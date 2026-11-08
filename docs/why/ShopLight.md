The reasoning behind `tkg/scripts/ui/ShopLight.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Shop light

Above `const MUL := preload("res://shaders/shop_light_mul.gdshader")`:

```text
The shop's light while it is running: how a failing lamp fails, and the two
layers that go over the room once the rack and the counter are in it.

PORTED, NOT REDESIGNED. Every function here is the room bench's own
(`tools/room_bench.tmpl.html`), line for line, because the bench is where
Jon judged these rooms and a light that fails differently in the game is a
different room. The names match the bench's so the two can be read side by
side.

The light itself was worked out by `tools/room_install.py` and is applied by
`shop_light_mul/add.gdshader`; what is left to do at run time is the part
that moves -- a failing lamp, the dust in its light, the glass of the lamps
-- and it is done here on the room's 30 Hz clock, the rate the bench draws
at and the rate the faults were shaped for.
```

## Shop marks

Above `class Glow extends Control:`:

```text
WHAT GOES OVER THE LIGHT: dust in the air, the lamps' glass, lit panels, and
the shop's own marks -- the prices, the rarity lights, the counter's quote --
which stay readable however dark the room is. That last is option 4A of the
port plan, taken when the rooms went in with the plan's four questions still
open: the room stays moody and the prices stay readable. The bench lights the
marks like everything else; `lit_marks = false` on the shop puts that back.
```
