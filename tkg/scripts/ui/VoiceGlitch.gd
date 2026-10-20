class_name VoiceGlitch
extends RefCounted

## A.S.H.'S VOICE BREAKING UP while the hull fails (`LowHull`; Jon: "Maybe even
## A.S.H.'s voice could glitch a bit?"). Her take, decoded by Godot's own
## decoder (`AudioStreamPlayback.mix_audio`, as `AshTest` renders it), a few
## short windows changed (`LowHull.voice_plan`), and played from memory as an
## AudioStreamWAV in the take's place. NO NEW RECORDING AND NO SPEND: the same
## take, edited live.
##
## THE SAME LENGTH, SAMPLE FOR SAMPLE. Every glitch replaces samples in place;
## none adds or removes any. The words type to the take's length
## (`SignalText.rate_for`), so a repeat that pushed the rest of her line later
## would part her words from her voice.
##
## THE KINDS, each a window of 20 to 60 ms (the wobble 100 to 150), so none can
## cover a whole word and she stays understandable:
##   gap     a dropout: the window drops to `1 - amt` of itself
##   repeat  a stutter: the window is the stretch just before it, again
##   crush   bit-crushed and sample-held (fewer bits and a lower rate)
##   ring    ring-modulated at RING_HZ, mixed in at `amt`
##   wobble  a pitch wobble: a delay that swells to WOBBLE_MS and back, so the
##           pitch bends down and up and lands where it started
## EVERY WINDOW IS FADED IN AND OUT over EDGE_S, so no glitch starts or ends on a
## step (her takes were de-clicked once: `docs/ash.md`, "The takes are
## de-clicked"; a glitch must not put the click back).

const EDGE_S := 0.004
const RING_HZ := 170.0
const WOBBLE_MS := 2.0
## Bits kept by `crush` at amt 0 and at amt 1, and its sample hold.
const CRUSH_BITS := [7.0, 5.0]
const CRUSH_HOLD := [3, 6]


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


## Her take with `plan`'s glitches, as a stream the same length, all on the
## calling thread. Null if it could not be decoded. In play the work is split
## (`bake` on a worker, `from_pcm` on the main thread: `Audio.ash_voice_prepare`).
static func render(stream: AudioStream, plan: Array) -> AudioStream:
	var d := decode(stream)
	if d.is_empty() or (d.x as PackedVector2Array).is_empty():
		return null
	return from_pcm(pcm16(apply(d.x, d.sr, plan)), d.sr)


## THE WORKER'S HALF: decode, glitch, and the 16-bit PCM. Pure CPU on arrays,
## no resource made; empty if nothing decoded.
static func bake(pb: AudioStreamPlayback, secs: float, sr: float, plan: Array) -> PackedByteArray:
	var x := decode_from(pb, secs, sr)
	if x.is_empty():
		return PackedByteArray()
	return pcm16(apply(x, sr, plan))


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
		for j in n:
			var i := s + j
			var dry: Vector2 = src[i]
			var wet := dry
			match StringName(g.kind):
				&"gap":
					wet = dry * (1.0 - lerpf(0.75, 1.0, amt))
				&"repeat":
					wet = src[maxi(0, i - n)]
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


## Stereo frames as 16-bit PCM, interleaved, little-endian: what an
## AudioStreamWAV holds. Pure CPU, sample by sample in script, so it is the
## worker's to do (3 to 5 ms a second of her voice there; on the main thread it
## would be the hitch this split exists to remove).
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
