class_name AshLines
extends RefCounted

## `docs/ash_lines.json` is the source of truth; `-- sheet=AshTest` fails if this table differs.
## Why: docs/why/AshLines.md#ash-lines

const MOMENTS: Dictionary = {
	&"doubt": {
		moment = "Once in a long while",
		lines = [
			"If anyone's waiting at the other end, they're very patient.",
			"I ran the numbers again. I'll keep them to myself.",
			"We keep going because stopping is worse. Mostly.",
		],
	},
	&"greed": {
		moment = "One more wreck",
		lines = [
			"Sure. What's one more stop between friends.",
			"We are, technically, still allowed to go home.",
			"Fine. But I'm writing down that it was your idea.",
			"One more wreck. You said that four wrecks ago.",
			"The fuel gauge and I have concerns.",
		],
	},
	&"haul": {
		moment = "A big haul",
		lines = [
			"Oh. That's actually good. Don't let it go to your head.",
			"Logged, stowed, and already spent, knowing you.",
			"Fine. That was worth the detour.",
			"Look at us. Solvent.",
			"I'll allow it.",
		],
	},
	&"hot": {
		moment = "Over the heat limit",
		lines = [
			"Bold of you to treat the heat cap as a suggestion.",
			"I'd vent. But you're the pilot.",
			"That's not a warning light. That's the whole panel.",
			"Hot enough to cook on. Please don't.",
		],
	},
	&"hull": {
		moment = "Moving to a new hull",
		lines = [
			"New body. The ceilings are lower. I'll adjust.",
			"I liked the old one. It knew where I kept things.",
			"Moving day. Try not to scratch this one.",
			"Fine. But I'm keeping the old seat settings.",
		],
	},
	&"hurt": {
		moment = "Hull failing",
		lines = [
			"Structural integrity: aspirational.",
			"Small hole. Medium hole. I've stopped naming them.",
			"If you were waiting for a sign, this is the sign.",
			"We're held together by optimism and two welds.",
		],
	},
	&"launch": {
		moment = "First launch",
		lines = [
			"Launch clearance granted. By me. I'm the only one here.",
			"Fuel's full. Optimism's at about half.",
			"Engines warm. That's my job. The rest is yours.",
			"Autonomous Systems Handler, reporting. Please don't make me handle much.",
			"All green. Enjoy it. It won't last.",
		],
	},
}


## Jon's voice picks (Oct 17); a new take is its file and an entry here, nothing else.
## Why: docs/why/AshLines.md#ash-voice
const INTRO := &"launch_04"

const VOICE_DIR := "res://assets/audio/voice/ash/%s.ogg"
const VOICE: Dictionary = {
	&"doubt_01": "doubt_01", &"doubt_02": "doubt_02", &"doubt_03": "doubt_03",
	&"greed_01": "greed_01", &"greed_02": "greed_02", &"greed_03": "greed_03",
	&"greed_04": "greed_04", &"greed_05": "greed_05",
	&"haul_01": "haul_01", &"haul_02": "haul_02", &"haul_03": "haul_03",
	&"haul_04": "haul_04", &"haul_05": "haul_05",
	&"hot_01": "hot_01", &"hot_02": "hot_02", &"hot_03": "hot_03", &"hot_04": "hot_04",
	&"hull_01": "hull_01", &"hull_02": "hull_02", &"hull_03": "hull_03", &"hull_04": "hull_04",
	&"hurt_01": "hurt_01", &"hurt_02": "hurt_02", &"hurt_03": "hurt_03", &"hurt_04": "hurt_04",
	&"launch_01": "launch_01", &"launch_02": "launch_02", &"launch_03": "launch_03",
	&"launch_04": "launch_04", &"launch_05": "launch_05",
}


## A line's id, "greed_05"; "" for a line that is not one of hers.
static func id_of(line: String) -> StringName:
	for k in MOMENTS:
		var i := of(k).find(line)
		if i >= 0:
			return StringName("%s_%02d" % [k, i + 1])
	return &""


## The line with id `id` ("launch_04"); "" for none.
static func line_of(id: StringName) -> String:
	var s := String(id)
	var cut := s.rfind("_")
	if cut < 0:
		return ""
	var all := of(StringName(s.left(cut)))
	var i := s.substr(cut + 1).to_int() - 1
	return String(all[i]) if i >= 0 and i < all.size() else ""


## The voice file for `line`, or "" if it is said as text alone.
static func voice_path(line: String) -> String:
	var f := String(VOICE.get(id_of(line), ""))
	return "" if f == "" else VOICE_DIR % f


static func of(kind: StringName) -> Array:
	return (MOMENTS.get(kind, {}) as Dictionary).get("lines", [])


static func count() -> int:
	var n := 0
	for k in MOMENTS:
		n += of(k).size()
	return n
