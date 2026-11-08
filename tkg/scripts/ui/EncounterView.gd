class_name EncounterView
extends Control

## One shared field, not two panels, so the ship reads as a thing in a place.
## Why: docs/why/EncounterView.md#frame-and-convoy

enum Subject { AREA, ENEMY }

var _row: HBoxContainer
## The other ships in the party. Empty in the solo game.
var _convoy: VBoxContainer
## Hide the box, not the column: a hidden child in an HBox still costs its separation.
var _convoy_pad: MarginContainer
var _made_convoy: Array[ConvoySlot] = []
## The "+N MORE" chip, or null when everybody here is drawn. See CONVOY_MAX.
var _overflow: Button = null
var _ship_slot: ShipSlot
var _ship: ShipView
var _area: AreaView
var _slots: Control
var _made: Array[EnemySlot] = []
## Slots rebuild only on count change, so a mode change must rebuild them too.
## Else a new contact drew over a dead binding and could not be hit.
## Why: docs/why/EncounterView.md#slot-modes
var _slots_mode: StringName = &""
var _tint: Color = Color("#16202c")
## What is actually out there: the system this is, seen side on, in the
## rendering style (`LocalSky`). Behind everything, including the gas.
var backdrop: LocalSky
## Dust drifting between the camera and the fight (`LocalDust`).
var dust: LocalDust
## Tracers, sparks and debris. Added last so it draws over the ship and the
## enemies, and ignores the mouse so it can never eat a card drop.
var fx: CombatFx
## Drifting gas, shown only in systems that sit inside a nebula, and only in
## LEGACY: in the other styles the cloud's own currents are the gas.
var weather: NebulaWeather
## the place the sky and the gas were last set to
var _place: MapGen.MapNode = null

func _ready() -> void:
	clip_contents = true
	_row = HBoxContainer.new()
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.add_theme_constant_override("separation", 24)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)

	# Ahead of your hull so the party reads in lobby order and your ship keeps its place.
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
	# Deferred: a roster push can land mid scene setup, where add_child() fails.
	# The partner's slot is then remembered but never drawn.
	# Why: docs/why/EncounterView.md#deferred-roster
	Sig.party_changed.connect(refresh_convoy, CONNECT_DEFERRED)
	# And when a fight does. Which of your partners is in the room with you is a
	# fact about the fight, not about the party — see ConvoySlot._engaged.
	Sig.party_fight_changed.connect(func(_at: int) -> void: refresh_convoy(), CONNECT_DEFERRED)

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

	# Not a container: enemies are placed by hand in `_layout_pack` so wide ships stay apart.
	_slots = Control.new()
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slots.visible = false
	_row.add_child(_slots)
	# Packed whenever the row lays them out: a fight opening, LOCAL's wrecks,
	# a ship's picture changing size.
	_slots.resized.connect(_queue_pack)

	# Background layers are the first children: a child behind the parent is covered by the wash.
	# Why: docs/why/EncounterView.md#depth-order
	backdrop = LocalSky.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# the camera follows your hull in and out (its approach, its departure)
	backdrop.cam_ship = _ship
	add_child(backdrop)
	move_child(backdrop, 0)
	Sig.render_style_changed.connect(func() -> void:
		if _place != null:
			set_weather(_place))

	weather = NebulaWeather.new()
	weather.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weather.visible = false
	add_child(weather)
	move_child(weather, 1)

	# THE NEAREST LAYER: dust in front of the ships, kept off them and off the
	# shots' band (`LocalDust`); under the shots themselves
	dust = LocalDust.new()
	dust.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dust.sky = backdrop
	dust.view = self
	add_child(dust)

	fx = CombatFx.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fx)

	refresh_convoy()


## Asked from the hull data, not typed, so no hull is cropped nose-first.
## Why: docs/why/EncounterView.md#convoy-sizing
static func convoy_w() -> int:
	return DB.widest_hull(true)
## Tall enough for the tallest canvas, so no hull loses its keel to a crop.
## Three rows plus separations is 362 of the 378 rows the arena leaves.
## Why: docs/why/EncounterView.md#convoy-sizing
const CONVOY_H := 118

## Three is what fits, not a tuned party size; overflow is said with a chip, not dropped.
## Why: docs/why/EncounterView.md#convoy-overflow
const CONVOY_MAX := 3
## Clears the sector name and description painted over this corner by the screen above.
const CONVOY_TOP := 62
## Short stagger: the approach runs 4.5 s, so it only has to break the lockstep.
const ARRIVE_LEAD := 0.25
const ARRIVE_GAP := 0.35

## Filtered by position: a partner in another system is in the convoy but not this room.
## Why: docs/why/EncounterView.md#convoy-membership
func _here() -> Array:
	if Run.map.is_empty():
		return []
	var at := Run.at
	return Net.partners().filter(func(s: Dictionary) -> bool:
		return int(s.get("at", -1)) == at)


## Rebuilt only when the party changes; partner views repaint themselves on `Sig.party_changed`.
## Why: docs/why/EncounterView.md#convoy-membership
func refresh_convoy() -> void:
	# `tree_exited` can fire as the whole screen is freed in a sector swap, so check validity.
	if not is_instance_valid(_convoy):
		return
	var here := _here()
	# The count chip takes a place, not extra room: 362 of 378 rows is full.
	# So the last place holds the count instead of a hull, and nobody is dropped.
	# Why: docs/why/EncounterView.md#convoy-overflow
	var shown := CONVOY_MAX if here.size() <= CONVOY_MAX else CONVOY_MAX - 1
	var them: Array = here.slice(0, shown) if here.size() > shown else here
	var want: Array = them.map(func(s: Dictionary) -> int: return int(s.id))

	# A diff, not a rebuild: rebuilding re-arrived every ship and left a leaver no frame.
	# Why: docs/why/EncounterView.md#convoy-arrivals
	for c in _made_convoy.duplicate():
		if want.has(c.peer):
			continue
		_made_convoy.erase(c)
		# Stays a child until the flash ends so the column keeps its height; it frees itself.
		c.jump_out()
		c.tree_exited.connect(refresh_convoy, CONNECT_ONE_SHOT)

	for i in them.size():
		var id := int(them[i].id)
		var slot := _slot_for(id)
		if slot == null:
			slot = ConvoySlot.new(id, CONVOY_H)
			_convoy.add_child(slot)
			_made_convoy.append(slot)
			# Stagger only the opening convoy; a lone later arrival would just feel it as latency.
			# Why: docs/why/EncounterView.md#convoy-arrivals
			var lone := _made_convoy.size() == 1 and _convoy.get_child_count() == 1
			slot.jump_in(0.0 if not lone else ARRIVE_LEAD)
		# Keep the column in the party's order even after somebody has left a
		# hole in the middle of it.
		_convoy.move_child(slot, i)
		slot.bind(them[i])

	_refresh_overflow(here.size() - them.size())

	# Visible while any ship is in the column, even one leaving, so the jump flash has its frame.
	# Your hull drops to 1x while anyone flies with you, to leave room for the column.
	# Why: docs/why/EncounterView.md#convoy-arrivals
	var crowded := not _made_convoy.is_empty()
	_convoy_pad.visible = crowded
	# Your ship stays on the full sheet and partners on the half, so you read as the subject.
	# Why: docs/why/EncounterView.md#own-ship-size
	_ship.use_half(false)


## A count that opens the party page; smaller hulls would be unidentifiable.
func _refresh_overflow(extra: int) -> void:
	if extra <= 0:
		if _overflow != null:
			_overflow.queue_free()
			_overflow = null
		return
	if _overflow == null:
		_overflow = Widgets.button("", func() -> void: Router.show_party())
		# The only clickable thing here: its parents ignore the mouse so cards drop through.
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


## Set for every sector, fighting or not: `show_area()` alone misses arriving into a fight.
## Why: docs/why/EncounterView.md#place-setup
func set_place(n: MapGen.MapNode) -> void:
	_tint = MapGen.star_colour(n).darkened(0.72)
	_place = n
	if backdrop != null:
		backdrop.setup(n)
	set_weather(n)
	queue_redraw()

func set_weather(n: MapGen.MapNode) -> void:
	if weather == null:
		return
	weather.visible = n.in_nebula and LocalSky.style_now() == &"legacy"
	if n.in_nebula:
		weather.setup(n.nebula_emission,
			Color("#8a5f7a") if n.nebula_emission else Color("#4a7a8a"))

## Reuses `EnemySlot` whole, so a wreck is drawn by the same code as a living hull.
## Why: docs/why/EncounterView.md#wreck-slots
func show_wrecks(wrecks: Array, on_open: Callable) -> void:
	if wrecks.is_empty():
		return
	_area.visible = false
	_slots.visible = true
	_ship.modulate = Color.WHITE
	if _made.size() != wrecks.size() or _slots_mode != &"wrecks":
		_slots_mode = &"wrecks"
		Widgets.clear(_slots)
		_made.clear()
		for i in wrecks.size():
			var slot := EnemySlot.new()
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
			slot.claim = _claim_hot
			# a wreck says no intent: its readout keeps no room for one
			slot.reserve_intent = false
			_slots.add_child(slot)
			_made.append(slot)
	for i in wrecks.size():
		var h: MapGen.Jetsam = wrecks[i]
		var t: EnemyTemplate = DB.enemies.get(h.art)
		if t == null:
			continue
		# Fabricated state: the fight is over and `Combat` is gone, a zero-hull template suffices.
		var ghost := Combat.EnemyState.new()
		ghost.template = t
		ghost.max_hp = t.max_hull
		ghost.hp = 0
		ghost.look = h.look
		_made[i].opened = on_open.bind(h)
		# The style it died in, from where it lies -- the same roll the kill made,
		# by its number among the system's wrecks (this place shows only some)
		var k := Run.wreck_ordinal(Run.node_at(), h)
		_made[i].death_style = EnemyArt.death_style(t, Run.node_at().index, k)
		# and where it lies, so the marks its fight left are on it
		_made[i].wreck_id = Run.node_at().index * 64 + k
		_made[i].bind(i, ghost, false)
		# What is still in it, on the label. `ship_changed` re-runs the screen's
		# refresh on every take, so the number follows the hand emptying it.
		_made[i].set_salvage(Run.jetsam_left(Run.node_at(), h))
	_queue_pack()
	queue_redraw()


