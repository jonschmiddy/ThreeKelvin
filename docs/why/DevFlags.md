The reasoning behind `tkg/scripts/DevFlags.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Tables

`Main._ready` used to be one `if "x" in OS.get_cmdline_user_args()` chain of about seventy-five flags; `DevFlags` is the same chain as four ordered tables. A flag is a bare word anywhere in the arguments (`flag`) or an `x=` prefix (`starts`), and the FIRST row that matches wins, so a table's order is the order the chain tried them in. Do not sort a table: `chartshot quest` once opened `quest` because it came first.

Each row is how it runs: `quit` builds the script and calls `run()` then quits the tree; `hold` calls `run(tree)` and keeps the object in `held`; `add` makes it a child of Main (`sheet=<Name>` fills in the `%s`); `fn` calls a method here. A row that ends `_ready` returns true; `quest`, `party` and `charttest` do not, and the next row is tried. `unless` skips a row when another word is present.

The four tables are the four moments the old chain ran at. `EARLY` runs before any UI and before `Router.register`, `REGISTERED` after it, `BOOTED` after the launcher (or run, or lobby) is up, and `SHORTCUTS` is the old `if cards / elif parts / elif ship ...` chain: one dispatch that stops at the first match and lets `_ready` go on to the shot flags. Moving a row between tables moves when it runs.

The sections below were moved here from `docs/why/Main.md` with the code. "Inside `_ready()`, above `if ...`" names where the comment sat in the old chain, which is now a table row; "held in a member" is now `held`.

## Test flags

Inside `_ready()`, above `if "attrs" in OS.get_cmdline_user_args():`:

```text
Every starting chassis and what it reads on the six attributes:
  godot --headless --path . -- attrs
Attribute constants are tuned by staring at this table, and the numbers are
only meaningful against each other — a column at a time, not a ship at a
time. Reading them off a UI one manufacturer per screen is how you convince
yourself a spread exists that does not.
```

Inside `_ready()`, above `if "checks" in OS.get_cmdline_user_args():`:

```text
Every event option, its badge, and 10,000 rolls of its ladder:
  godot --headless --path . -- checks
A skill check fails silently in both directions — an option nobody can
ever pass and an option nobody can ever fail both look like working code
and read like working prose. This prints what each one actually costs
against a real ship, and proves the odds table matches the rolls.
```

Inside `_ready()`, above `if "sky" in OS.get_cmdline_user_args():`:

```text
Every sector sky on one sheet, and again behind a real ship:
  godot --path . -- sky
Needs a window, not because it shows one but because SpaceBackdrop is
drawn by the renderer — under --headless the viewports it grabs come back
blank. Written to user:// and the path is printed.

It exists because procedural art is tuned by comparing a dozen rolls at
once. Reaching twelve different systems in a run to see twelve skies is
not a way to find the one that is too bright.
```

Inside `_ready()`, above `if "nettest" in OS.get_cmdline_user_args():`:

```text
Four peers, one process, and the whole join handshake:
  godot --headless --path . -- nettest
RUN THIS AFTER TOUCHING ANYTHING IN scripts/net/. Held in a member for the
same reason the sky test is: it runs across frames rather than inside one,
and a RefCounted that only a local variable holds is freed the moment this
function returns. It quits the tree itself when it is done.
```

Inside `_ready()`, above `if "fit" in OS.get_cmdline_user_args():`:

```text
Every specification class of a hull with real art:
  godot --headless --path . -- fit
  godot --headless --path . -- fit damage=3
RUN THIS AFTER TOUCHING HullFit. The second form composes it with wear,
which is the pairing that matters: fittings go on before damage, so a
bolt-on can be shot off.
```

Inside `_ready()`, above `if "content" in OS.get_cmdline_user_args():`:

```text
Every hull's mounts against its own opaque pixels. The lines are measured
per sprite, so the failure worth catching is a hull carrying ANOTHER
hull's lines — which draws guns in mid-air and throws nothing.
The hold's packing rule, against every hull's grid. The failure is invisible
in the data — two parts sharing a cell still add up to a sensible "17 of
28" and still save and load — so it is only ever seen on screen.
How much of the catalogue exists, against how much is meant to:
  godot --headless --path . -- content
```

Inside `_ready()`, above `if "systemtest" in OS.get_cmdline_user_args():`:

```text
What a rarity actually buys, in card numbers:
  godot --headless --path . -- rarity
