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
## The window onto the list. THE RAIL HAS A CEILING NOW, and the bug it fixes is
## not a scrolling bug — it is a layout one.
##
## A `PanelContainer` takes its minimum size from its child, and the child was a
## `VBoxContainer` holding one panel per part in the hold. Six parts out of a
## lawless run came to well over a screen, the rail's minimum grew past the
## viewport, and because it sits in the arena — which is the expanding row of the
## root column — the whole page grew with it. The hand strip and the quiet strip
## were pushed off the bottom, and the sector was unplayable until the hold was
## emptied from another screen.
##
## A ScrollContainer's minimum height does NOT track its content, so the rail now
## asks for a fixed, small amount of room and gives the overflow a scrollbar.
var _salvage_scroll: ScrollContainer
## STOW and JETTISON, built once and kept out of the scrolling region. They are
## the way to close this panel, so they must never be the thing you have to
## scroll to reach.
var _salvage_actions: HBoxContainer
## The rail's heading. Two things share this panel and they are not the same
## question: a BAG is loot nobody owns yet and a HOLD is loot you are carrying.
var _salvage_head: Label
## True while a TAKE is out at the host and has not been answered.
##
## One click at a time. `take_from_bag()` awaits a round trip, and a second click
## landing inside that window would put two requests in the air for a hold with
## one slot left in it — the answer to the first is what decides whether the
## second is even legal.
var _taking: bool = false
## Dismissed for now, not thrown away. See RunState.salvage_hushed_hauls — the
## flag lives there because THIS SCREEN IS REBUILT ON EVERY JUMP and a dismissal
## kept here was forgotten the moment you left.


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
## Every keyword panel is parented HERE and nowhere else, and opening one empties
## it first.
##
## "At most one readout on screen" used to be an invariant three suspended
## coroutines had to maintain between them — the rest timer, the layout frame and
## whichever hover event arrived while those were waiting — each holding the same
## `_readout` member and each able to run while the others slept. One interleaving
## that lost track of the reference left a panel on screen that nothing owned and
## nothing would ever close, so a second one opened on top of it. A single parent
## that is swept before every open makes it a fact about the node tree instead,
## which no interleaving can break.
var _readout_host: Control = null
## Which card the panel belongs to. See _show_readout.
var _readout_for: CardView = null
## The card whose panel is counting down but has not opened yet.
var _readout_pending: CardView = null
## Bumped every time the panel is torn down. A coroutine that wakes holding a
## stale generation has been overtaken while it slept and must not touch the
## screen — not to position a panel, not to fade one in, not to leave one behind.
##
## Deliberately bumped in _clear_readout() rather than on every hover event: an
## exit for a card that does not own the panel is not an interruption, and
## cancelling on those would mean the panel never opens while the cursor is
## sliding along a fan.
var _readout_gen: int = 0
## How long you have to rest on a card before it explains itself.
const READOUT_DELAY := 1.0
## The shortest the salvage list is allowed to be. Roughly one module row, so a
## single part does not open a tall empty box — everything past that comes out of
## the arena's spare height, and everything past THAT scrolls.
const SALVAGE_MIN_H := 96
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
	# The party moved: a partner ended their turn, or shot something. The hand
	# panel carries the WAITING button and the enemy panel carries their hits.
	Sig.party_fight_changed.connect(func(_at: int) -> void:
		if fighting():
			_refresh_hand()
			_refresh_enemy())
	Sig.turn_started.connect(func(_t): _refresh())
	Sig.combat_ended.connect(_on_combat_ended)
	Sig.damage_dealt.connect(_on_damage)
	Sig.enemy_destroyed.connect(_on_enemy_destroyed)
	# Damage says how much and to whom, never with what — so the card is caught
	# on its way past and read for its material.
	Sig.card_played.connect(func(c: CardData) -> void: _last_played = c)

	_refresh()

	# Fly in. Arriving somewhere should look like arriving somewhere — the ship
	# comes in under power from the left, cuts its engines short of station and
	# coasts to a halt, then sits there breathing.
	#
	# Not during a fight. A combat sector is one you are already in the middle
	# of, and Router rebuilds this screen when the fight starts, so playing the
	# approach there would fly the ship back in mid-battle.
	if not fighting():
		var art := _view.ship_view()
		if art != null:
			art.arrive()

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

	var pad := Widgets.pad(null, 8, 6)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

