extends Node

## THE CUSTODIAN'S BADGE (`CustodianBadge`, on `GoalLine`), on the real screens,
## headless:
##   godot --headless --fixed-fps 60 --path . -- sheet=BadgeTest
##
## Badge 9b, "The eye opens, loud" (eye-1b), approved by Jon on Nov 4. Through
## a real run, the real HUD and its goal line, and the real Router; no stub.
##
##   1. THE LADDER FROM DATA: the core boss is the one ENGAGE fights at the core
##      (`DB.core_boss`), it wakes at 16 and is at full strength from 33 by its
##      own growth (`EnemyTemplate.hull_at`), and every jump 0 to 40 has the
##      page's stage, tier, countdown and transition.
##   2. THE APPROVED PIXELS: every frame in `badge_golden.json` (the page's own
##      code drawing them, `tools/dev/badge/dump_golden.py`): `paint` gives the
##      same bytes, the digits too; the digits table is the game font's glyphs;
##      every transition ends on its stage's idle frame 0.
##   3. ON EVERY SCREEN, every jump 0 to 40: LOCAL, the map, the chart and a
##      fight. Up with the line, 6 blank columns after GOAL: REACH THE CORE, its
##      middle row on the capitals' middle, inside the line's room; the union of
##      every frame it inks clear of everything `GoalTest` keeps the line off
##      (its own list), of the step's line under it and of A.S.H.'s spots.
##   4. THE ARRIVAL, ONCE A JUMP: at 10 steps a second on the game's clock,
##      ending in idle; never again moving between screens, after a save is
##      loaded, or on the chart a real jump left from; and, animated, never
##      before the ship has stopped and the line is fully up.
##   5. IDLE, PER SECOND: each stage's changes a second as the page measured
##      them, never above 12, no frame shorter than its rate, FULL the same every
##      second; on screen it repaints only when the frame changes.
##   6. THE TOOLTIP: after the HUD's quarter second, gone on leaving, the page's
##      lines under the boss's name from data (renaming it renames them), no hull
##      figure, on the theme's tooltip plate, clear of the goal, the badge and
##      everything on the screen.
##   7. THE MOUSE: nothing in it takes the mouse or looks pressable, the picture
##      under it is what the pointer is over, a press there reaches the chart,
##      and nothing clickable moves for it.

const GoalTestScript := preload("res://scripts/sim/GoalTest.gd")
const GOLDEN := "res://scripts/sim/badge_golden.json"

var _tree: SceneTree
var _fails := 0
## the union of every pixel the badge inks at a jump (local to its corner), by jump
var _ink := {}


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	await _frames(40)
	_ladder()
	await _core_boss()
	_golden()
	_digits_are_the_font()
	_ends_on_idle()
	_per_second()
	_tooltip_words()
	await _repaints()
	await _screens()
	await _arrivals()
	await _hover_and_mouse()
	await _no_growth()
	_finish()


func _goal() -> GoalLine:
	return Router.hud.goal if Router.hud != null and is_instance_valid(Router.hud) else null


func _badge() -> CustodianBadge:
	var g := _goal()
	return g.badge() if g != null else null


# ------------------------------------------------------------------ 1. the ladder

## The page's table (core.js stage, tier, countdown, changeKind), with the
## game's jump 0 (asleep, 16 to go) and its tick at jump 1.
func _expect(j: int) -> Array:
	var st := &"S0" if j <= 15 else (&"WAKE" if j == 16 else (&"S1" if j <= 19 else (&"S2" if j <= 24 else (&"S3" if j < 33 else &"FULL"))))
	var tr := 0 if j <= 15 else (1 if j <= 19 else (2 if j <= 24 else (3 if j < 33 else 4)))
	var cd := 16 - j if j <= 15 else 0
	var k := &"wake" if j == 16 else (&"worse" if j == 20 or j == 25 else (&"full" if j == 33 else (&"tick" if j >= 1 and j <= 15 else &"none")))
	return [st, tr, cd, k]


