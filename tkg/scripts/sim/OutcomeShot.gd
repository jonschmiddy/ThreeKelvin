extends Node

## WHAT YOU END UP WITH, photographed in every look (`OutcomeRow`):
##   godot --path . -- sheet=OutcomeShot out=<dir> [cases=jon,gain,...] [looks=today,A,B,C,D,E]
##   godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 30
##       -- sheet=OutcomeShot out=<dir> film=C case=mix
##   godot --headless --path . -- sheet=OutcomeShot survey
##
## REAL OUTCOMES, FOUND NOT MADE UP. Every authored choice is resolved through
## `OptionResolve.take` -- the one rule -- on a fresh copy of one system from
## the same starting ship, over a few seeds of the event stream, and each case
## takes the first that does what it asks:
##   jon      the Drifting Lifepod cracked open and its trap fired: hull only
##   gain     credits and a part, nothing lost
##   mix      credits up, fuel down, heat up
##   card     a part alone: the only way an event offers a card is a part's
##   nothing  a choice taken that moved nothing
##   credits  credits and nothing else
##   big      the outcome that moved the most
## Then each is played on the real LOCAL: the event asked for as the map's GO
## asks (`LocalEventDrawer.request`), the band up, the choice taken, and the
## result drawn in every look, stills of the whole 1920x1080 window
## (`<look>_<case>.png`) and the band cut out of it at that 2x
## (`<look>_<case>_band.png`); C also mid-flight (`C_<case>_fly.png`). Writes
## `index.json`: each still, its case, the option and choice and seed, the
## entries as drawn with their boxes, and the band's.
##
## `survey` prints every kind of change the authored choices make, and how
## often, headless.
## `film=C case=<id>` films that case under C at true speed: the band up, the
## choice, the text arriving, the flights, then a second and a half. Prints
## `mark <name> <frame>`.
## Needs a window but for `survey`.


var _args: PackedStringArray
var _out := ""
var _film := false
var _frame0 := 0


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


## Wait: whole frames when filming (the movie writer's clock), the wall's
## otherwise.
func _wait(s: float) -> void:
	if _film:
		for i in int(round(s * 30.0)):
			await get_tree().process_frame
		return
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		await RenderingServer.frame_post_draw


func _run() -> void:
	var tree := get_tree()
	_out = _arg("out", "user://outcomeshot")
	_film = _arg("film") != ""
	DirAccess.make_dir_recursive_absolute(_out)
	await tree.process_frame
	# 1080P STILLS: the game drawn 2x into a 1920x1080 window, as Jon plays it
	# (the settings file can leave the window at 960x540 whatever the command
	# line says)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		for i in 6:
			await tree.process_frame
	print("  outcomeshot: window %s, screen %s, root %s" % [DisplayServer.window_get_size(), DisplayServer.screen_get_size(), tree.root.get_texture().get_size()])
	LocalEventDrawer.quiet = true
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n := _system()
	var found: Dictionary = await OutcomeCheck.find_cases(n, "survey" in _args)
	if "survey" in _args:
		tree.quit()
		return
	var cases: Array = _arg("cases", "jon,gain,mix,card,nothing,credits,big").split(",")
	if _film:
		cases = [_arg("case", "mix")]
	var looks: Array = _arg("looks", "today,A,B,C,D,E").split(",")
	if _film:
		looks = [_arg("film")]
	var index: Array = []
	for c in cases:
		if not found.has(c):
			print("  outcomeshot: NO CASE %s" % c)
			continue
		var f: Dictionary = found[c]
		print("  outcomeshot: case %s = %s choice %d seed %d: %s" % [c, f.id, f.j, f.seed, f.sig])
		index.append_array(await _play(n, String(c), f, looks))
	if not _film:
		var fh := FileAccess.open(_out + "/index.json", FileAccess.WRITE)
		fh.store_string(JSON.stringify({cases = _case_notes(found, cases), shots = index}, "  "))
		fh.close()
	OutcomeRow.look = &"today"
	LocalEventDrawer.quiet = false
	print("  outcomeshot: done")
	tree.quit()


# ------------------------------------------------------------------ the survey

func _case_notes(found: Dictionary, cases: Array) -> Dictionary:
	var notes := {}
	for c in cases:
		if found.has(c):
			notes[c] = found[c]
	return notes


# ------------------------------------------------------------------ on LOCAL

