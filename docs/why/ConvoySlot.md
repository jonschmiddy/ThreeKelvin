The reasoning behind `tkg/scripts/ui/ConvoySlot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Partner slot

Inside `_draw()`, above `var _engaged: bool = false`:

```text
In the same fight as you, right now.

Worth its own mark because the column shows the whole party and a fight
involves some of it. Three ships in the sector and two in the fight is the
normal case, not the exception — people arrive at different times — so
"who is shooting at the thing shooting at me" cannot be read off presence.
```

## Partner label redraw

Inside `_draw()`, above `art.visibility_changed.connect(queue_redraw)`:

```text
THE NAME AND GAUGES COME BACK WITH THE HULL. `_draw` paints nothing
while the hull is hidden, and `ShipView.arrive` hides it for its first
tick after the flare has already asked for a redraw -- so the slot
drew once, empty, and nothing asked again: the partner flew in with no
name over it (seen in the Oct 22 stills, LOCAL and the fight alike).
```

Inside `_draw()`, above `queue_redraw()`:

```text
And ask for the name and the gauges back. They are painted by this
slot rather than by the hull, and _draw() bailed out while there
was no hull under them — without this the ship returns and its
label does not, because nothing else redraws a settled convoy.
```

## Gauge placement

Inside `_draw()`, above `_gauge(float(fs) + 3.0, _hull_at, UITheme.HULL_GREEN)`:

```text
Directly under the name rather than at the floor of the slot. The ship
is centred in the box and the box is taller than the ship, so bars on
the floor float in space below it and read as belonging to whoever is
next in the column.

Hull above heat, which is the order they are stacked on the HUD and
under every enemy.
```

## Out of the station

Jon's co-op rules, Nov 13 (`docs/why/SectorScreen.md#partners`). At a station a
partner comes and goes through the dock as well as by jumping. `come_out` brings
the hull from the station's mouth (`EncounterView.mouth_g`, INF until the station
is up, so it waits) to its place over `OUT_S`: quick out of the mouth, easing in,
its engines lit until it slows, a little smaller out of the depth. Moored left
that path is a back-out; moored right it is nose first. `go_in` runs it the other
way, into the mouth, and frees the slot. `fade_out` fades it where it sits. The
slot stops cropping while the hull flies, so it can be drawn outside it, and draws
no name until it is in place. Moored right (`flipped`), the slot flips its own hull
and its name back, and holds the hull `FLIP_IN` px in from the screen's edge.

