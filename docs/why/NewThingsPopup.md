The reasoning behind `tkg/scripts/ui/NewThingsPopup.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## New things popup

Above `const TITLE := "NEW THINGS"`:

```text
NEW THINGS (Jon, Nov 5): what changed in each build (`NewThings`), newest
first, over the title screen in the note's own case (`NoteCard`) so it reads
as the same kind of page as MESSAGE FROM JON beside it in the menu.

Each version is a heading (the version, and the day it went out on the
right) over its lines, each line behind a small pip. The list scrolls inside
the case when it is taller than the window (`NoteCard._fit`): by the wheel,
the bar, or Up, Down, Page Up, Page Down, Home and End. CLOSE or Escape shuts
it. Opening it marks the newest notes seen (`NewThings.mark_seen`), which
takes the mark off the menu's NEW THINGS.

Built once, when it opens. Nothing here is rebuilt while it is up.
```
