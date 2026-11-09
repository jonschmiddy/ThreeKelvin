The reasoning behind `tkg/scripts/sim/LabSaverTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## The labs savers

Above `var _fails := 0`:

```text
THE LAB'S SAVERS, headless:
  godot --headless --path . -- sheet=LabSaverTest [cost]
Jon, Nov 7: all seven savers kept in the owner's dress, and all 24 of the
owners' own ("O:korvan 1,2,3; solari 1,2,3; ...").

THE TABLE (`LabSavers.list_for`): every owner, and a lab with none, runs ten
savers, its own three and the seven, no other owner's; the same station
deals the same order every time, and stations differ; an owner not in the
table runs an independent lab's. Every owner's dress (`LabSaverDress`) has
its five posters, and no player line on them has a dash.

THROUGH THE REAL STATION SCREEN, at the settlement (the smallest glass,
206 x 110) and the capital, for every owner and a lab with none: the lab's
screen runs that owner's ten; each one pinned (`LabLogin.forced`, as films
pin one) draws at rest, pointed at (with a SIGN IN on it) and signing in
(SIGNING IN on it), every look passing the box test (`LabLogin.check`) and
every box inside 960x540 where the landed camera puts it; and the glass,
clicked with the saver up, lands on RESEARCH. Each look is taken at a fixed
moment in the saver's own clock (`REST_AT`, by `LabLogin.rest_pin`), well
into it, so a run is the same every time (a moment on the wall's clock
caught saver 5 mid-wipe one look in thirty).

VER3 POINTED AT while a drawing fades holds the signed drawing, not a near
empty glass.

THE TURN, at the settlement with a short hold (`LabLogin.hold_s`), at a lab
whose owner is known only from its first berth: the savers come up in the
station's order on the lab's clock, the glass dips dark between them, the
glass (the one key) never moves, and pointing at it holds the one up;
pointed at while it is dark, the glass brightens over a quarter second and
does not jump.

THE GLASS HEARD (Jon's picks, Nov 7; read off `Audio.tape`, Audio being off
headless): `lab_glass_hover` once as the pointer arrives on the glass, not
again while it stays, again after it leaves and comes back, never while the
glass is hidden, signing in or on the camera's way back out with the pointer
still on it; the press that signs in plays `lab_login` once, on the frame of
its `ui_click`; a press refused (the camera already in) clicks alone.

`cost` prints each saver's draw cost (`LabLogin.paint_us`) at rest, the mean
and worst over a second, and fails one over `COST_MAX_US` on average.
```
