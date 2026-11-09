class_name SectorScreen
extends Control

## No separate combat screen: a fight is this sector with an enemy in it.
## Two classes drawing one place made the ship jump between contexts.
## Why: docs/why/SectorScreen.md#screen-shape

var combat: Combat
## The last card played, kept only so an attack can be drawn as the weapon it
## came from. Presentation, never consulted by anything that resolves.
var _last_played: CardData = null

# --- shared
var _view: EncounterView
var _title: Label
var _sub: Label
var _blurb: Label
var _state: Label
var _hull: Label

# --- salvage (quiet only)
var _salvage: VBoxContainer
var _salvage_wrap: PanelContainer
## The rail has a fixed small height and scrolls: a tall list pushed the hand off screen.
## Why: docs/why/SectorScreen.md#salvage-rail
var _salvage_scroll: ScrollContainer
## Built once, outside the scroll: they close this panel, so must stay reachable.
var _salvage_actions: HBoxContainer
## The rail's heading. Two things share this panel and they are not the same
## question: a BAG is loot nobody owns yet and a HOLD is loot you are carrying.
var _salvage_head: Label
## One TAKE at a time: a second click mid round trip could oversubscribe a one-slot hold.
## Why: docs/why/SectorScreen.md#salvage-rail
var _taking: bool = false
## Dismissal lives in `RunState`, as this screen is rebuilt on every jump.


# --- combat only
var _hand_wrap: PanelContainer
## The band the hand sits in; lowered when a fight ends. See `_build_hand`.
var _hand_holder: Control
var _preview: Label
var _energy: BoxGauge
var _energy_text: Label
var _player_chips: HBoxContainer
var _self_bar: HullBar
var _self_name: Label
var _self_plate: VBoxContainer
var _self_hp: Label
## "+17" beside the hull's number while brace is up.
var _self_brace: Label
var _enemy_name: Label
var _enemy_tag: Label
var _enemy_hp: Label
var _enemy_bar: ProgressBar
var _intent_label: Label
var _hand: HandView

## The card currently being aimed, or null. Everything about the gesture hangs
## off this being non-null.
var _aim_view: CardView = null
## The line's moving end, in this screen's space. Eased toward the cursor rather
## than snapped to it -- see `AimLine.FOLLOW`.
var _aim_tip: Vector2 = Vector2.ZERO
var _aim_line: AimLine = null

## A press that has not yet become anything. See `_on_card_grabbed`.
var _grab_view: CardView = null
var _grab_from: Vector2 = Vector2.ZERO
## 0 undecided, 1 reordering, 2 aiming.
var _grab_mode: int = 0

## Small thresholds so the card follows the hand; sideways is larger as it is recoverable.
## Why: docs/why/SectorScreen.md#card-gestures
const GRAB_SIDE := 14.0
## The keyword panel while a card is hovered. See _show_readout.
var _readout: PanelContainer = null
## Every readout parents here and is swept before each open, so two cannot coexist.
## Why: docs/why/SectorScreen.md#keyword-readout
var _readout_host: Control = null
## Which card the panel belongs to. See _show_readout.
var _readout_for: CardView = null
## The card whose panel is counting down but has not opened yet.
var _readout_pending: CardView = null
## Bumped on teardown: a coroutine holding a stale generation must not touch the screen.
## Why: docs/why/SectorScreen.md#keyword-readout
var _readout_gen: int = 0
## How long you have to rest on a card before it explains itself.
const READOUT_DELAY := 1.0
## About one module row tall, so a single part does not open a tall empty box.
const SALVAGE_MIN_H := 96
var _deck_label: Label
var _draw_pile: PileView
## The confirmation panel while it is open. See `_ask_exit`. One at a time:
## both exits use it, and they are alternatives to each other.
var _exit_ask: PanelContainer = null
## Its contents, so the question can be replaced by the answer in place.
var _exit_box: VBoxContainer = null

## One size for all four exit panels, so the buttons do not move between ask and answer.
## Why: docs/why/SectorScreen.md#exit-panel-size
const EXIT_ASK := Vector2(244, 144)
## What colour this exit is, and what it says when it fails. Held on the screen
## because the answer arrives on a signal, long after the question was built.
var _exit_ink: Color = UITheme.ICE
var _exit_fail: String = ""
## The open pile listing, or null. Built and torn down per open rather than
## hidden, because its contents change every single turn.
var _pile_panel: PanelContainer = null
## The open container, or null. See `_open_jetsam`.
var _transfer: TransferView = null
## The event band (`LocalEventDrawer`): an event from the map resolves here.
var _events: LocalEventDrawer = null
var _discard_pile: PileView
## The discard also holds discarded cards and the hand at END TURN, not just played ones.
## Why: docs/why/SectorScreen.md#discard-tooltip
const DISCARD_TIP := "DISCARD\n\nCards you played or discarded, and the rest of your hand at END TURN.\nClick to look."
var _end_button: Button
## The line in the empty drawer while this ship is stunned (`Combat.stunned`).
var _stun_note: Label
const STUN_NOTE := "Stunned. You act after the enemy's turn."
## END TURN's tooltip while stunned, the stun's one full explanation.
const STUN_TIP := "STUNNED\n\nYou just arrived. You act after the enemy's turn. It can still shoot you."
const END_TIP := "END TURN\n\nStop, and let them act."
var _hail_button: Button
var _flee_button: Button
var _log: LogPanel
## The fight's turn-by-turn log and its LOG button (`FightLog`).
var _fight_log: FightLog = null
var _quiet_wrap: PanelContainer
## The clipping box the drawer slides inside. See `_build_quiet_strip`.
var _quiet_holder: Control
var _quiet_text: Label
var _action: Button
## Fixed so the viewport does not jump; the hand shares it so a fight is a clean swap.
## Why: docs/why/SectorScreen.md#drawer-height
const DRAWER_H := 190

## Static: this screen is rebuilt on tab-back, and the answer is about the run.
static var _approached_at: int = -1

## The box the drawer's contents are rebuilt into.
var _drawer: VBoxContainer

var _overlay: PanelContainer
var _overlay_title: Label
var _overlay_body: Label

## Keeps the ship off LOCAL until the dock's arrival brings it in (Jon, Oct 20).
## Why: docs/why/SectorScreen.md#dock-arrival
static var dock_hidden := false
var _dock_hidden := false


func setup(c: Combat = null) -> void:
	combat = c
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if dock_hidden:
		dock_hidden = false
		_dock_hidden = true
		var dh := _view.ship_view()
		if dh != null:
			dh.visible = false
	# A FIGHT ABOUT TO OPEN (built, not begun: `Router.start_combat`) is drawn
	# as LOCAL first, row and all, and opened by `_raise_band`.
	if c != null and not fighting() and Router.animating():
		_view.hold_row = true

	Sig.resources_changed.connect(_refresh)
	Sig.ship_changed.connect(_refresh)
	Sig.map_changed.connect(_refresh)
	Sig.hand_changed.connect(_refresh_hand)
	Sig.enemy_changed.connect(_refresh_enemy)
	# One refresh on the combat state signal, so a new card modifier needs no new hook.
	# Why: docs/why/SectorScreen.md#hand-refresh
	Sig.player_combat_state_changed.connect(func() -> void:
		_refresh_player()
		if fighting():
			_refresh_hand())
	# The party moved: a partner ended their turn, or shot something. The hand
	# panel carries the WAITING button and the enemy panel carries their hits.
	Sig.party_fight_changed.connect(func(_at: int) -> void:
		if fighting():
			_refresh_hand()
			_refresh_enemy()
		# JOIN FIGHT is rebuilt only when its answer changes, not on every partner push.
		elif Router.join_state() != _join_shown:
			_refresh())
	Sig.turn_started.connect(func(_t): _refresh())
	Sig.combat_ended.connect(_on_combat_ended)
	# `combat_hit` drives the shot-by-shot playback; see the end of this file.
	Sig.combat_hit.connect(_on_hit)
	Sig.combat_started.connect(_on_fight_opened)
	Sig.hull_burned.connect(_on_burn)
	Sig.enemy_destroyed.connect(_on_enemy_destroyed)

	# (whether LOCAL plays its own arrival, decided before the event's band: the
	# band waits for it to settle, as GO's waits for the move down to land)
	_depart_to = Router.take_depart()
	var handoff := Router.take_arrival()
	var flyin := _depart_to < 0 and not fighting() and _approached_at == Run.at and _flyin_due()
	# Attached before the first refresh so the bar can offer OPEN IT; GO and LOCAL match.
	# Why: docs/why/SectorScreen.md#local-event
	_events = LocalEventDrawer.attach(self, fighting(), c == null and not _dock_hidden and not Router.docked, flyin)
	_events.changed.connect(_refresh)
	# (an event coming up: the thin bar kept off, so the band rises from below
	# the screen and not out of it; it comes once the band has gone)
	if not _events.deferred.is_empty() or _events.page != &"":
		_shut_drawer()
	_refresh()
	_attach_station_face()

	# The fly-in plays once per arrival, never in a fight, and an ambush screen must discard it.
	# Why: docs/why/SectorScreen.md#arrival
	var flew_in: bool = bool(handoff[0]) and not fighting()
	if fighting():
		flew_in = false
	var skipped: bool = bool(handoff[1])

	if _depart_to >= 0:
		_begin_depart()
	elif not fighting() and _approached_at != Run.at:
		_approached_at = Run.at
		# Also plays at a run's first system; `flew_in` lets an ambush screen discard it.
		if Router.animating() and not skipped:
			_begin_arrive()
			_station_here()
			return
		var art := _view.ship_view()
		if art != null and skipped:
			# A skip across the commit means be there already, not a half-finished jump animation.
			# Why: docs/why/SectorScreen.md#arrival
			art.park()
			art.refresh()
		elif art != null:
			# The drive sounds once here, not in `arrive()`, which also flies in convoy hulls.
			# Why: docs/why/SectorScreen.md#arrival-sound
			Audio.play(_ship_arrives(art, 0.0), 0.0)
	elif flyin:
		_flyin_hold()
	# THE STATION, ASLEEP OR AWAKE (Jon, Oct 21, "station:BC")
	_station_here()


# ---------------------------------------------------- LOCAL's own arrival
# The first LOCAL at a place flown to plays the system arrival, once per flight.
# Why: docs/why/SectorScreen.md#local-arrival

## the flight (`SystemMapScreen.flown_to` n) whose arrival LOCAL has had
static var _flyin_seen := -1
## fly-ins begun this session (for the harnesses)
static var flyins := 0
## THE STATION AWAKE while you are there: system -> the visit it woke for
## (`_visit`), so LOCAL again shows it lit, and a later DOCK finds it lit
static var _lit := {}
## waiting for the move down to land before flying in (the ship off LOCAL)
var _flyin_wait := false
## LOCAL's own arrival under way
var _flyin := false
## THE WAKE ON LOCAL: seconds since it began, or -1
var _wake_t := -1.0
## after the fly-in (or as LOCAL comes up), the station's wake is owed
var _wake_owed := false

## The station wakes after the ship settles, so flameout and breakers never overlap.
## Why: docs/why/SectorScreen.md#station-wake
const WAKE_BEAT_S := ZoomLadder.DOCK_BEAT_S
const WAKE_S := ZoomLadder.DOCK_POWER_S
const WAKE_GREEN_S := 0.6
const WAKE_GREEN_OUT_S := 0.4


## Forget where the map flew the ship, which LOCAL arrived at and which station
## is lit: in one system (`index`, a jump in) or all (a run's start).
static func forget_places(index: int = -1) -> void:
	if index < 0:
		SystemMapScreen.flown_to.clear()
		_lit.clear()
		_flyin_seen = -1
		LocalEventDrawer.forget_auto()
		return
	SystemMapScreen.flown_to.erase(index)
	_lit.erase(index)
	LocalEventDrawer.forget_auto(index)


## The visit the ship is on at its place in `n`: the map's flight that brought
## it there, or -1 (it came in by a jump, a load, a harness).
static func _visit(n: MapGen.MapNode) -> int:
	if n == null:
		return -1
	var f: Dictionary = SystemMapScreen.flown_to.get(n.index, {})
	if not f.is_empty() and int(f.at) == Run.site_here(n):
		return int(f.n)
	return -1


## This visit's arrival is had another way (an undock, a dock): no fly-in.
static func arrived_here() -> void:
	var v := _visit(Run.node_at())
	if v >= 0:
		_flyin_seen = v


static func _station_lit(n: MapGen.MapNode) -> bool:
	return n != null and _lit.has(n.index) and int(_lit[n.index]) == _visit(n)


static func _mark_lit() -> void:
	var n := Run.node_at()
	if n != null:
		_lit[n.index] = _visit(n)


## Whether this LOCAL plays its own arrival (and spends it either way).
func _flyin_due() -> bool:
	var n := Run.node_at()
	if n == null or fighting() or combat != null:
		return false
	var v := _visit(n)
	if v < 0 or v == _flyin_seen:
		return false
	_flyin_seen = v
	# (the map's DOCK: the dock's own arrival is this visit's)
	if _dock_hidden or Router.docked:
		return false
	# (GO's LOCAL too: the event opens once the ship has settled, as LOCAL's own
	# door opens it -- one result, Jon, Oct 21)
	return Router.animating() and _view.ship_view() != null


## Off LOCAL until the move down has landed, then in (`_begin_flyin`).
func _flyin_hold() -> void:
	_flyin_wait = true
	var art := _view.ship_view()
	if art != null:
		art.visible = false
	_shut_drawer()
	_when_up(_begin_flyin)


## `cb` once this LOCAL is the screen up and no move is under way.
func _when_up(cb: Callable) -> void:
	for i in 1800:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		if Router.current == self and not ZoomLadder.busy():
			break
	if is_inside_tree():
		cb.call()


func _begin_flyin() -> void:
	_flyin_wait = false
	var art := _view.ship_view()
	if art == null or fighting() or _phase != Phase.NONE:
		if art != null:
			art.visible = true
		_arrived_drawer()
		return
	_phase = Phase.ARRIVE
	_flyin = true
	flyins += 1
	_cine_sfx.clear()
	_shut_drawer()
	# (seen: `arrive` keeps it off LOCAL until it is off the left edge)
	art.visible = true
	var clip := _ship_arrives(art, 0.0)
	_cine_sfx.append(clip)
	Audio.play(clip, 0.0)
	_cine = create_tween()
	_cine.tween_interval(ShipView.ARRIVE_LEAD_S + ShipView.ARRIVE_MS / 1000.0 * DRAWER_AT)
	_cine.tween_callback(_arrival_drawer)
	_cine.tween_interval(ShipView.ARRIVE_MS / 1000.0 * (1.0 - DRAWER_AT))
	_cine.tween_callback(_flyin_end)


func _flyin_end() -> void:
	_phase = Phase.NONE
	_flyin = false
	_arrived_drawer()
	if _wake_owed:
		_wake_owed = false
		_wake()


## The event band rises once the ship settles; with none, the thin bar slides in.
func _arrived_drawer() -> void:
	if _events != null and is_instance_valid(_events) and not _events.deferred.is_empty():
		_events.open_held()
		return
	if _events != null and is_instance_valid(_events) and _events.page != &"":
		return
	if not fighting():
		_open_drawer(false)


## Lit if already woken, else woken after the fly-in or once LOCAL is up.
func _station_here() -> void:
	if _face == null or not is_instance_valid(_face):
		return
	var n := Run.node_at()
	if _station_lit(n):
		_face_set(1.0, 0.0, false)
		return
	if _dock_hidden or Router.docked or fighting():
		return
	if _flyin_wait or _flyin or _phase == Phase.ARRIVE:
		_wake_owed = true
		return
	_when_up(_wake)


func _face_set(pw: float, warn: float, heard: bool) -> void:
	for f: StationFace in [_face, _face_front]:
		if f != null and is_instance_valid(f):
			f.audible = heard
			f.power = pw
			f.warn = warn


func _wake() -> void:
	if _face == null or not is_instance_valid(_face) or fighting() or not _lad.is_empty():
		return
	var n := Run.node_at()
	if _station_lit(n):
		return
	_mark_lit()
	# (reduced motion: awake at once, and nothing heard)
	if not Router.animating():
		_face_set(1.0, 0.0, false)
		return
	_wake_t = 0.0


## The wake a frame on, on the same curve and clock the dock's POWER step uses.
func _wake_step(delta: float) -> void:
	if _face == null or not is_instance_valid(_face) or not _lad.is_empty():
		_wake_t = -1.0
		return
	# (the ladder's clock, as the dock's POWER step runs on: stepped in a harness)
	_wake_t += ZoomLadder.fixed_dt if ZoomLadder.fixed_dt > 0.0 else delta
	var u := (_wake_t - WAKE_BEAT_S) / WAKE_S
	var pw := clampf(u / WAKE_POWER_BY, 0.0, 1.0)
	var warn := 0.0
	if u > 0.0:
		warn = 1.0 if u < WARN_CLEAR else 2.0
	var after := _wake_t - WAKE_BEAT_S - WAKE_S - WAKE_GREEN_S
	if after > 0.0:
		warn = 2.0 + clampf(after / WAKE_GREEN_OUT_S, 0.0, 1.0)
	if warn >= 3.0:
		_wake_t = -1.0
		_face_set(1.0, 0.0, false)
		return
	_face_set(pw, warn, true)


## THE STATION PUT BACK TO SLEEP, for a harness that docks into a sleeping
## station from LOCAL's DOCK (`-- sheet=LadderTest`), as the map's DOCK finds it.
func station_asleep() -> void:
	_wake_t = -1.0
	_wake_owed = false
	var n := Run.node_at()
	if n != null:
		_lit.erase(n.index)
	_face_set(0.0, 0.0, false)


## A key or a click mid-wake: the station lit at once, its sounds hushed.
func _wake_finish() -> void:
	if _wake_t < 0.0 and not _wake_owed:
		return
	_wake_t = -1.0
	_wake_owed = false
	_mark_lit()
	_face_set(1.0, 0.0, false)
	Audio.hush(StationFace.power_sounds())


func fighting() -> bool:
	return combat != null and combat.enemy != null


## LOCAL at rest: no fight, no jump playing. A fight started from here is
## swapped in looking exactly like this (`Router.start_combat`).
func settled_local() -> bool:
	return not fighting() and _phase == Phase.NONE and is_visible_in_tree()


## The wrecks this LOCAL is drawing, taken for the fight screen that replaces
## it, and played out on that one (`EncounterView.hand_wrecks` / `wrecks_out`).
func hand_wrecks() -> Array:
	return _view.hand_wrecks() if _view != null else []

func wrecks_out(going: Array) -> void:
	if _view != null:
		_view.wrecks_out(going)

# ------------------------------------------------------- the jump, as a journey

## The lead lets the Router's own 0.13 s fade land before anything moves.
const DEPART_LEAD := 0.10
## Fires before the hull stops accelerating, so the ship is still gaining speed.
const REV_S := 0.90
## The system announcing itself. IN, HOLD, OUT — and the OUT overlaps the ship
## coming in, which is where the second the sequence used to waste went.
const CARD_IN := 0.50
const CARD_HOLD := 1.80
const CARD_OUT := 0.60
const CARD_TOTAL := CARD_IN + CARD_HOLD + CARD_OUT
## Reversed warp ends on the frame the drive starts, so leaving and arriving match.
## Why: docs/why/SectorScreen.md#jump-sounds
const WARP_IN_S := 1.48
## A 0.5 s breath between the warp ending and the ship appearing, Jon's pick.
## Why: docs/why/SectorScreen.md#jump-sounds
const ARRIVAL_GAP_S := 0.50
## Boards light a second before the ship stops, in its unpowered drift.
## Why: docs/why/SectorScreen.md#arrival
const DRAWER_AT := 0.78
const DRAWER_RISE := 0.28
## How much of the sky the drawer lets through. A shade under PANEL_A, because
## this panel is the one that covers the most of it.
const DRAWER_A := 0.80

enum Phase { NONE, DEPART, COMMITTING, ARRIVE }
var _phase: Phase = Phase.NONE
## Taken from Router and cleared there, so a dying screen cancels the jump unspent.
var _depart_to: int = -1
var _card: Control = null
## Held so a skip can kill it. A tween left running after the thing it animates
## has been jumped past is the sequence happening twice.
var _cine: Tween = null
## Sounds already playing: a skip cuts these but leaves a fight or music alone.
var _cine_sfx: Array[StringName] = []

## Engines up, lean, and go.
func _begin_depart() -> void:
	_phase = Phase.DEPART
	_cine_sfx.clear()
	_shut_drawer()
	var art := _view.ship_view()
	if art == null:
		_commit(false)
		return
	_cine = create_tween()
	_cine.tween_interval(DEPART_LEAD)
	# The style decides whether the hull is dismantled or merely hidden, so the
	# view is told before it starts rather than being corrected mid-run.
	var hyper := _view.ship_flare_melts()
	_cine.tween_callback(func() -> void:
		var clip := art.depart(hyper)
		# And no thruster roar with no thruster lit. The charge's own whine is the
		# drive for a hyperdrive; the roar belongs to departures that burn.
		if not hyper:
			_cine_sfx.append(clip)
			Audio.play(clip, 0.0))
	_cine.tween_interval(JumpFx.HYPER_REV if hyper else REV_S)
	_cine.tween_callback(_pulse_out)

func _pulse_out() -> void:
	var f := _view.ship_pulse()
	if f == null:
		_commit(false)
		return
	# Sound is placed on the flare's clock, with no pitch variance, as that shifts time.
	if f.melts():
		_cine_sfx.append(&"hyperjump")
		Audio.play(&"hyperjump", 0.0)
	# Commits at the peak: the flash is widest there, so it hides the screen swap.
	f.peaked.connect(func() -> void:
		var art := _view.ship_view()
		if art != null:
			art.visible = false
		_commit(false), CONNECT_ONE_SHOT)

## Spend it. Nothing in this object is valid after this line.
func _commit(skipped: bool) -> void:
	# `_swap` frees the old screen late in the frame, so a late flare peak would jump a dead run.
	# Why: docs/why/SectorScreen.md#jump-commit
	if _phase != Phase.DEPART or not is_visible_in_tree():
		return
	_phase = Phase.COMMITTING
	var to := _depart_to
	_depart_to = -1
	# And not the tab click either. The commit swaps the screen, the swap fires
	# screen_changed, and that plays a UI tick in the middle of a cinematic.
	Audio.suppress(&"ui_tab", 600)
	Router.commit_jump(to, skipped)

## Idle bob once an arrival has brought the ship to rest, for system and dock alike.
const ARRIVE_BOB := 2


func _begin_arrive() -> void:
	_phase = Phase.ARRIVE
	_hold_outline()
	_cine_sfx.clear()
	_shut_drawer()
	var art := _view.ship_view()
	if art == null:
		_phase = Phase.NONE
		_open_drawer(true)
		return
	# The delay keeps the ship off screen: `_tick_arrival` measures first, then honours it.
	# Why: docs/why/SectorScreen.md#arrival
	var clip := _ship_arrives(art, CARD_TOTAL)
	_card = _build_name_card(Run.node_at())
	add_child(_card)

	_cine = create_tween()
	_cine.tween_property(_card, "modulate:a", 1.0, CARD_IN).from(0.0)
	# Hold and fade are chained, not `parallel()`, or the fade ran during the hold.
	# Why: docs/why/SectorScreen.md#arrival
	var warp_lead := clampf(WARP_IN_S + ARRIVAL_GAP_S - CARD_OUT, 0.0, CARD_HOLD)
	_cine.tween_interval(CARD_HOLD - warp_lead)
	# No reverse warp in the first sector, as nothing warped in (Jon).
	# Why: docs/why/SectorScreen.md#jump-sounds
	_cine.tween_callback(func() -> void:
		if Run.jumps > 0:
			_cine_sfx.append(&"hyperjump_in")
			Audio.play(&"hyperjump_in", 0.0))
	_cine.tween_interval(warp_lead)
	_cine.tween_property(_card, "modulate:a", 0.0, CARD_OUT)
	_cine.tween_callback(func() -> void:
		# The clip opens with the lead-in, so the flame's coughs land on the sound's.
		_cine_sfx.append(clip)
		Audio.play(clip, 0.0)
		_drop_card())
	_cine.tween_interval(ShipView.ARRIVE_LEAD_S + ShipView.ARRIVE_MS / 1000.0 * DRAWER_AT)
	_cine.tween_callback(_arrival_drawer)
	_cine.tween_interval(ShipView.ARRIVE_MS / 1000.0 * (1.0 - DRAWER_AT))
	# (and a station alongside wakes once the ship has settled, as on a fly-in)
	_cine.tween_callback(_flyin_end)