func _play(n: MapGen.MapNode, case_id: String, f: Dictionary, looks: Array) -> Array:
	var shots: Array = []
	OutcomeCheck.reset(n, StringName(f.id), int(f.seed))
	n.visited = true
	SectorScreen._approached_at = n.index
	SystemMapScreen._parked.erase(n.index)
	# THE EVENT AS THE MAP'S GO ASKS FOR IT: LOCAL composes for it and the band
	# comes up once the move has landed
	LocalEventDrawer.request(n.index, 0)
	Router.show_local()
	var d: LocalEventDrawer = null
	var tries := 0
	while tries < 300:
		await _wait(0.05)
		tries += 1
		var lo := Router.current as SectorScreen
		d = lo.get("_events") if lo != null else null
		if d != null and d.page == &"event":
			break
	if d == null or d.page != &"event":
		print("  outcomeshot: FAIL %s: the band never came up" % case_id)
		return shots
	if _film:
		print("mark band_up %d" % Engine.get_frames_drawn())
		# read like a player: the text arrives, then a beat, then the click
		while d.text != null and not d.text.done:
			await get_tree().process_frame
		await _wait(0.8)
	else:
		# until the ladder has landed and the band's text is in for good: the
		# band can be opened again by the landing, which starts its text over
		var still := 0
		while still < 5:
			await _wait(0.1)
			if ZoomLadder.busy():
				still = 0
				continue
			if d.text != null and not d.text.done:
				d.text.skip()
				still = 0
			else:
				still += 1
	# the same rolls the survey saw
	Rng.event.seed = int(f.seed)
	Rng.loot.seed = int(f.seed) * 7 + 1
	Rng.world.seed = int(f.seed) * 13 + 5
	if _film:
		OutcomeRow.look = StringName(looks[0])
		print("mark choose %d" % Engine.get_frames_drawn())
	var got: Dictionary = await d.choose(int(f.j))
	if d.page != &"result":
		print("  outcomeshot: FAIL %s: no result page (%s, page %s, text done %s)" % [case_id, got, d.page, d.text.done if d.text != null else "-"])
		return shots
	if _film:
		# the result's text arriving at its own pace, then C's flights
		var k := 0
		while not d.out.get("flown", false) and k < 900:
			await get_tree().process_frame
			k += 1
		print("mark text_done %d" % Engine.get_frames_drawn())
		await _wait(2.5)
		print("mark end %d" % Engine.get_frames_drawn())
		return shots
	for lk in looks:
		OutcomeRow.look = StringName(lk)
		d.out.erase("flown")
		d._result()
		await _wait(0.15)
		if d.text != null:
			d.text.skip()
		if lk == "C":
			# mid-flight: the second change takes off one stagger after the first
			await _wait(OutcomeRow.FLY_S * 0.5)
			_shot("C_%s_fly" % case_id, d, shots, case_id, f, "C", true)
			await _wait(OutcomeRow.FLY_S + OutcomeRow.STAGGER_S * 6.0 + 0.4)
		else:
			await _wait(0.5)
		_shot("%s_%s" % [lk, case_id], d, shots, case_id, f, String(lk), false)
	return shots


func _shot(name: String, d: LocalEventDrawer, shots: Array, case_id: String, f: Dictionary, lk: String, fly: bool) -> void:
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	# THE BAND AT 2x, out of the window as shown: the game is drawn 2x into a
	# 1920x1080 window, so the band's game rect doubled, a few px of the scene
	# above it kept
	var k := float(img.get_width()) / 960.0
	var band := d.panel.get_global_rect()
	var r := Rect2i(Vector2i(0, int((band.position.y - 6.0) * k)), Vector2i(img.get_width(), int((band.size.y + 6.0) * k)))
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png("%s/%s_band.png" % [_out, name])
	var ents: Array = []
	for e: Dictionary in OutcomeCheck.entries(d):
		var er: Rect2 = e.rect
		ents.append({text = e.text, rect = [er.position.x, er.position.y, er.size.x, er.size.y]})
	var flying: Array = []
	for c in d.get_children():
		if c is OutcomeRow.Flight:
			for a: Dictionary in (c as OutcomeRow.Flight).in_air():
				flying.append({text = OutcomeRow.line_text(a.e), at = [a.at.x, a.at.y]})
	var cont := d.panel.find_child("Continue", true, false) as Control
	var cr := cont.get_global_rect() if cont != null else Rect2()
	shots.append({file = name + ".png", band_crop = name + "_band.png", look = lk, case = case_id,
		option = f.id, choice = f.j, seed = f.seed, fly = fly,
		band = [band.position.x, band.position.y, band.size.x, band.size.y],
		continue_btn = [cr.position.x, cr.position.y, cr.size.x, cr.size.y],
		entries = ents, in_air = flying, held = OutcomeRow.held.duplicate(),
		fails = OutcomeCheck.boxes(d, StringName(lk), OutcomeCheck.entries(d))})
	print("  outcomeshot: %s  %s" % [name, " | ".join(ents.map(func(x: Dictionary) -> String: return String(x.text)))])


## The first ordinary system of the run, with the ship at it.
func _system() -> MapGen.MapNode:
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.SYSTEM:
			OptionTable.ensure(m)
			Run.at = m.index
			return m
	return null
