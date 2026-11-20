class_name MiniKit
extends RefCounted

## THE ONE UI KIT round every science mini game (Jon, Nov 20: "Perfect."): the header row, the
## bottom deck (status line + control row), buttons, dial, meter, tell card. A port of the approved
## `tools/dev/minigame/layout/kit.js`, function for function and pixel for pixel, onto a MiniPix.
## Kinds are "neutral" (or ""), "yours", "goal", "good", "bad"; an unknown kind is neutral.
## Why: docs/why/MiniGame.md#the-ui-kit

## The game area: every game draws exactly this.
const W := 150
const H := 130
## Side gutter (text, buttons, GIVE UP all start/end 3 in); the gap between controls.
const GUT := 3
const GAP := 4
## ROW.HEAD: band rows 0-8, rule row 9, text rows 2-6.
const HEAD_Y := 0
const HEAD_H := 10
const HEAD_TY := 2
const HEAD_RULE := 9
## ROW.PLAY: the first play row.
const PLAY_Y := 10
## ROW.DECK_C / DECK_N: the bottom deck's top row with controls / without.
const DECK_C := 98
const DECK_N := 121
## The status text row from the deck's top (100 or 123): 4 clear rows above the haul line (132).
const STATUS_TY := 2
## ROW.CTRL: the control row, rows 107-129, every control centred on row 118.
const CTRL_Y := 107
const CTRL_H := 23
const CTRL_CY := 118
## ROW.TELL: the tell card, rows 45-61, centred on x 75.
const TELL_Y := 45
const TELL_H := 17
const TELL_CX := 75
## ROW.STRIP: the shell's (mockups only).
const STRIP_Y := 130
const STRIP_H := 10
## BTN: heights standard (label, or icon+label in a line) / large (icon over label); widths S/M/L; their y.
const BTN_H := 13
const BTN_HL := 19
const BTN_W: Array[int] = [25, 33, 45]
const BTN_YS := 112
const BTN_YL := 109
## DIAL.R: 19 px across, the large button's height.
const DIAL_R := 9
## METER: 1 px frame, 3x5 segments on a 4 px pitch.
const METER_H := 7
const METER_PITCH := 4
## The one border colour (PAL.panel): header, deck, strip.
const BORDER := MiniPix.PANEL
const OFF := Color("#18212d")
const SHADE := Color("#4a5a70")
## PAL.t2 (the goal blue) and PAL.t3 (the mockup strip's epic name).
const T2 := Color("#6a9ad4")
const T3 := Color("#8b4fd4")
const LABEL := MiniPix.COLD
const VALUE := MiniPix.ICE
const CARD_TX := MiniPix.HOT
## The four accents plus neutral, one meaning each: [fill, hi, text].
const KIND := {
	"neutral": [MiniPix.COLD, MiniPix.CHILL, MiniPix.CHILL],
	"yours": [MiniPix.EMBER, MiniPix.FLARE, MiniPix.FLARE],
	"goal": [T2, MiniPix.ICE, T2],
	"good": [MiniPix.GOOD, MiniPix.MARK, MiniPix.GOOD],
	"bad": [MiniPix.BAD, Color("#e07a62"), MiniPix.BAD],
}
## Button skins: [edge, face, hi, lo, text, dy].
const SKIN := {
	"normal": [MiniPix.BEVEL_LO, MiniPix.LINE, MiniPix.BEVEL_HI, OFF, MiniPix.ICE, 0],
	"pressed": [MiniPix.BEVEL_LO, MiniPix.LINE, OFF, MiniPix.LINE, MiniPix.ICE, 1],
	"active": [MiniPix.BEVEL_LO, MiniPix.EMBER, MiniPix.FLARE, Color("#8a4a16"), MiniPix.VOID, 0],
	"active-pressed": [MiniPix.BEVEL_LO, MiniPix.EMBER, Color("#8a4a16"), MiniPix.EMBER, MiniPix.VOID, 1],
	"disabled": [MiniPix.LINE, BORDER, BORDER, BORDER, MiniPix.BEVEL_HI, 0],
}
## Button icons, 9x9, drawn in the label's colour; scan, dig, left, right are kit_swaps_c's (Seismic, Dock).
const ICONS := {
	"ccw": ["...###...", "..#...#..", ".#.....#.", "#.......#", "#.......#", "#........", "###......", ".##......", "..#......"],
	"cw": ["...###...", "..#...#..", ".#.....#.", "#.......#", "#.......#", "........#", "......###", "......##.", "......#.."],
	"thrust": ["....#....", "...###...", "..##.##..", ".##...##.", "##.....##", "....#....", "...###...", "..#.#.#..", "....#...."],
	"undo": ["...#.....", "..##.....", ".#######.", "..##....#", "...#....#", "........#", "........#", "..######.", "........."],
	"spin": ["..####...", ".#....#..", "#......#.", "#...#..##", "#..###.#.", "#...#....", ".#.......", "..####...", "........."],
	"check": [".........", "........#", ".......##", "......##.", "#....##..", "##..##...", ".####....", "..##.....", "........."],
	"clear": [".........", ".#.....#.", "..#...#..", "...#.#...", "....#....", "...#.#...", "..#...#..", ".#.....#.", "........."],
	"lock": ["...###...", "..#...#..", "..#...#..", ".#######.", ".##...##.", ".###.###.", ".###.###.", ".#######.", "........."],
	"smoke": [".........", "...##....", "..####.#.", ".######..", "########.", ".######..", "..##.##..", ".........", "........."],
	"patch": ["#########", "#.......#", "#.#...#.#", "#.......#", "#.......#", "#.......#", "#.#...#.#", "#.......#", "#########"],
	"grow": ["....#....", "....#....", "..#####..", "....#....", ".#..#..#.", ".#.....#.", "..#...#..", "...###...", "........."],
	"scan": ["..#####..", ".#.....#.", "#..###..#", "#.#...#.#", "#.#.#.#.#", "#.#...#.#", "#..###..#", ".#.....#.", "..#####.."],
	"dig": [".#######.", ".#######.", "...###...", "...###...", "...###...", "....#....", "....#....", "....#....", "........."],
	"left": [".........", "...#.....", "..#......", ".#.......", "#########", ".#.......", "..#......", "...#.....", "........."],
	"right": [".........", ".....#...", "......#..", ".......#.", "#########", ".......#.", "......#..", ".....#...", "........."],
}


