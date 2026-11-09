The reasoning behind `tkg/scripts/ui/BoardScreen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Ad copy limits

Above `const ADS := [`:

```text
WHAT A CITY'S AND A CAPITAL'S MARKETPLACE SCREEN SHOWS, besides the work: a
pool to pick from (Jon: "Not 20X on the board, just a big pool to pick from
for diversity"). `PostingBoard` starts each station at its own place in each
list, by the station's number, and turns them over on the clock, so two
screens side by side are not showing the same ad.

Text is the Silkscreen pixel font, upper case. An ad's lines are [words,
size] with size 16 (big) or 8 (small); a big line holds about 7 letters
across an ad, a small one about 14. A strip ad's two lines hold about 30.
A popup's body lines hold about 15.

Measured since, for the long lists: an ad panel is about 104 wide and 170
tall, each line taking its size and 6 more, so keep a big line to 6 letters,
a small one to 15, and the lines to about 150 tall in all. A strip is about
240 wide: its lines hold 36. A popup is 176 wide: its title holds 22, its
body lines 24 (two or three of them), its button 10. A listing's title
holds 20, a headline 40, a stamp 9.
```
