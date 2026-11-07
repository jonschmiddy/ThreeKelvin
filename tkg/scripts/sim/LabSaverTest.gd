extends Node

## THE LAB'S SAVERS, headless:
##   godot --headless --path . -- sheet=LabSaverTest [cost]
## Jon, Nov 7: all seven savers kept in the owner's dress, and all 24 of the
## owners' own ("O:korvan 1,2,3; solari 1,2,3; ...").
##
## THE TABLE (`LabSavers.list_for`): every owner, and a lab with none, runs ten
## savers, its own three and the seven, no other owner's; the same station
## deals the same order every time, and stations differ; an owner not in the
## table runs an independent lab's. Every owner's dress (`LabSaverDress`) has
## its five posters, and no player line on them has a dash.
##
## THROUGH THE REAL STATION SCREEN, at the settlement (the smallest glass,
## 206 x 110) and the capital, for every owner and a lab with none: the lab's
## screen runs that owner's ten; each one pinned (`LabLogin.forced`, as films
## pin one) draws at rest, pointed at (with a SIGN IN on it) and signing in
## (SIGNING IN on it), every look passing the box test (`LabLogin.check`) and
## every box inside 960x540 where the landed camera puts it; and the glass,
## clicked with the saver up, lands on RESEARCH.
##
## THE TURN, at the settlement with a short hold (`LabLogin.hold_s`): the savers
## come up in the station's order on the lab's clock, the glass dips dark
## between them, the glass (the one key) never moves, and pointing at it holds
## the one up.
##
## `cost` prints each saver's draw cost (`LabLogin.paint_us`) at rest, the mean
## and worst over a second, and fails one over `COST_MAX_US` on average.

var _fails := 0
var _tree: SceneTree
var _cost := false
## The most a saver may take to draw a frame on average, headless (8 ms is half
## a 60 Hz frame; the glass is one small part of the room).
const COST_MAX_US := 8000
const OWNERS: Array[StringName] = [&"korvan", &"solari", &"probate", &"redline", &"cygnet", &"verity", &"calyx", &""]


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_tree = get_tree()
	_cost = OS.get_cmdline_user_args().has("cost")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _until(cond: Callable, ms: int = 8000) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < ms:
		await _tree.process_frame


