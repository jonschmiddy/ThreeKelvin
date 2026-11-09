class_name OptionsPart12

## The comet's readings (Phase 13, Jon's C): taken where the ship met the comet on its path.
## The spot sets the pay and the cost (`CometPath.pay_here`, `toll_here`). Last in the order.
## Why: docs/why/OptionsPart12.md#comet-readings
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_coma(out)
	_tail(out)
	_crust(out)
	return out


static func _coma(out: Array[Dictionary]) -> void:
	out.append_array([
		{
			id = &"comet_coma",
			title = "The coma",
			body = "The comet comes past with its coma lit. The cloud of gas around the head is wider than a world. Your dish can read what the ice is made of while you sit inside the edge of the cloud. A reading like that goes to the Dace Survey archive under your registry. An Okafor mining ship on the far side of the system is on the channel. Its crew wants the same numbers to price the ice, and they will pay for yours.",
			tags = [&"science"],
			site = &"comet",
			group = &"",
			weight = 10,
			min_danger = 1,
			max_danger = 10,
			choices = [
				{label = "Read the coma as it goes by", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(CometPath.pay_here())
					CometPath.toll_here("Rock in a comet's coma broke the hull.")
					return {text = CometPath.by_spot([
						"You hold the dish on the coma for the whole pass. The cloud is thin this far out, and the reading comes in clean. Holding still against the gas burns fuel. The archive files it under your registry.",
						"The coma is thick this close. The dish reads all of it while grit off the head rattles on the plating. The hull takes a few hits. Holding still burns fuel. The reading goes on file under your registry.",
						"This close to the star the comet is boiling. The dish reads more than it ever has. The heat comes in through the hull, and rock off the head hits the plating twice. Holding still burns fuel. The reading goes on file."])}},
				{label = "Sell the pass times to the Okafor crew", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "You send the Okafor crew your pass times and your dish settings. They read the coma themselves from the far side of the system. They pay on the channel once their numbers come in."}},
			],
		},
	])


static func _tail(out: Array[Dictionary]) -> void:
	out.append_array([
		{
			id = &"comet_dust",
			title = "The dust tail",
			body = "The comet's dust tail is coming across your spot. It is mostly fine grit, with some rock in it a meter across. A plate on a boom can catch a sample as the tail goes over. The Kell Institute pays for comet dust and puts the finder's registry on it. Its courier is two systems away and will not make the pass in time. The courier's pilot asks on the channel to buy your pass times instead.",
			tags = [&"science"],
			site = &"comet",
			group = &"",
			weight = 10,
			min_danger = 1,
			max_danger = 10,
			choices = [
				{label = "Put the plate out", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(CometPath.pay_here())
					CometPath.toll_here("Rock in a comet's dust tail broke the hull.")
					return {text = CometPath.by_spot([
						"The tail is thin out here. The plate comes back dusted grey, and the dish logs every grain. Holding the boom steady burns fuel. The Kell Institute files the sample under your registry.",
						"The tail is thick this close. The plate comes back pitted, and two rocks hit the hull on the way through. Holding the boom steady burns fuel. The sample goes on file under your registry.",
						"Near the star the tail is a storm of grit. The plate comes back scorched. Rock hits the hull, and the heat off the comet comes in through the plating. Holding the boom steady burns fuel. The sample goes on file."])}},
				{label = "Sell the courier your pass times", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "The courier's pilot takes your times and pays on the channel. The courier turns for the comet's way out of the system. It will catch the tail there, thin and cold."}},
			],
		},
	])


static func _crust(out: Array[Dictionary]) -> void:
	out.append_array([
		{
			id = &"comet_crust",
			title = "The dark crust",
			body = "The head of the comet is a dark crust over ice, a few kilometers across. Jets of gas break out of it where the sun warms the crust. Your camera can map the jets while the head goes by. The Dace Survey wants maps like that to tell when a comet will break up. A survey ship one system over asks on the channel to buy your camera log as it is, without the map.",
			tags = [&"science"],
			site = &"comet",
			group = &"",
			weight = 10,
			min_danger = 1,
			max_danger = 10,
			choices = [
				{label = "Map the jets as it passes", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(CometPath.pay_here())
					CometPath.toll_here("A jet off a comet's crust threw rock into the hull.")
					return {text = CometPath.by_spot([
						"From this far out the camera gets four jets and the shape of the crust. Turning the ship to keep the head in frame burns fuel. The Dace Survey files the map under your registry.",
						"This close the camera gets every jet on the sunlit side. One of them throws rock across your spot, and the hull takes it. Turning to keep the head in frame burns fuel. The map goes on file.",
						"At the star the whole crust is breaking open. The camera maps every jet. Rock and hot gas come off the head, the hull takes both, and the ship runs hot. Turning to keep the head in frame burns fuel. The map goes on file."])}},
				{label = "Sell the raw camera log", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "You send the log as it is. The survey ship pays on the channel and says it will make the map itself. Its crew asks for your pass times as well, and you send those."}},
			],
		},
	])
