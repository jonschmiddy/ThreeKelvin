extends Node

## Runs the Custodian badge through the real HUD, goal line and Router, with no stub.
## Why: docs/why/BadgeTest.md#badge-test

const GoalTestScript := preload("res://scripts/sim/GoalTest.gd")
const GOLDEN := "res://scripts/sim/badge_golden.json"

var _tree: SceneTree
var harness := Harness.new()
## the union of every pixel the badge inks at a jump (local to its corner), by jump
var _ink := {}
## frames on screen that were not the frame the badge said (`_screen_bad`), and
## whether the renderer gave its texture back to read
var _pix_bad: Array[String] = []
var _pix_n := 0
var _tex_read := false


func _ok(what: String, c: bool) -> bool:
	return harness._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await Harness.frames(_tree, 2)
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	await Harness.frames(_tree, 40)
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
	_coop_kinds()
	_coop_words()
	await _coop()
	_screen_summary()
	await _hover_and_mouse()
	await _no_growth()
	_finish()


func _goal() -> GoalLine:
	return Router.hud.goal if Router.hud != null and is_instance_valid(Router.hud) else null


func _badge() -> CustodianBadge:
	var g := _goal()
	return g.badge() if g != null else null


## Reads the screen: the badge's Image and texture must be `frame()` at the clock it shows.
func _screen_bad(b: CustodianBadge) -> String:
	if b == null or not b.is_visible_in_tree():
		return ""
	var j := int(b.shown.get("j", -1))
	var key := String(b.shown.get("key", ""))
	var want := CustodianBadge.frame(j, float(b.shown.get("t", 0.0)), float(b.shown.get("since", -1.0)), 0, 7,
		int(b.shown.get("from", j - 1))).get_data()
	var img := b.image()
	if img == null or img.get_data() != want:
		return "%s: its Image is not frame() at the clock it shows" % key
	if b._tex == null or Vector2i(b._tex.get_size()) != Vector2i(CustodianBadge.IMG_W, CustodianBadge.IMG_H):
		return "%s: its texture is %s" % [key, b._tex.get_size() if b._tex != null else "missing"]
	# (headless, the dummy renderer hands back the image a texture was made
	# from, never an update, so the texture is read only where it renders)
	var ti := b._tex.get_image() if DisplayServer.get_name() != "headless" else null
	if ti != null:
		_tex_read = true
		if ti.get_format() != Image.FORMAT_RGBA8:
			ti.convert(Image.FORMAT_RGBA8)
		if ti.get_data() != want:
			return "%s: its texture is not its frame" % key
	if b.position != GoalLine.badge_at() or b.size != Vector2(CustodianBadge.IMG_W, CustodianBadge.IMG_H):
		return "%s: at %s size %s, not %s" % [key, b.position, b.size, GoalLine.badge_at()]
	return ""


func _check_screen(b: CustodianBadge) -> void:
	if b == null or not b.is_visible_in_tree():
		return
	_pix_n += 1
	var s := _screen_bad(b)
	if s != "":
		_pix_bad.append(s)


func _screen_summary() -> void:
	_ok("on screen, every frame watched (%d) is the badge's frame at the clock it shows, in its Image%s, at its place on the line (%s)" % [
		_pix_n, " and the texture it draws" if _tex_read else " (the texture's size; headless gives no texture back to read)",
		"all" if _pix_bad.is_empty() else "%d not: %s" % [_pix_bad.size(), "; ".join(_pix_bad.slice(0, 5))]],
		_pix_n > 1000 and _pix_bad.is_empty())


