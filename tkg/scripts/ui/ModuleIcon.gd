class_name ModuleIcon
extends Control

## A module as a thing you can pick up.
##
## Inventory-grid icon, in the vein of Arc Raiders or Marathon: a plate in the
## manufacturer's field colour, a rarity edge, and a glyph saying what the part
## DOES. Three channels, three questions — whose is it, how good is it, what is
## it for — and none of them requires reading a word.
##
## The glyph comes from the module's own first card via CardData.glyph_kind(),
## which is the same classification the card face draws its art from. So a
## weapon that fires and a weapon that charges look different here for exactly
## the reason they look different in your hand, and neither is a second opinion
## about what the module is.

const SIZE := 44

## Clear space between a part's art and the edge of the cell it occupies, on
## every side. The silhouette used to be scaled to fill the plate exactly, so it
## pressed against the rarity border on at least one axis and the two read as
## one shape. Applied inside `part_scale`, so the HULL inherits it — a part is
## one size in both places and padding only one of them would break that.
const PAD := 4.0

## How far a rarity colour is dragged toward the void to make a plate's ground.
##
## MEASURED, not picked. The art on that ground is the house's own colour now, so
## every manufacturer has to stay legible on every rarity — 49 pairings, and the
## worst of them is Verity's sand on the two green rarities. At 0.80 that pair
## comes out at 2.94:1, under the 3.0 that WCAG asks of a graphical object; 0.88
## puts the floor at 3.48 while the ground is still plainly tinted. `-- holdtest`
## holds the line, because a new manufacturer colour is the thing that breaks it.
const GROUND := 0.88

## The magnification the hold's cells are authored at.
##
## The refit screen draws the ship at 2x and a cell is 30px, which is what makes
## a part the same size in the grid as it is bolted on. Anywhere the ship is
## drawn at a different magnification — the sector strip drops to 1x while a
## party is on screen — the cells have to come with it, or a part on a small
## ship is drawn twice the size it should be relative to the hull carrying it.
const HOLD_K := 2.0

var module: ModuleData
## Where a drag from here would be taking it FROM. The drop target needs to know
## whether this is a refit or an install.
var origin: StringName = &"cargo"

signal picked_up(icon: ModuleIcon)

## The preview currently under the cursor, or null.
##
## STATIC because Godot takes ownership of whatever `set_drag_preview` is handed
## and offers no way to ask for it back — and turning a part while you are
## carrying it has to resize the thing you are looking at, not just the record.
static var carried: ModuleIcon = null


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
## the middle over a few frames, and a fast flick leaves the plate trailing
## until the mouse stops, at which point it catches up and centres.
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

	var plate: ModuleIcon
	var _spawn: Vector2
	var _at: Vector2
	var _live: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = ALPHA
		set_process(true)

	## `from` is where the part is on screen at the moment it is picked up, so
	## the plate starts exactly over the thing it came out of rather than
	## appearing already centred somewhere else.
	func start(p: ModuleIcon, from: Vector2) -> void:
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


## The preview for a part being picked up, wherever it was picked up FROM.
## Both drag sources call this, so a lance leaving the hold and the same lance
## coming off the hull are carried as the same object at the same size.
static func ghost_for(m: ModuleData, from: StringName, at: Vector2) -> Control:
	var g := ModuleIcon.new()
	g.setup(m, from)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.fit_footprint()
	carried = g
	var wrap := Ghost.new()
	wrap.start(g, at)
	return wrap


## Size to the part's CURRENT shape, in the hold's own cells.
func fit_footprint() -> void:
	if module == null:
		return
	var f := footprint_box(module)
	custom_minimum_size = f
	size = f
	pivot_offset = f * 0.5
	queue_redraw()


## A quarter turn, played backwards from where it just was.
##
## Short on purpose — 0.14s. This is an answer, not a flourish: the whole job is
## to say WHICH WAY it turned, because a 1x3 becoming a 3x1 in one frame reads
## as the part having been swapped for a different one.
func spin() -> void:
	pivot_offset = size * 0.5
	rotation = -PI * 0.5
	var t := create_tween()
	var step := t.tween_property(self, "rotation", 0.0, 0.14)
	step.set_trans(Tween.TRANS_CUBIC)
	step.set_ease(Tween.EASE_OUT)

