The reasoning behind `tkg/scripts/ui/ShipScreen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Refit workbench

Above `const HULL_VIEW_H := 150`:

```text
Refit, as a workbench.

The ship and what it IS on the left; the parts and where they go on the
right. You drag a module from storage onto a hardpoint to fit it, drag it
back to store it, and drop one onto an occupied mount to swap the two.

There is no melter on this screen. Scrapping a part still exists and still
pays scrap — it lives on the station and the salvage prompt, where a bid to
compare it against is also on screen. A drag-to-destroy target sitting next to
the storage grid made the destructive move the easiest one to reach by
accident, which is the wrong ergonomics for the only irreversible verb here.

Modules are icons rather than rows. A list of names is a document; a grid of
icons is an inventory, and this screen's whole job is the second thing —
comparing what is bolted on against what is in the hold, at a glance, and
moving one to the other. The rows it replaced could not show you a full
weapon rack and a full hold at the same time.

Two drop handlers, because there are two destinations asking different
questions. `_on_mount_drop` asks whether a slot type matches and which PLACE
on the hull was aimed at; `_on_hold_drop` asks whether a shape fits and at
which cell. Nothing else in here touches `installed` or `cargo`.
```

## Hold and panel sizing

Above `const HULL_VIEW_H := 150`:

```text
SUPERSEDED by HoldGrid, which takes its shape from HullData.hold_grid. Kept
as the record of why four: the measurement below is what set it and it is
still what the hold is drawn at.

Four across, so the hold reads as rows of four whatever hull you are flying.

Capacities are 8 / 12 / 16, so four columns is exactly 2, 3 and 4 full rows —
no ragged last row on any ship in the game, and the shape itself tells you
which weight class you are in.

Width is also why this is safe. Measured at eight columns the two panels
demanded 985px of a 944px viewport and the melter and the last storage column
hung off the right edge. The left panel cannot give any of it back — its 527px
is the banner plus the ship at 2x, and the ship is the subject. Four columns
is 201px against six columns' 303px, so the grid now costs a third of what it
did when it did not fit.
The ship panel's height, off the SPEC rather than off whatever hull happens to
exist: the largest class is 125x50 at 2x the box, so 100 rows plus the bob.

150, and it is a BUDGET rather than a size. The masthead is SHRINK_BEGIN and
the workbench is EXPAND_FILL, so every row given to the ship is a row taken
off the panel below. Measured with `-- shipshot`, on the heavy, which is the
tight case — its hold is 6x5 against the light's 4x3:

    view    masthead   workbench   the heavy
    104        175         311     what it actually was, see below
    150        221         265     here. 19 rows clear under the abilities
    160        231         262     also fits
    165        236         257     still fits, nothing left over
    200        271         222     abilities clipped off the panel

104 is in that table because it is where this screen SAT, not where it was
set. ShipView._resize_canvas ignored the height it was handed unless the view
was magnified, so at 1x the panel silently took the canvas's own depth and
this constant did nothing at all. Honouring it is the whole of the extra room:
the number here is unchanged and the panel is 46 rows deeper than it was.

The panel bottom does not move as this grows. Two equal expanding spacers in
`textcol` carry all the slack, so what shrinks is the air between ATTRIBUTES,
HARDPOINTS below it, and it shrinks EQUALLY, which is the property worth
keeping. At 150 those two gaps are 20 rows each; at 200 they are nothing
and the bottom of the column runs off the panel, which is the failure to
watch for: it does not throw, and it only happens on one of the three
weights. A MANUFACTURER ABILITIES block used to be the thing that fell
off first, and its removal bought this margin rather than fixed it.
```

## Hull view spacing

Above `const HEAD_GAP := 0`:

```text
Clearance between the name block and the ship. The mount markers draw ABOVE
the hull's own top edge — they are what a part bolts to, so they have to sit
proud of it — and without this the dorsal row lands in the class line.

26 rather than the 10 that was merely enough to stop the collision: this is
also the gap that sets how far down the panel the ship sits, and the flag
beside it grows to match.
```

## Hold placement

Above `const STATS_W := 220`:

```text
How wide the numbers get before the hold starts. Fixes the hold's top-left
corner, which is the whole point: a hold grows by gaining CELLS, and it
should gain them down and to the right, the way a hold fills. Right-aligned
instead — which is where it sat first — a wider hold grew LEFTWARDS into the
attributes, so the same five parts moved every time the ship changed.

