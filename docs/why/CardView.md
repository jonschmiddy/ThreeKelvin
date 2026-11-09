The reasoning behind `tkg/scripts/ui/CardView.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Card scale and corners

Above `signal chosen(view: CardView)`:

```text
One card, at one of exactly two scales.

The layout is a fixed zone map in HAND-SCALE pixels, multiplied by _s. Inspect
is an exact 2x of hand, which is the whole reason the numbers below are the
numbers below: card furniture is drawn once on a true pixel grid and doubles
with no artifacts, while vector text re-renders at each scale and does not
care. Any size between the two would put the frame on half-pixels.

96x130 is not a preference either. The native resolution is 640x360, a hand
is five cards, and 5 x 96 + gaps fits across it. The previous 132 did not:
five of those is 660px on a 640px screen, so the hand was already wider than
the game before anything was drawn.

CORNER GRAMMAR IS STRICT: one corner, one meaning. Energy top-left is what you
pay; heat top-right is what playing it leaves behind. Anything that triggers
on draw, in hand, or at end of turn lives in the TEXT BOX and never in a
corner. The mirrored corners are the tutorial — every card silently teaches
"this is the cost, this is the byproduct".
```

## Grab gesture

Above `signal grabbed(view: CardView, at: Vector2)`:

```text
Pressed in a hand. What that TURNS INTO is not decided here and cannot be:
sideways is a reorder and up-and-out is a shot, and which one you meant is
only knowable once the pointer moves. The screen owns that decision.
WITH THE POINT IT HAPPENED AT, rather than leaving the screen to ask where
the mouse is. `get_global_mouse_position()` reports the OS cursor, which is
not necessarily where this event was: a pushed event does not move it at
all, and the gesture's whole decision is a delta from the press.
```

Inside `_on_input()`, above `hovered.emit(self, false)`:

```text
Picking it up ends the hover. Godot sends no `mouse_exited` when a press
turns into a gesture -- the cursor never technically leaves -- and without
this the keyword panel stayed open over the board for the whole drag,
covering the enemy being aimed at. That bug is the one this whole section
exists to fix, found once already; it must not come back through the door
the fix opened.
```

Above `func _notification(what: int) -> void:`:

```text
NO `_get_drag_data` ANY MORE. A card is never handed to Godot's drag.

`set_drag_preview` pins its argument to the pointer every frame and offers no
way to get it back, which is the exact opposite of what aiming needs: the
card must STAY where it is while a line does the pointing. So the gesture is
hand-rolled -- press to grab (`grabbed`), the screen decides whether that
became a reorder or a shot, release resolves it.

What went with it: a full-size ghost pinned to the cursor that covered the
enemy underneath at exactly the moment the damage figure appeared. See
`SectorScreen._on_card_grabbed`.
```

## Card size

Above `const CARD_W := 112`:

```text
Hand scale. Named CARD_W/CARD_H because the hand layout has always called
them that.
112, and every pixel of the increase goes to the content column — the banner
is unchanged at 13. Five cards at 112 plus gaps is 580 of a 640 screen, so
the width that mattered when this was frozen at 96 still holds.
```

Above `const CARD_H := 160`:

```text
160, not 130. The art window was thirty pixels of a card whose whole selling
point is a pixel-art module sprite; doubling it to sixty gives the picture
room to be the reason you look at the card. The width is untouched, because
width is the constrained axis — five cards at 96 is 480 of a 640 screen, and
nothing about a taller card changes that. Height is the axis with slack.
```

## Zone map

Above `const Z_BANNER := Rect2(2, 1, 13, 158)      ## the manufacturer, full height, left edge`:

