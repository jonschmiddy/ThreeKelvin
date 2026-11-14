class_name ConvoySlot
extends Control

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
## Why: docs/why/ConvoySlot.md#partner-slot
var _engaged: bool = false
## In your fight and STUNNED (`SharedFight.stunned`, Jon, Nov 5): joined
## after the first turn and sitting out until the enemy's turn is over. A
## tag under its gauges, in COLD, until the turn moves.
var _stunned: bool = false
const STUN_TAG := "STUNNED"

## Fixed bar width, as `EnemySlot.BAR_W`: length should show what is left, not room.
const BAR_W := 92.0
const BAR_H := 3.0
## The gauge bar's empty well.
const GAUGE_WELL := Color("#0d131b")

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
	# Why: docs/why/ConvoySlot.md#partner-label-redraw
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
		# Why: docs/why/ConvoySlot.md#partner-label-redraw
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

## OUT OF THE STATION (Jon's co-op rules, Nov 13): a partner undocking here, or
## arriving where you are moored right, comes out of the mouth (`mouth`, INF until
## the station is up) to its place, behind your hull, engines lit until it slows.
## Why: docs/why/ConvoySlot.md#out-of-the-station
const OUT_S := 2.4
var _move := {}
## In a mirrored LOCAL (`EncounterView.mirrored`): the hull and the name drawn
## flipped back, so it faces right and reads.
var flipped := false:
	set(v):
		flipped = v
		_face_art()
		queue_redraw()
## The hull's size against its place, as it flies (1 at rest).
var _k := 1.0


func _face_art() -> void:
	if art == null:
		return
	# (at rest and unflipped, the hull is left alone: its own arrival moves it)
	if not flipped and _move.is_empty() and is_equal_approx(_k, 1.0) and art.scale == Vector2.ONE:
		return
	art.pivot_offset = (art.size * 0.5).floor()
	art.scale = Vector2(-_k if flipped else _k, _k)
	if _move.is_empty():
		art.position = _rest()


## Where the hull sits in its place: mirrored, its nose kept off the screen's edge
## (+x is toward the middle of the screen there).
const FLIP_IN := 20.0


func _rest() -> Vector2:
	return Vector2(FLIP_IN if flipped else 0.0, 0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_face_art()


func come_out(mouth: Callable, delay: float = 0.0) -> void:
	art.visible = false
	_move = {"mouth": mouth, "t": -delay, "out": true}
	set_process(true)


## Into the mouth from its place (a partner docking, seen from the station's left).
func go_in(mouth: Callable) -> void:
	_leaving = true
	_move = {"mouth": mouth, "t": 0.0, "out": false}
	set_process(true)
	queue_redraw()


## Faded where it sits (a partner docking, seen from the station's right).
func fade_out() -> void:
	_leaving = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if _move.is_empty():
		set_process(false)
		return
	var g: Vector2 = (_move.mouth as Callable).call()
	if g == Vector2.INF:
		return
	_move.t = float(_move.t) + delta
	var t := float(_move.t)
	if t < 0.0:
		return
	var u := clampf(t / OUT_S, 0.0, 1.0)
	# where the mouth is in this slot's own pixels, the hull's middle put on it (the
	# hull's own middle, not its box's: it sits to one side of a box sized for the widest)
	var ic := art.canvas_to_local(Rect2(art.ink_rect()).get_center())
	if flipped:
		ic.x = art.size.x - ic.x
	var at := get_global_transform().affine_inverse() * g - ic
	var out := bool(_move.out)
	# out: quick from the mouth, easing into its place; in: easing off, faster into it
	var k := 1.0 - pow(1.0 - u, 2.4) if out else pow(u, 2.0)
	var f := (1.0 - k) if out else k
	clip_contents = false
	art.visible = true
	art.position = _rest().lerp(at, f)
	_k = lerpf(1.0, 0.7, f)
	_face_art()
	var lit := u < 0.7 if out else u > 0.05
	if lit != bool(_move.get("lit", false)):
		_move["lit"] = lit
		art.burn(lit)
	queue_redraw()
	if u >= 1.0:
		_move = {}
		art.burn(false)
		if out:
			_k = 1.0
			_face_art()
			clip_contents = true
			queue_redraw()
		else:
			art.visible = false
			queue_free()


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
	_stunned = _engaged and f.stunned.has(peer)
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
	# Paint nothing without a hull, or a name and bars hang in empty space;
	# nor while it flies, out of or into the station.
	if not art.visible or not _move.is_empty():
		return
	# (mirrored: drawn flipped back about the slot's middle, so it reads)
	if flipped:
		draw_set_transform(Vector2(size.x, 0.0), 0.0, Vector2(-1.0, 1.0))
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
	# Why: docs/why/ConvoySlot.md#gauge-placement
	_gauge(float(fs) + 3.0, _hull_at, UITheme.HULL_GREEN)
	_gauge(float(fs) + 3.0 + BAR_H + 1.0, _heat_at,
		UITheme.FLARE if _heat_at >= 1.0 else UITheme.EMBER)
	if _stunned:
		var ty := _tag_y()
		draw_string(f, Vector2(1, ty + 1), STUN_TAG, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
		draw_string(f, Vector2(0, ty), STUN_TAG, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.COLD)

## The tag's baseline: a line under the two gauges.
func _tag_y() -> float:
	var fs := UITheme.FS_SMALL
	return float(fs) + 3.0 + BAR_H * 2.0 + 1.0 + 2.0 + float(fs)

## Whether the tag is up, and where, in this slot's own coordinates
## (`-- sheet=ConvoySlideTest`'s box test): inside the label's BAR_W.
func stunned_shown() -> bool:
	return _stunned and not _lost and art.visible and _hull_at > 0.0

func stun_tag_rect() -> Rect2:
	var f := UITheme.pixel_font()
	var fs := UITheme.FS_SMALL
	var w := f.get_string_size(STUN_TAG, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return Rect2(0.0, _tag_y() - f.get_ascent(fs), w + 1.0, f.get_height(fs) + 1.0)

func _gauge(y: float, at: float, col: Color) -> void:
	draw_rect(Rect2(Vector2(0, y), Vector2(BAR_W, BAR_H)), GAUGE_WELL, true)
	if at > 0.0:
		draw_rect(Rect2(Vector2(0, y), Vector2(BAR_W * at, BAR_H)), col, true)
