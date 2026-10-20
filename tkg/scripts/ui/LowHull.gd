class_name LowHull
extends Node

## THE HULL IS FAILING, AND THE SCREEN KNOWS (Jon, Oct 20: "When you are low
## health, can you have all the text kinda glitch a bit? Maybe with the screen
## turning red? I don't want it to be too overt. Just kinda like a gentle
## warning state." And then: "Maybe even A.S.H.'s voice could glitch a bit?").
##
## WHEN: the hull at or under TIER1_AT of its max (a second, slightly stronger
## step of the red at TIER2_AT), read as the HUD reads it -- the figure the fight
## has SHOWN, not the one the click already decided (`SectorScreen.shown_hull`,
## `OutcomeRow.held`) -- so the warning arrives with the number that says so.
## Only inside a run: never on the title, the lobby, the hull pick, RUN ENDED or
## the records room from the title, and never once the hull is at 0 (the
## ship's loss has its own picture, `DeathHandoff`). It eases in and out over
## EASE_S as the hull crosses the line either way; a repair clears it.
##
## WHAT:
##   * THE RED, drawn over the finished frame (`low_hull.gdshader`, on a
##     CanvasLayer of its own at LAYER: above the screens and the HUD, under the
##     escape menu): a faint red at the picture's edges, breathing (BREATH_S a
##     cycle), never reaching the middle of the screen. Its two steps are the
##     preset's `red`.
##   * THE WORDS DECODING BADLY (`HullScramble`; Jon: "I think the text should
##     glitch more like the decoding. It should be ALL of the text on the
##     screen. With it getting worse as the health lowers."): letters all over
##     the screen flip to `SignalText`'s noise for a moment and resolve back.
##     NOT IN STEPS: `depth` runs from 0 at TIER1_AT to 1 at no hull, eased over
##     EASE_S, and the scramble's rate, run and hold follow it; the preset's
##     `scr.most` and `scr.share` are its ceilings, so it stays readable at 5%.
##     The hull readout scrambles too (Jon: ALL the text); the escape menu never.
##   * HER VOICE: A.S.H.'s lines while it is on stutter, drop out, chop and
##     crackle (`voice_plan`, rendered by `VoiceGlitch`), more and longer as the
##     hull falls, by the same `depth`; her portrait slips in step (`AshPortrait`).
##
## NO SOUND OF ITS OWN. The game has no low-hull sound and this adds none: the
## heat warning (`heat_warn`) is the only alarm the ship has.
##
## REDUCED MOTION (`Router.animating()` false): no scramble and no breathing --
## the red stands still at REDUCED_RED of its strength -- and her voice glitches
## at the SUBTLE preset whatever PRESET is (a sound does not move on screen, so
## it stays, at its quietest).
##
## THE STRENGTH IS ONE CONSTANT: PRESET, from LOOKS. `-- lowhull=subtle|medium|
## strong` overrides it for a film.

enum Preset { SUBTLE, MEDIUM, STRONG }
## Jon's pick of LOOKS. Default subtle ("I don't want it to be too overt").
const PRESET := Preset.SUBTLE

## The hull's share at or under which it comes on, and the red's second step.
const TIER1_AT := 0.30
const TIER2_AT := 0.15
## In and out, s, on the game's clock. `depth` follows the hull at the same pace.
const EASE_S := 1.0
## One breath, s: tier 1, and tier 2 (a little quicker).
const BREATH_S := [2.6, 2.0]
## The share of the red that stands, still, under reduced motion.
const REDUCED_RED := 0.6
## Above the screens (layer 0), under the escape menu and Settings (10).
const LAYER := 5

