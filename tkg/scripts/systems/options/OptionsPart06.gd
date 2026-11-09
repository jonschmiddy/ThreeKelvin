class_name OptionsPart06

## Encounters 77 to 90 of the authored table (`the_hunters` to `the_sleepers`), in the order `OptionTable._authored`
## joins them: `roll_for` draws by table order, so entries never move between or within files.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{
			id = &"the_hunters",
			title = "The hunters",
			subject = {stage = &"single", pieces = [&"r3_carcass_whale_fall_2"]},
			body = "A small hunting ship has killed a megafauna the size of a station. The body hangs in the lane with the hunter alongside, cutting fast. The rest of the pod is two hours out and coming back. The hunters want the body towed to their tender before then and will pay for the tow. They will also sell a cheap share to anyone who would rather leave before the pod arrives.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 5,
			max_danger = 6,
			needs_fauna = true,
			choices = [
				{label = "Tow the body to their tender",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "It is the heaviest thing you have ever towed. You get it to the tender with forty minutes to spare. They pay in full and start cutting again before the line is off."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "It takes everything the drive has and most of the two hours. The tender has the body under its cutters before the pod is on the dish. They pay what they said."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.add_credits(OptionTable.purse(8))
						return {text = "The line holds and the body barely moves. You get it half the distance. Then the pod shows on the dish. The hunters cut it loose and run. They pay you for the half."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Towing a dead one when the pod came back.")
						return {text = "The pod arrives while the body is still on your line. The first of them comes past close and slow, and its flank crushes your plating. It is not hostile, only careless. The hunters are gone, and no one pays."}},
				{label = "Buy a share", cost_credits = 45, effect = func() -> Dictionary:
					Run.add_credits(-45)
					return {text = "They cut you a share off the flank and take your money. You are gone before the pod shows on the dish.", material = &"fauna"}},
				{label = "Leave them to it", stay = true, effect = func() -> Dictionary:
					return {text = "You wish them luck and go. Two hours is enough time to be well away before the pod arrives."}},
			],
		},
		{
			id = &"the_singer",
			title = "The singer",
			subject = {stage = &"single", pieces = [&"pool_lev_throat"]},
			body = "An old megafauna the size of a station hangs alone, singing. Scars run the length of its leading edge. The song is loud on every channel and whites out the dish for a hundred kilometres. The rest of its pod is gone, and it stays where it is. It is dying slowly, and you can hear that in the song. A hunting ship two days out has been asking on the channel for one like this. They will pay for the bearing. Rendered, it is worth more than your ship.",
			tags = [&"signal", &"contract"],
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 8,
			needs_fauna = true,
			choices = [
				{label = "Work close and take what it sheds",
					check = {attr = &"maneuver", need = 7},
					met = func() -> Dictionary:
						return {text = "You go in slowly, close enough to see the scars. It knows you are there and ignores you. You take a sheet of hide it has shed, and something smaller that came away with it.", material_id = &"hide_scrap", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You get close, and it turns slowly. You spend the next hour staying out of its way, and you take what came loose in the turn.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Too close to a singer when it turned.")
						return {text = "It turns, and you are in its way. You come away with a scraped hull and nothing else."},
					botched = func() -> Dictionary:
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(4), "Too close to a singer when it rolled.")
						return {text = "You are close alongside when it rolls, and its weight comes down on your ship for a moment. You come away with nothing and a hull that needs a yard."}},
				{label = "Sell the bearing", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(20))
					return {text = "You give the hunting ship the bearing, and they pay before you finish reading it out. They will be here in two days, and you will be long gone."}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You go. The song stays on every channel for a hundred kilometres, and you tell no one about it."}},
			],
		},
		{
			id = &"turning_the_herd",
			title = "Turning the herd",
			subject = {stage = &"herd", flip = true, pieces = [&"r4_turning_the_turning_herd_1", &"r2_turning_the_turning_herd_idea3", &"r4_turning_the_turning_herd_2"], count = 9, near = 3, span = 420.0, height = 190.0, seed = 8},
			body = "A herd of two hundred megafauna is drifting toward the station's approach lane. A small ship with one pilot is trying to turn them. She is running every light she has along the near flank, and it is not enough. If the herd reaches the lane, everything inbound for a week must go around or through it. She is asking for a ship to take the far flank, lights on and drive loud. She says the station will pay her, and she will pay you.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_fauna = true,
			choices = [
				{label = "Take the far flank",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You run the far flank with every light on and the drive at full noise. The herd leans away from you, slowly and all together. Then it is turning. An hour later the lane is clear and the herd is going somewhere else. She pays you before the station has paid her."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "It takes three hours, and the drive is hot from being loud that long. Most of them turn. Two old slow ones keep going, and two is few enough that the station can route its ships around them. She pays what she offered."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(8))
						return {text = "You get half of them turned. The other half go through at their own pace, and the lane is a mess for a week. She pays you for the half, and the station pays her for the half."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Too close to the herd's flank. One of them turned the wrong way.")
						return {text = "You get too close to the flank, and one of them turns toward the noise instead of away. Its side comes across your bow and takes a metre of plating. The herd goes into the lane, and no one pays."}},
				{label = "Make noise on the herd's channel", effect = func() -> Dictionary:
					Run.heat += 12
					Run.add_credits(OptionTable.purse(16))
					return {text = "You fill the frequency the herd calls on with noise from your dish. The herd leans away from the noise and slowly turns. It is slower than flying a flank, and it heats the dish and everything behind it. She pays less than she offered for the flank."}},
				{label = "Leave her to it", stay = true, effect = func() -> Dictionary:
					return {text = "You wish her luck and go. The herd is a day from the lane, so she still has some time."}},
			],
		},
		{
			id = &"the_grazing",
			title = "The grazing",
			subject = {layers = [{stage = &"around", base = &"paint_moon_ice", r = 70.0, loose = true, apart = 8, pieces = [&"r3_grazing_feeder_2"], count = 7, size = 0.5, rx = 112.0, ry = 62.0, tilt = 14.0, seed = 7}, {stage = &"field", pieces = [&"r5_grazing_shed_plate_1"], count = 3, near = 0, deep = 1, turns = 70.0, span = 430.0, height = 176.0, seed = 6, tumble = 6.0}]},
			body = "Forty megafauna have stopped to feed on a body of dirty ice the size of a small moon. They are packed close, mouths to the surface, and will be there for days. As they feed they shed old hide, plates off their leading edges, and other loose pieces. It drifts, and it is worth money. They are not hostile and are not watching you. A startled herd moves all at once, in every direction.",
			tags = [&"hazard", &"salvage"], site = &"contact",
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_fauna = true,
			choices = [
				{label = "Drift in among them",
					check = {attr = &"stealth", need = 5},
					met = func() -> Dictionary:
						return {text = "You go in with the drive cold and the lights down and drift among them like the ice. They never look up. You take a sheet of shed hide the size of your ship and a hard plate off an old one's leading edge. You are out before any of them notices.", material_id = &"hide_scrap", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "One of them notices you and ignores you. You get one good piece off the drift between them and leave before the others notice. The drive runs warm.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Between three startled ones and the ice.")
						return {text = "One of the young ones startles, and the two beside it startle too. For a minute the herd moves in three directions at once. You back out with a scraped hull and nothing."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "In the middle of a feeding herd when the whole herd startled.")
						return {text = "The whole herd startles at once, and there is nowhere to go that they are not going. For thirty seconds they crowd against your ship. Then they are gone, and the hull is badly dented."}},
				{label = "Wait at the edge for what drifts out", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You hold a safe distance out for a day and let the shed drift to you. You take the one piece worth taking. Holding station there costs fuel. The pieces that drift furthest are the oldest and worth the least.", material = &"fauna"}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You go around the herd and fly on."}},
			],
		},
		{
			id = &"the_timekeeper",
			subject = {layers = [{stage = &"fx", fx = &"beam", period = 4.0}, {stage = &"single", pieces = [&"ship_bigdish"], turn = 7.0, dark = 0.6, window = [169, 71], at = Vector2(40.0, -10.0)}]},
			title = "The timekeeper",
			body = "A relay in this system listens to the pulsar and broadcasts its tick. Every ship in the ring sets its clock by it, because the tick never drifts. An old technician runs the relay alone. Its antenna must point straight at the pulsar, but the motor that turns it has burned out. It now points a few degrees off, at empty sky, and he cannot turn it himself. He wants a ship to turn the mount back with its grapple, a degree at a time. He will listen for the signal.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_pulsar = true,
			choices = [
				{label = "Nudge the dish back on",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You put the grapple on the mount and turn the antenna by degrees, then by tenths, while he calls the signal strength. After an hour the tick comes back clean, and every ship in the ring gets its clock back. He pays what he has, which is more than you expected."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						Run.heat += 6
						return {text = "It takes three hours, because the mount sticks, and the drive runs hot holding position that finely for that long. The tick comes back. He pays what he offered."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(6))
						return {text = "You get the antenna close enough that he can hear the pulsar faintly. It is not close enough to broadcast a clean tick. He can finish the last degree himself, once he has a spare motor rigged. He pays you for getting him most of the way."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "The mount gave way under the grapple, and the antenna swung.")
						return {text = "The mount gives way under the grapple, and the antenna swings into your hull. It now points further off the pulsar than before. After a while he says it is not your fault."}},
				{label = "Broadcast the tick yourself", effect = func() -> Dictionary:
					Run.heat += 12
					Run.add_credits(OptionTable.purse(16))
					return {text = "Your dish is already on the pulsar, so you broadcast the tick on his frequency, at his power. You do it for six hours while he rigs a spare motor and turns the antenna himself. It heats the dish and everything behind it. He pays for the six hours, less than he offered for the turning."}},
				{label = "Leave him", stay = true, effect = func() -> Dictionary:
					return {text = "You give him the time off your own board and go. The ring's clocks will drift until someone helps him."}},
			],
		},
		{
			id = &"thin_glaze",
			subject = {layers = [{stage = &"fx", fx = &"beam", period = 6.0, faint = true}, {stage = &"field", pieces = [&"r4_cache_tether_anchor_1", &"r2_minedrift_broken_strut_1", &"r2_minedrift_cable_coil_1", &"r5_scatter_spar_2", &"r4_minedrift_cable_coil_2", &"r2_minedrift_broken_strut_2", &"r4_minedrift_buckled_plate_2"], count = 7, near = 3, deep = 2, turns = 30.0, span = 420.0, height = 160.0, seed = 13, tumble = 2.0, glint = &"beam", at = Vector2(0.0, -40.0)}]},
			title = "Thin glaze",
			body = "The pulsar's beam reaches here every six seconds, so faint that most ships never notice it. It has done this for a very long time. A debris field of old markers, dead satellites and broken wreckage hangs in its track. Every piece carries a thin layer of glaze from the beam. One piece holds little, but a hundred pieces together are worth having. To collect it you fly slowly through sharp metal, and the hull takes hits the whole way.",
			tags = [&"salvage"], site = &"belt",
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 4,
			needs_pulsar = true,
			choices = [
				{label = "Sweep the field",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						return {text = "You go through slowly with the grapple out, scraping as you go while the hull takes the small hits. Three hours later you come out with a plate of glaze pressed from a hundred thin pieces.", material_id = &"sweep_glass"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Three hours in a field of sharp metal, scraping glaze.")
						return {text = "You get the glaze, but something in the middle of the field hits hard and takes a piece of your plating.", material_id = &"sweep_glass"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Dodging, not scraping, halfway through a field of sharp metal.")
						return {text = "Halfway through the field you stop scraping and start dodging. You come out with a dented hull and one piece of an old satellite with almost no glaze on it.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Hit broadside in a debris field, by a piece nobody saw move.")
						return {text = "A piece the size of a door comes out of the field, moving fast, and hits the hull broadside. You leave the way you came in, with nothing."}},
				{label = "Take the nearest piece", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You stay at the edge of the field and take the nearest piece with the grapple. It holds little glaze, but the metal under it is old and sound. Holding at the edge of the drifting field costs fuel.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the field and go."}},
			],
		},
		{
			id = &"the_last_turn",
			subject = {layers = [{stage = &"single", pieces = [&"paint_rock_a1"], r = 50.0, at = Vector2(0.0, -5.0)}, {stage = &"fx", fx = &"marks", on = &"paint_rock_a1", marks = 4, off = Vector2(-4.0, -6.0)}, {stage = &"group", dark = 0.85, ships = [{piece = &"role:hauler", size = 0.25, at = Vector2(-122.0, -62.0)}, {piece = &"role:hauler", size = 0.25, at = Vector2(-146.0, 8.0)}, {piece = &"role:hauler", size = 0.25, at = Vector2(-108.0, 74.0)}, {piece = &"role:hauler", size = 0.25, flip = true, at = Vector2(122.0, -58.0)}, {piece = &"role:hauler", size = 0.25, flip = true, at = Vector2(148.0, 14.0)}, {piece = &"role:hauler", size = 0.25, flip = true, at = Vector2(112.0, 78.0)}]}]},
			title = "The last turn",
			body = "This deep, every ship has to work out its fuel. Here, a full tank still gets you home and anything less does not. Years ago someone painted the numbers on a rock, big enough to read from the approach. Around the rock are thirty or forty hulls that read them too late, all pointed outward. Each ran its tank dry a day or a week short of anywhere. Their holds are still full.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 9,
			min_danger = 9,
			choices = [
				{label = "Read every tank on the dish",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 4
						return {text = "Of forty tanks, one is not empty. It belongs to a hauler that turned with fuel to spare and died of something else. You take its fuel through the transfer line and one thing from its hold. You leave the rest of the field as it was.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.fuel += 2
						Run.heat += 10
						return {text = "You spend two hours reading tanks, and most are dry. One has two units left in the bottom, and you take them. The dish is hot from the reading."},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "Every tank reads dry. You take one thing out of one hold, because you are here. The dish is hot from three hours of finding nothing.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "A dead hull's tank held something volatile, and it exploded.")
						return {text = "One of the tanks is not dry, and what is in it is not fuel either. Something a hauler was carrying has sat in the cold for years, and it goes when the transfer line opens. The hull takes it on the flank. You come away with nothing but the scorch."}},
				{label = "Work the nearest holds", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You skip the tanks and go hull to hull at a crawl. That costs fuel. You take the best thing out of the nearest three holds. They were full when they stopped. They are still full apart from what you take.", material = &"wreck"}},
				{label = "Check your tank and go", stay = true, effect = func() -> Dictionary:
					return {text = "You read the numbers on the rock and check your own tank. You go on while you still have the fuel to get home."}},
			],
		},
		{
			id = &"the_fuel_cache",
			title = "The fuel cache",
			subject = {stage = &"field", pieces = [&"r2_fuelcache_marked_fuel_tank_1", &"r2_fuelcache_marked_fuel_tank_2"], count = 6, near = 2, deep = 2, turns = 18.0, lift = 20.0, span = 340.0, height = 180.0, seed = 8, tumble = 3.0},
			body = "Six full fuel tanks hang on a tether, marked with a ship's name and a date eleven months ago. They sit where anyone coming out from the core would pass. Someone left their fuel home here and went inward in a lighter ship, planning to come back. They have not come back yet, though people have returned after longer. The valves have been in the cold all that time. Only the name painted on the tanks says they are not yours.",
			tags = [&"hazard"],
			group = &"",
			weight = 9,
			min_danger = 9,
			choices = [
				{label = "Take all six",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 5
						return {text = "You warm the valves one at a time and take all six tanks. The owners will not find out for months."},
					clean = func() -> Dictionary:
						Run.fuel += 3
						Run.heat += 10
						return {text = "Four of the valves come free and two do not, and the ship runs hot from warming them. You get three units. The two tanks left on the tether are not enough to get anyone home."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						Run.take_hull_damage(OptionTable.toll(2), "A frozen fuel valve, opened too fast.")
						return {text = "The first valve lets go before it is warm. The tank empties itself across your flank. You take one unit from the second one, slowly, and stop."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A frozen valve, opened too fast, burst its tank.")
						return {text = "The tank comes apart against the hull when the valve goes. None of the fuel reaches your tank, and the hull is dented from bow to midships. You leave the other five."}},
				{label = "Take two and leave four", effect = func() -> Dictionary:
					Run.heat += 8
					Run.fuel += 2
					return {text = "You take two tanks, slowly, warming the valves the long way. Four stay on the tether with the name still on them. Four is enough to get a lighter ship home from the core, if the pilot is careful."}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You log the name and the date and leave the tanks for their owners."}},
			],
		},
		{
			id = &"three_years_in",
			title = "Three years in",
			subject = {stage = &"single", pieces = [&"role:survey"], lights = &"run"},
			body = "A survey ship with four crew is holding station here. A company sent them three years ago to map the approach, log the traffic, and report every ninety days. They have reported on time, but no one has answered in two years or paid them in two and a half. They keep working instead of going home to find out why. Their long-range receiver has been dead since the silence began. They want news and fuel, and will trade three years of measurements for either.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 9,
			choices = [
				{label = "Fix their receiver",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You find the fault in forty minutes: a board that died two years ago. The receiver comes back with two years of messages at once. The company folded eighteen months ago. They pay you from the ship's account, which is now theirs, and give you the three years of measurements."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						return {text = "It takes half a day to find the fault. The receiver comes back. It brings eighteen months of messages and then stops. That is enough. They pay you what they can spare. They give you the measurements."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(6))
						Run.heat += 10
						return {text = "You get their receiver hearing the near channels and not the far ones. They learn the company is not answering, but not why. They pay for the attempt and go back to their instruments."},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(3), "A survey ship's power bus, through the connecting line.")
						return {text = "You trace the fault into their power bus, and the bus fails. Their ship is dark for an hour, and the jolt through the connecting line scorches a metre of your plating. Their receiver is no better, and no one pays."}},
				{label = "Trade fuel for the measurements", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You give them two units. They give you three years of the approach: every hull that went inward or came back, on film and in the log. They add a case of the company's rations, which they have in plenty. You give them what little news you have.", material_id = &"survey_film", material = &"event"}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You give them what news you have on the channel and go. They thank you and go back to their instruments."}},
			],
		},
		{
			id = &"still_inbound",
			title = "Still inbound",
			subject = {stage = &"herd", swim = false, pieces = [&"role:hauler"], count = 6, near = 1, span = 420.0, height = 200.0, seed = 5, drive = true, dark = 0.5},
			body = "Six haulers are crawling across the system in formation toward the core, at a few metres a second. No one answers your hail, and the hulls are cold on every band except the drives. People now long dead set this convoy on automatic, and it is still going where it was told. Their holds are sealed. Working them means matching their slow speed and cutting on the move, inside a formation that still corrects itself.",
			tags = [&"salvage"], site = &"contact",
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Match them and cut",
					check = {attr = &"maneuver", need = 8},
					met = func() -> Dictionary:
						return {text = "You match the crawl and slide in among them. No one aboard is alive to notice. In two hours alongside the lead hauler you take a sealed unit from its rack and a crate from its hold. Then you fall back and let them go on.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You match the speed and lose it twice. The cutter runs hot from starting and stopping. You get one crate out of the last hauler in the line.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "The formation shifts, one hauler correcting for another. You spend the pass staying out of the way of six ships that do not know you are there. You come away with nothing, and hot from the dodging."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "In the gap between two haulers of a dead convoy. One of them corrected.")
						return {text = "You match the wrong hauler, and the one behind it slowly corrects into your gap. There is nowhere to go. It crushes your flank and keeps going toward the core."}},
				{label = "Pace them for a day", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You hold a kilometre off and match their crawl for a day. Their drives shake the old hulls, and you take the one good piece that comes loose. Flying that slowly for a day costs fuel.", material = &"wreck"}},
				{label = "Let them go", stay = true, effect = func() -> Dictionary:
					return {text = "You log their heading and speed and let them go."}},
			],
		},
		{
			id = &"the_pilgrims",
			title = "The pilgrims",
			subject = {stage = &"single", pieces = [&"role:passenger"], lights = &"run", drive = true},
			body = "Nine people on a ship built for four are going to the core. They know they will not come back, and they are going anyway. They are polite and do not want to be talked out of it, and their drive is fine. They want fuel, because they have barely enough to get there. They will pay whatever you ask, since they will not need the money. They also ask if you would fly with them for the first day, and will pay for that too.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Fly with them for a day",
					check = {attr = &"hull", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "You fly inward with them for a day. Nobody says much on the channel. At the end of it they thank you, and pay, and go on, and you turn around. Your hull comes through it fine."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(2), "A day inward with nine people who were not coming back.")
						return {text = "You fly a day inward with them, and something uncharted out there marks your plating. They pay in full and thank you, and you turn around."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(10))
						Run.take_hull_damage(OptionTable.toll(3), "Half a day inward, and the plating did not like it.")
						return {text = "You turn back at midday. Your plating is reading things a day would not undo. You say so. They understand, and pay you for the half day. They go on without you."},
					botched = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.take_hull_damage(OptionTable.toll(4), "Flew a day inward with nine strangers. Hit something that was not on the chart.")
						return {text = "Half a day in, something that is not on the chart takes a piece of your flank. You burn hard coming back out. They pay nothing, since you were the one who turned around."}},
				{label = "Sell them fuel", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					Run.add_credits(OptionTable.purse(30))
					return {text = "You sell them three units, and they do not argue the price. They thank you, fill their tanks, and go inward until the dish loses them."}},
				{label = "Decline and go", stay = true, effect = func() -> Dictionary:
					return {text = "You tell them no, and they are polite about that too. They will wait for the next ship, and another ship will come through eventually."}},
			],
		},
		{
			id = &"going_the_other_way",
			title = "Going the other way",
			subject = {stage = &"single", pieces = [&"role:tender"], drive = true, lights = &"run"},
			body = "Every ship you have seen this deep was going in, but this one is coming out. It is a long way off, moving fast and running hot on one drive of three. It does not slow when you hail, but it answers. A tired voice says it has no fuel to spare and no time to stop. It does have something from further in than you have been, and will trade some for fuel. You would have to match its speed long enough to pass a line.",
			tags = [&"signal", &"contract"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Match it and trade",
					check = {attr = &"maneuver", need = 8},
					met = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You match the ship close enough to pass a line and hold there for six minutes. Two units go across, and a sealed case comes back with equipment from beyond the chart. The voice tells you three things about the core before the ship is gone.", module = true},
					clean = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You hold the match for four minutes. That is long enough for the fuel. It is not quite long enough for what they meant to send. Something smaller comes across instead. The voice says one thing about the core, and it is gone.", material = &"event"},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.heat += 14
						return {text = "You get the line and the fuel across. Then you lose the match, and the line parts before anything comes back. They have your fuel, and your drive is hot from the chase. The voice apologises but does not slow down."},
					botched = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.take_hull_damage(OptionTable.toll(4), "Touched hulls with a ship that was not stopping.")
						return {text = "You get the match wrong, and the hulls touch at a dangerous speed. They keep going. You spend unplanned fuel stopping your drift, and drift a while longer before your systems come back."}},
				{label = "Give them fuel and ask nothing", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(14))
					return {text = "You put two units into a drop tank and leave it on their line. They take it at speed without stopping. The voice talks the whole time it is in range. A payment for the fuel clears an hour later, though you asked for nothing."}},
				{label = "Let it go", stay = true, effect = func() -> Dictionary:
					return {text = "You let it go. It is out of range in an hour, still running hot on one drive."}},
			],
		},
		{
			id = &"frost",
			title = "Frost",
			subject = {stage = &"single", pieces = [&"r5_tank_pressure_tank_1"], tumble = 2.0},
			body = "A container ship has split a tank of liquid gas, which stays liquid only while it is kept cold. It has boiled into a cloud two kilometres across that freezes onto whatever it touches. Frost a centimetre thick covers everything, including the radiators. They cannot shed heat through ice. The containers inside the cloud are whole. Working them means an hour in a cloud that will coat your vents in the first ten minutes.",
			tags = [&"hazard", &"salvage"], site = &"derelict",
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Work through the frost",
					check = {attr = &"thermal", need = 8},
					met = func() -> Dictionary:
						return {text = "You run the radiators hot enough to shed the frost as fast as it forms. Then you go in. An hour in the cloud gets you a sealed unit and a container from the racks nearest the split. You come out white from bow to stern, and warm underneath.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 14
						return {text = "The vents ice over twice, and twice you back out to shed it and go back in. You get one container. The ship runs hot for a day afterwards, working the frost off.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 22
						return {text = "Ten minutes in, the radiators are ice. The heat has nowhere to go. You back out with nothing. The ship has to sit for hours before it can shed what it is carrying."},
					botched = func() -> Dictionary:
						Run.heat += 30
						Run.take_hull_damage(OptionTable.toll(4), "Iced radiators in a frost cloud. The drive section cooked from the inside.")
						return {text = "You stay in too long, and the heat builds with nowhere to go until something in the drive section fails. You come out of the cloud white and hot, missing a piece of the hull."}},
				{label = "Wait for the cloud to thin", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "The cloud is spreading, slowly. You hold outside it for a day and a half, burning to stay put. You go in when it has thinned enough to work the outer racks without icing. You get one container, from the edge.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the ship and go around the cloud."}},
			],
		},
		{
			id = &"the_sleepers",
			title = "The sleepers",
			subject = {stage = &"single", pieces = [&"role:passenger"], turn = 8.0, dark = 0.5, lights = &"battery"},
			body = "A ship drifts on the approach with twelve people aboard in long-term cold sleep. They went under years ago, with the ship set to wake them when help came. Help never came, and the power that keeps them cold is running down. Its transponder offers a standing bounty, paid from the ship's account, for a tow toward any station. The nearest one that could take them is nine days out, the other way from your route.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Tow them out to where the traffic runs",
					check = {attr = &"thrust", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You tow them a day outward to the traffic route and leave them there with their transponder loud. The ship pays the bounty for the leg and copies you its log. They are still asleep, a day nearer to help."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 10
						return {text = "The tow takes two days instead of one, and the drive is hot from the pull. You leave them where the traffic runs. The ship pays for the leg."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.add_credits(OptionTable.purse(8))
						return {text = "You get them half a day outward and the line parts. You burn an hour of fuel chasing the loose end down and putting it back on. Half a day is not far enough to matter. The ship pays for half a day."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A sleeping ship, on a tow line, swinging.")
						return {text = "The tow line comes tight at a bad angle, and the ship swings slowly into your flank. The sleepers do not wake or pay."}},
				{label = "Take what they will not miss", effect = func() -> Dictionary:
					Run.heat += 8
					return {text = "Their racks and holds are full, and none of the twelve will know. You take a sealed unit and a crate and leave the rest. The hour your cutter spends inside drains their power a little faster.", module = true, material = &"wreck"}},
				{label = "Leave them sleeping", stay = true, effect = func() -> Dictionary:
					return {text = "You log the position and the bounty and go."}},
			],
		},
	])
	return out
