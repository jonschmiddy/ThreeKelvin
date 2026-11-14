The reasoning behind `tkg/scripts/autoload/RunState.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Ship name

Above `var ship_name: String = ""`:

```text
WHAT THE PILOT CALLS IT, or empty for the frame's own name.

Empty by default rather than seeded with the hull's name, and that is the
whole design: a ship is unnamed until somebody names it, and a hull swap
then keeps the name across the frame rather than reverting to whatever the
new chassis is called. Storing the hull's name here at run start would make
every ship "named" and quietly rename it under the player the first time
they changed frames.
```

Above `func display_name() -> String:`:

```text
WHAT TO PUT ON SCREEN when the player's ship is named. The pilot's name if
there is one, the frame's own otherwise.

ONE FUNCTION, because there is more than one place that names your ship and
they were not agreeing. The refit masthead read `ship_name`; the plate under
the hull in a fight read `hull.name` -- so a ship you had named flew into
combat as its chassis, which is the one moment you are actually looking at it
being shot. Anything that shows the player's ship to the player calls this.

NOT `.to_upper()`d here. Silkscreen draws caps for both cases, but the
masthead and the combat plate upper it themselves and a name that arrived
pre-shouted would defeat any future place that wants it in mixed case.
```

## Moving ships

Above `var pad: Array[HoldItem] = []`:

```text
WHAT CAME OFF THE OLD SHIP AND WILL NOT FIT THE NEW ONE.

`cargo` has an invariant that HoldTest enforces on every run: every item in
it sits at a real cell, inside the grid, overlapping nothing. That is why the
old `transfer_to_hull` DESTROYED the overflow when you bought a smaller ship
-- deleting it was the only way to keep thirteen things out of a twelve-cell
hold. The cargo was never the problem; having nowhere to put it was.

So this is the nowhere. The pad is the dock you are standing on: things off
the old frame that have not found a cell yet. It is not `cargo`, so the
invariant is untouched, and it is not lost, so nothing is deleted behind your
back. You cannot undock while it has anything on it.
```

Above `var old_hull: HullData = null`:

```text
THE FRAME YOU ARE MOVING OUT OF, kept only until the move is finished.

The transfer screen draws BOTH ships, and the left-hand one has to be a real
hull or it cannot be drawn: it needs a sprite to show and a `hold_grid` to
lay the leftovers out in. The purchase is final the moment it is made -- this
is not a way back, it is the loading dock, and it is cleared the moment the
pad empties.
```

Above `var _undo_move: Dictionary = {}`:

```text
EVERYTHING NEEDED TO PUT THE OLD SHIP BACK, while a move is still in progress.

The purchase was going to be final and is not. What changed my mind about the
cost of reversing it is that `transfer_to_hull` no longer MOVES anything --
the old frame keeps its guns and its crates exactly where they were -- so
"undo" is not a reconstruction, it is putting a snapshot back over a state
nothing has happened to yet.

Cleared when the move commits, so it only ever describes a decision still
being made. Not saved: quitting mid-move and reloading leaves you on the new
ship with your things on the pad, which is a finished purchase. And CLEARED BY
THE LOAD (`SaveGame.load_into_run`): SAVE AND EXIT then CONTINUE is one
process, and an undo left in memory names the objects the load replaced -- a
BACK OUT there refunded the old price and put back a frame from before the
save (Oct 23).
```

Above `func transfer_to_hull(h: HullData, paid: int = 0,`:

```text
Move into a new frame. EVERYTHING COMES OFF, and you re-rig it yourself.

THE OLD VERSION GUESSED, AND GUESSED WITH THE WRONG NUMBER. It shed the
lowest `scrap_value` part of any slot the new hull had fewer mounts for --
a decent proxy for "least valuable object" and a bad one for "least wanted
part", because this is a deckbuilder. A common Coolant Flush granting the
card your whole engine turns on outranks a rare you never draw, and
`scrap_value` cannot know that. Nothing can, except you.

It also squeezed you twice. The shed loop packed parts against the OLD grid,
then the swap happened, then `repack_hold` ran against the NEW one -- so a
part could be stowed successfully and destroyed eight lines later, printing
two different "left behind" lines for one object.

Both go away by doing less: unbolt the lot, set the frame, pack ONCE against
the grid you are actually going to fly. What will not fit goes on the `pad`,
which is a place, not a wastebasket.

YOUR DECK IS NOW EMPTY, and that is not a side effect -- it is the decision.
`deck_size()` sums `grant_count()` over `installed` and the hull contributes
nothing, so a swap is a deck wipe and re-rigging is how you rebuild it. The
station will not let you undock until you have a deck again; see `ready_to_fly`.
```

Inside `transfer_to_hull()`, above `if h != found_hull:`:

```text
THE OLD SHIP KEEPS EVERYTHING UNTIL YOU MOVE IT.

An earlier version emptied the frame here and packed as much as would fit
into the new hold automatically, leaving the remainder stranded. That is
the same arithmetic and the wrong STORY: it decided for you, and then the
screen could only show you what it had decided. Nothing moves now unless a
hand moves it, so the transfer screen can draw the old ship still wearing
its guns and the new one genuinely empty.

`mount` and `hold_at` are both PRESERVED, which is what makes that picture
possible -- a gun remembers its hardpoint and a crate remembers its cell,
so the left-hand side of that screen is the ship you have been flying and
not an inventory of it.

A FOUND FRAME YOU ARE NOT MOVING INTO is cut up for its pay first
(`scrap_found_hull`): buying a yard hull threw it away below, pay and all.
Before the way back is taken, so backing out of the purchase does not
bring back a frame that has already paid.
```

Above `func abandon_move() -> void:`:

```text
Put the old ship back and forget the whole thing.

RESTORES WHAT STILL EXISTS, and deliberately not more. You can sell a gun or
throw one out of the hatch while the move is in progress, and those are real
decisions that happened -- a back-out that resurrected them would be an undo
of things you did rather than of the purchase you are cancelling. So the
credits from a sale stay yours and the part stays gone; what comes back is
every object still in your possession, in the place it was in.

THE HULL GOES BACK ON THE BLOCKS. `take_option` claimed it over the network
as well as locally, and there is no release on the other side of that -- so
in a party this frees the rack for you and the peer who was refused while you
were deciding is not told. That is the honest limit of this: single player it
is exact, in co-op it can leave one stale refusal. The alternative was
keeping the money and the claim for a ship you did not take, which is worse
in every seat.
```

Above `func pad_to_mount(m: ModuleData, slot: ModuleData.Slot, index: int) -> bool:`:

```text
Bolt something from the old ship straight onto a hardpoint of the new one.

THE SHORTEST PATH IS A DIRECT ONE. Routing this through the hold -- stow,
then fit -- would refuse the move whenever the hold happened to be full,
which has nothing to do with whether the hardpoint is free. A gun going from
one ship's mount to another ship's mount never needs to be put down.
```

## Materials

Above `var exotic: int:`:

```text
Raw materials, by id. See MaterialTable.

CREDITS are still the only CURRENCY — the ruling has not moved, only the name
has. These are not a second wallet; nothing on a price tag is denominated in
them. They are prerequisites: a recipe that costs forty credits is a purchase,
and a recipe that costs one precursor fragment is a reason to have flown
somewhere.

ALLOY was the counter-example and it is gone. It came off every part you broke
down, so it accumulated from the hold you were emptying anyway rather than from
anywhere you went — a resource with a faucet that large is a second currency
whatever the ruling calls it.
```

Above `var exotic: int:`:

```text
Exotic was a bare int here from the day megafauna existed, and about fifteen
call sites still read and write it that way. It is now the `exotic` row of
the ledger above, reached through a property so that every one of those sites
keeps working against the single store rather than against a copy that would
drift out of step with it the first time something forgot to update both.
EMITS, like `fuel` and `dross` and for the same reason. It is a view onto
`materials`, and `add_material()` — the other door onto the same dictionary —
has always announced itself. This one did not, so of the five places that
write `Run.exotic` directly, four left the reading on screen stale until some
unrelated redraw happened to correct it. That is the third instance of the
class of bug the header above describes, found by looking for it rather than
by anyone noticing a wrong number.
READ ONLY NOW. It was a settable view onto the ledger row; there is no ledger
row, and the five places that wrote `Run.exotic += n` were all handing you a
physical thing -- a fauna kill, a pacified herd, a pulsar sweep -- which is
`add_material` and a container. Reading it stays, because the history and the
save screen ask what you came home with.
BY TIER, NOT BY ID, and that is a change worth stating. This counted the
single id `&"exotic"` -- so the moment the pulsar drop was given a name of
its own it would have stopped counting beam hauls entirely, and it was
already blind to SINGER'S OIL, FLANK IVORY and every other named exotic in
the table. A number that means "what you came home with" and silently
excludes most of what you came home with is worse than no number.

Read by `RunHistory` alone, so widening it moves the run record and nothing
in play.
```

Above `func material(id: StringName) -> int:`:

```text
HOW MANY OF ONE THING YOU ARE CARRYING, counted off the hold.

THE LEDGER IS GONE AND THIS IS WHY. `materials` was a dictionary of id to
count living beside `cargo`, which held the same idea as objects with shapes
and positions -- two stores for one fact, and `MATERIALS_NOTE` 3.1 is explicit
that materials do not stack precisely so that "one is here and the other is
over there" can be true. A tally cannot say that, and a tally sitting next to
the thing that can is the older half waiting to disagree.

It also ends the shim. `MaterialTable.grant` paid a row's `value` in credits
because there was nowhere to put the object; there is now, so it hands over
the object and the station is where it becomes money.
```

Above `func add_material(id: StringName, n: int) -> Array[MaterialData]:`:

```text
Put some in the system, NOT in the hold. `MATERIALS_NOTE` 3.6: if something
hands you a physical thing it hands you a CONTAINER, and you reach in for it
with your own hold open beside you -- which is the only way a full hold can
refuse a reward without the reward quietly ceasing to exist.

Returns what it made, so a caller with its own container can take them.

EVERY MATERIAL IS PAID, so the party's size is counted here, once (Jon, Nov
5: "loot pools are increased as the playercount increases"): an n-player
game puts `PartyScale.pay(n)` of them in the system. 1 alone. A wreck's
exotic is in the wreck (`Combat.roll_wreck`), not through here.
```

## Dross

Above `var dross: Array[StringName] = []:`:

```text
WHICH malfunctions are lodged in you, not how many.

It was a count, and a count could only ever produce one card sixteen times.
The ids are stored so the deck can be rebuilt identically on every load and
every deck-build — rolling which malfunction at build time would have given
you a different set of junk every time the screen refreshed.
```

## Setters that emit

Above `var map: Array = []`:

```text
WHY THESE TWO HAVE SETTERS AND `heat` DOES NOT.

