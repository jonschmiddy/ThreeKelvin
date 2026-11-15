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
			body = "The deepest lit dock has one clerk, fuel at prices eleven years old, and a thick folder she calls the observations.",
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
				{label = "Buy her cheap fuel", cost_credits = 4, effect = func() -> Dictionary:
					Run.add_credits(-4)
					Run.fuel += 6
					return {text = "She stamps your receipt twice, once for a copy nobody collects."}},
				{label = "Copy the folder", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You film other crews' notes on the core, and she adds one thing from her stores.", material_id = &"survey_film", material = &"event"}},
				{label = "Leave her be", stay = true, effect = func() -> Dictionary:
					return {text = "She logs your arrival down to the minute."}},
			],
		},
		{
			id = &"counting_backwards",
			title = "Counting backwards",
			subject = {stage = &"single", pick = true, pieces = [&"t3_counting_backwards_a_2", &"t3_counting_backwards_b_1", &"t3_counting_backwards_b_2"], tumble = 2.0},
			body = "An old dead relay sends a lower number every forty-one years, and in four days it will send zero.",
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
						return {text = "The core comes out along a seam left for it, warm and still counting.", material_id = &"counting_core"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You cut it out fast and hot, and it keeps counting in the hold.", material_id = &"counting_core"},
					partial = func() -> Dictionary:
						Run.heat += 8
						# `survey_film` is a fixed 35 and the tier ladder cannot reach it, so a
						# rolled wreck material grades depth.
						# Why: docs/why/OptionsPart03.md#named-plus-rolled-payout
						return {text = "The housing is welded shut, so you film the readings and take one loose piece.", material_id = &"survey_film", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A relay core came through the hull when it was cut open.")
						Run.heat += 20
						return {text = "Whatever kept the core warm comes through the hull."}},
				{label = "Wait four days",
					effect = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You record it sending zero on the fourth day, then nothing.", material_id = &"last_broadcast"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and leave it counting."}},
			],
		},
		{
			id = &"holding_pattern",
			title = "Holding pattern",
			subject = {stage = &"ring", pieces = [&"role:hauler", &"role:passenger", &"role:barge", &"role:small", &"role:tender", &"role:hauler"], count = 6, near = 0, rx = 165.0, ry = 92.0, spin = 0.0, dark = 0.35},
			body = "Six ships with cold drives sit in a ring facing inward, and their transponders send back only receipt codes.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			min_danger = 9,
			regions = [MapGen.Region.DEEP],
			choices = [
				{label = "Sell them your route", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(30))
					return {text = "They pay for your route, and two of them want a second copy."}},
				{label = "Read their receipts",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "One vault owes all six, the oldest for forty years, and you copy the codes to sell."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(10))
						return {text = "The codes run in order from one vault, an old queue."},
					partial = func() -> Dictionary:
						return {text = "The codes point at a ledger you cannot reach."},
					botched = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "All six light their drives at once, and you burn out of the ring fast."}},
				{label = "Wait with them", stay = true, effect = func() -> Dictionary:
					return {text = "None of the six moves while you sit in the ring."}},
			],
		},
		{
			id = &"the_favour",
			title = "The favour",
			subject = {stage = &"single", pieces = [&"role:small"], lights = &"run", drive = true},
			body = "A courier short of fuel will pay above the going rate for a top-up so her delivery is not late.",
			tags = [&"contract"],
			group = &"",
			weight = 13,
			max_danger = 6,
			choices = [
				{label = "Sell two units", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(20))
					return {text = "She is moving again before the pump cools."}},
				{label = "Sell three units", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					Run.add_credits(OptionTable.purse(36))
					return {text = "Three units gets her there with fuel to spare."}},
				{label = "Wish her luck", stay = true, effect = func() -> Dictionary:
					return {text = "She logs your registry with the others who said no."}},
			],
		},
		{
			id = &"wrong_registry",
			title = "Wrong registry",
			subject = {stage = &"single", pieces = [&"r2_drone_delivery_drone_1"]},
			body = "A delivery drone has a late parcel for a ship one digit off yours and waits for someone to take it.",
			tags = [&"signal"],
			group = &"",
			weight = 12,
			max_danger = 6,
			choices = [
				{label = "Take the parcel", effect = func() -> Dictionary:
					return {text = "You spoof the digit, and the drone unloads a module and a crate.", module = true, material = &"event"}},
				{label = "Correct its registry",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "The real owner is long lost, so the drone gives you one parcel.", material = &"event"},
					clean = func() -> Dictionary:
						return {text = "It takes a registry that looks right and leaves you a crate.", material = &"event"},
					partial = func() -> Dictionary:
						return {text = "Its check loop turns down everything you offer."},
					botched = func() -> Dictionary:
						Run.add_credits(-15)
						return {text = "It takes you for its customer and bills you for the whole manifest."}},
				{label = "Decline the handshake", stay = true, effect = func() -> Dictionary:
					return {text = "It holds formation for an hour, then leaves with the parcel."}},
			],
		},
		{
			id = &"dead_station",
			title = "Dead station",
			subject = {stage = &"single", pieces = [&"place_derelict_station"], dark = 0.7, turn = 12.0},
			body = "A dark station turns off true, with racks in its open bays and sealed tanks on the far side of the hub.",
			tags = [&"salvage"], site = &"derelict",
			group = &"",
			weight = 12,
			max_danger = 6,
			choices = [
				{label = "Salvage the racks", effect = func() -> Dictionary:
					return {text = "The grapple pulls a module and one more piece from a dead bay.", module = true, material = &"wreck"}},
				{label = "Siphon the tanks", effect = func() -> Dictionary:
					Run.fuel += 2
					return {text = "The coupling still works, and the fuel pumps across."}},
			],
		},
		{
			id = &"distress_beacon",
			subject = {stage = &"none"},
			title = "Distress beacon",
			body = "A looped recording comes from a big hull one jump off your route, which could be a prize or someone's trap.",
			tags = [&"signal", &"fight"], site = &"world",
			group = &"",
			weight = 11,
			max_danger = 6,
			choices = [
				{label = "Answer it", fight = true, effect = func() -> Dictionary:
					return {text = "It is bait, and whoever waits at the hull opens fire.", fight = true}},
				{label = "Read it from cover",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "A second ship waits under the loop, and you sell word of the trap."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "No one is alive to rescue, and a buyer takes your log."},
					partial = func() -> Dictionary:
						return {text = "All you learn is that it loops every ninety seconds."},
					botched = func() -> Dictionary:
						Run.heat += 8
						return {text = "Whatever waits under the loop sees you, and you leave running hot."}},
				{label = "Run silent", stay = true, effect = func() -> Dictionary:
					Run.heat = 0
					return {text = "You drift past with the reactor cut and everything dark."}},
			],
		},
		{
			id = &"whale_fall",
			title = "Whale fall",
			subject = {stage = &"structure", pieces = [&"st_whale_fall"], cluster = {pieces = [&"pool_discs", &"pool_fan"], count = 9, rect = Rect2(110, 120, 220, 160), size = [0.2, 0.4], turns = 35.0, seed = 7}},
			body = "A dead leviathan feeds a crowd of animals, some bigger than your ship, and the best of it lies among them.",
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
						return {text = "You cut in the lee of the ribs, and no feeder notices.", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.add_material(&"exotic", 2)
						return {text = "A feeder the size of a hatch watches you and leaves you alone."},
					partial = func() -> Dictionary:
						Run.add_material(&"exotic", 1)
						Run.take_hull_damage(OptionTable.toll(3), "A feeder bigger than the ship attacked the hull.")
						return {text = "Halfway through the cut, the feeders turn on you as competition."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The feeders at a dead leviathan came all at once.")
						return {text = "The small feeders come at you all at once."}},
				{label = "Take the loose pieces", effect = func() -> Dictionary:
					return {text = "You take one piece that drifted clear of the ribs.", material = &"fauna"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You leave the carcass to the feeders."}},
			],
		},
		{
			id = &"inspection_sweep",
			title = "Inspection sweep",
			subject = {stage = &"group", ships = [{piece = &"role:hauler", far = true, dark = 0.7, turn = 5.0, at = Vector2(130.0, -75.0), z = -3}, {piece = &"role:hauler", far = true, lights = &"run", at = Vector2(150.0, 15.0), z = -2}, {piece = &"role:passenger", far = true, lights = &"run", at = Vector2(110.0, 70.0), z = -1}, {piece = &"ship_dropship", lights = &"patrol", at = Vector2(-95.0, 5.0), z = 1}]},
			body = "A patrol is searching a slow line of ships, and a seized hauler's load sits in its impound for bids.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 8,
			min_security = 3,
			choices = [
				{label = "Queue and bid", cost_credits = 40, effect = func() -> Dictionary:
					# The bid is spent in this effect like other priced choices, as the screen no
					# longer deducts it.
					Run.add_credits(-40)
					var lost := Run.contraband_count()
					if lost > 0:
						Run.add_credits(-20 * lost)
						return {text = "They find your contraband and fine you, but you still get a module.", module = true}
					return {text = "You are clean, so you get first pick of the impound.", module = true, material = &"wreck"}},
				{label = "Talk your way ahead",
					check = {attr = &"stealth", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Your registry reads as cleared, and you get a module.", module = true},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(17))
						return {text = "You leave the queue early with the smaller half of the impound."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "A patrol skiff crowded you off the impound gate.")
						return {text = "A patrol skiff crowds you off the gate, and you get nothing."},
					botched = func() -> Dictionary:
						Run.add_credits(-45)
						return {text = "They fine you item by item, and the impound is empty when you get through."}},
				{label = "Burn away", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					Run.take_hull_damage(OptionTable.toll(2), "Clipped by something while running from a patrol.")
					return {text = "You run, and something clips your flank on the way out."}},
			],
		},
		{
			id = &"derelict_hauler",
			title = "Derelict hauler",
			subject = {stage = &"single", pieces = [&"r3_frame_gutted_frame_1"], tumble = 1.0},
			body = "Someone stripped this freight frame in a hurry, and it might fly after hours of checks or sell to buyers as scrap.",
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
						return {text = "Hours of passes prove the frame will fly: %s." % Run.found_hull.display_name()}},
				{label = "Strip it for scrap", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(35))
					return {text = "Your cutter takes plating and wire to sell, and one part worth keeping.", material = &"wreck"}},
				{label = "Leave the frame", stay = true, effect = func() -> Dictionary:
					return {text = "You log it and fly on."}},
			],
		},
		{
			id = &"hostile_contact",
			title = "Hostile contact",
			subject = {stage = &"single", pieces = [&"ship_gunboat"], dark = 0.85, fights = true},
			body = "A dark, uncharted hull has queried your registry and turned its bow toward you.",
			tags = [&"fight"],
			group = &"",
			weight = 16,
			choices = [
				# `fight` returned is the trigger; `fight` on the choice is a declaration the
				# sector list reads before the click.
				# Why: docs/why/OptionsPart03.md#fight-declaration
				{label = "Engage", fight = true, effect = func() -> Dictionary:
					return {text = "You close before it is ready.", fight = true}},
				{label = "Burn past it", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You take the long way around the system, and it does not follow."}},
			],
		},
		{
			id = &"dead_hull",
			title = "A dead hull",
			subject = {stage = &"single", pieces = [&"role:hauler"], dark = 1.0, turn = 8.0},
			body = "A cold hull with no beacon drifts here, its airlocks shut and its racks still full.",
			tags = [&"salvage"], site = &"derelict",
			group = &"",
			weight = 14,
			choices = [
				{label = "Strip it", effect = func() -> Dictionary:
					return {text = "The grapple cuts a module out through the breach.", module = true}},
				{label = "Read the log first",
					check = {attr = &"sensors", need = 3},
					met = func() -> Dictionary:
						return {text = "The recorder shows the last racks loaded, and you take the best module and a crate.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "The log shows no trap, so you take a module at your own pace.", module = true},
					partial = func() -> Dictionary:
						return {text = "The recorder is melted, and the racks stay locked."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Something in the dead hull was still charged.")
						return {text = "A power cell that should be flat discharges into the bow."}},
			],
		},
		{
			id = &"cordon",
			title = "The cordon",
			subject = {stage = &"group", fights = true, strobe = true, lights = &"run", ships = [{piece = &"ship_gunboat", far = true, at = Vector2(-160.0, -10.0)}, {piece = &"ship_armedtrader", at = Vector2(0.0, 0.0), z = 1}, {piece = &"ship_dropship", far = true, at = Vector2(160.0, -10.0)}]},
			body = "Three armed ships charge every passing hull a toll, and no help is anywhere near.",
			tags = [&"fight", &"signal"],
			group = &"",
			weight = 12,
			regions = [MapGen.Region.LAWLESS],
			max_security = 2,
			min_danger = 5,
			choices = [
				{label = "Pay it", cost_credits = 60, effect = func() -> Dictionary:
					Run.add_credits(-60)
					return {text = "They let you through, and nobody pings you the rest of the way."}},
				{label = "Run it",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						return {text = "You are past before they react, and their one shot misses."},
					clean = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "They burn after you, and you outrun them at full throttle."},
					partial = func() -> Dictionary:
						Run.drain_fuel(4)
						return {text = "They close the gap, so you take the wide way around at speed."},
					botched = func() -> Dictionary:
						Run.drain_fuel(6)
						return {text = "You make two full-burn passes before they let you go."}},
				{label = "Break it", fight = true, effect = func() -> Dictionary:
					return {text = "You hit the line before they are ready.", fight = true}},
			],
		},
		{
			id = &"salvage_rights",
			subject = {layers = [{stage = &"single", pieces = [&"r3_frame_gutted_frame_1"], dark = 0.7, window = [40, 34], at = Vector2(-20.0, -50.0)}, {stage = &"single", pieces = [&"ship_catamaran"], size = 0.5, lights = &"run", at = Vector2(-150.0, 30.0)}, {stage = &"fx", fx = &"moor", from = &"ship_catamaran", from_at = [0, 16], to = &"r3_frame_gutted_frame_1", to_at = [14, 60]}]},
			title = "Salvage rights",
			body = "Another crew holds the salvage right on this wreck and is cutting its stern, but the bow is untouched.",
			tags = [&"salvage", &"contract"], site = &"derelict",
			group = &"wreck",
			weight = 11,
			max_danger = 6,
			regions = [MapGen.Region.LAWLESS, MapGen.Region.TERRITORY],
			min_danger = 2,
			choices = [
				{label = "Work the bow", effect = func() -> Dictionary:
					return {text = "Neither crew talks, and they flash their floods when your module comes free.", module = true}},
				{label = "Find what they missed",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(35))
						return {text = "Your dish finds a sealed hold they missed, with a module and a bale of cargo.", module = true},
					clean = func() -> Dictionary:
						return {text = "You pull a module from the one section their floods missed.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Only small pieces are left, and you sweep them up under their floods."},
					botched = func() -> Dictionary:
						Run.add_credits(-25)
						return {text = "You cut into their anchor brace and pay them to avoid a fight."}},
				{label = "Leave it to them", stay = true, effect = func() -> Dictionary:
					return {text = "Their floods follow you out of range."}},
			],
		},
		{
			id = &"still_under_warranty",
			title = "Still under warranty",
			subject = {stage = &"single", pieces = [&"r5_split_derelict_1"], tumble = 1.0},
			body = "A Verity wreck still has one live service bay, and it pings any passing ship to name itself as the owner.",
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
						return {text = "The wreck accepts your registry, and a bay releases a module.", module = true},
					clean = func() -> Dictionary:
						return {text = "It takes your registry on the second try, and one bay opens.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "Only the side locker opens, and you sell the Verity spares in it."},
					botched = func() -> Dictionary:
						Run.add_credits(-15)
						return {text = "It flags you as the wrong owner, and the lock arcs down your flank."}},
				{label = "Strip it anyway", effect = func() -> Dictionary:
					return {text = "You cut out a module while the bay keeps pinging.", module = true}},
			],
		},
		{
			id = &"collapsed_lane",
			title = "Collapsed lane",
			subject = {layers = [{stage = &"row", pieces = [&"r3_frame_gutted_frame_1", &"r3_frame_gutted_frame_2"], count = 2, near = 0, mid = 2, gap = 3.0, span = 440.0, dir = Vector2(1.0, -0.06), at = Vector2(0.0, -62.0)}, {stage = &"single", pieces = [&"r3_frame_gutted_frame_2"], at = Vector2(-30.0, 62.0)}]},
			body = "The short way through a shipbreaker's yard of dead hulls and loose spars saves fuel, and going around costs a day.",
			tags = [&"hazard"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 6,
			regions = [MapGen.Region.LAWLESS, MapGen.Region.COSMOPOLITAN,
				MapGen.Region.TERRITORY],
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Push through",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						Run.fuel += 2
						return {text = "Your plating scrapes the whole way through and holds."},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "A spar in a breaker's yard opened the bow.")
						Run.fuel += 2
						return {text = "Something gives near the bow, but you get through."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A spar went through the forward plating and stayed there.")
						return {text = "A spar goes through the forward plating, and you back out."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A dead hull folded the bow in a breaker's yard.")
						return {text = "Two dead hulls shift and close on your bow."}},
				{label = "Go around", stay = true, effect = func() -> Dictionary:
					return {text = "You take the long way around the yard."}},
			],
		},
		{
			id = &"drifting_lifepod",
			title = "Drifting lifepod",
			subject = {stage = &"single", pieces = [&"r2_lifepod_lifepod_1"], tumble = 14.0},
			body = "A lifepod with a frosted window and a dying beacon tumbles past, and someone has put a fresh weld on its lock.",
			tags = [&"signal"],
			group = &"",
			weight = 10,
			max_danger = 4,
			choices = [
				{label = "Crack it open", effect = func() -> Dictionary:
					if Rng.event.randf() < 0.6:
						Run.add_credits(OptionTable.purse(25))
						return {text = "The weld fails to fire, and the pod holds cargo where a person should be."}
					Run.take_hull_damage(OptionTable.toll(5), "A lifepod's lock was rigged to blow.")
					return {text = "The weld is a scavenger's charge, and it goes off against your hull."}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You let it tumble on."}},
			],
		},
	])
	return out