static func _k(kind: String) -> Array[Color]:
	var out: Array[Color] = []
	out.assign(KIND.get(kind, KIND.neutral))
	return out


## A kind's colours (`KIND[k].fill / .hi / .text`).
static func fill(kind: String) -> Color:
	return _k(kind)[0]


static func hi(kind: String) -> Color:
	return _k(kind)[1]


static func ink(kind: String) -> Color:
	return _k(kind)[2]


## JS `String(v)`: whole floats without ".0".
static func s(v: Variant) -> String:
	if v is float and is_finite(v) and floorf(v) == v and absf(v) < 1e15:
		return str(int(v))
	return str(v)


## JS `value!=null&&value!==''`.
static func _has(v: Variant) -> bool:
	return v != null and s(v) != ""


## A string's width in the 3x5 font.
static func tw(v: Variant) -> int:
	return s(v).length() * 4 - 1


## A label/value pair: label dim, value bright ("TURNS 3"); `align` "right" ends at x, "center"
## centres on it. Returns the width.
static func pair(px: MiniPix, x: int, y: int, label: Variant, value: Variant, lkind := "", vkind := "", align := "") -> int:
	var has_l := label != null and s(label) != ""
	var has_v := _has(value)
	var w := (tw(label) if has_l else 0) + (4 if has_l and has_v else 0) + (tw(value) if has_v else 0)
	if align == "right":
		x -= w
	elif align == "center":
		x -= w >> 1
	var cx := x
	if has_l:
		px.text(s(label), cx, y, ink(lkind) if lkind != "" else LABEL)
		cx += tw(label) + 4
	if has_v:
		px.text(s(value), cx, y, ink(vkind) if vkind != "" else VALUE)
	return w


