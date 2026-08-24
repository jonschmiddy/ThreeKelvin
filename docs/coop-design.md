# THREE KELVIN — Co-op Design
*An extraction deckbuilder for one to four ships, tuned at four. Draft v0.3 — living document. Companion to `design-doc.md`. v0.1 assumed roguelite resets; v0.2 replaced that with persistent collections and extraction stakes; v0.3 adds the heat-death frame, the two-doors rule, and §0 — which is measured rather than argued.*

---

## The pitch

> **Humans near the heat death of the universe, stealing warmth from dying galaxies before the lights go out. Heat is what you came for, and it is the only thing that makes you visible to whatever waits past the core. Four ships can take the big prizes; one ship takes what it can carry quietly.**

Everything below is those three sentences, expanded. If a mechanic cannot be traced back to them, cut the mechanic.

**Why this frame and not the old one.** v0.2 said the background was falling and something was drinking it. This says we are the ones drinking it. That is better on three counts: heat stops being only a risk and becomes the prize, so extraction has something to extract; multiple galaxies need no new systems, because `RunState` already rolls a fresh `galaxy_kind`, `galaxy_seed`, `galaxy_spin`, `galaxy_name` and `galaxy_title` every run and persistence simply turns each dive into a different galaxy you strip and leave; and plural cores with one thing behind them explains why every galaxy has the same gradient, which a single extinguished fire did not.

---

## 0. State of the mechanic — measured, and a gate

**Everything in this document rests on heat having teeth on the map. It does not have them yet, and the gap is now measured rather than assumed.**

### What was there before

`Combat.end_turn()` was the entire heat rule: shed `dissipation()`, then burn one hull per point over `heat_cap()`. Outside combat, `dissipation()` was read in **zero** gameplay sites. The three things that read `Run.heat` on the map were the hull shader, the HUD label, and an audio warning — all cosmetic. The main doc's ruling that hot ships attract encounters and cold ships slip past did not exist in code.

### What has now been built

| Change | Where |
|---|---|
| Heat sheds in transit — half a turn's worth per jump, floor of one | `RunState.cool_in_transit()`, called from `jump_to()` |
| `signature()` — heat as a fraction of capacity, so hulls compare | `RunState` |
| `ambush_chance()` — signature gates it, danger scales it, stealth divides it | `RunState` |
| Heat costs up to 4 of 10 Stealth, so it feeds event checks too | `RunState.attr_stealth()` |
| Ambushes roll once on arrival and persist on the node | `Router._roll_ambush()`, `MapNode.ambush` |
| Winning an ambush does not consume the system | `Combat.clears_node` |
| Save version 3 carries the roll | `SaveGame` |
| The sim models ambushes, samples signature, and has a `hot` policy | `HeadlessSim` |

### What the simulator says

1,000 runs per cell. Noise on this sample is about ±2 points.

| Model | Map layer | Win rate | Signature on arrival | Post-fight signature | Overheat deaths /1000 | Ambushes/run |
|---|---|---|---|---|---|---|
| Cold (default) | off | 19–21% | 0.32 | — | 120–141 | 0 |
| Cold | **on** | 19–21% | 0.06 | 0.34 | 94 | 0.42 |
| Hot (`-- sim hot`) | off | 18% | 0.35 | — | 203 | 0 |
| Hot | **on** | 18–20% | 0.06 | 0.34 | 171 | 0.39–0.42 |

Four readings, in order of how much they change the design:

1. **Fights do end hot.** Post-fight signature is 0.34 and **37% of fights end above the ambush floor**. The heat exists. This refuted the first diagnosis, which was that combat sheds everything.
2. **A run makes about 65 jumps for about 8 fights.** Eight jumps per fight. Any per-jump cooling clears the residue long before the next fight, which is why arrival signature is 0.06 however the cooling is tuned. The map layer only ever sees the one or two jumps straight after a hot fight.
3. **The layer fires.** 0.42 ambushes per run; 22–24% of runs get jumped at least once. The mechanism works.
4. **It does not move the win rate.** Every cell sits in the 16–21% band against a 20.5% baseline. Heat is still not a difficulty driver.

### Why it does not bite, and what that implies

**An ambush pays scrap and a module.** It is a fight, and fights in this game are net positive for a competent player. Attaching *more fights* to heat therefore adds texture, not pressure.

That measurement produced a proposal, which this draft recorded and which has since been **overruled by the designer**. It is left here because the measurement is still true and the reasoning is still worth having:

> ~~**Heat will not become a difficulty driver by having consequences bolted to it. It has to gate reward.**~~ — proposed, rejected. See the ruling below.

### RULING: a shared kill pays one bag, not one payout each

**A fight two ships were in drops ONE pool at the node. Anybody in the party can
take a part out of it; a part somebody took is gone.**

This is the ruling the second playtest asked for by name, and it is a correction
rather than a new idea — §3's dive economy has always been a closed loop, and a
kill that paid every ship privately was not one. The netcode had already fixed
the *visible* half of that (two players being handed the identical module) by
salting the loot stream per seat, which made the duplication stop looking like
duplication without making it stop.

