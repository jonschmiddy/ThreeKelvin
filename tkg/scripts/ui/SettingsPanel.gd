class_name SettingsPanel
extends VBoxContainer
## Settings, as the contents of a drawer.
##
## IN THE ESCAPE DRAWER, NOT ON TOP OF IT. Settings used to open as a second
## overlay that re-rendered the whole screen over the menu it came from; Jon:
## "can't we have the settings menu just be in the same size side drawer?" So
## this is only the drawer's CONTENTS: PauseMenu swaps it in place of its own,
## and SettingsMenu wraps it in a drawer of its own for the title screen, which
## has no escape menu to borrow.
##
## Built for the drawer's 250 px: every setting is a row that names itself and
## states its current value on the right, with short chips under it, and volume
## is a gauge you click along -- the layer strip's cells -- rather than six
## numbered buttons.
##
## Options show what they will do before you pick them, and the current one is
## marked — a settings screen that makes you toggle blind to find out is worse
## than no settings screen.

signal back_requested

## Discrete steps rather than a slider: the theme has no slider styling, and a
## pixel UI reads a marked step better than a grabber it cannot draw crisply.
## The gauge is these five cells; nothing lit is off.
const VOLUME_STEPS: Array[float] = [0.2, 0.4, 0.6, 0.8, 1.0]

var _body: VBoxContainer
var _scroll: ScrollContainer
## CONTROLS, the key bindings. Last, because it is the longest section and the
## one visited least; `show_keys` scrolls to it.
var keys_page: KeyBindings
## What SAVE MY LOGS last did here (`PlaytestLogs.save_bundle`), for the line under it.
var _last_logs: Dictionary = {}

func _init() -> void:
	add_theme_constant_override("separation", 6)

func build() -> void:
	var tab := PanelContainer.new()
	tab.add_theme_stylebox_override("panel", UITheme.flat(UITheme.EMBER, Color(0, 0, 0, 0), 0, 3, 5))
	tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tab.add_child(UITheme.body("SETTINGS", UITheme.VOID, UITheme.FS_SMALL))
	add_child(tab)
	add_child(UITheme.body("THREE KELVIN", UITheme.ICE, UITheme.FS_HEAD))
	# ONE SCROLLING PAGE. It was tabs for an afternoon -- Jon's call both ways --
	# and scrolling wins because every setting is then one gesture away rather
	# than behind a tab you have to remember the name of. BACK stays pinned
	# below the scroll rather than riding it out of reach.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_scroll = scroll
	# ROOM FOR THE BAR. A ScrollContainer draws its scrollbar over the right
	# edge of its content, so every value on the right -- 1920 x 1080, OFF, the
	# last chip in a row -- sat under it (Jon).
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_right", 10)
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inset)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_child(_body)
	# NO SOUND OF ITS OWN: what leaving Settings sounds like depends on where it
	# is. Inside the escape drawer it is a step back; on the title screen the
	# whole drawer leaves, so it is the drawer closing. The owner plays it.
	var back := DrawerPlate.plate(&"back", "BACK", "SETTINGS ARE KEPT AS YOU GO",
		func() -> void: back_requested.emit())
	back.tone = DrawerPlate.Tone.GOOD
	add_child(back)
	_refresh()

func _refresh() -> void:
	Widgets.clear(_body)
	_body.add_child(_gap(4))
	_page_screen()
	_body.add_child(_gap(8))
	_page_look()
	_body.add_child(_gap(8))
	_page_motion()
	_body.add_child(_gap(8))
	_page_sound()
	_body.add_child(_gap(8))
	_page_playtest()
	_body.add_child(_gap(8))
	_page_keys()

## PLAYTEST: SAVE MY LOGS (`PlaytestLogs`). One zip of this game's logs,
## settings, suspended run and flight record, to the Desktop; then where it went
## and a way to open that folder. Nothing is sent anywhere.
func _page_playtest() -> void:
	_body.add_child(Section.new(&"save", "PLAYTEST"))
	_body.add_child(DrawerPlate.plate(&"save", "SAVE MY LOGS", "ONE ZIP, TO YOUR DESKTOP",
		func() -> void:
			_last_logs = PlaytestLogs.save_bundle()
			if _last_logs.get("ok", false):
				PlaytestLogs.show_in_folder(String(_last_logs.path))
			_refresh()))
	if not _last_logs.is_empty():
		var said := ("Saved to your %s: %s. Drag it into the chat." % [_last_logs.where, String(_last_logs.path).get_file()]) 			if _last_logs.get("ok", false) else String(_last_logs.error)
		var l := UITheme.body(said, UITheme.CHILL, UITheme.FS_SMALL)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(l)
		if _last_logs.get("ok", false):
			var srow := _chips()
			srow.add_child(DrawerPlate.chip_for("SHOW IN FOLDER", false,
				func() -> void: PlaytestLogs.show_in_folder(String(_last_logs.path))))
			_body.add_child(srow)

