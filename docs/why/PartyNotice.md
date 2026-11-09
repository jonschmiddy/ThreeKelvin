The reasoning behind `tkg/scripts/ui/PartyNotice.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Party notice

Above `const TOP := 34.0`:

```text
A line from the party that every screen shows, top centre, until clicked.

For the one thing nothing else in the game can say: the galaxies of two
machines in one party do not match (`NetSession._galaxy_differs_here`). A
line in the ship's log scrolls away and a fight's log is not up on the map,
and a player who has not been told has no reason to send the log the
developer needs. So it sits over everything, on top of the HUD's own layer,
and goes when the player clicks it.

Top-level like `FpsMeter` and `LowHull`, so it takes part in no layout.
```
