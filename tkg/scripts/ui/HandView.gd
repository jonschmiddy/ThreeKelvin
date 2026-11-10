class_name HandView
extends Control

## Laid out by hand, not a container, so views tween to slots and the hand does not jump.
## Why: docs/why/HandView.md#hand-layout

signal card_hovered(view: CardView, entered: bool)
## A keyword on a card in this hand pointed at, or left (T2).
signal word_hovered(view: CardView, term: String, on: bool)
## Carries the finished order, not an index, which needed re-basing and landed a slot off.
signal reordered(cards: Array)

## A card in the hand was picked to satisfy a discard or a decommission. Separate
## from playing one, because it is a different question with a different answer.
signal picked(card: CardData)
## A card in this hand was pressed. Forwarded rather than handled: what the
## press becomes is the screen's business, not the hand's.
signal card_grabbed(view: CardView, at: Vector2)

const GAP := 5
const SLIDE := 0.14
## Between one dealt card and the next.
const DEAL_GAP := 0.055

var _views: Array[CardView] = []
## Where the dragged card would land. -1 when nothing is being dragged over us.
var _preview_slot: int = -1
var _drag_card: CardData = null
## One live tween per card. Stacking tweens on the same property makes them
## fight, which reads as flicker.
var _tweens: Dictionary = {}

## Slower than `ItemIcon.FOLLOW`'s 16 on purpose: a card should feel carried.
const CARD_FOLLOW := 9.0
## A carried card is driven per frame, not tweened: the tween wins on its first frame and snaps.
var _carry: CardView = null
var _carry_to: Vector2 = Vector2.ZERO
## Follow-driven, not tweened: a tween takes SLIDE seconds from any distance and teleports.
var _settle: CardView = null
var _settle_to: Vector2 = Vector2.ZERO

func _init() -> void:
	# The hand accepts drops so a card dragged back is reordered, not played.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Shrink-centred so the hand is a card plus padding, not tied to the draw pile's height.
	# Why: docs/why/HandView.md#hand-height
	custom_minimum_size = Vector2(0, CardView.CARD_H + 16)
	# Bottom, not centre: centred left cards 7 px above the DRAW and DISCARD baseline.
	# Why: docs/why/HandView.md#hand-height
	size_flags_vertical = Control.SIZE_SHRINK_END
	clip_contents = false

## Both placement sites read it: cards at zero piled 24 px of spare row underneath them.
## Why: docs/why/HandView.md#card-baseline
func _baseline() -> float:
	return maxf(0.0, (size.y - CardView.CARD_H) * 0.5)


## `choosing` makes every card clickable and nothing playable. `live` and `hot` feed card numbers.
## Why: docs/why/HandView.md#hand-sync
func sync(cards: Array, playable: Callable, choosing: bool = false,
		live: Callable = Callable(), hot: Callable = Callable()) -> void:
	var keep: Array[CardView] = []
	for c in cards:
		var found: CardView = null
		for v in _views:
			if v.card == c and not keep.has(v):
				found = v
				break
		if found == null:
			found = CardView.new()
			add_child(found)
			found.setup(c, playable.call(c))
			found.chosen.connect(func(v: CardView) -> void: picked.emit(v.card))
			found.word_hovered.connect(func(v: CardView, t: String, on: bool) -> void:
				word_hovered.emit(v, t, on))
			found.grabbed.connect(func(v: CardView, p: Vector2) -> void:
				card_grabbed.emit(v, p))
			found.size = Vector2(CardView.CARD_W, CardView.CARD_H)
			# Dealt from the deck side, so a draw reads as coming from somewhere.
			found.position = Vector2(-CardView.CARD_W, _baseline() + 12.0)
			found.set_meta(&"fresh", true)
			found.hovered.connect(func(v: CardView, e: bool) -> void:
				# Out of the stack when pointed at: the lift goes up, not forward of the neighbour.
				if e:
					v.move_to_front()
					# Hover sound, not while carried: the hand re-hovers a card as it follows.
					if not v.held:
						Audio.play(&"card_hover", 0.08, 45)
				else:
					_restack(_views)
				card_hovered.emit(v, e))
		else:
			found.set_playable(playable.call(c))
		found.set_picking(choosing)
		# After the branch so kept cards update too: modifiers move while a card sits in hand.
		found.set_live(live.call(c) if live.is_valid() else -1,
			hot.call(c) if hot.is_valid() else PackedStringArray())
		keep.append(found)

	for v in _views:
		if not keep.has(v):
			_discard(v)
	_views = keep
	_layout()

