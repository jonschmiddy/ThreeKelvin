extends Node

## One mark means "this one" (stripped-down UI C1, Jon, Nov 9): the mint outline on the card you
## point at and a deck, the ember brackets (`MarkOutline`) on your ship, an enemy and a wreck,
## nothing marked at rest; the fight's aim as on main, the armed card in its orange.
##   tools/dev/godot.sh --headless --path tkg -- sheet=MarkTest
## Why: docs/why/MarkTest.md#test-purpose

var _tree: SceneTree
var h := Harness.new()


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _screen() -> SectorScreen:
	return Router.current as SectorScreen


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	_theme()
	await _fight()
	h.verdict("marktest")
	_tree.quit(h.code())


## THE ONE COLOUR, on every hover box the theme and the widgets build.
func _theme() -> void:
	print("\n--- the theme")
	_ok("MARK is its own colour, none of the palette's", not [UITheme.ICE, UITheme.HOT, UITheme.FLARE,
		UITheme.GOOD, UITheme.TRACTOR, UITheme.CHILL, UITheme.EMBER].has(UITheme.MARK))
	_ok("the outline is 2 px", UITheme.MARK_PX == 2)
	var t := UITheme.build()
	var hover := t.get_stylebox("hover", "Button") as StyleBoxFlat
	_ok("a button's hover box is the outline: MARK, %d px" % UITheme.MARK_PX,
		hover != null and hover.border_color == UITheme.MARK and hover.border_width_top == UITheme.MARK_PX)
	_ok("and its text stays its resting colour, not FLARE",
		t.get_color("font_hover_color", "Button") == t.get_color("font_color", "Button"))
	var normal := t.get_stylebox("normal", "Button")
	_ok("a hovered button is the size it was at rest",
		hover.get_minimum_size() == normal.get_minimum_size())
	var commit := Widgets.commit(Button.new())
	var ch := commit.get_theme_stylebox("hover") as StyleBoxFlat
	_ok("a commit plate's hover is the same outline", ch != null and ch.border_color == UITheme.MARK
		and ch.border_width_left == UITheme.MARK_PX)
	var ob := UITheme.outline_boxes()
	_ok("a quiet button's hover is the same outline", (ob.hover as StyleBoxFlat).border_color == UITheme.MARK)
	var m := MarkOutline.new()
	var mat := m.material as ShaderMaterial
	_ok("a picture's mark is the fight's brackets in FLARE (Jon's pick, Nov 9), the picture untouched",
		mat != null and mat.get_shader_parameter("col") == UITheme.FLARE and m.get_child_count() == 0)
	m.free()
	_ok("the cutaway's hull outline is that outline", CutawayView.Outline.new() is MarkOutline)
	var st := StationScreen.new()
	var cell := st._deck_cell(&"services", "SHIPYARD", "repairs")
	var dh := cell.get_theme_stylebox("hover") as StyleBoxFlat
	_ok("a deck cell's hover is the outline and nothing at rest", dh != null and dh.border_color == UITheme.MARK
		and dh.border_width_top == UITheme.MARK_PX and cell.get_theme_stylebox("normal") is StyleBoxEmpty)
	cell.free()
	st.free()


