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
## clicked with the saver up, lands on RESEARCH. Each look is taken at a fixed
## moment in the saver's own clock (`REST_AT`, by `LabLogin.rest_pin`), well
## into it, so a run is the same every time (a moment on the wall's clock
## caught saver 5 mid-wipe one look in thirty).
##
## VER3 POINTED AT while a drawing fades holds the signed drawing, not a near
## empty glass.
##
## THE TURN, at the settlement with a short hold (`LabLogin.hold_s`), at a lab
## whose owner is known only from its first berth: the savers come up in the
## station's order on the lab's clock, the glass dips dark between them, the
## glass (the one key) never moves, and pointing at it holds the one up;
## pointed at while it is dark, the glass brightens over a quarter second and
## does not jump.
##
## THE GLASS HEARD (Jon's picks, Nov 7; read off `Audio.tape`, Audio being off
## headless): `lab_glass_hover` once as the pointer arrives on the glass, not
## again while it stays, again after it leaves and comes back, never while the
## glass is hidden, signing in or on the camera's way back out with the pointer
## still on it; the press that signs in plays `lab_login` once, on the frame of
## its `ui_click`; a press refused (the camera already in) clicks alone.
##
## `cost` prints each saver's draw cost (`LabLogin.paint_us`) at rest, the mean
## and worst over a second, and fails one over `COST_MAX_US` on average.

var _fails := 0
var _tree: SceneTree
var _cost := false
## The most a saver may take to draw a frame on average, headless (8 ms is half
## a 60 Hz frame; the glass is one small part of the room).
const COST_MAX_US := 8000
## The moment in each saver's own clock its looks are taken at (s): past every
## saver's start, off saver 5's wipes (3.4 s apart, 0.12 s long) and inside
## VER3's drawing.
const REST_AT := 7.3
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
	await _sounds()
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
		login.rest_pin = -1.0
		st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
		await _frames(2)
		login.rest_pin = REST_AT
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
		login.rest_pin = -1.0
	_ok("%s: every one of the ten draws at rest, pointed at and signing in, each passing the box test inside the window and inside 960x540 landed (%d of 10%s)" % [tag, drawn,
		"" if fails.is_empty() else ": " + "; ".join(fails.slice(0, 6))], drawn == 10 and fails.is_empty())
	_ok("%s: the glass, the one key, stayed where it was (%s)" % [tag, st._glass_press.get_global_rect()], st._glass_press.get_global_rect().is_equal_approx(press))
	if o == &"verity":
		await _ver3_fade(st, tag)
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


## VER3 pointed at while a drawing fades (13.8 s to 15 s of its cycle, which
## starts 6 s in) and while the next is only ruled in: the signed drawing held.
func _ver3_fade(st: StationScreen, tag: String) -> void:
	var login := st._login
	LabLogin.forced = "VER3"
	for at: float in [8.6, 9.6]:
		login.rest_pin = at
		st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
		await _frames(3)
		st._glass_press.notification(Control.NOTIFICATION_MOUSE_ENTER)
		await _frames(2)
		await _until(func() -> bool: return login._t >= 0.5, 4000)
		var names: Array = login.leaves.map(func(l: Array) -> String: return str(l[0]))
		_ok("%s: VER3 pointed at %.1f s into its cycle holds the signed drawing (%s)" % [tag, fposmod(at + LabSavers.VR3_OFFSET, LabSavers.VR3_CYCLE), ", ".join(names)],
			names.has("SIGNED") and names.any(func(n: String) -> bool: return n.begins_with("LENGTH ")))
		st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
		await _frames(2)
	login.rest_pin = -1.0
	LabLogin.forced = ""


## THE TURN, on the lab's clock, with a short hold.
func _turn() -> void:
	var here := _station(MapGen.Development.SETTLEMENT, &"cygnet")
	# (its owner known only from its first berth, as `_refresh_bench` falls back to)
	here.manufacturer = &""
	var st := await _open_lab(here)
	if not _ok("the turn: the lab's screen is up", st != null):
		return
	var login := st._login
	_ok("the turn: a lab with no maker set runs its first berth's savers (%s)" % login.owner_id, login.owner_id == &"cygnet"
		and login.savers().has("C1"))
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
		login.code() == up and is_equal_approx(tt, login.turn_t) and login.dip() == 0.0 and login._dip_shown == 0.0)
	st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await _frames(2)
	# POINTED AT IN THE DARK: the glass comes up over a quarter second, no jump
	await _until(func() -> bool: return login._dip_shown > 0.85, 4000)
	var dark := login._dip_shown
	st._glass_press.notification(Control.NOTIFICATION_MOUSE_ENTER)
	var worst := 0.0
	var last := dark
	var ok_rate := true
	for f in 40:
		await _tree.process_frame
		var step := absf(login._dip_shown - last)
		worst = maxf(worst, step)
		if step > get_process_delta_time() * 2.0 / LabLogin.DIP_S + 0.001:
			ok_rate = false
		last = login._dip_shown
	_ok("the turn: pointed at in the dark (%.2f), the glass clears with no jump (worst step %.3f a frame, cleared %s)" % [dark, worst, last == 0.0],
		dark > 0.85 and ok_rate and last == 0.0)
	st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await _frames(2)
	LabLogin.hold_s = hold_was


