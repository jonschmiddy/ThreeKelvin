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
## The options this system is offering, one row each.
var _options_box: VBoxContainer
## Which group the pointer is over, or &"". Drives RULING 1b's preview.
var _hover_group: StringName = &""
## And which ROW in it, because the hovered option is the one thing in the box
## that must NOT dim -- it is the row doing the closing.
var _hover_index: int = -1
## How tall the drawer is, and therefore how tall the viewport is not.
##
## 170 of 540, so the system keeps a little over two thirds. FIXED rather than
## sized to content on purpose: the drawer holds three different things -- the
## list, one option, one result -- and if it resized between them the viewport
## would jump on every click. A view that moves while you are reading it is the
## thing this layout exists to stop.
##
## THE HAND USES IT TOO, so a fight is a clean swap: the system does not resize
## when something starts shooting. 170 rather than a cleaner quarter because a
## card is 160 tall and the hand reserves 164 -- below that the cards have to
## hang out of the band, and a number both panels can actually hold is worth
## more than the extra 35 pixels of sky.
const DRAWER_H := 170

## What the drawer is showing.
##
## LIST -> OPTION -> RESULT -> LIST, and a fight is just a RESULT that happens on
## another screen before landing back on LIST -- `after_combat` returns to the
## sector, and a rebuilt drawer defaults here.
##
## THIS IS WHERE RULING 2 LIVES NOW. It said prose plus a check earns its own
## screen, for pacing: prose you cannot avoid stops being read. The drawer does
## that job without the swap -- the list gives one line, and the body only
## appears once you have chosen to look. `EventScreen` is off the option path.
enum Drawer { LIST, OPTION, RESULT }
var _dstate: Drawer = Drawer.LIST
## Which option the drawer has open, or -1.
var _open: int = -1
## The outcome being shown, and what the roll said about it.
var _res: Dictionary = {}
var _res_band: SkillCheck.Band = SkillCheck.Band.MET
var _res_checked: bool = false
var _res_got: String = ""
## The box the drawer's contents are rebuilt into.
var _drawer: VBoxContainer

## Outcome prose for options taken THIS VISIT, keyed by option index.
##
## Screen-local on purpose. Beat 5 has a resolved row become its outcome text,
## and persisting that prose across a save would be a save-format change for a
## sentence -- so a row taken while you are standing here shows what happened,
## and a row taken before a reload shows that it is taken. `MapNode.taken` is
## the fact; this is only the telling of it.
var _outcomes: Dictionary = {}
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
	# `arena` above expands, so pinning this pins the viewport at the remainder
	# without either of them having to know about the split.
	_drawer = VBoxContainer.new()
	_drawer.add_theme_constant_override("separation", 3)
	_quiet_wrap = Widgets.panel_with(_drawer)
	_quiet_wrap.custom_minimum_size = Vector2(0, DRAWER_H)
	_quiet_wrap.size_flags_vertical = Control.SIZE_SHRINK_END
	return _quiet_wrap


# -------------------------------------------------------------------- drawer


## Put the right thing in the drawer.
func _rebuild_drawer(n: MapGen.MapNode) -> void:
	Widgets.clear(_drawer)
	_size_drawer(n)
	if Run.dead:
		_drawer_simple("Nothing on this hull answers any more.", "SUMMARY")
		return
	if Run.hellbender_alive() and Run.hellbender_at == n.index:
		_drawer_simple("The Hellbender rides at anchor here, holds glowing with everything it has taken. Nothing else in this system is reachable past it.",
			"ENGAGE THE HELLBENDER")
		return
	if n.type != MapGen.NodeType.SYSTEM:
		var lines := _quiet_lines(n)
		_drawer_simple(String(lines[0]), String(lines[1]))
		return
	match _dstate:
		Drawer.OPTION: _drawer_option(n)
		Drawer.RESULT: _drawer_result(n)
		_: _drawer_list(n)


