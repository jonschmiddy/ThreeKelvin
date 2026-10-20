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
## What makes it survivable: an unlock grants no POWER. Every manufacturer is balanced
## against every other, so finishing the chain widens the choice at run start and
## changes nothing about how hard a run is. A locked player is not a weaker
## player, they are a player with fewer doors. That is the only shape of
## meta-progression this game can take without repealing the greed clock.
##
## DERIVED, NEVER STORED. There is no unlock file to desync, migrate or cheat —
## the answer is a fold over the flight record. The cost is that runs recorded
## before `chassis_manufacturer` existed cannot say who flew them, so they unlock
## nothing; a save wiped is progress wiped, which is the same deal the record
## already offered.

## The chain, in order. Each manufacturer is unlocked by WINNING with the one before it,
## and the first is free. Order follows DB.STARTABLE so the chassis select reads
## top to bottom as the order you earn them in.
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
		# THE OLD KEY IS STILL HONOURED, and here that is the fix rather than a
		# courtesy. The vocabulary pass renamed this field to
		# `chassis_manufacturer`; every record already on disk says
		# `chassis_maker`, so reading only the new name reports an empty
		# manufacturer for every run ever flown and silently re-locks the lot.
		#
		# A VERSION BUMP WOULD BE WORSE. RunHistory discards the whole file on a
		# mismatch, so raising its number would delete the flight record and take
		# every unlock with it -- destroying exactly what this read exists to
		# recover. The file still parses at version 1; two field names moved
		# inside it, and the record is append-only and never rewritten on load.
		# A run flown in July is meant to keep counting.
		var m := StringName(str(e.get("chassis_manufacturer",
			e.get("chassis_maker", ""))))
		if m != &"":
			out[m] = true
	return out

## Can this manufacturer be flown?
##
## Dev mode opens everything, because a build you cannot start as Calyx in is a
## build you cannot test Calyx in.
static func unlocked(manufacturer: StringName) -> bool:
	if DevMode.enabled:
		return true
	var need := prereq(manufacturer)
	if need == &"":
		return true
	return won_with().has(need)

## Every manufacturer this profile has unlocked, in chain order. Korvan at least.
##
## WHAT A NEW RUN'S WORLD MAY HOLD (Jon, Oct 20: "Solari things should NOT show
## up in the game until Solari is unlocked (win the game once)"). A locked
## manufacturer's parts and hulls drop nowhere, sell nowhere and come off no
## derelict: `LootGen.can_appear` reads this, as `Run.unlocked_manufacturers`,
## with `DB.ACTIVE_MANUFACTURERS` on top. The record is read ONCE, at run
## start (`for_new_run`), and the run keeps the answer and its save carries it,
## so a win recorded mid-run, or a CONTINUE on a profile that has moved on
## since, cannot change what a run already under way can find.
##
## One fold over the record rather than `unlocked()` seven times, which would
## read the file seven times.
static func open_now() -> Array[StringName]:
	var out: Array[StringName] = []
	var won := {} if DevMode.enabled else won_with()
	for m in CHAIN:
		var need := prereq(m)
		if DevMode.enabled or need == &"" or won.has(need):
			out.append(m)
	return out

## What a run starting now keeps as its `Run.unlocked_manufacturers`.
##
## IN A PARTY, THE HOST'S. The galaxy is one galaxy: a wreck holds what a wreck
## holds and a shelf is one shelf on every machine (`Rng.derive`), so the pool
## those positional rolls draw from has to be one pool too, or two ships at one
## derelict would open two different hulls. The host's profile decides it and
## sends it with the seed (`NetSession._begin_dive`, PROTOCOL 10). What each
## player may FLY is still their own record, read by the chassis select.
static func for_new_run() -> Array[StringName]:
	if Net.state == NetSession.State.DIVING and Net.dive_seed != 0 \
			and not Net.dive_unlocked.is_empty():
		return Net.dive_unlocked.duplicate()
	return open_now()

## What the chassis select prints for a locked manufacturer.
##
## The prerequisite is NAMED only if you have already unlocked it. Otherwise it
## is ???, so the chain reveals itself one rung at a time rather than laying the
## whole ladder out on the first run — which would make six locked rows into a
## checklist instead of a horizon.
static func lock_line(manufacturer: StringName) -> String:
	var need := prereq(manufacturer)
	if need == &"":
		return ""
	var known := unlocked(need)
	var who := DB.short_name(DB.manufacturer_name(need)).to_upper() if known else "???"
	return "Win a run with %s to unlock this manufacturer." % who
