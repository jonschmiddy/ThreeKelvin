class_name OptionsPart07

## Encounters 91 to 102 of the authored table (`first_on_the_wreck` to `the_back_of_the_line`), in the order `OptionTable._authored`
## joins them: `roll_for` draws by table order, so entries never move between or within files.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{
			id = &"first_on_the_wreck",
			title = "First on the wreck",
			subject = {stage = &"single", pieces = [&"r3_frame_gutted_frame_1"]},
			body = "Two ships claim the dead ore freighter you are cutting and park by the break, where the last full racks sit.",
			tags = [&"fight", &"salvage"], site = &"derelict",
			group = &"",
			weight = 12,
			min_danger = 1,
			max_danger = 2,
			choices = [
				{label = "Cut beside them",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						return {text = "You work too tight for them to follow and lift a drive module and a bay of plate.", material = &"wreck", module = true},
					clean = func() -> Dictionary:
						Run.heat += 5
						return {text = "You run the cutter hot on the near racks and get one bay of plate.", material = &"wreck"},
					partial = func() -> Dictionary:
						return {text = "They drift in on both sides, and you back off with nothing."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Hit a dead freighter at the wrong angle.")
						return {text = "The gap is narrower than it looked, and the freighter tears into your bow."}},
				{label = "Hold the wreck", fight = true, effect = func() -> Dictionary:
					return {text = "You put the ship across the break, and both ships come at you.", fight = true}},
				{label = "Back off", stay = true, effect = func() -> Dictionary:
					return {text = "The larger ship is on the break before you clear the field."}},
			],
		},
		{
			id = &"the_wrong_writ",
			title = "The wrong writ",
			subject = {stage = &"single", pieces = [&"ship_courier2"], lights = &"patrol", fights = true},
			body = "A patrol pilot stops you on a writ for a hull one digit off yours, from an office that no longer answers.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 11,
			min_danger = 1,
			max_danger = 2,
			choices = [
				{label = "Show your registry",
					check = {attr = &"sensors", need = 3},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "She checks your registry, stands down, and pays what her service owes for a wrong stop."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(12))
						return {text = "After an hour of calls, she agrees and pays a small fee for your time."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "She cannot check your record and holds you a day and a half."},
					botched = func() -> Dictionary:
						return {text = "You talk over her, and she takes it as guilt and comes at you.", fight = true}},
				{label = "Allow the inspection", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "She scans your hold for a day, finds nothing, and sends over a case of rations.", material = &"event"}},
				{label = "Hold your heading", stay = true, effect = func() -> Dictionary:
					return {text = "The skiff trails you twenty minutes, then goes looking for the right hull."}},
			],
		},
		{
			id = &"the_far_side",
			title = "The far side",
			subject = {stage = &"group", ships = [{piece = &"role:passenger", dark = 0.55, lights = &"battery", at = Vector2(85.0, 20.0), z = 0}, {piece = &"ship_gunboat", fights = true, size = 0.5, dock = {to = 0}, at = Vector2(75.0, 0.0), z = 1}, {piece = &"role:small", fights = true, turn = 6.0, lights = &"run", at = Vector2(-118.0, 82.0), z = 2}, {piece = &"role:small", fights = true, far = true, turn = -5.0, lights = &"run", at = Vector2(-150.0, -68.0), z = -1}]},
			body = "A scavenger crew strips a passenger hull with two small ships on guard, but nobody has touched its dark stern.",
			tags = [&"fight", &"salvage"], site = &"derelict",
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Work the stern dark",
					check = {attr = &"stealth", need = 4},
					met = func() -> Dictionary:
						return {text = "You slip in under their floods and take a drive module and a bay of plate off the stern.", material = &"wreck", module = true},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You get one bay of plate before your reactor gives you away, but nobody follows.", material = &"wreck"},
					partial = func() -> Dictionary:
						return {text = "One of the small ships was watching the stern and comes straight at you.", fight = true},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Hit a wreck's stern in the dark.")
						return {text = "You come in at the wrong angle and hit the stern frame hard."}},
				{label = "Cut for their crew", effect = func() -> Dictionary:
					Run.heat += 10
					return {text = "They let you run your cutter on their seam for a shift and pay one bay of plate.", material = &"wreck"}},
				{label = "Leave the stern", stay = true, effect = func() -> Dictionary:
					return {text = "Their two small ships stay between you and the hull until you are out of range."}},
			],
		},
		{
			id = &"the_open_toll",
			title = "The open toll",
			subject = {stage = &"single", pieces = [&"r3_depot_fuel_depot_1"], tumble = 1.0},
			body = "Two ships charge a toll at an automatic fuel platform that pumps free for any ship that reaches the intake.",
			tags = [&"fight", &"signal"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Burn for the intake",
					check = {attr = &"thrust", need = 5},
					met = func() -> Dictionary:
						Run.fuel += 4
						return {text = "You are coupled before either ship comes about."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						Run.heat += 6
						return {text = "The nearer ship crowds the coupling, and you break off with the radiators hot."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						return {text = "They put a hull across the intake soon after you couple."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Hit a fuel platform's intake arm at full burn.")
						return {text = "The intake arm is not where the old chart put it, and you hit it at full burn."}},
				{label = "Push them off the intake", fight = true, effect = func() -> Dictionary:
					return {text = "You go at the two ships, and they are slow to answer.", fight = true}},
				{label = "Keep clear", stay = true, effect = func() -> Dictionary:
					return {text = "You go around outside their strobe."}},
			],
		},
		{
			id = &"nothing_taken",
			title = "Nothing taken",
			subject = {stage = &"group", fights = true, flood = true, ships = [{piece = &"role:hauler", far = true, at = Vector2(-120.0, -60.0)}, {piece = &"role:hauler", far = true, at = Vector2(140.0, -55.0)}, {piece = &"ship_armedtrader", at = Vector2(10.0, 35.0), z = 1}]},
			body = "Three haulers robbed by a ship of your class block your way, sure it was you, though they will not shoot first.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Run cold for a reading",
					check = {attr = &"thermal", need = 5},
					met = func() -> Dictionary:
						return {text = "The reading clears you, and she gives you a fresh bearing on the real thief.", fight = true},
					clean = func() -> Dictionary:
						return {text = "The reading clears you, and she says so on the open channel."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "The radiators will not come down enough, so you take the long way out with two of them following."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A warning shot from a hauler landed.")
						return {text = "You run hot in the middle of the reading, and their warning shot hits."}},
				{label = "Escort them across", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(26))
					return {text = "She will not clear you, but she pays you to fly escort where she can see you."}},
				{label = "Decline the stop", stay = true, effect = func() -> Dictionary:
					return {text = "You fly through the middle of the three, and nobody follows."}},
			],
		},
		{
			id = &"the_licensed_seam",
			title = "The licensed seam",
			subject = {stage = &"single", pieces = [&"paint_rock_b3"], r = 120.0},
			body = "Three bigger ships from the outfit that has licensed this rock for nine years find you cutting its best nickel face.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			choices = [
				{label = "Hold and finish the cut",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "Your ship will not budge, so the foreman buys half the cut and you keep the rest.", material = &"mining"},
					clean = func() -> Dictionary:
						return {text = "You get the face off clean, and their smallest ship comes at you.", fight = true},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "They park two hulls across the face, and after an hour running hot you stow the cutter."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A ship's wash brought an overhang down.")
						return {text = "A ship puts its wash across your bow, and the overhang comes down on you."}},
				{label = "Buy a day's license", cost_credits = 50, effect = func() -> Dictionary:
					Run.add_credits(-50)
					return {text = "The foreman quotes his usual rate, and you finish the cut while they watch.", material = &"mining"}},
				{label = "Leave the face", stay = true, effect = func() -> Dictionary:
					return {text = "They are on the face before you clear the rock."}},
			],
		},
		{
			id = &"the_wreckers",
			title = "The wreckers",
			subject = {stage = &"single", pieces = [&"r4_lightmast_false_light_1"]},
			body = "Wreckers lure ships to a rock with a false station light, and two of their ships wait behind it among stripped hulls.",
			tags = [&"fight", &"salvage"], site = &"belt",
			group = &"",
			weight = 10,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Find the true bearing",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						return {text = "You work the old frames on the far side and lift a sealed unit and a crate.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You work the oldest hull far out and take one crate unseen.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "Hours on the dish get you nowhere, and the far frames are picked clean."},
					botched = func() -> Dictionary:
						Run.heat += 8
						return {text = "Your strong return gives you away, and both ships come out of the shadow.", fight = true}},
				{label = "Burn wide for far frames", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You go wide behind the rock and take one crate off the outermost hull.", material = &"wreck"}},
				{label = "Leave the light", stay = true, effect = func() -> Dictionary:
					return {text = "You log the false code and go wide of the rock."}},
			],
		},
		{
			id = &"the_hunting_ship",
			title = "The hunting ship",
			subject = {stage = &"single", pieces = [&"ship_scoop"], lights = &"run", fights = true},
			body = "A hunting ship five months out with empty holds turns toward your mass and asks twice what you are carrying.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 10,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Wait for them",
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "They read your plating, decide against a fight, and buy your bearing."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						return {text = "They look you over and buy your bearing for less than it is worth."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.add_credits(OptionTable.purse(6))
						return {text = "They take a day to decide, then pay badly for your bearing."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A hunting ship tested the plating with a shot.")
						return {text = "They put a shot through your flank, and you burn out of the system."}},
				{label = "Hit them first", fight = true, effect = func() -> Dictionary:
					Run.heat += 10
					return {text = "You close on them at full throttle before they can change their plan.", fight = true}},
				{label = "Answer and keep going", stay = true, effect = func() -> Dictionary:
					return {text = "You tell them, and they pace you to the system's edge before turning back."}},
			],
		},
		{
			id = &"the_long_crew",
			title = "The long crew",
			subject = {stage = &"single", pieces = [&"ship_ringdrive"], lights = &"battery", fights = true},
			body = "An armed crew nineteen years out with no registry reads you a list of forty things it needs, fuel first.",
			tags = [&"fight"],
			group = &"",
			weight = 9,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Come at them dark", fight = true,
					check = {attr = &"stealth", need = 7},
					met = func() -> Dictionary:
						return {text = "You come in cold off their blind quarter while they are still reading.", fight = true},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "Your reactor gives you away when you are close enough.", fight = true},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "They see you coming from halfway across.", fight = true},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(4), "Came in cold on a crew that knew the trick.")
						return {text = "They spot you early and shoot first.", fight = true}},
				{label = "Give them fuel", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					return {text = "They take the fuel and send back one crate off an old hull.", material = &"wreck"}},
				{label = "Refuse the list", stay = true, effect = func() -> Dictionary:
					return {text = "They stop reading and hold station while you go."}},
			],
		},
		{
			id = &"six_years_waiting",
			title = "Six years waiting",
			subject = {stage = &"single", pieces = [&"ship_forked"], dark = 0.3, lights = &"run", fights = true},
			body = "A pilot has waited here six years for a registry two digits off yours and wants to read your drive.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 9,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Fake your drive reading",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						Run.heat += 12
						Run.add_credits(OptionTable.purse(14))
						return {text = "The reading matches nothing on file, and she pays for your hour of hot running."},
					clean = func() -> Dictionary:
						Run.heat += 16
						return {text = "The reading comes back wrong, and she lets you through."},
					partial = func() -> Dictionary:
						Run.heat += 20
						Run.drain_fuel(2)
						return {text = "The reading is unclear and she wants two more days, so you burn wide out of the crossing."},
					botched = func() -> Dictionary:
						Run.heat += 18
						return {text = "Your drive slips back to its own profile mid-reading, and she comes at you.", fight = true}},
				{label = "Tell her where it is", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(28))
					return {text = "You give her the bearing where you saw that number two rings out, and she pays and leaves."}},
				{label = "Decline the reading", stay = true, effect = func() -> Dictionary:
					return {text = "Her ship stays on station as you pass."}},
			],
		},
		{
			id = &"standing_orders",
			title = "Standing orders",
			subject = {stage = &"single", pieces = [&"r3_depot_fuel_depot_1"]},
			body = "An old automatic guard fires on any ship inside its arc around a fuel depot's eleven full tanks.",
			tags = [&"fight", &"hazard"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Slip under its arc",
					check = {attr = &"maneuver", need = 8},
					met = func() -> Dictionary:
						Run.fuel += 4
						return {text = "You keep under its arc for two hours and come out the far side."},
					clean = func() -> Dictionary:
						Run.fuel += 3
						Run.heat += 12
						return {text = "The arc catches up before the fourth tank, and you leave hot."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						Run.take_hull_damage(OptionTable.toll(2), "Shot by a depot guard nobody could call off.")
						return {text = "It puts a shot through your flank after one tank."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Flew across a depot guard's firing arc.")
						return {text = "Your line crosses the middle of the arc, and the guard fires before a tank opens."}},
				{label = "Destroy the guard", fight = true, effect = func() -> Dictionary:
					Run.heat += 12
					return {text = "You go straight at it, and it fires in the first second.", fight = true}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the depot and go around."}},
			],
		},
		{
			id = &"the_back_of_the_line",
			title = "The back of the line",
			subject = {stage = &"single", pieces = [&"r3_depot_fuel_depot_1"]},
			body = "Eleven ships wait at a fuel point with seven ships' worth left, and the line drains the last ship, which is you.",
			tags = [&"fight"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Jump the line",
					check = {attr = &"thrust", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 4
						return {text = "You pull your fuel and burn clear while the line is still arguing."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						Run.heat += 14
						return {text = "The two front ships start their drives, and you leave half full and hot."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						return {text = "The line closes on the point while you are still coupled.", fight = true},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Jumped a fuel line and got shot.")
						return {text = "You go late, and the first ship opens fire before you couple.", fight = true}},
				{label = "Buy tenth place", cost_credits = 40, effect = func() -> Dictionary:
					Run.add_credits(-40)
					Run.fuel += 2
					return {text = "The tenth ship names its price at once and moves to the back of the line."}},
				{label = "Wait your turn", stay = true, effect = func() -> Dictionary:
					return {text = "Four hours later a twelfth ship arrives and takes the back of the line."}},
			],
		},
	])
	return out
