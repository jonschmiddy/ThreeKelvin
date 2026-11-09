The reasoning behind `tkg/scripts/ui/CustodianBadge.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Custodian badge

Above `const IMG_W := 40`:

```text
THE CUSTODIAN'S BADGE beside the goal line: badge 9b, "The eye opens, loud"
(eye-1b), approved by Jon on Nov 4 ("Yeah, 9B like this"; the page is
https://claude.ai/artifact/6sMbQ25hJP3pimr93ro9rj). It says, without a
number for its hull, that the boss at the core grows stronger the more jumps
the lead ship has made (`EnemyTemplate.hull_at`: 200 through jump 15, +4% a
jump, capped at twice from jump 33). Alone that is your jumps; in co-op the
most any ship in the dive has made (`count`, Jon, Nov 4: "The custodian
strength and icon should be the same for everyone in the galaxy, even if
they join late.").

  S0    jumps 0 to 15   a closed eye, breathing, with the jumps left beside it
  WAKE  jump 16         it opens (once, on arriving)
  S1    16 to 19        orange, drowsy: glances, glints, a slow blink
  S2    20 to 24        red and bloodshot, darting about
  S3    25 to 32        glaring, the veins crawling
  FULL  33 on           wide and blood red, a steady heartbeat. It stops
                        getting worse, not moving.

THE SOURCE is the approved page's own code, ported pixel for pixel:
tools/dev/badge/fin_eye.js (eye-1b) and core.js, copied from
tk-scratch/custodian-badge/web. `-- sheet=BadgeTest` holds `paint` to that
code's frames (`tools/dev/badge/dump_golden.py`, `badge_golden.json`).
Drawn into a 40 x 15 Image on the CPU and shown as one texture at whole
pixels, 1:1 at the game's 960 x 540: the texture is updated only when the
frame changes, about 2 to 12 times a second.

THE NUMBER is drawn from a table of Silkscreen's digits at 8 px (`DIGITS`),
baked from the game's own font file the way the game draws it (FreeType,
antialiasing off: every Silkscreen glyph sits on a 125-unit grid, 1 px at
8 px). The page drew the same glyphs with Chrome's antialiasing; past half
opacity its pixels are these. In the Image, so the whole badge is one draw
and the tests can read every pixel headless.

THE STAGE EDGES THAT ARE GROWTH come from the core boss's data
(`DB.core_boss()`): it wakes the jump after its free ones (`grow_after`,
15), and it is at full strength from the first jump `hull_at` reaches the cap
(33). S2 and S3 are Jon's picks on the page, 4 and 9 jumps after the wake
(20 and 25). A core boss that never grows has no badge.

MOTION on the game's clock (`GameClock`, never the wall's: films run the
wall's ticks about 13 times too fast). Idle loops at the stage's own rate
(`IDLE`); a transition once, on the first screen that shows the goal line
after the count rises (`GoalLine` starts it, `RunState.custodian_seen`
remembers it), at 10 steps a second, ending on the stage's idle frame 0.
Reduced motion: the transition plays and then holds idle frame 0, as the
page did. THE ARRIVAL RUNS FROM THE COUNT LAST SHOWN (`from`) to the count
now: alone that is the jump before, so every frame is the page's, except
after an arrival that never showed (a second jump begun inside the line's
fade in), when it runs from the count last shown; in co-op a partner's jump
can raise it while you sit still, or by several. Either way the biggest
stage edge crossed plays (`change_kind`).

NOT A CONTROL: it ignores the mouse like the rest of the goal line, so the
chart's and the map's pictures under it still take every press, drag and
wheel. It reads the pointer itself for its tooltip (`_hover`), the game's
tooltip plate (`TooltipPanel`) with the page's lines, the heading the boss's
name from data, and no hull figure. Their hover keeps off it (`covers`), so
a system or a world under it does not open its own tooltip under the badge's.
```

## Badge transitions

Above `static func change_kind(j: int, from: int = -1) -> StringName:`:

```text
What arriving at count `j` from `from` (the jump before when -1) plays: the
biggest stage edge crossed, &"full" (33), then &"worse" (20, 25), then
&"wake" (16), then &"tick" (the number drops, jumps 1 to 15), else &"none".
One jump crosses one edge, so alone it is the page's table; the page ran
from jump 1 and ticked from 2, and the game starts at jump 0, so its first
jump ticks too. In co-op 14 to 17 wakes it and 30 to 40 is the full one.
```

## Badge drawing

Above `static func _eye(b: PackedByteArray, cx: int, cy: int, hw: int, hh: int, o: Dictionary) -> void:`:

```text
THE EYE (fin_eye.js eye()): a diamond `hw` by `hh` round (`cx`, `cy`), its
edge the rim, inside the iris and the pupil round (`ox`, 0), the white of the
eye shaded as the sprite's glass is, bloodshot and veined by `o`.
o = {rim, ir, iris, pr, pupil, ring?, blood?, ox?, vein? {seed, col, n}, glint? {at, col}}
```

Above `static func _closed(b: PackedByteArray, x: int, cy: int, o: Dictionary) -> void:`:

```text
THE SHUT EYE AND ITS NUMBER (fin_eye.js closed()): a shallow U as wide as the
eye that opens, the seam along the bottom, lashes under it, the jumps left
5 px after it. o = {seam?, twitch?, leak?, corners?, digit?, digit_col?}
```
