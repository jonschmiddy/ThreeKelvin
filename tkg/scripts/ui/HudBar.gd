class_name HudBar
extends PanelContainer

## Persistent top bar: navigation, hull, heat, economy, frame, and live set-bonus
## progress.
##
## SHIP and MAP live here rather than inside each screen, so they are in the same
## place everywhere. SHIP greys out during combat instead of disappearing — you
## cannot refit mid-fight, and a button that says so beats one that vanishes.

var _row: HBoxContainer
var _hull: BoxGauge
var _heat: BoxGauge
var _heat_text: Label

func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.bevel(UITheme.PANEL, 5, 6))
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10)
	add_child(_row)
	set_process(true)
	Sig.resources_changed.connect(refresh)
	Sig.ship_changed.connect(refresh)
	Sig.screen_changed.connect(refresh)
	refresh()

func refresh() -> void:
	if Run.hull == null:
		return
	for c in _row.get_children():
		c.queue_free()

	var fighting := Router.in_combat()
	# Choosing a chassis locks the whole bar. Until you have launched there is no
	# sector to look at, no chart to plot on and nothing to refit — and a SHIP
	# tab that works before the run starts is an invitation to change a hull
	# behind the back of the screen whose entire job is choosing one.
	var choosing := Router.current is ChassisSelect
	var choose_lock := "Choose a chassis first." if choosing else ""
	var lock := choose_lock if choosing else ("Locked during combat." if fighting else "")

	# Ship | Sector | Starchart. The page you are on is lit rather than merely
	# disabled, so the nav says where you are as well as where you can go.
	_row.add_child(_tab("SHIP", Router.current is ShipScreen, lock,
		func() -> void: Router.show_ship(),
		"Install and scrap modules."))
	# Combat happens in the sector, so the tab stays lit through a fight rather
	# than greying out as if you had left.
	_row.add_child(_tab("SECTOR", Router.current is SectorScreen or fighting, choose_lock,
		func() -> void: Router.show_sector(),
		"What is around you."))
	_row.add_child(_tab("STARCHART", Router.current is StarchartScreen, lock,
		func() -> void: Router.show_starchart(),
		"Where to go next."))

	_row.add_child(_divider())

	# Hull reads as cells, like heat beside it. Ten of them whatever the frame,
	# because the useful question is what FRACTION is left — the exact figure is
	# on the tooltip, and the two ships either side of this bar disagree about
	# what a big number even is.
	var hull_note := "Hull %d of %d — %s.\nTen cells whatever the frame, so each is a tenth of your own maximum. Repairs cost %d scrap a point." % [
		Run.hp, Run.max_hp(), Run.hull.name, Run.repair_cost_per_hull()]
	_row.add_child(_hinted(
		UITheme.body("HULL", UITheme.COLD, UITheme.FS_SMALL), hull_note))
	_hull = BoxGauge.new()
	_hull.set_hull(Run.hp, Run.max_hp())
	_hull.tooltip_text = hull_note
	_row.add_child(_hull)

	# Heat reads as countable cells; the number beside it names the cost when
	# you are over cap, because that is the only time the number matters.
	var over := Run.heat - Run.heat_cap()
	var heat_note := "Heat %d of %d, shedding %d per turn.\nNo cap and no shutdown — go over and you pay 1 hull per point at end of turn. Heat is a second health bar you are allowed to spend." % [
		Run.heat, Run.heat_cap(), Run.dissipation()]
	if over > 0:
		heat_note = "Heat %d, %d over cap.\nThat is %d hull at end of turn unless you vent. Shedding %d per turn." % [
			Run.heat, over, over, Run.dissipation()]
	var heat_label := UITheme.body("HEAT", UITheme.COLD, UITheme.FS_SMALL)
	_row.add_child(_hinted(heat_label, heat_note))
	_heat = BoxGauge.new()
	_heat.setup(BoxGauge.Mode.HEAT, Run.heat_cap(), Run.heat)
	_heat.tooltip_text = heat_note
	_row.add_child(_heat)
	_heat_text = UITheme.body(
		("%d — %d HULL" % [Run.heat, over]) if over > 0 else "%d/%d" % [Run.heat, Run.heat_cap()],
		UITheme.FLARE if over > 0 else UITheme.COLD, UITheme.FS_SMALL)
	_row.add_child(_hinted(_heat_text, heat_note))

	_row.add_child(_divider())
	# Every readout on this bar explains itself on hover. The bar is where the
	# whole economy is stated and none of it is self-evident: scrap is one
	# currency competing with itself, fuel is priced by chart distance, and heat
	# is a second health bar you are allowed to spend.
	_row.add_child(_hinted(Widgets.stat("scrap", str(Run.scrap)),
		"Scrap: %d.\nThe only currency. Repairs, upgrades and purchases all come out of it — which is where this game's difficulty actually lives." % Run.scrap))
	if Run.exotic > 0:
		_row.add_child(_hinted(Widgets.stat("exotic", str(Run.exotic)),
			"Exotic: %d.\nHarvested from megafauna, not manufactured. Buys things scrap cannot." % Run.exotic))
	_row.add_child(_hinted(Widgets.stat("fuel", str(Run.fuel)),
		"Fuel: %d.\nEvery jump costs by how far it plainly is on the chart. Run dry between stations and the run ends adrift." % Run.fuel))

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(sp)

	# Card gallery, top right beside the frame rate — the two development
	# readouts together, away from the three tabs that are part of the game.
	# It never greys out during combat: looking at the catalog changes nothing,
	# and mid-fight is exactly when you want to check what a card was supposed
	# to say. It DOES grey while choosing a chassis, which is the one moment
	# there is no run to come back to.
	_row.add_child(_tab("CARDS", Router.current is CardGalleryScreen, choose_lock,
		func() -> void: Router.show_cards(),
		"Every card in the game."))
	_row.add_child(_divider())

	# Frame rate, far right. Lives on the HUD rather than on the chart because
	# the chart is only where the cost is currently obvious — knowing what the
	# rest of the game runs at is the comparison that makes the number mean
	# anything.
	_fps = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_row.add_child(_fps)

