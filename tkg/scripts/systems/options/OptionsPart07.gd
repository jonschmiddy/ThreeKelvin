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
			body = "Your grapple has been on a dead ore freighter for six hours. The cutter is still out on it. Two ships come in on your bearing and stop a kilometre off the bow. They were headed here before you were. The larger one hails to say the wreck is claimed. It is not. They say they are happy to wait, and they are not. What is left in the racks sits forward of the break. The break is the side those two ships have parked on.",
			tags = [&"fight", &"salvage"],
			group = &"",
			weight = 12,
			min_danger = 1,
			max_danger = 2,
			choices = [
				{label = "Cut forward of the break",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						return {text = "You work in tight against the break. Neither of them can follow without trading paint. The grapple takes a drive module still bolted to its frame. A bay of cut plate comes out with it. You are clear before the larger ship has finished its second hail. They watch you go and nobody fires.", material = &"wreck", module = true},
					clean = func() -> Dictionary:
						Run.heat += 5
						return {text = "You take the near racks fast and run the cutter hot to do it. One bay of plate goes aboard. The radiators shed for an hour after that. The two ships sit exactly where they were when you started.", material = &"wreck"},
					partial = func() -> Dictionary:
						return {text = "They drift in on either side of the break. There is no room left to work in. You back the grapple off with nothing in it. Neither ship hails again, and the larger one is on the racks before you have stowed the cutter."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The bow of a dead ore freighter, taken at the wrong angle.")
						return {text = "You commit to a gap narrower than the plate showed, and the freighter tears off a length of your bow. The two ships off the break do not move."}},
				{label = "Hold the wreck", fight = true, effect = func() -> Dictionary:
					return {text = "You put the ship between them and the break with the weapons live. They have spent six hours talking about waiting. In that time they decided they are owed this one. The larger ship comes first, and the smaller one comes around behind it.", fight = true}},
				{label = "Back off the hull", stay = true, effect = func() -> Dictionary:
					return {text = "You stow the cutter and let the grapple go. The larger ship is on the break before you clear the field. What was forward of it ends up in somebody else's racks."}},
			],
		},
		{
			id = &"the_wrong_writ",
			title = "The wrong writ",
			subject = {stage = &"single", pieces = [&"ship_courier2"], lights = &"patrol", fights = true},
			body = "A patrol boat comes up on your quarter with its lights going. It puts a stop order across the channel. The writ carries a registry prefix that matches yours. The hull number on it does not, and it is off by one digit. An office four rings inward issued it, and that office stopped answering queries in the spring. The pilot reads the order out twice. She is young and she means to do this properly. The ship the writ wants came through this ring an hour ahead of you.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 11,
			min_danger = 1,
			max_danger = 2,
			choices = [
				{label = "Put the registry record on the channel",
					check = {attr = &"sensors", need = 3},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You put your own registry entry across in the open. You send the office's numbering scheme with it. She reads both, reads the writ again, and stands the order down. Her service owes a held ship a set sum for a stop it cannot back up. She pays it out of the boat's account before she is done saying sorry."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(12))
						return {text = "It takes three calls and most of an hour. At the end of it she agrees the digit is the digit. She logs the fix and releases you. Her service posts a small fee for the time she took, and she pays it."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "She will not clear a hull on a record she cannot check. The office that could check it is not answering her either. You hold station a day and a half while she files upward. That costs one unit on the reactor. She lets you go without ever being told she was wrong."},
					botched = func() -> Dictionary:
						return {text = "You talk over her twice, and she takes it as a sign of guilt. The boat comes about with its bow mount live, and her writ covers whatever she does next.", fight = true}},
				{label = "Sit still for the inspection", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You hold station cold for most of a day while she scans your hold against a list for another ship. She finds nothing on it. Her stores owe a detained hull its rations, so she sends a case across before she goes.", material = &"event"}},
				{label = "Hold your heading", stay = true, effect = func() -> Dictionary:
					return {text = "You do not answer the order. You do not come off the throttle. The boat keeps your quarter for twenty minutes with its lights going. Then it drops back and goes looking for the hull number it was given."}},
			],
		},
		{
			id = &"the_far_side",
			title = "The far side",
			subject = {stage = &"group", ships = [{piece = &"role:passenger", dark = 0.55, lights = &"battery", at = Vector2(85.0, 20.0), z = 0}, {piece = &"ship_gunboat", fights = true, size = 0.5, dock = {to = 0}, at = Vector2(75.0, 0.0), z = 1}, {piece = &"role:small", fights = true, turn = 6.0, lights = &"run", at = Vector2(-118.0, 82.0), z = 2}, {piece = &"role:small", fights = true, far = true, turn = -5.0, lights = &"run", at = Vector2(-150.0, -68.0), z = -1}]},
			body = "A scavenger crew has a cutter ship anchored amidships on a passenger hull. Floods run the length of it and half the racks are already out. They watched you come in. Nobody hails and nobody stops working. Their two smallest ships have drifted out to sit between you and the wreck. Neither one quite points at you. The stern of the hull is dark, and nothing at all has come off it yet. They will get to it in a day or two.",
			tags = [&"fight", &"salvage"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Work the stern dark",
					check = {attr = &"stealth", need = 4},
					met = func() -> Dictionary:
						return {text = "You come in under their floods with the reactor down. The radiators point at nothing. The stern is yours for most of an hour. A drive module comes off its mounts, and a bay of cut plate comes with it. The cutter ship amidships never stops working.", material = &"wreck", module = true},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You get one bay of plate off the stern. Then the reactor has to come back up to move you. The bloom says plainly where you have been, and nobody comes after it. The plate is aboard and the floods stay pointed forward.", material = &"wreck"},
					partial = func() -> Dictionary:
						return {text = "One of the two small ships has been watching the stern the whole time. It does not bother to hail first. Amidships the cutter crew stops working to watch. The floods swing aft to give everyone a better look.", fight = true},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "The stern frame of a passenger hull, hit at speed in the dark.")
						return {text = "You come in dark at the wrong angle and hit the stern frame hard. You leave the wreck with a torn bow and nothing in the bay."}},
				{label = "Run your cutter on their seam", effect = func() -> Dictionary:
					Run.heat += 10
					return {text = "They take the offer on the second hail. They put you on the seam they were saving for last. You burn your own reactor on their wreck for a full shift. They cut you in for one bay of plate at the end of it. Then they go back to work, and nobody says a word about the stern.", material = &"wreck"}},
				{label = "Leave the stern to them", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and come about. You take the crossing you were on before the dish found the wreck. The two small ships hold their station between you and the hull. They stay there until you are well out of range."}},
			],
		},
		{
			id = &"the_open_toll",
			title = "The open toll",
			subject = {stage = &"single", pieces = [&"r3_depot_fuel_depot_1"], tumble = 1.0},
			body = "An automatic fuel platform turns slowly at the edge of the ring. It pumps for anyone who comes alongside. It has done that since the people who put it there stopped answering. Two ships sit off the intake with a rate card running on the open channel. They have a strobe across the approach. They did not build the platform and they do not maintain it. What they have is the intake. The nearest station that would care is nine days inward.",
			tags = [&"fight", &"signal"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Burn the approach and take the intake",
					check = {attr = &"thrust", need = 5},
					met = func() -> Dictionary:
						Run.fuel += 4
						return {text = "You come in high off the strobe and fast. You are coupled before either of them has finished coming about. The pumps do not ask who you are. You leave with four more units in the tank. The rate card is still repeating on the channel behind you."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						Run.heat += 6
						return {text = "You take the approach hot and get two units across. The nearer ship closes in until the coupling gets awkward. You break off with the radiators loaded. The pumps keep running for whoever comes next."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						return {text = "They get a hull across the intake before you have much across. You come off the coupling with one unit. They go back to their station off the arm."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "The intake arm of a fuel platform, hit at full burn.")
						return {text = "You commit to the approach at full burn. The intake arm is not where the old plate said. The platform keeps turning and keeps pumping. You come off it with a fold in the bow and the tank no fuller than it was."}},
				{label = "Push them off the intake", fight = true, effect = func() -> Dictionary:
					return {text = "You attack the two ships instead of going for the platform. They have relied on the rate card for a long time, and they are slow to respond.", fight = true}},
				{label = "Keep clear of the intake", stay = true, effect = func() -> Dictionary:
					return {text = "You take the long way around the platform, well outside the strobe. You leave the ring on the tank you came in with. The rate card repeats on the channel until you are out of range."}},
			],
		},
		{
			id = &"nothing_taken",
			title = "Nothing taken",
			subject = {stage = &"group", fights = true, flood = true, ships = [{piece = &"role:hauler", far = true, at = Vector2(-120.0, -60.0)}, {piece = &"role:hauler", far = true, at = Vector2(140.0, -55.0)}, {piece = &"ship_armedtrader", at = Vector2(10.0, 35.0), z = 1}]},
			body = "Three haulers come out of the ring together and put their lights on you. Someone took eleven containers off the second of them four days ago. The ship that did it was the same class as yours, with the same drive signature. They have stopped every ship of that class since. The woman speaking for them is tired and polite, and she is sure of what she is looking at. They will not shoot first, but they will not stand aside either.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Run the reactor down and let them read it",
					check = {attr = &"thermal", need = 5},
					met = func() -> Dictionary:
						return {text = "You take everything down to the hull and hold it there. Three sets of instruments agree that this ship has not burned hard in a week. She says sorry in one sentence. Then she gives you a bearing eleven minutes old. The hull they want crossed the ring behind them while they were stopping you. She asks whether you are still cold enough to get close to it.", fight = true},
					clean = func() -> Dictionary:
						return {text = "The read settles slowly and it settles clean. She takes a minute over it. Then she says so on the open channel, where the other two can hear her. She pulls the lights off your bow. The three of them go back to stopping ships."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "The radiators will not come down far enough for the reading to settle. She will not clear a hull she cannot rule out. You take the long way out of the ring and burn two units doing it. Two of the three hold your bearing for six hours. The third sits somewhere behind the moon."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A warning shot from a hauler crew that had made up its mind.")
						return {text = "You come up hot in the middle of the reading, and all three read that the same way. The shot is meant as a warning and it lands as a hit. She says nothing after that. The lights stay on you until you are out of the ring."}},
				{label = "Sell them an escort to the crossing", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(26))
					return {text = "She does not clear you, but she does not want to spend the afternoon on it either. She wants the only armed hull in the ring flying where she can see it. You burn alongside the three of them to the crossing. They pay the rate they would pay anyone, and no one mentions the containers again."}},
				{label = "Decline the stop", stay = true, effect = func() -> Dictionary:
					return {text = "You tell her what class of hull you fly. You tell her you are not the one she wants. Then you hold your heading through the middle of the three of them. Nobody follows. The eleven containers are somewhere in the ring, and the haulers are still stopping ships."}},
			],
		},
		{
			id = &"the_licensed_seam",
			title = "The licensed seam",
			subject = {stage = &"single", pieces = [&"paint_rock_b3"], r = 120.0},
			body = "You are half a shift into a nickel face on a rock nobody has filed on. Three ships come up from the dark side of it in formation. The outfit flying them has held the licence here for nine years. They have worked the rock for two of those. The filing is the first thing they put on the channel. Their smallest ship is bigger than yours. There are three of them. The face under your cutter is the best one on the rock.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			choices = [
				{label = "Hold the anchor and finish the cut",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "They come in to lean on you and the ship does not move. Twenty minutes of that changes what the foreman is asking for. He buys the loose half of the cut, at a rate that costs him less than another hour of this. The rest of it stays in your bay. The anchor holds until you decide to move it.", material = &"mining"},
					clean = func() -> Dictionary:
						return {text = "You get the face off the rock clean. The grapple is still walking it in. Their smallest ship comes around the near limb with its mount live and its lights off. The foreman is not on the channel any more. The ore still hangs between the rock and your bay.", fight = true},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "They put two hulls across the face and hold them there. They are close enough that your radiators have nowhere clean to point. You spend an hour of reactor deciding whether to push it. Then you stow the cutter. The cut stays on the rock, most of the way free of it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "The overhang over the seam, shaken down by a ship's wash.")
						return {text = "You hold the anchor well past the point where it means anything. The second ship comes in close. It puts its wash across your bow. The overhang above the seam comes down on top of that. You come off the rock with a bent bow and nothing in the bay."}},
				{label = "Buy a day on their licence", cost_credits = 50, effect = func() -> Dictionary:
					Run.add_credits(-50)
					return {text = "The foreman has a rate for this and quotes it without checking anything. He has quoted it before. You pay for the day and finish the cut. Three of their ships hold station close enough to watch every pass of the cutter. You come off the rock with the bay of nickel the face was worth.", material = &"mining"}},
				{label = "Leave them the face", stay = true, effect = func() -> Dictionary:
					return {text = "You stow the cutter and back off the rock with half a shift spent and the bay empty. They are on the face before you clear the limb, without a word on the channel."}},
			],
		},
		{
			id = &"the_wreckers",
			title = "The wreckers",
			subject = {stage = &"single", pieces = [&"r4_lightmast_false_light_1"]},
			body = "A crew works this crossing with a false light. They hang it off a rock where a station light would be, with nothing behind it. They have done this long enough that the hulls past the rock are bare frames. Two ships sit in the rock's shadow with drives idling and lights off. The light still sends a dock code retired forty years ago. No patrol has come this deep for a long while.",
			tags = [&"fight", &"salvage"],
			group = &"",
			weight = 10,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Read the rock against the real bearing",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						return {text = "The code is forty years dead. The rock it comes off has no dock. You work the far side of the field instead. The frames out there are old and the two ships are not. The grapple takes a sealed unit out of one rack and a crate out of another. Both ships are still holding station on the light when you leave.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You find the true bearing under the false one. You work the oldest hull in the field, far enough out that nobody comes to look. One crate comes off it. The reactor ran warm the whole time you were alongside.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "The two bearings will not separate. You spend three hours on a dish that keeps agreeing with itself. The frames out past the rock have all been picked over already. The ship is hot from the looking."},
					botched = func() -> Dictionary:
						Run.heat += 8
						return {text = "Your strong return across the field gives you away. They have waited on that light for eleven days with nothing to show for it. Both ships come out of the rock's shadow with drives lit.", fight = true}},
				{label = "Burn wide and work the far frames", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You take the long way in, around the outside of the field. It costs two units and keeps the rock between you and them. The outermost hull is the oldest, and the only one they have not finished. One crate comes off it. You are gone before either ship trims its attitude.", material = &"wreck"}},
				{label = "Leave the light burning", stay = true, effect = func() -> Dictionary:
					return {text = "You log the false code and the bearing it sits on. You go around wide of both. The light is still running when your dish loses the rock, and neither ship has moved."}},
			],
		},
		{
			id = &"the_hunting_ship",
			title = "The hunting ship",
			subject = {stage = &"single", pieces = [&"ship_scoop"], lights = &"run", fights = true},
			body = "A ship rigged for a hunt is coming across the system at you. It has wide holds and a frame on the bow for taking something aboard whole. There is nothing in any of it. The people flying it have been out five months. What they came for has not been where the charts put it since spring. They have said so on the open channel to nobody in particular. They read your mass at a hundred thousand kilometres and turn toward it. The hail is friendly and it asks twice what you are carrying.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 10,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Hold station and let them come alongside",
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "They come in close and spend twenty minutes reading your plating. What they read is a ship that would cost them theirs. The tone changes after that. They buy the bearing you came in on, at a price nobody argues with. They have five months of pay aboard and nothing out here to spend it on."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						return {text = "They look you over and decide against whatever they were deciding. They buy the bearing you came in on rather than leave with nothing. It is less than the bearing is worth. You take it anyway."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.add_credits(OptionTable.purse(6))
						return {text = "They hold alongside for most of a day and cannot decide. You hold with them and burn two units doing it. At the end of it they pay for the bearing, badly. They go on across the system with the frame on the bow still empty."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A hunting ship found the plating thin and put a shot through it.")
						return {text = "They come in closer than alongside and put one through your flank. They wanted to see what the plating does, and it gives. They ask a third time what you are carrying. You are already burning out of the system by then."}},
				{label = "Burn in on their bow first", fight = true, effect = func() -> Dictionary:
					Run.heat += 10
					return {text = "You put the throttle down and close on them. Their ship has wide holds and a frame for cargo. It does not have much else. Five months of nothing has made them slow to answer a change of plan. The reactor takes the whole cost of the run in.", fight = true}},
				{label = "Answer both hails and hold your heading", stay = true, effect = func() -> Dictionary:
					return {text = "You say what you are carrying, plainly, and keep your heading. They pace you to the edge of the system. They are working out whether the answer was worth anything. Then they turn back to the search. They are still on the open channel when your dish loses them."}},
			],
		},
		{
			id = &"the_long_crew",
			title = "The long crew",
			subject = {stage = &"single", pieces = [&"ship_ringdrive"], lights = &"battery", fights = true},
			body = "A ship hails you. It stopped being a business a long time ago. They have been out here nineteen years. The registry ran out twelve years back, and the manufacturer that built the ship is gone too. The same people have been aboard the whole time. They do not call it a raid. They read you a list of what they need, in order, and they stay armed while they read it. There are forty items on the list. The first one is fuel.",
			tags = [&"fight"],
			group = &"",
			weight = 9,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Come at them dark", fight = true,
					check = {attr = &"stealth", need = 7},
					met = func() -> Dictionary:
						return {text = "You go cold and come in off their blind quarter while the list is still being read. For nineteen years they have been the only armed ship in every talk, and they are slow to respond.", fight = true},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You get most of the way in cold before the reactor gives you away. That is close enough for what you came to do. They break off the list part way through an item. They light their drives.", fight = true},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "You lose the dark halfway across. They watch you come for the rest of it. The list stops part way through the fourth item, and the reactor is hot from holding everything down.", fight = true},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(4), "Came in cold on a crew with nineteen years of practice at it.")
						return {text = "You are lit up before you are halfway across. This has been done to them before, and they know what it looks like from a long way off. They shoot first and finish the list afterwards.", fight = true}},
				{label = "Give them the first item and keep the rest", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					return {text = "You put three units across and tell them the other thirty-nine items are not your problem. They take the fuel and the answer. Then they send one crate back, off the hulls they have worked since the registry ran out.", material = &"wreck"}},
				{label = "Refuse the list", stay = true, effect = func() -> Dictionary:
					return {text = "You tell them no, and they take it as they have before. They stop reading and go quiet. They hold their station, and you hold your heading."}},
			],
		},
		{
			id = &"six_years_waiting",
			title = "Six years waiting",
			subject = {stage = &"single", pieces = [&"ship_forked"], dark = 0.3, lights = &"run", fights = true},
			body = "A ship has been holding this crossing for six years. What it is waiting for is a registry. It sends that registry out on a loop, one line, over and over. The number is two digits off yours. The voice under the loop is not angry about anything. She asks you to hold still and let her instruments read your drive. A drive signature is the one thing on a ship that cannot be repainted. She has been almost sure for six years.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 9,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Run the reactor off its profile and let her read it",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						Run.heat += 12
						Run.add_credits(OptionTable.purse(14))
						return {text = "You push the reactor outside the envelope it was built for. You hold it there while her instruments work. What comes back matches nothing anybody has a file on. She says sorry, plainly and once. Then she pays you for the hour your reactor ran hot."},
					clean = func() -> Dictionary:
						Run.heat += 16
						return {text = "You hold the reactor off its profile long enough for the reading to come back wrong. The loop stops. She tells you to go on through the crossing. The reactor takes an hour to come back down to where it belongs."},
					partial = func() -> Dictionary:
						Run.heat += 20
						Run.drain_fuel(2)
						return {text = "The reading comes back unclear. That is no use to either of you, and she asks for two more days of it. You do not have two days. You burn wide out of the crossing with the loop still running behind you."},
					botched = func() -> Dictionary:
						Run.heat += 18
						return {text = "The profile slips back into its own shape halfway through the reading. What her instruments get is close enough to six years of waiting. Nothing is said after that. The loop stops and the ship comes about.", fight = true}},
				{label = "Tell her where that registry is working now", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(28))
					return {text = "You have seen that number on a hull two rings out. It was working a run it has no business working. You give her the bearing and the date. She pays out of an account that has been filling for six years. The ship lights its drives while the payment is still clearing. The crossing is empty behind it."}},
				{label = "Decline the reading", stay = true, effect = func() -> Dictionary:
					return {text = "You tell her no and hold your heading past the crossing. The loop follows you on the open channel for an hour. It is one line, over and over, and then the range takes it. The ship does not move off its station."}},
			],
		},
		{
			id = &"standing_orders",
			title = "Standing orders",
			subject = {stage = &"single", pieces = [&"r3_depot_fuel_depot_1"]},
			body = "A fuel depot sits on the approach with eleven tanks still reading full. In front of it, on station, is an automatic guard with a firing arc. It sends a challenge every ninety seconds and wants a code back. The code belongs to an authority that stopped issuing anything long ago, and no ship since has been able to give it. It does not talk or stand down, and no one is left to order it to.",
			tags = [&"fight", &"hazard"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Take the tanks from inside its arc",
					check = {attr = &"maneuver", need = 8},
					met = func() -> Dictionary:
						Run.fuel += 4
						return {text = "You go in under the arc and stay under it. That means never being where it is pointed, and never stopping. Two hours of that gets you four units off four tanks and out the far side. The challenge is still going out every ninety seconds behind you."},
					clean = func() -> Dictionary:
						Run.fuel += 3
						Run.heat += 12
						return {text = "You get three tanks open before the arc catches up with the line you are flying. You leave the fourth, and three units come across. The ship is hot from two hours of flying that way."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						Run.take_hull_damage(OptionTable.toll(2), "Inside the firing arc of a thing no one can call off.")
						return {text = "You get one tank open and one unit across. Then it puts a shot through your flank and you break off the transfer. The challenge goes out again on schedule while you back away."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Crossed the firing arc of a thing left on station with old orders.")
						return {text = "You put your line through the middle of the arc. It does the one thing it was left here to do. You come out of the approach with nothing off the tanks. There is a hole where the transfer line was going to go."}},
				{label = "Put it down and take the depot at leisure", fight = true, effect = func() -> Dictionary:
					Run.heat += 12
					return {text = "You stop trying to fly around it and go straight at it. It fires within the first second. The reactor is already hot from the run in.", fight = true}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the depot, the arc and the eleven full tanks, and go around them."}},
			],
		},
		{
			id = &"the_back_of_the_line",
			title = "The back of the line",
			subject = {stage = &"single", pieces = [&"r3_depot_fuel_depot_1"]},
			body = "Eleven ships hold a line off a fuel point that has about seven ships' worth left. The order is the order they arrived in, and the log records it. Every ship out here still keeps to the log. When the point runs dry, the line takes what it needs from the ship at the back. Every ship ahead of you agreed to that. You arrived a minute ago, and you are eleventh.",
			tags = [&"fight"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Take your fuel before your number comes up",
					check = {attr = &"thrust", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 4
						return {text = "You break the order and reach the point ahead of them. The line spends four minutes deciding whether the deal covers this. It does not. You pull four units and you are past them and burning. The ninth ship is still saying so on the channel."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						Run.heat += 14
						return {text = "You reach the point first and pull two units. The two ships at the front of the line start their drives. You leave with half of what you wanted. The drive is hot from getting out of their way."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						return {text = "You get one unit across before the line closes on the point with you still on the transfer line.", fight = true},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Cut the line at a deep fuel point and got shot for it.")
						return {text = "You commit late. Four of them are already moving when you reach the point. The first one opens up before you are on the transfer line at all.", fight = true}},
				{label = "Buy the tenth place off the ship ahead of you", cost_credits = 40, effect = func() -> Dictionary:
					Run.add_credits(-40)
					Run.fuel += 2
					return {text = "The ship at ten knows exactly what its place is worth. It names the figure before you have finished asking. You pay and the log is amended. When your number comes up there are two units left in the point. The ship that was at ten is at eleven now, and it knew that when it took the money."}},
				{label = "Hold your number and wait", stay = true, effect = func() -> Dictionary:
					return {text = "You sit at the back of the line with your drives cold and the transponder on. Four hours later a twelfth ship arrives, logs its arrival, and takes the back of the line from you."}},
			],
		},
	])
	return out
