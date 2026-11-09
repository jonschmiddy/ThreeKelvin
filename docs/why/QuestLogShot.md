The reasoning behind `tkg/scripts/sim/QuestLogShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Quest log shots

Above `var _tree: SceneTree`:

```text
THE QUESTS TABLE, photographed:
  godot --path . -- sheet=QuestLogShot out=<dir> [seed=N]
Over LOCAL, opened by the HUD's QUESTS tab: `quests_0.png` none held, the
plain line; `quests_1.png` one, its row open; `quests_4.png` four (a fetch
READY to hand in, a hunt, a heat quest part carried, a fetch), the hunt's
row open. Then `chart_show.png`: the chart after the hunt's SHOW ON
STARCHART, and `chart_route.png` after its PLOT ROUTE. With `events=1`,
only `event_quests.png`: an event quest beside a job, and COMPLETED
(`_events`). Each is the whole
window, scaled to 1920x1080 where the window could not be made that big (the
game is a 960x540 canvas drawn at 2x). Needs a window, and a fresh APPDATA:
a stale shader cache whitens the sky.
```
