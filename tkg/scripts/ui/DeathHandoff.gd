class_name DeathHandoff
extends CanvasLayer

## FROM THE WRECK TO RUN ENDED (Jon, Oct 13: "the transition from this to this
## is really abrupt"). It was a cut: the fight holding your wreck, then on the
## next frame the RUN ENDED panel over a different sky with a planet in it.
##
## Three ideas, one picked by `SectorScreen.DEATH_HANDOFF`:
##   A  LINGER AND FADE: the hand lowers as it does on a win, and the whole
##      picture, HUD and all, darkens and drains over 1.2 s with the wreck in
##      view; RUN ENDED then fades and rises in over that picture.
##   B  PULL BACK: the hand lowers, and LOCAL's own camera pulls back the way
##      the one-camera move to the map does (`ladder_cam`): the wreck drifts
##      small in the field as it dims; RUN ENDED fades in over that.
##   C  SIGNAL LOST: the picture degrades like a dying feed -- scanlines
##      thicken, colour drains, bands tear -- and collapses to a dim line; RUN
##      ENDED then types in on the dark screen.
## The last frame is kept (`still`) and RUN ENDED is drawn over it
## (`GameOverScreen.setup`), so nothing is swapped under the panel.
##
## Over everything in the game's picture, HUD included, and taking every click
## until the panel's buttons are up.

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