func show_area(n: MapGen.MapNode) -> void:
	# (at the place in the system the ship is: the picture is its events')
	_area.site = Run.site_here(n) if n != null and n == Run.node_at() else AreaView.ANY
	_area.setup(n)
	# (not while an event's subject stands in its place: `LocalSubject`)
	_area.visible = LocalSubject.of(self) == null
	_slots.visible = false
	_ship.modulate = Color(0.55, 0.55, 0.6) if Run.dead else Color.WHITE
	queue_redraw()

## Hit-tested by rectangle, not input picking, so cards drop through the party column.
## Why: docs/why/EncounterView.md#aiming
const AIM_NONE := -2

func target_at(p: Vector2) -> int:
	for i in _made.size():
		var s := _made[i] as EnemySlot
		if s != null and s.visible and s.get_global_rect().has_point(p):
			return i
	if _ship_slot != null and _ship_slot.visible \
			and _ship_slot.get_global_rect().has_point(p):
		return -1
	return AIM_NONE


## Light exactly one target, or none. Returns whether `c` may actually be played
## there -- an illegal target lights nothing and the caller refuses the release.
func aim_at(index: int, c: CardData, prev: Callable) -> bool:
	var ok := false
	for i in _made.size():
		var s := _made[i] as EnemySlot
		if s == null:
			continue
		var hit: bool = i == index and s.aimable(c)
		s.aim(hit, "" if not (hit and prev.is_valid()) else String(prev.call(c, i)))
		ok = ok or hit
	if _ship_slot != null:
		var hit_s: bool = index == -1 and _ship_slot.aimable(c)
		_ship_slot.aim(hit_s,
			"" if not (hit_s and prev.is_valid()) else String(prev.call(c, -1)))
		ok = ok or hit_s
	return ok


## Put every slot back to cold. Called on release and on cancel; cheap enough to
## call unconditionally rather than tracking which one was lit.
func clear_aim() -> void:
	for i in _made.size():
		var s := _made[i] as EnemySlot
		if s != null:
			s.aim(false)
	if _ship_slot != null:
		_ship_slot.aim(false)


func show_enemies(list: Array, on_drop: Callable, on_hover: Callable,
		on_wreck: Callable = Callable()) -> void:
	if not hold_row:
		open_row()
	_ship.modulate = Color.WHITE

	var arrived: Array[EnemySlot] = []
	# Built once a fight: nothing joins one (`Combat`), and the dead keep their
	# slots, so the count only changes when a new fight opens.
	if _made.size() != list.size() or _slots_mode != &"fight":
		# a fight opening over wrecks on this same screen hands them to itself
		var going := hand_wrecks()
		_slots_mode = &"fight"
		Widgets.clear(_slots)
		_made.clear()
		wrecks_out(going)
	if _made.size() < list.size():
		for i in range(_made.size(), list.size()):
			var slot := EnemySlot.new()
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
			slot.claim = _claim_hot
			slot.preview = preview
			# A WRECK IS A CONTAINER. The screen decides what opening one means;
			# the slot only knows it was clicked and that it is dead.
			slot.opened = on_wreck
			# a pack of three or more is drawn from half sheets, a size the layout
			# sets after the bind: its hit layers are built once, at that size
			slot.layers_wait = list.size() >= PACK_HALF_AT
			slot.card_dropped.connect(on_drop)
			slot.hovered.connect(on_hover)
			_slots.add_child(slot)
			_made.append(slot)
			arrived.append(slot)

	for i in list.size():
		var e = list[i]
		if death_style.is_valid():
			_made[i].death_style = int(death_style.call(i))
		if wreck_id.is_valid():
			_made[i].wreck_id = int(wreck_id.call(i))
		_made[i].bind(i, e, e.intent != null and e.intent.telegraph)
	# Fly new slots in after the bind, which sizes them; the dead keep slots so kills never re-fly.
	# Why: docs/why/EncounterView.md#slot-arrivals
	_layout_pack()
	for k in arrived.size():
		if _entrances_held:
			arrived[k].hold_entrance()
		else:
			arrived[k].enter(float(k) * 0.09)
	_queue_pack()
	queue_redraw()


## Keeps LOCAL's row as it was while a fight's first frame draws (`SectorScreen._raise_band`).
var hold_row := false


## The row as a fight has it: the place out (fading, `_area_fade_out`), the
## contacts' slots in.
func open_row() -> void:
	hold_row = false
	if _slots.visible:
		return
	if _area.visible:
		_area_fade_out()
	_area.visible = false
	_slots.visible = true


## Whether something LOCAL showed is fading out of the scene: the place's
## picture (`_area_fade_out`) or an event's subject (`LocalSubject.fade_out`).
func leaving() -> bool:
	for c in get_children():
		if (c is LocalSubject and (c as Node).has_meta(&"leaving")) \
				or c.name == "AreaLeaving" or c.name == "WrecksLeaving":
			return not (c as Node).is_queued_for_deletion()
	return false


## Wrecks leave before the fight comes, never on one frame: they are handed across the swap.
## Else every wreck was gone on the frame a fight opened.
## Why: docs/why/EncounterView.md#wreck-handoff
const WRECK_EXITS := {&"A": &"fade", &"B": &"drift", &"C": &"recede"}
static var WRECK_EXIT: StringName = &"fade"
const WRECK_DRIFT_S := 0.45
const WRECK_RECEDE_S := 0.5

## Only slots already laid out and drawn are handed over; headless and reduced motion skip it.
func hand_wrecks() -> Array:
	var out: Array = []
	if _slots_mode != &"wrecks" or _made.is_empty() or not Router.animating() \
			or not is_visible_in_tree():
		return out
	for sl in _made:
		var e := sl as EnemySlot
		if e == null or not is_instance_valid(e) or not _placed.has(e) or e.size == Vector2.ZERO:
			continue
		out.append([e, e.get_global_rect()])
		_slots.remove_child(e)
	_made.clear()
	return out


## And played out over this view, each at the place on screen it had.
func wrecks_out(going: Array) -> void:
	if going.is_empty():
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("wreckexit="):
			WRECK_EXIT = WRECK_EXITS.get(StringName(a.get_slice("=", 1).to_upper()), WRECK_EXIT)
	var holder := Control.new()
	holder.name = "WrecksLeaving"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.top_level = true
	add_child(holder)
	move_child(holder, _row.get_index())
	var right := get_viewport_rect().end.x
	var tw := holder.create_tween().set_parallel(true)
	for pair in going:
		var slot: EnemySlot = pair[0]
		var r: Rect2 = pair[1]
		holder.add_child(slot)
		slot.position = r.position
		slot.size = r.size
		slot.opened = Callable()
		_ignore_mouse(slot)
		match WRECK_EXIT:
			&"drift":
				# whole pixels, so the art never shimmers on its way off
				var x0: float = r.position.x
				var run: float = right - x0 + 8.0
				tw.tween_method(func(d: float) -> void:
					if is_instance_valid(slot):
						slot.position.x = x0 + roundf(d),
					0.0, run, WRECK_DRIFT_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.tween_property(slot, "modulate:a", 0.0, WRECK_DRIFT_S * 0.4) \
					.set_delay(WRECK_DRIFT_S * 0.6)
			&"recede":
				slot.pivot_offset = r.size * 0.5
				tw.tween_property(slot, "scale", Vector2(0.55, 0.55), WRECK_RECEDE_S) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				tw.tween_property(slot, "modulate", Color(0.35, 0.38, 0.45, 0.0), WRECK_RECEDE_S) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			_:
				tw.tween_property(slot, "modulate:a", 0.0, LocalSubject.FADE_OUT_S)
	# freed once the slowest of them is gone, which is what `leaving` waits on
	tw.chain().tween_callback(holder.queue_free)


static func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


## The contacts wait off screen until `release_entrances` (an ambush waiting
## for your ship to arrive: `SectorScreen._hold_for_arrival`).
var _entrances_held := false

func hold_entrances() -> void:
	_entrances_held = true
	for sl in _made:
		(sl as EnemySlot).hold_entrance()


## Entrances wait for the wrecks to go, so a contact is not flown in over an exiting wreck.
func release_entrances_when_clear() -> void:
	var w := get_node_or_null(^"WrecksLeaving")
	if w != null and not w.is_queued_for_deletion():
		w.tree_exited.connect(release_entrances, CONNECT_ONE_SHOT)
		return
	release_entrances()


## And in, staggered as a fight opening flies them.
func release_entrances() -> void:
	if not _entrances_held:
		return
	_entrances_held = false
	for k in _made.size():
		(_made[k] as EnemySlot).enter(float(k) * 0.09)


## A copy of the place picture fades where it stood, since the row's own must leave at once.
## Why: docs/why/EncounterView.md#place-fade
func _area_fade_out() -> void:
	if not Router.animating() or not is_visible_in_tree() or _area.node == null \
			or _area._place_name() == &"":
		return
	var fixed := 0.0
	var seen := 0
	for c in _row.get_children():
		if not (c is Control) or not (c as Control).visible:
			continue
		seen += 1
		if not ((c as Control).size_flags_horizontal & Control.SIZE_EXPAND):
			fixed += (c as Control).get_combined_minimum_size().x
	var ghost := AreaView.new()
	ghost.name = "AreaLeaving"
	ghost.anchor_left = 0.5
	ghost.anchor_right = 1.0
	ghost.anchor_top = 0.0
	ghost.anchor_bottom = 1.0
	ghost.offset_left = (fixed + float(_row.get_theme_constant("separation")) * maxf(0.0, seen - 1)) * 0.5
	ghost.offset_right = 0.0
	ghost.offset_top = 0.0
	ghost.offset_bottom = _row.offset_bottom
	ghost._clock = _area._clock
	ghost.site = _area.site
	add_child(ghost)
	move_child(ghost, _row.get_index())
	ghost.setup(_area.node)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, LocalSubject.FADE_OUT_S)
	tw.tween_callback(ghost.queue_free)


