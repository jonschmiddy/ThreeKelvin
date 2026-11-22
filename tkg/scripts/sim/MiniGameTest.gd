extends Node

## The science mini games, headless (`-- sheet=MiniGameTest [seeds=50] [games=a,b]`): per game, 50
## seeds at each depth deal the same puzzle twice, a scripted solve scores about 1, a give-up 0 to
## 0.2; then a solve through the shell's glass pays its tier, with the win then the reward sound,
## and the result card (A); Esc gives up.
## Why: docs/why/MiniGame.md#tests

const STEP := 1.0 / 30.0
## A scripted run gives up after this many steps (Four Kelvin's longest belt takes about 2,000).
const STEPS_MAX := 4000

var _h := Harness.new()
var _score := -1.0
## The last mounted game's canvas size, for the fill rule.
var _size := Vector2i.ZERO


func _ready() -> void:
	_run.call_deferred()


func _games() -> Array[StringName]:
	var out: Array[StringName] = []
	for g: String in Harness.arg("games", ",".join(MiniGames.ORDER)).split(",", false):
		out.append(StringName(g))
	return out


func _run() -> void:
	GameTray.memo_on = true
	GameSling.memo_on = true
	var seeds := int(Harness.arg("seeds", "50"))
	if Harness.arg("dump") != "":
		_dump(Harness.arg("dump"))
	_cost()
	_tiers()
	_haul()
	_site_deals()
	if _games().has(&"tray"):
		_prefetch()
	for id in _games():
		var t0 := Time.get_ticks_msec()
		for d in range(1, 6):
			_depth(id, d, seeds)
		print("minigame %s: %d ms" % [id, Time.get_ticks_msec() - t0])
		_shell(id)
		_tell(id)
		_tell_click(id)
	_h.verdict("minigametest")
	get_tree().quit(_h.code())


func _depth(id: StringName, d: int, seeds: int) -> void:
	var t0 := Time.get_ticks_msec()
	var dealt := 0
	var same := 0
	var solved := 0
	var perfect := 0
	var quits := 0
	var worst := 1.0
	var slow := 0
	var sized := 0
	for s in range(1, seeds + 1):
		var sens := s % 6
		var t1 := Time.get_ticks_msec()
		var a := _deal(id, d, sens, s)
		slow = maxi(slow, Time.get_ticks_msec() - t1)
		var b := _deal(id, d, sens, s)
		if a.is_empty():
			_h._fail("%s depth %d seed %d dealt no puzzle" % [id, d, s])
			continue
		dealt += 1
		if var_to_str(a) == var_to_str(b):
			same += 1
		var sc := _solve(id, d, sens, s)
		if sc >= 0.0:
			solved += 1
			worst = minf(worst, sc)
			if sc >= 0.95:
				perfect += 1
		else:
			print("  %s depth %d seed %d sensors %d: the scripted run never finished" % [id, d, s, sens])
		var q := _quit(id, d, sens, s)
		if q >= 0.0 and q <= 0.2:
			quits += 1
		if _size.y == AREA.y and (_size.x == AREA.x or _size.x == AREA.x + 2):
			sized += 1
		else:
			print("  %s depth %d seed %d draws %dx%d" % [id, d, s, _size.x, _size.y])
	print("minigame %s depth %d: %d dealt, %d same twice, %d solved (worst %.2f), %d scored about 1, %d give-ups at 0 to 0.2 (%d ms, slowest deal %d ms)"
		% [id, d, dealt, same, solved, worst, perfect, quits, Time.get_ticks_msec() - t0, slow])
	_h._ok("%s depth %d: every seed deals a puzzle" % [id, d], dealt == seeds)
	_h._ok("%s depth %d: the same seed deals the same puzzle" % [id, d], same == seeds)
	_h._ok("%s depth %d: the solver solves every puzzle" % [id, d], solved == seeds)
	_h._ok("%s depth %d: a perfect solve scores about 1" % [id, d], perfect == seeds)
	_h._ok("%s depth %d: a give-up scores 0 to 0.2" % [id, d], quits == seeds)
	_h._ok("%s depth %d: every deal fills the glass, exactly 150x140 (152x140 shown 150)" % [id, d], sized == seeds)


