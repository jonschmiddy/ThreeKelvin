class_name GpuProbe
extends RefCounted

## Measures the title's sky to pick GRAPHICS LOW for players who never chose (Jon, Oct 27, C1).
## Macs report 0 GPU time, so wall-clock frames stand in. The adapter name is only a hint.
## Why: docs/why/GpuProbe.md#graphics-pick

## Frames drawn before any is counted: the first few pay for compiles and the
## first upload, and the timer's answer lags its frame.
const SETTLE := 12
## The measure is scaled to a full screen of sky, so it is the same at any angle.
const FULL_SKY := Vector2i(483, 273)
## Sky GPU budget in ms, RADIANT's: the most of a 16.7 ms frame the sky may take.
const LOW_MS := 6.0
## Measured on Jon's Mac, Oct 27: title 6.20 ms on LOW against 12.88 on HIGH, so 0.48.
## Why: docs/why/GpuProbe.md#low-share
const LOW_SHARE := 0.48
## Wall-clock budget (22 ms) where the GPU cannot be timed: the title cannot hold 60.
const FRAME_MS := 22.0
## A frame cap under this hides the machine (its frames are the cap's): no
## wall-clock measure then.
const CAP_HIDES := 50

var rids: Array[RID] = []
## the viewports' instance ids, beside their RIDs: one freed under the probe
## is only counted out (`release`)
var _ids := PackedInt64Array()
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
## Whether this probe has its viewports' GPU timers on (`release`).
var _armed := false

## The timer is turned off again, or it runs on the title's viewports; the last probe out stops it.
## Why: docs/why/GpuProbe.md#gpu-timer
static var _reading := {}

## Harness stand-in for the GPU reading, as the dummy renderer reads 0. Never set by the game.
static var force_ms := -1.0


func _init(v: Array[SubViewport] = [], frames_wanted: int = 90) -> void:
	for vp in v:
		rids.append(vp.get_viewport_rid())
		_ids.append(vp.get_instance_id())
	want = frames_wanted


## One frame drawn; true once, when the average is ready, and the timers are released.
func step(scale: float = 1.0, delta: float = -1.0) -> bool:
	if done or rids.is_empty():
		return false
	frames += 1
	if frames == 1:
		_arm()
		return false
	if frames < SETTLE:
		return false
	var ms := 0.0
	if force_ms >= 0.0:
		ms = force_ms
	else:
		for r in rids:
			ms += RenderingServer.viewport_get_measured_render_time_gpu(r)
	gpu += ms * scale
	if delta >= 0.0:
		gaps.append(delta * 1000.0)
	n += 1
	if n < want:
		return false
	done = true
	release()
	avg_ms = gpu / float(n)
	# (a median of most of the frames, or none: a window behind others for
	# most of the measure says nothing)
	if gaps.size() * 2 >= n:
		var g := gaps.duplicate()
		g.sort()
		frame_ms = g[g.size() / 2]
	return true


func _arm() -> void:
	if _armed:
		return
	_armed = true
	for r in rids:
		_reading[r] = int(_reading.get(r, 0)) + 1
		RenderingServer.viewport_set_measure_render_time(r, true)


## Release stops reading; a viewport no other probe reads has its timer off. Safe to repeat.
func release() -> void:
	if not _armed:
		return
	_armed = false
	for i in rids.size():
		var r := rids[i]
		var c := int(_reading.get(r, 0)) - 1
		if c > 0:
			_reading[r] = c
			continue
		_reading.erase(r)
		if is_instance_id_valid(_ids[i]):
			RenderingServer.viewport_set_measure_render_time(r, false)


## How many unfinished probes are reading a viewport (`-- menutest`).
static func reading(vp: SubViewport) -> int:
	return int(_reading.get(vp.get_viewport_rid(), 0))


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


## The hint: an Intel chip that is not an Arc is weak; Apple and others never are by name.
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


## `-- gfxprobe` runs the pick under a harness; `nohint` measures HIGH's sky. Read once.
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


## `-- gfxprobe ... shot=<png>`: the still waits for the pick (`Main._shoot`),
## so the probe leaves the quitting to it.
static func shot_asked() -> bool:
	for a in OS.get_cmdline_user_args():
		if a == "shot" or (a as String).begins_with("shot="):
			return true
	return false


## An Intel Mac keeps LOW: a LOW that holds 60 says nothing about HIGH, so the name decides.
## Why: docs/why/GpuProbe.md#verdict
static func verdict(full_ms: float, measured_low: bool, weak_hint: bool, frame_ms: float = 0.0) -> bool:
	var k := 1.0 / LOW_SHARE if measured_low else 1.0
	if full_ms > 0.0:
		return full_ms * k > LOW_MS
	if frame_ms > 0.0:
		return frame_ms * k > FRAME_MS
	return weak_hint


## Measure only for players who never set GRAPHICS, unless a harness asks.
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


## Keep nothing on the hint alone: if the measure read nothing, the title measures again.
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
