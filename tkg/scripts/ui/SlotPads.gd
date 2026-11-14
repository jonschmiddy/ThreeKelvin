class_name SlotPads
extends Control

## Lives here now: the refit screen became drag and drop, so only this screen wants a slot summary.
## Why: docs/why/ChassisSelect.md#slot-pads
const CELL := Vector2(9, 11)
const GAP := 2
var used := 0
var total := 0

## `reserve` is width for pads this row lacks, so the figures share a left edge.
## Why: docs/why/ChassisSelect.md#slot-pads
func setup(u: int, t: int, reserve: int = 0) -> void:
	used = u
	total = t
	custom_minimum_size = Vector2(maxi(total, reserve) * (CELL.x + GAP), CELL.y)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var y: float = floor((size.y - CELL.y) * 0.5)
	for i in total:
		var pos := Vector2(i * (CELL.x + GAP), y)
		if i < used:
			draw_rect(Rect2(pos, CELL), UITheme.COLD, true)
			draw_rect(Rect2(pos, Vector2(CELL.x, 1)), UITheme.CHILL, true)
			draw_rect(Rect2(pos, Vector2(1, CELL.y)), UITheme.CHILL, true)
		else:
			# Four filled rects, not outline mode: a 1px stroke drew empty pads larger.
			draw_rect(Rect2(pos, CELL), Color("#10161f"), true)
			var e := UITheme.EMBER
			draw_rect(Rect2(pos, Vector2(CELL.x, 1)), e, true)
			draw_rect(Rect2(pos + Vector2(0, CELL.y - 1), Vector2(CELL.x, 1)), e, true)
			draw_rect(Rect2(pos, Vector2(1, CELL.y)), e, true)
			draw_rect(Rect2(pos + Vector2(CELL.x - 1, 0), Vector2(1, CELL.y)), e, true)


## Derived, not typed: `DB.TIER_DELTA` and heavy mounts moved this month, so a literal goes stale.
## Cached: asked once per row per chassis and it cannot change in a session.
## Why: docs/why/ChassisSelect.md#mount-ceiling
static var _ceiling: int = 0

static func mount_ceiling() -> int:
	if _ceiling > 0:
		return _ceiling
	var m := 1
	for frame: HullData in DB.hull_frames:
		for d: Dictionary in DB.TIER_DELTA:
			m = maxi(m, frame.weapon_slots + int(d.weapon))
			m = maxi(m, frame.system_slots + int(d.system))
			m = maxi(m, frame.utility_slots)
	_ceiling = m
	return m
