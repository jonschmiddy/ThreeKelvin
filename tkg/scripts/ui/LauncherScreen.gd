class_name LauncherScreen
extends Control

## Works with no run loaded, so nothing may read ship state; the HUD is hidden for it.
## Why: docs/why/LauncherScreen.md#title-screen

## Belt and braces: the first paint of 48k rects is the longest frame here and must not move.
## Why: docs/why/LauncherScreen.md#sky-warmup
const WARMUP_FRAMES := 4

## Turns once every five minutes so the arms visibly wheel behind the menu (Jon, Oct 6).
## Why: docs/why/LauncherScreen.md#galaxy-turn
const TITLE_TURN := ChartSky.TURN_MINUTES / 5.0

## Just over one, so outer arms run off the edges; no route to plan, so compose it.
const SKY_FILL := 1.12
## Silkscreen is an 8px grid, so only integer multiples stay crisp; 44 would render soft.
const TITLE_SIZE := 48
## One size for everything that is not the title, so the corner reads as two
## things rather than four.
const MENU_SIZE := UITheme.FS_HEAD

## Left bearing scales with type size, so small text sits 4 px left of the title; derived.
## Why: docs/why/LauncherScreen.md#bearing-fix
const BEARING_FIX := (TITLE_SIZE - MENU_SIZE) / 8

var _settings: SettingsMenu = null
## The dim + panel that FLY TOGETHER, FLIGHT RECORD and CONTINUE open into.
## One at a time, and never at the same time as the settings menu.
var _popup: Control = null
## One shared inset for all popups; wider than tall because every panel is a column.
## Why: docs/why/LauncherScreen.md#popup-inset
const POPUP_INSET_H := 170
const POPUP_INSET_V := 96
## The corner checkbox, kept so it can repaint itself when flipped.
var _dev_box: Button = null
var _sky: StarchartScreen.MapChart = null
## Real size arrives after setup(); rotating before it swept a default-size square across the view.
## Why: docs/why/LauncherScreen.md#sky-fit
var _fitted: bool = false
var _warmup: int = WARMUP_FRAMES
## Frames waited for the sky before the shaders' warm starts (-1: started).
var _warm_wait := 0
const WARM_AFTER := 180
## The margin holding the title and its menu, and the menu inside it, kept so
## the boot can fade up everything but the wordmark (`fade_up_around_title`).
var _holder: Control = null
var _menu_box: Control = null
## The menu's NEW THINGS, kept so its unseen mark can go when the page opens.
var _news: Button = null

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_sky()

	# Title top corner, options bottom, galaxy through the middle; the spacer pushes options down.
	# Why: docs/why/LauncherScreen.md#menu-layout
	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_theme_constant_override("margin_left", 22)
	holder.add_theme_constant_override("margin_top", 14)
	holder.add_theme_constant_override("margin_bottom", 24)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_holder = holder
	# Not built at all where developer mode does not exist: an exported game
	# has no workshop, so it has no switch for one. See DevMode.available.
	if DevMode.available:
		_add_dev_toggle()
	_add_build_stamp()

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

	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	push.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(push)

	# The menu carries the MENU_SIZE indent, so it lines up under the title
	# rather than four pixels left of it. See BEARING_FIX.
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 2)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_box = _indent(menu)
	col.add_child(_menu_box)

	var save := SaveGame.summary()
	if not save.is_empty():
		# Save details on hover, as two lines of grey under a menu item crowd the corner.
		menu.add_child(_option("CONTINUE", _confirm_continue, true))

	# White marks the one option you likely came for; hard-coding CONTINUE would show five greys.
	menu.add_child(_option("NEW RUN", _confirm_new_run, save.is_empty()))
	menu.add_child(_option("FLY TOGETHER", func() -> void:
		var lob := LobbyScreen.new()
		lob.on_leave = _close_popup
		_open_popup(lob)
		lob.setup()))
	menu.add_child(_option("FLIGHT RECORD", func() -> void:
		var hist := HistoryScreen.new()
		_open_popup(hist)
		hist.setup(_close_popup)))
	# The archive was removed: 'cool idea, but not for a procedural game' (Jon, Oct 22).
	# Why: docs/why/LauncherScreen.md#removed-archive
	menu.add_child(_option("SETTINGS", _open_settings))
	# NEW THINGS sits above MESSAGE FROM JON, which stays the line above QUIT (Jon, Nov 5).
	# Why: docs/why/LauncherScreen.md#menu-order
	_news = _option("NEW THINGS", open_new_things)
	_news.add_child(_new_mark())
	menu.add_child(_news)
	# JON'S WELCOME NOTE, again, whenever it is wanted (Jon, Oct 13): the line
	# above QUIT. It opens by itself the first time this screen does (`WelcomePopup`).
	menu.add_child(_option("MESSAGE FROM JON", open_welcome))

	# Red on hover alone: everything else leads somewhere you can come back from.
	var quit := _option("QUIT", func() -> void: GameShell.shut_down(get_tree()))
	quit.add_theme_color_override("font_hover_color", UITheme.LEAVE)
	quit.add_theme_color_override("font_pressed_color", Color("#f08872"))
	menu.add_child(quit)

	# THE FIRST TIME, the welcome note over the title (once per profile).
	if WelcomePopup.due():
		open_welcome(true)


