The reasoning behind `tkg/scripts/sim/BoardSignTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Sign test

Above `var _fails := 0`:

```text
SIGN CHANGES ONE NOTE, headless:
  godot --headless --path . -- sheet=BoardSignTest
Jon, Oct 22: "When you pick a quest from the hiring board... the whole hiring
board resets." SIGN took the job down and put it on the SIGNED, ELSEWHERE
card at the front, rebuilding every note: each note slid along a slot, and
the board, laid out round its notes, laid itself out again -- the cork's and
the whiteboard's scatter (the WANTED poster, the manufacturers' notices,
every piece of paper) jumped to new places, and the screen's other people's
listings moved along their slots with new stamps and prices.

On the outpost's cork, the settlement's whiteboard and the city's screen
(one tab picked, a popup open), through the station screen and its deck
button, with a DELIVER sticky and the SIGNED, ELSEWHERE card up: SIGN
clicked as a player clicks it signs that job, its note stays in its place
and size stamped SIGNED with no SIGN on it, and nothing else changes -- every
other note the same node in the same place, the tab, the board's scatter or
its listings, the ticker, the popup, the lamp's power-on, the offers
themselves (never rolled again). Then a refresh from elsewhere (credits
moving) changes nothing either. And a heat job signed with the heat already
on the hull is paid off its own note, in place, which then reads SIGN again.
```

## No bounty promise

Above `const PROMISE := "BOUNTY|REWARD|WORTH|CLAIM|PAID|PAYS|\\d+ ?CR\\b|CREDITS"`:

```text
NO BOARD PROMISES A BOUNTY FOR THE HELLBENDER (Jon, Oct 22: the bounty was
promised and never paid, so the posters just say WANTED). Every piece of
paper, ad, popup and ticker line that names the Hellbender, on every kind of
board, says nothing of a bounty, a reward, a sum or a claim. The two posters
drawn in code, the WANTED sheet and the screen's FEATURED listing, say
WANTED and nothing of the sort, and are stamped DESTROYED after the kill,
never CLAIMED: CLAIMED says somebody was paid.
```
