The reasoning behind `tkg/scripts/sim/OutcomeTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Outcome test

Above `var _tree: SceneTree`:

```text
WHAT YOU END UP WITH, on the real LOCAL with the real HUD and theme
(`OutcomeRow`, every look):
  godot --headless --fixed-fps 60 --path . -- sheet=OutcomeTest

The real outcomes `OutcomeCheck.find_cases` finds (Jon's lifepod, credits and
a part, credits and fuel, a part alone, nothing, credits alone, the most
changes), each
played through LOCAL's band as the map's GO asks for it, its result drawn in
every look in all three layouts:
  the numbers the run moved, said (`OutcomeCheck.check`);
  the box test, in Silkscreen at the game's own sizes: every entry inside
    the band, off every other, off the buttons, the text, the head and the
    YOU CHOSE line, B's rows in their columns;
  E's plates: one for each part and material that came aboard, said once,
    clear of the text and the buttons' column (`OutcomeCheck.prize_place`);
  CONTINUE exactly where today's look has it (in the band layouts; the card
    is seated by its height, so there it is the card's width that holds);
    but D's, at the band's top right, its size and right edge today's;
  D's table at 8, only the four stats that moved, no totals (none, no table), the
    buttons level with the title and clear of everything, the table
    centred under them (`OutcomeCheck.check` / `d_place`).
Then C's flight, animated (the game's clock stepped 1/60 s):
  the HUD holds its old number until the flight for it lands, then shows the
  new one; something is in the air between; a readout flickers on landing
  and is back to its own colour after; no HUD readout, tab or button moves a
  pixel (only pressable things look pressable, and nothing pressable moves);
  nothing is left held. CONTINUE pressed mid-flight lands everything at once.
  Reduced motion: nothing flies, the numbers change at once, it still
  flickers.
```
