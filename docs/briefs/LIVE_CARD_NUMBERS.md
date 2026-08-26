# Live card numbers

*Design brief, 2026-08-25. Written offline against `main` as merged (SaveGame VERSION 13,
PROTOCOL 8 at time of writing; **now 14 / 8** — see `ROADMAP.md` §1). Line numbers will move; grep the quoted strings.*

**The ask:** a card's damage number should reflect what it will actually do —
lock-on, salvo, adapt, heat scaling — rather than the number it was printed with.
The real figure should show when the card is over an enemy. And aiming should
stop covering the thing being aimed at.

**The second half already exists.** See §1. The first half is new and is the
subject of this document.

**D2 is ruled** (2026-08-26): hand reorder is **dropped**, which removes the
collision with the targeting line and makes §3a a net deletion in `HandView`.
Nothing in this document is now blocked.

Sibling: `HEAT_REWORK.md` §5, which establishes the rule this follows.

---

## 1. What is already built

`Combat.preview_damage(c, target_index)` (`Combat.gd`:635) already computes the
true figure, and it accounts for everything:

```
damage_equals_heat  -> heat + 2
heat_scale          -> + heat / scale
solari 3-set        -> + 2 on heat-scaling cards
adapt               -> + adapt_bonus
salvo               -> + salvo, when attacks_this_turn > 0
                       (or unconditionally with the korvan 5-set)
lock_on             -> + lock_on
hits                -> per-hit, spending a COPY of the target's
                       block and brace so multi-hit reads correctly
```

`SectorScreen._drag_preview()` (:891-899) already shows it while a card is over
a target — `-12`, or `-12 KILL` when it would finish them.

Its comment is worth reading before touching any of this. That number used to
live as a label under the enemy's health bar, and it read as part of the
enemy's own stat block — *a number that belonged to them and happened to move.*
Showing it only while a card is over a target makes it *the answer to a question
you are asking.* Whatever §3 does, it should not undo that.

**So the real gap is the hand.** Holding five cards, you cannot see which is
biggest without mentally adding lock-on to each. That is the same arithmetic tax
that made per-turn dissipation feel bad.

### Two genuine gaps in the existing preview

`_drag_preview` requires a **drag**. A player who hovers without picking up gets
nothing. Worth deciding whether hover should show it too — see §5.

**And the card is on top of the enemy.** See §3a — this is the bigger of the
two.

---

## 2. Why this is dynamic when the heat pip is not

`HEAT_REWORK.md` §5 rules the vent pip static. The rule it sets is not *card
faces never change* — Slay the Spire prints 0 on cards Corruption has freed and
rewrites damage as Strength moves. The rule is:

> **Print it live when the modifier moves during play. Print it static when it
> holds for the run and can be learned once.**

`dissipation()` is hull plus perk plus installed modules and cannot change
mid-fight, so the vent pip stays static and the gauge teaches it once.

`lock_on`, `salvo`, `adapt_bonus` and `heat` all move **turn to turn, inside a
single fight**. There is nothing to learn once. By the same rule they should be
live. The two decisions are consistent, not contradictory.

---

## 3. The card face

### Show pre-mitigation damage on the face. Post-mitigation belongs to the drag.

This is the load-bearing distinction and it must not be blurred.

`preview_damage` folds in *the target's* block and brace. With several enemies
on the board there is no single right answer for a card sitting in your hand —
the same card reads 12 against one and 4 against another.

- **Card face:** what the card will throw. `per` × `hits`, before anyone's
  mitigation. True regardless of target.
- **Drag preview:** what lands on *that* enemy, after their block and brace.
  Already built, already correct.

So the face needs a new function — call it `Combat.card_output(c)` — that is
`preview_damage`'s `per` calculation with the mitigation loop removed. **Derive
both from one place.** Two copies of that modifier chain is exactly the pattern
`DOC_RECONCILIATION.md` exists to clean up; extract `per` into a helper and have
`preview_damage` call it.

### Multi-hit

`hits` is already displayed structurally on the card. Decide once and apply
everywhere: either the face shows `3 x 4` and the drag shows the post-mitigation
total, or the face shows `12`. Recommend keeping the existing hit structure and
letting the *per-hit* number go live, since that is the figure the modifiers
actually change — lock-on adds to `per`, and on a three-hit card that is worth
three times as much, which the card should be teaching.

### Mark it as modified

A number that silently differs from the printed one is worse than either. Follow
the convention every deckbuilder uses: **live-and-higher renders in the positive
colour, live-and-lower in the negative one, unmodified renders normally.** The
theme already has `UITheme.CHILL` and `COLD` plus the damage red in use around
`CardView`:599-603.

