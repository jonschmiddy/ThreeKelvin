class_name DeskScene
extends Control

## A visit to the science desk (Jon, Nov 17 to 19): a reading picked on LOCAL pushes into your ship
## and fades to your room, which powers on with a card naming the site on its monitor. A tap takes
## the reading (once) and shows its outcome there; a tap or Esc runs it all back to LOCAL.
## Why: docs/why/DeskScene.md#the-hook

signal left(result: Dictionary)

## Jon's switch (Nov 19): the desk plays for every science reading.
static var enabled := true
## Jon's ruling (Nov 19, his A): the room goes by the hull. Salvage frames (unbranded) get the nook,
## light hulls the bunk, medium DESK 1, heavy DESK 2. Rooms not yet ported fall back to DESK 1.
## Why: docs/why/DeskScene.md#jons-rulings-nov-19
const BUILT: Array[String] = ["desk_1", "desk_2", "bunk_1", "nook_1"]
## The page's act 1, in scene seconds: LOCAL held, the push in (1x to 8x), the fade to black.
const HOLD := 0.5
const ZOOM_END := 2.1
const FADE_AT := 1.7
const ZOOM_MAX := 8.0
## Where the page's LOCAL shot had the ship, for a screen that cannot say where yours is.
const SHIP_DEFAULT := Vector2(198, 276)
## A frame longer than this (the room's first frame compiles its shaders) moves the clock this much.
const DT_MAX := 0.1
## A mini game's picture feeds the room's screen light this often (s): it is read on the CPU.
const LIGHT_EVERY := 0.5

var room: DeskRoom
var audio: DeskAudio
var canvas: SubViewport
var site := ""
var ts := 0.0
var real := 0.0
var leaving := false
var taken := false
var result: Dictionary = {}
var _take: Callable
var _shot: Texture2D = null
var _ship := SHIP_DEFAULT
var _clock := 0.0
var _leave_t0 := -1.0
var _leave_from := 0.0
var _shown_at := -1.0
var _fallback: TextureRect = null
var _done := false
## The reading played as a mini game (`MiniGames.deal`: id, depth, sensors, seed); empty, a tap takes it.
var _deal: Dictionary = {}
var game: MiniShell = null
var _paying := false
var _light_t := 0.0


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


## Whether taking choice `c` goes through the desk: a reading (`reads`), with the switch on and a
## screen to draw on (headless harnesses take it straight).
static func wants(c: Dictionary) -> bool:
	return enabled and int(c.get("reads", 0)) > 0 and DisplayServer.get_name() != "headless"


## The whole visit over `host` (LOCAL): returns what the reading's take said, or {} when the
## player left before taking it. `take(tier)` is the one call that resolves the reading (tier -1:
## no game); with `deal`, the tap plays that mini game and its end takes the reading with its haul.
static func visit(host: Node, title: String, ship_at: Vector2, take: Callable, deal: Dictionary = {}) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	var layer := CanvasLayer.new()
	layer.layer = 120
	host.add_child(layer)
	var d := DeskScene.new()
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(d)
	if not d.open(room_for(Run.hull), title, ship_at, take, deal):
		layer.queue_free()
		return out
	var r: Dictionary = await d.left
	layer.queue_free()
	out.assign(r)
	return out


func open(room_id: String, title: String, ship_at: Vector2, take: Callable, deal: Dictionary = {}) -> bool:
	mouse_filter = Control.MOUSE_FILTER_STOP
	site = title
	_take = take
	_deal = deal
	if ship_at.x >= 0.0:
		_ship = ship_at
	# LOCAL as it stands, for the push in (the page's act 1 zooms a still too)
	var img := get_viewport().get_texture().get_image()
	if img != null:
		_shot = ImageTexture.create_from_image(img)
	canvas = SubViewport.new()
	canvas.size = Vector2i(DeskRoom.CANVAS)
	canvas.disable_3d = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(canvas)
	room = DeskRoom.new()
	room.size = DeskRoom.CANVAS
	canvas.add_child(room)
	if not room.setup(room_id):
		return false
	var tell := {}
	var g := MiniGames.make(StringName(_deal.get("id", &""))) if not _deal.is_empty() else null
	if g != null:
		tell = {text = g.hint(), controls = g.controls()}
	else:
		_deal = {}
	room.set_card(site, tell)
	room.set_screen(DeskCard.still(DeskCard.title(site, tell)))
	room.life.hold_title()
	# drawn once now, while LOCAL still holds: the shaders compile behind the still picture
	room.show_at(DeskTimeline.A, DeskTimeline.A, false)
	audio = DeskAudio.new()
	audio.lamp_at = room.life.lamp_at
	audio.crt_at = room.life.crt_at
	add_child(audio)
	if GameShell.instance == null:
		_fallback = TextureRect.new()
		_fallback.texture = canvas.get_texture()
		_fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_fallback.stretch_mode = TextureRect.STRETCH_SCALE
		_fallback.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fallback.visible = false
		add_child(_fallback)
	return true


