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
	custom_minimum_size = Vector2(0, CardView.CARD_H + 4)
	clip_contents = false

## Reconcile against the current hand: keep what is still held, drop what is not,
## deal what is new, then slide everything to where it now belongs.
func sync(cards: Array, playable: Callable) -> void:
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
			found.size = Vector2(CardView.CARD_W, CardView.CARD_H)
			# Dealt from the deck side, so a draw reads as coming from somewhere.
			found.position = Vector2(-CardView.CARD_W, 12)
			found.hovered.connect(func(v, e): card_hovered.emit(v, e))
		else:
			found.set_playable(playable.call(c))
		keep.append(found)

	for v in _views:
		if not keep.has(v):
			_discard(v)
	_views = keep
	_layout()

func _layout() -> void:
	var order := _order_for_layout()
	var n := order.size()
	if n == 0:
		return
	var span := n * CardView.CARD_W + (n - 1) * GAP
	var x := (size.x - span) * 0.5
	for i in n:
		var v: CardView = order[i]
		var target := Vector2(x + i * (CardView.CARD_W + GAP), 0)
		v.size = Vector2(CardView.CARD_W, CardView.CARD_H)
		if v.position.distance_to(target) < 0.5:
			continue
		if _tweens.has(v) and is_instance_valid(_tweens[v]) and _tweens[v].is_valid():
			_tweens[v].kill()
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(v, "position", target, SLIDE)
		_tweens[v] = tw

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
	var span := n * CardView.CARD_W + (n - 1) * GAP
	var start := (size.x - span) * 0.5
	var slot := int(round((x - start) / float(CardView.CARD_W + GAP)))
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