## The new look never shows before its arrival begins; the count last shown stays at rest.
func _early_bad(b: CustodianBadge) -> String:
	var g := CustodianBadge.count()
	if b == null or not b.is_visible_in_tree() or Run.custodian_seen >= g \
			or CustodianBadge.change_kind(g, Run.custodian_seen) == &"none":
		return ""
	# (the jump committed after the line's refresh this frame: what is up is the
	# jump before's own frame, which `_screen_bad` holds it to)
	if int(b.shown.get("j", -1)) < g:
		return ""
	var img := b.image()
	if int(b.shown.get("step", -2)) != 0 or img == null \
			or img.get_data() != CustodianBadge.frame(Run.custodian_seen, 0.0, -1.0).get_data():
		return "jump %d (seen %d) shows %s at line alpha %.2f" % [Run.jumps, Run.custodian_seen, b.shown.get("key", ""), _goal().modulate.a]
	return ""


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
	await Harness.frames(_tree, 5)
	Router.engage_here()
	var cb: Combat = null
	for i in 30:
		cb = Router.combat
		if cb != null and not cb.enemies.is_empty():
			break
		await Harness.frames(_tree, 1)
	_ok("ENGAGE at the core fights the core boss (%s)" % (cb.enemies[0].template.name if cb != null and not cb.enemies.is_empty() else "no fight"),
		cb != null and not cb.enemies.is_empty() and cb.enemies[0].template.id == DB.core_boss().id)
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.at = was if was < Run.map.size() else Run.at
	Router.show_local()
	await Harness.frames(_tree, 40)


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
	# Per-stage change counts over one whole loop; the page's harness measured 3 s windows.
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
	await Harness.frames(_tree, 30)
	var b := _badge()
	var rows: Array[String] = []
	var ok := true
	for j: int in [1, 15, 18, 20, 28, 35]:
		Run.jumps = j
		Run.custodian_seen = j
		await Harness.frames(_tree, 2)
		var p0 := b.paints
		var keys := 0
		var last := String(b.shown.get("key", ""))
		for i in 180:
			await Harness.frames(_tree, 1)
			_check_screen(b)
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
		await Harness.frames(_tree, 60)
		await _fit_every_jump(which)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	await Harness.frames(_tree, 40)
	# A STEP PENDING (hints on, no jump made): its line under the goal, clear of
	# the badge, and the badge drawn at its tallest (FULL) clear of it too
	Hints.forced = true
	Hints.set_process(false)
	Hints.reset()
	await Harness.frames(_tree, 20)
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
	await Harness.frames(_tree, 5)


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
		await Harness.frames(_tree, 2)
		if not (g.is_visible_in_tree() and g.modulate.a > 0.99 and b.is_visible_in_tree()):
			bad.append("%d: not up (line %s, badge %s)" % [j, g.is_visible_in_tree(), b.is_visible_in_tree()])
			continue
		if int(b.shown.get("j", -1)) != j or int(b.shown.get("step", 0)) != -1:
			bad.append("%d: shows %s" % [j, b.shown])
		var scr := _screen_bad(b)
		if scr != "":
			bad.append("%d: %s" % [j, scr])
		_pix_n += 1
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
		await Harness.frames(_tree, 1)
		_check_screen(b)
		out.append(int(b.shown.get("step", -2)) if b.is_visible_in_tree() else -9)
	return out


## Frames until the goal line is fully up with the badge on it (at most 20 s).
func _until_up(b: CustodianBadge) -> int:
	var g := _goal()
	for i in 1200:
		if g != null and g.is_visible_in_tree() and g.modulate.a > 0.99 and b.is_visible_in_tree():
			return i
		await Harness.frames(_tree, 1)
	return -1


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
	await Harness.frames(_tree, 40)
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
	await Harness.frames(_tree, 40)
	var to := _neighbour()
	if not _ok("a star in range to jump to", to != null):
		return
	Router.commit_jump(to.index, true)
	var on_chart := false
	var seen: Array = []
	var where := ""
	var early: Array[String] = []
	for i in 150:
		await Harness.frames(_tree, 1)
		_check_screen(_badge())
		var e := _early_bad(_badge())
		if e != "":
			early.append("frame %d %s" % [i, e])
		var st := int(_badge().shown.get("step", -2)) if _badge().is_visible_in_tree() else -9
		if Router.current is StarchartScreen and Run.jumps == 16 and st >= 0:
			on_chart = true
		if st >= 0 and Run.jumps == 16:
			seen.append(st)
			where = _name(Router.current)
	_ok("a real jump 15 to 16 (jumps %d): the chart it left never plays the wake" % Run.jumps, Run.jumps == 16 and not on_chart)
	_ok("the next screen up does, on %s (steps %s)" % [where, _runs(seen).map(func(r: Array) -> int: return r[0])],
		seen.size() > 0 and seen[0] == 0 and seen.max() == 11 and Run.custodian_seen == 16)
	_ok("and until it does, jump 15's eye at rest is what shows (%s)" % ("every frame" if early.is_empty() else "; ".join(early.slice(0, 3))), early.is_empty())


