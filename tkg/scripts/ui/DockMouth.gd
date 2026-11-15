class_name DockMouth
extends Control

## THE STATION'S MOUTH IS THE DOCK BUTTON (Jon, Nov 15): on LOCAL at a station the bay's opening
## lights under the pointer (`StationFace.hover`, look A) and a click docks, as the bar's DOCK did.
## The bar's DOCK is gone. Pressable only while docking is offered, so only then does it look it.
## Why: docs/why/DockMouth.md#the-mouth-is-the-button

## The first-timer's line until the first dock by the mouth. Jon has not ruled: one const either way.
## Why: docs/why/DockMouth.md#the-hint-line
const HINT := true
const HINT_LINE := "A STATION HERE · CLICK ITS BAY TO DOCK"
const HINT_KEY := "dock_by_mouth"
static var _docked := -1

signal pressed

var screen: SectorScreen = null
## The pointer on the mouth (the GUI's own enter and exit).
var over := false
var _down := false


func _init() -> void:
	name = "DockMouth"
	mouse_filter = Control.MOUSE_FILTER_STOP
	# (set once, before the mirror: a cursor changed under it reads an upside-down rect, `Moored.cursor`)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(_dock)


## The mouth on `sc`'s station side: a child of the back face (under your ship's row, so your
## hull keeps its own clicks), lighting both faces.
static func attach(sc: SectorScreen, back: StationFace, fr: StationFace) -> DockMouth:
	var m := DockMouth.new()
	m.screen = sc
	back.add_child(m)
	for f: StationFace in [back, fr]:
		f.hover_of = m
	return m


## Whether the mouth takes a click now: where the bar's DOCK was offered, with LOCAL at rest.
func live() -> bool:
	var sc := screen
	if sc == null or not is_instance_valid(sc) or Router.current != sc or not sc.settled_local():
		return false
	var n: MapGen.MapNode = Run.node_at()
	if n == null or n.type != MapGen.NodeType.STATION or Run.dead or Router.final_loot or Router.docked:
		return false
	if not ZoomLadder.chosen() or not Router.at_station(n) or ZoomLadder.busy():
		return false
	return not (Run.hellbender_alive() and Run.hellbender_at == n.index)


## Lit only where it can be pressed.
func lit() -> bool:
	return over and live()


func _has_point(p: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(p) and live()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		over = true
		if live():
			Audio.hover()
	elif what == NOTIFICATION_MOUSE_EXIT:
		over = false


## As a button: pressed on it, let go on it (a press dragged off it does nothing).
func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if mb.pressed:
		_down = live()
	elif _down:
		_down = false
		if Rect2(Vector2.ZERO, size).has_point(mb.position) and live():
			pressed.emit()


## The click, which is what the bar's DOCK did; the hint line has done its job.
func _dock() -> void:
	Audio.click()
	if not docked_once():
		_docked = 1
		Hints.mark_seen(StringName(HINT_KEY))
	Router.show_station()


## `line` with the hint on it, until the first dock by the mouth on this profile.
static func hint_line(line: String) -> String:
	return HINT_LINE if HINT and ZoomLadder.chosen() and not docked_once() else line


static func docked_once() -> bool:
	if _docked < 0:
		var cfg := ConfigFile.new()
		var ok := cfg.load(Hints.store_path()) == OK
		_docked = 1 if ok and bool(cfg.get_value(Hints.SECTION, HINT_KEY, false)) else 0
	return _docked == 1


## For a harness: the hint as if never docked by the mouth (`true`), or as if docked.
static func forget(fresh: bool = true) -> void:
	_docked = 0 if fresh else 1
