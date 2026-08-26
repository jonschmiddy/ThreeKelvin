# -*- coding: utf-8 -*-
# Single source for batch-03. Emits the markdown file AND the prototype data.
O = []
def opt(**k): O.append(k)

opt(id="the_braid", label="The braid", tags="salvage", group=None, weight=7,
 gate="regions: FAUNA, FRONTIER · needs_fauna",
 teaser="Something large is moving through, and moving fast.",
 full="Nine of them, in line, big enough that the dish reads them as terrain. They are running a migration lane they have been running since before anyone was out here to name it, and they are shedding a wake you could ride most of the way to the next shell.\n\nThey are not hostile. They are also not paying attention, and the smallest of them is longer than your ship.",
 choices=[
  dict(label="Ride the wake", check=("maneuver",6), bands=dict(
   MET=("You slot into the draught behind the third one and let it carry you. It never registers you were there.", {"fuel":18}),
   CLEAN=("You hold the lane most of the way before the turbulence shrugs you out of it.", {"fuel":11}),
   PARTIAL=("You misjudge the interval and spend the whole run fighting the wash instead of using it.", {"fuel":-8}),
   BOTCHED=("The fourth one changes its mind about the lane. You are close enough that the flank takes your dorsal plating with it.", {"hull":-14}))),
  dict(label="Take what they shed", flat="You hold off the lane and collect what comes loose in the wake — plate, ice, a lifetime of accreted junk.", gain={"exotic":1,"credits":25}),
  dict(label="Let them pass", decline=True, flat="Nine of them, in line, going somewhere. You wait, and then they are not there any more.")])

opt(id="refinery_still_lit", label="Refinery, still lit", tags="salvage", group="refinery", weight=8,
 gate="regions: TERRITORY, COSMOPOLITAN · min_development SETTLEMENT",
 teaser="An automated refinery, running with nobody aboard.",
 full="Cygnet built it, staffed it, and pulled the staff out four years ago when the seam under it stopped paying. Nobody told the refinery. It is still drawing on the seam, still cracking what it draws, and still stacking the output in a yard nobody has emptied since.\n\nThe yard is four years deep. The cracking towers are at operating temperature and the operating temperature is not survivable, which is why the yard is still full.",
 choices=[
  dict(label="Go in for the yard", check=("thermal",5), bands=dict(
   MET=("You work the yard in three passes with the vents wide and never once go amber. Four years of output, and you take what fits.", {"exotic":2,"credits":60}),
   CLEAN=("Two passes, and you leave with a full hold and a reactor that will want a minute.", {"exotic":1,"credits":40,"heat":7}),
   PARTIAL=("One pass. You come out with an armful and a cabin you cannot stand in.", {"credits":25,"heat":15}),
   BOTCHED=("A tower cycles while you are alongside it. You leave with nothing but the temperature.", {"heat":24}))),
  dict(label="Shut it down first", flat="Six hours to talk the control stack into standing down, and it stands down apologetically. The yard is cool by the time you reach it and half of what you wanted has cooked in place.", gain={"exotic":1,"credits":30}),
  dict(label="Leave it running", decline=True, flat="It will keep cracking a seam that stopped paying, and stacking a yard nobody comes to. Nothing you do here changes the second part.")])

opt(id="the_sweep", label="The sweep", tags="salvage", group="refinery", weight=6,
 gate="regions: any · min_danger 4",
 teaser="A wreck inside a pulsar's sweep, and a gap between passes.",
 full="The beam comes round every eleven seconds and it has been sterilising this arc for longer than there has been anyone to sterilise. Sitting in it is a survey hull that got the interval wrong once.\n\nEleven seconds is enough to get in. It is enough to get out. It is not obviously enough to do both and take anything with you.",
 choices=[
  dict(label="Time the interval", check=("thermal",7), bands=dict(
   MET=("Three intervals, three passes, and you are clear before the fourth. Whatever killed them was not the arithmetic.", {"module":1,"credits":45}),
   CLEAN=("Two intervals. You take the rack you came for and eat most of the third pass getting clear.", {"module":1,"heat":9}),
   PARTIAL=("You get inside, get turned around, and spend the gap finding the way back out.", {"heat":18}),
   BOTCHED=("You are still alongside when it comes round. The hull holds. Everything on the hull does not.", {"heat":26}))),
  dict(label="Log the bearing", decline=True, flat="You mark the wreck, note the interval, and leave both for somebody with better vents and worse judgement.")])

