class_name MountPoints
extends Control

## The ship's hardpoints, ON the ship.

## Replaces the rack of squares beside it. A rack answers "how many mounts of
## each kind are there" — which is a real question, and is now answered by the
## HARDPOINTS tally under the attributes, where it costs three rows instead of a
## column. What a rack cannot answer is WHERE, and where is the thing a mount
## actually is: `HullData.dorsal` and its two siblings are measured off the
## hull's own silhouette precisely so a gun can hang off the spine it is bolted
## to rather than off a square in a list.
##
## Sits over a ShipView and asks it to place things, so the sprite's bob, its
## magnification and its centring stay in one place. See ShipView.canvas_to_local.

## Radius of the ring drawn at a mount, in CONTROL pixels.
##
## The hull is no longer magnified, so a ring is now the same size relative to
## the ship as it is on screen. 4 rather than 5: the deepest hull is 114 rows and
## the shallowest 43, and a 5px ring on the 43 was a quarter of the hull's depth
## — a mount should mark a place on the ship, not be a feature of it.
## The empty-mount ring, in ART pixels. Multiplied by the view's magnification
## everywhere it is used, same as everything else drawn on the hull.
const R := 4.0

## How many rings the tractor ping keeps in the air at once. Three reads as a
## repeating pulse; one reads as a thing that blinks.
const RINGS := 3

signal dropped(payload: Dictionary, slot: ModuleData.Slot, index: int)

var _view: ShipView = null
var _spots: Array[Dictionary] = []
var _phase: float = 0.0
var _lit: ModuleData = null
var _last_bob: int = -999

func attach(v: ShipView) -> void:
	_view = v
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)

## Recompute where every mount is. Cheap, and called whenever the ship changes.
func refresh() -> void:
	_spots.clear()
	if _view == null or Run.hull == null:
		queue_redraw()
		return
	for slot in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM,
			ModuleData.Slot.UTILITY]:
		var n := Run.slots_for(slot)
		var pts := Run.hull.mounts_along(slot, n)
		for i in pts.size():
			_spots.append({
				slot = slot,
				index = i,
				at = _view.canvas_to_local(pts[i]),
				held = Run.module_at(slot, i),
			})
	queue_redraw()

func _process(delta: float) -> void:
	if _view == null:
		return
	# The mounts ride the hull, so they move with the idle bob. Recomputed only
	# when the bob has actually stepped — it moves in whole pixels a few times a
	# second, and repainting on every frame regardless would be the same picture
	# drawn sixty times.
	var b := _view.bob_offset()
	if b != _last_bob:
		_last_bob = b
		refresh()
	if _lit != null:
		_phase = fmod(_phase + delta * 2.4, TAU)
		queue_redraw()

## One art pixel, in screen pixels. See ShipView.zoom_level.
func _mag() -> float:
	return float(_view.zoom_level()) if _view != null else 1.0

func _draw() -> void:
	var pulse := 0.62 + 0.38 * sin(_phase)
	# EVERY size below is in art pixels times this. The hull is magnified and
	# the things bolted to it were not, so a gun came out a sixth of the length
	# it is drawn at in the hold — the same asset, two scales, on one screen.
	var k := _mag()
	for spot in _spots:
		var at: Vector2 = spot.at
		var taken: bool = spot.held != null
		var wants: bool = _lit != null and _lit.slot == spot.slot
		if wants:
			# A beam reaching off the hull toward whatever you are carrying.
			# Drawn UP from the mount because that is where the cursor is coming
			# from, and it is the only diagonal-free way to say "into here".
			# A PING, not a beam. It was a stack of rectangles reaching up from
			# the mount toward the cursor, which said "from above" — and the
			# cursor is not always above, so half the time the beam pointed
			# away from the thing it was reaching for. Rings have no direction
			# to get wrong, and a mount is a point.
			var c := UITheme.TRACTOR
			for i in RINGS:
				var t := fmod(_phase / TAU + float(i) / float(RINGS), 1.0)
				_ring(at, lerpf(R * 0.7, R * 3.4, t) * k,
					Color(c.r, c.g, c.b, (1.0 - t) * 0.8 * pulse))
			draw_circle(at, (R + 2.0) * k, Color(c.r, c.g, c.b, 0.22 * pulse))
			_ring(at, (R + 1.0) * k, Color(c.r, c.g, c.b, 0.95 * pulse))
			continue
		if taken:
			_fitted(spot.held as ModuleData, spot.slot as ModuleData.Slot, at, k)
		else:
			_ring(at, R * k, UITheme.EMBER.darkened(0.15))

