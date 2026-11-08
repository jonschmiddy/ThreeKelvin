The reasoning behind `tkg/scripts/ui/LauncherScreen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Title screen

Above `const WARMUP_FRAMES := 4`:

```text
Title screen. The first thing the game shows, and the only screen that exists
before a run does.

It has to work with NO run loaded — Run.hull is null until something starts
one — so nothing here may read ship state. Router hides the HUD while this is
up for the same reason: a bar showing 0/0 hull above a title screen is a bug
that looks like a design.

CONTINUE is offered only when a suspend save is on disk, and it names the
system and the hull so the button is a decision rather than a guess. Loading
consumes the file — see SaveGame.
```

## Sky warmup

Above `const WARMUP_FRAMES := 4`:

```text
Frames to let the sky settle before it starts turning.

Belt and braces next to warm_sky(), which already moves the expensive galaxy
build off the first painted frame. This covers what it cannot: the first
paint of forty-eight thousand rects is still the longest frame on this
screen, and a long frame that is also a MOVING one is a frame the display can
show partway through.
```

## Galaxy turn

Above `const TITLE_TURN := ChartSky.TURN_MINUTES / 5.0`:

```text
THE TITLE'S GALAXY TURNS FASTER than the chart's (once in 12 hours there):
once every five minutes, so the arms are seen to wheel behind the menu
(Jon, Oct 6). A multiple of `ChartSky.OMEGA`, as `MapChart.turn_speed`.
```

## Bearing fix

Above `const BEARING_FIX := (TITLE_SIZE - MENU_SIZE) / 8`:

```text
Left side bearing, in pixels, for text at MENU_SIZE against text at
TITLE_SIZE.

Silkscreen leaves one blank column to the left of a glyph at its native 8px,
so that gap scales with the type: six pixels at 48, two at 16. Setting both
flush left therefore puts the SMALL text four pixels further left than the
title, which is the gap visible under THREE KELVIN. Derived from the grid
rather than nudged by eye, so it stays right if either size changes.
```

## Popup inset

Above `const POPUP_INSET_H := 170`:

```text
How far the popup frame sits inside the screen. TWO numbers, one shared by all
three popups — the lobby, the flight record and the continue prompt are the
same kind of object and should not be three different rectangles.

Wider inset than tall on purpose. On a 960x540 viewport this leaves about
620x348, which is portrait-ish rather than a letterbox. Every one of these
panels is a COLUMN of things — a list of runs, a stack of party fields, a
question and two buttons — and a column reads badly stretched across a wide
frame: the eye has to travel the full width to find the next short line.
Vertical space is the cheap axis here, because the content scrolls.
```

## Sky fit

Above `var _fitted: bool = false`:

```text
Whether the sky has been given its real size yet.

setup() runs before the layout pass has assigned this screen a size, so the
first _fit_sky() bails and the real one arrives with NOTIFICATION_RESIZED a
frame or two later. Rotating in between spun a square that was still at its
default size, sweeping its axis-aligned edges straight across the view — a
vertical and a horizontal tear for the first few frames, and then correct
forever, which is exactly the shape of a race.
```

Above `func _fit_sky() -> void:`:

```text
Square, and as wide as the screen's DIAGONAL.

A rotating rectangle sweeps its corners through the frame, so a screen-sized
sky would show two wedges of nothing at every angle but zero. A square whose
side matches the diagonal has an inscribed circle that reaches every corner of
the screen, so no rotation can ever expose an edge. It costs about two and a
half times the area in stars — paid once, because rotating a Control moves its
retained draw list rather than repainting it.
```

Inside `_fit_sky()`, above `var side := ceilf(sqrt(size.x * size.x + size.y * size.y)) + 24.0`:

```text
+24 rather than +8. The square's inscribed circle has to REACH the screen's
corners, and at +8 it cleared them by four pixels — close enough that a
rounding difference anywhere in the transform put the square's own edge
through a corner. The margin costs nothing: star counts are fixed, so a
bigger square spreads the same field rather than drawing more of it.
```

## Menu layout

Inside `setup()`, above `var holder := MarginContainer.new()`:

```text
Title in the top corner, options in the bottom one, galaxy through the
middle. No panel, no boxes, no centring.