func _ladder() -> void:
	var e := DB.core_boss()
	if not _ok("the core boss is in the data (%s)" % (e.name if e != null else "none"), e != null and e.boss):
		return
	var l := CustodianBadge.ladder()
	_ok("the ladder from its growth: free to %d, wakes at %d, worse at %d and %d, full from %d (want 15, 16, 20, 25, 33)" % [
		l.free, l.wake, l.s2, l.s3, l.full], l.grows and l.free == 15 and l.wake == 16 and l.s2 == 20 and l.s3 == 25 and l.full == 33)
	var top := roundi(e.max_hull * e.grow_cap)
	_ok("which is where its hull is: %d at %d, %d at %d, %d at %d, the cap %d at %d" % [e.hull_at(15), 15, e.hull_at(16), 16,
		e.hull_at(32), 32, e.hull_at(33), 33], e.hull_at(15) == e.max_hull and e.hull_at(16) > e.max_hull
		and e.hull_at(32) < top and e.hull_at(33) == top)
	var bad: Array[String] = []
	for j in 41:
		var want := _expect(j)
		var got := [CustodianBadge.stage(j), CustodianBadge.tier(j), CustodianBadge.countdown(j), CustodianBadge.change_kind(j)]
		if got != want:
			bad.append("%d: %s, not %s" % [j, got, want])
	_ok("jumps 0 to 40: the page's stage, tier, countdown and transition (%s)" % ("all" if bad.is_empty() else "; ".join(bad)), bad.is_empty())
	_ok("the transitions last 0.4, 1.2, 0.8, 0.8 and 1.0 s (tick, wake, 20, 25, full)",
		is_equal_approx(CustodianBadge.trans_len(5), 0.4) and is_equal_approx(CustodianBadge.trans_len(16), 1.2)
		and is_equal_approx(CustodianBadge.trans_len(20), 0.8) and is_equal_approx(CustodianBadge.trans_len(25), 0.8)
		and is_equal_approx(CustodianBadge.trans_len(33), 1.0) and CustodianBadge.trans_len(17) == 0.0)


## ENGAGE at the core fights `DB.core_boss()`: the badge watches the boss the
## run ends on.
func _core_boss() -> void:
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.CORE:
			idx = n.index
	if not _ok("the galaxy has a core", idx >= 0):
		return
	var was := Run.at
	Run.at = idx
	Run.map[idx].visited = true
	Router.show_local()
	await _frames(5)
	Router.engage_here()
	var cb: Combat = null
	for i in 30:
		cb = Router.combat
		if cb != null and not cb.enemies.is_empty():
			break
		await _frames(1)
	_ok("ENGAGE at the core fights the core boss (%s)" % (cb.enemies[0].template.name if cb != null and not cb.enemies.is_empty() else "no fight"),
		cb != null and not cb.enemies.is_empty() and cb.enemies[0].template.id == DB.core_boss().id)
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.at = was if was < Run.map.size() else Run.at
	Router.show_local()
	await _frames(40)


# ------------------------------------------------------------------ 2. the approved pixels

func _golden() -> void:
	var txt := FileAccess.get_file_as_string(GOLDEN)
	var doc: Variant = JSON.parse_string(txt)
	if not _ok("the page's frames load (%s)" % GOLDEN, doc is Dictionary):
		return
	var w := int(doc.w)
	var h := int(doc.h)
	var raw: PackedByteArray = Marshalls.base64_to_raw(String(doc.rgba_gzip_b64)).decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var frames: Array = doc.frames
	_ok("%d frames, %d x %d, letter spacing %d as the page set it" % [frames.size(), w, h, int(doc.letter_spacing)],
		w == CustodianBadge.IMG_W and h == CustodianBadge.IMG_H and raw.size() == frames.size() * w * h * 4 and int(doc.letter_spacing) == 0)
	var bad: Array[String] = []
	var boxes_bad: Array[String] = []
	for i in frames.size():
		var f: Dictionary = frames[i]
		var b := PackedByteArray()
		b.resize(w * h * 4)
		var box := CustodianBadge.paint(b, int(doc.x), int(doc.cy), int(f.j), float(f.t), float(f.since))
		var want := raw.slice(i * w * h * 4, (i + 1) * w * h * 4)
		if b != want:
			for p in w * h:
				var o := p * 4
				if b.slice(o, o + 4) != want.slice(o, o + 4):
					bad.append("j%d %s: first at (%d,%d) %s, the page %s" % [int(f.j), f.what, p % w, p / w,
						Array(b.slice(o, o + 4)), Array(want.slice(o, o + 4))])
					break
		var wb: Array = f.box
		if box != Rect2i(int(wb[0]), int(wb[1]), int(wb[2]), int(wb[3])):
			boxes_bad.append("j%d %s %s, the page %s" % [int(f.j), f.what, box, wb])
	_ok("every frame pixel for pixel as the page draws it, the digits too (%s)" % ("%d frames" % frames.size() if bad.is_empty()
		else "%d differ: %s" % [bad.size(), "; ".join(bad.slice(0, 8))]), bad.is_empty())
	_ok("and the box each says it inks in (%s)" % ("all" if boxes_bad.is_empty() else "; ".join(boxes_bad.slice(0, 6))), boxes_bad.is_empty())
	# the tooltip's lines, as the page wrote them (jumps 1 to 40)
	var tips: Array = doc.tooltips
	var tbad: Array[String] = []
	for j in range(1, 41):
		var mine := Array(CustodianBadge.tooltip(j))
		if mine != (tips[j] as Array):
			tbad.append("%d: %s" % [j, mine])
	_ok("the tooltip's lines are the page's at every jump 1 to 40 (%s)" % ("all" if tbad.is_empty() else "; ".join(tbad.slice(0, 4))), tbad.is_empty())


