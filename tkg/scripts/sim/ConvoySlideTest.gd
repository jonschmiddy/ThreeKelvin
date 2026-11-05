extends Node

## THE CONVOY COLUMN COMES AND GOES BY SLIDING (J4 B, Jon, Nov 5), AND THE
## STUNNED TAG:
##   tools/dev/godot.sh --headless --path tkg --fixed-fps 60 -- sheet=ConvoySlideTest
##   tools/dev/render.sh --path tkg --resolution 1920x1080 --fixed-fps 60 -- sheet=ConvoySlideTest out=<dir>
##   tools/dev/render.sh --path tkg --resolution 1920x1080 --fixed-fps 30 --write-movie <dir>/slide.avi -- sheet=ConvoySlideTest film=1
##
## Jon: "The column appears when a partner arrives. Your ship slides 220 px
## right, and each enemy moves and drops to half size, under a card you may be
## dragging. If that player leaves ... the column disappears and the ship
## slides back to the single player view." Through a real fight on the game's
## own session hosting a party (VELA a roster row, CoreWinTest's way), the
## animations on (`Router.animate_in_harness`):
##   - a card is aimed at an enemy, then VELA arrives: the column slides in,
##     every frame a whole pixel (the column's room, the row's offset, your
##     hull slot), never back, over `EncounterView.SLIDE_T`; your hull slot
##     ends `column_w` + the row's separation right, the enemies move; the
##     card stays in hand, armed, the same CardView all the way (nothing in the
##     hand is made again); released over an enemy at its new place, it is
##     played;
##   - the box test at rest: the column's hulls, your hull and its plate, and
##     every enemy's boxes inside the picture and clear of each other;
##   - MERCER walks in on turn 2, stunned: his slot carries STUNNED under its
##     gauges, inside the label's 92 px and the slot, clear of the name and
##     the bars; gone when the turn moves;
##   - both leave, with a card aimed again: the column slides out, whole
##     pixels, and every rect is back where it was before, to the pixel; the
##     card is still armed and is played on release;
##   - your own ship joining VELA's fight on turn 2: the drawer's "Stunned."
##     line inside the hand's area and clear of END TURN and the piles.
## `out=` photographs each state at 1920 x 1080 (2x); `film=1` plays only the
## slide in and out, in real time, for `--write-movie`.

const PORT := DirectTransport.DEFAULT_PORT + 37

