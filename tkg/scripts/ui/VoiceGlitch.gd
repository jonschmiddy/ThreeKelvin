class_name VoiceGlitch
extends RefCounted

## A.S.H.'s take is edited live in place at the same length, so typed words keep pace.
## Why: docs/why/VoiceGlitch.md#voice-glitch

const EDGE_S := 0.004
const RING_HZ := 170.0
const WOBBLE_MS := 2.0
## Bits kept by `crush` at amt 0 and at amt 1, and its sample hold.
const CRUSH_BITS := [7.0, 5.0]
const CRUSH_HOLD := [3, 6]
## The chop's gate edges, s, and how much of each cycle is off at amt 0 and 1.
const CHOP_EDGE_S := 0.0012
const CHOP_OFF := [0.35, 0.55]
## The crackle: clicks a second at amt 1, their height (of full scale), and
## the bits its voice keeps.
const CRACKLE_HZ := 520.0
const CRACKLE_PEAK := 0.22
const CRACKLE_BITS := 8.0


## Decode `stream` to stereo frames at the mixer's rate. {x, sr}. Main thread
## (it makes the playback); `decode_from` is the part a worker may run.
static func decode(stream: AudioStream) -> Dictionary:
	var pb := stream.instantiate_playback()
	if pb == null:
		return {}
	var sr := AudioServer.get_mix_rate()
	return {x = decode_from(pb, stream.get_length(), sr), sr = sr}


## A playback made on the main thread, decoded to `secs` of stereo frames at
## `sr`. Pure CPU: safe on a worker (`OffThread`'s rule).
static func decode_from(pb: AudioStreamPlayback, secs: float, sr: float) -> PackedVector2Array:
	pb.start(0.0)
	var want := int(roundf(secs * sr))
	var x := PackedVector2Array()
	var guard := 0
	while pb.is_playing() and x.size() < want and guard < 4000:
		x.append_array(pb.mix_audio(1.0, 4096))
		guard += 1
	if x.size() > want:
		x.resize(want)
	return x


## Same-length stream on the calling thread; in play the work is split onto a worker.
static func render(stream: AudioStream, plan: Array) -> AudioStream:
	var d := decode(stream)
	if d.is_empty() or (d.x as PackedVector2Array).is_empty():
		return null
	return from_pcm(pcm16(apply(d.x, d.sr, plan)), d.sr)


## THE WORKER'S HALF, with the windows moved onto her words first (`place`):
## {pcm, plan}. The plan comes back because her portrait slips on it.
static func bake_placed(pb: AudioStreamPlayback, secs: float, sr: float, plan: Array) -> Dictionary:
	var x := decode_from(pb, secs, sr)
	if x.is_empty():
		return {pcm = PackedByteArray(), plan = plan}
	var placed := place(x, sr, plan)
	return {pcm = pcm16(apply(x, sr, placed)), plan = placed}


## A glitch in a pause is silent (Jon), so windows move to speech or are dropped.
## Why: docs/why/VoiceGlitch.md#glitch-placement
const PLACE_QUIET := 0.12
const PLACE_VOICED := 0.7
const PLACE_REACH_S := 0.6
const PLACE_STEP_S := 0.01

static func place(x: PackedVector2Array, sr: float, plan: Array) -> Array:
	var hop := maxi(1, int(PLACE_STEP_S * sr))
	var env := PackedFloat32Array()
	var top := 0.0
	var i := 0
	while i < x.size():
		var e := 0.0
		var m := mini(x.size(), i + hop)
		for k in range(i, m):
			e += x[k].length_squared()
		e = sqrt(e / float(maxi(1, m - i)))
		env.append(e)
		top = maxf(top, e)
		i += hop
	var quiet := top * PLACE_QUIET
	var secs := float(x.size()) / sr
	var out: Array = []
	var after := 0.1
	for g: Dictionary in plan:
		var ln := float(g.len)
		var best := -1.0
		var tries := int(PLACE_REACH_S / PLACE_STEP_S)
		for t in tries * 2 + 1:
			# 0, +1, -1, +2, -2 ... steps from where it was planned
			var off := float((t + 1) / 2) * PLACE_STEP_S * (1.0 if t % 2 == 1 else -1.0)
			var at := float(g.at) + off
			if at < after or at + ln > secs - 0.2:
				continue
			var a := int(at / PLACE_STEP_S)
			var b := mini(env.size(), int(ceilf((at + ln) / PLACE_STEP_S)))
			var loud := 0
			for k in range(a, b):
				if env[k] >= quiet:
					loud += 1
			if b > a and float(loud) >= PLACE_VOICED * float(b - a):
				best = at
				break
		if best < 0.0:
			continue
		var h := g.duplicate()
		h.at = best
		out.append(h)
		after = float(h.at) + ln + LowHull.MIN_APART
	return out