## Park the drawer below the floor. Not `visible = false`: the band still has to
## measure, or the arena grows into it and shrinks again when it slides back.
func _shut_drawer() -> void:
	if _quiet_holder != null and _quiet_wrap != null:
		_quiet_wrap.position.y = maxf(_quiet_holder.size.y, DRAWER_H)

func _open_drawer(at_once: bool) -> void:
	if _quiet_wrap == null:
		return
	if at_once:
		_quiet_wrap.position.y = 0.0
		return
	create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) \
		.tween_property(_quiet_wrap, "position:y", 0.0, DRAWER_RISE)

func _drop_card() -> void:
	if _card != null:
		_card.queue_free()
		_card = null

## The detail line lives only on this card; the corner keeps the name alone.
## Why: docs/why/SectorScreen.md#name-card
func _build_name_card(n: MapGen.MapNode) -> Control:
	var wrap := CenterContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(col)
	var name_l := UITheme.body(MapGen.star_name(n), UITheme.ICE, UITheme.FS_PLACE)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_l)
	# A run's first frame says when you are, not where: the class line adds nothing.
	var under := "YOUR JOURNEY BEGINS HERE" if Run.jumps == 0 		else MapGen.place_line(n)
	var line := UITheme.body(under, UITheme.COLD, UITheme.FS_SMALL)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(line)
	return wrap

## Skip is essential: sixty-odd jumps of watching a transition adds up to minutes.
func _skip() -> void:
	if _cine != null and _cine.is_valid():
		_cine.kill()
	_cine = null
	# Killing the tween only stops unplayed sounds; ones already sounding must be cut.
	if not _cine_sfx.is_empty():
		Audio.hush(_cine_sfx)
		_cine_sfx.clear()
	if _phase == Phase.DEPART:
		# The skip is carried across the commit so the arrival does not play either.
		_commit(true)
		return
	_phase = Phase.NONE
	_drop_card()
	# (LOCAL's own arrival pressed through: parked, and the station it came
	# alongside lit at once, unheard)
	_flyin = false
	if _wake_owed:
		_wake_finish()
	var art := _view.ship_view()
	if art != null:
		art.visible = true
		art.park()
		art.refresh()
	# (the event held for it up at once, as it would have opened on settling;
	# else the thin bar, at once)
	if _events != null and is_instance_valid(_events) and not _events.deferred.is_empty():
		_events.open_held()
	elif _events == null or not is_instance_valid(_events) or _events.page == &"":
		_open_drawer(true)
	_refresh()
	# a fight that met you here comes up now, not after the approach
	if _ambushed and _opening:
		_arrival_drawer()


## The approach's last second: LOCAL's drawer rises, or, when something was
## waiting here, the contacts fly in and the hand comes up (`_hold_for_arrival`).
func _arrival_drawer() -> void:
	if _ambushed and _opening:
		_ambushed = false
		_view.release_entrances()
		_raise_band()
		return
	# No bottom drawer while arriving; the thin bar comes once the ship settles (Jon, Oct 22).
	# Why: docs/why/SectorScreen.md#arrival

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
	# Re-asked on every re-layout, as the arena height is the drawer band's leftovers.
	_view.resized.connect(_sync_bleed)
	_build_self_plate()
	# YOUR IDLE, HEARD: this is the one view of your ship whose idle flame has
	# a sound (`ShipView.hums`), on LOCAL and in fights alike.
	_view.ship_view().hums = true
	_view.fx.landed.connect(_on_shot_landed)
	_view.fx.volley_landed.connect(_on_volley_landed)
	_view.death_style = _death_style
	_view.wreck_id = _wreck_id_of
	# THE CUTAWAY: point at your own ship, out of a fight, and it is outlined in
	# its own pixels; click it and it opens up (`CutawayView`)
	_hook_cutaway()

	var pad := Widgets.pad(null, 8, 6)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)
	# The corner holds nothing now: the arrival card names the system, and empty is the point.
	# Why: docs/why/SectorScreen.md#header-corner
	_title = UITheme.body("", UITheme.ICE, UITheme.FS_PLACE)
	_sub = UITheme.body("", UITheme.THEM, UITheme.FS_SMALL)
	_blurb = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	# Built but not added, so the refresh code that writes to them keeps working.
	# Why: docs/why/SectorScreen.md#header-corner
	_hull = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	_state = UITheme.body("", UITheme.FLARE, UITheme.FS_SMALL)

	arena.add_child(_build_salvage_rail())

	root.add_child(_build_quiet_strip())
	_build_orphans()
	root.add_child(_build_hand())
	# THE FIGHT LOG, over the screen and hidden until asked for (`FightLog`):
	# laid out round nothing, so nothing moves for it
	_fight_log = FightLog.new(self)
	add_child(_fight_log)
	_build_overlay()

## These four stay alive as orphans so the refresh code writing to them need not change.
## Why: docs/why/SectorScreen.md#removed-side-rail

func _build_orphans() -> void:
	_enemy_name = UITheme.body("", UITheme.THEM, UITheme.FS_BODY)
	_enemy_bar = ProgressBar.new()
	_enemy_bar.show_percentage = false
	_enemy_hp = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_enemy_tag = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_preview = UITheme.body("", UITheme.FLARE, UITheme.FS_SMALL)
	_log = LogPanel.new()

## Only the middle band scrolls and is rebuilt; the heading needs no `name` check.
## Why: docs/why/SectorScreen.md#salvage-rail
func _build_salvage_rail() -> PanelContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	_salvage_head = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	col.add_child(_salvage_head)

	_salvage = VBoxContainer.new()
	_salvage.add_theme_constant_override("separation", 3)
	_salvage.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_salvage_scroll = ScrollContainer.new()
	# Sideways scroll would mean the rail is too narrow; disabled so no second bar.
	_salvage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Takes the arena's leftover height rather than demanding its content's. This
	# line and SALVAGE_MIN_H below are the whole of the fix.
	_salvage_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_salvage_scroll.custom_minimum_size = Vector2(0, SALVAGE_MIN_H)
	_salvage_scroll.add_child(_salvage)
	col.add_child(_salvage_scroll)

	_salvage_actions = HBoxContainer.new()
	_salvage_actions.add_theme_constant_override("separation", 4)
	# The button only hides the panel, so it reads DECIDE LATER, not STOW.
	# Why: docs/why/SectorScreen.md#salvage-rail
	var stow := Widgets.button("DECIDE LATER",
		func() -> void:
			Run.salvage_hushed_hauls = Run.hauls
			Run.salvage_hushed_bag = _bag_here()
			_refresh())
	stow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stow.tooltip_text = Widgets.tip("Closes this panel. Anything already in your hold stays there; anything still loose stays in this system for the rest of the run.")
	_salvage_actions.add_child(stow)
	# No JETTISON button: it cleared the whole hold, which `MATERIALS_NOTE` 3.4 rules out.
	# Why: docs/why/SectorScreen.md#salvage-rail
	col.add_child(_salvage_actions)

	_salvage_wrap = Widgets.panel_with(col)
	_salvage_wrap.custom_minimum_size = Vector2(268, 0)
	return _salvage_wrap

## Mirrors `EnemySlot` so both sides share one vocabulary; centred on `HULL_BIAS`.
## Why: docs/why/SectorScreen.md#self-plate
const PLATE_W := 120
## Measured as air under the hull; distance from its middle lands wherever the hull ends.
## Why: docs/why/SectorScreen.md#self-plate
const PLATE_AIR := 26.0

func _build_self_plate() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Top-aligned so the hull bar does not move when statuses come and go.
	# Why: docs/why/SectorScreen.md#self-plate
	col.alignment = BoxContainer.ALIGNMENT_BEGIN

	# Name above the bar, in the enemy readout's order; ICE colour marks it as yours.
	# Why: docs/why/SectorScreen.md#self-plate
	_self_name = UITheme.body("", UITheme.ICE, UITheme.FS_SMALL)
	_self_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_self_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_self_name)

	_self_bar = HullBar.new()
	_self_bar.custom_minimum_size = Vector2(PLATE_W, 6)
	# Shrink-centred: the bar's length is a reading and must not stretch to the status row.
	_self_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_self_bar)

	# "37 / 40 +17", the way the two sit on the bar above.
	var nums := HBoxContainer.new()
	nums.add_theme_constant_override("separation", 4)
	nums.alignment = BoxContainer.ALIGNMENT_CENTER
	nums.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nums)
	_self_hp = UITheme.body("", UITheme.HULL_GREEN, UITheme.FS_SMALL)
	_self_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nums.add_child(_self_hp)
	# STOP so its tooltip shows: the one place that says brace costs heat to hold.
	_self_brace = UITheme.body("", UITheme.BRACE, UITheme.FS_SMALL)
	_self_brace.mouse_filter = Control.MOUSE_FILTER_STOP
	_self_brace.visible = false
	nums.add_child(_self_brace)

	# Chips sit on the hull that carries them, which frees 22 px for the draw pile.
	_player_chips = HBoxContainer.new()
	_player_chips.add_theme_constant_override("separation", 3)
	_player_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_player_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_player_chips)

	# A child of the ship so it moves with it; panel anchors and `self_anchor()` both missed.
	# Why: docs/why/SectorScreen.md#self-plate
	_self_plate = col
	col.size = Vector2(PLATE_W, 0)
	# Parented to the slot, not the art: the slot is stable and leaves positions alone.
	_view.ship_view().get_parent().add_child(col)
	# Placed on resize too: on refresh alone the slot was unlaid and the plate landed high.
	# Why: docs/why/SectorScreen.md#self-plate
	_view.ship_view().resized.connect(_place_self_plate)
	col.resized.connect(_place_self_plate)


## A plain Control gives the drawer its own position to slide on, sized rather than anchored.
## Why: docs/why/SectorScreen.md#quiet-strip
func _build_quiet_strip() -> Control:
	# `arena` above expands, so pinning this pins the viewport at the remainder
	# without either of them having to know about the split.
	_drawer = VBoxContainer.new()
	_drawer.add_theme_constant_override("separation", 3)
	_quiet_wrap = Widgets.panel_with(_drawer)
	_quiet_wrap.custom_minimum_size = Vector2(0, DRAWER_H)

	_quiet_holder = Control.new()
	_quiet_holder.clip_contents = true
	_quiet_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quiet_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quiet_holder.size_flags_vertical = Control.SIZE_SHRINK_END
	_quiet_holder.custom_minimum_size = Vector2(0, DRAWER_H)
	_quiet_holder.add_child(_quiet_wrap)
	# The panel still drives layout, so tall drawer content grows the band, not clips.
	_quiet_holder.resized.connect(_sync_drawer_box)
	_quiet_wrap.minimum_size_changed.connect(_sync_drawer_box)
	return _quiet_holder

## Guarded against its own echo; `position.y` is left alone as it belongs to the reveal.
## Why: docs/why/SectorScreen.md#quiet-strip
func _sync_drawer_box() -> void:
	if _quiet_wrap == null or _quiet_holder == null:
		return
	var h := _quiet_wrap.get_combined_minimum_size().y
	if not is_equal_approx(_quiet_holder.custom_minimum_size.y, h):
		_quiet_holder.custom_minimum_size = Vector2(0, h)
	var want := Vector2(_quiet_holder.size.x, h)
	if not _quiet_wrap.size.is_equal_approx(want):
		_quiet_wrap.size = want
	_sync_bleed()

## The sky bleeds under the drawer band, removing the hard seam while it is parked low.
## Why: docs/why/SectorScreen.md#quiet-strip
func _sync_bleed() -> void:
	if _view == null:
		return
	# Measured from the view's parent, as the view's own edge is what the bleed moves.
	var slot := _view.get_parent() as Control
	if slot == null:
		return
	_view.set_bleed(get_global_rect().end.y - slot.get_global_rect().end.y)


# -------------------------------------------------------------------- drawer


## Put the right thing in the drawer.
func _rebuild_drawer(n: MapGen.MapNode) -> void:
	Widgets.clear(_drawer)
	_size_drawer(n)
	if Run.dead:
		_drawer_simple("The ship is lost. The run is over.", "SUMMARY")
		return
	# THE CORE WON, ITS BODY STILL SHUT: one line, and the body the one thing
	# to do -- no jump, no way off (`Router.final_loot`).
	if Router.final_loot:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var t := UITheme.body("The Custodian is dead. Its body is yours to strip.", UITheme.CHILL, UITheme.FS_SMALL)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(t)
		var b := Widgets.button("SALVAGE THE CUSTODIAN", Router.open_core_body)
		b.custom_minimum_size = EncounterDrawer.BTN
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		_drawer.add_child(row)
		return
	if Run.hellbender_alive() and Run.hellbender_at == n.index:
		var hl := EncounterDrawer.quiet_lines(n)
		_drawer_simple(String(hl[0]), String(hl[1]))
		return
	# A system or station shows one line and the map link; contents are taken on the map.
	# Why: docs/why/SectorScreen.md#local-drawer
	if n.type == MapGen.NodeType.SYSTEM or n.type == MapGen.NodeType.STATION:
		_drawer_here(n)
		return
	var lines := EncounterDrawer.quiet_lines(n)
	_drawer_simple(String(lines[0]), String(lines[1]))


## The bookends get a narrow drawer: they swap between nothing, so a fixed height is a hole.
## Why: docs/why/SectorScreen.md#drawer-sizing
func _size_drawer(n: MapGen.MapNode) -> void:
	# Reverses an earlier ruling: a system no longer collapses, as its option rows fill it.
	# Why: docs/why/SectorScreen.md#drawer-sizing
	var bookend := n != null and not Run.dead
	_quiet_wrap.custom_minimum_size = Vector2(0, 0 if bookend else DRAWER_H)
	# The panel's own padding has to come down with it, or twelve above and
	# twelve below is most of what is left.
	_sync_drawer_box()
	# Keeps the panel alpha: an opaque override undid `UITheme.PANEL_A` each refresh.
	_quiet_wrap.add_theme_stylebox_override("panel",
		UITheme.flat(Color(UITheme.PANEL, DRAWER_A), UITheme.LINE,
			0, 6 if bookend else 12, 12))


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
	# (NO SECTOR LOOT HERE ANY MORE: the floor's pile is on the sector map's
	# panel, where it says SECTOR LOOT whenever there is something on it.)
	var b := Widgets.button(label, _on_action)
	b.custom_minimum_size = EncounterDrawer.BTN
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	# No second jump button when the main one already leaves; the way out goes to the chart.
	# Why: docs/why/SectorScreen.md#drawer-actions
	if label != EncounterDrawer.TO_SECTOR:
		# NO CLICK ON THIS ONE, and see `_plot_next_jump` for why.
		var jump := Widgets.button(EncounterDrawer.TO_SECTOR, _plot_next_jump, false)
		jump.custom_minimum_size = EncounterDrawer.BTN
		jump.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(jump)
	_drawer.add_child(row)


## Counts only events at the ship's place, not the whole system's (Jon, Oct 21).
## Why: docs/why/SectorScreen.md#local-drawer
static func things_here(n: MapGen.MapNode) -> Array:
	var out: Array = []
	if n == null:
		return out
	var site := Run.site_here(n)
	if not SystemLayout.is_place(site):
		return out
	var L := SystemLayout.of(n)
	for i: int in EncounterDrawer.untaken(n):
		if L.place_of(i) == site:
			out.append(i)
	return out


## What the bar is offering for a partner's fight (`Router.join_state`), so a
## fight push rebuilds it only when that changes.
var _join_shown := Router.JOIN_NONE

## Parts are joined with a dot, as a player-facing line has no dash (audit, Oct 22).
static func here_line(n: MapGen.MapNode) -> String:
	var left := things_here(n).size() if n.type == MapGen.NodeType.SYSTEM else 0
	# No "· SEE SECTOR" tail: SCAN SECTOR sits beside it (Jon, Nov 9, stripped-down UI 1A).
	var line := "NOTHING ELSE HERE"
	if n.type == MapGen.NodeType.STATION:
		# (the berth is at the station's own body: anywhere else in its system
		# the way to it is the map -- dock:A)
		line = "A STATION HERE" if Router.at_station(n) else "FLY TO THE STATION TO DOCK"
	elif left > 0:
		line = "%d THING%s HERE" % [left, "" if left == 1 else "S"]
	# THE EVENT YOU CAME FOR, how it went and what is left (`LocalEventDrawer`)
	var ev := LocalEventDrawer.bar_line(n)
	if ev != "":
		line = ev
	return line


func _drawer_here(n: MapGen.MapNode) -> void:
	var line := here_line(n)
	# A PARTNER IS FIGHTING HERE, and the way in is on this bar (Oct 22
	# playtest: there was no way into a partner's fight at all).
	_join_shown = Router.join_state()
	if _join_shown != Router.JOIN_NONE:
		line = "%s IS FIGHTING HERE" % Router.join_fight_names()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var t := UITheme.body(line, UITheme.COLD, UITheme.FS_SMALL)
	t.name = "HereLine"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(t)
	# The sector loot button shows only while the pile has something, as on the map.
	# Why: docs/why/SectorScreen.md#local-drawer
	if _join_shown != Router.JOIN_NONE:
		var jf := Widgets.button("JOIN FIGHT", Router.join_fight)
		jf.name = "JoinFight"
		# greyed while the Hellbender spools its escape, and saying why
		jf.disabled = _join_shown == Router.JOIN_SHUT
		jf.tooltip_text = Widgets.tip(Router.join_tip())
		jf.custom_minimum_size = EncounterDrawer.BTN
		jf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(jf)
	# OPEN IT: the event the band was dropped on (NOT NOW), or walked away from
	if LocalEventDrawer.can_reopen(n) and _events != null and _events.page == &"":
		var oi := Widgets.button("OPEN IT", func() -> void: _events.open(LocalEventDrawer.bar_option(n)))
		oi.name = "OpenIt"
		oi.custom_minimum_size = EncounterDrawer.BTN
		oi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(oi)
	# (the pile and what is left in every wreck you have opened: `sector_loot`)
	var pile := Run.sector_loot(n)
	var loose := Run.jetsam_left(n, pile) if pile != null else 0
	if loose > 0:
		var lb := Widgets.button("SECTOR LOOT · %d" % loose, _open_loose)
		lb.name = "SectorLoot"
		lb.custom_minimum_size = EncounterDrawer.BTN
		lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lb)
	# DOCK shows only where a station is beside you, never at a world, star or open space.
	# Why: docs/why/SectorScreen.md#local-drawer
	if n.type == MapGen.NodeType.STATION and ZoomLadder.chosen() and Router.at_station(n):
		var dk := Widgets.button("DOCK", func() -> void: Router.show_station())
		dk.name = "Dock"
		dk.custom_minimum_size = EncounterDrawer.BTN
		dk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dk)
	# NO CLICK: the page turn is this button's sound. See `_plot_next_jump`.
	var b := Widgets.button(EncounterDrawer.TO_SECTOR, _plot_next_jump, false)
	b.custom_minimum_size = EncounterDrawer.BTN
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	_drawer.add_child(row)


func _on_action() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if Run.dead:
		Router.show_game_over()
		return
	# While the hellbender holds the system it is the one thing offered, as in Router.
	if Run.hellbender_alive() and Run.hellbender_at == n.index:
		if Router.at_hellbender(n):
			Router.engage_hellbender()
		else:
			Router.show_system()
		return
	match n.type:
		MapGen.NodeType.STATION:
			# (docks only at the station; elsewhere in its system, the map to fly there)
			if Router.at_station(n):
				Router.show_station()
			else:
				Router.show_system()
		# The rows are the options now, so the button under them only ever leaves.
		MapGen.NodeType.SYSTEM:
			_plot_next_jump()
		MapGen.NodeType.PULSAR:
			if n.cleared:
				Router.show_system()
			else:
				Router.harvest_pulsar()
		# An unfought contact: a resumed run for FIGHT, the ordinary path for CORE.
		MapGen.NodeType.CORE:
			if n.cleared or n.fled or not Router.at_custodian(n):
				Router.show_system()
			else:
				Router.engage_here()
		_:
			Router.show_system()

## Only the page-turn sound plays; the button's click is off, per Jon's correction.
## Why: docs/why/SectorScreen.md#plot-jump-sound
func _plot_next_jump() -> void:
	if _cutaway != null:
		_cutaway.close_now()
	Router.show_system()


## The loot button opens a popup over the cutaway, else the two-grid screen.
func _open_loose() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n == null:
		return
	var from := _drawer.find_child("SectorLoot", true, false) as Control
	if _cutaway != null and from != null:
		_cutaway.open_popup(Run.sector_loot(n), from.get_global_rect())
	else:
		_open_sector_loot()


## Reads the place, not the node type: "a hab ring, lights on" tells you where
## you are in a way that "STATION" never will.
func _dead_strip_note() -> void:
	pass

## 18 is the measured chip height, not 16, and the row reserves it with or without chips.
## Why: docs/why/SectorScreen.md#pile-view
const CHIP_ROW_H := 18

class PileView extends Control:
	# `W` is the floor `END TURN` needs; a wider rail makes a landscape pile.
	# Why: docs/why/SectorScreen.md#rail-sizing
	const W := 68
	# 52 is the swept ceiling: the band is fixed at 170 and each pixel comes off the panel.
	# Why: docs/why/SectorScreen.md#rail-sizing
	const H := 88
	var count: int = 0
	var label: String = ""

	func _init() -> void:
		# `H`, plus the stack lean, the label and the same gap the rails have above them.
		custom_minimum_size = Vector2(W, H + 16 + SectorScreen.RAIL_DROP)
		# STOP, not IGNORE: a control that ignores the mouse never shows a tooltip.
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

	## The card is narrower than the column and tied to `W`, so a full stack equals a button.
	## Why: docs/why/SectorScreen.md#rail-sizing
	const CARD_W := W - 4

	## The lean is subtracted so the stack stays centred and does not move as it fills.
	## Why: docs/why/SectorScreen.md#pile-view
	func _card_x(shown: int) -> float:
		return float(W - CARD_W - maxi(shown - 1, 0) * 2) * 0.5

	func _draw() -> void:
		# Up to three backs for depth only; the number says how many.
		var shown: int = clampi(count, 0, 3)
		for i in range(shown - 1, -1, -1):
			# Offset down by the lean: `-i * 2` drew the backs above the control, over FLEE.
			# Why: docs/why/SectorScreen.md#pile-view
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
		draw_string(f, Vector2((W - nw) * 0.5 + 1, H * 0.5 + 11), LowHull.scr(self, n, UITheme.FS_HEAD, f),
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_HEAD, UITheme.ICE)
		var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
		draw_string(f, Vector2((W - lw) * 0.5, H + 14), LowHull.scr(self, label, UITheme.FS_SMALL, f),
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, UITheme.COLD)

## Rails start where a hovered card starts; the gap after the spacer makes 4 land on 8.
## Why: docs/why/SectorScreen.md#rail-sizing
const RAIL_TOP := 4

## A card's content starts a few px inside its frame; the 6 is paid out of the pile.
## Why: docs/why/SectorScreen.md#rail-sizing
const RAIL_DROP := 6


