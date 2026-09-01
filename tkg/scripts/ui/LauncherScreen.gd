class_name LauncherScreen
extends Control

## Title screen. The first thing the game shows, and the only screen that exists
## before a run does.
##
## It has to work with NO run loaded — Run.hull is null until something starts
## one — so nothing here may read ship state. Router hides the HUD while this is
## up for the same reason: a bar showing 0/0 hull above a title screen is a bug
## that looks like a design.
##
## CONTINUE is offered only when a suspend save is on disk, and it names the
## system and the hull so the button is a decision rather than a guess. Loading
## consumes the file — see SaveGame.

const SUBTITLE := "three degrees above absolute zero"

## Radians per second. A full turn takes about fifty minutes, which is the
## point: the galaxy should never appear to be spinning, only to have moved
## while you were reading. Anything fast enough to watch turns a backdrop into
## an animation, and this screen is mostly looked past rather than at.
##
## Negative because Godot's y axis points down, so a positive angle turns
## clockwise on screen. Which way a galaxy turns is a look decision, not a
## physical one — the arms are drawn with a fixed handedness, and this is the
## direction that suits them.
const SPIN := -0.0021

## Frames to let the sky settle before it starts turning.
##
## Belt and braces next to warm_sky(), which already moves the expensive galaxy
## build off the first painted frame. This covers what it cannot: the first
## paint of forty-eight thousand rects is still the longest frame on this
## screen, and a long frame that is also a MOVING one is a frame the display can
## show partway through.
const WARMUP_FRAMES := 4

## How often the turn is pushed to the sky, in seconds.
##
## MEASURED, not guessed: a full repaint of the field is 10.1ms for 24,000
## stars, so doing it every frame spends sixty per cent of a 16.6ms budget on
## the backdrop alone. At 30Hz it is half that, with peak frames still inside
## the budget.
##
## The other end of this is what chop actually is. A repaint moves every star
## that crossed a pixel boundary since the LAST one, so the interval decides how
## many move together: at 30Hz under one per cent of the field shifts per
## repaint and it reads as drift, while at the 1.2Hz this screen briefly ran
## at, a quarter of the galaxy stepped at once.
const SKY_STEP := 1.0 / 30.0
## The galaxy's edge, as a fraction of half the screen's short side. Just over
## one, so the outer arms run off the top and bottom rather than sitting in the
## middle of a lot of empty space — there is no route to plan here, so the
## framing can be composed instead of useful.
const SKY_FILL := 1.12
## Six times the 8px face. Silkscreen is drawn on an 8px grid, so it only stays
## crisp at integer multiples — 8, 16, 24, 32, 48. 48 is a size, not a number
## picked for how it looked; 44 would render soft.
const TITLE_SIZE := 48
## The menu, and the tagline with it. One size for everything that is not the
## title, so the corner reads as two things rather than four.
const MENU_SIZE := UITheme.FS_HEAD

## Left side bearing, in pixels, for text at MENU_SIZE against text at
## TITLE_SIZE.
##
## Silkscreen leaves one blank column to the left of a glyph at its native 8px,
## so that gap scales with the type: six pixels at 48, two at 16. Setting both
## flush left therefore puts the SMALL text four pixels further left than the
## title, which is the gap visible under THREE KELVIN. Derived from the grid
## rather than nudged by eye, so it stays right if either size changes.
const BEARING_FIX := (TITLE_SIZE - MENU_SIZE) / 8

