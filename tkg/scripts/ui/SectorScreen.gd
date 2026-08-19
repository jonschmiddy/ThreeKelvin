class_name SectorScreen
extends Control

## Where you are — one screen, whether or not something is shooting at you.
##
## There is no separate combat screen. A fight is this sector with an enemy in
## it: the same frame, the same ship in the same place, with the hand and intent
## strip appearing underneath. Two classes drawing the same place gave the player
## two versions of one page and made the ship jump between contexts.
##
## `combat` is null when the sector is quiet. Combat-only controls hide rather
## than being built conditionally, so there is one layout to reason about.

var combat: Combat
## The last card played, kept only so an attack can be drawn as the weapon it
## came from. Presentation, never consulted by anything that resolves.
var _last_played: CardData = null

# --- shared
var _view: EncounterView
var _title: Label
var _sub: Label
var _blurb: Label
var _facts: Label
var _state: Label
var _hull: Label

# --- salvage (quiet only)
var _salvage: VBoxContainer
var _salvage_wrap: PanelContainer
## Dismissed for now, not thrown away. Reset when fresh salvage arrives.
var _stowed: bool = false
var _last_cargo: int = -1

# --- combat only
var _hand_wrap: PanelContainer
var _preview: Label
var _energy: BoxGauge
var _energy_text: Label
var _player_chips: HBoxContainer
var _enemy_name: Label
var _enemy_tag: Label
var _enemy_hp: Label
var _enemy_bar: ProgressBar
var _intent_label: Label
var _hand: HandView
## The keyword panel while a card is hovered. See _show_readout.
var _readout: PanelContainer = null
## Which card the panel belongs to. See _show_readout.
var _readout_for: CardView = null
## The card whose panel is counting down but has not opened yet.
var _readout_pending: CardView = null
## How long you have to rest on a card before it explains itself.
const READOUT_DELAY := 1.0
var _deck_label: Label
var _draw_pile: PileView
## The confirmation panel while it is open. See _on_flee.
var _flee_ask: PanelContainer = null
var _discard_pile: PileView
var _end_button: Button
var _log: LogPanel
var _quiet_wrap: PanelContainer
var _quiet_text: Label
var _action: Button
var _overlay: PanelContainer
var _overlay_title: Label
var _overlay_body: Label

func setup(c: Combat = null) -> void:
	combat = c
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

	Sig.resources_changed.connect(_refresh)
	Sig.ship_changed.connect(_refresh)
	Sig.map_changed.connect(_refresh)
	Sig.hand_changed.connect(_refresh_hand)
	Sig.enemy_changed.connect(_refresh_enemy)
	Sig.player_combat_state_changed.connect(_refresh_player)
	Sig.turn_started.connect(func(_t): _refresh())
	Sig.combat_ended.connect(_on_combat_ended)
	Sig.damage_dealt.connect(_on_damage)
	Sig.enemy_destroyed.connect(_on_enemy_destroyed)
	# Damage says how much and to whom, never with what — so the card is caught
	# on its way past and read for its material.
	Sig.card_played.connect(func(c: CardData) -> void: _last_played = c)

	_refresh()

func fighting() -> bool:
	return combat != null and combat.enemy != null

# ---------------------------------------------------------------------- build

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var arena := HBoxContainer.new()
	arena.add_theme_constant_override("separation", 5)
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(arena)

	# The scene, with readouts laid over it rather than boxed beside it.
	var stack := Control.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.add_child(stack)

	_view = EncounterView.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_view)
	_view.fx.landed.connect(_on_shot_landed)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 6)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)
	col.add_child(UITheme.body("SECTOR", UITheme.COLD, UITheme.FS_SMALL))
	_title = UITheme.body("", UITheme.ICE, UITheme.FS_HEAD)
	col.add_child(_title)
	_sub = UITheme.body("", UITheme.THEM, UITheme.FS_SMALL)
	col.add_child(_sub)
	_blurb = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(300, 0)
	col.add_child(_blurb)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	# Hull, heat, danger, layer and "engaged - 1 hostile" all lived here, and
	# every one of them is already on screen: hull and heat in the HUD along the
	# top, the sector's name and class in the header above this, and the count
	# of hostiles is the number of ships you can see. Built but not added, so
	# the refresh code that writes to them keeps working.
	_hull = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	_facts = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_state = UITheme.body("", UITheme.FLARE, UITheme.FS_SMALL)

	arena.add_child(_build_salvage_rail())

	root.add_child(_build_quiet_strip())
	_build_orphans()
	root.add_child(_build_hand())
	_build_overlay()

