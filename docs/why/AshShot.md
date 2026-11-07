The reasoning behind `tkg/scripts/sim/AshShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Ash photography

Above `var _args: PackedStringArray`:

```text
A.S.H. PHOTOGRAPHED where she is seen (`Ash`, `AshPortrait`). Needs a window.

  godot --path . --windowed --resolution 1920x1080 --position 3840,0 -- sheet=AshShot keepwindow out=<dir> mode=stills
      LOCAL with her launch line up, and a fight of three with her heat line
      up, each held once the line is all out: `<name>.png` the 1080p window as
      the player sees it, `<name>_1x.png` the game's own 960x540.
  ... mode=options [screens=a,b] [spots=a,b]
      Every spot she was considered for (`Ash.ALL_SPOTS`) on LOCAL and three
      fights, her line up at each whatever is under it (`Ash.force_spot`):
      `options/<screen>__<spot>.png` (1x), and `options.json`: each spot's
      box and what it covers, named (`AshTest`'s own list).
  godot --path . --fixed-fps 60 --windowed ... -- sheet=AshShot out=<dir> mode=closeup
      Her launch line said on LOCAL, every frame from her first to her last
      cropped round her at 1x into `closeup/f_####.png` (`crop.json` says
      where), on the game's clock, so 60 a second is true speed.
```
