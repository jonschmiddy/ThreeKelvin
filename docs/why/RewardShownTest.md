The reasoning behind `tkg/scripts/sim/RewardShownTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Reward shown

Above `var _tree: SceneTree`:

```text
A RESULT THAT GAVE YOU SOMETHING TO TAKE SHOWS REWARD, headless:
  godot --headless --path . -- sheet=RewardShownTest

Jon, Oct 22: "some quests don't show REWARD... they basically just say
continue and the drawer drops to the bottom and there is SECTOR LOOT ....
that's super NOT intuitive." REWARD was keyed on the outcome's `module` key
(`OptionTable.pays_item`), and a part is not the only thing an event puts on
the system's pile: `material`, `material_id` and an effect calling
`Run.add_material` itself land there too, with no REWARD to say so.

Every authored option, every choice, and every band of a checked choice
(`SkillCheck.forced`), on a fresh copy of one system, resolved through
LOCAL's event band (`LocalEventDrawer`) as a player takes it. What landed on
the system's pile is read off the RUN, not off the drawer or the outcome's
keys: a result that put anything there has REWARD, enabled; one that put
nothing there has none; nothing that paid out skips its result
(`fight_now`). The quest events are named in the sweep (`job_pickup`,
`job_target` and the placed quest steps), the pickup with a signed fetch
pointed at the system. And CONTINUE on a result with REWARD unopened still
leaves the things under SECTOR LOOT, as it always did.

Prints every outcome the old rule missed, so the list of what this fixed is
the harness's own output.
```
