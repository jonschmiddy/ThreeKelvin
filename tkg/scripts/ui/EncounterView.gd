class_name EncounterView
extends Control

## One continuous space. Your ship on the left, whatever you are facing on the
## right, a single starfield behind both.
##
## Not two panels. The moment you put a border around each half you get a stat
## block facing another stat block; with one field behind them the ship reads as
## a thing in a place. This is the frame the sector view and combat share, so the
## ship never disappears between them.
##
## THE CONVOY sits to the left of your hull, and only when there is one. Your
## partners are drawn from the HALF sheet and you are not, so the party reads at
## two to one — 248 against 124 for a heavy — and the ship you fly is the subject
## by size as well as by position: centre of frame, facing what you are facing,
## and the one you can drop a card on.
##
## Two sizes and no more. Pixel art scales by whole numbers, so the ladder is
## 1x, half and quarter, and a quarter-size medium is 50x20 — which fails the
## test in CONVOY_MAX below, that a hull nobody can identify is not a hull. Half
## is a second set of FILES rather than a scale, because nothing below 1x exists
## at the renderer. See HullData.sprite_half.
## The others are a column beside it, each in a box just tall enough for a hull,
## with the name and the two gauges painted over it.
##
## `docs/coop-design.md` §15 calls the party screen the hardest design problem
## outside the netcode, and this does not solve it — four hands and four intent
## strips still have nowhere to live. What it solves is the half that had to
## come first: a partner is drawn from a description of THEIR ship. See
## ShipBuild.

enum Subject { AREA, ENEMY }

var _row: HBoxContainer
## The other ships in the party. Empty in the solo game.
var _convoy: VBoxContainer
## The box the column sits in. Hidden rather than the column itself: an
## HBoxContainer puts its separation either side of every VISIBLE child, so a
## hidden column inside a visible margin still cost the solo game twenty-four
## pixels of empty left edge.
var _convoy_pad: MarginContainer
var _made_convoy: Array[ConvoySlot] = []
## The "+N MORE" chip, or null when everybody here is drawn. See CONVOY_MAX.
var _overflow: Button = null
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

	# Ahead of your hull in the row, so the party reads left to right in the
	# order the lobby lists it and your own ship keeps the position it has
	# always had — nearest the middle, facing what you are facing.
	_convoy_pad = MarginContainer.new()
	_convoy_pad.add_theme_constant_override("margin_top", CONVOY_TOP)
	_convoy_pad.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_convoy_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_convoy_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_convoy_pad.visible = false
	_row.add_child(_convoy_pad)
	_convoy = VBoxContainer.new()
	_convoy.add_theme_constant_override("separation", 4)
	_convoy.alignment = BoxContainer.ALIGNMENT_CENTER
	_convoy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_convoy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_convoy_pad.add_child(_convoy)
	Sig.party_changed.connect(refresh_convoy)
	# And when a fight does. Which of your partners is in the room with you is a
	# fact about the fight, not about the party — see ConvoySlot._engaged.
	Sig.party_fight_changed.connect(func(_at: int) -> void: refresh_convoy())

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

	refresh_convoy()


## How wide one partner gets: the biggest canvas any hull draws into, so nothing
## is ever cropped nose-first — which reads as a mistake rather than as distance.
##
## ASKED, NOT TYPED, and it used to be typed. 208 was measured against the
## procedural drawing and was already stale when the real hulls landed: every
## heavy in the party lost about fifteen pixels off each end, and losing them off
## the FRONT is the half you notice. A hull sprite is cropped tight to its ship,
## so horizontal crop is never empty space.
##
## The HALF set, because that is what a convoy slot draws — 75 to 124 across
## rather than 150 to 248. Asking for the full width here would reserve twice the
## column the ships need and push your own hull off centre.
##
## Vertical is a different question and stays a constant — see CONVOY_H. A canvas
## is taller than its ship by the bob headroom, so trimming rows costs nothing.
static func convoy_w() -> int:
	return DB.widest_hull(true)