## A segmented bar, 7 tall; w rounds down to whole segments. `mark` (0..1) adds a goal tick.
## Returns the width drawn.
static func meter(px: MiniPix, x: int, y: int, w: int, frac: float, kind := "", h := METER_H, off := OFF, mark: Variant = null) -> int:
	var n := maxi(1, floori((w - 1) / float(METER_PITCH)))
	var ww := n * METER_PITCH + 1
	var on := MiniPix.jr(clampf(frac, 0.0, 1.0) * n)
	px.rect(x, y, ww, h, MiniPix.BEVEL_LO)
	for i in n:
		var sx := x + 1 + i * METER_PITCH
		if i < on:
			px.rect(sx, y + 1, 3, h - 2, fill(kind))
			px.rect(sx, y + 1, 3, 1, hi(kind))
		else:
			px.rect(sx, y + 1, 3, h - 2, off)
	if mark != null:
		var mx := x + 1 + MiniPix.jr(clampf(float(mark), 0.0, 1.0) * (n * METER_PITCH - 1))
		px.rect(mx, y - 1, 1, h + 2, hi("goal"))
	return ww


## The header band and rule. `left`: "HEAT", or {label, value, kind, vkind, meter = {w, frac, kind}};
## `right`: "TIME 38" or [[label, value, vkind, lkind], ...]. `pad_r` leaves room for a game's lamp.
## Returns Vector2i(lx, rx): the free span between.
static func header(px: MiniPix, left: Variant, right: Variant, pad_r := 0) -> Vector2i:
	var y := HEAD_TY
	px.rect(0, 0, W, HEAD_RULE, BORDER)
	px.rect(0, HEAD_RULE, W, 1, MiniPix.LINE)
	var x := GUT
	if left != null and not (left is String and left == ""):
		var l: Dictionary = {label = left} if left is String else left
		var m: Dictionary = l.get("meter", {})
		var lk: String = s(l.get("kind", "")) if l.get("kind") != null else ""
		var vk: String = s(l.get("vkind", "")) if l.get("vkind") != null else ""
		x += pair(px, x, y, l.get("label"), null if not m.is_empty() else l.get("value"), lk, vk) + 4
		if not m.is_empty():
			var mk: String = s(m.get("kind", "")) if m.get("kind") != null else ""
			x += meter(px, x, y - 1, int(m.w), float(m.frac), mk) + 4
			if _has(l.get("value")):
				x += pair(px, x, y, null, l.get("value"), "", vk) + 4
	var rx := W - GUT - pad_r
	if right != null and not (right is String and right == ""):
		var items: Array = [[right, null]] if right is String else right
		for i in range(items.size() - 1, -1, -1):
			var it: Array = items[i]
			var vk2: String = s(it[2]) if it.size() > 2 and it[2] != null else ""
			var lk2: String = s(it[3]) if it.size() > 3 and it[3] != null else ""
			rx -= pair(px, rx, y, it[0], it[1] if it.size() > 1 else null, lk2, vk2, "right")
			if i:
				rx -= 8
	return Vector2i(x, rx - 4)


## The bottom deck's top row: with controls 98, without 121.
static func deck_y(controls: bool) -> int:
	return DECK_C if controls else DECK_N


## The deck: border colour from its top rule down to row 129.
static func deck(px: MiniPix, controls: bool) -> void:
	var y := deck_y(controls)
	px.rect(0, y, W, H - y, BORDER)
	px.rect(0, y, W, 1, MiniPix.LINE)


## The one place for status words, centred on the deck's status line. `parts`: "ROUTED" (with
## `kind`) or [["COLD 1/2", "neutral"], ["VALVE DRY", "bad"]].
static func status(px: MiniPix, parts: Variant, kind := "", controls := false) -> void:
	if parts == null or (parts is String and parts == "") or (parts is Array and (parts as Array).is_empty()):
		return
	var list: Array = [[parts, kind]] if parts is String else parts
	var y := deck_y(controls) + STATUS_TY
	var w := 8 * (list.size() - 1)
	for p: Array in list:
		w += tw(p[0])
	var x := (W >> 1) - (w >> 1)
	for p: Array in list:
		px.text(s(p[0]), x, y, ink(s(p[1]) if p.size() > 1 and p[1] != null else ""))
		x += tw(p[0]) + 9


