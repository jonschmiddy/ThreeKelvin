extends Node

## The chart's orbit map (`ChartOrbits`) is what the sector map draws on arrival, headless:
##   godot --headless --path . -- sheet=OrbitPreviewTest [seeds=4]
## Why: docs/why/OrbitPreviewTest.md#orbit-preview-test

const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
var h := Harness.new()
var _tree: SceneTree


func _ready() -> void:
	_tree = get_tree()
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(k + "="):
			return (a as String).substr(k.length() + 1)
	return d


func _start(seed_v: int) -> void:
	Rng.forced = seed_v
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))


## Every system but the core: what the chart would show of it, read before anything is visited.
func _look() -> Dictionary[int, String]:
	var out: Dictionary[int, String] = {}
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type != MapGen.NodeType.CORE:
			out[n.index] = ChartOrbits.signature(SystemLayout.of(n), n)
	return out


## Arrive at `i` as the game settles an arrival, and read the layout the sector map draws there.
func _arrive(i: int) -> String:
	var n: MapGen.MapNode = Run.map[i]
	Run.at = i
	n.visited = true
	Router.settle_arrival(n)
	return ChartOrbits.signature(SystemLayout.of(n), n)


func _run() -> void:
	await _tree.process_frame
	var seeds := int(_arg("seeds", "4"))
	var kinds := {}
	for s in seeds:
		_sweep(7100 + s * 211, kinds)
	h._ok("every kind was compared (%s)" % [kinds], kinds.has("twin") and kinds.has("red")
		and kinds.has("blue") and kinds.has("pulsar") and kinds.has("station") and kinds.has("job"))
	_star_numbers()
	_looks()
	_fog()
	await _panel()
	Rng.forced = 0
	h.verdict("orbitpreviewtest")
	_tree.quit(1 if h._fails > 0 else 0)


## Run A looks at every system first, then arrives at each; run B, the same seed, arrives
## without looking. The look must match both arrivals, so looking moves nothing.
func _sweep(seed_v: int, kinds: Dictionary) -> void:
	_start(seed_v)
	_sign_job()
	var before := _look()
	var job_at := _job_place()
	var after_a: Dictionary[int, String] = {}
	for i in before:
		after_a[i] = _arrive(i)
	_start(seed_v)
	_sign_job()
	var bad_a := 0
	var bad_b := 0
	var first := ""
	for i in before:
		var b := _arrive(i)
		if after_a[i] != before[i]:
			bad_a += 1
			first = "%d: %s / %s" % [i, before[i], after_a[i]]
		if b != before[i]:
			bad_b += 1
			if first == "":
				first = "%d: %s / %s (unlooked)" % [i, before[i], b]
		_tally(Run.map[i], kinds)
	if job_at >= 0 and before[job_at].contains("job@"):
		kinds["job"] = true
	h._ok("seed %d: %d systems read before a visit match the arrival (%d differ)%s"
		% [seed_v, before.size(), bad_a, "" if first == "" else " first " + first], bad_a == 0)
	h._ok("seed %d: and a run that never looked arrives at the same layouts (%d differ)"
		% [seed_v, bad_b], bad_b == 0)


func _tally(n: MapGen.MapNode, kinds: Dictionary) -> void:
	if n.twin and MapGen.twin_ok(n):
		kinds["twin"] = true
	if n.type == MapGen.NodeType.PULSAR:
		kinds["pulsar"] = true
	if n.type == MapGen.NodeType.STATION:
		kinds["station"] = true
	if n.type == MapGen.NodeType.SYSTEM and n.star == MapGen.Star.RED:
		kinds["red"] = true
	if n.type == MapGen.NodeType.SYSTEM and n.star == MapGen.Star.BLUE:
		kinds["blue"] = true


## Signed jobs, so a job's place is on some layout: every offer on the first station's board.
func _sign_job() -> void:
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.STATION:
			for c in Contracts.board(n):
				Contracts.take(c)
			return


func _job_place() -> int:
	for c in Run.contracts:
		var t := int((c as ContractData).at)
		if t >= 0 and OptionTable.ensure(Run.map[t]) 				and (Run.map[t] as MapGen.MapNode).options.any(func(o: StringName) -> bool: return OptionTable.is_job(o)):
			return t
	return -1