## The puzzle as data, for comparing two deals.
func _deal(id: StringName, d: int, sens: int, s: int) -> Dictionary:
	var r := MiniGames.stream(s)
	match id:
		&"coolant":
			return GameCoolant.gen(d, sens, r)
		&"centrifuge":
			return GameCentrifuge.gen(r, d)
		&"icecore":
			return GameIceCore.gen(r, d)
		&"pulsar":
			return GamePulsar.gen(r, d, sens)
		&"tray":
			# a real search, kept: the scripted solve and the give-up mount it without searching again
			var key := "%d:%d:%d" % [d, r.seed, r.state]
			var p := GameTray.gen(d, r)
			GameTray.memo[key] = {P = p.duplicate(true), end = r.state}
			return p
		&"anomaly":
			return GameAnomaly.gen(r, d)
		&"beams":
			return GameBeams.gen(r, d, sens)
		&"spectrum":
			return GameSpectrum.gen(r, d)
		&"fourkelvin":
			return GameFourKelvin.gen(r, d)
		&"torch":
			return TorchSim.gen(d, sens, r)
		&"leak":
			return GameLeak.gen(d, sens, r)
		&"sling":
			# kept, as the tray's: the scripted solve and the give-up mount it without scanning again
			var sk := "%d:%d:%d" % [d, r.seed, r.state]
			var sp := GameSling.gen(d, r)
			GameSling.memo[sk] = {P = sp.duplicate(true), end = r.state}
			return sp
		&"tuning":
			return GameTuning.gen(r, d)
		&"seismic":
			return GameSeismic.gen(r, d, sens)
		&"corescan":
			return GameCoreScan.gen(r, d)
		&"culture":
			return GameCulture.gen(r, d)
		&"dock":
			return GameDock.gen(d, sens, r)
		&"skim":
			return GameSkim.gen(r, d)
	return {}


func _mount(id: StringName, d: int, sens: int, s: int) -> MiniGame:
	var g := MiniGames.make(id)
	_score = -1.0
	_size = Vector2i.ZERO
	g.finished.connect(func(sc: float, _detail: String) -> void: _score = sc)
	g.seed = s
	g.drawing = false
	g.mount(d, sens, MiniGames.stream(s))
	_size = Vector2i(g.px.w, g.px.h) if g.px != null else Vector2i.ZERO
	return g


## One scripted event, straight into the game.
static func send(g: MiniGame, e: Dictionary) -> void:
	match String(e.k):
		"key":
			g.key(e.key, true)
			return
		"keyup":
			g.key(e.key, false)
			return
	var p: Vector2 = e.p
	g.pf = p
	var q := Vector2i(p.floor())
	match String(e.k):
		"down":
			g.glass_down(q)
		"move":
			g.move(q)
		"up":
			g.up(q)


## The score a scripted run earns through the game's input, or -1 if it never finished.
func _solve(id: StringName, d: int, sens: int, s: int) -> float:
	var g := _mount(id, d, sens, s)
	var sv := MiniSolver.for_game(g)
	for k in STEPS_MAX:
		if _score >= 0.0:
			break
		for e in sv.act(g, STEP):
			send(g, e)
		g.tick(STEP)
	return _score


func _quit(id: StringName, d: int, sens: int, s: int) -> float:
	var g := _mount(id, d, sens, s)
	g.tick(STEP)
	g.give_up()
	return _score


