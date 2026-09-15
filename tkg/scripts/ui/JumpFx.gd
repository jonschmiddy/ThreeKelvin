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
## the hull apart, and it spools up before it does. Jon, on the first version:
## "the horizontal bar exists right as the ship is jumping... it might be nice
## to have a spool up... make it dramatic." So the bar is where the charge
## ARRIVES, not where it starts.
##
## AND THEN, ON THE SECOND: "kinda cartooney". The first spool had motes of light
## streaking in, a pulsing square at the middle, a fat halo, a jittering hull and
## a spark that was a perfect ring of twelve identical dots -- each a charge-up
## convention, and together a drawing of power rather than power. What survived
## is what reads as physics: a hot line along the hull's own centre, crackle ON
## the line rather than things flying AT it, a tremor only at the very end, and
## a spark that is thrown rather than drawn.
##
## Which is why `melts()` exists: the caller asks whether a style wants the hull
## dismantled rather than hidden, instead of checking for a name.
const MELTING: Array[StringName] = [&"hyperdrive"]
## THE WHOLE CHOREOGRAPHY, IN SECONDS, AND THE SOUND READS IT.
## `audio/hyperjump.py` parses CHARGE_S, SNAP_S, ZIP_S and SPARK_S, builds the
## sound on them, and refuses to render if the sound no longer fits them. Change
## one and re-run that script -- the same rule as FLAMEOUTS, for the same reason.
##
## HYPER_REV is a held moment before any of it, counted from `depart()`. It was
## half a second of engines lit, and with no thrusters on ("the thrusters
## shouldn't be on") half a second of nothing is dead air, not a build.
## CHARGE_S was 1.60 and is longer at Jon's ask: the spool is the part to savour.
##
## THEN THE SOUND SET IT. The start-up is one recording, turbine-2, and it builds
## to its loudest 3.8 s in -- the frame the hull goes -- so CHARGE_S is 3.80.
## `audio/hyperjump.py` measures where that take tops out and will not render if
## CHARGE_S has moved away from it.
##
## HANDOFF_S is where the picture changes gear: before it the seam only creeps,
## to RUMBLE_C; after it the build, the crackle and the tremor come in. It was
## set for a second take that came in at 1.80 s. turbine-2 has swelled to its
## plateau by about then, so it stayed; the sound no longer reads it.
const HYPER_REV := 0.25
const CHARGE_S := 3.80
const HANDOFF_S := 1.80
const RUMBLE_C := 0.35
const SNAP_S := 0.16
const ZIP_S := 0.34
## The onward glint's whole run off the frame. It was 0.50 until Jon asked to
## "triple the speed of the dot leaving the screen": the same 400 px in a third
## of the time.
const SPARK_S := 0.17
const LONG_LIFE := CHARGE_S + SNAP_S + ZIP_S + SPARK_S
## The line's pulse, accelerating across the charge. Slower than it was -- 3 to
## 18 over a longer charge would have been thirty throbs, which is a wobble, not
## a build. Linear in frequency, so its phase is a closed form both ends compute.
const PULSE_F0 := 2.0
const PULSE_F1 := 12.0
## A tremor, not a shake: one pixel, and only in the last stretch of the charge.
const SHAKE_PX := 1.0
## Points of light crackling on the line once it has filled out.
const CRACKLE := 6
## What the beam throws when it arrives.
const SPARKS := 9
## Late, because the spark it ends on has to be seen before the screen swaps
## behind it. The commit lands as the last of it goes out.
##
## It was 0.97, a fraction of the WHOLE clock, which moved the swap whenever
## SPARK_S changed: with the glint made three times faster, 0.97 would have cut to
## the next system a fifth of the way through it. So it is stated as how far into
## the ending the swap falls, which is what 0.97 meant when SPARK_S was 0.50.
const PEAK_INTO_ENDING := 0.71
const LONG_PEAK := (LONG_LIFE - SPARK_S * (1.0 - PEAK_INTO_ENDING)) / LONG_LIFE
## Where the beam ends up, as a fraction of the hull's width right of centre.
## Just past the nose -- far enough to read as having gone somewhere, near
## enough that the spark is still beside the ship rather than out in the
## scenery.
const HYPER_DEST := 0.62