## ANIMATED (`Router.animate_in_harness`): the arrival waits for the ship to
## stop and the line to finish fading in.
func _animated_jump() -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.jumps = 19
	Run.custodian_seen = 19
	Router.show_local()
	await Harness.frames(_tree, 40)
	var to := _neighbour()
	if to == null:
		_ok("a star in range to jump to, animated", false)
		return
	Router.animate_in_harness = true
	Router.begin_jump(to.index)
	var started := ""
	var early := false
	var faded := false
	var shown_early: Array[String] = []
	for i in 1500:
		await Harness.frames(_tree, 1)
		_check_screen(_badge())
		var eb := _early_bad(_badge())
		if eb != "":
			shown_early.append("frame %d %s" % [i, eb])
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
	_ok("animated, jump 19's eye at rest shows until then, the old line fading out too (%s)" % ("every frame" if shown_early.is_empty() else "; ".join(shown_early.slice(0, 3))), shown_early.is_empty())
	await Harness.frames(_tree, 30)
	await _skipped_jump()


## A skip on the first frame commits while the old line fades, still holding jump 15's eye.
func _skipped_jump() -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.jumps = 15
	Run.custodian_seen = 15
	Router.show_local()
	await Harness.frames(_tree, 40)
	var to := _neighbour()
	if to == null:
		_ok("a star in range to jump to, skipped", false)
		return
	Router.animate_in_harness = true
	Router.begin_jump(to.index)
	var sc := Router.current as SectorScreen
	var skipped := false
	var fading_at_16 := 0
	var early: Array[String] = []
	var woke := false
	for i in 1500:
		await Harness.frames(_tree, 1)
		if not skipped and sc != null and is_instance_valid(sc) and sc._phase == SectorScreen.Phase.DEPART:
			sc._skip()
			skipped = true
		var b := _badge()
		_check_screen(b)
		if Run.jumps == 16 and Run.custodian_seen < 16 and b.is_visible_in_tree() and not _goal()._want:
			fading_at_16 += 1
		var eb := _early_bad(b)
		if eb != "":
			early.append("frame %d %s" % [i, eb])
		if Run.custodian_seen == 16:
			woke = true
			break
	Router.animate_in_harness = false
	_ok("a departure skipped on its first frame lands at 16 and wakes it (skipped %s, jumps %d, the line fading out with jump 16 committed on %d frames)" % [
		skipped, Run.jumps, fading_at_16], skipped and woke and Run.jumps == 16)
	_ok("and the fading line holds jump 15's eye until the wake (%s)" % ("every frame" if early.is_empty() else "; ".join(early.slice(0, 3))), early.is_empty())
	await Harness.frames(_tree, 30)


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
	await Harness.frames(_tree, 40)
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
		await Harness.frames(_tree, 60)
		var bad: Array[String] = []
		var late: Array[String] = []
		var timing: Array[String] = []
		for j: int in [0, 15, 16, 25, 33, 40]:
			Run.jumps = j
			Run.custodian_seen = j
			_move_to(Vector2(8, 300))
			await Harness.frames(_tree, 3)
			var mid := b.box_rect().get_center().floor()
			_move_to(mid)
			await Harness.frames(_tree, 12)
			var early := b.tip.visible
			await Harness.frames(_tree, 6)
			var up := b.tip.is_visible_in_tree()
			if early or not up:
				late.append("%d: up at 0.2 s %s, at 0.3 s %s" % [j, early, up])
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
			await Harness.frames(_tree, 1)
			if b.tip.is_visible_in_tree():
				bad.append("%d: still up after leaving" % j)
		_ok("%s: the tooltip comes up after a quarter second and not before, at every jump 0, 15, 16, 25, 33, 40 (%s)" % [which,
			", ".join(timing) if late.is_empty() else "; ".join(late)], late.is_empty() and timing.size() == 2)
		_ok("%s: the page's lines on the tooltip plate, inside the screen and clear of the badge, the goal, its step, A.S.H. and everything GoalTest keeps the line off; gone on leaving (%s)" % [
			which, "jumps 0, 15, 16, 25, 33, 40" if bad.is_empty() else "; ".join(bad.slice(0, 5))], bad.is_empty())
		if which == "the chart":
			await _press_reaches_chart()
		if which == "the chart" or which == "the map":
			await _picture_hover_under_badge(which)
	Router.show_local()
	await Harness.frames(_tree, 30)


