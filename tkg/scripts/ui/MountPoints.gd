class_name MountPoints
extends Control

## The ship's hardpoints, ON the ship.

## Draws mounts off the hull's own silhouette, so a gun hangs off the spine it is bolted to.
## Why: docs/why/MountPoints.md#purpose

## Ring radius 4, not 5: on the shallowest hull (43 rows) a 5px ring was a quarter of its depth.
## Why: docs/why/MountPoints.md#mount-sizes
const R := 4.0

## How many rings the tractor ping keeps in the air at once. Three reads as a
## repeating pulse; one reads as a thing that blinks.
const RINGS := 3

## Drop reach equals the ping's drawn reach, so no ring looks hittable but is not.
## Why: docs/why/MountPoints.md#mount-sizes
const REACH := R * 3.4

signal dropped(payload: Dictionary, slot: ModuleData.Slot, index: int)

## Two signals for two facts: lifting takes the part off the ship, and drag end is when a
## part that never landed has to go back.
## Why: docs/why/MountPoints.md#drag-signals
signal lifted(m: ModuleData)
signal released()

var _view: ShipView = null
var _spots: Array[Dictionary] = []
var _phase: float = 0.0
var _lit: ModuleData = null
## Where `_lit` was picked up from (`cargo`, `hull`, `bag`, `pad`); it decides `takes`.
var _lit_origin: StringName = &""

## Which part is pointed at from a list: no drag is involved, unlike `_lit`.
## Why: docs/why/MountPoints.md#pointed-part
var _focus: ModuleData = null
var _passive: bool = false

## Null means `Run.hull`; the transfer screen draws the frame being left, which `Run` cannot supply.
## Why: docs/why/MountPoints.md#foreign-hull
var ship: HullData = null
## What is bolted to `ship`. Read instead of `Run.installed` in foreign mode.
var fitted: Array = []

## Counts what `_draw` painted: the bare-hull bug was invisible to any assertion on the data.
## Why: docs/why/MountPoints.md#draw-counters
var drawn: int = 0

## How many tractor pings the last redraw put up. Same reason as `drawn`: the
## rule is that only an EMPTY hardpoint pings, and nothing in the data says so.
var pinged: int = 0

## Counts hover hints drawn, as a hint and a ping must never both show.
var hinted: int = 0

## Counts swap marks and marked mounts drawn; `-- cutawaytest` holds them to what a drop does.
var swapped: int = 0
var marked: Array[String] = []

## WHICH LOOK THE SWAP MARK WEARS: 0 a frame round the part, 1 its four
## corners. For the stills that put the two side by side; play uses 0.
static var swap_look := 0

## Where the pointer is over the hull, or INF. Drives the hover highlight.
var _hover: Vector2 = Vector2.INF

## The part is drawn, hit and picked up where it is lifted to, so a drag starts on what you see.
## Why: docs/why/MountPoints.md#cutaway
var lift: Dictionary = {}
var tag_side: Dictionary = {}
var explode: float = 0.0
## Names on the lifted parts, and rings on the empty mounts, once they are out.
var tags: bool = false
## A card in the hand is pointed at: its part, lit (the fight's half of the
## cutaway; ICE ring and a soft wash, pulsing). Null clears it.
var lit_part: ModuleData = null


static func spot_key(slot: int, index: int) -> String:
	return "%d:%d" % [slot, index]


## Where the part on spot `s` is drawn: its mount, or lifted off it.
func _part_at(s: Dictionary) -> Vector2:
	# (an empty mount is drawn where it is: its ping and its ring are the mount)
	if explode <= 0.0 or lift.is_empty() or s.held == null:
		return s.at
	var o: Vector2 = lift.get(spot_key(int(s.slot), int(s.index)), Vector2.ZERO)
	return (s.at as Vector2) + (o * explode * _mag()).round()

func attach(v: ShipView) -> void:
	_view = v
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)
	# Its own subscription so a host need only add it, at the cost of one extra redraw.
	Sig.ship_changed.connect(refresh)

## Display only: the sector wants the picture, and a ring or beam would invite what it cannot do.
func passive() -> void:
	_passive = true
	weapons_only = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

## Pictures show weapons only (Jon, Oct 23); fitting screens still show every part.
## Why: docs/why/MountPoints.md#weapons-only
var weapons_only: bool = false

