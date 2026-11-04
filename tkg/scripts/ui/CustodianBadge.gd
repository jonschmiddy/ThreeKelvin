class_name CustodianBadge
extends Control

## THE CUSTODIAN'S BADGE beside the goal line: badge 9b, "The eye opens, loud"
## (eye-1b), approved by Jon on Nov 4 ("Yeah, 9B like this"; the page is
## https://claude.ai/artifact/6sMbQ25hJP3pimr93ro9rj). It says, without a
## number for its hull, that the boss at the core grows stronger the more jumps
## the lead ship has made (`EnemyTemplate.hull_at`: 200 through jump 15, +4% a
## jump, capped at twice from jump 33). Alone that is your jumps; in co-op the
## most any ship in the dive has made (`count`, Jon, Nov 4: "The custodian
## strength and icon should be the same for everyone in the galaxy, even if
## they join late.").
##
##   S0    jumps 0 to 15   a closed eye, breathing, with the jumps left beside it
##   WAKE  jump 16         it opens (once, on arriving)
##   S1    16 to 19        orange, drowsy: glances, glints, a slow blink
##   S2    20 to 24        red and bloodshot, darting about
##   S3    25 to 32        glaring, the veins crawling
##   FULL  33 on           wide and blood red, a steady heartbeat. It stops
##                         getting worse, not moving.
##
## THE SOURCE is the approved page's own code, ported pixel for pixel:
## tools/dev/badge/fin_eye.js (eye-1b) and core.js, copied from
## tk-scratch/custodian-badge/web. `-- sheet=BadgeTest` holds `paint` to that
## code's frames (`tools/dev/badge/dump_golden.py`, `badge_golden.json`).
## Drawn into a 40 x 15 Image on the CPU and shown as one texture at whole
## pixels, 1:1 at the game's 960 x 540: the texture is updated only when the
## frame changes, about 2 to 12 times a second.
##
## THE NUMBER is drawn from a table of Silkscreen's digits at 8 px (`DIGITS`),
## baked from the game's own font file the way the game draws it (FreeType,
## antialiasing off: every Silkscreen glyph sits on a 125-unit grid, 1 px at
## 8 px). The page drew the same glyphs with Chrome's antialiasing; past half
## opacity its pixels are these. In the Image, so the whole badge is one draw
## and the tests can read every pixel headless.
##
## THE STAGE EDGES THAT ARE GROWTH come from the core boss's data
## (`DB.core_boss()`): it wakes the jump after its free ones (`grow_after`,
## 15), and it is at full strength from the first jump `hull_at` reaches the cap
## (33). S2 and S3 are Jon's picks on the page, 4 and 9 jumps after the wake
## (20 and 25). A core boss that never grows has no badge.
##
## MOTION on the game's clock (`GameClock`, never the wall's: films run the
## wall's ticks about 13 times too fast). Idle loops at the stage's own rate
## (`IDLE`); a transition once, on the first screen that shows the goal line
## after the count rises (`GoalLine` starts it, `RunState.custodian_seen`
## remembers it), at 10 steps a second, ending on the stage's idle frame 0.
## Reduced motion: the transition plays and then holds idle frame 0, as the
## page did. THE ARRIVAL RUNS FROM THE COUNT LAST SHOWN (`from`) to the count
## now: alone that is always the jump before, so every frame is the page's; in
## co-op a partner's jump can raise it while you sit still, or by several, and
## the biggest stage edge crossed plays (`change_kind`).
##
## NOT A CONTROL: it ignores the mouse like the rest of the goal line, so the
## chart's and the map's pictures under it still take every press, drag and
## wheel. It reads the pointer itself for its tooltip (`_hover`), the game's
## tooltip plate (`TooltipPanel`) with the page's lines, the heading the boss's
## name from data, and no hull figure. Their hover keeps off it (`covers`), so
## a system or a world under it does not open its own tooltip under the badge's.

## The Image the badge draws into, px: wide enough for S0's box (37) and the
## jump before the wake shown at the wake's first step.
const IMG_W := 40
const IMG_H := 15
## The box it inks in from the wake on, and every box's height (core.js BADGE_W, BADGE_H).
const BOX_W := 24
const BOX_H := 15
## The eye's centre from the badge's left edge, px.
const EYE_X := 11
## The jumps-left number starts this far past the eye's centre + its half width
## (5 blank px, Jon Nov 4: "a bit more to the right").
const NUM_GAP := 6
## S0's shut lid is as wide as the eye that opens at the wake (LOOK[1].hw).
const S0_HW := 9
## The number's widest string, px ("15", "16": 11).
const NUM_W := 11
## S0's box: the eye's left edge to the widest number's right edge (37).
const S0_W := EYE_X + S0_HW + NUM_GAP + NUM_W
## The widest box at any jump.
const MAX_W := S0_W
## S2 and S3 start this many jumps after the wake (20 and 25; Jon's stage picks).
const S2_AFTER := 4
const S3_AFTER := 9
## Transitions: steps a second, and steps by kind (core.js TRANS_RATE, TRANS_STEPS).
const TRANS_RATE := 10.0
const TRANS_STEPS := {&"wake": 12, &"worse": 8, &"full": 10, &"tick": 4, &"none": 0}
## Idle: [fast steps a second, slow steps a second, loop seconds] (core.js IDLE).
const IDLE := {
	&"S0": [9, 3, 3.0], &"WAKE": [10, 5, 2.0], &"S1": [10, 5, 2.0],
	&"S2": [12, 6, 1.5], &"S3": [12, 12, 1.0], &"FULL": [12, 12, 1.0]}
## The tooltip: px from the badge's right edge, and its layer (over A.S.H.'s 50,
## as a tooltip floats over everything).
const TIP_GAP := 6.0
const TIP_Z := 60
## THE PAGE'S SPOT for it, px from the screens' area's left (the page's 170 and
## 218 on its 8 px corner): no further left than this on the map and the chart,
## and on LOCAL and in a fight, where it keeps clear of the ship in the sky to
## the goal's right as the page did.
const TIP_AT_NAV := 162.0
const TIP_AT_SECTOR := 210.0

