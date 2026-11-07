class_name Unlocks
extends RefCounted

## Unlocks reverse the flight-record ruling but grant no power, only doors; derived, never stored.
## Why: docs/why/Unlocks.md#meta-progression

## Each maker unlocks by winning with the one before; order follows `DB.STARTABLE`.
const CHAIN: Array[StringName] = [
	&"korvan", &"solari", &"probate", &"redline", &"cygnet", &"verity", &"calyx",
]

## The manufacturer you must win with to earn this one, or empty for the first.
static func prereq(manufacturer: StringName) -> StringName:
	var i := CHAIN.find(manufacturer)
	return CHAIN[i - 1] if i > 0 else &""

## Every manufacturer won with at least once, by id.
static func won_with() -> Dictionary:
	var out: Dictionary = {}
	for r in RunHistory.load_all():
		var e: Dictionary = r
		if int(e.get("outcome", -1)) != int(RunHistory.Outcome.WON):
			continue
		# Keep the old `chassis_maker` key: a version bump would delete the flight record.
		# Why: docs/why/Unlocks.md#old-key
		var m := StringName(str(e.get("chassis_manufacturer",
			e.get("chassis_maker", ""))))
		# A win with no manufacturer still counts (Geno, Oct 23), for the first opened not yet won.
		# Why: docs/why/Unlocks.md#blank-manufacturer
		if m == &"":
			m = _first_unwon(out)
		if m != &"":
			out[m] = true
	return out

## The first manufacturer in the chain that is open (its prerequisite won, or
## the first) and not yet won with, given the wins so far.
static func _first_unwon(won: Dictionary) -> StringName:
	for m in CHAIN:
		if won.has(m):
			continue
		var need := prereq(m)
		if need == &"" or won.has(need):
			return m
	return &""

## Dev mode opens everything, as a build you cannot start as Calyx in cannot test Calyx.
static func unlocked(manufacturer: StringName) -> bool:
	if DevMode.enabled:
		return true
	var need := prereq(manufacturer)
	if need == &"":
		return true
	return won_with().has(need)

## Locked makers' parts appear nowhere (Jon, Oct 20); the record is read once at run start.
## Why: docs/why/Unlocks.md#new-run-world
static func open_now() -> Array[StringName]:
	var out: Array[StringName] = []
	var won := {} if DevMode.enabled else won_with()
	for m in CHAIN:
		var need := prereq(m)
		if DevMode.enabled or need == &"" or won.has(need):
			out.append(m)
	return out

## In a party the host's unlocks decide the world, so shared positional rolls stay one pool.
## Why: docs/why/Unlocks.md#party-unlocks
static func for_new_run() -> Array[StringName]:
	if Net.state == NetSession.State.DIVING and Net.dive_seed != 0 \
			and not Net.dive_unlocked.is_empty():
		return Net.dive_unlocked.duplicate()
	return open_now()

## The prerequisite is named only once unlocked, so the chain reads as a horizon, not a checklist.
## Why: docs/why/Unlocks.md#lock-line
static func lock_line(manufacturer: StringName) -> String:
	var need := prereq(manufacturer)
	if need == &"":
		return ""
	var known := unlocked(need)
	var who := DB.short_name(DB.manufacturer_name(need)).to_upper() if known else "???"
	return "Win a run with %s to unlock this manufacturer." % who