## Whether a fitted part is drawn; everything reading parts as drawn asks this.
func shows(m: ModuleData) -> bool:
	return m != null and (not weapons_only or m.slot == ModuleData.Slot.WEAPON)

## Recompute where every mount is. Cheap, and called whenever the ship changes.
func refresh() -> void:
	_place()
	queue_redraw()


## Where every mount is, from where the hull is drawn NOW (`_placed_at`).
func _place() -> void:
	_spots.clear()
	var h: HullData = ship if ship != null else Run.hull
	if _view == null or h == null:
		return
	_placed_at = _view.canvas_to_local(Vector2.ZERO)
	_placed_scale = _view.art_scale()
	for slot in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM,
			ModuleData.Slot.UTILITY]:
		# Use the hull's own slot count in foreign mode; `Run.slots_for` is for the flown ship.
		var n: int = h.slots_for(slot) if ship != null else Run.slots_for(slot)
		var pts := h.mounts_along(slot, n)
		for i in pts.size():
			_spots.append({
				slot = slot,
				index = i,
				at = _view.canvas_to_local(pts[i]),
				held = _held(slot, i),
			})


## For tests: a part left where the hull used to be would float beside the ship.
func strays() -> Array[String]:
	var out: Array[String] = []
	if _view == null or explode > 0.0:
		return out
	var img := _view.canvas()
	if img == null:
		return out
	var c0 := _view.canvas_to_local(Vector2.ZERO)
	var px := float(_view._k)
	var k := _mag()
	for s in _spots:
		var m: ModuleData = s.held
		if not shows(m):
			continue
		var r := part_rect(m, s.slot, _part_at(s), k)
		var cr := Rect2((r.position - c0) / px, r.size / px)
		var hit := false
		for y in range(maxi(0, int(floor(cr.position.y))), mini(img.get_height(), int(ceil(cr.end.y)))):
			for x in range(maxi(0, int(floor(cr.position.x))), mini(img.get_width(), int(ceil(cr.end.x)))):
				if img.get_pixel(x, y).a > 0.1:
					hit = true
					break
			if hit:
				break
		if not hit:
			out.append(m.name)
	return out


## For the yard's stands, which keep out from under a part hung below the belly.
func part_rects_canvas() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _view == null:
		return out
	_place()
	var c0 := _view.canvas_to_local(Vector2.ZERO)
	var px := float(_view._k)
	var k := _mag()
	for s in _spots:
		var m: ModuleData = s.held
		if not shows(m):
			continue
		var r := part_rect(m, s.slot, s.at, k)
		out.append(Rect2((r.position - c0) / px, r.size / px))
	return out


## Whatever is on hardpoint `i` of `slot`, on whichever ship this is drawing.
func _held(slot: ModuleData.Slot, i: int) -> ModuleData:
	if ship == null:
		return Run.module_at(slot, i)
	for raw in fitted:
		var m := raw as ModuleData
		if m != null and m.slot == slot and m.mount == i:
			return m
	return null

## Where the hull's canvas corner was, and its scale, when the mounts were
## last placed (`_place`).
var _placed_at := Vector2.INF
var _placed_scale := 0.0


## Whether the hull has moved, or changed scale, since the mounts were placed.
func _stale() -> bool:
	return _view != null and (_view.canvas_to_local(Vector2.ZERO) != _placed_at \
		or not is_equal_approx(_view.art_scale(), _placed_scale))


func _process(delta: float) -> void:
	if _view == null:
		return
	# Watch the hull's place, not only the bob: a relayout moved the hull and left parts behind.
	# Why: docs/why/MountPoints.md#hull-movement
	if _stale():
		refresh()
	# The phase must advance for either animation: the hover hints were stopped, not faint.
	# Why: docs/why/MountPoints.md#animation-phase
	if _animating():
		_phase = fmod(_phase + delta * 2.4, TAU)
		queue_redraw()

## One condition for any animation, so a third cannot be added and quietly not run.
func _animating() -> bool:
	return _lit != null or lit_part != null or (not _passive and _hover.x < INF)

## Parts are half hold size on the ship by force: five heavy guns at hold size are 125% of the hull.
## Why: docs/why/MountPoints.md#part-scale
func _mag() -> float:
	return _view.art_scale() if _view != null else 1.0