## Nothing in a pack overlaps anything else (Jon, Oct 13): slots are placed by hand as units.
## Why: docs/why/EncounterView.md#pack-layout
static var pack_layout: StringName = &"B"
const PACK_GAP := 10.0
const PACK_VGAP := 6.0
const PACK_MARGIN := 12.0
const PACK_EASE := 0.4
## From this many blocks in the pack, every ship is drawn from its half sheet.
const PACK_HALF_AT := 3

var _pack_queued := false
## Where each slot was last put, so a move eases rather than jumps.
var _placed: Dictionary = {}
## Which rank of the formation each slot stands in (0 the front), for the test.
var _pack_rank_of: Dictionary = {}
## How much higher the hand's band is still to come, as laid out now (a
## fight opening: `SectorScreen._band_still_to_come`; 0 once it has settled).
var band_left := Callable()
var _lift_was := 0.0
## The last plan and what it was made from (`_layout_pack`).
var _plan_key := ""
var _plan_memo: Dictionary = {}
var _pack_tw: Dictionary = {}

func _queue_pack() -> void:
	if _pack_queued:
		return
	_pack_queued = true
	_layout_pack.call_deferred()


## Your ship's boxes, in global coordinates: the hull's own rect and every
## readout on its plate (name, bar, number, chips).
func player_boxes() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _ship == null:
		return out
	# through the hull's whole transform, so a scene the cutaway or the ladder
	# has scaled gives the hull's real box (its offset and size scaled too)
	out.append(_ship.get_global_transform() * _ship.ship_rect())
	_collect_boxes(_ship, out)
	return out

func _collect_boxes(n: Node, out: Array[Rect2]) -> void:
	for c in n.get_children():
		if not (c is Control) or not (c as Control).is_visible_in_tree():
			continue
		if c is Label:
			if (c as Label).text.strip_edges() != "":
				out.append(EnemySlot.text_rect(c as Label))
		elif c is ProgressBar or c is EnemySlot.BracePips:
			out.append((c as Control).get_global_rect())
		elif c is HBoxContainer and (c as Control).get_parent() is VBoxContainer:
			for k in c.get_children():
				if k is Control and (k as Control).visible:
					out.append((k as Control).get_global_rect())
		_collect_boxes(c, out)


## Pack room is measured at rest, or a cutaway zoom plans wrecks across your bow (Jon, Oct 17).
## Why: docs/why/EncounterView.md#pack-layout
func _pack_area() -> Rect2:
	var to_row := _row.get_global_transform().affine_inverse()
	var right := 0.0
	for r in player_boxes():
		right = maxf(right, (to_row * r).end.x)
	var left := maxf(right + PACK_MARGIN, PACK_MARGIN)
	var x0 := left - _slots.position.x
	return Rect2(x0, 0.0, size.x - PACK_MARGIN - left, size.y - _bleed - _slots.position.y)


func _layout_pack() -> void:
	_pack_queued = false
	if _slots == null or not _slots.visible:
		return
	var live: Array[EnemySlot] = []
	for c in _slots.get_children():
		if c is EnemySlot and (c as EnemySlot).visible and not (c as EnemySlot).is_queued_for_deletion():
			live.append(c)
	if live.is_empty():
		return
	# Fight order, not child order: back ranks are moved first among children to draw underneath.
	live.sort_custom(func(a: EnemySlot, b: EnemySlot) -> bool: return a.index < b.index)
	var area := _pack_area()
	# While the band rises, plan for its settled size and carry the pack up so nothing jumps.
	var lift := 0.0
	var to_come := float(band_left.call()) if band_left.is_valid() else 0.0
	if to_come > 0.0:
		area.size.y = maxf(0.0, area.size.y - to_come)
		lift = floorf(to_come * 0.5)
	var mid := _slots.size.x * 0.5
	# THE WORLD YOU ORBIT, where LOCAL's wrecks lie (`_body_rest`)
	var body := _body_rest() if _slots_mode == &"wrecks" else Vector3.ZERO
	# Cache the plan by its inputs: a fight asks for layout dozens of times a turn.
	var key := "%s|%s|%s|%s|%s" % [pack_layout, _slots_mode, area, mid, body]
	for sl in live:
		var e: Combat.EnemyState = sl.get("_last_e")
		key += "|%d:%s:%d:%s:%s:%d" % [sl.get_instance_id(), e.template.id if e != null else &"",
			e.look if e != null else -1, sl.reserve_intent, sl.get("_dead"),
			sl.chips.get_child_count() if sl.chips != null else 0]
	var plan := {}
	var same_plan := key == _plan_key and not _plan_memo.is_empty()
	if same_plan:
		plan = _plan_memo
	else:
		plan = _plan_in(live, area, mid)
		if plan.is_empty():
			# more than the band can hold even in ranks: the row, overflowing
			plan = _pack_row(live, 0.5 if live.size() >= PACK_HALF_AT else 1.0, area, mid, true)
		if body.z > 0.0:
			plan = _clear_of_body(live, plan, area, mid, body)
		_plan_key = key
		_plan_memo = plan
	var back: Array = plan.get("back", [])
	_pack_rank_of = plan.get("ranks", {})
	var placed := {}
	for sl in live:
		var u: Dictionary = plan[sl]
		# the size steps at once, at the start of the move
		sl.apply_scale(float(u.scale))
		# and hit layers that waited for it are built at it (`EnemySlot.layers_wait`)
		sl.layers_sized()
		sl.set_side(bool(u.side))
		sl.reserve_readout(u.rect.size)
		var r: Rect2 = u.rect
		sl.size = r.size
		var at := (r.position + Vector2(0.0, lift)).round()
		var was: Variant = _placed.get(sl)
		if _pack_tw.has(sl) and (_pack_tw[sl] as Tween).is_valid():
			if was == at:
				placed[sl] = at
				continue
			(_pack_tw[sl] as Tween).kill()
		# Eased where things move, but carried with a rising band, which already moves each frame.
		if was != null and was != at and is_inside_tree() and Router.animating() \
				and not (same_plan and _lift_was != lift):
			var tw := sl.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(sl, "position", at, PACK_EASE)
			_pack_tw[sl] = tw
		else:
			sl.position = at
		placed[sl] = at
	_placed = placed
	_lift_was = lift
	for k in _pack_tw.keys():
		if not placed.has(k):
			_pack_tw.erase(k)
	# the ranks behind are drawn first, farthest first, under the ones in front
	for k in back.size():
		_slots.move_child(back[k], k)


## The plan for a pack in `area`: the layout's own way, at full size or from
## half sheets as the pack asks. Empty if it does not fit there.
func _plan_in(live: Array[EnemySlot], area: Rect2, mid: float) -> Dictionary:
	var s := 0.5 if live.size() >= PACK_HALF_AT else 1.0
	var plan := {}
	if pack_layout == &"C":
		if s == 1.0:
			plan = _pack_row(live, s, area, mid)
		if plan.is_empty():
			plan = _pack_column(live, s, area, mid)
	if plan.is_empty():
		plan = _pack_ranks(live, s, area, mid)
		# A pair too big for the band at full size is drawn from half sheets, like a pack of three.
		if s == 1.0 and (plan.is_empty() or float(plan.get("low", INF)) < PACK_GAP_MIN):
			var half := _pack_ranks(live, 0.5, area, mid)
			if not half.is_empty():
				plan = half
	return plan


## Read from the sky's plan, not its picture: the plan exists headless and at rest.
## Why: docs/why/EncounterView.md#world-clearance
func _body_rest() -> Vector3:
	if backdrop == null or _slots == null:
		return Vector3.ZERO
	var p := backdrop.near_plan()
	if p.is_empty():
		return Vector3.ZERO
	var c: Vector2 = Vector2(p.at) - get_global_rect().position - _slots.position
	return Vector3(c.x, c.y, float(p.R))


## Jon's rule: fit means nothing overlaps, so wrecks keep off the orbited world's disc.
## Why: docs/why/EncounterView.md#world-clearance
const BODY_GAP := 8.0

