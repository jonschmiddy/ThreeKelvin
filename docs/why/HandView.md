The reasoning behind `tkg/scripts/ui/HandView.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hand layout

Above `signal card_hovered(view: CardView, entered: bool)`:

```text
Your hand, laid out by hand rather than by a container.

A container repositions instantly, so playing a card made the rest jump. Here
the views persist between refreshes and tween to their new slots, which is the
difference between the hand reacting to you and the hand being rebuilt at you.

Views are matched to cards by object identity, so a card keeps its view — and
therefore its position — for as long as it stays in hand.
```

## Hand height

Inside `_init()`, above `custom_minimum_size = Vector2(0, CardView.CARD_H + 16)`:

```text
A CARD PLUS ITS PADDING, AND NO MORE. Shrink-centred rather than filling,
so the hand is always exactly this tall however tall the row around it
gets -- which is what stops the cards' eight pixels of air and the draw
pile's height from being the same argument. They were: every time the band
grew for the piles the cards got looser, and every time it shrank for the
cards the piles lost height.
```

Inside `_init()`, above `size_flags_vertical = Control.SIZE_SHRINK_END`:

```text
BOTTOM, not centre. Centred left the cards seven pixels above the line the
DRAW and DISCARD labels sit on, which reads as the hand floating rather
than resting on the same shelf as the rails. Bottom-aligned puts the card
edge exactly on that baseline -- the row is 190, the hand 176, and the pile
label lands at 182, which is 14 + 8 + 160.
```

## Card baseline

Above `func _baseline() -> float:`:

```text
The y a card sits at: centred in whatever height the hand has.

Cards used to be placed at ZERO, and the hand stretches to fill the row -- so
every pixel the row had spare piled up UNDERNEATH them. Measured at 160 of
card inside 184 of hand: nothing above, twenty-four below.

Both placement sites read this rather than assuming a constant, because the
deal-in animation used a hard 12 and the layout used a hard 0, and either left
behind would deal cards to a different height than the hand settles them at.
```

## Hand sync

Above `func sync(cards: Array, playable: Callable, choosing: bool = false,`:

```text
Reconcile against the current hand: keep what is still held, drop what is not,
deal what is new, then slide everything to where it now belongs.
`choosing` puts the hand into picking mode: nothing is playable, every card
is clickable, and a click reports which one rather than playing it.
`live` answers "what does this card throw per hit right now" and `hot` names
which of its clauses are paying -- see `Combat.card_output` and `card_hot`.
```

## Card step

Above `func _step(n: int) -> float:`:

```text
How far apart cards sit, and the only place that decides it.

A full card plus a gap while the hand fits. Once it does not, the step
shrinks until the fan ends exactly at the right edge, so the cards overlap
rather than running off screen — which is the moment a hand stops being a row
and becomes a hand.

Cards are 96 wide on a 640 screen, so five is the last size that fits laid
flat. Six was already 20 pixels over before the card grew taller, and a
deck-thickening affix or a Korvan draw bonus puts you at eight without
trying.
```

## Restack

Inside `_restack()`, above `for v in order:`:

```text
Pushed to the BACK in sequence rather than assigned indices 0..n.

A discarding card is still a child for as long as its fade runs, and this
function only knows about the cards still in hand. Assigning them indices
0..n left every leaver at whatever index it already held — which, after a
few plays, is on top of the live hand. Moving each keeper to the end in
order puts them all above anything not in the list, whatever that is.
```
