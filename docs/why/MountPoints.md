The reasoning behind `tkg/scripts/ui/MountPoints.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Purpose

Above `const R := 4.0`:

```text
Replaces the rack of squares beside it. A rack answers "how many mounts of
each kind are there" — which is a real question, and is now answered by the
HARDPOINTS tally under the attributes, where it costs three rows instead of a
column. What a rack cannot answer is WHERE, and where is the thing a mount
actually is: `HullData.dorsal` and its two siblings are measured off the
hull's own silhouette precisely so a gun can hang off the spine it is bolted
to rather than off a square in a list.

Sits over a ShipView and asks it to place things, so the sprite's bob, its
magnification and its centring stay in one place. See ShipView.canvas_to_local.
```

## Mount sizes

Above `const R := 4.0`:

```text
Radius of the ring drawn at a mount, in CONTROL pixels.

The hull is no longer magnified, so a ring is now the same size relative to
the ship as it is on screen. 4 rather than 5: the deepest hull is 114 rows and
the shallowest 43, and a 5px ring on the 43 was a quarter of the hull's depth
— a mount should mark a place on the ship, not be a feature of it.
The empty-mount ring, in ART pixels. Multiplied by the view's magnification
everywhere it is used, same as everything else drawn on the hull.
```

Above `const REACH := R * 3.4`:

```text
How far from an empty hardpoint a drop still counts, in art pixels.

THE SAME NUMBER THE PING IS DRAWN AT, which is the whole point of it being a
constant: the outermost ring reached 3.4R and the drop was accepted within
2.75R, so there was a visible ring of "looks like a target, is not one" all
the way round every mount. A target you can see and cannot hit is worse than
a smaller target.
```

## Drag signals

Above `signal lifted(m: ModuleData)`:

```text
A part has been picked UP off the hull, and a drag has ended.

Two signals rather than one because they are two different facts and the
screen does different things with them: lifting takes a part off the ship
immediately, and the end of a drag is the only moment anyone can tell that a
lifted part never landed anywhere and has to go back.
```

## Pointed part

Above `var _focus: ModuleData = null`:

```text
THE PART BEING POINTED AT FROM SOMEWHERE ELSE.

`_lit` answers "which mounts would take the thing I am carrying"; this
answers "where on the ship is the part I am reading about". They are
different questions and a drag is not involved in the second one, so the
refit screen's installed list can point at the hull without pretending to
carry anything.
```

## Foreign hull

Above `var ship: HullData = null`:

```text
THE SHIP THIS IS DRAWING MOUNTS FOR, when it is not the one you are flying.

Null means `Run.hull`, which is every use of this widget but one. The
transfer screen draws the frame you are LEAVING with its guns still on it --
and by then `Run.hull` is the new ship and `Run.installed` is empty, so a
widget that can only ask `Run` cannot draw it.

Six references were all it took. `refresh` needed a hull, a mount count and
an occupant; `_can_drop_data` needed a resident and a hold. Everything else
in this file already works off `_spots`, which is why generalising it was
worth doing here and was not worth doing to `HoldGrid`.
```

## Draw counters

Above `var drawn: int = 0`:

```text
How many fitted parts the last redraw actually put on the hull.