## Fog: nothing for a system out of sight, nothing for the core, the place you stand always.
func _fog() -> void:
	_start(7100)
	var here := Run.node_at()
	var dark := 0
	var dark_shown := 0
	var lit := 0
	var lit_shown := 0
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.index == here.index or n.type == MapGen.NodeType.CORE:
			continue
		if n.sensed:
			lit += 1
			lit_shown += 1 if StarchartScreen.orbits_shown(n, here) else 0
		else:
			dark += 1
			dark_shown += 1 if StarchartScreen.orbits_shown(n, here) else 0
	h._ok("out of sight shows no orbits (%d of %d)" % [dark_shown, dark], dark > 0 and dark_shown == 0)
	h._ok("in sight shows them (%d of %d)" % [lit_shown, lit], lit > 0 and lit_shown == lit)
	h._ok("where you stand shows them", StarchartScreen.orbits_shown(here, here))
	var core: MapGen.MapNode = null
	for raw in Run.map:
		if (raw as MapGen.MapNode).type == MapGen.NodeType.CORE:
			core = raw
	h._ok("the core shows none", core != null and not StarchartScreen.orbits_shown(core, here))


## The panel: the list with nothing picked; the orbits, and no list, with a star picked.
func _panel() -> void:
	_start(7100)
	Router.show_starchart()
	for i in 6:
		await _tree.process_frame
	var sc := Router.current as StarchartScreen
	if not h._ok("the chart opens", sc != null):
		return
	sc.dismiss_primer()
	var here := Run.node_at()
	var pick := -1
	for n in Run.in_range():
		if (n as MapGen.MapNode).sensed and (n as MapGen.MapNode).type != MapGen.NodeType.CORE:
			pick = (n as MapGen.MapNode).index
			break
	h._ok("nothing picked: the list, no orbits", sc._neigh_scroll.visible and not sc._star_box.visible)
	if not h._ok("a system in sight to pick", pick >= 0):
		return
	sc._on_node_picked(pick)
	await _tree.process_frame
	var t: MapGen.MapNode = Run.map[pick]
	var want := ChartOrbits.read(SystemLayout.of(t), t)
	h._ok("picked: the orbits, no list", not sc._neigh_scroll.visible and sc._star_box.visible
		and sc._orbits.visible)
	h._ok("and the star's picture under its name, its kind in the rows",
		sc._star_pic.visible and sc._star_pic.get_child_count() > 0
		and sc._rows.get_child(0).get_child(2).get("text") == sc._orbits.fact("kind"))
	h._ok("the map draws the layout's %d orbits (%d)" % [want.size(), sc._orbits.marks.size()],
		sc._orbits.marks.size() == want.size() and want.size() > 0)
	h._ok("the counts line says them (%s)" % sc._star_counts.text,
		sc._star_counts.text == ChartOrbits.counts(want))
	sc._on_chart_cleared()
	await _tree.process_frame
	h._ok("cleared: the list again, no picture", sc._neigh_scroll.visible and not sc._star_box.visible
		and not sc._star_pic.visible)
	print("  (stood at %d)" % here.index)


## Each look of the map (`ChartOrbits.LOOKS`, Nov 23) over one seed's systems: every orbit drawn
## inside the box, the same picture read before the visit and after arriving, the orrery and the
## arrival view with each world at its angle as the map opens, the lineup in orbit order.
func _looks() -> void:
	_start(7100)
	var bad := {}
	var seen := 0
	for lk in ChartOrbits.LOOKS:
		bad[lk] = []
	var before := {}
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.CORE or n.type == MapGen.NodeType.START:
			continue
		for lk in ChartOrbits.LOOKS:
			ChartOrbits.look = lk
			var o := ChartOrbits.new()
			o.show_system(n)
			before["%d:%s" % [n.index, lk]] = str(o._spots)
			var why := _look_fault(o, n)
			if why != "":
				(bad[lk] as Array).append("%d %s" % [n.index, why])
			o.free()
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.CORE or n.type == MapGen.NodeType.START:
			continue
		_arrive(n.index)
		seen += 1
		for lk in ChartOrbits.LOOKS:
			ChartOrbits.look = lk
			var o := ChartOrbits.new()
			o.show_system(n)
			if str(o._spots) != before["%d:%s" % [n.index, lk]]:
				(bad[lk] as Array).append("%d drawn differently after arriving" % n.index)
			o.free()
	ChartOrbits.look = &"arcs"
	for lk in ChartOrbits.LOOKS:
		var b: Array = bad[lk]
		h._ok("look %s: %d systems drawn whole, in the box, as arrived%s" % [lk, seen,
			"" if b.is_empty() else ": " + ", ".join(b.slice(0, 4))], b.is_empty() and seen > 20)


