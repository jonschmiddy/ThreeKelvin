extends Node

## THREE LATENT BUGS FROM SWEEP 2, each held to its fix (Jon's ruling 3A, Nov 14), headless:
## the old planner leaves no `_high` behind it, the moons' ring-slot cache answers for the
## moon count asked, and LOCAL's weather band above the fight has a height.
## Why: docs/why/LatentFixTest.md#latent-fix-test

const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")
const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
const SEEDS := [4242, 7, 99]

var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	_planner_flag()
	_ring_slots()
	_weather_band()
	h.verdict("latentfixtest")
	get_tree().quit(h.code())


## A kept choice with `high` set that is no longer clean falls through to the half-ellipse
## to the star; the flag it set must be cleared on that return (it leaked into the next plan).
func _planner_flag() -> void:
	var asked := 0
	var planned := 0
	var left := 0
	for sd: int in SEEDS:
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var done := 0
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if n.type != MapGen.NodeType.SYSTEM or done >= 4:
				continue
			OptionTable.ensure(n)
			var L := SystemLayout.of(n)
			if L.twin:
				continue
			done += 1
			for k in 3:
				var t := 40.0 + 70.0 * k
				var fl = ShipFlightS.new()
				fl.setup(L, Vector2(L.edge, -210.0), t)
				var prefer := {"tcap": 5.0, "high": true, "kf": 0.02, "side": 1.0, "way": true, "strict": true, "kind": "waypoint"}
				var pl = fl._old_plan(-1, t, prefer)
				asked += 1
				if pl != null:
					planned += 1
				if fl._high:
					left += 1
	Rng.forced = -1
	print("  planner: %d asks to the star with a stale high choice, %d planned, %d left _high set" % [asked, planned, left])
	h._ok("the old planner was asked to the star with a stale high choice and planned (%d of %d)" % [planned, asked], planned > 0)
	h._ok("and no return left `_high` set for the next plan (%d did)" % left, left == 0)


class _StubWorld extends Node2D:
	var spec := {"ring": true, "moons": 2}
	var _cell := 2.0


class _StubView extends RefCounted:
	var _views := {}


## One world, one radius, two moon counts: each answer has a slot per moon.
func _ring_slots() -> void:
	var stub := _StubView.new()
	var w := _StubWorld.new()
	stub._views[3] = w
	var moons = SystemViewS._Moons.new()
	moons.view = stub
	var b := SystemLayout.Body.new()
	b.world = &"ice"
	b.seed = 1234
	var two: Array = moons.ring_slots(3, b, 24.0, 2)
	var five: Array = moons.ring_slots(3, b, 24.0, 5)
	var two_again: Array = moons.ring_slots(3, b, 24.0, 2)
	h._ok("ring slots at 2 moons: %d slots" % two.size(), two.size() == 2)
	h._ok("the same world and radius at 5 moons: %d slots, not the cached 2" % five.size(), five.size() == 5)
	h._ok("and at 2 again: the first answer", two_again == two)
	moons.free()
	w.free()


## Shafts, shocks and glitter land in the band above the fight, spread through it, not on one line.
func _weather_band() -> void:
	var sky := LocalSky.new()
	var ys := {}
	var out := 0
	for k in 200:
		var ev := {"name": &"shaft", "at": Vector2.INF, "dir": Vector2.RIGHT}
		if not sky._wx_place(ev):
			out += 1
			continue
		var y: float = (Vector2(ev.at) + sky.neb_off()).y
		ys[roundi(y)] = true
		if y < 49.0 or y > LocalSky.PLAY.x + 1.0:
			out += 1
	sky.free()
	print("  weather: 200 shafts on %d rows, %d outside 50..%d" % [ys.size(), out, int(LocalSky.PLAY.x)])
	h._ok("a shaft lands on more than one row of the band (%d rows)" % ys.size(), ys.size() > 4)
	h._ok("and every one above the fight", out == 0)
