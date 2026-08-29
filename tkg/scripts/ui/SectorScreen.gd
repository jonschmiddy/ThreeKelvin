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
var _self_bar: ProgressBar
var _self_name: Label
var _self_plate: VBoxContainer
var _self_hp: Label
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
## The open pile listing, or null. Built and torn down per open rather than
## hidden, because its contents change every single turn.
var _pile_panel: PanelContainer = null
## The open salvage transfer, or null. See `_open_transfer`.
var _transfer: TransferView = null
var _discard_pile: PileView
var _end_button: Button
var _hail_button: Button
var _flee_button: Button
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
## 190 of 540, so the system keeps a little over two thirds. FIXED rather than
## sized to content on purpose: the drawer holds three different things -- the
## list, one option, one result -- and if it resized between them the viewport
## would jump on every click. A view that moves while you are reading it is the
## thing this layout exists to stop.
##
## THE HAND USES IT TOO, so a fight is a clean swap: the system does not resize
## when something starts shooting. 170 rather than a cleaner quarter because a
## card is 160 tall and the hand reserves 164 -- below that the cards have to
## hang out of the band.
##
## THE CARDS NO LONGER CARE WHAT THIS IS. `HandView` holds itself at a card plus
## sixteen and centres, so its eight pixels of air are fixed whatever the band
## does -- which is what lets this number belong to the RAILS again.
##
## It has been 135, 170, 190, 182 and now 196, and every move before this one was
## the cards and the piles taking room off each other through it. They are
## decoupled now: this grows when the rails need it, and nothing else moves.
const DRAWER_H := 190

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
## Which node the approach animation has already played for.
##
## STATIC, because this screen is rebuilt every time you tab away and back, and
## the question it answers is about the RUN rather than about the screen: have
## you already flown into this system? `Run.at` is the whole of that.
static var _approached_at: int = -1

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
	# ONCE PER ARRIVAL, not once per screen. This is rebuilt every time you come
	# back from SHIP or STARCHART, so the approach played again each time -- the
	# ship flying in to a system it has been parked in for five minutes.
	#
	# Static because the screen is not: the flag has to outlive the thing that
	# sets it, in the same way the chart's view memory does.
	if not fighting() and _approached_at != Run.at:
		_approached_at = Run.at
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
	_build_self_plate()
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
	# IT HIDES THE PANEL. It does not move anything, and it never did -- what it
	# sets is a hush, and the old label got away with "STOW" only because
	# everything it listed was already in the hold.
	#
	# A bag is not. Loose salvage sits in the SYSTEM until you take it, so
	# pressing this on a bag put the panel away and left the parts on the floor,
	# which read exactly like the game had eaten them. Same word, two states,
	# and only one of them was true.
	var stow := Widgets.button("DECIDE LATER",
		func() -> void:
			Run.salvage_hushed_hauls = Run.hauls
			Run.salvage_hushed_bag = _bag_here()
			_refresh())
	stow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stow.tooltip_text = Widgets.tip("Closes this panel. Anything already in your hold stays there; anything still loose stays in this system until you take it or you jump.")
	_salvage_actions.add_child(stow)
	# THE JETTISON BUTTON IS GONE, and it was wrong twice over.
	#
	# It called `Run.cargo.clear()` -- it emptied your whole hold, everything,
	# in one press. Its own tooltip said "Destroys everything in the hold. There
	# is no reason to do this", which is an accurate description of a control
	# that should not exist. MATERIALS_NOTE 3.4 now rules it out outright:
	# nothing of yours is ever destroyed for you.
	#
	# And the word had been taken. Jettison means one thing now -- overboard,
	# into the bag at this system, recoverable until you jump -- and it is done
	# by right-clicking the thing you want rid of, one at a time, wherever the
	# hold is shown. A second button spelled the same way and meaning "burn
	# everything" is not a button, it is a trap.
	col.add_child(_salvage_actions)

	_salvage_wrap = Widgets.panel_with(col)
	_salvage_wrap.custom_minimum_size = Vector2(268, 0)
	return _salvage_wrap

## Your hull and your status, under your own ship.
##
## THE ENEMY HAS HAD ONE SINCE THE START and you have not: their name, their bar
## and their number sit under their hull where you are already looking, while
## yours were a strip in the corner of the card rail and a pair of digits in the
## top bar. Two pools read from two different parts of the screen.
##
## Mirrors `EnemySlot` deliberately -- same bar width, same six pixels of height,
## same centred number under it -- so the two sides of the fight are one
## vocabulary rather than two.
##
## `HULL_BIAS` is `ShipSlot`'s: the hull is centred in the left 68% of its half,
## so the plate is centred on the same fraction rather than on the middle of the
## panel, which would put it off the ship's nose.
const PLATE_W := 120
## How far under the hull the plate sits.
## How much air between the hull's last row and the top of the bar.
##
## AIR UNDER THE SHIP, not distance from its middle, which is what `PLATE_DROP`
## measured and why it read as neither centred nor clear: the hull is about a
## third of its canvas, so 56 from the middle lands wherever that particular
## hull happens to end. The enemy's own readout sits about this far under its
## art, and the two sides of the fight should agree.
const PLATE_AIR := 26.0

