The reasoning behind `tkg/scripts/systems/options/OptionsPart01.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Quest table row

Inside `OptionsPart01.entries()`, above `quest = {task = "Deliver the runner's parcel", tag = "DELIVER", from = &"the_runner",`:

```text
ITS ROW IN THE QUESTS TABLE (`QuestLog`): the task beside the
signed jobs' tasks, the chart tag's word, and the note, which is
the runner's own line from `the_runner`'s body, word for word
(`-- sheet=QuestLogTest` holds it there). `from` is the event that
places it, for a save written before the run kept that
(`Run.event_quests`).
```
