# Prose: the mannered-prose pass (2026-10-23)

*The log of one pass over every player-facing string, made with the Meridian
manuscript's style sheet (§9.13 "Banished constructions", §9.18 "Mannered
prose") as the reference. Every change is here with its original, its
replacement and the rule it was made under, for Jon to rule on. Nothing in it
changes what an outcome does; a line that paid, hurt, placed or took still
does, and every name and number stays. The rules themselves are in
`tools/prose_tells.py` and described in the encounter-prose skill, §3d.*

## What was measured

The plain-voice overhaul of 2026-10-13 took the slang and the epigrams out and
brought the table to grade 3.3 against a ceiling of 7. What it left was the
same moves in plain words. Over the 1,233 encounter strings (36,800 words):

| | encounters, before | a shelf of sixteen novels |
|---|---|---|
| "still" per 10k words | 49 | 10 |
| nobody / no one / nothing / none per 10k | 56 | about 15 |
| strings ending on "X is still Y when you leave" | 49 | |
| "a long time", "long ago", "a long while" | 43 | |
| sentences of three words or fewer, per 10k | 12 | 13 to 74 |

So the staccato the grade cap might have produced is not there: the table is
not chopped. What is there is one closer, repeated, and the machines given
feelings. After the pass "still" runs 39 per 10k; the remaining uses are the
plain adverb ("the tanks are still full"), which is right.

## What was left alone, for Jon