## CONTROLS: every key a player can move. The rows are their own widget
## (KeyBindings) because a key changing rebuilds only them.
func _page_keys() -> void:
	_body.add_child(Section.new(&"keys", "CONTROLS"))
	keys_page = KeyBindings.new()
	_body.add_child(keys_page)
	# THE MOUSE'S OWN, which are not keys and cannot be moved: listed so they are
	# known (Jon: "You can add this control to the controls settings")
	_body.add_child(_gap(4))
	_body.add_child(UITheme.body("MOUSE (FIXED)", UITheme.CHILL, UITheme.FS_SMALL))
	for line: String in ["SECTOR MAP: RIGHT-CLICK THE SELECTED PLACE TO ZOOM ONTO IT", "RIGHT-CLICK AGAIN, OR ON EMPTY SPACE, TO ZOOM OUT"]:
		var l := UITheme.body(line, UITheme.COLD, UITheme.FS_SMALL)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(l)

## Scroll so CONTROLS is at the top, for `-- settings=controls`; `at_end`
## scrolls to the bottom instead, where RESET ALL is.
func show_keys(at_end: bool = false) -> void:
	if _scroll == null or keys_page == null:
		return
	if at_end:
		_scroll.scroll_vertical = int(_body.size.y)
		return
	# The section head sits just above the rows; aim for it, not the first row.
	var head := keys_page.get_index() - 1
	var target: Control = _body.get_child(head) as Control if head >= 0 else keys_page
	_scroll.scroll_vertical = int(target.position.y)

func _page_screen() -> void:
	_body.add_child(Section.new(&"display", "DISPLAY"))

	var mode_row := _chips()
	for m in [DisplaySettings.Mode.WINDOWED, DisplaySettings.Mode.BORDERLESS,
			DisplaySettings.Mode.FULLSCREEN]:
		var b := DrawerPlate.chip_for(DisplaySettings.mode_name(m), DisplaySettings.mode == m,
			func() -> void:
				DisplaySettings.set_mode(m)
				_refresh())
		b.tooltip_text = Widgets.tip(DisplaySettings.mode_blurb(m))
		mode_row.add_child(b)
	_body.add_child(mode_row)
	var blurb := UITheme.body(DisplaySettings.mode_blurb(DisplaySettings.mode).to_upper(),
		UITheme.COLD, UITheme.FS_SMALL)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(blurb)

	_body.add_child(_gap(2))
	var count := DisplayServer.get_screen_count()
	var here := DisplaySettings.safe_screen()
	var ss := DisplayServer.screen_get_size(here)
	_body.add_child(_line("MONITOR", "%d × %d" % [ss.x, ss.y]))
	if count > 1:
		var srow := _chips()
		for i in count:
			var primary := i == DisplayServer.get_primary_screen()
			var sb := DrawerPlate.chip_for("%d%s" % [i + 1, " *" if primary else ""], here == i,
				func() -> void:
					DisplaySettings.set_screen(i)
					_refresh())
			sb.tooltip_text = Widgets.tip("%s. Move the game to this monitor. * marks your primary."
				% DisplaySettings.screen_label(i))
			srow.add_child(sb)
		_body.add_child(srow)

	_body.add_child(_gap(2))
	var windowed := DisplaySettings.mode == DisplaySettings.Mode.WINDOWED
	var now := DisplaySettings.BASE * DisplaySettings.window_scale
	_body.add_child(_line("WINDOW SIZE",
		"%d × %d" % [now.x, now.y] if windowed else "FILLS THE SCREEN"))
	var top := DisplaySettings.max_window_scale()
	var wrow := _chips()
	for s in range(1, top + 1):
		wrow.add_child(DrawerPlate.chip_for("%dX" % s, windowed and DisplaySettings.window_scale == s,
			func() -> void:
				DisplaySettings.set_scale(s)
				_refresh()))
	_body.add_child(wrow)
	# On a 1080p screen 2x is exactly the screen height, so the only windowed
	# size that keeps its title bar is 1x. Say so rather than hiding the option.
	if top == 1:
		_body.add_child(UITheme.body("LARGER SIZES NEED BORDERLESS", UITheme.QUOTE, UITheme.FS_SMALL))

	_body.add_child(_gap(2))
	# THE FRAME COUNTER, under DISPLAY because that is what it measures.
	var fps := HBoxContainer.new()
	var fk := UITheme.body("FRAME COUNTER", UITheme.COLD, UITheme.FS_SMALL)
	fk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fps.add_child(fk)
	var fchips := _chips()
	fchips.custom_minimum_size = Vector2(96, 0)
	fchips.size_flags_horizontal = Control.SIZE_SHRINK_END
	for on in [true, false]:
		var fb := DrawerPlate.chip_for("ON" if on else "OFF", DisplaySettings.fps_meter == on,
			func() -> void:
				DisplaySettings.set_fps_meter(on)
				_refresh())
		fb.tooltip_text = Widgets.tip(
			"Frames per second, bottom right. Costs nothing and decides nothing. It is for saying \"the chart felt slow\" with a number attached.")
		fchips.add_child(fb)
	fps.add_child(fchips)
	_body.add_child(fps)

