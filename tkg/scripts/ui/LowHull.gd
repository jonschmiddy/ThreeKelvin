class_name LowHull
extends Node

## A gentle warning (Jon, Oct 20): edge red, words decoding badly, A.S.H.'s voice glitching.
## No sound of its own: the heat warning is the only alarm. Reduced motion stills it.
## Why: docs/why/LowHull.md#low-hull-warning

enum Preset { SUBTLE, MEDIUM, STRONG }
## Jon's pick of LOOKS: STRONG (Oct 20, "strength:strong", after subtle, medium
## and strong side by side; it began as subtle, "I don't want it to be too overt").
const PRESET := Preset.STRONG

## The hull's share at or under which it comes on, and the red's second step.
const TIER1_AT := 0.30
const TIER2_AT := 0.15
## The tags' glitch (`HoloTag`; Jon, Nov 11): G3 at or under WORN_AT, G4 with the red
## (TIER1_AT), G5b under DIRE_UNDER. Why: docs/why/LowHull.md#tags
const WORN_AT := 0.50
const DIRE_UNDER := 0.15
## In and out, s, on the game's clock. `depth` follows the hull at the same pace.
const EASE_S := 1.0
## One breath, s: tier 1, and tier 2 (a little quicker).
const BREATH_S := [2.6, 2.0]
## The share of the red that stands, still, under reduced motion.
const REDUCED_RED := 0.6
## Above the screens (layer 0), under the escape menu and Settings (10).
const LAYER := 5
## THE SCREEN WEARS (Jon, Nov 11): bursts of torn bands drawn over the picture, rarer and fainter
## at WORN_AT, more with the red, most at TIER2_AT. Per step (none, 50, 30, 15%): bursts a
## second, a burst's 30 Hz frames, bands, how far they slide (px), the colour split (px).
## Why: docs/why/LowHull.md#screen-wears
const UI_RATE: Array[float] = [0.0, 0.12, 0.45, 1.3]
const UI_FRAMES: Array[float] = [0.0, 2.0, 3.0, 5.0]
const UI_BANDS: Array[float] = [0.0, 1.25, 2.5, 5.0]
const UI_SHIFT: Array[float] = [0.0, 2.5, 5.0, 10.0]
const UI_SPLIT: Array[float] = [0.0, 1.25, 1.25, 2.5]
## How dark a torn band goes (0.12 first, a quarter more, H2).
const UI_DARK := 0.15

## Per-preset strengths for the red, the scramble and the voice, each from the line to no hull.
## Why: docs/why/LowHull.md#presets
const LOOKS := {
	Preset.SUBTLE: {
		red = [0.30, 0.42], breath = 0.4,
		scr = {rate = [0.5, 16.0], run = 4, hold = [0.08, 0.32], most = 12, share = 0.2},
		voice = {rate = [1.1, 3.0], len = [1.0, 1.35], amt = [0.85, 1.0]},
	},
	Preset.MEDIUM: {
		red = [0.48, 0.62], breath = 0.4,
		scr = {rate = [0.8, 24.0], run = 5, hold = [0.1, 0.38], most = 18, share = 0.25},
		voice = {rate = [1.4, 3.6], len = [1.05, 1.45], amt = [0.92, 1.0]},
	},
	Preset.STRONG: {
		red = [0.68, 0.85], breath = 0.45,
		scr = {rate = [1.2, 34.0], run = 6, hold = [0.12, 0.45], most = 32, share = 0.375},
		voice = {rate = [1.8, 4.2], len = [1.1, 1.55], amt = [1.0, 1.0]},
	},
}

const SHADER := preload("res://shaders/low_hull.gdshader")

