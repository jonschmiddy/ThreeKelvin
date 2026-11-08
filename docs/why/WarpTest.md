The reasoning behind `tkg/scripts/sim/WarpTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Curved glass input

Above `const LOOKS: Array[int] = [DisplaySettings.Look.CRT_GENTLE,`:

```text
A click through the curved glass lands where the picture says it does:
  godot --path . -- warptest

NEEDS A WINDOW, because it is about the window. The shader bends the picture
per screen pixel and the container that feeds input to the game knows nothing
about that, so `GameShell` bends the pointer the same way before anything
sees it. Jon found the fault by hand -- "the buttons in the far corners are
hard to hit" on CRT+ and the arcade cabinet -- and then found the fix was not
finished: "the button localization is better.... but it's not pixel perfect."

So this measures the WHOLE chain rather than my arithmetic: it takes a point
in the game, works out which window pixel that point is drawn at, pushes a
real mouse motion there, and asks the game where it thinks the mouse is. The
error is the answer, in game pixels, and the picture is only honest if it is
under one.

WHY THE INVERSE IS ITERATED. The bend has a closed form one way only: given a
screen point, which game pixel is drawn there. Going back the other way is a
cubic, so this walks Newton's method over it -- five passes is plenty at
these curvatures, and the harness asserts the walk converged rather than
trusting it.
```

## Error bound

Above `const WANT := 1.0`:

```text
HOW CLOSE IS CLOSE ENOUGH, and the number follows the mechanism rather than
the other way round. The rect is nudged by WHOLE GAME PIXELS -- a fractional
nudge changes which texel each screen pixel samples and makes the picture
crawl as the mouse moves -- so the pointer can sit up to half a pixel from
where the bend wants it in each axis. That is 0.71 on the diagonal, plus a
little for the bend's own curvature inside one pixel. One pixel is the
honest bound; asking for less would be asking the quantisation not to exist.
```

## Hover limits

Inside `run()`, above `DisplaySettings.screen_look = DisplaySettings.Look.CRT_GENTLE`:

```text
WHAT THIS CANNOT SEE, and two attempts are the evidence rather than an
excuse. Which control is HOVERED does not follow input events: pushed ones
leave `gui_get_hovered_control()` null even after the engine's own
`notify_mouse_entered`, and while the SubViewportContainer is delivering,
hover comes from the real pointer, which a harness cannot move -- warping
it is ignored without window focus and moving it for real would be moving
Jon's mouse. So the corner feel is judged by hand, with `-- mt=0` to
compare against how it was.
```

## Landing probe

Above `func _land(shell: GameShell, win: Vector2) -> Vector2:`:

```text
Push a real motion at that window pixel and ask THE GAME where it landed.

Not `Viewport.get_mouse_position()`: that reports the operating system's
pointer mapped into the viewport and is not moved by a pushed event at all --
it answered with the same number for every probe, which is how this test
first "measured" an error of eleven hundred pixels. A control inside the game
receiving the event is the only witness that proves the whole chain.
```
