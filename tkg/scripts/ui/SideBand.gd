class_name SideBand
extends ColorRect

## THE TOOLBAR'S BAND BETWEEN LOCAL AND A SCREEN WITH ONE (Jon, Oct 13: "When
## going from the local to sector or starchart... the window drops abruptly,
## can we have a smooth transition between those?"; and the half-decoded
## letters of the map's toolbar hung over LOCAL's open space, "weird").
##
## LOCAL's scene starts at the top of the screens' area; the map's and the
## chart's picture start under their toolbar (`StarchartScreen.BAR_H`) and the
## gap below it, 21 px lower. At the swap that edge moved in one frame. This
## is the band that toolbar sits on, drawn over LOCAL:
##   OPENING (LOCAL -> map): it grows down from the top over `OPEN_S`, eased
##     out, while LOCAL's camera still moves, so by the swap it is exactly where
##     the map's own band is; then it stays until nothing of LOCAL's held picture
##     is left under it, and goes -- the map's own band is the same pixels.
##   CLOSING (map -> LOCAL): it stands whole from the swap, the map's toolbar
##     decoding away on it (`SideSwap.banded`), and once that is done it closes
##     back up the same way, LOCAL's scene coming up under it.
## The scene's top edge moves with it, a pixel or two a frame, never at once.
## It takes the clicks on it: under it is either nothing yet or a scene it
## hides. Out of LOCAL the ladder drives it with the move (`driven`); into
## LOCAL the band leaves as a picture instead (`ChromeSlide`).

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