func _build_self_plate() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# BEGIN, NOT CENTER. A Control's size does not shrink back when its minimum
	# does, so with no statuses showing the box stayed as tall as it had been
	# with them -- and centring the contents in that leftover height put the
	# hull bar eight pixels lower than it sat a moment before. The bar moved
	# every time an effect came or went.
	#
	# Top-aligned, the bar is at the top of the plate whatever else is in it,
	# and the statuses print underneath. The bar is the thing you look for; it
	# does not get to move.
	col.alignment = BoxContainer.ALIGNMENT_BEGIN

	# YOUR NAME, ABOVE YOUR BAR, in the same order the enemy's readout uses:
	# name, bar, number, statuses. Two ships in a fight should be described the
	# same way -- theirs has always said who it is, and yours said nothing.
	#
	# ICE against their THEM. The colour is the only part of the readout that is
	# NOT mirrored, and it is the part carrying whose ship it is.
	_self_name = UITheme.body("", UITheme.ICE, UITheme.FS_SMALL)
	_self_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_self_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_self_name)

	_self_bar = ProgressBar.new()
	_self_bar.custom_minimum_size = Vector2(PLATE_W, 6)
	# SHRINK, or the bar is as wide as the widest thing under it. A VBox fills
	# its children horizontally by default, and the status row is the child that
	# grows -- so a fight with five effects running would have stretched the
	# hull bar to match, and the bar's LENGTH is a reading. It has to mean hull.
	_self_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_self_bar.show_percentage = false
	_self_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_self_bar)

	_self_hp = UITheme.body("", UITheme.HULL_GREEN, UITheme.FS_SMALL)
	_self_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_self_hp)

	# THE CHIPS COME DOWN HERE FROM THE RAIL. They are things carried on YOUR
	# hull -- brace, block, lock-on, a charging card -- so they belong on the
	# hull rather than in a strip beside the deck. It also gives the draw pile
	# the twenty-two pixels the rail was spending on a row that is empty most of
	# the time.
	_player_chips = HBoxContainer.new()
	_player_chips.add_theme_constant_override("separation", 3)
	_player_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_player_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_player_chips)

	# Centred under the hull rather than under the half: see `HULL_BIAS`.
	# A CHILD OF THE SHIP, so it goes where the ship goes.
	#
	# Two wrong answers came first and both were about the same thing. Anchoring
	# it to a fraction of the panel assumed the ship's slot was the whole width;
	# it is one of several children of a row, so the plate sat a long way to
	# starboard. Positioning it from `self_anchor()` on refresh got the place
	# right and the TIME wrong -- `ShipView.arrive()` animates, so the plate was
	# aimed at where the hull had been when the last refresh happened and stayed
	# there.
	#
	# Parenting settles both: the offset is measured once, against the art, and
	# the arrival carries the plate in with the ship.
	_self_plate = col
	col.size = Vector2(PLATE_W, 0)
	# THE SLOT, NOT THE ART. `ShipView` animates its own position on arrival and
	# its control is wider than the sprite inside it, so centring on that control
	# put the plate off the hull's nose and moving with it. The slot is stable,
	# is a plain Control rather than a container, and so leaves a child's
	# position alone -- which is what `_place_self_plate` then sets.
	_view.ship_view().get_parent().add_child(col)
	# ON RESIZE, NOT JUST ON REFRESH. The first version placed the plate only
	# from `_refresh_self_plate`, which runs before the slot has been laid out
	# -- `ship_bottom_y` had no canvas to measure yet and the ship's control was
	# still half its eventual height, so the plate landed eighty pixels above
	# the hull and stayed there.
	#
	# Both signals matter and for different reasons: the ship resizing moves the
	# hull, and the plate resizing changes what "centred" means, because a
	# status row wider than the bar widens the box the bar sits in.
	_view.ship_view().resized.connect(_place_self_plate)
	col.resized.connect(_place_self_plate)


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
		var lines := EncounterDrawer.quiet_lines(n)
		_drawer_simple(String(lines[0]), String(lines[1]))
		return
	match _dstate:
		Drawer.OPTION: _drawer_option(n)
		Drawer.RESULT: _drawer_result(n)
		_: _drawer_list(n)


## How tall the drawer is for this place.
##
## THE BOOKENDS ARE NARROW. A system gets the fixed `DRAWER_H`, because its
## drawer swaps between a list, an option and a result and a band that resized
## between those would make the viewport jump on every click. The start and the
## core swap between nothing: each says one line, offers one button, and that is
## the whole of it. A hundred and seventy pixels of panel holding forty of
## content is a hole under the ship, and these two are the first and last things
## anybody sees.
##
## Costs one resize on the first jump of a run and one on the last. Stations and
## pulsars are the same shape and could have the same treatment; they are left
## alone because each one would add a resize to a transition that has none, and
## unlike these two you dock at them repeatedly.
func _size_drawer(n: MapGen.MapNode) -> void:
	var bookend := n != null and not Run.dead 		and (n.type == MapGen.NodeType.START or n.type == MapGen.NodeType.CORE)
	_quiet_wrap.custom_minimum_size = Vector2(0, 0 if bookend else DRAWER_H)
	# The panel's own padding has to come down with it, or twelve above and
	# twelve below is most of what is left.
	_quiet_wrap.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 6 if bookend else 12, 12))


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
	var left := EncounterDrawer.untaken(n)
	if left.is_empty():
		# RULING 7. Every system rolls two to four, so an empty one only ever
		# means you took it all -- a small subtraction, not a completion tick.
		_drawer_simple("Nothing else here wants anything from you.", "PLOT NEXT JUMP")
		return
	_drawer.add_child(EncounterDrawer.head("%d THING%s OUT HERE WANT%s SOMETHING FROM YOU"
		% [left.size(), "" if left.size() == 1 else "S",
			"S" if left.size() == 1 else ""], _on_action))
	var placed: Dictionary = {}
	for i in left:
		var opt := OptionTable.by_id(n.options[i])
		var g := StringName(opt.get("group", &""))
		if g != &"":
			if placed.has(g):
				continue
			placed[g] = true
			_drawer.add_child(EncounterDrawer.group_strip(n, g, left, _open_option))
		else:
			_drawer.add_child(EncounterDrawer.list_row(n, i, opt, _open_option))


