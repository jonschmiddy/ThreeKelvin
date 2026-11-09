The reasoning behind `tkg/scripts/sim/OutcomeCheck.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Outcome check

Above `const WORDS := {"credits": "CREDITS", "heat": "HEAT", "hp": "HULL", "fuel": "FUEL"}`:

```text
WHAT AN EVENT'S RESULT SAYS YOU ENDED UP WITH, checked against what actually
moved (`OutcomeRow`, all four looks). Shared by `-- localeventtest` (every
choice of every option, in the bare band) and `-- sheet=OutcomeTest` (real
outcomes on the real LOCAL, with the HUD).

The expectation is read off the RUN, not off `OutcomeRow`: the ledger either
side of the choice, the system's pile, the hold and the found frame, diffed
here. A look that drew what `OutcomeRow.changes` said would
agree with itself whatever the run did.

THE NUMBERS: today's four pairs ("HULL -5", "CREDITS —"); A and C one entry
for every change and nothing else ("-5 HULL", "+1 PART: ...", no dash
anywhere); B a row for every change with its totals ("HULL -5 35 > 30");
E a row for every change with its new total ("HULL -5 31"); NOTHING GAINED
OR LOST when nothing moved. D only the four stats that moved, each its
change alone ("HULL -5"), and no table when none did (Jon, Oct 19); and
DATA a fifth by the same rule (Jon, Nov 4, science pick 2A): a reading's
table reads "FUEL -2", "DATA +5".

THE BOXES (fit means nothing overlaps): every entry inside the band, apart
from every other entry, off every button (CONTINUE, REWARD, CHOOSE AGAIN,
THEY ARE FIRING), off the text, the head and the YOU CHOSE line; B's rows
inside their own column; and CONTINUE where today's look puts it.
```

## Outcome table

Inside `check()`, above `var rows: Array = []`:

```text
THE FOUR STATS AND DATA, NOTHING ELSE (Jon, Oct 19: "let's only
show CREDITS, FUEL, HULL, HEAT on the right"; Nov 4, 2A: DATA
too): a row for each that moved, its change and no total ("just
put what is added or lost"), in hull, fuel, credits, DATA, heat
order, no thing ever (those are REWARD's), and no table at all
when none of them moved
```

Above `static func d_place(d: LocalEventDrawer) -> Array:`:

```text
D (Jon, Oct 19: "can the text on the right be a bit bigger? and centered
vertically?", "can we also have the buttons at the top right?"): the table
at `OutcomeRow.D_FS` (8: Jon saw 16 and kept 8), the four stats that moved
only and none when none did (`check`); the buttons at the top right, level with the title,
inside the band and clear of the title, YOU CHOSE, the text and the table;
the table under them, its right edge on theirs and at least their width,
centred in the room under them (in the band; on the card it sits at the
foot, the buttons on the title's line or a line of their own over it).
```