## Three bands: a heading, a scrolling list, and the two buttons that dismiss it.
##
## Only the middle one scrolls, and only the middle one is rebuilt. The heading
## used to be a child of the list with a `name` on it so the refresh could tell
## it apart from a module row — that check is gone with the structure that needed
## it, which is the small win hidden inside the layout fix.
func _build_salvage_rail() -> PanelContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	_salvage_head = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	col.add_child(_salvage_head)

	_salvage = VBoxContainer.new()
	_salvage.add_theme_constant_override("separation", 3)
	_salvage.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_salvage_scroll = ScrollContainer.new()
	# Sideways scrolling would mean the rail is too NARROW, which is a different
	# bug and one this screen does not have — the rows wrap to the 268 the panel
	# asks for. Disabled so a wide row cannot quietly buy itself a second bar.
	_salvage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Takes the arena's leftover height rather than demanding its content's. This
	# line and SALVAGE_MIN_H below are the whole of the fix.
	_salvage_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_salvage_scroll.custom_minimum_size = Vector2(0, SALVAGE_MIN_H)
	_salvage_scroll.add_child(_salvage)
	col.add_child(_salvage_scroll)

	_salvage_actions = HBoxContainer.new()
	_salvage_actions.add_theme_constant_override("separation", 4)
	# Stowing keeps everything. The hold is unlimited, so nothing here should
	# destroy salvage by default.
	var stow := Widgets.button("STOW - DECIDE LATER",
		func() -> void:
			Run.salvage_hushed_hauls = Run.hauls
			Run.salvage_hushed_bag = _bag_here()
			_refresh())
	stow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stow.tooltip_text = Widgets.tip("Keeps it all in the hold. Fit or scrap it from the SHIP page.")
	_salvage_actions.add_child(stow)
	var dump := Widgets.button("JETTISON",
		func() -> void:
			Run.cargo.clear()
			Run.found_hull = null
			_refresh())
	dump.tooltip_text = Widgets.tip("Destroys everything in the hold. There is no reason to do this.")
	_salvage_actions.add_child(dump)
	col.add_child(_salvage_actions)

	_salvage_wrap = Widgets.panel_with(col)
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
		# A contact you have not fought yet. For FIGHT that is a resumed run —
		# arriving at one normally starts the fight before this screen draws. For
		# GOAL it is the ORDINARY path: the core is a place you arrive at and
		# then commit to, so a party can be at it together. See
		# Router.resolve_current_node().
		MapGen.NodeType.FIGHT, MapGen.NodeType.GOAL:
			if n.cleared or n.fled:
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
			if n.fled:
				return ["You broke contact. They are still out there, and they still have everything they were carrying.",
					"PLOT NEXT JUMP"]
			return ["Contact.", "ENGAGE"]
		MapGen.NodeType.PULSAR:
			if n.cleared:
				return ["The beam still sweeps. Nothing left aboard can hold any more of it.",
					"PLOT NEXT JUMP"]
			return ["A neutron star, turning eleven times a second. Its wind is the densest fuel in the galaxy and its beam will cook you through the hull. Close enough to scoop is close enough to die.",
				"FLY THE BEAM"]
		MapGen.NodeType.START:
			return ["Open space, and the reactor holding. The core is a long way in from here.", "PLOT NEXT JUMP"]
		# The core, waiting. Arriving here no longer opens the fight, so this is
		# what the screen says while the party gathers and somebody decides to
		# commit — the line above the button has to name what pressing it does.
		MapGen.NodeType.GOAL:
			if n.cleared:
				return ["The light is behind you.", "PLOT NEXT JUMP"]
			if n.fled:
				return ["You broke off. It is still between you and the light.", "PLOT NEXT JUMP"]
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
## The height the player's status chip row holds whether or not it has chips in
## it. See where it is built for what happens without it.
##
## 18, MEASURED. A chip is a PanelContainer around 10px text with 2px of padding
## and a border, and it renders 18 rows tall — not the 16 the arithmetic
## suggested. Reserving 16 changed nothing at all, because the chip was still
## the taller of the two and the row sized to it: the hand sat at y=690 with no
## chips and y=654 with one, either way.
const CHIP_ROW_H := 18

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

	# Your own status, under your own numbers. Brace, block, lock-on, feedback,
	# adapt and drones are things you are carrying, so they belong beside the
	# energy you spend rather than in a strip about the enemy.
	_player_chips = HBoxContainer.new()
	_player_chips.add_theme_constant_override("separation", 3)
	_player_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	# HOLDS ITS HEIGHT WHILE EMPTY. An HBox with no children is zero rows tall,
	# so the first chip of the fight grew this column, grew the hand row with
	# it, and shoved every card in your hand upward — mid-turn, while you were
	# reading them. It reads as the hand jumping for no reason, and the reason
	# it seems to happen "around three discards" is that armour comes from
	# Brace and Reinforce, which are also what put those cards in the pile.
	#
	# A chip is 10px of text plus 2px of padding either side; 16 is that with a
	# pixel to spare, measured rather than guessed.
	_player_chips.custom_minimum_size = Vector2(0, CHIP_ROW_H)
	left.add_child(_player_chips)

	_draw_pile = PileView.new()
	left.add_child(_draw_pile)
	hand_row.add_child(left)

	_hand = HandView.new()
	_hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand.card_hovered.connect(_on_card_hovered)
	_hand.picked.connect(_on_card_picked)
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
	_view.set_place(n)

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

