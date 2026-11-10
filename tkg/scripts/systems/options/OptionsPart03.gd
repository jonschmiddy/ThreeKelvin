class_name OptionsPart03

## Encounters 33 to 49 of the authored table (`the_last_berth` to `drifting_lifepod`), in the order `OptionTable._authored`
## joins them: `roll_for` draws by table order, so entries never move between or within files.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{
			id = &"the_last_berth",
			title = "The last counter",
			subject = {stage = &"single", pieces = [&"place_station_stack"], lights = &"run"},
			body = "This is the deepest dock still lit, with one clerk behind its counter. She logs arrivals, though the traffic stopped before her posting began. She logs yours properly: name, mass, heading, and the time to the minute. Her rate sheet has not changed in eleven years. That makes her fuel the cheapest in the galaxy, and she does not know it. Her archive drawer holds one thick folder with no label. She calls it the observations.",
			tags = [&"contract"],
			group = &"threshold",
			weight = 8,
			min_danger = 9,
			regions = [MapGen.Region.DEEP],
			needs_berth = true,
			choices = [
				# 4 credits for 6 fuel keeps "cheapest in the galaxy" true (fuel:A, Oct 18); it was
				# 30 for 6.
				# Why: docs/why/OptionsPart03.md#fuel-price
				{label = "Buy fuel at her rates", cost_credits = 4, effect = func() -> Dictionary:
					Run.add_credits(-4)
					Run.fuel += 6
					return {text = "The rate is on a sheet she cannot change and has no reason to doubt. She stamps the receipt twice, once for you and once for a copy no one has collected in eleven years."}},
				{label = "Stay and copy the folder", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "Copying it takes most of a shift, with the reactor idling. It is other crews' paperwork about the thing at the core. There are transit logs that stop mid line and a mass estimate crossed out four times. There is an order for instruments that were never sent and never cancelled. She reads along with you in silence. In eleven years, no one else has asked to see it.", material_id = &"survey_film", material = &"event"}},
				{label = "Leave her be", stay = true, effect = func() -> Dictionary:
					return {text = "Yours is the first arrival she has logged in a long while. She logs it carefully, down to the minute."}},
			],
		},
		{
			id = &"counting_backwards",
			title = "Counting backwards",
			subject = {stage = &"single", pick = true, pieces = [&"t3_counting_backwards_a_2", &"t3_counting_backwards_b_1", &"t3_counting_backwards_b_2"], tumble = 2.0},
			body = "A dead relay hangs on the approach with its transponder still working. It sends one number every forty-one years, and each is lower than the last. Your charts hold three of them, logged by three ships across two centuries. The next number it sends will be zero. The relay is precursor work, older than any name anyone has for it. The dish puts that broadcast four days out.",
			tags = [&"signal"],
			group = &"",
			weight = 7,
			min_danger = 9,
			regions = [MapGen.Region.DEEP],
			choices = [
				# No credits out here, nobody pays. Branches hand over objects that become money at
				# a station.
				{label = "Cut the core out",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						return {text = "The cutter opens the housing along a seam the builders left for this. The core comes away still warm, and the grapple moves it into the hold. It keeps counting.", material_id = &"counting_core"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You take it fast and pay for the speed in waste heat, which the radiators will take an hour to shed. The core keeps counting down in the hold.", material_id = &"counting_core"},
					partial = func() -> Dictionary:
						Run.heat += 8
						# `survey_film` is a fixed 35 and the tier ladder cannot reach it, so a
						# rolled wreck material grades depth.
						# Why: docs/why/OptionsPart03.md#named-plus-rolled-payout
						return {text = "Years of heat and cold have welded the housing to its frame, and the cutter cannot free it in time. You take the readings instead: the interval, the bearing and the decay curve, shot onto film straight off the dish. You also take something the cutter shook loose.", material_id = &"survey_film", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Something kept the core warm for two hundred years. When the cutter opened it, it came through the hull.")
						Run.heat += 20
						return {text = "Something has kept that core warm since before there were manufacturers. When the cutter opens it, it comes through the hull, fast and hard."}},
				{label = "Wait out the four days",
					effect = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You hold station for four days on fuel you will want later. On the fourth day the number goes to zero and the transponder stops. After that there is no signal, no light, and no answer from anywhere. Your recording runs six more hours of silence.", material_id = &"last_broadcast"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and leave the relay counting down."}},
			],
		},
		{
			id = &"holding_pattern",
			title = "Holding pattern",
			subject = {stage = &"ring", pieces = [&"role:hauler", &"role:passenger", &"role:barge", &"role:small", &"role:tender", &"role:hauler"], count = 6, near = 0, rx = 165.0, ry = 92.0, spin = 0.0, dark = 0.35},
			body = "Six ships hold a loose ring ahead of you with their drives cold and their transponders on. Their hulls are weathered unevenly, so they arrived years apart. None of them has moved since your dish resolved them. They are not a convoy or a blockade, and all of them point inward. You hail the ring, and the only answer that comes back is a receipt code.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			min_danger = 9,
			regions = [MapGen.Region.DEEP],
			choices = [
				{label = "Sell them the way out", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(30))
					return {text = "They have pointed inward so long that their route is out of date. You send them yours: bearings, what the crossings cost, and which stations are still staffed. They pay warm-economy prices, in credits from somewhere that still has a mint. They do not say what they want it for. Two of them ask for a second copy."}},
				{label = "Read their receipts",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "All six codes come from one issuer, a vault. Their holds read empty, so they have delivered and are waiting to be paid. The oldest code is forty years old. You copy all six to sell further out."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(10))
						return {text = "The codes are vault-issued and run in sequence, so this is an old, orderly queue that someone set up."},
					partial = func() -> Dictionary:
						return {text = "The codes point at a ledger kept somewhere you will never get access to."},
					botched = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You push the nearest transponder hard enough that all six ships answer. They light their drives at once, hold them for four seconds, and go cold again without a word. You burn out of the ring on a heading you did not plan."}},
				{label = "Hold station with them", stay = true, effect = func() -> Dictionary:
					return {text = "You point inward, kill the drives, and sit in the ring for a while. None of the six ships moves. Then you light the drives and go."}},
			],
		},
		{
			id = &"the_favour",
			title = "The favour",
			subject = {stage = &"single", pieces = [&"role:small"], lights = &"run", drive = true},
			body = "A courier is hailing every ship with fuel to spare. Her tank is nearly empty, and her charter pays on arrival, one ring further in than her fuel reaches. She is offering above the going rate for a top-up. If no one sells, she drifts until the people who hired her notice she is late. She is in no danger, but she cannot afford a late delivery.",
			tags = [&"contract"],
			group = &"",
			weight = 13,
			max_danger = 6,
			choices = [
				{label = "Sell her two units", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(20))
					return {text = "You pump two units across. The rate is high for her and good for you. She is moving again before the pump has cooled."}},
				{label = "Sell her three", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					Run.add_credits(OptionTable.purse(36))
					return {text = "Three units is enough for her to arrive with margin. She pays the rate without arguing, so the charter must be worth a lot more."}},
				{label = "Wish her luck", stay = true, effect = func() -> Dictionary:
					return {text = "She thanks you, logs your registry with the others who said no, and goes back to hailing."}},
			],
		},
		{
			id = &"wrong_registry",
			title = "Wrong registry",
			subject = {stage = &"single", pieces = [&"r2_drone_delivery_drone_1"]},
			body = "A delivery drone matches your course and runs a docking handshake older than your ship. It carries a consignment for a registry one digit off yours. That hull may not have flown for decades. The job is long overdue, and the late penalty has run so far it has wrapped around to zero. The drone will keep waiting until someone accepts it.",
			tags = [&"signal"],
			group = &"",
			weight = 12,
			max_danger = 6,
			choices = [
				{label = "Accept the consignment", effect = func() -> Dictionary:
					return {text = "You spoof the digit and the drone unloads. The consignment comes over sealed, addressed, and heavier than it looks. The drone logs the delivery complete and returns to its route.", module = true, material = &"event"}},
				{label = "Correct its registry",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "You give it the right registry off an old dock ledger. That hull was lost before you started flying. The drone thanks you in protocol, releases the parcel it can no longer deliver, and sets course for the wreck.", material = &"event"},
					clean = func() -> Dictionary:
						return {text = "You give it a registry that looks right. It accepts, plots a new route, and leaves you a crate off the back of the consignment.", material = &"event"},
					partial = func() -> Dictionary:
						return {text = "Its check loop politely turns down everything you offer. You break off before it finishes the fourth try."},
					botched = func() -> Dictionary:
						Run.add_credits(-15)
						return {text = "You feed it a bad registry, and it takes you for the ship it was looking for. It bills you for every parcel on its manifest. Then it follows you to the edge of sensor range and waits there."}},
				{label = "Decline the handshake", stay = true, effect = func() -> Dictionary:
					return {text = "It holds formation for exactly one hour, then returns to its route with the parcel."}},
			],
		},
		{
			id = &"dead_station",
			title = "Dead station",
			subject = {stage = &"single", pieces = [&"place_derelict_station"], dark = 0.7, turn = 12.0},
			body = "A station hangs dark and unpowered ahead, turning slightly off true. The docking clamps still hold pressure, so the reactor died slowly and someone shut things down in order. No one is aboard now. The face turning past has open bays with the racks still in them. The tanks are on the far side of the hub, sealed, with a coupling the grapple can work. Getting from one to the other means an hour of holding station against the uneven turn.",
			tags = [&"salvage"], site = &"derelict",
			group = &"",
			weight = 12,
			max_danger = 6,
			choices = [
				{label = "Salvage the racks", effect = func() -> Dictionary:
					return {text = "The grapple pulls a module out of a dead bay and clears the rack around it on the same pass. After all this time, it comes away on the first try.", module = true, material = &"wreck"}},
				{label = "Siphon the tanks", effect = func() -> Dictionary:
					Run.fuel += 2
					return {text = "The tanks give two units of fuel."}},
			],
		},
		{
			id = &"distress_beacon",
			subject = {stage = &"none"},
			title = "Distress beacon",
			body = "A looping voice repeats a set of coordinates one jump off your route. It sounds like a recording that has been running a long time. Whatever is at the far end is sending through a hull big enough to carry a real transmitter. That makes it worth reaching or worth staying well away from, and the recording does not say which.",
			tags = [&"signal", &"fight"], site = &"world",
			group = &"",
			weight = 11,
			max_danger = 6,
			choices = [
				{label = "Answer it", fight = true, effect = func() -> Dictionary:
					return {text = "It was bait. The hull sending it is real and still loaded, worth taking from whoever is using it as a lure. They are already firing at you.", fight = true}},
				{label = "Read it from cover",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "You sit off the coordinates and listen. Under the loop is a second signature, holding station, so this is a trap. You sell the coordinates as a hazard note at the next dock."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "Enough of the carrier comes through to show there is no one alive to rescue. You log it, and the log is worth a little to a buyer."},
					partial = func() -> Dictionary:
						return {text = "You learn only that it repeats every ninety seconds."},
					botched = func() -> Dictionary:
						Run.heat += 8
						return {text = "You hold position too long, and whatever is under the loop gets a good look at you. You leave running hot."}},
				{label = "Run silent", stay = true, effect = func() -> Dictionary:
					Run.heat = 0
					return {text = "You cut the reactor and drift past with everything dark, and your heat drops to nothing."}},
			],
		},
		{
			id = &"whale_fall",
			title = "Whale fall",
			subject = {stage = &"structure", pieces = [&"st_whale_fall"], cluster = {pieces = [&"pool_discs", &"pool_fan"], count = 9, rect = Rect2(110, 120, 220, 160), size = [0.2, 0.4], turns = 35.0, seed = 7}},
			body = "The corpse of something enormous hangs ahead, coming apart slowly and feeding a crowd of smaller animals. Most of them are too small for the dish to read, and a few are bigger than your ship. The carcass is worth taking, and the best of it is in the seams between the ribs. Cutting there means sitting among the feeders for as long as the cut takes. Enough has already come loose to fill a bay, out where nothing is feeding.",
			tags = [&"salvage"], site = &"contact",
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 8,
			needs_fauna = true,
			choices = [
				{label = "Cut into it",
					check = {attr = &"stealth", need = 4},
					met = func() -> Dictionary:
						Run.add_material(&"exotic", 2)
						return {text = "You work the seam slowly, in the lee of the ribs, and come away loaded. None of the feeders pays you any attention.", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.add_material(&"exotic", 2)
						return {text = "You take what you came for. A feeder the size of a hatch cover watches you and leaves you alone."},
					partial = func() -> Dictionary:
						Run.add_material(&"exotic", 1)
						Run.take_hull_damage(OptionTable.toll(3), "A feeder at the whale fall, bigger than your ship, attacked the hull.")
						return {text = "Halfway through the cut, the feeders turn on you as competition. You leave with less than you wanted and a scratched hull."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The feeders at the whale fall came for the hull all at once and did not stop.")
						return {text = "The small feeders all come at you at once, while the big ones keep feeding."}},
				{label = "Take what has come loose", effect = func() -> Dictionary:
					return {text = "You take what has drifted clear of the ribs, enough to fill a bay, and cut nothing.", material = &"fauna"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You hold station a while, take nothing, and leave the carcass to the feeders."}},
			],
		},
		{
			id = &"inspection_sweep",
			title = "Inspection sweep",
			subject = {stage = &"group", ships = [{piece = &"role:hauler", far = true, dark = 0.7, turn = 5.0, at = Vector2(130.0, -75.0), z = -3}, {piece = &"role:hauler", far = true, lights = &"run", at = Vector2(150.0, 15.0), z = -2}, {piece = &"role:passenger", far = true, lights = &"run", at = Vector2(110.0, 70.0), z = -1}, {piece = &"ship_dropship", lights = &"patrol", at = Vector2(-95.0, 5.0), z = 1}]},
			body = "A patrol is stopping everything in this lane because of a hauler parked behind them. They pulled it over two days ago, and its crew abandoned it. Its load sits in the impound under a seizure notice that no one has come to act on. The queue moves slowly. Whatever is still in the impound at the end of the week goes to the breakers.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 8,
			min_security = 3,
			choices = [
				{label = "Wait your turn and bid on the load", cost_credits = 40, effect = func() -> Dictionary:
					# The bid is spent in this effect like other priced choices, as the screen no
					# longer deducts it.
					Run.add_credits(-40)
					var lost := Run.contraband_count()
					if lost > 0:
						Run.add_credits(-20 * lost)
						return {text = "They find what you are carrying and price it into the paperwork. You pay both bills. What is left in the impound is still worth more than the morning cost you.", module = true}
					return {text = "You are clean, so they wave you through, first in line for the impound. You pay the price on the notice.", module = true, material = &"wreck"}},
				{label = "Talk your way to the front",
					check = {attr = &"stealth", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Your registry reads as already cleared for the forty seconds they spend checking it.", module = true},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(17))
						return {text = "You come out of the queue two hours early and take the smaller half of the impound."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "A patrol skiff crowded you off the impound gate.")
						return {text = "They notice, and a patrol skiff crowds you off the gate. The damage is to your paint. You leave with nothing out of the impound."},
					botched = func() -> Dictionary:
						Run.add_credits(-45)
						return {text = "You are fined for trying it, item by item, and made to wait anyway. The impound is empty by the time you get to it."}},
				{label = "Burn away", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					Run.take_hull_damage(OptionTable.toll(2), "You ran the lane, and something clipped you on the way out.")
					return {text = "You run for it. It costs one fuel and a scraped flank, and leaves no record."}},
			],
		},
		{
			id = &"derelict_hauler",
			title = "Derelict hauler",
			subject = {stage = &"single", pieces = [&"r3_frame_gutted_frame_1"], tumble = 1.0},
			body = "An old freight frame drifts ahead, gutted to its structure but still straight. Whoever stripped it took the fittings and left what they were bolted to. That is the opposite of the usual order, so they were in a hurry. What is left is a spine, dry tanks, and the mounts the racks came off. None of it reads bent. Proving the frame will fly takes hours of slow passes and instrument work. Cutting it up is quicker, and plating and wire off a hull this size sell at any yard.",
			tags = [&"salvage"], site = &"derelict",
			group = &"",
			weight = 6,
			max_danger = 6,
			min_danger = 2,
			choices = [
				# The frame is named before you choose and carries the strip's pay, so a flown-
				# other frame still cuts up.
				{label = "Claim the hull",
					label_at = func(n: MapGen.MapNode) -> String:
						return "Claim the %s frame" % HullData.weight_name(OptionTable.derelict_frame(n).weight).to_lower(),
					effect = func() -> Dictionary:
						var here: MapGen.MapNode = Run.node_at()
						Run.find_hull(OptionTable.derelict_frame(here), OptionTable.strip_pay(here, 35))
						return {text = "The frame will fly. You prove it the slow way, with hours of passes and instrument work: %s." % Run.found_hull.display_name()}},
				{label = "Strip it for scrap", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(35))
					return {text = "Your cutter takes off plating and wire worth selling. You leave the frame a little more gutted than you found it.", material = &"wreck"}},
				{label = "Leave the frame", stay = true, effect = func() -> Dictionary:
					return {text = "You log where it is and fly on."}},
			],
		},
		{
			id = &"hostile_contact",
			title = "Hostile contact",
			subject = {stage = &"single", pieces = [&"ship_gunboat"], dark = 0.85, fights = true},
			body = "A hull sits dead ahead of you where the chart shows nothing. Its engines are cold and its running lights are off. It already has your registry, queried before your dish finished resolving its shape. No hail follows, and no demand. It turns slowly until its bow points at you, then holds there and waits for you to act.",
			tags = [&"fight"],
			group = &"",
			weight = 16,
			choices = [
				# `fight` returned is the trigger; `fight` on the choice is a declaration the
				# sector list reads before the click.
				# Why: docs/why/OptionsPart03.md#fight-declaration
				{label = "Engage", fight = true, effect = func() -> Dictionary:
					return {text = "You light the drives and close before it is ready for you. It did not expect you to attack first.", fight = true}},
				{label = "Burn past it", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You put the throttle down and take the long way around the system, watching its bearing. It does not follow or hail, and you never learn what it wanted."}},
			],
		},
		{
			id = &"dead_hull",
			title = "A dead hull",
			subject = {stage = &"single", pieces = [&"role:hauler"], dark = 1.0, turn = 8.0},
			body = "A hull drifts across the lane, cold all the way through: no heat on any band, no beacon, no claim transponder answering. Whatever registry it flew under is not one your dish can reach from here. The airlocks are shut. The racks, on the long-range read, are still full. It has been here long enough that nobody is coming for it.",
			tags = [&"salvage"], site = &"derelict",
			group = &"",
			weight = 14,
			choices = [
				{label = "Strip it", effect = func() -> Dictionary:
					return {text = "You put the grapple on it and cut the racks out through the breach. Whatever killed the crew left the parts, and you take them.", module = true}},
				{label = "Read the log first",
					check = {attr = &"sensors", need = 3},
					met = func() -> Dictionary:
						return {text = "The recorder is intact and names which racks were loaded last and with what. You take the best of those and the crate stowed beside them.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "Enough of the log survives to show the hull has no scuttling charge or scavenger trap. The crew ran out of heat. You strip it at your own pace.", module = true},
					partial = func() -> Dictionary:
						return {text = "The recorder is melted, and the racks are locked to a registry only it held. You take what is drifting loose in the open sections and learn nothing about how the crew died."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Something in the dead hull was still charged.")
						return {text = "A power cell that should have been flat discharges into the bow the moment the panel comes off."}},
			],
		},
		{
			id = &"cordon",
			title = "The cordon",
			subject = {stage = &"group", fights = true, strobe = true, lights = &"run", ships = [{piece = &"ship_gunboat", far = true, at = Vector2(-160.0, -10.0)}, {piece = &"ship_armedtrader", at = Vector2(0.0, 0.0), z = 1}, {piece = &"ship_dropship", far = true, at = Vector2(160.0, -10.0)}]},
			body = "Three ships hold a line across the lane with their weapons live. A strobe runs the width of it. It is a toll. The hail is polite and carries a rate card: one rate for every hull, payable now. Out here there is no one to complain to. The ships on the line know to the hour how far away the nearest help is.",
			tags = [&"fight", &"signal"],
			group = &"",
			weight = 12,
			regions = [MapGen.Region.LAWLESS],
			max_security = 2,
			min_danger = 5,
			choices = [
				{label = "Pay it", cost_credits = 60, effect = func() -> Dictionary:
					Run.add_credits(-60)
					return {text = "You pay the rate, and the strobe drops. You fly the lane end to end without a sensor ping."}},
				{label = "Run it",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						return {text = "You are past the line before the three of them react. Their one shot misses, and the lane costs you nothing."},
					clean = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "They burn after you the moment you commit. You take the lane at full throttle, and the sprint costs fuel."},
					partial = func() -> Dictionary:
						Run.drain_fuel(4)
						return {text = "They close the gap, so you take the wide route at speed. You get through, and it costs four units of fuel."},
					botched = func() -> Dictionary:
						Run.drain_fuel(6)
						return {text = "You cross the lane twice at full burn, the second time for no good reason. In the end they let you go, and the sprint costs a lot of fuel."}},
				{label = "Break it", fight = true, effect = func() -> Dictionary:
					return {text = "You attack the line. They do not expect it, and they are slow to respond.", fight = true}},
			],
		},
		{
			id = &"salvage_rights",
			subject = {layers = [{stage = &"single", pieces = [&"r3_frame_gutted_frame_1"], dark = 0.7, window = [40, 34], at = Vector2(-20.0, -50.0)}, {stage = &"single", pieces = [&"ship_catamaran"], size = 0.5, lights = &"run", at = Vector2(-150.0, 30.0)}, {stage = &"fx", fx = &"moor", from = &"ship_catamaran", from_at = [0, 16], to = &"r3_frame_gutted_frame_1", to_at = [14, 60]}]},
			title = "Salvage rights",
			body = "A wreck lies open along its length, and another crew is already on it. Their cutter ship is anchored at the stern with floods on and gear out. Half the racks are gone. They watched you arrive and did not hail. Out here, salvage belongs to whoever holds the cutter, and they do. The bow section is untouched.",
			tags = [&"salvage", &"contract"], site = &"derelict",
			group = &"wreck",
			weight = 11,
			max_danger = 6,
			regions = [MapGen.Region.LAWLESS, MapGen.Region.TERRITORY],
			min_danger = 2,
			choices = [
				{label = "Work the bow", effect = func() -> Dictionary:
					return {text = "You take the bow while they take the stern, and neither ship speaks. When the good rack comes free, they put their floods on you for a second to show they saw. Then they go back to work.", module = true}},
				{label = "Find what they missed",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(35))
						return {text = "Your dish maps the hull's voids. It finds a sealed transfer hold their cutting line went straight past. Inside is a module, still racked, and a sealed bale of cargo nobody opened. You are gone before they finish the stern.", module = true},
					clean = func() -> Dictionary:
						return {text = "You read the frame, find the one section their floods never swept, and pull a rack out of it clean. They notice and let it go.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Their cut got everything worth mounting. What is left is small and loose. You sweep what you can of it out of the open sections with their floods tracking you the whole time."},
					botched = func() -> Dictionary:
						Run.add_credits(-25)
						return {text = "You cut into the section their anchor line is braced on, and they stop work. You pay them to keep it from becoming a fight, with their floods on your cockpit."}},
				{label = "Leave it to them", stay = true, effect = func() -> Dictionary:
					return {text = "You leave the wreck to them. Their floods follow you out of sensor range."}},
			],
		},
		{
			id = &"still_under_warranty",
			title = "Still under warranty",
			subject = {stage = &"single", pieces = [&"r5_split_derelict_1"], tumble = 1.0},
			body = "A wreck drifts past with a Verity plate still bright on its flank, and something aboard is still live. A service handshake pings you every ninety seconds, the same three tones each time. It asks any passing hull to name itself. The crew that should answer is gone, but the bay has kept asking for a long time.",
			tags = [&"salvage"], site = &"derelict",
			group = &"wreck",
			weight = 6,
			max_danger = 6,
			regions = [MapGen.Region.LAWLESS, MapGen.Region.TERRITORY,
				MapGen.Region.COSMOPOLITAN],
			berth = &"verity",
			choices = [
				{label = "Answer the handshake",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "You answer with your own registry, and the wreck accepts it at once. Service bays cycle open down the flank and release the parts under warranty to you.", module = true},
					clean = func() -> Dictionary:
						return {text = "The handshake takes your registry on the second try. One bay opens, and what is racked inside comes free clean.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "The wreck accepts you, but the bays stay shut. All it will release is the courtesy locker beside the lock. Inside are a few sealed spares with Verity's name on the wrap."},
					botched = func() -> Dictionary:
						Run.add_credits(-15)
						return {text = "The handshake flags your registry as the wrong holder of record. The bay lock arcs the moment your grapple touches it. The scoring down your flank costs credits to make right."}},
				{label = "Strip it regardless", effect = func() -> Dictionary:
					return {text = "You cut the racks out while the handshake keeps pinging every ninety seconds. It is still pinging when you leave.", module = true}},
			],
		},
		{
			id = &"collapsed_lane",
			title = "Collapsed lane",
			subject = {layers = [{stage = &"row", pieces = [&"r3_frame_gutted_frame_1", &"r3_frame_gutted_frame_2"], count = 2, near = 0, mid = 2, gap = 3.0, span = 440.0, dir = Vector2(1.0, -0.06), at = Vector2(0.0, -62.0)}, {stage = &"single", pieces = [&"r3_frame_gutted_frame_2"], at = Vector2(-30.0, 62.0)}]},
			body = "The short way runs through a shipbreaker's yard. It is a lane of dead hulls packed so close the dish reads them as one long wreck. Spars cross the gap at every height, left where they lay when the money stopped. Going around costs a day. Going through costs nothing if nothing touches you, and it saves fuel.",
			tags = [&"hazard"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 6,
			regions = [MapGen.Region.LAWLESS, MapGen.Region.COSMOPOLITAN,
				MapGen.Region.TERRITORY],
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Push through the wrecks",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						Run.fuel += 2
						return {text = "Your plating scrapes the length of the lane and holds. Spars pass close enough to read the breakers' chalk marks. You come out the far side with all the fuel you would have spent going around."},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "A spar in the shipbreaker's lane opened the bow.")
						Run.fuel += 2
						return {text = "Something gives near the bow, but you keep going and keep the fuel. The bow needs repairs later."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A spar went through the forward plating and stayed there.")
						return {text = "Halfway in, a spar goes through the forward plating and sticks. You reverse out the way you came, slowly, with the spar still in the hull."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A dead hull folded the bow in the breaker's lane.")
						return {text = "Two hulls shift and close on you in the lane. Your ship comes out the far side badly damaged."}},
				{label = "Go around", stay = true, effect = func() -> Dictionary:
					return {text = "You take the long way around the yard. The trip is safe, and it costs you a day."}},
			],
		},
		{
			id = &"drifting_lifepod",
			title = "Drifting lifepod",
			subject = {stage = &"single", pieces = [&"r2_lifepod_lifepod_1"], tumble = 14.0},
			body = "A lifepod tumbles across your bow with a weak transponder, fading like a battery that has been dying for months. The viewport is frosted from the inside, so someone is still in there, or was. Another ship has been here first. The lock housing carries a fresh weld that is not part of any pod's design.",
			tags = [&"signal"],
			group = &"",
			weight = 10,
			max_danger = 4,
			choices = [
				{label = "Crack it open", effect = func() -> Dictionary:
					if Rng.event.randf() < 0.6:
						Run.add_credits(OptionTable.purse(25))
						return {text = "You take it on the grapple and cycle the lock from the board. The fresh weld is a scavenger's charge, and it fails to fire. There is no one inside, only cargo you can sell, packed where a person should be."}
					Run.take_hull_damage(OptionTable.toll(5), "The fresh weld on a lifepod was a scavenger trap, and it fired against the hull.")
					return {text = "The fresh weld is a scavenger trap. It fires when the seal breaks and goes off against your hull."}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You let it tumble on. Its transponder is still going, weaker, when it leaves sensor range."}},
			],
		},
	])
	return out