## And how tall. Tall enough for the tallest canvas any hull draws into, so no
## partner is ever cropped along the hull line — a ship with its keel cut off
## reads as a bug, and it is the one crop a viewer cannot explain to themselves
## as distance.
##
## Three of these plus the separations is 362 rows against the 378 the arena
## leaves under the sector header. That is the whole arithmetic, and it is also
## a CEILING rather than a coincidence — see CONVOY_MAX.
const CONVOY_H := 118

## How many partners the strip will draw, however many are in the room.
##
## Three, because three is what fits: the arithmetic above is not a description
## of the tuned party size, it is the number of 118px rows the arena has room
## for. That distinction did not matter while MAX_PLAYERS was four and does the
## moment it is not — photographed at seven, the fourth ship was cut in half by
## the quiet strip and the last three were not drawn at all. Silently.
##
## So the overflow is SAID rather than dropped. A chip under the column carries
## the count and opens the party page, which scrolls and therefore has no
## opinion about how many ships there are. The strip keeps the job it is good at
## — who is in this room, at a glance, without leaving the sector — and hands
## off the one it cannot do.
##
## Not tuned per party size on purpose. A strip that shrinks its rows to fit six
## ships is a strip where no ship is legible, and the point of drawing a hull
## rather than a name is that you can tell a Dreadnought from a Sloop.
const CONVOY_MAX := 3
## Cleared for the sector's name and its two lines of description, which are
## painted over this same corner by the screen above. Without it the first
## partner's name is written across the name of the system.
const CONVOY_TOP := 62
## How long after your own ship the convoy starts, and how far apart they are.
## Short: the approach itself runs four and a half seconds, so the stagger only
## has to break the lockstep, not queue them up.
const ARRIVE_LEAD := 0.25
const ARRIVE_GAP := 0.35

## Who is actually HERE, in arrival order.
##
## The sector is a place, not a party list. A ship two hundred light years away
## is in your convoy and is not in this room, and drawing it beside your hull
## says the opposite — during a fight it says it is helping. So the strip is
## filtered by position and the STAR CHART is where the whole party lives,
## because that is the screen whose subject is where everybody is.
##
## `where_is` returns -1 for somebody who has not reported a position yet, which
## is a real answer and correctly matches nothing: a player still on the chassis
## select has a galaxy and no place in it.
func _here() -> Array:
	if Run.map.is_empty():
		return []
	var at := Run.at
	return Net.partners().filter(func(s: Dictionary) -> bool:
		return int(s.get("at", -1)) == at)