## How many times `name` is on the tape, and the frames it played on.
func _heard(name: StringName) -> Array:
	return Audio.tape.filter(func(e: Array) -> bool: return e[6] == name).map(func(e: Array) -> int: return int(e[5]))


## THE GLASS HEARD.
func _sounds() -> void:
	var here := _station(MapGen.Development.SETTLEMENT, &"korvan")
	var st := await _open_lab(here)
	if not _ok("the sounds: the lab's screen is up", st != null):
		return
	var g := st._glass_press
	g.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await _frames(3)
	Audio.taping = true
	Audio.tape.clear()
	g.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _frames(3)
	_ok("the sounds: the pointer arriving on the glass plays its hover once (%s)" % [_heard(&"lab_glass_hover")],
		_heard(&"lab_glass_hover").size() == 1 and st._login.state == LabLogin.LOGIN)
	await _until(func() -> bool: return false, 600)
	_ok("the sounds: held on the glass 0.6 s, not again (%d)" % _heard(&"lab_glass_hover").size(), _heard(&"lab_glass_hover").size() == 1)
	g.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await _until(func() -> bool: return false, 200)
	_ok("the sounds: leaving plays nothing (%d)" % _heard(&"lab_glass_hover").size(), _heard(&"lab_glass_hover").size() == 1)
	g.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _frames(3)
	_ok("the sounds: left and come back, heard again (%d)" % _heard(&"lab_glass_hover").size(), _heard(&"lab_glass_hover").size() == 2)
	# hidden (its deck's page down): the glass plays nothing however the pointer
	# moves (the lab's own power-on scan shows and hides the clip it sits in, so
	# the page is what is hidden here)
	g.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await _until(func() -> bool: return false, 200)
	(st._pages[&"bench"] as Control).visible = false
	g.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _until(func() -> bool: return false, 200)
	_ok("the sounds: the glass hidden, nothing (%d)" % _heard(&"lab_glass_hover").size(), _heard(&"lab_glass_hover").size() == 2)
	g.notification(Control.NOTIFICATION_MOUSE_EXIT)
	(st._pages[&"bench"] as Control).visible = true
	await _until(func() -> bool: return false, 200)
	_ok("the sounds: no login heard before a press", _heard(&"lab_login").is_empty())
	# THE PRESS THAT SIGNS IN, a real click (the pointer arriving first)
	Audio.tape.clear()
	var zoom := st.lab_zoom()
	await _click(g)
	var clicks := _heard(&"ui_click")
	var logins := _heard(&"lab_login")
	_ok("the sounds: the press that signs in plays lab_login once on the frame of its ui_click (login %s, click %s, the screen %s)" % [logins, clicks, st._login.state],
		logins.size() == 1 and clicks.size() == 1 and logins[0] == clicks[0] and st._login.state == LabLogin.SIGNING)
	var hov_at_press := _heard(&"lab_glass_hover").size()
	# signing in: the pointer off and on the glass is not heard
	g.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await _frames(3)
	g.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _frames(3)
	_ok("the sounds: signing in, the pointer off and on again is not heard (%d after %d)" % [_heard(&"lab_glass_hover").size(), hov_at_press],
		_heard(&"lab_glass_hover").size() == hov_at_press)
	await _until(func() -> bool: return zoom.landed(), 6000)
	# a press with the camera already in: refused, clicks alone
	g.pressed.emit()
	await _frames(2)
	_ok("the sounds: a press refused (the camera in) clicks and plays no login (login %d, click %d)" % [_heard(&"lab_login").size(), _heard(&"ui_click").size()],
		_heard(&"lab_login").size() == 1 and _heard(&"ui_click").size() == 2)
	# back out with the pointer still on the glass: the sign-in shows, unheard
	zoom.close()
	await _until(func() -> bool: return not zoom.is_open() and not zoom.visible, 6000)
	await _frames(6)
	_ok("the sounds: back out with the pointer on the glass, the sign-in up (%s) and no hover (%d after %d)" % [st._login.state, _heard(&"lab_glass_hover").size(), hov_at_press],
		st._login.state == LabLogin.LOGIN and _heard(&"lab_glass_hover").size() == hov_at_press)
	g.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await _until(func() -> bool: return false, 200)
	g.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _frames(3)
	_ok("the sounds: and off and back on after, heard (%d after %d)" % [_heard(&"lab_glass_hover").size(), hov_at_press],
		_heard(&"lab_glass_hover").size() == hov_at_press + 1)
	g.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await _frames(2)
	Audio.taping = false
	Audio.tape.clear()


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
