class_name SignalText
extends Control

## TEXT THAT ARRIVES LIKE A SIGNAL (Jon: "let's have the text read in letter by
## letter ... like a signal transmission? IDK something stylized"). Each
## character comes in as one or two scrambled glyphs from the pixel font before
## it settles on the true letter, with a block cursor at the leading edge and,
## now and then, a short dropout. At `cps` a second, punctuation holding a beat.
##
## THE LAYOUT NEVER MOVES: the whole text is broken into lines and measured
## before a character shows, so the control is its full height from the start
## and nothing reflows while it reveals. Drawn by hand in the game's pixel face
## (`UITheme.pixel_font`), one character at a time.
##
## `skip()` finishes it at once; reduced motion (`Router.animating`) shows it
## whole.
##
## THE SOUND is Jon's pick from the audition page: "cps 40 · A blip_5 every 3,
## ±100c, 0 dB · B off · C off". Every third settled letter plays `text_blip`
## (spaces do not count), pitch spread ±100 cents, at its levelled gain, with at
## most two in the air (`Audio.play_capped`). Only a settling letter makes a
## blip. So `skip()` finishes silently and also fades any tail still ringing,
## and reduced motion, which has no reveal, has no blips.

signal char_settled(index: int, ch: String)
signal line_settled(line: int)
signal finished

## Characters a second -- THE ONE DIAL for the reveal's speed (Jon: "have the
## letters arrive more slowly"; he set 40 by ear on the audition page) -- and
## the beat a punctuation mark holds, s.
static var cps := 40.0
const PAUSE := {".": 0.09, "!": 0.09, "?": 0.09, ",": 0.03, ";": 0.05, ":": 0.05}
## How many characters past the settled edge show as noise, and how often
## their glyph changes, s.
const NOISE_N := 2
const NOISE_S := 0.035
## What the noise is drawn from: the face's own capitals, digits and marks.
const NOISE := "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789#%&*+=/<>"
## A dropout's chance per settled character, and how long it lasts, s.
const DROP_P := 0.012
const DROP_S := 0.06
const LINE_GAP := 3
## The blip: which sound, every how many letters, its pitch spread as a
## pitch_scale (2^(1/12) - 1, so +100 cents up and -106 down), and how many may
## ring at once. `sound` off keeps a reveal silent.
const BLIP := &"text_blip"
const BLIP_EVERY := 3
const BLIP_PITCH := 0.0595
const BLIP_VOICES := 2
var sound := true
var _letters := 0
## Blips this reveal has asked for (`localeventtest` counts them headless,
## where `Audio` is off).
var blips := 0

var text := "":
	set(v):
		text = v
		_lines.clear()
		_relayout()
var ink: Color = UITheme.CHILL
var size_px: int = UITheme.FS_BODY

## Settled characters (a float, so the clock can carry fractions).
var shown := 0.0
var done := true
var _lines: Array = []       # [{s: start index, t: text, x: PackedFloat32Array}]
var _laid_w := -1.0
var _hold := 0.0
var _noise_t := 0.0
var _noise: Array = []
var _drop := 0.0
var _rng := RandomNumberGenerator.new()
var _last_line := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rng.seed = 7


## Start revealing (or, without motion, show it all).
func play() -> void:
	shown = 0.0
	done = false
	_hold = 0.0
	_last_line = -1
	_letters = 0
	blips = 0
	if not Router.animating():
		skip()
	queue_redraw()


## Finish now.
func skip() -> void:
	if done and shown >= text.length():
		return
	var cut := not done
	shown = float(text.length())
	done = true
	_noise.clear()
	if cut and sound:
		Audio.hush([BLIP] as Array[StringName], 60)
	queue_redraw()
	finished.emit()


func _font() -> Font:
	return UITheme.pixel_font()


func _line_h() -> int:
	return int(_font().get_height(size_px)) + LINE_GAP


## Words into lines at this width, each character's x measured once.
func _relayout() -> void:
	var w := size.x
	if w <= 1.0:
		w = maxf(custom_minimum_size.x, 200.0)
	_laid_w = w
	_lines.clear()
	var f := _font()
	var words := text.split(" ")
	var line := ""
	var start := 0
	var at := 0
	for wi in words.size():
		var word: String = words[wi]
		var trial := word if line == "" else line + " " + word
		if line != "" and f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > w:
			_lines.append(_measure(start, line))
			start = at
			line = word
		else:
			line = trial
		at += word.length() + 1
	if line != "" or _lines.is_empty():
		_lines.append(_measure(start, line))
	custom_minimum_size.y = float(_lines.size() * _line_h())
	queue_redraw()


func _measure(s: int, t: String) -> Dictionary:
	var xs := PackedFloat32Array()
	var f := _font()
	var x := 0.0
	for i in t.length():
		xs.append(x)
		x += f.get_char_size(t.unicode_at(i), size_px).x
	xs.append(x)
	return {s = s, t = t, x = xs}


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and absf(size.x - _laid_w) > 0.5:
		_relayout()


func _process(delta: float) -> void:
	if done:
		return
	var n := text.length()
	if _hold > 0.0:
		_hold -= delta
	else:
		var before := int(shown)
		shown = minf(shown + cps * delta, float(n))
		for k in range(before, int(shown)):
			var ch := text.substr(k, 1)
			char_settled.emit(k, ch)
			if sound and ch != " ":
				_letters += 1
				if (_letters - 1) % BLIP_EVERY == 0:
					blips += 1
					Audio.play_capped(BLIP, BLIP_PITCH, BLIP_VOICES)
			var li := _line_of(k)
			if li != _last_line and _last_line >= 0:
				line_settled.emit(_last_line)
			_last_line = li
			if PAUSE.has(ch):
				shown = float(k + 1)
				_hold = float(PAUSE[ch])
				break
			if _rng.randf() < DROP_P:
				_drop = DROP_S
	if _drop > 0.0:
		_drop -= delta
	_noise_t -= delta
	if _noise_t <= 0.0:
		_noise_t = NOISE_S
		_noise.clear()
		for i in NOISE_N:
			_noise.append(NOISE[_rng.randi() % NOISE.length()])
	if shown >= float(n):
		done = true
		_noise.clear()
		if _last_line >= 0:
			line_settled.emit(_last_line)
		finished.emit()
	queue_redraw()


func _line_of(k: int) -> int:
	for li in _lines.size():
		var L: Dictionary = _lines[li]
		if k < int(L.s) + String(L.t).length() + 1:
			return li
	return _lines.size() - 1


func _draw() -> void:
	var f := _font()
	var lh := _line_h()
	var asc := f.get_ascent(size_px)
	var edge := int(shown)
	var drop_from := edge - 3 if _drop > 0.0 else edge
	for li in _lines.size():
		var L: Dictionary = _lines[li]
		var s := int(L.s)
		var t: String = L.t
		var xs: PackedFloat32Array = L.x
		var y := float(li * lh) + asc
		for i in t.length():
			var k := s + i
			var ch := t.substr(i, 1)
			if k < edge:
				if k >= drop_from:
					continue
				draw_string(f, Vector2(xs[i], y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, ink)
			elif not done and k < edge + _noise.size():
				if ch != " ":
					draw_string(f, Vector2(xs[i], y), String(_noise[k - edge]), HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(ink, 0.55))
			elif not done and k == edge + _noise.size():
				# the block cursor at the leading edge
				var cw := f.get_char_size(0x4D, size_px).x
				draw_rect(Rect2(xs[i], y - asc, maxf(cw - 1.0, 3.0), float(lh - LINE_GAP)), Color(ink, 0.8))
