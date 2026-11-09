The reasoning behind `tkg/scripts/ui/UITheme.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Material tier colour

Above `const TIER_ORDER: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic",`:

```text
A material's tier, as the grade ladder the game already has.

CORRECTED. This first shipped as a second palette of eight colours defined
here, on the grounds that nothing coloured a rarity yet. That was wrong:
`ModuleData.rarity_colour` has done it all along and I missed it because it is
a static on a data class rather than anything in `ui/`. Two ladders for one
idea is the exact thing the first version claimed to be avoiding.

The names line up exactly -- `MaterialTable`'s tiers and `ModuleData.Rarity`
are the same eight in the same order -- so this is a lookup, not a mapping
with opinions in it.

`rarity_ink` rather than `rarity_colour`, because contraband's colour is very
nearly black: fine as a plate's ground, unreadable as ink on one.
```

## Tractor colour

Above `const TRACTOR := Color("#4fe0cc")`:

```text
A mount reaching for the thing you are holding.

The one colour in the game that is neither the cold of the void nor the warm
of something burning, which is exactly what makes it read as MACHINERY doing
something rather than as heat or as chrome. The art direction's warm/cold
rule governs objects and lighting; this is neither, it is a field.

Deliberately off Cygnet's #58c8d8. Manufacturer accents sit on module plates,
and a drop target that borrowed one would say "Cygnet" on every hardpoint of
every ship in the game.
```

## Leave colour

Above `const LEAVE := Color("#d4614f")`:

```text
The way OUT. Quit, flee, break contact, not yet — every control whose job is
to leave the thing you are looking at.

Not a danger colour, which is why it is not called one. The red button on the
sector screen breaks off a fight you were losing and the red item on the
title screen closes the game; neither is the dangerous choice, both are the
exit. Marking exits keeps them from reading as one more equal option in a row
of buttons.

This hex was already in the game twelve times across seven files before it had
a name here — the sector screen alone spends it four times. Those sites are
left alone rather than swept: several are semantically DAMAGE (a hull below a
third, a negative stat) rather than an exit, and folding two meanings into one
constant because they share a hex is how a palette stops meaning anything.
```

## Tooltip wrap

Above `const TOOLTIP_PAD_V := 6`:

```text
Tooltips are held to one rectangle rather than sized to their text. See the
TooltipPanel block in build(). TOOLTIP_WRAP is in CHARACTERS, applied by
Widgets.tip() when the text is set, because a Label inside a themed
TooltipPanel cannot be given an autowrap mode from the theme itself.

32 is narrow on purpose. A tooltip is read in one glance beside the thing it
describes, not scanned like a paragraph, and a narrow column keeps it out of
the way of whatever you are pointing at. Prose measures usually want 45-75
characters; this is deliberately under that, because the text here is one or
two sentences and never a body of copy.
```

## Place heading size

Above `const FS_PLACE := 26`:

```text
For a heading that is the ONLY thing in its corner.

`FS_HEAD` is sized to sit above a subtitle and a paragraph; with those gone
it reads as a label rather than as the name of the place you are standing in.
26 is the same face at the next whole multiple that stays crisp -- the font
is a pixel face and anything between magnifications fuzzes.
```

## Font loaded once

Above `static var _face: FontFile = null`:

```text
Loaded once and shared. Antialiasing and hinting are forced off in code as
well as in project settings — a bitmap face at integer scale must not be
smoothed, and a stray .import setting would otherwise undo it silently.

NOW ACTUALLY ONCE. The comment above said "loaded once and shared" and the
function did neither: every call re-ran load() and rewrote all four
properties on the shared resource. That is cheap but not free, and eighteen
call sites read this — several from inside _draw(), which this codebase
queues on mouse motion, so the writes were landing on every hover frame of
every card, gauge and enemy slot. The resource cache always returned the same
FontFile, so the only thing the repetition bought was the property writes.
```

## Quote colour

Above `const QUOTE := Color("#5a6470")`:

```text
Flavour grey: dark enough to sink toward the panel, light enough to read.

Two jobs at once. Desaturated out of the palette's cold blues, because
everything the player can act on is blue-grey and a neutral says "not this
one" before a word is read. And held down near the panel itself, so the
block recedes rather than competing — flavour should be findable, not
announced.

Roughly 3:1 against PANEL. That is deliberately under the threshold you
would demand of anything a player has to act on, and it is the right side of
the line for something they never have to read at all.
```