Three things follow, and the third is the one that makes it a design rule rather
than a bug fix:

- **The bag scales with the crew.** Two ships, twice the parts. Bringing a friend
  must not halve what a fight is worth to you — the enemy already grew by
  `CREW_SHARE` to meet you, and this is the other side of that bargain.
- **It does not touch the wallets.** Pillar 1 stands exactly as written: what you
  are CARRYING is private, and the bag is not carried by anybody until somebody
  reaches into it. Credits, dross and exotic are still paid per ship.
- **It is the first thing in the game two friends have to talk to each other
  about.** Not a betrayal mechanic and not a menu — a pile of parts, a rare one
  in it, and two people who can both see it. Pillar 2 says the dilemma should be
  physical; a bag on the floor of a system you both just fought in is as physical
  as this game gets.

Built. See `netcode.md`, "One kill, one bag", and `tools/cofight.sh`.

### RULING: heat does not gate loot

**Winning a fight pays the loot. Fleeing pays nothing. Heat has nothing to do with what a fight drops.**

Heat's only job on the map is the **residual you carry into the next jump**, and that mechanism already exists and already fires — `cool_in_transit()`, `signature()`, `ambush_chance()`, and the ambush stored on the node. Greed at one contact bills you at the next one. That is the whole of it.

This closes three things at once:

- **§6's two doors is off the table.** Skirmish-versus-commit does not exist, and disengaging is not a second way to get paid. `Combat.flee()` costs fuel and yields nothing, which is the intended shape rather than a gap.
- **§16 ruling 14** — *does skirmishing pay scrap, and how much* — is answered: **no**.
- **§0's own conclusion is reversed.** Heat is not required to be a difficulty driver. It is a resource you spend for tempo and a signature you carry between systems, and the ambush layer is the consequence.

The cost is accepted and should not be rediscovered later: the 1,000-run measurement above says heat does not move the win rate, and under this ruling it is not going to. **Difficulty lives in the economy** — which is what `tkg/CLAUDE.md`'s tuning rule has said all along, and what the enemy-scaling measurement actually moved.

### The gate

1. ✅ Map-layer cooling — built.
2. ✅ Map heat signature — built and instrumented.
3. ✅ Heat wired to Stealth — built.
4. ✅ Re-measured — heat does not drive difficulty. Reported rather than quietly passed.
5. ✅ **Closed by ruling, not by building.** The gate said "two doors, then measure again". There are no two doors. The gate is discharged.

---

## Design pillars

1. **Share the costs. Keep the wallets separate.** Heat, fuel, danger and the enemy are shared. Hull, modules, deck and scrap are private. Every powerful action is privately good and publicly expensive. This split generates every dilemma here. No betrayal mechanic is required.
2. **The dilemma is physical, never a menu.** Heat is a field with a radius. Danger tracks the deepest ship. A rescue is a flight. There is no BETRAY button in this document and there must never be one.
3. **Cooperation is the strong play. Defection is a temptation.** A design where defection is correct is solved in one dive and poisons the friendship in two.
4. **You keep what you carry home.** The collection is permanent. The hold is not. This is the whole stake structure and every other rule serves it.
5. **Deaths are still self-authored — but not always by the person who dies.** The main doc's greed clock survives contact with a party. It gains three more hands.

---

## 1. Two layers

The game splits into a persistent layer and a session layer. This is the largest structural change from the current build.

| | **The hangar** | **The dive** |
|---|---|---|
| Persists | Forever | One session |
| Holds | Your collection, your hulls, your materials | One ship, one hold, one galaxy |
| You do | Curate the loadout, craft, repair, assemble | Fly, fight, loot, extract |
| Ends when | Never | You extract, or you die |

A dive is thirty to sixty minutes. Four people can schedule that. A three-hour reset run needs four people free for three hours, and if one drops at hour two everybody loses everything. That social contract is why almost every four-player co-op game is persistent.

---

## 2. The collection is modules, not loose cards

The main doc already rules that **loot literally is deckbuilding**, and `DeckBuilder.build()` already assembles the deck from installed modules. Nothing generates a card except a module.

So "collecting cards over many dives" means **collecting modules**, and "curating your deck before you launch" means **choosing which modules to bolt on**. Slots are the deck size.

This makes the persistent-collection ask *cheaper* than it sounds. The collection is an inventory of `ModuleData`, which the game already rolls, serialises and installs. There is no second card economy to build.

Two card sources sit outside this and stay outside it: `RunState.dross` malfunctions, and the cold cards in §12. Nobody owns those. They arrive.

---

## 3. What extracts, and what does not

The main doc already runs a two-tier economy. Give each tier a job and the split does the anti-creep work by itself.

| | Extracts | Job |
|---|---|---|
| **Modules and hulls** | ✅ | The collection. This is progression. |
| **Materials** — exotic, precursor fragments (`RunState.materials`) | ✅ | The meta currency. Pays for hangar work, crafting, slot unlocks. |
| **Scrap** | ❌ | The dive currency. Repairs, station stock, fuel. Spend it or lose it. |