func _draw() -> void:
	# (the layout has settled by the time anything is drawn: placed against a
	# passing size in `_process`, the mounts are placed again here)
	if _stale():
		_place()
	drawn = 0
	pinged = 0
	hinted = 0
	swapped = 0
	marked.clear()
	var pulse := 0.62 + 0.38 * sin(_phase)
	# Sizes are art pixels times this: the hull is magnified and bolted parts were not.
	var k := _mag()
	# Hover hints only with empty hands: with a part in hand the pings already answer.
	var over := not _passive and _lit == null and _hover.x < INF
	for spot in _spots:
		var at: Vector2 = _part_at(spot)
		var m: ModuleData = spot.held
		# (a part this hull does not show is not drawn, and its mount is not
		# empty either: no ping, no hint, nothing -- see `weapons_only`)
		if m != null and not shows(m):
			continue
		# THE DROP'S OWN ANSWER for this mount, while a part is carried: the one
		# `_can_drop_data` gives and `RunState.fit_at_mount` acts on (`takes`)
		var ok := _takes_spot(spot)
		if m != null and explode > 0.0 and at != (spot.at as Vector2):
			_leader(spot.at, at, m, spot.slot as ModuleData.Slot, k)
		# In the cutaway an empty mount shows only while a fitting part is carried (Jon).
		if m == null and _shows_empty(spot):
			_empty_words(spot, k)
		# Draw what is there first: skipping ahead to the highlight blanked every other weapon.
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
			# One ring, not two: the pair fenced a 15px gun in four pixels of white.
			# Why: docs/why/MountPoints.md#focus-ring
			if m == _focus:
				draw_rect(r.grow(2.0), UITheme.ICE, false, 1.0)
			if m == lit_part:
				var pl := 0.5 + 0.5 * sin(_phase * 3.0)
				draw_rect(r, Color(UITheme.HOT, 0.18 + 0.15 * pl))
				draw_rect(r.grow(2.0), UITheme.HOT, false, 1.0)
			# Trade partners get a still teal frame, never dimmed: greyed reads as gone (Jon).
			# Why: docs/why/MountPoints.md#swap-marks
			if ok:
				_swap_mark(r, k)
				swapped += 1
				marked.append(spot_key(int(spot.slot), int(spot.index)))
			if tags and explode > 0.85:
				_tag(m, r, spot)
			continue
		# An empty hardpoint is not drawn: rings on a finished ship say something is missing.
		# Why: docs/why/MountPoints.md#empty-mounts

		# Pings only on empty mounts; hover hints are cold and faint so a bare hull is not loud.
		# Why: docs/why/MountPoints.md#pings-and-hints
		if over and not tags:
			hinted += 1
			# Hints use CHILL at near ping alpha: the separation that matters is hue, not loudness.
			# Why: docs/why/MountPoints.md#pings-and-hints
			var g := UITheme.CHILL
			for i in RINGS:
				var t := fmod(_phase / TAU + float(i) / float(RINGS), 1.0)
				_ring(at, lerpf(R * 0.7, REACH, t) * k,
					Color(g.r, g.g, g.b, (1.0 - t) * 0.85 * pulse))
			var b := UITheme.ICE
			_ring(at, (R + 1.0) * k, Color(b.r, b.g, b.b, 0.95 * pulse))

		if not ok:
			continue
		pinged += 1
		marked.append(spot_key(int(spot.slot), int(spot.index)))
		var c := UITheme.TRACTOR
		for i in RINGS:
			var t := fmod(_phase / TAU + float(i) / float(RINGS), 1.0)
			_ring(at, lerpf(R * 0.7, REACH, t) * k,
				Color(c.r, c.g, c.b, (1.0 - t) * 0.8 * pulse))
		_ring(at, (R + 1.0) * k, Color(c.r, c.g, c.b, 0.95 * pulse))