func _page_look() -> void:
	_body.add_child(Section.new(&"look", "THE LOOK"))

	# THE RENDERING STYLE, only once there is more than one to pick: a row with a
	# single chip is a control that does nothing (only pressable things look
	# pressable). Built styles only, in DisplaySettings.STYLES' order.
	var styles := DisplaySettings.built_styles()
	if styles.size() > 1:
		_body.add_child(_line("STYLE", DisplaySettings.style_name(DisplaySettings.render_style)))
		var strow := _chips()
		for st in styles:
			var sb := DrawerPlate.chip_for(DisplaySettings.style_name(st),
				DisplaySettings.render_style == st,
				func() -> void:
					DisplaySettings.set_render_style(st)
					_refresh())
			sb.tooltip_text = Widgets.tip({
				&"legacy": "The look from before: the star chart and sector map as they were, with the new black hole and animations.",
				&"simplified": "The star chart and the sector map, clean and alive: gas streaming along the arms, knots breathing, weather in the nebulae.",
				&"painted": "Every pixel placed by hand: banded light, hue-shifted shadows, dithered gas.",
				&"radiant": "Light through gas: the galaxy and its nebulae as lit volumes. Heavy on the graphics card: made for screenshots. Falls back to SIMPLIFIED if the machine can't keep up.",
			}.get(st, ""))
			strow.add_child(sb)
		_body.add_child(strow)
		_body.add_child(_gap(2))

	# GRAPHICS, beside STYLE because it is the other half of how heavy the sky
	# is: LOW is every style's cheaper path, applied at once and kept.
	var gfx := HBoxContainer.new()
	var gk := UITheme.body("GRAPHICS", UITheme.COLD, UITheme.FS_SMALL)
	gk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gfx.add_child(gk)
	var gchips := _chips()
	gchips.custom_minimum_size = Vector2(96, 0)
	gchips.size_flags_horizontal = Control.SIZE_SHRINK_END
	for low in [false, true]:
		var gb := DrawerPlate.chip_for("LOW" if low else "HIGH", DisplaySettings.graphics_low == low,
			func() -> void:
				DisplaySettings.set_graphics_low(low)
				_refresh())
		gb.tooltip_text = Widgets.tip(
			"A lighter sky in every style, for laptops and integrated graphics. The look stays; the gas moves a little less." if low
			else "The full sky. RADIANT drops to SIMPLIFIED by itself if the machine can't keep up; try LOW first.")
		gchips.add_child(gb)
	gfx.add_child(gchips)
	_body.add_child(gfx)
	_body.add_child(_gap(2))

	_body.add_child(_line("COLORBLINDNESS", DisplaySettings.colour_help_name(DisplaySettings.colour_help)))
	var crow := _chips()
	for i in 4:
		var cb := DrawerPlate.chip_for(["OFF", "R-G", "R-G 2", "B-Y"][i],
			DisplaySettings.colour_help == i,
			func() -> void:
				DisplaySettings.set_colour_help(i)
				_refresh())
		cb.tooltip_text = Widgets.tip([
			"No change.",
			"Red-green (deuteranopia), the commonest kind. The difference a red-green eye cannot see is pushed into brightness and blue, which it can.",
			"Red-green (protanopia), where reds also go dark.",
			"Blue-yellow (tritanopia), the rarest kind."][i])
		crow.add_child(cb)
	_body.add_child(crow)

	_body.add_child(_gap(2))
	_body.add_child(_line("LOOK", DisplaySettings.look_name(DisplaySettings.screen_look)))
	var lrow := _chips()
	for l in [DisplaySettings.Look.FLAT, DisplaySettings.Look.SCANLINES,
			DisplaySettings.Look.CRT_GENTLE, DisplaySettings.Look.CRT,
			DisplaySettings.Look.CRT_ARCADE]:
		var lb := DrawerPlate.chip_for(DisplaySettings.look_name(l),
			DisplaySettings.screen_look == l,
			func() -> void:
				DisplaySettings.set_look(l)
				_refresh())
		lb.tooltip_text = Widgets.tip({
			DisplaySettings.Look.FLAT: "The game as it is drawn.",
			DisplaySettings.Look.SCANLINES: "One soft line per pixel row.",
			DisplaySettings.Look.CRT_GENTLE: "A slight curve, soft lines, a vignette. Meant to be played in.",
			DisplaySettings.Look.CRT: "More of everything, and a glow on bright pixels.",
			DisplaySettings.Look.CRT_ARCADE: "The cabinet: heavy curve and a shadow mask. Hard to read a card through.",
		}[l])
		lrow.add_child(lb)
	_body.add_child(lrow)

	_body.add_child(_gap(2))
	_body.add_child(_row_chips("CONTRAST", ["NORMAL", "HIGH"],
		1 if DisplaySettings.high_contrast else 0,
		func(i: int) -> void:
			DisplaySettings.set_high_contrast(i == 1)
			_refresh()))
	_body.add_child(_row_chips("BRIGHTNESS", ["DARK", "NORMAL", "BRIGHT"],
		DisplaySettings.brightness + 1,
		func(i: int) -> void:
			DisplaySettings.set_brightness(i - 1)
			_refresh()))

