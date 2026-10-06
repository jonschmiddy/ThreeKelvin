class_name CutawayView
extends Control

## THE CUTAWAY (Jon: "THE CUTAWAY IS CLEANNNN."; scratchpad `local_role/cutaway`
## and notes section 4). On LOCAL, out of a fight, click your own ship: the
## camera eases in on it, the sky behind breaks up the way it does behind the
## escape menu (`pause_backdrop.gdshader`, Jon: "the same pixelated treatment"),
## every fitted part lifts off its mount on a dotted leader line to a labelled
## tag, empty mounts show as rings, and the SHELF rises: the hold, the ship's
## name and numbers, the nearest wreck's bay and this system's own loot, each
## with TAKE ALL. Point at a part and its cards are on the right. Drag between
## the hold, the loot and the rings on the hull. Close with a click on the ship
## or the sky, Esc, or DONE.
##
## EVERY MOVE IS RUN'S RULE (`RunState.lift_part` / `fit_at_mount` / `stow_at`),
## the same calls the refit screen makes, so the two cannot disagree; the loot is
## claimed through `Run.take_item` / `take_from_jetsam`, the same calls the
## map's SECTOR LOOT popup (`TransferView`) makes, so taking a thing in one shows
## it gone in the other. Local only: nothing here is sent over the network
## beyond what those calls already send.
##
## The hull is drawn here at the push-in's scale (2x wherever the lifted parts
## and their tags can be fitted round it above the shelf -- on the heavy by
## showing the panel only on hover and resting the shelf a little low, see
## `_choose_scale` -- else 1x: a 960x540 game has no clean 1.5x), and LOCAL's
## own hull is hidden while it is open, so the backdrop the shader breaks up is
## the sky and everything in it but your ship.

signal closed

const EASE_S := 0.4
const PANEL_W := 250
const BACKDROP := preload("res://shaders/pause_backdrop.gdshader")
## Above the shelf and left of the panel, the room the exploded ship must fit in.
const MARGIN := 8.0
## How far the shelf may rest below its own top: part of the hold's last row.
const SINK := 30.0

var _src: ShipView
var _scrim: ColorRect
var _mat: ShaderMaterial
var _stage: Control
var _ship: ShipView
var _mounts: MountPoints
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _shelf: PanelContainer
var _hold: HoldGrid
var _hold_label: Label
var _name: Label
var _class: Label
var _attrs: AttrBlock
var _mount_line: Label
var _wreck_label: Label
var _wreck_grid: SalvageGrid
var _wreck_take: Button
var _loot_label: Label
var _loot_grid: SalvageGrid
var _loot_take: Button
var _loot_empty: Label
var _say: Label
var _done: Button

## The push-in's scale, and where the exploded ship's art origin lands.
var k: int = 2
var _target := Vector2.ZERO
var _from := Vector2.ZERO
var _from_s := 1.0
var _shelf_top := 300.0
var _shelf_h := 220.0
## Where the shelf rests: its top, or lower by up to SINK when that is what lets
## the ship be drawn at 2x (the heavy). It rises to its top while the pointer is
## on it, so the whole hold is there to drop on, and sinks back when it leaves.
var _shelf_rest := 300.0
var _shelf_up := false
## 0 LOCAL .. 1 the cutaway, and where it is heading
var t := 0.0
var _goal := 1.0
var _lifted: ModuleData = null
var _lifted_mount := -1
var _busy := false
var _shown: HoldItem = null
var _wreck: MapGen.Jetsam = null
var _say_until := 0
## What the push-in's scale was chosen from, for the harnesses.
var fit_note := ""
## The heavy's rung: the ship across the whole width and the panel shown only
## while something is pointed at, docked away from the pointer, hidden in a drag.
var hover_panel := false
var _room := Rect2()
var _layout_ok := true
var _offs_cache := {}
var _last_gp := Vector2.INF
## For the harness's clips: the push-in's clock advances this much a frame
## instead of the frame's real time, so a film at 30 a second shows the real
## 0.4 s however slowly the window drew. 0 is the real clock.
static var fixed_step := 0.0


## Open over `host`, from LOCAL's own hull `src`.
static func open_over(host: Control, src: ShipView) -> CutawayView:
	var c := CutawayView.new()
	c._src = src
	host.add_child(c)
	c._build()
	return c


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ease(x: float) -> float:
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


