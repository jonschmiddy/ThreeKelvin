class_name YardBand
extends Control

## The front door's info band, straight on the floor under the ships (Jon's
## band B1, Nov 10: no panel behind it): the facts, a tie line up to the
## ship's stand, and LAUNCH, a big amber key, shown once a ship is picked.
## Why: docs/why/ChassisSelect.md#banner-yard

signal launch
signal tier_picked(t: int)

## The band's box and the key's, in game pixels (the mockup's BAND and KEY).
const BAND := Rect2i(40, 404, 880, 122)
## Jon's L-A plate (Nov 11): 139 x 35 with its 2 px lip and shadow under it.
const KEY := Rect2i(762, 446, 139, 37)
## The developer's grade chips, where the old key's foot left room.
const CHIPS_AT := Vector2i(744, 508)
## The left column, the attribute column and the hardpoint column.
const COL_L := 58
const COL_A := 236
const COL_H := 528
const ROW0 := 416
## The attribute column's width (`HullNumberTest` holds it).
const SIDE_W := 264
const MINT := Color8(120, 230, 190)
const MINT_DIM := Color8(60, 130, 110)
const ICE := Color8(217, 225, 236)
const COLD := Color8(142, 155, 176)
const REST := Color8(120, 140, 150)
const LOCK_INK := Color8(195, 210, 226)
const LOCK_DIM := Color8(107, 125, 148)
## The hardpoints, in the hull picker's order.
const SLOTS := [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]

var key: LaunchKey
var block: AttrBlock = null
var tie: Vector2 = Vector2.ZERO
var _words: Control
var _tiers: Array[Button] = []
## LAUNCH (and the developer's grade chips) are up: hidden until a ship is picked.
var armed: bool = false
var _arm_tw: Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(960, 540)


func setup(dev: bool, tier: int) -> void:
	_words = Control.new()
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words.size = size
	add_child(_words)
	key = LaunchKey.new()
	key.position = Vector2(KEY.position)
	key.size = Vector2(KEY.size)
	key.pressed.connect(func() -> void: launch.emit())
	key.visible = false
	add_child(key)
	if dev:
		_tier_chips(tier)
	show_rest()


## LAUNCH and the grade chips appear in place once a ship is picked (Jon, Nov 11:
## "weird" before one is); faded, never slid, as they are things to click.
## Why: docs/why/ChassisSelect.md#launch-on-pick
func arm(on: bool) -> void:
	if on == armed:
		return
	armed = on
	var keys: Array[Control] = [key]
	keys.append_array(_tiers)
	if _arm_tw != null and _arm_tw.is_valid():
		_arm_tw.kill()
	var fade := on and Router.animating()
	for c in keys:
		c.visible = on
		c.self_modulate.a = 0.0 if fade else 1.0
	if fade:
		_arm_tw = create_tween().set_parallel(true)
		for c in keys:
			_arm_tw.tween_property(c, ^"self_modulate:a", 1.0, 0.18)


## Developer mode only: the condition grade to launch on, under the key. A
## real run always starts at C, as a graded frame is cut out of a wreck.
func _tier_chips(tier: int) -> void:
	for t in HullData.TIER_NAMES.size():
		var b := Widgets.button(String(HullData.TIER_NAMES[t]), func() -> void: tier_picked.emit(t))
		b.custom_minimum_size = Vector2(22, 20)
		b.position = Vector2(CHIPS_AT.x + t * 28, CHIPS_AT.y)
		b.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
		b.tooltip_text = Widgets.tip("%s tier\n%s" % [HullData.TIER_NAMES[t], ChassisSelect.TIER_BLURB[t]])
		b.visible = false
		_tiers.append(b)
		add_child(b)
	mark_tier(tier)


func mark_tier(tier: int) -> void:
	for t in _tiers.size():
		_tiers[t].modulate = Color(1, 1, 1, 1) if t == tier else Color(0.7, 0.75, 0.85, 0.7)


func _clear() -> void:
	Widgets.clear(_words)
	block = null
	tie = Vector2.ZERO
	queue_redraw()


## Nothing picked: the one instruction, large, and the quiet line under it.
func show_rest() -> void:
	_clear()
	# (centred where it was under the old key: the plate's box test measured it there)
	var cx := (BAND.position.x + CHIPS_AT.x) / 2
	_centred("SELECT A SHIP", UITheme.FS_HEAD, cx, (BAND.position.y + BAND.end.y) / 2 - 8, REST)
	_centred("POINT AT A SHIP TO SEE IT.", UITheme.FS_SMALL, cx, (BAND.position.y + BAND.end.y) / 2 + 16, COLD)
	key.set_on(false)