## The gap at the top of each rail. Both get it, or they stop being a pair.
func _rail_drop() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, RAIL_TOP)
	return c


func _build_hand() -> Control:
	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 6)
	# Both columns are top-aligned, as the left's chip row made paired rows drift apart.
	# Why: docs/why/SectorScreen.md#hand-layout
	var left := VBoxContainer.new()
	# Gaps of 4 so the top lines up with a hovered card; the cost comes off separations.
	left.add_theme_constant_override("separation", 4)
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.add_child(_rail_drop())

	# Same width as END TURN opposite, ordered the way you weigh a card's cost.
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
	nrg_box.tooltip_text = Widgets.tip("ENERGY\n\nWhat you have left to spend.")
	nrg_box.mouse_filter = Control.MOUSE_FILTER_STOP
	nrg_box.add_child(nrg)
	left.add_child(nrg_box)

	# Turn count sits under energy, as both are true of the whole turn. Mirrors FLEE.
	_deck_label = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var turn_box := PanelContainer.new()
	turn_box.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.PANEL2, UITheme.LINE, 0, 0, 4))
	turn_box.custom_minimum_size = Vector2(PileView.W, 13)
	turn_box.tooltip_text = Widgets.tip("TURN\n\nHow long this fight has been going on.")
	turn_box.mouse_filter = Control.MOUSE_FILTER_STOP
	turn_box.add_child(_deck_label)
	left.add_child(turn_box)


	# An expanding spacer levels the piles by construction; `RIGHT_GAP` needed re-measuring.
	# Why: docs/why/SectorScreen.md#hand-layout
	var draw_push := Control.new()
	draw_push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(draw_push)

	_draw_pile = PileView.new()
	_draw_pile.tooltip_text = Widgets.tip("DRAW\n\nWhat is left to draw from.\nClick to look.")
	_draw_pile.opened = func() -> void:
		_show_pile("DRAW PILE", combat.deck, true)
	left.add_child(_draw_pile)
	hand_row.add_child(left)

	_hand = HandView.new()
	_hand.card_grabbed.connect(_on_card_grabbed)
	_hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand.card_hovered.connect(_on_card_hovered)
	_hand.picked.connect(_on_card_picked)
	_view.preview = _drag_preview
	if not _view.slid.is_connected(_on_view_slid):
		_view.slid.connect(_on_view_slid)
	_hand.reordered.connect(_on_hand_reorder)
	hand_row.add_child(_hand)
	# WHERE THE HAND GOES WHILE STUNNED (Jon, Nov 5): an empty drawer says why
	_stun_note = UITheme.body(STUN_NOTE, UITheme.COLD, UITheme.FS_SMALL)
	_stun_note.name = "StunNote"
	_stun_note.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stun_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stun_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stun_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stun_note.visible = false
	_hand.add_child(_stun_note)
	# Ordered by how often each is pressed: END TURN, then FLEE, then the discard.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	right.add_child(_rail_drop())

	# Three buttons sum to 54 like ENERGY and TURN opposite, so the piles stay level.
	# Why: docs/why/SectorScreen.md#hand-layout
	_end_button = Widgets.button("END TURN", _on_end_turn)
	# 16 not 22: a bevel button floors near 17, so three plus a 22 gave 62 against 54.
	# Why: docs/why/SectorScreen.md#hand-layout
	_end_button.custom_minimum_size = Vector2(PileView.W, 16)
	_end_button.tooltip_text = Widgets.tip(END_TIP)
	# Own stylebox: the default bevel padding made END TURN 28 against FLEE's 16.
	_end_button.add_theme_stylebox_override("normal",
		UITheme.flat(UITheme.PANEL2, Color("#4a5f78"), 0, 1, 6))
	_end_button.add_theme_stylebox_override("hover",
		UITheme.flat(Color("#1d2836"), UITheme.ICE, 0, 1, 6))
	_end_button.add_theme_stylebox_override("pressed",
		UITheme.flat(Color("#243044"), UITheme.ICE, 0, 1, 6))
	# Override `disabled` too: the theme's pads 3 px, so a greyed button grew and shifted the rail.
	# Why: docs/why/SectorScreen.md#hand-layout
	_end_button.add_theme_stylebox_override("disabled",
		UITheme.flat(UITheme.PANEL, Color("#2b3746"), 0, 1, 6))
	right.add_child(_end_button)

	# Thin, and red, and never sitting beside the button you actually want.
	# Fleeing costs a run's worth of progress; it should take a deliberate aim.
	var flee := Widgets.button("FLEE", _on_flee)
	_flee_button = flee
	flee.custom_minimum_size = Vector2(PileView.W, 16)
	flee.tooltip_text = Widgets.tip("FLEE\n\nGet away on a Maneuver check.")
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

	# HAIL is the free exit rolling STEALTH; FLEE burns fuel and rolls MANEUVER.
	_hail_button = Widgets.button("HAIL", _on_hail)
	_hail_button.custom_minimum_size = Vector2(PileView.W, 16)
	# Yellow against FLEE's red, so the two exits do not look like one button twice.
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

	# Matches the left column's `CHIP_ROW_H` so both piles sit level; empty on purpose.
	var chip_gap := Control.new()
	# EXPANDING, like the left one. Neither rail needs to know how tall the other
	# is any more; both piles simply sit on the bottom.
	chip_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(chip_gap)

	_discard_pile = PileView.new()
	_discard_pile.opened = func() -> void:
		_show_pile("DISCARD PILE", combat.discard, false)
	_discard_pile.tooltip_text = Widgets.tip(DISCARD_TIP)
	right.add_child(_discard_pile)
	hand_row.add_child(right)
	_hand_wrap = Widgets.panel_with(hand_row)
	# Same height as the drawer so a fight is a clean swap; padding is 3 so 164 + 6 fits.
	# Why: docs/why/SectorScreen.md#hand-layout
	_hand_wrap.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 3, 12))
	_hand_wrap.custom_minimum_size = Vector2(0, DRAWER_H)
	_hand_wrap.size_flags_vertical = Control.SIZE_SHRINK_END
	# A holder lets the panel be lowered after a win; the root column measures the holder.
	# Why: docs/why/SectorScreen.md#hand-lowering
	_hand_holder = Control.new()
	_hand_holder.clip_contents = true
	_hand_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_holder.size_flags_vertical = Control.SIZE_SHRINK_END
	_hand_holder.custom_minimum_size = Vector2(0, DRAWER_H)
	_hand_holder.add_child(_hand_wrap)
	_hand_holder.resized.connect(func() -> void:
		_hand_wrap.size = Vector2(_hand_holder.size.x, maxf(DRAWER_H,
			_hand_wrap.get_combined_minimum_size().y)))
	return _hand_holder

## Seven cards across at `CARD_W` leave a margin; past that the flow wraps and scrolls.
## Why: docs/why/SectorScreen.md#pile-listing
const PILE_COLS := 7


## The draw pile is sorted so its hidden order is not shown; the discard reads newest first.
## Why: docs/why/SectorScreen.md#pile-listing
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
	# Any click reaching the backdrop is a click on nothing, so it closes the pile.
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
		# Cards stay playable-looking: a greyed list reads as cards taken, and none can be played.
		# Why: docs/why/SectorScreen.md#pile-listing
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
	# While a turn plays out the screen shows what the eye has seen; see `_hold`.
	if _hold:
		_dirty = true
		return
	# `Run.jump_to` emits before `jumped`, so a refresh here would repaint the next system.
	# Why: docs/why/SectorScreen.md#jump-commit
	if _phase == Phase.COMMITTING:
		return
	var n: MapGen.MapNode = Run.node_at()
	var at_war := fighting()
	_view.set_place(n)
	# WHAT THE EVENT IS ABOUT, in the scene while it is open or you are parked at
	# it (`LocalSubject`, the option's `subject`)
	LocalSubject.sync(_view, n, at_war)

	# (while the hand comes up, the bands and the plate are `_raise_band`'s)
	if not _raising:
		_hand_holder.visible = at_war and not _lowered
		# THE HOLDER, not the panel. The panel stays visible and keeps driving
		# the band's height; the holder is what collapses it during a fight.
		_quiet_holder.visible = not at_war
		# A hull bar is a combat readout; out of a fight the top bar carries the number.
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
	_blurb.text = MapGen.place_blurb(n)

	if not at_war:
		_fx_drop_player()
	if at_war:
		_view.show_enemies(combat.enemies, _on_card_dropped, _on_slot_hovered)
		_state.text = "ENGAGED - %d HOSTILE%s" % [
			combat.alive().size(), "" if combat.alive().size() == 1 else "S"]
		_refresh_player()
		_refresh_enemy()
		_refresh_hand()
	else:
		# Wrecks stay once emptied, per place, so the sector remembers a fight happened.
		# Why: docs/why/SectorScreen.md#wrecks
		var wrecks: Array = Run.wrecks_here(n)
		if not wrecks.is_empty():
			_view.show_wrecks(wrecks, _open_jetsam)
		else:
			_view.show_area(n)
		# The readout survives death on purpose. Hiding it at the moment the run
		# ends is how a game stops explaining what just happened to you.
		if Run.dead:
			_state.text = "THE SHIP IS LOST. THE RUN IS OVER."
		elif n.cleared:
			_state.text = "SALVAGE THE CUSTODIAN." if Router.final_loot else "PICKED CLEAN."
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
	# Only a found hull opens the rail: it is an offer, not a hold item.
	# Why: docs/why/SectorScreen.md#salvage-rail
	var mine := Run.found_hull != null
	var bag_here := n.index if loose > 0 else -1

	# Dismissal lives on `Run`, as the screen does not survive a jump; a new haul resets it.
	# Why: docs/why/SectorScreen.md#salvage-rail
	var hushed := Run.salvage_hushed(bag_here)
	# Just the hull: `MapNode.bag` is never filled now, so it opened an empty panel.
	var has := mine and not fighting()
	_salvage_wrap.visible = has and not hushed
	if not _salvage_wrap.visible:
		return

	# The bag names itself: its parts are not yours yet, and go when anyone reaches.
	_salvage_head.text = "A HULL, IF YOU WANT IT"

	if Run.found_hull != null:
		_salvage.add_child(Widgets.hull_row(Run.found_hull, "TRANSFER", 0, _on_salvage))
	# Modules only: the rail asks stow or fit, and a crate of ore answers neither.
	# Why: docs/why/SectorScreen.md#salvage-rail



## Your hull, under your hull.
func _refresh_self_plate() -> void:
	if _self_bar == null:
		return
	var cap := maxi(1, Run.max_hp())
	var hp := Run.hp if shown_hull < 0 else shown_hull
	_self_bar.max_value = cap
	_self_bar.value = hp
	_self_hp.text = "%d / %d" % [hp, cap]
	# Shows the name you gave the ship, not its chassis.
	if Run.hull != null:
		_self_name.text = Run.display_name().to_upper()
	# The same three bands the top bar uses, so a hull in trouble reads the same
	# wherever you happen to be looking.
	var frac := float(hp) / float(cap)
	_self_hp.add_theme_color_override("font_color",
		UITheme.LEAVE if frac < 0.34 else (UITheme.EMBER if frac < 0.67
			else UITheme.HULL_GREEN))
	# In a fight brace comes from `_refresh_player` and `_on_volley_landed`.
	if not fighting():
		_show_self_brace(0)
	_place_self_plate()


## Your brace on your hull bar, and its "+N" beside the hull's number.
func _show_self_brace(b: int) -> void:
	if _self_bar == null:
		return
	_self_bar.brace = b
	_self_brace.visible = b > 0
	_self_brace.text = "+%d" % b
	_self_brace.tooltip_text = Widgets.tip(
		"BRACE\n\nStops %d damage before your hull. Stays up, and costs 1 heat a turn." % b) \
		if b > 0 else ""


## Measured from the sprite, not its box: a fixed `PLATE_X` fraction drifted off the ship.
## Why: docs/why/SectorScreen.md#self-plate
func _place_self_plate() -> void:
	if _self_plate == null or _view == null:
		return
	var sv := _view.ship_view()
	if sv == null:
		return
	# Uses its own width, not `PLATE_W`: the box is as wide as its widest child.
	_self_plate.position = Vector2(
		sv.position.x + sv.size.x * 0.5 + sv.ship_offset_x()
			- _self_plate.size.x * 0.5,
		sv.position.y + sv.size.y * 0.5 + sv.ship_bottom_y() + PLATE_AIR)



func _refresh_player() -> void:
	if not fighting():
		return
	if _hold:
		_dirty = true
		return
	_energy.setup(BoxGauge.Mode.ENERGY, Run.reactor(), combat.energy)
	_energy_text.text = "%d/%d" % [combat.energy, Run.reactor()]
	_fx_sync_player()

	# Effects are icons, not words; colours match the old words and say whose they are.
	# Why: docs/why/SectorScreen.md#status-chips
	# Brace is on the hull bar instead.
	_show_self_brace(combat.brace)
	Widgets.clear(_player_chips)
	if combat.block > 0:
		_player_chips.add_child(StatusChip.make(&"block", str(combat.block),
			Color("#3a4a6e"), "BLOCK\n\nStops %d damage this turn." % combat.block))
	if combat.lock_on > 0:
		_player_chips.add_child(StatusChip.make(&"lock", "+%d" % combat.lock_on,
			Color("#6e5a3a"), "LOCK ON\n\nYour next attack deals %d more per hit."
				% combat.lock_on))
	# Named by the card keywords `KW_NEGATE` and `KW_GROWS` (tutorial audit, Oct 22).
	if combat.negate_next:
		_player_chips.add_child(StatusChip.make(&"slip", "", UITheme.GOOD,
			"%s\n\nThe next attack on you misses." % CardData.KW_NEGATE.to_upper()))
	# No salvo chip: it was not a status, and the live number now prints on the card.
	# Why: docs/why/SectorScreen.md#status-chips
	if combat.feedback > 0:
		_player_chips.add_child(StatusChip.make(&"feedback", str(combat.feedback),
			Color("#6e3a4a"), "FEEDBACK\n\nAttackers take %d back." % combat.feedback))
	if combat.adapt_bonus > 0:
		_player_chips.add_child(StatusChip.make(&"adapt", "+%d" % combat.adapt_bonus,
			Color("#4a6e3a"), "%s\n\nCards that grow deal %d more."
				% [CardData.KW_GROWS.to_upper(), combat.adapt_bonus]))
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

## RULING 8: a disabled button states what it wants; label has the reason, tooltip the cause.
## Why: docs/why/SectorScreen.md#gate-buttons
func _refresh_gate(b: Button, label: String, why: String, cause: StringName,
		tips: Dictionary, lit: Color) -> void:
	if b == null:
		return
	if not fighting():
		b.disabled = true
		return
	# A finished or playing-out fight offers no exit: HAIL stayed bright, FLEE misreported.
	# Why: docs/why/SectorScreen.md#gate-buttons
	if combat.finished or _hold or _opening:
		b.disabled = true
		b.text = label
		b.add_theme_color_override("font_color", UITheme.COLD)
		return
	b.disabled = why != ""
	b.text = why if why != "" else label
	b.add_theme_color_override("font_color", UITheme.COLD if why != "" else lit)
	b.tooltip_text = Widgets.tip("%s\n\n%s" % [label, str(tips.get(cause, tips[&""]))])


## FLEE can be shut by a miss or by the core's guard; either needs a stated reason.
func _refresh_flee() -> void:
	if not fighting():
		_refresh_gate(_flee_button, "FLEE", "", &"", {&"": ""}, UITheme.LEAVE)
		return
	_refresh_gate(_flee_button, "FLEE", combat.flee_reason(),
		combat.flee_cause(), {
			&"failed": "You tried. They are still here.",
			&"boss": "You cannot flee this fight.",
			&"stunned": "You are stunned.",
			&"": "Get away on a Maneuver check.",
		}, UITheme.LEAVE)


func _refresh_hail() -> void:
	if not fighting():
		_refresh_gate(_hail_button, "HAIL", "", &"", {&"": ""}, UITheme.CHILL)
		return
	_refresh_gate(_hail_button, "HAIL", combat.hail_reason(),
		combat.hail_cause(), {
			&"stunned": "You are stunned.",
			&"failed": "You already tried. They heard you.",
			&"struck": "Too late. You shot first.",
			&"fauna": "It does not have a radio.",
			&"boss": "This one is not here to deal.",
			&"": "Talk them down on a Stealth check.",
		}, UITheme.CHILL)


func _refresh_enemy() -> void:
	if not fighting():
		return
	if _hold:
		_dirty = true
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
	# Chips sit under their own enemy, so no ship-name prefix is needed.
	for i in combat.enemies.size():
		var row := _view.chips_for(i)
		if row == null:
			continue
		Widgets.clear(row)
		var e = combat.enemies[i]
		if e.hp <= 0:
			continue
		# The enemy uses the same icon chip; no brace chip, as the hull bar pips already show it.
		# Why: docs/why/SectorScreen.md#status-chips
		if e.block > 0:
			row.add_child(StatusChip.make(&"block", str(e.block),
				Color("#3a4a6e"), "BLOCK\n\nStops %d damage this turn." % e.block))

	_view.show_enemies(combat.enemies, _on_card_dropped, _on_slot_hovered)
	# Each ship's wreck cut ahead of its death, at the size its pack draws it
	# (a pack of three or more is drawn from half sheets; `EnemyArt.draw_scale`).
	for i2 in range(_foes_seen, combat.enemies.size()):
		var sl2 := _view.slot(i2)
		EnemyArt.warm_wreck(combat.enemies[i2], _death_style(i2),
			sl2.art.draw_scale if sl2 != null and sl2.art != null else 1.0)
	_foes_seen = combat.enemies.size()
	for i3 in combat.enemies.size():
		_fx_sync_enemy(i3)

## How many contacts this screen has drawn (each one's wreck is warmed once).
var _foes_seen := 0

func _refresh_hand() -> void:
	if not fighting():
		return
	if _hold or _opening:
		_dirty = true
		return
	# The hand reconciles rather than rebuilds, so cards slide into the gap a
	# played card leaves instead of the whole row snapping to new positions.
	_hand.sync(combat.hand, func(c): return combat.can_play(c), combat.choosing > 0,
		func(c): return combat.card_output(c),
		func(c): return combat.card_hot(c))
	# A card that left the hand takes its panel: a played card never sends its exit event.
	if _readout_for != null and (not is_instance_valid(_readout_for)
			or not combat.hand.has(_readout_for.card)):
		_clear_readout()
	_draw_pile.set_count(combat.deck.size(), "DRAW")
	_discard_pile.set_count(combat.discard.size(), "DISCARD")
	_deck_label.text = "TURN %d" % combat.turn
	# WAITING names who, as a silent grey button reads as a hang.
	if _stun_note != null:
		_stun_note.visible = combat.stunned and not combat.finished
	if combat.stunned:
		# STUNNED, greyed, and the tooltip says what it means (Jon, Nov 5)
		_end_button.text = "STUNNED"
		_end_button.tooltip_text = Widgets.tip(STUN_TIP)
	elif combat.waiting:
		var f := Net.fight_at(combat.shared_at)
		var names := PackedStringArray()
		if f != null:
			for p2 in f.waiting_on():
				# Never yourself: the local fight has not heard back and still lists you.
				if p2 == Net.local_id():
					continue
				var who := Net.name_of(p2)
				if who != "":
					names.append(who.to_upper())
		_end_button.text = "WAIT\n%s" % (names[0] if names.size() == 1
			else ("%d SHIPS" % names.size() if names.size() > 1 else "..."))
	else:
		# Text set here too: refresh restored a newline each time, so the button measured 24.
		# Why: docs/why/SectorScreen.md#hand-layout
		_end_button.text = "END TURN"
	if not combat.stunned:
		_end_button.tooltip_text = Widgets.tip(END_TIP)
	_end_button.disabled = combat.finished or combat.waiting or combat.stunned

# --------------------------------------------------------------------- input

## One function opens any container; the popup is named after it and built per open.
## Why: docs/why/SectorScreen.md#containers
func _open_jetsam(h: MapGen.Jetsam, title: String = "", direct: bool = false) -> void:
	if _transfer != null or h == null:
		return
	# THE CUSTODIAN'S BODY, clicked: its popup, with the win screen behind DONE
	if Router.final_loot and not direct and h == Router.core_body_here():
		Router.open_core_body()
		return
	var n: MapGen.MapNode = Run.node_at()
	if n == null:
		return
	_transfer = TransferView.new()
	add_child(_transfer)
	# Own sound: `menu_open` is a UI sound, and opening a hatch is not a UI moment.
	Audio.play(&"wreck_open")
	_transfer.setup(h, n, _close_transfer, true, title)


## Opened from outside with a follow-up, such as the custodian's body before the win.
func open_jetsam(h: MapGen.Jetsam, title: String, after: Callable) -> void:
	_open_jetsam(h, title, true)
	if _transfer != null and after.is_valid():
		_transfer._on_close = func() -> void:
			_close_transfer()
			after.call()


func has_open_container() -> bool:
	return _transfer != null


## `false` so asking does not create the pile: a door to nothing lies.
func _open_sector_loot() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n != null:
		_open_jetsam(Run.sector_loot(n))


func _close_transfer() -> void:
	if _transfer == null:
		return
	_transfer.queue_free()
	_transfer = null
	_refresh()


func _on_salvage(action: String, thing: Variant) -> void:
	match action:
		"install":
			Audio.act(&"module_install")
			Run.install_module(thing as ModuleData)
		"scrap":
			Audio.act(&"module_scrap")
			Run.scrap_module(thing as ModuleData)
		"uninstall":
			Audio.act(&"module_uninstall")
			Run.uninstall_module(thing as ModuleData)
		"take_hull":
			Audio.act(&"hull_transfer")
			Run.transfer_to_hull(thing as HullData)
			# Goes straight to the move: gear left on the pad blocked UNDOCK (Jon, Oct 23).
			# Why: docs/why/SectorScreen.md#salvage-rail
			Router.show_transfer()
			return
		"leave_hull":
			Run.found_hull = null
		"scrap_hull":
			# The frame you did not fly, for what its strip paid (`Widgets.hull_row`).
			Audio.act(&"module_scrap")
			Run.scrap_found_hull()
	_refresh()

## Hover prices a card against every enemy; the slot draws it so it reads as an answer.
## Why: docs/why/SectorScreen.md#drag-preview
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
		# Includes the ship's dissipation, or vent previews under-report by the whole radiator.
		bits.append("-%d HEAT" % mini(c.vent + Run.dissipation(), Run.heat))
	if c.draw > 0:
		bits.append("+%d CARD" % c.draw)
	if c.energy_gain > 0:
		bits.append("+%d NRG" % c.energy_gain)
	if c.lock_on > 0:
		bits.append("+%d NEXT" % c.lock_on)
	return " ".join(bits)

## Resolved by index, as `Combat.choose` takes: the sim and bot use the same door.
func _on_card_picked(card: CardData) -> void:
	if combat == null or combat.choosing <= 0:
		return
	combat.choose(combat.hand.find(card))


func _on_card_hovered(view: CardView, entered: bool) -> void:
	_show_readout(view, entered)
	# THE PART THAT GRANTS IT, LIT ON YOUR HULL (the cutaway's fight half)
	_light_source(view.card if entered and view != null else null)
	if not fighting() or not entered or combat.finished:
		_preview.text = ""
		return
	var c := view.card
	var aimable: bool = c.damage > 0 or c.damage_equals_heat or c.evoke > 0
	_preview.text = "HOLD AND AIM AT A TARGET" if aimable else "HOLD AND AIM AT YOUR HULL"

func _on_slot_hovered(_index: int, _entered: bool) -> void:
	pass


# ------------------------------------------------------------------ the cutaway

