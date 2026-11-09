The reasoning behind `tkg/scripts/ui/GameShell.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Shell window

Above `const BASE := Vector2i(960, 540)`:

```text
THE WINDOW THE GAME IS SHOWN IN, and the reason it exists is the curve.

The game draws at 960x540 and always has. Until now Godot scaled that whole
frame to the window for us (`stretch/mode = viewport`), which meant any
screen shader ran INSIDE the 960x540 frame -- and a curve computed there can
only blur the art or stagger it, because there is no room between one game
pixel and the next to put the bend in. Jon, on the blurred version: "REALLY
blurry and unreadable"; on the staggered one: "the pixels are jagged and
really bad looking". Both were true.

So the game now renders into a SubViewport of exactly 960x540 -- unchanged,
every coordinate in the game still means what it meant -- and THIS node draws
that texture to the window through `screen_filter.gdshader`. The shader runs
once per SCREEN pixel, so the curve is computed at the size you are actually
looking at, and each screen pixel still picks one game pixel: crisp art, bent
glass.

What Godot used to do and this now does by hand:
  * INTEGER SCALE. The game is drawn at a whole multiple of 960x540 or not at
    all. A 1.5x picture of pixel art is two different pixel sizes in one
    image, which is the one thing the art cannot survive.
  * LETTERBOX. Whatever is left over is black, and the shader paints the
    corners the curve pushes off the glass to match.

Everything else in the game is inside the SubViewport and does not know this
node exists. The shot tools still photograph `get_viewport()` from in there,
so they still write a 960x540 png.
```

## Tube edge

Above `static var _edge_style: int = 6`:

```text
HOW THE TUBE ENDS. Jon's pick, from the four ways other games do it and then
from four roundings of the one he chose: OVERSCAN with the corner rounded by
26 px and the picture darkening slightly into it. Overscan is what a
television did -- the outer few per cent of the picture fell off the glass --
so there is no empty wedge to finish; the rounding is only there because a
right-angled corner on a bowed picture "is just not nice to look at".

