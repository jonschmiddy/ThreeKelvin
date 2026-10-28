class_name GpuProbe
extends RefCounted

## WHAT THIS MACHINE'S GRAPHICS CAN HOLD, MEASURED: some viewports' GPU time,
## averaged over their first frames of drawing. It was RADIANT's safety alone
## (`ChartSky._radiant_safety`, Oct 5); it is every style's now, because the
## same measure picks GRAPHICS for a player who never chose it (below).
##
## GRAPHICS LOW, PICKED FOR THE MACHINE (Jon, Oct 27, ruling C1: "yes"). Every
## budget in this game was set on an RTX 3070, and on an Intel laptop chip (Jon's
## Mac: Iris Plus 645, about 1/25 of its shader rate) the HIGH sky alone runs past
## a 60 fps frame. LOW is every style's cheaper path, and nothing ever turned it
## on: a player had to know to look. So on the title, for a player who never set
## GRAPHICS (`DisplaySettings.graphics_by`), the title's sky is measured once
## and the answer is kept for good (once per profile, never again). A player who
## pressed HIGH or LOW is never touched.
##
## THE ADAPTER'S NAME IS ONLY A HINT. On the launch that is still undecided, an
## Intel chip that is not an Arc starts on LOW at once, before the title is
## built, so its first picture is already the cheap one (an Apple chip never
## does, whatever it measures later). The measure then decides: it can keep LOW
## or put HIGH back.
##
## A MAC CANNOT TIME ITS GPU. Apple's OpenGL answers every GPU timer with 0
## (Jon's Mac, Oct 27: `-- chartbench` read "GPU 0.00 ms" on every sample, HIGH
## and LOW). So the GPU's time is the measure where there is one, and where it
## reads 0 the title's frame time on the wall clock is (its median, the window
## focused): a title that cannot hold 60 frames a second is a weak machine.
## That sees less (vsync rounds a frame up to the screen's next refresh) but is
## still a measure; with neither (a frame cap under 50 hides it too), the hint
## stands for that launch and nothing is kept: the title measures again.
##
## NEVER UNDER A PICTURE: the pick is saved without `Sig.render_style_changed`,
## as RADIANT's own fall-back is (`DisplaySettings.fall_back_style`), so the
## title keeps its look and the next picture built (the run's chart, the map,
## LOCAL, the next title) draws the new one. And never under a harness, nor a
## launch that forced `style=` or `graphics=`: those ask for what they measure.

## Frames drawn before any is counted: the first few pay for compiles and the
## first upload, and the timer's answer lags its frame.
const SETTLE := 12
## A FULL SCREEN OF SKY, in the sky's own blocks (the game's 960x540 at two
## pixels a block, and the composite's margin): what the measure is scaled to.
## The title's sky is a square as wide as the screen's diagonal and draws the
## screen's share of it, which grows and shrinks as it turns; scaled per frame,
## the number is the same at any angle and comparable with the chart's.
const FULL_SKY := Vector2i(483, 273)
## The sky's GPU time for a full screen, ms a frame, over which this machine
## draws LOW. RADIANT's budget (`ChartRadiant.FALLBACK_MS`): the most of a
## 16.7 ms frame the sky may take and leave the shell, the HUD and the GDScript
## theirs. The 3070 draws SIMPLIFIED's chart sky in 1.26 ms (a95f7db7).
const LOW_MS := 6.0
## What LOW costs against HIGH on the same machine, for a title measured on LOW
## (the hint put it there): its time over this is what HIGH would have cost.
## Measured on Jon's Mac (Iris Plus 645, Oct 27, seed 4242, the window at 1x,
## vsync off: `-- chartbench` and `-- chartbench graphics=low`): the title 6.20
## ms a frame on LOW against 12.88 on HIGH (0.48); the chart 0.43 still, 0.31
## at zoom 6.
const LOW_SHARE := 0.48
## THE WALL CLOCK'S BUDGET, where the GPU cannot be timed: the title's median
## frame, ms, over which this machine draws LOW. Between 60 a second (16.7) and
## the next step vsync can show on a 60 Hz screen (33.3): the title could not
## hold 60. The chart costs more than the title (1.55x on Jon's Mac, HIGH), so
## this catches only the plainly weak; the hint covers Intel.
const FRAME_MS := 22.0
## A frame cap under this hides the machine (its frames are the cap's): no
## wall-clock measure then.
const CAP_HIDES := 50

var rids: Array[RID] = []
var want := 90
var frames := 0
var n := 0
var gpu := 0.0
var done := false
## the average, ms a frame, once `done`
var avg_ms := 0.0
## the frames' lengths on the wall clock, when stepped with them (every frame,
## `ChartSky._gfx_step`), and their median, ms, once `done` (0: not measured)
var gaps := PackedFloat32Array()
var frame_ms := 0.0


func _init(r: Array[RID] = [], frames_wanted: int = 90) -> void:
	rids = r
	want = frames_wanted