## The drawer's top line, with the way out parked on its right.
##
## Departure is on screen in EVERY state, which is what RULING 9 rests on: no
## option can pretend to be a wall while the exit is visible from inside it.
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
		row.add_child(EncounterDrawer.choice_button(
			n, _open, j, choices[j] as Dictionary, opt, _take_choice))
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
	# WHAT AN EVENT PAID YOU IN OBJECTS, if it paid you in any.
	#
	# `MATERIALS_NOTE` 3.6: a physical payout is a CONTAINER rather than a thing
	# that arrives. The text above already told you what you got; this is the
	# door to it, sitting next to CONTINUE so taking it is a decision rather
	# than something that happened while you were reading.
	#
	# Only when there is something loose here to take. An option that paid in
	# credits and fuel has nothing to open, and a button that opens an empty
	# container is a button that lies once per event.
	if Run.bag_left(n) > 0 and not Run.dead:
		var claim := Widgets.button("CLAIM %d" % Run.bag_left(n), _open_transfer)
		claim.custom_minimum_size = Vector2(120, 22)
		claim.tooltip_text = Widgets.tip("Your hold on one side, what this left you on the other. Anything you do not take stays in this system until you jump.")
		row.add_child(claim)

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
## Opening one option, handed to `EncounterDrawer.list_row` as a callable.
##
## The drawer's builders do not get to know about `Drawer.OPTION` or about
## `_refresh`; they get to say "this row was clicked". This is the whole of what
## they used to reach in for.
func _open_option(i: int) -> void:
	_open = i
	_dstate = Drawer.OPTION
	_refresh()


## And taking one. `_take` wants the node as well, which the screen already has
## and a static builder would have to be handed.
func _take_choice(i: int, j: int) -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n != null:
		_take(n, i, j)


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
	# 68, NOT 60, and the reason is a word. Every button on both rails is cut to
	# this width, and "END TURN" on one line does not fit 60 -- it wrapped, came
	# out at 24 against its neighbours' 16, and no amount of stylebox padding was
	# ever going to explain that. The eight pixels come off the card area, which
	# has them.
	# THE FLOOR, NOT A CHOICE. `END TURN` measures 58 at FS_SMALL and the flat
	# button boxes add six each side, so no rail can be narrower than this
	# whatever else is written on one. `-- fitwords` prints the table.
	#
	# It went to 100 to hold "NOT NEGOTIATING" and that was the wrong way round:
	# the rail sets what a word may be, because the PILE is cut to the rail too
	# and a wide rail makes a landscape pile. At 68 a full stack is 64 across
	# against 66 tall; at 100 it was 96 against 66.
	const W := 68
	# 52 IS THE CEILING, swept rather than guessed: the band is a fixed 170 shared
	# with the drawer, and `-- sectorshot` reports 171 at 53 and 175 at 57. Every
	# pixel this gains comes straight off the panel it has to fit inside.
	#
	# It has come down from 86 in three steps, each paying for something the rail
	# gained -- the fixed band, then the stack's lean, then the air under the
	# label. If it needs to be bigger the room has to come from somewhere else in
	# the column, because there is none here.
	# 66, which is where it was always trying to get to. It has been 86, 66, 62,
	# 58, 52, 60 and 52 again across one night of the rail and the cards trading
	# pixels; the hand holding its own height is what ended the argument.
	const H := 88
	var count: int = 0
	var label: String = ""

	func _init() -> void:
		# H, plus the four the stack leans by, plus room for the label under it,
		# plus the same gap under THAT as the rails carry above them -- the piles
		# are the last thing in each column and sat flush against the panel edge
		# while everything above them had six of air.
		custom_minimum_size = Vector2(W, H + 16 + SectorScreen.RAIL_DROP)
		# STOP, not IGNORE. A control that ignores the mouse never shows a
		# tooltip, and these two are the least self-explanatory things on the
		# panel -- a number on a card back that reshuffles when it runs out.
		mouse_filter = Control.MOUSE_FILTER_STOP

	## Told when the pile is clicked. Set by whoever built it.
	var opened: Callable

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb == null or not mb.pressed \
				or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if opened.is_valid():
			accept_event()
			opened.call()

	func set_count(n: int, text: String) -> void:
		if n == count and text == label:
			return
		count = n
		label = text
		queue_redraw()

	## The card inside the column, which is NARROWER than the column.
	##
	## `W` is the rail's width and every button on both sides is cut to it, so
	## narrowing that narrows the whole panel. The card is drawn at `CARD_W`
	## instead, centred, at 60 against 68 -- four pixels of margin each side and
	## the rest of the column filled. It was 44, which left twenty-four pixels of
	## nothing beside a pile that had already been squeezed three times.
	##
	## HEIGHT IS MAXED, not chosen: the control is `H + 16 + RAIL_DROP` and every
	## one of those is spoken for -- the lean, the label, and the air under it --
	## inside a band that is a fixed 170. Width was the only slack left.
	## The card, sized so a FULL stack is exactly as wide as a button.
	##
	## Three cards each lean two right of the last, so the widest the pile ever
	## draws is this plus four -- and tying it to `W` here is what stops the two
	## drifting apart. They did: the rail went to 100 for a long word and the
	## card stayed at 64, which put the pile back in the dead space it had just
	## been given to fill.
	const CARD_W := W - 4

	## Where the BACK card starts, so the whole leaning stack is centred.
	##
	## Centring one card and then leaning the others off it pushed the pile right
	## as it filled, which is a pile that moves while you play. The lean is known
	## -- two pixels per card behind the front one -- so it is subtracted here and
	## the group stays put.
	func _card_x(shown: int) -> float:
		return float(W - CARD_W - maxi(shown - 1, 0) * 2) * 0.5

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
			var o := Vector2(_card_x(shown) + float(i) * 2.0, float(shown - 1 - i) * 2.0)
			var r := Rect2(o, Vector2(CARD_W, H))
			draw_rect(r, UITheme.PANEL2, true)
			draw_rect(r, UITheme.LINE, false, 1.0)
			draw_rect(Rect2(o + Vector2(3, 3), Vector2(7, H - 6)), Color("#2b3646"), true)
			draw_rect(Rect2(o + Vector2(CARD_W * 0.5 - 7, H * 0.5 - 7), Vector2(14, 14)),
				Color("#3a4a5e"), true)
			draw_rect(Rect2(o + Vector2(CARD_W * 0.5 - 3, H * 0.5 - 3), Vector2(6, 6)),
				UITheme.PANEL2, true)
		if shown == 0:
			# An empty pile still holds its place, or the hand jumps sideways the
			# turn your draw pile runs out.
			draw_rect(Rect2(Vector2(_card_x(1), 4), Vector2(CARD_W, H)),
				Color("#1b2430"), false, 1.0)

		var f := UITheme.pixel_font()
		var n := str(count)
		var nw := f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_HEAD).x
		# The count rides the FRONT card, which is now four lower than the box.
		draw_string(f, Vector2((W - nw) * 0.5 + 1, H * 0.5 + 11), n,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_HEAD, UITheme.ICE)
		var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
		draw_string(f, Vector2((W - lw) * 0.5, H + 14), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, UITheme.COLD)