## The system index if there is loose salvage here, or -1. The second half of
## what a dismissal is keyed on.
func _bag_here() -> int:
	var n: MapGen.MapNode = Run.node_at()
	return n.index if Run.bag_left(n) > 0 else -1


func _refresh_salvage() -> void:
	Widgets.clear(_salvage)
	# One deck build for the whole list, handed to every row — see Widgets.module_row.
	var deck := DeckBuilder.build().size()

	var n: MapGen.MapNode = Run.node_at()
	var loose := Run.bag_left(n)
	var mine := Run.cargo.size() > 0 or Run.found_hull != null
	var bag_here := n.index if loose > 0 else -1

	# STAYS DISMISSED ACROSS A JUMP. The state lives on `Run` because this screen
	# does not survive one — see RunState.salvage_hushed_hauls.
	#
	# It stops being dismissed when there is something NEW to decide about: a
	# fresh haul, or a bag at a system you have not stood over yet. Watching
	# `cargo.size()` instead of `hauls` was right until the refit screen learned
	# to drag a part off a hardpoint into the hold — that grows the hold too, so
	# unbolting your own coolant line made this panel offer it back as salvage.
	var hushed := Run.salvage_hushed(bag_here)
	var has := (loose > 0 or mine) and not fighting()
	_salvage_wrap.visible = has and not hushed
	if not _salvage_wrap.visible:
		return

	# The bag names itself, because the rule is not obvious from looking at it
	# and it is the rule that matters: the parts are not yours yet, and they stop
	# being available the moment somebody reaches for one.
	_salvage_head.text = "SALVAGE - ONE BAG, FIRST HAND IN" if loose > 0 \
		else "SALVAGE - STOW IT OR FIT IT"

	# What the kill left, before what you are already carrying. Loose parts are
	# the only thing on this panel with a clock on them.
	for i in n.bag.size():
		if n.taken.has(MapGen.OPTION_BAG + i):
			# Kept on screen rather than dropped out of the list. A part that
			# vanishes reads as a part that was never there; a part with somebody
			# else's name on it is the whole texture of flying together, and it
			# is the same argument `MapGen.OPTION_SHOP` makes about a sold shelf.
			var who := Net.taker_name(n.index, MapGen.OPTION_BAG + i)
			_salvage.add_child(Widgets.module_row(n.bag[i],
				Widgets.ModuleContext.BAG, 0, _on_salvage,
				"%s TOOK THIS" % who.to_upper() if who != "" else "TAKEN", deck))
			continue
		# No price on a bag. You already paid for it by being in the fight.
		_salvage.add_child(Widgets.module_row(n.bag[i],
			Widgets.ModuleContext.BAG, 0, _on_bag, "", deck))

	if Run.found_hull != null:
		_salvage.add_child(Widgets.hull_row(Run.found_hull, "TRANSFER", 0, _on_salvage))
	for m in Run.cargo:
		_salvage.add_child(Widgets.module_row(m, Widgets.ModuleContext.CARGO, 0, _on_salvage, "", deck))


