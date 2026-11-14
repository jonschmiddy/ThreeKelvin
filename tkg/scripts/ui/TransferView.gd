class_name TransferView
extends Control

## One screen for every container, as no payout may force itself into a full hold.
## Why: docs/why/TransferView.md#container-screen

## LOOT OPENS WHERE IT IS (Jon, Nov 9, stripped-down UI A2): no window. The camera pushes
## in on the container's subject, its things float out beside it, your hold slides in.
## Why: docs/why/TransferView.md#loot-opens-where-it-is

## Both grids have a fixed height, as a window that moves while you work is worse.
## Why: docs/why/TransferView.md#grid-height
const GAP := 12          ## between the subject and its things
const PAD_V := 16
const PAD_H := 20

const PANEL_ROWS := 6

## Three rows show and the bar arrives with the fourth (Jon: not unless bigger than 4x3).
## Why: docs/why/TransferView.md#grid-height
const FIT_ROWS := 3

## Godot takes the bar from the child's width, so the frame is wider to keep the columns.
## Why: docs/why/TransferView.md#scrollbar-room
const BAR := 14

## The push-in's time, the cutaway's (`CutawayView.EASE_S`): one camera, one pace.
const EASE_S := 0.4
## Air round the room the subject and its things land in.
const MARGIN := 8.0

var _hold: HoldGrid
var _loose: SalvageGrid
var _title: Label
## Names the container, not the direction: 'OUT HERE' read as a compass.
var _loose_label: Label
## Kept so a fitted popup can grow the far grid once it knows what is in it.
var _loose_scroll: ScrollContainer = null
## The far grid is measured when a container arrives and never again.
var _sized: bool = false
var _node: MapGen.MapNode = null
## WHICH container. A system holds several -- one per hull you killed, plus its
## own floor -- and this screen is a view of exactly one of them at a time.
var _jetsam: MapGen.Jetsam = null
var _busy: bool = false
var _on_close: Callable
## The plate the container's things stand on (what A.S.H. keeps off: `window_rect`).
var _window: PanelContainer = null
## Its heading (the title and its rule), hidden under a wreck's own words.
var _head: Control = null
## Your hold, down the left.
var _hold_panel: PanelContainer = null
var _hold_w := 0.0
var _done: Button = null

## THE CAMERA, when the opener gives one (`aim`): the subject on LOCAL whose
## container this is, its box as drawn, the scene controls that zoom with it
## and the sky under them, and the floor (global y) the room stops at.
var subject: Control = null
var subject_box := Rect2()
var scenes: Array[Control] = []
var sky: LocalSky = null
var floor_g := INF
## A harness's: no camera even over LOCAL.
var no_camera := false
## The push-in's progress and where it is going (1 open, 0 shut).
var t := 0.0
var _goal := 1.0
## The subject's landed scale on screen (2x where it fits, else 1x).
var k := 1.0
var _zs := 1.0
var _zoom: SceneZoom = null
var _anchor := Vector2.ZERO
var _land := Vector2.ZERO
var _room := Rect2()
var _plate_rest := Vector2.ZERO
var _plate_from := Vector2.ZERO
var _measured := false


## `title` overrides the container's word only when an event hands you something.
## Why: docs/why/TransferView.md#container-title
func setup(h: MapGen.Jetsam, n: MapGen.MapNode, on_close: Callable,
		animate: bool = true, title: String = "") -> void:
	_node = n
	_jetsam = h
	# A NEW CONTAINER GETS A NEW MEASUREMENT, and nothing else does.
	_sized = false
	_on_close = on_close
	# Heading names the container first, as the screen is about it, not about the ship:
	# the pile's one name, or a wreck's own (Jon, Nov 9, stripped-down UI 6).
	# Why: docs/why/TransferView.md#container-title
	if title != "":
		_title.text = title
	elif h != null and h.is_wreck():
		_title.text = h.label.to_upper()
	else:
		_title.text = "SECTOR LOOT"
	refresh()
	# The sweep plays once per container, not per system or per visit.
	# Why: docs/why/TransferView.md#reveal-sweep
	if h != null and h.is_wreck():
		h.opened = true
	if animate and h != null and not h.scanned:
		h.scanned = true
		if h is MapGen.PileView and (h as MapGen.PileView).pile != null:
			(h as MapGen.PileView).pile.scanned = true
		_loose.scan()
	else:
		_loose.skip_scan()
	_measure.call_deferred()


