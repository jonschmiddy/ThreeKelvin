class_name SideBand
extends ColorRect

## Jon, Oct 13: the window dropped abruptly between LOCAL and the map or chart.
## The map's picture starts 21 px lower, so a band eases that edge and takes the clicks on it.
## Why: docs/why/SideBand.md#toolbar-band

const OPEN_S := 0.3

## Every band still standing, finished at once by the next move.
static var live: Array = []

var top := 0.0
var full := 21.0
var closing := false
## while this says true, the band stays whole (opening: LOCAL's held picture
## still under it; closing: the toolbar still decoding on it)
var wait: Callable
var _u := 0.0
var _k := 0.0
var done := false
## THE LADDER DRIVES IT (`ZoomLadder._drive_chrome`): out of LOCAL it opens
## with the camera leaving LOCAL, not on its own clock
var driven := false


func drive(k: float) -> void:
	_k = clampf(k, 0.0, 1.0)
	size.y = roundf(full * _k)


static func finish_all() -> void:
	for b: Variant in live.duplicate():
		if is_instance_valid(b):
			(b as SideBand).finish()
	live.clear()


## The band over `r` (viewport px: its top, the screens' width, its full
## height), opening from nothing or (`closing_`) standing whole.
func setup(r: Rect2, closing_: bool) -> void:
	color = UITheme.VOID
	mouse_filter = Control.MOUSE_FILTER_STOP
	top = r.position.y
	full = r.size.y
	closing = closing_
	_k = 1.0 if closing else 0.0
	live.append(self)
	_place.call_deferred(r)


func _place(r: Rect2) -> void:
	if done or not is_inside_tree():
		return
	var p := get_parent() as Control
	position = r.position - (p.global_position if p != null else Vector2.ZERO)
	size = Vector2(r.size.x, roundf(full * _k))


static func _ease_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


func _process(delta: float) -> void:
	if done:
		return
	var dt := ZoomLadder.fixed_dt if ZoomLadder.fixed_dt > 0.0 else minf(delta, 1.0 / 30.0)
	if driven:
		return
	var holding := wait.is_valid() and bool(wait.call())
	if not closing:
		_u = minf(1.0, _u + dt / OPEN_S)
		_k = _ease_out(_u)
		# (open, and nothing of LOCAL left under it: the map's own band is it)
		if _u >= 1.0 and wait.is_valid() and not holding:
			finish()
			return
	else:
		if not holding:
			_u = minf(1.0, _u + dt / OPEN_S)
			_k = 1.0 - _ease_out(_u)
			if _u >= 1.0:
				finish()
				return
	size.y = roundf(full * _k)


## The scene's top edge where the band is (viewport y).
func edge() -> float:
	return top + roundf(full * _k)


func finish() -> void:
	done = true
	visible = false
	live.erase(self)
	queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		live.erase(self)