**Scrap must not extract.** It is the one currency on every price tag, and `Market.gd` is tuned as a closed loop — one base value, three prices, with the repair rate as the master difficulty lever. Let scrap bank between dives and players buy past the early game, and the main doc's own tuning rule collapses.

Non-extracting scrap also creates a good last beat. At the final station before you climb out, unspent scrap is wasted scrap. Spend it or lose it.

`RunState.materials` is already a `Dictionary` keyed by material id, with `exotic` as a property over it. The meta currency is modelled today.

---

## 4. Extraction is the way out

**You extract by flying back out to the rim.** No new map structure is needed. `MapGen` already runs `LAYERS` 9 shells from rim to core with `DANGER_MAX` 10, and the main doc already rules that lateral travel is cheap and that depth is the danger gradient.

Three things fall out of this for free:

- **Fuel means twice what it meant.** `RunState.fuel` starts at 150 and every jump bills against it. Now the budget has to cover the climb back out. Every coreward jump is two jumps.
- **The dive length is chosen by the player, not by the map.** Go three shells deep for a small safe haul. Go nine for the ember. The greed gradient becomes the session planner. "We have forty minutes" is now a legal in-fiction decision.
- **It is the long way home.** The main doc already leans on that framing for the run goal. Extraction is that framing, made into a rule.

---

## 5. The convoy

Each player flies their own ship. The convoy is not a formation you join. It is a distance you happen to be at.

**The unit of play is the jump tick, not the combat turn.** Each player commits a jump and resolves their own node. Combat inside a node keeps Slay the Spire grammar.

**Ships sharing a fight run free, with one barrier.** ~~Simultaneous lock-in: everyone commits cards face down, everyone resolves together, nobody sees another hand.~~ **Rejected and built the other way.** Lock-in requires cards to become deferred effects, and the ones that draw, gain energy, or block-then-attack do not survive being resolved out of order — it is a rework of `CardResolver` and a chunk of the card set to buy a property that has a cheaper source. Instead: everybody draws and plays at their own pace, immediately, exactly as they do alone. The only thing that waits is the **enemy's** turn, because that is the one moment a shared object acts on several private ones. Nobody watches anybody, nobody waits on a phase, and not one card changed. See `netcode.md` §4.

**Do not gate the tick.** Let players run at their own pace. Gating means three people watch a fourth shop. §7 supplies the leash.

---

## 6. Heat is a field with a radius

This is the dial for together-or-apart, and it is continuous rather than a vote.

- **Same or adjacent node:** signatures **sum**. The convoy is loud.
- **Beyond that:** each ship carries its own signature only.

| | Together | Apart |
|---|---|---|
| Heat signature | Summed across every nearby ship. Loud. | Split. Quiet. |
| Fights | Shared. Fewer hits each. Cover is possible. | Solo, at solo difficulty. |
| Fuel | Formation flying is cheaper per ship. | Full cost each. |
| Map coverage | One node per tick. | Up to four nodes per tick. |
| Transfers | Docking allowed — scrap, fuel, modules. | Impossible. |

At four ships the summed signature is the point. A full party flying nose to tail is the loudest object in the sector.

**Chassis choice is the party role, and no new stats are needed.** `HullData` already carries signed `sensors` and `stealth`, and its own header notes Solari runs negative on stealth because a ship that hot cannot hide. Redline light hulls see far, run cold and scout. Korvan heavy hulls are loud and half blind and hold the line. Weight class becomes party composition for free.

### ~~Two doors on every contact~~ — REJECTED

> **This subsection is dead. See the ruling in §0.** Winning a fight pays the loot, fleeing pays nothing, and heat does not touch loot generation at all. Skirmish-versus-commit is not being built. The text is kept because the reasoning that produced it is worth being able to re-read, and because a section deleted without a record is a section somebody proposes again in six months.

The field above is **passive** — you are hot because of where you are. That is not enough, and §0 is the measurement that proves it. This is the active half, and it is the load-bearing rule of the whole design.

You jump in and there is a frigate. You may:

| | **Skirmish** | **Commit** |
|---|---|---|
| Who can | One ship, alone | Realistically, the party |
| Heat | Low. You never open the expensive cards | High. This is what capacity is for |
| Pays | Scrap — the stuff you were going to melt anyway | **Modules.** The cards you actually want |
| Ends when | You break contact | It dies |

**This is what makes heat a difficulty driver rather than a tax.** §0 measured the failure mode exactly: bolting consequences onto heat adds fights, and fights pay, so nothing moves. Gate the *good loot* behind heat and the player has to want it. Then every consequence already built — the ambush, the Stealth penalty, the overheat burn — is a price on something desirable instead of a fine for a mistake.

It also gives the party a **positive** reason to fly together. Every other magnet in §8 is defensive: fuel, safety, rescue. This one is greed, and greed is the stronger pull in a game whose third pillar is the greed clock.