## WHAT IS LEFT WHERE THE BEAM ARRIVES, on the last SPARK_S of the clock.
##
## It was a spray of sparks and before that a ring of them, and Jon's word for
## the spray was "silly". A small thing seen at the end of every jump is worth
## choosing rather than guessing, so there are twenty, and `ending` picks one.
## They all live inside the same SPARK_S, so which one plays cannot move the
## frame the jump commits on. `spray` is the one that was there, kept last so the
## others can be judged against it.
const ENDINGS: Array[StringName] = [
	&"wink", &"pinhole", &"star", &"recede", &"lens",
	&"glint", &"blink", &"afterimage", &"dust", &"ripple",
	&"shimmer", &"tear", &"iris", &"trail", &"glow",
	&"split", &"snapout", &"onward", &"echo", &"nothing",
	&"spray",
]
## Which ending plays. A setting, like `style`, for the same reason.
##
## `onward`, Jon's pick: the light does not stop where it closes up, it keeps
## going and leaves the frame. The sound's tail is the recording's own, so any
## ending can be picked without re-rendering it.
static var ending: int = 17

## THE BAR'S LOOK. Jon: "can we have the horizontal bar look cooler". So there
## are twelve, and `bar` picks. Every one goes through `_beam`, so the charge,
## the snap and the run all wear the same treatment -- and none of them draws
## past the ends it is given, which while the line is on the ship are the
## hull's own nose and tail. `plain` is the one that was there, kept first.
const BARS: Array[StringName] = [
	&"plain", &"glow", &"scan", &"flow", &"ion", &"twist",
	&"dash", &"spindle", &"arc", &"stack", &"wave", &"terminals",
	# BLENDS of the four Jon picked out -- "glow scan ion spindle... all good in
	# their own way" -- drawn by `_blend` out of the same four ideas, so each is a
	# combination of switches rather than a sixth drawing of light.
	&"spindle_ion", &"glow_scan", &"ion_glow", &"spindle_glow", &"scan_ion", &"all_four",
]
## Which look the bar wears. A setting, like `style` and `ending`.
##
## `spindle_ion`, Jon's pick, after the run was made to taper: a swell of
## white-hot light through the middle of the hull with cyan and violet
## edges, discharging to a fine line as it leaves. `plain` is index 0.
static var bar: int = 12
## The two edge colours `ion` uses. Both cold: a cyan and a blue-violet, the far
## side of the palette from anything that means heat.
const ION_HI := Color("#7fe8ff")
const ION_LO := Color("#8f86ff")

## WHAT THE HULL DOES AS THE SPOOL STARTS. Jon: "can we have some visual effects
## happening to the ship as the spool is starting?" So there are ten, and `spool`
## picks, like `bar` and `ending`. `ShipView` draws them onto the hull's own
## pixels -- whole pixels, cold light only, nothing scaled -- from `spool_amount()`
## pushed in every frame on this clock, the same way the melt is. `none` is the
## jump as it was, kept first.
const SPOOLS: Array[StringName] = [
	&"none", &"frost", &"scan", &"rim", &"static",
	&"pulse", &"bands", &"ghost", &"drain", &"interlace",
]
## `interlace`, Jon's pick, at full strength ("Yep 100% let's do it"), with the
## modules slipping along with the hull. `none` is index 0.
static var spool: int = 9
## How long the look takes to come up once the charge starts.
const SPOOL_IN_S := 0.60
## How many of the ship's rows `interlace` slips at once, at full charge, 0 to 1.
## Jon liked interlace, "but let's make it less strong".
static var interlace_rows: float = 1.0

func _name() -> StringName:
	return STYLES[clampi(style, 0, STYLES.size() - 1)]

func melts() -> bool:
	return _name() in MELTING

func life() -> float:
	return LONG_LIFE if melts() else LIFE

func peak() -> float:
	return LONG_PEAK if melts() else PEAK

func spool_look() -> StringName:
	return SPOOLS[clampi(spool, 0, SPOOLS.size() - 1)]

## How strongly the hull shows the spool now, 0 to 1: up over SPOOL_IN_S as the
## charge starts, building with the charge after that, and gone the frame the hull
## starts to melt -- the melt owns the hull from there.
func spool_amount() -> float:
	if not melts() or _t < 0.0:
		return 0.0
	var s := _secs()
	if s >= CHARGE_S:
		return 0.0
	return smoothstep(0.0, SPOOL_IN_S, s) * (0.5 + 0.5 * charge_at(s))

## Seconds into the charge, for looks that move.
func charge_secs() -> float:
	return _secs() if _t >= 0.0 else 0.0

## Seconds into this effect, on its own clock.
func _secs() -> float:
	return _t * life()