## The camera: `who` is the thing on LOCAL this container belongs to (a wreck's
## slot, your ship), `box` its drawn box (global), `near` the scene controls
## that zoom with it, `backdrop` the sky, `floor_y` where the room ends (global).
func aim(who: Control, box: Rect2, near: Array[Control], backdrop: LocalSky, floor_y: float = INF) -> void:
	subject = who
	subject_box = box
	scenes = near
	sky = backdrop
	floor_g = floor_y


## Opened over LOCAL (its parent a `SectorScreen`), the camera finds its own subject:
## the wreck's slot where the container is a wreck drawn here, else your ship; the
## scene zooms as it does for the cutaway, in the room above LOCAL's bar (or the
## floor the opener set: an event's band).
func _aim_local() -> void:
	var sc := get_parent() as SectorScreen
	if sc == null or sc._view == null or not is_instance_valid(sc._view):
		return
	var slot: EnemySlot = sc._view.wreck_slot(_jetsam) if _jetsam != null and _jetsam.is_wreck() else null
	var who: Control = slot if slot != null else sc._view.ship_view()
	var box: Rect2 = slot.drawn_box() if slot != null else sc.ladder_hull()
	if who == null or not who.is_visible_in_tree():
		return
	var near: Array[Control] = []
	for c: Control in [LocalSubject.of(sc._view), sc._view._row, sc._view.dust, sc._view.fx]:
		if c != null and is_instance_valid(c):
			near.append(c)
	var floor_y := floor_g
	if floor_y == INF and sc._quiet_holder != null and sc._quiet_holder.is_visible_in_tree():
		floor_y = sc._quiet_holder.get_global_rect().position.y
	aim(who, box, near, sc._view.backdrop, floor_y)


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Nothing drawn of its own: the sector is the backdrop. Still STOP, so nothing
	# behind is clicked through and a drop that misses both grids lands here. A
	# plain Control, not a container: the hold and the plate are placed by hand.
	# Why: docs/why/TransferView.md#backdrop
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Redraw on `ship_changed`: two triggers had each left a stale item drawn.
	# Why: docs/why/TransferView.md#redraw-on-ship-change
	Sig.ship_changed.connect(_on_ship_changed)
	# (and when a pile here changes under a partner's hand: their take greys here)
	Sig.map_changed.connect(_on_ship_changed)
	Sig.party_map_changed.connect(_on_ship_changed)

	_build_hold_panel()
	_build_plate()
	# (placed by `_measure`, a frame on: nothing of either shows till then)
	_hold_panel.visible = false
	_window.visible = false


## Your hold, the cutaway's own left panel in shape: the grid, air, DONE at the foot.
func _build_hold_panel() -> void:
	_hold_panel = PanelContainer.new()
	_hold_panel.add_theme_stylebox_override("panel",
		UITheme.flat(Color(UITheme.PANEL, 0.98), UITheme.LINE, 1, 5, 10))
	_hold_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_hold_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_hold_panel.add_child(col)
	# Your ship is always on the left, matching the encounter view, so side means whose.
	col.add_child(_side("YOUR HOLD", _build_hold(), Run.hold_grid().x, false))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sp)
	# DONE alone; the way back out, as the cutaway's.
	_done = Widgets.button("DONE", close)
	_done.custom_minimum_size = Vector2(0, 22)
	col.add_child(_done)