## THE DIGITS TABLE IS THE GAME'S FONT: each digit Silkscreen draws at 8 px
## with antialiasing off, read from its own glyph cache, is the table's.
func _digits_are_the_font() -> void:
	var f := UITheme.pixel_font()
	var sz := Vector2i(UITheme.FS_SMALL, 0)
	f.render_range(0, sz, 0x30, 0x39)
	var bad: Array[String] = []
	var asc := ceili(f.get_ascent(UITheme.FS_SMALL))
	for ch: String in CustodianBadge.DIGITS:
		var g := f.get_glyph_index(UITheme.FS_SMALL, ch.unicode_at(0), 0)
		var adv := f.get_glyph_advance(0, UITheme.FS_SMALL, g).x
		var ti := f.get_glyph_texture_idx(0, sz, g)
		var img := f.get_texture_image(0, sz, ti) if ti >= 0 else null
		if img == null or img.is_empty():
			bad.append("%s: no glyph image" % ch)
			continue
		var uv := f.get_glyph_uv_rect(0, sz, g)
		var off := f.get_glyph_offset(0, sz, g)
		var gs := f.get_glyph_size(0, sz, g)
		var spec: Array = CustodianBadge.DIGITS[ch]
		var rows := String(spec[1]).split("|")
		var mine := {}
		for r in rows.size():
			for c in (rows[r] as String).length():
				if (rows[r] as String)[c] == "#":
					mine[Vector2i(c, r)] = true
		var theirs := {}
		# the glyph's cell in the atlas, its ink placed from the pen and the cap top
		var cap_top := asc - 5
		for yy in int(gs.y):
			for xx in int(gs.x):
				var px := img.get_pixel(int(uv.position.x) + xx, int(uv.position.y) + yy)
				if px.a > 0.5:
					theirs[Vector2i(int(off.x) + xx, asc + int(off.y) + yy - cap_top)] = true
		if mine != theirs or int(adv) != int(spec[0]):
			bad.append("%s: the font %s adv %d, the table %s adv %d" % [ch, theirs.keys(), int(adv), mine.keys(), int(spec[0])])
	_ok("the digits table is Silkscreen's own glyphs at 8 px, antialiasing off (%s)" % ("0 to 9" if bad.is_empty() else "; ".join(bad.slice(0, 3))), bad.is_empty())
	_ok("the font's capitals sit as measured on the stills: ascent %.2f, the cap top 4 rows into the label" % f.get_ascent(UITheme.FS_SMALL),
		asc - 5 == 4)


## EVERY TRANSITION ENDS ON ITS STAGE'S IDLE FRAME 0, and its first step is
## the jump before at rest.
func _ends_on_idle() -> void:
	var bad: Array[String] = []
	for j in range(1, 41):
		var n: int = CustodianBadge.TRANS_STEPS[CustodianBadge.change_kind(j)]
		if n == 0:
			continue
		var last := CustodianBadge.frame(j, 0.0, (float(n - 1) + 0.5) / 10.0)
		var idle0 := CustodianBadge.frame(j, 0.0, -1.0)
		var after := CustodianBadge.frame(j, 0.0, float(n) / 10.0 + 0.01)
		var first := CustodianBadge.frame(j, 0.0, 0.05)
		var before := CustodianBadge.frame(j - 1, 0.0, -1.0)
		if last.get_data() != idle0.get_data() or after.get_data() != idle0.get_data() or first.get_data() != before.get_data():
			bad.append(str(j))
	_ok("every transition starts on the jump before and ends on its idle frame 0 (%s)" % ("jumps 1 to 16, 20, 25, 33" if bad.is_empty() else "not at " + ", ".join(bad)), bad.is_empty())


# ------------------------------------------------------------------ 5. per second