## Run back to LOCAL from wherever the visit stands.
func leave() -> void:
	# a game's reading is taken at its end: never leave between the end and the take
	if leaving or (game != null and (game.playing() or _paying)):
		return
	leaving = true
	_leave_t0 = _clock
	_leave_from = minf(ts, room.life.done_at)


## The tap: takes the reading once the card is up; once its outcome is up, leaves.
func tap() -> void:
	if leaving or room == null:
		return
	var u := ts - DeskTimeline.A
	if not taken:
		if u < room.life.title_u:
			return
		taken = true
		room.life.release(u)
		if not _deal.is_empty():
			_play()
			return
		result = await _take.call(-1)
		var res: Variant = result.get("res", {})
		var said := String((res as Dictionary).get("text", "")) if res is Dictionary else ""
		room.set_screen(DeskCard.outcome(said if said != "" else String(result.get("text", ""))))
		_shown_at = ts
	elif _shown_at >= 0.0 and ts - _shown_at > room.life.title_wipe:
		leave()


## The tap on the card: the dealt game mounts on the glass, and the card wipes into it.
func _play() -> void:
	game = MiniShell.new()
	game.scored.connect(_on_scored)
	game.start(MiniGames.make(StringName(_deal.id)), int(_deal.depth), int(_deal.sensors), MiniGames.stream(int(_deal.seed)))
	room.show_screen(game.glass, true)


## The game is over: the reading is taken now, its haul paid by the tier, once.
func _on_scored(tier: int) -> void:
	_paying = true
	result = await _take.call(tier)
	_paying = false
	game.set_haul(String(result.get("haul", "")))


func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if game != null and game.playing():
		_to_game(e)
		accept_event()
		return
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		tap()
		accept_event()


## The pointer, onto the glass's pixels through the tube's curve, for the game.
## Why: docs/why/MiniGame.md#input-on-the-glass
func _to_game(e: InputEvent) -> void:
	var me := e as InputEventMouse
	if me == null:
		return
	var g := room.glass_at(me.position * DeskRoom.CANVAS / size)
	var mb := e as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			game.press(g)
		else:
			game.release(g)
	elif e is InputEventMouseMotion:
		game.motion(g)


func _input(e: InputEvent) -> void:
	if e.is_action_pressed(&"ui_cancel"):
		# Esc during a game gives up (it still pays); after it, or before one, it leaves
		if game != null and game.playing():
			game.give_up()
		else:
			leave()
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if room == null or _done:
		return
	_clock += minf(dt, DT_MAX)
	real = _clock
	if leaving:
		ts = DeskTimeline.leaving(_clock - _leave_t0, _leave_from)
	else:
		ts = DeskTimeline.forward(real)
	var free := real
	if DisplaySettings.reduced_motion:
		free = minf(real, DeskTimeline.ZOOM_S + (DeskTimeline.KNEE - DeskTimeline.A) / DeskTimeline.SPEED)
	var in_room := ts >= DeskTimeline.A
	if game != null:
		_tick_game(minf(dt, DT_MAX))
	if in_room:
		room.show_at(ts, free, leaving)
	_show_canvas(in_room)
	audio.tick(ts, minf(dt, DT_MAX), leaving)
	queue_redraw()
	if leaving and ts <= 0.0:
		_done = true
		_show_canvas(false)
		audio.stop()
		left.emit(result)


func _tick_game(step: float) -> void:
	_light_t += step
	var light := _light_t >= LIGHT_EVERY
	if game.tick(step):
		room.show_screen(game.glass, light)
		if light:
			_light_t = 0.0
	if game.revealed and _shown_at < 0.0 and not _paying:
		_shown_at = ts


func _show_canvas(on: bool) -> void:
	if _fallback != null:
		_fallback.visible = on
	elif on != GameShell.covered():
		GameShell.cover(canvas.get_texture() if on else null)


## Act 1, the page's: LOCAL held, then pushed into your ship (it glides to the middle as it grows,
## so the picture's edge never shows), then black. Leaving runs it back. Reduced motion: no push.
func _draw() -> void:
	var a := DeskTimeline.A
	if ts >= a:
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
		return
	if _shot != null:
		var z := 1.0
		if not DisplaySettings.reduced_motion:
			z = 1.0 + (ZOOM_MAX - 1.0) * _ease((ts - HOLD) / (ZOOM_END - HOLD))
		var u := (z - 1.0) / (ZOOM_MAX - 1.0)
		var at := _ship + (size / 2.0 - _ship) * u
		# a ship near LOCAL's edge (yours flies in at the left) would bare the still's edge: it
		# comes as near the middle as the picture allows
		at = at.clamp(size - (size - _ship) * z, _ship * z)
		draw_texture_rect(_shot, Rect2(at - _ship * z, size * z), false)
	var f := clampf((ts - FADE_AT) / (a - FADE_AT - 0.15), 0.0, 1.0)
	if f > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, f))


## The page's ease (cubic in and out).
static func _ease(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0