func _build() -> void:
	# THE SKY, BROKEN UP AS IT IS BEHIND THE ESCAPE MENU: the shared shader, on a
	# rect drawn before the ship, the panel and the shelf, so it reads only what
	# is behind them (the HUD is outside this rect and stays sharp)
	_scrim = ColorRect.new()
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = BACKDROP
	_mat.set_shader_parameter(&"amount", 0.0)
	_scrim.material = _mat
	add_child(_scrim)

	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_ship = ShipView.new()
	_ship.self_clip = false
	_ship.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_ship)
	_ship.zoom(1)
	_mounts = MountPoints.new()
	_mounts.attach(_ship)
	_ship.add_child(_mounts)
	_mounts.dropped.connect(_on_mount_drop)
	_mounts.lifted.connect(_on_lift)
	_mounts.released.connect(_on_release)
	_mounts.gui_input.connect(_on_hull_input)

	_build_panel()
	_build_shelf()
	Sig.ship_changed.connect(_on_ship_changed)
	# (and when a pile here changes: a partner took something, an event paid out)
	Sig.map_changed.connect(_on_ship_changed)
	_measure.call_deferred()


## Sizes, the push-in's scale and where everything lands; then the ease in.
func _measure() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	var rows := Run.hold_grid().y
	# (as tight as the hold allows: the heavy's hull is 268 px tall at 2x, and
	# its five rows of hold leave 270 above the shelf at this, 262 at +40)
	_shelf_h = maxf(196.0, float(rows * HoldGrid.CELL) + 32.0)
	_shelf_top = size.y - _shelf_h
	_shelf.position = Vector2(0, size.y)
	_shelf.size = Vector2(size.x, _shelf_h)
	_panel.position = Vector2(size.x - PANEL_W - MARGIN, MARGIN)
	_panel.size = Vector2(PANEL_W, _shelf_top - MARGIN * 2.0)
	_choose_scale()
	# FROM LOCAL'S OWN HULL: its art origin on screen and its scale
	if _src != null and is_instance_valid(_src):
		var g := _src.get_global_transform()
		_from = get_global_transform().affine_inverse() * (g * _src.canvas_to_local(Vector2.ZERO))
		_from_s = _src.art_scale() * g.get_scale().x
		_src.visible = false
	else:
		_from = _target
		_from_s = float(k)
	_refresh()
	t = 0.0
	_goal = 1.0
	if not Router.animating():
		t = 1.0
	_apply()
	Audio.play(&"hold_lift", 0.05)


## THE PUSH-IN'S SCALE, PER HULL, tried in order until the exploded ship -- its
## hull, every part lifted clear of it and every tag -- fits above the shelf:
##   2x beside the panel (the light and the medium: what Jon saw);
##   2x across the whole width, the panel shown only while something is pointed
##   at (the heavy: its parts beside the hull, not above and below it -- 150 px
##   of hull at 2x leaves no height for them over a 30-cell hold);
##   the same with the shelf resting up to SINK lower, rising when pointed at
##   (the heavy in the game: a 268 px hull over a five-row hold);
##   1x beside the panel, last.
## (1.5x would double every other pixel on a 960x540 picture.)
func _choose_scale() -> void:
	var docked := Rect2(MARGIN, MARGIN, size.x - PANEL_W - MARGIN * 3.0, _shelf_top - MARGIN * 2.0)
	var wide := Rect2(MARGIN, MARGIN, size.x - MARGIN * 2.0, _shelf_top - MARGIN * 2.0)
	var sunk := Rect2(MARGIN, MARGIN, size.x - MARGIN * 2.0, _shelf_top + SINK - MARGIN * 2.0)
	fit_note = ""
	_shelf_rest = _shelf_top
	var rungs := [[2, docked, false], [2, wide, true], [2, sunk, true], [1, docked, false]]
	for i in rungs.size():
		var kk: int = rungs[i][0]
		var room: Rect2 = rungs[i][1]
		var b := _layout(kk, room)
		# (every part and word is inside the room by construction; a ring on the
		# hull's very edge may stand a few px past it, into the margin, not more)
		var fits := _layout_ok and b.size.x * kk <= room.size.x + MARGIN and b.size.y * kk <= room.size.y + MARGIN
		fit_note += "%dx%s%s %s in %dx%d; " % [kk, " (panel on hover)" if rungs[i][2] else "",
			" (shelf resting lower)" if room == sunk else "",
			("fits, %dx%d" % [int(b.size.x * kk), int(b.size.y * kk)]) if fits else "does not fit",
			int(room.size.x), int(room.size.y)]
		if fits or i == rungs.size() - 1:
			k = kk
			_room = room
			hover_panel = rungs[i][2]
			_ship.zoom(k)
			_ship.size = Vector2(_ship.canvas_width(), _ship.canvas_height())
			_mounts.refresh()
			b = _layout(k, room)
			# the frame the picture is centred in: the room, or on the sunk rung
			# only as much of it as this ship needs, the shelf resting just below
			var frame := room
			if room == sunk:
				var h := clampf(b.size.y * kk - MARGIN, wide.size.y, sunk.size.y)
				frame = Rect2(room.position, Vector2(room.size.x, ceilf(h)))
				_shelf_rest = frame.end.y + MARGIN
			_target = (frame.get_center() - b.get_center() * float(k)).round()
			_dock(false)
			return