var _settings: SettingsMenu = null
## The dim + panel that FLY TOGETHER, FLIGHT RECORD and CONTINUE open into.
## One at a time, and never at the same time as the settings menu.
var _popup: Control = null
## How far the popup frame sits inside the screen. TWO numbers, one shared by all
## three popups — the lobby, the flight record and the continue prompt are the
## same kind of object and should not be three different rectangles.
##
## Wider inset than tall on purpose. On a 960x540 viewport this leaves about
## 620x348, which is portrait-ish rather than a letterbox. Every one of these
## panels is a COLUMN of things — a list of runs, a stack of party fields, a
## question and two buttons — and a column reads badly stretched across a wide
## frame: the eye has to travel the full width to find the next short line.
## Vertical space is the cheap axis here, because the content scrolls.
const POPUP_INSET_H := 170
const POPUP_INSET_V := 96
## The corner checkbox, kept so it can repaint itself when flipped.
var _dev_box: Button = null
var _seed_field: LineEdit = null
var _sky: StarchartScreen.MapChart = null
var _spin: float = 0.0
## Whether the sky has been given its real size yet.
##
## setup() runs before the layout pass has assigned this screen a size, so the
## first _fit_sky() bails and the real one arrives with NOTIFICATION_RESIZED a
## frame or two later. Rotating in between spun a square that was still at its
## default size, sweeping its axis-aligned edges straight across the view — a
## vertical and a horizontal tear for the first few frames, and then correct
## forever, which is exactly the shape of a race.
var _fitted: bool = false
var _warmup: int = WARMUP_FRAMES
var _since: float = 0.0

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_sky()

	# Title in the top corner, options in the bottom one, galaxy through the
	# middle. No panel, no boxes, no centring.
	#
	# The galaxy is the picture; a menu is a thing you use once and then never
	# look at again, so it gets the corner and the title gets the scale. One
	# column pinned left does both — the spacer between them is what pushes the
	# options to the floor.
	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_theme_constant_override("margin_left", 22)
	holder.add_theme_constant_override("margin_top", 14)
	holder.add_theme_constant_override("margin_bottom", 24)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_add_dev_toggle()

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	# Eats the rest of the width, so the column is only ever as wide as the
	# widest thing in it.
	var wide := Control.new()
	wide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(wide)

	col.add_child(_line("THREE KELVIN", UITheme.ICE, TITLE_SIZE))
	col.add_child(_indent(_line(SUBTITLE, UITheme.COLD, MENU_SIZE)))

	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	push.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(push)

	# Everything at MENU_SIZE shares one indent, so the menu block and the
	# tagline line up with each other as well as with the title.
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 2)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_indent(menu))

	var save := SaveGame.summary()
	if not save.is_empty():
		# What the save holds, and what continuing costs, on the hover rather
		# than under the word. Two lines of grey explaining one menu item is the
		# kind of thing a title screen accumulates — you read it once, ever, and
		# then it sits there being the busiest part of the corner.
		menu.add_child(_option("CONTINUE", _confirm_continue, true))

	# White marks the option you most likely came here for, and there is exactly
	# one: the run you were already flying, or — with nothing to return to — a
	# new one. Everything else is grey. Hard-coding CONTINUE as the white one
	# would leave a first-time player looking at five identical grey lines.
	menu.add_child(_option("NEW RUN", _confirm_new_run, save.is_empty()))
	# Under NEW RUN rather than above it: the tutorial is a kind of run, not
	# the thing most visits to this screen are for. It is a real run on a
	# curated seed with a panel narrating it -- see Router.new_tutorial.
	menu.add_child(_option("FIRST FLIGHT", _confirm_tutorial))
	menu.add_child(_option("FLY TOGETHER", func() -> void:
		var lob := LobbyScreen.new()
		lob.on_leave = _close_popup
		_open_popup(lob)
		lob.setup()))
	menu.add_child(_option("FLIGHT RECORD", func() -> void:
		var hist := HistoryScreen.new()
		_open_popup(hist)
		hist.setup(_close_popup)))
	# On the title screen as well as on the HUD, because what you have read
	# survives the ship. The archive is the one thing here that is not about a
	# run — it is about the runs, plural, and the place to read it is the place
	# you are between them.
	menu.add_child(_option("THE ARCHIVE", func() -> void:
		var arc := ArchiveScreen.new()
		_open_popup(arc)
		arc.setup(_close_popup)))
	menu.add_child(_option("SETTINGS", _open_settings))

	# Red on hover, alone among the five. Everything else on this screen leads
	# somewhere you can come back from.
	var quit := _option("QUIT", func() -> void: get_tree().quit())
	quit.add_theme_color_override("font_hover_color", UITheme.LEAVE)
	quit.add_theme_color_override("font_pressed_color", Color("#f08872"))
	menu.add_child(quit)

