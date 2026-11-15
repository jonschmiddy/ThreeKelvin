class_name OptionsPart06

## Encounters 77 to 90 of the authored table (`the_hunters` to `the_sleepers`), in the order `OptionTable._authored`
## joins them: `roll_for` draws by table order, so entries never move between or within files.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{
			id = &"the_hunters",
			title = "The hunters",
			subject = {stage = &"single", pieces = [&"r3_carcass_whale_fall_2"]},
			body = "A hunting crew will pay you to tow their kill to the tender before its pod comes back.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 5,
			max_danger = 6,
			needs_fauna = true,
			choices = [
				{label = "Tow it in",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You make the tender with forty minutes to spare."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "It takes a full burn and most of the two hours."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.add_credits(OptionTable.purse(8))
						return {text = "The pod shows halfway there, and the hunters cut the body loose."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Towed a kill until the pod came back.")
						return {text = "The pod gets back first, and one drifts into your plating."}},
				{label = "Buy a share", cost_credits = 45, effect = func() -> Dictionary:
					Run.add_credits(-45)
					return {text = "They cut you a piece off the flank.", material = &"fauna"}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You get clear before the pod arrives."}},
			],
		},
		{
			id = &"the_singer",
			title = "The singer",
			subject = {stage = &"single", pieces = [&"pool_lev_throat"]},
			body = "A dying leviathan sings alone here, and hunters two days out will pay for its bearing.",
			tags = [&"signal", &"contract"],
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 8,
			needs_fauna = true,
			choices = [
				{label = "Take its shed hide",
					check = {attr = &"maneuver", need = 7},
					met = func() -> Dictionary:
						return {text = "It lets you take a sheet of shed hide and a smaller piece.", material_id = &"hide_scrap", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "It turns, and an hour later you take what came loose.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Got too close to a turning singer.")
						return {text = "It turns while you are in its way."},
					botched = func() -> Dictionary:
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(4), "Was under a singer when it rolled.")
						return {text = "It rolls, and its weight comes down on your ship."}},
				{label = "Sell the bearing", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(20))
					return {text = "The hunters pay before you finish reading it out."}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You tell no one where it is."}},
			],
		},
		{
			id = &"turning_the_herd",
			title = "Turning the herd",
			subject = {stage = &"herd", flip = true, pieces = [&"r4_turning_the_turning_herd_1", &"r2_turning_the_turning_herd_idea3", &"r4_turning_the_turning_herd_2"], count = 9, near = 3, span = 420.0, height = 190.0, seed = 8},
			body = "A pilot will pay you to help turn a herd of two hundred off the station's approach.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_fauna = true,
			choices = [
				{label = "Take the far flank",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "The whole herd leans away from your lights at once."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "After three loud hours, all but two old ones have turned."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(8))
						return {text = "Only half turn, and the rest clog the approach for a week."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A herd turned into the bow.")
						return {text = "One turns toward the noise and takes plating off your bow."}},
				{label = "Jam their channel", effect = func() -> Dictionary:
					Run.heat += 12
					Run.add_credits(OptionTable.purse(16))
					return {text = "The herd turns slowly away from the noise on its channel."}},
				{label = "Leave her", stay = true, effect = func() -> Dictionary:
					return {text = "The herd is still a day out when you go."}},
			],
		},
		{
			id = &"the_grazing",
			title = "The grazing",
			subject = {layers = [{stage = &"around", base = &"paint_moon_ice", r = 70.0, loose = true, apart = 8, pieces = [&"r3_grazing_feeder_2"], count = 7, size = 0.5, rx = 112.0, ry = 62.0, tilt = 14.0, seed = 7}, {stage = &"field", pieces = [&"r5_grazing_shed_plate_1"], count = 3, near = 0, deep = 1, turns = 70.0, span = 430.0, height = 176.0, seed = 6, tumble = 6.0}]},
			body = "A herd of forty feeds on an ice moon and sheds hide worth money, but it bolts if spooked.",
			tags = [&"hazard", &"salvage"], site = &"contact",
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_fauna = true,
			choices = [
				{label = "Drift in",
					check = {attr = &"stealth", need = 5},
					met = func() -> Dictionary:
						return {text = "None look up while you take a sheet of hide and a plate.", material_id = &"hide_scrap", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "One sees you and goes on feeding while you take a piece.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Caught between three startled ones and the ice.")
						return {text = "A young one startles, then two more."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Was inside a herd when it startled.")
						return {text = "The whole herd startles and crowds against your ship."}},
				{label = "Wait at the edge", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "After a day at the edge, one old piece drifts out.", material = &"fauna"}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You go around the herd."}},
			],
		},
		{
			id = &"the_timekeeper",
			subject = {layers = [{stage = &"fx", fx = &"beam", period = 4.0}, {stage = &"single", pieces = [&"ship_bigdish"], turn = 7.0, dark = 0.6, window = [169, 71], at = Vector2(40.0, -10.0)}]},
			title = "The timekeeper",
			body = "An old man will pay you to grapple his clock relay's antenna back onto the pulsar.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_pulsar = true,
			choices = [
				{label = "Turn the antenna",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "The tick comes back clean after an hour of turning."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						Run.heat += 6
						return {text = "The mount sticks, and the work takes three hours."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(6))
						return {text = "You get it close, and he will turn the last degree himself."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Hit by an antenna that swung off its mount.")
						return {text = "The mount gives way, and the antenna swings into your hull."}},
				{label = "Send the tick", effect = func() -> Dictionary:
					Run.heat += 12
					Run.add_credits(OptionTable.purse(16))
					return {text = "You send his tick for six hours while he fixes the motor."}},
				{label = "Leave him", stay = true, effect = func() -> Dictionary:
					return {text = "You give him the time off your own board."}},
			],
		},
		{
			id = &"thin_glaze",
			subject = {layers = [{stage = &"fx", fx = &"beam", period = 6.0, faint = true}, {stage = &"field", pieces = [&"r4_cache_tether_anchor_1", &"r2_minedrift_broken_strut_1", &"r2_minedrift_cable_coil_1", &"r5_scatter_spar_2", &"r4_minedrift_cable_coil_2", &"r2_minedrift_broken_strut_2", &"r4_minedrift_buckled_plate_2"], count = 7, near = 3, deep = 2, turns = 30.0, span = 420.0, height = 160.0, seed = 13, tumble = 2.0, glint = &"beam", at = Vector2(0.0, -40.0)}]},
			title = "Thin glaze",
			body = "A faint pulsar beam has glazed a field of sharp debris, and sweeping it means taking hits the whole way.",
			tags = [&"salvage"], site = &"belt",
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 4,
			needs_pulsar = true,
			choices = [
				{label = "Sweep the field",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						return {text = "Three hours of scraping gets you a full plate of glaze.", material_id = &"sweep_glass"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Scraped glaze in a field of sharp metal.")
						return {text = "Something in the middle hits hard, but you get the glaze.", material_id = &"sweep_glass"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Was hit while dodging through sharp metal.")
						return {text = "You start dodging halfway in and come out with one bare scrap of satellite.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Hit broadside by a piece nobody saw move.")
						return {text = "A piece the size of a door hits you broadside."}},
				{label = "Grab the nearest piece", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "The nearest piece has little glaze, but its metal is sound.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the field and go."}},
			],
		},
		{
			id = &"the_last_turn",
			subject = {layers = [{stage = &"single", pieces = [&"paint_rock_a1"], r = 50.0, at = Vector2(0.0, -5.0)}, {stage = &"fx", fx = &"marks", on = &"paint_rock_a1", marks = 4, off = Vector2(-4.0, -6.0)}, {stage = &"group", dark = 0.85, ships = [{piece = &"role:hauler", size = 0.25, at = Vector2(-122.0, -62.0)}, {piece = &"role:hauler", size = 0.25, at = Vector2(-146.0, 8.0)}, {piece = &"role:hauler", size = 0.25, at = Vector2(-108.0, 74.0)}, {piece = &"role:hauler", size = 0.25, flip = true, at = Vector2(122.0, -58.0)}, {piece = &"role:hauler", size = 0.25, flip = true, at = Vector2(148.0, 14.0)}, {piece = &"role:hauler", size = 0.25, flip = true, at = Vector2(112.0, 78.0)}]}]},
			title = "The last turn",
			body = "Forty haulers that ran dry short of home drift around a rock painted with fuel numbers, holds still full.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 9,
			min_danger = 9,
			choices = [
				{label = "Read every tank",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 4
						return {text = "One tank in forty is full, and you take one thing from that hauler's hold.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.fuel += 2
						Run.heat += 10
						return {text = "One tank has a little left in the bottom."},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "Every tank reads dry, so you take one thing from a hold.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "A dead hauler's tank exploded on the flank.")
						return {text = "One tank holds old cargo that goes up when the line opens."}},
				{label = "Search the near holds", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You crawl hull to hull and take the best thing from three holds.", material = &"wreck"}},
				{label = "Check fuel and go", stay = true, effect = func() -> Dictionary:
					return {text = "You check your gauge against the numbers on the rock."}},
			],
		},
		{
			id = &"the_fuel_cache",
			title = "The fuel cache",
			subject = {stage = &"field", pieces = [&"r2_fuelcache_marked_fuel_tank_1", &"r2_fuelcache_marked_fuel_tank_2"], count = 6, near = 2, deep = 2, turns = 18.0, lift = 20.0, span = 340.0, height = 180.0, seed = 8, tumble = 3.0},
			body = "Someone left six full fuel tanks on a tether here for the trip home, and the valves have frozen.",
			tags = [&"hazard"],
			group = &"",
			weight = 9,
			min_danger = 9,
			choices = [
				{label = "Take all six",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 5
						return {text = "You warm the valves one at a time."},
					clean = func() -> Dictionary:
						Run.fuel += 3
						Run.heat += 10
						return {text = "Two of the six valves stay frozen."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						Run.take_hull_damage(OptionTable.toll(2), "A frozen fuel valve burst across the flank.")
						return {text = "The first valve opens cold and sprays its tank across your flank."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A frozen valve burst its tank.")
						return {text = "The first tank bursts against your hull."}},
				{label = "Take two", effect = func() -> Dictionary:
					Run.heat += 8
					Run.fuel += 2
					return {text = "You warm two valves slowly and leave four for the owner."}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "The tanks stay on the tether for their owner."}},
			],
		},
		{
			id = &"three_years_in",
			title = "Three years in",
			subject = {stage = &"single", pieces = [&"role:survey"], lights = &"run"},
			body = "A survey crew with a dead receiver has not heard from home in two years and will trade its survey for fuel.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 9,
			choices = [
				{label = "Fix their receiver",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "The mail says their manufacturer shut down a year and a half ago."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						return {text = "It takes half a day to find the dead board."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(6))
						Run.heat += 10
						return {text = "They hear that nobody is answering, but not why."},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(3), "Another ship's power bus arced into the hull.")
						return {text = "Their power bus fails and arcs into your plating."}},
				{label = "Trade fuel for film", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "They send three years of traffic on film and a case of rations.", material_id = &"survey_film", material = &"event"}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You give them your news over the channel."}},
			],
		},
		{
			id = &"still_inbound",
			title = "Still inbound",
			subject = {stage = &"herd", swim = false, pieces = [&"role:hauler"], count = 6, near = 1, span = 420.0, height = 200.0, seed = 5, drive = true, dark = 0.5},
			body = "Six haulers with dead crews crawl toward the core on their own, still holding their places in line.",
			tags = [&"salvage"], site = &"contact",
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Match and cut",
					check = {attr = &"maneuver", need = 8},
					met = func() -> Dictionary:
						return {text = "You cut a sealed unit and a crate from the lead hauler.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You lose the speed twice and get one crate.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "The formation shifts, and you spend the pass dodging."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Crushed when a dead convoy corrected.")
						return {text = "The hauler behind corrects into your gap and crushes your flank."}},
				{label = "Pace them a day", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "A day at their crawl shakes one good piece loose.", material = &"wreck"}},
				{label = "Let them go", stay = true, effect = func() -> Dictionary:
					return {text = "You log their heading and let them go."}},
			],
		},
		{
			id = &"the_pilgrims",
			title = "The pilgrims",
			subject = {stage = &"single", pieces = [&"role:passenger"], lights = &"run", drive = true},
			body = "Nine people on a one-way trip to the core will pay for fuel or for company their first day in.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Fly with them a day",
					check = {attr = &"hull", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Nobody says much on the channel before you turn back."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(2), "Flew inward with nine people not coming back.")
						return {text = "Something uncharted marks your plating on the way in."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(10))
						Run.take_hull_damage(OptionTable.toll(3), "Plating wore through half a day in.")
						return {text = "Your plating wears thin, so you turn back after half a day."},
					botched = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.take_hull_damage(OptionTable.toll(4), "Hit something off the chart with nine strangers.")
						return {text = "Something off the chart tears your flank."}},
				{label = "Sell them fuel", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					Run.add_credits(OptionTable.purse(30))
					return {text = "They take it without arguing the price."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "They are polite about it."}},
			],
		},
		{
			id = &"going_the_other_way",
			title = "Going the other way",
			subject = {stage = &"single", pieces = [&"role:tender"], drive = true, lights = &"run"},
			body = "A ship heading out from the core on one drive will trade gear for fuel if you match its speed.",
			tags = [&"signal", &"contract"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Match and trade",
					check = {attr = &"maneuver", need = 8},
					met = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "A sealed case of gear from past the chart comes back.", module = true},
					clean = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "The fuel goes across, and something smaller comes back.", material = &"event"},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.heat += 14
						return {text = "The line parts before anything comes back."},
					botched = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.take_hull_damage(OptionTable.toll(4), "Touched hulls with a ship that was not stopping.")
						return {text = "You get the match wrong, and the hulls touch at speed."}},
				{label = "Give it fuel", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(14))
					return {text = "Its crew pays for the drop tank anyway."}},
				{label = "Let it go", stay = true, effect = func() -> Dictionary:
					return {text = "It is out of range within the hour."}},
			],
		},
		{
			id = &"frost",
			title = "Frost",
			subject = {stage = &"single", pieces = [&"r5_tank_pressure_tank_1"], tumble = 2.0},
			body = "A cargo ship sits whole in a cloud of frost from its split gas tank, and the frost ices vents in minutes.",
			tags = [&"hazard", &"salvage"], site = &"derelict",
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Work the frost",
					check = {attr = &"thermal", need = 8},
					met = func() -> Dictionary:
						return {text = "With the radiators hot, you pull out a sealed unit and a container.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 14
						return {text = "The vents ice over twice before you get one container out.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 22
						return {text = "The radiators ice over in ten minutes, and you back out."},
					botched = func() -> Dictionary:
						Run.heat += 30
						Run.take_hull_damage(OptionTable.toll(4), "The drive cooked behind iced vents.")
						return {text = "The trapped heat burns out part of the drive."}},
				{label = "Wait for it to thin", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "Once the cloud thins, you take one container from its edge.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You go around the cloud."}},
			],
		},
		{
			id = &"the_sleepers",
			title = "The sleepers",
			subject = {stage = &"single", pieces = [&"role:passenger"], turn = 8.0, dark = 0.5, lights = &"battery"},
			body = "A ship with twelve people in failing cold sleep has a transponder offering a bounty for a tow toward any station.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Tow them to traffic",
					check = {attr = &"thrust", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You leave them on the traffic route with their transponder loud."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 10
						return {text = "The tow takes two days instead of one."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.add_credits(OptionTable.purse(8))
						return {text = "The line parts half a day out."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A towed ship swung into the flank.")
						return {text = "The line snaps tight, and their ship swings into your flank."}},
				{label = "Loot the racks", effect = func() -> Dictionary:
					Run.heat += 8
					return {text = "You cut out a sealed unit and a crate, and your hour inside drains their power faster.", module = true, material = &"wreck"}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You log the position and the bounty."}},
			],
		},
	])
	return out