## How far the hull has gone to light, for `ShipSlot` to push into the view:
## nothing through the charge, all of it by the end of the snap. -1 when this
## style does not melt, or is not playing.
func melt_amount() -> float:
	if not melts() or _t < 0.0:
		return -1.0
	return clampf((_secs() - CHARGE_S) / SNAP_S, 0.0, 1.0)

## And how hard it shudders: building through the charge, letting go through
## the snap, still once it is light.
func shake_amount() -> float:
	if not melts() or _t < 0.0:
		return 0.0
	var s := _secs()
	if s < CHARGE_S:
		# Only in the back half of the surge: the rumble is too early to shudder.
		return SHAKE_PX * smoothstep(0.5, 1.0, surge_at(s))
	if s < CHARGE_S + SNAP_S:
		return SHAKE_PX * (1.0 - (s - CHARGE_S) / SNAP_S)
	return 0.0

## The seam's brightness at `s` seconds into the charge, 0 to 1: the closed form
## of a pulse whose frequency runs PULSE_F0 to PULSE_F1 across CHARGE_S. Starts
## dark, so the first thing seen is the seam arriving rather than a flash.
static func pulse_at(s: float) -> float:
	var ph := TAU * (PULSE_F0 * s + (PULSE_F1 - PULSE_F0) * s * s / (2.0 * CHARGE_S))
	return 0.5 - 0.5 * cos(ph)

## How far the charge has come at `s`, 0 to 1, in the sound's two gears: it
## creeps to RUMBLE_C through the rumble, then builds the rest of the way once
## boom comes in at HANDOFF_S. Continuous at the handoff, so nothing jumps.
static func charge_at(s: float) -> float:
	if s < HANDOFF_S:
		return RUMBLE_C * clampf(s / HANDOFF_S, 0.0, 1.0)
	return lerpf(RUMBLE_C, 1.0, surge_at(s))

## How far through the surge, from the handoff to the snap, 0 to 1.
static func surge_at(s: float) -> float:
	return clampf((s - HANDOFF_S) / (CHARGE_S - HANDOFF_S), 0.0, 1.0)

## FOR THE HARNESSES: jump straight to `secs` into this effect, so twenty endings
## can be photographed without sitting through the charge twenty times.
func seek(secs: float) -> void:
	if _t < 0.0:
		return
	_t = clampf(secs / life(), 0.0, 0.999)
	_fired = _t >= peak()
	queue_redraw()

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
			# CHARGE, SNAP, RUN, SPARK -- on this style's own clock, in seconds.
			# `ShipView` holds station and renders what `ShipSlot` tells it from
			# `melt_amount` and `shake_amount`; everything that travels is here.
			#
			# The box is the hull's opaque body (ShipSlot sizes it with
			# `hull_body`), so half its width is nose to centre and NOTHING here
			# draws the line wider than that. The run is the only thing that goes
			# past the nose, and it gets shorter as it goes.
			var s := _secs()
			var hw := size.x * 0.5
			var dest := size.x * HYPER_DEST
			if s < CHARGE_S:
				_charge(s, cx, cy, hw)
			elif s < CHARGE_S + SNAP_S:
				# THE SNAP. The hull drops its rows under this and the line goes
				# to full. No swelling flash any more -- a bar that bloomed past
				# the hull was the loudest part of the cartoon, and the crack in
				# the sound carries the hit better than a picture of one.
				_beam(cx - hw, cx + hw, cy, 1.0, 1.0, s)
			elif s < CHARGE_S + SNAP_S + ZIP_S:
				# THE RUN. Two ends on different curves: the head goes early and
				# the tail follows late, so the beam leaves the ship and closes
				# up as it arrives.
				var f := (s - CHARGE_S - SNAP_S) / ZIP_S
				var tail := lerpf(-hw, dest, pow(f, 1.9))
				var head := maxf(lerpf(hw, dest, pow(f, 0.70)), tail + 1.0)
				_beam(cx + tail, cx + head, cy, 1.0, 1.0, s, pow(f, 0.7))
			else:
				_ending(clampf((s - CHARGE_S - SNAP_S - ZIP_S) / SPARK_S, 0.0, 1.0),
					Vector2(cx + dest, cy), cx - hw)
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

## A horizontal run of light, snapped to whole pixels so it sits on the grid the
## hull is drawn on.
func _hline(x0: float, x1: float, y: float, thick: float, col: Color) -> void:
	var w := roundf(x1 - x0)
	var th := maxf(roundf(thick), 1.0)
	if w < 1.0 or col.a <= 0.001:
		return
	draw_rect(Rect2(roundf(x0), roundf(y - th * 0.5), w, th), col, true)