opt(id="tug_work", label="Tug work", tags="contract", group=None, weight=9,
 gate="regions: COSMOPOLITAN, TERRITORY · needs_berth · min_development CITY",
 teaser="A hauler wants a push and the yard tugs are all busy.",
 full="A bulk hauler has lost attitude control in a berth queue nine ships long, and the yard's own tugs are all committed for the next eleven hours. Every hour she sits there is an hour nine other ships are not moving, and the berth office is beginning to take an interest in whose fault that is.\n\nShe needs about four minutes of somebody else's engine and a pilot willing to put their nose against a hull forty times their mass.",
 choices=[
  dict(label="Put your nose on her", check=("thrust",5), bands=dict(
   MET=("Four minutes, one contact point, no scoring on either hull. The queue moves and somebody in the office writes down which ship did it.", {"credits":70}),
   CLEAN=("Six minutes and a stripe down your flank that will polish out. The queue moves.", {"credits":55}),
   PARTIAL=("You get her turned but not clear, and the yard tug that finally arrives gets paid the difference.", {"credits":20}),
   BOTCHED=("You put twelve tonnes of thrust into a hull that was not braced for it and both of you learn something.", {"hull":-8}))),
  dict(label="Sell her the fuel instead", flat="She cannot manoeuvre but she can burn. You sell her enough to get clear under her own power, at a rate she is in no position to argue with.", gain={"fuel":-20,"credits":85}),
  dict(label="Wait in the queue", decline=True, flat="Eleven hours. You are not going anywhere in particular, and neither is anyone else.")])

opt(id="silt", label="Silt", tags="salvage", group=None, weight=7,
 gate="regions: FAUNA, FRONTIER",
 teaser="A dust shoal, and something inside it that is not dust.",
 full="A shoal of fines and ice-grit, dense enough that the dish loses the far side of it. It has been accreting here for a long time and it collects whatever comes through — which is how you can see one hard return in the middle of it, ship-sized, that has not moved in a while.\n\nGoing in means going in blind. The grit is slow and soft and there is a very great deal of it.",
 choices=[
  dict(label="Feel your way in", check=("maneuver",5), bands=dict(
   MET=("You go in on attitude jets and touch nothing on the way. It is a survey cutter, intact, and nobody has been here first.", {"module":1,"credits":40}),
   CLEAN=("You clip something soft on the way in and it does not matter. The cutter's racks come away clean.", {"module":1}),
   PARTIAL=("You find her, get one panel open, and lose your bearings badly enough that leaving becomes the priority.", {"credits":30}),
   BOTCHED=("Something in the shoal is harder than the rest of it and you find that out with your bow.", {"hull":-13}))),
  dict(label="Sweep the edge", flat="You work the outside of the shoal where the grit is thin, and take what it has collected there. Nothing dramatic. Enough to matter.", gain={"exotic":1,"credits":20}),
  dict(label="Go round", decline=True, flat="It is a very large amount of dust and it is in no hurry.")])

opt(id="the_queue", label="The queue", tags="contract", group="berth2", weight=8,
 gate="regions: COSMOPOLITAN · needs_berth · min_development CITY",
 teaser="A berth slot, held by somebody who no longer needs it.",
 full="Nine ships deep and the office is honest about it: the queue is the queue. But the fourth ship in it has been fourth for two days because her charter fell through, and she is holding a slot she cannot use and cannot sell back.\n\nShe can sell it sideways. The office does not mind who docks as long as somebody does.",
 choices=[
  dict(label="Buy her slot", gate_credits=45, flat="Forty-five credits and a transfer that takes about a minute. You dock nine ships early and she gets something out of two wasted days.", gain={"credits":-45,"module":1}),
  dict(label="Trade her fuel for it", flat="She has no charter and no reason to sit here. You give her enough to leave and take the slot she was sitting on.", gain={"fuel":-25,"module":1}),
  dict(label="Wait your turn", decline=True, flat="The queue is the queue. It moves, eventually, in the order it says it will.")])

