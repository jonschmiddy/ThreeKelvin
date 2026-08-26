# batch-03 — twenty options

*Written 2026-08-26, offline. Aimed at the gaps `batch-02-draft.md` left: Maneuver
and Thermal had one option each, LAWLESS and COSMOPOLITAN carry 78% of the galaxy,
and continuity had exactly one instance.*

**Every option here is written against `ENCOUNTER_FLOW.md` Ruling 9** — *an obstacle
guards a reward, never a door.* Walking away always costs something specific.

**Fuel figures are placeholders** pending S3/S3a.

---

## The braid

```
id       the_braid
tags     salvage
gate     regions: FAUNA, FRONTIER · needs_fauna
group    —
weight   7
```

*Row teaser:* Something large is moving through, and moving fast.

> Nine of them, in line, big enough that the dish reads them as terrain. They are running a migration lane they have been running since before anyone was out here to name it, and they are shedding a wake you could ride most of the way to the next shell.
>
> They are not hostile. They are also not paying attention, and the smallest of them is longer than your ship.
>

**Ride the wake** — *Maneuver 6*

- **MET** — You slot into the draught behind the third one and let it carry you. It never registers you were there. **+18 fuel**
- **CLEAN** — You hold the lane most of the way before the turbulence shrugs you out of it. **+11 fuel**
- **PARTIAL** — You misjudge the interval and spend the whole run fighting the wash instead of using it. **-8 fuel**
- **BOTCHED** — The fourth one changes its mind about the lane. You are close enough that the flank takes your dorsal plating with it. **-14 hull**

**Take what they shed** — *no check*

- You hold off the lane and collect what comes loose in the wake — plate, ice, a lifetime of accreted junk. **+1 exotic** · **+25 credits**

**Let them pass** — *decline*

- Nine of them, in line, going somewhere. You wait, and then they are not there any more. **nothing.**

---

## Refinery, still lit

```
id       refinery_still_lit
tags     salvage
gate     regions: TERRITORY, COSMOPOLITAN · min_development SETTLEMENT
group    refinery
weight   8
```

*Row teaser:* An automated refinery, running with nobody aboard.

> Cygnet built it, staffed it, and pulled the staff out four years ago when the seam under it stopped paying. Nobody told the refinery. It is still drawing on the seam, still cracking what it draws, and still stacking the output in a yard nobody has emptied since.
>
> The yard is four years deep. The cracking towers are at operating temperature and the operating temperature is not survivable, which is why the yard is still full.
>

**Go in for the yard** — *Thermal 5*

- **MET** — You work the yard in three passes with the vents wide and never once go amber. Four years of output, and you take what fits. **+2 exotic** · **+60 credits**
- **CLEAN** — Two passes, and you leave with a full hold and a reactor that will want a minute. **+1 exotic** · **+40 credits** · **+7 heat**
- **PARTIAL** — One pass. You come out with an armful and a cabin you cannot stand in. **+25 credits** · **+15 heat**
- **BOTCHED** — A tower cycles while you are alongside it. You leave with nothing but the temperature. **+24 heat**

**Shut it down first** — *no check*

- Six hours to talk the control stack into standing down, and it stands down apologetically. The yard is cool by the time you reach it and half of what you wanted has cooked in place. **+1 exotic** · **+30 credits**

**Leave it running** — *decline*

- It will keep cracking a seam that stopped paying, and stacking a yard nobody comes to. Nothing you do here changes the second part. **nothing.**

---

## The sweep

```
id       the_sweep
tags     salvage
gate     regions: any · min_danger 4
group    refinery
weight   6
```

*Row teaser:* A wreck inside a pulsar's sweep, and a gap between passes.

> The beam comes round every eleven seconds and it has been sterilising this arc for longer than there has been anyone to sterilise. Sitting in it is a survey hull that got the interval wrong once.
>
> Eleven seconds is enough to get in. It is enough to get out. It is not obviously enough to do both and take anything with you.
>

**Time the interval** — *Thermal 7*