## Where the rails begin, which is where a HOVERED card begins.
##
## A card rests at 8 inside a hand bottom-aligned at 14, and hovering lifts it by
## 8 -- so the top edge of the card you are looking at is at 14, and that is the
## line the rails should start on. Rested cards sit 8 below it, which is right:
## the lifted one is the one you are considering, so it is the one the panel
## squares up to.
##
## Separate from `RAIL_DROP` because they stopped being the same number the
## moment this had to match something. That one is still the gap BETWEEN things
## and the air under the pile label; this is only the gap above the first box.
## 4, plus the 4 gap that lands after it, puts the first box on 8.
##
## EIGHT IS ALSO WHERE A HOVERED CARD STARTS, and that is not a coincidence
## surviving by luck -- the hand is bottom-aligned, so shortening the band moves
## it up by exactly what the band lost, and the lift is a constant. Both were 14
## at a band of 196 and both are 8 at 190. They travel together.
##
## The spacer is a CHILD of the rail, so the separation lands after it too, which
## is why this is 4 and not 8. Setting it to the target directly overshoots by
## exactly one gap.
const RAIL_TOP := 4

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
	c.custom_minimum_size = Vector2(0, RAIL_TOP)
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
	# FOUR BETWEEN ITEMS, against `RAIL_TOP` above the first and `RAIL_DROP`
	# under the last label. Three numbers where there was one, and the reason is
	# that the top now has to LINE UP with something outside the rail -- a
	# hovered card -- rather than just look even. The eight that costs comes off
	# the separations rather than off the band or the pile.
	left.add_theme_constant_override("separation", 4)
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
	nrg_box.tooltip_text = "ENERGY\n\nWhat you have left to spend."
	nrg_box.mouse_filter = Control.MOUSE_FILTER_STOP
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
	turn_box.tooltip_text = "TURN\n\nHow long this fight has been going on."
	turn_box.mouse_filter = Control.MOUSE_FILTER_STOP
	turn_box.add_child(_deck_label)
	left.add_child(turn_box)


	# PUSHES THE PILE TO THE BOTTOM, and this is what `RIGHT_GAP` was doing by
	# hand. That gap was a measured constant chosen to make the two rails come
	# out the same length -- which held exactly until any other number in either
	# column moved, and then the piles were four pixels apart again and the fix
	# was another measurement.
	#
	# An expanding spacer needs no measuring: both piles sit on the rail's bottom
	# edge, so they are level with each other by construction and their labels
	# land on the card edge because the band is what it is.
	var draw_push := Control.new()
	draw_push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(draw_push)

	_draw_pile = PileView.new()
	_draw_pile.tooltip_text = "DRAW\n\nWhat is left to draw from.\nClick to look."
	_draw_pile.opened = func() -> void:
		_show_pile("DRAW PILE", combat.deck, true)
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
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	right.add_child(_rail_drop())

	# Two lines and a box. It is the button you press every single turn, so it
	# should be the biggest target on the panel — and stacked it reads as a
	# button rather than as a word in a row of words.
	# THREE BUTTONS SPANNING ONE BLOCK. Together they come to the same 54 as
	# ENERGY and TURN opposite -- 22 + 3 + 14 + 3 + 14 -- so the piles below stay
	# level with the draw pile and the two rails read as columns rather than as
	# two lists that happen to be the same length.
	#
	# END TURN keeps the weight because it is the one you press every turn. It was
	# two lines and 38 tall, which made it a different size from the ENERGY box it
	# is supposed to mirror; one line at 22 mirrors it as part of the block.
	_end_button = Widgets.button("END TURN", _on_end_turn)
	# 16, not 22. A bevel button floors at about 17 whatever it is asked for, so
	# three of them plus a 22 came to 62 against the 54 the left rail spends on
	# ENERGY and TURN. Levelling them is what makes the block fit at all.
	_end_button.custom_minimum_size = Vector2(PileView.W, 16)
	_end_button.tooltip_text = "END TURN\n\nStop, and let them act."
	# ITS OWN STYLEBOX, because the default bevel pads four above and below and
	# rendered this at 28 while FLEE and HAIL -- which already carry flat boxes
	# with no vertical padding -- came out at 16. Three buttons cannot share a
	# block while one of them is nearly twice the others. Brighter border rather
	# than more height: it is still the primary, it just says so in colour.
	_end_button.add_theme_stylebox_override("normal",
		UITheme.flat(UITheme.PANEL2, Color("#4a5f78"), 0, 1, 6))
	_end_button.add_theme_stylebox_override("hover",
		UITheme.flat(Color("#1d2836"), UITheme.ICE, 0, 1, 6))
	_end_button.add_theme_stylebox_override("pressed",
		UITheme.flat(Color("#243044"), UITheme.ICE, 0, 1, 6))
	# AND `disabled`, WHICH IS THE ONE EVERY CUSTOM BUTTON FORGETS. The theme's
	# is `bevel_in(PANEL, 3, 5)` -- three above and below against these boxes'
	# zero -- so a button that greys GROWS, and the rail and everything under it
	# shifts a couple of pixels. Reported as the drawer moving when FLEE turns to
	# NO ESCAPE, which is exactly when a button greys.
	_end_button.add_theme_stylebox_override("disabled",
		UITheme.flat(UITheme.PANEL, Color("#2b3746"), 0, 1, 6))
	right.add_child(_end_button)

	# Thin, and red, and never sitting beside the button you actually want.
	# Fleeing costs a run's worth of progress; it should take a deliberate aim.
	var flee := Widgets.button("FLEE", _on_flee)
	_flee_button = flee
	flee.custom_minimum_size = Vector2(PileView.W, 16)
	flee.tooltip_text = "FLEE\n\nRun for it. Maneuver check."
	flee.add_theme_color_override("font_color", Color("#d4614f"))
	flee.add_theme_color_override("font_hover_color", Color("#f08872"))
	flee.add_theme_stylebox_override("normal",
		UITheme.flat(Color(0, 0, 0, 0), Color("#8f4034"), 0, 0, 6))
	flee.add_theme_stylebox_override("hover",
		UITheme.flat(Color("#2a1a18"), Color("#d4614f"), 0, 0, 6))
	flee.add_theme_stylebox_override("pressed",
		UITheme.flat(Color("#3a2320"), Color("#d4614f"), 0, 0, 6))
	# Same padding as the others, so NO ESCAPE is exactly as tall as FLEE.
	flee.add_theme_stylebox_override("disabled",
		UITheme.flat(Color(0, 0, 0, 0), Color("#3a3a3a"), 0, 0, 6))
	right.add_child(flee)

	# THE OTHER WAY OUT, and the one that costs nothing if it works. FLEE burns
	# fuel and rolls MANEUVER; HAIL burns nothing and rolls STEALTH. Two exits,
	# two attributes, and a ship is usually good at one of them.
	_hail_button = Widgets.button("HAIL", _on_hail)
	_hail_button.custom_minimum_size = Vector2(PileView.W, 16)
	# YELLOW, against FLEE's red. Two exits, and they should not look like the
	# same button twice -- red is the one that costs you a run's salvage, yellow
	# is the one that costs you nothing if it lands. `HOT` is the palette's warm
	# high note and is otherwise spent on outcome prose, which is close enough to
	# "this went well" for a button that tries to make a fight not happen.
	_hail_button.add_theme_color_override("font_color", UITheme.HOT)
	_hail_button.add_theme_color_override("font_hover_color", Color("#fff0c4"))
	_hail_button.add_theme_stylebox_override("normal",
		UITheme.flat(Color(0, 0, 0, 0), Color("#8a6a2e"), 0, 0, 6))
	_hail_button.add_theme_stylebox_override("hover",
		UITheme.flat(Color("#2a2213"), UITheme.HOT, 0, 0, 6))
	_hail_button.add_theme_stylebox_override("pressed",
		UITheme.flat(Color("#3a2f1a"), UITheme.HOT, 0, 0, 6))
	_hail_button.add_theme_stylebox_override("disabled",
		UITheme.flat(Color(0, 0, 0, 0), Color("#3a3a3a"), 0, 0, 6))
	right.add_child(_hail_button)

	# THE CHIP ROW'S OPPOSITE NUMBER. The left column spends `CHIP_ROW_H` on
	# your brace, block and lock-on; without the same gap here the discard pile
	# sits that much higher than the draw pile and the two columns stop being
	# columns. Empty on purpose -- the enemy's chips live in their own strip.
	var chip_gap := Control.new()
	# EXPANDING, like the left one. Neither rail needs to know how tall the other
	# is any more; both piles simply sit on the bottom.
	chip_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(chip_gap)

	_discard_pile = PileView.new()
	_discard_pile.opened = func() -> void:
		_show_pile("DISCARD PILE", combat.discard, false)
	_discard_pile.tooltip_text = "DISCARD\n\nWhat you have played so far.\nClick to look."
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

