extends Node

## THE SHIPYARD'S HITCHES, timed headless (issue #34):
##   godot --headless --path . -- sheet=YardHitchTest
## Jon, in the Shipyard: clicking your ship "does a sick spin move" and the game
## freezes, then recovers; moving things in the hold hitches too. Docked at an
## unclaimed station (a Korvan medium, whose belly gun's empty ring sits inside
## a yard stand) with parts in the hold, this times on the main thread what each
## gesture costs: the yard's ship bake, the yard's ships stood again, the click
## that opens the cutaway, a part off the hull into the hold and a part moved
## within the hold through the cutaway's own handlers, the close, and the click
## again. It fails on any one past its budget, and if a refit inside the
## cutaway stands the yard's ships again under it, or the close does not.
##
## Measured on the Mac before the fix: the click 7.9 s, a part off the hull
## 7.5 s, a move in the hold 5.7 s -- `CutawayView._layout` searching every
## place in the room for an empty mount's words that had nowhere to go, three
## or four times a gesture. The budgets are generous on purpose (other runs
## share the machine); what they catch is seconds, not milliseconds.

## The click: three layouts the first time (2x tried, 1x, 1x in place).
const OPEN_MS := 250.0
## Anything after it: a refit is one fresh layout, a move in the hold none.
const MOVE_MS := 100.0

var _fails := 0


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _ms(u0: int) -> float:
	return float(Time.get_ticks_usec() - u0) / 1000.0


## The longest frame over the next `n`, in ms.
func _worst(n: int) -> float:
	var worst := 0.0
	var last := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
	return worst


## The cutaway opened by the yard's click: how long the call took and the worst
## frame of its push-in.
func _open(st: StationScreen) -> Array:
	var u0 := Time.get_ticks_usec()
	var cut := st.open_cutaway()
	var call := _ms(u0)
	var after := await _worst(40)
	return [cut, call, after]


## Shut, and the worst frame until it is gone.
func _close(st: StationScreen, cut: CutawayView) -> float:
	cut.close()
	var worst := 0.0
	for i in 600:
		worst = maxf(worst, await _worst(1))
		if st._cutaway == null:
			break
	return maxf(worst, await _worst(10))


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

	# 1. the yard's ship bake, alone
	var u0 := Time.get_ticks_usec()
	st._scene._bake_ships()
	var bake := _ms(u0)
	_ok("the yard's ship bake: %.1f ms" % bake, bake < MOVE_MS)
	await _worst(10)

	# 2. the yard's ships stood again (what the close asks of it after a refit)
	st._yard_ships_key = ""
	u0 = Time.get_ticks_usec()
	st._yard_ships(st._yard_hull)
	var stand := _ms(u0)
	var stand_after := await _worst(10)
	_ok("the yard's ships stood again: %.1f ms, then a %.1f ms frame" % [stand, stand_after],
		stand < MOVE_MS and stand_after < MOVE_MS)
	await _worst(30)

	# 3. the click: the cutaway opens
	var view_was := st._mine_view
	var o: Array = await _open(st)
	var cut: CutawayView = o[0]
	if not _ok("the cutaway opens", cut != null):
		return _finish()
	_ok("the click: %.1f ms, the push-in's worst frame %.1f ms (%s)" % [o[1], o[2], cut.fit_note],
		o[1] < OPEN_MS and o[2] < OPEN_MS)

	# 4. a part off the hull into the hold, through the cutaway's handlers
	var m: ModuleData = Run.installed[0]
	var cell := _free_cell(m)
	u0 = Time.get_ticks_usec()
	cut._on_lift(m)
	await cut._on_hold_drop({module = m, origin = &"hull"}, cell)
	var unfit := _ms(u0)
	var unfit_after := await _worst(10)
	_ok("the part is in the hold", Run.cargo.has(m))
	_ok("a part off the hull: %.1f ms, then a %.1f ms frame" % [unfit, unfit_after],
		unfit < MOVE_MS and unfit_after < MOVE_MS)
	_ok("and the yard's ship under the cutaway is still the one it opened on",
		st._mine_view == view_was and is_instance_valid(view_was))

	# 5. the same part moved within the hold
	var to := _free_cell(m, m.hold_at)
	u0 = Time.get_ticks_usec()
	await cut._on_hold_drop({module = m, origin = &"cargo"}, to)
	var move := _ms(u0)
	var move_after := await _worst(10)
	_ok("the part moved in the hold", m.hold_at == to)
	_ok("a move in the hold: %.1f ms, then a %.1f ms frame" % [move, move_after],
		move < MOVE_MS and move_after < MOVE_MS)

	# 6. the close: the yard's ship catches up with the refit, once
	var shut := await _close(st, cut)
	_ok("the cutaway shuts, its worst frame %.1f ms" % shut, st._cutaway == null and shut < MOVE_MS)
	_ok("the yard's ship is stood again for the refit after the close",
		st._mine_view != null and st._mine_view != view_was and st._mine_view.visible)

	# 7. and the click again
	o = await _open(st)
	cut = o[0]
	if _ok("it opens again", cut != null):
		_ok("the click again: %.1f ms, the push-in's worst frame %.1f ms" % [o[1], o[2]],
			o[1] < MOVE_MS and o[2] < MOVE_MS)
		await _close(st, cut)
	_finish()


## A cell in the hold `m` fits in, other than `not_at`.
func _free_cell(m: HoldItem, not_at: Vector2i = -Vector2i.ONE) -> Vector2i:
	var g := Run.hold_grid()
	for y in g.y:
		for x in g.x:
			var c := Vector2i(x, y)
			if c != not_at and Run.can_place(m, c, m):
				return c
	return Vector2i.ZERO


func _finish() -> void:
	print("yardhitchtest: %s" % ("PASS" if _fails == 0 else "%d FAIL" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)