- **MET** — Three intervals, three passes, and you are clear before the fourth. Whatever killed them was not the arithmetic. **+1 module** · **+45 credits**
- **CLEAN** — Two intervals. You take the rack you came for and eat most of the third pass getting clear. **+1 module** · **+9 heat**
- **PARTIAL** — You get inside, get turned around, and spend the gap finding the way back out. **+18 heat**
- **BOTCHED** — You are still alongside when it comes round. The hull holds. Everything on the hull does not. **+26 heat**

**Log the bearing** — *decline*

- You mark the wreck, note the interval, and leave both for somebody with better vents and worse judgement. **nothing.**

---

## Tug work

```
id       tug_work
tags     contract
gate     regions: COSMOPOLITAN, TERRITORY · needs_berth · min_development CITY
group    —
weight   9
```

*Row teaser:* A hauler wants a push and the yard tugs are all busy.

> A bulk hauler has lost attitude control in a berth queue nine ships long, and the yard's own tugs are all committed for the next eleven hours. Every hour she sits there is an hour nine other ships are not moving, and the berth office is beginning to take an interest in whose fault that is.
>
> She needs about four minutes of somebody else's engine and a pilot willing to put their nose against a hull forty times their mass.
>

**Put your nose on her** — *Thrust 5*

- **MET** — Four minutes, one contact point, no scoring on either hull. The queue moves and somebody in the office writes down which ship did it. **+70 credits**
- **CLEAN** — Six minutes and a stripe down your flank that will polish out. The queue moves. **+55 credits**
- **PARTIAL** — You get her turned but not clear, and the yard tug that finally arrives gets paid the difference. **+20 credits**
- **BOTCHED** — You put twelve tonnes of thrust into a hull that was not braced for it and both of you learn something. **-8 hull**

**Sell her the fuel instead** — *no check*

- She cannot manoeuvre but she can burn. You sell her enough to get clear under her own power, at a rate she is in no position to argue with. **-20 fuel** · **+85 credits**

**Wait in the queue** — *decline*

- Eleven hours. You are not going anywhere in particular, and neither is anyone else. **nothing.**

---

## Silt

```
id       silt
tags     salvage
gate     regions: FAUNA, FRONTIER
group    —
weight   7
```

*Row teaser:* A dust shoal, and something inside it that is not dust.

> A shoal of fines and ice-grit, dense enough that the dish loses the far side of it. It has been accreting here for a long time and it collects whatever comes through — which is how you can see one hard return in the middle of it, ship-sized, that has not moved in a while.
>
> Going in means going in blind. The grit is slow and soft and there is a very great deal of it.
>

**Feel your way in** — *Maneuver 5*

- **MET** — You go in on attitude jets and touch nothing on the way. It is a survey cutter, intact, and nobody has been here first. **+1 module** · **+40 credits**
- **CLEAN** — You clip something soft on the way in and it does not matter. The cutter's racks come away clean. **+1 module**
- **PARTIAL** — You find her, get one panel open, and lose your bearings badly enough that leaving becomes the priority. **+30 credits**
- **BOTCHED** — Something in the shoal is harder than the rest of it and you find that out with your bow. **-13 hull**

**Sweep the edge** — *no check*

- You work the outside of the shoal where the grit is thin, and take what it has collected there. Nothing dramatic. Enough to matter. **+1 exotic** · **+20 credits**

**Go round** — *decline*

- It is a very large amount of dust and it is in no hurry. **nothing.**

---

## The queue

```
id       the_queue
tags     contract
gate     regions: COSMOPOLITAN · needs_berth · min_development CITY
group    berth2
weight   8
```

*Row teaser:* A berth slot, held by somebody who no longer needs it.

> Nine ships deep and the office is honest about it: the queue is the queue. But the fourth ship in it has been fourth for two days because her charter fell through, and she is holding a slot she cannot use and cannot sell back.
>
> She can sell it sideways. The office does not mind who docks as long as somebody does.
>

**Buy her slot** — *hard gate: 45 credits*

