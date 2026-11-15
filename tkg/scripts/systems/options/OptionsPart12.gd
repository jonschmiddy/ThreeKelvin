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
			title = "The comet's cloud",
			body = "A comet is passing close enough to read its gas cloud, and a mining crew will pay to know when it passes.",
			tags = [&"science"],
			site = &"comet",
			group = &"",
			weight = 10,
			min_danger = 1,
			max_danger = 10,
			choices = [
				{label = "Read the gas cloud", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(CometPath.pay_here())
					CometPath.toll_here("Rock in a comet's gas cloud broke the hull.")
					return {text = CometPath.by_spot([
						"The cloud is thin this far out, and the reading comes in clean.",
						"Grit off the head rattles on the plating while the dish reads the thick cloud.",
						"The comet boils this close to the star, and rock and heat come through the plating."])}},
				{label = "Sell them the timing", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "The mining crew pays and reads the comet themselves."}},
			],
		},
	])


static func _tail(out: Array[Dictionary]) -> void:
	out.append_array([
		{
			id = &"comet_dust",
			title = "The dust tail",
			body = "A comet's rocky dust tail is crossing your spot, and a courier who will miss it pays for its course.",
			tags = [&"science"],
			site = &"comet",
			group = &"",
			weight = 10,
			min_danger = 1,
			max_danger = 10,
			choices = [
				{label = "Catch a dust sample", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(CometPath.pay_here())
					CometPath.toll_here("Rock in a comet's dust tail broke the hull.")
					return {text = CometPath.by_spot([
						"The tail is thin out here, and the plate comes back dusted gray.",
						"The plate comes back pitted, and two rocks hit the hull.",
						"Near the star the tail scorches the plate, and rock and heat come through the hull."])}},
				{label = "Sell its course", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "The courier pays and goes to meet the tail where it leaves the system."}},
			],
		},
	])


static func _crust(out: Array[Dictionary]) -> void:
	out.append_array([
		{
			id = &"comet_crust",
			title = "The dark crust",
			body = "Gas jets throw rock off a passing comet's crust, and a survey crew will buy your camera log of them.",
			tags = [&"science"],
			site = &"comet",
			group = &"",
			weight = 10,
			min_danger = 1,
			max_danger = 10,
			choices = [
				{label = "Film the jets", burns = true, reads = 1, effect = func() -> Dictionary:
					Run.drain_fuel(OptionTable.science_fuel())
					Run.add_data(CometPath.pay_here())
					CometPath.toll_here("A jet off a comet's crust threw rock into the hull.")
					return {text = CometPath.by_spot([
						"From this far out the camera gets four jets and the shape of the crust.",
						"The camera gets every jet on the sunlit side, and one throws rock into the hull.",
						"The crust breaks open this near the star, and rock and hot gas hit the hull."])}},
				{label = "Sell the camera log", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(10))
					return {text = "The survey crew pays and maps the jets from your log."}},
			],
		},
	])
