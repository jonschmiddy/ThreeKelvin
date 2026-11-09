class_name DeathHandoff
extends CanvasLayer

## The death was an abrupt cut (Jon, Oct 13), so three handoffs were drawn; `DEATH_HANDOFF` picks.
## Why: docs/why/DeathHandoff.md#death-handoff

const SHADER := preload("res://shaders/death_handoff.gdshader")

var _rect: ColorRect
var _mat: ShaderMaterial


func _init() -> void:
	layer = 90
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Every click stops here while the run is ending.
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)


func _ready() -> void:
	_mat.set_shader_parameter(&"rows", maxf(get_viewport().get_visible_rect().size.y, 1.0))


## A, B: dimmed and drained, 0 to 1.
func set_dim(v: float) -> void:
	_mat.set_shader_parameter(&"look", 0)
	_mat.set_shader_parameter(&"dim", v)


## C: how far the feed has gone, 0 to 1.
func set_signal(v: float) -> void:
	_mat.set_shader_parameter(&"look", 2)
	_mat.set_shader_parameter(&"t", v)


## The picture as it stands, once this frame is drawn: what RUN ENDED sits on.
func still() -> Texture2D:
	# (headless draws nothing and never posts a frame: no picture to keep)
	if DisplayServer.get_name() == "headless":
		return null
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)