- Forty-five credits and a transfer that takes about a minute. You dock nine ships early and she gets something out of two wasted days. **-45 credits** · **+1 module**

**Trade her fuel for it** — *no check*

- She has no charter and no reason to sit here. You give her enough to leave and take the slot she was sitting on. **-25 fuel** · **+1 module**

**Wait your turn** — *decline*

- The queue is the queue. It moves, eventually, in the order it says it will. **nothing.**

---

## Cold labour

```
id       cold_labour
tags     contract
gate     regions: LAWLESS, TERRITORY · min_danger 2
group    —
weight   8
```

*Row teaser:* A breaker's crew wants to test a cutter on a live hull.

> Redline yard, or something wearing the colours. They have a new cutting head and no confidence in it, and they would rather learn what it does wrong on somebody else's plating than on the hull they are contracted to take apart next week.
>
> They are offering money to put your flank against it for an hour. They are very clear that they do not know what it will do.
>

**Give them the flank** — *Hull 5*

- **MET** — The head works exactly as advertised and your plating takes it without complaint. They pay, and they pay well, because now they know. **+95 credits**
- **CLEAN** — It bites deeper than the spec said. You come away paid and scored. **+80 credits** · **-4 hull**
- **PARTIAL** — It bites much deeper than the spec said, and they stop the test early and pay half. **+40 credits** · **-9 hull**
- **BOTCHED** — The head finds a seam. Somebody says a word and somebody else hits the cutoff, and afterwards everyone is very quiet and very apologetic. **-17 hull**

**Sell them the plate instead** — *no check*

- You have salvage aboard that will take a cut as well as your hull will and cost you nothing when it does not survive. **-1 exotic** · **+45 credits**

**Decline** — *decline*

- They take it well. Somebody out here will say yes to this before the week is out. **nothing.**

---

## Quarantine flag

```
id       quarantine_flag
tags     signal
gate     regions: TERRITORY, COSMOPOLITAN · min_security 3
group    —
weight   7
```

*Row teaser:* A station under a flag that may not be real.

> Calyx put a biological flag on this station eight days ago and nobody has been in or out since. The flag is real in the sense that it was properly filed. Whether there is anything behind it is a different question, and the two ships already sitting off it at a polite distance are asking it too.
>
> Inside is a full station's worth of stock that nobody is currently allowed to buy.
>

**Read the flag** — *Sensors 5*

- **MET** — The filing is eight days old, the atmosphere reads clean, and the hull temperature says nobody has run a decontamination cycle in any of it. There is no outbreak. There is a stock dispute wearing one. **+75 credits** · **+1 module**
- **CLEAN** — Nothing on your instruments supports the flag. Nothing disproves it either. You go in carefully and come out with cargo. **+1 module**
- **PARTIAL** — You get a partial read, do not like it, and buy nothing you cannot inspect from outside. **+25 credits**
- **BOTCHED** — You read it wrong in the reassuring direction, dock, and spend an afternoon in a decontamination cycle that costs more than the stock was worth. **-50 credits**

**Wait it out with the others** — *decline*

- Two ships are already doing this. In eight more days one of you will find out whether it was worth it. **nothing.**

---

## Counterweight

```
id       counterweight
tags     salvage
gate     regions: COSMOPOLITAN, TERRITORY · min_development SETTLEMENT
group    —
weight   7
```

*Row teaser:* A station module, still tumbling, still stocked.

> Somebody detached a habitation ring from a station and never came back for it, and it has been tumbling end over end ever since — a slow, patient rotation, once every ninety seconds, with everything still bolted down inside.
>
> The airlock comes past you once every ninety seconds. It is not moving fast. It is just never in the same place twice.
>

**Match the tumble** — *Maneuver 7*

