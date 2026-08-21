class_name ModuleCell
extends PanelContainer

## A place a module can sit, and be dropped onto.
##
## Two kinds — a hardpoint and a storage square — because they differ only in
## what they ACCEPT and what happens on arrival, and building two controls to
## express that would have been two copies of the same drag plumbing.
##
## A hardpoint knows its slot type and refuses anything else. That refusal is
## the point: you find out a system will not go in a weapon mount by the cell
## saying so the moment you pick the part up, before you have gone looking for
## somewhere to put it.

enum Kind { HARDPOINT, STORAGE }

const PAD := 2

var kind: Kind = Kind.STORAGE
## HARDPOINT only: what this mount takes.
var slot: ModuleData.Slot = ModuleData.Slot.WEAPON
## HARDPOINT only: WHICH mount of that type this is, counting from 0.
##
## A mount is a place on the physical hull — weapon 0 is the dorsal ordnance,
## weapon 1 the ventral barrels — so the cell has to carry its number through to
## the module that lands on it. Storage squares are interchangeable and leave it
## at -1.
var index: int = -1
## WHICH CELL of the hold grid this is, for STORAGE. (-1,-1) on a hardpoint.
##
## Storage squares stopped being interchangeable when the hold became a grid: a
## part is put down SOMEWHERE, and dropping it on the cell under the cursor is
## the difference between arranging a hold and merely filling one.
var cell: Vector2i = -Vector2i.ONE
## What is sitting here, if anything.
var held: ModuleData = null

var _refuse: Refuse = null

## Emitted when something is dropped on this cell. The screen owns every state
## change; a cell knows where a part came from and where it landed and nothing
## about installing.
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
		# The icon must not eat the drop. It is the thing you PICK UP; the cell
		# under it is the thing you drop ONTO, and a child with STOP would take
		# the hover and leave the cell unable to say whether it accepts.
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(icon)
	elif k == Kind.HARDPOINT:
		add_child(Pad.new(idx))

	# Always last, so it paints over the icon. PanelContainer lays every child
	# into the same content rect and draws them in order, which is the whole
	# reason this works without a CanvasLayer.
	_refuse = Refuse.new()
	add_child(_refuse)

func _style(hot: bool) -> void:
	var bg := Color("#0e141d")
	var edge := UITheme.LINE
	if hot:
		edge = UITheme.HOT
		bg = Color("#1d2a1e")
	add_theme_stylebox_override("panel", UITheme.flat(bg, edge, 0, PAD, PAD))

## Would this cell take that part?
func _accepts(m: ModuleData) -> bool:
	if m == null:
		return false
	if kind == Kind.HARDPOINT:
		return m.slot == slot
	return true

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("module"):
		return false
	var ok := _accepts(data.module as ModuleData)
	# Light the cell only while it would actually take the thing. Godot calls
	# this on every frame the cursor is over us, so it doubles as the hover
	# signal and there is no second place for the two to disagree.
	_style(ok)
	return ok

func _notification(what: int) -> void:
	# Godot gives no "drag left me" callback, so the highlight is cleared when
	# the mouse leaves and when any drag anywhere ends. Without the second one a
	# cell stays lit after a drop that landed somewhere else.
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_style(false)
	# DRAG_BEGIN fires on EVERY control in the tree, which is what makes the
	# refusal marks appear across the whole rack at once. _can_drop_data cannot
	# do it — Godot only calls that on the one cell under the cursor, so you
	# would have to go and ask each mount in turn whether it wanted the thing.
	if what == NOTIFICATION_DRAG_BEGIN and _refuse != null:
		var data: Variant = get_viewport().gui_get_drag_data()
		var m: ModuleData = null
		if typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("module"):
			m = (data as Dictionary).module
		_refuse.visible = m != null and not _accepts(m)
		_refuse.queue_redraw()
	elif what == NOTIFICATION_DRAG_END and _refuse != null:
		_refuse.visible = false

func _drop_data(_at: Vector2, data: Variant) -> void:
	_style(false)
	dropped.emit(data as Dictionary, self)


## The ember outline of a free hardpoint, at the SIZE OF AN ICON.
##
## It used to be the cell's own stylebox border, which made every empty mount
## read visibly larger than a filled one: the panel is 48px and its content rect
## is 44px, so a fitted module showed a 44px plate inset inside the border while
## an empty mount showed the 48px border itself. Same cell, two apparent sizes,
## and the empty ones looked inflated. Drawing the outline as a CHILD puts it in
## the content rect, which is exactly where the icon would be.
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
		# The mount's number, dim, in the middle. Mounts are places on the hull
		# rather than a queue, so the player has to be able to say "the gun goes
		# on 2" and see which square that is.
		var f := UITheme.pixel_font()
		var txt := str(index + 1)
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UITheme.FS_SMALL).x
		draw_string(f, Vector2((size.x - w) * 0.5, size.y * 0.5 + 4.0), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, UITheme.LINE)


## A cross over a cell that will not take what you are holding.
##
## Shown the instant a drag starts, on every cell that refuses, so the answer to
## "where can this go" is the whole board rather than one square at a time.
class Refuse extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.04, 0.02, 0.03, 0.66), true)
		var c := Color("#d4614f")
		# Drawn with lines rather than rects because it is the one diagonal in
		# the whole interface, and that is what makes it read as a refusal
		# instead of as another piece of chrome.
		var inset := 11.0
		draw_line(r.position + Vector2(inset, inset),
			r.end - Vector2(inset, inset), c, 2.0)
		draw_line(r.position + Vector2(r.size.x - inset, inset),
			r.position + Vector2(inset, r.size.y - inset), c, 2.0)