## `x` with the glitches (returned: a packed array is not shared through a call).
static func apply(x: PackedVector2Array, sr: float, plan: Array) -> PackedVector2Array:
	var src := x.duplicate()
	for g: Dictionary in plan:
		var s := int(float(g.at) * sr)
		var n := int(float(g.len) * sr)
		if s < 1 or n < 8 or s + n >= x.size():
			continue
		var amt := clampf(float(g.get("amt", 1.0)), 0.0, 1.0)
		var edge := maxi(1, mini(int(EDGE_S * sr), n / 3))
		var bits := lerpf(float(CRUSH_BITS[0]), float(CRUSH_BITS[1]), amt)
		var q := pow(2.0, bits - 1.0)
		var hold := int(lerpf(float(CRUSH_HOLD[0]), float(CRUSH_HOLD[1]), amt))
		var rep := maxi(1, int(g.get("rep", 1)))
		var chunk := maxi(1, n / rep)
		var period := sr / maxf(1.0, float(g.get("hz", 30.0)))
		var off := lerpf(float(CHOP_OFF[0]), float(CHOP_OFF[1]), amt)
		var ce := maxf(1.0, CHOP_EDGE_S * sr)
		var cr := RandomNumberGenerator.new()
		cr.seed = int(g.get("seed", 1))
		var click_p := CRACKLE_HZ * amt / sr
		var click_left := 0
		var click_v := 0.0
		var cq := pow(2.0, CRACKLE_BITS - 1.0)
		for j in n:
			var i := s + j
			var dry: Vector2 = src[i]
			var wet := dry
			match StringName(g.kind):
				&"gap":
					wet = dry * (1.0 - lerpf(0.75, 1.0, amt))
				&"repeat":
					# the first `chunk` of the window, again and again: "st-st-st"
					wet = src[s + (j % chunk)] if rep > 1 else src[maxi(0, i - n)]
				&"chop":
					# on for the first part of each cycle, off for `off` of it
					var ph := fmod(float(j), period)
					var on_len := period * (1.0 - off)
					var gate := 1.0
					if ph >= on_len:
						gate = 0.0
						if ph < on_len + ce:
							gate = 0.5 + 0.5 * cos(PI * (ph - on_len) / ce)
						elif ph > period - ce:
							gate = 0.5 - 0.5 * cos(PI * (ph - (period - ce)) / ce)
					wet = dry * gate
				&"crackle":
					wet = Vector2(roundf(dry.x * cq) / cq, roundf(dry.y * cq) / cq)
					if click_left <= 0 and cr.randf() < click_p:
						click_left = cr.randi_range(1, 3)
						click_v = cr.randf_range(-1.0, 1.0) * CRACKLE_PEAK * lerpf(0.6, 1.0, amt)
					if click_left > 0:
						wet += Vector2(click_v, click_v)
						click_v *= -0.6
						click_left -= 1
				&"crush":
					var h: Vector2 = src[i - (j % hold)]
					wet = Vector2(roundf(h.x * q) / q, roundf(h.y * q) / q)
				&"ring":
					var m := sin(TAU * RING_HZ * float(j) / sr)
					wet = dry * lerpf(1.0, m, lerpf(0.5, 0.85, amt))
				&"wobble":
					var dl := WOBBLE_MS * 0.001 * sr * lerpf(0.6, 1.0, amt) \
						* 0.5 * (1.0 - cos(TAU * float(j) / float(n)))
					var at := float(i) - dl
					var k := int(floorf(at))
					var f := at - float(k)
					wet = (src[maxi(0, k)] as Vector2).lerp(src[maxi(0, k + 1)], f)
			# the window's own fade, raised cosine, in and out
			var w := 1.0
			if j < edge:
				w = 0.5 - 0.5 * cos(PI * float(j) / float(edge))
			elif j >= n - edge:
				w = 0.5 - 0.5 * cos(PI * float(n - 1 - j) / float(edge))
			x[i] = dry.lerp(wet, w)
	return x


## Pure script work, 3 to 5 ms a second of voice, so it belongs on the worker, not the main thread.
static func pcm16(x: PackedVector2Array) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(x.size() * 4)
	var o := 0
	for v: Vector2 in x:
		b.encode_s16(o, clampi(int(roundf(v.x * 32767.0)), -32768, 32767))
		b.encode_s16(o + 2, clampi(int(roundf(v.y * 32767.0)), -32768, 32767))
		o += 4
	return b


## THE MAIN THREAD'S HALF: the PCM as a stream (a resource, so made here). A
## copy of the bytes and nothing else.
static func from_pcm(b: PackedByteArray, sr: float) -> AudioStream:
	if b.is_empty():
		return null
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.stereo = true
	w.mix_rate = int(sr)
	w.data = b
	return w


## Frames to a stream in one go (the harness's way).
static func to_wav(x: PackedVector2Array, sr: float) -> AudioStream:
	return from_pcm(pcm16(x), sr)