- **MET** — You match it, hold it, and walk aboard as though the floor had always been down. Somebody's whole life is still bolted to it. **+1 module** · **+1 exotic** · **+50 credits**
- **CLEAN** — You match it well enough. Getting back off is worse than getting on. **+1 module** · **-3 hull**
- **PARTIAL** — You get one hand on it and the rotation takes the decision away from you. **+20 credits** · **-7 hull**
- **BOTCHED** — Ninety seconds is a long time to be wrong about which way something is going. **-15 hull**

**Take the outside** — *no check*

- You do not try to board. You strip what is bolted to the exterior, on the pass, one piece at a time. **+1 exotic** · **+25 credits**

**Leave it turning** — *decline*

- Once every ninety seconds, with everything still where somebody left it. **nothing.**

---

## The auction

```
id       the_auction
tags     contract
gate     regions: COSMOPOLITAN · needs_berth
group    berth2
weight   7
```

*Row teaser:* A sealed lot, sold unseen, going cheap.

> Probate are clearing an intestate hold and the terms are the terms: the lot is sealed, the manifest is sealed, and the buyer takes it as it lies. Two of the three previous lots went for less than the filing fee. The third went for considerably more than that and the man who bought it has not been seen since, in the good way.
>
> Bidding closes in an hour and there are four of you.
>

**Bid on it** — *hard gate: 70 credits*

- Seventy credits and a seal broken in your own hold, forty minutes later, with nobody watching in case it is embarrassing. **-70 credits** · **+1 module** · **+1 exotic**

**Read the room instead** — *Sensors 4*

- **MET** — You do not bid. You watch who does, and what the Probate clerk's face does when the third bidder names a number. Afterwards you know exactly which of the four lots next week is worth having. **+40 credits**
- **CLEAN** — You learn something about two of the bidders that will be worth knowing later. **+20 credits**
- **PARTIAL** — You learn that everyone here is better at this than you are. **nothing.**
- **BOTCHED** — You misread a nod as a bid and win a lot you did not want, at a price you did not choose. **-70 credits** · **+1 exotic**

**Let it go** — *decline*

- Sealed, unseen, as it lies. Somebody else's forty minutes. **nothing.**

---

## Escort

```
id       escort
tags     fight
gate     regions: LAWLESS · min_danger 3
group    —
weight   10
```

*Row teaser:* A convoy paying for a gun for one shell.

> Three haulers and a courier, none of them armed, all of them going the same way you are and none of them happy about it. They have been quoted a price by the only escort in the system and the price is most of what the run is worth.
>
> They would rather pay you. They are not asking you to win anything — they are asking you to be visible, and to be visible with weapons.
>

**Take the contract** — *fight*

- You ride the flank for one shell. Something comes out of the shadow of the third moon and decides the convoy looks softer than it is. **nothing.**

**Sell them the courier's slot** — *no check*

- The courier is fast enough to outrun anything out here alone. You tell them so, take a cut for the advice, and the convoy splits. **+50 credits**

**Decline** — *decline*

- They pay the other escort most of what the run is worth, and go, and you never learn how it ended. **nothing.**

---

## Nine tonnes of nothing

```
id       nine_tonnes
tags     contract
gate     regions: LAWLESS, TERRITORY · max_security 3
group    —
weight   8
```

*Row teaser:* A cargo whose manifest does not match its mass.

> Somebody wants nine tonnes moved one shell inward and is paying above rate for it, which is the first thing. The second is that nine tonnes of what the manifest says would not need a hold this size, and the crate is warm.
>
> He is very relaxed about you not asking. He is noticeably less relaxed about you opening it.
>

**Open it** — *Sensors 4*

- **MET** — Reactor fuel, undeclared, in a casing rated for something duller. It is worth four times the freight and he knows it, which is why he renegotiates rather than argues. **+110 credits**
- **CLEAN** — Not what the manifest says. Not dangerous either. You take the job at a better rate. **+65 credits**
- **PARTIAL** — You get the casing open, learn nothing useful, and get it closed before he notices. The rate stays the rate. **+45 credits**
- **BOTCHED** — He notices. The job evaporates and so does he, and the crate goes with him. **nothing.**

**Just take the job** — *no check*

