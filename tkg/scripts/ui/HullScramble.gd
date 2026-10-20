class_name HullScramble
extends Node

## THE WORDS DECODE BADLY WHILE THE HULL FAILS (`LowHull`). Jon, Oct 20: "I
## think the text should glitch more like the decoding. It should be ALL of the
## text on the screen. With it getting worse as the health lowers." And then:
## "This goes outside of combat too." "Tool tips etc. Only the ESC menu doesn't
## glitch."
##
## WHAT: now and then a letter somewhere on screen -- or a short run of them,
## inside one word -- turns into the same noise `SignalText` decodes from (its
## NOISE glyphs, at its NOISE_A ink, changing every NOISE_S), and then resolves
## back, left to right. Every text the player can see: the HUD (its hull figure
## too), the top bar, the goal line, buttons, panels, A.S.H.'s box, cards, the
## chart's and the map's names, popups and tooltips. Never the escape menu or
## Settings (Main's overlay layer), and nothing at all while the menu is open.
##
## HOW MUCH follows the hull, continuously: `LowHull.depth` is 0 at TIER1_AT and
## 1 at no hull, eased, and from it come how many letters start a second
## (`scr.rate`, rising as depth^1.5, for a screen of REF_LETTERS letters), how
## long a run is (1 letter at the line,
## up to `scr.run` near 0) and how long each holds (`scr.hold`). Two ceilings
## keep it readable at 5%: at most `scr.most` letters scrambled on the whole
## screen at once, and at most `scr.share` of any one text's letters. Every
## number is the preset's (`LowHull.LOOKS`).
##
## NOTHING MOVES, NOTHING IS REWRITTEN. No string is ever changed and no
## control's layout is touched:
##   * a Label, a Button or a RichTextLabel keeps drawing itself as it always
##     does; a shader on its canvas item (set through the RenderingServer, not
##     its `material`, and taken off after) leaves its glyph pixels out inside
##     the scrambled letters' cells (`low_hull_mask.gdshader`), and a canvas
##     item of this node's own, a child of the control's, draws the noise glyph
##     in each cell. So it clips, fades, scales and stacks with the control (a
##     tooltip over it hides it; a popup over it hides it), and a click, a hover
##     and a rect are exactly what they were;
##   * `SignalText` draws its own letters, so it is told which settled letters
##     are noise (`SignalText.scramble`) and draws those;
##   * text a screen draws by hand (the chart's names, the outcome rows, the
##     cards' numbers...) asks `LowHull.scr` for the string to DRAW: the same
##     string, with a scrambled letter swapped for a noise glyph of exactly the
##     same advance, and the whole string's width checked equal, so not a pixel
##     after it moves. Its own data never sees that string.
## Whatever reads a Label's text, a save, a test, a tooltip's builder, reads the
## real words, because they are never anything else.
##
## THE COST: the texts on screen are found as they enter the tree
## (`SceneTree.node_added`), never by walking it, and which of them are showing
## is re-checked SCAN_PER_FRAME at a time while the effect is on. Nothing here
## runs at all with the hull sound (and nothing is ever handed to a worker: it is
## all RenderingServer and Control calls, which are the main thread's).

## The noise and its pace: `SignalText`'s, so it reads as the same decoding.
const NOISE := SignalText.NOISE
const FLIP_S := SignalText.NOISE_S
const INK_A := SignalText.NOISE_A
## A run resolves left to right, one letter every RESOLVE_S.
const RESOLVE_S := 0.03
## How many known texts are re-checked a frame (on screen? still showing?).
const SCAN_PER_FRAME := 80
## Cells one control may have at once (the mask shader's array).
const SLOTS := 8
## A text's pull on where the next scramble lands is its letter count, up to
## this: letters, not controls, are what is spread evenly over the screen.
const WEIGHT_MAX := 240
## THE RATE IS FOR A SCREEN OF REF_LETTERS LETTERS, and a screen with more or
## fewer gets more or fewer (between DENSITY's two shares of it): how worse it
## looks is how many of the letters are noise, so a bare LOCAL (a top bar,
## ~120 letters) is not three times as broken as a station deck full of words.
const REF_LETTERS := 240
const DENSITY := [0.6, 2.0]
## Hand-drawn text not drawn for this long, s, is off the screen.
const DRAWN_STALE_S := 0.5

enum Kind { LABEL, BUTTON, RICH, SIGNAL, DRAWN }

const MASK := preload("res://shaders/low_hull_mask.gdshader")

static var instance: HullScramble = null
## For a harness: letters scrambled now, and every scramble started
## ({at, node, kind, n, text}).
static var cells_now := 0
static var started_log: Array = []
## Microseconds this node's frame cost, last frame and the most since cleared.
static var cost_usec := 0
static var cost_most := 0

