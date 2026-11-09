class_name PaintLayer
extends Control

## A full-rect overlay that draws by calling `paint`, so one effect can stack a body layer
## and an additive light layer. Child order is draw order: add them in the order they paint.

var paint: Callable


## Builds a layer and adds it to `parent` as its last child; `additive` adds with light.
static func add_to(parent: Node, paint_fn: Callable, additive: bool = false) -> PaintLayer:
	var l := PaintLayer.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		l.material = mat
	l.paint = paint_fn
	parent.add_child(l)
	return l


func _draw() -> void:
	paint.call(self)
