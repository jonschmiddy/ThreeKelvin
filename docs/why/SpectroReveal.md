The reasoning behind `tkg/scripts/ui/SpectroReveal.gd`; each heading is referenced from the code by a `Why:` line.

## Spectro split

Above `class_name SpectroReveal`:

```text
JON'S PICK, NOV 18. Two rounds of mockups (scratchpad loot_reveal_mock, ten
animations and then five variations on the one he liked): "S1 SPECTRO SPLIT
is the best", with "anim=S1 SPECTRO SPLIT length=1.00 gap=1.00 overlap=off
tint=on". This is the mockup's sweepSplit, moved into the game as it was.

THE MOTION, per item, on its own clock (tau, seconds from the peak):
- 0.65 s before the peak: a prism line (a 2 px core in the item's GRADE
  colour, red, yellow and green fringe columns to its left, blue to its
  right, a faint column of light after it) sweeps left to right across the
  cell in the first 55% of that time;
- behind the line the item shows as three copies, its own red, green and
  blue (the icon drawn three times through a channel modulate, added
  together, so where they meet it is the item), 8 px apart and 2 px off
  vertically, then converging to nothing over the last 45%;
- at the peak the item is simply itself, and its tier sound plays
  (`SalvageGrid.revealed`, rung by `TransferView.ring_reveal`);
- 0.35 s after: a glint on the item's edges, red on the left half and blue
  on the right, at full for 30% of that and half for the next 30%. It is
  the copy shifted 2 px ADDED and the copy in place SUBTRACTED, so flat
  areas cancel and only edges light: the mockup's edge glint, without
  reading the item's pixels back.

EVERY OFFSET IS A WHOLE 2 PX ART PIXEL (`snap2`), as on the mockup. The item
never moves: only its copies and the light do. The same on every item; the
sound carries the grade, the line's core carries its colour.

NODES, NOT PIXELS. The icons draw themselves procedurally (`ModuleIcon.
draw_plate` and the rest), so the copies are three more of the same icon,
each FLATTENED in a CanvasGroup and then given a channel modulate. The
group's shader (`GROUP_SHADER`) adds its picture to what is under it, or
takes it away for the glint, and clips it between two x itself: the copies
end at the prism line, the glint at the item's halves. A Control's
clip_contents does not reach a CanvasGroup's picture, and a CanvasItemMaterial
on a group draws its whole rect white, which the second film showed. Without
the group each of the icon's draw calls was added on its own (plate, then
picture over it), so they summed and the item burned white: the first film
showed it. The two shaders are made once (static); each group has its own material, as its clip is its own.
```
