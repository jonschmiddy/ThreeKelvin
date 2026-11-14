The reasoning behind `tkg/scripts/ui/SalvageGrid.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Salvage grid

Above `signal picked(item: HoldItem)`:

```text
What is loose out here, laid out as a grid you reach into.

The other half of `HoldGrid`, and deliberately a different thing. Your hold
is a PACKING PUZZLE -- every item has a cell you chose, it is remembered
across jumps, and the whole game of it is deciding what fits. A wreck is not
a puzzle. Nobody arranged it. It is a pile, and the only question it asks is
which of these you want.

It places things itself, first-fit, and then REMEMBERS. The first version
re-laid-out on every change, on the reasoning that nobody arranges a wreck and
letting you would imply it mattered. That was wrong in practice for a reason
that has nothing to do with wrecks: taking one thing out made everything else
jump to a new cell and the container change height, so the pile you were
halfway through reading rearranged itself under your hand every time you
touched it.

Positions last as long as the view is open. Close it and come back and the
pile is tidied again, which is the one place the original reasoning still
holds -- you did not arrange it, so it owes you nothing across a visit.

Same 40-pixel cell and same lattice as the hold beside it, because the whole
point of showing them together is that a shape means the same thing on both
sides -- a 2x2 that will not go in your hold is a 2x2 you can see will not go.

`MATERIALS_NOTE` 3.6: every physical grant is a container, not an item. This
is that container. A kill fills one, an event hands you one, and what you
jettison lands in one.
```

## Reveal signal

Above `signal revealed(item: HoldItem, index: int)`:

```text
ONE THING RESOLVING OUT OF THE SWEEP, on the frame it does.

The rarity ladder used to sound only when you dragged something into the
hold, which is the moment you DECIDE about a thing rather than the moment you
find it. Finding is what the sweep is for -- the whole point of an eighteen
to one length ratio between a common and an artifact is to tell you what is
in a wreck before you have read a word of it.

A signal rather than a call into Audio from here: this grid draws a
container and has no business knowing which sound a rarity maps to. The view
that opened it already does -- see `TransferView.take_sound`.
```

## Drop beam

Above `var _beam: Rect2i = Rect2i()`:

```text
The cells a carried thing would cover if you let go now, or empty.

The hold has had this since it became a grid and the container had none, so
dragging something out here lit nothing up and read as a dead surface -- which
is half of why it looked like the drop was being refused when it was being
accepted and not drawn.
```

## Sweep speed

Above `const SCAN_CELLS_PER_SEC := 0.7`:

```text
HOW FAST THE SWEEP CROSSES THE CONTAINER, in cells per second.

1.05 cells a second: a six-row container takes about five and a half seconds,
a two-row one just under two.

This has been 14, then 4.5, then 2.6, then 1.6, and every one was too quick
for the same reason -- the sweep finished before it had cost you anything, so
it was decoration laid over a container that was simply there. At this rate
opening a wreck TAKES a moment: you read the top row while the bottom is
still dark, and you start deciding before you have seen everything.
SLOWER AGAIN, at Jon's ask ("much slower"): 0.7 cells a second, so a
six-row container takes about eight and a half seconds and a two-row one
just under three. The rarity ladder plays under it, one thing at a time, and
at this rate each one is heard on its own.
```

## Glitch timing

Above `const GLITCH_ROWS := 1.5`:

```text
HOW LONG A THING TAKES TO SETTLE, measured in ROWS OF SWEEP rather than in
seconds.

A row and a half: a crate is at its worst the instant the line finds it and
is done by the time the line is halfway through the row below. Tying it to
the sweep rather than to a clock is what keeps the two in step -- retune the
scan speed and the glitch follows it, instead of becoming a flicker on a slow
sweep or an unresolved mess on a fast one.

It also means several crates are always mid-resolve at once, at different
stages, which is most of why the container looks like an instrument reading
rather than a list appearing.
```

## Glitch dropouts

Above `const GLITCH_DROPS: Array[int] = [1, 4]`:

```text
WHICH STEPS DROP OUT, and it is only two of fourteen.

