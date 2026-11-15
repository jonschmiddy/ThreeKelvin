class_name OptionsPart04

## Encounters 50 to 62 of the authored table (`the_dust_cloud` to `lost_in_the_gas`), in the order `OptionTable._authored`
## joins them: `roll_for` draws by table order, so entries never move between or within files.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{
			id = &"the_dust_cloud",
			site = &"star",
			subject = {layers = [{stage = &"fx", fx = &"dust", warm = true, at = Vector2(40.0, -6.0), radii = Vector2(235.0, 118.0), tilt = -8.0, dens = 0.9}, {stage = &"single", pieces = [&"ship_scoop"], dark = 0.8, dust = 0.6, at = Vector2(40.0, 12.0)}]},
			title = "The dust cloud",
			body = "A dead mining ship sits in a cloud of warm star dust that coats radiators.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 4,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Pull the ship out",
					check = {attr = &"thrust", need = 5},
					met = func() -> Dictionary:
						return {text = "The ship comes clear of the cloud, and its holds open for the cutter.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You pull it out fast, and the dust coats every radiator you have.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 10
						return {text = "It shifts, then settles back into the cloud."},
					botched = func() -> Dictionary:
						Run.heat += 16
						Run.take_hull_damage(OptionTable.toll(4), "Star dust clogged the intakes.")
						return {text = "It comes free all at once, and a slab of crust goes into your intakes."}},
				{label = "Scoop the dust", effect = func() -> Dictionary:
					Run.heat += 9
					return {text = "The hold fills with fine metal while the ship heats.", material = &"mining"}},
				{label = "Go around", stay = true, effect = func() -> Dictionary:
					return {text = "You go around the cloud."}},
			],
		},
		{
			id = &"the_water_stop",
			title = "The water stop",
			subject = {stage = &"field", pieces = [&"r5_tank_pressure_tank_1", &"r4_tank_pressure_tank_2", &"r5_tank_pressure_tank_2", &"r5_tank_pressure_tank_1"], count = 4, near = 2, turns = 14.0, span = 400.0, height = 170.0, seed = 15, tumble = 2.0},
			body = "Two people's water plant has no engine and is sinking toward the star, and they want a tow.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Tow them out",
					check = {attr = &"thrust", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "A forty-minute burn puts the plant back in its old orbit."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "The tow runs long but leaves them high enough for now."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(7))
						return {text = "The line slips with the plant higher but not yet safe."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A water plant swung into the ship towing it.")
						return {text = "The line goes tight off center, and the plant swings into your side."}},
				{label = "Sell them fuel", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(18))
					return {text = "They will burn it slowly and climb out on their own."}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "Their orbit gives them a few months yet."}},
			],
		},
		{
			id = &"the_lit_side",
			title = "The lit side",
			subject = {stage = &"single", pieces = [&"r5_split_derelict_1"]},
			body = "A dead freighter's lit side is glazed with baked dust worth cutting in full light, and its cold side holds plain cargo.",
			tags = [&"salvage"], site = &"derelict",
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Cut the glaze",
					check = {attr = &"thermal", need = 6},
					met = func() -> Dictionary:
						return {text = "You take one warm plate of glaze with decades of layers in order.", material_id = &"corona_amber"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "The vents fall behind, and the last plate brings a strip of hull with it.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 14
						return {text = "The glaze is welded on, and the cutter only heats the ship."},
					botched = func() -> Dictionary:
						Run.heat += 22
						Run.take_hull_damage(OptionTable.toll(5), "Stayed too long in the full light.")
						return {text = "You stay ten minutes too long, and systems fail one by one from the lit side."}},
				{label = "Work the cold side", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You hold in its shadow for an hour and cut out a crate of cargo.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log where it is and go."}},
			],
		},
		{
			id = &"paying_for_shade",
			title = "Paying for shade",
			subject = {stage = &"single", pieces = [&"paint_rock_a1"], r = 96.0},
			body = "A flare is ninety minutes out, and two ships charge for spots in the only shade, with old salvage behind them.",
			tags = [&"hazard"],
			group = &"",
			weight = 10,
			min_danger = 5,
			max_danger = 6,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Pay for a spot", cost_credits = 45, effect = func() -> Dictionary:
					Run.add_credits(-45)
					return {text = "You sit out the flare, and no one minds you taking a piece of loose plate.", material = &"wreck"}},
				{label = "Sneak into the shade",
					check = {attr = &"stealth", need = 6},
					met = func() -> Dictionary:
						return {text = "No one spots you among the dead ships, and you leave with a piece of one.", material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You hold a poor spot half in the light, and something small drifts against the hull.", material = &"event"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "The shadow's edge moves faster than you do, and a third of the ship sits in the light."},
					botched = func() -> Dictionary:
						Run.heat += 18
						Run.take_hull_damage(OptionTable.toll(5), "Pushed out of the shade into a flare.")
						return {text = "They find you and keep a light on you until you leave into the flare."}},
				{label = "Go before it hits", stay = true, effect = func() -> Dictionary:
					return {text = "You clear the inner system before the readings climb."}},
			],
		},
		{
			id = &"the_century_log",
			site = &"star",
			subject = {stage = &"single", pieces = [&"ship_science"], size = 0.5, dark = 0.7, bake = 0.5, lights = &"shaded", at = Vector2(-110.0, -80.0)},
			title = "The century log",
			body = "A machine cooking in a close orbit holds a hundred years of readings on this star that would sell.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 8,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Pull the readings",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						return {text = "You pull all hundred years in one pass, and the grapple takes its instrument head.", module = true, material_id = &"survey_film"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You get forty years of readings and a panel off the housing before it rolls away.", material_id = &"survey_film", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "It wants an access code no one has sent in a century, so you take a piece of housing.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 24
						Run.take_hull_damage(OptionTable.toll(4), "Caught on the lit side of a machine in full starlight.")
						return {text = "You misjudge its roll and come around on the lit side, in full starlight."}},
				{label = "Answer it", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You send the receipt it waited for, and it sends you everything before going quiet.", material_id = &"survey_film", material = &"event"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log where it is and go."}},
			],
		},
		{
			id = &"the_failing_shade",
			title = "The failing shade",
			subject = {stage = &"single", pieces = [&"r4_shade_foil_shade_idea2"], tumble = 1.0},
			body = "A failing foil shade keeps the star off three wrecks and a fuel ship, and when it goes they all cook.",
			tags = [&"salvage", &"hazard"],
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 8,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Work fast under it",
					check = {attr = &"maneuver", need = 7},
					met = func() -> Dictionary:
						return {text = "You take the fuel ship's fittings and a piece of its hull before the frame lets go.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "The shade peels back as you burn out from under it with one piece.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "You spend too long picking a wreck, and the frame gives way first."},
					botched = func() -> Dictionary:
						Run.heat += 26
						Run.take_hull_damage(OptionTable.toll(4), "A star shade's foil came down on the ship.")
						return {text = "The whole frame lets go, and its foil comes down across you."}},
				{label = "Hold the frame up", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You hold the buckled edge straight on thrust and work the fuel ship at your own pace.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log what is behind it and go."}},
			],
		},
		{
			id = &"sixty_containers",
			title = "Sixty containers",
			subject = {stage = &"field", pieces = [&"r2_sixty_long_box_sun_bleached_1", &"r2_sixty_short_box_sun_bleached_1", &"r5_sixty_box_burst_open_1", &"r2_sixty_long_box_sun_bleached_2", &"r2_sixty_short_box_sun_bleached_2"], count = 7, near = 2, deep = 2, turns = 25.0, band = -8.0, lift = 30.0, span = 440.0, height = 220.0, seed = 6, tumble = 3.0},
			body = "Sixty containers cook in the light with their labels burned off, and only some of the contents survived.",
			tags = [&"salvage"], site = &"belt",
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Read them with the dish",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						return {text = "Two hours of scanning finds plate and a rack of parts the light never reached.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "A rough sort finds you one container the light could not hurt.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "The readings blur after an hour, and one container in five holds anything good.", material = &"event"},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Sorted containers for three hours in a blue hypergiant's light.")
						return {text = "Every container you open holds ruined stock, and your lit side wears thin."}},
				{label = "Open them at random", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "Five of six hold ruined stock, and one holds something the light could not hurt.", material = &"wreck"}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You log the containers and go."}},
			],
		},
		{
			id = &"the_shield_job",
			title = "The shield job",
			subject = {stage = &"single", pieces = [&"role:hauler"], lights = &"run"},
			body = "A pilot will pay you to block the star for an hour while she fits a dish, though the light wears hull.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Shield her",
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "Your lit side comes out polished, and she pays for the full hour."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.take_hull_damage(OptionTable.toll(2), "Spent an hour in a blue hypergiant's light shielding a stranger.")
						return {text = "Your lit side wears thinner, but she gets the dish mounted."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(8))
						Run.take_hull_damage(OptionTable.toll(3), "Held forty minutes in the light for a stranger's dish.")
						return {text = "Your plating forces you out at forty minutes, and she finishes the job badly."},
					botched = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(8))
						Run.take_hull_damage(OptionTable.toll(5), "Shielded a stranger until the plating failed.")
						return {text = "She gets the dish mounted, but your lit side is badly worn."}},
				{label = "Tow her to shade", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(16))
					return {text = "You tow her into a rock's shadow, and she fits the dish there."}},
				{label = "Leave her", stay = true, effect = func() -> Dictionary:
					return {text = "She goes back to calling, but traffic is thin here."}},
			],
		},
		{
			id = &"the_comet",
			site = &"star",
			subject = {stage = &"single", pieces = [&"paint_moon_ice"], lumpy = 7.7, r = 11.0, tail = true, at = Vector2(-120.0, -72.0)},
			title = "The comet",
			body = "A comet's tail along your course holds water for the tank and rock big enough to wreck the ship.",
			tags = [&"hazard"],
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 8,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Ride the tail",
					check = {attr = &"thrust", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 5
						return {text = "You hold in the tail for eleven minutes while ice packs the open hold.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.fuel += 3
						Run.heat += 10
						return {text = "You pull out when the rock gets thick, with the ship hot from the light."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						Run.take_hull_damage(OptionTable.toll(2), "Hit by a rock in a comet's tail.")
						return {text = "A rock the size of a door hits you eight minutes in."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Went into a comet's tail at the wrong angle.")
						return {text = "You go in at the wrong angle, and the tail throws you sideways through the rock."}},
				{label = "Skim the edge", effect = func() -> Dictionary:
					Run.heat += 14
					Run.fuel += 2
					return {text = "An hour on the thin edge gets you a little water and a lot of heat."}},
				{label = "Wait it out", stay = true, effect = func() -> Dictionary:
					return {text = "You wait three days for the comet to pass."}},
			],
		},
		{
			id = &"the_beacon_job",
			site = &"star",
			subject = {layers = [{stage = &"fx", fx = &"buoy", at = Vector2(-60.0, 0.0), tether = &"r2_container_freight_box_2"}, {stage = &"single", pieces = [&"r2_container_freight_box_2"], dark = 0.2, bake = 0.3, at = Vector2(40.0, 30.0)}]},
			title = "The beacon job",
			body = "A dead beacon pays whoever swaps its cooked board, and a crate of eleven spares hangs beside it.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 8,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Swap the board",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You seat a new board in nine minutes, and the fee clears."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "The first board cooks in the grapple, but the second goes in."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(6))
						Run.heat += 14
						return {text = "The beacon comes up for forty seconds, and you get part of the fee."},
					botched = func() -> Dictionary:
						Run.heat += 22
						Run.take_hull_damage(OptionTable.toll(4), "Worked a dead beacon in a blue hypergiant's light.")
						return {text = "The board slips, and the beacon housing tears a piece off your hull."}},
				{label = "Take the crate", effect = func() -> Dictionary:
					Run.heat += 10
					return {text = "You cut the tether and take the crate, and the beacon stays dark.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the beacon as dead and go."}},
			],
		},
		{
			id = &"the_sorting",
			site = &"star",
			subject = {layers = [{stage = &"fx", fx = &"drift"}, {stage = &"group", anchor = &"star", d = 150.0, ships = [{piece = &"r4_scatter_cabin_section_1", at = Vector2(0.0, 0.0)}, {piece = &"r4_scatter_tank_half_1", at = Vector2(100.0, 0.0)}, {piece = &"r4_scatter_drive_nozzle_1", at = Vector2(185.0, 0.0)}]}]},
			title = "The sorting",
			body = "Starlight has pushed the light wreckage out to the cold side and left the heavy parts here, where working wears hull.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Work the heavy field",
					check = {attr = &"hull", need = 8},
					met = func() -> Dictionary:
						return {text = "Your plating holds for half a day, and you take armor plate and a reactor housing.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "The light wore through the hull in a heavy field.")
						return {text = "You take a reactor housing and a keel bolt before your lit side wears thin.", module = true, material = &"wreck"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Stayed in a heavy field an hour too long.")
						return {text = "You get one piece off a keel before your plating forces you out.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "The light stripped the plating in a heavy field.")
						return {text = "You stay too long, and the light strips your plating."}},
				{label = "Chase the light salvage", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					return {text = "A long day on the cold side turns up one roll of good film.", material = &"event"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log both halves of the field and go."}},
			],
		},
		{
			id = &"clean_hull",
			title = "Clean hull",
			subject = {stage = &"single", pieces = [&"ship_lrshuttle"], lights = &"run"},
			body = "A pilot will pay well for a tow in close until the light burns off his markings, then a tow back out.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Hold him in the light",
					check = {attr = &"hull", need = 8},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "His name burns off in a day, and your lit side comes out polished."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(2), "Spent a day in a blue hypergiant's light for a stranger.")
						return {text = "His ship comes out clean, and your plating needs repair."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(10))
						Run.take_hull_damage(OptionTable.toll(3), "Held a stranger in the light until the plating gave out.")
						return {text = "Your plating gives out with his markings half gone."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Spent a day in a blue hypergiant's full light for a stranger.")
						return {text = "His ship comes out bare, but you have to leave before towing him out."}},
				{label = "Tow him and come back", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(16))
					return {text = "He drifts and burns unevenly, but his name is gone when you return."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "He waits there for the next ship."}},
			],
		},
		{
			id = &"lost_in_the_gas",
			subject = {stage = &"none"},
			title = "Lost in the gas",
			body = "Two people lost in the cloud and low on fuel will pay for directions out, and more for a pickup.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			min_danger = 1,
			max_danger = 2,
			needs_nebula = true,
			choices = [
				{label = "Talk them out",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You find them on the third sweep, and they come out two kilometers off your bow."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						return {text = "It takes eleven headings, and they come out far from where you said."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(6))
						return {text = "You burn to the cloud's edge so they have something bright to steer at."},
					botched = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.take_hull_damage(OptionTable.toll(3), "Hit a rock in the gas looking for a lost hauler.")
						return {text = "They burn on your wrong heading, and a hidden rock hits you as you go in after them."}},
				{label = "Go in and get them", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(24))
					return {text = "You find them the slow way and lead them out behind your drive."}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You point them toward the edge as best you can."}},
			],
		},
	])
	return out
