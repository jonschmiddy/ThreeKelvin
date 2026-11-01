# CHANGELOG draft for ruling 20 (fill the [brackets] after Jon's picks)

Under ## [Unreleased], newest first:

- **Added** — two-star systems. About one ordinary system in four now has two suns that circle
  each other. Some worlds circle one sun and some circle both. The sector panel lists both suns,
  and FLY HERE works on either one. The star chart marks a system with two suns. Its second sun
  is an orange dwarf, smaller and cooler than the first. Each world takes the light of the sun it
  circles, and in PAINTED the far cloud's edges catch the light of both.
- **Changed** — the autopilot flies a real path through the pull of the suns and the giants. The
  path is worked out before you click, so the dotted line is the flight the ship will fly, burns
  and all. A flight from place to place takes about 11 seconds, where it took about 7. Flying inside
  a system still costs no fuel, and flying with WASD still feels no pull.
- **Changed** — gas giants are heavier, from a tenth to a quarter of their star. A flight that
  passes close to one bends around it. A giant's page shows its MASS.
- **Fixed** — leaving the sector map during a flight no longer drops it. The ship arrives where it
  was going, and a GO still opens its event. Changing the render style or GRAPHICS during a GO no
  longer loses the event and locks the map.
- **Changed** — during a GO you can hover, zoom and drag the map. Clicks that would start another
  flight still wait until you arrive.

Notes for the merge:
- SaveGame VERSION 38 (`twin`); a save from before loads with one sun everywhere.
- NetSession PROTOCOL 13: partners on 0.4.2-alpha.1 cannot join a 0.4.3 host. Say so in the
  release notes.
- Run prose_grade.py / prose_tells.py on these lines before landing.

# DEVELOPMENT_PLAN draft

Phase 13 step 5: "**Built Oct 30 to Nov 1** (ruling 20, "Prototype: twin:A giant:A"): two-star
systems in about 1 ordinary system in 4, giants at 1/10 to 1/4 of their star, and the autopilot a
solved flight on map time through both stars' pull (FlightSolve + MapGravity), with two-leg flights
where one leg reaches nothing. Flight length: C (ruling 21, Nov 1). Open: [the looks sheet's items]."

Rulings table row:
| Twin stars and heavy giants (ruling 20) | "Prototype: twin:A giant:A": two-star systems, giants 1/10 to 1/4 of their star ("purely because it's more fun"); autopilot only, WASD keeps no gravity | Oct 30; Phase 13 step 5, feat/twin-stars |
| Flight length (ruling 21) | "Flight length: C" | Nov 1; Phase 13 |