## THE FIGHT: nothing at rest, the card and its target outlined while aimed, the line up, all
## gone on release; then the wreck under the pointer.
func _fight() -> void:
	print("\n--- a fight")
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
	var sc := _screen()
	if not _ok("LOCAL is up with your ship", sc != null and sc._ship_outline != null):
		return
	_ok("your ship's hover outline is the one outline, off at rest",
		sc._ship_outline is MarkOutline and not sc._ship_outline.visible)
	Router.start_combat(DB.enemies[&"cutter"], [], false, true)
	for i in 600:
		await _tree.process_frame
		sc = _screen()
		if sc != null and sc.fighting() and not sc._hold and not sc._opening and i > 90 \
				and sc._hand._views.size() > 0:
			break
	await _frames(60)
	sc = _screen()
	var v := sc._view if sc != null else null
	if not _ok("a fight is up with a hand", sc != null and v != null and sc.combat != null and sc._hand._views.size() > 0):
		return
	var slot := v.slot(0)
	_ok("the enemy has the outline, off at rest, and no brackets", slot != null and slot.mark != null
		and not slot.mark.visible and slot.mark.art == slot.art and not slot._hot)
	_ok("your hull in the fight has no outline, no brackets", v._ship_slot.mark == null and not v._ship_slot._hot)
	var rest_marked := 0
	for cv: CardView in sc._hand._views:
		if cv.marked:
			rest_marked += 1
	_ok("no card is outlined at rest", rest_marked == 0)
	_ok("no aim line at rest", sc._aim_line == null or not sc._aim_line.visible)

	# pointed at: the card lifts and is outlined, in its own colours
	var card: CardView = null
	for cv: CardView in sc._hand._views:
		if sc.combat.can_play(cv.card) and cv.card.damage > 0:
			card = cv
			break
	if not _ok("a playable attack card to point at", card != null):
		return
	var tint0: Color = card._tint
	card._on_hover_in()
	await _frames(12)
	_ok("pointed at, the card is outlined and lifted 8 px", card.marked
		and is_equal_approx(card.position.y, card._base_y - 8.0))
	_ok("its glyph tint is its manufacturer's, not FLARE", card._tint == tint0 and card._tint != UITheme.FLARE)
	card._on_hover_out()
	await _frames(12)
	_ok("pointed away, the outline goes", not card.marked)

	# aimed at the enemy: card, line and target
	var from := card.get_global_rect().get_center()
	sc._on_card_grabbed(card, from)
	var to := slot.get_global_transform() * slot.ink_rect().get_center()
	# (the first move decides the gesture, the second arms it, the third is tracked)
	for p in [from + Vector2(0, -6), to, to]:
		var mm := InputEventMouseMotion.new()
		mm.position = p
		sc._input(mm)
	await _frames(3)
	_ok("aimed, the card is armed and framed in the aim's orange (Jon, Nov 9)", sc._aim_view == card and card.armed
		and card.marked)
	_ok("the target wears the brackets as on main, not the outline; your hull neither",
		slot._hot and not slot.mark.visible and not v._ship_slot._hot)
	_ok("the wavy line is up, the old one (its lock and waves)", sc._aim_line != null and sc._aim_line.visible
		and sc._aim_line is AimLine and AimLine.LOCK_R == 8.0 and AimLine.WAVE_F.size() == 2)
	await _tree.create_timer(0.3).timeout
	# the lifted card draws whole (Jon, Nov 9: its top was clipped by the hand panel)
	var cr := card.get_global_rect()
	var clipped := ""
	var anc: Node = card.get_parent()
	while anc != null:
		var ac := anc as Control
		if ac != null and ac.clip_contents and not ac.get_global_rect().grow(0.5).encloses(cr):
			clipped = ac.name if ac.name != "" else str(ac)
		anc = anc.get_parent()
	_ok("the armed card and its frame lie whole in the picture, clipped by nothing (%s)" % str(cr),
		clipped == "" and Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(cr) and cr.position.y < sc._hand_holder.get_global_rect().position.y)
	var dim := 0
	for cv: CardView in sc._hand._views:
		if not sc.combat.can_play(cv.card) and not is_equal_approx(cv.modulate.a, UITheme.DIM):
			dim += 1
	_ok("a card you cannot pay for sits at DIM (%.2f)" % UITheme.DIM, dim == 0)
	# aimed at nothing: the target's outline goes, the card stays armed
	var mm2 := InputEventMouseMotion.new()
	mm2.position = Vector2(480.0, 120.0)
	sc._input(mm2)
	await _frames(2)
	_ok("aimed at empty space, nothing on the board is lit", not slot._hot and not v._ship_slot._hot
		and not slot.mark.visible and card.marked)
	# let go there: everything goes
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = false
	mb.position = Vector2(480.0, 120.0)
	sc._input(mb)
	await _frames(3)
	_ok("let go over nothing: the card is back, no outline, no line, the card still in hand",
		sc._aim_view == null and not card.armed and not card.marked and not sc._aim_line.visible
		and sc.combat.hand.has(card.card) and not slot._hot)

	# C2: out of moves, everything but END TURN steps back
	await _dim(sc, v)
	# the wreck: outlined under the pointer once it can be opened
	await _wreck(sc, v)


