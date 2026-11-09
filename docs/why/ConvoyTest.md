The reasoning behind `tkg/scripts/sim/ConvoyTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Party sheets

Above `const SHEET_DIR := "user://shipsheet"`:

```text
Two contact sheets for the party display.

  godot --headless --path . -- shipsheet     one ship per build, no renderer
  godot --path . -- convoy                   the real sector, with a party
  godot --path . -- convoy chart             the star chart, with a party
  godot --path . -- convoy hold              the same, left open to play with
  godot --path . -- convoy hold 7            and with a party that overflows

They answer two different questions and only the first one can be automated.

**Does a build draw as that build?** `shipsheet` writes one PNG per ship
straight out of `ShipView`'s own canvas. No viewport, no window, no frame
timing — the view composites into an `Image` and that image is the file. So
it runs headless, in CI, and it is the check that a gun bolted to the third
hardpoint is drawn on the third hardpoint.

**Does the convoy fit on screen?** `convoy` fakes a full party and screenshots
the real sector. That one needs a window, cannot assert anything, and exists
because four ships in an arena sized for one is a layout question and layout
questions are answered by looking.

The fake party is a fake ROSTER, not a fake network. `NetSession.build_of()`
reads `roster[id].build`, so filling that in puts four ships on screen with
no peer, no port and nobody to connect to — which is what makes this runnable
by one person on one machine.
```

## Convoy hold

Inside `run()`, above `if "hold" in OS.get_cmdline_user_args():`:

```text
`-- convoy hold` leaves it on screen instead of quitting.

The shot answers "does the convoy fit"; holding answers the questions a
still cannot — what it looks like while the ships bob, what happens when
you open the ship screen and come back, whether a size reads differently
when you can move between the tabs. Same fabricated roster, so it is still
one person on one machine with no port open.
```

## Convoy solo

Inside `_convoy_shot()`, above `var partners := 3`:

```text
`-- convoy solo` is the control shot. The convoy cell is hidden when
nobody is flying with you, and "hidden" has to mean the sector is pixel
for pixel the screen it always was — an HBoxContainer still spends its
separation on an empty child, and a solo game that gained a left margin
would be a regression nothing in the party display would ever reveal.
`-- convoy 7` overrides the party size. The default is three partners,
which is the party the strip was measured for; any larger number is the
experiment.
```

## Convoy timing

Inside `_convoy_shot()`, above `for i in 460:`:

```text
Long enough for the fly-in to land. The ship enters from off screen and
coasts for ARRIVE_MS, so a shot taken on the next frame is a shot of an
empty arena — which looks exactly like a convoy strip that failed to build.
Long enough for the LAST ship to land. The approach runs four and a half
seconds and the convoy is staggered behind it, so a shot timed for one
ship catches the others still coasting in.
```

## Flare shot

Above `func _flare_shot(tree: SceneTree) -> void:`:

```text
A jump, frozen. Six frames of the flash side by side.

  godot --path . -- convoy flare

Its own mode because the effect is 24 frames long and a screenshot of a
screenshot's worth of it says nothing: what has to be checked is the SHAPE
over time — that the column opens, flares, and closes, and that the hull
changes hands behind the widest frame rather than beside it.

Driven by hand rather than by the clock. `_process` on the flare advances
with delta, so a capture loop racing it lands on six arbitrary moments; this
sets `_t` directly and photographs a known one.
```

## Chart shot

Above `func _chart_shot(tree: SceneTree) -> void:`:

```text
The chart with the party on it: three partners at three depths, and a handful
of systems the party has already used up.

The one thing `-- nettest` cannot check. It proves a claim reaches every
machine and a position lands in the right slot; whether a partner four shells
coreward is actually VISIBLE is a drawing question, and the chart hides any
system you have not been to and cannot reach.
```
