extends Node

## BAKES THE HANGARS' CUES: each ship-select room's cues worked out of its life (`HangarCues.compute`) into
## `HangarCues.BAKED`, one cue a line. Rerun after changing a room's life or HangarCues (HangarSoundTest fails
## until you do): `python tools/dev/hangar_sound.py plans`. `out=<path>` writes elsewhere.
## Why: docs/why/HangarSound.md#baked-cues

const ROOMS: Array[StringName] = [&"korvan", &"solari", &"old"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var lines: Array[String] = []
	for id in ROOMS:
		var r := ShipRoom.make(id)
		r.build()
		add_child(r.under)
		add_child(r.above)
		var us := Time.get_ticks_usec()
		var p := HangarCues.compute(r)
		print("  %s: %d cues in %.1f ms" % [id, p.cues.size(), (Time.get_ticks_usec() - us) / 1000.0])
		var rows: Array[String] = []
		for c in p.cues:
			rows.append("  " + JSON.stringify(HangarCues.row_of(c), "", false, true))
		lines.append("%s: [\n%s\n ]" % [JSON.stringify(String(id)), ",\n".join(rows)])
		r.under.queue_free()
		r.above.queue_free()
	var note := JSON.stringify("Made by -- sheet=HangarCuesBake (python tools/dev/hangar_sound.py plans); "
		+ "docs/why/HangarSound.md#baked-cues")
	var text := "{\n \"_note\": %s,\n %s\n}\n" % [note, ",\n ".join(lines)]
	var out := Harness.arg("out", ProjectSettings.globalize_path(HangarCues.BAKED))
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		push_error("HangarCuesBake: cannot write %s" % out)
		get_tree().quit(1)
		return
	f.store_string(text)
	f.close()
	print("hangarcuesbake: wrote %s" % out)
	get_tree().quit(0)