## Changes a second at 60 frames a second, over 6 s (a whole number of every
## stage's loops, so the count is the loop's, wrapping round): what a player sees.
func _per_second() -> void:
	# each stage's changes in one loop over the loop's length (S0 6 in 3 s, 11 on
	# the last free jump; S1 12 in 2; S2 12 in 1.5; S3 10 in 1; FULL 12 in 1).
	# The page's harness measured the same frames over 3 s, not a whole loop
	# each: 2.0, 3.3, 5.3, 8.0, 9.7 and 11.7
	var want := {1: 2.0, 10: 2.0, 15: 11.0 / 3.0, 16: 6.0, 18: 6.0, 20: 8.0, 28: 10.0, 35: 12.0}
	var rows: Array[String] = []
	var bad: Array[String] = []
	for j: int in want:
		var rate := int(CustodianBadge.idle_of(j, 0.0, -1.0).rate)
		var seq: Array[PackedByteArray] = []
		for n in 360:
			seq.append(CustodianBadge.frame(j, (float(n) + 0.5) / 60.0, -1.0).get_data())
		var changes := 0
		var hold := 0
		var min_hold := 1 << 30
		var first := -1
		for n in 360:
			if seq[n] != seq[(n + 359) % 360]:
				changes += 1
				if first < 0:
					first = n
				else:
					min_hold = mini(min_hold, hold)
				hold = 0
			hold += 1
		if first >= 0:
			min_hold = mini(min_hold, hold + first)
		var cps := float(changes) / 6.0
		rows.append("%d %s %.2f/s" % [j, CustodianBadge.stage(j), cps])
		if absf(cps - float(want[j])) > 0.05 or cps > 12.0 or cps <= 0.0 or min_hold < 60 / rate - 1:
			bad.append("%d (%.2f/s, held %d frames at least)" % [j, cps, min_hold])
	_ok("idle per second, each stage's whole loop: never above 12, no frame shorter than its rate (%s)" % ", ".join(rows), bad.is_empty())
	var same := true
	for n in 60:
		var t := (float(n) + 0.5) / 60.0
		if CustodianBadge.frame(35, t, -1.0).get_data() != CustodianBadge.frame(35, t + 1.0, -1.0).get_data() \
				or CustodianBadge.frame(35, t, -1.0).get_data() != CustodianBadge.frame(35, t + 7.0, -1.0).get_data():
			same = false
	_ok("FULL beats the same every second", same)


## ON SCREEN IT REPAINTS ONLY WHEN THE FRAME CHANGES: over 3 s on LOCAL at
## each stage, as many repaints as the frame changed, never above 12 a second.
func _repaints() -> void:
	Router.show_local()
	await _frames(30)
	var b := _badge()
	var rows: Array[String] = []
	var ok := true
	for j: int in [1, 15, 18, 20, 28, 35]:
		Run.jumps = j
		Run.custodian_seen = j
		await _frames(2)
		var p0 := b.paints
		var keys := 0
		var last := String(b.shown.get("key", ""))
		for i in 180:
			await _frames(1)
			var k := String(b.shown.get("key", ""))
			if k != last:
				keys += 1
				last = k
		var n := b.paints - p0
		rows.append("%d: %d in 3 s" % [j, n])
		if n != keys or n > 36 or n == 0:
			ok = false
	_ok("on screen it repaints only when its frame changes, at most 12 a second (%s)" % ", ".join(rows), ok)


# ------------------------------------------------------------------ 6. the words

func _tooltip_words() -> void:
	var e := DB.core_boss()
	var bad: Array[String] = []
	var hulls := {}
	for j in 41:
		hulls[e.hull_at(j)] = true
	for j in 41:
		var lines := CustodianBadge.tooltip(j)
		var all := " ".join(lines)
		if lines[0] != e.name.to_upper():
			bad.append("%d: heading %s" % [j, lines[0]])
		if all.to_lower().contains("hull"):
			bad.append("%d: says hull" % j)
		var re := RegEx.create_from_string("\\d+")
		for m in re.search_all(all):
			var v := int(m.get_string())
			if hulls.has(v) or (v != CustodianBadge.countdown(j) and v != 15):
				bad.append("%d: the number %d" % [j, v])
	_ok("the heading is the boss's name from data, no hull figure, no number but the jumps (%s)" % ("0 to 40" if bad.is_empty() else "; ".join(bad.slice(0, 4))), bad.is_empty())
	var was := e.name
	e.name = "The Warden"
	var renamed := CustodianBadge.tooltip(20)[0]
	e.name = was
	_ok("renaming the boss renames the heading (%s)" % renamed, renamed == "THE WARDEN")
	_ok("jump 0 says 16 jumps, 15 after your next jump, 16 that it woke after jump 15, 33 full strength",
		CustodianBadge.tooltip(0)[3] == "in 16 jumps." and CustodianBadge.tooltip(15)[3] == "after your next jump."
		and CustodianBadge.tooltip(16)[4] == "It woke after jump 15." and CustodianBadge.tooltip(33)[2] == "It is at full strength.")


# ------------------------------------------------------------------ 3. on every screen