**And the loop closes with §0's cooling.** Commit to the big fight and you leave hot — post-fight signature is 0.34, and 37% of fights already end above the ambush floor. The *next* node is where you pay for it. Cool off over a few jumps, or push on hot and get jumped. Greed at one node bills you at the next, which is the greed clock expressed thermally.

**Most of this is already in code.** `_roll_foes()` rolls a lead plus an optional pack. `Combat.start()` takes `extras`. `fled` already tracks broken contact. What is missing is that fleeing currently pays nothing — so *skirmish* is mostly "make disengaging pay scrap", and *commit* is the fight that already exists.

---

## 7. Danger tracks the deepest ship

**Danger scales to whichever ship is deepest, not to each ship separately.**

If one player pushes coreward, everybody's nodes get harder. They take the loot. The other three take the risk.

This is the strongest rule in the design. It needs no ballot, no secret and no button. It happens by playing. One player's greed becomes three other people's problem, silently, while they are alone and outside sensor range.

It is also the leash on free-running time. A player who sprints ahead is spending the party's safety and can feel it happening.

---

## 8. What keeps a convoy a convoy

Free-running time plus solo nodes creates a real failure mode: four single-player games in one window. These pull ships back together.

- The fuel tank is shared.
- Transfers require docking, which requires adjacency.
- Some nodes need two or more ships — a derelict with a door that must be held, megafauna too large to solo.
- Danger tracks the deepest ship, so nobody can ignore where the others went.
- The ember cannot be carried out alone. See §13.
- The hellbender is a set piece one ship engages and four ships finish — and it is the first magnet that moves. **Built**; see §18.

---

## 18. The Hellbender — the galaxy's other harvester. BUILT, and measured.

*Numbered out of order like ruling 20 in §16: numbers here are stable IDs, not positions, and this section lives beside §8 because it is the newest answer to §8's question.*

### We are not the only crew drinking it

The pitch says humans steal warmth from dying galaxies. Nothing in it says only you do. **The Hellbender is a rival harvester ship — one per galaxy — with a POSITION instead of an address.** The name is a real giant salamander, and the reference underneath it is the heraldic one: the salamander of legend sits unharmed in flames, and this crew flies that device on the hull — a ship built to drink heat, wearing "we live in the fire" as its emblem. The device goes unexplained in-fiction, like everything else; an archive document can describe it without glossing it. It rides the same link lattice the party does, one hop per `hellbender_stride()` party jumps — a threshold scaled by the crew, so the cadence each pilot feels is two of their own jumps per port however many are flying — and it eats the derelicts it lands on: the wreck is consumed, marked `eaten`, and the sector at that system says *the Hellbender fed here first* instead of *stripped*. It is drawn on everybody's chart at all times, in ember, because it is the hottest thing flying and heat is the one signature this game says cannot be hidden — which is also its balance: a threat you can always see is a threat you can always route around, and routing around it is priced in salvage.

Catch it and it is a set piece: hand-tuned like the custodian (90 hull, 6 armor, between the sentinel and the boss), never danger-scaled, fought as a shared fight like any contact at a place. Below 35% hull it stops fighting and spools an **escape burn** — one full player turn of telegraph, and if it acts on it, it is gone: two hops at once, no salvage, the fight over because the other side left. The damage is banked. It mends `HELLBENDER_MEND` per ordinary move and never on a flee hop, so it escapes hurt and stays hurt exactly as long as the chase window is open. Killing it pays three modules a hand — one bag in a party, under the §0 ruling — plus the biggest credit reward short of the core.

### The moment this exists to produce

One ship jumps into its system, sees it at anchor, and says the thing into the voice channel this design has been building toward: *everyone get here, now.* Everything that makes that sentence WORK was already built — a fight a latecomer can join at 10% health, an enemy that grows by `CREW_SHARE` to meet each arrival, one bag when it dies — and the hellbender is the first thing worth saying it about that can also LEAVE. The escape burn is what makes the party hurry; the banked damage is what makes a failed first attempt a down payment instead of a waste; the mend-per-move is what makes dawdling cost the down payment back.

While it holds a system it is a blockade: nothing there is reachable past it — not the dock, not the node's own contact. Arrival does not auto-engage, for the reason the core stopped auto-engaging: two people never arrive on the same second, and a set piece a party cannot gather at is fought alone by design. The sector says what it is and the button says ENGAGE, and whether to press it before the others land is the player's own greed talking.

### RULING: the hellbender is host-authoritative

**The host owns its position, its hull, and its clock, and pushes all three whole.** This is the contested-object rule from combat applied to the map: everything else out there is either fixed by the seed or a fact about the past, and a thing that MOVES needs a clock this game deliberately does not share — four ships jump at their own pace, and there is no tick. So the party's jumps are the tick, counted by the host (its own in `jump_to()`, everybody else's off the presence message, whose `at` moving already says "jump"). WHERE it goes each move is still `Rng.derive(&"hellbender", move counter)` — positional in time — so a solo run replays bit-for-bit from its seed and the wire carries only the one thing a seed cannot: when. Protocol 7, save version 8, `docs/netcode.md` has the wire detail.

