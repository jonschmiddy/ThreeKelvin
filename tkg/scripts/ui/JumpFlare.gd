class_name JumpFlare
extends Control

## Readouts are painted over the ship, not stacked, to save arena rows. Not a drop target.
## The jump light is cold, not ember, so it is not mistaken for another gun.
## Why: docs/why/JumpFlare.md#partner-slot

## Long enough to be an event, short enough that four of them staggered do
## not turn arriving into a cutscene.
const LIFE := 0.40
## The moment the hull changes hands. The flash is at its widest here, so
## the swap happens behind the brightest frame and is never seen.
const PEAK := 0.42
const CORE := Color("#e4f2ff")
## Wide enough to be a column, not a rule: 20 px against a 208 px slot.
const MAX_W := 20.0
## Width peaks exactly at PEAK, the hull's swap frame, so the swap hides in the flash.
const OPEN := 0.22
const SHUT := 0.80

signal peaked()
signal finished()

## Column position as a slot fraction; your hull is left-biased, so a beam elsewhere misses.
var centre: float = 0.5

var _t: float = -1.0
var _delay: float = 0.0
var _fired: bool = false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	set_process(false)

func play(delay: float = 0.0) -> void:
	_t = 0.0
	_delay = maxf(0.0, delay)
	_fired = false
	visible = true
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if _delay > 0.0:
		_delay -= delta
		return
	_t += delta / LIFE
	if not _fired and _t >= PEAK:
		_fired = true
		peaked.emit()
	if _t >= 1.0:
		_t = -1.0
		visible = false
		set_process(false)
		finished.emit()
		return
	queue_redraw()

func _draw() -> void:
	if _t < 0.0 or _delay > 0.0:
		return
	var t := clampf(_t, 0.0, 1.0)
	var cx := roundf(size.x * centre)

	# Height: opens from the middle, holds, then snaps shut. The hold is
	# what makes it a place rather than a flash.
	var tall := 1.0
	if t < OPEN:
		tall = t / OPEN
	elif t > SHUT:
		tall = 1.0 - (t - SHUT) / (1.0 - SHUT)
	var h := roundf(size.y * clampf(tall, 0.0, 1.0))
	if h < 1.0:
		return
	var y0 := roundf((size.y - h) * 0.5)

	# Two width segments meeting at PEAK, not one sine, which peaked at 0.62 against 0.42.
	# Why: docs/why/JumpFlare.md#jump-flare
	var flare := 0.0
	if t <= PEAK:
		flare = smoothstep(OPEN, PEAK, t)
	else:
		flare = 1.0 - smoothstep(PEAK, SHUT, t)
	var w := 1.0 + roundf(flare * MAX_W)

	# Two planes, stepped. A pixel is lit or it is not — see CombatFx.
	if w > 3.0:
		draw_rect(Rect2(Vector2(cx - roundf(w * 0.5), y0), Vector2(w, h)),
			UITheme.ICE if flare > 0.35 else UITheme.CHILL, true)
	var core_w := maxf(1.0, roundf(w * 0.3))
	draw_rect(Rect2(Vector2(cx - roundf(core_w * 0.5), y0), Vector2(core_w, h)),
		CORE if flare > 0.25 else UITheme.ICE, true)

	# The spill. Two dashed streaks at the waist, thinning outward, which is
	# what stops the column reading as a rectangle somebody drew.
	if flare <= 0.4:
		return
	var reach := roundf(flare * 34.0)
	var my := roundf(size.y * 0.5)
	for i in int(reach):
		if i % 3 == 2 or i > reach - 5:
			continue
		var col := CORE if float(i) < reach * 0.3 else UITheme.CHILL
		draw_rect(Rect2(Vector2(cx + w * 0.5 + i, my), Vector2.ONE), col, true)
		draw_rect(Rect2(Vector2(cx - w * 0.5 - i - 1, my), Vector2.ONE), col, true)