## THE EXPLODED LAYOUT, in sprite pixels at scale `kk`, inside `room` (screen
## px, the hull centred in it). Each fitted part goes to the NEAREST place --
## straight out first, sideways costing a little more -- where it and its tag
## are inside the room, off the hull's own pixels and clear of every part, tag
## and ring already placed; its tag beside it (toward the hull's middle first)
## or above or below it, which is what lets parts stack in narrow columns off a
## heavy's nose and tail. Then each empty mount's words, near its ring, or none.
## The boxes are the ones `MountPoints` draws (`tag_box`, `label_box`), so what
## is kept apart here is what is on screen. Written into the mounts widget
## (`lift`, `tag_side`); `_layout_ok` says whether everything found a place.
## Returns the whole picture's bounds, in sprite px.
func _layout(kk: int, room: Rect2) -> Rect2:
	var img := _ship.canvas()
	var h := Run.hull
	var lift := {}
	var sides := {}
	_layout_ok = true
	if img == null or h == null:
		return Rect2(0, 0, 200, 80)
	var w := img.get_width()
	var ht := img.get_height()
	# the hull's pixels as a summed-area table: "is anything of the hull in this
	# rect" in four reads, whatever the rect's size
	var sat := PackedInt32Array()
	sat.resize((w + 1) * (ht + 1))
	for y in ht:
		var row := 0
		for x in w:
			if img.get_pixel(x, y).a > 0.1:
				row += 1
			sat[(y + 1) * (w + 1) + x + 1] = sat[y * (w + 1) + x + 1] + row
	var on_hull := func(r: Rect2) -> bool:
		var x0 := clampi(int(floor(r.position.x)), 0, w)
		var y0 := clampi(int(floor(r.position.y)), 0, ht)
		var x1 := clampi(int(ceil(r.end.x)), 0, w)
		var y1 := clampi(int(ceil(r.end.y)), 0, ht)
		if x1 <= x0 or y1 <= y0:
			return false
		return sat[y1 * (w + 1) + x1] - sat[y0 * (w + 1) + x1] - sat[y1 * (w + 1) + x0] + sat[y0 * (w + 1) + x0] > 0
	var ink := Rect2(_ship.ink_rect())
	var rs := Rect2(ink.get_center() - room.size / (2.0 * kk), room.size / float(kk))
	var bounds := ink
	var f := UITheme.pixel_font()
	var placed: Array[Rect2] = []
	var free := func(r: Rect2, pad: float) -> bool:
		if not rs.encloses(r) or on_hull.call(r.grow(pad)):
			return false
		for q in placed:
			if r.grow(1.5).intersects(q):
				return false
		return true
	var offs := _offsets(rs.size)
	var parts: Array = []
	var empties: Array = []
	for slot in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		var pts := h.mounts_along(slot, Run.slots_for(slot))
		for i in pts.size():
			var m := Run.module_at(slot, i)
			if m == null:
				empties.append([slot, i, pts[i]])
			else:
				parts.append([slot, i, pts[i], m])
	# the rings first: a part never lands on one
	for e in empties:
		var ring := Rect2((e[2] as Vector2) - Vector2.ONE * (MountPoints.R + 1.0), Vector2.ONE * (MountPoints.R + 1.0) * 2.0)
		placed.append(ring)
		bounds = bounds.merge(ring)
	# the biggest parts first: they have the fewest places to go
	parts.sort_custom(func(a: Array, c: Array) -> bool:
		return _mounts.part_rect(a[3], a[0], a[2], 1.0).get_area() > _mounts.part_rect(c[3], c[0], c[2], 1.0).get_area())
	for p in parts:
		var slot: ModuleData.Slot = p[0]
		var pt: Vector2 = p[2]
		var m: ModuleData = p[3]
		var key := MountPoints.spot_key(slot, int(p[1]))
		var b := _mounts.part_rect(m, slot, pt, 1.0)
		var tw := f.get_string_size(m.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
		var order: Array[String] = []
		order.append_array(["L", "R"] if pt.x > ink.get_center().x else ["R", "L"])
		order.append_array(["T", "B"])
		var found := false
		for o in offs:
			var pr := Rect2(b.position + o, b.size)
			if not free.call(pr, 2.0):
				continue
			for sd in order:
				var tag := _sprite_box(MountPoints.tag_box(_px(pr, kk), sd, tw), kk)
				if not tag.intersects(pr) and free.call(tag, 1.0):
					lift[key] = o
					sides[key] = sd
					placed.append(pr)
					placed.append(tag)
					bounds = bounds.merge(pr).merge(tag)
					found = true
					break
			if found:
				break
		if not found:
			# nowhere inside this room: straight up off the hull, and say so
			_layout_ok = false
			var o := Vector2(0, (ink.position.y - 5.0) - b.end.y)
			lift[key] = o
			sides[key] = order[0]
			var pr := Rect2(b.position + o, b.size)
			placed.append(pr)
			bounds = bounds.merge(pr)
	# THE EMPTY MOUNTS' WORDS, near the ring, off the hull and everything placed;
	# a ring with no room for them keeps the ring alone (an "EMPTY WEAPON" laid
	# over the hull plating read as part of it)
	for e in empties:
		var pt: Vector2 = e[2]
		var key := MountPoints.spot_key(int(e[0]), int(e[1]))
		var lw := f.get_string_size(MountPoints.empty_text(int(e[0])), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
		for o in offs:
			if absf(o.y) > MountPoints.R + 14.0 or absf(o.x) > lw / (2.0 * kk) + MountPoints.R + 6.0:
				continue
			var r := _sprite_box(MountPoints.label_box(pt * kk, o, lw, kk), kk)
			if free.call(r, 1.0):
				sides["empty:" + key] = o
				placed.append(r)
				bounds = bounds.merge(r)
				break
	_mounts.lift = lift
	_mounts.tag_side = sides
	return bounds


## Every offset from a mount inside a room this size, every 2 sprite px, nearest
## first (sideways counts 1.3x, so straight out wins a tie). Sorted natively and
## kept: the layout runs on every change to the ship.
func _offsets(room: Vector2) -> Array[Vector2]:
	var key := "%d:%d" % [int(room.x), int(room.y)]
	if _offs_cache.has(key):
		return _offs_cache[key]
	var nx := int(room.x / 2.0)
	var ny := int(room.y / 2.0)
	var keys := PackedInt64Array()
	var all: Array[Vector2] = []
	for iy in range(-ny, ny + 1):
		for ix in range(-nx, nx + 1):
			var o := Vector2(ix * 2, iy * 2)
			keys.append((int(Vector2(o.x * 1.3, o.y).length() * 16.0) << 24) | all.size())
			all.append(o)
	keys.sort()
	var out: Array[Vector2] = []
	out.resize(keys.size())
	for i in keys.size():
		out[i] = all[keys[i] & 0xFFFFFF]
	_offs_cache[key] = out
	return out


## A sprite-px rect at scale `kk` in screen px (what the boxes are measured in),
## and back.
static func _px(r: Rect2, kk: int) -> Rect2:
	return Rect2(r.position * kk, r.size * kk)


static func _sprite_box(r: Rect2, kk: int) -> Rect2:
	return Rect2(r.position / kk, r.size / kk)


func _process(delta: float) -> void:
	if _goal != t:
		var sp := (fixed_step if fixed_step > 0.0 else delta) / EASE_S
		t = minf(_goal, t + sp) if _goal > t else maxf(_goal, t - sp)
		if not Router.animating():
			t = _goal
		_apply()
		if t <= 0.0 and _goal <= 0.0:
			_finish_close()
			return
	elif t >= 1.0 and _shelf.position.y != _shelf_at():
		# the resting shelf rising to the pointer and sinking back: quick, in
		# whole pixels, cut under reduced motion
		var to := _shelf_at()
		var step := 360.0 * (fixed_step if fixed_step > 0.0 else delta)
		var y := move_toward(_shelf.position.y, to, maxf(step, 1.0))
		_shelf.position.y = roundf(y) if Router.animating() else to
	if _say != null and _say.visible and Time.get_ticks_msec() > _say_until:
		_say.visible = false


## The camera, the backdrop, the parts and the shelf at progress `t`.
func _apply() -> void:
	var e := _ease(t)
	# whole pixels: the hull's drawn width a whole number, its origin on the grid
	var s := lerpf(_from_s, float(k), e)
	var cw := maxf(_ship.canvas_width() / float(k), 1.0)
	s = roundf(s * cw) / cw
	_stage.scale = Vector2.ONE * (s / float(k))
	_stage.position = _from.lerp(_target, e).round()
	_mat.set_shader_parameter(&"amount", e)
	var x := clampf((e - 0.35) / 0.65, 0.0, 1.0)
	_mounts.explode = x
	_mounts.tags = x > 0.0
	_mounts.queue_redraw()
	_panel.modulate.a = x
	_panel_vis()
	_shelf.position.y = roundf(lerpf(size.y, _shelf_at(), e))


## Where the shelf's top belongs now: its own top, or resting lower until the
## pointer is on it.
func _shelf_at() -> float:
	return _shelf_top if _shelf_up else _shelf_rest


func is_open() -> bool:
	return _goal > 0.0


func close() -> void:
	if _goal <= 0.0:
		return
	if _lifted != null:
		Run.unlift_part(_lifted, _lifted_mount)
		_lifted = null
	_goal = 0.0
	Audio.play(&"hold_stow", 0.05)
	if not Router.animating():
		t = 0.0
		_apply()
		_finish_close()


func _finish_close() -> void:
	if _src != null and is_instance_valid(_src):
		_src.visible = true
	closed.emit()
	queue_free()


# --------------------------------------------------------------- the panel

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel",
		UITheme.flat(Color(UITheme.PANEL, 0.96), UITheme.LINE, 1, 10, 10))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.clip_contents = true
	add_child(_panel)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 4)
	_panel.add_child(_panel_box)