## `dump=<dir>`: each game at depth 3, sensors 1, seed 5, for `tools/dev/minigame/diff.py`: its deal
## as the page names it, the stream's draws after the deal, its canvas at the start, and after the
## scripted run's moves but the last and the frames the page draws them on.
func _dump(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for id: StringName in _games():
		var g := MiniGames.make(id)
		g.seed = 5
		var r := MiniGames.stream(5)
		g.mount(3, 1, r)
		var after := MiniGames.stream(5)
		_deal_into(id, after)
		var draws: Array[float] = []
		for i in 4000:
			draws.append(after.randf())
		var puz := MiniDump.puzzle(g)
		g.px.img.save_png(dir.path_join("%s_start.png" % id))
		var sv := MiniSolver.for_game(g)
		var evs: Array[Dictionary] = []
		if sv.plan.is_empty():
			evs = sv.act(g, 0.0)
		else:
			evs = sv.plan.slice(0, maxi(0, sv.plan.size() - 2))
		for e in evs:
			send(g, e)
		var ticks: Array = DUMP_TICKS.get(id, [])
		for dt: float in ticks:
			g.tick(dt)
		g.px.img.save_png(dir.path_join("%s_end.png" % id))
		var f := FileAccess.open(dir.path_join("%s_puzzle.json" % id), FileAccess.WRITE)
		# Skim's whole comet is its draws, so they go in full (the rest as they always have)
		f.store_string(JSON.stringify({puzzle = puz, draws = draws, seed = 5, events = MiniDump.js(evs), raf = DUMP_RAF.get(id, [])}, "", true, id == &"skim"))
		f.close()


## The frames each page draws after a move (its loop draws them, not the move), and the ticks here
## that match them: the first frame of most pages is 0.1 s (`last` starts at 0); Leak and Torch draw
## on their second.
const DUMP_RAF := {&"beams": [1100.0], &"spectrum": [1400.0], &"icecore": [1100.0], &"tray": [1100.0], &"anomaly": [1100.0], &"pulsar": [1100.0],
	&"leak": [1000.0, 1050.0], &"torch": [1000.0, 1050.0], &"fourkelvin": [1000.0], &"tuning": [1100.0], &"sling": [1100.0], &"seismic": [1600.0], &"corescan": [1100.0],
	&"culture": [1100.0], &"dock": [1000.0, 1050.0], &"skim": SKIM_RAF}
## Skim flies a second of frames 1/16 s apart, a step an exact binary fraction so both clocks agree.
const SKIM_RAF := [1062.5, 1125.0, 1187.5, 1250.0, 1312.5, 1375.0, 1437.5, 1500.0, 1562.5, 1625.0, 1687.5, 1750.0, 1812.5, 1875.0, 1937.5, 2000.0]
const SKIM_TICKS := [0.0625, 0.0625, 0.0625, 0.0625, 0.0625, 0.0625, 0.0625, 0.0625, 0.0625, 0.0625, 0.0625, 0.0625, 0.0625, 0.0625, 0.0625, 0.0625]
const DUMP_TICKS := {&"beams": [0.1], &"spectrum": [0.4], &"icecore": [0.1], &"tray": [0.1], &"anomaly": [0.1], &"pulsar": [0.1],
	&"leak": [0.0, 0.05], &"torch": [0.0, 0.05], &"fourkelvin": [0.0], &"tuning": [0.1], &"sling": [0.1], &"seismic": [0.6], &"corescan": [0.1],
	&"culture": [0.1], &"dock": [0.0, 0.05], &"skim": SKIM_TICKS}


## Deals into `r`, leaving it where the game's own deal left its stream.
func _deal_into(id: StringName, r: RandomNumberGenerator) -> void:
	match id:
		&"coolant":
			GameCoolant.gen(3, 1, r)
		&"centrifuge":
			GameCentrifuge.gen(r, 3)
		&"icecore":
			GameIceCore.gen(r, 3)
		&"pulsar":
			GamePulsar.gen(r, 3, 1)
		&"tray":
			GameTray.gen(3, r)
		&"anomaly":
			GameAnomaly.gen(r, 3)
		&"beams":
			GameBeams.gen(r, 3, 1)
		&"spectrum":
			GameSpectrum.gen(r, 3)
		&"fourkelvin":
			GameFourKelvin.gen(r, 3)
		&"torch":
			TorchSim.gen(3, 1, r)
		&"leak":
			GameLeak.gen(3, 1, r)
		&"sling":
			GameSling.gen(3, r)
		&"tuning":
			GameTuning.gen(r, 3)
		&"seismic":
			GameSeismic.gen(r, 3, 1)
		&"corescan":
			GameCoreScan.gen(r, 3)
		&"culture":
			GameCulture.gen(r, 3)
		&"dock":
			GameDock.gen(3, 1, r)
		&"skim":
			# the page deals its comet in its own mount, so its draws start where the stream does
			pass


## What a frame of each game costs at sector 5 (printed, never asserted: it is the machine's).
func _cost() -> void:
	for id in _games():
		var g := MiniGames.make(id)
		g.mount(5, 0, MiniGames.stream(3))
		var sv := MiniSolver.for_game(g)
		var t0 := Time.get_ticks_usec()
		for k in 60:
			for e in sv.act(g, STEP):
				send(g, e)
			g.tick(STEP)
		print("minigame %s: %.2f ms a frame at sector 5, playing" % [id, (Time.get_ticks_usec() - t0) / 60000.0])


## The desk's card starts the tray's search on a worker; the mount takes that deal, the same one
## the search on the spot would have made, and leaves the stream at the same place.
func _prefetch() -> void:
	GameTray.memo_on = false
	GameTray.memo.clear()
	MiniGames.prefetch({id = &"tray", depth = 5, seed = 7})
	var g := MiniGames.make(&"tray") as GameTray
	g.drawing = false
	var r := MiniGames.stream(7)
	g.mount(5, 0, r)
	var r2 := MiniGames.stream(7)
	var want := GameTray.gen(5, r2)
	_h._ok("tray: the card's search on a worker deals what the mount would have", var_to_str(g.P) == var_to_str(want) and r.state == r2.state and GameTray.memo.is_empty())
	GameTray.memo_on = true


func _tiers() -> void:
	var ok := true
	for d in range(1, 6):
		var top := mini(4, 2 + (d - 1) / 2)
		ok = ok and ScienceHaul.tier_of(1.0, d) == top and ScienceHaul.tier_of(0.0, d) == 0 \
			and ScienceHaul.tier_of(0.1, d) == 0 and ScienceHaul.tier_of(0.5, d) <= top
	_h._ok("the tier: depth raises the ceiling (rare, epic, legendary), a failure pays common", ok)


func _haul() -> void:
	# every site group pays a real row of its own source at every tier, at or under the tier
	for site: StringName in [&"barren", &"belt", &"comet", &"star", &"giant", &"derelict", &"life", &"pulsar"]:
		var src := ScienceHaul.source_of(site)
		var ok := true
		for t in 5:
			var row := MaterialTable.pick(src, ScienceHaul.tier_key(t), MiniGames.stream(7 + t))
			ok = ok and not row.is_empty() and StringName(row.get("source", &"")) == src
			ok = ok and not MaterialTable.by_id(StringName(row.get("id", &""))).is_empty() and MaterialTable.TIERS.find(StringName(row.get("tier", &""))) <= t
		_h._ok("a haul at a %s site pays a real %s material at every tier, at or under it" % [site, src], ok)
	var n: MapGen.MapNode = null
	for raw in Run.map:
		if (raw as MapGen.MapNode).type == MapGen.NodeType.SYSTEM:
			n = raw
			break
	if n != null:
		var h := ScienceHaul.pay(3, &"belt", n)
		_h._ok("pay grants one material by its catalogue name and tier (%s)" % str(h), not h.is_empty() and String(h.name) != "" and StringName(h.tier) in MaterialTable.TIERS)


## WHICH GAMES EACH SITE DEALS, printed: a comet deals Ice Core or Skim (Jon, Nov 21, "C"), every
## other site `pool(ROCK)`, as before. Why: docs/why/MiniGame.md#a-sites-own-deal
func _site_deals() -> void:
	var rock := MiniGames.pool(MiniGames.ROCK)
	var same := true
	for site: StringName in [&"barren", &"belt", &"star", &"giant", &"derelict", &"life", &"pulsar", &"lab"]:
		var ids := MiniGames.pool_at(site)
		print("deal at %s: %s (haul %s)" % [site, ", ".join(ids), ScienceHaul.source_of(site)])
		same = same and ids == rock
	_h._ok("every site but a comet deals the rock and lab games (%s)" % ", ".join(rock), same)
	var comet := MiniGames.pool_at(&"comet")
	print("deal at comet: %s (haul %s)" % [", ".join(comet), ScienceHaul.source_of(&"comet")])
	var dealt := {}
	# (the deal's own first draw: `deal` itself reads the ship's sensors, and this harness has no ship)
	for i in 64:
		dealt[comet[Rng.derive(&"minigame", i).randi() % comet.size()]] = true
	var both: Array[StringName] = [&"icecore", &"skim"]
	_h._ok("a comet deals Ice Core or Skim and nothing else, both over 64 systems (%s; dealt %s)" % [", ".join(comet), ", ".join(dealt.keys())],
		comet == both and dealt.size() == 2 and dealt.has(&"icecore") and dealt.has(&"skim"))


## The start card at every depth (Jon, Nov 20: "CONTROL [GAME INSTRUCTIONS] / [ESC] TO GIVE UP"): the
## game draws a tell, its line 1 lists no ESC (line 2 has it), and the card on its canvas is exactly the
## kit's, both lines, nothing drawn over it.
func _tell(id: StringName) -> void:
	var ok := true
	var why := ""
	for d in range(1, 6):
		MiniKit.told_px = null
		var g := MiniGames.make(id)
		g.seed = 5
		g.mount(d, 1, MiniGames.stream(5))
		g.tick(STEP)
		var px := MiniKit.told_px
		if px == null:
			ok = false
			why += " d%d no card" % d
			continue
		var b := MiniKit.told_at
		var esc := MiniKit.told_icons.any(func(k: String) -> bool: return k.contains("ESC"))
		var want := MiniPix.new(px.w, px.h)
		MiniKit.tell(want, MiniKit.told_text, MiniKit.told_icons, MiniKit.told_t, b.position.y)
		var same := want.img.get_region(b).get_data() == px.img.get_region(b).get_data()
		var quiet := 0
		for y in range(b.position.y + 20, b.position.y + 25):
			for x in range(b.position.x + 26, b.position.x + 26 + MiniKit.tw(MiniKit.GIVE)):
				quiet += 1 if px.img.get_pixel(x, y).is_equal_approx(MiniKit.LABEL) else 0
		if esc or not same or quiet == 0 or b.size.y != MiniKit.TELL_H:
			ok = false
			why += " d%d%s%s%s" % [d, " ESC on line 1" if esc else "", "" if same else " card not the kit's", "" if quiet > 0 else " no TO GIVE UP"]
	_h._ok("%s: the start card has its ESC TO GIVE UP line under the game's own, line 1 no ESC, at every depth%s" % [id, why], ok)


## Where a click on each game's glass hits nothing playable: the header band's top-left corner (glass
## 1,1), a label in every game. Some games already set a flag on any press (their own rule, kept):
## Anomaly and Four Kelvin start their clock; the rest mark themselves started (the centrifuge also
## stops its card's icon clock). That flag may differ.
const EMPTY := Vector2(1.5, 1.5)
const ANY_PRESS := {&"anomaly": ["started"], &"fourkelvin": ["mode"], &"tray": ["started"], &"centrifuge": ["acted", "_icon_t"],
	&"seismic": ["touched"], &"culture": ["touched"], &"skim": ["started", "ax", "ay"]}
## The games whose clock that press starts: their twins part from there, so they are held at the click.
## Skim's press starts the pass and takes hold of the tether where it lands.
const CLOCK_STARTS: Array[StringName] = [&"anomaly", &"fourkelvin", &"skim"]


## Any click on the glass puts the start card away (Jon, Nov 20: Ice Core's card hid ONE UPSIDE DOWN
## until the first drag). Two shells deal the same game; one gets a click on empty glass. Its next
## drawn frame has no card, the card's box is all that differs on the canvas, and its state is the
## twin's (bar the flag a game already sets on any press, `ANY_PRESS`).
## Why: docs/why/MiniGame.md#the-start-card-goes-on-any-click
func _tell_click(id: StringName) -> void:
	for d in range(1, 6):
		var a := MiniShell.new()
		var b := MiniShell.new()
		a.start(MiniGames.make(id), d, 1, MiniGames.stream(5), 5)
		a.tick(STEP)
		MiniKit.told_px = null
		b.start(MiniGames.make(id), d, 1, MiniGames.stream(5), 5)
		b.tick(STEP)
		var shown := MiniKit.told_px != null
		var card := Rect2i(MiniKit.told_at.position - a.at, MiniKit.told_at.size)
		a.press(EMPTY)
		a.release(EMPTY)
		var allow: Array = ANY_PRESS.get(id, [])
		var why := _state_diff(a.game, b.game, allow)
		MiniKit.told_px = null
		var n := 0
		var drawn := false
		while n < 10 and not drawn:
			drawn = a.tick(STEP)
			n += 1
		var gone := drawn and MiniKit.told_px == null
		for k in n:
			b.tick(STEP)
		var outside := 0
		if not id in CLOCK_STARTS:
			why += _state_diff(a.game, b.game, allow)
			outside = _differs_outside(a.game.px, b.game.px, card)
		_h._ok("%s depth %d: a click on empty glass hides the start card, nothing else (card %s, gone %s, %d px outside it%s)"
			% [id, d, shown, gone, outside, why], shown and gone and outside == 0 and why == "")


## The script variables that differ between two games, minus the card's own, the pointer, the frame.
func _state_diff(a: MiniGame, b: MiniGame, allow: Array) -> String:
	var skip := ["told", "pf", "dirty", "px"] + allow
	var out := ""
	for p: Dictionary in a.get_property_list():
		var n := String(p.name)
		if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) or n in skip:
			continue
		if _snap(a.get(n), 0) != _snap(b.get(n), 0):
			out += ", %s differs" % n
	return out


