The reasoning behind `tkg/scripts/systems/Combat.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Combat rulings

Above `class ChargingCard extends RefCounted:`:

```text
Turn-based ship combat. Slay the Spire grammar: telegraphed enemy intent,
energy as the only cost you pay, heat as a printed byproduct.

Key rulings baked in here (learned the hard way in the web prototype):
 * Charge fires automatically when ready.
 * Overheat = predictable self-damage, no cliff, no cap on heat.
 * The deck ONLY reshuffles at the start of your turn. Without this,
   zero-cost draw cards loop forever once the discard recycles.
 * Your attacks never miss; enemies have no dodge.
```

## Miniboss escape

Above `if template.miniboss and hp > 0 \`:

```text
A miniboss on the ropes stops fighting and starts leaving. One full
player turn of warning — the intent IS the telegraph — and if it acts
on it, the fight ends with the enemy gone rather than dead. The
threshold check lives here, at the moment the next move is chosen,
so burst damage past it mid-turn still kills: the escape can only
happen on the enemy's own clock.
```

## Resolving card

Above `var resolving: CardData = null`:

```text
The card resolving right now, or null (a drone, feedback, a partner's shot).
Presentation only: the screen reads it on `combat_hit` to draw the shot as
the weapon that fired it. It used to read the last `card_played`, which is
emitted AFTER the card resolves, so every shot was drawn as the card before
it (audit item 7).
```

## Node clearing

Above `var clears_node: bool = true`:

```text
Whether winning consumes the system. True for the contact a node was
generated holding; FALSE for an ambush, which is something that followed you
to a station rather than the reason the station is there. Without it, killing
whatever jumped you on the approach would mark the dock resolved and you
would fly away from a shop you never opened.
```

## Shared fight

Above `var shared: SharedFight = null`:

```text
The party's copy of the enemy, when more than one ship is in this fight.
Null in the solo game, in every headless sim, and in a party of one — and
everything below falls back to the fight the game has always had.

THE ENEMY IS THE ONLY SHARED THING. Your deck, hand, energy, block, brace,
heat and hull stay exactly where they are, in `Run` and in this object, on
your own machine. No other player targets them, spends them or reads them, so
nothing about them has to cross. That asymmetry is why joint combat fits in
one field here instead of a rewrite of this file.
```

## Planned but not begun

Above `var asking_at: int = -1`:

```text
THE SYSTEM THIS FIGHT IS ASKING THE PARTY ABOUT, or -1 (review, Nov 5).
`Router.start_combat` plans the fight, sets this, and waits for the host's
answer before `begin`. With no time limit on that wait, a fight planned but
not begun is a real state: no hand, and END TURN, FLEE, HAIL and every card
are refused in it. END TURN there ran a private enemy turn the answer then
undid, and a flee left a ship the late answer seated for good.
```

## Plan then begin

Above `func plan(template: EnemyTemplate, danger: int, extras: Array = []) -> void:`:

```text
Build the fight without starting it.

Split out of start() because a shared fight has to be opened with numbers
this function produces — the host is told what a frigate is worth rather than
working it out again, so danger scaling, the boss exemption and the pack
split stay in `_spawn` where they have always been. Router calls plan(), asks
the party, then calls begin().
```

## Party answer wins

Above `func begin(f: SharedFight) -> void:`:

```text
Open the first turn. `f` is the party's copy of the enemy, or null for the
fight the game has always had.

THE PARTY'S ANSWER IS THE FIGHT, whatever this ship planned (the same-second
race, Nov 5). One fight per system, and a ship that planned Y can be handed
X, opened by a partner whose push had not reached it yet. It used to paint
X's numbers on Y's hulls: Y's attack names, Y's swings, a hull nobody else
had that kept the kill from ever coming. So when the ids differ the enemy is
built again from the fight's (`replan_foes`), here, before anything is
dealt or drawn: the screen builds its enemy slots on `combat_started`.