var _pool: Array = []          ## every text control known: Label, Button, RichTextLabel, SignalText
var _pool_ix := {}             ## instance id -> index in _pool
var _elig: Array = []          ## [[node or drawn key, weight, kind]] showing now
var _elig_ix := {}             ## instance id or drawn key -> index in _elig
var _wsum := 0                 ## their weights, summed
var _scan := 0
var _acc := 0.0
var _live := {}                ## instance id or drawn key -> entry
var _drawn := {}               ## drawn key -> {owner, text, size, font, seen, w}
var _drawn_scan: Array = []
var _mats: Array[ShaderMaterial] = []
var _noise_by := {}            ## "font rid|size" -> {advance: [glyphs]}
var _btn_cache := {}           ## instance id -> {key, cells}
var _rich_cache := {}          ## instance id -> {key, lines, ink}
var _active := false
var _rng := RandomNumberGenerator.new()
var _overlay: CanvasLayer = null


func _init() -> void:
	name = "HullScramble"


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	get_tree().node_added.connect(_on_added)
	get_tree().node_removed.connect(_on_removed)
	_seed_pool.call_deferred()


func _exit_tree() -> void:
	clear()
	if instance == self:
		instance = null


## Seed the rolls (a harness, for numbers that repeat).
func seed_rolls(s: int) -> void:
	_rng.seed = s


func _seed_pool() -> void:
	for n in get_tree().root.find_children("*", "", true, false):
		_on_added(n)


static func _is_text(n: Node) -> bool:
	return n is Label or n is RichTextLabel or n is SignalText \
		or (n is Button and n.get_class() == "Button")


func _on_added(n: Node) -> void:
	if not _is_text(n):
		return
	var id := n.get_instance_id()
	if _pool_ix.has(id):
		return
	_pool_ix[id] = _pool.size()
	_pool.append(n)


func _on_removed(n: Node) -> void:
	var id := n.get_instance_id()
	if not _pool_ix.has(id):
		return
	_release(id)
	_unelig(id)
	var i: int = _pool_ix[id]
	var last = _pool[_pool.size() - 1]
	_pool[i] = last
	_pool_ix[last.get_instance_id()] = i
	_pool.pop_back()
	_pool_ix.erase(id)
	_btn_cache.erase(id)
	_rich_cache.erase(id)


func _set_elig(key: Variant, who: Variant, w: int, kind: int) -> void:
	if w <= 0:
		_unelig(key)
		return
	if _elig_ix.has(key):
		var row: Array = _elig[_elig_ix[key]]
		_wsum += w - int(row[1])
		row[1] = w
		return
	_elig_ix[key] = _elig.size()
	_elig.append([who, w, kind, key])
	_wsum += w


func _unelig(key: Variant) -> void:
	if not _elig_ix.has(key):
		return
	var i: int = _elig_ix[key]
	_wsum -= int((_elig[i] as Array)[1])
	var last: Array = _elig[_elig.size() - 1]
	_elig[i] = last
	_elig_ix[last[3]] = i
	_elig.pop_back()
	_elig_ix.erase(key)


## May anything scramble now: the hull failing, the screen animated, a run up,
## the escape menu shut.
func _may() -> bool:
	if LowHull.instance == null or LowHull.on <= 0.001 or not LowHull.moving():
		return false
	if get_tree().paused or not LowHull.in_run():
		return false
	var main := LowHull.instance.get_parent()
	if main != null:
		if "_menu" in main and main._menu != null:
			return false
		if "_settings" in main and main._settings != null:
			return false
		if "_overlay" in main:
			_overlay = main._overlay
	return true


func _process(_d: float) -> void:
	var t0 := Time.get_ticks_usec()
	var now := GameClock.now()
	var may := _may()
	if not may:
		if _active:
			clear()
		_active = false
		_acc = 0.0
		cost_usec = Time.get_ticks_usec() - t0
		return
	_active = true
	var dt := clampf(get_process_delta_time(), 0.0, 0.25)
	var lk: Dictionary = LowHull.look().scr
	var d := LowHull.depth
	var rate := lerpf(float(lk.rate[0]), float(lk.rate[1]), pow(d, 1.5)) * smoothstep(0.0, 1.0, LowHull.on) 		* clampf(float(_wsum) / float(REF_LETTERS), DENSITY[0], DENSITY[1])
	_refresh_some(now)
	_acc += rate * dt
	var guard := 0
	while _acc >= 1.0 and guard < 16:
		_acc -= 1.0
		guard += 1
		# a text already at its own ceiling is not a scramble lost: another one
		for t in 4:
			if _spawn(now, d, lk) != 0:
				break
	_age(now)
	cost_usec = Time.get_ticks_usec() - t0
	cost_most = maxi(cost_most, cost_usec)


# ------------------------------------------------------------------ which texts show

