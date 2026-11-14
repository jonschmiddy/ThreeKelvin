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

Since Jon, Nov 11 ("Can we vertically align the top of the thruster range /
sensor reach with the top of the GOAL: REACH THE CORE"), the first one's words
start on the goal line's row, to the pixel, rather than BAR_PAD down from the
chart's top (`_level_corner`). The goal keeps its fixed place (`GoalLine.place_at(1)`),
so the toggle is placed off it: at the goal's top plus its backing's padding, and
one text line tall so a Button's centring puts its words at its top. It is placed
again whenever the chart's rect changes. The second toggle stays 14 px under. The
system map and LOCAL have nothing at the top right of the picture to share the row.
FlyClickShot reads both rows off the picture and holds them equal.

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

Inside `_refresh()`, above the rows:

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

NOV 9 (stripped-down UI, item 5): docked, JUMP is not drawn at all, whatever
the star picked. A greyed DOCKED button looked like a way out that did
nothing, one of four on the berth. One plain line, UNDOCK FIRST, stands
where JUMP was and says the DOCKED line on hover. The HUD's greyed LOCAL tab
stays as it was (Jon kept it).
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

Above `var type: MapGen.NodeType = MapGen.NodeType.SYSTEM`:

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

Above `const _FIGHT := [`:

```text
Hostile: a dart nosing left, because enemies face left everywhere else in
the game and the chart should not be the exception.

Lit along the leading edge and dark under the belly, so the wedge reads as
a hull banked toward you rather than a triangle. Two pixels of glass sit
behind the nose and the thruster burns at the tail — the only warmth on
it, and pointing the way it is running.
```

Above `const _STATION := [`:

```text
A hab ring with its lights on. Warm pixels are the tell: a station is the
only friendly thing out here, and warmth is only ever emitted, never ambient.

The ring is a torus seen at the same three-quarter tilt as everything
else: the top arc catches the light, the bottom arc falls away, and the
hub burns in the middle. Drawn flat it was a letter O with a spark in it.
```

Above `const _EVENT := [`:

```text
An unknown signal: a burst, radiating. Reads at a glance as "something is
transmitting here" without resorting to a question mark.

Every ray falls off along its length — hot core, then the region tint, then
almost nothing at the frame edge. That gradient is the whole of the depth
here; there is no object to light. The uniform version read as a snowflake.
```

Above `const _TWIN := [`:

```text
TWO SUNS (ruling 20, Oct 30): a system with a pair of stars wears the same
burst with a small second star at its lower right, warm (the companion is
the cooler, orange one, as the map paints it), where the burst's lower
right ray was -- so it reads as two suns at the chart's 13 pixels without a
new shape to learn, and stands in the same box (nothing to click moves).
```

Above `const _DERELICT := [`:

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

Above `const _GOAL := [`:

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

Above `const _PULSAR := [`:

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

Above `const _START := [`:

```text
Where the run began: your own hull, nosing right.

It was drawn as the FIGHT dart mirrored, "because it is the same
shipyard", and read as one more contact among a hundred. The dart is not
drawn any more, so this is the only ship-shaped mark on the chart and is
unique by subtraction rather than by redesign.
```

Above `_: return _EVENT`:

```text
EVERY SYSTEM WEARS THE SAME MARK. It used to be three -- a dart, a
hulk, a beacon -- which told you what was waiting before you flew
there. What is at a system is `options` now and the chart does not
say what they are, so the star is what every one of them gets.
```

## Too deep grey

Above `const DIM := Color("#303236")`:

```text
A STAR IN REACH THAT A JUMP REFUSES AS TOO DEEP (`MapChart.too_deep_set`),
in one grey whatever its star: the dot zoomed out, the glyph's body
zoomed in (`ramp_for` with `dim`). Darker than any star you can go to and
than the far ones, and no colour in it, so it reads as off. Not the dead
blue grey of a cleared system (#37424f), which says "spent". Jon picked
this darkest of three on the Too-Deep Gray page (Oct 30, "Gray: B2");
it was #4a4e55.
```

Above `var dim: bool = deep.has(node2.index)`:

```text
IN THE RING AND STILL REFUSED (ruling 13 A, Jon, Oct 27): a star the
drive reaches that lies deeper than one jump may go is drawn in one
dim grey (`Glyph.DIM`), lights and all, and stays so under the
cursor and when picked; the reticle, the brackets and the name say
which one it is. Drawn like the rest, it read as a place you could
go until JUMP said TOO DEEP. Its hover readout ends TOO DEEP.
```

## Glyph ramp

Above `if dim:`:

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

Above `static var _halo_cache: Dictionary = {}`:

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

Above `const DASH := 2.0`:

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

## Jump plate

Above `const JUMP_H := 56`:

```text
STRIPPED-DOWN UI C3, "size is importance" (Jon, Nov 9, his pick from the
page; the mockup is tk-scratch/ui-audit/mockups/C3_size_is_importance.png):
each screen's one action is its biggest thing. On the chart that is JUMP,
which was a plain 24 px button under a 60-100 word panel, quieter than the
map's GO. It is now a 56 px ember plate, JUMP in the heading size with the
star's name under it in a child Label (`_jump_to`), the refusal word (TOO
DEEP, NOT ENOUGH FUEL, ...) on a dark plate of the same size so the reason
stays readable and nothing moves between the two states. `_jump.text` keeps
the word alone, as the harnesses read it.

The panel shrinks to what decides the jump: the name, DANGER, FUEL and the
WARNING lines, plus a contract-only system's CIRCLED BY and PAYS. The blurb
shows only for the galaxy at rest (`_blurb`); the survey rows went to the
star's hover tag (`MapChart.survey_lines`).

ONE CALL, for Jon: the mockup also dropped the IN RANGE list for a count.
The list stays here, because it is the one place the reachable stars' danger
and fuel sit side by side, and the tutorial's chart and fuel lessons point at
its rows (`Hints`, `HintActs`). Dropping it is a tutorial change (B1-B3).
```