## How tall the drawer is for this place.
##
## THE START IS THE ONE EXCEPTION and it is deliberately narrow. Every other
## place gets the fixed `DRAWER_H`, because the drawer swaps between a list, an
## option and a result and a band that resized between them would make the
## viewport jump on every click. The start swaps between nothing: it says one
## line, offers one button, and you leave. A hundred and seventy pixels of panel
## holding forty of content is just a hole under the ship.
##
## Costs one resize, on the first jump of a run, between a screen you see once
## and every screen after it. That is a fair price for not opening the game on a
## mostly empty box -- and it is the FIRST thing anybody sees.
func _size_drawer(n: MapGen.MapNode) -> void:
	var start := n != null and n.type == MapGen.NodeType.START and not Run.dead
	_quiet_wrap.custom_minimum_size = Vector2(0, 0 if start else DRAWER_H)
	# The panel's own padding has to come down with it, or twelve above and
	# twelve below is most of what is left.
	_quiet_wrap.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 6 if start else 12, 12))


## A place with exactly one thing to do: a station, a pulsar, the core.
func _drawer_simple(line: String, label: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var t := UITheme.body(line, UITheme.CHILL, UITheme.FS_SMALL)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(t)
	var b := Widgets.button(label, _on_action)
	# 150, not 210. It was sized to balance a drawer that was mostly empty around
	# it; against a bar the width of its own label it read as a slab.
	b.custom_minimum_size = Vector2(150, 24)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	_drawer.add_child(row)


## Everything this system still offers, one condensed line each.
func _drawer_list(n: MapGen.MapNode) -> void:
	var left := _untaken(n)
	if left.is_empty():
		# RULING 7. Every system rolls two to four, so an empty one only ever
		# means you took it all -- a small subtraction, not a completion tick.
		_drawer_simple("Nothing else here wants anything from you.", "PLOT NEXT JUMP")
		return
	_drawer.add_child(_drawer_head("%d THING%s OUT HERE WANT%s SOMETHING FROM YOU"
		% [left.size(), "" if left.size() == 1 else "S",
			"S" if left.size() == 1 else ""]))
	var placed: Dictionary = {}
	for i in left:
		var opt := OptionTable.by_id(n.options[i])
		var g := StringName(opt.get("group", &""))
		if g != &"":
			if placed.has(g):
				continue
			placed[g] = true
			_drawer.add_child(_group_strip(n, g, left))
		else:
			_drawer.add_child(_list_row(n, i, opt))


## The drawer's top line, with the way out parked on its right.
##
## Departure is on screen in EVERY state, which is what RULING 9 rests on: no
## option can pretend to be a wall while the exit is visible from inside it.
func _drawer_head(text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UITheme.body(text, UITheme.COLD, UITheme.FS_SMALL)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var b := Widgets.button("PLOT NEXT JUMP", _on_action)
	b.custom_minimum_size = Vector2(148, 17)
	row.add_child(b)
	return row


## One condensed option: a stripe, its name, a line of body, and its hardest number.
func _list_row(n: MapGen.MapNode, i: int, opt: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 21)
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.pressed.connect(func() -> void:
		_open = i
		_dstate = Drawer.OPTION
		_refresh())
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var bar := ColorRect.new()
	bar.color = _tag_colour(opt)
	bar.custom_minimum_size = Vector2(3, 0)
	row.add_child(bar)
	var nm := UITheme.body(String(opt.get("title", "")).to_upper(),
		UITheme.ICE, UITheme.FS_SMALL)
	nm.custom_minimum_size = Vector2(148, 0)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(nm)
	var lead := UITheme.body(_first_sentence(String(opt.get("body", ""))),
		UITheme.COLD, UITheme.FS_SMALL)
	lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead.clip_text = true
	lead.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lead)
	# ALWAYS PRESENT, EVEN WHEN EMPTY. The lead above expands into whatever is
	# left, so a row with no number let its prose run further than a row with
	# one -- three rows clipping at three different x positions, which reads as
	# broken text rather than as a column. Reserving the width makes the ragged
	# edge a straight one.
	var hint := _row_hint(n, opt)
	var h := UITheme.body(String(hint[0]), hint[1] as Color, UITheme.FS_SMALL)
	h.custom_minimum_size = Vector2(196, 0)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.clip_text = true
	row.add_child(h)
	return b


## The one number a condensed row is allowed.
##
## A row that printed every band would be the detail view with worse spacing, so
## it shows the hardest thing about the option: what is waiting if it opens a
## fight, else its check, else what it costs.
func _row_hint(n: MapGen.MapNode, opt: Dictionary) -> Array:
	for c in opt.get("choices", []):
		if bool((c as Dictionary).get("fight", false)):
			return [_contact_reading(n).to_upper(), UITheme.THEM]
	var chk := _lead_check(opt)
	if not chk.is_empty():
		# THE SHORT FORM: what it wants, and the odds. `SkillCheck.badge` also
		# carries "you have N" and "one more: X%", and both of those are for the
		# moment you are DECIDING -- in a list they overran the column and clipped
		# the attribute name off the front, which is the one part the badge exists
		# to show. The full badge is on the choice button in the OPTION state.
		return ["%s %d · %d%%" % [SkillCheck.attr_name(chk).to_upper(),
			int(chk.get("need", 0)), int(round(SkillCheck.odds(chk) * 100.0))],
			SkillCheck.badge_colour(chk)]
	for c2 in opt.get("choices", []):
		var cd := c2 as Dictionary
		if cd.has("cost_credits"):
			var cost := int(cd.cost_credits)
			return ["%d CREDITS" % cost,
				UITheme.EMBER if Run.credits >= cost else UITheme.FLARE]
	return ["", UITheme.COLD]


## An exclusive set, bracketed.
##
## RULING 1: you see what a choice forecloses while you are still deciding. In a
## drawer this has to be cheap -- a bordered strip and two words, not a box with
## a caption, because there are only a hundred and thirty-five pixels of it.
func _group_strip(n: MapGen.MapNode, g: StringName, left: Array) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.add_child(UITheme.body("ONE ONLY", UITheme.EMBER, UITheme.FS_SMALL))
	for i in left:
		var opt := OptionTable.by_id(n.options[i])
		if StringName(opt.get("group", &"")) != g:
			continue
		col.add_child(_list_row(n, i, opt))
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.PANEL2, UITheme.EMBER.darkened(0.5), 0, 5, 2))
	wrap.add_child(col)
	return wrap


