The reasoning behind `tkg/scripts/sim/WelcomeShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Welcome note shot

Above `var _args: PackedStringArray`:

```text
JON'S WELCOME NOTE, PHOTOGRAPHED on the real title screen:
  godot --path . --windowed --position 3840,0 -- sheet=WelcomeShot out=<dir> [wait=120]
The title is given `wait` frames to bring its galaxy up and saved alone
(`title.png`); then the note opens as on a first launch (START YOUR JOURNEY,
`welcome.png`) and from MESSAGE FROM JON (CLOSE, `welcome_menu.png`), each
saved once its fade has settled. Needs a window.
```
