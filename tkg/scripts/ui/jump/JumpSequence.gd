class_name JumpSequence
extends RefCounted

## One jump film, pure in t: `setup` builds its passes on the stage, `step(t)` sets this
## instant's numbers, `teardown` lets go. Its sound is the film's mix split at `cut_t` into
## a build cue and a hit cue (`audio/jump_cues.py`), each fired on the frame t crosses it.
## Why: docs/why/JumpSequence.md#sequence

var id: StringName = &""
## The film's length, its hit, where the mix is cut, and where the game commits the jump.
var length := 10.0
var hit_t := 5.0
var cut_t := 5.0
var commit_t := 8.8
## When the live hull gives way to the baked stand-in (before any light touches it).
var swap_t := 0.6
## How long the live ion flame keeps its idle burn before it sputters out (R3, R8 filmed it); 0 out at once.
var flame_s := 0.0
var stage: JumpStage
var place: JumpPlace
var hull: JumpHull
## Fewer flashes (DisplaySettings.reduce_flashes): the film says what it does with it.
var reduce := false
## The whole-pixel shake this instant, for the harnesses.
var shake := Vector2.ZERO
## The full-frame flash this instant, 0..1, for the harnesses.
var flash := 0.0
## The flash's frame-wide floor, the film's own (R4 and R12 lit the whole frame a tenth).
var flash_floor := 0.10

## The smooth noise the films shook with (`smooth_noise`, seeds 1 and 2): the rolled rates at
## 15 Hz (r4, r12); another film's rate scales them (R9 16 Hz, R10 17 Hz, R14 14 Hz), the phases stay.
const NOISE_F := [[15.90959, 18.60846, 31.70334, 62.53935], [12.53176, 33.98648, 41.04326, 35.76366]]
const NOISE_PH := [[5.96891, 5.95752, 2.65849, 2.56977], [1.87452, 0.57723, 4.57536, 0.34632]]


## The cues and when they fire: the build from the first frame, the hit at the cut.
func cues() -> Array[Array]:
	return [[StringName("jump_%s_build" % id), 0.0], [StringName("jump_%s_hit" % id), cut_t]]


func setup(_stage: JumpStage, _place: JumpPlace, _hull: JumpHull) -> void:
	stage = _stage
	place = _place
	hull = _hull


## The baked hull has arrived and the live view is hidden: draw the stand-in from now on.
func hull_ready() -> void:
	stage.hull_textures(hull)
	stage.set1(&"hull_on", 1.0)


func step(_t: float) -> void:
	pass


func teardown() -> void:
	pass


static func ease3(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func ease5(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * u * (u * (6.0 * u - 15.0) + 10.0)


## `hz` scales the rolled rates (the films rolled them as a factor of the rate asked for);
## R5's three-term `snoise` is the first three terms over 1.6.
static func smooth_noise(t: float, seed_i: int, hz: float = 15.0, terms: int = 4) -> float:
	var v := 0.0
	for k in terms:
		v += sin(TAU * float(NOISE_F[seed_i][k]) * (hz / 15.0) * t + float(NOISE_PH[seed_i][k])) / float(1 + k)
	return v / (1.9 if terms == 4 else 1.6)


## A deterministic 0..1 for a held frame and a salt (the films' `held` rng draws).
static func held_rand(step_i: int, salt: int) -> float:
	var h := hash(Vector2i(step_i, salt))
	return float(h % 10007) / 10007.0


## The shake to the finish pass: whole pixels, off with SCREEN SHAKE off.
func set_shake(sh: Vector2) -> void:
	shake = sh.round() if DisplaySettings.screen_shake else Vector2.ZERO
	stage.set2(&"shake", shake)


## The flash to the finish pass; with reduced flashes the frame-wide floor goes and it is capped.
func set_flash(fl: float, centre: Vector2, sy: float) -> void:
	flash = minf(fl, 0.35) if reduce else fl
	stage.set2(&"flash", flash)
	stage.set2(&"flash_floor", 0.0 if reduce else flash_floor)
	stage.set2(&"flash_sy", sy)
	stage.set2(&"centre", centre)