## The side rail is gone. Its contents, in order of what happened to them:
##
## The log went because every line was a transcript of an animation you had just
## watched, competing with the board for the same glance. The enemy's name,
## health bar, hull count and class went because all four already sit under its
## sprite, where the enemy actually is. The two chip rows moved to the intent
## strip, which was already the line answering "what is happening this turn".
##
## And _preview went because the targets now say it themselves: a valid drop
## lights up and paints the number it would do. These four stay alive as
## orphans so the refresh code that writes to them does not have to change.
func _build_orphans() -> void:
	_enemy_name = UITheme.body("", UITheme.THEM, UITheme.FS_BODY)
	_enemy_bar = ProgressBar.new()
	_enemy_bar.show_percentage = false
	_enemy_hp = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_enemy_tag = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_preview = UITheme.body("", UITheme.FLARE, UITheme.FS_SMALL)
	_log = LogPanel.new()

func _build_salvage_rail() -> PanelContainer:
	_salvage = VBoxContainer.new()
	_salvage.add_theme_constant_override("separation", 3)
	var head := UITheme.body("SALVAGE - STOW IT OR FIT IT", UITheme.COLD, UITheme.FS_SMALL)
	head.name = "Head"
	_salvage.add_child(head)
	_salvage_wrap = Widgets.panel_with(_salvage)
	_salvage_wrap.custom_minimum_size = Vector2(268, 0)
	return _salvage_wrap

## What there is to do here, when nothing is shooting. Occupies the same band as
## the enemy intent strip does in a fight, so the screen keeps one shape whether
## the sector is quiet or not.
func _build_quiet_strip() -> PanelContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_quiet_text = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_quiet_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quiet_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_quiet_text)
	_action = Widgets.button("", _on_action)
	_action.custom_minimum_size = Vector2(196, 22)
	row.add_child(_action)
	_quiet_wrap = Widgets.panel_with(row)
	return _quiet_wrap

## The one thing this place offers. Named for the act, not the screen it opens:
## you dock at a station, you strip a wreck, you answer a hail.
func _on_action() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if Run.dead:
		Router.show_game_over()
		return
	match n.type:
		MapGen.NodeType.STATION:
			Router.show_station()
		MapGen.NodeType.DERELICT:
			if n.cleared:
				Router.show_starchart()
			else:
				Router.salvage_here()
		MapGen.NodeType.EVENT:
			if n.cleared:
				Router.show_starchart()
			else:
				Router.show_event()
		MapGen.NodeType.PULSAR:
			if n.cleared:
				Router.show_starchart()
			else:
				Router.harvest_pulsar()
		# A contact you have not fought yet. Only reachable on a resumed run —
		# arriving at one normally starts the fight before this screen draws —
		# but the button has said ENGAGE all along, and it now does that rather
		# than quietly plotting a jump.
		MapGen.NodeType.FIGHT, MapGen.NodeType.GOAL:
			if n.cleared:
				Router.show_starchart()
			else:
				Router.engage_here()
		_:
			Router.show_starchart()

## Reads the place, not the node type: "a hab ring, lights on" tells you where
## you are in a way that "STATION" never will.
func _quiet_lines(n: MapGen.MapNode) -> Array:
	if Run.dead:
		return ["Nothing on this hull answers any more.", "SUMMARY"]
	match n.type:
		MapGen.NodeType.STATION:
			return ["A hab ring turns slowly, lights on. They will trade, repair and refuel — all of it out of the same pocket.", "DOCK"]
		MapGen.NodeType.DERELICT:
			if n.cleared:
				return ["Stripped. Whatever is left is welded to the frame.", "PLOT NEXT JUMP"]
			return ["A dead hull, drifting. No power, no answer to the hail. Something aboard is still worth taking.", "STRIP THE WRECK"]
		MapGen.NodeType.EVENT:
			if n.cleared:
				return ["The signal has stopped.", "PLOT NEXT JUMP"]
			return ["Something out here is transmitting, and it is addressed to you.", "ANSWER THE HAIL"]
		MapGen.NodeType.FIGHT:
			if n.cleared:
				return ["Wreckage, cooling. Nothing else is moving.", "PLOT NEXT JUMP"]
			return ["Contact.", "ENGAGE"]
		MapGen.NodeType.PULSAR:
			if n.cleared:
				return ["The beam still sweeps. Nothing left aboard can hold any more of it.",
					"PLOT NEXT JUMP"]
			return ["A neutron star, turning eleven times a second. Its wind is the densest fuel in the galaxy and its beam will cook you through the hull. Close enough to scoop is close enough to die.",
				"FLY THE BEAM"]
		MapGen.NodeType.START:
			return ["Open space, and the reactor holding. The core is a long way in from here.", "PLOT NEXT JUMP"]
		# Only drawn on a resumed run — arrival at the Core starts the fight
		# before this screen exists — but the button underneath now engages, so
		# the line above it has to say what pressing it does.
		MapGen.NodeType.GOAL:
			if n.cleared:
				return ["The light is behind you.", "PLOT NEXT JUMP"]
			return ["The core fills the viewport. Something is still guarding it.", "ENGAGE"]
		_:
			return ["", "PLOT NEXT JUMP"]