## One frame drawn. `scale` is what this frame's GPU reading is multiplied by
## (`full_sky_scale`: 1 for the raw time); `delta`, the frame's length in
## seconds when it is stepped every frame (below 0: not kept). True on the
## frame the average is ready, once.
func step(scale: float = 1.0, delta: float = -1.0) -> bool:
	if done or rids.is_empty():
		return false
	frames += 1
	if frames == 1:
		for r in rids:
			RenderingServer.viewport_set_measure_render_time(r, true)
		return false
	if frames < SETTLE:
		return false
	var ms := 0.0
	for r in rids:
		ms += RenderingServer.viewport_get_measured_render_time_gpu(r)
	gpu += ms * scale
	if delta >= 0.0:
		gaps.append(delta * 1000.0)
	n += 1
	if n < want:
		return false
	done = true
	avg_ms = gpu / float(n)
	# (a median of most of the frames, or none: a window behind others for
	# most of the measure says nothing)
	if gaps.size() * 2 >= n:
		var g := gaps.duplicate()
		g.sort()
		frame_ms = g[g.size() / 2]
	return true


## What a reading over a viewport of `size` is multiplied by to be a full
## screen's (`FULL_SKY`).
static func full_sky_scale(size: Vector2i) -> float:
	var a := float(maxi(size.x, 1) * maxi(size.y, 1))
	return float(FULL_SKY.x * FULL_SKY.y) / a


# ------------------------------------------------------------- the machine's pick

## The adapter's own name and vendor, or a harness's stand-in (`-- menutest`).
static var adapter_override := PackedStringArray()


static func adapter() -> PackedStringArray:
	if not adapter_override.is_empty():
		return adapter_override
	return PackedStringArray([RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name()])


## THE HINT: an Intel chip that is not an Arc is weak; an Apple one never is,
## nor anything else by its name. Read on Windows ("Intel", "Intel(R) UHD
## Graphics 620"), on a Mac's GL ("Intel Inc.", "Intel(R) Iris(TM) Plus Graphics
## 645") and through ANGLE ("ANGLE (Intel, Intel(R) UHD Graphics 620 ...)").
static func weak_by_name(vendor: String, name: String) -> bool:
	var s := (vendor + " " + name).to_lower()
	if s.contains("apple"):
		return false
	if not s.contains("intel"):
		return false
	var arc := RegEx.create_from_string("\\barc\\b")
	return arc.search(s) == null


static func hint_weak() -> bool:
	if asked() == "nohint":
		return false
	var a := adapter()
	return weak_by_name(a[0] if a.size() > 0 else "", a[1] if a.size() > 1 else "")


## `-- gfxprobe`: the pick under a harness too (into its scratch settings), to
## see it work on a real machine: "on". `gfxprobe=nohint`: the same without the
## adapter's hint, so the sky measured is HIGH's. "" when not asked. Read off
## the command line once (the title asks every frame until the pick is made).
static var _asked := "?"


static func asked() -> String:
	if _asked != "?":
		return _asked
	_asked = ""
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s == "gfxprobe":
			_asked = "on"
		elif s.begins_with("gfxprobe="):
			_asked = s.substr(9)
	return _asked


## THE VERDICT: LOW or not, from the sky's full-screen GPU time and whether it
## was measured on LOW; where the GPU read 0 (a Mac), from the title's median
## frame on the wall clock; with neither (headless, a cap that hides it) the
## hint's, which `conclude` never keeps. Measured on LOW, a time is judged by
## what HIGH would have cost.
static func verdict(full_ms: float, measured_low: bool, weak_hint: bool, frame_ms: float = 0.0) -> bool:
	var k := 1.0 / LOW_SHARE if measured_low else 1.0
	if full_ms > 0.0:
		return full_ms * k > LOW_MS
	if frame_ms > 0.0:
		return frame_ms * k > FRAME_MS
	return weak_hint


## Whether a sky should measure for the pick now: the player never set
## GRAPHICS, nothing forced it, and this is the game a player runs (a harness
## only when it asks: `-- menutest` through `in_harness`, a window with
## `-- gfxprobe`).
static var in_harness := false
## `TestRun.active()`, read once: the command line does not change.
static var _test_run := -1


static func wanted() -> bool:
	if DisplaySettings.graphics_by != DisplaySettings.GFX_NOBODY:
		return false
	if DisplaySettings.harness_forced():
		return false
	if _test_run < 0:
		_test_run = 1 if TestRun.active() else 0
	if _test_run == 1 and not in_harness and asked() == "":
		return false
	return DisplayServer.get_name() != "headless" or in_harness


## The measure is in: decide, keep it, and say so in the log (once, ever).
## False if it was not this measure's to decide, or if it read nothing (a Mac's
## window behind others the whole time, a cap hiding the frames): the adapter's
## name is only a hint, so nothing is kept on it alone. The hint stays in
## memory for this launch and the title measures again.
static func conclude(full_ms: float, measured_low: bool, frame_ms: float = 0.0) -> bool:
	if not wanted():
		return false
	if full_ms <= 0.0 and frame_ms <= 0.0:
		return false
	var weak := hint_weak()
	var low := verdict(full_ms, measured_low, weak, frame_ms)
	var a := adapter()
	print("GRAPHICS %s picked for this machine: on %s the sky's GPU took %.2f ms a frame for a full screen, the title's frame %.2f ms (hint %s; %s)" % [
		"LOW" if low else "HIGH", "LOW" if measured_low else "HIGH", full_ms, frame_ms,
		"weak" if weak else "none", " / ".join(a)])
	DisplaySettings.machine_pick(low)
	return true