func _refresh_some(now: float) -> void:
	var n := _pool.size()
	if n > 0:
		for k in mini(SCAN_PER_FRAME, n):
			_scan = (_scan + 1) % n
			var c = _pool[_scan]
			if not is_instance_valid(c):
				continue
			_set_elig(c.get_instance_id(), c, _weight(c as Control), _kind_of(c))
	# hand-drawn: seen lately, and its owner still showing
	if _drawn_scan.is_empty():
		_drawn_scan = _drawn.keys()
	for k in mini(SCAN_PER_FRAME, _drawn_scan.size()):
		var key: String = _drawn_scan.pop_back()
		if not _drawn.has(key):
			continue
		var e: Dictionary = _drawn[key]
		var o = e.owner
		if not is_instance_valid(o) or now - float(e.seen) > DRAWN_STALE_S \
				or not (o as CanvasItem).is_visible_in_tree():
			_release(key)
			_unelig(key)
			_drawn.erase(key)
			continue
		_set_elig(key, key, int(e.w), Kind.DRAWN)


static func _kind_of(c: Object) -> int:
	if c is SignalText:
		return Kind.SIGNAL
	if c is RichTextLabel:
		return Kind.RICH
	if c is Button:
		return Kind.BUTTON
	return Kind.LABEL


## How strongly this text pulls the next scramble: its letters, 0 if it is not
## one that may scramble now.
func _weight(c: Control) -> int:
	if c == null or not c.is_inside_tree() or not c.is_visible_in_tree() or c is FpsMeter:
		return 0
	if _overlay != null and c.get_canvas_layer_node() == _overlay:
		return 0
	var s := _text_of(c)
	if s.strip_edges() == "":
		return 0
	if not (c is SignalText) and (c.material != null or c.use_parent_material):
		return 0
	var xf := c.get_global_transform_with_canvas()
	var r := (xf * Rect2(Vector2.ZERO, c.size)).abs()
	if not r.intersects(c.get_viewport().get_visible_rect()):
		return 0
	return mini(WEIGHT_MAX, s.length() - s.count(" "))


static func _text_of(c: Object) -> String:
	if c is Label:
		return (c as Label).text
	if c is Button:
		return (c as Button).text
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text()
	if c is SignalText:
		var st := c as SignalText
		return st.text if st.done else st.text.left(int(st.shown))
	return ""


# ------------------------------------------------------------------ hand-drawn text

## The string to DRAW for `s` drawn by `owner` (`LowHull.scr`). Registers it as
## a text on screen; returns `s` itself unless some of its letters are noise.
func drawn(owner: CanvasItem, s: String, size: int, font: Font) -> String:
	if not _active or s.length() == 0:
		return s
	var key := "%d|%s" % [owner.get_instance_id(), s]
	var e: Dictionary = _drawn.get(key, {})
	if e.is_empty():
		if _overlay != null and owner.get_canvas_layer_node() == _overlay:
			return s
		e = {owner = owner, text = s, size = size, font = font, seen = 0.0, w = mini(WEIGHT_MAX, s.length() - s.count(" "))}
		_drawn[key] = e
	e.seen = GameClock.now()
	var lv: Dictionary = _live.get(key, {})
	if lv.is_empty():
		return s
	var out := s
	for cell: Dictionary in lv.cells:
		out[int(cell.i)] = String(cell.g)
	return out


# ------------------------------------------------------------------ starting one

## A text, by its letters: a letter anywhere on screen is as likely as any other.
func _pick() -> Array:
	if _elig.is_empty() or _wsum <= 0:
		return []
	var r := _rng.randi() % _wsum
	for row: Array in _elig:
		r -= int(row[1])
		if r < 0:
			return row
	return _elig.back()