opt(id="cold_labour", label="Cold labour", tags="contract", group=None, weight=8,
 gate="regions: LAWLESS, TERRITORY · min_danger 2",
 teaser="A breaker's crew wants to test a cutter on a live hull.",
 full="Redline yard, or something wearing the colours. They have a new cutting head and no confidence in it, and they would rather learn what it does wrong on somebody else's plating than on the hull they are contracted to take apart next week.\n\nThey are offering money to put your flank against it for an hour. They are very clear that they do not know what it will do.",
 choices=[
  dict(label="Give them the flank", check=("hull",5), bands=dict(
   MET=("The head works exactly as advertised and your plating takes it without complaint. They pay, and they pay well, because now they know.", {"credits":95}),
   CLEAN=("It bites deeper than the spec said. You come away paid and scored.", {"credits":80,"hull":-4}),
   PARTIAL=("It bites much deeper than the spec said, and they stop the test early and pay half.", {"credits":40,"hull":-9}),
   BOTCHED=("The head finds a seam. Somebody says a word and somebody else hits the cutoff, and afterwards everyone is very quiet and very apologetic.", {"hull":-17}))),
  dict(label="Sell them the plate instead", flat="You have salvage aboard that will take a cut as well as your hull will and cost you nothing when it does not survive.", gain={"exotic":-1,"credits":45}),
  dict(label="Decline", decline=True, flat="They take it well. Somebody out here will say yes to this before the week is out.")])

opt(id="quarantine_flag", label="Quarantine flag", tags="signal", group=None, weight=7,
 gate="regions: TERRITORY, COSMOPOLITAN · min_security 3",
 teaser="A station under a flag that may not be real.",
 full="Calyx put a biological flag on this station eight days ago and nobody has been in or out since. The flag is real in the sense that it was properly filed. Whether there is anything behind it is a different question, and the two ships already sitting off it at a polite distance are asking it too.\n\nInside is a full station's worth of stock that nobody is currently allowed to buy.",
 choices=[
  dict(label="Read the flag", check=("sensors",5), bands=dict(
   MET=("The filing is eight days old, the atmosphere reads clean, and the hull temperature says nobody has run a decontamination cycle in any of it. There is no outbreak. There is a stock dispute wearing one.", {"credits":75,"module":1}),
   CLEAN=("Nothing on your instruments supports the flag. Nothing disproves it either. You go in carefully and come out with cargo.", {"module":1}),
   PARTIAL=("You get a partial read, do not like it, and buy nothing you cannot inspect from outside.", {"credits":25}),
   BOTCHED=("You read it wrong in the reassuring direction, dock, and spend an afternoon in a decontamination cycle that costs more than the stock was worth.", {"credits":-50}))),
  dict(label="Wait it out with the others", decline=True, flat="Two ships are already doing this. In eight more days one of you will find out whether it was worth it.")])

opt(id="counterweight", label="Counterweight", tags="salvage", group=None, weight=7,
 gate="regions: COSMOPOLITAN, TERRITORY · min_development SETTLEMENT",
 teaser="A station module, still tumbling, still stocked.",
 full="Somebody detached a habitation ring from a station and never came back for it, and it has been tumbling end over end ever since — a slow, patient rotation, once every ninety seconds, with everything still bolted down inside.\n\nThe airlock comes past you once every ninety seconds. It is not moving fast. It is just never in the same place twice.",
 choices=[
  dict(label="Match the tumble", check=("maneuver",7), bands=dict(
   MET=("You match it, hold it, and walk aboard as though the floor had always been down. Somebody's whole life is still bolted to it.", {"module":1,"exotic":1,"credits":50}),
   CLEAN=("You match it well enough. Getting back off is worse than getting on.", {"module":1,"hull":-3}),
   PARTIAL=("You get one hand on it and the rotation takes the decision away from you.", {"credits":20,"hull":-7}),
   BOTCHED=("Ninety seconds is a long time to be wrong about which way something is going.", {"hull":-15}))),
  dict(label="Take the outside", flat="You do not try to board. You strip what is bolted to the exterior, on the pass, one piece at a time.", gain={"exotic":1,"credits":25}),
  dict(label="Leave it turning", decline=True, flat="Once every ninety seconds, with everything still where somebody left it.")])

