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
			body = "A dropped cargo pod pings from somewhere in the gas, but its bearing wanders and the gas hides rocks.",
			tags = [&"salvage"], site = &"belt",
			group = &"",
			weight = 9,
			min_danger = 1,
			max_danger = 2,
			needs_nebula = true,
			choices = [
				{label = "Follow the ping in",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						return {text = "The pod is where the last ping said, sealed with its cargo inside.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "You crawl in with the lights on and find the pod beside a rock.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "You find the tether and a loose case, but never the pod.", material = &"event"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Followed a pod's ping into a rock in the gas.")
						return {text = "You come around a bank of gas at speed and into a rock."}},
				{label = "Fly a search pattern", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "The search finds one case, and someone else got the pod first.", material = &"event"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the pod and go."}},
			],
		},
		{
			id = &"the_cache",
			title = "The cache",
			subject = {layers = [{stage = &"single", pieces = [&"paint_rock_b3"], r = 60.0, at = Vector2(-145.0, 22.0)}, {stage = &"field", pieces = [&"r2_cache_sealed_canister_1", &"r2_cache_sealed_canister_2"], count = 8, near = 2, deep = 3, turns = 20.0, lift = 20.0, span = 230.0, height = 160.0, seed = 11, tumble = 3.0, at = Vector2(45.0, -6.0)}]},
			body = "Eight sealed containers hang on a tether hidden in the gas, and whoever hid them means to come back.",
			tags = [&"salvage"], site = &"belt",
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 4,
			needs_nebula = true,
			choices = [
				{label = "Take all eight",
					check = {attr = &"stealth", need = 5},
					met = func() -> Dictionary:
						return {text = "No one comes, and two of the eight hold a ship's part and whatever they were hiding.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "Another ship's lights show, and you leave with six, one of them worth having.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "The other ship's lights show, and you run with the one container you freed.", material = &"event"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A trapped container in a hidden cache went off.")
						return {text = "The second container from the end is a charge, and it goes off when the grapple pulls."}},
				{label = "Cut one loose", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You cut the nearest container and leave the other seven for their owner.", material = &"wreck"}},
				{label = "Leave it hidden", stay = true, effect = func() -> Dictionary:
					return {text = "You back out the way you came with the lights off."}},
			],
		},
		{
			id = &"no_stars",
			subject = {stage = &"fx", fx = &"gas", k = 1.0},
			title = "No stars",
			body = "The gas has closed in with nothing to steer by, and a charted rock a hundred meters across is somewhere close.",
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
						return {text = "Two stars show through the gas, and on the way out you take a piece off a hidden hull.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "After an hour and two false starts, two stars give you a heading out."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You guess the second star wrong and burn the wrong way for two hours."},
					botched = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.take_hull_damage(OptionTable.toll(4), "Burned on a bad fix into a charted rock.")
						return {text = "You trust a bad fix and burn into the rock the chart marked."}},
				{label = "Climb above the gas", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "Coming back down, you find a supply case left on a marker for lost ships.", material = &"event"}},
				{label = "Wait for it to thin", stay = true, effect = func() -> Dictionary:
					return {text = "After two days, a thin patch of gas drifts past with stars in it."}},
			],
		},
		{
			id = &"the_dark_ship",
			title = "The dark ship",
			subject = {stage = &"single", pieces = [&"r5_split_derelict_1"], tumble = 1.0},
			body = "A ship sits dark and frosted in the gas, either dead with a full hold or alive and hiding.",
			tags = [&"hazard", &"salvage"], site = &"derelict",
			group = &"",
			weight = 8,
			min_danger = 5,
			max_danger = 6,
			needs_nebula = true,
			choices = [
				{label = "Go alongside and look",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						return {text = "It has been dead for years, and you take a sealed unit and a crate.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "It is dead, but the moving gas slows the cutter to one good piece.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "It is alive, and it lights its drive and runs deeper into the gas."},
					botched = func() -> Dictionary:
						Run.heat += 8
						Run.take_hull_damage(OptionTable.toll(5), "Went alongside a dark ship that was not dead.")
						return {text = "It is alive, and something hits your flank as it leaves."}},
				{label = "Watch it for a day", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "After a quiet day, you take one loose piece without going alongside.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You go on and say nothing about it on the channel."}},
			],
		},
		{
			id = &"the_scoop",
			site = &"giant",
			subject = {stage = &"none"},
			title = "The scoop",
			body = "The giant's upper air is fuel, and a dive takes more than a skim but can drag the ship down.",
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
						return {text = "You take it in one long, shallow pass with the nose glowing."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						Run.heat += 8
						return {text = "You go in a little steep and come out hot."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(2), "Skipped hard off a gas giant's air.")
						return {text = "You skip off the top of the air twice, and the second skip is hard."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Dove into a gas giant's air too steeply.")
						return {text = "The air grabs you with fire in the intakes, and you barely climb out."}},
				{label = "Skim high and slow", effect = func() -> Dictionary:
					Run.heat += 8
					Run.fuel += 1
					return {text = "An hour at the thin top of the air warms the whole ship."}},
				{label = "Leave the air alone", stay = true, effect = func() -> Dictionary:
					return {text = "You keep your altitude and go around."}},
			],
		},
		{
			id = &"the_breaking_moon",
			site = &"giant",
			subject = {layers = [{stage = &"single", pieces = [&"paint_moon_ice"], world = &"shattered", r = 30.0, at = Vector2(70.0, -70.0)}, {stage = &"single", pieces = [&"paint_rock_a1"], r = 7.0, at = Vector2(18.0, -34.0)}, {stage = &"single", pieces = [&"paint_rock_a2"], r = 5.0, at = Vector2(-8.0, -20.0)}, {stage = &"single", pieces = [&"paint_rock_b3"], r = 6.0, at = Vector2(-36.0, -6.0)}]},
			title = "The breaking moon",
			body = "The giant is tearing its inner moon apart, baring metal no one has mined between drifting sheets of crust.",
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
						return {text = "You cut a piece of the core between the sheets and come out untouched.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "Clipped by a piece of a breaking moon.")
						return {text = "You get a piece of the core, but a chunk of moon clips your flank.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Dodged sheets of crust inside a breaking moon.")
						return {text = "A sheet turns over fast, and you spend the pass dodging instead of cutting."},
					botched = func() -> Dictionary:
						Run.heat += 10
						Run.take_hull_damage(OptionTable.toll(4), "Caught between two sheets of a breaking moon.")
						return {text = "Two sheets close with you between them, and you burn out with the hull grinding."}},
				{label = "Take what drifts clear", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "After a day at a safe distance, you grapple the best piece that drifts clear.", material = &"mining"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the moon and fly on."}},
			],
		},
		{
			id = &"the_rings",
			site = &"giant",
			near = {ring = true},
			subject = {stage = &"ring_arc", pieces = [&"place_derelict", &"ship_cl_drums", &"r3_frame_gutted_frame_2", &"ship_lattice"], u = [-0.6, -0.86, 0.78, 0.6], lift = [-2.0, 1.0, -1.0, -16.0], size = 0.25, dark = 0.8},
			title = "The rings",
			body = "Eleven hulls circle in the giant's rings, and reaching one means flying the ring plane with ice on every side.",
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
						return {text = "You match ring speed and take a sealed unit and a crate off a whole freighter.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "A piece of ring ice hit the ship at ring speed.")
						return {text = "Ice you never see knocks you twice, but you get one good piece off the freighter.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 10
						return {text = "You cannot hold the plane, so you climb out hot and empty."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Came into the ring plane at the wrong speed.")
						return {text = "A few meters a second off ring speed is enough, and the ice hits you hard."}},
				{label = "Grapple from above", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "The grapple brings up mostly ice and once a piece off a hidden hull.", material = &"wreck"}},
				{label = "Leave the rings alone", stay = true, effect = func() -> Dictionary:
					return {text = "You log the eleven hulls and go on."}},
			],
		},
		{
			id = &"the_sunken_freighter",
			title = "The sunken freighter",
			subject = {stage = &"single", pieces = [&"r5_split_derelict_1"]},
			body = "A freighter has floated deep in the giant's air for eleven years, at a depth that cooks your ship in ten minutes.",
			tags = [&"salvage"], site = &"giant",
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_giant = true,
			choices = [
				{label = "Go down to it",
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						return {text = "In eight minutes alongside, you take a sealed unit and a crate from its hold.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Stayed twelve minutes at a depth that allowed ten.")
						return {text = "You stay twelve minutes, two too many, and the grapple brings up one thing.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Went to crushing depth and came up with nothing.")
						return {text = "The plating starts to give before the cutter finishes, so you climb out with nothing."},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(5), "Came up too slowly from a freighter at crushing depth.")
						return {text = "The air catches you as it caught the freighter, and you barely climb out."}},
				{label = "Drop the grapple", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "After a day fishing in an open hold, you get what was nearest the door.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You leave it circling at depth."}},
			],
		},
		{
			id = &"the_storm",
			site = &"giant",
			near = {storm = {sv = Vector2(-0.42, -0.52), z = 0.55, w = 0.17}},
			subject = {stage = &"single", pieces = [&"ship_bored"], size = 0.25, far_k = 0.1, dark = 0.85, lights = &"battery", anchor = &"near", on = Vector2(-0.42, -0.52)},
			title = "The storm",
			body = "A storm on the giant carries a dead mining ship whose three crew will pay for a line before their hull fails.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_giant = true,
			choices = [
				{label = "Grapple them out",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "The grapple takes them on the second pass, and you climb out together."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(2), "Made four passes into a gas giant's storm for strangers.")
						return {text = "It takes four passes, and the storm scores your plating before you pull them out."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.add_credits(OptionTable.purse(10))
						Run.take_hull_damage(OptionTable.toll(3), "Put two lines into a gas giant's storm.")
						return {text = "The second line drags them high enough to finish the climb on their own thrusters."},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(5), "Went into a gas giant's storm after three strangers.")
						return {text = "The storm carries you around the planet before you burn out with an empty line."}},
				{label = "Wait for them to rise", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(16))
					return {text = "After a day above the storm, it lifts them into range for a line."}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "The storm takes them out of range while they are still calling."}},
			],
		},
		{
			id = &"dead_boards",
			subject = {layers = [{stage = &"fx", fx = &"beam", period = 14.0, faint = true}, {stage = &"single", pieces = [&"ship_cl_tree"], dark = 0.9, drive = true, flip = true, at = Vector2(30.0, 0.0)}]},
			title = "Dead boards",
			body = "A pulsar's beam killed a hauler's controls, and its crew will pay for a tow before its stuck drive takes them deeper.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_pulsar = true,
			choices = [
				{label = "Tow them clear",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "Their boards come back once you pull them out of the beam."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "The line parts twice in two hours of pulling, but they get clear."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(8))
						return {text = "The line parts for good, but they are drifting out of the beam now."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Towed a hauler whose stuck drive pulled the other way.")
						return {text = "Their stuck drive pulls against the line, and your hull comes off worse."}},
				{label = "Shield them with your hull", effect = func() -> Dictionary:
					Run.heat += 14
					Run.add_credits(OptionTable.purse(18))
					return {text = "Your hull takes the beam for two hours while they work around the dead boards."}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "They have a day before the beam is strong enough to matter."}},
			],
		},
		{
			id = &"the_glass_ring",
			title = "The glass ring",
			subject = {stage = &"structure", pick = true, pieces = [&"st_the_glass_ring_1", &"st_the_glass_ring_2"]},
			body = "A pulsar beam has glazed an old station ring, and it leaves you six minutes in every ninety to cut.",
			tags = [&"salvage"], site = &"derelict",
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 8,
			needs_pulsar = true,
			choices = [
				{label = "Work the gap",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						return {text = "The cutter runs the whole gap and brings back a plate of glaze and a piece of the ring.", material_id = &"sweep_glass", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 12
						return {text = "A seventh minute in the beam still gets you the glaze and a piece of the ring.", material_id = &"sweep_glass", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 18
						return {text = "The gap closes while you find the angle, and you leave with a piece of frame.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 28
						Run.take_hull_damage(OptionTable.toll(4), "Took a full sweep of the beam beside the glass ring.")
						return {text = "You misjudge the gap and take four seconds of the beam at close range."}},
				{label = "Work the shadow side", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You take a plain piece of frame that fell into the ring's shadow long ago.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the ring and the gap."}},
			],
		},
		{
			id = &"the_drop_point",
			title = "The drop point",
			subject = {stage = &"single", pieces = [&"r4_pod_cargo_pod_1"], tumble = 2.0},
			body = "Every thirty-one minutes a slow pulsar beam kills any ship in the open, and cached cargo sits in a rock's shadow.",
			tags = [&"salvage", &"hazard"],
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_pulsar = true,
			choices = [
				{label = "Run for the shadow",
					check = {attr = &"thrust", need = 8},
					met = func() -> Dictionary:
						return {text = "You reach the shadow with time to spare and take a sealed unit and a crate.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 12
						return {text = "The beam's edge catches your stern on the way back, but you keep one crate.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 22
						Run.take_hull_damage(OptionTable.toll(2), "Caught by a pulsar beam while turning back.")
						return {text = "You turn back halfway, and the beam catches you in the turn."},
					botched = func() -> Dictionary:
						Run.heat += 30
						Run.take_hull_damage(OptionTable.toll(4), "Caught in the open by a slow pulsar.")
						return {text = "The beam finds you in the open at minute thirty-one."}},
				{label = "Grapple from the edge", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "After three sweeps on a long cable, you get what sat nearest the edge.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the rock and the interval."}},
			],
		},
		{
			id = &"the_quiet_beam",
			subject = {layers = [{stage = &"group", glint = &"glaze", dark = 0.55, ships = [{piece = &"r3_frame_gutted_frame_2", size = 0.5, turn = -6.0, at = Vector2(-130.0, -92.0)}, {piece = &"place_derelict", size = 0.5, turn = 4.0, at = Vector2(20.0, -60.0)}, {piece = &"r5_split_derelict_1", size = 0.5, turn = -3.0, at = Vector2(120.0, -6.0)}]}, {stage = &"group", ships = [{piece = &"ship_courier2", size = 0.25, drive = true, lights = &"run", at = Vector2(150.0, -108.0)}, {piece = &"ship_catamaran", size = 0.25, drive = true, lights = &"run", at = Vector2(190.0, -86.0)}]}]},
			title = "The quiet beam",
			body = "This pulsar's beam stopped two days ago and could start any time, and ships are already racing in for the glazed hulls.",
			tags = [&"hazard", &"salvage"], site = &"derelict",
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_pulsar = true,
			choices = [
				{label = "Work until the last minute",
					check = {attr = &"sensors", need = 8},
					met = func() -> Dictionary:
						return {text = "You leave with glaze and a sealed unit minutes before the beam returns.", material_id = &"sweep_glass", module = true},
					clean = func() -> Dictionary:
						Run.heat += 14
						return {text = "The first sweep catches your stern as you leave with glaze and a piece of hull.", material_id = &"sweep_glass", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 20
						return {text = "You cannot read the spin on the dish, so you take one piece and leave early.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 32
						Run.take_hull_damage(OptionTable.toll(4), "Worked a glazed hull until the beam came back.")
						return {text = "The beam comes back without warning and hits you twice before you get out."}},
				{label = "Grab the nearest piece", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You grapple one piece off the nearest hull and burn clear of the beam's track.", material = &"wreck"}},
				{label = "Stay clear", stay = true, effect = func() -> Dictionary:
					return {text = "You watch the other ships go in."}},
			],
		},
		{
			id = &"the_crossing",
			title = "The crossing",
			subject = {stage = &"herd", flip = true, pieces = [&"r3_crossing_old_one_1", &"r4_crossing_young_one_1", &"r3_crossing_old_one_2", &"r4_crossing_young_one_1"], count = 8, near = 2, span = 420.0, height = 200.0, seed = 4},
			body = "A slow herd of hundreds of leviathans blocks your path, and going through takes an hour if none of them turns.",
			tags = [&"hazard"], site = &"contact",
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_fauna = true,
			choices = [
				{label = "Thread the herd",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						return {text = "None of them turns, and an old one on the edge sheds a sheet of hide.", material_id = &"hide_scrap"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "A curious young one follows you, and something it shed drifts against your hull.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Scraped by a leviathan's flank.")
						return {text = "One of them turns and scrapes its flank across your bow."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Caught between two leviathans as they closed.")
						return {text = "Two of them close on you, and you back out and go around anyway."}},
				{label = "Follow the edge", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "A day at the old ones' pace gets you the one good piece that drops.", material = &"fauna"}},
				{label = "Wait for them to pass", stay = true, effect = func() -> Dictionary:
					return {text = "They take most of a day to pass."}},
			],
		},
	])
	return out
