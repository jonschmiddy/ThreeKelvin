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

## How far from an empty hardpoint a drop still counts, in art pixels.
##
## THE SAME NUMBER THE PING IS DRAWN AT, which is the whole point of it being a
## constant: the outermost ring reached 3.4R and the drop was accepted within
## 2.75R, so there was a visible ring of "looks like a target, is not one" all
## the way round every mount. A target you can see and cannot hit is worse than
## a smaller target.
const REACH := R * 3.4

signal dropped(payload: Dictionary, slot: ModuleData.Slot, index: int)

## A part has been picked UP off the hull, and a drag has ended.
##
## Two signals rather than one because they are two different facts and the
## screen does different things with them: lifting takes a part off the ship
## immediately, and the end of a drag is the only moment anyone can tell that a
## lifted part never landed anywhere and has to go back.
signal lifted(m: ModuleData)
signal released()

var _view: ShipView = null
var _spots: Array[Dictionary] = []
var _phase: float = 0.0
var _lit: ModuleData = null

## THE PART BEING POINTED AT FROM SOMEWHERE ELSE.
##
## `_lit` answers "which mounts would take the thing I am carrying"; this
## answers "where on the ship is the part I am reading about". They are
## different questions and a drag is not involved in the second one, so the
## refit screen's installed list can point at the hull without pretending to
## carry anything.
var _focus: ModuleData = null
var _last_bob: int = -999
var _passive: bool = false

## How many fitted parts the last redraw actually put on the hull.
##
## Written by `_draw` and read by `-- fittest`. The bug it exists for was the
## draw loop skipping past a fitted part to paint a highlight in its place, and
## no assertion on the DATA can see that: `spots()` reported every part
## correctly the whole time the hull was coming back bare. A count of what was
## DRAWN is the smallest thing that can tell the difference.
var drawn: int = 0

## How many tractor pings the last redraw put up. Same reason as `drawn`: the
## rule is that only an EMPTY hardpoint pings, and nothing in the data says so.
var pinged: int = 0

## Where the pointer is over the hull, or INF. Drives the hover highlight.
var _hover: Vector2 = Vector2.INF

func attach(v: ShipView) -> void:
	_view = v
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)
	# Its own subscription, so a host only has to add it. The refit screen calls
	# refresh() itself as well, which costs a redraw and is worth not having a
	# second rule about who is responsible for this.
	Sig.ship_changed.connect(refresh)

## Display only. No drops, no empty hardpoints, no beams.
##
## What the sector wants is the PICTURE: a ship with its guns on it. A ring
## marking a mount you have not filled is an invitation to do something that
## screen cannot do, and a tractor beam has nothing to reach for.
func passive() -> void:
	_passive = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

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

## One art pixel, in screen pixels. See ShipView.art_scale.
##
## PARTS ARE HALF THE SIZE ON THE SHIP THAT THEY ARE IN THE HOLD, deliberately.
## The two surfaces are doing different jobs: the hold is a thing you grab from,
## so its cells are 30px and easy to hit, and the ship is a picture, so a part on
## it has to be in proportion to the hull it is bolted to.
##
## The proportion is not a preference — it is forced. A heavy carries FIVE weapon
## hardpoints. At hold size a two-cell gun is 61px against a 248px hull, so five
## of them come to 125% of the ship and cannot be drawn at all. At this size the
## same gun is 31px and five of them take 62% of the dorsal line, which is a ship
## with guns on it.
##
## art_scale, not zoom_level: a mount is drawn ON the hull, so it has to follow
## the hull onto the half sheet. zoom_level reports magnification alone and would
## draw full-size parts over a half-size ship.
func _mag() -> float:
	return _view.art_scale() if _view != null else 1.0

