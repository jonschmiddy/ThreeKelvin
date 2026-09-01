class_name ModuleCell
extends PanelContainer

## A place a module can sit, and be dropped onto.
##
## Two kinds — a hardpoint and a storage square — because they differ only in
## what they ACCEPT and what happens on arrival, and building two controls to
## express that would have been two copies of the same drag plumbing.
##
## A hardpoint knows its slot type and takes nothing else. The moment you pick a
## part up, every mount that WILL take it opens a tractor beam — so you find out
## where a system can go before you have gone looking, and the mounts that refuse
## it simply stay dark. See ModuleCell.Tractor for why that is the way round.

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

var _tractor: Tractor = null

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
	_tractor = Tractor.new()
	add_child(_tractor)

func _style(hot: bool) -> void:
	var bg := Color("#0e141d")
	var edge := UITheme.LINE
	if hot:
		edge = UITheme.HOT
		bg = Color("#1d2a1e")
	add_theme_stylebox_override("panel", UITheme.flat(bg, edge, 0, PAD, PAD))

## Would this cell take that part?
## A MOUNT, not a shelf. Materials live in the hold and never bolt to a hull --
## they have no slot, no mount and no power draw -- so this stays typed to
## `ModuleData` on purpose and the drop check below refuses anything else.
## Before materials existed the type was the whole guard; now it has to say so.
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
	# beams appear across the whole rack at once. _can_drop_data cannot do it —
	# Godot only calls that on the one cell under the cursor, so you would have
	# to go and ask each mount in turn whether it wanted the thing.
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


class Tractor extends Control:
	## A mount reaching for the part you are holding.
	##
	## Shown the instant a drag starts, on every cell that ACCEPTS, so the answer
	## to "where can this go" is the whole board rather than one square at a time.
	##
	## REPLACES a red cross on every hardpoint that would refuse it. The cross
	## was the louder signal by a distance — half a dozen of them lit up across
	## the rack the moment you picked anything up, so the screen answered a
	## question nobody asked ("where can this NOT go") in the most emphatic way
	## available, and the one mount that mattered was the only thing not marked.
	##
	## Now the affordance is positive and the refusals are silent: a cell that
	## will take the part opens a beam, and a cell that will not does nothing at
	## all. Same information, inverted, and it points at the answer.
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
		# The pulse rides the ALPHA, never the geometry. A beam that changes
		# width redraws its own edges every frame, and at this scale that reads
		# as the cell jittering rather than as light.
		var pulse := 0.62 + 0.38 * sin(phase)
		var c := UITheme.TRACTOR

		draw_rect(r, Color(c.r, c.g, c.b, 0.10 * pulse), true)

		# A column of light down onto the mount, narrowing as it lands. Drawn as
		# stacked rects rather than a polygon because the whole interface is on
		# a pixel grid and a sloped edge would be the one antialiased thing in
		# it — see the art direction's no-anti-aliasing rule.
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