Is the galaxy traversable, and how short is the short way:
  godot --headless --path . -- maptest
Does the option roller obey its own rules -- positional, gated, in plan:
  godot --headless --path . -- optiontest
Does the system map's layout keep its promises:
  godot --headless --path . -- systemtest
```

Inside `_ready()`, above `if "attrtest" in OS.get_cmdline_user_args():`:

```text
What every frame launches with, and whether the reactor ladder leaves it
a deck:
  godot --headless --path . -- reactor
What the chart's KNOWN ONLY view actually shows:
  godot --headless --path . -- chartfilter
Does a part move the gauge its grade promised:
  godot --headless --path . -- attrtest
```

Inside `_ready()`, above `if "transfertest" in OS.get_cmdline_user_args():`:

```text
The salvage rail, driven through the real screen and a real jump — the one
thing unit assertions on the rule cannot see:
  godot --headless --path . -- stowtest
The container, checked on what it DRAWS. Beside stowtest and for the same
reason: it builds a real screen and needs a live tree, but no pixels.
  godot --headless --path . -- transfertest
```

## Bot flag

Inside `_ready()`, above `if "bot" in OS.get_cmdline_user_args():`:

```text
A ship in the party that nobody is sitting in front of:
  godot --headless --path . -- bot join ABC-123
  tools/bot.sh ABC-123
It joins by lobby code like a person, rolls its own chassis and holds its
own Run. Returns before the UI for the same reason cofight does — there is
nobody to show it to — and registers Router a holder of its own, because a
bot flies through the same Router the humans do. See scripts/net/BotPilot.
```

## Art prompt

Inside `_ready()`, above `if "artprompt" in OS.get_cmdline_user_args():`:

```text
One PNG per ship, straight out of ShipView's own canvas:
  godot --headless --path . -- shipsheet
Each hull twice, bare and loaded, because the question is not whether a
ship draws — it is whether the ship that draws is the one described. It
needs no renderer at all: the view composites into an Image, and the
Image is the file. See ConvoyTest.
A PixelLab prompt, built from a manufacturer rather than from memory:
  godot --headless --path . -- artprompt korvan structures
RUN THIS BEFORE GENERATING ANY MANUFACTURER'S PARTS. It reads the fiction live from
DB.manufacturers so a prompt cannot drift from the tooltip a player reads,
and it carries the two settings that were learned expensively: force the
palette, and send no init image or transparency is silently dropped.
```

## Co-fight test

Inside `_ready()`, above `if "cofight" in OS.get_cmdline_user_args():`:

```text
Two processes, one enemy:
  godot --headless --path . -- cofight host
  godot --headless --path . -- cofight join CODE
  tools/cofight.sh                    (both, paired by the printed code)