## THE PALETTE (core.js COL and IC), 0xRRGGBB. The ones the HUD has come from UITheme.
const C_ICE := 0xc3d2e2
const C_SILVER := 0xc3d2e2
const C_CHILL := 0x8fa3ba
const C_COLD := 0x6b7d94
const C_FLARE := 0xff9d3d
const C_HOT := 0xffd28a
const C_BAD := 0xc8503c
const C_DARKRED := 0x5a1a1a
const C_WHITE := 0xffffff
const C_UL := 0x4a6582
const C_UR := 0x3a516b
const C_LL := 0x304255
const C_LR := 0x2b3b4f
const C_GIRDLE := 0x33465c

## SILKSCREEN'S DIGITS AT 8 PX: [advance, five rows from the cap top], baked
## from assets/fonts/Silkscreen-Regular.ttf (FreeType mono, as the game draws
## it with antialiasing off). Columns from the pen.
const DIGITS := {
	"0": [6, "..##..|.#..#.|.#..#.|.#..#.|..##.."],
	"1": [5, ".##..|..#..|..#..|..#..|.###."],
	"2": [6, ".###..|....#.|..##..|.#....|.####."],
	"3": [6, ".###..|....#.|..##..|....#.|.###.."],
	"4": [6, ".#.#..|.#.#..|.####.|...#..|...#.."],
	"5": [6, ".####.|.#....|.###..|....#.|.###.."],
	"6": [6, "..##..|.#....|.###..|.#..#.|..##.."],
	"7": [6, ".####.|....#.|...#..|..#...|..#..."],
	"8": [6, "..##..|.#..#.|..##..|.#..#.|..##.."],
	"9": [6, "..##..|.#..#.|..###.|....#.|..##.."],
}

## the frame on screen now, and its texture
var _buf := PackedByteArray()
var _img: Image = null
var _tex: ImageTexture = null
var _key := ""
## the arrival on show: the count it is for, the count it runs from, and when
## it started (GameClock s)
var _arrive_j := -1
var _arrive_from := -1
var _arrive_t0 := -1.0
## the box the frame on show inks in (`paint`'s answer), for the hover
var _drawn := Rect2i()
## when the pointer came over it (GameClock s; -1 not over it)
var _hover_t0 := -1.0
## THE POINTER as its viewport last saw it (canvas px), and whether it is in the
## window: read off the input itself (`_input`), since the badge takes none.
## Headless and under a harness that pushes its events, the engine's own mouse
## position never moves; the events do.
var _pointer := Vector2(-1.0e6, -1.0e6)
var _pointer_in := false
## THE TOOLTIP, made once; its lines set only when they change
var tip: PanelContainer = null
var _tip_box: VBoxContainer = null
var _tip_lines: PackedStringArray = []
## A FIXED CLOCK for the frame dumper and the tests: {t, since} in place of the
## game's; empty in play.
var fixed: Dictionary = {}
## the frame drawn last, for the tests: its jump, {t, since}, transition step
## (-1 idle) and idle steps
var shown: Dictionary = {}
## how many times it has repainted (the tests count it against the frames)
var paints := 0


func _init() -> void:
	name = "CustodianBadge"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(IMG_W, IMG_H)
	visible = false
	_buf.resize(IMG_W * IMG_H * 4)


func _ready() -> void:
	_build_tip()


## Every pointer move and press its viewport gets, before the controls take
## them; nothing is consumed.
func _input(event: InputEvent) -> void:
	var m := event as InputEventMouse
	if m != null:
		_pointer = get_canvas_transform().affine_inverse() * m.position
		_pointer_in = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_pointer_in = false


## THE TOOLTIP: the theme's own plate (`TooltipPanel`, the one Godot puts round
## every HUD readout's popup; `CutawayView._build_panel` places one the same
## way), and inside it the HUD readouts' column (`Widgets.set_readout`): the
## heading, a rule, the lines. Placed by the badge, not at the pointer, so it
## stands clear of the goal and of what is on the screen (`_tip_spot`).
func _build_tip() -> void:
	if tip != null:
		return
	tip = PanelContainer.new()
	tip.name = "Tip"
	tip.add_theme_stylebox_override("panel", get_theme_stylebox(&"panel", &"TooltipPanel"))
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.focus_mode = Control.FOCUS_NONE
	tip.top_level = true
	tip.z_index = TIP_Z
	tip.visible = false
	add_child(tip)
	_tip_box = VBoxContainer.new()
	_tip_box.add_theme_constant_override("separation", 1)
	_tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_child(_tip_box)


# ------------------------------------------------------------------ the ladder

## The boss at the core, from data.
static func boss() -> EnemyTemplate:
	return DB.core_boss()


static var _lad_key := ""
static var _lad: Dictionary = {}


## THE STAGE EDGES: {grows, free, wake, s2, s3, full}. `free` is the boss's free
## jumps (15), `wake` the jump after (16), `full` the first jump its hull is at
## the cap (33), all from its data; S2 and S3 are 4 and 9 after the wake.
static func ladder() -> Dictionary:
	var e := boss()
	if e == null:
		return {grows = false, free = 0, wake = 1, s2 = 1, s3 = 1, full = 1}
	var key := "%s|%d|%d|%s|%s" % [e.id, e.max_hull, e.grow_after, e.grow_rate, e.grow_cap]
	if key == _lad_key:
		return _lad
	var free := e.grow_after
	var top := roundi(e.max_hull * e.grow_cap)
	var full := -1
	if free >= 0 and top > e.max_hull:
		for j in range(free + 1, free + 2001):
			if e.hull_at(j) >= top:
				full = j
				break
	var grows := free >= 0 and full > free
	var wake := free + 1
	var s2 := mini(wake + S2_AFTER, full) if grows else wake
	var s3 := mini(wake + S3_AFTER, full) if grows else wake
	_lad = {grows = grows, free = free, wake = wake, s2 = s2, s3 = s3, full = full}
	_lad_key = key
	return _lad


