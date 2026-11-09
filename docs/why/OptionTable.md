The reasoning behind `tkg/scripts/systems/OptionTable.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Option shape

Above `static var _all: Array[Dictionary] = []`:

````text
What a system holds, and the rules for picking it.

`ENCOUNTER_REBUILD.md` §4–§5. A system rolls 2–4 of these on arrival; each one
is a SITUATION with its own choices inside it, and the chart never says what
they are.

NESTED RATHER THAN FLAT, ruled 2026-08-26. §4 of that brief specifies a flat
option -- one label, one resolution -- and all thirteen authored options in
`batch-02-draft.md` are written the other way: a title, shared prose, and two
or three lines to take. Flattening them would turn 13 into ~33, repeat the
prose on every line, and lose the thing `group` is for -- the authored groups
pair WHOLE situations ("salvage_rights competes with still_under_warranty"),
not individual lines.

`EventTable` WAS DELETED 2026-08-27, its last seven entries ported here. It is
named below because it is why this shape is what it is, not because you can go
and read it.

So the shape is that `EventTable` entry plus four fields: `id`, gating,
`group`, `weight`. That is also why the port is cheap -- OPT-007 to 012 are
literally existing events with a header written on them.

```gdscript
{
    id = &"salvage_rights",          # stable identity, never the title
    title = "Salvage rights",
    body = "A hull lies open across two claims...",
    tags = [&"salvage", &"contract"],
    group = &"wreck",                # &"" is independent
    weight = 11,
    regions = [MapGen.Region.LAWLESS], min_danger = 2,   # gating, all ANDed
    choices = [ {label, label_at?, check?, stay?, effect|met/clean/partial/botched}, ... ],
    subject = {stage = &"tether", pieces = [&"...tank_1"], count = 6},   # optional
}
```

`subject` IS WHAT LOCAL SHOWS while the event is open there (`LocalSubject`):
kept pieces of art from `art/subjects/index.json` and how they are staged --
one thing, a row, a tether, a field, a herd, a line, round a body, on a rock --
with the counts the text gives ("six fuel tanks on a tether", "nine of them in
a line"). Optional: an encounter without one keeps the scene as it is. Filled
from the subjects audit (scratchpad `local_role/subjects.md`) wherever the
subject has art Jon kept; the rest wait for theirs.
Ships are named by what they are, not which picture: `role:hauler` is one of
Jon's kept pool ships that serve as haulers, the same one for this encounter
every time; `foe` is the ship the event's fight would bring, so the scene
before a fight hands over to the fight's own ship.

`foe = &"whale"` (or `&"leviathan"`) IS WHAT THE EVENT'S FIGHT BRINGS, when it
is a creature: the one named, every time (`fight_foe`, `Router.option_foe`).
With no `foe` an event's fight brings a ship off the ordinary pool, never a
creature. Jon, Oct 17: an event's fight may bring megafauna, "but the text
leading up to the fight should make sense" -- so the creature is a property
of the TEXT, declared by the author beside it, and never rolled from the
region: a whale cannot follow a body about pirates, and a ship cannot follow
one about a whale. A creature event names its creature (a calf is not a
leviathan), is fauna-gated (`needs_fauna`), and pays what animals pay: the
body's exotic in its wreck, never credits off the animal. A choice may carry
its own `foe`, which wins over the option's. `-- sheet=FoeTagTest` holds it.

`stay = true` MARKS A WALK-AWAY: a choice that rolls nothing, costs nothing
and pays nothing — "Leave it", "Decline", "Pass". The sector shows its prose
and does NOT mark the option resolved, so declining a thing leaves it there
to come back to. It is a declaration, not a detection, because only the
author knows whether "she goes to ask the next ship" means the encounter is
narratively spent — a choice whose effect changes anything must never carry
it.

IDENTITY IS THE `id`, NEVER THE TITLE. `EventTable.by_key()` matches on
`str(e.title)`, so renaming "Whale fall" invalidates every save that rolled
it. That is not carried forward: the title is copy and the id is a key.
````

## Static option table

Above `static var _all: Array[Dictionary] = []`:

```text
Every option in the game.

STATIC AND BUILT ONCE. `EventTable.build_all()` reconstructs fourteen
dictionaries and every closure inside them on each call, including from
`by_key()`, which then linear-searches. At ~290 systems each rolling its own
list that pattern stops being merely wasteful -- `ENCOUNTER_REBUILD.md` §5a
says so in as many words.
```

## Depth pay scale

Above `const PAY_SCALE: Array[float] = [0.0, 1.0, 1.8, 3.0, 4.7, 7.2]`:

```text
HOW MUCH DEEPER IS WORTH, as a multiple of the same thing on the rim.

