The reasoning behind `tkg/scripts/sim/StationDeckTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Test purpose

Above `var _fails := 0`:

```text
ALL FIVE DECKS AT EVERY STATION, headless:
  godot --headless --path . -- sheet=StationDeckTest
Jon, Nov 3: every station has the PROMENADE, SHIPYARD, EXCHANGE, HIRING BOARD
and LABORATORY, at every development level. The LABORATORY used to hide below
a city (RELIC ANALYSIS was dev 3) and the HIRING BOARD where no manufacturer
berths (an empty `Contracts.board`).

Through the real station screen, at each level from UNCLAIMED to CAPITAL,
once with no berth and once with one: all five tabs are on and shown and the
elevator lights five floors; the lab's screen shows the owner's logo, and
the sign-in while the pointer is on the glass (Jon, Nov 5), each inside the
screen's window, nothing overlapping (the settlement's 206 x 110 is the
smallest); the glass is the only key (a click just off it opens nothing,
Enter and the pad's A press it); pressed, the camera goes onto the glass
(`LabZoom`, science S9, Jon's 1C), one uniform zoom landing at the lab's
whole number with the board's glass inside the lab's, and RECIPES (AUGMENT's
layout, Jon, Nov 5) greys every recipe with nothing held, prices RELIC
ANALYSIS at that level and the other two at no credits, picks by a click on
a row and a ring, and its MAKE survives thirty refreshes and makes, and
the RESEARCH board passes the mockup's box test (every box inside the glass,
none overlapping, no word across an arm) with no step, some and all of them
bought and the strip on every step; AUGMENT passes it on every part and
every affix (one part augmented, one with a rolled affix, DATA short, a
hold that runs onto a second page, STRIP on each affix), costs 5 DATA and
22/20/18/16/15 credits, its key survives thirty refreshes, a click on a row
moves no part, AUGMENT and STRIP pressed through the viewport do what they
say; BUY stays one object through thirty
refreshes, never shows on a step behind the next, buys, and the board is the
same at a second station of the run; with no berth the board
posts its dock desk's work (`Contracts.dock_desk`), hangs the desk's notice,
and a job signed there is handed in at that desk; with a berth there is no
desk.
A board with nothing to post says NO WORK POSTED. and keeps its tab. The
chart names the dock desk under OPERATORS, and every such line fits the
destination panel.
```

## Address order

Inside `_dock_desk_rule()`, above `var made: Array = []`:

```text
One process keeps one address order, so the real table cannot show the
fault. A table of fresh StringNames made in reverse text order can: their
addresses fall in no text order, and a different one each process (3, 4,
2, 5, 1, 6, 7 one run and 1, 5, 2, 4, 3, 7, 6 the next on Nov 3), and a
`keys().sort()` pick follows the addresses. Checked failing on that sort.
```
