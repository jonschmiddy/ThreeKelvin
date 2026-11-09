class_name OptionsPart01

## Encounters 1 to 15 of the authored table (`dropped_load` to `the_braid`), in the order `OptionTable._authored`
## joins them: `roll_for` draws by table order, so entries never move between or within files.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{
			id = &"dropped_load",
			title = "The dropped load",
			subject = {stage = &"single", pieces = [&"r4_pod_cargo_pod_1"], tumble = 2.0},
			body = "Two ships sit either side of a drifting cargo pod. Both have running lights on and weapons warm. Neither crew looks keen on a fight. They would rather be paid than shoot. Both are claiming the pod on the open channel. The pod's transponder log shows who dropped it. Your dish is the only one in range with no stake in the answer.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			max_danger = 8,
			choices = [
				{label = "Read the log",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "The log is clear. The smaller ship dropped it two days ago in a bad burn. You send the timestamps out on the open channel. The bigger ship peels off without a word. The owner pays a finder's rate for getting the pod back with no shot fired."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "The log is clear enough. The losing crew argues with you for a while. You have the timestamps on the channel, and in the end they stop."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "The log is older than both ships, so neither crew owns the pod. You split it three ways, fast, before another ship turns up and wants a share."},
					botched = func() -> Dictionary:
						Run.add_credits(-20)
						return {text = "You call it for the wrong ship, and you sound sure of it. The right ship leaves with the pod, and you pay back your reading fee."}},
				{label = "Snatch it while they argue", fight = true, effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "You burn in and take the pod while both crews are shouting about it. They stop shouting at each other and turn their guns on you.", fight = true, material = &"event"}},
				{label = "Leave them to it", stay = true, effect = func() -> Dictionary:
					return {text = "You leave the two crews to sort out the pod. Their argument is still on the open channel long after the pod is out of range."}},
			],
		},
		{
			id = &"long_claim",
			title = "The long claim",
			subject = {stage = &"single", pieces = [&"paint_rock_a2"], r = 86.0},
			body = "A bare rock turns past your bow. One face has a mineral seam down it, and the rock has no transponder. No one mines this far out, because hauling the ore back costs more than it sells for. The best of the seam runs under an overhang that looks ready to fall. Taking the seam is a day of cutting. There is no other ship out here and none on the way.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			max_danger = 4,
			max_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Work it", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(38))
					return {text = "It takes most of a day and one cutting head. You come away with enough off the seam to sell at the next station.", material = &"mining"}},
				{label = "Work it hard",
					check = {attr = &"hull", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(38))
						return {text = "You take the seam and the shelf under it as well, and the frame takes no damage.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(38))
						Run.take_hull_damage(OptionTable.toll(3), "You take more than the seam. The forward bracing cracks under the strain, then holds.")
						return {text = "You take more than the seam. The forward bracing cracks under the strain, then holds."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						Run.take_hull_damage(OptionTable.toll(5), "The shelf comes away wrong and takes the cutting head with it. You get half of what you came for. The rest of the seam stays in the rock.")
						return {text = "The shelf comes away wrong and takes the cutting head with it. You get half of what you came for. The rest of the seam stays in the rock."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "The overhang comes down while you are still under it, and it lands on the bow.")
						return {text = "The overhang comes down while you are still under it, and it lands on the bow."}},
				{label = "Move on", stay = true, effect = func() -> Dictionary:
					return {text = "You log the seam and leave the overhang where it is. No other ship is close enough to work it before you return."}},
			],
		},
		{
			id = &"slipping_orbit",
			site = &"giant",
			subject = {layers = [{stage = &"single", pieces = [&"r5_scatter_spar_1"], turn = -14.0, tumble = 1.5, at = Vector2(40.0, -76.0)}, {stage = &"single", pieces = [&"r4_scatter_torn_plate_1"], turn = 10.0, tumble = 2.0, at = Vector2(-84.0, -56.0)}]},
			title = "Slipping orbit",
			body = "A gas giant fills half the viewport, and its gravity has you. You came in on a slow transfer to save fuel, and the well pulled you lower than you planned. The gauges give you about four minutes to decide whether the engines can climb out. The dish reads a spar of old wreckage on the same track, plate and frame both, caught by the well long ago. A hard burn climbs straight out and passes close enough to grapple it. A slower burn also gets out, but it uses a lot of fuel. One orbit costs you an hour and nothing else.",
			tags = [&"hazard"],
			group = &"",
			weight = 10,
			# A GAS GIANT FILLS HALF THE VIEWPORT. It cannot fill half of
			# anything at a system that does not have one.
			needs_giant = true,
			choices = [
				{label = "Burn out of the well",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						return {text = "You climb out cleanly. On the way past, the grapple takes the spar of old wreckage.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "The engines get you out of the well in the end. They burn two units doing it."},
					partial = func() -> Dictionary:
						Run.drain_fuel(4)
						return {text = "You get out, but the climb costs four units."},
					botched = func() -> Dictionary:
						Run.drain_fuel(6)
						return {text = "You skim the atmosphere going up. It costs six units and scorches the paint."}},
				{label = "Orbit once", stay = true, effect = func() -> Dictionary:
					return {text = "You ride one slow orbit without a burn. It costs the hour."}},
			],
		},
		{
			id = &"mine_drift",
			title = "Mine drift",
			subject = {layers = [{stage = &"single", pieces = [&"role:hauler"], far = true, dark = 0.75, at = Vector2(0.0, -6.0)}, {stage = &"ring", pieces = [&"r2_minedrift_limpet_mine_1", &"r4_minedrift_prong_mine_1", &"r2_minedrift_limpet_mine_2", &"r2_minedrift_prong_mine_2", &"r4_minedrift_prong_mine_2", &"r2_minedrift_limpet_mine_1", &"r4_minedrift_prong_mine_1"], count = 7, near = 0, rx = 150.0, ry = 62.0, spin = 0.3, roll = 8.0, roll_step = 15.0, at = Vector2(0.0, -6.0)}, {stage = &"field", pieces = [&"r4_minedrift_buckled_plate_1", &"r2_minedrift_broken_strut_2"], count = 2, near = 2, span = 430.0, height = 240.0, seed = 21, tumble = 4.0, turns = 30.0}]},
			body = "Dozens of old mines sit across the debris belt ahead. They still keep station around the ship they were set to guard. Whoever laid them stopped answering long ago, and no one came back for the ship. It is whole, with its hull unbreached and its holds shut. A second hull lies further in, opened along one flank by something other than the belt. A module is still racked in the open where the grapple could lift it. Some of the mines are too old to fire, but from out here you cannot tell which.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 5,
			choices = [
				{label = "Thread it",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						return {text = "You fly through the field without a hit. On the way out you lift a module off the opened wreck.", module = true},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "One mine hits your flank on the way out, and only one.")
						return {text = "One mine hits your flank on the way out, and only one."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Two mines hit, then a third, and you back out the last hundred metres.")
						return {text = "Two mines hit, then a third, and you back out the last hundred metres."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "An old mine fires late, after you are past it, and hits you from behind.")
						return {text = "An old mine fires late, after you are past it, and hits you from behind."}},
				{label = "Sweep wide", stay = true, effect = func() -> Dictionary:
					return {text = "You give the whole drift a wide margin and lose nothing but time."}},
			],
		},
		{
			id = &"corona",
			site = &"star",
			subject = {stage = &"single", pieces = [&"ship_cl_stack"], dark = 0.75, bake = 0.9, at = Vector2(40.0, 10.0)},
			title = "The corona",
			body = "The star here throws a flare every few hours, and the next one is due soon. Close in, inside the glare, a wreck sits with its holds intact. Other ships read the temperature and left. The light has baked the wreck's lit side to an amber crust. It is thick enough for the cutter to take off as a whole plate. The holds under it are still racked. Your vents have to carry the heat the whole way in and out. The board cannot say exactly when the next flare comes.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 7,
			min_danger = 5,
			# A mid-tantrum star is a fact about the star, not depth: a flare star on the rim is as
			# dangerous.
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Go in hot",
					check = {attr = &"thermal", need = 6},
					met = func() -> Dictionary:
						return {text = "Your vents hold the whole way in and out. The cutter takes a plate of amber crust off the lit side. The grapple pulls a rack out of a hold.", material_id = &"corona_amber", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "The grapple takes one rack off the wreck. You come out with a reactor that needs a minute to cool.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "You get one hold open, but the heat climbs too fast, and you back off before you can take anything."},
					botched = func() -> Dictionary:
						Run.heat += 20
						return {text = "The flare comes early. You leave with nothing, and the ship runs hot all the way out."}},
				{label = "Log the wreck", stay = true, effect = func() -> Dictionary:
					return {text = "You hold station outside the corona and log the wreck for a ship with better vents."}},
			],
		},
		{
			id = &"the_wind",
			site = &"star",
			subject = {stage = &"fx", fx = &"wind"},
			title = "The wind",
			body = "The star here is a blue hypergiant, losing mass fast enough to measure. The gas it sheds crosses this lane as a front, and the dish reads it an hour out. The gas is thin and very fast, and all of it moves outward the way you are going. Turn the hull side on and it carries the ship while the reactor idles. Meet it bow first and it shoves the bow aside, and the rest of the ship follows. Crossing at an angle under power costs fuel and gets you through inside the hour. The front is most of a day wide and will be past by the end of the afternoon.",
			tags = [&"hazard"],
			group = &"",
			weight = 8,
			min_danger = 5,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Ride the front",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.fuel += 3
						return {text = "You put the hull side on for ninety seconds and let the front carry you. The crossing costs you no fuel at all."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						return {text = "You catch the edge of the front and hold it there. The reactor spends the whole crossing idling."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						Run.heat += 5
						return {text = "You catch it badly and spend the crossing correcting. That costs you most of what the front gave you."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "The front takes the bow first and turns the whole ship sideways.")
						return {text = "The front takes the bow first and turns the whole ship sideways. It takes a long time to bring the ship back under control."}},
				{label = "Burn across it", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You cross the front at an angle, under power the whole way, and pay for it in fuel."}},
				{label = "Wait it out", stay = true, effect = func() -> Dictionary:
					return {text = "You hold position until the front has gone past. It costs you the afternoon and nothing else."}},
			],
		},
		{
			id = &"the_glare",
			site = &"star",
			subject = {layers = [{stage = &"fx", fx = &"glare", reach = 340.0}, {stage = &"single", pieces = [&"ship_lrshuttle"], dark = 1.0, silhouette = 0.9, at = Vector2(60.0, -10.0)}]},
			title = "The glare",
			body = "A blue hypergiant puts out more light in an hour than most stars do in a year. The dish reads this whole approach as white. Across a quarter of the sky it picks out no returns and no shadows. The last clean sweep before the dish whited out had a contact in it. It was the size of a ship, and it was holding still.",
			tags = [&"hazard"],
			group = &"",
			weight = 7,
			min_danger = 5,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Go in on the last bearing",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						return {text = "You fly the bearing and trust it. The contact is a wreck, exactly where the dish put it, and no one has been here before you. The grapple takes its racks.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You find it on the third pass, with one pass to spare. You strip what you can reach before you lose it in the glare again.", module = true},
					partial = func() -> Dictionary:
						return {text = "You find where the contact was, but it has moved. Something that came off it is still nearby, and you take that.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 8
						return {text = "You spend an hour inside the glare and come out with a hot hull. You never find out whether you got within ten kilometres of it."}},
				{label = "Sweep the shadow side", effect = func() -> Dictionary:
					return {text = "You put the nearest rock between you and the star and read the sliver of sky in its shadow. The contact is not there, but something smaller has been drifting there for a while.", material = &"wreck"}},
				{label = "Log the bearing and go", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and the time. Then you turn out of the glare and take the long way in. The dish stays white for another hour."}},
			],
		},
		{
			id = &"the_scouring",
			title = "The scouring",
			subject = {stage = &"single", pieces = [&"place_derelict"], turn = 4.0},
			body = "A hull has sat in the wind of a blue hypergiant for a long time. The wind has stripped everything soft off it: the paint, the markings, the seals, and the crew's remains. What is left is frame and fittings, polished to bare metal and still bolted down. The star does the same to your plating the whole time you are alongside, though more slowly.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 7,
			min_danger = 5,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Work it until you have to leave",
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						return {text = "You stay alongside for four hours. The grapple takes the racks and most of a reactor housing. Your plating comes away polished on the star-facing side.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "You stay alongside a blue hypergiant for three hours, and the plating on the star-facing side gives out.")
						return {text = "You take one rack in three hours. The hull needs work.", module = true},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "You stayed alongside longer than the plating could take. The star went through it and into the frame.")
						return {text = "You get one rack off it before your plating readings start to drop, and you leave.", module = true},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "You misjudged how long is too long beside a blue hypergiant. The star cut through your plating while you worked.")
						return {text = "You stay too long and get nothing. The wreck keeps its fittings, and you leave with damaged plating."}},
				{label = "Take what is already loose", effect = func() -> Dictionary:
					return {text = "You work the drift downwind of the hull instead and take what the star has already stripped loose.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You hold off and take nothing. The hull keeps its fittings."}},
			],
		},
		{
			id = &"the_runner",
			title = "The runner",
			subject = {stage = &"single", pieces = [&"role:small"], lights = &"run"},
			body = "A pilot is running an errand for someone else, in someone else's ship. The parcel she needs moved is small enough to fit in a pocket. It has no manifest, no filing and no name on it. She cannot pay much now. She says the person it goes to will pay properly on delivery, but she is only repeating what she was told.",
			tags = [&"contract"],
			group = &"",
			weight = 7,
			min_danger = 3,
			max_danger = 8,
			max_security = 2,
			choices = [
				{label = "Hide it aboard",
					check = {attr = &"stealth", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "It goes into a space behind the coolant run that no scan reaches and no one else knows about. She watches you stow it and does not ask what else is in there.", place = &"paid_in_full"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "You find a place for it inside the ship that will pass an ordinary search.", place = &"paid_in_full"},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "You stow it badly. For the whole next shell, a search would find it.", place = &"paid_in_full"},
					botched = func() -> Dictionary:
						return {text = "You are still looking for a place to put it when a patrol sweeps the dock. The sweep finds nothing, but she sees it and takes the parcel back."}},
				{label = "Ask what it is", stay = true, effect = func() -> Dictionary:
					return {text = "She tells you something, and you cannot tell if it is true. The parcel stays with her while she waits for your answer."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "She expected that. She goes to ask the next ship along the dock."}},
			],
		},
		{
			# Placed, never rolled, and ungrouped on purpose: an auction must not foreclose a
			# consequence.
			id = &"paid_in_full",
			title = "Paid in full",
			subject = {stage = &"structure", pick = true, pieces = [&"st_dock_face_1", &"st_dock_face_2", &"st_dock_face_3", &"st_dock_face_4"], add_lights = [{at = "collar", off = [-2, 0], r = 12, col = "#ffcf7a", kind = "breathe", period = 6.0, k = 1.8, cone = 90, cone_k = 0.8}]},
			body = "The one waiting for the parcel is old, and not who you expected. He has been at this dock for eleven days. It is one small sealed package, and he does not open it where you can see. He pays what she said he would pay, which is far more than she could have promised. Then he asks carefully whether she looked well.",
			tags = [&"quest"],
			group = &"",
			placed = true,
			# Row in the QUESTS table (`QuestLog`); the note matches the body word for word
			# (`QuestLogTest`).
			# Why: docs/why/OptionsPart01.md#quest-table-row
			quest = {task = "Deliver the runner's parcel", tag = "DELIVER", from = &"the_runner",
				note = "She says the person it goes to will pay properly on delivery, but she is only repeating what she was told."},
			weight = 0,
			choices = [
				# No failing band: `batch-03` ruled that taxing an earned reward teaches players to
				# refuse the offer.
				{label = "Take the money", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "He pays in full and in cash, and then he thanks you."}},
				{label = "Tell him she looked tired", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "He nods for a long time and pays more than the agreed rate. He also names a yard two shells in that will fit you something at cost.", module = true}},
			],
		},
		{
			# Pickup for a signed fetch, placed by `Contracts.post_goal`, per ship, and never
			# rolled.
			id = &"job_pickup",
			title = "Contract pickup",
			subject = {stage = &"single", pieces = [&"r4_pod_cargo_pod_1"], tumble = 2.0},
			body = "A cargo pod is parked in orbit here. Its beacon sends the code from your contract. This is the pickup you signed for. The seals are still on it, and the job says to leave them on.",
			tags = [&"quest"],
			group = &"",
			placed = true,
			job = true,
			weight = 0,
			choices = [
				{label = "Bring it aboard", effect = func() -> Dictionary:
					var who := Contracts.payer_here(ContractData.Kind.FETCH)
					Run.reach_contract_target(Run.at)
					return {text = "The grapple pulls the pod in and locks it to the frame. It takes no room in the hold. Take it to any %s yard to be paid." % who}},
				{label = "Leave it for now", stay = true, effect = func() -> Dictionary:
					return {text = "You leave the pod where it is. The beacon keeps sending, and the job stays open."}},
			],
		},
		{
			# Hunt target, same way. The kill readies it (`Combat._victory`); fleeing posts it
			# again.
			id = &"job_target",
			title = "Contract target",
			subject = {stage = &"single", pieces = [&"ship_gunboat"], dark = 0.85},
			body = "A ship sits here with its running lights off. Its transponder matches the one on your contract. It has seen you. It turns its bow toward you and holds there.",
			tags = [&"quest", &"fight"],
			group = &"",
			placed = true,
			job = true,
			weight = 0,
			choices = [
				{label = "Engage", fight = true, effect = func() -> Dictionary:
					return {text = "You close on it and open fire.", fight = true}},
				{label = "Leave it for now", stay = true, effect = func() -> Dictionary:
					return {text = "You keep your distance. It stays where it is, and the job stays open."}},
			],
		},
		{
			id = &"ghost_signal",
			subject = {stage = &"none"},
			title = "Ghost signal",
			body = "The dish is pulling a signal out of the background noise. It is too regular to be a star and too weak to be a station. In eleven minutes it has not drifted a second of arc, so the sender is fixed to something solid. The chart shows nothing at that bearing. Resolving it means holding position and giving the dish full power. At full power the dish can mistake your own reactor harmonics for a signal, and then you spend fuel chasing them.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			max_danger = 4,
			max_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Resolve it",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "It is a precursor beacon, still sending on a cycle no one uses now. You cannot read any of it. The grapple takes the housing off its mount and into the hold.", material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You pinpoint it, but the housing is fused to its mount and will not come off. You take the readings instead, shot onto film straight off the dish and never developed.", material_id = &"survey_film"},
					partial = func() -> Dictionary:
						return {text = "You chase it for an hour and it never comes clear. In the end it is your own reactor harmonics, reflected off something you never find."},
					botched = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You follow it a long way before you accept it was never there. It costs two units of fuel."}},
				{label = "Log it and go", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and move on, and leave it for a ship with a better dish."}},
			],
		},
		{
			id = &"customs_cordon",
			title = "Customs cordon",
			subject = {stage = &"group", ships = [{piece = &"role:hauler", dark = 0.7, at = Vector2(10.0, 50.0), z = 0}, {piece = &"ship_catamaran", fights = true, lights = &"patrol", at = Vector2(-5.0, -45.0), z = 1}, {piece = &"role:armed", fights = true, size = 0.5, dark = 0.6, at = Vector2(-168.0, -40.0), z = 1}, {piece = &"role:armed", fights = true, size = 0.5, dark = 0.6, at = Vector2(165.0, -48.0), z = 1}]},
			body = "A revenue cutter holds station over a seized hull, with two cold escorts off its flanks. Its crew seized that hull nine days ago. The impound paperwork is still not done. Until the paperwork clears, the manifest is public, and it lists what is still aboard. The cutter lets traffic through. It is here to guard the cargo.",
			tags = [&"signal", &"fight"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 8,
			min_security = 3,
			choices = [
				{label = "Go in dark",
					check = {attr = &"stealth", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(17))
						return {text = "You go across cold and silent, close enough to read the cutter's hull number. Nobody on it looks up. The seized hold is as open as its manifest said.", module = true},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You shut down all but the reactor, which runs hot. You take one rack for six heat and are not caught.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(-40)
						return {text = "Their sensors get a partial return, and they hail you in before you reach the hull. You pay the fine."},
					botched = func() -> Dictionary:
						Run.add_credits(-40)
						return {text = "They light you up from two sides at once and fine you, and the cutter's escorts come in to fight.", fight = true}},
				{label = "Hail them and ask", stay = true, effect = func() -> Dictionary:
					return {text = "You hail the cutter, ask what it is sitting on, and get told. It costs an afternoon and nothing else, and the hold stays sealed."}},
			],
		},
		{
			id = &"the_braid",
			title = "The braid",
			subject = {layers = [{stage = &"field", flip = true, pieces = [&"r2_braid_the_braid_idea2", &"r2_braid_the_braid_idea3", &"r2_braid_the_braid_idea2"], count = 3, near = 0, deep = 1, span = 440.0, height = 120.0, seed = 3, tumble = 0.0, at = Vector2(0.0, -64.0)}, {stage = &"single", flip = true, pieces = [&"r2_braid_the_braid_idea3"], at = Vector2(40.0, 62.0)}]},
			body = "Nine megafauna cross the dish in a line, big enough that the dish reads them as terrain. They follow a lane older than any chart. The wake behind them would carry you most of the way to the next ring. They are not hostile, but they are not watching for ships either. The smallest one is longer than yours.",
			tags = [&"signal"],
			group = &"herd",
			weight = 7,
			min_danger = 3,
			max_danger = 8,
			needs_fauna = true,
			choices = [
				{label = "Ride the wake",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						Run.fuel += 3
						return {text = "You slot into the wake behind the third one and let it carry you. It never notices you."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						return {text = "You hold the wake most of the way before the wash pushes you out of it."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "You misjudge the gap and drop in late. You spend the whole run fighting the wash instead of riding it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The fourth one turns out of the lane while you are close in, and its flank tears off your dorsal plating.")
						return {text = "The fourth one turns out of the lane while you are close in, and its flank tears off your dorsal plating."}},
				{label = "Take what they shed", effect = func() -> Dictionary:
					return {text = "You hold off the lane and collect what works loose in the wake. Their hides carry decades of junk: plate, ice, and today a whole rack off some ship that got too close.", module = true, material_id = &"hide_scrap"}},
				{label = "Let them pass", stay = true, effect = func() -> Dictionary:
					return {text = "You hold off and wait while the nine of them pass. Then the dish clears."}},
			],
		},
	])
	return out
