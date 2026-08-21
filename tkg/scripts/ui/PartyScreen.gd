class_name PartyScreen
extends Control

## Everyone you are flying with, on one page.
##
## The convoy strip answers "who is in this room", which is the right question
## while something is shooting at you and the wrong one the rest of the time. It
## is also a fixed column with a fixed height: three partners plus separations
## is 362 rows against the 378 the arena leaves, so it was measured for a party
## of four and silently drops everybody past that. Photographed at seven, the
## fourth ship is cut in half by the quiet strip and the last three are not
## drawn at all.
##
## So the strip keeps its job — presence, at a glance, in the room — and this
## takes the one it was never able to do: the whole party, however many that is,
## with the numbers you would actually plan around. It scrolls, so it does not
## care how many there are.
##
## EVERYTHING HERE IS ALREADY ON THE WIRE. A roster slot carries the ship, the
## hull points, the heat, the heat cap and the system that player is in, because
## `netcode.md`'s presence message has carried all five since the convoy strip
## needed them to draw a gauge. Not one new message was added to build this
## page, and that is the test of whether it deserved to exist: a screen that
## needs a new channel is a feature, and a screen assembled out of facts the
## party already agrees on is a view.

## What the page came from, so LEAVE goes back where you were rather than to a
## fixed screen. The HUD reaches this from the sector, the chart and the refit
## page, and landing on the sector from all three would be a navigation bug
## wearing a convenience.
var _back: Callable = Callable()

var _list: VBoxContainer
var _head: Label

## One partner's hull, drawn at its own size. A heavy is 237 across and the
## column has to hold the widest without the narrow ones rattling around in it,
## so the cell is fixed and the ship sits in the middle of it.
const CELL_W := 248
const CELL_H := 104
## Between rows. Wider than the panels inside a row, so the party reads as a
## list of ships rather than as one block of chrome.
const ROW_GAP := 8


func setup(back: Callable = Callable()) -> void:
	_back = back
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	# The roster is the subject, so every message that moves it redraws this.
	# `party_changed` covers somebody joining, leaving, jumping, taking damage
	# or venting — presence is one message and it carries all of them.
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

	# THE PART THE CONVOY STRIP CANNOT DO. A scrolling list has no opinion about
	# how many ships there are, which is the whole reason this page can answer a
	# question a fixed-height column could not.
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


## One ship, and the four numbers you would plan around: how much hull is left,
## how hot they are running, where they are, and whether they are in a fight.
##
## Not a stat dump. `ShipBuild` deliberately carries what is DRAWN rather than
## what is played — no cards, no affixes, no rolled numbers — so those are not
## available to print here and should not be: what another player is holding is
## their business, and `coop-design.md`'s first pillar is that the wallets stay
## separate. What the party shares is exposure, and exposure is exactly these
## four.
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
		# In the party, not yet in a ship. Said out loud rather than drawn as an
		# empty hull with full gauges, which is a lie about a ship that does not
		# exist. Same answer the convoy slot gives.
		col.add_child(UITheme.body("Still choosing a chassis.",
			UITheme.QUOTE, UITheme.FS_SMALL))
		return Widgets.panel_with(Widgets.pad(row))

	col.add_child(UITheme.body("%s · %s" % [
		DB.manufacturer_name(b.hull.manufacturer).to_upper(),
		DB.hull_class(b.hull.manufacturer, b.hull.weight).to_upper()],
		DB.manufacturer_colour(b.hull.manufacturer), UITheme.FS_SMALL))

	col.add_child(_gauge("HULL", BoxGauge.Mode.HULL, b.max_hp, b.hp,
		"%d/%d" % [b.hp, b.max_hp]))
	# Heat as a FRACTION as well as a count, because the count means nothing
	# without the cap it is measured against — a Hairpin caps at 8 and a Furnace
	# Baron at 26, so "9 heat" is a crisis on one ship and a warm afternoon on
	# the other. This is the number `coop-design.md` §6's field is summed from,
	# and reading it off three partners at once is the point of the page.
	col.add_child(_gauge("HEAT", BoxGauge.Mode.HEAT, b.heat_cap, b.heat,
		"%d/%d" % [b.heat, b.heat_cap]))
	col.add_child(UITheme.body(_where(id), UITheme.COLD, UITheme.FS_SMALL))

	return Widgets.panel_with(Widgets.pad(row))


## The hull itself, at its own size, in a cell wide enough for the widest.
##
## `follow_peer` for a partner and nothing for yourself: ShipView answers "whose
## ship is this" in one place and a peer id of zero already means the local
## ship, so your own row costs no special case.
func _portrait(id: int, b: ShipBuild) -> Control:
	var box := Control.new()
	box.clip_contents = true
	# A ship nobody has picked yet reserves NOTHING. Holding the cell open would
	# give the row its full height for a hull that does not exist, which draws a
	# hundred empty rows of panel above the one sentence that explains why — and
	# in a party still on the chassis select that is every row on the page.
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


## Where they are, by the name of the place rather than by its index.
##
## `where_is` returns -1 for somebody who has not reported a position, which is
## a real answer and not an error: a player on the chassis select has a galaxy
## and no place in it yet.
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

