The reasoning behind `tkg/scripts/ui/StarchartScreen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Chart overview

Above `var _chart: MapChart`:

```text
The star chart.

Nodes are icons tinted by region, not squares with names under them: a label
under every node is what forced the old chart to clip STATION to STATIO, and
it made a spatial decision read like a list. You pick a node, the panel tells
you what is there, and one button commits.

Ship stats and cargo used to live here too. They belong to your ship (click it) —
this one answers a single question: where next, and what will it cost.
```

## Static view state

Above `static var _sight_on := true`:

```text
Which rings the chart draws. Both on by default: they are how the two
limits are read, and a player who has never seen them cannot know to
look for them.
HOW THE CHART IS BEING LOOKED AT, and STATIC because the screen is not.

`show_starchart` builds a fresh StarchartScreen on every arrival, so anything
held on the instance is a preference the player re-enters after every single
jump. Reported for LOCAL REGION -- "it's kinda annoying always having to zoom
into my local region every jump" -- and the other three are the same control
in the same corner, so they would have been reported next.

Static rather than saved: these describe how somebody is looking at the map
this session, not anything about the run. A save that restored a zoom level
would be a save that could restore a WRONG one.
```

Above `static var _view_zoom: float = 0.0`:

```text
WHERE THE CHART WAS POINTED, kept for the same reason the toggles are.

LOCAL REGION persisted and the VIEW did not, which reads as the toggle being
broken: it stayed lit while the chart sat fully zoomed out. The cause is that
`frame_region` divides by `size`, and during `_build` the control has not been
laid out yet -- so `size` is zero, the wanted zoom is zero, and it clamps to
ZOOM_MIN. It was re-deriving the view at the one moment it could not.

Storing the view itself sidesteps that entirely, and answers the actual ask:
the zoom and the position stay put across a jump, whether they came from the
region button, the wheel or a drag.

`_view_map` is a crude galaxy fingerprint. A new run is a new galaxy and the
old pan means nothing in it, so a mismatch throws the saved view away.
```

Inside `_build()`, above `if "primer" in OS.get_cmdline_user_args():`:

```text
The VIEW itself is restored by the chart on its first resize -- see
`_view_zoom`. Re-framing here would run before layout and land on ZOOM_MIN,
which is the bug that made LOCAL REGION look like it had stopped working.
```

## Primer gate

Above `static var _primed_for: int = -1`:

```text
WHICH RUN HAS ALREADY BEEN PRIMED, as a galaxy seed.

GALAXY_SCALE.md section 5 says to gate on `Run.trail.is_empty()` and spend no
save key on this. THE FIRST HALF OF THAT IS WRONG ABOUT THE CODE: a run
starts with `trail = PackedInt32Array([0])`, the system you begin on, so the
trail is never empty and a primer gated on emptiness would never once appear.
`size() <= 1` is the same intent -- you have not jumped yet -- and does work.