func _run() -> void:
	await _tree.process_frame
	_tables()
	for dev: int in [MapGen.Development.SETTLEMENT, MapGen.Development.CAPITAL]:
		for o in OWNERS:
			await _lab(dev, o)
	await _turn()
	LabLogin.forced = ""
	print("labsavertest: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	_tree.quit(1 if _fails > 0 else 0)


func _name(o: StringName) -> String:
	return "independent" if o == &"" else String(o)


## THE TABLE, off the code alone.
func _tables() -> void:
	var orders := {}
	for o in OWNERS:
		var l := LabSavers.list_for(o, 12345)
		var own: Array = LabSavers.OWN[o]
		var others: Array[String] = []
		for o2 in OWNERS:
			if o2 != o:
				for c: String in LabSavers.OWN[o2]:
					if l.has(c):
						others.append(c)
		var dup := false
		for c in l:
			if l.count(c) > 1:
				dup = true
		_ok("%s: ten savers (%s), its own three and the seven, none twice, no other owner's (%s)" % [_name(o), ",".join(l), ",".join(others)],
			l.size() == 10 and own.all(func(c: String) -> bool: return l.has(c)) and LabSavers.KEPT.all(func(c: String) -> bool: return l.has(c))
			and others.is_empty() and not dup)
		_ok("%s: every one is a saver there is" % _name(o), l.all(func(c: String) -> bool: return LabSavers.ALL.has(c)))
		_ok("%s: the same station deals the same order" % _name(o), LabSavers.list_for(o, 12345) == l)
		var differ := 0
		for k in 20:
			if LabSavers.list_for(o, 777 + k * 31) != l:
				differ += 1
		_ok("%s: other stations deal other orders (%d of 20 differ)" % [_name(o), differ], differ >= 18)
		orders[o] = l
		var d := LabSaverDress.of(o)
		var cards: Array = d.s5
		var dashed: Array[String] = []
		for cd: Array in cards:
			for w in cd.slice(1):
				if (w as String).contains(" - ") or (w as String).contains("—") or (w as String).contains("–"):
					dashed.append(w)
		for w2 in d.s3_own:
			if (w2 as String).contains(" - ") or (w2 as String).contains("—"):
				dashed.append(w2)
		_ok("%s: its dress has five posters and every key (%d keys), no dash in a line (%s)" % [_name(o), d.size(), ",".join(dashed)],
			cards.size() == 5 and d.size() == LabSaverDress.BASE.size() and dashed.is_empty())
	_ok("a lab whose owner is not in the table runs an independent lab's (%s)" % ",".join(LabSavers.list_for(&"nobody", 12345)),
		LabSavers.list_for(&"nobody", 12345) == orders[&""])


func _station(dev: int, o: StringName) -> MapGen.MapNode:
	Rng.forced = 9400 + dev
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var here: MapGen.MapNode = Run.node_at()
	here.type = MapGen.NodeType.STATION
	here.development = dev
	here.security = 4
	here.danger = 5
	here.in_nebula = false
	here.berths.clear()
	here.manufacturer = o
	if o != &"":
		here.berths.append(o)
	Run.data = 12
	Run.board_owned[0] = 2
	Run.board_owned[1] = 1
	return here


func _open_lab(here: MapGen.MapNode) -> StationScreen:
	Router.powered.clear()
	Router.park_at_station(here)
	Router.show_station()
	await _frames(30)
	var st := Router.current as StationScreen
	if st == null:
		return null
	(st._tabs[&"bench"] as Button).pressed.emit()
	await _frames(3)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000 and not st.deck_subject(&"bench").has_area():
		await _tree.process_frame
	await _frames(4)
	# the screen up past its power-on
	await _until(func() -> bool: return st._login.since_on() > 0.5, 8000)
	return st if st.deck_subject(&"bench").has_area() else null


## The look's boxes the landed camera would put outside 960x540.
func _cut(st: StationScreen) -> Array[String]:
	var lab := st._lab
	var z := float(LabZoom.ZOOM.get(lab._level, 3))
	var o := LabZoom.landed_origin(lab)
	var wp := lab.win_rect().position
	var out: Array[String] = []
	for l: Array in st._login.leaves:
		var r: Rect2i = l[1]
		var sr := Rect2(o + (wp + Vector2(r.position)) * z, Vector2(r.size) * z)
		if not Rect2(0, 0, LabZoom.W, LabZoom.H).encloses(sr):
			out.append("'%s'" % l[0])
	return out


func _lab(dev: int, o: StringName) -> void:
	var tag := "%s, %s" % [String(MapGen.Development.keys()[dev]).to_lower(), _name(o)]
	var here := _station(dev, o)
	var st := await _open_lab(here)
	if not _ok("%s: the lab's screen is up" % tag, st != null):
		return
	var login := st._login
	var want := LabSavers.list_for(o, hash("%d:%d" % [Run.galaxy_seed, here.index]))
	_ok("%s: the screen runs %s's ten in the station's order (%s)" % [tag, _name(o), ",".join(login.savers())],
		login.savers() == want and login.owner_id == o)
	var press := st._glass_press.get_global_rect()
	var fails: Array[String] = []
	var drawn := 0
	for code in login.savers():
		LabLogin.forced = code
		st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
		await _frames(2)
		# at rest a moment, then a second's frames for the cost
		await _until(func() -> bool: return false, 400)
		var us: Array[int] = []
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < (1000 if _cost else 150):
			await _tree.process_frame
			us.append(login.paint_us)
		var mean := 0.0
		for u in us:
			mean += float(u)
		mean /= float(maxi(1, us.size()))
		if _cost:
			print("    cost %s %s %s: mean %.2f ms, worst %.2f ms over %d frames" % [String(MapGen.Development.keys()[dev]).to_lower(), _name(o), code, mean / 1000.0, float(us.max()) / 1000.0, us.size()])
			if mean > COST_MAX_US:
				fails.append("%s costs %.1f ms a frame" % [code, mean / 1000.0])
		var rest := _look(st, code, "rest", "")
		# pointed at
		st._glass_press.notification(Control.NOTIFICATION_MOUSE_ENTER)
		await _frames(2)
		await _until(func() -> bool: return login._t >= 0.8, 4000)
		var hov := _look(st, code, "pointed at", "SIGN IN")
		# signing in, as the press sets it (the station's own pointer check held
		# off for it: the camera is not moved here)
		st.set_process(false)
		login.set_state(LabLogin.SIGNING)
		await _frames(4)
		var sig := _look(st, code, "signing in", "SIGNING IN")
		login.set_state(LabLogin.LOGIN)
		st.set_process(true)
		st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
		await _frames(2)
		fails.append_array(rest)
		fails.append_array(hov)
		fails.append_array(sig)
		if rest.is_empty() and hov.is_empty() and sig.is_empty():
			drawn += 1
	_ok("%s: every one of the ten draws at rest, pointed at and signing in, each passing the box test inside the window and inside 960x540 landed (%d of 10%s)" % [tag, drawn,
		"" if fails.is_empty() else ": " + "; ".join(fails.slice(0, 6))], drawn == 10 and fails.is_empty())
	_ok("%s: the glass, the one key, stayed where it was (%s)" % [tag, st._glass_press.get_global_rect()], st._glass_press.get_global_rect().is_equal_approx(press))
	# THE CLICK STILL LANDS ON RESEARCH, the owner's own first saver up
	LabLogin.forced = String(LabSavers.OWN[o][0])
	await _frames(2)
	var zoom := st.lab_zoom()
	await _click(st._glass_press)
	st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await _until(func() -> bool: return zoom.landed(), 6000)
	await _frames(3)
	_ok("%s: with %s up, the glass clicked lands on RESEARCH (open %s, landed %s, tab %s, the screen %s)" % [tag, login.code(), zoom.is_open(), zoom.landed(), zoom.tab, login.state],
		zoom.is_open() and zoom.landed() and zoom.tab == &"research" and login.state == LabLogin.SIGNING)
	zoom.close()
	await _frames(3)
	LabLogin.forced = ""


## One look's faults: nothing drawn, the box test, a box cut off once landed, or
## the words it must have.
func _look(st: StationScreen, code: String, what: String, must: String) -> Array[String]:
	var login := st._login
	var out: Array[String] = []
	if login.code() != code:
		out.append("%s %s: %s up instead" % [code, what, login.code()])
	if login.leaves.size() < 2:
		out.append("%s %s: nothing drawn (%d boxes)" % [code, what, login.leaves.size()])
	for b in login.check():
		out.append("%s %s: %s" % [code, what, b])
	for c in _cut(st):
		out.append("%s %s: %s off the landed view" % [code, what, c])
	if must != "" and not login.leaves.any(func(l: Array) -> bool: return str(l[0]).contains(must)):
		out.append("%s %s: no %s (%s)" % [code, what, must, ", ".join(login.leaves.map(func(l: Array) -> String: return str(l[0])))])
	return out


## THE TURN, on the lab's clock, with a short hold.
func _turn() -> void:
	var here := _station(MapGen.Development.SETTLEMENT, &"cygnet")
	var st := await _open_lab(here)
	if not _ok("the turn: the lab's screen is up", st != null):
		return
	var login := st._login
	LabLogin.forced = ""
	var hold_was := LabLogin.hold_s
	LabLogin.hold_s = 1.2
	login.turn_t = 0.0
	st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await _frames(2)
	var order := login.savers()
	var seen: Array[String] = [login.code()]
	var dipped := false
	var press := st._glass_press.get_global_rect()
	var moved := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4200:
		await _tree.process_frame
		if login.dip() > 0.5:
			dipped = true
		if not st._glass_press.get_global_rect().is_equal_approx(press):
			moved = true
		if login.code() != seen[-1]:
			seen.append(login.code())
	var in_order := seen.size() >= 3
	for i in seen.size():
		if seen[i] != order[i % order.size()]:
			in_order = false
	_ok("the turn: on the lab's clock the savers come up in the station's order (%s of %s)" % [",".join(seen), ",".join(order)], in_order)
	_ok("the turn: the glass dips dark between them", dipped)
	_ok("the turn: the glass, the one key, never moved", not moved)
	# a saver's clock is the lab's (game time), from when it came up
	_ok("the turn: a saver's own clock starts when it comes up (%.2f s up, the lab at %.2f)" % [login.saver().rest_t(), login.since_on()],
		login.saver().rest_t() <= LabLogin.hold_s + 0.1 and login.since_on() > login.saver().rest_t())
	# POINTED AT, the one up holds
	st._glass_press.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _frames(2)
	var up := login.code()
	var tt := login.turn_t
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2000:
		await _tree.process_frame
	_ok("the turn: pointed at for 2 s, %s stays up (now %s) and the turn's clock waits (%.2f, %.2f)" % [up, login.code(), tt, login.turn_t],
		login.code() == up and is_equal_approx(tt, login.turn_t) and login.dip() == 0.0)
	st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await _frames(2)
	LabLogin.hold_s = hold_was


## A click through the viewport, as a player makes it.
func _click(b: Control) -> void:
	b.notification(Control.NOTIFICATION_MOUSE_ENTER)
	var at := b.get_global_rect().get_center()
	var target := GameShell.input_target(_tree)
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	target.push_input(mv)
	await _tree.process_frame
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		mb.position = at
		mb.global_position = at
		target.push_input(mb)
		await _tree.process_frame