func _refresh_player() -> void:
	if not fighting():
		return
	_energy.setup(BoxGauge.Mode.ENERGY, Run.reactor(), combat.energy)
	_energy_text.text = "%d/%d" % [combat.energy, Run.reactor()]

	Widgets.clear(_player_chips)
	if combat.brace > 0:
		_player_chips.add_child(Widgets.chip("brace %d" % combat.brace, Color("#3a5a6e")))
	if combat.block > 0:
		_player_chips.add_child(Widgets.chip("block %d" % combat.block, Color("#3a4a6e")))
	if combat.lock_on > 0:
		_player_chips.add_child(Widgets.chip("lock +%d" % combat.lock_on, Color("#6e5a3a")))
	if combat.negate_next:
		_player_chips.add_child(Widgets.chip("slip ready", UITheme.GOOD))
	if combat.feedback > 0:
		_player_chips.add_child(Widgets.chip("feedback %d" % combat.feedback))
	if combat.adapt_bonus > 0:
		_player_chips.add_child(Widgets.chip("adapt +%d" % combat.adapt_bonus))
	for d in combat.drones:
		_player_chips.add_child(Widgets.chip("drone %d" % d.damage, Color("#5a7a94")))
	if combat.drone_brace > 0:
		_player_chips.add_child(Widgets.chip("wasp %d" % combat.drone_brace, Color("#5a7a94")))
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
		Widgets.clear(row)
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
	_hand.sync(combat.hand, func(c): return combat.can_play(c), combat.choosing > 0)
	# A card that left the hand takes its panel with it. The panel is closed by
	# the card's own exit event, and a card that was played or discarded never
	# sends one — its view flies off and fades on a tween, so it is not even
	# freed yet. Keyed on the HAND rather than on whether the view still exists,
	# because the question the panel answers is "what am I holding".
	if _readout_for != null and (not is_instance_valid(_readout_for)
			or not combat.hand.has(_readout_for.card)):
		_clear_readout()
	_draw_pile.set_count(combat.deck.size(), "DRAW")
	_discard_pile.set_count(combat.discard.size(), "DISCARD")
	_deck_label.text = "TURN %d" % combat.turn
	# WAITING, with a name on it. A button that greys out and says nothing is
	# indistinguishable from a hang, and in a shared fight the reason it is grey
	# is always another person — so say who.
	if combat.waiting:
		var f := Net.fight_at(combat.shared_at)
		var names := PackedStringArray()
		if f != null:
			for p2 in f.waiting_on():
				# Never yourself. You pressed the button; the local copy of the
				# fight has not heard back yet, so for one frame it still lists
				# you among the ships it is waiting for.
				if p2 == Net.local_id():
					continue
				var who := Net.name_of(p2)
				if who != "":
					names.append(who.to_upper())
		_end_button.text = "WAIT\n%s" % (names[0] if names.size() == 1
			else ("%d SHIPS" % names.size() if names.size() > 1 else "..."))
	else:
		_end_button.text = "END\nTURN"
	_end_button.disabled = combat.finished or combat.waiting

# --------------------------------------------------------------------- input

## Reaching into the bag, which is the one control on this screen that has to
## ask somebody else's machine before it can answer.
##
## `Widgets` binds the module rather than the index, so the index is recovered by
## identity — `n.bag` holds the very objects the rows were built from, and the
## array never shrinks, so `find()` is exact rather than a lookup by name.
func _on_bag(action: String, thing: Variant) -> void:
	if action != "take" or _taking:
		return
	var n: MapGen.MapNode = Run.node_at()
	var i := n.bag.find(thing)
	if i < 0:
		return
	_taking = true
	# Redrawn twice on purpose: once now so the row cannot be pressed again while
	# the answer is in the air, and once when it lands.
	_refresh()
	var got := await Run.take_from_bag(n, i)
	_taking = false
	if got:
		Audio.play(&"loot_drop")
	_refresh()

func _on_salvage(action: String, thing: Variant) -> void:
	match action:
		"install": Run.install_module(thing as ModuleData)
		"scrap": Run.scrap_module(thing as ModuleData)
		"uninstall": Run.uninstall_module(thing as ModuleData)
		"take_hull": Run.transfer_to_hull(thing as HullData)
		"leave_hull":
			Run.found_hull = null
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
	if c.brace > 0:
		bits.append("+%d BRACE" % c.brace)
	if c.brace_from_heat:
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