- Nine tonnes, one shell inward, above rate, no questions. You have carried worse and asked less. **+45 credits**

**Pass** — *decline*

- He finds somebody else inside the hour. The crate is still warm when it leaves. **nothing.**

---

## Ice

```
id       ice
tags     claim
gate     regions: FRONTIER, FAUNA · max_development OUTPOST
group    —
weight   8
```

*Row teaser:* A cometary body, unclaimed, mostly volatiles.

> A dirty snowball on a long ellipse, three kilometres of it, and nobody has ever bothered because there is nothing out here to sell it to. It is water and volatiles and a little metal, packed in a crust that has been hardening since the system was warm.
>
> Cutting into it is honest work and slightly stupid work. The crust is under compression and it has opinions about being cut.
>

**Cut deep** — *Hull 4*

- **MET** — You take the crust off in sheets and get at the clean ice under it. Volatiles, water, and enough metal in the tail to be worth the trip. **+24 fuel** · **+35 credits**
- **CLEAN** — The crust goes where you did not want it to. You get most of what you came for and wear the rest. **+18 fuel** · **-3 hull**
- **PARTIAL** — The face calves while you are on it. You back off with a partial hold and a story. **+10 fuel** · **-6 hull**
- **BOTCHED** — Three kilometres of compressed ice releases about eleven seconds of stored temper directly into your bow. **-14 hull**

**Skim the tail** — *no check*

- You do not touch the body. You run the tail and collect what it is already shedding, which is slower and entirely safe. **+9 fuel**

**Leave it** — *decline*

- A long ellipse, a hard crust, and nobody out here to sell water to. It will be back around in ninety years. **nothing.**

---

## The runner

```
id       the_runner
tags     signal
gate     regions: LAWLESS · max_security 2
group    —
weight   7
places   paid_in_full
```

*Row teaser:* A package, one shell inward, no questions and no manifest.

> She is nineteen at the outside and she is running somebody else's errand with somebody else's ship, and the thing she needs moved fits in one hand. No manifest, no filing, no name on it.
>
> She cannot pay much now. She says the man it goes to pays properly and pays on delivery, and she says it like somebody repeating a thing she was told rather than a thing she knows.
>

**Take it quietly** — *Stealth 5*

- **MET** — It goes in a void behind the coolant run that nothing scans and nobody knows about. She watches you do it and does not ask what else is in there. **+20 credits**
- **CLEAN** — You find somewhere for it that will hold up to an ordinary look. **+20 credits**
- **PARTIAL** — You stow it badly and spend the next shell aware of exactly where it is. **+20 credits**
- **BOTCHED** — You are still finding somewhere for it when a patrol runs a courtesy sweep of the dock. Nothing comes of it. She sees the sweep and takes it back. **nothing.**

**Ask what it is** — *no check*

- She tells you, or tells you something. Either way she takes it somewhere else, politely, and you do not see her again. **nothing.**

**Decline** — *decline*

- She nods like she expected it and goes to ask the next ship along the rank. **nothing.**

---

## Paid in full

```
id       paid_in_full
tags     signal
gate     placed by `the_runner` only · never rolled from the pool
group    —
weight   — (placed)
```

*Row teaser:* Somebody here has been waiting for a package.

> He is old, and he is not what you were expecting, and he has been waiting at this berth for eleven days for a thing that fits in one hand.
>
> He does not open it in front of you. He pays what she said he would pay, which is considerably more than she was in a position to promise, and then he asks — carefully, as though the answer matters — whether she looked well.
>

**Take the money** — *no check*

- He pays in full, in cash, and thanks you in a register nobody has used on you in a while. **+150 credits**

**Tell him she looked tired** — *no check*

- He nods for a while. Then he pays you more than the agreed figure, and gives you a name at a yard two shells in who will fit you something at cost. **+190 credits** · **+1 module**

---

## The memorial

```
id       the_memorial
tags     signal
gate     regions: any
group    —
weight   6
```

*Row teaser:* A marked site, and a beacon nobody maintains.