## The option you clicked, with its choices.
func _drawer_option(n: MapGen.MapNode) -> void:
	var opt: Dictionary = OptionTable.by_id(n.options[_open]) if _open >= 0 \
		and _open < n.options.size() else {}
	if opt.is_empty():
		_dstate = Drawer.LIST
		_drawer_list(n)
		return
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var back := Widgets.button("<  BACK", func() -> void:
		_dstate = Drawer.LIST
		_open = -1
		_refresh())
	back.custom_minimum_size = Vector2(70, 17)
	head.add_child(back)
	var t := UITheme.body(String(opt.get("title", "")).to_upper(),
		UITheme.HOT, UITheme.FS_SMALL)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(t)
	var jb := Widgets.button("PLOT NEXT JUMP", _on_action)
	jb.custom_minimum_size = Vector2(148, 17)
	head.add_child(jb)
	_drawer.add_child(head)
	# THE FULL BODY, and this is the only place it appears. The list showed one
	# sentence of it; the rest is what looking buys.
	var body := UITheme.body(String(opt.get("body", "")), UITheme.CHILL,
		UITheme.FS_SMALL)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_drawer.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var choices: Array = opt.get("choices", [])
	for j in choices.size():
		row.add_child(_choice_button(n, _open, j, choices[j] as Dictionary, opt))
	_drawer.add_child(row)