func _draw() -> void:
	drawn = 0
	pinged = 0
	var pulse := 0.62 + 0.38 * sin(_phase)
	# EVERY size below is in art pixels times this. The hull is magnified and
	# the things bolted to it were not, so a gun came out a sixth of the length
	# it is drawn at in the hold — the same asset, two scales, on one screen.
	var k := _mag()
	# HOVERING THE SHIP SHOWS YOU WHAT IS ON IT. Only while your hands are
	# empty: with a part in hand the pings are already saying where it can go,
	# and two answers at once is one too many.
	var over := not _passive and _lit == null and _hover.x < INF
	for spot in _spots:
		var at: Vector2 = spot.at
		var m: ModuleData = spot.held
		# WHAT IS THERE, FIRST AND ALWAYS. This used to draw the highlight
		# INSTEAD of the part and skip to the next mount, so picking up any
		# weapon blanked every other weapon on the ship for as long as you
		# carried it — which is exactly the moment you are looking at the hull.
		if m != null:
			var r := part_rect(m, spot.slot, at, k)
			var under := over and r.grow(2.0).has_point(_hover)
			_fitted(m, spot.slot as ModuleData.Slot, at, k, under)
			drawn += 1
			if over and not under:
				# The others get an outline, so hovering the ship answers
				# "what have I got on here" for all of them at once.
				draw_rect(r.grow(1.0),
					ModuleData.rarity_ink(m.rarity), false, 1.0)
			# POINTED AT FROM THE LIST. Two rings rather than one, because a
			# single hairline on a busy hull is not findable — the whole
			# point is that your eye lands on it without searching.
			if m == _focus:
				draw_rect(r.grow(3.0), UITheme.ICE, false, 1.0)
				draw_rect(r.grow(1.0), UITheme.ICE, false, 1.0)
			continue
		# AN EMPTY HARDPOINT IS NOT DRAWN AT ALL. A ring on every unfilled
		# mount put a row of orange circles across a ship that was finished —
		# saying "something is missing here" about a hull with nothing missing,
		# and louder than anything else on the screen. Showing them on hover was
		# the same complaint one gesture later. The only time a bare mount is
		# worth pointing at is when you are holding something that fits it, and
		# that is what the ping below is.

		# A PING, and ONLY on a mount with nothing in it. Drawn over an
		# installed part it swamped the thing it was pointing at — 27px of
		# rings over a gun 30px tall — which is what made a whole slot look
		# like it had emptied the moment you picked something up. An occupied
		# mount will still take a swap; it does not need to shout about it.
		if _passive or _lit == null or _lit.slot != spot.slot:
			continue
		pinged += 1
		var c := UITheme.TRACTOR
		for i in RINGS:
			var t := fmod(_phase / TAU + float(i) / float(RINGS), 1.0)
			_ring(at, lerpf(R * 0.7, REACH, t) * k,
				Color(c.r, c.g, c.b, (1.0 - t) * 0.8 * pulse))
		_ring(at, (R + 1.0) * k, Color(c.r, c.g, c.b, 0.95 * pulse))

## WHERE A PART IS DRAWN, as a rectangle. One function, because three things
## need it: the drawing, the hover test, and picking one up. A gun you can only
## grab by the dot it is bolted through is a gun you have to aim at.
func part_rect(m: ModuleData, slot: ModuleData.Slot, at: Vector2,
		k: float) -> Rect2:
	# THE AUTHORED SIZE, not the packed one. `footprint()` swaps the axes
	# when a part is turned, and turning is a fact about how it fits in the
	# HOLD -- rotating a rail to slot it into a gap should not stand the gun
	# on its end once it is bolted to the hull.
	var f := Vector2i(maxi(1, m.size.x), maxi(1, m.size.y))
	# THE CELLS COME WITH THE SHIP. The hold is authored at 2x and so is the
	# refit screen's hull, which is what makes a part the same size in both. The
	# sector drops to 1x with a party on screen, and a box that stayed 30px
	# would put a full-size gun on a half-size ship.
	var q := k / ModuleIcon.HOLD_K
	var cell := float(HoldGrid.CELL) * q
	var gap := float(HoldGrid.GAP) * q
	var box := Vector2(f) * (cell + gap) - Vector2(gap, gap)
	# THE HARDPOINT IS A POINT INSIDE THE PART, and which point depends on what
	# the part is — see ModuleIcon.mount_anchor. So the footprint hangs off the
	# mount by that offset rather than being centred on it.
	var up := ModuleIcon.part_turn(slot, f)
	var anchor := ModuleIcon.mount_anchor(slot, box, up, cell)
	return Rect2((Vector2(roundf(at.x), roundf(at.y)) - anchor).round(), box)


func _fitted(m: ModuleData, slot: ModuleData.Slot, at: Vector2, k: float,
		full: bool) -> void:
	var maker: ManufacturerData = DB.manufacturers.get(m.manufacturer)
	var col: Color = maker.colour if maker != null else UITheme.CHILL
	var f := Vector2i(maxi(1, m.size.x), maxi(1, m.size.y))
	var r := part_rect(m, slot, at, k)
	var up := ModuleIcon.part_turn(slot, f)
	var k2 := ModuleIcon.part_scale(slot, f, r.size)

	# THE PART ITSELF, and normally nothing around it. A ship is not an
	# inventory: what is bolted to it is the object, not a plate with the object
	# on it. Hovering is the exception — see `_draw`.
	# FLIPPED, if this one is. Mirrored about the part's own middle rather
	# than redrawn: the silhouette is the same object seen from the other
	# side, so a gun on the belly points its muzzle the way the ship is
	# going instead of hanging upside down off the keel.
	if m.flipped:
		draw_set_transform(Vector2(0.0, r.position.y * 2.0 + r.size.y),
			0.0, Vector2(1.0, -1.0))
	if full:
		ModuleIcon.draw_plate(self, m, r)
	else:
		ModuleIcon.fill_part(self, slot, r, col, k2, up)
	if m.flipped:
		draw_set_transform_matrix(Transform2D.IDENTITY)

	# RARITY, as a bar where the part meets the hull. The same split the plate
	# uses, kept the same way round out here: the ART says whose it is, and what
	# is behind or under it says how good.
	if not full:
		var w := minf(r.size.x, 10.0 * k)
		draw_rect(Rect2(roundf(at.x - w * 0.5), roundf(at.y - k * 0.5), w, k),
			ModuleData.rarity_ink(m.rarity), true)