## Whether the panel shows: beside the ship, once it is out; on the heavy's
## rung, only while something is pointed at and nothing is carried.
func _panel_vis() -> void:
	var out := _panel.modulate.a > 0.01
	if hover_panel:
		out = out and _shown != null and not _carrying()
	_panel.visible = out


func _carrying() -> bool:
	var d: Variant = get_viewport().gui_get_drag_data() if is_inside_tree() else null
	return typeof(d) == TYPE_DICTIONARY and (d as Dictionary).get("module") is HoldItem


## The panel against the right edge, or (on the heavy's rung, pointing at
## something on the right half) the left.
func _dock(left: bool) -> void:
	_panel.position = Vector2(MARGIN if left else size.x - PANEL_W - MARGIN, MARGIN)


## WHAT IS POINTED AT: a part's name, its manufacturer, rarity, size and slot, its line
## and its cards; or, pointing at nothing, the ship and how to use this.
func _show(m: HoldItem) -> void:
	if hover_panel and m != null and _last_gp.x < INF:
		_dock(_last_gp.x > get_global_rect().get_center().x)
	if m == _shown and _panel_box.get_child_count() > 0:
		_panel_vis()
		return
	_shown = m
	_panel_vis()
	Widgets.clear(_panel_box)
	if m == null:
		_panel_box.add_child(UITheme.body(Run.display_name().to_upper(), UITheme.ICE, UITheme.FS_BODY))
		_panel_box.add_child(UITheme.body(_class_line(), _accent(), UITheme.FS_SMALL))
		_panel_box.add_child(UITheme.hsep())
		# one line: the rings pulse when something is carried, which says the rest
		_panel_box.add_child(UITheme.body("POINT AT A PART TO READ ITS CARDS.", UITheme.CHILL, UITheme.FS_SMALL))
		return
	_panel_box.add_child(UITheme.body(m.name.to_upper(), UITheme.ICE, UITheme.FS_BODY))
	var mod := m as ModuleData
	if mod == null:
		_panel_box.add_child(UITheme.body("%d X %d · CARGO" % [m.size.x, m.size.y], UITheme.COLD, UITheme.FS_SMALL))
		return
	_panel_box.add_child(UITheme.body("%s · %s · %d X %d · %s" % [
		DB.manufacturer_name(mod.manufacturer).to_upper() if mod.manufacturer != &"" else "UNBRANDED",
		ModuleData.rarity_name(mod.rarity), mod.size.x, mod.size.y,
		ModuleData.slot_name(mod.slot).to_upper()], ModuleData.rarity_ink(mod.rarity), UITheme.FS_SMALL))
	if mod.flavour != "":
		var fl := UITheme.body(mod.flavour.to_upper(), UITheme.COLD, UITheme.FS_SMALL)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size = Vector2(PANEL_W - 22, 0)
		_panel_box.add_child(fl)
	var cards := mod.resolved_cards()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_box.add_child(row)
	var seen := {}
	for c in cards:
		if seen.has(c.name) or seen.size() >= 2:
			continue
		seen[c.name] = true
		var v := CardView.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(v)
		v.setup(c, true, 1)
	_panel_box.add_child(UITheme.body("GRANTS %d CARD%s · FITS A %s MOUNT" % [cards.size(),
		"" if cards.size() == 1 else "S", ModuleData.slot_name(mod.slot).to_upper()], UITheme.CHILL, UITheme.FS_SMALL))


