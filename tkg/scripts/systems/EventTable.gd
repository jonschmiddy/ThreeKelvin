class_name EventTable
extends RefCounted

## Narrative nodes. Each option returns {text, fight?} so the screen stays dumb.
## Choices lean on the economy and the build rather than pure coin flips.

static func pick() -> Dictionary:
	var all := build_all()
	return all[randi() % all.size()]

static func build_all() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	events.assign([
		{
			title = "Drifting lifepod",
			body = "A pod tumbles past, transponder weak. Someone is still inside, or was.",
			options = [
				{label = "Crack it open", effect = func() -> Dictionary:
					if randf() < 0.6:
						Run.add_scrap(25)
						return {text = "Cargo, no occupant. 25 scrap."}
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
					Run.cargo.append(LootGen.roll_module(Run.node_at().danger))
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
				{label = "Buy (20 scrap)", effect = func() -> Dictionary:
					if Run.scrap < 20:
						return {text = "You cannot afford it."}
					Run.add_scrap(-20)
					Run.heat_cap_bonus += 3
					return {text = "Heat capacity +3, permanently."}},
				{label = "Decline", effect = func() -> Dictionary:
					return {text = "You keep your scrap. The cold keeps its edge."}},
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
						Run.add_scrap(-20 * c)
						return {text = "Fined 20 scrap per illegal part."}
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
					Run.add_scrap(35)
					return {text = "35 scrap of plating and wire."}},
			],
		},
		{
			title = "Cold sleeper",
			body = "A single cryopod, still drawing power from a dying cell. The occupant's chart reads three degrees.",
			options = [
				{label = "Restore power (10 scrap)", effect = func() -> Dictionary:
					if Run.scrap < 10:
						return {text = "Not enough power to spare. The pod goes dark."}
					Run.add_scrap(-10)
					Run.exotic += 1
					return {text = "They live, briefly, and give you something they were carrying."}},
				{label = "Take the power cell", effect = func() -> Dictionary:
					Run.fuel += 9
					Sig.resources_changed.emit()
					return {text = "Three jumps. The pod goes dark behind you."}},
			],
		},
	])
	return events
