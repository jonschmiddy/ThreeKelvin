class_name FpsMeter
extends Label

## A top-level overlay, not on the HUD row, which lost its width; a setting, not a dev flag.
## Why: docs/why/FpsMeter.md#frame-meter

## A rate read every frame never settles long enough to read; a quarter second was right.
const TICK := 0.25

## Where the reading stops being fine. The colours are the originals.
const WARN := 50
const BAD := 30

## Inset is -1 at the bottom: the box is taller than the ink, which sits on rows 534 to 538.
const INSET := Vector2(6.0, -1.0)

## Four quarter-second slots keep the last second's worst and mean as four numbers.
const SLOTS := 4
var _worst := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var _sum := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var _count := PackedInt32Array([0, 0, 0, 0])
var _slot := 0
## Wall clock, not `delta`, which `Engine.time_scale` shrinks in a hit's slow motion.
var _last_us := 0
var _tick_us := 0


func _ready() -> void:
	# Top level, so no container can lay it out or push anything aside, like the perk box.
	set_as_top_level(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_override("font", UITheme.pixel_font())
	add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	z_index = 4096
	text = ""
	visible = DisplaySettings.fps_meter
	Sig.fps_meter_changed.connect(func(on: bool) -> void: visible = on)


func _process(_delta: float) -> void:
	if not visible:
		if _last_us != 0:
			_reset()
		return
	var now := Time.get_ticks_usec()
	if _last_us == 0:
		_last_us = now
		_tick_us = now
		return
	var ms := float(now - _last_us) / 1000.0
	_last_us = now
	_worst[_slot] = maxf(_worst[_slot], ms)
	_sum[_slot] += ms
	_count[_slot] += 1
	if now - _tick_us < int(TICK * 1000000.0):
		return
	_tick_us = now
	var worst := 0.0
	var total := 0.0
	var frames := 0
	for i in SLOTS:
		worst = maxf(worst, _worst[i])
		total += _sum[i]
		frames += _count[i]
	_slot = (_slot + 1) % SLOTS
	_worst[_slot] = 0.0
	_sum[_slot] = 0.0
	_count[_slot] = 0
	var f := Engine.get_frames_per_second()
	var col := UITheme.COLD
	if f < BAD:
		col = UITheme.BAD
	elif f < WARN:
		col = UITheme.WARN
	text = "%d FPS  %.1f MS  WORST %.1f MS" % [f, total / float(maxi(frames, 1)), worst]
	add_theme_color_override("font_color", col)
	# Placed every tick as top-level controls get no anchors; bottom right, as the top is crowded.
	# Why: docs/why/FpsMeter.md#placement
	var vp := get_viewport_rect().size
	size = get_combined_minimum_size()
	position = vp - size - INSET


## Hidden: the next reading starts from nothing, so a second spent hidden (or
## the frames before it) never shows as the worst frame when it comes back.
func _reset() -> void:
	_last_us = 0
	_tick_us = 0
	for i in SLOTS:
		_worst[i] = 0.0
		_sum[i] = 0.0
		_count[i] = 0
