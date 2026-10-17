class_name AshPortrait
extends Control

## A.S.H. SPEAKING (`Ash` decides when and where): her hologram face, with the
## line arriving beside it in the event band's signal type (`SignalText`), under
## her designation. It comes up, the line types out, it holds long enough to
## read, and it fades.
##
## THE FACE IS ONE FILE, `art/ash/face.png`: eight 64x64 frames in a row --
## closed, slight, open, round, then the same four with her eyes shut -- made by
## `art/tools/ash_face.py` from the frames hand-drawn on B15. Swapping her face
## is swapping that file. Drawn at the game's own pixel (64 game px, 128 on a
## 1080p screen), at whole-pixel places, never scaled or filtered.
##
## HOW SHE MOVES, all of it on `GameClock` (a film runs it at the film's speed),
## stepped TICK_S at a time so every change is a held frame and no faster than
## the tick (Jon judges motion per second; the fire ruling put living things at
## 8-12 changes a second):
##   - THE MOUTH FOLLOWS THE LETTERS: each tick it takes the shape of the last
##     letter that settled in that tick (a vowel open, o/u/w/y round, m/b/p
##     shut, any other letter slight; a space or a mark shut), and a shape the
##     same as the tick before gives way to the next one down so the mouth does
##     not freeze on a long vowel run. Shut once the line is out.
##   - SHE BLINKS for one tick every 2.2 to 5.7 s.
##   - THE HOLOGRAM SLIPS: a band of one to three rows shifted a whole pixel
##     sideways for one tick, with a faint lit row over it, every 0.9 to 3.5 s
##     while she talks and every 2 to 6 s while she holds; twice as often with
##     the hull failing (`docs/ash.md`: "the image breaks up"). Two ticks of it
##     as she comes up, which is her power-on.
## Reduced motion keeps the face and the words and drops the slips and the fades
## (the line arrives whole, so the mouth stays shut).
##
## IT IS NOT A CONTROL, and does not look like one: no plate edge, no hover, no
## hand; it ignores the mouse, so a click lands on whatever is under it. The
## words sit on the dim edgeless backing the goal line uses (an edged box is
## what this game's buttons look like). Nothing dismisses it but time.
##
## THE SOUND, from what is already in the game (voice comes later): two of the
## event text's own `text_blip`, the second a minor third up, at her appearance
## and at the end of the power-on slip, a little under the text's level.

const SHEET := "res://art/ash/face.png"
const FACE := 64
## The words' column, px, and the air between it and the face.
const TEXT_W := 188
const GAP := 4
## The backing's padding round the words, px.
const PAD_X := 5
const PAD_Y := 4
const W := FACE + GAP + TEXT_W
const H := FACE
## One held frame, s: 10 a second at most.
const TICK_S := 0.1
## How long the line stays up once it has all arrived: a floor, plus a reading
## allowance per letter, s.
const HOLD_MIN_S := 2.6
const HOLD_PER_CHAR_S := 0.035
const FADE_IN_S := 0.15
const FADE_OUT_S := 0.3
## The frames, by name, as `ash_face.py` lays them out.
enum Mouth { CLOSED, SLIGHT, OPEN, ROUND }
const BLINK := 4
## The art's own backdrop, for the row a slip uncovers.
const BACK := Color8(3, 7, 35)
const SLIP_LIGHT := Color(0.75, 0.91, 1.0, 0.18)
## The power-on chirp: `text_blip`, the second a minor third (2^(3/12)) up, dB.
const CHIRP := &"text_blip"
const CHIRP_UP := 1.189207
const CHIRP_DB := -3.0
const DESIGNATION := "A.S.H."

## The line she is saying, and its moment (for the harnesses).
var line := ""
var kind: StringName = &""
## Mirror: the face on the right, the words on its left.
var mirrored := false
## Up, typing, holding, going, gone.
enum Phase { UP, TYPING, HOLDING, GOING, GONE }
var phase: Phase = Phase.GONE
## Every frame index shown, with the game time it came up (for `AshTest`: the
## changes a second are counted off this).
var frames_log: Array = []
## Chirps asked for (`Audio` is off headless; `AshTest` counts these).
var chirps := 0