## A 9x9 icon from ICONS in `col`. Returns 9 (0 for an unknown name).
static func glyph(px: MiniPix, name: String, x: int, y: int, col: Color) -> int:
	if not ICONS.has(name):
		return 0
	var m: Array = ICONS[name]
	for r in 9:
		var row: String = m[r]
		for c in 9:
			if row[c] == "#":
				px.rect(x + c, y + r, 1, 1, col)
	return 9


## A button: `state` "normal" | "pressed" | "active" (amber: the one to press now / the chosen
## mode) | "active-pressed" | "disabled"; `h` BTN_H (label, or icon+label in a line) or BTN_HL (icon over label).
static func button(px: MiniPix, x: int, y: int, w: int, h: int, label: String, state := "normal", icon := "") -> void:
	var sk: Array = SKIN.get(state, SKIN.normal)
	var d: int = sk[5]
	var tx: Color = sk[4]
	px.rect(x, y, w, h, sk[0])
	px.rect(x + 1, y + 1, w - 2, h - 2, sk[1])
	px.rect(x + 1, y + 1, w - 2, 1, sk[2])
	px.rect(x + 1, y + 1, 1, h - 2, sk[2])
	px.rect(x + 1, y + h - 2, w - 2, 1, sk[3])
	px.rect(x + w - 2, y + 1, 1, h - 2, sk[3])
	var cx := x + (w >> 1) + d
	if icon != "" and label != "" and h >= BTN_HL:
		glyph(px, icon, cx - 4, y + 2 + d, tx)
		px.text(label, cx, y + h - 7 + d, tx, "center")
	elif icon != "" and label != "":
		var ww := 9 + 3 + tw(label)
		var x0 := cx - (ww >> 1)
		glyph(px, icon, x0, y + ((h - 9) >> 1) + d, tx)
		px.text(label, x0 + 12, y + ((h - 5) >> 1) + d, tx)
	elif icon != "":
		glyph(px, icon, cx - 4, y + ((h - 9) >> 1) + d, tx)
	else:
		px.text(label, cx, y + ((h - 5) >> 1) + d, tx, "center")


## A button's standard width for a label: the smallest of 25 / 33 / 45 it fits, else label + 10.
static func btn_w(label: String, icon := "") -> int:
	var need := (tw(label) if label != "" else 0) + (12 if icon != "" else 0) + 8
	for w in BTN_W:
		if w >= need:
			return w
	return need + 2


## A knurled knob, 19 across; `a` the pointer angle in radians (0 up, clockwise). `state` "normal",
## "active" or "disabled"; `ring` a kind for the dotted collar. With label/value they sit right of
## the knob (rows cy-6 and cy+1). Returns the width taken.
static func dial(px: MiniPix, cx: int, cy: int, a: float, state := "normal", ring := "", label: Variant = null,
		value: Variant = null, vkind := "") -> int:
	var r := DIAL_R
	if ring != "":
		var rc := fill(ring)
		for y in range(-r - 1, r + 2):
			for x in range(-r - 1, r + 2):
				var dd := sqrt(float(x * x + y * y))
				if dd > r + 0.5 and dd <= r + 1.5 and ((x + y) & 1) == 0:
					px.rect(cx + x, cy + y, 1, 1, rc)
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d := sqrt(float(x * x + y * y))
			if d > r + 0.5:
				continue
			px.rect(cx + x, cy + y, 1, 1, _knob(x, y, d, a, state))
	var pc := MiniPix.HOT if state == "active" else (MiniPix.LINE if state == "disabled" else MiniPix.EMBER)
	for t in range(1, r - 2):
		px.rect(MiniPix.jr(cx + sin(a) * t), MiniPix.jr(cy - cos(a) * t), 1, 1, pc)
	px.rect(MiniPix.jr(cx + sin(a) * (r - 4.5) - 0.5), MiniPix.jr(cy - cos(a) * (r - 4.5) - 0.5), 2, 2, pc)
	var w := 2 * r + 1
	if label != null or value != null:
		var tx := cx + r + 4
		if label != null:
			px.text(s(label), tx, cy - 6, LABEL)
		if value != null:
			px.text(s(value), tx, cy + 1, ink(vkind) if vkind != "" else VALUE)
		var lw := tw(label) if label != null and s(label) != "" else 0
		w += 4 + maxi(lw, tw(value) if value != null else 0)
	return w


