The reasoning behind `tkg/scripts/ui/HudBar.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Built once

Above `const STAT_GAP := 4`:

```text
Persistent top bar: navigation, hull, heat, and the economy.

SHIP and MAP live here rather than inside each screen, so they are in the same
place everywhere. SHIP greys out during combat instead of disappearing — you
cannot refit mid-fight, and a button that says so beats one that vanishes.

BUILT ONCE, UPDATED IN PLACE. It used to free every child and remake them on
each of three signals, which cost more than it looks:

- The tabs were destroyed and remade under the cursor, losing hover state and
  flickering — very visible when clicking through chassis on the select
  screen, which emits ship_changed on every click.
- Freeing is deferred to end of frame, so for one frame the bar held both
  sets of children and reported twice its real width. Everything above it
  grew to match; on the star chart, whose sky is cached against panel width,
  that threw the cache away and rebuilt forty thousand stars — about 180ms,
  on every screen change, for a layout nobody ever saw.

So refresh() now only writes values and states. Nothing here is constructed
after _ready.
```

## Readout gaps

Above `const STAT_GAP := 4`:

```text
How far a readout's label sits from its number, and how far one readout sits
from the next. THE SECOND MUST BE THE LARGER -- that is the whole of the rule,
and it was inverted once: six inside against the row's five between, so
"CREDITS 40 EXOTIC 2" bound 40 to EXOTIC rather than to its own word.

TWELVE CAME DOWN TO EIGHT. Twelve was set while the economy sat in the middle
of the bar with a divider on either side of it; at the right-hand end, with
nothing after FUEL, that much air read as the readouts drifting apart rather
than as a group. Eight against four is still plainly two to one, which is all
the rule asks.
```

## Nav tabs

Above `var _tab_system: Button`:

```text
The sector map (Jon: "rename system to sector"). `_tab_sector` is LOCAL beside it: the side-on view, which
reads COMBAT in a fight and STATION on the map or the chart looked at from a
berth (Jon: "local would become combat and station"); at the berth itself,
LOCAL greyed (Jon, Oct 27: UNDOCK is the only way out).
```

Above `var _tab_comms: Button`:

```text
COMMS (Jeremy, a playtester, Oct 23: "Give me an option to revisit all
communications"): everything A.S.H. has said this run, newest first, her
voice to play again (`CommsPanel`). After QUESTS, and like it no count ever.
Measured: the row wants 702 of 932 px with it (832 in developer mode).

RE-MEASURED WITH DATA (science, Nov 4), against the clip's 932, not the
panel's 944: `-- stationshot` through render.sh reads 750 (880 in developer
mode), so DATA costs 47. The worst case FuelTest builds (a party's tab, over
the heat cap, 9999 credits, 99 DATA) wants 927, five pixels to spare, and
1057 in developer mode, which clips its right end. The next thing on this
bar has those five pixels, so it takes room from something else.
```

Inside `_build()`, above `_tab_sector = _tab("STATION", _go_here)`:

```text
--- LEFT: where you can go.

