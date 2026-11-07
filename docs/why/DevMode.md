The reasoning behind `tkg/scripts/ui/DevMode.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Developer mode

Above `const PATH := "user://settings.cfg"`:

```text
The developer switch, persisted to user://settings.cfg beside display and audio.

ONE FLAG, read by everything that exists for us rather than for a player. The
point is not that these tools are secret — it is that a build with a card
gallery tab, a star chart that shows the whole galaxy and a run you can start
in an S-tier hull is not the game, and judging pacing or difficulty against it
quietly measures the wrong thing. `enabled` off is the game; on is the
workshop.

What it gates today:
  - CARDS and MODULES tabs in the HUD       (every card and part, on a page)
  - the star chart's view buttons           (hide systems / reach / show all)
    and REGENERATE GALAXY                   (a new galaxy under the same ship)
  - the chassis select's C-B-A-S tier row   (launch in any hull grade)
  - every manufacturer unlocked             (Unlocks.unlocked)

Adding to that list is one `if DevMode.enabled` at the point of construction.
Prefer NOT BUILDING the control at all over building it hidden: a hidden node
still takes layout, still takes focus order, and still has to be reasoned
about by whoever changes that screen next.

IT EXISTS ONLY WHERE THE EDITOR DOES. `available` is `OS.has_feature("editor")`:
true when the game runs from the editor binary (`godot --path .`, and every
harness the gate runs), false in any exported build, debug template or
release. Where it is false the workshop is simply not there: `enabled` stays
false whatever settings.cfg says, toggle() and save() do nothing and write
nothing, and the title screen does not build the switch. A friend's install
cannot reach it, and there is no line left to remember to flip before one
goes out.

ON by default where it is available. That is the right default for exactly
one audience and it is the audience running the editor — a fresh checkout
should hand a developer the tools, not make them go and find the switch.

(Not airtight: an exported .pck run under a downloaded editor binary with
--main-pack has the "editor" feature. A custom feature tag on the export
preset would close that, once there is a preset.)

To play without developer mode from the editor:
  godot --path . -- asrelease
turns `available` off for that run. It is NOT the build a friend gets: it
still reads your own settings.cfg, suspend save and flight record, and loose
res:// files an export leaves out. For that, launch the export from a clean
profile. `-- devtest` checks both sides.
```

## Detecting dev mode

Above `static func _detect(args: PackedStringArray, editor: bool) -> bool:`:

```text
The editor binary, less `-- asrelease`. `editor` is passed in rather than
asked here, so `-- devtest` can put the question an export would put: from
the editor binary OS.has_feature("editor") is always true, and a rule that
forgot it would look right. An export has no "editor" feature, so no setting
turns this on there. (`-- devtest` flips it by hand for its editor half, on
scratch files, then puts it back and quits.)
```