## Who is flying with you, redrawn when that changes.
##
## Rebuilt only when the PARTY changes, not when a ship does. A partner's own
## view is wired to `Sig.party_changed` itself and repaints in place, so a new
## gun on somebody else's hull costs a repaint rather than a rebuild of the
## column it sits in.
func refresh_convoy() -> void:
	# `tree_exited` brings us back here when a departing slot finishes, and that
	# can be the frame the whole screen is being torn down on — a sector swap
	# frees the column and the slots inside it together.
	if not is_instance_valid(_convoy):
		return
	var here := _here()
	# THE COUNTER OCCUPIES A PLACE. The column has room for CONVOY_MAX rows and
	# not one pixel more — 362 against 378 — so a chip added BESIDE three hulls
	# pushes the block ten rows over, and because the column is centred it spends
	# half of that going upward, writing the first partner's name across the name
	# of the system. Measured, by adding it and looking.
	#
	# So the strip has three places rather than three ships: when more ships are
	# here than there are places, the last place holds the count instead of a
	# hull. Nobody is dropped, the arithmetic above stays true, and the rule is
	# one sentence.
	var shown := CONVOY_MAX if here.size() <= CONVOY_MAX else CONVOY_MAX - 1
	var them: Array = here.slice(0, shown) if here.size() > shown else here
	var want: Array = them.map(func(s: Dictionary) -> int: return int(s.id))

	# A DIFF, NOT A REBUILD, and that is what makes a departure drawable at all.
	# Clearing the column and building it again gave every remaining ship a
	# fresh arrival for somebody else's jump, and gave the ship that left no
	# frame to leave in — it was simply not in the next list.
	for c in _made_convoy.duplicate():
		if want.has(c.peer):
			continue
		_made_convoy.erase(c)
		# Still a child, so the column keeps its height and the flash has
		# somewhere to happen. It frees itself when the light goes out, and
		# `tree_exited` brings us back here to close the column up.
		c.jump_out()
		c.tree_exited.connect(refresh_convoy, CONNECT_ONE_SHOT)

	for i in them.size():
		var id := int(them[i].id)
		var slot := _slot_for(id)
		if slot == null:
			slot = ConvoySlot.new(id, CONVOY_H)
			_convoy.add_child(slot)
			_made_convoy.append(slot)
			# Staggered, and behind you. Four hulls starting the same approach
			# on the same frame arrive as one object with four parts; a fraction
			# of a second apart they read as ships flying in formation. Yours
			# goes first because it is the one the screen is about.
			#
			# The stagger applies to the OPENING convoy only. A ship arriving on
			# its own, into a system you are already sitting in, has nobody to be
			# staggered against and a delay on it is just latency.
			var lone := _made_convoy.size() == 1 and _convoy.get_child_count() == 1
			slot.jump_in(0.0 if not lone else ARRIVE_LEAD)
		# Keep the column in the party's order even after somebody has left a
		# hole in the middle of it.
		_convoy.move_child(slot, i)
		slot.bind(them[i])

	_refresh_overflow(here.size() - them.size())

	# Visible while any SHIP is in the column, including one on its way out.
	# `them.is_empty()` would take the last partner off screen on the frame they
	# pressed JUMP, which is the one frame the effect exists to fill.
	#
	# Counted off the slots rather than off the children, because the overflow
	# chip is a child too and a column holding nothing but a chip is a column
	# that should not be on screen.
	# YOUR HULL COMES DOWN TO 1x WHILE ANYBODY IS FLYING WITH YOU.
	#
	# 2x is right for the game one person is looking at: the sector is where a
	# run is mostly spent and the ship should carry it. It is wrong the moment
	# the convoy column appears, because then the left of the screen has to hold
	# your hull AND up to three partners, and a hull at 2x takes the room the
	# column needs.
	#
	# Hung off the same fact the column's own visibility is — one test, so the
	# two cannot disagree about whether there is a party — and re-applied here
	# rather than set once, because somebody joining or leaving mid-run is
	# exactly the case a value set at build time would miss.
	var crowded := not _made_convoy.is_empty()
	_convoy_pad.visible = crowded
	# YOUR ship stays on the full sheet. Your partners are on the half one, so
	# the party reads at two to one and the ship you fly is plainly the subject.
	#
	# This is the one place the old code could not go. Everything used to be the
	# same size in a party — your hull dropped from 2x to 1x to make room and
	# landed on the convoy's own scale — so the class note above had to say the
	# foreground came from position alone, because there was no other size to
	# give it. There is now: 248 against 124 for a heavy, and both fit, because
	# the column costs 124 and a gap rather than 248 and a gap.
	#
	# A one-line flip if it reads wrong. `use_half(crowded)` puts everybody back
	# on the same footing.
	_ship.use_half(false)


## Everybody in this room the column had no room for.
##
## A count and a way to see them, which is the whole of it. The alternative was
## drawing them smaller, and a hull nobody can identify is not a hull — see
## CONVOY_MAX.
func _refresh_overflow(extra: int) -> void:
	if extra <= 0:
		if _overflow != null:
			_overflow.queue_free()
			_overflow = null
		return
	if _overflow == null:
		_overflow = Widgets.button("", func() -> void: Router.show_party())
		# The one thing in this overlay that takes a click. Its parents are
		# MOUSE_FILTER_IGNORE so that cards can be dropped through the column,
		# and a child sets its own filter — so this stays pressable without
		# making the rest of the strip swallow the arena's input.
		_overflow.mouse_filter = Control.MOUSE_FILTER_STOP
		_convoy.add_child(_overflow)
	_overflow.text = "+%d MORE" % extra
	_overflow.tooltip_text = Widgets.tip(
		"More ships are here than the strip can draw. Opens the party page.")
	# Always last, under the hulls, even after a slot has been inserted above it.
	_convoy.move_child(_overflow, _convoy.get_child_count() - 1)