## Panel alpha

Above `const PANEL_A := 0.88`:

```text
How solid a panel is over the sky behind it.

NOT QUITE OPAQUE, and that is the whole of what makes the sky worth drawing.
`SpaceLayer` puts a world behind every screen that is not an interior, and a
panel filled with solid PANEL covers all of it — the refit bay and the
galleries are rectangles that leave a few pixels of gutter, so a
sky behind them was a sky nobody would ever see.

Held high on purpose. This is depth, not a window: the stars must never
compete with the text in front of them, and a player reading a module's stats
should not be aware they are doing it against a planet. What survives at this
alpha is the value shift where the sky is bright, which is enough to say the
panel is IN a place.

One number, here, because it is the dial the whole effect lives on and it
wants arguing with in one place rather than finding in eleven. Note that the
theme is only half of it: `Widgets.panel_with` overrides the stylebox, so the
screens built from it read the alpha from there. Changing this alone moves
nothing on the refit bay — measured, at 0.25, on a screen that did not budge.
```

## Scroll bar sizing

Inside `build()`, above `t.set_stylebox("scroll", "VScrollBar", bar_box(Color("#0c1219")))`:

```text
Scrolling.

THE PADDING IS THE WIDTH, and these three were authored at zero.

A `VScrollBar` derives its minimum width from its styleboxes, so a track
with no horizontal content margin is a bar that is nought pixels across.
Every ScrollContainer in the game was therefore scrollable and said so to
nobody: the shelf, the hold, the run history and — once it had one — the
salvage rail all scrolled on the wheel and drew no bar at any point. The
bug that got this looked at was reported as "it doesn't have a scroll",
which was the correct reading of what was on screen.

Six pixels. Wide enough to see and to grab, narrow enough that it reads as
an edge treatment rather than as a control — the panels it lives in are
268 across and a chunky bar would be a tenth of one.

AND A GUTTER BEFORE IT (Jon, Oct 20, on the sector map's WORLD card: "the
scroll bar covers up text"). A ScrollContainer gives its content its width
less the bar's minimum width, so right-aligned values ended on the bar's
first pixel and read as running under it. Every piece of the bar is now
BAR_GAP px wider on its left, and that strip is drawn clear: the
container keeps it out of the content and nothing is painted in it. The
pressed grabber is the lit one, so dragging keeps the gutter clear too.
```

## Tooltip shape

Inside `build()`, above `var tip := bevel(PANEL2, TOOLTIP_PAD_V, TOOLTIP_PAD_H)`:

```text
Tooltips, held to one shape.

Godot sizes a tooltip to its text, so a screen full of them is a screen
full of different rectangles — a four-word one is a sliver and a
three-sentence one runs most of the way across the viewport. Padding it
generously and giving the panel a minimum width puts a floor under the
small ones; TOOLTIP_WRAP puts a ceiling over the large ones by breaking
their lines before the viewport does.

Both halves are needed. Only a minimum and the long ones still sprawl;
only a wrap and the short ones are still slivers.
```

## Button styles

Above `enum ButtonStyle { PLATE, SOFT, FLAT, OUTLINE, CUT, UNDERLINE }`:

```text
Raised surface: 1px light top-left, 1px dark bottom-right, drawn as a 9-slice
so it never stretches. 1px here is 2 real pixels at the 2x viewport scale.
THE SHAPE OF EVERY BUTTON IN THE GAME.

PLATE is what it has always been, since the first commit that built this
theme: a raised plate lit from the top left, one pixel of BEVEL_HI along the
top and left and near-black down the other two. It reads as hardware, and it
is the loudest thing about a row of seven HUD tabs.

The rest are the alternatives Jon asked to see. Pick with `-- btn=N`; the
number is this enum's order.
```

## Text field

Above `static func field(chars: int = 20) -> LineEdit:`:

```text
Small caps-ish section header used throughout the UI.
A TEXT FIELD IN THE GAME'S OWN CLOTHES.

Lived on LobbyScreen, whose comment said the honest thing at the time: "the
first text field in the game, so it is styled here rather than in UITheme --
one screen is not a pattern". The ship's rename box is the second, and two is
a pattern, so it moves here rather than being copied there.

RECESSED, because a field is a hole you type into rather than a plate. The
caret is EMBER for the same reason every other live thing in this interface
is: it is the one part of the control that is moving.
```
