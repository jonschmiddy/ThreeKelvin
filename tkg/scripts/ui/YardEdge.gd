class_name YardEdge
extends Node

## The elevator's column as the yard's hall runs on into it: kept out of the picture
## while it is away, its dark drawn behind its header and gaps, the clips let go.
## Why: docs/why/StationScreen.md#yard-edge

var screen: StationScreen

## Whether the ladder is panning this screen in or out right now.
func _panning() -> bool:
	return ZoomLadder.busy() and ZoomLadder.active._pan_view != null \
		and is_instance_valid(ZoomLadder.active._pan_view) and ZoomLadder.active._pan_view.visible
var _rest_x := NAN
var _on := false
var _clipped: Array = []

func _process(_d: float) -> void:
	var r := screen._rail if screen != null else null
	var sc: YardScene = screen._scene if screen != null else null
	if r == null or not is_instance_valid(r) or sc == null or not is_instance_valid(sc):
		return
	if not r.draw.is_connected(_dark):
		r.draw.connect(_dark)
	# (the elevator's own place: the ladder's note of it, or learned while it
	# stands in it)
	if not screen._lad.is_empty() and not is_nan(float(screen._lad.get("rail_x", NAN))):
		_rest_x = float(screen._lad.rail_x)
	elif (screen._lad_tw == null or not screen._lad_tw.is_valid()) and screen._rail_slide == null \
			and (screen._cutaway == null or not is_instance_valid(screen._cutaway)):
		_rest_x = r.position.x
	# (not while the cutaway has the yard zoomed: the hall is not where it was)
	var away := not is_nan(_rest_x) and r.position.x < _rest_x - 0.5 \
		and (screen._cutaway == null or not is_instance_valid(screen._cutaway))
	# The elevator fully away is not drawn, so the pan and flight never show it through.
	var gone := away and r.position.x <= _rest_x - r.size.x + 0.5
	# (and through the whole flight in, wherever its row puts it back for a
	# frame while the screen is laid out)
	if not screen._lad.is_empty() and not bool(screen._lad.get("out", false)):
		gone = true
	# (by its alpha, not `visible`: hidden, the row it stands in would close up)
	r.modulate.a = 0.0 if gone else screen._rail_a * screen._lab_rail_a
	r.z_index = 2 if screen._lab_lift else (1 if away and not gone and not _panning() else 0)
	if away == _on:
		return
	_on = away
	r.queue_redraw()
	# The yard's hall runs on into the elevator's
	# column, under the ships, with the elevator over it.
	sc.set_edge(away)
	# (every box between the yard and this screen that would clip it)
	if away:
		_clipped = []
		var c: Node = sc
		while c != null and c != screen:
			if c is Control and (c as Control).clip_contents:
				_clipped.append(c)
				(c as Control).clip_contents = false
			c = c.get_parent()
	else:
		for c in _clipped:
			if is_instance_valid(c):
				(c as Control).clip_contents = true
		_clipped = []


## Sliding away, the elevator keeps the screen's dark behind its header and gaps: the
## hall run on into its column showed through them, the title afloat on it.
func _dark() -> void:
	var r := screen._rail if screen != null else null
	if _on and r != null and is_instance_valid(r):
		r.draw_rect(Rect2(Vector2.ZERO, r.size), UITheme.VOID)