func _page_motion() -> void:
	_body.add_child(Section.new(&"motion", "MOTION"))
	_body.add_child(_row_chips("ANIMATION", ["FULL", "REDUCED"],
		1 if DisplaySettings.reduced_motion else 0,
		func(i: int) -> void:
			DisplaySettings.set_reduced_motion(i == 1)
			_refresh()))
	_body.add_child(_row_chips("CLICK TO SKIP JUMP", ["OFF", "ON"],
		1 if DisplaySettings.skip_jump else 0,
		func(i: int) -> void:
			DisplaySettings.set_skip_jump(i == 1)
			_refresh()))
	_body.add_child(_row_chips("SCREEN SHAKE", ["ON", "OFF"],
		0 if DisplaySettings.screen_shake else 1,
		func(i: int) -> void:
			DisplaySettings.set_screen_shake(i == 0)
			_refresh()))
	var caps := [0, 60, 120]
	_body.add_child(_row_chips("FRAME CAP", ["NONE", "60", "120"],
		maxi(caps.find(DisplaySettings.frame_cap), 0),
		func(i: int) -> void:
			DisplaySettings.set_frame_cap(caps[i])
			_refresh()))

func _page_sound() -> void:
	_body.add_child(Section.new(&"audio", "AUDIO"))
	for bus: StringName in [&"Master", &"Music", &"SFX", &"Ambient"]:
		var v: float = Audio.volume_of(bus)
		var label := {&"Master": "MASTER", &"Music": "MUSIC", &"SFX": "EFFECTS",
				&"Ambient": "AMBIENT"}[bus] as String
		_body.add_child(_line(label, "OFF" if v < 0.1 else "%d%%" % roundi(v * 100.0)))
		var gauge := VolumeGauge.new()
		gauge.bus = bus
		gauge.changed.connect(_refresh)
		_body.add_child(gauge)
		_body.add_child(_gap(3))

## A name on the left and its choices on the right, for the settings whose
## options are short enough to sit beside their label.

