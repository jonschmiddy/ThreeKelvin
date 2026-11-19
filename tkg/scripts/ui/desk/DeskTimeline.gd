class_name DeskTimeline
extends RefCounted

## The science desk's clock, as the approved page's shell runs it (tools/desk/page/index.html), and
## when its sounds fire (`scenes/audio.js`). Pure, so `DeskTest` can hold both to the page.
## Scene time `ts`: act 1 (the push into the ship, then black) ends at A; the room's power-on runs
## SPEED x fast after it; from KNEE on the idle runs at real speed. Leaving runs it backwards.
## Why: docs/why/DeskScene.md#the-plan

const A := 2.5
const ZOOM_S := 2.9
const SPEED := 1.25
const KNEE := 10.0
const OFF_SPEED := 2.2
const ZOOM_OUT_S := 2.4
## G's thunk decays here (real seconds after the power-on), and the hum starts on it.
const HUM_AT := 0.83
## The quit sound's click, seconds into `power_off.wav`; it lands as the screen goes dark.
const OFF_CUT := 1.47
## A one-shot fires when the clock crosses its time going forward by at most this (never on a jump).
const STEP_MAX := 0.25
const LEAVE_STEP_MAX := 0.5


## Scene time `real` seconds after the start.
static func forward(real: float) -> float:
	var pk := ZOOM_S + (KNEE - A) / SPEED
	if real < ZOOM_S:
		return real * A / ZOOM_S
	if real < pk:
		return A + (real - ZOOM_S) * SPEED
	return KNEE + (real - pk)


## Scene time `e` real seconds after a leave from scene time `from`: the room powers off OFF_SPEED x
## fast, then the fade and the zoom run back over ZOOM_OUT_S.
static func leaving(e: float, from: float) -> float:
	var d1 := maxf(0.0, (from - A) / OFF_SPEED)
	if e < d1:
		return from - e * OFF_SPEED
	return maxf(0.0, minf(from, A) - (e - d1) * A / ZOOM_OUT_S)


## Real seconds a leave from `from` takes to reach LOCAL.
static func leave_length(from: float) -> float:
	return maxf(0.0, (from - A) / OFF_SPEED) + minf(from, A) * ZOOM_OUT_S / A


## The room bed's level at scene time `ts`: up with the room after act 1, down as leaving runs back.
static func bed_level(ts: float) -> float:
	return clampf((ts - (A - 0.3)) / 1.4, 0.0, 1.0)


## When the hum starts (scene time) for a room whose monitor powers on at `crt`.
static func hum_at(crt: float) -> float:
	return crt + HUM_AT * SPEED


## The sounds a frame fires, going from scene time `p` to `ts` (`p` < 0: the first frame, none).
## Each is [name, value]: &"lamp", &"poweron", &"hum_warm" forward; &"power_off" (seconds into the
## file to start at) and &"lamp" while leaving. `off_fired`: this leave's power-off already went.
static func sound_events(p: float, ts: float, is_leaving: bool, lamp: float, crt: float, off_fired: bool) -> Array[Array]:
	var out: Array[Array] = []
	if p < 0.0:
		return out
	if is_leaving:
		var lead := (ts - crt) / OFF_SPEED
		if not off_fired and ts > crt and lead <= OFF_CUT:
			out.append([&"power_off", maxf(0.0, OFF_CUT - lead)])
		if p > lamp and ts <= lamp and p - ts <= LEAVE_STEP_MAX:
			out.append([&"lamp", 0.0])
		return out
	if ts <= p or ts - p > STEP_MAX:
		return out
	if p < lamp and ts >= lamp:
		out.append([&"lamp", 0.0])
	if p < crt and ts >= crt:
		out.append([&"poweron", 0.0])
	var hs := hum_at(crt)
	if p < hs and ts >= hs:
		out.append([&"hum_warm", 0.0])
	return out
