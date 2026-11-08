The reasoning behind `tkg/scripts/sim/ArriveIdleTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Arrival idle

Above `var _tree: SceneTree`:

```text
A NEW RUN'S FIRST ARRIVAL, THE ENGINES AND THE HOVER:
  godot --headless --fixed-fps 60 --path . -- sheet=ArriveIdleTest [manufacturer=solari] [weight=light]

Jon, Oct 13, of the first sector: "your ship sputters to a stop... the
engines turn OFF and then there is a hitch... the ship is highlighted and
then the engines turn to idle. I don't want the engines to turn off... I
just want them to sputter to an idle. No highlight."

A new run on LOCAL the way the hull pick launches it (`Router.show_local`,
animated), stepped a frame at a time from the screen's first frame to a
second after the ship has parked. On every frame:
  - the flame is never fully off (`ShipView._thrust_now` >= 0): the coughs
    sputter over the idle, and the idle is what it settles to;
  - the cutaway's amber outline never shows (park() used to switch it on).
And the arrival has to have happened: the clean burn at FULL, at least one
cough, the ship parked, the screen at rest, the idle after.
Then, at rest, the pointer that was resting where the ship came to rest
(the event the slot is handed, with the pointer not moved) must not light
it; and once the pointer has moved, the hover outline works as before.
THE DUST AT ITS IDLE THROUGH AN ARRIVAL (Jon, Oct 21, for 0.3.0, as the
dock has it since Oct 20: "The dust move too much"): on every frame from the
screen's first to a second after the ship parks, every `LocalDust` mote, by
its place as drawn (`_rest_at`), moves by its own drift and bob and nothing
more, 0 px beyond, and the sky's camera (`LocalSky.cam_follow`) holds one
place. Then the same through a jump's arrival at the next system, LOCAL
opened on it from its map. (It
followed the ship at `CAM_FOLLOW`: the dust jumped about 209 px on the
arrival's first frame and slid back over the approach.)
```

## Later arrival

Above `func _next_system() -> void:`:

```text
A LATER SYSTEM'S ARRIVAL ON LOCAL: a jump to the next system in reach
(`Router.commit_jump`) with something waiting there (`ambush_pending`), so
the fight meets you on arrival and your ship flies in on LOCAL before it
starts (`_hold_for_arrival`). (A quiet jump lands on the system's map, which
plays its own arrival and spends LOCAL's.) Stepped from the first frame to a
second after the ship parks, the dust measured as above.
```
