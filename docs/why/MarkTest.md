The reasoning behind `tkg/scripts/sim/MarkTest.gd`.

## Test purpose

Above `var _tree: SceneTree`:

```text
STRIPPED-DOWN UI C1 (Jon, Nov 9): one outline means "this one". The game had
about seventeen highlight styles (tk-scratch/ui-audit, section 2.3), and the
fight's were the loudest: FLARE brackets on the enemy, GOOD brackets on your
hull, a warm tint on the hovered card, a wavy two-colour aim line with a
spinning lock. This harness holds the replacement to its rule through the
real screens, headless: the theme's hover boxes are the mint outline and the
text keeps its resting colour; the shape outline is MARK at MARK_PX; the
dashed line is whole pixels on the straight run with real gaps, moving with
the clock, short of the tip; in a fight nothing is outlined at rest, a card
pointed at is outlined and lifted in its own colours, an aimed card and its
target are outlined with the line up and your hull is not, aiming at empty
space outlines nothing, letting go there takes everything down; a wreck is
outlined only under the pointer and only once it can be opened. With the
outline taken out (08534bae) the fight's checks fail on `marked` and
`mark`, and the theme's on FLARE text.
```