static var instance: LowHull = null
## The preset in force: PRESET, or what `-- lowhull=` asked for.
static var preset: Preset = PRESET
## What the hull says now: 0 fine, 1 at or under TIER1_AT, 2 at or under TIER2_AT.
static var tier := 0
## Eased toward on (1) and toward the red's second step (1), 0..1.
static var on := 0.0
static var deep := 0.0
## Eased toward 1 at or under WORN_AT and under DIRE_UNDER, as `on` (no red: the tags read them).
static var worn := 0.0
static var dire := 0.0
## How far below the line the hull is, 0 at TIER1_AT to 1 at none, eased.
static var depth := 0.0
## The red the shader was given this frame.
static var red_now := 0.0
## The screen's wear, 0 to 3 (`worn` + `on` + `deep`, eased); a burst showing now, how strong
## (bands times slide), and how many have started (for a harness).
static var ui_k := 0.0
static var ui_on := false
static var ui_strength := 0.0
static var ui_bursts := 0

var _layer: CanvasLayer
var _rect: ColorRect
var _mat: ShaderMaterial
var _breath := 0.0
var _last := -1.0
var _ui_next := -1.0
var _ui_end := -1.0
var _ui_rng := RandomNumberGenerator.new()
var scramble: HullScramble


func _init() -> void:
	name = "LowHull"


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("lowhull="):
			match (a as String).substr(8):
				"medium": preset = Preset.MEDIUM
				"strong": preset = Preset.STRONG
				_: preset = Preset.SUBTLE
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect = ColorRect.new()
	_rect.name = "LowHullGlass"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.focus_mode = Control.FOCUS_NONE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.material = _mat
	_rect.visible = false
	_layer.add_child(_rect)
	scramble = HullScramble.new()
	add_child(scramble)


func _exit_tree() -> void:
	if instance == self:
		instance = null


## The look in force (`preset`).
static func look() -> Dictionary:
	return LOOKS[preset]


## The hull as the HUD shows it, and its max. 0 max outside a run.
static func shown() -> Vector2i:
	if Run.hull == null:
		return Vector2i(0, 0)
	var hp := Run.hp if SectorScreen.shown_hull < 0 else SectorScreen.shown_hull
	hp = int(OutcomeRow.held.get("hp", hp))
	return Vector2i(hp, Run.max_hp())


## Which step a hull of `hp` out of `top` is on.
static func tier_for(hp: int, top: int) -> int:
	if top <= 0 or hp <= 0:
		return 0
	var s := float(hp) / float(top)
	if s <= TIER2_AT + 0.00001:
		return 2
	if s <= TIER1_AT + 0.00001:
		return 1
	return 0


## Whether a hull of `hp` out of `top` is at or under WORN_AT (and not 0, where all is off).
static func is_worn(hp: int, top: int) -> bool:
	return top > 0 and hp > 0 and float(hp) / float(top) <= WORN_AT + 0.00001


## Whether it is strictly under DIRE_UNDER ("when under 15%"), not 0.
static func is_dire(hp: int, top: int) -> bool:
	return top > 0 and hp > 0 and float(hp) / float(top) < DIRE_UNDER - 0.00001


## How far under the line a hull at `share` of its max is: 0 at TIER1_AT, 1 at
## none; 0 above the line too (and at 0 hull, where it is off).
static func depth_for(share: float) -> float:
	if share <= 0.0 or share > TIER1_AT + 0.00001:
		return 0.0
	return clampf((TIER1_AT - share) / TIER1_AT, 0.0, 1.0)


## A run is up and on screen: not the title, the lobby, the hull pick or RUN
## ENDED.
static func in_run() -> bool:
	var cur := Router.current
	if cur == null or not is_instance_valid(cur) or Run.hull == null:
		return false
	if Router.is_front_door(cur) or cur is GameOverScreen:
		return false
	return true


static func moving() -> bool:
	return Router.animating()


## Scrambled letters swap to noise glyphs of the same advance, so width never changes.
static func scr(owner: CanvasItem, s: String, size: int = UITheme.FS_BODY, font: Font = null) -> String:
	if instance == null or instance.scramble == null or not instance.scramble._active:
		return s
	return instance.scramble.drawn(owner, s, size, font if font != null else UITheme.pixel_font())