## A press on the badge on the chart is the chart's: a pan starts (or a star
## there is picked).
func _press_reaches_chart() -> void:
	var b := _badge()
	var chart: Control = (Router.current as StarchartScreen)._chart
	var mid := b.box_rect().get_center().floor()
	_move_to(mid)
	await Harness.frames(_tree, 2)
	var picked := [false]
	var on_pick := func(_i: int) -> void: picked[0] = true
	chart.connect(&"node_picked", on_pick)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = mid
	mb.global_position = mid
	get_viewport().push_input(mb, true)
	await Harness.frames(_tree, 2)
	# (headless keeps no hover, so what the pointer is over is read where the
	# viewport has one)
	var hov := get_viewport().gui_get_hovered_control()
	var reached: bool = bool(chart.get("_dragging")) or picked[0]
	_ok("on the chart a press on the badge reaches the chart's picture under it (pan %s, pick %s; over %s)" % [
		chart.get("_dragging"), picked[0], hov.name if hov != null else "no hover headless"], (hov == null or hov == chart) and reached)
	var up := mb.duplicate() as InputEventMouseButton
	up.pressed = false
	get_viewport().push_input(up, true)
	await Harness.frames(_tree, 2)
	chart.disconnect(&"node_picked", on_pick)
	_move_to(Vector2(8, 300))
	await Harness.frames(_tree, 2)


## One tooltip under the pointer: the picture under the badge must hover nothing.
## Why: docs/why/BadgeTest.md#tooltip-hover
func _picture_hover_under_badge(which: String) -> void:
	var b := _badge()
	Run.jumps = 16
	Run.custodian_seen = 16
	_move_to(Vector2(8, 300))
	await Harness.frames(_tree, 3)
	var mid := b.box_rect().get_center().floor()
	var aside := Vector2(b.box_rect().end.x + 40.0, mid.y)
	var rows: Array[String] = []
	var ok := true
	for spot: Vector2 in [mid, aside]:
		var under := await _bring_under(which, spot)
		var hovered := _picture_hover(which, spot)
		if spot == mid:
			_move_to(mid)
			await Harness.frames(_tree, 18)
			var tip := b.tip.is_visible_in_tree()
			rows.append("under the badge: %s there, the picture hovers %s, the badge's tooltip %s" % [under, hovered, "up" if tip else "shut"])
			ok = ok and under != "" and hovered == "" and tip
		else:
			rows.append("beside it: %s there, hovers %s" % [under, hovered])
			ok = ok and under != "" and hovered != ""
		_move_to(Vector2(8, 300))
		await Harness.frames(_tree, 2)
	_picture_hover(which, Vector2(8, 300))
	_ok("%s: one tooltip at a time, the picture's hover is not under the badge (%s)" % [which, "; ".join(rows)], ok)
	if which == "the chart":
		Router.show_starchart()
	else:
		Router.show_system()
	await Harness.frames(_tree, 30)