## The intent strip is gone.
##
## Everything it held moved to the thing it was describing: the move and its
## effect sit over each enemy, each enemy's chips sit under it, and yours sit
## with your energy. A strip at the bottom of the screen naming which ship an
## intent belonged to was doing work that position does for free — and in a
## pack it had to name them all in one line.
func _dead_strip_note() -> void:
	pass

## A stack of card backs with a count on it.
##
## The strips either side of the hand were dead space with a line of text in
## them — "deck 12 · discard 3" — which is a pile's information without a pile.
## Drawn as actual backs the number stops being a stat and becomes a THING: you
## can see the draw pile getting thin, and the discard growing to meet it,
## without reading either.
##
## The back borrows the card's own vocabulary — a banner down the left, a
## punched square where an emblem would go — so a face-down card is obviously
## one of these cards rather than a generic rectangle.
class PileView extends Control:
	# Big enough to read as a card rather than as an icon of one. The hand row
	# is 160 tall to fit a card, so there was height going spare either side.
	const W := 60
	const H := 86
	var count: int = 0
	var label: String = ""

	func _init() -> void:
		custom_minimum_size = Vector2(W, H + 12)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_count(n: int, text: String) -> void:
		if n == count and text == label:
			return
		count = n
		label = text
		queue_redraw()

	func _draw() -> void:
		# Up to three backs, offset, so the pile has depth without needing to
		# draw one rect per card. Depth is the only thing the extra backs are
		# for — the number says how many.
		var shown: int = clampi(count, 0, 3)
		for i in range(shown - 1, -1, -1):
			var o := Vector2(i * 2, -i * 2)
			var r := Rect2(o, Vector2(W, H))
			draw_rect(r, UITheme.PANEL2, true)
			draw_rect(r, UITheme.LINE, false, 1.0)
			draw_rect(Rect2(o + Vector2(3, 3), Vector2(9, H - 6)), Color("#2b3646"), true)
			draw_rect(Rect2(o + Vector2(W * 0.5 - 7, H * 0.5 - 7), Vector2(14, 14)),
				Color("#3a4a5e"), true)
			draw_rect(Rect2(o + Vector2(W * 0.5 - 3, H * 0.5 - 3), Vector2(6, 6)),
				UITheme.PANEL2, true)
		if shown == 0:
			# An empty pile still holds its place, or the hand jumps sideways the
			# turn your draw pile runs out.
			draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color("#1b2430"), false, 1.0)

		var f := UITheme.pixel_font()
		var n := str(count)
		var nw := f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_HEAD).x
		draw_string(f, Vector2((W - nw) * 0.5 + 1, H * 0.5 + 7), n,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_HEAD, UITheme.ICE)
		var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
		draw_string(f, Vector2((W - lw) * 0.5, H + 10), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, UITheme.COLD)

