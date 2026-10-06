class_name CutawayView
extends Control

## THE CUTAWAY (Jon: "THE CUTAWAY IS CLEANNNN."; scratchpad `local_role/cutaway`
## and notes section 4). On LOCAL, out of a fight, click your own ship: the
## camera eases in on it, the sky behind breaks up the way it does behind the
## escape menu (`pause_backdrop.gdshader`, Jon: "the same pixelated treatment"),
## every fitted part lifts off its mount on a dotted leader line to a labelled
## tag, empty mounts show as rings, and the LEFT PANEL slides in: the ship's
## name and numbers, its hold and DONE. Point at a module anywhere -- the hold,
## the hull, a popup -- and a card beside it shows the module large and its
## cards. Click a wreck in the sky for its bay, or SECTOR LOOT on LOCAL's bottom
## bar (left showing under the cutaway) for this system's own pile, each a
## popup beside what opened it. Drag between the
## hold, a popup and the rings on the hull. Close with a click on the ship or
## the sky -- anywhere that is not the ship, its parts, tags and rings, the left
## panel or a popup; with a popup open, that click shuts the popup first -- Esc
## (a popup first), or DONE. A drag let go of anywhere else puts the part back
## and shuts nothing.
##
## EVERY MOVE IS RUN'S RULE (`RunState.lift_part` / `fit_at_mount` / `stow_at`),
## the same calls the refit screen makes, so the two cannot disagree; the loot is
## claimed through `Run.take_item` / `take_from_jetsam`, the same calls the
## map's SECTOR LOOT popup (`TransferView`) makes, so taking a thing in one shows
## it gone in the other. Local only: nothing here is sent over the network
## beyond what those calls already send.
##
## The hull is drawn here at the push-in's scale (2x wherever the lifted parts
## and their tags fit round it right of the left panel, else 1x: a 960x540 game
## has no clean 1.5x), and LOCAL's own hull is hidden while it is open, so the
## backdrop the shader breaks up is the sky and everything in it but your ship.

signal closed

const EASE_S := 0.4
const PANEL_W := 250
const BACKDROP := preload("res://shaders/pause_backdrop.gdshader")
## The gap kept round the room the exploded ship must fit in, right of the left panel.
const MARGIN := 8.0

var _src: ShipView
var _scrim: ColorRect
var _mat: ShaderMaterial
var _stage: Control
var _ship: ShipView
var _mounts: MountPoints
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _hold: HoldGrid
var _hold_label: Label
var _name: Label
var _class: Label
var _attrs: AttrBlock
var _mount_line: Label
var _say: Label
var _done: Button
## The open popup (a wreck's bay, or this system's own pile), if any.
var _popup: PanelContainer = null
var _pop_jetsam: MapGen.Jetsam = null
var _pop_grid: SalvageGrid = null
var _pop_scroll: ScrollContainer
var _pop_take: Button
var _pop_empty: Label
var _pop_beside := Rect2()
## Asked with a point on screen: the wreck drawn there in the sky behind, as
## `[jetsam, its rect on screen]`, or `[]`. LOCAL sets it (it knows its wrecks).
var wreck_at: Callable

## The push-in's scale, and where the exploded ship's art origin lands.
var k: int = 2
var _target := Vector2.ZERO
var _from := Vector2.ZERO
var _from_s := 1.0
## THE LEFT PANEL and how wide it came out: everything right of it is the
## hull's.
var _hold_panel: PanelContainer
var _hold_w := 0.0
## 0 LOCAL .. 1 the cutaway, and where it is heading
var t := 0.0
var _goal := 1.0
var _lifted: ModuleData = null
var _lifted_mount := -1
var _busy := false
var _shown: HoldItem = null
var _say_until := 0
## What the push-in's scale was chosen from, for the harnesses.
var fit_note := ""
var _room := Rect2()
var _layout_ok := true
## Where the exploded ship -- hull, parts, tags, rings -- is drawn, this view's px.
var _pic := Rect2()
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
	# rect drawn before the ship, the left panel and the card, so it reads only what
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

	_build_left()
	_build_panel()
	Sig.ship_changed.connect(_on_ship_changed)
	# (and when a pile here changes: a partner took something, an event paid out)
	Sig.map_changed.connect(_on_ship_changed)
	_measure.call_deferred()