## A part, drawn ON the hull.
##
## A ring said a mount was occupied and nothing about BY WHAT, which made a
## fully fitted ship look bare — five identical dots where five modules were.
##
## The shapes are the vocabulary `ShipView._draw_weapon` already used on the
## procedural hulls, scaled down: those were authored against a 240x120 canvas
## with 30px housings and 44px barrels, which is most of the depth of a hull at
## 1x. Same silhouettes, a third the size, so a ship with real art reads the way
## a procedural one always did.
##
## Slot decides the FORM, not just the position. A weapon is a housing with a
## barrel out of it, a system is a plate slung under the belly, a utility is a
## mast — so the hull says what kind of ship you have built from across the
## screen, before any colour is read.
func _fitted(m: ModuleData, slot: ModuleData.Slot, at: Vector2, k: float) -> void:
	var maker: ManufacturerData = DB.manufacturers.get(m.manufacturer)
	var col: Color = maker.colour if maker != null else UITheme.CHILL
	# THE PART ITSELF, and nothing around it. The hold draws a plate — a field,
	# a house stripe, a rarity edge — because the hold is an inventory and those
	# are inventory facts. A ship is not an inventory: what is bolted to it is
	# the object, so the box goes and the silhouette is scaled up to fill the
	# room the box used to take.
	#
	# It still takes its SIZE from the footprint, which is the point: a 1x3
	# lance is three cells long on the ship because it is three cells long, and
	# turning it in the hold turns it here.
	var f := m.footprint()
	var box := ModuleIcon.footprint_box(m)
	var up := ModuleIcon.part_turn(slot, f)
	var k2 := ModuleIcon.part_scale(slot, f, box)

	# THE HARDPOINT IS A POINT INSIDE THE PART, and which point depends on what
	# the part is — see ModuleIcon.mount_anchor. So the footprint is hung off
	# the mount by that offset rather than centred on it or stood on top of it,
	# both of which this has been: centred, a three-cell rail put half of itself
	# behind its own mounting; stood on top, every part floated clear of the
	# hull whenever its silhouette did not fill the box.
	var anchor := ModuleIcon.mount_anchor(slot, box, up)
	var r := Rect2((Vector2(roundf(at.x), roundf(at.y)) - anchor).round(), box)
	ModuleIcon.fill_part(self, slot, r, ModuleData.rarity_colour(m.rarity), k2, up)

	# THE HOUSE, as a bar where the part meets the hull. There is no plate out
	# here to carry a border and the silhouette now says rarity, so without this
	# the ship is the one place in the game that cannot tell you whose parts are
	# bolted to it — which is the fact set bonuses are counted from.
	var w := minf(box.x, 10.0 * k)
	draw_rect(Rect2(roundf(at.x - w * 0.5), roundf(at.y - k * 0.5), w, k), col, true)

## Where every mount is and what is in it, in this control's own coordinates.
## Read-only, and it exists for `-- fittest`: a test that has to drop something
## on a hardpoint needs to know where one IS, and guessing that off the sprite
## is the thing anchors.py was written to stop anybody doing.
func spots() -> Array[Dictionary]:
	return _spots

func _ring(at: Vector2, r: float, col: Color) -> void:
	draw_arc(at, r, 0.0, TAU, 18, col, maxf(1.0, _mag()))

## Which mount is under a point, or -1.
func _spot_at(p: Vector2) -> int:
	var best := -1
	# The grab radius scales too, or a mount drawn twice the size still has to
	# be clicked as though it were small.
	var best_d := ((R + 7.0) * _mag()) * ((R + 7.0) * _mag())
	for i in _spots.size():
		var d: float = (_spots[i].at as Vector2).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best

## Taking a part back OFF the ship.
##
## This did not exist, and its absence was invisible because everything it needs
## already did: `_on_hold_drop` has always had a branch for a part arriving off
## the hull, `ModuleData.mount` has always been clearable, and the hold has
## always accepted a drop. There was simply nothing anywhere that could start
## the drag, so the whole return journey was unreachable code that read as
## finished.
##
## `origin` is what tells the far end which journey this is. The hold uses it to
## decide between moving a part between two cells and taking one off the ship.
func _get_drag_data(at: Vector2) -> Variant:
	var i := _spot_at(at)
	if i < 0:
		return null
	var m: ModuleData = _spots[i].held
	if m == null:
		return null
	# The same ghost the hold hands over, at the same size, because what you are
	# carrying does not change shape depending on where you picked it up.
	set_drag_preview(ModuleIcon.ghost_for(m, &"hull"))
	return {module = m, origin = &"hull"}

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("module"):
		return false
	var m: ModuleData = data.module
	if m == null:
		return false
	if _lit != m:
		_lit = m
		queue_redraw()
	var i := _spot_at(at)
	return i >= 0 and (_spots[i].slot as ModuleData.Slot) == m.slot

func _drop_data(at: Vector2, data: Variant) -> void:
	var m: ModuleData = (data as Dictionary).module
	var i := _spot_at(at)
	_unlight()
	if i < 0 or m == null:
		return
	if (_spots[i].slot as ModuleData.Slot) != m.slot:
		return
	dropped.emit(data as Dictionary, _spots[i].slot, _spots[i].index)

func _unlight() -> void:
	if _lit == null:
		return
	_lit = null
	queue_redraw()

func _notification(what: int) -> void:
	# Godot offers no "the drag left me", so the beams are put out when the
	# mouse leaves and again when any drag anywhere ends — without the second,
	# the hull stays lit after a drop that landed in the hold.
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_unlight()
	elif what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("module"):
			_lit = (data as Dictionary).module
			queue_redraw()