AND A FIGHT ALREADY OVER (review, Nov 5): the host can seat this ship and
take the last hull in one frame, so the answer arrives finished, and no push
follows it. A ship in the crew at the kill was counted in `paid`, so it goes
to the win, as `_on_fight_changed` would have sent it.
```

## Enemy picture

Above `func look_for(i: int) -> int:`:

```text
WHICH PICTURE the `i`th ship of this fight wears, out of its kind's few.

POSITIONAL, never a fresh roll, for the same reason wreck loot is
(`Rng.derive`, keyed by the system and by how many wrecks it already holds):
every machine in a party draws the same ship without a byte on the wire, a
second fight at the same system can bring a different one, and the number
goes into the wreck so LOCAL shows the hull the fight did. A raw draw;
`DB.enemy_sprite` wraps it to however many pictures the kind has.
```

## Enemy spawn scaling

Above `func _spawn(template: EnemyTemplate, danger: int, hp_share: float = 1.0, pick: bool = true) -> EnemyState:`:

```text
Builds one enemy at this danger. Bosses are hand-tuned, never scaled by
danger. HP scales faster than damage so deeper fights are longer rather than
lethal. A hand-tuned enemy may grow with the run instead: its hull is
`EnemyTemplate.hull_at(Run.custodian_jumps())`, read here as the fight is
built, which today is only the Custodian (Jon, Nov 3, G3 capped at twice its
hull). The count is your jumps alone, the lead ship's in co-op (Jon, Nov 4),
so one line covers the opener, a joiner's local build before the host's
numbers arrive, a fight alone when the party does not answer, and a party
that has dropped. The template is never written, so nothing carries from one
run to the next.
`pick` false builds it with no intent rolled, its first listed one standing
in until the party's fight names it (`replan_foes`).
```

## No reinforcements

Above `func alive() -> Array[EnemyState]:`:

```text
NOTHING JOINS A FIGHT (Jon, Oct 13: "No reinforcements anywhere."). A fight
is the ships it was planned with (`plan`: the contact and its pack, or the
dev flag's `foes=`) and only ever loses them. There was a wave: one roll on
turn 3, solo, danger 3 and up, 10% (25% lawless), a fresh ship at three
quarters' hull. It went, and with it the only way a third ship reached the
screen in play.
```

## No end-of-turn heat shed

Inside `end_turn()`, above `if Run.heat > Run.heat_cap():`:

```text
NO END-OF-TURN SHED, and this is where it used to be. It was one point --
dissipation runs 2/1/1 across light, medium and heavy -- against card heat
of 1 to 6 with two or three cards a turn. Too small to plan around and too
present to ignore: it printed a line, nudged the gauge and asked for
arithmetic every turn for a change that never altered a decision.

It was also why the interesting half of heat was never built. `heat_scale`
appears on one card of 149, `damage_equals_heat` on one, `brace_from_heat`
on one. Those cards want heat HIGH, and automatic cooling worked against
them every turn in a direction the player could not switch off.

Dissipation now multiplies venting instead -- see CardResolver. In a fight
you generate faster than any radiator sheds, so heat comes off only when
you deliberately dump it; between systems you drift, which is
`cool_in_transit`.

REMOVING IT MOVES THE OVERHEAT CHECK ONE STEP CLOSER to the heat you just
generated, which is the intended effect: the burn now measures what you
did rather than what survived a free refund. Do not compensate by
softening overheat -- it is deliberately a linear 1:1 hull burn with no
cliff and no cap, and Solari's 5-set halving it is a set bonus that should
stay worth having.
```

## Pacifying fauna

Inside `end_turn()`, above `if enemy.template.fauna and peaceful_turns >= 2 and not is_shared():`:

```text
Not every fight wants fighting.

Solo only. Pacifying is a claim about how the WHOLE room behaved for two
turns, and this object only knows what one ship did — three players
shooting while a fourth sits still is not a pod being left alone. Making
it work in a party means the host counting quiet turns per ship, which is
a real feature rather than a guard, so it is off rather than wrong.
```

## Block expiry

Inside `end_turn()`, above `block = 0`:

```text
AFTER the enemy swings, not before.

This line used to sit above _enemy_act(), which zeroed the player's block
on the way into the one function that spends it — so every Block card in
the game bought exactly nothing, silently, for as long as the field has
existed. CardData has said "decays at end of enemy turn" the whole time;
the code was clearing it at the start of one.

Brace was unaffected, which is what hid it: the defensive cards that
obviously worked were the ones that used the other field.
```

Inside `_act_one()`, above `if not is_shared():`:

```text
LAST TURN'S BLOCK EXPIRES AS IT ACTS AGAIN, and not a moment sooner.

This line used to sit at the END of this function, after `e.block +=
I.block` -- so every "Gain N block" turn granted block and took it away
in the same call, and the player's next turn met a hull with none. The
intent lied and the chip never appeared (combat polish audit, item 3).
It is the player-Block bug from August mirrored onto the enemy: block
exists to be spent during the OTHER side's turn, so it has to survive
into it. Solo only, as before: in a shared fight the host owns block.
```

## Dead ship returns no fire

Inside `_act_one()`, above `if feedback > 0 and not Run.dead:`:

```text
A SHIP THAT IS GONE RETURNS NO FIRE. Feedback ran before the death
check, so a hit that killed you could still kill the Custodian on
the way back: `Run.win()` on a dead ship, the run ended as a death
and a win at once (5 runs in about 5,000 of the Oct 29 sims).
`-- sheet=PlayerDeathTest` holds it.
```

## Default choice

Above `func best_choice() -> int:`:

```text
Pick one of the cards a discard or a decommission is waiting on.

Deliberately NOT "the player clicked" — it takes an index into the hand, so
the simulator and the bot reach it the same way the screen does. A choice
only a mouse can make is a choice `Policy` cannot play around.
What to pick when nobody is looking — the simulator, the bot, or a turn that
ended with a choice still open.

JUNK FIRST, then whatever costs the most energy. It is the answer a person
would give: unplayable cards are the reason these verbs exist, and past that
the card you are least likely to be able to afford is the one you can most
afford to lose. Deliberately not random — `Policy` is the number the gate
reports before every merge, and a coin flip inside it makes that number noisy
for a reason that has nothing to do with balance.
```

## Card output preview

Above `func card_output(c: CardData) -> int:`:

```text
What this card would actually land, right now, after the enemy's block and
brace. Mirrors CardResolver's attack maths without mutating anything — if the
two ever drift, the number on screen becomes a lie, so keep them together.
WHAT ONE HIT OF THIS CARD THROWS, before anybody's mitigation.

The face's number, and the reason it is a separate function from
`preview_damage`: that one folds in THE TARGET'S block and brace, so with
several enemies on the board it has no single right answer for a card sitting
in your hand -- the same card reads 12 against one and 4 against another. What
the card will THROW is true regardless of who it is pointed at.

`preview_damage` calls this and then spends a copy of the target's mitigation
over `hits`. One chain, two readings; a second copy of this arithmetic is
exactly the drift DOC_RECONCILIATION.md exists to clean up.

PER HIT, NOT PER CARD. `hits` is already drawn structurally on the face, and
per-hit is the figure the modifiers actually move: lock-on adds to `per`, so
on a three-hit card it is worth three times as much, which is the thing the
card should be teaching.
```

## Card hot clauses

Above `func card_hot(c: CardData) -> PackedStringArray:`:

```text
WHICH OF THIS CARD'S OWN CLAUSES ARE PAYING RIGHT NOW, by keyword.

`card_output` returns one number and the face needs to say what moved it.
Colouring every modifier clause the moment the number is up would be a lie
the one time it matters: a card raised purely by lock-on would light its
SALVO clause, teaching the player the wrong rule about the mechanic they are
looking at. So this reports only the clauses that are actually contributing,
and lock-on is deliberately absent -- it is not a clause on the card, it is a
thing on the ship, and the ship's status row already carries it.
```

## Shared hits

Inside `damage_enemy()`, above `Net.hurt_foe(shared_at, which, amount, hits)`:

```text
Applied locally AND sent. Locally so that your own card reads exactly
as it does alone — you played it, you see the number, there is no
round trip between the click and the hit. Sent because the host owns
the hull: its push arrives a moment later and overwrites hp, block and
brace with the answer that counts, which is how two ships firing in
the same instant end up agreeing about what is left.

The RAW amount goes, not `total`. The host redoes the mitigation
itself against the block it actually has, because the copy this
machine just spent may already have been spent by somebody else.
```

## Flee cost

Above `const FLEE_FUEL := 1`:

```text
What breaking contact costs. Read by the confirmation prompt too, so the
warning cannot drift from the charge.

1 of a 45 tank (Jon, Oct 17: "flee:A"). It was 6 of 279; scaled with the
events, and taken through the same floor (`Run.drain_fuel`), so a burn out
of a fight leaves the fuel to reach a dock in sight and cannot strand you.
```

## Hail rules

Above `var struck := false`:

```text
What a hail is checked against, and how hard.

STEALTH, because talking your way out of this universe is not charm, it is
looking like a ship nobody wants the paperwork of. There is precedent in the
option table: `inspection_sweep`'s "talk your way to the front" is a Stealth
check for exactly the same act.

3 is a real ladder rather than a formality: a hull with no stealth at all is
on the 20% band and a Redline launches at 2, which puts it on 65%. That is
the manufacturer difference showing up in a button rather than in a tooltip.
Whether you have put a shot into anything this fight.

HAIL closes the moment you do, and only then: bracing, venting, patching and
every other thing you do to your OWN ship leave it open. That is the line the
rule is actually drawn on -- not "have you acted" but "have you shot at them",
which is what they would care about.

Set in `damage_enemy`, which is the one place a hit on a contact lands
whatever card, drone or feedback effect caused it.
```

Above `func hail_check() -> Dictionary:`:

```text
Can this contact be talked to at all?

RULED: not fauna and not a boss. You do not negotiate with something that
hunts by smell, and the thing guarding the core is not there to be reasoned
with -- it is the run's ending. `EnemyTemplate` already carries both flags, so
the gate needs no new data.
What hailing rolls. The mirror of `flee_check`, and it exists for the same
reason: the panel that asks whether you mean it has to print the odds you are
about to take, and it must be reading the number the roll uses rather than
the one somebody typed twice.
```

Above `var hail_failed := false`:

```text
Whether the channel has been tried and refused.

ONE ATTEMPT, and the argument is `flee_failed`'s word for word: a check you
may repeat is a check you will eventually pass, so a hail you could re-open
every turn was a stealth roll with unlimited retries and a heat bill. It was
also the louder of the two -- fourteen heat and the turn handed back -- which
made it the one you could least afford to spam and the only one you could.
```

## Salvo live

Above `func salvo_live(c: CardData) -> bool:`:

```text
IS THIS SALVO CARD WORTH MORE RIGHT NOW. One definition, because three
places asked and one of them asked differently.

Salvo pays "if you have already attacked this turn" -- except with five
Korvan aboard, which makes a Korvan card's salvo unconditional. The resolver
knew that and the preview knew that; the CHIP on your ship only tested the
counter, so a Korvan-5 pilot was told SALVO was down at the top of every turn
while the cards in their hand were quietly already paying it. A readout that
contradicts the rule is worse than no readout.
```

## Hail button label

Inside `hail_reason()`, above `return "" if hail_cause() == &"" else "NO REPLY"`:

```text
ONE LABEL FOR A SHUT DOOR, and it has to fit the rail -- which is 68,
because END TURN sets that and the pile is cut to it. "NOT NEGOTIATING"
needed 93 and took the rail to 100, which made the pile landscape; this
needs 58. Three different words for "no" made the button
read as three different mechanics -- a player would learn NO REPLY, NO
TERMS and YOU FIRED separately before noticing they are the same greyed
state. The BUTTON says what is true of the button; the TOOLTIP says why,
and why is where the three actually differ.
Derived from `hail_cause`, the same way `flee_reason` derives from
`can_flee` -- the blocking conditions live once, in the cause.
```

## Hail exit

Above `func hail() -> void:`:

```text
Talk your way out.

The same exit `flee` buys, bought with words: the contact breaks off, there is
no salvage, and the node is marked so the sector offers a jump rather than the
fight again. What it does NOT cost is the fuel -- that is the whole point
of having stealth on the ship.

Failure is loud rather than damaging. You have broadcast, and they did not
take it.
```

## Flee attempt

Above `var flee_failed := false`:

```text
Whether the burn has been tried and missed.

ONE ATTEMPT. Fleeing used to be a purchase, then a check you could re-roll
every turn until it landed -- which is the same thing with extra steps, since
a check you may repeat is a check you will eventually pass. Failing it now
closes the door: you committed to the burn, they are still on you, and the
fight is the only thing left.
```

## Flee eligibility

Above `func can_flee() -> bool:`:

```text
Can you still try to run?

Not from the core's guard: that is the fight the run has been travelling
towards and there is nowhere past it to run TO. The hellbender is deliberately
NOT included -- breaking off it banks the damage you did, which is the whole
shape of that chase, and taking that away would quietly delete a mechanic.
```

## Flee check

Above `const FLEE_ATTR := &"maneuver"`:

```text
Breaking contact is MANEUVER, and it can fail.

It used to be a purchase: fuel, always granted. That made FLEE the safest
button on the panel -- every fight had a guaranteed exit and the only question
was whether you minded the price. A check makes leaving a thing your ship is
either good at or is not, and puts MANEUVER -- which had almost nothing to do
outside dodge -- on a button you reach for under pressure.

3 against a ladder that runs 4/6/8 by hull class: a light frame is on the good
bands and a heavy is on the bad ones, which is what a light frame is FOR.
```

## Failed exit note

Above `var exit_note: String = ""`:

```text
What a flee would roll, for the panel to print before you commit.
WHAT A FAILED EXIT DID, for the panel that asked to print.

A hail or a burn that WORKS ends the fight, and `_finish` carries its own
summary out on `combat_ended`. One that fails does not end anything: it spends
the fuel or the heat, logs a line into a feed you are not looking at, and
hands the turn back -- so the one moment the player is owed an answer is the
one moment nothing was telling them. Set on every path through both, cleared
by the caller before it asks.
```

## Custodian body loot

Above `const CORE_PRECURSOR := 2`:

```text
WHAT THE CUSTODIAN'S BODY HOLDS: two precursor parts, two branded
legendaries, and the instrument shadow (Jon, Oct 13, option C of three: the
first version took the best of any rarity and came back nearly all
precursor).

Generous because it is the last thing a run pays, and nothing after it
competes for the hold. Each part is the first roll of `LootGen.roll_module`
that is what its slot asks for -- ARTIFACT with precursor parts allowed, or
LEGENDARY from a manufacturer -- so affixes and scrap value come out exactly
as any drop's, and never the same part twice. Rolled as the deepest danger
whatever the node says, so the gates that hold legendaries back never apply
to the galaxy's boss. If a slot finds nothing in `CORE_TRIES` rolls, the
best it saw stands, so the body is never short.

The INSTRUMENT SHADOW is the material table's own core piece -- "a sensor
plate burned in the shape of something that passed between it and the
core" -- and taking it off the thing that guards the core is the fitting
place for it.

POSITIONAL, as every wreck is (see `roll_wreck`): keyed by the node and how
many wrecks it already holds, so a party's machines open the same body.
```

## Wreck contents

Above `const WRECK_CREDIT_CHANCE := 0.75`:

```text
WHAT ONE WRECK HOLDS. Jon, Oct 13: "Each ship you kill has a chance to get
credits and modules and other parts." Every hull a fight leaves is rolled on
its own, from its own template, and you collect it wreck by wreck.

It used to be one payout for the whole fight: the LAST ship's
`credit_reward`, once, as a chit in the FIRST wreck, and the fight's parts
dealt round-robin across the hulls. So a Cutter (15) and a Marauder (34) paid
15 or 34, never 49, and every wreck after the first held no money. Now a
fight pays about what its ships would have paid one at a time.

CREDITS: a `WRECK_CREDIT_CHANCE` chance of a chit for the ship's own
`credit_reward`, scaled as the single payout always was (+20% a danger level
above 1, half as much again with the probate set), give or take
`WRECK_CREDIT_SPREAD`. The Hellbender always pays, and pays its number
exactly: a set piece is tuned by hand. Fauna have no money aboard
(`credit_reward` 0) and pay exotic instead. The custodian is not rolled
here at all; see `core_body` and the boss branch of `_victory`.

PARTS: `WRECK_PARTS` is how many parts one hand can expect from a hull of
that kind, so a bigger, tougher hull leans toward more. The whole number is
certain and the fraction is a chance: 1.2 is one part and a one-in-five
chance of a second. Lawless space multiplies it by `WRECK_LAWLESS`, fauna
carry none, and the Hellbender holds `HELLBENDER_PARTS` a hand, as its drop
always did. Set so a one-ship fight pays about what it did before (one part
a hand, two in lawless space) over the ships a run actually meets.

OTHER PARTS: an animal's exotic goes into its own body (`FAUNA_EXOTIC`, one
more with the calyx set). It used to go on the system's floor through
`Run.add_material`, under a comment that said "into the hull you just
killed"; now it is.

