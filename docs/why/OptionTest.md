The reasoning behind `tkg/scripts/sim/OptionTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Option test

Above `const ROLLS := 200`:

```text
Does the option roller obey its own rules?
  godot --headless --path . -- optiontest

A GATE, not a measurement. Everything checked here is a thing that would be
invisible in a run and wrong in a save or a co-op session.

The four that matter:

**Positional and stable.** What is AT a place is a property of the place, so
four machines must roll the same list. `Rng.derive(&"options", n.index)` is
the mechanism; this proves it by rolling the same node twice and by rolling
the same seed twice.

**Gating is honoured.** Every clause is ANDed and all seven axes already exist
on `MapNode`. An option that surfaces where its gate forbids is the fault
`EventTable` has today -- `pick_key()` reads none of the axes, which is most
of why fourteen events feel same-y.

**The tier plan is obeyed.** Counts stay flat and only grouping moves, per
`ENCOUNTER_REBUILD.md` §4. A tier-5 system offering two independent options
has lost the dial the whole design turns on.

**No duplicates.** Drawn without replacement, so a system never offers the
same situation twice.
```

## Dead content

Inside `run()`, above `var reach: Dictionary = {}`:

```text
AND AN OPTION NO GALAXY WILL ADMIT IS DEAD CONTENT.

The counterpart to the gate check above, and the failure that arrives with
star features: `needs_pulsar` is a real gate rather than the `min_danger 4`
proxy it replaced, and a real gate can be too tight. An option gated on a
sky nothing has is authored, reviewed, committed and never seen -- and
nothing else here would say so, because every other test is about what WAS
rolled rather than what COULD be.

ACROSS SEEDS, and that distinction is the whole of it. Pulsars are derived
from supernova remnants and `_seed_pulsars` says plainly that "a galaxy can
roll none" -- so an option needing one is CORRECTLY absent from a galaxy
with no corpses in it, the way a fauna option is absent from a galaxy of
cities. Homeless everywhere is a bug. Homeless somewhere is the map doing
its job, and asserting against it would force every gate down to the
weakest galaxy the generator can produce.

Admittance rather than appearance: weight and the draw are the roller's
business and a rare option legitimately misses a small sample. What must
never happen is a home that exists nowhere.
```

## Gate names

Above `func _gates_are_real() -> void:`:

```text
Every field an option gates on is one `admits` actually reads.

THE FAILURE THIS EXISTS FOR IS SILENT. `admits` tests the keys it knows and
ignores the rest, so an option carrying a gate nobody implemented is not
rejected loudly -- it is admitted EVERYWHERE. The content then reads as
deliberately placed while being placed nowhere in particular.

Batch 04 shipped `max_development` and there was no such gate. `long_claim` is
a seam nobody works "because hauling ore back costs more than the ore", and it
would have turned up in capital systems saying so. Nothing failed, nothing
warned, and the only symptom was prose that did not match where it appeared.

Cheap to check and it closes the class: a typo in a gate name is the same bug.
```
