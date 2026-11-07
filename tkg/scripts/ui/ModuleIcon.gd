class_name ModuleIcon
extends ItemIcon

## Three channels (maker, grade, use), none needing a word; the glyph shares the card's art.
## Why: docs/why/ModuleIcon.md#module-icon

const SIZE := 44

## Clear space inside the cell, applied in `part_scale` so the hull inherits it.
const PAD := 4.0

## Measured 0.82: 0.88 crushed the grades into one band, 0.80 leaves no colour margin.
## The 3.0:1 legibility floor (Verity's gold binds) is held by `-- holdtest`.
## Why: docs/why/ModuleIcon.md#plate-ground
const GROUND := 0.82

## Cells are authored at 2x; where the ship draws smaller the cells must scale with it.
## Why: docs/why/ModuleIcon.md#hold-magnification
const HOLD_K := 2.0

var module: ModuleData
## The part uses the box's own scale, not a hardcoded `HOLD_K` that agreed only by luck.
## Why: docs/why/ModuleIcon.md#part-scale
var plate_scale: float = HOLD_K
## The part alone, for shelves, where a boxed plate looks like a slot stuck to furniture.
var bare := false
## Where a drag from here would be taking it FROM. The drop target needs to know
## whether this is a refit or an install.

## Both drag sources use this, so a part is carried as the same object at the same size.
static func ghost_for(m: ModuleData, from: StringName, at: Vector2) -> Control:
	var g := ModuleIcon.new()
	g.setup(m, from)
	return ItemIcon.wrap_ghost(g, at)


func held_item() -> HoldItem:
	return module


func _ghost() -> Control:
	return ghost_for(module, origin, global_position)



func setup(m: ModuleData, from: StringName) -> void:
	module = m
	origin = from
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = _hint()
	queue_redraw()

## A Control showing the part and its cards, not a string.
## Uses `resolved_cards()` so what is drawn is what the deck gets (Grant Count Law).
## Why: docs/why/ModuleIcon.md#tooltip
func _make_custom_tooltip(_for_text: String) -> Object:
	if module == null:
		return null
	return tip_for(module)


## Shared with LOCAL's cutaway hover card so the two cannot drift.
static func tip_for(module: ModuleData) -> Control:
	var row := HBoxContainer.new()
	row.set_meta(&"module", module)
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Widgets.module_readout(module))
	for c in module.resolved_cards():
		var v := CardView.new()
		v.setup(c, false, 1)
		# IGNORE, not STOP: a tooltip that eats the mouse counts as leaving what you point at.
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(v)
	return row


## Godot asks for a tooltip only when `tooltip_text` is non-empty, so this arms it.
func _hint() -> String:
	if module == null:
		return ""
	return module.name


## Drawn to the control's own size, as a 1x3 gun is the same icon at another footprint.
## Why: docs/why/ModuleIcon.md#draw-size
func _draw() -> void:
	if bare and module != null:
		var mf: ManufacturerData = DB.manufacturers.get(module.manufacturer)
		draw_body(self, module, Rect2(Vector2.ZERO, size),
			mf.colour if mf != null else UITheme.COLD, Vector2i.ZERO, false,
			plate_scale)
		return
	draw_plate(self, module, Rect2(Vector2.ZERO, size), Vector2i.ZERO,
		false, plate_scale)

## Static and rect-taking so the hull draws the identical part at the identical size.
## `cells` stops the hull standing a gun on end just because the hold turned it.
## Why: docs/why/ModuleIcon.md#drawing-a-part
static func draw_plate(ci: CanvasItem, m: ModuleData, r: Rect2,
		cells := Vector2i.ZERO, mirror: bool = false,
		scale: float = HOLD_K) -> void:
	if m == null:
		return
	var manufacturer: ManufacturerData = DB.manufacturers.get(m.manufacturer)
	var mark: Color = manufacturer.colour if manufacturer != null else UITheme.COLD
	var rar := ModuleData.rarity_colour(m.rarity)
	# Rarity is the ground, darkened to a tint, so plates sort by quality at a glance.
	ci.draw_rect(r, rar.lerp(UITheme.VOID, GROUND), true)

	# A bet that generated art will show the maker, so no stripe. Revisit if it does not.
	# Why: docs/why/ModuleIcon.md#manufacturer-as-art

	# Drawn at the size the hull draws it, via `part_scale` on the same box (was min(w, h) / 26).
	# Why: docs/why/ModuleIcon.md#silhouette-size
	var f := m.footprint() if cells == Vector2i.ZERO else cells
	# The art is the rarity, not the maker, which the field already says.
	draw_body(ci, m, r, mark, f, mirror, scale)

	# The edge is the ink: a contraband ground is darker than the screen, so only the edge shows.
	var e := ModuleData.rarity_ink(m.rarity)
	var p := r.position
	var z := r.size
	for side in [Rect2(p, Vector2(z.x, 1)), Rect2(p + Vector2(0, z.y - 1), Vector2(z.x, 1)),
			Rect2(p, Vector2(1, z.y)), Rect2(p + Vector2(z.x - 1, 0), Vector2(1, z.y))]:
		ci.draw_rect(side, e, true)