## Per preset.
##   red     the red at the very edge, (tier 1, tier 2) (`low_hull.gdshader`)
##   breath  how far a breath takes it down, as a share of itself
##   scr     the words (`HullScramble`), each pair (at TIER1_AT, at no hull):
##             rate   letters' runs started a second, across a screen of
##                    `HullScramble.REF_LETTERS` letters (more on a fuller one,
##                    fewer on a bare one), followed as depth^1.5: rare near the line
##             run    the longest run, letters (1 at the line, this near 0)
##             hold   how long a letter stays noise, s
##             most   the ceiling: letters scrambled at once on the whole screen
##             share  the ceiling for one text: of its letters, at once
##   voice   her lines (`plan_for`), each pair (at TIER1_AT, at no hull):
##             rate   glitches a second of her words
##             len    each window's length, times its kind's (KIND_LEN)
##             amt    how hard each bites (`VoiceGlitch.apply`)
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
		scr = {rate = [1.2, 34.0], run = 6, hold = [0.12, 0.45], most = 26, share = 0.3},
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
## How far below the line the hull is, 0 at TIER1_AT to 1 at none, eased.
static var depth := 0.0
## The red the shader was given this frame.
static var red_now := 0.0

var _layer: CanvasLayer
var _rect: ColorRect
var _mat: ShaderMaterial
var _breath := 0.0
var _last := -1.0
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


## How far under the line a hull at `share` of its max is: 0 at TIER1_AT, 1 at
## none; 0 above the line too (and at 0 hull, where it is off).
static func depth_for(share: float) -> float:
	if share <= 0.0 or share > TIER1_AT + 0.00001:
		return 0.0
	return clampf((TIER1_AT - share) / TIER1_AT, 0.0, 1.0)


## A run is up and on screen: not the title, the lobby, the hull pick, RUN
## ENDED, or the records room opened from the title.
static func in_run() -> bool:
	var cur := Router.current
	if cur == null or not is_instance_valid(cur) or Run.hull == null:
		return false
	if Router.is_front_door(cur) or cur is GameOverScreen:
		return false
	if cur is ArchiveScreen and Router.hud != null and not Router.hud.visible:
		return false
	return true


static func moving() -> bool:
	return Router.animating()


## The string to draw for `s` (hand-drawn text: `draw_string` in a screen's
## `_draw`): `s` itself, or `s` with a scrambled letter or two swapped for noise
## glyphs of exactly the same advance, so the string is the same width to the
## pixel and nothing after it moves. Only ever for drawing: the screen's own
## data keeps `s`.
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
	var show := red_now > 0.0005
	_rect.visible = show
	if show:
		_mat.set_shader_parameter(&"red", red_now)


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


## WHERE HER LINE GLITCHES (Jon, Oct 20, on the first take of this: "I don't
## hear A.S.H.'s voice glitch that much"). Heard at the line already -- a
## stutter or a chop first in every line -- and more of them, longer, with the
## crush, the ring and the wobble joining, as `depth` goes to 1.
##
## SHE STAYS UNDERSTOOD: a dropout or a stutter replaces what she said, so it
## is never longer than KIND_MOST (110 ms: under a short word); the chop, the
## crackle, the crush, the ring and the wobble keep her words under them. At
## least MIN_APART between two, and never more than MOST_SHARE of a line.
## Inside her words only: after the take's 30 ms lead-in (and a little) and
## before its trailing silence.
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
## Heard from the line down (a stutter, a chop, a crackle: each plainly a
## fault, Jon having not heard the first take's), a dropout now and then
## (GAP_P, more as the hull falls), and the rest joining as it falls (LATE_P).
const VOICE_EARLY: Array[StringName] = [&"repeat", &"chop", &"crackle"]
const VOICE_LATE: Array[StringName] = [&"crush", &"ring", &"wobble"]
const GAP_P := [0.15, 0.3]
const LATE_P := 0.5

static func voice_plan(secs: float, rng: RandomNumberGenerator = null) -> Array:
	if not voice_on():
		return []
	var h := shown()
	return plan_for(secs, float(h.x) / float(h.y), voice_look(), rng)


## The plan without asking the hull: `share` the hull's share of its max, `lk`
## the look. [{at, len, kind, amt, rep, hz, seed}], at and len in s from the
## take's start.
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