The panel gives 479px between its paddings and the attribute rows measure
183 of it, so this is mostly gutter. 220 puts the hold's left edge at x=254 —
a 50px gutter off the numbers, which is enough to read as a separate block
without being a hole.

Sitting this far left is also what makes "grows down and to the right" true
rather than aspirational: 245px of clear panel to the right of a five-wide
hold is nine more columns. It was at 340 for one pass, and there the same
sentence bought exactly one.
```

## Panel widths

Above `const PANEL_W := 504`:

```text
Air between the hold's heading and its first row of cells, matched to the gap
ATTRIBUTES has over HULL. That one is free — a label carries its own leading
and the gauge row is mostly whitespace — and the hold's first row is a
hard-edged plate, so the same distance has to be put there on purpose.

MEASURED, not guessed: ATTRIBUTES clears HULL by 8px of background, and at
LABEL_AIR 6 the hold cleared its grid by 11. Hence 3.
Between the flag and the text beside it. Named because the ship's own
placement has to subtract it — see `_centre_ship`.
The left panel's width, fixed. See `_centre_ship` for why it cannot float.

524 was the smallest that fitted everything WHEN THE WIDEST THING IN THIS
column was the manufacturer abilities block at 470 across. A centred heavy
needs the flag's 49 plus half a 336px view plus the 33 the hull sits off
its own centre, which is 500 inside the padding -- and that half still
holds, because it is about the ship rather than the readouts.

504, not 524. The right panel takes whatever the left column leaves, and a
readout NUDGES right on hover, so its row needs twenty pixels of slack or
the far card slides under the screen edge while you are reading about it.
Taken from here rather than added there, because this column had room.

THE 470 CONSTRAINT IS GONE with the abilities block, so this is no longer
the smallest width that fits -- it is merely a width that does. Left as it
is on purpose: narrowing the panel moves the ship, the hold and the whole
right-hand column, which is a layout decision and not the tail end of
deleting a list. The 500 the ship needs is the real floor now.
```

Above `const STORAGE_COLS := 4`:

```text
NO EXPLICIT GAP under the ship, and that is measured rather than an omission.
The flag ends 8px above the ATTRIBUTES glyphs on its own: two of the column's
separations, plus the leading a label carries above its own capitals. Adding a
spacer of the 8 that was wanted produced 16.

8 is also what ATTRIBUTES clears HULL by and what the hold's heading clears
its grid by, so all three headings on this panel now sit the same distance
under whatever is above them.
```

## Module readouts

Above `const READOUT_W := 150.0`:

```text
How wide a module readout is in the installed list.

WIDER THAN A CARD, deliberately. At a card's 112 the longest manufacturer line
wrapped to two rows on Korvan parts and one on unbranded ones, so the boxes
were the same width and different HEIGHTS — which is the same raggedness
moved to the other axis. 150 fits "KORVAN HEAVY WORKS" on one line.
```

Above `const NUDGE := 7.0`:

```text
How far a readout slides right while it is being pointed at.

Animated through a MarginContainer rather than by setting `position`: the
readout lives in an HBox, and a container overwrites a child's position on
the next layout pass. A margin is a thing the container itself honours.
```

## Lifted part

Above `var _lifted: ModuleData = null`:

```text
THE PART CURRENTLY IN THE AIR, and where it came off.

A part dragged off the hull leaves the ship at the moment it is picked up,
which means that between the grab and the drop it belongs to NOTHING — not
`installed`, not `cargo`. That is the state this remembers, and `_on_release`
is what guarantees it cannot outlive the drag: a drag abandoned over the star
chart would otherwise delete the module.
```

## Masthead flag

Inside `_build()`, above `var header := HBoxContainer.new()`:

```text
THE FLAG HANGS THE WHOLE DEPTH OF THE SHIP, name and hull both.

This went the other way for a while — a short banner sized to the three
lines of text — because "fixed across, free down" meant it grew to the
ship's height and took vertical the blocks below needed. That was the
right diagnosis of the wrong problem: the vertical was won back by moving
the hold out of the column, and the flag can have its depth now.

It is the one thing on this panel that says whose yard built what you are
looking at, and a 66px badge beside a 106px ship reads as a bullet point
next to the subject rather than as a masthead over it.
```

Inside `_build()`, above `var namerow := HBoxContainer.new()`:

```text
THE NAME, and the pencil that changes it.