func _slot_for(id: int) -> ConvoySlot:
	for c in _made_convoy:
		if c.peer == id:
			return c
	return null


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
		Widgets.clear(_slots)
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

## Where YOUR hull is, in this view's own coordinates.
##
## The mirror of `enemy_anchor`, and it exists for the same reason: anything that
## wants to sit under the ship has to ask where the ship IS. Deriving it from
## `ShipSlot.HULL_BIAS` and a guess at how wide the slot is gets it wrong the
## moment the row gains or loses a child -- which it does, because the enemy
## slots live in the same row.
func self_anchor() -> Vector2:
	if _ship == null:
		return size * 0.5
	return get_global_transform().affine_inverse() \
		* _ship.get_global_rect().get_center()


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
			# READ WHAT IS HERE. The three types this replaced each had their own
			# picture, and the picture is still worth having -- it just comes off
			# the options now instead of a label chosen before anything rolled.
			MapGen.NodeType.SYSTEM:
				if OptionTable.system_has_tag(node, &"fight"):
					_battlefield(c)
				elif OptionTable.system_has_tag(node, &"salvage"):
					_derelict(c)
				else:
					_beacon(c, tint)
			MapGen.NodeType.CORE: _core(c)
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

	## How much of the slot the hull is centred in. The rest is empty space on
	## its right.
	##
	## The frame is "your ship left, what you face right", and a Control that
	## fills its half and centres its texture puts the ship in the middle of the
	## screen — which reads as neither. Centring it in the left two thirds of the
	## same box moves it back onto the left without changing the layout, and it
	## leaves the ship pointing INTO the space the subject occupies rather than
	## across it.
	##
	## Done with an anchor and not with `position`, because `ShipView.arrive()`
	## animates position and puts it back to zero when the ship parks.
	const HULL_BIAS := 0.68

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		art = ShipView.new()
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# set_anchor(), not `anchor_right =`. The property setter defaults to
		# keep_offset TRUE, so it holds the control's current size by moving the
		# offset the other way — which is an elaborate no-op.
		art.set_anchor(SIDE_RIGHT, HULL_BIAS, false)
		# Behind the slot's own _draw. A Control paints itself first and its
		# children after, so the brace number was being drawn and then covered
		# by the ship it was meant to sit on.
		art.show_behind_parent = true
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 2x, matching the refit screen and the chassis select. The hulls are
		# authored small enough that 1x here left the ship a detail in the
		# middle of its own encounter — and this is the screen the game is
		# mostly played on, so it is the one that should agree with the others.
		#
		# 1x, solo or crowded. The hulls are authored at 2x their box, so this
		# is the full-size ship and there is no step below it.
		#
		# zoom(), not magnify(): the slot's width is anchored to a fraction of
		# the encounter and a minimum size would fight that.
		art.zoom(1)
		# The hull is now bigger than its slot on the deepest frames, and the
		# enemy panel is immediately to the right of it.
		art.clip_contents = true
		add_child(art)

		# WHAT IS BOLTED TO IT, on the screen the game is mostly played on. The
		# refit screen was the only place a fitted ship could be seen, which
		# made every part you chose a thing you looked at once and then flew
		# around without. Passive: this is a picture of your ship, not a place
		# to change it.
		var mounts := MountPoints.new()
		mounts.attach(art)
		mounts.passive()
		art.add_child(mounts)

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


