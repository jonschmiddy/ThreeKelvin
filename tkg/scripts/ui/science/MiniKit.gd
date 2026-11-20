class_name MiniKit
extends RefCounted

## THE ONE UI KIT round every science mini game: header, control deck, buttons, dial, meter, tell
## card, toasts and the result card, on the whole 150x140 glass (status A, Nov 20). A port of
## `tools/dev/minigame/layout/kit.js`, pixel for pixel, onto a MiniPix. Kinds: "neutral" (or ""),
## "yours", "goal", "good", "bad"; an unknown kind is neutral.
## Why: docs/why/MiniGame.md#the-ui-kit

## The game area: every game draws exactly this, the whole glass (A: no strip under it).
const W := 150
const H := 140
## Side gutter (text and buttons start/end 3 in); the gap between controls.
const GUT := 3
const GAP := 4
## ROW.HEAD: band rows 0-8, rule row 9, text rows 2-6.
const HEAD_Y := 0
const HEAD_H := 10
const HEAD_TY := 2
const HEAD_RULE := 9
## ROW.PLAY: the first play row.
const PLAY_Y := 10
## ROW.DECK_C / DECK_N: the deck's top row with controls (its rule) / without (none: H).
const DECK_C := 116
const DECK_N := 140
## ROW.CTRL: the control row, rows 117-139, every control centred on row 128.
const CTRL_Y := 117
const CTRL_H := 23
const CTRL_CY := 128
## ROW.TELL: the tell card, rows 45-73, centred on x 75; HIGH (rows 33-61) and TOP (rows 12-40) where
## the middle would hide what a player needs to start.
const TELL_Y := 45
const TELL_H := 29
const TELL_CX := 75
const TELL_HIGH := 33
const TELL_TOP := 12
## BTN: heights standard (label, or icon+label in a line) / large (icon over label); widths S/M/L; their y.
const BTN_H := 13
const BTN_HL := 19
const BTN_W: Array[int] = [25, 33, 45]
const BTN_YS := 122
const BTN_YL := 119
## DIAL.R: 19 px across, the large button's height.
const DIAL_R := 9
## METER: 1 px frame, 3x5 segments on a 4 px pitch.
const METER_H := 7
const METER_PITCH := 4
## The one border colour (PAL.panel): header, deck, cards.
const BORDER := MiniPix.PANEL
const OFF := Color("#18212d")
const SHADE := Color("#4a5a70")
## PAL.t2 (the goal blue).
const T2 := Color("#6a9ad4")
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
	# the tiers' inks (MiniPix.TIERS 0-4), for a toast that names a find's tier (Seismic's dig results)
	"t0": [Color("#98a0a8"), Color("#98a0a8"), Color("#98a0a8")],
	"t1": [Color("#4fbf82"), Color("#4fbf82"), Color("#4fbf82")],
	"t2": [T2, T2, T2],
	"t3": [Color("#8b4fd4"), Color("#8b4fd4"), Color("#8b4fd4")],
	"t4": [Color("#d99b29"), Color("#d99b29"), Color("#d99b29")],
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


## The deck's top row: with controls 116 (its rule), without 140 (no deck).
static func deck_y(controls: bool) -> int:
	return DECK_C if controls else DECK_N


## The deck, for games with controls: border colour from its top rule down to row 139. Without: none.
static func deck(px: MiniPix, controls: bool) -> void:
	if not controls:
		return
	var y := deck_y(true)
	px.rect(0, y, W, H - y, BORDER)
	px.rect(0, y, W, 1, MiniPix.LINE)


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


## The tell card's second line, always (Jon, Nov 20: "CONTROL [GAME INSTRUCTIONS] / [ESC] TO GIVE
## UP"): this key cap at rest, never blinking, then GIVE in the quiet label ink. No game lists it.
const ESC := "key:ESC"
## The cap's resting frame (a key icon lights on t 0-0.5, 1-1.5 ...).
const ESC_T := 0.5
const GIVE := "TO GIVE UP"