On a row of its own so the button sits against the text rather than out at
the column's right edge -- the column expands to fill the masthead, and a
button parented straight to it would end up a hundred pixels from the word
it edits.
```

## Hull view scale

Inside `_build()`, above `view.self_clip = false`:

```text
1x, and the height sized off the TALLEST hull rather than off the one that
used to be the only one.

2x was set when every hull was procedural at 240x120 and the one real
sprite was 188x88. The shipped hulls are 150x60, 200x80 and 248x100, so 2x
drew a 496px ship on a 960px viewport — over half the screen width — and
clipped the deepest ones top and bottom. Integer magnification is the art
rule and 1x is the only step below 2x, so this is half rather than a nudge;
the viewport is itself scaled 2x into a 1920x1080 window, so an art pixel
still lands on four real ones and stays crisp.
THE WINDOW CLIPS, NOT THE VIEW. `_clip` bounds everything on this screen,
so the view clipping itself as well can only take a bite out of its own
children — which is the hardpoint layer, and the guns on it.
```

## Ship centring

Inside `_build()`, above `var vwrap := HBoxContainer.new()`:

```text
CENTRED ON THE PANEL, not on the column and not on the canvas.

Two separate reasons the ship was not in the middle, and neither was the
one it looked like. It lives in the column the flag leaves, so it starts
half a flag right of the panel's centre; and a hull sits right of the
middle of its OWN canvas, because the canvas carries the exhaust plume's
clearance on one side only.

A pad either side, and `_centre_ship` puts the number on the left one.
```

Above `func _ship_x() -> float:`:

```text
Where the ship's left edge goes so its middle is the PANEL's middle.

Same arithmetic that used to set the left pad, applied to the view's position
inside the box instead. Three terms, all of them things pushing the ship right
of the middle: the flag it sits beside, half the width of the view, and how
far the hull sits from the middle of its own canvas -- which is not zero,
because the canvas carries the exhaust plume's clearance on one side only.
```

Inside `_ship_x()`, above `if wide > win:`:

```text
THE OFFSET ONLY APPLIES WHILE THE SHIP FITS.

It exists because the canvas carries the exhaust plume's clearance on one
side only, so the hull is not in the middle of its own image and centring
the IMAGE leaves the SHIP looking off. That is true and worth doing — while
there is room to do it in.

Zoomed, there is not. The offset scales with the magnification, so at 2x it
pushed a heavy some 123 pixels to the right of a window it was already 217
too wide for, and a fifth of the ship — the front, and every gun on it —
was outside the window before a drag had even happened. When the ship is
wider than what it is being shown in, the only honest starting place is the
middle.
```

## Hull view window

Inside `_build()`, above `_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL`:

```text
THE WINDOW TAKES THE REST OF THE ROW. It used to be sized to a computed
width with a spacer after it soaking up the remainder, which put an
invisible edge a hundred pixels inside the panel — and at 2x on a heavy
that edge lands exactly where the longest gun is, so the muzzle was cut
off by a piece of empty panel. Expanding instead means the viewable area
IS the panel, which is what was asked for.
```

## Hold beside text column

Inside `_build()`, above `var midrow := HBoxContainer.new()`:

```text
THE HOLD SITS BESIDE THE WHOLE TEXT COLUMN, not beside one block of it.

It was paired with the ATTRIBUTES row alone for two passes, which put the
two headings on one line — correct, and kept — but also put the hold IN
the column's vertical flow. So HARDPOINTS started below the deepest thing
above it, and the deepest thing was the grid rather than the attributes:
the gap over HARDPOINTS was being measured off the hold's bottom edge,
30px lower than the numbers it looked like it was spaced from.

Out of the flow, the three text blocks space themselves against each
other and the hold hangs alongside. The headings still align, because
both columns still start at the same row.
```

## Text column

Inside `_build()`, above `var textcol := VBoxContainer.new()`:

```text
ATTRIBUTES AND HARDPOINTS, with equal space above and below the second.
That is what centres HARDPOINTS under the numbers: the
gap over it and the gap under it are the same object with the same weight,
so it stays centred when a hull with more mounts makes its block taller.

