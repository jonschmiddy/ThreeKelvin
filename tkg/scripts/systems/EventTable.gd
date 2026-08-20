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

static func build_all() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	events.assign([
		{
			title = "Drifting lifepod",
			body = "A pod tumbles past, transponder weak. Someone is still inside, or was.",
			options = [
				{label = "Crack it open", effect = func() -> Dictionary:
					if Rng.event.randf() < 0.6:
						Run.add_credits(25)
						return {text = "Cargo, no occupant. 25 credits."}
					Run.take_hull_damage(6, "A scavenger trap finished what the cold started.")
					return {text = "A scavenger trap. 6 hull."}},
				{label = "Leave it", effect = func() -> Dictionary:
					return {text = "You log the position and jump. It stays with you."}},
			],
		},
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
					Sig.resources_changed.emit()
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
					Run.heat_cap_bonus += 3
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
					Sig.resources_changed.emit()
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
					Run.found_hull = LootGen.roll_hull(Run.node_at().danger)
					Sig.ship_changed.emit()
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
					Sig.resources_changed.emit()
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
		{
			title = "Collapsed lane",
			body = "The short way on runs through a shipbreaker's yard — a lane of dead hulls packed too close to thread. Going around costs a day and a tank.",
			options = [
				{label = "Push through the wrecks",
					met = func() -> Dictionary:
						Run.fuel += 10
						Sig.resources_changed.emit()
						return {text = "Plating screams the length of the lane and holds. You come out the far side with the fuel you did not spend going round."},
					clean = func() -> Dictionary:
						Run.take_hull_damage(4, "The shipbreaker's lane took its cut.")
						Run.fuel += 10
						Sig.resources_changed.emit()
						return {text = "Something gives near the bow. You keep going, and you keep the fuel — four hull for ten is a trade you would take again."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(9, "The shipbreaker's lane took its cut.")
						return {text = "Halfway in, a spar goes through the forward plating. You reverse out of the lane the way you came."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(16, "A dead hull folded the bow in the breaker's lane.")
						return {text = "The lane closes on you. What comes out the other side is your ship, mostly."},
					check = {attr = &"hull", need = 5}},
				{label = "Go around", effect = func() -> Dictionary:
					return {text = "The long way. Nothing happens on it, which is the point."}},
			],
		},
		{
			title = "Slipping orbit",
			body = "A gas giant has you. Not badly — yet. The gauges give you perhaps four minutes to decide whether your engines are the answer.",
			options = [
				{label = "Burn out of the well",
					met = func() -> Dictionary:
						Run.add_credits(30)
						return {text = "You climb out of it like it was nothing, and clip a derelict's tumbling wing on the way past. Thirty credits of somebody else's bad afternoon."},
					clean = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 14)
						Sig.resources_changed.emit()
						return {text = "The engines find it, eventually, and drink fourteen units doing it."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 26)
						Sig.resources_changed.emit()
						return {text = "You get out. The tank shows what it cost and you decide not to look at it again."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 40)
						Sig.resources_changed.emit()
						return {text = "You skim the upper atmosphere on the way up. Forty units, and most of your paint."},
					check = {attr = &"thrust", need = 6}},
				{label = "Ride it round", effect = func() -> Dictionary:
					return {text = "One slow orbit, no burn. It costs you nothing but the hour."}},
			],
		},
		{
			title = "Mine drift",
			body = "Someone seeded this approach and never came back to sweep it. The mines are old, patient, and still keeping perfect station.",
			options = [
				{label = "Thread it",
					met = func() -> Dictionary:
						Run.stow(LootGen.roll_module(Run.node_at().danger))
						Sig.ship_changed.emit()
						return {text = "You go through the field like water through a grate, and lift a module off the wreck of somebody who did not."},
					clean = func() -> Dictionary:
						Run.take_hull_damage(5, "A mine clipped the flank on the way through.")
						return {text = "One of them finds your flank on the way out. Only one."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(11, "The minefield closed on the way through.")
						return {text = "Two, then a third. You reverse the last hundred metres with the hull ringing."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(18, "A pre-war mine found the ship amidships.")
						return {text = "The old ones are the worst. This one waits until you are past before it decides."},
					check = {attr = &"maneuver", need = 6}},
				{label = "Sweep wide", effect = func() -> Dictionary:
					return {text = "You give the whole drift a berth and lose nothing but time."}},
			],
		},
		{
			title = "The corona",
			body = "A flare star mid-cycle, and a wreck sitting inside its corona with the holds intact. Everyone else has looked at this and left.",
			options = [
				{label = "Go in hot",
					met = func() -> Dictionary:
						Run.add_credits(85)
						return {text = "Your vents hold the whole way in and the whole way out. Eighty-five credits out of a hold nobody else would reach."},
					clean = func() -> Dictionary:
						Run.heat += 8
						Run.add_credits(45)
						Sig.resources_changed.emit()
						return {text = "You come out carrying forty-five credits and a reactor that will need a minute."},
					partial = func() -> Dictionary:
						Run.heat += 16
						Run.add_credits(20)
						Sig.resources_changed.emit()
						return {text = "You get one hold open and take what is nearest before the temperature makes the decision for you."},
					botched = func() -> Dictionary:
						Run.heat += 26
						Sig.resources_changed.emit()
						return {text = "The flare comes early. You leave with nothing and a ship that is still ticking as it cools."},
					check = {attr = &"thermal", need = 6}},
				{label = "Watch it burn", effect = func() -> Dictionary:
					return {text = "You hold station outside the corona and log the wreck for somebody with better vents."}},
			],
		},
		{
			title = "Ghost signal",
			body = "There is a carrier under the background hiss on this bearing. Too regular to be a star, too weak to be a station.",
			options = [
				{label = "Resolve it",
					met = func() -> Dictionary:
						var found := 0
						for r in Run.in_range():
							var node: MapGen.MapNode = r
							if not node.visited:
								node.visited = true
								found += 1
						Run.add_credits(25)
						return {text = "A precursor beacon, still counting. You cannot read it, but you can triangulate off it — %d systems resolve out of the dark, and the housing is worth twenty-five." % found},
					clean = func() -> Dictionary:
						for r in Run.in_range():
							var node: MapGen.MapNode = r
							if not node.visited:
								node.visited = true
								break
						return {text = "You pull one clean bearing out of the noise before it drifts. One system, named."},
					partial = func() -> Dictionary:
						return {text = "You chase it for an hour and it resolves into your own reactor harmonics, reflected off something you never find."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 12)
						Sig.resources_changed.emit()
						return {text = "You follow it a long way before admitting it was never there. Twelve units of fuel, spent on a bearing."},
					check = {attr = &"sensors", need = 4}},
				{label = "Log it and go", effect = func() -> Dictionary:
					return {text = "You write the bearing down. Someone with better ears can have it."}},
			],
		},
		{
			title = "Customs cordon",
			body = "A revenue cutter is running a cordon across the only lane out, and they are stopping everyone.",
			options = [
				{label = "Run the cordon dark",
					met = func() -> Dictionary:
						return {text = "You go through cold and silent, close enough to read their hull number. They never look up."},
					clean = func() -> Dictionary:
						Run.heat += 6
						Sig.resources_changed.emit()
						return {text = "You hold everything off but the reactor, and the reactor is what you pay with. Six heat, no questions."},
					partial = func() -> Dictionary:
						Run.add_credits(-40)
						return {text = "They get a partial return and hail you in. The fine is forty credits and a lecture."},
					botched = func() -> Dictionary:
						Run.add_credits(-40)
						return {text = "They light you up from two sides, and something in the cutter's escort decides you are worth the trouble.", fight = true},
					check = {attr = &"stealth", need = 4}},
				{label = "Submit to inspection", effect = func() -> Dictionary:
					return {text = "You stop, open the holds, and answer everything twice. It costs an afternoon and nothing else."}},
			],
		},
	])
	return out