func setup(m: ModuleData, from: StringName) -> void:
	module = m
	origin = from
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = _hint()
	queue_redraw()

func _hint() -> String:
	if module == null:
		return ""
	var lines := "%s\n%s · %s" % [module.name.to_upper(),
		ModuleData.rarity_name(module.rarity).to_upper(),
		ModuleData.slot_name(module.slot).to_upper()]
	if module.manufacturer != &"":
		lines += "\n%s" % DB.manufacturer_name(module.manufacturer)
	for c in module.resolved_cards():
		lines += "\n· %s" % c.describe()
	if not module.affixes.is_empty():
		for a in module.affixes:
			lines += "\n+ %s (%s)" % [a.name, a.text]
	return lines

## Picking one up. The preview is a copy of the icon rather than the icon
## itself: Godot reparents whatever you return, so handing over the live control
## would tear it out of the grid it is sitting in and leave a hole that only
## closes on the next refresh.
func _get_drag_data(_at: Vector2) -> Variant:
	if module == null:
		return null
	# The ghost carries the part's SHAPE, not a square. What you are dragging
	# has to look like what will land: the hold is a grid you pack, and a 1x3
	# gun previewed as a 1x1 tile tells you nothing about whether it will fit
	# in the row you are aiming at.
	set_drag_preview(ghost_for(module, origin, global_position))
	picked_up.emit(self)
	return {module = module, origin = origin}

## Drawn to the control's OWN size, not to SIZE.
##
## A 1x1 fitting and a 1x3 gun are the same icon at different footprints once
## the hold is a grid, so the plate, the house stripe and the rarity border all
## measure themselves off `size`. Every existing use is a 44x44 cell and is
## unchanged by this; the glyph was already centre-relative.
func _draw() -> void:
	draw_plate(self, module, Rect2(Vector2.ZERO, size))

## A PART, WHOLE, IN A RECTANGLE — plate, house stripe, silhouette and rarity
## edge. Static and rect-taking so the HULL can draw the identical thing at the
## identical size, which is the entire point: a 1x3 lance in the hold and the
## same lance bolted to the ship should be one object that moved, not two
## drawings that happen to share a colour.
##
## It used to be only the silhouette that was shared, and a hardpoint drew that
## at a fixed size whatever the part was — so a 1x1 sight and a 1x3 rail were
## the same mark on the hull, and the shape you packed the hold around vanished
## the moment you fitted it.
static func draw_plate(ci: CanvasItem, m: ModuleData, r: Rect2) -> void:
	if m == null:
		return
	var maker: ManufacturerData = DB.manufacturers.get(m.manufacturer)
	var mark: Color = maker.colour if maker != null else UITheme.COLD
	var rar := ModuleData.rarity_colour(m.rarity)
	# RARITY IS THE GROUND the part sits on — the whole plate, darkened until it
	# is a tint rather than a colour, so five plates side by side sort by
	# quality before anything is read.
	ci.draw_rect(r, rar.lerp(UITheme.VOID, GROUND), true)

	# AND THE HOUSE IS THE ART. Which is a bet on what the art is going to be:
	# a generated Korvan gun and a generated Solari gun will not need a stripe
	# to tell them apart, any more than the hulls do. Until those exist the
	# silhouette is drawn in the house's own colour, which is the same claim
	# made with the one channel a rectangle has.
	#
	# It cost a stripe, and that is the point of writing it down: the stripe was
	# a reliable answer that does not depend on art that has not been made yet.
	# If the generated parts turn out not to read as their house, this is the
	# commit to come back to.

	# The silhouette, at THE SAME SIZE THE HULL DRAWS IT and standing whichever
	# way the part is currently packed. Both call part_scale against the same
	# box — a footprint in the hold's own cells — so the gun you are looking at
	# in the grid is the gun that appears on the ship, not a smaller drawing of
	# it. It was `min(w, h) / 26` here, which made a part in the hold about a
	# third of the size of the same part bolted on.
	var f := m.footprint()
	# THE ART IS THE RARITY. It was the manufacturer's colour, which meant the
	# one thing you look at — the shape in the middle of the plate — answered
	# the question you can already answer from the field it is sitting on, and
	# left how good the part is to a one-pixel line.
	fill_part(ci, m.slot, r, mark, part_scale(m.slot, f, r.size),
		part_turn(m.slot, f))

	# THE EDGE IS THE INK, not the ground. Identical for seven grades and the
	# whole plate for the eighth: a contraband ground is darker than the screen,
	# so the bone edge is the only thing that says a part is there at all.
	var e := ModuleData.rarity_ink(m.rarity)
	var p := r.position
	var z := r.size
	for side in [Rect2(p, Vector2(z.x, 1)), Rect2(p + Vector2(0, z.y - 1), Vector2(z.x, 1)),
			Rect2(p, Vector2(1, z.y)), Rect2(p + Vector2(z.x - 1, 0), Vector2(1, z.y))]:
		ci.draw_rect(side, e, true)

