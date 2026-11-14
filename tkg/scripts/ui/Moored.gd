class_name Moored
extends RefCounted

## LOCAL MOORED ON THE STATION'S RIGHT (Jon's (c), Nov 13): after an undock, LOCAL at
## that station is drawn mirrored and your ship leaves nose first to the right.
## `at` is the station's node or -1, held for the visit it was set in; saved.
## Why: docs/why/SectorScreen.md#mirrored
static var at := -1
static var _visit := -2


## Whether LOCAL here is drawn moored on the station's right.
static func here() -> bool:
	return at >= 0 and at == Run.at and _visit == SectorScreen._visit(Run.node_at())


## Moored on the right of the station at `node` (an undock there, a save loaded), or -1.
static func moor(node: int) -> void:
	at = node
	_visit = SectorScreen._visit(Run.map[node]) if node >= 0 and node < Run.map.size() else -2


## A control's pointer, set only when it changes. The engine checks a changed cursor
## against the control's global rect, which LOCAL's mirror turns upside down ("Rect2
## size is negative"): `view` is unflipped for that one set, in the same frame.
static func cursor(view: Control, c: Control, shape: Control.CursorShape) -> void:
	if c.mouse_default_cursor_shape == shape:
		return
	var flip := view != null and view.scale.x < 0.0
	if flip:
		view.scale.x = -view.scale.x
	c.mouse_default_cursor_shape = shape
	if flip:
		view.scale.x = -view.scale.x
