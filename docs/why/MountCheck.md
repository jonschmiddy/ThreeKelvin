The reasoning behind `tkg/scripts/sim/MountCheck.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Mount check

Above `func run() -> void:`:

```text
Every hull's mounts against its own pixels:
  godot --headless --path . -- mounts

The dorsal, ventral and flank lines are measured off ONE specific image each
by `art/tools/anchors.py`. So the failure this exists for is a hull sprite
replaced without the tool being re-run: the new art has a different
silhouette, the old line still describes the old one, and the ship draws its
guns in clear space beside itself. Nothing throws, nothing logs, and the only
way to notice is to look at that exact hull at that exact class.

It has already caught it once, on the swap of Korvan's heavy B.
```
