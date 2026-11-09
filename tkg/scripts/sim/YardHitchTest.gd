extends Node

## The shipyard's hitches (#34), timed headless with `sheet=YardHitchTest`.
## A docked Korvan medium, its belly gun's ring inside a yard stand. Budgets catch seconds.
## Why: docs/why/YardHitchTest.md#yard-hitches

const OPEN_MS := 250.0
const MOVE_MS := 100.0

var h := Harness.new()


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _ms(u0: int) -> float:
	return float(Time.get_ticks_usec() - u0) / 1000.0


## The longest of the next `n` frames, in ms.
func _worst(n: int) -> float:
	var worst := 0.0
	var last := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		worst = maxf(worst, _ms(last))
		last = Time.get_ticks_usec()
	return worst


## A hold cell `m` fits in, other than `not_at`.
func _free_cell(m: HoldItem, not_at: Vector2i = -Vector2i.ONE) -> Vector2i:
	var g := Run.hold_grid()
	for y in g.y:
		for x in g.x:
			var c := Vector2i(x, y)
			if c != not_at and Run.can_place(m, c, m):
				return c
	return Vector2i.ZERO


func _run() -> void:
	await get_tree().process_frame
	Router.animate_in_harness = true
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for i in 3:
		Run.stow(LootGen.roll_module(3, &"korvan"))
	var here: MapGen.MapNode = Run.node_at()
	here.type = MapGen.NodeType.STATION
	here.development = MapGen.Development.UNCLAIMED
	Router.park_at_station(here)
	Router.show_station()
	await _worst(60)
	var st := Router.current as StationScreen
	if not _ok("the station shows your ship in the yard", st != null and st._mine_view != null):
		return _finish()

	# the click: the layout runs in the push-in's first frames
	var view_was := st._mine_view
	var cut := st.open_cutaway()
	if not _ok("the cutaway opens", cut != null):
		return _finish()
	var open := await _worst(40)
	_ok("the click's worst frame: %.1f ms (%s)" % [open, cut.fit_note], open < OPEN_MS)

	var m: ModuleData = Run.installed[0]
	var u0 := Time.get_ticks_usec()
	cut._on_lift(m)
	await cut._on_hold_drop({module = m, origin = &"hull"}, _free_cell(m))
	var unfit := _ms(u0)
	_ok("a part off the hull into the hold: %.1f ms" % unfit, Run.cargo.has(m) and unfit < MOVE_MS)
	_ok("the yard's ship under the cutaway is not stood again", st._mine_view == view_was)

	var to := _free_cell(m, m.hold_at)
	u0 = Time.get_ticks_usec()
	await cut._on_hold_drop({module = m, origin = &"cargo"}, to)
	var move := _ms(u0)
	_ok("a move in the hold: %.1f ms" % move, m.hold_at == to and move < MOVE_MS)

	cut.close()
	for i in 600:
		if st._cutaway == null:
			break
		await get_tree().process_frame
	_ok("the close stands the yard's ship again for the refit", st._cutaway == null
		and st._mine_view != null and st._mine_view != view_was)
	_finish()


func _finish() -> void:
	h.verdict("yardhitchtest")
	get_tree().quit(h.code())
