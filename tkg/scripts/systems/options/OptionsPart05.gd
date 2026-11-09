class_name OptionsPart05

## Encounters 63 to 76 of the authored table (`the_dropped_pod` to `the_crossing`), in the order `OptionTable._authored`
## joins them: `roll_for` draws by table order, so entries never move between or within files.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{
			id = &"the_dropped_pod",
			title = "The dropped pod",
			subject = {stage = &"single", pieces = [&"r2_pod_cargo_pod_1"], tumble = 3.0},
			body = "A transponder in the cloud says it is a cargo pod. Haulers drop these when they have to lose weight fast, and they mean to come back. No one has come back for this one. The gas scatters the signal, so the bearing wanders five degrees one way, then ten the other. You will not see the pod until you are close enough to grapple it. The gas here is thick enough to hide rocks too.",
			tags = [&"salvage"],
			group = &"",
			weight = 9,
			min_danger = 1,
			max_danger = 2,
			needs_nebula = true,
			choices = [
				{label = "Follow the ping in",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						return {text = "You follow the ping, correcting each time the bearing jumps and slowing where the gas thickens. The pod is where the last ping said, sealed and cold, with its cargo still inside.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "It takes longer than the ping suggests, crawling most of the way with the lights on. The pod is there, and so is a rock that would have hit you at speed.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "The bearing walks you in a circle twice before you catch on. You find the pod's tether. You find a case that came off it. You never find the pod.", material = &"event"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "You followed a cargo pod's ping into the gas and hit a rock.")
						return {text = "You come around a bank of gas at speed and there is a rock in it. The pod is somewhere on the far side, still pinging. You do not stay to find out where."}},
				{label = "Fly a slow search pattern", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You give up on the bearing and fly a search box slowly, with the lights on, one leg at a time. It costs fuel. You find the pod's tether, one case, and enough of the pod to know someone else got here first.", material = &"event"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the pod and go."}},
			],
		},
		{
			id = &"the_cache",
			title = "The cache",
			subject = {layers = [{stage = &"single", pieces = [&"paint_rock_b3"], r = 60.0, at = Vector2(-145.0, 22.0)}, {stage = &"field", pieces = [&"r2_cache_sealed_canister_1", &"r2_cache_sealed_canister_2"], count = 8, near = 2, deep = 3, turns = 20.0, lift = 20.0, span = 230.0, height = 160.0, seed = 11, tumble = 3.0, at = Vector2(45.0, -6.0)}]},
			body = "Half a kilometre off the lane, deep in the cloud, eight sealed containers hang on a tether between two rocks. You only see them because your lights are on. They are all alike, marked with the same code and nothing else. In the open, any dish would find them within an hour, but no one searches in here. Someone hid them on purpose and plans to come back.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 4,
			needs_nebula = true,
			choices = [
				{label = "Take the string",
					check = {attr = &"stealth", need = 5},
					met = func() -> Dictionary:
						return {text = "You cut the tether at both ends and take the whole string aboard in an hour, and no one comes. Six hold supplies worth nothing to you. One holds a ship's part, still packed. The last holds what they were hiding, with no name on it.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You get six of the eight aboard. Then another ship's lights show in the gas, a long way off and closing. You leave the last two and go. It does not follow. Of the six, one is worth having.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "You have one container off the tether when the other ship's lights show. You go fast, with the one you have. It is not the good one.", material = &"event"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "One container in the cache was a trap, set to stop the other seven being taken.")
						return {text = "The second container from the end is a charge. It goes off when the grapple takes the tension off the tether. You spend the next hour checking what plating you have left."}},
				{label = "Cut one loose and go", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You cut the container nearest the lane and take it quickly. Matching the tether's drift in the gas costs fuel, and getting back out costs more. The other seven stay where they were put.", material = &"wreck"}},
				{label = "Leave it hidden", stay = true, effect = func() -> Dictionary:
					return {text = "You switch the lights off and back out the way you came, leaving the containers on their tether."}},
			],
		},
		{
			id = &"no_stars",
			subject = {stage = &"fx", fx = &"gas", k = 1.0},
			title = "No stars",
			body = "The gas has closed in, and there is nothing to steer by: no stars, no beacon and no fix. The dish reads the same cloud in every direction. The gyro heading was true when you entered, but it has drifted for an hour or two in an unknown direction. The gas is moving at a different speed from you, and you cannot measure the difference. Somewhere in this cloud is a rock the chart says is a hundred metres across.",
			tags = [&"hazard"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_nebula = true,
			choices = [
				{label = "Rebuild the fix",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						return {text = "You stop, kill the drive, and let the dish listen. Over half an hour the gas thins in one direction and shows you two stars, enough for a fix. On the new heading you pass a hull the cloud has hidden for years and take what is loose off it.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "It takes an hour of listening and two false starts before you see two stars and get a heading. You burn out on it, and it is right. The gas thins to show the lane."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You get one star and guess the second. The heading is out by ten degrees. You find that out slowly, over two hours of burning the wrong way. You come out of the gas a long way from where you meant to."},
					botched = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.take_hull_damage(OptionTable.toll(4), "Burned on a bad fix, in gas. The chart had the rock marked.")
						return {text = "You get a fix, trust it, and burn. The rock is where the chart said, but your fix was wrong about where you were."}},
				{label = "Burn straight up out of the plane", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You burn straight up, at right angles to the lane. You keep burning until the gas thins and the stars come back. Leaving the lane costs fuel. Coming back down to it costs more. On the way down you find a marker at the edge of the gas. Somebody left a supply case on it for whoever got lost next.", material = &"event"}},
				{label = "Wait for the gas to thin", stay = true, effect = func() -> Dictionary:
					return {text = "You kill the drive and wait for the cloud to move. After two days a thin patch passes with stars in it, and you go. It costs nothing but the two days."}},
			],
		},
		{
			id = &"the_dark_ship",
			title = "The dark ship",
			subject = {stage = &"single", pieces = [&"r5_split_derelict_1"], tumble = 1.0},
			body = "Three kilometres off the lane, a ship is sitting dark. The gas is thick enough to hide it from any dish not pointed straight at it. It has no transponder, no drive and no heat, and it has gathered frost. It is either dead and unfound, or alive and hiding, and from here you cannot tell which. A dead ship like this is worth a great deal to whoever reaches it first.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 5,
			max_danger = 6,
			needs_nebula = true,
			choices = [
				{label = "Go alongside and look",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						return {text = "It has been dead for years, with frost inside as well as out. The hold was full when it stopped, and no one has found it. You take the best of it and log the rest.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "It is dead, and cold. The cutter takes twice as long as it should. The gas will not sit still, so the fuel goes on holding station. What you get is worth it.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "It is alive. It lights its drive when you are two hundred metres off and goes deeper into the cloud, fast. Getting clear of its wake costs fuel."},
					botched = func() -> Dictionary:
						Run.heat += 8
						Run.take_hull_damage(OptionTable.toll(5), "Went alongside a dark ship in the gas, and it was not dead.")
						return {text = "It is alive. Something hits your flank as it leaves, perhaps as a warning, and then it is gone into the gas. Your hull needs repairs."}},
				{label = "Watch it for a day", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You hold off in the gas with everything down and watch it for a day. Nothing changes. No heat, no drift, no light. Then you go closer, slowly. You take what is loose around it and never go alongside. Holding still in moving gas costs a day of fuel.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You go on along the lane and say nothing about it on the channel."}},
			],
		},
		{
			id = &"the_scoop",
			site = &"giant",
			subject = {stage = &"none"},
			title = "The scoop",
			body = "The banded giant fills the sky ahead, and its upper air is fuel. Every ship that passes here dips into it. Get low enough and the intakes fill themselves. Get too low and the air drags you in, hot enough to strip the plating on the way down. A shallow skim gets you free fuel. A dive gets you more, or destroys the ship.",
			tags = [&"hazard"],
			group = &"",
			weight = 10,
			min_danger = 1,
			max_danger = 2,
			needs_giant = true,
			choices = [
				{label = "Dip into the air",
					check = {attr = &"thrust", need = 4},
					met = func() -> Dictionary:
						Run.fuel += 3
						return {text = "You take it in one long, shallow pass with the nose glowing. You come out climbing, with three more units in the tank."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						Run.heat += 8
						return {text = "You go in a little steep and come out a little hot. The tank takes two units. The hull takes an hour to cool, and you spend the hour climbing."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(2), "Skipped off the top of a gas giant's air, twice. The second one was hard.")
						return {text = "You skip off the top of the air twice by accident, and the second skip is hard. You get one unit of fuel, a hot ship and a dent."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "You dove into the giant's air too steeply.")
						return {text = "You go in too steep, and the air grabs you for ninety seconds with fire in the intakes. You climb out on the last of the burn with no more fuel than before and much less plating."}},
				{label = "Skim high and slow", effect = func() -> Dictionary:
					Run.heat += 8
					Run.fuel += 1
					return {text = "You keep to the very top of the air. It is thin there, and the intakes take a long time to fill. An hour of skimming buys one unit. The ship is warm all the way through by the end of it."}},
				{label = "Leave the air alone", stay = true, effect = func() -> Dictionary:
					return {text = "You keep your altitude and go around."}},
			],
		},
		{
			id = &"the_breaking_moon",
			site = &"giant",
			subject = {layers = [{stage = &"single", pieces = [&"paint_moon_ice"], world = &"shattered", r = 30.0, at = Vector2(70.0, -70.0)}, {stage = &"single", pieces = [&"paint_rock_a1"], r = 7.0, at = Vector2(18.0, -34.0)}, {stage = &"single", pieces = [&"paint_rock_a2"], r = 5.0, at = Vector2(-8.0, -20.0)}, {stage = &"single", pieces = [&"paint_rock_b3"], r = 6.0, at = Vector2(-36.0, -6.0)}]},
			title = "The breaking moon",
			body = "The giant's innermost moon orbits too close, and it is coming apart. The planet pulls harder on its near side than its far side, and the difference is tearing it. Cracks a kilometre wide cross the surface. Sheets of crust lift off the near side and drift, exposing the moon's interior. It is dark metal that has never been mined, and it is worth a fortune.",
			tags = [&"salvage"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_giant = true,
			choices = [
				{label = "Fly in among the pieces",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						return {text = "You go in slowly between the lifted sheets with the cutter running. You come out the other side with a full hold, untouched. Behind you, a piece of crust the size of a station turns over where you were.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "Clipped by a piece of a breaking moon.")
						return {text = "You fill the hold, but a piece of the moon hits your flank on the way out. The flank needs repairs.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "You spent a pass inside a breaking moon dodging sheets of crust.")
						return {text = "A sheet turns over faster than it should. You spend the pass avoiding it instead of cutting. You come out with a scraped hull and an empty hold."},
					botched = func() -> Dictionary:
						Run.heat += 10
						Run.take_hull_damage(OptionTable.toll(4), "Caught between two pieces of a breaking moon.")
						return {text = "Two sheets close with the ship between them. You burn out with the hull grinding on both sides. You do not stop burning until the moon is a long way behind."}},
				{label = "Take what drifts clear", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You sit a safe distance out and wait. Every few hours a piece of the interior drifts clear of the sheets, and you take the best one with the grapple. Holding station for the day costs fuel, but it is safe.", material = &"mining"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the moon and fly on. It has been breaking up for a thousand years and will go on for a thousand more."}},
			],
		},
		{
			id = &"the_rings",
			site = &"giant",
			near = {ring = true},
			subject = {stage = &"ring_arc", pieces = [&"place_derelict", &"ship_cl_drums", &"r3_frame_gutted_frame_2", &"ship_lattice"], u = [-0.6, -0.86, 0.78, 0.6], lift = [-2.0, 1.0, -1.0, -16.0], size = 0.25, dark = 0.8},
			title = "The rings",
			body = "The giant's rings are mostly ice and rock, a few metres thick and a hundred thousand kilometres across. They have been catching things for longer than anyone has been here. Anything that enters orbit at the wrong angle ends up in the ring plane and goes around with the rest. The dish counts eleven hulls in the near arc alone. To reach one, you fly in the plane at ring speed, with ice on every side.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 4,
			needs_giant = true,
			choices = [
				{label = "Fly the plane",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						return {text = "You match the ring's speed, so the ice hangs still around you, and pick your way through it. The nearest hull is a whole freighter that has circled with the ice for a long time.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "A piece of ring ice, at ring speed.")
						return {text = "You get to the freighter with one knock on the way in. You take one more on the way out. Both come from ice you never saw. The hold is worth both.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 10
						return {text = "You get into the plane and cannot hold it. The ice keeps finding you, and you climb out hot and empty before it finds you properly."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Came into the ring plane at the wrong speed.")
						return {text = "You come into the plane only a few metres a second off ring speed, and that is enough. A lot of ice hits you. By the time you are out of the plane, many systems have failed at once."}},
				{label = "Hold above the plane and fish", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You hold just above the ring, matching its speed. You drop the grapple into it on a long line and pull up what it catches. Mostly ice. Once, something better, off a hull you never see. Holding above a ring for a day costs fuel.", material = &"wreck"}},
				{label = "Leave the rings alone", stay = true, effect = func() -> Dictionary:
					return {text = "You log the eleven hulls and go on."}},
			],
		},
		{
			id = &"the_sunken_freighter",
			title = "The sunken freighter",
			subject = {stage = &"single", pieces = [&"r5_split_derelict_1"]},
			body = "A freighter went into the giant's air eleven years ago and did not come out. It was a gas-mining hull built for pressure, so it was not crushed. It floats at the depth where the air holds it up and circles the planet with the wind. Its transponder still works, and its cargo is still aboard. At that depth the air would crush your ship in about twenty minutes and cook it in ten.",
			tags = [&"salvage"],
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_giant = true,
			choices = [
				{label = "Go down to it",
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						return {text = "You go down through the bands with the pressure climbing. The freighter is where the transponder said, its running lights still on. In eight minutes alongside, the cutter opens a hold and the grapple takes the best of it. You climb out with the hull creaking.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Twelve minutes at a depth that gives you ten.")
						return {text = "You stay twelve minutes at depth, two too many. Every panel of plating is dented, and the grapple brings up the one thing it could reach.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Went down to crushing depth, and came up with nothing.")
						return {text = "You get down to it. The plating starts to give before the cutter has finished. You have to climb. You bring up nothing but a hull that has been squeezed."},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(5), "Went down to a freighter at crushing depth, and came up too slowly.")
						return {text = "You go down, and the air catches you the way it caught the freighter. You climb out on the last of the burn, with the whole outer hull pushed in."}},
				{label = "Fish for it from above", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You hold at the top of the air and drop the grapple on its longest line. One of the freighter's holds is open. It takes a day to hook anything, and holding station in the wind costs fuel. You get what was nearest the door.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You leave it circling at depth, sinking a little lower each year."}},
			],
		},
		{
			id = &"the_storm",
			site = &"giant",
			near = {storm = {sv = Vector2(-0.42, -0.52), z = 0.55, w = 0.17}},
			subject = {stage = &"single", pieces = [&"ship_bored"], size = 0.25, far_k = 0.1, dark = 0.85, lights = &"battery", anchor = &"near", on = Vector2(-0.42, -0.52)},
			title = "The storm",
			body = "A storm the size of a small continent is carrying a mining ship around the giant. Its drives are dead, and the wind moves at six hundred kilometres an hour. Three crew are aboard. They call on the open channel each time the storm lifts them into range, then go quiet for an hour. They have circled for two days and think their pressure hull will last one more. They will pay anything for a line.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_giant = true,
			choices = [
				{label = "Match the wind and grapple them",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "You go into the top of the storm with their beacon on the dish and match the wind. That means six hundred kilometres an hour through air that pulls you down. The grapple takes them on the second pass, and you climb out together. They pay everything they promised."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(2), "Four passes into a storm on a gas giant, for three strangers.")
						return {text = "It takes four passes, and the storm grabs you on the third. You come out with their ship on the line and your plating scored from nose to tail. They pay in full."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.add_credits(OptionTable.purse(10))
						Run.take_hull_damage(OptionTable.toll(3), "Two lines into a storm on a gas giant. The storm kept most of the second.")
						return {text = "You get a line on them, lose it, and get it again. The second line holds and drags them up to where their thrusters can hold altitude. They finish the climb themselves and pay less than they promised."},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(5), "Went into a storm on a gas giant after three strangers. It kept both ships.")
						return {text = "You go in after them, and the storm carries you around the planet for an hour. Then a gap opens, and you burn up through it with nothing on the line. They are still down there, calling."}},
				{label = "Wait for the storm to bring them up", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(16))
					return {text = "You hold above the storm for a day, burning fuel against the wind, and wait for it to lift them into range. It does, twice. The second time you get a line on them without going in. They pay less than they promised, and since you never went in, you do not argue."}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You tell them you cannot, and they say they understand. The storm takes them down again, and by the time they call again, you are out of range."}},
			],
		},
		{
			id = &"dead_boards",
			subject = {layers = [{stage = &"fx", fx = &"beam", period = 14.0, faint = true}, {stage = &"single", pieces = [&"ship_cl_tree"], dark = 0.9, drive = true, flip = true, at = Vector2(30.0, 0.0)}]},
			title = "Dead boards",
			body = "A pulsar two systems over sweeps its beam through here every fourteen seconds. At this distance it cannot hurt a hull, but it can kill an unshielded circuit board, and most are unshielded. A hauler in the lane ahead has lost its controls this way. Its drive is stuck on its last setting. It is pushing the ship toward the one part of the system where the beam is strong enough to matter. Its two crew are calling for a tow.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_pulsar = true,
			choices = [
				{label = "Tow them out of the beam",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You get a line on them and pull them across the beam's track. It takes an hour and every bit of thrust you have. Once they are clear, their boards come back one at a time. They pay in full. They ask what you are shielded with."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "The tow takes two hours and the line parts twice. They are out of the beam by the end of it. Their boards are coming back. You are hot from the pulling. They pay what they offered."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(8))
						return {text = "You get them moving the right way. Then the line parts for good. They are drifting out of the beam now instead of into it. They will be clear in a day. They pay you for the direction."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "You towed a hauler whose stuck drive pulled against you.")
						return {text = "The line comes tight while their drive is still pushing on the old setting. The two ships pull against each other, and your hull comes off worse. They are no better off, and they do not pay."}},
				{label = "Sit between them and the beam", effect = func() -> Dictionary:
					Run.heat += 14
					Run.add_credits(OptionTable.purse(18))
					return {text = "You put your ship in the beam's path with theirs behind it. For two hours your hull takes the beam every fourteen seconds while they work around the dead boards. The ship heats up the whole way through. They pay less than they would for a tow."}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You wish them luck. They have a day before the beam is strong enough to matter. Another ship may come, or they may fix the boards."}},
			],
		},
		{
			id = &"the_glass_ring",
			title = "The glass ring",
			subject = {stage = &"structure", pick = true, pieces = [&"st_the_glass_ring_1", &"st_the_glass_ring_2"]},
			body = "An old station ring hangs in the lane, dead for longer than anyone has records. The pulsar's beam has swept it every four seconds the whole time. Over centuries it has left a glaze on the hull, as thick as the plating under it and in unusual colours. The glaze is worth a great deal to the right buyer. Every ninety minutes the beam's angle misses the ring for six minutes. You have six minutes to work.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 8,
			needs_pulsar = true,
			choices = [
				{label = "Work the gap",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						return {text = "You go in on the first second of the gap and out on the last, with the cutter running the whole time. You bring back a warm plate of the glaze and a piece of the ring that came away under it.", material_id = &"sweep_glass", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 12
						return {text = "You need seven minutes, and the seventh is in the beam. You get out before it does more than heat you, with the glaze and a piece of the ring aboard.", material_id = &"sweep_glass", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 18
						return {text = "You are still finding the angle when the gap closes. You leave with a piece of the ring's frame and a second of the beam on your hull.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 28
						Run.take_hull_damage(OptionTable.toll(4), "Took a full sweep of the beam alongside the glass ring.")
						return {text = "You misjudge the gap by a full sweep and take four seconds of the beam at this range. No ship is built for that. You leave with nothing but heat."}},
				{label = "Take frame from the shadow side", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You never go near the glaze. The ring throws its own shadow. In it are pieces of the frame that fell clear of the beam's line a long time ago. Holding in a shadow that moves with the ring costs fuel. What you take is plain metal, and it is safe.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the ring and the gap and leave the glaze for a faster ship."}},
			],
		},
		{
			id = &"the_drop_point",
			title = "The drop point",
			subject = {stage = &"single", pieces = [&"r4_pod_cargo_pod_1"], tumble = 2.0},
			body = "This pulsar is slow, and its beam comes around once every thirty-one minutes. At this range one sweep is enough to destroy a ship, so everything here runs on that clock. Behind a rock the size of a city is the one shadow the beam never reaches. For a very long time, people have left crates, tanks and sealed cargo there for others, stacked and tethered. The beam is the only guard. You have thirty-one minutes to cross the open sky, load up, and get back.",
			tags = [&"salvage", &"hazard"],
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_pulsar = true,
			choices = [
				{label = "Run for the shadow",
					check = {attr = &"thrust", need = 8},
					met = func() -> Dictionary:
						return {text = "You go the second the beam has passed. You are in the shadow with twenty minutes to spare. The stack is deeper than it looked from outside. You take a sealed unit off the top and a crate from under it. You are back across the open with four minutes left. The beam comes around behind you.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 12
						return {text = "You are slow across the open and slower coming back, and the edge of the beam catches your stern. You get one crate and a hot ship.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 22
						Run.take_hull_damage(OptionTable.toll(2), "Turned back halfway to the shadow, and the beam caught the turn.")
						return {text = "Halfway across, you see there is not time to reach the shadow and get back. The beam catches you as you turn around. You come out with nothing and a damaged hull."},
					botched = func() -> Dictionary:
						Run.heat += 30
						Run.take_hull_damage(OptionTable.toll(4), "Caught in the open by a slow pulsar. It came around on minute thirty-one.")
						return {text = "You misjudge the clock, and the beam finds you in the open at minute thirty-one. When it has passed, you are drifting at the shadow's edge in a badly damaged ship."}},
				{label = "Hook what you can from the edge", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You hold at the edge of the shadow with the beam's line a hundred metres off your bow. You put the grapple in on a long cable and wait through three sweeps. You get what was nearest the edge.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the rock and the interval and go."}},
			],
		},
		{
			id = &"the_quiet_beam",
			subject = {layers = [{stage = &"group", glint = &"glaze", dark = 0.55, ships = [{piece = &"r3_frame_gutted_frame_2", size = 0.5, turn = -6.0, at = Vector2(-130.0, -92.0)}, {piece = &"place_derelict", size = 0.5, turn = 4.0, at = Vector2(20.0, -60.0)}, {piece = &"r5_split_derelict_1", size = 0.5, turn = -3.0, at = Vector2(120.0, -6.0)}]}, {stage = &"group", ships = [{piece = &"ship_courier2", size = 0.25, drive = true, lights = &"run", at = Vector2(150.0, -108.0)}, {piece = &"ship_catamaran", size = 0.25, drive = true, lights = &"run", at = Vector2(190.0, -86.0)}]}]},
			title = "The quiet beam",
			body = "For as long as anyone has counted, this pulsar's beam swept the system every second and a half. Two days ago it stopped, and no one knows why. Other pulsars have done this. Each time, the beam started again without warning, after an hour or a month. Until it does, you can reach the hulls that sat in its path for centuries, thick with glaze. Every ship within a week is coming for them, and the first are already here.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_pulsar = true,
			choices = [
				{label = "Work until the last minute",
					check = {attr = &"sensors", need = 8},
					met = func() -> Dictionary:
						return {text = "You keep the dish on the pulsar the whole time you work. Six hours in, it shows the spin coming back into line. You leave with a plate of the glaze and a sealed unit off the nearest hull. You are eleven minutes clear when the beam returns.", material_id = &"sweep_glass", module = true},
					clean = func() -> Dictionary:
						Run.heat += 14
						return {text = "You read the pulsar right but cut it fine, and the first sweep catches your stern as you clear the lane. You get a plate of glaze and a piece of hull. The ship spends the day cooling.", material_id = &"sweep_glass", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 20
						return {text = "You cannot read the pulsar's spin on the dish, so you take one piece off the nearest hull and leave early. The beam comes back four hours later.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 32
						Run.take_hull_damage(OptionTable.toll(4), "Working a glassed hull when the beam came back.")
						return {text = "The beam comes back without warning while you are still working. It hits you twice before you get out of the lane and scorches the whole outer hull."}},
				{label = "Take what is nearest and go", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You take the first thing the grapple can reach off the nearest hull. Then you burn out of the lane and keep going until the beam's track is far behind you.", material = &"wreck"}},
				{label = "Stay out of the lane", stay = true, effect = func() -> Dictionary:
					return {text = "You stay well out of the lane with the dish on the pulsar and watch the other ships go in."}},
			],
		},
		{
			id = &"the_crossing",
			title = "The crossing",
			subject = {stage = &"herd", flip = true, pieces = [&"r3_crossing_old_one_1", &"r4_crossing_young_one_1", &"r3_crossing_old_one_2", &"r4_crossing_young_one_1"], count = 8, near = 2, span = 420.0, height = 200.0, seed = 4},
			body = "A herd of hundreds of megafauna is crossing the lane, slow and packed close. The young are in the middle and the old are on the outside. They barely move, and they cover the stretch of sky you need. They are not hostile, but they will not move for you or notice you. The smallest is the size of a hauler. Going around costs a day. Going through costs an hour, if none of them turns.",
			tags = [&"hazard"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_fauna = true,
			choices = [
				{label = "Thread the herd",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						return {text = "You go through at their speed, the only speed that works, and none of them turns. Halfway across, an old one on the outside sheds a sheet of hide the size of your ship. You take it.", material_id = &"hide_scrap"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "It takes two hours and a lot of correcting. One of the young ones follows you part of the way. It is curious. Something that came off one of them drifts against the hull as you clear the far side. You keep it.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Brushed by the flank of something the size of a hauler.")
						return {text = "One of them turns, and its flank comes across your bow and scrapes the paint off. You get through with nothing but the scrape."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Between two of them when they closed.")
						return {text = "Two of them close in, slowly, with you between. You back out of the gap. The hull grinds on both sides. You go around after all, and it costs the day as well."}},
				{label = "Follow the old ones around the edge", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "The old ones keep to the outside, and the old ones shed. You follow the edge of the herd for a day at their pace. You take the one good piece that drops. Flying that slow for a day costs fuel. The herd does not mind you there.", material = &"fauna"}},
				{label = "Wait for them to pass", stay = true, effect = func() -> Dictionary:
					return {text = "You hold off the lane while they pass. It takes most of a day and costs nothing else."}},
			],
		},
	])
	return out