## Swap mark: one art pixel thick, one px off the part, filled rects so no edge is half a pixel.
func _swap_mark(r: Rect2, k: float) -> void:
	var t := maxf(1.0, roundf(k))
	var g := 1.0 + t
	var f := Rect2((r.position - Vector2(g, g)).round(), (r.size + Vector2(g, g) * 2.0).round())
	var c := UITheme.TRACTOR
	if swap_look == 1:
		var arm := minf(t * 3.0, floorf(minf(f.size.x, f.size.y) * 0.5))
		for x: float in [f.position.x, f.end.x - arm]:
			for y: float in [f.position.y, f.end.y - t]:
				draw_rect(Rect2(x, y, arm, t), c)
		for x: float in [f.position.x, f.end.x - t]:
			for y: float in [f.position.y, f.end.y - arm]:
				draw_rect(Rect2(x, y, t, arm), c)
		return
	draw_rect(Rect2(f.position.x, f.position.y, f.size.x, t), c)
	draw_rect(Rect2(f.position.x, f.end.y - t, f.size.x, t), c)
	draw_rect(Rect2(f.position.x, f.position.y + t, t, f.size.y - t * 2.0), c)
	draw_rect(Rect2(f.end.x - t, f.position.y + t, t, f.size.y - t * 2.0), c)


## One function for drawing, hover and pick-up; a gun grabbable only by its dot is hard to aim at.
func part_rect(m: ModuleData, slot: ModuleData.Slot, at: Vector2,
		k: float) -> Rect2:
	# Authored size, not packed: turning a part to fit the hold must not stand it on end.
	var f := Vector2i(maxi(1, m.size.x), maxi(1, m.size.y))
	# The cells scale with the ship: a fixed 30px box would put a full gun on a half ship.
	var q := k / ModuleIcon.HOLD_K
	var cell := float(HoldGrid.CELL) * q
	var gap := float(HoldGrid.GAP) * q
	var box := Vector2(f) * (cell + gap) - Vector2(gap, gap)
	# The hardpoint is a point inside the part; see `ModuleIcon.mount_anchor`.
	var up := ModuleIcon.part_turn(slot, f)
	var anchor := ModuleIcon.mount_anchor(slot, box, up, cell)
	return Rect2((Vector2(roundf(at.x), roundf(at.y)) - anchor).round(), box)


func _fitted(m: ModuleData, slot: ModuleData.Slot, at: Vector2, k: float,
		full: bool) -> void:
	var manufacturer: ManufacturerData = DB.manufacturers.get(m.manufacturer)
	var col: Color = manufacturer.colour if manufacturer != null else UITheme.CHILL
	var f := Vector2i(maxi(1, m.size.x), maxi(1, m.size.y))
	var r := part_rect(m, slot, at, k)

	# The part alone, no plate (hover aside). Flip goes as arguments: the transform resets.
	# Why: docs/why/MountPoints.md#fitted-part-drawing
	if full:
		ModuleIcon.draw_plate(self, m, r, f, m.flipped, k)
	else:
		ModuleIcon.draw_body(self, m, r, col, f, m.flipped, k)

	# No rarity bar on the hull: it read as a stripe through the part. Hover shows the plate.
	# Why: docs/why/MountPoints.md#rarity-bar

## Read-only, for `-- fittest`: tests need where a hardpoint is, not a guess off the sprite.
func spots() -> Array[Dictionary]:
	return _spots

## THE CUTAWAY'S LEADER: dotted from the mount to where the part was lifted to,
## with the mount itself a small square.
func _leader(from: Vector2, at: Vector2, m: ModuleData, slot: ModuleData.Slot, k: float) -> void:
	var r := part_rect(m, slot, at, k)
	var to := Vector2(r.position.x + (r.size.y * 0.5 if slot == ModuleData.Slot.WEAPON else r.size.x * 0.5), r.get_center().y)
	var c := Color(UITheme.HOT, 0.85 * clampf(explode, 0.0, 1.0))
	var d := to - from
	var n := int(d.length() / 2.0)
	for i in range(0, n, 2):
		var p := (from + d * (float(i) / maxf(float(n), 1.0))).floor()
		draw_rect(Rect2(p, Vector2.ONE), c)
	draw_rect(Rect2((from - Vector2(1, 1)).floor(), Vector2(3, 3)), Color(UITheme.HOT, c.a))


## Its name beside it, on the side the cutaway chose.
func _tag(m: ModuleData, r: Rect2, s: Dictionary) -> void:
	var f := UITheme.pixel_font()
	var txt := m.name.to_upper()
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	var a := clampf((explode - 0.85) / 0.15, 0.0, 1.0)
	var box := tag_box(r, String(tag_side.get(spot_key(int(s.slot), int(s.index)), "R")), w)
	draw_string(f, box.position + Vector2(0, f.get_ascent(UITheme.FS_SMALL)), LowHull.scr(self, txt, UITheme.FS_SMALL, f), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, Color(UITheme.ICE, a))


