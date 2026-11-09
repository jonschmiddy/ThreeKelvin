The reasoning behind `tkg/scripts/sim/DockFlyTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Berth rule

Above `var _fails := 0`:

```text
UNDOCK IS THE ONLY WAY OUT OF A STATION (Jon, Oct 27, on Jeremy's "LOCAL
lets you leave a station too easily"):
  godot --headless --fixed-fps 60 --path . -- sheet=DockFlyTest
Headless, the ladder on and its clock stepped 1/30 s (`LadderTest`'s rig).
Docked in the berth (`route=berth`): the HUD's first tab reads LOCAL, greyed,
and says "Docked. Press UNDOCK to leave."; pressed anyway it goes nowhere.
Tab goes round the berth, the map and the chart and never lands on LOCAL; the
map and the chart are views: FLY HERE and GO read DOCKED with the same words,
and FLY HERE, WASD, GO and the chart's JUMP are refused; the HUD's STATION,
the map's DOCK and PARTY's LEAVE (co-op) go straight back in, docked
throughout and never by LOCAL. UNDOCK still leaves.
Then every route that used to leave without UNDOCK -- the map to another
world, the star, a belt or open space, then the HUD's tab or Tab round the
chart; the chart's JUMP; a jump on and GO -- is tried from the berth and
refused, back in the berth and never on LOCAL, and made again after UNDOCK:
LOCAL arrived on with nothing of the station left (`Router.docked`, its
powered decks, no StationScreen in the tree, the ladder idle with nothing
built ahead and no chain), the sky composed for where the ship is. The rule:
`Router.cast_off` refuses every move from the berth.

`shots=<dir>` (windowed) writes a still of each LOCAL arrived on.
`route=<name>` runs one route (with `--write-movie` and `--fixed-fps 30`: a
film of it at true speed; `proper` films its UNDOCK-first half alone).
```

## Dock only at station

Above `func _only_at_station() -> void:`:

```text
DOCK ONLY AT THE STATION (Jon, Oct 18, "dock:A"), AND A JUMP IN ARRIVES AT
IT ("arrive:B"): in a used run (docked and undocked here once, off to a
neighbour by the chart and back), the ship arrives alongside the station:
the map's DOCK card live and LOCAL with the station's side and DOCK. Flown
to a world of the system, nothing offers DOCK -- LOCAL's bar, the station's
side on LOCAL, the map's DOCK card (greyed, with the way to it on it) and its
beacon, the fuel hint, `show_station` itself. Flown back to the station, DOCK
again, and pressed it docks; from the berth the map's FLY HERE to the world
is refused (UNDOCK is the only way out, Jon, Oct 27), and after UNDOCK the
flight there leaves LOCAL with no berth and no DOCK.
```