# --------------------------------------------------------------- the shelf

func _build_shelf() -> void:
	_shelf = PanelContainer.new()
	_shelf.add_theme_stylebox_override("panel",
		UITheme.flat(Color(UITheme.PANEL, 0.98), UITheme.LINE, 1, 8, 10))
	_shelf.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shelf)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_shelf.add_child(row)

	# THE HOLD
	var hc := VBoxContainer.new()
	hc.add_theme_constant_override("separation", 4)
	row.add_child(hc)
	_hold_label = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	hc.add_child(_hold_label)
	_hold = HoldGrid.new()
	_hold.dropped.connect(_on_hold_drop)
	hc.add_child(_hold)

	# THE SHIP
	var sc := VBoxContainer.new()
	sc.add_theme_constant_override("separation", 3)
	sc.custom_minimum_size = Vector2(196, 0)
	row.add_child(sc)
	_name = UITheme.body("", UITheme.ICE, UITheme.FS_BODY)
	sc.add_child(_name)
	_class = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	sc.add_child(_class)
	_attrs = AttrBlock.new()
	sc.add_child(_attrs)
	_mount_line = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	sc.add_child(_mount_line)

	# THE WRECK'S BAY: the nearest hull you killed here that still holds something
	var wc := VBoxContainer.new()
	wc.add_theme_constant_override("separation", 4)
	row.add_child(wc)
	_wreck_label = UITheme.body("", UITheme.THEM, UITheme.FS_SMALL)
	wc.add_child(_wreck_label)
	_wreck_grid = _loot_box(wc, func(m: HoldItem) -> bool:
		return _wreck != null and Run.put_in(Run.node_at(), _wreck, m))
	_wreck_take = Widgets.button("TAKE ALL", func() -> void: _take_all(_wreck))
	_wreck_take.custom_minimum_size = Vector2(92, 18)
	_wreck_take.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wc.add_child(_wreck_take)

	# THIS SYSTEM'S LOOT (Jon: "the bottom right is good for sector
	# loot/salvage/rewards"): the system's own pile, what an event paid into it
	# and what you have put down here -- the map's SECTOR LOOT
	var lc := VBoxContainer.new()
	lc.add_theme_constant_override("separation", 4)
	lc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lc)
	_loot_label = UITheme.body("THIS SYSTEM'S LOOT", UITheme.CHILL, UITheme.FS_SMALL)
	lc.add_child(_loot_label)
	_loot_empty = UITheme.body("NOTHING LOOSE HERE", UITheme.COLD, UITheme.FS_SMALL)
	lc.add_child(_loot_empty)
	_loot_grid = _loot_box(lc, func(m: HoldItem) -> bool:
		var n: MapGen.MapNode = Run.node_at()
		return n != null and Run.put_in(n, Run.sector_jetsam(n, true), m))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	lc.add_child(btns)
	_loot_take = Widgets.button("TAKE ALL", func() -> void:
		var n: MapGen.MapNode = Run.node_at()
		_take_all(Run.sector_jetsam(n, false) if n != null else null))
	_loot_take.custom_minimum_size = Vector2(92, 18)
	btns.add_child(_loot_take)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(sp)
	_done = Widgets.button("DONE · ESC", close)
	_done.custom_minimum_size = Vector2(104, 22)
	btns.add_child(_done)
	_say = UITheme.body("", UITheme.TRACTOR, UITheme.FS_SMALL)
	_say.visible = false
	lc.add_child(_say)


