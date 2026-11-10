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
	await _looks()
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
	var p := TornTag.place(sz, thing, bound)
	_ok("above the thing, centred, clear of it (%s)" % str(p), p.y + sz.y <= thing.position.y
		and not Rect2(p, sz).intersects(thing) and absf(p.x + sz.x * 0.5 - thing.get_center().x) < 1.0)
	var top := Rect2(400, 4, 60, 20)
	var p2 := TornTag.place(sz, top, bound)
	_ok("no room above: below it, clear of it (%s)" % str(p2), p2.y >= top.end.y and not Rect2(p2, sz).intersects(top))
	var edge := Rect2(930, 300, 20, 20)
	var p3 := TornTag.place(sz, edge, bound)
	_ok("at the screen's edge: slid inside (%s)" % str(p3), bound.encloses(Rect2(p3, sz)))
	var ls := TornTag.sentence("At zero the ship is lost; a station repairs it for credits.")
	var widest := 0
	for l in ls:
		widest = maxi(widest, String((l as Array)[0]).length())
	_ok("a sentence wraps at %d letters (%d lines, widest %d)" % [UITheme.TOOLTIP_WRAP, ls.size(), widest],
		ls.size() >= 2 and widest <= UITheme.TOOLTIP_WRAP)
	var m := TornTag.measure(ls)
	_ok("and measures to its lines (%s)" % str(m), m.y == ls.size() * TornTag.LINE_H + TornTag.PAD_V * 2 - 2)


## THE TEN BOXES (`-- tiplook=N`): each a whole-pixel 9-slice the words fit inside, the plate
## for a rich body the same box, today's tag back when the dial is 0.
func _looks() -> void:
	print("
--- the tag's boxes")
	_ok("the dial rests on today's tag (%d of %d looks)" % [TornTag.look, TipFrames.LOOKS],
		TornTag.look == 0 and TipFrames.LOOKS == 10 and TipFrames.NAMES.size() == 11)
	var ls := TornTag.sentence("At zero the ship is lost; a station repairs it for credits.")
	var today := TornTag.measure(ls)
	var f := UITheme.pixel_font()
	var widest := 0.0
	for l in ls:
		widest = maxf(widest, f.get_string_size(String((l as Array)[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x)
	var host := Control.new()
	_tree.root.add_child(host)
	for look in range(1, TipFrames.LOOKS + 1):
		TornTag.look = look
		var p := TipFrames.pad(look)
		var sb := TipFrames.box(look)
		var tex := sb.texture as ImageTexture
		var m := TornTag.measure(ls)
		var tag := TornTag.new()
		tag.set_lines(ls)
		host.add_child(tag)
		await _frames(2)
		var fits := m.x >= widest + p.position.x + p.size.x and m.y >= ls.size() * TornTag.LINE_H + p.position.y + p.size.y - 2
		var whole := tex != null and tex.get_width() == tex.get_height() and sb.get_content_margin(SIDE_LEFT) == p.position.x 			and sb.get_content_margin(SIDE_TOP) == p.position.y and sb.texture_margin_left * 2 < tex.get_width()
		_ok("%2d %-11s a whole-pixel slice of %d, margins %s; the words fit (%s), no smaller than today" % [look,
			TipFrames.NAMES[look], tex.get_width() if tex != null else 0, str(p), str(m)],
			whole and fits and m.x >= today.x and m.y >= today.y and tag.size == m and m == m.round()
			and UITheme.torn_box() == sb)
		if look == 3:
			_ok("   HUD types its words on: %.2f at once, all there after %.2f s" % [tag._reveal, TipFrames.REVEAL],
				tag._reveal < 1.0)
			await _secs(TipFrames.REVEAL + 0.1)
			_ok("   and they are", tag._reveal >= 1.0 and not tag.is_processing())
		tag.queue_free()
	TornTag.look = 0
	_ok("the dial back at 0: today's measure (%s)" % str(TornTag.measure(ls)), TornTag.measure(ls) == today
		and UITheme.torn_box().texture_margin_left == 2)
	host.queue_free()
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
	var tag := layer.shown() as TornTag
	if not _ok("after the delay, the torn tag is up", tag != null):
		return
	var tr := Rect2(tag.global_position, tag.size)
	var screen := Rect2(Vector2.ZERO, Vector2(960, 540))
	_ok("above the gauge or below it, never on it (%s vs %s)" % [str(tr), str(gr)], not tr.intersects(gr)
		and (tr.end.y <= gr.position.y + 0.5 or tr.position.y >= gr.end.y - 0.5))
	_ok("inside the screen", screen.encloses(tr))
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
	_ok("a rich tooltip (the hull's perks) comes up on the torn plate, above the thing",
		plate != null and plate.get_child_count() == 1 and plate.get_theme_stylebox("panel") is StyleBoxTexture
		and plate.global_position.y + plate.size.y <= box.get_global_rect().position.y + 0.5)
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
		if n.index != here.index and n.sensed and Run.can_jump_to(n) and go == null:
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
	_ok("the star's tag carries the survey (%d lines): %s" % [tip.size(), " / ".join(tip)],
		tip.size() >= 6 and tip[0] == MapGen.star_name(go) and tip[3].begins_with("DANGER"))
	var survey := MapChart.survey_lines(go, here)
	_ok("with the star, how built up and policed, who runs it, and the heading",
		survey.size() >= 3 and survey[0].contains("STAR") and survey[1].contains("SECURITY")
		and (survey[survey.size() - 1].contains("WARD") or survey[survey.size() - 1] == "LATERAL"))
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
	var tag := sc.word_tag() as TornTag
	_ok("pointed at %s: its tag is up at once" % term, tag != null and v.lit_word == term)
	_ok("the word lights in the highlight colour", v._body.text.contains(UITheme.MARK.to_html(false)))
	if tag != null:
		var words := ""
		for l in tag.lines:
			words += String((l as Array)[0]) + " "
		_ok("the tag says the keyword's one sentence", words.strip_edges() == meaning)
		var art := Rect2(v.global_position + CardView.Z_ART.position, CardView.Z_ART.size)
		var tr := Rect2(tag.global_position, tag.size)
		_ok("sitting on the card's picture (%s on %s)" % [str(tr), str(art)], tr.intersects(art)
			and absf(tr.end.y - art.end.y) <= 1.0 and Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(tr))
	v._on_word(term, false)
	await _frames(2)
	_ok("pointed off the word: the tag goes, the word is plain", sc.word_tag() == null and v.lit_word == ""
		and not v._body.text.contains(UITheme.MARK.to_html(false)))
	v._on_word(term, true)
	await _frames(1)
	v._on_hover_out()
	await _frames(2)
	_ok("leaving the card takes the tag with it", sc.word_tag() == null and v.lit_word == "")