var _tree: SceneTree
var _fails := 0
var _out := ""
var _film := false
var _idx := -1


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _arg(k: String, d: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(k + "="):
			return (a as String).substr(k.length() + 1)
	return d


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	_out = _arg("out")
	_film = _arg("film") == "1"
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	Router.animate_in_harness = true
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for n: MapGen.MapNode in Run.map:
		if n.index > 0 and n.type == MapGen.NodeType.SYSTEM and not n.cleared \
				and n.region != MapGen.Region.FAUNA:
			_idx = n.index
			break
	Run.at = _idx
	Run.map[_idx].visited = true
	Run.map[_idx].danger = 4
	SectorScreen._approached_at = _idx
	Router.show_local()
	await _frames(120)
	var t := DirectTransport.new()
	t.port = PORT
	t.advertise = "127.0.0.1"
	if not _ok("the game's session hosts a party", Net.host_party("Kevin", &"korvan", t) != ""):
		_finish()
		return
	_partner(777, "Vela", &"redline", -1, 1)
	_partner(888, "Mercer", &"solari", -1, 2)
	Router.start_combat(DB.enemies[&"lancer"], [DB.enemies[&"cutter"]], false, true)
	await _settle_screen()
	var v := _view()
	var sc := _screen()
	if not _ok("a fight is up, the party's", v != null and sc != null and Router.combat != null and Router.combat.is_shared()):
		_finish()
		return
	if _film:
		await _film_run(v)
		_finish()
		return
	await _shot("01_alone")
	var before := _layout(v)
	_ok("alone in the room: no column (pad %s, row offset %d)" % [str(v._convoy_pad.visible), int(v._row.offset_left)],
		not v._convoy_pad.visible and int(v._row.offset_left) == 0)

	# --- VELA arrives, under an aimed card
	print("\n--- VELA arrives while a card is aimed")
	var card := _aim(sc, v, 0)
	if not _ok("a card is aimed at an enemy", card != null and sc._aim_view != null):
		_finish()
		return
	var views0 := sc._hand._views.duplicate()
	_here(777, true)
	var steps := await _watch_slide(v, sc, card, 1.0)
	var after := _layout(v)
	var want := v.column_w() + v._row.get_theme_constant("separation")
	_ok("your hull's slot ends %d px right (column %d + separation): %d" % [want, v.column_w(),
		int(after.slot.position.x - before.slot.position.x)],
		int(after.slot.position.x - before.slot.position.x) == want)
	_ok("over %d frames, about SLIDE_T (%.2f s)" % [steps, EncounterView.SLIDE_T],
		steps >= int(EncounterView.SLIDE_T * 60.0) - 2 and steps <= int(EncounterView.SLIDE_T * 60.0) + 3)
	_ok("your hull moved right (%d -> %d)" % [int(before.hull.position.x), int(after.hull.position.x)],
		after.hull.position.x > before.hull.position.x)
	var moved := 0
	for i in before.foes.size():
		if i < after.foes.size() and (after.foes[i] as Rect2).position != (before.foes[i] as Rect2).position:
			moved += 1
	_ok("every enemy moved (%d of %d), scales %s -> %s" % [moved, before.foes.size(), str(before.scales), str(after.scales)],
		moved == before.foes.size())
	_ok("nothing in the hand was made again", sc._hand._views == views0)
	# VELA's own arrival plays on in the column (the flare, then her approach)
	await _frames(330)
	_ok("and the card is still armed once she has arrived", sc._aim_view != null and sc._aim_view.card == card)
	_box_test(v, "column in")
	await _shot("02_column_in")
	# released at the enemy's new place: played
	var played := _release_on_enemy(sc, v, card, 0)
	await _frames(4)
	_ok("released over the enemy where it is now, the card is played", played and not Router.combat.hand.has(card))

	# --- MERCER walks in on turn 2, stunned
	print("\n--- MERCER walks in on turn 2, stunned")
	Router.combat.end_turn()
	await _frames(30)
	var f := Net.fight_at(_idx)
	_ok("the party's fight is on turn 2", f != null and f.turn == 2)
	_here(888, true)
	await _frames(2)
	Net._open_or_join(_idx, f.foe_ids, PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), -1, 888, 2)
	await _settle_slide(v)
	# its arrival plays out in the column (the flare, then its approach), as
	# VELA's did, so the picture shows the ship and not the flare
	await _frames(330)
	var m := _slot_of(v, 888)
	if _ok("MERCER's slot is in the column, stunned", m != null and m.stunned_shown()):
		var tag := m.stun_tag_rect()
		var slot_r := Rect2(Vector2.ZERO, m.size)
		var fs := UITheme.FS_SMALL
		var bars_bottom := float(fs) + 3.0 + EncounterView.ConvoySlot.BAR_H * 2.0 + 1.0
		_ok("the tag is inside the label's %d px and the slot (%s in %s)" % [int(EncounterView.ConvoySlot.BAR_W), str(tag), str(slot_r)],
			tag.end.x <= EncounterView.ConvoySlot.BAR_W and slot_r.encloses(tag))
		_ok("and under the name and the bars (top %.0f, bars end %.0f)" % [tag.position.y, bars_bottom],
			tag.position.y >= bars_bottom)
	_box_test(v, "two in the column")
	await _shot("03_partner_stunned")
	var vm := _slot_of(v, 777)
	_ok("VELA, on turn 1's crew... not in this fight: no tag", vm != null and not vm.stunned_shown())
	# the turn moves: the tag goes
	Router.combat.end_turn()
	await _frames(30)
	m = _slot_of(v, 888)
	_ok("the turn moves and MERCER's tag goes", m != null and not m.stunned_shown())
	Net._apply_leave(_idx, 888)

	# --- both leave, under an aimed card
	print("\n--- both leave while a card is aimed")
	await _frames(10)
	var card2 := _aim(sc, v, 0)
	_ok("a card is aimed again", card2 != null and sc._aim_view != null)
	var views1 := sc._hand._views.duplicate()
	_here(777, false)
	_here(888, false)
	var steps2 := await _watch_slide(v, sc, card2, 0.0)
	var at_end := _layout(v)
	print("    at the slide's end: hull %s, foes %s" % [str(at_end.hull), str(at_end.foes)])
	await _frames(40)
	var back := _layout(v)
	print("    before: hull %s, foes %s" % [str(before.hull), str(before.foes)])
	print("    back:   hull %s, foes %s" % [str(back.hull), str(back.foes)])
	_ok("the column is gone (pad %s, row offset %d) after %d frames" % [str(v._convoy_pad.visible), int(v._row.offset_left), steps2],
		not v._convoy_pad.visible and int(v._row.offset_left) == 0)
	_ok("your hull's slot is back to the pixel (%s, was %s)" % [str(back.slot), str(before.slot)], back.slot == before.slot)
	_ok("your hull is back to the pixel (%s, was %s)" % [str(back.hull), str(before.hull)], back.hull == before.hull)
	var same := true
	for i in before.foes.size():
		if i >= back.foes.size() or (back.foes[i] as Rect2) != (before.foes[i] as Rect2):
			same = false
	_ok("every enemy is back where it was, at its size (%s, scales %s)" % [str(back.foes), str(back.scales)],
		same and back.scales == before.scales)
	_ok("nothing in the hand was made again", sc._hand._views == views1)
	await _shot("04_column_out")
	var played2 := _release_on_enemy(sc, v, card2, 0)
	await _frames(4)
	_ok("and the card held through it is played on release", played2 and not Router.combat.hand.has(card2))

	# --- your own ship, joining on turn 2
	print("\n--- your own ship joins VELA's fight on turn 2")
	await _own_stun()
	_finish()


