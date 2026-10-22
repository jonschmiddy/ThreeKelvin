extends Node

## THE SHORTEST WAY IN (balance/run-length, Oct 22):
##   godot --headless --path . -- sheet=RunLengthStudy [seeds=12] [depthcap=N]
##       [radrim=X raddeep=Y] [dump=<dir>]
##
## Kevin, the first outside playtester, reached the core in seven jumps. This
## measures what the galaxy allows: for `seeds` galaxies of every kind
## (`GalaxyGen.KINDS`), and each Korvan weight at grade C with its starter kit,
## the fewest jumps from the start to the core under the rule the ship flies --
## a star must be in the dish (`sense_radius_of`, the core always is) and in
## reach (`reachable_from`) -- and then the same with the 45 tank: the fewest
## jumps that fuel allows, with a dock stop (a full tank) at any station flown
## through, and how many dock stops that takes.
##
## A MEASUREMENT, never a gate; it passes either way. The study flags are
## `RunState.study_*` and are off unless given here.
##
## `dump=<dir>` writes one JSON a galaxy (the first seed of each kind) with
## every system's place and its fewest jumps from the start, for drawing.

const TANK := 45
const MAXD := 6

var _seeds := 12
var _dump := ""


func _ready() -> void:
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(k + "="):
			return (a as String).substr(k.length() + 1)
	return d


func _run() -> void:
	_seeds = int(_arg("seeds", "12"))
	_dump = _arg("dump", "")
	Run.study_depth_cap = int(_arg("depthcap", "0"))
	Run.study_radius_rim = float(_arg("radrim", "1.0"))
	Run.study_radius_deep = float(_arg("raddeep", "1.0"))
	print("RunLengthStudy: %d galaxies a kind, %d kinds · depth cap %d · radius x%.2f rim, x%.2f last ring" % [
		_seeds, GalaxyGen.count(), Run.study_depth_cap, Run.study_radius_rim, Run.study_radius_deep])
	var weights := [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]
	# per weight: arrays across every galaxy
	var all := {}
	for w in weights:
		all[w] = {h = [], hf = [], docks = [], nodock = [], fuel = [], unreach = 0, sopt = [], aopt = []}
	var by_kind := {}
	for k in GalaxyGen.count():
		var kh: Array = []
		for s in _seeds:
			var seed := 900001 + k * 1000 + s
			_galaxy(seed, k)
			var core := -1
			for raw in Run.map:
				if (raw as MapGen.MapNode).type == MapGen.NodeType.CORE:
					core = (raw as MapGen.MapNode).index
			var cand := _candidates()
			for w in weights:
				Run.fit_chassis(&"korvan", w)
				var adj := _adjacency(cand)
				var r := _paths(adj, core)
				var row: Dictionary = all[w]
				row.sopt.append((adj[0] as Array).size())
				var tot := 0
				for l in adj:
					tot += (l as Array).size()
				row.aopt.append(float(tot) / adj.size())
				if r.h < 0:
					row.unreach += 1
					if w == HullData.Weight.MEDIUM:
						kh.append(-1)
					continue
				row.h.append(r.h)
				row.fuel.append(r.fuel)
				if r.hf >= 0:
					row.hf.append(r.hf)
					row.docks.append(r.docks)
				row.nodock.append(r.nodock)
				if w == HullData.Weight.MEDIUM:
					kh.append(r.h)
				if w == HullData.Weight.MEDIUM and s == 0 and _dump != "":
					_write_dump(k, seed, adj, core)
		by_kind[GalaxyGen.type_name(k)] = kh
	var wn := ["light", "medium", "heavy"]
	print("---")
	for w in weights:
		var row: Dictionary = all[w]
		Run.fit_chassis(&"korvan", w)
		print("%-6s (fuel factor %.2f, reach x%.2f, dish x%.2f): fewest jumps min %d · median %.1f · max %d  |  with the 45 tank: min %d · median %.1f · max %d · dock stops median %.1f max %d · %d%% need none  |  fuel for the fewest-jump path median %.0f (max %d) · %d of %d galaxies no route" % [
			wn[int(w)], Run.fuel_factor(), Run.thrust_reach(),
			Run.sense_radius_of(Run.map[0]) / Run.JUMP_RADIUS,
			_min(row.h), _median(row.h), _max(row.h),
			_min(row.hf), _median(row.hf), _max(row.hf),
			_median(row.docks), _max(row.docks), _pct_zero(row.docks),
			_median(row.fuel), _max(row.fuel), row.unreach, GalaxyGen.count() * _seeds])
		var hist := {}
		for h in row.h:
			hist[h] = int(hist.get(h, 0)) + 1
		var keys := hist.keys()
		keys.sort()
		var bits: PackedStringArray = []
		for kk in keys:
			bits.append("%d:%d" % [kk, hist[kk]])
		print("       fewest-jump histogram %s · stars in reach at the start median %.1f (min %d) · across the galaxy mean %.1f" % [" ".join(bits), _median(row.sopt), _min(row.sopt), _mean(row.aopt)])
	print("--- by kind, medium (fewest jumps, ignoring fuel)")
	for kname in by_kind:
		var a: Array = (by_kind[kname] as Array).filter(func(v): return int(v) >= 0)
		var lost: int = (by_kind[kname] as Array).size() - a.size()
		print("  %-22s min %2d median %4.1f max %2d%s" % [kname, _min(a), _median(a), _max(a),
			(" · %d with no route" % lost) if lost > 0 else ""])
	get_tree().quit(0)


