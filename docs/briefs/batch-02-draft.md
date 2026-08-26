# batch-02 — first options

*Written 2026-08-26, offline. Revised the same day: **standing removed** (§0),
then **the six checked events ported in** (OPT-007–012).*

**13 authored options.** Six new, one placed, six ported. The new six were a
voice check before volume; the ported six are the existing game's best writing,
kept.

**Ruled 2026-08-26: the event model is retired at phase 8** — `EventTable.gd`,
`NodeType.EVENT`, `MapNode.event_key` and the eight unchecked events all go.
**It does not die until the option pool can stand without it**, or phase 8 ships
a game where every third system offers the same thing.

**Format:** schema-agnostic. Fields map onto `ENCOUNTER_REBUILD.md` §4. Phase 6
has not built the table yet, so nothing here is GDScript — the content is the
expensive part and remapping it later is an afternoon.

**⚠ Before authoring more: run `ENCOUNTER_GENERATION.md` §0's recovery check.**
A hundred event seeds and a `batch-01.md` existed and are not in the repo.

**⚠ The two cordons in this file are the PRE-fix text.** `ENCOUNTER_FLOW.md`
Ruling 9 — *an obstacle guards a reward, never a door* — invalidated both of
them, and `encounter-prototype.html` carries the corrected versions. Take the
prose from the prototype, not from here, until this file is re-synced.

---

## 0. Every reward here exists today

Checked against `main` at `dd998f8` rather than assumed. **An option that pays in
a mechanic nobody built is a content file that cannot land.**

| Reward | API | Real? |
| --- | --- | --- |
| credits | `Run.add_credits(n)` | ✅ |
| fuel | `Run.fuel += n` | ✅ *(figures marked `[S3]` — the sweep may reprice)* |
| module | `Run.stow(LootGen.roll_module(danger))` | ✅ rarity gated by danger |
| materials | `Run.add_material(&"exotic"\|&"relic", n)` | ✅ **only two exist** |
| hull damage | `Run.take_hull_damage(n, reason)` | ✅ |
| archive entry | `Archive.at_node(n)` then `Archive.recover(id, where)` | ✅ *but positional — see below* |
| **standing** | `Run.standing_with()` | ⛔ **REMOVED FROM THIS BATCH** |

### Why standing is out

**Ruled 2026-08-26: no encounter outcome touches standing until it is a system.**

It exists — a dictionary on the run, keyed by manufacturer — but:

- **Contracts are the only writer** (`RunState.gd`:2291). Nothing subtracts, so
  every `−1 standing` in the first draft was inventing a mechanic.
- **It has exactly one effect**: `standing_bid_bonus()`, +5% a point capped at
  20%, and **only on the bid**. Never on the ask — `Market`'s invariant leaves
  about seven percent between melt value and the price floor, so a discount on
  what you pay would be a buy-and-melt exploit at four points.
- **It is never displayed.** No UI reads `standing_with`. A player earning it
  gets no feedback and a player losing it gets no signal at all.

A consequence the player cannot see is not a consequence. Wire it into the pool
later, deliberately, with a readout — it is a good hook and deserves better than
being smuggled in through a content file.

### The archive is positional, not grantable

`Archive.at_node(n)` derives from `Rng.derive(&"doc", n.index)` — **a system
either holds a document or it does not**, and most do not. So an option cannot
conjure one; it can only recover the one that is here, which is what the derelict
path already does.

Every archive reward below therefore reads **"recovers this system's document, if
it holds one"** and pays credits regardless, so the option stays honest on a
system holding nothing.

---

## 1. Rules these are written against

From `ENCOUNTER_GENERATION.md` §1, all three carried from the batch-01
post-mortem where they survived contact:

- **Failure domain.** A ram costs hull, a sneak costs detection, a burn costs
  heat. **Botches surprise in degree, never in kind.**
- **Pile-on guard.** No BOTCHED band stacks two of {hull damage, malfunction,
  combat entry}.
- **Hard gates only for meter payments and physical impossibility.** Everything
  else rolls the ladder.

And `ENCOUNTER_REBUILD.md` §5: **fights and the wrecks they leave are where
modules and rarity come from.** Signals, claims and contracts pay in credits,
fuel, materials and archive entries.

**A fourth rule, recovered from `EventTable._checked()`'s header** and not in
`ENCOUNTER_GENERATION.md`:

> **EVERY EVENT HAS A FREE EXIT.** Exactly one option that costs nothing and is
> genuinely unpunished, so declining a 20% gamble is a real choice rather than a
> trap with no door.

**How it maps to the option model.** The system-level free exit is now PLOT NEXT
JUMP, live from arrival (`ENCOUNTER_FLOW.md` Beat 6), so a *system* can no longer
be a trap. But the rule still binds **inside a group**: if every member of a
boxed set costs something, the box needs a decline row. Every group in this file
has one.

Independent options need no decline row — not clicking one is free.

**On PARTIAL:** the ladder splits failure evenly between PARTIAL and BOTCHED, so
at four short it is 47.5% each. `SkillCheck.gd` says it outright — *partial is
where the design effort goes.* It is the band a marginal attempt produces most
often and must not read as a watered-down botch.

---

## OPT-001 · The weighing

```
id       weighing
tags     contract
gate     regions: COSMOPOLITAN · needs_berth · min_security 3
group    berth          (competes with OPT-002)
weight   10
```

**Two berths, two scales, one cargo.** A hauler sits between them with a hold she
cannot get weighed twice. Both offices have quoted her. Both quotes are honest.
They differ by a third.

> **Stand as her witness** — *Sensors 5*
> - **MET** — You read both scales off their own telemetry before either office
>   opens its mouth. The low one recalibrates without being asked, and nobody
>   says the word *error*. She pays you out of the difference. **+45 credits.**
> - **CLEAN** — You catch the discrepancy but not its direction. The offices
>   settle it between themselves, courteously, at a table you are not at. She
>   pays you for the afternoon. **+22 credits.**
> - **PARTIAL** — Your figures agree with neither of theirs. A third number
>   turns a disagreement into a procedure, and the procedure takes the rest of
>   the day. **+8 credits, and the hauler is still there when you leave.**
> - **BOTCHED** — You certify the wrong scale. It is corrected inside the hour,
>   the correction carries your registry, and you return the fee. **−15
>   credits.**
>
> **Take the low quote and haul it yourself** — no check
> - Her cargo, your hold, the cheaper office. She keeps the difference and you
>   keep the work. **+18 credits, −1 hold slot until the next station.**
>
> **Leave them to it** — no check
> - Two offices and a scale each. It will be settled by people who file for a
>   living. *(closes the group)*

*A Sensors failure domain is being wrong, never being hurt. The worst band costs
a fee and a name on a correction.*

---

## OPT-002 · Countersign

```
id       countersign
tags     signal
gate     regions: COSMOPOLITAN · needs_berth
group    berth          (competes with OPT-001)
weight   8
```

**A clerk hails you privately.** She has a document that wants a second signature
and no interest in which berth provides it. She is not offering money. She says
she will remember it, and says it like a woman who does.

> **Sign it** — no check
> - You do not read it closely. That is the arrangement. **+15 credits, and a
>   name at this station that will recognise yours.** *(places `clerk_owes` —
>   see Continuity)*
>
> **Read it first** — *Sensors 4*
> - **MET** — A routine transfer with one clause that is not routine, and the
>   clause is in your favour. You sign, and you know why. **+40 credits, places
>   `clerk_owes`.**
> - **CLEAN** — Routine. You sign. **+15 credits, places `clerk_owes`.**
> - **PARTIAL** — Half of it is in a register you do not read. You sign anyway,
>   which is what she expected, and she notes how long it took. **+15 credits,
>   places `clerk_owes`.**
> - **BOTCHED** — You take long enough that she withdraws it, pleasantly, and
>   files it alone. **nothing.** *(no placement)*
>
> **Decline** — no check
> - She files it alone, which she was always going to have to do. *(closes the
>   group)*

*The reward for signing is not a number — it is the option this places four jumps
deeper. Reading it well pays more now; reading it badly costs the favour, which
is the only real loss here.*

---

## OPT-003 · The cordon

```
id       cordon
tags     fight, signal
gate     regions: LAWLESS · max_security 2 · min_danger 3
group    —              (independent)
weight   12
```

**Someone has strung a picket across the lane** and is charging to let ships
through it. There is no authority here to complain to. That is the entire
business model.