## A card was pointed at to satisfy a discard or a decommission.
##
## Resolved by INDEX rather than by passing the card object down, because
## Combat.choose takes an index — the same door the simulator and the bot use,
## so a choice is never something only a mouse can make.
func _on_card_picked(card: CardData) -> void:
	if combat == null or combat.choosing <= 0:
		return
	combat.choose(combat.hand.find(card))


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
## player had to already know — and Brace, Salvo and Feedback are precisely the
## words a new player does not.
##
## Floated in a layer above everything rather than placed in the hand row: the
## hand is a fixed-height panel at the bottom of the screen, so a panel parented
## into it would either resize the row or be clipped by it.
## Created on first use rather than in _build(), so the layer does not exist at
## all in a run that never rests on a card. Full-rect and click-through: it is a
## place to put panels, not a thing on the screen.
func _readout_layer() -> Control:
	if _readout_host == null or not is_instance_valid(_readout_host):
		_readout_host = Control.new()
		_readout_host.set_anchors_preset(Control.PRESET_FULL_RECT)
		_readout_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_readout_host)
	return _readout_host

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
	# Captured AFTER the clear above, so this coroutine owns the current
	# generation until something else tears the panel down. Checked rather than
	# `_readout_pending == view` at every wake-up below, because the card is not
	# a unique enough claim: rest on a card, leave, and rest on it again and
	# there are two coroutines that both think the pending card is theirs.
	var gen := _readout_gen
	await get_tree().create_timer(READOUT_DELAY).timeout
	if gen != _readout_gen or not is_instance_valid(view):
		return
	if get_viewport().gui_is_dragging():
		return

	_readout_pending = null
	_readout_for = view
	# Held locally as well as on the member. Everything after this point runs
	# across an await, and the member may belong to a newer panel by then — a
	# coroutine that positions `_readout` blind can move somebody else's panel
	# to its own card.
	var panel := Widgets.card_readout(view.card)
	_readout = panel
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Invisible until it knows where it goes.
	#
	# The panel's height depends on how much of its text wrapped, which is not
	# settled until the layout pass — so its final position cannot be computed
	# on the frame it is created. It used to be parked at the top of the screen
	# for that one frame and then moved, which is exactly the flash: a panel
	# appearing in the wrong place and jumping. Held at zero alpha, that frame
	# is simply not seen.
	panel.modulate.a = 0.0
	_readout_layer().add_child(panel)

	# Above the card, nudged to stay on screen. Above rather than beside because
	# a hand fans across the full width — there is no reliable "beside" — and
	# because the space above the hand is the one part of a combat screen that
	# is never holding anything you need while choosing a card.
	var w: float = panel.custom_minimum_size.x
	var top := view.global_position - global_position
	var px := clampf(top.x + CardView.CARD_W * 0.5 - w * 0.5, 2.0,
		maxf(2.0, size.x - w - 2.0))
	panel.position = Vector2(px, 2.0)

	await get_tree().process_frame
	if gen != _readout_gen or not is_instance_valid(panel):
		return
	var py := maxf(2.0, top.y - panel.size.y - 6.0)
	# Rises the last few pixels as it fades in. The card lifts when you point at
	# it; the panel arriving on the same vector reads as one gesture rather than
	# two things happening near each other.
	panel.position = Vector2(px, py + 5.0)
	var tw := panel.create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.14)
	tw.tween_property(panel, "position:y", py, 0.14)

func _clear_readout() -> void:
	_readout_gen += 1
	_readout_pending = null
	_readout_for = null
	_readout = null
	if _readout_host == null or not is_instance_valid(_readout_host):
		return
	for c in _readout_host.get_children():
		# Removed as well as freed. queue_free() takes effect at the END of the
		# frame, so a panel that is only queued is still on screen for the frame
		# in which its replacement is built — one frame of exactly the doubled
		# panel this is here to prevent. The sweep is over every child rather
		# than over the one the member points at, which is the whole point: a
		# panel nothing is tracking any more is still a panel on the screen.
		_readout_host.remove_child(c)
		c.queue_free()

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
	if fighting() and not combat.waiting:
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
