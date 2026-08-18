class_name EnemySlot
extends Control

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
var _bar: ProgressBar
var _estimate: Label
var _hot: bool = false
## Told by the view when another slot takes the cursor.
var claim: Callable
var _dead: bool = false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	art = EnemyArt.new()
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(art)

	_name = UITheme.body("", UITheme.THEM, UITheme.FS_SMALL)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_name)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 6)
	_bar.show_percentage = false
	col.add_child(_bar)
	_hp = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hp)
	_estimate = UITheme.body("", UITheme.FLARE, UITheme.FS_SMALL)
	_estimate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_estimate)

	mouse_entered.connect(func() -> void: hovered.emit(index, true))
	mouse_exited.connect(func() -> void: hovered.emit(index, false))

func bind(i: int, e, telegraphed: bool) -> void:
	index = i
	_dead = e.hp <= 0
	art.set_enemy(e, telegraphed)
	art.modulate = Color(0.4, 0.4, 0.45) if _dead else Color.WHITE
	_name.text = e.template.name.to_upper()
	_name.add_theme_color_override("font_color",
		Color("#4a5c72") if _dead else UITheme.THEM)
	_bar.max_value = e.max_hp
	_bar.value = e.hp
	_hp.text = "WRECKED" if _dead else "%d / %d" % [e.hp, e.max_hp]
	queue_redraw()

func show_estimate(text: String) -> void:
	_estimate.text = text

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
	if ok and claim.is_valid():
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
	var n := 10.0
	var w := size.x
	var h := size.y
	for corner in [
			[Vector2(0, 0), Vector2(1, 1)],
			[Vector2(w, 0), Vector2(-1, 1)],
			[Vector2(0, h), Vector2(1, -1)],
			[Vector2(w, h), Vector2(-1, -1)]]:
		var o: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_rect(Rect2(o + Vector2(0, -1 if d.y < 0 else 0), Vector2(n * d.x, 1)), c, true)
		draw_rect(Rect2(o + Vector2(-1 if d.x < 0 else 0, 0), Vector2(1, n * d.y)), c, true)