opt(id="the_auction", label="The auction", tags="contract", group="berth2", weight=7,
 gate="regions: COSMOPOLITAN · needs_berth",
 teaser="A sealed lot, sold unseen, going cheap.",
 full="Probate are clearing an intestate hold and the terms are the terms: the lot is sealed, the manifest is sealed, and the buyer takes it as it lies. Two of the three previous lots went for less than the filing fee. The third went for considerably more than that and the man who bought it has not been seen since, in the good way.\n\nBidding closes in an hour and there are four of you.",
 choices=[
  dict(label="Bid on it", gate_credits=70, flat="Seventy credits and a seal broken in your own hold, forty minutes later, with nobody watching in case it is embarrassing.", gain={"credits":-70,"module":1,"exotic":1}),
  dict(label="Read the room instead", check=("sensors",4), bands=dict(
   MET=("You do not bid. You watch who does, and what the Probate clerk's face does when the third bidder names a number. Afterwards you know exactly which of the four lots next week is worth having.", {"credits":40}),
   CLEAN=("You learn something about two of the bidders that will be worth knowing later.", {"credits":20}),
   PARTIAL=("You learn that everyone here is better at this than you are.", {}),
   BOTCHED=("You misread a nod as a bid and win a lot you did not want, at a price you did not choose.", {"credits":-70,"exotic":1}))),
  dict(label="Let it go", decline=True, flat="Sealed, unseen, as it lies. Somebody else's forty minutes.")])

opt(id="escort", label="Escort", tags="fight", group=None, weight=10,
 gate="regions: LAWLESS · min_danger 3",
 teaser="A convoy paying for a gun for one shell.",
 full="Three haulers and a courier, none of them armed, all of them going the same way you are and none of them happy about it. They have been quoted a price by the only escort in the system and the price is most of what the run is worth.\n\nThey would rather pay you. They are not asking you to win anything — they are asking you to be visible, and to be visible with weapons.",
 choices=[
  dict(label="Take the contract", fight=True, flat="You ride the flank for one shell. Something comes out of the shadow of the third moon and decides the convoy looks softer than it is."),
  dict(label="Sell them the courier's slot", flat="The courier is fast enough to outrun anything out here alone. You tell them so, take a cut for the advice, and the convoy splits.", gain={"credits":50}),
  dict(label="Decline", decline=True, flat="They pay the other escort most of what the run is worth, and go, and you never learn how it ended.")])

opt(id="nine_tonnes", label="Nine tonnes of nothing", tags="contract", group=None, weight=8,
 gate="regions: LAWLESS, TERRITORY · max_security 3",
 teaser="A cargo whose manifest does not match its mass.",
 full="Somebody wants nine tonnes moved one shell inward and is paying above rate for it, which is the first thing. The second is that nine tonnes of what the manifest says would not need a hold this size, and the crate is warm.\n\nHe is very relaxed about you not asking. He is noticeably less relaxed about you opening it.",
 choices=[
  dict(label="Open it", check=("sensors",4), bands=dict(
   MET=("Reactor fuel, undeclared, in a casing rated for something duller. It is worth four times the freight and he knows it, which is why he renegotiates rather than argues.", {"credits":110}),
   CLEAN=("Not what the manifest says. Not dangerous either. You take the job at a better rate.", {"credits":65}),
   PARTIAL=("You get the casing open, learn nothing useful, and get it closed before he notices. The rate stays the rate.", {"credits":45}),
   BOTCHED=("He notices. The job evaporates and so does he, and the crate goes with him.", {}))),
  dict(label="Just take the job", flat="Nine tonnes, one shell inward, above rate, no questions. You have carried worse and asked less.", gain={"credits":45}),
  dict(label="Pass", decline=True, flat="He finds somebody else inside the hour. The crate is still warm when it leaves.")])

opt(id="ice", label="Ice", tags="claim", group=None, weight=8,
 gate="regions: FRONTIER, FAUNA · max_development OUTPOST",
 teaser="A cometary body, unclaimed, mostly volatiles.",
 full="A dirty snowball on a long ellipse, three kilometres of it, and nobody has ever bothered because there is nothing out here to sell it to. It is water and volatiles and a little metal, packed in a crust that has been hardening since the system was warm.\n\nCutting into it is honest work and slightly stupid work. The crust is under compression and it has opinions about being cut.",
 choices=[
  dict(label="Cut deep", check=("hull",4), bands=dict(
   MET=("You take the crust off in sheets and get at the clean ice under it. Volatiles, water, and enough metal in the tail to be worth the trip.", {"fuel":24,"credits":35}),
   CLEAN=("The crust goes where you did not want it to. You get most of what you came for and wear the rest.", {"fuel":18,"hull":-3}),
   PARTIAL=("The face calves while you are on it. You back off with a partial hold and a story.", {"fuel":10,"hull":-6}),
   BOTCHED=("Three kilometres of compressed ice releases about eleven seconds of stored temper directly into your bow.", {"hull":-14}))),
  dict(label="Skim the tail", flat="You do not touch the body. You run the tail and collect what it is already shedding, which is slower and entirely safe.", gain={"fuel":9}),
  dict(label="Leave it", decline=True, flat="A long ellipse, a hard crust, and nobody out here to sell water to. It will be back around in ninety years.")])

