class_name AshPortrait
extends Control

## Motion steps on `GameClock` at TICK_S: every change a held frame, 8 to 12 a second.
## Not a control: it ignores the mouse and nothing dismisses it but time.
## Why: docs/why/AshPortrait.md#ash-portrait

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
## Coming up and going are held steps of the tick, like a projector striking and cutting out.
const FADE_IN := [0.5, 1.0]
const FADE_OUT := [0.66, 0.33]
## The frames, by name, as `ash_face.py` lays them out.
enum Mouth { CLOSED, SLIGHT, OPEN, ROUND }
const BLINK := 4
## The art's own backdrop, for the row a slip uncovers.
const BACK := Color8(3, 7, 35)
const SLIP_LIGHT := Color(0.75, 0.91, 1.0, 0.18)
## The power-on chirp: `text_blip`, the second a minor third (2^(3/12)) up, dB.
const CHIRP := &"text_blip"
const CHIRP_UP := 1.189207
const CHIRP_DB := 0.0
## The power-down: `text_blip` reversed, played the same way.
const CHIRP_REV := &"text_blip_rev"
## The forward chirp's gap between its two blips, s (the power-on slip's two ticks).
const CHIRP_GAP := 0.2
const DESIGNATION := "A.S.H."
## Her voice starts this long after she appears, s: past the second chirp's
## click and most of its ring (measured: see THE SOUND above).
const VOICE_AT := 0.35
## A take's own silence after her last word, s (the takes were trimmed to 30 ms
## ahead and 80 ms after): the words end with the word, not the file.
const VOICE_TAIL_S := 0.1
## Once her voice has run out, the words stay at least this long, s (reduced
## motion shows them whole at once; they must not go before she has finished).
const VOICE_HOLD_S := 1.0

## The line she is saying, and its moment (for the harnesses).
var line := ""
var kind: StringName = &""
## A teaching line is held until the action is done, never on a timer or a click (Jon, Oct 22).
var held := false
## What she says when the take was recorded from a different script. Typing spans the shown words.
var spoken := ""
## Quiet (Oct 23, Jeremy): a repeated teaching line shows words at once, with no chirp or voice.
var quiet := false
## Holds VOICE_HOLD_S past her last word (Jon, Oct 20: the intro delay was far too long).
var quick := false
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
## The power-down's blips asked for, each [game s, pitch], and whether one was
## hushed by a cut (`AshTest`).
var rev_log: Array = []
var rev_hushed := false
## Voice length and the start and typing times, so `AshTest` can measure one against the other.
var voice := ""
var voice_secs := 0.0
var voice_started_at := -1.0
var typed_at := -1.0
var typed_for := -1.0
var _voice_at := INF

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
var _rev_step := 0
var _natural := false
static var _blip_s := -1.0
var _out_steps: Array = []
var _rng := RandomNumberGenerator.new()
## Set by `Ash` each frame: the hull failing (slips come twice as often).
var hurt := false
## Glitches in her voice take become one-tick slips, so the picture breaks with the sound.
var _glitch_at: Array = []
## How many of those slipped, for a harness.
var glitch_slips := 0


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


