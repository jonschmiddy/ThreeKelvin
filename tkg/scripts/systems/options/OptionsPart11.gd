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
			body = "A survey clerk will buy your place in line to file the first reading on this unclaimed world.",
			tags = [&"science"],
			site = &"barren",
			group = &"",
			weight = 8,
			min_danger = 1,
			max_danger = 4,
			choices = [
				{label = "Drop a probe", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(OptionTable.reading(1))
					return {text = "Your probe sends from the plain an hour before hers lands."}},
				{label = "Land and drill", burns = true, reads = 2,
					check = {attr = &"thermal", need = 4},
					met = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						return {text = "The core comes up whole and goes on file under your registry."},
					clean = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						Run.heat += 6
						return {text = "The drill runs hot near the bottom, but the core comes up whole."},
					partial = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(1))
						Run.heat += 12
						return {text = "The drill overheats halfway down, and you lift with half a core."},
					botched = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.take_hull_damage(OptionTable.toll(4), "A jammed drill tore its mount out of the hull.")
						Run.heat += 8
						return {text = "The drill jams deep, and its mount tears out of the plating on the climb."}},
				{label = "Sell your place", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "Her name goes on the world's chart instead of yours."}},
			],
		},
		{
			id = &"the_old_lander",
			title = "The old lander",
			body = "An old lander keeps its record in a box read by cable, and a collector offers credits to leave it alone.",
			tags = [&"science"],
			site = &"barren",
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 6,
			choices = [
				{label = "Copy the beacon", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(OptionTable.reading(1))
					return {text = "Three low passes catch years of the beacon's short daily summaries."}},
				{label = "Hover and cable in", burns = true, reads = 2,
					check = {attr = &"thermal", need = 5},
					met = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						return {text = "The grapple holds the cable in the port for an hour while the box gives up its record."},
					clean = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						Run.heat += 8
						return {text = "The hover runs long and the drive runs hot, but the record comes through."},
					partial = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(1))
						Run.heat += 16
						return {text = "The port is fouled, and the heat forces you up with half the record."},
					botched = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.take_hull_damage(OptionTable.toll(4), "An old lander's record box swung into the plating on a cable.")
						Run.heat += 10
						return {text = "You lift in a hurry with the cable still in, and the box swings into your plating."}},
				{label = "Sell the position", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "Within the hour his grapple lifts the lander off the plain whole."}},
			],
		},
		{
			id = &"the_fresh_slide",
			title = "The fresh slide",
			body = "A fallen crater wall bared fresh layers under falling dust, and a pilot lost in it will pay for a way out.",
			tags = [&"science"],
			site = &"barren",
			group = &"",
			weight = 8,
			min_danger = 5,
			max_danger = 8,
			choices = [
				{label = "Read from high up", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(OptionTable.reading(1))
					return {text = "You read the layers through the thin edge of the dust while another scout talks her out."}},
				{label = "Core the face", burns = true, reads = 2,
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						return {text = "Dust rings off the plating, and the scout follows your track out while the core comes up whole."},
					clean = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						Run.take_hull_damage(OptionTable.toll(1), "Scoured by a slide's dust while coring it.")
						return {text = "The dust low down scours the bow while the drill works."},
					partial = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(1))
						Run.take_hull_damage(OptionTable.toll(3), "Hit by a piece of a fresh slide.")
						return {text = "A piece of the slide hits the bow, and you pull out with half a core."},
					botched = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.take_hull_damage(OptionTable.toll(4), "Hit by a boulder hidden in a slide's dust.")
						return {text = "A boulder hidden in the dust hits you before the drill is set."}},
				{label = "Guide the scout out", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "After most of a shift her scout comes out of the dust on the north side."}},
			],
		},
		{
			id = &"the_target_range",
			title = "The target range",
			body = "This old navy range is pitted with live shells, and a scrapper will pay you to mark them ahead of her.",
			tags = [&"science"],
			site = &"barren",
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 10,
			choices = [
				{label = "Probe an old crater", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(OptionTable.reading(1))
					return {text = "Your probe reads the oldest crater while a shell goes off near the scrapper's ship."}},
				{label = "Core a fresh pit", burns = true, reads = 2,
					check = {attr = &"hull", need = 7},
					met = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						return {text = "You set down at the lip of a fresh pit, and the core comes up whole."},
					clean = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						Run.take_hull_damage(OptionTable.toll(1), "A navy shell shifted under the landing legs.")
						return {text = "Something in the pit shifts under the landing legs, but nothing goes off."},
					partial = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(1))
						Run.take_hull_damage(OptionTable.toll(3), "A navy shell went off in the next pit.")
						return {text = "A shell in the next pit goes off, and you lift with half a core."},
					botched = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.take_hull_damage(OptionTable.toll(4), "A navy shell went off under the landing legs.")
						return {text = "A shell under the landing site goes off as the legs touch."}},
				{label = "Mark live shells", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "Her hold fills with casings, and her ship loses none of its plating."}},
			],
		},
		{
			id = &"the_spare_probe",
			title = "The spare probe",
			body = "An old belt miner lost his probe to a rock that moved and will pay you well for your spare.",
			tags = [&"science"],
			site = &"belt",
			group = &"",
			weight = 8,
			min_danger = 1,
			max_danger = 4,
			choices = [
				{label = "Send your probe", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(OptionTable.reading(1))
					return {text = "Your probe reads every rock along the edge, and the miner goes after the one it ends on."}},
				{label = "Read a rock close", burns = true, reads = 2,
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						return {text = "You slip between two rocks and grapple the slower one for an hour of close reading."},
					clean = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						Run.take_hull_damage(OptionTable.toll(1), "Clipped by a rock in a thin belt.")
						return {text = "On the way out a smaller rock clips the stern."},
					partial = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(1))
						Run.take_hull_damage(OptionTable.toll(3), "Hit by a turning rock in a belt.")
						return {text = "The rock turns faster than it looked and knocks your grapple into the hull."},
					botched = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.take_hull_damage(OptionTable.toll(4), "Caught between two slow rocks in a belt.")
						return {text = "Two rocks close on the gap and pin the ship between them."}},
				{label = "Sell the probe", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "He has it out in the belt within the hour, naming each rock it passes."}},
			],
		},
		{
			id = &"the_race_course",
			title = "The race course",
			body = "A belt race starts within the hour on freshly scarred rocks, and its steward offers credits to mark the far turn.",
			tags = [&"science"],
			site = &"belt",
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 6,
			choices = [
				{label = "Read from outside", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(OptionTable.reading(1))
					return {text = "The race starts while you read, and a racer cuts inside the far turn."}},
				{label = "Fly the course first", burns = true, reads = 2,
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						return {text = "You run the course ahead of the start and read each scar as you pass."},
					clean = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						Run.take_hull_damage(OptionTable.toll(1), "Clipped a rock on a belt race course.")
						return {text = "You clip a beacon rock at the far turn, and the start is moved back."},
					partial = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(1))
						Run.take_hull_damage(OptionTable.toll(3), "Hit a rock on a belt race course.")
						return {text = "A rock you misjudged meets the bow, and you leave the course early."},
					botched = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.take_hull_damage(OptionTable.toll(4), "Hit a race course's beacon rock too fast.")
						return {text = "You hit the far turn's beacon rock too fast, and the race is called off."}},
				{label = "Mark the far turn", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "The racers pass close enough to read their registries, and one clips the rock behind you."}},
			],
		},
		{
			id = &"the_close_pair",
			title = "The close pair",
			body = "A family on two close rocks will pay you to carry their mail, and their antennas point through the gap.",
			tags = [&"science"],
			site = &"belt",
			group = &"",
			weight = 8,
			min_danger = 5,
			max_danger = 8,
			choices = [
				{label = "Read from outside", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(OptionTable.reading(1))
					return {text = "You read how the pair pull on each other from a wide orbit."}},
				{label = "Fly the gap", burns = true, reads = 2,
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						return {text = "You fly the gap on line, and the family's antennas lose their link while you are in there."},
					clean = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						Run.take_hull_damage(OptionTable.toll(1), "Scraped a rock flying a narrow gap.")
						return {text = "You come out a little off line and scrape the smaller rock."},
					partial = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(1))
						Run.take_hull_damage(OptionTable.toll(3), "Struck by a turning rock in a narrow gap.")
						return {text = "The larger rock swings across your line, and your burn to clear it knocks out the family's link to the station."},
					botched = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.take_hull_damage(OptionTable.toll(4), "Crushed in a gap between two rocks.")
						return {text = "The gap closes on you, and the ship bounces off the smaller rock."}},
				{label = "Carry their mail", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "You log for the dockmaster that the family is still out here."}},
			],
		},
		{
			id = &"the_broken_rock",
			title = "The broken rock",
			body = "An old mining charge broke a rock apart, and a patrol will pay you to track a piece drifting toward a camp.",
			tags = [&"science"],
			site = &"belt",
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 10,
			choices = [
				{label = "Read from outside", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(OptionTable.reading(1))
					return {text = "Without your track, the patrol gets the large piece wrong and sends the camp's work ship to the wrong place."}},
				{label = "Fly into the spread", burns = true, reads = 2,
					check = {attr = &"maneuver", need = 7},
					met = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						return {text = "Nothing touches you, and you send the patrol the large piece's true spin."},
					clean = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(2))
						Run.take_hull_damage(OptionTable.toll(1), "Hit by a piece of a broken rock.")
						return {text = "A small piece the patrol was not tracking catches the stern."},
					partial = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.add_data(OptionTable.reading(1))
						Run.take_hull_damage(OptionTable.toll(3), "Hit by two pieces of a broken rock.")
						return {text = "Two pieces turn into your path, and you take one on the bow to miss the other."},
					botched = func() -> Dictionary:
						Run.drain_fuel(OptionTable.science_fuel())
						Run.take_hull_damage(OptionTable.toll(4), "Hit by a piece of rock as big as the ship.")
						return {text = "A piece the size of your ship comes across the bow, and the patrol lists you as a hazard."}},
				{label = "Track the pieces", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "A work ship from the camp meets the large piece on your track and pushes it off line."}},
			],
		},
	])
	return out
