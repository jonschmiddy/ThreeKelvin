The reasoning behind `tkg/scripts/sim/CalmLadderTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Calm ladder checks

Above `var _fails := 0`:

```text
ONE MOTION EVERYWHERE (Jon picked A of the nav audit's three directions, Oct
17: "the movement between local > sector > starchart ... EXTREMELY
disorienting"), headless with the animation on, the ladder's clock stepped
1/60 s a frame:
  godot --headless --fixed-fps 60 --path . -- sheet=CalmLadderTest
(fixed fps: the goal line's fade is a tween on the engine's clock, which must
step with the ladder's)
Every hop between LOCAL, the map and the chart -- by its HUD tab (a real
click), by Tab, by NEXT SCREEN rebound to N, both ways where the route goes
both ways, from a world's orbit and from the system's edge -- watched frame by
frame for what the audit measured going wrong:
  - ONE SHIP: wherever the picture held from the screen left and the screen
    arriving both show, they show your ship in the same place (4 px);
  - ONE STRAIGHT LINE: your ship's place on screen keeps within 6 px of the
    line from where it rested to where it rests, never turning back on it,
    never more than 40 px in a frame, never under the side bar;
  - NO ONE-FRAME SWAP: the held picture never leaves (or comes) by more than a
    fifth in one frame, and the screens change hands under it whole;
  - THE CHROME STILL WHILE THE CAMERA MOVES: no side bar or toolbar decode, no
    sliding column or band, no side bar or toolbar moving or fading, on any
    frame your ship is moving (one frame's grace at the landing);
  - THE HOP'S LENGTH within 10% of its target (`ZoomLadder.calm_length`, or
    A's 1.55 s where there is none);
  - A PRESS MID-MOVE: a key, a click on the picture, Tab -- the move hurries
    to its end (under 0.45 s from the press), no frame of it a cut, and the
    press is not lost (Tab goes on to the next distance);
  - ONE FIELD UNDER IT ALL (Jon, Oct 18: stars edge to edge, the panels built
    on top): the Router's `NavField` is the same layer on every frame of every
    hop, on, under the screens, never faded, never redrawn (its `version`);
  - THE PANELS DRAWN AS THEY MOVE (Jon, Oct 18: "they come in blank now"):
    on every frame a side panel or toolbar row slides, it is the screen's own,
    opaque, with its words on it -- never an empty plate;
  - THE SHIP HOLDS WITH THE MAP'S CLOCK (Jon, Nov 2, "Pair calls: 4A"): on
    every frame a map's clock holds for the move (`clock_held`, the map up,
    put away or built ahead), its ship on the plane and its clock stand where
    they were on the hold's first frame, and when the clock runs again the
    ship goes on from there by no more than a frame's ride (`RESUME_PX`);
    a partner drawn on it holds too, its reports coming in all the while,
    and eases on to the latest once the clock runs (`_partner_holds`); and
    a place's preview, drawn before the move, kept through it, not planned
    again frame after frame (`_preview_holds`); and a key held into the
    move and let go in it goes quiet on the next frame, its flame out, as
    it always did, on the ring and flying free (`_keys_let_go`).
Written to run on main too (the ship's place read by the hooks every build
has), so it can be watched failing there.
```

## Clock hold

Above `func _watch_hold(seen: Dictionary, was: Variant) -> void:`:

```text
THE SHIP HELD WITH THE MAP'S CLOCK, this frame, on every map there is (the
one up, the one the hop left, put away, and one built ahead), by map: while
its clock holds (`SystemMapScreen.clock_held`), the most its ship has moved
on the plane and its clock run since the hold's first frame; on the frames
after (to the end of the rest), the most it moved in one, and how far it
went from where it was held.
```

## Partner hold

Above `func _partner_holds() -> void:`:

```text
A PARTNER HOLDS WITH THE MAP'S CLOCK (Jon, Nov 2, "Pair calls: 4A"), as your
own ship does: LOCAL -> map by its tab, a partner off a world of this system,
its report moved on 6 px every 10 frames as a partner riding its ring at
RAIL_V on its own machine would send. On every frame the map's clock holds it is drawn in one
place on the plane (`SystemOverlay._draw_partners`); once the clock runs it
eases on to the latest report, never more than `JUMP_PX` in a frame.
```

## Preview hold

Above `func _preview_holds() -> void:`:

```text
A PREVIEW HOLDS WITH THE MAP'S CLOCK (Jon, Nov 2, "Pair calls: 4A"): on the
map, your ship on its ring, another world selected and its flight drawn,
then map -> chart by its tab. Through the hold the drawn flight is kept and
at most one more plan is taken in; with the ship riding on by frame time
each plan came back stale (made from where the ship was, at a clock that
stood still), was dropped and was asked for again, the whole move long
(the review 2 render note).
```

## Field drift

Above `func _field_drift() -> void:`:

```text
THE FIELD DRIFTS ON A PAN (Jon: "Why is the parallax gone from the sector and
starchart views?"): a drag on the chart and one on the map slide the field
(`NavField.pan`, its far layers' `u_skyPan`) the way the drag went, the
chart's by its own sky's pan; a hop never moves it (`_field_wrong`, every
frame of every hop above) and never puts it back: across each hop it stands
where it was, and LOCAL arrived lies where it does (`LocalSky` `u_skyPan`).
```

## Goal line and box

Above `func _no_box() -> void:`:

```text
THE GOAL LINE (`GoalLine`, tutorial B) under the HUD: gone before the camera
moves, on no frame of it, and back once the hop has landed.
NO BOX ROUND THE PICTURE (Jon, Oct 18: "why is there a box around the galaxy
panel?"): on the map and the chart at rest, the picture's frame draws no
line and fills nothing, and its key fades what the picture holds out toward
its edge (`nav_key.gdshader` `fade`) rather than cutting it. (The pixels are
read windowed: `-- sheet=FieldEdgeTest`.)
```

## Goal line HUD

Above `func _goal_line() -> void:`:

```text
THE GOAL LINE (`GoalLine`) A PIECE OF THE HUD (Jon, Oct 18: "Can we have the
goal: xxx always be in this location?"; Oct 20, "snug:B": below the top plate
on the map and the chart, snug under the HUD on LOCAL, "smooth animation as
it drops down or up"): up on every frame of a move between them, at the same
left; moving only while the top plate slides and at the plate's own point on
its curve, in whole pixels, a few a frame at most and one way only; never on
the plate or the HUD; still between the map and the chart; and at rest where
the screen arrived at has it.
```

## Fast flight holds

Above `func _flight_holds(path: StringName) -> void:`:

```text
A FAST FLIGHT HOLDS WITH THE MAP'S CLOCK (the fast transfers, Nov 5): on
the map, your ship flying to another place on `path` at its pace
(`ShipFlight.FLIGHT_PACE`: DIRECT x4, CURVED x4),
then map -> chart by its tab mid-flight. Through the hold the ship stands
where it was (the map's clock and the flight held, not run on at x4 under
the still picture), and back on the map it is at that place.
```