## What happened, until you accept it.
func _drawer_result(n: MapGen.MapNode) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	# NAME THE BAND. The prose is written in fiction and deliberately never says
	# "you failed", so without this a PARTIAL and a BOTCHED are two paragraphs
	# you cannot tell apart and the ladder never resolves where you can see it.
	if _res_checked:
		head.add_child(UITheme.body(SkillCheck.band_name(_res_band),
			SkillCheck.band_colour(_res_band), UITheme.FS_SMALL))
	else:
		head.add_child(UITheme.body("RESOLVED", UITheme.COLD, UITheme.FS_SMALL))
	if _res_got != "":
		head.add_child(UITheme.body(_res_got.to_upper(), UITheme.GOOD,
			UITheme.FS_SMALL))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_drawer.add_child(head)
	var text := UITheme.body(String(_res.get("text", "")), UITheme.HOT,
		UITheme.FS_SMALL)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_drawer.add_child(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp2)
	if Run.dead:
		row.add_child(Widgets.button("…", func() -> void: Router.show_game_over()))
	elif bool(_res.get("fight", false)):
		# LIST -> FIGHT -> RESULT -> LIST. The fight is a screen of its own and
		# then `after_combat` returns to the sector, where a rebuilt drawer
		# defaults to LIST with this option already spent.
		var f := Widgets.button("THEY ARE ALREADY FIRING", func() -> void:
			Router.start_ambush())
		f.custom_minimum_size = Vector2(210, 22)
		row.add_child(f)
	else:
		var c := Widgets.button("CONTINUE", func() -> void:
			_dstate = Drawer.LIST
			_open = -1
			_res = {}
			_refresh())
		c.custom_minimum_size = Vector2(148, 22)
		row.add_child(c)
	_drawer.add_child(row)


## Which options this system still has.
func _untaken(n: MapGen.MapNode) -> Array:
	var out: Array = []
	for i in n.options.size():
		if OptionTable.by_id(n.options[i]).is_empty():
			continue
		if not n.taken.has(MapGen.OPTION_SITE + i):
			out.append(i)
	return out


## What a tag reads as at three pixels wide. A fight is a threat, salvage is a
## wreck, a signal is somebody talking.
func _tag_colour(opt: Dictionary) -> Color:
	for t in opt.get("tags", []):
		match StringName(t):
			&"fight": return UITheme.LEAVE
			&"salvage": return Color("#9a7b52")
			&"signal": return Color("#8ec8e6")
	return UITheme.LINE