## Starts the power-on. `opts` for a teaching line: `voice`, `spoken` and `held`.
func say(what: String, k: StringName, opts: Dictionary = {}) -> void:
	# whatever she was saying, she is not now
	Audio.ash_voice_stop()
	line = what
	kind = k
	held = bool(opts.get("held", false))
	spoken = String(opts.get("spoken", ""))
	quick = bool(opts.get("quick", false))
	quiet = bool(opts.get("quiet", false))
	voice =String(opts["voice"]) if opts.has("voice") else AshLines.voice_path(what)
	if quiet:
		voice = ""
	voice_secs = 0.0
	voice_started_at = -1.0
	typed_at = -1.0
	typed_for = -1.0
	_voice_at = INF
	_text.rate = 0.0
	_layout()
	var now := GameClock.now()
	_born = now
	_tick_at = now
	_mouth = Mouth.CLOSED
	_blink = false
	_slip = {}
	_glitch_at.clear()
	glitch_slips = 0
	_settled.clear()
	frames_log.clear()
	_hold_until = INF
	_going_at = INF
	_second_chirp = false
	chirps = 0
	_rev_step = 0
	_natural = false
	rev_log.clear()
	rev_hushed = false
	_next_blink = now + _rng.randf_range(1.2, 3.0)
	phase = Phase.UP
	visible = true
	if quiet:
		# BACK QUIETLY: up as it was left, the words out, nothing announced
		modulate.a = 1.0
		_slip_ticks = 0
		_second_chirp = true
		_next_slip = now + _slip_gap() if _moving() else INF
		_start_words(now)
		_text.skip()
		_log_frame(now)
		queue_redraw()
		return
	if _moving():
		modulate.a = float(FADE_IN[0])
		_slip_ticks = 2
		_new_slip()
		_next_slip = now + _slip_gap()
	else:
		modulate.a = 1.0
		_slip_ticks = 0
		_next_slip = INF
	_chirp(1.0)
	if voice == "":
		_start_words(now)
	else:
		# nothing typed until she speaks, after the power-on
		_text.text = ""
		_text.skip()
		_voice_at = now + VOICE_AT
		# her take, glitched if the hull is failing, made on a worker meanwhile
		Audio.ash_voice_prepare(voice)
	_log_frame(now)
	queue_redraw()


## Her voice (if the line has one) and the words, together.
func _start_words(now: float) -> void:
	_voice_at = INF
	if voice != "":
		voice_secs = Audio.ash_voice(voice)
		if voice_secs > 0.0:
			voice_started_at = now
			for g: Dictionary in Audio.voice_glitches:
				_glitch_at.append(now + float(g.at))
			_text.rate = SignalText.rate_for(line, voice_secs - VOICE_TAIL_S)
	_text.text = line
	_text.play()
	typed_at = now
	phase = Phase.TYPING


## Fade out now (`quick`: the hints' or a drag's turn, faster). Sent off from
## outside, so no power-down (THE SOUND), and any already started is hushed.
func leave(quick: bool = false) -> void:
	if phase == Phase.GOING or phase == Phase.GONE:
		return
	if not _natural:
		_hush_rev()
	phase = Phase.GOING
	_going_at = GameClock.now()
	_voice_at = INF
	Audio.ash_voice_stop()
	if not _moving():
		_gone()
		return
	_out_steps = FADE_OUT.slice(FADE_OUT.size() - 1) if quick else FADE_OUT
	modulate.a = float(_out_steps[0])


## Gone this frame, no fade: the ship is lost, and the projection goes with it.
func cut() -> void:
	_hush_rev()
	_gone()


func _gone() -> void:
	phase = Phase.GONE
	visible = false
	modulate.a = 0.0
	_voice_at = INF
	Audio.ash_voice_stop()
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
	# the backing as tall as what it holds (the face keeps the frame's height; a
	# teaching line of five lines makes the frame taller, never narrower)
	var sz := size_for(line)
	size = sz
	_back.size = Vector2(TEXT_W, minf(sz.y, _words_h(line)))
	_name.position = Vector2(tx + PAD_X, PAD_Y - 1.0)
	_name.size = Vector2(TEXT_W - PAD_X * 2, 10.0)
	_text.position = Vector2(tx + PAD_X, PAD_Y + 12.0)
	_text.size = Vector2(TEXT_W - PAD_X * 2, sz.y - PAD_Y * 2 - 12.0)
	_text.custom_minimum_size = Vector2(TEXT_W - PAD_X * 2, 0.0)