## Sizes, the push-in's scale and where everything lands; then the ease in.
func _measure() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_refresh()
	# the left panel: as wide as the hold (or the ship's numbers), the whole height
	_hold_w = ceilf(_hold_panel.get_combined_minimum_size().x)
	_hold_panel.size = Vector2(_hold_w, size.y)
	_hold_panel.position = Vector2(-_hold_w, 0)
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


## THE PUSH-IN'S SCALE, PER HULL: 2x if the exploded ship -- its hull, every
## part lifted clear of it and every tag -- fits right of the left panel, at the
## content area's full height; else 1x. (1.5x would double every other pixel on
## a 960x540 picture.)
func _choose_scale() -> void:
	var room := Rect2(_hold_w + MARGIN, MARGIN, size.x - _hold_w - MARGIN * 2.0, size.y - MARGIN * 2.0)
	fit_note = ""
	for kk: int in [2, 1]:
		var b := _layout(kk, room)
		# (every part and word is inside the room by construction; a ring on the
		# hull's very edge may stand a few px past it, into the margin, not more)
		var fits := _layout_ok and b.size.x * kk <= room.size.x + MARGIN and b.size.y * kk <= room.size.y + MARGIN
		fit_note += "%dx %s in %dx%d; " % [kk,
			("fits, %dx%d" % [int(b.size.x * kk), int(b.size.y * kk)]) if fits else ("does not fit, %dx%d" % [int(b.size.x * kk), int(b.size.y * kk)]),
			int(room.size.x), int(room.size.y)]
		if fits or kk == 1:
			k = kk
			_room = room
			_ship.zoom(k)
			_ship.size = Vector2(_ship.canvas_width(), _ship.canvas_height())
			_mounts.refresh()
			b = _layout(k, room)
			_target = (room.get_center() - b.get_center() * float(k)).round()
			_pic = Rect2(_target + b.position * float(k), b.size * float(k))
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
	if _say != null and _say.modulate.a > 0.0 and Time.get_ticks_msec() > _say_until:
		_say.modulate.a = 0.0


## The camera, the backdrop, the parts and the left panel at progress `t`.
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
	_hold_panel.position.x = roundf(lerpf(-_hold_w, 0.0, e))


## Shut at once, no ease: LOCAL is going away under it (SCAN SECTOR).
func close_now() -> void:
	if _goal > 0.0:
		close()
	t = 0.0
	_goal = 0.0
	_finish_close()


func is_open() -> bool:
	return _goal > 0.0


func close() -> void:
	if _goal <= 0.0:
		return
	close_popup()
	_shown = null
	_panel_vis()
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
		UITheme.flat(Color(UITheme.PANEL, 0.97), UITheme.LINE, 1, 10, 10))
	# (the card is something to read, not to press: the pointer goes through it)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 4)
	_panel_box.custom_minimum_size.x = PANEL_W - 20
	_panel.add_child(_panel_box)


## Whether the card shows: once the ship is out, while a module is pointed at
## and nothing is carried (the rings say where a carried part goes, and the card
## would cover some of them).
func _panel_vis() -> void:
	_panel.visible = _panel.modulate.a > 0.01 and _shown != null and not _carrying()


func _carrying() -> bool:
	var d: Variant = get_viewport().gui_get_drag_data() if is_inside_tree() else null
	return typeof(d) == TYPE_DICTIONARY and (d as Dictionary).get("module") is HoldItem