## The wordmark is already on screen, so the rest fades up around it.
func fade_up_around_title() -> void:
	if not Router.animating():
		return
	var parts: Array[Node] = get_children()
	parts.append(_menu_box)
	var tw := create_tween().set_parallel()
	for c in parts:
		if c == _holder or not c is CanvasItem:
			continue
		(c as CanvasItem).modulate.a = 0.0
		tw.tween_property(c, "modulate:a", 1.0, Router.FADE_S) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## In the popup slot so nothing opens over it; first-time wording is START YOUR JOURNEY.
func open_welcome(first: bool = false) -> void:
	if _popup != null or _settings != null:
		return
	var w := WelcomePopup.new()
	w.setup(first)
	add_child(w)
	_popup = w
	w.closed.connect(func() -> void:
		if _popup == w:
			_popup = null)

## The NEW THINGS page (`NewThingsPopup`) in the popup slot, as the welcome
## note. Opening it marks the newest notes seen, so the menu's mark goes.
func open_new_things() -> void:
	if _popup != null or _settings != null:
		return
	var p := NewThingsPopup.new()
	p.setup()
	add_child(p)
	_popup = p
	_paint_new_mark()
	p.closed.connect(func() -> void:
		if _popup == p:
			_popup = null)


## A small unseen square, still, a child of the button so it takes no click.
func _new_mark() -> Control:
	var m := ColorRect.new()
	m.name = "NewMark"
	m.color = UITheme.FLARE
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.anchor_left = 1.0
	m.anchor_right = 1.0
	m.anchor_top = 0.5
	m.anchor_bottom = 0.5
	m.offset_left = 4.0
	m.offset_right = 8.0
	m.offset_top = -2.0
	m.offset_bottom = 2.0
	m.visible = NewThings.unseen()
	return m


func _paint_new_mark() -> void:
	if _news != null and is_instance_valid(_news):
		var m := _news.get_node_or_null("NewMark") as Control
		if m != null:
			m.visible = NewThings.unseen()


## Corner checkbox, not in the menu; it repaints itself only so the galaxy keeps turning.
## Why: docs/why/LauncherScreen.md#dev-toggle
func _input(e: InputEvent) -> void:
	# (every input, from the title's first frame: the shaders' warm keeps clear
	# of a hand that is moving, `ShaderWarm.note_input`)
	ShaderWarm.note_input(e)
	var k := e as InputEventKey
	if k == null:
		return
	if k.keycode not in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	get_viewport().set_input_as_handled()


## Shows which build this is, so a screenshot or report says what was played.
func _add_build_stamp() -> void:
	var l := UITheme.body(BuildInfo.stamp(), UITheme.COLD, UITheme.FS_SMALL)
	l.name = "BuildStamp"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_right = -14
	l.offset_bottom = -34 if DevMode.available else -10
	add_child(l)


func _add_dev_toggle() -> void:
	# A named method, not a lambda, so `-- devtest` can find what the switch wires to.
	# Why: docs/why/LauncherScreen.md#dev-toggle
	_dev_box = Widgets.button("", _on_dev_toggle)
	var box := _dev_box
	box.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	box.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_theme_color_override("font_hover_color", UITheme.ICE)
	box.add_theme_color_override("font_pressed_color", UITheme.HOT)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		box.add_theme_stylebox_override(st, UITheme.empty())
	_paint_dev_toggle(box)
	box.tooltip_text = Widgets.tip("Card gallery, the whole star chart, and any hull grade at launch.\nNot the game: do not judge pacing or difficulty with this on.")
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -14
	box.offset_bottom = -10
	add_child(box)