## One ship flying with you: their hull, their name, and how they are doing.
##
## The readouts are PAINTED OVER the ship rather than stacked under it, which is
## the same choice `ShipSlot` makes below and for the same reason — a column of
## four ships each with a label and two bars under it is sixteen rows of chrome
## in an arena that has none to spare, and a name written across a hull is
## plainly that hull's name.
##
## It is not a drop target and it never will be. Cards are played from your deck
## onto your ship and onto what is shooting at you; a partner is a thing you can
## see, not a thing you can aim at. See `docs/coop-design.md` §5.
## The light a ship arrives and leaves in.
##
## ONE ANIMATION FOR BOTH DIRECTIONS, and that is not a shortcut. A jump is a
## column of light with a hull either side of it: what differs between arriving
## and leaving is only whether the ship is there before the flash or after it.
## Two separate effects would be two things to keep in step and would read as
## two different events, which they are not.
##
## Cold, not ember. Every other light in this game is heat — weapons, the hull
## shader, the overheat warning — so a jump has to be the one thing on screen
## that is bright and not warm, or it reads as another gun going off.
##
## Drawn rather than animated. Everything here is on the pixel grid at integer
## widths and the brightness is stepped, for the reason CombatFx records: a
## pixel is lit or it is not, and fading one through alpha is how pixel art
## starts looking like a screensaver.
class JumpFlare extends Control:
	## Long enough to be an event, short enough that four of them staggered do
	## not turn arriving into a cutscene.
	const LIFE := 0.40
	## The moment the hull changes hands. The flash is at its widest here, so
	## the swap happens behind the brightest frame and is never seen.
	const PEAK := 0.42
	const CORE := Color("#e4f2ff")
	## Wide enough to be a column rather than a rule. The slot is 208px and the
	## hull about half of it, so a beam this wide is plainly a thing the ship
	## came out of and not a line somebody drew beside it.
	const MAX_W := 20.0
	## The three beats, as fractions of LIFE. OPEN is the column arriving, PEAK
	## is the flash, SHUT is it gone — and the width curve is built to reach its
	## maximum exactly AT PEAK rather than somewhere near it, because PEAK is
	## also the frame the hull changes hands on. A swap that happens beside the
	## brightest frame instead of behind it is a ship seen to appear.
	const OPEN := 0.22
	const SHUT := 0.80

	signal peaked()
	signal finished()

	## Where the column stands, as a fraction of the slot's width. Your own hull
	## is biased left of centre — see ShipSlot.HULL_BIAS — and a beam that
	## arrives somewhere the ship is not is a beam that missed.
	var centre: float = 0.5

	var _t: float = -1.0
	var _delay: float = 0.0
	var _fired: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		visible = false
		set_process(false)

	func play(delay: float = 0.0) -> void:
		_t = 0.0
		_delay = maxf(0.0, delay)
		_fired = false
		visible = true
		set_process(true)
		queue_redraw()

	func _process(delta: float) -> void:
		if _delay > 0.0:
			_delay -= delta
			return
		_t += delta / LIFE
		if not _fired and _t >= PEAK:
			_fired = true
			peaked.emit()
		if _t >= 1.0:
			_t = -1.0
			visible = false
			set_process(false)
			finished.emit()
			return
		queue_redraw()

	func _draw() -> void:
		if _t < 0.0 or _delay > 0.0:
			return
		var t := clampf(_t, 0.0, 1.0)
		var cx := roundf(size.x * centre)

		# Height: opens from the middle, holds, then snaps shut. The hold is
		# what makes it a place rather than a flash.
		var tall := 1.0
		if t < OPEN:
			tall = t / OPEN
		elif t > SHUT:
			tall = 1.0 - (t - SHUT) / (1.0 - SHUT)
		var h := roundf(size.y * clampf(tall, 0.0, 1.0))
		if h < 1.0:
			return
		var y0 := roundf((size.y - h) * 0.5)

		# Width: two segments, meeting at PEAK. Not one sine across the whole
		# life — that put the widest frame at 0.62 while the hull swapped at
		# 0.42, and the swap was visible next to the flash instead of inside it.
		var flare := 0.0
		if t <= PEAK:
			flare = smoothstep(OPEN, PEAK, t)
		else:
			flare = 1.0 - smoothstep(PEAK, SHUT, t)
		var w := 1.0 + roundf(flare * MAX_W)

		# Two planes, stepped. A pixel is lit or it is not — see CombatFx.
		if w > 3.0:
			draw_rect(Rect2(Vector2(cx - roundf(w * 0.5), y0), Vector2(w, h)),
				UITheme.ICE if flare > 0.35 else UITheme.CHILL, true)
		var core_w := maxf(1.0, roundf(w * 0.3))
		draw_rect(Rect2(Vector2(cx - roundf(core_w * 0.5), y0), Vector2(core_w, h)),
			CORE if flare > 0.25 else UITheme.ICE, true)

		# The spill. Two dashed streaks at the waist, thinning outward, which is
		# what stops the column reading as a rectangle somebody drew.
		if flare <= 0.4:
			return
		var reach := roundf(flare * 34.0)
		var my := roundf(size.y * 0.5)
		for i in int(reach):
			if i % 3 == 2 or i > reach - 5:
				continue
			var col := CORE if float(i) < reach * 0.3 else UITheme.CHILL
			draw_rect(Rect2(Vector2(cx + w * 0.5 + i, my), Vector2.ONE), col, true)
			draw_rect(Rect2(Vector2(cx - w * 0.5 - i - 1, my), Vector2.ONE), col, true)


