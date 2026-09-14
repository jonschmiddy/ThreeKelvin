class_name JumpFx
extends Control

## Twenty-one ways for a ship to not be here any more.
##
## The original was one: `EncounterView.JumpFlare`, a vertical column of light
## that opens, flashes and shuts. It is still the first entry here and still the
## default. The rest exist because a jump is the most-repeated moment in the
## game after a card play, and the one worth being sure about.
##
## TWENTY OF THEM SHARE A CLOCK, and that is not a detail. `peaked` fires at
## PEAK for all of those, because that is the frame the hull hides, the frame
## the jump is committed, and the frame the screen swaps — see
## `SectorScreen._pulse_out`. So picking between them picks a LOOK and nothing
## else: none can be better or worse timed than another, and swapping one for
## another cannot desynchronise anything.
##
## `hyperdrive` is the twenty-first and the exception, because it is not an
## overlay at all — it takes the hull apart. It needs its own, longer clock, and
## `life()` and `peak()` exist so that everything downstream asks rather than
## assumes. See MELTING below.
##
## NOTHING WARM. `UITheme` rules that EMBER, FLARE and HOT mean something is
## emitting heat, "never as decoration" — and a jump is the one bright thing in
## this game that is not combustion. Everything here is drawn in the same cold
## white the original column used.
##
## Set `JumpFx.style` to choose. It is static because it is a setting rather
## than a property of any one ship: four hulls jumping out of a convoy should
## not jump out four different ways.

## Long enough to be an event, short enough that four of them staggered do not
## turn arriving into a cutscene. Straight from JumpFlare, which tuned it.
const LIFE := 0.40
## The moment the hull changes hands. Every style is built to be at its loudest
## here, so the swap happens behind the brightest frame and is never seen.
const PEAK := 0.42

const CORE := Color("#e4f2ff")
const COLD := Color("#9fd0e4")

## In pick order, which is roughly loudest to quietest.
const STYLES: Array[StringName] = [
	&"column", &"twin", &"cross", &"slit", &"lance",
	&"ring", &"ripple", &"shock", &"halo", &"burst",
	&"bloom", &"streak", &"wake", &"bar", &"curtain",
	&"pinch", &"spark", &"ghost", &"stutter", &"wink",
	&"hyperdrive",
]

## THE ONE THAT IS NOT AN OVERLAY, and the one exception to the shared clock.
##
## Every other style here draws over a ship that is still a ship. This one takes
## the hull apart -- `ShipView` drops its rows until nothing is left but a line
## of light along its own centre -- and then the line runs. That is three
## movements where the others have one, so it needs longer, and it has to hold
## the screen until the beam is gone rather than swapping behind a flash.
##
## Which is why `melts()` exists: the caller asks whether a style wants the hull
## dismantled rather than hidden, instead of checking for a name.
const MELTING: Array[StringName] = [&"hyperdrive"]
const LONG_LIFE := 0.86
## Late, because the spark it ends on has to be seen before the screen swaps
## behind it. The commit lands as the last of it goes out.
const LONG_PEAK := 0.93
## The three movements, as fractions of this style's own life: the hull going
## to light, the beam running, and the spark it arrives in.
const MELT_TO := 0.34
const ZIP_TO := 0.60
## Where the beam ends up, as a fraction of the hull's width right of centre.
## Just past the nose -- far enough to read as having gone somewhere, near
## enough that the spark is still beside the ship rather than out in the
## scenery.
const HYPER_DEST := 0.62

func _name() -> StringName:
	return STYLES[clampi(style, 0, STYLES.size() - 1)]

func melts() -> bool:
	return _name() in MELTING

func life() -> float:
	return LONG_LIFE if melts() else LIFE

func peak() -> float:
	return LONG_PEAK if melts() else PEAK

## Which one the game plays. See the class note: a setting, not a property.
##
## `hyperdrive`. The column was the default for as long as it was the only one,
## and it is still index 0 if this wants putting back.
static var style: int = 20

signal peaked()
signal finished()

## Where the column stands, as a fraction of the box's width.
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
	_t += delta / life()
	if not _fired and _t >= peak():
		_fired = true
		peaked.emit()
	if _t >= 1.0:
		_t = -1.0
		visible = false
		set_process(false)
		finished.emit()
		return
	queue_redraw()