## THE SILHOUETTE A PART READS AS, drawn the same way wherever it appears.
##
## One function, called by the hold and by the hull, because the alternative is
## two drawings of a gun that drift apart — and the whole value of a part having
## a shape is that you recognise the thing you just dragged when it lands.
##
## SLOT decides the form: a weapon is a housing with a barrel out of the front, a
## system is a plate, a utility is a mast. `s` scales it — the hull draws these
## at 1 against a hull 30 to 50 rows deep, the hold at rather more in a cell it
## has to fill.
static func draw_part(ci: CanvasItem, slot: ModuleData.Slot, at: Vector2,
		col: Color, s: float = 1.0, upright: bool = false) -> void:
	var dark := col.lerp(Color("#0a0e13"), 0.55)
	var lite := col.lerp(Color.WHITE, 0.3)
	# Drawn about the ORIGIN and moved by a transform, so the same rectangles
	# serve both orientations. A quarter turn anticlockwise, so a barrel that
	# points forward on a ship that faces right points UP when it is stood on
	# end — which is where a lance or a mast belongs.
	ci.draw_set_transform(at, -PI * 0.5 if upright else 0.0, Vector2.ONE)
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
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## THE BOX A PART OCCUPIES, in screen pixels, wherever it is drawn.
##
## One function because three places wanted the same arithmetic and the whole
## point of the last two commits is that they agree: the hold sizes its plate to
## this, the hull scales the silhouette to it, and the drag ghost is cut to it.
## Written out separately in each, they would only have to disagree once.
static func footprint_box(m: ModuleData) -> Vector2:
	var f := m.footprint()
	var step := float(HoldGrid.CELL + HoldGrid.GAP)
	return Vector2(f) * step - Vector2(HoldGrid.GAP, HoldGrid.GAP)


## How big a slot's silhouette is when nothing has scaled it, in the same units
## the rectangles above are written in. Read off those rectangles, so a shape
## that changes has to change this too — and the two are eight lines apart.
static func part_extent(slot: ModuleData.Slot) -> Vector2:
	match slot:
		ModuleData.Slot.WEAPON: return Vector2(18.0, 5.0)
		ModuleData.Slot.SYSTEM: return Vector2(11.0, 4.0)
		_: return Vector2(3.0, 11.0)


## Where a slot's silhouette actually sits relative to the point it is drawn
## from, in the same units as `part_extent`.
##
## NOT ZERO, and assuming it was is what put barrels through the side of their
## own plates: a weapon is drawn from its BREECH, spanning -4 to +14, so its
## bounding box is centred five units in front of the origin. Centring the
## origin in a box therefore hangs a fifth of the gun outside it.
static func part_offset(slot: ModuleData.Slot) -> Vector2:
	match slot:
		ModuleData.Slot.WEAPON: return Vector2(5.0, 0.0)
		ModuleData.Slot.SYSTEM: return Vector2.ZERO
		_: return Vector2(0.0, -2.0)


## Draw a silhouette CENTRED IN A BOX, at the given scale and orientation.
##
## The one way to put a part inside a rectangle. Both callers had been passing
## the box's centre straight to `draw_part` as the draw origin, which is only
## the same thing for a shape that happens to be symmetric — and one of the
## three is not.
static func fill_part(ci: CanvasItem, slot: ModuleData.Slot, box: Rect2,
		col: Color, s: float, upright: bool) -> void:
	draw_part(ci, slot, part_origin(slot, box, s, upright), col, s, upright)


