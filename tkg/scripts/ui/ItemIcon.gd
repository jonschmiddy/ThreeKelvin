class_name ItemIcon
extends Control

## Dragging is the same for any held thing, so it lives here and not on `ModuleIcon`.
## Without it, materials rendered but could not be picked up.
## Why: docs/why/ItemIcon.md#shared-hold-icon

signal picked_up(icon: ItemIcon)

## Static: Godot owns the drag preview, and turning mid-carry must resize what you see.
static var carried: ItemIcon = null

## Where it was picked up from. The drop reads it to tell a move inside the hold
## from an arrival out of somewhere else.
var origin: StringName = &"cargo"


## Godot pins the preview to the pointer, which feels dead: pin a wrapper, ease the plate.
## Why: docs/why/ItemIcon.md#carried-ghost
class Ghost extends Control:
	## E-folds per second the plate closes on the cursor: 16 leaves a visible flick trail.
	const FOLLOW := 16.0

	## See-through so the grid shows: at 0.78 the plate hid the two cells being decided.
	## Why: docs/why/ItemIcon.md#ghost-alpha
	const ALPHA := 0.55

	var plate: ItemIcon
	var _spawn: Vector2
	var _at: Vector2
	var _live: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = ALPHA
		set_process(true)

	## Starts exactly over what it came out of, not already centred elsewhere.
	func start(p: ItemIcon, from: Vector2) -> void:
		plate = p
		_spawn = from
		add_child(p)

	func _process(delta: float) -> void:
		if plate == null:
			return
		if not _live:
			# First frame in the tree, which is the first time a global
			# position means anything.
			_live = true
			_at = _spawn
		var want := get_global_mouse_position() - plate.size * 0.5
		# Frame-rate independent: a fixed fraction per second, not per frame.
		_at = _at.lerp(want, 1.0 - exp(-FOLLOW * delta))
		plate.global_position = _at


## Jettison is on the base, as 3.5 applies it to all. No confirmation, as it is undoable.
## A thing you can pick up is a thing you can press, so the reticle closes on it.
## Why: docs/why/ItemIcon.md#press-and-jettison
func _init() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var m := held_item()
	if m == null:
		return
	# (a hold shown to pick from moves nothing, by any gesture: `HoldGrid.pick_mode`)
	var g := get_parent() as HoldGrid
	if g != null and g.pick_mode:
		return
	# Shift-click or double-click takes; right-click throws. Origin decides, never both.
	# Why: docs/why/ItemIcon.md#take-and-throw-gestures
	if mb.button_index == MOUSE_BUTTON_LEFT \
			and (mb.shift_pressed or mb.double_click):
		# The pad takes the same gesture: six objects in a row must not need six drags.
		if origin == &"pad":
			accept_event()
			Run.pad_to_hold(m)
			return
		if origin != &"bag":
			return
		accept_event()
		await Run.take_item(m)
		return
	# Right-click no longer throws: the only destructive gesture with no confirmation.
	# Why: docs/why/ItemIcon.md#right-click-removed


## What this icon is showing. Overridden by each kind; the drag machinery and
## the hold both ask through here rather than reaching for a typed field.
func held_item() -> HoldItem:
	return null


## Size to the thing's CURRENT shape, in the hold's own cells.
func fit_footprint() -> void:
	var m := held_item()
	if m == null:
		return
	var f := ModuleIcon.footprint_box(m)
	custom_minimum_size = f
	size = f
	pivot_offset = f * 0.5
	queue_redraw()


## A 0.14 s quarter turn that shows which way it turned, so 1x3 to 3x1 is not read as a swap.
func spin() -> void:
	pivot_offset = size * 0.5
	rotation = -PI * 0.5
	var t := create_tween()
	var step := t.tween_property(self, "rotation", 0.0, 0.14)
	step.set_trans(Tween.TRANS_CUBIC)
	step.set_ease(Tween.EASE_OUT)


## The preview is a copy, as Godot reparents what is returned and would leave a hole in the grid.
## Why: docs/why/ItemIcon.md#drag-preview-copy
func _get_drag_data(_at: Vector2) -> Variant:
	var m := held_item()
	if m == null:
		return null
	# (a hold shown to pick from lifts nothing: `HoldGrid.pick_mode`)
	var g := get_parent() as HoldGrid
	if g != null and g.pick_mode:
		return null
	set_drag_preview(_ghost())
	# Hidden, not removed, so a cancelled drag can restore it. Nothing commits until it lands.
	# Why: docs/why/ItemIcon.md#lift-leaves-cell
	visible = false
	# Out of the hold and into the hand, the same lift a part makes coming
	# off the hull. Every screen with a hold picks up through here.
	Audio.play(&"hold_lift", 0.08)
	picked_up.emit(self)
	# `module` stays the payload key: renaming it across four screens risks silent misses.
	# Why: docs/why/ItemIcon.md#payload-key
	return {module = m, origin = origin}


## `NOTIFICATION_DRAG_END` reaches every control, so the icon returns when the drop did not land.
## Why: docs/why/ItemIcon.md#drag-end-restore
func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return
	visible = true
	# Turning mid-drag flips `turned` in the hold, so `Run.settle` fixes it here for every screen.
	# Why: docs/why/ItemIcon.md#drag-end-restore
	var m := held_item()
	if m != null:
		Run.settle(m)


## An icon answers as its parent would: it was unproven that Godot asks the grid beneath.
## Why: docs/why/ItemIcon.md#pass-through-drops
func _can_drop_data(at: Vector2, data: Variant) -> bool:
	var g := get_parent() as Control
	if g == null or not g.has_method("_can_drop_data"):
		return false
	return g._can_drop_data(at + position, data)


func _drop_data(at: Vector2, data: Variant) -> void:
	var g := get_parent() as Control
	if g != null and g.has_method("_drop_data"):
		g._drop_data(at + position, data)


## A copy of this icon, sized to its footprint, inside a following wrapper.
## Overridden so each kind builds its own sort of plate.
func _ghost() -> Control:
	return null


## The kind-to-icon choice is made only here, so a new `HoldItem` kind is wired once.
static func make(m: HoldItem, from: StringName) -> ItemIcon:
	if m is CreditChit:
		var ci := ChitIcon.new()
		ci.setup(m as CreditChit, from)
		return ci
	if m is MaterialData:
		var mi := MaterialIcon.new()
		mi.setup(m as MaterialData, from)
		return mi
	var gi := ModuleIcon.new()
	gi.setup(m as ModuleData, from)
	return gi


## The shared tail of pick-up: every ghost is a copy in the same following wrapper.
static func wrap_ghost(g: ItemIcon, at: Vector2) -> Control:
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.fit_footprint()
	ItemIcon.carried = g
	var wrap := Ghost.new()
	wrap.start(g, at)
	return wrap