## A core boss that grows has a badge.
static func enabled() -> bool:
	return bool(ladder().grows)


## THE COUNT IT SHOWS: the jumps the Custodian grows on, your own alone and the
## lead ship's in co-op (`RunState.custodian_jumps`).
static func count() -> int:
	return Run.custodian_jumps()


## THE PARTY'S WORDS in the tooltip: in a party, or flying on from one (its host
## gone, or a co-op save CONTINUEd) while the lead ship's count is above yours.
static func party() -> bool:
	return Net.is_networked() or Run.party_jumps > Run.jumps


## The count an arrival at `j` runs from: `from`, or the jump before when it is
## not given (-1), as it always is alone.
static func _from(j: int, from: int) -> int:
	return j - 1 if from < 0 else from


## Whether going from `from` to `j` crosses `edge`: (from, j] holds it.
static func _crossed(from: int, j: int, edge: int) -> bool:
	return from < edge and edge <= j


## "S0", "WAKE", "S1", "S2", "S3" or "FULL" at jump `j`.
static func stage(j: int) -> StringName:
	var l := ladder()
	if j <= int(l.free):
		return &"S0"
	if j == int(l.wake):
		return &"WAKE"
	if j < int(l.s2):
		return &"S1"
	if j < int(l.s3):
		return &"S2"
	if j < int(l.full):
		return &"S3"
	return &"FULL"


## 0 asleep, 1 woken (the wake too), 2, 3, 4 at full strength.
static func tier(j: int) -> int:
	var l := ladder()
	if j <= int(l.free):
		return 0
	if j < int(l.s2):
		return 1
	if j < int(l.s3):
		return 2
	if j < int(l.full):
		return 3
	return 4


## Jumps left before it starts to grow, while it sleeps (16 at jump 0, 1 at
## jump 15); 0 after.
static func countdown(j: int) -> int:
	var l := ladder()
	return int(l.free) + 1 - j if j <= int(l.free) else 0


## What arriving at count `j` from `from` (the jump before when -1) plays: the
## biggest stage edge crossed, &"full" (33), then &"worse" (20, 25), then
## &"wake" (16), then &"tick" (the number drops, jumps 1 to 15), else &"none".
## One jump crosses one edge, so alone it is the page's table; the page ran
## from jump 1 and ticked from 2, and the game starts at jump 0, so its first
## jump ticks too. In co-op 14 to 17 wakes it and 30 to 40 is the full one.
static func change_kind(j: int, from: int = -1) -> StringName:
	var l := ladder()
	var f := _from(j, from)
	if f >= j:
		return &"none"
	if _crossed(f, j, int(l.full)):
		return &"full"
	if _crossed(f, j, int(l.s2)) or _crossed(f, j, int(l.s3)):
		return &"worse"
	if _crossed(f, j, int(l.wake)):
		return &"wake"
	if maxi(f + 1, 1) <= mini(j, int(l.free)):
		return &"tick"
	return &"none"


## How long the transition at `j` from `from` lasts, s.
static func trans_len(j: int, from: int = -1) -> float:
	return float(TRANS_STEPS[change_kind(j, from)]) / TRANS_RATE


## The transition's step at `since` s after arriving at `j` from `from`, or -1
## (not arriving, `since` < 0, or done). core.js arrival().
static func arrival(since: float, j: int, from: int = -1) -> int:
	if since < 0.0:
		return -1
	var n: int = TRANS_STEPS[change_kind(j, from)]
	var k := floori(since * TRANS_RATE + 1e-9)
	return k if k < n else -1


## The idle steps at `j`: {k fast, q slow, rate, slow, c idle seconds}, counted
## from the transition's end when arriving, from `t` otherwise. core.js idleOf().
static func idle_of(j: int, t: float, since: float, from: int = -1) -> Dictionary:
	var r: Array = IDLE[stage(j)]
	var c := maxf(0.0, since - trans_len(j, from)) if since >= 0.0 else t
	return {k = floori(c * float(r[0]) + 1e-9), q = floori(c * float(r[1]) + 1e-9), rate = int(r[0]), slow = int(r[1]), c = c}


## The box it may ink at `j`, as wide as S0's box while it sleeps, local to its
## left edge and cy - 7.
static func box_w(j: int) -> int:
	return S0_W if tier(j) == 0 else BOX_W


# ------------------------------------------------------------------ the draw

## THE BADGE AT COUNT `j`, `t` game seconds, `since` seconds after arriving
## from `from` (-1 not arriving; `from` -1 the jump before), into `b` (IMG_W x
## IMG_H RGBA8, cleared by the caller) with its left edge at `x` and its middle
## row at `cy`. Returns the box it inks in. core.js + fin_eye.js eye-1b's
## draw(), line for line.
static func paint(b: PackedByteArray, x: int, cy: int, j: int, t: float, since: float, from: int = -1) -> Rect2i:
	var st := arrival(since, j, from)
	if st >= 0:
		return _arrive(b, x, cy, j, st, from)
	var i := idle_of(j, t, since, from)
	return _idle(b, x, cy, j, int(i.k), int(i.q))


## One frame as an Image, for the tests and the frame dumper.
static func frame(j: int, t: float, since: float, x: int = 0, cy: int = 7, from: int = -1) -> Image:
	var b := PackedByteArray()
	b.resize(IMG_W * IMG_H * 4)
	paint(b, x, cy, j, t, since, from)
	return Image.create_from_data(IMG_W, IMG_H, false, Image.FORMAT_RGBA8, b)


static func _box(x: int, cy: int, w: int = BOX_W) -> Rect2i:
	return Rect2i(x, cy - 7, w, BOX_H)


