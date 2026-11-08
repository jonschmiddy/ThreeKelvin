class_name GalleryFilter
extends VBoxContainer

## One widget for both galleries, so a filter is learned once; rows are data, not layout.
## Why: docs/why/GalleryFilter.md#shared-filter

## Emits the whole state, not the delta, so consumers keep no copy of their own.
signal changed(state: Dictionary)

const ROW_SEP := 4
const SET_SEP := 12
const BTN_H := 15

var _state: Dictionary = {}
var _groups: Dictionary = {}


## The first option of each set starts selected, so every caller puts All first.
func setup(rows: Array) -> void:
	add_theme_constant_override("separation", ROW_SEP)
	for row in rows:
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", SET_SEP)
		for raw in row:
			var spec: Dictionary = raw
			bar.add_child(_make_set(spec))
		add_child(bar)


func _make_set(spec: Dictionary) -> Control:
	var key: StringName = spec.key
	var set_box := HBoxContainer.new()
	set_box.add_theme_constant_override("separation", 3)
	var label := UITheme.body(String(spec.label).to_upper(), UITheme.COLD,
		UITheme.FS_SMALL)
	label.custom_minimum_size = Vector2(0, BTN_H)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	set_box.add_child(label)

	var buttons: Array[Button] = []
	for i in (spec.options as Array).size():
		var opt: Dictionary = spec.options[i]
		var b := Widgets.button(String(opt.text), func() -> void:
			_pick(key, opt.value))
		b.custom_minimum_size = Vector2(0, BTN_H)
		buttons.append(b)
		set_box.add_child(b)
		if i == 0:
			_state[key] = opt.value
	_groups[key] = {buttons = buttons, values = (spec.options as Array).map(
		func(o: Dictionary) -> Variant: return o.value)}
	_paint(key)
	return set_box


func _pick(key: StringName, value: Variant) -> void:
	_state[key] = value
	_paint(key)
	changed.emit(_state.duplicate())


## Selection is drawn, not a `ButtonGroup`: matching `Widgets.button` beats the six lines saved.
func _paint(key: StringName) -> void:
	var g: Dictionary = _groups[key]
	var buttons: Array = g.buttons
	var values: Array = g.values
	for i in buttons.size():
		var b: Button = buttons[i]
		var on: bool = values[i] == _state[key]
		b.add_theme_color_override("font_color",
			UITheme.VOID if on else UITheme.CHILL)
		var sb := StyleBoxFlat.new()
		sb.bg_color = UITheme.ICE if on else UITheme.VOID
		sb.border_color = UITheme.ICE if on else UITheme.LINE
		sb.set_border_width_all(1)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)


func state() -> Dictionary:
	return _state.duplicate()


## Built here so the galleries agree; a button is the manufacturer's short name, not a split.
## Why: docs/why/GalleryFilter.md#shared-options
static func manufacturer_options() -> Array:
	var out: Array = [{value = &"", text = "All"}]
	for id in DB.manufacturers:
		var name := String(DB.manufacturer_name(id))
		if name.begins_with("The "):
			name = name.substr(4)
		out.append({value = id, text = name.split(" ")[0]})
	out.append({value = &"(unbranded)", text = "Unbranded"})
	return out


static func grade_options() -> Array:
	var out: Array = [{value = -1, text = "All"}]
	for r in ModuleData.Rarity.size():
		out.append({value = r, text = ModuleData.rarity_name(r)})
	return out


static func slot_options() -> Array:
	var out: Array = [{value = -1, text = "All"}]
	for sl in ModuleData.Slot.size():
		out.append({value = sl, text = ModuleData.slot_name(sl)})
	return out
