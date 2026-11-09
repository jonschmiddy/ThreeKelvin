class_name TransferView
extends PanelContainer

## One screen for every container, as no payout may force itself into a full hold.
## Why: docs/why/TransferView.md#container-screen

const PAD := 24

## Both grids have a fixed height, as a window that moves while you work is worse.
## Why: docs/why/TransferView.md#grid-height
const GAP := 12          ## between the two wells
const PAD_V := 16
const PAD_H := 20

const PANEL_ROWS := 6

## Three rows show and the bar arrives with the fourth (Jon: not unless bigger than 4x3).
## Why: docs/why/TransferView.md#grid-height
const FIT_ROWS := 3

## Godot takes the bar from the child's width, so the frame is wider to keep the columns.
## Why: docs/why/TransferView.md#scrollbar-room
const BAR := 14

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
## The window itself (the popup in the middle of the dimmed backdrop).
var _window: PanelContainer = null


## `title` overrides the container's word only when an event hands you something.
## Why: docs/why/TransferView.md#container-title
func setup(h: MapGen.Jetsam, n: MapGen.MapNode, on_close: Callable,
		animate: bool = true, title: String = "") -> void:
	_node = n
	_jetsam = h
	# A NEW CONTAINER GETS A NEW MEASUREMENT, and nothing else does.
	_sized = false
	_on_close = on_close
	# Heading names the container first, as the screen is about it, not about the ship.
	# Why: docs/why/TransferView.md#container-title
	if title != "":
		_title.text = title
	else:
		_title.text = h.title() if h != null else "JETSAM"
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


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Dimmed not replaced, so the sector stays visible; still STOP so nothing is clicked through.
	# Why: docs/why/TransferView.md#backdrop
	add_theme_stylebox_override("panel",
		UITheme.flat(Color(0.031, 0.043, 0.067, 0.72), Color(0, 0, 0, 0), 0,
			PAD, PAD))
	mouse_filter = Control.MOUSE_FILTER_STOP

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	# IGNORE not STOP: the frame must not eat drops that fall through to the backdrop.
	# Why: docs/why/TransferView.md#popup-frame
	var popup := PanelContainer.new()
	_window = popup
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_theme_stylebox_override("panel", _cut_box(PAD_V, PAD_H))
	centre.add_child(popup)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	popup.add_child(col)

	_title = UITheme.body("", UITheme.ICE, UITheme.FS_HEAD)
	_head_of(col, Widgets.button("DONE", func() -> void:
		if _on_close.is_valid():
			_on_close.call()))
	# No running total: the grid on the right is the answer and a number only competes.
	# Why: docs/why/TransferView.md#popup-layout

	# No centring layer: the popup is centred, so a second centring gave two answers.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)

	# Redraw on `ship_changed`: two triggers had each left a stale item drawn.
	# Why: docs/why/TransferView.md#redraw-on-ship-change
	Sig.ship_changed.connect(_on_ship_changed)

	# Your ship is always on the left, matching the encounter view, so side means whose.
	row.add_child(_side("YOUR HOLD", _build_hold(), Run.hold_grid().x, false))
	row.add_child(_gutter())
	# Empty, because the container names itself on refresh. See `_loose_label`.
	row.add_child(_side("", _build_loose(), SalvageGrid.COLS, true))


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

static func _take_sound(m: HoldItem) -> StringName:
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
	Audio.play(_take_sound(m), 0.04, 0, REVEAL_DB)


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
	var k := event as InputEventKey
	# TURN PART, a binding (`Keys`); R out of the box.
	if k == null or not k.is_action_pressed(&"hold_turn"):
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
	# A WELL, not a field: the grid sits in something darker than the popup, so
	# each side is an object with an edge rather than an area of slab.
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.VOID, UITheme.LINE, 0, 8, 8))
	well.add_child(scroll)
	box.add_child(well)
	return box


