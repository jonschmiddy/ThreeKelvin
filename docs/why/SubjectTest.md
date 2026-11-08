The reasoning behind `tkg/scripts/sim/SubjectTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Subject checks

Above `const STAGES := [&"single", &"row", &"tether", &"field", &"herd", &"line", &"around", &"on_rock", &"strewn", &"ring", &"group", &"structure", &"ring_arc", &"none", &"fx"]`:

```text
EVERY ENCOUNTER'S SUBJECT IS REAL AND FITS, headless:
  godot --headless --path . -- subjecttest

An option's `subject` (`OptionTable`, drawn by `LocalSubject`) names pieces of
art and a staging. A misspelt piece draws nothing and says nothing; a staging
one tank too wide runs under the event's band or off the view. So, for every
option that has one:
 - every stage is a kind `LocalSubject` stages, with what that kind needs;
 - every piece is in `art/subjects/index.json`, and its picture loads (or its
   painter recipe names a world the painter has);
 - the whole staging fits the subject's box on LOCAL's own view (right of
   centre, above the band) and keeps off your ship.
Then once on the real LOCAL: an event with a subject opened there draws it,
inside its box, off the ship and above the band. And with the wrecks a fight
leaves there (one, two, three of them, measured where the view puts them):
the subject keeps clear of every one, there and then, and every other
subject would too (`LocalSubject.fit`).

NOTHING IS DRAWN ACROSS ANYTHING ELSE (`LocalSubject.clear_of`): no two pieces'
opaque pixels come within the drift they can travel apart, but a piece on its
own rock or round its own body, and a declared `dock`, which must touch along
an edge (its clamps drawn over the seam).