HANDS: `hands` is how many ships the party paid for this kill
(`SharedFight.paid`), 1 alone. Each hand rolls the wreck's parts again, so a
kill shared four ways holds about four times the parts and the party takes
them first come, first served. The money does not multiply: one hull carries
one purse however many ships shot at it, which is what keeps
`docs/coop-design.md` 3's dive economy a closed loop.

POSITIONAL, as every wreck has been: `Rng.derive(&"wreck", node.index * 64 +
index)`, where `index` is this wreck's place among the system's wrecks. So
every machine in a party rolls the same wreck the same way without a byte on
the wire, and one wreck's roll never moves another's. `core_body` is keyed
the same way. `probate` and `calyx` are this machine's set bonuses and are
the one input that is not the place's: a party member with the set sees a
bigger chit or one more exotic, as the old single payout did.
```

## Wreck credit scale

Above `const WRECK_CREDIT_SCALE := 1.27`:

```text
WHAT AN ORDINARY SHIP'S PURSE IS WORTH against its `credit_reward` (Jon, Oct
13, option C of three: keep the chance per ship and raise every ship's pay so
a run banks what it did before the chance came in). Set by measurement, not
by the 1/0.75 the chance suggests, on 3e47e4d (no reinforcements), `-- sim
runs=200 seed=777`, two readings:
  - `packs` (ambushes field their whole `Router._roll_foes` pack, as the game
    does): the old single payout banked 78 credits a run; x1.10 banks 79.
  - the sim's default (every fight one ship): the old rule banked 88; x1.24
    banks 88, x1.10 about 78.