## THE CARD FOR WHAT IS POINTED AT (Jon: "hovering over the module shows the
## modules + cards"), beside it: the module large, its name, manufacturer,
## rarity, size and slot, its line, then its cards. `at` is where the pointed
## thing is on screen; the card goes beside it, right of the left panel, off any
## open popup, never on the thing itself. Null hides it.
func _show(m: HoldItem, at: Rect2 = Rect2()) -> void:
	if m != _shown or _panel_box.get_child_count() == 0:
		_shown = m
		Widgets.clear(_panel_box)
		if m != null:
			_card(m)
	if m != null and at.has_area():
		var local := Rect2(get_global_transform().affine_inverse() * at.position, at.size)
		_panel.reset_size()
		_panel.size = _panel.get_combined_minimum_size()
		_panel.position = _beside(local, _panel.size, _popup.get_rect() if _popup != null else Rect2())
	_panel_vis()


func _card(m: HoldItem) -> void:
	var mod := m as ModuleData
	if mod != null:
		# THE PART ITSELF FIRST, large: the hold's own plate, at the biggest whole
		# multiple of its art pixels the card has room for
		var pic := Pic.new()
		pic.setup(mod, PANEL_W - 22.0, 84.0)
		_panel_box.add_child(pic)
	_panel_box.add_child(UITheme.body(m.name.to_upper(), UITheme.ICE, UITheme.FS_BODY))
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


# --------------------------------------------------------------- the left panel

## THE LEFT PANEL, the cutaway's only one (Jon, in turn: "Maybe we can have the
## hold in a panel to the left?", "The hold AND the stats can go in the left
## panel maybe?", "maybe we don't need the bottom drawer?", "no right panel"):
## the ship's name and numbers, the hold under them at the hold's own cell size
## -- every row of every hull's hold on screen -- then DONE. The cutaway's full
## height (it ends above LOCAL's bottom bar, whose SECTOR LOOT opens this
## system's own pile in a popup here); it slides in from the left with the
## push-in.
func _build_left() -> void:
	_hold_panel = PanelContainer.new()
	_hold_panel.add_theme_stylebox_override("panel",
		UITheme.flat(Color(UITheme.PANEL, 0.98), UITheme.LINE, 1, 10, 10))
	_hold_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_hold_panel)
	var hc := VBoxContainer.new()
	hc.add_theme_constant_override("separation", 3)
	_hold_panel.add_child(hc)
	_name = UITheme.body("", UITheme.ICE, UITheme.FS_BODY)
	hc.add_child(_name)
	_class = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	hc.add_child(_class)
	_attrs = AttrBlock.new()
	_attrs.custom_minimum_size.x = 196
	hc.add_child(_attrs)
	_mount_line = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	hc.add_child(_mount_line)
	hc.add_child(UITheme.hsep())
	_hold_label = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	hc.add_child(_hold_label)
	_hold = HoldGrid.new()
	_hold.dropped.connect(_on_hold_drop)
	hc.add_child(_hold)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hc.add_child(sp)
	_say = UITheme.body("", UITheme.TRACTOR, UITheme.FS_SMALL)
	_say.modulate.a = 0.0
	hc.add_child(_say)
	_done = Widgets.button("DONE · ESC", close)
	_done.custom_minimum_size = Vector2(0, 22)
	hc.add_child(_done)


# --------------------------------------------------------------- the popup