## Why look `o` of `n` is wrong, or "".
func _look_fault(o: ChartOrbits, n: MapGen.MapNode) -> String:
	var L := SystemLayout.of(n)
	if str(ChartOrbits.read(L, n)) != str(o.marks):
		return "marks are not the layout's"
	if o._spots.size() != o.marks.size():
		return "a mark has no place"
	for p in o._spots:
		if p.x < 0 or p.x >= ChartOrbits.W or p.y < 0 or p.y >= ChartOrbits.H:
			return "a mark off the box at %s" % p
	var t := o.t_drawn
	var tilt: float = SystemViewS.TILT
	for i in o.marks.size():
		var d: Dictionary = o.marks[i]
		var b: SystemLayout.Body = L.bodies[int(d.body)]
		var main := not L.twin or int(d.host) == -9
		var want := (b.pos(t) - b.host_at(t)).angle()
		match ChartOrbits.look:
			&"orrery":
				if main:
					var v: Vector2 = o._spots[i] - Vector2(roundf(ChartOrbits.W * 0.5), roundf(ChartOrbits.H * 0.5))
					if absf(angle_difference(v.angle(), want)) > 0.35:
						return "a world at the wrong angle"
			&"arrival":
				var c0: Vector2 = L.bary if L.twin else Vector2.ZERO
				var mid := Vector2(roundf(ChartOrbits.W * 0.5), roundf(ChartOrbits.H * 0.5))
				var v2: Vector2 = o._spots[i] - mid
				var want_v := (b.pos(t) - c0)
				if v2.length() > 6.0 and absf(angle_difference(Vector2(v2.x, v2.y / tilt).angle(), want_v.angle())) > 0.35:
					return "a world not where the map opens it"
	if ChartOrbits.look == &"lineup":
		var xs: Array = []
		var order := []
		for i in o.marks.size():
			if not L.twin or int(o.marks[i].host) == -9:
				order.append([float(o.marks[i].orbit), o._spots[i].x])
		order.sort_custom(func(a: Array, b2: Array) -> bool: return a[0] < b2[0])
		for e in order:
			xs.append(e[1])
		for k in range(1, xs.size()):
			if xs[k] <= xs[k - 1]:
				return "the line is not in orbit order"
	return ""


## Each sun's numbers (Jon, Nov 23): inside its kind's range, and the same after a fresh start.
const RANGES := {
	"ORDINARY": {mass = [0.8, 1.2], temp = [5300.0, 6000.0], radius = [0.8, 1.2]},
	"RED": {mass = [15.0, 30.0], temp = [3400.0, 3800.0], radius = [700.0, 1500.0]},
	"BLUE": {mass = [30.0, 60.0], temp = [20000.0, 30000.0], radius = [25.0, 70.0]},
	"PULSAR": {mass = [1.3, 1.6], temp = [500000.0, 700000.0], radius = [10.0, 13.0]},
}


func _star_numbers() -> void:
	_start(7311)
	var first: Dictionary[int, String] = {}
	var out := 0
	var seen := {}
	var odd := ""
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		var k: String = SystemViewS.KIND_NAMES[SystemLayout.star_kind(n)]
		if not RANGES.has(k):
			continue
		var f := StarNumbers.of(k, n.index)
		first[n.index] = str(f)
		seen[k] = true
		for key: String in ["mass", "temp", "radius"]:
			var x := String(f[key]).split(" ")[0].replace(",", "").to_float()
			var lo: float = RANGES[k][key][0]
			var hi: float = RANGES[k][key][1]
			# (two significant figures may round a hair past an edge)
			if x < lo * 0.95 or x > hi * 1.05:
				out += 1
				odd = "%s %s %s" % [k, key, f[key]]
		if String(f.lum) == "" or String(f.lum).begins_with("0 "):
			out += 1
	Rng.world.randf()
	_start(7311)
	var moved := 0
	for i in first:
		var k: String = SystemViewS.KIND_NAMES[SystemLayout.star_kind(Run.map[i])]
		if str(StarNumbers.of(k, i)) != first[i]:
			moved += 1
	h._ok("every sun's mass, temperature and size inside its kind's range (%d out%s; kinds %s)"
		% [out, "" if odd == "" else ", " + odd, seen.keys()], out == 0 and seen.size() == 4)
	h._ok("and the same numbers after a fresh start (%d of %d moved)" % [moved, first.size()], moved == 0)