## core.js px(): a solid rect, clipped to the Image.
static func _px(b: PackedByteArray, x: int, y: int, w: int, h: int, c: int) -> void:
	for yy in range(maxi(0, y), mini(IMG_H, y + h)):
		for xx in range(maxi(0, x), mini(IMG_W, x + w)):
			var o := (yy * IMG_W + xx) * 4
			b[o] = (c >> 16) & 0xff
			b[o + 1] = (c >> 8) & 0xff
			b[o + 2] = c & 0xff
			b[o + 3] = 0xff


## core.js mix(): two colours blended by `k`, each channel rounded as JS rounds
## (half up; the values are never negative, so half away from zero is the same).
static func _mix(a: int, c: int, k: float) -> int:
	var out := 0
	for s: int in [16, 8, 0]:
		var v := (a >> s) & 0xff
		var w := (c >> s) & 0xff
		out |= clampi(roundi(float(v) + float(w - v) * k), 0, 255) << s
	return out


## fin_eye.js hsh(): a 32-bit hash, Math.imul and >>> as unsigned 32-bit.
static func _hsh(a: int, c: int) -> int:
	var h := (((a + 1) * 73856093) & 0xFFFFFFFF) ^ (((c + 7) * 19349663) & 0xFFFFFFFF)
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return (h ^ (h >> 16)) & 0xFFFFFFFF


static func _half(dy: int, hw: int, hh: int) -> int:
	if absi(dy) > hh:
		return -1
	if hh <= 0:
		return hw if dy == 0 else -1
	return roundi(float(hw) * (1.0 - float(absi(dy)) / float(hh)))


static func _ins(dx: int, dy: int, hw: int, hh: int) -> bool:
	var h := _half(dy, hw, hh)
	return h >= 0 and absi(dx) <= h


## THE EYE (fin_eye.js eye()): a diamond `hw` by `hh` round (`cx`, `cy`), its
## edge the rim, inside the iris and the pupil round (`ox`, 0), the white of the
## eye shaded as the sprite's glass is, bloodshot and veined by `o`.
## o = {rim, ir, iris, pr, pupil, ring?, blood?, ox?, vein? {seed, col, n}, glint? {at, col}}
static func _eye(b: PackedByteArray, cx: int, cy: int, hw: int, hh: int, o: Dictionary) -> void:
	var ox: int = o.get("ox", 0)
	var rim: int = o.rim
	var ring: int = o.get("ring", -1)
	var blood: float = o.get("blood", 0.0)
	var pr: int = o.pr
	var ir: int = o.ir
	var vein: Dictionary = o.get("vein", {})
	var glint: Dictionary = o.get("glint", {})
	for dy in range(-hh, hh + 1):
		for dx in range(-hw, hw + 1):
			if not _ins(dx, dy, hw, hh):
				continue
			var inner := _ins(dx - 1, dy, hw, hh) and _ins(dx + 1, dy, hw, hh) and _ins(dx, dy - 1, hw, hh) and _ins(dx, dy + 1, hw, hh)
			var c: int
			if not inner:
				c = rim
				if not glint.is_empty():
					var ang := atan2(float(dy) / float(maxi(1, hh)), float(dx) / float(hw)) / TAU
					if floori(fmod(ang + 1.25, 1.0) * 12.0) == int(glint.at):
						c = int(glint.col)
			else:
				var d := absi(dx - ox) + absi(dy)
				if d <= pr:
					c = o.pupil
				elif d <= ir:
					c = ring if d == ir and ring >= 0 else int(o.iris)
				else:
					if dy < 0:
						c = C_UL if dx <= 0 else C_UR
					elif dy == 0:
						c = C_GIRDLE
					else:
						c = C_LL if dx <= 0 else C_LR
					if blood > 0.0:
						c = _mix(c, C_DARKRED, blood)
					if not vein.is_empty() and _hsh(dx + 40, dy + 40 + 97 * int(vein.seed)) % int(vein.n) == 0:
						c = int(vein.col)
			_px(b, cx + dx, cy + dy, 1, 1, c)


## THE SHUT EYE AND ITS NUMBER (fin_eye.js closed()): a shallow U as wide as the
## eye that opens, the seam along the bottom, lashes under it, the jumps left
## 5 px after it. o = {seam?, twitch?, leak?, corners?, digit?, digit_col?}
static func _closed(b: PackedByteArray, x: int, cy: int, o: Dictionary) -> void:
	var cor: int = o.get("corners", C_CHILL)
	var hw := S0_HW
	var cx := x + EYE_X
	var sh := hw - 4
	var l1 := hw - 3
	var l2 := roundi(float(l1) / 2.0)
	_px(b, cx - hw, cy - 2, 1, 1, cor)
	_px(b, cx + hw, cy - 2, 1, 1, cor)
	_px(b, cx - hw + 1, cy - 1, 3, 1, C_SILVER)
	_px(b, cx + hw - 3, cy - 1, 3, 1, C_SILVER)
	_px(b, cx - sh, cy, 2 * sh + 1, 1, int(o.get("seam", C_SILVER)))
	if bool(o.get("twitch", false)):
		_px(b, cx, cy + 1, 1, 1, C_COLD)
	else:
		for d: int in [-l1, -l2, l2, l1]:
			_px(b, cx + d, cy + 1, 1, 1, C_COLD)
		_px(b, cx, cy + 1, 1, 2, C_COLD)
	var leak: int = o.get("leak", -1)
	if leak >= 0:
		_px(b, cx - 2, cy, 5, 1, leak)
	var n: int = o.get("digit", 0)
	if n > 0:
		var col: int = o.get("digit_col", C_HOT if n <= 3 else C_CHILL)
		_digits(b, str(n), cx + hw + NUM_GAP, cy - 2, col)


## core.js text() for a number: Silkscreen 8 px, `top` the cap top, `x` the pen.
static func _digits(b: PackedByteArray, s: String, x: int, top: int, col: int) -> void:
	var pen := x
	for ch in s:
		var g: Array = DIGITS[ch]
		var rows := String(g[1]).split("|")
		for r in rows.size():
			var row: String = rows[r]
			for c in row.length():
				if row[c] == "#":
					_px(b, pen + c, top + r, 1, 1, col)
		pen += int(g[0])