class ConvoySlot extends Control:
	var peer: int = 0
	var art: ShipView
	var flare: JumpFlare
	## On its way out and already freed as far as the column is concerned. Kept
	## as a child until the flash finishes, because a ship that vanishes on the
	## frame its owner pressed JUMP has not left, it has been deleted.
	var _leaving: bool = false
	var _label: String = ""
	var _hull_at: float = 1.0
	var _heat_at: float = 0.0
	var _lost: bool = false
	## In the same fight as you, right now.
	##
	## Worth its own mark because the column shows the whole party and a fight
	## involves some of it. Three ships in the sector and two in the fight is the
	## normal case, not the exception — people arrive at different times — so
	## "who is shooting at the thing shooting at me" cannot be read off presence.
	var _engaged: bool = false

	## Bars are drawn to a fixed width, not to the slot's, for the reason
	## EnemySlot.BAR_W records: a readout's LENGTH should say how much is left,
	## and one that stretches to fill the layout says how much room there was.
	const BAR_W := 92.0
	const BAR_H := 3.0

	func _init(id: int, view_height: int) -> void:
		peer = id
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The ship is drawn at its own size and this box shows the middle of it.
		# Cropping rather than scaling: integer magnification is the only
		# resizing the art direction allows, and half of 1 is not a pixel.
		clip_contents = true
		custom_minimum_size = Vector2(EncounterView.convoy_w(), view_height)
		art = ShipView.new()
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Behind this slot's own _draw, so the name and the bars sit on the hull
		# instead of under it.
		art.show_behind_parent = true
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.follow_peer(id)
		# Always the half sheet. A convoy slot only exists when there IS a party,
		# which is exactly the condition the reduced set is for.
		art.use_half(true)
		# Slower and shallower than your own ship's. They are further away, and
		# four hulls bobbing in step read as one object.
		art.bob(1, 0.19)
		add_child(art)
		flare = JumpFlare.new()
		add_child(flare)

	## Somebody dropped into the system. The hull is hidden until the flash is
	## at its widest, so it is never seen to appear.
	func jump_in(delay: float = 0.0) -> void:
		art.visible = false
		flare.peaked.connect(func() -> void:
			art.visible = true
			# And ask for the name and the gauges back. They are painted by this
			# slot rather than by the hull, and _draw() bailed out while there
			# was no hull under them — without this the ship returns and its
			# label does not, because nothing else redraws a settled convoy.
			queue_redraw()
			# Into the same approach every ship in this game makes. The flare is
			# punctuation on the arrival, not a replacement for it — four hulls
			# materialising in place and holding still would read as a menu.
			art.arrive(1, 0.0), CONNECT_ONE_SHOT)
		flare.play(delay)
		# Throttled. A convoy arriving is three or four of these a fraction of a
		# second apart, and the same sample four times over reads as a stutter
		# rather than as four ships.
		Audio.play(&"jump", 0.10, 140)

	## And left. Same flash, opposite side of it.
	func jump_out() -> void:
		_leaving = true
		flare.peaked.connect(func() -> void:
			art.visible = false
			queue_redraw(), CONNECT_ONE_SHOT)
		flare.finished.connect(queue_free, CONNECT_ONE_SHOT)
		flare.play(0.0)
		Audio.play(&"jump", 0.10, 140)
		queue_redraw()

	func leaving() -> bool:
		return _leaving

	func bind(slot: Dictionary) -> void:
		var b: ShipBuild = Net.build_of(peer)
		var who := String(slot.get("name", "")).to_upper()
		if b == null:
			# In the party, not yet in a ship. A name with no readouts under it
			# says that better than a full hull bar on a ship nobody is flying.
			_label = "%s · NO SHIP YET" % who
			_hull_at = 0.0
			_heat_at = 0.0
			_lost = false
		else:
			_label = "%s · %s" % [who,
				DB.hull_class(b.hull.manufacturer, b.hull.weight).to_upper()]
			_hull_at = clampf(float(b.hp) / float(maxi(1, b.max_hp)), 0.0, 1.0)
			_heat_at = clampf(b.heat_ratio(), 0.0, 1.0)
			_lost = b.dead
		var f := Net.fight_at(Run.at) if not Run.map.is_empty() else null
		_engaged = f != null and not f.over and f.crew.has(peer)
		art.modulate = Color(0.45, 0.45, 0.52) if _lost else Color.WHITE
		queue_redraw()

	func _draw() -> void:
		# Nothing without a hull under it. The label and the gauges are painted
		# OVER the ship rather than under it, so a slot that kept drawing them
		# while the hull was away would leave a name and two bars hanging in
		# empty space — before an arrival as much as after a departure.
		if not art.visible:
			return
		var f := UITheme.pixel_font()
		var fs := UITheme.FS_SMALL
		var text := "LOST · " + _label if _lost else _label
		if _engaged and not _lost:
			# The same arrow the combat log puts on a shot of yours. Somebody
			# firing on your side is the one thing in this column that is about
			# the fight rather than about the convoy.
			text = "▸ " + text
		# Shadowed, because the label sits on a hull rather than on a panel and
		# the hull is the same value range as the type.
		draw_string(f, Vector2(1, fs + 1), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
		var ink := UITheme.CHILL
		if _lost:
			ink = UITheme.COLD
		elif _engaged:
			ink = UITheme.GOOD
		draw_string(f, Vector2(0, fs), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		if _lost or _hull_at <= 0.0:
			return
		# Directly under the name rather than at the floor of the slot. The ship
		# is centred in the box and the box is taller than the ship, so bars on
		# the floor float in space below it and read as belonging to whoever is
		# next in the column.
		#
		# Hull above heat, which is the order they are stacked on the HUD and
		# under every enemy.
		_gauge(float(fs) + 3.0, _hull_at, UITheme.HULL_GREEN)
		_gauge(float(fs) + 3.0 + BAR_H + 1.0, _heat_at,
			UITheme.FLARE if _heat_at >= 1.0 else UITheme.EMBER)

	func _gauge(y: float, at: float, col: Color) -> void:
		draw_rect(Rect2(Vector2(0, y), Vector2(BAR_W, BAR_H)), Color("#0d131b"), true)
		if at > 0.0:
			draw_rect(Rect2(Vector2(0, y), Vector2(BAR_W * at, BAR_H)), col, true)
