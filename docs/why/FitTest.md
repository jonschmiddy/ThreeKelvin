The reasoning behind `tkg/scripts/sim/FitTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Fit test purpose

Above `const WANT_PAD := 4.0`:

```text
Parts can actually be picked up and put down:
  godot --path . -- fittest

NEEDS A WINDOW. This drives Godot's own drag-and-drop state machine with real
input events, and that machine lives in Viewport — headless there is no gui
input to hand it, so the whole thing would pass by never running.

Written because every other test of the hold checks the DATA. `-- holdtest`
proves two parts never share a cell and `-- mounts` proves a hardpoint sits on
the hull, and both of them pass in full on a screen where nothing can be
picked up at all. The refit screen is the one place in the game whose entire
job is an interaction, and it was the one place with no test of one.

Four crossings, because the hold and the hull are two containers and a part
has to survive every trip between them: hold to hull, hull to hold, hull to
hull, and a refusal — a part dropped on a mount of the wrong kind must not
move, and must not vanish on the way.
```

## Seeds

Above `const SEEDS: Array[int] = [7711, 1360870258]`:

```text
THE RUNS IT DRIVES, by seed, every one of them every time. Until Oct 11 this
called `Rng.reseed(7711)` and then `start_new_run`, which draws its own seed
(`Rng.roll_master`, from the global generator) and threw the reseed away, so
every gate run tested a fresh ship and hold and a seed-dependent fault came
and went between runs. The seed is forced now (`Rng.forced`), and the seeds
that once failed are kept here:
  1360870258  the stripping check found the hold too full for the part it
              meant to take off (a 2x2 part, no 2x2 hole) -- the test's own
              assumption, not the game's: a full hold refuses the drop and
              the part stays on the ship. `_stripping` makes room now, and
              first checks that refusal. (32213827 and 128620107 did the
              same: 3 seeds in 151 swept, all this one check.)
`-- fittest seed N` drives that one seed alone.
```

## Self ending

Inside `run()`, above `_tree.quit()`:

```text
AND IT ENDS ITSELF. Every other harness is dispatched with a
`get_tree().quit()` on the line after it; this one runs ACROSS
frames, so Main returns immediately and there is nobody left to
end it. It has therefore always printed its verdict and then sat
there until something killed it -- which read as "still running
after 240s" the moment it went into the gate, on a run where
every one of its checks had passed.
```

## Stripping

Above `func _stripping(grid: HoldGrid, mounts: MountPoints) -> void:`:

```text
TAKING ONE PART OFF DOES NOT TAKE THE OTHERS WITH IT.

Reported from the game: pull a module off the hull and the rest of them
vanish. Nothing throws, the hold is right, the tally is right — the hull just
comes back bare, which makes it a drawing fault or a lookup one and the two
look identical from the outside.
```

## Full hold

Inside `_stripping()`, above `if target == Vector2.INF:`:

```text
A HOLD WITH NO ROOM FOR IT (seed 1360870258: a 2x2 part, no 2x2 hole left
by the parts the checks above rolled into it). The game's rule is that the
drop is refused and costs nothing, so check that here -- the part still on
the ship, on its mount, not in the hold, nothing gone -- and then make room
the way a player would have to (here: whatever is in the hold goes, last
stowed first) so the stripping below still runs.
```

## Redraw counting

Above `func _redrawn(mounts: MountPoints) -> void:`:

```text
PICKING SOMETHING UP DOES NOT BLANK THE SHIP.

Counted off what the draw loop DID, not off the data and not off the frame.
The data was never wrong — `spots()` reported every fitted part the whole
time the hull was coming back bare — and a rendered-pixel version of this
check was written first and thrown away: it read the last presented frame and
returned identical counts either side of a real visual change, so it passed
against the very bug it was written for. Twice.
Queue a redraw and wait until it has actually HAPPENED.

`queue_redraw` marks the canvas item dirty; the draw runs in the engine's
draw pass, which is not guaranteed to have completed by the end of the very
next `process_frame`. Reading `drawn`/`pinged`/`hinted` after a single frame
therefore samples the counters from the PREVIOUS draw about one run in five,
and the check fails on a hull that is behaving perfectly.

This surfaced as `fittest` reporting one failure and then passing four times
in a row on the same tree, which is the worst way for a gate to behave: a
flaky check teaches you to re-run it rather than to read it.
```

## Mount ping and hint

Inside `_lit_keeps_the_parts()`, above `var free := 0`:

```text
AND ONLY THE EMPTY MOUNTS PING. Drawn over an installed part the rings
swamped the thing they were pointing at — 27px of them over a gun 30px
tall — which is most of why a whole slot looked like it had emptied.
```

Inside `_lit_keeps_the_parts()`, above `mounts.light(null)`:

```text
AND HOVERING WITH EMPTY HANDS HINTS AT EVERY EMPTY MOUNT, of any slot.

