The reasoning behind `tkg/scripts/ui/OutcomeRow.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Outcome looks

Above `static var look: StringName = &"D"`:

```text
WHAT YOU END UP WITH, at the foot of an event's result on LOCAL
(`LocalEventDrawer._result`).

Jon, Oct 17, of the Drifting Lifepod's result: "it's kinda hard to read what
you end up getting at the bottom. It should be more clear." It was four fixed
pairs -- CREDITS — HEAT — HULL -5 FUEL — -- in the body's 8 px, dim grey,
a dash for every stat that did not move, the one real change a small red -5
among them, and the words and numbers on two baselines. Nothing a part, a
crate, a document or a marked place could say: those had no line at all.

THREE LOOKS, ONE SWITCH (`look`), today's until Jon picks one:
  A  ONLY WHAT CHANGED, BIG. The dashes go. Each change is the number at
     FS_HEAD with its word beside it on the same baseline, signed and in its
     colour ("-5 HULL" red, "+40 CREDITS" green), in the order it matters:
     hull, fuel, credits, heat, then the things. A part is named in full
     with the cards it would add to your deck.
  B  A LEDGER. A small receipt beside the text, GAINED | LOST, each row the
     stat's mark, its word, the amount and where it leaves you ("HULL -5
     35 > 30"), so you read where you stand now and not only what moved.
  D  A LITTLE TABLE ON THE RIGHT (Jon, of the first three: "can we have the
     results be on the right side right above the reward and continue? Like
     in a little table?"). Directly above REWARD and CONTINUE, its right edge
     on theirs and at least their width: a row a change, its mark, its name,
     the signed change and the new total ("HULL -5 31"), hull, fuel,
     credits, heat, then the things, a part with its cards under it. The
     text on the left wraps to stay clear of it.
     THEN THE BUTTONS ON TOP, AND ONLY THE FOUR STATS (Jon, Oct 19, of the
     band: "can the text on the right be a bit bigger? and centered
     vertically?", "can we also have the buttons at the top right?", then
     "let's only show CREDITS, FUEL, HULL, HEAT on the right"). REWARD and
     CONTINUE stand at the band's top right, level with the title, and the
     table is centred in the right column under them. It lists only the
     four stats, each only when it moved: a part, a material, a frame or
     a place is collected through REWARD and is not listed,
     and a result that moved none of the four has no table at all (the
     buttons alone). Its size is `D_FS`: he tried the next crisp size up,
     16, and kept 8 ("size 8"). The title, YOU CHOSE and the text are a
     column on the left that wraps clear of it. On the card the buttons go
     on the title's line too (or on a line of their own over it when the
     title leaves them no room) and the table sits at the foot,
     right-aligned. And no totals ("you can remove the total credits and
     fuel part. just put what is added or lost"): "FUEL -3", not
     "FUEL -3 42".
     AND DATA, A FIFTH (Jon, Nov 4, science pick 2A, amending the Oct 19
     ruling's four): DATA is a stat like credits, spent at a lab and
     nowhere else, so a reading's result lists it with the four, after
     credits and before heat, by the same rule (only when it moved, its
     change alone): "FUEL -2", "DATA +5". Its mark is drawn in ICE, the
     HUD's DATA ink, never the credits note's brown: it is not money.
  E  D, AND WHAT YOU GOT, BIG (Jon, of D: "I like this, but there was a
     previous version of this where the things you get are big on the
     right side"). D's table over REWARD and CONTINUE stays where it is; a
     part or a material the event put on the pile is drawn beside it, to
     its left, as the hold draws it -- its plate (as big as the band holds,
     `BIG_KS`), the grade's ground and edge, its art -- with its name in its
     grade's ink, the grade and kind under it, and a part's cards. What is
     drawn big is not said again in the table; the rest of the table is
     D's. Nothing that takes a click moves: the text wraps narrower and the
     band grows upward if the plates stand taller than the table.
  C  SHOW IT. Today's size, only what changed, each with its mark; once the
     text is in, each change flies from the band to the HUD readout it moves
     (the hull gauge, credits, fuel, DATA, heat; a place to STARCHART) and that readout flickers as it lands -- and only then does
     the HUD number change (`held`). A part or a crate makes REWARD flicker
     on its turn instead: it is on the band already, and a copy sliding
     along the row would cross the other entries. Nothing that takes a click
     moves: the readouts and buttons only flicker.

WHAT AN EVENT CAN HAND YOU, all of it read off `OptionResolve.take`: the five
ledger stats (`bill`: the four and DATA), and the things (`got`) -- a part or a material put on
the system's pile, a hull frame found, a place marked on the chart, an item taken out of your hold. No event gives or takes a card
or a malfunction directly (malfunctions come from fights); a part's cards are
the only cards an event ever offers, so a part names them.
```

## Change entries

Above `static func changes(out: Dictionary) -> Array:`:

```text
Every change one result made, in the order it matters, as entries:
  key    "hp" "fuel" "credits" "data" "heat", or the thing's kind
  kind   &"stat" or the thing's kind (part, material, frame, place, item)
  n      the move (a stat), or the count (a thing; negative when taken)
  was    now   a stat's totals either side
  good   whether it went your way; tone  its colour
  big    the signed number; word  what it is; name  a thing's name
  cards  a part's cards, by name
  item   the part or the material itself (a thing on the pile), else null
Empty when nothing changed.
```

## Outcome table

Above `class Table extends Control:`:

```text
A small table, drawn: mark | name | change | total, a row a stat, the
change and the total right-aligned in their columns so the digits line up.
The things after, a line each with their count leading ("+1 PART: ..."),
wrapped to TABLE_MAX_W, a part's cards under it in the quiet grey. As wide
as it needs and drawn against its right edge, so stretched to the buttons'
width it still ends where they end.
```

## Plate sizes

Above `const BIG_KS: Array[float] = [3.0, 2.0, 1.0]`:

```text
The magnifications a plate may be drawn at, biggest first: the largest that
fits BIG_FULL_W x BIG_FULL_H (a two-cell part three cells wide, or two
tall). A one-cell part gets 3x, half again the hold's own 2x
(`ModuleIcon.HOLD_K`) -- the point of E is that it is big -- a 2x2 the
hold's size, a long rail 1x. Whole numbers only: a sprite is drawn at a
whole multiple or not at all (`ModuleIcon.draw_sprite`).
```
