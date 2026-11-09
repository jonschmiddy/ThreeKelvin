The reasoning behind `tkg/scripts/Main.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Frame counter

Inside `_ready()`, above `add_child(FpsMeter.new())`:

```text
THE FRAME COUNTER, over everything and part of no layout. Added to the
window rather than to `root`, so it cannot take a pixel from the HUD row --
which is exactly what got the last one deleted. Built whatever the setting
says and hidden if it is off, so the toggle works without a relaunch.
```

## Hit kick

Inside `_ready()`, above `Sig.hit_landed.connect(func(amount: int, to_player: bool, _who: int, _ab: int) -> void:`:

```text
THE VIEW KICKS WHEN YOUR HULL IS HIT. Connected here rather than in Audio
because it is a picture, not a sound, and because it moves the whole
viewport -- see `_kick`.
ON THE LANDING, not the resolution: kicked when the maths ran, the view
had stopped shaking ten frames before the shot it belonged to arrived
(combat polish audit F2).
```

## Boot destination

Inside `_ready()`, above `var argv := OS.get_cmdline_user_args()`:

```text
Boot destination. The launcher is the default, and every development flag
below skips it — an automated run must never stop at a screen waiting to
be clicked, and a flag that drops you into a fight plainly means "not the
title screen" without having to say so.

  -- nolauncher   straight into a new run
  -- resume       straight into the suspend save, if there is one
  -- lobby        straight into the party screen, with no run rolled

`ship` belongs in this list and its absence is not cosmetic: the refit
screen reads Run.hull, which is null until a run starts, so booting to the
launcher and then swapping the ship screen over it crashes on arrival.
`salvage` is the same: it stows into a hold that a run has to exist for,
and the sector it opens draws the ship's own reactor.
```

## Shot flags

Inside `_ready()`, above `if "menu" in OS.get_cmdline_user_args():`:

```text
`-- shot` writes what is on screen and quits. For looking at a layout from
a place that cannot look at a window — a headless CI leg, an agent, a bug
report from somebody who cannot run the project. Deliberately generic: it
photographs whatever the flags above put up, so it never needs a case
adding for a new screen.
`-- menu` opens the escape menu over whatever the flags put up, so `-- ship
menu shot` photographs it in place;
```

## Shot timing

Above `func _shoot() -> void:`:

```text
Wait for the layout to settle, then save the frame.

Several frames, not one. Containers size their children on the frame AFTER
they are added, and every screen here is built in code during _ready — a
grab on frame zero photographs a page whose panels are all still at their
minimum size, which is precisely the property under test.
```

Inside `_shoot()`, above `var base := Vector2i(`:

```text
THE WINDOW IS RESIZED TO THE BASE VIEWPORT FIRST, and this is not tidiness.

The window is resizable and the controls lay out to it in real pixels, while
this grab returns the viewport's own render target at the project's base
size. Those two are routinely different — a 999-wide window photographed as
a 960-wide PNG — so the picture silently CROPS the interface, and a button
perfectly placed in the game appears sliced by the right edge of the file.

An afternoon went into chasing a margin bug that did not exist because of
it. A screenshot that does not show what the game shows is worse than no
screenshot: it is a confident wrong answer.
```

Inside `_shoot()`, above `print("[shot] %s  texture %dx%d  layout %dx%d" % [`:

```text
THE TEXTURE AND THE LAYOUT ARE NOT ALWAYS THE SAME WIDTH, and reading the
picture as if they were costs an afternoon. The window is resizable, the
controls lay out to it, and this grab is the viewport's own render target —
so a screenshot can be NARROWER than the interface in it, and a button
sliced by the right edge of the PNG can be perfectly placed in the game.
Both numbers are printed so the next reader can tell those two apart.
```

## Overlay layer

Above `var _overlay: CanvasLayer = null`:

```text
The escape menu and Settings live on their own layer, above the game's. The
menu's backdrop is a screen shader, and it can only blur what is drawn BEFORE
it -- on the base layer, `top_level` controls (the ship screen's perk labels)
draw after everything else, so they stayed sharp through the pause. On a
higher layer the whole game is finished before the menu reads it. Settings
shares the layer so it still opens on top of the menu.

A CanvasLayer is not a Control, so the theme set on this node does not reach
through it: whatever goes on the layer is handed `theme` by hand, or it draws
in Godot's default font.
```

## Input and cursor

Above `const CURSOR_FRAMES := 4`:

```text
The game shipped with no way to exit — no quit action, no input map entries.
Escape now opens the menu; F11 toggles fullscreen so a screen-sized window
can never trap the player behind missing title-bar chrome again.
TAB IS THE SHIP, and it has to be caught in `_input` rather than in
`_unhandled_key_input`.

Godot binds Tab to `ui_focus_next` and the GUI consumes it walking focus
between controls, so it never reaches the unhandled pass -- which is where I
put it first, and why it did nothing. Taking it here and marking it handled
costs the focus walk, which this game does not use: nothing is keyboard
navigable and every control is clicked.

`show_ship` refuses during a fight on its own, so there is no guard here.
THE POINTER, AND THE POINTER CLOSING.

Four corners and a dot -- see `art/tools/cursors.py` for why there is no
crosshair -- travelling from six pixels out to three when the thing under
them can be pressed.

FRAMES, BECAUSE A CUSTOM CURSOR IS ONE STATIC TEXTURE PER SHAPE. Godot has
no animated form of it, so the animation is four images and the swapping is
here. The alternative -- hiding the system cursor and painting our own
Control at the mouse position -- can tween anything, and is a cursor one
frame behind the mouse forever. A pointer that lags is a worse pointer than
one that does not ease, so the frames win.

IT COSTS FOUR OS CALLS PER HOVER, not four a second: `_process` only touches
the cursor when the rounded frame index actually changes, which is three
times on the way in and three on the way out.
```

## Cursor

Inside `_wear_cursor()`, above `var tex := load("res://art/cursors/reticle_%d_2x.png" % i) as Texture2D`:

```text
THROUGH THE IMPORTED TEXTURE, not the PNG on disk. An export has no
loose PNG -- only the imported texture in the pack -- so loading the
file by its globalized path failed there, silently, and friends got the
system arrow. The textures import lossless, so their image is exact.
```

Inside `_show_cursor()`, above `for shape in CURSOR_SHAPES:`:

```text
BOTH SHAPES, THE SAME IMAGE. Godot swaps ARROW for POINTING_HAND by itself
the instant the pointer crosses a control, which would jump the reticle to
its end state and leave the animation running behind it. Holding both to
the current frame means the swap is invisible and this is the only thing
deciding what the cursor looks like.

AND EVERY SHAPE A DRAG WEARS. Picking up a part hands the pointer to
Godot's drag, which shows FORBIDDEN over whatever will not take it and
CAN_DROP over whatever will -- the system's red X on the Promenade and
its plain arrow over the hold, because neither had the reticle (Jon:
"kinda bad"). Where a part can go is shown by the thing it would go
into; the pointer stays ours, held shut for as long as you carry it.
```

Above `func _cursor_wants_shut() -> bool:`:

```text
Is the thing under the pointer something you can press?

Asked of the hovered control rather than of the cursor, because the cursor is
what we are deciding. `mouse_default_cursor_shape` is the declaration every
button makes through `Widgets._btn`, so this reads the same fact Godot would
have read to do the swap we are taking over.
```

Inside `_input()`, above `var mb := event as InputEventMouseButton`:

```text
SNAP SHUT, EASE OPEN. A press jumps the reticle to closed rather than
travelling there: the animation is a response to hovering, and a click is
an impact. Easing INTO a click makes the pointer feel behind your hand;
easing out of one reads as the thing recovering.

NOT HANDLED, deliberately. This watches the click on the way past; the
control under it still gets it.
```

## Screen shake

Above `const SHAKE_S := 0.22`:

```text
SCREEN SHAKE, and it is the viewport that moves rather than any one node.

`canvas_transform` shifts everything drawn in the base canvas together -- the
ship, the enemy, the drawer, the HUD -- so nothing can drift out of step with
anything else. The escape menu is on its own CanvasLayer and is deliberately
not shaken: a menu that wobbles while you read it is a different feeling
entirely.

WHOLE PIXELS ONLY. Everything in this game is drawn on a 960x540 grid, and a
half-pixel offset resamples every sprite on screen -- the one thing the
integer window scaling exists to prevent.
```

## Tab round

Inside `_input()`, above `if Router.move_open():`:

```text
NOR OFF THE MOVE (`TransferScreen`). It has no off while anything is on the
pad -- that is why it hides the HUD -- and Tab was the door it forgot: over
the yard it swapped the station out and the move with it, and the pad it
was showing was never shown again (Jon, Oct 23).
```

Inside `_input()`, above `var at := ZoomLadder.lit_rank() if ZoomLadder.busy() else -1`:

```text
LOCAL, SECTOR, STARCHART, round. The screens a run is actually played on,
in the order you move between them: where you are side on, the sector
round you, where you are going (Jon: "include local in the tabbable pages
list"). DOCKED, THE BERTH TAKES LOCAL'S PLACE: Tab from the berth goes to
the map, and from the chart back into the station, never out to LOCAL,
because UNDOCK is the only way out (Jon, Oct 27). The HUD's first tab
agrees: STATION on the map or the chart, LOCAL greyed at the berth. SHIP
is gone from the round with its tab: your ship opens from LOCAL or the
Shipyard.

Each `show_` refuses on its own terms -- the map and the chart during a
fight (`Router.fight_up`: Tab there rebuilt the fight over itself), the
chart with nothing to jump to -- so a refused step simply leaves you where
you were rather than needing a guard here.
FROM WHERE A MOVE UNDER WAY IS GOING (`ZoomLadder.lit_rank`, the tab lit):
Tab twice quickly is two steps round, the second taken when the first
lands (`ZoomLadder.hurry`), not the first one asked for again
```

## Abandon and quit

Inside `toggle_menu()`, above `_menu.quit_requested.connect(func() -> void:`:

```text
Abandoning is an ENDING, so it goes into the record — the same one
Router.new_run() writes when you start over on top of a live run. Recorded
here rather than left for later because the run is over the moment this is
pressed, and a player who abandons and then closes the game would otherwise
have it vanish from the flight record entirely.
```

Inside `toggle_menu()`, above `_menu.save_and_quit_requested.connect(func() -> void:`:

```text
The autosave has already written a screen swap, but state moves after one
— a station's purchases and repairs all land on a screen that was saved
when it opened — so the explicit write is what makes SAVE & QUIT mean it.

Not mid-combat, though. Combat is outside the save by design and the format
stores none of it, so writing there banked the hull and heat the fight had
already spent against an enemy that comes back at full HP on a node still
marked unfought: strictly worse than force-quitting, from the button that
promises to be the safe way out. Mid-fight this now does what force-quitting
does — the last save, from before the shooting started, stands.
```

Inside `toggle_menu()`, above `Run.hull = null`:

```text
The run is on disk now, so the copy in memory is finished with. Letting
it stay live would be actively dangerous: the title screen rolls its
own Run.galaxy for the backdrop, and any later autosave would then
write this run's MAP against that galaxy — the systems are positioned
from the galaxy, so every one of them would move.
```

Inside `toggle_menu()`, above `Router.drop_combat()`:

```text
Out of the party's fight and off the signal bus, not just dropped
(review, Nov 5): the partners sat on "WAIT <name>", the fight still
listening ran their next turn with no hull, and CONTINUE was handed
back the fight it never left.
```