> Four hundred and six people, a hull breach, and a marker put here afterwards by an office that no longer exists. The beacon still runs on a decay cell that has about a year in it.
>
> The names are on the marker. The cell is standard and you are carrying two.
>

**Replace the cell** — *no check*

- Twenty minutes and one cell out of your own stores. Another eleven years of a beacon nobody will hear, saying four hundred and six names to nobody at all. **-10 credits** *(archive entry, if this system holds one)*

**Log the names** — *no check*

- You copy the marker to your own archive, which is not the same as maintaining it, and is not nothing. **nothing.** *(archive entry, if this system holds one)*

**Hold station a moment** — *decline*

- You do not do anything. You are just there for a bit, and then you are not. **nothing.**

---

## Flare shelter

```
id       flare_shelter
tags     signal
gate     regions: FRONTIER, TERRITORY · min_danger 2
group    —
weight   8
```

*Row teaser:* A flare inbound, and a rock to put between you and it.

> The star is going to do something in about forty minutes and the instruments are confident about it. There is a rock two minutes away, big enough to shadow you, and on the far side of the rock is a survey drone that has evidently been using it the same way for years.
>
> Forty minutes is enough to reach the rock. It is enough to strip the drone. It is not enough to be leisurely about either.
>

**Shelter and strip** — *Thermal 6*

- **MET** — You take the shadow, take the drone apart in the dark, and come out the other side of the flare with a hold and a cold reactor. **+1 module** · **+40 credits**
- **CLEAN** — You get most of it done before the shadow starts to move and finish the rest in the light. **+1 module** · **+8 heat**
- **PARTIAL** — You get the drone open and the flare arrives while you are inside the housing. **+17 heat**
- **BOTCHED** — You misread the rock's rotation and spend the peak of it on the lit side. **+25 heat**

**Just shelter** — *no check*

- You put the rock between you and the star and wait it out doing nothing at all, which is the correct answer and a dull one. **nothing.**

**Outrun it** — *no check*

- You leave before it peaks. It costs a burn you had not budgeted for and you never find out what was on the drone. **-16 fuel**

---

## Deadfall

```
id       deadfall
tags     salvage
gate     regions: LAWLESS, TERRITORY · min_danger 3
group    —
weight   8
```

*Row teaser:* A collapsed gantry field, and something under it.

> An orbital yard came down on itself — not explosively, just structurally, over about a decade of nobody paying for maintenance. What is left is nine hundred metres of gantry lying across itself at every angle, still under tension in places, still letting go of a piece now and then.
>
> Under the middle of it is a fitting bay, and fitting bays are where the good parts are when the lights go out.
>

**Go under it** — *Maneuver 6*

- **MET** — You pick a line through nine hundred metres of dead scaffolding and nothing so much as brushes you. The bay is exactly as it was left. **+1 module** · **+1 exotic**
- **CLEAN** — You get in, get the bay open, and take a glancing hit from something that let go behind you. **+1 module** · **-4 hull**
- **PARTIAL** — Two hundred metres in, a span shifts across your line and you reverse out past a bay you can see and cannot reach. **-8 hull**
- **BOTCHED** — The thing about tension is that it is patient right up until it is not. **-16 hull**

**Work the outside** — *no check*

- The perimeter of the field is safe enough and picked over enough. You take what the last four crews did not think was worth the lift. **+1 exotic** · **+20 credits**

**Leave it lying** — *decline*

- Nine hundred metres of somebody's deferred maintenance. It will finish coming down eventually, on its own. **nothing.**

---

## The long tow

```
id       the_long_tow
tags     contract
gate     regions: TERRITORY, COSMOPOLITAN · needs_berth
group    —
weight   8
places   what_she_was_carrying
```

*Row teaser:* A dead ship, a live crew, and nowhere near enough engine.

> Her reactor is scrap and her crew are fine, which is the wrong way round for how these usually go. Six people, no power, and a station one shell in that will take them if they can get there.
>
> A tow is four hours of your engine at a load it was not built for, and a hull hanging off your stern the whole way that does not steer.
>