The brief then accepts re-showing the card if you open the chart, dismiss it
and reopen before jumping. That is cheap to do better: this is static, so it
outlives a screen that is rebuilt on every open, and holding the SEED rather
than a bool means a second run in the same session is primed again rather
than silently skipped. Still no save key, still nothing on the wire.
```

## Toolbar row

Above `const BAR_H := 17`:

```text
THE TOOLBAR ROW along the top of the chart, and of the sector map, which is
built from the same pieces (Jon: "do the danger bar the same style as the
layer bar ... It should be the same height as the button bar for the
starchart"): one height whether it holds buttons or not (17, a button's own,
measured), so the two rows line up to the pixel as the camera moves between
them.
```

Inside `_build()`, above `var dev_host: HBoxContainer = strip`:

```text
(LAYER at the row's own start: the goal is below the plate, at the
picture's top left -- Jon, Oct 20 -- not in the row: `GoalLine.fixed_at`)
DEVELOPER MODE'S BUTTONS narrower: still held (their SHOW / HIDE must not
shuffle the row: a shuffle re-laid the chart under a move), and the row
the same height as the map's, so the plate never changes between them
```

## Sky under the glass

Inside `_build()`, above `if not ("skyhost=off" in OS.get_cmdline_user_args()):`:

```text
THE GALAXY RUNS ON UNDER THE GLASS (Jon: "why does a galaxy disappear
near the side panel?", "And also disappear in the corner?"): the chart's
sky drawn behind the whole screen, out past the picture to the field's
own edges -- under the side panel, the toolbar row and the key row --
and fading out only there; the picture keeps the clicks and the marks
(`MapChart.sky_out`)
(a harness's `skyhost=off`: the sky in the picture alone, as before)
```

## Corner toggles

Inside `_build()`, above `_region_btn = _corner_toggle(_on_region, 0, 112.0)`:

```text
OVER THE CHART, bottom right, sitting on the scale bar it belongs with.
Both answer "where am I and how big is this", so together they read as
one instrument in the corner rather than a toolbar item at one end of
the screen and a decoration at the other.

A child of the CHART rather than of the panel around it, so it follows
the chart's rect and needs no second set of margins to stay put.
```

Inside `_build()`, above `_reach_btn = _corner_toggle(_on_reach, 0, 150.0, true)`:

```text
TOP right, not stacked under the scale block. These two answer "how far
can I see and go", which is a question you ask while reading the map --
the scale bar and LOCAL REGION are about the view itself and belong
together down there.
THRUSTER REACH first because it is the LONGER label. These are right
aligned, so the longest line on top gives a clean descending edge; the
other order notches inward and then back out.
```

## Destination name height

Inside `_build()`, above `var head := VBoxContainer.new()`:

```text
Wraps to a second line instead of widening the panel. A Label reports the
width of its longest unbroken line as its minimum size, so a name like
OMEGA CALLOUS SECUNDUS at head size pushed the whole sidebar out and the
chart shrank to make room — the panel changing width as you point at
different systems is far worse than a name taking two lines.

AND THE HEIGHT IS RESERVED, because that fix only moved the problem onto
the other axis. A wrapped name is TALLER, the panel's height is its
content's, and the chart shares a row with it -- so selecting THETA ABYSSAL
SECUNDUS pushed every row below it down and resized the chart, while OMEGA
WICK REACH did not. Two lines' worth is always held whether the name needs
it or not, so nothing below can move.

`-- namefit` still wraps every name five galaxies generate at this font
and this width -- 94.4% one line, 5.6% two, none three -- and still fails
if that stops being true. It is a WIDTH check now rather than the evidence
for a height: the name sizes to its own lines like everything else here.

NO RESERVED HEIGHT, AND THE SLACK LIVES BELOW THE ROWS INSTEAD.

This block held a fixed height so that a long blurb could not push the
rows down -- and it worked, and the cost was a fixed gap under every short
description, which is most of them. Both readings of that trade have now
been looked at on screen and the gap is the worse one.

What makes giving it up cheap is that the panel ALREADY anchors its bottom
half: there is an expanding spacer between the rows and the in-range list,
so IN RANGE and JUMP sit where they sit no matter what happens above them.
Letting the header size to its own text spends that spacer rather than
moving anything a hand is aimed at. The rows shift by a line or two
between systems; the buttons do not move at all.
```

## In-range list sizing

Inside `_build()`, above `_hint = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)`:

```text
NO SPACER HERE ANY MORE. It used to hold the slack between the rows and
the in-range list, which meant the list itself had to declare a height --
and a declared height is a demand. The list expands instead, so it IS the
slack: it swells when there is little above it and shrinks when there is
much, and either way the thing below it stays on the screen.
```

Inside `_build()`, above `_neigh_scroll = ScrollContainer.new()`:

```text
A CEILING, because the list is as long as the galaxy is generous and JUMP
sits under it. Seventeen rows in a built-up ship's range pushed the button
off the bottom of the panel outright -- the one control the screen exists
to reach. Any list that grows without a bound will do that eventually; this
one just got there first.

Scrolled rather than truncated, because every row is somewhere you can
legally fly and hiding a destination is worse than making it a scroll.

AND THE CEILING WAS A FLOOR, which is why the button went off the bottom
again. `NEIGH_H` was written to `custom_minimum_size`, and a minimum size
is a DEMAND: with eleven rows of system facts above it the panel no longer
had 128 pixels spare, and the list took them anyway. Twelve systems in
range and JUMP was below the screen.

It expands into what is left instead. The floor is one row, so it never
vanishes; everything past that is whatever the header and the rows have
not already spent, and the button underneath cannot be pushed anywhere.
```

Inside `_fill_neighbours()`, above `func _quest_marks() -> void:`:

```text
AND NOTHING IS SET HERE ANY MORE.

This wrote `min(rows, NEIGH_H)` to `custom_minimum_size`, which reads like
a ceiling and is a DEMAND: Godot will not size a control under its minimum
for any reason, so with eleven rows of system facts above it the panel had
no 128 pixels spare and the list took them regardless. Twelve systems in
range and JUMP was off the bottom of the screen.

The container expands into what is left instead -- see where it is built.
A short list leaves its slack inside its own box rather than above it,
which is the same hole in a better place, and a long one scrolls.
```

## Legend colours

Inside `_build()`, above `for item in _legend_items():`:

```text
THE COLOURS COME FROM `MapGen.swatch` NOW, not from five literals here.

They had gone wrong. This drew SYSTEM in violet and STATION in pale blue,
which is what the chart used when a system was tinted by who HELD it. The
colours have been starlight for a while now and every glyph on the map is
`star_colour` -- so the legend was naming two colours that appear nowhere
on the thing it is a legend for, which is worse than having no legend.
```

## First survey card

Inside `_build()`, above `if "primer" in OS.get_cmdline_user_args():`:

```text
NO FIRST SURVEY CARD (Jon, Oct 13: "we can just remove the popup that
happens when you open the starchart for the first time"). The galaxy's
name, type and blurb stay on the no-selection destination panel, and the
legend stays in the corner KEY. The card is built only for ChartShot's
`primer` photograph, LAST so it would be the top child.
```

## Primer card

Above `func _build_primer() -> void:`:

```text
THE FIRST TIME YOU OPEN THE CHART IN A RUN, what this galaxy is and how to
read the thing you are looking at.

GALAXY_SCALE.md section 5. Two halves, and the second is the one that earns
it: the chart draws systems as coloured glyphs, hangs two range rings off
your ship and puts danger and fuel on every row of the list, and until now
nothing anywhere said what any of that meant. The galaxy blurb on its own
would have been a popup; the legend is the reason to build it.

It is NOT the only home for this. The no-selection destination panel says the
galaxy's name, type and blurb permanently, and says so in its own comment:
the card is the moment, the panel is the reference at jump forty.
```

## Primer legend text

Above `const PRIMER_LEGEND: Array[String] = [`:

```text
The half of the card that does not change with the galaxy.

SHORTER, NOT RESHAPED. These were three long sentences that came to seven
lines of small caps -- a wall you skip rather than a legend you read. Tried as
keyed rows first, which cut the length and read as a spec sheet: COLOUR and
CIRCLES are not things on the chart you can point at, so labelling them made
instructions look like data. They stay sentences and lose half their words.

TWO OF THE THREE WERE ALSO WRONG, which is worse in teaching text than
anywhere else in the game:

"Outrunning your dish means arriving somewhere you never surveyed" promised
exactly what `can_jump_to` forbids -- it wants `sensed`, so a system past your
sight is drawn, priced and REFUSED. Reach can outrun sight on purpose (see
`sense_radius_of`); what that buys is range you cannot spend, which is the
opposite of the danger this line invented.

"A short danger bar beside a long fuel one is a cheap trip somewhere awful"
is inside out. `_neighbour_row` has said it correctly for months: a FULL
danger gauge beside a NEARLY EMPTY fuel one is the cheap trip into somewhere
awful. This was a paraphrase of that comment that inverted it.
```

## Too deep refusal

Above `const DEPTH_ROW := "TWO RINGS IN AT MOST"`:

```text
WHY A STAR INSIDE THE REACH RING IS REFUSED, on its FUEL row: a jump goes two
rings deeper at most (`RunState.DEPTH_STEP`; Jon, Oct 27: "Two rings now").
It read ONE RING AT A TIME under Oct 22's one ring. Named here so `-- maptest`
can hold it, and the legend's second line, to the rule's count. "IN" because
TWO RINGS AT MOST, on a FUEL row, read as a limit on fuel (Jon, Oct 29, "fuel:B").
```

## Primer cost text

Above `func _primer_cost() -> Array[String]:`:

```text
What this galaxy does to a fuel tank, in the words section 4 made authorable.

`reach` and `density` are archetype constants and `roll()` does not jitter
them, so these thresholds do not move under a re-roll -- unlike `squash`,
which is jittered and is why the tilt line is decided per run rather than per
kind.
```

## Squash anisotropy

Inside `_primer_cost()`, above `var sq: float = float(Run.galaxy.get("squash", 1.0))`:

```text
THE ANISOTROPY, AND IT RUNS THE OTHER WAY FROM THE BRIEF.

GALAXY_SCALE.md section 4 describes north-south jumps as costing 1.5x to
3.6x LESS and lists measuring un-squashed as the alternative it did not
take. The code took it: `hop_distance` DIVIDES y by squash, so fuel is
spent on the round distance and not on the drawn one. The brief's note is
stale and section 4's "still open" ruling has already been decided by the
implementation.

MEASURED on a Lenticular at squash 0.372: the same drawn gap of 0.200
costs 3 fuel sideways and 6 up-and-down. So the player-facing fact is the
one section 4 warned about as the price of this choice -- two systems that
look equally far apart are not -- and this is the line that says so.
```

## Nowhere to go

Above `func _anywhere_to_go() -> bool:`:

```text
IS THERE ANYWHERE TO GO AT ALL -- asked of the whole map, the way every other
part of the game asks it.

This used to walk `Run.node_at().links` and say NOWHERE if none of THOSE was
jumpable. But links are TOPOLOGY -- the lines the chart draws -- and travel is
not link-gated: `reachable_from` is pure geometry, `in_range_of` scans the
whole map with it, and `can_jump_to` never mentions links. A node has a
handful of links and a great many systems in range.

So the panel announced NOWHERE over a list of places you could fly to, any
time your few linked neighbours were the unaffordable ones. Rare enough to be
hard to reproduce on purpose, which is why it survived: it needs the links to
be expensive while the rest of the neighbourhood is not.

`has_legal_jump()` is the same question asked by `check_stranded()`, which
ENDS THE RUN when it answers no. That is the right authority for a panel whose
message is "the tank is dry": the header now says NOWHERE exactly when the run
is one resolution away from being over, and never merely because the drawn
lines went somewhere costly.
```

## Settle fade

Above `func _settle() -> void:`:

```text
The facts about a system resolve; the system's NAME does not.

A destination panel that faded in whole would be a panel that flickers every
time the chart refreshes, and `_refresh` runs on far more than a new
selection. So this fades the ROWS only -- CONTAINS, the star, the danger, the
fuel -- and only when the selection actually changed.

The split is the point rather than an optimisation. The name and the blurb
are what the chart already knew: you pointed at a place and it is called
something. The rows are what the dish went and got. Snapping the identity and
resolving the readings is how the instrument would behave, and it is as far
as this goes -- the numbers themselves do not count up, because a count-up is
a lie about a value that was known all at once.

Modulate carries to children added after the tween starts, which is what
makes this a single line at the top of a rebuild rather than a callback at
the end of one.
```

## Neighbour count hint

Inside `_refresh()`, above `else:`:

```text
AND THE COUNT STAYS. `_fill_neighbours` set it four lines up and
this blanked it, so the one state you are guaranteed to see -- the
start of a run, nothing selected -- was the one state with a list
and no number above it. The hint was an instruction back when it
read "pick somewhere"; it is a count of the rows underneath it now,
and those rows are right there.
```

Inside `_fill_neighbours()`, above `_hint.text = "IN RANGE - %d SYSTEM%s" % [`:

```text
ONE NUMBER, because it is the only one the list below does not already
give you. This line used to carry two more.

"N UNTOUCHED" counted cleared systems six lines above a list that dims a
cleared system's name to `#55647a`, row by row. "N NAMED FIRST" counted the
ones `_notable` pins to the top -- each of which draws its own glyph, so a
station in the list is legible as a station without a number promising one.
Both were the panel reading its own rows aloud.

The count survives because you cannot see it: it is the number that decides
farm or dive, and it decides it before you have read a single row.

The pinning itself stays -- `_notable` still sorts. What is gone is the
warning about it, which existed to stop a player reading the list as
distance-ordered. Nothing in a row invites that reading: there is no
distance column, only a name, a danger gauge and a fuel cost. The label was
guarding against a misreading the panel never offered, and asking a
question of its own to do it.
```

## Contract only systems

Inside `_refresh()`, above `if Run.known_only_by_contract(_selected):`:

```text
A SYSTEM YOU ONLY KNOW ABOUT BECAUSE SOMEBODY IS PAYING YOU TO GO THERE.

It answers exactly one question — why is this circled — and refuses the
rest. No CONTAINS, no development, no security, no operators, because none
of that was in the offer: the manufacturer said go here, it did not say what here
is. Reading the panel and reading the contract give the same information,
which is correct, because the contract is the only source there is.

The jump button is left alone. Whether you can reach it is a question about
fuel and adjacency rather than about knowledge, and the answer does not
change because the place is unexplored.
```

## Class line removed

Inside `_refresh()`, above `_class("")`:

```text
NO CLASS LINE ON A SYSTEM AT ALL. Name, then blurb, with nothing between.

MEASURED: 7.0% of systems are inside a cloud (161 of 2289 across seven
galaxies), so the line this replaced was EMPTY for nineteen systems in
twenty -- and an empty Label still reserves a line of its font, so the gap
between a name and its description was a blank fact almost every time.

It read "PGC 5055 - SETTLEMENT" once: a galaxy catalogue number identical
for every system in the run, and a development word the DEVELOPMENT row
says again three lines below. Cutting that back to the nebula kept the one
part that was not noise -- but the panel was ALREADY saying it, down in the
WARNING group, and the header had been holding a line open to repeat it.
```

## Row order

Inside `_refresh()`, above `_rows.add_child(_row("CONTAINS", _contains(t)))`:

```text
THREE ANSWERS, IN THE ORDER YOU WANT THEM, and the order is the change.

It used to run CONTAINS, DEVELOPMENT, SECURITY, OPERATORS, MARKET, STAR,
BODIES, NEARBY, DANGER, FUEL -- which put the sky between the market and
the fuel bill, so the physical facts about a place were interrupted by
trade and then resumed as travel. Eleven rows in one column with no shape
to them is a list you read from the top every time.

WHAT IT IS, then WHO IS THERE, then WHAT IT COSTS. That is the order the
questions actually arrive in: you look at a system to find out what it is,
decide whether you want what is being sold, and commit the fuel last. The
gaps are four pixels rather than rules, because three separators in a
panel this narrow reads as three panels.
```

## Star row

Inside `_refresh()`, above `_rows.add_child(_row("STAR", MapGen.BINARY if t.twin and MapGen.twin_ok(t) else MapGen.star_kind(t), MapGen.star_colour(t)))`:

```text
WHAT IS IN THE SKY, which is the half of a system the panel never said.

It decides what you will be offered: a red hypergiant is the only place
`corona` and `flare_shelter` exist, a blue one is the only place the wind,
the glare and the scouring do, and a giant is what `slipping_orbit` needs.
The chart has painted this since the star colours landed -- this is the
row that says what the colour MEANS, so it can be learned rather than
guessed at.

In the star's own colour, so the swatch on the map and the words here are
obviously the same fact.
BINARY where it has two suns (ruling 20; Jon, Nov 1: "Let's call it Binary
instead of two suns", it read TWO SUNS): both ordinary, so the row says how
many rather than what kind, and is seen before the jump.
```

## No nebula row

Inside `_refresh()`, above `_rows.add_child(_gap())`:

```text
AND NO NEBULA ROW HERE, though one was written and taken out again.
`MapGen.hazards()` already returns "NEBULA" for an `in_nebula` system, so
the panel says it in the WARNING group at the bottom -- where it belongs,
because being inside gas is a thing that acts on the ship rather than a
thing to look at. A second row above would have been the same fact twice
in one panel, which is what this rework has spent its time deleting.

What that costs is the cloud's NAME, which the class line used to carry
and nothing here does now. It is still on the chart itself: hovering the
gas names it. If it should be on the panel too, the honest place is inside
the existing warning rather than in a row of its own.
```

## None vs unclaimed

Inside `_refresh()`, above `var who := "NONE"`:

```text
"NONE", NOT "UNCLAIMED", and the word is the whole change.

`DEVELOPMENT_NAMES[0]` is "Unclaimed" -- a real rung on the development
scale -- and this was a bare literal that happened to pick the same
word. Measured across 1938 systems in six galaxies: 416 are
development-zero, 484 have no berths, and 341 are BOTH -- so 18% of
systems printed UNCLAIMED on two consecutive rows.

The row is not dropped, though dropping it was the tempting fix. The
two facts are not the same one: 143 systems have no berths while being
a real outpost or settlement, and "nobody operates this place" is worth
saying about those. NONE is already this panel's word for an absence --
SECURITY: NONE on the Core, SURVEY: NONE on a contract system.
```

## Dock desks

Inside `_refresh()`, above `var desk := Contracts.dock_desk(t)`:

```text
A DOCK DESK (Jon, Nov 3: every station posts work): nobody holds the
place, and one manufacturer posts and takes its work there. Said, or
the chart draws a delivery square on a place it says nobody operates.
```

## Jump button reasons

Inside `_refresh()`, above `_jump.text = "NOT SCANNED"`:

```text
THE THIRD REASON, and it used to fall through to the fuel message.
`can_jump_to` is `sensed and reachable and afford`; the chain tested two
of the three and blamed the last one for everything left over, so a
ship with a full tank was told it was broke.
```

## Berth lock

Above `func _berth_lock() -> void:`:

```text
FROM THE BERTH, the station's own rule (`Router.cast_off`): docked, a jump the
chart would offer reads DOCKED and says how to leave (Jon, Oct 27: UNDOCK is
the only way out; it used to cast off and go, no undock seen); with crates
still on the pad, CANNOT UNDOCK.
```

## Neighbour sorting

Inside `_fill_neighbours()`, above `near.sort_custom(func(x, y):`:

```text
TELEGRAPHED FIRST, then nearest. Distance alone buried the four places the
chart actually names among fourteen it deliberately does not: RULING 1 says
every system but a station looks identical until you fly to it, so a list
sorted by distance is a list of near-identical rows with the notable ones
scattered through it.

This orders by what the chart ALREADY tells you and never by what a system
holds -- reading `options` here would be the chart answering the question
arrival is for.
```

Above `func _quest_marks() -> void:`:

```text
How far up the in-range list a system sits. Lower is higher.

ONLY WHAT THE CHART TELEGRAPHS. A contract target because somebody paid you to
find it, the core because it is the run, a station because it is the one node
type the chart names, a pulsar because it is placed against a nebula and you
can see the shell. Everything else is an ordinary system and they are
interchangeable from here BY DESIGN -- which is exactly why they sort below.

Cleared last, and still listed: knowing the nearby ground is already stripped
is what decides whether you farm on or dive.
The shown quest's tag and, for PLOT ROUTE, its route: nothing otherwise.
```

## Danger names

Inside `_neighbour_row()`, above `b.tooltip_text = "%s\ndanger %d of %d · %s · %d fuel" % [`:

```text
The exact numbers are still one hover away, which is where precision
belongs once the shape of the thing is readable at a glance.
THE RUNG BY NAME, beside the number. "danger 7 of 10" is precise and
says nothing about how bad 7 IS. The ladder it sits on has been driving
enemy pools, loot gates, hull tiers and station stock since the scale
widened, and it has never once been spoken. See `MapGen.tier_name`.
```

## Atomic clear

Above `func _clear(host: Node) -> void:`:

```text
Empty a container NOW, not at the end of the frame.

queue_free() defers to the end of the frame while add_child() is immediate,
so a rebuild left the old children and the new ones in the container together
for one frame before the old set vanished. In a VBoxContainer that reads as
the list doubling in length and then collapsing — which is why every click
made things appear and disappear. Removing from the tree first makes the
rebuild atomic; the nodes are still freed, just not while they are visible.
```

## Class line hiding

Above `func _class(s: String) -> void:`:

```text
The class line under the name — and NOTHING AT ALL when it has nothing to
say. An empty Label is not a zero-height Label: Godot reserves a line of the
font whether or not there is text on it, so a blank class pushed the blurb
down by a line and left a gap that read as a mistake. A hidden child is
skipped by the container outright, which is the only way to actually get the
space back.
```

## Region toggle

Above `func _on_view_dragged() -> void:`:

```text
Back to just the galaxy. Deliberately -1 rather than -2: the next refresh
must not helpfully pick a system again.
Everything the chart draws over the galaxy, off. Worth having as a button
rather than a debug flag: the galaxy is the best thing on this screen and the
systems are, unavoidably, 190 icons sitting on top of it.
Frame the neighbourhood the ship is standing in. Reads the CURRENT node
rather than the selection: the button is about where you are, and a
selected system three rings away is where you are going.
Lit while the view is held on your region, dim while it is not. EMBER and
QUOTE are the launcher's own pair, so the two toggles in the game read as
one idea rather than as two designs that happen to use brackets.
Dragging away UNTICKS the box and leaves the view alone.

The box says "the view is held on your region", and once you have dragged
it somewhere else that is simply no longer true. Zooming back out on top
of that would undo the drag you just made — the box is reporting, not
commanding.
```

## Local region key

Above `func _unhandled_key_input(e: InputEvent) -> void:`:

```text
L IS THE LOCAL REGION, on the screen rather than on the chart control.

It belongs here because the toggle does: `_on_region` repaints a button this
screen owns and then tells the chart what to do, and a shortcut that reached
past that would have the key and the button doing two different amounts.

`_unhandled_key_input`, so WASD keeps its own handler on the chart and
anything focused has had first refusal.
```

## Ladder UI fade

Above `var _strip_row: Control = null`:

```text
THE CHART'S UI, k of the way gone (`ZoomLadder`: it leaves before the camera
moves and comes back after it lands): the key, the corner toggles, and YOU
and the scale bar drawn over the galaxy. NOT the destination panel nor the
depth strip: the side bar and the toolbar stay through the move and swap in
place for the next screen's (`ladder_side`, `ladder_bar`, `SideSwap`; Jon,
Oct 13, "the side bar goes blank and then draws the new side bar").
```

## Glyph and gauge

Above `class MicroGauge extends Control:`:

```text
A node glyph. Shape carries the type, tint carries the region — so the chart
stays readable without a word under every node.
Countable cells, small enough to live in a list row.

The heat and energy gauges are the same idea at full size; this is the same
language shrunk to fit beside a star's name, so a glance reads "nearly full,
and red" without reading a number at all.
```

## Glyph pixel art

Inside `_on_jump()`, above `var type: MapGen.NodeType = MapGen.NodeType.SYSTEM`:

```text
A system, drawn as an object rather than a letter in a box.

The old glyphs were abstract marks on a raised tile — and the tile was
most of the problem: 173 of them turned the chart into a lattice of UI
chips laid over a galaxy instead of places inside one. These are
free-standing silhouettes with their own 1px outline, which is what lets
them sit on a starfield without a plate underneath.

Authored as pixel maps because that is how pixel art is authored. Working
them out as draw_rect arithmetic is how you end up with two bars and a
crossbar and call it a station.

Eleven inks, not four. The first set had outline, ink, one shade and one
emissive, which draws a SHAPE and cannot draw an OBJECT — every
glyph came out as a flat silhouette with a light in it. The extra stops
are what the hull sprites already use and what ART_CONTRACT calls the
single most important rule: a bright top face, a darker front wall, and a
bright lip where the two meet. Thirteen pixels is plenty of room for that
break; it was the palette that was short.

  .  empty          o  outline          %  lit face / rim
  #  ink (tint)     +  shaded wall      -  recess / underside
  *  emissive hot   @  emissive core    :  emissive falloff
  =  glass          ~  glass, shaded    !  cold light (beam)

Everything except the emissives is derived from the region tint, so a
glyph still tells you whose space you are looking at.
```

Inside `_on_jump()`, above `const _FIGHT := [`:

```text
Hostile: a dart nosing left, because enemies face left everywhere else in
the game and the chart should not be the exception.

Lit along the leading edge and dark under the belly, so the wedge reads as
a hull banked toward you rather than a triangle. Two pixels of glass sit
behind the nose and the thruster burns at the tail — the only warmth on
it, and pointing the way it is running.
```

Inside `_on_jump()`, above `const _STATION := [`:

```text
A hab ring with its lights on. Warm pixels are the tell: a station is the
only friendly thing out here, and warmth is only ever emitted, never ambient.

The ring is a torus seen at the same three-quarter tilt as everything
else: the top arc catches the light, the bottom arc falls away, and the
hub burns in the middle. Drawn flat it was a letter O with a spark in it.
```

Inside `_on_jump()`, above `const _EVENT := [`:

```text
An unknown signal: a burst, radiating. Reads at a glance as "something is
transmitting here" without resorting to a question mark.

Every ray falls off along its length — hot core, then the region tint, then
almost nothing at the frame edge. That gradient is the whole of the depth
here; there is no object to light. The uniform version read as a snowflake.
```

Inside `_on_jump()`, above `const _TWIN := [`:

```text
TWO SUNS (ruling 20, Oct 30): a system with a pair of stars wears the same
burst with a small second star at its lower right, warm (the companion is
the cooler, orange one, as the map paints it), where the burst's lower
right ray was -- so it reads as two suns at the chart's 13 pixels without a
new shape to learn, and stands in the same box (nothing to click moves).
```

Inside `_on_jump()`, above `const _DERELICT := [`:

```text
NOT DRAWN SINCE THE TYPE COLLAPSE, and kept rather than deleted. Every
system wears `_EVENT` now, but these are authored pixel art and the option
detail view is the obvious place a wreck or a contact wants a picture --
see ENCOUNTER_FLOW.md. Delete them if that never happens.

A hulk with a bite out of it and its pieces drifting off. Asymmetric on
purpose — a regular wreck reads as a building.

The torn edge is the darkest ink in the glyph and the intact plating above
it is the lightest, which is what makes the bite read as a hole through
the hull instead of a shape painted on it.
```

Inside `_on_jump()`, above `const _GOAL := [`:

```text
The hole itself: an accretion disc seen nearly edge-on, with the far side
of it lensed up over the top and down under the bottom.

Read it as three things. The wide bright band through the middle is the
disc; it breaks either side of the centre because the far side of it
passes BEHIND the shadow, and the unbroken band just below is the near
side passing in front. The arcs over and under are that same disc again,
bent right around the hole — which is the one piece of a black hole that
no other object in the sky does, and so the piece worth spending pixels
on at this size.

The middle is left EMPTY rather than drawn dark, and that is deliberate:
the glyph sits exactly on the galaxy centre, where the sky is
turning a real accretion disc around a real shadow (`ChartSky`). Leaving the shadow
transparent means the marker frames the animation instead of covering it.

The disc runs hot and the lensed arcs run cold, and that split is doing
the work: warm is the light source, the tint is the matter it is falling
through, and the arc under the hole is drawn a stop darker than the arc
over it. Flat, the whole thing was one red ring.
```

Inside `_on_jump()`, above `const _PULSAR := [`:

```text
An open ring with a beam tick either side.

The middle is deliberately EMPTY. The flashes layer lights the actual
neutron star at this exact point, and the first version of this glyph was
a solid cross that sat on top of it — so the one node type with its own
animation was the one node type whose animation you could not see. The
ring says "something is here" and then gets out of the way.

The ring is lit from the top and falls to a recess at the bottom, so it
reads as a shell of ejecta seen at an angle. The beam ticks are the only
COLD light in the set — a neutron star is not a furnace, and drawing its
beam in the same warm ink as a station window said the wrong thing.
```

Inside `_on_jump()`, above `const _START := [`:

```text
Where the run began: your own hull, nosing right.

It was drawn as the FIGHT dart mirrored, "because it is the same
shipyard", and read as one more contact among a hundred. The dart is not
drawn any more, so this is the only ship-shaped mark on the chart and is
unique by subtraction rather than by redesign.
```

Inside `_on_jump()`, above `_: return _EVENT`:

```text
EVERY SYSTEM WEARS THE SAME MARK. It used to be three -- a dart, a
hulk, a beacon -- which told you what was waiting before you flew
there. What is at a system is `options` now and the chart does not
say what they are, so the star is what every one of them gets.
```

## Too deep grey

Inside `_on_jump()`, above `const DIM := Color("#303236")`:

```text
A STAR IN REACH THAT A JUMP REFUSES AS TOO DEEP (`MapChart.too_deep_set`),
in one grey whatever its star: the dot zoomed out, the glyph's body
zoomed in (`ramp_for` with `dim`). Darker than any star you can go to and
than the far ones, and no colour in it, so it reads as off. Not the dead
blue grey of a cleared system (#37424f), which says "spent". Jon picked
this darkest of three on the Too-Deep Gray page (Oct 30, "Gray: B2");
it was #4a4e55.
```

Inside `_on_jump()`, above `var dim: bool = deep.has(node2.index)`:

```text
IN THE RING AND STILL REFUSED (ruling 13 A, Jon, Oct 27): a star the
drive reaches that lies deeper than one jump may go is drawn in one
dim grey (`Glyph.DIM`), lights and all, and stays so under the
cursor and when picked; the reticle, the brackets and the name say
which one it is. Drawn like the rest, it read as a place you could
go until JUMP said TOO DEEP. Its hover readout ends TOO DEEP.
```

## Glyph ramp

Inside `_on_jump()`, above `if dim:`:

```text
Region colours sit quietly behind sprites; as a glyph on a dark chart
they need lifting or the icon reads as a smudge. The ramp is built
from the tint every call rather than stored, because the tint is the
argument — a cleared system is drawn in dead grey and a Core system in
red from the same seven pixel maps.

Spacing is the point. lightened(0.62) against darkened(0.52) is a big
enough value break to survive being 13 pixels wide on a starfield;
closer stops than that and the shading turns back into one flat mass,
which is what the four-colour version was.
```

## Glyph halo

Inside `_on_jump()`, above `static var _halo_cache: Dictionary = {}`:

```text
A dark rim one pixel round a glyph, so it stands off the sky behind it.
The chart's galaxy is bright and busy now (Jon: "the systems icons just
fade into the starchart"), and a glyph laid straight on an arm or the
bulge loses its edge; a rim of the void round it gives it back. Only
its four sides, never the corners: a rim on all eight filled in between
a star's spikes and read as a heavy outline ("these are kinda too thick
you know in the border", Jon). Worked out once per glyph, from its own
pixels; how dark it is depends on the sky under it (`MapChart._UNDER`).
```

## Crosshair

Inside `_on_jump()`, above `const DASH := 2.0`:

```text
THE SECTOR MAP'S CURSOR, ON THE CHART ("angle the cursor of the
starchart to match the sector view", Jon): the two lines run along the
plane's own diagonals, so on screen they lean at its slant (TILT, the
sector map's and now the chart's), with a ring the size of a small world
lying flat on the plane under the cursor -- `sysmap/SectorCursor`'s
dash, notch, ring and strengths. The dashes count columns from the
frame's edge, so they hold still and only the lines move; nothing is
drawn across the black hole's shadow.
```

## Held keys

Inside `_on_jump()`, above `func _settle_walk() -> void:`:

```text
WASD, held. The same move a drag makes, so it goes through the same three
lines: the sky follows what the galaxy ACTUALLY did after the clamp, not
what the key asked for, or the background slides under a stationary
galaxy at the edge of the chart.

It counts as moving it by hand, so a held view lets go -- pressing a
direction is exactly as much "I am looking somewhere else" as dragging is.
A KEY-UP THAT NEVER ARRIVED CANNOT LEAVE THE CHART DRIVING.

`_walk` accumulates on key-down and subtracts on key-up, so it depends on
seeing both halves of every press -- and WIN+SHIFT+S is a press of S
followed by the operating system taking focus for the snip overlay. The
release goes to Windows, `_walk` keeps its DOWN, and the chart pans on
its own until you press and release S again to balance the books.

Checked here rather than only on focus loss because this covers every way
a release can go missing -- alt-tab, a shortcut, a lost window -- and it
can only ever CANCEL movement. That is what makes it safe next to
`_unhandled_key_input`: polling `Input` directly to START a pan would let
a keystroke meant for a focused field drive the chart, which is the exact
thing routing this through `_unhandled_key_input` was for.
```

## Scale bar

Inside `_on_jump()`, above `const RADIUS_LY := 50000.0`:

```text
How far across the galaxy is, so a bar can say a NUMBER.

`MapNode.gal` is normalised — a fraction of the disc radius — which is
the right thing for a map that only has to be self-consistent, and no
use at all to a reader asking how far a jump is. One constant turns the
whole chart into real units.

50,000 is chosen rather than measured: it is roughly the Milky Way's
radius, so the bar reads as a galaxy instead of a solar system. Nothing
in the sim depends on it — MapGen prices jumps off `gal` directly — so
this is a label, and changing it relabels without rebalancing.
```

Inside `_on_jump()`, above `func _draw_scale() -> void:`:

```text
HOW FAR IS THAT, in light years.

A zoomable map without one asks the reader to hold a scale in their
head across every zoom step. The bar is the standard answer and it is
cheap: pick the longest round number that fits the allowance, draw it,
print it.

Bottom LEFT. The tooltip follows the cursor and the party markers sit
with the ships, and both of those move; this does not, so it goes in
the one corner nothing else claims.
```

## Sky parallax

Inside `_on_jump()`, above `const PARALLAX := 0.5`:

```text
How hard the fixed sky slides against the galaxy when you drag.

Halved. Both fields keep their own SPREAD of rates — seven shells of
distant galaxies, twenty-two of halo stars — and that spread is what
actually carries depth, since layers disagreeing about how fast they move
is the whole effect. Amplitude only sets how far they travel, and at full
strength the background covered enough ground to read as the sky being
dragged past rather than as distance behind the galaxy.

One constant on purpose: the two fields have to move as one sky, so their
rates are not independently tunable numbers.
```

Inside `_on_jump()`, above `const FAR_PARALLAX := PARALLAX * 0.5`:

```text
And HALF of it again for the distant galaxies.

This is a deliberate exception to the sentence above, so it is written
down rather than folded into PARALLAX. The two fields still move as one
sky — one rate, one control — but they are not at one distance: the star
shells are foreground haze and the galaxies are supposed to be millions
of light years past everything, and at a shared rate they read as being
just behind the stars. Halving the far field is what puts them behind
it, and it costs nothing else, because nothing is measured against it.
```

## Mark halo key

Inside `_on_jump()`, above `const _UNDER := Color(0.0, 1.0, 0.0, 0.65)`:

```text
What the chart's marks stand on over the bright sky: the void, a rim of
it round every glyph and dot, and a softer one under routes and rings.
Drawn in a key colour (pure green) that `chart_marks.gdshader` turns into
the void, part see-through and only where the sky under it is bright --
over dark sky, where a mark already reads, it is not there at all (a
solid rim everywhere was "kinda too thick", Jon).
```

## Show all debug

Inside `_on_jump()`, above `var show_all: bool = false`:

```text
Debug: ignore the visited/reachable filter and draw every system.

RESTORED, dev-only, and the reason it came out is worth keeping: it
defeats the one thing the chart is for, which is the map you have EARNED.
That argument is about the PLAYER, and it still stands — this is behind
DevMode, like the card gallery and the manufacturer list, and for the same
reason. The three dev toggles exist to look at GENERATION: whether the
shells are spaced sensibly, how the lattice is wired, whether a galaxy
rolled something odd. None of that can be seen through a filter that hides
most of the galaxy.

Its absence read as a bug rather than as a decision, which is the other
half of why it is back: the link overlay -- SHOW REACH now, and it drew
the whole `links` lattice then -- painted edges over a chart that was
still hiding the systems those edges ran to, so the diagnostic showed
lines going nowhere and stations floating in the dark, stations being the
one type the filter always let through.

Nothing is reachable through it. Jumping has always been gated on
Run.can_jump_to(), so this reveals and never travels.
```

## WASD pan speed

Inside `_on_jump()`, above `const WALK_PX_PER_SEC := 320.0`:

```text
HOW FAST WASD WALKS THE CHART, in screen pixels a second.

320 crosses a 960-wide view in three seconds at the reading zoom, which is
the pace of somebody looking rather than somebody travelling. A drag is
for going somewhere; this is for reading along a route, and it should feel
closer to leaning than to flying.

Divided by the zoom, so it moves the same distance across the GALAXY at
every magnification -- otherwise zoomed in it crawls and zoomed out it
throws you across the disc, and the key stops meaning one thing.
```

## Zoom tick

Inside `_on_jump()`, above `const ZOOM_STEP := 1.12`:

```text
(`remembers_view`): the launcher's backdrop is the same class and must stay
silent and bare.
One wheel notch. A magnification LEVEL is a power of this, so the tick
lands once per notch, and a glide (LOCAL REGION) that crosses nine levels
runs nine ticks off quickly.
```

## Faint star tier

Inside `_on_jump()`, above `var _star_dim: PackedByteArray = PackedByteArray()`:

```text
The faintest tier of the field, flagged once at build time. While a drag
is actually in flight these are skipped: they are the dim wash between
the bright structure, they carry no shape on their own, and dropping them
costs well over half the pixels in a repaint. Halving the field wholesale
was the earlier attempt and it visibly dimmed the galaxy — this leaves
every bright star, the arms, the core and the lanes exactly as they are.
```

## Core stars

Inside `_on_jump()`, above `var _core_rad: PackedFloat32Array = PackedFloat32Array()`:

```text
The core's stars: their radius and their colour, kept as the stars
themselves rather than a separate population standing in for them.

A stand-in can match a count and still be obviously wrong. On an edge-on
galaxy the disc is a bright blue-white lane straight through the middle,
and replacing its stars with a warm gold field left the lane running up to
the core, stopping, and a different-coloured thing turning where it should
have continued. Inheriting radius and colour makes the core the same
galaxy as the rest of it — just the part that is moving.
```

Inside `_on_jump()`, above `var _core_ang: PackedFloat32Array = PackedFloat32Array()`:

```text
The angle each one was already at. Orbits used to take a hashed angle,
which threw away where the star actually WAS — so the arms stopped dead at
the core and a scrambled cloud turned inside it. Worse, the hash was fed a
strided index once the core overflowed, and a multiplicative hash on an
arithmetic progression lands on a lattice: the whole cluster bunched into
one arc. Keeping the angle fixes both. The arms now run continuously into
the core and wind as it turns, which is what a galaxy does.
```

## Sky cache

Inside `_on_jump()`, above `const SKY_FIELDS: Array[String] = [`:

```text
Everything above that _build_stars derives, by name.

Kept as a list rather than as thirty-four static vars because the cache
has to be saved and restored as a SET — one field left out is a chart
that draws with last galaxy's dust lanes over this galaxy's stars, and a
list you can read against the declarations above catches that by eye.

Everything in it is a Packed*Array or an int. Those are copy-on-write
value types, so storing one is a snapshot rather than an alias; a plain
Array or Dictionary in here would be shared by reference and the cache
would mutate under itself.
```

Inside `_on_jump()`, above `static var _sky_cache: Dictionary = {}`:

```text
The built sky, shared by every MapChart this process makes.

Router builds a NEW StarchartScreen on every visit, so an instance-level
cache was thrown away every time the player looked at the chart and
rebuilt from scratch on the next look — a quarter of a second of galaxy
maths to redraw a sky that had not changed. It is keyed by panel width as
well as by galaxy, so a resize still rebuilds; what it stops is paying for
the same sky twice.
```

## Nebula label height

Inside `_on_jump()`, above `var _neb_top: PackedFloat32Array = PackedFloat32Array()`:

```text
How far above its centre each cloud actually reached, MEASURED off the
pixels that survived the dither rather than taken from the radius it was
nominally built to. The two are nowhere near each other — lobes sit at
half to nine tenths of the nominal radius and the falloff then kills
everything past about six tenths of each lobe — so spacing the label off
the nominal figure hung it a couple of hundred pixels above the cloud
with clear sky in between, plainly labelling nothing.
```

## Flashes class

Inside `_on_jump()`, above `_flash = null`:

```text
THE FLASHES ARE THE SKY'S NOW. Every rendering style draws the pulsars'
beat and the supernovae in the sky itself, as gathered light with an
envelope (`ChartSky`), so the old pixel
strobes and gamma-ray bursts over it would be a second pulsar on every
pulsar. The class stays, unused, for the harnesses that time it.
```

## Warm sky

Inside `_on_jump()`, above `func warm_sky() -> void:`:

```text
Build the star field NOW, rather than on demand inside the first draw.

_build_stars() is the expensive half of this class — 350 to 420ms for a
galaxy it has not seen — and the first paint calls it lazily, so the cost
lands on whichever frame first paints the sky. That frame is then a
quarter-second long, and a quarter-second frame is one the display gets to
show partway through.

Calling it here moves the work to a frame of the caller's choosing, before
anything is visible or moving. The draw that follows finds the key
unchanged and returns immediately. The layers' textures and meshes are
made here too, for the same reason.
```

## Chart built ahead

Inside `_on_jump()`, above `const CHART_AT := Vector2(655.0, 419.0)`:

```text
THE FIRST CHART OF A RUN, BUILT WHILE THE HULL IS PICKED (Oct 27, on
Jon's Mac). The run's star field was built the first time its chart was
drawn: the click on STARCHART, or Tab, held the old screen still for the
whole build -- 350-420 ms on the PC, 300-560 ms on Jon's Mac -- before the move
began. `Router.new_run` (and CONTINUE) start it here instead, on a worker,
from a copy of the run's galaxy (`_ahead_src`), so it is done long before
anyone opens the chart; the chart's own `_build_stars` finds it in the
cache (`_take_ahead`) and draws the same stars it would have built.

The field is laid out for the chart's size, which only the screen's
layout decides: the size the last chart had this session, or the one it
has had since the field went under the navigation screens (`CHART_AT`;
`-- sheet=ChartAheadTest` fails if the layout moves it). Built for a size
the chart turns out not to have, it is simply not used: the chart builds
its own, as before.

Not headless and not in the sim, which start runs by the hundred and never
draw a chart (`ahead_always` for the test).
```

## Pan slack

Inside `_on_jump()`, above `const PAN_SLACK := 0.5`:

```text
How far past "the rim is in the middle of the view" a drag may go, as a
fraction of the view.

0.5 is the ordinary convention -- the rim reaches the near EDGE, so the
galaxy may be pushed exactly out of frame and no further. Worth knowing
before trusting that: `ex` is the disc's NOMINAL radius, and the stars fade
out well inside it, so at full pan the screen really is empty rather than
showing a sliver. Lower this if drifting into the void feels like being
lost rather than like looking away.
```

## Remembered view

Inside `_on_jump()`, above `if remembers_view and size.x > 0.0 and _lad.is_empty():`:

```text
RECORDED HERE RATHER THAN AT EVERY MUTATION. Zoom and pan are moved by
the wheel, by a drag, by `glide_to`'s animation and by both framing
helpers; hooking all of them would leave one out. Reading the result
once a frame cannot.
(not while the zoom ladder holds the view: what is remembered is where
the chart rests, not the dive into your star on the way out)
```

## Framing the title

Inside `_on_jump()`, above `func frame_to(screen: Vector2, fill: float) -> void:`:

```text
Zoom so the galaxy's outer edge lands at `fill` times half the short side
of `screen`.

For anything that draws the sky on a control BIGGER than the view. The
launcher does: its sky is a square as wide as the screen's diagonal, so
that rotating it can never sweep a corner into frame. _radius() is derived
from the control, so on that square it is nearly twice what it would be on
the screen, and a zoom picked by eye against the chart put the galaxy at
about 1.6 screen-widths across — a title screen showing only the core.

Framing is a question about what the player can see, so it takes the view
as an argument rather than reading a size that is deliberately too big.
```

## Navigated chart flag

Inside `_on_jump()`, above `var remembers_view := false`:

```text
Whether this chart is the one the player navigates.

`LauncherScreen` builds a MapChart too, as the menu's galaxy backdrop, and
the view memory lives on the CLASS -- so a chart panned in a run was
recorded by one instance and restored by the other, and quitting to the
menu showed a galaxy sitting off centre in exactly the way you had left the
starchart. Reported as, correctly, "LOL".

Off by default so anything decorative stays where it was put; the screen
that owns the real chart opts in.
```

## Arrival framing

Inside `_on_jump()`, above `func _arrive() -> void:`:

```text
What an arrival does to the view, which is what LOCAL REGION is FOR.

ON, the chart follows you: every arrival re-frames on the region you are
standing in, so the ship is always in the middle of what you are looking
at. OFF, the chart stays exactly where you left it -- same zoom, same pan
-- so you can park on a distant approach and keep watching it across
several jumps.

The toggle used to persist while doing NOTHING on arrival, which read as
broken: it stayed lit and the view sat wherever the last jump had left it.
```

## Core ownership

Inside `_on_jump()`, above `func _own_at(r: float, clear: float) -> float:`:

```text
The star field is built in two lists, the core's and the rest, split at
this radius by `_own_at`: an old live layer's ownership rule, kept because
the split decides which random numbers each star draws. The sky reads
both lists the same way (`ChartSky`).
Which layer OWNS the stars at this radius — a different question from how
fast they are going, and it needs a different curve.

Splitting them by speed alone put half the stars in each layer wherever
the speed happened to be halfway, and at those radii the motion is still
plainly visible — so you got stationary stars sitting among obviously
moving ones. Weighting ownership hard toward the live layer keeps the
cached field out until the motion is genuinely almost nothing, which is
the only place a static star can hide next to a moving one.
```

Inside `_on_jump()`, above `var x: float = clampf(r / maxf(1.0, clear), 0.0, 1.0)`:

```text
Total inside three quarters of the core, then a smooth handover.

This was pow(motion, 0.30), which is a curve rather than a rule, and a
curve leaves a tail: measured, it left thirteen static stars in the
innermost fifth of the core but two hundred in the next and nearly a
thousand in the outermost — about twenty-two hundred motionless stars
sitting inside a region where everything is supposed to be turning.
A few percent of a very dense place is still a crowd.

The live layer takes ALL of it out to 0.72 and hands back over the last
quarter. A sharp edge is safe here because the two layers share one
rule: whatever this gives up, the other picks up, so the total density
is flat across the seam however abrupt the split.
```

Inside `_on_jump()`, above `var seed := (_gseed() * 2654435761 + 24601) & 0x7fffffff`:

```text
Whether a drawn position falls inside the region the live layer owns.
Measured in UNSQUASHED space, which is the fix for the dark crescents
above and below the core: the orbiting stars are laid out on the
galaxy's ellipse, but this test was a circle, so a band was cleared of
static stars that the orbiting ones never reached. The hole itself
stays round — that is the accretion disc's inner radius, not this.
Everything about the core is measured in DRAWN space, and is round.

Ownership used the unsquashed radius so it would line up with the
ellipse the orbits were laid out on, and that was the root of a whole
family of bugs. On a flattened galaxy a star sitting a few pixels
above the hole has a large unsquashed radius: it reads as far out,
keeps its place in the static field, and sits there motionless right
beside the thing everything else is orbiting. Same arithmetic put
stars inside the hole earlier.

A black hole is round on screen whatever the inclination of its
galaxy, and so is the cluster around it. Measuring the distance you
can actually see makes the rule mean what it says: near the hole is
near the hole.
```

## Live core radius

Inside `_on_jump()`, above `return maxf(_radius() * 0.21, _shadow_r() * 5.0)`:

```text
Never smaller than the disc needs: a galaxy that rolled a large hole
would otherwise have its accretion disc pushed through the boundary.
Every star in here is redrawn sixty times a second, and the count is
derived from the area, so this radius IS the frame budget. At 0.22 it
was nine thousand moving particles and 23ms a frame. The speed
gradient still reads across a smaller region; nine thousand stars
turning did not read any better than three thousand.
```

## Chart scale

Inside `_on_jump()`, above `return minf(size.x * 0.5 / DISC, size.y * 0.5 / (DISC * ChartSky.TILT)) * 1.9`:

```text
Twice the frame. Twenty-four rings inside one screen puts them about
twenty pixels apart — closer than a system glyph is tall — so the chart
is drawn large and navigated. Zoom out to ZOOM_MIN to see all of it.

Fitted to the plane the chart is DRAWN in (TILT), not the galaxy's own
squash: every galaxy lies at the sector map's angle now, so a squash fit
only made the round ones small -- an elliptical at 0.92 came out 450 px a
galaxy unit against a spiral's 622 (the showcase's audit). One scale
for every kind.
```

## Visible set

Inside `_on_jump()`, above `func _visible_set(here: MapGen.MapNode, reach: Array) -> Dictionary:`:

```text
Everything currently on screen, as a set of indices.

Built once per frame and shared with hit-testing, because "what is drawn"
and "what can be clicked" answering differently is how you end up with a
tooltip hovering over empty space.

Pointing at a reachable system adds ITS neighbourhood too — that is the
question you are asking by pointing at it. Without that the onward routes
were drawn to systems the filter had hidden, so hovering a candidate gave
you dotted lines running off to nothing.
```

## Sight vs reach

Inside `_on_jump()`, above `if selected >= 0:`:

```text
ENGINE RANGE IS NOT SIGHT. This used to add everything `in_range()`
returns, which is pure geometry and knows nothing about the dish -- so a
ship with a big thruster and no sensors was shown systems it had never
resolved, could select them, and got a fuel quote for them.

Ruled 2026-08-28: "you still shouldn't be able to SEE those sectors
unless you have the sensor range to see them." Reach beyond sight is
real and allowed -- it is simply range you cannot spend until you fit a
dish, and an unspendable range draws nothing.

Nothing is lost by dropping the clause: anything reachable AND sensed is
already in by `Run.charted`.
```

## Projection

Inside `_on_jump()`, above `func turn() -> float:`:

```text
THE CHART'S ONE PROJECTION, the sector map's angle with the galaxy turned.

Positions stay in the galaxy's own coordinates: `MapNode.gal`, which
MapGen prices jumps by (`hop_distance` measures in the disc's own plane,
`gal.y / squash`), and which NebulaField speaks. The chart shows that
plane tipped to the sector map's 0.38 and turned by the galaxy's angle:
  in the plane     d  = (gal.x, gal.y / squash) * radius
  turned           d' = d turned back by `turn()`
  on the screen    centre + (d'.x, d'.y * eff) * zoom
`eff` is how flat the disc looks from there (`ChartSky.eff_of`). The
systems, the routes, the rings, the trail, YOU, the party, the Hellbender,
the markers, the tooltips, the pulsars and the bursts all go through
`_proj`; a click comes back through `_to_galaxy`, its inverse, so what is
drawn and what can be pointed at never disagree. The sky turns by the same
angle (`ChartSky`), so a system stays on the arm it was placed on.
```

## Centre pixel

Inside `_on_jump()`, above `func centre_px() -> Vector2:`:

```text
The galaxy's centre on the screen, on a whole pixel: the sky's blocks are
anchored to it and the systems are drawn from it.
ON THE PIXEL THE SKY SETS THE GALAXY ON: once the sky has settled after a zoom
(`ChartSky.settled`) it moves the galaxy a whole 2x2 block of its own art at a
time, on the even pixel at or below the centre, so its far stars never hop back
on a pan; on an odd centre the systems stood a pixel off the light they belong
to. Hidden while the chart's height was even and a test's drag even too, until
the top plate's new height (d1256496) made the chart 419 px tall and the centre
odd at rest -- `solidtest` 1.93 -> 2.28 px after a drag. While the sky holds a
zoom it draws about the exact centre, and the marks stay on its whole pixel.
```

## Hidden means hidden

Inside `_on_jump()`, above `var under_badge := CustodianBadge.covers(get_global_transform_with_canvas() * mm.position)`:

```text
Hidden means hidden. The rule used to be that pointing at a
system brought it back — hiding as a way to look PAST the
interface rather than to turn it off — but a toggle that
still answers the cursor is not a toggle, and every hover
still drew a glyph and a tooltip over the galaxy you had just
asked to see on its own. The nebulae still answer, because
they are the galaxy.
Nothing under the Custodian's badge on the goal line: its own
tooltip opens there, and the chart's would open under it. A
press there is still the chart's.
```

## Sky zoom pivot

Inside `_on_jump()`, above `var eff: float = zoom / maxf(0.0001, was)`:

```text
The sky is anchored at the cursor too, and that is the whole point.
Zoom pivots the galaxy about the pointer, so the galaxy is perfectly
still THERE — and translating the sky by a share of the pan correction
moved it uniformly, hardest at the one spot the galaxy was guaranteed
not to move. Pivoting both about the same point means they agree under
the cursor and diverge with distance from it, which is what parallax
actually looks like.

Only the offset is pivoted, never the contents: the objects translate
as a rigid group, so no pixel is ever rescaled and nothing crawls.
It also falls out correctly at the zoom limits — a clamped zoom gives
an effective factor of 1, so the sky simply does not move.
```

## Pan limit

Inside `_on_jump()`, above `var ex := _radius() * DISC * zoom`:

```text
THE RIM MAY BE PUSHED TO THE EDGE OF THE VIEW, NOT ONLY TO ITS MIDDLE.

This was `maxf(half a screen, ex)`, which reads as a sensible floor and
is really a REGIME CHANGE. `ex` is the disc's radius in screen pixels,
so it overtakes half a screen at about zoom 0.62, and the two sides of
that switch behave differently: below it you may shift the galaxy 1.47
disc-radii off centre, above it exactly 1.00 and never more, because
panning by `ex` is by definition "put the rim in the middle of the
view". So the drag room collapsed as you leaned in and then stayed
pinned -- which is what "it stops too soon when I zoom in" was.

Adding half a view instead of taking the larger of the two makes one
rule at every zoom: pan until the rim reaches the NEAR EDGE of the
view. That is strictly more room than before at every zoom, it is the
ordinary convention for panning something bigger than its window, and
it still cannot lose the galaxy -- one more pixel and it would be off
screen, so it never is.

The `maxf` is gone rather than relaxed: `ex + half` is already at least
half a view, so the floor it provided is built in.
```

## Range cache

Inside `_on_jump()`, above `var _range_key: String = ""`:

```text
`Run.in_range()`, remembered.

It walks every system and works the ship's thrust out afresh for each,
about 3ms a call, and the chart asked it on every redraw and on every
mouse motion -- three quarters of a dragged frame once the sky had moved
to the GPU. Its answer depends on where you are, which map, how far the
ship reaches and how the galaxy is tilted (`hop_distance` divides by the
squash), and on nothing a pan, a zoom or a hover can change. Those are the
key, so fitting a thruster or jumping is a new answer and looking around
is not.
```

## Too deep set

Inside `_on_jump()`, above `func too_deep_set() -> Dictionary:`:

```text
THE STARS INSIDE THE REACH RING THAT A JUMP STILL REFUSES, as a set of
indices: near enough for the drive, but deeper than one jump may go
(`Run.too_deep_only`; ruling 13 A, Jon, Oct 27). Remembered with
`_in_range`, on the same key, since it is the same kind of answer.

Geno met these near the top of the map, where the tilted chart puts rings
close together on the screen: a star beside YOU, lit like the rest, and
TOO DEEP only once it was clicked. The chart draws them dimmed
(`Glyph.DIM`).

The rule is read through `Run.too_deep_only` and nothing here, so how many
rings a jump may go (`RunState.DEPTH_STEP`) can change under it. The core
is left out: it has its own mark on the black hole, and `too_deep_only`
counts it from any distance, not only from inside the ring.
```

## Hit testing

Inside `_on_jump()`, above `func nodes_near(r: Rect2) -> Dictionary:`:

```text
THE SYSTEMS A CLICK COULD PICK ANYWHERE IN `r` (local), as
`[index, screen position]` in `_node_at`'s order, with the radius it
picks by: what `node_among` asks instead of the whole map.

For A.S.H.'s `covers`, which asks at every 3 px of her box. `_node_at`
rebuilds the visible set over every system (410: 0.8 ms) on each call,
and some 1,500 calls a box made 1.2 s, every tenth of a second while she
taught the chart's list -- the game frozen until she was clicked away
(Jon, Oct 20: "SUPER laggy and unresponsive"). Asked once here, the
answer is the same to the system: a point picks a system within the
radius of it, so any system it could pick stands inside `r` grown by it.
```

## Reach overlay

Inside `_on_jump()`, above `if show_links and hovered >= 0 and hovered < Run.map.size():`:

```text
WHAT THE SYSTEM UNDER THE CURSOR CAN REACH.

This used to draw every `links` entry from every system at once --
both ends, so each line twice -- and at four hundred systems that
is a grey fog rather than a diagram. It was also a picture of the
WRONG GRAPH: links are what the chart draws, while `can_jump_to` is
`sensed` plus `reachable_from` plus fuel and never consults them.

Its old comment said it "answers the question no in-game view can:
whether MapGen wired the galaxy up sensibly", and that was true
while links gated movement. The modern form of the question is
whether a system can be flown out of, which is what this shows.

ONE SYSTEM AT A TIME, because the reachable graph is DENSER than
the link graph, not sparser -- a radius reaches further than the
lattice does. Drawing all of it would be worse than what it
replaces. Pointing at a system is the question.
```

## Route lines

Inside `_on_jump()`, above `reach = []`:

```text
Two kinds of line, and they should not look alike. Where you HAVE
been is settled fact: solid, white, unbroken. Where you COULD go is
a proposal: dotted, dim, obviously provisional. Drawing both as
plain lines in different colours made the chart look like one
network when it is really a record and a set of options.
ONLY TO SYSTEMS THAT ARE DRAWN. `in_range` is geometry and knows
nothing about the dish, so a fast ship with no sensors got dotted
lines running out to nothing -- the destination glyph was correctly
hidden and the route to it was not. A line to an invisible place is
worse than either showing both or hiding both.
```

## Remembered systems

Inside `_on_jump()`, above `if not node2.sensed and node2.index != here.index:`:

```text
REMEMBERED, NOT SEEN, and both are meant to be on the chart: where
you have been is a historical marker and stays, which is a ruling.

So the whole job here is telling them apart. Drawn identically, a
chart carrying a run's worth of history looked like a dish reaching
far past its own ring, and the ring read as a lie. Dimmed, the lit
systems are the ones you can see RIGHT NOW and the ring is their
boundary; the dim ones are places you have been.

Not `cleared`'s dead grey, which says "spent". These keep their
region colour because they are still real places you might route
back through -- they are simply not on the dish this minute.
```

## Core marker

Inside `_on_jump()`, above `if node2.type == MapGen.NodeType.CORE and not (show_all or node2.index == here.index`:

```text
THE CORE IS ITS BLACK HOLE, AND MARKED ON IT ("the core icon should
be in the center of the black part of the black hole AND the
selection reticle should be there too", Jon): its glyph on the
shadow, the brackets and YOU with it, no name. Its band in the
flare's amber, not the near-white that read as a second, smaller
hole inside the black ("I don't like the white outline on the
center of the black hole").
(the core is always on the chart's list -- it is where the run
ends and can always be jumped toward -- but its icon shows only
when it is in your sensors, as any system's would: "have the black
hole icon only show up when you're in range of it", Jon. The hole
itself is sky and always there.)
```

## Local region framing

Inside `_on_jump()`, above `var _glide: Tween = null`:

```text
FRAME WHERE YOU ARE, not the ring you are on.

The first version framed the whole LAYER, which is right in the abstract
and useless in practice: at the rim a layer is most of the galaxy's
circumference, so the fit came out at ZOOM_MIN and the button appeared to
do nothing on exactly the screen you start the run on.

A neighbourhood instead: everything within `span` of you in galaxy
coordinates, which is the same measure MapGen prices jumps by. That is
the region you can actually reach, and it frames the same way whether you
are on the rim or in the core.
A view change in flight, so a second press can cancel the first.
```

Inside `_on_jump()`, above `if n <= 1:`:

```text
EVERY GALAXY'S FRAME IS THE SYSTEMS NEAR YOU, a ball's as a spiral's (Jon,
Oct 21, for 0.3.0). His "frame:A" of Oct 18 framed a ball whole -- the box took
in the core and the ball's lit radius (`ChartSky.ball_lit_gu`), because its
systems lie on the disc's plane, drawn mostly below the core, and a frame of
them alone cut the ball off at the top -- so L took a ball from 0.42 to 0.54-0.84
(PGC 6236 0.58) against a spiral's 1.8, and read as doing nothing. The ball is
out of the frame now, as a spiral's arms are; L is for the systems in reach.
```

## Glide

Inside `_on_jump()`, above `func glide_to(z: float, p: Vector2, secs: float = 0.55) -> void:`:

```text
Move the view to a zoom and a pan over time rather than at once.

The sky is settled EVERY STEP, against the values from the step before.
`_settle_sky` is written as a delta — pivot by however much the zoom just
changed, translate by however far the pan just moved — so feeding it the
whole journey at the end would pivot the starfield about the wrong point
and slide it past where it belongs.
```

Inside `_on_jump()`, above `var pz := zoom`:

```text
WORK OUT WHERE THE SKY ENDS UP FIRST, then travel to it.

Settling per step against the step before accumulates: each frame
pivots by a pow() of a fraction of the zoom change, and a chain of
those does not add up to the single pivot the whole move deserves.
On screen the galaxy trailed the systems and caught up at the end,
which is exactly what an accumulating error looks like.

The end state is computable in closed form, so the sky is simply
LERPED to it alongside the zoom and the pan. All three then move as
one and arrive together.
```

Inside `_on_jump()`, above `var sf: float = pow(zoom / maxf(0.0001, z0), SKY_ZOOM_POWER)`:

```text
SOLVED AT THIS ZOOM, never interpolated towards the end.

The sky's offset is a pow() of the zoom RATIO, and the zoom is
travelling on a cubic ease. Lerping the sky between its start and
end is therefore right at both ends and wrong everywhere between
them, which on screen is the galaxy trailing the systems and
catching up at the last moment. Evaluating the same closed form
against the CURRENT zoom is exact at every step.
```

Inside `_on_jump()`, above `func center_on_ship(z: float) -> void:`:

```text
Travel there, or simply be there.

The snap is the same two assignments the remembered-view restore makes,
and that path was already smooth -- there is no third way of moving the
chart, only the question of whether the move is watched.
Frame the ship at a given zoom. The screenshot harnesses both need
exactly this and were each poking zoom, pan, `_clamp_pan` and
`_repaint_sky` by hand, which is the part a caller doing it by hand
forgets.
```

## Snap on arrival

Inside `_on_jump()`, above `func frame_region(here: MapGen.MapNode, span: float = 0.24,`:

```text
`animate` false SNAPS, which is what an ARRIVAL wants.

`glide_to` tweens for half a second and repaints the galaxy on every frame
of it. That is right for a PRESS -- you asked for the view to move, and
watching it travel is how you keep your bearings -- and wrong for a jump,
where the screen is rebuilt at ZOOM_MIN and then visibly zooms itself in.
Reported as jitter with LOCAL REGION on, and absent with it off for exactly
this reason: the off path assigns and repaints once.
```

## Sky settle

Inside `_on_jump()`, above `func _settle_sky(was: float, before: Vector2) -> void:`:

```text
Move the SKY to match a jump the view just made.

The starfield is not drawn from `pan`. It has its own offset, and only
dragging and `_zoom_at` were maintaining it — so setting `zoom` and
`pan` directly moved the systems and left the galaxy where it was. On
screen that reads as the local region being pasted onto the middle of
an unmoved galaxy, and it corrected itself the moment you dragged,
which is what made it look like a repaint bug rather than a missing
term.

Two motions, in the order the view made them: pivot about the frame
centre for the zoom, then translate by however far the pan moved.
`_repaint_galaxy` is the other half — the starfield is a cached image,
so a queue_redraw alone repaints everything except the thing that
moved.
```

## Nebula boundary

Inside `_on_jump()`, above `func _draw_neb_edges() -> void:`:

```text
The boundary of the cloud under the cursor, and only that one.

Every cloud outlined at once was a set of rings competing with the systems
for attention — and an outline is an answer to "what am I pointing at",
which is a question you are only asking about one of them.

Drawn as the union boundary of its lobes: every point on a lobe that is
not inside another one. That is the actual silhouette, so the line agrees
with the gas rather than circling it approximately, and it is exactly the
region the tooltip answers for.
```

## Reach ring

Inside `_on_jump()`, above `func _draw_reach_ring(c: Vector2) -> void:`:

```text
How far the ship can go, drawn where it can be seen.

AN ELLIPSE, NOT A CIRCLE, and that is the whole of it. `galaxy_pos` draws
the disc foreshortened -- `Vector2(cos(a), sin(a) * squash)` -- and
`hop_distance` measures in the disc's own plane, dividing `gal.y` back out
by that same squash. So the reachable set is a circle in the galaxy and an
ELLIPSE on the chart: at squash 0.62 you reach about 1.6x further sideways
than you do up or down, in screen pixels.

Reported as a bug -- a system plainly nearer than a reachable one that
could not be reached. It is not one; it was just impossible to see. A ring
that is visibly wide and flat says "down costs more than across" without a
word of explanation, and says the galaxy is tilted while it is at it.

Whole pixels and a step count tied to the radius, for the reason `_dotted`
gives below: a ring walked in continuous space lands its dashes on
fractions of a pixel and shimmers as you pan.
```

## Sight and reach rings

Inside `_on_jump()`, above `if show_sight:`:

```text
TWO RINGS, BECAUSE THERE ARE TWO LIMITS AND THEY ARE NOT THE SAME ONE.
Sight is `base * (SENSE_FLOOR + sensors * SENSE_REACH)` and reach is
`base * thrust_reach()`, so the dish ALWAYS outruns the engine -- 1.39x
at no sensors at all, near 3x at ten.

Only the inner one used to be drawn, which left the outer boundary with
no line on it: systems lit up outside the ring you could see and there
was nothing to say why. Reported as "I can see outside my range
circle?", which is exactly right and exactly the design.

The gap between them is what a dish BUYS, and now it is a visible band
rather than an inference from which dots happen to be lit.
AND THE OUTER ONE HAS TO BE VISIBLE, which took a second report to
notice. Drawing it was not enough: at alpha 0.34 in single pixels, two
on and three off, on a ring with a far bigger circumference than the
inner one, the dots land further apart AND dimmer than reach's -- so on
a dense starfield the only boundary a player could actually find was the
orange one, and every system in the band between them read as a bug.
Measured after the fact by `-- chartfilter`: nothing was wrong with the
filter, the line saying where the limit was simply could not be seen.

So sight carries reach's weight and a LONGER dash. Two boundaries at the
same rhythm in two colours are one boundary drawn twice; a long dash
reads as an outer limit and a short dot as an immediate one, which is
what they respectively are.
```

## Contract tooltip

Inside `_on_jump()`, above `if Run.known_only_by_contract(n.index):`:

```text
THE SAME REFUSAL THE PANEL MAKES, and it has to be made twice or it is
not made at all: the tooltip prints type, place and danger, which is
precisely the survey the destination panel just declined to give. One
hover and the withholding is undone.

Fuel survives, because reachability is a fact about your tank and the
link you are standing next to rather than about the place. So does
TOO DEEP, for the same reason.
```

## Party markers

Inside `_on_jump()`, above `func _draw_party() -> void:`:

```text
Where the rest of the party is.

Drawn OUTSIDE the visibility filter, deliberately. The chart otherwise
hides a system you have never been to and cannot reach, which is right for
a place and wrong for a person: a partner four shells coreward is the one
piece of information you most want and the one you can least reach. It is
also what makes `docs/coop-design.md` §7 legible — danger tracking the deepest
ship is only a leash if you can see how deep they are.

`docs/coop-design.md` §9 rules that this should be gated on sensor range, with
a last-known position and an age stamp outside it. There is no fog in the
game yet, so this shows everybody. When fog arrives it gates the position
going ONTO the wire rather than coming off it, and nothing here changes.
```

Inside `_on_jump()`, above `_diamond(c, 6.0, _UNDER)`:

```text
Backed in ink, and the name shadowed with it.

Not a polish pass. The deepest ship is the one this marker exists
to show — `docs/coop-design.md` §7 makes everybody's danger track it —
and deep means over the core, which is the brightest thing on the
chart. Unbacked, the one marker that matters most was the only one
you could not see.
```

Inside `_on_jump()`, above `func party_marks() -> Array:`:

```text
Where each partner's diamond goes: `[[slot, screen point, label row], ...]`.

OFF YOUR OWN SYSTEM, NOT ON IT. A partner in the system you are in was
drawn on its centre -- the glyph your ship is marked on -- so the two of
you were one picture "totally on top of each other" (Oct 22 playtest).
There the diamonds stand to the upper right of your marker, one under
another, each with its name beside it (row -1 says "name beside");
elsewhere a diamond is on its system and names stack above it.
```

## Hellbender marker

Inside `_on_jump()`, above `func _draw_hellbender() -> void:`:

```text
The galaxy's other harvester, drawn wherever the host last said it was.

OUTSIDE any visibility filter, like the party and the work, and the
fiction pays for it: the hellbender is the hottest thing flying, and heat is
the one signature this game says you cannot hide. That is also its
balance — a threat you can always see is a threat you can always route
around, and routing around it has a price the map charges in salvage.
```

## Quest markers

Inside `_on_jump()`, above `func _draw_quests() -> void:`:

```text
Where the work is. A ring in the issuing manufacturer's colour, on every system an
open contract points at.

THE CHART IS WHERE A CONTRACT BECOMES PLAYABLE. A fetch that names "Kappa
Thorn Reach" and then leaves you to find it is a memory test, and the
station board is four screens away from the only page that plots a jump.

Drawn OUTSIDE the visibility filter, like the party markers above and for
the same reason: the filter is right about places and wrong about
intentions. A job you signed for is a fact about YOU, and hiding it until
you happen to fly within sensor range of it would hide it exactly while it
is still a decision.

Not a route and not an arrow. It says where, and leaves the whether alone —
see ContractData's header on why nothing here pushes you anywhere.
A SYSTEM SOMEBODY PUT SOMETHING ON, and the name of the thing.

A CHEVRON POINTING DOWN AT IT, and every other shape was taken. The chart
speaks in rings for contracts -- one for a fetch, two for a hunt -- in
diamonds for the party and the hellbender, and in four corner ticks for
YOU. Corner ticks were the first thing I drew here and they were wrong:
gold ticks beside amber ticks is the same marker in two colours, and the
one meaning "you are here" is the one you least want doubled.

A SQUARE, and it took three tries to get there. A filled triangle was too
heavy -- nothing on this map is filled -- and an open chevron was two
strokes floating over a star with nothing tying them to it.

The three markers are now three shapes at the same weight: a SQUARE for a
quest, a DIAMOND for the hellbender, and the corner brackets for YOU. All
outlines, all a pixel wide, told apart by form rather than by colour --
which matters most zoomed out, where colour is two pixels and shape is
the only thing left.

The name rides above it, which no other marker carries and which is the
one thing a quest has that a contract ring does not.

IT IGNORES THE VISIBILITY RULE, and that is the point of it. The chart
deliberately hides systems you have never been to and cannot reach,
because "a system you can neither see nor go to is not information you can
act on" -- and a quest is the one thing on the map that IS. You cannot act
on it this minute; you can route toward it, which is the entire reason it
was placed four jumps deeper instead of handed to you.

The name goes ABOVE. Hovering already prints a system's own name below it,
and two labels on one node stacked on each other.
```

## Delivery berths

Inside `_on_jump()`, above `for manufacturer in _work_berths:`:

```text
AND WHERE IT GETS HANDED OVER, which is the third thing to mark and the
one that was missing. A fetch and a hunt ring a place before you go; a
finished job and a heat contract have to ring a place you come BACK to,
and a heat contract never had a target at all. Every berth of that
manufacturer, because delivery is to the manufacturer rather than to the desk that
posted it.

A square rather than a ring, and filled: this is not somewhere to look,
it is somewhere to land.
THE NEAREST FEW, NOT ALL OF THEM. A manufacturer holds berths all over the
galaxy and marking every one drew twelve squares across the disc, which
reads as a rash rather than as directions — and the question a player is
actually asking is not "where could I hand this over" but "where is the
closest place I can". Three is enough to offer a choice of routes and
few enough to be a marking.
```

Inside `_on_jump()`, above `func _nearest_berths(manufacturer: StringName, want: int) -> Array:`:

```text
The closest berths of one manufacturer, by galaxy distance from where you stand.

Distance rather than jumps, deliberately. A route is a fuel question that
the neighbour list answers properly and a straight line cannot, and a chart
marking that pretended to know the route would be wrong the first time a
link did not exist. This says WHICH WAY, and leaves the how to the list.
```

## YOU marker

Inside `_on_jump()`, above `func _draw_you(p: Vector2, tiny: bool) -> void:`:

```text
THE LABEL ONLY. This used to draw corner brackets as well, at 21 pixels
with 5-pixel arms -- and `Glyph.draw_glyph` has always bracketed the
current node too, at 16 with 4, in the same FLARE. So the ship sat inside
two nested boxes that were meant to be one, close enough in size to read
as a rendering fault rather than as a design.

The glyph's are kept because they are drawn WITH the node and scale with
it; this one is a label and does the job the glyph cannot.
```

## Galaxy rim

Inside `_on_jump()`, above `u *= 1.0 + 0.55 * pow(t, 8.0)`:

```text
The outermost few percent of stars are stretched well past the
nominal edge. Without this the disc simply stops at r_max — every
star inside, none outside — and a galaxy with a hard boundary
reads as a picture pasted onto the starfield. Spreading the last
few percent over half again the radius makes density decay instead
of truncating, and only that outer tail moves at all.
```

## Nebula dither

Inside `_on_jump()`, above `const _DITHER4 := [`:

```text
Ordered dither, 4x4, indexed by position in GALAXY space rather than on
screen. The art contract allows this and nothing else, and a nebula is
mostly edge: a random stipple where the gas thins out reads as noise on
the screen, a fixed threshold pattern reads as gas. Keying it to the
galaxy rather than to the viewport is what stops the pattern crawling
across the cloud when you pan.
```

## Dark nebula extinction

Inside `_on_jump()`, above `func _extinct(p: Vector2) -> float:`:

```text
How much a dark nebula blocks whatever is behind it, 0 to 1.

A dark nebula is the one kind defined by what it HIDES, and the clouds
are drawn BEFORE the arms so that arm stars sit in front of the gas —
which is right for gas that glows and exactly wrong for gas that does
not. The result was a dust cloud with the full star field shining
through it, which is the one thing a dark nebula must never look like.

Smoothstepped so the cloud has an edge you can see into rather than a
rim, and cheap enough to ask per star: a few lobes, no trig, and an
instant zero in a galaxy that rolled no dark clouds at all.
```

Inside `_on_jump()`, above `return e`:

```text
Returned RAW. The diffuse arm field tempers this down at its own call
site, because taking every one of those left a smooth black disc with
a hard rim — a hole cut in the galaxy rather than dust in front of it.
Bright point sources are the opposite case and want the full value:
a globular or a foreground-bright field star showing through at even
a quarter strength is precisely what stops a dark cloud reading dark.
```

## Static pixel gate

Inside `_on_jump()`, above `func _static_ok(p: Vector2, t: float) -> bool:`:

```text
Whether a point in drawn galaxy space may hold a static pixel.

The live layer owns the black hole's neighbourhood outright and fades in
across a band on the way out of it, so everything cached has to fade out
across the same band or the handover shows as a ring. `t` is the pixel's
own random number, which is what makes that fade dithered rather than a
hard edge. The four original field passes each inline this; everything
added since calls it.
Whether a piece of static material — nebula, dust lane, remnant — may sit
here. The nebulae, lanes and remnants go through this; the stars, arms and
bulge go through the same two rules inline.

It was still using a fixed blend band from before the core was rewritten,
and it had no test against the hole at all. That is why the disc lane ran
straight across the middle of an edge-on galaxy: it is dust rather than
stars, so it never met either of the rules the stars were following, and
sat frozen among the orbiting field with a slice of it inside the hole.
```

## Region tint

Inside `_on_jump()`, above `func _region_tint(at: Vector2) -> Color:`:

```text
What colour the gas around here is, taken from the nearest system.

This is the art direction's rule about the void carrying region
signatures, applied to the only thing on the chart big enough to carry a
wash: a cloud sitting in Korvan space glows rusty amber, one on a
migration route glows teal, and the Core's neighbourhood glows red. So the
sky tells you whose space you are looking at before you point at anything.
```

## Nebula ramps

Inside `_on_jump()`, above `func _neb_ramp(base: Color, hue: float, sat: float, val: float,`:

```text
One four-step ramp for one tone of one cloud: fringe, low, body, and a
lit core that only emission gas gets.

Clouds are built from three of these at once rather than one, because a
single ramp is what makes a nebula read as a splotch — a shape filled in.
Real gas is not one temperature: it is patches of different ionisation
sitting against each other, and that is most of what gives a cloud its
interior. The variants stay NEAR each other on purpose — a few hundredths
of a turn of hue, a few percent of saturation. Push them further apart and
the cloud stops being one object.
```

## Nebula layers

Inside `_on_jump()`, above `func _pn_reach(kind: int, a: float) -> float:`:

```text
Nebulae, as the art direction specifies them: layered translucent masses,
dithered edges, coloured per region.

Appended BEFORE the arms so arm stars draw in front of them. Gas you can
see stars through is gas; gas that occludes them is a sticker laid over
the galaxy. The dark half of the same material is a separate pass that
runs AFTER the arms, because a dust lane only reads as a lane when it
hides the stars behind it.
How far out a planetary's gas reaches at this angle, as a multiple of its
nominal radius. Build-time only, so it can afford to be readable.
```

## Cloud colour

Inside `_on_jump()`, above `var pull: float = 0.88 if cloud.hollow > 0.0 else 0.68`:

```text
Weighted toward the gas rather than the region: region colours are
chrome, chosen to sit quietly behind an icon, and a cloud built out
of one at full strength comes out the colour of the panel border.
The region pulls the hue over; it does not set it.
The kind decides the hue and the region pulls it over — a
planetary is oxygen green wherever it is, but a green one sitting
in Korvan space leans amber.
A shell keeps far more of its own colour than a diffuse cloud
does. The region tint is chrome — it exists so gas sits quietly
behind an icon — and at 0.68 it was pulling the planetary's
oxygen green and the remnant's filament teal to within a few
points of each other, which is most of why the two were hard to
tell apart. A shell is a bright, compact, high-contrast object;
it can afford to be its own colour.
```

## Nebula sampling

Inside `_on_jump()`, above `var px := clampi(int(rad * rad * 0.62), 1200, 12000)`:

```text
Enough samples that the blocks overlap through the middle and only
separate out at the fringe, which is the point at which a scatter
of dots stops reading as dots. The first pass ran at a third of
this and the clouds were invisible underneath their own labels.
Raised with the block size halved: a quarter of the area per pixel
needs more pixels to read as the same body of gas, and the wash
lives in the static arrays so it costs a rect apiece and nothing
to derive.
```

Inside `_on_jump()`, above `px = int(float(px) * (4.0 if cloud.kind == NebulaField.Kind.PLANETARY else 3.4))`:

```text
A shell puts every pixel it has into a thin annulus rather
than spreading them through a volume, so it needs fewer than
a solid cloud of the same radius — but a planetary is also
the smallest object here by a distance, and the budget goes
with the SQUARE of the radius. Without a bump it was getting
about a tenth of the pixels of its neighbours and came out as
a faint smudge.
The remnant spends its budget over a much wider, fainter band
than the planetary and throws most of it away again at the
arc gaps, so it needs the larger share despite being the
larger object. The planetary now fills its interior as well
as its rim and wants enough left for both.
```

## Shell lobes

Inside `_on_jump()`, above `var nl := lobes.size()`:

```text
lobes.size(), NOT a literal 3. A planetary and a remnant are gas
thrown outward from a single point, so NebulaField gives them ONE
centred lobe — and this loop was indexing three of them. Two
thirds of every shell's pixels were read out of bounds: radius
zero, offset zero, the whole budget piled onto the exact centre,
where the hollow test then threw it away. That is why a supernova
remnant drew as an empty circle with a few strays in it.
```

## Shell wall

Inside `_on_jump()`, above `var wall: float = NebulaField.EXTENT * 0.80`:

```text
A shell, sampled AS a shell. The wall used to be carved
out of a solid cloud by remapping the density falloff,
which had two problems: almost every sample fell outside
the band and was discarded, and because the falloff is
smoothstepped, the surviving wall landed at about a third
of the radius — a small faint ring adrift inside a large
boundary circle, with nothing between the two.

Placing samples in the wall directly costs nothing, wastes
nothing, and puts the gas where the hover outline is.
```

Inside `_on_jump()`, above `wall = NebulaField.EXTENT * 0.64`:

```text
Pulled in and spread wide. A remnant is thousands of
years past the explosion: the front has broken up,
slowed unevenly and begun mixing back into the medium
it swept. It is not a shell so much as a REGION, and
smearing it over half its own radius is what stops it
reading as a drawn ring. The centre comes in to match,
so the gas still mostly sits inside the outline.
```

## Remnant ragged

Inside `_on_jump()`, above `var wob: float = sin(a2 * 3.0 + twist_k) * 0.36 \`:

```text
Ragged, and incomplete. A shock front does not expand
into a vacuum — it ploughs into gas that is lumpy, so
it runs ahead where the medium is thin and stalls
where it is thick. Three harmonics wobble the wall,
and a slower one takes whole arcs of it away, which is
what makes a remnant read as something torn rather
than something drawn.
```

## Planetary interior

Inside `_on_jump()`, above `filled = true`:

```text
The inside of a planetary GLOWS. The star that shed
the envelope is still sitting in the middle of it and
still ionising it, so the interior is not empty — it
holds the same oxygen light as the rim, only fainter
for having less gas along the line of sight.

Drawing it as a bare ring was the single thing that
made these read as remnants: a hollow outline is what
is left when something has gone, and this one has not
gone anywhere.
```

## Planetary shape

Inside `_on_jump()`, above `var pu: float = u * _pn_reach(cloud.shape, a2)`:

```text
A planetary is one star's envelope, thrown off in one
go and seen at whatever angle it happens to present:
smooth, unbroken, and elliptical because it is tilted
rather than because it is deformed. Where the remnant
is torn, this is intact — that contrast is the whole
distinction between the two.
```

## Nebula tone

Inside `_on_jump()`, above `var tone: float = 0.5 + 0.20 * sin(local.x * tf + twist_k * 0.6) \`:

```text
Which tone, from a field at a much lower frequency than the
filaments — so brightness and temperature vary independently
and the cloud does not come out banded.
Three terms, none of them a multiple of another. Two put the
tones in clean diagonal bands across the cloud, which reads as
two clouds overlapping rather than as one with structure.
```

## Nebula blocks

Inside `_on_jump()`, above `_star_big.append(2)`:

```text
Every tier is a block, the bright ones included. Drawing the
core at full resolution and the wash at a quarter of it was
the obvious economy and it erased the cloud's whole interior:
single pixels of the bright steps disappeared between blocks
of the dim ones, so what was left was a flat even mat with no
middle to it. A nebula has to have a middle.
```

## Nebula stars

Inside `_on_jump()`, above `if cloud.kind == NebulaField.Kind.PLANETARY:`:

```text
The stars that lit it. Only a cloud that is actively forming them
gets them: a planetary is one dying star's envelope, a remnant is
what is left after the star went, and a dark cloud has nothing
lighting it at all.
The star that shed it, still sitting in the middle. A planetary is
the one nebula with an obvious source, and it is what makes the
ring read as a ring around something.
```

## Dust lanes

Inside `_on_jump()`, above `var n := 0 if (int(g.arms) <= 0 or gas < 0.35) \`:

```text
No arms, no density wave, nothing to pile the dust into a lane — and a
galaxy that has run out of gas has nothing to make one out of either.
The globules below still run: they belong to the clouds, not to the
arms, and a barless ring galaxy has clouds without having lanes.

A lane runs along the INNER edge of an arm, which is where the wave
piles material up, and it is why a spiral arm has a bright side and a
dark side instead of fading off symmetrically both ways.
```

## Globular clusters

Inside `_on_jump()`, above `func _build_clusters(r_max: float) -> void:`:

```text
Globular clusters. Old, dense, and out of the plane — which is the whole
point of drawing them. Everything else on this chart lies in the disc, so
a knot of stars plainly sitting above it is the cheapest thing available
that says the galaxy is a solid object rather than a picture of a spiral.

Deliberately NOT squashed: the halo is a sphere, and a sphere in
projection is a circle however flattened the disc in front of it is.
```

## Pulsars

Inside `_on_jump()`, above `func _build_remnants(r_max: float) -> void:`:

```text
The flashing star at each pulsar.

This used to draw a small shock shell around every pulsar as well. That
shell is now redundant and was actively misleading: a pulsar only exists
inside a supernova remnant or a planetary nebula, and both of those are
already drawn — as hollow clouds, at their real size, by the nebula pass.
Ringing the system with a second, smaller shell of its own put two shock
fronts on the chart for one explosion.

So all that is left is the star itself, which `Flashes` lights.
```

Inside `_on_jump()`, above `for raw in _clouds():`:

```text
No map — the launcher. Pulsars are placed by MapGen, which marks a
SYSTEM inside a remnant as one, so with no systems there were no
pulsars and the title screen's remnants sat there with nothing at the
centre. A supernova remnant without its neutron star is the one thing
in this sky that is actually wrong rather than merely absent.

Straight from the cloud instead: one per REMNANT, at its centre, which
is where the star that threw the shell has to be. Planetary nebulae get
nothing, same as in a real run — they are low-mass envelopes and leave
a white dwarf.
```

## Gamma-ray bursts

Inside `_on_jump()`, above `func _draw_bursts(ci: CanvasItem, t: float, c: Vector2, w: float, h: float) -> void:`:

```text
Gamma-ray bursts: a single pixel arriving brighter than anything else on
screen, with a cross of light around it, gone in under a second.

Rare on purpose. The whole effect is that you mostly do not see one, and
the one you do catch out of the corner of your eye makes the sky feel
like somewhere things are still happening.
```

## Corner word shadow

Above `var shs: Array[Label] = []`:

```text
A SHADOW UNDER THE WORDS, as the chart's own labels have (THE HELLBENDER's): with no
plate, ember words on a galaxy's warm light close in -- a giant elliptical at zoom 2
fills the corner with its own orange -- were lost in it (Nov 5). A Button draws no
shadow (and an outline on this 8 px face filled the letters in), so a Label behind it
(`show_behind_parent`) says the same words a pixel down and right, in black, kept
to the button's text each time it draws
(all the way round, Nov 5's review: a shadow down and right only left THRUSTER
REACH's orange readable by its shadow alone over a giant's gold, so the black words
lie a pixel each way and down-right, a ring the words sit in)
```