## Start one run of noise. 1 started, -1 the screen at its ceiling or nothing
## to pick (no point trying again), 0 this pick could not take one.
func _spawn(now: float, d: float, lk: Dictionary) -> int:
	if cells_now >= int(lk.most):
		return -1
	var row := _pick()
	if row.is_empty():
		return -1
	var kind: int = row[2]
	var key: Variant = row[3]
	var text := ""
	var who = null
	if kind == Kind.DRAWN:
		if not _drawn.has(key):
			return 0
		var de: Dictionary = _drawn[key]
		who = de.owner
		text = String(de.text)
	else:
		who = row[0]
		if not is_instance_valid(who) or not (who as Control).is_visible_in_tree():
			return 0
		text = _text_of(who)
	if not is_instance_valid(who):
		return 0
	var letters := text.length() - text.count(" ")
	if letters <= 0:
		return 0
	var lv: Dictionary = _live.get(key, {})
	var have := 0 if lv.is_empty() else (lv.cells as Array).size()
	var cap := mini(SLOTS, maxi(1, int(floorf(float(letters) * float(lk.share)))))
	if have >= cap:
		return 0
	# where: any letter, and the run goes on to its right inside the word
	var at := _rng.randi() % text.length()
	var tries := 0
	while text[at] == " " or text[at] == "\n":
		at = (at + 1) % text.length()
		tries += 1
		if tries > text.length():
			return 0
	var run_most := 1 + int(floorf(lerpf(0.0, float(int(lk.run) - 1), d) + 0.0001))
	var run := 1 + _rng.randi() % run_most
	run = mini(run, mini(cap - have, int(lk.most) - cells_now))
	var hold := lerpf(float(lk.hold[0]), float(lk.hold[1]), d) * _rng.randf_range(0.7, 1.3)
	var cells: Array = []
	var taken := {}
	if not lv.is_empty():
		for c: Dictionary in lv.cells:
			taken[int(c.i)] = true
	var i := at
	while cells.size() < run and i < text.length():
		var ch := text[i]
		if ch == " " or ch == "\n":
			break
		if not taken.has(i):
			var cell := _cell(who, kind, i, text, key)
			if not cell.is_empty():
				cell.i = i
				cell.ch = ch
				cell.until = now + hold + RESOLVE_S * float(cells.size())
				cell.flip = 0.0
				cells.append(cell)
		i += 1
	if cells.is_empty():
		return 0
	if lv.is_empty():
		lv = {node = who, kind = kind, cells = [], ci = RID(), mat = null, key = key}
		_live[key] = lv
	var placed := 0
	for c: Dictionary in cells:
		_reglyph(lv, c)
		if String(c.get("g", "")) == "":
			continue
		(lv.cells as Array).append(c)
		placed += 1
	cells_now += placed
	if (lv.cells as Array).is_empty():
		_release(key)
		return 0
	started_log.append({at = now, node = who, kind = kind, n = placed, text = text})
	_paint(lv, true)
	return 1


## Where letter `i` of this text sits, in the control's own pixels:
## {r: its cell, base: its baseline's left end, adv, font, size, ink, outline...}.
## Empty if it cannot be placed exactly.
func _cell(who: Object, kind: int, i: int, text: String, key: Variant) -> Dictionary:
	match kind:
		Kind.LABEL:
			return _label_cell(who as Label, i)
		Kind.BUTTON:
			return _button_cell(who as Button, i)
		Kind.RICH:
			return _rich_cell(who as RichTextLabel, i)
		Kind.SIGNAL:
			return _signal_cell(who as SignalText, i)
		Kind.DRAWN:
			return _drawn_cell(key, i, text)
	return {}


func _label_cell(l: Label, i: int) -> Dictionary:
	if l.visible_characters >= 0 and i >= l.visible_characters:
		return {}
	var r := l.get_character_bounds(i)
	if r.size.x < 1.0 or r.size.y < 1.0:
		return {}
	var ls := l.label_settings
	var font: Font = ls.font if ls != null and ls.font != null else l.get_theme_font(&"font")
	var fs: int = ls.font_size if ls != null else l.get_theme_font_size(&"font_size")
	var ink: Color = ls.font_color if ls != null else l.get_theme_color(&"font_color")
	var cell := {r = r, base = Vector2(r.position.x, r.position.y + font.get_ascent(fs)), adv = r.size.x,
		font = font, size = fs, ink = ink * l.self_modulate}
	var osz: int = ls.outline_size if ls != null else l.get_theme_constant(&"outline_size")
	if osz > 0:
		cell.outline = osz
		cell.outline_ink = (ls.outline_color if ls != null else l.get_theme_color(&"font_outline_color")) * l.self_modulate
	var sh: Color = ls.shadow_color if ls != null else l.get_theme_color(&"font_shadow_color")
	if sh.a > 0.0:
		cell.shadow = sh * l.self_modulate
		cell.shadow_at = ls.shadow_offset if ls != null else Vector2(
			l.get_theme_constant(&"shadow_offset_x"), l.get_theme_constant(&"shadow_offset_y"))
	return cell


func _signal_cell(st: SignalText, i: int) -> Dictionary:
	if not st.done and i >= int(st.shown):
		return {}
	var f := st._font()
	var lh := st._line_h()
	var asc := f.get_ascent(st.size_px)
	for li in st._lines.size():
		var L: Dictionary = st._lines[li]
		var s := int(L.s)
		var t: String = L.t
		if i < s or i >= s + t.length():
			continue
		var xs: PackedFloat32Array = L.x
		var j := i - s
		var y := float(li * lh)
		return {r = Rect2(xs[j], y, xs[j + 1] - xs[j], float(lh - SignalText.LINE_GAP)),
			base = Vector2(xs[j], y + asc), adv = xs[j + 1] - xs[j], font = f, size = st.size_px, ink = st.ink}
	return {}


