# ChartOrbits

## What it shows

Above `class_name ChartOrbits`:

```text
THE DESTINATION PANEL, OPTION B (Jon, Nov 22): "2: B. A small map of the orbits. No
section for nearby systems (you only get that when a sector is not selected). More
information about the stars would be cool. Neutron star icon? is weird."

The map is read off SystemLayout.of(n), the function SystemView calls on arrival, so
the arcs are the ones the player finds. SystemLayout is derived (Rng.derive by node
index) and OptionTable.ensure rolls a node's options off its own derived stream, so
reading it early moves nothing: OrbitPreviewTest flies the same path twice, once
looking first and once not, and holds the two layouts equal.

What it leaves out, because the game does not fix it ahead:
  contacts     a fight's place is an event; the Hellbender and the Custodian move or wait
  the comet    rolled per visit (CometPath)
  events       what is on a world is for the sector panel on arrival
A signed job's place IS shown (a flare diamond): it is posted at signing and circled
on the chart already.

Jon, Nov 22, on the first renders: "Show the stars underneath the name of the sector.
Remove the HOT line. Let's have the system info at the top and then the simplified
sector map view." So the panel reads: the name, the star as the sector map paints it
(SunView; a pulsar in the chart's own point-and-beams, since its map painter is a
480 x 320 animated box tied to the map's rect and sky flash), one list of STAR, RADIUS,
BINARY, DANGER, FUEL and WARNING with the beam's line beside WARNING, then the orbit
map with a small sun on its edge, then the counts. The hot line and its HOT label are
gone; so is the HOT ZONE row, which read 4.75 AU round every star.
Jon, Nov 23: "Let's have the x planets x giant x belt x wrecks above the simplified
orbit map." The counts line moved from under the orbit map to just over it.

A pair draws both suns on the edge; a world round one sun sits beside it, and the arcs
are the worlds round both.
```

## Looks

Above `const LOOKS: Array[StringName] = [&"arcs", &"orrery", &"lineup", &"arrival"]`:

```text
THREE OTHER PICTURES OF THE SAME ORBITS (Jon, Nov 23: "Can I get a couple versions of the
simplified sector map?"), each a different idea, behind a dev switch (`look`; ChartShot's
`orbitlook=<look>`, or `looks` to photograph the panel in all four):
  arcs     today's: the star cut by the left edge, an arc per orbit, linear in AU
  orrery   top down: the star in the middle, a full ring per orbit spaced by order (a
           ring per AU would crowd the inner worlds into the star in 72 px), each world
           at the angle it has as the map opens (`Run.map_t`); a world round one sun of
           a pair beside that sun, at its angle
  lineup   the star at the left, one line out, the worlds on it in orbit order, each at
           its own size and colour (a giant big, a rock small, a belt a column of dots)
  arrival  the sector map itself, small: its projection (`SystemView.TILT`), its orbits
           as ellipses, the whole system fitted, each world where it is as the map opens
           and in its own colour (`Worlds.RAMP`)
Every look draws the same marks from the same `read`, so the counts line and the match
with arrival hold for all of them; OrbitPreviewTest checks each look over a seed's
systems (in the box, the same before and after arriving, angles as the map opens).
```
