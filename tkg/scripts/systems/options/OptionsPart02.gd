class_name OptionsPart02

## Encounters 16 to 32 of the authored table (`refinery_still_lit` to `the_manifest`), in the order `OptionTable._authored`
## joins them: `roll_for` draws by table order, so entries never move between or within files.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{
			id = &"refinery_still_lit",
			title = "Refinery, still lit",
			body = "A crewless Cygnet refinery has four years of output in its yard, and its stacks run hot enough to kill.",
			tags = [&"contract"], site = &"barren",
			group = &"refinery",
			weight = 8,
			min_danger = 3,
			max_danger = 8,
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Work the yard",
					check = {attr = &"thermal", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(33))
						return {text = "You make three passes with the vents wide open and never run hot.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.heat += 7
						return {text = "You get two passes before the reactor needs a minute to cool.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						Run.heat += 15
						return {text = "The cabin gets too hot after one pass."},
					botched = func() -> Dictionary:
						Run.heat += 24
						return {text = "A tower cycles while you are alongside, and you leave with nothing."}},
				{label = "Shut it down first", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(14))
					return {text = "Six hours of talking shuts the stack down, but half the yard has cooked.", material = &"mining"}},
				{label = "Leave it running", stay = true, effect = func() -> Dictionary:
					return {text = "You leave it cracking a seam that stopped paying."}},
			],
		},
		{
			id = &"the_sweep",
			subject = {layers = [{stage = &"fx", fx = &"beam", period = 11.0}, {stage = &"single", pieces = [&"ship_rly_dishes"], dark = 0.85, glint = &"beam", at = Vector2(40.0, -20.0)}]},
			title = "The sweep",
			body = "A survey ship caught in a pulsar's sweep still has its rack, and cutting it free means taking the beam's heat.",
			tags = [&"hazard"], site = &"derelict",
			group = &"refinery",
			weight = 6,
			min_danger = 7,
			# A PULSAR, CLOSE. `min_danger 4` meant "deep enough to be
			# plausible"; this means there is one.
			needs_pulsar = true,
			choices = [
				{label = "Time the gaps",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						return {text = "The rack comes free in three gaps, crusted with glass a refinery will buy.", module = true, material_id = &"sweep_glass"},
					clean = func() -> Dictionary:
						Run.heat += 9
						return {text = "You get the rack, but the beam catches you for most of the third gap.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 18
						return {text = "You lose your bearings inside and spend the gap finding the way out."},
					botched = func() -> Dictionary:
						Run.heat += 26
						return {text = "The beam comes around while you are still alongside."}},
				{label = "Log the bearing", stay = true, effect = func() -> Dictionary:
					return {text = "You log the wreck for a ship with better vents."}},
			],
		},
		{
			id = &"tug_work",
			title = "Tug work",
			subject = {layers = [{stage = &"single", pieces = [&"ship_pr_drum"], turn = -7.0, at = Vector2(-118.0, 40.0), lights = &"battery"}, {stage = &"field", pieces = [&"role:hauler", &"role:passenger", &"role:small", &"role:hauler", &"role:barge"], count = 5, near = 0, deep = 3, lift = 12.0, span = 216.0, height = 160.0, seed = 7, tumble = 0.0, at = Vector2(104.0, -36.0), lights = &"run"}]},
			body = "A hauler forty times your mass blocks the dock queue with dead thrusters, and its pilot will pay for a push.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 8,
			needs_berth = true,
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Push it clear",
					check = {attr = &"thrust", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Four minutes of push on one contact point gets the queue moving."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(31))
						return {text = "It takes six minutes and leaves a scrape that will polish out."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "A yard tug clears it and takes most of the fee."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Pushed a hauler that was not braced for it.")
						return {text = "Its hull gives way under your thrust, and your bow goes in with it."}},
				{label = "Sell her fuel", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					Run.add_credits(OptionTable.purse(36))
					return {text = "Her ship clears the queue on your fuel under its own power."}},
				{label = "Wait in the queue", stay = true, effect = func() -> Dictionary:
					return {text = "Eleven hours later, the hauler is still stuck at the head of the queue."}},
			],
		},
		{
			id = &"silt",
			subject = {layers = [{stage = &"fx", fx = &"dust", at = Vector2(30.0, 0.0), radii = Vector2(250.0, 124.0), tilt = 6.0, dens = 0.95}, {stage = &"single", pieces = [&"ship_lattice"], dark = 1.0, silhouette = 0.6, at = Vector2(60.0, -10.0)}, {stage = &"group", ships = [{piece = &"r4_scatter_torn_plate_1", size = 0.5, turn = 12.0, at = Vector2(-172.0, 40.0)}, {piece = &"r4_minedrift_cable_coil_1", size = 0.5, at = Vector2(-196.0, -6.0)}, {piece = &"r2_minedrift_broken_strut_1", size = 0.5, turn = -9.0, at = Vector2(-150.0, 84.0)}]}]},
			title = "Silt",
			body = "A dust shoal hides a ship-sized echo, and flying in blind risks hitting something harder than dust.",
			tags = [&"hazard"],
			group = &"",
			weight = 7,
			min_danger = 3,
			max_danger = 6,
			choices = [
				{label = "Feel your way in",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						return {text = "The echo is an untouched survey cutter, and the grapple takes a rack and fittings.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You clip something soft, and the cutter's rack comes away clean.", module = true},
					partial = func() -> Dictionary:
						return {text = "You get one panel open before you lose your bearings in the dust."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Hit something in a dust shoal bow first.")
						return {text = "Something in the shoal is harder than dust, and you hit it bow first."}},
				{label = "Sweep the edge", effect = func() -> Dictionary:
					return {text = "You take the scrap that has collected in the thin grit at the edge.", material = &"wreck"}},
				{label = "Fly around it", stay = true, effect = func() -> Dictionary:
					return {text = "You keep the shoal on your beam and go around."}},
			],
		},
		{
			id = &"the_queue",
			title = "The queue",
			subject = {layers = [{stage = &"single", pieces = [&"place_station_stack"], at = Vector2(150.0, 0.0), lights = &"run"}, {stage = &"field", flip = true, pieces = [&"role:hauler", &"role:passenger", &"role:barge", &"role:small"], count = 5, near = 0, deep = 3, lift = 12.0, span = 290.0, height = 220.0, seed = 21, tumble = 0.0, at = Vector2(-76.0, 4.0), lights = &"run"}]},
			body = "A pilot whose charter fell through will sell you her fourth place in a nine-ship dock queue.",
			tags = [&"contract"],
			group = &"berth",
			weight = 9,
			min_danger = 3,
			max_danger = 8,
			needs_berth = true,
			min_development = MapGen.Development.CITY,
			choices = [
				{label = "Buy her slot", cost_credits = 45, effect = func() -> Dictionary:
					Run.add_credits(-45)
					return {text = "You dock early and have a part fitted while the queue waits.", module = true}},
				{label = "Trade fuel for it", effect = func() -> Dictionary:
					Run.drain_fuel(4)
					return {text = "She leaves on your fuel, and the dock fits you a part in her slot.", module = true}},
				{label = "Wait your turn", stay = true, effect = func() -> Dictionary:
					return {text = "The queue moves slowly, in order."}},
			],
		},
		{
			id = &"cold_labour",
			title = "Cold labour",
			subject = {stage = &"structure", pieces = [&"st_cold_labour"]},
			body = "A Redline breaker's yard will pay to test an untried cutting head on your flank.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			max_danger = 8,
			min_danger = 3,
			choices = [
				{label = "Give them the flank",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "The head works as the spec said, and your plating takes no damage."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						Run.take_hull_damage(OptionTable.toll(2), "A test cutting head went through one flank.")
						return {text = "It bites deeper than the spec said and scores one flank."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(4), "A test cutting head bit deeper than its spec.")
						return {text = "It bites much deeper than the spec said, and they stop the test early."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A test cutting head cut through a seam.")
						return {text = "The head cuts through a seam before the crew can hit the cutoff."}},
				{label = "Rig them a target", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(17))
					return {text = "The new head cuts your scrap target to pieces in one shift."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "The yard waves in the next ship."}},
			],
		},
		{
			id = &"quarantine_flag",
			title = "Quarantine flag",
			subject = {layers = [{stage = &"single", pieces = [&"place_station_wheel"], dark = 0.8, at = Vector2(70.0, -5.0)}, {stage = &"group", lights = &"run", flip = true, ships = [{piece = &"role:hauler", far = true, at = Vector2(-140.0, 60.0)}, {piece = &"role:passenger", far = true, at = Vector2(-130.0, -70.0)}]}]},
			body = "A dark station full of cheap stock has flown a Calyx quarantine flag for eight days, and no Calyx ship has come.",
			tags = [&"signal"],
			group = &"",
			weight = 7,
			min_danger = 3,
			max_danger = 8,
			min_security = 3,
			choices = [
				{label = "Read the flag",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						return {text = "The flag covers a stock dispute, and the station sells you a part.", module = true},
					clean = func() -> Dictionary:
						return {text = "Nothing confirms or clears the flag, so you dock braced and buy fast.", module = true},
					partial = func() -> Dictionary:
						return {text = "You buy one crate you can inspect through the airlock glass.", material = &"event"},
					botched = func() -> Dictionary:
						Run.add_credits(-50)
						return {text = "You read it the way you hoped and pay for a decontamination cycle."}},
				{label = "Wait it out", stay = true, effect = func() -> Dictionary:
					return {text = "You hold off the exclusion line and wait."}},
			],
		},
		{
			id = &"counterweight",
			title = "Counterweight",
			subject = {stage = &"single", pick = true, pieces = [&"t3_counterweight_1", &"t3_counterweight_2", &"t3_counterweight_4"], at = Vector2(20.0, -20.0)},
			body = "A loose habitation ring heavier than your ship tumbles every ninety seconds, full of fittings a nearby yard will buy.",
			tags = [&"contract"],
			group = &"",
			weight = 7,
			min_danger = 5,
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Match the tumble",
					check = {attr = &"maneuver", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(17))
						return {text = "With the ring held still, the grapple takes a rack and fittings through the lock.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "Hit by a tumbling ring while backing out.")
						return {text = "The grapple reaches one rack before the ring catches your hull.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(7))
						Run.take_hull_damage(OptionTable.toll(2), "Pulled into a tumbling ring.")
						return {text = "The grapple gets one hold before the spin pulls you into the ring."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Matched a ring's spin the wrong way.")
						return {text = "You match the wrong spin, and the ring hits before you can correct."}},
				{label = "Strip the outside", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(8))
					return {text = "The grapple takes one piece off the outside each turn.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You leave the ring turning."}},
			],
		},
		{
			id = &"the_auction",
			title = "The auction",
			subject = {stage = &"structure", pick = true, pieces = [&"st_dock_face_1", &"st_dock_face_2", &"st_dock_face_3", &"st_dock_face_4"], with = [{piece = &"r2_holding_old_container_2", at = "cargo", off = Vector2(-26.0, 0.0)}, {piece = &"ship_mkt_slung", scale = 0.5, flip = true, lights = &"run", at = Vector2(10.0, 100.0)}, {piece = &"ship_courier2", scale = 0.5, flip = true, lights = &"run", at = Vector2(0.0, 150.0)}, {piece = &"ship_hp_wards", scale = 0.5, flip = true, lights = &"run", at = Vector2(40.0, 255.0)}]},
			body = "Probate is auctioning a dead crew's sealed hold, which is usually worth less than the fee but sometimes far more.",
			tags = [&"contract"],
			group = &"berth",
			weight = 7,
			min_danger = 5,
			needs_berth = true,
			choices = [
				{label = "Bid on it", cost_credits = 70, effect = func() -> Dictionary:
					Run.add_credits(-70)
					return {text = "You break the seal and find a part and some loose cargo.", module = true, material = &"event"}},
				{label = "Read the room",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(13))
						return {text = "You sell what you learn about next week's lots."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(7))
						return {text = "You learn something about two of the bidders and sell it."},
					partial = func() -> Dictionary:
						return {text = "The other bidders are better at this than you are."},
					botched = func() -> Dictionary:
						Run.add_credits(-70)
						return {text = "A nod you read as a bid wins you a lot you did not want.", material = &"event"}},
				{label = "Let it go", stay = true, effect = func() -> Dictionary:
					return {text = "Another bidder takes the sealed lot."}},
			],
		},
		{
			id = &"escort",
			title = "Escort",
			subject = {stage = &"field", flip = true, lights = &"run", pieces = [&"role:hauler", &"role:small", &"role:hauler", &"role:hauler"], count = 4, near = 1, deep = 1, lift = 30.0, span = 440.0, height = 240.0, seed = 13, tumble = 0.0},
			body = "Three unarmed haulers and a courier will pay you to fly alongside them with your weapons showing.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 11,
			min_danger = 3,
			max_danger = 8,
			max_security = 2,
			choices = [
				{label = "Take the contract", fight = true, effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(33))
					return {text = "One ring in, a ship comes out of the third moon's shadow and attacks.", fight = true}},
				{label = "Sell them advice", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(28))
					return {text = "You show them the courier can outrun anything alone, and the convoy splits."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "They leave without you."}},
			],
		},
		{
			id = &"nine_tonnes",
			title = "Nine tonnes of nothing",
			subject = {stage = &"single", pieces = [&"r2_container_freight_box_1"]},
			body = "A man pays above rate to ship a crate sized for forty tons but listed at nine, if it stays shut.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 8,
			max_security = 3,
			choices = [
				{label = "Open it",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "It is undeclared reactor fuel, and he pays a higher rate without arguing."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "The cargo is undeclared but safe, so you take the job at a better rate."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(25))
						return {text = "You find nothing worth knowing and shut the casing before he notices."},
					botched = func() -> Dictionary:
						return {text = "He notices and leaves with the crate."}},
				{label = "Take the job", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(25))
					return {text = "You move the crate and ask no questions."}},
				{label = "Pass", stay = true, effect = func() -> Dictionary:
					return {text = "He finds another ship inside the hour."}},
			],
		},
		{
			id = &"ice",
			subject = {stage = &"single", pieces = [&"paint_moon_europa"], lumpy = 3.3, r = 34.0, dirt = 0.45, at = Vector2(110.0, -80.0)},
			title = "Ice",
			body = "An unclaimed comet holds volatiles and a little metal under a hard crust that can crack when you cut it.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			max_danger = 4,
			max_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Cut deep",
					check = {attr = &"hull", need = 4},
					met = func() -> Dictionary:
						Run.fuel += 4
						return {text = "You take the crust off in sheets and get at the clean ice under it.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.fuel += 3
						Run.take_hull_damage(OptionTable.toll(3), "A comet's crust broke the wrong way.")
						return {text = "The crust breaks the wrong way and scrapes down one side of the hull."},
					partial = func() -> Dictionary:
						Run.fuel += 2
						Run.take_hull_damage(OptionTable.toll(5), "A comet's ice face calved onto the bow.")
						return {text = "The face calves while you are cutting it and dents your bow."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A comet's ice face let go onto the bow.")
						return {text = "The ice face lets go all at once and pours into your bow."}},
				{label = "Skim the tail", effect = func() -> Dictionary:
					Run.fuel += 1
					return {text = "You run the tail and take what it is already shedding."}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the comet and fly on."}},
			],
		},
		{
			id = &"flare_shelter",
			site = &"star",
			subject = {layers = [{stage = &"single", pieces = [&"paint_rock_a1"], r = 58.0, at = Vector2(-30.0, -12.0)}, {stage = &"single", pieces = [&"r2_drone_delivery_drone_2"], dark = 0.55, at = Vector2(122.0, 62.0)}]},
			title = "Flare shelter",
			body = "A flare hits in forty minutes, just enough time to reach a sheltering rock and strip the survey drone behind it.",
			tags = [&"hazard"],
			group = &"",
			weight = 11,
			min_danger = 3,
			max_danger = 8,
			# The same star, from the other side: one is a hold worth reaching
			# through a flare, the other is forty minutes to get behind a rock.
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Shelter and strip",
					check = {attr = &"thermal", need = 6},
					met = func() -> Dictionary:
						return {text = "You strip the drone in the shadow and leave with its readings and a rack.", module = true, material_id = &"survey_film"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "The shadow moves before you finish, so you do the rest out in the light.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 17
						return {text = "The flare hits as soon as the cutter gets the drone open."},
					botched = func() -> Dictionary:
						Run.heat += 25
						return {text = "You misread how the rock turns and spend the peak on the lit side."}},
				{label = "Just shelter", effect = func() -> Dictionary:
					return {text = "A piece of drifting cargo shares the shadow, and the grapple takes it.", material = &"event"}},
				{label = "Outrun it", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					return {text = "You leave before the peak on a burn you had not planned."}},
			],
		},
		{
			id = &"deadfall",
			title = "Deadfall",
			subject = {layers = [{stage = &"strewn", far = true, pieces = [&"r6_gantry_snapped_truss_drifting_2_p3", &"r6_gantry_snapped_truss_drifting_2_p1", &"r6_gantry_snapped_truss_drifting_2_p4", &"r6_gantry_snapped_truss_drifting_2_p2"], turn = [12.0, -7.0, 17.0, -11.0], lift = [0.0, 10.0, -8.0, 6.0], gap = 16.0, at = Vector2(70.0, -78.0)}, {stage = &"strewn", pieces = [&"r6_gantry_snapped_truss_drifting_2_p1", &"r6_gantry_snapped_truss_drifting_2_p2", &"r6_gantry_snapped_truss_drifting_2_p3", &"r6_gantry_snapped_truss_drifting_2_p4"], turn = [-4.0, 9.0, -14.0, 20.0], lift = [8.0, -10.0, 16.0, -4.0], gap = 18.0, at = Vector2(0.0, 22.0)}]},
			body = "Nine hundred meters of collapsed yard gantry still drops pieces, and its fitting bay lies under the middle.",
			tags = [&"salvage"], site = &"derelict",
			group = &"",
			weight = 8,
			min_danger = 5,
			choices = [
				{label = "Go under it",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						return {text = "Nothing touches you, and the bay gives up a part and some fittings.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "Clipped by a falling piece of gantry.")
						return {text = "Something lets go behind you as you open the bay.", module = true},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Caught by a shifting gantry span.")
						return {text = "A span shifts across your line, and you back out short of the bay."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A gantry span let go overhead.")
						return {text = "A span that held for a decade lets go while you are under it."}},
				{label = "Pick the edges", effect = func() -> Dictionary:
					return {text = "You take what four crews before you left at the edge.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You keep clear of the gantry."}},
			],
		},
		{
			id = &"the_long_tow",
			title = "The long tow",
			subject = {stage = &"single", pieces = [&"role:hauler"], dark = 0.55, lights = &"battery", at = Vector2(40.0, 0.0)},
			body = "A dead ship's six crew will pay for a four-hour tow, at a load your engine was not built for.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 8,
			needs_berth = true,
			choices = [
				{label = "Take the tow",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "The tow goes clean, and the dock takes the ship."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						Run.take_hull_damage(OptionTable.toll(2), "A long tow tore out a stern mount.")
						return {text = "The tow takes five hours and strains a stern mount."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						return {text = "A yard tug takes the last leg and most of the fee."},
					botched = func() -> Dictionary:
						Run.drain_fuel(3)
						return {text = "The line parts under load, and nobody is hurt."}},
				{label = "Sell a reactor start", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(36))
					return {text = "Your fuel starts its cold reactor, and they fly in on their own."}},
				{label = "Signal it in", stay = true, effect = func() -> Dictionary:
					return {text = "You put their position on the emergency band."}},
			],
		},
		{
			id = &"the_calf",
			title = "The calf",
			subject = {layers = [{stage = &"single", pieces = [&"paint_rock_b4"], r = 80.0, at = Vector2(90.0, -30.0)}, {stage = &"single", pieces = [&"pool_calf_wound"], at = Vector2(-70.0, 40.0)}]},
			body = "A leviathan calf calls for its pod two hours out, and a hunting crew behind you pays a bounty for tagging it.",
			tags = [&"signal"], site = &"contact",
			group = &"herd",
			weight = 8,
			min_danger = 3,
			max_danger = 8,
			needs_fauna = true,
			choices = [
				{label = "Tag it", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "The calf carries your dart to its pod, and an unseen ship pays."}},
				{label = "Herd it home",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						Run.fuel += 3
						return {text = "It follows you in, and the pod's wake carries you along."},
					clean = func() -> Dictionary:
						Run.fuel += 1
						return {text = "It takes you for a threat twice before it follows."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "It bolts the wrong way twice, then hears the pod and goes in alone."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A panicked leviathan calf hit the ship.")
						return {text = "It panics and hits you with its flank at speed, then reaches the pod."}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You leave it calling, with the hunters closer than the pod."}},
			],
		},
		{
			id = &"the_manifest",
			title = "The manifest",
			subject = {stage = &"single", pieces = [&"ship_rf_pipes"], lights = &"run"},
			body = "A barge pilot wants a paid witness for her seal of nine hundred units, but the barge reads heavier.",
			tags = [&"contract"],
			group = &"threshold",
			weight = 9,
			min_danger = 9,
			regions = [MapGen.Region.DEEP],
			choices = [
				{label = "Sign the seal", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(14))
					return {text = "You sign, and the extra mass stays unexplained."}},
				{label = "Scan the load first",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "It reads eleven hundred units, so you sign the true figure."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						return {text = "Fuel and ice explain the difference, so you sign and fly the leg."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(3))
						return {text = "Your figures will not settle, so you refuse to sign."},
					botched = func() -> Dictionary:
						Run.add_credits(-60)
						return {text = "The vault's scale later disputes your number, and the fine lands on you."}},
				{label = "Let her go on", stay = true, effect = func() -> Dictionary:
					return {text = "She flies the last leg without a witness."}},
			],
		},
	])
	return out