Two consequences worth naming:

- **It is pinned while anybody fights it.** The party's other ships keep jumping, but the clock does not advance a thing that is being shot at — it leaves through the escape burn or not at all. "Keep him on the ropes" is literally the movement clock stopping.
- **Eating is derived, not messaged.** A landing on an uncleared derelict consumes it on every machine by the same rule, so the movement push IS the claim and the claims list never hears about it.

### Why it eats, and what the simulator says

§0's lesson: attaching more fights to a mechanic adds texture, not pressure, because fights pay. The hellbender is pressure because AVOIDING it costs — every derelict it reaches first is salvage the party does not get. 1,000 runs per cell, seed 555, same build, `-- sim nohellbender` as the control:

| Cell | Win rate | Met it | Engaged | Killed | Escaped | Derelicts eaten/run |
|---|---|---|---|---|---|---|
| Hellbender on | 29.8% | 249 | 215 | 133 | 81 | 3.01 |
| `nohellbender` | 29.6% | — | — | — | — | 0 |

Four readings:

1. **The win rate does not move.** 29.8 against 29.6 is inside the noise, and that is the design intent, not a failure: solo it is optional pressure, not a difficulty spike. The party moment is what it is FOR, and the sim cannot measure a voice channel.
2. **A quarter of runs cross its path** without being steered to it, and the model — health-gated, no build knowledge — commits 86% of the time it does.
3. **The escape fires.** 81 of 215 engagements ended watching it leave, which is the number that says the one-turn window is real rather than decorative. 133 kills against that is a 62% close rate for a competent solo player who engages at strength.
4. **It eats about a fifth of the galaxy's wrecks.** ~17 derelicts generate per map; it reaches 3 a run. That is a real tax on the salvage economy without emptying it — and in co-op the tax quadruples in felt weight, because it is eating out of ONE shared map.

### Open

| # | Question | Blocks |
|---|---|---|
| S1 | Should it hunt heat? A hellbender that turns toward the party's summed signature makes §6's field predator-shaped — and makes running cold worth something new | §6 tuning; the horror layer's tone |
| S2 | One per galaxy, or one per N shells deeper? | How often the §8 magnet fires |
| S3 | Does killing it drop something only it carries — the run's second-best unique — or is the bag enough? | Whether engaging is a want or a shrug |
| S4 | Should its kills feed IT? A hellbender that grows by what it eats gives the route-around decision a compounding cost | Whether ignoring it stays viable all run |

---

## 9. Fog, rendezvous, and the unverifiable claim

Fog of war is already ruled in the main doc: sensors and chart data decide what you can see. Apply it to your party.

**You see another ship only inside your sensor range.** Outside it, the chart shows their last known position with an age stamp. `RunState.trail` already records every system visited in order, so the data exists.

A rendezvous is therefore a promise, not a waypoint. You agree a system and you fly to it. They may be there. They may be late. They may be dead.

**This is the rule that makes the design survive a voice channel.** Four friends on Discord will simply tell each other any secret the game tries to keep. So tension cannot come from hidden choices. It must come from claims nobody can check, or from pressure that runs in real time:

- Nobody can see your hand, your heat headroom, or your hold.
- Contraband is already unverifiable by design, and it exposes the whole convoy to inspections.
- Locked-in simultaneous turns leave no time to negotiate every play.

---

## 10. Death, the wreck, and the cold approach

Under extraction, death is not the end of a player's evening. It is the start of everybody else's real decision.

When a ship dies it becomes a **WRECK** node at the system where it fell, holding the hull, the installed modules and the entire hold. `MapGen.NodeType` currently holds START, FIGHT, STATION, EVENT, DERELICT, GOAL and PULSAR. This one is placed at runtime.

- **Every chart shows it always, through fog.** The pull has to be legible or it is not a decision.
- It shows an age. Time matters and players can watch it matter.

### The rescue is dangerous because of the rescuer

Do not guard the wreck with an enemy. That makes it a taxi fare.

A dead ship is cold, and in this universe cold is invisible. The wreck is safe precisely because it is dead. **You are the problem.** You arrive hot and you light it up.

So the approach carries a heat ceiling. Arriving cold means no fights on the way in, and venting before arrival at the cost of turns and cards. Heavy hulls dissipate badly, so a Korvan rescue is genuinely hard and a Redline rescue is what that chassis is for. A new encounter type, built from the game's core mechanic, needing no new enemy art.

### The hold is the limit, and that is the scene

**The pilot always comes back.** Reviving is not optional and not separable from salvage. There is no button that takes the cargo and leaves the person — see pillar 2.

**The cargo is what will not fit.** The rescuer's hold has limits. So the radio call is: *I can take three modules. Which three?*

That is the best scene in the design, and under persistence it is not about tonight. It is about the Legendary somebody spent eleven dives finding.

### What death costs