## Brings what the picture shows under `spot`: the chart pans, the map takes the first world.
func _bring_under(which: String, spot: Vector2) -> String:
	if which == "the chart":
		var chart: Control = (Router.current as StarchartScreen)._chart
		var p := chart.get_global_transform_with_canvas().affine_inverse() * spot
		var n := Run.node_at()
		chart.pan += p - chart.screen_pos(n)
		chart.queue_redraw()
		await Harness.frames(_tree, 2)
		chart.pan += p - chart.screen_pos(n)
		var h: int = chart._node_at(p)
		return "system %d" % h if h >= 0 else ""
	var sm := Router.current as SystemMapScreen
	var mp: Vector2 = sm._map_at(sm._frame.get_global_transform_with_canvas().affine_inverse() * spot)
	var L: SystemLayout = sm.view.layout
	var i := -1
	for k in L.bodies.size():
		if L.bodies[k].kind != &"belt" and L.bodies[k].kind != &"contact":
			i = k
			break
	if i < 0:
		return ""
	sm.view.at[i] = mp
	var hit: Dictionary = sm.overlay.hit(mp)
	return "%s %d" % [hit.kind, int(hit.body)] if not hit.is_empty() else ""


## The picture's hover after the pointer moves to `spot` (global), handed to it
## as the GUI would: "" nothing.
func _picture_hover(which: String, spot: Vector2) -> String:
	var mm := InputEventMouseMotion.new()
	if which == "the chart":
		var chart: Control = (Router.current as StarchartScreen)._chart
		mm.position = chart.get_global_transform_with_canvas().affine_inverse() * spot
		mm.global_position = spot
		chart._gui_input(mm)
		var h: int = chart.hovered
		var neb: String = chart._neb_hot
		return "system %d" % h if h >= 0 else ("cloud %s" % neb if neb != "" else "")
	var sm := Router.current as SystemMapScreen
	mm.position = sm._frame.get_global_transform_with_canvas().affine_inverse() * spot
	mm.global_position = spot
	sm._on_map_input(mm)
	var hv: Dictionary = sm.overlay.hover
	return "%s %d" % [hv.kind, int(hv.body)] if not hv.is_empty() else ""


## Not a control: it and its contents ignore the mouse, as `GoalTest._not_pressable` checks.
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
# ------------------------------------------------------------------ 8. one Custodian for the galaxy

## Every single step is the page's table; a rise of several plays the biggest edge crossed.
func _coop_kinds() -> void:
	var bad: Array[String] = []
	for j in 41:
		var want: StringName = _expect(j)[3]
		if CustodianBadge.change_kind(j, j - 1) != want or CustodianBadge.change_kind(j) != want \
				or not is_equal_approx(CustodianBadge.trans_len(j, j - 1), CustodianBadge.trans_len(j)):
			bad.append(str(j))
	_ok("every single-step arrival, 0 to 40, is the page's table (%s)" % ("all" if bad.is_empty() else ", ".join(bad)), bad.is_empty())
	var table := [[14, 17, &"wake"], [15, 16, &"wake"], [3, 7, &"tick"], [0, 15, &"tick"], [12, 22, &"worse"],
		[16, 19, &"none"], [18, 26, &"worse"], [21, 24, &"none"], [30, 40, &"full"], [10, 40, &"full"],
		[33, 40, &"none"], [20, 20, &"none"], [22, 21, &"none"]]
	var tb: Array[String] = []
	for row: Array in table:
		var got := CustodianBadge.change_kind(int(row[1]), int(row[0]))
		if got != row[2]:
			tb.append("%d to %d: %s, not %s" % [row[0], row[1], got, row[2]])
	_ok("a rise of several plays the biggest edge crossed: 14 to 17 wakes, 18 to 26 worse, 30 to 40 full, 16 to 19 nothing (%s)"
		% ("all %d" % table.size() if tb.is_empty() else "; ".join(tb)), tb.is_empty())
	# Step 0 is the count at rest, the between steps are that edge's own, the last the new count.
	var fb: Array[String] = []
	for row: Array in [[14, 17, 16], [18, 26, 25], [30, 40, 33], [3, 7, 7], [12, 22, 20]]:
		var from: int = row[0]
		var to: int = row[1]
		var single: int = row[2]
		var n: int = CustodianBadge.TRANS_STEPS[CustodianBadge.change_kind(to, from)]
		for st in n:
			var at := (float(st) + 0.5) / CustodianBadge.TRANS_RATE
			var got := CustodianBadge.frame(to, 0.0, at, 0, 7, from).get_data()
			var want: PackedByteArray
			if st == 0:
				want = CustodianBadge.frame(from, 0.0, -1.0).get_data()
			elif st == n - 1:
				want = CustodianBadge.frame(to, 0.0, -1.0).get_data()
			else:
				want = CustodianBadge.frame(single, 0.0, at).get_data()
			if got != want:
				fb.append("%d to %d step %d" % [from, to, st])
	_ok("its frames: the count it runs from at rest, the edge's own steps, the new count at rest (%s)" % ("all" if fb.is_empty() else ", ".join(fb.slice(0, 6))), fb.is_empty())
	var b := PackedByteArray()
	b.resize(CustodianBadge.IMG_W * CustodianBadge.IMG_H * 4)
	var box0 := CustodianBadge.paint(b, 0, 7, 16, 0.0, 0.05)
	_ok("the wake's first step inks S0's box, the jump before's (%d px, want %d)" % [box0.size.x, CustodianBadge.S0_W], box0.size.x == CustodianBadge.S0_W)