## The union of every pixel the badge inks at `j` over its idle loop and its
## transition, local to its corner.
func _ink_at(j: int) -> Rect2i:
	if _ink.has(j):
		return _ink[j]
	var u := Rect2i()
	var r: Array = CustodianBadge.IDLE[CustodianBadge.stage(j)]
	var times: Array = []
	for n in int(round(float(r[0]) * float(r[2]))):
		times.append([(float(n) + 0.5) / float(r[0]), -1.0])
	var steps: int = CustodianBadge.TRANS_STEPS[CustodianBadge.change_kind(j)]
	for s in steps:
		times.append([0.0, (float(s) + 0.5) / 10.0])
	for tt: Array in times:
		var img := CustodianBadge.frame(j, tt[0], tt[1])
		var used := img.get_used_rect()
		if used.size != Vector2i.ZERO:
			u = used if u.size == Vector2i.ZERO else u.merge(used)
	_ink[j] = u
	return u


func _screens() -> void:
	Hints.forced = false
	Hints.reset()
	for which: String in ["LOCAL", "the map", "the chart", "a fight"]:
		match which:
			"LOCAL":
				Router.show_local()
			"the map":
				Router.show_system()
			"the chart":
				Router.show_starchart()
			"a fight":
				Router.start_combat(DB.enemies[&"cutter"], [], false, false)
		await _frames(60)
		await _fit_every_jump(which)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	await _frames(40)
	# A STEP PENDING (hints on, no jump made): its line under the goal, clear of
	# the badge, and the badge drawn at its tallest (FULL) clear of it too
	Hints.forced = true
	Hints.set_process(false)
	Hints.reset()
	await _frames(20)
	var g := _goal()
	var sr := g.step_rect()
	var tall := CustodianBadge.frame(35, 0.0, -1.0).get_used_rect()
	var bt := g.position + _badge().position
	_ok("with a step pending, its line %s stands under the badge's tallest ink (rows %d to %d) with a blank row between" % [sr,
		int(bt.y) + tall.position.y, int(bt.y) + tall.end.y - 1], sr.size != Vector2.ZERO and sr.position.y >= bt.y + float(tall.end.y) + 1.0
		and sr.position == Vector2(g.position.x, g.position.y + g.size.y + GoalLine.GAP))
	Hints.forced = false
	Hints.set_process(true)
	Hints.reset()
	await _frames(5)