## THE LOOKS AT REST, by tier (fin_eye.js LOOK.b: "a stage louder: orange at
## 16, red and bloodshot by 20").
static var _look: Array = []


static func look(t: int) -> Dictionary:
	if _look.is_empty():
		_look = [{},
			{hw = 9, hh = 3, rim = C_FLARE, ir = 1, iris = C_FLARE, pr = 0, pupil = C_HOT,
				iris_steps = [C_FLARE, _mix(C_FLARE, C_HOT, 0.5), C_HOT]},
			{hw = 11, hh = 5, rim = C_BAD, ir = 2, iris = C_BAD, ring = C_FLARE, pr = 1, pupil = C_WHITE, pupil2 = C_HOT, blood = 0.45, vein = C_BAD},
			{hw = 11, hh = 6, rim = C_BAD, ir = 3, iris = C_BAD, iris2 = C_FLARE, ring = C_DARKRED, pr = 1, pupil = C_WHITE, blood = 0.75, vein = C_BAD},
			{hw = 11, hh = 7, rim = C_BAD, ir = 4, iris = C_BAD, ring = C_FLARE, pr = 2, pupil = C_WHITE, blood = 1.0, vein = C_BAD, beat = C_HOT, glint = C_HOT}]
	return _look[t]


## a blink: phase 1 half shut, 2 shut, 3 half shut
static func _blink_hh(hh: int, ph: int) -> int:
	return 0 if ph == 2 else ceili(float(hh) / 2.0)


## THE STAGE'S LIVING LOOP (fin_eye.js idle()); k, q the fast and slow steps,
## k = q = 0 the rest pose.
static func _idle(b: PackedByteArray, x: int, cy: int, j: int, k: int, q: int) -> Rect2i:
	var tr := tier(j)
	var cx := x + EYE_X
	var free := int(ladder().free)
	if tr == 0:
		# S0, 9 a second, a 3 s loop: it sleeps. The seam dims on the out-breath,
		# the lashes twitch once a loop; on the last free jump light leaks
		# through the seam, flickering on the breath
		var qq := q % 9
		var kk := k % 27
		var seam: int = [C_SILVER, C_SILVER, C_SILVER, C_CHILL, C_COLD, C_CHILL, C_SILVER, C_SILVER, C_SILVER][qq]
		var twitch := kk == 22 or (j == free and kk == 10)
		var o := {seam = seam, twitch = twitch, digit = countdown(j)}
		if j == free:
			o.leak = C_FLARE if qq % 3 == 2 else C_HOT
		_closed(b, x, cy, o)
		return _box(x, cy, S0_W)
	var p := look(tr)
	if tr == 1:
		# S1, 10 a second, a 2 s loop: drowsy. The iris glows up and down, a
		# glance back at the goal, a glint once a second, a slow blink
		var qq := q % 10
		var kk := k % 20
		var iris: int = (p.iris_steps as Array)[[0, 1, 2, 2, 1, 0, 0, 1, 1, 0][qq]]
		var ox := -2 if qq == 5 or qq == 6 else (-1 if qq == 7 else 0)
		var hh: int = _blink_hh(p.hh, kk - 15) if kk >= 16 and kk <= 18 else int(p.hh)
		_eye(b, cx, cy, p.hw, hh, {rim = p.rim, ir = p.ir, iris = iris, pr = p.pr,
			pupil = C_WHITE if kk % 10 == 1 else int(p.pupil), ox = ox})
	elif tr == 2:
		# S2, 12 a second, a 1.5 s loop: awake and searching. Saccades, the
		# pupil glinting off their beat, one quick blink
		var qq := q % 9
		var kk := k % 18
		var ox: int = [0, 0, -3, -3, 0, 2, 2, 0, 0][qq]
		var hh: int = _blink_hh(p.hh, kk - 13) if kk >= 14 and kk <= 16 else int(p.hh)
		var o := {rim = p.rim, ir = p.ir, iris = p.iris, ring = p.ring, pr = p.pr,
			pupil = p.pupil if k % 6 == 1 or k % 6 == 2 else p.pupil2, blood = p.blood, ox = ox}
		if p.has("vein"):
			o.vein = {seed = 0, col = p.vein, n = 7}
		_eye(b, cx, cy, p.hw, hh, o)
	elif tr == 3:
		# S3, 12 a second, a 1 s loop: bloodshot and glaring. The iris flickers,
		# the veins crawl, the lids tremble once a loop
		var kk := k % 12
		var flick: int = [0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1][kk]
		_eye(b, cx, cy, p.hw, int(p.hh) - 1 if kk == 7 else int(p.hh), {rim = p.rim, ir = p.ir,
			iris = p.iris2 if flick == 1 else p.iris, ring = p.ring, pr = p.pr, pupil = p.pupil, blood = p.blood,
			vein = {seed = floori(float(kk + 1) / 3.0) % 4, col = p.vein, n = 5}})
	else:
		# FULL, 12 a second, a 1 s loop, the same every second: a hot glint runs
		# round the lid, and a heartbeat, lub-dub on frames 1 and 3
		var kk := k % 12
		var lub := kk == 1
		var dub := kk == 3
		_eye(b, cx, cy, p.hw, p.hh, {rim = p.rim, ir = p.ir, iris = p.iris, ring = p.beat if lub else p.ring,
			pr = int(p.pr) + 1 if lub or dub else int(p.pr), pupil = p.pupil, blood = p.blood,
			vein = {seed = 0, col = p.beat if lub else p.vein, n = 4}, glint = {at = kk, col = p.glint}})
	return _box(x, cy)


static func _rest(b: PackedByteArray, x: int, cy: int, j: int) -> Rect2i:
	return _idle(b, x, cy, j, 0, 0)