## A Button's words, laid out the way `Button::_notification(DRAW)` lays them
## (Godot 4.7.1: its TextParagraph, the state's stylebox margins, an icon to the
## left or right, centred lines floored). One text a time, cached.
func _button_cell(b: Button, i: int) -> Dictionary:
	var font := b.get_theme_font(&"font")
	var fs := b.get_theme_font_size(&"font_size")
	var mode := b.get_draw_mode()
	var key := "%s|%d|%d|%s|%d|%d" % [b.text, fs, mode, b.size, b.alignment, b.icon_alignment]
	var id := b.get_instance_id()
	var cc: Dictionary = _btn_cache.get(id, {})
	if cc.get("key", "") != key:
		cc = {key = key, cells = _button_layout(b, font, fs, mode)}
		_btn_cache[id] = cc
	var cells: Dictionary = cc.cells
	if not cells.has(i):
		return {}
	var c: Dictionary = (cells[i] as Dictionary).duplicate()
	c.font = font
	c.size = fs
	c.ink = _button_ink(b, mode) * b.self_modulate
	var osz := b.get_theme_constant(&"outline_size")
	if osz > 0:
		c.outline = osz
		c.outline_ink = b.get_theme_color(&"font_outline_color") * b.self_modulate
	return c


static func _button_style(b: Button, mode: int) -> StyleBox:
	match mode:
		BaseButton.DRAW_PRESSED:
			return b.get_theme_stylebox(&"pressed")
		BaseButton.DRAW_HOVER:
			return b.get_theme_stylebox(&"hover")
		BaseButton.DRAW_DISABLED:
			return b.get_theme_stylebox(&"disabled")
		BaseButton.DRAW_HOVER_PRESSED:
			return b.get_theme_stylebox(&"hover_pressed") if b.has_theme_stylebox(&"hover_pressed") else b.get_theme_stylebox(&"pressed")
	return b.get_theme_stylebox(&"normal")


static func _button_ink(b: Button, mode: int) -> Color:
	match mode:
		BaseButton.DRAW_PRESSED:
			return b.get_theme_color(&"font_pressed_color") if b.has_theme_color(&"font_pressed_color") else b.get_theme_color(&"font_color")
		BaseButton.DRAW_HOVER:
			return b.get_theme_color(&"font_hover_color")
		BaseButton.DRAW_DISABLED:
			return b.get_theme_color(&"font_disabled_color")
		BaseButton.DRAW_HOVER_PRESSED:
			return b.get_theme_color(&"font_hover_pressed_color")
	if b.has_focus():
		return b.get_theme_color(&"font_focus_color")
	return b.get_theme_color(&"font_color")


static func _button_layout(b: Button, font: Font, fs: int, mode: int) -> Dictionary:
	var out := {}
	if font == null or fs <= 0 or b.text == "" or b.expand_icon:
		return out
	var style := _button_style(b, mode)
	var ml := style.get_margin(SIDE_LEFT)
	var mr := style.get_margin(SIDE_RIGHT)
	var mt := style.get_margin(SIDE_TOP)
	var mb := style.get_margin(SIDE_BOTTOM)
	if b.get_theme_constant(&"align_to_largest_stylebox") != 0:
		for nm in [&"normal", &"hover", &"pressed", &"disabled", &"hover_pressed", &"normal_mirrored"]:
			if b.has_theme_stylebox(nm):
				var s2 := b.get_theme_stylebox(nm)
				ml = maxf(ml, s2.get_margin(SIDE_LEFT))
				mr = maxf(mr, s2.get_margin(SIDE_RIGHT))
				mt = maxf(mt, s2.get_margin(SIDE_TOP))
				mb = maxf(mb, s2.get_margin(SIDE_BOTTOM))
	var dw := b.size.x - ml - mr
	var dh := b.size.y - mt - mb
	var icon_left := 0.0
	var ic: Texture2D = b.icon
	if ic == null and b.has_theme_icon(&"icon"):
		ic = b.get_theme_icon(&"icon")
	if ic != null:
		if b.vertical_icon_alignment != VERTICAL_ALIGNMENT_CENTER:
			return out
		var isz := ic.get_size()
		var maxw := b.get_theme_constant(&"icon_max_width")
		if maxw > 0 and isz.x > maxw:
			isz = Vector2(maxw, isz.y * maxw / isz.x)
		isz = isz.round()
		var hsep := maxi(0, b.get_theme_constant(&"h_separation"))
		if isz.x > 0.0 and b.icon_alignment != HORIZONTAL_ALIGNMENT_CENTER:
			dw -= isz.x + hsep
			if b.icon_alignment == HORIZONTAL_ALIGNMENT_LEFT:
				icon_left = isz.x + hsep
	var p := TextParagraph.new()
	var flags := TextServer.BREAK_MANDATORY
	match b.autowrap_mode:
		TextServer.AUTOWRAP_WORD_SMART:
			flags = TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_MANDATORY
		TextServer.AUTOWRAP_WORD:
			flags = TextServer.BREAK_WORD_BOUND | TextServer.BREAK_MANDATORY
		TextServer.AUTOWRAP_ARBITRARY:
			flags = TextServer.BREAK_GRAPHEME_BOUND | TextServer.BREAK_MANDATORY
	p.break_flags = flags | b.autowrap_trim_flags
	p.line_spacing = b.get_theme_constant(&"line_spacing")
	p.add_string(b.text, font, fs)
	p.text_overrun_behavior = b.text_overrun_behavior
	p.alignment = b.alignment
	var tw := ceilf(maxf(1.0, dw))
	p.width = tw
	var ox := 0.0
	if b.alignment == HORIZONTAL_ALIGNMENT_CENTER:
		ox = (dw - tw) / 2.0
	ox += ml + icon_left
	var y := (dh - p.get_size().y) / 2.0 + mt
	var ts := TextServerManager.get_primary_interface()
	for li in p.get_line_count():
		var rid := p.get_line_rid(li)
		var asc := ts.shaped_text_get_ascent(rid)
		var dsc := ts.shaped_text_get_descent(rid)
		var lw := ts.shaped_text_get_width(rid)
		var x := ox
		match b.alignment:
			HORIZONTAL_ALIGNMENT_CENTER:
				if lw <= tw:
					x += floorf((tw - lw) / 2.0)
			HORIZONTAL_ALIGNMENT_RIGHT:
				x += tw - lw
		y += asc
		var gx := 0.0
		for g: Dictionary in ts.shaped_text_get_glyphs(rid):
			var adv := float(g.advance) * float(g.get("repeat", 1))
			if int(g.get("count", 1)) > 0 and int(g.end) - int(g.start) == 1:
				var cx := roundf(x + gx)
				out[int(g.start)] = {r = Rect2(cx, roundf(y - asc), adv, asc + dsc), base = Vector2(cx, roundf(y)), adv = adv}
			gx += adv
		y += dsc + float(p.line_spacing)
	return out