## The developer switch, small, in the corner where a build stamp goes.
##
## Not in the menu column: that column is the five things a player came here to
## do, and this is not one of them. A corner checkbox reads as a property OF the
## build rather than as a destination, which is what it is.
##
## Anchored to the bottom-right of the screen rather than laid out in a
## container, so it stays pinned to the corner at every window size and cannot
## push the title or the menu around.
##
## Repaints ITSELF and nothing else.
##
## It used to rebuild the whole launcher, on the reasoning that everything this
## flag gates is built-or-not-built rather than hidden. That was true and still
## is — but the only thing ON THIS SCREEN the flag changes is this checkbox, and
## rebuilding took the galaxy backdrop with it, restarting its rotation from zero
## every time the switch was touched.
##
## Every other screen rebuilds off Sig.dev_mode_changed instead, which is where
## that responsibility belongs: the HUD outlives screen swaps and had to listen
## anyway, and a screen built AFTER the toggle reads the flag correctly for free.
func _add_dev_toggle() -> void:
	# Built through Widgets.button so it gets the click and hover sounds, which
	# means the action has to be supplied at construction — it connects `pressed`
	# immediately and a null Callable is an error. The lambda reaches the button
	# through the member rather than through itself, since it cannot capture a
	# local that does not exist yet.
	_dev_box = Widgets.button("", func() -> void:
		DevMode.toggle()
		_paint_dev_toggle(_dev_box))
	var box := _dev_box
	box.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	box.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_theme_color_override("font_hover_color", UITheme.ICE)
	box.add_theme_color_override("font_pressed_color", UITheme.HOT)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		box.add_theme_stylebox_override(st, UITheme.empty())
	_paint_dev_toggle(box)
	box.tooltip_text = Widgets.tip("Card gallery, the whole star chart, and any hull grade at launch.\nNot the game — do not judge pacing or difficulty with this on.")
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -14
	box.offset_bottom = -10
	add_child(box)

## CONTINUE, with the thing it consumes shown first.
##
## The only one of the three that is not a screen — it loads and flies. It gets
## a panel anyway because it is the single irreversible button on this screen:
## loading DELETES the save, by design, so that quitting stays a bookmark
## rather than a checkpoint. A menu item that quietly eats your only save on
## one click was relying on a tooltip nobody has to read.
func _confirm_continue() -> void:
	var save := SaveGame.summary()
	if save.is_empty():
		return
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(UITheme.body("RESUME THIS RUN", UITheme.ICE, UITheme.FS_HEAD))
	col.add_child(UITheme.body(_save_line(save), UITheme.CHILL, UITheme.FS_SMALL))
	col.add_child(UITheme.body(
		"Continuing consumes the save. There is no going back to it.",
		UITheme.COLD, UITheme.FS_SMALL))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(Widgets.button("CONTINUE", func() -> void:
		_close_popup()
		Router.continue_run()))
	row.add_child(_leave_button("NOT YET", _close_popup))
	col.add_child(row)

	_open_popup(col, true)

## Open a screen OVER the title rather than instead of it.
##
## The lobby, the flight record and the continue prompt are all things you do
## BEFORE a run, from the title screen, and swapping the whole view for them
## threw away the galaxy behind it and made coming back a rebuild. As overlays
## they read as what they are: a panel you opened and will close again.
##
## The shade eats input, so the menu underneath cannot be clicked through, and
## a click on the dim margin closes — the same dismissal the deck popup uses.
## How wide a PROMPT is. The lobby and the flight record are lists and want the
## full frame; a question and two buttons wants a card.
##
## Width is fixed and height is not, which is the whole trick. The complaint that
## started the popups was that they were three different rectangles — and what
## read as ragged was the WIDTH, because that is the edge your eye lines up
## against. Height following content is not raggedness, it is a panel that is as
## tall as what is in it.
const POPUP_PROMPT_W := 356