## Your own ship walks into VELA's fight at the next system on its turn 2.
func _own_stun() -> void:
	Router.drop_combat()
	var at := -1
	for n: MapGen.MapNode in Run.map:
		if n.index > _idx and n.type == MapGen.NodeType.SYSTEM and not n.cleared \
				and n.region != MapGen.Region.FAUNA:
			at = n.index
			break
	Run.at = at
	Run.map[at].visited = true
	Run.map[at].danger = 4
	SectorScreen._approached_at = at
	Router.show_local()
	await _frames(120)
	var plan := Combat.new()
	plan.plan(DB.enemies[&"lancer"], 4, [DB.enemies[&"cutter"]])
	Net._open_or_join(at, plan.foe_ids(), plan.foe_hp(), plan.foe_brace(), plan.foe_hp_now(), -1, 777, Net.party_count())
	Net.forced_target = 777
	Net._apply_end_turn(at, 777)
	Net.forced_target = 0
	_here(777, true, at)
	await _frames(60)
	Router.join_fight()
	await _settle_screen()
	var sc := _screen()
	var cb := Router.combat
	if not _ok("joined VELA's fight on turn 2, stunned", sc != null and cb != null and cb.stunned):
		return
	var note := sc._stun_note
	var hand_r: Rect2 = sc._hand.get_global_rect()
	var nr := EnemySlot.text_rect(note)
	_ok("the drawer's line is up, inside the hand's area (%s in %s)" % [str(nr), str(hand_r)],
		note.is_visible_in_tree() and hand_r.encloses(nr))
	var clear := true
	for c: Control in [sc._end_button, sc._draw_pile, sc._discard_pile, sc._flee_button, sc._hail_button]:
		if c != null and c.is_visible_in_tree() and c.get_global_rect().intersects(nr):
			clear = false
			print("    the line meets %s %s" % [c.name, str(c.get_global_rect())])
	_ok("and clear of END TURN, FLEE, HAIL and the piles", clear)
	await _shot("05_stunned_you")


