class_name GalleryFilter
extends VBoxContainer

## The filter bar the CARDS and MODULES galleries share.
##
## ONE WIDGET, TWO SCREENS, and the reason is the reason `AttrBlock` is shared:
## the two pages answer the same question about different things, and a filter
## that drifts between them is a filter a player has to learn twice. It is also
## the same set of controls the Yard Manifest carries, so the page a designer
## reads and the screen a player reads sort the same way.
##
## Rows are DATA, not layout. A screen hands over a list of {key, label,
## options} and gets a bar back; the screen never touches a button. That is what
## makes adding a grade or a manufacturer a one-line change in the caller rather than a
## row of hand-placed controls here.

## Emitted whenever any button is pressed, with the whole current selection as
## {key: value}. The whole state and not the delta, because every consumer
## re-filters everything anyway and a delta would make them keep their own copy
## of what this already knows.
signal changed(state: Dictionary)

const ROW_SEP := 4
const SET_SEP := 12
const BTN_H := 15

var _state: Dictionary = {}
var _groups: Dictionary = {}


## `rows` is an Array of Arrays of {key, label, options}, one inner Array per
## visual row. Each option is {value, text}. The FIRST option of each set is the
## one that starts selected, which is why every caller puts "All" first.
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


## WHICH ONE IS ON, drawn rather than left to a toggle group. Godot's ButtonGroup
## wants real toggle buttons and this bar is built from `Widgets.button`, which
## every other control in the game uses — matching the rest of the UI is worth
## more than the six lines this saves.
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


## The two sets both galleries want, built here so they cannot disagree about
## the order or the wording. House order comes from DB.manufacturers, which is
## the only place it is written down.
## A BUTTON IS ONE WORD, and it is the word the manufacturer is CALLED, not the first
## token of its legal name. "The Probate Combine" split on spaces gives "The",
## which is a button that says nothing and sits next to six that say plenty.
##
## Leading articles are dropped first, which is the only rule needed: every
## manufacturer in the game is named <Word> <Word> and one of them wears a "The".
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