```text
The zone map, in hand-scale pixels. Everything below multiplies by _s.

The name sits directly under the cost gems and above the art. Reading order
is then cost -> name -> picture, which is the order you actually use a hand
in: what it costs decides whether you read on at all. It also puts the two
things that survive at 96px — the number and the verb — in the top third,
which is the only part of a card you can sequence a turn from.
Thirteen wide, inset by one, and ODD on purpose.

Odd is load-bearing: the marks must centre in it, so the leftover either side
has to split evenly. An even width has no middle pixel at all, which is the
half-pixel that made every emblem read off-centre when this started.

Thirteen leaves a field of eleven inside the border, for a mark of nine — a
pixel of manufacturer colour showing either side of its own emblem. Seventeen was
about a fifth of the card given to one flat block of colour; eleven made the
marks so narrow they had to stretch vertically to stay legible, which is its
own kind of wrong. Nine across and nine tall is the size at which these
shapes are square.
```

Above `const Z_NAME := Rect2(16, 18, 93, 22)       ## the verb`:

```text
Two lines. "Suppressing Fire" is sixteen characters and ran off the right
edge of the card on one — and a verb pool full of two-word names means that
is the common case, not the exception. Wrapping costs the art four pixels
and buys every name in the game room to be itself.
```

## Type line zone

Above `const Z_TYPE := Rect2(16, 106, 93, 11)       ## type + lane`:

```text
Eleven, not nine. An 8px font is not 8px tall once Godot adds its leading,
so a nine-pixel zone let ATTACK render down into the first line of the text
box and the two printed on top of each other. Zones have to be sized for
what the font DOES, not for what its point size is called.
Tucked under the art, left-aligned, like a caption on a plate.

It was centred in the gutter between the picture and the rules, on the idea
that it belonged to neither. It reads better belonging to the ART: the
picture and the word under it are one statement — here is the thing, here is
what kind of thing it is — and the effect text is a separate paragraph
below. Centred and floating, it looked like a heading for the rules, which
it is not.

Placed from the INK, not from the box. Measured: Silkscreen at 8px is 11
tall with an ascent of 9 and a descent of 2, so a line of caps paints rows 2
through 9 of its box and leaves the bottom two empty. Every gap set by eye
came out lopsided because of those two pixels. Art ends at 102, type ink lands at
108, text ink at 121 — six pixels of clearance either side, ink to ink.
```

## Live output

Above `var live_output: int = -1`:

```text
What this card throws per hit right now, or -1 for "print what it says".

COMBAT ONLY, and it is a push rather than a lookup on purpose. `CardGallery`
and `ChassisSelect` build `CardView`s too and there is no fight behind them;
leaving the default at -1 means they cannot accidentally acquire live numbers
by existing. Nothing has to know about a mode flag -- the hand pushes a figure
in, and everywhere else simply never does.
```

## Name and rarity

Inside `setup()`, above `var nm := UITheme.body(c.name, ModuleData.rarity_ink(c.source_rarity),`:

```text
Name is on the card at BOTH scales. Effect text is not: it is unreadable
at 96px and pretending otherwise costs the room the art needs. Cards have
to be sortable from the top third alone; the text is confirmation you go
looking for, not discovery.
The NAME carries rarity.

It is the one string on the card at both scales, so colouring it costs
nothing and reaches everywhere — and it puts "how good is this" on the
same glance as "what is it", which is the pair you sort a hand by.
```

## Effect text

Inside `setup()`, above `var body := RichTextLabel.new()`:

```text
Effect text at BOTH scales.

card-design says "effect text is unreadable at hand scale, full stop" and
that turns out to be untrue for this game specifically: 8px Silkscreen is
the body font of the entire UI — the HUD, every panel, the name and type
line on this very card — so if it were unreadable at 96px the game would
already be unreadable everywhere. The rule was written for a card that
had no room; this zone map gave the text box the provenance row and it now
holds about sixty characters, which covers every card in the catalog.

It also removes a real inconsistency: the text plate was being DRAWN at
both scales and filled at one, so a hand-scale card carried an empty
recessed panel where its rules should be.
Rich text, so the words that have rules behind them can say so.

Underlined and lifted to ICE: two channels, because colour alone fails a
colourblind reader and an underline alone is easy to miss at 8px. It marks
exactly the terms this card's own keywords() can explain, so a word is
only ever underlined where there is something to look up.
```

