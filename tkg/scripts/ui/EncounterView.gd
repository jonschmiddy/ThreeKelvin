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
## What is actually out there: the world, the rocks or the fleet this system
## has in it. Behind everything, including the gas.
var backdrop: SpaceBackdrop
## Tracers, sparks and debris. Added last so it draws over the ship and the
## enemies, and ignores the mouse so it can never eat a card drop.
var fx: CombatFx
## Drifting gas, shown only in systems that sit inside a nebula.
var weather: NebulaWeather

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
	_ship_slot.preview = preview
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

	# Depth order, and the reason it is expressed as child order. NOT
	# show_behind_parent: this view paints the wash in _draw, and a child behind
	# the parent is behind THAT — so the gas was being drawn and then covered by
	# the sky every frame. A Control draws itself first and its children after,
	# in order, so the two background layers have to be the first two children:
	# wash, then what is out there, then the gas blowing through it, then the
	# ship.
	backdrop = SpaceBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	move_child(backdrop, 0)

	weather = NebulaWeather.new()
	weather.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weather.visible = false
	add_child(weather)
	move_child(weather, 1)

	fx = CombatFx.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fx)

## Where you are, told once. Sky and wash both, and both for every sector —
## fighting or not.
##
## show_area() is not enough to carry this and never was: it runs only when the
## sector is quiet, so arriving straight into a fight left the wash on its
## default tint and would now leave the sky on the last system's. What is out
## there does not care whether something is shooting at you.
func set_place(n: MapGen.MapNode) -> void:
	_tint = MapGen.region_colour(n).darkened(0.72)
	if backdrop != null:
		backdrop.setup(n)
	set_weather(n)
	queue_redraw()

func set_weather(n: MapGen.MapNode) -> void:
	if weather == null:
		return
	weather.visible = n.in_nebula
	if n.in_nebula:
		weather.setup(n.nebula_emission,
			Color("#8a5f7a") if n.nebula_emission else Color("#4a7a8a"))

func show_area(n: MapGen.MapNode) -> void:
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
			slot.preview = preview
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

## The chip row belonging to one enemy, or null if there is no such slot.
func chips_for(i: int) -> HBoxContainer:
	if i < 0 or i >= _made.size():
		return null
	return (_made[i] as EnemySlot).chips

## Forwarded to every slot: what a held card would do to that target.
var preview: Callable:
	set(v):
		preview = v
		if _ship_slot != null:
			_ship_slot.preview = v
		# _made, not _slots. _slots is the HBoxContainer they sit in; _made is
		# the list of EnemySlots themselves, which is what the rest of this
		# class iterates.
		for sl in _made:
			(sl as EnemySlot).preview = v

## Where a shot leaves your hull, and where one lands on a given enemy — both
## in the effects layer's own coordinates, since that is what has to draw the
## line between them.
func ship_muzzle() -> Vector2:
	if _ship == null or fx == null:
		return size * 0.5
	var r := _ship.get_global_rect()
	return fx.get_global_transform().affine_inverse() \
		* Vector2(r.position.x + r.size.x * 0.86, r.position.y + r.size.y * 0.5)

func enemy_anchor(i: int) -> Vector2:
	if fx == null:
		return size * 0.5
	var art := enemy_view(i)
	if art == null:
		return size * 0.5
	return fx.get_global_transform().affine_inverse() * art.get_global_rect().get_center()

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

	# The stars used to be drawn here, from one fixed seed, which is why every
	# sector in the game had the same sky. They belong to SpaceBackdrop now,
	# where they are seeded per system along with everything else in it.


