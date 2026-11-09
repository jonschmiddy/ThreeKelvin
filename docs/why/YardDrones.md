The reasoning behind `tkg/scripts/ui/YardDrones.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Yard services

Above `const PH := [0.0, 1.3, 0.6, 2.1]`:

```text
The Yard's four services, each carried on one of the station's flyer drones
over your ship (the Yard Drones page's drones, `step`, `carry`, `buy`,
`drawDrone`, `drawWork`): PATCH, REPAIR, REFUEL and FAULTS.

THEY COME AFTER THE TV (Jon: "can we have the drones fly in more spread out
AFTER the TV turns on ?", then "closer together ... but not all at the same
time"): the first 0.4 s after the deal has scanned onto the TV, the others
about 0.42 s behind each other. Each bobs above your ship, and what it
carries says what it will do and what it costs. Pointed at, its glass lights
amber; clicked, it dips to the hull and does the work -- a torch for a patch,
a welder's white for a repair, fuel coming down, a scan down the hull for a
fault. When there is nothing left for it to do its screen says why ("HULL
FULL", "NO FAULTS") and it flies off; on paper, at an unclaimed station, what
it offered is scribbled out in red first. One with nothing to do when you
dock never comes; REFUEL always does.

WHAT THEY CARRY is the level's (Jon, 2026-09-29): paper scraps at an
unclaimed station, chunky casings at an outpost or settlement, riveted
frames in a city, glowing frames at a capital.

AND NOW AND THEN, ONE OF THEM MISBEHAVES (the page's rare events): it nods
off and sinks (E1), two bump screens (E5), one shows a joke (E6), one
sneezes (E18).
```