## A galaxy of kind `kind` from `seed`, laid out as a new run's would be.
func _galaxy(seed: int, kind: int) -> void:
	Rng.forced = seed
	Run.start_new_run(&"korvan", HullData.Weight.MEDIUM)
	Rng.reseed(seed, 0)
	Run.galaxy_kind = kind
	Run.galaxy = GalaxyGen.roll(kind)
	Run.galaxy_spin = Rng.world.randf() * TAU
	Run.map = MapGen.generate(Run.MAP_CANVAS)
	Run.at = 0
	Run._range_cache.clear()
	Run.chart_from(Run.node_at())


## Every pair close enough that some weight might fly it, and the core from
## anywhere (its approach is a rule, not a distance).
func _candidates() -> Array:
	var out: Array = []
	var lim := Run.JUMP_RADIUS * maxf(Run.study_radius_rim, Run.study_radius_deep) * 1.7
	var n := Run.map.size()
	for i in n:
		var a: MapGen.MapNode = Run.map[i]
		var l: Array = []
		for j in n:
			if j == i:
				continue
			var b: MapGen.MapNode = Run.map[j]
			if b.type == MapGen.NodeType.CORE or MapGen.hop_distance(a, b) <= lim:
				l.append(j)
		out.append(l)
	return out


## The hops this ship can take: seen from where it stands (the core always is)
## and in reach, each with its fuel price.
func _adjacency(cand: Array) -> Array:
	var out: Array = []
	for i in Run.map.size():
		var a: MapGen.MapNode = Run.map[i]
		var dish := Run.sense_radius_of(a)
		var l: Array = []
		for j: int in cand[i]:
			var b: MapGen.MapNode = Run.map[j]
			if b.type != MapGen.NodeType.CORE and MapGen.hop_distance(a, b) > dish:
				continue
			if not Run.reachable_from(a, b):
				continue
			l.append(Vector2i(j, Run._hop_cost(a, b)))
		out.append(l)
	return out