RUN THIS AFTER TOUCHING Combat's shared path. nettest cannot reach it:
`Run` is a singleton, so one process holds one ship, and every line in
Combat that talks to the party needs a second one. Held in a member for
the same reason nettest is. AFTER `Router.register` (moved Oct 22): it
starts runs and fights through Router, whose screens need a holder, and
before it every swap threw ("Cannot call method 'add_child' on a null
value", a hundred times a run) while the verdict still said PASS.
```

Inside `_ready()`, above `if "cojoin" in OS.get_cmdline_user_args():`:

```text
Two processes flown the way two friends fly -- one system, one fight,
apart and together again -- through the real screens:
  godot --headless --path . -- cojoin host
  godot --headless --path . -- cojoin join CODE
  tools/cojoin.sh [relay] [late]
AFTER `Router.register`, unlike cofight: LOCAL and the SECTOR map are
what it checks. See scripts/sim/CoJoinTest.gd.
```

## Dev shortcuts

Inside `_ready()`, above `if "questrun" in OS.get_cmdline_user_args():`:

```text
Dev shortcut: drop straight into a fight with a hand of cards.
  godot --path . -- fight
Card work is 90% of what gets iterated on and reaching a fight normally
costs a jump, a sector screen and a loading pass every time you change a
pixel. Deliberately not a menu item — it skips the run the balance depends
on, so it stays a flag you have to type.
Star chart cache test. Needs the real shell and a window, so unlike the
sim and savetest it runs after boot rather than instead of it:
  godot --path . -- charttest
The sector with a party in it:  godot --path . -- convoy
Needs a window, and runs after boot rather than instead of it, because it
photographs the real screen — the arena, the salvage rail and the hand all
competing for the same width, which is the whole question. The party is a
fabricated ROSTER and no port is opened.
`-- party 6` opens the party page against a fabricated roster.

Same argument as `-- convoy`: the page's whole subject is other people, so
without this the only way to look at it is to start six Godot processes and
fly them to the same place. The roster is faked, not the screen — what is
drawn is the real PartyScreen reading the real Net.roster.
`-- cargo` starts a heavy run with a hold full of materials, and then hands
the game back to you.

Not a screenshot. `-- shipshot heavy cargo` photographs the same hold and
quits, which answers "does it draw" and not "does it feel like anything to
pack". Materials are a SPATIAL toy -- the whole ruling behind them is that
they do not stack, so every one is a decision about room -- and that is not
a thing a still image can be judged on.

One of every shape first, then a spread of tiers, then whatever else fits.
`-- questrun` places one and opens the chart on it, then hands the game
back. NOT `quest`: every mode here matches on a bare word appearing
anywhere in the arguments, so `-- chartshot quest` matched this first and
quietly opened a playable game instead of taking the photograph.

A PLACEMENT CANNOT BE POSED. It is the consequence of an option resolution
several jumps back, so the only honest setup is to make the call the
outcome makes and let it choose its own target the way it will in a real
run. `-- chartshot quest` photographs the marker and quits, which answers
"does it draw"; this answers "can you find it, and does the chart still
read with it on".

`flown` first, because a fresh chart shows every system as currently
sensed and the marker is most interesting on a system you CANNOT see --
which is the one rule it deliberately breaks.
```

Inside `_ready()`, above `if "cargo" in OS.get_cmdline_user_args() \`:

```text
NOT WHEN IT IS A SHOT'S ARGUMENT. `-- shipshot heavy cargo` matched this
first, the same way `chartshot quest` once matched `quest` above, and opened
a playable game where the photograph should have been -- which from outside
looks exactly like a shot that hangs.
```

Inside `_ready()`, above `if "quest" in OS.get_cmdline_user_args():`:

```text
`-- quest` signs the first fetch and the first hunt it can find and opens
the chart on them.

The rings are the only part of the contract system living on a screen you
cannot reach from a station, so without this the only way to look at them is
to fly to a station, sign something and fly to the chart — three screens
away from the thing being changed. Same argument as `-- party` and
`-- salvage`: the contracts are faked, the chart is not.
```

Inside `_ready()`, above `if "artdemo" in OS.get_cmdline_user_args():`:

```text
The refit screen at a chosen weight:  godot --path . -- shipshot heavy
Needs a window and runs after boot, same as convoy. The heavy is the
default because its 6x5 hold is what any change to that panel has to clear.
Every drawn part on one ship, live:  godot --path . -- artdemo
AFTER BOOT, beside shipshot and not up with the headless checks: show_ship
needs the Router to have been handed a content node, and the branches above
run before that exists.
```

Inside `_ready()`, above `elif "parts" in OS.get_cmdline_user_args():`:

```text
Every module in the game, on one page:  godot --path . -- parts

Same argument as `-- cards` one line up, one level out: a part is what you
find and pack, and the only way to see one used to be to be handed it.

An ELIF, in the chain, and not an `if` of its own beside it. Written as a
separate `if` it silently re-parents the `elif` under it — `-- ship` would
then be testing whether `parts` was absent rather than whether `cards`
was. That has happened here before and cost an afternoon.
```

Inside `_ready()`, above `var flags := OS.get_cmdline_user_args()`:

```text
WHICH weight, for comparing the three hull sizes: `-- ship heavy`.
Inside this branch rather than in front of the chain — put in front,
the `elif` below binds to IT instead of to the flag above, and every
other dev flag silently stops working.
```

## Coroutine tests

Inside `_ready()`, above `_chart_test = load("res://scripts/sim/ChartTest.gd").new()`:

```text
Held in a member, not called on a throwaway. ChartTest.run() awaits,
and a RefCounted nothing holds a reference to is freed the moment the
calling statement ends — the suspended coroutine goes with it and the
test dies silently after its first print. SaveTest gets away with
`load(...).new().run()` only because it never awaits.
```

## Ship shot

Inside `_ready()`, above `for i in 8:`:

```text
The refit screen normally sits two clicks and a chassis choice away,
and it is where the attribute block lives — so the screen that most
needs looking at was the most tedious to reach.

Seeded with a hold, because the screen is a workbench now and an empty
hold tests half of it. Eight parts across the rarity range: enough to
fill the storage grid past one row, and enough that a swap has
something worth swapping to.
```

Inside `_ready()`, above `for a in flags:`:

```text
NAME A MODULE AND IT GOES ON THE HULL: `-- ship lattice`.

The eight above are a random hold, which is right for exercising the
workbench and wrong for looking at ONE part. Checking a sprite meant
rolling until the part turned up, and a 2x2 unbranded system module
does not turn up often. Any argument that matches a module id is now
built and installed, so the thing you want to look at is bolted on
when the screen opens.

Duplicated, for the reason `fit_chassis` gives at the same call: the
catalogue entry is shared, and a run that mutates it moves that part
on every ship in the game.
```

Inside `_ready()`, above `if "mixed" in flags:`:

```text
TWO OTHERS, not three. Mounts are finite and these displace the parts
fitted above, so three of them on a heavy left the hull manufacturer at
four -- lit, but one short of the tier that breathes. Two leaves five,
which is the only loadout that shows all three chip states at once.
```

## Station shot

Inside `_ready()`, above `var here: MapGen.MapNode = Run.node_at()`:

```text
The dock, immediately. Added when the station became four panels rather
than two — a shelf, a service desk, a buyer for the hold and a
fabricator — and reaching it normally costs a chassis choice, a jump
and a sector screen every time one of those four moves a pixel.

It also gives the merge gate something that CONSTRUCTS the screen. The
boot check only ever built the launcher, so the busiest screen in the
game was the one nothing automated had ever drawn.
```

Inside `_ready()`, above `var deep := "full" in OS.get_cmdline_user_args()`:

```text
Something in the hold to sell, something to scrap, and enough of every
material to light up the fabricator and the material rows.

`full` PACKS THE HOLD UNTIL NOTHING MORE FITS and guarantees a hull on
the blocks. Every one of these five decks behaves differently when it is
busy -- the Exchange scrolls, the Yard offers, the Promenade fills its
list -- and the three-item hold this flag used to build showed none of
that. `hold_full()` is the honest test: it asks whether ONE CELL is
free, so the loop stops where the packer actually stops rather than at a
count somebody guessed.
```

Inside `_ready()`, above `for i in 40:`:

```text
A BOUND ON THE LOOP AS WELL AS A TEST. `stow` can refuse a part that
does not fit while a smaller one still would, so `hold_full` alone
is not guaranteed to flip -- a 2x2 bouncing off a hold with four
separate single cells left would spin here forever.
```

Inside `_ready()`, above `var want := 4`:

```text
FOUR OF THE BERTH'S OWN PARTS BOLTED ON.

A fresh run counts two toward a set -- the hull and one starter module --
and the HUD's set-bonus chip appears at three. So the state this flag
built was the one state that could not show the chip, on the screen the
chip was added to. `sets=N` asks for a different count.
```

## Salvage shot

Inside `_ready()`, above `var many := 8`:

```text
`-- salvage 8` opens the sector with eight parts in the hold.

The salvage rail is the one panel in the game whose layout only
misbehaves at sizes a normal run reaches late — a lawless run pays two
modules a fight — and it misbehaved by growing the PAGE rather than
itself, which pushed the hand strip off the bottom of the screen. The
only way to see that was to play until the hold was full, which is the
same argument `-- fight 10` makes about the hand.

`-- salvage 8 bag=4` also drops a four-part BAG at the node, which is
what a shared kill leaves. That one cannot be reached at all without a
second machine — `Combat._victory` only opens a bag when the fight was
the party's — so without this the newest panel in the game is the one
nothing can draw on its own.
```

## Check table

Above `func _print_check_table() -> void:`:

```text
Every checked option in the table, measured against three real ships.

Prints the badge the player would see and then rolls the ladder ten thousand
times, so the four bands can be compared against what ODDS promises. A drift
between them means pick_outcome or the split is wrong, and neither would
crash.
```

## Attribute table

Inside `_print_attribute_table()`, above `print("chassis            HUL RCT THR MNV THM SEN STL   hp/cap/diss/dodge/init/fuel  mounts  kit deck hand set")`:

```text
RCT WAS MISSING and the row has always printed it: the loop below walks
`Run.attributes()`, which is seven gauges, against six labels. Every
column after HUL read as the one to its left, so a heavy's thrust of 8
looked like a maneuverability of 8 on a frame that cannot turn at all.
```

