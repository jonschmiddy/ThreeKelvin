The reasoning behind `tkg/scripts/sim/ReactorSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Reactor gate

Above `const DECK_MARGIN := 1`:

```text
What every frame actually launches with:
  godot --headless --path . -- reactor

A SHEET AND A GATE. It prints the twelve weight-by-grade combinations so the
reactor ladder can be tuned by looking at real launches rather than at the
table it came from, and it fails on the two ways the ladder can be set wrong.

THE FAILURE IT EXISTS FOR is a cell budget so tight that a frame launches
without a deck. `_top_up_deck` fills spare mounts until the deck reaches
hand_size + 4, and it now has to respect the reactor — so a low cap does not
produce a small ship, it produces a ship whose every turn is identical
because it draws its entire deck. That is not a hypothesis: the medium's
second utility mount exists because an Atelier Yacht once opened with four
cards against a hand of five, and nothing about the fix stops a reactor
number from putting it straight back.

Deliberately measured through `start_new_run`, the real path, rather than by
arithmetic on the tables. The kit is filtered by mounts AND by capacity, and
the interaction between those two filters is the thing worth checking.
```

## Capacity grants

Above `func _hardware() -> void:`:

```text
THE PARTS THAT GRANT CAPACITY, measured on the gauge rather than counted in
the table that authored them.

Every coupling raises REACTOR by the same +2, and the cells it grants are
derived from that. So the thing worth checking is the PIP, not the cell
count: a change to CELLS_PER_PIP moves every grant at once and this is what
notices if the two halves stop agreeing.

It replaces a check on the NET, which measured a proxy. That rule — nothing
nets more than +2 — was a guess at what "not too much" meant, made before the
gauge was the unit, and it is superseded: the nets now run from +2 to +5 by
design, because a part that grants capacity also occupies it and a 1-cell
cable keeps more of its own grant than a 2x2 armature does.
```