func _paths(adj: Array, core: int) -> Dictionary:
	var out := {h = -1, fuel = 0, hf = -1, docks = 0, nodock = -1}
	# 1. fewest jumps, fuel ignored; and the least fuel over those
	var lvl := {0: 0}
	var fuel := {0: 0}
	var frontier: Array[int] = [0]
	var h := 0
	while not frontier.is_empty() and not lvl.has(core):
		h += 1
		var next: Array[int] = []
		for i in frontier:
			for e: Vector2i in adj[i]:
				var j := e.x
				var f: int = int(fuel[i]) + e.y
				if not lvl.has(j):
					lvl[j] = h
					fuel[j] = f
					next.append(j)
				elif int(lvl[j]) == h and f < int(fuel[j]):
					fuel[j] = f
		frontier = next
	if not lvl.has(core):
		return out
	out.h = int(lvl[core])
	out.fuel = int(fuel[core])
	out.lvl = lvl
	# 2. with the tank: states (system, dock stops) -> most fuel left
	var r := _tank(adj, core, true)
	out.hf = r.x
	out.docks = r.y
	out.nodock = _tank(adj, core, false).x
	return out


func _tank(adj: Array, core: int, docks_ok: bool) -> Vector2i:
	var best := {}
	var frontier := {0: TANK}
	best[0] = TANK
	for h in range(1, 80):
		var next := {}
		var found := -1
		for key: int in frontier:
			var i := key / 8
			var d := key % 8
			var f: int = frontier[key]
			for e: Vector2i in adj[i]:
				if e.y > f:
					continue
				var j := e.x
				var nf := f - e.y
				if j == core:
					found = d if found < 0 else mini(found, d)
					continue
				_push(best, next, j, d, nf)
				if docks_ok and d < MAXD and (Run.map[j] as MapGen.MapNode).type == MapGen.NodeType.STATION:
					_push(best, next, j, d + 1, TANK)
		if found >= 0:
			return Vector2i(h, found)
		if next.is_empty():
			return Vector2i(-1, 0)
		frontier = next
	return Vector2i(-1, 0)


func _push(best: Dictionary, next: Dictionary, j: int, d: int, nf: int) -> void:
	for dd in d + 1:
		if int(best.get(j * 8 + dd, -1)) >= nf:
			return
	best[j * 8 + d] = nf
	next[j * 8 + d] = maxi(int(next.get(j * 8 + d, -1)), nf)


func _write_dump(kind: int, seed: int, adj: Array, core: int) -> void:
	DirAccess.make_dir_recursive_absolute(_dump)
	var lvl := {0: 0}
	var frontier: Array[int] = [0]
	var h := 0
	while not frontier.is_empty():
		h += 1
		var next: Array[int] = []
		for i in frontier:
			for e: Vector2i in adj[i]:
				if not lvl.has(e.x):
					lvl[e.x] = h
					next.append(e.x)
		frontier = next
	var nodes: Array = []
	var sq := maxf(0.05, float(Run.galaxy.squash))
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		nodes.append({x = n.gal.x, y = n.gal.y / sq, layer = n.layer, type = int(n.type),
			danger = n.danger, hops = int(lvl.get(n.index, -1))})
	var f := FileAccess.open("%s/k%02d.json" % [_dump, kind], FileAccess.WRITE)
	f.store_string(JSON.stringify({kind = GalaxyGen.type_name(kind), seed = seed, core = core,
		radius = Run.JUMP_RADIUS, cap = Run.study_depth_cap, radrim = Run.study_radius_rim,
		raddeep = Run.study_radius_deep, nodes = nodes}))
	f.close()


static func _median(a: Array) -> float:
	if a.is_empty():
		return -1.0
	var s := a.duplicate()
	s.sort()
	var m := s.size() / 2
	return float(s[m]) if s.size() % 2 == 1 else (float(s[m - 1]) + float(s[m])) * 0.5

static func _mean(a: Array) -> float:
	var t := 0.0
	for v in a:
		t += float(v)
	return t / maxf(1.0, float(a.size()))

static func _min(a: Array) -> int:
	var m := 9999
	for v in a:
		m = mini(m, int(v))
	return m if not a.is_empty() else -1

static func _max(a: Array) -> int:
	var m := -1
	for v in a:
		m = maxi(m, int(v))
	return m

static func _pct_zero(a: Array) -> int:
	var z := 0
	for v in a:
		if int(v) == 0:
			z += 1
	return int(round(100.0 * z / maxi(1, a.size())))