1.10 was the one chosen then, because Jon's goal is the money per run IN THE
GAME, and the game's ambushes bring their packs, each ship of which now pays.

NOW 1.27 (Oct 17). RE-MEASURED, after the sim was made to field fights as Router does
(whole packs and `clears_node` false on ambushes, none at stations, option
fights from `Router.option_foe`), and with the old rule put back for the
money alone -- the last hull's reward, certain, in the first wreck -- so both
readings fly identical runs: the old rule banks 92 a run, x1.10 banks 80,
x1.26 91, x1.28 93. The same money-only swap on the sim as it was gave 87
against 78, so most of the gap is in how "the old rule" was measured, not in
the sim. The arithmetic says the same: a lone ship pays 0.75 x 1.10 = 0.825
of what it did, and only about 6% of won fights are pairs. Jon's rule is
"75% chance, money per run where it was", so the old rule's 92 is the
target, and 1.27 sits between the two readings that bracket it.
Re-measure whenever the mix of pack sizes moves. Never the set pieces: the
Hellbender and the custodian are hand-tuned and pay their own numbers.
```

## Custodian win

Inside `_victory()`, above `Combat.core_body(node, boss.template)`:

```text
AND THE BODY IS LOOTED BEFORE THE RUN ENDS (Jon, Oct 12: "when
defeating the final boss at the core, let's have the body of the boss
lootable, but let it end the alpha with a winning game popup"). It
used to end on this line with nothing to open. Now the custodian
leaves a wreck like any other kill, `Router.after_combat` opens it
over LOCAL, and DONE brings up the win screen.

THE WIN IS RECORDED HERE, AT THE KILL, not when the popup opens. The
same rule as dying: a player who quits while looting has still won,
the suspend save goes now, and `Run.won` keeps the autosave from
writing a cleared core back to disk -- so no way out of the loot step
leaves a run that can no longer be won.
```

## Wreck payout

Inside `_victory()`, above `var hands := maxi(1, shared.paid if (is_shared() and shared != null) else 1)`:

```text
ONE WAY TO BE PAID, and it is the wrecks you just made.

This used to branch. Alone the parts went straight into your hold, on the
reasoning that "a bag with one hand reaching into it is a menu between you
and your own loot" -- which was true of a LIST and is not true of a
container you open. `MATERIALS_NOTE` 3.6 made every physical payout a
place you reach into, and 3.4 is why: `Run.stow` returns false on a full
hold, so the solo arm quietly destroyed the reward for winning whenever
you were carrying anything.

In a party it was always this, and for a reason worth keeping: both ships
used to roll their own drop off their own seat-salted stream, which stops
two players being handed the identical part and does nothing about one
frigate paying the party twice over. `docs/coop-design.md` 3 runs the dive
economy as a closed loop, and a kill that pays per-head is not closed. The
parts sit where the fight happened until somebody reaches for one, and the
reach is first come, first served. So the party rule became the only rule,
and solo is a party of one.

ONE CONTAINER PER HULL, and now each container is that hull's own (Jon,
Oct 13; see `roll_wreck`). A wreck you can point at is a wreck you can go
and open, and three of them is three decisions instead of one list. The
money used to sit in the first hull only, on the reasoning that "a chit
in each turns one payout into a chore" -- and that was the price of one
payout. Jon's ruling makes each kill its own payout, so each wreck carries
its own, and some carry none: a hull you have to open to find out is the
point of a chance.

