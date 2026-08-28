class_name HandView
extends Control

## Your hand, laid out by hand rather than by a container.
##
## A container repositions instantly, so playing a card made the rest jump. Here
## the views persist between refreshes and tween to their new slots, which is the
## difference between the hand reacting to you and the hand being rebuilt at you.
##
## Views are matched to cards by object identity, so a card keeps its view — and
## therefore its position — for as long as it stays in hand.

signal card_hovered(view: CardView, entered: bool)
## Carries the finished order, not an index. An index has to be re-based after
## the dragged card is removed, and getting that wrong is what made a drop
## land one slot off and look like it snapped back.
signal reordered(cards: Array)

## A card in the hand was picked to satisfy a discard or a decommission. Separate
## from playing one, because it is a different question with a different answer.
signal picked(card: CardData)

const GAP := 5
const SLIDE := 0.14

var _views: Array[CardView] = []
## Where the dragged card would land. -1 when nothing is being dragged over us.
var _preview_slot: int = -1
var _drag_card: CardData = null
## One live tween per card. Stacking tweens on the same property makes them
## fight, which reads as flicker.
var _tweens: Dictionary = {}

func _init() -> void:
	# The hand accepts drops so a card dragged back here is reordered rather
	# than played. Enemies and your hull are the other drop zones; which one
	# you release over is the whole choice.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# A CARD PLUS ITS PADDING, AND NO MORE. Shrink-centred rather than filling,
	# so the hand is always exactly this tall however tall the row around it
	# gets -- which is what stops the cards' eight pixels of air and the draw
	# pile's height from being the same argument. They were: every time the band
	# grew for the piles the cards got looser, and every time it shrank for the
	# cards the piles lost height.
	custom_minimum_size = Vector2(0, CardView.CARD_H + 16)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clip_contents = false

## The y a card sits at: centred in whatever height the hand has.
##
## Cards used to be placed at ZERO, and the hand stretches to fill the row -- so
## every pixel the row had spare piled up UNDERNEATH them. Measured at 160 of
## card inside 184 of hand: nothing above, twenty-four below.
##
## Both placement sites read this rather than assuming a constant, because the
## deal-in animation used a hard 12 and the layout used a hard 0, and either left
## behind would deal cards to a different height than the hand settles them at.
func _baseline() -> float:
	return maxf(0.0, (size.y - CardView.CARD_H) * 0.5)


## Reconcile against the current hand: keep what is still held, drop what is not,
## deal what is new, then slide everything to where it now belongs.
## `choosing` puts the hand into picking mode: nothing is playable, every card
## is clickable, and a click reports which one rather than playing it.
func sync(cards: Array, playable: Callable, choosing: bool = false) -> void:
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
			found.size = Vector2(CardView.CARD_W, CardView.CARD_H)
			# Dealt from the deck side, so a draw reads as coming from somewhere.
			found.position = Vector2(-CardView.CARD_W, _baseline() + 12.0)
			found.hovered.connect(func(v: CardView, e: bool) -> void:
				# Out of the stack while you are pointing at it. In an
				# overlapping fan the card under the cursor is half-buried by
				# its right-hand neighbour, and the lift alone does not fix
				# that — it moves the card up, not forward.
				if e:
					v.move_to_front()
				else:
					_restack(_views)
				card_hovered.emit(v, e))
		else:
			found.set_playable(playable.call(c))
		found.set_picking(choosing)
		keep.append(found)

	for v in _views:
		if not keep.has(v):
			_discard(v)
	_views = keep
	_layout()

## How far apart cards sit, and the only place that decides it.
##
## A full card plus a gap while the hand fits. Once it does not, the step
## shrinks until the fan ends exactly at the right edge, so the cards overlap
## rather than running off screen — which is the moment a hand stops being a row
## and becomes a hand.
##
## Cards are 96 wide on a 640 screen, so five is the last size that fits laid
## flat. Six was already 20 pixels over before the card grew taller, and a
## deck-thickening affix or a Korvan draw bonus puts you at eight without
## trying.
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
	for i in n:
		var v: CardView = order[i]
		var target := Vector2(x + i * step, _baseline())
		# The card's hover lift springs back to this, and it is the only thing
		# that knows it. Set on every layout, not just on deal, because the
		# baseline moves whenever the band does.
		v.set_base_y(target.y)
		v.size = Vector2(CardView.CARD_W, CardView.CARD_H)
		if v.position.distance_to(target) < 0.5:
			continue
		if _tweens.has(v) and is_instance_valid(_tweens[v]) and _tweens[v].is_valid():
			_tweens[v].kill()
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(v, "position", target, SLIDE)
		_tweens[v] = tw
	_restack(order)

## Left card under, right card over — so an overlapping fan reads as a fan and
## not as a pile. Only matters once the step is smaller than a card, but it
## costs nothing when it is not.
func _restack(order: Array) -> void:
	# Pushed to the BACK in sequence rather than assigned indices 0..n.
	#
	# A discarding card is still a child for as long as its fade runs, and this
	# function only knows about the cards still in hand. Assigning them indices
	# 0..n left every leaver at whatever index it already held — which, after a
	# few plays, is on top of the live hand. Moving each keeper to the end in
	# order puts them all above anything not in the list, whatever that is.
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

## Preview by position rather than by whichever card happens to be under the
## cursor: that card moves as the gap opens, so keying off it makes the target
## slot chase the animation and the row flickers.
func preview_at(x: float, card: CardData) -> void:
	preview(card, _slot_at(x))

func preview_onto(card: CardData, onto: CardView) -> void:
	preview_at(onto.position.x + CardView.CARD_W * 0.5, card)

func clear_preview() -> void:
	if _preview_slot < 0 and _drag_card == null:
		return
	_preview_slot = -1
	_drag_card = null
	_layout()

## Played cards leave rather than vanish, so the eye can follow where they went.
func _discard(v: CardView) -> void:
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

func _can_drop_data(pos: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("card")):
		return false
	preview(data["card"], _slot_at(pos.x))
	return true

func _drop_data(pos: Vector2, data: Variant) -> void:
	preview(data["card"], _slot_at(pos.x))
	_commit()

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

## Dropped straight onto a card: take that card's slot.
func reorder_onto(card: CardData, onto: CardView) -> void:
	preview_onto(card, onto)
	_commit()

## What you see is what you get: hand over exactly the order on screen.
func _commit() -> void:
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
