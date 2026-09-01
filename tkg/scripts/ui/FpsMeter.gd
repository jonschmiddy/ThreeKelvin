class_name FpsMeter
extends Label

## Frames per second, bottom right.
##
## RESTORED AS AN OVERLAY, and the overlay part is the whole point. There was a
## frame counter on `HudBar` until `872f546` removed it, and that commit is worth
## reading before putting one back — it was not removed for being useless, it was
## removed for being A CHILD OF THE ROW:
##
##   "It was the last thing on the row, so it was what the row lost when the row
##    ran out — clipped at a standard window size... Reserving its width put the
##    row at 948 against 944 available and it was STILL clipped."
##
## And the reason nobody caught it earlier, which is the good part: its label was
## built empty and filled by `_process`, so its minimum width at build time was
## NOTHING. The row fitted, and then the first frame put "120 FPS" into space
## nobody had allocated.
##
## So this is not on the row. It is top-level, positioned against the viewport,
## and takes part in no layout at all — the bar cannot lose fifty pixels to
## something that never asks it for any.
##
## A SETTING, NOT A DEV FLAG. It rode on `DevMode` for one commit, which meant a
## player could not read their frame rate without also unlocking the card gallery
## and the whole star chart — DevMode's own tooltip says exactly that. A frame
## counter is a diagnostic, not a cheat: a tester reporting "the chart felt
## choppy" is worth far more with a number attached, and that should not cost
## them the game's secrets. `DisplaySettings.fps_meter` owns it.
##
## BUILT ALWAYS, SHOWN CONDITIONALLY, so the toggle takes effect immediately
## rather than at the next launch.

## How often the reading refreshes. Frames per second read every frame is a
## number that never settles long enough to be read; a quarter second was the
## original cadence and it was right.
const TICK := 0.25

## Where the reading stops being fine. The colours are the originals.
const WARN := 50
const BAD := 30

## Clearance from the corner, in viewport pixels.
const INSET := Vector2(6.0, 4.0)

var _t: float = 0.0


func _ready() -> void:
	# TOP LEVEL, so no container can lay it out, size it, or push anything aside
	# to make room for it. The same trick the ship screen's perk box uses, for
	# the same reason.
	set_as_top_level(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_override("font", UITheme.pixel_font())
	add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	z_index = 4096
	text = ""
	visible = DisplaySettings.fps_meter
	Sig.fps_meter_changed.connect(func(on: bool) -> void: visible = on)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _t < TICK:
		return
	_t = 0.0
	var f := Engine.get_frames_per_second()
	var col := UITheme.COLD
	if f < BAD:
		col = UITheme.BAD
	elif f < WARN:
		col = UITheme.WARN
	text = "%d FPS" % f
	add_theme_color_override("font_color", col)
	# PLACED EVERY TICK RATHER THAN ANCHORED. A top-level Control is excluded
	# from its parent's layout, and that also means no anchor preset is applied
	# to it — so the corner is arithmetic. It has to be redone each tick because
	# the width changes when the reading goes from two digits to three.
	#
	# BOTTOM RIGHT, the one corner with nothing in it. The top right is the HUD
	# row: CARDS, MODULES, ARCHIVE and HISTORY run to within a few pixels of the
	# edge, and that crowding is precisely what got the last frame counter
	# deleted. Down here it overlaps nothing on any screen.
	var vp := get_viewport_rect().size
	size = get_combined_minimum_size()
	position = vp - size - INSET