func _choice_button(n: MapGen.MapNode, i: int, j: int, c: Dictionary,
		opt: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	var b := Widgets.button(String(c.get("label", "…")).to_upper(),
		func() -> void: _take(n, i, j))
	b.custom_minimum_size = Vector2(150, 22)
	# RULING 8: an unaffordable hard gate greys and says by how much. A gate is a
	# meter payment and 40 credits genuinely is not 60 -- but a disabled thing
	# still says what it wants and how far off you are.
	var note := ""
	var tone := UITheme.COLD
	# A GATE ON WHAT YOU ARE CARRYING, not on what you can pay. `holding_pattern`
	# trades an exotic-tier item to a queue that has been waiting long enough to
	# want one, and the handoff asked for the choice to be HIDDEN if this could
	# not land tonight. Greying it is better and costs the same: RULING 8 already
	# says a disabled thing states what it wants and how far off you are, and a
	# hidden row teaches the player nothing about why the trade was possible the
	# last time they saw it.
	if c.has("needs_material"):
		var mid := StringName(c.needs_material)
		var have := Run.material(mid)
		note = "1 %s · you have %d" % [String(mid), have]
		if have < 1:
			b.disabled = true
			tone = UITheme.FLARE
	elif c.has("cost_credits"):
		var cost := int(c.cost_credits)
		note = "%d credits · you have %d" % [cost, Run.credits]
		if Run.credits < cost:
			b.disabled = true
			tone = UITheme.FLARE
	elif c.has("check"):
		# RULING 3: the odds are on the button, so there is no confirm step. A
		# dialog after showing 40% asks the same question twice and teaches the
		# player the number was not the commitment.
		note = SkillCheck.badge(c.check)
		tone = SkillCheck.badge_colour(c.check)
	elif bool(c.get("fight", false)) or _opens_fight(c):
		note = _contact_reading(n)
		tone = UITheme.THEM
	col.add_child(b)
	if note != "":
		col.add_child(UITheme.body(note, tone, UITheme.FS_SMALL))
	return col


## RULING 5 — what a fight row prints, and it is something the player bought.
##
## Every other row prints a number and this one printed nothing until the fight
## started. A flat enemy count spoils a reveal worth keeping; leaving it bare is
## inconsistent. So it is `chart_from()` one scale down: the dish already tells
## you WHERE things are, and a better dish tells you WHAT they are.
##
## It also finally gives SENSORS something to do outside event checks -- its
## attribute row prints an empty effect string today because nothing reads it.
func _contact_reading(n: MapGen.MapNode) -> String:
	var s := Run.attr_sensors()
	if s < 3:
		return "Fight."
	var pack := Router._roll_foes(n)
	if pack.is_empty():
		return "Fight."
	if s < 6:
		return "Fight · %d %s" % [pack.size(),
			"contact" if pack.size() == 1 else "contacts"]
	# One adjective, not a build readout. Composition starts to read the enemy's
	# loadout, which is closer to a combat preview than a chart reading -- see
	# ENCOUNTER_FLOW.md 7, which asks for count first and a measurement before
	# going further.
	var hot: String = String(DB.enemies[pack[0]].name).to_lower()
	return "Fight · %d %s, one of them a %s" % [pack.size(),
		"contact" if pack.size() == 1 else "contacts", hot]


## Does this choice SAY it leads to a fight?
##
## The declaration, not the trigger -- see the note on `hostile_contact`. A list
## has to print its reading before the click, and the trigger only exists after
## the callable has run.
func _opens_fight(c: Dictionary) -> bool:
	return bool(c.get("fight", false))
func _lead_check(opt: Dictionary) -> Dictionary:
	var found: Dictionary = {}
	var count := 0
	for c in opt.get("choices", []):
		if not (c as Dictionary).has("check"):
			continue
		count += 1
		found = (c as Dictionary).check
	return found if count == 1 else {}


## One line of body for the list. The rest lives in the detail view.
func _first_sentence(body: String) -> String:
	var cut := body.find(". ")
	if cut < 0:
		return body
	return body.substr(0, cut + 1)


## Take one choice where it stands.
func _take(n: MapGen.MapNode, i: int, j: int) -> void:
	var opt := OptionTable.by_id(n.options[i])
	var choices: Array = opt.get("choices", [])
	if j < 0 or j >= choices.size():
		return
	var c: Dictionary = choices[j]
	if c.has("cost_credits") and Run.credits < int(c.cost_credits):
		return
	if c.has("needs_material") and Run.material(StringName(c.needs_material)) < 1:
		return
	_res_checked = c.has("check")
	_res_band = SkillCheck.Band.MET
	var call: Callable = c.get("effect", Callable())
	if _res_checked:
		_res_band = SkillCheck.roll(c.check)
		call = SkillCheck.pick_outcome(c, _res_band)
	if c.has("cost_credits"):
		Run.add_credits(-int(c.cost_credits))
	var res: Dictionary = call.call() if call.is_valid() else {}
	if typeof(res) != TYPE_DICTIONARY:
		res = {}
	_res = res
	_res_got = OptionTable.pay(res, n)
	_outcomes[i] = String(res.get("text", ""))
	# SPENT NOW, NOT ON CONTINUE. The result is already applied -- credits moved,
	# hull taken, a module in the hold -- so a player who closed the game on the
	# result screen must not come back to an option they have already been paid
	# for. `option_resolved` is the same bookkeeping the old path used.
	Router.option_resolved(i)
	if Run.dead:
		Router.show_game_over()
		return
	_dstate = Drawer.RESULT
	_refresh()

func _on_action() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if Run.dead:
		Router.show_game_over()
		return
	# While the hellbender holds the system it IS the one thing this place offers —
	# same blockade the arrival path enforces in Router.resolve_current_node().
	if Run.hellbender_alive() and Run.hellbender_at == n.index:
		Router.engage_hellbender()
		return
	match n.type:
		MapGen.NodeType.STATION:
			Router.show_station()
		# The rows are the options now, so the button under them only ever leaves.
		MapGen.NodeType.SYSTEM:
			Router.show_starchart()
		MapGen.NodeType.PULSAR:
			if n.cleared:
				Router.show_starchart()
			else:
				Router.harvest_pulsar()
		# A contact you have not fought yet. For FIGHT that is a resumed run —
		# arriving at one normally starts the fight before this screen draws. For
		# CORE it is the ORDINARY path: the core is a place you arrive at and
		# then commit to, so a party can be at it together. See
		# Router.resolve_current_node().
		MapGen.NodeType.CORE:
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
	if Run.hellbender_alive() and Run.hellbender_at == n.index:
		return ["The Hellbender rides at anchor here, holds glowing with everything it has taken. Nothing else in this system is reachable past it.",
			"ENGAGE THE HELLBENDER"]
	match n.type:
		MapGen.NodeType.STATION:
			return ["A hab ring turns slowly, lights on. They will trade, repair and refuel — all of it out of the same pocket.", "DOCK"]
		MapGen.NodeType.SYSTEM:
			if n.eaten:
				return ["Cut open along the spine, and the cuts are fresh. The Hellbender fed here first.", "PLOT NEXT JUMP"]
			# THE LIST SAYS WHAT IS HERE; this line only says where you are. It
			# used to name a button -- LOOK -- because a system opened one thing
			# at a time, and the button is now every row below.
			var left := 0
			for i in n.options.size():
				if not n.taken.has(MapGen.OPTION_SITE + i):
					left += 1
			if n.cleared or left <= 0:
				# RULING 7. Every system rolls two to four options, so an empty one
				# only ever means you took it all -- and in a setting whose premise
				# is extraction from a universe running down, that is not a
				# completion tick. A small subtraction, which is also simply true.
				return ["Nothing else here wants anything from you.", "PLOT NEXT JUMP"]
			return ["The lane is quiet and the board is not.", "PLOT NEXT JUMP"]
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
		MapGen.NodeType.CORE:
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
	# Big enough to read as a card rather than as an icon of one.
	#
	# WAS 86, WHICH THE BAND CAN NO LONGER HOLD. The old note read "the hand row
	# is 160 tall to fit a card, so there was height going spare either side" --
	# and the spare is gone now the band is a fixed 170 shared with the drawer.
	# At 86 the left rail came to about 179 and pushed the whole panel past the
	# drawer it is supposed to swap with.
	const W := 60
	# 52 IS THE CEILING, swept rather than guessed: the band is a fixed 170 shared
	# with the drawer, and `-- sectorshot` reports 171 at 53 and 175 at 57. Every
	# pixel this gains comes straight off the panel it has to fit inside.
	#
	# It has come down from 86 in three steps, each paying for something the rail
	# gained -- the fixed band, then the stack's lean, then the air under the
	# label. If it needs to be bigger the room has to come from somewhere else in
	# the column, because there is none here.
	const H := 52
	var count: int = 0
	var label: String = ""

	func _init() -> void:
		# H, plus the four the stack leans by, plus room for the label under it,
		# plus the same gap under THAT as the rails carry above them -- the piles
		# are the last thing in each column and sat flush against the panel edge
		# while everything above them had six of air.
		custom_minimum_size = Vector2(W, H + 16 + SectorScreen.RAIL_DROP)
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
			# INSIDE ITS OWN BOX. This was `-i * 2`, which drew the cards behind
			# the front one ABOVE y=0 -- outside the control, over whatever sits
			# above it. On the right rail that is FLEE, so a discard pile with
			# anything in it painted across the button.
			#
			# The stack still leans up and to the right; the whole thing is just
			# offset down by as far as it leans, so the deepest card starts at
			# zero instead of the front one.
			var o := Vector2(i * 2, float(shown - 1 - i) * 2.0)
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
			draw_rect(Rect2(Vector2(0, 4), Vector2(W, H)), Color("#1b2430"), false, 1.0)

		var f := UITheme.pixel_font()
		var n := str(count)
		var nw := f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_HEAD).x
		# The count rides the FRONT card, which is now four lower than the box.
		draw_string(f, Vector2((W - nw) * 0.5 + 1, H * 0.5 + 11), n,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_HEAD, UITheme.ICE)
		var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
		draw_string(f, Vector2((W - lw) * 0.5, H + 14), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, UITheme.COLD)

