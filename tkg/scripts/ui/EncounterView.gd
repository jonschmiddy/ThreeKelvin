class_name EncounterView
extends Control

## One continuous space. Your ship on the left, whatever you are facing on the
## right, a single starfield behind both.
##
## Not two panels. The moment you put a border around each half you get a stat
## block facing another stat block; with one field behind them the ship reads as
## a thing in a place. This is the frame the sector view and combat share, so the
## ship never disappears between them.

enum Subject { AREA, ENEMY }

var _row: HBoxContainer
var _ship_slot: ShipSlot
var _ship: ShipView
var _area: AreaView
var _slots: HBoxContainer
var _made: Array[EnemySlot] = []
var _tint: Color = Color("#16202c")

func _ready() -> void:
	clip_contents = true
	_row = HBoxContainer.new()
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.add_theme_constant_override("separation", 24)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)

	# Your hull is itself a target: defensive and utility cards are played by
	# dropping them here, so every card is aimed at something.
	_ship_slot = ShipSlot.new()
	_ship_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_row.add_child(_ship_slot)
	_ship_slot.claim = _claim_hot
	_ship = _ship_slot.art

	_area = AreaView.new()
	_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_row.add_child(_area)

	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 10)
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots.visible = false
	_row.add_child(_slots)

## Sector: the right side is the place itself.
func show_area(n: MapGen.MapNode) -> void:
	_tint = MapGen.region_colour(n).darkened(0.72)
	_area.setup(n)
	_area.visible = true
	_slots.visible = false
	_ship.modulate = Color(0.55, 0.55, 0.6) if Run.dead else Color.WHITE
	queue_redraw()

## Combat: the right side is everything shooting at you. Slots are rebuilt only
## when the count changes, so reinforcements arriving mid-fight slide in without
## resetting the ones already there.
func bind_self_drop(on_drop: Callable) -> void:
	if not _ship_slot.card_dropped.is_connected(on_drop):
		_ship_slot.card_dropped.connect(on_drop)

func show_enemies(list: Array, on_drop: Callable, on_hover: Callable) -> void:
	_area.visible = false
	_slots.visible = true
	_ship.modulate = Color.WHITE

	if _made.size() != list.size():
		for c in _slots.get_children():
			c.queue_free()
		_made.clear()
		for i in list.size():
			var slot := EnemySlot.new()
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
			slot.claim = _claim_hot
			slot.card_dropped.connect(on_drop)
			slot.hovered.connect(on_hover)
			_slots.add_child(slot)
			_made.append(slot)

	for i in list.size():
		var e = list[i]
		_made[i].bind(i, e, e.intent != null and e.intent.telegraph)
	queue_redraw()

## Exactly one target highlights at a time. Each slot reports when it takes the
## cursor and the rest are cleared, because a slot never hears that the cursor
## left it.
func _claim_hot(who) -> void:
	if _ship_slot != who:
		_ship_slot.set_hot(false)
	for sl in _made:
		if sl != who:
			sl.set_hot(false)

func slot(i: int) -> EnemySlot:
	return _made[i] if i >= 0 and i < _made.size() else null

func estimate(i: int, text: String) -> void:
	var sl := slot(i)
	if sl != null:
		sl.show_estimate(text)

func clear_estimates() -> void:
	for sl in _made:
		sl.show_estimate("")

func ship_view() -> ShipView:
	return _ship

func enemy_view(i: int = 0) -> EnemyArt:
	var sl := slot(i)
	return sl.art if sl != null else null

func _draw() -> void:
	# The void is never flat black: a wash tinted by region gives each place a
	# colour signature for free, which is the cheapest richness available.
	draw_rect(Rect2(Vector2.ZERO, size), Color("#070a10"), true)
	var steps := 5
	for i in steps:
		var f := float(i) / float(steps)
		var band := Rect2(Vector2(size.x * (0.45 + f * 0.14), 0),
			Vector2(size.x, size.y))
		draw_rect(band, Color(_tint.r, _tint.g, _tint.b, 0.10), true)

	var s := 11
	for i in 150:
		s = (s * 9301 + 49297) % 233280
		var x := float(s) / 233280.0 * size.x
		s = (s * 9301 + 49297) % 233280
		var y := float(s) / 233280.0 * size.y
		s = (s * 9301 + 49297) % 233280
		var bright := (s % 5) == 0
		draw_rect(Rect2(Vector2(floor(x), floor(y)), Vector2.ONE),
			Color("#8fa3ba") if bright else Color("#28323f"), true)


