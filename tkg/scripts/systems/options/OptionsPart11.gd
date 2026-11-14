class_name OptionsPart11

## The science encounters (`the_first_look` to `the_broken_rock`), second to last in the order `OptionTable._authored`
## joins them (`OptionsPart12` is last): `roll_for` draws by table order, so entries never move between or within files.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		# SCIENCE (Phase 12, Jon's picks Nov 4): readings at a dry world or a belt.
		# Why: docs/why/OptionsPart11.md#science
		{
			id = &"the_first_look",
			title = "The first look",
			body = "A small world turns below you with no claim on file. A survey ship holds orbit beside you. Ida Marsh clerks on it for the Fennick Claims Office, and she tells you the office rule. The first ship to put a reading on file gets its registry on the world's chart. Her own probe is still being fitted. She offers to buy your place in line and pay you now. The plain under you is flat, and the dish reads nothing moving on it.",
			tags = [&"science"],
			site = &"barren",
			group = &"",
			weight = 8,
			min_danger = 1,
			max_danger = 4,
			choices = [
				{label = "Drop a probe from orbit", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(OptionTable.reading(1))
					return {text = "The probe comes down on the plain and starts sending at once. Ida files your reading. Her own probe goes down an hour after yours, a long way off on the same plain. You hold orbit over yours for a full shift, and the burns to stay there cost fuel."}},
				{label = "Set down and run the drill", burns = true, reads = 2,
					check = {attr = &"thermal", need = 4},
					met = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						return {text = "You set down on the plain and run the drill until the core is out whole. Ida asks to see the core log. She reads it twice and then files it under your registry. The climb back to orbit burns fuel."},
					clean = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						Run.heat += 6
						return {text = "The drill runs hot in the last part of the hole, and you shut it down a little early. The core still comes up whole. Some of the heat is still in the ship when you reach orbit, and the climb has cost fuel. Ida files the reading."},
					partial = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(1))
						Run.heat += 12
						return {text = "The drill heats faster than the vents can clear it. You stop halfway down and burn fuel to lift with what you have. Half a core goes on file, and the ship is running hot. Ida files her own probe's reading beside yours later that shift."},
					botched = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.take_hull_damage(OptionTable.toll(4), "A jammed drill tore its mount out of the hull on the climb off an empty world.")
						Run.heat += 8
						return {text = "The drill jams deep in the hole, and its heat backs up into the ship. You cut it loose and lift with nothing. The mount tears out of the plating on the climb, and the fuel for the trip is gone. Ida's probe is down by the time you reach orbit, and her office files first."}},
				{label = "Sell Ida Marsh your place in line", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "Ida pays from the office account while you are still on the channel. She asks for your approach log as well, and you send it. Her probe goes down on the plain a few hours later. Her name goes on the chart under the Fennick office's mark."}},
			],
		},
		{
			id = &"the_old_lander",
			title = "The old lander",
			body = "An old lander sits on a plain below you. Its markings say Ostrander Survey. No Ostrander ship has flown in this sector for a long time. Its beacon still sends a short summary each day. The full record is in a box on its frame, and the box can only be read through a cable. A private yacht holds orbit nearby. Corin Pell owns it and collects old survey gear. He says the lander is worth more untouched. He offers credits up front for its position and your word to leave it be.",
			tags = [&"science"],
			site = &"barren",
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 6,
			choices = [
				{label = "Copy the beacon from orbit", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(OptionTable.reading(1))
					return {text = "You drop to a low orbit and catch the beacon on three passes. The burns to line up each pass cost fuel. The summaries are short, but they go back a long way. Corin watches the whole time. When you climb, he sends a formal note to say the lander is his find."}},
				{label = "Hover beside it and run the cable in", burns = true, reads = 2,
					check = {attr = &"thermal", need = 5},
					met = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						return {text = "You hover off the frame for an hour while the grapple holds the cable in the port. Corin is on the channel for all of it. He reads you a list of what the lander is worth, line by line. The hover costs fuel, but the drive heat stays where you want it. The box gives up its whole record before you climb."},
					clean = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						Run.heat += 8
						return {text = "The hover runs longer than you planned. The drive heat climbs, and the vents fall behind it. The box gives up its record just before you have to lift. The climb back costs fuel, and the ship runs hot for a while after. Corin has left orbit by then."},
					partial = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(1))
						Run.heat += 16
						return {text = "The port is fouled after all these years. The grapple works the cable in a little at a time while the drive heat climbs. You get half the record before the heat forces you up, and the trip down and back has cost fuel. Corin sends a note asking you not to come back for the rest."},
					botched = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.take_hull_damage(OptionTable.toll(4), "An old survey lander's record box, swung up on a cable, came through the plating.")
						Run.heat += 10
						return {text = "The drive heat goes past what the vents can clear, and you lift in a hurry. The cable is still in the port. It tears the box off the frame and swings it into your plating before the line parts. The box falls back to the plain in pieces, and the fuel is spent. Corin has recorded all of it."}},
				{label = "Sell Corin Pell the position", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "Corin pays as soon as the position is on his screen. Within the hour a small ship from his yacht is down on the plain. Its grapple lifts the lander off the ground whole. He tells you it will go on show in a hall on Merrow Station."}},
			],
		},
		{
			id = &"the_fresh_slide",
			title = "The fresh slide",
			body = "Part of a crater wall on this world gave way an hour ago. The slide opened a fresh face down the whole height of the wall. No one has read those layers. The dust it threw up is still coming down over the crater. A small ore scout is somewhere inside that dust. Neve Calder flies it, and she is on the channel. Her dish is fouled and she cannot find the rim. She will pay you now to read her a way out from up here.",
			tags = [&"science"],
			site = &"barren",
			group = &"",
			weight = 8,
			min_danger = 5,
			max_danger = 8,
			choices = [
				{label = "Read the new face from high up", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(OptionTable.reading(1))
					return {text = "You burn fuel to hold a high pass over the crater and read the face through the thin edge of the dust. The layers show clearly. While you read, Neve stops asking. A second scout from her outfit comes in from the far side and talks her out."}},
				{label = "Fly down through the dust and core the face", burns = true, reads = 2,
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						return {text = "You go in under the worst of the dust and put the drill into the new face. Dust rings off the plating the whole time, but none of it is big. Neve finds your track and follows it out to the rim. The core comes up whole, and the climb out costs fuel."},
					clean = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						Run.take_hull_damage(OptionTable.toll(1), "A boulder rolling down a fresh slide, hidden in its own dust.")
						return {text = "The dust is thicker low down than it looked from above. The plating takes a steady scour while the drill works. The core comes up whole, and you burn fuel to climb out with a scuffed bow. Neve is still in the dust when you leave orbit."},
					partial = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(1))
						Run.take_hull_damage(OptionTable.toll(3), "A boulder rolling down a fresh slide, hidden in its own dust.")
						return {text = "A piece of the slide comes off the face while the drill is in. It hits the bow, and you pull out with half a core. The trip down and up has cost fuel. On the way up you pass Neve's scout. Its lights are on, and it is climbing on its own."},
					botched = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.take_hull_damage(OptionTable.toll(4), "A boulder rolling down a fresh slide, hidden in its own dust.")
						return {text = "The dust hides a boulder rolling down the slide. It hits the ship before the drill is set. You climb with no core and the plating split, and the fuel for the trip is spent. Neve hears the impact on the channel and asks if you are still there."}},
				{label = "Read Neve Calder out of the dust", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "You hold over the rim and read her the crater walls one at a time. It takes most of a shift. Her scout comes out of the dust on the north side with the paint scoured off one flank. She pays you before she has finished her climb."}},
			],
		},
		{
			id = &"the_target_range",
			title = "The target range",
			body = "This world was a navy target range. The navy is gone, but a beacon in orbit still warns ships off. The plain below is pitted with old impacts, and some of the shells in them never went off. The oldest craters lie outside the range. A scrap ship works the edge of the range. Mirela Dunn flies it alone and lifts dead shells for their casings. She wants a ship with a good dish to mark the live ones ahead of her. She will pay you now for a shift of it.",
			tags = [&"science"],
			site = &"barren",
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 10,
			choices = [
				{label = "Drop a probe into an old crater", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(OptionTable.reading(1))
					return {text = "The probe lands in the oldest crater and reads the floor under it. You burn fuel holding orbit over the crater for the readings. Mirela lifts a casing while you wait. Something on the range goes off near her ship. She is on the channel a minute later, angry, with her ship's plating holed."}},
				{label = "Fly low over the range and core a fresh pit", burns = true, reads = 2,
					check = {attr = &"hull", need = 7},
					met = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						return {text = "You come in low over the range and set down at the lip of a fresh pit. The drill goes through the floor of the pit, and the core comes up whole. Mirela logs your pit as clear and asks for your track. The burn back up to orbit costs fuel."},
					clean = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						Run.take_hull_damage(OptionTable.toll(1), "A navy shell went off under the landing legs on an old target range.")
						return {text = "You set down at the edge of a pit, and something in the pit floor shifts against the landing legs. Nothing goes off. You take the core and burn fuel to lift, with a gouge in the belly plating. Mirela marks the pit on her chart with your registry beside it."},
					partial = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(1))
						Run.take_hull_damage(OptionTable.toll(3), "A navy shell went off under the landing legs on an old target range.")
						return {text = "A shell in the next pit goes off as you set down. The blast pushes the ship sideways, and you lift with half a core and holed plating. The fuel for the trip is spent. Mirela tells you which pit it was and adds it to her chart."},
					botched = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.take_hull_damage(OptionTable.toll(4), "A navy shell went off under the landing legs on an old target range.")
						return {text = "A shell under the landing site goes off as the legs touch. You climb with no core, a holed belly and warning lights across the board. The fuel for the trip is gone. Mirela asks if you want her to mark the site for the next ship."}},
				{label = "Mark live shells for Mirela Dunn", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "Her credits come in before you start. You spend a shift over the range, reading the ground ahead of her ship. You call out every shell that still reads live. At the end of it her hold is full of casings, and her ship has lost none of its plating."}},
			],
		},
		{
			id = &"the_spare_probe",
			title = "The spare probe",
			body = "The belt is thin here, with long gaps between the rocks. A one-seat ship sits at the edge of it. Hollis Brandt has worked this belt from it for most of his life. He lost his last probe earlier this shift to a rock he says moved when it should not have. He asks if you carry a spare. He will pay you for it now, and more than it cost you. The rocks nearest you turn slowly, and none of them carries a claim beacon.",
			tags = [&"science"],
			site = &"belt",
			group = &"",
			weight = 8,
			min_danger = 1,
			max_danger = 4,
			choices = [
				{label = "Send your probe along the edge", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(OptionTable.reading(1))
					return {text = "The probe crosses the edge of the belt and reads every rock it passes. You follow it along the edge to keep it in range, and that costs fuel. Hollis follows too, a long way back. When the probe sends its last reading, he goes after the rock it ended on."}},
				{label = "Fly in and read a rock up close", burns = true, reads = 2,
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						return {text = "You slip in between two rocks and put the grapple on the slower one. The dish reads it close for an hour. Hollis watches from the edge and asks for the bearing of the rock, and you send it. Holding still in there costs fuel, but nothing comes near you."},
					clean = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						Run.take_hull_damage(OptionTable.toll(1), "Caught between two slow rocks in a thin part of a belt.")
						return {text = "You burn fuel getting the grapple on a rock, then read it close for an hour. On the way out a smaller rock clips the stern. The scrape is shallow. Hollis says it was the same rock that took his probe."},
					partial = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(1))
						Run.take_hull_damage(OptionTable.toll(3), "Caught between two slow rocks in a thin part of a belt.")
						return {text = "The rock you picked turns faster than it looked. You get half an hour on it before the grapple slips and the rock knocks it into the hull. You burn fuel backing out with half the readings and a dent. Hollis asks again if he can buy the probe."},
					botched = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.take_hull_damage(OptionTable.toll(4), "Caught between two slow rocks in a thin part of a belt.")
						return {text = "Two rocks close on the gap while you are in it. One catches the bow and pushes the ship sideways into the other. You back out with no readings and torn plating, and the fuel for the trip is gone. Hollis stays on the channel until you are clear of the rocks."}},
				{label = "Sell Hollis Brandt the probe", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "Hollis pays before the probe is across to his ship. His grapple takes it aboard, and he has it out in the belt within the hour. He calls out each rock it passes, by names he made up himself. It is still sending when you leave."}},
			],
		},
		{
			id = &"the_race_course",
			title = "The race course",
			body = "Someone has marked a course through this belt with beacons on the rocks. Pilots race it for money, and a race starts within the hour. Ilse Varn is its steward, and she is on the open channel asking ships to keep clear. The rocks along the course carry fresh scars where racers have clipped them. Each scar is bare rock that no dish has read up close. Ilse is short one marker ship for the far turn. She offers credits now to hold your lights there for the race.",
			tags = [&"science"],
			site = &"belt",
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 6,
			choices = [
				{label = "Read the scars from outside the course", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(OptionTable.reading(1))
					return {text = "You burn fuel keeping outside the beacons and read the scars from the edge of the course. The race starts while you are still reading. A racer cuts inside the far turn, and Ilse spends the rest of the race arguing with him on the channel."}},
				{label = "Fly the course before the start", burns = true, reads = 2,
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						return {text = "You run the course ahead of the start and read each scar as you pass it. The ship clears every rock, and the burn costs fuel. Ilse logs your time out of habit and reads it out on the channel. Two of the racers ask who you are."},
					clean = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						Run.take_hull_damage(OptionTable.toll(1), "Hit a rock on a race course through a belt, before the race had started.")
						return {text = "You fly the course and read the scars. At the far turn you clip one of the beacon rocks. The plating takes a scrape, and the burn costs fuel. Ilse has to move the start back while her crew checks the beacon on the rock you hit."},
					partial = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(1))
						Run.take_hull_damage(OptionTable.toll(3), "Hit a rock on a race course through a belt, before the race had started.")
						return {text = "You take the first half of the course well and read every scar on it. Then a rock you misjudged meets the bow. You burn fuel to leave the course early with half the readings and a dent. The race starts late, and Ilse names you on the channel."},
					botched = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.take_hull_damage(OptionTable.toll(4), "Hit a rock on a race course through a belt, before the race had started.")
						return {text = "You come into the far turn too fast and hit the rock that holds its beacon. The beacon breaks off, and the ship takes the worst of it. You leave with no readings and holed plating, and the fuel for the run is spent. Ilse calls the race off. The racers want their money back from her."}},
				{label = "Hold the far turn for Ilse Varn", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "Ilse has paid up front. You hold station at the far turn with your lights up. The racers come past close enough for you to read their registries. One of them clips the rock behind you and keeps going."}},
			],
		},
		{
			id = &"the_close_pair",
			title = "The close pair",
			body = "Two long rocks in this belt orbit each other. The gap between them opens and closes as they turn. A claim holder, Agathe Moll, lives on the larger one with her sons. Their mail ship has not come in months. She hails you before you have stopped. Her outgoing mail has to make the next station before its mail run closes. Agathe will pay you now to take it. She also asks you to keep out of the gap, where her antennas point.",
			tags = [&"science"],
			site = &"belt",
			group = &"",
			weight = 8,
			min_danger = 5,
			max_danger = 8,
			choices = [
				{label = "Read the pair from outside", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(OptionTable.reading(1))
					return {text = "You hold a wide orbit around the pair and read how they pull on each other. Every correction costs fuel. Agathe hails twice to ask about the mail. The second time her elder son is on the channel instead. He asks what the readings show."}},
				{label = "Fly the gap between the rocks", burns = true, reads = 2,
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						return {text = "You time the gap and go through between the rocks. The dish reads the pull of both at once, and the drive holds you on line. The burn costs fuel. Agathe watches from the larger rock. She tells you most of her antennas lost their link while you were in there."},
					clean = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						Run.take_hull_damage(OptionTable.toll(1), "Struck by a turning rock while flying the gap between two that orbit each other.")
						return {text = "The smaller rock turns faster than the dish said. You come out of the gap a little off line and scrape its edge. The readings are whole, and the fuel for the trip is spent. Agathe sends you a list of what your drive knocked off her mast."},
					partial = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(1))
						Run.take_hull_damage(OptionTable.toll(3), "Struck by a turning rock while flying the gap between two that orbit each other.")
						return {text = "Halfway through, the end of the larger rock swings across your line. You burn hard to clear it and hit the edge of her antenna field. You come out with half the readings and a dent. The fuel is spent. Agathe's link to the station is down, and she says it will take her sons a week to fix."},
					botched = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.take_hull_damage(OptionTable.toll(4), "Struck by a turning rock while flying the gap between two that orbit each other.")
						return {text = "You misjudge the turn, and the gap closes on you. The ship hits the smaller rock and bounces off it. You come out with nothing read and holed plating, and the fuel for the trip is gone. Agathe asks if you still mean to take the mail."}},
				{label = "Carry Agathe Moll's mail", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "Agathe sends the mail across to your board. It is larger than she said. She pays you while it loads. Her younger son asks you to tell the station they are still out here. You put it in the log for the dockmaster."}},
			],
		},
		{
			id = &"the_broken_rock",
			title = "The broken rock",
			body = "A rock in this belt broke apart a few days ago. A crew from Kessit Holdings set a charge inside it and left. The charge went off long after they had gone. The pieces are spreading, and the new faces inside them have never been read. A patrol ship is tracking them. Its officer, Lieutenant Sabine Orrow, says one of the larger pieces is drifting toward a mining camp further along the belt. Her dish is old. She will pay you now to track the pieces with your dish.",
			tags = [&"science"],
			site = &"belt",
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 10,
			choices = [
				{label = "Read the faces from outside the spread", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(OptionTable.reading(1))
					return {text = "You hold off the edge of the spread and read the faces that turn toward you. Keeping pace with the pieces costs fuel. Sabine tracks them with her old dish and gets the large one wrong. A work ship from the camp goes out to meet it at the wrong place. Sabine spends the next hour on the channel with its pilot."}},
				{label = "Fly into the spread and read the pieces close", burns = true, reads = 2,
					check = {attr = &"maneuver", need = 7},
					met = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						return {text = "You fly into the spread and read the fresh faces close, one piece at a time. Nothing touches you, though the burns between pieces cost fuel. On the way out you pass the large piece and see it turning faster than her chart says. You send her the spin. She says it changes her numbers and signs off."},
					clean = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						Run.take_hull_damage(OptionTable.toll(1), "A piece of a rock that a forgotten mining charge had broken apart.")
						return {text = "You read the faces close and keep most of the spread off you. A small piece catches the stern on the way out. The fuel for the trip is spent. Sabine asks you to log the hit, since the piece that did it is not on her track."},
					partial = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(1))
						Run.take_hull_damage(OptionTable.toll(3), "A piece of a rock that a forgotten mining charge had broken apart.")
						return {text = "Two pieces turn into your path at once, and you take one on the bow to miss the other. You leave the spread with half the readings and a dent. The burns cost fuel. Sabine asks for what you have, and you send it."},
					botched = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.take_hull_damage(OptionTable.toll(4), "A piece of a rock that a forgotten mining charge had broken apart.")
						return {text = "The spread is tighter than the dish showed. A piece the size of your ship comes across the bow, and the plating gives. You pull out with no readings, and the fuel for the trip is gone. Sabine logs the hit in her patrol report and lists your registry as a hazard to traffic."}},
				{label = "Track the pieces for Lieutenant Orrow", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "You hold off the spread and feed her a track of every piece large enough to matter. She pays from the patrol account. Her report goes out with your registry on it. Before the large piece gets there, a work ship from the camp meets it and pushes it off line."}},
			],
		},
	])
	return out