## The container's things on a plate beside their subject: its name, then the grid.
func _build_plate() -> void:
	_window = PanelContainer.new()
	_window.add_theme_stylebox_override("panel", _cut_box(PAD_V, PAD_H))
	# IGNORE not STOP: the plate must not eat drops that fall through to the view.
	# Why: docs/why/TransferView.md#popup-frame
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_window)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_window.add_child(col)
	_title = UITheme.body("", UITheme.ICE, UITheme.FS_HEAD)
	_head_of(col)
	# Empty, because the container names itself on refresh. See `_loose_label`.
	col.add_child(_side("", _build_loose(), SalvageGrid.COLS, true))


## Sizes, the camera's landing and where the plate rests; then the ease in.
func _measure() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if subject == null and not no_camera:
		_aim_local()
	var hmin := _hold_panel.get_combined_minimum_size()
	_hold_w = ceilf(hmin.x)
	var inv := get_global_transform().affine_inverse()
	var bottom := size.y
	if floor_g < INF:
		bottom = clampf((inv * Vector2(0.0, floor_g)).y, 120.0, size.y)
	# (as tall as the grid and DONE, not the window: an empty slab under them read as a page)
	_hold_panel.size = Vector2(_hold_w, minf(ceilf(hmin.y), bottom))
	# A WRECK'S OWN WORDS STAND OVER ITS PLATE (its name and SALVAGE, zoomed with
	# it), so the plate says nothing twice: no heading of its own then.
	_head.visible = not (subject is EnemySlot and is_instance_valid(subject) and not scenes.is_empty())
	_loose_label.visible = _loose_label.visible and _head.visible
	_window.reset_size()
	_window.size = _window.get_combined_minimum_size()
	_room = Rect2(_hold_w + MARGIN, MARGIN, size.x - _hold_w - MARGIN * 2.0, bottom - MARGIN * 2.0)
	_place()
	_hold_panel.visible = true
	_window.visible = true
	_measured = true
	t = 0.0
	_goal = 1.0
	if not Router.animating():
		t = 1.0
	_apply()


## The subject's landed size and place, and the plate's rest beside it: under it
## where the room is tall enough, else to its right; no subject, the plate alone.
func _place() -> void:
	_release_camera()
	k = 1.0
	_zs = 1.0
	var psz := _window.size
	_plate_rest = (_room.get_center() - psz * 0.5).round()
	_plate_from = Vector2(size.x + 8.0, _plate_rest.y)
	if subject == null or not is_instance_valid(subject) or scenes.is_empty() or not subject_box.has_area():
		return
	var inv := get_global_transform().affine_inverse()
	var b := Rect2(inv * subject_box.position, subject_box.size)
	var s0 := maxf(subject.get_global_transform().get_scale().x, 0.01)
	var c := _room.get_center()
	for kk: float in [2.0, 1.0]:
		var sz := b.size * (kk / s0)
		var stack := sz.y + GAP + psz.y <= _room.size.y and maxf(sz.x, psz.x) <= _room.size.x
		var beside := sz.x + GAP + psz.x <= _room.size.x and maxf(sz.y, psz.y) <= _room.size.y
		if not (stack or beside or kk == 1.0):
			continue
		k = kk
		if stack:
			var top := c.y - (sz.y + GAP + psz.y) * 0.5
			_land = Vector2(c.x, top + sz.y * 0.5)
			_plate_rest = Vector2(c.x - psz.x * 0.5, top + sz.y + GAP)
		elif beside:
			var left := c.x - (sz.x + GAP + psz.x) * 0.5
			_land = Vector2(left + sz.x * 0.5, c.y)
			_plate_rest = Vector2(left + sz.x + GAP, c.y - psz.y * 0.5)
		else:
			# (neither fits at 1x: the subject centred, the plate in the room's corner)
			_land = c
			_plate_rest = _room.end - psz
		break
	_land = _land.round()
	_plate_rest = _plate_rest.round()
	# the things float out from the subject
	_plate_from = (_land - psz * 0.5).round()
	_zs = k / s0
	_anchor = subject_box.get_center()
	_zoom = SceneZoom.new()
	_zoom.begin(scenes, sky, _anchor)


