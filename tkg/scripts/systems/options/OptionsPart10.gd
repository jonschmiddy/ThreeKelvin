class_name OptionsPart10

## Encounters 133 to 137 of the authored table (`in_the_wake` to `the_warm_reactor`), in the order `OptionTable._authored`
## joins them: `roll_for` draws by table order, so entries never move between or within files.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		# Creature events (Jon, Oct 17): a fight may bring a creature when the text is about it;
		# fauna-gated.
		# Why: docs/why/OptionsPart10.md#creature-events
		{
			id = &"in_the_wake",
			title = "In the wake",
			subject = {stage = &"single", pieces = [&"pool_fan"], fights = true},
			body = "A voidwhale calf follows your drive's heat, bumping your stern and shedding hide into your wake.",
			tags = [&"fight", &"hazard"],
			group = &"",
			weight = 11,
			min_danger = 3,
			max_danger = 6,
			needs_fauna = true,
			foe = &"whale",
			choices = [
				{label = "Go cold and wait",
					check = {attr = &"stealth", need = 5},
					met = func() -> Dictionary:
						return {text = "It finds nothing warm and leaves a sheet of hide and a broken spine behind.", material_id = &"hide_scrap", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "It loses interest after three cold hours, and you grapple one loose piece it shed.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "A calf looking for warmth cracked the stern.")
						return {text = "It cracks a stern plate before it follows your old wake away."},
					botched = func() -> Dictionary:
						return {text = "The cold hull upsets it, and it swings its tail at you.", fight = true}},
				{label = "Drive it off", fight = true, effect = func() -> Dictionary:
					return {text = "Your warning shot does not scare it, and it comes at you.", fight = true}},
				{label = "Let it follow", stay = true, effect = func() -> Dictionary:
					return {text = "It bumps your stern now and then as you fly."}},
			],
		},
		{
			id = &"the_tow_cable",
			title = "The tow cable",
			subject = {layers = [{stage = &"single", pieces = [&"role:barge"], dark = 0.7, at = Vector2(90.0, -40.0)}, {stage = &"single", fights = true, pieces = [&"pool_fan"], at = Vector2(-90.0, 50.0)}]},
			body = "A voidwhale calf is caught in a dead ore barge's tow cable, and the barge's hold reads full of ore.",
			tags = [&"fight", &"salvage"], site = &"derelict",
			group = &"",
			weight = 11,
			min_danger = 1,
			max_danger = 4,
			needs_fauna = true,
			foe = &"whale",
			choices = [
				{label = "Cut the calf free",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						return {text = "The calf holds still for the last cut and leaves a spine in the cable.", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.heat += 5
						return {text = "The cutter runs hot for two hours, and the calf leaves a spine behind.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "A tow cable whipped across the bow.")
						return {text = "The calf pulls at the wrong moment, and the cable whips across your bow."},
					botched = func() -> Dictionary:
						return {text = "The cutter catches the calf, and it turns on you.", fight = true}},
				{label = "Work the barge's hold", fight = true, effect = func() -> Dictionary:
					return {text = "You grapple one load of ore before the barge shifts and the calf comes at you.", material = &"mining", fight = true}},
				{label = "Leave the barge", stay = true, effect = func() -> Dictionary:
					return {text = "You log the barge and the calf still caught in it."}},
			],
		},
		{
			id = &"the_harpoon_line",
			title = "The harpoon line",
			subject = {layers = [{stage = &"single", pieces = [&"ship_scoop"], lights = &"run", at = Vector2(110.0, -55.0)}, {stage = &"single", fights = true, pieces = [&"pool_lev_spine"], at = Vector2(-80.0, 45.0)}]},
			body = "A leviathan is towing a hunting ship by its harpoon, and the crew will pay you to kill it.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 8,
			min_danger = 5,
			max_danger = 8,
			needs_fauna = true,
			foe = &"leviathan",
			choices = [
				{label = "Kill it for them", fight = true, effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(24))
					return {text = "It turns from the line toward your drive's heat.", fight = true}},
				{label = "Cut their line",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						return {text = "The leviathan drifts off, and the angry hunters watch you grapple a broken crystal.", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "The cutter runs hot, but the line parts and the leviathan leaves a crystal behind.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Cut a loaded harpoon line and stayed in its way.")
						return {text = "The free end whips across your hull, and the leviathan is gone."},
					botched = func() -> Dictionary:
						return {text = "The leviathan feels the slow cut and turns toward your drive.", fight = true}},
				{label = "Leave them to it", stay = true, effect = func() -> Dictionary:
					return {text = "The leviathan is still towing the hunters when you go."}},
			],
		},
		{
			id = &"the_grown_plate",
			title = "The grown plate",
			subject = {stage = &"single", pieces = [&"pool_lev_spine"], fights = true},
			body = "A lost ship's plate has grown into a sleeping leviathan, and Harl Station pays for its number.",
			tags = [&"fight", &"contract"], site = &"barren",
			group = &"",
			weight = 8,
			min_danger = 5,
			max_danger = 10,
			needs_fauna = true,
			foe = &"leviathan",
			choices = [
				{label = "Read the number",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(28))
						return {text = "The leviathan sleeps while the dish records the plate, and Harl Station pays."},
					clean = func() -> Dictionary:
						Run.heat += 10
						Run.add_credits(OptionTable.purse(18))
						return {text = "The dish needs a long, warm look, and Harl pays less for a rough record."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Was too close when a sleeping leviathan shifted.")
						return {text = "It shifts in its sleep and scrapes your hull before the dish gets a clean record."},
					botched = func() -> Dictionary:
						return {text = "It wakes with you off its flank and comes at you.", fight = true}},
				{label = "Cut the plate out", fight = true, effect = func() -> Dictionary:
					return {text = "It wakes at the cutter's first touch and rolls toward you.", fight = true}},
				{label = "Leave it sleeping", stay = true, effect = func() -> Dictionary:
					return {text = "Harl pays only for a record, so you log the number and fly on."}},
			],
		},
		{
			id = &"the_warm_reactor",
			title = "The warm reactor",
			subject = {layers = [{stage = &"single", pieces = [&"role:hauler"], dark = 0.8, at = Vector2(40.0, -60.0)}, {stage = &"single", fights = true, flip = true, pieces = [&"pool_lev_spine"], at = Vector2(80.0, 55.0)}]},
			body = "A leviathan feeds on the heat of a dead freighter's reactor, far from the full holds at the bow.",
			tags = [&"fight", &"salvage"], site = &"derelict",
			group = &"",
			weight = 8,
			min_danger = 6,
			max_danger = 10,
			needs_fauna = true,
			foe = &"leviathan",
			choices = [
				{label = "Open the holds cold",
					check = {attr = &"stealth", need = 7},
					met = func() -> Dictionary:
						return {text = "The leviathan never moves while you cut a hold open and grapple a sealed crate.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 12
						return {text = "Running quiet heats the ship, but you get one sealed crate out.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "The leviathan lifts its head with the hold half open, and you back off."},
					botched = func() -> Dictionary:
						return {text = "A hold door gives way with a jolt, and the leviathan comes at you.", fight = true}},
				{label = "Drive it off", fight = true, effect = func() -> Dictionary:
					return {text = "Your shot turns it off the reactor and toward you.", fight = true}},
				{label = "Leave it feeding", stay = true, effect = func() -> Dictionary:
					return {text = "You run the drive cold past the star so it has nothing to follow."}},
			],
		},
	])
	return out