## One door for hull and hold to choose sprite or silhouette, so the two cannot drift.
## Why: docs/why/ModuleIcon.md#part-drawing
static func draw_body(ci: CanvasItem, m: ModuleData, box: Rect2, col: Color,
		cells := Vector2i.ZERO, mirror: bool = false, scale: float = 1.0) -> void:
	if m == null:
		return
	var f := m.footprint() if cells == Vector2i.ZERO else cells
	if m.sprite != null:
		draw_sprite(ci, m.sprite, box, mirror, scale, sprite_turn(m.sprite, f))
		return
	fill_part(ci, m.slot, box, col, part_scale(m.slot, f, box.size),
		part_turn(m.slot, f), mirror)


## Scale comes from the view as a whole multiple, never fitted to the box.
## `upright` stands it on end like the silhouette path, or art hung out over neighbours.
## Why: docs/why/ModuleIcon.md#sprite-drawing
static func draw_sprite(ci: CanvasItem, tex: Texture2D, box: Rect2,
		mirror: bool = false, scale: float = 1.0, upright: bool = false) -> void:
	var src := Vector2(tex.get_size())
	if src.x < 1.0 or src.y < 1.0:
		return
	var k := maxi(1, int(roundf(scale)))
	var dst := src * float(k)
	var cy := box.get_center().y
	if not upright:
		var r := Rect2((box.position + (box.size - dst) * 0.5).round(), dst)
		# Mirrored about the BOX's middle, the same line `fill_part` reflects the
		# silhouette about, so a flipped part lands in the same place either way.
		if mirror:
			ci.draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0),
				Vector2(0.0, -1.0), Vector2(0.0, cy * 2.0)))
		ci.draw_texture_rect(tex, r, false)
		if mirror:
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		return

	# Anticlockwise to match `draw_part`, or art and silhouette disagree. Mirror composes after.
	# Why: docs/why/ModuleIcon.md#sprite-turning
	var c := box.get_center().round()
	var t := Transform2D(-PI * 0.5, c)
	if mirror:
		t = Transform2D(Vector2(1.0, 0.0), Vector2(0.0, -1.0),
			Vector2(0.0, cy * 2.0)) * t
	ci.draw_set_transform_matrix(t)
	# Drawn about the ORIGIN, because the transform carries it to the box.
	ci.draw_texture_rect(tex, Rect2((-dst * 0.5).round(), dst), false)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## One function for hold and hull. `mirror_y` is a parameter as `draw_set_transform` replaces.