The first version swung the alpha the full way either side of where it was
heading on EVERY cut, which is a strobe rather than a glitch -- the thing
vanished and returned fourteen times and read as a fault in the screen.

The brightness holds now and the TEAR carries the effect: the crate is
plainly there from the first cut, sliding sideways and settling, and it
blinks exactly twice on the way in. Interference is something happening to a
picture you can see, not the picture being taken away and given back.
```

## Materialise

Above `func _materialise(ic: ItemIcon, seed_at: int) -> void:`:

```text
One thing resolving out of the sweep.

Stepped, not interpolated. `tween_callback` sets a state and `tween_interval`
holds it, so every change is a hard cut -- which is the whole difference
between a thing switching on and a thing being picked up by an instrument
that is not quite sure yet.

It runs in the SWEEP'S colour and only lands on white at the end, so for the
first tenth of a second the crate is the same light as the line that found
it. Revealed by the sweep, rather than switched on underneath it.
```

## Spare row

Inside `_layout()`, above `_rows += 1`:

```text
ONE SPARE ROW, ALWAYS.

The grid was exactly as big as its contents, which is tidy and made the
other half of the design unreachable: dropping one of YOUR things in here
is jettison, and with every cell occupied there was nowhere to aim it. The
drop logic worked the whole time and could not be asked.

An empty row also says the thing that needs saying without a label -- that
this is somewhere you can put something, not just somewhere you take from.
```

## Lattice extent

Above `func _draw() -> void:`:

```text
The lattice is drawn at its OWN extent, not at the control's.

The control is now bigger than the grid on purpose -- it fills the whole
right-hand column so that dropping one of your things anywhere on that side
is jettison. Before, its rect was exactly the packed cells, and Godot only
offers a drop to the control under the pointer: with every cell occupied
there was no part of it left to aim at, so `_can_drop_data` was never asked.
The logic had been right the whole time and unreachable.

So the picture and the target part company here. Everything below draws at
`_cols` by `_rows`; the control extends past it and is all target.
```

## Drops

Above `func _can_drop_data(at: Vector2, data: Variant) -> bool:`:

```text
Dropping one of YOUR things in here is jettison.

The same motion as taking, mirrored, because it is the same idea seen from the
other end: this is the floor of the system you are standing in, and putting
something down on it is exactly what `Run.jettison` does. `MATERIALS_NOTE`
3.5 makes it apply to everything, so a gun and a crate leave the same way.

Only things you OWN. An item already loose out here has nowhere further to
fall, and letting it be dragged around inside the pile would suggest the
arrangement meant something -- see the note at the top.
Two kinds of drop land here, and they are different things.

One of YOURS is jettison -- putting it down in the system you are standing in.
One already out here is a REARRANGEMENT, which the first version refused on
the grounds that nobody arranges a wreck. That reads as broken rather than as
principled: the cells are right there, the thing moves under your hand
everywhere else in the game, and refusing costs a rule nobody asked for.
```

## Drop recheck

Inside `_drop_data()`, above `var cell := _cell_of(at, m)`:

```text
RE-CHECKED AT THE LANDING, not only on the hover. A partner mutating
the same pile fires a refresh mid-drag, so the hover's yes can be
stale by the time you let go -- and `_layout` keeps any cell it is
handed, so a stale yes drew two items on one cell until the
container was reopened. A cell that stopped fitting goes through the
same nudge-and-anywhere search a throw-in uses.
```

## Nudged landing

Above `func _target_for(at: Vector2, m: HoldItem) -> Vector2i:`:

```text
The cell a carried thing would actually land on.

Where you aimed if that is clear; otherwise the nearest cell that is, scanned
outward. The hold does the same thing through `target_for` and its `NUDGE` --
a drop a cell off is a drop that meant the cell next to it, and refusing it
outright makes packing a test of aim rather than of arithmetic.
```
