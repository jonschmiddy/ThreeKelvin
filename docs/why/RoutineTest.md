The reasoning behind `tkg/scripts/sim/RoutineTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## What each routine does

Above `var _tree: SceneTree`:

```text
WHAT EACH ROUTINE DOES, WHERE IT HAPPENS (science, Phase 12, plan S3):
  godot --headless --path . -- sheet=RoutineTest

The Lab writes routines into the flight computer (`DB.routines`), and each
one is read where the thing it changes happens: the six numbers in RunState's
stat functions, the four fight ones in Combat, BLACK BOX in
`take_hull_damage`. Every check starts from a USED run (hull down, some heat,
the kit fitted), because a full, cold, empty ship hides half of what a
routine can get wrong.

Routines are owned either the way a player owns them (a board step bought
with DATA, `Run.buy_step`) or through the test seam `Run.routines_granted`,
which is how all twelve can be owned at once when a board holds nine.

 - the six stat routines, each read before and after: DAMAGE CONTROL carries
   the damage (full stays full, 7 down stays 7 down), dodge stops at 0.6,
   FUEL TRIM is 0.81 with Deep Tanks and never under 0.3, trims a long hop
   and the way-out floor and not a science reading's burn, SPARE CELLS powers
   a part 3 cells over the old cap with the energy unchanged;
 - each pip routine moves its gauge by exactly 1, and VENT TIMING moves heat
   capacity by 0 (here and not in AttrTest, whose file is another lane's);
 - WARM START and FIRST LOOK on the first turn only, a late joiner too;
 - COLD OPEN 10 to 6, 2 to 0, and no line at 0;
 - PATCH CREW +3 capped, +6 with Calyx's three, on a pacify, never on a flee;
 - BLACK BOX on PlayerDeathTest's seed 6061 against a cutter: the ship lives
   at 1, the box is spent, the next killing hit kills, and so does an event's
   toll; overheat and junk count as the fight's; and on the fight screen the
   turn's replay never draws the held ship at 0;
 - a hull swap with all twelve: full stays full, a damaged ship keeps its
   share of the ship it flew (a fitted plate included), BACK OUT restores the hull,
   the yard's reading of a new frame includes the +7, a new run clears all;
 - the two orders S2 could not test: a new run's hull is filled after the
   last run's science is gone, and a load reads the science before the hull;
 - `-- sim routines=`'s parse and grant.
```

## A used run with damage control

Above `func _new_run_order() -> void:`:

```text
A USED RUN WITH DAMAGE CONTROL, THEN A NEW RUN (S2's order, untestable
there): `start_new_run` clears the last run's science BEFORE `fit_chassis`
fills the hull. Swapped, the hull fills to the last run's +7, and the clear
after it leaves 47 on a 40 frame until the `dross` setter's `ship_changed`
clamps it; the fuel setter's `resources_changed` comes first, and anything
drawing the hull then (the HUD) reads 47/40. So every `resources_changed` of
the new run is watched, not only where it ends.
```
