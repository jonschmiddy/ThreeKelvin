The reasoning behind `tkg/scripts/sim/BindTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Key bindings test

Above `const SCRATCH := "user://bindtest.cfg"`:

```text
Key bindings, driven with real key events through the real screens:
  godot --headless --path . -- bindtest

Four claims, and each fails silently in play. THE DEFAULTS ARE THE KEYS THE
GAME ALWAYS HAD: every screen used to read a keycode off the event, and a
binding with the wrong default moves a key without anyone deciding to.
A REBOUND KEY WORKS AND THE OLD ONE STOPS, set through Settings' own capture
with the pause menu open over it -- the path where a stray Escape or Tab
would close the menu or change the page instead. A BINDING SURVIVES A
RELOAD of the settings file without taking the display and audio sections
with it. A CLASH IS CAUGHT on the screens that share keys and not on the
screens that never meet.

THE PLAYER'S FILE IS NEVER TOUCHED. `Keys.path` points at a scratch file for
the whole run and the file is deleted at the end. F11 is checked as a binding
and never pressed: it would flip the real window and save the mode.
```
