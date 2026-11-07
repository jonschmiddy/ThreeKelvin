The reasoning behind `tkg/scripts/ui/PostingBoard.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Board design

Above `var list: Control = null`:

```text
The Hiring Hall: a bulletin board, and the whole deck is the board.

IT WAS A BOARD IN A ROOM, and before that a board filling a panel with nothing
on it but the work. Neither looked like the thing every station actually has,
which is a bulletin board somebody has been pinning to for years: notices hung
wherever there was room, a wanted poster, a clipping, a flyer with half its
tabs torn off, and the holes of every pin that was ever pulled out. The WORK is
what you came for; the rest is how the deck says people live here.

EVERYTHING WITH WORDS ON IT HANGS SQUARE. The notices and the town's sheets
were each turned a few degrees for one pass, and pixel text turned by even a
degree breaks into stair-steps. The board is made of things to read, so the
lived-in look comes from overlaps, shadows and pin holes instead.

TWO KINDS OF PAPER, AND ONLY ONE OF THEM IS A BUTTON. The real contracts are the
dark printed notices down the left -- `_offer_row` and `_deliver_row` build
them as they always did, pinned in a straight column. Everything in the
right-hand column is drawn here and is scenery: nothing in it can be signed, so
none of it is printed the way the notices that can be are.

AND THE MANUFACTURERS PIN THINGS UP TOO. Every manufacturer holding the station
has a notice of its own on the board, in its own colours and in its own voice
-- Korvan's misfire counter, Calyx asking you not to feed the hull. A board at a
Korvan yard and a board at a Calyx one should not read the same, and a notice
is the cheapest way there is to say who runs a place.

Drawn rather than loaded, like the rest of the station's furniture.
```

## Board by development

Above `var dev := 2`:

```text
WHAT THE BOARD IS, by the station's development level (Jon, 2026-10-01:
"Unclaimed and outpost is like a cheap corkboard / settlement could be a
whiteboard / city and capital are more of a LCD screen"), drawn here rather
than generated ("Maybe we just stick with the coded for right now ... Can you
code generate these at the different development levels?"). The paper on it
is the same everywhere: the work and the town's are what the deck is for.
```

## Screen marketplace

Above `const HEADER := 22.0`:

```text
THE SCREEN IS A MARKETPLACE (Jon: "maybe we can have ads and popups on the
LCD screens ... or we can make it look like a craigslist / facebook
marketplace", then "Both"). An app bar across the top -- a title, a search
box, category tabs -- the work as listings under it, and down the side the
town's WANTED Hellbender as the featured listing, a rotating ad, the manufacturers'
sponsored posts, and now and then a popup that opens over the side and
closes itself. Popups never cover the work: nothing moves over what you can
click.
```

## Scatter placement

Above `const SCATTER_TRIES := 90`:

```text
EVERYTHING BUT THE WORK GOES WHERE IT LANDS (Jon: "having things in random
locations would be cool. we can have a designated spot for the quests (top
left), but the rest can just be random"). The work flows from the top left.
The WANTED poster and the manufacturers' notices are always up: they are
placed first, so they find room, and nothing lies over them. Then pieces
from the board's pool, in this station's order, each tried at random spots
until one is clear of the work and lies over no more than a little of what
is already up. Nothing ever goes over the work.
```

## Featured listing

Above `func _featured(sz: Vector2) -> void:`:

```text
THE FEATURED LISTING, a marketplace's, not a poster (Jon: "let's have the
sponsered and featured different from the corkboard and whiteboard"): a
photo of the Hellbender across the top with a gold star on its corner,
WANTED where a price would go, what it is and what for. No bounty and no
sum (Jon, Oct 22: the bounty was promised and never paid, so the posters
just say WANTED). No VIEW chip: it is an ad,
and nothing that cannot be pressed may look as if it can (Jon: "just remove
the view and more buttons entirely. Just have it be an ad").
```

## Monitor casing

Above `func _monitor(w: float, h: float, k: Dictionary) -> void:`:

```text
A MONITOR'S CASING, not a picture frame (Jon: "Can we make the frame of the
LCD monitors have little buttons or something? Just to make it look more like
a TV monitor or screen instead of a painting frame"): rounded corners, a
speaker grille and a blank nameplate along the chin, a row of push buttons
and the power light on the right of it, a camera eye at the top. A city's
is grey plastic; a capital's is brushed brass with gold buttons.
```

## Sheet pins

Above `func _sheet(at: Vector2, sz: Vector2, deg: float, paint: Callable, pin_x: float) -> void:`:

```text
One sheet, with its shadow and its pin -- turned about its corner only when
`deg` is not zero, which is only ever the scrap with nothing written on it.

THE PIN GOES WHERE THE WORDS ARE NOT. It sat dead centre on every sheet, and on
a sheet whose title starts at its left edge the centre is the end of the title:
the rota card read SHIFT ROT with a pin where the A was. `pin_x` is a fraction
of the width -- the middle for a centred title, the right-hand corner for one
that starts at the left.
```

## Manufacturer posts

Above `const POSTS := {`:

```text
What each manufacturer pins up: its lines, then one word set large.

IN EACH ONE'S OWN VOICE, lifted from who they already are rather than invented
beside it. Korvan stamps parts for a war two centuries over, and they fire every
time; Solari lost an argument about safety margins; Probate follows other
people's disasters; Redline is never at the address on its invoices; Verity
makes few and signs them; Cygnet's drones anticipate you and nobody discusses
it; Calyx hulls are grown, with a clause about what not to feed them.
```
