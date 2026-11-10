The reasoning behind `tkg/scripts/ui/TransferView.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Container screen

Above `const PAD := 24`:

```text
Your hold on the left, what is out there on the right, and a drag between.

`MATERIALS_NOTE` 3.6: if something hands you a physical item, it hands you a
CONTAINER, not the item. A kill fills one, an event pays out into one, and
whatever you throw overboard lands in one. This is the screen for all of them,
built once, so a wreck and a windfall are the same gesture.

The reason it is one screen rather than three is 3.4. Nothing may be destroyed
for you, which means no payout can ever force itself into a full hold -- so
every payout has to be a place you reach into rather than a thing that
arrives, and every one of them needs your hold visible beside it to reach
from. Once that is true for one of them it is cheaper to make it true for all.

BOTH DIRECTIONS ARE ONE GESTURE. Right to left is taking; left to right is
jettison, which the ruling already defines as putting something down in the
system you are standing in. They are the same motion because they are the same
idea -- this is your ship, that is the floor.
```

## Grid height

Above `const GAP := 12          ## between the two wells`:

```text
HOW TALL BOTH GRIDS ARE, in cells, whatever is in them.

The popup used to size itself to its contents, which meant every change of
contents changed its shape: fill the container and it grew, empty it and it
shrank, and the moment a scrollbar appeared it got wider and everything
jumped sideways. A window that moves while you are working in it is worse
than one that is occasionally too big.

Six rows fits a heavy hull's five with a row spare, and is the most a pile
shows before it scrolls instead of growing.
HOW THIS SCREEN LOOKS, AND HOW IT GOT THAT WAY. Ten dressings were built
and photographed in the real game, and Jon picked two of them and asked for
a third thing: "terminal / Readout", "chamfer / Chamfered case", and "I do
like the idea of an arrow... something maybe animated?" So: a chamfered
case, a readout heading, a well around each grid, and a chevron between them
that steps rather than slides.

THE OTHER NINE ARE GONE from the code and kept as pictures --
claude.ai/artifact/5Fx8msGPuruoQcdbS4K1Nq has every one at 1:1, and the four
arrows at claude.ai/artifact/6HqdiPhUGRZ3Yanq7yxZvt. A table of layouts this
file will never draw again is weight in a file that also has to be right
about drag and drop; the screenshots answer "what did we try" better than
dead branches do.
```

Above `const FIT_ROWS := 3`:

```text
HOW DEEP A PILE GETS TO BE BEFORE IT SCROLLS. Jon: "let's not have the
scroll wheel, unless it's bigger than 4x3" -- so three rows are simply shown,
and the bar arrives with the fourth. Fifteen parts across the far grid's five
columns, which is more than a wreck has ever held.
```

Inside `_side()`, above `var rows := maxi(Run.hold_grid().y, 2) if not far else FIT_ROWS`:

```text
FIXED, HERE, ONCE. `custom_minimum_size` is a floor -- this file has
already got that wrong once and clipped both grids to two rows -- so
setting it and never touching it again is what makes the popup one shape.
Nothing about the contents may reach this number.
FIT, AND THE FAR SIDE IS MEASURED IN `refresh`. The hold's shape is known
here; what is out there is not, because a container is handed to this
screen after it is built.
```

Inside `refresh()`, above `if _loose_scroll != null and not _sized:`:

```text
A FITTED POPUP LEARNS THE FAR SIDE HERE, AND ONLY ONCE.

The screen is built before it is handed a container, so the only place
that knows how deep the pile is is this one. But the ruling this file
already made stands: a window that moves while you are working in it is
worse than one that is occasionally too big -- and a size that followed
the contents would shrink under your hand as you emptied the wreck. The
test caught exactly that, which is what it was written for.

So: measured when the container arrives, fixed for as long as it is open.
Two rows minimum so an emptied wreck is still a place, six maximum so a
windfall scrolls rather than growing off the screen.
```

Inside `refresh()`, above `var deep := maxi(ceili(showing.size() / float(SalvageGrid.COLS)),`:

