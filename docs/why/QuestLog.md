The reasoning behind `tkg/scripts/ui/QuestLog.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Quest log

Above `const MARK := {`:

```text
THE QUESTS YOU HOLD (Jon, Oct 22, design A of the quest log, after Kevin's
playtest: "I needed a quest menu or some type of quest [log]"). The HUD's
QUESTS tab opens them as a table (`QuestPanel`), and a row's SHOW ON STARCHART
and PLOT ROUTE open the chart on the quest's place, tagged with its number
(`StarchartScreen.MapChart.place_quest_tags`), with its route from YOU.

A QUEST IS A SIGNED CONTRACT, `Run.contracts` less the closed ones, in the
order you signed them; AND AN EVENT QUEST (Jon, Oct 22: an event that plants
a follow-up "is essentially a quest"), an option an event put on a system
ahead (`OptionTable.place`) and not taken yet, in the order placed. Nothing
here is saved: every line is read off the contract, the map and the run's
record of who placed what (`Run.event_quests`) when asked. Only this ship's
own -- `Run` is one ship, so a co-op partner's quests are on their machine
and never on yours.

FINISHED ONES STAY (Jon, Oct 22: "quests shouldn't vanish when they're
done"): `done_entries`, a contract delivered and an event quest taken,
newest first, with what each paid, for the table's COMPLETED rows.

The words are the chart's: QUEST, as its tags and the sector map's key say,
while the board and its notes keep their own (SIGN, DELIVER).
```

## Quest entries

Above `static func entries() -> Array:`:

```text
Every open quest, numbered from 1: the signed contracts in the order you
signed them, then the event quests in the order placed. As the table's rows
and the chart's tags read them:
  n, id (the contract's id, or EVENT_ID + the system's index), job (the
  ContractData; null for an event quest), event, done, kind, what, where,
  jumps (words), pay, pay2 (a second line under it, or ""), state,
  state_colour, place (the system its tag stands on: the target, or for a
  heat quest and a READY one the nearest yard that pays it; -1 if none), tag,
  tip, note (the poster's or the event's own words), who (the poster's short
  name, or the event's title), manufacturer (&"" for an event), yard
  (whether `place` is the nearest of any of its yards), place_name, layer
  ("LAYER 7", from 1), paid (what a finished one paid; "" for an open one).
```

## Event quests

Above `static func _events(done: bool) -> Array:`:

```text
The event quests on the map, open (`done` false) or finished: an option only
ever placed (`OptionTable.placed_ids`) on its system, and either not taken,
or taken with an outcome (`MapNode.results`, and not `R_GONE`). READ OFF THE
MAP, so a save from before `Run.event_quests` still has them; the record adds
who gave it and what it paid. In the order placed, then by system.
  {at, slot, id, done, rec (the record, or {})}
```
