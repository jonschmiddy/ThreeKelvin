class_name ShipScreen
extends Control

## Refit, as a workbench.
##
## The ship and what it IS on the left; the parts and where they go on the
## right. You drag a module from storage onto a hardpoint to fit it, drag it
## back to store it, and drop one onto an occupied mount to swap the two.
##
## There is no melter on this screen. Scrapping a part still exists and still
## pays scrap — it lives on the station and the salvage prompt, where a bid to
## compare it against is also on screen. A drag-to-destroy target sitting next to
## the storage grid made the destructive move the easiest one to reach by
## accident, which is the wrong ergonomics for the only irreversible verb here.
##
## Modules are icons rather than rows. A list of names is a document; a grid of
## icons is an inventory, and this screen's whole job is the second thing —
## comparing what is bolted on against what is in the hold, at a glance, and
## moving one to the other. The rows it replaced could not show you a full
## weapon rack and a full hold at the same time.
##
## Two drop handlers, because there are two destinations asking different
## questions. `_on_mount_drop` asks whether a slot type matches and which PLACE
## on the hull was aimed at; `_on_hold_drop` asks whether a shape fits and at
## which cell. Nothing else in here touches `installed` or `cargo`.

## SUPERSEDED by HoldGrid, which takes its shape from HullData.hold_grid. Kept
## as the record of why four: the measurement below is what set it and it is
## still what the hold is drawn at.
##
## Four across, so the hold reads as rows of four whatever hull you are flying.
##
## Capacities are 8 / 12 / 16, so four columns is exactly 2, 3 and 4 full rows —
## no ragged last row on any ship in the game, and the shape itself tells you
## which weight class you are in.
##
## Width is also why this is safe. Measured at eight columns the two panels
## demanded 985px of a 944px viewport and the melter and the last storage column
## hung off the right edge. The left panel cannot give any of it back — its 527px
## is the banner plus the ship at 2x, and the ship is the subject. Four columns
## is 201px against six columns' 303px, so the grid now costs a third of what it
## did when it did not fit.
## The ship panel's height: the tallest hull (235x114) plus the idle bob's four
## rows plus a little air. Named because ChassisSelect and StationScreen size
## the same thing and all three have to move together when a hull gets deeper.
const HULL_VIEW_H := 120

const STORAGE_COLS := 4