```text
BY THE ROWS THE PARTS TAKE, not by how many there are. Counted, five
things read as one row of five, and the custodian's body -- two 2x2
parts and three more -- showed its first row and hid the rest under a
view with no scrollbar.
```

## Scrollbar room

Above `const BAR := 14`:

```text
Room kept for a scrollbar, WHERE THERE IS ONE.

Godot gives a ScrollContainer its bar out of the child's width, so the frame
has to be wider than the grid by this much or the grid loses a column the
instant the pile outgrows the view -- which is exactly when you least want
the layout moving.
```

Inside `refresh()`, above `var over := deep > FIT_ROWS`:

```text
AND THE BAR IS ONLY THERE WHEN IT IS DOING SOMETHING. Godot takes a
scrollbar out of the child's width, so a box that reserves one is a
column narrower for ever -- which is why this reserves nothing until a
pile is actually deeper than it can show.
```

## Container title

Above `func setup(h: MapGen.Jetsam, n: MapGen.MapNode, on_close: Callable,`:

```text
`title` names the container -- SALVAGE, the wreck's name, whatever handed it
to you. `n` is the system whose bag this is.
`animate` is off for the harness, which counts VISIBLE icons -- a sweep in
progress would have it measuring an empty container and calling it a bug.

`title` OVERRIDES the container's own word, and exists for exactly one case:
the instant an event resolution hands you something. See `Jetsam.title` --
the pile is the system's floor either way, and PRIZE is a fact about the
moment you are standing in rather than about the crate.
```

Inside `setup()`, above `if title != "":`:

```text
WHAT IT IS, THEN WHOSE. The heading was the ship's name and the column
said SALVAGE, which read as a screen about the Rustjaw Cutter that
happened to contain salvage -- when it is a salvage screen that happens to
be about a Rustjaw Cutter. The name belongs over the grid it names.

AND IT ASKS THE CONTAINER, because the heading was a constant and there is
more than one kind of pile. See `MapGen.Jetsam.title`.
```

## Reveal sweep

Inside `setup()`, above `if h != null and h.is_wreck():`:

```text
ONCE PER CONTAINER. The sweep is what OPENING something looks like, and a
wreck you have already been through is not being opened -- replaying it
every visit would make walking back to a half-stripped pile feel like
finding it again, which is the one thing it must not say.
PER CONTAINER, not per system. Three wrecks in one sector are three
things found, and the second should sweep exactly as the first did.
```

## Backdrop

Inside `_init()`, above `add_theme_stylebox_override("panel",`:

```text
THE BACKDROP, and it is only a backdrop now.

This used to be the whole screen: an opaque full-rect panel with the grids
laid out directly on it. That reads as a MODE -- the sector is gone and you
are somewhere else -- when the thing it describes is a crate on the floor
twenty metres away. Dimmed rather than replaced, so the system you are
standing in is still visibly there behind what you are sorting.

Still STOP, and that has not changed for a reason: nothing behind may be
clicked through it, and a drop that misses both grids still has to land
somewhere that knows what to do with it.
```

## Popup frame

Inside `_init()`, above `var popup := PanelContainer.new()`:

```text
THE POPUP ITSELF. Sized to what is in it rather than to the window, with
an edge, so it reads as an object on top of the sector.

IGNORE, not STOP: the frame is decoration and must not become a drop
target. Its children still receive everything -- the grids and their icons
are what answer a drop -- and anything that misses them falls through to
the backdrop, which is this view's own catch-all. A STOP frame would eat
exactly the drops that are currently reaching it.
```

## Popup layout

Inside `_init()`, above `var row := HBoxContainer.new()`:

```text
NO RUNNING TOTAL. "2 LEFT" and "PICKED CLEAN" were counting something you
are looking at: the grid on the right IS the answer, and a number beside
the name only competes with it. An empty container says it is empty by
being empty.
```

## Redraw on ship change

Inside `_init()`, above `Sig.ship_changed.connect(_on_ship_changed)`:

