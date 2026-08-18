class_name CombatScreen
extends Control

## FTL/StS-style combat layout: two unit panels facing each other, telegraphed
## enemy intent, your hand fanned along the bottom, log on the side.

var combat: Combat

var _ship_view: ShipView
var _enemy_art: EnemyArt
var _player_stats: VBoxContainer
var _player_chips: HBoxContainer
var _enemy_name: Label
var _enemy_tag: Label
var _enemy_hp: Label
var _enemy_bar: ProgressBar
var _enemy_chips: HBoxContainer
var _intent_label: Label
var _hand_box: HBoxContainer
var _deck_label: Label
var _end_button: Button
var _log: LogPanel
var _overlay: PanelContainer
var _overlay_title: Label
var _overlay_body: Label

func setup(c: Combat) -> void:
	combat = c
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Sig.hand_changed.connect(_refresh_hand)
	Sig.enemy_changed.connect(_refresh_enemy)
	Sig.player_combat_state_changed.connect(_refresh_player)
	Sig.resources_changed.connect(_refresh_player)
	Sig.turn_started.connect(func(_t): _refresh_all())
	Sig.combat_ended.connect(_on_combat_ended)
	Sig.damage_dealt.connect(_on_damage)
	_refresh_all()

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# --- arena: player | enemy
	var arena := HBoxContainer.new()
	arena.add_theme_constant_override("separation", 10)
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(arena)
	arena.add_child(_build_player_panel())
	arena.add_child(_build_enemy_panel())

	# --- hand
	var hand_section := Widgets.section("hand")
	_hand_box = HBoxContainer.new()
	_hand_box.add_theme_constant_override("separation", 8)
	_hand_box.custom_minimum_size = Vector2(0, CardView.CARD_H + 14)
	_hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_section.add_child(_hand_box)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	_end_button = Widgets.button("END TURN", _on_end_turn)
	controls.add_child(_end_button)
	controls.add_child(Widgets.button("FLEE", _on_flee))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(sp)
	_deck_label = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	controls.add_child(_deck_label)
	hand_section.add_child(controls)
	root.add_child(Widgets.panel_with(hand_section))

	_log = LogPanel.new()
	root.add_child(Widgets.panel_with(_log))

	_build_overlay()

func _build_player_panel() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.add_child(UITheme.body("YOUR SHIP", UITheme.ICE, UITheme.FS_BODY))
	section.add_child(UITheme.body(Run.hull.display_name(), UITheme.COLD, UITheme.FS_SMALL))
	_ship_view = ShipView.new()
	section.add_child(_ship_view)
	_player_stats = VBoxContainer.new()
	_player_stats.add_theme_constant_override("separation", 2)
	section.add_child(_player_stats)
	_player_chips = HBoxContainer.new()
	_player_chips.add_theme_constant_override("separation", 4)
	section.add_child(_player_chips)

	var wrap := Widgets.panel_with(section)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return wrap

func _build_enemy_panel() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	_enemy_name = UITheme.body("", UITheme.ICE, UITheme.FS_BODY)
	section.add_child(_enemy_name)
	_enemy_tag = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	section.add_child(_enemy_tag)
	_enemy_art = EnemyArt.new()
	section.add_child(_enemy_art)
	_enemy_hp = UITheme.body("", UITheme.ICE, UITheme.FS_SMALL)
	section.add_child(_enemy_hp)
	_enemy_bar = ProgressBar.new()
	_enemy_bar.custom_minimum_size = Vector2(0, 8)
	_enemy_bar.show_percentage = false
	section.add_child(_enemy_bar)
	_enemy_chips = HBoxContainer.new()
	_enemy_chips.add_theme_constant_override("separation", 4)
	section.add_child(_enemy_chips)

	# Intent panel: the single most important thing on screen.
	var intent_panel := PanelContainer.new()
	var sb := UITheme.flat(UITheme.PANEL2, UITheme.EMBER, 0, 7, 9)
	sb.border_width_left = 2
	intent_panel.add_theme_stylebox_override("panel", sb)
	var ib := VBoxContainer.new()
	ib.add_theme_constant_override("separation", 1)
	intent_panel.add_child(ib)
	ib.add_child(UITheme.body("INTENT", UITheme.COLD, 10))
	_intent_label = UITheme.body("", UITheme.FLARE, UITheme.FS_BODY)
	ib.add_child(_intent_label)
	section.add_child(intent_panel)

	var wrap := Widgets.panel_with(section)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return wrap

