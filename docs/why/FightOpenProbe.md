The reasoning behind `tkg/scripts/sim/FightOpenProbe.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Fight open probe

Above `const ROLES := ["screen", "ship", "plate", "band_quiet", "quiet_panel", "band_hand",`:

```text
WHERE EVERYTHING ON THE FIGHT'S SCREEN IS, ONE FRAME AT A TIME, for the
opening of a fight (`FightOpenFilm`, `FightOpenTest`). Every element that
changes place or appears as a fight starts, by role, so the LOCAL screen a
fight is started from and the fight's own screen are compared as one
picture: a role is looked up on whichever screen is current.

Each sample is `{role: [x, y, w, h, alpha]}` in game px (the 960 x 540
canvas), alpha the product of every modulate up the tree (0 when hidden).
Bob-free: your ship is its canvas's box (`ShipView.hull_rect`) and each enemy
its holder, the box its layout gives it; the enemy's own fly-in is
`enemy<i>_fly`, its art's offset from that box, kept apart because it is a
flight and not a jump.

Also says, per frame, whether a card or END TURN / FLEE / HAIL / a pile would
take a click (`clickable`).
```