Without that, a player who learned Charged Slug hits for 8 sees a 12 and does
not know whether the card changed or they misremembered.

---

## 3a. The targeting line

**The problem:** aiming means putting the card on top of the thing you are
aiming at. `CardView._get_drag_data()` pins a full-size `CardView` ghost to the
cursor, centred on it — `ghost.position = -Vector2(CARD_W * _s, CARD_H * _s) * 0.5`.
At 112x160 that ghost completely covers the enemy underneath, so at the exact
moment the damage figure appears, the target it applies to is behind the card.

This is worse after §3, not better: the whole point of live numbers is reading
figures during a fight, and the biggest one is hidden under the card that
produced it.

**The fix, as every deckbuilder does it:** the card does not travel to the
target. It lifts a short way out of the hand and stays there, and a line or
arrow runs from it to the cursor. You aim the line, not the card.

### Why this is a rewrite of the drag, not an addition to it

Godot's `set_drag_preview()` pins its argument to the pointer every frame and
offers no way to get it back. A targeting line means the card is **not** on the
pointer, which is the opposite of what that API does. So the card-throw drag
stops being a Godot drag and becomes hand-rolled: press to arm, track the
cursor, release to resolve against whatever is under it.

`ModuleIcon` has already been down this road for the hold, and its notes are the
best thing to read before starting. Two findings carry over:

- **What the engine pins should be a wrapper, not the thing itself.** The plate
  inside is eased toward the cursor in screen space at `FOLLOW := 16.0` e-folds
  per second, which is what makes a drag feel alive rather than welded to the
  mouse. A targeting line wants the same easing on its endpoint, and 16 is a
  measured starting value rather than a guess.
- **Hide the original outright, do not ghost it.** *A half-faded copy reads as a
  rendering fault; an empty slot reads as "you are holding that one."* That
  applies inverted here — the card stays visible and lifted, so it is the
  **hand** that needs to read as having a gap, and the lifted card needs to read
  as armed rather than mid-animation.

Also preserved from the current implementation: picking up a card fires
`hovered.emit(self, false)` explicitly, because Godot sends no `mouse_exited`
when a drag begins and without it the keyword panel *stays open over the board
for the whole drag, covering the enemy you are trying to aim at.* That bug is
the same bug this section is about, found once already. Any rewrite must keep
that behaviour or it comes straight back.

### What it buys beyond visibility

- **Multi-target reading.** With the board unobstructed, `_drag_preview` can
  show the figure over the hovered enemy while the others stay legible, so you
  can compare before committing.
- **The lifted card stays readable.** Under §3 its face is live, so you can see
  the modified damage on the card *and* the post-mitigation result at the target
  simultaneously. Currently those two numbers cannot both be on screen.
- **Self-targeted cards get an honest gesture too** — brace, vent, repair. The
  line points at your own ship rather than the card being dropped on a hull
  panel it covers.

### D2 RULED — hand reorder is dropped

**Ruled 2026-08-26: remove reorder entirely.** A hand that rearranges itself
under you is disorienting, and that is reason enough on its own — but it also
happens to be the cheapest of the three options by a wide margin, and it turns
this section from a conflict into a **net deletion**.

The conflict it resolves: `HandView._init()` says it plainly —

> The hand accepts drops so a card dragged back here is reordered rather than
> played. Enemies and your hull are the other drop zones; **which one you
> release over is the whole choice.**

One press-and-move meant two different things depending on where you released. A
targeting line lifts the card and leaves it in place, so it is never "over" the
hand and there is nothing to drop onto. With reorder gone there is no ambiguity
to resolve and no threshold to tune.

**What comes out of `HandView.gd`:**

- `signal reordered(cards: Array)` (:17) — one listener,
  `SectorScreen.gd`:559 → `_on_hand_reorder`
- `_preview_slot` and `_drag_card` (:28-29) and every branch that reads them
  (:142-175, :233-234)
- `_can_drop_data()` (:198) and `_drop_data()` (:204)
- `reorder_onto()` (:223)
- the hand stops being a Godot drop target at all

That also retires a real piece of scar tissue: `reordered` carries the finished
order rather than an index, because *an index has to be re-based after the
dragged card is removed, and getting that wrong is what made a drop land one slot
off and look like it snapped back.* That whole class of bug leaves with it.

**Releasing over the hand now means cancel** — the card returns to where it was
and nothing resolves. Simpler than the old behaviour and it gives the
hand-rolled gesture its cancel path almost for free.

**Check before deleting:** confirm nothing else drives hand order — a draw
animation, a sort-on-draw, or the co-op board. `reordered` has exactly one
listener, which is a good sign, but grep `_on_hand_reorder` and whatever it
touches before pulling the signal.