## A CONTAINER, OPENED BESIDE WHAT OPENED IT (Jon: "the wreck loot can be just a
## popup after you click the wrecked ship"): a wreck's bay, clicked on in the
## sky behind the ship, or this system's own pile, from SECTOR LOOT on LOCAL's
## bottom bar. Its title,
## its grid (four across, three rows shown before it scrolls), TAKE ALL and a
## close. Drag out of it to the hold or straight onto a ring; drag from the hold
## into it to put a thing down. One at a time.
##
## A LIGHTER SHELL THAN `TransferView`, on purpose: that screen is a whole page
## with its own copy of your hold beside the container, and here the hold is
## already on screen. What it shares is everything that decides anything -- the
## grid (`SalvageGrid`) and the calls (`take_item`, `take_from_jetsam`,
## `put_in`) -- so the two cannot disagree about what is left in a wreck.
func open_popup(h: MapGen.Jetsam, beside: Rect2) -> void:
	close_popup()
	if h == null:
		return
	_pop_jetsam = h
	_pop_beside = Rect2(get_global_transform().affine_inverse() * beside.position, beside.size)
	_popup = PanelContainer.new()
	_popup.add_theme_stylebox_override("panel",
		UITheme.flat(Color(UITheme.PANEL, 0.98), UITheme.LINE, 1, 8, 10))
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_popup)
	move_child(_popup, _panel.get_index())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_popup.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UITheme.body(("%s · WRECK" % h.label) if h.is_wreck() else "SECTOR LOOT",
		UITheme.THEM if h.is_wreck() else UITheme.CHILL, UITheme.FS_SMALL)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := Widgets.button("X", close_popup)
	x.custom_minimum_size = Vector2(18, 16)
	head.add_child(x)
	_pop_empty = UITheme.body("NOTHING LEFT IN IT", UITheme.COLD, UITheme.FS_SMALL)
	v.add_child(_pop_empty)
	_pop_scroll = ScrollContainer.new()
	_pop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	v.add_child(_pop_scroll)
	_pop_grid = SalvageGrid.new()
	_pop_grid.on_put = func(m: HoldItem) -> bool:
		var n: MapGen.MapNode = Run.node_at()
		return n != null and _pop_jetsam != null and Run.put_in(n, _pop_jetsam, m)
	_pop_grid.picked.connect(func(_m: HoldItem) -> void: _refresh())
	_pop_scroll.add_child(_pop_grid)
	_pop_take = Widgets.button("TAKE ALL", func() -> void: _take_all(_pop_jetsam))
	_pop_take.custom_minimum_size = Vector2(92, 20)
	_pop_take.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(_pop_take)
	if h.is_wreck():
		Audio.play(&"wreck_open")
	else:
		Audio.play(&"hold_lift", 0.05)
	_fill_popup()


func close_popup() -> void:
	if _popup != null:
		_popup.queue_free()
	_popup = null
	_pop_jetsam = null
	_pop_grid = null


func popup_open() -> bool:
	return _popup != null


func _fill_popup() -> void:
	if _popup == null:
		return
	var n: MapGen.MapNode = Run.node_at()
	_fill(_pop_grid, _pop_jetsam)
	var left := Run.jetsam_left(n, _pop_jetsam) if n != null else 0
	_pop_empty.visible = left <= 0
	_pop_take.disabled = left <= 0
	var gh := _pop_grid.get_combined_minimum_size().y
	_pop_scroll.custom_minimum_size = Vector2(4.0 * HoldGrid.CELL + (14.0 if gh > 3.0 * HoldGrid.CELL else 0.0),
		clampf(gh, float(HoldGrid.CELL), 3.0 * HoldGrid.CELL))
	_popup.reset_size()
	_popup.size = _popup.get_combined_minimum_size()
	# (off the exploded ship where there is room, so no ring is under it)
	_popup.position = _beside(_pop_beside, _popup.size, _pic)


## WHERE A FLOATING THING GOES beside `r` (this view's px): right of it, else
## left, else under, else over -- the first that is inside the room right of the
## left panel and clear of `avoid`; failing that a corner of the room clear of
## `avoid`; failing that beside `r` whatever it covers -- and never on `r`.
func _beside(r: Rect2, sz: Vector2, avoid: Rect2) -> Vector2:
	var area := Rect2(_hold_w + MARGIN, MARGIN, size.x - _hold_w - MARGIN * 2.0, size.y - MARGIN * 2.0)
	var cy := clampf(r.get_center().y - sz.y * 0.5, area.position.y, area.end.y - sz.y)
	var cx := clampf(r.get_center().x - sz.x * 0.5, area.position.x, area.end.x - sz.x)
	var cands: Array[Vector2] = [
		Vector2(maxf(r.end.x + 10.0, area.position.x), cy),
		Vector2(r.position.x - 10.0 - sz.x, cy),
		Vector2(cx, r.end.y + 10.0),
		Vector2(cx, r.position.y - 10.0 - sz.y)]
	var corners: Array[Vector2] = [
		Vector2(area.end.x - sz.x, area.position.y), Vector2(area.end.x - sz.x, area.end.y - sz.y),
		Vector2(area.position.x, area.end.y - sz.y), Vector2(area.position.x, area.position.y)]
	for pass_ in 3:
		for c in (corners if pass_ == 1 else cands):
			var q := Rect2(c.round(), sz)
			if not area.encloses(q) or q.intersects(r):
				continue
			if pass_ < 2 and avoid.has_area() and q.intersects(avoid):
				continue
			return c.round()
	return Vector2(area.end.x - sz.x, area.position.y).round()


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
	_fill_popup()
	_layout(k, _room)
	_mounts.refresh()
	_panel_vis()


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
	_say.modulate.a = 1.0
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
		# a popup first, then the cutaway
		get_viewport().set_input_as_handled()
		if _popup != null:
			close_popup()
		else:
			close()
		return
	var mm := e as InputEventMouseMotion
	if mm != null:
		_point(mm.global_position)


