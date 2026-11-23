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

Scale is linear in AU so the hot line (SystemLayout.ZONE_NEAR, 380 px, 4.75 AU) sits
where it really does against the orbits. A one-sun system picks each world's pool by
its index, not its distance (SystemLayout._worlds), so a world just past the line can
still be a hot one; the line is the game's rule, not a promise about each world.

No HOT ZONE row (coordinator, Nov 22): 4.75 AU is the same round every star, so the
row said nothing; the arc is labelled HOT once at its top end instead.

A pair draws both suns on the edge; a world round one sun sits beside it, and the arcs
are the worlds round both.
```
