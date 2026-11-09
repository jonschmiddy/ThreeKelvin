The reasoning behind `tkg/scripts/ui/ShipSlot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Own ship slot

Inside `_draw()`, above `const HULL_BIAS := 0.68`:

```text
How much of the slot the hull is centred in. The rest is empty space on
its right.

The frame is "your ship left, what you face right", and a Control that
fills its half and centres its texture puts the ship in the middle of the
screen — which reads as neither. Centring it in the left two thirds of the
same box moves it back onto the left without changing the layout, and it
leaves the ship pointing INTO the space the subject occupies rather than
across it.

Done with an anchor and not with `position`, because `ShipView.arrive()`
animates position and puts it back to zero when the ship parks.
```

Inside `_draw()`, above `art.zoom(1)`:

```text
2x, matching the refit screen and the chassis select. The hulls are
authored small enough that 1x here left the ship a detail in the
middle of its own encounter — and this is the screen the game is
mostly played on, so it is the one that should agree with the others.

1x, solo or crowded. The hulls are authored at 2x their box, so this
is the full-size ship and there is no step below it.

zoom(), not magnify(): the slot's width is anchored to a fraction of
the encounter and a minimum size would fight that.
```

Inside `_draw()`, above `art.bob(2)`:

```text
THE IDLE DRIFT, which this slot never had. The convoy slots below ask
for `bob(1, 0.19)` and call it "slower and shallower than your own
ship's" -- a comparison to a bob that was not there. The ship screen
and the chassis select both use 2, so that is what your own ship's is.

It moves inside the canvas rather than moving the Control: see
`ShipView`'s note, which is why anything riding the hull has to take
the offset out again. `_place_self_plate` does.
```

## Jump flare

Inside `_draw()`, above `_flare_box = Control.new()`:

```text
THE COLUMN YOU LEAVE ON. The convoy slots have had one of these since
they were written; your own ship never did, because your own ship
never left while you were watching.

IN A BOX THE SIZE OF THE HULL, not of the slot. JumpFlare.MAX_W is 20
and its own comment reasons that against a 208px slot holding a 124px
hull: a beam that wide is "plainly a thing the ship came out of".
Across this slot — most of half the arena — twenty pixels is a rule
somebody drew, not a column. So the box is sized to the art, and added
last so the flash is in front of the hull rather than behind it.
```

Inside `_draw()`, above `func _process(_d: float) -> void:`:

```text
Fire the column over the hull, wherever the hull has got to. Returns it so
the caller can hang off `peaked` — the frame the ship changes hands, which
is what that signal was built for.

Re-measured at play time rather than at build time, because the departure
leans the hull twenty pixels right before this fires and a beam that
arrives where the ship was is a beam that missed.
THE COLUMN TRAVELS WITH THE SHIP. Placed once at play time it stayed where
the hull had been while the hull kept accelerating out of it -- by the peak
the ship had outrun its own flare by most of a hull length. Two lines a
frame, and only while the thing is on screen.
```

## Drag preview

Inside `_draw()`, above `if _drag_text != "":`:

```text
What this card would give you, over your own hull. Same idea as the
enemy's number and the opposite colour: one is what you take off them,
the other is what you put on yourself.
On the hull too, for the same reason the brackets are, in the same
letters a landing pops (`HitText`): centred on the hull's INK, not
the bracket box (clipped to the view) nor the canvas (which carries
the exhaust's clearance on one side).
```

## Hull box follows the slot

Inside `_notification()`, above `if what == NOTIFICATION_RESIZED and art != null:`:

```text
THE HULL'S BOX FOLLOWS THE SLOT'S. A shudder or an arrival writes the
hull's `position`, and on an anchored Control that writes its size
into the offsets: written while the slot was narrower than the hull's
canvas (the convoy column in), it kept that clamped size when the slot
widened again, and your ship sat 37 px right of the solo view's when
the column slid out (J4 B, `-- sheet=ConvoySlideTest`). The offsets
keep only the move the shudder made.
```