var _cutaway: CutawayView = null
## How many clicks on your ship were refused with the thud (for `-- cutawaytest`).
var denied_clicks := 0
var _ship_outline: CutawayView.Outline = null
## A ship arriving under an unmoved pointer is not pointed at; no outline until it moves.
## Why: docs/why/SectorScreen.md#ship-hover
var _still_pointer := Vector2.INF


func _hook_cutaway() -> void:
	var art := _view.ship_view()
	if art == null:
		return
	var slot := art.get_parent() as Control
	_ship_outline = CutawayView.Outline.new()
	_ship_outline.view = art
	_ship_outline.visible = false
	art.add_child(_ship_outline)
	if slot == null:
		return
	slot.gui_input.connect(_on_own_ship_input)
	slot.mouse_exited.connect(func() -> void:
		_ship_outline.visible = false
		slot.mouse_default_cursor_shape = Control.CURSOR_ARROW)


## An arrival is starting: whatever the pointer is resting on when the ship
## parks under it is not a hover (`_still_pointer`).
func _hold_outline() -> void:
	_still_pointer = Vector2(DisplayServer.mouse_get_position())
	if _ship_outline != null:
		_ship_outline.visible = false


## Whether your ship can be opened up now: out of a fight, not mid-jump, alive.
func cutaway_ready() -> bool:
	return not fighting() and _phase == Phase.NONE and not Run.dead 		and _cutaway == null and Run.hull != null and _transfer == null


func _on_own_ship_input(e: InputEvent) -> void:
	var art := _view.ship_view()
	var slot := art.get_parent() as Control
	# where on the art the event is (the event's own point, not the mouse's: a
	# harness pushes clicks without moving a pointer)
	var mev := e as InputEventMouse
	var at := (art.get_global_transform().affine_inverse() * (slot.get_global_transform() * mev.position)) 		if mev != null else art.get_local_mouse_position()
	var mpos := Vector2(DisplayServer.mouse_get_position())
	var press0 := e as InputEventMouseButton
	if _still_pointer != Vector2.INF and (mpos.distance_to(_still_pointer) >= 1.0 			or (press0 != null and press0.pressed)):
		_still_pointer = Vector2.INF
	if not cutaway_ready() or _still_pointer != Vector2.INF:
		# An unpressable ship shows no outline, and a click makes the dead-button thud.
		# Why: docs/why/SectorScreen.md#ship-hover
		_ship_outline.visible = false
		slot.mouse_default_cursor_shape = Control.CURSOR_ARROW
		var press := e as InputEventMouseButton
		if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT 				and _aim_view == null and CutawayView.on_hull(art, at):
			denied_clicks += 1
			Audio.denied()
		return
	var on := CutawayView.on_hull(art, at)
	if on != _ship_outline.visible:
		_ship_outline.visible = on
		_ship_outline.queue_redraw()
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW
	var mb := e as InputEventMouseButton
	if on and mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		slot.accept_event()
		open_cutaway()


# ------------------------------------------------------------ the zoom ladder
# LOCAL is one distance of four; the scene scales for real parallax.
# Why: docs/why/SectorScreen.md#zoom-ladder
var _lad := {}
var _lad_zs := 1.0


func ladder_ready() -> bool:
	return _view != null and _view.size.x > 10.0


func ladder_picture() -> Rect2:
	return _view.get_global_rect()


func ladder_scale() -> float:
	return _lad_zs


func _ladder_ship() -> Vector2:
	var art := _view.ship_view() if _view != null else null
	if art == null:
		return _view.get_global_rect().get_center()
	var ink := Rect2(art.ink_rect())
	return art.get_global_transform() * art.canvas_to_local(ink.get_center())


## THE STATION'S SIDE (`StationFace`), with the one camera on: the hull and its
## hangar behind your ship, the mouth's frame in front of it.
var _face: StationFace = null
var _face_front: StationFace = null


func _attach_station_face() -> void:
	var n: MapGen.MapNode = Run.node_at()
	# (the station's side is beside you only AT the station: at a world of its
	# system it drew there too, and DOCK played into it -- dock:A)
	if n == null or n.type != MapGen.NodeType.STATION or not ZoomLadder.chosen() or _view == null 			or not Router.at_station(n):
		return
	var pair := StationFace.make_pair(n, _view)
	_face = pair[0]
	_face_front = pair[1]
	_view.add_child(_face)
	_view.move_child(_face, _view._row.get_index())
	_view.add_child(_face_front)
	_view.move_child(_face_front, _view._row.get_index() + 1)
	# (the ring stands down: the station is its side now)
	_view._area.modulate.a = 0.0
	_view.resized.connect(_place_face)
	# The hallway tracks the ship's slot: built early at UNDOCK it sat 4 px low.
	# Why: docs/why/SectorScreen.md#docking
	var art := _view.ship_view()
	if art != null:
		art.resized.connect(_place_face)
	_place_face.call_deferred()


func _place_face() -> void:
	if _face == null or not is_instance_valid(_face):
		return
	var sky: LocalSky = _view.backdrop
	var tint := Color(1, 1, 1)
	if sky != null:
		tint = Color(sky._tint.x, sky._tint.y, sky._tint.z)
	# Level with the ship's middle without its idle bob, so the station stays put.
	var mid := _ladder_ship()
	var art := _view.ship_view() if _view != null else null
	if art != null:
		mid -= art.get_global_transform().basis_xform(Vector2(0.0, float(art.bob_offset()) * float(art._k)))
	for f: StationFace in [_face, _face_front]:
		f.ship_y = (f.get_global_transform().affine_inverse() * mid).y
		f.tint = tint
		f.queue_redraw()


func _ladder_ring() -> Vector2:
	if _face != null and is_instance_valid(_face):
		return _face.mouth_g()
	var a: Control = _view._area if _view != null else null
	if a != null and a.is_visible_in_tree() and a.size.x > 1.0:
		return a.get_global_rect().get_center()
	return _ladder_ship()


## The world the ship is in orbit of, drawn close behind the fight: its centre on
## screen and its radius, under the camera as it is now.
func ladder_world() -> Dictionary:
	var sky: LocalSky = _view.backdrop if _view != null else null
	if sky == null or sky.orbit_target < 0 or sky._near.is_empty() or float(sky._near[0][3]) <= 0.0:
		return {}
	# (the map's world, handed over and still being moved: where it is drawn)
	if not sky._hand.is_empty() and sky._box != null:
		return {"c": sky._box.get_global_transform() * ((sky._hand.get("drawn", sky._hand.at) as Vector2) * 0.5), "r": float(sky._hand.r)}
	if sky.has_method(&"near_info"):
		var ni: Dictionary = sky.near_info()
		if not ni.is_empty():
			return {"c": ni.at, "r": float(ni.r)}
	var at: Vector2 = sky._near[0][1]
	return {"c": sky.get_global_transform() * sky._zp(at, LocalSky.Z_NEAR), "r": float(sky._near[0][3]) * sky._zl(LocalSky.Z_NEAR)}


## The plane as LOCAL draws it: its star on screen, plane px to screen px, and
## its slant.
func ladder_plane() -> Dictionary:
	var sky: LocalSky = _view.backdrop if _view != null else null
	if sky == null or sky.layout == null:
		return {}
	return {"o": sky.get_global_transform() * sky._zp(sky.band_origin(), LocalSky.Z_STAR), "s": sky._s * sky._zl(LocalSky.Z_BAND), "tilt": LocalSky.TILT}


func ladder_anchor(other: int, seam: int, design: String) -> Vector2:
	if other == ZoomLadder.STATION:
		return _ladder_ring()
	if seam == 2 and design == "C":
		var w := ladder_world()
		if not w.is_empty():
			return w.c
	return _ladder_ship()


func ladder_pre(target: int, seam: int, design: String) -> float:
	if not ladder_ready():
		return 0.0
	if seam == 3 and design == "D":
		return 1.0
	if seam == 3 and design == "B":
		# the hull flies all the way into the ring before the hangar takes over
		return 1.0
	if seam == 2 and design == "B":
		return 0.5
	return 1.0


## LOCAL's UI leaves before the camera moves and returns after it lands.
var _chrome_band := false


func ladder_chrome(k: float) -> void:
	if k > 0.0 and _quiet_holder != null and not _quiet_holder.has_meta(&"lad_a0"):
		_chrome_band = _events != null and is_instance_valid(_events) and _events.visible
	ZoomLadder.fade_chrome(_quiet_holder, k)
	if _chrome_band:
		ZoomLadder.fade_chrome(_events, k)
	if k <= 0.0:
		_chrome_band = false


## Where the held picture's anchor is (and its world, for the world handoff):

## this camera's far end is placed on it. Taken by the next `ladder_cam_begin`.
var _lad_meet := {}


func ladder_meet(at: Vector2, world: Dictionary) -> void:
	_lad_meet = {"at": at, "world": world}


func ladder_cam_begin(other: int, seam: int, design: String) -> void:
	if not ladder_ready():
		return
	ladder_cam_end()
	var meet := _lad_meet
	_lad_meet = {}
	var fixed := ladder_anchor(other, seam, design)
	var zs1 := 0.22
	var to1 := fixed
	var hull_flies := seam == 3 and (design == "B" or design == "D") and other == ZoomLadder.STATION
	if other == ZoomLadder.STATION:
		zs1 = 2.4
		if hull_flies:
			# into the mouth: the bulkhead hides the rest (B); straight through it
			# until the hangar fills the picture (D)
			zs1 = 2.0 if design == "B" else 4.2
		to1 = _view.get_global_rect().get_center()
	elif seam == 2 and design == "C":
		zs1 = 0.3
	elif seam == 2 and design == "B":
		zs1 = 0.55
	if not meet.is_empty() and not hull_flies:
		to1 = meet.at
		# the world you orbit, drawn at the held world's size
		var w := ladder_world()
		var wo: Dictionary = meet.world
		if seam == 2 and design == "C" and not w.is_empty() and not wo.is_empty():
			zs1 = clampf(float(wo.r) / maxf(float(w.r), 1.0), 0.1, 0.8)
	var scenes: Array = []
	for c: Control in [LocalSubject.of(_view), _face, _view._row, _face_front, _view.dust, _view.fx]:
		if c != null and is_instance_valid(c):
			scenes.append([c, c.scale, c.offset_left, c.offset_top, c.offset_right, c.offset_bottom, c.size,
				c.get_global_transform().affine_inverse() * fixed, c.get_global_transform().affine_inverse()])
	var sky: LocalSky = _view.backdrop
	# 2C moves by fractions of a pixel (Jon prefers smooth to stepped)
	var smooth := seam == 2 and design == "C"
	# 3B: YOUR SHIP FLIES INTO THE RING (and back out of it, undocking): the hull
	# itself, carried from where it sits to the ring's middle, getting smaller
	var ship := {}
	var art := _view.ship_view()
	if hull_flies and art != null:
		var ink := Rect2(art.ink_rect())
		# Middle without the idle bob, so the path is the same whenever it set off.
		ship = {"art": art, "pos": art.position, "scale": art.scale, "pivot": art.pivot_offset,
			"mid": art.canvas_to_local(ink.get_center()) - Vector2(0.0, float(art.bob_offset()) * float(art._k))}
		art.pivot_offset = ship.mid
	_lad = {"fixed": fixed, "to1": to1, "zs1": zs1, "scenes": scenes, "smooth": smooth, "ship": ship,
		"sky_fixed": _sky_pt(sky, fixed) if sky != null else Vector2.ZERO,
		"bar": _quiet_holder.modulate.a if _quiet_holder != null else 1.0, "x0": position.x}
	# The camera follows the ship down the hallway; its right edge never enters the view.
	if hull_flies and _face != null and is_instance_valid(_face):
		var art2 := _view.ship_view()
		var s_end := StationFace.SHIP_END_SCALE
		var len_end := 236.0 * s_end
		if art2 != null:
			var ink2 := Rect2(art2.ink_rect())
			var dim := ink2.size * art2.scale
			if dim.x > 1.0 and dim.y > 1.0:
				s_end = minf(s_end, minf(StationFace.SHIP_END_LEN / dim.x, StationFace.SHIP_END_H / dim.y))
				len_end = dim.x * s_end
		var xf0 := _face.get_global_transform()
		var start := xf0.affine_inverse() * _ladder_ship() - _face.origin()
		var berth := Vector2(StationFace.TAIL_IN + len_end * 0.5, StationFace.ROW)
		# (docking: LOCAL is the screen being left; undocking it is the one coming)
		var inward := ZoomLadder.active == null or ZoomLadder.active.old == self
		# (docking: from the mooring, where the arrival leaves your ship, all the
		# way in -- `hold` is the fraction of the path the ENTER sets off from)
		var hold := 0.0
		var dip_s := ZoomLadder.DOCK_DIP_S
		# Measured both ways: undocking leaves down the same path, so this is also `ladder_up_s`.
		if art2 != null:
			var ink3 := Rect2(art2.ink_rect())
			var to_plate := xf0.affine_inverse()
			var a3 := to_plate * (art2.get_global_transform() * art2.canvas_to_local(ink3.position))
			var b3 := to_plate * (art2.get_global_transform() * art2.canvas_to_local(ink3.end))
			var run := berth.x - start.x
			# Fraction at which all bolted-on kit has passed the recess, so the dip may start.
			var fg := art2.fitted_rect_global()
			var dl := (a3.x + b3.x) * 0.5 - (to_plate * fg.position).x
			var din := run + dl * (1.0 - s_end)
			if din > 1.0:
				var f_in := clampf((StationFace.RECESS.end.x + 2.0 - start.x + dl) / din, hold, 1.0)
				var ue_in := sqrt(clampf((f_in - hold) / maxf(1.0 - hold, 0.001), 0.0, 1.0))
				dip_s = clampf(ZoomLadder.DOCK_ENTER_S * (1.0 - ue_in), 0.1, ZoomLadder.DOCK_DIP_S)
		# Sky and dust hold still while docking and undocking; the camera is given back after.
		# Why: docs/why/SectorScreen.md#docking
		var skyc: LocalSky = _view.backdrop
		if skyc != null and is_instance_valid(skyc):
			_lad["sky_hold0"] = skyc.cam_hold
			if inward:
				skyc.cam_hold = skyc.cam_follow
			else:
				var rest_x := float((ship.pos as Vector2).x) if not ship.is_empty() else 0.0
				skyc.cam_hold = Vector2(roundf(rest_x * LocalSky.CAM_FOLLOW), 0.0)
		# Lights are kept as the move found them; a wake in progress finishes lit.
		# Why: docs/why/SectorScreen.md#docking
		if inward and (_wake_t >= 0.0 or _wake_owed):
			_wake_finish()
		_lad["hall"] = {"xf": xf0, "o": _face.origin(),
			"right": _view.get_global_rect().end.x, "vc": _view.get_global_rect().get_center(), "s_end": s_end,
			"berth": berth, "start": start, "path": absf(berth.x - start.x), "inward": inward, "beat": &"",
			"hold": hold, "dip_s": dip_s, "heard": false, "hidden": _dock_hidden and inward,
			"power0": _face.power, "row": randi() % ShipView.FLAMEOUTS.size()}
	# 2C, LEAVING for the map (no meeting point: this is the screen being left):
	# the world you orbit carried in its own picture, as the map's is carried in
	if smooth and meet.is_empty() and other == ZoomLadder.MAP and sky != null and is_instance_valid(sky) \
			and sky.hand_own(_sky_pt(sky, fixed)):
		_lad["hand_R"] = float(sky._near[0][3])


## The sky's 960x540 frame, which `set_zoom` takes and `near_info` reads back.
func _sky_pt(sky: LocalSky, g: Vector2) -> Vector2:
	if sky._box != null and is_instance_valid(sky._box):
		return (sky._box.get_global_transform().affine_inverse() * g) * 2.0
	return sky.get_global_transform().affine_inverse() * g


func ladder_cam(k: float) -> void:
	if _lad.is_empty():
		return
	var hall: Dictionary = _lad.get("hall", {})
	# (the camera's place along the move: with the station's hallway, docking
	# and undocking, it stays where it is, below)
	var kc := k
	var hk := clampf(k, 0.0, 1.0)
	var hall_fly := hk * hk
	var follow := 0.0
	var beat := &""
	if not hall.is_empty() and bool(hall.get("inward", true)):
		# Five steps on one linear clock; the camera holds still and only the ship moves.
		# Why: docs/why/SectorScreen.md#docking
		var t := hk * ZoomLadder.dock_approach_s()
		var su := ZoomLadder.dock_step_at(t)
		var step := int(su.x)
		var u := su.y
		var hold := float(hall.get("hold", 0.0))
		var ue := 0.0
		var blk := 0.0
		kc = 0.0
		follow = 0.0
		hall_fly = hold
		if step == 0:
			# 1. CUT: LOCAL down to black, your ship still at its mooring
			beat = &"cut"
			blk = ZoomLadder._ease(u)
		elif step == 1:
			# 2. ARRIVE: up from black, and the arrival itself flies it in
			beat = &"arrive"
			blk = 1.0 - ZoomLadder._ease((t - ZoomLadder.dock_step_from(1)) / maxf(ZoomLadder.FADE_IN_S, 0.001))
		elif step <= 3:
			# 3-4. AT ITS MOORING, idling: a breath (BEAT), and the station powers
			# up to meet it (POWER)
			beat = [&"beat", &"power"][step - 2]
		else:
			# Final move in: only your ship moves, so dust and station do not parallax (Jon).
			# Why: docs/why/SectorScreen.md#docking
			beat = &"enter"
			ue = u
			hall_fly = hold + (1.0 - hold) * ue * ue
		hall["beat"] = beat
		hall["step"] = step
		hall["t"] = t
		hall["t_arrive"] = t - ZoomLadder.dock_step_from(1)
		# (the map's DOCK came up on LOCAL from its own black, your ship already
		# off it: no cut of its own)
		if bool(hall.get("hidden", false)):
			blk = 0.0
		hall["black"] = clampf(blk, 0.0, 1.0)
		hall["u_power"] = 0.0 if step < 3 else (u if step == 3 else 1.0)
		hall["u_enter"] = ue
	elif not hall.is_empty():
		# Undocking holds the background as docking does: eased out down the ENTER's path, station lit.
		# Why: docs/why/SectorScreen.md#undocking
		kc = 0.0
		beat = &"out"
		hall["beat"] = beat
		hall["t"] = (1.0 - hk) * ZoomLadder.DOCK_ENTER_S
		hall_fly = ZoomLadder._ease(hk)
	var zs := pow(float(_lad.zs1), kc)
	_lad_zs = zs
	var to_g: Vector2 = (_lad.fixed as Vector2).lerp(_lad.to1, kc)
	var fixed_g: Vector2 = _lad.fixed
	var shift := Vector2(position.x - float(_lad.get("x0", position.x)), 0.0)
	if not hall.is_empty():
		var a := _hall_anchor(hall, kc, follow, hall_fly)
		fixed_g = a
		to_g = a.lerp(hall.vc, kc)
	for w: Array in _lad.scenes:
		# (a piece freed mid-move -- the event's subject, changed -- is let go:
		# checked before it is typed, or the assignment itself is the error)
		if not is_instance_valid(w[0]):
			continue
		var sc: Control = w[0]
		sc.scale = (w[1] as Vector2) * zs
		# (the screen itself may be carried sideways -- 3B's pan -- and the scene
		# with it)
		var to := (sc.get_parent() as CanvasItem).get_global_transform().affine_inverse() * (to_g + shift)
		var at_rest: Vector2 = w[7] if hall.is_empty() else (w[8] as Transform2D) * fixed_g
		sc.position = to - at_rest * sc.scale
		if not bool(_lad.smooth):
			sc.position = sc.position.round()
		sc.size = w[6]
	if not hall.is_empty():
		# The station wakes while the ship waits at its mouth; undocking, it stays lit.
		var pw := 0.0
		var warn := 0.0
		if bool(hall.get("inward", true)):
			# Dark until the POWER step apart from beacons; lit through the CUT if already lit.
			var up := float(hall.get("u_power", 0.0))
			pw = clampf(up / WAKE_POWER_BY, 0.0, 1.0)
			if beat == &"cut":
				pw = float(hall.get("power0", 0.0))
			# A station already awake stays lit; its power-on is not replayed, only the clearance.
			var lit0 := float(hall.get("power0", 0.0)) >= 1.0
			if lit0:
				pw = 1.0
			if pw >= 1.0 and not lit0:
				_mark_lit()
			if beat == &"power":
				warn = 1.0 if up < WARN_CLEAR else 2.0
			elif beat == &"enter":
				warn = 2.0 + clampf(float(hall.get("u_enter", 0.0)) / 0.6, 0.0, 1.0)
		else:
			# (undocking: all on, and left on)
			pw = 1.0
		# (heard as it comes on, docking into a sleeping station; never for one
		# already lit, an undock, or a press that ends the dock at once)
		var heard := bool(hall.get("inward", true)) and float(hall.get("power0", 0.0)) < 1.0 \
			and not (ZoomLadder.active != null and ZoomLadder.active._cut) and Router.animating()
		for f: StationFace in [_face, _face_front]:
			if f != null and is_instance_valid(f):
				f.audible = heard
				f.dock_k = clampf(k, 0.0, 1.0)
				f.power = pw
				f.warn = warn
	var sky: LocalSky = _view.backdrop
	if sky != null and is_instance_valid(sky):
		sky.set_zoom(zs, _lad.sky_fixed if hall.is_empty() else _sky_pt(sky, fixed_g + shift), _sky_pt(sky, to_g + shift))
		# the handed-over world: where the world's middle goes, at its size
		if _lad.has("hand_R"):
			sky.near_hand(_sky_pt(sky, to_g), float(_lad.hand_R) * zs, 1.0 - k, _sky_pt(sky, _lad.fixed))
	var ship: Dictionary = _lad.ship
	if not ship.is_empty() and is_instance_valid(ship.art):
		var art: ShipView = ship.art
		var q := clampf(k, 0.0, 1.0)
		var eq := q * q * (3.0 - 2.0 * q)
		var slot := art.get_parent() as Control
		var ring := slot.get_global_transform().affine_inverse() * _ladder_ring()
		# (with the station's side up, into its mouth and on into the hangar,
		# a little smaller with the depth; into the ring and gone without it)
		var deep := _face != null and is_instance_valid(_face)
		var fly := eq if not deep else clampf(q * 1.25, 0.0, 1.0)
		fly = fly * fly * (3.0 - 2.0 * fly)
		if deep and not hall.is_empty():
			fly = hall_fly
			var berth := slot.get_global_transform().affine_inverse() * _face.plate_g(hall.berth)
			var p0: Vector2 = ship.pos
			var p1: Vector2 = berth - (ship.mid as Vector2)
			var docking := bool(hall.get("inward", true))
			var step := int(hall.get("step", 0))
			# (and on, a frame past the ARRIVE if need be, to its own end: it
			# runs from the frame it was called on)
			if docking and (step <= 1 or (step <= 3 and art.arrive_driven)):
				_dock_arrival(art, hall, p0)
			else:
				# FROM ITS MOORING (docking) or the bay (undocking), down the
				# hallway (`hall_fly`, one curve), shrinking with the depth
				art.position = p0.lerp(p1, fly)
				art.scale = (ship.scale as Vector2) * lerpf(1.0, float(hall.s_end), fly)
			if docking:
				_dock_burn(art, hall, step == 4 and float(hall.get("t", 0.0)) < ZoomLadder.dock_approach_s() - ladder_dip_s())
			else:
				_undock_engines(art, hall)
		else:
			art.position = (ship.pos as Vector2).lerp(ring - (ship.mid as Vector2) + (Vector2(24, 0) if deep else Vector2.ZERO), fly)
			art.scale = (ship.scale as Vector2) * lerpf(1.0, 0.62 if deep else 0.2, fly)
		art.visible = deep or eq < 0.9
		# (the map's DOCK: kept off LOCAL until its arrival, `dock_hidden`)
		if deep and not hall.is_empty() and bool(hall.get("hidden", false)) and int(hall.get("step", 0)) == 0:
			art.visible = false
	# (the bar along the bottom is the screen's, not the scene's: it leaves before
	# the camera moves and comes back after it lands, `ladder_chrome`)


