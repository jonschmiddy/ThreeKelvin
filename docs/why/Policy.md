The reasoning behind `tkg/scripts/sim/Policy.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Pilot model

Above `var hot: bool = false`:

```text
The competent-player model, as a thing rather than as a loop.

This is `HeadlessSim`'s pilot, lifted out of it unchanged. It was extracted
for one reason: the party bot needed a brain, and a bot with its OWN brain
would be a second pilot model that nothing measures. The gate plays this one
two hundred times before every merge and reports its win rate; a second copy
in `BotPilot` would drift away from that number quietly, and the first sign
would be a bot that plays visibly worse than the simulator says the game
plays. One model, two callers.

Frame-free on purpose. Nothing here awaits, and nothing here touches a
screen, so it runs identically inside `HeadlessSim`'s tight synchronous loop
and inside `BotPilot`'s frame-driven one. That is the whole reason the split
lands on this line and not somewhere more natural-looking: the SIM's loop and
the BOT's loop cannot be shared — one must not yield and the other must — but
every decision inside them can.

It reads `Run` and a `Combat` and mutates them. That is not a layering
mistake, it is what a player does.
```

## Vent thresholds

Above `var vent_cold: float = 0.7`:

```text
When each model reaches for a vent card, as a fraction of heat capacity.

THESE TWO NUMBERS ARE THE TWO POLICIES -- and they are UNCHANGED after being
swept on 2026-08-25, because the sweep says they do not matter.

The suspicion was reasonable. They were chosen when a free point of heat came
off every turn, and deleting that shed should have made both models hold vent
cards too long. An unpaired sweep at 300 runs a cell appeared to confirm it,
with both old values landing worst in their own column.

THAT SWEEP WAS MEASURING THE GALAXY, NOT THE THRESHOLD. Every run rolls a
different galaxy and the kind alone swings win rate 33 to 38 points, which
is an order of magnitude more than this dial. Re-run PAIRED -- `seed=1000`,
so both configs face the same 500 galaxies -- it collapses:

    cold 0.50   win 27% (135)   cooked 52   fightsig 0.31   arrived hot 8.4%
    cold 0.70   win 26% (129)   cooked 53   fightsig 0.32   arrived hot 8.6%
    hot  1.00   win 26% (128)   cooked 65   fightsig 0.34   arrived hot 9.3%
    hot  1.15   win 26% (128)   cooked 62   fightsig 0.34   arrived hot 9.2%

Six wins in five hundred between the cold pair, none at all between the hot
pair, and every heat number the same. So the values stay where they are: a
change with no measured effect is a diff somebody has to read later for
nothing.

WHY THE DIAL IS INERT, and it is not a heat problem at all.

THE HOT POLICY IS MODELLING SOLARI, ON A KORVAN SHIP. `design-doc.md` has
them as mirrored heat philosophies -- Korvan MANAGES heat, Solari SURFS it --
and Korvan is the starter kit and the only entry in ACTIVE_MANUFACTURERS. So
the model is asking the cold manufacturer to run hot, using the cold
manufacturer's loot. It loses because it should.

The three cards that want heat high are all Solari: Plasma Lance
(`heat_scale`), Thermal Purge (`damage_equals_heat`), Heat Shroud
(`brace_from_heat`). Solari is SEVEN modules of a targeted forty and does not
drop, so those cards are unreachable in a normal run.

This dial becomes meaningful when Solari is written and switched on -- that
is blocker B4, already tracked -- and not before. Tuning it against Korvan is
tuning the wrong ship.

Sweepable from the command line -- `-- sim ventcold=0.5 venthot=1.0` --
and ALWAYS PAIRED with `seed=`, or the galaxy roll drowns the answer.
```

## Pilot rng

Above `var pilot: RandomNumberGenerator = RandomNumberGenerator.new()`:

```text
The pilot's own generator. One per run, seeded from the run's master seed, so
the model's choices replay with the run and drawing them does not move what
the world rolls next.

Assigned by the caller — `Rng.derive(&"pilot", 0)` — rather than seeded here,
because a bot in a party must NOT share it with the sim's convention. See
`BotPilot._brain_up()`.
```

## Cargo policy

Above `static func loot(n: MapGen.MapNode) -> int:`:

```text
WHAT A PILOT TAKES OUT OF A CONTAINER, and it is a design statement rather
than plumbing.

Until now nothing physical could fail to reach the sim: a kill called
`Run.stow` and the part was aboard. `MATERIALS_NOTE` 3.6 changed that -- every
payout is a place you reach into -- so without this the simulated pilot walks
past every wreck in the galaxy and every number the sim reports describes
somebody who picks nothing up.

The rule: take the most valuable thing that fits, and keep going until
nothing does. Not "take everything", because a hold is finite and the whole
point of the change is that room is a decision; not "take the first thing",
because nobody plays that way. What it does NOT do is scrap to make space --
that is the player choosing to destroy something, and a model that does it
automatically would be measuring a game nobody is playing.