func _fit_every_jump(which: String) -> void:
	var g := _goal()
	var b := _badge()
	var cur := Router.current
	var font := UITheme.pixel_font()
	var adv := font.get_string_size(GoalLine.GOAL, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	var bad: Array[String] = []
	var placed: Array[String] = []
	var hud := Router.hud.get_global_rect()
	var screen := get_viewport().get_visible_rect()
	var pic := GoalLine.picture_rect(cur)
	for j in 41:
		Run.jumps = j
		Run.custodian_seen = j
		await _frames(2)
		if not (g.is_visible_in_tree() and g.modulate.a > 0.99 and b.is_visible_in_tree()):
			bad.append("%d: not up (line %s, badge %s)" % [j, g.is_visible_in_tree(), b.is_visible_in_tree()])
			continue
		if int(b.shown.get("j", -1)) != j or int(b.shown.get("step", 0)) != -1:
			bad.append("%d: shows %s" % [j, b.shown])
		var ink := _ink_at(j)
		var at := b.global_position
		var u := Rect2(at + Vector2(ink.position), Vector2(ink.size))
		# 6 blank columns after the goal's last letter, the middle row on the caps'
		var last_ink := g._goal.global_position.x + adv - 2.0
		var gap := at.x - last_ink - 1.0
		var cy := at.y + 7.0
		if j == 0:
			placed.append("x %.0f, %.0f blank after the goal's ink at %.0f, cy %.0f (the line's top %.0f + 7)" % [at.x, gap, last_ink, cy, g.position.y])
		if gap != 6.0 or cy != g.position.y + 7.0 or at != at.round():
			bad.append("%d: %.0f blank, cy %.0f against %.0f" % [j, gap, cy, g.position.y + 7.0])
		if not Rect2(g.position, g.size).encloses(u):
			bad.append("%d: ink %s outside the line's room %s" % [j, u, Rect2(g.position, g.size)])
		if not screen.encloses(u) or u.position.y < hud.end.y:
			bad.append("%d: ink %s off the screen or over the HUD" % [j, u])
		if pic.size != Vector2.ZERO and not pic.encloses(u):
			bad.append("%d: ink %s outside the picture %s" % [j, u, pic])
		for pair: Array in GoalTestScript.boxes(cur):
			var r: Rect2 = pair[1]
			if r.size.x > 0.0 and r.size.y > 0.0 and u.intersects(r):
				bad.append("%d: over %s %s" % [j, pair[0], r])
		if u.end.y >= g.step_at().y:
			bad.append("%d: ink to row %.0f touches the step's place at %.0f" % [j, u.end.y - 1.0, g.step_at().y])
		for s: Dictionary in Ash.survey_boxes(cur):
			if String(s.name).begins_with("top") and (s.rect as Rect2).intersects(u):
				bad.append("%d: A.S.H.'s spot %s %s" % [j, s.name, s.rect])
	_ok("%s: %s" % [which, placed[0] if not placed.is_empty() else "never up"], not placed.is_empty())
	_ok("%s, every jump 0 to 40: up with the line, 6 blank px after the goal, on its caps' middle, inside its room and the picture, clear of everything GoalTest keeps it off, the step's place and A.S.H.'s spots (%s)" % [
		which, "all" if bad.is_empty() else "; ".join(bad.slice(0, 6))], bad.is_empty())


# ------------------------------------------------------------------ 4. the arrival

## The steps the badge shows over `n` frames, one per frame.
func _watch(n: int) -> Array:
	var b := _badge()
	var out: Array = []
	for i in n:
		await _frames(1)
		out.append(int(b.shown.get("step", -2)) if b.is_visible_in_tree() else -9)
	return out


## The steps in a run of frames: [[step, frames], ...].
func _runs(seq: Array) -> Array:
	var out: Array = []
	for s: int in seq:
		if out.is_empty() or (out.back() as Array)[0] != s:
			out.append([s, 1])
		else:
			(out.back() as Array)[1] += 1
	return out


func _arrivals() -> void:
	Hints.forced = false
	Hints.reset()
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	await _frames(40)
	_ok("a new run has seen no arrival (custodian_seen %d)" % Run.custodian_seen, Run.custodian_seen == 0 and Run.jumps == 0)
	# ---- the wake on LOCAL, at 10 steps a second, then idle
	for j: int in [16, 20, 25, 33, 7]:
		Run.jumps = j
		Run.custodian_seen = j - 1
		var seq: Array = await _watch(150)
		var rs := _runs(seq)
		var n: int = CustodianBadge.TRANS_STEPS[CustodianBadge.change_kind(j)]
		var good: bool = rs.size() == n + 1 and (rs.back() as Array)[0] == -1 and Run.custodian_seen == j
		for s in n:
			if not good:
				break
			good = (rs[s] as Array)[0] == s and absi(int((rs[s] as Array)[1]) - 6) <= 1
		_ok("arriving at %d on LOCAL: %s, then idle (steps:frames %s)" % [j, CustodianBadge.change_kind(j),
			", ".join(rs.map(func(r: Array) -> String: return "%d:%d" % r))], good)
	# ---- no replay between screens
	var replay := false
	for step_to: Callable in [Router.show_starchart, Router.show_system, Router.show_local, Router.show_starchart, Router.show_local]:
		step_to.call()
		var seq2: Array = await _watch(40)
		if seq2.any(func(s: int) -> bool: return s >= 0):
			replay = true
	_ok("moving between the chart, the map and LOCAL never plays it again", not replay and Run.custodian_seen == Run.jumps)
	# ---- a save loaded does not replay it
	Run.jumps = 12
	Run.custodian_seen = 12
	SaveGame.save()
	Run.custodian_seen = 0
	var loaded := SaveGame.load_into_run()
	_ok("a save loads and counts its jump as seen (%d of %d)" % [Run.custodian_seen, Run.jumps], loaded and Run.custodian_seen == Run.jumps and Run.jumps == 12)
	Router.show_local()
	var seq3: Array = await _watch(40)
	_ok("so CONTINUE does not replay it", not seq3.any(func(s: int) -> bool: return s >= 0))
	await _real_jump()
	await _animated_jump()


## A REAL JUMP from the chart at 15: the chart never plays the wake; the next
## screen with the line up does.
func _real_jump() -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.jumps = 15
	Run.custodian_seen = 15
	Router.show_starchart()
	await _frames(40)
	var to := _neighbour()
	if not _ok("a star in range to jump to", to != null):
		return
	Router.commit_jump(to.index, true)
	var on_chart := false
	var seen: Array = []
	var where := ""
	for i in 150:
		await _frames(1)
		var st := int(_badge().shown.get("step", -2)) if _badge().is_visible_in_tree() else -9
		if Router.current is StarchartScreen and Run.jumps == 16 and st >= 0:
			on_chart = true
		if st >= 0 and Run.jumps == 16:
			seen.append(st)
			where = _name(Router.current)
	_ok("a real jump 15 to 16 (jumps %d): the chart it left never plays the wake" % Run.jumps, Run.jumps == 16 and not on_chart)
	_ok("the next screen up does, on %s (steps %s)" % [where, _runs(seen).map(func(r: Array) -> int: return r[0])],
		seen.size() > 0 and seen[0] == 0 and seen.max() == 11 and Run.custodian_seen == 16)


## ANIMATED (`Router.animate_in_harness`): the arrival waits for the ship to
## stop and the line to finish fading in.
func _animated_jump() -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.jumps = 19
	Run.custodian_seen = 19
	Router.show_local()
	await _frames(40)
	var to := _neighbour()
	if to == null:
		_ok("a star in range to jump to, animated", false)
		return
	Router.animate_in_harness = true
	Router.begin_jump(to.index)
	var started := ""
	var early := false
	var faded := false
	for i in 1500:
		await _frames(1)
		if Run.custodian_seen == 20 and started == "":
			var g := _goal()
			var sc := Router.current as SectorScreen
			started = "frame %d on %s, line alpha %.2f, phase %s" % [i, _name(Router.current), g.modulate.a, sc._phase if sc != null else "-"]
			early = not GoalLine.shows_on(Router.current) or (sc != null and sc._phase != SectorScreen.Phase.NONE)
			faded = g.modulate.a >= 0.99
			break
	Router.animate_in_harness = false
	_ok("animated, the jump to 20 lands (jumps %d) and its arrival starts once the ship has stopped and the line is up (%s)" % [Run.jumps, started],
		Run.jumps == 20 and started != "" and not early and faded)
	await _frames(30)


func _neighbour() -> MapGen.MapNode:
	var here := Run.node_at()
	for raw in Run.in_range():
		var n: MapGen.MapNode = raw
		if n != here and Run.can_jump_to(n) and n.type == MapGen.NodeType.SYSTEM:
			return n
	return null


# ------------------------------------------------------------------ 6, 7. hover and the mouse

func _move_to(p: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = p
	mm.global_position = p
	get_viewport().push_input(mm, true)


func _hover_and_mouse() -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	await _frames(40)
	var g := _goal()
	var b := _badge()
	_not_pressable(g)
	var plate := b.get_theme_stylebox(&"panel", &"TooltipPanel")
	for which: String in ["LOCAL", "the map", "the chart", "a fight"]:
		match which:
			"LOCAL":
				Router.show_local()
			"the map":
				Router.show_system()
			"the chart":
				Router.show_starchart()
			"a fight":
				Router.start_combat(DB.enemies[&"cutter"], [], false, false)
		await _frames(60)
		var bad: Array[String] = []
		var timing: Array[String] = []
		for j: int in [0, 15, 16, 25, 33, 40]:
			Run.jumps = j
			Run.custodian_seen = j
			_move_to(Vector2(8, 300))
			await _frames(3)
			var mid := b.box_rect().get_center().floor()
			_move_to(mid)
			await _frames(12)
			var early := b.tip.visible
			await _frames(6)
			var up := b.tip.is_visible_in_tree()
			if early or not up:
				timing.append("%d: up at 0.2 s %s, at 0.3 s %s" % [j, early, up])
				continue
			var tr := b.tip_rect()
			var lines: Array[String] = []
			for l in b._tip_box.get_children():
				if l is Label:
					lines.append((l as Label).text)
			if lines != Array(CustodianBadge.tooltip(j)):
				bad.append("%d: says %s" % [j, lines])
			if b.tip.get_theme_stylebox(&"panel") != plate:
				bad.append("%d: not the tooltip plate" % j)
			if not get_viewport().get_visible_rect().encloses(tr):
				bad.append("%d: %s off the screen" % [j, tr])
			# (the badge's box at this jump and the goal's words: the line's room is
			# kept for S0's wider box, empty past the eye from the wake on)
			var keep: Array = [["the badge", b.box_rect()], ["the goal", g._panel.get_global_rect()], ["the step", g.step_rect()]]
			keep.append_array(GoalTestScript.boxes(Router.current))
			if Ash.portrait != null and Ash.portrait.is_visible_in_tree():
				keep.append(["A.S.H.", Ash.portrait.get_global_rect()])
			for pair: Array in keep:
				var r: Rect2 = pair[1]
				if r.size.x > 0.0 and r.size.y > 0.0 and tr.intersects(r):
					bad.append("%d: %s over %s %s" % [j, tr, pair[0], r])
			# the page's spot: 6 px after the badge, no further left than its 170
			# (the map and the chart) or 218 (LOCAL and a fight), on the badge's top
			var area := Router.content.get_global_rect()
			var nav := Router.current is SystemMapScreen or Router.current is StarchartScreen
			var spot := Vector2(maxf(b.box_rect().end.x + 6.0, area.position.x + (162.0 if nav else 210.0)), b.box_rect().position.y)
			if tr.position != spot:
				bad.append("%d: at %s, the page's spot %s" % [j, tr.position, spot])
			if j == 0 or j == 16:
				timing.append("at %d %s" % [j, tr])
			# what the pointer is over is the picture under it, not the badge
			var hov := get_viewport().gui_get_hovered_control()
			if hov != null and (hov == g or g.is_ancestor_of(hov)):
				bad.append("%d: the pointer is over %s" % [j, hov.name])
			_move_to(Vector2(mid.x, 300))
			await _frames(1)
			if b.tip.is_visible_in_tree():
				bad.append("%d: still up after leaving" % j)
		_ok("%s: the tooltip comes up after a quarter second and not before, %s" % [which, ", ".join(timing)], timing.size() == 2)
		_ok("%s: the page's lines on the tooltip plate, inside the screen and clear of the badge, the goal, its step, A.S.H. and everything GoalTest keeps the line off; gone on leaving (%s)" % [
			which, "jumps 0, 15, 16, 25, 33, 40" if bad.is_empty() else "; ".join(bad.slice(0, 5))], bad.is_empty())
		if which == "the chart":
			await _press_reaches_chart()
	Router.show_local()
	await _frames(30)


## A press on the badge on the chart is the chart's: a pan starts (or a star
## there is picked).
func _press_reaches_chart() -> void:
	var b := _badge()
	var chart: Control = (Router.current as StarchartScreen)._chart
	var mid := b.box_rect().get_center().floor()
	_move_to(mid)
	await _frames(2)
	var picked := [false]
	var on_pick := func(_i: int) -> void: picked[0] = true
	chart.connect(&"node_picked", on_pick)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = mid
	mb.global_position = mid
	get_viewport().push_input(mb, true)
	await _frames(2)
	# (headless keeps no hover, so what the pointer is over is read where the
	# viewport has one)
	var hov := get_viewport().gui_get_hovered_control()
	var reached: bool = bool(chart.get("_dragging")) or picked[0]
	_ok("on the chart a press on the badge reaches the chart's picture under it (pan %s, pick %s; over %s)" % [
		chart.get("_dragging"), picked[0], hov.name if hov != null else "no hover headless"], (hov == null or hov == chart) and reached)
	var up := mb.duplicate() as InputEventMouseButton
	up.pressed = false
	get_viewport().push_input(up, true)
	await _frames(2)
	chart.disconnect(&"node_picked", on_pick)
	_move_to(Vector2(8, 300))
	await _frames(2)


## Not a control: it and everything in it ignore the mouse, nothing is a
## button, no hand, no focus (`GoalTest._not_pressable`, with the badge and its
## tooltip in it).
func _not_pressable(g: Control) -> void:
	var all: Array = [g]
	all.append_array(g.find_children("*", "", true, false))
	var bad: Array[String] = []
	var has_badge := false
	for n in all:
		var c := n as Control
		if c == null:
			continue
		if c is CustodianBadge:
			has_badge = true
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE or c is BaseButton \
				or c.mouse_default_cursor_shape != Control.CURSOR_ARROW or c.focus_mode != Control.FOCUS_NONE:
			bad.append(c.name)
	_ok("the badge is on the goal line, and nothing on it is pressable: ignores the mouse, no button, no hand, no focus (%s)" % (
		"all of it" if bad.is_empty() else ", ".join(bad)), has_badge and bad.is_empty())


## A CORE BOSS THAT DOES NOT GROW has no badge, and the line and everything
## clickable round it stand where they did; with it back, nothing clickable
## has moved for the badge.
func _no_growth() -> void:
	Router.show_local()
	await _frames(30)
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	await _frames(60)
	var with_badge := _clickables()
	var e := DB.core_boss()
	var was := e.grow_after
	e.grow_after = -1
	await _frames(3)
	var g := _goal()
	var off_ok := not CustodianBadge.enabled() and not _badge().visible and g.size == g._panel.size
	var without := _clickables()
	e.grow_after = was
	await _frames(3)
	_ok("a core boss that never grows has no badge, and the line is its words alone (%s)" % g.size if not off_ok else "a core boss that never grows has no badge, and the line is its words alone", off_ok)
	_ok("nothing clickable moves for the badge (%d controls: the HUD's tabs, the fight's END TURN, LOG, the hand)" % with_badge.size(),
		with_badge == without and with_badge.size() > 3)
	Router.show_local()
	await _frames(20)


func _clickables() -> Dictionary:
	var out := {}
	for c in Router.hud.find_children("*", "BaseButton", true, false):
		var k := c as Control
		if k.is_visible_in_tree():
			out[str(k.get_path())] = k.get_global_rect()
	var sc := Router.current as SectorScreen
	if sc != null:
		if sc._end_button != null:
			out["end"] = sc._end_button.get_global_rect()
		if sc._hand != null:
			out["hand"] = sc._hand.get_global_rect()
		for r: Rect2 in FightLog.rects(sc):
			out["log%s" % r] = r
	return out


func _name(c: Node) -> String:
	return c.get_script().get_global_name() if c != null and c.get_script() != null else "none"


func _finish() -> void:
	Hints.forced = false
	Hints.set_process(true)
	Hints.reset()
	print("badgetest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
