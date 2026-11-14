class_name ZoomLadder
extends Control

## One camera at four distances; the screens stay four, joined by a held picture and a dither.
## Why: docs/why/ZoomLadder.md#four-distances

enum { CHART = 0, MAP = 1, LOCAL = 2, STATION = 3 }

const DESIGNS := {1: ["A", "B", "C"], 2: ["A", "B", "C"], 3: ["A", "B", "C", "D"]}
## Jon's picks (Oct 8): 1A toned down, 2C smoothed, 3B with the hull flying in.
const DEFAULTS := {1: "A", 2: "C", 3: "B"}
## what each design is called where a person picks one (the sheet)
const NAMES := {
	"1A": "STAR OPENS", "1B": "STARS STREAM", "1C": "MOSAIC",
	"2A": "DIVE PAST THE SHIP", "2B": "INTO THE PLANE", "2C": "WORLD HANDOFF",
	"3A": "THROUGH THE RING", "3B": "INTO THE HANGAR, BULKHEAD", "3C": "MOSAIC",
	"3D": "INTO THE HANGAR",
}
## how a dive splits its length between the screen being left moving first and
## the move after the handoff (its whole length is `DIVE_S`)
const PRE_S := 0.38
const MOVE_S := 0.72
## how long an arriving screen may take to be ready before the move goes anyway
const WAIT_MAX_S := 1.2

## Jon's dial settings baked (Oct 19). A move is UI out, one camera move, UI in, never overlapping.
## Why: docs/why/ZoomLadder.md#move-timings
const UI_OUT_S := 0.22
const UI_IN_S := 0.4
## chart <-> map (1A), map <-> LOCAL (2C), and two distances in one go (a
## dive: Tab from the chart to LOCAL, the berth to the map): the camera move, s
const SEAM1_S := 1.7
const SEAM2_S := 1.8
const DIVE_S := 1.9
## THE LAB'S SCREEN, PRESSED (science S9, Jon's 1C): the camera into the glass until it fills the
## window, and back out on LEAVE (`LabZoom`), between the same UI_OUT_S and UI_IN_S beats. A guess
## at the calm moves' pace, not yet Jon's: one dial, here with the others.
const LAB_ZOOM_S := 0.9
## Docking is five steps, never two at once, camera still; undocking eases out down the same path.
## Why: docs/why/ZoomLadder.md#dock-in-five-steps
const DOCK_BEAT_S := 0.3
## A dock from the station's right (`Moored`): LOCAL to black, then the landing.
static var dock_fade_only := false
const DOCK_POWER_S := 1.3
const DOCK_ENTER_S := 4.0
## how fast the warning lights at the mouth flash while your ship waits (a second)
const DOCK_WARN_HZ := 1.6
## the dip to black at the end of the dock, your ship already out of sight (s)
const DOCK_DIP_S := 0.4
## Jon wanted far more drama between off and on: OFF, ON and GLOW set the bay and lamp levels.
## Why: docs/why/ZoomLadder.md#station-lights
const LIGHT_OFF := 0.22
const LIGHT_ON := 1.35
const LIGHT_GLOW := 1.8
## the camera's pan sideways through the station's hull into the yard
const DOCK_PAN_S := 1.4
## the yard: your ship in from the left, hanging on its jets, down onto its
## stands (`ShipLift.land_at`; and then the elevator, `ELEVATOR_S`)
const DOCK_YARD_S := ShipLift.LAND_S
## the elevator sliding back in once your ship is down (and out, undocking)
const ELEVATOR_S := 0.8
## undocking: the elevator out, your ship's heavy lift away to the right
## (`ShipLift.lift_at`), and on LOCAL the ENTER backwards, `DOCK_ENTER_S`
const UNDOCK_YARD_S := ELEVATOR_S * 0.6 + ShipLift.MAINS_ON + ShipLift.BURN_S
## Chart straight to LOCAL or the berth is a fade through black, no camera (Jon, Oct 10).
## Why: docs/why/ZoomLadder.md#chart-to-local
const FADE_OUT_S := 0.3
const FADE_IN_S := 0.45
## 0 is the focus object and a thin halo, Jon's pick of three sizes filmed (Oct 11).
## Why: docs/why/ZoomLadder.md#handoff-disc
const DISC_PX := 0.0
## Every hop between LOCAL, map and chart is one motion of one length (Jon's pick A, Oct 17).
## Why: docs/why/ZoomLadder.md#calm-move
const CALM_OUT_S := 0.2
## (the column crosses 265 px: at 0.6 s on its curve, at most 9 px a frame, the
## walk SideBarTest holds it to)
const CALM_SLIDE_S := 0.6
const CALM_CAM_S := 0.8
const CALM_IN_S := 0.25
## Decode is 0.7 s, Jon's pick of 0.4, 0.7 and 1.1 filmed (Oct 17), now that it runs after landing.
## Why: docs/why/ZoomLadder.md#calm-move
const CALM_DECODE_S := 0.7

## how much of the station's hull the pan passes through (game px)
const PAN_HULL_W := 520.0
## F is Jon's pick: the empty yard rises from black, then the ship flies in. P is kept as the alternative.
## Why: docs/why/ZoomLadder.md#yard-handoff
const FADES := ["F", "P"]
static var force_fade := ""
## F: a dip over the approach's last tenth, the empty yard up from black, then the ship comes in.
const FADE_DOWN := 0.1
const YARD_FADE_S := 1.2
const YARD_BEAT_S := 0.5
const LOCAL_FADE_S := 0.6


static func seam3_fade() -> String:
	if force_fade in FADES:
		return force_fade
	var a := _arg("seam3_fade").to_upper()
	return a if a in FADES else "F"


## The dock's five steps, s, in order: CUT, ARRIVE, BEAT, POWER, ENTER.
static func dock_steps() -> PackedFloat32Array:
	if dock_fade_only:
		return PackedFloat32Array([FADE_OUT_S, 0.0, 0.0, 0.0, 0.0])
	return PackedFloat32Array([FADE_OUT_S, ShipView.ARRIVE_LEAD_S + ShipView.ARRIVE_MS / 1000.0,
		DOCK_BEAT_S, DOCK_POWER_S, DOCK_ENTER_S])


## The step under way at `t` s into the dock (0 CUT .. 4 ENTER, 5 past the
## end), and how far into it (0..1): `Vector2(step, u)`.
static func dock_step_at(t: float) -> Vector2:
	var at := 0.0
	var steps := dock_steps()
	for i in steps.size():
		var d := maxf(steps[i], 0.001)
		if t < at + d:
			return Vector2(i, clampf((t - at) / d, 0.0, 1.0))
		at += steps[i]
	return Vector2(steps.size(), 1.0)


## When step `i` starts, s into the dock.
static func dock_step_from(i: int) -> float:
	var at := 0.0
	var steps := dock_steps()
	for j in mini(i, steps.size()):
		at += steps[j]
	return at


static func dock_approach_s() -> float:
	return dock_step_from(5)


## A Hermite curve: the pieces of one smooth motion each start at the speed the last ended on.
static func herm(u: float, m0: float, m1: float) -> float:
	u = clampf(u, 0.0, 1.0)
	var u2 := u * u
	var u3 := u2 * u
	return (u3 - 2.0 * u2 + u) * m0 + (-2.0 * u3 + 3.0 * u2) + (u3 - u2) * m1
const SHADER := preload("res://shaders/zoom_ladder.gdshader")

## The move under way, if any.
static var active: ZoomLadder = null
## A harness steps the move by this many seconds a frame (frames filmed at 30
## fps then play at true speed however slowly the window drew); <= 0: real time.
static var fixed_dt := -1.0
## A harness's real-time trace: microseconds spent this frame, by what (`probe_add`;
## the harness reads and clears it each frame). Off unless a harness turns it on.
static var probe_on := false
static var probe := {}
## A swap mid-move leaves the autosave to the move's end: the write is ~15 ms of one frame.
static var save_after := false


static func probe_add(k: String, us: int) -> void:
	if probe_on:
		probe[k] = int(probe.get(k, 0)) + us
## A harness's override of the switch: 1 on, 0 off, -1 the setting.
static var force := -1
## And of a seam's design: seam -> letter.
static var force_design := {}
## The Router's own call, being made by a pre-roll's end: `preroll` declines it.
static var _going := false

## UI_OUT takes the left screen's UI away; UI_IN brings the arriving screen's up after the landing.
## Appended, so the old phases keep their numbers for the harnesses that log them.
enum Phase { PRE, PRE_DONE, WAIT, MOVE, UI_OUT, UI_IN, FADE_OUT, FADE_HOLD, FADE_IN,
	C_OUT, C_SLIDE, C_WAIT, C_CAM, C_POST, C_IN }
## the move is a plain fade through black (`is_fade`)
var _fade := false
var phase: Phase = Phase.PRE
var old: Control = null
var new: Control = null
var r_old := -1
var r_new := -1
var seam := 0
var design := "A"
var _then: Callable
var _u := 0.0
var _waited := 0.0
var _pre_k := 0.0
var _rect: ColorRect
var _mat: ShaderMaterial
var _tex: ImageTexture
## the held picture: its anchor, its picture rect, the arriving camera's scale
## when the move began
var _a_old := Vector2.ZERO
var _pic := Rect2()
var _s0 := 1.0
var _style := {}
## One smoothstep over `_T` seconds, split at `_F`, so the handoff has no stop or change of speed.
var _T := 1.0
var _F := 0.5
var _tau := 0.0
var _g_last := 0.0
var _pre_s := PRE_S
var _move_s := MOVE_S
## the held picture's own growth (log scale) over the second half, for the
## frame(s) before the new screen is ready
var _l_move := 0.0
## the hull carried over (3B): the art, its rect in each picture
var _hull: TextureRect = null
var _hull_from := Rect2()
var _hull_to := Rect2()
var _hull_tex: Texture2D = null
## what the held picture's screen said about itself as it went (it is freed at
## the end of the swap's frame, so nothing is asked of it after)
var _old_plane := {}
var _old_world := {}
## the arriving screen placed its camera on the held picture's anchor
var _met := false
## 1A: the map's sun as the held picture had it (coming out)
var _old_sun := {}
## 2C: where LOCAL will have the world, for the frame(s) before it is up
var _rest_est := Vector2.INF
## 2C: the map's own world node, given at the swap ({} once taken or for none)
var _given := {}
var _taken := false
## For a harness: the first frame after the swap matches the held picture, so they can be diffed.
static var measure_hold := false
var _held_frames := 0
## the screen left moved first (the move then starts at speed)
var _had_pre := false
## the UI's own clock (UI_OUT, UI_IN), s
var _ui_u := 0.0
## THE SIDE BAR'S SWAP (`_side_begin`), and the old side bar's rect (viewport px)
var side_swap: SideSwap = null
var _side_old := Rect2()
## and the screen's own toolbar along its top (`ladder_bar`), the same way
var bar_swap: SideSwap = null
var _bar_old := Rect2()
## and the KEY band along the bottom (`ladder_foot`), between the map and the chart
var foot_swap: SideSwap = null
## ended by a press or a key: anything still decoding ends with it
var _cut := false
## The side bar's look, one of `SIDE_LOOKS` (A crossfade to F reboot), each drawn by `SideSwap`.
const SIDE_LOOKS := ["A", "B", "C", "D", "E", "F"]
## Jon picked E, decode (Oct 13), and the chart and map toolbars decode too (`ladder_bar`).
## Why: docs/why/ZoomLadder.md#side-bar-look
const SIDE_LOOK := "E"
static var _side_force := ""
## Between LOCAL and a screen with chrome, the band and side bar slide; LOCAL is never scaled.
## Why: docs/why/ZoomLadder.md#chrome-slide
var band: SideBand = null
## the chrome sliding, and which way: &"on" out of LOCAL, &"off" into it
var slides: Array = []
var _slide_way: StringName = &""


## The band over the top of the screens' area, opening as the ladder drives it.
func _make_band() -> SideBand:
	var b := SideBand.new()
	add_child(b)
	var c := _content_rect()
	b.setup(Rect2(c.position.x, c.position.y, c.size.x, StarchartScreen.row_h() + 4), false)
	b.driven = true
	b.drive(0.0)
	return b


static func _content_rect() -> Rect2:
	return Router.content.get_global_rect() if Router.content != null else Rect2(8, 42, 944, 491)


## Where a side bar stands on the map and the chart: down the right, under
## their band, the key's row below it (viewport px).
static func _side_rest() -> Rect2:
	var c := _content_rect()
	var top := c.position.y + StarchartScreen.row_h() + 4
	return Rect2(c.end.x - 260, top, 260, c.end.y - top - 16)


## Out of LOCAL the band and an empty side column come on, both driven by `_drive_chrome`.
func _chrome_on() -> void:
	_slide_way = &"on"
	band = _make_band()
	var c := _content_rect()
	var pr := _side_rest()
	var rest := Rect2(pr.position.x - 5, pr.position.y, c.end.x - (pr.position.x - 5), c.end.y - pr.position.y)
	var p := ChromeSlide.new()
	add_child(p)
	p.plate = UITheme.flat(Color(UITheme.PANEL, UITheme.PANEL_A), UITheme.LINE, 0, 12, 12)
	p.plate_rect = pr
	p.setup(&"side", rest, Vector2(c.end.x - rest.position.x, 0), c, 0.0)
	slides.append(p)


## INTO LOCAL: the chrome of `from`, as the picture `tex` has it, carried off
## -- the band up, the side bar's column right -- driven by the move.
func _chrome_off(tex: Texture2D, from: Control) -> void:
	_slide_way = &"off"
	var c := _content_rect()
	var sd := side_of(from)
	var pr := sd.get_global_rect() if sd != null and sd.size.x > 2.0 else _side_rest()
	# (the band to the frame's top edge, its border row too)
	var bh := pr.position.y - c.position.y + 1.0
	var bp := ChromeSlide.new()
	add_child(bp)
	bp.tex = tex
	bp.setup(&"band", Rect2(c.position.x, c.position.y, c.size.x, bh), Vector2(0, -bh), c, 1.0)
	var rest := Rect2(pr.position.x - 5, pr.position.y, c.end.x - (pr.position.x - 5), c.end.y - pr.position.y)
	var sp := ChromeSlide.new()
	add_child(sp)
	sp.tex = tex
	sp.setup(&"side", rest, Vector2(c.end.x - rest.position.x, 0), c, 1.0)
	slides.append(bp)
	slides.append(sp)
	# (the held picture leaves both to them)
	_mat.set_shader_parameter(&"side", Vector4(rest.position.x, rest.position.y, rest.size.x, rest.size.y))
	_mat.set_shader_parameter(&"side2", Vector4(c.position.x, c.position.y, c.size.x, bh))


## How far through a dive's whole dip the chrome is (0 to 1): down to black and
## up from it, as one stretch, so the side bar's column crosses at a walk.
func _dive_q() -> float:
	var whole := maxf(FADE_OUT_S + FADE_IN_S, 0.001)
	match phase:
		Phase.FADE_OUT:
			return clampf(_ui_u / whole, 0.0, 1.0)
		Phase.FADE_HOLD:
			return clampf(FADE_OUT_S / whole, 0.0, 1.0)
		Phase.FADE_IN:
			return clampf((FADE_OUT_S + _ui_u) / whole, 0.0, 1.0)
	return 1.0


