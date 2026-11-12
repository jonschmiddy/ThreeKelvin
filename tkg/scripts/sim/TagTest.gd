extends Node

## Tooltips are one sentence at the thing (stripped-down UI T1), a card's keywords are their
## own hover targets (T2), and the chart's JUMP is the biggest thing on its screen (C3).
##   tools/dev/godot.sh --headless --path tkg -- sheet=TagTest
## Why: docs/why/TagTest.md#test-purpose

var _tree: SceneTree
var h := Harness.new()


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _secs(s: float) -> void:
	await _tree.create_timer(s).timeout


func _screen() -> SectorScreen:
	return Router.current as SectorScreen


## A motion pushed as a real pointer's would arrive (BadgeTest's `_move_to`).
func _hover(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	get_viewport().push_input(mm, true)
	await _frames(2)


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	_pure()
	_glitch_rules()
	await _box()
	await _readout()
	await _local_tags()
	await _chart()
	await _words()
	h.verdict("tagtest")
	_tree.quit(h.code())


## THE TAG'S RULES, with no screen: the title goes, the tag sits above and clear.
func _pure() -> void:
	print("\n--- the tag's rules")
	_ok("the layer is up under Main's overlay", TagLayer.instance != null and TagLayer.instance.is_inside_tree())
	_ok("Godot's own tooltips are off (delay %s)" % str(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")),
		float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")) > 1000.0)
	_ok("a CAPS title line goes: \"%s\"" % TagLayer.plain("ENERGY\n\nWhat you have left to spend."),
		TagLayer.plain("ENERGY\n\nWhat you have left to spend.") == "What you have left to spend.")
	_ok("a first line that is not a title stays",
		TagLayer.plain("Korvan Heavy Works\nIt fires. Every time.") == "Korvan Heavy Works It fires. Every time.")
	_ok("wrapped lines read as one run of words",
		TagLayer.plain("DRAW\n\nWhat is left to draw;\nclick to look.") == "What is left to draw; click to look.")
	var bound := Rect2(0, 0, 960, 540)
	var thing := Rect2(400, 300, 60, 20)
	var sz := Vector2(120, 25)
	var p := HoloTag.place(sz, thing, bound)
	_ok("above the thing, centred, clear of it (%s)" % str(p), p.y + sz.y <= thing.position.y
		and not Rect2(p, sz).intersects(thing) and absf(p.x + sz.x * 0.5 - thing.get_center().x) < 1.0)
	var top := Rect2(400, 4, 60, 20)
	var p2 := HoloTag.place(sz, top, bound)
	_ok("no room above: below it, clear of it (%s)" % str(p2), p2.y >= top.end.y and not Rect2(p2, sz).intersects(top))
	var edge := Rect2(930, 300, 20, 20)
	var p3 := HoloTag.place(sz, edge, bound)
	_ok("at the screen's edge: slid inside (%s)" % str(p3), bound.encloses(Rect2(p3, sz)))
	var ls := HoloTag.sentence("At zero the ship is lost; a station repairs it for credits.")
	var widest := 0
	for l in ls:
		widest = maxi(widest, String((l as Array)[0]).length())
	_ok("a sentence wraps at %d letters (%d lines, widest %d)" % [UITheme.TOOLTIP_WRAP, ls.size(), widest],
		ls.size() >= 2 and widest <= UITheme.TOOLTIP_WRAP)
	var m := HoloTag.measure(ls)
	_ok("and measures to its lines (%s)" % str(m), m.y == ls.size() * HoloTag.LINE_H + HoloTag.PAD_V * 2 - 2)


## WEARS THIN (C-D, Jon, Nov 11), with no screen: G2 by default; steady for D_AFTER; a burst keeps
## the level it began on; 3-4 s of clean words between bursts at every level; reduced motion stills it.
func _glitch_rules() -> void:
	print("
--- the glitch's rules")
	var was_anim := Router.animate_in_harness
	Router.animate_in_harness = true
	DisplaySettings.reduced_motion = false
	var dial := HoloTag.glitch
	HoloTag.glitch = 0
	_ok("by default every tag follows the hull: G%d with it fine, G3 worn, G4 with the red, G5b dire" % HoloTag.level_now(),
		HoloTag.hull_level(0.0, 0.0, 0.0) == 2 and HoloTag.hull_level(0.6, 0.0, 0.0) == 3
		and HoloTag.hull_level(1.0, 0.6, 0.0) == 4 and HoloTag.hull_level(1.0, 1.0, 0.6) == HoloTag.G5B
		and HoloTag.hull_level(0.4, 0.0, 0.0) == 2)
	_ok("steady for its first D_AFTER s", HoloTag.glitch_at(HoloTag.D_AFTER - 0.05, 9001) == null)
	# a burst keeps its level: G2's first burst starts at D_AFTER; G4 asked for inside it
	HoloTag.glitch = 2
	HoloTag._sched.erase(9002)
	var g0 := HoloTag.glitch_at(HoloTag.D_AFTER + 0.001, 9002)
	HoloTag.glitch = 4
	var g1 := HoloTag.glitch_at(HoloTag.D_AFTER + 1.0 / HoloTag.G_HZ + 0.001, 9002)
	var later: HoloTag.Glitch = null
	for i in 200:
		later = HoloTag.glitch_at(HoloTag.D_AFTER + 2.0 + i / HoloTag.G_HZ, 9002)
		if later != null:
			break
	var l0 := g0.lvl if g0 != null else 0
	var l1 := g1.lvl if g1 != null else 0
	var l2 := later.lvl if later != null else 0
	_ok("a burst keeps the level it began on (G%d, G%d mid-burst), the next takes the new one (G%d)" % [l0, l1, l2],
		l0 == 2 and l1 == 2 and l2 == 4)
	# every level over 2 minutes open: the same 3-4 s of clean words between bursts; only the
	# bursts grow (Jon, Nov 11)
	for lv in [2, 3, 4, HoloTag.G5B]:
		HoloTag.glitch = lv
		HoloTag._sched.erase(9003 + lv)
		var runs: Array = []
		var start := -1.0
		var torn := 0
		for i in int(120.0 * HoloTag.G_HZ):
			var t := HoloTag.D_AFTER + (i + 0.5) / HoloTag.G_HZ
			var g := HoloTag.glitch_at(t, 9003 + lv)
			var on := g != null
			if on and g.tears.size() > 0 and g.chroma == HoloTag.G_CHROMA[lv - 1]:
				torn += 1
			if on and start < 0.0:
				start = t
			elif not on and start >= 0.0:
				runs.append([start, t])
				start = -1.0
		var longest := 0.0
		var lo := INF
		var hi := 0.0
		for j in runs.size():
			longest = maxf(longest, runs[j][1] - runs[j][0])
			if j > 0:
				var still: float = runs[j][0] - runs[j - 1][1]
				lo = minf(lo, still)
				hi = maxf(hi, still)
		var name := "G5b" if lv == HoloTag.G5B else "G%d" % lv
		_ok("%s: %d bursts in 2 min, each %.2f s at most, torn (%d frames); clean, untorn, unsplit %.2f-%.2f s between" % [
			name, runs.size(), longest, torn, lo, hi],
			runs.size() >= 28 and longest <= 0.51 and torn > 0 and lo >= 2.95 and hi <= 4.1)
	DisplaySettings.reduced_motion = true
	HoloTag.glitch = 5
	var calm_rm := true
	for i in 120:
		if HoloTag.glitch_at(HoloTag.D_AFTER + i / HoloTag.G_HZ, 9004) != null:
			calm_rm = false
	_ok("reduced motion: no glitch at any level (G5 for 4 s)", calm_rm)
	DisplaySettings.reduced_motion = false
	HoloTag.glitch = dial
	Router.animate_in_harness = was_anim


## THE BOX (Jon's pick of twenty, Nov 9): the plate is the same box, and the open watched frame
## by frame: the tag never moves or changes size and is whole by `OPEN`; then steady (C-D, Nov 11).
func _box() -> void:
	print("
--- the tag's box")
	var ls := HoloTag.sentence("At zero the ship is lost; a station repairs it for credits.")
	var m := HoloTag.measure(ls)
	var sb := HoloTag.plate()
	_ok("the plate is the same box: an 8 px slice tiled, the tag's margins (%s)" % str(m),
		UITheme.tag_plate() == sb and sb.texture.get_width() == 8 and sb.get_content_margin(SIDE_LEFT) == HoloTag.PAD_H
		and sb.get_content_margin(SIDE_TOP) == HoloTag.PAD_V and m.y == ls.size() * HoloTag.LINE_H + HoloTag.PAD_V * 2 - 2)
	var tag := HoloTag.new()
	tag.set_lines(ls)
	_tree.root.add_child(tag)
	var pos := tag.position
	var steady := true
	var frames := 0
	while tag.age() < HoloTag.OPEN:
		await _tree.process_frame
		frames += 1
		steady = steady and tag.size == m and tag.position == pos
	var age := tag.age()
	var idle := age - HoloTag.OPEN
	_ok("opens over %.2f s (%d frames), the box fixed at %s, %s" % [HoloTag.OPEN, frames, str(pos), str(m)],
		frames >= 2 and steady and tag.size == m and HoloTag.OPEN <= 0.25)
	_ok("opens steady: no glitch in its first %.1f s (at %.2f s)" % [HoloTag.D_AFTER, idle],
		tag.is_processing() and HoloTag.glitch_at(idle, tag.get_instance_id()) == null
		and HoloTag.glitch_at(HoloTag.D_AFTER - 0.1, tag.get_instance_id()) == null)
	tag.queue_free()
	await _frames(2)


## A PART'S READOUT (Jon, Nov 9): no flavour line anywhere a part is read out, and the cards in
## the hover readout bob a pixel each on its own beat while the plate and the words stay put.
func _readout() -> void:
	print("\n--- a part's readout")
	var m: ModuleData = null
	for id in DB.modules:
		var cand := DB.modules[id] as ModuleData
		if cand.flavour != "" and cand.resolved_cards().size() >= 2:
			m = cand
			break
	if not _ok("a part with flavour on its data and two cards", m != null):
		return
	var tip := ModuleIcon.tip_for(m)
	_tree.root.add_child(tip)
	await _frames(2)
	var texts: Array[String] = []
	for l in tip.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	var shows_flavour := false
	for t in texts:
		shows_flavour = shows_flavour or t.contains(m.flavour)
	_ok("the readout says its name and not its flavour", not shows_flavour
		and (texts.has(m.name.to_upper()) or texts.has(m.name)))
	var bobs := tip.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is ModuleIcon.BobCard)
	if not _ok("each card sits in its own bob holder (%d)" % bobs.size(), bobs.size() == m.resolved_cards().size()):
		tip.queue_free()
		return
	var holders: Array[Vector2] = []
	for b in bobs:
		holders.append((b as Control).position)
	var seen: Dictionary[float, bool] = {}
	var steady := true
	var within := true
	var smooth := true
	var last := INF
	var t0 := GameClock.now()
	while GameClock.now() - t0 < 1.0:
		await _tree.process_frame
		for k in bobs.size():
			var b := bobs[k] as ModuleIcon.BobCard
			steady = steady and b.position == holders[k] and tip.position == Vector2.ZERO
			var y := b.card.position.y
			within = within and absf(y) <= ModuleIcon.BobCard.SWING + 0.001
			if k == 0:
				# smooth: no frame moves the card more than a sliver (a step of a pixel would)
				smooth = smooth and (last == INF or absf(y - last) < 0.5)
				last = y
				seen[snappedf(y, 0.001)] = true
	var b0 := bobs[0] as ModuleIcon.BobCard
	var b1 := bobs[1] as ModuleIcon.BobCard
	_ok("the cards move smoothly, sub-pixel (%d distinct offsets in a second, within %.0f px); the holders never" % [
		seen.size(), ModuleIcon.BobCard.SWING], seen.size() >= 12 and smooth and within and steady)
	_ok("each on its own beat: periods %.1f and %.1f s, phases %.1f and %.1f" % [b0.period, b1.period, b0.phase, b1.phase],
		b0.period != b1.period and b0.phase != b1.phase and b0.period >= 1.6 and b1.period <= 2.4)
	_ok("none of it takes the mouse, and the cards are drawn bright, not dimmed (alpha %.2f)" % b0.card.modulate.a,
		b0.mouse_filter == Control.MOUSE_FILTER_IGNORE and b0.card.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and b0.card.modulate.a == 1.0 and (b0.card as CardView).playable)
	_ok("the row draws its pieces' shadows and sits them %d px apart" % tip.get_theme_constant("separation"),
		tip is ModuleIcon.ReadoutRow and tip.get_theme_constant("separation") >= 4)
	var icon := ModuleIcon.new()
	icon.setup(m, &"test")
	icon.position = Vector2(600, 300)
	_tree.root.add_child(icon)
	await _frames(2)
	await _hover(icon.get_global_rect().get_center())
	await _secs(TagLayer.DELAY + 0.15)
	var plate := TagLayer.instance.shown() as PanelContainer
	_ok("pointed at a part, its readout floats: no plate round it, no arrow, the row alone",
		plate != null and plate.get_theme_stylebox("panel") is StyleBoxEmpty and plate.get_child_count() == 1
		and plate.get_child(0) is ModuleIcon.ReadoutRow)
	await _hover(Vector2(480, 300))
	await _frames(3)
	icon.queue_free()
	var shelf := Widgets.module_readout(m)
	var shelf_texts: Array[String] = []
	for l in shelf.find_children("*", "Label", true, false):
		shelf_texts.append((l as Label).text)
	var shelf_flavour := false
	for t in shelf_texts:
		shelf_flavour = shelf_flavour or t.contains(m.flavour)
	_ok("the module readout alone has no flavour line either", not shelf_flavour)
	shelf.free()
	tip.queue_free()
	await _frames(2)


## THE HUD'S HULL GAUGE pointed at on LOCAL: the tag above it, clear, one sentence, no title;
## gone when the pointer leaves. Then a rich tooltip (the hull's perks) on the torn plate.
func _local_tags() -> void:
	print("\n--- a tag at the thing")
	Router.animate_in_harness = true
	h.seed_run(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for n: MapGen.MapNode in Run.map:
		if n.index > 0 and n.type == MapGen.NodeType.SYSTEM and not n.cleared \
				and n.region != MapGen.Region.FAUNA:
			Run.at = n.index
			break
	Run.map[Run.at].visited = true
	SectorScreen._approached_at = Run.at
	Router.show_local()
	await _frames(120)
	var layer := TagLayer.instance
	var gauge: Control = Router.hud._hull
	var gr := gauge.get_global_rect()
	await _hover(gr.get_center())
	await _frames(3)
	_ok("resting on the hull gauge: no tag before the delay", layer.shown() == null)
	await _secs(TagLayer.DELAY + 0.15)
	var tag := layer.shown() as HoloTag
	if not _ok("after the delay, the torn tag is up", tag != null):
		return
	var tr := Rect2(tag.global_position, tag.size)
	var screen := Rect2(Vector2.ZERO, Vector2(960, 540))
	_ok("above the gauge or below it, never on it (%s vs %s)" % [str(tr), str(gr)], not tr.intersects(gr)
		and (tr.end.y <= gr.position.y + 0.5 or tr.position.y >= gr.end.y - 0.5))
	_ok("inside the screen", screen.encloses(tr))
	_ok("the arrow points at the gauge (point %d: the tag is %s it)" % [tag.point, "above" if tag.point > 0 else "below"],
		tag.point == (1 if tr.end.y <= gr.position.y + 0.5 else -1))
	var words := ""
	for l in tag.lines:
		words += String((l as Array)[0]) + " "
	words = words.strip_edges()
	_ok("one sentence, no title: \"%s\"" % words, words == TagLayer.plain(gauge.tooltip_text) and words.count(".") == 1
		and words.to_upper() != words)
	_ok("the HUD's heat and fuel say one sentence each too",
		TagLayer.plain(Router.hud._heat.tooltip_text).count(".") == 1
		and TagLayer.plain(Router.hud._fuel.tooltip_text).count(".") == 1)
	await _hover(Vector2(480, 300))
	await _frames(3)
	_ok("pointed away, the tag is gone", layer.shown() == null)
	# a rich tooltip keeps its body, on the torn plate
	var sc := _screen()
	var box := PerkBox.new()
	box.tooltip_text = "PERKS"
	box.custom_minimum_size = Vector2(40, 20)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.position = Vector2(600, 400)
	sc.add_child(box)
	await _frames(2)
	await _hover(box.get_global_rect().get_center())
	await _secs(TagLayer.DELAY + 0.15)
	var plate := layer.shown() as PanelContainer
	_ok("a rich tooltip (the hull's perks) comes up on the plate, above the thing",
		plate != null and plate.get_child_count() >= 1 and plate.get_child(0) is Control and not plate.get_child(0) is TagLayer.PlateArrow
		and plate.get_theme_stylebox("panel") is StyleBoxTexture
		and plate.global_position.y + plate.size.y <= box.get_global_rect().position.y + 0.5)
	var sbp := plate.get_theme_stylebox("panel") as StyleBoxTexture if plate != null else null
	_ok("the plate wears the box: its slice, its margins, and the arrow pointing down at the thing",
		sbp == HoloTag.plate() and sbp.get_content_margin(SIDE_LEFT) == HoloTag.PAD_H
		and plate.get_child_count() == 2 and plate.get_child(1) is TagLayer.PlateArrow
		and (plate.get_child(1) as TagLayer.PlateArrow).point == 1)
	await _hover(Vector2(480, 300))
	await _frames(3)
	box.queue_free()
	await _frames(2)


## THE CHART (C3): JUMP a big plate with the star's name, the panel down to what decides the
## jump, the survey on the star's tag.
func _chart() -> void:
	print("\n--- the chart")
	Router.show_starchart()
	for i in 600:
		await _tree.process_frame
		if Router.current is StarchartScreen and not ZoomLadder.busy() and i > 30:
			break
	await _frames(10)
	var ch := Router.current as StarchartScreen
	if not _ok("the chart is up", ch != null):
		return
	_ok("nothing picked: the galaxy's blurb shows", ch._dest_blurb.visible and ch._dest_blurb.text != "")
	_ok("JUMP is %d px tall (at least %d), where it was 24" % [int(ch._jump.size.y), StarchartScreen.JUMP_H],
		ch._jump.size.y >= StarchartScreen.JUMP_H)
	var here: MapGen.MapNode = Run.node_at()
	var go: MapGen.MapNode = null
	var far: MapGen.MapNode = null
	for n: MapGen.MapNode in Run.map:
		# (one on a lane from here: the tag prices only a lane's jump, `MapChart.tip_lines`;
		# G2's seed put a jumpable star off the lanes first, Nov 10)
		if n.index != here.index and n.sensed and Run.can_jump_to(n) and here.links.has(n.index) and go == null:
			go = n
		if n.index != here.index and not Run.can_jump_to(n) and n.type == MapGen.NodeType.SYSTEM and far == null:
			far = n
	if not _ok("a star to jump to and one out of reach", go != null and far != null):
		return
	ch._on_node_picked(go.index)
	await _frames(3)
	var nb := ch._jump.get_theme_stylebox("normal") as StyleBoxFlat
	_ok("picked: JUMP on the ember plate, the star's name on it (\"%s\" / \"%s\")" % [ch._jump.text, ch._jump_to.text],
		ch._jump.text == "JUMP" and not ch._jump.disabled and ch._jump_to.text == MapGen.star_name(go)
		and nb != null and nb.bg_color == UITheme.EMBER)
	_ok("the name sits inside the plate", ch._jump.get_global_rect().encloses(ch._jump_to.get_global_rect()))
	_ok("the blurb is gone with a star picked", not ch._dest_blurb.visible)
	var hz := MapGen.hazards(go).size()
	_ok("the panel keeps danger, fuel and warnings: %d rows for %d hazards" % [ch._rows.get_child_count(), hz],
		ch._rows.get_child_count() == 2 + hz)
	var tip := ch._chart.tip_lines(go, here)
	_ok("the star's tag is a few lines (Q1): the name, what is there, the place, danger and fuel: %s" % " / ".join(tip),
		tip.size() == 4 and tip[0] == MapGen.star_name(go) and tip[3].begins_with("DANGER") and tip[3].contains("FUEL"))
	ch._on_node_picked(far.index)
	await _frames(3)
	var db := ch._jump.get_theme_stylebox("disabled") as StyleBoxFlat
	_ok("out of reach: the refusal word on the dark plate, no name (\"%s\")" % ch._jump.text,
		ch._jump.disabled and ch._jump.text != "JUMP" and ch._jump_to.text == "" and db != null
		and db.bg_color == UITheme.VOID)
	_ok("the plate is the same size either way", ch._jump.size.y >= StarchartScreen.JUMP_H)


## POINT AT A WORD (T2): in a fight, a keyword pointed at lights and its sentence sits on the
## card's picture at once; the whole-card readout is gone from the hand.
func _words() -> void:
	print("\n--- a word on a card")
	Router.show_local()
	await _frames(90)
	Router.start_combat(DB.enemies[&"cutter"], [], false, true)
	var sc: SectorScreen = null
	for i in 600:
		await _tree.process_frame
		sc = _screen()
		if sc != null and sc.fighting() and not sc._hold and not sc._opening and i > 90 \
				and sc._hand._views.size() > 0:
			break
	await _frames(60)
	sc = _screen()
	if not _ok("a fight is up with a hand", sc != null and sc.fighting() and sc._hand._views.size() > 0):
		return
	var v: CardView = null
	for cv: CardView in sc._hand._views:
		if not cv.card.keywords().is_empty():
			v = cv
			break
	if not _ok("a card with a keyword in hand", v != null):
		return
	var term := String((v.card.keywords()[0] as Array)[0])
	var meaning := String((v.card.keywords()[0] as Array)[1])
	_ok("the word is a hover target on the card ([url=%s])" % term, v._body.text.contains("[url=%s]" % term)
		and v._body.mouse_filter == Control.MOUSE_FILTER_PASS)
	var at_word := Vector2(4.0, 4.0)
	_ok("the word is found under the pointer by measure (%s -> \"%s\"), nothing off the text" % [str(at_word), v.word_at(at_word)],
		v.word_at(at_word) == term and v.word_at(Vector2(v._body.size.x - 2.0, 36.0)) == "")
	var mm := InputEventMouseMotion.new()
	mm.position = at_word
	v._body.gui_input.emit(mm)
	await _frames(2)
	_ok("a motion over the word lights it", v.lit_word == term and sc.word_tag() != null)
	v._body.mouse_exited.emit()
	await _frames(2)
	_ok("leaving the text puts it out", v.lit_word == "" and sc.word_tag() == null)
	sc._on_card_hovered(v, true)
	await _secs(1.2)
	_ok("resting on the card opens no whole-card readout", sc.word_tag() == null
		and sc._readout_layer().get_child_count() == 0)
	v._on_word(term, true)
	await _frames(2)
	var tag := sc.word_tag() as HoloTag
	_ok("pointed at %s: its tag is up at once" % term, tag != null and v.lit_word == term)
	_ok("the word lights in the highlight colour", v._body.text.contains(UITheme.MARK.to_html(false)))
	if tag != null:
		var words := ""
		for l in tag.lines:
			words += String((l as Array)[0]) + " "
		_ok("the tag says the keyword's one sentence", words.strip_edges() == meaning)
		var art := Rect2(v.global_position + CardView.Z_ART.position, CardView.Z_ART.size)
		var tr := Rect2(tag.global_position, tag.size)
		_ok("sitting on the card's picture (%s on %s), the arrow pointing down at the words" % [str(tr), str(art)],
			tr.intersects(art) and absf(tr.end.y - art.end.y) <= 1.0 and Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(tr)
			and tag.point == 1)
	v._on_word(term, false)
	await _frames(2)
	_ok("pointed off the word: the tag goes, the word is plain", sc.word_tag() == null and v.lit_word == ""
		and not v._body.text.contains(UITheme.MARK.to_html(false)))
	v._on_word(term, true)
	await _frames(1)
	v._on_hover_out()
	await _frames(2)
	_ok("leaving the card takes the tag with it", sc.word_tag() == null and v.lit_word == "")
