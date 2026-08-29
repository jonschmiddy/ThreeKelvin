class_name SalvageGrid
extends Control

## What is loose out here, laid out as a grid you reach into.
##
## The other half of `HoldGrid`, and deliberately a different thing. Your hold
## is a PACKING PUZZLE -- every item has a cell you chose, it is remembered
## across jumps, and the whole game of it is deciding what fits. A wreck is not
## a puzzle. Nobody arranged it. It is a pile, and the only question it asks is
## which of these you want.
##
## So this grid places things itself, first-fit, and never stores where it put
## them. Rearranging the inside of a wreck is not a decision anybody wants to
## make, and letting you would imply it mattered.
##
## Same 40-pixel cell and same lattice as the hold beside it, because the whole
## point of showing them together is that a shape means the same thing on both
## sides -- a 2x2 that will not go in your hold is a 2x2 you can see will not go.
##
## `MATERIALS_NOTE` 3.6: every physical grant is a container, not an item. This
## is that container. A kill fills one, an event hands you one, and what you
## jettison lands in one.

signal picked(item: HoldItem)

const CELL := HoldGrid.CELL
const EDGE := 2.0

var _cols: int = 5
var _rows: int = 1
var _items: Array = []
## Where this grid decided to draw each item. Index-matched to `_items`, and
## thrown away on every rebuild -- see the note above about not remembering.
var _cells: Array[Vector2i] = []
## Which entries are spoken for. A bag row someone already claimed still takes
## up space in the picture, because a hole where a part was is information and
## a silently reflowed grid is not.
var _spent: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


## `spent` holds the indices already claimed -- they draw greyed and cannot be
## picked up. `cols` is how wide the container reads; the rows follow from what
## has to fit.
func setup(items: Array, spent: Dictionary, cols: int = 5) -> void:
	_items = items
	_spent = spent
	_cols = maxi(1, cols)
	_layout()
	_rebuild()


## First fit, largest first, which is the same rule `RunState.reseat` uses and
## for the same reason: first-fit on a fresh grid strands big things behind
## small ones, and a 4x1 that cannot find a row is a 4x1 you cannot see.
func _layout() -> void:
	_cells.clear()
	_cells.resize(_items.size())
	var order: Array[int] = []
	for i in _items.size():
		order.append(i)
		_cells[i] = -Vector2i.ONE
	order.sort_custom(func(a: int, b: int) -> bool:
		return (_items[a] as HoldItem).cells() > (_items[b] as HoldItem).cells())

	var taken: Dictionary = {}
	_rows = 1
	for i in order:
		var m: HoldItem = _items[i]
		var f := m.footprint()
		var at := _first_fit(taken, f)
		_cells[i] = at
		for dy in f.y:
			for dx in f.x:
				taken[at + Vector2i(dx, dy)] = true
		_rows = maxi(_rows, at.y + f.y)
	custom_minimum_size = Vector2(_cols * CELL, _rows * CELL)
	size = custom_minimum_size


## Scans down as far as it needs to. The container has no floor -- unlike a hold,
## which is a fixed box, a pile is however big the pile is, and refusing to show
## the last item because a number ran out would be inventing a rule.
func _first_fit(taken: Dictionary, f: Vector2i) -> Vector2i:
	var y := 0
	while y < 256:
		for x in maxi(1, _cols - f.x + 1):
			var at := Vector2i(x, y)
			var ok := true
			for dy in f.y:
				for dx in f.x:
					if taken.has(at + Vector2i(dx, dy)):
						ok = false
						break
				if not ok:
					break
			if ok:
				return at
		y += 1
	return Vector2i(0, 0)


func _rebuild() -> void:
	Widgets.clear(self)
	for i in _items.size():
		var m: HoldItem = _items[i]
		var icon: ItemIcon
		if m is MaterialData:
			var mi := MaterialIcon.new()
			mi.setup(m as MaterialData, &"bag")
			icon = mi
		else:
			var gi := ModuleIcon.new()
			gi.setup(m as ModuleData, &"bag")
			icon = gi
		# `bag`, not `cargo`, and this is the whole wiring. The drop site reads
		# it to know that taking this costs a CLAIM -- one bag, first hand in --
		# rather than being a free rearrangement of something you already own.
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(icon)
		icon.custom_minimum_size = Vector2.ZERO
		icon.position = Vector2(_cells[i].x * CELL, _cells[i].y * CELL)
		icon.size = ModuleIcon.footprint_box(m)
		if _spent.has(i):
			# Still drawn, still in its cell, plainly not yours. See `_spent`.
			icon.modulate = Color(0.42, 0.42, 0.48, 0.7)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.tooltip_text = Widgets.tip("Already taken.")
	queue_redraw()


func _draw() -> void:
	for y in _rows:
		for x in _cols:
			draw_rect(Rect2(Vector2(x * CELL, y * CELL), Vector2(CELL, CELL)),
				Color("#0b1017"), true)
	for x in range(1, _cols):
		draw_line(Vector2(x * CELL, 0.0), Vector2(x * CELL, size.y),
			UITheme.LINE, 1.0)
	for y in range(1, _rows):
		draw_line(Vector2(0.0, y * CELL), Vector2(size.x, y * CELL),
			UITheme.LINE, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.LINE, false, EDGE)


## Which entry an item is, so a claim can name it. Identity, not equality --
## `n.bag` holds the very objects the icons were built from.
func index_of(m: HoldItem) -> int:
	return _items.find(m)


## Dropping one of YOUR things in here is jettison.
##
## The same motion as taking, mirrored, because it is the same idea seen from the
## other end: this is the floor of the system you are standing in, and putting
## something down on it is exactly what `Run.jettison` does. `MATERIALS_NOTE`
## 3.5 makes it apply to everything, so a gun and a crate leave the same way.
##
## Only things you OWN. An item already loose out here has nowhere further to
## fall, and letting it be dragged around inside the pile would suggest the
## arrangement meant something -- see the note at the top.
func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("module"):
		return false
	if String((data as Dictionary).get("origin", &"")) == "bag":
		return false
	var m: HoldItem = (data as Dictionary).module
	return m != null and Run.cargo.has(m)


func _drop_data(_at: Vector2, data: Variant) -> void:
	var m: HoldItem = (data as Dictionary).module
	if m != null and Run.jettison(m):
		picked.emit(m)
