The reasoning behind `tkg/scripts/ui/SettingsPanel.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Settings drawer

Above `signal back_requested`:

```text
Settings, as the contents of a drawer.

IN THE ESCAPE DRAWER, NOT ON TOP OF IT. Settings used to open as a second
overlay that re-rendered the whole screen over the menu it came from; Jon:
"can't we have the settings menu just be in the same size side drawer?" So
this is only the drawer's CONTENTS: PauseMenu swaps it in place of its own,
and SettingsMenu wraps it in a drawer of its own for the title screen, which
has no escape menu to borrow.

Built for the drawer's 250 px: every setting is a row that names itself and
states its current value on the right, with short chips under it, and volume
is a gauge you click along -- the layer strip's cells -- rather than six
numbered buttons.

Options show what they will do before you pick them, and the current one is
marked — a settings screen that makes you toggle blind to find out is worse
than no settings screen.
```

## Scrolling page

Inside `build()`, above `var scroll := ScrollContainer.new()`:

```text
ONE SCROLLING PAGE. It was tabs for an afternoon -- Jon's call both ways --
and scrolling wins because every setting is then one gesture away rather
than behind a tab you have to remember the name of. BACK stays pinned
below the scroll rather than riding it out of reach.
```

## Scrollbar gutter

Inside `build()`, above `var inset := MarginContainer.new()`:

```text
ROOM FOR THE BAR. A ScrollContainer draws its scrollbar over the right
edge of its content, so every value on the right -- 1920 x 1080, OFF, the
last chip in a row -- sat under it (Jon). The bar keeps a gutter of its own
now (`UITheme.BAR_GAP`, Oct 20), so this is the rest of the 10 px it had.
```

## Machine pick

Inside `_page_look()`, above `var by_machine := DisplaySettings.low_by_machine()`:

```text
PICKED FOR THIS COMPUTER (Jon, Oct 27, C1: `GpuProbe` measured this machine
on the title and set LOW): said here, where the row is, in plain words, for
as long as the pick is the machine's. Pressing HIGH makes it the player's
(and LOW after it: the marked chip cannot be pressed). Before the measure,
the LOW is only the chip's name (`DisplaySettings.low_by_hint`), and the
words say that, not that this computer was found slow: on Windows the
measure may still put HIGH back.
```

## Removed dev rows

Inside `_page_motion()`, above `func _page_sound() -> void:`:

```text
(THE ZOOM LADDER'S DEV ROWS -- ONE CAMERA, each seam's design, 3B into
the yard, the move timings and the station lights -- were here in dev mode.
Jon, Oct 19: remove them, even in dev mode. What he had set ships as
`ZoomLadder`'s constants; a harness still picks with `flow=` and the forces.)
```

## Chip rows

Above `func _row_chips(key: String, names: Array, picked: int, on_pick: Callable, tips: Array = [], slot: float = 46.0) -> Control:`:

```text
A name on the left and its choices on the right, for the settings whose
options are short enough to sit beside their label. `tips`, if given, is
each chip's tooltip, in the same order as `names`. `slot` is each chip's
share of the row: 46 px, but four at 46 next to FRAME CAP made the row 243
px wide and pushed the escape drawer 9 px past its 290 (`-- menutest` boxes
it), so that row's four take 40 each.
```
