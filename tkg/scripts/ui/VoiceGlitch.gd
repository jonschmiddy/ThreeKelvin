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


## Decode `stream` to stereo frames at the mixer's rate. {x, sr}.
static func decode(stream: AudioStream) -> Dictionary:
	var pb := stream.instantiate_playback()
	if pb == null:
		return {}
	pb.start(0.0)
	var secs := stream.get_length()
	var sr := AudioServer.get_mix_rate()
	var want := int(roundf(secs * sr))
	var x := PackedVector2Array()
	var guard := 0
	while pb.is_playing() and x.size() < want and guard < 4000:
		x.append_array(pb.mix_audio(1.0, 4096))
		guard += 1
	if x.size() > want:
		x.resize(want)
	return {x = x, sr = sr}


## Her take with `plan`'s glitches, as a stream the same length. Null if it
## could not be decoded (the caller plays the take as it was).
static func render(stream: AudioStream, plan: Array) -> AudioStream:
	var d := decode(stream)
	if d.is_empty() or (d.x as PackedVector2Array).is_empty():
		return null
	var x: PackedVector2Array = d.x
	var sr: float = d.sr
	x = apply(x, sr, plan)
	return to_wav(x, sr)


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


## Stereo frames to a stream, through a 32-bit float WAV in memory: the frames'
## own bytes behind a 44-byte header, so no sample is touched in script.
static func to_wav(x: PackedVector2Array, sr: float) -> AudioStream:
	var data := x.to_byte_array()
	var h := PackedByteArray()
	h.resize(44)
	h.encode_u32(0, 0x46464952)         # "RIFF"
	h.encode_u32(4, 36 + data.size())
	h.encode_u32(8, 0x45564157)         # "WAVE"
	h.encode_u32(12, 0x20746d66)        # "fmt "
	h.encode_u32(16, 16)
	h.encode_u16(20, 3)                 # IEEE float
	h.encode_u16(22, 2)
	h.encode_u32(24, int(sr))
	h.encode_u32(28, int(sr) * 8)
	h.encode_u16(32, 8)
	h.encode_u16(34, 32)
	h.encode_u32(36, 0x61746164)        # "data"
	h.encode_u32(40, data.size())
	h.append_array(data)
	return AudioStreamWAV.load_from_buffer(h)
