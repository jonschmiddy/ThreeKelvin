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
			body = "Two armed crews argue over a drifting cargo pod, and its transponder log can settle which one dropped it.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			max_danger = 8,
			choices = [
				{label = "Read the log",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "The smaller ship dropped it, and the bigger one leaves."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "The losing crew argues with you for a while, then gives up."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "The log is older than both ships, so you split the pod three ways."},
					botched = func() -> Dictionary:
						Run.add_credits(-20)
						return {text = "You call it for the wrong ship, and the right one leaves with the pod."}},
				{label = "Snatch the pod", fight = true, effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "You grab the pod, and both crews turn their guns on you.", fight = true, material = &"event"}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "They are still arguing when you leave."}},
			],
		},
		{
			id = &"long_claim",
			title = "The long claim",
			subject = {stage = &"single", pieces = [&"paint_rock_a2"], r = 86.0},
			body = "An unclaimed rock has a mineral seam, and the best of it runs under an overhang that looks ready to fall.",
			tags = [&"contract"], site = &"contact",
			group = &"",
			weight = 9,
			max_danger = 4,
			max_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Cut the seam", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(38))
					return {text = "It takes most of a day and one cutting head.", material = &"mining"}},
				{label = "Cut under the overhang",
					check = {attr = &"hull", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(38))
						return {text = "You take the seam and the shelf under it, and the frame holds.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(38))
						Run.take_hull_damage(OptionTable.toll(3), "The forward bracing cracked under the overhang.")
						return {text = "The forward bracing cracks under the strain, then holds."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						Run.take_hull_damage(OptionTable.toll(5), "A shelf of rock came away and tore off the cutting head.")
						return {text = "The shelf comes away wrong and takes the cutting head with it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "The overhang came down on the bow.")
						return {text = "The overhang comes down on your bow."}},
				{label = "Move on", stay = true, effect = func() -> Dictionary:
					return {text = "You log the seam and go."}},
			],
		},
		{
			id = &"slipping_orbit",
			site = &"giant",
			subject = {layers = [{stage = &"single", pieces = [&"r5_scatter_spar_1"], turn = -14.0, tumble = 1.5, at = Vector2(40.0, -76.0)}, {stage = &"single", pieces = [&"r4_scatter_torn_plate_1"], turn = 10.0, tumble = 2.0, at = Vector2(-84.0, -56.0)}]},
			title = "Slipping orbit",
			body = "A gas giant has pulled you low, and a hard burn could climb out past old wreckage close enough to grapple.",
			tags = [&"hazard"],
			group = &"",
			weight = 10,
			# A GAS GIANT FILLS HALF THE VIEWPORT. It cannot fill half of
			# anything at a system that does not have one.
			needs_giant = true,
			choices = [
				{label = "Burn out hard",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						return {text = "You climb out clean and grapple a spar on the way.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "The engines get you out of the well in the end."},
					partial = func() -> Dictionary:
						Run.drain_fuel(4)
						return {text = "You get out on a long, hard climb."},
					botched = func() -> Dictionary:
						Run.drain_fuel(6)
						return {text = "You skim the atmosphere going up and scorch the paint."}},
				{label = "Orbit once", stay = true, effect = func() -> Dictionary:
					return {text = "You ride one slow orbit and lose the hour."}},
			],
		},
		{
			id = &"mine_drift",
			title = "Mine drift",
			subject = {layers = [{stage = &"single", pieces = [&"role:hauler"], far = true, dark = 0.75, at = Vector2(0.0, -6.0)}, {stage = &"ring", pieces = [&"r2_minedrift_limpet_mine_1", &"r4_minedrift_prong_mine_1", &"r2_minedrift_limpet_mine_2", &"r2_minedrift_prong_mine_2", &"r4_minedrift_prong_mine_2", &"r2_minedrift_limpet_mine_1", &"r4_minedrift_prong_mine_1"], count = 7, near = 0, rx = 150.0, ry = 62.0, spin = 0.3, roll = 8.0, roll_step = 15.0, at = Vector2(0.0, -6.0)}, {stage = &"field", pieces = [&"r4_minedrift_buckled_plate_1", &"r2_minedrift_broken_strut_2"], count = 2, near = 2, span = 430.0, height = 240.0, seed = 21, tumble = 4.0, turns = 30.0}]},
			body = "Old mines guard the way to an opened wreck with a module in reach of the grapple.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 5,
			choices = [
				{label = "Thread the mines",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						return {text = "You fly through clean and lift the module.", module = true},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "A mine hit the flank on the way out.")
						return {text = "One mine hits your flank on the way out."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Three mines hit near the edge of the drift.")
						return {text = "Two mines hit, then a third, and you back out."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "An old mine fired late and hit from behind.")
						return {text = "An old mine fires late and hits you from behind."}},
				{label = "Go around wide", stay = true, effect = func() -> Dictionary:
					return {text = "You give the drift a wide margin."}},
			],
		},
		{
			id = &"corona",
			site = &"star",
			subject = {stage = &"single", pieces = [&"ship_cl_stack"], dark = 0.75, bake = 0.9, at = Vector2(40.0, 10.0)},
			title = "The corona",
			body = "A wreck close to a flaring star has a crust of slag and full holds, if your vents can carry the heat.",
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
						return {text = "Your vents hold, and you take a plate of star slag and a rack.", material_id = &"corona_amber", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You take one rack off the wreck before the heat drives you out.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "The heat climbs too fast, and you back off with nothing."},
					botched = func() -> Dictionary:
						Run.heat += 20
						return {text = "The flare comes early, and you leave with nothing."}},
				{label = "Log the wreck", stay = true, effect = func() -> Dictionary:
					return {text = "You log the wreck for a ship with better vents."}},
			],
		},
		{
			id = &"the_wind",
			site = &"star",
			subject = {stage = &"fx", fx = &"wind"},
			title = "The wind",
			body = "A fast gas front from the blue hypergiant crosses here, carrying a ship side on but spinning one caught bow first.",
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
						return {text = "You turn side on and let the front carry you."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						return {text = "You catch the edge of the front and idle across."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						Run.heat += 5
						return {text = "You catch it badly and spend the crossing correcting."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "A gas front took the bow and turned the ship sideways.")
						return {text = "The front takes the bow first and turns the whole ship sideways."}},
				{label = "Burn across it", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You cross the front at an angle under power."}},
				{label = "Wait it out", stay = true, effect = func() -> Dictionary:
					return {text = "You hold position for a shift until the front has passed."}},
			],
		},
		{
			id = &"the_glare",
			site = &"star",
			subject = {layers = [{stage = &"fx", fx = &"glare", reach = 340.0}, {stage = &"single", pieces = [&"ship_lrshuttle"], dark = 1.0, silhouette = 0.9, at = Vector2(60.0, -10.0)}]},
			title = "The glare",
			body = "A blue hypergiant whites out your dish, and its last clean sweep showed a ship-sized contact holding still.",
			tags = [&"hazard"],
			group = &"",
			weight = 7,
			min_danger = 5,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Fly the last bearing",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						return {text = "The contact is an untouched wreck, and the grapple takes a module and a crate.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You find it on the third pass and take a module.", module = true},
					partial = func() -> Dictionary:
						return {text = "The contact has moved, but you take a piece that came off it.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 8
						return {text = "You spend an hour in the glare and never find it."}},
				{label = "Sweep the shadow side", effect = func() -> Dictionary:
					return {text = "In a rock's shadow you find a smaller piece of drift.", material = &"wreck"}},
				{label = "Log it and go", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and take the long way in."}},
			],
		},
		{
			id = &"the_scouring",
			title = "The scouring",
			subject = {stage = &"single", pieces = [&"place_derelict"], turn = 4.0},
			body = "A blue hypergiant's wind has stripped a wreck to bare frame and fittings, and it wears your plating while you work.",
			tags = [&"hazard", &"salvage"], site = &"derelict",
			group = &"",
			weight = 7,
			min_danger = 5,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Work it long",
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						return {text = "You stay four hours and take a module and a reactor housing.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "Three hours beside a blue hypergiant wore through the plating.")
						return {text = "You take one module in three hours.", module = true},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Stayed beside a blue hypergiant until it cut into the frame.")
						return {text = "You take one module before your plating readings start to drop.", module = true},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Stayed too long beside a blue hypergiant.")
						return {text = "You stay too long and leave with nothing."}},
				{label = "Take what is loose", effect = func() -> Dictionary:
					return {text = "You take one piece the wind has already stripped loose.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You leave the wreck to the wind."}},
			],
		},
		{
			id = &"the_runner",
			title = "The runner",
			subject = {stage = &"single", pieces = [&"role:small"], lights = &"run"},
			body = "A pilot needs an unmarked parcel hidden aboard and can pay little, but she was told the buyer pays well.",
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
						return {text = "It goes behind the coolant run, where no scan reaches.", place = &"paid_in_full"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "You find a place for it that will pass an ordinary search.", place = &"paid_in_full"},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "You stow it where a real search would find it.", place = &"paid_in_full"},
					botched = func() -> Dictionary:
						return {text = "A patrol sweeps the dock before you stow it, and she takes the parcel back."}},
				{label = "Ask what it is", stay = true, effect = func() -> Dictionary:
					return {text = "She tells you something, and you cannot tell if it is true."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "She asks the next ship along the dock."}},
			],
		},
		{
			# Placed, never rolled, and ungrouped on purpose: an auction must not foreclose a
			# consequence.
			id = &"paid_in_full",
			title = "Paid in full",
			subject = {stage = &"structure", pick = true, pieces = [&"st_dock_face_1", &"st_dock_face_2", &"st_dock_face_3", &"st_dock_face_4"], add_lights = [{at = "collar", off = [-2, 0], r = 12, col = "#ffcf7a", kind = "breathe", period = 6.0, k = 1.8, cone = 90, cone_k = 0.8}]},
			body = "An old pilot has waited eleven days at this dock for the parcel, and he asks whether she looked well.",
			tags = [&"quest"],
			group = &"",
			placed = true,
			# Row in the QUESTS table (`QuestLog`); the note matches the body word for word
			# (`QuestLogTest`).
			# Why: docs/why/OptionsPart01.md#quest-table-row
			quest = {task = "Deliver the runner's parcel", tag = "DELIVER", from = &"the_runner",
				note = "A pilot needs an unmarked parcel hidden aboard"},
			weight = 0,
			choices = [
				# No failing band: `batch-03` ruled that taxing an earned reward teaches players to
				# refuse the offer.
				{label = "Take the money", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "He pays in cash and thanks you."}},
				{label = "Say she looked tired", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "He nods for a long time and adds a module to the payment.", module = true}},
			],
		},
		{
			# Pickup for a signed fetch, placed by `Contracts.post_goal`, per ship, and never
			# rolled.
			id = &"job_pickup",
			title = "Contract pickup",
			subject = {stage = &"single", pieces = [&"r4_pod_cargo_pod_1"], tumble = 2.0},
			body = "The sealed cargo pod you signed to fetch is parked here, its beacon sending your contract's code.",
			tags = [&"quest"],
			group = &"",
			placed = true,
			job = true,
			weight = 0,
			choices = [
				{label = "Bring it aboard", effect = func() -> Dictionary:
					var who := Contracts.payer_here(ContractData.Kind.FETCH)
					Run.reach_contract_target(Run.at)
					return {text = "The pod locks to the frame outside the hold, and any %s yard will pay for it." % who}},
				{label = "Leave it for now", stay = true, effect = func() -> Dictionary:
					return {text = "The beacon keeps sending, and the job stays open."}},
			],
		},
		{
			# Hunt target, same way. The kill readies it (`Combat._victory`); fleeing posts it
			# again.
			id = &"job_target",
			title = "Contract target",
			subject = {stage = &"single", pieces = [&"ship_gunboat"], dark = 0.85},
			body = "The dark ship from your contract sits here with its bow turned toward you.",
			tags = [&"quest", &"fight"],
			group = &"",
			placed = true,
			job = true,
			weight = 0,
			choices = [
				{label = "Engage", fight = true, effect = func() -> Dictionary:
					return {text = "You close and open fire.", fight = true}},
				{label = "Leave it for now", stay = true, effect = func() -> Dictionary:
					return {text = "It holds where it is, and the job stays open."}},
			],
		},
		{
			id = &"ghost_signal",
			subject = {stage = &"none"},
			title = "Ghost signal",
			body = "A fixed signal comes from a blank spot on the chart, and full dish power may chase your reactor's echo instead.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			max_danger = 4,
			max_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Resolve it",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "It is an old precursor beacon, and the grapple takes its housing.", material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "The beacon's housing is fused on, so you take its readings on film.", material_id = &"survey_film"},
					partial = func() -> Dictionary:
						return {text = "After an hour it turns out to be your own reactor's echo."},
					botched = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You chase it a long way before you accept it was never there."}},
				{label = "Log it and go", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing for a ship with a better dish."}},
			],
		},
		{
			id = &"customs_cordon",
			title = "Customs cordon",
			subject = {stage = &"group", ships = [{piece = &"role:hauler", dark = 0.7, at = Vector2(10.0, 50.0), z = 0}, {piece = &"ship_catamaran", fights = true, lights = &"patrol", at = Vector2(-5.0, -45.0), z = 1}, {piece = &"role:armed", fights = true, size = 0.5, dark = 0.6, at = Vector2(-168.0, -40.0), z = 1}, {piece = &"role:armed", fights = true, size = 0.5, dark = 0.6, at = Vector2(165.0, -48.0), z = 1}]},
			body = "A customs patrol guards a seized hull with two escorts, and the hull's public manifest lists what is still aboard.",
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
						return {text = "You cross cold and silent and take a module unseen.", module = true},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "The reactor runs hot while you take a module unseen.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(-40)
						return {text = "They catch a partial return and fine you before you reach the hull."},
					botched = func() -> Dictionary:
						Run.add_credits(-40)
						return {text = "They light you up, fine you, and send the escorts in.", fight = true}},
				{label = "Ask what they guard", stay = true, effect = func() -> Dictionary:
					return {text = "They tell you what they guard, and the hold stays sealed."}},
			],
		},
		{
			id = &"the_braid",
			title = "The braid",
			subject = {layers = [{stage = &"field", flip = true, pieces = [&"r2_braid_the_braid_idea2", &"r2_braid_the_braid_idea3", &"r2_braid_the_braid_idea2"], count = 3, near = 0, deep = 1, span = 440.0, height = 120.0, seed = 3, tumble = 0.0, at = Vector2(0.0, -64.0)}, {stage = &"single", flip = true, pieces = [&"r2_braid_the_braid_idea3"], at = Vector2(40.0, 62.0)}]},
			body = "Nine leviathans pass in a line without watching for ships, and their wake could carry you a long way.",
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
						return {text = "You slot in behind the third one, and it never notices."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						return {text = "You hold the wake most of the way."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "You drop in late and fight the wash the whole way."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A leviathan's flank tore off the dorsal plating.")
						return {text = "The fourth one turns out of line, and its flank tears off your plating."}},
				{label = "Take what they shed", effect = func() -> Dictionary:
					return {text = "You collect a piece of shed hide and a module off some ship.", module = true, material_id = &"hide_scrap"}},
				{label = "Let them pass", stay = true, effect = func() -> Dictionary:
					return {text = "You wait while the nine of them pass."}},
			],
		},
	])
	return out