## THE PARTY'S WORDS (Jon, Nov 4), and the solo ones untouched.
func _coop_words() -> void:
	var e := DB.core_boss()
	var head := e.name.to_upper()
	var want := {
		0: [head, "It guards the core.", "It starts to grow stronger", "when the lead ship makes jump 16.", "The lead ship has made 0 jumps."],
		1: [head, "It guards the core.", "It starts to grow stronger", "when the lead ship makes jump 16.", "The lead ship has made 1 jump."],
		15: [head, "It guards the core.", "It starts to grow stronger", "when the lead ship makes jump 16.", "The lead ship has made 15 jumps."],
		16: [head, "It guards the core.", "It grows stronger each time", "the lead ship jumps.", "It woke after jump 15.", "It can grow to twice its strength."],
		20: [head, "It guards the core.", "It grows stronger each time", "the lead ship jumps.", "It is already stronger.", "It can grow to twice its strength."],
		25: [head, "It guards the core.", "It grows stronger each time", "the lead ship jumps.", "It is much stronger now.", "It can grow to twice its strength."],
		33: [head, "It guards the core.", "It is at full strength.", "It will not grow any more."],
	}
	var bad: Array[String] = []
	for j: int in want:
		var got := Array(CustodianBadge.tooltip(j, true))
		if got != want[j]:
			bad.append("%d: %s" % [j, got])
	_ok("the party's tooltip at 0, 1, 15, 16, 20, 25 and 33 (%s)" % ("as Jon put them" if bad.is_empty() else "; ".join(bad)), bad.is_empty())
	var widest := 0
	var hull := false
	for j in 41:
		for l: String in CustodianBadge.tooltip(j, true):
			widest = maxi(widest, l.length())
			hull = hull or l.to_lower().contains("hull") or l.contains(str(e.hull_at(j)))
	_ok("no hull figure in them, and no line wider than the solo tooltip's widest, 34 (%d)" % widest, not hull and widest <= 34)
	var same := true
	for j in 41:
		same = same and CustodianBadge.tooltip(j) == CustodianBadge.tooltip(j, false)
	Run.jumps = 5
	Run.party_jumps = 0
	var solo := CustodianBadge.party()
	Run.party_jumps = 9
	var behind := CustodianBadge.party()
	Run.party_jumps = 0
	Run.jumps = 0
	_ok("alone the words are the solo ones, and the party's show offline only behind a lead ship's count (%s, %s)" % [solo, behind],
		same and not solo and behind)