Local | Sector | Starchart. The page you are on is lit rather than
merely disabled, so the nav says where you are as well as where you can go.
(NO SHIP TAB. Jon: "I guess you can also remove the SHIP tab on the left."
Your ship opens where it is drawn -- click it on LOCAL, or in the
Shipyard when docked -- and everything the refit page did is in that
cutaway. `ShipScreen` stays for the harnesses that drive it.)
ONE TAB, TWO NAMES. Docked, on the map or the chart, this reads STATION and
goes back to the station (at the berth itself it reads LOCAL, greyed:
UNDOCK is the only way out, Jon, Oct 27); flying, it reads LOCAL and goes
to LOCAL. It is the same slot either
way because it is the same idea -- "the place I am parked" -- and a second
tab that appears and disappears at a station would move STARCHART
sideways every time you tied up.
(NO ARCHIVE TAB either. Jon, Oct 22: "Let's also get rid of the ARCHIVE.
From both the top left and the main menu. It was a cool idea, but not
for a procedural game.")

The action dispatches at CLICK time rather than being rebound on docking:
nothing on this bar is constructed after _ready, and swapping a Callable
is one more piece of state to keep in step with the label.
```

Inside `_build()`, above `_row.add_child(_tab_sector)`:

```text
HELD AT THE WIDTH OF THE LONGER WORD. STATION is a character wider than
SECTOR, and without this the two tabs to its right -- and with them the
gauges, and with them the whole middle of the bar -- shuffled six pixels
sideways every time you tied up or let go.

MEASURED AFTER add_child, NOT BEFORE. A Button takes its font from the
theme it inherits through the tree, so an unparented one measures itself in
Godot's default face and reserves the wrong number. `_row` is already in
the tree by the time _build() runs, so the child is too the moment it is
added, and the minimum is then taken in Silkscreen.
```

## Bar width

Inside `_ready()`, above `var clip := Control.new()`:

```text
THE BAR MUST NOT BE ABLE TO WIDEN THE GAME.

A PanelContainer takes its minimum from its child, and this row's minimum is
the sum of every tab, gauge and readout on it — 983px with dev mode on. The
HUD is the first child of `Main`'s column, so that minimum became the
column's, and the column's became the MarginContainer's, and every SCREEN
below inherited it: at a 960 window each page was laid out 983 wide and hung
23px off the right edge. One row nobody could fit made every panel in the
game overflow, and it looked like each screen had a margin bug of its own.

The row now lives in a clipping wrapper whose own minimum is zero, so the
window sizes the HUD rather than the HUD sizing the window. If the bar ever
genuinely does not fit, it loses its right-hand end instead of shoving the
rest of the interface off screen — a readout you cannot see is a smaller
problem than a layout nobody can trust.

This is the third tab added to this bar in a day. The next one costs
nothing.
```

Inside `_ready()`, above `_row.add_theme_constant_override("separation", 5)`:

```text
Six, not ten. The bar carries about twenty children, so the separation
alone was two hundred pixels — more than any single readout on it — and
four of those pixels per gap is the difference between the whole bar
fitting a 960 window and losing its last readout off the end. Nothing is
removed and nothing is renamed; the air between things is just slightly
less generous.

FIVE NOW, and the same lever for the same reason. `-- stationshot` prints
what the row wants against what it has, so the next person to add
something here can check rather than guess.
```

## Rebuild

Above `const ROW_H := 20`:

```text
Throw the bar away and build it again.

The dev switch decides which tabs EXIST, not which are visible, so repainting
is not enough — the row has to be constructed a second time. Widgets.clear()
rather than a bare queue_free(): the old tabs must be gone before the new ones
are added, or the row lays out both for a frame.
How tall the bar is, now that its wrapper cannot take a height from the row.
```

## Freed tab fields

Inside `_build()`, above `_tab_cards = null`:

```text
THE OPTIONAL TABS ARE FORGOTTEN FIRST, and this is a bug fix rather than
tidiness.

`_rebuild` frees every child of the row and builds it again. When dev mode
goes OFF, the branch that makes these two does not run -- so the fields
went on holding the buttons that had just been freed, and every refresh
after that handed a dead Object to `_state`.

IT DID NOT FAIL WHERE YOU WOULD EXPECT. `_state` opens with `if b == null`,
and a freed reference is not null -- but it never reached that line either:
the call is REJECTED AT THE ARGUMENT, because a typed parameter will not
accept a previously-freed object. No guard inside the function can catch
it.

It also did not fail immediately. `Widgets.clear` calls queue_free, which
is deferred, so the rebuild's own refresh still saw live buttons and wrote
correct values; the throw waited for the NEXT refresh a frame later. That
is why turning dev off ON THE LAUNCHER -- where there is no run and refresh
returns early -- gave a bar that only broke once a run started: every tab
and gauge built, every tab lit correctly, and then nothing.
PARTY still showing, both gauges empty, no credits and no fuel, because the
throw landed between the tab states and the values.
```

## Heat width

Inside `_build()`, above `_row.add_child(_hintable(_heat_text))`:

```text
NO WIDTH RESERVED HERE ANY MORE, and it is the layout that retired it
rather than a change of mind.

It reserved the over-cap form -- "00 — 00 HULL" -- because that is the long
one and it appears mid-fight, which is the worst possible moment for the
bar to jump sideways. That was true while the economy sat directly to its
right in the middle of the row. It does not sit there now: everything after
this is either a fixed gap or the slack, and the economy is pinned to the
right-hand end, so heat growing is absorbed by the spacer and nothing a
player can see moves at all.

MEASURED, because it was not free: the reservation was 78 pixels against
the 21 that "0/22" actually draws, and those 57 pixels of held-open air
were the gap between the gauges and the catalogues. Twenty-four of MID_GAP
was moving the pair four pixels, because the wall it was pushing off was
this and not the heat number.

The one thing that still moves is CARDS and MODULES, sliding right when you
go over cap. They are dev-only and they are the only things between here
and the slack.
```

## Catalogue gap

Inside `_build()`, above `if DevMode.enabled:`:

```text
--- MIDDLE: the catalogues, and nothing else.

A FIXED GAP, not a share of the slack. The bar reads in three groups —
where you can go, what the ship is, what you are carrying — and the two
dev-only catalogues belong to none of them, so they get air on both sides
and no rule.

It was two expanding spacers, then two at a 1:3 ratio to pull the pair
left. MEASURED: the pair did not move -- 582 either way -- so the ratio was
doing nothing that could be seen, and a lever that does not move the thing
it is aimed at is worse than no lever. A fixed gap puts them a known
distance from the gauges instead of somewhere in the middle of whatever
space happens to be left over.
```

## Dev catalogues

Inside `_build()`, above `if DevMode.enabled:`:

```text
Dev only. Every card in the game on one page is an authoring view, and a
player who reads it has been handed the answer to a game about finding out
what things do. Not built at all rather than hidden — see DevMode.

Neither greys out during combat: looking at the catalog changes nothing,
and mid-fight is exactly when you want to check what a card was supposed
to say. They DO grey while choosing a chassis, which is the one moment
there is no run to come back to.
```

## Economy readouts

Inside `_build()`, above `var econ := HBoxContainer.new()`:

```text
--- RIGHT: what you are carrying, grouped by PROXIMITY rather than by
dividers.

Every readout on this bar explains itself on hover. The bar is where the
whole economy is stated and none of it is self-evident: credits buy
everything and compete with themselves, DATA buys only what a lab sells
and never trades for credits, fuel is priced by chart distance, and heat
is a second health bar you are allowed to spend.

The gap inside a readout was SIX and the gap between two readouts was the
row's own five, so "CREDITS 40 EXOTIC 2" bound the wrong pairs -- 40 sat
closer to EXOTIC than to the word it belongs to. Nothing was misaligned;
the spacing simply said the opposite of the grouping. Four in, twelve
between, and the eye does the rest without a rule being drawn.
```

Inside `_build()`, above `_fuel = Widgets.stat("fuel", "")`:

```text
NO CARGO UP HERE. Materials had a readout each, by name, and three pickups
of common salvage pushed FUEL off the end of the bar -- to say what the
storage grid already shows crate by crate. Sat beside CREDITS they also read
as a second currency, and they are not one: materials are cargo, sold for
credits at the Exchange. DATA is the one other pool on this bar (science,
Jon's pick 1A, Nov 4), and it earns the place because, like exotic and
relic, it only comes from places, yet unlike them it takes no hold room and
nothing sells it.
Fuel joins the group rather than sitting behind a rule of its own. It IS a
different kind of thing -- credits are money, fuel is the
clock -- but ECON_GAP already says "separate readout", and a vertical bar
at the very end of the row was drawing a compartment with one thing in it.

INSIDE `econ`, not beside it. Dropping the rule and leaving fuel on the row
left it on the row's own separation of five against the group's twelve, so
"RELIC 1 FUEL 279" bound the wrong pair -- exactly the mistake ECON_GAP was
introduced to fix, reintroduced by removing the divider that was hiding it.
```

## Removed readouts

Inside `_build()`, above `_built = true`:

```text
THE RUN HISTORY IS NOT HERE ANY MORE. It is FLIGHT RECORD on the title
screen, which is the only place it was ever read: it is the list of runs
you have FINISHED, so consulting it mid-run is looking up somebody else's
ship. Removing it also bought the row back about sixty pixels, which is
what let the economy move to the right-hand end without clipping.

THE FRAME COUNTER IS GONE TOO, and the bar is the better for the room.

It was the last thing on the row, so when the row ran out of width it was
the thing that got cut — and it was cut at a standard window size, which is
how the whole overflow was found. Reserving its width made the row 948
against 944 available and it was still clipped; putting it behind the dev
switch fixed it for players and left it broken for the only people who
wanted it.

So: removed. It measured the renderer rather than the game, nothing on this
bar was ever decided by it, and it was costing the row about fifty pixels
that the readouts people actually use now have.
```

## Tab lighting

Inside `refresh()`, above `var lit := ZoomLadder.lit_rank()`:

```text
Lit on the station screen as well as the sector: both are "here", and the
name on the tab already says which of the three you are looking at. Combat
happens in the sector, so it stays lit through a fight rather than greying
out as if you had left.

COMBAT OUTRANKS THE OTHER TWO. It is the one state you cannot leave, so the
tab that names where you are had better name that first -- and a tab
reading SECTOR while something is shooting at you is the bar's only
opportunity to be wrong about the most important thing on screen.

All three fit the reserved width: STATION is the longest at seven, and the
button was built with that word for exactly this reason.

THE TAB YOU ASKED FOR LIGHTS AT THE CLICK (`ZoomLadder.lit_rank`): on the
one camera the screen changes hands in the middle of the move, and the
tab flipping there was one more thing changing while the camera moved
```

## Berth tab

Inside `refresh()`, above `var at_berth := Router.docked and not fighting and lit == ZoomLadder.STATION`:

```text
DOCKED, LOCAL IS SHUT (Jon, Oct 27, on Jeremy's "LOCAL lets you leave a
station too easily"): at the berth this reads LOCAL, greyed, and says how
to leave, because UNDOCK is the only way out. On a page looked at from the
berth (the map, the chart) it reads STATION and goes back in, which leaves
nothing. (UNDOCK pressed, the move is on its way to LOCAL: lit as LOCAL.)
```

## Binary wording

Inside `refresh()`, above `var here_n := Run.here()`:

```text
(Jon's approved line for one sun; in a binary system, the same said of
both stars: ruling 20, and Jon, Nov 1: "Let's call it Binary instead of two
suns". `here`, not `node_at`: the HUD is drawn while a new run is still
building its map, with nowhere to stand yet)
```

## Tooltips

Inside `refresh()`, above `var hull_note := "Hull is your ship's health.\nAt zero the run ends. Stations repair it for credits."`:

```text
These say what the gauge IS before they say anything about its numbers.
Someone hovering a bar they do not recognise is asking "what is this",
not "what is the arithmetic" — the figures are already beside the cells,
and a tooltip that opens with them answers a question nobody hovered to
ask. Description first, then the one consequence that matters, then the
live rate.
No repair rate here. It is priced per station now, so a number quoted on a
bar that follows you everywhere is only true where you happen to be
standing — and a figure that silently changes meaning is worse than no
figure. The station screen quotes it where it applies.
```

## Reserved widths

Above `func _reserve(l: Label, widest: String) -> void:`:

```text
Hold a label at the width of the longest thing it will ever say.

The two gauge figures are the only readouts on this bar whose text LENGTH
changes with play: hull runs "8/24" to "120/120", and heat turns from "0/23"
into "25 — 2 HULL" the moment you cross the cap. Both sit left of CREDITS and
FUEL, so every one of those changes shoved the rest of the bar sideways — and
the heat one does it exactly when a fight is going badly, which is the worst
moment to move the numbers somebody is watching.

Measured off the font rather than guessed, for the same reason AttrBlock
measures its label column: a guess is a minimum, so guessing low leaves the
label at its natural width and buys nothing.
```

## Tab click sound

Above `func heat_rect() -> Rect2:`:

```text
No button click: a tab changes the page, and the page change has its own
sound. Both at once was a double click on every tab (Jon: "the ui click
shouldn't happen too when you select ship sector starchart...").
THE BOXES THE HINTS AND THE GOAL LINE POINT AT, global; empty when the bar is
not up. The heat gauge with its word and number; the fuel readout; a tab.
```

## Tab state

Above `func _state(b: Button, active: bool, lock: String, hint: String) -> void:`:

```text
`lock` is empty when the tab is available, and otherwise says WHY it is not.
A greyed control that cannot explain itself reads as a bug; one that says
"choose a chassis first" reads as the game waiting for you.

The lit styleboxes are ADDED when active and REMOVED when not. Leaving them
on and hoping the next state overwrites them is how a tab stays amber after
you have left the page it belongs to.
```

## Set chip

Above `class SetChip extends Control:`:

```text
ONE MANUFACTURER'S SET BONUS, LIT. Sixteen pixels square, which is not a
rounded number -- it is the size the build plan's Phase 9 gate names. "Every
emblem legible at 16px" was written as a test OF this chip, and until now the
chip it was written for did not exist, so the gate had never been run against
anything.

The bonuses have been live in the sim the whole time: `Run.has_set` decides
whether Solari plasma gains damage, whether Cygnet drones act twice, whether
Redline negates the first attack. A player could be three modules into an
identity, having it applied to every card they play, and be told nowhere.
The only place set bonuses appeared was the chassis picker, which is the one
screen you are not on while it matters.
```

## Fuel bar

Above `class FuelBar extends Control:`:

```text
THE TANK AS A BAR, between FUEL and its figure. A gauge, not a control: flat,
no bevel, no hover state, no focus, so nothing about it says "press me" (the
rule is only pressable things look pressable). It takes the hover only so the
readout's tooltip works across it, as every readout on this bar does.

Continuous rather than cells: hull and heat are ten cells beside it, and a
third row of cells read as one long gauge. A thin bar is a different kind
of thing at a glance, which is what fuel is -- the clock, not the ship.
```