func _ease(x: float) -> float:
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


## The camera, the hold and the plate at progress `t`; neither takes a click till it rests.
func _apply() -> void:
	var e := _ease(t)
	_hold_panel.position = Vector2(roundf(lerpf(-_hold_w, 0.0, e)), 0.0)
	if _zoom != null:
		var to_g: Vector2 = _anchor.lerp(get_global_transform() * _land, e).round()
		_zoom.apply(lerpf(1.0, _zs, e), to_g)
	# the things in the second half of the push, out of the subject to their plate
	var x2 := clampf((e - 0.5) / 0.5, 0.0, 1.0)
	_window.position = _plate_from.lerp(_plate_rest, _ease(x2)).round()
	_window.modulate.a = x2
	var live := t >= 1.0
	for p: Control in [_hold_panel, _window]:
		p.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED if live \
			else Control.MOUSE_BEHAVIOR_DISABLED


func _process(delta: float) -> void:
	if not _measured or _goal == t:
		return
	var sp := delta / EASE_S
	t = minf(_goal, t + sp) if _goal > t else maxf(_goal, t - sp)
	if not Router.animating():
		t = _goal
	_apply()
	if t <= 0.0 and _goal <= 0.0:
		_finish_close()


## Whether the push-in has landed and the grids take the hand.
func settled() -> bool:
	return _measured and t >= 1.0 and _goal >= 1.0


## DONE, or the opener: the camera eases back out, then the opener's close runs.
func close() -> void:
	if _goal <= 0.0:
		return
	_goal = 0.0
	if not Router.animating() or not _measured:
		t = 0.0
		if _measured:
			_apply()
		_finish_close()


func _finish_close() -> void:
	_release_camera()
	if _on_close.is_valid():
		_on_close.call()


func _release_camera() -> void:
	if _zoom != null:
		_zoom.end()
		_zoom = null


## Freed from outside mid-push (a harness, a screen torn down): the scene goes back.
func _exit_tree() -> void:
	_release_camera()


## The screen catches any drop the grids miss; Godot may never ask the grid.
## Why: docs/why/TransferView.md#drop-catching
func _can_drop_data(at: Vector2, data: Variant) -> bool:
	return _side_of(at, data) != 0



## Packing is not a payout: one dry layer, rarity only adds a small ring.
static func _rarity_of(m: HoldItem) -> ModuleData.Rarity:
	if m is ModuleData:
		return (m as ModuleData).rarity
	if m is MaterialData:
		return UITheme.tier_rarity((m as MaterialData).tier)
	return ModuleData.Rarity.COMMON

static func take_sound(m: HoldItem) -> StringName:
	if m is CreditChit:
		return &"take_credits"
	# One grade ladder for modules and materials, as materials fell through to `take_common`.
	var r := ModuleData.Rarity.COMMON
	if m is ModuleData:
		r = (m as ModuleData).rarity
	elif m is MaterialData:
		r = UITheme.tier_rarity((m as MaterialData).tier)
	match r:
		ModuleData.Rarity.COMMON, ModuleData.Rarity.UNCOMMON:
			return &"take_common"
		ModuleData.Rarity.RARE:
			return &"take_rare"
		ModuleData.Rarity.EPIC:
			return &"take_epic"
		ModuleData.Rarity.LEGENDARY:
			return &"take_legendary"
		ModuleData.Rarity.EXOTIC:
			return &"take_exotic"
		_:
			return &"take_artifact"


## A take has its own quiet sound, not the reward fanfare; the reveal is staggered and quieter.
## Why: docs/why/TransferView.md#take-sound
const REVEAL_DB := -4.0

## Only the top of the ladder rings, as commons said nothing (Jon).
## Why: docs/why/TransferView.md#reveal-sound
const REVEAL_FLOOR := ModuleData.Rarity.LEGENDARY
const REVEAL_GAP := 0.055

