class_name OptionsPart09

## Encounters 119 to 132 of the authored table (`quoted_blind` to `the_holding_stack`), in the order `OptionTable._authored`
## joins them: `roll_for` draws by table order, so entries never move between or within files.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{
			id = &"quoted_blind",
			title = "Quoted blind",
			subject = {stage = &"structure", pieces = [&"st_quoted_blind"]},
			body = "A yard crew found a crack longer than their quote and will pay what little is left for your cutter and radiators.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			min_danger = 3, max_danger = 6,
			choices = [
				{label = "Take the long seam",
					check = {attr = &"thermal", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "The seam comes out clean, and the plate is back on before their window closes."},
					clean = func() -> Dictionary:
						Run.heat += 6
						Run.add_credits(OptionTable.purse(14))
						return {text = "Your radiators fill near the end, and the crew finishes the corners."},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "Your panels fill two hours in, so you stow the cutter and leave the crew to it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Cut a freighter's seam with the vents full.")
						Run.heat += 10
						return {text = "The frame moves under the cutter, and the freighter's plating swings across your bow."}},
				{label = "Hold the plate", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You hold the plate flush for a shift, and the foreman pays in a crate of yard stock.", material = &"event"}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "The crew is still hailing for a cutter when you pass."}},
			],
		},
		{
			id = &"the_even_split",
			title = "The even split",
			subject = {stage = &"single", pieces = [&"r3_frame_gutted_frame_2"], tumble = 1.5},
			body = "Another crew takes the easy bow of a dead hauler and leaves you the stern, which spins but holds the racks.",
			tags = [&"salvage"], site = &"derelict",
			group = &"",
			weight = 9,
			min_danger = 3, max_danger = 6,
			choices = [
				{label = "Work the stern",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						return {text = "You hold the roll for four hours and lift out a whole rack and a crate of drive spares.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You lose the roll twice but get one rack off clean.", module = true},
					partial = func() -> Dictionary:
						return {text = "The tumble is too fast for the racks, so you take a locker the cutter shook loose.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Matched a hauler's roll one beat late.")
						return {text = "You come in a beat late, and the stern swings into your plating."}},
				{label = "Take the bow", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You cut a bay of easy plate off the bow while they fight the stern.", material = &"wreck"}},
				{label = "Leave them the hull", stay = true, effect = func() -> Dictionary:
					return {text = "Their bigger cutter is still on the hull when you go."}},
			],
		},
		{
			id = &"receipted_twice",
			subject = {stage = &"single", pieces = [&"ship_forked"], size = 0.5, lights = &"run", at = Vector2(60.0, -40.0)},
			title = "Receipted twice",
			body = "A shipping agent will pay for a mass reading on drive parts that two stations each say they received.",
			tags = [&"contract", &"signal"],
			group = &"",
			weight = 9,
			min_danger = 3, max_danger = 6,
			choices = [
				{label = "Read the shipment",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(28))
						return {text = "It reads as eleven crates, so the second receipt was for a load that was never built."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(12))
						return {text = "Your reading comes out a little high and settles nothing."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(4))
						return {text = "Other loads block your dish, so all she gets is an unsure figure."},
					botched = func() -> Dictionary:
						Run.add_credits(-25)
						return {text = "Your figure is off by a crate, and the delay is billed to your registry."}},
				{label = "Copy her filing", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					Run.add_credits(OptionTable.purse(8))
					return {text = "You spend a shift copying her receipts while she talks about paperwork."}},
				{label = "Stay out of it", stay = true, effect = func() -> Dictionary:
					return {text = "She is still asking on the channel when you leave range."}},
			],
		},
		{
			id = &"walking_the_tank",
			title = "Walking the tank",
			body = "A refinery will pay any ship to push its ore tank to a freighter that leaves in eleven hours.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Push the tank",
					check = {attr = &"thrust", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You push for nine hours, and the foreman adds a bay of ore off the top.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(16))
						return {text = "You fix a drift you put in yourself and arrive with forty minutes left."},
					partial = func() -> Dictionary:
						Run.heat += 12
						Run.add_credits(OptionTable.purse(5))
						return {text = "The tank comes off its anchor too hard and arrives after the window."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Pushed an ore tank off center.")
						return {text = "The push goes in off center, and a corner of the tank yaws into your plating."}},
				{label = "Sell them fuel", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "Their small tug makes the trip in three runs on your fuel, and the foreman pays in ore.", material = &"mining"}},
				{label = "Hold your heading", stay = true, effect = func() -> Dictionary:
					return {text = "The foreman is still asking on the channel two hours later."}},
			],
		},
		{
			id = &"the_cracked_frame",
			title = "The cracked frame",
			subject = {stage = &"structure", pieces = [&"st_the_cracked_frame"]},
			body = "A pilot is selling her cracked hauler's fittings to pay for the weld, or will trade one for help with it.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Hold the frame",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						return {text = "You hold her frame for eleven hours and get her instrument head and a cut section of old frame.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "The weld holds, and she gives you the instrument head.", module = true},
					partial = func() -> Dictionary:
						return {text = "Your frame strains after six hours, so she keeps the head and gives you a cut section instead.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Held a hauler on the grapple until your own frame gave.")
						return {text = "Your own frame gives first, and her hauler drops hard onto the clamps."}},
				{label = "Buy her pump", cost_credits = 35, effect = func() -> Dictionary:
					Run.add_credits(-35)
					return {text = "The pump comes across with its service record taped to the lid.", module = true}},
				{label = "Leave her", stay = true, effect = func() -> Dictionary:
					return {text = "She is still listing fittings on the channel when you leave."}},
			],
		},
		{
			id = &"the_flagged_stack",
			title = "The flagged stack",
			subject = {stage = &"single", pieces = [&"r4_pumprack_pump_on_a_rack_1"]},
			body = "A repair outfit will pay you to sneak its own pump off a station rack where a paperwork hold keeps it.",
			tags = [&"contract", &"salvage"], site = &"world",
			group = &"",
			weight = 8,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Lift it quietly",
					check = {attr = &"stealth", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "The board logs only a ship changing heading, and the outfit gets its pump on time."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(16))
						return {text = "The board logs you as ordinary traffic, and you get the crate across."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "A tender works the rack all shift, and you give up before the window."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Pulled a crate off a rack before the clamp let go.")
						return {text = "The clamp holds late, and you tear the crate free with a length of rack across your plating."}},
				{label = "Watch the dock", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					Run.add_credits(OptionTable.purse(10))
					return {text = "You log when the dock goes quiet, and their own tender takes the pump in the third lull."}},
				{label = "Keep clear", stay = true, effect = func() -> Dictionary:
					return {text = "The crate is still on the rack when you go."}},
			],
		},
		{
			id = &"the_flat_rate",
			title = "The flat rate",
			subject = {stage = &"single", pieces = [&"r4_pod_cargo_pod_2"]},
			body = "A two-person tow crew will pay for help stopping the roll of a mining tender full of wet ore.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Match the roll",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(28))
						return {text = "Three hours of small corrections bring the roll down, and the dock takes the line."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						return {text = "The dock argues about the roll you leave, then takes the line."},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "You put back some of the roll you took out, and the dock refuses the line."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Went alongside a rolling tender of wet ore.")
						return {text = "The ore shifts early, and the tender rolls across your flank."}},
				{label = "Take ore as the fee", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "They pump the wet ore into your bay, and the roll eases as their tank empties.", material = &"mining"}},
				{label = "Let them finish", stay = true, effect = func() -> Dictionary:
					return {text = "The tender is still rolling when your dish loses them."}},
			],
		},
		{
			id = &"the_thrower",
			title = "The thrower",
			subject = {stage = &"structure", pieces = [&"st_the_thrower"], with = [{piece = &"r2_thrower_canister_on_sled_2", scale = 0.5, turn = 20.0, swim = true, tumble = 3.0, at = Vector2(100.0, 150.0)}, {piece = &"r2_thrower_canister_on_sled_2", scale = 0.5, turn = -30.0, swim = true, tumble = 3.0, flip = true, at = Vector2(138.0, 205.0)}, {piece = &"r2_thrower_canister_on_sled_2", scale = 0.5, turn = 50.0, swim = true, tumble = 3.0, at = Vector2(58.0, 232.0)}]},
			body = "An old mass driver on a rock still fires a canister of ore every eleven minutes at a dead station.",
			tags = [&"salvage"], site = &"belt",
			group = &"",
			weight = 9,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Catch a canister",
					check = {attr = &"maneuver", need = 7},
					met = func() -> Dictionary:
						return {text = "An hour out from the muzzle you take a canister of graded ore with its guidance unit still sealed.", module = true, material = &"mining"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "An hour's hot burn puts you in place to take one canister of ore.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "You line up three times and lose every canister."},
					botched = func() -> Dictionary:
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(4), "Caught an ore canister too close to the muzzle.")
						return {text = "Near the muzzle, a canister still under power tears open your flank."}},
				{label = "Work the loading rack", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You hold by the shaking rock and grab one canister before the loader does.", material = &"mining"}},
				{label = "Leave it firing", stay = true, effect = func() -> Dictionary:
					return {text = "The next canister goes out eleven minutes after you leave."}},
			],
		},
		{
			id = &"the_bonded_load",
			title = "The bonded load",
			subject = {stage = &"single", pieces = [&"ship_lightfreighter"], lights = &"battery"},
			body = "A depot keeper will pay you to read the seals on a load nobody came for in nineteen years.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Read the seals",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "The seals read in a minute, and she can close the order."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						return {text = "Four seals of six read, which is just enough to close the order."},
					partial = func() -> Dictionary:
						Run.heat += 10
						Run.add_credits(OptionTable.purse(6))
						return {text = "Only two seals read, which is not enough to close it."},
					botched = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "Your reader writes to the seals, and you idle a day and a half while the depot locks the load."}},
				{label = "Buy the load", cost_credits = 30, effect = func() -> Dictionary:
					Run.add_credits(-30)
					return {text = "You pay the old order's price, and she sends one case of stores across.", material = &"event"}},
				{label = "Let her hold it", stay = true, effect = func() -> Dictionary:
					return {text = "She logs your visit against the order and goes back to waiting."}},
			],
		},
		{
			id = &"the_metered_dock",
			title = "The metered dock",
			subject = {stage = &"single", pieces = [&"r6_oredock_ore_dock_pushed_3"]},
			body = "An empty ore dock still meters its fuel for a dead office, but a slow enough draw never shows.",
			tags = [&"salvage"], site = &"derelict",
			group = &"",
			weight = 8,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Draw under the meter",
					check = {attr = &"stealth", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 4
						return {text = "You hold the line under the meter's rate for most of a day, and its log shows no fuel used."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						return {text = "You lose patience after six hours, and the meter logs your hull number."},
					partial = func() -> Dictionary:
						Run.heat += 12
						Run.fuel += 1
						return {text = "The pumps keep stalling at the low rate, and restarting them warms the ship."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A frozen fuel line burst at a dead dock.")
						return {text = "You push the rate up, and the frozen line bursts across your flank."}},
				{label = "Pay and pump", cost_credits = 34, effect = func() -> Dictionary:
					Run.add_credits(-34)
					Run.fuel += 3
					return {text = "You pay the rate printed when the dock opened, and the pumps run at full."}},
				{label = "Leave the tanks", stay = true, effect = func() -> Dictionary:
					return {text = "The dock keeps its lights on and its meter running."}},
			],
		},
		{
			id = &"the_service_cradle",
			title = "The service cradle",
			subject = {stage = &"structure", pieces = [&"st_the_service_cradle"]},
			body = "An old yard cradle still clamps any ship in reach at a freighter's pressure and fits it with parts from its racks.",
			tags = [&"salvage"], site = &"derelict",
			group = &"",
			weight = 8,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Enter the cradle",
					check = {attr = &"hull", need = 7},
					met = func() -> Dictionary:
						return {text = "The plating holds, and the cradle leaves a sealed unit and your worn part in the grapple.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 12
						return {text = "The arms close hard, and you come out hot with one unit off the racks.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "Nothing on its racks fits your ship, and the arms hold you for two hours anyway."},
					botched = func() -> Dictionary:
						Run.heat += 10
						Run.take_hull_damage(OptionTable.toll(4), "Clamped in a cradle at a freighter's pressure.")
						return {text = "The arms shut at full pressure, and something in the middle of the ship gives."}},
				{label = "Work its racks", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You trim clear of the arms for a day and grapple one piece off the nearest rack.", material = &"wreck"}},
				{label = "Leave it cycling", stay = true, effect = func() -> Dictionary:
					return {text = "The cradle closes on nothing as you go around the yard."}},
			],
		},
		{
			id = &"the_uncollected_order",
			title = "The uncollected order",
			body = "A beacon posts a work order for a sealed load on a tether near here, for a station that is gone.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Read the load's list",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						return {text = "Once you get the cell voltage right, the list shows one case still holding a charge, and you take it.", module = true},
					clean = func() -> Dictionary:
						return {text = "Half the list reads, and you take the one sealed unit still holding.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 10
						return {text = "Nothing answers your reader, so you cut one case open and take its dry stores.", material = &"event"},
					botched = func() -> Dictionary:
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(3), "Cut a sealed case still under pressure.")
						return {text = "The case you cut was still under pressure, and it blows out through your bow."}},
				{label = "Record the beacon", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You hold station a day to record the full order and take a coil of spare line off the tether.", material_id = &"frayed_line"}},
				{label = "Leave the order", stay = true, effect = func() -> Dictionary:
					return {text = "The beacon posts the order again on the hour."}},
			],
		},
		{
			id = &"the_outbound_five",
			title = "The five going out",
			subject = {stage = &"field", pieces = [&"role:barge", &"role:hauler", &"role:small", &"role:hauler", &"role:tender"], count = 5, near = 1, deep = 2, lift = 40.0, span = 440.0, height = 240.0, seed = 5, tumble = 0.0, drive = true},
			body = "Five ships heading out on pooled fuel will pay most of what they have for a push on their slow ore carrier.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Push the carrier",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "Nine hours of pushing gets the carrier up to a speed the others can hold."},
					clean = func() -> Dictionary:
						Run.heat += 12
						Run.add_credits(OptionTable.purse(20))
						return {text = "The carrier comes most of the way up, and they do not argue the shortfall."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.add_credits(OptionTable.purse(8))
						return {text = "The carrier will not hold its line, and you give up in the sixth hour."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Pushed an ore carrier that yawed into the bow.")
						return {text = "The carrier yaws, and your bow goes into its quarter."}},
				{label = "Trade fuel for ore", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You pump fuel into the carrier's tank, and graded ore comes back the other way.", material = &"mining"}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You send them your bearings and go on past."}},
			],
		},
		{
			id = &"the_holding_stack",
			title = "The holding stack",
			subject = {stage = &"on_rock", loose = true, base = &"paint_rock_a1", r = 104.0, pieces = [&"r2_holding_old_container_1", &"r2_holding_old_container_2", &"r2_holding_old_container_1"], count = 3, size = 0.5, spread = Vector2(124.0, 96.0), turns = 12.0, seed = 5, clamp = &"r4_holding_cold_welded_clamp_1", face = Vector2(-34.0, -6.0)},
			body = "Forty containers sit cold-welded to a rock's rails, and cutting one free sends the heat back down your grapple.",
			tags = [&"salvage"], site = &"belt",
			group = &"",
			weight = 8,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Cut a clamp slowly",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						return {text = "You cut in long passes with the radiators wide, and the container comes free with little heat.", material = &"event"},
					clean = func() -> Dictionary:
						Run.heat += 14
						return {text = "The clamp takes two hours of heat down the grapple before the container comes free.", material = &"event"},
					partial = func() -> Dictionary:
						Run.heat += 22
						return {text = "The shaded clamp will not soften, and you stop when the heat has nowhere left to go."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Cut a cold-welded clamp until the drive section gave.")
						return {text = "The clamp gives, and so does something in your drive section."}},
				{label = "Cut one hot", effect = func() -> Dictionary:
					Run.heat += 20
					return {text = "The container is off in forty minutes, and the ship stays hot all day.", material = &"event"}},
				{label = "Leave the rows", stay = true, effect = func() -> Dictionary:
					return {text = "You read the labels on the near row and go."}},
			],
		},
	])
	return out