func _clear_of_body(live: Array[EnemySlot], plan: Dictionary, area: Rect2, mid: float, body: Vector3) -> Dictionary:
	if _plan_clear(live, plan, body, false):
		return plan
	var c := Vector2(body.x, body.y)
	var r := body.z + BODY_GAP
	# Try the strip just over the world first, mid view where the hulls are, not the bright sky.
	var hp := _plan_box(live, plan).size.y
	var over := minf(hp, (c.y - r) - area.position.y)
	var rooms: Array[Rect2] = [
		Rect2(area.position.x, (c.y - r) - over, area.size.x, over),
		Rect2(area.position.x, area.position.y, area.size.x, (c.y - r) - area.position.y),
		Rect2(area.position.x, area.position.y, (c.x - r) - area.position.x, area.size.y),
		Rect2(c.x + r, area.position.y, area.end.x - (c.x + r), area.size.y),
		Rect2(area.position.x, c.y + r, area.size.x, area.end.y - (c.y + r)),
	]
	# (and, when a big world leaves a big pile nowhere else, the whole width
	# over it, your ship's side too, above your hull and its plate)
	var to_row := _row.get_global_transform().affine_inverse()
	var top := INF
	for b in player_boxes():
		top = minf(top, (to_row * b).position.y - _slots.position.y)
	var x0 := PACK_MARGIN - _slots.position.x
	var low := minf(c.y - r, top - PACK_MARGIN)
	rooms.append(Rect2(x0, area.position.y, area.end.x - x0, low - area.position.y))
	var was := _plan_mid(live, plan)
	for words_only in [false, true]:
		var best := {}
		var best_k := INF
		var tries: Array = rooms.duplicate()
		if words_only:
			tries.push_front(area)
		for room: Rect2 in tries:
			if room.size.x <= 0.0 or room.size.y <= 0.0:
				continue
			var p := plan if room == area else _plan_in(live, room, mid)
			if p.is_empty() or not _plan_clear(live, p, body, words_only):
				continue
			# the larger size first, then the least move
			var k := (0.0 if _plan_scale(live, p) >= 1.0 else 1e6) + _plan_mid(live, p).distance_to(was)
			if k < best_k:
				best = p
				best_k = k
		if not best.is_empty():
			return best
	return plan


## Whether every wreck in `plan` keeps BODY_GAP off the world's disc: its whole
## block, or (`words_only`) the words under it.
func _plan_clear(live: Array[EnemySlot], plan: Dictionary, body: Vector3, words_only: bool) -> bool:
	var c := Vector2(body.x, body.y)
	for sl in live:
		if not plan.has(sl):
			return false
		var u: Dictionary = plan[sl]
		var s := float(u.scale)
		var b: Rect2 = sl.words(s) if words_only else sl.block(s)
		var at := Rect2((u.rect as Rect2).position + b.position, b.size)
		var near := Vector2(clampf(c.x, at.position.x, at.end.x), clampf(c.y, at.position.y, at.end.y))
		if near.distance_to(c) < body.z + BODY_GAP:
			return false
	return true


func _plan_mid(live: Array[EnemySlot], plan: Dictionary) -> Vector2:
	return _plan_box(live, plan).get_center()


func _plan_box(live: Array[EnemySlot], plan: Dictionary) -> Rect2:
	var box := Rect2()
	var first := true
	for sl in live:
		if not plan.has(sl):
			continue
		var r: Rect2 = plan[sl].rect
		box = r if first else box.merge(r)
		first = false
	return box


func _plan_scale(live: Array[EnemySlot], plan: Dictionary) -> float:
	var s := 1.0
	for sl in live:
		if plan.has(sl):
			s = minf(s, float(plan[sl].scale))
	return s


## One row, every ship at `s`. Empty if it does not fit (unless `force`).
func _pack_row(live: Array[EnemySlot], s: float, area: Rect2, mid: float, force: bool = false) -> Dictionary:
	var units: Array[Vector2] = []
	var total := 0.0
	var tall := 0.0
	for sl in live:
		var u := sl.unit(s, false)
		units.append(u)
		total += u.x
		tall = maxf(tall, u.y)
	total += PACK_GAP * float(live.size() - 1)
	if not force and (total > area.size.x or tall > area.size.y):
		return {}
	var x := _place_span(total, area, mid)
	var out := {}
	for i in live.size():
		var u := units[i]
		out[live[i]] = {scale = s, side = false,
			rect = Rect2(x, _low_enough(area.position.y + (area.size.y - u.y) * 0.5, u.y, area), u.x, u.y)}
		x += u.x + PACK_GAP
	return out


## One even gap between all neighbouring blocks (Jon), between PACK_GAP_MIN and PACK_GAP_MAX.
## Why: docs/why/EncounterView.md#pack-formation
const PACK_GAP_MIN := 12.0
const PACK_GAP_MAX := 48.0
const PACK_GAP_WRECKS := 12.0

func _pack_ranks(live: Array[EnemySlot], s: float, area: Rect2, mid: float) -> Dictionary:
	var units := {}
	var blocks := {}
	for sl in live:
		units[sl] = sl.unit(s, false)
		blocks[sl] = sl.block(s)
	var n := live.size()
	var pers: Array = [n, 1] if n <= 2 else range(2, n + 1)
	var best := {}
	var best_g := -INF
	for per in pers:
		var ranks: Array = []
		for i in n:
			if i % int(per) == 0:
				ranks.append([])
			(ranks[ranks.size() - 1] as Array).append(live[i])
		# Wreck piles space at the least gap so the system's subject keeps room.
		# At 24 px between blocks the fuel cache's pieces had nowhere left beside three wrecks.
		# Why: docs/why/EncounterView.md#wreck-spacing
		var g := PACK_GAP_WRECKS if _slots_mode == &"wrecks" else PACK_GAP_MAX
		var multi := false
		var heights: Array[float] = []
		var total_h := 0.0
		var fits := true
		for rank: Array in ranks:
			var w := 0.0
			var h := 0.0
			for sl: EnemySlot in rank:
				w += (blocks[sl] as Rect2).size.x
				h = maxf(h, (blocks[sl] as Rect2).size.y)
			if w > area.size.x:
				fits = false
			if rank.size() > 1:
				g = minf(g, (area.size.x - w) / float(rank.size() - 1))
				multi = true
			heights.append(h)
			total_h += h
		# The triangle sets the rear ship into the front pair's shoulders so shield rooms fit.
		# Why: docs/why/EncounterView.md#pack-formation
		if fits and _slots_mode != &"wrecks" and ranks.size() == 2 \
				and (ranks[1] as Array).size() == (ranks[0] as Array).size() - 1:
			var sh := _pack_shoulders(ranks, blocks, units, g, s, area, mid)
			if not sh.is_empty():
				return sh
		if not fits or total_h > area.size.y:
			continue
		# Across a rank one gap as wide as the band allows; between ranks the same or less (Jon).
		var gv := g
		if ranks.size() > 1:
			gv = minf(g, (area.size.y - total_h) / float(ranks.size() - 1))
		g = floorf(g)
		gv = floorf(gv)
		var plan := _place_ranks(ranks, heights, blocks, units, g, s, area, mid, gv)
		if plan.is_empty():
			continue
		var low := minf(g if multi else INF, gv if ranks.size() > 1 else INF)
		plan["low"] = low
		if low >= PACK_GAP_MIN:
			return plan
		if low > best_g:
			best = plan
			best_g = low
	return best


func _place_ranks(ranks: Array, heights: Array[float], blocks: Dictionary, units: Dictionary,
		g: float, s: float, area: Rect2, mid: float, gv: float = -1.0) -> Dictionary:
	if gv < 0.0:
		gv = g
	var total_h := gv * float(ranks.size() - 1)
	for h in heights:
		total_h += h
	var bottom := _low_enough(area.position.y + floorf((area.size.y - total_h) * 0.5), total_h, area) + total_h
	var placed: Array = []   # per rank: Array of Rect2, the blocks as drawn
	for k in ranks.size():
		var rank: Array = ranks[k]
		var rects: Array = []
		var wsum := g * float(rank.size() - 1)
		for sl: EnemySlot in rank:
			wsum += (blocks[sl] as Rect2).size.x
		var xs: Array[float] = []
		var staggered := false
		if k > 0 and rank.size() == (ranks[k - 1] as Array).size() - 1:
			# over the gaps of the rank in front
			var prev: Array = placed[k - 1]
			staggered = true
			for j in rank.size():
				var w: float = (blocks[rank[j]] as Rect2).size.x
				xs.append(roundf(((prev[j] as Rect2).end.x + (prev[j + 1] as Rect2).position.x) * 0.5 - w * 0.5))
			for j in range(1, xs.size()):
				if xs[j] < xs[j - 1] + (blocks[rank[j - 1]] as Rect2).size.x + g:
					staggered = false
		if not staggered:
			xs.clear()
			var centre := mid
			if k > 0:
				var prev2: Array = placed[k - 1]
				centre = ((prev2[0] as Rect2).position.x + (prev2[prev2.size() - 1] as Rect2).end.x) * 0.5
			var x := roundf(centre - wsum * 0.5) if k > 0 else _place_span(wsum, area, mid)
			for sl: EnemySlot in rank:
				xs.append(x)
				x += (blocks[sl] as Rect2).size.x + g
		# the whole rank inside the band
		var x0: float = xs[0]
		var x1: float = xs[xs.size() - 1] + (blocks[rank[rank.size() - 1]] as Rect2).size.x
		var shift := 0.0
		if x1 > area.end.x:
			shift = area.end.x - x1
		if x0 + shift < area.position.x:
			shift = area.position.x - x0
		for j in rank.size():
			var b: Rect2 = blocks[rank[j]]
			# a rank stands on its baseline
			rects.append(Rect2(xs[j] + shift, bottom - b.size.y, b.size.x, b.size.y))
		placed.append(rects)
		bottom -= heights[k] + gv
	var out := {}
	var back: Array = []
	for k in ranks.size():
		var rank: Array = ranks[k]
		for j in rank.size():
			var sl: EnemySlot = rank[j]
			var r: Rect2 = placed[k][j]
			var b: Rect2 = blocks[sl]
			out[sl] = {scale = s, side = false, rect = Rect2(r.position - b.position, units[sl])}
	for k in range(ranks.size() - 1, 0, -1):
		back.append_array(ranks[k])
	out["back"] = back
	var rank_of := {}
	for k in ranks.size():
		for sl in ranks[k]:
			rank_of[sl] = k
	out["ranks"] = rank_of
	return out