## A value as text for comparing twins: objects by their state, not their ids.
static func _snap(v: Variant, depth: int) -> String:
	if v is Dictionary:
		var parts: PackedStringArray = []
		for k: Variant in v:
			parts.append("%s:%s" % [str(k), _snap(v[k], depth + 1)])
		return "{" + ",".join(parts) + "}"
	if v is Array:
		var parts: PackedStringArray = []
		for e: Variant in v:
			parts.append(_snap(e, depth + 1))
		return "[" + ",".join(parts) + "]"
	if v is Callable:
		return "callable:" + String((v as Callable).get_method())
	if v is RandomNumberGenerator:
		return "rng:%d" % (v as RandomNumberGenerator).state
	if v is Object:
		var o := v as Object
		if o is Image or o is MiniPix or depth > 3 or o.get_script() == null:
			return o.get_class()
		var parts: PackedStringArray = []
		for p: Dictionary in o.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				parts.append("%s=%s" % [p.name, _snap(o.get(p.name), depth + 1)])
		return "obj(" + ",".join(parts) + ")"
	return var_to_str(v)


## How many pixels differ between two canvases outside box `r`.
static func _differs_outside(a: MiniPix, b: MiniPix, r: Rect2i) -> int:
	var n := 0
	for y in a.h:
		for x in a.w:
			if not r.has_point(Vector2i(x, y)) and a.img.get_pixel(x, y) != b.img.get_pixel(x, y):
				n += 1
	return n