The number this leaves behind is worth watching. It is the first time the sim
can fail to collect, and how much a competent pilot walks away from is now a
fact about the balance rather than zero by construction.
```

Above `func manage_cargo() -> void:`:

```text
Install what improves the ship; carry a few of the rest to the next market.

The model used to melt everything it did not install, the instant it picked
it up. That was correct when melting was the only thing you could do with a
part and it is not any more — a hold that is always empty means the simulator
can never once exercise the thing this economy is built around, and would
report a win rate for a game with no market in it.
```

## Human pilot

Above `var human: bool = false`:

```text
A PERSON HEADING FOR THE CORE, rather than the gate's farmer. `-- sim human`.

The gate's model picks forward stars AT RANDOM and farms a ring on a coin.
A person reads the chart: they go deeper, they go somewhere new, they divert
to a dock when hurt or low, and they notice the fuel price a little. That is
the player Jon is describing, and it is the one whose choice of star fuel can
be said to LIMIT -- the random model has no best star to be denied.
```

## Fuel policy

Above `const FUEL_TOPUP := 1.0`:

```text
Top up to a full tank at a station, and never below this many credits. It
was half, against a 279 tank with no top; against 45, half is ten jumps.

The reserve exists because hull loss kills more runs than fuel does: a model
that spends its last credit on fuel arrives at the next fight unable to
repair, which is a worse death for the same money.
```

Inside `shop()`, above `var want := int(float(Run.fuel_cap()) * FUEL_TOPUP)`:

```text
A COMPETENT PILOT TOPS UP; they do not coast to empty and hope for a
station. `Run.fuel < 8` was the old test, and it is a fault in the
INSTRUMENT rather than a fact about the game -- see the note on
RunState.FUEL_PER_DISC_RADIUS, which records the same lesson about the
jump policy. With a tank that starts at 279 that test fires about once a
run: the model sailed past twenty-one stations declining fuel and then
stranded when it finally ran low somewhere without one.

Measured before the change: 21.5 stations a run, 11 fuel bought across all
of them, and 20% of runs ending blocked by fuel while sitting on 125
credits of profit.

Tops up, keeping a credit reserve so refuelling never eats the repair
budget -- hull loss is the largest death cause and buying fuel instead of
a hull is not competence.
```

Inside `shop()`, above `var reserve := FUEL_RESERVE`:

```text
NO RESERVE WHEN THE TANK CANNOT MAKE THE NEXT JUMP, or the dock is
offering the way out (`Run.dock_rescue`). Keeping 40 back for repairs
there is not competence, it is the end of the run: the balance check
(Oct 18) replayed three strands that sat on docks with 23-46 credits
and refused a can.
```

## Jump policy

Above `const FARM_LIMIT := 3`:

```text
How many lateral hops the model will spend in one ring before descending.

Unbounded farming is not a strategy, it is a loop: the old rule moved
laterally on every unhealthy turn, so a damaged ship circled its ring picking
up more damage until something killed it. Three is enough to visit a station
and a couple of sites and still be going somewhere.
```

Above `func engage_hellbender() -> bool:`:

```text
Where to go from here, or -1 when there is nowhere legal to go.

Farm laterally while the tank allows it, then descend.

A COMPETENT PLAYER WATCHES THE TANK. This used to farm laterally on a 65%
coin whatever the fuel gauge said, and always when hurt — so the model
wandered until it ran dry, and the average run came out at 117 jumps. That is
not a fact about the game; it is a fact about this function. Tuning the fuel
economy to bring the number down would have been tuning the game against a
model artifact, and it would have made the real game punitive to fix a bug in
here.

Farming is what you do when you can afford it. With the tank low, the only
move that ends well is onward — and a player who has decided to descend
descends whether or not they are healthy, because sitting still does not heal
you.
Whether the model commits to the hellbender when it lands on one. Health-gated
rather than build-gated: the model cannot read its own deck quality, but a
player at full hull who has found a set piece engages it and a player at
half does not. Damage banked from a previous engagement makes the fight
strictly better, so the bar drops with the hellbender's own hull.
```

Inside `choose_jump()`, above `limited = false`:

```text
IN RANGE, NOT LINKED. `links` is the graph the chart DRAWS; it is not the
graph the ship flies. `can_jump_to` is `reachable_from` plus fuel, and
`reachable_from` is a radius that never consults `links` -- the chart's own
neighbour list is `in_range()`, which is what the player picks from.

Routing on links made the simulator play a narrower game than the one that
ships, and it showed: the policy running out of charted options was being
counted as the run ending, and 46% of those ships could still fly.
```

Inside `choose_jump()`, above `if not sideways.is_empty():`:

```text
NO WAY DOWN FROM HERE, so walk the ring until there is one. Since sparse
coreward links landed, most systems have no door and this is the ordinary
case rather than an edge one -- the old fallback picked at random from
every link including BACKWARD ones, which on a sparse map is a random walk
that ends when the fuel does. Measured before this: 70 jumps at an average
danger of 1.8, which is seventy hops without leaving the rim.