## Native tooltip

Above `func _make_custom_tooltip(_for_text: String) -> Object:`:

```text
The full readout, as a native tooltip.

OPT-IN: Godot only asks for a tooltip when tooltip_text is non-empty, and
nothing sets that by default. The hand and the gallery build their own
readouts with their own timing and placement — a second one appearing under
the cursor would be two panels saying the same thing — so they leave it
alone and get no tooltip. Anywhere a card is just sitting there being looked
at, setting tooltip_text is enough.

Same Widgets.card_readout() the other two use, so the three cannot drift.
```

Inside `_make_custom_tooltip()`, above `if get_parent() is HandView:`:

```text
Never in a hand, whatever anybody set on the card. The hand builds this
same panel itself, on its own delay and above the fan where it cannot
cover the board, and a native tooltip would be a second copy of it
floating at the cursor. The rule above says the hand opts out by leaving
tooltip_text empty; this is the rule enforced where it can be broken by
accident rather than only stated where it can be read.
```

## Malfunction banner

Inside `_draw()`, above `_junk_banner()`:

```text
A MALFUNCTION GETS A BANNER TOO -- in its own ink, and with no mark on
it. Leaving the left edge BARE was one of the four junk signals, and it
was the one signal made of an ABSENCE: in a fan every other card had a
coloured column down its side and this had a hole where one should be,
which reads as a card that failed to finish drawing rather than as a
card that belongs to nobody.

The other three still carry the weight -- the #1a1418 frame, the grey
MALFUNCTION type line, and a keyword underlined without being useful --
and this now says the same thing in the positive: every card has a
column, and the colour of yours is the colour this game paints damage.
```

Inside `_junk_banner()`, above `var cx := b.position.x + b.size.x * 0.5`:

```text
THE MARK: A BREAK, on the line the manufacturer emblems sit on.

Two bars offset with a gap between them, which is the same figure the
station's SYSTEM REPAIR row wears -- the thing that is wrong, and the thing
that fixes it, drawn once. It goes at the emblem's own height so a fan of
eight lines up along the top whatever is in it.
```

## Malfunction art

Inside `_draw()`, above `if not _draw_art(art):`:

```text
NO HATCH OVER THE ART WINDOW. It used to draw INSTEAD of the picture, which
was invisible while nothing had art and blanked all sixteen malfunctions
the moment they had some; drawing it on top instead still ate them -- at
half alpha Dross lost its stencils and Arc Fault was almost solid stripes.

So the window is left alone and dead weight is carried by everything else
the card already does: the frame goes to #1a1418, there is no manufacturer
banner down the left edge, the type line reads MALFUNCTION in grey, and the
rules text is the only place a keyword is underlined without being useful.
That is enough to sort a fan of eight without reading, which was the job.
```

## Recessed plates

Inside `_draw()`, above `_plate(_z(Z_NAME))`:

```text
Recessed plates at BOTH scales, including the ones that only hold text at
inspect. The furniture is one layout drawn once and doubled — that is the
whole reason the two sizes are an exact 2x — so hiding a plate at hand
scale does not save anything, it just leaves a hole where a panel should
be. An empty plate reads as a card with a quiet lower half; an empty
rectangle of background reads as a card that failed to finish drawing.
```

## Rarity and provenance

Inside `_draw()`, above `func _junk_banner() -> void:`:

```text
No rarity swatch and no provenance row. Rarity is the colour of the name
(see setup) and the module is named in the readout beside the card, which
between them cost zero pixels and freed a whole row for effect text.

The tradeoff worth knowing about: card-design calls the provenance footer
load-bearing under the verb model, because the name bar carries the VERB
and the footer was the only thing identifying the module — and mid-run
scrap decisions get made while looking at a hand. The rarity colour keeps
most of that answer on the card; the exact module now needs the readout.
```

## Manufacturer banner

