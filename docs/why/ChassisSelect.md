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

Changed Nov 11 (Jon: "When in the ship selection screen, Esc doesn't open the
menu... it goes back to the title"). Esc opens the escape menu here as on every
other screen. The audit's worry stands, so the menu knows it is before launch
(`PauseMenu.before_launch`): no run status block, RESUME says BACK TO THE YARD,
and its one exit is BACK TO TITLE, with no confirm, as nothing is lost; SAVE
and ABANDON are not offered. BACK TO TITLE calls `escape()`, which leaves the
way it always did: no ship, nothing on the record.

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

## No science cleared here

Inside `setup()`, above `_build()`:

```text
NO SCIENCE CLEARED HERE. The one game door in is `Router.new_run`, whose
`Run.start_new_run` has already cleared the dead run's science (so no old
DAMAGE CONTROL shows as +7 hull, nor SPARE CELLS as +3 cells in
`power_cap()`, below) AND dealt this run's board. Clearing again here
wiped that board, and LAUNCH deals none: every run flew with an empty
board, and the first autosave wrote it (`-- savetest`).
```

## Banner yard

The screen since Nov 10 (Jon's W2 v10, "Y1: the yard is good, build it"), drawn by
`YardFront` (the hall), `YardBanner` (a banner), `YardStandSet` (a berth), `YardBand`
(the facts and LAUNCH) and `YardFrontLife` (the crew), with `ChassisSelect` left to
say what a click means:

```text
The front door is the old shipyard. The Shipyard deck's own hall at city level,
with its lamps, its crew lanes and its workers (`YardScene`, `YardLife`), is the
picture; it is 766 wide and the frame is 960, so the hall's first columns are
drawn again at its right, lit as those columns are (the light shader's
`shift_x`, as the deck's elevator edge already used it), and its last rows run
on under the band. Three things of the deck's life would have crossed the band
on the apron (the forklift, the floor hatch, the front welder's lane) and go;
the engine cart and the grinder move to where the mockup put them.

Seven banners hang from the gantry, one a manufacturer, every one shown: a
locked one is a dark cloth saying ??? for its name and its emblem, and it is
still clickable, so the chain reads as a horizon. The sway is a whole-pixel
shear of the cloth, more at the foot than the head, nine poses held while the
sine holds: pixel art turns in whole steps.

The chosen manufacturer's three hulls stand on the yard's stands, staged in
depth: the medium front left, the light front right, the heavy centred behind
and higher on the floor. They are the game's own hull art on the deck's own
stands, lit as the Shipyard deck is lit (see `Lit as the Shipyard`, which
replaced this paragraph's first lighting on Nov 12).

Pointing at a hull blurs everything else, stands included, a little strong
(a box blur of 1.8 px and 13% down), and the hull is drawn again sharp over
the blur. There is no outline: the ship stands out by being the one thing in
focus. Clicking a hull picks it; the pick carries across manufacturers (a
medium stays a medium) because the two axes are independent. LAUNCH is a big
amber key, grey until a ship is picked, and silent, as it always was.

A locked manufacturer's three ships sit under tarps (PixelLab art, one a
weight, cut for the Korvan hulls), which drop one after another, sag and
settle, then ripple at the hem now and then while the body never moves; the
hall goes gloomy, two lamps stutter in uneven steps, and the band shows ???
and `Unlocks.lock_line`. The band itself (Jon's B1) has no panel: the floor
falls to near black toward the frame's foot in stepped dithered bands and the
words sit on it. It shows the name, the manufacturer, the weight, the seven
attributes as `AttrBlock` always drew them, the hardpoints spelled out, the
hand and the hull's perk, and a mint tie line up to the ship's stand.

The HUD bar is hidden over this screen, and the screen is `top_level`, so the
hall runs edge to edge of the 960 x 540 picture rather than the shell's
content box. Developer mode shows every banner open (as `Unlocks` already
said) and the C-B-A-S grade chips under the key, nothing else.
```

## Seated on the stands

Jon, Nov 11: "The ships are floating above their stands." The banner yard stood
two 88-row stands at the hull's quarters with their tops six rows above the
hull's lowest pixel. That lowest pixel is a keel, a fin or a pod, rarely the
belly over a stand, so most hulls hung over the cradles with floor between
(the heavy and both side ships worst). The mockup's drawn hulls had flat
bellies, which is why it looked right there.

`YardStandSet._seat_stands` now stands a hull as the Shipyard deck does
(`YardScene._stand`): `seat_pair` puts the two stands on the hull's mass
middle where the belly over each cradle is level, the higher cradle's seat row
(the stand's `seat` in yard.json, 11 for the city stand: the white lip) lies
under the belly, the other is let in deeper behind the hull, and both stands
are one height, grown or cut by `_sized` so their feet stay on the berth's
floor row. The hull stays where the mockup put it; the stands reach up to it.
A tarp keeps the mockup's stands (quarters, the stand let six rows in), which
its drawn hem covers. `YardSeatTest`'s front-door section measures every
manufacturer, weight and grade, and the tarps, off the pictures.

## Fixed berths

Jon, Nov 12: "the stands don't line up between manufacturers. They kinda move
around when you select different manufacturers. The light should be on the far
left. The medium on the far right and the heavy in the back." Since Nov 11 each
hull stood where the mockup put its left edge and the stands reached up to it
(`Seated on the stands`, above), so a wider or differently shaped hull moved and
resized both stands. The berths are now fixed (`YardSlot`): the light centred at
x 200, the medium at 776 (over the hall's join, so its right stand is lit as the
hall's first columns are), the heavy at 480 behind them; the front stands' feet
on row 372, the heavy's on 334. The front stands are the picture as drawn
(46 x 88); the heavy's are smaller by the floor's depth, (334 - 30) / (372 - 30)
= 0.89 (`YardLife.zat`'s vanishing row 30), so 41 x 78: rows cut by `_sized`
where the sides match best, whole columns dropped where a column matches its
neighbour best. Only the hull moves: `YardSlot.seat` slides it up to `DRIFT`
(14) columns off its mass middle and lets it down onto the stands with the score
`YardScene.seat_pair` uses, resting on the higher cradle. The stands' middles
apart (light 84, medium 108, heavy 180) were swept from 60 to 196 over Korvan's
and Solari's art, the only two with their own hulls (the others wear Korvan's),
and picked where both sit centred (no slide), nothing let down past the seat,
and the stands near the deck's 48% of the hull: the light's keel pod and
Solari's light's tail drop 12 to 14 rows, so the light's left stand stands up
behind its keel, as on the deck. The tarps sit where Korvan's hull sits on the same stands.

## Grounded stands

Jon, Nov 12: "The stands don't really meet the floor in the right way, they are
kinda floating." The stands were TextureRects over the whole hall, and under
them a 4-row black bar and a 12-row dither ran the width of the hull at the
feet row, which read as a shelf the stands stood on. The bar is gone and the
stands are drawn as the Shipyard deck draws its own (`YardStandSet.paint_stands`,
`YardScene._draw_ships`): the stand shadow Jon passed on Sep 30 under each, the
stand lit as the deck lights a ship, in the crew's depth order. A first pass
added contact shades, a reflection of the feet and a darkened base plate; Jon
picked the deck's whole light instead (D, below), so they went with it.

## Lit as the Shipyard

Jon, Nov 12: "The lighting on the ships doesn't really make sense... the lights
are not emanating from the top", then, shown the deck beside the front door:
"Why can't the yard light work like it does in the shipyard?", and picked D,
the deck's light exactly ("D ❤️"). The front door runs on the deck's engine
(`YardLight`, `yard_light.gdshader`) but was built on Nov 10 from the W2 v10
mockup, and its light followed the mockup: haze cones hung from the ceiling
lamps to row 360 and ended on a flat line with no pool, the ambient was 0.12
against the deck's 0.2 ("so the pools read"), the lamps over the picked ship
went to 1.5 as spotlights that lit the wall but never the ship, and the floor
pools were baked with no hulls in them (a deliberate note then: the deck's bake
puts every ship at the deck's row, 310, and hulls standing further up the hall
threw "long shapes across the floor that read as writing"). The hall copied past
x 766 read the floor lamps of the hall's left edge. Measured source by source
(`tk-scratch/yard-stands/light/diag_*.png`), the floor lamps lit 48% of the
picture in a grid of 44 lamps that line up with nothing you see, the haze 23%,
the ceiling lamps 13% and only the wall.

Now: no haze; the deck's ambient (yard.json's dial, 0.2 at city) and its five
ceiling lamps at full, picked or not (the deck adds no light to a ship shown:
the pick has the blur); the deck's belly shading; and the deck's floor-lamp
pools with the hulls' shadows in them (`YardFrontPools`), baked over the whole
960 columns by `yard_bay.gdshader` with two rows of ships, the front berths at
their depth and the heavy at its own (`mask2`, `zs2`), so each shadow falls
where its hull stands; the light shader reads a frame-wide floor map at its own
place past x 766 and folds everything else back onto the hall's first columns,
so the join has no seam. The pools are baked when the hulls change, on a banner,
never on a pick. A locked set keeps its gloom: the ambient to 0.07, the lamps to
half and two of them stuttering. The shapes the hulls' shadows make on the floor
are the deck's own, which Jon chose.

## Walkers round the stands

Jon, Nov 12: "People walking around the ship selection screen run through the
stands or right underneath them." Three faults. The stands were drawn above the
whole hall, so every walker went under them, in front or not. The crew's front
lanes (rows 358, 368, 376) crossed the front berths' feet (372). And the floor
patches over the bay marks and the hall's continued right side were laid over
the hall after its crew, so a walker crossing one vanished (the generator
mechanic at x 806 was never seen at all, and is gone). Now the stands are items
in the crew's depth order (`YardFrontLife.tick`, by their feet row), the patches
and the continued hall lie under the crew (`YardFront._under`), the hall is not
clipped at its 766 columns and the lanes run on to x 990, off the frame. Each
berth keeps its floor (`YardSlot.footprint`: stand to stand plus 6 columns,
from 24 rows behind the feet to 12 in front, at the front row's size), and
`YardFrontLife.avoid` steps a lane that crosses one forward to pass in front of
the stands, eased in and out over 36 columns. Walkers behind a berth (the back
lanes, rows 224 to 280) pass behind its stands and under its hull, drawn under
both. `YardSeatTest` walks every lane for a whole lap.

## Launch on pick

Jon, Nov 11: "having the launch and buttons appear when a ship isn't selected
is weird." With nothing picked the band shows SELECT A SHIP and its line and
nothing else. LAUNCH and, in developer mode, the C B A S grade chips (the
condition grade to launch on, `_tier_chips`) appear once a ship is picked, in
place, faded in over 0.18 s through `self_modulate` (the chips' own
`modulate` marks the picked grade); never slid, as they are things to click.
Under a locked manufacturer a click on a tarp picks nothing but brings LAUNCH
up grey beside the lock line, so the way out (win a run) is said where the key
would be.

## Held blur

Jon, Nov 11: "When a ship is selected, the blur should stay." The blur used to
follow the pointer only. Now the picked ship holds it: the rest of the yard
stays soft with the pick drawn sharp over it after the pointer leaves.
Pointing at another ship moves the sharp copy to it as a preview, and leaving
it brings the pick back. The fades stay at a fifth of a second. A locked set
holds no blur: a carried pick is not a ship on those stands.

## Click away

Jon, Nov 11: "Clicking away from the ship (not directly on the ship) deselects
it." A left click no ship, banner, LAUNCH or grade chip took reaches
`ChassisSelect._gui_input` (the hall passes its clicks on), and clears the
pick: SELECT A SHIP, LAUNCH and the chips hidden, the blur gone. A band word
with a tooltip passes its click on too, so a click on a word is not away. A
ship is its own opaque pixels (`YardStandSet.on_ink`), not its box: a click in
a hull's box but off its pixels is away.

## Banner cloth

Jon, Nov 11: "You can select the different banners at the bottom of the
screen...? Should only be when hovering over them." `YardBanner._has_point`
kept the chains out but had no foot, so every column under a banner, down to
the band, was that banner. It is now the cloth as it hangs this frame
(`on_cloth`: the posed shear and the forked foot), and nothing below it. The
same day: "the banners can be longer", so the cloth went from the mockup's 76
rows to 100, the name and emblem where they were and the lighting bands
stretched to the new foot; the foot stays clear of the heavy's top.

## Launch plate

Jon picked L-A "Plate" on Nov 11 (`tk-scratch/ui-build/launch-btn/launch_designs.py`,
`design_a`, drawn there pixel for pixel): the old 156 x 76 key cap read as a
slab, so LAUNCH is a slim 139 x 35 amber plate with a 2 px lip under it, a
crisp 1 px bevel lit from the top left, 2 px chamfered corners and the word
tracked out 3 px in dark ink, with floor all round. Hover lays a stepped amber
glow round it (two solid steps and a dithered outer one, light drawn as light);
a press sinks the face 2 px over the lip; locked is the same plate in dark
slate. It is still a Button named LAUNCH, still appears only once a ship is
picked, and nothing on it moves at rest. The mockup's box test put it clear of
the band's words (122 px at its nearest) and of the developer's grade chips,
which keep the old key's foot at (744, 508); SELECT A SHIP stays centred where
it was.


## Hulls baked ahead

Above `func _bake_ahead() -> void:`:

```text
Jon, Nov 12: "the whole ship yard selection screen is VERY laggy". Measured
on the PC (RTX 3070, `-- sheet=YardBench`): a frame of the hall costs about
1.2 ms at rest and 1.7 ms with the blur, so the hall itself was never the lag.
The clicks were. A banner's first click in a run took 630 to 690 ms, as its
three hulls' graded pictures (`HullGrade.graded_tex`, C grade) were baked on
the main thread; the bake is seeded by the run (`Rng.master`), so every new
run paid it again, and with developer mode (or a record that opens them) every
banner paid it. Now every open banner's hulls bake on a worker while the hall
stands: Korvan's three alongside the hall's build, the rest one at a time.
All twenty-one at once starved Korvan's three and made the way in 1.4 to 1.6 s
(from 1.0); one at a time it stays 1.0 s and the rest are done in about 4 s.
A click on a banner not yet baked waits for the bake in flight and bakes the
rest itself, as before. Leaving the yard waits for the one in flight.
```

## Ship map in bytes

Above `func _rebake() -> void:`:

```text
Each banner click rebuilt the light's ship map with get_pixel and set_pixel
over the whole 960 x 482 hall (the stamps 15 ms, the belly shading about
30 ms) and baked the floor pools again (15 ms and a GPU read the next frame),
65 ms a click. The map is built in a byte array over the hulls' box only. The
pools were then baked with no hull in them and baked once; since Jon's D (Nov
12, `Lit as the Shipyard`) they carry the hulls' shadows, so they bake again
on each banner, from byte masks, and never on a pick. `-- sheet=YardPerfTest` holds it equal, byte for byte, to the old
per-pixel map for every set, hulls and tarps.
```


## What a ship comes with

Jon, Nov 12, on the hull pick: "In the bottom left, it might be helpful to show
the manufacturer information", and "Let's also show the installed modules (I
think it's just the weapons?)... they do come with a standard deck of cards."
A chassis launches with more than its weapons: `Run.fit_chassis` fits the
manufacturer's weapon and the four yard parts of `DB.GENERIC_KIT` (Mining Laser, Hull
Plating, Signal Board, Coolant Line) where the mounts and the reactor allow, and
`_top_up_deck` fills spare mounts until the deck is the hand plus four: ten cards
for most, twelve for Cygnet's light, nine for Verity's (its parts grant one each).

Of three options (B1 in the band, B2 on the ship, B3 a dossier plate that had to
sit over another ship) Jon picked B2, with B1's parts list "without the little
box to the left". `YardInfo` draws it: the band's left column is the hull's name,
the manufacturer's emblem and name, its slogan and, once picked, its identity line (while
only pointed at, CLICK TO MAKE IT YOURS stands there instead, so the column fits);
the hardpoint column is FITTED, each part's name and slot, the mounts left, the
hand and the hull's perk, wrapped to the card stack's edge. Jon's notes on the
build: no deck line ("Deck 10 cards is redundant": the stack says it), the
column moved left to 32 px after the attribute values, and the perk's second
line at the parts' pitch. The hand reads "HAND SIZE: 5 A TURN" (Jon's words). The weapons
are bolted on every open hull in the yard (`MountPoints`, passive, weapons only, as
on the Shipyard deck), the kit fitted on `Run` for a moment and put back, and the
sharp copy over the blur carries them. The deck is a stack of three card backs
in the manufacturer's colours by LAUNCH; pointing at it lays the
whole deck out over the floor at the hand's size. `YardInfoFit` box-tests it.