func _loot_box(parent: Control, put: Callable) -> SalvageGrid:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(4 * HoldGrid.CELL, 2 * HoldGrid.CELL)
	parent.add_child(scroll)
	var g := SalvageGrid.new()
	g.on_put = put
	g.picked.connect(func(_m: HoldItem) -> void: _refresh())
	scroll.add_child(g)
	return g


func _class_line() -> String:
	var mf: ManufacturerData = DB.manufacturers.get(Run.hull.manufacturer) if Run.hull != null else null
	return "%s · %s · %s" % [mf.name.to_upper() if mf != null else "UNBRANDED SALVAGE",
		HullData.weight_name(Run.hull.weight).to_upper(), Run.hull.tier_letter()]


func _accent() -> Color:
	var mf: ManufacturerData = DB.manufacturers.get(Run.hull.manufacturer) if Run.hull != null else null
	return mf.colour if mf != null else UITheme.CHILL


func _refresh() -> void:
	if Run.hull == null:
		return
	_hold.refresh()
	var g := Run.hold_grid()
	_hold_label.text = "HOLD · %d OF %d" % [Run.cargo_used(), g.x * g.y]
	_name.text = Run.display_name().to_upper()
	_class.text = _class_line()
	_class.add_theme_color_override("font_color", _accent())
	_attrs.setup(Run.attributes(), _accent())
	var fitted := 0
	var mounts := 0
	var cards := 0
	for slot in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		mounts += Run.slots_for(slot)
		fitted += Run.slots_used(slot)
	for m in Run.installed:
		cards += m.resolved_cards().size()
	_mount_line.text = "MOUNTS %d OF %d · %d CARDS" % [fitted, mounts, cards]
	var n: MapGen.MapNode = Run.node_at()
	# the wreck: the first here with something left, else the last you made
	_wreck = null
	if n != null:
		for raw in n.jetsam:
			var h: MapGen.Jetsam = raw
			if h.is_wreck() and (Run.jetsam_left(n, h) > 0 or _wreck == null):
				_wreck = h
				if Run.jetsam_left(n, h) > 0:
					break
	_fill(_wreck_grid, _wreck)
	_wreck_label.text = ("%s · WRECK" % _wreck.label) if _wreck != null else "NO WRECK HERE"
	_wreck_take.disabled = _wreck == null or Run.jetsam_left(n, _wreck) <= 0
	_wreck_grid.get_parent().visible = _wreck != null
	_wreck_take.visible = _wreck != null
	var pile := Run.sector_jetsam(n, false) if n != null else null
	var left := Run.jetsam_left(n, pile) if pile != null else 0
	_fill(_loot_grid, pile)
	_loot_empty.visible = left <= 0
	_loot_grid.get_parent().visible = left > 0
	_loot_take.disabled = left <= 0
	_layout(k, _room)
	_mounts.refresh()
	_show(null if _shown == null else _shown)


