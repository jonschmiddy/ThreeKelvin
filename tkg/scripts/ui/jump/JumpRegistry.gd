class_name JumpRegistry
extends RefCounted

## The jump films that have landed, and which one this jump plays: one draw per jump from
## `Rng.derive(&"jump_film", jumps)`, so a run's seed decides and repeats are allowed (Jon,
## Nov 10, Q3 B). `-- jumpfilm=r4` forces one for the harnesses and the films' captures.
## Why: docs/why/JumpRegistry.md#pick

const ALL: Array[StringName] = [&"r12", &"r4", &"r9", &"r2"]

static var forced: StringName = &""
static var _parsed := false


static func pick(jumps: int) -> StringName:
	if not _parsed:
		_parsed = true
		for a in OS.get_cmdline_user_args():
			if (a as String).begins_with("jumpfilm="):
				forced = StringName((a as String).substr(9))
	if forced in ALL:
		return forced
	var r := Rng.derive(&"jump_film", jumps)
	return ALL[r.randi() % ALL.size()]


static func make(id: StringName) -> JumpSequence:
	match id:
		&"r4":
			return SeqSlitScan.new()
		&"r9":
			return SeqUnravel.new()
		&"r2":
			return SeqFourth.new()
		_:
			return SeqNegative.new()
