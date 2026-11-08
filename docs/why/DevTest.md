The reasoning behind `tkg/scripts/sim/DevTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Dev mode gate

Above `const SCRATCH := "user://devtest.cfg"`:

```text
Developer mode exists only where the editor does:
  godot --headless --path . -- devtest
  godot --headless --path . -- devtest asrelease

Jon: "Dev mode shouldn't even be accessible in the released version." It was
on for a fresh install, so a friend's first launch would have opened every
manufacturer, the card gallery and the whole galaxy. `DevMode.available` is
the editor binary now, and an exported game has no workshop at all.

BOTH SIDES, FROM THE SAME SETTINGS FILE. A scratch file that says
[dev] enabled=true, because Jon's own file says that and a check against an
empty one would pass on a build that still read it. In the editor that file
gives developer mode: the title screen builds its switch, the HUD its CARDS
and MODULES tabs, the chassis select its tier row, the star chart its four
dev buttons, and every manufacturer is open. As released, the same file gives
none of it: the switch is not built, toggle() changes nothing and writes
nothing, and a fresh profile flies Korvan alone. The editor half is the
proof that the release half can see what it is looking for.

THE PLAYER'S FILES ARE NEVER TOUCHED. `DevMode.path` and `RunHistory.path`
point at scratch files for the whole run, and both are deleted at the end.
Screens are built in a holder of the test's own and never through Router, so
no screen swap autosaves a run. With `asrelease` on the command line the boot
itself is checked too: Main came up without dev mode or its tabs, whatever
the settings file says.
```