Three bugs in one day had one shape: a field on this object written directly
from somewhere else, with the signal that redraws it left to the call site to
remember. `heat_cap_bonus` forgot it entirely and the gauge sat at the old
number. `found_hull` never moved `hauls`, so a claimed hull could not be seen.
Both were fixed with a bespoke mutator, one at a time — which cures two call
sites and leaves the CLASS of bug intact: `fuel` and `dross` are written from
about twenty places across six files, each one pairing a write with a
hand-rolled emit.

A setter is the general fix and it costs the call sites nothing: every
existing `Run.fuel -= n` now redraws by construction, and the manual emits
beside them become redundant rather than load-bearing. `Sig` is registered
before `Run` in project.godot, so the initialiser above is safe.

`heat` is deliberately left alone. It is written inside the combat loop —
every card that costs or vents heat, plus the end-of-turn burn — so a signal
per write is a screen rebuild per write, several times a turn. That is the
efficiency problem this pass is also trying to remove. Rare, chunky writes get
the guardrail; the one field on the hot path keeps manual control, and this
paragraph is the reason rather than an oversight.

`kills` has no setter for a different reason: nothing on screen reads it, so
announcing it would be work with no listener.
```

## Map clock

Above `var map_clock: Dictionary = {}`:

```text
EACH SYSTEM'S MAP CLOCK, by system index: the map time (`SystemView.t`) its
map was last put away at, so it opens there again (ruling 23, Jon, Nov 1:
a binary's two suns turn, and a clock that started again at 0 on every
visit snapped them back on a Tab to LOCAL and back). It runs only while that
map is up. Written where the map keeps the ship
(`SystemMapScreen._keep_ship`), read by every map open (`Router.show_system`,
`ZoomLadder`), saved (`SaveGame`, VERSION 39), and cleared with a new run
(`start_new_run`) and replaced whole by a load. Kept apart from `SystemMapScreen._parked`,
which every jump in erases: the suns go on from where they were. A system
never opened has none, which is t 0, the layout as laid out.
```

## Custodian jump count

Above `var party_jumps: int = 0`:

```text
THE LEAD SHIP'S JUMPS, as this pilot last heard them: the most jumps any ship
in the co-op dive has made (Jon, Nov 4: "The custodian strength and icon
should be the same for everyone in the galaxy, even if they join late."). The
host keeps the party's figure (`NetSession.galaxy_jumps`) and pushes it whole;
this is the copy that outlives the party, so a guest whose host left flies on
at the count it had, and a quit and CONTINUE meets the same boss. Saved
(`SaveGame`, VERSION 40); cleared with a new run. 0 in the solo game, where
nothing raises it. Read through `custodian_jumps`, never alone.
```

Above `var custodian_seen: int = 0`:

```text
THE LAST COUNT WHOSE ARRIVAL THE CUSTODIAN'S BADGE HAS SHOWN (`GoalLine`,
`CustodianBadge`), so moving between LOCAL, the map and the chart never plays
it twice. The count is `custodian_jumps`, which in co-op can rise while you
sit still, or by more than one. NOT SAVED, on purpose: the save is written as
the ship arrives (`Router.resolve_current_node`), before the goal line comes
up, so a saved figure would always be one behind and every CONTINUE would
replay it. A loaded run counts as seen (`SaveGame`), and so does the count a
late joiner is handed at the door (`NetSession._push_growth_to`); a new run
starts at 0.
```

Above `func custodian_jumps() -> int:`:

```text
THE COUNT THE CUSTODIAN GROWS ON: the lead ship's jumps (`party_jumps`), or
your own when you are the lead or alone. Your own jumps are the floor, so
the jumping ship's badge, the save on arrival and a fight it opens are right
with no round trip; a partner's jump arrives with the host's push. Solo it is
`jumps`, exactly. What reads it: `Combat._spawn`, the badge and its tooltip
(`CustodianBadge.count`), `GoalLine` and the load. Everything else that
counts jumps (history, the game-over line, A.S.H., hints) keeps `jumps`.
```

## Salvage rail dismissal

Above `var hauls: int = 0`:

```text
How many times something has ARRIVED in the hold from outside the ship.

Bumped by stow() and by nothing else, which is the whole point: salvage, a
purchase and a fabrication are hauls, and a part moved off a hardpoint is
not. The sector screen re-opens its salvage prompt on this rather than on
`cargo.size()` — the size went up when you unbolted something on the refit
screen too, so putting your own coolant line in the hold made the sector
offer it back to you as fresh salvage.

Deliberately outside the save. It is a UI edge, not run state, and a resumed
run showing its hold once is the behaviour it already had.
```

Above `var salvage_hushed_hauls: int = -1`:

```text
The salvage rail was dismissed, and the state it was dismissed in.

ON THE RUN, NOT ON THE SCREEN, and that is the whole of a bug rather than a
preference. `SectorScreen` is rebuilt from scratch on every jump — `Router`
makes a new one — so a `_stowed` flag living on it was forgotten the instant
you left the system. Stow a part, jump, and the rail opened again and asked
the same question about the same cargo, at every system, for the rest of the
run.

Two numbers rather than a bool, because "dismissed" has to expire on the right
events and only those: a fresh HAUL is new cargo and should re-open it, and a
BAG at a system you have not seen is new loot and should too. Arriving
somewhere new carrying the same parts you already decided about is neither.

DELIBERATELY OUTSIDE THE SAVE, and that is not symmetry for its own sake — it
is the only way this can be correct. `hauls` above is not saved either, so it
comes back as 0; save the dismissal beside it and a run resumed after stowing
at haul 12 has `hauls` 0 against a hush of 12, and `hauls > hushed` is false
for the next twelve hauls. The rail would stay shut over loot the player had
just recovered.

Worth naming because the previous version of the rule got away with it: an
equality test fail-OPENED on that mismatch (0 != 12, so the rail showed), and
changing it to "is anything new" inverted the failure into a silent one. A
fix that is correct in isolation can break the thing next to it.
```

Above `func salvage_hushed(bag_here: int) -> bool:`:

```text
Whether the salvage rail should stay shut. `bag_here` is the index of the
system you are standing in if it has loose salvage, or -1.

THE TEST IS "IS ANYTHING NEW", NOT "IS THE STATE THE SAME", and the first
version got that backwards. It asked whether the haul count and the bag
matched what they were at dismissal — so stowing while standing over a bag
recorded that bag, and the next system, having no bag, compared -1 against it,
failed the equality and opened the rail again. A bag you walked away from is
not new salvage. Nothing happened; something merely stopped.

Two things are new and nothing else is: the hold GREW since you dismissed it,
or there is a bag at a system that is not the one you dismissed at.
```

Inside `salvage_hushed()`, above `if hauls != salvage_hushed_hauls:`:

```text
DIFFERENT, not greater. Within a run `hauls` only climbs, so the two read
the same — but `>` quietly assumes that, and the assumption is exactly what
broke when the dismissal was persisted and `hauls` (which is not) came back
as zero: `0 > 12` is false, so the rail stayed shut over loot already in the
hold. The dismissal is no longer saved and this no longer relies on that
being true. Any haul count that is not the one dismissed at means the hold
is not the hold that was dismissed.
```

## Event quests

Above `var event_quests: Array = []`:

```text
THE QUESTS AN EVENT GAVE YOU (Jon, Oct 22: an event that plants a follow-up
"is essentially a quest", so the QUESTS table lists it beside the signed
jobs). One record per option `OptionTable.place` put on a system, in the
order placed, written at `place` time:
  at       the system it went on
  id       the placed option (`paid_in_full`)
  from     the option that placed it (`the_runner`), whose title the table
           names as who gave it; &"" when the placer did not say
  credits  what taking it paid, and `got` the names of the things it put on
           the pile (`finish_event_quest`); both absent until it is taken

THE MAP STAYS THE TRUTH of whether a quest is open: the option on its system
and not taken. This only says where it came from and what it paid, so a save
from before it (VERSION 34) still lists every open one (`QuestLog`). Saved
(VERSION 35).
```

## Standing

Above `var standing: Dictionary = {}`:

```text
What each manufacturer thinks of you, by id. Higher is better and it only goes up.

GOODS, NEVER SECRETS. `docs/lore.md` §2 rules that there is no promotion — no
rank, no inner circle, no point at which a manufacturer starts telling you things —
and that ruling stands unchanged. This is not a relationship, it is an
account: deliver their work and their berths pay you better for your parts and
carry more of their stock. They still never explain anything.

Deliberately not a reputation you can lose. A manufacturer that can be offended is a
manufacturer you can lock yourself out of by playing badly, which is a punishment for
the player who most needs the money.
```

Above `const STANDING_BID := 0.05`:

```text
What their berths pay OVER the going rate for your parts, as a fraction.

The benefit is on the BID and never on the ask, and that is a hard constraint
rather than a preference: `Market`'s invariant leaves only about seven percent
between what a part melts for and the floor under what a station charges, so
a discount on the ask is a buy-and-melt exploit at four points of standing.
Paying you more for what you carry in has no such edge and reads the same at
the counter.

Capped, because bid is a fraction of ask and must stay one.
```

## Hulls bought

Above `var hulls_bought: int = 0`:

```text
Hulls BOUGHT at a station's yard this run (`transfer_to_hull` with the
station it came off). A.S.H.'s "New body" moment keys on this and not on
`hull` changing: the chassis select swaps `hull` once per click before a run
has started, and a hull found in the field is not a purchase. Jon, Oct 18:
only "when a player buys a new ship mid run". Not saved -- A.S.H. compares
it against her own count from the run's start or load.
```

## Unlocked manufacturers

Above `var unlocked_manufacturers: Array[StringName] = [&"korvan"]`:

```text
THE MANUFACTURERS THIS RUN'S WORLD MAY HOLD, read off the flight record once
at run start (`Unlocks.for_new_run`) and kept: what drops, sells and comes
off a derelict is these, within `DB.ACTIVE_MANUFACTURERS`, plus unbranded
(`LootGen.can_appear`). Saved (SaveGame VERSION 34), so CONTINUE finds the
world it left even if the record has moved on since. Korvan before any run
has started, which is what a fresh profile has.
```

## Missing hull stays missing

Above `var _hull_seen: HullData = null`:

```text
MISSING HULL STAYS MISSING (Jon, Oct 22, "a full ship stays full"). Fitting
or removing a part with hull on it moves the maximum, and the damage the ship
carries goes across unchanged: 40/40 fits a +7 plate and reads 47/47, 33/40
reads 40/47, and taking the plate off again lands exactly where it started.
Before, fitting raised only the maximum, so a full ship read 40/47 and the
HULL gauge (which reads CURRENT hull) did not move for the "+1 HUL" the part
printed. Damage carried, not "full or nothing": a 45/47 ship that took a
plate off was clamped to 40/40, read as full, and got its 2 back for free.

ONLY ON THE SAME HULL. A hull swap, a new run, a load and an undo set `hp`
themselves; the first change seen on a new hull is recorded, not acted on.
Never down to 0: taking plating off a nearly dead ship leaves it at 1.
```

## Starting a run

Above `func start_new_run(manufacturer: StringName = &"", w: int = -1) -> void:`:

```text
Begin a run in a given manufacturer's chassis.

