class_name YardFrontLife
extends YardLife

## The yard's crew on the front door: the Shipyard deck's walkers and workers,
## minus what would cross the info band on the apron, the engine cart and the
## grinder where the mockup put them, a mechanic under the generator at the right.
## Why: docs/why/ChassisSelect.md#banner-yard

## The band's top row in hall pixels: nothing of the floor's life goes below it.
const BAND_TOP := 400.0
## The mechanic at the engine cart, kneeling between the heavy's stands.
const ENG_FRONT := Vector2(442, 346)
## The grinder bench, left of the medium's stands at the apron's edge.
const BENCH_FRONT := Vector2(24, 380)
## A mechanic under the generator on its lift, right of the light, on the
## hall's continued floor (lit as the hall's first columns are).
const GEN_FRONT := Vector2(806, 376)


func _init(s: YardScene) -> void:
	super(s)
	var keep: Array = []
	for c: Dictionary in CREW:
		if float(c["y"]) < BAND_TOP:
			keep.append(c)
	CREW = keep
	has_welder = false


func tick(t: float, dt: float) -> void:
	super(t, dt)
	var F := sprite("mech_gen_1", int(t * 2.0) % maxi(1, frames_of("mech_gen_1")))
	if not F.is_empty():
		item(GEN_FRONT.y, false, func(P: YardPaint) -> void:
			_put_lit(P, F, GEN_FRONT.x, GEN_FRONT.y, Vector2(GEN_FRONT.x - 766.0, GEN_FRONT.y)))


## `put`, with the light taken at a given hall cell (a thing past the hall's edge).
func _put_lit(P: YardPaint, S: Dictionary, x: float, bottom: float, cell: Vector2) -> void:
	var left := floorf(x - float(S["cx"]) + 0.5)
	var top := bottom - float(S["foot"])
	var inkw := float(S["x1"]) - float(S["x0"]) + 1.0
	P.use(YardPaint.PLAIN)
	scene.shade(P, floorf(x + 0.5), bottom + 1.0, maxf(3.0, inkw * 0.5), maxf(2.0, floorf(inkw * 0.07 + 0.5)), 0.4)
	P.use(YardPaint.FLOOR, Vector2(YardLight.cell_x(cell.x), YardLight.cell_y(cell.y)))
	P.tex(S["tex"], Vector2(left, top), S["src"], Color.WHITE, false)


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