func _build_overlay() -> void:
	_overlay = PanelContainer.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
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

# ------------------------------------------------------------------- refreshing

func _refresh_all() -> void:
	_refresh_player()
	_refresh_enemy()
	_refresh_hand()

func _refresh_player() -> void:
	for c in _player_stats.get_children():
		c.queue_free()
	_player_stats.add_child(Widgets.stat("hull", "%d / %d" % [Run.hp, Run.max_hp()]))
	var heat_colour := UITheme.FLARE if Run.heat > Run.heat_cap() else UITheme.ICE
	_player_stats.add_child(Widgets.stat("heat",
		"%d / %d" % [Run.heat, Run.heat_cap()], heat_colour))
	_player_stats.add_child(Widgets.stat("energy",
		"%d / %d" % [combat.energy, Run.reactor()]))

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
	var e := combat.enemy
	_enemy_name.text = e.template.name.to_upper()
	_enemy_tag.text = "%s · danger %d" % [e.template.tag, Run.node_at().danger]
	_enemy_hp.text = "hull %d / %d" % [e.hp, e.max_hp]
	_enemy_bar.max_value = e.max_hp
	_enemy_bar.value = e.hp
	for c in _enemy_chips.get_children():
		c.queue_free()
	if e.block > 0:
		_enemy_chips.add_child(Widgets.chip("block %d" % e.block, Color("#3a4a6e")))
	if e.armor > 0:
		_enemy_chips.add_child(Widgets.chip("armor %d" % e.armor, Color("#3a5a6e")))
	if e.intent != null:
		_intent_label.text = "%s — %s" % [e.intent.name, e.intent.text]
	_enemy_art.set_enemy(e, e.intent != null and e.intent.telegraph)

func _refresh_hand() -> void:
	for c in _hand_box.get_children():
		c.queue_free()
	for i in combat.hand.size():
		var card := combat.hand[i]
		var view := CardView.new()
		_hand_box.add_child(view)
		view.setup(card, combat.can_play(card))
		view.chosen.connect(_on_card_chosen)
	_deck_label.text = "deck %d · discard %d · turn %d" % [
		combat.deck.size(), combat.discard.size(), combat.turn]
	_end_button.disabled = combat.finished

func _on_card_chosen(view: CardView) -> void:
	var index := combat.hand.find(view.card)
	if index < 0:
		return
	combat.play(index)

func _on_end_turn() -> void:
	combat.end_turn()

func _on_flee() -> void:
	combat.flee()

func _on_damage(amount: int, to_player: bool) -> void:
	if amount <= 0:
		return
	# Small shake sells the hit without needing animation assets.
	var target: Control = _ship_view if to_player else _enemy_art
	var origin := target.position
	var tw := create_tween()
	for i in 3:
		tw.tween_property(target, "position",
			origin + Vector2(randf_range(-3, 3), randf_range(-2, 2)), 0.03)
	tw.tween_property(target, "position", origin, 0.05)

func _on_combat_ended(result: StringName, text: String) -> void:
	var titles := {
		&"victory": "TARGET DESTROYED",
		&"pacified": "CALF PACIFIED",
		&"fled": "DISENGAGED",
		&"won": "THE FARLIGHT",
		&"dead": "RUN ENDED",
	}
	_overlay_title.text = String(titles.get(result, "COMBAT ENDED"))
	_overlay_body.text = text
	_overlay.visible = true
	_end_button.disabled = true

func _on_continue() -> void:
	_overlay.visible = false
	Router.after_combat(combat)