## A screen's own chrome hidden while a piece of it is drawn on the move in a
## dive (it would show through the dip beside the piece), and put back.
var _hid: Array = []


func _hide_chrome(s: Control) -> void:
	for c: Variant in [side_of(s), bar_of(s), PanelSlide.veil_of(s)]:
		if c != null and is_instance_valid(c):
			(c as CanvasItem).modulate.a = 0.0
			_hid.append(c)


func _show_chrome() -> void:
	for c: Variant in _hid:
		if is_instance_valid(c):
			(c as CanvasItem).modulate.a = 1.0
	_hid.clear()


static func _ease_in(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * u


## On eases out as the camera leaves LOCAL, off eases in as it lands, so it lands as screens change.
func _drive_chrome() -> void:
	if _slide_way != &"on" and _slide_way != &"off":
		return
	var curve := bool(_style.get("curve", false))
	# (how far through its half of the move: the camera's own progress, or the
	# dip's; 1 is landed, chrome on or chrome off)
	var q := -1.0
	if _slide_way == &"on":
		match phase:
			Phase.UI_OUT:
				q = 0.0
			Phase.PRE:
				q = clampf(ease_cam_curve(_tau / maxf(_T, 0.001)) / maxf(_F, 0.001), 0.0, 1.0) if curve else clampf(_u, 0.0, 1.0)
			Phase.FADE_OUT, Phase.FADE_HOLD, Phase.FADE_IN:
				q = _dive_q()
			_:
				q = 1.0
	else:
		match phase:
			Phase.MOVE:
				q = _curve_e() if curve else clampf(_u, 0.0, 1.0)
			Phase.FADE_OUT, Phase.FADE_HOLD, Phase.FADE_IN:
				q = _dive_q()
			Phase.UI_IN, Phase.PRE_DONE:
				q = 1.0
			_:
				q = 0.0
	# The side column (265 px) rides a sine so its fastest is 8 px a frame, not 15.
	# Why: docs/why/ZoomLadder.md#chrome-slide
	var on := _slide_way == &"on"
	var k := _ease_out(q) if on else 1.0 - _ease_in(q)
	var ks := sin(q * PI * 0.5) if on else cos(q * PI * 0.5)
	for p: Variant in slides:
		if is_instance_valid(p):
			(p as ChromeSlide).set_k(ks if (p as ChromeSlide).kind == &"side" else k)
	if band != null and is_instance_valid(band) and band.driven:
		band.drive(k)


static func force_side_look(l: String) -> void:
	_side_force = l if l in SIDE_LOOKS else ""


static func side_look() -> String:
	if _side_force != "":
		return _side_force
	var a := _arg("side").to_upper()
	return a if a in SIDE_LOOKS else SIDE_LOOK
## what runs when the camera lands (`when_landed`): the event's band lifting on
## LOCAL, say -- the UI arriving after the move, never during it
var _landed: Array[Callable] = []
var _landed_done := false
## Set when a move left the UI hidden because another follows at once (the map's DOCK).
static var chrome_hidden: Control = null


# ------------------------------------------------------------------ switches

static func _arg(k: String) -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(k + "="):
			return (a as String).substr(k.length() + 1)
	return ""


## Whether C's flow is on (always, but for a harness's `flow=`), animation aside.
static func chosen() -> bool:
	if force >= 0:
		return force == 1
	var a := _arg("flow")
	if a == "legacy" or a == "off":
		return false
	if a == "c" or a == "on":
		return true
	# A HARNESS takes today's flow unless it asks (`flow=c`): every test written
	# before the ladder expects the doors it was written against
	if TestRun.active():
		return false
	return true


static func enabled() -> bool:
	return chosen() and not hold_off and Router.animating()


## Set for the length of a call that must be instant (a skip).
static var hold_off := false


static func design_for(s: int) -> String:
	if force_design.has(s):
		return String(force_design[s])
	var a := _arg("flow%d" % s).to_upper()
	if a in DESIGNS.get(s, []):
		return a
	return String(DEFAULTS.get(s, "A"))


static func rank_of(s: Control) -> int:
	if s == null or not is_instance_valid(s):
		return -1
	if s is StarchartScreen:
		return CHART
	if s is SystemMapScreen:
		return MAP
	if s is SectorScreen:
		return LOCAL
	if s is StationScreen:
		return STATION
	return -1


## Which seam a move crosses, or 0 for one two distances long (a dive).
static func seam_between(a: int, b: int) -> int:
	if absi(a - b) != 1:
		return 0
	return mini(a, b) + 1


## Where LOCAL draws the world you orbit, so the map aims at it on its way in (2C).
static var world_rest := {}


static func rest_world(node_index: int, body: SystemLayout.Body) -> Dictionary:
	var key := "%d:%d" % [node_index, body.index]
	if world_rest.has(key):
		return world_rest[key]
	# (LocalSky's own rule, on the side it draws the world before an event asks)
	var R := LocalSky.near_r(body)
	if node_index < 0 or node_index >= Run.map.size():
		return {"c": Vector2(698.0, 339.0 + 0.2 * R), "r": R}
	var n: MapGen.MapNode = Run.map[node_index]
	var pl := LocalSky.near_place(n, body, LocalSky.near_side(n))
	return {"c": pl.at, "r": R}


static func busy() -> bool:
	return active != null and is_instance_valid(active)


## A calm move is under way: the screens' bottom bands slide or stand held, never fade (Jon, Nov 11).
static func calm_moving() -> bool:
	return busy() and active._calm


## The distance the HUD's tabs light: where a move under way is going, or the
## screen up (-1 for one that is none of the four).
static func lit_rank() -> int:
	if busy() and active.r_new >= 0:
		return active.r_new
	return rank_of(Router.current)


static func _hud_refresh() -> void:
	if Router.hud != null and is_instance_valid(Router.hud) and Router.hud.has_method(&"refresh"):
		Router.hud.call(&"refresh")


## A piece of a screen's UI k gone: faded from its
## alpha and moved `dx`; at 0 it is put back exactly.
static func fade_chrome(c: CanvasItem, k: float, dx: float = 0.0) -> void:
	if c == null or not is_instance_valid(c):
		return
	var e := clampf(k, 0.0, 1.0)
	if e <= 0.0:
		if c.has_meta(&"lad_a0"):
			c.modulate.a = float(c.get_meta(&"lad_a0"))
			c.remove_meta(&"lad_a0")
		if c.has_meta(&"lad_x0") and c is Control:
			(c as Control).position.x = float(c.get_meta(&"lad_x0"))
			c.remove_meta(&"lad_x0")
			if c.get_parent() is Container:
				(c.get_parent() as Container).queue_sort()
		return
	if not c.has_meta(&"lad_a0"):
		c.set_meta(&"lad_a0", c.modulate.a)
	c.modulate.a = float(c.get_meta(&"lad_a0")) * (1.0 - e)
	if dx != 0.0 and c is Control:
		if not c.has_meta(&"lad_x0"):
			c.set_meta(&"lad_x0", (c as Control).position.x)
		(c as Control).position.x = roundf(float(c.get_meta(&"lad_x0")) + dx * e * e)


## A SIDE PANEL off the edge of the screen by k (0 where it stands, 1 gone right),
## in whole pixels; `x` is where it stands. Chrome slides, it does not fade.
static func slide(c: Control, x: float, k: float) -> void:
	if c == null or not is_instance_valid(c) or is_nan(x):
		return
	var kk := clampf(k * 1.4, 0.0, 1.0)
	c.position.x = roundf(x + kk * kk * (c.size.x + 12.0))
	# at rest, its container places it again (as it would have)
	if k <= 0.0 and c.get_parent() is Container:
		(c.get_parent() as Container).queue_sort()


# ------------------------------------------------------------------ the doors

## The screen being left moves its camera first; `then` runs when done. False means go now.
static func preroll(target: int, then: Callable) -> bool:
	if _going or not enabled():
		return false
	# A CALM MOVE UNDER WAY: a press is never a cut and never lost -- the move
	# hurries to its end, and the door asked for is taken from there
	if busy() and active._calm:
		if target != active.r_new:
			active._calm_queue(target, then)
		active.hurry()
		return true
	# (a decode a move before handed on is finished: this move is its own)
	SideSwap.finish_all()
	SideBand.finish_all()
	ChromeSlide.finish_all()
	# (the jump's own flare is the cut on its far side)
	if Router._post_arrive:
		return false
	var cur := Router.current
	var r := rank_of(cur)
	if r < 0 or r == target or not cur.has_method(&"ladder_cam"):
		return false
	if busy():
		active.finish_now()
	# The map's DOCK goes by black, ship kept off LOCAL, so its arrival is the first sight (Jon, Oct 20).
	# Why: docs/why/ZoomLadder.md#map-dock-by-black
	var dock_fade := chain == &"station" and r == MAP and target == LOCAL
	if calm_hop(r, target) and not dock_fade:
		_calm_preroll(cur, r, target, then)
		return true
	var lad := _make()
	lad.old = cur
	lad.r_old = r
	lad.r_new = target
	lad.seam = seam_between(r, target)
	lad.design = design_for(lad.seam) if lad.seam > 0 else "A"
	lad._then = then
	# THE CHART AND LOCAL (or the berth) ARE A FADE, NOT A MOVE: nothing built
	# ahead (it is built in the black), no camera, no UI beats of their own
	if (lad.seam == 0 and is_fade(r, target)) or dock_fade:
		lad._fade = true
		lad.phase = Phase.FADE_OUT
		_hud_refresh()
		# THE CHROME MOVES IN A DIVE TOO, over the picture's dip to black: out of
		# LOCAL on as it goes down, into it off as it comes up
		if r == LOCAL and target == CHART:
			lad._fit()
			lad._chrome_on()
		elif r == CHART and target == LOCAL and side_of(cur) != null:
			lad._fit()
			var vp := lad.get_viewport()
			var im: Image = null
			if vp != null and vp.get_texture() != null and DisplayServer.get_name() != "headless":
				im = vp.get_texture().get_image()
			if im == null or im.is_empty():
				im = Image.create(960, 540, false, Image.FORMAT_RGBA8)
			lad._chrome_off(ImageTexture.create_from_image(im), cur)
			lad._hide_chrome(cur)
		return true
	lad._pre_k = float(cur.call(&"ladder_pre", target, lad.seam, lad.design))
	# THE UI LEAVES FIRST, the camera still, on every move -- even one whose
	# screen has no camera of its own to move first (the station's berth)
	var chrome := cur.has_method(&"ladder_chrome") and UI_OUT_S > 0.001 and chrome_hidden != cur
	var sd := side_of(cur)
	if sd != null and sd.is_visible_in_tree():
		lad._side_old = sd.get_global_rect()
	var br := bar_of(cur)
	if br != null and br.is_visible_in_tree():
		lad._bar_old = br.get_global_rect()
	if lad._pre_k <= 0.0 and not chrome:
		active = null
		lad.queue_free()
		return false
	lad._had_pre = lad._pre_k > 0.0
	lad._style = lad._style_for()
	lad._pre_s = float(lad._style.get("pre_s", PRE_S))
	lad._move_s = float(lad._style.get("move_s", MOVE_S))
	lad._T = lad._pre_s + lad._move_s
	lad._F = lad._pre_s / lad._T
	if lad._had_pre:
		cur.call(&"ladder_cam_begin", target, lad.seam, lad.design)
	# The map is built during the pre-roll, drawn but unseen, so the move never waits on it.
	# Why: docs/why/ZoomLadder.md#prebuilt-map
	var _pt_pre := Time.get_ticks_usec()
	if (target == MAP or target == CHART) and not Run.map.is_empty() and Router.content != null:
		var pm: Control = SystemMapScreen.new() if target == MAP else StarchartScreen.new()
		# The chart stands at a trace of opacity; the map at none, as its sun shader ignores opacity.
		# Why: docs/why/ZoomLadder.md#prebuilt-map
		pm.modulate.a = PREBUILT_A if target == CHART else 0.0
		pm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# (laid out where the screens are, with nothing beside it: under this
		# ladder, which stands exactly over the screens' place)
		lad._fit()
		lad.add_child(pm)
		lad.move_child(pm, 0)
		pm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if pm is SystemMapScreen:
			# Out of LOCAL the map takes LOCAL's clock, so the pair stands where LOCAL had it.
			# Why: docs/why/ZoomLadder.md#prebuilt-map
			(pm as SystemMapScreen).show_system(Run.node_at(), Net.handed_clock(Run.at) if r == LOCAL else Net.adopt_clock(Run.at), false)
		else:
			(pm as StarchartScreen).setup()
		prebuilt = pm
		# (out of LOCAL: the arriving screen's chrome comes on now, as this
		# screen's camera moves, so the swap finds it where the next one has it)
		if side_of(cur) == null and bar_of(cur) == null and (side_of(pm) != null or bar_of(pm) != null):
			lad._chrome_on()
		ZoomLadder.probe_add("prebuild", Time.get_ticks_usec() - _pt_pre)
	# On 2C, LOCAL is built at the click, not mid-dive where it cost 60 to 90 ms of one frame.
	# Why: docs/why/ZoomLadder.md#prebuild-local
	elif target == LOCAL and ((lad.seam == 2 and lad.design == "C") or lad.seam == 0) \
			and _local_quiet(false, true) and Router.content != null:
		var ps := SectorScreen.new()
		ps.modulate.a = 0.0
		ps.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lad._fit()
		lad.add_child(ps)
		lad.move_child(ps, 0)
		ps.setup(null)
		prebuilt = ps
		ZoomLadder.probe_add("prebuild", Time.get_ticks_usec() - _pt_pre)
	# On 3B both screens are built before anything moves; built at the swap they stood still mid-move.
	# Why: docs/why/ZoomLadder.md#prebuild-yard
	elif target == STATION and ((lad.seam == 3 and lad.design == "B") or (lad.seam == 0 and Router.docked)) \
			and Router.content != null and not Router.in_combat():
		var ss := StationScreen.new()
		ss.modulate.a = 0.0
		ss.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Build under the game's theme, not the ladder's: the engine's made the figures 153 tall, not 144.
		# Why: docs/why/ZoomLadder.md#prebuild-yard
		Router.content.add_child(ss)
		Router.content.move_child(ss, 0)
		ss.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ss.setup()
		ss.process_mode = Node.PROCESS_MODE_DISABLED
		ss.set_meta(&"ladder_at", Run.at)
		prebuilt = ss
		# (and its room's tone, loaded while LOCAL moves)
		var rn: Variant = Router._room_for(ss)
		if rn != null:
			Audio.warm_room(StringName(rn))
	elif target == LOCAL and lad.seam == 3 and lad.design == "B" and Router.content != null and _local_quiet(true):
		# (leaving a berth is arriving at the system it is in: `Router.show_local`)
		SectorScreen._approached_at = Run.at
		var pl := SectorScreen.new()
		pl.modulate.a = 0.0
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Build under the game's theme: the engine's left the bar 43 px tall for 32 and the ship 5 px high.
		# Why: docs/why/ZoomLadder.md#prebuild-yard
		Router.content.add_child(pl)
		Router.content.move_child(pl, 0)
		pl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pl.setup(null)
		prebuilt = pl
	# the motion's split, from how far each half travels (log scale), so the
	# speed is the same on both sides of the handoff
	if lad._had_pre and bool(lad._style.get("curve", false)) and cur.has_method(&"ladder_spans"):
		var sp: Vector2 = cur.call(&"ladder_spans")
		if sp.x > 0.01 and sp.y > 0.01:
			lad._F = clampf(sp.x / (sp.x + sp.y), 0.35, 0.9)
			lad._l_move = sp.y * (1.0 if target > r else -1.0)
	# (and the screen being left told how much of the way across it carries the
	# thing it closes on, so the next screen carries the rest at the same speed)
	if lad._had_pre and bool(lad._style.get("curve", false)) and cur.has_method(&"ladder_split"):
		cur.call(&"ladder_split", lad._F)
	lad.phase = Phase.UI_OUT if chrome else Phase.PRE
	_hud_refresh()
	if chrome_hidden == cur:
		chrome_hidden = null
	return true


## Called by `Router._swap` before the old screen goes: hold its picture.
static func capture(o: Control, n: Control) -> void:
	# THE CALM MOVE'S OWN DOOR: the screens change hands on its curve
	if busy() and active._calm and active.old == o and active._calm_firing:
		active._calm_hold(n)
		return
	# (a decode handed on by a move already over stops as anything else comes)
	if not (busy() and active.old == o):
		SideSwap.finish_all()
		SideBand.finish_all()
		ChromeSlide.finish_all()
	if not enabled():
		if busy():
			_capturing = true
			active.finish_now()
			_capturing = false
		return
	var ro := rank_of(o)
	var rn := rank_of(n)
	var lad: ZoomLadder = null
	if busy() and active.phase == Phase.PRE_DONE and active.old == o:
		lad = active
		# (a fade: the screen arriving is under the black; it comes up once it
		# has drawn a few frames there, so nothing it builds is seen stalling)
		if lad._fade:
			lad.new = n
			lad.r_new = rn
			lad.phase = Phase.FADE_HOLD
			lad._held_frames = 0
			lad._waited = 0.0
			# (out of LOCAL its chrome comes on over the dip: the arriving
			# screen's own stays hidden under it until it lands)
			if lad._slide_way == &"on":
				lad._hide_chrome.call_deferred(n)
			return
	elif busy():
		# (another screen is coming in by some other door: a calm move under
		# way gives way to it rather than taking its own door on top of it)
		_capturing = true
		active.finish_now()
		_capturing = false
	if ro < 0 or rn < 0 or ro == rn or Router._post_arrive:
		if lad != null:
			lad._end()
		return
	if lad == null:
		lad = _make()
		lad.old = o
		lad.r_old = ro
		lad.seam = seam_between(ro, rn)
		lad.design = design_for(lad.seam) if lad.seam > 0 else "A"
	lad.r_new = rn
	lad.new = n
	if not lad._had_pre:
		lad._style = lad._style_for()
		# (no screen moved first: the move is the whole of the seam's length)
		lad._move_s = float(lad._style.get("total", lad._style.get("move_s", MOVE_S)))
		lad._pre_s = 0.0
		lad._T = lad._move_s
		lad._F = 0.0
	var th := Time.get_ticks_usec()
	lad._hold()
	probe_add("hold", Time.get_ticks_usec() - th)
	# A screen built ahead moves on this very frame, so the swap frame is not a still one.
	if lad.phase == Phase.WAIT and n.has_method(&"ladder_ready") and bool(n.call(&"ladder_ready")):
		lad._start_move.call_deferred()


## Whether a move between ranks `a` and `b` is a plain fade: the chart and LOCAL,
## or the chart and the berth, either way.
static func is_fade(a: int, b: int) -> bool:
	return (a == CHART and (b == LOCAL or b == STATION)) or (b == CHART and (a == LOCAL or a == STATION))


## Whether a move is running and this screen is the one it arrives at.
static func takes(s: Control) -> bool:
	return busy() and active.new == s


static func _make() -> ZoomLadder:
	var lad := ZoomLadder.new()
	active = lad
	var root: Node = Router.content.get_viewport() if Router.content != null else null
	if root != null:
		root.add_child(lad)
	return lad


# ------------------------------------------------------------------ the move

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


func _fit() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(960, 540))
	if Router.content != null and is_instance_valid(Router.content):
		r = Router.content.get_global_rect()
	position = r.position
	size = r.size
	_rect.position = Vector2.ZERO
	_rect.size = r.size
	_mat.set_shader_parameter(&"rect_pos", r.position)
	_mat.set_shader_parameter(&"rect_size", r.size)


