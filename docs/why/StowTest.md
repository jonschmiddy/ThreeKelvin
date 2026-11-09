The reasoning behind `tkg/scripts/sim/StowTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Dismissal rule

Above `var _tree: SceneTree`:

```text
The salvage rail, driven through the real screen:
  godot --headless --path . -- stowtest

THIS IS THE TEST THAT SHOULD HAVE EXISTED FIRST. The dismissal rule has been
got wrong three times and every one of them was invisible to the assertions
that existed:

  1. the flag lived on `SectorScreen`, which `Router` REBUILDS ON EVERY JUMP,
     so stowing was forgotten the moment you left the system;
  2. moved to `Run`, it asked whether the state MATCHED the dismissal, so
     walking away from a loot bag re-opened the rail;
  3. it compared haul counts with `>`, which fails shut when `hauls` resets.

Unit assertions on `Run.salvage_hushed()` catch (2) and (3) and CANNOT catch
(1), because (1) is not about the rule — it is about which object holds it and
how long that object lives. Only building the screen, pressing its button,
jumping, and letting Router build a NEW screen can see that.

So this drives the real thing: the real rail, the real STOW button, the real
jump, the real rebuild.
```

## Rail trigger

Inside `run()`, above `Run.found_hull = DB.hull_frames[0]`:

```text
TWO PARTS LOOSE IN THE SYSTEM, which is how loot arrives now. They used
to be stowed straight into the hold and the rail opened because the hold
was not empty -- but the rail no longer reports what you are carrying,
only what is out there and unclaimed. The dismissal rule this test guards
is unchanged; what opens the rail is not.
A HULL ON OFFER, which is what this rail is now for. It has been three
things across this file's life -- your cargo, then loose salvage, now an
offer -- and each time the DISMISSAL RULE it guards was unchanged and what
opened the panel was not. That rule has been got wrong three times; the
trigger is incidental.
```

## Rail button

Inside `run()`, above `var stow := _button("DECIDE LATER")`:

```text
Press the real button rather than setting the flag by hand. The handler is
what a player touches and the handler is what was wrong the first time.
"DECIDE LATER", not "STOW". The verb was dropped because the button does
not move anything -- it hushes the rail -- and "STOW" was only ever true
while everything the rail listed was already in the hold. A bag is not:
loose salvage sits in the system, so pressing STOW on one put the panel
away and left the parts on the floor. The rule this test guards is
unchanged; only the word is.
```

## No emptying hold

Inside `run()`, above `Run.stow(LootGen.roll_module(3))`:

```text
AND NOTHING ON THIS RAIL MAY EMPTY THE HOLD.

This assertion used to read the other way round: it required a JETTISON
button and required it to leave `Run.cargo` empty. That button called
`Run.cargo.clear()` -- one press, everything you were carrying, gone --
and its own tooltip admitted "there is no reason to do this".

`MATERIALS_NOTE` 3.4 rules it out: nothing of yours is destroyed for you.
Jettison now means one thing, overboard into this system's bag and
recoverable until you jump, done one item at a time by right-clicking it.

So the test is inverted rather than deleted. A deleted assertion protects
nothing; this one keeps the trap from being rebuilt, and would have failed
on the day it was first written.
SOMETHING IN THE HOLD TO BE UNTOUCHED. Nothing is stowed by this test any
more -- the salvage stays loose in the system -- so without this the claim
"the hold is untouched" would be made about an empty hold, which is the
case that cannot fail.
```

## Test exit

Above `func _finish() -> void:`:

```text
Print the verdict and end the process. EVERY EXIT GOES THROUGH HERE.

The guarded assertions above used to `return` on failure, and nothing else
ends the tree — `Main._ready()` has already returned by then. So renaming the
STOW button would not have failed this test, it would have HUNG it: no
verdict line, no failing assertion, just the gate's 120-second watchdog
reporting "still running, killed". A test whose failure mode is a timeout
tells you less than no test at all.
```

## Test teardown

Inside `_finish()`, above `if Router.current != null:`:

```text
TORN DOWN BEFORE QUITTING, and the merge gate is why. This is the only
headless test that builds real screens, so it is the only one that can quit
holding a live Control tree — and Godot reports the leftovers as
"resources still in use at exit", which the gate reads as script errors and
fails the build on. `free()` rather than `queue_free()`: a deferred free
does not run before the tree quits.
```
