class_name OptionsPart02

## Encounters 16 to 32 of the authored table (`refinery_still_lit` to `the_manifest`), in the order `OptionTable._authored`
## joins them: `roll_for` draws by table order, so entries never move between or within files.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{
			id = &"refinery_still_lit",
			title = "Refinery, still lit",
			body = "A Cygnet refinery hangs over a dead seam with its stacks still glowing. It runs without a crew, cracking ore and stacking the output in a yard. The last shift left four years ago, and no one has come to empty the yard. The stacks run at working temperature, hot enough to kill a crew that gets close. The yard is still full.",
			tags = [&"contract"],
			group = &"refinery",
			weight = 8,
			min_danger = 3,
			max_danger = 8,
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Go in for the yard",
					check = {attr = &"thermal", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(33))
						return {text = "You work the yard in three passes with the vents wide open and never run hot. You take what fits of four years of output.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.heat += 7
						return {text = "You get two passes. You leave with a full hold and a reactor that needs a minute to cool.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						Run.heat += 15
						return {text = "You get one pass and take what little the grapple reaches before the cabin gets too hot."},
					botched = func() -> Dictionary:
						Run.heat += 24
						return {text = "A tower cycles while you are still alongside it. You leave with nothing at all and a reactor running hot."}},
				{label = "Shut it down first", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(14))
					return {text = "It takes six hours to talk the control stack into shutting down. The yard is cool by the time you reach it, but half of what you wanted has cooked in place.", material = &"mining"}},
				{label = "Leave it running", stay = true, effect = func() -> Dictionary:
					return {text = "You leave the refinery running, still cracking a seam that stopped paying and stacking a yard no one empties."}},
			],
		},
		{
			id = &"the_sweep",
			subject = {layers = [{stage = &"fx", fx = &"beam", period = 11.0}, {stage = &"single", pieces = [&"ship_rly_dishes"], dark = 0.85, glint = &"beam", at = Vector2(40.0, -20.0)}]},
			title = "The sweep",
			body = "A close, old pulsar sweeps its beam across this arc every eleven seconds, exactly. A survey ship sits inside the sweep, caught when it got the timing wrong. Its instrument rack is still mounted on the dorsal spine. Each gap is long enough to get in or to get out. Cutting the rack free takes longer than one gap, so some of the work happens with the beam on your hull. The beam puts in heat faster than the radiators shed it. It also leaves a glass crust that a refinery will buy.",
			tags = [&"hazard"],
			group = &"refinery",
			weight = 6,
			min_danger = 7,
			# A PULSAR, CLOSE. `min_danger 4` meant "deep enough to be
			# plausible"; this means there is one.
			needs_pulsar = true,
			choices = [
				{label = "Time the interval",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						return {text = "You make three passes in three gaps and are clear before the fourth. Up close, it was not the beam that killed the survey crew. Your hull comes away crusted with glass, and a refinery will pay for it.", module = true, material_id = &"sweep_glass"},
					clean = func() -> Dictionary:
						Run.heat += 9
						return {text = "You take the rack in two gaps, and the beam catches you for most of the third.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 18
						return {text = "You get inside, lose your bearings, and spend the gap finding the way back out."},
					botched = func() -> Dictionary:
						Run.heat += 26
						return {text = "You are still alongside when the beam comes around. The hull holds, and what is bolted to the outside of it cooks."}},
				{label = "Log the bearing", stay = true, effect = func() -> Dictionary:
					return {text = "You log the wreck and the interval and leave them for a ship with better vents."}},
			],
		},
		{
			id = &"tug_work",
			title = "Tug work",
			subject = {layers = [{stage = &"single", pieces = [&"ship_pr_drum"], turn = -7.0, at = Vector2(-118.0, 40.0), lights = &"battery"}, {stage = &"field", pieces = [&"role:hauler", &"role:passenger", &"role:small", &"role:hauler", &"role:barge"], count = 5, near = 0, deep = 3, lift = 12.0, span = 216.0, height = 160.0, seed = 7, tumble = 0.0, at = Vector2(104.0, -36.0), lights = &"run"}]},
			body = "A bulk hauler hangs crooked at the head of the dock queue with dead thrusters. Nine ships are waiting behind it. The dock's own tugs are booked for the next eleven hours. Each hour the dockmaster grows keener to know whose fault it is. The pilot needs four minutes of push from a ship willing to put its nose on a hull forty times its mass.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 8,
			needs_berth = true,
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Put your nose on it",
					check = {attr = &"thrust", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "It takes four minutes on one contact point, with no scoring on either hull. The queue moves, and the dockmaster logs your ship."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(31))
						return {text = "It takes six minutes and leaves a scrape on your flank that will polish out. The queue moves."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "You get it turned, but you do not get it clear. A yard tug comes out in the end and gets paid the difference."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "You put twelve tonnes of thrust into a hull that was not braced for it. It gives way, and your bow goes in with it.")
						return {text = "You put twelve tonnes of thrust into a hull that was not braced for it. It gives way, and your bow goes in with it."}},
				{label = "Sell her the fuel instead", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					Run.add_credits(OptionTable.purse(36))
					return {text = "Her ship cannot steer, but it can still burn fuel. You pump her ship enough to get clear under its own power, at a rate she cannot argue with."}},
				{label = "Wait in the queue", stay = true, effect = func() -> Dictionary:
					return {text = "Eleven hours in the queue. The hauler is still crooked at the head of it when your turn comes."}},
			],
		},
		{
			id = &"silt",
			subject = {layers = [{stage = &"fx", fx = &"dust", at = Vector2(30.0, 0.0), radii = Vector2(250.0, 124.0), tilt = 6.0, dens = 0.95}, {stage = &"single", pieces = [&"ship_lattice"], dark = 1.0, silhouette = 0.6, at = Vector2(60.0, -10.0)}, {stage = &"group", ships = [{piece = &"r4_scatter_torn_plate_1", size = 0.5, turn = 12.0, at = Vector2(-172.0, 40.0)}, {piece = &"r4_minedrift_cable_coil_1", size = 0.5, at = Vector2(-196.0, -6.0)}, {piece = &"r2_minedrift_broken_strut_1", size = 0.5, turn = -9.0, at = Vector2(-150.0, 84.0)}]}]},
			title = "Silt",
			body = "A shoal of fine dust and ice grit hangs across the lane, dense enough that the dish loses its far side. In the middle is one solid echo, hard and ship-sized, holding its shape while the shoal turns around it. Going in means going in blind on attitude jets, slowly, in case something in there is harder than dust. The near edge is thin enough to see through. For years it has caught what drifts down this lane: plate, loose fittings, and ice with metal frozen through it.",
			tags = [&"hazard"],
			group = &"",
			weight = 7,
			min_danger = 3,
			max_danger = 6,
			choices = [
				{label = "Feel your way in",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						return {text = "You go in on attitude jets and touch nothing on the way. The echo is an intact survey cutter no one has reached before. The grapple takes a rack and its fittings.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You clip something soft on the way in, with no damage. The cutter's racks come away clean.", module = true},
					partial = func() -> Dictionary:
						return {text = "You find it and get one panel open. Then you lose your bearings in the dust and spend the rest of the time getting out."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Something in the shoal is much harder than dust, and you hit it bow first.")
						return {text = "Something in the shoal is much harder than dust, and you hit it bow first."}},
				{label = "Sweep the edge", effect = func() -> Dictionary:
					return {text = "You work the outside of the shoal where the grit is thin. You take what has collected there over the years.", material = &"wreck"}},
				{label = "Avoid it", stay = true, effect = func() -> Dictionary:
					return {text = "You keep the shoal on your beam and fly around it."}},
			],
		},
		{
			id = &"the_queue",
			title = "The queue",
			subject = {layers = [{stage = &"single", pieces = [&"place_station_stack"], at = Vector2(150.0, 0.0), lights = &"run"}, {stage = &"field", flip = true, pieces = [&"role:hauler", &"role:passenger", &"role:barge", &"role:small"], count = 5, near = 0, deep = 3, lift = 12.0, span = 290.0, height = 220.0, seed = 21, tumble = 0.0, at = Vector2(-76.0, 4.0), lights = &"run"}]},
			body = "The dock queue is nine ships long, and the dockmaster will not move anyone up it. The fourth ship has been fourth for two days. The pilot's charter fell through, and she is holding a slot she cannot use or sell back to the dock. She can sell it to another ship. The dockmaster does not mind who docks, as long as someone does.",
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
					return {text = "You pay her, and the transfer takes about a minute. You dock nine ships early, and she gets something out of two wasted days.", module = true}},
				{label = "Trade her fuel for it", effect = func() -> Dictionary:
					Run.drain_fuel(4)
					return {text = "She has no charter and no reason to sit here. You give her enough to leave and take the slot she was sitting on.", module = true}},
				{label = "Wait your turn", stay = true, effect = func() -> Dictionary:
					return {text = "You wait your turn. The queue moves slowly, in order."}},
			],
		},
		{
			id = &"cold_labour",
			title = "Cold labour",
			subject = {stage = &"structure", pieces = [&"st_cold_labour"]},
			body = "A breaker's yard in Redline colours is waving you in. The crew has a new cutting head and does not trust it. They want to test it on someone else's plating before they use it on next week's hull. They will pay you to hold your flank against the head for an hour. They tell you plainly that they do not know what it will do.",
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
						return {text = "The head works as the spec said it would, and your plating takes no damage. They pay well for the test."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						Run.take_hull_damage(OptionTable.toll(2), "It bites deeper than the spec said. You come away paid, and scored down one flank.")
						return {text = "It bites deeper than the spec said. You come away paid, and scored down one flank."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(4), "It bites much deeper than the spec said. They stop the test early and pay you half of it.")
						return {text = "It bites much deeper than the spec said. They stop the test early and pay you half of it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The head finds a seam and cuts through it before the yard crew can hit the cutoff. The crew apologises.")
						return {text = "The head finds a seam and cuts through it before the yard crew can hit the cutoff. The crew apologises."}},
				{label = "Rig them a target instead", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(17))
					return {text = "Your cutter shapes them a test target out of scrap plating. The new head has it in pieces by the end of the afternoon."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "They take it well. The yard is waving at the next ship along before you are clear of the dock."}},
			],
		},
		{
			id = &"quarantine_flag",
			title = "Quarantine flag",
			subject = {layers = [{stage = &"single", pieces = [&"place_station_wheel"], dark = 0.8, at = Vector2(70.0, -5.0)}, {stage = &"group", lights = &"run", flip = true, ships = [{piece = &"role:hauler", far = true, at = Vector2(-140.0, 60.0)}, {piece = &"role:passenger", far = true, at = Vector2(-130.0, -70.0)}]}]},
			body = "A station sits dark with a Calyx quarantine flag on all its channels. For eight days nothing has gone in or out. No drones, decontamination lighters or Calyx hulls have come to it either. Two other ships hold off the exclusion line with you, and their dishes read nothing too. Inside is a full station's worth of stock, and it gets cheaper every hour the flag holds.",
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
						return {text = "The atmosphere reads clean and the hull sits at ambient. No decontamination cycle has ever run here. The flag is covering a stock dispute. The station is glad to sell to the first ship that turns up.", module = true},
					clean = func() -> Dictionary:
						return {text = "Nothing on your instruments backs the flag up and nothing knocks it down. You dock braced, you buy fast, and you leave loaded.", module = true},
					partial = func() -> Dictionary:
						return {text = "You get half a read. You buy one crate you can inspect through the airlock glass and nothing else.", material = &"event"},
					botched = func() -> Dictionary:
						Run.add_credits(-50)
						return {text = "You read it wrong, the way you hoped it would read. Then you sit through a decontamination cycle that costs more than the stock was worth."}},
				{label = "Wait with the others", stay = true, effect = func() -> Dictionary:
					return {text = "You wait off the exclusion line with the other two ships. One of you will learn what the flag was in eight more days."}},
			],
		},
		{
			id = &"counterweight",
			title = "Counterweight",
			subject = {stage = &"single", pick = true, pieces = [&"t3_counterweight_1", &"t3_counterweight_2", &"t3_counterweight_4"], at = Vector2(20.0, -20.0)},
			body = "A habitation ring tumbles end over end ahead, one turn every ninety seconds. It came off a station, and no one collected it. Everything inside is still bolted down where it was fitted. The yard at the settlement one jump in buys ring fittings by the tonne and does not ask which ring. Plating and antenna mounts come past outside on every turn. So does the airlock, never in the same place twice. The ring is heavier than your ship and keeps turning at the same rate while you work.",
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
						return {text = "You match the tumble and hold it steady, so the ring is still relative to you. The grapple works through the lock and takes out what the yard will buy.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "You match the tumble, but the ring hits you as you back out.")
						return {text = "You match it well enough, and the grapple reaches one rack through the lock. Backing out, the ring catches your hull.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(7))
						Run.take_hull_damage(OptionTable.toll(2), "The grapple gets one hold before the rotation pulls the ship into the ring.")
						return {text = "The grapple gets one hold before the rotation pulls the ship into the ring."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "You match the wrong direction of spin, and the ring hits you before you can correct.")
						return {text = "You match the wrong direction of spin, and the ring hits you before you can correct."}},
				{label = "Take the outside", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(8))
					return {text = "You stay outside. The grapple takes what is bolted to the exterior, one piece each turn.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You leave the ring turning, with everything inside still bolted down."}},
			],
		},
		{
			id = &"the_auction",
			title = "The auction",
			subject = {stage = &"structure", pick = true, pieces = [&"st_dock_face_1", &"st_dock_face_2", &"st_dock_face_3", &"st_dock_face_4"], with = [{piece = &"r2_holding_old_container_2", at = "cargo", off = Vector2(-26.0, 0.0)}, {piece = &"ship_mkt_slung", scale = 0.5, flip = true, lights = &"run", at = Vector2(10.0, 100.0)}, {piece = &"ship_courier2", scale = 0.5, flip = true, lights = &"run", at = Vector2(0.0, 150.0)}, {piece = &"ship_hp_wards", scale = 0.5, flip = true, lights = &"run", at = Vector2(40.0, 255.0)}]},
			body = "Probate is selling a dead crew's hold. There are no heirs. The lot is sealed, the manifest is sealed, and the buyer takes it as it lies. Two of the last three lots were worth less than the fee. The third was worth a great deal more, and its buyer has not needed to work since. Bidding closes in an hour, and there are four of you.",
			tags = [&"contract"],
			group = &"berth",
			weight = 7,
			min_danger = 5,
			needs_berth = true,
			choices = [
				{label = "Bid on it", cost_credits = 70, effect = func() -> Dictionary:
					Run.add_credits(-70)
					return {text = "You pay the fee and take the lot as it lies. Forty minutes later you break the seal in your own hold, where no one else can see what you got.", module = true, material = &"event"}},
				{label = "Read the room instead",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(13))
						return {text = "You do not bid. You watch who does, and how the Probate clerk reacts to the third bidder's price. Afterwards you know which lot next week is worth having, and you sell that."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(7))
						return {text = "You learn something about two of the bidders. You can sell it now, and it will be useful later."},
					partial = func() -> Dictionary:
						return {text = "You learn only that the other bidders are better at this than you are."},
					botched = func() -> Dictionary:
						Run.add_credits(-70)
						return {text = "You read a nod across the room as a bid. You win a lot you did not want, at a price you did not pick.", material = &"event"}},
				{label = "Let it go", stay = true, effect = func() -> Dictionary:
					return {text = "One of the other three pays the fee and takes the sealed lot."}},
			],
		},
		{
			id = &"escort",
			title = "Escort",
			subject = {stage = &"field", flip = true, lights = &"run", pieces = [&"role:hauler", &"role:small", &"role:hauler", &"role:hauler"], count = 4, near = 1, deep = 1, lift = 30.0, span = 440.0, height = 240.0, seed = 13, tumble = 0.0},
			body = "Three haulers and a courier hold station off your bow. None of them is armed. They are all headed the way you are, and none of them is happy about it. The only armed ship in the system quoted them a price worth most of the run. They would rather pay you. All they want is for you to fly alongside them, visible, with weapons.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 11,
			min_danger = 3,
			max_danger = 8,
			max_security = 2,
			choices = [
				{label = "Take the contract", fight = true, effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(33))
					return {text = "You fly the flank for one ring. Then a ship comes out of the shadow of the third moon and attacks the convoy.", fight = true}},
				{label = "Sell them the courier's slot", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(28))
					return {text = "The courier is fast enough to outrun anything out here alone. You tell them so, take a cut for the advice, and the convoy splits."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "They pay the other escort most of what the run is worth and leave without you."}},
			],
		},
		{
			id = &"nine_tonnes",
			title = "Nine tonnes of nothing",
			subject = {stage = &"single", pieces = [&"r2_container_freight_box_1"]},
			body = "A freight crate sits on the dock, and its owner wants it moved one ring inward, above rate. The numbers do not match. The manifest says nine tonnes, but the crate is sized for forty, and it reads warm on your sensors. He is happy for you not to ask what is in it. He is less happy about you opening it.",
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
						return {text = "It is undeclared reactor fuel in a casing rated for something safer, worth four times the freight. He pays the new rate without arguing."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "It is not what the manifest says, but it is safe. You take the job at a better rate."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(25))
						return {text = "You get the casing open, find nothing worth knowing, and shut it before he notices. The rate stays what it was."},
					botched = func() -> Dictionary:
						return {text = "He notices, and he leaves with the crate. The job is off."}},
				{label = "Just take the job", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(25))
					return {text = "You move the nine tonnes one ring inward, above rate, and ask no questions."}},
				{label = "Pass", stay = true, effect = func() -> Dictionary:
					return {text = "He finds another ship inside the hour."}},
			],
		},
		{
			id = &"ice",
			subject = {stage = &"single", pieces = [&"paint_moon_europa"], lumpy = 3.3, r = 34.0, dirt = 0.45, at = Vector2(110.0, -80.0)},
			title = "Ice",
			body = "A comet hangs off your bow, three kilometres of dirty ice on a long, slow orbit. It has no transponder and no claim on it, and no one out here buys water. Under the crust are volatiles and a little metal. The crust has hardened since this system was warm, and it is under pressure, so it can crack when you cut it.",
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
						return {text = "You take the crust off in sheets and get at the clean ice under it. There are volatiles and water. There is enough left in the tail to make the trip pay.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.fuel += 3
						Run.take_hull_damage(OptionTable.toll(3), "The crust breaks the wrong way. You get most of what you came for, and the rest scrapes down one side of the hull.")
						return {text = "The crust breaks the wrong way. You get most of what you came for, and the rest scrapes down one side of the hull."},
					partial = func() -> Dictionary:
						Run.fuel += 2
						Run.take_hull_damage(OptionTable.toll(5), "The face calves while you are cutting it. You back off with a half hold and a dented bow.")
						return {text = "The face calves while you are cutting it. You back off with a half hold and a dented bow."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "The face of hard ice lets go all at once, and it pours into your bow for about eleven seconds.")
						return {text = "The face of hard ice lets go all at once, and it pours into your bow for about eleven seconds."}},
				{label = "Skim the tail", effect = func() -> Dictionary:
					Run.fuel += 1
					return {text = "You leave the body alone and run the tail instead, taking what it is already shedding. It is slow and safe."}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the comet and fly on. It comes back around in ninety years."}},
			],
		},
		{
			id = &"flare_shelter",
			site = &"star",
			subject = {layers = [{stage = &"single", pieces = [&"paint_rock_a1"], r = 58.0, at = Vector2(-30.0, -12.0)}, {stage = &"single", pieces = [&"r2_drone_delivery_drone_2"], dark = 0.55, at = Vector2(122.0, 62.0)}]},
			title = "Flare shelter",
			body = "The star's readings are climbing, and the instruments are sure a big flare is about forty minutes out. Two minutes away is a rock big enough to shadow you. A survey drone is tucked in behind it, where it has sheltered from flares for years. Forty minutes is enough to reach the rock and strip the drone, with little time to spare.",
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
						return {text = "You reach the shadow, and the cutter opens the drone in the dark. You come out of the flare with its readings, a rack off its frame, and a cold reactor.", module = true, material_id = &"survey_film"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You get most of it done before the shadow starts to move. You finish the rest out in the light.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 17
						return {text = "The cutter gets the drone open, but no more. The flare hits you with the hold still empty."},
					botched = func() -> Dictionary:
						Run.heat += 25
						return {text = "You misread how the rock turns. You spend the peak of the flare out on the lit side."}},
				{label = "Just shelter", effect = func() -> Dictionary:
					return {text = "You put the rock between you and the star and wait the flare out. One piece of somebody else's cargo drifts into the shadow with you. The grapple takes it in.", material = &"event"}},
				{label = "Outrun it", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					return {text = "You leave before it peaks. It costs a burn you had not budgeted for and you never find out what was on the drone."}},
			],
		},
		{
			id = &"deadfall",
			title = "Deadfall",
			subject = {layers = [{stage = &"strewn", far = true, pieces = [&"r6_gantry_snapped_truss_drifting_2_p3", &"r6_gantry_snapped_truss_drifting_2_p1", &"r6_gantry_snapped_truss_drifting_2_p4", &"r6_gantry_snapped_truss_drifting_2_p2"], turn = [12.0, -7.0, 17.0, -11.0], lift = [0.0, 10.0, -8.0, 6.0], gap = 16.0, at = Vector2(70.0, -78.0)}, {stage = &"strewn", pieces = [&"r6_gantry_snapped_truss_drifting_2_p1", &"r6_gantry_snapped_truss_drifting_2_p2", &"r6_gantry_snapped_truss_drifting_2_p3", &"r6_gantry_snapped_truss_drifting_2_p4"], turn = [-4.0, 9.0, -14.0, 20.0], lift = [8.0, -10.0, 16.0, -4.0], gap = 18.0, at = Vector2(0.0, 22.0)}]},
			body = "Nine hundred metres of collapsed gantry lies across the approach. It was an orbital yard, and it fell in on itself slowly after a decade with no one paying for maintenance. Parts of the wreck are still under tension and let go of a piece now and then. Under the middle of it is a fitting bay, where a yard like this kept its best parts.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 5,
			choices = [
				{label = "Go under it",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						return {text = "You pick a line through nine hundred metres of dead scaffolding, and nothing touches you. The bay is exactly as it was left.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "You get in and get the bay open. Something lets go behind you and clips the hull on its way past.")
						return {text = "You get in and get the bay open. Something lets go behind you and clips the hull on its way past.", module = true},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Two hundred metres in, a span shifts across your line. You reverse out past a fitting bay you can see and cannot reach.")
						return {text = "Two hundred metres in, a span shifts across your line. You reverse out past a fitting bay you can see and cannot reach."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A span has held there for a decade. It lets go while you are under it.")
						return {text = "A span has held there for a decade. It lets go while you are under it."}},
				{label = "Work the outside", effect = func() -> Dictionary:
					return {text = "The edge of the field is safe and already picked over. You take what the last four crews did not think was worth lifting.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You keep clear of the gantry and fly on."}},
			],
		},
		{
			id = &"the_long_tow",
			title = "The long tow",
			subject = {stage = &"single", pieces = [&"role:hauler"], dark = 0.55, lights = &"battery", at = Vector2(40.0, 0.0)},
			body = "A ship hangs dead off your bow with its hull lights running on battery. Its crew answers the hail at once. The reactor is scrap, but all six of them are fine. The dock on the far side of this system will take the ship if it can get there. A tow is four hours of your engine at a load it was not built for. The hull on your stern does not steer.",
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
						return {text = "The tow takes four hours on one heading, and nothing goes wrong. The dock takes the ship."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						Run.take_hull_damage(OptionTable.toll(2), "The tow takes five hours and strains a stern mount. The ship gets there.")
						return {text = "The tow takes five hours and strains a stern mount. The ship gets there."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						return {text = "You get it most of the way before your engine can take no more. A yard tug takes the last leg and most of the fee."},
					botched = func() -> Dictionary:
						Run.drain_fuel(3)
						return {text = "The line parts under load. Nobody is hurt. You lose four hours, one tow line, and all the fuel you burned getting that far."}},
				{label = "Sell them a reactor start", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(36))
					return {text = "You have enough fuel aboard to start its cold reactor, though it leaves a thin safety margin. They take it."}},
				{label = "Signal it in and go", stay = true, effect = func() -> Dictionary:
					return {text = "You put their position on the emergency band and fly on."}},
			],
		},
		{
			id = &"the_calf",
			title = "The calf",
			subject = {layers = [{stage = &"single", pieces = [&"paint_rock_b4"], r = 80.0, at = Vector2(90.0, -30.0)}, {stage = &"single", pieces = [&"pool_calf_wound"], at = Vector2(-70.0, 40.0)}]},
			body = "A megafauna calf hangs beside a cold rock, calling for the pod it lost. Like all of them, it reads warm on every instrument, and that warmth is why they are hunted. A hunter somewhere behind you has posted a standing bounty for a tagged calf. The pod is two hours out, answering on a frequency so low your hull picks it up as vibration.",
			tags = [&"signal"],
			group = &"herd",
			weight = 8,
			min_danger = 3,
			max_danger = 8,
			needs_fauna = true,
			choices = [
				{label = "Tag it for the bounty", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "You fire a transponder dart, get a confirmation ping, and are paid by a ship you never see. The calf carries the tag toward its pod. The bounty terms say that what happens next is not your business."}},
				{label = "Herd it home",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						Run.fuel += 3
						return {text = "You put your hull where a parent would put its flank. It follows you all the way in. The pod closes around it. Nine of them turn at once, and the wake carries you a long way for free."},
					clean = func() -> Dictionary:
						Run.fuel += 1
						return {text = "It follows in the end, after twice taking you for a threat. The pod's wake pays back some of the fuel."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "It bolts the wrong way twice. You spend an hour of burn undoing each of those. Then it hears the pod itself and goes in alone."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "It panics at the wrong moment and hits you with its flank at speed. It still reaches the pod.")
						return {text = "It panics at the wrong moment and hits you with its flank at speed. It still reaches the pod."}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "The pod is two hours out. The hunter behind you is closer than that. You do not stay to see which one gets there first."}},
			],
		},
		{
			id = &"the_manifest",
			title = "The manifest",
			subject = {stage = &"single", pieces = [&"ship_rf_pipes"], lights = &"run"},
			body = "A heat barge sits across the lane inward with its running lights on and drives cold. The woman flying it is hailing for a witness. The rules want a second signature on the last leg, from someone with nothing to gain. She has held station for a day and a half, waiting for a ship that neither pays her nor competes with her. The seal on the load reads nine hundred units, signed at the last station with the authority to sign it. Your mass reading puts the barge four points heavy for nine hundred units of anything.",
			tags = [&"contract"],
			group = &"threshold",
			weight = 9,
			min_danger = 9,
			regions = [MapGen.Region.DEEP],
			choices = [
				{label = "Sign what the seal says", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(14))
					return {text = "You sign for nine hundred units and hold formation for the last leg. The fee clears before you have decided what you saw. It pays well for an hour of flying, and the four points stay unexplained."}},
				{label = "Put the dish on the load first",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "The load is eleven hundred units against a seal for nine. Someone up the line is moving two hundred units of something inward and paying tax on the smaller number. The pilot was never told what it is. You sign the true figure, and she pays you for it, glad to send the problem back to whoever made it."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						return {text = "The mass settles close enough to the seal. The difference is fuel and ice, which shift the reading on a barge low on both. You sign, fly the leg and collect."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(3))
						return {text = "Your figures will not settle, and her window will not wait. You refuse to sign a reading you cannot trust and take the standing fee for answering the hail. She looks for another witness."},
					botched = func() -> Dictionary:
						Run.add_credits(-60)
						return {text = "You sign a number that the vault's own scale later disputes. The fine lands on you, because yours is the only name on the paper anyone can find."}},
				{label = "Let her carry on", stay = true, effect = func() -> Dictionary:
					return {text = "She holds another hour on the open channel. Then she flies the last leg without a witness so she does not lose the window."}},
			],
		},
	])
	return out
