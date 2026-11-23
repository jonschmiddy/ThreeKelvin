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

A pair draws both suns on the edge; a world round one sun sits beside it, and the arcs
are the worlds round both.
```