```text
LISTEN TO THE MODEL, NOT TO EACH THING THAT CHANGES IT.

This is the second time the same bug has been reported with a different
trigger. First a drop into the container moved the item and left it drawn
where it had been; now a RIGHT-CLICK does -- `Run.jettison` runs, the item
leaves the hold, and the screen carries on showing it until the next
action forces a repaint. Both times the symptom was "it goes back, then
reappears out here when I do something else", and both times the something
else was just the first redraw.

Wiring the second trigger would leave a third. `ship_changed` is what
every one of them already emits -- jettison, stow, place, take -- so the
view now redraws because the SHIP changed, whatever did it.

The `picked` connection above stays. It is redundant with this and it is
known to work, and while this screen is being hammered on I would rather
have two things agreeing than one clever one.
```

Inside `_build_loose()`, above `_loose.picked.connect(func(_m: HoldItem) -> void: refresh())`:

```text
THIS LINE IS THE WHOLE BUG. `SalvageGrid` jettisons on a drop and then
announces it -- and nothing was listening, so the model changed and the
screen did not. The item left your hold, went into the bag, and carried on
being drawn where it had been.

Which is exactly what it looked like from outside: drop it out here and it
"goes back", then move anything else and the earlier one is suddenly out
there. The second action was not moving it. It was the first refresh since
it moved.

The hold has to redraw too, not just the container, which is why this is
the view's refresh rather than the grid's own.
```

## Drop catching

Above `func _can_drop_data(at: Vector2, data: Variant) -> bool:`:

```text
THE SCREEN ITSELF CATCHES ANYTHING THE GRIDS DID NOT.

`SalvageGrid` has its own `_can_drop_data` and it is correct -- driven
directly it accepts the payload and moves the item every time. What could not
be established is whether Godot ever ASKS it: hit-testing a drop through a
scroll container, past PASS-filtered icons, onto a control that is one of
several stacked full-rect siblings has too many places to fail quietly, and
the harness cannot answer it either -- an unfocused window does not track a
warped cursor, so simulated input measures itself rather than the game.

So the decision moves to the one control that cannot be missed. This panel is
topmost, covers everything, and is `MOUSE_FILTER_STOP`; a drop that reaches
it is a drop the grids declined. Which side you let go over is then plain
arithmetic on the x, which needs no hit-testing to be right.

The grid keeps its own handler. Two answers to one question is not ideal, but
they agree, and the alternative is removing the one that demonstrably works
in favour of the one that may not be reached.
```

## Take sound

Above `const REVEAL_DB := -4.0`:

```text
The whole sound of a take, both drop paths. A DIFFERENT SOUND from the
reward sting, not the same one turned down: `loot_drop` is a fanfare and its
problem here is CHARACTER, not level -- taking a crate off the floor happens
six times a system, and a fanfare each time turns packing into a slot
machine paying out. The resource watcher would answer the same take with
the flat loot_drop / scrap_gain a frame later; this sound IS that sound,
better informed, so theirs are held. Down four and rate-limited, because a
fast hand emptying a bag fires this several times a second.
WHAT A WRECK HAD IN IT, HEARD AS IT RESOLVES.

The rarity ladder is the clearest sound design in this game -- 0.12 s for a
common and 2.20 s for an artifact, eighteen times the length -- and it only
ever played when you dragged something into the hold. That is the moment you
DECIDE about a thing, not the moment you find it. Now the sweep tells you
what is in a pile while it is still opening it, which is what the ladder was
built to do.

STAGGERED BY ARRIVAL, not played on top of each other. A wreck with eight
things in it would otherwise fire eight overlapping sounds inside half a
second; the sweep already reveals them in order, so the sound follows the
picture and lands one at a time.

QUIETER THAN TAKING, because finding is the smaller event of the two: you
will hear this on every wreck you open and the take only on what you keep.
And no `loot_drop` underneath -- the resource watcher is not involved in a
reveal, nothing has moved yet.
Four down from the take, which is the level the ladder was judged at.
```

## Reveal sound

Above `const REVEAL_FLOOR := ModuleData.Rarity.LEGENDARY`:

```text
THE TOP OF THE LADDER ONLY. Every rung used to ring as the sweep found it,
and the low ones did not read as anything -- a common is 0.12 s of dry tick
and a wreck is mostly commons, so the sound said "something appeared" over
and over and meant nothing. Jon: "maybe we only do the sound for legendaries
and artifacts." The sweep is quiet now until it finds something worth
stopping for, and then it is unmistakable: 1.2 s, 1.6 s, 2.2 s.
```

Above `func _take_fx(_m: HoldItem) -> void:`:

```text
THE RARITY LADDER IS FOR FINDING, NOT FOR PACKING. It played twice -- once
as the sweep revealed a thing and again when you dragged it into the hold --
so a legendary announced itself on the way in as well as on the way out of
the dark. Jon: "only when it is found the first time, not when you put it in
your hull." Taking now sounds like what it is: a thing stowed.
```

## Rotate key

Above `func _unhandled_key_input(event: InputEvent) -> void:`:

```text
R TURNS WHAT YOU ARE CARRYING.

The refit screen has had this since the hold became a grid, and this screen
had none of it -- so a 4x1 that would only fit standing up could be seen not
fitting and not be turned. Packing is the whole game of a hold; a view you
pack in and cannot rotate in is a worse version of the one next door.

Deliberately only the carried item. `ShipScreen` also turns a part sitting in
the hold under the pointer, which is a second verb on a second target -- worth
having there, and not worth two ways to do it here while this screen is young.
```

## Redraw guard

Above `func _on_ship_changed() -> void:`:

```text
Redraw because something happened to the ship, whatever it was.

Guarded on being in the tree: the signal outlives a closed view by however
long the free takes, and refreshing a torn-down panel is a crash rather than
a wasted frame.
```

## Arrow

Above `class Arrow extends Control:`:

```text
WHICH WAY THINGS COME, and it moves.

Every take on this screen is right to left, and the drag along it is the one
gesture the screen has -- so the arrow is instruction, not decoration. Four
ways of saying it, picked with `-- salvage salv=10 arrow=N`:

  0 MARCH    three chevrons lighting in turn, right to left, like a conveyor
  1 DRIFT    the group slides left and fades, over and over
  2 SWEEP    a line runs from the far grid to your hold, with a head on it
  3 BREATHE  all three brighten and dim together, going nowhere

IT HOLDS STILL WHEN MOTION IS OFF. `reduced_motion` is a setting somebody
turned on for a reason, and an animation in the middle of the screen is
exactly what it is for; frozen, it is still an arrow and still says which way.
`-- phase=F` freezes it anywhere for a shot.
```

Inside `_cut_box()`, above `const STEPS := 8`:

```text
HOW MANY FRAMES THE PASS HAS. Jon: "more pixelated and the animation more
choppy" -- so it does not slide, it STEPS: eight positions in 1.6 s, five
a second, which is about what a sprite sheet of this era would hold. A
continuous tween is the one thing that gives pixel art away as not being
drawn, and the whole screen is 960x540.
```

Inside `_cut_box()`, above `var p := _phase()`:

```text
DRIFT, which is what Jon picked from four: the group slides toward the
hold and fades as it goes, and the next one starts before the last is
gone. One gesture repeated, rather than a loop. The other three --
marching, a sweep on a rail, and a breath going nowhere -- are kept as
frames at claude.ai/artifact/6HqdiPhUGRZ3Yanq7yxZvt rather than as
branches nothing takes.
```

Inside `_cut_box()`, above `var arm := int(w / BLOCK)`:

```text
THE POINT IS ON THE LEFT, because left is where the parts go. The first
block version had the vertex on the right and drew the arms backwards,
so the arrow pointed at the wreck: an instruction to put things back.
```

## Party claims

Inside `refresh()`, above `var spent: Dictionary = {}`:

```text
SOMEBODY ELSE'S CLAIMS, not every claim.

A taken entry is kept on screen greyed, because in a party a part with
somebody's name on it is the texture of flying together -- a part that
simply vanished would read as one that was never there.

None of that is true of your OWN take. Alone, the greyed leftover sits in
the container next to the same object now in your hold, which reads as the
thing not having moved. So a claim with no other name on it leaves nothing
behind: it is in your hold, and that is where it is.
```

## Hold drops

Above `func _on_hold_drop(payload: Dictionary, at: Vector2i) -> void:`:

```text
Something dragged INTO your hold.

Two sources, and they cost different things. A part already in your cargo is
being rearranged and is free. A part out of the bag has to be CLAIMED first --
one bag, first hand in -- and the claim is a round trip in a party, which is
why this awaits and why it refuses to run twice at once.
```

Inside `_on_hold_drop()`, above `if m.hold_at != at and not Run.can_place(m, at):`:

```text
Yours already, so this is a rearrangement and it is free.

ASKED BEFORE IT IS LIFTED. The first version took the item out of the
hold, tried the new cell, and put it back on failure -- which is one
`place_in_hold` away from losing it outright if BOTH calls refuse.
3.4 does not allow a move to cost you the thing being moved, so the
question is answered while the item is still safely where it was.
```

Inside `_on_hold_drop()`, above `var i := _jetsam.items.find(m)`:

```text
THE BAG'S INDEX, not the grid's. The grid shows a filtered list now, so
its positions and `n.bag`'s stopped agreeing -- and `take_from_bag` claims
by index, which is exactly the kind of mismatch that claims the wrong thing
rather than failing.
```

Inside `_on_hold_drop()`, above `if not (m is CreditChit) and (Run.can_place(m, at) or m.hold_at == at):`:

```text
It landed wherever the hold had room. Move it to the cell actually
aimed at, if that cell will still take it -- a drop is a decision about
WHERE, and silently ignoring the half of it you can honour is worse
than not offering the choice.
NOT MONEY. `stow` cashed a chit and did NOT put it in the hold, and
then this put it there anyway to honour the cell you aimed at -- so
it sat in cargo occupying cells that nothing could be dropped into,
and `HoldGrid` draws no icon for one, so the space was invisible.

A chit has already landed by the time we are here. There is nothing
left to place.
```

## Loot opens where it is

Above `const PAD := 24`:

```text
LOOT OPENS WHERE IT IS (Jon, Nov 9, stripped-down UI A2). This was a centred
window over a 72% dim: the sector went dark and a frame with two grids came up,
the same for a wreck, the system's pile and an event's REWARD. A pop-up says
"you are somewhere else now" about a crate twenty metres away.

Now there is no window. Opened over LOCAL, the view finds its subject on its
own (`_aim_local`): the wreck's slot where the container is a wreck drawn at
this place, else your ship (the pile, REWARD). The camera pushes in on it with
the cutaway's own move (`SceneZoom`, the same 0.4 s ease, 2x where it fits
else 1x), the hold panel slides in from the left and the plate with the
container's things floats out of the subject to its rest under it (or beside
it, where the room is too short). DONE eases the camera back out, then the
opener's close runs. Freed from outside mid-push (a harness, the screen torn
down) the scene still goes back (`_exit_tree`).

NOTHING CLICKABLE MOVES UNDER THE CURSOR: the hold panel and the plate are
`MOUSE_BEHAVIOR_DISABLED` until the push has landed, and the view itself stays
STOP over the whole screen so nothing behind is clicked while it is up. The
room ends at LOCAL's bar, or at an event's band when the band opened it
(`floor_g`), so neither covers the thing that opened them.

The plate says nothing twice: under a wreck its own name and SALVAGE stand over
the plate, zoomed with it, so the plate has no heading; the pile's heading is
SECTOR LOOT, its one name (Part 1). The hold panel is as tall as its grid and
DONE, not the window: an empty slab under them read as a page.

Off LOCAL (the map's event page, a harness) there is no scene to push on: the
hold slides in from the left and the plate from the right, no dim. Under
reduced motion everything is at rest the frame it is measured.

The arrow between the two grids went with the window: with the subject above
the plate and the hold at the left, the geometry says which way things go.
```
