The reasoning behind `tkg/scripts/sim/ChassisFilm.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Chassis film

Above `var _args: PackedStringArray`:

```text
THE CHASSIS SELECT, FILMED (the coded engine flame going live, Oct 13):
  godot --path . --fixed-fps 30 --windowed --position 3840,0 -- sheet=ChassisFilm
      out=<dir> [frames=150]
Opens the chassis select the way the title does (`Router.show_chassis_select`),
lets its showroom hull burn (CRUISE) and the rest idle, and saves the window every
frame as f_####.png. Every hull's bob and flame run on `ShipView.shot_clock`,
stepped 1/30 s a frame, so the frames at 30 fps are true speed however
slowly the window drew. Waits for the flames' pictures (built off the main
thread) before the first frame.
```