## The last tell card drawn, for MiniGameTest: its canvas, words, icons, clock and box.
static var told_px: MiniPix = null
static var told_text := ""
static var told_icons: Array[String] = []
static var told_t := 0.0
static var told_at := Rect2i()


## A tell icon's width: TK.icon kinds, "key:SPACE" (one cap) or "keys:WAD" (a row of caps).
static func icon_w(k: String) -> int:
	if k.begins_with("key:"):
		return k.substr(4).length() * 4 + 5
	if k.begins_with("keys:"):
		return k.substr(5).length() * 11 - 2
	return int(MiniPix.ICW.get(k, 13))


static func draw_icon(px: MiniPix, k: String, x: int, y: int, t: float) -> void:
	if k == ESC:
		t = ESC_T
	if k.begins_with("key:"):
		px.icon("key", x, y, t, k.substr(4))
	elif k.begins_with("keys:"):
		var ks := k.substr(5)
		for i in ks.length():
			px.icon("key", x + i * 11, y, t, ks[i])
	else:
		px.icon(k, x, y, t)


## The tell card's box for `text` and `icons`, its top on row `y`.
static func tell_rect(text: String, icons: Array[String] = [], y := TELL_Y) -> Rect2i:
	var iw := 0
	for k in icons:
		iw += icon_w(k) + 3
	var w := maxi(iw + tw(text), icon_w(ESC) + 3 + tw(GIVE)) + 12
	return Rect2i(TELL_CX - (w >> 1), y, w, TELL_H)


## The start card: line 1 the icons (at y+2), then the words (y+6); line 2 the ESC cap (y+15), then
## TO GIVE UP (y+20), each line centred in the card. Its top on row `y` (TELL_Y, TELL_HIGH, TELL_TOP).
static func tell(px: MiniPix, text: String, icons: Array[String] = [], t := 0.0, y := TELL_Y) -> Rect2i:
	var b := tell_rect(text, icons, y)
	box(px, b.position.x, b.position.y, b.size.x, b.size.y)
	# each line centred in the card (Jon, Nov 20: "can we center the text?")
	var iw := 0
	for k in icons:
		iw += icon_w(k) + 3
	var x := b.position.x + ((b.size.x - iw - tw(text)) >> 1)
	for k in icons:
		draw_icon(px, k, x, b.position.y + 2, t)
		x += icon_w(k) + 3
	px.text(text, x, b.position.y + 6, CARD_TX)
	var x2 := b.position.x + ((b.size.x - icon_w(ESC) - 3 - tw(GIVE)) >> 1)
	draw_icon(px, ESC, x2, b.position.y + 15, 0.0)
	px.text(GIVE, x2 + icon_w(ESC) + 3, b.position.y + 20, LABEL)
	told_px = px
	told_text = text
	told_icons = icons.duplicate()
	told_t = t
	told_at = b
	return b


# ---------------------------------------------------------------- popups (A, Nov 20)

## The tiers' names, as the haul's [TIER] says them; their ink is `MiniPix.TIERS` (the item colours).
const TIERS: Array[String] = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"]
## The result card: centred on x 75 and the tell card's centre row 53 (rows 33-73); its lines'
## padding, its width's bounds (x 3-146 at most), and the wait after the end.
const CARD_CX := 75
const CARD_CY := 53
const CARD_PAD := 8
const CARD_MIN_W := 79
const CARD_MAX_W := 144
const CARD_H := 41
const CARD_DELAY := 0.6
## A toast: rows 12-22 (2 under the header rule), centred on x 75; full for 0.9 s, gone at 1.2 s.
const TOAST_Y := 12
const TOAST_H := 11
const TOAST_CX := 75
const TOAST_HOLD := 0.9
const TOAST_LIFE := 1.2


## The cards' box (tell, result, toast): bevelLo edge, border-colour face, bevelHi top line.
static func box(px: MiniPix, x: int, y: int, w: int, h: int) -> void:
	px.rect(x, y, w, h, MiniPix.BEVEL_LO)
	px.rect(x + 1, y + 1, w - 2, h - 2, BORDER)
	px.rect(x + 1, y + 1, w - 2, 1, MiniPix.BEVEL_HI)


