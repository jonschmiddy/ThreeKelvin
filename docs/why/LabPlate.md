The reasoning behind `tkg/scripts/ui/LabPlate.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## A key on the labs screen

Above `const BG := Color("#0a0e15")`:

```text
A KEY ON THE LAB'S SCREEN (science S9, Jon's 1C): the four the zoomed-in
Lab presses, drawn pixel for pixel as the approved mockup drew them
(tk-scratch/science/sheet2/tree/build/build.py, `plate` and `tab`):

  &"plate"   the game's own button, UITheme.bevel: one pixel of BEVEL_HI on
             the top and left, near-black on the other two, ICE words
  &"leave"   the same plate in LEAVE ink
  &"commit"  the plate in ember: BUY and MAKE
  &"tab"     no box, a rule under the word; the tab you are on is lit

A REAL BUTTON, so it clicks, disables and points the way every button does
(the pointer closes over it). Godot's own plate and words are switched off
and this draws its own word, `label`: a Button's `text` would size the key
off the theme's font and grow it past the mockup's box.
Built once and restyled: a screen that rebuilt its keys on every refresh
could not be clicked.
```
