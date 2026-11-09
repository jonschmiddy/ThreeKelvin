The reasoning behind `tkg/scripts/sim/TagTest.gd`.

## Test purpose

Above `var _tree: SceneTree`:

```text
STRIPPED-DOWN UI T1, T2 and C3 (Jon, Nov 9). Three rules, held through the
real screens headless: a tooltip is one torn tag right above the thing it
names, clear of it, inside the screen, one sentence and no title (the HUD's
hull gauge; a rich tooltip, the hull's perks, keeps its body on the torn
plate); each keyword on a card in the hand is its own hover target whose
sentence shows at once on the card's picture, the word lit, and no
whole-card readout opens any more; the chart's JUMP is a 56 px ember plate
with the star's name on it, the refusal word on a dark plate of the same
size, the panel down to danger, fuel and warnings, the survey on the star's
tag. The pure rules first (`TagLayer.plain`, `TornTag.place`, `sentence`,
`measure`), so a failure names the rule before the screen. Without the
layer (08534bae) the first section fails to compile.
```
