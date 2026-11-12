class_name YardFrontLife
extends YardLife

## The yard's crew on the front door: the Shipyard deck's, minus what would cross
## the band, the engine cart and grinder where the mockup put them, the berths'
## stands drawn with them by depth, and every walker stepping round a berth.
## Why: docs/why/ChassisSelect.md#walkers-round-the-stands

## The band's top row in hall pixels: nothing of the floor's life goes below it.
const BAND_TOP := 400.0
## The mechanic at the engine cart, kneeling between the heavy's stands.
const ENG_FRONT := Vector2(442, 346)
## The grinder bench, left of the light's stands at the apron's edge.
const BENCH_FRONT := Vector2(24, 380)
## The lanes run on past the hall to off the frame's right edge.
const LANE_END := 990.0
## A walker turns out round a berth over this many columns either side of it.
const RAMP := 36.0

## The berths, for their stands' place in the depth order.
var berths: Array[YardStandSet] = []


func _init(s: YardScene) -> void:
	super(s)
	var keep: Array = []
	for c: Dictionary in CREW:
		if float(c["y"]) < BAND_TOP:
			keep.append(c)
	CREW = keep
	for c: Dictionary in CREW:
		if float(c["to"]) > float(YardScene.W):
			c["to"] = LANE_END
	has_welder = false


func tick(t: float, dt: float) -> void:
	super(t, dt)
	for b in berths:
		if is_instance_valid(b):
			var s := b
			item(float(b.feet), float(b.feet) < SHIP_ROW, func(P: YardPaint) -> void: s.paint_stands(P))


## Out round a berth's floor (`YardSlot.footprint`): a lane that crosses one
## steps forward to pass in front of its stands, easing out and back over `RAMP`.
## Why: docs/why/ChassisSelect.md#walkers-round-the-stands
func avoid(x: float, lane_y: float) -> float:
	var dy := 0.0
	for w: HullData.Weight in YardStandSet.WEIGHTS:
		var r := YardSlot.footprint(w)
		if lane_y < float(r.position.y) or lane_y >= float(r.end.y):
			continue
		var out := float(r.position.x) - x if x < float(r.position.x) else x - float(r.end.x - 1)
		var f := 1.0 - smoothstep(0.0, RAMP, out)
		dy = maxf(dy, floorf((float(r.end.y) + 1.0 - lane_y) * f + 0.5))
	return dy


## Past the hall's right edge the floor is its first columns again, lit as they are.
func lit_cell(x: float, y: float) -> Vector2:
	return YardScene.cell(x - float(YardScene.W) if x >= float(YardScene.W) else x, y)


func _engine(t: float) -> void:
	var key: String = MECHS[int(VISIT["mech"])]
	var n := frames_of(key)
	var u := fmod(t, 4.2)
	var tap := n > 1 and u < 0.9 and int(floorf(u / 0.15)) % 2 == 1
	var F := sprite(key, 1 if tap else 0)
	item(ENG_FRONT.y, false, func(P: YardPaint) -> void:
		put(P, F, ENG_FRONT.x, ENG_FRONT.y, {"k": 0.45}))


func _bench(_t: float) -> void:
	var u := fmod(_t, 5.2)
	var on := u <= 3.4
	GRINDLIT = {"on": on, "x": BENCH_FRONT.x + 4.0, "y": BENCH_FRONT.y - 12.0}
	var f := int(floorf(u * 10.0)) % 9 if on else 0
	var F := sprite("grind_strip", f)
	item(BENCH_FRONT.y, false, func(P: YardPaint) -> void: put(P, F, BENCH_FRONT.x, BENCH_FRONT.y, {"k": 0.35}))


func _fk_step(_t: float) -> void:
	pass


func _forklift(_t: float) -> void:
	pass


func _hatch(_t: float) -> void:
	pass


func send_bot(_t: float) -> bool:
	return false


func send_cat(_t: float) -> bool:
	return false


func cat_ride(_t: float) -> bool:
	return false


func cat_chase(_t: float) -> bool:
	return false


func paper_plane(_t: float) -> bool:
	return false


func hatch_peek(_t: float) -> bool:
	return false