MEASURED FIRST, and the measurement is why this exists. With every payout a
literal, the ladder came out FLAT: average credits per tier read 50, 50, 49,
52, 56 from EASY to LETHAL, and the top prize was 190 at every tier including
the first. Hull cost was flat from HARD up, and BRUTAL cost LESS than HARD.
Depth controlled which encounters you met and nothing about what they were
worth.

It could not have been otherwise. THIRTY-ONE of forty-seven encounters span
three tiers and four span all five, so one literal has to serve danger 3 and
danger 8 at once. Narrowing every band would have worked and would have cost
the table most of its range; scaling the number costs nothing.

The author writes what a thing is worth ON THE RIM and the tier multiplies
it. `pay(30)` is thirty credits at EASY and two hundred and sixteen at
LETHAL.

SAFE FOR THE PROSE, and that was checked before a line of this was written:
of 207 outcome texts, ZERO quote a credit sum and only twenty contain a digit
at all -- those count hours and racks, not money. The ledger rail under the
result already prints what actually moved. So the words never have to agree
with a figure, and the rule going forward is that they never may.
```

Above `const TOLL_SCALE: Array[float] = [0.0, 1.0, 1.9, 3.0, 4.3, 5.8]`:

```text
Hull is the currency depth is bought with, and it climbs less steeply than
the reward on purpose -- 5.8x against 7.2x. A ladder where the cost outruns
the prize is a ladder nobody climbs twice.
```

## Purse naming

Above `static func purse(base: int) -> int:`:

```text
What a rim-priced reward is worth here.

NOT `pay`. That name was already taken by the function that turns a resolved
outcome into the REWARD line -- a different job entirely, and the collision
was a parse error rather than a silent shadow only because GDScript refuses
two functions of one name.

