The reasoning behind `tkg/scripts/ui/YardDeal.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Yard deal TV

Above `const LID := 13`:

```text
The deal, on each level's own TV at the bottom right of the Yard (the Yard
Drones page's `drawTerminal`, `groundTV`, `LIGHTS`, `signal`, `sagWithBulb`).

JON'S PICK FOR EACH LEVEL, lit and misbehaving the way that level's lab does:
its lamps are its own painted pixels, brightened and dimmed by the lab's
clock (`LabScene._weights`, ported); its glass warms, then the deal scans in
-- what they ask, what your ship is worth to them, and what leaves your
account, over TAKE IT. Then the lab's screen trick: unclaimed's screen
failing with its bulb, the outpost losing its signal every 2.6 s and the
settlement every 14, the city's sweep, the gold light running round the
capital's glass.

THE BOX TAKES THE HALL'S LIGHT as it stands when the TV is fully on (Jon:
"the boxes shouldn't be fully dark... just the screen"): only its glass and
lamps follow the power-on. It stands on the floor, with a top, a contact
shadow and its foot in the polish, and its lamps light the floor in front
of it ("it looked pasted in").

THE GLASS is composed in its own small viewport every tick, as the page
composed it in a canvas of its own: the bands a bad signal slips are pieces
of that picture.
```