## THE CHARGE. The bar is where this arrives, not where it starts.
##
## RESTRAINED ON PURPOSE; see MELTING for what came out and why. A hot line along
## the hull's own centre lengthens to the ship's ends and never past them, and
## brightens in a shimmer rather than a blink. Once it has filled out, single
## points of light crackle on it -- on it, not flying at it.
func _charge(s: float, cx: float, cy: float, hw: float) -> void:
	var c := charge_at(s)
	var p := pulse_at(s)
	# A shimmer, not a blink: the pulse moves brightness between 0.6 and 1.
	var glow := pow(c, 0.9) * (0.60 + 0.40 * p)
	var half := hw * pow(c, 0.85)
	if half < 1.0:
		return
	_beam(cx - half, cx + half, cy, glow, c, s)
	if s < HANDOFF_S:
		return
	# CRACKLE. Each point lives for under half a beat, somewhere new every time it
	# comes back, and there are more of them as the surge builds -- none through
	# the rumble, so the crackle arrives with boom.
	var n := int(round(float(CRACKLE) * surge_at(s)))
	for i in n:
		var beat := s * 11.0 + _hash(i, 5) * 7.0
		var age := fposmod(beat, 1.0)
		if age > 0.45:
			continue
		var at := int(beat)
		var x := cx + (_hash(i * 31 + at, 6) * 2.0 - 1.0) * half
		var side := 1.0 if _hash(i * 17 + at, 7) > 0.5 else -1.0
		var y := cy + side * (1.0 + roundf(_hash(i + at, 8)))
		draw_rect(Rect2(roundf(x), roundf(y), 1.0, 1.0),
			Color(CORE, glow * (1.0 - age / 0.45)), true)

## THE SPARK, and it is not a ring any more. Twelve identical points on a perfect
## circle was the other thing that read as a cartoon pop. Each of these has its
## own heading -- biased forward, because the beam arrived moving right and what
## it throws carries that -- its own speed and size, slows as it goes, and goes
## out on its own time.
func _spark(s2: float, at: Vector2) -> void:
	for i in SPARKS:
		var ang := lerpf(-1.9, 1.9, _hash(i, 11)) + (_hash(i, 12) - 0.5) * 0.6
		var reach := size.y * (0.35 + 0.75 * _hash(i, 13))
		var dist := reach * (1.0 - pow(1.0 - s2, 2.2))
		var k := clampf(s2 / (0.45 + 0.55 * _hash(i, 14)), 0.0, 1.0)
		if k >= 1.0:
			continue
		var px := 2.0 if _hash(i, 15) > 0.6 else 1.0
		var pos := at + Vector2(cos(ang), sin(ang)) * dist
		draw_rect(Rect2(roundf(pos.x), roundf(pos.y), px, px),
			Color(CORE, pow(1.0 - k, 1.3)), true)

