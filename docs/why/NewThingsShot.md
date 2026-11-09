The reasoning behind `tkg/scripts/sim/NewThingsShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## New things shots

Above `var _args: PackedStringArray`:

```text
THE TITLE'S NEW THINGS, PHOTOGRAPHED on the real title screen:
  tools/dev/render.sh --path tkg --resolution 1920x1080 -- sheet=NewThingsShot out=<dir> [wait=120]
On a profile that has read Jon's note but never opened NEW THINGS, the title
is given `wait` frames to bring its galaxy up and saved with the menu's mark
(`menu_mark.png`); then the page opens from the menu (`page_top.png`), is
scrolled to its end (`page_end.png`), and shuts, and the title is saved with
the mark gone (`menu_seen.png`). Needs a window.
```
