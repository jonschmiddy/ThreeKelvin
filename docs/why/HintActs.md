The reasoning behind `tkg/scripts/sim/HintActs.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hint acts

Above `static func act(id: StringName) -> String:`:

```text
THE PLAYER DOING WHAT A HINT TEACHES (`Hints.DONE`), for `-- hinttest` and
`-- sheet=AshTutorTest`: through the screen that is up, the way a hand does
it -- the chart's row pressed, an event's row in the map's list, a choice in
the band, a card played, END TURN, a part out of a wreck's window, a module
off your ship and back on, a wreck's own click, SECTOR LOOT, a deck's button,
a drone's job, the till, the counter, SIGN, the fabricator; and the deep
tutorial's (Oct 22): a discard picked, the pointer rested on a card, a
malfunction purged, FLEE pressed, CONTINUE, THRUST held, a part put down or
pointed at in the cutaway, the FAULTS drone, TAKE IT, another deck, the escape
menu shut, LAUNCH. Not `Hints`: what the game does when the player does it,
and `Hints` has to notice.

`act(id)` returns what it did, or "" if the screen had nothing to do it with.
```
