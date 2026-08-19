class_name ChassisSelect
extends Control

## Which ship you fly out in: a manufacturer, then a weight class.
##
## The first screen of a run, and the first time the game asks you for anything.
## It exists because hulls now have makers: a chassis sets four of your six
## attributes, decides which cards your starting modules grant, and counts as
## one toward its own set bonus.
##
## TWO AXES, and they are genuinely different questions. The manufacturer is
## who you are — which cards, which set bonus, which attribute signature. The
## weight class is how much ship — hull, hardpoints, hand size, evasion. Every
## maker builds all three, so picking Redline does not force you into a paper
## hull; it means a Redline heavy is still the fastest heavy in the game.
##
## Selecting REALLY REFITS THE SHIP rather than previewing it — Run.fit_chassis()
## runs on every click — so the attribute block is reading the live ship, not a
## parallel calculation of what the ship would be. There is no second
## implementation to drift.

signal launched

const WEIGHTS := [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]
const PREVIEW_H := 74

var _sel: int = 0
var _weight: HullData.Weight = HullData.Weight.MEDIUM
var _list: VBoxContainer
var _detail: VBoxContainer
var _rows: Array[Button] = []

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_select(0)

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 5)
	add_child(root)

	root.add_child(UITheme.header("CHOOSE A CHASSIS"))

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 5)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	# --- left: who built it. Narrow, because seven short words need no more.
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.custom_minimum_size = Vector2(126, 0)
	for i in DB.STARTABLE.size():
		var r := _maker_row(i)
		_rows.append(r)
		_list.add_child(r)
	split.add_child(Widgets.panel_with(_list))

	# --- right: how much of it
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 5)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wrap := Widgets.panel_with(_detail)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(wrap)

## One manufacturer. Emblem and name only — the hull's name belongs beside the
## hull it names, and there are three of those now, so printing one here would
## have been printing whichever weight happened to be selected.
func _maker_row(i: int) -> Button:
	var man: StringName = DB.STARTABLE[i]
	var m: ManufacturerData = DB.manufacturers[man]

	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = Vector2(0, 34)
	btn.pressed.connect(_select.bind(i))
	btn.tooltip_text = "%s\n%s" % [m.name, m.identity]
	# Hover fills with the maker's own colour rather than a neutral grey. Seven
	# rows that highlight identically make you read the label to know what you
	# are pointing at; seven that light up in their own colour do not.
	btn.add_theme_stylebox_override("normal", UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 0, 4))
	btn.add_theme_stylebox_override("hover",
		UITheme.flat(m.field.lerp(m.colour, 0.25), m.colour, 0, 0, 4))
	btn.add_theme_stylebox_override("pressed",
		UITheme.flat(m.field.lerp(m.colour, 0.25), m.colour, 0, 0, 4))
	btn.add_theme_stylebox_override("focus", UITheme.empty())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 5
	row.offset_right = -5

	var badge := Badge.new()
	badge.man = man
	badge.mark = m.colour
	badge.field = m.field
	badge.scale_px = 2.0
	row.add_child(badge)

	var label := UITheme.body(DB.short_name(m.name).to_upper(), m.colour, UITheme.FS_HEAD)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	btn.add_child(row)
	return btn

func _select(i: int) -> void:
	_sel = i
	_refit()
	for j in _rows.size():
		_rows[j].modulate = Color(1, 1, 1, 1.0 if j == i else 0.5)
	_build_detail()

func _pick_weight(w: HullData.Weight) -> void:
	_weight = w
	_refit()
	_build_detail()

func _refit() -> void:
	Run.fit_chassis(DB.STARTABLE[_sel], _weight)