## Docking: how long before the hand-off the dip to black may begin, s (your
## ship all in behind the hull by then), or -1 where this is no dock.
func ladder_dip_s() -> float:
	var hall: Dictionary = _lad.get("hall", {})
	if hall.is_empty() or not bool(hall.get("inward", true)):
		return -1.0
	return float(hall.get("dip_s", ZoomLadder.DOCK_DIP_S))


## How long LOCAL takes to rise from the yard's black when undocking, else -1.
func ladder_up_s() -> float:
	var hall: Dictionary = _lad.get("hall", {})
	if hall.is_empty() or bool(hall.get("inward", true)):
		return -1.0
	return float(hall.get("dip_s", ZoomLadder.DOCK_DIP_S))


## Arrived by undocking: the station stays lit, whether or not the undock played.
func station_awake() -> void:
	_mark_lit()
	for f: StationFace in [_face, _face_front]:
		if f != null and is_instance_valid(f):
			f.audible = false
			f.power = 1.0


## The map's DOCK that did not dock after all (`ZoomLadder._chain_go`): your ship
## back on LOCAL where it sits.
func dock_unhide() -> void:
	if not _dock_hidden:
		return
	_dock_hidden = false
	var art := _view.ship_view() if _view != null else null
	if art != null:
		art.visible = true


## Docking: LOCAL's own black for the CUT (0 none, 1 all), which the ladder
## draws (`ZoomLadder`'s pre-roll).
func ladder_black() -> float:
	var hall: Dictionary = _lad.get("hall", {})
	if hall.is_empty() or not bool(hall.get("inward", true)):
		return 0.0
	return float(hall.get("black", 0.0))


## The dock's entrance is a new system's arrival, stepped on the ladder's clock.
## Why: docs/why/SectorScreen.md#docking
func _dock_arrival(art: ShipView, hall: Dictionary, p0: Vector2) -> void:
	var ship: Dictionary = _lad.ship
	if int(hall.get("step", 0)) == 0:
		art.position = p0
		art.scale = ship.scale
		return
	if not bool(hall.get("heard", false)):
		hall["heard"] = true
		art.position = p0
		art.scale = ship.scale
		var clip := _ship_arrives(art, 0.0)
		art.arrive_driven = true
		hall["clip"] = clip
		# (its clock from this frame, as an arrival's runs from the frame it is
		# called on)
		hall["t_called"] = float(hall.get("t_arrive", 0.0))
		Audio.play(clip, 0.0)
	art.arrive_step(float(hall.get("t_arrive", 0.0)) - float(hall.get("t_called", 0.0)))


## The one call every arrival on LOCAL makes; returns the clip once the wait is over.
func _ship_arrives(art: ShipView, wait: float) -> StringName:
	_hold_outline()
	return art.arrive(ARRIVE_BOB, wait + ShipView.ARRIVE_LEAD_S)


## The ENTER's engines are lit from its first frame and cut once the ship is in.
const DOCK_BURN_LEVEL := 1.0


func _dock_burn(art: ShipView, hall: Dictionary, on: bool) -> void:
	if on == bool(hall.get("burning", false)):
		if on:
			Audio.ship_thrust(DOCK_BURN_LEVEL)
		return
	hall["burning"] = on
	art.burn(on)
	if on:
		Audio.ship_thrust(DOCK_BURN_LEVEL)
	else:
		Audio.ship_thrust_off()


## Engines idle as your ship backs out, then the arrival's coughs; silent if cut short.
## Why: docs/why/SectorScreen.md#undocking
func _undock_engines(art: ShipView, hall: Dictionary) -> void:
	var t := float(hall.get("t", 0.0))
	var row := int(hall.get("row", 0))
	var cough_at := ZoomLadder.DOCK_ENTER_S - UNDOCK_COAST_S - ShipView.sputter_s(row)
	if t < cough_at:
		return
	if not hall.has("cough_clip"):
		hall["cough_clip"] = art.sputter(row)
		hall["cough_at"] = cough_at
		if not (ZoomLadder.active != null and ZoomLadder.active._cut):
			Audio.play(hall.cough_clip as StringName, 0.0, 0, Audio.SHIP_DB + linear_to_db(DOCK_BURN_LEVEL), 1.0,
				ShipView.sputter_from_s(row) + (t - cough_at))
	art.sputter_step(t - cough_at)


## Undocking: the last of the way to the mooring coasted at the idle, s, after
## the flameout's last cough.
const UNDOCK_COAST_S := 0.4
## Dock timing: lights on by `WAKE_POWER_BY`, warning lights green at `WARN_CLEAR`.
const WAKE_POWER_BY := 0.85
const WARN_CLEAR := 0.86




## Ship speed at the hallway's end, which the camera and pan carry on with.
func ladder_track_speed(dur: float) -> float:
	var hall: Dictionary = _lad.get("hall", {})
	if hall.is_empty():
		return 0.0
	if bool(hall.get("inward", true)):
		# (docking: the end of the move in, fly = hold + (1 - hold) u^2)
		return 2.0 * (1.0 - float(hall.get("hold", 0.0))) * float(hall.path) * float(_lad.zs1) / maxf(ZoomLadder.DOCK_ENTER_S, 0.001)
	# (undocking the camera stays at the scene's own size: its speed out of the
	# berth, fly = k squared run back over `dur`)
	return 2.0 * float(hall.path) / maxf(dur, 0.001)


## Where the drum's panels tile on screen now (the plate's seam at `HULL_X0`)
## and its row `ROW`: the pan's hull carries on from them.
func ladder_hull_at() -> Vector2:
	if _face == null or not is_instance_valid(_face):
		return Vector2.INF
	return Vector2(_face.plate_g(Vector2(_face.hull_x0(), 0)).x, _face.plate_g(Vector2(0, StationFace.ROW)).y)


## The side the pan's hull is (`StationSides`), and its layers' parallax as the
## approach left them, so the pan carries on the hull LOCAL drew.
func ladder_hull_side() -> Array:
	if _face_front == null or not is_instance_valid(_face_front):
		return []
	return [_face_front.side, _face_front.par.duplicate()]


## The camera anchor runs along the plate's row, then turns to follow the ship.
func _hall_anchor(hall: Dictionary, kc: float, w: float, fly: float) -> Vector2:
	var xf: Transform2D = hall.xf
	var o: Vector2 = hall.o
	var frame := lerpf(StationFace.A0, StationFace.A1, kc)
	var ship_x := lerpf((hall.start as Vector2).x, (hall.berth as Vector2).x, fly)
	return xf * (o + Vector2(lerpf(frame, ship_x, w), StationFace.ROW))


func ladder_cam_end() -> void:
	if _lad.is_empty():
		return
	var hall_x: Dictionary = _lad.get("hall", {})
	var undocked := not hall_x.is_empty() and not bool(hall_x.get("inward", true))
	# (a press that ended the move at once: `ZoomLadder.finish_now`)
	var cut := ZoomLadder.active != null and ZoomLadder.active._cut
	for w: Array in _lad.scenes:
		# (a piece freed mid-move -- the event's subject, changed -- is let go:
		# checked before it is typed, or the assignment itself is the error)
		if not is_instance_valid(w[0]):
			continue
		var sc: Control = w[0]
		sc.scale = w[1]
		sc.offset_left = w[2]
		sc.offset_top = w[3]
		sc.offset_right = w[4]
		sc.offset_bottom = w[5]
	# The row is measured at the band as now: a moved band left the ship low, plate under the hand.
	# Why: docs/why/SectorScreen.md#zoom-ladder
	_view.reapply_bleed()
	var sky: LocalSky = _view.backdrop
	if sky != null and is_instance_valid(sky):
		sky.end_hand()
		sky.set_zoom(1.0, Vector2.ZERO, Vector2.ZERO)
	for f: StationFace in [_face, _face_front]:
		if f != null and is_instance_valid(f):
			f.audible = false
			f.dock_k = 0.0
			# (undocked, the station stays lit: a working station; and one woken
			# for this visit stays lit, whatever became of the dock)
			f.power = 1.0 if undocked or _station_lit(Run.node_at()) else 0.0
			f.warn = 0.0
	# (a dock cut short by a press takes its power-on's sounds with it)
	if cut and not undocked and not hall_x.is_empty():
		Audio.hush(StationFace.power_sounds())
	var ship: Dictionary = _lad.ship
	if not ship.is_empty() and is_instance_valid(ship.art):
		var art: ShipView = ship.art
		art.position = ship.pos
		art.scale = ship.scale
		art.pivot_offset = ship.pivot
		# (an arrival cut short -- a press mid-dock -- parked where it was going;
		# the entry's engines out)
		if art.arrive_driven:
			art.park()
		if bool((_lad.get("hall", {}) as Dictionary).get("burning", false)):
			art.burn(false)
			Audio.ship_thrust_off()
		# (undocking's flameout: over, or cut short by a press, the idle it ends on)
		art.sputter_stop()
		art.position = ship.pos
		art.scale = ship.scale
		art.visible = true
		_dock_hidden = false
	# A dock ended early takes the arrival clip with it: sound follows the picture.
	if _lad.has("sky_hold0") and _view.backdrop != null and is_instance_valid(_view.backdrop):
		_view.backdrop.cam_hold = _lad.sky_hold0
	var hall_e: Dictionary = _lad.get("hall", {})
	if hall_e.has("clip") and float(hall_e.get("t", 0.0)) < ZoomLadder.dock_step_from(2):
		var hn: Array[StringName] = [hall_e.clip as StringName]
		Audio.hush(hn)
	# (and an undock cut short takes its coughs with it)
	if undocked and cut and hall_e.has("cough_clip"):
		var hc: Array[StringName] = [hall_e.cough_clip as StringName]
		Audio.hush(hc)
	_lad = {}
	# where the world you orbit sits at rest, for the next move in (`ZoomLadder`)
	var w := ladder_world()
	var sk: LocalSky = _view.backdrop if _view != null else null
	if not w.is_empty() and sk != null and sk.node != null and sk.orbit_target >= 0:
		ZoomLadder.world_rest["%d:%d" % [sk.node.index, sk.orbit_target]] = w
	_lad_zs = 1.0
	ladder_hide_hull(false)


# ------------------------------------------------------------ the calm move
# The ladder walks the ship along one line between rest spots; nothing else moves.
# Why: docs/why/SectorScreen.md#calm-move

## The camera taken: the scene's places at rest kept, to put back exactly.
func calm_begin() -> void:
	if not ladder_ready():
		return
	ladder_cam_end()
	# (your hull where it sits, its idle bob left out: the move aims at the
	# place, and the hull bobs about it on the way as it does at rest)
	var fixed := _ladder_ship()
	var art := _view.ship_view() if _view != null else null
	if art != null:
		fixed -= art.get_global_transform().basis_xform(Vector2(0.0, float(art.bob_offset()) * float(art._k)))
	var scenes: Array = []
	for c: Control in [LocalSubject.of(_view), _face, _view._row, _face_front, _view.dust, _view.fx]:
		if c != null and is_instance_valid(c):
			scenes.append([c, c.scale, c.offset_left, c.offset_top, c.offset_right, c.offset_bottom, c.size,
				c.get_global_transform().affine_inverse() * fixed, c.get_global_transform().affine_inverse()])
	var sky: LocalSky = _view.backdrop
	_lad = {"fixed": fixed, "to1": fixed, "zs1": 1.0, "scenes": scenes, "smooth": true, "ship": {},
		"sky_fixed": _sky_pt(sky, fixed) if sky != null else Vector2.ZERO,
		"bar": _quiet_holder.modulate.a if _quiet_holder != null else 1.0, "x0": position.x, "calm": true}


## Where your ship sits on screen at rest (the calm move's end on this view).
func calm_rest() -> Vector2:
	if _lad.has("calm"):
		return _lad.fixed
	return _ladder_ship()


## Where your ship is drawn now.
func calm_ship() -> Vector2:
	return _ladder_ship()


## The camera with your ship at `p` on screen and the scene `s` times its size
## at rest (fractions of a pixel: smooth, not stepped).
func calm_at(p: Vector2, s: float) -> void:
	if not _lad.has("calm"):
		return
	_lad_zs = s
	for w: Array in _lad.scenes:
		# (a piece freed mid-move -- the event's subject, changed -- is let go:
		# checked before it is typed, or the assignment itself is the error)
		if not is_instance_valid(w[0]):
			continue
		var sc: Control = w[0]
		sc.scale = (w[1] as Vector2) * s
		var to := (sc.get_parent() as CanvasItem).get_global_transform().affine_inverse() * p
		sc.position = to - (w[7] as Vector2) * sc.scale
		sc.size = w[6]
	var sky: LocalSky = _view.backdrop
	if sky != null and is_instance_valid(sky):
		sky.set_zoom(s, _lad.sky_fixed, _sky_pt(sky, p))


func calm_end() -> void:
	ladder_cam_end()


## THE MAP'S WORLD, TAKEN (2C): into the sky's near picture in place of its own,
## at the map's size and place; moved and eased by `ladder_cam` from here on.
func ladder_take_world(g: Dictionary) -> bool:
	var sky: LocalSky = _view.backdrop if _view != null else null
	if sky == null or _lad.is_empty():
		return false
	var ok := sky.adopt_near(g.view, _sky_pt(sky, g.screen), g)
	if ok:
		_lad["hand_R"] = float(sky._near[0][3])
	return ok


## Your hull as it is drawn: its canvas on screen, and the art (3B carries it).
func ladder_hull() -> Rect2:
	var art := _view.ship_view() if _view != null else null
	if art == null or art._tex == null:
		return Rect2()
	var g := art.get_global_transform()
	return Rect2(g * art.canvas_to_local(Vector2.ZERO), Vector2(art._w, art._h) * float(art._k) * g.get_scale())


func ladder_hull_texture() -> Texture2D:
	var art := _view.ship_view() if _view != null else null
	return art._tex if art != null else null


var _lad_hid := false


func ladder_hide_hull(on: bool) -> void:
	var art := _view.ship_view() if _view != null else null
	if art == null or _cutaway != null or on == _lad_hid:
		return
	_lad_hid = on
	# (kept off LOCAL while its own arrival waits for the move to land)
	art.visible = not on and not _flyin_wait


## Open your ship up. Public for the harnesses (`sheet=CutawayShot`).
func open_cutaway() -> CutawayView:
	if not cutaway_ready():
		return null
	_ship_outline.visible = false
	_cutaway = CutawayView.open_over(self, _view.ship_view())
	# The real scene zooms with the ship, the sky layer by layer by depth (Jon).
	# Why: docs/why/SectorScreen.md#zoom-ladder
	var near: Array[Control] = []
	for c: Control in [LocalSubject.of(_view), _view._row, _view.dust, _view.fx]:
		if c != null and is_instance_valid(c):
			near.append(c)
	_cutaway.scenes = near
	_cutaway.sky = _view.backdrop
	# ABOVE THE BOTTOM BAR, which stays: its SECTOR LOOT works from in here
	if _quiet_holder != null and _quiet_holder.is_visible_in_tree():
		_cutaway.offset_bottom = -maxf(0.0, get_global_rect().end.y - _quiet_holder.get_global_rect().position.y)
	_cutaway.closed.connect(func() -> void: _cutaway = null)
	return _cutaway


## The part a card came off, lit on the hull while the card is pointed at.
func _light_source(c: CardData) -> void:
	var art := _view.ship_view() if _view != null else null
	if art == null:
		return
	var src: ModuleData = null
	if c != null and fighting():
		for m in Run.installed:
			if m.id == c.source_id:
				src = m
				break
	for ch in art.get_children():
		if ch is MountPoints:
			(ch as MountPoints).lit_part = src
			(ch as MountPoints).queue_redraw()

## Pressing arms nothing: reorder versus shot is only known once the pointer moves.
## Why: docs/why/SectorScreen.md#card-gestures
func _on_card_grabbed(view: CardView, at: Vector2) -> void:
	if not fighting() or combat.finished or view == null or _hold or _opening:
		return
	_end_aim(false)
	_end_reorder(false)
	_grab_view = view
	_grab_from = at
	_grab_mode = 0

## A shot never becomes a reorder, but a reorder may become a shot, as drift eats clicks.
## Why: docs/why/SectorScreen.md#card-gestures
func _grab_decide(at: Vector2) -> void:
	if _grab_view == null or _grab_mode != 0:
		return
	var d := at - _grab_from
	# Aim only once the cursor is above the drawer, the only direction anything is aimed.
	# Why: docs/why/SectorScreen.md#card-gestures
	var above_drawer := at.y < _hand.get_global_rect().position.y
	if above_drawer:
		if not combat.can_play(_grab_view.card):
			# Unplayable cards can still be REARRANGED, so this refuses the shot
			# without ending the grab -- push it sideways instead.
			return
		_grab_mode = 2
		_begin_aim(_grab_view)
	# Dominantly sideways: an upward drag carries some x and wrongly committed to reorder.
	elif absf(d.x) > GRAB_SIDE and absf(d.x) > absf(d.y):
		_grab_mode = 1
		_hand.slide_to(at, _grab_view.card)

## The reorder is kept when promoted to a shot; reverting yanks the card back.
## Why: docs/why/SectorScreen.md#card-gestures
func _promote_to_aim(at: Vector2) -> bool:
	if _grab_view == null or combat == null or _hand == null:
		return false
	if at.y >= _hand.get_global_rect().position.y:
		return false
	# Same refusal as `_grab_decide`: an unplayable card rearranges but never arms a shot.
	if not combat.can_play(_grab_view.card):
		return false
	# `_end_reorder` clears the grab, and the grab is what the aim is about to
	# be built from.
	var view := _grab_view
	_end_reorder(true)
	_grab_view = view
	_grab_mode = 2
	_begin_aim(view)
	return true

func _end_reorder(commit: bool) -> void:
	if _grab_mode == 1:
		if commit:
			_hand.commit()
		else:
			_hand.clear_preview()
	_grab_view = null
	_grab_mode = 0

func _begin_aim(view: CardView) -> void:
	_aim_view = view
	view.set_armed(true)
	# Started AT the card, so the line grows out of it rather than snapping
	# across the screen on the first frame.
	_aim_tip = _aim_anchor()
	if _aim_line == null:
		_aim_line = AimLine.new()
		_aim_line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_aim_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_aim_line)
	_aim_line.owner_screen = self
	_aim_line.visible = true
	_aim_line.queue_redraw()

## Where the line leaves the card: the top edge, middle. The card is below the
## board and everything it can be aimed at is above it.
func _aim_anchor() -> Vector2:
	if _aim_view == null:
		return Vector2.ZERO
	var r := _aim_view.get_global_rect()
	return get_global_transform().affine_inverse() \
		* Vector2(r.position.x + r.size.x * 0.5, r.position.y)

## `MOUSE_MODE_HIDDEN` and a flag, so Main's animated cursor is not fought on each motion.
## Why: docs/why/SectorScreen.md#aim-cursor
var _cursor_off: bool = false

func _hide_cursor(on: bool) -> void:
	if _cursor_off == on:
		return
	_cursor_off = on
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN if on else Input.MOUSE_MODE_VISIBLE)

## Whatever happens to the screen, the pointer comes back. A cursor left hidden
## by a fight that ended mid-drag is not recoverable from inside the game.
func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_hide_cursor(false)
		# Nothing this screen was holding back outlives it.
		shown_hull = -1
		shown_heat = -1
		Engine.time_scale = 1.0
		# nor any hum it was holding up
		Audio.fx_stop(&"shield_idle")
		Audio.fx_stop(&"arc")
		# No cut outlives the screen that asked for it.
		EnemyArt.reap_wrecks()
		for who in _prebuilt.keys():
			var pre: Dictionary = _prebuilt[who]
			WorkerThreadPool.wait_for_task_completion(pre.task)
			if pre.held.b != null:
				(pre.held.b as Node).free()
		_prebuilt.clear()
		if not _loss_pre.is_empty():
			WorkerThreadPool.wait_for_task_completion(_loss_pre.task)
			if _loss_pre.held.b != null and not (_loss_pre.held.b as Node).is_inside_tree():
				(_loss_pre.held.b as Node).free()
			_loss_pre = {}

func _end_aim(played: bool) -> void:
	_hide_cursor(false)
	if _aim_view != null and not played:
		_aim_view.set_armed(false)
	_aim_view = null
	_grab_view = null
	_grab_mode = 0
	if _aim_line != null:
		_aim_line.visible = false
	if _view != null:
		_view.clear_aim()

## `_input` so a release is seen anywhere; releasing over nothing cancels.
## Why: docs/why/SectorScreen.md#card-gestures
func _input(e: InputEvent) -> void:
	# The skip is first in `_input` and off by default; Tab is eaten, Escape let through.
	# Why: docs/why/SectorScreen.md#jump-skip
	if _phase == Phase.DEPART or _phase == Phase.ARRIVE:
		var sb := e as InputEventMouseButton
		var sk := e as InputEventKey
		if (sb != null and sb.pressed) or (sk != null and sk.pressed 				and not sk.echo and sk.keycode != KEY_ESCAPE):
			get_viewport().set_input_as_handled()
			# (LOCAL's own arrival at a place flown to is always a press from
			# parked: it plays at every new place, not once a jump)
			if DisplaySettings.skip_jump or _flyin:
				_skip()
		return
	# THE STATION'S WAKE, a press: lit at once, its sounds hushed (the press
	# goes on to whatever it was for -- DOCK, a tab)
	if _wake_t >= 0.0:
		var wb := e as InputEventMouseButton
		var wk := e as InputEventKey
		if (wb != null and wb.pressed) or (wk != null and wk.pressed and not wk.echo):
			_wake_finish()
	if _grab_view == null and _aim_view == null:
		return
	var mm := e as InputEventMouseMotion
	if mm != null:
		if _grab_mode == 0:
			_grab_decide(mm.position)
		elif _grab_mode == 1:
			if not _promote_to_aim(mm.position):
				_hand.slide_to(mm.position, _grab_view.card)
		elif _aim_view != null:
			_aim_track(mm.position)
		return
	var mb := e as InputEventMouseButton
	if mb == null or mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	if _grab_mode == 1:
		_end_reorder(true)
		return
	if _aim_view != null:
		_aim_release(mb.position)
	# A press that never moved does nothing: it could start a reorder or a shot.
	_grab_view = null
	_grab_mode = 0

## THE BOARD MOVED UNDER A CARD BEING AIMED: the convoy column sliding in or
## out (J4 B, Jon, Nov 5). The card stays in hand and armed, and the target
## lit is whatever is under the pointer now, as a motion would light it; the
## release resolves against the board as it stands then (`_aim_release`).
func _on_view_slid() -> void:
	if _aim_view != null and is_inside_tree():
		_aim_track(_aim_where)


## Where the pointer last was while aiming, as `_input` saw it.
var _aim_where := Vector2.ZERO


## Light whatever is under the cursor, and remember where to draw to.
func _aim_track(where: Vector2) -> void:
	if _view == null or _aim_view == null:
		return
	_aim_where = where
	var at := get_global_transform().affine_inverse() * where
	# Back in the drawer is not aiming: the line and preview go, the card stays armed.
	var aiming := where.y < _hand.get_global_rect().position.y
	# The reticle replaces the pointer while drawn; the system cursor covered the lock.
	_hide_cursor(aiming)
	if _aim_line != null:
		_aim_line.visible = aiming
		if aiming:
			_aim_line.target = at
		else:
			# Parked at the card, so coming back out GROWS the line again rather
			# than whipping it across the board from wherever it was left.
			_aim_tip = _aim_anchor()
			_aim_line.target = _aim_tip
	if aiming:
		_view.aim_at(_view.target_at(where), _aim_view.card, _drag_preview)
	else:
		_view.clear_aim()

