class_name ShaderWarm
extends Node

## THE SECTOR MAP'S SHADERS COMPILED BEHIND THE TITLE MENU (Oct 27, on Jon's
## Mac: Intel Iris Plus 645, Apple's own OpenGL).
##
## Godot's OpenGL renderer compiles a canvas shader the first time something is
## drawn with it, on the main thread, and the frame waits. The chart's are
## compiled behind the boot splash (`ChartSky._warm`); nothing else was, so the
## first sector map stood still while its own compiled: about 0.8 s of its
## first frame's 1.6 to 2.5 s on this Mac (`LadderShot first timing`). And
## Apple's OpenGL hands Godot no program binaries to keep (its shader cache
## folder comes out empty), so that is every launch, not only the first.
##
## So they are compiled here instead, one each frame while the title is up:
## drawn once into a 4x4 picture of their own, never shown, the way the game
## draws them -- a rect, and the fabric as a mesh, which is a program of its own
## (`draw_mesh` binds the attribute variant). Nothing drawn on screen changes.
## A compile is a frame the title does not answer in, so none is started within
## QUIET_MS of the player moving the mouse or pressing anything (`note_input`,
## fed by the title's own `_input` from the moment it is up, so a hand already
## moving when the warm begins holds back the first compile too; and never in
## the first QUIET_MS after this node arrives), and only the
## cheap ones are here: each costs this Mac at most a frame as long as the
## title's own longest (0.4 s, `-- sheet=WarmCost`). Not on the hull pick,
## whose hull bobs and burns, so a held frame there would be seen; what is left
## when the title goes is paid where it is used, as before.
##
## LOCAL'S ARE NOT HERE, ON PURPOSE: `planet` takes 13 to 16 s to compile on
## this Mac, `sun` and `sky_nebula` 1.9 s each. Behind the title that froze the
## menu for as long (measured), so they are still compiled by the first LOCAL.
##
## `-- warm=0` turns it off (to measure a launch without it); so does `off`
## (`-- sheet=WarmCost`, which times the compiles itself).

## What a frame's compile waits for after the last input, ms.
const QUIET_MS := 250

const RECT := 0
const MESH := 1

const SKY := preload("res://shaders/sky.gdshader")
const SKY_DEPTH := preload("res://shaders/sky_depth.gdshader")
const MAP_PALETTE := preload("res://shaders/map_palette.gdshader")
const MAP_FABRIC := preload("res://shaders/map_fabric.gdshader")

## Each shader with how the map draws it, the costliest first. (GRAPHICS LOW
## draws all four too: its map keeps the sky, the palette, the fabric and the
## two fluffy depth sheets, `SystemView` `gfx_low`.)
static func wanted() -> Array:
	return [
		[SKY, RECT],
		[SKY_DEPTH, RECT],
		[MAP_FABRIC, MESH],
		[MAP_PALETTE, RECT],
	]

## Held off by a harness that times the compiles itself.
static var off := false
static var _list: Array = []
static var _next := 0
static var _node: ShaderWarm = null
## Each shader drawn so far, with how long its frame took from this node's
## turn to the end of the draw, ms (for a harness: `LadderShot first`).
static var costs: Array = []
## No compile starts before this tick, ms: QUIET_MS past the last input seen
## and past this node's arrival.
static var _quiet_until := 0
## How far a stick has to be pushed to count as the player's hand (a resting
## pad's drift is not).
const STICK := 0.2


## The player touched something (`LauncherScreen._input`, and this node's own):
## no compile for QUIET_MS. Every event a window gets -- mouse, keys, touch, a
## trackpad's pan and pinch -- and a pad's buttons and sticks.
static func note_input(event: InputEvent) -> void:
	var stick := event as InputEventJoypadMotion
	if event is InputEventFromWindow or event is InputEventJoypadButton \
			or (stick != null and absf(stick.axis_value) > STICK):
		_quiet_until = maxi(_quiet_until, Time.get_ticks_msec() + QUIET_MS)


## Whether a compile would land too near the player's last input now.
static func held() -> bool:
	return Time.get_ticks_msec() < _quiet_until


## Begin, or go on from where the last visit to the title left off.
static func start() -> void:
	if _node != null or off or DisplayServer.get_name() == "headless" \
			or "warm=0" in OS.get_cmdline_user_args():
		return
	if _list.is_empty():
		_list = wanted()
	if _next >= _list.size():
		return
	_node = ShaderWarm.new()
	_node.name = "ShaderWarm"
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_node)


## Whether every shader has been drawn once.
static func done() -> bool:
	return not _list.is_empty() and _next >= _list.size()


var _drawn: Array[Node] = []
var _t_draw := 0
var _what := ""


func _ready() -> void:
	# (arrived: the first compile waits its QUIET_MS like the rest)
	_quiet_until = maxi(_quiet_until, Time.get_ticks_msec() + QUIET_MS)
	RenderingServer.frame_post_draw.connect(_after_draw)


func _input(event: InputEvent) -> void:
	note_input(event)


func _process(_delta: float) -> void:
	# (last frame's, drawn now: gone)
	for n in _drawn:
		n.queue_free()
	_drawn.clear()
	if _next >= _list.size() or not (Router.current is LauncherScreen):
		queue_free()
		return
	if held():
		return
	var e: Array = _list[_next]
	_next += 1
	var vp := SubViewport.new()
	vp.size = Vector2i(4, 4)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var m := ShaderMaterial.new()
	m.shader = e[0]
	if int(e[1]) == MESH:
		var it := _MeshItem.new()
		it.material = m
		vp.add_child(it)
	else:
		var r := ColorRect.new()
		r.size = Vector2(4, 4)
		r.material = m
		vp.add_child(r)
	add_child(vp)
	_drawn.append(vp)
	_what = (e[0] as Shader).resource_path
	_t_draw = Time.get_ticks_usec()


func _after_draw() -> void:
	if _what != "":
		costs.append([_what, (Time.get_ticks_usec() - _t_draw) / 1000.0])
		_what = ""


func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_after_draw):
		RenderingServer.frame_post_draw.disconnect(_after_draw)
	for n in _drawn:
		n.queue_free()
	_drawn.clear()
	if _node == self:
		_node = null


## A mesh drawn as the fabric draws its grid (`SystemView._Fabric`): vertex,
## UV and colour, indexed.
class _MeshItem extends Node2D:
	## (held: a mesh freed after `draw_mesh` is drawn as nothing)
	var _mesh: ArrayMesh = null

	func _draw() -> void:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		_mesh = ArrayMesh.new()
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		draw_mesh(_mesh, null)