## One place the tag box is worked out, so layout, drawing and test cannot disagree.
static func tag_box(r: Rect2, side: String, w: float) -> Rect2:
	var f := UITheme.pixel_font()
	var asc := f.get_ascent(UITheme.FS_SMALL)
	var hgt := asc + f.get_descent(UITheme.FS_SMALL)
	var x := r.end.x + 5.0
	var base := roundf(r.get_center().y + 3.0)
	match side:
		"L":
			x = r.position.x - 5.0 - w
		"T":
			x = r.get_center().x - w * 0.5
			base = r.position.y - 3.0
		"B":
			x = r.get_center().x - w * 0.5
			base = r.end.y + 3.0 + asc
	return Rect2(Vector2(roundf(x), roundf(base) - asc), Vector2(w, hgt))


## And an empty mount's words: centred `off` (art px) from the ring at `at`.
static func label_box(at: Vector2, off: Vector2, w: float, k: float) -> Rect2:
	var f := UITheme.pixel_font()
	var asc := f.get_ascent(UITheme.FS_SMALL)
	var c := at + off * k
	return Rect2(Vector2(roundf(c.x - w * 0.5), roundf(c.y + 3.0) - asc), Vector2(w, asc + f.get_descent(UITheme.FS_SMALL)))


static func empty_text(slot: int) -> String:
	return "EMPTY " + ModuleData.slot_name(slot).to_upper()


