The reasoning behind `tkg/scripts/ui/ShelfDisplay.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Shelf design

Above `const CELL := HoldGrid.CELL`:

```text
The Promenade's stock, as objects standing on a shelf.

IT WAS A LIST OF ROWS AND NOW IT IS A SHOP. The rack under the old list was
furniture behind a table of names -- better than a picture behind one, and
still a table. What is actually on a shelf is THINGS, at the size they are,
in the shape they are: a four-cell rail takes four cells of board and a
fitting takes one, so the shelf tells you what you are buying before you have
read a word of it.

THE HOVER IS FREE. `ModuleIcon` already answers `_make_custom_tooltip` with
the part's readout and every card it grants -- the same panel the refit screen
and the module gallery use -- so putting the real icon on a board is what
gives the shelf its inspection, rather than something built for this screen.

Drawn rather than loaded, like `YardScene` and `StationSpine`. Art replaces
the body of `_draw`; the layout below is what the art has to fit.
```

## No buy signal

Above `const CELL := HoldGrid.CELL`:

```text
NO SIGNAL, BECAUSE NOTHING ON A SHELF IS A BUTTON.

The ticket used to be one: clicking a price bought the part where it stood.
That was three hundred credits leaving your account on a single click with
nothing carried anywhere, which is the gesture the game threw out of the hold
when right-click-to-jettison was cut. The stock is objects and the objects
drag -- `ModuleIcon` is an `ItemIcon`, so every part on these boards can
already be picked up -- and the till on the deck below is what a shop has
instead of a buy button.
```

## Cell size

Above `const CELL := HoldGrid.CELL`:

```text
One cell of a module's footprint, in pixels.

THE SAME 40 THE HOLD USES, so a part is the same size on the shelf as it is
in the bay you will put it in. 26 was the first try -- four spines to a board
and technically legible, but a shop where the goods are smaller than they are
anywhere else in the game reads as a list of thumbnails rather than as
objects. A 1x1 fitting is 40 across and a 2x2 is 80, which is a thing you
point at rather than a thing you squint at.
```

Above `const SHELF_CELL := 20`:

```text
ONE CELL ON THE SHELF: THE SPRITE'S OWN 1x, 20 A CELL -- half the hold's 40.

The paragraph above is why it was 40, and it was overruled by looking: seen on
the rack at both sizes, Jon kept 1x. A part at its own pixel size is the
finest-detailed thing on the wall, so it reads as the goods rather than as
furniture, and the rack it needs is half the height. The cost is the one the
paragraph names -- a part is bigger in your hold than it was on the shelf.
```

## Rack frame

Above `const POST_W := 8`:

```text
THE UPRIGHT, AND IT IS FURNITURE, NOT SHELF. At 13 with 7 of air inside it,
the frame spent 40 of the rack's 132 pixels on itself and the goods read as
lost in it. Eight and four is the same pillar with its two flat middle
columns dropped: the shelf space is 92 either way, so the rack is 116.
```

Above `const PITCH := SHELF_CELL * 2 + PLANK + TICKET_H + HEAD + 6`:

```text
How far apart the boards are, floor to floor.

Tall enough for the tallest thing in the catalogue to stand on one -- a 2x2 is
two cells -- plus its ticket and a little headroom. Fixed rather than measured
off the stock, because a shelf's boards are where the shelf's boards are: they
do not move up when a shop happens to be selling small things.
```

Above `const PIP_GAP := 2`:

```text
The break between one cell's light and the next, so the strip can be counted.

Two pixels, which is one at game scale -- the gap has to survive the shrink
without eating the light either side of it. The art's own bays under the
board run at a pitch of its own and are NOT what this lines up with: those
are how the rack was built, this is how big the part on it is.
```

## Rack size

Above `const BOARDS := 3`:

```text
HOW BIG THE UNIT IS, rather than how big the deck is.

A PIECE OF FURNITURE, NOT A WALL. The rack was handed the whole deck and drew
boards all the way down it, which made the Promenade a warehouse aisle with
four things in it. A shop's shelf is an OBJECT standing in a room -- it is the
size it is, the air around it is the room, and an outpost with two parts on it
still looks like a shop with two parts in it because the empty boards are
still there. Three of them, which is a shelf; nine was a wall.
```

Above `static func boards_for(rows: Array) -> int:`:

```text
Two boards, or three when two will not hold this stock.

TWO OR THREE SHELVES TALL. Twelve cells hold an ordinary station's three
parts nearly always; a hub's five can need eighteen, so a hub gets the tall
rack. Asked of `_pack`, the same packing `stock` lays out with, so the rack
and what stands on it cannot disagree.
```

Inside `stock()`, above `var usable := h - float(CAP_H + 6 + PLINTH_H)`:

```text
--- THE BOARDS ARE WHERE THE BOARDS ARE.