# --- the slide ----------------------------------------------------------------

## Frames until the column's room reaches `to`, each checked: whole pixels,
## one way only, the aimed card still in hand and armed. Returns the frames.
func _watch_slide(v: EncounterView, sc: SectorScreen, card: CardData, to: float) -> int:
	var prev := _layout(v)
	var frames := 0
	var whole := true
	var one_way := true
	var armed := true
	var biggest := 0.0
	var started := false
	var view: CardView = sc._aim_view
	for i in 600:
		await _tree.process_frame
		var now := _layout(v)
		if not started and v.sliding():
			started = true
		if started:
			frames += 1
		for x in [now.pad, now.offset, now.slot.position.x, now.slot.size.x]:
			if not is_equal_approx(float(x), round(float(x))):
				whole = false
		var dx: float = now.slot.position.x - prev.slot.position.x
		biggest = maxf(biggest, absf(dx))
		if (to > 0.5 and dx < 0.0) or (to < 0.5 and dx > 0.0):
			one_way = false
		if sc._aim_view != view or not is_instance_valid(view) or not view.armed or not Router.combat.hand.has(card):
			armed = false
		prev = now
		if started and not v.sliding() and is_equal_approx(v.column_slide(), to):
			break
	_ok("the column slid %s: %d frames, every one a whole pixel (biggest step %d px)" % [
		"in" if to > 0.5 else "out", frames, int(biggest)], started and whole)
	_ok("never back the way it came", one_way)
	_ok("the aimed card stayed in hand, armed, the same view, all the way", armed)
	return frames


## Wait for a slide already started (a partner arriving off-test) to finish.
func _settle_slide(v: EncounterView) -> void:
	for i in 300:
		await _tree.process_frame
		if not v.sliding():
			return


## What the slide moves, in whole numbers where they are whole.
func _layout(v: EncounterView) -> Dictionary:
	var foes: Array = []
	var scales: Array = []
	for s in v._made:
		if is_instance_valid(s) and (s as EnemySlot).visible:
			foes.append((s as EnemySlot).get_global_rect())
			scales.append((s as EnemySlot).art.draw_scale if (s as EnemySlot).art != null else 0.0)
	return {pad = v._convoy_pad.custom_minimum_size.x if v._convoy_pad.visible else 0.0,
		offset = v._row.offset_left, slot = v._ship_slot.get_global_rect(),
		hull = v.player_boxes()[0] if not v.player_boxes().is_empty() else Rect2(),
		foes = foes, scales = scales}


## Aim the first card that can be played at enemy `i`, as a press on it and a
## drag out of the drawer up to the enemy do. The card, or null.
func _aim(sc: SectorScreen, v: EncounterView, i: int) -> CardData:
	var cb := Router.combat
	for view: CardView in sc._hand._views:
		if not is_instance_valid(view) or not cb.can_play(view.card):
			continue
		var s := v.slot(i)
		if s == null or not s.aimable(view.card):
			continue
		var from := view.get_global_rect().get_center()
		sc._on_card_grabbed(view, from)
		var to := s.get_global_rect().get_center()
		for p in [from + Vector2(0, -6), to]:
			var mm := InputEventMouseMotion.new()
			mm.position = p
			sc._input(mm)
		var mm2 := InputEventMouseMotion.new()
		mm2.position = to
		sc._input(mm2)
		if sc._aim_view == view:
			return view.card
		sc._end_aim(false)
	return null


## Let go over enemy `i` where it is now. Whether a play was asked for.
func _release_on_enemy(sc: SectorScreen, v: EncounterView, card: CardData, i: int) -> bool:
	if sc._aim_view == null or sc._aim_view.card != card:
		return false
	var s := v.slot(i)
	var at := s.get_global_rect().get_center()
	var mm := InputEventMouseMotion.new()
	mm.position = at
	sc._input(mm)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = false
	mb.position = at
	sc._input(mb)
	return true


