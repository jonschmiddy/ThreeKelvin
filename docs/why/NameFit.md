The reasoning behind `tkg/scripts/sim/NameFit.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Name fit

Above `const PANEL_W := 228.0`:

```text
How tall the destination title can get:
  godot --headless --path . -- namefit

The right-hand panel's height is driven by its tallest content, and the chart
shares a row with it -- so a name that wraps to a second line moves the whole
screen. Reported as "clicking Theta Abyssal Secundus completely changes how
the panel and star chart are rendered size-wise".

The fix is to RESERVE the height, and that needs a number rather than a guess:
reserve one line too few and the jump comes back on a longer name, one too
many and the panel carries a permanent gap. So this measures every name a real
galaxy generates, at the real font and the real width.
```
