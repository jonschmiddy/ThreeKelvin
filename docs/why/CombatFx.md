The reasoning behind `tkg/scripts/ui/CombatFx.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Combat effects

Above `signal landed(who: int, to_player: bool, kind: int)`:

```text
Everything combat throws across the screen: tracers, beams, impact sparks and
the debris a dead hull leaves behind.

A layer of its own, over the encounter and under the readouts, because none
of this is state — it is the report of a state change that already happened.
Combat resolves instantly and always has; these effects are how long it
*reads* as taking. Nothing here can alter a number.

Drawn as loose pixels rather than sprites or particles: a 1px tracer with a
short trail sits correctly beside a pixel-art ship at integer scale, where a
smooth line or a soft particle would be the only anti-aliased thing on screen.

WHAT THE COMBAT POLISH PASS ADDED (Oct 13): volleys (a card's hits are one
volley, and `volley_landed` says when the last of them arrived, which is when
the numbers are allowed to move), misses that fly past rather than vanish, the
damage numbers that pop where a volley lands, and the impact's light -- a small
gathered glow, stepped and dithered, drawn additively (memory draw-light-as-
light) rather than the 1-pixel sparks alone, which read as no impact at all.
```
