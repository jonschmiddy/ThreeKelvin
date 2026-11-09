The reasoning behind `tkg/scripts/autoload/Keys.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Key bindings

Above `signal changed`:

```text
THE KEYS, BY NAME. Every key the game listens for that a player may move,
held as a Godot InputMap action with a label a player reads in Settings.

Jon: "We need a way to bind keys and such." Before this every screen read a
keycode straight off the event (`k.keycode == KEY_R`), so a key was wherever
the line that read it said it was. Now a screen asks for the ACTION
(`event.is_action_pressed(&"hold_turn")`) and this file is the one place that
says which key that is.

TWO SLOTS AN ACTION, a primary and an optional second key, which is what a
player who wants the arrows AND WASD on the ship needs and no more. The
defaults fill only the primary, so with nothing rebound the game reacts to
exactly the keys it reacted to before.

A CLASH IS ONLY A CLASH WHERE BOTH KEYS COULD BE PRESSED. W thrusts on the
sector map and pans the star chart; those two screens are never up together,
so the same key doing both is fine and is how it shipped. GENERAL is live
on every screen, so it clashes with everything; and the hold's keys clash
with the sector map's because the salvage drawer opens over that map
(`TOGETHER`).

WHAT IS NOT HERE, ON PURPOSE. Escape opens the menu and backs out of
everything, including this screen's own "press a key", so it cannot be
moved -- a player who bound it to something else could lock themselves out
of the menu. Backspace and Delete are how Settings clears a key. The "any
key" moments (the chart's first-visit card, skipping a jump) take any key by
design. Mouse clicks, drags and the wheel are not keys. See `FIXED`.

SAVED BESIDE THE OTHER SETTINGS, in `user://settings.cfg` under [keys], and
only the actions a player has moved: an action left alone keeps following
the default, so a default changed in a later build reaches them.
```

## Set key

Above `func set_key(action: StringName, slot: int, code: int) -> bool:`:

```text
Put `code` in `action`'s slot (0 primary, 1 second key). Refuses a fixed key.
Does NOT look for clashes: Settings asks `clashes` first and either calls
`swap_in` or does not call this at all.

The same key already in the action's other slot swaps the two, rather than
binding one key twice.
```
