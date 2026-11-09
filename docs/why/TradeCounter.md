The reasoning behind `tkg/scripts/ui/TradeCounter.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Counter design

Above `signal took(item: HoldItem)`:

```text
A counter you carry things to, and the money changes hands.

DRAGGING IS THE CONFIRMATION, which is the whole reason this needs no button.
The game already settled that argument once -- right-clicking to jettison was
cut for being "the only destructive gesture in the game with no confirmation,
no travel and no target", and the hatch beside the hold was fine because you
have to CARRY something to it. A counter is the same rule applied to money:
nobody sells a rare, or spends four hundred credits, by twitching.

It also unties the knot a list of rows could not. Buying was a price you could
click and selling was three buttons on every line -- install, sell, scrap --
which is a spreadsheet. As PLACES they need no labels at all: the hardpoints
are on your ship (click it, on LOCAL or in the Shipyard), and this is the counter.

TWO SIDES, ONE PIECE OF FURNITURE. See `Side`. The Promenade's till charges
you and the Exchange's counter pays you, and they are the same desk seen from
the two sides of it.

Drawn rather than loaded, like the rest of the station's furniture.
```

## Counter sides

Above `enum Side { PAYS, CHARGES }`:

```text
Which way the money goes at this counter.

THIS IS NOT THE SCRAP CHUTE COMING BACK. That was two prices for ONE object in
ONE room: the counter's bid beside a flat melt rate, where the lower number
existed only to be a second currency wearing a verb's clothes. These are the
two SIDES of a single market -- `Market.ask` is what a shop charges and
`Market.bid` is what it pays -- and `MarketTest` proves by exhaustion over
every development, security, danger, rarity and manufacturer relationship that
a bid is always under an ask. A spread you cannot farm is a market; a second
rate for the same object in the same room is a currency.
```

## Shelf origin

Above `const FROM_SHELF := &"shelf"`:

```text
The `origin` a drag carries when the thing was lifted off a shop shelf.

NAMED HERE BECAUSE THIS IS WHAT DEPENDS ON IT. `ShelfDisplay` stamps it and
`_accepts` reads it, and while it was a bare "shelf" in both files a rename in
either one would have gone through the parser without a word and come out as a
till that charges you for parts already in your hold. It is a money bug with
no error message, so it gets a name.
```

## Desk size

Above `const DESK_H := 96.0`:

```text
How tall the desk itself is, measured up from the deck.

FIXED, NOT A FRACTION. This control fills whatever it is given so the room has
depth, and an early version scaled the counter with it -- which drew a
waist-high desk three hundred pixels tall and made the scale on it look like a
lamppost. A counter is a counter however big the room is; the SPACE above it
is what varies, and that space is the room. Below about forty pixels of slack
there is no room to draw and this is simply a desk, which is what the
Promenade wants: the shelf is already that deck's room.
```

## Counter art

Above `var art: Texture2D = null`:

```text
What is being carried over the desk right now, and why it is being refused.
`_why` empty while something is over it means the counter will take it.
The counter as art, or null for the drawn desk. Set by the screen, which
loads it outside any draw call. Authored with its desk top `DESK_H` above its
foot and its props standing ABOVE that, drawn over whatever is behind the
control -- a till is a desk with things on it, and the things are the till.
```

## Pricing

Above `static func offer(m: HoldItem, at: int = Side.PAYS) -> int:`:

```text
What one thing changes hands for at a counter of this side.

STATIC AND PUBLIC so a screen can quote the same number in its own readouts
without forming a second opinion about what a counter is worth. It reads
`Run.node_at()` rather than taking a node, because a price is a property of
the PLACE and there is only ever one place you are standing in.
```

## Refusal

Above `static func refusal(at: int, m: HoldItem) -> String:`:

```text
Why this counter will not take the thing being carried over it. Empty when it
will take it.

SAID OUT LOUD RATHER THAN GONE QUIET. A till that simply refused a drop is a
till that looks broken, and every case here is one the player can act on --
"NEED 40 MORE" is a different instruction from "NO ROOM".
```

Inside `refusal()`, above `if not Run.has_room_for(m):`:

```text
ROOM FOR THIS PART, not for any one cell. `hold_full` asks about a
single cell, so a 2x2 into a hold with one gap was quoted, paid for,
and then had nowhere to go -- the credits gone and the part with them.
```

## Drop origin

Above `func _accepts(from: StringName) -> bool:`:

```text
Where a thing carried here is allowed to have come from.

THE ORIGIN MATTERS, and getting it wrong would be a money bug rather than a
layout one. A till buys FROM THE SHELF; dropping a part you already own onto
it would otherwise charge you for something already in your hold. The
Exchange's counter is the mirror -- it takes what you are carrying and not
what is still standing on a shelf for sale.
```

## Drawn counter

Inside `_draw()`, above `if dy > 40.0:`:

```text
--- THE ROOM BEHIND THE DESK, when there is room for one.

THE COUNTER IS NOT THE WHOLE CONTROL. Given height it fills it, so that
side of the deck is a PLACE rather than a widget floating in a panel; given
none -- the Promenade, where the shelf is already the room -- it is just the
desk, and nothing below has to be told which case it is in.
```

Inside `_draw()`, above `for r in [Rect2(w - 74.0, dy - 44.0, 30.0, 44.0),`:

```text
--- AND WHAT IT HAS ALREADY TAKEN, stacked against the back wall.

BEHIND the desk, so only the tops clear the counter -- which is what
makes the desk read as being in front of something rather than pasted
onto a backdrop. It is also the only thing on the deck that says the
station keeps what it handles: your hold empties and the stock goes
somewhere.
```

Inside `_draw()`, above `var bw := minf(w - 40.0, 132.0)`:

```text
--- THE TILL DISPLAY, set into the front of the desk and facing you.

ON THE DESK RATHER THAN ON THE WALL, which is the one placement that works
at both sizes: the Promenade's counter has no wall to hang anything on. It
is also where a till's display actually is.

THE QUOTE IS A NUMBER, NOT A GLOW. An earlier version lit a small green
window and left you to guess what the thing was worth, but the whole point
of quoting while it is still in your hand is that you can decline, and you
cannot decline an amount nobody has told you.
```

Inside `_draw()`, above `if side == Side.CHARGES and win.end.y < h - 5.0:`:

```text
--- THE HARDWARE EITHER SIDE OF THE DISPLAY, which is what tells the two
counters apart at a glance.

A TILL HAS A KEYPAD AND A SCALE HAS A PAN. Both counters are the same desk
-- deliberately, because a station should do business one way -- so the
equipment bolted to them is the only thing that has to say which way the
money goes here. It sits on the FACE rather than standing on the top,
because the Promenade's counter is only as tall as a counter and has no
top surface inside its own box to stand anything on.
```

Inside `_draw()`, above `var cx := w * 0.5`:

```text
--- THE SCALE, STANDING ON THE COUNTER.

It is the one object that says TRADING rather than storing, which is the
whole difference between this and the shelf or the hold beside it. It sits
ON the desk and reaches UP, so the pan is above the surface -- which is
where you would actually put something down.
```

Inside `_draw()`, above `if carrying:`:

```text
--- AND THE DESK ANSWERS WHAT IS BEING HELD OVER IT.

THE DESK AND NOT THE ROOM, which is also where the drop is accepted: the
lit edge is the hit box drawn. On the EDGE rather than as a wash, because a
fill would swallow the object you are holding over it and the object is the
thing you are deciding about. Red for a refusal rather than nothing at all,
so a counter that will not take something still looks like it noticed.
```