The argument is optional and empty means "roll one", which is not a
convenience: HeadlessSim calls this directly, and a default of Korvan would
have every one of two hundred simulated runs fly the same ship and report a
win rate for one seventh of the game. Random here means the sim exercises all
seven starts for free.
```

Inside `start_new_run()`, above `var start_rng := Rng.derive(&"start", 0)`:

```text
A weight of -1 rolls one, for the same reason an empty manufacturer does:
HeadlessSim calls this directly, and a fixed default would report a win
rate for one twenty-first of the possible starts.

Off a DERIVED generator rather than the world stream. The starting ship is
not part of the world — in a party, four players fly four different hulls
through one galaxy — so choosing one must not move the map.
```

## Regenerate galaxy

Above `func dev_regenerate_galaxy() -> bool:`:

```text
DEVELOPER MODE ONLY: a new galaxy under the same ship, right now ("can I get
a button up here to regenerate the galaxy right there?", Jon) -- for looking
at what the generator rolls without starting a run each time. A new seed
(never the one in use, and not a forced test seed), a new kind, its map as a
new run's would be, the ship at the new start system. The ship, its hull,
cargo, credits, fuel and standing are kept, and so are its DATA, its board and
the steps bought on it (the board is not dealt again: it is the ship's flight
computer, not the galaxy's); contracts are dropped, because
they name systems of the old map. Not in a co-op session, where the galaxy
belongs to the whole party (the button says so). Returns whether it did.
```

## Fitting a chassis

Above `func fit_chassis(manufacturer: StringName = &"",`:

```text
Put a manufacturer's chassis and starting kit under the player, at full hull.

Separate from start_new_run because the chassis select calls it once per
click while you browse the seven. Folded together, changing your mind about a
ship would roll a new galaxy, a new name and a new map each time — so the
world you were about to fly into would quietly change while you compared
Thermal numbers. Rolling the world is a run-start concern; fitting a ship is
not.
`tier` is a DEV affordance and defaults to C, which is what every real run
starts on. Nothing in the game grants a graded frame at the yard — you find
those in wrecks. The chassis select exposes it behind Developer Mode so a
build can be flown at the grade it was designed around without playing to it.
```

## Room in the hold

Above `func has_room_for(m: HoldItem, leaving: HoldItem = null) -> bool:`:

```text
Whether a SPECIFIC part fits, which is the only form of the question a grid
can answer.

`hold_full()` used to be a property of the hold alone. It cannot be any more:
a hold with four free cells has room for four fittings, one bulky array, or a
long gun only if three of those cells happen to lie in a row. Callers that
want a yes/no now have to say what they are trying to put down.
Is there anywhere this could go?

`leaving` is a thing that is ABOUT to vacate its cells and should not be
counted as in the way. A swap is the case: dragging a stowed gun onto an
occupied hardpoint takes the resident off the hull and puts the new one on,
so the resident is landing in the space the new one is that instant giving up.
Asked without it, a full hold refuses every swap -- including swapping a part
for one exactly the same size, which cannot fail by construction.
```

## Doors into the hold

Above `func place_in_hold(m: HoldItem, at: Vector2i = -Vector2i.ONE) -> bool:`:

```text
Put a part in the hold, finding it a cell. False when nothing fits.

THE ONLY DOOR INTO `cargo`, with take_from_hold as the only way out. A bare
append leaves a module at (-1,-1) — in the array, drawn nowhere, overlapping
everything because it claims no cells — and that is a bug you find later, in
the UI, looking like a part that vanished.
```

Above `func take_from_hold(m: HoldItem) -> void:`:

```text
Take a part out, releasing its cells.
Take a thing out of your possession, wherever it was being kept.

BOTH LISTS, and that is what makes the pad cheap. This is the one door every
disposal goes through -- selling at the Exchange, scrapping on the refit
screen, jettisoning out the hatch -- so teaching it about `pad` is the whole
of teaching those three. The alternative was a `sell_from_pad` beside every
one of them, which is three chances to forget the second list.
```

Above `func stow(m: HoldItem) -> bool:`:

```text
Put a part in the hold, or refuse.

The one door into `cargo`, so the hold has a size that means something. It
returns whether it took the part, and callers are expected to care — a wreck
that hands you a module you cannot carry has to say so rather than silently
dropping it or silently exceeding the limit.

Forced moves do NOT come through here. install_module evicts the worst part
to make room for something you asked to fit, and uninstalling to a full hold
is refused at the point of asking; neither can be allowed to destroy a module
because the arithmetic did not work out.
A HoldItem. This was the last `ModuleData` between a bag and a hold, and it
is why TAKE did nothing on a crate: `take_from_bag` claimed the item, marked
the option taken, and then failed silently at the parameter type -- so the
claim was spent and the thing stayed on the floor.
```

## Event ledger

Above `func ledger() -> Dictionary:`:

```text
EVERYTHING AN EVENT CAN MOVE, in one dictionary, so it can be moved again.

An outcome does not report what it did -- it DOES it, inside a callable, and
hands back prose. There are a hundred and sixty-seven direct mutations in
`OptionTable` (`add_credits(-70)`, `heat += 20`, `take_hull_damage(8)`) and
the returned dictionary carries none of them: it has `text`, `module`,
`material`, `material_id`, `fight` and
`consume_material_tier`, and nothing else.

SNAPSHOT AND DIFF, rather than a reward field on each outcome. Two hundred and
sixteen of those callables would have to be edited to declare what they do,
every one of them could declare it wrong, and the declaration would drift the
first time somebody tuned a number and forgot the label. This reads the
ledger, so it cannot disagree with the ledger.
```

## Loose items and containers

Above `func take_item(m: HoldItem) -> bool:`:

```text
Reach for one loose thing, without knowing which entry it is.

The mirror of `jettison`, and it exists because the ICON knows what you
clicked and nothing else: it has an item, not a node and an index. Finding
those is the bag's business.

Awaits, because `take_from_bag` does -- the claim is a round trip in a party,
and "one bag, first hand in" is only true if everybody asks the same question
in the same order.
```

Above `func put_in(n: MapGen.MapNode, h: MapGen.Jetsam, m: HoldItem) -> bool:`:

```text
Put something down in a NAMED container.

`jettison` is this with the container chosen for you. They are separate
because the choice matters: with a wreck open on screen, dragging something
into it must put it in THAT hull -- what you are looking at is where it goes,
and quietly routing it to the floor instead would be the screen lying about
its own contents.
```

Inside `put_in()`, above `var already := h.items.find(m)`:

```text
THE SAME THING TWICE IS STILL ONE THING.

Taking from a bag does not remove the entry -- it marks the index taken,
so a party can see who got what. Jettisoning then APPENDED, so throwing
the same crate out twice put two references to one object in `n.bag`, and
`find()` answers with the FIRST -- which is the spent one. `take_from_bag`
saw an index already claimed and refused, so an item you had thrown out
more than once could not be picked back up.

Put back where it was instead: the entry is still there, so clearing its
claim is the whole of what "it is loose again" means.
THE FLOOR, not a wreck. What you put down is the system's, and a hull you
killed is not a bin -- keeping them separate is what makes "everything in
this sector" and "what that ship was carrying" two different questions
with two different doors.
```

## Settling a turned part

Above `func settle(m: HoldItem) -> bool:`:

```text
Make sure one item's cell is still a cell it can occupy.

TURNING A CARRIED PART MUTATES THE PART, and that is the whole problem this
exists for. Press R mid-drag and `turned` flips on the object itself -- which
it has to, because the drop target asks `footprint()` where it would land.
But the item is still in `cargo` at the cell it was picked up from, so if the
drag is then cancelled or refused, it stays there with a NEW shape: a 4x1
sitting in the last row becomes a 1x4 hanging four rows off the bottom of the
hold, overlapping whatever it crosses.

That is the corruption behind "items overflow the grid" and behind "it only
works if I shuffle things afterwards" -- shuffling calls `place_in_hold`,
which quietly puts the mess right.

Three answers, in order of how little they cost you: the cell still works;
some other cell does; or turning it is what broke it, so turn it back. Only
if none of those hold does it fail, and then it has changed nothing.
```

## Claims in co-op

Above `func consume_node(n: MapGen.MapNode) -> void:`:

```text
This system is finished: the wreck is stripped, the fight is won, the hail is
answered. THE ONE DOOR, and the reason it exists is co-op.

A shared seed gives four machines an identical galaxy rather than a shared
one — every wreck holds the same modules on every machine, because what a
node holds is drawn from `Rng.derive(tag, node.index)` and depends on where
it is rather than on who asked. The one thing a seed cannot say is whether
somebody has already been there. So consuming a node has to be told, and
telling it from one place means a new way to finish a system is shared by
construction instead of by somebody remembering to add a line.

`Net.claim()` does nothing in the solo game, which is why every call site
could be changed without a branch.
```

Above `func take_whole(n: MapGen.MapNode) -> void:`:

```text
The system itself, used up. Marked locally and told to the party without
waiting for an answer.

Fire and forget is correct HERE and wrong in take_option(). These are the
outcomes nobody can take out from under you — the fight you just won, the
hail you were already inside — so a round trip would buy nothing and would
show the wreck you just stripped as still full while it ran.
```

Above `func take_option(n: MapGen.MapNode, option: int) -> bool:`:

```text
One option at this system, when only one ship can have it. Returns whether
you got it, and awaits the party's answer if there is a party.

THE ONE THAT HAS TO ASK. Two ships reach the same wreck in the same second;
if both assume they won, both roll the loot, and the flag agreeing a moment
later does not take the module back out of the loser's hold. So the caller
does not get to act until it is told, and every caller has to actually read
the answer — which is why this returns a bool instead of quietly doing
nothing.

Solo returns true immediately: `Net.take()` answers with your own id when
there is nobody to ask.
```

## The shared bag

Above `func open_bag(n: MapGen.MapNode, drops: int, hands: int) -> void:`:

```text
What a shared kill left floating, rolled once and agreed by everybody.

`drops` is what the fight would have paid one ship. `hands` is how many ships
were still in it when the last hull came apart — `SharedFight.paid`, frozen by
the host so that four machines cannot each read a crew list at a different
point in its unwinding.

POSITIONAL, LIKE EVERYTHING ELSE THAT BELONGS TO A PLACE. `Rng.derive()` seeds
from the node index, so every machine rolls the identical bag without a byte
of it crossing the wire — the same trick that lets one seed put one wreck and
one shelf on four machines. What travels is only which parts are GONE, which
is the one fact a seed cannot carry.

Deliberately NOT off `Rng.loot`. That stream is salted by seat precisely so
that what is paid to a PLAYER differs per player; a bag is paid to the party,
so it must not.
```

Above `func take_from_bag(n: MapGen.MapNode, i: int) -> bool:`:

```text
Reach into the bag. Returns whether the part is now in your hold.

ASKS AND WAITS, for exactly the reason the wreck does: two ships reach for the
same part in the same second, and a flag that agrees a moment later does not
take it back out of the loser's hold.

The hold is checked BEFORE the claim, not after. Claiming a part you have
nowhere to put would burn it for the whole party — gone from the bag, in
nobody's hold — which is the shop's "ask, then pay" ordering seen from the
other end. It is also the solo bug that ordering already fixed once.
```

## Adopting party claims

Inside `adopt_party_claims()`, above `if o >= MapGen.OPTION_SITE and o < MapGen.OPTION_JETSAM and not n.options.is_empty():`:

```text
A PARTNER'S OWN OPTION IS NOT THIS SHIP'S. A claim names a slot
index, and past the rolled list a slot holds whatever each ship's
own `place` or `post_goal` appended there: their quest is not
mine, and a claim on it must not close my pickup or my quest at
the same index (`OptionTable.is_mine`). With the list rolled, a
slot off its end or holding a per-ship option is skipped; before
it is rolled the claim is kept, and `OptionTable.ensure` drops it
if it lands past the list.
```

Inside `adopt_party_claims()`, above `OptionTable.foreclose(n, o - MapGen.OPTION_SITE)`:

```text
A site option a partner took closes its exclusive group HERE
as well. Foreclosure is DERIVED, never replicated: every
machine applies the same rule to the same claim and arrives
at the same shut doors without a byte crossing the wire.
A node whose options are not rolled yet is caught by
`OptionTable.ensure` re-deriving on the roll.
```

## Topping up the deck

Above `func _top_up_deck() -> void:`:

```text
Fill spare mounts with more yard stock until the deck can actually be drawn
from.

The starting kit is one shape — a weapon, two systems, a utility — and the
frames are not. Four manufacturers drop a weapon mount, so on a LIGHT frame their
generic weapon had nowhere to go and two cards vanished, while the same ship
sat on spare system and utility mounts the kit could not reach. Probate,
Cygnet, Verity and Calyx lights opened two cards down on Korvan's for no
reason anyone chose.

The floor is a function of HAND SIZE, because that is what makes it matter:
a deck no bigger than the hand is not a deck, you simply hold all of it, and
light frames draw the most. So the ships that need the biggest decks are
exactly the ones this used to shortchange.

Distinct parts first, in two passes. Yard stock has three of each slot, so a
frame with spare mounts gets a Slug Thrower and a Ranging Scope rather than a
second and third Hull Plating — and a starting deck of nine identical cards
is not a deck either. The second pass allows duplicates only because a frame
can have more mounts than the yard has distinct parts for that slot.
```

## Gauges

Above `func max_hp(bare: bool = false) -> int:`:

```text
THE GAUGES. Chassis, then everything bolted to it.

Each of these used to return the hull's field and stop. That made four of the
six attributes pure chassis properties by accident rather than by ruling —
Sensors and Stealth summed `installed` because they had no gauge to derive
from, and the other four silently did not. Armour plating added no armour.

Summing here rather than in attr_hull() and attr_thermal() is the point: an
attribute is a READING of a gauge, so a plate that only moved the attribute
would be a plate that shows up on the ship tab and not in the fight. Combat
calls max_hp() and heat_cap(); it never calls attr_*().

`bare` reports the CHASSIS ALONE — no fitted modules. Only the attribute
block asks for it, and it asks so the display can separate what the ship is
from what you bolted to it. It is a parameter rather than six more functions
because the two readings must never be able to disagree about the formula.
```

## Cooling in transit

Above `func cool_in_transit() -> void:`:

```text
HEAT SHEDS BETWEEN SYSTEMS, NOT ONLY BETWEEN TURNS.

`dissipation()` was read in exactly one gameplay site — Combat.end_turn() —
so heat carried out of a fight stayed on the hull forever. Ten jumps later
the gauge still read what it read when the shooting stopped, and the only
ways down were a purge card, one event, or the next fight. That made the
number a fossil between fights, and it made "cool off before you go in" a
thing a player could want and had no way to do.

HALF A TURN'S WORTH PER JUMP, FLOOR OF ONE. Measured, not chosen: at a full
turn's worth the average signature on arrival fell from 0.32 to 0.05 over a
thousand runs, which did not make heat manageable between systems, it deleted
it. A jump you were making anyway must not be a free vent.

At half rate a medium frame carries a hard fight about six systems, a light
frame three, and a Solari heavy most of the way to the next station — the
same trade those hulls already make in combat, now visible on the map. The
floor of one exists so that the worst dissipation in the game still cools
eventually rather than fossilising at capacity for the rest of the run.
```

Inside `cool_in_transit()`, above `heat = maxi(0, heat - maxi(1, int(dissipation() / 2.0)))`:

```text
HALF RATE, and full rate was tried on 2026-08-25 and put back. The
argument for trying it was good and the measurement refused it.

THE ARGUMENT: an older comment here recorded full rate deleting the map
mechanic -- average arrival signature 0.32 down to 0.05 -- but that test
ran with in-combat dissipation still active, so fights ended cool and
full-rate transit was compounding an already-cool start. With the
end-of-turn shed now deleted, fights end near capacity, so full rate
should have been a counterweight rather than a second pull the same way.

THE MEASUREMENT, 500 runs each, combat change held constant:

    transit      arrival sig   arrived hot   ambush/run   win
    full rate       0.04           5.5%         0.21       30%
    half rate       0.07           9.4%         0.24       29%

Half rate is better on every axis the change was FOR, and the win rate
difference is inside the noise of 500 runs. So the ruling is reverted.

THE REAL FINDING IS THAT THIS RATE IS NOT THE LEVER. Fights now end at
0.31 signature -- more than double what they did -- and arrival is still
0.07 against a SIGNATURE_FLOOR of 0.25. Cooling is charged PER JUMP and
there are roughly four jumps per fight, so whatever a fight builds is
spent long before the next one. Halving the rate cannot fix that and
neither can doubling it; the dials that would are the per-jump floor
below, the number of jumps between fights, or the floor itself.

The floor of 1 stays regardless: it is what stops the worst dissipation
in the game fossilising at capacity.
```

## Ambush chance

Above `func ambush_chance(n: MapGen.MapNode) -> float:`:

```text
Whether something followed the heat in, and how likely that was.

Three terms, and the order matters. Signature is the gate: run cold and the
rest never applies. Danger scales it, because deep systems have more in them
to notice you. Stealth divides it last, so the hull and the modules you fitted
are the answer to a problem your own throttle created.
```

## Reactor level

Above `const CELLS_PER_LEVEL := 3`:

```text
WHAT A REACTOR LEVEL IS. Three cells of hardware, and a step of energy
every second level.

    REACTOR   4    5    6    7    8    9   10   11   12   13   14
    cells    12   15   18   21   24   27   30   33   36   39   42
    energy    3    3    4    4    5    5    6    6    7    7    8

THE LEVEL IS THE STAT AND THE OTHER TWO ARE READ OFF IT, which is the
opposite of how this started. It was a SCORE: you had energy and cells and
the bar weighed them into a number. That could not be read backwards —
REACTOR 10 meant "at least this good", not any particular ship — and on the
one gauge whose raw unit is printed directly under it, being unreadable
backwards is the whole complaint.

IT WAS AN ELEVEN-ROW TABLE AND THE TABLE WAS THE CEILING. Attributes go over
ten now (Pillar 5), and every other one of them does — but a lookup clamps at
its own length, so REACTOR alone stopped at 10 while the rule said otherwise.
Two lines of arithmetic have no length. The table is kept above as the
LADDER, which is what anybody actually wanted to read off it.

The arithmetic and the old table disagree at levels 1 and 3, by one point of
energy. Nothing in the game is ever there: the worst frame is 4 and nothing
lowers a reactor.
```

Above `const CELLS_PER_PIP := 3.0`:

```text
THE GRADE, AS A GAUGE. Output and capacity are one attribute because they
are one piece of hardware — the same argument THERMAL makes for heat
capacity and dissipation, and it is wrong here for the same reason it would
be wrong there to split them: a player asking "is this a good reactor" is
asking one question.

They are not interchangeable and the weights say so. Output is scarce and
enormous — three points of it across the whole ladder, and each one is a
card a turn — so it is worth 1.6 a point. Capacity runs 13 to 22 and buys
room rather than tempo, so it is worth a quarter of a point a cell.

DIVISORS PICKED SO THE TOP DOES NOT PIN, which is the mistake THERMAL made
once and documents above: an attribute everything good saturates is not a
measurement. A bare S frame reads 7 of 10. Reaching 10 takes the S grade,
the overspec perk and two couplings — a build that has actually spent
itself on power, which is what a full gauge should mean.

    C 2    B 3    A 5    S 7    S, perked and coupled 10
HOW MANY CELLS ONE PIP OF REACTOR IS WORTH.

Named rather than buried in the formula, because it is the number a coupling
is priced in: a part that raises REACTOR by 2 grants exactly two of these,
and Database derives its grant from here rather than authoring a 6 that
means nothing on its own.

Three, so the gauge and the cells stay legible together. REACTOR is the one
attribute whose raw unit a player COUNTS — thirteen cells of hardware is a
number on the ship screen, where nobody counts hull points — so a pip has to
be a quantity of them small enough to divide the ladder tidily and large
enough to be worth crossing.
```

Above `func attr_reactor(bare: bool = false) -> int:`:

```text
THE ATTRIBUTE IS THE STAT. No weighting, no offset, no formula — the bar
reads the reactor level, and the level is what decides the cells and the
energy. REACTOR 10 is thirty cells and six energy, on every hull in the
game, and a player who reads the bar and multiplies is right.

It is the only attribute that works this way, and it earned it: it is the
only one whose raw unit is printed on the same screen. HULL scores your
plating and THERMAL weighs capacity against vent because nobody counts
either of those; the ship screen counts cells under the mounts.
```

## Mounts and the reactor

Above `func can_power(m: ModuleData, replacing: ModuleData = null) -> bool:`:

```text
Can this part be RUN, ignoring whether there is a mount for it.

Two questions, never one. `slots_used < slots_for` asks whether the frame
has somewhere to bolt it; this asks whether the reactor can carry it. A
heavy has four weapon mounts and cannot power four four-cell cannons, and
the whole interest of the system is in the gap between those two answers.

`replacing` is the part coming off to make room, whose draw is freed first
— without it a straight swap of like for like would be refused at cap.
```

Above `func install_module(m: ModuleData) -> void:`:

```text
TWO BUDGETS, AND A PART HAS TO SATISFY BOTH.

A mount of the right kind, and reactor capacity to run it. They fail
differently and so they clear differently: no mount means the worst part in
THAT SLOT comes off, because a weapon cannot free a system mount; no
capacity means the worst part ANYWHERE comes off, because every cell on the
ship draws from the one reactor.

Worst by scrap value in both cases, which is the only ordering the game has
that means roughly "how good is this" — and it is the ordering the mount
rule already used, so a player who has learned one has learned the other.
```

## Manufacturer count

Above `func manufacturer_count(id: StringName) -> int:`:

```text
Modules from this manufacturer, PLUS the hull if it built one.

The hull counting is what makes choosing a chassis a build decision instead
of a stat decision: a Korvan hull puts you one module from Standard Issue,
and swapping to a found Redline frame costs you that piece. It is also the
price of the reversal — hull swaps are no longer identity-neutral, which the
old "hulls have no manufacturer" ruling existed to guarantee.
```

## Attributes

Above `# Attributes are functions of tracked state`:

```text
------------------------------------------------------------------- attributes

The six numbers events check against, per attributes-and-checks.md.

THE RULE, from §0: every attribute is a number the game ALREADY TRACKS. These
are functions, never fields. Nothing writes an attribute; there is no second
copy of your ship's condition to drift out of sync with the first, and no
"recalculate attributes" call anyone can forget after a refit.

The consequence worth stating out loud is that checks read the CURRENT value.
A holed ship really does fail Hull checks it would have passed at full — the
attribute is the damage, not a rating the damage is compared against.

All six are 0-6. The constants below are FIRST VALUES, tuned against the three
unbranded frames and not yet against the seven manufacturer hulls or against
any real event table. Expect to move them.
```

## Thermal

Above `const THERMAL_FLOOR := 8.0`:

```text
VENT, not "shedding". The card face says "Vent 3" and the field is called
dissipation; a third word for the same quantity in the comments is how two
halves of a game stop being about the same thing.

Thermal is capacity AND venting, per §1.4, because an event that asks "can
you sit in this heat" is asking about both and would otherwise need two
attributes to answer.

Capacity carries most of the weight, and this took a measurement to get
right. The first version was `cap/6 + diss/2.5`, which read 3 or 4 for every
chassis in the game — the Emberwright caps at 20 and vents 2, the Brood
Tender caps at 12 and vents 4, and the two terms cancelled so cleanly that
the heat manufacturer and the drone manufacturer scored identically. Weighting
capacity harder and subtracting a floor spreads it 2-6, with Solari at the
top where the whole manufacturer says it should be.

They are not interchangeable in fiction and must not be in the formula:
capacity is how much you can take, dissipation is how fast you get rid of it,
and only the first decides whether you survive sitting in a corona.

Divisors widened once already. At 2.4/2.0 the attribute saturated: five of
the seven heavy frames pinned at 6, so a Probate ore barge and a Solari
Furnace Baron read identically on the axis Solari exists to own. A ceiling
that everything large reaches is not a measurement. Now exactly one chassis
in the game reads 6, and it is the one built by the heat manufacturer.
```

Inside `attr_thermal()`, above `var v := (heat_cap(bare) - THERMAL_FLOOR) / 2.0 + dissipation(bare) / 2.0`:

```text
2.0 AND 1.0, NOT 2.1 AND 1.5, since the attribute ladder. Both fields are
ints, so a divisor that is not a whole number cannot carry a whole pip: a
rare vent asked for one pip, got 1.5 rounded to 2, and read back as two.
`-- attrtest` caught it on the first run.

The readings barely move — a medium reads 3 either way — because the change
is a rounding convenience and not a retune. What it buys is that one point
of venting is exactly one pip and two of capacity is exactly one pip, so
the ladder can be exact instead of nearly right.
BOTH TERMS AT 2.0, so one point of capacity and one point of vent are each
half a pip and a part that raises THERMAL raises both by one. The only
reading that moves is a light, 2 to 1, which is the correct direction for
the frame with the smallest tank and the least to shed.
```

## Sensors and stealth

Above `const SENSE_SCALE := 1.0`:

```text
Sensors and Stealth are the two with no other gauge in the game, so unlike
the four above they are summed rather than derived. Hull baseline plus fitted
modules — the same shape as the others, where the chassis sets the platform
and what you bolt on adjusts it.
Sensors and Stealth are authored in small whole numbers — a hull carries 0 to
2, a module 1 or 2 — because that is a legible thing to write in a data table.
The scale they are DISPLAYED on is a different question, so the conversion
lives here rather than in the catalog. At 1.7 the best sensor ship in the game
reads 7 and the stealthiest reads 9, which leaves both room to improve.
ONE, not 1.7, since the attribute ladder. A module now says how many PIPS
it is worth and the grade decides the number — so a scale that is not 1 makes
the two sensor axes the only ones where a rare part cannot deliver exactly
one pip: 1/1.7 is 0.59, the field is an int, and rare and epic both round to
a raw 1. Two grades reading identically is the failure THERMAL documents.

What it costs is headroom on the hull alone: a chassis carries 0 to 2 of
these and used to read up to 3.4 on its own. It buys something better —
Sensors and Stealth become axes you BUILD rather than ones the frame hands
you, because a legendary dish is now worth more than any hull ever was.
```

Above `func attr_sensors(bare: bool = false) -> int:`:

```text
AN ATTRIBUTE STOPS AT ZERO. The clamp on the return is what enforces it, and
these two are the only gauges that could ever have needed it — they are
summed straight off the hull and its modules, where every other attribute is
derived from a quantity that was floored on the way here: heat capacity at 1,
dissipation and dodge at 0.

A part that PRICES a gauge (see Database.PASSIVE_COST) can therefore take a
real pip off a build that has one, and takes nothing off a build that does
not. Both halves are checked by `-- attrtest`, which measures the price
against a supplier and then against an empty gauge.
```

Above `const HEAT_STEALTH_COST := 4.0`:

```text
Heat comes off the top of Stealth rather than out of the modules that grant
it, because it is the one thing on the ship you cannot bolt a cover over. A
cold Redline is the quietest thing in the galaxy; the same hull at capacity is
a lit match, and no amount of baffling changes that. Four of ten at capacity —
enough to lose a check you would pass cold, not enough to erase a build.

This is also what makes ambush_chance() a decision rather than a tax: the
stealth term there reads this, so running hot is punished twice through one
number, and fitting for stealth answers both.
```

## Bare hull attributes

Above `func hull_attributes(h: HullData) -> Array[Dictionary]:`:

```text
THE SEVEN GAUGES A HULL WOULD GIVE YOU BARE, with nothing bolted on.

Computed by standing the hull in place for the length of one call rather than
by copying the seven formulas out. Every `attr_*` reads `hull` and `installed`
off this singleton and none of them takes a hull argument -- so the only other
way to price a chassis you do not own is a second set of the same arithmetic,
which is exactly the drift `-- attrtest` exists to catch.

NOTHING IS EMITTED AND NOTHING IS SAVED. The swap is undone before the
function returns and no signal fires in between, so no listener can observe
the ship as anything but its real self. It is not re-entrant and does not need
to be: it is called from a panel refresh, on the main thread, once per draw.
```

## Hull pip wording

Inside `attributes()`, above `effect = "A pip is about %d hull. Your %d hull rounds to %d %s. This gauge reads CURRENT hull, so damage lowers it until you repair." % [`:

```text
READS CURRENT HULL, not maximum, which is worth saying out loud:
it is the one gauge that falls as you take damage, so a holed ship
really does fail a check it would have passed intact.

ABOUT 7, ROUNDED, AND THE SUM DONE ON YOUR OWN SHIP. It said "A
pip is 7 hull", and Geno (friends' alpha) held that against
Korvan's 29, 40 and 57 hull at 4, 6 and 8 pips: 6 x 7 is 42, not
40. The pips are hull over 7 rounded to the nearest, so the honest
line says about 7 and then does the sum on the hull you have. The 7
is HULL_REF over ATTR_MAX, not typed.
```

## Pulsar harvest

Above `const PULSAR_DROP := &"magnetar_silt"`:

```text
Fly a pulsar's beam: the densest fuel in the galaxy, paid for in hull.

The arithmetic lives here rather than in Router because the simulator has to
be able to run it. Anything that only exists on a screen is invisible to the
balance model, and a node type that hands out fuel and takes hull is exactly
the kind of thing the model needs to see.
What a neutron star leaves alongside. Named once so the grant, the log line
and the table cannot drift apart.
```

Inside `harvest_pulsar()`, above `add_material(PULSAR_DROP, gain_exotic)`:

```text
INTO THE SYSTEM, not into your pocket. What the beam throws off is matter,
and matter needs somewhere to be -- see `add_material`. It is beside you
in the sector and you load what fits.

AND IT HAS A NAME NOW. This granted `&"exotic"` -- an item literally called
"Exotic", the one placeholder left in a table where every other
exotic-tier row is a named thing with prose attached, and whose own text
had to straddle two unrelated sources ("Megafauna organs and whatever a
pulsar leaves behind"). Flying the beam is the game's most deliberate
trade and it paid out in a category name.

`&"exotic"` is still dropped by fauna, so any recipe asking for it by ID
rather than by tier is unaffected.
```

## Found hulls

Above `func find_hull(h: HullData, scrap: Dictionary = {}) -> void:`:

```text
A flyable hull, cut out of a wreck or claimed off an event.

THE THIRD THING THE RAIL SHOWS, and the only one that never went through
`stow()` — so it never bumped `hauls`, so a dismissed rail stayed dismissed
over it. Claim a hull after stowing and the transfer was never offered until
some unrelated haul happened to arrive.

Clears the dismissal outright rather than incrementing `hauls`: a hull is not
a haul, and the honest statement is "there is something new here", which is
what an undismissed rail means.

`scrap` is what cutting it up pays instead (`found_scrap`): the derelict
hauler passes its strip's pay; a wreck's hull passes nothing.

A FRAME STILL ON OFFER WITH ITS PAY IS CUT UP FIRST (`scrap_found_hull`).
Claiming a second derelict used to put the new frame over it, and the setter
wiped the old frame's pay with it: the strip you gave up, lost after all.
```

Above `func scrap_found_hull() -> bool:`:

```text
Cut up the hull on offer for what it carries (`found_scrap`): the credits,
and its crate on this system's pile, under SECTOR LOOT. Once: the hull is
gone after. False, and nothing moves, for a hull with nothing to pay.

THE LOG SAYS WHERE THE CRATE WENT, by name. It lands in SECTOR LOOT and not
in the hold, and with nothing on screen saying so Jon called it "super NOT
intuitive".
```

## The refit rule

Above `enum Refit { REFUSED, MOVED, FITTED }`:

```text
THE REFIT RULE: the one place a hand moves a part between the hold, the dock
and the hardpoints. Every screen a part can be dragged on calls these --
`ShipScreen` today, LOCAL's cutaway next -- so a swap means the same thing
wherever it is made. (`install_module` above is the simulator's and the
salvage dialog's "fit this somewhere": it picks the mount and clears room
itself; these take the mount the player chose.)

A part held in the hand is OFF the ship while it is carried: `lift_part`
takes it out of `installed`, and the caller remembers the mount it came from
(`lifted_from`) to hand back to `fit_at_mount`, `stow_at` or `unlift_part`.
```

Inside `fit_at_mount()`, above `var lifted := lifted_from >= 0 and not installed.has(m)`:

```text
Two fitted parts trading mounts EXCHANGE places rather than sending one to
the hold -- the mounts are visibly different positions on the ship.

A lifted part counts as fitted: it is off the ship while you carry it, so
`installed.has(m)` is false for exactly the move this branch exists for.
Without it, sliding a gun from one hardpoint to an occupied one sent the
resident to the hold instead of trading.
```

Inside `fit_at_mount()`, above `var was_at := m.hold_at`:

```text
The resident has nowhere to go but the hold, and if it will not fit there
the move is refused BEFORE anything has been taken off the ship.
`m` IS LEAVING: it is in the hold this instant and on the hull the next, so
the cells it occupies are exactly where the resident is going. Without
saying so, a full hold refused every swap -- including a part for one the
same size, which is a move that cannot fail. (`refit_allowed` asked it.)
```

Above `func refit_allowed(m: ModuleData, slot: ModuleData.Slot, index: int, lifted_from: int = -1) -> bool:`:

```text
WHETHER `fit_at_mount` WITH THESE ARGUMENTS WOULD FIT OR TRADE, moving
nothing: the refit rule's yes or no, and `fit_at_mount`'s own gate. Three
parts to it:
 - the mount's kind is the part's (a weapon on a weapon mount);
 - a part fitted or in the hand (`lifted_from` >= 0) TRADES with the one on
   the mount, always -- the resident goes where it came from, not the hold;
 - any other part (the hold, the dock) puts the resident in the hold, so the
   resident must fit there with the part's own cells counted free;
 - and that part, coming aboard, must be one the reactor can carry with the
   resident's draw freed (`can_power`), the rule the transfer screen's
   `pad_to_mount` and its hold-to-mount drop already kept. It was missing
   here, so the refit screen and the cutaway bolted on a part past the
   reactor's cells that every other way onto a mount refused.
An empty mount of the right kind says yes to a part the reactor can carry.
Nothing about the size or shape of the part decides a mount: only the
reactor, and the hold's room for the resident.
```

Above `func stow_at(m: HoldItem, at: Vector2i, lifted: bool = false) -> bool:`:

```text
A part (or any hold item) dropped onto CELL `at` of the hold: from the hold
itself, off the dock (`pad`), or off the ship (fitted, or `lifted` in the hand).
False, and nothing moved, when it does not fit there.

Separate from `fit_at_mount` because the two answer different questions: a
hardpoint asks "does this slot type match"; the hold asks "does this shape fit
here", and the cell it fits at is information a mount has no use for.
```

## Scrapping

Above `func scrap_module(m: ModuleData) -> void:`:

```text
Break a part down for scrap. Scrap ONLY.

It used to also yield alloy, and that is the half that is gone: a part turning
into a second resource made alloy behave like a second currency, which is the
thing the one-currency ruling exists to prevent. Scrap is what a part is
worth; the fabricator's prerequisites come from places you flew to, not from
the hold you were going to empty anyway.

SCRAP and MELT were one operation under two names — this function priced by
Market.melt() and wore a SCRAP label in every screen. The refit screen's melt
cell is gone; this is the survivor, and it is called scrapping.
```

## Ready to fly

Above `func ready_to_fly() -> Array[String]:`:

```text
Whether this ship can leave the dock.

TWO CONDITIONS, AND THE SECOND ONE IS NEW. An empty pad is obvious -- you
cannot fly away from crates on the ground. The deck is the one a hull swap
introduced: `_top_up_deck` fills spare mounts until a deck is playable and it
runs in `start_new_run` ONLY, so nothing rescues a ship that undocks bare.
Before this, `transfer_to_hull` re-mounted everything automatically and the
case could not arise; now it can, and the next fight would open with a hand
of nothing.

The floor is the HAND, not some authored minimum: a deck no bigger than the
hand is not a deck, you simply hold all of it. That is the same reasoning
`_top_up_deck` uses to pick its own target, one line apart.
```

## Mending a loadout

Above `func mend_loadout() -> int:`:

```text
A LOADED SHIP PUT RIGHT, for a save written by a build that could strand it
(0.4.1-alpha.1: Jon, Oct 23, "all the parts no longer appear for me to
transfer and now i can no longer undock from a station"). Run on every load,
and it changes nothing on a ship that is already right. NOTHING IS DROPPED:
every object goes somewhere you can see it and move it.

 - A FITTED PART ON A HARDPOINT THE HULL DOES NOT HAVE, or on one another part
   already holds, goes to the first free hardpoint of its kind; failing that,
   into the hold; failing that, onto the pad.
 - THE PAD WITH NO OLD SHIP UNDER IT (a save from before `old_hull` was
   written, or a frame that is gone): a part on it still remembers the
   hardpoint of a hull that cannot be drawn, so it would be drawn nowhere
   (`OldHold` leaves fitted parts to the old ship's picture). It forgets the
   hardpoint and is laid out in the old hold with the rest.
 - AN EMPTY PAD has no old ship either, so a stale frame cannot outlive it.

The pad itself stays a pad: what is on it is shown, by the move the station
opens whenever it is loaded (`Router.show_station`) and by the one a load in
space opens (`Router.resume_here`). Returns how many things it moved.
```

## Where you are

Above `func here() -> MapGen.MapNode:`:

```text
Where you are, or null when there is nowhere yet.

`node_at()` indexes the map and is right to: every caller inside a run is
standing somewhere, and a null return would only push the crash one frame
later. But the chassis select runs with a hull and no galaxy — you pick a ship
before there is anywhere to fly it — and it draws the HUD, which asks the
market what repairs cost here. This is the accessor for the handful of callers
that can legitimately run outside a run.
```

## Fuel per distance

Above `const FUEL_PER_DISC_RADIUS := 13.0`:

```text
Fuel is distance. Not a flat lateral rate and a flat coreward rate — those
made every jump on the chart cost the same 1 fuel no matter how far it
plainly was, which is why the numbers beside the systems looked like
decoration.

An ordinary hop is about 0.11 of a disc radius now that the field is even,
so this prices one at 1 fuel and a long reach across the cluster at 2.

The attrition of the frontier no longer comes from each hop being dear — it
comes from there being 42 systems on the rim ring and 14 at the core. Farming
the edge is a long haul rather than an expensive one, which is a cleaner way
to say the same thing.
Raised from 10. At 10 an ordinary hop cost 1 fuel out of a 150-unit tank, so
wandering was nearly free and a run averaged ninety-odd jumps — the greed
clock had no hands. At 17 a hop costs 2 and a long reach 3, which prices
farming without making the map hostile: measured, 62.9 jumps and a 20.3% win
rate against 93.6 and 21.5% at the old value.

Tuned AFTER fixing the simulator, not before. See HeadlessSim's jump policy —
the model used to wander on a coin flip regardless of fuel, and tuning this
against that would have made the real game punitive to correct a bug in the
thing measuring it.
13, down from 17, and this is a UNIT CONVERSION rather than a balance change.

`MapGen.hop_distance` used to measure in the drawn, foreshortened space and
now measures un-squashed (D1) -- it divides y by the galaxy's squash, which
averages 0.62, so every distance in the game grew by about a third overnight.
This constant prices raw distance, so the fuel bill grew with it: measured,
1.87 fuel a jump became 2.55, individual hops pinned at the FUEL_MAX_HOP
ceiling of 6, and 98% of runs ended adrift.

17 / 1.3 restores the rate the tuning below was measured at. Nothing about
how dear a jump SHOULD be has been re-decided; the ruler changed length and
the price per unit had to change with it.
```

## Fuel tank

Above `const FUEL_TANK := 45`:

```text
THE TANK HOLDS 45, and that is where a run starts. Jon, Oct 17: "Starting
with almost 280 fuel allows a player to basically jump all over the galaxy
without paying for gas once. Fuel should feel painful." Picked "fuel:A".

It was 279 -- 150/7 a ring-step of the galaxy, from when a flat 150 was tuned
against nine rings -- with no top. Measured on the corrected sim (seed 777,
200 runs, balance/fuel): a run that reaches the core burns 46-67 fuel, at
most 130, so the tank held four to six winning runs, no run ever bought a
can, and runs ended 90-92% full. Two other answers were flown and not
picked: pricing jumps by distance and danger on the same 279 (it charged
credits and the tank never felt low), and scarce, depth-priced docks with
fuel in wrecks (gentler, more to explain). The numbers are in the commit.

45 is about one winning run. 40 made a winning run stop 3.5 times at docks;
45 is the two or three Jon asked for. Every write to `fuel` is held under it
by the setter, so a refuel, a pulsar or an event cannot overfill.
```

## Nearest dock

Above `func nearest_dock() -> Dictionary:`:

```text
THE NEAREST DOCK YOU CAN REACH ON WHAT IS IN THE TANK, for the fuel hint
("Nearest dock: GAMMA BRINE PRIME, 2 jumps"). Fewest jumps first, then the
least fuel, over hops the ship can take when it gets there (`hop_seen`, the
rule `nearest_other_dock` routes on) and the drive allows
(`reachable_from`), each hop priced from where it starts, through no core.
{node, jumps, fuel}, or {} when no dock is in reach. Here counts when you are
docked: zero jumps.

NOT OVER THE CHART (Jon, Oct 18: "hint:fix"). `charted` also draws a
contract's system you have never seen and a visited one out of sight now,
and `can_jump_to` refuses both: the hint named a dock the ship could not fly
to.
```

Above `func hop_seen(here: MapGen.MapNode, from: MapGen.MapNode, t: MapGen.MapNode, dish: float) -> bool:`:

```text
WHETHER A ROUTE FROM `here` CAN TAKE THE HOP `from` -> `t` WHEN IT GETS
THERE: `can_jump_to` wants `sensed`, and sight is live (`chart_from` clears
it every arrival). The first hop is to a system seen from here now; a later
one to a system inside the dish of the star it leaves, which is what
arriving there will show. `dish` is `sense_radius_of(from)`, passed in so a
search works it out once a star. The routes the fuel hint and the dock's way
out are priced on, and nothing the chart merely draws.
```

Above `func nearest_other_dock() -> Dictionary:`:

```text
THE CHEAPEST OTHER DOCK TO REACH FROM HERE, and the fuel it takes, whatever
is in the tank: least fuel first, each hop priced from where it starts,
through no core and within one full tank. Here does not count. {node,
jumps, fuel}, or {} with none.

OVER HOPS THE SHIP WILL BE ABLE TO TAKE WHEN IT GETS THERE, which is not
the chart. `can_jump_to` wants `sensed`, and sight is LIVE (`chart_from`
clears it every arrival): the first hop is to a system seen from here; each
hop after it is to one inside the dish of the star it leaves, which is what
arriving there will show. Routing on `charted` sold fuel for a path whose
last star was out of sight from the one before it.
```

## No fuel dead ends

Above `func drain_fuel(n: int) -> void:`:

```text
AN EVENT TAKES FUEL THROUGH HERE, and leaves you the way out: the fuel to
reach a dock you can see, or with none in sight three of the cheapest jumps
from here -- room to go and find one. It never adds fuel.

Measured with the 45 tank before the events were rescaled to it: most
strands were one event emptying the tank (109 outcomes took 4 to 40 of a
279 tank), not a route the player chose. Leaving only the single cheapest
jump was tried first and moved the strand one system on.
```

Above `func dock_rescue(n: MapGen.MapNode) -> Dictionary:`:

```text
NO DEAD END AT A DOCK (Jon, Oct 18: "fuel:B"). The one strand the balance
check found that a person would hit: docked, the tank short of every other
dock, and the credits short of a can. Then the dock sells exactly the fuel
to reach the cheapest other dock (`nearest_other_dock`), never more, for
what that fuel costs here or for every credit you have when that is less,
down to none. {units, cost, rescue, dock}, or {} when it does not apply:
not docked here, a dock already in reach, the ordinary REFUEL affordable,
or no other dock on the chart within a full tank.

It cannot be farmed past the fuel to the dock: once bought, that dock is in
reach and the offer is gone. Flying off and back burns more than it returns.
```

## Thrust reach

Above `const THRUST_REF := 4`:

```text
Reference thrust, and how far a point above it stretches a jump.

REFERENCED TO THE LIGHTEST HULL rather than the middle, because this may only
ever ADD. See `thrust_reach`.

0.04 a point was deliberately small and turned out to be invisible: hull
thrust runs 4 / 6 / 8 by class, so a medium reached 8% further than a light
and a heavy 16%, and on a chart that is two or three pixels of ellipse.
Reported as "no matter what the thrusters are, the circle is the same size" --
which was not true and could not be told apart from true.

0.15 makes the class ladder legible: light 1.00, medium 1.30, heavy 1.60. The
cap moves with it, because at 1.4 a heavy hull would have been clamped before
it left the yard and the top of the ladder would have flattened again.
```

Above `func thrust_reach() -> float:`:

```text
How far this ship's engine stretches a jump, as a multiplier on the map's own
geometry.

THRUST WAS READ BY EVENT CHECKS AND NOTHING ELSE. `range_from` below derives a
radius entirely from how densely the galaxy is packed around you -- a fact
about the MAP, with no term in it for the ship standing on it. The gauge
described an engine that never moved anything, and a part that raised it
bought a slightly better roll on a Thrust check and no more.

IT ONLY EVER EXTENDS, and that is a safety property rather than generosity.
The radius carries a floor -- the third-nearest neighbour, so a sparse ring
still offers a choice rather than a corridor -- and a multiplier below 1.0
would cut straight through that floor and could leave a ship with no legal
jump at all. A low-thrust hull gets no bonus here; it does not get a penalty.

Heavier frames reach further and pay for it in fuel, which they already do:
`fuel_factor` prices every jump and runs 0.8 / 1.2 / 1.8. Long legs and a big
tank is a coherent thing for a hauler to be.
```

## Jump radius

Above `const JUMP_RADIUS := 0.18`:

```text
How much further than you can FLY you can SEE, per pip of SENSORS.

0.25 a pip against a base of the map's own jump radius: a dish worth two pips
shows you half again as far as you can go. Most hulls launch with no sensors
at all -- Korvan, Solari and Probate all read zero -- so this is a thing you
build toward rather than a thing you are given, which is what makes fitting a
dish a decision instead of a formality.
The sight a ship has with NO dish at all, as a multiple of the map's own
jump radius.

Sight is live now -- see `chart_from` -- so a ship at zero sensors would go
blind and selling a dish would take the chart with it. This is the floor that
makes that impossible: there is always a baseline neighbourhood.

ON THE RADIUS, NOT ON THE ATTRIBUTE. Flooring `attr_sensors()` was tried and
it breaks the gauge contract that `-- attrtest` enforces: with the pips
clamped to 2, a Rare part promising +1 sensors moved the gauge +0 and an
Artifact promising +4 moved it +2. A dish you fit has to do something. So the
attribute stays honest from 0 and the BASELINE lives here, which also means
every pip still buys the same 0.25 on top rather than the first two being
dead.

It is also the dial for whether a galaxy is playable at all. The base radius
is RELATIVE to your nearest neighbour rather than absolute -- `_map_range_from`
takes about 2.5x the nearest, floored at the third and capped at the sixth --
so a sparse frontier already widens it and a spawn in a system desert is not
the trap it looks like. If a kind still comes out unplayable, raise this
before touching the geometry.
How far a drive reaches, in galaxy units. A FIXED distance.

It used to be derived from local density -- 2.5x your nearest neighbour,
clamped between the third and sixth, which held the option count near six
wherever you stood. That worked and it hid the range: measured across one
galaxy the radius swung 5x, so the reach ellipse resized as the ship moved,
a rim jump crossed five times what a core jump did and was billed for it,
and thrust multiplied a local accident rather than a knowable number.

0.18 measured against the flattened rings in `MapGen.ring_count`: five
systems in reach at the rim, fourteen at the deepest, never none.

NOT scaled by the galaxy. `reach` already multiplies every position -- see
MapGen `gal = galaxy_pos(n) * reach` -- so a galaxy authored large is one a
fixed radius crosses in more hops, which is exactly what that dial is for.
```

Above `func _map_range_from(here: MapGen.MapNode) -> float:`:

```text
The same radius WITHOUT the ship, which is the half worth caching.

The galaxy's own geometry costs a pass over every system to work out and
never changes within a run; the engine's multiplier is a property of the ship
and moves the moment a part is fitted. Keeping them apart means bolting on a
thruster does not have to invalidate anything.
```

## What the chart draws

Above `func charted(n: MapGen.MapNode) -> bool:`:

```text
How far the ship can see, in the same units as the jump radius.

OFF THE MAP TERM, not off `range_from`, and deliberately: sight should not
quietly inherit the engine. A hauler with long legs is not more observant.
Does the chart draw this system?

ONE DEFINITION, because there were three and they disagreed. The screen had
it, `-- chartfilter` had a copy to measure against, and `-- sighttest` had
another -- so tightening the rule in the screen left both harnesses reporting
the old answer, confidently, in a table. A test that carries its own copy of
the thing it is testing measures itself.

Four reasons, and only the first is a sighting:

- `sensed` -- your dish has it right now. `chart_from` clears this every
  arrival, so it is live sight and not a memory.
- a station you have HEARD of -- WHICH IS NOW A SUBSET OF `visited` and admits
  nothing on its own. It was "a station next door to somewhere you have been",
  and that clause was cut on 2026-08-26 under a ruling that you can only see
  what you can see. What survived is `is a station AND (visited or here)`, so
  every system it admits was already admitted. Kept in the call below only
  because deleting a live-looking condition and its function in the same pass
  as a range change would make two things hard to tell apart; it goes on its
  own, next time this file is opened.
- a system somebody has PAID you to find. A contract naming a system the chart
  will not draw is a memory test.
- where you are standing.

- a system you have VISITED. Ruled 2026-08-27: *"The chart SHOULD draw the
  sectors that you have been, even if they're out of range. It's a historical
  marker."* It is not a claim about what is there NOW, which is why the chart
  draws it dimmed rather than lit -- see `StarchartScreen`'s remembered tint.

THIS WAS BRIEFLY REMOVED AND THAT WAS AN OVER-CORRECTION, worth recording
because the reasoning looked sound. Three reports of "systems outside my
sensor range" pointed at this clause, so it went. The reports were real and
this was not the cause: the ship in them had made a handful of jumps and the
systems it could see were SENSED, by a dish whose floor was 1.5x its own jump
range. Fixing the radius fixed the complaint; deleting history as well threw
away a thing the player wanted and had never objected to.

The lesson is not about charts. Two candidate causes were on the table, one
measured and one plausible, and both were changed at once -- so the fix could
not be told apart from the damage until somebody noticed the damage.
```

## Sight

Above `func sense_radius_of(here: MapGen.MapNode) -> float:`:

```text
The same radius around any system, not just the one under the ship.

Needed because SIGHT HAS TO HAVE THE SAME SHAPE AS REACH. `reachable_from` is
symmetric -- a hop is legal if EITHER end's radius encloses the other -- and
`chart_from` was not, so anything reachable only through the far end's radius
could never be seen, and criterion 1 then made it permanently unjumpable.

On a ring galaxy that is the core itself: it sits alone inside the hole, its
own neighbourhood radius is huge because its nearest neighbour is half a disc
away, and the inner ring can therefore reach it -- but never sensed it, so the
ship circled the rim until the run ended. Collisional Ring: 0% wins, 233 jumps.

It reads sensibly too. A system that dominates a large empty region is one you
can pick out from further off than a system crowded in among others.
```

Inside `sense_radius_of()`, above `return _map_range_from(here) * (SENSE_FLOOR + float(attr_sensors()) * SENSE_REACH)`:

```text
THE DISH ALONE, and nothing about the engine. Ruled 2026-08-28: a thruster
buys reach and a dish buys sight, and neither pays for the other.

SO REACH CAN OUTRUN SIGHT, on purpose. A heavy hull with no sensors flies
1.6x the base radius and sees 1.0x, and the systems in the gap are drawn,
priced, and refused -- `can_jump_to` wants `sensed`, and the chart says NOT
SCANNED rather than inventing a reason. That is the trade being legible: an
engine with no dish behind it is range you cannot spend.

This USED to be `maxf(range_from(here), ...)`, which kept the two in step
and was defended on the grounds that a reachable-but-unseen system is a
trap. It is not a trap once the screen says so; it is a reason to fit
sensors. The floor stays 1.0 because it now means one thing only -- what a
ship with no dish at all can make out, which is about five systems.
```

Above `func chart_from(here: MapGen.MapNode) -> void:`:

```text
Mark everything within sight of `here` as charted.

STICKY, WHICH IS THE WHOLE DESIGN. `station_heard` refuses to scale with
sensors because a chart that forgets a system when you sell a dish is worse
than one that never showed it. A mark that is only ever SET has no such
failure: refitting costs you what you have not seen yet and never takes back
what you have. See MapGen.MapNode.sensed.

Called on arrival and at the start of a run, so the first thing a dish does
is show you where you are standing.
```

Inside `chart_from()`, above `for n in map:`:

```text
LIVE, NOT REMEMBERED. This mark used to be set and never cleared, so the
chart accumulated every system the dish had ever swept and the galaxy was
solved after enough hops. Clearing first is what makes the frontier dark
and what gives a better dish something to buy.

`visited` is NOT cleared and is a separate reason to draw a system -- see
StarchartScreen._visible_set. Where you have BEEN is a track record rather
than a sighting, `Run.trail` draws it, and it is what you plan routes
through. Nor are `station_heard` or a contract's marker: those are things
you were TOLD, and being told does not stop being true when you move.
```

Inside `chart_from()`, above `for g in map:`:

```text
THE CORE IS NOT SOMETHING YOU FIND. It is the galactic centre, it is where
the run ends, and the chart names it from the first frame -- so criterion 1
should never be what stands between a ship and the objective.

It has to be said explicitly because the core is the one node that sits
outside the rings. On a galaxy with a hole it is alone in the middle, half
a disc from its nearest neighbour: `reachable_from` allows the hop through
the core's own radius, and `chart_from` -- which only ever measures YOUR
dish -- could never mark it seen. Collisional Ring: 0% wins, 233 jumps
spent circling a rim, because the destination was unsensed and unjumpable.
```

## Balance study flags

Above `var study_ambush_deep := 0.0`:

```text
BALANCE STUDY FLAGS (balance/run-length, Oct 22: Kevin reached the core in
seven jumps). Every one is OFF by default and only `-- sim` /
`-- sheet=RunLengthStudy` set them, from the command line; with them off the
game is what it was. They exist so the options Jon is choosing between can
be flown, not so any of them ships. (The first of them, a depth cap, did
ship: see DEPTH_STEP.)
  study_radius_rim / study_radius_deep: the jump (and dish) radius as a
                   multiple of JUMP_RADIUS at the rim ring and at the last
                   ring, lerped by the ring the hop is measured from.
study_ambush_deep  p > 0: arriving in a system of danger 7+ is an ambush
                   roll of at least p per point over 6 (danger 10: 4p),
                   whatever the ship's heat -- deep space bites on arrival.
```

## Depth cap

Above `const DEPTH_STEP := 2`:

```text
TWO RINGS DEEPER A JUMP, AT MOST (Jon, Oct 27: "Two rings now"). Outward
and along a ring are as far as the drive reaches.

It was here once and was dropped in August, when range became relative to
your nearest neighbour and was local by construction. Range went back to a
fixed 0.18 (`JUMP_RADIUS`) and the cap never came back with it, and 0.18 is
about three ring gaps (`MapGen.RING_GAP`, 0.062): Kevin, the first outside
playtester, reached the core in seven jumps, and the run-length study
measured six as the shortest way in and a straight dive winning 24% of runs.
The cap came back at ONE ring (Jon, Oct 22: "A1D ... I want this to be a
hard game"), and the shortest way in was one jump a ring, fourteen. At two
rings it is half that, seven (`-- maptest` measures it): the drive's reach
is three ring gaps and the cap now spends two of them, so a dive is still
held back, by a jump in three.

Its cost is a system you can plainly see is nearer than one it offers,
refused because it lies three rings in. That is answered by SAYING so
rather than by dropping the rule: the chart's JUMP button reads TOO DEEP,
the fuel row `StarchartScreen.DEPTH_ROW`, and the hover tag TOO DEEP
(`StarchartScreen`), so a refusal always has a reason on screen.

`MapGen._ensure_flyable` walks the galaxy by the same rule, so every ring
has a way in for the slowest ship (`-- maptest` sweeps it).

A var, not a const, only so `-- sim depthcap=N` / `-- sheet=RunLengthStudy
depthcap=N` can fly another rule for comparison (0: no cap, August's; 1:
Oct 22's one ring).
```

## Reachable

Above `func reachable_from(here: MapGen.MapNode, n: MapGen.MapNode) -> bool:`:

```text
Close enough to fly to: within two rings deeper (`too_deep`), and then pure
distance.

Charted links do not grant passage either: a link is how generation
guarantees the galaxy hangs together, not a promise that the place is near.

SYMMETRIC, and it has to be. Range is relative to the neighbourhood you are
standing in, and two ends of one hop can disagree about it: out on a thin
frontier your nearest neighbour is far, so the radius is wide and a crowded
cluster three parsecs off is a legal jump — and once you are down in that
cluster your nearest neighbour is a hand's width away, the radius shrinks to
match, and the way you CAME IN is suddenly out of range. A one-way door, and
the chart still draws the link you flew. So a hop is legal if either end
thinks the other is close: n is in my neighbourhood, or I am in n's. The
fuel cost is distance-priced already, so a long way back is expensive rather
than impossible.
```

Inside `reachable_from()`, above `if n.type == MapGen.NodeType.CORE and here.layer >= MapGen.LAYERS - 2:`:

```text
THE FINAL APPROACH IS ALWAYS AVAILABLE FROM THE LAST RING.

The core sits at the centre, at radius zero, while the innermost ring sits
at `CORE` -- about 0.11 -- so in an ordinary galaxy a fixed reach of 0.19
covers that last hop with room to spare and this rule changes nothing.

A galaxy with a HOLE is the exception it exists for. `galaxy_pos` maps every
ring into the annulus above `ring`, so on a Collisional Ring the innermost
ring is at 0.52 and the core is still at zero. Nothing can cross that: the
old density-derived radius grew in the sparse middle and bridged it, and a
fixed radius cannot. Measured without this: 0% wins and 317 jumps spent
circling a rim that has no way in.

Shrinking `ring` instead would need it under about 0.09 to close the gap
geometrically, which is not a ring galaxy any more.

It is the same argument as the core being permanently charted: the middle
of the galaxy is where the run ENDS, and it should be the danger that stops
you there, never the geometry.
```

## Can jump to

Above `func can_jump_to(n: MapGen.MapNode) -> bool:`:

```text
The three criteria, and they are the whole rule: SEE it, AFFORD it, REACH it.

`n.sensed` is the first of them and used to be missing. It was set by
`chart_from` and read only by the chart's visible set, so sensors decided what
was DRAWN and never what could be flown to -- and because sight and reach come
off the same base with different multipliers, any ship whose thrust outran its
dish could jump to somewhere it had never seen.

Sticky, so this is "have you ever charted it", not "is it lit up right now".
That is `chart_from`'s design and the right reading here too: a place you
surveyed last ring does not stop existing when you move on.

Cannot stand a ship still. Sight is base * (1 + sensors * 0.25) and reach is
base * thrust_reach(), thrust_reach is floored at 1.0, so everything within
the base radius is always both -- and that set is never empty.
```

## Stations heard

Above `func station_heard(index: int) -> bool:`:

```text
True when the ONLY reason this system is on the chart is that you signed for
it — not visited, not a station, not reachable from where you stand.

Signing reveals WHERE, and nothing else. You are told a place exists and given
its name, because a job that names a system you cannot find is a memory test;
you are not told what is in it, how policed it is or who operates there,
because none of that was in the offer. The manufacturer said go here. It did not say
what here is.

That asymmetry is the whole point and it is worth not smoothing away later: a
contract is a REASON to fly somewhere unexplored, and it stops being one the
moment accepting it also explores the place.
A STATION YOU HAVE HEARD. Stations are on the chart before you visit them,
and this is how far "before" reaches.

The exception itself is right and stays: the filter is correct about a place
you might GO and wrong about a place you navigate BY. A station means "you can
stop here" — repairs, fuel, a market, no danger — and it is most valuable to a
ship that has not found one yet, so hiding it until you have already been
there is backwards.

WHAT WAS WRONG WAS THE RANGE, WHICH WAS INFINITE. Every station in the galaxy
sat on the chart from the first frame of a run, so KNOWN ONLY drew the four or
five systems you had actually been to and then every station out to the rim —
a view of what you have earned, dominated by the one thing you had not earned
any of. It read as a bug because it was one: a filter whose exception is
larger than its rule.

ONE HOP, and the fiction is the mechanism: a station broadcasts, and you pick
it up from next door. Having stood in a system means having listened there, so
a station adjacent to anywhere you have been is a station you know about, and
one four layers away through systems you have never seen is not.

Deliberately NOT scaled by SENSORS, though it is the obvious next move and the
attribute would carry it well. A beacon range that changes when you swap a
dish means the chart forgets systems when you refit, and a map that loses
places you were told about is worse than one that never said.
```

Inside `station_heard()`, above `return false`:

```text
AND NOTHING ELSE. A station used to be revealed when any VISITED system
had a `link` to it, which is a relationship that governs nothing -- links
are the graph the chart draws, not the one the ship flies -- and a link
can be long. Swapping it for `reachable_from` was more defensible and
revealed MORE, because a radius is wider than a link.

Ruled 2026-08-26: you can only see what you can see. Sight is live, and a
station is a place you sensed, or a place you have been. The old comment
above objects that a chart which loses places you were told about is worse
than one that never said -- and that is answered rather than overruled,
because nothing is lost now: the mark is never gained in the first place,
so no refit and no departure can take it away.
```

## Science data

Above `func add_data(n: int) -> void:`:

```text
---------------------------------------------------------------------- science

DATA, the dealt board and the routines bought on it (Phase 12, Jon's picks
1A and 2B, Nov 4). The catalogue is `DB.routines`; what each routine does is
read where it happens (plan S3). All of it is the RUN's, never the hull's: the
Lab writes into the flight computer and the computer goes to any hull.
```

## Deal this runs board

Above `func deal_board() -> void:`:

```text
DEAL THIS RUN'S BOARD (pick 2B): per branch, one of its four routines is
dropped and the three left keep their order, weakest first, so the prices
(4, 10, 15) always climb with the power. 4 boards a branch, 64 in all.

Off `Rng.derive(&"board", seat)` and NOTHING ELSE: dealing it draws from no
stream, so a run with science moves no world, loot, event, foe or fight roll
(`-- rngtest`), and `science=off` stays the run main would fly. By SEAT, so
each ship of a party has its own board and seat 0 is the solo board on that
seed. `Rng.seat` rather than `Net.seat()`: the two agree at a new run, which
reseeds from `Net.seat()`, and at a load only Rng has the saved seat back.
```

## Hellbender ascension

Above `const HELLBENDER_ASCENSION := 7`:

```text
THE ASCENSION LEVEL THE HELLBENDER FIRST FLIES AT (Jon, Nov 8: "ONLY have
the hellbender show up on Ascention 7+"). Below it the rival never spawns,
so nothing that reads `hellbender_alive()` (the chart, the blockade, the
log, the drawer, its fight, its music, the co-op pushes) has anything to
show. The hiring boards still name it at every level, as a hint of what is
coming (Jon's follow-up); they promise no bounty (`BoardSignTest`).
```

## Weapons fill from the nose

Jon, Nov 13: "Can we have the default hardpoint locations put the weapons at the
front of the ship instead of both on top?", then: "The hardpoints shouldn't change
themselves, just the order in which they are filled, yes?" No mount moved. When
nobody chose a hardpoint (the starter kit, the top-up, an install, a part put back
from a broken save), `free_mount` takes weapon mounts in `mount_order`: by the
mount's x on the hull's art, nose first (every hull faces +x in its art, and the
LOCAL mirror flips the drawing, not the indices), level x by index. Systems and
utilities still fill lowest first. A part the player bolted on keeps its mount,
and a save keeps what it stored. Measured on the starter kits: the Korvan-art
light and heavy were already nose first (their first two mounts share the
nose's x); Korvan's three-mount medium (Korvan's Anvil, Redline's Moonrunner)
moves its second gun from the top deck aft (201, 42) to the nose's lower mount
(271, 89); Solari's Prominence and Nova take their nose mount (292, 63) and
(340, 80) first. The two-mount mediums of the manufacturers on Korvan's art already
filled the forward mount first.
