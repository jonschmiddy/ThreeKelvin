class_name EnemySlot
extends Control

## Brace as countable cells, sitting on the hull bar.
##
## Brace was a small bar with "2 ARMOR" written under it, which is a bar doing
## a number's job and a number doing a bar's. Brace values are small and every
## point is one hit's worth of nothing happening — so what matters is HOW MANY,
## exactly, the same reason heat and energy are cells rather than bars. Read
## them and the label is redundant; the label goes.
class BracePips extends Control:
	const CELL := Vector2(6, 4)
	const GAP := 1
	var value: int = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, CELL.y)

	func set_value(v: int) -> void:
		if v == value:
			return
		value = maxi(0, v)
		queue_redraw()

	func _draw() -> void:
		if value <= 0:
			return
		# Centred over the hull bar below, so the two read as one stack.
		var n: int = mini(value, 14)
		var w: float = n * CELL.x + (n - 1) * GAP
		var x: float = (size.x - w) * 0.5
		for i in n:
			draw_rect(Rect2(Vector2(x + i * (CELL.x + GAP), 0), CELL),
				EnemySlot.ARMOR_COL, true)
		# More than the strip can hold says so rather than lying about the count.
		if value > n:
			draw_rect(Rect2(Vector2(x + w + 2, 1), Vector2(2, CELL.y - 2)),
				EnemySlot.ARMOR_COL, true)

## One enemy in the encounter, and the thing you drop a card onto to target it.
##
## The slot owns the art, the name and the health bar together so a target is a
## single object on screen rather than a sprite here and a readout somewhere
## else. Dropping a card here aims it; hovering shows what it would land.

signal card_dropped(index: int, view: CardView)
signal hovered(index: int, entered: bool)

var index: int = 0
var art: EnemyArt
var _name: Label
var _hp: Label
## Status chips for this enemy, filled by the screen that owns the Combat.
var chips: HBoxContainer
var _intent: Label
var _intent_text: Label
## How wide a ship's readout is, regardless of how much arena it was given.
const BAR_W := 120

var _bar: ProgressBar
var _brace_bar: BracePips
## Steel, so it never reads as a second kind of hull.
const ARMOR_COL := Color("#9fb0c4")
var _hot: bool = false
## Told by the view when another slot takes the cursor.
var claim: Callable
var _dead: bool = false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# One pixel. Everything in this column belongs to the ship in the middle of
	# it — intent above, name and bars below — and a gap wide enough to notice is
	# a gap that makes them look like separate readouts that happen to line up.
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Behind this slot's own _draw. A Control paints itself first and its
	# children after, so the damage number was being drawn and then buried under
	# the ship, the name and the health bar it was meant to sit over.
	col.show_behind_parent = true
	add_child(col)

	# What THIS one is about to do, over its own hull. One strip at the bottom
	# of the screen could only ever name a turn's worth of intent for the whole
	# pack — with two enemies it printed "Lancer: Strafe   Hulk: Ram", which is
	# a sentence you parse rather than a thing you see. Above each ship it is
	# just a label on the thing it describes.
	# The move, then what the move does. The name alone tells you a Lancer is
	# about to Strafe, which is only useful if you already know what a Strafe
	# costs you — and the number underneath is the half you actually plan
	# against.
	_intent = UITheme.body("", UITheme.THEM, UITheme.FS_SMALL)
	_intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_intent)
	col.move_child(_intent, 0)
	_intent_text = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_intent_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_intent_text)
	col.move_child(_intent_text, 1)

	# The column centres itself and the art stops expanding, so name and bars
	# sit directly under the ship instead of being shoved to the floor of a slot
	# that happens to be tall. A health bar half a screen below its ship is a
	# health bar you have to go looking for.
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	art = EnemyArt.new()
	# No custom_minimum_size here. EnemyArt already declares its own native
	# W x H and draws the ship at 1:1 inside it — overriding that with a width
	# of zero let the Control stretch to whatever share of the arena the slot
	# had, which is what the reticle was then framing. Shrink on both axes and
	# the Control is the ship's own box.
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(art)

	_name = UITheme.body("", UITheme.THEM, UITheme.FS_SMALL)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_name)
	# Bars sized to the SHIP, not to the slot.
	#
	# The slot expands to share the arena, so a lone enemy owned the full width
	# and its health bar with it — a seven-hundred-pixel readout for one
	# freighter. A health bar belongs to the thing it measures: read at a
	# glance, its length should say how much is left, not how much room the
	# layout had. Centred in a fixed BAR_W so two enemies read the same as one.
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 1)
	bars.custom_minimum_size = Vector2(BAR_W, 0)
	bars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bars)

	# Brace ON TOP, hull beneath — the order damage goes through them. Brace is
	# a second pool that has to be chewed away before the first one moves, so it
	# gets a bar rather than a chip: that is what a second bar says and what a
	# word and a number do not.
	_brace_bar = BracePips.new()
	_brace_bar.custom_minimum_size = Vector2(BAR_W, BracePips.CELL.y)
	_brace_bar.visible = false
	bars.add_child(_brace_bar)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(BAR_W, 6)
	_bar.show_percentage = false
	bars.add_child(_bar)
	# Both numbers on one line, each in the colour of the bar it belongs to —
	# so the pair reads as two pools rather than as one stat with a prefix.
	_hp = UITheme.body("", UITheme.GOOD, UITheme.FS_SMALL)
	_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hp)

	# Whatever this one is carrying — block, a charge, a debuff — under its own
	# hull. In a pack, a chip row at the bottom of the screen has to name which
	# ship it belongs to before it can say anything; here the position says it.
	chips = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 3)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(chips)

	mouse_entered.connect(func() -> void: hovered.emit(index, true))
	mouse_exited.connect(func() -> void: hovered.emit(index, false))

