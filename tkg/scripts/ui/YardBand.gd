class_name YardBand
extends Control

## The front door's info band, straight on the floor under the ships (Jon's
## band B1, Nov 10: no panel behind it): the facts, a tie line up to the
## ship's stand, and LAUNCH, a big amber key, grey until a ship is picked.
## Why: docs/why/ChassisSelect.md#banner-yard

signal launch
signal tier_picked(t: int)

## The band's box and the key's, in game pixels (the mockup's BAND and KEY).
const BAND := Rect2i(40, 404, 880, 122)
const KEY := Rect2i(744, 426, 156, 76)
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
	add_child(key)
	if dev:
		_tier_chips(tier)
	show_rest()


## Developer mode only: the condition grade to launch on, under the key. A
## real run always starts at C, as a graded frame is cut out of a wreck.
func _tier_chips(tier: int) -> void:
	for t in HullData.TIER_NAMES.size():
		var b := Widgets.button(String(HullData.TIER_NAMES[t]), func() -> void: tier_picked.emit(t))
		b.custom_minimum_size = Vector2(22, 20)
		b.position = Vector2(KEY.position.x + t * 28, KEY.end.y + 6)
		b.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
		b.tooltip_text = Widgets.tip("%s tier\n%s" % [HullData.TIER_NAMES[t], ChassisSelect.TIER_BLURB[t]])
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
	var cx := (BAND.position.x + KEY.position.x) / 2
	_centred("SELECT A SHIP", UITheme.FS_HEAD, cx, (BAND.position.y + BAND.end.y) / 2 - 8, REST)
	_centred("POINT AT A SHIP TO SEE IT.", UITheme.FS_SMALL, cx, (BAND.position.y + BAND.end.y) / 2 + 16, COLD)
	key.set_on(false)


## The ship on the stands, read off the live refit (`Run`), so the block and
## the rows cannot disagree with what launches. `chosen` is the picked ship;
## another says what a click does.
func show_ship(m: ManufacturerData, chosen: bool, at: Vector2, launchable: bool) -> void:
	_clear()
	tie = at
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
## as the mockup's amber key cap with its lit top and dark lip; grey and
## disabled until a ship is picked. Silent: launching is the start of the game,
## not a UI click (Jon).
class LaunchKey extends Button:
	const AMBER := Color8(240, 160, 67)
	const TOP := Color8(255, 206, 122)
	const TOP_LINE := Color8(255, 234, 180)
	const LIP := Color8(126, 76, 22)
	const RIM := Color8(255, 190, 100)
	const INK := Color8(24, 16, 8)
	const SHADE := Color8(120, 70, 20)
	const OFF_FILL := Color8(22, 34, 34)
	const OFF_RIM := Color8(44, 58, 58)
	const OFF_INK := Color8(64, 80, 84)
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

	func _draw() -> void:
		var b := Rect2(Vector2.ZERO, size)
		var font := UITheme.pixel_font()
		var px := UITheme.FS_HEAD
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var tx := floorf((size.x - w) / 2.0)
		var ty := floorf(size.y / 2.0 - 8.0 + font.get_ascent(px))
		if not on:
			draw_rect(Rect2(0, 0, size.x, size.y + 4), Color8(8, 26, 22), true)
			draw_rect(b, OFF_FILL, true)
			draw_rect(b, OFF_RIM, false, 1.0)
			draw_string(font, Vector2(tx, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, OFF_INK)
			return
		var down := 2.0 if is_pressed() else 0.0
		var fill := AMBER.lightened(0.12) if is_hovered() else AMBER
		draw_rect(Rect2(0, 4, size.x, size.y), Color8(4, 12, 10), true)
		var cap := Rect2(0, down, size.x, size.y - down)
		draw_rect(cap, fill, true)
		draw_rect(Rect2(0, down, size.x, 6), TOP, true)
		draw_rect(Rect2(0, down, size.x, 1), TOP_LINE, true)
		draw_rect(Rect2(0, size.y - 6, size.x, 6), LIP, true)
		draw_rect(cap.grow(-0.5), RIM, false, 1.0)
		draw_string(font, Vector2(tx + 1, ty + 1 + down), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, SHADE)
		draw_string(font, Vector2(tx, ty + down), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, INK)
