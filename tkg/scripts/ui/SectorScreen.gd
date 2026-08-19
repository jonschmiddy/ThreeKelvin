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
var _side_wrap: PanelContainer
var _strip_wrap: PanelContainer
var _hand_wrap: PanelContainer
var _preview: Label
var _energy: BoxGauge
var _energy_text: Label
var _player_chips: HBoxContainer
var _enemy_name: Label
var _enemy_tag: Label
var _enemy_hp: Label
var _enemy_bar: ProgressBar
var _enemy_chips: HBoxContainer
var _intent_label: Label
var _hand: HandView
var _deck_label: Label
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
	_hull = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	col.add_child(_hull)
	_facts = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	col.add_child(_facts)
	_state = UITheme.body("", UITheme.FLARE, UITheme.FS_SMALL)
	col.add_child(_state)

	arena.add_child(_build_side_rail())
	arena.add_child(_build_salvage_rail())

	root.add_child(_build_quiet_strip())
	root.add_child(_build_intent_strip())
	root.add_child(_build_hand())
	_build_overlay()

func _build_side_rail() -> PanelContainer:
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 3)
	side.custom_minimum_size = Vector2(186, 0)
	_enemy_name = UITheme.body("", UITheme.THEM, UITheme.FS_BODY)
	side.add_child(_enemy_name)
	_enemy_bar = ProgressBar.new()
	_enemy_bar.custom_minimum_size = Vector2(0, 7)
	_enemy_bar.show_percentage = false
	side.add_child(_enemy_bar)
	_enemy_hp = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	side.add_child(_enemy_hp)
	# What the hovered card would land, after this enemy's block and armor.
	_preview = UITheme.body("", UITheme.FLARE, UITheme.FS_SMALL)
	side.add_child(_preview)
	_enemy_tag = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	side.add_child(_enemy_tag)
	_enemy_chips = HBoxContainer.new()
	_enemy_chips.add_theme_constant_override("separation", 3)
	side.add_child(_enemy_chips)
	side.add_child(UITheme.hsep())
	_player_chips = HBoxContainer.new()
	_player_chips.add_theme_constant_override("separation", 3)
	side.add_child(_player_chips)
	side.add_child(UITheme.hsep())
	_log = LogPanel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_log)
	_side_wrap = Widgets.panel_with(side)
	return _side_wrap

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
		_:
			return ["", "PLOT NEXT JUMP"]

func _build_intent_strip() -> PanelContainer:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	strip.add_child(UITheme.body("INTENT", UITheme.COLD, UITheme.FS_SMALL))
	_intent_label = UITheme.body("", UITheme.ICE, UITheme.FS_SMALL)
	strip.add_child(_intent_label)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(gap)
	strip.add_child(UITheme.body("ENERGY", UITheme.COLD, UITheme.FS_SMALL))
	_energy = BoxGauge.new()
	_energy.setup(BoxGauge.Mode.ENERGY, Run.reactor(), 0)
	strip.add_child(_energy)
	_energy_text = UITheme.body("", UITheme.FLARE, UITheme.FS_SMALL)
	strip.add_child(_energy_text)
	_strip_wrap = Widgets.panel_with(strip)
	return _strip_wrap

func _build_hand() -> PanelContainer:
	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 6)
	_deck_label = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	hand_row.add_child(_deck_label)
	_hand = HandView.new()
	_hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand.card_hovered.connect(_on_card_hovered)
	_hand.reordered.connect(_on_hand_reorder)
	hand_row.add_child(_hand)
	_end_button = Widgets.button("END TURN", _on_end_turn)
	hand_row.add_child(_end_button)
	hand_row.add_child(Widgets.button("FLEE", _on_flee))
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

	_side_wrap.visible = at_war
	_strip_wrap.visible = at_war
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
	for c in _enemy_chips.get_children():
		c.queue_free()
	for e in live:
		if e.block > 0:
			_enemy_chips.add_child(Widgets.chip("%s block %d" % [
				DB.short_name(e.template.name), e.block], Color("#3a4a6e")))
		if e.armor > 0:
			_enemy_chips.add_child(Widgets.chip("%s armor %d" % [
				DB.short_name(e.template.name), e.armor], Color("#3a5a6e")))

	var intents: PackedStringArray = []
	for e in live:
		if e.intent != null:
			intents.append("%s: %s" % [DB.short_name(e.template.name), e.intent.name] 				if live.size() > 1 else "%s — %s" % [e.intent.name, e.intent.text])
	_intent_label.text = "   ".join(intents)

	_view.bind_self_drop(_on_self_drop)
	_view.show_enemies(combat.enemies, _on_card_dropped, _on_slot_hovered)

func _refresh_hand() -> void:
	if not fighting():
		return
	# The hand reconciles rather than rebuilds, so cards slide into the gap a
	# played card leaves instead of the whole row snapping to new positions.
	_hand.sync(combat.hand, func(c): return combat.can_play(c))
	_deck_label.text = "deck %d · discard %d · turn %d" % [
		combat.deck.size(), combat.discard.size(), combat.turn]
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
		_view.clear_estimates()
		combat.play(hand_index)

## Hovering a card prices it against every enemy at once, so choosing a target
## is a comparison rather than a guess.
func _on_card_hovered(view: CardView, entered: bool) -> void:
	if not fighting() or not entered or combat.finished:
		_preview.text = ""
		_view.clear_estimates()
		return
	var best := 0
	for i in combat.enemies.size():
		var e = combat.enemies[i]
		if e.hp <= 0:
			_view.estimate(i, "")
			continue
		var d := combat.preview_damage(view.card, i)
		best = maxi(best, d)
		_view.estimate(i, "" if d <= 0 else ("-%d  KILLS" % d if d >= e.hp else "-%d" % d))
	_preview.text = "DRAG ONTO A TARGET" if best > 0 else "DRAG ONTO YOUR HULL"

func _on_slot_hovered(_index: int, _entered: bool) -> void:
	pass

## Dropping a card on an enemy plays it at that enemy.
func _on_card_dropped(index: int, view: CardView) -> void:
	if not fighting() or view == null:
		return
	var hand_index := combat.hand.find(view.card)
	if hand_index >= 0 and combat.can_play(view.card):
		_view.clear_estimates()
		combat.play(hand_index, index)

## Hand order is presentation, not state — the deck, discard and draw rules do
## not care — so reordering is free and worth allowing.
## Hand order is presentation, not state — the deck, discard and draw rules do
## not care — so reordering is free. The view hands over the order it is already
## showing, which is why nothing can land a slot off.
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

func _on_flee() -> void:
	if fighting():
		combat.flee()

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
