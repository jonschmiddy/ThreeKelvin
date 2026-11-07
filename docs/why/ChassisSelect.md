The reasoning behind `tkg/scripts/ui/ChassisSelect.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Chassis select

Above `signal launched`:

```text
Which ship you fly out in: a manufacturer, then a weight class.

The first screen of a run, and the first time the game asks you for anything.
It exists because hulls now have manufacturers: a chassis sets four of your six
attributes, decides which cards your starting modules grant, and counts as
one toward its own set bonus.

TWO AXES, and they are genuinely different questions. The manufacturer is
who you are — which cards, which set bonus, which attribute signature. The
weight class is how much ship — hull, hardpoints, hand size, evasion. Every
manufacturer builds all three, so picking Redline does not force you into a paper
hull; it means a Redline heavy is still the fastest heavy in the game.

Selecting REALLY REFITS THE SHIP rather than previewing it — Run.fit_chassis()
runs on every click — so the attribute block is reading the live ship, not a
parallel calculation of what the ship would be. There is no second
implementation to drift.
```

## Tier blurbs

Above `const TIER_BLURB: Array[String] = [`:

```text
What each weight class IS, in one line, for the L/M/H tooltips. The buttons
are single letters, so this is where the word and the trade-off live.
One line each, in the same register as WEIGHT_BLURB: what the class buys you,
not its numbers. The numbers are already on screen in the attribute block and
the hardpoint rows, and clicking is how you compare them.

SPECIFICATION, NOT CONDITION. These used to read "kept up", "well kept",
"somebody loved this ship" — and that was wrong, because a class grows
HARDPOINTS. A well-maintained ship does not sprout a weapon mount. How beaten
up a hull is now lives on its hull points and is drawn by HullWear, which
leaves these letters free to mean the thing they actually change.
```

## Hero scale

Above `const HERO_SCALE := 1`:

```text
The one ship on the screen, and the only one drawn at all.

Cropped to roughly the band the hull occupies, so the window throws away the
empty rows above and below rather than the ship.

1x, not 2x. Integer scaling is the pixel-art rule, so a hull is either its own
size or exactly double it and there is nothing in between — and double filled
most of the panel once real art replaced the procedural drawing. ShipScreen
carries the same note for the same reason.
1x. The doubling moved into the ART: hulls are authored at 2x their box
(a heavy is 248x100 for a 125x50 box), so drawing them at 2x applies it
twice and puts a 496px ship on a 960px viewport. See boxes.py.
```

## Layout spacing

Above `const BLOCK_GAP := 4`:

```text
The gap between the banner and the identity column, reused as the indent for
everything below that has to line up with it.
The air between ATTRIBUTES, HARDPOINTS and STARTING MODULES. One constant so
the three read as evenly spaced blocks rather than as a list that happens to
have gaps in it.

Four, and it is measured against the WORST chassis rather than a typical one.
Cygnet's light frame has four utility mounts, so it launches with seven
modules where most launch with five — two extra rows in the list below. At a
12px gap that build came to 470px against a 448px viewport, and the 22px the
ScrollContainer quietly absorbed read as the module list being cut off.
```

Above `const PICKER_ROWS_GAP := 4`:

```text
Between those two rows. shipcol runs at separation 1 because the hull below it
needs every pixel it can get, and two rows of buttons one pixel apart read as
one crowded block rather than as two questions.

PAID FOR, not added: the gap under the pair drops by the same amount, so the
column is exactly as tall as it was. This screen was measured to 448 against a
448 viewport and has no slack to spend.
```

Above `const SIDE_W := 264`:

```text
The right-hand column, shared by the attribute block above and the loadout
below so the two line up.

The column is pinned to the right edge and its rows are left-aligned inside
it, so this width is also what sets how far LEFT the block starts: narrowing
it moves ATTRIBUTES, HARDPOINTS and STARTING MODULES rightward together,
which is the only lever that moves all three without breaking the shared left
edge they were given in the first place. The margin on `rwrap` cannot do it —
that sits outside the column and pushes the column left, not its contents
right.

The widest row is MANEUVERABILITY's: its label, ten cells and a value, about
217px. 264 keeps roughly 45px of headroom over that.
```

## Launch button

Inside `_build()`, above `var top := HBoxContainer.new()`:

```text
Title left, LAUNCH right, on one line above everything.

It used to be a full-width bar under the detail panel, which gave the least
interesting control on the screen the most weight — and put it below a
scroll, so the answer to "how do I start" depended on where you had
scrolled to. Up here it is always visible, always in the same place, and
small enough to read as the end of the process rather than the point of it.
```

## Detail scroll

Inside `_build()`, above `var col2 := VBoxContainer.new()`:

```text

Scrolled. Measured, the detail needs about 457px against 445 available —
and that was KORVAN, which does not have the longest backstory. Trimming
twelve pixels would fit one manufacturer and cut off another, so the height
is not something this screen gets to assume.

LAUNCH is not in here for the same reason: it lives in the title row above,
where it cannot be scrolled away from.
```

## Dim colour

Above `const DIM := Color(0.62, 0.66, 0.74, 0.42)`:

```text
An unpicked manufacturer, and a picked one.

Alpha alone was not enough of a difference. modulate multiplies, so pulling
the colour channels down as well takes the saturation out of the emblem and
the name — a dimmed Redline was still unmistakably red, which made seven rows
of livery compete with the one you had actually chosen. Cooled and darkened,
they read as a list; the selected one reads as the subject.
```

## Hull perk

Inside `_build_detail()`, above `for row in Widgets.ability_rows(manufacturer, Run.hull.perk_id, Run.manufacturer_count(manufacturer)):`:

```text
The hull perk belongs here on THIS screen. Every chassis a yard builds
carries the same authored perk — all three Korvan frames vent baffled — so
at the point of choosing a manufacturer it is one of their abilities, and
it is the only one you get without collecting anything.

It is a HULL property, not a manufacturer property, and the two come apart later:
LootGen rerolls the perk on a wreck, so a salvaged Korvan frame can carry
anything. That is why the tag reads HULL rather than 1+.
```

## Ability rows

Inside `_build_detail()`, above `head.add_child(idc)`:

```text
What the two rows above are actually counting, and where this ship starts
on that count. The old wording explained the arithmetic — "modules from
this yard, plus the hull" — which is the rule, not the situation. You want
to know how close you are.
No running count here. The rows above already say what each ability needs,
and at the point of choosing a chassis the count is always two — a line
reporting it says nothing that changes between manufacturers. It belongs
on the ship screen, where it moves as you fit things.
```

## Header height

Inside `_build_detail()`, above `head.custom_minimum_size.y = HEAD_H`:

```text
One height for every manufacturer. MEASURED: the identity column comes out
at 155 for four of the seven and 169 for the other three, the difference
being a single wrapped line of backstory. Left free, clicking down the list
shifted the ship, the attributes and the yard list up and down by fourteen
pixels — the page twitching while you compare things is the opposite of
what a comparison screen is for.

A minimum rather than a fixed size, so prose that grows past this still
gets its line: it pushes into the scroll instead of being clipped.
```

## Hull sizing

Inside `_build_detail()`, above `chosen.custom_minimum_size.x = 0`:

```text
The ship asks for NO width and takes what is left.

At 2x the sprite is 480 wide, and 480 plus the 300 column plus the banner
indent came to more than the panel has. That does not clip — the detail
lives in a ScrollContainer, so the container simply sized itself to the
content, and every wrapping Label above then wrapped at that oversized
width and ran off the visible edge. The manufacturer backstory losing its
last word was this, not a text problem.

Expanding instead of demanding means the arithmetic cannot go wrong again
at some other panel size: the hull is centred in whatever remains and
clipped by its own clip_contents, which is already how the height works.
```

## Power cap

Inside `_build_detail()`, above `var rct := HBoxContainer.new()`:

```text
Directly under the mounts because it is the OTHER thing that can refuse a
part, and the one a player has no way to guess: three mount rows read as
the whole install budget until something says otherwise.

`hull.power_cap` and not `power_cap()`, matching HOLD below — this screen
describes a FRAME, not the loadout currently bolted to it, and a number
that moved when the starter kit changed would be describing the kit.
```

## Row tooltips

Above `static func _tipped(inner: Control, tip: String) -> Control:`:

```text
Give a row a tooltip whose HOVER TARGET is the row, not the column.

A row in a VBox stretches to the full column width, so a bare tooltip on it
fires from empty space well to the right of anything readable. The inner box
shrinks to its content and owns the hover; the outer one is inert and holds
the slack. Same two-box shape AttrBlock uses, and for the same reason.
```

## Mount ceiling

Above `static var _ceiling: int = 0`:

```text
The most mounts of one kind any chassis in the game can reach.

DERIVED, not typed. A heavy carries four weapon mounts and `DB.TIER_DELTA`
grants an A-class frame a fifth and an S-class one a system mount on top —
two tables that have both moved this month, and a literal here would go stale
the first time either moves again and quietly re-ragged the column.

Cached because it is asked once per hardpoint row per chassis and the answer
cannot change inside a session.
```

## Deck popup

Above `func _show_deck() -> void:`:

```text
Every card this chassis would deal you, laid out over the screen.

Built from Run.installed rather than from a table of what the kit ought to
grant, so it cannot disagree with the deck you actually launch with — the
grant count is a rule with three inputs (slot, manufacturer, affixes) and a
second implementation of it here would be a second place to get it wrong.
```

## Escape handling

Above `func escape() -> void:`:

```text
ESC HERE (Main): the opening deck's popup first, then back to the title. Not
the escape menu (the tutorial audit, Oct 22): nothing has launched, and its
ABANDON put a run that never started on the record. Left the way the menu's
quit leaves, with no ship, the state the title expects; the save was cleared
by NEW RUN already, and a cold arrival here is left its save.
```

## Grade buttons

Above `func _tier_row(manufacturer: StringName, m: ManufacturerData) -> Control:`:

```text
The chassis line, and in Developer Mode the four grade buttons on the end of
it. Same shape as the weight picker one line above: the buttons CHANGE the
text beside them, so cause and effect stay one glance apart.

They sit here rather than in the name row because that row already carries
three buttons and the ship name at head size, and this screen has 448 pixels
of height to spend and no slack — a fourth control there pushed the sprite
below the fold. This line was a bare label with the whole width spare.

NOT BUILT when Developer Mode is off, rather than hidden: a hidden Control
still takes layout and focus order. The line then reads exactly as it always
has, which is the point — a player has no grade to choose, because a run
starts at C and every better frame is something you found.
```

## Banner

Above `class Banner extends Control:`:

```text
The manufacturer's banner, flown large.

The same flag the cards carry down their left edge, at four times the scale
and drawn by the same two functions — CardView.draw_cut for the hem and
draw_emblem for the mark. Not a picture OF the card's banner; literally the
card's banner, so a manufacturer whose hem gets redesigned is redesigned here too.

Thirteen units wide because that is what the hems are authored against: the
shapes use absolute offsets across the flag (Redline's tear is six two-unit
strips), so a wider banner would leave them bunched at the left edge. Only
the HEIGHT is free — the hem hangs off the bottom and the emblem sits near
the top, and the plain field between them can be any length.
```

Inside `_weight_button()`, above `const UNITS_H := 22`:

```text
How deep the flag is AUTHORED, in the same units as the width. Measured
off what the two draw calls actually put on it rather than picked: the
emblem occupies units 6.5 to 14.5 (it is centred at 11), and the deepest
hem in `CardView.draw_cut` is cut 6 units up from the bottom edge. 22 is
those two plus a unit of air, and anything shorter cuts the hem off — a
flag stopping mid-emblem is what 40px was doing on the refit screen.

Only a MINIMUM. On the chassis cards the flag still hangs the full depth
of the header, which is what `SIZE_FILL` in `_init` is for.
```

Inside `_weight_button()`, above `var s: float = S`:

```text
PIXELS PER UNIT FOR THIS ONE. `S` stays the default and the only size the
chassis cards use; the station flies its berths larger, because there the
flag IS the heading rather than a mark in the corner of a card.

An instance member rather than a second const, so every offset in `_draw`
scales together -- the hems are authored in units and a flag drawn at one
size with a hem cut at another is a flag with a hole in it. Set it before
the banner is added, and set `custom_minimum_size` to match: `_init` cannot
see it, so the default minimum is still built from `S`.
```

## Slot pads

Above `class SlotPads extends Control:`:

```text
Hardpoint cells: filled steel is occupied, an ember outline is a free pad.

Lives here now rather than on ShipScreen. The refit screen used to draw its
mounts this way and became a drag-and-drop grid, so this is the only place
left that wants a countable summary of the slots rather than the slots
themselves — which is right, because this screen is choosing a chassis and
that one is filling it.
```

Inside `_weight_button()`, above `func setup(u: int, t: int, reserve: int = 0) -> void:`:

```text
`reserve` is width held for pads this row does not have.

Without it the control is exactly as wide as the mounts it draws, so the
"2/4" beside it sat at a different left edge on every row — weapon four
pads out, utility one. The three figures are meant to be read down the
column against each other, which they cannot be while the column is ragged.
```
