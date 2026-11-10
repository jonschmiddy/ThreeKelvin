The reasoning behind `tkg/scripts/ui/ModuleIcon.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Module icon

Above `const SIZE := 44`:

```text
A module as a thing you can pick up.

Inventory-grid icon, in the vein of Arc Raiders or Marathon: a plate in the
manufacturer's field colour, a rarity edge, and a glyph saying what the part
DOES. Three channels, three questions — whose is it, how good is it, what is
it for — and none of them requires reading a word.

The glyph comes from the module's own first card via CardData.glyph_kind(),
which is the same classification the card face draws its art from. So a
weapon that fires and a weapon that charges look different here for exactly
the reason they look different in your hand, and neither is a second opinion
about what the module is.
```

## Plate ground

Above `const GROUND := 0.82`:

```text
How far a rarity colour is dragged toward the void to make a plate's ground.

MEASURED, not picked, and PULLED BACK FROM 0.88 because the measurement was
answering only half the question. The half it had was legibility: the art on
the ground is the manufacturer's own colour, so all 56 manufacturer-by-rarity
pairings have to clear 3.0:1, and Verity's dark gold on a green ground is the
one that binds. `-- holdtest` still holds that line and it is still the line a
new manufacturer colour breaks first.

THE HALF IT DID NOT HAVE is whether the grades can be told apart AT ALL. A
grade is read off a 30-pixel plate, and 0.88 leaves about a tenth of the
colour — which crushed eight grades into a band 22 CIELAB units wide, where
the closest pair sat at 2.5 against a just-noticeable difference of 2.3. Two
grades were, to an eye, one grade. Nobody reported the pair that was actually
worst (Uncommon and Exotic), because the NAMES are written in the colour at
full strength and the names were fine.

Both numbers, swept:

    0.88   closest plates 4.6   Verity on Uncommon 3.56
    0.82   closest plates 6.3   Verity on Uncommon 3.16
    0.80   closest plates 7.4   Verity on Uncommon 3.03
    0.76   closest plates 8.7   Verity on Uncommon 2.77  refused

0.82 AND NOT 0.80 on purpose. 0.80 is the most the current manufacturer colours
allow and it clears the floor by three hundredths, which means the next
colour change starts failing the gate — correct behaviour, but a bill paid
later for a difference of one unit now. The ceiling is Verity's #8a7340 and
nothing else: brightening that one colour is what would buy real room here.
```

## Hold magnification

Above `const HOLD_K := 2.0`:

```text
The magnification the hold's cells are authored at.

The refit screen draws the ship at 2x and a cell is 30px, which is what makes
a part the same size in the grid as it is bolted on. Anywhere the ship is
drawn at a different magnification — the sector strip drops to 1x while a
party is on screen — the cells have to come with it, or a part on a small
ship is drawn twice the size it should be relative to the hull carrying it.
```

## Part scale

Above `var plate_scale: float = HOLD_K`:

```text
HOW BIG THE PART INSIDE THE PLATE IS DRAWN, which has to be the same number
the box was sized with. `_draw` used to hardcode HOLD_K here while callers
sized `custom_minimum_size` from `footprint_box(m, k)` with a k of their own,
and the two only agreed by luck. They disagreed on the module gallery: a 3x
box around a 2x sprite, which is where its border came from. Worse, only the
SPRITE path was wrong -- `fill_part` takes its scale from the box, so a part
without art filled the plate and the same part with art floated in it.
```

Above `static func part_scale(slot: ModuleData.Slot, f: Vector2i, box: Vector2) -> float:`:

```text
The scale that makes a slot's silhouette fill `box`, at `f` cells.

FRACTIONAL on purpose, which the art direction's integer-magnification rule
does not cover: that rule is about magnifying a BITMAP, and these are
rectangles computed at draw time. There is no source grid to land on, so
rounding the scale would only make the shape smaller than the space it has.
Real generated sprites, when they arrive, will want the rule back.
```

## Tooltip

Above `func _make_custom_tooltip(_for_text: String) -> Object:`:

```text
THE PART AND BOTH ITS CARDS, side by side.

Three panels: what the module IS, then the two cards it actually grants,
drawn as cards rather than described as text. A module is a way of putting
particular verbs into a deck (docs/catalogue.md §1), so the honest picture of
one is the verbs themselves.

IT USED TO BE A STRING. Plain text could not show a card, so it printed the
effect line and the cost as words — which works and is a translation of the
thing rather than the thing. Godot will take a Control here, and a CardView
already knows how to draw itself.

resolved_cards(), not `cards`: the Grant Count Law decides how many a module
actually puts in a deck, so a part authored with two verbs that grants one
must show one. What is drawn is what the deck gets.
```

## Draw size

Above `func _draw() -> void:`:

```text
Drawn to the control's OWN size, not to SIZE.