## THE BAR. One function for every horizontal run of light in the hyperdrive,
## wearing whichever of BARS is set.
##
## `k` is how bright (0..1). `g` is how grown into itself it is: 0 at the first
## flicker of the charge, 1 from the snap on, so the looks that assemble -- the
## twisting strands, the closing dashes, the compressing layers -- are finished
## by the time the hull goes. `s` is the clock in seconds, for the ones that move.
##
## `run` is how far the beam has got through the run, 0 until it leaves the ship.
## ONLY THE SPINDLE SHAPES READ IT. Jon, on spindle + ion: "i don't like how
## spindle ion ends" -- the swell was worked out over whatever length the beam
## still had, so a beam closing up to a point kept its full belly and flew off
## as a fat coloured lozenge that stubbed into the glint. Now the swell
## discharges as it runs and arrives as a fine line. It is not folded into `g`,
## because the strands, the dashes and the stacked bars assemble on `g` and
## would come apart again mid-run if it fell.
## Nothing here draws outside x0..x1.
func _beam(x0: float, x1: float, y: float, k: float, g: float, s: float,
		run: float = 0.0) -> void:
	x0 = roundf(x0)
	x1 = roundf(x1)
	y = roundf(y)
	var span := x1 - x0
	if span < 1.0 or k <= 0.001:
		return
	match BARS[clampi(bar, 0, BARS.size() - 1)]:
		&"plain":
			# What was there: a thin core in a faint shoulder.
			_hline(x0, x1, y, 3.0, Color(COLD, k * 0.22))
			_hline(x0, x1, y, 1.0 + roundf(g), Color(CORE, k))
		&"glow":
			# A proper glow in pixel steps: four widening layers, each fainter,
			# with a one-pixel white core burning in the middle.
			for layer in [[9.0, 0.07], [7.0, 0.12], [5.0, 0.22], [3.0, 0.5]]:
				_hline(x0, x1, y, maxf(1.0, roundf(float(layer[0]) * (0.35 + 0.65 * g))),
					Color(COLD, k * float(layer[1])))
			_hline(x0, x1, y, 1.0, Color(CORE, k))
		&"scan":
			# Scanlines: a bright core row, dark rows either side, and fainter
			# bright rows outside those -- the look of light on an old tube.
			_px(x0, y, span, 1.0, Color(CORE, k))
			_px(x0, y - 1.0, span, 1.0, Color(COLD, k * 0.10))
			_px(x0, y + 1.0, span, 1.0, Color(COLD, k * 0.10))
			if g > 0.35:
				_px(x0, y - 2.0, span, 1.0, Color(COLD, k * 0.55 * g))
				_px(x0, y + 2.0, span, 1.0, Color(COLD, k * 0.55 * g))
			if g > 0.75:
				_px(x0, y - 4.0, span, 1.0, Color(COLD, k * 0.22 * g))
				_px(x0, y + 4.0, span, 1.0, Color(COLD, k * 0.22 * g))
		&"flow":
			# Energy moving through it toward the nose: bright segments running
			# forward along a dimmer line.
			_hline(x0, x1, y, 3.0, Color(COLD, k * 0.18))
			_hline(x0, x1, y, 1.0, Color(CORE, k * 0.5))
			var period := 26.0
			var sx := x0 - period + fposmod(s * 150.0, period)
			while sx < x1:
				var a0 := maxf(sx, x0)
				var a1 := minf(sx + 11.0, x1)
				if a1 - a0 >= 1.0:
					_hline(a0, a1, y, 2.0, Color(CORE, k))
				sx += period
		&"ion":
			# A white-hot core with coloured edges: cyan above, violet below.
			_px(x0, y - 2.0, span, 1.0, Color(ION_HI, k * (0.25 + 0.45 * g)))
			_px(x0, y + 1.0, span, 1.0, Color(ION_LO, k * (0.25 + 0.45 * g)))
			_px(x0, y - 1.0, span, 2.0, Color(CORE, k))
		&"twist":
			# Two strands winding around each other along the hull, pulling in
			# tighter as it charges until they are one line at the snap.
			var d := 3.0 * (1.0 - g)
			_hline(x0, x1, y, 3.0, Color(COLD, k * 0.12))
			var x := x0
			while x < x1:
				var o := roundf(d * sin((x - x0) * 0.13 + s * 9.0))
				_px(x, y + o, 1.0, 1.0, Color(CORE, k))
				_px(x, y - o, 1.0, 1.0, Color(COLD, k * 0.85))
				x += 1.0
		&"dash":
			# Dashes running forward that lengthen until the gaps close and it is
			# one solid bar.
			var per := 26.0
			var ln := lerpf(5.0, per, pow(g, 1.5))
			_hline(x0, x1, y, 3.0, Color(COLD, k * 0.12))
			var dx := x0 - per + fposmod(s * 110.0, per)
			while dx < x1:
				var d0 := maxf(dx, x0)
				var d1 := minf(dx + ln, x1)
				if d1 - d0 >= 1.0:
					_hline(d0, d1, y, 2.0, Color(CORE, k))
				dx += per
		&"spindle":
			# Thick through the middle of the hull and fine at the ends, like the
			# energy is gathered at the centre.
			var mid := (x0 + x1) * 0.5
			var hwid := maxf(span * 0.5, 1.0)
			var cx2 := x0
			while cx2 < x1:
				var u := (cx2 - mid) / hwid
				var hgt := 1.0 + roundf(4.0 * g * (1.0 - run) * maxf(0.0, 1.0 - u * u))
				var top := y - floorf(hgt * 0.5)
				_px(cx2, top - 1.0, 1.0, hgt + 2.0, Color(COLD, k * 0.22))
				_px(cx2, top, 1.0, hgt, Color(CORE, k))
				cx2 += 1.0
		&"arc":
			# A jagged filament that re-strikes every few frames, over a faint
			# straight line.
			_hline(x0, x1, y, 1.0, Color(COLD, k * 0.35))
			var strike := int(s * 20.0)
			var ax := x0
			var ay := y
			var seg := 0
			while ax < x1:
				var nx := minf(ax + 6.0, x1)
				var ny := y + roundf((_hash(seg + strike * 17, 31) - 0.5) * 5.0 * (0.4 + 0.6 * g))
				if nx >= x1:
					ny = y
				draw_line(Vector2(ax, ay), Vector2(nx, ny), Color(CORE, k), 1.0)
				ax = nx
				ay = ny
				seg += 1
		&"stack":
			# Three bars, apart at first, compressing into one thick bar.
			var gap := 1.0 + roundf(5.0 * (1.0 - g))
			_px(x0, y - gap - 1.0, span, 1.0, Color(COLD, k * 0.6))
			_px(x0, y + gap, span, 1.0, Color(COLD, k * 0.6))
			_px(x0, y - 1.0, span, 2.0, Color(CORE, k))
		&"wave":
			# Brightness rippling along its length, running toward the nose.
			_hline(x0, x1, y, 3.0, Color(COLD, k * 0.15))
			var wx := x0
			while wx < x1:
				var w := 0.4 + 0.6 * (0.5 + 0.5 * sin((wx - x0) * 0.21 - s * 16.0))
				_px(wx, y - 1.0, 1.0, 2.0, Color(CORE, k * w))
				wx += 1.0
		&"spindle_ion":
			_blend(x0, x1, y, k, g, true, true, false, false, false, run)
		&"glow_scan":
			_blend(x0, x1, y, k, g, false, false, true, true, false, run)
		&"ion_glow":
			_blend(x0, x1, y, k, g, false, true, true, false, false, run)
		&"spindle_glow":
			_blend(x0, x1, y, k, g, true, false, true, false, false, run)
		&"scan_ion":
			_blend(x0, x1, y, k, g, false, true, true, true, true, run)
		&"all_four":
			_blend(x0, x1, y, k, g, true, true, true, true, false, run)
		&"terminals":
			# A finer line held between two bright points at nose and tail, the
			# points flickering like contacts.
			_hline(x0, x1, y, 3.0, Color(COLD, k * 0.18))
			_hline(x0, x1, y, 1.0, Color(CORE, k * 0.8))
			if span >= 6.0:
				var fl := 0.7 + 0.3 * sin(s * 40.0)
				_px(x0, y - 1.0, 3.0, 3.0, Color(CORE, k * fl))
				_px(x1 - 3.0, y - 1.0, 3.0, 3.0, Color(CORE, k * fl))