## A RichTextLabel's letter: its line from the label itself (`get_line_range`,
## `get_line_offset`), its place along the line by shaping that line's words in
## the label's normal face, its colour from the BBCode. A line in another size
## (a heading in `font_size`) is left alone: it cannot be placed exactly.
func _rich_cell(rt: RichTextLabel, i: int) -> Dictionary:
	if rt.visible_characters >= 0 and i >= rt.visible_characters:
		return {}
	var font := rt.get_theme_font(&"normal_font")
	var fs := rt.get_theme_font_size(&"normal_font_size")
	var parsed := rt.get_parsed_text()
	var id := rt.get_instance_id()
	var key := "%s|%d|%s" % [rt.text, fs, rt.size]
	var cc: Dictionary = _rich_cache.get(id, {})
	if cc.get("key", "") != key:
		cc = {key = key, ink = _rich_ink(rt.text if rt.bbcode_enabled else "", parsed.length(),
			rt.get_theme_color(&"default_color")), lines = []}
		_rich_cache[id] = cc
	var lines: Array = cc.lines
	if lines.is_empty():
		var st := rt.get_theme_stylebox(&"normal")
		var ml := st.get_margin(SIDE_LEFT)
		var mt := st.get_margin(SIDE_TOP)
		var fh := font.get_height(fs)
		var ts := TextServerManager.get_primary_interface()
		for li in rt.get_line_count():
			var rg := rt.get_line_range(li)
			var h := float(rt.get_line_height(li))
			if h > fh + maxf(0.0, float(rt.get_theme_constant(&"line_separation"))) + 1.5:
				lines.append({})
				continue
			var tl := TextLine.new()
			tl.add_string(parsed.substr(rg.x, rg.y - rg.x), font, fs)
			var xs := {}
			var gx := 0.0
			for g: Dictionary in ts.shaped_text_get_glyphs(tl.get_rid()):
				var adv := float(g.advance) * float(g.get("repeat", 1))
				if int(g.end) - int(g.start) == 1:
					xs[rg.x + int(g.start)] = Vector2(gx, adv)
				gx += adv
			var x0 := ml
			var cw := rt.size.x - ml - st.get_margin(SIDE_RIGHT)
			if rt.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
				x0 += floorf((cw - float(rt.get_line_width(li))) / 2.0)
			elif rt.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
				x0 += cw - float(rt.get_line_width(li))
			lines.append({from = rg.x, to = rg.y, y = mt + float(rt.get_line_offset(li)), xs = xs, x0 = x0})
	var scroll := 0.0
	if rt.scroll_active and rt.get_v_scroll_bar() != null:
		scroll = rt.get_v_scroll_bar().value
	for L: Dictionary in lines:
		if L.is_empty() or i < int(L.from) or i >= int(L.to):
			continue
		var xs: Dictionary = L.xs
		if not xs.has(i):
			return {}
		var v: Vector2 = xs[i]
		var x := roundf(float(L.x0) + v.x)
		var y := roundf(float(L.y) - scroll)
		var asc := font.get_ascent(fs)
		var inks: PackedColorArray = cc.ink
		var ink: Color = inks[i] if i < inks.size() else rt.get_theme_color(&"default_color")
		return {r = Rect2(x, y, v.y, font.get_height(fs)), base = Vector2(x, y + asc), adv = v.y,
			font = font, size = fs, ink = ink * rt.self_modulate}
	return {}


