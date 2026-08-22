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
const R := 4.0

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

func _draw() -> void:
	var pulse := 0.62 + 0.38 * sin(_phase)
	for spot in _spots:
		var at: Vector2 = spot.at
		var taken: bool = spot.held != null
		var wants: bool = _lit != null and _lit.slot == spot.slot
		if wants:
			# A beam reaching off the hull toward whatever you are carrying.
			# Drawn UP from the mount because that is where the cursor is coming
			# from, and it is the only diagonal-free way to say "into here".
			var c := UITheme.TRACTOR
			for i in 7:
				var t := float(i) / 6.0
				var half := lerpf(R * 2.2, 1.0, t)
				draw_rect(Rect2(at.x - half, at.y - 16.0 + t * 16.0, half * 2.0, 2.0),
					Color(c.r, c.g, c.b, lerpf(0.06, 0.34, t) * pulse), true)
			draw_circle(at, R + 2.0, Color(c.r, c.g, c.b, 0.22 * pulse))
			_ring(at, R + 1.0, Color(c.r, c.g, c.b, 0.95 * pulse))
			continue
		if taken:
			_fitted(spot.held as ModuleData, spot.slot as ModuleData.Slot, at)
		else:
			_ring(at, R, UITheme.EMBER.darkened(0.15))

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
func _fitted(m: ModuleData, slot: ModuleData.Slot, at: Vector2) -> void:
	var maker: ManufacturerData = DB.manufacturers.get(m.manufacturer)
	var col: Color = maker.colour if maker != null else UITheme.CHILL
	# Drawn by ModuleIcon.draw_part, which the HOLD also calls. One function, so
	# the gun you dragged off the grid is the gun that appears on the spine.
	ModuleIcon.draw_part(self, slot, Vector2(roundf(at.x), roundf(at.y)), col)
	# The rarity of the thing bolted there, as a pip. Same ladder the cards and
	# the hold icons use, so an Epic gun is the same colour everywhere.
	draw_rect(Rect2(roundf(at.x) - 1.0, roundf(at.y) - 1.0, 2.0, 2.0),
		ModuleData.rarity_colour(m.rarity), true)

func _ring(at: Vector2, r: float, col: Color) -> void:
	draw_arc(at, r, 0.0, TAU, 18, col, 1.0)

## Which mount is under a point, or -1.
func _spot_at(p: Vector2) -> int:
	var best := -1
	var best_d := (R + 7.0) * (R + 7.0)
	for i in _spots.size():
		var d: float = (_spots[i].at as Vector2).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best

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