static func _e(b: PackedByteArray, x: int, cy: int, hw: int, hh: int, o: Dictionary) -> Rect2i:
	_eye(b, x + EYE_X, cy, hw, hh, o)
	return _box(x, cy)


## THE TRANSITIONS, 10 steps a second (fin_eye.js arrive()). Step 0 is the
## count it runs from at rest (`from`, the jump before alone); the last is the
## new stage at rest (its idle frame 0).
static func _arrive(b: PackedByteArray, x: int, cy: int, j: int, st: int, from: int = -1) -> Rect2i:
	var kind := change_kind(j, from)
	var n: int = TRANS_STEPS[kind]
	var l := ladder()
	var last_free := j == int(l.free)
	if st == 0:
		return _rest(b, x, cy, _from(j, from))
	if st == n - 1:
		return _rest(b, x, cy, j)
	if kind == &"tick":
		# the old number; the lashes twitch and the number goes out; the new
		# number lights white, then settles to its colour
		if st == 1:
			var o1 := {twitch = true}
			if last_free:
				o1.leak = C_FLARE
			_closed(b, x, cy, o1)
		else:
			var o2 := {digit = countdown(j), digit_col = C_WHITE}
			if last_free:
				o2.leak = C_WHITE
			_closed(b, x, cy, o2)
		return _box(x, cy, S0_W)
	if kind == &"wake":
		# the number goes out and white light pours from the seam; the lids
		# crack, a hot slit; it snaps wide open, white; it narrows in two steps,
		# hot; the lid cools to its colour; rest
		var f := look(1)
		if st == 1:
			_closed(b, x, cy, {seam = C_WHITE, corners = C_HOT, leak = C_WHITE})
			return _box(x, cy)
		if st == 2:
			return _e(b, x, cy, 11, 1, {rim = C_HOT, ir = 3, iris = C_WHITE, pr = 1, pupil = C_WHITE})
		if st <= 4:
			return _e(b, x, cy, 11, 7, {rim = C_WHITE, ir = 5, iris = C_HOT, pr = 2, pupil = C_WHITE})
		if st <= 6:
			return _e(b, x, cy, 10, 4, {rim = C_HOT, ir = 2, iris = C_WHITE, pr = 1, pupil = C_WHITE})
		if st <= 8:
			return _e(b, x, cy, f.hw, f.hh, {rim = C_HOT, ir = f.ir, iris = C_FLARE, pr = 0, pupil = C_WHITE})
		return _e(b, x, cy, f.hw, f.hh, {rim = f.rim, ir = f.ir, iris = C_HOT, pr = 0, pupil = C_WHITE})
	if kind == &"worse" and not _crossed(_from(j, from), j, int(l.s3)):
		# a blink, then it opens wider than before, hot; settles to the new
		# size, the pupil white; rest
		var a0 := look(1)
		var b0 := look(2)
		if st <= 2:
			return _e(b, x, cy, a0.hw, _blink_hh(a0.hh, st), {rim = a0.rim, ir = a0.ir, iris = a0.iris, pr = a0.pr, pupil = a0.pupil})
		var o := {ir = b0.ir, iris = b0.iris, ring = b0.ring, pr = 1, pupil = C_WHITE, blood = b0.blood}
		if st <= 4:
			o.rim = C_WHITE if st == 3 else C_HOT
			return _e(b, x, cy, mini(11, int(b0.hw) + 1), int(b0.hh) + 1, o)
		o.rim = C_HOT if st == 5 else int(b0.rim)
		o.pr = b0.pr
		return _e(b, x, cy, b0.hw, b0.hh, o)
	if kind == &"worse":
		# harder: it narrows to a red glare, snaps open past full, white; blood
		# floods the white of the eye; it settles to the new size; rest
		var a0 := look(2)
		var b0 := look(3)
		if st <= 2:
			return _e(b, x, cy, a0.hw, 2 if st == 1 else 1, {rim = C_BAD, ir = a0.ir, iris = a0.iris if st == 1 else C_BAD,
				pr = a0.pr, pupil = C_HOT, blood = a0.blood})
		if st == 3:
			return _e(b, x, cy, 11, 7, {rim = C_WHITE, ir = 4, iris = C_HOT, pr = 2, pupil = C_WHITE})
		var flood := minf(1.0, float(b0.blood) + 0.3)
		if st <= 5:
			return _e(b, x, cy, 11, 7, {rim = C_HOT if st == 4 else C_BAD, ir = b0.ir, iris = C_BAD, ring = b0.ring, pr = 1,
				pupil = C_WHITE, blood = flood, vein = {seed = st, col = C_BAD, n = 4}})
		return _e(b, x, cy, b0.hw, b0.hh, {rim = C_FLARE, ir = b0.ir, iris = b0.iris2, ring = b0.ring, pr = b0.pr,
			pupil = b0.pupil, blood = flood, vein = {seed = 0, col = b0.vein, n = 5}})
	# FULL, the hardest: it shuts hard to a red line, goes dark, snaps open full
	# and all white, the pupil blown wide, red floods in, the pupil draws in with
	# a beat; rest
	var f4 := look(4)
	if st == 1:
		return _e(b, x, cy, 11, 0, {rim = C_BAD, ir = 0, iris = C_BAD, pr = 0, pupil = C_BAD})
	if st == 2:
		return _e(b, x, cy, 11, 0, {rim = C_DARKRED, ir = 0, iris = C_DARKRED, pr = 0, pupil = C_DARKRED})
	if st == 3:
		return _e(b, x, cy, 11, 7, {rim = C_WHITE, ir = 9, iris = C_WHITE, ring = C_HOT, pr = 9, pupil = C_WHITE})
	if st == 4:
		return _e(b, x, cy, 11, 7, {rim = C_WHITE, ir = 5, iris = C_HOT, ring = C_FLARE, pr = 3, pupil = C_WHITE})
	if st <= 6:
		return _e(b, x, cy, 11, 7, {rim = C_HOT if st == 5 else int(f4.rim), ir = f4.ir, iris = f4.iris, ring = C_HOT, pr = 2,
			pupil = C_WHITE, blood = f4.blood, vein = {seed = 0, col = f4.vein, n = 4}})
	return _e(b, x, cy, 11, 7, {rim = f4.rim, ir = f4.ir, iris = f4.iris, ring = f4.beat if st == 7 else f4.ring,
		pr = int(f4.pr) + 1 if st == 7 else int(f4.pr), pupil = f4.pupil, blood = f4.blood,
		vein = {seed = 0, col = f4.beat if st == 7 else f4.vein, n = 4}})


