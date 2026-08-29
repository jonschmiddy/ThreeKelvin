class_name ItemIcon
extends Control

## Anything in the hold, as something you can pick up and carry.
##
## The view-side twin of `HoldItem`, and it exists for the same reason and by the
## same test. Everything about DRAGGING is identical whether the thing in your
## hand is a gun or a crate of ore: it lifts out of a cell, it eases toward the
## cursor, it turns a quarter when you ask, and it lands somewhere or it does
## not. None of that is about being a module.
##
## What each kind draws is entirely its own business, and stays on the subclass.
##
## `MaterialIcon` did not have any of this at first and the symptom was exactly
## what you would expect: the crates rendered perfectly and could not be picked
## up. A material was a thing the hold could hold and not a thing a hand could
## reach, because the reaching lived on `ModuleIcon`.

signal picked_up(icon: ItemIcon)

## The preview currently under the cursor, or null.
##
## STATIC because Godot takes ownership of whatever `set_drag_preview` is handed
## and offers no way to ask for it back — and turning a thing while you are
## carrying it has to resize what you are looking at, not just the record.
static var carried: ItemIcon = null

## Where it was picked up from. The drop reads it to tell a move inside the hold
## from an arrival out of somewhere else.
var origin: StringName = &"cargo"


## WHAT YOU ARE CARRYING, and how it behaves while you carry it.
##
## Godot pins whatever `set_drag_preview` is given to the pointer, exactly, on
## every frame. That is correct and it feels dead: grab a three-cell rail by its
## far end and it stays gripped at that corner for the whole drag, and a fast
## flick moves it as though it were welded to the mouse.
##
## So the thing the engine pins is a WRAPPER, and the plate inside it is eased
## toward the cursor in SCREEN space. One easing buys both halves of what people
## mean when they say a drag feels good: whatever corner you grabbed drifts to
## the middle over a few frames, and a fast flick leaves the plate trailing until
## the mouse stops, at which point it catches up and centres.
class Ghost extends Control:
	## How fast the plate closes on the cursor, in e-folds per second. Higher is
	## tighter. At 16 a flick leaves a plainly visible trail and a stop settles
	## in about a fifth of a second, which is long enough to see and short
	## enough not to fight.
	const FOLLOW := 16.0

	## How see-through. The point is the GRID under the plate: packing is a game
	## of seeing what a part would displace, and at 0.78 the plate in hand hid
	## the two cells the decision was about.
	const ALPHA := 0.55

	var plate: ItemIcon
	var _spawn: Vector2
	var _at: Vector2
	var _live: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = ALPHA
		set_process(true)

	## `from` is where the thing is on screen at the moment it is picked up, so
	## the plate starts exactly over what it came out of rather than appearing
	## already centred somewhere else.
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
		# Frame-rate independent. What is fixed is the fraction closed per
		# SECOND; lerping by a constant per frame makes the whole feel depend on
		# how busy the machine is, which is the one thing it must not do.
		_at = _at.lerp(want, 1.0 - exp(-FOLLOW * delta))
		plate.global_position = _at


## RIGHT-CLICK THROWS IT OVERBOARD, wherever the hold is being shown.
##
## On the base rather than on either icon, because §3.5 rules that jettison
## applies to everything -- a crate of ore and a gun leave the same way.
##
## No confirmation, deliberately. The ruling made this the FORGIVING option:
## what you drop lands in the bag at the system you are in, the sector lists it,
## and you can pick it straight back up. A dialog guarding an action you can undo
## by clicking the thing you just dropped would be asking permission to change
## your mind. The log line says where it went.
func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	var m := held_item()
	if m == null:
		return
	accept_event()
	Run.jettison(m)


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


## A quarter turn, played backwards from where it just was.
##
## Short on purpose — 0.14s. This is an answer, not a flourish: the whole job is
## to say WHICH WAY it turned, because a 1x3 becoming a 3x1 in one frame reads as
## the thing having been swapped for a different one.
func spin() -> void:
	pivot_offset = size * 0.5
	rotation = -PI * 0.5
	var t := create_tween()
	var step := t.tween_property(self, "rotation", 0.0, 0.14)
	step.set_trans(Tween.TRANS_CUBIC)
	step.set_ease(Tween.EASE_OUT)


## Picking one up. The preview is a COPY rather than the icon itself: Godot
## reparents whatever you return, so handing over the live control would tear it
## out of the grid it is sitting in and leave a hole that only closes on the next
## refresh.
##
## The ghost carries the thing's SHAPE, not a square. What you are dragging has
## to look like what will land: the hold is a grid you pack, and a 1x3 gun
## previewed as a 1x1 tile tells you nothing about whether it fits the row you
## are aiming at.
func _get_drag_data(_at: Vector2) -> Variant:
	var m := held_item()
	if m == null:
		return null
	set_drag_preview(_ghost())
	# IT LEAVES THE CELL THE MOMENT YOU LIFT IT.
	#
	# Godot's default is to leave the source control exactly where it was and
	# follow the cursor with a copy, so a dragged part is on screen twice -- in
	# your hand and still in the hold. That reads as previewing a move rather
	# than making one, and it hides the thing you most need to see, which is the
	# hole it came out of.
	#
	# Hidden rather than removed. A drag that is cancelled has to put it back,
	# and the item is still legitimately in `Run.cargo` the whole time it is in
	# the air -- nothing is committed until it lands. `can_place` already skips
	# the item being placed, so the cells it is vacating light as free.
	visible = false
	picked_up.emit(self)
	# `module` is the payload key, and it is the wrong word now that cargo is two
	# kinds of thing. It is kept because every drop site in the game reads it,
	# and renaming a key across four screens to improve a noun is a change with
	# no upside and a long tail of silent misses.
	return {module = m, origin = origin}


## Put back whatever the drag did not consume.
##
## `NOTIFICATION_DRAG_END` reaches every control, dropped on or not, which is
## exactly what is wanted: the icon has to come back whether the drop landed
## somewhere else, was refused, or was let go over nothing. A successful drop
## rebuilds the grid and this icon is freed anyway, so the restore is only ever
## seen in the cases where nothing happened.
func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return
	visible = true
	# AND THE SHAPE IT CAME BACK AS HAS TO FIT WHERE IT CAME FROM.
	#
	# Turning mid-drag flips `turned` on the item itself while it is still in
	# the hold at its old cell, so a drag that does not land leaves a part in a
	# cell its new footprint does not fit. `Run.settle` is the one line that
	# puts that right, and it lives here so every screen with a hold in it gets
	# the same answer -- there are three now and none of them should have to
	# know this happened.
	var m := held_item()
	if m != null:
		Run.settle(m)


## A copy of this icon, sized to its footprint, inside a following wrapper.
## Overridden so each kind builds its own sort of plate.
func _ghost() -> Control:
	return null