func _process(_d: float) -> void:
	var now := GameClock.now()
	var dt := 0.0 if _last < 0.0 else clampf(now - _last, 0.0, 0.25)
	_last = now
	var h := shown()
	var live := in_run()
	tier = tier_for(h.x, h.y) if live else 0
	var share := float(h.x) / float(h.y) if h.y > 0 else 1.0
	on = move_toward(on, 1.0 if tier > 0 else 0.0, dt / EASE_S)
	deep = move_toward(deep, 1.0 if tier > 1 else 0.0, dt / EASE_S)
	worn = move_toward(worn, 1.0 if live and is_worn(h.x, h.y) else 0.0, dt / EASE_S)
	dire = move_toward(dire, 1.0 if live and is_dire(h.x, h.y) else 0.0, dt / EASE_S)
	depth = move_toward(depth, depth_for(share) if tier > 0 else 0.0, dt / EASE_S)
	var lk := look()
	var e_on := smoothstep(0.0, 1.0, on)
	var e_deep := smoothstep(0.0, 1.0, deep)
	var base := lerpf(float(lk.red[0]), float(lk.red[1]), e_deep)
	if moving():
		_breath = fposmod(_breath + dt / lerpf(float(BREATH_S[0]), float(BREATH_S[1]), e_deep), 1.0)
		var b := 0.5 - 0.5 * cos(TAU * _breath)
		red_now = e_on * base * (1.0 - float(lk.breath) * (1.0 - b))
	else:
		_breath = 0.0
		red_now = e_on * base * REDUCED_RED
	ui_k = (worn + on + deep) if live else 0.0
	_wear(now)
	var show := red_now > 0.0005 or ui_on
	_rect.visible = show
	if show:
		_mat.set_shader_parameter(&"red", red_now)


## `arr` at the screen's wear `ui_k`, between its steps.
static func ui_val(arr: Array[float], k: float = -1.0) -> float:
	var x := clampf(ui_k if k < 0.0 else k, 0.0, 3.0)
	var i := mini(int(x), 2)
	return lerpf(arr[i], arr[i + 1], x - i)


## THE SCREEN WEARS: a burst now and then, its bands rolled on a 30 Hz clock, drawn by the glass;
## none under reduced motion or out of a run. It only tints pixels: nothing moves or stops a click.
func _wear(now: float) -> void:
	var rate := ui_val(UI_RATE)
	if ui_k <= 0.001 or rate <= 0.0 or not moving():
		ui_on = false
		ui_strength = 0.0
		_ui_next = -1.0
		_mat.set_shader_parameter(&"gl_on", 0.0)
		return
	if _ui_next < 0.0 or _ui_next - now > 1.5 / rate:
		_ui_next = now + _ui_rng.randf_range(0.5, 1.5) / rate
	if not ui_on and now >= _ui_next:
		ui_on = true
		ui_bursts += 1
		_ui_end = now + maxf(1.0, roundf(ui_val(UI_FRAMES))) / 30.0
		_ui_next = _ui_end + _ui_rng.randf_range(0.5, 1.5) / rate
	if ui_on and now >= _ui_end:
		ui_on = false
	var bands := int(roundf(ui_val(UI_BANDS)))
	var shift := ui_val(UI_SHIFT)
	ui_strength = bands * shift if ui_on else 0.0
	_mat.set_shader_parameter(&"gl_on", 1.0 if ui_on else 0.0)
	_mat.set_shader_parameter(&"gl_seed", floorf(now * 30.0))
	_mat.set_shader_parameter(&"gl_bands", bands)
	_mat.set_shader_parameter(&"gl_shift", shift)
	_mat.set_shader_parameter(&"gl_split", roundf(ui_val(UI_SPLIT)))
	_mat.set_shader_parameter(&"gl_dark", UI_DARK)


static func _screen_rect(c: Control) -> Rect2:
	var xf := c.get_global_transform_with_canvas()
	return (xf * Rect2(Vector2.ZERO, c.size)).abs()


# ------------------------------------------------------------------ her voice

## The preset her voice uses: PRESET's, or SUBTLE under reduced motion.
static func voice_look() -> Dictionary:
	return LOOKS[Preset.SUBTLE] if DisplaySettings.reduced_motion else look()


## Her voice glitches this line: the hull is on a step NOW (her line is decided
## as it starts, so no easing).
static func voice_on() -> bool:
	if instance == null:
		return false
	var h := shown()
	return in_run() and tier_for(h.x, h.y) > 0