## The rear rank sits over the front gaps, nudged to equalise its gaps, as low as rooms allow.
## Why: docs/why/EncounterView.md#pack-formation
const SHOULDER_DX := 40
const SHOULDER_EVEN := 0.75

func _pack_shoulders(ranks: Array, blocks: Dictionary, units: Dictionary, g0: float,
		s: float, area: Rect2, mid: float) -> Dictionary:
	_tops_cache.clear()
	var rooms := {}
	for rank: Array in ranks:
		for sl: EnemySlot in rank:
			sl.apply_scale(s)
			var r := sl.rooms(s)
			if r.is_empty():
				return {}
			rooms[sl] = r
	var front: Array = ranks[0]
	var wsum := 0.0
	for sl: EnemySlot in front:
		wsum += (blocks[sl] as Rect2).size.x
	var gmax := floorf((area.size.x - wsum) / float(maxi(1, front.size() - 1)))
	var g := floorf(minf(g0, gmax))
	# Step out from the usual gap: wider drops the rear ship lower, too wide and it is not behind.
	var plan := _shoulders_at(ranks, rooms, blocks, units, g, PACK_GAP_MIN, s, area, mid)
	if plan.is_empty():
		var lo_g := g
		var hi_g := -1.0
		var step := g + 8.0
		while step <= gmax + 7.0:
			var gs := minf(step, gmax)
			var ps := _shoulders_at(ranks, rooms, blocks, units, gs, PACK_GAP_MIN, s, area, mid)
			if not ps.is_empty():
				hi_g = gs
				plan = ps
				break
			lo_g = gs
			if gs >= gmax:
				break
			step += 8.0
		if hi_g < 0.0:
			return {}
		g = hi_g
		while hi_g - lo_g > 1.0:
			var m := floorf((lo_g + hi_g) * 0.5)
			var pm := _shoulders_at(ranks, rooms, blocks, units, m, PACK_GAP_MIN, s, area, mid)
			if pm.is_empty():
				lo_g = m
			else:
				hi_g = m
				plan = pm
				g = m
	# the gap between ranks as wide as still fits, up to the gap across
	var lo := PACK_GAP_MIN
	# (no wider than the band's spare height allows: a wider gap lifts the
	# ship behind by at least as much)
	var hi := minf(g, PACK_GAP_MIN + area.size.y - float(plan.get("h", 0.0))) + 1.0
	while hi - lo > 1.0:
		var m2 := floorf((lo + hi) * 0.5)
		var p2 := _shoulders_at(ranks, rooms, blocks, units, g, m2, s, area, mid)
		if p2.is_empty():
			hi = m2
		else:
			lo = m2
			plan = p2
	return plan


func _shoulders_at(ranks: Array, rooms: Dictionary, blocks: Dictionary, units: Dictionary,
		g: float, gv: float, s: float, area: Rect2, mid: float) -> Dictionary:
	var front: Array = ranks[0]
	var back: Array = ranks[1]
	var wsum := g * float(front.size() - 1)
	for sl: EnemySlot in front:
		wsum += (blocks[sl] as Rect2).size.x
	var x := _place_span(wsum, area, mid)
	var fr: Array = []
	var hmax := 0.0
	for sl: EnemySlot in front:
		var b: Rect2 = blocks[sl]
		fr.append(Rect2(x, -b.size.y, b.size.x, b.size.y))
		x += b.size.x + g
		hmax = maxf(hmax, b.size.y)
	var br: Array = []
	var top := -hmax
	for j in back.size():
		var sl: EnemySlot = back[j]
		var b: Rect2 = blocks[sl]
		var left: Rect2 = fr[j]
		var right: Rect2 = fr[j + 1]
		var centre := roundf((left.end.x + right.position.x) * 0.5 - b.size.x * 0.5)
		var x_lo := int(floorf(centre)) - SHOULDER_DX - int(gv) - 2
		var x_hi := int(ceilf(centre + b.size.x)) + SHOULDER_DX + int(gv) + 2
		# (a pixel's slack over the gap: the profile is taken down column middles)
		var t1 := _tops_at(front[j], rooms, units, left.position - (blocks[front[j]] as Rect2).position, x_lo, x_hi, gv + 0.75)
		var t2 := _tops_at(front[j + 1], rooms, units, right.position - (blocks[front[j + 1]] as Rect2).position, x_lo, x_hi, gv + 0.75)
		var bp := _room_bottoms(rooms[sl], b)
		var oval_top := minf(_oval_of(rooms[front[j]]).position.y + left.position.y - (blocks[front[j]] as Rect2).position.y,
			_oval_of(rooms[front[j + 1]]).position.y + right.position.y - (blocks[front[j + 1]] as Rect2).position.y)
		var back_oval_bottom := _oval_of(rooms[sl]).end.y - b.position.y
		# Find where the two gaps cross, by a coarse pass then halving, and keep the lowest.
		var d_lo := maxi(-SHOULDER_DX, int(ceilf(area.position.x - centre)))
		var d_hi := mini(SHOULDER_DX, int(floorf(area.end.x - b.size.x - centre)))
		if d_lo > d_hi:
			return {}
		var base := int(centre) - x_lo
		var fb := Vector3(-INF, -INF, INF)
		var best_dx := 0
		var prev_d := d_lo
		var prev_f := _shoulder_lean(bp, t1, t2, base + d_lo)
		var d := d_lo
		while d <= d_hi:
			var f := _shoulder_lean(bp, t1, t2, base + d)
			var hit := absf(f.z) <= SHOULDER_EVEN
			var a_d := prev_d
			var a_f := prev_f
			var c_d := d
			var c_f := f
			if not hit and d > d_lo and ((a_f.z < 0.0) != (c_f.z < 0.0)):
				while c_d - a_d > 1:
					var dm := (a_d + c_d) / 2
					var fm := _shoulder_lean(bp, t1, t2, base + dm)
					if (fm.z < 0.0) == (a_f.z < 0.0):
						a_d = dm
						a_f = fm
					else:
						c_d = dm
						c_f = fm
				if absf(a_f.z) <= absf(c_f.z):
					c_d = a_d
					c_f = a_f
				hit = absf(c_f.z) <= SHOULDER_EVEN
			if hit and minf(c_f.x, c_f.y) > minf(fb.x, fb.y) + 0.5:
				fb = c_f
				best_dx = c_d
			prev_d = d
			prev_f = f
			if d == d_hi:
				break
			d = mini(d + 4, d_hi)
		if fb.z == INF:
			return {}
		var best_y := floorf(minf(fb.x, fb.y))
		var best_x := centre + float(best_dx)
		# behind and above: its shield clear above theirs
		if best_y + back_oval_bottom > oval_top:
			return {}
		br.append(Rect2(best_x, best_y, b.size.x, b.size.y))
		top = minf(top, best_y)
	var h := -top
	if h > area.size.y:
		return {}
	var y0 := _low_enough(area.position.y + floorf((area.size.y - h) * 0.5), h, area)
	var base := y0 + h
	var out := {}
	var placed: Array = [fr, br]
	var rank_of := {}
	for k in 2:
		var rank: Array = ranks[k]
		for j in rank.size():
			var sl: EnemySlot = rank[j]
			var r: Rect2 = placed[k][j]
			var b: Rect2 = blocks[sl]
			out[sl] = {scale = s, side = false,
				rect = Rect2(Vector2(r.position.x, r.position.y + base) - b.position, units[sl])}
			rank_of[sl] = k
	out["back"] = back.duplicate()
	out["ranks"] = rank_of
	out["low"] = minf(g, gv)
	out["h"] = h
	return out


## Where the rear ship may come down to; far from either neighbour its side is very large.
static func _shoulder_lean(bp: PackedFloat32Array, t1: PackedFloat32Array, t2: PackedFloat32Array, at0: int) -> Vector3:
	var y1 := INF
	var y2 := INF
	for c in bp.size():
		if bp[c] == -INF:
			continue
		var col := at0 + c
		if col < 0 or col >= t1.size():
			continue
		y1 = minf(y1, t1[col] - bp[c])
		y2 = minf(y2, t2[col] - bp[c])
	var a := minf(y1, 1.0e6)
	var b := minf(y2, 1.0e6)
	return Vector3(a, b, a - b)


## Cached per ship and gap in the ship's own columns; the pull-up is the costly part.
var _tops_cache: Dictionary = {}

func _tops_at(sl: EnemySlot, rooms: Dictionary, units: Dictionary, at: Vector2,
		x_lo: int, x_hi: int, gv: float) -> PackedFloat32Array:
	var k := int(ceilf(gv)) + 1
	var key := "%d|%.2f" % [sl.get_instance_id(), gv]
	if not _tops_cache.has(key):
		_tops_cache[key] = _room_tops(rooms[sl], Vector2.ZERO, -k, int(ceilf((units[sl] as Vector2).x)) + k, gv)
	var loc: PackedFloat32Array = _tops_cache[key]
	var ax := int(roundf(at.x))
	var out := PackedFloat32Array()
	out.resize(x_hi - x_lo + 1)
	for i in out.size():
		var lc := x_lo + i - ax + k
		out[i] = loc[lc] + at.y if lc >= 0 and lc < loc.size() else INF
	return out


static func _oval_of(rooms: Array) -> Rect2:
	for p in rooms:
		if p[0] == &"oval":
			return p[1]
	return Rect2()