## One place the leader is worked out, shared by layout, drawing and `-- cutawaytest`.
## Why: docs/why/MountPoints.md#cutaway-layout
static func label_leader(at: Vector2, box: Rect2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var g := box.grow(2.0)
	var to := Vector2(clampf(at.x, g.position.x, g.end.x - 1.0), clampf(at.y, g.position.y, g.end.y - 1.0)).floor()
	var r0 := (R + 2.0) * k
	var d := to - at
	if d.length() <= r0 + 2.0:
		return out
	var from := (at + d.normalized() * r0).floor()
	# Bresenham: one pixel per step along the longer axis, no doubled corners
	var x0 := int(from.x)
	var y0 := int(from.y)
	var x1 := int(to.x)
	var y1 := int(to.y)
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		out.append(Vector2(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return out


## Every word and lifted part as drawn, for `-- cutawaytest` overlap checks.
## Why: docs/why/MountPoints.md#cutaway-layout
func parts_rect() -> Rect2:
	var out := Rect2()
	var k := _mag()
	for s in _spots:
		var m: ModuleData = s.held
		if not shows(m):
			continue
		var r := part_rect(m, s.slot, s.at, k)
		out = r if out.size.x <= 0.0 else out.merge(r)
	return out


func drawn_rects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if explode <= 0.0:
		return out
	var k := _mag()
	var f := UITheme.pixel_font()
	for s in _spots:
		var m: ModuleData = s.held
		if m != null:
			var r := part_rect(m, s.slot, _part_at(s), k)
			out.append({kind = "part", rect = r, text = m.name})
			if tags and explode > 0.85:
				var txt := m.name.to_upper()
				var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
				out.append({kind = "tag", rect = tag_box(r, String(tag_side.get(spot_key(int(s.slot), int(s.index)), "R")), w), text = txt})
		elif explode > 0.85 and _shows_empty(s):
			var off: Variant = tag_side.get("empty:" + spot_key(int(s.slot), int(s.index)))
			if off is Vector2:
				var txt := empty_text(int(s.slot))
				var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
				out.append({kind = "label", rect = label_box(s.at, off, w, k), text = txt})
	return out


## The leaders drawn now, for `-- cutawaytest`.
func empty_leaders() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if explode <= 0.85:
		return out
	var k := _mag()
	var f := UITheme.pixel_font()
	for s in _spots:
		if s.held != null or not _shows_empty(s):
			continue
		var key := spot_key(int(s.slot), int(s.index))
		var off: Variant = tag_side.get("empty:" + key)
		if not off is Vector2 or not tag_side.get("lead:" + key, false):
			continue
		var txt := empty_text(int(s.slot))
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
		var box := label_box(s.at, off, w, k)
		out.append({at = s.at, rect = box, points = label_leader(s.at, box, k), text = txt})
	return out


## WHETHER A POINT IS ON SOMETHING THE CUTAWAY DREW:a lifted part, a tag, an
## empty mount's ring or its words. A click there is not a click on the sky.
func hit_drawn(p: Vector2) -> bool:
	if explode <= 0.0:
		return false
	for d in drawn_rects():
		if (d.rect as Rect2).grow(2.0).has_point(p):
			return true
	for s in _spots:
		if s.held == null and _shows_empty(s) and (s.at as Vector2).distance_to(p) <= (R + 3.0) * _mag():
			return true
	return false


## Whether the cutaway shows this empty mount now: only while a part that fits
## it is carried.
func _shows_empty(s: Dictionary) -> bool:
	return tags and explode > 0.5 and _takes_spot(s)


## The one answer to whether a drop lands; cursor, marks and `RunState.refit_allowed` all agree.
## Why: docs/why/MountPoints.md#drop-rule
func takes(m: ModuleData, origin: StringName, slot: ModuleData.Slot, index: int) -> bool:
	if m == null or ship != null or _passive:
		return false
	if origin == &"bag" and not Run.has_room_for(m):
		return false
	var lifted_from := 0 if origin == &"hull" and not Run.installed.has(m) else -1
	return Run.refit_allowed(m, slot, index, lifted_from)


func _takes_spot(s: Dictionary) -> bool:
	return _lit != null and takes(_lit, _lit_origin, s.slot as ModuleData.Slot, int(s.index))


## Cutaway parts stand past the widget's rect, so any point on a drawn thing counts as inside.
func _has_point(p: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(p) or hit_drawn(p)


## An EMPTY mount in the cutaway, while a part that fits it is carried: what it
## takes, in words beside its ring (the ring is the ping, drawn in `_draw`).
func _empty_words(s: Dictionary, k: float) -> void:
	var a := clampf((explode - 0.5) / 0.5, 0.0, 1.0)
	if explode < 0.85:
		return
	# where the cutaway found room for the words (art px off the ring's
	# centre); no entry, no room: the ring alone
	var off: Variant = tag_side.get("empty:" + spot_key(int(s.slot), int(s.index)))
	if not off is Vector2:
		return
	var f := UITheme.pixel_font()
	var txt := empty_text(int(s.slot))
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	var box := label_box(s.at, off, w, k)
	var col := Color(UITheme.COLD, a)
	draw_string(f, box.position + Vector2(0, f.get_ascent(UITheme.FS_SMALL)), LowHull.scr(self, txt, UITheme.FS_SMALL, f), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, col)
	# set away from its ring: a 1 px leader back to it, in the words' own ink
	if tag_side.get("lead:" + spot_key(int(s.slot), int(s.index)), false):
		for p in label_leader(s.at, box, k):
			draw_rect(Rect2(p, Vector2.ONE), col)


func _ring(at: Vector2, r: float, col: Color) -> void:
	draw_arc(at, r, 0.0, TAU, 18, col, maxf(1.0, _mag()))

## Parts are drawn by this node, not nodes of their own, so the cursor must be position-keyed.
## Why: docs/why/MountPoints.md#cursor-shape
func _get_cursor_shape(at: Vector2) -> CursorShape:
	if _passive or part_under(at) == null:
		return Control.CURSOR_ARROW
	return Control.CURSOR_POINTING_HAND


## The installed part under a point; a caller that flips it does not care which hardpoint.
func part_under(p: Vector2) -> ModuleData:
	var k := _mag()
	for i in _spots.size():
		var m: ModuleData = _spots[i].held
		if not shows(m):
			continue
		if part_rect(m, _spots[i].slot, _part_at(_spots[i]), k).grow(2.0).has_point(p):
			return m
	return null

## An installed part is grabbed anywhere on it; an empty mount is a point with a radius.
## Why: docs/why/MountPoints.md#hit-testing
func _get_tooltip(at: Vector2) -> String:
	if not tooltips:
		return ""
	var i := spot_at(at)
	_tip_for = _spots[i].held if i >= 0 else null
	# Return the name: Godot needs a non-empty string, and `_make_custom_tooltip` builds the panel.
	return String(_tip_for.name) if _tip_for != null else ""


## Off in the cutaway, which shows its own popup beside the part (the MODULES
## page's, `ModuleIcon.tip_for`); one hover, one popup.
var tooltips := true


## What the last hover asked about. Set by `_get_tooltip`, which Godot always
## calls first, and read by the builder below.
var _tip_for: ModuleData = null


func _make_custom_tooltip(_for_text: String) -> Object:
	if _tip_for == null:
		return null
	return Widgets.module_tip_panel(_tip_for)


func spot_at(p: Vector2) -> int:
	var k := _mag()
	for i in _spots.size():
		var m: ModuleData = _spots[i].held
		if m != null and part_rect(m, _spots[i].slot, _part_at(_spots[i]), k).has_point(p):
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

## `origin` tells the far end which journey this is: cell to cell, or off the ship.
## Why: docs/why/MountPoints.md#taking-parts-off
func _get_drag_data(at: Vector2) -> Variant:
	var i := spot_at(at)
	if i < 0:
		return null
	var m: ModuleData = _spots[i].held
	if m == null:
		return null
	# Same ghost as the hold, at the part's current place, so the plate starts over the gun.
	set_drag_preview(ModuleIcon.ghost_for(m, &"hull",
		get_global_rect().position
		+ part_rect(m, _spots[i].slot, _part_at(_spots[i]), _mag()).position))
	# Off the ship once in hand, or its origin mount stays full and will not ping.
	# Why: docs/why/MountPoints.md#lifting-a-part
	if ship != null:
		# The live hull's lift plays in the screen's `_on_lift`; a foreign hull
		# has no such handler, so its lift sounds here.
		Audio.play(&"hold_lift", 0.08)
		return {module = m, origin = &"oldhull"}
	lifted.emit(m)
	return {module = m, origin = &"hull"}

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	# A hardpoint, so only a MODULE answers: a material has no slot and cannot
	# bolt to a hull. `dragged_module` is the refusal.
	var m := Widgets.dragged_module(data)
	if m == null:
		return false
	# Nothing is fitted to a ship you are abandoning: its old frame is a source only.
	if ship != null:
		return false
	var origin := StringName((data as Dictionary).get("origin", &""))
	if _lit != m or _lit_origin != origin:
		_lit = m
		_lit_origin = origin
		queue_redraw()
	var i := spot_at(at)
	if i < 0 or (_spots[i].slot as ModuleData.Slot) != m.slot:
		return false
	# Refuse here, while still holding the part: a silent refusal after accepting reads as broken.
	# Why: docs/why/MountPoints.md#drop-rule
	return takes(m, origin, _spots[i].slot as ModuleData.Slot, int(_spots[i].index))

func _drop_data(at: Vector2, data: Variant) -> void:
	var m := Widgets.dragged_module(data)
	var i := spot_at(at)
	_unlight()
	if i < 0 or m == null:
		return
	if (_spots[i].slot as ModuleData.Slot) != m.slot:
		return
	dropped.emit(data as Dictionary, _spots[i].slot, _spots[i].index)

func _unlight() -> void:
	_lit_origin = &""
	if _lit == null:
		return
	_lit = null
	queue_redraw()

func _notification(what: int) -> void:
	# Godot has no drag-left signal: clear on mouse exit and any drag end, or the hull stays lit.
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_hover = Vector2.INF
		# Marks last the whole drag, so the hull still says where the part goes over the hold.
		if what == NOTIFICATION_DRAG_END or not (is_inside_tree() and get_viewport().gui_is_dragging()):
			_unlight()
		# Repaint even if nothing was lit: hover hints draw off `_hover`, queuing no frame.
		# Why: docs/why/MountPoints.md#stale-hints
		queue_redraw()
	if what == NOTIFICATION_DRAG_END:
		# After any drop has been processed, which is what makes this the place
		# to notice that a lifted part is now in neither the hull nor the hold.
		released.emit()
	elif what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		# Cargo rides the same "module" key, and a material has no mount to light.
		if typeof(data) == TYPE_DICTIONARY and (data as Dictionary).get("module") is ModuleData:
			light((data as Dictionary).module, StringName((data as Dictionary).get("origin", &"")))

## `_gui_input`, not `_process`: the global mouse would light the ship with the cursor elsewhere.
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


## Public so `-- fittest` can put the hull in a live drag's state; idempotent, as hover fires often.
func focus(m: ModuleData) -> void:
	if _focus == m:
		return
	_focus = m
	queue_redraw()

func light(m: ModuleData, origin: StringName = &"") -> void:
	_lit = m
	_lit_origin = origin if m != null else &""
	queue_redraw()