Fixed pitch down the whole unit, filled from the top. The empty ones at the
bottom are not a gap to be closed -- an outpost with two parts on it SHOULD
look like a shop with two parts in it, and a rack that shrank to fit its
stock could never say that.
```

## Packing

Above `static func _pack(rows: Array, count: int) -> Array:`:

```text
The stock on `count` boards, as `[boards, spilled]`: each board an Array of
entries in stock order, and how many parts found no room.

WIDEST FIRST, ONTO THE BOARD WITH THE MOST ROOM LEFT. Widest-first is what
stops a long rail being stranded by small parts ahead of it; most-room-first
spreads the stock across the boards instead of filling the top one, which is
what a shopkeeper does and what a delivery nobody unpacked does not.
```

Inside `stock()`, above `var shelves: Array = _pack(rows, count)[0]`:

```text
--- AND THE STOCK STANDS ON THEM, wrapped left to right.

Wrapped FIRST and placed SECOND, because things on a shelf stand on it: a
2x2 and a 1x1 sharing a board line up at the BOTTOM, and a part cannot be
positioned until the tallest thing beside it is known.
SPREAD ACROSS THE BOARDS, not packed onto the first one.

Wrapping purely on width put all five parts on the top shelf with three
empty boards underneath -- which is what a delivery looks like before
anybody has put it away, not what a shop looks like. A shopkeeper spreads
the stock out, so the wrap takes whichever comes first: the board is full
ACROSS, or it has its share of the goods.
```

## Room rack

Above `var art_override: Texture2D = null`:

```text
A SHOP ROOM'S OWN RACK, when the room has one: the level's rack art and the
rows its boards are on, which a style may move (`rack_boards.json` -- three
level racks were recut so their tags clear a drawer). Set before `stock`.
The node stands at the art's own size and the screen scales it by two, so
the rack and everything on it are pixel-doubled together, as the bench
draws them.
```

## Rack art

Above `var _art2: Texture2D = null`:

```text
The rack as art, or null for the drawn one.

RESOLVED OUTSIDE `_draw`, deferred: a texture first touched inside a draw
call renders white for good -- `StationRoom._plate_key` has the long version.
The art is authored to `RACK_W` x `rack_height()` with its boards on the
heights `stock` stands parts on, so the parts land on them without asking.
```

## Light strip

Inside `stock()`, above `var lit := float(SHELF_CELL - PIP_GAP)`:

```text
ON THE BOARD'S LIGHT STRIP, ONE SEGMENT PER CELL: the edge under a
rare part glows its colour, broken where its cells are. Three rows
so it covers the strip on the middle board too, which the art puts
a pixel higher than `base`.

IT COUNTS, it does not just measure. As one unbroken rect it was
only a LENGTH, and a length is read against the part standing on
it rather than against the grid -- so a 3x1 and a 2x1 looked like
the same thing at two sizes. Segmented, the strip says three and
says two, and you can count it without knowing the cell pitch.
ONE BLOCK IS ONE CELL, at the cell pitch -- not the part's width
divided by its cells. Dividing gave a block of 18.67px for a 3x1
against 19px for a 2x1, which lands on half pixels at 2x and
makes the segments ragged and unequal. A block of SHELF_CELL less
the break is a whole number for every size there is.
```

## Price tags

Inside `_slot()`, above `var price := int(entry.price)`:

```text
THE PRICE ON THE BOARD, under the thing it is the price of. A shop puts the
ticket on the shelf edge and not on the box, which is also the only place
it can go here without covering the part.

A TAG AND NOT A BUTTON. It is a piece of card on a string; what buys the
part is carrying the part to the till.

CENTRED UNDER ITS OWN ITEM. A tag is as wide as its number and the things
above them are not -- a four-cell rail is a hundred and sixty pixels and a
fitting is forty -- so a wide price under a narrow part hangs past it on
both sides. That is what `stock` reserves room for: it advances by whichever
of the two is wider, so the overhang lands in air and never on a neighbour.
```

Above `class PriceTag extends Control:`:

```text
One price, as a card on a string.

IT WAS A LABEL, and a label is a number floating on a shelf. What a shop puts
under its goods is an OBJECT -- card, a punched hole, a bit of string -- and
the difference between those two things is about thirty lines of rectangles.
It is also the only warm surface on this deck, which is the point: paper among
painted metal reads as somebody's handwriting rather than as a readout.

Drawn rather than loaded, like everything else standing in this station.
```

Inside `draw_lit_marks()`, above `const CARD := Color("#c2ae86")`:

```text
A PRICE STAMPED ON A CARD, in digits three pixels wide.

A tag has to fit under its part, and a part on a 1x shelf can be one cell,
twenty pixels. The game's pixel font sets "236" wider than that, so the
digits are drawn here, 3x5 each with a pixel between: three digits in
fifteen, four in nineteen. It reads as a price gun's stamp, which is what a
shop tag is.
```