## How loud the effect is right now: nothing, up to one at PEAK, nothing again.
## Eased so the rise is quicker than the fall, which is what a flash does.
func _amp() -> float:
	if _t < 0.0:
		return 0.0
	var pk := peak()
	if _t < pk:
		return pow(_t / pk, 0.7)
	return pow(1.0 - (_t - pk) / (1.0 - pk), 1.6)

## And how far through it is, 0 to 1, for the styles that travel rather than
## pulse — a ring does not come back, it keeps going and fades.
func _run() -> float:
	return clampf(_t, 0.0, 1.0)


func _draw() -> void:
	if _t < 0.0:
		return
	var a := _amp()
	if a <= 0.001:
		return
	var r := _run()
	var cx := size.x * centre
	var cy := size.y * 0.5
	var mid := Vector2(cx, cy)
	var core := Color(CORE.r, CORE.g, CORE.b, a)
	var cold := Color(COLD.r, COLD.g, COLD.b, a * 0.55)
	match _name():
		&"column":
			# The original: a beam wide enough to be a thing the ship came out
			# of rather than a line somebody drew beside it.
			_bar(cx, 20.0 * a, size.y, core, cold)
		&"twin":
			var gap := 10.0 + 34.0 * r
			_bar(cx - gap, 9.0 * a, size.y, core, cold)
			_bar(cx + gap, 9.0 * a, size.y, core, cold)
		&"cross":
			_bar(cx, 14.0 * a, size.y, core, cold)
			_hbar(cy, 10.0 * a, size.x, core, cold)
		&"slit":
			# Opens along the hull's own axis, then shuts on it.
			_hbar(cy, 3.0 + 20.0 * a, size.x * (0.25 + 0.75 * a), core, cold)
		&"lance":
			_hbar(cy, 6.0 * a, size.x, core, cold)
			draw_circle(mid, 9.0 * a, core)
		&"ring":
			_ring(mid, 8.0 + size.y * 0.55 * r, 3.0 * a, core)
		&"ripple":
			for i in 3:
				var f := r - float(i) * 0.16
				if f > 0.0:
					_ring(mid, 8.0 + size.y * 0.6 * f, 2.5 * a, core)
		&"shock":
			_ring(mid, 6.0 + size.y * 0.7 * r, 2.0 * a, core)
			_hbar(cy, 4.0 * a, size.x * (0.3 + 0.7 * r), cold, cold)
		&"halo":
			# Stays where it was and fades, so the hole the ship left is visible.
			_ring(mid, size.y * 0.32, 2.0 + 4.0 * a, core)
		&"burst":
			draw_circle(mid, (6.0 + size.y * 0.34 * r) * a, core)
		&"bloom":
			# No hard edge anywhere: six rings of falling alpha.
			for i in 6:
				var f := float(i + 1) / 6.0
				draw_circle(mid, size.y * 0.42 * f,
					Color(CORE.r, CORE.g, CORE.b, a * 0.16 * (1.0 - f)))
		&"streak":
			# Away to the right, the way the nose points.
			var w := size.x * 0.65 * r
			draw_rect(Rect2(cx, cy - 5.0 * a, w, 10.0 * a), core, true)
			draw_rect(Rect2(cx, cy - 1.5, w * 1.3, 3.0), cold, true)
		&"wake":
			# A V opening behind it, like something closing over.
			var d := size.x * 0.5 * r
			var s := 4.0 + size.y * 0.30 * r
			draw_line(mid, mid + Vector2(-d, -s), core, 2.0)
			draw_line(mid, mid + Vector2(-d, s), core, 2.0)
		&"bar":
			# One horizontal bar sweeping across the hull and off it.
			var x := lerpf(-size.x * 0.1, size.x * 1.1, r)
			draw_rect(Rect2(x - 6.0, 0.0, 12.0, size.y), core, true)
		&"curtain":
			# A vertical wipe, the ship gone behind it.
			var x2 := lerpf(cx - size.x * 0.6, cx + size.x * 0.6, r)
			draw_rect(Rect2(x2 - 3.0, 0.0, 6.0, size.y), core, true)
			draw_rect(Rect2(x2 - 24.0, 0.0, 21.0, size.y),
				Color(COLD.r, COLD.g, COLD.b, a * 0.3), true)
		&"pinch":
			# Two bars closing onto the hull from both sides.
			var d2 := size.x * 0.5 * (1.0 - r)
			draw_rect(Rect2(cx - d2 - 5.0, 0.0, 5.0, size.y), core, true)
			draw_rect(Rect2(cx + d2, 0.0, 5.0, size.y), core, true)
		&"spark":
			for i in 12:
				var ang := TAU * float(i) / 12.0 + 0.26
				var far := Vector2(cos(ang), sin(ang)) * (size.y * 0.5 * r)
				draw_circle(mid + far, 2.5 * a, core)
		&"ghost":
			# No flash. The hull's own footprint, left behind and fading.
			draw_rect(Rect2(cx - size.x * 0.22, cy - size.y * 0.18,
				size.x * 0.44, size.y * 0.36),
				Color(COLD.r, COLD.g, COLD.b, a * 0.5), true)
		&"stutter":
			# Nothing drawn on the odd beats. The hull is doing the acting.
			if int(r * 9.0) % 2 == 0:
				_bar(cx, 7.0, size.y, Color(CORE.r, CORE.g, CORE.b, 0.8), cold)
		&"wink":
			# One white frame, and it is over.
			if _t < peak() + 0.08:
				draw_rect(Rect2(cx - 30.0, cy - 14.0, 60.0, 28.0), core, true)
		&"hyperdrive":
			# THE SHIP HOLDS STATION AND THE LIGHT LEAVES. `ShipView` is
			# collapsing the hull to its own centre line under this and moving
			# nowhere; everything that travels is drawn here.
			#
			# The beam is two ends on different curves. The head runs early and
			# the tail follows late, so it stretches out of the ship before it
			# goes, and then closes up as it arrives -- which is what makes it
			# read as the ship becoming the beam rather than as a beam being
			# fired out of one.
			var dest := size.x * HYPER_DEST
			if _t < ZIP_TO:
				var f := clampf((_t - MELT_TO) / (ZIP_TO - MELT_TO), 0.0, 1.0)
				var tail := lerpf(-size.x * 0.55, dest, pow(f, 1.9))
				var head := lerpf(size.x * 0.55, dest, pow(f, 0.70))
				var th := 1.5 + 5.0 * a
				var run := maxf(head - tail, 1.0)
				draw_rect(Rect2(cx + tail, cy - th, run, th * 2.0), cold, true)
				draw_rect(Rect2(cx + tail, cy - th * 0.4, run, th * 0.8),
					core, true)
			else:
				# And it ends where it got to, off the ship's nose.
				var s2 := (_t - ZIP_TO) / (1.0 - ZIP_TO)
				var fade := pow(1.0 - s2, 1.4)
				var at := Vector2(cx + dest, cy)
				for i in 12:
					var an := TAU * float(i) / 12.0 + 0.26
					var out := Vector2(cos(an), sin(an)) 						* (size.y * 1.15 * pow(s2, 0.7))
					draw_circle(at + out, 1.5 + 3.0 * fade,
						Color(CORE.r, CORE.g, CORE.b, fade))
		_:
			_bar(cx, 20.0 * a, size.y, core, cold)


## A vertical column: a bright core with a softer shoulder either side.
func _bar(x: float, w: float, h: float, core: Color, halo: Color) -> void:
	if w <= 0.1:
		return
	draw_rect(Rect2(x - w, 0.0, w * 2.0, h), halo, true)
	draw_rect(Rect2(x - w * 0.35, 0.0, w * 0.7, h), core, true)

## The same thing lying down.
func _hbar(y: float, h: float, w: float, core: Color, halo: Color) -> void:
	if h <= 0.1 or w <= 0.1:
		return
	var x := size.x * centre - w * 0.5
	draw_rect(Rect2(x, y - h, w, h * 2.0), halo, true)
	draw_rect(Rect2(x, y - h * 0.35, w, h * 0.7), core, true)

func _ring(at: Vector2, rad: float, w: float, c: Color) -> void:
	if rad <= 0.5 or w <= 0.1:
		return
	draw_arc(at, rad, 0.0, TAU, 48, c, w)