A different question from the ping and so a different answer: the ping is
"the part in your hand fits HERE" and is filtered to that part's slot,
while the hover is "where are the gaps on this ship" and is not filtered
at all. Counted rather than looked at, for the reason the note above this
function gives at length -- a rendered-pixel version of this check passed
against the very bug it was written for, twice.
```

## Animated hints

Inside `_lit_keeps_the_parts()`, above `mounts.hover(_mount_local(mounts, m))`:

```text
AND THE HINTS ACTUALLY MOVE.

They shipped once as a still picture: `_process` advanced the animation
phase only while a part was in hand, so the hover rings were painted at
whatever phase the last drag had left and then held there, repainted only
when the idle bob stepped. A count of what was DRAWN cannot see that --
three rings were drawn every frame, correctly, at the same three radii
forever -- so the phase itself is what gets asserted on.
```

## Grab anywhere

Inside `_lit_keeps_the_parts()`, above `var r := mounts.part_rect(m, m.slot, _mount_local(mounts, m), mounts._mag())`:

```text
AND A PART IS GRABBED ANYWHERE ON ITSELF, not just at the dot it hangs
from. A three-cell rail used to be pickable only by its breech.
THE LIVE MAGNIFICATION, not a hardcoded 2. The refit screen draws at 1x
unless the zoom is on, so asking for the rect at 2x measured a part twice
the size of the one on screen and probed a corner well outside it. The
assertion then failed for a part that was perfectly grabbable, which is
the exact breakage ShipView warns about: harmless while every screen
magnified by 2, silent the moment one stopped.
```

## Nudged drop

Above `func _nudging(grid: HoldGrid) -> void:`:

```text
A REFUSED DROP LANDS NEXT DOOR, OR NOWHERE. Never across the hold.

The old fallback was `Run.find_hold_slot` — first fit from the top-left — so
a part nudged one cell left that clipped a neighbour reappeared in the far
corner. Packing is a game of small adjustments and that made every imprecise
one destructive.
```

## Hold ladder

Above `func _hold_ladder() -> void:`:

```text
THE HOLD LADDER IS 12, 20, 30.

Small, and it earns its place: the three sizes are one table entry each and
the medium's and the heavy's were transposed the first time they were written,
which nothing else would have caught — a hold of the wrong size still packs,
still saves and still totals correctly.

THERE IS NO LAYOUT ASSERTION HERE, and that is deliberate rather than an
omission. The heavy's six rows come within 16px of the manufacturer abilities
and it would be worth a guard, but four versions of one were written and every
one of them passed with the heavy hold blown up to 48 cells. A column pushes
rather than overlaps, so a clearance check between the grid and the block
below sees nothing wrong; and re-running `start_new_run` inside this harness
does not re-lay-out a screen that is already built, so measuring per weight
measures the same frame three times. A check that cannot fail is worse than no
check, because it is read as coverage. If this needs guarding, it wants a
screen rebuilt per hull, which is a bigger harness than this one.
```

## Lifting

Above `func _lifting(grid: HoldGrid, mounts: MountPoints) -> void:`:

```text
GRABBING A PART TAKES IT OFF THE SHIP, and letting go of it nowhere puts it
back.

The second half is the one worth writing: between the grab and the drop the
part is in neither `installed` nor `cargo`, so a drag abandoned over empty
space is a module deleted. Picking a thing up is not a decision to get rid
of it.
```

## Carried plate

Above `var _ghost_checked: bool = false`:

```text
WHAT YOU CARRY IS A PLATE INSIDE A WRAPPER, and it is see-through.

Checked once, on the first drag of the run. The wrapper is the thing Godot
pins to the pointer; the plate inside it is what eases toward the cursor, and
a plate handed straight to `set_drag_preview` would be gripped rigidly at
whatever corner it was picked up by. So "the carried plate has a parent that
is not the drag layer" is the whole mechanism, stated.

The EASING itself is not asserted here and cannot be: it is driven by the
real cursor, which pushed input events do not move. See `_carry`.
```

## Geometry

Above `func _geometry() -> void:`:

```text
A part is drawn at ONE size, in the hold and on the hull, and its ink stays
inside its own plate.

EVERY SLOT AND EVERY SHAPE, not whichever part the loot roll happened to hand
over. Only a weapon has a silhouette that is off-centre from the point it is
drawn at — it is drawn from its breech — so a version of this that checked one
random module passed with the offset set to a deliberately wrong number three
times out of four. The shapes are cheap and there are six of them.
```

Inside `_geometry()`, above `if not box.grow(-WANT_PAD + 1.0).encloses(ink):`:

```text
WANT_PAD, not ModuleIcon.PAD. Reading the constant under test is
how the first version of this passed with the padding set to
zero: the assertion relaxed by exactly as much as the code did.
A test states the requirement; it does not ask the code what the
requirement is.
```

## Nothing cut

Above `func _nothing_cut(screen: Node) -> void:`:

```text
NOTHING BOLTED TO THE HULL IS CUT OFF BY THE VIEW IT IS DRAWN IN.