## Room top per column, pulled up by `gv` round each part, so another room stays `gv` clear.
static func _room_tops(rooms: Array, at: Vector2, x_lo: int, x_hi: int, gv: float) -> PackedFloat32Array:
	var n := x_hi - x_lo + 1
	var raw := PackedFloat32Array()
	raw.resize(n)
	raw.fill(INF)
	for p in rooms:
		var r: Rect2 = p[1]
		r.position += at
		for i in n:
			var cx := float(x_lo + i) + 0.5
			if cx < r.position.x or cx > r.end.x:
				continue
			var t := r.position.y
			if p[0] == &"oval":
				var u := (cx - r.get_center().x) / (r.size.x * 0.5)
				if absf(u) >= 1.0:
					continue
				t = r.get_center().y - r.size.y * 0.5 * sqrt(1.0 - u * u)
			raw[i] = minf(raw[i], t)
	var out := PackedFloat32Array()
	out.resize(n)
	var k := int(ceilf(gv))
	var lift := PackedFloat32Array()
	for d in range(-k, k + 1):
		lift.append(sqrt(maxf(0.0, gv * gv - float(d * d))))
	out.fill(INF)
	# each column with a top pulls up the columns round it
	for j in n:
		var t := raw[j]
		if t == INF:
			continue
		for d in range(maxi(-k, -j), mini(k, n - 1 - j) + 1):
			var v := t - lift[d + k]
			if v < out[j + d]:
				out[j + d] = v
	return out


## The bottom of a ship's room down each column of its block (block-relative,
## the block's top at 0); -INF where it has none.
static func _room_bottoms(rooms: Array, b: Rect2) -> PackedFloat32Array:
	var n := int(ceilf(b.size.x))
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(-INF)
	for p in rooms:
		var r: Rect2 = p[1]
		for i in n:
			var cx := b.position.x + float(i) + 0.5
			if cx < r.position.x or cx > r.end.x:
				continue
			var bt := r.end.y
			if p[0] == &"oval":
				var u := (cx - r.get_center().x) / (r.size.x * 0.5)
				if absf(u) >= 1.0:
					continue
				bt = r.get_center().y + r.size.y * 0.5 * sqrt(1.0 - u * u)
			out[i] = maxf(out[i], bt - b.position.y)
	return out


## C: one above another, each readout beside its ship.
func _pack_column(live: Array[EnemySlot], s: float, area: Rect2, mid: float) -> Dictionary:
	var units: Array[Vector2] = []
	var total := 0.0
	var wide := 0.0
	for sl in live:
		var u := sl.unit(s, true)
		units.append(u)
		total += u.y
		wide = maxf(wide, u.x)
	total += PACK_VGAP * float(live.size() - 1)
	if total > area.size.y or wide > area.size.x:
		return {}
	var x := _place_span(wide, area, mid)
	var y := area.position.y + (area.size.y - total) * 0.5
	var out := {}
	for i in live.size():
		var u := units[i]
		# right-aligned, so the ships stand in a line and the readouts face you
		out[live[i]] = {scale = s, side = true, rect = Rect2(x + wide - u.x, y, u.x, u.y)}
		y += u.y + PACK_VGAP
	return out


## Ships sit lower so the three-line hit stack (Jon, Oct 13) stays under the HUD, off the hull.
## Why: docs/why/EncounterView.md#hit-number-room
const POP_ROOM := HitText.GAP + 2.0 * HitText.LINE + HitText.CAP + 1.0 + HitText.RISE + 2.0

func _low_enough(top: float, h: float, area: Rect2) -> float:
	if _slots_mode == &"wrecks":
		return top
	var want := area.position.y + POP_ROOM
	if top >= want:
		return top
	return maxf(top, minf(want, area.end.y - h))


## Where a span of `w` starts: centred on the enemy half while it fits there,
## slid toward you only as far as the view's edge makes it.
func _place_span(w: float, area: Rect2, mid: float) -> float:
	var x := mid - w * 0.5
	if x + w > area.end.x:
		x = area.end.x - w
	return maxf(area.position.x, x)


## One highlight at a time: slots never hear the cursor leave, so each claim clears the rest.
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

## Which style enemy `i` of this fight dies in, asked by the slots before they
## draw (the fight's screen knows where the wrecks will lie).
var death_style: Callable
## Where each fight slot's wreck will lie (`node * 64 + nth`), by index: keys the
## slot's marked wreck and seeds its hit effects (`EnemySlot.wreck_id`).
var wreck_id: Callable

## Forwarded to every slot: what a held card would do to that target.
var preview: Callable:
	set(v):
		preview = v
		if _ship_slot != null:
			_ship_slot.preview = v
		# `_made`, not `_slots`: `_slots` is the container, `_made` holds the EnemySlots.
		for sl in _made:
			(sl as EnemySlot).preview = v

## Both points are in the effects layer's coordinates, since that draws the line between them.
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

## Ask where the ship is instead of deriving it from `ShipSlot.HULL_BIAS`; the row gains children.
## Why: docs/why/EncounterView.md#hull-anchor
func self_anchor() -> Vector2:
	if _ship == null:
		return size * 0.5
	return get_global_transform().affine_inverse() \
		* _ship.get_global_rect().get_center()


func ship_view() -> ShipView:
	return _ship

## Returns the flare so callers hang off `peaked`, the frame the ship changes hands on.
func ship_flare_melts() -> bool:
	return _ship_slot != null and _ship_slot.flare.melts()

func ship_pulse() -> JumpFx:
	return _ship_slot.pulse() if _ship_slot != null else null

func enemy_view(i: int = 0) -> EnemyArt:
	var sl := slot(i)
	return sl.art if sl != null else null

## The sky bleeds past the view and the contents do not, so no seam shows during arrival.
## Why: docs/why/EncounterView.md#sky-bleed
var _bleed: float = 0.0

## Grow the view and hold `_row` up: `clip_contents` would cut a child reaching past the seam.
## Why: docs/why/EncounterView.md#sky-bleed
func set_bleed(px: float) -> void:
	var want := maxf(px, 0.0)
	if is_equal_approx(_bleed, want):
		return
	_bleed = want
	offset_bottom = want
	if _row != null:
		_row.offset_bottom = -want
	queue_redraw()

## Reapply after a camera move: `set_bleed` skips repeats, leaving the row low (Jon, Oct 22).
## Why: docs/why/EncounterView.md#sky-bleed
func reapply_bleed() -> void:
	offset_bottom = _bleed
	if _row != null:
		_row.offset_bottom = -_bleed

func _draw() -> void:
	# The void is never flat black: a wash tinted by region gives each place a
	# colour signature for free, which is the cheapest richness available.
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, h)), Color("#070a10"), true)
	var steps := 5
	for i in steps:
		var f := float(i) / float(steps)
		var band := Rect2(Vector2(size.x * (0.45 + f * 0.14), 0),
			Vector2(size.x, h))
		draw_rect(band, Color(_tint.r, _tint.g, _tint.b, 0.10), true)

	# Stars moved to `SpaceBackdrop`, seeded per system; one fixed seed gave every sector one sky.