STILL FIXED-WIDTH even though the block that forced it is gone. The
MANUFACTURER ABILITIES rows ran the full width of the panel, so inside
this column they -- not STATS_W -- set the column's width, and the hold
got shoved 240px right of where it was pinned. The rows have gone; the
pin has not, because STATS_W is what the hold is placed against and a
column that sizes to its widest child would move it again.
```

## Hold heading row

Inside `_build()`, above `var holdhead := HBoxContainer.new()`:

```text
THE HEADING AND THE HATCH SHARE A ROW.

It was under the grid, which put it off the bottom of the screen on a
heavy hull -- the hold is five rows there, and the panel had no more to
give. Up here it is above the fold whatever you are flying, and it is
beside the thing it acts on rather than after it.
```

## Dock strip

Inside `_build()`, above `_dockhead = UITheme.body("", UITheme.LEAVE, UITheme.FS_SMALL)`:

```text

Under and not beside, because the two are the same rectangle seen twice:
the strip takes the hold's own column count, so a part that will not fit
up there is directly above the empty cells it needs. Beside them, at half
the width, the comparison stops being a comparison.
```

Inside `_build()`, above `var dockbox := ScrollContainer.new()`:

```text

The first version put the strip straight into the column and it ran off the
bottom of the window: a heavy moving into a light strands about seven
things, which wraps to four rows at the hold's width, and there are two
rows of screen left under the grid. The panel had no more to give and the
strip does not get to take it.

The CELL stays the hold's, because the whole point of the plate is that it
is the same object you are about to drag two inches upward -- shrinking it
would have bought the rows back by making the two grids stop matching.
Height is what gets capped instead, and the overflow scrolls.
```

## Removed abilities block

Inside `_build()`, above `var foot := Control.new()`:

```text
NO MANUFACTURER ABILITIES BLOCK, and this is where one used to be. It
listed the set-bonus ladder for the hull's own manufacturer and, under a
rule, the counts for any other allegiance the fitted parts had earned.

Removed on request. What went with it: the only place on this screen that
said how close a mixed loadout was to a SECOND manufacturer's bonus. The
hull's own perks are still in the masthead's top-right corner, and the
chassis select still answers the ladder question for a manufacturer you
are choosing rather than one you are already flying.
```

## Perk box top level

Inside `_build()`, above `_perkbox.set_as_top_level(true)`:

```text
TOP LEVEL, and that is the whole trick. `panel_with` returns a
PanelContainer, and a Container lays out EVERY child it has and ignores
their anchors -- so adding this beside the ship column did not put a
small box in the corner, it stretched the box across the entire panel and
put it in front of the ship. Nothing looked wrong: the labels still drew
in the corner because they are the only thing in the box with a size.
What broke was INPUT -- a part could no longer be picked up off the hull,
because the drag was landing on an invisible column instead. `-- fittest`
went from two failures to eight and nothing else noticed, because
fittest is not in validate.sh.

Godot Containers skip children set top-level, so this one is positioned
by hand and laid out by nobody. See `_place_perks`.
```

## Right panel

Inside `_build()`, above `var right := VBoxContainer.new()`:

```text

THIS PANEL WAS EMPTY. The hold moved to the left column and nothing took
its place, so a third of the screen was a lit box with a spacer in it.

It answers the question the left panel cannot. The left says what the ship
IS — its numbers, its budgets, its silhouette. This says what you have
ASSEMBLED: the parts on the hull, and the cards those parts will deal you.
A module's cards were previously visible only in a tooltip, one module at a
time, which is the wrong shape for the question "what does my deck look
like now" — that is a question about all of them at once.
```

## Rename prompt input

Inside `_unhandled_key_input()`, above `if _rename != null:`:

```text
THE RENAME PROMPT SWALLOWS THE LOT. Its shade stops the mouse but not the
keyboard, so without this Z zoomed the ship and F flipped a part behind a
panel the player thought they were typing into -- and the focused field
only protects the letters it consumes itself, which is not Z once the
focus has moved to SET or CANCEL.

Escape closes it, and here rather than on the button: `_unhandled_key_input`
only sees the key once the focused LineEdit has declined it, which is
exactly the condition wanted.
```

## Zoom in place

Above `func _set_zoom(on: bool) -> void:`:

```text
ZOOM, IN PLACE. The ship doubles and the panel does not.