func _build_hand() -> PanelContainer:
	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 6)
	# Everything you spend on the left, everything you end with on the right,
	# and the cards in between. Energy sits at the top of the left column
	# because it is the number you check before choosing a card, not after.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.alignment = BoxContainer.ALIGNMENT_CENTER

	# A box of the same width as END TURN opposite it, so the panel reads as a
	# pair of columns rather than as a pile of leftovers at each end. Label,
	# then the cells you spend, then the count — top to bottom, because that is
	# the order you read it in when deciding whether a card is affordable.
	var nrg := VBoxContainer.new()
	nrg.add_theme_constant_override("separation", 2)
	var nrg_label := UITheme.body("ENERGY", UITheme.COLD, UITheme.FS_SMALL)
	nrg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nrg.add_child(nrg_label)
	_energy = BoxGauge.new()
	_energy.setup(BoxGauge.Mode.ENERGY, Run.reactor(), 0)
	_energy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	nrg.add_child(_energy)
	_energy_text = UITheme.body("", UITheme.FLARE, UITheme.FS_SMALL)
	_energy_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nrg.add_child(_energy_text)

	var nrg_box := PanelContainer.new()
	nrg_box.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.PANEL2, UITheme.LINE, 0, 3, 4))
	nrg_box.custom_minimum_size = Vector2(PileView.W, 38)
	nrg_box.add_child(nrg)
	left.add_child(nrg_box)

	# Turn count in a box of its own, directly under energy — the two things
	# that are true of the whole turn, above the pile that changes within it.
	# It mirrors FLEE opposite: a thin strip between the tall box and the pile.
	_deck_label = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var turn_box := PanelContainer.new()
	turn_box.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.PANEL2, UITheme.LINE, 0, 0, 4))
	turn_box.custom_minimum_size = Vector2(PileView.W, 13)
	turn_box.add_child(_deck_label)
	left.add_child(turn_box)

	# Your own status, under your own numbers. Armor, block, lock-on, riposte,
	# adapt and drones are things you are carrying, so they belong beside the
	# energy you spend rather than in a strip about the enemy.
	_player_chips = HBoxContainer.new()
	_player_chips.add_theme_constant_override("separation", 3)
	_player_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(_player_chips)

	_draw_pile = PileView.new()
	left.add_child(_draw_pile)
	hand_row.add_child(left)

	_hand = HandView.new()
	_hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand.card_hovered.connect(_on_card_hovered)
	_view.preview = _drag_preview
	_hand.reordered.connect(_on_hand_reorder)
	hand_row.add_child(_hand)
	# END TURN, then FLEE, then the discard. Ordered by how often you mean it:
	# the one you press every turn is on top and full size, the one you press
	# once a run is a thin red line under it, and the pile you never press at
	# all is at the bottom.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.alignment = BoxContainer.ALIGNMENT_CENTER

	# Two lines and a box. It is the button you press every single turn, so it
	# should be the biggest target on the panel — and stacked it reads as a
	# button rather than as a word in a row of words.
	_end_button = Widgets.button("END
TURN", _on_end_turn)
	_end_button.custom_minimum_size = Vector2(PileView.W, 38)
	right.add_child(_end_button)

	# Thin, and red, and never sitting beside the button you actually want.
	# Fleeing costs a run's worth of progress; it should take a deliberate aim.
	var flee := Widgets.button("FLEE", _on_flee)
	flee.custom_minimum_size = Vector2(PileView.W, 13)
	flee.add_theme_color_override("font_color", Color("#d4614f"))
	flee.add_theme_color_override("font_hover_color", Color("#f08872"))
	flee.add_theme_stylebox_override("normal",
		UITheme.flat(Color(0, 0, 0, 0), Color("#8f4034"), 0, 0, 6))
	flee.add_theme_stylebox_override("hover",
		UITheme.flat(Color("#2a1a18"), Color("#d4614f"), 0, 0, 6))
	flee.add_theme_stylebox_override("pressed",
		UITheme.flat(Color("#3a2320"), Color("#d4614f"), 0, 0, 6))
	right.add_child(flee)

	_discard_pile = PileView.new()
	right.add_child(_discard_pile)
	hand_row.add_child(right)
	_hand_wrap = Widgets.panel_with(hand_row)
	return _hand_wrap

func _build_overlay() -> void:
	_overlay = PanelContainer.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_theme_stylebox_override("panel",
		UITheme.flat(Color(0.031, 0.043, 0.067, 0.95), Color(0, 0, 0, 0), 0, 24, 24))
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	_overlay.add_child(box)
	_overlay_title = UITheme.body("", UITheme.ICE, UITheme.FS_HEAD)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_overlay_title)
	_overlay_body = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_body.custom_minimum_size = Vector2(420, 0)
	box.add_child(_overlay_body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	row.add_child(Widgets.button("CONTINUE", _on_continue))

# -------------------------------------------------------------------- refresh

func _refresh() -> void:
	if Run.hull == null:
		return
	var n: MapGen.MapNode = Run.node_at()
	var at_war := fighting()
	_view.set_weather(n)

	_hand_wrap.visible = at_war
	_quiet_wrap.visible = not at_war
	if not at_war:
		var lines := _quiet_lines(n)
		_quiet_text.text = lines[0]
		_action.text = lines[1]

	_title.text = MapGen.star_name(n)
	_sub.text = MapGen.place_line(n)

	_hull.text = "HULL %d/%d - HEAT %d/%d" % [
		Run.hp, Run.max_hp(), Run.heat, Run.heat_cap()]
	_facts.text = "%s - DANGER %d - LAYER %d OF %d" % [
		MapGen.type_label(n.type), n.danger, n.layer + 1, MapGen.LAYERS]
	if n.in_nebula:
		# Named, not just described. "Inside a nebula" is a fact about the sky;
		# "inside The Drowned Veil" is a fact about where you are, and it is the
		# same name written across the cloud on the chart.
		var cloud := NebulaField.at(n.gal)
		if cloud != null:
			_facts.text += "  -  INSIDE %s" % cloud.name.to_upper()
	_blurb.text = MapGen.place_blurb(n)

	if at_war:
		_view.bind_self_drop(_on_self_drop)
		_view.show_enemies(combat.enemies, _on_card_dropped, _on_slot_hovered)
		_state.text = "ENGAGED - %d HOSTILE%s" % [
			combat.alive().size(), "" if combat.alive().size() == 1 else "S"]
		_refresh_player()
		_refresh_enemy()
		_refresh_hand()
	else:
		_view.show_area(n)
		# The readout survives death on purpose. Hiding it at the moment the run
		# ends is how a game stops explaining what just happened to you.
		if Run.dead:
			_state.text = "ADRIFT. NOTHING ON THIS HULL ANSWERS ANY MORE."
		elif n.cleared:
			_state.text = "PICKED CLEAN."
		else:
			_state.text = "UNRESOLVED."

	_refresh_salvage()

func _refresh_salvage() -> void:
	for c in _salvage.get_children():
		if c.name != "Head":
			c.queue_free()

	var held := Run.cargo.size()
	# Anything new in the hold re-opens the prompt; stowing is per-haul.
	if held > _last_cargo and _last_cargo >= 0:
		_stowed = false
	_last_cargo = held

	var has := (held > 0 or Run.found_hull != null) and not fighting()
	_salvage_wrap.visible = has and not _stowed
	if not _salvage_wrap.visible:
		return

	if Run.found_hull != null:
		_salvage.add_child(Widgets.hull_row(Run.found_hull, "TRANSFER", 0, _on_salvage))
	for m in Run.cargo:
		_salvage.add_child(Widgets.module_row(m, Widgets.ModuleContext.CARGO, 0, _on_salvage))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	# Stowing keeps everything. The hold is unlimited, so nothing here should
	# destroy salvage by default.
	var stow := Widgets.button("STOW - DECIDE LATER",
		func() -> void:
			_stowed = true
			_refresh())
	stow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stow.tooltip_text = "Keeps it all in the hold. Fit or scrap it from the SHIP page."
	actions.add_child(stow)
	var dump := Widgets.button("JETTISON",
		func() -> void:
			Run.cargo.clear()
			Run.found_hull = null
			Sig.ship_changed.emit()
			_refresh())
	dump.tooltip_text = "Destroys everything in the hold. There is no reason to do this."
	actions.add_child(dump)
	_salvage.add_child(actions)

func _refresh_player() -> void:
	if not fighting():
		return
	_energy.setup(BoxGauge.Mode.ENERGY, Run.reactor(), combat.energy)
	_energy_text.text = "%d/%d" % [combat.energy, Run.reactor()]

	for c in _player_chips.get_children():
		c.queue_free()
	if combat.armor > 0:
		_player_chips.add_child(Widgets.chip("armor %d" % combat.armor, Color("#3a5a6e")))
	if combat.block > 0:
		_player_chips.add_child(Widgets.chip("block %d" % combat.block, Color("#3a4a6e")))
	if combat.lock_on > 0:
		_player_chips.add_child(Widgets.chip("lock +%d" % combat.lock_on, Color("#6e5a3a")))
	if combat.negate_next:
		_player_chips.add_child(Widgets.chip("slip ready", UITheme.GOOD))
	if combat.riposte > 0:
		_player_chips.add_child(Widgets.chip("riposte %d" % combat.riposte))
	if combat.adapt_bonus > 0:
		_player_chips.add_child(Widgets.chip("adapt +%d" % combat.adapt_bonus))
	for d in combat.drones:
		_player_chips.add_child(Widgets.chip("drone %d" % d.damage, Color("#5a7a94")))
	if combat.drone_armor > 0:
		_player_chips.add_child(Widgets.chip("wasp %d" % combat.drone_armor, Color("#5a7a94")))
	for c in combat.charging:
		_player_chips.add_child(Widgets.chip(
			"%s · %d" % [c.card.name, c.turns_left], UITheme.EMBER))
	if combat.enemy.template.fauna and combat.peaceful_turns > 0:
		_player_chips.add_child(Widgets.chip("peaceful %d/2" % combat.peaceful_turns))

func _refresh_enemy() -> void:
	if not fighting():
		return
	var live := combat.alive()
	_enemy_name.text = "%d HOSTILE%s" % [live.size(), "" if live.size() == 1 else "S"] 		if live.size() > 1 else combat.enemy.template.name.to_upper()

	# The bar tracks the whole pack, so you can read how much fight is left
	# without adding up three separate numbers.
	var hp := 0
	var cap := 0
	for e in combat.enemies:
		hp += e.hp
		cap += e.max_hp
	_enemy_bar.max_value = maxi(1, cap)
	_enemy_bar.value = hp
	_enemy_hp.text = "hull %d / %d" % [hp, cap]

	_enemy_tag.text = "%s · danger %d" % [
		combat.enemy.template.tag, Run.node_at().danger]
	# Each enemy's chips go under that enemy. In a pack the old row had to
	# prefix every chip with a ship's name to say who it belonged to; standing
	# under the hull, it does not have to say anything.
	for i in combat.enemies.size():
		var row := _view.chips_for(i)
		if row == null:
			continue
		for c in row.get_children():
			c.queue_free()
		var e = combat.enemies[i]
		if e.hp > 0 and e.block > 0:
			row.add_child(Widgets.chip("block %d" % e.block, Color("#3a4a6e")))

	_view.bind_self_drop(_on_self_drop)
	_view.show_enemies(combat.enemies, _on_card_dropped, _on_slot_hovered)

func _refresh_hand() -> void:
	if not fighting():
		return
	# The hand reconciles rather than rebuilds, so cards slide into the gap a
	# played card leaves instead of the whole row snapping to new positions.
	_hand.sync(combat.hand, func(c): return combat.can_play(c))
	_draw_pile.set_count(combat.deck.size(), "DRAW")
	_discard_pile.set_count(combat.discard.size(), "DISCARD")
	_deck_label.text = "TURN %d" % combat.turn
	_end_button.disabled = combat.finished

# --------------------------------------------------------------------- input

func _on_salvage(action: String, thing: Variant) -> void:
	match action:
		"install": Run.install_module(thing as ModuleData)
		"uninstall": Run.uninstall_module(thing as ModuleData)
		"scrap": Run.scrap_module(thing as ModuleData)
		"take_hull": Run.transfer_to_hull(thing as HullData)
		"leave_hull":
			Run.found_hull = null
			Sig.ship_changed.emit()
	_refresh()

## Played by dropping on your own hull: defence, venting, drawing — anything
## that is not aimed at an enemy.
func _on_self_drop(view: CardView) -> void:
	if not fighting() or view == null:
		return
	var hand_index := combat.hand.find(view.card)
	if hand_index >= 0 and combat.can_play(view.card):
		combat.play(hand_index)

## Hovering a card prices it against every enemy at once, so choosing a target
## is a comparison rather than a guess.
## What a held card would do to the thing under it. Drawn ON the target by the
## slot itself; this only decides the words.
##
## It replaces a small label under each enemy's health bar, which read as part
## of the enemy's own stat block — a number that belonged to them and happened
## to move. Shown only while a card is actually over a target, it reads as the
## answer to a question you are asking.
func _drag_preview(c: CardData, index: int) -> String:
	if not fighting() or combat.finished:
		return ""
	if index >= 0:
		var e = combat.enemies[index]
		var d := combat.preview_damage(c, index)
		if d <= 0:
			return ""
		return "-%d KILL" % d if d >= e.hp else "-%d" % d
	# Your own hull. Whatever the card actually does when it lands there, in the
	# order the player would say it.
	var bits: PackedStringArray = []
	if c.armor > 0:
		bits.append("+%d BRACE" % c.armor)
	if c.armor_from_heat:
		bits.append("+%d BRACE" % Run.heat)
	if c.block > 0:
		bits.append("+%d BLOCK" % c.block)
	if c.heal > 0:
		bits.append("+%d HULL" % c.heal)
	if c.vent_all:
		bits.append("-%d HEAT" % Run.heat)
	elif c.vent > 0:
		bits.append("-%d HEAT" % mini(c.vent, Run.heat))
	if c.draw > 0:
		bits.append("+%d CARD" % c.draw)
	if c.energy_gain > 0:
		bits.append("+%d NRG" % c.energy_gain)
	if c.lock_on > 0:
		bits.append("+%d NEXT" % c.lock_on)
	return " ".join(bits)

func _on_card_hovered(view: CardView, entered: bool) -> void:
	_show_readout(view, entered)
	if not fighting() or not entered or combat.finished:
		_preview.text = ""
		return
	var c := view.card
	var aimable: bool = c.damage > 0 or c.damage_equals_heat or c.evoke > 0
	_preview.text = "DRAG ONTO A TARGET" if aimable else "DRAG ONTO YOUR HULL"

func _on_slot_hovered(_index: int, _entered: bool) -> void:
	pass

## Dropping a card on an enemy plays it at that enemy.
func _on_card_dropped(index: int, view: CardView) -> void:
	if not fighting() or view == null:
		return
	var hand_index := combat.hand.find(view.card)
	if hand_index >= 0 and combat.can_play(view.card):
		combat.play(hand_index, index)

## Hand order is presentation, not state — the deck, discard and draw rules do
## not care — so reordering is free and worth allowing.
## Hand order is presentation, not state — the deck, discard and draw rules do
## not care — so reordering is free. The view hands over the order it is already
## showing, which is why nothing can land a slot off.
## The keyword panel, in a fight.
##
## Same builder the gallery uses. The glossary was only reachable from a
## development screen, which meant every rules word on a card was something the
## player had to already know — and Brace, Salvo and Riposte are precisely the
## words a new player does not.
##
## Floated in a layer above everything rather than placed in the hand row: the
## hand is a fixed-height panel at the bottom of the screen, so a panel parented
## into it would either resize the row or be clipped by it.
func _show_readout(view: CardView, entered: bool) -> void:
	if not entered:
		# Only the card that owns the panel — or the one waiting to — may close
		# it. Sliding from one card to the next fires exited on the old one
		# AFTER entered on the new, so obeying every exit would tear down a
		# panel that had just been built.
		if view == null or view == _readout_for or view == _readout_pending:
			_clear_readout()
		return
	_clear_readout()

	# Not while a card is in the air. Godot keeps sending hover events to
	# whatever the cursor passes over during a drag, so without this, dragging
	# one card across the hand opens the panel for every card it crosses —
	# right where you are trying to see the board.
	if get_viewport().gui_is_dragging():
		return

	# And not immediately. In a fight the cursor crosses the hand constantly
	# on its way to an enemy, and a panel that appears the instant it touches a
	# card turns reading the board into a slideshow. The delay is what makes it
	# a thing you ASK for by resting on a card, rather than a thing that happens
	# to you. The gallery keeps its instant panel: browsing is the whole point
	# there, and nothing is behind it to look at.
	_readout_pending = view
	await get_tree().create_timer(READOUT_DELAY).timeout
	if _readout_pending != view or not is_instance_valid(view):
		return
	if get_viewport().gui_is_dragging():
		return

	_readout_pending = null
	_readout_for = view
	_readout = Widgets.card_readout(view.card)
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Invisible until it knows where it goes.
	#
	# The panel's height depends on how much of its text wrapped, which is not
	# settled until the layout pass — so its final position cannot be computed
	# on the frame it is created. It used to be parked at the top of the screen
	# for that one frame and then moved, which is exactly the flash: a panel
	# appearing in the wrong place and jumping. Held at zero alpha, that frame
	# is simply not seen.
	_readout.modulate.a = 0.0
	add_child(_readout)

	# Above the card, nudged to stay on screen. Above rather than beside because
	# a hand fans across the full width — there is no reliable "beside" — and
	# because the space above the hand is the one part of a combat screen that
	# is never holding anything you need while choosing a card.
	var w: float = _readout.custom_minimum_size.x
	var top := view.global_position - global_position
	var px := clampf(top.x + CardView.CARD_W * 0.5 - w * 0.5, 2.0,
		maxf(2.0, size.x - w - 2.0))
	_readout.position = Vector2(px, 2.0)

	await get_tree().process_frame
	if not is_instance_valid(_readout):
		return
	var py := maxf(2.0, top.y - _readout.size.y - 6.0)
	# Rises the last few pixels as it fades in. The card lifts when you point at
	# it; the panel arriving on the same vector reads as one gesture rather than
	# two things happening near each other.
	_readout.position = Vector2(px, py + 5.0)
	var tw := _readout.create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_readout, "modulate:a", 1.0, 0.14)
	tw.tween_property(_readout, "position:y", py, 0.14)