Off `Rng.loot` -- salted by seat -- the two ships' copies of one wreck held
different parts under the same claim numbers, so a claim on slot 0 took a
different part on each machine (`tools/cofight.sh` caught it). Which is
why each wreck is rolled positionally, by its place among the system's
wrecks: a second fight at the same system is a second roll, and every
machine in the party rolls each wreck identically.
```

## Leaving mid-fight

Above `func abandon() -> void:`:

```text
LEFT FROM THE MENU, mid-fight: SAVE & EXIT or ABANDON (review, Nov 5): out
of the party's crew, and off the signal bus. Both used to let go only (or
not at all), so the crew kept a ghost: every partner sat on "WAIT <name>", and a
CONTINUE was handed back the fight it never left, with no join and no
growth. And a fight SAVE & EXIT dropped without letting go stayed on the
signal bus, and ran the next turn with no hull when the party's moved.
A finished fight has left already (`_finish`). Let go BEFORE the leave: on
the host the leave is handled at once, and can close the barrier and move
the turn while this is still listening.
```

## Adopting host state

Above `func _adopt(f: SharedFight) -> void:`:

```text
Copy the host's answer over the local enemy.

Only the numbers move. The templates, the art and the scaled intent lists
were built identically on every machine from the same ids and the same
danger, so what crosses is hull, block, brace and WHICH intent — never the
intent itself.
```

## Party lost

Above `func _on_party_lost(_reason: String) -> void:`:

```text
The party is gone — the host dropped, or the connection did.

The fight does not stop. It becomes the fight the game has always had: the
enemy on this machine is whatever the last push said it was, and from here
this object decides its own hulls again. Anything else is a softlock, because
the one thing a shared fight waits for is a host that is no longer there.

The enemy is left at party scale. Finishing a frigate sized for four on your
own is bad; being unable to finish it at all is worse, and FLEE is still on
the panel.
```