## A container's untaken things into a grid (taken ones are gone from it: they
## are in your hold, or somebody else's).
func _fill(g: SalvageGrid, h: MapGen.Jetsam) -> void:
	var n: MapGen.MapNode = Run.node_at()
	var items: Array = []
	if h != null and n != null:
		for i in h.items.size():
			if not n.taken.has(h.option(i)):
				items.append(h.items[i])
	g.setup(items, {}, 4)


func _on_ship_changed() -> void:
	if is_inside_tree():
		_refresh()


func _toast(s: String, bad: bool = false) -> void:
	_say.text = s
	_say.add_theme_color_override("font_color", UITheme.BAD if bad else UITheme.TRACTOR)
	_say.visible = true
	_say_until = Time.get_ticks_msec() + 1800


# --------------------------------------------------------------- moving parts
# Run's rule, every one of them (see the head of this file).

func _on_lift(m: ModuleData) -> void:
	if m == null or not Run.installed.has(m):
		return
	_lifted = m
	_lifted_mount = Run.lift_part(m)
	Audio.play(&"hold_lift", 0.08)


func _on_release() -> void:
	var m := _lifted
	_lifted = null
	if m == null or Run.installed.has(m) or Run.cargo.has(m):
		return
	Run.unlift_part(m, _lifted_mount)


## Onto a ring on the hull. From the loot, the thing is claimed into the hold
## first (the same claim SECTOR LOOT makes), then fitted from there.
func _on_mount_drop(payload: Dictionary, slot: ModuleData.Slot, index: int) -> void:
	var m: ModuleData = payload.get("module")
	if m == null or _busy:
		return
	if String(payload.get("origin", &"")) == "bag":
		_busy = true
		var got: bool = await Run.take_item(m)
		_busy = false
		if not got:
			_toast("NO ROOM IN THE HOLD FOR %s" % m.name.to_upper(), true)
			return
		Audio.play(TransferView._take_sound(m), 0.05)
	var r := Run.fit_at_mount(m, slot, index, _lifted_mount if m == _lifted else -1)
	if r == Run.Refit.REFUSED:
		return
	if r == Run.Refit.FITTED or m == _lifted:
		_lifted = null
	Audio.act(&"module_install")
	_toast(("FITTED %s" if r == Run.Refit.FITTED else "SWAPPED %s") % m.name.to_upper())
	_refresh()


## Onto a cell of the hold: from the hold, off the ship, or out of the loot.
func _on_hold_drop(payload: Dictionary, at: Vector2i) -> void:
	var m: HoldItem = payload.get("module")
	if m == null or _busy:
		return
	if String(payload.get("origin", &"")) == "bag":
		_busy = true
		var got: bool = await Run.take_item(m)
		_busy = false
		if not got:
			_toast("NO ROOM IN THE HOLD FOR %s" % m.name.to_upper(), true)
			return
		# where it was dropped, if it fits there (it is in the hold already)
		Run.stow_at(m, at)
		Audio.play(TransferView._take_sound(m), 0.05)
		_toast("TAKEN %s" % m.name.to_upper())
		_refresh()
		return
	if not Run.stow_at(m, at, m == _lifted):
		_refresh()
		return
	if m == _lifted:
		_lifted = null
		_toast("STORED %s" % m.name.to_upper())
	Audio.play(&"hold_stow", 0.08)
	_refresh()