## Every node type gets a lit picture before real art exists, by ART_CONTRACT's two-plane rule.
## Why: docs/why/EncounterView.md#place-pictures
class AreaView extends Control:
	var node: MapGen.MapNode
	## Where in its system this picture stands; `ANY` draws the whole system, as the sheets do.
	var site := ANY
	const ANY := -99

	## Six value stops from the ART_CONTRACT table, so stations here and on the chart share steel.
	var _grey: Array[Color] = [Color("#141721"), Color("#1e202a"), Color("#2e313e"),
		Color("#424758"), Color("#5c6376"), Color("#80889e")]
	## Wreck ramp is cold but not near black, or the derelict reads as a hole.
	var _dead: Array[Color] = [Color("#0c1219"), Color("#16202b"), Color("#22303f"),
		Color("#33455a"), Color("#465b73"), Color("#5f7890")]
	var _heat: Array[Color] = [Color("#5c280c"), Color("#964214"), Color("#cc641c"),
		Color("#ffa63c"), Color("#ffdca0"), Color("#fff6e2")]
	var _ink: Color = Color("#0b0f16")

	## Two names for one clock: strobes read seconds, the transmission reads cycle position.
	var _clock: float = 0.0
	var _phase: float = 0.0
	## Slow on purpose: a readable pulse would compete with what you came to look at.
	const RING_S := 1.9
	## 12 Hz, not frame rate: strobes still snap and rings still glide, with far less repainting.
	const REDRAW_HZ := 12.0
	var _since_draw: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Off until `setup` decides this place moves, so static sectors run no `_process`.
		set_process(false)

	func setup(n: MapGen.MapNode) -> void:
		node = n
		set_process(SHOW_PLACES and _moves())
		queue_redraw()

	## Only two places move, so every other sector pays nothing for this.
	func _moves() -> bool:
		var what := _place_name()
		return what == &"station" or what == &"beacon"

	func _process(delta: float) -> void:
		_clock += delta
		_phase = fposmod(_clock / RING_S, 5.0)
		_since_draw += delta
		if _since_draw >= 1.0 / REDRAW_HZ:
			_since_draw = 0.0
			queue_redraw()

	## ON since 2026-09-12 by Jon: turn it on now, commission art later.
	## The risk stands: placeholder art that reads well can quietly become the shipped answer.
	## Why: docs/why/EncounterView.md#place-art-switch
	const SHOW_PLACES := true

	## Named, not typed, so the sprite and the drawing are chosen by one line and cannot disagree.
	## Why: docs/why/EncounterView.md#place-picture-choice
	func _place_name() -> StringName:
		if node == null:
			return &""
		match node.type:
			# THE STATION ONLY WHERE IT IS (dock:A): at a world, the star or open
			# space of its system the hab ring is not beside you
			MapGen.NodeType.STATION:
				return &"station" if Router.at_station(node) else &""
			# No place picture on LOCAL (Jon, Oct 21): the event itself shows; sheets still draw.
			# Why: docs/why/EncounterView.md#place-picture-choice
			MapGen.NodeType.SYSTEM:
				if site != ANY:
					return &""
				if OptionTable.system_has_tag(node, &"fight"):
					return &"battlefield_cleared" if node.cleared else &"battlefield"
				if OptionTable.system_has_tag(node, &"salvage"):
					return &"derelict"
				return &"beacon"
			# Core and pulsar are the system's star, which LOCAL's sky draws; no second one.
			# Why: docs/why/EncounterView.md#place-picture-choice
			MapGen.NodeType.CORE, MapGen.NodeType.PULSAR:
				return &""
			# Where you start is empty space. Drawing a marker here would put an
			# object in the one sector that is meant to have nothing in it.
			MapGen.NodeType.START:
				return &""
		# (nor a stand-in for a type that has no picture of its own)
		return &"" if site != ANY else &"unknown"

	func _draw() -> void:
		if node == null or not SHOW_PLACES:
			return
		var c := (size * 0.5).round()
		var tint := MapGen.star_colour(node)
		var what := _place_name()
		if what == &"":
			return
		# Animated parts are overlays drawn after the picture, so the asset stays one still frame.
		# Why: docs/why/EncounterView.md#place-picture-choice
		var tex: Texture2D = DB.place_sprite(what)
		if tex != null:
			# The beacon's rings go BEHIND the buoy; everything else that moves
			# goes in front. See `_beacon_rings`.
			if what == &"beacon":
				_beacon_rings(c, tint)
			# Centred and unscaled, on whole pixels. Everything in this game is
			# drawn on a 960x540 grid and a half-pixel offset resamples it.
			draw_texture(tex, (c - tex.get_size() * 0.5).round())
			match what:
				&"station": _station_lights(c)
				&"beacon": _beacon_lamp(c)
			return
		match what:
			&"station": _station(c)
			&"battlefield", &"battlefield_cleared": _battlefield(c)
			&"derelict": _derelict(c)
			&"beacon": _beacon(c, tint)
			&"core": _core(c)
			&"pulsar": _pulsar(c)
			_:
				draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), tint, true)

	# --- the two-plane kit ---------------------------------------------------

	## `deck` is how much height the top face takes: high looking down, low hanging below.
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

	## A ring station: habitat torus on a docking spine, the only warm and friendly thing here.
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
		# Windows sit on the arc, not a line at its apex, or outer ones float off the ring.
		for i in 9:
			var wx := -52.0 + float(i) * 13.0
			var wy := 26.0 * sqrt(maxf(0.0, 1.0 - (wx / 62.0) * (wx / 62.0)))
			_window(c + Vector2(wx, -wy - 8.0), Vector2(6, 4))
		for i in 5:
			_window(c + Vector2(-30 + i * 15, -6), Vector2(5, 3))
		_window(c + Vector2(-3, -30), Vector2(6, 3))
		_station_lights(c)

	## Strobes are the one animation, kept separate so a sprite can keep them over a still station.
	## Why: docs/why/EncounterView.md#station-and-beacon
	func _station_lights(c: Vector2) -> void:
		var dark := Color("#2b4759")
		draw_rect(Rect2(c + Vector2(-64, -2), Vector2(3, 3)),
			dark.lerp(Color("#8ec8e6"), _strobe(2.3, 0.0)), true)
		draw_rect(Rect2(c + Vector2(61, -2), Vector2(3, 3)),
			dark.lerp(Color("#8ec8e6"), _strobe(3.1, 1.4)), true)

	## Not a sine: a flash after long dark reads as a signalling machine, not a pulsing glow.
	## Why: docs/why/EncounterView.md#station-and-beacon
	func _strobe(period: float, offset: float) -> float:
		var u := fposmod(_clock + offset, period) / period
		return clampf(1.0 - u * 7.0, 0.0, 1.0)

	## A derelict is the station picture with the power off and a hole through it.
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

	## Rings thin as they go, the only depth cue for something with no surface.
	func _beacon(c: Vector2, tint: Color) -> void:
		_beacon_rings(c, tint)
		# The buoy itself. Small — most of the picture is the thing it is doing.
		_body(c + Vector2(-4, -34), Vector2(8, 62), _grey, 0.5)
		_body(c + Vector2(-16, -44), Vector2(32, 12), _grey, 0.7)
		_body(c + Vector2(-11, 24), Vector2(22, 7), _grey, 0.4)
		_beacon_lamp(c)

	## Rings split from the lamp: a buoy sprite goes between them, rings first, lamp on top.
	## Why: docs/why/EncounterView.md#station-and-beacon
	func _beacon_rings(c: Vector2, tint: Color) -> void:
		# Rings walk outward on one cycle so the loop hides itself: an empty system still talking.
		# Why: docs/why/EncounterView.md#station-and-beacon
		for i in 5:
			var k := fposmod(float(i) + _phase, 5.0)
			var rr := 26.0 + k * 15.0
			var col := tint.lerp(Color("#070a10"), 0.18 + k * 0.17)
			var step: int = 2 + int(k)
			var n := int(rr * 2.4)
			for j in n:
				var a := TAU * float(j) / float(n)
				if j % step != 0:
					continue
				draw_rect(Rect2(c + Vector2(cos(a) * rr, sin(a) * rr * 0.62),
					Vector2(2, 2)), col, true)

	## The lamp, which answers the rings. Drawn over the buoy, generated or not.
	func _beacon_lamp(c: Vector2) -> void:
		# The lamp brightens as a ring leaves, so they read as one machine.
		var fire := 1.0 - clampf(fposmod(_phase, 1.0) * 3.2, 0.0, 1.0)
		draw_rect(Rect2(c + Vector2(-6, -50), Vector2(12, 6)), _ink, true)
		draw_rect(Rect2(c + Vector2(-5, -49), Vector2(10, 4)),
			_heat[1].lerp(_heat[2], fire), true)
		draw_rect(Rect2(c + Vector2(-5, -49), Vector2(10, 2)),
			_heat[3].lerp(_heat[4], fire), true)
		draw_rect(Rect2(c + Vector2(-3, -49), Vector2(6, 1)),
			_heat[4].lerp(_heat[5], fire), true)

	## The Custodian's hole. A disc seen nearly edge-on, brightest where it is
	## about to fall in, with the shadow left as a shadow.
	func _core(c: Vector2) -> void:
		# Halo is dithered, not stacked translucent boxes, whose corners showed at this size.
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

	## A pulsar's star is barely a pixel, so draw the sweeping beam and the remnant round it.
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
	var art: ShipView
	var _hot: bool = false
	var claim: Callable
	var preview: Callable
	var _drag_text: String = ""

	## Hull is centred in the left two thirds by anchor, as `ShipView.arrive()` resets position.
	## Why: docs/why/EncounterView.md#own-ship-slot
	const HULL_BIAS := 0.68

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		art = ShipView.new()
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# `set_anchor()`, not `anchor_right =`: the property setter keeps the offset, a no-op.
		art.set_anchor(SIDE_RIGHT, HULL_BIAS, false)
		# Behind the slot's own `_draw`, or the brace number is covered by the ship.
		art.show_behind_parent = true
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# `zoom()`, not `magnify()`: the slot width is anchored, so a minimum size would fight it.
		# Why: docs/why/EncounterView.md#own-ship-slot
		art.zoom(1)
		# The idle bob is 2, as on the ship screen; it moves inside the canvas, not the Control.
		# Why: docs/why/EncounterView.md#own-ship-slot
		art.bob(2)
		# The hull is now bigger than its slot on the deepest frames, and the
		# enemy panel is immediately to the right of it.
		art.clip_contents = true
		add_child(art)

		# Fitted parts show passively here; refit stays the only place to change them.
		var mounts := MountPoints.new()
		mounts.attach(art)
		mounts.passive()
		art.add_child(mounts)

		# Column sized to the hull, not the slot, or 20 px reads as a drawn rule, not a beam.
		# Why: docs/why/EncounterView.md#jump-flare
		_flare_box = Control.new()
		_flare_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_flare_box)
		# `JumpFx` not `JumpFlare`: every style peaks on one frame, so the swap frame is fixed.
		flare = JumpFx.new()
		flare.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_flare_box.add_child(flare)

	var flare: JumpFx
	var _flare_box: Control

	## Re-measured at play time and tracked each frame, so the beam does not miss the moving hull.
	## Why: docs/why/EncounterView.md#jump-flare
	func _process(_d: float) -> void:
		if not flare.visible:
			set_process(false)
			return
		# One clock: charge, snap and run live in `JumpFx`; the hull is told where it is on it.
		if flare.melts():
			art.set_melt(flare.melt_amount())
			art.set_shake(flare.shake_amount())
			art.set_spool(flare.spool_look(), flare.spool_amount(), flare.charge_secs())
		_aim()

	func _aim() -> void:
		# THE BODY, NOT THE CANVAS. The canvas carries empty columns at the stern
		# for the exhaust art, so a box sized to it put every beam past the tail.
		var b := art.hull_body()
		_flare_box.position = art.position + b.position
		_flare_box.size = b.size

	func pulse() -> JumpFx:
		# Hull, not slot: sizing to the slot drew rings wider than the ship is long.
		_aim()
		flare.centre = 0.5
		flare.play(0.0)
		set_process(true)
		return flare

	## Your hull refuses attacks, same rule the drop path uses.
	func aimable(c: CardData) -> bool:
		if c == null:
			return false
		return c.damage <= 0 and not c.damage_equals_heat and c.evoke <= 0


	func aim(on: bool, text: String = "") -> void:
		set_hot(on)
		var t := text if on else ""
		if t != _drag_text:
			_drag_text = t
			queue_redraw()


	func set_hot(v: bool) -> void:
		if _hot == v:
			return
		_hot = v
		queue_redraw()

	## NO `_can_drop_data`. See `aim` above and `CardView`'s note: your hull is
	## aimed at, not dropped on.


	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and _hot:
			_hot = false
			queue_redraw()

	## Where the hull actually is, in this slot's coordinates. Falls back to the
	## whole slot before the art has anything to measure.
	func _hull_box() -> Rect2:
		if art == null:
			return Rect2(Vector2.ZERO, size)
		var r := art.ship_rect()
		r.position += art.position
		r = r.grow(5.0)
		var clipped := r.intersection(Rect2(art.position, art.size))
		return clipped if clipped.size.x > 8.0 and clipped.size.y > 8.0 else r

	func _draw() -> void:
		if not _hot:
			return
		var c := UITheme.GOOD
		var n := 10.0
		# Brackets bind to the hull, not the slot, which spans most of half the screen.
		var box := _hull_box()
		for corner in [
				[box.position, Vector2(1, 1)],
				[Vector2(box.end.x, box.position.y), Vector2(-1, 1)],
				[Vector2(box.position.x, box.end.y), Vector2(1, -1)],
				[box.end, Vector2(-1, -1)]]:
			var o: Vector2 = corner[0]
			var d: Vector2 = corner[1]
			draw_rect(Rect2(o + Vector2(0, -1 if d.y < 0 else 0), Vector2(n * d.x, 1)), c, true)
			draw_rect(Rect2(o + Vector2(-1 if d.x < 0 else 0, 0), Vector2(1, n * d.y)), c, true)

		# Card benefit shows over your hull, centred on its ink, not the clipped bracket box.
		# Why: docs/why/EncounterView.md#drag-preview
		if _drag_text != "":
			HitText.draw_centred(self, ink_rect().get_center(), _drag_text, HitText.colour(&"gain"))

	## Your hull's ink in this slot's coordinates, the bob taken out.
	func ink_rect() -> Rect2:
		if art == null:
			return Rect2(Vector2.ZERO, size)
		var r := art.ship_rect()
		r.position += art.position
		return r

	## Where the held card's number is drawn, its letters' own box.
	func preview_rect(text: String) -> Rect2:
		return HitText.ink_rect(HitText.centred_at(ink_rect().get_center(), text), text)


