class_name Unlocks
extends RefCounted

## Which manufacturers you have earned the right to fly.
##
## META-PROGRESSION, AND IT REVERSES A RULING. `CLAUDE.md` said "the flight
## record is a record, not meta-progression — nothing in RunHistory feeds back
## into a run", on the grounds that identity is assembled mid-run and a history
## that granted a starting bonus would be the first crack in that. This is that
## crack, opened deliberately.
##
## What makes it survivable: an unlock grants no POWER. Every house is balanced
## against every other, so finishing the chain widens the choice at run start and
## changes nothing about how hard a run is. A locked player is not a weaker
## player, they are a player with fewer doors. That is the only shape of
## meta-progression this game can take without repealing the greed clock.
##
## DERIVED, NEVER STORED. There is no unlock file to desync, migrate or cheat —
## the answer is a fold over the flight record. The cost is that runs recorded
## before `chassis_maker` existed cannot say who flew them, so they unlock
## nothing; a save wiped is progress wiped, which is the same deal the record
## already offered.

## The chain, in order. Each house is unlocked by WINNING with the one before it,
## and the first is free. Order follows DB.STARTABLE so the chassis select reads
## top to bottom as the order you earn them in.
const CHAIN: Array[StringName] = [
	&"korvan", &"solari", &"probate", &"redline", &"cygnet", &"verity", &"calyx",
]

## The house you must win with to earn this one, or empty for the first.
static func prereq(man: StringName) -> StringName:
	var i := CHAIN.find(man)
	return CHAIN[i - 1] if i > 0 else &""

## Every house won with at least once, by id.
static func won_with() -> Dictionary:
	var out: Dictionary = {}
	for r in RunHistory.load_all():
		var e: Dictionary = r
		if int(e.get("outcome", -1)) != int(RunHistory.Outcome.WON):
			continue
		var m := StringName(str(e.get("chassis_maker", "")))
		if m != &"":
			out[m] = true
	return out

## Can this house be flown?
##
## Dev mode opens everything, because a build you cannot start as Calyx in is a
## build you cannot test Calyx in.
static func unlocked(man: StringName) -> bool:
	if DevMode.enabled:
		return true
	var need := prereq(man)
	if need == &"":
		return true
	return won_with().has(need)

## What the chassis select prints for a locked house.
##
## The prerequisite is NAMED only if you have already unlocked it. Otherwise it
## is ???, so the chain reveals itself one rung at a time rather than laying the
## whole ladder out on the first run — which would make six locked rows into a
## checklist instead of a horizon.
static func lock_line(man: StringName) -> String:
	var need := prereq(man)
	if need == &"":
		return ""
	var known := unlocked(need)
	var who := DB.short_name(DB.manufacturer_name(need)).to_upper() if known else "???"
	return "Win a run with %s to unlock this manufacturer." % who