## On screen, through the real goal line: the count rising under you.
func _coop() -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	await Harness.frames(_tree, 40)
	var b := _badge()
	# Windowed, a new run's LOCAL plays its intro first: wait for the line to be
	# fully up, as an arrival does, before the count moves.
	var waited := await _until_up(b)
	_ok("the line comes up on a new run's LOCAL (after %d more frames)" % waited, waited >= 0)
	# A PARTNER'S JUMP: the lead ship's count rises with no jump of yours, and
	# the tick plays once on LOCAL
	Run.jumps = 10
	Run.custodian_seen = 10
	await Harness.frames(_tree, 5)
	Run.party_jumps = 11
	var rs := _runs(await _watch(120))
	_ok("a partner's jump past yours plays its arrival once, with no jump of yours (steps:frames %s; seen %d, shown %d)" % [
		", ".join(rs.map(func(r: Array) -> String: return "%d:%d" % r)), Run.custodian_seen, int(b.shown.get("j", -1))],
		_steps_ok(rs, 4) and Run.custodian_seen == 11 and int(b.shown.get("j", -1)) == 11 and Run.jumps == 10)
	var replay := false
	for step_to: Callable in [Router.show_starchart, Router.show_system, Router.show_local]:
		step_to.call()
		if (await _watch(40)).any(func(s: int) -> bool: return s >= 0):
			replay = true
	_ok("and never again on a screen change", not replay and Run.custodian_seen == 11)
	# 14 TO 17: the wake, ending on S1; the hover box is the look on show
	for row: Array in [[14, 17, &"wake"], [18, 26, &"worse"], [30, 40, &"full"]]:
		Run.party_jumps = 0
		Run.jumps = int(row[0])
		Run.custodian_seen = int(row[0])
		await Harness.frames(_tree, 5)
		Run.party_jumps = int(row[1])
		var seq: Array = []
		var w0: Array = []
		var wi: Array = []
		var froms: Array = []
		for i in 150:
			await Harness.frames(_tree, 1)
			_check_screen(b)
			var st := int(b.shown.get("step", -2))
			seq.append(st)
			if st == 0:
				w0.append(b.box_rect().size.x)
			if st >= 0:
				froms.append(int(b.shown.get("from", -1)))
			elif st == -1:
				wi.append(b.box_rect().size.x)
		var r2 := _runs(seq)
		var n: int = CustodianBadge.TRANS_STEPS[row[2]]
		var ends := CustodianBadge.stage(int(b.shown.get("j", -1)))
		var from_ok := froms.all(func(f: int) -> bool: return f == int(row[0]))
		_ok("%d to %d plays the %s from %d at rest and ends at %s (steps:frames %s)" % [row[0], row[1], row[2], row[0], ends,
			", ".join(r2.map(func(r: Array) -> String: return "%d:%d" % r))],
			_steps_ok(r2, n) and from_ok and Run.custodian_seen == int(row[1]) and int(b.shown.get("j", -1)) == int(row[1]))
		if int(row[0]) == 14:
			_ok("the wake ends at S1 (%s), its hover box S0's 37 px on its first step and 24 at rest (%s, %s)" % [ends,
				str(w0.slice(0, 1)), str(wi.slice(0, 1))], ends == &"S1"
				and w0.all(func(w: float) -> bool: return int(w) == CustodianBadge.S0_W)
				and not wi.is_empty() and wi.all(func(w: float) -> bool: return int(w) == CustodianBadge.BOX_W))
			# the box follows the count, not your jumps (14: S0's 37 px)
			var t := b.get_global_transform_with_canvas()
			var inside := t * Vector2(10, 7)
			var past := t * Vector2(30, 7)
			_ok("the box and covers() follow the count, 17, not your 14 (%d px; covers 10 px in %s, 30 px in %s)" % [
				int(b.box_rect().size.x), CustodianBadge.covers(inside), CustodianBadge.covers(past)],
				int(b.box_rect().size.x) == CustodianBadge.BOX_W and CustodianBadge.covers(inside) and not CustodianBadge.covers(past))
	# Alone, an arrival that never showed plays the wake from 15, where jump 16 played nothing.
	Run.party_jumps = 0
	Run.jumps = 15
	Run.custodian_seen = 15
	await Harness.frames(_tree, 5)
	Run.jumps = 17
	var seq6: Array = []
	var froms6: Array = []
	for i in 150:
		await Harness.frames(_tree, 1)
		var st6 := int(b.shown.get("step", -2))
		seq6.append(st6)
		if st6 >= 0:
			froms6.append(int(b.shown.get("from", -1)))
	var r6 := _runs(seq6)
	_ok("alone, 15 shown and 17 jumps plays the wake from 15 and ends at S1 (steps:frames %s)" % ", ".join(
		r6.map(func(r: Array) -> String: return "%d:%d" % r)),
		not CustodianBadge.party() and _steps_ok(r6, CustodianBadge.TRANS_STEPS[&"wake"])
		and froms6.all(func(f: int) -> bool: return f == 15)
		and CustodianBadge.stage(int(b.shown.get("j", -1))) == &"S1" and Run.custodian_seen == 17)
	# THE DOOR (a late joiner, a rejoiner): the host's quiet push on a fresh
	# run plays nothing; the eye is as it is on the first frame
	var door := NetSession.new()
	door.state = NetSession.State.DIVING
	door.dive_seed = Run.galaxy_seed
	var loud: Array[String] = []
	for g: int in [0, 16, 20, 33]:
		Run.jumps = 0
		Run.party_jumps = 0
		Run.custodian_seen = 0
		await Harness.frames(_tree, 4)
		door.galaxy_jumps = 0
		door._push_growth_to(g, true)
		var seq4: Array = await _watch(60)
		if seq4.any(func(s: int) -> bool: return s >= 0) or int(b.shown.get("j", -1)) != g or Run.custodian_seen != g:
			loud.append("%d: shown %d, seen %d" % [g, int(b.shown.get("j", -1)), Run.custodian_seen])
	door.free()
	_ok("the door's quiet push at 0, 16, 20 and 33 shows the eye as it is and plays nothing (%s)" % ("so" if loud.is_empty() else "; ".join(loud)), loud.is_empty())
	# YOUR OWN JUMP BEHIND THE LEAD plays nothing: the count does not move
	Run.party_jumps = 30
	Run.jumps = 20
	Run.custodian_seen = 30
	await Harness.frames(_tree, 5)
	Run.jumps = 21
	var seq5: Array = await _watch(60)
	_ok("your own jump behind the lead ship plays nothing (shows %d)" % int(b.shown.get("j", -1)),
		not seq5.any(func(s: int) -> bool: return s >= 0) and int(b.shown.get("j", -1)) == 30)
	# THE TOOLTIP ON SCREEN says the party's words behind a lead ship
	_move_to(Vector2(8, 300))
	await Harness.frames(_tree, 3)
	_move_to(b.box_rect().get_center().floor())
	await Harness.frames(_tree, 20)
	var lines: Array[String] = []
	if b.tip != null and b.tip.is_visible_in_tree():
		for l in b._tip_box.get_children():
			if l is Label:
				lines.append((l as Label).text)
	_ok("its tooltip behind a lead ship at 30 says the party's words (%s)" % " / ".join(lines), lines == Array(CustodianBadge.tooltip(30, true)))
	_move_to(Vector2(8, 300))
	await Harness.frames(_tree, 3)
	Run.party_jumps = 0
	Run.jumps = 0
	Run.custodian_seen = 0
	await Harness.frames(_tree, 5)