## Her line must stay understood: dropouts and stutters stay under 110 ms (Jon, Oct 20).
## Why: docs/why/LowHull.md#voice-glitches
const MIN_APART := 0.14
const MOST_SHARE := 0.45
## Each kind's window at the line, s (times the preset's `voice.len`)...
const KIND_LEN := {
	&"gap": [0.045, 0.07], &"repeat": [0.085, 0.11], &"chop": [0.09, 0.14],
	&"crackle": [0.1, 0.16], &"crush": [0.06, 0.1], &"ring": [0.05, 0.08],
	&"wobble": [0.12, 0.16],
}
## ...and the longest it may ever be.
const KIND_MOST := {
	&"gap": 0.09, &"repeat": 0.11, &"chop": 0.2, &"crackle": 0.22,
	&"crush": 0.14, &"ring": 0.12, &"wobble": 0.22,
}
## Plain faults from the line down, a dropout now and then, the rest as the hull falls.
const VOICE_EARLY: Array[StringName] = [&"repeat", &"chop", &"crackle"]
const VOICE_LATE: Array[StringName] = [&"crush", &"ring", &"wobble"]
const GAP_P := [0.15, 0.3]
const LATE_P := 0.5

static func voice_plan(secs: float, rng: RandomNumberGenerator = null) -> Array:
	if not voice_on():
		return []
	var h := shown()
	return plan_for(secs, float(h.x) / float(h.y), voice_look(), rng)


## The plan without asking the hull: `share` of max and the look `lk`.
static func plan_for(secs: float, share: float, lk: Dictionary, rng: RandomNumberGenerator = null) -> Array:
	var out: Array = []
	if share <= 0.0 or share > TIER1_AT + 0.00001:
		return out
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var d := depth_for(share)
	var v: Dictionary = lk.voice
	var a := 0.12
	var z := secs - 0.1 - 0.2
	var span := z - a
	if span < 0.25:
		return out
	var n := maxi(1, int(roundf(lerpf(float(v.rate[0]), float(v.rate[1]), d) * span)))
	var scale := lerpf(float(v.len[0]), float(v.len[1]), d)
	var kinds: Array[StringName] = []
	var lens: Array[float] = []
	var total := 0.0
	for i in n:
		var k: StringName
		var roll := rng.randf()
		if i == 0:
			k = [&"repeat", &"chop"][rng.randi() % 2]
		elif roll < d * LATE_P:
			k = VOICE_LATE[rng.randi() % VOICE_LATE.size()]
		elif roll < d * LATE_P + lerpf(float(GAP_P[0]), float(GAP_P[1]), d):
			k = &"gap"
		else:
			k = VOICE_EARLY[rng.randi() % VOICE_EARLY.size()]
		var ln := minf(rng.randf_range(float(KIND_LEN[k][0]), float(KIND_LEN[k][1])) * scale, float(KIND_MOST[k]))
		kinds.append(k)
		lens.append(ln)
		total += ln
	# what fits: the windows, MIN_APART after each, and no more than MOST_SHARE
	while kinds.size() > 1 and (total + MIN_APART * kinds.size() > span or total > MOST_SHARE * span):
		total -= lens.pop_back()
		kinds.pop_back()
	if total + MIN_APART * kinds.size() > span:
		return out
	# spread: what is left over shared out at random between them
	var free := span - total - MIN_APART * kinds.size()
	var w: Array[float] = []
	var ws := 0.0
	for i in kinds.size() + 1:
		var x := rng.randf_range(0.3, 1.0)
		w.append(x)
		ws += x
	var at := a
	var amt := lerpf(float(v.amt[0]), float(v.amt[1]), d)
	for i in kinds.size():
		at += free * w[i] / ws
		out.append({at = at, len = lens[i], kind = kinds[i], amt = amt,
			rep = 2 + int(floorf(d * 2.99)), hz = lerpf(26.0, 38.0, d), seed = rng.randi()})
		at += lens[i] + MIN_APART
	return out