The others are kept for `-- edge=N`: 0 hard edge, 1 overscan square,
2 shaped glass, 3 in a bezel, 4 a deeper bezel, 5 and 7 the same rounding at
14 and 40 px.
```

## Letterbox bands

Inside `_ready()`, above `for i in 4:`:

```text
THE BLACK AROUND THE PICTURE, four bands that `_fit` lays round the glass.
It was one black rect under the whole window, and at 3X the glass covers
every pixel of that: 4.7 million pixels drawn a frame for nobody. UNTIL
THE GLASS EXISTS the first band is the whole window, as that rect was:
the game boots inside the `add_child` below, and `DisplaySettings.
load_and_apply` force-draws a dark frame into the grown window from there.
```

Above `func _fit_bands(win: Vector2, px: Vector2) -> void:`:

```text
THE BLACK IS WHERE THE GLASS IS NOT: the rows above and below the picture,
then the columns either side of it, each hidden when it is empty. A window
that is a whole multiple of 960x540 has none at all; BORDERLESS on a 1080p
or Retina screen has a top and a bottom. The glass writes every pixel of its
own rect, the corners the curve leaves included, so nothing under it is
ever seen. The root's clear colour is the interface navy and stays so (the
game's own frame clears with it), which is why the bands are drawn at all.
```

## Input container

Inside `_ready()`, above `_frame.modulate = Color(1, 1, 1, 0)`:

```text
THE CONTAINER IS FOR INPUT ONLY NOW, AND IS NOT SEEN. `_nudge` slides it
under the pointer so hover and clicks land where the bent picture says;
when it also DREW the picture, sliding it dragged the glass's own edge in
with it -- a sliver of backdrop down one side and across the top whenever
the pointer went near a corner (Jon: "the crt edge pulls inward on the
sides and top"). The picture is drawn by `_glass`, which never moves.
MODULATE, NOT SELF_MODULATE: Godot skips drawing an item whose modulate is
transparent, and still drew this one, a whole window of nothing, when only
its self_modulate was. Not `visible = false` either: that takes it out of
the input path and freezes the game's frame. Modulate does neither, and
does not reach the game inside its SubViewport.
```

## Texture filter

Inside `_ready()`, above `view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST`:

```text
NEAREST, LIKE THE REST OF THE PROJECT. `textures/canvas_textures/
default_texture_filter` is applied to the ROOT viewport only; a Viewport
made in code starts on LINEAR whatever the project says. Every stretched
texture in the game was being blended -- which showed up as a sheen across
the buttons, because a StyleBoxTexture stretches a 4x4 image over the
whole plate and linear sampling smeared its bevel into the middle.
```

## Pointer through glass

Above `func _nudge() -> void:`:

```text
THE POINTER GOES THROUGH THE GLASS, AND SO DOES THE HOVER.

The shader bends the picture per screen pixel and the container that feeds
the game maps the window to the viewport with a straight divide, so a button
DRAWN in the corner sat a long way from where it could be CLICKED -- 45 game
pixels at the top-left tab on the arcade setting. Jon found it by hand and
his diagnosis was exactly right: the picture moved and the hit boxes did not.

TWO SEPARATE THINGS HAD TO BE BENT, and missing the second is why this took
three goes and two wrong "fixed" claims:

  THE EVENT decides where a click LANDS. Bending it in place is enough for
  that, and `-- warptest` measures the whole chain at 0.00 game px.

  THE VIEWPORT'S OWN MOUSE POSITION decides which control is HOVERED. Godot
  keeps that separately and takes it from the container's local mouse
  position -- the OS pointer through a straight transform -- so the click
  goes where the picture says and the highlight goes somewhere else: 6.7
  game px at the top-left tab on the default look, 45 on the arcade one.

  THIS IS NOT FIXED, and here is what does not work, so nobody spends the
  day again. Pushing bent events into the SubViewport does not move it --
  `gui_get_hovered_control()` returns null for every one. Taking the
  container out of the mouse path (`mouse_filter = IGNORE`) stops the wrong
  updates and stops the right ones too: the viewport then believes the
  pointer is outside it and skips GUI picking entirely.

  `view.warp_mouse(bent)` DOES fix it, and it cost Jon his cursor: a
  SubViewport has no window of its own, so the warp goes to the real one and
  drags the hardware pointer toward the bend, which feeds the next warp.
  "My cursor is floating to the center of the screen." It is out.
`relative` is left alone. It drives panning, the scale it would want differs
across the screen, and a pan that changed speed toward the corners would be a
worse bug than the one being fixed.
THE GLASS MOVES SO THE POINTER DOES NOT HAVE TO.

Everything before this bent the EVENT, which fixed the click and left the
highlight behind -- Godot works out what is hovered from the container's own
transform and never looks at an event. Three ways round that are dead:
pushing bent events (nothing is ever hovered), `mouse_target` (judged by
hand, no better), and `warp_mouse` (works, and drags the real cursor).

So bend the CONTAINER instead. Godot maps a window point to the game with
`(point - position) / stretch_shrink`; that is affine and the bend is not,
but it only has to be right AT ONE POINT -- the pointer. Put the container
where that arithmetic comes out at the bent pixel and the engine does the
rest: hover, clicks, drags, tooltips, everything, from the one transform it
already trusts.

THE PICTURE MUST NOT MOVE WITH IT, so the container is not what is seen:
`_glass` draws the same frame through the shader from a rect that stays at
`_home`. (It used to be the container itself, handed the nudge back in UV;
that kept the picture still but slid the glass's edge in at one side and the
top, up to 6% of the frame, whenever the pointer neared a corner.)
```

Inside `_nudge()`, above `if not Rect2(_home, _frame.size).has_point(p):`:

```text
THE POINTER HAS TO BE ON THE GLASS. Off it -- outside the window, or
anywhere at all before the player has moved the mouse -- there is nothing
to line up, and lining up with a point a thousand pixels away sends the
rect off the screen. The first version of this rendered pure black for
exactly that reason, on a shot tool where the cursor was somewhere else.
```

Inside `_nudge()`, above `delta = (delta / k).round() * k`:

```text
WHOLE GAME PIXELS, NOT FRACTIONS OF ONE. The compensation keeps the
picture in the same place -- measured, the best match between a frame with
the pointer at the middle and one with it in a corner is at zero shift --
but a fractional nudge changes which texel each screen pixel lands on, and
on pixel art that crawls as the mouse moves. Rounded to a texel, the
sampling is identical and only the rect moves. It costs half a game pixel
of aim, which is the precision the snap already worked to.
```

## Power off

Above `const OFF_S := 3.0`:

```text
SWITCH THE SET OFF, then go.

Jon asked for it and a tube is the one thing this shell already is, so the
whole effect is one uniform: the picture folds to a line, the line closes to
a dot, the dot burns out. Three quarters of a second, which is about what a
real set took and is short enough that nobody quitting in a hurry is made to
watch it.

IT RUNS EVEN WITH THE CURVE OFF, because it is not the curve -- a flat
screen still had a beam. It is skipped when motion is reduced and when there
is no shell at all, and in both of those it quits at once.

THE QUIT IS GUARANTEED. `await` on a tween that never finishes would leave
the window open for ever, so the timer runs the quit whether or not the
picture got there.
THREE SECONDS, AND THE TIME IS SPENT ON THE LINE. Jon: "make it last a
while." Stretching the fold would only look slow; what lasts is the bright
bar the picture folds into, which sits and drains for well over a second
before the line closes. That is the beat the sound was cut for -- the whine
runs the whole length of the hold.
```

Above `const BLACK_S := 1.0`:

```text
AND THEN A BLACK SECOND, before the window goes. Jon asked for it, and it is
the part that makes the rest read as a set rather than as an animation: a
picture ending is a thing you watch finish, and a window vanishing on the
same frame as the last of the light turns the whole sequence into a
transition. The dot is gone well before this; what is held is nothing at all.
```

Inside `_fade_out()`, above `tree.create_timer(CLOSE_S - 0.06).timeout.connect(func() -> void:`:

```text
THE HOLE, and it does half the work. The click in `power_off` lands where
the line becomes a dot; everything else in the game is cut a moment
BEFORE it, so it lands in silence rather than over a mix. It is what film
does and it is the one thing no sound file can carry, because the thing
being silenced is the rest of the game.
```

Inside `_fade_out()`, above `Audio.stop_music(0.04)`:

```text
40 ms, not SWAP's 2.5 s. The hole is only a hole if the mix is
actually gone when the click lands; a swap-length fade left the music
audible -- and still bending -- for two and a half seconds after it.
Not a hard stop either: a mix cut mid-sample is its own click, and
this one would land in the silence the ending needs.
```

## Pointer mapping

Above `func _game_at(win: Vector2) -> Vector2:`:

```text
Window pixel -> the game pixel actually drawn there: the bend, then the snap.

THE SNAP MATTERS. The bend is continuous; the picture is not. `sharp_uv` in
the shader gives each screen pixel one whole game texel, so the edge you can
SEE is on a game-pixel boundary while a continuous map puts the hit edge
anywhere inside that pixel -- half a pixel out, which is what "better, but
not pixel perfect" feels like. Landing on the middle of the texel the shader
shows makes the two the same edge by construction.
```

## Vignette

Inside `_apply()`, above `var vign := 0.0`:

```text
HOW DARK THE CORNERS GO. The tube's ladder, and Jon set its middle rung by
eye against four depths shot on the card gallery: 0.55 on the look he
plays in, where the corner sits at 64% of the middle and the edges at 57%.
The old 0.35 was there and measurable and he could not see it, which is
the whole lesson -- a vignette on a screen whose edges are already dark
has to be deeper than the arithmetic suggests. The other two keep their
distance from it rather than their old numbers.
```

## Brightness gain

Inside `_apply()`, above `const VIGNETTE_MEAN := 0.412`:

```text
GIVE BACK WHAT THE TUBE TOOK, and get the arithmetic right this time.

The first version of this line guessed at two of the three costs, and Jon
found it by eye: "CRT mode shouldn't darken the screen much." Measured on
the same screen, it was 14% down on the gentle setting, 21% on CRT and 33%
on the arcade one. Both guesses were the same mistake -- assuming a mark
costs what it costs at its own strength rather than what it costs ACROSS
THE WHOLE SCREEN:

  VIGNETTE. Its profile is `clamp(r * 0.72, 0, 1) ^ 1.6`, whose mean over
  the screen is 0.412, not the 0.2 this assumed. That one number is most of
  the darkening.
  MASK. It dims two subpixels in three, so it costs `mask * 2/3`, not
  `mask / 3`.
  SCANLINE. Half the rows at full strength: `scan * 0.5`. This one was
  right.

The floor is gone with them. It existed to stop the old formula asking for
a gain it could not deliver; the shader now rolls its highlights off with a
soft knee instead, so a gain of two is a brighter picture rather than a
clipped one.
```
