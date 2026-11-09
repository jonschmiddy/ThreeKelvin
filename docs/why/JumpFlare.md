The reasoning behind `tkg/scripts/ui/JumpFlare.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Jump flare

Inside `_draw()`, above `var flare := 0.0`:

```text
Width: two segments, meeting at PEAK. Not one sine across the whole
life — that put the widest frame at 0.62 while the hull swapped at
0.42, and the swap was visible next to the flash instead of inside it.
```

## Partner slot

At the top of the file, above the class's first member:

```text
One ship flying with you: their hull, their name, and how they are doing.

The readouts are PAINTED OVER the ship rather than stacked under it, which is
the same choice `ShipSlot` makes below and for the same reason — a column of
four ships each with a label and two bars under it is sixteen rows of chrome
in an arena that has none to spare, and a name written across a hull is
plainly that hull's name.

It is not a drop target and it never will be. Cards are played from your deck
onto your ship and onto what is shooting at you; a partner is a thing you can
see, not a thing you can aim at. See `docs/coop-design.md` §5.
The light a ship arrives and leaves in.

ONE ANIMATION FOR BOTH DIRECTIONS, and that is not a shortcut. A jump is a
column of light with a hull either side of it: what differs between arriving
and leaving is only whether the ship is there before the flash or after it.
Two separate effects would be two things to keep in step and would read as
two different events, which they are not.

Cold, not ember. Every other light in this game is heat — weapons, the hull
shader, the overheat warning — so a jump has to be the one thing on screen
that is bright and not warm, or it reads as another gun going off.

Drawn rather than animated. Everything here is on the pixel grid at integer
widths and the brightness is stepped, for the reason CombatFx records: a
pixel is lit or it is not, and fading one through alpha is how pixel art
starts looking like a screensaver.
```
