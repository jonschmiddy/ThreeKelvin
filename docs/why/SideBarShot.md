The reasoning behind `tkg/scripts/sim/SideBarShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Side bar film

Above `var _tree: SceneTree`:

```text
THE SIDE BAR'S SWAP, filmed (`SideSwap`):
  godot --path . --windowed --position 3840,0 --fixed-fps 60 --quit-after 20000
      -- sheet=SideBarShot out=<dir> [looks=A,B,C,D,E,F] [seed=N]
For each look, one film of LOCAL -> map -> chart -> map -> LOCAL, then the
dives LOCAL -> chart -> LOCAL (Tab, through black), through the
Router's own doors on the default seams (1A, 2C), every frame of the game's
960x540 picture as <dir>/<look>/f_####.png. The ladder's clock and the
swap's step 1/60 s a frame, and with `--fixed-fps 60` so does the game's,
so the frames play at true speed at 60 fps however slowly the window drew.
<dir>/<look>/meta.json: the frame each hop was asked on, and the side bar's
rect. Runs on main too (no look there: `looks=-`), for the before. Needs a
window.
```