func _on_revealed(m: HoldItem, index: int) -> void:
	if m == null or _rarity_of(m) < REVEAL_FLOOR:
		return
	var wait := REVEAL_GAP * float(maxi(index - 1, 0))
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
		if not is_inside_tree():
			return
	# `limit_ms` 0: the stagger already spaces these, and a rate limit here
	# would silently drop the tail of a full wreck.
	Audio.play(take_sound(m), 0.04, 0, REVEAL_DB)


## The rarity ladder is for finding, not packing (Jon: only the first time).
## Why: docs/why/TransferView.md#reveal-sound
func _take_fx(_m: HoldItem) -> void:
	Audio.suppress(&"loot_drop")
	Audio.suppress(&"scrap_gain")
	Audio.play(&"hold_stow", 0.06)

func _drop_data(at: Vector2, data: Variant) -> void:
	var where := _side_of(at, data)
	var m: HoldItem = (data as Dictionary).module
	if where < 0:
		# Onto your own side, from out there: the same claim `_on_hold_drop`
		# makes, aimed at wherever the hold has room.
		var i := _jetsam.items.find(m)
		if i >= 0 and not _busy:
			_busy = true
			var got: bool = await Run.take_from_jetsam(_node, _jetsam, i)
			_busy = false
			if got:
				_take_fx(m)
	elif where > 0 and Run.put_in(_node, _jetsam, m):
		pass
	refresh()


## Halves come from the grids' own rects, so the answer holds when either side resizes.
func _side_of(at: Vector2, data: Variant) -> int:
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("module"):
		return 0
	var m: HoldItem = (data as Dictionary).module
	if m == null or _node == null:
		return 0
	var from_bag := String((data as Dictionary).get("origin", &"")) == "bag"
	var split := (_hold.get_global_rect().end.x
		+ _loose.get_global_rect().position.x) * 0.5
	var out_here := get_global_position().x + at.x >= split
	if out_here:
		# Only your own things can be put down, and only once.
		return 1 if (not from_bag and Run.cargo.has(m)) else 0
	return -1 if from_bag else 0


## R turns the carried item only, as a second verb on a second target is not needed.
## Why: docs/why/TransferView.md#rotate-key
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	# TURN PART, a binding (`Keys`); R out of the box.
	if key == null or not key.is_action_pressed(&"hold_turn"):
		return
	var carried: Variant = get_viewport().gui_get_drag_data()
	if typeof(carried) != TYPE_DICTIONARY \
			or not (carried as Dictionary).has("module"):
		return
	var m: HoldItem = (carried as Dictionary).module
	if m == null:
		return
	m.turned = not m.turned
	Audio.play(&"hold_turn", 0.10)
	# The plate in your hand has to change shape too, or you are aiming a 4x1
	# while holding a picture of a 1x4.
	if ItemIcon.carried != null and is_instance_valid(ItemIcon.carried):
		ItemIcon.carried.fit_footprint()
		ItemIcon.carried.spin()
	get_viewport().set_input_as_handled()


## Guarded on being in the tree: refreshing a torn-down panel is a crash.
## Why: docs/why/TransferView.md#redraw-guard
func _on_ship_changed() -> void:
	if is_inside_tree() and _node != null:
		refresh()


func _side(label: String, body: Control, cols: int, far: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var l := UITheme.body(label, UITheme.COLD, UITheme.FS_SMALL)
	if label == "":
		_loose_label = l
	box.add_child(l)
	# A cap, not a fill: scroll appears only when a pile outgrows the screen.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Set once and never touched: `custom_minimum_size` is a floor, and clipped both grids once.
	# Why: docs/why/TransferView.md#grid-height
	var rows := maxi(Run.hold_grid().y, 2) if not far else FIT_ROWS
	# The hold never scrolls: its box is exactly the hull's grid, and a bar costs a column.
	if not far:
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.custom_minimum_size = Vector2(
		cols * HoldGrid.CELL + (BAR if far else 0), rows * HoldGrid.CELL)
	scroll.size_flags_vertical = Control.SIZE_FILL
	scroll.add_child(body)
	if far:
		_loose_scroll = scroll
	# A WELL, not a field: the grid sits in something darker than the plate, so
	# each side is an object with an edge rather than an area of slab.
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.VOID, UITheme.LINE, 0, 8, 8))
	well.add_child(scroll)
	box.add_child(well)
	return box