func _clear_readout() -> void:
	_readout_pending = null
	_readout_for = null
	if _readout != null:
		_readout.queue_free()
		_readout = null

func _on_hand_reorder(cards: Array) -> void:
	if not fighting() or cards.size() != combat.hand.size():
		return
	for c in cards:
		if not combat.hand.has(c):
			return
	combat.hand.clear()
	for c in cards:
		combat.hand.append(c)
	_refresh_hand()

func _on_end_turn() -> void:
	if fighting():
		combat.end_turn()

## Fleeing asks first.
##
## It ends the fight, forfeits every scrap of salvage and burns fuel — and it
## was a button one row from END TURN, which you press every single turn. Making
## it thin and red narrowed the target; it did not make the click reversible.
## Nothing else in combat costs a run's progress in one press, so nothing else
## needs this.
func _on_flee() -> void:
	if not fighting() or _flee_ask != null:
		return

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var head := UITheme.body("BREAK CONTACT?", Color("#d4614f"), UITheme.FS_HEAD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	# The exact cost, from the same constant the code charges.
	var body := UITheme.body(
		"You lose the salvage and burn %d fuel. The fight ends here."
		% Combat.FLEE_FUEL, UITheme.CHILL, UITheme.FS_SMALL)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(220, 0)
	box.add_child(body)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# Staying is the default and sits first: the safe answer should be the one
	# under your hand when the panel opens.
	row.add_child(Widgets.button("KEEP FIGHTING", _close_flee_ask))
	var go := Widgets.button("BREAK CONTACT", func() -> void:
		_close_flee_ask()
		if fighting():
			combat.flee())
	go.add_theme_color_override("font_color", Color("#d4614f"))
	row.add_child(go)
	box.add_child(row)

	_flee_ask = PanelContainer.new()
	_flee_ask.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.PANEL, Color("#8f4034"), 0, 10, 12))
	_flee_ask.add_child(box)
	add_child(_flee_ask)
	_flee_ask.set_anchors_preset(Control.PRESET_CENTER)
	await get_tree().process_frame
	if is_instance_valid(_flee_ask):
		_flee_ask.position = (size - _flee_ask.size) * 0.5