## THE BLENDS, one pixel column at a time, out of four switches:
##
##   spindle   the core thickens toward the middle of the hull
##   ion       a cyan row above the core and a violet row below it
##   halo      a stepped glow outside all of that, fading over a few rows
##   scan      every other row dimmed, core and halo both, like scanlines
##   tint      the halo takes ion's colours instead of plain cold white
##
## Column by column because spindle changes the shape along the length, and the
## edges and the halo have to follow the shape rather than sit on a straight line.
func _blend(x0: float, x1: float, y: float, k: float, g: float,
		spindle: bool, ion: bool, halo: bool, scan: bool, tint: bool,
		run: float = 0.0) -> void:
	var span := x1 - x0
	var mid := (x0 + x1) * 0.5
	var hwid := maxf(span * 0.5, 1.0)
	var reach := int(round(4.0 * (0.35 + 0.65 * g))) if halo else 0
	var col := x0
	while col < x1:
		var hgt := 1.0 + roundf(g)
		if spindle:
			var u := (col - mid) / hwid
			hgt = 1.0 + roundf(4.0 * g * (1.0 - run) * maxf(0.0, 1.0 - u * u))
		var top := y - floorf(hgt * 0.5)
		var bot := top + hgt - 1.0
		if scan and hgt >= 3.0:
			var ry := top
			while ry <= bot:
				var lit := int(ry - y) % 2 == 0
				_px(col, ry, 1.0, 1.0, Color(CORE, k if lit else k * 0.45))
				ry += 1.0
		else:
			_px(col, top, 1.0, hgt, Color(CORE, k))
		var up := top
		var dn := bot
		if ion:
			var ia := k * (0.3 + 0.45 * g)
			_px(col, top - 1.0, 1.0, 1.0, Color(ION_HI, ia))
			_px(col, bot + 1.0, 1.0, 1.0, Color(ION_LO, ia))
			up = top - 1.0
			dn = bot + 1.0
		for d in range(1, reach + 1):
			if scan and d % 2 == 0:
				continue
			var ha := k * 0.42 * (1.0 - float(d) / float(reach + 1))
			_px(col, up - float(d), 1.0, 1.0, Color(ION_HI if tint else COLD, ha))
			_px(col, dn + float(d), 1.0, 1.0, Color(ION_LO if tint else COLD, ha))
		col += 1.0

