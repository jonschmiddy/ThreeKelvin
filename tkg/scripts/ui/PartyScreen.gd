class_name PartyScreen
extends Control

## Does what the convoy strip cannot: the whole party, scrolling, from existing wire facts.
## Why: docs/why/PartyScreen.md#party-page

## Remembers where it came from, so LEAVE goes back there, not to a fixed screen.
var _back: Callable = Callable()

var _list: VBoxContainer
var _head: Label

## A fixed cell wide enough for the widest hull (a heavy is 237), the ship centred in it.
const CELL_W := 248
const CELL_H := 104
## Between rows. Wider than the panels inside a row, so the party reads as a
## list of ships rather than as one block of chrome.
const ROW_GAP := 8


func setup(back: Callable = Callable()) -> void:
	_back = back
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	# Presence is one message, so `party_changed` covers join, leave, jump, damage and vent.
	Sig.party_changed.connect(_refresh)
	Sig.party_fight_changed.connect(func(_at: int) -> void: _refresh())
	Sig.map_changed.connect(_refresh)
	_refresh()


func _build() -> void:
	var pad := Widgets.pad(null, 12, 8)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	pad.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(UITheme.header("PARTY"))
	_head = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_head)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	top.add_child(Widgets.button("LEAVE", func() -> void:
		if _back.is_valid():
			_back.call()
		else:
			Router.show_sector()))
	col.add_child(top)
	col.add_child(UITheme.hsep())

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", ROW_GAP)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# A scrolling list has no opinion on how many ships there are.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	col.add_child(scroll)


func _refresh() -> void:
	Widgets.clear(_list)

	if not Net.is_networked():
		_head.text = ""
		_list.add_child(UITheme.body(
			"Flying alone. FLY TOGETHER on the title screen opens a party.",
			UITheme.QUOTE, UITheme.FS_SMALL))
		return

	var slots := Net.slots()
	_head.text = "%d SHIPS" % slots.size()
	for slot in slots:
		_list.add_child(_row(slot))


## Four numbers only: hull, heat, place, fight. What others hold is theirs; wallets stay apart.
## Why: docs/why/PartyScreen.md#party-rows
func _row(slot: Dictionary) -> Control:
	var id := int(slot.id)
	var b: ShipBuild = Net.build_of(id)
	var me := id == Net.local_id()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	row.add_child(_portrait(id, b))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	var who := String(slot.get("name", "")).to_upper()
	if id == 1:
		who += "  (HOST)"
	if me:
		who += "  (YOU)"
	name_row.add_child(UITheme.body(who, UITheme.ICE, UITheme.FS_BODY))
	name_row.add_child(_marks(id, b))
	col.add_child(name_row)

	if b == null:
		# Said out loud, not drawn as an empty hull with full gauges, which would be a lie.
		col.add_child(UITheme.body("Still choosing a chassis.",
			UITheme.QUOTE, UITheme.FS_SMALL))
		return Widgets.panel_with(Widgets.pad(row))

	col.add_child(UITheme.body("%s · %s" % [
		DB.manufacturer_name(b.hull.manufacturer).to_upper(),
		HullData.weight_name(b.hull.weight).to_upper()],
		DB.manufacturer_colour(b.hull.manufacturer), UITheme.FS_SMALL))

	col.add_child(_gauge("HULL", BoxGauge.Mode.HULL, b.max_hp, b.hp,
		"%d/%d" % [b.hp, b.max_hp]))
	# Heat as a fraction too, as a count means nothing without the cap it is measured against.
	col.add_child(_gauge("HEAT", BoxGauge.Mode.HEAT, b.heat_cap, b.heat,
		"%d/%d" % [b.heat, b.heat_cap]))
	col.add_child(UITheme.body(_where(id), UITheme.COLD, UITheme.FS_SMALL))

	return Widgets.panel_with(Widgets.pad(row))


## `follow_peer` for a partner, nothing for yourself: peer id zero already means local.
func _portrait(id: int, b: ShipBuild) -> Control:
	var box := Control.new()
	box.clip_contents = true
	# A ship nobody has picked reserves nothing, or the row keeps a full height for no hull.
	if b == null:
		return box
	box.custom_minimum_size = Vector2(CELL_W, CELL_H)
	var art := ShipView.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if id != Net.local_id():
		art.follow_peer(id)
	art.bob(1, 0.19)
	art.modulate = Color(0.45, 0.45, 0.52) if b.dead else Color.WHITE
	box.add_child(art)
	return box


## LOST, and IN THIS FIGHT. The two states that change what you should do next.
func _marks(id: int, b: ShipBuild) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	if b != null and b.dead:
		row.add_child(Widgets.chip("LOST", UITheme.LEAVE))
		return row
	var at := Net.where_is(id)
	var f := Net.fight_at(at) if at >= 0 else null
	if f != null and not f.over and f.crew.has(id):
		row.add_child(Widgets.chip("IN A FIGHT", UITheme.FLARE))
	elif at >= 0 and at == Run.at and id != Net.local_id():
		# Same system as you, which is what decides whether you can join their
		# fight and whether your signatures sum. See coop-design.md §6.
		row.add_child(Widgets.chip("WITH YOU", UITheme.GOOD))
	return row


## A name, not an index; -1 from `where_is` is a real answer, not an error.
func _where(id: int) -> String:
	var at := Net.where_is(id)
	if at < 0 or at >= Run.map.size():
		return "Not under way yet."
	var n: MapGen.MapNode = Run.map[at]
	return "%s · layer %d · danger %d" % [MapGen.star_name(n), n.layer, n.danger]


func _gauge(label: String, mode: BoxGauge.Mode, cap: int, value: int,
		text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var key := UITheme.body(label, UITheme.COLD, UITheme.FS_SMALL)
	key.custom_minimum_size = Vector2(34, 0)
	row.add_child(key)
	var g := BoxGauge.new()
	g.setup(mode, cap, value)
	row.add_child(g)
	row.add_child(UITheme.body(text, UITheme.CHILL, UITheme.FS_SMALL))
	return row

