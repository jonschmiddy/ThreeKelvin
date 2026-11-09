The reasoning behind `tkg/scripts/sim/FoeTagShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Creature shots

Above `var _args: PackedStringArray`:

```text
A CREATURE EVENT AND THE FIGHT IT OPENS, photographed:
  godot --path . --windowed --resolution 1920x1080 -- sheet=FoeTagShot
      ids=in_the_wake,the_harpoon_line out=<dir> [choice=N]
For each event: a run at a fauna system holding just that option, LOCAL with
the event's band up and its text whole (`<id>_1_event.png`); its first
unchecked fight choice taken through the band (`choice=N` picks another),
the result if it shows one (`<id>_2_result.png`); then the fight that
`Router.start_ambush` opens, once its creature has flown in and the hand is
up (`<id>_3_fight.png`). Prints what each fight brought. Needs a window.
```