## The shell round a game (status A, Nov 20): a scripted run through the glass (offset by where the
## game sits) ends it once, at the tier its score earns at sector 5; the win then the reward. While
## it plays the glass is the game's canvas and nothing leaves; 0.6 s after the end the result card
## is up with the game's END word and the paid NAME [TIER], and a click anywhere leaves.
func _shell(id: StringName) -> void:
	Audio.taping = true
	Audio.tape.clear()
	var sh := MiniShell.new()
	var tiers: Array[int] = []
	sh.scored.connect(func(tr: int) -> void:
		tiers.append(tr)
		sh.set_haul("TEST STOCK", &"legendary"))
	var g := MiniGames.make(id)
	sh.start(g, 5, 0, MiniGames.stream(11), 11)
	var sv := MiniSolver.for_game(g)
	var bare := _glass_is_game(sh)
	var no_leave := true
	var early := false
	for k in STEPS_MAX:
		if sh.revealed and sh.card_up():
			break
		for e in sv.act(g, STEP):
			_send_glass(sh, e)
		sh.tick(STEP)
		if sh.playing():
			no_leave = no_leave and not sh.leave_hit(Vector2(75, 70)) and not sh.leave_hit(Vector2(130, 135))
			if k % 10 == 0:
				bare = bare and _glass_is_game(sh)
		elif sh.card_up() and sh.t < sh._done_at + MiniKit.CARD_DELAY - 0.001:
			early = true
	Audio.taping = false
	var names: Array[String] = []
	for e: Array in Audio.tape:
		names.append(String(e[0]))
	_h._ok("%s on the glass: played through it, ended once (tiers %s)" % [id, str(tiers)], tiers.size() == 1 and tiers[0] == ScienceHaul.tier_of(sh.score, 5))
	_h._ok("%s on the glass: a clean run at sector 5 pays legendary (score %.2f)" % [id, sh.score], tiers.size() == 1 and tiers[0] == 4)
	var win := names.find("mg_win")
	var reward := names.find("mg_reward_4")
	_h._ok("%s: the win, then the reward a beat later (%s)" % [id, ", ".join(names.slice(maxi(0, names.size() - 6)))], win >= 0 and reward > win)
	_h._ok("%s: while it plays the glass is the game's canvas, nothing over it (no strip, no GIVE UP)" % id, bare)
	_h._ok("%s: while it plays a click leaves nothing" % id, no_leave)
	_h._ok("%s: the game names its end for the card (say_end: %s)" % [id, g.end_text], g.end_text != "" and sh.end_text == g.end_text)
	_card_checks(id, sh, early, "TEST STOCK", 4)
	_give_up(id)


