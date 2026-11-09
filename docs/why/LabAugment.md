The reasoning behind `tkg/scripts/ui/LabAugment.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## The labs augment page

Above `signal lit_changed`:

```text
THE LAB'S AUGMENT PAGE, on the big screen with the camera in the glass
(science S9 part two; Jon's 1C, Nov 4). Your parts down a rail on the left,
FITTED and then IN THE HOLD; the part in hand drawn large in the middle as a
schematic; the Lab's three affixes for it branching off its mount on the
right, each with what it does to your numbers; and the strip along the
bottom naming the result and holding the one key that spends.

PORTED FROM THE APPROVED MOCKUP (tk-scratch/science/sheet2/tree/build/
build.py, `augment`, 2_augment_capital.png): the rail's 46 px rows, the
phosphor parts, the 5x schematic with its cell grid and centreline, the
affix rings at (700, 118/248/378), the strip's words and the AUGMENT key
are drawn where and how it drew them.

STRIP (open call 10) lives on the same page: an augmented part, or one with
rolled affixes, has a STRIP key on its row. Pressed, the right side lists
the part's own affixes instead of the offer, and the strip at the bottom
names the one picked with its own STRIP key and bill: a pick, then a press.

A PICK NEVER MOVES A PART. The rail is drawn, not made of the hold's icons,
so there is nothing here to drag (HoldGrid's pick mode is the same rule for
the grid). An augmented part is dimmed and cannot be picked for a second
augment: picking it shows what can come off it.

BUILT ONCE. The keys (AUGMENT or STRIP, the rows' STRIP keys, MORE) are
made with the page and only moved, retitled, shown or hidden on a refresh,
so a click survives the `resources_changed` its own purchase sends.
```
