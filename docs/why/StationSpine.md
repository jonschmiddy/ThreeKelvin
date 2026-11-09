The reasoning behind `tkg/scripts/ui/StationSpine.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Station spine

Above `var floors: Array[StringName] = []`:

```text
The station in section, five floors of it, drawn behind the deck rail.

THE RAIL WAS FIVE BUTTONS AND IT IS A BUILDING NOW. A tab strip tells you
which page you are on; a cutaway tells you where you are STANDING. They cost
the same vertical, and only one of them makes the station a place -- so the
decks are floors of one structure, stacked in the order you walk them, and
the one you are on is the one with its lights on.

EVERY FLOOR IS AN INTERIOR. That is the whole conceit: you are inside this
thing. Nothing here is drawn from outside, there is no starfield, and the
hull walls run down both edges of every floor to say so.

The rooms were drawn rather than loaded, as the placeholder AND the fallback;
the art has landed (`_draw_picture`), and a deck without a picture still gets
its room in rectangles.
```

## Elevator car

Above `var car: float = -1.0`:

```text
WHERE THE CAR IS, as a floor number that need not be a whole one.

THE LIGHT TRAVELS, AND THAT IS THE WHOLE ELEVATOR. `active` says which floor
you have chosen; this says where the car has actually got to on its way
there. At 2.4 it is between the third and fourth rooms, and both of them are
partly lit -- so a floor brightens as the car arrives and dims as it leaves,
which is what makes it read as something moving through a building rather
than as a highlight teleporting between rows.
```

Inside `_draw()`, above `if car >= 0.0:`:

```text
--- THE CAR. A lit frame the height of one floor, at wherever it has got to.

Drawn as a FRAME rather than a fill: a filled box would hide the room it is
standing in, and the room is the thing you came to look at. Four edges and a
brighter left post, because the post is the side the labels are on and it is
what makes the selection read from across the screen.
```

## Parallax

Above `var parallax: float = 0.0`:

```text
How far the far wall of each room is offset, in pixels.

THE BACK OF A ROOM IS FURTHER AWAY, so it is drawn inset. This used to be
driven by the building sliding in its shaft; the building does not slide any
more -- the CAR does -- so it is a fixed inset now and the depth comes from
the light moving across rooms that have a behind.
```

## Floor pictures

Above `const RAIL_DIR := "res://art/sprites/station/rail/"`:

```text
THE FLOORS ARE PICTURES NOW (Jon, 2026-10-01: "Can we have these animated
and colored when on the respective floor? ... When the floor is not active
... the colors are muted a lot and not animated"). One per deck, the same at
every station, installed by `tools/rail_install.py`: the floor the car is on
plays its frames in full colour, every other floor stands muted and still,
and as the car passes a floor fades from one to the other. A deck with no
picture keeps the rooms drawn below.
```

## Furniture contrast

Inside `_draw()`, above `var furn := plate.lerp(EDGE, 1.4).lerp(LAMP, 0.16 * glow)`:

```text
THE FURNITURE IS DRAWN BRIGHTER THAN THE ROOM IT IS IN, and the first
pass was not. Everything in here was `plate` on `wall` -- #151e2a on
#0d141d -- which is eight levels of difference at 156 pixels wide, and
eight levels of difference is nothing. The walls stay dark because the
ship on the Yard has to read against them; what is IN a room has no
such duty and has to be legible at a glance from a rail.
```

## Label shadow

Inside `_draw()`, above `for band in 5:`:

```text
--- A SHADOW DOWN THE LEFT, UNDER THE LABELS.

The deck names sit over this drawing and nine-pixel type on a lit stall is
not type you can read. So the near side of every room is in shade -- which
is also what a room lit from the far wall would actually look like, so the
thing that makes the words legible is the same thing that gives the section
its light direction. Banded rather than smooth: a gradient is not a move
this renderer makes, and hard steps are what pixel art uses for falloff.
```