## The colour each letter of a RichTextLabel is drawn in, from its BBCode's
## `[color]` tags (everything else is the default colour). Empty if the count
## does not come out at the parsed text's length (a tag this does not know).
static func _rich_ink(bb: String, n: int, base: Color) -> PackedColorArray:
	var out := PackedColorArray()
	if bb == "":
		out.resize(n)
		out.fill(base)
		return out
	var stack: Array[Color] = [base]
	var i := 0
	while i < bb.length():
		if bb[i] == "[":
			var j := bb.find("]", i)
			if j > i:
				var tag := bb.substr(i + 1, j - i - 1)
				if tag.begins_with("color="):
					stack.append(Color.from_string(tag.substr(6), stack.back()))
				elif tag == "/color":
					if stack.size() > 1:
						stack.pop_back()
				elif tag == "lb" or tag == "rb":
					out.append(stack.back())
				i = j + 1
				continue
		out.append(stack.back())
		i += 1
	if out.size() != n:
		out.resize(n)
		out.fill(base)
	return out


## Hand-drawn: no place is needed (the owner draws the string where it always
## does); only a letter whose noise has exactly its advance, and a string that
## comes out exactly as wide.
func _drawn_cell(key: Variant, i: int, text: String) -> Dictionary:
	var e: Dictionary = _drawn.get(key, {})
	if e.is_empty():
		return {}
	var f: Font = e.font
	var fs: int = e.size
	var adv := f.get_char_size(text.unicode_at(i), fs).x
	var pool: Array = _noise(f, fs).get(int(roundf(adv)), [])
	if pool.is_empty():
		return {}
	return {adv = adv, font = f, size = fs, exact = true}


# ------------------------------------------------------------------ the noise

## The noise glyphs by advance, for this face at this size.
func _noise(f: Font, fs: int) -> Dictionary:
	var k := "%d|%d" % [f.get_rid().get_id(), fs]
	if _noise_by.has(k):
		return _noise_by[k]
	var by := {}
	for ch in NOISE:
		var a := int(roundf(f.get_char_size(ch.unicode_at(0), fs).x))
		if not by.has(a):
			by[a] = []
		(by[a] as Array).append(ch)
	_noise_by[k] = by
	return by


## A new noise glyph for `cell`: one of exactly its advance where the face has
## one (always, for hand-drawn text), otherwise the nearest narrower one; none
## for a letter narrower than every noise glyph (a stop, a comma, an
## apostrophe), which is left alone rather than spilled over its neighbours.
func _reglyph(lv: Dictionary, cell: Dictionary) -> void:
	var f: Font = cell.font
	var fs: int = cell.size
	var by := _noise(f, fs)
	var a := int(roundf(float(cell.adv)))
	var pool: Array = by.get(a, [])
	if pool.is_empty() and not cell.get("exact", false):
		var best := -1
		for k: int in by:
			if k <= a and k > best:
				best = k
		pool = by.get(best, []) if best >= 0 else []
	if pool.is_empty():
		cell.g = ""
		return
	var old := String(cell.get("g", ""))
	var g := String(pool[_rng.randi() % pool.size()])
	if g == old and pool.size() > 1:
		g = String(pool[(pool.find(g) + 1) % pool.size()])
	if cell.get("exact", false):
		# the whole string as wide as before (a kerning pair would shift the rest)
		var key: String = lv.get("key", "")
		var e: Dictionary = _drawn.get(key, {})
		if not e.is_empty():
			var s := String(e.text)
			var t := s
			t[int(cell.i)] = g
			if not is_equal_approx(f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x,
					f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x):
				g = s[int(cell.i)]
	cell.g = g


# ------------------------------------------------------------------ running

func _age(now: float) -> void:
	var gone: Array = []
	for key: Variant in _live:
		var lv: Dictionary = _live[key]
		var who = lv.node
		if not is_instance_valid(who) or (lv.kind != Kind.DRAWN and not (who as Node).is_inside_tree()):
			gone.append(key)
			continue
		var cells: Array = lv.cells
		var changed := false
		var removed := false
		for j in range(cells.size() - 1, -1, -1):
			var c: Dictionary = cells[j]
			if now >= float(c.until):
				cells.remove_at(j)
				cells_now -= 1
				changed = true
				removed = true
			elif now >= float(c.flip):
				c.flip = now + FLIP_S
				_reglyph(lv, c)
				changed = true
		if cells.is_empty():
			gone.append(key)
		elif changed:
			_paint(lv, removed)
	for key: Variant in gone:
		_release(key)