## Everything left in one container, into the hold, as far as it will go.
func _take_all(h: MapGen.Jetsam) -> void:
	var n: MapGen.MapNode = Run.node_at()
	if h == null or n == null or _busy:
		return
	_busy = true
	var took := 0
	var left := 0
	for i in h.items.size():
		if n.taken.has(h.option(i)):
			continue
		if await Run.take_from_jetsam(n, h, i):
			took += 1
		else:
			left += 1
	_busy = false
	if took > 0:
		Audio.play(&"hold_stow", 0.05)
	if left > 0:
		_toast("NO ROOM IN THE HOLD FOR %d MORE" % left, true)
	elif took > 0:
		_toast("TAKEN %d" % took)
	_refresh()


# --------------------------------------------------------------- the pointer

func _input(e: InputEvent) -> void:
	if _goal <= 0.0:
		return
	var key := e as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
		return
	var mm := e as InputEventMouseMotion
	if mm != null:
		_point(mm.global_position)


## What is under the pointer, for the panel; while carrying, what is carried.
func _point(gp: Vector2) -> void:
	_last_gp = gp
	if _shelf_rest > _shelf_top:
		# up once the pointer reaches the resting shelf; down once it leaves the
		# risen one (with or without something in hand)
		var ly := (get_global_transform().affine_inverse() * gp).y
		_shelf_up = ly >= (_shelf_top - 2.0 if _shelf_up else _shelf_rest)
	var carried: Variant = get_viewport().gui_get_drag_data()
	if typeof(carried) == TYPE_DICTIONARY and (carried as Dictionary).get("module") is HoldItem:
		if hover_panel:
			# (the rings say where it goes; the panel would cover some of them)
			_panel_vis()
			return
		_show((carried as Dictionary).module)
		return
	var m: HoldItem = null
	var lp := _mounts.get_global_transform().affine_inverse() * gp
	m = _mounts.part_under(lp)
	if m == null:
		var ic := _hold.icon_at(gp)
		if ic != null:
			m = ic.held_item()
	if m == null:
		for g in [_wreck_grid, _loot_grid]:
			for c in (g as Control).get_children():
				if c is ItemIcon and (c as Control).get_global_rect().has_point(gp) and (c as Control).is_visible_in_tree():
					m = (c as ItemIcon).held_item()
	if m != null or not _panel.visible or not _panel.get_global_rect().has_point(gp):
		_show(m)


## A click on the hull that is not on a part closes, as a click on the sky does.
func _on_hull_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _mounts.part_under(mb.position) != null:
		return
	close()


func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and t >= 0.98:
		accept_event()
		close()


# --------------------------------------------------------------- the hover outline

## WHETHER A POINT (in `v`'s own coordinates) IS ON THE SHIP'S OWN PIXELS, give
## or take two: what the pointer has to be over for the click to open the
## cutaway, so the empty canvas round a hull is not a button.
static func on_hull(v: ShipView, p: Vector2) -> bool:
	var img := v.canvas()
	if img == null:
		return false
	var kk := v.art_scale()
	var origin := ((v.size - Vector2(v.canvas_width(), v.canvas_height())) * 0.5).floor()
	var c := ((p - origin) / maxf(kk, 0.5)).floor()
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var q := Vector2i(int(c.x) + dx, int(c.y) + dy)
			if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height() \
					and img.get_pixel(q.x, q.y).a > 0.1:
				return true
	return false


## THE AMBER OUTLINE IN THE HULL'S OWN PIXELS, while the pointer is on your ship:
## every clear pixel touching an opaque one, so the line hugs the silhouette and
## nothing else on screen gets one. A child of the ship's view, so it rides its
## bob; re-traced when the bob steps.
class Outline extends Control:
	var view: ShipView
	var _pts := PackedVector2Array()
	var _bob := -999

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(_d: float) -> void:
		if view == null or not visible:
			return
		if view.bob_offset() != _bob:
			_bob = view.bob_offset()
			_trace()
			queue_redraw()

	func _trace() -> void:
		_pts.clear()
		var img := view.canvas()
		if img == null:
			return
		var w := img.get_width()
		var h := img.get_height()
		var solid := func(x: int, y: int) -> bool:
			return x >= 0 and y >= 0 and x < w and y < h and img.get_pixel(x, y).a > 0.1
		for y in range(-1, h + 1):
			for x in range(-1, w + 1):
				if solid.call(x, y):
					continue
				if solid.call(x + 1, y) or solid.call(x - 1, y) or solid.call(x, y + 1) or solid.call(x, y - 1):
					_pts.append(Vector2(x, y))

	func _draw() -> void:
		if view == null:
			return
		var kk := view.art_scale()
		var origin := ((view.size - Vector2(view.canvas_width(), view.canvas_height())) * 0.5).floor()
		var c := Color(UITheme.HOT, 0.85)
		for p in _pts:
			draw_rect(Rect2(origin + p * kk, Vector2(kk, kk)), c)