# ------------------------------------------------------------------ the tooltip's words

## THE TOOLTIP'S LINES at count `j` (core.js tooltip()), line for line: the
## boss's name from data, then what it does and when it grows. No hull figure.
## `in_party`: the co-op words (Jon, Nov 4), where it grows on the lead ship's
## jumps rather than yours (`party()`); the solo lines are the page's, unchanged.
static func tooltip(j: int, in_party: bool = false) -> PackedStringArray:
	var l := ladder()
	var e := boss()
	var out := PackedStringArray([e.name.to_upper() if e != null else "", "It guards the core."])
	if in_party and j < int(l.full):
		if j <= int(l.free):
			out.append_array(PackedStringArray(["It starts to grow stronger",
				"when the lead ship makes jump %d." % int(l.wake),
				"The lead ship has made %d %s." % [j, "jump" if j == 1 else "jumps"]]))
		else:
			var pl := ["", "It woke after jump %d." % int(l.free), "It is already stronger.", "It is much stronger now."]
			out.append_array(PackedStringArray(["It grows stronger each time", "the lead ship jumps.", pl[tier(j)],
				"It can grow to %s its strength." % _times(e.grow_cap)]))
		return out
	if j < int(l.free):
		out.append_array(PackedStringArray(["It starts to grow stronger", "in %d jumps." % countdown(j)]))
	elif j == int(l.free):
		out.append_array(PackedStringArray(["It starts to grow stronger", "after your next jump."]))
	elif j < int(l.full):
		var tl := ["", "It woke after jump %d." % int(l.free), "It is already stronger.", "It is much stronger now."]
		out.append_array(PackedStringArray(["It grows stronger with every", "jump you take.", tl[tier(j)],
			"It can grow to %s its strength." % _times(e.grow_cap)]))
	else:
		out.append_array(PackedStringArray(["It is at full strength.", "It will not grow any more."]))
	return out


## "twice" for a cap of 2 (the Custodian's), else "3 times" and so on.
static func _times(cap: float) -> String:
	if is_equal_approx(cap, 2.0):
		return "twice"
	if is_equal_approx(cap, 3.0):
		return "three times"
	return "%s times" % String.num(cap, 1)


# ------------------------------------------------------------------ on screen

## The arrival at count `j` from `from` (the count last shown; -1 the jump
## before) starts now (`GoalLine`, on the first frame the line is up after the
## count rose).
func arrive(j: int, from: int = -1) -> void:
	_arrive_j = j
	_arrive_from = _from(j, from)
	_arrive_t0 = GameClock.now()


## The arrival at `j` on show, from `fixed` or the game's clock: {t, since}.
func clock(j: int) -> Dictionary:
	if not fixed.is_empty():
		return {t = float(fixed.get("t", 0.0)), since = float(fixed.get("since", -1.0))}
	var now := GameClock.now()
	var since := now - _arrive_t0 if _arrive_j == j and _arrive_t0 >= 0.0 else -1.0
	# REDUCED MOTION, as the page did: the transition plays, then it holds
	# idle frame 0
	if DisplaySettings.reduced_motion and (since < 0.0 or since >= trans_len(j, _arrive_from if _arrive_j == j else -1)):
		return {t = 0.0, since = -1.0}
	return {t = now, since = since}


## ONE FRAME ON SCREEN (`GoalLine.refresh`, every frame): `on` while the goal
## line is up; `pending` while the arrival at this count has yet to start (the
## line still fading in), when it holds the transition's first step, the count
## last shown (`seen`; -1 the jump before), so the new look never shows before
## it arrives. Repaints only when the frame changes.
func refresh(on: bool, pending: bool = false, seen: int = -1) -> void:
	var up := on and enabled() and Run.hull != null
	visible = up
	if not up:
		_hide_tip()
		return
	var j := count()
	var from := -1
	if pending:
		from = seen
	elif _arrive_j == j:
		from = _arrive_from
	if not fixed.is_empty() and fixed.has("from"):
		from = int(fixed.from)
	var c := clock(j)
	var since: float = c.since
	var t: float = c.t
	if pending and change_kind(j, from) != &"none" and fixed.is_empty():
		since = 0.0
		t = 0.0
	var st := arrival(since, j, from)
	var i := idle_of(j, t, since, from)
	var f := _from(j, from)
	# keyed by where it runs from only when that is not the jump before, so a
	# solo frame's key is what it always was
	var key := ("%d|a%d" % [j, st] if f == j - 1 else "%d<%d|a%d" % [j, f, st]) if st >= 0 \
		else "%d|i%d|%d" % [j, int(i.k), int(i.q)]
	shown = {j = j, from = f, t = t, since = since, step = st, k = int(i.k), q = int(i.q), key = key}
	if key != _key:
		_key = key
		paints += 1
		_buf.fill(0)
		_drawn = paint(_buf, 0, 7, j, t, since, from)
		if _img == null:
			_img = Image.create_from_data(IMG_W, IMG_H, false, Image.FORMAT_RGBA8, _buf)
			_tex = ImageTexture.create_from_image(_img)
		else:
			_img.set_data(IMG_W, IMG_H, false, Image.FORMAT_RGBA8, _buf)
			_tex.update(_img)
		queue_redraw()
	_hover(j)


## The Image on screen now (the tests read it).
func image() -> Image:
	return _img