## Why: docs/why/ModuleIcon.md#silhouette
static func draw_part(ci: CanvasItem, slot: ModuleData.Slot, at: Vector2,
		col: Color, s: float = 1.0, upright: bool = false,
		mirror_y: float = INF) -> void:
	var dark := col.lerp(Color("#0a0e13"), 0.55)
	var lite := col.lerp(Color.WHITE, 0.3)
	# Drawn about the origin and moved by a transform; a quarter turn anticlockwise stands it up.
	var t := Transform2D(-PI * 0.5 if upright else 0.0, at)
	if mirror_y != INF:
		t = Transform2D(Vector2(1.0, 0.0), Vector2(0.0, -1.0),
			Vector2(0.0, mirror_y * 2.0)) * t
	ci.draw_set_transform_matrix(t)
	match slot:
		ModuleData.Slot.WEAPON:
			ci.draw_rect(Rect2(-4.0 * s, -2.5 * s, 9.0 * s, 5.0 * s), dark, true)
			ci.draw_rect(Rect2(-4.0 * s, -2.5 * s, 9.0 * s, 1.0 * s), lite, true)
			ci.draw_rect(Rect2(5.0 * s, -1.0 * s, 7.0 * s, 2.0 * s), col, true)
			ci.draw_rect(Rect2(12.0 * s, -1.0 * s, 2.0 * s, 2.0 * s), UITheme.VOID, true)
		ModuleData.Slot.SYSTEM:
			ci.draw_rect(Rect2(-5.5 * s, -2.0 * s, 11.0 * s, 4.0 * s), dark, true)
			ci.draw_rect(Rect2(-5.5 * s, -2.0 * s, 11.0 * s, 1.0 * s), col, true)
			ci.draw_rect(Rect2(-3.5 * s, 0.0, 3.0 * s, 1.0 * s), lite, true)
		_:
			ci.draw_rect(Rect2(-1.5 * s, -3.5 * s, 3.0 * s, 7.0 * s), dark, true)
			ci.draw_rect(Rect2(-0.5 * s, -6.5 * s, 1.0 * s, 4.0 * s), col, true)
			ci.draw_rect(Rect2(-0.5 * s, -7.5 * s, 1.0 * s, 1.0 * s), lite, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## One function for the box a part occupies, so hold, hull and drag ghost agree.
## Same arithmetic as `MountPoints.part_rect`, or a part differs between gallery and ship.
## Why: docs/why/ModuleIcon.md#part-box
static func footprint_box(m: HoldItem, k: float = HOLD_K) -> Vector2:
	var f := m.footprint()
	var q := k / HOLD_K
	var step := (float(HoldGrid.CELL) + float(HoldGrid.GAP)) * q
	return Vector2(f) * step - Vector2(HoldGrid.GAP, HoldGrid.GAP) * q


## Silhouette size unscaled, read off the rectangles below, so change both together.
static func part_extent(slot: ModuleData.Slot) -> Vector2:
	match slot:
		ModuleData.Slot.WEAPON: return Vector2(18.0, 5.0)
		ModuleData.Slot.SYSTEM: return Vector2(11.0, 4.0)
		_: return Vector2(3.0, 11.0)


## Not zero: a weapon is drawn from its breech, so centring the origin hung barrels out.
## Why: docs/why/ModuleIcon.md#part-offset
static func part_offset(slot: ModuleData.Slot) -> Vector2:
	match slot:
		ModuleData.Slot.WEAPON: return Vector2(5.0, 0.0)
		ModuleData.Slot.SYSTEM: return Vector2.ZERO
		_: return Vector2(0.0, -2.0)


## The one way to centre a silhouette; the box centre is wrong for asymmetric shapes.
## Why: docs/why/ModuleIcon.md#filling-a-box
static func fill_part(ci: CanvasItem, slot: ModuleData.Slot, box: Rect2,
		col: Color, s: float, upright: bool, mirror: bool = false) -> void:
	# Mirror about the box's middle, not the draw origin, or the gun slides out of its plate.
	var my := box.get_center().y if mirror else INF
	draw_part(ci, slot, part_origin(slot, box, s, upright), col, s, upright, my)


## Not the box centre: the bounding box sits five units ahead of the breech.
## Split out so a test can ask where the ink will go.
## Why: docs/why/ModuleIcon.md#part-origin
static func part_origin(slot: ModuleData.Slot, box: Rect2, s: float,
		upright: bool) -> Vector2:
	var off := part_offset(slot) * s
	# `draw_part` turns anticlockwise about its origin, so the offset turns too.
	if upright:
		off = Vector2(off.y, -off.x)
	return (part_rect(slot, box, s, upright).get_center() - off).round()


## Separate from `fill_part` so a test can assert where the ink lands.
## Why: docs/why/ModuleIcon.md#part-origin
static func part_rect(slot: ModuleData.Slot, box: Rect2, s: float,
		upright: bool) -> Rect2:
	var ext := part_extent(slot) * s
	if upright:
		ext = Vector2(ext.y, ext.x)
	return Rect2((box.get_center() - ext * 0.5).round(), ext)


## Guns bolt on at the breech, systems at their middle. It follows the anticlockwise turn.
## Why: docs/why/ModuleIcon.md#mount-anchor
static func mount_anchor(slot: ModuleData.Slot, box: Vector2, upright: bool,
		cell: float = float(HoldGrid.CELL)) -> Vector2:
	if slot != ModuleData.Slot.WEAPON:
		return box * 0.5
	var half := cell * 0.5
	return Vector2(box.x * 0.5, box.y - half) if upright 		else Vector2(half, box.y * 0.5)


## Matches long axis to long axis, as weapons are authored long across and masts long down.
## Why: docs/why/ModuleIcon.md#part-turning
static func part_turn(slot: ModuleData.Slot, f: Vector2i) -> bool:
	if f.x == f.y:
		return false
	var nat := part_extent(slot)
	return (f.y > f.x) != (nat.y > nat.x)


## For sprites the art's own shape decides, as the slot says nothing about a given PNG.
## Why: docs/why/ModuleIcon.md#part-turning
static func sprite_turn(tex: Texture2D, f: Vector2i) -> bool:
	if tex == null or f.x == f.y:
		return false
	var s := Vector2(tex.get_size())
	if s.x == s.y:
		return false
	return (f.y > f.x) != (s.y > s.x)


## Fractional on purpose: these are rectangles computed at draw time, not a bitmap.
## Why: docs/why/ModuleIcon.md#part-scale
static func part_scale(slot: ModuleData.Slot, f: Vector2i, box: Vector2) -> float:
	var nat := part_extent(slot)
	if part_turn(slot, f):
		nat = Vector2(nat.y, nat.x)
	var room := Vector2(maxf(4.0, box.x - PAD * 2.0), maxf(4.0, box.y - PAD * 2.0))
	return maxf(0.35, minf(room.x / nat.x, room.y / nat.y))

## Drawn from the first card, not authored per module, which would drift from its effects.
func _glyph(mark: Color) -> void:
	var kind := &"utility"
	if not module.cards.is_empty():
		kind = (module.cards[0] as CardData).glyph_kind()
	var c := Vector2(size.x * 0.5 + 1.0, size.y * 0.5)
	var ink := mark.lightened(0.25)
	var dim := mark.darkened(0.35)
	match kind:
		&"slug":
			# A barrel and its muzzle flash. One shot.
			draw_rect(Rect2(c + Vector2(-11, -2), Vector2(15, 5)), ink, true)
			draw_rect(Rect2(c + Vector2(4, -5), Vector2(3, 11)), dim, true)
			draw_rect(Rect2(c + Vector2(7, -2), Vector2(4, 5)), ink, true)
		&"burst":
			# Three muzzles: at 44px there is no room to count, so it says more than one.
			for i in 3:
				draw_rect(Rect2(c + Vector2(-11, -8 + i * 6), Vector2(13, 3)), ink, true)
				draw_rect(Rect2(c + Vector2(4, -8 + i * 6), Vector2(4, 3)), dim, true)
		&"pyre":
			# A barrel fed from the reactor. The one weapon lit from inside.
			draw_rect(Rect2(c + Vector2(-11, -2), Vector2(15, 5)), ink, true)
			draw_rect(Rect2(c + Vector2(-7, -1), Vector2(8, 3)), UITheme.FLARE, true)
			draw_rect(Rect2(c + Vector2(4, -4), Vector2(5, 9)), UITheme.HOT, true)
		&"charge":
			# A capacitor filling: three bars, the last one lit.
			for i in 3:
				var h := 4 + i * 4
				draw_rect(Rect2(c + Vector2(-9 + i * 7, 6 - h), Vector2(5, h)),
					ink if i == 2 else dim, true)
		&"drone":
			# A carrier and the thing it launched.
			draw_rect(Rect2(c + Vector2(-11, -1), Vector2(10, 7)), dim, true)
			draw_rect(Rect2(c + Vector2(2, -8), Vector2(6, 6)), ink, true)
			draw_rect(Rect2(c + Vector2(4, -2), Vector2(2, 3)), ink, true)
		&"brace":
			# A plate with a bevel. Whole, because Brace is a wall you keep.
			draw_rect(Rect2(c + Vector2(-8, -9), Vector2(16, 15)), dim, true)
			draw_rect(Rect2(c + Vector2(-8, -9), Vector2(16, 3)), ink, true)
			draw_rect(Rect2(c + Vector2(-8, -9), Vector2(3, 15)), ink, true)
		&"block":
			# The same footprint, SEGMENTED. Gaps say it falls down at the end of
			# the turn, which is the one distinction that decides a defensive turn.
			for i in 3:
				draw_rect(Rect2(c + Vector2(-8, -9 + i * 6), Vector2(16, 4)),
					ink if i == 1 else dim, true)
		&"feedback":
			# A wall, and a round leaving it.
			draw_rect(Rect2(c + Vector2(-10, -9), Vector2(6, 17)), ink, true)
			draw_rect(Rect2(c + Vector2(0, -2), Vector2(7, 4)), dim, true)
			draw_rect(Rect2(c + Vector2(7, -1), Vector2(4, 2)), UITheme.HOT, true)
		&"slip":
			# The gap the shot goes through.
			draw_rect(Rect2(c + Vector2(-9, -10), Vector2(5, 7)), dim, true)
			draw_rect(Rect2(c + Vector2(-9, 3), Vector2(5, 7)), dim, true)
			draw_rect(Rect2(c + Vector2(-1, -2), Vector2(11, 3)), ink, true)
		&"vent":
			# Heat leaving through slats.
			draw_rect(Rect2(c + Vector2(-10, 2), Vector2(20, 5)), dim, true)
			for i in 3:
				draw_rect(Rect2(c + Vector2(-8 + i * 7, -9), Vector2(4, 10)), ink, true)
		&"repair":
			# A seam and the weld across it.
			draw_rect(Rect2(c + Vector2(-9, -7), Vector2(19, 13)), dim, true)
			draw_rect(Rect2(c + Vector2(-2, -10), Vector2(5, 19)), ink, true)
			draw_rect(Rect2(c + Vector2(-9, -2), Vector2(19, 4)), ink, true)
		&"lock":
			# The four corners are written out: a loop pointed the lower brackets wrong.
			# Why: docs/why/ModuleIcon.md#reticle-glyph
			var arm := Vector2(6, 2)
			var leg := Vector2(2, 6)
			draw_rect(Rect2(c + Vector2(-11, -11), arm), ink, true)   ## top left
			draw_rect(Rect2(c + Vector2(-11, -11), leg), ink, true)
			draw_rect(Rect2(c + Vector2(5, -11), arm), ink, true)     ## top right
			draw_rect(Rect2(c + Vector2(9, -11), leg), ink, true)
			draw_rect(Rect2(c + Vector2(-11, 9), arm), ink, true)     ## bottom left
			draw_rect(Rect2(c + Vector2(-11, 5), leg), ink, true)
			draw_rect(Rect2(c + Vector2(5, 9), arm), ink, true)       ## bottom right
			draw_rect(Rect2(c + Vector2(9, 5), leg), ink, true)
			draw_rect(Rect2(c + Vector2(-1, -1), Vector2(3, 3)), UITheme.HOT, true)
		&"draw":
			# Cards, one lifted.
			draw_rect(Rect2(c + Vector2(-10, -3), Vector2(9, 12)), dim, true)
			draw_rect(Rect2(c + Vector2(-5, -6), Vector2(9, 12)), dim, true)
			draw_rect(Rect2(c + Vector2(0, -10), Vector2(9, 13)), ink, true)
		&"power":
			# A cell with a charge in it.
			draw_rect(Rect2(c + Vector2(-7, -9), Vector2(14, 18)), dim, true)
			draw_rect(Rect2(c + Vector2(-2, -6), Vector2(4, 6)), UITheme.FLARE, true)
			draw_rect(Rect2(c + Vector2(-2, 1), Vector2(4, 6)), UITheme.HOT, true)
		&"scrip":
			# Stacked notes.
			for i in 3:
				draw_rect(Rect2(c + Vector2(-9 + i * 2, -7 + i * 5), Vector2(16, 4)),
					ink if i == 2 else dim, true)
		&"malfunction":
			# A crack. Nothing else in the set is diagonal.
			for i in 5:
				draw_rect(Rect2(c + Vector2(-8 + i * 4, -8 + i * 3), Vector2(4, 3)),
					ink, true)
		_:
			# A housing with a fitting on it: an unclassified part.
			draw_rect(Rect2(c + Vector2(-9, -6), Vector2(17, 12)), dim, true)
			draw_rect(Rect2(c + Vector2(-5, -3), Vector2(9, 6)), ink, true)
			draw_rect(Rect2(c + Vector2(8, -2), Vector2(4, 4)), dim, true)