Prefers a neighbour that can itself descend, so the walk is toward
something rather than merely away. These hops are travel, not farming, and
deliberately do not count against FARM_LIMIT: a limit on how much you farm
should not also be a limit on how far you may walk to leave.
```

Inside `choose_jump()`, above `var doors: Array[int] = []`:

```text
ALSO IN RANGE RATHER THAN LINKED, for the same reason: "can this
neighbour get further in" is a question about what it can REACH.

This is the expensive branch -- a map-wide pass per candidate -- but it
now almost never runs. `forward` is only empty when nothing deeper is
in radius at all, which a radius reaching several rings rarely manages.
```

## Card scoring

Inside `score()`, above `if (c.heal > 0 or c.heal_scale > 0) and Run.hp < Run.max_hp() * 0.5:`:

```text
Repair, and it RISES AS THE HULL FALLS rather than sitting at one number.

The flat 75 modelled a player who repairs when convenient. It ranked below
brace and venting at every level of damage, so at three hull the model
braced against a hit it could not survive instead of buying the turn that
would let it. That is not a competent player, and the repair cards are now
scaled on hull missing — see CardData.heal_scale — so the card the model was
declining is the biggest one in the deck exactly when it declined it.

Below a fifth of your hull it outranks everything except a lock that is
already paid for. Between a fifth and a half it sits where it used to.
```

## Shopping

Above `func shop(n: MapGen.MapNode) -> void:`:

```text
Dock. Sell first, then spend — which is what a player does, and which is the
only order that lets a hold full of salvage pay for the repair.

The model deliberately does NOT buy stock to resell. Trade routes are a
strategy the player can find; assuming a competent player already runs one
would report a win rate for a game nobody has played yet.
```

## Risk policy

Above `var risk_averse: bool = false`:

```text
Whether this pilot declines long odds.

The second policy `ENCOUNTER_REBUILD.md` §8 asks for. A greedy model takes
every check it is offered, which overstates income and makes the shortfall
ladder look free; a risk-averse one refuses below `RISK_FLOOR` and pays for
the caution in what it never collects. Running both is how the exclusivity
dial gets argued with rather than assumed.
```

Above `var checks_avoided := 0`:

```text
How often caution took the safe line instead of the check.

`declined` counts walking away from an option ENTIRELY, and it measured
nothing: a cautious pilot almost never does that, it takes the unchecked
fallback instead. So the two policies differed by eight points of win rate
with an identical `declined` of 0.00, and the number that was supposed to
explain the gap could not see it.

This is what caution actually costs, and what it buys.
```

Above `const RISK_FLOOR := 0.45`:

```text
The odds a cautious pilot will not go below.

`SkillCheck.ODDS` is [1.0, 0.65, 0.40, 0.20, 0.05] by shortfall, so 0.45 sits
between one pip short and two: this pilot takes a check it is one under and
declines one it is two under. Not a ruling -- a starting point for the sweep
§8 asks for.
```

## Option taking

Above `var fight_cb: Callable = Callable()`:

```text
Runs a fight the way this harness runs fights, and reports whether we lived.

Injected because a policy has no Combat of its own and should not: the sim
owns the loop, the postfight sampling and the turn cap. Left invalid, fights
are counted and not run -- which is a measurement of a different game, so any
harness that reports a win rate must set this.
```

Above `func take_options(n: MapGen.MapNode) -> Dictionary:`:

```text
Take what this system offers, and report what was left behind.

GROUPS ARE THE POINT. Taking an option marks its group spent and every other
option in that group becomes unavailable -- so a grouped system is a system
where arriving rich means choosing what to leave. `forgone` counts exactly
that, and it is the number §8 says the model must be able to report.
```

Inside `take_options()`, above `if bool(res.get("fight", false)):`:

```text
AND NOW THE FIGHT, if the outcome opened one. This used to be counted
and skipped, which was defensible while FIGHT was still a node type and
the sim fought there instead. It is not defensible now: fights exist
ONLY as option outcomes, so skipping them meant simulating a game with
no combat in it -- 0.2 kills a run, and a win rate measuring the wrong
game. `fight_cb` is the sim's own `_fight`, handed in because Policy
does not own a Combat.
```

Above `func _choose_line(opt: Dictionary) -> int:`:

```text
Which line of an option to take, or -1 to walk away.

Prefers a check this pilot will pass over a flat effect, because the checked
bands are where the payouts are -- but only when the odds clear the floor. A
cautious pilot falling back to the unchecked line is the whole difference
between the two policies.
```

## Beeline pilot

Above `var beeline: bool = false`:

```text
THE BEELINE PILOT (`-- sim beeline`, balance/run-length, Oct 22). Kevin, the
first outside playtester, reached the core in seven jumps; the gate's pilot
farms rings on a coin and never does. This one always flies the deepest star
it can see, reach and afford (the core above everything), the cheaper of two
equally deep. Its one concession to fuel: below a third of the tank it flies
to the deepest dock in reach instead, if one is, and tops up there (`shop`).
`dash` (with `-- sim dash`) also walks past every option on the way in.
```
