The reasoning behind `tkg/scripts/data/IntentData.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Describe

Above `func describe() -> String:`:

```text
WHAT THIS DOES, WRITTEN FROM ITS OWN NUMBERS.

`text` is authored against the danger-1 numbers, and `Combat._spawn` scales
`damage`, `block` and `heal` per fight -- so at danger 5 a RAM printed "Deal
14" and hit for 15, and a Barrage printed "5 x 3" and killed a ship at 5 hull
with 6 x 3 (combat polish audit, item 4). The screen reads this, never
`text`, for anything with a number in it. A wind-up or an escape has no
number and keeps its authored line.
```