> **Pay it** — hard gate: 60 credits
> - Sixty credits and a wave from a man in a chair. The lane is clear the whole
>   way through, which is the galling part. **−60 credits.**
>
> **Run it** — *Thrust 6*
> - **MET** — You are past the picket before the picket is past discussing it.
>   **nothing spent.**
> - **CLEAN** — They get a burn off. You get through, and the tank shows the
>   sprint. **−14 fuel.** `[S3]`
> - **PARTIAL** — You commit, then take the wide route at speed, which is the
>   expensive one. You are through, and down half a ring's travel. **−26
>   fuel.** `[S3]`
> - **BOTCHED** — You cross the lane twice, both times at full burn, the second
>   time for no reason either of you could name afterwards. **−40 fuel.** `[S3]`
>
> **Break it** — no check
> - **Fight.** They are not expecting a ship that came out here to do this.

*Three options, three failure domains: paying costs credits, running costs fuel,
breaking costs hull. The Thrust ladder never touches hull — a botched burn is a
wasted burn.*

---

## OPT-004 · Salvage rights

```
id       salvage_rights
tags     salvage, contract
gate     regions: LAWLESS, TERRITORY · min_danger 2
group    wreck          (competes with OPT-005)
weight   11
```

**A hull lies open across two claims** and neither claimant is here. Both filings
sit on the local board, dated the same day, each citing the other as the party in
error.