var _sheet: Texture2D
var _back: Panel
var _name: Label
var _text: SignalText
var _mouth: int = Mouth.CLOSED
var _blink := false
var _slip := {}            # {y, h, dx} while a band is slipped
var _tick_at := 0.0
var _born := 0.0
var _next_blink := 0.0
var _next_slip := 0.0
var _slip_ticks := 0
var _settled: Array = []   # letters settled since the last tick
var _hold_until := INF
var _going_at := INF
var _second_chirp := false
var _rng := RandomNumberGenerator.new()
## Set by `Ash` each frame: the hull failing (slips come twice as often).
var hurt := false


func _init() -> void:
	name = "AshPortrait"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	size = Vector2(W, H)
	_sheet = load(SHEET) as Texture2D
	_rng.randomize()
	_back = Panel.new()
	_back.add_theme_stylebox_override("panel",
		UITheme.flat(Color(UITheme.VOID, 0.72), Color(0, 0, 0, 0), 0, 0, 0))
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	_name = UITheme.body(DESIGNATION, UITheme.COLD, UITheme.FS_SMALL)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)
	_text = SignalText.new()
	_text.sound = false
	_text.ink = UITheme.ICE
	_text.size_px = UITheme.FS_SMALL
	_text.char_settled.connect(func(_i: int, ch: String) -> void: _settled.append(ch))
	add_child(_text)


## Say `what` (one of `AshLines`' moments, `k`). Starts the power-on.
func say(what: String, k: StringName) -> void:
	line = what
	kind = k
	_layout()
	_text.text = what
	var now := GameClock.now()
	_born = now
	_tick_at = now
	_mouth = Mouth.CLOSED
	_blink = false
	_slip = {}
	_settled.clear()
	frames_log.clear()
	_hold_until = INF
	_going_at = INF
	_second_chirp = false
	chirps = 0
	_next_blink = now + _rng.randf_range(1.2, 3.0)
	phase = Phase.UP
	visible = true
	if _moving():
		modulate.a = 0.0
		_slip_ticks = 2
		_new_slip()
		_next_slip = now + _slip_gap()
	else:
		modulate.a = 1.0
		_slip_ticks = 0
		_next_slip = INF
	_chirp(1.0)
	_text.play()
	phase = Phase.TYPING
	_log_frame(now)
	queue_redraw()


## Fade out now (`quick`: the hints' or a drag's turn, faster).
func leave(quick: bool = false) -> void:
	if phase == Phase.GOING or phase == Phase.GONE:
		return
	phase = Phase.GOING
	_going_at = GameClock.now()
	if not _moving():
		cut()
		return
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE_OUT_S * (0.4 if quick else 1.0))
	t.tween_callback(cut)


## Gone this frame, no fade: the ship is lost, and the projection goes with it.
func cut() -> void:
	phase = Phase.GONE
	visible = false
	modulate.a = 0.0
	_text.skip()


func speaking() -> bool:
	return phase == Phase.UP or phase == Phase.TYPING or phase == Phase.HOLDING


## The whole of what it covers, global.
func rect() -> Rect2:
	return get_global_rect() if visible else Rect2()


## Where the face is, global.
func face_rect() -> Rect2:
	var x := float(TEXT_W + GAP) if mirrored else 0.0
	return Rect2(global_position + Vector2(x, 0.0), Vector2(FACE, FACE))


## The frame on screen now, 0..7.
func frame() -> int:
	return _mouth + (BLINK if _blink else 0)


func _moving() -> bool:
	return Router.animating()


func _layout() -> void:
	var tx := 0.0 if mirrored else float(FACE + GAP)
	_back.position = Vector2(tx, 0.0)
	_back.size = Vector2(TEXT_W, H)
	_name.position = Vector2(tx + PAD_X, PAD_Y - 1.0)
	_name.size = Vector2(TEXT_W - PAD_X * 2, 10.0)
	_text.position = Vector2(tx + PAD_X, PAD_Y + 12.0)
	_text.size = Vector2(TEXT_W - PAD_X * 2, H - PAD_Y * 2 - 12.0)
	_text.custom_minimum_size = Vector2(TEXT_W - PAD_X * 2, 0.0)


## How many lines `what` takes in the words' column (Ash keeps them to four).
static func lines_for(what: String) -> int:
	var f := UITheme.pixel_font()
	var w := float(TEXT_W - PAD_X * 2)
	var n := 1
	var cur := ""
	for word in what.split(" "):
		var trial := word if cur == "" else cur + " " + word
		if cur != "" and f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x > w:
			n += 1
			cur = word
		else:
			cur = trial
	return n