## Resolve against whatever is under the cursor, or put the card back.
func _aim_release(where: Vector2) -> void:
	var view := _aim_view
	if _view == null or view == null:
		_end_aim(false)
		return
	var idx := _view.target_at(where)
	# Asked of the slot, which owns `aimable`: brace does nothing to a Rustjaw.
	var legal := idx != EncounterView.AIM_NONE \
		and _view.aim_at(idx, view.card, _drag_preview)
	_end_aim(legal)
	if not legal:
		return
	var hand_index := combat.hand.find(view.card)
	if hand_index < 0 or not combat.can_play(view.card):
		return
	if idx < 0:
		combat.play(hand_index)
	else:
		combat.play(hand_index, idx)

## Dropping a card on an enemy plays it at that enemy.
func _on_card_dropped(index: int, view: CardView) -> void:
	if not fighting() or view == null:
		return
	var hand_index := combat.hand.find(view.card)
	if hand_index >= 0 and combat.can_play(view.card):
		combat.play(hand_index, index)

## Its own Control so it draws over the board; it ignores the mouse, being a picture.
## Why: docs/why/SectorScreen.md#aim-line
class AimLine extends Control:
	## Follow rate borrowed from `ModuleIcon.FOLLOW`, a measured value.
	const FOLLOW := 16.0

	## Two non-harmonic waves (12 and 17) from a bench of forty treatments; numbers kept.
	## Why: docs/why/SectorScreen.md#aim-line
	const AMP := 5.0
	const WAVE_F := [12.0, 17.0]
	const WAVE_S := [5.5, -3.6]
	const WAVE_A := [1.0, 0.6]

	## A generous bow, mirrored on the horizontal so it always bellies away from the card.
	## Why: docs/why/SectorScreen.md#aim-line
	const BOW := 0.24
	const BOW_MAX := 46.0

	## How far short of the tip the shaft stops, so it never draws underneath the
	## reticle. Slightly more than the reticle's own reach.
	const HEAD_GAP := 12.0

	## The reticle is a lock of three marks closing from radius 8 to 5.
	const LOCK_R := 8.0
	const LOCK_CLOSE := 3.0
	const LOCK_SPIN := 1.6
	const LOCK_RATE := 2.2

	const SHADOW := Color("#060a10")

	var owner_screen: SectorScreen = null
	var target: Vector2 = Vector2.ZERO

	func _process(delta: float) -> void:
		if owner_screen == null or owner_screen._aim_view == null:
			return
		# Exponential, so the tip never overshoots and the rate does not depend
		# on the frame rate.
		var k: float = 1.0 - exp(-FOLLOW * delta)
		owner_screen._aim_tip = owner_screen._aim_tip.lerp(target, k)
		queue_redraw()

	## Plotted pixel by pixel: smoothed curves look like strays on 960x540 pixel art.
	func _px(x: float, y: float, c: Color) -> void:
		draw_rect(Rect2(roundf(x), roundf(y), 1.0, 1.0), c)

	func _draw() -> void:
		if owner_screen == null or owner_screen._aim_view == null:
			return
		var a: Vector2 = owner_screen._aim_anchor()
		var b: Vector2 = owner_screen._aim_tip
		var t := GameClock.now()
		_draw_shaft(a, b, t)
		_draw_lock(b, t)

	## Straight run: a bowed arc swung with the aim, and waves on a straight run do not.
	## Why: docs/why/SectorScreen.md#aim-line
	func _draw_shaft(a: Vector2, b: Vector2, t: float) -> void:
		var run := b - a
		var span := run.length()
		if span < HEAD_GAP + 4.0:
			return
		var lean := -1.0 if run.x >= 0.0 else 1.0
		var ctrl := (a + b) * 0.5 			+ Vector2(-run.y, run.x) / span * minf(span * BOW, BOW_MAX) * lean
		# Steps use an upper bound on the length; stepping by the span left a dashed shaft.
		var steps := int(ceilf(a.distance_to(ctrl) + ctrl.distance_to(b)))
		if steps < 2:
			return
		for i in steps + 1:
			var u := float(i) / float(steps)
			var here := a.lerp(ctrl, u).lerp(ctrl.lerp(b, u), u)
			# Stop short of the reticle. Guarded past the midpoint because a deep
			# bow can start out closer to the tip than the straight line is.
			if u > 0.5 and here.distance_to(b) < HEAD_GAP:
				break
			# The normal turns with the curve, so the waves stay square to the
			# run rather than to the straight line between its ends.
			var tang := (ctrl - a) * (2.0 * (1.0 - u)) + (b - ctrl) * (2.0 * u)
			if tang.length() < 0.001:
				continue
			var nrm := Vector2(-tang.y, tang.x) / tang.length()
			# Widest at the middle, pinched at both ends: it gives the run a waist
			# and keeps the air around the reticle clear.
			var env := 0.2 + sin(u * PI) * 1.1
			var amp := AMP * env
			for w in WAVE_F.size():
				var off: float = sin(u * WAVE_F[w] - t * WAVE_S[w]) * amp * WAVE_A[w]
				var at := here + nrm * off
				if w == 0:
					_px(at.x, at.y + 1.0, SHADOW)
					_px(at.x, at.y, UITheme.FLARE)
				else:
					_px(at.x, at.y, UITheme.EMBER)

	## Three marks closing on the mark.
	func _draw_lock(b: Vector2, t: float) -> void:
		var r := LOCK_R - roundf(absf(sin(t * LOCK_RATE)) * LOCK_CLOSE)
		var ph := -t * LOCK_SPIN
		for i in 3:
			var th := ph + float(i) * TAU / 3.0
			var c := b + Vector2(cos(th), sin(th)) * r
			var across := Vector2(cos(th + PI * 0.5), sin(th + PI * 0.5))
			for s in range(-2, 3):
				var q := c + across * float(s)
				_px(q.x + 1.0, q.y + 1.0, SHADOW)
			for s2 in range(-2, 3):
				var q2 := c + across * float(s2)
				_px(q2.x, q2.y, UITheme.FLARE)
			var inward := c - Vector2(cos(th), sin(th))
			_px(inward.x, inward.y, UITheme.EMBER)
		draw_rect(Rect2(b.x - 1.0, b.y - 1.0, 3.0, 3.0), SHADOW)
		_px(b.x, b.y, UITheme.HOT)


## Floats in a layer above the hand, created on first use and click-through.
## Why: docs/why/SectorScreen.md#keyword-readout
func _readout_layer() -> Control:
	if _readout_host == null or not is_instance_valid(_readout_host):
		_readout_host = Control.new()
		_readout_host.set_anchors_preset(Control.PRESET_FULL_RECT)
		_readout_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_readout_host)
	return _readout_host

func _show_readout(view: CardView, entered: bool) -> void:
	if not entered:
		# Only the owning card may close it: sliding fires exited after entered.
		if view == null or view == _readout_for or view == _readout_pending:
			_clear_readout()
		return
	_clear_readout()

	# Not mid-drag: Godot sends hover events during a drag and opened a panel per card.
	if get_viewport().gui_is_dragging():
		return

	# Delayed so it is a thing you ask for by resting; the gallery stays instant.
	# Why: docs/why/SectorScreen.md#keyword-readout
	_readout_pending = view
	# The generation is checked per wake, as the card is not a unique enough claim.
	var gen := _readout_gen
	await get_tree().create_timer(READOUT_DELAY).timeout
	if gen != _readout_gen or not is_instance_valid(view):
		return
	if get_viewport().gui_is_dragging():
		return

	_readout_pending = null
	_readout_for = view
	# Held locally: across an await, the member may belong to a newer panel.
	var panel := Widgets.card_readout(view.card)
	_readout = panel
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Held at zero alpha until placed, as the wrapped height is unknown on the first frame.
	# Why: docs/why/SectorScreen.md#keyword-readout
	panel.modulate.a = 0.0
	_readout_layer().add_child(panel)

	# Above the card: a hand fans full width, and the space above holds nothing needed.
	var w: float = panel.custom_minimum_size.x
	var top := view.global_position - global_position
	var px := clampf(top.x + CardView.CARD_W * 0.5 - w * 0.5, 2.0,
		maxf(2.0, size.x - w - 2.0))
	panel.position = Vector2(px, 2.0)

	await get_tree().process_frame
	if gen != _readout_gen or not is_instance_valid(panel):
		return
	var py := maxf(2.0, top.y - panel.size.y - 6.0)
	# Rises as it fades in, matching the card's lift so it reads as one gesture.
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
		# Removed as well as freed, as `queue_free()` leaves a doubled panel for a frame.
		# Why: docs/why/SectorScreen.md#keyword-readout
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
	if not fighting() or combat.waiting or combat.finished or _hold or _opening:
		return
	# The turn plays out on screen: it is held, caught as it happens, then shown in order.
	# Why: docs/why/SectorScreen.md#turn-playback
	if combat.is_shared():
		combat.end_turn()
		return
	_begin_hold()
	combat.end_turn()
	_play_turn()

## Both exits ask first: each spends a run's progress, and the odds live on the panel.
## Why: docs/why/SectorScreen.md#exit-buttons
func _ask_exit(title: String, ink: Color, edge: Color, said: String,
		go_label: String, fail_title: String, on_go: Callable) -> void:
	_exit_ink = ink
	_exit_fail = fail_title
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_exit_box = box
	var head := UITheme.body(title, ink, UITheme.FS_HEAD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var body := UITheme.body(said, UITheme.CHILL, UITheme.FS_SMALL)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(220, 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# Staying is the default and sits first: the safe answer should be the one
	# under your hand when the panel opens.
	row.add_child(Widgets.button("KEEP FIGHTING", _close_exit_ask))
	# The panel does not close; the answer appears where the player is already looking.
	# Why: docs/why/SectorScreen.md#exit-buttons
	var go := Widgets.button(go_label, func() -> void:
		if not fighting() or combat.finished or _hold:
			return
		combat.exit_note = ""
		_exit_heat0 = Run.heat
		_exit_fuel0 = Run.fuel
		_exit_cost = ""
		_begin_hold()
		on_go.call()
		if not combat.finished:
			_exit_cost = _cost_line(_exit_heat0, _exit_fuel0)
		if combat.finished:
			# It worked: nothing swings, so nothing waits. A partial hail still
			# costs heat, and the panel says so (audit item 11).
			_end_hold()
		# Refresh belongs to 'an exit was taken': a successful hail left the hand greyed.
		# Why: docs/why/SectorScreen.md#exit-buttons
		_refresh()
		# Tests `finished`, not `fighting()`, which stays true after a fight ends.
		# Why: docs/why/SectorScreen.md#exit-buttons
		if _exit_ask != null and not combat.finished:
			# The answer states the cost; the enemy's turn plays when CONTINUE is pressed.
			_exit_ask_result(_exit_fail, _exit_ink,
				combat.exit_note + ("\n" + _exit_cost if _exit_cost != "" else ""),
				func() -> void:
					_close_exit_ask()
					_play_turn()))
	go.add_theme_color_override("font_color", ink)
	row.add_child(go)
	box.add_child(row)

	_exit_ask = PanelContainer.new()
	_exit_ask.custom_minimum_size = EXIT_ASK
	_exit_ask.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.PANEL, edge, 0, 10, 12))
	_exit_ask.add_child(box)
	# Unseen until centred, as centring waits two layout frames and it flashed top-left.
	_exit_ask.modulate.a = 0.0
	add_child(_exit_ask)
	_exit_ask.set_anchors_preset(Control.PRESET_CENTER)
	_centre_exit_ask()


## What an exit cost, in numbers, and what the turn it gave away does.
var _exit_cost := ""
var _exit_heat0 := 0
var _exit_fuel0 := 0

func _cost_line(heat0: int, fuel0: int) -> String:
	var bits := PackedStringArray()
	if Run.fuel < fuel0:
		bits.append("-%d FUEL." % (fuel0 - Run.fuel))
	if Run.heat > heat0:
		bits.append("+%d HEAT." % (Run.heat - heat0))
	var dealt := 0
	var swings := 0
	for q in _queue:
		if q.k == &"hit" and q.to_player:
			dealt += int(q.dealt)
			swings += 1
	if dealt > 0:
		bits.append("THEY HIT YOU FOR %d." % dealt)
	elif swings > 0:
		bits.append("THEY OPEN FIRE.")
	return " ".join(bits)