## Sampled a few times a second rather than every frame: a counter that updates
## sixty times a second is unreadable, and averaging over a short window is what
## makes a stutter visible as a dip instead of a blur.
var _fps: Label
var _fps_t: float = 0.0

func _process(delta: float) -> void:
	if _fps == null:
		return
	_fps_t += delta
	if _fps_t < 0.25:
		return
	_fps_t = 0.0
	var f := Engine.get_frames_per_second()
	var col := UITheme.COLD
	if f < 30:
		col = Color("#c8503c")
	elif f < 50:
		col = Color("#b8923f")
	_fps.text = "%d FPS" % f
	_fps.add_theme_color_override("font_color", col)

## Give a readout a tooltip, and make it able to receive the hover that shows
## it. Label defaults to MOUSE_FILTER_IGNORE, so setting tooltip_text alone is
## silently a no-op — the text is set and the tooltip never appears. Containers
## need the same treatment plus their children, or the hover falls through the
## gaps between words.
func _hinted(c: Control, text: String) -> Control:
	c.tooltip_text = text
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	for child in c.get_children():
		var cc := child as Control
		if cc != null:
			cc.tooltip_text = text
			cc.mouse_filter = Control.MOUSE_FILTER_STOP
	return c

func _divider() -> Control:
	var d := Panel.new()
	d.custom_minimum_size = Vector2(1, 14)
	d.add_theme_stylebox_override("panel", UITheme.flat(UITheme.LINE, Color(0, 0, 0, 0), 0, 0, 0))
	return d

## `lock` is empty when the tab is available, and otherwise says WHY it is not.
## A greyed control that cannot explain itself reads as a bug; one that says
## "choose a chassis first" reads as the game waiting for you.
func _tab(label: String, active: bool, lock: String, action: Callable,
		hint: String) -> Button:
	var b := Widgets.button(label, action)
	var locked := lock != ""
	b.disabled = locked or active
	b.tooltip_text = lock if locked else hint
	if active and not locked:
		# Lit, not greyed: an active tab is a statement, not an unavailable option.
		b.add_theme_stylebox_override("normal", UITheme.bevel(Color("#4a2a0c"), 3, 5))
		b.add_theme_stylebox_override("disabled", UITheme.bevel(Color("#4a2a0c"), 3, 5))
		b.add_theme_color_override("font_disabled_color", UITheme.HOT)
	return b