**Take the tow** — *Thrust 6*

- **MET** — Four hours, one heading, no drama. The station takes them and the yard master watches you come in with somebody else's ship on the line. **+90 credits**
- **CLEAN** — Five hours and a stern mount you will want looked at. They get there. **+75 credits** · **-3 hull**
- **PARTIAL** — You get her most of the way before the load tells you it is done. A yard tug comes out for the last of it and takes most of the fee. **+25 credits**
- **BOTCHED** — The line parts under load. Nobody is hurt and nothing is lost except four hours, a tow line, and a certain amount of dignity. **-18 fuel**

**Sell them a reactor start** — *no check*

- You have enough aboard to bootstrap her if they are not fussy about the state you leave your own stores in. They are not fussy. **-1 exotic** · **+70 credits**

**Signal it in and go** — *decline*

- You put their position on the emergency band and leave. Somebody will come. Somebody usually comes. **nothing.**

---

## What she was carrying

```
id       what_she_was_carrying
tags     signal
gate     placed by `the_long_tow` only · never rolled from the pool
group    —
weight   — (placed)
```

*Row teaser:* The ship you towed is here, and running again.

> She has a new reactor and an old name and the same six people, and one of them recognises your hull before you have finished docking.
>
> They never did tell you what was in the hold, because the tow was the thing that mattered and nobody asks a tug. They are telling you now.
>

**Take the share** — *no check*

- A fifth of what they were carrying, which they have already sold, in cash, without being asked twice. **+160 credits**

**Take the favour instead** — *no check*

- You tell them to keep it. Their engineer spends an afternoon in your machine spaces instead, and does not itemise what she does in there. **+1 module** · **+8 hull**

---
## Audit — run headless over the pool, not asserted

`encounter-prototype.html` was executed with a stubbed DOM and every option
walked. **29 options, 81 choices, 96 outcome bands** across batch-02 and
batch-03 together. Every checked choice has all four bands; every unchecked
choice has its text; every option has a full body.

### Coverage

| attribute | checks | | region | systems |
| --- | --- | --- | --- | --- |
| Sensors | **7** | | COSMOPOLITAN | 4 |
| Thrust | 4 | | LAWLESS | 2 |
| Maneuver | 4 | | FRONTIER | 2 |
| Stealth | 3 | | TERRITORY | 1 |
| Hull | 3 | | FAUNA | 1 |
| Thermal | 3 | | | |

**Maneuver and Thermal are fixed** — they were 1 each before this batch.
**Sensors is now the overweight one at 7**, which is the next batch's problem:
a Sensors build currently reads more of the galaxy than any other, and that
should not be a permanent advantage. Aim the next twenty at Hull, Stealth and
Thermal.

### Three deliberate exceptions the audit flags

**`the_memorial` returns nothing.** By Ruling 9 an option should cost you
something to walk away from, and this one costs an archive entry and nothing
else. **Kept on purpose.** It is the only non-transactional thing in the pool,
in a game whose premise is that everything is being taken apart for parts, and
one option that is just four hundred and six names and a decay cell is worth
the exception. If a second one appears, that is a pattern rather than a choice.

**`paid_in_full` and `what_she_was_carrying` have no decline row.** Correct:
they are placed payoffs. Both choices are gains, there is no failing band, and
there is nothing to decline. **Taxing a reward the player earned four jumps ago
teaches them not to take the offer next time.**

### Continuity now has two threads, not one

| placed by | pays off as | the thread |
| --- | --- | --- |
| `countersign` | `clerk_owes` | a signature for someone with no stake here |
| `the_runner` | `paid_in_full` | a package, and an old man who asks how she looked |
| `the_long_tow` | `what_she_was_carrying` | six people, no reactor, and a hold nobody asked about |

Three threads. **This is the mechanism batch-01 lost half its best writing to
not having** — the old contract required every event to resolve within itself.
An option is placed on a node, so a consequence has somewhere to live.
