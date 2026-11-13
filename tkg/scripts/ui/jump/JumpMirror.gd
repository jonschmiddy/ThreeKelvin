class_name JumpMirror
extends SubViewport

## The world under a jump film's stage, drawn again into its own texture: a SubViewport on
## the game view's World2D that draws layer 1 only. Everything off EncounterView's path (the
## HUD) and the stage go on HIDDEN alone while it lives; freed, it puts the layers back.
## Why: docs/why/JumpMirror.md#mirror

const HIDDEN := 1 << 19

var _held: Array[Array] = []


## A mirror of `view`'s world, the size of its viewport, with `also` (the stage) culled too.
static func of(view: Control, also: Array[CanvasItem]) -> JumpMirror:
	var m := JumpMirror.new()
	var vp := view.get_viewport()
	m.size = Vector2i(vp.get_visible_rect().size)
	m.world_2d = vp.world_2d
	m.canvas_cull_mask = 1
	m.transparent_bg = false
	m.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	m.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var path: Node = view
	while path != null and not (path is Viewport):
		var par := path.get_parent()
		if par == null:
			break
		for c in par.get_children():
			if c != path and c is CanvasItem:
				m._hide(c as CanvasItem)
		path = par
	for c in also:
		m._hide(c)
	return m


func _hide(c: CanvasItem) -> void:
	_held.append([c, c.visibility_layer])
	c.visibility_layer = HIDDEN


func _exit_tree() -> void:
	for e in _held:
		if is_instance_valid(e[0]):
			(e[0] as CanvasItem).visibility_layer = e[1]
	_held.clear()
