class_name OptionsPart08

## Encounters 103 to 118 of the authored table (`seized_clamp` to `the_core_drill`), in the order `OptionTable._authored`
## joins them: `roll_for` draws by table order, so entries never move between or within files.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{
			id = &"seized_clamp",
			title = "The clamp",
			subject = {stage = &"structure", pick = true, pieces = [&"st_dock_face_1", &"st_dock_face_2", &"st_dock_face_3", &"st_dock_face_4"], grip = {at = "collar"}},
			body = "The dock is four clamps wide and one of them has you. Its release motor burned out while you were loading. The woman on the counter says the yard crew comes through on the ninth, four days out. She is not sorry, and she is not charging you for the days. The clamp holds your collar and a metre of plating around it. Your drives can pull a ship this size off a dead clamp if the collar holds. You cannot see the collar from where you sit.",
			tags = [&"hazard"], site = &"world",
			group = &"",
			weight = 10,
			min_danger = 1,
			max_danger = 2,
			needs_berth = true,
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Pull off the dead clamp",
					check = {attr = &"thrust", need = 4},
					met = func() -> Dictionary:
						return {text = "You bring the drives up slowly and hold them there. The clamp gives before your collar does. The arm shears at its own pin and comes away with you, still shut. The grapple walks it into the hold. The woman on the counter logs the clamp as lost along with its motor.", material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "It lets go on the third pull, all at once. You are off the dock and drifting before the drives are back down. Nothing is bent. The collar reads the way it read yesterday. The clamp sits open behind you with its motor still dead."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Pulled off a dead clamp and left the collar in its jaws.")
						return {text = "You come off, but a small piece of plating around the collar stays in the clamp, and it was holding something. The woman on the counter watches from behind the glass and logs none of it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A dead clamp held on and the collar came out of the hull.")
						return {text = "You go to full against a clamp that will not open, and the collar goes first. It takes plating with it on the way out. The clamp is still shut around what is left of it. You are a kilometre off the dock by then."}},
				{label = "Cut the arm off at its mount", effect = func() -> Dictionary:
					Run.heat += 8
					return {text = "Four hours on the cutter with the reactor up the whole time. The mount was built to be replaced and never to be removed. The arm comes off in one piece with your collar still in its jaws. You keep it. The yard has no use for a clamp with a burned motor and a cut mount.", material = &"wreck"}},
				{label = "Wait for the yard crew", stay = true, effect = func() -> Dictionary:
					return {text = "You spend four days on the dock with the drives cold. On the ninth the yard crew comes through with a cart of motors. They swap the dead one in about twenty minutes, charge you nothing, and move on down the row."}},
			],
		},
		{
			id = &"the_split_loop",
			subject = {stage = &"single", pieces = [&"ship_orbitarms"], lights = &"run", at = Vector2(20.0, 0.0)},
			title = "The split loop",
			body = "Two hours out from the station the reactor runs warmer than the board says. The loop is why. There is a split in the coolant line forward of the pump. It is thin and wet and getting longer while you watch. Two hours back is two hours you would rather not fly twice. A supply tender works this lane. It sells to ships that find things out late. The woman running it has a rack of loop sections aboard. Her price does not move.",
			tags = [&"hazard"],
			group = &"",
			weight = 11,
			min_danger = 1,
			max_danger = 2,
			min_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Sleeve the split with the pump running",
					check = {attr = &"thermal", need = 4},
					met = func() -> Dictionary:
						Run.fuel += 1
						return {text = "The sleeve seats on the first try, and the loop holds at pressure. The reactor is back to normal inside the hour. You fly on and save the fuel of a trip back to the station."},
					clean = func() -> Dictionary:
						Run.heat += 5
						return {text = "The sleeve seats on the third try. The loop runs low the whole time and the heat goes nowhere. It holds. You go on warm and you stay warm for the rest of the day. The number on the board does not climb any further."},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "The sleeve will not seat while the pump is running. You run the loop at half pressure instead. You go on with the reactor hotter than it has been all week. The split stays where it is for the whole afternoon."},
					botched = func() -> Dictionary:
						Run.heat += 10
						Run.take_hull_damage(OptionTable.toll(3), "A coolant line opened at the pump with the reactor still hot.")
						return {text = "The line lets go at the pump while you have it open. What was in it goes out through the mount. It takes the plating behind it. You shut the loop down and the reactor with it. The rest of the day goes on cooling."}},
				{label = "Buy a section off the tender", cost_credits = 30, effect = func() -> Dictionary:
					Run.add_credits(-30)
					return {text = "She names her price and gets it, since no one else out here sells loop sections. It comes as a whole unit with the pump end included, ready to fit. She watches it aboard, then goes looking for the next ship running warm.", module = true}},
				{label = "Turn back and patch it cold", stay = true, effect = func() -> Dictionary:
					return {text = "You fly the two hours back and sit at the station. The reactor goes down and the loop drains. You put a proper sleeve on a line that is not moving. It takes the afternoon and most of the evening. The loop reads clean when you light the reactor again."}},
			],
		},
		{
			id = &"the_scatter",
			title = "The scatter",
			subject = {stage = &"field", pieces = [&"r4_scatter_torn_plate_1", &"r4_scatter_cabin_section_1", &"r4_scatter_drive_nozzle_1", &"r5_scatter_spar_2", &"r4_scatter_tank_half_2", &"r4_scatter_torn_plate_2"], count = 6, near = 2, deep = 2, turns = 35.0, band = -14.0, span = 430.0, height = 200.0, seed = 9, tumble = 6.0},
			body = "Two ships touched in the approach lanes six days ago. The pieces are still coming through. A traffic office on the station calls the crossings. It calls one every twenty minutes on the open channel. It gives the bearing, the spread, and how wide the gap is. Most of the scatter is too small for the hull to notice. Some of it is plate a metre across and turning. The dish loses a piece like that against the station's own returns. The gap the office is calling now is eleven minutes wide.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 10,
			min_danger = 1,
			max_danger = 2,
			min_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Read the spread and cross",
					check = {attr = &"sensors", need = 3},
					met = func() -> Dictionary:
						return {text = "You hold off and put the dish on the spread for a full pass. By the time you move you know where every piece of it will be. You take the gap with time to spare. The grapple takes a plate on the way through. It comes aboard turning and is still by the time you are clear.", material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You cross on the office's numbers and nothing comes near you. Two pieces go past behind you, both small, both counted. The office is calling the next gap while you are still clearing the lane."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "You are into the gap before the dish finds a piece the office never counted. You spend the rest of the crossing burning to stay behind it. You come out where you meant to. The tank is one unit down and the grapple is empty."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A plate a metre across, turning, six days out of a wreck.")
						return {text = "You cross on a gap the office called twenty minutes ago. The piece that finds you turns slowly enough to watch it come in. There is not enough of the gap left to be anywhere else. It goes into the forward plating and stays there."}},
				{label = "Work the near edge of the spread", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You put yourself well off the lane, on the near edge. The pieces there are thin and slow. You burn to stay in place while the office works through two more crossings. The grapple gets one piece of somebody's hull plating. It is big enough to be worth the burn.", material = &"wreck"}},
				{label = "Wait for the office to call it clear", stay = true, effect = func() -> Dictionary:
					return {text = "The office says two more days before the lane is worth calling clear. You spend them out of everybody's way with the drives cold. On the second afternoon a tug starts working the lane from the station end. It picks pieces up and stacks them on a line."}},
			],
		},
		{
			id = &"the_parted_line",
			title = "The parted line",
			subject = {stage = &"structure", pick = true, pieces = [&"st_dock_face_1", &"st_dock_face_2", &"st_dock_face_3", &"st_dock_face_4"], with = [{piece = &"ship_lightfreighter", scale = 0.5, turn = -62.0, tumble = 1.0, at = "lug0", off = Vector2(-8.0, 69.0)}], lines = [{from = "lug0", to = 0, to_at = [186, 30]}, {from = "lug1", to = 0, to_at = [184, 54]}], parted = {from = "lug2", len = 38.0, lean = -10.0}},
			body = "A cargo lighter is moored to the loading mast outside the station. Its load has moved. Forty tonnes of something has come off its tethers and gone to one end of the hold. The lighter hangs nose down. One mooring line has parted and drifts beside it. The woman flying it asks on the open channel for a ship with a grapple. She wants the low end held for twenty minutes while she runs a new line. The mast is older than she is and the load is still settling.",
			tags = [&"hazard", &"contract"], site = &"world",
			group = &"",
			weight = 9,
			min_danger = 1,
			max_danger = 2,
			needs_berth = true,
			min_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Take the strain on the grapple",
					check = {attr = &"hull", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You get the grapple on the low end and hold it there. Your frame carries forty tonnes of somebody else's cargo for twenty minutes. Nothing on the board complains. She runs the new line, then a second one. Then she tethers the load again with the mast crew watching. She pays you what she would have paid a tug."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "You hold the low end for twenty minutes and the frame complains twice. She gets one line on, and that is enough to stop the swing. She pays you out of what she keeps aboard. It is less than a tug would have charged."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(8))
						return {text = "The load moves again while you have the strain on. The lighter comes around on the grapple. You let it go before it takes you with it. She gets a line on an hour later on her own, with the load where it ended up. She pays you for the hour you spent on it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Forty tonnes of cargo on the end of a grapple line.")
						return {text = "The load goes all the way to the low end while you have the strain on. The lighter takes the grapple line with it. The line comes back across your flank before the winch lets go. It takes plating on the way past."}},
				{label = "Push the low end up on thrust", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You put your nose under the low end and hold it up on a long steady burn. It costs fuel. It gives her a lighter that is not swinging. She gets both lines on in the time it takes. She has nothing aboard to pay you with. She signs over a case off the load and the mast crew logs it as damaged in transit.", material = &"event"}},
				{label = "Call it in for her", stay = true, effect = func() -> Dictionary:
					return {text = "You put it on the open channel to the station. You give them the mast, the parted line, and the way the lighter hangs. The traffic office says a tug is an hour out and already tasked. She is still talking to them when you lose the channel."}},
			],
		},
		{
			id = &"the_cooling_loop",
			title = "The cooling loop",
			subject = {stage = &"single", pieces = [&"role:mining"], lights = &"battery"},
			body = "A mining ship forty kilometres off has lost its cooling loop. The reactor is shut down and the crew are calm about it. A reactor that has just gone down still puts out heat. That heat has to go somewhere and theirs has nowhere to go. The pilot puts the numbers on the open channel. There are two coolant lines and one of them is split. The split sits behind the shielding, where none of their own instruments reach. They have about four hours to cut the right one. Your dish reads a hull from outside.",
			tags = [&"hazard", &"contract"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Put the dish on their hull",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You read their hull from the drives forward, warm against cold. The split shows as a cold patch two metres long aft of the shielding. You give them the frame number. They cut that line and the loop comes back on the half that is left. The temperature stops climbing while you are still watching. The pilot pays out of the ship's account and stays on the channel, talking about nothing."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(24))
						return {text = "The hull reads cold in two places. You cannot say which one is the split and which is the shadow of a tank. They cut both lines and run the loop on what is left. That holds the temperature flat and does not bring it down. It will be somebody's problem at the next dock. They pay you for the half of the work you did."},
					partial = func() -> Dictionary:
						Run.fuel += 2
						return {text = "Your dish will not separate the two lines at this range. You will not guess for them. You give them the bearing of the warmest plating. They cut on that, and it is the right line. Nobody aboard will ever be sure whose call it was. They have nothing in the account worth sending. They pump two units of fuel across instead."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Sat alongside a mining ship while its reactor cooked.")
						return {text = "You call the aft line and they cut it. The aft line was the good one. What is left of the loop goes down inside four minutes. The crew get clear in a boat. The ship opens in one place and stays whole everywhere else. You are close enough that a sheet of it reaches you before you turn away."}},
				{label = "Take their cargo off while they work", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "They would rather it went with somebody than went down with the ship. They say so plainly and ask nothing for it. Their hull is holding its attitude badly. Matching it costs you an hour of small corrections and the fuel to make them. One load comes across on the grapple: their stores, their spare seals, a crate of instrument film nobody has opened. The loop is still down when you pull away.", material = &"event"}},
				{label = "Pass the hail inward", stay = true, effect = func() -> Dictionary:
					return {text = "You put their position and their numbers on the relay, at a priority no one this far out honours, and fly on. No reply comes back while you are still in range."}},
			],
		},
		{
			id = &"the_front",
			subject = {stage = &"fx", fx = &"front"},
			title = "The front",
			body = "Something let go an hour ago, a long way off your track. The dish has been reading what came out of it ever since. Gas, grit and plate, in a shell, spreading out. The leading edge reaches you in about twenty minutes. The shell is wide. Clean sky is two days of burning to either side. The edge will be thin by the time it gets that far. It is not thin here. Nothing is transmitting from where it started, and the chart has nothing there to transmit.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Turn the heavy side to it and hold",
					check = {attr = &"hull", need = 4},
					met = func() -> Dictionary:
						return {text = "You put the keel and the tanks between the front and everything soft. It arrives as four minutes of gravel on the plating and one long push. When it is past, the ship is where it was. The sky behind it is full of what the shell was carrying. All of it goes the same way at the same speed. The grapple takes plate off the near stuff. Then it takes a module, still racked in its frame and coasting with the rest.", material = &"wreck", module = true},
					clean = func() -> Dictionary:
						return {text = "The heavy side takes it. The plating rings for four minutes and then stops. Nothing is bent that was not bent before. You spend the hour afterwards picking plate out of the sky behind the front. It all ends up there, moving at the same speed and going the same way.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 9
						return {text = "You are still coming around when the edge arrives. It catches the radiators broadside. Whatever let go was hot and the front is still carrying that heat. The ship holds it now. The grit goes past. You come out the other side with nothing aboard and an hour of shedding to do."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A sheet of hull plate, at the speed of whatever let it go.")
						return {text = "The front arrives while the ship is still beam on to it. Gravel hits first, then a sheet of plate the size of a cargo door, tumbling. It goes into the flank, and the frames stop it."}},
				{label = "Put the nearest rock between you and it", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "The rock is eleven minutes away under a hard burn. It is not large and it does not have to be. You sit in its lee while the front goes past on both sides. It rings the far face of the rock for four minutes. There is nothing else to do in that time. The cutter takes a load of ice off the shaded side while you wait.", material = &"mining"}},
				{label = "Turn around and run with it", stay = true, effect = func() -> Dictionary:
					return {text = "You put the drives toward the front and run outward ahead of it. It takes six hours to catch you and it is thin by then. Grit on the plating, a reading on the dish, and nothing else. The sky you meant to cross is behind all of it now. You will come at it from the other side."}},
			],
		},
		{
			id = &"the_ice_stream",
			subject = {layers = [{stage = &"fx", fx = &"stream", from = Vector2(-215.0, -112.0), to = Vector2(215.0, -8.0), width = 30.0}, {stage = &"field", pieces = [&"paint_rock_a1", &"paint_rock_b3", &"paint_rock_a2", &"paint_moon_ice", &"paint_rock_b4", &"paint_rock_a1", &"paint_rock_b3", &"paint_moon_europa", &"paint_rock_a2", &"paint_rock_b4"], count = 10, near = 10, r = [4.0, 9.0], band = 14.0, span = 430.0, height = 46.0, seed = 17, tumble = 0.0, at = Vector2(0.0, -60.0)}]},
			title = "The ice stream",
			body = "A stream of ice and rock crosses the sky ahead. Its orbit brings it through here once every nine years, and this is the year. The head of it reaches your track in about six hours. The band is wide. Going around it costs two days of fuel. In the middle it is thick enough that the dish stops counting pieces and calls it one. Most of it is water ice with grit frozen through. That is worth carrying and worth burning. The fast pieces run out in front.",
			tags = [&"hazard"],
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Burn across ahead of the head",
					check = {attr = &"thrust", need = 5},
					met = func() -> Dictionary:
						Run.fuel += 2
						return {text = "You are across the track and past it with an hour to spare. That puts you outside the stream with the whole leading edge coming to you at walking pace. You work it for most of a day. Water goes into the tank as fast as the cutter can free it. A load of the grit-bearing ice goes into the hold behind that.", material = &"mining"},
					clean = func() -> Dictionary:
						return {text = "The burn starts late and runs long. You cross with the first pieces already going past, close enough to count. On the far side you take what the stream sheds. One load of ice with rock frozen through it comes from the slow, thin edge.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You misjudge how far ahead the fast pieces run, and you spend the whole burn correcting for them. You come out clean on the far side, with less fuel than you planned and an empty hold."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A rock crossing the other way, at the speed of an orbit.")
						return {text = "The dish counts the big pieces all day. It gives you no trouble with them. A piece the size of a bolt comes out of the head of the stream. It arrives at the sum of two orbital speeds and goes into the bow. The frames behind the bow stop what is left of it. The stream keeps going past for another day and a half."}},
				{label = "Sit off the flank and fish the thin edge", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You hold station off the flank for a day and a half, burning to stay level. You take what comes off the outside of the stream, where the pieces are slow and far apart. One load of ice and grit goes into the hold, and the hull is never touched.", material = &"mining"}},
				{label = "Wait for the whole stream to pass", stay = true, effect = func() -> Dictionary:
					return {text = "You sit still for a day and a half while the stream goes by. When the sky is clear you cross, later than you meant to and with nothing new aboard."}},
			],
		},
		{
			id = &"the_venting_hold",
			title = "The venting hold",
			subject = {stage = &"field", pieces = [&"r2_container_freight_box_1", &"r2_container_freight_box_2"], count = 6, near = 3, span = 360.0, height = 170.0, seed = 5, tumble = 3.0},
			body = "A container ship is holed low on one flank. Its hold is coming out through the hole. The jet is steady and it has been turning the ship for some time. One slow turn every three minutes, containers and all. The dish reads the vapour as fuel grade. Anything hot enough will light it. Your radiators are the hottest thing for a long way in any direction. The tank behind the hole runs dry in about a day. The containers on the high side are sealed and nobody has been at them.",
			tags = [&"hazard", &"salvage"], site = &"derelict",
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Match the turn and work the high side",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						return {text = "You go around with it, three minutes a turn, always on the side the jet is not. You stay there two hours. The racks on the high side are open to space. One of them still has a module seated in it, tagged for a hull twice this size. The grapple lifts it out between turns. The ship goes on turning without it.", module = true},
					clean = func() -> Dictionary:
						return {text = "Matching the turn takes longer than the turning does. It eats the time you meant to spend working. One container comes free before the jet swings back around toward you. It is sealed and heavy, the stores a ship this size carries for a year. You take it and get out of the arc.", material = &"event"},
					partial = func() -> Dictionary:
						Run.heat += 8
						return {text = "You come around a half turn behind the whole way and cross the jet twice. Nothing lights. What settles on the radiators does not burn and does not leave. The ship carries that heat out of the arc. The hold is as empty as it went in."},
					botched = func() -> Dictionary:
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(4), "A jet of fuel vapour, lit off the hot radiators.")
						return {text = "You cross the jet with the radiators facing it and the vapour finds them. It goes up along the whole length of the plume in about a second. The ship is inside that for most of it. The fire takes the radiators and then the plating under them. After that the heat stays aboard with nowhere to go."}},
				{label = "Stand off the arc and cut one container free", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You work from outside the turn. That means matching a container that comes past once every three minutes. You cut only at the near point. It takes four passes and the fuel to make them. One comes away on the fourth: sealed, full of stores, untouched since the day it was loaded.", material = &"event"}},
				{label = "Give it the day and go", stay = true, effect = func() -> Dictionary:
					return {text = "The tank runs dry sometime in the next day. After that it is a ship with a hole in it, turning at whatever rate the jet left it. You log the drift and the heading for whoever is behind you. The containers on the high side will still be sealed then."}},
			],
		},
		{
			id = &"four_on_one_hull",
			title = "Four on one hull",
			subject = {stage = &"single", pieces = [&"role:family"], lights = &"run", drive = true},
			body = "A family hull crosses your track with one drive dark. The other runs rich to cover for it. Four of them aboard, two old enough to fly it, nineteen years on this ring taking one charter at a time. The load was made up for two drives. On one, the burn out of this system costs fuel they did not budget for. It also costs hours their delivery window does not have. The oldest of them lays all of that out on the open channel, and then asks. She wants the excess mass carried as far as the next crossing.",
			tags = [&"contract"],
			group = &"",
			weight = 11,
			max_danger = 4,
			choices = [
				{label = "Take the excess onto your frame",
					check = {attr = &"thrust", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(28))
						return {text = "You take eleven containers onto the outer frame and fly the burn heavy. The family hull makes its window behind you with fuel left over. They pay at the crossing, off a charter account. It has nineteen years of small entries in it. The oldest of them asks how your drive frame took the weight. She waits for the whole answer."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(16))
						return {text = "You take what the frame will hold. They spread the rest across the two holds they can still reach. The burn is slower than either of you wanted. Nobody loses the window. They pay for what you carried, to the container."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(6))
						return {text = "You take four containers, all your own load leaves room for. You hold the burn long and slow to keep them alongside, using fuel you meant to keep. They pay the standing fee for the hours and say they are sorry it is not more."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "A burn flown heavier than the drive frame was ever rated for.")
						return {text = "You take more than the frame wants and hold the burn anyway. Forty seconds in, a mount on the port side bends and stays bent. The containers go back to the family hull, and you shut the drive down to check the mount. They fly the window in two trips, and no one is paid."}},
				{label = "Buy the excess off them", cost_credits = 22, effect = func() -> Dictionary:
					Run.add_credits(-22)
					return {text = "Cash now against a delivery later is a poor trade. She takes it anyway. That delivery is three crossings off and the fuel is this week. The grapple walks one pallet across. It holds ration crates, filter cloth, and drums with another ship's marks still on them. She logs it as a sale and signs the log in two places.", material = &"event"}},
				{label = "Fly your own burn", stay = true, effect = func() -> Dictionary:
					return {text = "They talk it over on the open channel for another hour. Then they split the load and fly it in two trips. That costs them the window and the fuel for a second crossing. The one doing the arithmetic is the youngest aboard. She does it out loud on a channel anybody could be hearing."}},
			],
		},
		{
			id = &"borrowed_radiators",
			title = "Borrowed radiators",
			subject = {stage = &"single", pieces = [&"role:hauler"], dark = 0.6, lights = &"battery"},
			body = "Two crew sit on a short-haul hull with the reactor down. The exchanger that should shed its heat is split along a weld. They have been sitting cold for nine hours. The repair is an afternoon of work, but they cannot start until their loop cools. Their own panels went with the exchanger. They want a coupling walked across on the grapple, so their loop can run through your radiators until the number comes down. They will pay the hours at a rim yard's rate.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			max_danger = 4,
			choices = [
				{label = "Run their loop through your panels",
					check = {attr = &"thermal", need = 5},
					met = func() -> Dictionary:
						Run.heat += 6
						Run.add_credits(OptionTable.purse(26))
						return {text = "Their loop goes through your panels. Your panels give most of it back to the sky as fast as it arrives. You run warm for four hours and never close to anything that matters. They have the weld in and their reactor lit before you have uncoupled. They pay the yard rate off a card. One of them keeps it for the things they do not plan."},
					clean = func() -> Dictionary:
						Run.heat += 10
						Run.add_credits(OptionTable.purse(18))
						return {text = "The coupling holds and the transfer works. It is slower than either set of instruments said it would be. You spend five hours warm and an hour of that warmer than you like. Your own reactor is eased back to give the panels room. They light theirs at the end of it and pay what they said."},
					partial = func() -> Dictionary:
						Run.heat += 14
						Run.add_credits(OptionTable.purse(6))
						return {text = "You take about half of what they needed shifted. Then your own panels are as far behind as theirs were. They finish the weld with the loop still hot, slower than they meant to. They pay for the half you took. You carry the heat of it in your own plating all afternoon."},
					botched = func() -> Dictionary:
						Run.heat += 18
						Run.take_hull_damage(OptionTable.toll(3), "A coupling gave way with their coolant loop at full pressure.")
						return {text = "The coupling seats badly and you find that out with their loop at pressure. What comes out goes across the mount and takes the plating behind it. Now you shed their heat and your own through a panel that is short a section. They cut it from their side and say nothing for a while. Then they say sorry."}},
				{label = "Take two hours of it and uncouple", effect = func() -> Dictionary:
					Run.heat += 8
					Run.add_credits(OptionTable.purse(14))
					return {text = "You agree to two hours, and you give them two hours. It takes their loop down far enough to work in and no further. You go on warm. They pay before the coupling is stowed, then go back to a repair that will take the rest of the day."}},
				{label = "Stay cold", stay = true, effect = func() -> Dictionary:
					return {text = "They take the answer and do not argue about it. They go back to the open channel. Somebody will come through this system in a day or two with empty panels. The reactor stays down until then. The two of them sit in a hull going as cold as the sky around it."}},
			],
		},
		{
			id = &"the_spare_module",
			title = "The spare module",
			subject = {stage = &"single", pieces = [&"role:tender"], lights = &"run"},
			body = "Three people work off an old tender. They have one thing left to sell, a power module out of a hull they took apart four systems back. Someone has ground the manufacturer's plate and the serial off the casing. They are selling it here, in open space, because the yard they are headed for keeps a register. That yard asks about parts with no numbers on them. They want cash today. The price is low, and they say so.",
			tags = [&"salvage"], site = &"contact",
			group = &"",
			weight = 9,
			max_danger = 4,
			choices = [
				{label = "Read it under load before you pay",
					check = {attr = &"sensors", need = 3},
					met = func() -> Dictionary:
						Run.add_credits(-16)
						return {text = "The dish reads it cold and then reads it under load. Coil temperatures, the housing, a repair on the third bus. That repair was done in a hurry by somebody who knew the work. The module is sound. The repair is worth arguing about, and you argue about it. The grapple walks it across for less than they opened at. It goes straight into the rack.", module = true},
					clean = func() -> Dictionary:
						Run.add_credits(-24)
						return {text = "Nothing on the instruments says the module is other than what they claim. Nothing says where it came from either. You pay close to the asking price and take it aboard. It reads clean on your own bus an hour later. It is still reading clean at the end of the day.", module = true},
					partial = func() -> Dictionary:
						return {text = "The readings will not settle. Under load the third bus wanders. That could be the module or it could be the tender's own supply. There is no telling the two apart from where you sit. You tell them so. They keep the module and go back to waiting for a ship that will not look."},
					botched = func() -> Dictionary:
						Run.add_credits(-24)
						Run.take_hull_damage(OptionTable.toll(3), "A power module bought in open space with its numbers ground off.")
						return {text = "Your readings say sound, so you pay for sound. The module comes aboard, goes in the rack and comes up once. What is wrong with it sits on the far side of the housing. The dish was never going to see it there. It takes a section of bus and the plating behind that on its way out. The tender is four hours gone by then."}},
				{label = "Pay what they are asking", cost_credits = 28, effect = func() -> Dictionary:
					Run.add_credits(-28)
					return {text = "They want it off the tender before the yard. You want a spare power module. Neither of you asks the other a single question. The grapple has it across inside the hour. One of them stays on the channel until you confirm it is racked. Then they wish you a quiet crossing and go back to sorting the rest of the hull into piles.", module = true}},
				{label = "Cross without it", stay = true, effect = func() -> Dictionary:
					return {text = "They put the price down twice on the open channel while you are still in range. Then they stop. Ships come through here every few days. The module sits on the tender until somebody arrives who does not ask about the plate."}},
			],
		},
		{
			id = &"one_number_between_two",
			title = "One number between two",
			subject = {stage = &"single", pieces = [&"role:hauler"], lights = &"run", drive = true},
			body = "A short-haul hauler matches your course and asks for something odd. Its transponder came back from a yard reflashed to the wrong hull number. It is four digits off its own. Every patrol on this ring has stopped it since. Papers, mass check, half a day standing still while somebody inward is queried. The yard that can fix it is two crossings on. The woman flying it wants to make those crossings tucked under your flank. She wants a patrol dish to read one contact. She is offering the fee she loses to one more stop.",
			tags = [&"contract", &"signal"],
			group = &"",
			weight = 10,
			max_danger = 4,
			choices = [
				{label = "Fly the crossings with her under your flank",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(28))
						return {text = "She holds under the flank for eleven hours. She never drifts out of the shadow your hull puts on the traffic dish. One patrol queries you on the way through and logs one ship. At the yard she pays the whole fee. Then she stays on the channel a while. She tells you where the reflash was done and which of the two people there did it."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(16))
						return {text = "It works for most of the crossing. Twice she falls far enough back to read as her own contact. Both times nobody is looking. You fly the rest of it slow to keep her close and get in late. She pays what she said she would pay."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(5))
						return {text = "Holding a line that tight is attitude work the whole way. You spend the crossing burning small corrections you do not get back. She is stopped anyway, an hour out from the yard. The patrol reads two contacts and wants to know about the older one. She pays you what she has left after the stop."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Two hulls flying closer than either pilot could hold them.")
						return {text = "Eight hours in she comes up under the flank on a correction you were already making. The touch is slow. It still takes a run of plating off the underside. It puts her attitude jets out on that side. She finishes the crossing a kilometre off and pays nobody anything. The yard gets two jobs now."}},
				{label = "Sit out the patrol window with her", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					Run.add_credits(OptionTable.purse(12))
					return {text = "The patrol working this ring keeps to a schedule. You can both read it off the traffic channel. You hold at the edge of the system with her and wait for the patrol to pass inward. That costs most of a day and the fuel to hold position. She crosses behind you unstopped. She pays before either of you has lit a drive."}},
				{label = "Send her the times and go", stay = true, effect = func() -> Dictionary:
					return {text = "You send her the last three times you saw a patrol on this ring. You send nothing else and fly your own crossing. She is still at the edge of the system when you lose her off the dish. She is doing the arithmetic on a schedule with three entries in it."}},
			],
		},
		{
			id = &"the_automatic_dock",
			title = "The automatic dock",
			subject = {stage = &"structure", pieces = [&"st_the_automatic_dock"]},
			body = "A docking arm sticks out of a rock off the lane. It still keeps its schedule. Every two hours it swings out, holds open twenty minutes, and folds back on the stone. A ship name is painted along the spine, with a rota of four dates a month. The cold has gone through the paint. No ship has come to the arm in a long while. A parts locker is welded to the frame under it. Somebody put it there so their own ships would never wait on a station. The arm takes any hull.",
			tags = [&"salvage"], site = &"belt",
			group = &"",
			weight = 10,
			max_danger = 4,
			choices = [
				{label = "Fly the approach it wants",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						return {text = "You fly the rota line at the speed the arm wants. It takes you like it was expecting you. The clamps hold you square for the whole twenty minutes. The locker opens on the same cycle. Behind it is a module still in its shipping frame. The cutter goes through the frame, and it is good plate.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "The arm takes you on the second try. It holds you steady. Twenty minutes is enough to open the locker and take the module out. It is not enough to cut up the frame it came in.", module = true},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "You miss the window twice. The arm folds back both times with nothing in it. Holding for the next cycle costs more burn than the cycle is worth. You break off before the third one opens."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "A dock arm folded on its schedule with the ship still in it.")
						return {text = "You are square in the arm when the twenty minutes run out. It folds on the hour it was built to fold. It closes on your flank and does not notice the difference."}},
				{label = "Cut the parts locker off the frame", effect = func() -> Dictionary:
					Run.heat += 6
					return {text = "The cutter runs hot for half an hour. The bolts were put in to stay. What comes away is a locker of spares kept for four ships that stopped coming. Seals, cable, cells, and a box of parts for a drive nobody makes now. Every drawer is sorted and labelled.", material = &"event"}},
				{label = "Let it keep its schedule", stay = true, effect = func() -> Dictionary:
					return {text = "You hold off and watch one cycle from a distance. The arm swings out and waits its twenty minutes on an empty approach. Then it folds back. The rota says it will do it again in two hours."}},
			],
		},
		{
			id = &"the_dust_counter",
			title = "The dust counter",
			subject = {stage = &"single", pieces = [&"r4_dustcounter_dust_counter_2"], tumble = 3.0},
			body = "An instrument hangs on a frame out here, counting what goes past. It has one aperture, a stack of cells, and a log. The log writes a number every hour whether anybody reads it or not. A mining outfit put it here to learn if the drift was worth working. The outfit is gone and the answer is still not in. It has been writing since before your ship was fitted. Two cells are left in the stack. The log is nearly full. When it fills it starts over and writes on top of the old numbers.",
			tags = [&"signal"],
			group = &"",
			weight = 9,
			max_danger = 4,
			choices = [
				{label = "Copy the log before it wraps",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "The dish reads it off in an hour and forty minutes, first entry to last. The first entry is older than the outfit that ordered it. Eleven numbers an hour for four years. Then one an hour ever since. The cells have been going flat that whole time. You clip the spares box off the frame: cable, two cells, a lens the aperture never needed.", material = &"event"},
					clean = func() -> Dictionary:
						return {text = "The copy comes off clean for the last four years. Then it hits the wrap. The new numbers are written on top of the old ones, and neither one survives. You take the spares box off the frame and leave the instrument counting.", material = &"event"},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "The interface wants a key you do not have. The dish gives you the entry it is writing now, over and over. The reactor idles the whole time. Two hours of that, and you have one number out of a record forty years deep."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "A survey frame let go at the weld and put a strut through the plating.")
						return {text = "You come in close to read the housing itself. The frame it is bolted to lets go at the weld. It comes apart slowly. That does not help. One strut finds the plating and goes through it."}},
				{label = "Cut the instrument off its frame", effect = func() -> Dictionary:
					Run.heat += 6
					return {text = "Half an hour of cutter on a frame built to stay put. The aperture, the cell stack and the housing come aboard as metal. The log stops somewhere in the second cut. The frame is still out there, bare, pointed at the drift.", material = &"wreck"}},
				{label = "Note the bearing and go", stay = true, effect = func() -> Dictionary:
					return {text = "You log where it is and what it is doing. In a month or two the log will wrap and write over its first forty years."}},
			],
		},
		{
			id = &"the_welded_plate",
			title = "The welded plate",
			subject = {stage = &"on_rock", planet = true, base = &"paint_rock_a1", r = 84.0, pieces = [&"r4_plate_welded_plate_1"], rows = 1, count = 1, face = Vector2(-6.0, 4.0)},
			body = "A rock the size of a station turns slowly off your beam. Somebody welded a hull plate to it. The letters are cut into the steel, not painted: eleven registries and one date. Under the plate is the ship those registries flew, bolted flat so the spin cannot take it. Your dish reads nothing running aboard it. Other ships have been here and taken what a grapple could lift. The tanks are still on it, and they are still full.",
			tags = [&"salvage"], site = &"belt",
			group = &"",
			weight = 9,
			max_danger = 4,
			choices = [
				{label = "Work in close against the spin",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						return {text = "You sit in against the spin for two hours. The face throws what it throws. The frame is good steel under the bolts. It comes up in lengths once the first row is off. By the end your plating is scoured bright along one side.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "You take one pass at it. Most of a row of frame comes aboard. The rock turns under you the whole time. Holding the nose steady costs more burn than you meant to spend.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "An hour of station keeping against a rock that will not hold still. Most of the hour goes on the nose and not the cutter. Somebody put those bolts in with a cutter and no reason to hurry. They are still in."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A turning rock the size of a station threw loose debris off its face into the ship.")
						return {text = "You come in under the plate on the wrong side of the spin. What comes off the face is small, and there is a lot of it. It arrives at the speed the rock is turning."}},
				{label = "Pump what is left in the tanks", effect = func() -> Dictionary:
					Run.heat += 5
					Run.fuel += 2
					return {text = "The valves are a standard fitting and they have not frozen shut. The rest of the ship did not manage that. It takes three hours to move the fuel across. The pump runs hot the whole time, with your own lights on the plate. The tanks read empty when you uncouple."}},
				{label = "Log the eleven registries", stay = true, effect = func() -> Dictionary:
					return {text = "You put the dish on the plate and read off all eleven numbers. The date under them goes in the log too. The rock turns the plate out of sight. It brings it back around."}},
			],
		},
		{
			id = &"the_core_drill",
			title = "The core drill",
			subject = {stage = &"single", pieces = [&"r4_drill_drill_rig_1"]},
			body = "A survey rig is anchored to a rock out here. It is still drilling. It has put a line of holes across the face, a few metres apart. It is working on the next one. The cores it cut are stacked in a rack beside it. They are labelled in a code. The code meant something to whoever ordered the survey. A transponder on the mast repeats a claim notice every ninety seconds. The rock is taken, the survey is under way, results pending. The date in the notice is nineteen years old.",
			tags = [&"signal", &"salvage"], site = &"belt",
			group = &"",
			weight = 8,
			max_danger = 4,
			choices = [
				{label = "Cut into the face the drill opened",
					check = {attr = &"thermal", need = 4},
					met = func() -> Dictionary:
						return {text = "The holes go deep enough to show what the rig has been paying for. The drill found a seam and never finished it. The cutter works that face for two hours and the grapple brings it in loose. The rig starts the next hole while you are still working. The notice goes out on schedule.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You take the face slowly. The cutter is hotter than you want by the end. What comes aboard is ore in pieces. The vents have an hour of work before you burn out.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.heat += 8
						return {text = "The rock is harder than nineteen years of drilling made it look. It beats the cutter for an hour before you stop. You come away with a hot ship and one more mark on the face."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A rock face came apart on the hull where the drill had been.")
						return {text = "The face parts along a line the drill made. The rock behind it was holding the rest in place. A slab comes out at you slowly. It does not stop when it reaches the hull."}},
				{label = "Take the power rack off the mast", effect = func() -> Dictionary:
					Run.take_hull_damage(OptionTable.toll(2), "The power rack was half cut out. The survey mast came down on the plating.")
					return {text = "The rack is bolted through the mast. The mast was never built to come apart next to anything. You get the rack out in forty minutes. You wear the top of the mast on your way clear. The drill carries on into the hole it was in. The notice does not go out again.", module = true}},
				{label = "Let the claim stand", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and the code on the rack of cores. You log the date in the notice too. The drill starts the next hole while you are still in range. The notice goes out again at ninety seconds."}},
			],
		},
	])
	return out