## THE ENDINGS. See ENDINGS for why there are twenty.
##
## Whole pixels, cold light, nothing warm and nothing scaled -- the class rules.
## `at` is where the beam closed up; `from_x` is where it left the hull, for the
## endings that remember the path it took.
func _ending(s2: float, at: Vector2, from_x: float) -> void:
	var x := roundf(at.x)
	var y := roundf(at.y)
	var fade := 1.0 - s2
	match ENDINGS[clampi(ending, 0, ENDINGS.size() - 1)]:
		&"wink":
			# One bright point for a few frames, and gone.
			if s2 < 0.07:
				_px(x - 1.0, y - 1.0, 2.0, 2.0, CORE)
			elif s2 < 0.16:
				_px(x, y, 1.0, 1.0, CORE)
		&"pinhole":
			# A point of light left behind, going out slowly.
			var sz := 2.0 if s2 < 0.6 else 1.0
			_px(x - floorf(sz * 0.5), y - floorf(sz * 0.5), sz, sz, Color(CORE, pow(fade, 1.5)))
		&"star":
			# It becomes one of the stars in the backdrop: a point with four short
			# arms, the arms drawing in as it fades.
			var arm := int(round(3.0 * fade))
			var ca := Color(CORE, pow(fade, 0.8))
			var aa := Color(COLD, 0.55 * fade)
			_px(x, y, 1.0, 1.0, ca)
			for k in range(1, arm + 1):
				_px(x + k, y, 1.0, 1.0, aa)
				_px(x - k, y, 1.0, 1.0, aa)
				_px(x, y + k, 1.0, 1.0, aa)
				_px(x, y - k, 1.0, 1.0, aa)
		&"recede":
			# A small square that steps down in size, as if getting further away.
			var sz2 := 3.0 if s2 < 0.25 else (2.0 if s2 < 0.55 else 1.0)
			_px(x - floorf(sz2 * 0.5), y - floorf(sz2 * 0.5), sz2, sz2, Color(CORE, 1.0 - 0.6 * s2))
		&"lens":
			# A thin horizontal streak, the way a camera catches a bright point.
			var half := roundf(60.0 * pow(s2, 0.35))
			_px(x - half, y, half * 2.0 + 1.0, 1.0, Color(COLD, 0.7 * fade * fade))
			_px(x - 1.0, y, 3.0, 1.0, Color(CORE, fade))
		&"glint":
			# The same, standing up.
			var hh := roundf(3.0 + 18.0 * pow(s2, 0.4))
			_px(x, y - hh, 1.0, hh * 2.0 + 1.0, Color(COLD, 0.8 * fade * fade))
			_px(x, y, 1.0, 1.0, Color(CORE, fade))
		&"blink":
			# Three flashes, each dimmer and shorter, like a signal going out.
			var on := 0.0
			if s2 < 0.10:
				on = 1.0
			elif s2 >= 0.30 and s2 < 0.38:
				on = 0.6
			elif s2 >= 0.60 and s2 < 0.64:
				on = 0.3
			if on > 0.0:
				_px(x, y, 1.0, 1.0, Color(CORE, on))
		&"afterimage":
			# The path the beam took stays for a moment, eaten from the tail.
			var start := lerpf(from_x, x, s2)
			if x - start >= 1.0:
				_px(start, y, x - start, 1.0, Color(COLD, 0.5 * pow(fade, 1.6)))
		&"dust":
			# A few points drifting on forward, slowly, each going out on its own.
			for i in 5:
				var span := 0.55 + 0.45 * _hash(i, 21)
				var k2 := s2 / span
				if k2 >= 1.0:
					continue
				var drift := Vector2(10.0 + 14.0 * _hash(i, 22), (_hash(i, 23) - 0.5) * 8.0) * k2
				_px(x + roundf(drift.x), y + roundf(drift.y), 1.0, 1.0, Color(CORE, 0.8 * (1.0 - k2)))
		&"ripple":
			# One faint ring, slow, not a burst.
			var rad := 2.0 + 24.0 * (1.0 - fade * fade)
			draw_arc(Vector2(x + 0.5, y + 0.5), rad, 0.0, TAU, 40, Color(COLD, 0.35 * fade), 1.0)
		&"shimmer":
			# A few pixels flickering in a small patch, thinning out.
			var n := int(round(6.0 * fade))
			var tick := int(s2 * SPARK_S * 25.0)
			for i in n:
				var dx := roundf((_hash(i * 7 + tick, 24) - 0.5) * 7.0)
				var dy := roundf((_hash(i * 13 + tick, 25) - 0.5) * 5.0)
				_px(x + dx, y + dy, 1.0, 1.0, Color(CORE, 0.7 * fade))
		&"tear":
			# A thin vertical slit that opens and closes.
			var o := sin(PI * minf(s2 * 1.6, 1.0))
			var th := roundf(9.0 * o)
			if th >= 1.0:
				_px(x - 1.0, y - th, 3.0, th * 2.0 + 1.0, Color(COLD, 0.3 * o))
				_px(x, y - th, 1.0, th * 2.0 + 1.0, Color(CORE, o))
		&"iris":
			# A diamond outline closing down to a point.
			var ir := int(round(8.0 * fade))
			var ic := Color(CORE, 0.8)
			if ir <= 0:
				if s2 < 0.98:
					_px(x, y, 1.0, 1.0, ic)
			else:
				for k in ir:
					_px(x + (ir - k), y + k, 1.0, 1.0, ic)
					_px(x - (ir - k), y - k, 1.0, 1.0, ic)
					_px(x - k, y + (ir - k), 1.0, 1.0, ic)
					_px(x + k, y - (ir - k), 1.0, 1.0, ic)
		&"trail":
			# Dots along the path, going out from the tail forward.
			var run := x - from_x
			if run >= 4.0:
				var dot := from_x
				while dot <= x:
					var u := (dot - from_x) / run
					var al := 0.5 * clampf((u + 0.35 - s2 * 1.35) / 0.35, 0.0, 1.0)
					if al > 0.0:
						_px(roundf(dot), y, 1.0, 1.0, Color(COLD, al))
					dot += 4.0
		&"glow":
			# A soft patch of light with no edge, and a point in it.
			var gr := 10.0 * (0.4 + 0.6 * s2)
			for k in 4:
				draw_circle(Vector2(x + 0.5, y + 0.5), gr * float(k + 1) / 4.0, Color(CORE, 0.10 * fade))
			_px(x, y, 1.0, 1.0, Color(CORE, fade))
		&"split":
			# The point parts into two, above and below, and they go.
			var gap := roundf(6.0 * pow(s2, 0.6))
			var pc := Color(CORE, pow(fade, 1.2))
			_px(x, y - gap, 1.0, 1.0, pc)
			_px(x, y + gap, 1.0, 1.0, pc)
		&"snapout":
			# A hard white square for two frames, then nothing at all.
			if s2 < 0.06:
				_px(x - 2.0, y - 2.0, 5.0, 5.0, CORE)
			elif s2 < 0.12:
				_px(x - 1.0, y - 1.0, 3.0, 3.0, Color(CORE, 0.5))
		&"onward":
			# It does not stop there: a small glint keeps going, off the frame.
			var ox := x + roundf(400.0 * pow(s2, 1.3))
			_px(ox - 2.0, y, 5.0, 1.0, Color(COLD, 0.7))
			_px(ox, y, 1.0, 1.0, CORE)
		&"echo":
			# Three points further on, each fainter, as if it jumped in steps.
			var offs := [8.0, 18.0, 30.0]
			var lvl := [1.0, 0.6, 0.35]
			for i in 3:
				var t0 := 0.18 * float(i)
				if s2 >= t0:
					var a2 := float(lvl[i]) * clampf(1.0 - (s2 - t0) / 0.45, 0.0, 1.0)
					if a2 > 0.0:
						_px(x + float(offs[i]), y, 1.0, 1.0, Color(CORE, a2))
		&"nothing":
			# The beam closes up and there is just space where it was.
			pass
		&"spray":
			_spark(s2, at)

## One snapped rectangle of light. Skips the fully transparent ones.
func _px(x: float, y: float, w: float, h: float, col: Color) -> void:
	if col.a <= 0.001:
		return
	draw_rect(Rect2(roundf(x), roundf(y), w, h), col, true)

## A fixed scatter, the same every jump.
static func _hash(i: int, k: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453, 1.0)