## How many cards fit across the panel before it wraps.
##
## Seven at `CARD_W` plus the flow's four is 808, which leaves the 960 a margin
## either side. Past that the panel would be wider than the screen it is
## centred in, so the flow wraps and the scroll takes the overflow -- a starting
## deck is ten cards but nothing stops a run ending with forty.
const PILE_COLS := 7


## What is in a pile.
##
## Both piles are public information -- the discard always was, and a draw pile
## you cannot count is just an unfair surprise -- but they are public in
## DIFFERENT ways, which is why the draw pile is sorted and the discard is not.
## The ORDER of the draw pile is the one thing that is genuinely hidden, so
## showing it in sequence would hand over the next five turns; sorting by name
## answers "what is left" without answering "what is next". The discard has no
## such secret, so it reads newest-first, the way you put it there.
func _show_pile(title: String, cards: Array[CardData], sorted_by_name: bool) -> void:
	if _pile_panel != null:
		_close_pile()

	_pile_panel = PanelContainer.new()
	_pile_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pile_panel.add_theme_stylebox_override("panel",
		UITheme.flat(Color(0.031, 0.043, 0.067, 0.95), Color(0, 0, 0, 0), 0, 20, 20))
	# STOP, so the fight underneath cannot be played through the panel covering
	# it. A card dropped on an enemy you cannot see is not a click you meant.
	_pile_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# CLICK ANYWHERE TO PUT IT DOWN. The cards ignore the mouse and the CLOSE
	# button eats its own click, so everything that reaches the backdrop is a
	# click on nothing -- which is the gesture people already try first.
	_pile_panel.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_close_pile())
	add_child(_pile_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_pile_panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	head.add_child(UITheme.body(title, UITheme.ICE, UITheme.FS_HEAD))
	var count := UITheme.body("%d CARDS" % cards.size(), UITheme.COLD, UITheme.FS_SMALL)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(count)
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(pad)
	head.add_child(Widgets.button("CLOSE", _close_pile))

	var shown: Array[CardData] = cards.duplicate()
	if sorted_by_name:
		shown.sort_custom(func(a: CardData, b: CardData) -> bool:
			return a.name < b.name)
	else:
		shown.reverse()

	if shown.is_empty():
		var none := UITheme.body("EMPTY", UITheme.COLD, UITheme.FS_SMALL)
		none.size_flags_vertical = Control.SIZE_EXPAND_FILL
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(none)
		return

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.custom_minimum_size = Vector2(
		float(PILE_COLS) * (CardView.CARD_W + 4), 0)
	scroll.add_child(flow)

	for c in shown:
		var v := CardView.new()
		# PLAYABLE, WHICH IS A LIE THAT READS TRUE. `set_playable(false)` drops
		# a card to a third alpha, and `CardView` already records why that is
		# wrong in bulk: "a hand greyed out end to end reads as unplayable".
		# A pile listing greyed end to end reads the same way -- as if the
		# cards had been taken off you rather than merely put down.
		#
		# Nothing can be played from here regardless: the flow is not a
		# `HandView`, which is the parent `CardView` checks before it will
		# start a drag, and the card ignores the mouse anyway.
		v.setup(c, true, 1)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(v)


## One enemy slot, for `-- entrance`. The view is private to this screen and
## the harness has to reach past it to read where the contact actually IS.
func view_slot(i: int) -> EnemySlot:
	return _view.slot(i) if _view != null else null


func _close_pile() -> void:
	if _pile_panel == null:
		return
	_pile_panel.queue_free()
	_pile_panel = null


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
	# A HULL BAR IS A COMBAT READOUT. Out of a fight the top bar already carries
	# the number and nothing is taking it off you, so a second copy floating
	# under the ship is a gauge for a thing that is not happening.
	if _self_plate != null:
		_self_plate.visible = at_war
	_refresh_hail()
	_refresh_flee()
	_refresh_self_plate()
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
		_view.show_enemies(combat.enemies, _on_card_dropped, _on_slot_hovered, _open_wreck)
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
	# NOT `Run.cargo`. This rail listed everything in your hold, which made
	# sense when loot ARRIVED there -- something turned up and the rail was how
	# you heard about it. Nothing arrives any more: 3.6 made every physical
	# grant a container you reach into, so by the time a part is in your hold
	# you have already picked it up on purpose and decided to keep it. Printing
	# it again in the sector is the game telling you something you just did.
	#
	# A found hull is different and stays: it is not in your hold, it is an
	# offer, and the rail is where the offer lives.
	var mine := Run.found_hull != null
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
		else "A HULL, IF YOU WANT IT"

	# THE BAG IS A CONTAINER, NOT A LIST. `MATERIALS_NOTE` 3.6: if something
	# hands you a physical thing it hands you a place to reach into, with your
	# own hold beside it, because 3.4 means no payout may force itself into a
	# full hold.
	#
	# Rows could not carry that. A row says the name and a number; what you
	# actually need to decide is whether a 2x2 will go anywhere, and the only
	# honest answer to that is both grids side by side. So the rail keeps the
	# summary and the reaching happens in `TransferView`.
	if loose > 0:
		var open := Widgets.button("OPEN SALVAGE - %d LEFT" % loose,
			_open_transfer)
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		open.tooltip_text = Widgets.tip("Your hold on one side, what is loose out here on the other. Drag across what you want; drag your own back out to put it down.")
		_salvage.add_child(open)
		var note := UITheme.body(
			"It stays in this system until you take it or you jump.",
			UITheme.COLD, UITheme.FS_SMALL)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_salvage.add_child(note)

	if Run.found_hull != null:
		_salvage.add_child(Widgets.hull_row(Run.found_hull, "TRANSFER", 0, _on_salvage))
	# MODULES ONLY. This rail asks "stow it or fit it", and a crate of ore
	# answers neither: it cannot be bolted to anything and there is nothing to
	# decide about it here.
	#
	# It listed everything in `Run.cargo`, which was every part you owned and
	# was survivable while a hold held four of them. With materials in there it
	# became your whole inventory, printed down the side of the sector, every
	# time you arrived anywhere. The hold is where you look at what you are
	# carrying; this is where you look at what just arrived and is fittable.



## Your hull, under your hull.
func _refresh_self_plate() -> void:
	if _self_bar == null:
		return
	var cap := maxi(1, Run.max_hp())
	_self_bar.max_value = cap
	_self_bar.value = Run.hp
	_self_hp.text = "%d / %d" % [Run.hp, cap]
	if Run.hull != null:
		_self_name.text = Run.hull.name.to_upper()
	# The same three bands the top bar uses, so a hull in trouble reads the same
	# wherever you happen to be looking.
	var frac := float(Run.hp) / float(cap)
	_self_hp.add_theme_color_override("font_color",
		UITheme.LEAVE if frac < 0.34 else (UITheme.EMBER if frac < 0.67
			else UITheme.HULL_GREEN))
	_place_self_plate()


## Under the hull, centred on the hull.
##
## MEASURED FROM THE SPRITE, not from the box around it. `PLATE_X` was 0.26 of
## the slot's width, arrived at by looking at a screenshot, and it was wrong the
## moment anything about the layout moved -- which is how it came to sit off to
## port of the ship it belongs to. `ship_offset_x` is the same question answered
## by the image itself, and `ship_bottom_y` is the vertical half of it.
##
## The canvas is drawn `STRETCH_KEEP_CENTERED`, so the control's middle IS the
## canvas's middle and both offsets are corrections from there.
func _place_self_plate() -> void:
	if _self_plate == null or _view == null:
		return
	var sv := _view.ship_view()
	if sv == null:
		return
	# ITS OWN WIDTH, not `PLATE_W`. The box is as wide as its widest child and
	# the status row can be twice the bar, so halving the CONSTANT centres a
	# narrower plate than the one actually on screen.
	_self_plate.position = Vector2(
		sv.position.x + sv.size.x * 0.5 + sv.ship_offset_x()
			- _self_plate.size.x * 0.5,
		sv.position.y + sv.size.y * 0.5 + sv.ship_bottom_y() + PLATE_AIR)



func _refresh_player() -> void:
	if not fighting():
		return
	_energy.setup(BoxGauge.Mode.ENERGY, Run.reactor(), combat.energy)
	_energy_text.text = "%d/%d" % [combat.energy, Run.reactor()]

	# EVERY EFFECT ON YOUR HULL, AS A PICTURE. See `StatusChip` for why these
	# stopped being words: five words under a sprite is a paragraph, five icons
	# is a glance, and the word survives in the tooltip.
	#
	# The colours are the ones the words already carried, because colour is what
	# says whose an effect is -- the two blues are yours, ember is a timer, and
	# the drones share one steel.
	Widgets.clear(_player_chips)
	if combat.brace > 0:
		_player_chips.add_child(StatusChip.make(&"brace", str(combat.brace),
			Color("#3a5a6e"), "BRACE\n\nMitigates %d damage, then goes away." % combat.brace))
	if combat.block > 0:
		_player_chips.add_child(StatusChip.make(&"block", str(combat.block),
			Color("#3a4a6e"), "BLOCK\n\nStops %d damage this turn." % combat.block))
	if combat.lock_on > 0:
		_player_chips.add_child(StatusChip.make(&"lock", "+%d" % combat.lock_on,
			Color("#6e5a3a"), "LOCK ON\n\nYour next attack deals %d more."
				% combat.lock_on))
	if combat.negate_next:
		_player_chips.add_child(StatusChip.make(&"slip", "", UITheme.GOOD,
			"SLIP\n\nThe next hit on you misses."))
	# SALVO IS NOT A STATUS, BUT ITS CONDITION IS. The keyword lives on the card
	# -- "if you have already attacked this turn, +N" -- so there is nothing on
	# the ship to show. What IS on the ship is `attacks_this_turn`, which decides
	# whether every salvo card in your hand is currently worth more, and which
	# was invisible: you had to remember whether you had swung yet.
	#
	# Only when a salvo card is actually in hand. A chip that fires on every
	# second attack whether or not it means anything is a light that is always on.
	if combat.attacks_this_turn > 0:
		for c in combat.hand:
			if (c as CardData).salvo > 0:
				_player_chips.add_child(StatusChip.make(&"salvo", "", UITheme.EMBER,
					"SALVO UP\n\nYou have attacked this turn, so salvo cards\nin your hand are worth more."))
				break
	if combat.feedback > 0:
		_player_chips.add_child(StatusChip.make(&"feedback", str(combat.feedback),
			Color("#6e3a4a"), "FEEDBACK\n\nAttackers take %d back." % combat.feedback))
	if combat.adapt_bonus > 0:
		_player_chips.add_child(StatusChip.make(&"adapt", "+%d" % combat.adapt_bonus,
			Color("#4a6e3a"), "ADAPT\n\nAdapting cards deal %d more."
				% combat.adapt_bonus))
	for d2 in combat.drones:
		_player_chips.add_child(StatusChip.make(&"drone", str(d2.damage),
			Color("#5a7a94"), "DRONE\n\nAttacks for %d at the end of your turn."
				% d2.damage))
	if combat.drone_brace > 0:
		_player_chips.add_child(StatusChip.make(&"wasp", str(combat.drone_brace),
			Color("#5a7a94"), "WASP\n\nYour drones add %d brace." % combat.drone_brace))
	for c2 in combat.charging:
		_player_chips.add_child(StatusChip.make(&"charging", str(c2.turns_left),
			UITheme.EMBER, "%s\n\nFires in %d." % [c2.card.name, c2.turns_left]))
	if combat.enemy.template.fauna and combat.peaceful_turns > 0:
		_player_chips.add_child(StatusChip.make(&"peaceful",
			"%d/2" % combat.peaceful_turns, Color("#4a6e5a"),
			"PEACEFUL\n\nIt has not been provoked for %d turns."
				% combat.peaceful_turns))

## RULING 8's shape: a disabled thing says what it wants.
##
## A greyed HAIL with no explanation reads as a bug. "NO REPLY" on a creature
## and "NO TERMS" on the thing guarding the core both say the rule out loud,
## once, at the moment it applies -- and both fit the button, which the first
## pair did not.
## The same shape as `_refresh_hail`, for the same reason.
##
## FLEE can be shut two ways now -- you tried and missed, or it is the core's
## guard and there is nowhere to run to -- and a greyed button with no reason
## reads as a bug either way.
func _refresh_flee() -> void:
	if _flee_button == null:
		return
	if not fighting():
		_flee_button.disabled = true
		return
	var why := combat.flee_reason()
	_flee_button.disabled = why != ""
	_flee_button.text = why if why != "" else "FLEE"
	_flee_button.add_theme_color_override("font_color",
		UITheme.COLD if why != "" else Color("#d4614f"))
	match combat.flee_cause():
		&"failed":
			_flee_button.tooltip_text = "FLEE\n\nYou tried. They are still here."
		&"boss":
			_flee_button.tooltip_text = "FLEE\n\nThere is nothing past this."
		_:
			_flee_button.tooltip_text = "FLEE\n\nRun for it. Maneuver check."


func _refresh_hail() -> void:
	if _hail_button == null:
		return
	if not fighting():
		_hail_button.disabled = true
		return
	var why := combat.hail_reason()
	_hail_button.disabled = why != ""
	_hail_button.text = why if why != "" else "HAIL"
	# The button has room for two words of why not; the tooltip has room for a
	# short sentence, and that is all it should be. Godot's tooltip does not
	# wrap, so a long one is a strip half the screen wide.
	match combat.hail_cause():
		&"struck":
			_hail_button.tooltip_text = "HAIL\n\nToo late. You shot first."
		&"fauna":
			_hail_button.tooltip_text = "HAIL\n\nIt does not have a radio."
		&"boss":
			_hail_button.tooltip_text = "HAIL\n\nThis one is not here to deal."
		_:
			_hail_button.tooltip_text = "HAIL\n\nTalk them down. Stealth check."
	_hail_button.add_theme_color_override("font_color",
		UITheme.COLD if why != "" else UITheme.CHILL)


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
	_view.show_enemies(combat.enemies, _on_card_dropped, _on_slot_hovered, _open_wreck)

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
		# ONE LINE, and it is set here as well as at construction because this
		# runs on every refresh and used to put the newline back. That is why
		# the button measured 24 against its neighbours' 16 whatever its
		# minimum size or its stylebox said: it was two lines tall again by
		# the time anything looked at it.
		_end_button.text = "END TURN"
	_end_button.disabled = combat.finished or combat.waiting

# --------------------------------------------------------------------- input

## Reaching into the bag, which is the one control on this screen that has to
## ask somebody else's machine before it can answer.
##
## `Widgets` binds the module rather than the index, so the index is recovered by
## identity — `n.bag` holds the very objects the rows were built from, and the
## array never shrinks, so `find()` is exact rather than a lookup by name.
## Open the two-grid view over this system's loose salvage.
##
## Built per open and torn down on close, the same as the pile listing, because
## what it shows changes every time something is taken out of it.
func _open_transfer() -> void:
	if _transfer != null:
		return
	var n: MapGen.MapNode = Run.node_at()
	if n == null:
		return
	_transfer = TransferView.new()
	add_child(_transfer)
	_transfer.setup("SALVAGE", n, _close_transfer)


## Clicking the hull you just killed.
##
## The wreck IS the container: what a fight paid you is sitting in the thing you
## shot, and the way to it is to go and look. Same popup as the sector's loose
## salvage because it is the same idea -- `MATERIALS_NOTE` 3.6 -- and titled for
## what you are standing over rather than generically, so opening a Rustjaw
## Cutter says so.
func _open_wreck() -> void:
	if _transfer != null:
		return
	var n: MapGen.MapNode = Run.node_at()
	if n == null or Run.bag_left(n) <= 0:
		return
	var name := "WRECK"
	if combat != null and not combat.enemies.is_empty():
		name = String(combat.enemies[0].template.name).to_upper()
	_transfer = TransferView.new()
	add_child(_transfer)
	_transfer.setup(name, n, _close_transfer)


func _close_transfer() -> void:
	if _transfer == null:
		return
	_transfer.queue_free()
	_transfer = null
	_refresh()


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

## Talk instead of shoot. `Combat.hail` owns the ruling and the roll.
##
## No confirm panel, unlike FLEE. Fleeing throws a run's salvage away and deserves
## the second question; hailing costs nothing you can see, and RULING 3 says a
## number on the button IS the commitment.
func _on_hail() -> void:
	if not fighting() or not combat.can_hail():
		return
	combat.hail()
	_refresh()


## Fleeing asks first.
##
## It ends the fight, forfeits every scrap of salvage and burns fuel — and it
## was a button one row from END TURN, which you press every single turn. Making
## it thin and red narrowed the target; it did not make the click reversible.
## Nothing else in combat costs a run's progress in one press, so nothing else
## needs this.
func _on_flee() -> void:
	if not fighting() or _flee_ask != null or not combat.can_flee():
		return

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var head := UITheme.body("BREAK CONTACT?", Color("#d4614f"), UITheme.FS_HEAD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	# The exact cost, from the same constant the code charges.
	# RULING 3'S SHAPE, borrowed: the odds are on the button, so pressing it is
	# the commitment. This panel exists because breaking contact throws a run's
	# salvage away -- but now that it can also FAIL, the number has to be here
	# rather than discovered afterwards.
	var fchk := combat.flee_check()
	var body := UITheme.body(
		"%s. You lose the salvage and burn %d fuel. Fail and there is no second try."
		% [SkillCheck.badge(fchk), Combat.FLEE_FUEL], UITheme.CHILL,
		UITheme.FS_SMALL)
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
		&"hailed": "STOOD DOWN",
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