## CONTINUE gets a panel as the only irreversible button: loading deletes the save.
## Why: docs/why/LauncherScreen.md#continue-prompt
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

## Popups open over the title, keeping the galaxy; prompt width is fixed, height follows content.
## Why: docs/why/LauncherScreen.md#popups
const POPUP_PROMPT_W := 356

func _open_popup(inner: Control, compact: bool = false) -> void:
	if _popup != null or _settings != null:
		return
	# The dim covers the whole picture, as the galaxy past Main's margin showed through undimmed.
	# Why: docs/why/LauncherScreen.md#popups
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_close_popup())
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = NoteCard.DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Widgets.cover_picture(dim)
	shade.add_child(dim)
	add_child(shade)
	_popup = shade

	# A prompt is centred at its size: a ScrollContainer stretched it to the full frame.
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

	# Horizontal scroll is disabled on purpose, so wrapping labels actually wrap.
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

## The corner switch, pressed. The only caller of DevMode.toggle in the game.
func _on_dev_toggle() -> void:
	DevMode.toggle()
	_paint_dev_toggle(_dev_box)

## The box and its colour, for whichever state the flag is in now.
static func _paint_dev_toggle(box: Button) -> void:
	Widgets.paint_toggle(box, "DEVELOPER MODE", DevMode.enabled)

func _close_popup() -> void:
	if _popup == null:
		return
	_popup.queue_free()
	_popup = null