## WHAT IS UNDER THE POINTER, for the card: a part on the hull, a module in the
## hold, or one in the open popup -- the same card wherever it is.
func _point(gp: Vector2) -> void:
	_last_gp = gp
	if _carrying():
		_panel_vis()
		return
	var m: HoldItem = null
	var at := Rect2()
	# the open popup first: it is drawn over everything but the card
	if _pop_grid != null:
		for c in _pop_grid.get_children():
			if c is ItemIcon and (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().has_point(gp):
				m = (c as ItemIcon).held_item()
				# (beside the whole popup, so the card covers none of it)
				at = _popup.get_global_rect()
	if m == null:
		var ic := _hold.icon_at(gp)
		if ic != null:
			m = ic.held_item()
			at = ic.get_global_rect()
	var over_popup := _popup != null and _popup.get_global_rect().has_point(gp)
	if m == null and not over_popup:
		var lp := _mounts.get_global_transform().affine_inverse() * gp
		var part := _mounts.part_under(lp)
		if part != null:
			m = part
			for s in _mounts.spots():
				if s.held == part:
					var r := _mounts.part_rect(part, s.slot, _mounts._part_at(s), _mounts._mag())
					at = Rect2(_mounts.get_global_transform() * r.position, r.size * _mounts.get_global_transform().get_scale())
	if not m is ModuleData:
		m = null
	_show(m, at)


## A click on the hull: on a part, the part's (a lift); on the hull's own
## pixels, nothing; on the clear canvas round it, the sky's.
func _on_hull_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _mounts.part_under(mb.position) != null or on_hull(_ship, mb.position) or _mounts.hit_drawn(mb.position):
		return
	_mounts.accept_event()
	_sky_click(mb.global_position)


func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and t >= 0.98:
		accept_event()
		_sky_click(mb.global_position)


## A click on the sky: a wreck there opens its bay; else an open popup shuts;
## else the cutaway does.
func _sky_click(gp: Vector2) -> void:
	if wreck_at.is_valid():
		var hit: Array = wreck_at.call(gp)
		if hit.size() == 2:
			open_popup(hit[0], hit[1])
			return
	if _popup != null:
		close_popup()
		return
	close()


## A module drawn large for the panel: `ModuleIcon.draw_plate`, the hold's own
## picture of it, standing as it is authored, at 2, 3 or 4 screen px per art
## px -- whichever is the largest that fits `w` x `h`.
class Pic extends Control:
	var m: ModuleData
	var sc := ModuleIcon.HOLD_K

	func setup(mod: ModuleData, w: float, h: float) -> void:
		m = mod
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var f := Vector2(maxi(1, mod.size.x), maxi(1, mod.size.y))
		for n: float in [4.0, 3.0, 2.0]:
			var box := f * float(HoldGrid.CELL) * (n / ModuleIcon.HOLD_K)
			sc = n
			if box.x <= w and box.y <= h:
				break
		custom_minimum_size = f * float(HoldGrid.CELL) * (sc / ModuleIcon.HOLD_K)
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	func _draw() -> void:
		ModuleIcon.draw_plate(self, m, Rect2(Vector2.ZERO, custom_minimum_size),
			Vector2i(maxi(1, m.size.x), maxi(1, m.size.y)), false, sc)


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