THE SHIPS (`role:<name>`, or a pool ship by name): every role names kept pool
ships; an encounter resolves to the same ships every time; the ships vary
between the encounters that share a role. LOCAL NEVER DRAWS THE FIGHT'S CODED
SHIP (Jon picked kept pool ships on LOCAL only): no subject names `foe`, and
an armed encounter's scene shows pool ships, then goes the moment its fight
opens, so the fight's own ship (`EnemyArt`) flies in alone. AND IT DOES NOT
COME BACK (Jon, Oct 22: "When you destroy a ship in combat, sometimes another
ship randomly pops up?"): the fight won, LOCAL draws its wreck and no whole
ship of the event beside it, then and on LOCAL again; every fight's scene
keeps all but what it marks `fights` (`LocalSubject.without_foes`).
```

## Big structure

Above `const STAGES := [&"single", &"row", &"tether", &"field", &"herd", &"line", &"around", &"on_rock", &"strewn", &"ring", &"group", &"structure", &"ring_arc", &"none", &"fx"]`:

```text

A BIG STRUCTURE (`structure`, Jon's "Pulling up to it"): pinned to the view's
right edge instead of placed in the box -- it runs off the top, the right and
the bottom, from about x 540, its nearest part at your ship's height and clear
of your ship; what goes with it inside the view, above the band and off your
ship. On the real LOCAL it is drawn there, behind the hulls; a fight's wreck
does not move it, it dims behind the wreck, and the wreck is still clicked
through it (its hold opens); and in the cutaway it zooms with the scene, under
the blur, and comes back to its place. Its moving parts glide (Jon: "can the
motion be more smooth?"): a cradle's arms go open, shut, open again with no
jump between frames, and every part turns about a pivot inside its picture.
```

## Seeds

Above `var _seed := 4242`:

```text
THE SEED EVERY RUN HERE STARTS FROM, forced (`Rng.forced`). Until Oct 12 each
run called `Rng.reseed(4242)` and then `start_new_run`, which draws its own
seed from the global generator and threw the reseed away, so every gate run
drove galaxies nobody could name again. `-- subjecttest seed N` drives N.
```

Above `const RELOAD_SEEDS: Array[int] = [816829285]`:

```text
AND THE SEEDS THE SAVE-AND-CONTINUE CHECK ALSO RUNS ON (`_orbit_reload`):
  816829285  failed it in a gate run (Oct 12) -- not for the seed: every
             harness shared one save file, and another process's write landed
             between this one's save and its CONTINUE (`TestRun.scratch`)
```

## Kept takes

Above `func _kept_round3(view_size: Vector2, box: Rect2, ship: Rect2, ship_mid: float) -> void:`:

```text
ROUND THREE'S KEEPS, wired:
 - every kept take of each encounter is drawn by it at some system, and each
   one, forced, stages as the rest do: a plate pinned to the right edge (off
   the top, right and bottom, clear of your ship, its near part at your
   height, what goes with it in view), an object inside the box and off your
   ship, nothing drawn across anything;
 - THE PER-SYSTEM PICK (`LocalSubject.pick_of`): the same system draws the same
   take every time it is asked, and across the run's systems every take turns up;
 - on the real LOCAL, at a system it could be rolled at: it draws its kept
   art (one of its takes; its pieces), the plate pinned and behind the hulls,
   nothing of it on your ship -- but the seized clamp's arm, whose jaws touch
   your bow and never cross it -- or under the band; and the same encounter at
   another system that picks another take draws that one, and back at the
   first system, the first take again.
```

## Dock faces

Above `func _dock_faces(view_size: Vector2, ship: Rect2, ship_mid: float) -> void:`:

```text
THE FOUR KEPT DOCK FACES in the four berth events (the auction, the seized
clamp, paid in full, the parted line):
 - every part an encounter names (`anchors`: cargo, collar, lug0/1/2) is on
   that take's own metal (within 3 px of an opaque pixel of its picture);
 - every take forced in every event puts its pieces there: the lot at the
   cargo berth, the lit berth's lamp at the collar, the lighter under the
   mast's lugs with its lines from them and the parted one from the head, the
   clamp's arm leaving from the collar -- and stages as a plate must;
 - on the real LOCAL, each take in each event: nothing of it on your ship or
   under the band; the clamp's arm leaves from that take's metal on its row
   and its jaws touch your bow without crossing it.
```

## Built events on LOCAL

Above `func _bare_events() -> void:`:

```text
EVERY BUILT EVENT ON THE REAL LOCAL, at a system it could be rolled at, the
ship parked where it sits: it shows what its plan says (its effects and its
pieces), LOCAL's stand-in goes, nothing of it is on your ship or under the
band -- its pieces, its effects' own light (every shader rect is told your
ship and the band; every streak and speck drawn is clear of them) -- and the
beam is eased light: its flat core outlasts a frame's turn at 30 a second (so
a pixel's peak never goes A, B, A: the flicker budget), it fades as it turns
toward you rather than flashing, and it is not drawn with reduced motion.
```

## Wreck foes

Above `const WRECK_FOES: Array[StringName] = [&"whale", &"hellbender", &"cutter"]`:

```text
THE FOES THE WRECKS ARE LEFT BY, named. They were picked off
`DB.enemies.keys()` sorted, and an Array of StringNames sorts by address, so
which foes they were moved with every StringName a change interned: on main
(010655ff) whale, hellbender and cutter, and with the stations change of
Nov 3 leviathan, the Custodian and cutter (a boss's wreck at a fuel cache).
These are main's, the three it measured. (In text order, hulk, cutter and
whale, the third wreck's top row touches a tank's drawn square by 2 px,
measured Nov 3 and not yet looked into: the fit put the staging in the clear
stretch above the wrecks, and the tank's square reaches 10 px past it.)
```

## Fight handover

Inside `_handover()`, above `if Router.combat != null:`:

```text
AND AFTER THE KILL IT DOES NOT COME BACK (Jon, Oct 22: "When you destroy a
ship in combat, sometimes another ship randomly pops up?"): the bar's event
is still the fight, RESOLVED, and LOCAL drew its subject -- the pool ship --
whole beside the wreck of the ship you shot. Won as play wins it (the
breakup, the hand lowered, `Router.after_combat` to LOCAL), then LOCAL again.
```

## Orbit switch

Above `func _orbit_switch() -> void:`:

```text
LOCAL SHOWS THE WORLD YOU ORBIT NOW (Jon: "when transitioning from one planet
to another I have to go to the local and then the system and then the local
again for the local to update"). LOCAL composes its sky from where the map
left the ship (`SystemMapScreen._parked`), and the map wrote that only on its
way out of the tree -- after the screen replacing it had already been built
from the old record. Through the real Router, as the HUD's tab goes: in orbit
of world A, LOCAL; the map; a flight to world B, flown on the map's own
clock; LOCAL once, and it must draw B. Then the map again, which must put the
ship back at B.
```

## World memory

Above `func _world_memory() -> void:`:

```text
THE WORLDS TURN BLENDED (`PixelTurn.world_mode`, Jon: "THESE LOOK GREAT!!!"):
every world the painter draws carries its surface's memory with no flag --
LOCAL's orbited world and its moons, the map's worlds, and a world in pieces
(`ShatteredView`) on the map and in orbit on LOCAL, where it must turn -- wired
to read itself last frame. And it must still TURN: a memory that held everything
would show a dead world with no shimmer at all. So one world is filmed
turning a third of a pixel a frame, with the memory and (as the game was
before) without: its pixels change on most frames and over the run, and
pixels going A, B, A stay under a few a second. The filming needs a
renderer: headless (the merge gate) checks the wiring and says the pixels
went unchecked; `godot --path . -- subjecttest` in a window checks both.
```

## Reload orbit

Above `func _orbit_reload(sd: int) -> void:`:

```text
A RELOAD PUTS YOU BACK IN ORBIT WHERE YOU WERE, LOCAL INCLUDED. Where the
ship was left lived only in memory (`SystemMapScreen._parked`), so SAVE &
EXIT then CONTINUE dropped it at the system's edge and LOCAL drew the warp-in
instead of the world (alpha gap). Twice, as a player leaves: SAVE & EXIT
from LOCAL in orbit of one world, and SAVE & EXIT from the map itself in
orbit of another (the map writes its record only as it is put away, so this
one is the save reaching in for it). Each time the run goes to the title,
the memory of where the ship was is wiped as a fresh launch would have it,
and CONTINUE must land on the map in orbit of that world, with LOCAL drawing it.
```