## How far the rails sit below the top of the band.
##
## A card's frame starts at the very top of the panel and its CONTENT starts a
## few pixels in, so rails flush with the frame read as sitting higher than the
## cards they flank. Six is the difference, and it is paid for out of the pile
## rather than added to the band -- 170 is shared with the drawer and there is no
## slack in it.
const RAIL_DROP := 6


## The gap at the top of each rail. Both get it, or they stop being a pair.
func _rail_drop() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, RAIL_DROP)
	return c


func _build_hand() -> PanelContainer:
	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 6)
	# Everything you spend on the left, everything you end with on the right,
	# and the cards in between. Energy sits at the top of the left column
	# because it is the number you check before choosing a card, not after.
	# TOP-ALIGNED, BOTH OF THEM. Centred, each column centres against its OWN
	# height -- and the left carries a chip row the right does not -- so the
	# pairs that are meant to read across the panel drifted apart by more the
	# further down you looked. ENERGY/END TURN, TURN/FLEE and the two piles are
	# the same three rows on both sides, and now they start at the same y.
	var left := VBoxContainer.new()
	# Three, not four: the drop above costs a gap of its own, and four across
	# five children pushed the band to 172 against the drawer's 170.
	left.add_theme_constant_override("separation", 3)
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.add_child(_rail_drop())

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
	right.add_theme_constant_override("separation", 3)
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	right.add_child(_rail_drop())

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

	# THE CHIP ROW'S OPPOSITE NUMBER. The left column spends `CHIP_ROW_H` on
	# your brace, block and lock-on; without the same gap here the discard pile
	# sits that much higher than the draw pile and the two columns stop being
	# columns. Empty on purpose -- the enemy's chips live in their own strip.
	var chip_gap := Control.new()
	chip_gap.custom_minimum_size = Vector2(0, CHIP_ROW_H)
	right.add_child(chip_gap)

	_discard_pile = PileView.new()
	right.add_child(_discard_pile)
	hand_row.add_child(right)
	_hand_wrap = Widgets.panel_with(hand_row)
	# THE SAME HEIGHT AS THE DRAWER, so a fight is a clean swap. The two panels
	# are mutually exclusive and occupy the same band; matching them means the
	# system above does not resize the moment something starts shooting, which is
	# the one frame where a viewport jumping would be most obvious.
	#
	# AND THE PADDING HAD TO GIVE. `custom_minimum_size` is a floor, not a
	# ceiling: the hand reserves a card's height plus four, and `panel_with`'s
	# default 12 above and below took that to 188 against the drawer's 170. The
	# measurement is why this is 3 rather than a guess -- 164 + 6 is exactly the
	# band, and any more padding puts the cards back through the ceiling.
	_hand_wrap.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 3, 12))
	_hand_wrap.custom_minimum_size = Vector2(0, DRAWER_H)
	_hand_wrap.size_flags_vertical = Control.SIZE_SHRINK_END
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
		_rebuild_drawer(n)

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
		# THE SHIP'S HALF INCLUDED. This is the preview a player reads at the
		# moment of committing a card, and without the dissipation term it
		# under-reports every vent card by the whole radiator.
		bits.append("-%d HEAT" % mini(c.vent + Run.dissipation(), Run.heat))
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