func _open_popup(inner: Control, compact: bool = false) -> void:
	if _popup != null or _settings != null:
		return
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.80)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_close_popup())
	add_child(shade)
	_popup = shade

	# A prompt is centred at its own size, with no scroll around it. The scroll
	# below exists to force long content to the frame's width; a prompt has no
	# long content, and wrapping a short column in a ScrollContainer is what was
	# stretching these to the full 620x348 whatever they held.
	if compact:
		var mid := CenterContainer.new()
		mid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.add_child(mid)
		var card := Widgets.panel_with(inner)
		card.custom_minimum_size = Vector2(POPUP_PROMPT_W, 0)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		mid.add_child(card)
		return

	var pad := Widgets.pad(null, POPUP_INSET_H, POPUP_INSET_V)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(pad)

	# Scrolled, and horizontal scrolling DISABLED on purpose. That is what forces
	# the content to the panel's width, which is what makes wrapping labels
	# actually wrap — these screens were written to fill a viewport, and given a
	# free horizontal axis a long line simply widens the column and runs off the
	# frame instead of folding.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)

	# The panel stops the press, so only the dim margin dismisses.
	var frame := Widgets.panel_with(scroll)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	pad.add_child(frame)

## The box and its colour, for whichever state the flag is in now.
static func _paint_dev_toggle(box: Button) -> void:
	Widgets.paint_toggle(box, "DEVELOPER MODE", DevMode.enabled)

func _close_popup() -> void:
	if _popup == null:
		return
	_popup.queue_free()
	_popup = null
	# The seed field lived inside that popup and is now on its way out. A freed
	# Node is NOT null in GDScript — it is an invalid instance, which sails
	# straight past `== null` and fails on the next property read. Dropping the
	# reference here is what makes _typed_seed()'s guard mean anything.
	_seed_field = null