opt(id="the_runner", label="The runner", tags="signal", group=None, weight=7,
 gate="regions: LAWLESS · max_security 2",
 teaser="A package, one shell inward, no questions and no manifest.",
 full="She is nineteen at the outside and she is running somebody else's errand with somebody else's ship, and the thing she needs moved fits in one hand. No manifest, no filing, no name on it.\n\nShe cannot pay much now. She says the man it goes to pays properly and pays on delivery, and she says it like somebody repeating a thing she was told rather than a thing she knows.",
 places="paid_in_full",
 choices=[
  dict(label="Take it quietly", check=("stealth",5), bands=dict(
   MET=("It goes in a void behind the coolant run that nothing scans and nobody knows about. She watches you do it and does not ask what else is in there.", {"credits":20}, "paid_in_full"),
   CLEAN=("You find somewhere for it that will hold up to an ordinary look.", {"credits":20}, "paid_in_full"),
   PARTIAL=("You stow it badly and spend the next shell aware of exactly where it is.", {"credits":20}, "paid_in_full"),
   BOTCHED=("You are still finding somewhere for it when a patrol runs a courtesy sweep of the dock. Nothing comes of it. She sees the sweep and takes it back.", {}))),
  dict(label="Ask what it is", flat="She tells you, or tells you something. Either way she takes it somewhere else, politely, and you do not see her again.", gain={}),
  dict(label="Decline", decline=True, flat="She nods like she expected it and goes to ask the next ship along the rank.")])

opt(id="paid_in_full", label="Paid in full", tags="signal", group=None, weight=0, placed=True,
 gate="placed by `the_runner` only · never rolled from the pool",
 teaser="Somebody here has been waiting for a package.",
 full="He is old, and he is not what you were expecting, and he has been waiting at this berth for eleven days for a thing that fits in one hand.\n\nHe does not open it in front of you. He pays what she said he would pay, which is considerably more than she was in a position to promise, and then he asks — carefully, as though the answer matters — whether she looked well.",
 choices=[
  dict(label="Take the money", flat="He pays in full, in cash, and thanks you in a register nobody has used on you in a while.", gain={"credits":150}),
  dict(label="Tell him she looked tired", flat="He nods for a while. Then he pays you more than the agreed figure, and gives you a name at a yard two shells in who will fit you something at cost.", gain={"credits":190,"module":1})])

opt(id="the_memorial", label="The memorial", tags="signal", group=None, weight=6,
 gate="regions: any",
 teaser="A marked site, and a beacon nobody maintains.",
 full="Four hundred and six people, a hull breach, and a marker put here afterwards by an office that no longer exists. The beacon still runs on a decay cell that has about a year in it.\n\nThe names are on the marker. The cell is standard and you are carrying two.",
 choices=[
  dict(label="Replace the cell", flat="Twenty minutes and one cell out of your own stores. Another eleven years of a beacon nobody will hear, saying four hundred and six names to nobody at all.", gain={"credits":-10}, archive=True),
  dict(label="Log the names", flat="You copy the marker to your own archive, which is not the same as maintaining it, and is not nothing.", gain={}, archive=True),
  dict(label="Hold station a moment", decline=True, flat="You do not do anything. You are just there for a bit, and then you are not.")])

opt(id="flare_shelter", label="Flare shelter", tags="signal", group=None, weight=8,
 gate="regions: FRONTIER, TERRITORY · min_danger 2",
 teaser="A flare inbound, and a rock to put between you and it.",
 full="The star is going to do something in about forty minutes and the instruments are confident about it. There is a rock two minutes away, big enough to shadow you, and on the far side of the rock is a survey drone that has evidently been using it the same way for years.\n\nForty minutes is enough to reach the rock. It is enough to strip the drone. It is not enough to be leisurely about either.",
 choices=[
  dict(label="Shelter and strip", check=("thermal",6), bands=dict(
   MET=("You take the shadow, take the drone apart in the dark, and come out the other side of the flare with a hold and a cold reactor.", {"module":1,"credits":40}),
   CLEAN=("You get most of it done before the shadow starts to move and finish the rest in the light.", {"module":1,"heat":8}),
   PARTIAL=("You get the drone open and the flare arrives while you are inside the housing.", {"heat":17}),
   BOTCHED=("You misread the rock's rotation and spend the peak of it on the lit side.", {"heat":25}))),
  dict(label="Just shelter", flat="You put the rock between you and the star and wait it out doing nothing at all, which is the correct answer and a dull one.", gain={}),
  dict(label="Outrun it", flat="You leave before it peaks. It costs a burn you had not budgeted for and you never find out what was on the drone.", gain={"fuel":-16})])

