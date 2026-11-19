class_name DeskScene
extends Control

## A visit to the science desk: the room powers on and idles, and leaving runs the same timeline
## backwards (the approved page's shell, `DeskTimeline`), with its sound (`DeskAudio`). Runs on
## `GameClock`, never the wall clock. Act 1 (the push into your ship on LOCAL) belongs to the hook;
## until then the desk opens from black. Reduced motion keeps the power-on and holds the idle still.
## Why: docs/why/DeskScene.md#the-plan

signal left

## Jon's switch (Nov 19): the desk plays for every science reading.
static var enabled := true

## Jon's ruling (Nov 19, his A): the room goes by the hull. Salvage frames (unbranded) get the nook,
## light hulls the bunk, medium DESK 1, heavy DESK 2. Rooms not yet ported fall back to DESK 1.
## Why: docs/why/DeskScene.md#jons-rulings-nov-19
const BUILT: Array[String] = ["desk_1"]


static func room_for(h: HullData) -> String:
	var r := "desk_1"
	if h != null:
		if h.manufacturer == &"":
			r = "nook_1"
		elif h.weight == HullData.Weight.LIGHT:
			r = "bunk_1"
		elif h.weight == HullData.Weight.HEAVY:
			r = "desk_2"
	return r if BUILT.has(r) else "desk_1"


var room: DeskRoom
var audio: DeskAudio
var _black: ColorRect
var _t0 := 0.0
var _last := 0.0
var _leave_t0 := -1.0
var _leave_from := 0.0
var ts := 0.0
var real := 0.0
var leaving := false


func open(room_id: String) -> bool:
	room = DeskRoom.new()
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(room)
	if not room.setup(room_id):
		return false
	audio = DeskAudio.new()
	audio.lamp_at = DeskOne.LAMP_AT
	audio.crt_at = DeskOne.CRT_AT
	add_child(audio)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_black)
	_t0 = GameClock.now()
	_last = _t0
	resized.connect(_fit)
	_fit()
	return true


## The room at 16:9, as large as fits, centred; black round it.
func _fit() -> void:
	if room == null:
		return
	var s := minf(size.x / DeskRoom.CANVAS.x, size.y / DeskRoom.CANVAS.y)
	room.size = DeskRoom.CANVAS * s
	room.position = ((size - room.size) / 2.0).floor()


## Run back to LOCAL from wherever the power-on stands.
func leave() -> void:
	if leaving:
		return
	leaving = true
	_leave_t0 = GameClock.now()
	_leave_from = minf(ts, DeskOne.DONE_AT)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(&"ui_cancel"):
		leave()
		accept_event()


func _process(_dt: float) -> void:
	if room == null:
		return
	var now := GameClock.now()
	var dt := now - _last
	_last = now
	real = now - _t0
	if leaving:
		ts = DeskTimeline.leaving(now - _leave_t0, _leave_from)
	else:
		ts = DeskTimeline.forward(real)
	var clock := real
	if DisplaySettings.reduced_motion:
		clock = minf(real, DeskTimeline.ZOOM_S + (DeskTimeline.KNEE - DeskTimeline.A) / DeskTimeline.SPEED)
	room.show_at(ts, clock, leaving)
	_black.visible = ts < DeskTimeline.A
	audio.tick(ts, dt, leaving)
	if leaving and ts <= 0.0:
		audio.stop()
		set_process(false)
		left.emit()