A 1x1 fitting and a 1x3 gun are the same icon at different footprints once
the hold is a grid, so the plate, the manufacturer stripe and the rarity border all
measure themselves off `size`. Every existing use is a 44x44 cell and is
unchanged by this; the glyph was already centre-relative.
```

## Drawing a part

Above `static func draw_plate(ci: CanvasItem, m: ModuleData, r: Rect2,`:

```text
A PART, WHOLE, IN A RECTANGLE — plate, manufacturer stripe, silhouette and rarity
edge. Static and rect-taking so the HULL can draw the identical thing at the
identical size, which is the entire point: a 1x3 lance in the hold and the
same lance bolted to the ship should be one object that moved, not two
drawings that happen to share a colour.

It used to be only the silhouette that was shared, and a hardpoint drew that
at a fixed size whatever the part was — so a 1x1 sight and a 1x3 rail were
the same mark on the hull, and the shape you packed the hold around vanished
the moment you fitted it.
`cells` OVERRIDES how the part is standing, and the hull passes it.

`footprint()` swaps a part's axes when it is turned, and turning is a fact
about how it fits in the HOLD. The hold wants that -- it is drawing the
packing. The hull does not: rotating a rail to slot it into a gap should
not stand the gun on its end once it is bolted on. The hull already knew
this and sized the box from `m.size`, and the plate went on recomputing
from `footprint()` behind its back, which is why the box came out level
and the gun inside it did not.
```

## Manufacturer as art

Inside `draw_plate()`, above `var f := m.footprint() if cells == Vector2i.ZERO else cells`:

```text
AND THE MANUFACTURER IS THE ART. Which is a bet on what the art is going to be:
a generated Korvan gun and a generated Solari gun will not need a stripe
to tell them apart, any more than the hulls do. Until those exist the
silhouette is drawn in the manufacturer's own colour, which is the same claim
made with the one channel a rectangle has.

It cost a stripe, and that is the point of writing it down: the stripe was
a reliable answer that does not depend on art that has not been made yet.
If the generated parts turn out not to read as their manufacturer, this is the
commit to come back to.
```

## Silhouette size

Inside `draw_plate()`, above `var f := m.footprint() if cells == Vector2i.ZERO else cells`:

```text
The silhouette, at THE SAME SIZE THE HULL DRAWS IT and standing whichever
way the part is currently packed. Both call part_scale against the same
box — a footprint in the hold's own cells — so the gun you are looking at
in the grid is the gun that appears on the ship, not a smaller drawing of
it. It was `min(w, h) / 26` here, which made a part in the hold about a
third of the size of the same part bolted on.
```

## Part drawing

Above `static func draw_body(ci: CanvasItem, m: ModuleData, box: Rect2, col: Color,`:

```text
THE PART, by whichever means it has: its sprite when one exists, the drawn
silhouette when it does not.

ONE DOOR, called by the hull and by the hold, for the same reason `draw_part`
is one function — the alternative is two places that decide independently
whether a module has art yet, and they drift the moment one of them is fixed.
`ShipView` already proved the shape on hulls: sprite when there is one, the
procedural path underneath forever, and no third state where a part vanishes
because its file has not been generated.

`cells` is the footprint to reason about, which is the HULL's business rather
than the hold's — see `draw_plate`. Zero means "ask the module".
```

## Sprite drawing

Above `static func draw_sprite(ci: CanvasItem, tex: Texture2D, box: Rect2,`:

```text
A module's sprite, centred on its box AT A WHOLE MULTIPLE OF THE VIEW.

THE SCALE COMES FROM THE VIEW, not from fitting the box, and that is the
whole difference. Deriving it from the box looks right until the zoom goes
on: the box doubles, the sprite divides into it no better than before, and
the part stays small on a ship that has just become twice as big.

THE BOX IS A GUIDE, NOT A FRAME. A sprite is generated at the width its
cells ask for and cropped to its own ink, so its height is whatever the art
needed - a gun standing a few rows proud of its mount is a gun, not a
defect. What the box still says is where the part sits and how big it ought
to read, and `-- artcheck` fails only what misses that by a wide margin.

Never a fractional multiple. Resampling pixel art onto a grid it was not
drawn for is the one thing the art direction refuses outright.

`upright` STANDS IT ON END, and the silhouette path has taken that argument
since long before there was art to turn. This one ignored it -- there was no
argument to ignore -- so a part rotated in the hold kept its picture lying
down while its cell stood up, and the art hung out over both neighbours.
```

## Sprite turning

Inside `draw_sprite()`, above `var c := box.get_center().round()`:

```text
ANTICLOCKWISE, and that is not a free choice: `draw_part` turns the
procedural silhouette this way, so a barrel pointing forward on a ship
facing right points UP once stood on end. Turning the other way would fire
a stood-up gun downward -- and worse, a part WITH art would then disagree
with the same part without it, which is the one thing `draw_body` exists
to prevent.

The mirror composes on the LEFT so it lands AFTER the turn, for the reason
`draw_part` gives at the same junction: reflect first and the turn rotates
the reflection, which reads as a differently-shaped object rather than the
same one seen from underneath.
```

## Silhouette

Above `static func draw_part(ci: CanvasItem, slot: ModuleData.Slot, at: Vector2,`:

```text
THE SILHOUETTE A PART READS AS, drawn the same way wherever it appears.

One function, called by the hold and by the hull, because the alternative is
two drawings of a gun that drift apart — and the whole value of a part having
a shape is that you recognise the thing you just dragged when it lands.

SLOT decides the form: a weapon is a housing with a barrel out of the front, a
system is a plate, a utility is a mast. `s` scales it — the hull draws these
at 1 against a hull 30 to 50 rows deep, the hold at rather more in a cell it
has to fill.
`mirror_y` reflects the whole silhouette about that SCREEN ROW, after the
quarter turn rather than before it, which is what makes it read as the same
object seen from underneath instead of a differently-shaped part.

It is a parameter and not the caller's own transform because this function
sets the canvas transform ABSOLUTELY -- `draw_set_transform` replaces, it
does not compose -- so a mirror established outside was silently thrown
away here on the next line. Nothing errored; the flag simply did nothing.
```

## Part box

Above `static func footprint_box(m: HoldItem, k: float = HOLD_K) -> Vector2:`:

```text
THE BOX A PART OCCUPIES, in screen pixels, wherever it is drawn.

One function because three places wanted the same arithmetic and the whole
point of the last two commits is that they agree: the hold sizes its plate to
this, the hull scales the silhouette to it, and the drag ghost is cut to it.
Written out separately in each, they would only have to disagree once.
`k` is the MAGNIFICATION the box is wanted at, and it defaults to the one the
hold is authored at. Pass 1.0 for the size a part is on the ship at native
zoom — the gallery does, so a plate there is exactly the rectangle the part
occupies on a hull rather than the twice-size one the refit screen shows.

Same arithmetic as MountPoints.part_rect, deliberately: if these two ever
disagree, a part is one size in the gallery and another on the ship, which is
the thing the shared silhouette exists to prevent.
Takes a `HoldItem`, not a `ModuleData`: it reads `footprint()` and nothing
else, so it was never about modules -- it was about shapes, and a material has
one of those too.
```

## Part offset

Above `static func part_offset(slot: ModuleData.Slot) -> Vector2:`:

```text
Where a slot's silhouette actually sits relative to the point it is drawn
from, in the same units as `part_extent`.

NOT ZERO, and assuming it was is what put barrels through the side of their
own plates: a weapon is drawn from its BREECH, spanning -4 to +14, so its
bounding box is centred five units in front of the origin. Centring the
origin in a box therefore hangs a fifth of the gun outside it.
```

## Filling a box

Above `static func fill_part(ci: CanvasItem, slot: ModuleData.Slot, box: Rect2,`:

```text
Draw a silhouette CENTRED IN A BOX, at the given scale and orientation.

The one way to put a part inside a rectangle. Both callers had been passing
the box's centre straight to `draw_part` as the draw origin, which is only
the same thing for a shape that happens to be symmetric — and one of the
three is not.
```

## Part origin

Above `static func part_origin(slot: ModuleData.Slot, box: Rect2, s: float,`:

```text
THE POINT `draw_part` IS CALLED FROM to centre a silhouette in `box`.

Not the box's centre, and that was the bug: a weapon is drawn from its BREECH
and its bounding box sits five units in front of that, so handing over the
box centre hung a fifth of the barrel outside the plate. Nothing in the data
was wrong — every size, scale and total was right and the only symptom was on
screen. Separate from `fill_part` so a test can ask where the ink will go
instead of looking at it.
```

Above `static func part_rect(slot: ModuleData.Slot, box: Rect2, s: float,`:

```text
WHERE THE INK ACTUALLY LANDS when a silhouette is centred in `box`.

Separate from `fill_part` so it can be asserted rather than looked at. The
bug this exists for was a barrel hanging out of the right-hand side of its own
plate, and nothing in the data was wrong — every size, scale and total was
correct and the only symptom was on screen.
```

## Mount anchor

Above `static func mount_anchor(slot: ModuleData.Slot, box: Vector2, upright: bool,`:

```text
WHERE THE HARDPOINT IS, inside the part's own footprint. Measured from the
box's top-left, in screen pixels.

Not the middle for everything. A gun bolts on at its BREECH — the centre of
its leftmost cell — so a three-cell rail lies along the hull ahead of the
mount instead of straddling it with a cell and a half hanging off the back.
Systems and utilities bolt on at their middle, which is what a plate slung
under a belly and a mast standing on a flank both actually do.

Follows the drawing round. `draw_part` turns anticlockwise, so a gun stood on
end has its breech at the BOTTOM and the anchor goes with it — otherwise
turning a rail in the hold would fire it through its own mount.
```

## Part turning

Above `static func part_turn(slot: ModuleData.Slot, f: Vector2i) -> bool:`:

```text
Does this part's silhouette need standing on end to match its footprint?

MATCHES LONG AXIS TO LONG AXIS rather than reading `turned` directly, because
the shapes do not all start out lying down: a weapon is authored long across and
a utility mast is authored long down, so the same flag would stand one of
them up and knock the other over. A square footprint asks for nothing.
```

Above `static func sprite_turn(tex: Texture2D, f: Vector2i) -> bool:`:

```text
The same question asked of a SPRITE, which answers it differently.

THE ART'S OWN SHAPE decides, where `part_turn` above asks the slot -- and the
slot is the wrong oracle for a picture. `part_extent` says what a WEAPON or a
UTILITY is authored like in rectangles; it cannot say what a given PNG was
actually drawn like, and the two need not agree. A sprite is generated at the
size its authored footprint asks for and then cropped to its own ink, so the
image is the honest record of which way that object lies.

Both functions therefore exist, rather than one: where there is no art the
slot is all there is to go on.

Square either way asks for nothing -- a 1x1 and a 2x2 look the same turned.
```

## The augmented mark

Above `static func augment_mark(r: Rect2, scale: float = HOLD_K) -> Array:`:

```text
THE AUGMENTED MARK: a small ICE wedge in the plate's top-right corner, cut
from the corner like a folded tab, with a one-pixel VOID rim on its long side.

ICE because it is the DATA colour and the colour of the AUGMENTED line in the
part's tooltip (`Widgets.augmented_label`). The rim is what makes it read on
any ground, the pale Common and the near-black contraband alike, and on a
sprite that stands proud of its box into the corner.

TOP-RIGHT. A drawn silhouette sits PAD clear of every edge, so there the
corner is empty. A SPRITE is centred with no margin, and a few run to the
plate's edge (ejector, board, braceframe), so on those the wedge is painted
OVER the art's corner. That is on purpose: the mark is ink over the art, as
the edge is, and the VOID rim is what lets it read on art. Rows of whole
pixels, never a polygon, so the stair edge stays crisp at any whole
magnification. `-- attrtest` checks it sits clear of every drawn silhouette
at 1x and at the hold's 2x, and that on any sprite, at 1x to 3x, it hides no
more than a twentieth of the art.
```

## Readout bob

Above `class ReadoutRow extends HBoxContainer` and `class BobCard extends Control`:

```text
Jon, Nov 9, on the part's hover readout, in three notes. First: the cards
inside it should "bob gently up and down, each out of step with the
others". Then, seeing it: "wayyyy smoother", and "remove the square border
around the whole thing".

The row (ReadoutRow) is the HBox that holds the part's panel and its cards,
6 px apart, and it has no plate: TagLayer gives a body with the `module`
meta an empty StyleBox and no arrow, and the cutaway does the same for a
part (a material's card and the dross keep the box, as every other rich
body does). So the pieces read over a busy scene, the row draws a soft
shadow under each child before the children draw: the child's rect 2 px
down and right at 0.45 black, and 4 px at 0.22. Not a box.

Each card sits in a BobCard holder the row lays out; the holder never
moves, the panel never moves, and the card inside sits at
SWING * sin(2 pi t / period + phase), SWING 2 px, on GameClock so a film
runs at the right speed: a continuous sine, which eases at both ends of
the swing. Periods 1.6 to 2.4 s by card index (1.6 + 0.2 i), phases 1.7 i
rad, so no two cards agree. It renders smoothly because the project
leaves snap_2d_transforms_to_pixel and snap_2d_vertices_to_pixel off and
the game is drawn through a 2x canvas transform (Main), so a fractional
game-pixel offset lands on whole screen pixels: half a game pixel is one
screen pixel at the normal window, finer on a bigger one, with no blur
(the default filter is nearest). The cards take no mouse (IGNORE, as
before: a tooltip that eats the mouse counts as leaving the thing), so
nothing that bobs can be clicked. The holder is freed with the readout,
which stops the bob. The same readout shows no flavour line (Widgets.md,
Card readout).
```