## The place, drawn. Every node type has a picture before any real art exists,
## and a cleared node visibly differs from one you have not touched.
class AreaView extends Control:
	var node: MapGen.MapNode

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(n: MapGen.MapNode) -> void:
		node = n
		queue_redraw()

	func _draw() -> void:
		if node == null:
			return
		var c := size * 0.5
		var tint := MapGen.region_colour(node)
		match node.type:
			MapGen.NodeType.STATION:
				_plate(c + Vector2(-40, -30), Vector2(80, 60), Color("#2e313e"))
				for i in 4:
					for j in 3:
						draw_rect(Rect2(c + Vector2(-31 + i * 18, -21 + j * 17),
							Vector2(8, 6)),
							UITheme.HOT if (i + j) % 3 else Color("#8a5c20"), true)
				_plate(c + Vector2(-54, 30), Vector2(108, 7), Color("#424758"))
				_plate(c + Vector2(-6, -44), Vector2(12, 14), Color("#5c6376"))
			MapGen.NodeType.DERELICT:
				_plate(c + Vector2(-52, -14), Vector2(104, 26), Color("#1e2733"))
				_plate(c + Vector2(-52, 12), Vector2(104, 6), Color("#0f151d"))
				draw_rect(Rect2(c + Vector2(-10, -14), Vector2(20, 26)), Color("#070a10"), true)
				for i in 7:
					draw_rect(Rect2(c + Vector2(58 + i * 11, -24 + i * 8),
						Vector2(4, 3)), Color("#2a3644"), true)
			MapGen.NodeType.EVENT:
				draw_rect(Rect2(c + Vector2(-2, -40), Vector2(4, 74)), Color("#3a5876"), true)
				draw_rect(Rect2(c + Vector2(-11, -40), Vector2(22, 7)), tint, true)
				draw_rect(Rect2(c + Vector2(-4, -50), Vector2(8, 8)), UITheme.HOT, true)
			MapGen.NodeType.GOAL:
				for r in range(64, 10, -10):
					draw_rect(Rect2(c - Vector2(r, r) * 0.5, Vector2(r, r)),
						Color(1.0, 0.62, 0.24, 0.09), true)
				draw_rect(Rect2(c - Vector2(11, 11), Vector2(22, 22)), UITheme.FLARE, true)
				draw_rect(Rect2(c - Vector2(5, 5), Vector2(10, 10)), Color("#fff6e2"), true)
			MapGen.NodeType.FIGHT:
				if node.cleared:
					for i in 11:
						var a := float(i) * 0.66
						draw_rect(Rect2(c + Vector2(cos(a) * (26 + i * 6), sin(a) * (18 + i * 4)),
							Vector2(3, 2)), Color("#2a3644"), true)
				else:
					_plate(c + Vector2(-46, -12), Vector2(92, 24), Color("#2a2119"))
					_plate(c + Vector2(-46, 12), Vector2(92, 5), Color("#0b0f16"))
					draw_rect(Rect2(c + Vector2(-56, -5), Vector2(10, 5)), Color("#d64a3a"), true)
			MapGen.NodeType.START:
				# Where you start is empty space. Drawing a marker here would put
				# an object in the one sector that is meant to have nothing in it.
				pass
			_:
				draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), tint, true)

	func _plate(pos: Vector2, dim: Vector2, col: Color) -> void:
		draw_rect(Rect2(pos, dim), col, true)
		draw_rect(Rect2(pos, Vector2(dim.x, 1)), col.lightened(0.25), true)
		draw_rect(Rect2(pos + Vector2(0, dim.y - 1), Vector2(dim.x, 1)), Color("#0b0f16"), true)


## Your own hull as a drop target. Attacks are refused here — dropping a weapon
## on yourself should not silently do something else.
class ShipSlot extends Control:
	signal card_dropped(view: CardView)

	var art: ShipView
	var _hot: bool = false
	var claim: Callable

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		art = ShipView.new()
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)

	func set_hot(v: bool) -> void:
		if _hot == v:
			return
		_hot = v
		queue_redraw()

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		if not (data is Dictionary and data.has("card")):
			return false
		var c: CardData = data["card"]
		var ok: bool = c.damage <= 0 and not c.damage_equals_heat and c.evoke <= 0
		set_hot(ok)
		if ok and claim.is_valid():
			claim.call(self)
		return ok

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		_hot = false
		queue_redraw()
		card_dropped.emit(data.get("view"))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and _hot:
			_hot = false
			queue_redraw()

	func _draw() -> void:
		if not _hot:
			return
		var c := UITheme.GOOD
		var n := 10.0
		for corner in [
				[Vector2(0, 0), Vector2(1, 1)],
				[Vector2(size.x, 0), Vector2(-1, 1)],
				[Vector2(0, size.y), Vector2(1, -1)],
				[Vector2(size.x, size.y), Vector2(-1, -1)]]:
			var o: Vector2 = corner[0]
			var d: Vector2 = corner[1]
			draw_rect(Rect2(o + Vector2(0, -1 if d.y < 0 else 0), Vector2(n * d.x, 1)), c, true)
			draw_rect(Rect2(o + Vector2(-1 if d.x < 0 else 0, 0), Vector2(1, n * d.y)), c, true)