## A tier's ink (0 common to 4 legendary): the name's colour on the card.
static func tier_ink(tier: int) -> Color:
	return MiniPix.TIERS[clampi(tier, 0, 4)]


static func card_tag(tier: int) -> String:
	return "[%s]" % TIERS[clampi(tier, 0, 4)]


## Whether NAME [TIER] fits on the card; a name too long for both drops its [TIER].
static func card_full(status: String, haul: String, tier: int) -> bool:
	return haul == "" or maxi(maxi(tw(status), tw(haul + " " + card_tag(tier))), 33) + 2 * CARD_PAD <= CARD_MAX_W


## The card's box for an END word, the haul's NAME and its tier (`cardRect`).
static func card_rect(status: String, haul: String, tier: int) -> Rect2i:
	var hl := tw(haul + " " + card_tag(tier)) if haul != "" else 0
	var w := maxi(maxi(tw(status), hl), 33) + 2 * CARD_PAD
	if not card_full(status, haul, tier):
		w = maxi(maxi(tw(status), tw(haul)), 33) + 2 * CARD_PAD
	w = clampi(w, CARD_MIN_W, CARD_MAX_W)
	return Rect2i(CARD_CX - (w >> 1), CARD_CY - (CARD_H >> 1), w, CARD_H)


## LEAVE on the card `b`: the kit's button, 33x13, centred, 25 rows down.
static func card_leave(b: Rect2i) -> Rect2i:
	return Rect2i(CARD_CX - 16, b.position.y + 25, 33, BTN_H)


## THE RESULT CARD (A): the END word in its kind's colour, a rule, NAME [TIER] (the name in its
## tier's ink, [TIER] quiet) and an amber LEAVE, over the play area. `t`: seconds since the end;
## nothing before CARD_DELAY (an empty Rect2i). Returns its box.
static func result_card(px: MiniPix, status: String, kind: String, haul: String, tier: int, t: float) -> Rect2i:
	if t < CARD_DELAY:
		return Rect2i()
	var b := card_rect(status, haul, tier)
	var x := b.position.x
	var y := b.position.y
	var cx := x + (b.size.x >> 1)
	box(px, x, y, b.size.x, b.size.y)
	px.text(status, cx - (tw(status) >> 1), y + 5, ink(kind))
	px.rect(x + 6, y + 13, b.size.x - 12, 1, MiniPix.LINE)
	if haul != "":
		var full := card_full(status, haul, tier)
		var line := haul + " " + card_tag(tier) if full else haul
		var hx := cx - (tw(line) >> 1)
		px.text(haul, hx, y + 17, tier_ink(tier))
		if full:
			px.text(card_tag(tier), hx + (haul.length() + 1) * 4, y + 17, MiniPix.COLD)
	var lb := card_leave(b)
	button(px, lb.position.x, lb.position.y, lb.size.x, lb.size.y, "LEAVE", "active")
	return b


## A TOAST (a LIVE word): the same box, 11 tall, its text in its kind's colour; full for 0.9 s,
## then two dimmer steps to 1.2 s (the kit's 2x2 dither: 3 of 4 pixels, then 1 of 4), then gone.
## Draw-only: it never takes a click. `age`: seconds since the event. True while it shows.
static func toast(px: MiniPix, text: String, kind: String, age: float, cx := TOAST_CX, y := TOAST_Y) -> bool:
	if text == "" or age < 0.0 or age >= TOAST_LIFE:
		return false
	var d := 1.0 if age < TOAST_HOLD else (0.66 if age < TOAST_HOLD + (TOAST_LIFE - TOAST_HOLD) / 2.0 else 0.33)
	var w := tw(text) + 10
	var x := cx - (w >> 1)
	var one := MiniPix.new(w, TOAST_H)
	box(one, 0, 0, w, TOAST_H)
	one.text(text, 5, 3, ink(kind))
	for j in TOAST_H:
		for i in w:
			if d >= 1.0 or MiniPix.lit(x + i, y + j, d):
				px.dot(x + i, y + j, one.img.get_pixel(i, j))
	return true