## (a long frame -- a screen being built -- holds the move for that frame rather
## than jumping it on: no step is ever more than a 30th of a second)
func _dt(delta: float) -> float:
	if fixed_dt > 0.0:
		return fixed_dt
	# 2C: a frame far longer than its neighbours counts as one ordinary frame, so the move waits.
	if bool(_style.get("wait_long", false)) and delta > 1.0 / 24.0:
		return 1.0 / 60.0
	return minf(delta, 1.0 / 30.0)


static func ease_curve(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## Smootherstep: no jolt at either end, where the
## smoothstep before it set off and stopped with a kick.
static func ease_cam_curve(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * u * (u * (u * 6.0 - 15.0) + 10.0)


## Ease out (fast start, long settle): the camera's own curve.
static func _ease_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


func _process(delta: float) -> void:
	if _calm:
		_process_calm(delta)
		return
	_process_move(delta)
	if not is_queued_for_deletion():
		_drive_chrome()


func _process_move(delta: float) -> void:
	var dt := _dt(delta)
	var curve := bool(_style.get("curve", false))
	# The arriving UI waits for the landing and the left one stays away while its camera moves.
	if phase == Phase.WAIT or phase == Phase.MOVE:
		_chrome(new, 1.0)
	elif phase == Phase.PRE and _ui_u > 0.0:
		_chrome(old, 1.0)
	match phase:
		Phase.FADE_OUT:
			if not is_instance_valid(old) or Router.current != old:
				_end()
				return
			_ui_u += dt
			_black_at(ease_curve(_ui_u / maxf(FADE_OUT_S, 0.001)))
			if _ui_u >= FADE_OUT_S:
				_black_at(1.0)
				phase = Phase.PRE
				_fire()
			return
		Phase.FADE_HOLD:
			_black_at(1.0)
			_chain_chrome()
			_held_frames += 1
			_waited += dt
			if not is_instance_valid(new):
				_end()
				return
			var ready := not new.has_method(&"ladder_ready") or bool(new.call(&"ladder_ready"))
			if (ready and _held_frames >= 3) or _waited >= WAIT_MAX_S:
				phase = Phase.FADE_IN
				_ui_u = 0.0
				_run_landed()
			return
		Phase.FADE_IN:
			if not is_instance_valid(new) or Router.current != new:
				_end()
				return
			_ui_u += dt
			_black_at(1.0 - ease_curve(_ui_u / maxf(FADE_IN_S, 0.001)))
			_chain_chrome()
			if _ui_u >= FADE_IN_S:
				if _slide_way == &"on":
					_decode_after_dive()
				_end()
			return
		Phase.UI_OUT:
			if not is_instance_valid(old) or Router.current != old:
				_end()
				return
			_ui_u += dt
			_chrome(old, ease_curve(_ui_u / maxf(UI_OUT_S, 0.001)))
			if _ui_u >= UI_OUT_S:
				_chrome(old, 1.0)
				phase = Phase.PRE
				# (a screen with no camera of its own goes straight to the move)
				if not _had_pre:
					_fire()
			return
		Phase.UI_IN:
			if not is_instance_valid(new) or Router.current != new:
				_end()
				return
			_ui_u += dt
			_chrome(new, 1.0 - ease_curve(_ui_u / maxf(UI_IN_S, 0.001)))
			if _ui_u >= UI_IN_S:
				_end()
			return
		Phase.PRE:
			if not is_instance_valid(old) or Router.current != old:
				_end()
				return
			if curve:
				_tau += dt
				var g := ease_cam_curve(_tau / _T)
				# Handed over before this frame moves the old
				# camera, so the held picture and its anchors match.
				if g >= _F:
					# (the second half runs on from where the last drawn frame was)
					_F = _g_last
					_fire()
					return
				old.call(&"ladder_cam", _pre_k * clampf(g / maxf(_F, 0.001), 0.0, 1.0))
				_g_last = g
				if old.has_method(&"ladder_peek"):
					old.call(&"ladder_peek")
				return
			_u += dt / maxf(_pre_s, 0.001)
			# eased IN: the move that follows starts at speed, so the two halves
			# are one motion with no stop at the handoff
			var ui := clampf(_u, 0.0, 1.0)
			old.call(&"ladder_cam", _pre_k * (ui if bool(_style.get("pan", false)) else ui * ui))
			if String(_style.get("fade", "")) == "F":
				# F: down to black over the pre-roll's last stretch
				# (docking: the last tenth, ship behind the lips).
				var fd := minf(DOCK_DIP_S, _pre_s * FADE_DOWN) if old is SectorScreen else YARD_FADE_S
				# (and only once your ship is all in: LOCAL knows when that is)
				if old is SectorScreen and float(old.call(&"ladder_dip_s")) > 0.0:
					fd = minf(fd, float(old.call(&"ladder_dip_s")))
				var blk := ease_curve(clampf((_u * _pre_s - (_pre_s - fd)) / fd, 0.0, 1.0))
				# (docking, the CUT at the start: LOCAL's own black)
				if old is SectorScreen:
					blk = maxf(blk, float(old.call(&"ladder_black")))
				_black_at(blk)
			if _u >= 1.0:
				# (the move goes on from where the clock is, not a frame later)
				_pan_t0 = (_u - 1.0) * _pre_s
				_fire()
		Phase.WAIT:
			_waited += dt
			if not is_instance_valid(new):
				_end()
				return
			# (1A waits for the map with the chart's star held where it is: the
			# map's sun has to be there to take over from it, so the clock waits too)
			if curve and not measure_hold and not bool(_style.get("sun", false)):
				# the clock runs on, and the held picture with it
				_tau += dt
				var ew := _curve_e()
				_mat.set_shader_parameter(&"scl", Vector2.ONE * exp(_l_move * ew))
				# (and on along its line, so the frame before LOCAL is up is not a stop)
				if _rest_est != Vector2.INF:
					_mat.set_shader_parameter(&"to_pt", _a_old.lerp(_rest_est, ew))
			if bool(new.call(&"ladder_ready")) or _waited >= WAIT_MAX_S:
				_start_move()
		Phase.MOVE:
			if not is_instance_valid(new):
				_end()
				return
			if bool(_style.get("pan", false)):
				_u += dt
				_step_pan(_u)
				if _u >= _move_s:
					_land()
				return
			if curve:
				if measure_hold and _held_frames < 1:
					_held_frames += 1
					return
				_tau += dt
				_step(_curve_e())
				if _tau >= _T:
					_land()
				return
			_u += dt / maxf(_move_s, 0.001)
			_step(_u)
			if _u >= 1.0:
				_land()


## How far into the second half of the one curve the clock is (0 to 1).
func _curve_e() -> float:
	var g := ease_cam_curve(_tau / maxf(_T, 0.001))
	return clampf((g - _F) / maxf(1.0 - _F, 0.001), 0.0, 1.0)


## The pre-roll is done (or skipped): make the Router's call.
func _fire() -> void:
	if phase != Phase.PRE:
		return
	phase = Phase.PRE_DONE
	var cb := _then
	_then = Callable()
	_going = true
	var t0 := Time.get_ticks_usec()
	cb.call()
	probe_add("door", Time.get_ticks_usec() - t0)
	_going = false
	# the call did not swap (refused on its own terms): the old screen stays, at rest
	if phase == Phase.PRE_DONE:
		if is_instance_valid(old):
			old.call(&"ladder_cam", 0.0)
			old.call(&"ladder_cam_end")
		_end()


func _input(e: InputEvent) -> void:
	var press := (e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo) \
		or (e is InputEventMouseButton and (e as InputEventMouseButton).pressed
			and (e as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE])
	if not press:
		return
	# A press hurries the calm move to its end, never cuts it, and goes on to what it was for.
	if _calm:
		var eat_c := _calm_eats(e)
		hurry()
		# The arriving screen's key is carried to it: L pressed as the chart came on was lost (Jon, Oct 20).
		# Why: docs/why/ZoomLadder.md#carried-keys
		if e is InputEventKey and _carry(e as InputEventKey):
			eat_c = true
		if eat_c and get_viewport() != null:
			get_viewport().set_input_as_handled()
		return
	# (but a click on the side bar while what it shows is changing lands on
	# nothing: what was under the pointer is not what is there once it ends)
	var eat := _side_eats(e)
	# NOT EATEN: the move ends where it was going and the press does what it does
	finish_now()
	if eat and get_viewport() != null:
		get_viewport().set_input_as_handled()


## Only presses are carried: a held key's release would come during the move and never be let go.
const CARRIED := {CHART: [&"chart_region"], MAP: [&"map_location"]}

## `k` is a key of the screen this move is going to (`CARRIED`): kept, and
## given to that screen once the move has landed. True if kept.
func _carry(k: InputEventKey) -> bool:
	for a: StringName in CARRIED.get(r_new, []):
		if k.is_action_pressed(a):
			var copy := k.duplicate() as InputEventKey
			# (deferred: given after the landing's own work, the camera at rest)
			var give := func() -> void:
				(func() -> void: Input.parse_input_event(copy)).call_deferred()
			if not when_landed(give):
				give.call()
			return true
	return false


## A screen's UI, `k` of the way gone (0 all there, 1 all away).
func _chrome(s: Control, k: float) -> void:
	if s != null and is_instance_valid(s) and s.has_method(&"ladder_chrome"):
		s.call(&"ladder_chrome", clampf(k, 0.0, 1.0))


## Run `cb` when the move under way lands (the camera at rest, its UI about to
## come up), or now if there is none. True if it waits.
static func when_landed(cb: Callable) -> bool:
	if busy() and not active._landed_done:
		active._landed.append(cb)
		return true
	return false


## The camera has landed: the held picture goes and the UI comes up, unless `then_ui` is false.
func _land(then_ui: bool = true) -> void:
	if phase != Phase.MOVE:
		return
	if is_instance_valid(new):
		new.call(&"ladder_cam", 0.0)
		new.call(&"ladder_cam_end")
		if _hull != null and new.has_method(&"ladder_hide_hull"):
			new.call(&"ladder_hide_hull", false)
		if _pan_view != null:
			new.position.x = _pan_x0
	if _pan_view != null and is_instance_valid(_pan_view):
		_pan_view.visible = false
	if _hull != null and is_instance_valid(_hull):
		_hull.visible = false
	_rect.visible = false
	if _black != null and is_instance_valid(_black):
		_black.color.a = 0.0
	phase = Phase.UI_IN
	_ui_u = 0.0
	_run_landed()
	if then_ui and (UI_IN_S <= 0.001 or chain != &"" or not is_instance_valid(new)
			or not new.has_method(&"ladder_chrome")):
		_end()


func _run_landed() -> void:
	if _landed_done:
		return
	_landed_done = true
	var cbs := _landed.duplicate()
	_landed.clear()
	for cb: Callable in cbs:
		if cb.is_valid():
			cb.call()


## Straight to the end of the move.
func finish_now() -> void:
	if _calm:
		_calm_finish_now()
		return
	_cut = true
	match phase:
		Phase.UI_OUT:
			_chrome(old, 1.0)
			phase = Phase.PRE
			finish_now()
		Phase.UI_IN, Phase.FADE_HOLD, Phase.FADE_IN:
			_end()
		Phase.FADE_OUT:
			phase = Phase.PRE
			_fire()
			_end()
		Phase.PRE:
			_fire()
			if phase == Phase.WAIT:
				_start_move()
			if phase == Phase.MOVE:
				_step_last()
				_end()
			elif phase == Phase.UI_IN:
				_end()
		Phase.WAIT:
			_start_move()
			_step_last()
			_end()
		Phase.MOVE:
			_step_last()
			_end()
		_:
			_end()


## The old screen's last frame, held; where its anchor and picture were.
func _hold() -> void:
	_fit()
	var vp := get_viewport()
	# (headless there is no picture to read, only the moves to run)
	var img: Image = null
	if vp != null and vp.get_texture() != null and DisplayServer.get_name() != "headless":
		img = vp.get_texture().get_image()
	if img == null or img.is_empty():
		img = Image.create(960, 540, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(img)
	_a_old = old.call(&"ladder_anchor", r_new, seam, design)
	# (3B's one motion: the speed the screen being left hands on, and where its
	# hull tiled)
	if old.has_method(&"ladder_track_speed"):
		_v_old = float(old.call(&"ladder_track_speed", UNDOCK_YARD_S * 0.7 if old is StationScreen else _pre_s))
	if old.has_method(&"ladder_hull_at"):
		_hull_at_old = old.call(&"ladder_hull_at")
	if old.has_method(&"ladder_hull_side"):
		_hull_side = old.call(&"ladder_hull_side")
	_pic = old.call(&"ladder_picture")
	if old.has_method(&"ladder_hull"):
		_hull_from = old.call(&"ladder_hull")
	if old.has_method(&"ladder_hull_texture"):
		_hull_tex = old.call(&"ladder_hull_texture")
	if old.has_method(&"ladder_plane"):
		_old_plane = old.call(&"ladder_plane")
	if old.has_method(&"ladder_world"):
		_old_world = old.call(&"ladder_world")
	_mat.set_shader_parameter(&"hole", Vector3.ZERO)
	if old.has_method(&"ladder_sun"):
		_old_sun = old.call(&"ladder_sun")
	if old.has_method(&"ladder_rest"):
		_rest_est = old.call(&"ladder_rest")
	if bool(_style.get("world", false)) and seam == 2 and r_new > r_old and old.has_method(&"ladder_give_world"):
		_given = old.call(&"ladder_give_world")
	_mat.set_shader_parameter(&"old_tex", _tex)
	_mat.set_shader_parameter(&"old_lin", _tex)
	_mat.set_shader_parameter(&"vp", Vector2(img.get_width(), img.get_height()))
	_mat.set_shader_parameter(&"pic", Vector4(_pic.position.x, _pic.position.y, _pic.size.x, _pic.size.y))
	_mat.set_shader_parameter(&"from_pt", _a_old)
	_mat.set_shader_parameter(&"to_pt", _a_old)
	_mat.set_shader_parameter(&"scl", Vector2.ONE)
	_mat.set_shader_parameter(&"mode", 0)
	_mat.set_shader_parameter(&"t", 0.0)
	_mat.set_shader_parameter(&"chrome_t", 0.0)
	_mat.set_shader_parameter(&"block", 1.0)
	_rect.visible = true
	_u = 0.0
	_waited = 0.0
	phase = Phase.WAIT
	_style = _style_for()
	_side_begin()
	# On the one curve the swap's own frame moves too, as the clock already ran: no stopped frame.
	if bool(_style.get("curve", false)) and not measure_hold and _had_pre:
		var ew := _curve_e()
		_mat.set_shader_parameter(&"scl", Vector2.ONE * exp(_l_move * ew))
		if _rest_est != Vector2.INF:
			_mat.set_shader_parameter(&"to_pt", _a_old.lerp(_rest_est, ew))


## The side bar swaps in place instead of going blank first (Jon, Oct 13), in the look picked.
## Why: docs/why/ZoomLadder.md#side-bar-swap
func _side_begin() -> void:
	# (the rest of the move from here: the one curve's remaining time, or the
	# move's own length)
	var rem := _move_s
	if bool(_style.get("curve", false)) and _had_pre:
		rem = maxf(_T - _tau, 0.0)
	var so := side_of(old)
	if so != null and so.is_visible_in_tree():
		_side_old = so.get_global_rect()
	var bo := bar_of(old)
	if bo != null and bo.is_visible_in_tree():
		_bar_old = bo.get_global_rect()
	# INTO LOCAL: no decode; the chrome being left slides off as the camera
	# lands (`_chrome_off`)
	if (so != null or bo != null) and side_of(new) == null and bar_of(new) == null:
		_chrome_off(_tex, old)
		return
	side_swap = _region_swap(so, side_of(new), &"side", rem, false)
	# THE TOOLBAR TOO, the same way (Jon: "these buttons"): the row along the
	# top of the picture, decoded left to right
	bar_swap = _region_swap(bo, bar_of(new), &"side2", rem, true)
	# OUT OF LOCAL: the chrome has landed; its contents decode in on it, the
	# band holding until nothing of LOCAL's held picture is left under it
	if _slide_way == &"on":
		if bar_swap != null:
			bar_swap.banded = true
			bar_swap.held = Callable()
		if side_swap != null:
			# (what it crosses from is the empty column that has just landed,
			# whole in the held frame)
			side_swap.held = func() -> float: return 1.0
		_land_chrome_on()


## A DIVE OUT OF LOCAL has come up from black under its chrome, landed: the
## contents decode in on it now.
func _decode_after_dive() -> void:
	_show_chrome()
	side_swap = _region_swap(null, side_of(new), &"side", 0.0, false)
	bar_swap = _region_swap(null, bar_of(new), &"side2", 0.0, true)
	if bar_swap != null:
		bar_swap.banded = true
		bar_swap.held = Callable()
	if side_swap != null:
		side_swap.held = Callable()
	# (the chrome stands until each decode is drawing: then it is the same)
	for p: Variant in slides:
		if is_instance_valid(p) and side_swap != null:
			var wp: WeakRef = weakref(p)
			side_swap.laid.connect(func(_r: Rect2) -> void:
				var o: Variant = wp.get_ref()
				if o != null:
					(o as ChromeSlide).finish())
	if band != null and is_instance_valid(band):
		var wb: WeakRef = weakref(band)
		band.driven = false
		band._u = 1.0
		if bar_swap != null:
			bar_swap.laid.connect(func(_r: Rect2) -> void:
				var o: Variant = wb.get_ref()
				if o != null:
					(o as SideBand).finish())
			move_child(band, bar_swap.get_index() - 1)
	_slide_way = &"done"


## Out of LOCAL, landed: the held frame covers the panel till its decode is up; the band goes last.
func _land_chrome_on() -> void:
	for p: Variant in slides:
		if is_instance_valid(p):
			(p as ChromeSlide).finish()
	slides.clear()
	if band != null and is_instance_valid(band):
		band.driven = false
		band._u = 1.0
		band.drive(1.0)
		band.wait = func() -> bool: return held_alpha() > 0.01
		if bar_swap != null and is_instance_valid(bar_swap):
			move_child(band, bar_swap.get_index() - 1)
	_slide_way = &""


## One region's swap, from `so` (the old screen's, or null) to `sn` (the new
## one's, or null), the held picture leaving its rect alone through `uniform`.
func _region_swap(so: Control, sn: Control, uniform: StringName, rem: float, across: bool) -> SideSwap:
	if so == null and sn == null:
		return null
	var sw := SideSwap.new()
	sw.visible = false
	sw.across = across
	# A fresh screen copy, as a sky behind the screens can read it before any panel is drawn.
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(bb)
	add_child(sw)
	# OVER THE HELD PICTURE, which leaves the rect to it: what was there is in
	# the swap's own hands from here
	move_child(bb, _rect.get_index() + 1)
	move_child(sw, bb.get_index() + 1)
	sw.laid.connect(func(r: Rect2) -> void:
		_mat.set_shader_parameter(uniform, Vector4(r.position.x, r.position.y, r.size.x, r.size.y)))
	if so == null:
		# Where LOCAL had no panel its picture goes on the
		# held picture's curve, never a still of its sky.
		sw.held = held_alpha
	sw.setup(so, sn, _tex, side_look(), 1.0 if r_new > r_old else -1.0, rem)
	return sw


## How much of the held picture's standing copy is drawn this frame (the
## picture as it was, where it was): its shader's own sum, soft or dithered.
func held_alpha() -> float:
	if not _rect.visible:
		return 0.0
	if _calm:
		return _calm_a
	var tv: Variant = _mat.get_shader_parameter(&"t")
	var t := float(tv) if tv != null else 0.0
	var sv: Variant = _mat.get_shader_parameter(&"soft")
	if sv != null and float(sv) > 0.5:
		return 1.0 - smoothstep(0.0, 0.2, t)
	var mv: Variant = _mat.get_shader_parameter(&"mode")
	if mv != null and int(mv) == 3:
		return 1.0 if t < 0.5 else 0.0
	var cv: Variant = _mat.get_shader_parameter(&"chrome_t")
	return 1.0 - (float(cv) if cv != null else 0.0)


## A screen's side bar, the panel down its right edge (`ladder_side`), or null.
static func side_of(s: Control) -> Control:
	if s == null or not is_instance_valid(s) or not s.has_method(&"ladder_side"):
		return null
	return s.call(&"ladder_side") as Control


## A screen's toolbar, the row along the top of its picture (`ladder_bar`), or
## null.
static func bar_of(s: Control) -> Control:
	if s == null or not is_instance_valid(s) or not s.has_method(&"ladder_bar"):
		return null
	return s.call(&"ladder_bar") as Control


## The decodes under way: the side bar's, the toolbar's and the KEY band's.
func _swaps() -> Array[Variant]:
	return [side_swap, bar_swap, foot_swap]


## Whether a press lands on a side bar still changing; the move ends and the press lands on nothing.
func _side_eats(e: InputEvent) -> bool:
	if not (e is InputEventMouseButton):
		return false
	var p := (e as InputEventMouseButton).position
	# (a piece of chrome on the move takes no click until it has landed)
	for pc: Variant in ChromeSlide.live:
		if is_instance_valid(pc) and (pc as ChromeSlide).at().intersection((pc as ChromeSlide).clip).has_point(p):
			return true
	var pre := phase == Phase.UI_OUT or phase == Phase.PRE or phase == Phase.PRE_DONE or phase == Phase.WAIT
	for pair in [[side_swap, _side_old], [bar_swap, _bar_old]]:
		var sw: Variant = pair[0]
		var was: Rect2 = pair[1]
		if sw != null and is_instance_valid(sw) and not (sw as SideSwap).done:
			if (sw as SideSwap).blocks(p) or (not (sw as SideSwap).rect().has_area() and was.has_point(p)):
				return true
		elif pre and was.has_point(p):
			return true
	return false


## What the move looks like: the dither's mode and how the held picture travels.
func _style_for() -> Dictionary:
	var inward := r_new > r_old
	var s := {"mode": 0, "spread": 0.7 if inward else -0.7, "extra": 1.0, "reach": 520.0,
		"axis": Vector2.ONE, "chrome": 0.45, "block": 0.0, "plane": false, "world": false, "hull": false}
	if seam == 0:
		s.extra = 3.0 if inward else 0.3
		# Tab from the chart leaves by how much is kept, not a dither: the 4x4 checker read as noise.
		# Why: docs/why/ZoomLadder.md#two-distances-in-one
		s.soft = true
		s.sharp = true
		s.feather = 48.0
	# a picture going small loses its own edge first (`edge`), and is taken on
	# the camera's own curve, fast at first
	s["edge"] = 0.0 if inward else 1.8
	s["fast"] = not inward and _had_pre
	s.reach = 420.0
	match "%d%s" % [seam, design]:
		"1A":
			# The held chart has a hole the size of the live sun, so the star icon becomes the sun (Jon).
			# Why: docs/why/ZoomLadder.md#star-handoff
			s.curve = true
			s.soft = true
			s.sharp = true
			s.sun = true
			s.pre_s = 0.4
			s.move_s = 0.7
			s.reach = 340.0
			s.t_from = 0.0
			s.t_to = 0.9
			if inward:
				s.spread = 0.8
			else:
				s.spread = -0.9
				s.extra = 0.9
				# (the map's frame made small over the chart: never a card
				# with a hard edge, even on its first frames)
				s.feather = 64.0
		"1B":
			s.mode = 2
			s.extra = 3.0 if inward else 0.6
		"1C", "3C":
			s.mode = 3
			s.block = 12.0
			s.extra = 1.6 if inward else 0.7
		"2B":
			s.plane = true
			s.spread = -0.8
			s.axis = Vector2(40.0, 1.0)
			s.reach = 260.0
		"2C":
			# One curve with the same speed both sides of the handoff, sampled between pixels (Jon).
			# Why: docs/why/ZoomLadder.md#smoothed-handoff
			s.world = true
			s.curve = true
			s.soft = true
			s.sharp = true
			s.spread = -0.75
			s.edge = 0.0
			s.reach = 380.0
			s.pre_s = 0.7
			s.move_s = 0.45
			s.t_from = 0.05
			s.t_to = 0.95
			s.wait_long = true
		"3A":
			if inward:
				s.mode = 1
				s.axis = Vector2(1.0, 0.45)
				s.reach = 900.0
				s.extra = 2.5
				s.rim = 8.0
			else:
				s.spread = -0.85
				s.extra = 0.6
		"3B", "3D":
			# LOCAL draws the station's side; the ship flies in and the camera follows. Undocking runs it back.
			# Why: docs/why/ZoomLadder.md#into-the-hangar
			s.soft = true
			s.spread = 0.8 if inward else -0.8
			s.reach = 520.0
			s.extra = 1.0
			s.edge = 0.0
			s.pin = true
			if design == "B":
				# The arrival: a linear approach on LOCAL, then a
				# sideways pan into the yard (Jon: let it breathe).
				s.pan = true
				s.wait_long = true
				s.fade = seam3_fade()
				var f := String(s.fade) == "F"
				s.pre_s = dock_approach_s() if inward else UNDOCK_YARD_S + (YARD_BEAT_S + YARD_FADE_S if f else 0.0)
				# (undocking, LOCAL's part is the dock's ENTER run back)
				if f:
					s.move_s = YARD_FADE_S + YARD_BEAT_S + DOCK_YARD_S if inward else DOCK_ENTER_S
				else:
					s.move_s = DOCK_PAN_S + (DOCK_YARD_S if inward else DOCK_ENTER_S)
			else:
				s.pre_s = 0.75 if inward else 0.85
				s.move_s = 1.4 if inward else 0.8
				s.t_from = 0.0
				s.t_to = 0.4 if inward else 0.6
			# (no eaten edge: the hangar and the sky cross by the soft edge alone;
			# and the held picture stays where it was, the hull being what travels)
			s.edge = 0.0
			s.pin = true
	# EACH SEAM'S LENGTH IS ITS DIAL (`SEAM1_S`, `SEAM2_S`, `DIVE_S`): the
	# design's own split between the two halves kept, the whole stretched to it
	var total := 0.0
	match seam:
		0: total = DIVE_S
		1: total = SEAM1_S
		2: total = SEAM2_S
	# Soft moves already feather the held edge; the eaten edge on top put a 40 px dark band round it.
	# Why: docs/why/ZoomLadder.md#soft-edge
	if bool(s.get("soft", false)) and (seam == 0 or seam == 1):
		s.edge = 0.0
	if total > 0.0:
		var p := float(s.get("pre_s", PRE_S))
		var m := float(s.get("move_s", MOVE_S))
		var f := total / maxf(p + m, 0.01)
		s.pre_s = p * f
		s.move_s = m * f
		s.total = total
	return s


# ------------------------------------------------------------------ the pan (3B)

## The camera slides past the station's hull to the yard, which has no station in it (Jon).
## Why: docs/why/ZoomLadder.md#pan-through-station
var _pan_view: _PanView = null
var _pan_x0 := 0.0
var _pan_vr := 0.0
var _hull_at_old := Vector2.INF
## the station's side the hull is ([side, its parallax]), from LOCAL
var _hull_side: Array = []


class _PanView extends Control:
	var tex: Texture2D
	var src := Rect2()
	var held_x := 0.0
	var slab_x := 0.0
	var slab_w := 520.0
	var row_y := 270.0
	## where the hull's panels tile (this view's px), as LOCAL's drum tiles them
	var tile_x0 := 0.0
	var show_held := true
	## the station's side ([] the Drum's) and its layers' parallax
	var side: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		if tex != null and show_held:
			draw_texture_rect_region(tex, Rect2(Vector2(roundf(held_x), 0), src.size), src)
		if side.is_empty():
			StationFace.draw_hull(self, Rect2(roundf(slab_x), 0, slab_w, size.y), roundf(tile_x0), row_y)
		else:
			StationFace.draw_hull(self, Rect2(roundf(slab_x), 0, slab_w, size.y), roundf(tile_x0), row_y,
				Color(1, 1, 1), StationFace.HULL_K, side[0], side[1])


## the move's own clock where the pre-roll left it (s), and the speeds the two
## screens hand on at the seam (screen px a second)
var _pan_t0 := 0.0
var _v_old := 0.0
var _v_new := 0.0
var _hull_x0 := 0.0
var _black: ColorRect = null


## The dip to black (F) or the pan's shadow (PF): `a` of black over the screens.
func _black_at(a: float) -> void:
	if _black == null:
		if a <= 0.0:
			return
		_fit()
		_black = ColorRect.new()
		_black.color = Color(0, 0, 0, 0)
		_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_black)
	# (side to side the whole window: the yard's hall run on into the elevator's
	# column reaches past this box's left edge, into the margin)
	var vw := get_viewport_rect().size.x
	var gx := get_global_rect().position.x
	_black.position = Vector2(-gx, 0.0)
	_black.size = Vector2(maxf(vw, gx + size.x), size.y)
	_black.color.a = clampf(a, 0.0, 1.0)
	move_child(_black, -1)


func _start_pan() -> void:
	new.call(&"ladder_cam_begin", r_old, seam, design)
	new.call(&"ladder_cam", 1.0)
	_fit()
	_rect.visible = false
	_pan_x0 = new.position.x
	var inward := r_new > r_old
	# (the hull starts at LOCAL's picture's right edge, over the strip beside it)
	var pic: Rect2 = _pic if inward else new.call(&"ladder_picture")
	_pan_vr = clampf(pic.end.x - position.x, 0.0, size.x)
	# the speeds at the seam: what LOCAL's approach (or the yard's flight out)
	# ended on, and what the yard's flight in (or LOCAL's flight out) starts on
	var rest_s := DOCK_YARD_S if inward else DOCK_ENTER_S
	if new.has_method(&"ladder_track_speed"):
		_v_new = float(new.call(&"ladder_track_speed", rest_s))
	# the hull's tiling, carried on from LOCAL's drum
	var at: Vector2 = Vector2.INF
	var local: Control = new if not inward else null
	var hs: Array = _hull_side
	if local != null and local.has_method(&"ladder_hull_at"):
		at = local.call(&"ladder_hull_at")
		if local.has_method(&"ladder_hull_side"):
			hs = local.call(&"ladder_hull_side")
	elif inward:
		at = _hull_at_old
	_pan_view = _PanView.new()
	_pan_view.tex = _tex
	_pan_view.src = Rect2(position, size)
	_pan_view.size = size
	_pan_view.slab_w = PAN_HULL_W
	_pan_view.side = hs
	_pan_view.row_y = roundf(size.y * 0.5) if at == Vector2.INF else roundf(at.y - position.y)
	_hull_x0 = (_pan_vr if at == Vector2.INF else at.x - position.x)
	add_child(_pan_view)
	phase = Phase.MOVE
	# (on from where the pre-roll's clock left off: no frame stands still)
	_u = maxf(_pan_t0, 0.0) + _dt(get_process_delta_time())
	_step_pan(_u)
	# (and again once the screen just put in place has laid itself out -- a
	# container sorting its children puts the elevator back in its place)
	_step_pan.call_deferred(_u)


## THE ONE MOTION AFTER THE SEAM (3B): F's way up from black, or P's pan, then
## the yard's flight in (docking) or LOCAL's flight out (undocking).
func _step_pan(t: float) -> void:
	if not is_instance_valid(new) or _pan_view == null:
		return
	var inward := r_new > r_old
	if String(_style.get("fade", "")) == "F":
		# F: no pan. The empty yard rises from black,
		# then the ship flies in; undocking runs it back.
		_pan_view.visible = false
		new.position.x = _pan_x0
		if inward:
			_black_at(1.0 - ease_curve(clampf(t / YARD_FADE_S, 0.0, 1.0)))
			# (coming in at the speed LOCAL's approach ended on, within reason)
			var lad: Variant = new.get("_lad")
			var off := maxf(float((lad as Dictionary).get("off", 1.0)) if lad is Dictionary else 1.0, 1.0)
			var m0 := clampf(_v_old * DOCK_YARD_S / off, 1.5, 3.0)
			var rest := clampf((t - YARD_FADE_S - YARD_BEAT_S) / DOCK_YARD_S, 0.0, 1.0)
			new.call(&"ladder_cam", 1.0 - herm(rest, m0, 0.0))
			# (and its engines and their sound on the same clock: the roar, the
			# coughs, nothing, the clamps -- `StationScreen.ladder_yard_t`)
			if new.has_method(&"ladder_yard_t"):
				new.call(&"ladder_yard_t", t - YARD_FADE_S - YARD_BEAT_S, DOCK_YARD_S)
		else:
			var up := float(new.call(&"ladder_up_s")) if new.has_method(&"ladder_up_s") else -1.0
			if up <= 0.0:
				up = LOCAL_FADE_S
			_black_at(1.0 - ease_curve(clampf(t / up, 0.0, 1.0)))
			new.call(&"ladder_cam", 1.0 - clampf(t / maxf(_move_s, 0.001), 0.0, 1.0))
		return
	var P := DOCK_PAN_S
	var W := _pan_vr if _pan_vr > 0.0 else size.x
	var S := PAN_HULL_W
	var D := W + S
	# P: the pan, from the speed handed on to the speed handed over
	var hu := herm(t / P, _v_old * P / D, _v_new * P / D)
	var X := D * (hu if inward else 1.0 - hu)
	var held := -X if inward else W + S - X
	var live := W + S - X if inward else -X
	new.position.x = _pan_x0 + roundf(live)
	_pan_view.held_x = held
	_pan_view.slab_x = W - X
	_pan_view.tile_x0 = _hull_x0 - X
	_pan_view.visible = t < P
	_pan_view.queue_redraw()
	if t >= P:
		new.position.x = _pan_x0
	var rest2 := clampf((t - P) / maxf(_move_s - P, 0.001), 0.0, 1.0)
	if inward:
		new.call(&"ladder_cam", 1.0 - herm(rest2, YARD_M_IN, 0.0))
		if new.has_method(&"ladder_yard_t"):
			new.call(&"ladder_yard_t", t - P, _move_s - P)
	else:
		new.call(&"ladder_cam", 1.0 - rest2)


const YARD_M_IN := 2.0


## The move's last frame, whichever kind of move it is.
func _step_last() -> void:
	if bool(_style.get("pan", false)):
		_step_pan(_move_s)
	else:
		_step(1.0)


func _start_move() -> void:
	if phase != Phase.WAIT:
		return
	_chrome(new, 1.0)

	if bool(_style.get("pan", false)):
		_start_pan()
		return
	# The arriving camera starts anchored on the held picture, so both move as one from frame one.
	_met = new.has_method(&"ladder_meet")
	if _met:
		new.call(&"ladder_meet", _a_old, _old_world)
	new.call(&"ladder_cam_begin", r_old, seam, design)
	new.call(&"ladder_cam", 1.0)
	# THE WORLD ITSELF HANDED OVER (2C): the held picture leaves a hole where its
	# world is, and LOCAL draws the map's own world there
	if not _given.is_empty() and new.has_method(&"ladder_take_world"):
		var g := _given.duplicate()
		g["freeze"] = measure_hold
		_taken = bool(new.call(&"ladder_take_world", g))
		if _taken and not _old_world.is_empty():
			var c: Vector2 = _old_world.c
			# (with the world's lit rim of air, which reaches past its disc)
			_mat.set_shader_parameter(&"hole", Vector3(c.x, c.y, float(_old_world.r) * 1.22 + 2.0))
			new.call(&"ladder_cam", 1.0)
	if not _taken and not _given.is_empty() and is_instance_valid(_given.view):
		(_given.view as Node).queue_free()
	_given = {}
	_s0 = maxf(float(new.call(&"ladder_scale")), 0.0001)
	_mat.set_shader_parameter(&"mode", int(_style.mode))
	_mat.set_shader_parameter(&"spread", float(_style.spread))
	_mat.set_shader_parameter(&"reach", float(_style.reach))
	_mat.set_shader_parameter(&"axis", _style.axis)
	_mat.set_shader_parameter(&"rim", float(_style.get("rim", 10.0)))
	_mat.set_shader_parameter(&"edge", float(_style.get("edge", 0.0)))
	_mat.set_shader_parameter(&"soft", 1.0 if bool(_style.get("soft", false)) else 0.0)
	_mat.set_shader_parameter(&"sharp", 1.0 if bool(_style.get("sharp", false)) else 0.0)
	_mat.set_shader_parameter(&"feather", float(_style.get("feather", 0.0)))
	# (the soft handoff's standing copy of the old picture leaves out the thing
	# the move carries: the world you orbit, or your star)
	var fh := Vector3.ZERO
	if not _old_world.is_empty():
		fh = Vector3((_old_world.c as Vector2).x, (_old_world.c as Vector2).y, float(_old_world.r) * 1.35 + 3.0)
	elif not _old_sun.is_empty():
		fh = Vector3((_old_sun.c as Vector2).x, (_old_sun.c as Vector2).y, float(_old_sun.r) * 1.35 + 3.0)
	elif r_old == CHART:
		# (the chart's mark for your star)
		fh = Vector3(_a_old.x, _a_old.y, 14.0)
	_mat.set_shader_parameter(&"focus_hole", fh)
	_mat.set_shader_parameter(&"disc_r0", DISC_PX)
	_mat.set_shader_parameter(&"focus_r", maxf((fh.z - 3.0) / 1.35, 0.0) if fh.z > 0.0 else 0.0)

	if bool(_style.hull) and new.has_method(&"ladder_hull"):
		_hull_to = new.call(&"ladder_hull")
		var art: Texture2D = new.call(&"ladder_hull_texture") if new.has_method(&"ladder_hull_texture") else null
		if art == null:
			art = _hull_tex
		if art != null and _hull_from.size.x > 1.0 and _hull_to.size.x > 1.0:
			_hull = TextureRect.new()
			_hull.texture = art
			_hull.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_hull.stretch_mode = TextureRect.STRETCH_SCALE
			_hull.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_hull)
			new.call(&"ladder_hide_hull", true)
	phase = Phase.MOVE
	_u = 0.0
	# Out of a pre-roll the first frame is a frame on, as a dive's swap used to stand still a frame.
	if _had_pre and not measure_hold and not bool(_style.get("curve", false)):
		_u = _dt(get_process_delta_time()) / maxf(_move_s, 0.001)
	_step(0.0 if measure_hold else (_curve_e() if bool(_style.get("curve", false)) else _u))


## The move at progress `u`.
func _step(u: float) -> void:
	if not is_instance_valid(new):
		return
	# out of a pre-roll, eased OUT (it arrives at speed); from a standstill, both
	var e := 1.0 - (1.0 - clampf(u, 0.0, 1.0)) * (1.0 - clampf(u, 0.0, 1.0)) if _had_pre else ease_curve(u)
	# (on the one curve, `u` is already where the curve is)
	if bool(_style.get("curve", false)):
		e = clampf(u, 0.0, 1.0)
	new.call(&"ladder_cam", 1.0 - e)
	_fit()
	var a_new: Vector2 = new.call(&"ladder_anchor", r_old, seam, design)
	var ratio := float(new.call(&"ladder_scale")) / _s0
	var extra := lerpf(1.0, float(_style.extra), e) if float(_style.extra) >= 1.0 \
		else pow(float(_style.extra), e)
	var scl := Vector2.ONE * ratio * extra
	var from := _a_old
	var to := a_new if _met else _a_old.lerp(a_new, e)
	if bool(_style.get("pin", false)):
		to = _a_old
	# 1A: the hole is the sun, so the live sun shows
	# through the held chart where the star is drawn.
	if bool(_style.get("sun", false)):
		var sun_r := 0.0
		if r_new > r_old and new.has_method(&"ladder_sun"):
			sun_r = float((new.call(&"ladder_sun") as Dictionary).get("r", 0.0)) / maxf(scl.x, 0.0001)
		elif r_new < r_old:
			sun_r = float(_old_sun.get("r", 0.0))
		if sun_r > 0.0:
			_mat.set_shader_parameter(&"hole", Vector3(_a_old.x, _a_old.y, sun_r + 0.5))
	if bool(_style.plane) and new.has_method(&"ladder_plane"):
		# THE MAP LAID DOWN INTO LOCAL'S PLANE: the map's star onto LOCAL's star, the
		# map's slant (0.38) pressed flat to LOCAL's (0.07), its scale to LOCAL's
		var pl_new: Dictionary = new.call(&"ladder_plane")
		var pl_old: Dictionary = _old_plane
		if not pl_old.is_empty() and not pl_new.is_empty():
			var inward := r_new > r_old
			var a: Dictionary = pl_old if inward else pl_new
			var b: Dictionary = pl_new if inward else pl_old
			var sx: float = float(b.s) / maxf(float(a.s), 0.0001)
			var sy: float = float(b.s) * float(b.tilt) / maxf(float(a.s) * float(a.tilt), 0.0001)
			var target := Vector2(sx, sy) if inward else Vector2(1.0 / sx, 1.0 / sy)
			from = pl_old.o
			to = (pl_old.o as Vector2).lerp(pl_new.o, e)
			scl = Vector2(pow(target.x, e), pow(target.y, e))
			_mat.set_shader_parameter(&"c", to)
	elif bool(_style.world) and not _met:
		var w_new: Dictionary = new.call(&"ladder_world") if new.has_method(&"ladder_world") else {}
		var w_old: Dictionary = _old_world
		if not w_old.is_empty() and not w_new.is_empty():
			# THE WORLD YOU ORBIT, carried: its disc in the held picture onto its
			# disc in the live one, sized to it
			var k := float(w_new.r) / maxf(float(w_old.r), 0.5)
			from = w_old.c
			to = (w_old.c as Vector2).lerp(w_new.c, e)
			scl = Vector2.ONE * pow(k, e)
	_mat.set_shader_parameter(&"from_pt", from)
	_mat.set_shader_parameter(&"to_pt", to)
	_mat.set_shader_parameter(&"scl", scl)
	# 2C out: keep the map's own world under the held picture, or a small disc showed two worlds.
	if bool(_style.get("world", false)) and r_new < r_old and new.has_method(&"ladder_world"):
		var wn: Dictionary = new.call(&"ladder_world")
		if not wn.is_empty():
			_mat.set_shader_parameter(&"cover", Vector3((wn.c as Vector2).x, (wn.c as Vector2).y, float(wn.r) * 1.4 + 6.0))
	if not bool(_style.plane):
		_mat.set_shader_parameter(&"c", to)
	# the held picture goes on a slightly faster curve than the camera, so the
	# arriving picture is whole well before the camera settles
	var tm := _ease_out(clampf(u / 0.85, 0.0, 1.0)) if bool(_style.get("fast", false)) 		else ease_curve(clampf(u / 0.85, 0.0, 1.0))
	if _style.has("t_from"):
		# (the held picture goes over its own stretch of the move)
		tm = ease_curve(clampf((u - float(_style.t_from)) / maxf(float(_style.t_to) - float(_style.t_from), 0.001), 0.0, 1.0))
	_mat.set_shader_parameter(&"t", tm)
	_mat.set_shader_parameter(&"chrome_t", ease_curve(clampf(u / float(_style.chrome), 0.0, 1.0)))
	if int(_style.mode) == 3:
		var bmax := float(_style.block)
		var tri := 1.0 - absf(u * 2.0 - 1.0)
		var b := roundf(lerpf(1.0, bmax, tri) / 2.0) * 2.0
		if u >= 1.0:
			b = 1.0
		_mat.set_shader_parameter(&"block", maxf(b, 1.0))
		_mat.set_shader_parameter(&"t", u)
	if _hull != null:
		var r := Rect2(_hull_from.position.lerp(_hull_to.position, e), _hull_from.size.lerp(_hull_to.size, e))
		_hull.position = (r.position - position).round()
		_hull.size = r.size.round()


## Godot leaves items under about 0.007 undrawn, so 0.008: drawn and warmed for two levels at most.
## Why: docs/why/ZoomLadder.md#prebuilt-chart-opacity
const PREBUILT_A := 0.008


## The map, built ahead for the move under way (`preroll`), for the Router to
## show instead of building one (`take_prebuilt`).
static var prebuilt: Control = null


## The screen built ahead for the move under way (`NavField` feeds on its LOCAL sky), or null.
static func prebuilt_screen() -> Control:
	return prebuilt if prebuilt != null and is_instance_valid(prebuilt) else null


## The map (or the chart) built ahead, if it is the kind asked for and ready; the Router takes it.
static func take_prebuilt(kind: int) -> Control:
	var pm := prebuilt
	if pm == null or not is_instance_valid(pm) or rank_of(pm) != kind:
		return null
	prebuilt = null
	# (LOCAL: only if nothing has happened since that it would have played)
	if pm is SectorScreen and (not _local_quiet() or (pm as SectorScreen)._events == null
			or (pm as SectorScreen)._events.node != Run.node_at()):
		_release(pm)
		return null
	if pm is StationScreen and int(pm.get_meta(&"ladder_at", -1)) != Run.at:
		_release(pm)
		return null
	if pm is StationScreen:
		pm.process_mode = Node.PROCESS_MODE_INHERIT
	if pm is SystemMapScreen and ((pm as SystemMapScreen).view == null or (pm as SystemMapScreen).view.node != Run.node_at()
			or not (pm as SystemMapScreen).ladder_ready()):
		_release(pm)
		return null
	if pm.get_parent() != null:
		pm.get_parent().remove_child(pm)
	pm.modulate.a = 1.0
	return pm


## The map's DOCK goes on into the hangar from LOCAL; if that door does not open, LOCAL's UI returns.
func _chain_chrome() -> void:
	if chain == &"station" and new is SectorScreen and is_instance_valid(new):
		_chrome(new, 1.0)


static func _chain_go(s: Control) -> void:
	if not is_instance_valid(s):
		chrome_hidden = null
		return
	Router.show_station()
	# (a dock that did not start after all: your ship back where it is)
	if not (busy() and active.old == s) and is_instance_valid(s) and s.has_method(&"dock_unhide"):
		s.call(&"dock_unhide")
	if not (busy() and active.old == s) and is_instance_valid(s) and Router.current == s:
		if s.has_method(&"ladder_chrome"):
			s.call(&"ladder_chrome", 0.0)
	if chrome_hidden == s and not (busy() and active.old == s):
		chrome_hidden = null


## Whether LOCAL built now would play nothing as it is built, which `preroll` needs.
static func _local_quiet(undocking: bool = false, event_ok: bool = false) -> bool:
	var ev_ok := LocalEventDrawer.pending.is_empty() or (event_ok and LocalEventDrawer.pending.size() >= 2
		and int(LocalEventDrawer.pending[0]) == Run.at)
	return (undocking or not Router.docked) and not Router.in_combat() and Router._post_depart < 0 \
		and not Router._post_arrive and ev_ok \
		and (undocking or SectorScreen._approached_at == Run.at)



## A screen built ahead and not shown, freed; an event that LOCAL was holding
## for the move to land goes back to wait for the next LOCAL.
static func _release(pm: Control) -> void:
	if pm is SectorScreen:
		var ev: LocalEventDrawer = (pm as SectorScreen)._events
		if ev != null and is_instance_valid(ev) and not ev.deferred.is_empty():
			LocalEventDrawer.pending = ev.deferred.duplicate()
			ev.deferred = []
	pm.queue_free()


static func drop_prebuilt() -> void:
	if prebuilt != null and is_instance_valid(prebuilt):
		_release(prebuilt)
	prebuilt = null


## A move that goes on into the next when it lands (the map's DOCK: down to LOCAL, then into the hangar).
static var chain := &""


func _end() -> void:
	# (a map built ahead and never shown goes)
	if phase != Phase.MOVE and phase != Phase.UI_IN:
		drop_prebuilt()
	# (ended in the middle of the move: landed at once, no UI beat)
	if phase == Phase.MOVE:
		_land(false)
	var chained := false
	if chain == &"station" and (phase == Phase.UI_IN or (_fade and phase == Phase.FADE_IN)) and new is SectorScreen and is_instance_valid(new):
		chain = &""
		chained = true
		# (LOCAL's UI stays away: the hangar is the next move, at once)
		chrome_hidden = new
		_chain_go.call_deferred(new)
	if not _given.is_empty() and is_instance_valid(_given.view) and (_given.view as Node).get_parent() == null:
		(_given.view as Node).queue_free()
	_given = {}
	if (phase == Phase.PRE or phase == Phase.UI_OUT) and is_instance_valid(old) and Router.current == old and _had_pre:
		old.call(&"ladder_cam", 0.0)
		old.call(&"ladder_cam_end")
	# THE UI BACK, whatever stopped the move: on the screen left if it is still
	# up (a door that refused, a move cut short), on the one arrived at
	if is_instance_valid(old) and Router.current == old:
		_chrome(old, 0.0)
	if phase == Phase.UI_IN and not chained:
		_chrome(new, 0.0)
	_run_landed()
	if _pan_view != null and is_instance_valid(new):
		new.position.x = _pan_x0
	if _black != null and is_instance_valid(_black):
		_black.color.a = 0.0
	if active == self:
		active = null
		_hud_refresh()
	phase = Phase.PRE_DONE
	_rect.visible = false
	# The decode runs on past a shorter move (Jon: not sped up); a press or a key ends it.
	var going: Array = []
	# (the band first, so it stays under what decodes on it; and the chrome that waits for a decode to be drawing)
	for p: Variant in slides:
		if is_instance_valid(p) and not (p as ChromeSlide).done:
			if _cut or get_parent() == null or _slide_way != &"done":
				(p as ChromeSlide).finish()
			else:
				var pgp := (p as ChromeSlide).global_position
				remove_child(p)
				get_parent().add_child(p)
				(p as ChromeSlide).global_position = pgp
	if is_instance_valid(band) and not band.done:
		if _cut or get_parent() == null or not (band.closing or _slide_way == &"done"):
			band.finish()
		else:
			var bgp := band.global_position
			remove_child(band)
			get_parent().add_child(band)
			band.global_position = bgp
	going.append_array(_swaps().filter(func(sw: Variant) -> bool: return is_instance_valid(sw)))
	for sw: SideSwap in going:
		if sw.done:
			continue
		if _cut or get_parent() == null:
			sw.finish()
			continue
		var bb := BackBufferCopy.new()
		bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		var gp := sw.global_position
		remove_child(sw)
		get_parent().add_child(bb)
		get_parent().add_child(sw)
		sw.global_position = gp
		sw.tree_exited.connect(bb.queue_free)
	queue_free()
	# (the run written now the move has landed: `Router._swap` held it back)
	if save_after:
		save_after = false
		Router.autosave()


# ------------------------------------------------------------------ the calm move
# Jon picked A (Oct 17) after the nav audit: every
# hop is one motion, the ship on one straight line.
# Why: docs/why/ZoomLadder.md#calm-move-audit

const CALM_SHADER := preload("res://shaders/calm_ladder.gdshader")
## How much bigger the nearer screen draws the same thing, by the two distances a hop joins.
const CALM_RATIO := {"LM": 4.0, "MC": 6.0, "LC": 12.0}
## Where on the camera's curve the screens change hands, and how long the held picture fades.
const CALM_HANDOFF := 0.45
const CALM_DISSOLVE_S := 0.3
## a press mid-move: whatever is left of the move in about this long
const CALM_HURRY_S := 0.25

var _calm := false
## (set while `capture` ends a move for a screen swapped in by another door)
static var _capturing := false
var _calm_firing := false
var _calm_t := 0.0
var _calm_rate := 1.0
var _calm_hurried := false
var _calm_a := 1.0
var _calm_e := 0.0
var _calm_e_drawn := 0.0
var _calm_e_h := -1.0
## the crossfade's own clock (the move's, a press's hurry and all), from the moment the screen arriving took its camera
var _calm_diss := 0.0
var _calm_swap_frame := 0
var _calm_L := 0.0
var _calm_p0 := Vector2.ZERO
var _calm_p1 := Vector2.ZERO
var _calm_ph := Vector2.ZERO
var _calm_new_begun := false
var _calm_dt := 0.0
var _calm_q: Callable
## the side bar and toolbar of the screen being left, as the held picture has
## them, standing still over their places until the camera lands
var _calm_covers: Array = []
## THE FIELD UNDER THE MOVE (`NavField`), as it stood when the picture was held:
## what is keyed out of the held picture (`calm_ladder.gdshader`)
var _calm_field: Texture2D = null
## (for the harness) what the move has done: [what, seconds into its phase]
var calm_log: Array = []


## `-- calm=off` restores the moves Jon picked on Oct 8 to 13; `[flow] calm` is no longer read.
## Why: docs/why/ZoomLadder.md#calm-switch
static var calm_force := -1


static func calm_on() -> bool:
	if calm_force >= 0:
		return calm_force == 1
	var a := _arg("calm")
	if a == "off":
		return false
	return true


## Whether a hop between ranks `a` and `b` is the calm move.
static func calm_hop(a: int, b: int) -> bool:
	if not calm_on():
		return false
	if a == b or a < CHART or a > LOCAL or b < CHART or b > LOCAL:
		return false
	# (docked, LOCAL is the berth; the jump's departure is its own cinematic)
	return not Router.docked and Router._post_depart < 0 and not Router._post_arrive


static func _calm_key(a: int, b: int) -> String:
	if mini(a, b) == CHART and maxi(a, b) == LOCAL:
		return "LC"
	if mini(a, b) == CHART:
		return "MC"
	return "LM"


## Click to settled: UI out, slide, camera, then slide off and UI in, or decode and UI in together.
static func calm_length(a: int, b: int) -> float:
	# Into LOCAL: panel off, camera, LOCAL's UI. Out of LOCAL the reverse, then the decode.
	var t := 0.0
	if b == LOCAL:
		t = maxf(CALM_OUT_S, CALM_SLIDE_S) + CALM_CAM_S + CALM_IN_S
	elif a == LOCAL:
		# (the side panel and toolbar slide on drawn: nothing left to decode)
		t = CALM_OUT_S + CALM_CAM_S + CALM_SLIDE_S + CALM_IN_S
	else:
		t = CALM_OUT_S + CALM_CAM_S + maxf(CALM_IN_S, CALM_DECODE_S)
	# The frames between: the camera sets off a frame after chrome stills, and a decode takes two.
	return t + 4.0 / 60.0


## Eased up over the first fifth and down over the last: the most even crossing for its length.
static func calm_slide_curve(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	var a := 0.2
	var v := 1.0 / (1.0 - a)
	if u < a:
		return v * u * u / (2.0 * a)
	if u < 1.0 - a:
		return v * (u - a * 0.5)
	return 1.0 - v * (1.0 - u) * (1.0 - u) / (2.0 * a)


static func _calm_preroll(cur: Control, r: int, target: int, then: Callable) -> void:
	var lad := _make()
	lad._calm = true
	lad.old = cur
	lad.r_old = r
	lad.r_new = target
	lad.seam = seam_between(r, target)
	lad.design = "calm"
	lad._then = then
	lad._fit()
	lad._mat.shader = CALM_SHADER
	var ratio := float(CALM_RATIO[_calm_key(r, target)])
	# (out: the picture shrinks about you; in: it grows)
	lad._calm_L = log(ratio) * (-1.0 if target < r else 1.0)
	lad._calm_p0 = cur.call(&"calm_ship")
	# THE SOUND AT THE CLICK, not when the screens change hands a second later
	# (the HUD's tabs are silent; Tab is a key): the page's sound, once
	Audio.play(&"ui_tab", 0.04, 60)
	# the arriving screen built now, out of sight, so it is up when the screens
	# change hands and where your ship will rest on it is known from the start
	lad._calm_prebuild(target)
	lad.phase = Phase.C_OUT
	lad._calm_t = 0.0
	lad.calm_log.append(["click", 0.0])
	_hud_refresh()
	if chrome_hidden == cur:
		chrome_hidden = null


func _calm_prebuild(target: int) -> void:
	if Router.content == null or Run.map.is_empty():
		return
	var pm: Control = null
	if target == MAP:
		pm = SystemMapScreen.new()
		pm.modulate.a = 0.0
	elif target == CHART:
		pm = StarchartScreen.new()
		pm.modulate.a = PREBUILT_A
	elif target == LOCAL and _local_quiet(false, true):
		pm = SectorScreen.new()
		pm.modulate.a = 0.0
	if pm == null:
		return
	pm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Router.content != null:
		# Build under the game's theme (the engine's made its buttons 31 px tall), behind the screen being left.
		# Why: docs/why/ZoomLadder.md#prebuilt-chart
		Router.content.add_child(pm)
		Router.content.move_child(pm, 0)
	else:
		add_child(pm)
		move_child(pm, 0)
	pm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if pm is SystemMapScreen:
		# (LOCAL's clock out of LOCAL, the party's out of the chart: as `preroll`)
		(pm as SystemMapScreen).show_system(Run.node_at(), Net.handed_clock(Run.at) if r_old == LOCAL else Net.adopt_clock(Run.at), false)
	elif pm is StarchartScreen:
		(pm as StarchartScreen).setup()
	else:
		(pm as SectorScreen).setup(null)
	prebuilt = pm


## Where your ship will rest on the screen arriving: the one built ahead, or
## (built at the swap) where that kind of screen has it at rest.
func _calm_target_rest() -> Vector2:
	var pm := prebuilt
	if pm != null and is_instance_valid(pm) and rank_of(pm) == r_new and pm.call(&"ladder_ready"):
		return pm.call(&"calm_ship")
	var c := _content_rect()
	if r_new == LOCAL:
		return Vector2(209.5, 280.0)
	return Vector2(c.position.x + (c.size.x - 260.0) * 0.5, c.position.y + c.size.y * 0.5)


func _calm_prebuilt_ready() -> bool:
	var pm := prebuilt
	return pm == null or not is_instance_valid(pm) or rank_of(pm) != r_new or bool(pm.call(&"ladder_ready"))


## Your ship on one straight line from rest to rest; after the handoff on to where it arrived.
func _calm_p(e: float) -> Vector2:
	if _calm_e_h < 0.0 or e <= _calm_e_h:
		return _calm_p0.lerp(_calm_p1, e)
	var p1 := _calm_p1
	if _calm_new_begun and is_instance_valid(new):
		p1 = new.call(&"calm_rest")
	return _calm_ph.lerp(p1, (e - _calm_e_h) / maxf(1.0 - _calm_e_h, 0.001))


func _process_calm(delta: float) -> void:
	var dt := _dt(delta) * _calm_rate
	_calm_dt = dt
	_calm_t += dt
	if _calm_new_begun:
		_calm_diss += dt
	# (a crossfade a press hurried runs on past the landing rather than be cut)
	if phase != Phase.C_CAM and _rect.visible and _calm_e_h >= 0.0:
		_calm_fade()
	match phase:
		Phase.C_OUT:
			if not is_instance_valid(old) or Router.current != old:
				_calm_end()
				return
			if r_new == LOCAL:
				# INTO LOCAL: the side panel and toolbar slide off first, the UI leaving with them, all before the camera moves
				_calm_next(Phase.C_SLIDE)
				_calm_t = dt
				_panels_slide(old, false)
				_process_slide_off()
				return
			# (out of LOCAL its strip slides off in LOCAL's own beat, no step added: Jon, Nov 11)
			if r_old == LOCAL and _slide_way == &"":
				_panels_slide(old, false)
			_chrome(old, ease_curve(_calm_t / maxf(CALM_OUT_S, 0.001)))
			_drive_slide(clampf(_calm_t / maxf(CALM_OUT_S, 0.001), 0.0, 1.0), false)
			if _calm_t >= CALM_OUT_S:
				_chrome(old, 1.0)
				_slides_done()
				_calm_next(Phase.C_WAIT)
		Phase.C_SLIDE:
			if not is_instance_valid(old) or Router.current != old:
				_calm_end()
				return
			_process_slide_off()
		Phase.C_WAIT:
			if not is_instance_valid(old) or Router.current != old:
				_calm_end()
				return
			_calm_wait()
		Phase.C_CAM:
			_calm_cam()
		Phase.C_POST:
			_calm_post()
		Phase.C_IN:
			_calm_in()


## INTO LOCAL: the side column and the band go off, the camera still, the
## screen's UI leaving over the first of it; gone whole before the camera moves.
func _process_slide_off() -> void:
	_chrome(old, ease_curve(_calm_t / maxf(CALM_OUT_S, 0.001)))
	var q := clampf(_calm_t / maxf(CALM_SLIDE_S, 0.001), 0.0, 1.0)
	_drive_slide(q, false)
	if q >= 1.0 and _calm_t >= CALM_OUT_S:
		# (the panels stay away, on the screen about to go)
		_slides_done()
		_chrome(old, 1.0)
		# (gone on this frame; the camera from the next)
		_calm_next(Phase.C_WAIT)


## (the screen arriving built and laid out, so where your ship will rest on it
## is known before anything moves; then the camera, from this frame)
func _calm_wait() -> void:
	if _calm_prebuilt_ready() or _calm_t >= WAIT_MAX_S:
		_calm_p1 = _calm_target_rest()
		old.call(&"calm_begin")
		_calm_next(Phase.C_CAM)
		_calm_cam()


func _calm_next(p: Phase) -> void:
	calm_log.append([String(Phase.keys()[p]), _calm_t])
	phase = p
	_calm_t = 0.0


## One step of the camera's curve.
func _calm_cam() -> void:
	var u := clampf(_calm_t / maxf(CALM_CAM_S, 0.001), 0.0, 1.0)
	var e := ease_cam_curve(u)
	_calm_e = e
	if _calm_e_h < 0.0:
		# THE SCREEN BEING LEFT, live, until the screens change hands
		if not is_instance_valid(old) or Router.current != old:
			_calm_end()
			return
		if e >= CALM_HANDOFF:
			_calm_fire()
			if not _calm or phase != Phase.C_CAM or _calm_e_h < 0.0:
				return
		else:
			old.call(&"calm_at", _calm_p(e), exp(_calm_L * e))
			_cloud_round(old, e)
			_calm_e_drawn = e
			return
	# THE SCREEN ARRIVED, live underneath; the held picture over it on the same move, crossfading away
	if not is_instance_valid(new):
		_calm_end()
		return
	_chrome(new, 1.0)
	if not _calm_new_begun:
		if not bool(new.call(&"ladder_ready")):
			# (not laid out yet: the held picture stands, the clock waits)
			_calm_t -= _calm_dt
			return
		# Its camera is taken once it has stood a frame where it is shown, the held picture over it.
		if Engine.get_process_frames() > _calm_swap_frame:
			new.call(&"calm_begin")
			_calm_new_begun = true
			_calm_diss = 0.0
	var p := _calm_p(e)
	if _calm_new_begun:
		new.call(&"calm_at", p, exp(_calm_L * (e - 1.0)))
	_mat.set_shader_parameter(&"to_pt", p)
	_mat.set_shader_parameter(&"scl", Vector2.ONE * exp(_calm_L * (e - _calm_e_h)))
	if _calm_round_from < 0.0:
		_mat.set_shader_parameter(&"cloud_k", _cloud_k(e))
	else:
		_mat.set_shader_parameter(&"cloud_h", _calm_round_h * _cloud_g(e))
	_calm_fade()
	if u >= 1.0:
		_calm_land()


## The held picture's crossfade: `CALM_DISSOLVE_S` of the move's clock, and
## never quicker than a hurried 0.12 s of real time.
func _calm_fade() -> void:
	if not _calm_new_begun:
		_calm_a = 1.0
	else:
		var d := maxf(CALM_DISSOLVE_S, 0.12 * _calm_rate)
		_calm_a = 1.0 - ease_curve(clampf(_calm_diss / d, 0.0, 1.0))
	_mat.set_shader_parameter(&"alpha", _calm_a)
	_rect.visible = _calm_a > 0.0
	# The arriving screen comes up as the left one goes, each as things in front of the same stars.
	if is_instance_valid(new) and _calm_e_h >= 0.0:
		new.modulate.a = 1.0 - _calm_a
		# In a cloud the held picture thins as a cloud over the other's cloud, never over bare sky.
		if _calm_round_from >= 0.0:
			new.modulate.a = 1.0


## THE SCREENS CHANGE HANDS: the Router's own door, which builds (or takes) the
## screen arriving and calls `capture` -> `_calm_hold`.
func _calm_fire() -> void:
	var cb := _then
	_then = Callable()
	_calm_firing = true
	_going = true
	if cb.is_valid():
		cb.call()
	_going = false
	_calm_firing = false
	if _calm_e_h < 0.0:
		# (the door refused: the screen left stays, back at rest)
		if is_instance_valid(old) and Router.current == old:
			old.call(&"calm_end")
		_calm_end()


## Called by `capture` as the Router swaps: the last frame drawn held, the
## chrome put where it stands still until the camera lands.
func _calm_hold(n: Control) -> void:
	new = n
	r_new = rank_of(n)
	_fit()
	var vp := get_viewport()
	var img: Image = null
	if vp != null and vp.get_texture() != null and DisplayServer.get_name() != "headless":
		img = vp.get_texture().get_image()
	if img == null or img.is_empty():
		img = Image.create(960, 540, false, Image.FORMAT_RGBA8)
	# Held opaque as seen: a see-through plate reads 0.84 and let the arriving screen show through.
	# Why: docs/why/ZoomLadder.md#held-picture-opacity
	img.convert(Image.FORMAT_RGB8)
	_tex = ImageTexture.create_from_image(img)
	# THE PICTURE HELD IS THE LAST FRAME DRAWN: its ship where that frame put it, and the line goes on from there
	_calm_e_h = _calm_e_drawn
	_calm_swap_frame = Engine.get_process_frames()
	_calm_ph = _calm_p0.lerp(_calm_p1, _calm_e_drawn)
	# Use where the left screen drew the ship, not its aim: a far chart zoom put a second ship 5 px off.
	# Why: docs/why/ZoomLadder.md#held-ship-position
	if is_instance_valid(old) and bool(old.call(&"ladder_ready")):
		var seen: Variant = old.call(&"calm_ship")
		if seen is Vector2 and (seen as Vector2).is_finite() and (seen as Vector2).distance_to(_calm_ph) < 8.0:
			_calm_ph = seen
	var pic: Rect2 = old.call(&"ladder_picture")
	# A map in a cloud draws its cloud past its picture, so the held picture is the whole of that.
	var cuts := [Vector4.ZERO, Vector4.ZERO]
	var ext: Variant = old.get("_gas_ext") if old is SystemMapScreen else null
	_mat.set_shader_parameter(&"under_on", false)
	_mat.set_shader_parameter(&"under_past_on", false)
	_mat.set_shader_parameter(&"feather", 28.0)
	_mat.set_shader_parameter(&"cloud_edge", false)
	_mat.set_shader_parameter(&"feather_noise", false)
	if ext is TextureRect and (ext as TextureRect).visible:
		pic = _content_rect()
		# (made smaller, a cloud thins out at its edge as a cloud: rounded about
		# the picture's middle, broken by the gas -- `cloud_edge`)
		_mat.set_shader_parameter(&"feather", 160.0)
		var ce := _cloud_ellipse(old)
		_mat.set_shader_parameter(&"cloud_edge", r_new == CHART)
		_mat.set_shader_parameter(&"cloud_k", _cloud_k(_calm_e_drawn))
		_mat.set_shader_parameter(&"cloud_c", ce.position)
		_mat.set_shader_parameter(&"cloud_h", ce.size)
		# (and under them the map's own sky as it was, its cloud running on)
		var et := (ext as TextureRect).texture
		var ei: Image = et.get_image() if et != null and DisplayServer.get_name() != "headless" else null
		if ei != null and not ei.is_empty():
			var at: Vector2 = (ext as TextureRect).global_position
			_mat.set_shader_parameter(&"under_tex", ImageTexture.create_from_image(ei))
			_mat.set_shader_parameter(&"under_at", at)
			_mat.set_shader_parameter(&"under_right", at.x + 960.0)
			_mat.set_shader_parameter(&"under_on", true)
			# (and the cloud past its end, as it was)
			var pv: Variant = (old as SystemMapScreen).view.get("_past") if (old as SystemMapScreen).view != null else null
			var pi: Image = (pv as SubViewport).get_texture().get_image() if pv is SubViewport and is_instance_valid(pv) else null
			_mat.set_shader_parameter(&"under_past_on", pi != null and not pi.is_empty())
			if pi != null and not pi.is_empty():
				_mat.set_shader_parameter(&"under_past", ImageTexture.create_from_image(pi))
		cuts = _chrome_cuts(old)
	elif old is StarchartScreen and (old as StarchartScreen)._chart != null and (old as StarchartScreen)._chart.sky_out.has_area():
		# The chart's sky runs past its picture under the glass, so the held picture takes all of it.
		pic = _content_rect()
		if r_new != LOCAL:
			cuts = _chrome_cuts(old)
	# LOCAL and the map in a cloud: the held picture thins as a cloud too, from the handoff on.
	_calm_round_from = -1.0
	var nd := Run.node_at() if Run.map.size() > 0 else null
	if nd != null and nd.in_nebula and ((r_old == LOCAL and r_new == MAP) or (r_old == MAP and r_new == LOCAL)):
		var ce2 := _cloud_ellipse(old)
		_calm_round_from = _calm_e_drawn
		_mat.set_shader_parameter(&"cloud_edge", true)
		_calm_round_h = ce2.size
		_mat.set_shader_parameter(&"feather_noise", true)
		_mat.set_shader_parameter(&"cloud_k", 1.0)
		_mat.set_shader_parameter(&"cloud_c", ce2.position)
		_mat.set_shader_parameter(&"cloud_h", ce2.size * _cloud_g(_calm_e_drawn))
		_mat.set_shader_parameter(&"feather", 160.0)
	_mat.set_shader_parameter(&"cut3", cuts[0])
	_mat.set_shader_parameter(&"cut4", cuts[1])
	if r_new == LOCAL:
		# Into LOCAL the panels went before the move, so the whole screen left is the carried picture.
		pic = _content_rect()
	_mat.set_shader_parameter(&"old_lin", _tex)
	_mat.set_shader_parameter(&"vp", Vector2(img.get_width(), img.get_height()))
	_mat.set_shader_parameter(&"pic", Vector4(pic.position.x, pic.position.y, pic.size.x, pic.size.y))
	_mat.set_shader_parameter(&"from_pt", _calm_ph)
	_mat.set_shader_parameter(&"to_pt", _calm_ph)
	_mat.set_shader_parameter(&"scl", Vector2.ONE)
	_mat.set_shader_parameter(&"alpha", 1.0)
	_mat.set_shader_parameter(&"side", Vector4.ZERO)
	_mat.set_shader_parameter(&"side2", Vector4.ZERO)
	# THE FIELD KEYED OUT of the picture held: it stays, the things in front go
	_calm_field = null
	var fld: NavField = Router.field
	if fld != null and is_instance_valid(fld) and fld.visible and fld.picture() != null:
		var fi := fld.picture().get_image()
		if fi != null and not fi.is_empty():
			_calm_field = ImageTexture.create_from_image(fi)
	_mat.set_shader_parameter(&"field_on", _calm_field != null)
	if _calm_field != null:
		_mat.set_shader_parameter(&"field_tex", _calm_field)
	# (the goal line, up through the move over both screens, left out of the picture held: `calm_ladder.gdshader` `cut`)
	var gcut := Vector4.ZERO
	var gcut2 := Vector4.ZERO
	var gl: Variant = Router.hud.get("goal") if Router.hud != null else null
	if gl is GoalLine and (gl as GoalLine).visible:
		var gr := Rect2((gl as GoalLine).position, (gl as GoalLine).size).grow(1.0)
		gcut = Vector4(gr.position.x, gr.position.y, gr.size.x, gr.size.y)
		var sr: Rect2 = (gl as GoalLine).step_rect()
		if sr.size != Vector2.ZERO:
			sr = sr.grow(1.0)
			gcut2 = Vector4(sr.position.x, sr.position.y, sr.size.x, sr.size.y)
	_mat.set_shader_parameter(&"cut", gcut)
	_mat.set_shader_parameter(&"cut2", gcut2)
	# (the screen arriving unseen until the held one starts to go)
	n.modulate.a = 1.0 if _calm_round_from >= 0.0 else 0.0
	_calm_a = 1.0
	_rect.visible = true
	# (the swap's own page sound was the click's: `_calm_preroll`)
	Audio.suppress(&"ui_tab", 200)
	# THE CHROME STANDS STILL THROUGH THE MOVE (into LOCAL it went before it)
	if r_old != LOCAL and r_new == LOCAL:
		if chain != &"station": _hide_chrome.call_deferred(n)
	elif r_old != LOCAL and r_new != LOCAL:
		# the map and the chart: the old side bar and toolbar held whole, to decode into the new ones once landed
		for oc: Variant in [side_of(old), bar_of(old), PanelSlide.foot_of(old)]:
			if oc != null and (oc as Control).is_visible_in_tree():
				_calm_cover((oc as Control).get_global_rect())
		side_swap = _region_swap(side_of(old), side_of(n), &"side", CALM_DECODE_S, false)
		bar_swap = _region_swap(bar_of(old), bar_of(n), &"side2", CALM_DECODE_S, true)
		foot_swap = _region_swap(PanelSlide.foot_of(old), PanelSlide.foot_of(n), &"foot", CALM_DECODE_S, true)
		for sw: Variant in _swaps():
			if sw != null:
				(sw as SideSwap).frozen = true
				(sw as SideSwap).target_s = CALM_DECODE_S
				(sw as SideSwap).rate = _calm_rate
	else:
		# out of LOCAL: the arriving screen's side bar and toolbar kept out of
		# sight until the camera has landed, the field where they stand
		_hide_chrome.call_deferred(n)
	calm_log.append(["swap", _calm_t])


## A piece of the held picture, standing where it stood (viewport px).
func _calm_cover(r: Rect2) -> void:
	r = Rect2(r.position.floor(), r.size.ceil())
	var at := AtlasTexture.new()
	at.atlas = _tex
	at.region = r
	var tr := TextureRect.new()
	tr.texture = at
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	tr.position = r.position - global_position
	tr.size = r.size
	tr.z_index = 1
	_calm_covers.append(tr)


func _calm_uncover() -> void:
	for c: Variant in _calm_covers:
		if is_instance_valid(c):
			(c as Node).queue_free()
	_calm_covers.clear()


## THE CAMERA HAS LANDED.
func _calm_land() -> void:
	if is_instance_valid(new) and _calm_new_begun:
		new.call(&"calm_at", new.call(&"calm_rest"), 1.0)
		new.call(&"calm_end")
	_run_landed()
	_calm_uncover()
	if r_old == LOCAL and r_new != LOCAL:
		# Out of LOCAL the column and bands slide on once the left screen is whole.
		_calm_next(Phase.C_POST)
		_calm_post()
		return
	_calm_next(Phase.C_IN)
	if chain == &"station" and r_new == LOCAL:
		# (the map's DOCK: LOCAL's UI stays away, the hangar is next, at once)
		_calm_end()
		return
	for sw: Variant in _swaps():
		if sw != null and is_instance_valid(sw):
			(sw as SideSwap).frozen = false
			(sw as SideSwap).rate = _calm_rate


## (the move between LOCAL and the map in a cloud, from the handoff: `e` there)
var _calm_round_from := -1.0
var _calm_round_h := Vector2.ONE

## Between LOCAL and the map the round comes in as a shape, never a fade, so no side thins alone.
const CLOUD_G0 := 12.0
const CLOUD_G_SPAN := 0.15


func _cloud_g(e: float) -> float:
	var t := smoothstep(_calm_round_from, _calm_round_from + CLOUD_G_SPAN, e)
	return exp(lerpf(log(CLOUD_G0), 0.0, t))


## The map in a cloud rounds off from the camera's first steps, on one curve, live and held.
static func _cloud_k(e: float) -> float:
	return smoothstep(0.04, 0.5, e)


## The screen's side bar and toolbar, where they stand, as the held picture's
## cuts (`calm_ladder.gdshader` `cut3`, `cut4`).
func _chrome_cuts(s: Control) -> Array:
	var cuts := [Vector4.ZERO, Vector4.ZERO]
	var i := 0
	for oc: Variant in [side_of(s), bar_of(s)]:
		if oc != null and (oc as Control).is_visible_in_tree():
			var cr := (oc as Control).get_global_rect().grow(1.0)
			cuts[i] = Vector4(cr.position.x, cr.position.y, cr.size.x, cr.size.y)
			i += 1
	return cuts


## the ellipse's middle (the map's picture's) and its reach (to the screens' area's farthest edges), as [position, size]
func _cloud_ellipse(m: Control) -> Rect2:
	var mid := (m.call(&"ladder_picture") as Rect2).get_center()
	var c := _content_rect()
	return Rect2(mid, Vector2(maxf(mid.x - c.position.x, c.end.x - mid.x), maxf(mid.y - c.position.y, c.end.y - mid.y)))


func _cloud_round(m: Control, e: float) -> void:
	if r_new != CHART or not (m is SystemMapScreen):
		return
	var ext: Variant = m.get("_gas_ext")
	if not (ext is TextureRect) or not (ext as TextureRect).visible:
		return
	var ce := _cloud_ellipse(m)
	for mat: Variant in [(ext as TextureRect).material, (m as SystemMapScreen)._box.material]:
		if mat is ShaderMaterial:
			(mat as ShaderMaterial).set_shader_parameter(&"round_k", _cloud_k(e))
			(mat as ShaderMaterial).set_shader_parameter(&"round_c", ce.position)
			(mat as ShaderMaterial).set_shader_parameter(&"round_h", ce.size)


## Panels drawn the whole way as they slide (`PanelSlide`), on after the camera or off before it.
func _panels_slide(s: Control, on: bool) -> void:
	_slide_way = &"on" if on else &"off"
	var c := _content_rect()
	var sd := side_of(s)
	if sd != null and is_instance_valid(sd) and sd.size.x > 2.0:
		var ps := PanelSlide.new()
		add_child(ps)
		var r := sd.get_global_rect()
		ps.setup(sd, &"side", Vector2(c.end.x - r.position.x + 2.0, 0.0), 0.0 if on else 1.0, s)
		slides.append(ps)
	var br := bar_of(s)
	if br != null and is_instance_valid(br) and br.size.y > 2.0:
		var pb := PanelSlide.new()
		add_child(pb)
		var r2 := br.get_global_rect()
		pb.setup(br, &"band", Vector2(0.0, -(r2.end.y - c.position.y + 2.0)), 0.0 if on else 1.0, s)
		slides.append(pb)
	var pf := PanelSlide.for_foot(self, s, c, on)
	if pf != null:
		slides.append(pf)


## The side column and the band at `q` (0 to 1) of their slide, on (out of
## LOCAL) or off (into it), on the one even curve (`calm_slide_curve`).
func _drive_slide(q: float, on: bool) -> void:
	var c := calm_slide_curve(q)
	var k := c if on else 1.0 - c
	for p: Variant in slides:
		if is_instance_valid(p):
			p.call(&"set_k", k)
	if band != null and is_instance_valid(band) and band.driven:
		band.drive(k)


## Out of LOCAL, landed: the side panel and toolbar slide on, drawn, then the UI.
func _calm_post() -> void:
	if not is_instance_valid(new) or Router.current != new:
		_calm_end()
		return
	_chrome(new, 1.0)
	if _slide_way != &"on":
		if _rect.visible:
			_calm_t = 0.0
			return
		_show_chrome()
		_panels_slide(new, true)
		_calm_t = 0.0
	var q := clampf(_calm_t / maxf(CALM_SLIDE_S, 0.001), 0.0, 1.0)
	_drive_slide(q, true)
	if q >= 1.0:
		_slides_done()
		_slide_way = &"done"
		_calm_next(Phase.C_IN)


func _calm_in() -> void:
	if not is_instance_valid(new) or Router.current != new:
		_calm_end()
		return
	_chrome(new, 1.0 - ease_curve(_calm_t / maxf(CALM_IN_S, 0.001)))
	# (into LOCAL its strip slides on in LOCAL's own beat, as its UI comes up)
	if r_new == LOCAL and _slide_way == &"off":
		_show_chrome()
		_panels_slide(new, true)
	_drive_slide(clampf(_calm_t / maxf(CALM_IN_S, 0.001), 0.0, 1.0), true)
	if _calm_t >= CALM_IN_S:
		_slides_done()
		_calm_end()


## The slides under way finished where they stand.
func _slides_done() -> void:
	for pc: Variant in slides:
		if is_instance_valid(pc):
			pc.call(&"finish")
	slides.clear()


## A PRESS MID-MOVE (or another door asked for): the rest of the move in about
## `CALM_HURRY_S`, on the same curve -- never a cut, never lost.
func hurry() -> void:
	if not _calm or _calm_hurried:
		return
	_calm_hurried = true
	var left := 0.0
	var after := CALM_IN_S if (r_new == LOCAL or r_old == LOCAL) else maxf(CALM_IN_S, CALM_DECODE_S)
	if r_old == LOCAL:
		after += CALM_SLIDE_S
	match phase:
		Phase.C_OUT:
			left = CALM_OUT_S - _calm_t + CALM_CAM_S + after
		Phase.C_SLIDE:
			left = CALM_SLIDE_S - _calm_t + CALM_CAM_S + after
		Phase.C_WAIT:
			left = CALM_CAM_S + after
		Phase.C_CAM:
			left = CALM_CAM_S - _calm_t + after
		Phase.C_POST:
			left = CALM_SLIDE_S - _calm_t + CALM_IN_S
		Phase.C_IN:
			left = (CALM_IN_S if (r_new == LOCAL or r_old == LOCAL) else maxf(CALM_IN_S, CALM_DECODE_S)) - _calm_t
	_calm_rate = maxf(1.0, left / CALM_HURRY_S)
	for sw: Variant in _swaps():
		if sw != null and is_instance_valid(sw):
			(sw as SideSwap).rate = _calm_rate
	calm_log.append(["hurry", _calm_t])


## Another door asked for while this move is on: taken once it has landed.
func _calm_queue(_target: int, then: Callable) -> void:
	_calm_q = then


## A press over the side bar or the toolbar while what they show is changing
## lands on nothing (`SideSwap.blocks` once a decode runs on).
func _calm_eats(e: InputEvent) -> bool:
	if not (e is InputEventMouseButton):
		return false
	var p := (e as InputEventMouseButton).position
	for pc: Variant in ChromeSlide.live:
		if is_instance_valid(pc) and (pc as ChromeSlide).at().intersection((pc as ChromeSlide).clip).has_point(p):
			return true
	for pc: Variant in PanelSlide.live:
		if is_instance_valid(pc) and (pc as PanelSlide).at().intersection(_content_rect()).has_point(p):
			return true
	if phase == Phase.C_IN or phase == Phase.C_POST:
		for sw: Variant in _swaps():
			if sw != null and is_instance_valid(sw) and not (sw as SideSwap).done and (sw as SideSwap).blocks(p):
				return true
		return false
	for s: Variant in [old, new]:
		if s != null and is_instance_valid(s):
			for c: Variant in [side_of(s), bar_of(s), PanelSlide.foot_of(s)]:
				if c != null and (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().has_point(p):
					return true
	return false


## Straight to the end state, for code that must not wait (a skip, another kind
## of move): the screen asked for up, at rest, its UI back.
func _calm_finish_now() -> void:
	if _calm_e_h < 0.0 and is_instance_valid(old) and Router.current == old:
		if phase == Phase.C_CAM:
			old.call(&"calm_end")
		if _then.is_valid() and not _capturing:
			_chrome(old, 1.0)
			_calm_fire()
	if _calm_e_h >= 0.0 and is_instance_valid(new):
		if not _calm_new_begun and bool(new.call(&"ladder_ready")):
			new.call(&"calm_begin")
			_calm_new_begun = true
		if _calm_new_begun and phase == Phase.C_CAM:
			new.call(&"calm_end")
	_rect.visible = false
	_calm_uncover()
	for p: Variant in slides:
		if is_instance_valid(p):
			if p is PanelSlide:
				(p as PanelSlide).set_k(1.0)
			p.call(&"finish")
	slides.clear()
	if is_instance_valid(new):
		new.modulate.a = 1.0
	for sw: Variant in _swaps():
		if sw != null and is_instance_valid(sw):
			(sw as SideSwap).finish()
	if band != null and is_instance_valid(band):
		band.finish()
	_show_chrome()
	_calm_q = Callable()
	if _calm:
		_calm_end()


func _calm_end() -> void:
	if not _calm:
		return
	_calm = false
	# (a map that stays -- the move given up -- back to its whole cloud)
	if is_instance_valid(old) and old is SystemMapScreen and Router.current == old:
		var ext: Variant = old.get("_gas_ext")
		for mat: Variant in [(ext as TextureRect).material if ext is TextureRect else null, (old as SystemMapScreen)._box.material]:
			if mat is ShaderMaterial:
				(mat as ShaderMaterial).set_shader_parameter(&"round_k", 0.0)
	if is_instance_valid(new):
		new.modulate.a = 1.0
	if _calm_e_h < 0.0:
		drop_prebuilt()
		if is_instance_valid(old) and Router.current == old:
			if phase == Phase.C_CAM:
				old.call(&"calm_end")
			_chrome(old, 0.0)
			for p: Variant in slides:
				if is_instance_valid(p):
					if p is PanelSlide:
						(p as PanelSlide).set_k(1.0)
					p.call(&"finish")
			slides.clear()
			if band != null and is_instance_valid(band):
				band.finish()
			_show_chrome()
	elif phase == Phase.C_CAM and _calm_new_begun and is_instance_valid(new):
		new.call(&"calm_end")
	var chained := false
	if chain == &"station" and new is SectorScreen and is_instance_valid(new) and Router.current == new:
		chain = &""
		chained = true
		chrome_hidden = new
		_chain_go.call_deferred(new)
	if is_instance_valid(new) and Router.current == new and not chained:
		_chrome(new, 0.0)
	_run_landed()
	calm_log.append(["end", _calm_t])
	if active == self:
		active = null
		_hud_refresh()
	phase = Phase.PRE_DONE
	_rect.visible = false
	# THE DECODE RUNS ON PAST THE MOVE (a press hurried the camera; the letters
	# finish on their own), handed to the viewport as the ladder goes
	for sw: Variant in _swaps():
		if sw == null or not is_instance_valid(sw) or (sw as SideSwap).done:
			continue
		if get_parent() == null:
			(sw as SideSwap).finish()
			continue
		(sw as SideSwap).frozen = false
		var bb := BackBufferCopy.new()
		bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		var gp := (sw as SideSwap).global_position
		remove_child(sw)
		get_parent().add_child(bb)
		get_parent().add_child(sw)
		(sw as SideSwap).global_position = gp
		(sw as SideSwap).tree_exited.connect(bb.queue_free)
	if band != null and is_instance_valid(band) and not band.done:
		if get_parent() == null:
			band.finish()
		else:
			var bgp := band.global_position
			remove_child(band)
			get_parent().add_child(band)
			band.global_position = bgp
	var q := _calm_q
	_calm_q = Callable()
	queue_free()
	if save_after:
		save_after = false
		Router.autosave()
	# THE DOOR ASKED FOR WHILE THIS MOVE WAS ON, from where it landed
	if q.is_valid():
		q.call_deferred()