Above `func _junk_banner() -> void:`:

```text
The manufacturer banner: a field, a mark, and a cut.

A 2px accent stripe carried the manufacturer colour and nothing else — manufacturer as a
legal requirement rather than as identity. A banner is the emblem's largest
habitat, and at 13px wide it still has room for the three things that
distinguish a manufacturer at a glance: the ground it flies on, the mark it carries,
and the shape of its own bottom edge.

The cut is doing real work, not decoration. It is the one manufacturer channel that
survives with no colour at all — Korvan ends square because decoration is for
people whose guns jam; Redline ends torn because salvage does not finish
edges; Verity ends in a swallowtail because it can afford to.
The malfunction's own banner: a field and a cut, and no emblem.

NO MARK, because there is nobody to mark it with. A malfunction is not built
by anyone -- it is what a fight did to your ship -- so a manufacturer emblem
would be inventing an allegiance for a thing that has none. The field and the
cut are enough to make it a column rather than a gap.
```

## Emblem centring

Inside `_banner()`, above `_emblem(Vector2(b.position.x + b.size.x * 0.5,`:

```text
Centred on the energy gem's row, not on the banner's own.

Z_ENERGY runs y 3 to 16, so a centre of 9 puts the tallest marks — Solari's
rays, Calyx's cross — at exactly 3 to 16 as well. The manufacturer and the cost
then share one horizontal line across the top of the card, which is the
line the eye starts on.
Centre taken FROM the banner, not written next to it.

It was a hardcoded 9 while the flag's real centre is 9.5 — measured, not
guessed — so every mark sat half a pixel left, which at 1x rounds to a
whole one. Two numbers that must agree should never be two numbers.

Vertically it lines up with the energy gem rather than the flag: the manufacturer
and the cost then share the top line of the card, which is where the eye
starts.
```

Above `func _emblem(c: Vector2, mark: Color, field: Color) -> void:`:

```text
`c` is the flag's true centre, and every offset below is measured from it as
a HALF — -6.5 with a width of 13, not -6 with a width of 13. That is what
straddling a centre actually looks like: an odd-width mark has to start half
its width to the left, and half of 13 is 6.5. Writing whole numbers there put
every emblem half a pixel off, in the same direction, on all seven manufacturers.
```

## Banner outline

Inside `_banner()`, above `var edge := mark.darkened(0.3)`:

```text
EVERY banner is outlined, and the outline goes on LAST.

It started as a light-field rule — Verity and Calyx bleed into the card
without one. But two manufacturers fly fields that are the card's own colour:
Redline's charcoal is #1c2127 against a #161f2c panel, and Cygnet's
#16202e is nearer still. Those banners had no edge at all, so their hems
were carving shapes out of a flag whose outline you could not see, and the
bottom of the flag simply merged into the card.

In the manufacturer's own mark, dimmed: it reads on a dark field and stays quiet
on a bright one. Last, because a frame drawn before its contents is not a
frame — underneath the hem it lost exactly the edge this is for.
Four filled rects, not draw_rect's outline mode.

An unfilled draw_rect strokes the boundary rather than the pixels inside
it, so at 1px the stroke straddles the edge and rounds inward on one side
and outward on the other. That is a one-pixel asymmetry applied to the
frame every emblem is judged against — measured, the mark sat dead centre
and still read a pixel right, because the border had quietly eaten the
right margin and not the left. Explicit rects land where they are told.
```

## Banner hems

Above `static func draw_cut(ci: CanvasItem, manufacturer: StringName, b: Rect2, mark: Color,`:

```text
The seven hems, drawn onto any canvas at any scale.

Static and free of the card for the same reason draw_emblem is: the chassis
select flies these banners too, at four times the size. The offsets are
hand-authored — a hem is the one part of this card designed by eye rather
than derived — so a second copy would be a second set of numbers to get
wrong.

`back` is whatever the banner is sitting ON. Most of these shapes are CUT,
by painting the background back over the flag, so passing the wrong colour
does not misdraw the hem — it makes the hem invisible.
```