The galaxy is the picture; a menu is a thing you use once and then never
look at again, so it gets the corner and the title gets the scale. One
column pinned left does both — the spacer between them is what pushes the
options to the floor.
```

## Removed archive

Inside `setup()`, above `menu.add_child(_option("SETTINGS", _open_settings))`:

```text
(THE ARCHIVE stood here, a reading room of recovered documents. Jon, Oct
22: "It was a cool idea, but not for a procedural game." Gone from the
HUD as well.)
```

## Menu order

Inside `setup()`, above `_news = _option("NEW THINGS", open_new_things)`:

```text
NEW THINGS (Jon, Nov 5): what changed in each build. Above MESSAGE FROM
JON, not under it: that one is "the line above QUIT" (Jon, Oct 13), and the
two pages to read sit together under the things you do.
```

## Dev toggle

Above `func _input(e: InputEvent) -> void:`:

```text
The developer switch, small, in the corner where a build stamp goes.

Only where DevMode.available: from the editor, never in an exported game.
Nothing else is anchored to that corner, so a build without it leaves the
corner empty and moves nothing.

Not in the menu column: that column is the five things a player came here to
do, and this is not one of them. A corner checkbox reads as a property OF the
build rather than as a destination, which is what it is.

Anchored to the bottom-right of the screen rather than laid out in a
container, so it stays pinned to the corner at every window size and cannot
push the title or the menu around.

Repaints ITSELF and nothing else.

It used to rebuild the whole launcher, on the reasoning that everything this
flag gates is built-or-not-built rather than hidden. That was true and still
is — but the only thing ON THIS SCREEN the flag changes is this checkbox, and
rebuilding took the galaxy backdrop with it, restarting its rotation from zero
every time the switch was touched.

