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
## A card in this hand was pressed. Forwarded rather than handled: what the
## press becomes is the screen's business, not the hand's.
signal card_grabbed(view: CardView, at: Vector2)

const GAP := 5
const SLIDE := 0.14

var _views: Array[CardView] = []
## Where the dragged card would land. -1 when nothing is being dragged over us.
var _preview_slot: int = -1
var _drag_card: CardData = null
## One live tween per card. Stacking tweens on the same property makes them
## fight, which reads as flicker.
var _tweens: Dictionary = {}

## E-folds per second the held card closes on the cursor. Lower than
## `ItemIcon.FOLLOW`'s 16 on purpose: a card is a big object and the weight is
## the point -- it should feel carried rather than stuck to the pointer.
const CARD_FOLLOW := 9.0
## The card being carried, and where it is heading. While this is set the card
## is driven per frame by `_process` and NOT tweened into its slot by `_layout`:
## a tween to a slot and a lerp to the cursor fight, and the tween wins on the
## frame it is created, which is what made the drag snap.
var _carry: CardView = null
var _carry_to: Vector2 = Vector2.ZERO
## And the card that has just been let go, still travelling. A tween would do it
## in SLIDE seconds from ANY distance, so a card released a hundred pixels out of
## the fan appears to teleport back into it. Driven by the same follow as the
## carry, it decelerates into place and reads as the same object being set down.
var _settle: CardView = null
var _settle_to: Vector2 = Vector2.ZERO

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
	# BOTTOM, not centre. Centred left the cards seven pixels above the line the
	# DRAW and DISCARD labels sit on, which reads as the hand floating rather
	# than resting on the same shelf as the rails. Bottom-aligned puts the card
	# edge exactly on that baseline -- the row is 190, the hand 176, and the pile
	# label lands at 182, which is 14 + 8 + 160.
	size_flags_vertical = Control.SIZE_SHRINK_END
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
## `live` answers "what does this card throw per hit right now" and `hot` names
## which of its clauses are paying -- see `Combat.card_output` and `card_hot`.
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
			found.grabbed.connect(func(v: CardView, p: Vector2) -> void:
				card_grabbed.emit(v, p))
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
		# AFTER the branch, so it reaches kept cards as well as new ones. `sync`
		# only calls `setup` for a card it has not seen, and every modifier this
		# figure depends on -- lock-on, salvo, adapt, heat -- moves while the
		# card sits in your hand untouched. Refreshing only new views would mean
		# the number went live for exactly the cards that had just been drawn.
		found.set_live(live.call(c) if live.is_valid() else -1,
			hot.call(c) if hot.is_valid() else PackedStringArray())
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
	var carried := _carry != null
	_drop_carry()
	if _preview_slot < 0 and _drag_card == null and not carried:
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

## NO DROP HANDLERS. The hand used to accept a Godot drop so a card dragged
## back over it was reordered rather than played; there is no Godot drag to
## accept any more. `SectorScreen` drives `slide_to` and `commit` directly, and
## releasing over the hand is simply releasing over nothing aimable.


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


## Drive the reorder from a gesture this view does not own. `preview_at` and
## `_commit` were reachable only through Godot's drop before, which is why hand
## reorder died with the drag -- the machinery survived, its only caller did not.
func slide_to(at_global: Vector2, card: CardData) -> void:
	var v := _view_of(card)
	if v == null:
		return
	# CLAIMED BEFORE THE LAYOUT, not after. `preview_at` runs `_layout`, and a
	# layout that does not yet know the card is carried starts a 0.14s tween to
	# its slot -- which then fights the follow. That tween is what threw the card
	# sideways on the first frame of every drag before settling on the cursor.
	if _carry != v:
		# Caught on its way home and picked straight back up: it is the carry's
		# again, and leaving it in `_settle` would have both driving the same
		# position every frame.
		if _settle == v:
			_settle = null
		_carry = v
		v.set_held(true)
		# Above its neighbours for as long as it is held. z_index rather than
		# child order, because `_restack` rewrites child order on every layout
		# and would drop it back into the fan.
		v.z_index = 1
		if _tweens.has(v) and is_instance_valid(_tweens[v]) and _tweens[v].is_valid():
			_tweens[v].kill()
		set_process(true)
	# Centred on the pointer: `position` is the top-left corner. The vertical is
	# CLAMPED INTO THE DRAWER -- a reorder is a horizontal gesture, and letting
	# the card climb out of the fan with the cursor is how it ended up wrestling
	# the layout for a place to be.
	var want := at_global - global_position 		- Vector2(CardView.CARD_W, CardView.CARD_H) * 0.5
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
		# STILL HELD, on purpose. It stays the hand's to move until it has
		# arrived; releasing it here would hand it to `_layout`'s tween and to
		# the armed lift at the same moment, from a hundred pixels away, and the
		# two would fight over it in front of you.
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
