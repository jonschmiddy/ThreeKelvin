extends Node

## WHAT A PACK'S HIT LAYERS COST TO BUILD AS ITS FIGHT OPENS (perf, Oct 27).
##   godot --headless --fixed-fps 60 --path . -- sheet=PackArmProf [reps=5]
## A ship's `HitLayers` (its marks, bubble and armour, `EnemySlot._arm`) are
## built from its picture as drawn. A pack of three or more is drawn from half
## sheets, a size the layout sets after the bind (`EncounterView._layout_pack`),
## and its layers wait for that size (`EnemySlot.layers_wait`); before Oct 27
## they were built at full size in the bind and again at half, the first build
## thrown away. Prints first, for each kind, one `_arm` at full size and one at
## half (ms, median of `reps`); then, for packs of three and four through the
## real `Router.start_combat` from LOCAL:
##   still     not animated (headless, reduced motion): the bind and the layout
##             in the one call; `open ms` is that call, the whole opening;
##   animated  `Router.animate_in_harness`, the row held while LOCAL's band
##             goes (`EncounterView.hold_row`): the layout a few frames later;
## for each: the enemy layers built (`builds`; one a ship is the floor), the
## half-sheet ones among them, the size the kept ones were built at, and the
## `_arm` time those builds cost (`arm ms`, from the kinds' costs above). A
## build is counted as its `HitLayers` enters the tree (yours, which follows
## your `ShipView`, is not counted). With `_arm` patched locally to add its own
## time to the `Engine` meta `prof_arm_us`, `measured` prints that too.
## Profiler only: nothing here fails.

const KINDS: Array[StringName] = [&"cutter", &"lancer", &"hulk", &"marauder", &"sentinel", &"whale"]

var _tree: SceneTree
## [kind, scale] of each enemy layer built, as it enters the tree
var _built: Array = []


func _ready() -> void:
	_tree = get_tree()
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _on_added(n: Node) -> void:
	if not (n is HitLayers) or (n as HitLayers).follow != null:
		return
	# the slot it lies in: its art's picture says which kind (`EnemyArt._sig`)
	var p := n.get_parent()
	while p != null and not (p is EnemySlot):
		p = p.get_parent()
	var id := ""
	if p != null and (p as EnemySlot).art != null:
		id = (p as EnemySlot).art._sig.split("|")[0]
	_built.append([id, (n as HitLayers).hits.mark_scale])


static func _median(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var s := xs.duplicate()
	s.sort()
	return float(s[s.size() / 2])


func _run() -> void:
	await _frames(2)
	var reps := int(_arg("reps", "5"))
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))

	# one build at each size, by kind
	var cost := {}
	for id: StringName in KINDS:
		var e := Combat.EnemyState.new()
		e.template = DB.enemies[id]
		e.max_hp = e.template.max_hull
		e.hp = e.max_hp
		e.look = 0
		var sl := EnemySlot.new()
		add_child(sl)
		sl.wreck_id = 1
		sl.bind(0, e, false)
		await _frames(1)
		for s in [1.0, 0.5]:
			var ts: Array = []
			for k in reps:
				if sl.layers != null:
					sl.layers.free()
					sl.layers = null
				sl.art.marks = null
				sl.art.set_draw_scale(s)
				var t1 := Time.get_ticks_usec()
				sl._arm(e)
				ts.append(float(Time.get_ticks_usec() - t1) / 1000.0)
			cost["%s/%.1f" % [id, s]] = _median(ts)
		print("packarmprof: _arm %-9s full %.1f ms  half %.1f ms" % [id, cost["%s/1.0" % id], cost["%s/0.5" % id]])
		sl.queue_free()
		await _frames(1)

	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not n.cleared and not Router.no_fights_at(n):
			idx = n.index
			break
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	_tree.node_added.connect(_on_added)
	var packs := {
		"3 cutter+lancer+cutter": [&"cutter", &"lancer", &"cutter"],
		"4 cutter+lancer+cutter+hulk": [&"cutter", &"lancer", &"cutter", &"hulk"],
		"3 hulk+marauder+sentinel": [&"hulk", &"marauder", &"sentinel"],
		"3 whale+whale+whale": [&"whale", &"whale", &"whale"],
	}
	for mode in ["still", "animated"]:
		Router.animate_in_harness = mode == "animated"
		for label: String in packs:
			var kinds: Array = packs[label]
			var opens: Array = []
			var measured: Array = []
			var builds := -1
			var halves := -1
			var arm_ms := 0.0
			var kept := ""
			for r in reps:
				Router.combat = null
				Router.show_local()
				await _frames(4)
				if mode == "animated":
					var w := 0
					while w < 240 and not ((Router.current is SectorScreen) and (Router.current as SectorScreen).settled_local()):
						await _frames(1)
						w += 1
				var extras: Array = []
				for i in range(1, kinds.size()):
					extras.append(DB.enemies[kinds[i]])
				_built.clear()
				Engine.set_meta(&"prof_arm_us", 0)
				var t0 := Time.get_ticks_usec()
				Router.start_combat(DB.enemies[kinds[0]], extras, false, false)
				opens.append(float(Time.get_ticks_usec() - t0) / 1000.0)
				# the band's rise, and its layout, in the animated opening
				await _frames(150 if mode == "animated" else 4)
				measured.append(float(int(Engine.get_meta(&"prof_arm_us", 0))) / 1000.0)
				builds = _built.size()
				halves = 0
				arm_ms = 0.0
				for b: Array in _built:
					if is_equal_approx(float(b[1]), 0.5):
						halves += 1
					arm_ms += float(cost.get("%s/%.1f" % [b[0], 1.0 if float(b[1]) > 0.75 else 0.5], 0.0))
				var sc := Router.current as SectorScreen
				var scales: Array = []
				if sc != null and sc._view != null:
					var i2 := 0
					while sc._view.slot(i2) != null:
						var sl := sc._view.slot(i2)
						scales.append("%.1f/%s" % [sl.art.draw_scale,
							("%.1f" % sl.layers.hits.mark_scale) if sl.layers != null else "none"])
						i2 += 1
				kept = " ".join(scales)
			var m := _median(measured)
			print("packarmprof: %-8s %-30s builds %d (half %d)  kept art/layers %s  arm ms %.1f%s  open ms median %.1f (first %.1f)" % [
				mode, label, builds, halves, kept, arm_ms,
				("  measured %.1f" % m) if m > 0.0 else "", _median(opens), float(opens[0])])
	Router.animate_in_harness = false
	Router.combat = null
	print("packarmprof: done")
	_tree.quit()
