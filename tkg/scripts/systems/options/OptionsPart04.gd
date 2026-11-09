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
			body = "The star has been shedding for a long time. What comes off collects here as warm dust, too fine to see until it is on you. Everything in this system is coated with it on the side facing the light. It will stick to your radiators too, and it does not come off by itself. Deep in the thickest part of the cloud is a mining ship, dusted over, holds shut, drifting. Nothing here moves fast enough to have wrecked it. It just stopped.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 4,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Pull the mining ship out",
					check = {attr = &"thrust", need = 5},
					met = func() -> Dictionary:
						return {text = "The grapple takes the towing eye. It drags the ship out of the cloud a metre at a time. The dust comes off in sheets once it is moving. The holds were shut, not sealed. They open for the cutter in about ten minutes.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You pull it out fast and the dust goes everywhere. Every radiator you have is coated, and the vents will be an hour clearing them. The holds are worth the hour.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 10
						return {text = "It shifts, then settles back into the cloud. You spend an hour on it and come away with nothing but a hot ship."},
					botched = func() -> Dictionary:
						Run.heat += 16
						Run.take_hull_damage(OptionTable.toll(4), "Star dust got into the intakes faster than the vents could clear it.")
						return {text = "It comes free all at once, and a slab of the crust goes straight into your intakes. The hull holds, but the vents behind it fail."}},
				{label = "Fly the cloud with a hold open", effect = func() -> Dictionary:
					Run.heat += 9
					return {text = "You open one hold and fly the length of the cloud slowly. The dust packs into the corners and heats the ship the whole way. You end up with a hold of fine metal the star threw off.", material = &"mining"}},
				{label = "Keep clear of the cloud", stay = true, effect = func() -> Dictionary:
					return {text = "You go around the lit side of the system and leave the mining ship where it is."}},
			],
		},
		{
			id = &"the_water_stop",
			title = "The water stop",
			subject = {stage = &"field", pieces = [&"r5_tank_pressure_tank_1", &"r4_tank_pressure_tank_2", &"r5_tank_pressure_tank_2", &"r5_tank_pressure_tank_1"], count = 4, near = 2, turns = 14.0, span = 400.0, height = 170.0, seed = 15, tumble = 2.0},
			body = "Two people run a water stop sunward of here. For eleven years they have held tanks of ice out in the light and sold the melt water to passing ships. The plant was parked in a stable orbit and has no engine. Now the orbit is slowly decaying toward the star. They have been asking every ship on the open channel for a tow for a while. There is not much traffic.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Tow them back out",
					check = {attr = &"thrust", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You put your nose against the plant and hold a slow burn for forty minutes. It puts them back where they were eleven years ago. They pay out of a box under the console and count it twice."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "The tow takes longer than either of you expected, but it puts them high enough to stop worrying. They pay what they said they would, though the orbit will need fixing again."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(7))
						return {text = "You get them moving and the line slips before they are anywhere near safe. They are higher than they were and not high enough. They pay you something for the try, because they will be asking again next month."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A water plant the size of a station swung into the ship under tow.")
						return {text = "The line goes tight off centre, and the plant swings around fast and hits your side. The plant is not damaged."}},
				{label = "Sell them fuel instead", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(18))
					return {text = "They have thrusters on the tanks and nothing to run them on, so you sell them two units at a fair price. They will burn it a little at a time and climb out on their own over the next month. It pays less than the tow, and you cannot refill until the next station."}},
				{label = "Leave them to it", stay = true, effect = func() -> Dictionary:
					return {text = "You wish them luck and go. Their orbit gives them a few months yet."}},
			],
		},
		{
			id = &"the_lit_side",
			title = "The lit side",
			subject = {stage = &"single", pieces = [&"r5_split_derelict_1"]},
			body = "A dead freighter has kept the same face to the star for decades. Dust has baked onto the lit side year after year until it went hard and clear like amber. You can see the layers in it. The cold side is bare metal, and its holds would open after an hour of cutting. Working the lit side means sitting in the light for as long as it takes.",
			tags = [&"salvage"], site = &"derelict",
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Cut the glaze off",
					check = {attr = &"thermal", need = 6},
					met = func() -> Dictionary:
						return {text = "You sit in the full light and take the glaze off in plates. It comes away solid and warm, with decades of layers stacked in order. It goes into the hold hot and stays hot for a long time.", material_id = &"corona_amber"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You get a good amount off before the vents start falling behind. What you have is worth the heat. The last plate brings a strip of hull with it.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 14
						return {text = "The glaze is welded to the plating underneath. The cutter is doing more heating than cutting. You give it up. Your ship is hot and your hold is empty."},
					botched = func() -> Dictionary:
						Run.heat += 22
						Run.take_hull_damage(OptionTable.toll(5), "Ten minutes too long in the full light. The vents never caught up.")
						return {text = "You stay ten minutes longer than the vents can handle. Nothing catches fire, but systems fail one after another, starting on the lit side."}},
				{label = "Take the cold side instead", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You sit in the freighter's shadow. Holding that spot burns a slow drip of fuel for the whole hour. The holds on the cold side have ordinary cargo in them. You take some.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log where it is and go."}},
			],
		},
		{
			id = &"paying_for_shade",
			title = "Paying for shade",
			subject = {stage = &"single", pieces = [&"paint_rock_a1"], r = 96.0},
			body = "One rock in this system holds a stable position and throws a shadow long enough to hide a dozen ships. Two ships got here first and hold the near edge. They charge for a spot, cash up front, and say so on the open channel to everyone who comes in. The instruments put the next flare about ninety minutes out. Further back in the shadow is forty years of what people left when they ran: cargo, a dead ship, and loose plate.",
			tags = [&"hazard"],
			group = &"",
			weight = 10,
			min_danger = 5,
			max_danger = 6,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Pay for a spot", cost_credits = 45, effect = func() -> Dictionary:
					Run.add_credits(-45)
					return {text = "You pay, take the spot they give you, and sit out the flare with everything turned down. When the grapple goes out for a piece of the loose plate further back, no one objects. They charged only for the shade.", material = &"wreck"}},
				{label = "Take a spot without paying",
					check = {attr = &"stealth", need = 6},
					met = func() -> Dictionary:
						return {text = "You come in cold along the back edge and sit among the dead ships. The flare comes and goes, and no one calls you on the channel. On the way out you take the best thing you were parked next to.", material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You get a poor spot at the edge, half in the light, and hold it. It is uncomfortable and it is free. Something small drifts against the hull while you wait, and you keep it.", material = &"event"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "The edge of the shadow moves during the flare, and you do not keep up. You spend the worst of it with a third of the ship in the light. You come out hot, with an empty hold."},
					botched = func() -> Dictionary:
						Run.heat += 18
						Run.take_hull_damage(OptionTable.toll(5), "You were pushed out of the shade, and the flare hit you in the open.")
						return {text = "They find you inside twenty minutes and keep a light on you until you leave. The flare arrives while you are out in the open."}},
				{label = "Move on before it hits", stay = true, effect = func() -> Dictionary:
					return {text = "You are out of the inner system before the readings climb far. You give up the shade and everything sitting in it."}},
			],
		},
		{
			id = &"the_century_log",
			site = &"star",
			subject = {stage = &"single", pieces = [&"ship_science"], size = 0.5, dark = 0.7, bake = 0.5, lights = &"shaded", at = Vector2(-110.0, -80.0)},
			title = "The century log",
			body = "A machine in a close orbit here has measured the star once an hour for a hundred years, through every flare. Stars this size are hard to predict, so a century of readings is worth money to anyone who flies near them. The people who put it there stopped answering long ago. The heat is cooking it now, and only its shaded half still works. After every flare it sends a summary to a receiver that is no longer there.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 8,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Take the readings off it",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						return {text = "You match its roll, put the dish on it, and pull down the whole hundred years in one pass. The grapple also takes the instrument head off its mount, still cold and still good.", module = true, material_id = &"survey_film"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You get the link and about forty years of readings before the working half rolls away from you. The grapple takes a panel off the housing as you pass.", material_id = &"survey_film", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "The link wants an access code no one has sent in a century, and you cannot find it in time. You come away with a piece of the housing and none of the readings.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 24
						Run.take_hull_damage(OptionTable.toll(4), "You were caught on the lit side of the machine, in full starlight.")
						return {text = "You misjudge the roll and come around on the lit side, with nothing between you and the star for a few seconds."}},
				{label = "Answer it", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "Its summaries carry the return frequency. You send a receipt on it in the format the machine expects, and it treats the job as finished. It sends you everything it has, which takes eleven hours with the reactor idling. Then it stops transmitting.", material_id = &"survey_film", material = &"event"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log where it is and go. It keeps taking readings while you are in range."}},
			],
		},
		{
			id = &"the_failing_shade",
			title = "The failing shade",
			subject = {stage = &"single", pieces = [&"r4_shade_foil_shade_idea2"], tumble = 1.0},
			body = "Someone built a shade here. It is foil on a frame, kilometres across, hung between the star and a lane that would be useless without it. It is still up. Over the years, things have collected in the cool behind it: three wrecks, a fuel ship, and loose cargo. One edge of the frame is buckling. When it goes, the whole shade goes, and everything behind it gets the full heat of the star.",
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
						return {text = "You go for the fuel ship first, because that is where the fittings are. You have the good half of it aboard before the frame lets go. What you leave stays out in the light.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You work fast and pick well enough. The edge lets go while you are still shortening the last line. The shade peels back over you as you burn out from under it. You are clear with about four minutes to spare.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "You spend too long choosing between the three wrecks, and the frame gives way first. You leave with an empty hold, after taking the starlight in the open."},
					botched = func() -> Dictionary:
						Run.heat += 26
						Run.take_hull_damage(OptionTable.toll(4), "The shade's foil came down on you, with the star straight behind it.")
						return {text = "The buckled edge lets go along its whole length, and the rest of the frame follows. A sheet of foil the size of a town comes down across you. Then nothing stands between you and the star."}},
				{label = "Hold the frame up", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You put the grapple on the buckled edge and hold it straight on thrust. The long burn buys you hours instead of minutes. You work the fuel ship at your own pace with the shade steady over you. It is still up when you let go, but it will not last the year.", material = &"wreck"}},
				{label = "Leave the shade alone", stay = true, effect = func() -> Dictionary:
					return {text = "You log what is behind it and fly on."}},
			],
		},
		{
			id = &"sixty_containers",
			title = "Sixty containers",
			subject = {stage = &"field", pieces = [&"r2_sixty_long_box_sun_bleached_1", &"r2_sixty_short_box_sun_bleached_1", &"r5_sixty_box_burst_open_1", &"r2_sixty_long_box_sun_bleached_2", &"r2_sixty_short_box_sun_bleached_2"], count = 7, near = 2, deep = 2, turns = 25.0, band = -8.0, lift = 30.0, span = 440.0, height = 220.0, seed = 6, tumble = 3.0},
			body = "A hauler broke up here a while ago. More than sixty of its containers are spread across the approach in the light. The light has burned every label off and cooked the seals. Some of the contents are unharmed and some are ruined, and from outside you cannot tell which. Metal, ore and tools survive the light. Medicine, film and anything with a circuit do not.",
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
						return {text = "You scan the containers one by one for mass, density, and how each has warmed. After two hours you know which eleven are worth opening. Inside are plate and a rack of parts the light never reached.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "The dish gives you a rough sort, good enough to skip the worst of them. Two hours in the light heats the ship. You come out with one container of something the light could not hurt.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "The readings all look the same after the first hour. You open the ones that seem heaviest and get one good container in five. The rest is cooked stock, and the ship is hot from the sorting.", material = &"event"},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "You spent three hours in a blue hypergiant's light, sorting containers.")
						return {text = "You spend three hours in the light reading numbers that never add up. All four containers you open hold ruined stock, and your own lit side is worn thin."}},
				{label = "Open them at random", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You do not have two hours, so you open whatever is nearest. Stopping and starting costs fuel. Of six containers, five hold ruined stock and one holds something the light could not hurt.", material = &"wreck"}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You log the containers and move on."}},
			],
		},
		{
			id = &"the_shield_job",
			title = "The shield job",
			subject = {stage = &"single", pieces = [&"role:hauler"], lights = &"run"},
			body = "A small freighter is calling for an unusual kind of help on the open channel. The light here has burned out its dish array, as it does to anything pointed at the star. The pilot cannot fit the spare, because it would start cooking on the mount. She needs something big to sit between her ship and the star for about an hour. She is offering good money, and she knows that sitting still here costs hull.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Sit in the light for her",
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You put the ship between her and the star and hold. Your lit side comes out polished but otherwise undamaged. She has the spare mounted in fifty minutes and pays for the full hour anyway."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.take_hull_damage(OptionTable.toll(2), "An hour in a blue hypergiant's light, shielding a stranger's dish.")
						return {text = "You hold the hour. The plating on your lit side is measurably thinner at the end of it. She gets the array mounted and pays what she offered."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(8))
						Run.take_hull_damage(OptionTable.toll(3), "You held forty minutes for a stranger's dish. The plating gave out at thirty.")
						return {text = "You hold forty minutes before your plating readings force you to stop. She gets the array half mounted and finishes it badly in the shadow of her own hull. She pays for the forty minutes."},
					botched = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(8))
						Run.take_hull_damage(OptionTable.toll(5), "You sat in a blue hypergiant's full light for an hour, and the plating failed.")
						return {text = "You misjudge what an hour costs here. She gets the array mounted, but your lit side is badly worn, and her money does not cover the repairs."}},
				{label = "Tow her into a shadow instead", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(16))
					return {text = "You tow her to a rock forty minutes away with a shadow the right size. It costs fuel and most of a day. She swaps the array in the dark at her own pace and pays less than she offered for the shielding."}},
				{label = "Leave her", stay = true, effect = func() -> Dictionary:
					return {text = "You wish her luck and fly on. She goes back to calling, but there is not much traffic here."}},
			],
		},
		{
			id = &"the_comet",
			site = &"star",
			subject = {stage = &"single", pieces = [&"paint_moon_ice"], lumpy = 7.7, r = 11.0, tail = true, at = Vector2(-120.0, -72.0)},
			title = "The comet",
			body = "A comet is passing close to the star, which is boiling it. Its tail is a hundred thousand kilometres of water, gas and rock, lit white. It points straight along the lane you need. It holds more clean water than all the station tanks within a week of here. It also holds more fast-moving rock than the dish can count, none of it small. Riding the tail puts fuel in the tank. Riding it badly can destroy the ship.",
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
						return {text = "You put the nose into the tail and hold it there for eleven minutes. You correct the whole time as rock goes past on both sides. Five units go into the tank, and ice packs into the open hold.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.fuel += 3
						Run.heat += 10
						return {text = "You get three units before the rock gets too thick to fly through. The ship is hot from the light and will take an hour to shed the heat."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						Run.take_hull_damage(OptionTable.toll(2), "Rock in a comet's tail.")
						return {text = "You get eight minutes in the tail before a rock the size of a door hits you. The tank takes one unit, and the hull has a matching dent."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Went into a comet's tail at the wrong angle.")
						return {text = "You go in at the wrong angle, and the tail throws you sideways for six kilometres through rock and ice. The tank is no fuller than it was."}},
				{label = "Skim the edge for ice", effect = func() -> Dictionary:
					Run.heat += 14
					Run.fuel += 2
					return {text = "You keep to the thin edge of the tail, where the rock is rare and the ice is too. It takes an hour in the light. Two units of water go into the tank. The ship spends the next hour shedding heat."}},
				{label = "Wait for it to pass", stay = true, effect = func() -> Dictionary:
					return {text = "You hold off the lane for the three days it takes the comet to pass."}},
			],
		},
		{
			id = &"the_beacon_job",
			site = &"star",
			subject = {layers = [{stage = &"fx", fx = &"buoy", at = Vector2(-60.0, 0.0), tether = &"r2_container_freight_box_2"}, {stage = &"single", pieces = [&"r2_container_freight_box_2"], dark = 0.2, bake = 0.3, at = Vector2(40.0, 30.0)}]},
			title = "The beacon job",
			body = "A navigation beacon on the lane inward is dead. The light here kills a circuit board in about four days. Its owners keep a crate of spare boards tethered beside it. A standing offer is painted on the crate: swap the board, key in the job number, and the fee clears. No one is here to watch, and no one has been for a while. The crate has eleven boards left.",
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
						return {text = "You pull the dead board with the grapple and seat a new one in nine minutes, before the light can damage it. The beacon comes up, you key the number, and the fee clears."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "It takes two boards. The first cooks in the grapple before it is seated, and the second goes in fast. The beacon comes up. You key the number and are paid for one swap."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(6))
						Run.heat += 14
						return {text = "The beacon comes up for forty seconds and goes dark again. You key the number anyway and get a partial fee. The crate has ten boards left."},
					botched = func() -> Dictionary:
						Run.heat += 22
						Run.take_hull_damage(OptionTable.toll(4), "Working a dead beacon in the full light of a blue hypergiant.")
						return {text = "You are still working when the board in the grapple slips. The beacon housing tears a piece off your hull, and the beacon stays dark. The crate has ten boards left."}},
				{label = "Take the crate", effect = func() -> Dictionary:
					Run.heat += 10
					return {text = "Eleven sealed boards are worth more at a station than one swap pays. You spend ten minutes in the light cutting the tether and take the crate. The beacon stays dark.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the beacon as dead and fly the lane by dead reckoning."}},
			],
		},
		{
			id = &"the_sorting",
			site = &"star",
			subject = {layers = [{stage = &"fx", fx = &"drift"}, {stage = &"group", anchor = &"star", d = 150.0, ships = [{piece = &"r4_scatter_cabin_section_1", at = Vector2(0.0, 0.0)}, {piece = &"r4_scatter_tank_half_1", at = Vector2(100.0, 0.0)}, {piece = &"r4_scatter_drive_nozzle_1", at = Vector2(185.0, 0.0)}]}]},
			title = "The sorting",
			body = "The light here is strong enough to push things, slowly but without stopping. Over years it moves anything loose, light things quickly and heavy things slowly. So the wreckage in this system has been sorted. Foil, film, plastic and other light salvage were blown out to the cold side years ago. The heavy parts are still here in the light: keels, reactor housings and armour plate. Working them means working in the light.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Work the heavy field",
					check = {attr = &"hull", need = 8},
					met = func() -> Dictionary:
						return {text = "Your plating holds for the afternoon it takes. You come away with armour plate, a reactor housing and heavy keel bolts, all still good.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "The light wore through the hull in an afternoon on the heavy field.")
						return {text = "You get most of an afternoon before your lit side starts to wear thin. You take the best of the heavy field, at a cost in hull.", module = true, material = &"wreck"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "You stayed in the heavy field an hour too long, and the plating gave out.")
						return {text = "You get one good piece off a keel before your plating readings force you out. The damage to your lit side costs more than the piece is worth.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "The light stripped your plating in the heavy field.")
						return {text = "You stay too long, and the light does to your plating what it has done to everything else here. You leave with nothing in the hold."}},
				{label = "Chase the light things outward", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					return {text = "You burn out to the cold side and spend a long day among what the light pushed there. Most of it is worthless, but you take the film and foil that stayed out of the light.", material = &"event"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log both halves of the field and go."}},
			],
		},
		{
			id = &"clean_hull",
			title = "Clean hull",
			subject = {stage = &"single", pieces = [&"ship_lrshuttle"], lights = &"run"},
			body = "A ship holds a long way out from the star. The pilot wants it towed in close until the light burns off every marking: registry, yard numbers and name. Then he wants it towed back out. He says his drive is out, and a ship with no drive drifts in the light. He says a day will do it. He does not say why, and no one out here asks. He pays well for the tow both ways.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Tow him in and hold him there",
					check = {attr = &"hull", need = 8},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "You tow him in and hold beside him for a day while the star burns his ship's name off. Then you tow him out. Your lit side comes out polished but otherwise undamaged. He pays in full without a word."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(2), "You spent a day in a blue hypergiant's light for a stranger.")
						return {text = "You hold beside him for the day, and your plating wears thin enough to need repair. His ship comes out clean, and he pays what he said."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(10))
						Run.take_hull_damage(OptionTable.toll(3), "You held a stranger's ship in the light, and your plating gave out before his paint did.")
						return {text = "The day is too long for your plating, so you pull him out with his markings half gone. They cannot be read, but they are not clean. He pays for half a job, unhappily."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "You spent a day in a blue hypergiant's full light for a stranger.")
						return {text = "You stay the day, and your plating suffers badly. His ship comes out bare, but you have to leave before you can tow him out, so he pays nothing."}},
				{label = "Tow him in and come back tomorrow", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(16))
					return {text = "You tow him in, let go, and pull back out of the worst of the light. A day later you go in for him. He has drifted, and the burn is uneven, but his name is gone. He pays for two tows and not for the day."}},
				{label = "Decline the job", stay = true, effect = func() -> Dictionary:
					return {text = "You tell him no, and he takes it well. He is still holding there when you leave, waiting for the next ship."}},
			],
		},
		{
			id = &"lost_in_the_gas",
			subject = {stage = &"none"},
			title = "Lost in the gas",
			body = "A hauler is calling on the open channel from somewhere inside the cloud. Its two crew are low on fuel and lost. Their small dish cannot see through the gas, and they have no fix and no stars. Their heading stopped being any use an hour ago. They can hear you but cannot tell where you are. They will pay for directions out, and more for a ship that comes in and gets them.",
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
						return {text = "Your dish is bigger than theirs. You find them on the third sweep, a cold spot in warmer gas. You read them a heading. You read them another when the gas moves, and then a third. Forty minutes later they come out of the cloud two kilometres off your bow. They pay before they have finished thanking you."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						return {text = "It takes two hours and eleven headings. Most of them are corrections to the one before. They come out in the end, a long way from where you said they would. They pay what they offered for the way out."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(6))
						return {text = "You lose them twice and find them once. In the end you burn out to the edge of the cloud yourself, so they have something bright to steer at. They make it and pay what little they have left."},
					botched = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.take_hull_damage(OptionTable.toll(3), "Went into the gas after a lost hauler, and found a rock first.")
						return {text = "You give them a wrong heading, and they burn on it for twenty minutes before either of you knows. You go in after them, and the gas hides a rock the size of a station until you are nearly on it. You get them out in the end, but they cannot pay."}},
				{label = "Go in and get them", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(24))
					return {text = "You go in on the bearing of their voice and find them the slow way, with the lights on. Then you lead them out, close, so they can see your drive. It costs fuel to fly slowly in gas. They pay the higher price without being asked."}},
				{label = "Leave them to find their own way", stay = true, effect = func() -> Dictionary:
					return {text = "You tell them which way the edge is, as best you can, and go on. They thank you, though it is not much help."}},
			],
		},
	])
	return out