- **The hull is gone from the collection** unless it is recovered.
- **Everything left in the wreck is gone from the collection.** Permanently, if nobody comes.
- **Rebuilding costs materials, and hangars are private.** Whether the party chips in is a real conversation with a price tag.
- **The wreck decays.** See §12. Decay is not deletion.

### Nobody dying alone ends the dive

If every ship is a wreck, the dive is over and everything in all of them is lost. `RunHistory.Outcome` — currently DIED, WON, ABANDONED — needs entries for extraction, total loss, and partial extraction.

### The party may not come

This is the best dilemma here, and nothing about it is hidden.

The others can keep pushing. They can take the loot and extract. And the dead player is still on comms: they can see the chart, they can see three ships not turning around, and they can ask.

Nothing needs verifying, because the choice is public. The temptation is real anyway.

It is also **not simply betrayal**. Fuel may be short. The wreck may be four jumps coreward at a danger level that just killed a whole ship. Refusing may be correct. That ambiguity is what lets this survive a friendship.

At four players it also becomes a group decision, which is worse in the way this game wants. Somebody has to say it out loud first.

**Ruling lean: refusal is a silence, not a button.** A menu item labelled ABANDON grants permission. Making people simply fly the other way, in front of the person watching, is the version this game wants.

---

## 11. What the dead player does

Do not make them spectate. Give them the half of the game the living cannot have.

**The living have agency. The dead have sight.**

They are outside the ship now. They are in the cold, so they see what the cold sees:

- Enemy intent one turn further ahead than the living player sees.
- What is actually inside a fogged node.
- The real background temperature, unrounded.

They cannot act. They can only talk.

This is a Hanabi split. It makes the rescue trip the most engaged the table has been all session, and it keeps the dead player useful, which is the only thing that stops them from leaving.

---

## 12. The cold — the horror layer

### We are the ones drinking it

2.725 K is what is left, and it is nearly gone. You are late in the universe, and you are here to take what warmth is still lying around before the last of it goes.

**Put the background temperature on the HUD as a live number.** It falls as you go coreward. 2.7 at the rim. 2.4. 1.9. One number is the depth gauge and the dread meter at once, and it costs almost nothing to build.

This is the frame that makes the rest cohere. Heat is not merely dangerous — **heat is the cargo**. It is what the ember is, it is what extraction extracts, and it is why home needs you to come back. And because it is the only self-emitted warmth for light years, carrying it is exactly what makes you visible.

Framing for the fiction: every galaxy has a core, and the same thing waits past all of them. Nobody has established what it is. What is established is that it notices warmth, and that the deeper you go the more of it there is to take.

### The trap: the cold helps you

Colder background means better dissipation. Your ship runs cooler, vents faster, and plays its expensive cards more often. **The horror rewards you for approaching it.** Every player notices their ship performing better the deeper they go, and most decide the falling number is good news.

### The cold gets in

Long exposure adds cards to your deck that you did not install. No module made them. They are cheap. They are strong. They generate **negative** heat. Playing them is correct. Playing them adds more of them.

Joined to §10, this is the payoff of the whole design:

- **Death is how you get changed.**
- **A slow rescue is how much you get changed.**
- The party caused the delay. The party can see the heat readout afterward. **The party cannot see the deck.**

So they watch a ship run impossibly cold and hit impossibly hard, four jumps away, and cannot see why. That is horror which survives a voice channel, because saying it out loud does not fix it.

The greed loop closes on itself. The greediest player dies deepest. The deepest wreck is the slowest to reach. So the greediest player comes back the most changed, and whoever flew all that way has to decide whether to mention it.

### Cold cards extract

**Lean: cold cards come home with you, bound to the hull that earned them.**

This is what makes them frightening rather than a per-dive nuisance. A corrupted ship is a ship that is measurably better and quietly wrong, sitting in your hangar between sessions.

The purge is to **abandon the hull**. Mid-run hull swapping already exists in the main doc. Giving up a corrupted chassis means giving up its rolled stats and its innate perk, and re-slotting everything. That is a real price, paid in the hangar, in the cold light of not being in danger.

**Tuning ruling: cold cards must never be a pure trap.** If the correct play is "never touch them", the mechanic is dead and players read it in one dive. They must be genuinely good. The cost must arrive late and be survivable. Players have to choose them with open eyes and still regret it.

### The flip at the core

Past a threshold, dissipation stops being useful. Heat leaves faster than the reactor makes it. Systems need a minimum temperature. The reactor needs heat to run.

The whole game teaches you that heat kills you. The core teaches you that cold kills you, and that heat is the only thing you are.

That lands the title and gives the deep dive a mechanic instead of a cutscene.

---

## 13. The ember — the prize is a burden

At the core there is one ember. It is the top of the loot ladder and it is the reason to dive nine shells instead of three.

**No player-versus-player combat.** Every card assumes one-sided damage and no player dodge. Building a duel is large scope and it turns cosmic horror into an arena. The environment does the killing. Your partner just does not move.

**The ember cannot be stood next to. It has to be carried out.**

