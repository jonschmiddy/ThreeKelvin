class_name EventTable
extends RefCounted

## Narrative nodes. Each option returns {text, fight?} so the screen stays dumb.
## Choices lean on the economy and the build rather than pure coin flips.

static func pick(r: RandomNumberGenerator = Rng.event) -> Dictionary:
	var all := build_all()
	return all[r.randi() % all.size()]

## The same roll, as something that can be written to a save. A hail has to be
## decided once and stay decided — see MapNode.event_key.
## `r` is a parameter and the caller is expected to pass a POSITIONAL one —
## Rng.derive(&"event", node.index). Which hail is waiting at a system is a
## property of the system, not of the order four ships happened to arrive in,
## and a shared cursor would hand each of them a different one.
static func pick_key(r: RandomNumberGenerator = Rng.event) -> String:
	var all := build_all()
	return str(all[r.randi() % all.size()].title)

## Resolve a saved key back to its event. An unknown key re-rolls rather than
## failing: an event retired or renamed between the save and the load is a
## development accident, and losing the hail is a smaller cost than refusing to
## open the run.
static func by_key(key: String) -> Dictionary:
	for e in build_all():
		if str(e.title) == key:
			return e
	push_warning("EventTable: no event titled '%s'; re-rolling" % key)
	return pick()

## NOTHING IN A RUNNING GAME REACHES THIS TABLE. Recorded 2026-08-27, after the
## batch-04 port, because a file this size that is never called is a trap for
## whoever opens it next.
##
## `MapNode.event_key` is what chose an event, and the type collapse deleted the
## line that set it -- an EVENT node used to roll one on arrival and there are no
## EVENT nodes. `Router.show_event()` still compiles and has no callers.
##
## Seven entries were retired here: drifting lifepod, collapsed lane, slipping
## orbit, mine drift, the corona, ghost signal and customs cordon all exist in
## `OptionTable` now, re-cut against RULING 9 -- customs cordon especially, whose
## own best outcome used to be "nothing bad happens", which only reads as a
## reward when the event IS the whole system and leaving is impossible.
##
## SEVEN REMAIN AND THEY ARE NOT SUPERSEDED, only unported: dead station, coolant
## seller, distress beacon, whale fall, inspection sweep, derelict hauler, cold
## sleeper. That is authored prose nobody has decided about, which is why this
## file still exists -- deleting it would be throwing away content, not cleaning
## up code. Port them or delete them deliberately; do not let them rot here.
##
## `event_key` stays on `MapNode` and in the save. Removing a saved field costs a
## version bump, and it is not worth one on its own -- batch it with the next.
static func build_all() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	events.assign([
		{
			title = "Dead station",
			body = "A station hangs dark and unpowered. The docking clamps still work.",
			options = [
				{label = "Salvage the racks", effect = func() -> Dictionary:
					Run.stow(LootGen.roll_module(Run.node_at().danger))
					Sig.ship_changed.emit()
					return {text = "You pull a module from a dead bay."}},
				{label = "Siphon the tanks", effect = func() -> Dictionary:
					Run.fuel += 12
					return {text = "Four jumps of fuel, tasting of rust."}},
			],
		},
		{
			title = "Coolant seller",
			body = "A trader offers surplus coolant. Cheap, and probably stolen.",
			options = [
				{label = "Buy (20 credits)", effect = func() -> Dictionary:
					if Run.credits < 20:
						return {text = "You cannot afford it."}
					Run.add_credits(-20)
					Run.add_heat_cap(3)
					return {text = "Heat capacity +3, permanently."}},
				{label = "Decline", effect = func() -> Dictionary:
					return {text = "You keep your credits. The cold keeps its edge."}},
			],
		},
		{
			title = "Distress beacon",
			body = "A looping voice, repeating coordinates one jump off your route.",
			options = [
				{label = "Answer it", effect = func() -> Dictionary:
					return {text = "It was bait. Something is already firing.", fight = true}},
				{label = "Run silent", effect = func() -> Dictionary:
					Run.heat = 0
					Sig.resources_changed.emit()
					return {text = "You cut the reactor and drift past. Heat cleared."}},
			],
		},
		{
			title = "Whale fall",
			body = "The corpse of something enormous, slowly coming apart in the dark.",
			options = [
				{label = "Harvest it", effect = func() -> Dictionary:
					Run.exotic += 2
					return {text = "2 exotic materials, and a smell you will not forget."}},
				{label = "Let it rest", effect = func() -> Dictionary:
					var h := Run.heal(8)
					return {text = "You drift alongside a while. Hull +%d. Hard to explain." % h}},
			],
		},
		{
			title = "Inspection sweep",
			body = "A patrol hails you for a routine cargo check.",
			options = [
				{label = "Submit to inspection", effect = func() -> Dictionary:
					var c := Run.contraband_count()
					if c > 0:
						Run.add_credits(-20 * c)
						return {text = "Fined 20 credits per illegal part."}
					return {text = "Clean. They wave you through, disappointed."}},
				{label = "Burn away", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 6)
					Run.take_hull_damage(4, "You ran, and something clipped you on the way out.")
					return {text = "You run. 2 fuel, 4 hull, no record."}},
			],
		},
		{
			title = "Derelict hauler",
			body = "An old freight frame, gutted but structurally intact.",
			options = [
				{label = "Claim the hull", effect = func() -> Dictionary:
					Run.find_hull(LootGen.roll_hull(Run.node_at().danger))
					return {text = "The frame is flyable: %s" % Run.found_hull.display_name()}},
				{label = "Strip it for scrap", effect = func() -> Dictionary:
					Run.add_credits(35)
					return {text = "35 credits of plating and wire."}},
			],
		},
		{
			title = "Cold sleeper",
			body = "A single cryopod, still drawing power from a dying cell. The occupant's chart reads three degrees.",
			options = [
				{label = "Restore power (10 credits)", effect = func() -> Dictionary:
					if Run.credits < 10:
						return {text = "Not enough power to spare. The pod goes dark."}
					Run.add_credits(-10)
					Run.exotic += 1
					return {text = "They live, briefly, and give you something they were carrying."}},
				{label = "Take the power cell", effect = func() -> Dictionary:
					Run.fuel += 9
					return {text = "Three jumps. The pod goes dark behind you."}},
			],
		},
	])
	events.append_array(_checked())
	return events

## The events that read your ship rather than a die.
##
## One per attribute, so every axis on the refit screen has somewhere it gets
## spent. An attribute nothing checks is just a number, and the reason they are
## derived from live gauges was so they could be asked for.
##
## Three rules hold across all six, all from the events contract:
##
## FAILURE STAYS IN ITS DOMAIN. A ram costs hull, a burn costs heat, a sneak
## costs being seen. A botch surprises you in DEGREE, never in kind — if
## threading a minefield could cost fuel, the option was lying about what it was.
##
## EVERY EVENT HAS A FREE EXIT. Exactly one option that costs nothing and is
## genuinely unpunished, so declining a 20% gamble is a real choice rather than
## a trap with no door.
##
## `check` IS WRITTEN LAST in every option, which is a syntax defence rather
## than a style. A lambda's final `return {…}` and the option dictionary's own
## closing brace collide on the same line, so ending on a plain value means
## every outcome line closes the same way and none of them is special.
static func _checked() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
	])
	return out