## THE HEADING, AS A READOUT: a marker before the title and a scanline under the pair.
func _head_of(col: VBoxContainer) -> void:
	_head = VBoxContainer.new()
	_head.add_theme_constant_override("separation", 8)
	col.add_child(_head)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var dot := Stripe.new()
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	h.add_child(_title)
	_head.add_child(h)
	var sc := Scan.new()
	sc.custom_minimum_size = Vector2(0, 5)
	_head.add_child(sc)


## A chamfered plate, the shape the escape drawer's plates already use.
func _cut_box(pad_v: int, pad_h: int) -> StyleBoxFlat:
	return UITheme.chamfer(Color(UITheme.PANEL2, 0.94), UITheme.LINE, pad_v, pad_h)


## A short hazard bar: the mark on the lid of something that was sealed.
class Stripe extends Control:
	func _draw() -> void:
		var step := 4.0
		var x := -size.y
		while x < size.x:
			draw_line(Vector2(x, size.y), Vector2(x + size.y, 0.0),
				UITheme.EMBER, 2.0)
			x += step * 2.0


## One scanline under a readout heading.
class Scan extends Control:
	func _draw() -> void:
		var c := UITheme.LINE
		draw_line(Vector2(0, 1), Vector2(size.x, 1), c, 1.0)
		c.a = 0.5
		draw_line(Vector2(0, 4), Vector2(size.x, 4), c, 1.0)


## The plate's box, global (what A.S.H. keeps off when she teaches over it).
func window_rect() -> Rect2:
	if _window == null or not is_instance_valid(_window) or not _window.is_visible_in_tree():
		return Rect2()
	return _window.get_global_rect()


## The hold and the plate where they come to rest, global: what A.S.H. keeps
## off, picked while they may still be sliding in.
func rest_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _hold_panel != null and is_instance_valid(_hold_panel) and _hold_panel.is_visible_in_tree():
		out.append(Rect2(get_global_rect().position + Vector2(0.0, _hold_panel.position.y), _hold_panel.size))
	if _window != null and is_instance_valid(_window) and _window.is_visible_in_tree():
		out.append(Rect2(get_global_rect().position + _plate_rest, _window.size))
	return out


## Your hold's panel, global.
func hold_rect() -> Rect2:
	if _hold_panel == null or not is_instance_valid(_hold_panel) or not _hold_panel.is_visible_in_tree():
		return Rect2()
	return _hold_panel.get_global_rect()


## Where the subject stands once the camera has landed, global.
func subject_landed() -> Rect2:
	if _zoom == null:
		return Rect2()
	var sz := subject_box.size * _zs
	return Rect2(get_global_transform() * _land - sz * 0.5, sz)


func _build_hold() -> Control:
	_hold = HoldGrid.new()
	_hold.dropped.connect(_on_hold_drop)
	return _hold


func _build_loose() -> Control:
	_loose = SalvageGrid.new()
	# The `picked` connection is the whole bug: the model changed and the screen did not.
	# Why: docs/why/TransferView.md#redraw-on-ship-change
	_loose.picked.connect(func(_m: HoldItem) -> void: refresh())
	_loose.revealed.connect(_on_revealed)
	# Into the open container; see `RunState.put_in`, or the screen lies about it.
	_loose.on_put = func(m: HoldItem) -> bool:
		return Run.put_in(_node, _jetsam, m)
	# Fills its side, keeping the spare row so there is always somewhere to drop.
	_loose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loose.size_flags_vertical = Control.SIZE_FILL
	return _loose


