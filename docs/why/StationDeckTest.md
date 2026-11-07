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
elevator lights five floors; the lab's screen lists RELIC ANALYSIS at that
level's price, its row inside the screen's window (the settlement's is the
smallest, 218 x 118, and it never had a lab before); with no berth the board
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
