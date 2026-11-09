The reasoning behind `tkg/scripts/ui/ChitIcon.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Credit chit

Above `var chit: CreditChit = null`:

```text
Money in a container.

Drawn as stacked notes rather than as a crate, because the one thing it must
not look like is something that will cost you room -- see `CreditChit`. A
player who reads it as cargo will leave it behind when the hold is full,
which is the exact decision this item exists not to make you take.

Same flat rectangles as everything else, and the same stacked-notes idiom
`CardView` already uses for its `scrip` glyph: "the human economy, which is
the only kind a card ever pays out in".
```
