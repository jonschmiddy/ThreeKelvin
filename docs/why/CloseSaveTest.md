The reasoning behind `tkg/scripts/sim/CloseSaveTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Close saves

Above `var h := Harness.new()`:

```text
CLOSING THE WINDOW SAVES, as SAVE & EXIT does (`Router.save_on_close`;
release check, Oct 18, Jon "r3:yes").
  godot --headless --path . -- sheet=CloseSaveTest

The autosave writes on a screen change and nowhere else, so a wreck looted
on LOCAL and then the window's X lost the loot: the export's own first-run
bot came back from a relaunch 19 credits and a part short. Through the real
notification (`NOTIFICATION_WM_CLOSE_REQUEST`, sent to the tree as the
window sends it) and a real load:
  - a used run, a wreck looted on LOCAL, the window closed: the save on disk
    has the loot, and a resume puts it in the hold;
  - closed mid-fight: the save from before the fight stands (no hull, heat or
    credits banked from inside it) and the fight is marked to start again;
  - closed on the title: nothing is written.
Its own scratch save (`SaveGame.path` under a harness), never the player's.
```
