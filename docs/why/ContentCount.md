The reasoning behind `tkg/scripts/sim/ContentCount.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Content count

Above `const TARGET := {`:

```text
How much of the catalogue actually exists:
  godot --headless --path . -- content

A MEASUREMENT, not a gate. It prints what each manufacturer has and what it is
supposed to have, and passes either way — the same shape as `-- glyphs` and
for the same reason: a number nobody can see does not get acted on, and a
test that fails for a year because content has not been written yet is a test
everybody learns to ignore.

Counts UNIQUE CARDS BY NAME, not grants. The module gallery says "98 cards"
and that is the honest count of what a deck can be handed, because two
modules can grant the same verb — a manufacturer with eight parts that all fit a
Brace is not a manufacturer with eight cards. This asks the other question: how many
DIFFERENT things can this manufacturer do.

MALFUNCTIONS ARE NOT ON MODULES, and this used to count them as though they
were — it reported 1, and that 1 was a dead `dross` module nothing could hand
out. They live in `DB.MALFUNCTIONS` now, which is where a thing that arrives
unasked belongs: it costs a deck slot and nothing else.
```

## Catalogue dump

Above `func _dump() -> void:`:

```text
Every module as JSON, for building a review page out of.
  godot --headless --path . -- content json

Exists because the alternative is retyping the catalogue by hand into
whatever is reviewing it, and a hand-copied catalogue is wrong the day after
it is copied. The picking page for one manufacturer is going to be made seven times;
this is the half that must not be done seven times by eye.
```

Inside `_dump()`, above `var axes: Array = []`:

```text
THE GAUGE IT MOVES, and by how much. Both halves, because a part can
grant on one axis and be priced on another, and a page that showed only
the grant would say a Voidwhale Ganglion is free.
A LIST, since a part may name two gauges. It was String() on the raw
value, which quietly stringified the array into "[\"hull\"]" the moment
parts stopped having exactly one — the export kept working and every page
reading it stopped grouping.
```

## Keyword glossary

Inside `_dump()`, above `var glossary := {}`:

```text
EVERY KEYWORD THE CATALOGUE PRINTS, with the explanation the game gives.

COLLECTED FROM THE CARDS rather than typed, because CardData.keywords() is
the only place a keyword is defined and a second list would go stale the
first time somebody added one. It is the same walk `-- holdtest` does to
check that no card is NAMED after a keyword.

The one blind spot: a keyword no card uses yet does not appear, because
nothing has asked for its explanation. That is also true of the gate.
```

## Export vetting

Above `func _vet(rows: Array, junk: Array) -> void:`:

```text
THE EXPORT IS A CONTRACT AND NOTHING WAS CHECKING IT.

`PASSIVE_AXIS` values became arrays and the line above was still doing
`String()` on one. GDScript will stringify anything, so a gauge name came
out as the four characters `["hull"]`, the JSON stayed valid, the file kept
being written, and every page reading it stopped grouping. Nothing errored
at either end. It was found by looking at a table that had gone blank.

THE VOCABULARY IS BUILT FROM THE GAME, not typed here. A hand-written list
of legal gauge names is a second place for the truth to live and it goes
stale the first time somebody adds a gauge; asking PER_PIP what the gauges
are cannot.

Fails the harness rather than warning, because an export nobody can trust is
worse than no export: it produces a page that looks right and is not, and
the whole argument for generating the manifest was that a hand-copied one
goes wrong silently.
```

Inside `_vet()`, above `for g in Run.PER_PIP:`:

```text
`Run`, the singleton, and not `RunState` — that script carries no
class_name, so the identifier does not exist and the whole harness fails to
COMPILE. Which does not look like a compile error from outside: `.new()`
returns nothing, `get_tree().quit()` never runs, and Godot sits there until
the gate’s watchdog kills it at 120 seconds. Database reaches the same
constants through a preload because it runs before the autoload exists; a
harness runs after, so the singleton is right here.
```
