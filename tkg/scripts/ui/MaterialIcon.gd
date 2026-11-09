class_name MaterialIcon
extends ItemIcon

## Not a variant of ModuleIcon: a material has no hull form to echo, so it draws a container.
## Same flat rectangles and 40px cell as module icons, so a packed hold reads as one surface.
## Why: docs/why/MaterialIcon.md#material-icon

var item: MaterialData = null

## The same number the box was sized with: a mismatch put a 3x box around a 2x sprite
## on the module gallery.
## Why: docs/why/MaterialIcon.md#plate-scale
var plate_scale: float = ModuleIcon.HOLD_K

func setup(m: MaterialData, from: StringName) -> void:
	item = m
	origin = from
	# `Widgets.tip` wraps, as Godot does not and a raw paragraph becomes a banner.
	# The facts line carries what the crate cannot show: what a station will pay.
	# Why: docs/why/MaterialIcon.md#tooltip
	tooltip_text = tip_text(m)
	queue_redraw()


## One place for the tooltip words, as the cutaway's card must say the same thing.
static func tip_text(m: MaterialData) -> String:
	var shape := "%d x %d" % [m.size.x, m.size.y]
	return Widgets.tip("%s\n%s \u00b7 %s \u00b7 SELLS FOR %d\n\n%s" % [
		m.name.to_upper(), String(m.tier).to_upper(), shape, m.value, m.text])


## A non-module hold item as a control for the cutaway's card,
## tagged with the item as `ModuleIcon.tip_for` does.
static func tip_for(m: HoldItem) -> Control:
	var l := Label.new()
	l.theme_type_variation = &"TooltipLabel"
	if m is MaterialData:
		l.text = tip_text(m as MaterialData)
	elif m is CreditChit:
		l.text = ChitIcon.tip_text(m as CreditChit)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_meta(&"item", m)
	return l


func held_item() -> HoldItem:
	return item


func _ghost() -> Control:
	var g := MaterialIcon.new()
	g.setup(item, origin)
	return ItemIcon.wrap_ghost(g, global_position)


func _draw() -> void:
	if item == null:
		return
	# Art when there is art, the crate underneath, decided in this one place or two would drift.
	# Only the ARTIFACT tier gets a picture, stood on end when turned.
	# Why: docs/why/MaterialIcon.md#art-or-crate
	if item.sprite != null:
		ModuleIcon.draw_sprite(self, item.sprite,
			Rect2(Vector2.ZERO, size), false, plate_scale,
			ModuleIcon.sprite_turn(item.sprite, item.footprint()))
		return
	# The tier is an accent: full saturation made crates the brightest thing on a cold-steel
	# screen. The body is pulled toward the ground; edge and pip stay full, where identity is read.
	# Why: docs/why/MaterialIcon.md#tier-colour
	var tier := UITheme.tier_colour(item.tier)
	var tint := Color.from_hsv(tier.h, tier.s * 0.42, tier.v * 0.62)
	var lit := tint.lerp(Color.WHITE, 0.22)
	var dim := tint.lerp(Color("#0b0f16"), 0.42)
	var ink := Color("#0b0f16")

	# The body fills the footprint less a hairline, so two crates in adjacent
	# cells read as two objects rather than one long one.
	var box := Rect2(Vector2.ONE, size - Vector2(2, 2))
	draw_rect(box, dim, true)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 2)), lit, true)
	draw_rect(box, tier, false, 1.0)

	# Bands across the short axis, spaced off the cell so a 2x1 gets twice the bands of a 1x1.
	var along := box.size.x >= box.size.y
	var run := box.size.x if along else box.size.y
	var bands := maxi(2, int(run / 14.0))
	for i in bands:
		var t := (float(i) + 0.5) / float(bands)
		if along:
			var x := box.position.x + run * t
			draw_rect(Rect2(x - 1.0, box.position.y + 3.0, 2.0,
				box.size.y - 6.0), ink, true)
		else:
			var y := box.position.y + run * t
			draw_rect(Rect2(box.position.x + 3.0, y - 1.0,
				box.size.x - 6.0, 2.0), ink, true)

	# A corner pip in the tier colour, as the band colour is lost against a lit neighbour.
	draw_rect(Rect2(box.position + Vector2(2, 2), Vector2(4, 4)), tier, true)