## At rest: the column's hulls, your hull and its plate, and every enemy's
## boxes inside the picture and clear of each other.
func _box_test(v: EncounterView, tag: String) -> void:
	var view_r := v.get_global_rect()
	var mine: Array[Rect2] = v.player_boxes()
	var col: Array[Rect2] = []
	for s in v._made_convoy:
		if is_instance_valid(s) and not (s as EncounterView.ConvoySlot).leaving():
			col.append((s as Control).get_global_rect())
	var foes: Array = []
	for s in v._made:
		if is_instance_valid(s) and (s as EnemySlot).visible:
			for b in (s as EnemySlot).boxes():
				foes.append([(s as EnemySlot).index, b[0], b[1]])
	var bad: PackedStringArray = []
	for r in mine + col:
		if not view_r.encloses(r):
			bad.append("outside: %s" % str(r))
	for e in foes:
		if not view_r.grow(1.0).encloses(e[2]):
			bad.append("enemy %d %s outside" % [e[0], e[1]])
		for r in mine:
			if (e[2] as Rect2).intersects(r):
				bad.append("enemy %d %s on your ship" % [e[0], e[1]])
		for r in col:
			if (e[2] as Rect2).intersects(r):
				bad.append("enemy %d %s on the column" % [e[0], e[1]])
	for r in mine:
		for c in col:
			if r.intersects(c):
				bad.append("your ship on the column")
	_ok("(%s) the box test: the column, your hull and plate, every enemy's boxes inside and apart%s" % [
		tag, (": " + "; ".join(bad)) if not bad.is_empty() else ""], bad.is_empty())


# --- the film -----------------------------------------------------------------

func _film_run(v: EncounterView) -> void:
	await _secs(1.0)
	_here(777, true)
	await _settle_slide(v)
	# her arrival in the column, then a beat
	await _secs(5.0)
	_here(777, false)
	for i in 600:
		await _tree.process_frame
		if not v._convoy_pad.visible:
			break
	await _secs(1.0)


## Game seconds, as the frames' own time steps add up (`--fixed-fps` films).
func _secs(s: float) -> void:
	var t := 0.0
	while t < s:
		await _tree.process_frame
		t += get_process_delta_time()


# --- plumbing -----------------------------------------------------------------

func _partner(id: int, who: String, hull: StringName, at: int, order: int) -> void:
	var ct: Variant = load("res://scripts/sim/ConvoyTest.gd")
	var b: ShipBuild = ct._build(hull, HullData.Weight.MEDIUM, [
		[ModuleData.Slot.WEAPON, 0, hull], [ModuleData.Slot.SYSTEM, 0, hull]])
	b.pilot = who
	Net.roster[id] = {"id": id, "name": who, "hull": hull, "ready": true, "order": order,
		"build": b.to_wire(), "at": at}


## A partner into this system, or out of it, as its presence says.
func _here(id: int, on: bool, at: int = -1) -> void:
	Net.roster[id]["at"] = (Run.at if at < 0 else at) if on else -1
	Sig.party_changed.emit()


func _slot_of(v: EncounterView, id: int) -> EncounterView.ConvoySlot:
	for s in v._made_convoy:
		if is_instance_valid(s) and (s as EncounterView.ConvoySlot).peer == id:
			return s
	return null


func _screen() -> SectorScreen:
	return Router.current as SectorScreen if Router.current is SectorScreen else null


func _view() -> EncounterView:
	var sc := _screen()
	return sc._view if sc != null else null


## The fight screen up and still: its band raised, its pack placed.
func _settle_screen() -> void:
	for i in 600:
		await _tree.process_frame
		var sc := _screen()
		if sc != null and sc.fighting() and not sc._hold and not sc._opening and i > 90:
			break
	await _frames(60)


func _shot(name: String) -> void:
	if _out == "":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _tree.root.get_texture().get_image()
	if img != null:
		img.save_png(_out.path_join(name + ".png"))
		print("  shot %s.png" % name)


func _finish() -> void:
	Net.leave_party()
	print("convoyslidetest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
