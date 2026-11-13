class_name UiRect
extends RefCounted

## A control's box on screen, flips and all. `get_global_rect()` builds it from the
## transform's scale, and a mirrored transform's scale puts its minus sign on y: under
## LOCAL drawn mirrored (`EncounterView.mirrored`) that box was upside down and on the
## wrong side. This one is from the corners.
## Why: docs/why/SectorScreen.md#mirrored
static func of(c: Control) -> Rect2:
	var xf := c.get_global_transform()
	var a := xf * Vector2.ZERO
	var b := xf * c.size
	var r := Rect2(a, b - a).abs()
	# (and a rotation's other two corners, should one ever be turned)
	r = r.expand(xf * Vector2(c.size.x, 0.0)).expand(xf * Vector2(0.0, c.size.y))
	return r