opt(id="deadfall", label="Deadfall", tags="salvage", group=None, weight=8,
 gate="regions: LAWLESS, TERRITORY · min_danger 3",
 teaser="A collapsed gantry field, and something under it.",
 full="An orbital yard came down on itself — not explosively, just structurally, over about a decade of nobody paying for maintenance. What is left is nine hundred metres of gantry lying across itself at every angle, still under tension in places, still letting go of a piece now and then.\n\nUnder the middle of it is a fitting bay, and fitting bays are where the good parts are when the lights go out.",
 choices=[
  dict(label="Go under it", check=("maneuver",6), bands=dict(
   MET=("You pick a line through nine hundred metres of dead scaffolding and nothing so much as brushes you. The bay is exactly as it was left.", {"module":1,"exotic":1}),
   CLEAN=("You get in, get the bay open, and take a glancing hit from something that let go behind you.", {"module":1,"hull":-4}),
   PARTIAL=("Two hundred metres in, a span shifts across your line and you reverse out past a bay you can see and cannot reach.", {"hull":-8}),
   BOTCHED=("The thing about tension is that it is patient right up until it is not.", {"hull":-16}))),
  dict(label="Work the outside", flat="The perimeter of the field is safe enough and picked over enough. You take what the last four crews did not think was worth the lift.", gain={"exotic":1,"credits":20}),
  dict(label="Leave it lying", decline=True, flat="Nine hundred metres of somebody's deferred maintenance. It will finish coming down eventually, on its own.")])

opt(id="the_long_tow", label="The long tow", tags="contract", group=None, weight=8,
 gate="regions: TERRITORY, COSMOPOLITAN · needs_berth",
 teaser="A dead ship, a live crew, and nowhere near enough engine.",
 full="Her reactor is scrap and her crew are fine, which is the wrong way round for how these usually go. Six people, no power, and a station one shell in that will take them if they can get there.\n\nA tow is four hours of your engine at a load it was not built for, and a hull hanging off your stern the whole way that does not steer.",
 places="what_she_was_carrying",
 choices=[
  dict(label="Take the tow", check=("thrust",6), bands=dict(
   MET=("Four hours, one heading, no drama. The station takes them and the yard master watches you come in with somebody else's ship on the line.", {"credits":90}, "what_she_was_carrying"),
   CLEAN=("Five hours and a stern mount you will want looked at. They get there.", {"credits":75,"hull":-3}, "what_she_was_carrying"),
   PARTIAL=("You get her most of the way before the load tells you it is done. A yard tug comes out for the last of it and takes most of the fee.", {"credits":25}),
   BOTCHED=("The line parts under load. Nobody is hurt and nothing is lost except four hours, a tow line, and a certain amount of dignity.", {"fuel":-18}))),
  dict(label="Sell them a reactor start", flat="You have enough aboard to bootstrap her if they are not fussy about the state you leave your own stores in. They are not fussy.", gain={"exotic":-1,"credits":70}),
  dict(label="Signal it in and go", decline=True, flat="You put their position on the emergency band and leave. Somebody will come. Somebody usually comes.")])

opt(id="what_she_was_carrying", label="What she was carrying", tags="signal", group=None, weight=0, placed=True,
 gate="placed by `the_long_tow` only · never rolled from the pool",
 teaser="The ship you towed is here, and running again.",
 full="She has a new reactor and an old name and the same six people, and one of them recognises your hull before you have finished docking.\n\nThey never did tell you what was in the hold, because the tow was the thing that mattered and nobody asks a tug. They are telling you now.",
 choices=[
  dict(label="Take the share", flat="A fifth of what they were carrying, which they have already sold, in cash, without being asked twice.", gain={"credits":160}),
  dict(label="Take the favour instead", flat="You tell them to keep it. Their engineer spends an afternoon in your machine spaces instead, and does not itemise what she does in there.", gain={"module":1,"hull":8})])