## `Widgets.clear` keeps the border and position, so question and answer read as one.
func _exit_ask_result(title: String, ink: Color, said: String,
		on_go: Callable) -> void:
	if _exit_ask == null or _exit_box == null:
		return
	Widgets.clear(_exit_box)
	var head := UITheme.body(title, ink, UITheme.FS_HEAD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exit_box.add_child(head)
	# Always built so CONTINUE stays at the bottom even with nothing to say.
	var body := UITheme.body(said, UITheme.CHILL, UITheme.FS_SMALL)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(220, 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_exit_box.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(Widgets.button("CONTINUE", on_go))
	_exit_box.add_child(row)
	_centre_exit_ask()


## The panel changes size when its contents do, and a centred thing that grew
## from its top-left corner is not centred any more.
func _centre_exit_ask() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_exit_ask):
		return
	# Shrink first: a Control never shrinks back, so a short answer kept the tall box.
	_exit_ask.reset_size()
	await get_tree().process_frame
	if is_instance_valid(_exit_ask):
		_exit_ask.position = (size - _exit_ask.size) * 0.5
		if _exit_ask.modulate.a < 1.0:
			_exit_ask.create_tween().tween_property(_exit_ask, "modulate:a", 1.0, 0.1)


## Fleeing: it ends the fight, forfeits every scrap of salvage and burns fuel.
func _on_flee() -> void:
	if not fighting() or _exit_ask != null or _opening or not combat.can_flee():
		return
	# The exact cost, from the same constant the code charges.
	_ask_exit("BREAK CONTACT?", Color("#d4614f"), Color("#8f4034"),
		"%s. You lose the salvage and burn %d fuel, %d if it goes badly. Fail and there is no second try."
			% [SkillCheck.badge(combat.flee_check()), Combat.FLEE_FUEL,
				Combat.FLEE_FUEL + Combat.FLEE_FUEL_PARTIAL],
		"BREAK CONTACT", "STILL ON YOU", func() -> void: combat.flee())


## Hail asks first now: failing broadcasts your position, costing 14 heat and the turn.
## Why: docs/why/SectorScreen.md#hail
func _on_hail() -> void:
	if not fighting() or _exit_ask != null or _opening or not combat.can_hail():
		return
	_ask_exit("OPEN A CHANNEL?", UITheme.HOT, Color("#8a6420"),
		"%s. They break off and there is no salvage. Fail and you give away your position: %d heat, and they take the turn."
			% [SkillCheck.badge(combat.hail_check()), Combat.HAIL_HEAT_BOTCHED],
		"HAIL THEM", "NO ANSWER", func() -> void:
			combat.hail())


func _close_exit_ask() -> void:
	if _exit_ask != null:
		_exit_ask.queue_free()
		_exit_ask = null
		_exit_box = null



## Kills show when the shot lands; a signal spawned debris 8 frames early (audit F4).
## Why: docs/why/SectorScreen.md#death-breakup
func _on_enemy_destroyed(who: int) -> void:
	if not fighting() or _view == null or _view.fx == null:
		return
	_dying[who] = true
	_prebuild_death(who)
	# Killed with nothing in the air (a partner's push): start now. Otherwise
	# the shot that did it is drawn first and the death starts as it lands.
	if int(_slot_volleys.get(who, 0)) == 0 and not _hold:
		_start_death(who)

## The shot arrived. Now the target moves, about its place at rest, a second hit too:
## two hits a frame apart once left the hull 0.8 px off the grid.
## Why: docs/why/SectorScreen.md#shot-landed
func _on_shot_landed(who: int, to_player: bool, _kind: int) -> void:
	var target: Control = _view.ship_view() if to_player else _view.enemy_view(who)
	if target == null:
		return
	var origin := target.position
	var was: Array = _shook.get(target, [])
	if not was.is_empty() and (was[1] as Tween).is_valid():
		(was[1] as Tween).kill()
		origin = was[0]
	var tw := create_tween()
	for i in 3:
		tw.tween_property(target, "position",
			origin + Vector2(randf_range(-3, 3), randf_range(-2, 2)).round(), 0.03)
	tw.tween_property(target, "position", origin, 0.05)
	_shook[target] = [origin, tw]
	tw.finished.connect(func() -> void: _shook.erase(target))


## What each shaken thing's place at rest is while it shakes, and its shake.
var _shook: Dictionary = {}

func _on_combat_ended(result: StringName, text: String) -> void:
	# Nothing ends on the frame it resolved; it waits for what the eye is still being shown.
	# Why: docs/why/SectorScreen.md#fight-end
	_ending = {result = result, text = text}
	# Your ship's breakup is cut now, off the main thread, while the shot that
	# did it is still in the air (see `_lose_ship`).
	if result == &"dead":
		_prebuild_loss()
	_end_button.disabled = true
	_refresh_flee()
	_refresh_hail()
	if (result == &"fled" or result == &"hailed") and _exit_ask != null:
		var titles := {&"fled": "DISENGAGED", &"hailed": "STOOD DOWN"}
		var said := text
		# The fuel is already in the summary's own words; the heat is not.
		var cost := _cost_line(_exit_heat0, Run.fuel)
		if cost != "":
			said += "\n" + cost
		_exit_ask_result(String(titles[result]), _exit_ink, said, func() -> void:
			_close_exit_ask()
			_lower_band(_on_continue))
		_ending = {}
		return
	_check_ending()

func _on_continue() -> void:
	_overlay.visible = false
	Router.after_combat(combat)

## Deferred: the fight is mid-emit when it ends, and swapping the screen out
## from under a running signal frees the object still walking its connections.
func _leave_combat() -> void:
	Router.after_combat(combat)


# ------------------------------------------------------- the fight, played out
# Combat resolves instantly; the screen holds back what it shows until the eye has seen why.
# Why: docs/why/SectorScreen.md#turn-playback

## Static, as the HUD is not this screen's; reset whenever this screen goes.
static var shown_hull: int = -1
static var shown_heat: int = -1

## END TURN is playing out; refreshes wait (see `_refresh`).
var _hold := false
var _dirty := false
## The replay is running. Separate from `_hold`: the exit panels hold first and
## play when CONTINUE is pressed.
var _playing := false
## The first hand of a fight waits for the band to come up (`_raise_band`).
var _opening := false
## The band is coming up: `_refresh` leaves the two bands and your plate to it.
var _raising := false
var _raise_tw: Tween = null
var _band_shield: Control = null
## The fight met you on arrival and waits for the approach (`_hold_for_arrival`).
var _ambushed := false
## LOCAL's line fading out before the hand comes up, and back in after it has
## gone down (`_lower_band`).
const BAND_FADE_S := 0.18
## The hand has been lowered for the end of the fight; it does not come back.
var _lowered := false
## What END TURN caught, in the order it happened.
var _queue: Array = []
## Each living enemy and the move it was about to make, as END TURN was pressed.
var _pre: Array = []
## Volleys in the air, by id: what they will say when they land.
var _volleys: Dictionary = {}
var _volley_seq := 0
## Per enemy: the hull its slot shows while shots at it are in the air, and how
## many volleys are still coming.
var _slot_shown: Dictionary = {}
var _slot_volleys: Dictionary = {}
## Enemies dead in the maths whose killing shot has not landed yet.
var _dying: Dictionary = {}
## Breakups still playing, and each one's art (it follows the slot's bob).
var _breakups: Array = []
## How the fight ended, waiting for the screen to catch up. See `_check_ending`.
var _ending: Dictionary = {}
var _ending_started := false

## Jon asked for 0.5 to 0.8 s: slow enough to read as lowering, short enough not to wait.
## Why: docs/why/SectorScreen.md#hand-lowering
const LOWER_S := 0.65


func _on_fight_opened(_name: String) -> void:
	# The first hand is dealt once contacts are in; before, drawer and cards popped in (audit F6).
	# Why: docs/why/SectorScreen.md#hand-raising
	if combat != null:
		_wrecks_before = _count_wrecks()
		for i0 in combat.enemies.size():
			EnemyArt.warm_wreck(combat.enemies[i0], _death_style(i0))
	if not Router.animating():
		_view.open_row()
		return
	if _phase == Phase.ARRIVE:
		_hold_for_arrival()
		return
	_raise_band()


## An ambush waits for the arrival to finish, then contacts fly in and the hand comes up.
## Why: docs/why/SectorScreen.md#hand-raising
func _hold_for_arrival() -> void:
	_ambushed = true
	_opening = true
	_raising = true
	_shield(true)
	_quiet_holder.visible = true
	_hand_holder.visible = false
	_hand_wrap.modulate.a = 0.0
	if _self_plate != null:
		_self_plate.visible = true
		_self_plate.modulate.a = 0.0
	_end_button.disabled = true
	_refresh_flee()
	_refresh_hail()
	# your ship is off screen until the approach brings it to the fight's place
	_view.open_row()
	_view.hold_entrances()


## The longest a fight's hand waits for a camera move to land (frames).
const LADDER_WAIT_FRAMES := 600

## `_lower_band` played backwards on the same clock and curve; no clicks while it moves.
## Why: docs/why/SectorScreen.md#hand-raising
func _raise_band() -> void:
	if _hand_holder == null or _quiet_holder == null:
		return
	_opening = true
	_raising = true
	_shield(true)
	# LOCAL's picture, as the frame it is swapped in on
	_quiet_holder.visible = true
	_quiet_wrap.modulate.a = 1.0
	_hand_holder.visible = false
	_hand_wrap.modulate.a = 0.0
	if _self_plate != null:
		_self_plate.visible = true
		_self_plate.modulate.a = 0.0
	_end_button.disabled = true
	_refresh_flee()
	_refresh_hail()
	# One frame laid out as LOCAL, so the band's height is measured rather than
	# guessed (a wrapping line has no width to wrap to before then).
	await get_tree().process_frame
	if not is_inside_tree() or not _raising:
		return
	# Not under a camera move: a band grown under it left the ship low (Jon, Oct 22).
	# Why: docs/why/SectorScreen.md#hand-raising
	var waited := 0
	while ZoomLadder.busy() and waited < LADDER_WAIT_FRAMES:
		await get_tree().process_frame
		waited += 1
		if not is_inside_tree() or not _raising:
			return
	var from := minf(_quiet_holder.size.y, float(DRAWER_H))
	if from <= 0.0:
		from = minf(_one_line_height(), float(DRAWER_H))
	from = roundf(from * 0.5) * 2.0
	_view.band_left = _band_still_to_come
	_open_row_eased()
	# LOCAL's picture fades first; the contacts fly in after it, as overlapping looked wrong.
	var clear_first := _view.leaving()
	if clear_first:
		_view.hold_entrances()
	_raise_tw = create_tween()
	_raise_tw.tween_property(_quiet_wrap, "modulate:a", 0.0, BAND_FADE_S)
	_raise_tw.tween_callback(func() -> void:
		if clear_first:
			_view.release_entrances_when_clear()
		_quiet_holder.visible = false
		_hand_holder.custom_minimum_size = Vector2(0, from)
		_hand_holder.visible = true
		# the band starts up: the escape menu's open (Jon: the same drawer)
		Audio.fx(&"fight_band"))
	_raise_tw.tween_method(func(h: float) -> void:
		_hand_holder.custom_minimum_size = Vector2(0, roundf(h * 0.5) * 2.0),
		from, float(DRAWER_H), LOWER_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_raise_tw.parallel().tween_property(_hand_wrap, "modulate:a", 1.0, BAND_FADE_S)
	if _self_plate != null:
		_raise_tw.parallel().tween_property(_self_plate, "modulate:a", 1.0, LOWER_S * 0.5) \
			.set_delay(LOWER_S * 0.5)
	_raise_tw.tween_callback(_band_up)


## The ship is pinned through layout passes and eased to wherever the row puts it.
## Why: docs/why/SectorScreen.md#hand-raising
func _open_row_eased() -> void:
	var sv := _view.ship_view()
	if not _view.hold_row or sv == null:
		_view.open_row()
		return
	_ship_from = sv.global_position.x + sv.size.x * 0.5
	_ship_k = 0.0
	_ship_off = 0.0
	sv.item_rect_changed.connect(_pin_ship)
	_view.open_row()
	_pin_ship()
	var tw := create_tween()
	tw.tween_interval(BAND_FADE_S)
	tw.tween_method(func(k: float) -> void:
		_ship_k = k
		_pin_ship(),
		0.0, 1.0, LOWER_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		_ship_k = 1.0
		_pin_ship()
		if is_instance_valid(sv) and sv.item_rect_changed.is_connected(_pin_ship):
			sv.item_rect_changed.disconnect(_pin_ship))


## Where LOCAL had your ship (the middle of its canvas), how far to the fight's
## place it has come, and the offset that puts it there now.
var _ship_from := 0.0
var _ship_k := 1.0
var _ship_off := 0.0
var _pinning := false

func _pin_ship() -> void:
	var sv := _view.ship_view() if _view != null else null
	if _pinning or sv == null:
		return
	var rest := sv.global_position.x + sv.size.x * 0.5 - _ship_off
	var off := roundf(lerpf(_ship_from, rest, _ship_k) - rest)
	if off != _ship_off:
		_pinning = true
		sv.position.x += off - _ship_off
		_ship_off = off
		_pinning = false
	_place_self_plate()


## How much the band has still to grow, measured off the band as laid out.
func _band_still_to_come() -> float:
	if not _raising:
		return 0.0
	var now := _hand_holder.size.y if _hand_holder.visible else _quiet_holder.size.y
	return maxf(0.0, float(DRAWER_H) - now)


func _band_up() -> void:
	_raise_tw = null
	_raising = false
	_opening = false
	_shield(false)
	_hand_holder.custom_minimum_size = Vector2(0, DRAWER_H)
	_hand_wrap.modulate.a = 1.0
	_quiet_wrap.modulate.a = 1.0
	if _self_plate != null:
		_self_plate.modulate.a = 1.0
	_refresh()
	if fighting() and not combat.finished:
		Audio.play(&"card_draw", 0.10, 70)


## The rise cut short (the fight ended under it, `_lower_band`): the hand's
## band stays at the height it had reached, for the lowering to take down from.
func _stop_raise() -> void:
	if not _raising and _raise_tw == null:
		return
	if _raise_tw != null and _raise_tw.is_valid():
		_raise_tw.kill()
	_raise_tw = null
	_raising = false
	_opening = false
	_shield(false)
	if not _hand_holder.visible:
		# still on LOCAL's line: the band is that tall
		_hand_holder.custom_minimum_size = Vector2(0, _quiet_holder.size.y)
	_quiet_holder.visible = false
	_quiet_wrap.modulate.a = 1.0
	_hand_holder.visible = true
	_hand_wrap.modulate.a = 1.0
	if _self_plate != null:
		_self_plate.modulate.a = 1.0


## A pane over the band eats clicks while it moves, so none land on LOCAL's button.
func _shield(on: bool) -> void:
	if not on:
		if _band_shield != null and is_instance_valid(_band_shield):
			_band_shield.queue_free()
		_band_shield = null
		return
	if _band_shield != null:
		return
	_band_shield = Control.new()
	_band_shield.name = "BandShield"
	_band_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	_band_shield.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_band_shield.offset_top = -float(DRAWER_H) - 8.0
	_band_shield.offset_bottom = 0.0
	add_child(_band_shield)


func _begin_hold() -> void:
	_hold = true
	_dirty = false
	_queue.clear()
	_pre.clear()
	shown_hull = Run.hp
	shown_heat = Run.heat
	for i in combat.enemies.size():
		var e: Combat.EnemyState = combat.enemies[i]
		if e.hp > 0:
			_pre.append([i, e.intent])
	_end_aim(false)
	_clear_readout()
	# The hand goes to the pile now; the next one is dealt when the turn has
	# been shown.
	_hand.sync([], func(_c): return false)
	_end_button.disabled = true
	_refresh_flee()
	_refresh_hail()


func _end_hold() -> void:
	_hold = false
	shown_hull = -1
	shown_heat = -1
	_sync_hull()
	_refresh()
	if fighting() and not combat.finished:
		Audio.play(&"card_draw", 0.10, 70)
	_check_ending()


## How low the replay of a turn may show your hull: where the turn left it.
## Each hit takes its whole `dealt`, which is right until BLACK BOX (science)
## holds a killing hit at 1. Taken whole, 5 hull against a 6 hit drew "0 / 47"
## and a broken ship for a ship that lived. Dead, it is 0 as before. Never above
## the number on show, so a hit can only ever take the shown hull down.
func _shown_less(n: int) -> int:
	var floor_at := 0 if Run.dead else maxi(0, Run.hp)
	return maxi(shown_hull - n, mini(shown_hull, floor_at))


## The HUD and your plate, from the shown numbers.
func _sync_hull() -> void:
	_refresh_self_plate()
	if Router.hud != null:
		Router.hud.refresh()


func _wait_s(t: float) -> void:
	# NOTHING TO WAIT FOR when nothing animates: reduced motion, headless, the
	# sim. The order of events is kept; only the time between them goes.
	if not Router.animating():
		return
	await get_tree().create_timer(t).timeout


## Replay what END TURN caught: burns, then each enemy in turn, then anything of
## yours that went off as the next turn started (drones, a charge).
func _play_turn() -> void:
	if _playing or not _hold:
		return
	_playing = true
	var steps := _turn_steps()
	_queue.clear()
	var opened := {}
	for st in steps:
		if not is_inside_tree() or combat == null:
			return
		# LAST TURN'S BLOCK GOES AS EACH ENEMY ACTS (`Combat._act_one`), so its
		# bubble fizzles on the first thing it does this turn
		if (st.k == &"act" or (st.k == &"hit" and st.to_player)) and not opened.has(int(st.who)):
			opened[int(st.who)] = true
			var L0 := _enemy_fx(int(st.who))
			if L0 != null:
				L0.expire_block()
		match st.k:
			&"burn":
				_show_burn(int(st.amount), st.cause)
				await _wait_s(0.45)
			&"hit":
				# A creature winds up before it fires (Jon, Oct 13); ships keep their pacing.
				if st.to_player and _fauna_winds_up(int(st.who)):
					await _wait_s(FAUNA_ANTICIPATION)
					if not is_inside_tree() or combat == null:
						return
				_fire_q(st)
				await _wait_s(0.36 if st.to_player else 0.22)
			&"act":
				_show_act(int(st.who), st.intent)
				await _wait_s(0.34)
	while not _volleys.is_empty() or _view.fx.in_flight():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	await _wait_s(0.18)
	if not is_inside_tree():
		return
	_playing = false
	_end_hold()


func _turn_steps() -> Array:
	var steps: Array = []
	var hits: Array = []
	var rest: Array = []
	for q in _queue:
		if q.k == &"burn":
			steps.append(q)
		elif q.k == &"hit" and q.to_player:
			hits.append(q)
		else:
			rest.append(q)
	for pr in _pre:
		var who: int = pr[0]
		var it: IntentData = pr[1]
		var took := false
		for h in hits:
			if int(h.who) == who and not h.get("used", false):
				h.used = true
				steps.append(h)
				took = true
				break
		if it != null and not it.escape and (it.block > 0 or it.heal > 0 or it.dross > 0
				or it.telegraph or (not took and it.damage <= 0)):
			steps.append({k = &"act", who = who, intent = it})
	for h2 in hits:
		if not h2.get("used", false):
			steps.append(h2)
	steps.append_array(rest)
	return steps


## Something an enemy did that is not a shot, said over it.
func _show_act(who: int, it: IntentData) -> void:
	if it == null or _view == null or _view.fx == null:
		return
	var at := _pop_at(false, who, int(it.telegraph) + int(it.block > 0) + int(it.heal > 0))
	var y := 0.0
	if it.telegraph:
		_view.fx.pop(at, "WINDING UP", HitText.colour(&"act"), true)
		y -= HitText.LINE
	if it.block > 0:
		_view.fx.pop(at + Vector2(0, y), "+%d BLOCK" % it.block, HitText.colour(&"block"), true)
		y -= HitText.LINE
		var L1 := _enemy_fx(who)
		if L1 != null:
			L1.shield.gain(it.block)
	if it.heal > 0:
		_view.fx.pop(at + Vector2(0, y), "+%d HULL" % it.heal, HitText.colour(&"act"), true)
		y -= HitText.LINE
	if it.dross > 0:
		# Lodged in YOU, so said over your ship.
		_view.fx.pop(_pop_at(true, -1), "+%d DROSS" % it.dross, HitText.colour(&"hurt"), true, 0.25)


## Hull you burned yourself, on your own ship, as the hull goes (audit item 9).
func _show_burn(amount: int, cause: StringName) -> void:
	if _view == null or _view.fx == null:
		return
	var at := _ship_pt()
	_view.fx.pop(_pop_at(true, -1), "-%d %s" % [amount,
		"OVERHEAT" if cause == &"overheat" else "JUNK"], HitText.colour(&"hurt"), true)
	_view.fx.flash(at, true, true)
	_flash_hit(_view.ship_view())
	if shown_hull >= 0:
		shown_hull = _shown_less(amount)
		_sync_hull()
	Audio.play(&"overheat" if cause == &"overheat" else &"impact_hull", 0.03)


func _on_burn(amount: int, cause: StringName) -> void:
	if not fighting():
		return
	if _hold:
		_queue.append({k = &"burn", amount = amount, cause = cause})
		return
	_show_burn(amount, cause)


func _on_hit(to_player: bool, who: int, dealt: int, absorbed: int, missed: int, hits: int) -> void:
	if not fighting() or _view == null or _view.fx == null:
		return
	var kind := CombatFx.Kind.HOSTILE
	var pre := -1
	if not to_player:
		# The firing weapon is read as it resolves: a card that makes heat is an energy weapon.
		kind = CombatFx.Kind.BALLISTIC
		var c: CardData = combat.resolving
		if c != null and (c.heat > 0 or c.damage_equals_heat or c.heat_scale > 0):
			kind = CombatFx.Kind.ENERGY
		if who >= 0 and who < combat.enemies.size():
			pre = combat.enemies[who].hp + dealt
	var q := {k = &"hit", to_player = to_player, who = who, dealt = dealt,
		absorbed = absorbed, missed = missed, hits = maxi(1, hits), pre = pre, kind = kind}
	if _hold:
		_queue.append(q)
		return
	_fire_q(q)


func _fire_q(q: Dictionary) -> void:
	var id := _volley_seq
	_volley_seq += 1
	_volleys[id] = q
	var who: int = q.who
	if not q.to_player and who >= 0 and who < combat.enemies.size():
		# THE BAR WAITS FOR THE SHOT. The slot shows the hull from before this
		# volley until it lands.
		var e: Combat.EnemyState = combat.enemies[who]
		if not _slot_shown.has(who):
			_slot_shown[who] = clampi(int(q.pre), 0, e.max_hp)
		_slot_volleys[who] = int(_slot_volleys.get(who, 0)) + 1
		_show_slot(who)
	# Without motion the shot has nothing to cross: it lands now.
	if not Router.animating():
		_on_volley_landed(id)
		return
	var here := _view.enemy_anchor(who)
	var mine := _view.ship_muzzle()
	if q.to_player:
		_view.fx.fire(here, mine, q.kind, q.hits, who, true, id, q.missed)
	else:
		_view.fx.fire(mine, here, q.kind, q.hits, who, false, id, q.missed)


## One enemy's slot, drawn with whatever it is allowed to show right now.
func _show_slot(who: int) -> void:
	var sl := _view.slot(who)
	if sl == null or who >= combat.enemies.size():
		return
	var e: Combat.EnemyState = combat.enemies[who]
	sl.shown_hp = int(_slot_shown.get(who, -1))
	sl.bind(who, e, e.intent != null and e.intent.telegraph)


func _on_volley_landed(id: int) -> void:
	if not _volleys.has(id) or combat == null:
		return
	var q: Dictionary = _volleys[id]
	_volleys.erase(id)
	var who: int = q.who
	if q.to_player:
		_pop_hit(_pop_at(true, who, _pop_lines(q)), q, true)
		if shown_hull >= 0:
			shown_hull = _shown_less(int(q.dealt))
			_sync_hull()
		if _ship_fx != null:
			_ship_fx.land(int(q.dealt), int(q.absorbed), shown_hull if shown_hull >= 0 else Run.hp)
			# the bar's brace runs down with the hit, not at the end of the turn
			if _hold:
				_show_self_brace(_ship_fx.brace.brace)
		if int(q.dealt) > 0:
			_flash_hit(_view.ship_view())
	elif who >= 0:
		var n := int(_slot_volleys.get(who, 1)) - 1
		if n <= 0:
			_slot_volleys.erase(who)
			_slot_shown.erase(who)
		else:
			_slot_volleys[who] = n
			_slot_shown[who] = maxi(0, int(_slot_shown[who]) - int(q.dealt))
		_pop_hit(_pop_at(false, who, _pop_lines(q)), q, false, n <= 0 and _dying.has(who))
		var L2 := _enemy_fx(who)
		if L2 != null:
			var hp_after: int = int(_slot_shown[who]) if _slot_shown.has(who) else combat.enemies[who].hp
			L2.land(int(q.dealt), int(q.absorbed), hp_after)
		if int(q.dealt) > 0:
			_flash_hit(_view.enemy_view(who))
		# Cut up the ship as it WAS, before the slot redraws it as a wreck.
		if n <= 0 and _dying.has(who):
			_start_death(who)
		_show_slot(who)
	Sig.hit_landed.emit(int(q.dealt), q.to_player, who, int(q.absorbed))
	if int(q.dealt) >= 10:
		_hitstop()
	_check_ending()


## Numbers sit above an enemy's intent words, as just above the hull one read 'ST-8E'.
## Why: docs/why/SectorScreen.md#pop-numbers
func _pop_at(to_player: bool, who: int, lines: int = 1) -> Vector2:
	var ink := _hull_ink(to_player, who)
	var top := ink
	if not to_player:
		var sl := _view.slot(who)
		var words := sl.intent_rect_global() if sl != null else Rect2()
		if words.size.y > 0.0:
			var inv := _view.fx.get_global_transform().affine_inverse()
			var w := Rect2(inv * words.position, words.size)
			top = Rect2(ink.position.x, minf(ink.position.y, w.position.y), ink.size.x, ink.size.y)
	var at := HitText.above(Rect2(ink.position.x, top.position.y, ink.size.x, 1.0))
	# With no room above, the stack goes on the hull and the ship's words step back.
	if not to_player and at.y - _pop_reach(lines) < _pop_limit(who, ink):
		var mid := ink.get_center()
		at = Vector2(mid.x, mid.y + HitText.CAP * 0.5 + float(maxi(lines, 1) - 1) * HitText.LINE * 0.5).round()
		var sl2 := _view.slot(who)
		# a stack taller than a thin hull (a Lancer from a half sheet) lifted
		# clear of the ship's own name and bars, into the words' stepped-back room
		var plate := sl2.readout_rect_global() if sl2 != null else Rect2()
		if plate.size.y > 0.0:
			var inv2 := _view.fx.get_global_transform().affine_inverse()
			at.y = minf(at.y, (inv2 * plate.position).y - 3.0)
		if sl2 != null:
			sl2.hush_intent(1.15)
	return _pop_room(at, lines, -1 if to_player else who, ink)


## How far above its baseline a stack of `lines` pops reaches, risen.
func _pop_reach(lines: int) -> float:
	return float(maxi(lines, 1) - 1) * HitText.LINE + HitText.CAP + 1.0 + HitText.RISE


## The rise limit is under the HUD, and under any ship behind in the pack's front rank.
## Why: docs/why/SectorScreen.md#pop-numbers
func _pop_limit(who: int = -1, ink: Rect2 = Rect2()) -> float:
	var inv := _view.fx.get_global_transform().affine_inverse()
	var top_g := _view.get_global_rect().position.y
	if Router.hud != null and Router.hud.is_visible_in_tree():
		top_g = maxf(top_g, Router.hud.get_global_rect().end.y)
	if who >= 0 and ink.size.x > 0.0:
		var fxg := _view.fx.get_global_transform()
		# as wide as the numbers' widest line, centred on the ink
		var wide := maxf(ink.size.x, HitText.ink_width("BLOCKED 99") + 2.0)
		var span := Rect2(fxg * Vector2(ink.get_center().x - wide * 0.5, ink.position.y), Vector2(wide, ink.size.y))
		var mine := _view.slot(who)
		var k := 0
		while _view.slot(k) != null:
			var other := _view.slot(k)
			if other != mine and other.visible and mine != null \
					and other.get_global_rect().position.y < mine.get_global_rect().position.y - 0.5:
				var oi := other.ink_rect()
				var parts: Array[Rect2] = [other.intent_rect_global(), other.readout_rect_global(),
					Rect2(other.get_global_rect().position + oi.position, oi.size)]
				# and its shield's oval, up or not
				for p in other.rooms(other.art.draw_scale):
					if p[0] == &"oval":
						parts.append(Rect2(other.get_global_rect().position + (p[1] as Rect2).position, (p[1] as Rect2).size))
				for g in parts:
					if g.size.x > 0.0 and g.position.x < span.end.x and g.end.x > span.position.x:
						top_g = maxf(top_g, g.end.y)
			k += 1
	# Keeps clear of the fight log: room for two of your numbers, then they stay under it.
	if who < 0 and _fight_log != null and is_instance_valid(_fight_log) and _fight_log.panel.is_visible_in_tree():
		var lr := _fight_log.panel.get_global_rect()
		var sv := _view.ship_view()
		if sv != null:
			var sr := sv.get_global_transform() * sv.ship_rect()
			if sr.position.x < lr.end.x and sr.end.x > lr.position.x:
				top_g = maxf(top_g, lr.end.y)
	return (inv * Vector2(0.0, top_g)).y + 2.0


## Moved down only as far as needed to keep the stack under the HUD.
func _pop_room(at: Vector2, lines: int, who: int = -1, ink: Rect2 = Rect2()) -> Vector2:
	var limit := _pop_limit(who, ink)
	_view.fx.pop_top = limit
	var reach := _pop_reach(lines)
	if at.y - reach < limit:
		at.y = limit + reach
	return at


## Uses painted ink, not the canvas, which carries exhaust clearance and put BLOCKED 5 right.
## Why: docs/why/SectorScreen.md#pop-numbers
func _hull_ink(to_player: bool, who: int) -> Rect2:
	var inv := _view.fx.get_global_transform().affine_inverse()
	if to_player:
		var v := _view.ship_view()
		if v == null:
			return Rect2(_ship_pt(), Vector2.ZERO)
		var r := v.ship_rect()
		var g := v.get_global_transform()
		return Rect2(inv * (g * r.position), Vector2.ZERO).expand(inv * (g * r.end))
	var art := _view.enemy_view(who)
	if art == null:
		return Rect2(_view.enemy_anchor(who), Vector2.ZERO)
	# Rest position, not mid-slide: a number landing as a pack flew in hit a neighbour.
	var sl := _view.slot(who)
	if sl != null:
		var ink := sl.ink_rect()
		var at := sl.get_global_transform() * ink.position
		return Rect2(inv * at, ink.size)
	var u := art.used_rect()
	var tl := art.get_global_rect().position + (art.size - _canvas_size(art)) * 0.5
	return Rect2(inv * (tl + Vector2(u.position)), Vector2(u.size))


## What a volley did, popped where it landed: damage, then what was taken, or a miss.
func _pop_lines(q: Dictionary) -> int:
	return int(int(q.dealt) > 0) + int(int(q.absorbed) > 0) + int(int(q.missed) > 0)


func _pop_hit(at: Vector2, q: Dictionary, to_player: bool, killed: bool = false) -> void:
	# The held card's preview said "-6" or "-6 KILL" over this hull; the landing
	# says the same, in the same letters (`HitText`).
	var fx := _view.fx
	var y := 0.0
	if int(q.dealt) > 0:
		fx.pop(at + Vector2(0, y), ("-%d KILL" if killed else "-%d") % int(q.dealt),
			HitText.colour(&"hurt" if to_player else (&"kill" if killed else &"damage")), true)
		y -= HitText.LINE
	if int(q.absorbed) > 0:
		fx.pop(at + Vector2(0, y), "BLOCKED %d" % int(q.absorbed), HitText.colour(&"block"), true, 0.05)
		y -= HitText.LINE
	if int(q.missed) > 0:
		fx.pop(at + Vector2(0, y), "MISS" if int(q.missed) >= int(q.hits) else "%d MISSED" % int(q.missed),
			HitText.colour(&"miss"), true, 0.08)


## Two frames of white on whatever was hit (audit F3).
func _flash_hit(ci: CanvasItem) -> void:
	if ci == null or not is_instance_valid(ci) or ci.self_modulate.a <= 0.0:
		return
	ci.self_modulate = Color(2.4, 2.4, 2.4, ci.self_modulate.a)
	var tw := create_tween()
	tw.tween_interval(0.07)
	tw.tween_callback(func() -> void:
		if is_instance_valid(ci) and ci.self_modulate.a > 0.0:
			ci.self_modulate = Color(1, 1, 1, ci.self_modulate.a))


## A heavy hit holds the world still for a beat (audit F3): 50 ms at a twentieth
## speed. Off with reduced motion, like every other shake.
func _hitstop() -> void:
	if not Router.animating() or not DisplaySettings.screen_shake or Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.05, true, false, true).timeout
	Engine.time_scale = 1.0


## Asked of the texture, as the enemy art is being re-cut round PixelLab sprites.
func _canvas_size(art: EnemyArt) -> Vector2:
	if art.texture != null:
		return art.texture.get_size()
	return Vector2(EnemyArt.W, EnemyArt.H)


func _ship_pt() -> Vector2:
	var sv := _view.ship_view()
	if sv == null:
		return _view.ship_muzzle()
	return _view.fx.get_global_transform().affine_inverse() * sv.get_global_rect().get_center()


## How many wrecks lay in this system before the fight: enemy `i`'s will be
## wreck number `_wrecks_before + i` there when the fight is won.
var _wrecks_before := -1

func _count_wrecks() -> int:
	var n := 0
	for raw in Run.node_at().jetsam:
		if (raw as MapGen.Jetsam).is_wreck():
			n += 1
	return n

# ------------------------------------------------------------- hits, block, brace
# Hits, block and brace land on the frame their pop and sound do, on every ship.
# Why: docs/why/SectorScreen.md#hit-layers

## Where enemy `who`'s wreck will lie, by the same count `_death_style` uses.
func _wreck_id_of(who: int) -> int:
	if _wrecks_before < 0:
		_wrecks_before = _count_wrecks()
	return Run.node_at().index * 64 + _wrecks_before + who

## Your ship's.
var _ship_fx: HitLayers = null

func _enemy_fx(who: int) -> HitLayers:
	var sl := _view.slot(who) if _view != null else null
	return sl.layers if sl != null else null

func _enemy_marks(who: int) -> ShipHitFx:
	var L := _enemy_fx(who)
	return L.hits if L != null else null

func _fx_sync_enemy(who: int) -> void:
	var L := _enemy_fx(who)
	if L == null or who >= combat.enemies.size():
		return
	var e: Combat.EnemyState = combat.enemies[who]
	if e.hp <= 0 and not _slot_volleys.has(who):
		return
	if not L.moment.is_connected(_on_fx_moment):
		L.moment.connect(_on_fx_moment.bind(false, FaunaGuard.wants(L.kind), L))
	# a shot still in the air at it has already spent block in the maths
	L.sync(e.block, e.brace, int(_slot_shown.get(who, e.hp)), not _slot_volleys.has(who))

func _fx_sync_player() -> void:
	var sv := _view.ship_view() if _view != null else null
	if sv == null:
		return
	if _ship_fx == null or not is_instance_valid(_ship_fx):
		var seed := int(Rng.derive(&"hitfx_you", Run.node_at().index * 64 + posmod(Net.local_id(), 64)).randi() & 0x7fffffff)
		_ship_fx = HitLayers.for_ship(sv, seed, Run.max_hp())
		if _ship_fx == null:
			return
		sv.get_parent().add_child(_ship_fx)
		sv.get_parent().move_child(_ship_fx, sv.get_index() + 1)
		_ship_fx.moment.connect(_on_fx_moment.bind(true, false, _ship_fx))
	var pending := false
	for q in _volleys.values():
		if q.to_player:
			pending = true
	_ship_fx.sync(combat.block, combat.brace, Run.hp, not pending)

## Out of a fight, your ship's layers go (the marks with them: the hull is
## repaired by number, not by picture).
func _fx_drop_player() -> void:
	if _ship_fx != null and is_instance_valid(_ship_fx):
		_ship_fx.queue_free()
	_ship_fx = null

## Effect moments are heard on the frame each picture acts; unsounded ones stay quiet.
func _on_fx_moment(kind: StringName, s: float, len: float, mine: bool, creature: bool, from: HitLayers) -> void:
	# Nothing seen, nothing heard: open vents kept sputtering over a wreck.
	# Why: docs/why/SectorScreen.md#hit-layers
	if from != null and is_instance_valid(from) and not from.is_visible_in_tree():
		return
	match kind:
		&"shield_up":
			# an enemy's block arriving (yours plays with the card)
			if not mine:
				Audio.play(&"shield_block", 0.06, 90, -6.0)
		&"shield_ripple", &"shield_glitch":
			if not creature:
				Audio.fx(&"shield_glitch", kind)
		&"bolt_on", &"clamp":
			if creature:
				# a hide hardening is not plating: as it was until it has a sound
				if kind == &"clamp":
					Audio.play(&"shield_block", 0.06, 90, -8.0)
			else:
				Audio.fx(&"brace_on_yours" if mine else &"brace_on", kind)
		&"plate_off":
			if not creature:
				Audio.fx(&"brace_off", kind)
		&"hiss":
			Audio.fx(&"vent_hiss", kind)
		&"sputter":
			Audio.fx(&"vent_sputter", kind)
		&"crack":
			# a creature's crack is its scales shedding; a ship's, its hull
			Audio.fx(&"shed" if creature else &"crack_mark", kind)
		&"sizzle":
			# (a creature's sizzle is ichor, not heat: still unheard)
			if not creature:
				Audio.fx(&"heat_mark", kind)


## The shield's hum, every frame of a fight: up while any hex shield is up and
## seen (yours or theirs; a creature's glow skin is not one), down when none is.
func _shield_hum() -> void:
	var up := false
	if fighting() and _view != null and combat != null:
		var all: Array = [_ship_fx]
		for i in combat.enemies.size():
			all.append(_enemy_fx(i))
		for L: Variant in all:
			if L == null or not is_instance_valid(L):
				continue
			var hl := L as HitLayers
			var sh := hl.shield
			if sh != null and not (sh is FaunaShield) and sh.block > 0 and sh.is_visible_in_tree():
				up = true
				break
	Audio.fx_hold(&"shield_idle", up)


## A DEATH'S OWN BEATS, heard (a breakup's `moment`): the beats a style has
## besides its booms (`broke`, `Audio.play_kill`). `who` -1 is your ship.
func _on_death_moment(kind: StringName, _s: float, len: float, who: int, style: int) -> void:
	const S := ShipBreakup.Style
	if kind == &"prelude":
		# your ship's breakup, the bursts before its style: a whine up into it
		Audio.fx(&"charge_prelude", kind)
		return
	if style >= S.GLOWOUT and style <= S.PART:
		if kind == &"flare" or kind == &"pulse":
			Audio.play_kill(who)
		return
	if ShipBreakup._is_boss(style):
		_on_boss_moment(kind, len, style)
		return
	# (A's crack is its main break's buckling metal, `Audio.kill_beat`)
	if style == S.BURN and kind == &"burst":
		Audio.fx(&"heat", kind)
	elif (style == S.IMPLODE and kind == &"gather") or (style == S.BREACH and kind == &"charge") 			or (style == S.OVERLOAD and kind == &"spool"):
		Audio.fx(&"charge", kind, len)
	elif style == S.VENT and kind == &"vent":
		Audio.fx(&"vent_jet", kind)
	elif style == S.VENT and kind == &"sputter":
		Audio.fx(&"vent_sputter", kind)
	elif style == S.DISSOLVE and kind == &"fizz":
		Audio.fx(&"dissolve", kind)
	elif style == S.COLLAPSE and kind == &"pull":
		Audio.fx(&"collapse", kind, len)
	elif style == S.SHIELD and kind == &"shatter":
		Audio.fx(&"k_shatter", kind)
	elif style == S.MELT and kind == &"heat":
		Audio.fx(&"heat", kind)
	elif style == S.CRUMPLE and kind == &"crunch":
		Audio.fx(&"crumple", kind)


## The Custodian's and the Hellbender's.
func _on_boss_moment(kind: StringName, len: float, style: int) -> void:
	const S := ShipBreakup.Style
	var hell := style == S.HELL_CHAIN or style == S.HELL_BURNOUT or style == S.HELL_UNCOIL
	match kind:
		&"pop", &"rupture":
			# the Hellbender's holds and cargo; the Custodian's spine
			Audio.fx(&"boss_pop" if hell else &"spine_pop", kind)
		&"split":
			Audio.fx(&"boss_split", kind)
		&"emblem_heat":
			Audio.fx(&"hb_heat", kind)
		&"emblem_burst":
			Audio.fx_stop(&"hb_heat")
		&"crack":
			if not hell:
				Audio.fx(&"cust_crack", kind)
		&"beam":
			# (one hum for every beam: up with the first)
			Audio.fx_hold(&"arc", true, kind)
		&"swell":
			Audio.fx(&"riser", kind, len)
		&"crush":
			Audio.fx_stop(&"arc")
			Audio.fx(&"collapse", kind, len)
		&"implode":
			Audio.fx_stop(&"arc")


## THE STYLE ENEMY `who` DIES IN: rolled from where its wreck will lie, the
## same roll LOCAL makes for that wreck later (`EnemyArt.death_style`).
func _death_style(who: int) -> int:
	if combat == null or who < 0 or who >= combat.enemies.size():
		return EnemyArt.SHIP_STYLES[0]
	if _wrecks_before < 0:
		_wrecks_before = _count_wrecks()
	return EnemyArt.death_style(combat.enemies[who].template, Run.node_at().index,
		_wrecks_before + who)

## Prebuilt on a worker: cutting a hull is 40 to 90 ms and froze impact at 105 to 128 ms.
## Why: docs/why/SectorScreen.md#death-breakup
var _prebuilt: Dictionary = {}

func _prebuild_death(who: int) -> void:
	# Creature movement settles first, so the cut matches what is on screen.
	if _view.slot(who) != null:
		_view.slot(who).fauna_settle()
	if not Router.animating():
		return
	var sl := _view.slot(who)
	if sl == null or sl.art == null or who >= combat.enemies.size() or _prebuilt.has(who):
		return
	var e: Combat.EnemyState = combat.enemies[who]
	# Cut from the dead ship so the breakup's last frame is the wreck drawn afterwards.
	var dc := EnemyArt.dead_canvas(e, _enemy_marks(who), sl.art.draw_scale)
	var img: Image = dc[0]
	var used: Rect2i = dc[1]
	var seed := EnemyArt.wreck_seed(e.template)
	var boss: bool = e.template.boss
	var style := _death_style(who)
	var marked := _enemy_marks(who) != null
	var held := {b = null, w = null}
	# the node here, the cut on the worker, `finish` here once it is taken
	var b := ShipBreakup.new()
	var task := WorkerThreadPool.add_task(func() -> void:
		b.setup(img, used, Vector2.ZERO, style, seed, boss)
		held.b = b
		if marked:
			held.w = ShipBreakup.wreck_image(img, used, seed, boss, style))
	_prebuilt[who] = {task = task, held = held, scale = sl.art.draw_scale}


## How long a creature winds up before its shot leaves.
const FAUNA_ANTICIPATION := 0.35

## A creature about to fire, with its own movement on screen: start its
## wind-up (`FaunaMotion.strike`, held through the shot) and say so.
func _fauna_winds_up(who: int) -> bool:
	var fslot := _view.slot(who) if _view != null else null
	if fslot == null or fslot.fauna_motion() == null or not Router.animating():
		return false
	return fslot.fauna_strike()


## The ship comes apart where it stood, cut out of its own picture.
func _start_death(who: int) -> void:
	_dying.erase(who)
	var sl := _view.slot(who)
	if sl == null or sl.art == null or who >= combat.enemies.size():
		return
	var art := sl.art
	var e: Combat.EnemyState = combat.enemies[who]
	var mk := _enemy_marks(who)
	# WITHOUT MOTION a death is the wreck, at once (reduced motion, headless) --
	# still the wreck with its marks.
	if not Router.animating():
		if mk != null:
			var dc0 := EnemyArt.dead_canvas(e, mk, art.draw_scale)
			EnemyArt.set_marked_wreck(_wreck_id_of(who), _death_style(who), ShipBreakup.wreck_image(dc0[0], dc0[1],
				EnemyArt.wreck_seed(e.template), e.template.boss, _death_style(who)))
		sl.hide_art(false)
		_show_slot(who)
		_check_ending()
		return
	var b: ShipBreakup = null
	if _prebuilt.has(who):
		var pre: Dictionary = _prebuilt[who]
		_prebuilt.erase(who)
		WorkerThreadPool.wait_for_task_completion(pre.task)
		# cut at the size the ship is drawn now (`EnemyArt.draw_scale`)
		if is_equal_approx(float(pre.get("scale", 1.0)), art.draw_scale):
			b = pre.held.b
			if b != null:
				b.finish()
			if pre.held.w != null:
				EnemyArt.set_marked_wreck(_wreck_id_of(who), _death_style(who), pre.held.w)
		elif pre.held.b != null:
			(pre.held.b as Node).free()
	if b == null:
		b = ShipBreakup.new()
		var dc := EnemyArt.dead_canvas(e, mk, art.draw_scale)
		b.setup(dc[0], dc[1], Vector2.ZERO, _death_style(who),
			EnemyArt.wreck_seed(e.template), e.template.boss)
		if mk != null:
			EnemyArt.set_marked_wreck(_wreck_id_of(who), _death_style(who), ShipBreakup.wreck_image(dc[0], dc[1],
				EnemyArt.wreck_seed(e.template), e.template.boss, _death_style(who)))
	# Cut at the origin; placed by moving the whole thing.
	b.size = _view.size
	_view.add_child(b)
	# Under the shots and the numbers, over everything else.
	_view.move_child(b, _view.fx.get_index())
	# Rest position, so the breakup hands back to the wreck pixel for pixel.
	var rest := sl.holder_rect().position + sl._art_base
	var canvas := rest + (art.size - _canvas_size(art)) * 0.5
	var base := (_view.get_global_transform().affine_inverse() * canvas).round()
	b.position = base + Vector2(0, roundf(art.position.y - sl._art_base.y))
	sl.hide_art(true)
	var entry := {b = b, art = art, y0 = sl._art_base.y, base = base}
	_breakups.append(entry)
	# Sound on each visible break, never on the resolution (Jon's rule).
	# Why: docs/why/SectorScreen.md#death-breakup
	if not e.template.fauna:
		b.broke.connect(func(s: float) -> void:
			Audio.kill_beat(s))
	b.moment.connect(_on_death_moment.bind(who, b.style))
	# (a furnace under a set piece goes with it, however it ends)
	if ShipBreakup._is_boss(b.style):
		b.tree_exiting.connect(func() -> void:
			Audio.fx_stop(&"hb_heat")
			Audio.fx_stop(&"arc"))
	# A BOSS'S SET PIECE HOLDS THE SCREEN (`ScreenHooks`): the shake, the slow
	# motion, the flash and the music's duck and hit it names as moments.
	var hooks: ScreenHooks = null
	if ShipBreakup._is_boss(b.style):
		hooks = ScreenHooks.new()
		hooks.target = _view
		add_child(hooks)
		b.moment.connect(hooks.on_moment)
	b.finished.connect(func() -> void:
		sl.hide_art(false)
		_breakups.erase(entry)
		b.queue_free()
		if hooks != null and is_instance_valid(hooks):
			hooks.queue_free()
		_check_ending())


# ------------------------------------------------------------- your ship, lost
# Your hull comes apart, holds a beat, then RUN ENDED; the run was over in the maths.
# Why: docs/why/SectorScreen.md#ship-loss

## How long the wreck is held before the run's screen.
const WRECK_HOLD_S := 1.0

## Which of three filmed hand-offs plays: A linger, B pull back, C signal lost.
const DEATH_HANDOFF := "A"
## A harness's pick of the three, for filming them side by side; empty in play.
static var handoff_override := ""
## A: how long the picture takes to darken and drain.
const LINGER_S := 1.2
## B: how long the camera takes to pull back.
const PULL_S := 1.0
## C: how long the feed takes to die.
const SIGNAL_S := 1.3
var _loss_carried := false

## The cut, started when the fight resolved (`_prebuild_loss`).
var _loss_pre: Dictionary = {}
## Your ship's breakup, once it is playing; its last frame is the wreck held on.
var loss: ShipBreakup = null

func _prebuild_loss() -> void:
	if not Router.animating() or not _loss_pre.is_empty() or _view == null:
		return
	var pic := ShipLoss.picture(_view.ship_view())
	if pic.is_empty():
		return
	# with the marks the fight left on your hull, where the hull is now
	if _ship_fx != null:
		var mi := _ship_fx.hits.marks()
		var dy := _view.ship_view().bob_offset() - _ship_fx.bob0
		(pic.img as Image).blend_rect(mi, Rect2i(Vector2i.ZERO, mi.get_size()), _ship_fx.hits.marks_at() + Vector2i(0, dy))
	var n := Run.node_at().index
	var me := Net.local_id()
	_loss_pre = ShipLoss.prebuild(pic, ShipLoss.style_for(n, me), ShipLoss.seed_for(n, me))


## THE WRECK INTO RUN ENDED, one of three ways (see DEATH_HANDOFF). Leaves the
## picture it ended on with the Router, which RUN ENDED is drawn over.
func _death_handoff() -> void:
	if not Router.animating():
		return
	var look := handoff_override if handoff_override != "" else DEATH_HANDOFF
	var fade := DeathHandoff.new()
	add_child(fade)
	# THE SET GOING OFF as the picture starts to go (Jon's quit sound: a line,
	# a dot, a click as it goes dark)
	Audio.fx(&"loss_handoff")
	match look:
		"B":
			# the hand down first: the camera holds every scene where it stands
			var lowered := [false]
			_lower_band(func() -> void: lowered[0] = true)
			while not lowered[0] and is_inside_tree():
				await get_tree().process_frame
			if not is_inside_tree():
				return
			var lad_ok := ladder_ready()
			if lad_ok:
				ladder_cam_begin(ZoomLadder.MAP, 2, "A")
				# your wreck rides the camera with the rest of the scene
				if not _lad.is_empty() and loss != null and is_instance_valid(loss):
					_loss_carried = true
					var fixed: Vector2 = _lad.fixed
					(_lad.scenes as Array).append([loss, loss.scale, loss.offset_left, loss.offset_top,
						loss.offset_right, loss.offset_bottom, loss.size,
						loss.get_global_transform().affine_inverse() * fixed,
						loss.get_global_transform().affine_inverse()])
			var tw := create_tween()
			tw.tween_method(func(k: float) -> void:
				var e := k * k * (3.0 - 2.0 * k)
				if lad_ok:
					ladder_cam(e)
					ladder_chrome(clampf(k * 3.0, 0.0, 1.0))
				fade.set_dim(clampf((k - 0.35) / 0.65, 0.0, 1.0) * 0.6),
				0.0, 1.0, PULL_S)
			await tw.finished
		"C":
			var tw2 := create_tween()
			tw2.tween_method(fade.set_signal, 0.0, 1.0, SIGNAL_S)
			await tw2.finished
		_:
			_lower_band(func() -> void: pass)
			var tw3 := create_tween()
			tw3.tween_method(fade.set_dim, 0.0, 1.0, LINGER_S) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await tw3.finished
	if not is_inside_tree():
		return
	Router.death_still = await fade.still()
	Router.death_look = &"type" if look == "C" else &"rise"


## How long the picked handoff takes, s.
static func handoff_s() -> float:
	var look := handoff_override if handoff_override != "" else DEATH_HANDOFF
	match look:
		"B":
			return LOWER_S + BAND_FADE_S + PULL_S
		"C":
			return SIGNAL_S
	return LINGER_S


## Your hull breaks up; returns once it has, true if it did.
func _lose_ship() -> bool:
	if _loss_pre.is_empty() or not Router.animating():
		return false
	var pre := _loss_pre
	_loss_pre = {}
	var v := _view.ship_view()
	# Under the shots and the numbers, over everything else, as a kill is. At
	# the hull's place AT REST: the hit's kick may still be shaking the view.
	var b := ShipLoss.play(pre, _view, v, _view.fx.get_index())
	if b == null:
		return false
	v.visible = false
	loss = b
	# The explosion on each visible break, the enemies' pool (Jon's rule:
	# sound follows what you see, never the resolution).
	b.broke.connect(func(s: float) -> void:
		Audio.kill_beat(s))
	b.moment.connect(_on_death_moment.bind(-1, b.style))
	await b.finished
	return is_inside_tree()


func _process(_delta: float) -> void:
	_shield_hum()
	if _wake_t >= 0.0:
		_wake_step(_delta)
	# A breakup draws where the hull was; the hull's slot keeps its slow bob, so
	# the breakup rides it, and the wreck it hands back to is where it ended.
	for en in _breakups:
		var b: ShipBreakup = en.b
		var art: EnemyArt = en.art
		if is_instance_valid(b) and is_instance_valid(art):
			b.position = Vector2(en.base) + Vector2(0, roundf(art.position.y - float(en.y0)))
	# Your wreck stays on your hull's place while the layout moves under it (the
	# hand lowering), until a camera move carries it (`_death_handoff` B).
	if loss != null and is_instance_valid(loss) and not _loss_carried and _view != null:
		ShipLoss.place(loss, _view, _view.ship_view())


## Ends once nothing is in the air; the core's guard hands off on the `won` branch.
## Why: docs/why/SectorScreen.md#fight-end
func _check_ending() -> void:
	if _ending.is_empty() or _ending_started or _hold or _playing:
		return
	if not _volleys.is_empty() or not _breakups.is_empty() or not _dying.is_empty():
		return
	_ending_started = true
	var r: StringName = _ending.result
	match r:
		&"victory", &"won":
			_lower_band(func() -> void:
				# LOCAL arrives with this layout, so no fade; the wrecks stay put.
				Router.seamless_next = true
				# Nor the page's door sound: nothing on screen changes page.
				Audio.suppress(&"ui_tab", 300)
				_leave_combat())
		&"dead":
			# Your ship comes apart, a beat on the wreck, then the run's own screen.
			if await _lose_ship():
				# THE SCORE STEPS BACK through the gap the breakup leaves, the
				# wreck's hold and the handoff, and comes up as Lights Out
				Audio.fx(&"loss_duck", &"", WRECK_HOLD_S + handoff_s())
				await _wait_s(WRECK_HOLD_S)
				# and from the wreck into RUN ENDED, not a cut (`DeathHandoff`)
				if is_inside_tree():
					await _death_handoff()
			else:
				await _wait_s(0.7)
			if is_inside_tree():
				# RUN ENDED is not another page: no page door on the swap
				Audio.fx(&"loss_swap")
				_leave_combat()
		&"broke_off":
			await _escape(0)
			if is_inside_tree():
				_end_panel("IT GOT AWAY", UITheme.HOT, Color("#8a6420"), String(_ending.text))
		&"pacified":
			_end_panel("LEFT IN PEACE", UITheme.GOOD, Color("#3f6a52"), String(_ending.text))
		_:
			_end_panel("COMBAT ENDED", UITheme.ICE, UITheme.LINE, String(_ending.text))


## A contact leaves under its own power; before, it was a black COMBAT ENDED screen.
func _escape(who: int) -> void:
	var sl := _view.slot(who)
	if sl == null or not Router.animating():
		return
	var art := sl.art
	_view.fx.flash(_view.enemy_anchor(who), true, true)
	Audio.play(&"hyperjump", 0.0)
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(art, "position:x", art.position.x + 700.0, 0.5)
	tw.tween_property(sl, "modulate:a", 0.0, 0.45)
	await tw.finished


## An ending nobody pressed a button for, said in the same panel the exits use,
## over the scene rather than instead of it.
func _end_panel(title: String, ink: Color, edge: Color, text: String) -> void:
	_ask_exit(title, ink, edge, text, "", "", Callable())
	_exit_ask_result(title, ink, text, func() -> void:
		_close_exit_ask()
		_lower_band(_on_continue))


## The band shrinks to LOCAL's height over `LOWER_S`, so the ships ease down, not drop.
## Why: docs/why/SectorScreen.md#hand-lowering
func _lower_band(then: Callable) -> void:
	if _lowered:
		then.call()
		return
	_lowered = true
	# a fight over before its hand was up: down from wherever it had got to
	_stop_raise()
	_clear_readout()
	_end_aim(false)
	var n: MapGen.MapNode = Run.node_at()
	if n != null and not Run.dead:
		_rebuild_drawer(n)
	_sync_drawer_box()
	var target := _one_line_height()
	var from := _hand_holder.size.y
	# Down, never up: at the core LOCAL's band was taller and pulled ships to the top.
	# Why: docs/why/SectorScreen.md#hand-lowering
	target = minf(target, from)
	if not Router.animating() or _hand_holder == null or not _hand_holder.visible:
		_finish_lower()
		then.call()
		return
	var tw := create_tween()
	tw.tween_method(func(h: float) -> void:
		_hand_holder.custom_minimum_size = Vector2(0, roundf(h * 0.5) * 2.0),
		from, target, LOWER_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# the band starts down: the escape menu's close (Jon: the same drawer)
	Audio.fx(&"fight_band_down")
	if _self_plate != null:
		tw.parallel().tween_property(_self_plate, "modulate:a", 0.0, LOWER_S * 0.5)
	tw.tween_callback(func() -> void:
		_finish_lower()
		_quiet_wrap.modulate.a = 0.0)
	# (a lost run's band stays away: SCAN SECTOR is nothing to offer a wreck)
	tw.tween_property(_quiet_wrap, "modulate:a", 0.0 if Run.dead else 1.0, BAND_FADE_S)
	tw.tween_callback(then)


## A hidden wrapping label measures as single words, so a tall measure becomes one line.
## Why: docs/why/SectorScreen.md#hand-lowering
func _one_line_height() -> float:
	var measured := _quiet_wrap.get_combined_minimum_size().y
	if measured < DRAWER_H:
		return measured
	var sb := _quiet_wrap.get_theme_stylebox(&"panel")
	var pad := sb.get_minimum_size().y if sb != null else 0.0
	var line := float(UITheme.pixel_font().get_height(UITheme.FS_SMALL))
	return maxf(EncounterDrawer.BTN.y, line) + pad


func _finish_lower() -> void:
	if _hand_holder != null:
		_hand_holder.visible = false
	if _quiet_holder != null:
		_quiet_holder.visible = true
	_open_drawer(true)