func _build_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var man: StringName = DB.STARTABLE[_sel]
	var m: ManufacturerData = DB.manufacturers[man]

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.add_child(UITheme.body(m.name.to_upper(), m.colour, UITheme.FS_SMALL))
	name_row.add_child(UITheme.body('"%s"' % m.tagline, UITheme.QUOTE, UITheme.FS_SMALL))
	_detail.add_child(name_row)

	# The three weights, each showing the ship it actually builds.
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 6)
	for w in WEIGHTS:
		cards.add_child(_weight_card(man, w, m))
	_detail.add_child(cards)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(cols)

	var attrs := VBoxContainer.new()
	attrs.add_theme_constant_override("separation", 3)
	attrs.add_child(UITheme.body("ATTRIBUTES", UITheme.COLD, UITheme.FS_SMALL))
	var block := AttrBlock.new()
	block.setup(Run.attributes(), m.colour)
	attrs.add_child(block)
	cols.add_child(attrs)

	var kit := VBoxContainer.new()
	kit.add_theme_constant_override("separation", 2)
	kit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kit.add_child(UITheme.body("YOU LAUNCH WITH", UITheme.COLD, UITheme.FS_SMALL))
	for mod in Run.installed:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 5)
		line.add_child(UITheme.body(
			ModuleData.slot_name(mod.slot).to_upper(), UITheme.COLD, UITheme.FS_SMALL))
		line.add_child(UITheme.body(mod.name, UITheme.ICE, UITheme.FS_SMALL))
		kit.add_child(line)
	kit.add_child(UITheme.body(DB.perk_text(Run.hull.perk_id), UITheme.CHILL, UITheme.FS_SMALL))
	# The hull's own contribution to the set it belongs to. This is the line
	# that explains why a chassis is a build decision and not a stat sheet.
	kit.add_child(UITheme.body(
		"%s set: %d — the hull counts as one." % [
			DB.short_name(m.name), Run.manufacturer_count(man)],
		m.colour, UITheme.FS_SMALL))
	cols.add_child(kit)

	var go := Widgets.button("LAUNCH", func() -> void: launched.emit())
	go.custom_minimum_size = Vector2(0, 22)
	_detail.add_child(go)

## One weight class, with the ship drawn rather than described. Three stat lines
## under it, chosen because they are what actually differs: how much you can
## take, how many things you can bolt on, how many cards you hold.
func _weight_card(man: StringName, w: HullData.Weight, m: ManufacturerData) -> Button:
	var h := DB.hull_for(man, w)
	var chosen := w == _weight

	var btn := Button.new()
	btn.flat = true
	btn.pressed.connect(_pick_weight.bind(w))
	btn.custom_minimum_size = Vector2(ShipView.W, 0)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var face := m.colour if chosen else UITheme.LINE
	var bg := m.field.lerp(m.colour, 0.18) if chosen else UITheme.PANEL
	btn.add_theme_stylebox_override("normal", UITheme.flat(bg, face, 0, 0, 4))
	btn.add_theme_stylebox_override("hover",
		UITheme.flat(m.field.lerp(m.colour, 0.25), m.colour, 0, 0, 4))
	btn.add_theme_stylebox_override("pressed", UITheme.flat(bg, m.colour, 0, 0, 4))
	btn.add_theme_stylebox_override("focus", UITheme.empty())

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var view := ShipView.new()
	view.setup_preview(h, PREVIEW_H)
	col.add_child(view)

	var title := UITheme.body(
		"%s · %s" % [HullData.weight_name(w).to_upper(), h.name.to_upper()],
		m.colour if chosen else UITheme.CHILL, UITheme.FS_SMALL)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var facts := UITheme.body(
		"%d hull · %d/%d/%d mounts · %d cards" % [
			h.max_hull, h.weapon_slots, h.system_slots, h.utility_slots, h.hand_size],
		UITheme.COLD, UITheme.FS_SMALL)
	facts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(facts)

	btn.add_child(col)
	btn.custom_minimum_size.y = PREVIEW_H + 24
	btn.tooltip_text = "%s\n%d hull · %d heat cap · %d dissipation\n%d weapon, %d system, %d utility mounts\n%d cards in hand" % [
		h.name, h.max_hull, h.heat_cap, h.dissipation,
		h.weapon_slots, h.system_slots, h.utility_slots, h.hand_size]
	return btn


## A manufacturer's mark on a small dark plate. Nine by nine at 1x, which is the
## size CardView.draw_emblem's offsets are authored for.
class Badge extends Control:
	var man: StringName = &""
	var mark: Color = UITheme.CHILL
	var field: Color = UITheme.PANEL
	var scale_px: float = 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		var s := 13.0 * scale_px
		custom_minimum_size = Vector2(s, s)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var s := 13.0 * scale_px
		draw_rect(Rect2(Vector2.ZERO, Vector2(s, s)), field, true)
		draw_rect(Rect2(Vector2.ZERO, Vector2(s, s)), mark.darkened(0.3), false, 1.0)
		CardView.draw_emblem(self, man, Vector2(s, s) * 0.5, scale_px, mark, field)
