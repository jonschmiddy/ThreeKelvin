class_name OptionsPart09

## Encounters 119 to 132 of the authored table (`quoted_blind` to `the_holding_stack`), in the order `OptionTable._authored`
## joins them: `roll_for` draws by table order, so entries never move between or within files.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{
			id = &"quoted_blind",
			title = "Quoted blind",
			subject = {stage = &"structure", pieces = [&"st_quoted_blind"]},
			body = "A repair crew has a freighter's flank open at a yard on the approach. The price was agreed on the channel before anybody put a light on it. The crack runs a long way past what the quote covers. They cannot go back to the owner for more. They cannot close the plate as it is. So they hail passing ships for a cutter and an hour of somebody else's radiators. The foreman is honest about the money. There is not much of it left. He says so before he says what he wants.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			min_danger = 3, max_danger = 6,
			choices = [
				{label = "Take the long seam",
					check = {attr = &"thermal", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You run the cutter for a shift and a half with the panels wide. You never let the head get ahead of you. The seam comes out clean the whole way. The crew has the plate back on before their window closes. The foreman pays the rest of the quote. He adds most of what was going to be the crew's margin."},
					clean = func() -> Dictionary:
						Run.heat += 6
						Run.add_credits(OptionTable.purse(14))
						return {text = "You take the seam in one long pass. The radiators saturate toward the end of it. The crew finishes the corners themselves. He pays for the pass at the rate the quote allows. It is the only rate he has."},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "Two hours in, the panels are full. The head runs hotter than the plate it is cutting. You stow the cutter and stand off. The crew goes back to doing it their own way, which is slower. Nobody is sore about it. The freighter is still open when you leave."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Cut a long seam on another freighter with the vents full.")
						Run.heat += 10
						return {text = "The head is deep in the seam when the frame under it moves. The freighter's plating comes across your bow. The whole weight of the flank is behind it. The crew gets their people clear. You back off with the cutter still out and a new line in your plating. The seam is longer now than it was."}},
				{label = "Hold the plate flush while they weld", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "Two units of attitude work over a shift. You hold the plate flush while the crew runs the weld from the inside. It is dull flying and the grapple does most of it. The foreman cannot pay you what the hours are worth. He loads a crate of yard stock into your bay instead: cells, sealant, two spools of line. He counts it out loud, item by item.", material = &"event"}},
				{label = "Leave them the seam", stay = true, effect = func() -> Dictionary:
					return {text = "They keep hailing for a while after you are past. The plate stays open. The yard has other work in front of it. The price on the channel does not change."}},
			],
		},
		{
			id = &"the_even_split",
			title = "The even split",
			subject = {stage = &"single", pieces = [&"r3_frame_gutted_frame_2"], tumble = 1.5},
			body = "A dead ore hauler tumbles slowly out past the loading point. A second salvage ship came up on it inside the same hour you did. Their cutter is bigger than yours. Their pilot puts a line down the hull on the open channel. Bow to them, stern to you. Both crews work their own side and stay off the other. The stern holds the racks. She knows that, and she offered it anyway. The bow is four hours of easy plate. The stern is four hours of matching a tumble.",
			tags = [&"salvage"],
			group = &"",
			weight = 9,
			min_danger = 3, max_danger = 6,
			choices = [
				{label = "Work the stern while the tumble is with you",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						return {text = "You take the roll and hold it. For four hours the stern is as still as a dock. A whole rack comes off the mount with its cabling still on it. Behind the rack is a crate of drive spares nobody ever opened. The other crew works the bow the whole time. Neither of you crosses the line.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You match it well enough for the work. You lose the roll twice and find it again. The grapple never does anything it cannot undo. One rack comes off clean. The stern is still rolling when you stow the cutter.", module = true},
					partial = func() -> Dictionary:
						return {text = "The tumble is faster than the dish read it. The racks stay bolted where they are. You settle for what the cutter shakes loose: plate, a length of conduit, and a locker that opened itself.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Matched the roll of an ore hauler one beat late. Its stern came the other way.")
						return {text = "You come in on the roll a beat late. The stern goes one way and you go the other. You meet where the mount is thickest. Your own plating wears most of it. The other crew stops long enough to ask if you want a line. Then they go back to the bow."}},
				{label = "Take the bow and work fast", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "Four hours of easy plate off a half that is not fighting you. Two units go on holding position against the roll while you cut. It is the side nobody wanted, and it is still a bay of good plate. The other crew is on the stern before your second pass is done. They are still there when you go.", material = &"wreck"}},
				{label = "Let them have the hull", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and go. Their cutter is bigger and their crew is rested. The hauler will be just as dead in four hours. They will still be cutting it then."}},
			],
		},
		{
			id = &"receipted_twice",
			subject = {stage = &"single", pieces = [&"ship_forked"], size = 0.5, lights = &"run", at = Vector2(60.0, -40.0)},
			title = "Receipted twice",
			body = "A shipping agent is on the approach channel. She is asking every hull with a dish for a mass reading. A shipment of drive parts was receipted at two stations eight days apart. The ship carrying it called at one of them. Either somebody upstream was paid twice for eleven crates. Or they were paid once for twenty-two crates that were never built. She has the whole filing and nothing to read mass with. She will pay for a reading. She will pay more for a reading with a registry on it that is not hers.",
			tags = [&"contract", &"signal"],
			group = &"",
			weight = 9,
			min_danger = 3, max_danger = 6,
			choices = [
				{label = "Put the dish on the consignment",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(28))
						return {text = "Eleven crates. The mass sits within a point of what eleven crates of drive parts should read. The second receipt was written against a load that was never on any ship. The station that wrote it is four crossings behind you and does not know yet. She pays the reading fee and the correction fee together. She copies the filing across to you as well. She wants it stored somewhere that is not her own drive."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(12))
						return {text = "The mass reads high by enough to matter. It reads low by enough to argue about. You log what the dish says and sign that figure. She takes it away to whoever has to decide what it means. She pays the reading fee without a word."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(4))
						return {text = "The shipment is stacked behind two other loads. Your dish spends an hour reading their plating instead. You give her the figure and flag it as unsure. That makes it useless to her. She pays the standing fee for answering the hail and goes back to asking."},
					botched = func() -> Dictionary:
						Run.add_credits(-25)
						return {text = "Your figure is off by a whole crate. The file goes inward with your registry on the reading. Nobody is angry about it. The station at the far end holds the shipment eleven more days. A third instrument settles the argument. The cost of those eleven days goes against your reading."}},
				{label = "Sit with her and copy the filing across", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					Run.add_credits(OptionTable.purse(8))
					return {text = "Most of a shift with the reactor idling. The dish points at her ship instead of the shipment. Eight days of receipts and two stamps from two stations. There is a transfer note with the wrong registry typed in twice. You take a copy of all of it. She pays you a clerk's fee for the shift. She talks the whole time, and about half of it is about the paperwork."}},
				{label = "Stay out of the file", stay = true, effect = func() -> Dictionary:
					return {text = "She is still on the channel asking when you pass out of range."}},
			],
		},
		{
			id = &"walking_the_tank",
			title = "Walking the tank",
			body = "A refinery out past the last dock has a freighter's window in eleven hours. Its tender is dead. The ore tank is loaded and sitting where it was filled. Nothing on the site has the thrust to walk it to the loading point in time. The site foreman has been on the channel most of a shift. He is offering the freight rate he was going to pay the tender, and it is all the money he has. He wants any ship with a working drive to take it. If no one does, the freighter leaves empty.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Put your bow on the tank and push",
					check = {attr = &"thrust", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You get on it square and hold the push for nine hours. The rate stays inside what the anchor points can take. The tank arrives with two hours of the window left. The freighter takes all of it. The foreman pays the freight rate in full. He puts a bay of ore across as well, off the top of the tank. He has more ore than he has money.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(16))
						return {text = "You get it there with forty minutes to spare. Two of the nine hours went on correcting a drift you put in yourself. The freighter takes the tank, and the foreman pays the rate without mentioning the drift."},
					partial = func() -> Dictionary:
						Run.heat += 12
						Run.add_credits(OptionTable.purse(5))
						return {text = "The tank comes off its anchor harder than you meant. You spend the next six hours taking that back out of it. The drive is up and the vents work behind it the whole way. It arrives after the window. The freighter takes what it can hold in the time it has. The rest stays on the tank. He pays part of a rate for part of a job."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Pushed a loaded ore tank past what its anchor points would hold. A corner of it came around into the plating.")
						return {text = "The push goes in off centre. The tank starts a slow yaw you cannot get in front of. One corner comes around into your plating at walking speed. At that mass, walking speed is enough. The tank stops where it stops. The freighter leaves on time and empty."}},
				{label = "Sell the site your reserve", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "Their last working tug can do it in three trips if it has fuel to burn. Two units go across the line in an hour. The tug is moving before the pump is cold. The foreman pays in ore off the top of the tank. He would rather part with the ore than the money. The tug is out at the anchor before he finishes saying it.", material = &"mining"}},
				{label = "Hold your heading", stay = true, effect = func() -> Dictionary:
					return {text = "He is still on the channel two hours later. He is offering the same rate to a different set of ships. The tank sits where it was filled. The window closes whether anybody answers him or not."}},
			],
		},
		{
			id = &"the_cracked_frame",
			title = "The cracked frame",
			subject = {stage = &"structure", pieces = [&"st_the_cracked_frame"]},
			body = "A hauler is up on a yard's clamps with a crack across two frame members. The quote for the work is more than the woman flying it has. She has had the ship eleven years. She is selling fittings off it to close the gap. A spare pump, a rack of cells, and an instrument head she bought new four years ago. The yard offered for all three at the price a yard offers. So she is on the open channel instead. She is telling everybody on the approach what she has and what she wants for it.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Hold the frame in tension while they weld",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						return {text = "The grapple takes the hauler's weight across both members. Your own frame takes it after that, for eleven hours, while the yard runs the weld in passes. Nothing moves more than the yard allows for. She gives you the instrument head. She has not stopped looking at it since she agreed to it. The yard adds the two cut sections of old member, which are good plate.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "Eleven hours of holding still. Your own plating reports numbers the board records and does not explain. The weld takes. She gives you the instrument head in a box, with the calibration sheet still in it.", module = true},
					partial = func() -> Dictionary:
						return {text = "You hold it six hours. Then your own frame starts reporting numbers the board flags. You put the load down while putting it down is still your idea. The yard gets one member welded out of two. The job is not finished, so she keeps the instrument head. She gives you the section they cut out of the first member instead.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Held an eleven-year-old hauler in tension on the grapple. Something in your own frame let go first.")
						return {text = "The load comes on uneven and you correct into it instead of out of it. Something in your own structure goes before anything in hers does. The grapple releases itself, the way it is built to. The hauler comes down on the clamps hard. The yard has to look at all of it again."}},
				{label = "Buy the pump at her figure", cost_credits = 35, effect = func() -> Dictionary:
					Run.add_credits(-35)
					return {text = "She names a figure and it is a fair one. She does not move off it while you think. The pump comes across in a crate with its service record taped to the lid. The money is on the yard's account before your grapple has stowed. She watches the transfer clear without saying anything.", module = true}},
				{label = "Leave her the quote", stay = true, effect = func() -> Dictionary:
					return {text = "She is still listing the fittings on the channel when you pass out of range. The yard is in no hurry. The clamps are rented by the day, and the day is already paid for."}},
			],
		},
		{
			id = &"the_flagged_stack",
			title = "The flagged stack",
			subject = {stage = &"single", pieces = [&"r4_pumprack_pump_on_a_rack_1"]},
			body = "A repair outfit on a busy station has a freighter open and no pump for it. The pump they bought is on a rack outside the dock. There is a hold against it. The shipment it arrived in was filed under a registry that closed last year. The office that can lift the hold answers in nine days. The freighter leaves in two. Their foreman reads you the receipt over the channel twice. Then he asks if your ship is the sort that comes off a rack without lighting up the board.",
			tags = [&"contract", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Come off the rack with the transponder cold",
					check = {attr = &"stealth", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You come in on attitude jets with everything but the grapple cold. The crate goes in the bay and you are back on the lane. The dock's board has nothing to log except a ship that changed heading. An hour later the crate goes across to the outfit in the open. The transfer is entirely legal. They pay the whole figure and the freighter leaves on time."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(16))
						return {text = "The board sees something and logs it as traffic. It stays traffic. You come away with the crate. The outfit pays the figure, less what they spent on somebody at the dock who also saw something."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "A tender works the rack all shift, doing perfectly ordinary things. You hold off it and burn fuel. By the time it clears, the freighter's window is too close to be worth the approach. You break off. The outfit stops answering. The crate is still on the rack when you leave."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Pulled a crate off a station rack before the clamp let go.")
						return {text = "The clamp reads the grapple as a dock loader and does not release on your schedule. You take the crate and a length of the rack with it, across your own plating. The board logs every second. The outfit gets the pump, and no one at the dock mentions the rack to you."}},
				{label = "Sit off the rack and read the dock for them", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					Run.add_credits(OptionTable.purse(10))
					return {text = "One unit of station keeping, and most of a shift with the dish on the dock's traffic. You log when the rack is worked and when it is not. Their foreman takes the pattern. He sends his own tender in on the third quiet window. They pay for the watch at the rate they pay their own people. It clears before the tender is back."}},
				{label = "Keep clear of the rack", stay = true, effect = func() -> Dictionary:
					return {text = "The freighter leaves in two days, with a pump in it or without one. The outfit puts the same question to the next ship on the approach. The crate sits on the rack. The hold is still against it."}},
			],
		},
		{
			id = &"the_flat_rate",
			title = "The flat rate",
			subject = {stage = &"single", pieces = [&"r4_pod_cargo_pod_2"]},
			body = "A tow was agreed at a flat rate on the channel. Nobody weighed the load first. The outfit that took it is two people with a good drive and no margin. The load is a mining tender full of wet ore that nobody drained before it left. They are four days into a six-hour job. The receiving dock will not take the line until the roll comes off the tender. The pilot cannot fly that part, so he is paying somebody else to do it. The rate was thin the day it was written.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Match the roll and take it out of the tender",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(28))
						return {text = "You get alongside and match it. Then you spend three hours giving the tender small corrections, in the places where the ore is not. The roll comes down inside what the dock will accept. The dock takes the line on the first try. He pays the figure he agreed. Then he adds most of what the tow has left him. He works it out on the board in front of you."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						return {text = "Four hours of correcting a load that answers late every time. The roll comes down to something the dock argues about and then accepts. He pays the figure he agreed. There is nothing left in the rate after it."},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "You take most of the roll out and put some of it back in twice. The drive works the whole time and the vents work behind it. The dock refuses the line at that rate of roll. The two of them wait about a day for it to damp on its own, and that day is unpaid."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Went alongside a rolling mining tender full of wet ore. The ore moved before you did.")
						return {text = "You go in close on a load whose centre shifts every time it rolls. This time it shifts early. The tender comes across your flank at the top of the roll. It takes plating with it. The roll is worse afterwards than it was before. The pilot says nothing on the channel for a while. Then he asks if you are all right."}},
				{label = "Take the drained ore as the fee", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You spend two units holding station alongside while they pump the wet ore into your bay as payment. The roll comes down as the tank empties. After four hours of dull flying, you have a bay of ore.", material = &"mining"}},
				{label = "Let them finish it themselves", stay = true, effect = func() -> Dictionary:
					return {text = "They are still alongside it when your dish loses them. The tender rolls at the rate it has rolled for four days. The dock at the far end is not expecting anybody early."}},
			],
		},
		{
			id = &"the_thrower",
			title = "The thrower",
			subject = {stage = &"structure", pieces = [&"st_the_thrower"], with = [{piece = &"r2_thrower_canister_on_sled_2", scale = 0.5, turn = 20.0, swim = true, tumble = 3.0, at = Vector2(100.0, 150.0)}, {piece = &"r2_thrower_canister_on_sled_2", scale = 0.5, turn = -30.0, swim = true, tumble = 3.0, flip = true, at = Vector2(138.0, 205.0)}, {piece = &"r2_thrower_canister_on_sled_2", scale = 0.5, turn = 50.0, swim = true, tumble = 3.0, at = Vector2(58.0, 232.0)}]},
			body = "A mass driver sits on a rock, throwing ore canisters out. One goes every eleven minutes. It has been firing since before anybody stopped watching it. The bearing ends at a receiving station that stopped answering years ago. The loader still feeds the rail. Your dish can follow the line of canisters as far as it reaches. The sleds they ride out on come off at the muzzle. They drift back toward the rock in a slow cone.",
			tags = [&"salvage"],
			group = &"",
			weight = 9,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Catch one off the stream",
					check = {attr = &"maneuver", need = 7},
					met = func() -> Dictionary:
						return {text = "You sit in the line an hour out from the muzzle. The canisters have spread by then, so you can pick one. The grapple takes it at almost no closing speed. It is ore, graded and packed. Its sled comes aboard with it, guidance unit sealed and still drawing off its own cell. The next canister goes past eleven minutes later on the same bearing.", module = true, material = &"mining"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You burn for an hour to get into the right place. You take one cleanly at the end of that. The drive is hot for it. The canister holds ore, graded and packed and twenty years in the cold. The sled goes on outward without it.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "Two go past while you are still lining up. You touch the third and lose it. It carries on outward with a dent in it and your bearing written across its side. You come away with nothing. The drive is hot from three attempts."},
					botched = func() -> Dictionary:
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(4), "A loaded ore canister, caught too close to a mass driver's muzzle.")
						return {text = "You try a fourth time, close in near the muzzle. The canister there is still under power. It catches the flank and keeps going on its bearing. It does not lose a metre a second. The plating on that side is opened from bow to midships."}},
				{label = "Work the loading rack at the rock", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You hold station beside the rock. It shakes every eleven minutes and you trim against that. The grapple takes one canister off the rack before the loader can get it to the rail. Holding that close costs a day of fuel. The loader reaches past you for the next one and carries on.", material = &"mining"}},
				{label = "Leave it firing", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and the gap between shots and go. The next canister goes out eleven minutes after you do. It takes the same line as all the rest. The station at the far end of that line stopped answering years ago."}},
			],
		},
		{
			id = &"the_bonded_load",
			title = "The bonded load",
			subject = {stage = &"single", pieces = [&"ship_lightfreighter"], lights = &"battery"},
			body = "A depot ship sits off the approach with one woman aboard. A sealed load waits in its racks. The order was placed nineteen years ago, by a manufacturer that has since stopped existing. Nobody ever came for it, and her orders say hold until they do. She may close an order that nobody can collect. First somebody has to read its seals against a current registry. Her own reader is older than the load. She has been waiting for a ship with a better one. She says so on the first hail.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Read the seals against the registry",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "The seals answer a current reader in about a minute. They match the order in every line but one: the collector is on no registry you can reach. That lets her close the order out. She pays the reading fee from the depot account and sends over the file. It holds the order, the route it was meant to take, and nineteen years of holding notes."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						return {text = "Your reader gets four seals out of six. Four is what the depot rules ask for. She closes the order on that. She pays the fee at the reduced rate her sheet allows for a partial reading. Then she puts the file back in the drawer it came out of."},
					partial = func() -> Dictionary:
						Run.heat += 10
						Run.add_credits(OptionTable.purse(6))
						return {text = "Two seals read and the rest are dead cells. Two is not enough for anything. She pays the standing rate for the attempt, which is small. She pays it without argument and goes back to holding the load."},
					botched = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "Your reader writes to the seals instead of reading them. The depot locks the load for ninety days. Neither of you can reach the rule that did it. You stay on the channel with her for a day and a half. The reactor idles the whole time, and the load stays locked."}},
				{label = "Buy the load at the order's price", cost_credits = 30, effect = func() -> Dictionary:
					Run.add_credits(-30)
					return {text = "The order priced it nineteen years ago. Her sheet has no field for repricing anything. You pay what the order says. She sends one case across on the line. It holds stores and spares, packed by people who expected to see it again inside a month.", material = &"event"}},
				{label = "Let her hold it", stay = true, effect = func() -> Dictionary:
					return {text = "She logs your arrival against the order. The order has a field for ships that came and did not collect. Then she goes back to waiting. The load has been in the racks longer than she has been aboard."}},
			],
		},
		{
			id = &"the_metered_dock",
			title = "The metered dock",
			subject = {stage = &"single", pieces = [&"r6_oredock_ore_dock_pushed_3"]},
			body = "An ore dock stands lit with nobody on it. The last fuel delivery came after the last crew left, so the tanks are full. The pumps run off the dock's own power, which has not failed yet. The meter has not failed either. It logs hull number, mass and quantity. It bills an office that stopped answering years ago, and it keeps the record anyway. Below a certain draw rate it writes nothing at all. It was built to ignore a leak.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Draw under the meter",
					check = {attr = &"stealth", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 4
						return {text = "You bring the line up slowly. You hold it just under the rate the meter cares about. You sit there most of a day. Four units come across, and the log shows a dock that used no fuel today. The lights stay on the whole time."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						return {text = "You hold the rate down for six hours. You lose patience in the seventh. The meter starts writing in the eighth. Two units reach the tank, and a line goes into a ledger nobody reads, against a hull number that is yours."},
					partial = func() -> Dictionary:
						Run.heat += 12
						Run.fuel += 1
						return {text = "The pumps stall against a rate that low, and they keep stalling. You spend more of the day restarting them than drawing from them. One unit reaches the tank. The ship is warm from nine hours of its own systems, with the drive cold."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A dock's fuel line, frozen for years, opened too fast.")
						return {text = "You push the rate up to where the meter would see it. The line lets go at the boom. What is in it comes out under pressure, across your flank. None of it reaches your tank. The pumps keep running for an hour with nothing to push."}},
				{label = "Settle the sheet and pump", cost_credits = 34, effect = func() -> Dictionary:
					Run.add_credits(-34)
					Run.fuel += 3
					return {text = "The meter takes a settlement from anybody who offers one. The rate was printed the year the dock opened. You pay it and the pumps run at full. Three units come across in under an hour. The receipt prints and drops into a tray that already holds a stack of them."}},
				{label = "Leave the tanks alone", stay = true, effect = func() -> Dictionary:
					return {text = "You go past with your tank as it is. The dock keeps its lights on and its meter running."}},
			],
		},
		{
			id = &"the_service_cradle",
			title = "The service cradle",
			subject = {stage = &"structure", pieces = [&"st_the_service_cradle"]},
			body = "A service cradle hangs off a dead yard. Its arms open and close on nothing, on a cycle it has kept for years. It is built for freighters. Whatever it clamps, it services. It pulls the worn units off and fits whatever is still on its racks, without asking the ship anything first. The racks are not empty. The arms close at the pressure a freighter is framed for. No ship that size has come through here in years.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Put the ship in the arms",
					check = {attr = &"hull", need = 7},
					met = func() -> Dictionary:
						return {text = "The arms take you across the middle and hold. The plating carries the pressure the way plating should. The cradle works on you for two hours. It lifts a sealed unit off its rack and leaves it in your grapple. The worn part it pulled goes in there too, because the cradle has nowhere else to put it. Then it opens and goes back to its cycle.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 12
						return {text = "The arms close harder than you would choose. They hold you there for the whole cycle. You come out with one unit off the racks, which the cradle decided you were short of. The ship is hot from two hours of somebody else's power running through it.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "It clamps and reads whatever it reads off your flank. Nothing on its racks answers that. Two hours in the arms and no work done. The drive is warm from holding attitude against the arms. The cradle will not open until the cycle ends."},
					botched = func() -> Dictionary:
						Run.heat += 10
						Run.take_hull_damage(OptionTable.toll(4), "Clamped in a cradle built for freighters, at a freighter's pressure.")
						return {text = "The arms shut at the pressure they were set to twenty years ago. Something gives amidships, and it gives slowly, over about four seconds. The cradle ends its cycle and lets you go. Then it shuts on nothing and starts again."}},
				{label = "Work its racks from outside", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You stay out of the arms and work the racks with the grapple. You trim the whole time to keep clear of the cycle. The arms do not care where you are. A day of fuel goes into holding that station. You come away with one piece off the nearest rack.", material = &"wreck"}},
				{label = "Leave it cycling", stay = true, effect = func() -> Dictionary:
					return {text = "You go around the yard and leave the cradle to its arms. It closes on nothing, and opens, and closes again. The yard behind it is dark on every band."}},
			],
		},
		{
			id = &"the_uncollected_order",
			title = "The uncollected order",
			body = "A beacon on the approach repeats a work order every hour. Collect the load at this bearing. Deliver it to this address. Payment on delivery against this vault code. The bearing is a tether four hours off, with the load still on it. The load is counted and sealed and labelled in a script nobody uses now. The address is a station that is not there. The vault code is not one anybody will honour. The beacon has been asking for years, and its cell is good for years more.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Open the load and read the list",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						return {text = "The list reads clean once you have the cell voltage right. It says what is in every case, and which of them still hold a charge. One does. You take that one off the tether. The order's own file comes with it: the posting, the address, and the name of whoever signed the job out.", module = true},
					clean = func() -> Dictionary:
						return {text = "Half the list reads and the other half went with the cells. You open the cases that answer and find one sealed unit still holding. You take it off the tether. The rest stay counted and sealed, where the order says they are.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 10
						return {text = "Nothing on the load answers a reader any more. The cutter opens one case on the tether to see what is in it. It holds stores, packed dense and dry. You take that case and leave the others as they were.", material = &"event"},
					botched = func() -> Dictionary:
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(3), "A sealed case, still under pressure, cut open on the grapple.")
						return {text = "The case you pick is under pressure. It has been since the day it was packed. It opens along the seam the cutter made. What was in it goes through your bow at speed. The rest of the load hangs on the tether, counted and sealed."}},
				{label = "Record the beacon through a full cycle", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "The order repeats hourly, and the long version runs once a day. That one carries the schedule, the routing, and every amendment made to either. You hold station a full day to get the whole of it. Burning to stay put costs you a day of fuel. You take the recording with you, and a coil of spare line off the tether.", material_id = &"frayed_line"}},
				{label = "Leave the order standing", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and go on. The beacon puts the order out again on the hour. The strength is the same. The address it names has not been there for a long time."}},
			],
		},
		{
			id = &"the_outbound_five",
			title = "The five going out",
			subject = {stage = &"field", pieces = [&"role:barge", &"role:hauler", &"role:small", &"role:hauler", &"role:tender"], count = 5, near = 1, deep = 2, lift = 40.0, span = 440.0, height = 240.0, seed = 5, tumble = 0.0, drive = true},
			body = "Five ships that went in are coming out, in a line, slowly. They pooled their fuel two months ago, and it is still not enough. The heavy one is an ore carrier. Its drive will hold a course and will not build speed. The other four cannot spare the burn to push it. The pilot flying the lead hails to ask what a push is worth. She names a figure before you answer. It is most of what the five of them have left between them.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Push the ore carrier up to speed",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You get your bow on the carrier's stern plate. You push for nine hours. It comes up to a speed the other four can hold without extra burn. They pay the figure she named, out of five accounts. They send over their run inward as well. It has every bearing they took, every place they stopped, and the day they turned around."},
					clean = func() -> Dictionary:
						Run.heat += 12
						Run.add_credits(OptionTable.purse(20))
						return {text = "Nine hours of pushing brings the carrier most of the way up. It does not reach the speed they wanted. The drive runs hot the whole time. They pay what she named and do not argue the shortfall. The line forms up around the carrier and goes on out."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.add_credits(OptionTable.purse(8))
						return {text = "The carrier will not hold its line under the push. You spend most of the burn correcting for it. You give it up in the sixth hour, down a day of fuel. They pay you for the hours you put in."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Pushed an ore carrier that would not come up to speed. The two hulls went into each other.")
						return {text = "The carrier yaws under the push in the fourth hour. Your bow goes into its quarter instead of its plate. Both hulls open, and theirs is worse. They stop talking to you. They go to work on their own ship, and nobody is paid."}},
				{label = "Take the mass they cannot carry", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "They are dumping mass to get home and would sooner it went to a ship. You pump two units into the carrier's tank. Ore comes back the other way, graded and bagged. The rate suits them, because they are not carrying it either way.", material = &"mining"}},
				{label = "Let them work it out", stay = true, effect = func() -> Dictionary:
					return {text = "You give them the bearings you have and go on past. An hour later the five of them are still in a line. They are still slow and still pointed out. The carrier is still setting the speed."}},
			],
		},
		{
			id = &"the_holding_stack",
			title = "The holding stack",
			subject = {stage = &"on_rock", loose = true, base = &"paint_rock_a1", r = 104.0, pieces = [&"r2_holding_old_container_1", &"r2_holding_old_container_2", &"r2_holding_old_container_1"], count = 3, size = 0.5, spread = Vector2(124.0, 96.0), turns = 12.0, seed = 5, clamp = &"r4_holding_cold_welded_clamp_1", face = Vector2(-34.0, -6.0)},
			body = "Containers are clamped to a rock in rows, forty or fifty of them. They were dropped here for a carrier that stopped coming. The oldest labels carry a date twenty-two years old. They also carry a consignor whose name is on nothing else out here. The clamps were shut warm and have sat at three kelvin ever since. They have cold-welded to the rails. Getting one off means running the cutter until a clamp softens. The heat that takes comes back down the grapple.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Cut a clamp warm and take the container",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						return {text = "You run the cutter in long passes with the radiators wide. The clamp lets go in about an hour. Not much heat comes back into the ship. The container comes across whole. The consignment papers are in a sleeve on the door. They are printed, stamped twice, and readable from the first line to the last.", material = &"event"},
					clean = func() -> Dictionary:
						Run.heat += 14
						return {text = "The clamp takes two hours. Most of those hours come back as heat down the grapple. You get the container off the rail. Then you sit a while with the drive cold, shedding what the job put into you.", material = &"event"},
					partial = func() -> Dictionary:
						Run.heat += 22
						return {text = "You pick a clamp on the shaded side. It will not soften at any rate the grapple can carry. You stop when the heat has nowhere left to go. The container is still on the rail. The ship is warm all the way through."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Heat off a cold-welded clamp, taken back down the grapple. It went into the drive section.")
						return {text = "You stay on the clamp past what the radiators can keep up with. The clamp gives, and so does something in the drive section. The container comes off the rail and drifts clear. You are in no state to go after it."}},
				{label = "Run the cutter hot and take one anyway", effect = func() -> Dictionary:
					Run.heat += 20
					return {text = "You put the cutter on the nearest clamp and keep it there. You do not pace the job at all. The container is off the rail in forty minutes. The ship carries what that cost for the rest of the day. The radiators stay wide and the drive stays down.", material = &"event"}},
				{label = "Leave the rows as they are", stay = true, effect = func() -> Dictionary:
					return {text = "You read the labels off the near row and go. The rows are still clamped to the rock when the dish loses them. They sit in the order somebody set them down in twenty-two years ago."}},
			],
		},
	])
	return out
