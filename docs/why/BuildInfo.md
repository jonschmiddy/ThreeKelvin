The reasoning behind `tkg/scripts/systems/BuildInfo.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Build info

Above `const PATH := "res://build.json"`:

```text
WHICH BUILD THIS IS, so a friend's report says what they played.

Nothing here is typed by hand. `tools/export.sh` writes `res://build.json`
({version, commit, date}) just before it exports and deletes it after, so the
file exists only inside an exported game: the version is
`application/config/version` in project.godot, the commit is the short hash
of what was exported. A run from source has no such file and says "dev".

Shown small on the title screen (`LauncherScreen`) and at the foot of the
pause menu (`PauseMenu`), printed at boot and at every new run into the log
(`godot.log`, the file a friend sends), and stored with each flight record.
```