## Nudge a control right by the side-bearing difference. See BEARING_FIX.
func _indent(c: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", BEARING_FIX)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	m.add_child(c)
	return m

## Explicit alignment and SHRINK_BEGIN: in a wide column a stretched label drifts.
## Why: docs/why/LauncherScreen.md#menu-lines
func _line(text: String, colour: Color, size: int) -> Label:
	var l := UITheme.body(text, colour, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return l

## NEW RUN goes straight to the hull pick; only a live run asks first, as starting
## over abandons it (Jon, Nov 9, stripped-down UI 7). The seed is in Settings.
## Why: docs/why/LauncherScreen.md#new-run-prompt
func _confirm_new_run() -> void:
	var save := SaveGame.summary()
	if save.is_empty():
		_start_new_run()
		return
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(UITheme.body("START OVER?", UITheme.ICE, UITheme.FS_HEAD))
	# The abandoned run still goes on the flight record, so this is a cost
	# rather than a deletion: worth saying which.
	col.add_child(UITheme.body(_save_line(save), UITheme.CHILL, UITheme.FS_SMALL))
	col.add_child(UITheme.body(
		"A new run abandons that one. It keeps its place on the flight record.",
		UITheme.COLD, UITheme.FS_SMALL))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	# Silent, like the hull pick's LAUNCH: starting the game is not a UI click.
	row.add_child(Widgets.button("NEW RUN", _start_new_run, false))
	row.add_child(_leave_button("NOT YET", _close_popup))
	col.add_child(row)
	_open_popup(col, true)

## No run to abandon and none ever flown: a first launch.
static func fresh_profile() -> bool:
	return SaveGame.summary().is_empty() and RunHistory.load_all().is_empty()

## The seed for the next new run, typed in Settings on the title; 0 rolls one.
## Used once and cleared, so it never sticks to the run after.
static var next_seed := 0

func _start_new_run() -> void:
	var n := next_seed
	next_seed = 0
	_close_popup()
	Router.new_run(n)


## Red text on the same box says one of a pair is the way out, not the opposite action.
## Why: docs/why/LauncherScreen.md#leave-button
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
	# Grey at rest, white for the primary, warm on hover: three states, three jobs.
	var rest := UITheme.ICE if primary else UITheme.COLD
	b.add_theme_color_override("font_color", rest)
	b.add_theme_color_override("font_hover_color", UITheme.HOT)
	b.add_theme_color_override("font_pressed_color", UITheme.FLARE)
	b.add_theme_color_override("font_focus_color", rest)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, UITheme.empty())
	return b

# ------------------------------------------------------------------------- sky

## Reuses the chart's `MapChart` with icons off, not a second galaxy renderer to maintain.
## Why: docs/why/LauncherScreen.md#title-galaxy
func _make_sky() -> void:
	_roll_sky_galaxy()
	_sky = StarchartScreen.MapChart.new()
	_sky.show_icons = false
	_sky.turn_speed = TITLE_TURN
	_sky.run_galaxy = false
	_sky.keys = false
	# The clip is axis-aligned and tears a rotating child; the sky is oversized, so none is needed.
	# Why: docs/why/LauncherScreen.md#title-galaxy
	_sky.clip_contents = false
	# The live core runs at 30: nothing drags here, so halving it halves the only cost.
	_sky.set_anim_interval(1.0 / 30.0)
	# The buttons are in front and get the click first, but a full-screen Control
	# with STOP would eat every press that lands beside them.
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hidden until sized and framed, as a wrong-size galaxy for a frame is a visible pop.
	_sky.visible = false
	add_child(_sky)
	_fit_sky()

## A square of the screen's diagonal side means no rotation can expose an edge.
## Why: docs/why/LauncherScreen.md#sky-fit
func _fit_sky() -> void:
	if _sky == null or size.x <= 0.0 or size.y <= 0.0:
		return
	# The margin is +24: at +8 the circle cleared the corners by 4 px and rounding exposed an edge.
	# Why: docs/why/LauncherScreen.md#sky-fit
	var side := ceilf(sqrt(size.x * size.x + size.y * size.y)) + 24.0
	var sq := Vector2(side, side)
	_sky.size = sq
	_sky.position = (size - sq) * 0.5
	_sky.pivot_offset = sq * 0.5
	# After the size, because the framing is derived from it — and against the
	# screen rather than the square, which is deliberately larger than the view.
	_sky.frame_to(size, SKY_FILL)
	# Pay for the galaxy here, with nothing on screen and nothing turning,
	# instead of inside the first frame that paints it.
	_sky.warm_sky()
	_fitted = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_sky()

func _process(_delta: float) -> void:
	if _sky == null or not _fitted:
		return
	if not _sky.visible:
		# Shown a frame after fitting, as the layers' rects resolve in the next layout pass.
		_sky.visible = true
		return
	if _warmup > 0:
		_warmup -= 1
		return
	# Warm the sector map's shaders once this sky is up, or after `WARM_AFTER` frames.
	if _warm_wait >= 0:
		_warm_wait += 1
		if _sky.sky_drawn() or _warm_wait > WARM_AFTER:
			_warm_wait = -1
			ShaderWarm.start()
	# The galaxy turns by itself at `TITLE_TURN` times the chart's speed; nothing to do here.

## Written into Run legitimately, and static so returning does not roll a new galaxy.
## Why: docs/why/LauncherScreen.md#title-galaxy
static var _sky_kind: int = -1
static var _sky_seed: int = 0
static var _sky_params: Dictionary = {}
static var _sky_spin: float = 0.0

func _roll_sky_galaxy() -> void:
	if _sky_kind < 0:
		_sky_kind = randi() % GalaxyGen.count()
		_sky_seed = randi()
		# Own generator, so the title's galaxy never moves the one the player flies into.
		var r := RandomNumberGenerator.new()
		r.seed = _sky_seed
		_sky_params = GalaxyGen.roll(_sky_kind, r)
		# Own arm angle too, or arms were drawn where the last run's were.
		_sky_spin = r.randf() * TAU
	Run.galaxy_kind = _sky_kind
	# Duplicated on the way out, so the chart cannot edit the copy rebuilt from.
	Run.galaxy = _sky_params.duplicate(true)
	Run.galaxy_seed = _sky_seed
	Run.galaxy_spin = _sky_spin

## Where the ship is and how it is doing — enough to recognise the run without
## loading it.
func _save_line(s: Dictionary) -> String:
	return "%s — %s, danger %d · %d/%d hull · %d jumps" % [
		str(s.galaxy), str(s.system), int(s.danger),
		int(s.hp), int(s.max_hp), int(s.jumps)]

## Opens as a child of this screen, as Main's copy needs a run behind it.
func _open_settings() -> void:
	if _settings != null:
		return
	_settings = SettingsMenu.new()
	add_child(_settings)
	_settings.setup()
	_settings.closed.connect(func() -> void: close_settings())

## Esc closes the Settings drawer, and only it -- the launcher itself is the
## menu, so Esc has nothing else to do here. True when there was one to close.
func close_settings(sound: bool = true) -> bool:
	if _settings == null:
		return false
	# The drawer is leaving, so it sounds like the drawer leaving -- the escape
	# menu's close, not a UI back (Jon). Guarded on the file like Main's.
	if sound and ResourceLoader.exists(Audio.SFX_PATH % &"menu_close"):
		Audio.play(&"menu_close", 0.03, 120)
	_settings.close()
	_settings = null
	return true