Inside `draw_cut()`, above `hem.call(Rect2(b.position.x, base - 2 * s, b.size.x, 2.0 * s), mark)`:

```text
A torn hem, DRAWN rather than carved. Every other manufacturer cuts its
shape by painting the card back over the flag, which relies on the
field differing from the card — and Redline's #1c2127 against a
#161f2c panel IS the card. A subtraction needs two colours to
subtract between, so this one goes on as a positive.

TWO THREADS PULLED LONG, and the rest of the edge holding. The
first version ran its strips up to SIXTEEN units on a twenty-two
unit flag, which put them at unit 11 -- where the emblem sits.
Redline's mark is two bars in the mark colour, and two bars on a
column of the mark colour are nothing: the hem ate the mark, on
every card the manufacturer flies. Nothing here goes above eight.
```

## Emblems

Above `static func draw_emblem(ci: CanvasItem, manufacturer: StringName, c: Vector2, s: float,`:

```text
The seven marks, drawn onto any canvas at any scale.

Static and free of the card because the ship tab flies these too: a hull is
built by a manufacturer now, and its header wears the same emblem as the
cards that manufacturer grants. Two copies of these offsets would be two
copies to fix the next time one is half a pixel out — which has already
happened once, to all seven at the same time.
```

Inside `draw_emblem()`, above `r.call(Vector2(-4.5, -5), Vector2(9, 2), mark)`:

```text
Three descending armour slabs. Armour as heraldry.
Pitch 4: two of bar, two of gap, three times over. The bars were
at -4.5, -1 and 2.5, which put 1.5 pixels between them — and half
a pixel of gap does not exist, so one rendered as 1 and the other
as 2. Whole numbers or the spacing is decided by the rasteriser.
```

Inside `draw_emblem()`, above `r.call(Vector2(-0.5, -4.5), Vector2(1, 9), mark)`:

```text
Sun disc, four cardinal rays.

THREE RECTS, NOT FIVE, and not one pixel different. The rays were
drawn as four stubs off the disc, which is how you would describe
the mark -- but opposite stubs are collinear and touch it, so a bar
straight through does the same job twice. Checked by painting both
and comparing: identical. The build plan budgets four primitives an
emblem and this was the only one over it that could come down
without becoming a different mark.
```

## Card art

Above `func _draw_art(where: Rect2) -> bool:`:

```text
THE CARD'S OWN ILLUSTRATION, if one exists. False means there is none and the
drawn glyph should take the window instead.

AT WHOLE MULTIPLES ONLY. The illustration is authored at the window's own
size, so hand scale draws it 1:1 and inspect draws it at exactly 2 — the same
reason the two card sizes are an exact 2x and not a comfortable 1.8. Anything
else resamples pixel art onto a grid it was not drawn for, which is the one
thing the art direction refuses outright.

Centred rather than stretched when the file is not the size it should be. A
wrong-sized asset is a mistake to SEE, and `-- artcheck` names it; silently
scaling it to fit would hide exactly the mistake that check exists to catch.
```

## Type glyphs

Above `func _type_glyph() -> void:`:

```text
What the module looks like, until there is a module sprite to show.

The art window is the largest thing on the card and every module currently
ships without a sprite, so it would otherwise be the largest thing on the
card showing nothing. The doc requires a card be sortable from its top third
alone, and a black rectangle sorts nothing.

Shape rather than colour, because colour is the manufacturer channel and the
two must never share an encoding — these silhouettes work identically for a
colourblind player. Drawn from rects on the pixel grid so they double cleanly
into inspect.
```

Inside `_type_glyph()`, above `var n := clampi(card.hits, 2, 4)`:

```text
THE SAME ROUND, SEVERAL TIMES, and this is the split that does the
most work in the whole set: "Deal 2 x 5" is a stream and "Deal 40"
is a hammer, and until now they were one picture.

Drawn to the ACTUAL hit count up to four, then smaller, so a player
can count them off a 96px thumbnail. Past four it stops counting and
starts meaning "a lot", which is the honest reading of Deal 2 x 5
anyway — nobody counts five rounds, they see a stream.
```

Inside `_type_glyph()`, above `_r(c + Vector2(-20, -19) * s, Vector2(13, 38) * s, ink)`:

```text
A wall that shoots back, drawn as a wall and THE ATTACK GLYPH'S OWN
ROUND leaving it. Reusing the round rather than inventing a spark is
the whole point: feedback is defence that deals damage, and the
picture should be made of the two things it is made of.

Leaving to the RIGHT, with the rest of the attack family, because
right is where this card's damage goes.
```

Inside `_type_glyph()`, above `var arm := Vector2(11, 3)`:

```text
A reticle closing on something. The only glyph that is about the
NEXT card rather than this one.
Written out, not looped. An L has a handedness and there are four
of them — see ModuleIcon._glyph (since deleted), where the derived version
read as four unrelated ticks.
```

## Heat text

Above `func _heat_text() -> String:`:

```text
ALWAYS printed, even at zero.

A zero-heat attack is a chase property — the whole point of a cold build is
that it can keep swinging — and a stat you cannot see is a stat you cannot
chase. Vent cards print the same number running backwards, which teaches that
heat is bidirectional using the corner that already exists rather than a new
one.
```

## Hover lift

Above `func set_base_y(y: float) -> void:`:

```text
Where the hover lift returns to.

`_ready` CANNOT KNOW THIS. It fires on `add_child`, and the hand sets the
card's position on the line after -- so the value captured there is always
zero, and every hovered card animated to the top of the hand rather than back
to where it was sitting. Invisible while the cards rested at zero anyway;
the moment they were centred, hovering one threw it eight pixels upward.

The hand owns layout, so the hand owns this. See `HandView._layout`.
```

Above `func _animate_lift(offset: float) -> void:`:

```text
Only in a hand.

The lift is a claim about PLAYABILITY — "this one, now" — which is a fact
about a hand and meaningless in a catalog. It also cannot work anywhere else:
it animates position.y back to a rest value captured at _ready(), before any
container has laid the card out, so inside a flow container every hovered
card slid up to y=0 and the gallery stacked itself into its own first row.

Gated on the parent rather than on a flag the caller has to remember, because
the rule is not "the gallery is special" — it is "position is the hand's to
own, and nothing else may fight its container for it".
```

## Picking

Above `var picking: bool = false`:

```text
PICKING, not playing. A card is played by dragging it onto a target — your
hull for defence and utility, an enemy for anything that hits — and
click-to-play would quietly choose a target for you, which is the decision the
drag exists to make.

A click means something only while a card has asked you to pick some of your
hand. There is no target to guess at then: the question is which card, and
pointing at it is the whole answer.
```

## Armed card

Above `var armed: bool = false`:

```text
ARMED: lifted out of the hand and held there while a line does the aiming.

`_animate_lift` is the hand's own hover lift and this borrows it, so an armed
card sits where a hovered one would and a little higher. It also has to WIN
against hover: the pointer leaves the card the instant you start aiming, and
an unguarded `_on_hover_out` would drop it back into the fan mid-gesture.
```

## Word under the pointer

Above `func word_at(p: Vector2) -> String:`:

```text
STRIPPED-DOWN UI T2 (Jon, Nov 9): each keyword on the card is its own
hover target. The first build wrapped each term in [url] and listened to
RichTextLabel's meta_hover_started; a pointer pushed over the hand in a
window reached the label (its gui_input saw every motion) and the signal
never fired, and headless the label keeps no hover at all. So the body's
motions are measured here instead: a TextParagraph shaped as the body is
(the same face, size and width, no line separation) answers which character
is under the point, and the keyword whose span holds that character is the
word. The [url] markup stays, as the harness and the hints read it as "a
word that can be pointed at".
```