## Its box on screen (global): S0's while it sleeps, 24 x 15 after; AS DRAWN,
## so while it holds the count before (an arrival pending, or its first step)
## the box is the look on show, not the one coming (S0's 37 px at the wake's
## first step, where it once was the wake's 24).
func box_rect() -> Rect2:
	return Rect2(global_position, Vector2(drawn_w(), BOX_H))


## The width of the box the frame on show inks in, or the count's while none is.
func drawn_w() -> int:
	return _drawn.size.x if _drawn.size.x > 0 else box_w(count())


## THE BADGE IS UP OVER `p` (viewport px): the chart's and the map's pictures
## under it take its presses but not its hover there, so the one tooltip that
## opens is the badge's, not theirs under it too (`StarchartScreen`'s and
## `SystemMapScreen`'s hover ask).
static func covers(p: Vector2) -> bool:
	var g: GoalLine = Router.hud.goal if Router.hud != null and is_instance_valid(Router.hud) else null
	if g == null or not is_instance_valid(g) or g.modulate.a <= 0.0:
		return false
	var b := g.badge()
	if b == null or not b.is_visible_in_tree():
		return false
	var local := b.get_global_transform_with_canvas().affine_inverse() * p
	return Rect2(Vector2.ZERO, Vector2(b.drawn_w(), BOX_H)).has_point(local)


func _draw() -> void:
	if _tex != null:
		draw_texture(_tex, Vector2.ZERO)


## THE POINTER OVER IT, read here (it ignores the mouse, `_input`): the tooltip after the
## project's tooltip delay (0.25 s, the HUD's), gone the moment it leaves, and
## never while a drag is under way or the line is fading.
func _hover(j: int) -> void:
	var gl := get_parent() as Control
	var vp := get_viewport()
	var over := vp != null and is_visible_in_tree() and gl != null and gl.modulate.a >= 0.99 \
		and _pointer_in and not vp.gui_is_dragging() and box_rect().has_point(_pointer)
	if not over:
		_hide_tip()
		return
	var now := GameClock.now()
	if _hover_t0 < 0.0:
		_hover_t0 = now
	var delay := float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5))
	if now - _hover_t0 < delay:
		return
	_show_tip(j)


func _hide_tip() -> void:
	_hover_t0 = -1.0
	if tip != null and tip.visible:
		tip.visible = false


func _show_tip(j: int) -> void:
	if tip == null:
		_build_tip()
	var lines := tooltip(j, party())
	if lines != _tip_lines:
		_tip_lines = lines
		for ch in _tip_box.get_children():
			_tip_box.remove_child(ch)
			ch.queue_free()
		var head := UITheme.body(lines[0], UITheme.BAD if tier(j) >= 1 else UITheme.THEM, UITheme.FS_SMALL)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_box.add_child(head)
		var sep := UITheme.hsep()
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_box.add_child(sep)
		for k in range(1, lines.size()):
			var l := UITheme.body(lines[k], UITheme.ICE, UITheme.FS_SMALL)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_tip_box.add_child(l)
		tip.reset_size()
	var sz := tip.get_combined_minimum_size()
	tip.size = sz
	tip.global_position = tip_spot(sz).position
	tip.visible = true


## WHERE THE TOOLTIP GOES (global), as the page put it: 6 px after the badge
## and no further left than the page's spot (`TIP_AT_*`), its top on the
## badge's top; stepped right past anything on the screen it would cover
## (`GoalLine.avoid_rects`, the goal, the badge and the step, A.S.H., a hint
## card), then under the goal's room if the row runs out.
func tip_spot(sz: Vector2) -> Rect2:
	var cur := Router.current
	var avoid := tip_avoid(cur)
	var bound := GoalLine.picture_rect(cur)
	if bound.size == Vector2.ZERO:
		bound = get_viewport_rect()
	var br := box_rect()
	var gl := get_parent() as Control
	var area := Router.content.get_global_rect() if Router.content != null else get_viewport_rect()
	var nav := cur is SystemMapScreen or cur is StarchartScreen
	var x0 := maxf(br.end.x + TIP_GAP, area.position.x + (TIP_AT_NAV if nav else TIP_AT_SECTOR))
	var rows: Array[Vector2] = [Vector2(x0, br.position.y)]
	var st := GoalLine.stack_rect(cur)
	if gl != null and st.size != Vector2.ZERO:
		rows.append(Vector2(st.position.x, st.end.y + TIP_GAP))
	for start: Vector2 in rows:
		var p := start
		for n in 32:
			var r := Rect2(p.round(), sz)
			if not bound.encloses(r):
				break
			var hit := Rect2()
			for a: Rect2 in avoid:
				if a.size.x > 0.0 and a.size.y > 0.0 and r.intersects(a):
					hit = a
					break
			if hit.size == Vector2.ZERO:
				return r
			p.x = hit.end.x + TIP_GAP
	return Rect2((rows[0] as Vector2).round(), sz)


## What the open tooltip must not cover on `cur`, global: what the goal line
## keeps off (but the picture's frame it stands inside), the goal and its step,
## A.S.H.'s box while she talks and a hint card.
func tip_avoid(cur: Control) -> Array:
	var out: Array = []
	var fr := GoalLine.frame_rect(cur)
	for r: Rect2 in GoalLine.avoid_rects(cur):
		if r != fr:
			out.append(r)
	var gl := get_parent() as GoalLine
	if gl != null:
		out.append(gl._panel.get_global_rect())
		out.append(box_rect())
		out.append(gl.step_rect())
	if Ash.portrait != null and is_instance_valid(Ash.portrait) and Ash.portrait.is_visible_in_tree():
		out.append(Ash.portrait.get_global_rect())
	if Hints.card != null and is_instance_valid(Hints.card) and Hints.card.visible:
		out.append(Hints.card.get_global_rect())
	return out


## The tooltip's rect on screen (global), or empty while it is shut.
func tip_rect() -> Rect2:
	return Rect2(tip.global_position, tip.size) if tip != null and tip.is_visible_in_tree() else Rect2()