## An arrival's runs: steps 0 to n-1 at about 6 frames each (10 a second at 60),
## then idle.
func _steps_ok(rs: Array, n: int) -> bool:
	if rs.size() != n + 1 or (rs.back() as Array)[0] != -1:
		return false
	for s in n:
		if (rs[s] as Array)[0] != s or absi(int((rs[s] as Array)[1]) - 6) > 1:
			return false
	return true


func _no_growth() -> void:
	Router.show_local()
	await Harness.frames(_tree, 30)
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	await Harness.frames(_tree, 60)
	var with_badge := _clickables()
	var e := DB.core_boss()
	var was := e.grow_after
	e.grow_after = -1
	await Harness.frames(_tree, 3)
	var g := _goal()
	var off_ok := not CustodianBadge.enabled() and not _badge().visible and g.size == g._panel.size
	var without := _clickables()
	e.grow_after = was
	await Harness.frames(_tree, 3)
	_ok("a core boss that never grows has no badge, and the line is its words alone (%s)" % g.size if not off_ok else "a core boss that never grows has no badge, and the line is its words alone", off_ok)
	_ok("nothing clickable moves for the badge (%d controls: the HUD's tabs, the fight's END TURN, LOG, the hand)" % with_badge.size(),
		with_badge == without and with_badge.size() > 3)
	Router.show_local()
	await Harness.frames(_tree, 20)


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
	harness.verdict("badgetest")
	_tree.quit(harness.code())