## Draw an entry's noise, and (`cells_moved`) tell its mask where the cells are.
func _paint(lv: Dictionary, cells_moved: bool) -> void:
	var who = lv.node
	if not is_instance_valid(who):
		return
	var cells: Array = lv.cells
	match int(lv.kind):
		Kind.SIGNAL:
			var map := {}
			for c: Dictionary in cells:
				map[int(c.i)] = String(c.g)
			(who as SignalText).scramble = map
			(who as SignalText).queue_redraw()
			return
		Kind.DRAWN:
			(who as CanvasItem).queue_redraw()
			return
	var ctl := who as Control
	var rs := RenderingServer
	if not (lv.ci as RID).is_valid():
		var ci := rs.canvas_item_create()
		rs.canvas_item_set_parent(ci, ctl.get_canvas_item())
		rs.canvas_item_set_draw_index(ci, 1 << 20)
		lv.ci = ci
	if lv.mat == null:
		lv.mat = _mats.pop_back() if not _mats.is_empty() else _new_mat()
		rs.canvas_item_set_material(ctl.get_canvas_item(), (lv.mat as ShaderMaterial).get_rid())
	if cells_moved:
		var arr: Array[Vector4] = []
		for k in SLOTS:
			if k < cells.size():
				var r: Rect2 = cells[k].r
				arr.append(Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
			else:
				arr.append(Vector4.ZERO)
		(lv.mat as ShaderMaterial).set_shader_parameter(&"cells", arr)
		(lv.mat as ShaderMaterial).set_shader_parameter(&"n", mini(cells.size(), SLOTS))
	var ci2: RID = lv.ci
	rs.canvas_item_clear(ci2)
	for c: Dictionary in cells:
		var g := String(c.get("g", ""))
		if g == "":
			continue
		var f: Font = c.font
		var fs: int = c.size
		var code := g.unicode_at(0)
		var ga := f.get_char_size(code, fs).x
		var at := Vector2(float(c.base.x) + floorf((float(c.adv) - ga) * 0.5), float(c.base.y))
		if c.has("shadow"):
			f.draw_char(ci2, at + (c.shadow_at as Vector2), code, fs, Color(c.shadow as Color, (c.shadow as Color).a * INK_A))
		if c.has("outline"):
			f.draw_char_outline(ci2, at, code, fs, int(c.outline), Color(c.outline_ink as Color, (c.outline_ink as Color).a * INK_A))
		f.draw_char(ci2, at, code, fs, Color(c.ink as Color, (c.ink as Color).a * INK_A))


func _new_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MASK
	return m


## Put a text back exactly as it draws without any of this.
func _release(key: Variant) -> void:
	if not _live.has(key):
		return
	var lv: Dictionary = _live[key]
	_live.erase(key)
	cells_now -= (lv.cells as Array).size()
	var who = lv.node
	if (lv.ci as RID).is_valid():
		RenderingServer.free_rid(lv.ci)
		lv.ci = RID()
	if lv.mat != null:
		var m: ShaderMaterial = lv.mat
		m.set_shader_parameter(&"n", 0)
		_mats.append(m)
		lv.mat = null
		if is_instance_valid(who):
			var ctl := who as CanvasItem
			RenderingServer.canvas_item_set_material(ctl.get_canvas_item(),
				ctl.material.get_rid() if ctl.material != null else RID())
	if is_instance_valid(who):
		if who is SignalText:
			(who as SignalText).scramble = {}
			(who as SignalText).queue_redraw()
		elif int(lv.kind) == Kind.DRAWN:
			(who as CanvasItem).queue_redraw()


## Everything back as it was, now.
func clear() -> void:
	for key: Variant in _live.keys():
		_release(key)
	_live.clear()
	cells_now = 0
	_drawn.clear()
	_drawn_scan.clear()
	_elig.clear()
	_elig_ix.clear()
	_wsum = 0


## For a harness: the live entries, {key: {node, kind, cells}}.
func live() -> Dictionary:
	return _live


## For a harness: entries still holding a canvas item or a mask (none once off).
func held() -> int:
	var n := 0
	for key: Variant in _live:
		var lv: Dictionary = _live[key]
		if (lv.ci as RID).is_valid() or lv.mat != null:
			n += 1
	return n


## For a harness: how many texts it knows, and how many are showing now.
func known() -> Vector2i:
	return Vector2i(_pool.size(), _elig.size())
