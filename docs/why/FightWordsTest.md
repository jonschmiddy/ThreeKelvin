The reasoning behind `tkg/scripts/sim/FightWordsTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Fight words

Above `var _fails := 0`:

```text
THE WORDS ON LOCAL AND IN A FIGHT SAY WHAT THE RULES DO (the tutorial audit,
Oct 22), headless:
  godot --headless --fixed-fps 60 --path . -- sheet=FightWordsTest

 - THE STATUS CHIPS NAME THE CARD'S KEYWORD. Negate showed as SLIP and Grows
   as ADAPT. A real fight on LOCAL, each set on your ship, the chip row
   rebuilt: each chip's heading is the keyword the card that sets it prints
   (`CardData.keywords`, read off a real card of the catalogue), and no chip
   says SLIP or ADAPT.
 - THE DISCARD SAYS WHAT GOES THERE. It said "What you have played so far".
   A card played, END TURN with cards left in the hand: the played card and
   every unplayed one (fused ones stay) are in the discard, and the pile's
   tooltip names both.
 - THE BAR'S LINE HAS NO DASH. "NOTHING ELSE HERE - SEE SECTOR" had one, and
   its three siblings too. Every place in the galaxy, its line
   (`SectorScreen.here_line`), and the label LOCAL draws.
```
