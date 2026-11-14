The reasoning behind `tkg/scripts/ui/EncounterDrawer.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Drawer split

Above `const BTN := Vector2(94, 20)`:

```text
How a system describes itself, before anything is shooting.

Lifted out of `SectorScreen`, which is BOTH the arrival screen and the combat
screen and had reached 2,357 lines carrying the two of them. `ROADMAP.md`
flagged that when it was 1,221 -- "E and L both make large edits to
SectorScreen.gd ... sequence them" -- and three queued jobs edit it now.
Sequencing is not the fix when the file keeps growing; separating is.

Everything here is STATIC and builds a Control from data. That is not a style
choice, it is the test that decided what could move: eleven of these twelve
touched no screen state at all, and the two that did reached for exactly one
thing each -- opening an option, and taking one. Both are now `Callable`
parameters, which is the pattern `PileView.opened` (and the since-deleted
`Widgets.module_row`) used here.

What stayed behind is the state machine: which of LIST, OPTION and RESULT the
drawer is in, what is open, and what happens when you take something. That is
the screen's business and it reads its own fields. This file is the pictures.
```

## Button sizing

Above `const BTN := Vector2(94, 20)`:

```text
`on_jump` is the third and last thing these builders reached back into the
screen for: the PLOT NEXT JUMP button hangs off the heading, and pressing it
is the screen's business.
`loose` is how much is lying around this system's own pile, and `on_loot`
opens it. Zero hides the button: a door onto an empty room lies once per
system.

Beside PLOT NEXT JUMP because those are the two things you do with a system
once you have read it -- take what is in it, and leave. What a WRECK holds is
reached through the wreck, which is sitting in the picture above.
WHAT A SECTOR'S BUTTONS MEASURE, everywhere.

They were 148x17 in the option drawer and 150x24 in the one-thing drawer, so
the same three controls changed height depending on what kind of place you
had flown into -- which reads as the panel being rebuilt rather than as the
contents changing.

Narrower than either, and then narrower again. They were sized to fill a row
that had nothing else in it; with three abreast they only need to hold their
own words. 104 fits TO_SECTOR and "SECTOR LOOT - 12" at FS_SMALL with
the stylebox's own padding either side and nothing spare.
```

## Option cards

Above `class OptionCard extends PanelContainer:`:

```text
One encounter, as a plate you click into.

A ROW IS A LEDGER LINE AND AN ENCOUNTER IS NOT ONE. These were full-width
bars 21 pixels tall: a name column, a sentence clipped mid-word, and a
right-aligned number. Three of them stacked read as a table of accounts,
which is the wrong promise -- a table is something you scan for a value, and
these are things you go and do. Side by side and square-ish, they read as
choices instead, and the drawer stops looking like a receipt.

THE PLATE IS THE CLICK TARGET, which is most of the argument for a
`PanelContainer` over the `Button` the row used. A Button is not a container:
it cannot pad itself from its own stylebox, so the row anchored its contents
to the full rect and had no margins at all. This sizes to its contents and
the stylebox does the spacing, which is what makes the padding uniform.
`press` TAKES NO ARGUMENTS. It was an index and a callable to hand it to,
which only suited the one caller; a choice needs an option AND a choice
number. Binding at the call site means the plate does not have to know what
kind of thing it is pressing.
```

Above `var over: Control = null`:

```text
AND THE THING THAT HOLDS IT, which is what has to be hidden.

Fading the LABEL left its scrim painted: every card in an exclusive set
was built with `seal(..., false)`, which created a 55 per cent-black rectangle
over the whole plate and then hid only the word on top of it. So a
grouped option sat permanently dimmed with nothing to explain it, hover
lifted the panel behind the scrim and could not lift the scrim, and the
probe reported `flesh=1.00 stamp a=0.00` -- both true, and neither of
them the thing that was dark.
```

Above `func dress(hot: bool) -> void:`:

```text
THE FRAME IS STATE AND THE STRIPE IS IDENTITY, and putting both on the
border was the mistake. `tag_colour` spans a bright cyan for a signal, a
muted brown for salvage and `LINE` itself for an untagged option, so four
cards edged in their own tag came out at four different weights and the
brightest one read as the selected one. It is a uniform frame now, and the
tag is the flush stripe down the left that `plate` adds.

