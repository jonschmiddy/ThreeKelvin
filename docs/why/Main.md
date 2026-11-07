The reasoning behind `tkg/scripts/Main.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

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

## Frame counter

Inside `_ready()`, above `add_child(FpsMeter.new())`:

```text
THE FRAME COUNTER, over everything and part of no layout. Added to the
window rather than to `root`, so it cannot take a pixel from the HUD row --
which is exactly what got the last one deleted. Built whatever the setting
says and hidden if it is off, so the toggle works without a relaunch.
```

## Hit kick

Inside `_ready()`, above `Sig.hit_landed.connect(func(amount: int, to_player: bool, _who: int, _ab: int) -> void:`:

```text
THE VIEW KICKS WHEN YOUR HULL IS HIT. Connected here rather than in Audio
because it is a picture, not a sound, and because it moves the whole
viewport -- see `_kick`.
ON THE LANDING, not the resolution: kicked when the maths ran, the view
had stopped shaking ten frames before the shot it belonged to arrived
(combat polish audit F2).
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

## Boot destination

Inside `_ready()`, above `var argv := OS.get_cmdline_user_args()`:

```text
Boot destination. The launcher is the default, and every development flag
below skips it — an automated run must never stop at a screen waiting to
be clicked, and a flag that drops you into a fight plainly means "not the
title screen" without having to say so.

  -- nolauncher   straight into a new run
  -- resume       straight into the suspend save, if there is one
  -- lobby        straight into the party screen, with no run rolled

`ship` belongs in this list and its absence is not cosmetic: the refit
screen reads Run.hull, which is null until a run starts, so booting to the
launcher and then swapping the ship screen over it crashes on arrival.
`salvage` is the same: it stows into a hold that a run has to exist for,
and the sector it opens draws the ship's own reactor.
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

## Shot flags

Inside `_ready()`, above `if "menu" in OS.get_cmdline_user_args():`:

```text
`-- shot` writes what is on screen and quits. For looking at a layout from
a place that cannot look at a window — a headless CI leg, an agent, a bug
report from somebody who cannot run the project. Deliberately generic: it
photographs whatever the flags above put up, so it never needs a case
adding for a new screen.
`-- menu` opens the escape menu over whatever the flags put up, so `-- ship
menu shot` photographs it in place;
```

## Shot timing

Above `func _shoot() -> void:`:

```text
Wait for the layout to settle, then save the frame.

Several frames, not one. Containers size their children on the frame AFTER
they are added, and every screen here is built in code during _ready — a
grab on frame zero photographs a page whose panels are all still at their
minimum size, which is precisely the property under test.
```

Inside `_shoot()`, above `var base := Vector2i(`:

```text
THE WINDOW IS RESIZED TO THE BASE VIEWPORT FIRST, and this is not tidiness.

The window is resizable and the controls lay out to it in real pixels, while
this grab returns the viewport's own render target at the project's base
size. Those two are routinely different — a 999-wide window photographed as
a 960-wide PNG — so the picture silently CROPS the interface, and a button
perfectly placed in the game appears sliced by the right edge of the file.

An afternoon went into chasing a margin bug that did not exist because of
it. A screenshot that does not show what the game shows is worse than no
screenshot: it is a confident wrong answer.
```

Inside `_shoot()`, above `print("[shot] %s  texture %dx%d  layout %dx%d" % [`:

```text
THE TEXTURE AND THE LAYOUT ARE NOT ALWAYS THE SAME WIDTH, and reading the
picture as if they were costs an afternoon. The window is resizable, the
controls lay out to it, and this grab is the viewport's own render target —
so a screenshot can be NARROWER than the interface in it, and a button
sliced by the right edge of the PNG can be perfectly placed in the game.
Both numbers are printed so the next reader can tell those two apart.
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

## Overlay layer

Above `var _overlay: CanvasLayer = null`:

```text
The escape menu and Settings live on their own layer, above the game's. The
menu's backdrop is a screen shader, and it can only blur what is drawn BEFORE
it -- on the base layer, `top_level` controls (the ship screen's perk labels)
draw after everything else, so they stayed sharp through the pause. On a
higher layer the whole game is finished before the menu reads it. Settings
shares the layer so it still opens on top of the menu.

A CanvasLayer is not a Control, so the theme set on this node does not reach
through it: whatever goes on the layer is handed `theme` by hand, or it draws
in Godot's default font.
```

## Input and cursor

Above `const CURSOR_FRAMES := 4`:

```text
The game shipped with no way to exit — no quit action, no input map entries.
Escape now opens the menu; F11 toggles fullscreen so a screen-sized window
can never trap the player behind missing title-bar chrome again.
TAB IS THE SHIP, and it has to be caught in `_input` rather than in
`_unhandled_key_input`.

Godot binds Tab to `ui_focus_next` and the GUI consumes it walking focus
between controls, so it never reaches the unhandled pass -- which is where I
put it first, and why it did nothing. Taking it here and marking it handled
costs the focus walk, which this game does not use: nothing is keyboard
navigable and every control is clicked.

`show_ship` refuses during a fight on its own, so there is no guard here.
THE POINTER, AND THE POINTER CLOSING.

Four corners and a dot -- see `art/tools/cursors.py` for why there is no
crosshair -- travelling from six pixels out to three when the thing under
them can be pressed.

FRAMES, BECAUSE A CUSTOM CURSOR IS ONE STATIC TEXTURE PER SHAPE. Godot has
no animated form of it, so the animation is four images and the swapping is
here. The alternative -- hiding the system cursor and painting our own
Control at the mouse position -- can tween anything, and is a cursor one
frame behind the mouse forever. A pointer that lags is a worse pointer than
one that does not ease, so the frames win.

IT COSTS FOUR OS CALLS PER HOVER, not four a second: `_process` only touches
the cursor when the rounded frame index actually changes, which is three
times on the way in and three on the way out.
```

## Cursor

Inside `_wear_cursor()`, above `var tex := load("res://art/cursors/reticle_%d_2x.png" % i) as Texture2D`:

```text
THROUGH THE IMPORTED TEXTURE, not the PNG on disk. An export has no
loose PNG -- only the imported texture in the pack -- so loading the
file by its globalized path failed there, silently, and friends got the
system arrow. The textures import lossless, so their image is exact.
```

Inside `_show_cursor()`, above `for shape in CURSOR_SHAPES:`:

```text
BOTH SHAPES, THE SAME IMAGE. Godot swaps ARROW for POINTING_HAND by itself
the instant the pointer crosses a control, which would jump the reticle to
its end state and leave the animation running behind it. Holding both to
the current frame means the swap is invisible and this is the only thing
deciding what the cursor looks like.

AND EVERY SHAPE A DRAG WEARS. Picking up a part hands the pointer to
Godot's drag, which shows FORBIDDEN over whatever will not take it and
CAN_DROP over whatever will -- the system's red X on the Promenade and
its plain arrow over the hold, because neither had the reticle (Jon:
"kinda bad"). Where a part can go is shown by the thing it would go
into; the pointer stays ours, held shut for as long as you carry it.
```

Above `func _cursor_wants_shut() -> bool:`:

```text
Is the thing under the pointer something you can press?

Asked of the hovered control rather than of the cursor, because the cursor is
what we are deciding. `mouse_default_cursor_shape` is the declaration every
button makes through `Widgets._btn`, so this reads the same fact Godot would
have read to do the swap we are taking over.
```

Inside `_input()`, above `var mb := event as InputEventMouseButton`:

```text
SNAP SHUT, EASE OPEN. A press jumps the reticle to closed rather than
travelling there: the animation is a response to hovering, and a click is
an impact. Easing INTO a click makes the pointer feel behind your hand;
easing out of one reads as the thing recovering.

NOT HANDLED, deliberately. This watches the click on the way past; the
control under it still gets it.
```

## Screen shake

Above `const SHAKE_S := 0.22`:

```text
SCREEN SHAKE, and it is the viewport that moves rather than any one node.

`canvas_transform` shifts everything drawn in the base canvas together -- the
ship, the enemy, the drawer, the HUD -- so nothing can drift out of step with
anything else. The escape menu is on its own CanvasLayer and is deliberately
not shaken: a menu that wobbles while you read it is a different feeling
entirely.

WHOLE PIXELS ONLY. Everything in this game is drawn on a 960x540 grid, and a
half-pixel offset resamples every sprite on screen -- the one thing the
integer window scaling exists to prevent.
```

## Tab round

Inside `_input()`, above `if Router.move_open():`:

```text
NOR OFF THE MOVE (`TransferScreen`). It has no off while anything is on the
pad -- that is why it hides the HUD -- and Tab was the door it forgot: over
the yard it swapped the station out and the move with it, and the pad it
was showing was never shown again (Jon, Oct 23).
```

Inside `_input()`, above `var at := ZoomLadder.lit_rank() if ZoomLadder.busy() else -1`:

```text
LOCAL, SECTOR, STARCHART, round. The screens a run is actually played on,
in the order you move between them: where you are side on, the sector
round you, where you are going (Jon: "include local in the tabbable pages
list"). DOCKED, THE BERTH TAKES LOCAL'S PLACE: Tab from the berth goes to
the map, and from the chart back into the station, never out to LOCAL,
because UNDOCK is the only way out (Jon, Oct 27). The HUD's first tab
agrees: STATION on the map or the chart, LOCAL greyed at the berth. SHIP
is gone from the round with its tab: your ship opens from LOCAL or the
Shipyard.

Each `show_` refuses on its own terms -- the map and the chart during a
fight (`Router.fight_up`: Tab there rebuilt the fight over itself), the
chart with nothing to jump to -- so a refused step simply leaves you where
you were rather than needing a guard here.
FROM WHERE A MOVE UNDER WAY IS GOING (`ZoomLadder.lit_rank`, the tab lit):
Tab twice quickly is two steps round, the second taken when the first
lands (`ZoomLadder.hurry`), not the first one asked for again
```

## Abandon and quit

Inside `toggle_menu()`, above `_menu.quit_requested.connect(func() -> void:`:

```text
Abandoning is an ENDING, so it goes into the record — the same one
Router.new_run() writes when you start over on top of a live run. Recorded
here rather than left for later because the run is over the moment this is
pressed, and a player who abandons and then closes the game would otherwise
have it vanish from the flight record entirely.
```

Inside `toggle_menu()`, above `_menu.save_and_quit_requested.connect(func() -> void:`:

```text
The autosave has already written a screen swap, but state moves after one
— a station's purchases and repairs all land on a screen that was saved
when it opened — so the explicit write is what makes SAVE & QUIT mean it.

Not mid-combat, though. Combat is outside the save by design and the format
stores none of it, so writing there banked the hull and heat the fight had
already spent against an enemy that comes back at full HP on a node still
marked unfought: strictly worse than force-quitting, from the button that
promises to be the safe way out. Mid-fight this now does what force-quitting
does — the last save, from before the shooting started, stands.
```

Inside `toggle_menu()`, above `Run.hull = null`:

```text
The run is on disk now, so the copy in memory is finished with. Letting
it stay live would be actively dangerous: the title screen rolls its
own Run.galaxy for the backdrop, and any later autosave would then
write this run's MAP against that galaxy — the systems are positioned
from the galaxy, so every one of them would move.
```

Inside `toggle_menu()`, above `Router.drop_combat()`:

```text
Out of the party's fight and off the signal bus, not just dropped
(review, Nov 5): the partners sat on "WAIT <name>", the fight still
listening ran their next turn with no hull, and CONTINUE was handed
back the fight it never left.
```