### Scope: `EncounterView` moves too

`show_enemies(list, on_drop, on_hover)` connects `slot.card_dropped` and
`slot.hovered` per enemy (:381-396), and `bind_self_drop()` does the same for
your own ship (:377-379). **Those are Godot drop targets.** Hand-rolling the
gesture means `SectorScreen` hit-tests what is under the cursor at release
itself, and both files change.

The `MOUSE_FILTER_IGNORE` tuning that lets a card drop *through* the party
column (:326-329) exists for Godot's drop propagation and does not transfer —
a hand-rolled hit test has to reproduce that behaviour deliberately: the column
is not a target, the arena behind it is.

Carry across by hand, none of which comes free once you leave Godot's drag:

- the `picking` guard — no throwing while a discard or decommission choice is
  open, *because dragging one card onto an enemy while another is waiting to be
  picked resolves two cards in an order neither stated*
- `hovered.emit(self, false)` on arm — see above
- cancel, which Godot currently provides for nothing

### Open

- **Where the number goes.** On the target, at the line's end, or near the
  cursor. Recommend at the target: `_drag_preview`'s comment argues the figure
  reads correctly *because* it is the answer to a question you are asking, and
  the line makes the question visible.
- **Click-to-arm versus press-and-hold.** Hold matches the current gesture and
  needs no new mental model. Click-arm-click is steadier for precise aiming and
  is what several deckbuilders moved to. Either works; do not support both. *No
  longer interacts with reorder — that is settled.*

### Cost, honestly

**This will work.** The line itself is trivial — `draw_polyline` on a Control
that already has a `_draw()`. Press-track-release is ordinary `_gui_input`. And
`ModuleIcon` proves this codebase can already do eased hand-rolled pointer
following well, with `FOLLOW := 16.0` available to borrow rather than guess.

What makes it large is everything around it: a two-to-three file refactor of the
combat input layer and three behaviours that must be reimplemented by hand
because they currently come from the engine. **Still the largest single item in
this document** — but with D2 ruled it is smaller than it was, because
`HandView` loses code rather than gaining a disambiguation rule, and cancel
falls out of "release over the hand" nearly for free.

---

## 4. Combat only

`CardView` is shared. `CardGalleryScreen` (:191, :259) and `ChassisSelect`
(:688) both build one, and there is no combat there to read.

**Live numbers are a combat-only mode.** Everywhere else the face prints the
base, because outside a fight the question is *what is this card* — you are
comparing it against another card in a shop or a loot screen, and a number
inflated by a lock-on you happen to be holding is the wrong answer.

`CardView.setup(c, can_play, scale_step)` gains a live-context argument, or
reads a mode flag. Default off. **Gallery and chassis select must not change.**

---

## 5. Open

- **Hover as well as drag.** `_drag_preview` needs the card picked up. Cheap to
  extend to hover, and it makes the feature discoverable — but the existing
  comment argues the number reads as an answer *because* you are actively
  pointing the card at something. Hovering may be enough of a question; it may
  also put a number under the cursor every time it crosses the board. Try it
  before ruling.
- **Redraw triggers.** The face must refresh on lock-on gained, on the first
  attack of a turn (`salvo_ok` flips when `attacks_this_turn > 0`), on heat
  change, and on `adapt_bonus` change. A hand is five to seven `CardView`s and
  `_draw()` is a full repaint of a 112x160 pixel-art face. Measure it before
  wiring it to every signal; if it is heavy, refresh on a single
  `combat_state_changed` rather than four separate hooks.
- **Salvo flipping mid-turn is a feature, not a glitch.** Your first attack
  changes what every salvo card in hand reads. That teaches the mechanic better
  than any tooltip — but it is a hand-wide visual change triggered by an
  unrelated action, so it wants to be legible rather than startling. Worth
  watching on screen.
- **`BotBoard.gd`:130** already sends `damage_now` from `preview_damage` for the
  co-op board. If the `per` calculation is extracted per §3, check whether the
  bot board wants the pre- or post-mitigation figure. It currently gets
  post-mitigation against the default target.
- **No version bumps.** Display only. Nothing serialised, nothing on the wire.

---

## 6. Ordering

Independent of `GALAXY_SCALE.md` and `ENCOUNTER_REBUILD.md` — different files
entirely.

Land it **after** `HEAT_REWORK.md`. That brief already rewrites three
player-facing strings about heat, and `heat_scale` and `damage_equals_heat` are
two of the modifiers this feature displays. Doing heat first means the numbers
being made live are the final ones.