## The place, drawn. Every node type has a picture before any real art exists,
## and a cleared node visibly differs from one you have not touched.
##
## Lit the same way as everything else in the game: from the top of the frame,
## cold, with warmth only where something emits it. `_body` is ART_CONTRACT's
## two-plane rule — bright top face, bright lip, wall falling into shadow — and
## it replaces the flat `_plate` these were built from. A station drawn as three
## filled rectangles is three filled rectangles; the same station drawn as three
## LIT rectangles is a place with a near side and a far side.
class AreaView extends Control:
	var node: MapGen.MapNode

	## Six value stops, darkest first: shadow, wall, lit wall, deck, lit deck,
	## rim. Same shape as EnemyArt's ramps and sampled from the same table in
	## ART_CONTRACT, so a station out here and a station on the chart are made
	## of the same steel.
	var _grey: Array[Color] = [Color("#141721"), Color("#1e202a"), Color("#2e313e"),
		Color("#424758"), Color("#5c6376"), Color("#80889e")]
	## The wreck ramp. Cold and low, but NOT nearly black — a hull with the power
	## off is still lit by the same sky as everything else, and drawn any darker
	## than this the derelict stops being an object and becomes a hole.
	var _dead: Array[Color] = [Color("#0c1219"), Color("#16202b"), Color("#22303f"),
		Color("#33455a"), Color("#465b73"), Color("#5f7890")]
	var _heat: Array[Color] = [Color("#5c280c"), Color("#964214"), Color("#cc641c"),
		Color("#ffa63c"), Color("#ffdca0"), Color("#fff6e2")]
	var _ink: Color = Color("#0b0f16")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(n: MapGen.MapNode) -> void:
		node = n
		queue_redraw()

	func _draw() -> void:
		if node == null:
			return
		var c := (size * 0.5).round()
		var tint := MapGen.region_colour(node)
		match node.type:
			MapGen.NodeType.STATION: _station(c)
			MapGen.NodeType.DERELICT: _derelict(c)
			MapGen.NodeType.EVENT: _beacon(c, tint)
			MapGen.NodeType.GOAL: _core(c)
			MapGen.NodeType.FIGHT: _battlefield(c)
			MapGen.NodeType.PULSAR: _pulsar(c)
			MapGen.NodeType.START:
				# Where you start is empty space. Drawing a marker here would put
				# an object in the one sector that is meant to have nothing in it.
				pass
			_:
				draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), tint, true)

	# --- the two-plane kit ---------------------------------------------------

	## One lit body. `deck` is how much of the height the top face takes: high
	## for something you are looking down onto, low for something hanging below
	## the eyeline.
	func _body(pos: Vector2, dim: Vector2, r: Array, deck: float = 0.55) -> void:
		var p := pos.round()
		var w := maxf(1.0, roundf(dim.x))
		var h := maxf(2.0, roundf(dim.y))
		var d := clampf(roundf(h * deck), 1.0, h - 1.0)
		draw_rect(Rect2(p - Vector2.ONE, Vector2(w + 2, h + 2)), _ink, true)
		draw_rect(Rect2(p, Vector2(w, d)), r[3], true)
		draw_rect(Rect2(p, Vector2(w, 1)), r[4], true)
		draw_rect(Rect2(p + Vector2(0, d - 1), Vector2(w, 1)), r[5], true)
		draw_rect(Rect2(p + Vector2(0, d), Vector2(w, h - d)), r[1], true)
		draw_rect(Rect2(p + Vector2(0, d), Vector2(w, minf(2.0, h - d))), r[2], true)
		_dither(Rect2(p + Vector2(0, d + 2), Vector2(w, (h - d) * 0.5)), r[2], 0.4)
		_dither(Rect2(p + Vector2(0, h - 4), Vector2(w, 3)), r[0], 0.45)
		draw_rect(Rect2(p + Vector2(0, h - 1), Vector2(w, 1)), r[0], true)

	## Anything hanging under a hull is in that hull's shadow: the same ramp,
	## shifted two stops down.
	func _under(r: Array) -> Array:
		return [r[0], r[0], r[1], r[1], r[2], r[3]]

	## Ordered 2x2 dither, the only kind of gradient this art style has.
	func _dither(r: Rect2, col: Color, density: float) -> void:
		var th := [0.0, 0.5, 0.75, 0.25]
		for j in int(r.size.y):
			for i in int(r.size.x):
				if th[(i % 2) + (j % 2) * 2] < density:
					draw_rect(Rect2(r.position + Vector2(i, j), Vector2.ONE), col, true)

	## A torus seen at the same three-quarter tilt as every hull in the game:
	## the far arc catches the light, the near arc falls into shadow.
	func _ring(c: Vector2, rx: float, ry: float, thick: float, r: Array) -> void:
		for i in int(rx * 2.0) + 1:
			var x := -rx + float(i)
			var k := 1.0 - (x / rx) * (x / rx)
			if k <= 0.0:
				continue
			var dy := ry * sqrt(k)
			for raw in [-1.0, 1.0]:
				var side := float(raw)
				var top := c.y + dy * side - (thick if side < 0.0 else 0.0)
				var lit := side < 0.0
				draw_rect(Rect2(Vector2(c.x + x, top - 1), Vector2(1, thick + 2)), _ink, true)
				draw_rect(Rect2(Vector2(c.x + x, top), Vector2(1, thick)),
					r[3] if lit else r[1], true)
				draw_rect(Rect2(Vector2(c.x + x, top), Vector2(1, 1)),
					r[4] if lit else r[2], true)
				draw_rect(Rect2(Vector2(c.x + x, top + thick - 1), Vector2(1, 1)),
					r[5] if lit else r[0], true)

	## A window with a light behind it. Warm, because someone is home; two
	## values, because a single flat pixel of orange is a dot and this is a room.
	func _window(pos: Vector2, dim: Vector2) -> void:
		draw_rect(Rect2(pos - Vector2.ONE, dim + Vector2(2, 2)), _ink, true)
		draw_rect(Rect2(pos, dim), _heat[1], true)
		draw_rect(Rect2(pos, Vector2(dim.x, maxf(1.0, dim.y * 0.5))), _heat[3], true)
		draw_rect(Rect2(pos, Vector2(maxf(1.0, dim.x * 0.6), 1)), _heat[5], true)

	# --- the places ----------------------------------------------------------

	## A ring station: a habitat torus turning around a docking spine, with the
	## lights on. The only friendly thing in the sector, and the only one that
	## gets to be warm.
	func _station(c: Vector2) -> void:
		_ring(c, 62.0, 26.0, 9.0, _grey)
		# Spokes, drawn between the arcs so the ring reads as one solid object
		# rather than two unrelated bands.
		for raw in [-30.0, 30.0]:
			var sx := float(raw)
			_body(c + Vector2(sx - 3.0, -24.0), Vector2(6, 48), _grey, 0.5)
		# Hub and docking spine
		_body(c + Vector2(-20, -13), Vector2(40, 26), _grey, 0.6)
		_body(c + Vector2(-52, -4), Vector2(104, 8), _grey, 0.5)
		_body(c + Vector2(-7, -34), Vector2(14, 22), _grey, 0.55)
		# Windows: two rows on the far arc, one on the hub, one on the mast.
		# Placed ON the arc rather than along a straight line at its apex, or the
		# outermost ones float off the ring entirely.
		for i in 9:
			var wx := -52.0 + float(i) * 13.0
			var wy := 26.0 * sqrt(maxf(0.0, 1.0 - (wx / 62.0) * (wx / 62.0)))
			_window(c + Vector2(wx, -wy - 8.0), Vector2(6, 4))
		for i in 5:
			_window(c + Vector2(-30 + i * 15, -6), Vector2(5, 3))
		_window(c + Vector2(-3, -30), Vector2(6, 3))
		# Navigation strobes: the one cold light on it, so it does not read as
		# a furnace.
		draw_rect(Rect2(c + Vector2(-64, -2), Vector2(3, 3)), Color("#8ec8e6"), true)
		draw_rect(Rect2(c + Vector2(61, -2), Vector2(3, 3)), Color("#8ec8e6"), true)

	## A wreck: the same construction with the light taken out of it and a hole
	## through the middle. Nothing here emits, which is the whole point — the
	## derelict is the station's picture with the power off.
	func _derelict(c: Vector2) -> void:
		# The keel first, so both halves sit on it. A ship broken in two reads as
		# two boxes until you can see the spine that used to join them.
		_body(c + Vector2(-26, -6), Vector2(48, 6), _dead, 0.4)
		for i in 7:
			draw_rect(Rect2(c + Vector2(-24 + i * 7, -6), Vector2(2, 6)), _dead[0], true)
		# Bow canted up, stern dropped and drifting away from it.
		_body(c + Vector2(-64, -26), Vector2(44, 30), _dead, 0.5)
		_body(c + Vector2(-54, -38), Vector2(26, 13), _dead, 0.66)
		_body(c + Vector2(14, -10), Vector2(52, 32), _dead, 0.5)
		_body(c + Vector2(28, -22), Vector2(20, 13), _dead, 0.66)
		# Torn ends: notches cut back into each half, deepest at the keel line,
		# so the break reads as something that happened rather than a cut.
		for i in 6:
			var dpt: int = [3, 7, 10, 8, 4, 2][i]
			draw_rect(Rect2(c + Vector2(-21 - dpt, -26 + i * 5),
				Vector2(dpt + 2, 5)), Color("#05080c"), true)
		for i in 7:
			var dpt2: int = [2, 5, 9, 11, 7, 3, 2][i]
			draw_rect(Rect2(c + Vector2(13, -11 + i * 5),
				Vector2(dpt2 + 1, 5)), Color("#05080c"), true)
		_dither(Rect2(c + Vector2(-22, -24), Vector2(38, 44)), Color("#05080c"), 0.22)
		# Dead viewports: the same rooms the station lights, unlit.
		for i in 4:
			draw_rect(Rect2(c + Vector2(-58 + i * 10, -8), Vector2(4, 3)),
				Color("#101922"), true)
		for i in 4:
			draw_rect(Rect2(c + Vector2(20 + i * 11, 4), Vector2(4, 3)),
				Color("#101922"), true)
		# The pieces that came off it, tumbling away and catching the same light.
		for raw2 in [[64, -34, 5], [78, -20, 3], [72, 12, 4], [90, 2, 2],
				[-70, 22, 3], [-84, 8, 2], [58, 30, 3]]:
			var d: Array = raw2
			var sz: float = float(d[2])
			var p := c + Vector2(float(d[0]), float(d[1]))
			draw_rect(Rect2(p - Vector2.ONE, Vector2(sz + 2, sz + 2)), _ink, true)
			draw_rect(Rect2(p, Vector2(sz, sz)), _dead[2], true)
			draw_rect(Rect2(p, Vector2(sz, 1)), _dead[4], true)

	## An unknown signal: a beacon nobody claims, still transmitting. The rings
	## are the message leaving; they thin as they go, which is the only depth
	## cue available for something that has no surface.
	func _beacon(c: Vector2, tint: Color) -> void:
		for i in 5:
			var rr := 26.0 + float(i) * 15.0
			var col := tint.lerp(Color("#070a10"), 0.18 + float(i) * 0.17)
			var step: int = 2 + i
			var n := int(rr * 2.4)
			for j in n:
				var a := TAU * float(j) / float(n)
				if j % step != 0:
					continue
				draw_rect(Rect2(c + Vector2(cos(a) * rr, sin(a) * rr * 0.62),
					Vector2(2, 2)), col, true)
		# The buoy itself. Small — most of the picture is the thing it is doing.
		_body(c + Vector2(-4, -34), Vector2(8, 62), _grey, 0.5)
		_body(c + Vector2(-16, -44), Vector2(32, 12), _grey, 0.7)
		_body(c + Vector2(-11, 24), Vector2(22, 7), _grey, 0.4)
		draw_rect(Rect2(c + Vector2(-6, -50), Vector2(12, 6)), _ink, true)
		draw_rect(Rect2(c + Vector2(-5, -49), Vector2(10, 4)), _heat[2], true)
		draw_rect(Rect2(c + Vector2(-5, -49), Vector2(10, 2)), _heat[4], true)
		draw_rect(Rect2(c + Vector2(-3, -49), Vector2(6, 1)), _heat[5], true)

	## The Custodian's hole. A disc seen nearly edge-on, brightest where it is
	## about to fall in, with the shadow left as a shadow.
	func _core(c: Vector2) -> void:
		# The halo is dithered outward rather than stacked out of translucent
		# boxes: a box has corners and at this size you can see every one of
		# them, which is exactly what the first version of this looked like.
		for i in 6:
			var rr := 92.0 - float(i) * 13.0
			var col: Color = [_heat[0], _heat[0], _heat[1], _heat[1],
				_heat[2], _heat[3]][i]
			var dens := 0.16 + float(i) * 0.13
			var ry := rr * 0.42
			for j in int(ry * 2.0) + 1:
				var y := -ry + float(j)
				var k := 1.0 - (y / ry) * (y / ry)
				if k <= 0.0:
					continue
				var hw := rr * sqrt(k)
				_dither(Rect2(c + Vector2(-hw, y), Vector2(hw * 2.0, 1)), col, dens)
		# The disc, seen nearly edge on: the far side lensed up over the top,
		# the near side passing in front of the shadow.
		for raw in [-1.0, 1.0]:
			var side := float(raw)
			for i in 145:
				var x := -72.0 + float(i)
				var k2 := 1.0 - (x / 72.0) * (x / 72.0)
				if k2 <= 0.0:
					continue
				var dy := 22.0 * sqrt(k2) * side
				draw_rect(Rect2(c + Vector2(x, dy - 1), Vector2(1, 3)),
					_heat[4] if side < 0.0 else _heat[2], true)
				draw_rect(Rect2(c + Vector2(x, dy - 1), Vector2(1, 1)),
					_heat[5] if side < 0.0 else _heat[3], true)
		draw_rect(Rect2(c + Vector2(-76, -2), Vector2(152, 5)), _heat[3], true)
		draw_rect(Rect2(c + Vector2(-76, -1), Vector2(152, 2)), _heat[5], true)
		# The shadow, painted over the near side of the disc — the one thing in
		# the picture that is an absence rather than an object.
		for j in 29:
			var t := float(j) / 28.0
			var hw2 := 15.0 * sqrt(maxf(0.0, 1.0 - (t * 2.0 - 1.0) * (t * 2.0 - 1.0)))
			draw_rect(Rect2(c + Vector2(-hw2, -14.0 + t * 28.0),
				Vector2(hw2 * 2.0, 1)), Color("#05070c"), true)

	## A fight that has already happened, or one about to. Cleared, the sector is
	## the debris; uncleared, it is one raider holding station and waiting.
	func _battlefield(c: Vector2) -> void:
		if node.cleared:
			# Dust first, chunks over it. Drawn the other way round the haze is a
			# grey rectangle laid on top of the only objects in the picture.
			for ring in 2:
				var rx := 58.0 - float(ring) * 24.0
				var ry := 23.0 - float(ring) * 10.0
				for j in int(ry * 2.0) + 1:
					var y := -ry + float(j)
					var k := 1.0 - (y / ry) * (y / ry)
					if k <= 0.0:
						continue
					var hw := rx * sqrt(k)
					_dither(Rect2(c + Vector2(-hw, y), Vector2(hw * 2.0, 1)),
						Color("#182430") if ring == 0 else Color("#22303f"),
						0.28 + float(ring) * 0.1)
			# Chunks of what used to be a ship, still lit from above and still
			# drifting apart along the axis it broke on.
			for i in 15:
				var a := float(i) * 1.31
				var p := (c + Vector2(cos(a) * (14.0 + float(i) * 4.6),
					sin(a) * (8.0 + float(i) * 2.4))).round()
				var s := 5.0 - float(i % 3) * 1.5
				draw_rect(Rect2(p - Vector2.ONE, Vector2(s + 2, s + 2)), _ink, true)
				draw_rect(Rect2(p, Vector2(s, s)), _dead[2], true)
				draw_rect(Rect2(p, Vector2(s, 1)), _dead[4], true)
				if i % 4 == 0:
					draw_rect(Rect2(p + Vector2(s, 1), Vector2(s * 1.6, 1)),
						_dead[1], true)
			return
		# A raider, nose left, drawn at the same scale as the wreck field so the
		# two states of this sector are obviously the same place.
		_body(c + Vector2(-56, -13), Vector2(112, 28), _grey, 0.55)
		_body(c + Vector2(-20, -27), Vector2(46, 15), _grey, 0.64)
		_body(c + Vector2(-10, 15), Vector2(32, 9), _under(_grey), 0.28)
		for i in 6:
			draw_rect(Rect2(c + Vector2(-42 + i * 17, -9), Vector2(1, 11)),
				_grey[1], true)
			draw_rect(Rect2(c + Vector2(-41 + i * 17, -9), Vector2(1, 11)),
				_grey[4], true)
		draw_rect(Rect2(c + Vector2(-50, -9), Vector2(16, 5)), Color("#3a6b8c"), true)
		draw_rect(Rect2(c + Vector2(-50, -9), Vector2(11, 2)), Color("#8ec8e6"), true)
		draw_rect(Rect2(c + Vector2(-50, -9), Vector2(7, 1)), Color("#cfe8f5"), true)
		# It has its engines lit and its warning light on. Both are emitted.
		for i in 10:
			var t := float(i) / 10.0
			var hh := 8.0 - t * 6.0
			draw_rect(Rect2(c + Vector2(56 + float(i) * 4, -hh * 0.5),
				Vector2(4, hh)),
				_heat[5] if t < 0.18 else (_heat[3] if t < 0.5 else _heat[1]), true)
		draw_rect(Rect2(c + Vector2(-4, -31), Vector2(3, 3)), Color("#d64a3a"), true)

	## The star itself is barely a pixel — a neutron star is a city across — so
	## what you see is the beam. Two cones sweeping out of one bright point, and
	## the wreck of the star that made it still expanding around them.
	func _pulsar(c: Vector2) -> void:
		for i in 26:
			var a := float(i) * 0.242
			var rr := 26.0 + float(i) * 3.4
			var p := c + Vector2(cos(a) * rr, sin(a) * rr * 0.5)
			draw_rect(Rect2(p, Vector2(2, 2)), Color("#2f4a58"), true)
			draw_rect(Rect2(p, Vector2(2, 1)), Color("#456878"), true)
		for raw in [-1.0, 1.0]:
			var side := float(raw)
			for i in 22:
				var t := float(i) / 22.0
				var spread := 2.0 + t * 16.0
				for j in int(spread * 0.6):
					var off := (float(j) / maxf(1.0, spread * 0.6) - 0.5) * spread
					var col := Color("#bff0ff") if t < 0.35 else Color("#5f9ab0")
					if t > 0.7:
						col = Color("#2c4a5c")
					draw_rect(Rect2(c + Vector2(side * (10.0 + t * 74.0),
						off - 12.0 * side * t), Vector2.ONE), col, true)
		draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), Color("#ffffff"), true)
		draw_rect(Rect2(c - Vector2(4, 1), Vector2(8, 2)), Color("#dff6ff"), true)


## Your own hull as a drop target. Attacks are refused here — dropping a weapon
## on yourself should not silently do something else.
class ShipSlot extends Control:
	signal card_dropped(view: CardView)

	var art: ShipView
	var _hot: bool = false
	var claim: Callable
	var preview: Callable
	var _drag_text: String = ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		art = ShipView.new()
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Behind the slot's own _draw. A Control paints itself first and its
		# children after, so the brace number was being drawn and then covered
		# by the ship it was meant to sit on.
		art.show_behind_parent = true
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
		if ok:
			var t: String = "" if not preview.is_valid() else String(preview.call(c, -1))
			if t != _drag_text:
				_drag_text = t
				queue_redraw()
			if claim.is_valid():
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

		# What this card would give you, over your own hull. Same idea as the
		# enemy's number and the opposite colour: one is what you take off them,
		# the other is what you put on yourself.
		if _drag_text != "":
			var f := UITheme.pixel_font()
			var fs := UITheme.FS_HEAD
			var tw := f.get_string_size(_drag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var at := Vector2((size.x - tw) * 0.5, size.y * 0.5 + fs * 0.4)
			draw_string(f, at + Vector2(1, 1), _drag_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.75))
			draw_string(f, at, _drag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.GOOD)
