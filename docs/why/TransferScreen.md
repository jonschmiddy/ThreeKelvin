The reasoning behind `tkg/scripts/ui/TransferScreen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Transfer overview

Above `const SHIP_H := 132`:

```text
Moving day. Two ships, and everything you own between them.

THE ONE SCREEN THAT DRAWS TWO HULLS AT ONCE, and it exists because a hull
swap is the only moment in the game where you are choosing between objects
you already own rather than deciding whether to acquire one. The Yard asks
"do you want this ship"; this asks "which of your things come with you", and
those are different questions on different screens.

THE PURCHASE IS ALREADY FINAL when you arrive. There is no way back to the
old frame -- it has been traded in, the credits have moved, and `Run.hull` is
the new one. What is drawn on the left is the loading dock: your old hold,
with whatever has not crossed yet still sitting in the cells it sat in.

An earlier version of this was a STRIP under the hold on the refit screen.
It worked and it was wrong: a strip says "here is some overflow", and the
thing actually happening is that you are standing between two ships deciding
what your run is going to be made of. Two grids facing each other say that;
a caption under a widget does not.
```

## Full size ships

Above `const SHIP_H := 132`:

```text
FULL SIZE, and the room for it comes from the screen having nothing else on
it. The berth on the station rail draws at a half because it is a thumbnail
in a 150-wide column; here each ship has 450 of width and this is the last
time you will ever see the old one. A heavy is about 340 across at 1x, which
clears that with room, so the halving the rail needs would be shrinking these
for no reason but symmetry with a widget that is not on this page.
```

## Full rect anchors

Inside `setup()`, above `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`:

```text
ANCHORS **AND OFFSETS**. `set_anchors_preset` alone leaves the offsets
where they were, so the screen anchored to all four sides of a parent it
had no size inside of -- and every container under it collapsed to its
own content, which put a whole page in the top third and gave the two
hold grids no height at all to draw in. Every other screen in this game
uses the `_and_offsets_` spelling; this one now does too.
```

## Take all and jettison

Inside `setup()`, above `var bin := JettisonBin.new()`:

```text
TAKE IT ALL IS ONE CLICK, and it is the button most swaps will use. Moving
into a bigger frame strands nothing and moving into an equal one strands
little, so the common case must not cost twelve drags to say yes to.
THE HATCH, because the status line was already naming it as the only way
out of something and this screen did not have one. `Market.bid` answers 0
for contraband where contraband does not trade, and CAST OFF is refused
while anything is still on the old ship -- so without a bin, one crate of
grey coolant at the wrong station was a hard stop with no move available.
```

## Back out

Inside `setup()`, above `_back = Widgets.button("BACK OUT", _back_out)`:

```text
THE WAY OUT, and it is the reason the old frame is still drawn rather than
described. A purchase you cannot reverse has to be judged from the Yard,
which means judging a ship by its gauges; a purchase you can reverse can be
judged from HERE, with both hulls in front of you and your own guns on one
of them. The second is a better place to make the decision, so the button
that makes it possible earns its width.
```

## Ship column

Above `func _column(h: HullData, title: String, head: Label, grid: Control,`:

```text
One ship: what it is, a portrait WITH ITS KIT ON IT, and its hold under it.

`foreign` picks which ship the hardpoints belong to. The left-hand hull is
not `Run.hull` any more -- the purchase already happened -- so its mounts
come from `MountPoints.ship`/`fitted` and refuse every drop; the right-hand
one IS `Run.hull`, so it is the ordinary live widget the refit screen uses
and a gun dropped on it bolts straight on.
```

## Grid alignment

Above `func _portrait(h: HullData, foreign: bool) -> Control:`:

```text
The two grids sit at the same height whatever is in them.

THE HOLDS ARE DIFFERENT SHAPES -- a light is 4x3 and a heavy 6x5 -- so left
and right are rarely the same number of rows, and a container that centred
each in its own column would put the two lattices at two different heights.
They are meant to be read across, so they are both pinned to the TOP of the
space under the portraits and the slack falls below them.
```

## Portrait centring

Inside `_portrait()`, above `var holder := CenterContainer.new()`:

```text
A CENTRE CONTAINER AROUND A STACK THE SHIP'S EXACT SIZE.

The first version positioned the hull by hand against `COL_W` and laid the
mounts over it at the same offset. Both were wrong the moment the column
was allowed to EXPAND: the real width is about 440, so the arithmetic
centred the ship in a 300-wide box that was not there -- and the mounts
layer, which anchors to its PARENT, ended up over a rectangle the hull was
no longer inside. The rings drew, at coordinates nothing was at.

Letting a container do the centring and giving the mounts a parent that is
exactly the canvas removes both sums and the class of bug they were in.
```

Inside `_portrait()`, above `var mid := _mass_middle(v._img) - float(v._bob_off)`:

```text
CENTRED ON THE SHIP, NOT ON ITS PICTURE. The holder centres the canvas, and
a hull is in the middle of its canvas neither way: across, the picture is
wider than the ship on one side; down, masts and spires stretch it up, so
the body sat low -- 5 px on a medium, 18 on a heavy. Jon: "can the ships be
centered vertically in their respective boxes?", then "The heavy is not
centered in the box. It's off to the right." Across, the middle is the
ship's own extent, nose to tail; down, the middle of its MASS, where a
mast weighs what its few pixels weigh. Measured once here so a part bolted
on later does not make the hull jump. Each time the holder places the view
it moves by that much, but never so far that the ship leaves its box.
```

## Portrait mounts

Inside `_portrait()`, above `var ink := v.ink_rect()`:

```text
THE MOUNTS ARE A CHILD OF THE VIEW, not a sibling in a stack beside it.
`attach` anchors them to their PARENT, so parenting them to the ship makes
every coordinate they draw the ship's own -- which is what makes
`ShipView.canvas_to_local` the single place the bob, the magnification and
the centring are reasoned about. The refit screen has always done it this
way; a stack was a second set of numbers to keep in step, and it was
already out of step with the column's real width.
THE PICTURE CLAIMS THE SHIP, NOT ITS CANVAS. A heavy's canvas is 392 wide
and the ship is 296 of it, and the panel took the whole canvas as its
width, so two heavies ran the dock off the screen and CAST OFF with it.
Jon: "can't we just make the panels skinnier? There is a lot of dead
space on the left and right of the ships." The view claims the ship's
width and a little air (an even amount less than the canvas, so the
canvas, drawn whole and centred over it, stays on whole pixels).
```

## Arrow

Above `func _arrow() -> Control:`:

```text
The arrow, drawn rather than typed.

`Control` with a `_draw`, because the biggest thing the font can do is a
16px glyph and this wants to read from across the screen. Two triangles and
a shaft in EMBER, the ink this game uses for the thing you are meant to act
on.
```

## Turn and flip keys

Above `func _unhandled_key_input(event: InputEvent) -> void:`:

```text
R TURNS WHAT YOU ARE CARRYING, and what you are pointing at in the new hold.

The same key the refit screen uses, because it is the same gesture on the
same widget: a `HoldGrid` you are packing. It was missing here, which made
this the one screen in the game where a 3x1 spine could not be stood on end
to fit a gap -- on the screen whose entire subject is fitting things into a
smaller hold than they came out of.

THE OLD SHIP'S GRID IS NOT TURNABLE, and that is not an omission. Nothing on
it is being packed: it is a source you are emptying, its cells are the ones
the parts were already in, and rearranging a hold you are walking away from
is work with no outcome.
```

Above `func _flip_pointed() -> bool:`:

```text
Mirror whatever is bolted to the NEW ship under the pointer.

THE NEW SHIP ONLY. The old hull is a frame you are stripping -- which way its
guns face is a fact about a ship that is about to stop being yours, and a key
that silently did nothing on one half of the screen would be worse than one
that does nothing at all.
```

## Mount drops

Above `func _on_mount_drop(payload: Dictionary, slot: ModuleData.Slot, index: int) -> void:`:

```text
A part dropped on a hardpoint of the NEW ship.

THREE JOURNEYS END HERE and they are not the same. Off the old hull is the
one this screen exists for: a gun going mount to mount, which never needs to
be put down and so never asks whether the hold has room. Out of the new hold
is an ordinary fitting. And a part already bolted to the new ship is being
moved one hardpoint along, which is the case that looks like the others and
must not go through `install`, because that would take it off and put it
back and lose the arrangement.
```