## THE HEADING, AS A READOUT: a marker before the title, the way out at the far
## end, and a scanline under the pair.
func _head_of(col: VBoxContainer, done: Button) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var dot := Stripe.new()
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	h.add_child(_title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(done)
	col.add_child(h)
	var sc := Scan.new()
	sc.custom_minimum_size = Vector2(0, 5)
	col.add_child(sc)


func _gutter() -> Control:
	var a := Arrow.new()
	a.custom_minimum_size = Vector2(46, 0)
	a.size_flags_vertical = Control.SIZE_FILL
	return a


## A chamfered popup, the shape the escape drawer's plates already use.
func _cut_box(pad_v: int, pad_h: int) -> StyleBoxFlat:
	return UITheme.chamfer(UITheme.PANEL2, UITheme.LINE, pad_v, pad_h)


## The arrow shows which way things come, and holds still when motion is off.
## Why: docs/why/TransferView.md#arrow
class Arrow extends Control:
	const CYCLE := 1.6           ## seconds for one pass, unhurried on purpose
	## The arrow steps, not slides: eight positions in 1.6 s, as continuous tweens break pixel art.
	## Why: docs/why/TransferView.md#arrow
	const STEPS := 8
	## And the fading is stepped too, for the same reason: four levels, not a
	## smooth ramp.
	const FADES := 4
	## The chevrons are built from blocks rather than lines, at this size.
	const BLOCK := 2.0
	static var freeze: float = -1.0
	var _t: float = 0.0

	func _ready() -> void:
		set_process(true)

	func _process(delta: float) -> void:
		# Still under a shot tool, so a harness photograph does not vary run to run.
		if freeze >= 0.0 or DisplaySettings.reduced_motion or not Router.animating():
			return
		_t = fmod(_t + delta / CYCLE, 1.0)
		queue_redraw()

	func _phase() -> float:
		if freeze >= 0.0:
			return _step(fmod(freeze, 1.0))
		if DisplaySettings.reduced_motion or not Router.animating():
			return 0.0
		return _step(_t)

	## The phase, on the frame grid. Everything downstream is drawn from this,
	## so nothing in the arrow can move by less than one frame's worth.
	func _step(t: float) -> float:
		return floorf(t * float(STEPS)) / float(STEPS)

	func _draw() -> void:
		# Drift is Jon's pick of four; the other three live as frames in an artifact.
		# Why: docs/why/TransferView.md#arrow
		var p := _phase()
		var mid := size.y * 0.5
		var w := 13.0
		for k in 2:
			var q: float = fmod(p + float(k) * 0.5, 1.0)
			# Whole blocks of travel, so a step is a step and not a blur.
			var x := size.x * 0.5 + 16.0 - floorf(q * 34.0 / BLOCK) * BLOCK
			var c := UITheme.COLD
			c.a = 0.7 * sin(q * PI)
			_chevron(x, mid, w, c)

	## Blocks not lines: `draw_line` antialiases a diagonal on a pixel-grid screen.
	func _chevron(x: float, y: float, w: float, c: Color) -> void:
		# Quantised alpha, so the fade steps with the motion.
		c.a = floorf(c.a * float(FADES) + 0.5) / float(FADES)
		if c.a <= 0.0:
			return
		var bx := floorf(x / BLOCK) * BLOCK
		var by := floorf(y / BLOCK) * BLOCK
		# The point is on the left: a right-hand vertex pointed the arrow back at the wreck.
		# Why: docs/why/TransferView.md#arrow
		var arm := int(w / BLOCK)
		for i in arm + 1:
			var d := float(i) * BLOCK
			draw_rect(Rect2(bx - w + d, by - d, BLOCK, BLOCK), c)
			draw_rect(Rect2(bx - w + d, by + d, BLOCK, BLOCK), c)


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


## Registration marks, the corners of a frame rather than a whole border.
class Ticks extends Control:
	func _draw() -> void:
		var c := UITheme.CHILL
		c.a = 0.5
		var n := 12.0
		for p in [[Vector2.ZERO, Vector2(1, 1)], [Vector2(size.x, 0), Vector2(-1, 1)],
				[Vector2(0, size.y), Vector2(1, -1)], [size, Vector2(-1, -1)]]:
			var o: Vector2 = p[0]
			var d: Vector2 = p[1]
			draw_line(o, o + Vector2(d.x * n, 0), c, 1.0)
			draw_line(o, o + Vector2(0, d.y * n), c, 1.0)


## The window's box, global (what A.S.H. keeps off when she teaches over it).
func window_rect() -> Rect2:
	if _window == null or not is_instance_valid(_window) or not _window.is_visible_in_tree():
		return Rect2()
	return _window.get_global_rect()


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
	_loose_label.text = _jetsam.label if _jetsam != null else "SECTOR LOOT"


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
