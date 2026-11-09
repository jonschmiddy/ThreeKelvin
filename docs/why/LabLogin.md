The reasoning behind `tkg/scripts/ui/LabLogin.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## The labs screen at rest

Above `const LOGO := &"logo"`:

```text
THE LAB'S SCREEN AT REST: the owner's screensavers (Jon, Nov 5: "you start
the lab fully zoomed out, the screen turns on like normal, has a corpo logo
or something, and you hover over the screen, it changes to a login type look
or something, and if you click on the screen the view zooms onto the
screen"; Nov 7, of the savers: "S:B,1,2,3,4,5,6 OWNER", then all 24 of the
owners' own: "O:korvan 1,2,3; solari 1,2,3; ...").

WHAT IT SHOWS: the station's owner's savers (`LabSavers.list_for`): that
owner's three plus the seven every lab runs, in its dress
(`LabSaverDress`), in an order dealt from the station, so every pilot at
that station (a co-op partner, a film) sees the same order. One stays up
`HOLD_S` on the lab's clock, then the glass dips dark and the next comes up
(`DIP_S`); nothing moves but the picture on the glass. Pointed at, the one
up holds and shows its own sign-in; it does not change while you point.

THREE STATES, each saver drawing its own look for them:

  LOGO     at rest
  LOGIN    pointing at the glass: the saver's sign-in, CLICK TO SIGN IN
  SIGNING  the glass pressed: SIGNING IN, while the camera goes into the
           glass (`LabZoom`), which lands on RESEARCH

Drawn into a SubViewport the size of the window (`StationScreen`), so the
room shows it at 1:1 and the camera carries the very same pixels in.
The glass is the only key: nothing on here is drawn as a button.

FOR FILMS AND TESTS: `saver=<code>` on the command line (`splash=` still
reads) or `LabLogin.forced = "<code>"` pins one saver and stops the turn.
```
