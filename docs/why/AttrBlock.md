The reasoning behind `tkg/scripts/ui/AttrBlock.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Attribute cells

Above `const CELL := Vector2(7, 9)`:

```text
The seven attributes, as countable cells.

Cells rather than bars, for the same reason heat and energy are cells: a
check is `attribute >= N`, so the player needs the exact number, not roughly
how full something is. A bar that looks two-thirds full answers no question
anyone is about to be asked.

Shared by the ship tab and the chassis select so the two can never disagree
about the order, the names or the ceiling — and the order itself comes from
RunState.attributes(), which is the only place it is written down.
```

## Gain colour

Above `const GAIN := Color("#ffffff")`:

```text
What a fitted module ADDED. Bright white, and the white is the point.

The base cells stay the MANUFACTURER's colour — that is the ship, and it is
what makes a Solari row read as Solari before you have read a word. So the
bonus has to wear a colour no manufacturer flies, or it just reads as more chassis.

White is the one that is left. The seven accents are #d97b2e, #ef9f27,
#b3924e, #e24b4a, #8a7340, #58c8d8 and #3f8f6b — between them they cover
orange, gold, red, cyan and green, and none is within reach of white. It is
also the brightest thing on the panel, which is correct: a bonus should be
where the eye lands.

The version before this was teal with a bright ring around it, because teal
collides with Cygnet and Calyx and needed structure to survive them. White
needs no ring.
```

## Loss cell

Above `const LOSS := Color("#d4614f")`:

```text
What a fitted module TOOK AWAY — a Solari flare rack costs stealth, and the
row has to be able to say so.

Drawn as an UNLIT cell with a red slash through it, never as a red fill:
Redline's accent is #e24b4a, so a filled red cell is indistinguishable from a
Redline ship's ordinary ones. An unlit cell struck through reads as absence
against every accent in the game, because it is not competing on colour at
all — the cell is dark like an empty one, and the slash says something took it.
```

## Label column width

Above `func _measure_labels(rows: Array[Dictionary]) -> float:`:

```text
Names are spelled out rather than abbreviated — HUL/THR/MNV is a code you
have to learn, and seven rows leave room to just say what they are.

The column width is MEASURED off the font rather than guessed at, because a
Label's custom_minimum_size is a minimum: guess low and the longest name
takes its natural width instead, shoving that one row's cells out of the
column while the other six stay put. Asking the font is the only version
that cannot be wrong at a size nobody re-checked.
```

## Amounts and accent

Above `func setup(rows: Array[Dictionary], accent: Color = UITheme.CHILL,`:

```text
`accent` tints the filled cells. The chassis select passes the manufacturer's
colour, which is what makes a Solari attribute row read as Solari before you
have read a word of it; the ship tab passes the hull's manufacturer for the same
reason. Steel is the fallback for an unbranded frame.

`amounts` prints a row's real quantity after its number: "29 hull" after
HULL's 4 (ruling 12 C, Jon, Oct 27). Geno read the chassis select's HULL as
4, 6 and 8 pips against 29, 40 and 57 hull and took them for a mismatch;
the pips are that hull over 7, rounded, and the screen never said what they
were rounded FROM. The HUD's HULL 29/29 sat at the top of that screen the
whole time, a long way from the pips; the number has to be IN the row.

ON ONLY WHERE THE COLUMN HAS THE WIDTH: the chassis select, where frames are
compared pip against pip and the question came up, has 264px for a row of
230 (187 without it). The refit screen and the cutaway do not: STATS_W pins
the refit screen's hold at 220, 10 short, and the cutaway's panel is as wide
as its widest row, so a light's or a medium's (a hold 160 or 200 across)
would take 30px from the ship. The yard's slab already spends that width on
its change column. All of them get the honest tooltip, which does the sum
on the ship you have.
```

## Hover box

Inside `_build_row()`, above `var outer := HBoxContainer.new()`:

```text
TWO boxes, and the outer one is why. A row in a VBox stretches to the full
panel width, so a single HBox carrying the tooltip made the hover target
~550px wide for ~140px of content — the attribute tooltip fired from empty
space halfway across the screen, and from directly over the abilities block
below it. The inner box shrinks to its content and owns the hover; the
outer one is inert and just holds the slack.
```

## Change column

Inside `_build_row()`, above `var d := int(a.get("delta", 0))`:

```text
AN OPTIONAL CHANGE COLUMN, for a block that is being read against another
ship rather than on its own.

AS A SIGNED NUMBER AND NOT AS PAINTED CELLS. The shipyard tried the cell
version once: your value as the floor, the offer's as the fill, one block
instead of two. It was compact and unreadable, because the base cells take
the MANUFACTURER's accent -- so wherever that accent is itself red, four
gauges on which the new frame was BETTER came out red, under a legend
saying that red meant loss.
`+3` cannot be misread by anybody, colourblind or otherwise, and the colour
is then free to reinforce rather than to carry.
```

## Attribute tooltip

Above `static func _hint(a: Dictionary) -> String:`:

```text
What the attribute is FOR, in the same shape as the weight-class tooltips:
the name, then one sentence.

It used to also print the value and a "Chassis 40, fitted modules +3" split.
Both were repeating the row they were attached to — the cells and the number
are an inch away, and the split is visible in the cells themselves, which
already paint the chassis in the manufacturer colour and anything fitted in white.
A tooltip that restates what you are pointing at is a tooltip you stop reading.

THEN WHAT A PIP BUYS, which is the half that was missing. The sentence above
says what the gauge is FOR; a player choosing between two parts needs to know
what one more of it does, and that was only knowable by reading RunState.

NOT THE ODDS LADDER, which lived here for one commit and was in the wrong
place twice: it repeated itself across seven tooltips, and it could only ever
state the ladder in the abstract. `SkillCheck.badge` prints the real number
for the real check at the moment of choosing -- which is strictly better, so
the abstract copy is gone rather than duplicated.
```

## Over ten

Inside `set_values()`, above `func _draw() -> void:`:

```text
OVER TEN IS DRAWN, not clipped. Pillar 5 says the ceiling is meant to
break, and a row that silently stops at ten hides the exact moment the
whole loot loop was paying out for — a stealth build reading 14 looked
identical to one reading 10.

THE BAR NEEDED NO CODE FOR IT. Ten cells, and when the value is over ten
every one of them lights because `i < value` is true for all of them — the
loop already said what to do. The numeral beside the row says how far past.

A special case was written first, in a hotter colour, and removed: it was
an answer to a question the existing loop had already answered, and the
only way to find that out was to take it away and see nothing change.
```

## Loss slash

Inside `set_values()`, above `func _lost(pos: Vector2) -> void:`:

```text
A cell the chassis had and a fitted module took away: an unlit cell with a
red slash across it. Never a red FILL — see AttrBlock.LOSS.

The cell body is drawn exactly like an empty one, because that is what it
now is. Only the slash is added, and it is the sole diagonal anywhere in
this interface — which is what makes it read as a strike-through rather
than as another piece of chrome.

draw_line rather than stepped rects: Godot leaves it unantialiased by
default, so it stays crisp on the pixel grid at this size.
```