## The step shrinks to end at the right edge, so cards overlap. Five is the last that fits flat.
## Why: docs/why/HandView.md#card-step
func _step(n: int) -> float:
	var full := float(CardView.CARD_W + GAP)
	if n <= 1:
		return full
	if n * CardView.CARD_W + (n - 1) * GAP <= size.x:
		return full
	return maxf(12.0, (size.x - CardView.CARD_W) / float(n - 1))

func _layout() -> void:
	var order := _order_for_layout()
	var n := order.size()
	if n == 0:
		return
	var step := _step(n)
	var span := (n - 1) * step + CardView.CARD_W
	var x := (size.x - span) * 0.5
	var fresh := 0
	for i in n:
		var v: CardView = order[i]
		var target := Vector2(x + i * step, _baseline())
		# A card held back for its deal and then laid out again before its turn
		# came is shown now; nothing else would ever show it.
		if not v.has_meta(&"fresh"):
			v.visible = true
		# The lift springs back to this. Set on every layout, as the baseline moves with the band.
		v.set_base_y(target.y)
		v.size = Vector2(CardView.CARD_W, CardView.CARD_H)
		# The carried card answers to the cursor, not to its slot. Its neighbours
		# still slide, so the gap opens and closes under it as it moves.
		if _carry != null and v == _carry:
			continue
		# A card on its way home takes its target from here -- the layout is what
		# knows where home IS -- but travels under `_process`, not a tween.
		if _settle != null and v == _settle:
			_settle_to = target
			continue
		if v.position.distance_to(target) < 0.5:
			continue
		if _tweens.has(v) and is_instance_valid(_tweens[v]) and _tweens[v].is_valid():
			_tweens[v].kill()
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# A new hand is dealt with a beat between cards (combat polish F6), so five read as five.
		var wait := 0.0
		if v.has_meta(&"fresh"):
			v.remove_meta(&"fresh")
			wait = DEAL_GAP * fresh
			fresh += 1
		if wait > 0.0:
			# Out of sight until its turn, or the cards still waiting sit in a
			# stack over the energy box and the draw pile.
			v.visible = false
			tw.tween_interval(wait)
			# (by its weak reference: a card can be freed while it waits)
			var wv: WeakRef = weakref(v)
			tw.tween_callback(func() -> void:
				var c := wv.get_ref() as Control
				if c != null:
					c.visible = true)
		tw.tween_property(v, "position", target, SLIDE + (0.08 if wait > 0.0 else 0.0))
		_tweens[v] = tw
	_restack(order)

## Left card under, right over, so an overlapping fan reads as a fan.
func _restack(order: Array) -> void:
	# Pushed to the back in order: fading discards are children too and would stay on top.
	# Why: docs/why/HandView.md#restack
	for v in order:
		move_child(v as CardView, get_child_count() - 1)

## Lay out as though the dragged card already sat where the cursor is, so the
## gap opens under it and you can see the result before committing.
func _order_for_layout() -> Array:
	var order: Array = _views.duplicate()
	if _drag_card == null or _preview_slot < 0:
		return order
	var moving: CardView = null
	for v in order:
		if v.card == _drag_card:
			moving = v
			break
	if moving == null:
		return order
	order.erase(moving)
	order.insert(clampi(_preview_slot, 0, order.size()), moving)
	return order

func preview(card: CardData, slot: int) -> void:
	if _drag_card == card and _preview_slot == slot:
		return
	_drag_card = card
	_preview_slot = slot
	_layout()

## Previewed by position: the card under the cursor moves as the gap opens and flickers.
func preview_at(x: float, card: CardData) -> void:
	preview(card, _slot_at(x))

func clear_preview() -> void:
	var carried := _carry != null
	_drop_carry()
	if _preview_slot < 0 and _drag_card == null and not carried:
		return
	_preview_slot = -1
	_drag_card = null
	_layout()

