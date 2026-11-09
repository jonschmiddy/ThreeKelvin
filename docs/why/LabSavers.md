The reasoning behind `tkg/scripts/ui/LabSavers.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## The labs screensavers

Above `const KEPT: Array[String] = ["B", "1", "2", "3", "4", "5", "6"]`:

```text
THE LAB'S SCREENSAVERS, for its glass at rest, each with its own hover cue
and sign-in (Jon, Nov 5: "I like the screensaver the best, but I want more
options for what these can be"; Nov 7: all seven kept in the owner's dress,
"Want more per owner", then all 24 of the owners' own kept). `LabLogin`
picks which is up (`list_for`, the turn); this draws it.

THE SEVEN EVERY LAB RUNS, dressed by its owner (`LabSaverDress`):

  B  THE BOARD'S CHART, polished: drawn with the board's own painter
     (`LabBoard`'s rings, discs, halos, arms and states) where the landed
     camera will find the board, turning slowly; hover squares it up and
     zooms in a little; signing in lands it on the board's own angle and size
  1  THE SKY OUTSIDE: this system's star and worlds in a telescope, the
     crosshair stepping from world to world, readings ticking, DATA logged
  2  SPECIMEN SCAN: a relic turning as a wireframe under a scan line, its
     spectrum beside it
  3  RESEARCH FEED: findings from other pilots and the owner's labs, one line
     at a time, and a counter of routines researched galaxy-wide
  4  YOUR SHIP: the hull as a blueprint, each fitted part called out in turn
     with its augment slot
  5  THE OWNER'S POSTERS: corporate cards in plain words, one after another
  6  THE GALAXY: the run's galaxy turning as a toy, your route traced on it,
     the core pulsing

THREE MORE PER OWNER, each only at that owner's labs (`OWN`): Korvan K1-K3,
Solari SOL1-SOL3 (`LabSaversSolari`), Probate P1-P3, Redline R1-R3, Cygnet
C1-C3, Verity VER1-VER3, Calyx CX1-CX3, and the independent labs' I1-I3.

Everything is drawn on `LabLogin`'s canvas, in its window's px, on the lab's
clock (`since_on`, the lamp clock, from when this saver came up:
`rest_t`) and the look's own (`_t`): never the wall.
```

## Korvan savers

Above `func _kc(a: float) -> Color:`:

```text
================================================================== K: Korvan Heavy Works
Three savers only Korvan runs (Nov 7, Jon: "Want more per owner."):
  K1 PROOF RANGE: a test gun fires a round into a plate every 2.4 s, and the
     count of rounds without a misfire (the posting board's 71,204) goes up
  K2 SPEC CHECK: a stamped part on its jig, a gauge stepping bolt hole to
     bolt hole against the old navy's sizes
  K3 ACCOUNTS: the invoices sent to the navy stores, one a month for 201
     years, a dot each, replayed year by year
```

## Probate savers

Above `const P_BRASS := Color("#b3924e")`:

```text
================================================================== P: the Probate Combine's own

Three savers only a Probate Lab runs (r6 owners, Nov 7). Jon: "Love
these. Want more per owner." The Combine follows other people's wrecks and
files the claim first; scrap is paid on the weight.

  P1  WRECK WATCH: ships cross the Combine's watch; one slows, stops and goes
      quiet, and the Combine files its claim on it
  P2  CLAIM FILING: a claim of salvage typed out line by line, then stamped
  P3  SALVAGE ASSAY: a piece of a wreck towed onto the scale, weighed, its
      metal split by share, and paid on the weight
```

## redlines own

Above `func _red(k: float) -> Color:`:

```text
================================================================== REDLINE's own (r6, Nov 7)
Jon on the seven: "Love these. Want more per owner." Three that only Redline
Shipyards would run, each its own idea:
  R1  NO RECORD: a refit job's record typed in, then the serial, the port and
      the owner marked out; RECORD KEPT: NONE. (What it sells.)
  R2  GOING DARK: a passive sensor's waterfall, a refitted hull's return
      fading into the noise as its baffles close. (What it researches.)
  R3  OVER THE LINE: a drive hung over the blast pit, its plume run past the
      rated line and back; the line is cut where the plume crosses it. (Its name.)
Owner red is the owner's own colour (`DB.manufacturer_colour`), so the same
looks dressed for another owner take that owner's colour.
```

## cygnet dynamics

Above `func _oc() -> Color:`:

```text
================================================================== Cygnet Dynamics
(r6, Nov 7: Jon kept all seven, "OWNER", and wants more per owner. These
three are Cygnet's own: drones, cells, units that report in, no people.)
  C1  UNIT STATUS: the swarm's roll call. A honeycomb of launch cells, each
      unit flashing its signal arcs as it reports in; now and then one stops
      reporting and is replaced. Pointed at, the middle cell is yours.
  C2  FORMATION TRIAL: eight units leave their launch cells, fly a pattern
      round a beacon and come home. Pointed at, they ring your ship.
  C3  NESTED HOUSING: a unit's housing, its six cells, and the housing in
      its middle cell, zooming in without end. Pointed at, the zoom stops.
```

## verity ateliers own three

Above `var _vr_said := false`:

```text
================================================================== Verity Ateliers' own three
(review_lab r6, Nov 7: Jon kept all seven, per owner, "Want more per owner.")
  VER1  THE HULL REGISTER: the signed hulls, one entry at a time, its manufacturer's
        signature drawn in under the number
  VER2  THE SEAM GAUGE: a probe runs along one hull seam, magnified, and
        plots how flush the two panels sit
  VER3  THE COMMISSION: a new hull drawn in hairlines, then signed
```

## Independent savers

Above `const I1_TURN_S := 75.0`:

```text
================================================================== I: a lab nobody owns
Three savers only an INDEPENDENT lab runs (r6 owners, Nov 7), the lab of a station with no owner. Nobody pays for it,
so the people who live there keep it up with what drifts in and what power
is left over.

  I1  THE PATCHED RING: the station's ring turning, every plate in the
      colour of the manufacturer whose wreck it was cut from; the plate in front is
      named, and a row under it counts the plates from each manufacturer
  I2  SALVAGE WATCH: junk drifting past the station, one piece at a time
      tagged with what it is, who made it and what DATA it is worth
  I3  SPARE POWER: the station's draw against its supply over the last 30 s,
      and the loads one after another; the lab gets what is left
```