## Where every mount is and what is in it, in this control's own coordinates.
## Read-only, and it exists for `-- fittest`: a test that has to drop something
## on a hardpoint needs to know where one IS, and guessing that off the sprite
## is the thing anchors.py was written to stop anybody doing.
func spots() -> Array[Dictionary]:
	return _spots

func _ring(at: Vector2, r: float, col: Color) -> void:
	draw_arc(at, r, 0.0, TAU, 18, col, maxf(1.0, _mag()))

## The INSTALLED PART under a point, or null. Same hit test the mount lookup
## uses, answering with the thing rather than the place -- a caller that wants
## to flip what it is pointing at does not care which hardpoint holds it.
func part_under(p: Vector2) -> ModuleData:
	var k := _mag()
	for i in _spots.size():
		var m: ModuleData = _spots[i].held
		if m == null:
			continue
		if part_rect(m, _spots[i].slot, _spots[i].at, k).grow(2.0).has_point(p):
			return m
	return null

## Which mount is under a point, or -1.
##
## AN INSTALLED PART IS GRABBED ANYWHERE ON IT. It used to be a radius round the
## hardpoint for everything, so a three-cell rail could only be picked up by the
## dot at its breech — the rest of it was scenery you could click through. An
## EMPTY mount is genuinely just a point, so that keeps its radius.
func spot_at(p: Vector2) -> int:
	var k := _mag()
	for i in _spots.size():
		var m: ModuleData = _spots[i].held
		if m != null and part_rect(m, _spots[i].slot, _spots[i].at, k).has_point(p):
			return i
	var best := -1
	var best_d := (REACH * k) * (REACH * k)
	for i in _spots.size():
		if _spots[i].held != null:
			continue
		var d: float = (_spots[i].at as Vector2).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best

## Taking a part back OFF the ship.
##
## This did not exist for a long time, and its absence was invisible because
## everything it needs already did: `_on_hold_drop` has always had a branch for
## a part arriving off the hull, and the hold has always accepted a drop. There
## was simply nothing anywhere that could start the drag.
##
## `origin` is what tells the far end which journey this is. The hold uses it to
## decide between moving a part between two cells and taking one off the ship.
func _get_drag_data(at: Vector2) -> Variant:
	var i := spot_at(at)
	if i < 0:
		return null
	var m: ModuleData = _spots[i].held
	if m == null:
		return null
	# The same ghost the hold hands over, at the same size, because what you are
	# carrying does not change shape depending on where you picked it up. It is
	# handed the part's CURRENT place on the hull so the plate starts over the
	# gun you just grabbed rather than appearing centred on the pointer.
	set_drag_preview(ModuleIcon.ghost_for(m, &"hull",
		get_global_rect().position
		+ part_rect(m, _spots[i].slot, _spots[i].at, _mag()).position))
	# OFF THE SHIP THE MOMENT IT IS IN YOUR HAND. Carrying a part while the
	# ship still wore it meant the mount you were dragging OUT of stayed full,
	# so it did not ping, and moving a gun one hardpoint along was a fight with
	# a slot that already looked occupied — by the thing you were holding.
	lifted.emit(m)
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
	var i := spot_at(at)
	return i >= 0 and (_spots[i].slot as ModuleData.Slot) == m.slot

func _drop_data(at: Vector2, data: Variant) -> void:
	var m: ModuleData = (data as Dictionary).module
	var i := spot_at(at)
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
		_hover = Vector2.INF
		_unlight()
	if what == NOTIFICATION_DRAG_END:
		# After any drop has been processed, which is what makes this the place
		# to notice that a lifted part is now in neither the hull nor the hold.
		released.emit()
	elif what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("module"):
			light((data as Dictionary).module)

## Follow the pointer over the hull, so `_draw` can say what is bolted on.
##
## `_gui_input` and not `_process`: a Control is told where the mouse is when it
## is over IT, which is the question being asked. Reading the global mouse every
## frame would light the ship up while the cursor was somewhere else entirely.
func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm == null:
		return
	_hover = mm.position
	queue_redraw()


## Where the pointer is over the hull, for a test that cannot move a real one.
func hover(p: Vector2) -> void:
	_hover = p
	queue_redraw()


## Show which mounts would take `m`. Public so `-- fittest` can put the hull in
## the state a live drag puts it in — a drag is driven by the OS cursor and
## pushed events do not move that.
## Point at one INSTALLED part, from a list somewhere else on the screen.
## Null clears it. Idempotent, because a hover fires on every motion event.
func focus(m: ModuleData) -> void:
	if _focus == m:
		return
	_focus = m
	queue_redraw()

func light(m: ModuleData) -> void:
	_lit = m
	queue_redraw()