## One pixel of the knob at (x, y), d from its centre: rim, knurl turning with `a`, shaded face.
static func _knob(x: int, y: int, d: float, a: float, state: String) -> Color:
	var r := DIAL_R
	var lt := (-x - y) / float(r)
	var c: Color
	if d > r - 0.5:
		c = MiniPix.BEVEL_LO
	elif d > r - 2.5:
		var an := atan2(float(y), float(x)) - a
		if floori(an / (2.0 * PI) * 24.0 + 48.0) & 1:
			c = MiniPix.BEVEL_LO
		else:
			c = MiniPix.CHILL if lt > 0.3 else (MiniPix.COLD if lt > -0.3 else SHADE)
	elif d > r - 3.5:
		c = MiniPix.BEVEL_LO
	else:
		c = MiniPix.CHILL if lt > 0.5 else (MiniPix.COLD if lt > 0.0 else (SHADE if lt > -0.5 else MiniPix.BEVEL_HI))
	if state == "disabled":
		if c == MiniPix.CHILL:
			c = MiniPix.COLD
		elif c == MiniPix.COLD:
			c = SHADE
		elif c == SHADE:
			c = MiniPix.BEVEL_HI
	return c


## A 0..1 setting as a pointer angle over the usual 270 degree sweep.
static func dial_angle(v: float) -> float:
	return (-135.0 + 270.0 * clampf(v, 0.0, 1.0)) * PI / 180.0


## A tell icon's width: TK.icon kinds, "key:SPACE" (one cap) or "keys:WAD" (a row of caps).
static func icon_w(k: String) -> int:
	if k.begins_with("key:"):
		return k.substr(4).length() * 4 + 5
	if k.begins_with("keys:"):
		return k.substr(5).length() * 11 - 2
	return int(MiniPix.ICW.get(k, 13))


static func draw_icon(px: MiniPix, k: String, x: int, y: int, t: float) -> void:
	if k.begins_with("key:"):
		px.icon("key", x, y, t, k.substr(4))
	elif k.begins_with("keys:"):
		var ks := k.substr(5)
		for i in ks.length():
			px.icon("key", x + i * 11, y, t, ks[i])
	else:
		px.icon(k, x, y, t)


## The tell card's box for `text` and `icons`.
static func tell_rect(text: String, icons: Array[String] = []) -> Rect2i:
	var iw := 0
	for k in icons:
		iw += icon_w(k) + 3
	var w := iw + tw(text) + 12
	return Rect2i(TELL_CX - (w >> 1), TELL_Y, w, TELL_H)


## The one-line start card: icons, then the words, in one box at the kit's spot. Returns its box.
static func tell(px: MiniPix, text: String, icons: Array[String] = [], t := 0.0) -> Rect2i:
	var b := tell_rect(text, icons)
	px.rect(b.position.x, b.position.y, b.size.x, b.size.y, MiniPix.BEVEL_LO)
	px.rect(b.position.x + 1, b.position.y + 1, b.size.x - 2, b.size.y - 2, BORDER)
	px.rect(b.position.x + 1, b.position.y + 1, b.size.x - 2, 1, MiniPix.BEVEL_HI)
	var x := b.position.x + 6
	for k in icons:
		draw_icon(px, k, x, b.position.y + 2, t)
		x += icon_w(k) + 3
	px.text(text, x, b.position.y + 6, CARD_TX)
	return b


## kit.js's mockup strip (the game never draws it; MiniShell draws the approved one).
static func strip(px: MiniPix, result := false, name := "FLARE GLASS", tag := "[EPIC]", col := T3) -> void:
	var y := STRIP_Y
	px.rect(0, y, W, 10, BORDER)
	var bx := W - GUT - 33
	px.rect(bx, y, 33, 9, MiniPix.BEVEL_LO)
	px.rect(bx + 1, y + 1, 31, 7, BORDER)
	px.rect(bx + 1, y + 1, 31, 1, MiniPix.LINE)
	px.text("LEAVE" if result else "GIVE UP", bx + 16, y + 2, MiniPix.CHILL, "center")
	if result:
		px.text(name, GUT, y + 1, col)
		px.text(tag, GUT + (name.length() + 1) * 4, y + 1, MiniPix.COLD)
