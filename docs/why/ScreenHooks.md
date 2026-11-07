The reasoning behind `tkg/scripts/ui/ScreenHooks.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Boss death hold

Above `var target: Control`:

```text
A BOSS DEATH'S HOLD ON THE SCREEN (Oct 13). The set pieces in ShipBreakup name
what the whole screen should do as `moment`s -- `shake` (strength in px,
length in s), `slowmo` (the fight's clock scale, length), `flash` (white's
peak over the whole screen, length), `duck` (how far the music drops,
length) and `stinger` (a music hit) -- and this plays them:
  shake    moves `target` (the fight view) in whole pixels: a jolt that
           decays as (1-x)^2, a new direction at most every three frames,
           swung back across and eased to (the boss-death round's fix for
           the shake that read as flicker);
  slowmo   Engine.time_scale for its length, in real time;
  flash    a white layer over the whole screen, eased out a frame at a time;
  duck / stinger  through Audio.
Everything on the game's clock (`GameClock`), as everything on screen is, so
a film made with the movie writer plays it at true speed and the slow motion
reaches the shake and the flash too. A slow motion's length is screen time:
it is kept in game seconds scaled down by its own rate. Reduced motion (`Router.animating()` false) and the
screen-shake setting are honoured: no shake, no flash, no slow motion then.
```