## The card over the finished game: up only 0.6 s after the end, exactly `MiniKit.result_card` with
## the shell's END word and the paid NAME [TIER] (tier `ti`), the tier's ink on the glass, and a
## click anywhere on the glass leaves.
func _card_checks(id: StringName, sh: MiniShell, early: bool, name: String, ti: int) -> void:
	_h._ok("%s: the result card waits 0.6 s after the end, then is up" % id, not early and sh.card_up() and sh.revealed)
	var want := MiniPix.new(MiniShell.GW, MiniShell.GH)
	want.clear(MiniShell.BORDER)
	var src := Rect2i(Vector2i(maxi(0, -sh.at.x), maxi(0, -sh.at.y)), sh.game.px.img.get_size())
	src.size -= src.position
	want.img.blit_rect(sh.game.px.img, src, sh.at + src.position)
	var b := MiniKit.result_card(want, sh.end_text, sh.end_kind, name, ti, sh.t - sh._done_at)
	_h._ok("%s: the card is the kit's, %s over NAME [TIER] (%s %s)" % [id, sh.end_text, name, MiniKit.card_tag(ti)],
		b.size.x > 0 and sh.haul == name and sh.card_tier() == ti and want.img.get_data() == sh.glass.get_data())
	var ink := 0
	var quiet := 0
	for y in range(b.position.y + 17, b.position.y + 22):
		for x in range(b.position.x, b.end.x):
			var c := sh.glass.get_pixel(x, y)
			ink += 1 if c.is_equal_approx(UITheme.tier_colour(UITheme.TIER_ORDER[ti])) else 0
			quiet += 1 if c.is_equal_approx(MiniPix.COLD) else 0
	_h._ok("%s: the name in its tier's ink, then [TIER] quiet (%d, %d px)" % [id, ink, quiet], ink > 0 and quiet > 0)
	var anywhere := true
	for p: Vector2 in [Vector2(0, 0), Vector2(75, 70), Vector2(149.5, 139.5), Vector2(10, 130), Vector2(140, 20)]:
		anywhere = anywhere and sh.leave_hit(p)
	_h._ok("%s: once the card is up a click anywhere on the glass leaves" % id, anywhere)