func _close_flee_ask() -> void:
	if _flee_ask != null:
		_flee_ask.queue_free()
		_flee_ask = null

## An attack landed. Draw the shot rather than the result: something crosses the
## gap, and the hull it reaches flinches when it arrives.
##
## The flinch is deliberately NOT here — it waits for the effects layer to
## report the hit. Combat resolves instantly, so shaking at this moment would
## put the recoil before the round had gone anywhere.
func _on_damage(amount: int, to_player: bool, who: int) -> void:
	if amount <= 0 or not fighting() or _view.fx == null:
		return
	var here := _view.enemy_anchor(who)
	var mine := _view.ship_muzzle()
	if to_player:
		# Theirs is always warm and always comes from the enemy that threw it,
		# so several attackers read as several attackers.
		_view.fx.fire(here, mine, CombatFx.Kind.HOSTILE, 1, who, true)
	else:
		# Ballistics run cold and energy weapons run hot — the game says so
		# everywhere else, so the shot should look like the weapon that fired
		# it. A card that generates heat is an energy weapon.
		var kind := CombatFx.Kind.BALLISTIC
		var hits := 1
		if _last_played != null:
			if _last_played.heat > 0:
				kind = CombatFx.Kind.ENERGY
			hits = clampi(_last_played.hits, 1, 6)
		_view.fx.fire(mine, here, kind, hits, who, false)

