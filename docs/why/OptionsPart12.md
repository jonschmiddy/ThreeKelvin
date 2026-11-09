The reasoning behind `tkg/scripts/systems/options/OptionsPart12.gd`; each heading is referenced from the code by a `Why:` line.

## Comet readings

Above `static func entries() -> Array[Dictionary]:`:

```text
The science design held three comet readings for Phase 13 (DESIGN_FITS_THE_GAME,
ECONOMY_RISK_DESIGN). They are sited on the comet (`site = &"comet"`) and reached
only by its spots (`CometCatch`), never by GO. Each has the science shape: a
reading that burns the science fuel and pays DATA, a credits line paid by
people on the channel, and a walk-away. The reading pays and costs by the spot
the ship met the comet at (`CometPath.pay_here`, `toll_here`), and its outcome
text is one of three by that spot (`by_spot`), so the prose says what the code
did.

Each entry is its own function: one table of three would be over the gate's
100-line limit (`tools/code_check.py`). The text is a first draft through the
encounter-prose rules (grade 3 to 4, plain voice), flagged for Jon, not final.
```