## Esc (the desk calls `give_up`) while it plays: the game ends with GAVE UP, scores 0 to 0.2, the
## glass stays the game's until 0.6 s after, then the card is up.
func _give_up(id: StringName) -> void:
	var sh := MiniShell.new()
	sh.scored.connect(func(_tr: int) -> void: sh.set_haul("SLAG", &"common"))
	sh.start(MiniGames.make(id), 2, 0, MiniGames.stream(13), 13)
	for k in 6:
		sh.tick(STEP)
	sh.give_up()
	var ended := not sh.playing()
	var t0 := sh._done_at
	var bare := true
	while sh.t < t0 + MiniKit.CARD_DELAY - STEP * 1.5:
		sh.tick(STEP)
		bare = bare and not sh.card_up() and _glass_is_game(sh)
	var up := false
	for k in 4:
		sh.tick(STEP)
		up = up or sh.card_up()
	_h._ok("%s: Esc gives up (GAVE UP, score %.2f), the glass the game's until the card 0.6 s on" % [id, sh.score],
		ended and sh.score <= 0.2 and sh.end_text == MiniShell.GAVE_UP and bare and up)
	while not sh.revealed:
		sh.tick(STEP)
	_card_checks(id, sh, false, "SLAG", 0)


## The game area every game fills, the whole glass (Jon, Nov 19: no black bars; A, Nov 20: no strip).
const AREA := Vector2i(150, 140)


## Whether every pixel of the glass is the game's canvas (a 152-wide canvas shown without its outer columns).
static func _glass_is_game(sh: MiniShell) -> bool:
	var src := Rect2i(-sh.at, Vector2i(MiniShell.GW, MiniShell.GH))
	if not Rect2i(Vector2i.ZERO, sh.game.px.img.get_size()).encloses(src):
		return false
	return sh.game.px.img.get_region(src).get_data() == sh.glass.get_data()


static func _send_glass(sh: MiniShell, e: Dictionary) -> void:
	match String(e.k):
		"key":
			sh.key(e.key, true)
		"keyup":
			sh.key(e.key, false)
		"down":
			sh.press((e.p as Vector2) + Vector2(sh.at))
		"move":
			sh.motion((e.p as Vector2) + Vector2(sh.at))
		"up":
			sh.release((e.p as Vector2) + Vector2(sh.at))
