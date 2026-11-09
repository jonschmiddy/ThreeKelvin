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
			body = "A voidwhale calf has followed your ship since the edge of the system. It is pale and long, with thin spines down its back that fan out when it turns. Your drive is the warmest thing it has found out here. Every few minutes it swings around from the bow to push its nose into the plume. Twice it has bumped the stern hard enough to show on the hull sensors. There is no pod on the dish. A calf this young sheds as it grows, and loose hide is drifting in your wake.",
			tags = [&"fight", &"hazard"],
			group = &"",
			weight = 11,
			min_danger = 3,
			max_danger = 6,
			needs_fauna = true,
			foe = &"whale",
			choices = [
				{label = "Go cold and wait it out",
					check = {attr = &"stealth", need = 5},
					met = func() -> Dictionary:
						return {text = "You shut the drive down and let the hull cool. The calf noses along the stern for an hour and finds nothing warm. Then it leaves. The grapple picks a sheet of its hide out of your wake, and a spine it broke on your stern.", material_id = &"hide_scrap", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "It takes three hours of drifting cold before the calf loses interest and leaves. Starting the drive again costs fuel. The grapple finds one piece of loose hide in your wake and brings it in.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "A voidwhale calf looking for warmth cracked the stern open.")
						return {text = "It does not lose interest. In the dark it bumps the stern twice more, and the second time cracks a plate. Then it finds the warm wake you left behind and follows that away instead."},
					botched = func() -> Dictionary:
						return {text = "The calf does not like the cold hull. It circles the ship twice, faster each time, with its spines spread wide. Then it swings its tail at you.", fight = true}},
				{label = "Drive it off with the guns", fight = true, effect = func() -> Dictionary:
					return {text = "You come about and put a shot across its path to scare it off. It does not run. It spreads its spines wide and comes at the ship, tail first.", fight = true}},
				{label = "Let it follow", stay = true, effect = func() -> Dictionary:
					return {text = "You hold your course and let it nose along behind you. It bumps the stern now and then, and the hull sensors log each bump."}},
			],
		},
		{
			id = &"the_tow_cable",
			title = "The tow cable",
			subject = {layers = [{stage = &"single", pieces = [&"role:barge"], dark = 0.7, at = Vector2(90.0, -40.0)}, {stage = &"single", fights = true, pieces = [&"pool_fan"], at = Vector2(-90.0, 50.0)}]},
			body = "A dead ore barge drifts at the edge of the system with its tow cable still trailing from the stern. A voidwhale calf has wound itself into the cable. It is pale, with thin spines along its back. Every time it pulls, the cable cuts in deeper between the spines. The dish picked up its calls for a while. They have stopped. The barge's forward hold reads full of ore. There is no claim filed on the barge, and the dish shows no other ship in the system.",
			tags = [&"fight", &"salvage"],
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
						return {text = "You bring the cutter in along the cable and take it apart one length at a time. The calf holds still for the last cut. Then it moves off slowly toward the dark. One of its spines broke off in the cable, and the grapple takes it.", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.heat += 5
						return {text = "It takes two hours with the cutter running hot. The calf pulls once and then holds still until the last length parts. It leaves a broken spine in the cable, and the grapple takes it.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "A barge's tow cable, pulled tight by a frightened calf.")
						return {text = "The calf pulls at the wrong moment, and the cable whips across your bow. It takes a strip of plating with it. The calf tears loose on its own and is gone. The grapple comes back empty."},
					botched = func() -> Dictionary:
						return {text = "The cutter catches the calf instead of the cable. It tears itself free in one pull. Then it turns on your ship with its tail up and its spines spread.", fight = true}},
				{label = "Work the barge's hold around it", fight = true, effect = func() -> Dictionary:
					return {text = "The grapple gets one load of ore out of the forward hold. Then the barge shifts, and the cable cuts into the calf again. It tears loose and comes straight at your ship.", material = &"mining", fight = true}},
				{label = "Leave the barge", stay = true, effect = func() -> Dictionary:
					return {text = "You log the barge's position and the calf beside it, and fly on. The calf has stopped pulling. It is still caught in the cable."}},
			],
		},
		{
			id = &"the_harpoon_line",
			title = "The harpoon line",
			subject = {layers = [{stage = &"single", pieces = [&"ship_scoop"], lights = &"run", at = Vector2(110.0, -55.0)}, {stage = &"single", fights = true, pieces = [&"pool_lev_spine"], at = Vector2(-80.0, 45.0)}]},
			body = "A hunting ship has a harpoon line in a void leviathan, and the leviathan is towing the ship. It is dark blue and plated like a hull, with a ridge of pale crystal down its back. It is longer than the hunting ship. The crew cannot reel it in, and they will not cut the line. Their pilot is on the open channel. She asks for a ship with guns to finish it while she holds on. She will pay as soon as you agree.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 8,
			min_danger = 5,
			max_danger = 8,
			needs_fauna = true,
			foe = &"leviathan",
			choices = [
				{label = "Finish it for her", fight = true, effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(24))
					return {text = "She pays. You come in on the leviathan's flank while the line holds it still. It turns away from the line, toward the heat of your drive, and comes at you.", fight = true}},
				{label = "Cut her line",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						return {text = "You run the cutter along the line until it parts near the harpoon. The leviathan stops pulling and drifts off slowly toward the dark. A crystal broke off its back where the line went in, and the grapple takes it. The pilot is angry and says so on the open channel for some time.", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "The line takes three passes of the cutter, and the third runs hot. When it parts, the leviathan leaves at once. You take one broken crystal from the drift. The hunters do not hail you again.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Cut a harpoon line under load and stayed in its way.")
						return {text = "The line parts while you are still alongside it. The free end whips across your hull and opens a seam. The leviathan is gone, and so is the hunters' catch. You come away with nothing."},
					botched = func() -> Dictionary:
						return {text = "The cut is slow, and the leviathan feels it through the line. It turns from the hunting ship toward your drive. The line goes slack as it comes for you.", fight = true}},
				{label = "Leave them to it", stay = true, effect = func() -> Dictionary:
					return {text = "You stay off the channel and fly on. The last you read of them, the leviathan is still towing the hunting ship away from the star."}},
			],
		},
		{
			id = &"the_grown_plate",
			title = "The grown plate",
			subject = {stage = &"single", pieces = [&"pool_lev_spine"], fights = true},
			body = "A void leviathan is resting in the shadow of a cold world. It is dark blue and plated like a hull, with pale crystal down its back. One plate on its flank came off a ship. It has grown in at the edges, and a registry number is still painted on it. The registry office at Harl Station lists that number as missing. The clerk there pays for proof of what became of a ship. The leviathan has not moved in a day.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 8,
			min_danger = 5,
			max_danger = 10,
			needs_fauna = true,
			foe = &"leviathan",
			choices = [
				{label = "Read the number from close in",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(28))
						return {text = "You come in slowly until the dish can read the paint, and you record the plate from three sides. The leviathan never wakes. You send the record to the registry office at Harl Station. The clerk checks the number against the list and pays."},
					clean = func() -> Dictionary:
						Run.heat += 10
						Run.add_credits(OptionTable.purse(18))
						return {text = "The dish needs a long look before the paint will read, and the drive runs warm holding you that close. You send the record to Harl Station. The clerk takes it and pays less for one this rough."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Too close to a sleeping leviathan when it shifted.")
						return {text = "It shifts in its sleep while you are close. A crystal on its back scrapes the length of your hull. The record you got is too poor to send, and you back off with a damaged hull."},
					botched = func() -> Dictionary:
						return {text = "It wakes with your ship a few hundred metres off its flank. The crystals along its back light up, and it comes straight at you.", fight = true}},
				{label = "Cut the plate out", fight = true, effect = func() -> Dictionary:
					return {text = "You get the cutter onto the edge of the plate. The leviathan wakes at the first touch and rolls toward your ship. The plate is still in its flank.", fight = true}},
				{label = "Leave it sleeping", stay = true, effect = func() -> Dictionary:
					return {text = "You log the number and the world it sleeps beside. The clerk at Harl Station only pays for a record, so you send nothing and fly on."}},
			],
		},
		{
			id = &"the_warm_reactor",
			title = "The warm reactor",
			subject = {layers = [{stage = &"single", pieces = [&"role:hauler"], dark = 0.8, at = Vector2(40.0, -60.0)}, {stage = &"single", fights = true, flip = true, pieces = [&"pool_lev_spine"], at = Vector2(80.0, 55.0)}]},
			body = "A dead freighter hangs off the star with its reactor still warm. A void leviathan stays close to the stern to feed on the heat. It is dark blue and plated, and the pale crystal on its back glows in the reactor's light. The freighter's forward holds are sealed and read full. They are at the bow, the far end from the leviathan. The transponder is dead. The leviathan moves only to press closer to the reactor.",
			tags = [&"fight", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 6,
			max_danger = 10,
			needs_fauna = true,
			foe = &"leviathan",
			choices = [
				{label = "Open the forward holds cold",
					check = {attr = &"stealth", need = 7},
					met = func() -> Dictionary:
						return {text = "You come in cold on the bow and open the first hold with the cutter on its lowest setting. The leviathan never moves from the reactor. The grapple brings out one sealed crate, and you are gone before it stirs.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 12
						return {text = "You get one hold open, but running quiet that long lets heat build up inside the ship. The grapple brings out a sealed crate. The leviathan shifts once at the stern and settles again.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "You get the hold half open before the leviathan lifts its head. You back off and wait. It settles again, but by then the hull is warm and you have nothing aboard."},
					botched = func() -> Dictionary:
						return {text = "A hold door lets go all at once, and the whole freighter shakes. The leviathan leaves the reactor and comes along the freighter's length toward you.", fight = true}},
				{label = "Drive it off the reactor", fight = true, effect = func() -> Dictionary:
					return {text = "You put a shot into the plates on its back from the stern side. It leaves the reactor and turns. It comes at you along the freighter's length.", fight = true}},
				{label = "Leave it feeding", stay = true, effect = func() -> Dictionary:
					return {text = "You keep well clear of the freighter and fly on. You run the drive cold until you are past the star, so the leviathan has no heat to follow."}},
			],
		},
	])
	return out