func _slip_gap() -> float:
	var g := _rng.randf_range(0.9, 3.5) if phase == Phase.TYPING or phase == Phase.UP \
		else _rng.randf_range(2.0, 6.0)
	return g * (0.5 if hurt else 1.0)


func _new_slip() -> void:
	_slip = {y = _rng.randi_range(8, 53), h = _rng.randi_range(1, 3),
		dx = -1 if _rng.randf() < 0.5 else 1}


func _chirp(pitch: float) -> void:
	chirps += 1
	Audio.play(CHIRP, 0.0, 0, CHIRP_DB, pitch)


func _process(_d: float) -> void:
	if phase == Phase.GONE:
		return
	var now := GameClock.now()
	if phase != Phase.GOING and _moving():
		modulate.a = clampf((now - _born) / FADE_IN_S, 0.0, 1.0)
	if _text.done and phase == Phase.TYPING:
		phase = Phase.HOLDING
		_hold_until = now + HOLD_MIN_S + HOLD_PER_CHAR_S * float(line.length())
	if phase == Phase.HOLDING and now >= _hold_until:
		leave()
	var changed := false
	while now - _tick_at >= TICK_S - 0.0001:
		_tick_at += TICK_S
		changed = _tick(_tick_at) or changed
	if changed:
		_log_frame(now)
		queue_redraw()


## One held frame: the mouth, a blink, a slip. True if anything changed.
func _tick(at: float) -> bool:
	var before := [frame(), _slip.duplicate()]
	# THE MOUTH: the last letter this tick, or shut
	var m: int = Mouth.CLOSED
	if phase == Phase.TYPING and not _text.done:
		if not _settled.is_empty():
			m = shape_for(String(_settled.back()))
			if m == _mouth and m != Mouth.CLOSED:
				m = Mouth.SLIGHT if m != Mouth.SLIGHT else Mouth.CLOSED
	_settled.clear()
	_mouth = m
	# THE BLINK: one tick
	_blink = not _blink and at >= _next_blink
	if _blink:
		_next_blink = at + _rng.randf_range(2.2, 5.7)
	# THE SLIP: its ticks, then the next one; the power-on's second chirp when
	# the power-on slip lets go
	if _slip_ticks > 0:
		_slip_ticks -= 1
		if _slip_ticks == 0:
			_slip = {}
			if not _second_chirp:
				_second_chirp = true
				_chirp(CHIRP_UP)
		else:
			_new_slip()
	elif _moving() and at >= _next_slip and phase != Phase.GOING:
		_slip_ticks = 1
		_new_slip()
		_next_slip = at + _slip_gap()
	return before[0] != frame() or before[1] != _slip


## A letter's mouth.
static func shape_for(ch: String) -> int:
	var c := ch.to_lower()
	if c == "" or c == " ":
		return Mouth.CLOSED
	if "aei".contains(c):
		return Mouth.OPEN
	if "ouwy".contains(c):
		return Mouth.ROUND
	if "mbp".contains(c):
		return Mouth.CLOSED
	if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
		return Mouth.SLIGHT
	return Mouth.CLOSED


func _log_frame(now: float) -> void:
	frames_log.append([now, frame(), not _slip.is_empty()])


func _draw() -> void:
	if _sheet == null:
		return
	var fx := float(TEXT_W + GAP) if mirrored else 0.0
	var src := Rect2(float(frame() * FACE), 0.0, FACE, FACE)
	draw_texture_rect_region(_sheet, Rect2(fx, 0.0, FACE, FACE), src)
	if _slip.is_empty():
		return
	var y0 := int(_slip.y)
	var h := int(_slip.h)
	var dx := int(_slip.dx)
	# the band's rows, a whole pixel sideways, the row they leave the art's own dark
	draw_rect(Rect2(fx, float(y0), FACE, float(h)), BACK)
	var sx := 0.0 if dx > 0 else 1.0
	draw_texture_rect_region(_sheet, Rect2(fx + maxf(0.0, float(dx)), float(y0), FACE - 1, float(h)),
		Rect2(src.position.x + sx, float(y0), FACE - 1, float(h)))
	draw_rect(Rect2(fx, float(y0), FACE, 1.0), SLIP_LIGHT)