The hardpoint layer is a CHILD of the ship view, so the view's clip applies
to it — and a gun mounted on the last hardpoint on the spine reaches past the
hull it is mounted on, which is the whole point of a barrel. It was losing
its muzzle to a rectangle that had nothing else to cut: the view is sized to
show the entire canvas here, so the clip could only ever remove a child.
```

Inside `_nothing_cut()`, above `var sc := screen as ShipScreen`:

```text
AND ZOOMED, which is the case this check was blind to for as long as it
has existed. At 1x the row is taller than the canvas so `magnify` leaves
clipping off and the assertion above passes for free. The zoom doubles the
canvas past the row, `magnify` turns clipping back on, and every gun that
reaches past its hull loses its muzzle — the exact thing this test names,
in the one state it never entered.
```

## No room to turn

Above `func _pack_solid() -> ModuleData:`:

```text
A hold with EXACTLY no room to turn in, built rather than hoped for.

A 1x3 down the first column and every other cell filled with fittings. Turned
it wants three cells in a ROW and the only three free are the ones it just
vacated, in a column — so the move has to be refused, and refused is the
branch worth testing: the part is out of the hold at that moment and has to
get back exactly where it was.

Built by hand because the first version of this filled the hold with whatever
the loot table rolled and then asserted a refusal. There was room, the turn
succeeded, and the test failed while the code was right.
```

## Carry crossing

Above `func _carry(from: Vector2, onto: Control, local: Vector2) -> bool:`:

```text
One crossing: pick up at `from` on the screen, put down at `local` on
`onto`. Returns whether a drag actually started.

THE PICK-UP IS REAL AND THE DROP IS NOT, and the split is deliberate rather
than lazy. Real events start a genuine drag — `gui_is_dragging()` goes true
and the payload comes back through `_get_drag_data` — but Godot then follows
the OS CURSOR for the rest of it, so pushed motion does not steer the hover.
Driving the rest would mean warping the physical mouse on whatever machine is
running the gate, which is a real side effect to inflict for a test.

So the engine's routing is out of scope here and everything of ours is in it:
that a plate hands over a payload, that a target accepts or refuses it, and
that the run's state afterwards is right.
```

Inside `_carry()`, above `for i in 12:`:

```text
LET THE DROP LAND. One frame is not enough and it is not a fixed number
of frames either: a drop is handled through signals and deferred calls,
so a caller that asserts on the frame the drag ended is reading the
state from BEFORE the part arrived. It only bites sometimes, which is
worse than always -- this test failed about one run in four, on an
assertion about a part that had moved perfectly well.

Every caller asserts something about `Run` right after this returns, so
the wait belongs here rather than repeated at each of them.
```

## Waiting on conditions

Above `func _became(cond: Callable, frames: int = 90) -> bool:`:

```text
Wait until `cond` holds, or give up. Returns whether it ever did.

THE CONDITION, NOT A COUNT OF FRAMES. A drop is handled through signals and
deferred calls, so how many frames it takes to land is not a number anybody
knows -- it is however long the engine feels like taking on the day. This
test asserted on a fixed count and failed about one run in four, always on
an assertion about a part that had moved perfectly well.

A flaky check in a gate is worse than no check at all: it teaches everybody
to re-run until it is green, which is the same as not having it.
```

## Room for part

Above `func _room_for(grid: HoldGrid, m: ModuleData) -> Vector2:`:

```text
The middle of a cell where `m` would actually FIT, or INF if it would not.

THE PART'S SIZE IS THE POINT, and leaving it out is what made this test
flaky. It used to return the first cell nothing was sitting in, which is a
fine answer for a one-cell part and a wrong one for a Widowmaker: four cells
wide in a five-wide hold, dropped on a cell with no four free columns after
it, is a drop the hold correctly REFUSES -- so the part went back on the
hull and the assertion "the part that was dragged off is off" failed.

It looked random because it depended on whether the four-cell gun happened
to come first in mount order, which is why chasing it as a timing problem
got nowhere: a bounded wait on the fact did not help, because the fact was
never going to become true.
```

## Pinned ship

Above `func _pinned(screen: Node) -> void:`:

```text
THE SHIP HOLDS STILL AT 1x, and still pans when zoomed.

`_on_clip_input` documented itself as panning "only while zoomed" and then
never checked, which is the whole bug: at 1x `_ship_x` centres the ship and
there is nothing off screen to reach for, but `_clamp_pan` still allows it as
far as +85 -- so a press on the hull and a few pixels of motion slid the ship
off centre and LEFT it there, through every later refresh, because nothing
zeroes `_pan` except turning the zoom off.

It was reported as the ship moving when a part was moved in the HOLD. The
hold was innocent: `_panning` was still set from an earlier press whose
release landed outside the hull window and so never arrived to clear it.

Events go STRAIGHT to the handler rather than through the input system, for
the reason `_turn_in_hold` takes its position as an argument: a synthetic
drag never moves the OS cursor, so a pushed event is swallowed on the way.
```