## Nudge a control right by the side-bearing difference. See BEARING_FIX.
func _indent(c: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", BEARING_FIX)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	m.add_child(c)
	return m

## A left-aligned line of text.
##
## Explicit about both alignment and sizing rather than trusting defaults: these
## labels sit in a column as wide as THREE KELVIN at 48px, so a label that
## stretches has six hundred pixels to drift in, and only its alignment decides
## where the words land. SHRINK_BEGIN makes each label its own width instead,
## which takes the question away entirely.
func _line(text: String, colour: Color, size: int) -> Label:
	var l := UITheme.body(text, colour, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return l

## A menu line: text, and nothing else.
##
## Still built through Widgets.button, because that is where every click, hover
## and refusal sound in the game is wired — a hand-rolled Button here would be
## the one silent control in the interface. Only the look is overridden.
##
## SHRINK_BEGIN matters: without it a VBox child fills the column, and since the
## column is as wide as THREE KELVIN at 32px, the clickable area of QUIT would
## reach a third of the way across the screen with nothing drawn in it.
## What NEW RUN opens now, rather than a field parked on the title screen.
##
## MOVED, and for two reasons rather than one. The seed belongs to the moment
## you start a run, not to the screen you start it from — a title screen with a
## number field on it reads like a debug build. And NEW RUN was already the one
## destructive item in this menu with no confirmation on it: Router.new_run()
## records an ABANDONED run and clears the save when one is live, which is
## exactly the thing CONTINUE gets a panel for.
##
## So this panel does both jobs. With a save it warns; without one it is simply
## where you decide whether this run is a fresh galaxy or a named one.
func _confirm_new_run() -> void:
	var save := SaveGame.summary()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(UITheme.body("LAUNCH A RUN", UITheme.ICE, UITheme.FS_HEAD))
	if save.is_empty():
		col.add_child(UITheme.body(
			"Leave the seed empty for a galaxy nobody has flown.",
			UITheme.COLD, UITheme.FS_SMALL))
	else:
		# The abandoned run still goes on the flight record, so this is a cost
		# rather than a deletion — worth saying which.
		col.add_child(UITheme.body(_save_line(save), UITheme.CHILL, UITheme.FS_SMALL))
		col.add_child(UITheme.body(
			"Launching abandons that run. It keeps its place on the flight record.",
			UITheme.COLD, UITheme.FS_SMALL))
	col.add_child(_gap(4))
	col.add_child(_seed_row())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(Widgets.button("LAUNCH", _launch))
	row.add_child(_leave_button("NOT YET", _close_popup))
	col.add_child(row)

	_open_popup(col, true)
	# Typing is the whole reason this panel exists, so the caret starts in the
	# field. Everything else here is one keystroke away either way.
	if _seed_field != null:
		_seed_field.grab_focus()

func _launch() -> void:
	var n := _typed_seed()
	_close_popup()
	Router.new_run(n)

## FIRST FLIGHT. Straight in when nothing would be lost; one question when a
## suspended run is on disk, because the tutorial abandons it exactly the way
## NEW RUN does and deserves exactly the same warning. No seed field -- the
## seed is the one thing this run exists to have chosen already.
func _confirm_tutorial() -> void:
	var save := SaveGame.summary()
	if save.is_empty():
		Router.new_tutorial()
		return
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(UITheme.body("FIRST FLIGHT", UITheme.ICE, UITheme.FS_HEAD))
	col.add_child(UITheme.body(_save_line(save), UITheme.CHILL, UITheme.FS_SMALL))
	col.add_child(UITheme.body(
		"Launching abandons that run. It keeps its place on the flight record.",
		UITheme.COLD, UITheme.FS_SMALL))
	col.add_child(_gap(4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(Widgets.button("LAUNCH", _launch_tutorial))
	row.add_child(_leave_button("NOT YET", _close_popup))
	col.add_child(row)
	_open_popup(col, true)

func _launch_tutorial() -> void:
	_close_popup()
	Router.new_tutorial()

## SEED, and a box to put one in.
func _seed_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	# On the label, not on a "?" beside it. The panel already states the common
	# case in a full sentence; this only has to cover what it leaves out.
	var lab := UITheme.body("SEED", UITheme.COLD, UITheme.FS_SMALL)
	lab.mouse_filter = Control.MOUSE_FILTER_STOP
	lab.tooltip_text = Widgets.tip("Seeded run\nFly the same number again for the same galaxy, map and loot. Old ones are on the flight record.")
	row.add_child(lab)

	_seed_field = LineEdit.new()
	_seed_field.custom_minimum_size = Vector2(96, 0)
	_seed_field.placeholder_text = "random"
	_seed_field.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_seed_field.max_length = 10
	_seed_field.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	_seed_field.add_theme_color_override("font_color", UITheme.CHILL)
	_seed_field.add_theme_color_override("font_placeholder_color", UITheme.LINE)
	_seed_field.add_theme_stylebox_override("normal",
		UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 3, 6))
	_seed_field.add_theme_stylebox_override("focus",
		UITheme.flat(UITheme.PANEL2, UITheme.COLD, 0, 3, 6))
	# Digits only, and filtered on the way in rather than validated on the way
	# out: a field that accepts letters and then silently ignores them has lied.
	_seed_field.text_changed.connect(func(t: String) -> void:
		var clean := ""
		for c in t:
			if c >= "0" and c <= "9":
				clean += c
		if clean != t:
			_seed_field.text = clean
			_seed_field.caret_column = clean.length())
	# Enter is LAUNCH. Somebody typing a seed has both hands on the keyboard and
	# reaching for the mouse to press the button beside the field is silly.
	_seed_field.text_submitted.connect(func(_t: String) -> void: _launch())
	row.add_child(_seed_field)
	return row

## What is in the field, or 0 for "roll one". Router.new_run() reads 0 as random,
## so an empty field needs no special case anywhere else.
func _typed_seed() -> int:
	if _seed_field == null:
		return 0
	return int(_seed_field.text.strip_edges())


## A button that LEAVES. Both prompts have one and the menu has QUIT, and they
## are the same idea: the control that puts you back where you were.
##
## Coloured rather than styled, so it still reads as one of a pair with the
## button beside it. A red BOX next to a normal one says the two do opposite
## things; red text on the same box says one of them is the way out.
func _leave_button(text: String, action: Callable) -> Button:
	var b := Widgets.button(text, action)
	b.add_theme_color_override("font_color", UITheme.LEAVE)
	b.add_theme_color_override("font_hover_color", UITheme.LEAVE.lightened(0.3))
	b.add_theme_color_override("font_focus_color", UITheme.LEAVE)
	return b


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _option(text: String, action: Callable, primary: bool = false) -> Button:
	var b := Widgets.button(text, action)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", MENU_SIZE)
	# Grey at rest, white for the primary, warm on hover. Three states doing
	# three jobs: what you can do, what you probably want, and what you are
	# pointing at.
	var rest := UITheme.ICE if primary else UITheme.COLD
	b.add_theme_color_override("font_color", rest)
	b.add_theme_color_override("font_hover_color", UITheme.HOT)
	b.add_theme_color_override("font_pressed_color", UITheme.FLARE)
	b.add_theme_color_override("font_focus_color", rest)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, UITheme.empty())
	return b

# ------------------------------------------------------------------------- sky

## The galaxy behind the title, turning.
##
## It is the chart's own MapChart with show_icons off — the mode the chart
## already has for "the galaxy alone: no routes, no trail, no glyphs, nothing
## that answers the cursor". Reusing it rather than writing a second galaxy
## renderer matters more here than it looks: the sky is forty-eight thousand
## precomputed points, nine kinds of structure and a static cache, and a
## simplified copy for the title screen would be a second answer to "what does a
## galaxy look like" that nobody would remember to update.
##
## Added before everything else so it sits behind the panel; siblings paint in
## child order.
func _make_sky() -> void:
	_roll_sky_galaxy()
	_sky = StarchartScreen.MapChart.new()
	_sky.show_icons = false
	# THE TEAR. MapChart clips to its own rect so the galaxy cannot spill out of
	# the chart panel, and that clip is AXIS-ALIGNED — so a rotating child gets
	# cut along a vertical and a horizontal line. On the chart the clip is the
	# panel edge and that is exactly right; here the sky is deliberately larger
	# than the screen and there is nothing to protect, so clipping only supplies
	# two straight edges for the rotation to drag across the view.
	_sky.clip_contents = false
	# The live core at 30 rather than 60. Nothing here drags, so the reason the
	# chart runs it every frame does not apply, and halving it halves the only
	# per-frame cost this screen has.
	_sky.set_anim_interval(1.0 / 30.0)
	# The buttons are in front and get the click first, but a full-screen Control
	# with STOP would eat every press that lands beside them.
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hidden until it has been sized and framed. A wrongly-sized galaxy drawn for
	# one frame and then corrected is a visible pop, and there is nothing behind
	# it to show through — the screen is black either way.
	_sky.visible = false
	add_child(_sky)
	_fit_sky()

## Square, and as wide as the screen's DIAGONAL.
##
## A rotating rectangle sweeps its corners through the frame, so a screen-sized
## sky would show two wedges of nothing at every angle but zero. A square whose
## side matches the diagonal has an inscribed circle that reaches every corner of
## the screen, so no rotation can ever expose an edge. It costs about two and a
## half times the area in stars — paid once, because rotating a Control moves its
## retained draw list rather than repainting it.
func _fit_sky() -> void:
	if _sky == null or size.x <= 0.0 or size.y <= 0.0:
		return
	# +24 rather than +8. The square's inscribed circle has to REACH the screen's
	# corners, and at +8 it cleared them by four pixels — close enough that a
	# rounding difference anywhere in the transform put the square's own edge
	# through a corner. The margin costs nothing: star counts are fixed, so a
	# bigger square spreads the same field rather than drawing more of it.
	var side := ceilf(sqrt(size.x * size.x + size.y * size.y)) + 24.0
	var sq := Vector2(side, side)
	_sky.size = sq
	_sky.position = (size - sq) * 0.5
	_sky.pivot_offset = sq * 0.5
	# After the size, because the framing is derived from it — and against the
	# screen rather than the square, which is deliberately larger than the view.
	_sky.frame_to(size, SKY_FILL)
	_sky.set_sky_rotation(_spin)
	# Pay for the galaxy here, with nothing on screen and nothing turning,
	# instead of inside the first frame that paints it.
	_sky.warm_sky()
	_fitted = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_sky()

func _process(delta: float) -> void:
	if _sky == null or not _fitted:
		return
	if not _sky.visible:
		# Shown a frame AFTER fitting, never in _fit_sky itself. The sky's four
		# layers are anchored to it, so their rects are resolved by the layout
		# pass that follows — painting in the same frame the size changed means
		# painting layers that are still the old size.
		_sky.visible = true
		return
	if _warmup > 0:
		_warmup -= 1
		return
	# Wrapped rather than accumulated. A float that only ever grows loses
	# precision in the low bits, and this one is added to every frame for as long
	# as the title screen is up — which, on a game people leave running, is
	# indefinitely.
	# The angle advances every frame; only the PUSH to the sky is throttled, so
	# the rotation stays exactly in step with wall-clock time however often it is
	# drawn. Accumulating on the drawn frames instead would make the galaxy's
	# speed a function of the frame rate.
	_spin = fmod(_spin + delta * SPIN, TAU)
	_since += delta
	if _since < SKY_STEP:
		return
	_since = 0.0
	# Turns the galaxy's own two layers. The deep field and the halo are separate
	# canvases and stay where they are — other galaxies do not orbit ours.
	_sky.set_sky_rotation(_spin)

## A galaxy for the title screen, rolled once per process and kept.
##
## Written into Run, which is legitimate rather than a shortcut: RunState seeds
## Run.galaxy at _ready specifically so screens can draw before a run exists, and
## both ways out of this screen overwrite it — NEW RUN through start_new_run(),
## CONTINUE through SaveGame. Run.map and Run.hull stay untouched, so no save is
## written and the HUD stays hidden.
##
## Static so that coming back to the title screen does not roll a different
## galaxy and throw away the sky cache to build the same thing again.
static var _sky_kind: int = -1
static var _sky_seed: int = 0
static var _sky_params: Dictionary = {}

func _roll_sky_galaxy() -> void:
	if _sky_kind < 0:
		_sky_kind = randi() % GalaxyGen.count()
		_sky_seed = randi()
		# Its own generator, off the global one. The title screen is decoration:
		# it must not draw from a run's streams — a galaxy drawn behind a menu
		# would otherwise move the galaxy the player is about to fly into.
		# Run.galaxy_seed is written below for the same reason it always was,
		# and start_new_run() overwrites it before anything reads it as a seed.
		var r := RandomNumberGenerator.new()
		r.seed = _sky_seed
		_sky_params = GalaxyGen.roll(_sky_kind, r)
	Run.galaxy_kind = _sky_kind
	# Duplicated on the way out: the chart reads Run.galaxy freely and a shared
	# reference would let it edit the copy every later launcher visit rebuilds
	# from.
	Run.galaxy = _sky_params.duplicate(true)
	Run.galaxy_seed = _sky_seed

## Where the ship is and how it is doing — enough to recognise the run without
## loading it.
func _save_line(s: Dictionary) -> String:
	return "%s — %s, danger %d · %d/%d hull · %d jumps" % [
		str(s.galaxy), str(s.system), int(s.danger),
		int(s.hp), int(s.max_hp), int(s.jumps)]

## Settings open as a child of this screen rather than of Main. Main's copy is
## reached through the escape menu, which needs a run behind it; this one has to
## work when there is nothing behind it at all.
func _open_settings() -> void:
	if _settings != null:
		return
	_settings = SettingsMenu.new()
	add_child(_settings)
	_settings.setup()
	_settings.closed.connect(func() -> void:
		if _settings != null:
			_settings.queue_free()
			_settings = null)