func refresh() -> void:
	if _node == null or _jetsam == null:
		return
	_hold.refresh()
	# Only somebody else's claims stay greyed; your own take leaves nothing behind.
	# Why: docs/why/TransferView.md#party-claims
	var spent: Dictionary = {}
	for i in _jetsam.items.size():
		if not _node.taken.has(_jetsam.option(i)):
			continue
		if Net.taker_name(_node.index, _jetsam.option(i)) != "":
			spent[i] = true
	# What is still out here, plus whatever somebody else is holding. Your own
	# claims are gone from the list entirely -- see `spent` above.
	var showing: Array = []
	var showing_spent: Dictionary = {}
	for i in _jetsam.items.size():
		if _node.taken.has(_jetsam.option(i)) and not spent.has(i):
			continue
		if spent.has(i):
			showing_spent[showing.size()] = true
		showing.append(_jetsam.items[i])
	_loose.setup(showing, showing_spent, 5)
	# A fitted popup learns the far side once, or it shrank under your hand as you emptied it.
	# Why: docs/why/TransferView.md#grid-height
	if _loose_scroll != null and not _sized:
		_sized = true
		# Counted by rows the parts take: the custodian's body hid rows under a bar-less view.
		# Why: docs/why/TransferView.md#grid-height
		var deep := maxi(ceili(showing.size() / float(SalvageGrid.COLS)),
			_loose.content_rows())
		var need := clampi(deep, 2, FIT_ROWS)
		_loose_scroll.custom_minimum_size.y = need * HoldGrid.CELL
		# Reserve the bar only when a pile is deeper than it can show, or a column is lost.
		# Why: docs/why/TransferView.md#scrollbar-room
		var over := deep > FIT_ROWS
		_loose_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO \
			if over else ScrollContainer.SCROLL_MODE_SHOW_NEVER
		_loose_scroll.custom_minimum_size.x = SalvageGrid.COLS * HoldGrid.CELL \
			+ (BAR if over else 0)
	# The container's own name under the heading, unless the heading (or the wreck's
	# own words over the plate) already says it.
	var label := _jetsam.label if _jetsam != null else "SECTOR LOOT"
	_loose_label.text = label
	_loose_label.visible = label.to_upper() != _title.text.to_upper() and (_head == null or _head.visible)


## A bag part is claimed first; the round trip is why this awaits and cannot run twice.
## Why: docs/why/TransferView.md#hold-drops
func _on_hold_drop(payload: Dictionary, at: Vector2i) -> void:
	var m: HoldItem = payload.get("module")
	if m == null or _busy:
		return
	if String(payload.get("origin", &"")) != "bag":
		# Asked before lifted: a move must never cost the thing moved if both calls refuse.
		# Why: docs/why/TransferView.md#hold-drops
		if m.hold_at != at and not Run.can_place(m, at):
			return
		var was := m.hold_at
		Run.take_from_hold(m)
		if not Run.place_in_hold(m, at) and not Run.place_in_hold(m, was):
			# Cannot happen; if it does the item goes back in the hold, never nowhere.
			Run.place_in_hold(m)
		refresh()
		return
	# Uses the bag's index, not the grid's: a filtered grid made the claim take the wrong thing.
	# Why: docs/why/TransferView.md#hold-drops
	var i := _jetsam.items.find(m)
	if i < 0:
		return
	# Asked before placed: `take_from_bag` checks room before spending the claim.
	_busy = true
	refresh()
	var got: bool = await Run.take_from_jetsam(_node, _jetsam, i)
	_busy = false
	if got:
		# Not for money: a placed chit sat in cargo with no icon, occupying invisible cells.
		# Why: docs/why/TransferView.md#hold-drops
		if not (m is CreditChit) and (Run.can_place(m, at) or m.hold_at == at):
			Run.take_from_hold(m)
			if not Run.place_in_hold(m, at):
				Run.place_in_hold(m)
		_take_fx(m)
	refresh()
