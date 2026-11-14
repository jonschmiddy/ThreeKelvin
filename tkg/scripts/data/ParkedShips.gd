class_name ParkedShips
extends RefCounted

## Where the ship was left, by system index. Saved with the run (SaveGame `parked`); per player, not on the wire.
## A record: {at: place, p: Vector2, v: Vector2, head: float, mode: StringName}, and on a wide star orbit also
## cen: int, r: float, sense: float. Router parks a docked ship as {at, mode = &"rail"}.
static var spots := {}
