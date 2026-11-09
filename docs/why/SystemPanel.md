The reasoning behind `tkg/scripts/ui/sysmap/SystemPanel.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Panel design

Above `const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")`:

```text
THE SECTOR MAP'S PANEL, on the right of the map in the star chart's own type.

TWO PAGES, NOT SIX (Jon: "It's not super clear right now to the user what the
actual events are in a particular sector. There are also multiple different
pages for the right panel ... It could be super simplified"; he picked B on
the "Sector Panel Rethink" mockup). It had a sector page, a star page, a
world page, an encounter page, a page each for DOCK and HARVEST, and a result
page, and the list of beacons was printed on three of them. Now:
  LIST   every event in the sector as a card: its title, its tag word in its
         colour, where it is, and its first line -- or, once it is over, a
         stamp saying how it ended and a line of what came of it. DOCK,
         HARVEST and the custodian are cards with their button on them.
         Clicking a world or the star on the map narrows the list to that
         place, with its picture, its facts and FLY HERE on top; SHOW ALL
         widens it again. There is no star page and no world page.
  EVENT  one encounter: its place, where you are, its one sentence and GO.
         GO flies you there and down into LOCAL, where the event's text, its
         choices and how it went come up (`LocalEventDrawer`) -- the one
         place a choice is taken. A walked-away one stays LEFT ALONE, open.

THE PAIR IS SHOWN WHEN IT MATTERS (Jon: "hovering over an option would grey
it out and would say WILL BE MADE UNAVAILABLE"). No divider and no warning
line: pointing at a card greys its rival and says so top right; pointing at a
choice that would take the event says what it would close; once taken, the
rival is stamped UNAVAILABLE.

THE STAMP (Jon picked treatment 1 of three): a finished card dims hard and
wears a solid badge with a pixel mark -- a tick in its band's colour, a cross
on grey for UNAVAILABLE, a figure on the partner colour with their name -- and
LEFT ALONE is an outline badge on a card that stays bright, because it is
still there to take. What each state means is `EncounterDrawer.option_state`.

IN ORBIT, THE CHOICES (Jon: "you can either fly to a planet... get in its orbit,
and the right panel updates with info on the planet, the picture of the
planet, and the choices. OR you click on the choices and that moves you to the
planet's orbit"). A place's page is its picture, its facts, whether you are in
orbit of it, and every event there with its one sentence and GO; GO flies you
into orbit first if you are not there, then down into LOCAL to take it (the
choices moved there: events resolve on LOCAL). The star's page is the same,
with its own picture and the worlds that go round it.

The screen owns the rules; this only builds what is shown and calls back.
```

## Event order

Above `func _events() -> Array:`:

```text
Every event in the sector, as [body, beacon], in the order of their places'
names (I, II, III), as the SATELLITES list below them goes (`_satellites`,
"list:C"); the pulsar's own on the star (beacon null). Round one sun that is
the order the bodies were made in, as ever; in a binary the cards read III,
IV, I over a list that read I to V (KAPPA AUGUR-9 on seed 7, the picks
review, Nov 1). What < and > step through follows (`_encounters`).
```

## Twin panel

Above `func _twin_head() -> void:`:

```text
THE SECTOR'S PAGE WITH TWO SUNS (ruling 20, Oct 30): both suns in the one
sun's picture, the system named once and called BINARY (Jon, Nov 1: "Let's
call it Binary instead of two suns"; it read TWO SUNS), its place line,
and then each star under its own name ("<system> A", "<system> B") with its
kind, its facts and its own way into its close orbit. Clicking either star on
the map opens this page, as clicking the one star does.
EACH STAR'S FACTS AS IT IS DRAWN (`SystemView.star_facts_of`, one source with
the tip's kind): star A as the one sun reads, a yellow dwarf of 1.0 SOL; star B
the K5 orange dwarf the map draws, with a K5's own mass and radius, 0.7 SOL
each (Jon, Nov 1, "starb:B"). (MASS read each star's share of the pair's pull:
0.55 SOL beside G2, and B a yellow dwarf too; then B's mass against A's as
their pulls are, 0.72 to 0.92 SOL, and its radius its drawn size.)
```

## Card tags

Inside `hover_choice()`, above `var mid := HFlowContainer.new()`:

```text
ITS TAGS, AND WHERE IT IS AT THE RIGHT, ON ONE LINE WHERE THEY FIT AND
ON TWO WHERE THEY DO NOT, as the panel's other words wrap at its column
(`_wrap`): on one row a card at the world you orbit asked for 231 px of
the 226 (RECEIPTED TWICE, YOU · LAMBDA CALLOUS I; Nov 1), and a page
that asks for more than the column widens the panel under its scroll
bar. The place goes down whole, YOU with it; on one line it is laid out
as it was.
```

## Comet spots

Above `var _spot_btns: Array[Button] = []`:

```text
A comet's reading has no GO: it is reached by its spots (`CometCatch`). Its
page shows three buttons, one a spot: "2 NEAR 2X   IT 0:13  YOU 0:05", IT the
comet's time to the spot and YOU the ship's. A spot greys out "TOO LATE" once it
cannot be made, and reads WAITING or ON YOUR WAY while the ship is going to it
or is there. The costs are one plain line under them, in the danger colours:
near costs hull, at the star hull and heat. The buttons clip their words, as
long ones widened the panel.
```
