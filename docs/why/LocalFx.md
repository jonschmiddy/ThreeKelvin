The reasoning behind `tkg/scripts/ui/LocalFx.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Event sky effects

Above `const LIGHT := preload("res://shaders/local_fx_light.gdshader")`:

```text
WHAT AN EVENT'S SKY DOES THAT NO PICTURE CAN (`LocalSubject`'s `fx` stages;
Jon's "Forty-three bare events" plan, every one said yes to): things with no
outline -- a pulsar's beam, a blue star's glare, a front, a bank of dust, a
stream of ice -- which no generation has drawn well, drawn here in code in
the scene's own light, behind the subject's pieces and in front of the sky.

AS LIGHT ("draw light as light", "pixel-art lighting is a light map"):
gathered, smooth inside, its edge dithered over a few pixels on a fixed
pattern (`local_fx_light.gdshader`), eased in and out and never flashing. A
moving edge crosses a pixel once (a beam's flat core lasts frames, so its
peak never goes A, B, A). Nothing is drawn on your ship or within a margin of
it, or under the event's band. With reduced motion nothing here moves: the
beam, the wind and the drifting specks are not drawn at all, the rest hold
still.

An `fx` stage is `{stage = &"fx", fx = <kind>, ...}`:
  beam    a pulsar's beam sweeping the sky every `period` s (`faint`: weaker).
          FROM THE PULSAR, AS IT TURNS: the nearest pulsar on the chart, on
          LOCAL's horizon at its bearing, its beam the lower lobe of
          `PulsarView`'s own spin (the map's tilt, the map's sense of turn:
          right, down, left, then away toward you) -- one turn a `period` --
          fading as it turns toward you instead of flashing
  glare   a blue star's glare spread over a quarter of the sky, washing it white
  wind    a star shedding itself: thin streaks racing outward from the star,
          each on its own ray, above the fight only
  dust    a bank of dust (`at` from the box's middle, `radii`, `tilt`, `warm`,
          `dens`) in 2x2 blocks, lit toward the star (`local_fx_dust`)
  front   a curved shell coming in from the right edge, grit glinting in it
  stream  a band of ice grit from `from` to `to` (from the box's middle),
          thick in the middle, a few fast pieces out in front
  drift   light things blowing out from the star past the pieces, as specks
  gas     the gas closed in: the sky's far stars faded, its cloud thickened
          (`LocalSky.set_closed`)
  buoy    LOCAL's own coded beacon, dead (its rings and lamp out), at `at`,
          a tether from its mast to the piece `tether` (a piece id)
  marks   `marks` big painted marks on the piece `on` that cannot be read
          (never letters)
  moor    a slack line from piece `from` (its point `from_at`) to `to` (`to_at`)
And on a piece: `tail` -- a comet's tails off it, away from the star.
```