var _storage: HoldGrid
var _attrs: AttrBlock
var _mounts: VBoxContainer
var _mountpts: MountPoints
var _view: ShipView
var _banner: ChassisSelect.Banner
var _name: Label
var _maker: Label
var _class: Label
var _hand: Label
var _hold: Label
var _abilities: VBoxContainer

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Sig.ship_changed.connect(_refresh)
	Sig.resources_changed.connect(_refresh)
	_refresh()

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 5)
	add_child(root)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# --- left: what you are flying
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)

	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 1)
	_name = UITheme.body("", UITheme.ICE, UITheme.FS_HEAD)
	names.add_child(_name)
	# Who built it, in their own colour, directly under the ship's name — the two
	# halves of what this thing IS. The frame and tier are a separate, greyer
	# fact underneath, and the hull perk is not here at all: the abilities block
	# below already states it as BUILT IN, and saying it twice made the subtitle
	# a duplicate of a row six lines down.
	_maker = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	names.add_child(_maker)
	_class = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	names.add_child(_class)
	left.add_child(names)

	# The banner hangs the full depth of the ship rather than a badge sitting
	# beside a name. It is the same flag the chassis cards fly and it is the one
	# piece of this panel that says whose yard built the thing you are looking
	# at, so it gets the height the subject has — a 26px badge next to two lines
	# of text read as a bullet point.
	var shiprow := HBoxContainer.new()
	shiprow.add_theme_constant_override("separation", 8)
	_banner = ChassisSelect.Banner.new()
	shiprow.add_child(_banner)

	# Doubled and cropped to the hull, the same treatment the chassis select
	# gives it. At 1x in a panel this size the ship was a small object adrift in
	# a lot of nothing, which is the wrong impression for the screen whose
	# subject it is. SHRINK_CENTER inside an expanding wrapper puts it in the
	# middle of the space the banner leaves rather than hard against the flag.
	var view := ShipView.new()
	# 2x. Integer scaling is the whole pixel-art rule, so the ship is either its
	# own size or exactly double and there is nothing in between. 184 rows: the
	# canvas is cropped to 88, doubling needs 176, plus bob headroom.
	# 1x, not 2x, and the height sized off the TALLEST hull rather than the one
	# that used to be the only one.
	#
	# 2x was set when every hull was procedural at 240x120 and the one real
	# sprite was 188x88. The generated hulls run to 235x114, so 2x put a 470px
	# ship on a 960px canvas — half the screen — and 184 rows clipped the top and
	# bottom off the deepest ones. Integer magnification is the art rule and 1x
	# is the only step below 2x, so this is half rather than a nudge; at the
	# viewport's own 2x it is still two real pixels per art pixel and crisp.
	view.magnify(1, HULL_VIEW_H)
	view.bob(2)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# The mounts are a CHILD of the view, so they inherit its rect and every
	# position they draw is in the view's own coordinates — which is what makes
	# ShipView.canvas_to_local the only place the sprite's bob, magnification
	# and centring are reasoned about.
	_mountpts = MountPoints.new()
	_mountpts.attach(view)
	_mountpts.dropped.connect(_on_mount_drop)
	view.add_child(_mountpts)
	_view = view
	var vwrap := HBoxContainer.new()
	vwrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vwrap.add_child(view)
	shiprow.add_child(vwrap)
	left.add_child(shiprow)

	left.add_child(UITheme.body("ATTRIBUTES", UITheme.COLD, UITheme.FS_SMALL))
	_attrs = AttrBlock.new()
	left.add_child(_attrs)

	# The same block the chassis select shows, on the screen where it is
	# ACTIONABLE. There it answers "what would flying this cost me" before you
	# commit; here it answers "what have I got left", which is the question you
	# are asking on every drop — and it was the one screen in the game where
	# slot pressure was invisible while you were spending it.
	left.add_child(UITheme.body("HARDPOINTS", UITheme.COLD, UITheme.FS_SMALL))
	_mounts = VBoxContainer.new()
	_mounts.add_theme_constant_override("separation", 2)
	left.add_child(_mounts)

	_hand = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	left.add_child(_hand)

	# The abilities go here, not on the chassis select's terms. There they
	# answer "what would flying this house give me"; here they answer "how close
	# am I now", and the answer changes every time you drop a part into a mount
	# on the other half of this screen. Under the attributes because it is the
	# same column of facts about the ship — what it is, then what it unlocks.
	#
	# Given real air above it. They are two different KINDS of fact — six gauges
	# you read at a glance, then three conditional rules you read as sentences —
	# and at the column's 4px separation they ran together as one list.
	var abgap := Control.new()
	abgap.custom_minimum_size = Vector2(0, 10)
	abgap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(abgap)
	left.add_child(UITheme.body("MANUFACTURER ABILITIES", UITheme.COLD, UITheme.FS_SMALL))
	_abilities = VBoxContainer.new()
	_abilities.add_theme_constant_override("separation", 1)
	left.add_child(_abilities)

	# The slack goes at the BOTTOM, in one place. Spread through the column — as
	# it was when the ship view expanded — it opened a gap between the ship and
	# its own numbers, which are the two things this half is comparing.
	var lgap := Control.new()
	lgap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lgap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(lgap)

	var lwrap := Widgets.panel_with(left)
	lwrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(lwrap)

	# --- right: the parts, and where they go
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# No HARDPOINTS heading here any more: the mounts moved onto the hull and the
	# rule under them moved with the rack, or the panel opened on a rule with
	# nothing above it.
	_hold = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	right.add_child(_hold)

	_storage = HoldGrid.new()
	_storage.dropped.connect(_on_hold_drop)
	right.add_child(_storage)

	var rgap := Control.new()
	rgap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rgap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(rgap)

	# EXPAND_FILL on the PANEL, not on the column inside it. Setting it on the
	# inner VBox does nothing useful — the wrapper is the child the HBox is
	# sizing, so the panel stayed at its content width and left seven hundred
	# pixels of the screen empty to its right.
	var rwrap := Widgets.panel_with(right)
	rwrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(rwrap)

func _refresh() -> void:
	if Run.hull == null:
		return
	var man := Run.hull.manufacturer
	var maker: ManufacturerData = DB.manufacturers.get(man)
	var accent := maker.colour if maker != null else UITheme.CHILL
	_banner.man = man
	_banner.mark = accent
	_banner.field = maker.field if maker != null else UITheme.PANEL
	_banner.queue_redraw()
	_name.text = Run.hull.name.to_upper()
	_maker.text = maker.name.to_upper() if maker != null else "UNBRANDED SALVAGE"
	_maker.add_theme_color_override("font_color", accent)
	_class.text = "%s CHASSIS · %s TIER" % [
		HullData.weight_name(Run.hull.weight).to_upper(), Run.hull.tier_letter()]
	_attrs.setup(Run.attributes(), accent)
	_refresh_mounts()
	_hand.text = "%d cards a turn · %d in the deck" % [Run.hand_size(), Run.deck_size()]

	# Rebuilt every refresh, because the unlock state is the point: fitting a
	# third Korvan part has to light the 3+ row the moment it lands.
	Widgets.clear(_abilities)
	for row in Widgets.ability_rows(man, Run.hull.perk_id, Run.manufacturer_count(man)):
		_abilities.add_child(row)

	# Other allegiances go under the hull's own, and only when you have one. A
	# Korvan ship carrying two Solari parts is two from a second set bonus, and
	# this is now the only place on the screen that says so.
	var others := Widgets.other_maker_rows(man)
	if not others.is_empty():
		_abilities.add_child(UITheme.hsep())
		for row2 in others:
			_abilities.add_child(row2)

	# --- the hardpoints are ON THE SHIP now, drawn over the view on the left.
	# What used to be a rack of squares here is the HARDPOINTS tally under the
	# attributes; what a rack could never say is where a mount actually is.
	if _mountpts != null:
		_mountpts.refresh()

	_storage.refresh()
	# Cells, not parts. "6 of 12" counted parts against a capacity in parts, and
	# neither half of that survives a grid: the hold holds as many things as
	# their shapes allow, so the honest number is how much ROOM is gone.
	_hold.text = "STORAGE — %d of %d cells" % [Run.cargo_used(), Run.cargo_slots()]