- Whoever holds it runs permanently hot. They cannot vent it. They cannot hide.
- The carrier lights up the whole convoy. Every summed-signature rule in §6 now works against the party.
- **Only the ship that lands with it keeps it.**
- It can be handed off at dock. It can be dropped.

So the party must choose a carrier, and the carrier is simultaneously the winner and the most likely to die. Nine shells of climbing out, hot, with everything in the sector awake.

**The escape is the climax.** Going in is easy. Getting home is the game — which is the pitch, arriving on schedule at the end of the deepest dive.

Chicken survives inside this as a special case. The carrier can run for the rim early and leave the escorts behind. Nobody has to press anything to do it.

---

## 14. Newcomers and power creep

Both problems have structural answers rather than tuning answers.

- **The ceiling is slots, not collection size.** A veteran and a newcomer fly the same number of modules, capped by reactor budget and hardpoints exactly as the main doc already rules. The veteran's are better and better matched. That is a real edge and a bounded one.
- **Danger tracks the deepest ship.** A veteran who pushes deep raises the newcomer's difficulty. The mismatch is self-limiting, and it is self-limiting in an interesting way.
- **Veterans can gift modules at dock.** §6 already allows transfers. Outfitting a new player from surplus becomes a good social moment instead of a gap.
- **Shallow dives are real content.** Three shells with a starter kit is a legitimate session, because the player chooses the depth.
- **Revisit "starter hulls are bad on purpose."** That ruling was written for a roguelite where the first ten minutes are meant to be lean. In a persistent party game it means a new player is dead weight in front of three strangers. The starter should be plain and complete, not deliberately broken.

---

## 15. What this costs in code

Measured against `main`, not assumed.

| Item | Current state | Work |
|---|---|---|
| **`Run` is a singleton** | Autoload holding one run. **697 references, 68 distinct members, 33 files.** | Becomes an instance. Largest single item; gates most of the rest. |
| **The hangar layer** | Does not exist. No persistent player state of any kind. | New save file, new screen family: collection, loadout curation, crafting. `RunHistory`'s split from `SaveGame` is the pattern to copy — one file appends, one file is the present tense. |
| **Extraction** | No concept. A run ends at the GOAL node or in death. | Win condition becomes "reach the rim alive". Cheap: the shells already exist. |
| **Networking** | **The session layer is built and tested — see `netcode.md`.** Host, lobby code, join, roster, version refusal, one seed on four machines, each player's ship and position on everybody's screen, **one map rather than four copies**, and **one enemy rather than four copies** — the host owns any fight more than one ship is in. Direct and relay transports both. `godot --headless --path . -- nettest`. | Three gameplay messages exist above the seed. Still to come: the shared heat field of §6 on the map, the shared fuel tank, and danger tracking the deepest ship (§7) — which is now cheap, because everybody's position is already on the wire. |
| **RNG determinism** | ✅ **Built.** `Rng` autoload: five named streams off one master seed, plus `Rng.derive()` for anything a player can reach out of order. `Run.galaxy_seed` is now the master seed and is what a host sends. `-- seed N` replays a run; `-- rngtest` proves it. Balance re-measured at n=1000 either side — within noise. | Combat and event RESOLUTION are still host-only. A client cannot yet replay a fight from the same seed, because nothing sends the inputs. |
| **Serialization** | `SaveGame` writes a complete run to JSON at VERSION 2, full float precision. | Reuse as the wire format. Add a separate hangar file. |
| **Combat** | ✅ **Shared.** The host owns the enemy — hull, block, armor, intent, and who it swings at. Your deck, hand, energy, block, heat and hull stay on your own machine, because nobody else targets them. `SharedFight` is a plain `RefCounted` with no `Run`, no `Combat` and no screen in it. Everything funnels through `Combat.damage_enemy()`, which is why this needed a field rather than a rewrite. | Reinforcements and pacification are off in a shared fight rather than wrong in one. Both want the host counting something it does not count yet. Simultaneous lock-in was **rejected** in favour of free-running turns with one barrier — see §5. |
| **Screen grammar** | Your ship left, the thing you face right. **`ShipView` no longer reads `Run` — it takes a `ShipBuild`, and `EncounterView` puts a convoy column left of your hull: one slot per partner, drawn from their build, with their name, hull class, hull and heat.** `SectorScreen` and `HudBar` still read `Run.*` directly. | The hardest half is still open: four ships is four hands, four intent strips and four sets of chips, and only the ships themselves have somewhere to live. What is settled is that a partner's ship is drawn from a description of THEIR ship, which had to come first — see `netcode.md` §4. |
| **Map heat signature** | Does not exist. `DEVELOPMENT_PLAN.md` already lists Thermal as "derive; add map signature". | Build once; solo and party both use it. |
| **`sensors` / `stealth`** | Fields exist on `HullData`, signed, unused. | Wire to fog and partner visibility. |
| **`NodeType.WRECK`** | Seven generated entries. | New type, placed at runtime. |
| **`RunHistory.Outcome`** | DIED, WON, ABANDONED. | Extracted, total loss, partial extraction, ember recovered. |
| **Background temperature** | Does not exist. | One float, one HUD readout, one dissipation modifier. Cheap for what it buys. |
| **Scrap non-persistence** | Already true. Scrap resets in `start_new_run()`. | Nothing. The economy is already a closed per-dive loop. |
| **Materials as meta currency** | `RunState.materials` is already a `Dictionary` with `exotic` as a property over it. | Move the store to the hangar. Small. |