func _row_chips(key: String, names: Array, picked: int, on_pick: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var k := UITheme.body(key, UITheme.COLD, UITheme.FS_SMALL)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(k)
	var row := _chips()
	row.custom_minimum_size = Vector2(46.0 * names.size(), 0)
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	for i in names.size():
		row.add_child(DrawerPlate.chip_for(String(names[i]), i == picked,
			on_pick.bind(i)))
	h.add_child(row)
	return h

## A setting's name, and what it is set to now, on one line.
func _line(key: String, value: String) -> Control:
	var h := HBoxContainer.new()
	var k := UITheme.body(key, UITheme.COLD, UITheme.FS_SMALL)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	h.add_child(UITheme.body(value, UITheme.ICE, UITheme.FS_SMALL))
	return h

func _chips() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	return r

func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


## A section head: its mark, its name, and a rule to the edge.
class Section extends Control:
	var id: StringName
	var text := ""

	func _init(i: StringName = &"", t: String = "") -> void:
		id = i
		text = t
		custom_minimum_size = Vector2(0, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		DrawerPlate.draw_icon(self, id, Vector2.ZERO, UITheme.FLARE)
		var font := get_theme_font("font", "Label")
		var fs := UITheme.FS_SMALL
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(22, 3 + font.get_ascent(fs)), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.ICE)
		draw_rect(Rect2(22 + tw + 8, 7, size.x - (22 + tw + 8), 1), UITheme.LINE)


## Volume as the layer strip's cells: five, lit to the level, clicked along.
## Hover previews where a click would set it. The empty cell on the left is off.
class VolumeGauge extends Control:
	signal changed
	const CELL_GAP := 2.0
	const OFF_W := 30.0
	var bus: StringName
	var _hover := -2

	func _init() -> void:
		custom_minimum_size = Vector2(0, 12)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_exited.connect(func() -> void:
			_hover = -2
			queue_redraw())

	## -1 is OFF, 0..4 the cells, -2 nothing.
	func _slot_at(x: float) -> int:
		if x < OFF_W:
			return -1
		var w := (size.x - OFF_W - CELL_GAP) / SettingsPanel.VOLUME_STEPS.size()
		return clampi(int((x - OFF_W - CELL_GAP) / w), 0, SettingsPanel.VOLUME_STEPS.size() - 1)

	func _gui_input(e: InputEvent) -> void:
		var mm := e as InputEventMouseMotion
		if mm != null:
			var s := _slot_at(mm.position.x)
			if s != _hover:
				_hover = s
				Audio.hover()
				queue_redraw()
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var slot := _slot_at(mb.position.x)
			var v := 0.0 if slot < 0 else SettingsPanel.VOLUME_STEPS[slot]
			Audio.click()
			Audio.set_volume(bus, v)
			# You should hear what you just picked. Music and the room answer for
			# themselves -- both are already playing while you drag the fader --
			# so only Master and Effects need something to answer with.
			if bus != &"Music" and bus != &"Ambient" and v > 0.0:
				Audio.confirm()
			accept_event()
			changed.emit()

	func _draw() -> void:
		var v: float = Audio.volume_of(bus)
		var lit := -1
		for i in SettingsPanel.VOLUME_STEPS.size():
			if v >= SettingsPanel.VOLUME_STEPS[i] - 0.05:
				lit = i
		var font := get_theme_font("font", "Label")
		var fs := UITheme.FS_SMALL
		# OFF: a small plate, ember when the bus is silent.
		var off_col := UITheme.EMBER if lit < 0 else (UITheme.CHILL if _hover == -1 else UITheme.LINE)
		draw_rect(Rect2(0, 0, OFF_W - CELL_GAP, size.y), off_col, false, 1.0)
		# CENTRED ON THE BOX, both ways, off the font's own metrics: the label was
		# measured but the baseline was guessed, so it sat low and left.
		var tw := font.get_string_size("OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var box := Vector2(OFF_W - CELL_GAP, size.y)
		var base := (box.y + font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(floorf((box.x - tw) * 0.5), floorf(base)),
			"OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.ICE if lit < 0 else UITheme.COLD)
		var n := SettingsPanel.VOLUME_STEPS.size()
		var w := (size.x - OFF_W - CELL_GAP * (n)) / n
		for i in n:
			var r := Rect2(OFF_W + i * (w + CELL_GAP), 0, w, size.y).abs()
			var col := UITheme.LINE
			if i <= lit:
				col = UITheme.EMBER
			if _hover >= 0 and i <= _hover:
				col = UITheme.FLARE if i <= lit else UITheme.CHILL
			draw_rect(Rect2(r.position.floor(), r.size.floor()), col)