Zero padding, because the stripe has to touch the edge: a PanelContainer
insets its whole child by the stylebox margins, so the spacing moved to a
MarginContainer around the text only.
```

## Option card text

Above `static func result_stamp(r: StringName) -> Array:`:

```text
THE WORD A SPENT CARD WEARS, and its colour.

Success, partial and botched take the bands' own colours, so the stamp and
the result panel that produced it agree. `DONE` is an option with no check in
it -- there was nothing to succeed at, so it says what happened and no more.
```

## Option state

Above `static func option_state(n: MapGen.MapNode, i: int) -> Dictionary:`:

```text
WHAT ONE OPTION CAME TO, for the system map's cards, its beacons and its
event page, read off what the run already records and nothing else:
  open   nobody has touched it
  left   you walked away from it (`MapNode.left`, saved); still open, and
         still takeable
  band   you took it: `word` is its band, SUCCESS / PARTIAL / BOTCHED, or
         RESOLVED when there was no check (or no result was recorded)
  gone   a rival in its set was taken (`results` R_GONE); `by` says which,
         and `by_who` names the partner if it was theirs
  who    a partner claimed it (`Net.taker_name`), `who` their name
A partner's claim used to stamp RESOLVED, as if you had done it.
```

## Bill rows

Above `const BILL: Array[Array] = [`:

```text
WHAT MOVED, as fixed rows: four, and DATA a fifth since science (Phase 12).

FIXED, and printing an em dash for the two that did not. The alternative is
listing only what changed, which makes the rail a different height and a
different shape on every outcome -- so CREDITS is on the second line
sometimes and the fourth line other times, and you have to read it to find
out. Fixed rows always means you learn where each number lives once.

DATA IS LAST, after the four it joined, so the line a taken option keeps
(`moved_line`, saved as `MapNode.said`) reads as it always did for every
result that paid no DATA: "FUEL -16", never reordered round it. A reading
that did reads "FUEL -2 · DATA +5". DATA going up is good, like credits.

HEAT RISING IS NOT A LOSS, and gets `FLARE` rather than the red the other
three use when they fall: nothing was taken off the ship. It is a bill that
comes due at the end of the turn, which is what that colour means everywhere
else on this screen.
```

## Tag colours

Above `const TAG_CONTRACT := Color("#9b8ec8")`:

```text
What a tag reads as at three pixels wide. A fight is a threat, salvage is a
wreck, a signal is somebody talking.
CONTRACT WAS MISSING, and it is the biggest group in the table: fifteen of
forty-nine options are tagged `contract` and nothing else, so a third of the
table fell through to `LINE` and drew no stripe at all. A code that is silent
about its largest category is not a code.

Violet because it has to be cold and it has to be unused. The palette note at
the top of `UITheme` reserves every warm colour for combustion, and salvage's
brown is already stretching that; green is the hull bar's.
```

Above `const TAG_HAZARD := Color("#f2761d")`:

```text
Hazard orange, and it is the one warm tag that earns the palette's exception.

`UITheme`'s note reserves the warm end for combustion -- reactor glow, weapon
fire, heat on your own hull -- and four of these seven options ARE combustion:
a star mid-tantrum, a flare forty minutes out, a pulsar beam, a lane you
cannot thread. Saturated past `EMBER`, which is a reading on your own ship,
and away from `LEAVE`, which is somebody shooting.
```

Above `const TAG_SALVAGE := Color("#b3a488")`:

```text
Bone. A wreck is not dirt, and brown said dirt.

This was `#9a7b52`, which worked while it was the only warm tag and stopped
the moment HAZARD arrived beside it: red, orange and brown are one family,
and salvage is the SAFE one of the three -- the tag that says nothing here is
trying to kill you. Bleached and desaturated, it reads as material rather
than as heat, and it never competes with the two that are warnings.

Warm on purpose even so. The cold half of the wheel is where this game keeps
its TEXT -- `COLD`, `CHILL`, `ICE` are the body, the labels and the titles --
so a grey stripe would sit a shade away from the words printed next to it,
and a green one would collide with `GOOD`, which is the SUCCESS stamp.
```

Above `const TAG_QUEST := Color("#e0b83c")`:

```text
Gold, and the only tag that is not a KIND of thing.

The other five say what an encounter IS. This one says where it came from:
somebody put it here because of something you did, and it is the only option
in the game that could not have been rolled. Gold because it has to read as
the one worth crossing a system for, and because it is the last hue the other
five leave open -- red, orange, bone, cyan and violet are spoken for.
```

## Tag priority

Above `const TAG_ORDER: Array[StringName] = [&"quest", &"fight", &"hazard", &"salvage",`:

```text
PRIORITY, NOT AUTHORING ORDER. `lead_tag` read the option's own `tags` array
and returned the first one it recognised, so `[signal, fight]` came out cyan
and `[fight, signal]` came out red -- the same option two colours depending
on which word got typed first. A fight is the fact that changes what you
would do about the thing, so it outranks whatever else is true of it.

HAZARD SITS SECOND, under a fight and over everything else. The corona and
the mine drift are both wrecks worth stripping and both are tagged salvage,
which is true and is not the thing you need to know first: what decides
whether you go in is the star and the mines. A fight still outranks it,
because something aiming at you is a shorter clock than something you are
flying into.
QUEST OUTRANKS EVERYTHING, including a fight. The others describe what you
are walking into; this one is the reason you came, and a thread you have been
carrying for four jumps should not be filed under whatever else is true of
the encounter that pays it off.
SCIENCE AFTER SALVAGE. A reading is a place you take something from, as a
wreck is, and it never shares an option with a fight or a hazard today; if it
ever does, the fight or the star is still the thing to know first.
```

## Choice cards

Above `static func choice_card(n: MapGen.MapNode, i: int, j: int, c: Dictionary,`:

```text
THE SAME PLATE THE ENCOUNTER WAS, one screen further in.

These were stock buttons with a caption underneath: a grey rectangle, a word
in the middle of it, and the number that the whole decision turns on floating
outside the thing you were about to press. Three of them in a row read as a
form. On a plate the label and its number are one object, the number is INSIDE
what you are committing to, and the OPTION state matches the list you reached
it from -- the same shape means the same kind of act.

The stripe is what stands in the way. `tag_colour` answers "what kind of thing
is this" for an encounter; here there is only one kind of thing and the useful
fact is the gate: red when you cannot pay, the band's own colour when it is a
roll, the contact colour when it opens a fight.
```

## Choice gates

Inside `choice_card()`, above `if c.has("needs_material"):`:

```text
A GATE ON WHAT YOU ARE CARRYING, not on what you can pay. `holding_pattern`
trades an exotic-tier item to a queue that has been waiting long enough to
want one, and the handoff asked for the choice to be HIDDEN if this could
not land tonight. Greying it is better and costs the same: RULING 8 already
says a disabled thing states what it wants and how far off you are, and a
hidden row teaches the player nothing about why the trade was possible the
last time they saw it.
```

## Contact reading

Above `static func contact_reading(n: MapGen.MapNode) -> String:`:

```text
RULING 5 — what a fight row prints, and it is something the player bought.

Every other row prints a number and this one printed nothing until the fight
started. A flat enemy count spoils a reveal worth keeping; leaving it bare is
inconsistent. So it is `chart_from()` one scale down: the dish already tells
you WHERE things are, and a better dish tells you WHAT they are.

It also finally gives SENSORS something to do outside event checks -- its
attribute row prints an empty effect string today because nothing reads it.
```

## Science hue

Above `const TAG_SCIENCE := Color("#e07ac8")`:

```text
Rose, for a reading (science, Phase 12): the last hue the six leave open.

Green was the obvious one for an instrument and is taken twice over, by
`GOOD` (the SUCCESS stamp) and by the hull bar. Cyan is SIGNAL's and violet
CONTRACT's; this sits between violet and a fight's red, fifty to sixty
degrees from both, light enough to read at two pixels on the dark map. The HUD's DATA
readout has no hue of its own (ICE, like every figure on the bar), so there
was nothing to match.
```

## A reading burns fuel

Inside `choice_card()`, above `if bool(c.get("burns", false)):`:

```text
A READING BURNS FUEL (science, `burns`): what it costs goes on the card,
after any odds, so the number you pay is inside what you press. When the
tank cannot pay it and keep the way out (`OptionResolve.fuel_ok`, the hard
gate), the card greys: the same price as the full card, then the way out
the tank keeps back (`Run.fuel_floor()`), then what you have, as RULING 8
has a price say. Folding the two into one number read as if the reading
cost it. Only pressable things look pressable.
```