Every other screen rebuilds off Sig.dev_mode_changed instead, which is where
that responsibility belongs: the HUD outlives screen swaps and had to listen
anyway, and a screen built AFTER the toggle reads the flag correctly for free.
THE ARROW KEYS DO NOTHING HERE (Jon: "WASD and the Arrows should not work in
the title menu"). Left alone, Godot walks the keyboard focus round the menu's
buttons with them; the menu is clicked. A typed seed keeps its caret.
```

Inside `_add_dev_toggle()`, above `_dev_box = Widgets.button("", _on_dev_toggle)`:

```text
Built through Widgets.button so it gets the click and hover sounds, which
means the action has to be supplied at construction — it connects `pressed`
immediately and a null Callable is an error. A named method rather than a
lambda, so `-- devtest` can find what is wired to the switch: it reaches
the button through the member, since the button does not exist yet.
```

## Continue prompt

Above `func _confirm_continue() -> void:`:

```text
CONTINUE, with the thing it consumes shown first.

The only one of the three that is not a screen — it loads and flies. It gets
a panel anyway because it is the single irreversible button on this screen:
loading DELETES the save, by design, so that quitting stays a bookmark
rather than a checkpoint. A menu item that quietly eats your only save on
one click was relying on a tooltip nobody has to read.
```

## Popups

Above `const POPUP_PROMPT_W := 356`:

```text
Open a screen OVER the title rather than instead of it.

The lobby, the flight record and the continue prompt are all things you do
BEFORE a run, from the title screen, and swapping the whole view for them
threw away the galaxy behind it and made coming back a rebuild. As overlays
they read as what they are: a panel you opened and will close again.

The shade eats input, so the menu underneath cannot be clicked through, and
a click on the dim margin closes — the same dismissal the deck popup uses.
How wide a PROMPT is. The lobby and the flight record are lists and want the
full frame; a question and two buttons wants a card.

Width is fixed and height is not, which is the whole trick. The complaint that
started the popups was that they were three different rectangles — and what
read as ragged was the WIDTH, because that is the edge your eye lines up
against. Height following content is not raggedness, it is a panel that is as
tall as what is in it.
```

Inside `_open_popup()`, above `var shade := ColorRect.new()`:

```text
The shade lays the popup out and takes the clicks, over this screen's rect
as it always has; the dim it draws is its first child, over the whole
picture (`Widgets.cover_picture`): this screen stops short of the glass by
Main's margin, and the galaxy, which does not, showed through it undimmed
```

## Freed seed field

Inside `_close_popup()`, above `_seed_field = null`:

```text
The seed field lived inside that popup and is now on its way out. A freed
Node is NOT null in GDScript — it is an invalid instance, which sails
straight past `== null` and fails on the next property read. Dropping the
reference here is what makes _typed_seed()'s guard mean anything.
```

## Menu lines

Above `func _line(text: String, colour: Color, size: int) -> Label:`:

```text
A left-aligned line of text.

Explicit about both alignment and sizing rather than trusting defaults: these
labels sit in a column as wide as THREE KELVIN at 48px, so a label that
stretches has six hundred pixels to drift in, and only its alignment decides
where the words land. SHRINK_BEGIN makes each label its own width instead,
which takes the question away entirely.
```

## New run prompt

Above `func _confirm_new_run() -> void:`:

```text
A menu line: text, and nothing else.

Still built through Widgets.button, because that is where every click, hover
and refusal sound in the game is wired — a hand-rolled Button here would be
the one silent control in the interface. Only the look is overridden.

SHRINK_BEGIN matters: without it a VBox child fills the column, and since the
column is as wide as THREE KELVIN at 32px, the clickable area of QUIT would
reach a third of the way across the screen with nothing drawn in it.
What NEW RUN opens now, rather than a field parked on the title screen.

MOVED, and for two reasons rather than one. The seed belongs to the moment
you start a run, not to the screen you start it from — a title screen with a
number field on it reads like a debug build. And NEW RUN was already the one
destructive item in this menu with no confirmation on it: Router.new_run()
records an ABANDONED run and clears the save when one is live, which is
exactly the thing CONTINUE gets a panel for.

So this panel does both jobs. With a save it warns; without one it is simply
where you decide whether this run is a fresh galaxy or a named one.

NOT ON A FRESH PROFILE (tutorial direction B, Oct 17): no save and no run on
the flight record means a first launch, and asking somebody about seeds
before they know what a run is was one click spent on a question they could
not answer. Straight to the hull pick; the panel is there from the second run.
```

## Leave button

Above `func _leave_button(text: String, action: Callable) -> Button:`:

```text
A button that LEAVES. Both prompts have one and the menu has QUIT, and they
are the same idea: the control that puts you back where you were.

Coloured rather than styled, so it still reads as one of a pair with the
button beside it. A red BOX next to a normal one says the two do opposite
things; red text on the same box says one of them is the way out.
```

## Title galaxy

Above `func _make_sky() -> void:`:

```text
The galaxy behind the title, turning.

It is the chart's own MapChart with show_icons off — the mode the chart
already has for "the galaxy alone: no routes, no trail, no glyphs, nothing
that answers the cursor". Reusing it rather than writing a second galaxy
renderer matters more here than it looks: the sky is forty-eight thousand
precomputed points, nine kinds of structure and a static cache, and a
simplified copy for the title screen would be a second answer to "what does a
galaxy look like" that nobody would remember to update.

Added before everything else so it sits behind the panel; siblings paint in
child order.
```

Inside `_make_sky()`, above `_sky.clip_contents = false`:

```text
THE TEAR. MapChart clips to its own rect so the galaxy cannot spill out of
the chart panel, and that clip is AXIS-ALIGNED — so a rotating child gets
cut along a vertical and a horizontal line. On the chart the clip is the
panel edge and that is exactly right; here the sky is deliberately larger
than the screen and there is nothing to protect, so clipping only supplies
two straight edges for the rotation to drag across the view.
```

Above `static var _sky_kind: int = -1`:

```text
A galaxy for the title screen, rolled once per process and kept.

Written into Run, which is legitimate rather than a shortcut: RunState seeds
Run.galaxy at _ready specifically so screens can draw before a run exists, and
both ways out of this screen overwrite it — NEW RUN through start_new_run(),
CONTINUE through SaveGame. Run.map and Run.hull stay untouched, so no save is
written and the HUD stays hidden.

Static so that coming back to the title screen does not roll a different
galaxy and throw away the sky cache to build the same thing again.
```