## DIM THE REST (C2): with nothing playable on your turn the screen dims round END TURN, which
## lights ember; nothing moves; a move coming back lifts it.
func _dim(sc: SectorScreen, v: EncounterView) -> void:
	print("
--- dim the rest")
	var boxes_before: Array[Rect2] = _boxes(sc, v)
	_ok("with a card to play, nothing is dimmed", not sc.dimmed())
	# out of energy: dimmed exactly when no card in the hand is free
	var energy0 := sc.combat.energy
	sc.combat.energy = 0
	Sig.player_combat_state_changed.emit()
	await _frames(30)
	var free := 0
	for c: CardData in sc.combat.hand:
		if sc.combat.can_play(c):
			free += 1
	_ok("out of energy with %d free card(s) in hand: dimmed %s" % [free, str(sc.dimmed())], sc.dimmed() == (free == 0))
	# an empty hand: END TURN is the one move
	var hand0: Array = sc.combat.hand.duplicate()
	sc.combat.hand.clear()
	Sig.hand_changed.emit()
	await _tree.create_timer(0.6).timeout
	_ok("nothing in hand: the screen dims round END TURN", sc.dimmed() and sc._dim != null and sc._dim.visible
		and sc._dim.alpha > sc._dim.ALPHA - 0.01)
	_ok("the hole is END TURN's own box", sc._dim.hole == _end_button(sc).get_global_rect())
	_ok("the glass takes no clicks", sc._dim.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var nb := _end_button(sc).get_theme_stylebox("normal") as StyleBoxFlat
	_ok("END TURN lights ember", nb != null and nb.bg_color == UITheme.EMBER
		and _end_button(sc).get_theme_color("font_color") == UITheme.VOID and not _end_button(sc).disabled)
	_ok("nothing clickable moved", _boxes(sc, v) == boxes_before)
	sc._playing = true
	await _frames(3)
	_ok("while the turn plays out, no dim", not sc.dimmed())
	sc._playing = false
	await _frames(3)
	_ok("and back once it has", sc.dimmed())
	# the hand and the energy back: a move again
	sc.combat.hand.assign(hand0)
	sc.combat.energy = energy0
	Sig.hand_changed.emit()
	Sig.player_combat_state_changed.emit()
	await _tree.create_timer(0.6).timeout
	var nb2 := _end_button(sc).get_theme_stylebox("normal") as StyleBoxFlat
	_ok("a move comes back: the dim lifts and END TURN is plain again", not sc.dimmed()
		and (sc._dim == null or not sc._dim.visible) and nb2 != null and nb2.bg_color != UITheme.EMBER
		and _end_button(sc).get_theme_color("font_color") != UITheme.VOID)
	_ok("and still nothing moved", _boxes(sc, v) == boxes_before)


func _end_button(sc: SectorScreen) -> Button:
	return sc._end_button


## The fixed clickable things on the fight screen: the three buttons, the piles, your hull.
func _boxes(sc: SectorScreen, v: EncounterView) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for b: Control in [sc._end_button, sc._flee_button, sc._hail_button, sc._draw_pile, sc._discard_pile, v._ship_slot]:
		out.append(b.get_global_rect())
	return out


func _wreck(sc: SectorScreen, v: EncounterView) -> void:
	print("
--- a wreck")
	var slot := v.slot(0)
	sc.combat.damage_enemy(9999, 1, "test")
	# a win lowers the band and lands on LOCAL by itself, the wreck where the ship was
	var seen_dead_unmarked := true
	for i in 1800:
		await _tree.process_frame
		sc = _screen()
		if sc == null:
			continue
		if is_instance_valid(slot) and slot._dead and slot.mark.visible:
			seen_dead_unmarked = false
		if sc.settled_local() and sc._view.slot(0) != null and sc._view.slot(0)._dead 				and sc._view.slot(0).opened.is_valid() and sc._view.slot(0).modulate.a > 0.99:
			break
	await _frames(30)
	sc = _screen()
	var w := sc._view.slot(0) if sc != null else null
	if not _ok("the fight is won and LOCAL is up with an openable wreck", w != null and w._dead and w.opened.is_valid()):
		return
	_ok("the dead ship wore no outline on the way down", seen_dead_unmarked)
	_ok("the wreck is not outlined at rest", not w.mark.visible)
	var on := InputEventMouseMotion.new()
	on.position = w.ink_rect().get_center()
	w._gui_input(on)
	await _frames(2)
	_ok("pointed at its hull, the wreck wears the outline", w.mark.visible)
	var off := InputEventMouseMotion.new()
	off.position = Vector2(-50.0, -50.0)
	w._gui_input(off)
	await _frames(2)
	_ok("pointed off it, the outline goes", not w.mark.visible)
	w._gui_input(on)
	await _frames(1)
	w.mouse_exited.emit()
	await _frames(1)
	_ok("and leaving the slot takes it off too", not w.mark.visible)
