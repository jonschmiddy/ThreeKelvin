class_name RoomsAhead
extends Node

## A child of `StationScreen`: once the dock has been quiet half a second, the Promenade and the
## Exchange load their art, one step a frame, so the first ride to them finds it there. A ride
## that comes first takes the old way (the room's first draw defers the same load).
## Why: docs/why/StationScreen.md#rooms-ahead

const QUIET := 30

var _quiet := 0
var _done := false


func _process(_delta: float) -> void:
	var st := get_parent() as StationScreen
	if _done or st == null:
		return
	# No ride, no ladder, no rail slide, the fade-in over, and this the screen on show.
	if st.deck_changing() or ZoomLadder.busy() or st._rail_slide != null or st.modulate.a < 1.0 \
			or Router.current != st or not st.is_visible_in_tree():
		_quiet = 0
		return
	_quiet += 1
	if _quiet < QUIET:
		return
	for room: ShopScene in [st._shop, st._exchange]:
		if room != null and is_instance_valid(room) and room.load_plate_ahead():
			return
	_done = true
