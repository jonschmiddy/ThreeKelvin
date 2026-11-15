class_name OptionsPart08

## Encounters 103 to 118 of the authored table (`seized_clamp` to `the_core_drill`), in the order `OptionTable._authored`
## joins them: `roll_for` draws by table order, so entries never move between or within files.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{
			id = &"seized_clamp",
			title = "The clamp",
			subject = {stage = &"structure", pick = true, pieces = [&"st_dock_face_1", &"st_dock_face_2", &"st_dock_face_3", &"st_dock_face_4"], grip = {at = "collar"}},
			body = "A dock clamp with a burned-out motor holds your collar, and the yard crew is four days out.",
			tags = [&"hazard"], site = &"world",
			group = &"",
			weight = 10,
			min_danger = 1,
			max_danger = 2,
			needs_berth = true,
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Pull off the clamp",
					check = {attr = &"thrust", need = 4},
					met = func() -> Dictionary:
						return {text = "The clamp shears at its pin and comes away with you, still shut.", material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "It lets go on the third pull, and nothing bends."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Left part of the collar in a dead clamp.")
						return {text = "You come off, but a piece of plating around the collar stays in the clamp."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A dead clamp tore the collar out of the hull.")
						return {text = "The clamp holds at full thrust, and your collar tears out of the hull."}},
				{label = "Cut the arm off", effect = func() -> Dictionary:
					Run.heat += 8
					return {text = "Four hours on the cutter frees the arm, and you keep it.", material = &"wreck"}},
				{label = "Wait for the yard crew", stay = true, effect = func() -> Dictionary:
					return {text = "On the fourth day the yard crew swaps the motor for nothing."}},
			],
		},
		{
			id = &"the_split_loop",
			subject = {stage = &"single", pieces = [&"ship_orbitarms"], lights = &"run", at = Vector2(20.0, 0.0)},
			title = "The split loop",
			body = "A split in your coolant line is growing two hours out from the station, and a supply tender nearby sells loop sections.",
			tags = [&"hazard"],
			group = &"",
			weight = 11,
			min_danger = 1,
			max_danger = 2,
			min_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Sleeve the split",
					check = {attr = &"thermal", need = 4},
					met = func() -> Dictionary:
						Run.fuel += 1
						return {text = "The sleeve seats on the first try, so you skip the trip back."},
					clean = func() -> Dictionary:
						Run.heat += 5
						return {text = "The sleeve seats on the third try, and you run warm all day."},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "The sleeve will not seat with the pump running, so you run the loop at half pressure."},
					botched = func() -> Dictionary:
						Run.heat += 10
						Run.take_hull_damage(OptionTable.toll(3), "A coolant line burst at the pump.")
						return {text = "The line bursts at the pump and takes the plating behind it."}},
				{label = "Buy a section", cost_credits = 30, effect = func() -> Dictionary:
					Run.add_credits(-30)
					return {text = "She sells you a whole section with the pump end, ready to fit.", module = true}},
				{label = "Turn back and patch it", stay = true, effect = func() -> Dictionary:
					return {text = "You fly back and spend a shift sleeving the line cold."}},
			],
		},
		{
			id = &"the_scatter",
			title = "The scatter",
			subject = {stage = &"field", pieces = [&"r4_scatter_torn_plate_1", &"r4_scatter_cabin_section_1", &"r4_scatter_drive_nozzle_1", &"r5_scatter_spar_2", &"r4_scatter_tank_half_2", &"r4_scatter_torn_plate_2"], count = 6, near = 2, deep = 2, turns = 35.0, band = -14.0, span = 430.0, height = 200.0, seed = 9, tumble = 6.0},
			body = "Plate from a six-day-old collision drifts through the approach, and the traffic office is calling an eleven-minute gap.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 10,
			min_danger = 1,
			max_danger = 2,
			min_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Read it and cross",
					check = {attr = &"sensors", need = 3},
					met = func() -> Dictionary:
						return {text = "You read the spread for a full pass, then cross and grapple a plate on the way.", material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You cross on the office's numbers, and nothing comes near you."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "A piece nobody counted keeps you burning the whole crossing to stay behind it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Hit by a turning plate in a gap that had closed.")
						return {text = "You cross on an old gap, and a turning plate goes into your bow."}},
				{label = "Work the near edge", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "The grapple gets one hull plate from the slow pieces off the lane.", material = &"wreck"}},
				{label = "Wait for the all-clear", stay = true, effect = func() -> Dictionary:
					return {text = "You wait two days with the drives cold while a tug clears the lane."}},
			],
		},
		{
			id = &"the_parted_line",
			title = "The parted line",
			subject = {stage = &"structure", pick = true, pieces = [&"st_dock_face_1", &"st_dock_face_2", &"st_dock_face_3", &"st_dock_face_4"], with = [{piece = &"ship_lightfreighter", scale = 0.5, turn = -62.0, tumble = 1.0, at = "lug0", off = Vector2(-8.0, 69.0)}], lines = [{from = "lug0", to = 0, to_at = [186, 30]}, {from = "lug1", to = 0, to_at = [184, 54]}], parted = {from = "lug2", len = 38.0, lean = -10.0}},
			body = "A shifted load hangs a cargo lighter nose down off the station mast, and the pilot needs the low end held.",
			tags = [&"hazard", &"contract"], site = &"world",
			group = &"",
			weight = 9,
			min_danger = 1,
			max_danger = 2,
			needs_berth = true,
			min_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Hold it on the grapple",
					check = {attr = &"hull", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You hold forty tons for twenty minutes, and she pays you a tug's rate."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "The frame groans twice, but she gets one line on and pays from what she has aboard."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(8))
						return {text = "The load shifts again, and you let go before the lighter takes you with it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A swinging cargo load whipped a grapple line across the flank.")
						return {text = "The load swings to the low end, and the grapple line whips back across your flank."}},
				{label = "Push it up on thrust", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "She gets both lines on and signs over a case from the load.", material = &"event"}},
				{label = "Call the station", stay = true, effect = func() -> Dictionary:
					return {text = "The station says a tug is an hour out and already busy."}},
			],
		},
		{
			id = &"the_cooling_loop",
			title = "The cooling loop",
			subject = {stage = &"single", pieces = [&"role:mining"], lights = &"battery"},
			body = "A mining ship has four hours to find its split coolant line before the reactor cooks, and your dish could find it.",
			tags = [&"hazard", &"contract"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Read their hull",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You find the cold patch, they cut that line, and the heat stops climbing."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(24))
						return {text = "You cannot tell the split from a tank's shadow, so they cut both lines and hold the heat flat."},
					partial = func() -> Dictionary:
						Run.fuel += 2
						return {text = "Your best guess is the right line, and they pump fuel across as pay."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Was beside a mining ship when its reactor went.")
						return {text = "You call the wrong line, the crew gets out in a pod, and a sheet of their hull reaches you."}},
				{label = "Take their cargo", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "They let you take one load of stores, and the loop is still down when you go.", material = &"event"}},
				{label = "Relay their numbers", stay = true, effect = func() -> Dictionary:
					return {text = "You relay their numbers inward, and no reply comes while you are in range."}},
			],
		},
		{
			id = &"the_front",
			subject = {stage = &"fx", fx = &"front"},
			title = "The front",
			body = "Debris from a blast far off your track hits in twenty minutes, and clean space is two days' burn to either side.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Turn the heavy side to it",
					check = {attr = &"hull", need = 4},
					met = func() -> Dictionary:
						return {text = "It passes as four minutes of gravel, and you grapple plate and a racked module from the drift behind it.", material = &"wreck", module = true},
					clean = func() -> Dictionary:
						return {text = "The plating rings for four minutes, then you pick plate out of the drift behind it.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 9
						return {text = "It catches the radiators broadside, still hot from the blast."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A sheet of hull plate hit the flank at blast speed.")
						return {text = "A tumbling sheet of plate the size of a cargo door goes into your flank."}},
				{label = "Hide behind a rock", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You wait in a rock's lee and cut ice off its shaded side.", material = &"mining"}},
				{label = "Run ahead of it", stay = true, effect = func() -> Dictionary:
					return {text = "It is only grit by the time it catches you six hours later."}},
			],
		},
		{
			id = &"the_ice_stream",
			subject = {layers = [{stage = &"fx", fx = &"stream", from = Vector2(-215.0, -112.0), to = Vector2(215.0, -8.0), width = 30.0}, {stage = &"field", pieces = [&"paint_rock_a1", &"paint_rock_b3", &"paint_rock_a2", &"paint_moon_ice", &"paint_rock_b4", &"paint_rock_a1", &"paint_rock_b3", &"paint_moon_europa", &"paint_rock_a2", &"paint_rock_b4"], count = 10, near = 10, r = [4.0, 9.0], band = 14.0, span = 430.0, height = 46.0, seed = 17, tumble = 0.0, at = Vector2(0.0, -60.0)}]},
			title = "The ice stream",
			body = "A stream of ice and rock worth mining crosses your track in six hours, with fast pieces running out in front.",
			tags = [&"hazard"],
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Burn across ahead of it",
					check = {attr = &"thrust", need = 5},
					met = func() -> Dictionary:
						Run.fuel += 2
						return {text = "You cross with an hour to spare and work the leading edge for a day.", material = &"mining"},
					clean = func() -> Dictionary:
						return {text = "You cross late and take a load of ice from the slow edge.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "The fast pieces keep you correcting the whole burn, and the hold stays empty."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A rock crossing the other way hit the bow.")
						return {text = "A bolt-sized piece from the head of the stream hits your bow at twice orbit speed."}},
				{label = "Work the thin edge", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You hold off the flank for a day and a half and take one load from the slow outside pieces.", material = &"mining"}},
				{label = "Wait for it to pass", stay = true, effect = func() -> Dictionary:
					return {text = "You wait a day and a half, then cross the empty sky."}},
			],
		},
		{
			id = &"the_venting_hold",
			title = "The venting hold",
			subject = {stage = &"field", pieces = [&"r2_container_freight_box_1", &"r2_container_freight_box_2"], count = 6, near = 3, span = 360.0, height = 170.0, seed = 5, tumble = 3.0},
			body = "A holed container ship spins on a jet of fuel vapor your radiators could light, with sealed containers on its high side.",
			tags = [&"hazard", &"salvage"], site = &"derelict",
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Match its turn",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						return {text = "You turn with it for two hours and lift a module out of an open rack.", module = true},
					clean = func() -> Dictionary:
						return {text = "Matching the turn eats your time, so you take one sealed container of stores.", material = &"event"},
					partial = func() -> Dictionary:
						Run.heat += 8
						return {text = "You cross the jet twice, and the vapor settles on your radiators without lighting."},
					botched = func() -> Dictionary:
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(4), "Fuel vapor lit off the hot radiators.")
						return {text = "The vapor finds your radiators, and the whole plume goes up with you inside it."}},
				{label = "Cut one container free", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "It takes four passes to cut one sealed container of stores free.", material = &"event"}},
				{label = "Leave it venting", stay = true, effect = func() -> Dictionary:
					return {text = "You log its drift for whoever comes next."}},
			],
		},
		{
			id = &"four_on_one_hull",
			title = "Four on one hull",
			subject = {stage = &"single", pieces = [&"role:family"], lights = &"run", drive = true},
			body = "A family ship down to one drive asks you to carry its extra cargo so it can make its delivery window.",
			tags = [&"contract"],
			group = &"",
			weight = 11,
			max_danger = 4,
			choices = [
				{label = "Carry the extra cargo",
					check = {attr = &"thrust", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(28))
						return {text = "You fly the burn heavy with eleven containers, and they make their window."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(16))
						return {text = "You carry what your frame will hold, and nobody loses the window."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(6))
						return {text = "Only four containers fit alongside, and they pay the standing fee for the hours."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Flew a burn heavier than the drive frame was rated for.")
						return {text = "A port mount bends forty seconds in, and they fly the window in two trips."}},
				{label = "Buy the extra cargo", cost_credits = 22, effect = func() -> Dictionary:
					Run.add_credits(-22)
					return {text = "She takes a poor price for one pallet of stores, since she needs fuel this week.", material = &"event"}},
				{label = "Fly your own burn", stay = true, effect = func() -> Dictionary:
					return {text = "They split the load into two trips and miss their window."}},
			],
		},
		{
			id = &"borrowed_radiators",
			title = "Borrowed radiators",
			subject = {stage = &"single", pieces = [&"role:hauler"], dark = 0.6, lights = &"battery"},
			body = "Two crew with a split heat exchanger will pay to run their reactor loop through your radiators until it cools.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			max_danger = 4,
			choices = [
				{label = "Run their loop",
					check = {attr = &"thermal", need = 5},
					met = func() -> Dictionary:
						Run.heat += 6
						Run.add_credits(OptionTable.purse(26))
						return {text = "Your panels shed their heat fast, and they relight before you uncouple."},
					clean = func() -> Dictionary:
						Run.heat += 10
						Run.add_credits(OptionTable.purse(18))
						return {text = "The transfer runs slower than planned, and you spend five hours warm."},
					partial = func() -> Dictionary:
						Run.heat += 14
						Run.add_credits(OptionTable.purse(6))
						return {text = "You take half their heat before your own panels fall behind."},
					botched = func() -> Dictionary:
						Run.heat += 18
						Run.take_hull_damage(OptionTable.toll(3), "A coupling gave way at full pressure.")
						return {text = "The coupling fails at pressure and takes the plating behind it."}},
				{label = "Give them two hours", effect = func() -> Dictionary:
					Run.heat += 8
					Run.add_credits(OptionTable.purse(14))
					return {text = "Two hours brings their loop down far enough to work on."}},
				{label = "Stay cold", stay = true, effect = func() -> Dictionary:
					return {text = "They go back to the channel to wait for another ship."}},
			],
		},
		{
			id = &"the_spare_module",
			title = "The spare module",
			subject = {stage = &"single", pieces = [&"role:tender"], lights = &"run"},
			body = "Three salvagers on an old tender want quick cash for a power module with its serial ground off.",
			tags = [&"salvage"], site = &"contact",
			group = &"",
			weight = 9,
			max_danger = 4,
			choices = [
				{label = "Test it, then pay",
					check = {attr = &"sensors", need = 3},
					met = func() -> Dictionary:
						Run.add_credits(-16)
						return {text = "It reads sound under load, and you argue the price down.", module = true},
					clean = func() -> Dictionary:
						Run.add_credits(-24)
						return {text = "Nothing reads wrong, so you pay close to their price.", module = true},
					partial = func() -> Dictionary:
						return {text = "The third bus wanders under load, so you say no and they keep it."},
					botched = func() -> Dictionary:
						Run.add_credits(-24)
						Run.take_hull_damage(OptionTable.toll(3), "A power module with no serial failed on its first start.")
						return {text = "It fails on its first start and takes a section of bus and plating with it."}},
				{label = "Pay their price", cost_credits = 28, effect = func() -> Dictionary:
					Run.add_credits(-28)
					return {text = "Nobody asks questions, and it is racked inside the hour.", module = true}},
				{label = "Fly on without it", stay = true, effect = func() -> Dictionary:
					return {text = "They drop the price twice on the channel as you go."}},
			],
		},
		{
			id = &"one_number_between_two",
			title = "One number between two",
			subject = {stage = &"single", pieces = [&"role:hauler"], lights = &"run", drive = true},
			body = "A hauler pilot with a wrong number on her transponder will pay to hide under your flank from patrols for two crossings.",
			tags = [&"contract", &"signal"],
			group = &"",
			weight = 10,
			max_danger = 4,
			choices = [
				{label = "Fly her under your flank",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(28))
						return {text = "She holds in your shadow for eleven hours, and the patrol logs one ship."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(16))
						return {text = "She drifts out twice while nobody is looking, and you arrive late."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(5))
						return {text = "A patrol stops her an hour from the yard anyway."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Two hulls flew closer than their pilots could hold.")
						return {text = "She comes up into your underside eight hours in and scrapes off a run of plating."}},
				{label = "Wait out the patrol", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					Run.add_credits(OptionTable.purse(12))
					return {text = "You hold at the system's edge with her for most of a day until the patrol passes."}},
				{label = "Send her patrol times", stay = true, effect = func() -> Dictionary:
					return {text = "You send her the last three patrol times you saw and fly your own crossing."}},
			],
		},
		{
			id = &"the_automatic_dock",
			title = "The automatic dock",
			subject = {stage = &"structure", pieces = [&"st_the_automatic_dock"]},
			body = "An old docking arm on a rock still opens for twenty minutes every two hours, with a parts locker welded under it.",
			tags = [&"salvage"], site = &"belt",
			group = &"",
			weight = 10,
			max_danger = 4,
			choices = [
				{label = "Fly into the arm",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						return {text = "It takes you square, and you leave with a module and its shipping frame cut up for plate.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "It takes you on the second try, with time for the module but not its frame.", module = true},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "You miss the window twice and break off."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "A dock arm folded on schedule with the ship in it.")
						return {text = "The twenty minutes run out, and the arm folds shut on your flank."}},
				{label = "Cut the locker off", effect = func() -> Dictionary:
					Run.heat += 6
					return {text = "Half an hour of hot cutting gets you a locker of sorted spares.", material = &"event"}},
				{label = "Leave it running", stay = true, effect = func() -> Dictionary:
					return {text = "You watch the arm open once on an empty approach and go."}},
			],
		},
		{
			id = &"the_dust_counter",
			title = "The dust counter",
			subject = {stage = &"single", pieces = [&"r4_dustcounter_dust_counter_2"], tumble = 3.0},
			body = "A mining outfit's dust counter is still logging out here, and its log is about to wrap over forty years of numbers.",
			tags = [&"signal"],
			group = &"",
			weight = 9,
			max_danger = 4,
			choices = [
				{label = "Copy the log",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "The dish copies every entry, and you clip the spares box off the frame.", material = &"event"},
					clean = func() -> Dictionary:
						return {text = "The oldest entries are already written over, so you take the spares box and go.", material = &"event"},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "It wants a key you do not have, and two hours gets you one number."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "A survey frame let go and put a strut through the plating.")
						return {text = "The frame breaks at the weld, and a strut goes through your plating."}},
				{label = "Cut it off its frame", effect = func() -> Dictionary:
					Run.heat += 6
					return {text = "Half an hour of cutting brings the instrument aboard as metal, and its log stops.", material = &"wreck"}},
				{label = "Note it and go", stay = true, effect = func() -> Dictionary:
					return {text = "You log where it is, and it keeps counting."}},
			],
		},
		{
			id = &"the_welded_plate",
			title = "The welded plate",
			subject = {stage = &"on_rock", planet = true, base = &"paint_rock_a1", r = 84.0, pieces = [&"r4_plate_welded_plate_1"], rows = 1, count = 1, face = Vector2(-6.0, 4.0)},
			body = "A spinning rock carries a plate with eleven registry numbers and the stripped ship they flew, its tanks still full.",
			tags = [&"salvage"], site = &"belt",
			group = &"",
			weight = 9,
			max_danger = 4,
			choices = [
				{label = "Work in against the spin",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						return {text = "Two hours in close against the spin gets you a length of good frame steel.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "One pass gets you part of a row of frame.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "An hour of station keeping goes on the nose, and the bolts stay in."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Debris thrown off a spinning rock hit the ship.")
						return {text = "You come in on the wrong side of the spin, into a spray of small rock."}},
				{label = "Pump its tanks", effect = func() -> Dictionary:
					Run.heat += 5
					Run.fuel += 2
					return {text = "The pump runs hot for three hours until their tanks read empty."}},
				{label = "Log the registries", stay = true, effect = func() -> Dictionary:
					return {text = "You log the eleven numbers and the date."}},
			],
		},
		{
			id = &"the_core_drill",
			title = "The core drill",
			subject = {stage = &"single", pieces = [&"r4_drill_drill_rig_1"]},
			body = "A survey rig is still drilling a rock under a claim notice nineteen years old.",
			tags = [&"signal", &"salvage"], site = &"belt",
			group = &"",
			weight = 8,
			max_danger = 4,
			choices = [
				{label = "Cut the drilled face",
					check = {attr = &"thermal", need = 4},
					met = func() -> Dictionary:
						return {text = "The drill found a seam it never finished, and you cut ore from it for two hours.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You take the face slowly and come away with ore and a hot cutter.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.heat += 8
						return {text = "The rock beats the cutter for an hour, and you stop."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A rock face came apart onto the hull.")
						return {text = "The face splits along the drill line, and a slab slides into your hull."}},
				{label = "Take the power rack", effect = func() -> Dictionary:
					Run.take_hull_damage(OptionTable.toll(2), "A survey mast came down on the plating.")
					return {text = "You take the rack, and the top of the mast hits you on the way out.", module = true}},
				{label = "Let the claim stand", stay = true, effect = func() -> Dictionary:
					return {text = "You log the claim and leave the rig drilling."}},
			],
		},
	])
	return out