- The manufacturer taglines in `Database.gd` ("Everything is salvage. Even
  you.", "The line between reactor and weapon is philosophy.", "Still flying?
  Then we did our job."). They are the epigram §0 vetoed, but they are company
  mottos and the lore gives each manufacturer one line in its own register.
- The contract postings in `Contracts.gd`, each in its manufacturer's voice
  ("That offends me personally. Fetch it.").
- A.S.H.'s lines. Her voice is dry and teasing by design (`docs/ash.md`).
- The material catalogue's wry pairs ("Owning them is legal, but reading them
  is not."; "Scrubbing it off is illegal, and leaving it on is worse."). They
  read as facts about the item. Two that did not were changed, below.
- Two closers the rule still flags, kept and baselined because the fact is the
  point: "It is out of range in an hour, still running hot on one drive." and
  the storm's "by the time they call again, you are out of range."

## The changes

### The lingering camera (43)

- `OptionTable.gd`
  - was: You leave the two crews to sort out the pod. Their argument is still on the open channel long after the pod is out of range.
  - now: You leave the two crews to argue over the pod on the open channel.
- `OptionTable.gd`
  - was: You leave the refinery running, still cracking a seam that stopped paying and stacking a yard no one empties.
  - now: You leave the refinery running and the yard full.
- `OptionTable.gd`
  - was: You cut the racks out while the handshake keeps pinging every ninety seconds. It is still pinging when you leave.
  - now: You cut the racks out while the handshake goes on pinging every ninety seconds.
- `OptionTable.gd`
  - was: You let it tumble on. Its transponder is still going, weaker, when it leaves sensor range.
  - now: You let it tumble on with its transponder fading.
- `OptionTable.gd`
  - was: It is still up when you let go, but it will not last the year.
  - now: When you let go it stays up, but it will not last the year.
- `OptionTable.gd`
  - was: You tell him no, and he takes it well. He is still holding there when you leave, waiting for the next ship.
  - now: You tell him no, and he takes it well. He waits for the next ship.
- `OptionTable.gd`
  - was: You leave with four more units in the tank. The rate card is still repeating on the channel behind you.
  - now: You leave with four more units in the tank.
- `OptionTable.gd`
  - was: You leave the ring on the tank you came in with. The rate card repeats on the channel until you are out of range.
  - now: You leave the ring on the tank you came in with.
- `OptionTable.gd`
  - was: Nobody follows. The eleven containers are somewhere in the ring, and the haulers are still stopping ships.
  - now: Nobody follows. The haulers go back to stopping ships, and the eleven containers are somewhere in the ring.
- `OptionTable.gd`
  - was: The grapple takes a sealed unit out of one rack and a crate out of another. Both ships are still holding station on the light when you leave.
  - now: The grapple takes a sealed unit out of one rack and a crate out of another. Neither ship moves off the light.
- `OptionTable.gd`
  - was: You log the false code and the bearing it sits on. You go around wide of both. The light is still running when your dish loses the rock, and neither ship has moved.
  - now: You log the false code and the bearing it sits on. You go around wide of both ships and the light.
- `OptionTable.gd`
  - was: Then they turn back to the search. They are still on the open channel when your dish loses them.
  - now: Then they turn back to the search.
- `OptionTable.gd`
  - was: The ship lights its drives while the payment is still clearing. The crossing is empty behind it.
  - now: The ship lights its drives while the payment is still clearing, and leaves the crossing.
- `OptionTable.gd`
  - was: The loop follows you on the open channel for an hour. It is one line, over and over, and then the range takes it. The ship does not move off its station.
  - now: The loop follows you on the open channel for an hour, until you are out of range. The ship does not move.
- `OptionTable.gd`
  - was: Two hours of that gets you four units off four tanks and out the far side. The challenge is still going out every ninety seconds behind you.
  - now: Two hours of that gets you four units off four tanks and out the far side.
- `OptionTable.gd`
  - was: You pull four units and you are past them and burning. The ninth ship is still saying so on the channel.
  - now: You pull four units and you are past them and burning.
- `OptionTable.gd`
  - was: The clamp sits open behind you with its motor still dead.
  - now: The clamp sits open behind you with its motor dead.
- `OptionTable.gd`
  - was: The traffic office says a tug is an hour out and already tasked. She is still talking to them when you lose the channel.
  - now: The traffic office says a tug is an hour out and already tasked. You leave her talking to them.
- `OptionTable.gd`
  - was: It reads clean on your own bus an hour later. It is still reading clean at the end of the day.
  - now: It reads clean on your own bus an hour later, and again at the end of the day.
- `OptionTable.gd`
  - was: You send her the last three times you saw a patrol on this ring. You send nothing else and fly your own crossing. She is still at the edge of the system when you lose her off the dish. She is doing the arithmetic on a schedule with three entries in it.
  - now: You send her the last three times you saw a patrol on this ring, and nothing else. Then you fly your own crossing. She stays at the edge of the system, working out a crossing from three patrol times.
- `OptionTable.gd`
  - was: The log stops somewhere in the second cut. The frame is still out there, bare, pointed at the drift.
  - now: The log stops somewhere in the second cut, and the bare frame stays on its mount.
- `OptionTable.gd`
  - was: You put the dish on the plate and read off all eleven numbers. The date under them goes in the log too. The rock turns the plate out of sight. It brings it back around.
  - now: You put the dish on the plate and read off all eleven numbers. The date under them goes in the log too.
- `OptionTable.gd`
  - was: Nobody is sore about it. The freighter is still open when you leave.
  - now: Nobody is sore about it. The plate is not back on when you leave.
- `OptionTable.gd`
  - was: One rack comes off clean. The stern is still rolling when you stow the cutter.
  - now: One rack comes off clean.
- `OptionTable.gd`
  - was: The other crew is on the stern before your second pass is done. They are still there when you go.
  - now: The other crew is on the stern before your second pass is done.
- `OptionTable.gd`
  - was: You log the bearing and go. Their cutter is bigger and their crew is rested. The hauler will be just as dead in four hours. They will still be cutting it then.
  - now: You log the bearing and go. Their cutter is bigger and their crew is rested, and the hauler will be just as dead in four hours.
- `OptionTable.gd`
  - was: She is still on the channel asking when you pass out of range.
  - now: You leave her asking on the channel.
- `OptionTable.gd`
  - was: He is still on the channel two hours later. He is offering the same rate to a different set of ships. The tank sits where it was filled. The window closes whether anybody answers him or not.
  - now: Two hours later he is offering the same rate to a different set of ships. The tank sits where it was filled, and the window closes on it.
- `OptionTable.gd`
  - was: She is still listing the fittings on the channel when you pass out of range. The yard is in no hurry. The clamps are rented by the day, and the day is already paid for.
  - now: You leave her listing the fittings on the channel. The yard is in no hurry: the clamps are rented by the day, and the day is paid for.
- `OptionTable.gd`
  - was: You break off. The outfit stops answering. The crate is still on the rack when you leave.
  - now: You break off. The outfit stops answering, and the crate stays on the rack.
- `OptionTable.gd`
  - was: The crate sits on the rack. The hold is still against it.
  - now: The crate sits on the rack with the hold against it.
- `OptionTable.gd`
  - was: They are still alongside it when your dish loses them. The tender rolls at the rate it has rolled for four days. The dock at the far end is not expecting anybody early.
  - now: They are still alongside it when your dish loses them. The tender rolls as it has for four days.
- `OptionTable.gd`
  - was: The next canister goes out eleven minutes after you do. It takes the same line as all the rest. The station at the far end of that line stopped answering years ago.
  - now: The next canister goes out eleven minutes after you do, on the same line as the rest.
- `OptionTable.gd`
  - was: You log the bearing and go on. The beacon puts the order out again on the hour. The strength is the same. The address it names has not been there for a long time.
  - now: You log the bearing and go on. The beacon puts the order out again on the hour, at the same strength. The address it names has not been there for years.
- `OptionTable.gd`
  - was: An hour later the five of them are still in a line. They are still slow and still pointed out. The carrier is still setting the speed.
  - now: An hour later the five of them are in a line behind the carrier, slow and pointed out.
- `OptionTable.gd`
  - was: You read the labels off the near row and go. The rows are still clamped to the rock when the dish loses them. They sit in the order somebody set them down in twenty-two years ago.
  - now: You read the labels off the near row and go. The rows sit clamped to the rock in the order somebody set them down twenty-two years ago.
- `OptionTable.gd`
  - was: You log the barge's position and the calf beside it, and fly on. The calf has stopped pulling. It is still caught in the cable.
  - now: You log the barge's position and the calf beside it, and fly on. The calf is caught in the cable and has stopped pulling.
- `OptionTable.gd`
  - was: You stay off the channel and fly on. The last you read of them, the leviathan is still towing the hunting ship away from the star.
  - now: You stay off the channel and fly on, and the leviathan tows the hunting ship away from the star.
- `OptionTable.gd`
  - was: You go around the yard and leave the cradle to its arms. It closes on nothing, and opens, and closes again. The yard behind it is dark on every band.
  - now: You go around the yard and leave the cradle to its cycle. The yard behind it is dark on every band.
- `OptionTable.gd`
  - was: They take the answer and do not argue about it. They go back to the open channel. Somebody will come through this system in a day or two with empty panels. The reactor stays down until then. The two of them sit in a hull going as cold as the sky around it.
  - now: They take the answer and do not argue about it. They go back to the open channel. Somebody will come through this system in a day or two with empty panels. The reactor stays down until then, and the two of them sit in a hull with no heat in it.
- `OptionTable.gd`
  - was: You leave the wreck to them. Their floods follow you out of sensor range.
  - now: You leave the wreck to them. Their floods follow you out.
- `OptionTable.gd`
  - was: The two small ships hold their station between you and the hull. They stay there until you are well out of range.
  - now: The two small ships hold their station between you and the hull as you go.
- `OptionTable.gd`
  - was: The loop is still down when you pull away.
  - now: You pull away with their loop down.

### The pronouncement closer (11)

- `OptionTable.gd`
  - was: The cutter lets traffic through. It is here to guard the cargo.
  - now: The cutter is here to guard the cargo, and it lets traffic through.
- `OptionTable.gd`
  - was: You leave the body alone and run the tail instead, taking what it is already shedding. It is slow and safe.
  - now: You leave the body alone and run the tail instead, taking what it is already shedding. That takes longer and cracks nothing.
- `OptionTable.gd`
  - was: You have one container off the tether when the other ship's lights show. You go fast, with the one you have. It is not the good one.
  - now: You have one container off the tether when the other ship's lights show. You go fast, with the one you have. It holds supplies.
- `OptionTable.gd`
  - was: Nothing here moves fast enough to have wrecked it. It just stopped.
  - now: Nothing here moves fast enough to have wrecked it. It stopped for some other reason.
- `OptionTable.gd`
  - was: For a very long time, people have left crates, tanks and sealed cargo there for others, stacked and tethered. The beam is the only guard.
  - now: For a very long time, people have left crates, tanks and sealed cargo there for others. It is stacked and tethered, with the beam as its only guard.
- `OptionTable.gd`
  - was: It brings eighteen months of messages and then stops. That is enough.
  - now: It brings eighteen months of messages and then stops. That is enough to tell them what happened.
- `OptionTable.gd`
  - was: He pays for the pass at the rate the quote allows. It is the only rate he has.
  - now: He pays for the pass at the only rate he has, the one the quote allows.
- `OptionTable.gd`
  - was: Below a certain draw rate it writes nothing at all. It was built to ignore a leak.
  - now: Below a certain draw rate it writes nothing at all, because it was built to ignore a leak.
- `OptionTable.gd`
  - was: He pays what he has, which is more than you expected.
  - now: He pays you everything he has, more than you expected.
- `OptionTable.gd`
  - was: The voice says one thing about the core, and it is gone.
  - now: The voice says one thing about the core before the ship is gone.
- `OptionTable.gd`
  - was: At the end of it they thank you, and pay, and go on, and you turn around.
  - now: At the end of it they thank you and pay, and go on. You turn around.

### The personified machine (14)

- `OptionTable.gd`
  - was: You hold off and take nothing. The hull keeps its fittings.
  - now: You hold off and take nothing. The fittings stay on the hull.
- `OptionTable.gd`
  - was: You stay too long and get nothing. The wreck keeps its fittings, and you leave with damaged plating.
  - now: You stay too long and get nothing. The fittings stay on the wreck, and you leave with damaged plating.
- `OptionTable.gd`
  - was: You fly the rota line at the speed the arm wants. It takes you like it was expecting you.
  - now: You fly the rota line at the speed the arm wants, and it takes you on the first pass.
- `OptionTable.gd`
  - was: It folds on the hour it was built to fold. It closes on your flank and does not notice the difference.
  - now: It folds on schedule and closes on your flank.
- `OptionTable.gd`
  - was: You put your line through the middle of the arc. It does the one thing it was left here to do. You come out of the approach with nothing off the tanks.
  - now: You put your line through the middle of the arc, and it fires. You come out of the approach with nothing off the tanks.
- `OptionTable.gd`
  - was: Your frame carries forty tonnes of somebody else's cargo for twenty minutes. Nothing on the board complains.
  - now: Your frame carries forty tonnes of somebody else's cargo for twenty minutes. Nothing on the board goes out of limits.
- `OptionTable.gd`
  - was: You hold the low end for twenty minutes and the frame complains twice.
  - now: You hold the low end for twenty minutes and the board flags the frame twice.
- `OptionTable.gd`
  - was: You come out with one unit off the racks, which the cradle decided you were short of.
  - now: You come out with one unit off the racks, the one the cradle chose for you.
- `OptionTable.gd`
  - was: You trim the whole time to keep clear of the cycle. The arms do not care where you are.
  - now: You trim the whole time to keep clear of the cycle, because the arms close whether you are there or not.
- `OptionTable.gd`
  - was: You take the one good piece that drops. Flying that slow for a day costs fuel. The herd does not mind you there.
  - now: You take the one good piece that drops. Flying that slow for a day costs fuel. None of them turns toward you.
- `OptionTable.gd`
  - was: Your own plating reports numbers the board records and does not explain.
  - now: Your own plating reports numbers the board records and does not flag.
- `OptionTable.gd`
  - was: You sit in against the spin for two hours. The face throws what it throws.
  - now: You sit in against the spin for two hours while the face throws off debris.
- `OptionTable.gd`
  - was: You are coupled before either of them has finished coming about. The pumps do not ask who you are.
  - now: You are coupled before either of them has finished coming about, and the pumps run for anyone.
- `OptionTable.gd`
  - was: You lose the roll twice and find it again. The grapple never does anything it cannot undo.
  - now: You lose the roll twice and find it again. You keep the grapple to moves you can undo.

### The wink (13)

- `OptionTable.gd`
  - was: The larger one hails to say the wreck is claimed. It is not. They say they are happy to wait, and they are not.
  - now: The larger one hails to say the wreck is claimed, but no claim is filed. They say they are happy to wait, and they are lying.
- `OptionTable.gd`
  - was: You get a poor spot at the edge, half in the light, and hold it. It is uncomfortable and it is free.
  - now: You get a poor spot at the edge, half in the light, and hold it. It costs nothing.
- `OptionTable.gd`
  - was: The module is sound. The repair is worth arguing about, and you argue about it.
  - now: The module is sound, but you argue the price down over the repair.
- `OptionTable.gd`
  - was: They look you over and decide against whatever they were deciding.
  - now: They look you over for a while and do not attack.
- `OptionTable.gd`
  - was: What her instruments get is close enough to six years of waiting. Nothing is said after that.
  - now: What her instruments get is close enough for someone who has waited six years. She says nothing more.
- `OptionTable.gd`
  - was: Nothing changes. No heat, no drift, no light.
  - now: Nothing changes: no heat, no drift and no light.
- `Database.gd`
  - was: Rated for the pressure. The crew was not.
  - now: Fires over its rated pressure. It hits twice and runs hot.
- `Database.gd`
  - was: It breathes for the furnace. Mind your hands.
  - now: A pump that feeds the furnace. It draws cards and makes heat.
- `Database.gd`
  - was: The air bends, and their gunners guess.
  - now: Heats the air around the hull until their gunners miss.
- `Database.gd`
  - was: The floor calls it the heart. It is a reactor.
  - now: A reactor that turns your heat into brace and hits back.
- `Database.gd`
  - was: Every other yard points these at the dark.
  - now: A radiator pointed at the enemy. It hits for your heat and sheds it.
- `MaterialTable.gd`
  - was: Fake Korvan delivery seals that pass for real. Korvan says that makes them real, and Korvan's property.
  - now: Fake Korvan delivery seals that pass for real. Korvan treats any seal that passes as its own property.
- `MaterialTable.gd`
  - was: The bar every scale in three shells is set by. Whoever holds it decides what weight is, until someone takes it.
  - now: The bar every scale in three shells is set by. Whoever holds it sets the weights for all three.

### Vague "thing" (12)

- `OptionTable.gd`
  - was: It is other crews' paperwork about the thing at the core.
  - now: It is other crews' paperwork about whatever is at the core.
- `OptionTable.gd`
  - was: On the way out you take the best thing you were parked next to.
  - now: On the way out you take the best of what you were parked next to.
- `OptionTable.gd`
  - was: Every panel of plating is dented, and the grapple brings up the one thing it could reach.
  - now: Every panel of plating is dented, and the grapple brings up the one piece it could reach.
- `OptionTable.gd`
  - was: You take the first thing the grapple can reach off the nearest hull.
  - now: You take the first piece the grapple can reach off the nearest hull.
- `OptionTable.gd`
  - was: It is the heaviest thing you have ever towed.
  - now: It is heavier than anything you have towed before.
- `OptionTable.gd`
  - was: You take the best thing out of the nearest three holds.
  - now: You take the best of what is in the nearest three holds.
- `OptionTable.gd`
  - was: The filing is the first thing they put on the channel.
  - now: They put the filing on the channel before anything else.
- `OptionTable.gd`
  - was: A drive signature is the one thing on a ship that cannot be repainted.
  - now: A drive signature is the one part of a ship that cannot be repainted.
- `OptionTable.gd`
  - was: Inside the firing arc of a thing no one can call off.
  - now: Inside the firing arc of a guard no one can call off.
- `OptionTable.gd`
  - was: Crossed the firing arc of a thing left on station with old orders.
  - now: Crossed the firing arc of a guard left on station with old orders.
- `OptionTable.gd`
  - was: Your radiators are the hottest thing for a long way in any direction.
  - now: Your radiators are hotter than anything else for a long way in any direction.
- `OptionTable.gd`
  - was: Your drive is the warmest thing it has found out here.
  - now: Your drive is warmer than anything else it has found out here.

### Idiom stand-ins (6)

- `OptionTable.gd`
  - was: Afterwards you know which lot next week is worth having, and you sell that.
  - now: Afterwards you know which lot next week is worth bidding on, and you sell that.
- `OptionTable.gd`
  - was: You get the casing open, find nothing worth knowing, and shut it before he notices.
  - now: You get the casing open, find nothing you can use, and shut it before he notices.
- `OptionTable.gd`
  - was: Their one shot misses, and the lane costs you nothing.
  - now: Their one shot misses, and you get through the lane without paying.
- `OptionTable.gd`
  - was: It does not follow. Of the six, one is worth having.
  - now: It does not follow. Of the six, one holds anything worth selling.
- `OptionTable.gd`
  - was: One piece holds little, but a hundred pieces together are worth having.
  - now: One piece holds little, but a hundred pieces together are worth collecting.
- `OptionTable.gd`
  - was: You hold station a full day to get the whole of it.
  - now: You hold station a full day to get all of it.

### Tautology (2)

- `OptionTable.gd`
  - was: At the end of it she agrees the digit is the digit.
  - now: At the end of it she agrees the hull number is not yours.
- `OptionTable.gd`
  - was: The order is the order they arrived in, and the log records it.
  - now: The line runs in the order they arrived, and the log records it.

### The bare flourish verb (1)

- `OptionTable.gd`
  - was: The loop runs low the whole time and the heat goes nowhere. It holds. You go on warm
  - now: The loop runs low the whole time and the heat goes nowhere, but the sleeve holds. You go on warm

### Vague spans (8)

- `OptionTable.gd`
  - was: In it are pieces of the frame that fell clear of the beam's line a long time ago.
  - now: In it are pieces of the frame that fell clear of the beam's line centuries ago.
- `OptionTable.gd`
  - was: A hull has sat in the wind of a blue hypergiant for a long time.
  - now: A hull has sat in the wind of a blue hypergiant for years.
- `OptionTable.gd`
  - was: Yours is the first arrival she has logged in a long while.
  - now: Yours is the first arrival she has logged in years.
- `OptionTable.gd`
  - was: They have relied on the rate card for a long time, and they are slow to respond.
  - now: They have relied on the rate card for years, and they are slow to respond.
- `OptionTable.gd`
  - was: A ship hails you. It stopped being a business a long time ago.
  - now: A ship hails you. It stopped being a business years ago.
- `OptionTable.gd`
  - was: The cold has gone through the paint. No ship has come to the arm in a long while.
  - now: The cold has gone through the paint. No ship has come to the arm in years.
- `OptionTable.gd`
  - was: The crew that should answer is gone, but the bay has kept asking for a long time.
  - now: The crew that should answer is gone, but the bay has kept asking for years.
- `OptionTable.gd`
  - was: No patrol has come this deep for a long while.
  - now: No patrol has come this deep in years.

### Choice labels (2)

- `OptionTable.gd`
  - was: Sit with her and copy the filing across
  - now: Stay and copy the filing across
- `OptionTable.gd`
  - was: Put it down and take the depot at leisure
  - now: Put it down and take the depot