## The words' backing for `what`: the designation, the lines and the padding, px.
static func _words_h(what: String) -> float:
	var lh := float(UITheme.pixel_font().get_height(UITheme.FS_SMALL)) + float(SignalText.LINE_GAP)
	return roundf(PAD_Y + 12.0 + lh * float(lines_for(what)) + PAD_Y - 2.0)


## The whole frame for `what`: W wide, and the face's height or the words', the
## taller (`Ash` finds her spot with it).
static func size_for(what: String) -> Vector2:
	return Vector2(W, maxf(float(H), _words_h(what)))


## How many lines `what` takes in the words' column (Ash keeps them to four;
## a "\n" starts a new one, as `SignalText` breaks it).
static func lines_for(what: String) -> int:
	var f := UITheme.pixel_font()
	var w := float(TEXT_W - PAD_X * 2)
	var n := 0
	for para in what.split("\n"):
		n += 1
		var cur := ""
		for word in para.split(" "):
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


## One blip of the power-down.
func _rev_chirp(pitch: float, at: float) -> void:
	rev_log.append([at, pitch])
	Audio.play(CHIRP_REV, 0.0, 0, CHIRP_DB, pitch)


func _hush_rev() -> void:
	if _rev_step > 0 and not rev_hushed:
		rev_hushed = true
		Audio.hush([CHIRP_REV] as Array[StringName], Audio.VOICE_CUT_MS)


## The blip's length, s (the file, read once; headless too).
static func blip_secs() -> float:
	if _blip_s < 0.0:
		var st := load(Audio.SFX_PATH % CHIRP_REV) as AudioStream
		_blip_s = st.get_length() if st != null else 0.3
	return _blip_s


## The first blip's reverse ends at `gone`, the second CHIRP_GAP before. None under reduced motion.
func _power_down(now: float) -> void:
	if quiet:
		return
	var fade := float(FADE_OUT.size()) * TICK_S if _moving() else 0.0
	var gone := _hold_until + fade
	var b := blip_secs()
	if _rev_step == 0:
		if not _moving():
			_rev_step = 1
		elif now >= gone - CHIRP_GAP - b / CHIRP_UP - 0.0001:
			_rev_step = 1
			_rev_chirp(CHIRP_UP, now)
	if _rev_step == 1 and now >= gone - b - 0.0001:
		_rev_step = 2
		_rev_chirp(1.0, now)


func _process(_d: float) -> void:
	if phase == Phase.GONE:
		return
	var now := GameClock.now()
	if phase == Phase.GOING:
		var j := int(floorf((now - _going_at) / TICK_S + 0.0001))
		if j >= _out_steps.size():
			_gone()
			return
		modulate.a = float(_out_steps[j])
	elif _moving():
		var i := int(floorf((now - _born) / TICK_S + 0.0001))
		modulate.a = float(FADE_IN[mini(i, FADE_IN.size() - 1)])
	if phase == Phase.UP and now >= _voice_at - 0.0001:
		_start_words(now)
	if _text.done and phase == Phase.TYPING:
		phase = Phase.HOLDING
		typed_for = now - typed_at
		_hold_until = now + HOLD_MIN_S + HOLD_PER_CHAR_S * float(line.length())
		if voice_started_at >= 0.0:
			_hold_until = maxf(_hold_until, voice_started_at + voice_secs + VOICE_HOLD_S)
			if quick:
				_hold_until = maxf(now, voice_started_at + voice_secs + VOICE_HOLD_S)
		if held:
			_hold_until = INF
	if phase == Phase.HOLDING:
		_power_down(now)
	if phase == Phase.HOLDING and now >= _hold_until:
		_natural = true
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
			if m == _mouth:
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
	elif _moving() and not _glitch_at.is_empty() and at >= float(_glitch_at[0]) - 0.0001 \
			and phase != Phase.GOING:
		while not _glitch_at.is_empty() and at >= float(_glitch_at[0]) - 0.0001:
			_glitch_at.pop_front()
		glitch_slips += 1
		_slip_ticks = 1
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
