The reasoning behind `tkg/scripts/sim/AttrTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Attribute round trip

Above `const ON := {`:

```text
Does a part actually move the gauge its grade promised:
  godot --headless --path . -- attrtest

The attribute ladder says a rare part is worth one pip, an epic two, a
legendary three. `Database._lay_pips` converts that into whatever raw unit
the gauge is kept in — 7 hull, 2 heat capacity, 2 venting — and then
`RunState.attr_*` converts it back. THIS CHECKS THE ROUND TRIP, by bolting
each part onto a bare frame and reading the gauge before and after.

Two ways it goes wrong and neither one throws:

ROUNDING. A pip of venting is 1.5 and the field is an int, so it is stored
as 2 and reads back as 1.3 — which rounds to 1 and is fine, until a formula
is retuned and it rounds to 2. Nothing announces that; the part quietly
becomes worth double its grade.

A CHANGED FORMULA. `PER_PIP` is inverted out of the attr_* functions by hand.
Retuning attr_thermal's divisor and not touching PER_PIP leaves every heat
part off the ladder, silently, on every hull in the game.

Measured against a BARE MEDIUM C, one part at a time. One reference frame is
a definition rather than a discovery: pips are integers and the arithmetic
rounds, so a bump measured from 2 and a bump measured from 7 can legitimately
differ by one. The frame everything is measured against has to be named, and
this is it.
```

## Attribute floor

Above `func _floor() -> void:`:

```text
AN ATTRIBUTE STOPS AT ZERO. It does not go under, and it is not shown as a
negative anywhere.

The arithmetic above zero is plain — four stealth and a flare rack is three,
and that is a real pip the rack costs a stealth build. What this checks is
the bottom: a price on a gauge that is already empty reads 0, not -1, and
not a smaller number than nothing.

Only sensors and stealth could ever have failed it. They are the two summed
straight off the hull and its modules rather than derived from a quantity
that was floored on the way — heat capacity floors at 1, dissipation and
dodge at 0, and nothing had ever been negative on any of them.
```

## Affix checks

Above `func _affixes() -> void:`:

```text
Every affix in the table moves the gauge it advertises, by its pips.

MEASURED THE SAME WAY A PART IS, on a bare medium C with one thing attached,
because the arithmetic rounds and a bump measured from a different starting
value can legitimately differ by one. Reusing the reference frame is what
makes the two comparable.

A negative pip is checked as carefully as a positive one: `Lightened` trades
two of maneuverability for one of hull, and a table where the plus half works
and the minus half silently does not is worse than one that never worked.

STEALTH IS EXCLUDED, and that is a real exception rather than a fudge:
`attr_stealth` subtracts the ship's heat signature, which the reference frame
has, so a stealth pip does not survive to the gauge cleanly. The affix is
still applied -- `_read` would show it on a cold ship -- and the sum it goes
through is the same one every other gauge uses.
```

## Card faces

Above `func _faces() -> void:`:

```text
A card reads the same however the module that granted it rolled.

THE POINT OF THE WHOLE MOVE. Affixes used to write into card fields and
`describe()` prints a clause per non-zero field, so a Slug off a plain module
read "Deal 4 x 2." and the same Slug off a well-rolled one read "Deal 4 x 2.
Draw 1. Vent 2. Heal 2." -- in a box 93 pixels wide, with fit_content on and
no clipping, so the words simply left the card.

Compared against the SAME module with no affixes rather than against a
remembered string, because the expected answer is "whatever this card says
when nothing has touched it" and hard-coding that would need updating every
time a card is retuned.
```

## The augmented line in every box

Above `func _augmented_shown() -> void:`:

```text
THE AUGMENTED LINE IN EVERY BOX THAT DESCRIBES A PART (science, S10): the
hover popup the hold, the hull and the gallery share (`ModuleIcon.tip_for`),
the hull's own tip (`Widgets.module_tip_panel`) and the old list row
(`Widgets.module_row`). A plain copy of the same part says nothing of it,
and a part STRIP has emptied still says it (the mark outlives the affix).

Then a BOX TEST at the worst case the Lab allows: three rolled affixes plus
the augment, the longest texts in the table, on the part with the longest
flavour. Laid out for real (in the tree, the containers sorted until the
wrapped lines settle) and read off the boxes: the tip stays TIP_W wide and the
popup's part panel a card wide, every line inside its panel, no two lines on
top of each other, and both shorter than the 540 px screen.
```

## Laid out for real

Above `func _lay_out(c: Control) -> void:`:

```text
LAID OUT FOR REAL, without waiting for a frame (attrtest runs inside
Main._ready and quits after it). In the tree under an autoload, since the
root is busy readying the main scene, so the labels have the game's font.
Then sized to what it asks for and every container sorted, top down, a few
times over: a wrapped Label's height comes from the width its container just
gave it, so the first pass is never the last.
```

## The corner mark

Above `func _augment_mark() -> void:`:

```text
THE CORNER MARK, drawn only on an augmented part. `ModuleIcon.plate_ink` is
the list `draw_plate` paints over the art (the edge, then the mark), so it is
read here instead of pixels: a plain part inks its four edges and no ICE; an
augmented one adds the wedge, every pixel inside the plate and in its
top-right corner. And for every slot at every footprint up to 3x3, at 1x and
at the hold's 2x, the wedge sits clear of the drawn silhouette.
```

## The mark on a sprite

Above `const MARK_HIDES := 0.05`:

```text
THE MARK ON A SPRITE. A sprite is centred in its box with no PAD margin, and
a few run to the plate's edge (ejector, board, braceframe), so on those the
wedge is painted over the art's corner. That is kept on purpose: the mark is
ink over the art, as the edge is, and its VOID rim is what lets it read there.
What is checked is that it stays a corner: every sprite part, packed either
way, flipped or not, at 1x, 2x and 3x, mapped through `draw_sprite`'s own
placement, and the wedge hides no more than MARK_HIDES of the art drawn.
```