The panel cannot grow: the left column is a fixed 524px because everything
about where the ship sits is measured off its middle, and `_centre_ship`
closes in one frame only while that width cannot move. So the box stays the
size it was at 1x, a doubled ship is simply bigger than its window, and that
is why this comes with a drag.

MountPoints goes to PASS while zoomed. It is STOP normally and covers the
whole hull, so with it stopping events the box underneath never saw a press
and nothing could be dragged. PASS still delivers its hover and still leaves
it a drop target -- IGNORE is the filter that would break those -- and the
event carries on to the box behind it.
```

## Module overhang

Above `const MOUNT_CELLS := 4`:

```text
How far a MODULE may stick out past the hull canvas.

A gun is drawn on a mount and its barrel runs off the end of the sprite it is
bolted to, so a window sized to the canvas cuts the front off the longest one.
The canvas is the hull's extent, never the ship's.

MEASURED FROM THE LONGEST PART, and no longer a flat 72. The widest
footprint is four cells, which is 4 x 20 = 80 art pixels — already more than
72 at 1x, and 160 with the zoom on, so the front of a siege driver on a
zoomed heavy was outside the window and could not be panned into it. A
constant cannot be right at two magnifications; this is the same number the
part is drawn at.

Plus a cell of air, so the muzzle has somewhere to be rather than sitting
exactly on the edge of the window.
```

## Rename prompt build

Above `func _open_rename() -> void:`:

```text
NOT AN AcceptDialog ANY MORE, and that is the whole of it looking like the
game.

An AcceptDialog is a Window, and an embedded Window paints `embedded_border`
from Godot's own theme UNDERNEATH whatever panel you give it -- so the pale
grey gradient behind this prompt was not the dialog's background at all,
which is why overriding `panel` never removed it. Godot also builds the OK
and CANCEL buttons itself, in its own row, at its own spacing.

The title screen already had the answer: a full-screen shade, a card centred
on it, and the game's own buttons inside. Everything it wears is the game's,
because none of it is Godot's furniture.

STILL NOT A SCREEN. Renaming is a detour of about four seconds and a Router
push would tear down the refit screen and rebuild it underneath -- losing the
ship's arrival animation, the hold's scroll position and whatever part was
mid-drag.

BUILT AND FREED EACH TIME. A prompt held as a field is one more thing to keep
in step with a hull swap, and this one reads `Run` at the moment it opens.
```

## Perk corner

Above `static func fill_perks(box: Control, right: bool, inline: bool = false) -> void:`:

```text
Park the perk list in the masthead's top-right corner.

By hand, because it is top-level and therefore laid out by nobody -- which
is exactly why it is top-level. Driven off both the panel resizing and the
box itself resizing: the box changes width whenever the perks change, and a
right-aligned thing whose width moved has to be repositioned or it drifts
off the edge.
THE HULL'S PERKS AND THE SET BONUSES THAT ARE LIVE, into `box` (cleared
first): a row of set chips, each its own hover, then the perks by name, one
tooltip for the lot (`PerkBox`). Shared with LOCAL's cutaway, whose left panel
shows the same; `right` aligns them to the right, as this screen's corner does;
`inline` runs the perks' names on as one wrapped line (the cutaway's narrow
panel) rather than one to a line.
```

Inside `fill_perks()`, above `var live := HBoxContainer.new()`:

```text

The two belong in one corner because they are the same kind of fact:
always-on effects you did not spend a card on. They are not the same
ORIGIN, though -- a perk came with the frame and a set bonus was
assembled -- so the chips read as marks and the perks as words.