## Played cards leave rather than vanish, so the eye can follow where they went.
func _discard(v: CardView) -> void:
	if _tweens.has(v) and is_instance_valid(_tweens[v]) and _tweens[v].is_valid():
		_tweens[v].kill()
	_tweens.erase(v)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Out of the stack on the way out, so it cannot come back over the top of
	# the cards that are still being played.
	v.z_index = -1
	move_child(v, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(v, "position", v.position + Vector2(0, 26), SLIDE)
	tw.tween_property(v, "modulate", Color(1, 1, 1, 0), SLIDE)
	tw.chain().tween_callback(v.queue_free)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
	elif what == NOTIFICATION_DRAG_END:
		clear_preview()

## No drop handlers: `SectorScreen` drives `slide_to` and `commit` now that there is no Godot drag.


## Which gap the cursor is nearest. Rounding rather than flooring means dropping
## on the right half of a card puts you after it, which is what the eye expects.
func _slot_at(x: float) -> int:
	var n := _views.size()
	if n <= 1:
		return 0
	# Same step the layout used, or the slot you drop into stops matching the
	# gap you saw open.
	var step := _step(n)
	var span := (n - 1) * step + CardView.CARD_W
	var start := (size.x - span) * 0.5
	var slot := int(round((x - start) / step))
	return clampi(slot, 0, n - 1)

## `reorder_onto` went with the drop handlers -- its only caller was the drag.
## `slide_to` above is what drives a reorder now.


## Drives reorder from a gesture this view does not own: the machinery outlived its caller.
func slide_to(at_global: Vector2, card: CardData) -> void:
	var v := _view_of(card)
	if v == null:
		return
	# Claimed before the layout: otherwise it starts a 0.14 s tween that fights the follow.
	if _carry != v:
		# Caught on its way home and picked up again: it is the carry's, not `_settle`'s.
		if _settle == v:
			_settle = null
		_carry = v
		v.set_held(true)
		# z_index, not child order, because `_restack` rewrites child order every layout.
		v.z_index = 1
		if _tweens.has(v) and is_instance_valid(_tweens[v]) and _tweens[v].is_valid():
			_tweens[v].kill()
		set_process(true)
	# Centred on the pointer, and the vertical clamped into the drawer: reorder is horizontal.
	var want := at_global - global_position \
		- Vector2(CardView.CARD_W, CardView.CARD_H) * 0.5
	want.y = clampf(want.y, _baseline() - 26.0, _baseline() + 6.0)
	_carry_to = want
	preview_at(at_global.x - global_position.x, card)

func _view_of(card: CardData) -> CardView:
	for v in _views:
		if v.card == card:
			return v
	return null

func _process(delta: float) -> void:
	# Exponential, so it never overshoots and the rate does not depend on the
	# frame rate. Same shape as ItemIcon's, slower.
	var k := 1.0 - exp(-CARD_FOLLOW * delta)
	if _carry != null and is_instance_valid(_carry):
		_carry.position = _carry.position.lerp(_carry_to, k)
	elif _carry != null:
		_carry = null
	if _settle != null and is_instance_valid(_settle):
		_settle.position = _settle.position.lerp(_settle_to, k)
		if _settle.position.distance_to(_settle_to) < 0.5:
			_settle.position = _settle_to
			# Only now does it stop being held, so the armed lift plays from a
			# card that has finished travelling rather than against one that has not.
			_settle.set_held(false)
			_settle = null
	elif _settle != null:
		_settle = null
	if _carry == null and _settle == null:
		set_process(false)

## Put the carried card down: it stops chasing the cursor and slides home with
## everything else.
func _drop_carry() -> void:
	if _carry != null and is_instance_valid(_carry):
		_carry.z_index = 0
		# Still held: releasing it would give it to the layout tween and armed lift at once.
		_settle = _carry
		_settle_to = _carry.position
		set_process(true)
	_carry = null


func commit() -> void:
	_commit()


func _commit() -> void:
	_drop_carry()
	var order := _order_for_layout()
	var cards: Array = []
	for v in order:
		cards.append(v.card)
	_preview_slot = -1
	_drag_card = null
	_views = []
	for v in order:
		_views.append(v)
	reordered.emit(cards)