## A hull coming apart. Spawned before the refresh dims the slot, so the debris
## leaves from where the ship actually was rather than from a grey placeholder.
func _on_enemy_destroyed(who: int) -> void:
	if not fighting() or _view.fx == null:
		return
	var art := _view.enemy_view(who)
	var tint: Color = UITheme.COLD if art == null else Color("#6f8093")
	_view.fx.wreck(_view.enemy_anchor(who), tint)

## The shot arrived. Now the target moves.
func _on_shot_landed(who: int, to_player: bool, _kind: int) -> void:
	var target: Control = _view.ship_view() if to_player else _view.enemy_view(who)
	if target == null:
		return
	var origin := target.position
	var tw := create_tween()
	for i in 3:
		tw.tween_property(target, "position",
			origin + Vector2(randf_range(-3, 3), randf_range(-2, 2)), 0.03)
	tw.tween_property(target, "position", origin, 0.05)

func _on_combat_ended(result: StringName, text: String) -> void:
	# A run ending already has its own screen, with the death reason and the run
	# summary on it. Showing a "RUN ENDED" overlay first and the summary second
	# says the same thing twice, and puts a CONTINUE button between the player
	# and the only information that matters.
	if result == &"dead" or result == &"won":
		call_deferred("_leave_combat")
		return

	var titles := {
		&"victory": "TARGET DESTROYED",
		&"pacified": "CALF PACIFIED",
		&"fled": "DISENGAGED",
	}
	_overlay_title.text = String(titles.get(result, "COMBAT ENDED"))
	_overlay_body.text = text
	_overlay.visible = true
	_overlay.move_to_front()
	_end_button.disabled = true

func _on_continue() -> void:
	_overlay.visible = false
	Router.after_combat(combat)

## Deferred: the fight is mid-emit when it ends, and swapping the screen out
## from under a running signal frees the object still walking its connections.
func _leave_combat() -> void:
	Router.after_combat(combat)
