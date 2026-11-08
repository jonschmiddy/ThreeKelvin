class_name ModuleCell
extends PanelContainer

## One cell for hardpoint and storage: they differ only in what they accept, not drag plumbing.
## Why: docs/why/ModuleCell.md#module-cell

enum Kind { HARDPOINT, STORAGE }

const PAD := 2

var kind: Kind = Kind.STORAGE
## HARDPOINT only: what this mount takes.
var slot: ModuleData.Slot = ModuleData.Slot.WEAPON
## The mount's number rides through to the module, as a mount is a place on the hull.
## Why: docs/why/ModuleCell.md#module-cell
var index: int = -1
## Which hold cell this is: dropping on the cell under the cursor arranges a hold.
var cell: Vector2i = -Vector2i.ONE
## What is sitting here, if anything.
var held: ModuleData = null

var _tractor: Tractor = null

## The screen owns every state change; a cell knows where a part came from and landed.
signal dropped(payload: Dictionary, onto: ModuleCell)

func setup(k: Kind, s: ModuleData.Slot, m: ModuleData, idx: int = -1) -> void:
	kind = k
	slot = s
	index = idx
	held = m
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(ModuleIcon.SIZE + PAD * 2, ModuleIcon.SIZE + PAD * 2)
	_style(false)
	Widgets.clear(self)
	if m != null:
		var icon := ModuleIcon.new()
		icon.setup(m, &"installed" if k == Kind.HARDPOINT else &"cargo")
		# The icon must not eat the drop: STOP would take the hover and hide cell acceptance.
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(icon)
	elif k == Kind.HARDPOINT:
		add_child(Pad.new(idx))

	# Always last so it paints over the icon; PanelContainer draws children in order.
	_tractor = Tractor.new()
	add_child(_tractor)

func _style(hot: bool) -> void:
	var bg := Color("#0e141d")
	var edge := UITheme.LINE
	if hot:
		edge = UITheme.HOT
		bg = Color("#1d2a1e")
	add_theme_stylebox_override("panel", UITheme.flat(bg, edge, 0, PAD, PAD))

## Typed to `ModuleData` on purpose: materials never bolt to a hull, so the drop check refuses them.
## Why: docs/why/ModuleCell.md#module-cell
func _accepts(m: ModuleData) -> bool:
	if m == null:
		return false
	if kind == Kind.HARDPOINT:
		return m.slot == slot
	return true

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var m := Widgets.dragged_module(data)
	if m == null:
		return false
	var ok := _accepts(m)
	# Lit only while it would take the thing; `_can_drop_data` runs per frame, so it is the hover.
	_style(ok)
	return ok

func _notification(what: int) -> void:
	# Godot has no drag-left callback, so clear on mouse exit and on any drag end.
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_style(false)
	# DRAG_BEGIN reaches every control, so all beams appear at once; `_can_drop_data` does not.
	if what == NOTIFICATION_DRAG_BEGIN and _tractor != null:
		var m := Widgets.dragged_module(get_viewport().gui_get_drag_data())
		# INVERTED from the mark this replaced: lit where the part CAN go.
		_tractor.visible = m != null and _accepts(m)
		_tractor.queue_redraw()
	elif what == NOTIFICATION_DRAG_END and _tractor != null:
		_tractor.visible = false

func _drop_data(_at: Vector2, data: Variant) -> void:
	_style(false)
	dropped.emit(data as Dictionary, self)


## The outline is a child in the content rect: a cell border made empty mounts look larger.
## Why: docs/why/ModuleCell.md#mount-pad
class Pad extends Control:
	var index: int = -1

	func _init(idx: int = -1) -> void:
		index = idx
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(ModuleIcon.SIZE, ModuleIcon.SIZE)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("#0b1017"), true)
		draw_rect(r, UITheme.EMBER.darkened(0.25), false, 1.0)
		# The mount's number, dim in the middle: mounts are places on the hull, not a queue.
		var f := UITheme.pixel_font()
		var txt := str(index + 1)
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UITheme.FS_SMALL).x
		draw_string(f, Vector2((size.x - w) * 0.5, size.y * 0.5 + 4.0), LowHull.scr(self, txt, UITheme.FS_SMALL, f),
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, UITheme.LINE)


class Tractor extends Control:
	## Positive affordance: accepting cells open a beam, replacing red crosses on every refusal.
	## Why: docs/why/ModuleCell.md#tractor-beam
	const BEAM := 5

	var phase: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _process(delta: float) -> void:
		# Only while it is on screen. A dozen of these idling behind a closed
		# refit screen is a dozen redraws a frame for nothing.
		if not visible:
			return
		phase = fmod(phase + delta * 2.4, TAU)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# The pulse rides alpha, never geometry, or a changing beam width reads as jitter.
		var pulse := 0.62 + 0.38 * sin(phase)
		var c := UITheme.TRACTOR

		draw_rect(r, Color(c.r, c.g, c.b, 0.10 * pulse), true)

		# Stacked rects, not a polygon: a sloped edge would be the one antialiased thing.
		var mid := r.size.x * 0.5
		var rows := int(r.size.y)
		for y in rows:
			var t := float(y) / float(maxi(1, rows - 1))
			var half := lerpf(r.size.x * 0.42, BEAM * 0.5, t)
			var a := lerpf(0.05, 0.30, t) * pulse
			draw_rect(Rect2(mid - half, float(y), half * 2.0, 1.0),
				Color(c.r, c.g, c.b, a), true)

		# Brackets, so the cell has a hard edge under the soft light. These are
		# what make it read as a PLACE rather than as a glow.
		var k := 5.0
		var t := 1.0
		# Typed, because the literal below is an untyped Array: its elements come
		# back as Variant and `:=` has nothing to infer from.
		var corners: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(r.size.x, 0.0),
			Vector2(0.0, r.size.y), Vector2(r.size.x, r.size.y)]
		var edge := Color(c.r, c.g, c.b, 0.85 * pulse)
		for corner in corners:
			var left := corner.x == 0.0
			var top := corner.y == 0.0
			var px := corner.x if left else corner.x - k
			var py := corner.y if top else corner.y - t
			draw_rect(Rect2(px, py, k, t), edge, true)
			px = corner.x if left else corner.x - t
			py = corner.y if top else corner.y - k
			draw_rect(Rect2(px, py, t, k), edge, true)