A set-bonus LADDER used to live on this screen and was removed on
request; this is deliberately not that. The ladder showed how close a
mixed loadout was to a bonus it did not have yet. These say only what
is applying right now, which is the half nothing on this screen said.
```

Inside `fill_perks()`, above `var parts := 0`:

```text
ONE TOWARD THE SET IS ENOUGH TO APPEAR, and the hull counts as
one. `manufacturer_count` includes it deliberately -- choosing a
chassis is a build decision, and a Korvan frame really does put you
one part from Standard Issue. (Briefly gated on FITTED parts instead,
which made the chip disagree with the number the game uses; the count
below names the hull's share instead of hiding it.)
```

## Pan clamp

Above `func _clamp_pan() -> void:`:

```text
Keep the pan legal, WHEREVER IT CAME FROM.

It lived inside the drag handler, which meant it was only true while a
mouse was moving: anything else that set `_pan` — a tool, a future keyboard
nudge, a restored view — produced a position no drag could ever reach, and
the ship went somewhere it is not allowed to be. `_sync_clip` calls this, so
it holds by construction rather than by everyone remembering.
```

Inside `_clamp_pan()`, above `var bleed := _bleed()`:

```text
CLAMPED AGAINST THE SHIP'S EDGES, not by a symmetric slack around the
middle. A slack says how far the ship may travel; it does not say where
the ship ENDS, so at full pan on a zoomed heavy the hull was dragged
clean out of its own window and what you were looking at was the empty
panel behind it, with the hull sliced off at the edge.

The rule is instead: neither edge of the ship may travel further inside
the window than the bleed. So the front can always be brought to the
front of the window with room for the longest gun ahead of it, and no
drag can put the ship somewhere it is not.
```

Inside `_clamp_pan()`, above `if _view.size.x <= _clip.size.x:`:

```text
A SHIP THAT FITS HAS NOWHERE TO GO. The rule below is about a hull too
WIDE for its window; applied to one that fits, it forces the ship off
centre and holds it there. Measured on a medium at 1x: window 431, ship
276, so the two bounds came out 15 and 60 and the legal range for `_pan.x`
was [15, 60] -- zero was illegal, and `_ship_x()` had already centred the
hull. The ship sat 15px right of centre with nothing having been dragged.

That is the drift reported twice. `_on_clip_input` zeroes `_pan` at 1x,
which fixed it for anything that arrived as an INPUT and could not fix it
for a relayout: the first `_sync_clip` runs before the clip has its final
width, where zero is still legal, and the next one -- unmounting a module,
say -- recomputes against the settled width and shoves the hull right.
```

## Pan at 1x

Inside `_on_clip_input()`, above `if not _zoomed:`:

```text
NOT AT 1x. The line above has always said "only while zoomed" and the code
never checked, which is the whole of the bug: at 1x `_ship_x` centres the
ship and there is nothing off screen to pan TO, but `_clamp_pan` still
allows it as far as +85 -- so a press on the hull and a few pixels of
motion slid the ship off centre and LEFT it there, surviving every later
refresh, because nothing zeroes `_pan` except turning the zoom off.

Measured before this branch existed: a 30px motion at 1x moved the ship
30px right, permanently. Reported as "the ship moved slightly to the
right" after moving a part in the hold -- the hold was innocent.
```

## Turning in the hold

Above `func _turn_in_hold(at: Vector2) -> bool:`:

```text
Turn a part already sitting in the hold, in place if it will still fit.

The whole move is a take-out-and-put-back, so it has to be able to FAIL
cleanly: a 1x3 lance in a hold with no three-wide gap has nowhere to go
turned, and the part must end up exactly where it started rather than in the
first hole the repacker could find for it.
`at` is in screen coordinates and defaults to the cursor at the call site.
Taking it as an argument rather than reading the mouse in here is what makes
it reachable from `-- fittest`: pushed input events start a drag but never
move the OS cursor, so a hover this function looked up itself could only ever
be whatever the physical mouse happened to be sitting on.
```

Above `static func turn_in_hold(grid: HoldGrid, at: Vector2) -> bool:`:

```text
R on a part sitting in a hold grid, shared with LOCAL's cutaway: see above.

ANY HOLD ITEM, NOT ONLY A MODULE. This asked `icon_at`, which finds module
plates and nothing else, so R over a 2x1 crate of deck plate did nothing
while the same crate in the hand turned. `item_at` is the one that sees a
material; the rules are the module's own -- a square shape is a no-op, and a
turn that does not fit puts the item back where it was.
```

## Ship naming

Inside `_refresh()`, above `_name.text = Run.display_name().to_upper()`:

```text
A NAMED SHIP REPLACES THE FRAME'S NAME OUTRIGHT. It used to push it down
to the head of the class line -- "IRONSIDE CUTTER · MEDIUM CHASSIS · C
TIER" -- on the reasoning that a player deciding whether to swap frames
needs to know what they are flying. REVERSED ON REQUEST: once you have
named a ship the frame's name is not what you call it, and printing both
read as the rename not having taken. What the frame IS still says itself
on that line, in the two facts that actually decide a swap -- its weight
and its tier -- and the dialog still offers the old name as its
placeholder.
```

## Hold and deck counts

Inside `_refresh()`, above `_hold.text = "STORAGE — %d of %d cells · DECK %d" % [Run.cargo_used(),`:

```text
Cells, not parts. "6 of 12" counted parts against a capacity in parts, and
neither half of that survives a grid: the hold holds as many things as
their shapes allow, so the honest number is how much ROOM is gone.
CELLS AND CARDS. Cells, not parts, because the hold holds as many things as
their shapes allow -- "6 of 12" counted parts against a capacity in parts
and neither half of that survives a grid.

And the DECK, because that is the number this screen is really about.
`deck_size()` sums `grant_count()` over what is bolted on and the hull
contributes nothing, so every card you will be dealt comes from the
arrangement in front of you -- and after a hull swap unbolts the lot, the
honest reading of an untouched ship is zero.
```

## Loadout panel

Above `func _focus_part(m: ModuleData, slot: MarginContainer = null,`:

```text
What is bolted on, and every card it will deal you.

Grouped by slot rather than listed flat, because that is how the ship is
budgeted: the tally on the left says two of three weapons are filled, and
this is the row that says WHICH two. A flat list makes you count.

Cards at hand scale, which is the scale they are played at. Inspect scale
exists and is exactly 2x, but a card you are reading in a panel is the same
card you will read in a hand, and showing it larger here would teach a size
that never appears in combat.
Point the hull at a part in the list, so reading about it shows you where
it is. The reverse direction already existed — hovering the ship outlines
everything on it — and this closes the loop from the other side.
```

## Row nudge tweens

Inside `_focus_part()`, above `var old: Tween = slot.get_meta(&"nudge") as Tween if slot.has_meta(&"nudge") else null`:

```text
One tween per row, killed before a new one starts: moving the mouse
along the column fires enter and exit faster than a tween finishes,
and two live tweens on one margin fight over it.
`get_meta(key, null)` is not a quiet miss: the engine cannot tell a null
DEFAULT from no default at all, so a row that has never been nudged
prints "does not have any 'meta' values" instead of handing back null.
has_meta is the only way to ask without the error.
```

## Dross block

Above `func _dross_block() -> void:`:

```text
What is WRONG with the ship, at the top of the column where it cannot be
scrolled past.

THE DECK HAD A SECRET IN IT. A malfunction is a card dealt into your hand in
combat and it comes off no module -- so this panel, the one place in the game
that answers "what is in my deck and where did it come from", was silent
about it. The only mention anywhere was a repair line on the Yard's service
list, which means you learned your ship had a blown coupling by being offered
the bill for one, at a station, after whatever fight put it there.

FIRST, NOT LAST. It was written at the foot of the panel, under three slot
groups and a dozen card faces, which on a full loadout is below the fold --
and a warning you have to scroll to is a warning for somebody who already
knows to look. It is the exception on a page of things you chose; it goes
where the eye lands.

Drawn as the CARDS THEMSELVES for the same reason the modules below are: it
is a card you will be holding, and a grey line of text describing one is a
worse picture of it than the card.
```

## Spacers and tally

Above `func _spread(share: float = 1.0) -> Control:`:

```text
The hardpoint tally, mirroring the chassis select's.

Pads reserve to the same ceiling that screen uses, so the two read as one
block seen twice rather than as two designs — and the figures line up in a
column instead of tracking the pad count.
One share of whatever vertical is left over.

Every one of these has the same expand weight, so N of them divide the slack
into N equal parts. That is the whole mechanism behind "evenly distributed":
the column does the arithmetic, and adding a block later does not mean
re-tuning a set of hand-picked gaps.
```

## Drop handlers

Above `func _on_lift(m: ModuleData) -> void:`:

```text
A part dropped onto a mount ON THE HULL.

The mount is a PLACE, so `index` is carried through to the module rather than
derived from the order of `installed` — that was the bug the stored `mount`
fixed and it would come straight back if this appended instead.
Off the ship, into the hand.
```

Above `func _on_hold_drop(payload: Dictionary, at: Vector2i) -> void:`:

```text
The only place `installed` and `cargo` move.

Written as "take it out of wherever it was, then put it where it landed",
because every case is that: a swap is the same two steps with the resident
displaced first. Special-casing storage-to-hardpoint and hardpoint-to-storage
separately is how you end up with a fourth path nobody thought about that
duplicates a module.
Would every one of these fit at once?

Asked by placing them for real and rolling back, because "do N parts fit"
is not a sum: two 1x3 guns need two separate runs of three, and free-cell
arithmetic says yes to a hold that cannot hold either of them.
A part dropped onto a CELL of the hold.

Separate from _on_mount_drop because the two answer different questions. A
hardpoint asks "does this slot type match"; the hold asks "does this shape
fit here", and the cell it fits at is information a mount has no use for.
```

## Name plate

Above `class NameEdit extends Button:`:

```text
THE PENCIL BESIDE THE SHIP'S NAME, drawn rather than typed.

The UI font has no pencil glyph, and an "EDIT" label next to a name reads as
part of the name -- which on this screen means it reads as part of the SHIP'S
name. Everything else in this interface is rectangles on the pixel grid, so
this is too.
```

Inside `_on_hold_drop()`, above `const ART := 11.0`:

```text
THE NAMEPLATE, in art pixels. Square, and eleven rather than the nine the
pencil before it had.

ELEVEN IS THE CEILING, not a preference. The name beside it is FS_HEAD,
whose capitals are ten pixels tall; a square any larger stands proud of
the text it belongs to and starts reading as a panel rather than as a mark
on the end of a line.

Replaced a pencil. The pencil's widest feature was the ferrule at its
blunt end, so the eye landed on the wrong end of it, and at nine pixels a
stepped diagonal is mostly staircase.
```

Inside `_on_hold_drop()`, above `const PAD_X := 3.0`:

```text
Air between the plate and the edge of the clickable box. The box is what
you have to hit; the plate is only what you can see.

THE HORIZONTAL PAD IS PART OF THE GAP TO THE NAME, and was most of it: it
sat on top of the row's own separation, so the mark floated twelve pixels
clear of the word it belongs to and read as the next thing along rather
than as part of the line. Three here against the row's four.
```

Inside `_on_hold_drop()`, above `const REST_DIM := 0.34`:

```text
How far the resting plate is dropped below COLD.

COLD is the ink the masthead's own quiet text is set in, so a mark drawn
in it competes with the writing instead of waiting behind it. A third of
the way to black leaves it plainly there and plainly inactive -- and makes
the lift to ICE and EMBER on hover read as the thing switching on.
```

Inside `_on_hold_drop()`, above `const CAP_RATIO := 5.0 / 8.0`:

```text
Silkscreen's capitals are FIVE of its eight pixels. Measured off the face
and true at every size the game asks for, because UITheme only ever asks
for multiples of eight -- see its note on the font.

The font itself will not answer this: `get_ascent` is 17 at FS_HEAD
against a cap that is 10, so seven of those pixels are leading with
nothing drawn in them. Centring on ascent centres on the leading.
```

Inside `_on_hold_drop()`, above `var _drop: float = 0.0`:

```text
How far the art sits BELOW the middle of its own box.

The row centres this button on the name label's BOX, and that box is
ascent plus descent -- 21 pixels at FS_HEAD. The caps inside it occupy 10,
sitting on a baseline 17 down, so the ink runs 7..16 and its middle is a
pixel and a half UNDER the middle of the box. Centred on the box, the
plate rode high beside every ship name in the game.

Rounded down onto the baseline rather than up: nine rows of plate cannot
be centred exactly in ten of caps, and of the two off-by-half answers the
one that puts the plate's bottom edge ON the baseline is a relationship
rather than a coin toss.
```

Inside `_on_hold_drop()`, above `draw_rect(Rect2(o + Vector2(2, 4), Vector2(7, 1)), mark, true)`:

```text
Two engraved lines, UNEQUAL. Two bars the same length read as a gauge;
a long one over a short one reads as a name over what the thing is --
which is what the masthead beside it actually says.
Three rows of air above, three below, one between: the pair sits as a
BLOCK of text on the plate rather than as two marks that happen to be
in the same box.
```

## The runs routines

Above `static func fill_routines(box: Control) -> void:`:

```text
THE RUN'S ROUTINES (science), into `box` (cleared first): one line, "ROUTINES
· 4 OF 9", the names and what each does on hover (`RoutineBox`). Hidden with
none bought, so a run that never reaches a Lab shows the panel it always had.
Kept OUT of `fill_perks`: the perks are the hull's and change at a yard, the
routines are the flight computer's and do not, and one block for both would
hide which is which.
```