## Readouts are painted over the ship, not stacked, to save arena rows. Not a drop target.
## The jump light is cold, not ember, so it is not mistaken for another gun.
## Why: docs/why/EncounterView.md#partner-slot
class JumpFlare extends Control:
	## Long enough to be an event, short enough that four of them staggered do
	## not turn arriving into a cutscene.
	const LIFE := 0.40
	## The moment the hull changes hands. The flash is at its widest here, so
	## the swap happens behind the brightest frame and is never seen.
	const PEAK := 0.42
	const CORE := Color("#e4f2ff")
	## Wide enough to be a column, not a rule: 20 px against a 208 px slot.
	const MAX_W := 20.0
	## Width peaks exactly at PEAK, the hull's swap frame, so the swap hides in the flash.
	const OPEN := 0.22
	const SHUT := 0.80

	signal peaked()
	signal finished()

	## Column position as a slot fraction; your hull is left-biased, so a beam elsewhere misses.
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

		# Two width segments meeting at PEAK, not one sine, which peaked at 0.62 against 0.42.
		# Why: docs/why/EncounterView.md#jump-flare
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
	## Leaving ships stay children until the flash ends: vanishing on JUMP is deletion, not leaving.
	var _leaving: bool = false
	var _label: String = ""
	var _hull_at: float = 1.0
	var _heat_at: float = 0.0
	var _lost: bool = false
	## Engaged mark: a fight involves only some of the party, so presence cannot show it.
	## Why: docs/why/EncounterView.md#partner-slot
	var _engaged: bool = false

	## Fixed bar width, as `EnemySlot.BAR_W`: length should show what is left, not room.
	const BAR_W := 92.0
	const BAR_H := 3.0

	func _init(id: int, view_height: int) -> void:
		peer = id
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Cropped, not scaled: only integer magnification is allowed, and half of 1 is not a pixel.
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
		# The name and gauges must redraw when the hull shows, or a partner flies in unnamed.
		# Why: docs/why/EncounterView.md#partner-label-redraw
		art.visibility_changed.connect(queue_redraw)
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
			# Ask for the name and gauges back after a departure: `_draw()` bailed with no hull.
			# Why: docs/why/EncounterView.md#partner-label-redraw
			queue_redraw()
			# Same approach as every ship: the flare punctuates the arrival, not replaces it.
			art.arrive(1, 0.0), CONNECT_ONE_SHOT)
		flare.play(delay)
		# Player's own arrival sound, throttled so a convoy arriving together sounds as one.
		Audio.play(&"hyperjump_in", 0.10, 900)

	## And left. Same flash, opposite side of it.
	func jump_out() -> void:
		_leaving = true
		flare.peaked.connect(func() -> void:
			art.visible = false
			queue_redraw(), CONNECT_ONE_SHOT)
		flare.finished.connect(queue_free, CONNECT_ONE_SHOT)
		flare.play(0.0)
		Audio.play(&"hyperjump", 0.10, 900)
		queue_redraw()

	func leaving() -> bool:
		return _leaving

	func bind(slot: Dictionary) -> void:
		var b: ShipBuild = Net.build_of(peer)
		var who := String(slot.get("name", "")).to_upper()
		var was_lost := _lost
		var was_engaged := _engaged
		if b == null:
			# In the party, not yet in a ship. A name with no readouts under it
			# says that better than a full hull bar on a ship nobody is flying.
			_label = "%s · NO SHIP YET" % who
			_hull_at = 0.0
			_heat_at = 0.0
			_lost = false
		else:
			_label = "%s · %s" % [who,
				HullData.weight_name(b.hull.weight).to_upper()]
			_hull_at = clampf(float(b.hp) / float(maxi(1, b.max_hp)), 0.0, 1.0)
			_heat_at = clampf(b.heat_ratio(), 0.0, 1.0)
			_lost = b.dead
		var f := Net.fight_at(Run.at) if not Run.map.is_empty() else null
		_engaged = f != null and not f.over and f.crew.has(peer)
		# A partner lost in your fight comes apart visibly, as yours does, only if shown alive.
		if b != null and not _lost:
			_seen_alive = true
		elif _lost and not was_lost and _seen_alive and (was_engaged or _engaged) \
				and Router.animating() and _wreck == null:
			_break_up()
		art.modulate = Color(0.45, 0.45, 0.52) if _lost else Color.WHITE
		queue_redraw()

	var _seen_alive := false
	var _wreck: ShipBreakup = null
	var _pre: Dictionary = {}

	## A slot freed mid-cut still waits for its task and frees the unplayed breakup.
	func _exit_tree() -> void:
		_drop_pre()

	func _drop_pre() -> void:
		if _pre.is_empty():
			return
		WorkerThreadPool.wait_for_task_completion(_pre.task)
		if _pre.held.b != null:
			(_pre.held.b as Node).free()
		_pre = {}

	func _break_up() -> void:
		var pic := ShipLoss.picture(art)
		if pic.is_empty():
			return
		var n := Run.node_at().index
		var pre := ShipLoss.prebuild(pic, ShipLoss.style_for(n, peer), ShipLoss.seed_for(n, peer))
		_pre = pre
		# Cut off the main thread; the hull stays up until the cut is ready.
		while not ShipLoss.is_cut(pre):
			await get_tree().process_frame
			if _pre.is_empty():
				return
		if not is_inside_tree() or _leaving:
			_drop_pre()
			return
		_pre = {}
		var b := ShipLoss.play(pre, self, art)
		if b == null:
			return
		_wreck = b
		# The hull goes; the slot's own name and LOST stay over it.
		art.self_modulate.a = 0.0
		b.broke.connect(func(s: float) -> void:
			Audio.play_kill(-1, -4.0 if s >= 0.6 else -10.0))
		# The wreck in the same grey a lost ship is drawn in.
		b.finished.connect(func() -> void:
			b.modulate = Color(0.45, 0.45, 0.52))

	func _draw() -> void:
		# Paint nothing without a hull, or a name and bars hang in empty space.
		if not art.visible:
			return
		var f := UITheme.pixel_font()
		var fs := UITheme.FS_SMALL
		var text := "LOST · " + _label if _lost else _label
		if _engaged and not _lost:
			# Same arrow as the combat log's shot of yours: firing on your side is about the fight.
			text = "▸ " + text
		# Shadowed, because the label sits on a hull rather than on a panel and
		# the hull is the same value range as the type.
		text = LowHull.scr(self, text, fs, f)
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
		# Gauges sit directly under the name: floor bars float and read as the next ship's.
		# Why: docs/why/EncounterView.md#gauge-placement
		_gauge(float(fs) + 3.0, _hull_at, UITheme.HULL_GREEN)
		_gauge(float(fs) + 3.0 + BAR_H + 1.0, _heat_at,
			UITheme.FLARE if _heat_at >= 1.0 else UITheme.EMBER)

	func _gauge(y: float, at: float, col: Color) -> void:
		draw_rect(Rect2(Vector2(0, y), Vector2(BAR_W, BAR_H)), Color("#0d131b"), true)
		if at > 0.0:
			draw_rect(Rect2(Vector2(0, y), Vector2(BAR_W * at, BAR_H)), col, true)