AND FOR THE PARTY (Jon, Nov 5: "loot pools are increased as the playercount
increases"): an n-player game pays `PartyScale.loot(n)` of it, so a party
that splits the galaxy's events evenly is each paid what a lone pilot is.
```

## Option gating

Above `static func admits(o: Dictionary, n: MapGen.MapNode) -> bool:`:

```text
Does this option's gating admit this system?

Every clause is optional and they are ANDed. All seven axes already exist on
`MapNode` and are richly generated -- and `EventTable.pick_key()` reads none
of them, which is most of why fourteen events feel same-y: a whale fall can
surface in the core, a customs cordon in unclaimed space.
```

## Silent gate failure

Inside `admits()`, above `if o.has("max_development") and int(n.development) > int(o.max_development):`:

```text
A CEILING AS WELL AS A FLOOR, added for batch 04. `long_claim` is a seam
nobody works "because hauling ore back costs more than the ore" -- that is
false at a city and the option would have been lying wherever it landed.

Worth noting how it would have failed: `admits` ignores keys it does not
know, so an option carrying an unimplemented gate is not rejected loudly.
It simply appears everywhere. A gate that silently does nothing is worse
than one that does not exist, because the content reads as if it were
placed.
```

Inside `admits()`, above `if o.has("needs_star") and int(n.star) != int(o.needs_star):`:

```text
WHAT IS ACTUALLY IN THE SKY. These four options describe a specific thing
overhead -- a star throwing tantrums, a gas giant with you in its well, a
pulsar sweeping the arc -- and had `min_danger` for a gate, which says
"deep enough that it is plausible" and nothing more. `the_sweep` could
land on a system with no pulsar within reach and the prose simply lied.

The header above says it: a gate that silently does nothing is worse than
one that does not exist, because the content reads as if it were placed.
These were the four where that was true.
```

## Derelict frame

Above `static func derelict_frame(n: MapGen.MapNode) -> HullData:`:

```text
THE DERELICT HAULER'S FRAME, rolled where it lies.

It was rolled off the loot stream when you claimed it, so the choice could
not say what it was. Jeremy (friends' alpha) flew a heavy ship, claimed the
hull, got a light frame he did not want, and had given up "Strip it for
scrap" for it. Rolled from the system instead (`Rng.derive`), it is the same
frame on every visit and for every ship in a party, nothing else moves it,
and the label can name its weight before you choose (`derelict_hauler`).
```

## Tier plan counts

Above `const TIER_PLAN := {`:

```text
How many options a system of this tier holds, and how many share a group.

`ENCOUNTER_REBUILD.md` §4. COUNTS STAY FLAT and only the grouping moves --
the galaxy already applies a depth gradient through `ring_count`, and applying
it twice compounds. Depth changes what the options cost you and how many you
must give up, not how many there are.
```

## Paying outcomes

Above `static func foreclose(n: MapGen.MapNode, i: int) -> void:`:

```text
Hand over everything an outcome promised, and say what arrived.

ONE PLACE, BECAUSE THREE WAS ALREADY ONE TOO MANY. An outcome dictionary is
paid in three unrelated files -- `Policy` for the sim, `SectorScreen` for a row
that resolves in place, `EventScreen` for one that opened the detail view --
and each held its own copy of the same two lines. They had already drifted:
`EventScreen` never learned about `module`, so `salvage_rights` paid nothing
through the only path it can actually be taken by. Nothing failed; the reward
simply did not arrive.

Batch 04 adds four more payload forms. Four forms across three hand-maintained
sites is twelve chances to repeat that, so the sites now call this instead.

`fight` is deliberately NOT handled here: it is the CALLER's business, because
starting a battle means something different in a sim than on a screen. This
function grants; it does not decide what happens next.
Close everything the option at `i` shares a group with.

RULING 1's other half. The list shows what a choice forecloses; this is the
foreclosing. A closed option is marked `taken` so nothing offers it again AND
given `R_GONE`, so the card can say UNAVAILABLE rather than quietly not
being there -- which is the difference between a rule and a disappearance.
```

## Reward display

Above `static func pays_item(res: Dictionary) -> bool:`:

```text
Whether this outcome's payload asks for a rolled MODULE (`module = true`),
which `pay` puts on the system's pile.

NOT WHETHER THE RESULT SHOWS REWARD, though it used to be. It was the one
question the screens asked, and a part is not the only thing that lands on
the pile: `material` and `material_id` are put there by `MaterialTable.grant`,
and an effect that calls `Run.add_material` itself (`whale_fall`) puts them
there with no key at all. Every one of those results said CONTINUE, dropped,
and left the crate under SECTOR LOOT with nothing on the result to say so
(Jon, Oct 22: "some quests don't show REWARD... that's super NOT
intuitive"). The screens now ask what actually arrived on the pile
(`OptionResolve.shows_reward`), which no payload form can slip past.
```

## Pay into the system

Inside `pay()`, above `Run.sector_jetsam(n).items.append(LootGen.roll_module(n.danger))`:

```text
INTO THE SYSTEM, NOT INTO YOUR POCKET. `MATERIALS_NOTE` 3.6: if
something hands you a physical thing it hands you a CONTAINER, and you
reach in for it with your own hold open beside you.

It was `Run.place_in_hold(...)` with the result thrown away, which
meant a reward you had earned quietly ceased to exist whenever the
hold was full -- 3.4's exact failure, in the one place where the game
is supposed to be paying you. A bag cannot fail that way: it sits in
the system until you take it or you jump, and if there is no room you
can see there is no room and decide what leaves.
NOT `n.bagged`. That flag means "the kill bag here has been rolled"
and `open_bag` refuses to fill a node that has it -- so an option
setting it would silently rob the next fight in this system of its
entire payout. An option cannot be taken twice anyway; `n.taken` is
what stops that.
THE FLOOR, not a wreck: nothing died to produce this, so it lands in
the system's own pile beside anything you have put down here.
One more for each player past the first (`PartyScale`, Jon, Nov 5),
as the event's money is.
```

## Material consumption ruling

Inside `pay()`, above `if res.has("consume_material_tier"):`:

```text
NOTHING USES THIS, AND THAT IS A RULING RATHER THAN AN ACCIDENT.

`holding_pattern` was the only caller. `spend_material_tier` takes the FIRST
item of that tier it finds in the hold, so the encounter reached in and chose
for you -- tolerable while materials were a ledger counter, indefensible now
they are objects with names, values and cells. THE HOLD IS THE PLAYER'S.

The mechanism stays because a future encounter might legitimately want to
take something NAMED that the player has already agreed to hand over. It must
not be used to take a tier and let the code pick.
```

## Rolling early

Inside `system_has_tag()`, above `ensure(n)`:

```text
ROLLS THE SYSTEM IF IT HAS NOT BEEN ROLLED, and the hellbender needs that:
it scans the whole map, so most systems it cares about are ones nobody has
flown to. (A contract board asked too, for a hunt's fight, until a hunt
brought its own target -- `Contracts.post_goal`.)
Reading `n.options` raw would have answered "no fight anywhere", which is
how the hunt contract stopped being findable.

Safe because the answer does not depend on WHEN it is asked. `admits` gates
on node properties only -- danger, security, development, region, fauna,
berths, all fixed at map generation -- and the draw is positional, which is
what `-- optiontest`'s "the same system always rolls the same options" is
there to prove. Rolling early writes the list the arrival would have
written, so the anti-save-scum contract in `_roll_here` is untouched: it is
still decided once and still written before the autosave.
```

## Placing options ahead

Above `const PLACE_DEPTH := 3`:

```text
Put an option on a system ahead of this one, and say which.

THE MECHANISM IS AN ARRAY APPEND. A system's encounters are `MapNode.options`
and nothing else, so a consequence that travels is one id written onto a node
you have not reached. It saves for free -- `options` is already in the file --
and it survives a jump for the same reason the wrecks do: it is node state.

THE TARGET IS DERIVED, NOT CHOSEN, and that is what makes this work in co-op
without a single packet. `roll_for`'s note says options are positional
because "what is AT a place is a property of the place and four machines must
agree about it" -- a placement is NOT a property of the place, it is a
consequence of what one ship did elsewhere, so it would have had to be
replicated. Deriving the target from the SOURCE node's index instead makes it
a property of the place after all: every machine that resolves the same
option at the same system computes the same target and nobody has to be told.

`ensure` FIRST, and this is the trap. It rolls a system's own options only
when the list is EMPTY -- so appending to a system that has not been visited
yet would leave it non-empty forever, and you would arrive at a place
offering the quest and nothing else. Rolling it before appending is one line
and the difference between a working thread and a content bug that surfaces
months later.

Returns the node index it landed on, or -1 if there was nowhere: near the
core there may be no unvisited system deep enough, and a thread that never
pays off is better than one that pays off in the wrong place.

AND IT IS WRITTEN DOWN (`Run.note_placed`): the system, the option and `src`,
the option that placed it, so the QUESTS table can say who gave it. Only on
the machine that took the event, which is the ship it belongs to: nothing
here goes to the party.
```

## Quests stand alone

Inside `place()`, above `if StringName(what.get("group", &"")) != &"":`:

```text
A QUEST STANDS ALONE. An exclusive set is a choice between things that are
both there for you to weigh; a placed payoff is the consequence of
something you already did, and putting it in a group means the system it
lands on can foreclose it with an option that has nothing to do with the
thread. You would lose the delivery by bidding at an auction.

Refused rather than stripped: a grouped quest is an authoring mistake, and
quietly ungrouping it here would hide the mistake in a place nobody looks.
```

## Placed id cache

Above `static var _placed: Dictionary = {}`:

```text
Does this system hold a placed encounter nobody has taken yet? The chart asks,
to know whether to mark it.
THE IDS THAT CAN ONLY BE PLACED, as a set, built once.

`holds_quest` is asked of every system on the chart on every mouse-motion
frame, and `by_id` is a linear walk of the whole table -- a hundred and ninety
systems times three options times fifty rows is thirty thousand comparisons a
frame for an answer that changes about twice a run. `_draw_work` solved the
same problem by caching in the view; this fixes it at the source instead, so
nothing downstream has to know it was ever expensive.
```

## Ship-owned options

Above `static func is_mine(id: StringName) -> bool:`:

```text
WHETHER THIS OPTION IS ONE SHIP'S OWN: a signed contract's work (`is_job`)
or an event quest (`placed_ids`, what `place` put on this ship's map for
what this ship did). Neither is on a partner's map, so neither is raced for
over the wire (`OptionResolve.take`, `Router.claim_open_option`), and a
partner's claim on the same slot index never closes it
(`RunState.adopt_party_claims`): the slot is theirs, not this.

It was jobs only, and a taken PAID IN FULL went to the party as a claim on
(system, slot), which a partner's machine wrote into its own copy of that
system whatever sat there: their contract pickup or their own quest at the
same index came up already taken (Oct 22).
```

## Positional roll

Above `static func roll_for(n: MapGen.MapNode) -> Array[StringName]:`:

```text
What this system holds. Ids only -- callables are never built here.

POSITIONAL, off `Rng.derive(&"options", n.index)`, because what is AT a place
is a property of the place and four machines in a co-op session must agree
about it. What happens TO you comes off a seat-salted stream instead; the
ambush roll is that and this is not.

Drawn without replacement so a system never offers the same situation twice.

SCIENCE IS DRAWN APART (Phase 12). The main draw never sees a science event,
so its pool, its stream and its list are exactly what they were before there
was science. Then a pass of its own, off `Rng.derive(&"science", n.index)`,
gives the system one science event at `SCIENCE_SHARE` a slot, in place of one
of the slots drawn. So a system holds one at most, and a system the pass
misses holds exactly the list it held before. Skipped under `Run.science_off`
(`-- sim science=off`, the control cell), which then rolls main's world.
```

## Ensure and quiet start

Above `static func ensure(n: MapGen.MapNode) -> bool:`:

```text
Roll this system's list if it has none, and answer whether it has one.

THE SAME DECISION IN ONE PLACE. `Router._roll_here` rolls on arrival for a
played run and the headless simulator never goes through Router at all, so
without this the two would each carry a copy of "which nodes get options"
and drift the first time either changed.

Stations are excluded because a station IS its option list -- the shelf, the
rack, repair and fuel -- and it is the one node the chart telegraphs. The core
is excluded because it is a hand-authored boss.

AND THE START IS QUIET ON PURPOSE. A run opens on a system with nothing in it,
so the first thing a player does is read the chart rather than resolve an
encounter -- which matters more now that sight is live and most of the map is
dark. It is also the one arrival nobody chose, and asking someone to spend a
decision before they have seen the galaxy is asking them to guess.
```

## Authored options scope

Above `static func _authored() -> Array[Dictionary]:`:

```text
The options themselves, ported from `docs/briefs/batch-02-draft.md`.

THE MACHINE, NOT THE CONTENT. `ROADMAP.md` §11 puts authoring the pool out of
scope for this phase -- `ENCOUNTER_GENERATION.md` is how it gets filled, and
that is its own job with its own volume problem. What is here is enough to
exercise gating, grouping, weighting and the tier plan honestly.
```

## Quest table row

Inside `_authored()`, above `quest = {task = "Deliver the runner's parcel", tag = "DELIVER", from = &"the_runner",`:

```text
ITS ROW IN THE QUESTS TABLE (`QuestLog`): the task beside the
signed jobs' tasks, the chart tag's word, and the note, which is
the runner's own line from `the_runner`'s body, word for word
(`-- sheet=QuestLogTest` holds it there). `from` is the event that
places it, for a save written before the run kept that
(`Run.event_quests`).
```

## Fuel price

Inside `_authored()`, above `{label = "Buy fuel at her rates", cost_credits = 4, effect = func() -> Dictionary:`:

```text
4 for 6 units, so "the cheapest in the galaxy" is true: a
capital's REFUEL is 24 for 25, about 1 a unit (fuel:A, Oct 18).
It was 30 for 6, five a unit, dearer than any dock.
```

## Named plus rolled payout

Inside `_authored()`, above `return {text = "Years of heat and cold have welded the housing to its frame, and the cutter cannot free it in time. You take the readings instead: the interval, the bearing and the decay curve, shot onto film straight off the dish. You also take something the cutter shook loose.", material_id = &"survey_film", material = &"wreck"},`:

```text
NAMED FOR THE STORY, ROLLED FOR THE SCALE, and a branch this
deep wants both. `survey_film` is the readings and is worth
35 whatever the danger -- a named material has a FIXED value
and is the one kind of payout the tier ladder cannot reach.
Alone it made a LETHAL partial pay less than an EASY
success. The rolled wreck material beside it goes through
`MaterialTable.roll(table, danger)`, which grades, so the
depth is paid for by the half of the haul that can be.
```

## Fight declaration

Inside `_authored()`, above `{label = "Engage", fight = true, effect = func() -> Dictionary:`:

```text
TWO STATEMENTS, NOT ONE, and collapsing them broke RULING 5.

`fight` in the RETURNED dictionary is the TRIGGER: it is what
`EventScreen._choose` reads to start the fight, and it is how
EventTable's two hostile endings have always worked. It is only
knowable by running the callable.

`fight` on the CHOICE is a DECLARATION: this row leads to a
fight. The sector list has to print a contact reading BEFORE the
click, so it needs an answer that does not require resolving the
option first. Removing it made every hostile row print nothing.

An outcome may still open a fight the choice did not declare --
that is a twist, and it is why the trigger is the runtime one.
```

## Creature events

Inside `_authored()`, above `{`:

```text
THE CREATURE EVENTS (Jon, Oct 17): an event's fight may bring a creature
when the text before it is about that creature. Each one names the one
it brings (`foe`, read by `fight_foe`), is fauna-gated, and pays what
animals pay: hide and fauna rolls on the quiet branches, the body's
exotic in its wreck after the fight, credits only from people.
```