## The ship on the stands, read off the live refit (`Run`), so the block and
## the rows cannot disagree with what launches. `chosen` is the picked ship;
## another says what a click does.
func show_ship(m: ManufacturerData, chosen: bool, at: Vector2, launchable: bool) -> void:
	_clear()
	tie = at
	if YardInfoTrial.opt() != "":
		YardInfoTrial.band_ship(self, m, chosen)
	else:
		_word(Run.hull.name.to_upper(), UITheme.FS_HEAD, COL_L, ROW0, MINT)
		_word(m.name.to_upper(), UITheme.FS_SMALL, COL_L, ROW0 + 24, COLD)
		var weight := _word("%s HULL" % HullData.weight_name(Run.hull.weight).to_upper(), UITheme.FS_SMALL, COL_L, ROW0 + 36, COLD)
		weight.mouse_filter = Control.MOUSE_FILTER_PASS
		weight.tooltip_text = Widgets.tip("%s\n%s" % [HullData.weight_name(Run.hull.weight),
			ChassisSelect.WEIGHT_BLURB[int(Run.hull.weight)]])
		if not chosen:
			_word("CLICK TO MAKE IT YOURS", UITheme.FS_SMALL, COL_L, ROW0 + 58, MINT_DIM)
	_word("ATTRIBUTES", UITheme.FS_SMALL, COL_A, ROW0 - 4, COLD)
	var col := Control.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.position = Vector2(COL_A, ROW0 + 7)
	col.size = Vector2(SIDE_W, 90)
	_words.add_child(col)
	block = AttrBlock.new()
	block.setup(Run.attributes(), m.colour, true)
	col.add_child(block)
	if YardInfoTrial.opt() == "B1":
		YardInfoTrial.fitted_column(self, COL_H, ROW0)
		key.set_on(launchable)
		queue_redraw()
		return
	_word("HARDPOINTS", UITheme.FS_SMALL, COL_H, ROW0 - 4, COLD)
	for i in SLOTS.size():
		var s: ModuleData.Slot = SLOTS[i]
		var row := _word("%d %s" % [Run.slots_for(s), ModuleData.slot_name(s).to_upper()],
			UITheme.FS_SMALL, COL_H, ROW0 + 8 + i * 11, ICE)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.tooltip_text = Widgets.tip(str(ChassisSelect.MOUNT_TIP[ModuleData.slot_name(s)]))
	_word("HAND", UITheme.FS_SMALL, COL_H, ROW0 + 46, COLD)
	var hand := _word("%d CARDS A TURN" % Run.hand_size(), UITheme.FS_SMALL, COL_H + 34, ROW0 + 46, ICE)
	hand.mouse_filter = Control.MOUSE_FILTER_PASS
	hand.tooltip_text = Widgets.tip(str(ChassisSelect.MOUNT_TIP["hand"]))
	var perk: Dictionary = DB.hull_perks.get(Run.hull.perk_id, {})
	if not perk.is_empty():
		_word(String(perk.name).to_upper(), UITheme.FS_SMALL, COL_H, ROW0 + 64, COLD)
		_word(String(perk.text).to_upper().trim_suffix("."), UITheme.FS_SMALL, COL_H, ROW0 + 76, ICE)
	key.set_on(launchable)
	queue_redraw()


## A locked manufacturer's set: ??? and the game's own lock line.
func show_locked(m: StringName, at: Vector2) -> void:
	_clear()
	tie = at
	_word("???", UITheme.FS_HEAD, COL_L, ROW0, MINT)
	_word("LOCKED MANUFACTURER", UITheme.FS_SMALL, COL_L, ROW0 + 24, COLD)
	_word(Unlocks.lock_line(m).to_upper(), UITheme.FS_SMALL, COL_A, ROW0 + 8, LOCK_INK)
	_word("ITS SHIPS WAIT UNDER THEIR TARPS UNTIL THEN.", UITheme.FS_SMALL, COL_A, ROW0 + 24, LOCK_DIM)
	key.set_on(false)
	queue_redraw()


## Is `p` (global) on a band word that carries a tooltip? A click there is not "away".
func on_word(p: Vector2) -> bool:
	for c in _words.find_children("*", "Label", true, false):
		var l := c as Label
		if l.mouse_filter != Control.MOUSE_FILTER_IGNORE and l.is_visible_in_tree() and l.get_global_rect().has_point(p):
			return true
	return false


func _word(s: String, px: int, x: int, y: int, col: Color) -> Label:
	var l := UITheme.body(s, col, px)
	l.position = Vector2(x, y)
	_words.add_child(l)
	return l


func _centred(s: String, px: int, cx: int, y: int, col: Color) -> Label:
	var l := UITheme.body(s, col, px)
	var w := UITheme.pixel_font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	l.position = Vector2(floorf(cx - w / 2.0), y)
	_words.add_child(l)
	return l


## The tie line: from the band's top edge up to the ship's stand.
func _draw() -> void:
	if tie == Vector2.ZERO:
		return
	var y0 := float(BAND.position.y)
	draw_rect(Rect2(tie.x, tie.y, 1, y0 - tie.y), MINT, true)
	draw_rect(Rect2(tie.x - 1, tie.y - 1, 3, 3), MINT, true)
	draw_rect(Rect2(tie.x - 2, y0 - 1, 5, 3), MINT, true)