**Sequencing.** The `Run` instance refactor gates most of this. Three items do not depend on it and improve the solo game on their own: the map heat signature, the background temperature, and RNG determinism. Build those first regardless of when co-op starts.

---

## 16. Open rulings

| # | Ruling | Blocks |
|---|---|---|
| 1 | **Does the solo game become extraction too, or stay a roguelite?** One model is far less balance work and reuses everything. Two modes doubles it. *Lean: one model.* **This is the same question `DEVELOPMENT_PLAN.md` carried as its open ruling #11, rescued here 2026-08-24 when that file was trimmed.** Its framing is worth keeping: §16.1 *overturns the no-meta-progression ruling stated in `RunHistory.gd` and `design-doc.md`* — persistent collection, per-dive credits, win = reach the rim alive. Whichever way it goes, those two files have to be corrected or confirmed in the same pass. | Everything. This is the top ruling. Decide before the economy is tuned. |
| 2 | Party size floor. Four is the target. Is a solo dive a first-class mode or a practice range? | Tuning of §6, §7, §13 |
| 3 | Wreck decay rate, and whether it has a floor | Rescue urgency; how much cold gets in |
| 4 | Does dead-player sight cover the whole chart or only nearby nodes | Balance of the §11 Hanabi split |
| 5 | Is abandonment a formal action or only a silence — *lean: silence* | Whether refusal is a button |
| 6 | Shared fuel tank: does it replace private fuel or sit beside it | §6 and §8 both depend on it |
| 7 | Where the flip point sits; fixed or rolled per galaxy | §12, and the shape of a deep dive |
| 8 | Danger tracks the deepest ship — live position, or deepest ever reached this dive | §7 is the strongest rule here and this changes its whole feel |
| 9 | Can the same player be rescued twice in a dive, and does the cost escalate | Death spiral tuning |
| 10 | Does the ember's carrier get any compensation, or is the risk its own argument | §13 balance |
| 11 | Do hulls extract, or is the hull always consumed by a dive | Collection shape; §12's purge depends on it |
| 12 | Rework "starter hulls are bad on purpose" for a party game | §14, onboarding |
| ~~13~~ | ~~Do all four players share one galaxy instance, or one map with private fog~~ — **ANSWERED: one instance.** The seed already gives four machines an identical galaxy; the host now also holds which systems the party has consumed, so a wreck is stripped once. Private fog is compatible and not built — when it arrives it gates what goes ONTO the wire, not what comes off it | Was: netcode shape. Now built — `netcode.md` §4 |
| ~~14~~ | ~~**Does skirmishing pay scrap, and how much?**~~ — **ANSWERED: no.** Fleeing pays nothing. See the ruling in §0 | Closed. §6's two doors is rejected with it |
| ~~15~~ | ~~Should an ambush drop loot at all?~~ — **FOLLOWS from the §0 ruling: yes.** Winning a fight pays the loot, and an ambush is a fight. That it is roughly EV-neutral is the measured consequence, not a problem to fix. *(Read from the ruling rather than stated in it — say so if that is wrong.)* | Closed |
| 20 | Does a station's stock restock, or is one shelf all four ships get for the dive | Currently one shelf, claimed a slot at a time. That is the honest reading of §3's closed economy and it makes docking together a real cost — but four ships sharing three parts is untested at the table |
| 17 | Does a shared fight get reinforcements, and whose roll is it | Off today. Needs the host spawning into the shared enemy list at an index everyone agrees on — short, because foe ids are already on the wire |
| 18 | Can a party pacify fauna together, and does one ship shooting ruin it for everyone | Off today. Needs the host counting quiet turns per ship. The interesting version is that it CAN be ruined |
| 19 | Should a ship that flees a shared fight shrink the enemy back down | Currently no — the party is left holding a frigate scaled for the crew that was there. Harsh, honest, and untested at the table |
| 16 | Transit cooling rate — currently half a turn's worth per jump, floor 1. At ~8 jumps per fight almost any value clears the residue | §0, and how long a commit is felt |

---

## 17. Deliberately not here

- **A betrayal button.** Pillar 2. Every defection here is a physical act with a cost.
- **Player-versus-player combat.** §13.
- **A traitor role.** Everyone wants the same thing. Tension comes from scarcity, not from a hidden objective.
- **Persistent scrap.** §3. It would dissolve `Market.gd`'s closed loop and the main doc's master difficulty lever with it.
- **Stat-based meta-progression.** The collection is horizontal — more options, capped by slots. It is not a stat ladder. The main doc's warning against power creep still stands.
- **Text chat and ping systems as a design assumption.** §9 assumes players are already talking, and is built to survive it.