func bind(i: int, e, telegraphed: bool) -> void:
	index = i
	_dead = e.hp <= 0
	art.set_enemy(e, telegraphed)
	art.modulate = Color(0.4, 0.4, 0.45) if _dead else Color.WHITE
	_intent.text = "" if _dead or e.intent == null else e.intent.name.to_upper()
	_intent.visible = _intent.text != ""
	_intent_text.text = "" if _dead or e.intent == null else e.intent.text
	_intent_text.visible = _intent_text.text != ""
	_name.text = e.template.name.to_upper()
	_name.add_theme_color_override("font_color",
		Color("#4a5c72") if _dead else UITheme.THEM)
	_bar.max_value = e.max_hp
	_bar.value = e.hp
	_brace_bar.visible = not _dead and e.brace > 0
	_brace_bar.set_value(e.brace)
	_hp.text = "WRECKED" if _dead else "%d / %d" % [e.hp, e.max_hp]
	_hp.add_theme_color_override("font_color",
		Color("#4a5c72") if _dead else UITheme.GOOD)
	queue_redraw()

## What this card would do here, asked at drop-test time.
##
## Returns the string to paint over the target. Set by EncounterView, which gets
## it from the screen that owns the Combat — the slot knows the card and the
## target, and nothing else, which is exactly as much as it should.
var preview: Callable
var _drag_text: String = ""

## Godot asks this continuously while a drag hovers, which doubles as the
## "is this a legal target" highlight without any extra plumbing.

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("card")):
		return false
	var c: CardData = data["card"]
	# Brace does nothing to a Rustjaw. Refuse it here rather than accepting the
	# drop and quietly resolving it on yourself — the card returns to hand.
	var aimable: bool = c.damage > 0 or c.damage_equals_heat or c.evoke > 0
	var ok: bool = aimable and not _dead
	if ok != _hot:
		set_hot(ok)
	if ok:
		var t: String = "" if not preview.is_valid() else String(preview.call(c, index))
		if t != _drag_text:
			_drag_text = t
			queue_redraw()
		if claim.is_valid():
			claim.call(self)
	return ok

func set_hot(v: bool) -> void:
	if _hot == v:
		return
	_hot = v
	queue_redraw()

func _drop_data(_pos: Vector2, data: Variant) -> void:
	_hot = false
	queue_redraw()
	card_dropped.emit(index, data.get("view"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _hot:
		_hot = false
		queue_redraw()

func _draw() -> void:
	if not _hot:
		return
	# Corner brackets rather than a filled panel: a full wash buries the sprite
	# you are aiming at, which is the one thing you need to still see.
	var c := UITheme.FLARE
	var n := 7.0
	# Simply the art's rect: EnemyArt now sizes itself to the hull, so its box
	# and the ship are the same thing and the brackets need no correction.
	var pad := 2.0
	var r := Rect2(art.position - Vector2(pad, pad), art.size + Vector2(pad, pad) * 2.0)
	var x0 := r.position.x
	var y0 := r.position.y
	var w := r.end.x
	var h := r.end.y
	for corner in [
			[Vector2(x0, y0), Vector2(1, 1)],
			[Vector2(w, y0), Vector2(-1, 1)],
			[Vector2(x0, h), Vector2(1, -1)],
			[Vector2(w, h), Vector2(-1, -1)]]:
		var o: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_rect(Rect2(o + Vector2(0, -1 if d.y < 0 else 0), Vector2(n * d.x, 1)), c, true)
		draw_rect(Rect2(o + Vector2(-1 if d.x < 0 else 0, 0), Vector2(1, n * d.y)), c, true)

	# The number, over the target, while a card is held above it.
	#
	# It used to live as a small label under the health bar and it read as part
	# of the enemy's own readout — a permanent stat that happened to change.
	# Painted across the target only while you are holding a card over it, it is
	# obviously a QUESTION being answered: this card, this enemy, this much.
	if _hot and _drag_text != "":
		var f := UITheme.pixel_font()
		var fs := UITheme.FS_HEAD
		var tw := f.get_string_size(_drag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2((size.x - tw) * 0.5, size.y * 0.5 + fs * 0.4)
		draw_string(f, at + Vector2(1, 1), _drag_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.75))
		draw_string(f, at, _drag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.FLARE)
