class_name AshLines
extends RefCounted

## A.S.H.'S LINES, the thirty Jon and Ashlee kept over two rounds (Oct 17), by the
## moment each was written for. The source of truth is `docs/ash_lines.json` at
## the repo root, outside the game's folder; this is that file as the game reads
## it (plus `VOICE`, her recorded take of each), and `-- sheet=AshTest` fails if the two ever differ by a character. More
## lines are more entries here and nothing else (`docs/ash.md`: "from a data
## table, like the cards, so more lines never need code").
##
## WHEN EACH MOMENT COMES (`Ash`, which decides):
##   launch  a new run's first launch, on LOCAL once the ship has come to rest
##   greed   one more wreck: the third wreck you open since you last docked,
##           and every third after it
##   haul    a big haul: a credit chit of HAUL_CREDITS or more, or an epic or
##           better part, taken aboard
##   hot     over the heat limit in a fight
##   hull    moving to a new hull, the first time she is up in it
##   hurt    hull failing: a quarter or less of the hull left, alive
##   doubt   once in a long while, on arriving in a new system

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


## HER VOICE, line by line (Jon's picks, Oct 17: ElevenLabs, the Cortana chain,
## levelled to -18.3 LUFS). A line's id is its moment and its place in that
## moment's list, from 1 (`id_of`); its file is `VOICE_DIR` + the name here.
## A line with "" has no take yet and is said as text alone, as every line was
## before (`AshPortrait.say`). A new line's take is one entry here; new takes
## replace these files and entries and nothing else (the typing follows each
## file's own length). These are placeholders: Jon is re-recording all thirty.
const VOICE_DIR := "res://assets/audio/voice/ash/%s.ogg"
const VOICE: Dictionary = {
	&"doubt_01": "doubt_01", &"doubt_02": "doubt_02", &"doubt_03": "doubt_03",
	&"greed_01": "greed_01", &"greed_02": "greed_02", &"greed_03": "greed_03",
	&"greed_04": "greed_04",
	&"haul_01": "haul_01", &"haul_02": "haul_02", &"haul_03": "haul_03",
	&"haul_04": "haul_04", &"haul_05": "haul_05",
	&"hot_01": "hot_01", &"hot_02": "hot_02", &"hot_03": "hot_03", &"hot_04": "hot_04",
	&"hull_01": "hull_01", &"hull_02": "hull_02", &"hull_03": "hull_03", &"hull_04": "hull_04",
	&"hurt_01": "hurt_01", &"hurt_02": "hurt_02", &"hurt_03": "hurt_03", &"hurt_04": "hurt_04",
	&"launch_01": "launch_01", &"launch_03": "launch_03", &"launch_04": "launch_04",
	&"launch_05": "launch_05",
	# TODO(Jon): the two takes still to pick (the scratchpad's ash-voice/lines/fx,
	# <id>_3/4/5.ogg). Copy the pick to assets/audio/voice/ash/<id>.ogg, import,
	# and put its name here; nothing else changes.
	&"greed_05": "", &"launch_02": "",
}


## A line's id, "greed_05"; "" for a line that is not one of hers.
static func id_of(line: String) -> StringName:
	for k in MOMENTS:
		var i := of(k).find(line)
		if i >= 0:
			return StringName("%s_%02d" % [k, i + 1])
	return &""


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