## THE POINT `draw_part` IS CALLED FROM to centre a silhouette in `box`.
##
## Not the box's centre, and that was the bug: a weapon is drawn from its BREECH
## and its bounding box sits five units in front of that, so handing over the
## box centre hung a fifth of the barrel outside the plate. Nothing in the data
## was wrong — every size, scale and total was right and the only symptom was on
## screen. Separate from `fill_part` so a test can ask where the ink will go
## instead of looking at it.
static func part_origin(slot: ModuleData.Slot, box: Rect2, s: float,
		upright: bool) -> Vector2:
	var off := part_offset(slot) * s
	# `draw_part` turns anticlockwise about its origin, so the offset turns too.
	if upright:
		off = Vector2(off.y, -off.x)
	return (part_rect(slot, box, s, upright).get_center() - off).round()


## WHERE THE INK ACTUALLY LANDS when a silhouette is centred in `box`.
##
## Separate from `fill_part` so it can be asserted rather than looked at. The
## bug this exists for was a barrel hanging out of the right-hand side of its own
## plate, and nothing in the data was wrong — every size, scale and total was
## correct and the only symptom was on screen.
static func part_rect(slot: ModuleData.Slot, box: Rect2, s: float,
		upright: bool) -> Rect2:
	var ext := part_extent(slot) * s
	if upright:
		ext = Vector2(ext.y, ext.x)
	return Rect2((box.get_center() - ext * 0.5).round(), ext)


## WHERE THE HARDPOINT IS, inside the part's own footprint. Measured from the
## box's top-left, in screen pixels.
##
## Not the middle for everything. A gun bolts on at its BREECH — the centre of
## its leftmost cell — so a three-cell rail lies along the hull ahead of the
## mount instead of straddling it with a cell and a half hanging off the back.
## Systems and utilities bolt on at their middle, which is what a plate slung
## under a belly and a mast standing on a flank both actually do.
##
## Follows the drawing round. `draw_part` turns anticlockwise, so a gun stood on
## end has its breech at the BOTTOM and the anchor goes with it — otherwise
## turning a rail in the hold would fire it through its own mount.
static func mount_anchor(slot: ModuleData.Slot, box: Vector2, upright: bool,
		cell: float = float(HoldGrid.CELL)) -> Vector2:
	if slot != ModuleData.Slot.WEAPON:
		return box * 0.5
	var half := cell * 0.5
	return Vector2(box.x * 0.5, box.y - half) if upright 		else Vector2(half, box.y * 0.5)


## Does this part's silhouette need standing on end to match its footprint?
##
## MATCHES LONG AXIS TO LONG AXIS rather than reading `turned` directly, because
## the shapes do not all start out lying down: a weapon is authored long across and
## a utility mast is authored long down, so the same flag would stand one of
## them up and knock the other over. A square footprint asks for nothing.
static func part_turn(slot: ModuleData.Slot, f: Vector2i) -> bool:
	if f.x == f.y:
		return false
	var nat := part_extent(slot)
	return (f.y > f.x) != (nat.y > nat.x)


## The scale that makes a slot's silhouette fill `box`, at `f` cells.
##
## FRACTIONAL on purpose, which the art direction's integer-magnification rule
## does not cover: that rule is about magnifying a BITMAP, and these are
## rectangles computed at draw time. There is no source grid to land on, so
## rounding the scale would only make the shape smaller than the space it has.
## Real generated sprites, when they arrive, will want the rule back.
static func part_scale(slot: ModuleData.Slot, f: Vector2i, box: Vector2) -> float:
	var nat := part_extent(slot)
	if part_turn(slot, f):
		nat = Vector2(nat.y, nat.x)
	var room := Vector2(maxf(4.0, box.x - PAD * 2.0), maxf(4.0, box.y - PAD * 2.0))
	return maxf(0.35, minf(room.x / nat.x, room.y / nat.y))

## What the part does, in rectangles.
##
## Drawn from the module's first card rather than authored per module: forty-six
## modules would be forty-six drawings to keep in step with their own effects,
## and the six verbs below already cover every one of them.
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
			# THREE muzzles. At 44px there is no room to count the way the card
			# face does, so this says "more than one" and stops — which is the
			# question the grid is being asked.
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
		&"armor":
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
			# A reticle, and the only glyph in the set with a hole in the middle.
			#
			# The four corners are written out rather than derived from a loop.
			# The clever version put every vertical arm at the corner's top edge,
			# so the two lower brackets pointed the wrong way and the whole thing
			# read as four unrelated ticks — which at 44px is indistinguishable
			# from damage. An L has a handedness and there are four of them.
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