## THE KEY: a Button, so the hints and the harnesses find LAUNCH by name, drawn
## as Jon's L-A "Plate" (Nov 11). Silent: launching is the start of the game,
## not a UI click (Jon).
## Why: docs/why/ChassisSelect.md#launch-plate
class LaunchKey extends Button:
	const AMBER := Color8(240, 160, 67)
	## The plate's box from its corner; the lip and its contact shadow hang below it.
	const PLATE_W := 139
	const PLATE_H := 35
	const TRACK := 3
	const GLOW := Color8(255, 170, 70)
	var on: bool = false

	func _init() -> void:
		text = "LAUNCH"
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, UITheme.empty())
		for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color",
				"font_focus_color", "font_hover_pressed_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))
		add_theme_font_size_override("font_size", UITheme.FS_HEAD)
		mouse_entered.connect(func() -> void:
			if on:
				Audio.hover()
			queue_redraw())
		mouse_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)
		gui_input.connect(func(e: InputEvent) -> void:
			var mb := e as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and disabled:
				Audio.denied())

	func set_on(v: bool) -> void:
		on = v
		disabled = not v
		queue_redraw()

	## The mockup's four states: ready, hover, pressed, locked.
	func state() -> StringName:
		if not on:
			return &"locked"
		if is_pressed():
			return &"pressed"
		return &"hover" if is_hovered() else &"ready"

	## A pixel box by its inclusive corners, as the mockup's PIL drew it.
	func _px(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
		if x1 >= x0 and y1 >= y0:
			draw_rect(Rect2(x0, y0, x1 - x0 + 1, y1 - y0 + 1), c, true)

	func _chamfer(x0: int, y0: int, x1: int, y1: int, c: Color, ch: int) -> void:
		_px(x0 + ch, y0, x1 - ch, y1, c)
		_px(x0, y0 + ch, x1, y1 - ch, c)

	func _draw() -> void:
		var st := state()
		var x1 := PLATE_W - 1
		var y1 := PLATE_H - 1
		var fill := AMBER
		var hi := Color8(255, 212, 140)
		var lo := Color8(184, 110, 36)
		var rim := Color8(30, 16, 6)
		var ink := Color8(34, 20, 6)
		var lip := Color8(132, 76, 22)
		match st:
			&"locked":
				fill = Color8(24, 34, 36)
				hi = Color8(42, 56, 58)
				lo = Color8(14, 22, 24)
				rim = Color8(6, 10, 11)
				ink = Color8(70, 86, 90)
				lip = Color8(10, 16, 17)
			&"hover":
				fill = Color8(252, 180, 86)
				hi = Color8(255, 232, 176)
			&"pressed":
				fill = Color8(226, 146, 56)
				hi = Color8(186, 112, 36)
		var pressed := st == &"pressed"
		var dn := 2 if pressed else 0
		if st == &"hover":
			_glow(x1, y1 + 2)
		_px(1, y1 + 3, x1 + 1, y1 + 4, Color(0, 0, 0, 120.0 / 255.0))
		_chamfer(0, dn, x1, y1 + 2, rim, 2)
		if not pressed:
			_px(2, y1 - 1, x1 - 2, y1 + 1, lip)
		# the face: over the lip when sunk, above it at rest
		var f0 := 1
		var f1 := 1 + dn
		var f2 := x1 - 1
		var f3 := y1 + 1 if pressed else y1 - 3
		_chamfer(f0, f1, f2, f3, fill, 1)
		_px(f0 + 1, f1, f2 - 1, f1, hi)
		_px(f0, f1 + 1, f0, f3 - 1, lo if pressed else hi)
		_px(f0 + 1, f3, f2 - 1, f3, hi if pressed else lo)
		_px(f2, f1 + 1, f2, f3 - 1, lo)
		var font := UITheme.pixel_font()
		var fs := UITheme.FS_HEAD
		var tw := TRACK * (text.length() - 1)
		for ch in text:
			tw += int(font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var x := float((f0 + f2 + 1) / 2 - tw / 2)
		var base := float((f1 + f3 + 1) / 2 - 12) + font.get_ascent(fs)
		for ch in text:
			draw_string(font, Vector2(x, base), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
			x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + TRACK

	## Light as light: amber in steps round the plate, the outermost dithered.
	func _glow(x1: int, y1: int) -> void:
		for d in range(1, 7):
			var a := 0.42 if d <= 2 else (0.2 if d <= 4 else 0.1)
			var c := Color(GLOW, a)
			if d <= 4:
				_px(-d + 1, -d, x1 + d - 1, -d, c)
				_px(-d + 1, y1 + d, x1 + d - 1, y1 + d, c)
				_px(-d, -d + 1, -d, y1 + d - 1, c)
				_px(x1 + d, -d + 1, x1 + d, y1 + d - 1, c)
				continue
			for xx in range(-d + 1, x1 + d):
				if (xx + d) % 2 == 0:
					_px(xx, -d, xx, -d, c)
					_px(xx, y1 + d, xx, y1 + d, c)
			for y in range(-d + 1, y1 + d):
				if (y + d) % 2 == 0:
					_px(-d, y, -d, y, c)
					_px(x1 + d, y, x1 + d, y, c)