> **Strip it now** — no check
> - You take what is loose and leave before either office establishes which of
>   them was right. **+1 module (rarity rolled at this system's danger).**
>
> **File a third claim** — *Sensors 5*
> - **MET** — Your filing is cleaner than either of theirs and predates the
>   dispute by exactly as long as it took you to write it. The wreck is yours on
>   paper before you touch it. **+1 module, +35 credits.**
> - **CLEAN** — Your claim holds long enough to matter. **+1 module.**
> - **PARTIAL** — The board accepts it and one claimant contests it within the
>   hour. You take what you can carry and draft a reply you will never send.
>   **+45 credits.**
> - **BOTCHED** — You file into the middle of a dispute that now has three
>   parties and a docket number. The fee is not refundable. **−25 credits.**
>
> **Leave it to them** — no check
> - Two claims, one wreck, an office each. *(closes the group)*

---

## OPT-005 · Still under warranty

```
id       still_under_warranty
tags     salvage
gate     regions: LAWLESS, TERRITORY, COSMOPOLITAN · berth includes verity
group    wreck          (competes with OPT-004)
weight   6
```

**The wreck carries a Verity plate**, and Verity plates carry terms. A service
notice is still transmitting on a loop from a hull with no crew, no power and, by
any reasonable reading, no remaining obligations.

> *"COVERAGE CONTINUES. THE HOLDER IS ADVISED THAT COVERAGE IS NOT CONTINGENT
> UPON THE CONTINUED EXISTENCE OF THE HOLDER."*

> **Answer the notice** — no check
> - You transmit your own registry against the loop. Something at the far end of
>   a very long chain accepts it, and the loop stops. **+1 module
>   (Verity-biased), +20 credits, and recovers this system's document if it
>   holds one.**
>
> **Strip it and say nothing** — *Stealth 4*
> - **MET** — You take the plate off first. Whatever the loop was reporting to
>   receives nothing further, ever. **+1 module (Verity-biased), +1 relic if
>   danger ≥ 4.**
> - **CLEAN** — You take the racks and leave the plate where it is. **+1
>   module.**
> - **PARTIAL** — The loop logs a registry on its way past. Yours. You are gone
>   before anything answers, and something will. **+1 module, −20 credits at the
>   next station, quietly, against an account you did not open.**
> - **BOTCHED** — The loop logs your registry, your heading, and the eleven
>   minutes you spent aboard. **+1 module, −45 credits at the next station.**
>
> **Leave it transmitting** — no check
> - It has been saying that for a while. It will keep saying it. *(closes the
>   group)*

*A Stealth failure domain is being SEEN, never being hurt. Both failing bands
cost exposure billed as money, and neither withholds the module — you were always
going to get the racks. The question was whether anyone would know.*

---

## OPT-006 · The long claim

```
id       long_claim
tags     claim
gate     regions: FRONTIER, FAUNA · max_development OUTPOST
group    —              (independent — rim options mostly are)
weight   9
```

**Nobody has filed on this rock** because nobody files out here. It is not rich.
It is not close to anything. It will take most of a day and it will pay for the
day.

> **Work it** — no check
> - Most of a day, one cutting head, and enough off the seam to matter at the
>   next station. **+1 exotic, +30 credits.**
>
> **Work it hard** — *Hull 4*
> - **MET** — You take the seam and the shelf under it, and the frame does not
>   complain once. **+2 exotic, +45 credits.**
> - **CLEAN** — You take more than the seam. Something in the forward bracing
>   makes a noise it has not made before, then stops. **+2 exotic, −3 hull.**
> - **PARTIAL** — The shelf comes away wrong and takes the cutting head with it.
>   You get half of what you came for and you are cutting by hand after that.
>   **+1 exotic, −6 hull.**
> - **BOTCHED** — You are still under the overhang when the overhang decides.
>   **−12 hull.**
>
> **Move on** — no check
> - It has been here a long time. It is in no hurry.

*The rim's job is texture and building your ship, so both working options pay and
neither is exclusive. The Hull ladder costs hull all the way down — the degree
surprises, the kind never does.*

---

## Continuity — the thing batch-01 could not have

`ENCOUNTER_GENERATION.md` §0: **an option is placed on a node, so a consequence
has somewhere to live.** The old contract required every event to resolve within
itself, which is exactly what killed its best writing.

Any signing band of OPT-002 places **OPT-002b** on one COSMOPOLITAN system in a
different ring, one step deeper.

## OPT-002b · She was as good as her word

```
id       clerk_owes
tags     signal
gate     placed by OPT-002 only · never rolled from the pool
group    —              (placed options take a slot, they do not compete)
```

**Your name is on a list here** and it is the good kind of list. A berth office
you have never dealt with is expecting you, and has been for a while.

> **Collect** — no check
> - A fitting bay, no charge, and a clerk who does not explain how she knows the
>   name. **+1 module (dominant manufacturer, rarity rolled), +40 credits.**
>
> **Ask what you signed** — no check
> - She tells you. It is duller than you have spent four jumps imagining, and one
>   clause is still in your favour. **+1 module, +40 credits, and recovers this
>   system's document if it holds one.**

*No check, no failing band, no cost. **This is the payoff for a decision made
four jumps ago**, and taxing it would teach the player not to take the offer next
time.*

---

## What this batch is testing

| | archetype | region | group | check |
| --- | --- | --- | --- | --- |
| 001 | contract | COSMOPOLITAN | berth | Sensors |
| 002 | signal | COSMOPOLITAN | berth | Sensors · **places** |
| 003 | fight/signal | LAWLESS | — | Thrust · **hard gate** |
| 004 | salvage | LAWLESS/TERRITORY | wreck | Sensors |
| 005 | salvage | + manufacturer gate | wreck | Stealth |
| 006 | claim | FRONTIER/FAUNA | — | Hull |
| 002b | signal | placed | — | none |

**Weighted to COSMOPOLITAN and LAWLESS on purpose** — 78% of the galaxy between
them per `ENCOUNTER_GENERATION.md` §2. FAUNA gets a share of one option, because
FAUNA is 3.3% of the galaxy and does not exist past mid-depth.

**Four check attributes across five checks**, so no single build reads every
option. **Every reward is in its declared class** — three modules, all from
salvage or the placed payoff; none from a signal, a claim or a contract.

### Voice notes, for whoever writes the next fifty

- Second person, present tense, **flat about consequences**. The existing
  table's *"Forty units, and most of your paint"* is the register.
- **The declining option is never punished and never blank.** *"The long way.
  Nothing happens on it, which is the point."* Give it a line worth reading.
- **One concrete detail per band**, carrying the tone instead of an adjective. A
  cutting head. Eleven minutes. A man in a chair.
- **Institutions are polite and immovable.** Nobody shouts in this setting. The
  Verity loop is the model: not threatening, just still running.
- **PARTIAL is the most-read band.** Give it its own shape — the wide route, the
  reply you never send, cutting by hand — not a smaller BOTCHED.
- No profanity, no gore, PG-13.

---

# Ported from the event table — OPT-007 to 012

*The six checked events from `EventTable._checked()`, converted verbatim.*

**The event MODEL is retired; the PROSE is not.** These six were written one per
attribute, so every axis on the refit screen has somewhere it gets spent — *an
attribute nothing checks is just a number.* That intent is preserved: they are
still one per attribute, and they are still the best-written bands in the game.

**What changed:** each gained a `gate`, a `group` and a `weight`. Labels, bodies,
bands and check values are **unaltered** — the text below is what is in
`EventTable.gd` today. Their old free-exit option is kept as an ordinary
un-checked row.

**What is deleted with the model:** `EventTable.gd`, `NodeType.EVENT`,
`MapNode.event_key`, the `Rng.derive(&"event")` usage, and `by_key()`'s
title-string identity bug. The eight unchecked events go with it — *Drifting
lifepod* is a 60% coin flip, *Coolant seller* is a shop, and neither survives
contact with a model where a system already offers three other things.

> ⚠ **One bug to fix in the port.** `Ghost signal`'s MET and CLEAN bands set
> `node.visited = true` on unvisited systems in range. That predates the `sensed`
> mark, which landed with `SaveGame VERSION 14`. **`visited` means *you have been
> there*, and setting it falsely is a lie the rest of the game reads** — the
> farming and cleared logic both consult it. The port must set `sensed` instead,
> which is what the band's own prose describes: *systems resolve out of the
> dark.*

---

## OPT-007 · Collapsed lane

```
id       collapsed_lane
tags     signal
gate     regions: LAWLESS, COSMOPOLITAN, TERRITORY · min_development SETTLEMENT
group    —
weight   9
```

**The short way on runs through a shipbreaker's yard** — a lane of dead hulls
packed too close to thread. Going around costs a day and a tank.

> **Push through the wrecks** — *Hull 5*
> - **MET** — Plating screams the length of the lane and holds. You come out the
>   far side with the fuel you did not spend going round. **+10 fuel.** `[S3]`
> - **CLEAN** — Something gives near the bow. You keep going, and you keep the
>   fuel — four hull for ten is a trade you would take again. **−4 hull, +10
>   fuel.** `[S3]`
> - **PARTIAL** — Halfway in, a spar goes through the forward plating. You
>   reverse out of the lane the way you came. **−9 hull.**
> - **BOTCHED** — The lane closes on you. What comes out the other side is your
>   ship, mostly. **−16 hull.**
>
> **Go around** — no check
> - The long way. Nothing happens on it, which is the point.

---

## OPT-008 · Slipping orbit

```
id       slipping_orbit
tags     signal
gate     any region · min_danger 2
group    —
weight   10
```

**A gas giant has you.** Not badly — yet. The gauges give you perhaps four
minutes to decide whether your engines are the answer.

> **Burn out of the well** — *Thrust 6*
> - **MET** — You climb out of it like it was nothing, and clip a derelict's
>   tumbling wing on the way past. Thirty credits of somebody else's bad
>   afternoon. **+30 credits.**
> - **CLEAN** — The engines find it, eventually, and drink fourteen units doing
>   it. **−14 fuel.** `[S3]`
> - **PARTIAL** — You get out. The tank shows what it cost and you decide not to
>   look at it again. **−26 fuel.** `[S3]`
> - **BOTCHED** — You skim the upper atmosphere on the way up. Forty units, and
>   most of your paint. **−40 fuel.** `[S3]`
>
> **Ride it round** — no check
> - One slow orbit, no burn. It costs you nothing but the hour.

---

## OPT-009 · Mine drift

```
id       mine_drift
tags     salvage
gate     regions: LAWLESS, FRONTIER · min_danger 3
group    —
weight   8
```

**Someone seeded this approach and never came back to sweep it.** The mines are
old, patient, and still keeping perfect station.

> **Thread it** — *Maneuver 6*
> - **MET** — You go through the field like water through a grate, and lift a
>   module off the wreck of somebody who did not. **+1 module (rarity rolled at
>   this system's danger).**
> - **CLEAN** — One of them finds your flank on the way out. Only one. **−5
>   hull.**
> - **PARTIAL** — Two, then a third. You reverse the last hundred metres with the
>   hull ringing. **−11 hull.**
> - **BOTCHED** — The old ones are the worst. This one waits until you are past
>   before it decides. **−18 hull.**
>
> **Sweep wide** — no check
> - You give the whole drift a berth and lose nothing but time.

*The module comes from a wreck, which keeps it inside the salvage reward class.*

---

## OPT-010 · The corona

```
id       corona
tags     salvage
gate     any region · min_danger 3
group    —
weight   7
```

**A flare star mid-cycle**, and a wreck sitting inside its corona with the holds
intact. Everyone else has looked at this and left.

> **Go in hot** — *Thermal 6*
> - **MET** — Your vents hold the whole way in and the whole way out.
>   Eighty-five credits out of a hold nobody else would reach. **+85 credits.**
> - **CLEAN** — You come out carrying forty-five credits and a reactor that will
>   need a minute. **+45 credits, +8 heat.**
> - **PARTIAL** — You get one hold open and take what is nearest before the
>   temperature makes the decision for you. **+20 credits, +16 heat.**
> - **BOTCHED** — The flare comes early. You leave with nothing and a ship that
>   is still ticking as it cools. **+26 heat.**
>
> **Watch it burn** — no check
> - You hold station outside the corona and log the wreck for somebody with
>   better vents.

*A Thermal failure domain is heat, all the way down — and after
`HEAT_REWORK.md` §2 that heat now stays until you spend a vent card on it, which
makes this option considerably sharper than it was written to be. **Worth
re-checking the numbers against the new curve** rather than assuming they carry.*

---

## OPT-011 · Ghost signal

```
id       ghost_signal
tags     signal
gate     regions: FRONTIER, FAUNA · max_development OUTPOST
group    —
weight   8
```

**There is a carrier under the background hiss on this bearing.** Too regular to
be a star, too weak to be a station.

> **Resolve it** — *Sensors 4*
> - **MET** — A precursor beacon, still counting. You cannot read it, but you can
>   triangulate off it — *N* systems resolve out of the dark, and the housing is
>   worth twenty-five. **marks every unsensed system in range as `sensed`, +25
>   credits.** ⚠ *`sensed`, not `visited` — see the note above.*
> - **CLEAN** — You pull one clean bearing out of the noise before it drifts. One
>   system, named. **marks one unsensed system in range as `sensed`.**
> - **PARTIAL** — You chase it for an hour and it resolves into your own reactor
>   harmonics, reflected off something you never find. **nothing.**
> - **BOTCHED** — You follow it a long way before admitting it was never there.
>   Twelve units of fuel, spent on a bearing. **−12 fuel.** `[S3]`
>
> **Log it and go** — no check
> - You write the bearing down. Someone with better ears can have it.

*The only option in the pool that pays in **map knowledge**, which makes it worth
more the larger the galaxy gets — and `LAYERS` went 9 → 15. Its weight may want
raising after phase 6 measures it.*

---

## OPT-012 · Customs cordon

```
id       customs_cordon
tags     signal, fight
gate     regions: TERRITORY, COSMOPOLITAN · min_security 3
group    —
weight   10
```

**A revenue cutter is running a cordon across the only lane out**, and they are
stopping everyone.

> **Run the cordon dark** — *Stealth 4*
> - **MET** — You go through cold and silent, close enough to read their hull
>   number. They never look up. **nothing.**
> - **CLEAN** — You hold everything off but the reactor, and the reactor is what
>   you pay with. Six heat, no questions. **+6 heat.**
> - **PARTIAL** — They get a partial return and hail you in. The fine is forty
>   credits and a lecture. **−40 credits.**
> - **BOTCHED** — They light you up from two sides, and something in the cutter's
>   escort decides you are worth the trouble. **−40 credits, fight.**
>
> **Submit to inspection** — no check
> - You stop, open the holds, and answer everything twice. It costs an afternoon
>   and nothing else.

*Deliberately the lawful mirror of **OPT-003 The cordon**, and they can never
co-occur: OPT-003 gates `max_security 2`, this gates `min_security 3`. Same
obstacle, opposite side of the law, and which one a system offers says what kind
of place it is.*

*The BOTCHED band stacks credits **and** combat entry — permitted, because the
pile-on guard covers two of {hull damage, malfunction, combat entry} and a fine
is none of those.*

---

## Pool after the port

| | count |
| --- | --- |
| batch-02 originals (OPT-001–006) | 6 |
| placed continuity (OPT-002b) | 1 |
| ported from the event table (OPT-007–012) | 6 |
| **total authored** | **13** |
| retired unchecked events | 8 |

**Attribute coverage is complete**: Hull ×2, Thrust ×2, Sensors ×3, Stealth ×2,
Maneuver ×1, Thermal ×1. The two thin ones are Maneuver and Thermal, which is
where the next batch should start.

**Region coverage**, against the distribution in `ENCOUNTER_GENERATION.md` §2:

| region | share of galaxy | options gated to it |
| --- | --- | --- |
| COSMOPOLITAN | 46.7% | 5 |
| LAWLESS | 31.3% | 5 |
| TERRITORY | 11.1% | 4 |
| FRONTIER | 7.6% | 3 |
| FAUNA | 3.3% | 2 |

Roughly proportional, which is the point. **Thirteen is still far short of the
60–100 the pool wants** — see `ENCOUNTER_GENERATION.md` §5. It is enough to
build and measure phase 6 against, and not enough to ship.