## The hardpoint tally, mirroring the chassis select's.
##
## Pads reserve to the same ceiling that screen uses, so the two read as one
## block seen twice rather than as two designs — and the figures line up in a
## column instead of tracking the pad count.
func _refresh_mounts() -> void:
	Widgets.clear(_mounts)
	for s in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var label := UITheme.body(ModuleData.slot_name(s).to_upper(),
			UITheme.COLD, UITheme.FS_SMALL)
		label.custom_minimum_size = Vector2(46, 0)
		row.add_child(label)
		var pads := ChassisSelect.SlotPads.new()
		pads.setup(Run.slots_used(s), Run.slots_for(s), ChassisSelect._mount_ceiling())
		row.add_child(pads)
		row.add_child(UITheme.body("%d/%d" % [Run.slots_used(s), Run.slots_for(s)],
			UITheme.CHILL, UITheme.FS_SMALL))
		_mounts.add_child(row)

## A part dropped onto a mount ON THE HULL.
##
## The mount is a PLACE, so `index` is carried through to the module rather than
## derived from the order of `installed` — that was the bug the stored `mount`
## fixed and it would come straight back if this appended instead.
func _on_mount_drop(payload: Dictionary, slot: ModuleData.Slot, index: int) -> void:
	var m: ModuleData = payload.get("module")
	if m == null or m.slot != slot:
		return
	var resident := Run.module_at(slot, index)
	if resident == m:
		return

	# Two fitted parts trading mounts EXCHANGE places rather than sending one to
	# the hold — the same rule the rack had, and it matters more here, where the
	# mounts are visibly different positions on the ship.
	if resident != null and Run.installed.has(m):
		var there := m.mount
		m.mount = index
		resident.mount = there
		Sig.ship_changed.emit()
		Run.log_line("Moved %s." % m.name, &"sys")
		_refresh()
		return

	# The resident has nowhere to go but the hold, and if it will not fit there
	# the move is refused BEFORE anything has been taken off the ship.
	if resident != null and not Run.has_room_for(resident):
		Run.log_line("No room in the hold for %s." % resident.name, &"them")
		return

	var was_at := m.hold_at
	if Run.cargo.has(m):
		Run.take_from_hold(m)
	if resident != null:
		Run.installed.erase(resident)
		resident.mount = -1
		if not Run.place_in_hold(resident):
			# Cannot happen — has_room_for said yes a moment ago and nothing has
			# taken cells since. Put everything back rather than trust that.
			resident.mount = index
			Run.installed.append(resident)
			if was_at.x >= 0:
				Run.place_in_hold(m, was_at)
			Run.log_line("No room in the hold for %s." % resident.name, &"them")
			return
	Run.installed.erase(m)
	m.mount = index
	Run.installed.append(m)
	Sig.ship_changed.emit()
	Run.log_line("Fitted %s." % m.name, &"good")
	_refresh()

## The only place `installed` and `cargo` move.
##
## Written as "take it out of wherever it was, then put it where it landed",
## because every case is that: a swap is the same two steps with the resident
## displaced first. Special-casing storage-to-hardpoint and hardpoint-to-storage
## separately is how you end up with a fourth path nobody thought about that
## duplicates a module.
## Would every one of these fit at once?
##
## Asked by placing them for real and rolling back, because "do N parts fit"
## is not a sum: two 1x3 guns need two separate runs of three, and free-cell
## arithmetic says yes to a hold that cannot hold either of them.
## A part dropped onto a CELL of the hold.
##
## Separate from _on_mount_drop because the two answer different questions. A
## hardpoint asks "does this slot type match"; the hold asks "does this shape
## fit here", and the cell it fits at is information a mount has no use for.
func _on_hold_drop(payload: Dictionary, at: Vector2i) -> void:
	var m: ModuleData = payload.get("module")
	if m == null:
		return
	var was_at := m.hold_at
	var from_ship := Run.installed.has(m)
	if Run.cargo.has(m):
		Run.take_from_hold(m)
	if not Run.place_in_hold(m, at):
		# Put it back exactly where it was. A refused move must cost nothing —
		# the alternative is a part that vanishes because the arithmetic said no
		# after it had already been lifted.
		if not from_ship and was_at.x >= 0:
			Run.place_in_hold(m, was_at)
		return
	if from_ship:
		Run.installed.erase(m)
		m.mount = -1
		Run.log_line("Stowed %s." % m.name, &"sys")
	Sig.ship_changed.emit()
	_refresh()