Written by `_draw` and read by `-- fittest`. The bug it exists for was the
draw loop skipping past a fitted part to paint a highlight in its place, and
no assertion on the DATA can see that: `spots()` reported every part
correctly the whole time the hull was coming back bare. A count of what was
DRAWN is the smallest thing that can tell the difference.
```

## Cutaway

Above `var lift: Dictionary = {}`:

```text
THE CUTAWAY (`CutawayView`): every fitted part lifted off its mount along a
dotted leader line to a labelled tag, and the empty mounts drawn as rings.
`lift` is each part's offset from its mount ("slot:index" -> art px, worked
out by the cutaway from the hull's silhouette), `explode` how far along it is
(0 on its mount: everywhere else this widget is used, nothing changes), and
`tag_side` which side of the part its name goes ("L", "R", "T", "B"). The part is
drawn, hit and picked up where it is lifted to, so a drag starts on what you
see.
```

## Weapons only

Above `var weapons_only: bool = false`:

```text
ONLY THE GUNS ON A PICTURE OF THE SHIP (Jon, Oct 23, from Geno's playtest):
LOCAL, the fight, the station hall and the yard draw the WEAPON parts and
leave the systems and utilities off, which keeps the hull from reading as a
pile of boxes. Every part still shows wherever parts are fitted or moved --
the cutaway, the refit screen, moving day -- since those are not `passive`.

The hull under a hidden part is the hull's own art: the parts are drawn over
the canvas, never cut out of it, so there is no hole to fill.
```

## Hull movement

Inside `_process()`, above `if _stale():`:

```text
The mounts ride the hull, so they move with it: with the idle bob, and
with the hull's place in its view. Recomputed only when the hull has
actually moved -- the bob steps in whole pixels a few times a second, and
repainting every frame regardless would be the same picture drawn sixty
times.

THE HULL'S PLACE, NOT ONLY THE BOB (Jon: "why are the modules off the
ship?"). The hull is drawn centred in its view, so when the view is laid
out again -- LOCAL's event band folding away, the ship's slot growing --
the hull moves and nothing about the ship changed. Watching the bob alone
left every part where the hull had been until the next bob step, and for
good on a hull that does not bob.

Measured against where the mounts were PLACED, not where the hull was last
frame: LOCAL's ship slot is laid out twice in some frames (the hull's view
at its minimum width, 324, then the row's 642 at the end of the frame), and
a placing done in between is wrong by the difference, 158 px of the hull's
own length. `_draw` checks again, after the layout has settled.
```

## Animation phase

Inside `_process()`, above `if _animating():`:

```text
THE PHASE ADVANCES FOR EITHER ANIMATION, and it used to advance for only
one. `_lit` was the sole condition here for as long as the tractor ping
was the sole animated thing on the hull, so the hover hints added beside
it were drawn ONCE and then held -- repainted only when the idle bob
stepped, a few times a second, always at whatever phase the last drag had
left behind. They were not faint. They were STOPPED, which is a thing a
lower alpha looks exactly like and no amount of brightening would fix.
```

## Part scale

Above `func _mag() -> float:`:

```text
One art pixel, in screen pixels. See ShipView.art_scale.

PARTS ARE HALF THE SIZE ON THE SHIP THAT THEY ARE IN THE HOLD, deliberately.
The two surfaces are doing different jobs: the hold is a thing you grab from,
so its cells are 30px and easy to hit, and the ship is a picture, so a part on
it has to be in proportion to the hull it is bolted to.

The proportion is not a preference — it is forced. A heavy carries FIVE weapon
hardpoints. At hold size a two-cell gun is 61px against a 248px hull, so five
of them come to 125% of the ship and cannot be drawn at all. At this size the
same gun is 31px and five of them take 62% of the dorsal line, which is a ship
with guns on it.

art_scale, not zoom_level: a mount is drawn ON the hull, so it has to follow
the hull onto the half sheet. zoom_level reports magnification alone and would
draw full-size parts over a half-size ship.
```

## Focus ring

Inside `_draw()`, above `if m == _focus:`:

```text
POINTED AT FROM THE LIST. ONE ring, and this used to be two.

The pair was reasoned from findability -- a single hairline on a
busy hull is easy to miss -- and it bought that by fencing the
part off: two strokes and the gap between them put four pixels of
white around a gun fifteen pixels tall, so what your eye landed on
was the frame rather than the thing inside it. On a part that
small the border IS the highlight, and it was most of it.

Still ICE, which is the brightest ink on the screen and is doing
the finding now. One pixel of air so the stroke does not sit on
the silhouette and read as part of it.
```

## Swap marks

Inside `_draw()`, above `if ok:`:

```text
WHAT THE CARRIED PART WOULD TRADE PLACES WITH (Jon: "can the
swappable modules already installed get highlighted? Just so you
know what can or cannot be swapped with that part"): the ping's
teal, as a still frame round the part rather than rings at a point
-- the same "your part goes here", told apart by its shape. A part
it would NOT trade with is left as it is, never dimmed: you are
looking at the hull while you carry, and a part greyed out reads as
one gone (see "WHAT IS THERE, FIRST AND ALWAYS" above).
```

## Empty mounts

Inside `_draw()`, above `if over and not tags:`:

```text
AN EMPTY HARDPOINT IS NOT DRAWN AT ALL. A ring on every unfilled
mount put a row of orange circles across a ship that was finished —
saying "something is missing here" about a hull with nothing missing,
and louder than anything else on the screen. Showing them on hover was
the same complaint one gesture later. The only time a bare mount is
worth pointing at is when you are holding something that fits it, and
that is what the ping below is.
```

## Pings and hints

Inside `_draw()`, above `if over and not tags:`:

```text
A PING, and ONLY on a mount with nothing in it. Drawn over an
installed part it swamped the thing it was pointing at — 27px of
rings over a gun 30px tall — which is what made a whole slot look
like it had emptied the moment you picked something up. An occupied
mount that will take a swap says so with a still frame round its part
instead (`_swap_mark`, above), which leaves the part in plain view.
HOVERING WITH EMPTY HANDS ANSWERS "WHERE ARE THE GAPS" TOO.

The note above rules out drawing empty mounts UNPROMPTED, and that
still holds -- a permanent row of rings on a finished ship complains
about a hull with nothing wrong with it. What is different here is
that the hover IS the question. Fitted parts already answer "what
have I got on this thing" with their outlines the moment you point at
the ship; this is the other half of the same answer, and without it
the hover tells you what is there and stays silent about what is not.

COLD AND FAINT, NEVER THE TRACTOR TEAL. A ping means "the part in
your hand goes here", which is an instruction; a hint means "a mount
is here", which is a fact. Same motion, so it reads as the same
animation -- a third of the alpha, a shorter reach, and the dimmest
ink on the screen, so an empty hull cannot out-shout the guns already
bolted to it. That loudness is what got the first version cut.

The two can never appear together: `over` requires empty hands and
the ping requires a part in one.
(not in the cutaway: there an empty mount waits for a part in hand)
```

Inside `_draw()`, above `var g := UITheme.CHILL`:

```text
CHILL FOR THE TRAVELLING RINGS, ICE FOR THE ONE THAT STAYS.

The first pass used COLD at a third of the ping's alpha, reasoning
from the note above that a bare hull must not out-shout the guns
on it. That reasoning was sound and the number was still wrong:
COLD is the dimmest ink in the theme and a third of it against a
hull is nothing. A hint has to be SEEN to be a hint.

Full reach and near the ping's alpha, but a cold blue-grey where
the ping is teal -- the separation that matters is HUE, not
loudness. Two things that mean different things should look
different, not one of them look absent.
```

## Fitted part drawing

Inside `_fitted()`, above `if full:`:

```text
THE PART ITSELF, and normally nothing around it. A ship is not an
inventory: what is bolted to it is the object, not a plate with the object
on it. Hovering is the exception — see `_draw`.
FLIPPED, if this one is, and standing the way the HULL decided rather
than the way the hold packed it. Both travel as arguments: a transform
set out here does not survive, because the silhouette sets the canvas
transform absolutely when it draws itself.
```

## Rarity bar

Inside `_fitted()`, above `func spots() -> Array[Dictionary]:`:

```text
NO RARITY BAR ON THE HULL, and this is where one used to be.

It was a coloured bar drawn across the hardpoint whenever the part was not
hovered -- the same rarity split the plate uses, applied out here on the
assumption that "what is under the art says how good it is" would read the
same way on a ship as it does in the hold. It does not. In the hold the
rarity is the GROUND behind a plate and the eye takes it as a background;
on the hull there is no plate, so the bar landed on top of the part itself
and read as a stripe painted down the middle of the object. Every fitted
module wore one, and it vanished on hover -- which is exactly backwards,
since hovering is when you are asking about the part.

Rarity on a fitted part is now answered by hovering it, which draws the
full plate, and by the module list on the right. That is a real loss of
an at-a-glance read and it is the trade that was chosen knowingly: a
ship is not an inventory, and the line cost more than it told.
```

## Cutaway layout

Above `static func label_leader(at: Vector2, box: Rect2, k: float) -> PackedVector2Array:`:

```text
THE LEADER FROM A RING TO ITS WORDS, when the cutaway had to set them away
from it: whole pixels (this widget's px), one wide, from just outside the
ring at `at` to one pixel short of the words' box `box`, straight. None when
the words are beside the ring anyway. The one place it is worked out: the
cutaway keeps it clear with this, the drawing draws it and `-- cutawaytest`
checks it.
```

Above `func parts_rect() -> Rect2:`:

```text
EVERY WORD THE CUTAWAY HAS PUT ON SCREEN, and every part it lifted, as this
widget draws them: [{kind = "tag"|"label"|"part", rect, text}]. For
`-- cutawaytest`, which checks none of them sits on another or on the hull.
Every part bolted on, where it is drawn at rest (this control's px): their
footprints' union, Rect2() with none. With `ShipView.fitted_rect_global`,
how big a fitted ship is -- what the station's mouth is sized for.
```

## Drop rule

Above `func takes(m: ModuleData, origin: StringName, slot: ModuleData.Slot, index: int) -> bool:`:

```text
WHETHER A DROP OF `m` ON MOUNT `index` OF `slot` WOULD LAND -- fit it, or
trade it with what is there -- for a part picked up from `origin`. THE ONE
ANSWER: `_can_drop_data` gives it to the cursor, `_draw` marks the mounts
with it, and it is `RunState.refit_allowed`, the gate `fit_at_mount` itself
goes through, with what the screens do before that call:
 - off this ship (`&"hull"`), the part is in the hand (`lift_part`), so it
   trades with any part of its kind;
 - off a loot pile (`&"bag"`), the cutaway claims it into the hold first
   (`Run.take_item`), so the hold has to have room for it -- on an empty
   mount too -- and then the resident goes in the cells it leaves;
 - anything else, from the hold or the dock: the resident goes to the hold.
Never on a ship you are leaving (`ship`), nor on a picture (`passive`).
```

Inside `_can_drop_data()`, above `return takes(m, origin, _spots[i].slot as ModuleData.Slot, int(_spots[i].index))`:

```text
AND THE RESIDENT HAS TO HAVE SOMEWHERE TO GO.

`ShipScreen._on_mount_drop` already refuses this -- it will not take a part
off the hull with no room in the hold for it -- but it refused SILENTLY,
after accepting the drag, with only a line in the log to say why. On a
packed hold that reads as "I cannot replace a mounted weapon", because the
gesture completes and nothing happens.

Answering it here instead means the cursor says no while you are still
holding the thing, which is where a refusal belongs.

`takes`, which is the refit rule's own gate: this used to ask the hold for
the resident's room whenever the part was not on the ship, which a part
lifted OFF the ship never is -- so on a full hold the cursor refused two
fitted parts trading, a move `fit_at_mount` makes without the hold at all.
```

## Cursor shape

Above `func _get_cursor_shape(at: Vector2) -> CursorShape:`:

```text
A PART ON THE HULL IS A THING YOU CAN PRESS, and the hull is one Control.

Every mounted module is drawn by this node rather than being a node of its
own, so there is nothing for `mouse_default_cursor_shape` to sit on and the
reticle stayed open across a ship covered in things you can pick up, flip and
pull off. Position-keyed, like `_get_tooltip` beside it -- the answer depends
on WHERE in this Control you are, which is exactly what the hook is for.

`_passive` is the display-only hull -- the convoy column, the shot harness --
where nothing answers a click and the pointer should not promise one.
```

## Hit testing

Above `func _get_tooltip(at: Vector2) -> String:`:

```text
Which mount is under a point, or -1.

AN INSTALLED PART IS GRABBED ANYWHERE ON IT. It used to be a radius round the
hardpoint for everything, so a three-cell rail could only be picked up by the
dot at its breech — the rest of it was scenery you could click through. An
EMPTY mount is genuinely just a point, so that keeps its radius.
WHAT IS BOLTED HERE, if the cursor is over anything.

Position-keyed, which is the only shape that works: the mounts are drawn onto
one control rather than being controls themselves, so there is nothing per
part to hang a `tooltip_text` on. Godot asks this per position and an empty
string means no tooltip at all, which is exactly right over bare hull.
```

## Taking parts off

Above `func _get_drag_data(at: Vector2) -> Variant:`:

```text
Taking a part back OFF the ship.

This did not exist for a long time, and its absence was invisible because
everything it needs already did: `_on_hold_drop` has always had a branch for
a part arriving off the hull, and the hold has always accepted a drop. There
was simply nothing anywhere that could start the drag.

`origin` is what tells the far end which journey this is. The hold uses it to
decide between moving a part between two cells and taking one off the ship.
```

## Lifting a part

Inside `_get_drag_data()`, above `if ship != null:`:

```text
OFF THE SHIP THE MOMENT IT IS IN YOUR HAND. Carrying a part while the
ship still wore it meant the mount you were dragging OUT of stayed full,
so it did not ping, and moving a gun one hardpoint along was a fight with
a slot that already looked occupied — by the thing you were holding.
`lifted` IS LIVE-SHIP BOOKKEEPING. It takes the part out of `Run.installed`
so the mount stops reading as full while the thing that filled it is in
your hand -- which is meaningless for a foreign hull, where the part is
not in `Run.installed` to begin with.
```

## Stale hints

Inside `_notification()`, above `queue_redraw()`:

```text
AND REPAINT WHETHER OR NOT ANYTHING WAS LIT. `_unlight` returns early
when `_lit` is null, which is exactly the case here: pointing at a hull
with empty hands raises the hover HINTS, and those are drawn off
`_hover` rather than off `_lit`. So the clear above happened and
nothing asked for a frame -- and `_process` only queues one while
`_animating()`, which the clear had just made false.

It went unseen for as long as every ship wearing this widget was a
LIVE one: the idle bob steps a few times a second and `_process`
refreshes on it, so the stale hints were wiped within a frame or two by
an animation that had nothing to do with them. The transfer screen
draws two FIXED builds, neither of which bobs, and the hardpoints
stayed up until something else happened to touch the screen.
```
