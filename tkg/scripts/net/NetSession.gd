class_name NetSession
extends Node

## Session layer only: it moves no ship and resolves no card. The host is the authority.
## Why: docs/why/NetSession.md#session-design

## Bump on any change to the messages or the meaning of their fields.
## Cheap to raise, very expensive to forget: a mismatch is refused at the door.
## Why: docs/why/NetSession.md#protocol-versions
const PROTOCOL: int = 18

## Generous: giving up early costs a wreck, assuming costs the party's economy.
## Why: docs/why/NetSession.md#take-timeout
const TAKE_TIMEOUT: float = 3.0

const MAX_PLAYERS: int = NetTransport.MAX_PLAYERS

## A variable only so the headless test need not wait ten real seconds.
const HANDSHAKE_TIMEOUT: float = 10.0
var handshake_timeout: float = HANDSHAKE_TIMEOUT

enum State {
	OFFLINE,     ## No peer. The solo game.
	HOSTING,     ## Peer open, code readable, waiting for friends.
	JOINING,     ## Connecting, or connected and waiting on the handshake.
	IN_PARTY,    ## Handshake done. The roster is live.
	DIVING,      ## Launched. The roster is closed.
	FAILED,      ## See last_error(). Held so a screen can show why.
}

var state: State = State.OFFLINE
var transport: NetTransport = null
## Host only until launch, then everyone. Keyed by peer id; 1 is the host.
var roster: Dictionary = {}
## What the host rolled for this dive. Zero until launch.
var dive_seed: int = 0
## The host's unlocked manufacturers, sent with the seed. Empty until launch.
var dive_unlocked: Array[StringName] = []
## A max, so reports in any order or twice agree; the Custodian grows on it.
## Why: docs/why/NetSession.md#lead-ship-jumps
var galaxy_jumps: int = 0
## Host only: each guest's last jumps, so a first presence is not read as a jump.
var _jumps_said: Dictionary = {}

var _error: String = ""
var _local_name: String = "Pilot"
var _local_hull: StringName = &""
var _content_hash: int = 0
var _handshake_deadline: float = 0.0

## Test seams: pretend to be another build to reach the refusal paths. Never set in game.
var forced_protocol: int = 0
var forced_fingerprint: int = 0
## And which build this session claims to be (`-- nettest`); empty is the real one.
var forced_build: String = ""
## Test seam: holds fight asks until `release_asks()`. Never set from game code.
var hold_asks: bool = false
var _held_asks: Array = []
## A SWING'S TARGET, FORCED (`-- nettest`, `-- sheet=MidJoinTest`): every swing
## goes to this peer while it is in the fight's crew. 0 is the real roll.
## Never set from game code.
var forced_target: int = 0
## THE FIGHT THIS MACHINE IS ASKING TO BE SEATED IN, or -1 (PROTOCOL 18). A
## stunned joiner counts as ended, so a partner's END TURN can swing at it
## while its ask is still on the wire and no Combat is listening yet: those
## swings are held here (`_held_swings`) and the Combat plays them as it begins
## (`take_held_swings`).
var _asking_at: int = -1
var _held_swings: Array = []
## The system whose JOIN the host answered with "nothing open here any more"
## (`_no_fight_to`), or -1.
var _no_fight_at: int = -1

## Arrival order, as peer ids are random and sorting by them shuffles the lobby list.
var _join_serial: int = 0
var _said_hello: bool = false
## True while `_swing` runs, so a host leaving mid-swing cannot start a second one inside it.
var _swinging: bool = false

## Fingerprinted so an unchanged ship returns as the same object and is not repainted.
## Why: docs/why/NetSession.md#build-cache
var _builds: Dictionary = {}

## A fingerprint, not the dictionary: comparing nested dictionaries per frame is the wrong trade.
var _presence_sent: int = 0
var _presence_dirty: bool = false

## One shared map, not four copies: a seed cannot say who already stripped a node.
## Pushed whole, per option, with the peer id, so it cannot drift.
## Why: docs/why/NetSession.md#claims
var claims: Dictionary = {}

## Only the enemy is shared. Kept after `over` so the last push has somewhere to land.
## Why: docs/why/NetSession.md#shared-fights
var fights: Dictionary = {}

## Not on the roster: it changes several times a second, so it is a small unreliable message.
## Why: docs/why/NetSession.md#spots
var spots: Dictionary = {}
## Each partner's flight under way (PROTOCOL 17): peer id -> its said path, burns, clocks and ends.
## Dropped with the partner's spots.
## Why: docs/why/NetSession.md#partner-flights
var flights: Dictionary = {}
## the flight this machine said last (its plan's instance id), so it is said once
var _flight_said := 0
## THE HOST'S OWN FLIGHT UNDER WAY, as it said it (the same row), told to a ship
## joining while it flies (`_hello`): said once to the peers there then, a late
## joiner never heard it (the code review, Nov 5)
var _own_flight: Dictionary = {}
## Only the seed crosses the wire, so each guest reports what it built and mismatches are said.
## Why: docs/why/NetSession.md#galaxy-check
var galaxy_mine: Array = []
var _galaxy_theirs: Dictionary = {}
## What the screens were told, or "" while every galaxy matches.
var galaxy_warning: String = ""
## Test seam: a fingerprint to claim instead of the one built. Never set from
## game code. `-- cojoin join CODE skew` sets it to force the mismatch.
var forced_galaxy: int = 0

## Throttle for `report_spot`: what was last sent and when ([at, body, x, z,
## ang, host, held]).
var _spot_sent: Array = []
var _spot_ms: int = 0
const SPOT_EVERY_MS := 150
## A spot is re-said while a map is up, so a lost packet costs only a few seconds.
const SPOT_BEAT_MS := 1000
const RUN_ON_MAX := 3.0
## Bounds on what a peer may say, each far above play. The lobby's name field holds 14 characters.
const NAME_MAX := 24
## At most this many foes in a fight (`Combat.plan`: a lead and three more).
const FIGHT_FOES_MAX := 4
## Hull and brace a peer may open a fight with: the largest `max_hull` is a few hundred.
const FOE_STAT_MAX := 10000
## About 60 points a second, so nearly half an hour of flight; a real plan is minutes.
const FLIGHT_POINTS_MAX := 100000
## Claims one system may hold: its shelf, hull rack, bag, sites and every wreck's contents.
const CLAIMS_PER_NODE := 2048
## The last option id a claim may name: 1000 wrecks of `JETSAM_STRIDE` items.
const OPTION_MAX := MapGen.OPTION_JETSAM + MapGen.JETSAM_STRIDE * 1000
## A map clock is seconds of play; this is eleven weeks of it.
const MAP_CLOCK_MAX := 1.0e7


func _ready() -> void:
	# Only the autoload copy is reachable by name; headless test instances must not pass for it.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_host_lost)

	# Forwards a picture of the ship only, so it does not breach the session-layer rule.
	# Why: docs/why/NetSession.md#presence
	Sig.ship_changed.connect(_mark_presence)
	Sig.resources_changed.connect(_mark_presence)
	Sig.player_combat_state_changed.connect(_mark_presence)
	# A jump is the only event that moves a ship between systems, so it alone changes `at`.
	Sig.run_started.connect(_on_run_started)
	Sig.jumped.connect(_on_jumped)


## This machine's ship jumped to `index`.
func _on_jumped(index: int) -> void:
	_mark_presence()
	# The host's own jump raises the lead ship's count here; a guest's
	# arrives with its presence (`_apply_presence`)
	if is_host():
		_fold_growth(_my_jumps())
	# and, inside the new system, at its edge (see `spots`)
	report_arrival(index)


# --- what a screen calls -------------------------------------------------

## Open a party. Returns the lobby code to read out, or "" with last_error()
## set. The transport is passed in rather than chosen here — see NetTransport.
func host_party(player_name: String, hull_id: StringName, t: NetTransport = null) -> String:
	if state != State.OFFLINE:
		_error = "Already in a party."
		return ""
	transport = t if t != null else DirectTransport.new()
	var peer := transport.create_host()
	if peer == null:
		return _fail(transport.last_error())
	_local_name = player_name
	_local_hull = hull_id
	_content_hash = forced_fingerprint if forced_fingerprint != 0 else content_fingerprint()
	multiplayer.multiplayer_peer = peer
	roster.clear()
	_builds.clear()
	claims.clear()
	fights.clear()
	_held_asks.clear()
	spots.clear()
	flights.clear()
	_own_flight = {}
	_flight_said = 0
	_galaxy_theirs.clear()
	galaxy_mine.clear()
	galaxy_warning = ""
	_said_hello = false
	_join_serial = 0
	_presence_sent = 0
	_presence_dirty = true
	galaxy_jumps = 0
	_jumps_said.clear()
	roster[1] = _slot(1, player_name, hull_id, 0)
	_set_state(State.HOSTING)
	Sig.party_changed.emit()
	return transport.code


## Join a party by code. Returns false immediately on a bad code; a good code
## that cannot be reached fails later, through Sig.party_failed.
func join_party(code: String, player_name: String, hull_id: StringName, t: NetTransport = null) -> bool:
	if state != State.OFFLINE:
		_error = "Already in a party."
		return false
	transport = t if t != null else DirectTransport.new()
	var peer := transport.create_client(code)
	if peer == null:
		_fail(transport.last_error())
		return false
	_local_name = player_name
	_local_hull = hull_id
	_content_hash = forced_fingerprint if forced_fingerprint != 0 else content_fingerprint()
	multiplayer.multiplayer_peer = peer
	roster.clear()
	_builds.clear()
	claims.clear()
	fights.clear()
	_held_asks.clear()
	spots.clear()
	flights.clear()
	_own_flight = {}
	_flight_said = 0
	_galaxy_theirs.clear()
	galaxy_mine.clear()
	galaxy_warning = ""
	_said_hello = false
	_presence_sent = 0
	_presence_dirty = true
	galaxy_jumps = 0
	_jumps_said.clear()
	_handshake_deadline = _now() + handshake_timeout
	_set_state(State.JOINING)
	return true


func leave_party() -> void:
	# `multiplayer` is null on a node that is not in a tree. That is not a
	# hypothetical: a lobby screen torn down mid-connect frees its way out.
	if multiplayer == null:
		_set_state(State.OFFLINE)
		return
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	roster.clear()
	_builds.clear()
	claims.clear()
	fights.clear()
	_held_asks.clear()
	spots.clear()
	flights.clear()
	_own_flight = {}
	_flight_said = 0
	_galaxy_theirs.clear()
	galaxy_mine.clear()
	galaxy_warning = ""
	transport = null
	dive_seed = 0
	dive_unlocked.clear()
	galaxy_jumps = 0
	_jumps_said.clear()
	_set_state(State.OFFLINE)
	Sig.party_changed.emit()


func set_ready(value: bool) -> void:
	if state != State.IN_PARTY and state != State.HOSTING:
		return
	if is_host():
		_apply_ready(1, value)
	else:
		_set_ready_at_host.rpc_id(1, value)


func choose_hull(hull_id: StringName) -> void:
	_local_hull = hull_id
	if is_host():
		_apply_hull(1, hull_id)
	else:
		_choose_hull_at_host.rpc_id(1, hull_id)


## Host only. Rolls the galaxy and tells everyone to start on it.
func launch_dive() -> bool:
	if not is_host() or state != State.HOSTING:
		_error = "Only the host starts the dive."
		return false
	if not everyone_ready():
		_error = "Somebody is not ready."
		return false
	# Through `Rng`, not `randi()`, so `-- seed N` on the host puts the party in a known galaxy.
	var seed_value := Rng.roll_master()
	# AND WHAT THE WORLD MAY HOLD, which is the host's to say for the same
	# reason the seed is. Strings on the wire, the way a build's ids travel.
	var open: Array = Array(Unlocks.open_now()).map(
		func(m: StringName) -> String: return String(m))
	_begin_dive.rpc(seed_value, open)
	_apply_dive(seed_value, open)
	return true


# --- what a screen reads -------------------------------------------------

func is_networked() -> bool:
	return state != State.OFFLINE and state != State.FAILED


## Guarded on `multiplayer` itself: it is null while the node is out of the tree.
## Why: docs/why/NetSession.md#null-multiplayer
func is_host() -> bool:
	return multiplayer != null and multiplayer.multiplayer_peer != null and multiplayer.is_server()


func local_id() -> int:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return 1
	return multiplayer.get_unique_id()


func party_size() -> int:
	return roster.size()


## The players in this game, for the enemy's hull and the pay (`PartyScale`, PROTOCOL 18).
## 1 alone or off the dive's galaxy; a dead pilot or one `away` is not counted.
## Why: docs/why/NetSession.md#party-count
func party_count() -> int:
	if not is_networked() or not _on_dive_galaxy():
		return 1
	var n := 0
	for id: int in roster.keys():
		if bool(roster[id].get("away", false)):
			continue
		var b := build_of(id)
		if b != null and b.dead:
			continue
		n += 1
	return clampi(n, 1, MAX_PLAYERS)


func everyone_ready() -> bool:
	if roster.is_empty():
		return false
	for slot in roster.values():
		if not slot.ready:
			return false
	return true


## Which build this session is (`BuildInfo.stamp()`), as the handshake says it.
func local_build() -> String:
	return forced_build if forced_build != "" else BuildInfo.stamp()


func last_error() -> String:
	return _error


## Null is a real answer: a slot exists before its ship does.
func build_of(id: int) -> ShipBuild:
	if not roster.has(id):
		return null
	var wire: Dictionary = roster[id].get("build", {})
	if wire.is_empty():
		return null
	var stamp := hash(wire)
	var held: Array = _builds.get(id, [])
	if held.size() == 2 and int(held[0]) == stamp:
		return held[1]
	var made := ShipBuild.from_wire(wire)
	_builds[id] = [stamp, made]
	return made


## -1 is a real answer: a player on the chassis select has no position yet.
func where_is(id: int) -> int:
	if not roster.has(id):
		return -1
	return int(roster[id].get("at", -1))


## Everyone except you, in arrival order. What the convoy strip draws.
func partners() -> Array:
	var me := local_id()
	return slots().filter(func(s: Dictionary) -> bool: return int(s.id) != me)


## Ordered for display: the host first, then by the order people arrived.
func slots() -> Array:
	var out: Array = roster.values().duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.order < b.order)
	return out


## Sorted as Strings: StringName arrays sort by process start order, so a build refused itself.
## Why: docs/why/NetSession.md#content-fingerprint
static func sorted_ids(table: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for id in table:
		out.append(String(id))
	out.sort()
	return out


## Covers the content tables, not the build, and is coarse: it says something differs, not what.
## Why: docs/why/NetSession.md#content-fingerprint
func content_fingerprint() -> int:
	var parts: PackedStringArray = []
	parts.append_array(sorted_ids(DB.modules))
	parts.append_array(sorted_ids(DB.enemies))
	for h in DB.hull_frames:
		parts.append("%s/%d" % [h.manufacturer, int(h.weight)])
	for a in DB.affixes:
		parts.append(a.name)
	# Includes the galaxy table: peers whose kinds differ lay out different maps from one seed.
	# Why: docs/why/NetSession.md#content-fingerprint
	parts.append(GalaxyGen.table_fingerprint())
	# Includes option ids, not prose: differing pools roll different lists at the same node.
	# Why: docs/why/NetSession.md#content-fingerprint
	var opt_ids: PackedStringArray = []
	for o in OptionTable.all():
		opt_ids.append(String(o.id))
	opt_ids.sort()
	parts.append("|".join(opt_ids))
	return hash("|".join(parts))


func _process(_delta: float) -> void:
	# Coalesced to one send per frame: one thing a partner sees fires many signals.
	if _presence_dirty and _can_talk():
		_presence_dirty = false
		_send_presence()
	if state != State.JOINING:
		return
	# Watch the peer status directly so a refusal shows at once, not after the handshake timeout.
	# Why: docs/why/NetSession.md#failed-join
	var peer := multiplayer.multiplayer_peer if multiplayer != null else null
	if peer == null or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		_drop(_why("Could not reach the party."))
		return
	if _now() > _handshake_deadline:
		_drop(_why("The host did not answer. Check the code, and whether the port is open."))


# --- the handshake --------------------------------------------------------
# Host side is `_hello` alone: a refused client learns nothing about the party.
# Why: docs/why/NetSession.md#handshake

@rpc("any_peer", "call_remote", "reliable")
func _hello(protocol: int, fingerprint: int, player_name: String, hull_id: StringName, build: String) -> void:
	if not is_host():
		return
	var who := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		_turn_away(who, "Different game version. Host is protocol %d, you are %d." % [PROTOCOL, protocol])
		return
	# Check the build before content, and only between two stamped builds:
	# a run from source says dev and is judged by protocol and content alone.
	var mine := local_build()
	if build != mine and build != "dev" and mine != "dev":
		_turn_away(who, "Your friend is on build %s; you're on %s. Both need the same build." % [mine, build])
		return
	if fingerprint != _content_hash:
		_turn_away(who, "Your content does not match the host's. Compare builds or mods.")
		return
	if roster.size() >= MAX_PLAYERS:
		_turn_away(who, "The party is full.")
		return
	_join_serial += 1
	roster[who] = _slot(who, player_name.substr(0, NAME_MAX), hull_id, _join_serial)
	_accept.rpc_id(who)
	_push_roster()
	Sig.party_changed.emit()
	# The seed went out once at launch, so a late joiner is told the rest of the state at the door.
	# Why: docs/why/NetSession.md#late-joiners
	if state == State.DIVING and dive_seed != 0:
		var open: Array = Array(dive_unlocked).map(
			func(m: StringName) -> String: return String(m))
		_begin_dive.rpc_id(who, dive_seed, open)
		# Sent after `_begin_dive` on the same reliable channel, and quiet so no arrival shows.
		_push_growth_to.rpc_id(who, galaxy_jumps, true)
		_push_claims_to.rpc_id(who, claims)
		_push_hellbender_to.rpc_id(who, Run.hellbender_at, Run.hellbender_hp, Run.hellbender_moves, false)
		for f: SharedFight in fights.values():
			if not f.over:
				_push_fight_to.rpc_id(who, f.to_wire())
		# THE FLIGHTS UNDER WAY (PROTOCOL 17), each said once as it left: the
		# partners' as this machine keeps them and its own, the sender's clock
		# run on to now
		var now := Time.get_ticks_msec()
		for fid in flights.keys():
			_tell_flight(who, int(fid), flights[fid], now)
		if not _own_flight.is_empty():
			_tell_flight(who, 1, _own_flight, now)


@rpc("authority", "call_remote", "reliable")
func _accept() -> void:
	_set_state(State.IN_PARTY)


@rpc("authority", "call_remote", "reliable")
func _refuse(reason: String) -> void:
	_drop(reason)


@rpc("authority", "call_remote", "reliable")
func _push_roster_to(rows: Array) -> void:
	roster.clear()
	# Not `_builds.clear()`: `build_of()` hands back the old object for an unchanged ship.
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and row.has("id") and typeof(row.id) == TYPE_INT:
			roster[int(row.id)] = row
	# A leaver's spot goes here too, or a guest keeps its clock as the party's for good.
	for id in spots.keys():
		if not roster.has(int(id)):
			spots.erase(id)
			flights.erase(id)
	if state == State.JOINING:
		_set_state(State.IN_PARTY)
	Sig.party_changed.emit()


## The sender of a message bound for the host, or 0 when this is not the host or the sender never
## said hello: a refused or silent peer may still be connected and can send anything.
## Why: docs/why/NetSession.md#handshake
func _member_sender() -> int:
	if not is_host():
		return 0
	var who := multiplayer.get_remote_sender_id()
	return who if roster.has(who) else 0


@rpc("any_peer", "call_remote", "reliable")
func _set_ready_at_host(value: bool) -> void:
	if is_host():
		_apply_ready(multiplayer.get_remote_sender_id(), value)


@rpc("any_peer", "call_remote", "reliable")
func _choose_hull_at_host(hull_id: StringName) -> void:
	if is_host():
		_apply_hull(multiplayer.get_remote_sender_id(), hull_id)


## Through the host, not peer to peer: one message shape, one direction, one place to fail.
## Why: docs/why/NetSession.md#presence-relay
@rpc("any_peer", "call_remote", "reliable")
func _report_presence_at_host(wire: Dictionary, at: int, jumps: int) -> void:
	if is_host():
		_apply_presence(multiplayer.get_remote_sender_id(), wire, at, jumps)


## Only a node index and option id travel: the seed already puts the same loot everywhere.
## Why: docs/why/NetSession.md#claims
@rpc("any_peer", "call_remote", "reliable")
func _claim_at_host(index: int, option: int) -> void:
	var who := _member_sender()
	if who != 0:
		_apply_claim(index, option, who)


@rpc("authority", "call_remote", "reliable")
func _push_claims_to(all: Dictionary) -> void:
	claims = all
	Sig.party_map_changed.emit()


## Open-or-join in one message: only the host can say who was first in a same-second race.
## `players`: the count the asker built its hull for; `join_only`: a JOIN door's ask, which opens nothing (PROTOCOL 18).
@rpc("any_peer", "call_remote", "reliable")
func _open_fight_at_host(index: int, ids: PackedStringArray, hp: PackedInt32Array,
		brace: PackedInt32Array, cur: PackedInt32Array, grown: int, players: int,
		join_only: bool) -> void:
	var by := _member_sender()
	if by == 0:
		return
	if hold_asks:
		_held_asks.append([index, ids, hp, brace, cur, grown, by, players, join_only])
		return
	_open_or_join(index, ids, hp, brace, cur, grown, by, players, join_only)


## The test seam's other half: answer every held ask now, in the order asked.
func release_asks() -> void:
	var held := _held_asks
	_held_asks = []
	for a: Array in held:
		_open_or_join(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8])


## A JOIN THAT CAME AFTER THE KILL (PROTOCOL 18): nothing is open at `index`
## to join, and the host opened nothing. Sent to the asker alone, after the
## fight that ended; its wait (`open_fight`) hands that fight back.
@rpc("authority", "call_remote", "reliable")
func _no_fight_to(index: int) -> void:
	_no_fight_at = index


@rpc("any_peer", "call_remote", "reliable")
func _hurt_at_host(index: int, which: int, amount: int, hits: int) -> void:
	var who := _member_sender()
	if who != 0:
		_apply_hurt(index, which, amount, hits, who)


@rpc("any_peer", "call_remote", "reliable")
func _end_turn_at_host(index: int) -> void:
	var who := _member_sender()
	if who != 0:
		_apply_end_turn(index, who)


@rpc("any_peer", "call_remote", "reliable")
func _leave_fight_at_host(index: int) -> void:
	var who := _member_sender()
	if who != 0:
		_apply_leave(index, who)


## One fight per push: fights change several times a turn, claims a few times an hour.
@rpc("authority", "call_remote", "reliable")
func _push_fight_to(wire: Dictionary) -> void:
	var f := SharedFight.from_wire(wire)
	if f.at < 0:
		return
	fights[f.at] = f
	Sig.party_fight_changed.emit(f.at)


## Pushed whole so a dropped push costs one update; `feeding` stops flee hops from feeding.
@rpc("authority", "call_remote", "reliable")
func _push_hellbender_to(to: int, hp: int, moves: int, feeding: bool) -> void:
	Run.hellbender_adopt(to, hp, moves, feeding)


## Adopted only in a dive and never lower; `quiet` hides arrivals for jumps a joiner never saw.
## Why: docs/why/NetSession.md#lead-ship-jumps
@rpc("authority", "call_remote", "reliable")
func _push_growth_to(g: int, quiet: bool) -> void:
	if state != State.DIVING:
		return
	g = clampi(g, 0, SharedFight.MAX_GROWN)
	galaxy_jumps = maxi(galaxy_jumps, g)
	if not _on_dive_galaxy():
		return
	Run.party_jumps = maxi(Run.party_jumps, g)
	if quiet:
		Run.custodian_seen = Run.custodian_jumps()


## Sent to one peer only; the intent is an index into lists every machine built identically.
@rpc("authority", "call_remote", "reliable")
func _enemy_swings(at: int, which: int, kind: int, pick: int) -> void:
	# Still asking to be seated there: nothing is listening yet, so it is held
	# for the Combat to play as it begins (`take_held_swings`).
	if at == _asking_at:
		_held_swings.append([at, which, kind, pick])
		return
	Sig.party_fight_swing.emit(at, which, kind, pick)


## THE HITS THAT LANDED WHILE THIS SHIP WAS ASKING TO JOIN THE FIGHT AT `at`,
## as `[at, which, kind, pick]` rows, in order; taken once. `Combat.begin`
## plays them before it decides between a hand and the stun.
func take_held_swings(at: int) -> Array:
	var out: Array = []
	var kept: Array = []
	for row: Array in _held_swings:
		if int(row[0]) == at:
			out.append(row)
		else:
			kept.append(row)
	_held_swings = kept
	return out


## Unreliable: the next one replaces a lost one, and a stale queued one is worse than none.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _spot_at_host(at: int, body: int, x: float, z: float, ang: float, mt: float, host: int, held: bool) -> void:
	var who := _member_sender()
	if who != 0:
		_apply_spot(who, at, body, x, z, ang, mt, host, held)


@rpc("authority", "call_remote", "unreliable_ordered")
func _spot_to(id: int, at: int, body: int, x: float, z: float, ang: float, mt: float, host: int, held: bool) -> void:
	if id != local_id():
		spots[id] = _spot_row(at, body, x, z, ang, mt, host, held)


## Reliable twin for a changed `held`: a lost put-away ran every partner's clock on.
@rpc("any_peer", "call_remote", "reliable")
func _spot_at_host_sure(at: int, body: int, x: float, z: float, ang: float, mt: float, host: int, held: bool) -> void:
	var who := _member_sender()
	if who != 0:
		_apply_spot(who, at, body, x, z, ang, mt, host, held, true)


@rpc("authority", "call_remote", "reliable")
func _spot_to_sure(id: int, at: int, body: int, x: float, z: float, ang: float, mt: float, host: int, held: bool) -> void:
	if id != local_id():
		spots[id] = _spot_row(at, body, x, z, ang, mt, host, held)


@rpc("authority", "call_remote", "reliable")
func _begin_dive(seed_value: int, unlocked: Array) -> void:
	_apply_dive(seed_value, unlocked)


# --- plumbing -------------------------------------------------------------

## Both connect signals are wired, as a custom peer may emit one; a flag stops a double hello.
## Why: docs/why/NetSession.md#hello-handshake
func _on_connected() -> void:
	_say_hello()


func _say_hello() -> void:
	if is_host() or _said_hello:
		return
	_said_hello = true
	var speak := forced_protocol if forced_protocol != 0 else PROTOCOL
	_hello.rpc_id(1, speak, _content_hash, _local_name, _local_hull, local_build())


func _on_connect_failed() -> void:
	_drop(_why("Could not connect. The host may be offline, or the port closed."))


func _on_host_lost() -> void:
	_drop(_why("The host left."))


## A peer cannot carry a sentence, so the transport keeps the real reason and this asks for it.
## Why: docs/why/NetSession.md#transport-reasons
func _why(fallback: String) -> String:
	var said := transport.last_error() if transport != null else ""
	return said if not said.is_empty() else fallback


func _on_peer_connected(id: int) -> void:
	# On a client, the host appearing is the other way of learning we are in.
	# On the host this is a joiner, and the host never speaks first: see _hello.
	if id == 1:
		_say_hello()


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	# Leave every fight first: a dropped player in a crew list blocks the others' turn for good.
	for index in fights.keys():
		var f: SharedFight = fights[index]
		if f.crew.has(id):
			_apply_leave(int(index), id)
	spots.erase(id)
	flights.erase(id)
	_jumps_said.erase(id)
	if roster.erase(id):
		_builds.erase(id)
		_push_roster()
		Sig.party_changed.emit()


func _apply_ready(id: int, value: bool) -> void:
	if not roster.has(id):
		return
	roster[id].ready = value
	_push_roster()
	Sig.party_changed.emit()


## Something about your ship moved. The send itself waits for the frame — see
## _process.
func _mark_presence() -> void:
	if is_networked():
		_presence_dirty = true


## HOSTING counts, JOINING does not: an RPC through a connecting peer is logged as an error.
func _can_talk() -> bool:
	return state == State.HOSTING or state == State.IN_PARTY or state == State.DIVING


func _send_presence() -> void:
	var b := ShipBuild.local()
	# No ship yet. The lobby runs before any run exists, and a party formed
	# there has four names and no hulls until everybody has picked one.
	if b.hull == null:
		return
	b.pilot = _local_name
	var wire := b.to_wire()
	var at := Run.at if not Run.map.is_empty() else -1
	var jumps := _my_jumps()
	var stamp := hash([wire, at, jumps])
	if stamp == _presence_sent:
		return
	_presence_sent = stamp
	if is_host():
		_apply_presence(1, wire, at, jumps)
	else:
		_report_presence_at_host.rpc_id(1, wire, at, jumps)


## Only in a dive on the dive's own galaxy: a stale or NEW RUN ship must not raise the count.
func _my_jumps() -> int:
	return Run.jumps if _on_dive_galaxy() else -1


## Guards both what a presence says and what the run takes from the lead ship's count.
func _on_dive_galaxy() -> bool:
	return state == State.DIVING and dive_seed != 0 and Run.galaxy_seed == dive_seed \
		and not Run.map.is_empty()


func _apply_presence(id: int, wire: Dictionary, at: int, jumps: int = -1) -> void:
	if not roster.has(id) or not _is_place(at, true):
		return
	# A moved `at` is a jump for others only: the host's own jumps tick in `RunState.jump_to()`.
	var was := int(roster[id].get("at", -1))
	var said := int(_jumps_said.get(id, -1))
	roster[id].build = wire
	roster[id].at = at
	# (in the dive, a presence with no jumps to say is a ship off this galaxy:
	# not one of the players the fights are built for, `party_count`)
	roster[id].away = state == State.DIVING and jumps < 0
	_jumps_said[id] = jumps
	# Both presences must be from this dive's galaxy, so a first or late presence is no jump.
	if is_host() and id != 1 and state == State.DIVING \
			and was >= 0 and at >= 0 and at != was and said >= 0 and jumps >= 0:
		Run.hellbender_jumped()
	# Every guest presence, its first too: the lead ship's count is a max, and
	# a ship behind the lead adds nothing
	if id != 1:
		_fold_growth(jumps)
	_push_roster()
	Sig.party_changed.emit()


## Host folds one ship's jumps into the lead count: higher wins, pushed whole, never lower.
func _fold_growth(n: int) -> void:
	if not is_host() or state != State.DIVING or n < 0:
		return
	n = clampi(n, 0, SharedFight.MAX_GROWN)
	if n <= galaxy_jumps:
		return
	galaxy_jumps = n
	if _on_dive_galaxy():
		Run.party_jumps = maxi(Run.party_jumps, n)
	push_growth()
	for f: SharedFight in fights.values():
		if _regrow(f):
			_push_fight(f)


## Broadcast the lead ship's count, host only; built like `push_hellbender`.
func push_growth() -> void:
	if not is_host() or not _can_talk():
		return
	if not multiplayer.get_peers().is_empty():
		_push_growth_to.rpc(galaxy_jumps, false)


## Static so `-- sheet=CoreWinTest` can grow a fight with no session.
static func growth_ratios(f: SharedFight, to: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in f.foes.size():
		var t: EnemyTemplate = DB.enemies.get(StringName(f.foe_ids[i])) if i < f.foe_ids.size() else null
		if t == null or t.grow_after < 0 or f.grown < 0:
			out.append(0.0)
			continue
		out.append(float(t.hull_at(to)) / float(maxi(1, t.hull_at(f.grown))))
	return out


## A fight grown at less than the lead count grows now: the hull bar rises, damage stays done.
## Why: docs/why/NetSession.md#lead-ship-jumps
func _regrow(f: SharedFight) -> bool:
	if f == null or f.over or f.grown < 0 or f.grown >= galaxy_jumps:
		return false
	return f.regrow(galaxy_jumps, growth_ratios(f, galaxy_jumps))


## Coarse on position, exact on everything a player can act on.
static func galaxy_print(map: Array, galaxy_name: String) -> int:
	var parts := PackedStringArray([galaxy_name, str(map.size())])
	for raw in map:
		var n: MapGen.MapNode = raw
		var links := PackedStringArray()
		for l in n.links:
			links.append(str(l))
		parts.append("%d:%d:%d:%d:%d:%d:%d%d%d%d:%d,%d:%s" % [n.index, int(n.type), n.layer,
			n.danger, int(n.region), int(n.star), int(n.gas_giant), int(n.near_pulsar),
			int(n.twin), int(n.in_nebula), roundi(n.gal.x * 10.0), roundi(n.gal.y * 10.0), "-".join(links)])
	return hash("|".join(parts))


func _on_run_started() -> void:
	if state != State.DIVING or dive_seed == 0 or Rng.master != dive_seed:
		return
	# A run started on the dive's galaxy keeps the lead count, as a later new run clears it.
	if galaxy_jumps > 0:
		Run.party_jumps = maxi(Run.party_jumps, galaxy_jumps)
		Run.custodian_seen = maxi(Run.custodian_seen, Run.custodian_jumps())
	var fp := forced_galaxy if forced_galaxy != 0 else galaxy_print(Run.map, Run.galaxy_name)
	report_galaxy(dive_seed, Run.map.size(), fp)


## This machine built galaxy `fp` (`systems` of them) from `seed_value`. The
## host keeps its own and compares; a guest sends it to the host.
func report_galaxy(seed_value: int, systems: int, fp: int) -> void:
	galaxy_mine = [seed_value, systems, fp]
	print("[party] galaxy seed %d: %d systems, fingerprint %d (%s, build %s)" % [
		seed_value, systems, fp, OS.get_name(), local_build()])
	if not _can_talk():
		return
	if is_host():
		_check_galaxies()
	else:
		_galaxy_at_host.rpc_id(1, seed_value, systems, fp)


@rpc("any_peer", "call_remote", "reliable")
func _galaxy_at_host(seed_value: int, systems: int, fp: int) -> void:
	var who := _member_sender()
	if who == 0:
		return
	_galaxy_theirs[who] = [seed_value, systems, fp]
	print("[party] %s built galaxy seed %d: %d systems, fingerprint %d" % [
		name_of(who), seed_value, systems, fp])
	_check_galaxies()


## Host only: every guest's galaxy against this one's, once both are known.
func _check_galaxies() -> void:
	if galaxy_mine.size() != 3:
		return
	for id in _galaxy_theirs.keys():
		var g: Array = _galaxy_theirs[id]
		if int(g[0]) != int(galaxy_mine[0]):
			continue
		_galaxy_theirs.erase(id)
		if int(g[1]) == int(galaxy_mine[1]) and int(g[2]) == int(galaxy_mine[2]):
			print("[party] %s's galaxy matches this one" % name_of(id))
			continue
		var args := [name_of(id), int(galaxy_mine[0]), int(galaxy_mine[1]), int(galaxy_mine[2]),
			int(g[1]), int(g[2])]
		if multiplayer.get_peers().has(int(id)):
			_galaxy_differs.rpc(args[0], args[1], args[2], args[3], args[4], args[5])
		_galaxy_differs_here(args[0], args[1], args[2], args[3], args[4], args[5])


@rpc("authority", "call_remote", "reliable")
func _galaxy_differs(guest: String, seed_value: int, host_n: int, host_fp: int,
		guest_n: int, guest_fp: int) -> void:
	_galaxy_differs_here(guest, seed_value, host_n, host_fp, guest_n, guest_fp)


func _galaxy_differs_here(guest: String, seed_value: int, host_n: int, host_fp: int,
		guest_n: int, guest_fp: int) -> void:
	# The log line is the diagnosis: both fingerprints, both counts, the seed.
	push_warning("[party] GALAXY MISMATCH seed %d: host %s has %d systems, fingerprint %d; %s has %d systems, fingerprint %d (this machine: %s, build %s)" % [
		seed_value, name_of(1), host_n, host_fp, guest, guest_n, guest_fp, OS.get_name(), local_build()])
	galaxy_warning = "Your galaxies do not match (%s's and the host's). Places will not line up. Tell the developer and send godot.log." % guest
	Sig.party_notice.emit(galaxy_warning)


## Throttled here so the map can call it every frame; sent at once when place or sun changes.
## Why: docs/why/NetSession.md#spots
func report_spot(at: int, body: int, p: Vector2, ang: float, force: bool = false, mt: float = 0.0, host: int = -9, held: bool = false) -> void:
	if not _can_talk() or state != State.DIVING:
		return
	var now := Time.get_ticks_msec()
	var same_place := _spot_sent.size() == 7 and int(_spot_sent[0]) == at and int(_spot_sent[1]) == body \
		and int(_spot_sent[5]) == host and bool(_spot_sent[6]) == held
	if same_place and not force:
		if now - _spot_ms < SPOT_EVERY_MS:
			return
		if Vector2(_spot_sent[2], _spot_sent[3]).distance_to(p) < 0.5 \
				and absf(angle_difference(float(_spot_sent[4]), ang)) < 0.05 and now - _spot_ms < SPOT_BEAT_MS:
			return
	# (the clock stopping or starting goes reliably: `_spot_at_host_sure`)
	var sure := _spot_sent.size() != 7 or bool(_spot_sent[6]) != held
	_spot_sent = [at, body, p.x, p.y, ang, host, held]
	_spot_ms = now
	if is_host():
		_apply_spot(1, at, body, p.x, p.y, ang, mt, host, held, sure)
	elif sure:
		_spot_at_host_sure.rpc_id(1, at, body, p.x, p.y, ang, mt, host, held)
	else:
		_spot_at_host.rpc_id(1, at, body, p.x, p.y, ang, mt, host, held)


## An arrival says no map clock (-1): a 0 was taken for one and run on.
func report_arrival(at: int) -> void:
	report_spot(at, -10, Vector2.ZERO, 0.0, true, -1.0)


## Where a partner is inside the system `at`, or {} if this machine does not
## know (never reported, or the report is about another system).
func spot_of(id: int, at: int) -> Dictionary:
	var sp: Dictionary = spots.get(id, {})
	if sp.is_empty() or int(sp.get("at", -1)) != at:
		return {}
	return sp


## A flight leaving (PROTOCOL 17), said once as it starts, reliably: its path about 60 points a second,
## burns, ends and clocks. `to` -9 lets go of the last one said. `shape` is [host, dep_s, arr_s].
## Why: docs/why/NetSession.md#report-flight
func report_flight(at: int, key: int, from: int, to: int, t0: float, dt: float, pts: PackedVector2Array, burns: PackedByteArray, said: float, shape := PackedFloat64Array()) -> void:
	if not _can_talk() or state != State.DIVING:
		return
	if key == _flight_said:
		return
	_flight_said = key
	if is_host():
		_own_flight = {} if to == -9 or pts.size() < 2 else _flight_row(at, from, to, t0, dt, pts, burns, said, shape)
		_apply_flight(1, at, from, to, t0, dt, pts, burns, said, shape)
	else:
		_flight_at_host.rpc_id(1, at, from, to, t0, dt, pts, burns, said, shape)


## THE FLIGHT LET GO OF (W off it, or another place clicked on the way): the
## partners draw the ship by its spots again.
func report_flight_off(at: int) -> void:
	if _flight_said == 0:
		return
	_flight_said = 0
	report_flight(at, -1, -9, -9, 0.0, 0.0, PackedVector2Array(), PackedByteArray(), 0.0)
	_flight_said = 0


@rpc("any_peer", "call_remote", "reliable")
func _flight_at_host(at: int, from: int, to: int, t0: float, dt: float, pts: PackedVector2Array, burns: PackedByteArray, said: float, shape: PackedFloat64Array) -> void:
	var who := _member_sender()
	if who != 0 and pts.size() <= FLIGHT_POINTS_MAX and burns.size() <= FLIGHT_POINTS_MAX:
		_apply_flight(who, at, from, to, t0, dt, pts, burns, said, shape)


@rpc("authority", "call_remote", "reliable")
func _flight_to(id: int, at: int, from: int, to: int, t0: float, dt: float, pts: PackedVector2Array, burns: PackedByteArray, said: float, shape: PackedFloat64Array) -> void:
	if id != local_id():
		_keep_flight(id, at, from, to, t0, dt, pts, burns, said, shape)


func _apply_flight(id: int, at: int, from: int, to: int, t0: float, dt: float, pts: PackedVector2Array, burns: PackedByteArray, said: float, shape := PackedFloat64Array()) -> void:
	if id != 1:
		_keep_flight(id, at, from, to, t0, dt, pts, burns, said, shape)
	if not multiplayer.get_peers().is_empty():
		_flight_to.rpc(id, at, from, to, t0, dt, pts, burns, said, shape)


## A KEPT FLIGHT TOLD AGAIN, to ship `who` (one joining while it flies), the
## sender's clock run on from `said` by the time since it came.
func _tell_flight(who: int, id: int, fl: Dictionary, now_ms: int) -> void:
	var said := float(fl.said) + float(now_ms - int(fl.got)) / 1000.0
	var shape := PackedFloat64Array([float(fl.get("host", -9)), float(fl.get("dep_s", 0.0)), float(fl.get("arr_s", -1.0))])
	_flight_to.rpc_id(who, id, int(fl.at), int(fl.from), int(fl.to), float(fl.t0), float(fl.dt), fl.pts, fl.burns, said, shape)


static func _flight_row(at: int, from: int, to: int, t0: float, dt: float, pts: PackedVector2Array, burns: PackedByteArray, said: float, shape: PackedFloat64Array) -> Dictionary:
	var dur := float(dt) * float(maxi(pts.size() - 1, 0))
	return {"at": at, "from": from, "to": to, "t0": t0, "dt": dt, "pts": pts, "burns": burns, "said": said,
		"got": Time.get_ticks_msec(), "host": int(shape[0]) if shape.size() > 0 else -9,
		"dep_s": shape[1] if shape.size() > 1 else 0.0, "arr_s": shape[2] if shape.size() > 2 and shape[2] >= 0.0 else dur}


func _keep_flight(id: int, at: int, from: int, to: int, t0: float, dt: float, pts: PackedVector2Array, burns: PackedByteArray, said: float, shape := PackedFloat64Array()) -> void:
	if to == -9 or pts.size() < 2:
		flights.erase(id)
		return
	flights[id] = _flight_row(at, from, to, t0, dt, pts, burns, said, shape)


## The sender's map clock now for flight fl: run on from when it was said, held where its spot says
## the clock holds, so a partner is not flown on by the wall clock while the sender stands still.
## Why: docs/why/NetSession.md#sender-clock
static func sender_clock(fl: Dictionary, sp: Dictionary, now_ms: int) -> float:
	var est := float(fl.said) + float(now_ms - int(fl.got)) / 1000.0
	if sp.is_empty() or float(sp.get("t", -1.0)) < 0.0 or int(sp.get("got", -1)) < int(fl.got):
		return est
	if bool(sp.get("held", false)):
		return float(sp.t)
	var est2 := float(sp.t) + float(now_ms - int(sp.got)) / 1000.0
	return est2 if absf(est2 - est) > 0.25 else est


## A partner's flight in system `at` still to be drawn, or {}: one whose last
## point has gone by on the sender's clock (`sender_clock`) is over, and the
## spots have it again.
func flight_of(id: int, at: int) -> Dictionary:
	var fl: Dictionary = flights.get(id, {})
	if fl.is_empty() or int(fl.at) != at:
		return {}
	var now_s := sender_clock(fl, spot_of(id, at), Time.get_ticks_msec())
	if now_s > float(fl.t0) + float(fl.dt) * float((fl.pts as PackedVector2Array).size() - 1) + 0.05:
		return {}
	return fl


## Where a partner's flight has it now (PROTOCOL 17) at this machine's clock t, each end moved with
## its place. [point, screen angle, burning], or [] when it is not flying now.
## Why: docs/why/NetSession.md#flight-point
static func flight_point(fl: Dictionary, L: SystemLayout, t: float, now_ms: int, sp: Dictionary = {}) -> Array:
	var pts: PackedVector2Array = fl.pts
	var n := pts.size()
	if n < 2:
		return []
	var sender_now := sender_clock(fl, sp, now_ms)
	var dur := float(fl.dt) * float(n - 1)
	var s := sender_now - float(fl.t0)
	if s < 0.0 or s > dur:
		return []
	var x := s / float(fl.dt)
	var j := mini(int(floor(x)), n - 2)
	var q := pts[j].lerp(pts[j + 1], x - float(j))
	var dlt := t - sender_now
	var sa := clampf(float(fl.get("dep_s", 0.0)), 0.0, dur)
	var sb := clampf(float(fl.get("arr_s", dur)), sa, dur)
	var hs := int(fl.get("host", -9))
	# (each end's place moved by the clocks' difference, at this point's moment)
	var d0 := spot_anchor(L, int(fl.from), hs, sender_now + dlt) - spot_anchor(L, int(fl.from), hs, sender_now)
	var d1 := spot_anchor(L, int(fl.to), -9, sender_now + dlt) - spot_anchor(L, int(fl.to), -9, sender_now)
	var u := smoothstep(sa, maxf(sb, sa + 1e-6), s)
	q += d0.lerp(d1, u)
	var v := pts[j + 1] - pts[j]
	var ang := atan2(v.y * 0.38, v.x)
	var burns: PackedByteArray = fl.burns
	var lit := j < burns.size() and burns[j] == 1
	return [q, ang, lit]


func _apply_spot(id: int, at: int, body: int, x: float, z: float, ang: float, mt: float, host: int, held: bool = false, sure: bool = false) -> void:
	# A non-finite float reaches `party_t` and from there the map clock.
	if not (is_finite(x) and is_finite(z) and is_finite(ang) and is_finite(mt)):
		return
	mt = minf(mt, MAP_CLOCK_MAX)
	if id != 1:
		spots[id] = _spot_row(at, body, x, z, ang, mt, host, held)
	if not multiplayer.get_peers().is_empty():
		if sure:
			_spot_to_sure.rpc(id, at, body, x, z, ang, mt, host, held)
		else:
			_spot_to.rpc(id, at, body, x, z, ang, mt, host, held)


## A spot as `spots` keeps it, stamped with when it came.
static func _spot_row(at: int, body: int, x: float, z: float, ang: float, mt: float, host: int, held: bool = false) -> Dictionary:
	return {"at": at, "body": body, "x": x, "z": z, "ang": ang, "t": mt, "host": host, "held": held, "got": Time.get_ticks_msec()}


## The sender takes a spot off its own clock and receivers add it back at theirs.
## Why: docs/why/NetSession.md#party-map-clock
static func spot_anchor(L: SystemLayout, body: int, host: int, t: float) -> Vector2:
	if L == null:
		return Vector2.ZERO
	if body >= 0:
		return L.bodies[body].pos(t) if body < L.bodies.size() else Vector2.ZERO
	var s := body if SystemLayout.is_star(body) else (host if body == -9 else -9)
	if SystemLayout.is_star(s):
		return L.star_pos(s, t)
	return Vector2.ZERO


## Run on only while the sender's map is up, and only for partners in the party and system.
## Why: docs/why/NetSession.md#party-map-clock
func party_t(at: int) -> float:
	var best := -1.0
	var now := Time.get_ticks_msec()
	for id in spots:
		if not roster.has(int(id)) or where_is(int(id)) != at:
			continue
		var sp := spot_of(int(id), at)
		if sp.is_empty() or not sp.has("t") or float(sp.t) < 0.0 or int(sp.get("body", -9)) == -10:
			continue
		# A row nothing refreshes is run on at most `RUN_ON_MAX`, as a put-away word can be lost.
		var run_on := 0.0 if bool(sp.get("held", false)) else minf(float(now - int(sp.get("got", now))) / 1000.0, RUN_ON_MAX)
		best = maxf(best, float(sp.t) + run_on)
	return best


## Never goes back, and keeps its own when a free ship was put away coasting.
## Why: docs/why/NetSession.md#party-map-clock
static func clock_to_open(own: float, party: float, keep_own: bool) -> float:
	return party if party > own and not keep_own else own


## Within `CATCH_CUT` the map catches up; further behind it takes the party's clock in one cut.
## Why: docs/why/NetSession.md#party-map-clock
const CATCH_CUT := 20.0
func handed_clock(at: int) -> float:
	var own := Run.map_t(at)
	if is_networked() and party_t(at) - own > CATCH_CUT:
		return adopt_clock(at)
	return own


## Kept in `Run.map_clock` so the map and LOCAL put a parked ship in one place.
## Why: docs/why/NetSession.md#party-map-clock
func adopt_clock(at: int) -> float:
	var own := Run.map_t(at)
	if not is_networked():
		return own
	var d: Dictionary = SystemMapScreen._parked.get(at, {})
	var free := StringName(d.get("mode", &"")) == &"free"
	var t := clock_to_open(own, party_t(at), free and not d.has("cen"))
	if t != own:
		Run.map_clock[at] = t
		if not d.is_empty() and at >= 0 and at < Run.map.size():
			carry_parked(SystemLayout.of(Run.map[at]), d, own, t)
	return t


## Carries a parked ship with its sun or ring so the map and LOCAL agree where it is.
## Why: docs/why/NetSession.md#party-map-clock
static func carry_parked(L: SystemLayout, d: Dictionary, own: float, t: float) -> void:
	if L == null:
		return
	var mode := StringName(d.get("mode", &""))
	var at := int(d.get("at", -9))
	if mode == &"rail" and d.has("p") and SystemLayout.is_place(at) and at < L.bodies.size():
		var star := SystemLayout.is_star(at)
		if star and at == SystemLayout.STAR_B and not L.twin:
			at = -1
		var c0: Vector2 = L.star_pos(at, own) if star else L.bodies[at].pos(own)
		var c1: Vector2 = L.star_pos(at, t) if star else L.bodies[at].pos(t)
		d["p"] = (d.p as Vector2) + c1 - c0
		if d.has("v"):
			var v0: Vector2 = L.star_vel(at, own) if star else L.bodies[at].vel(own)
			var v1: Vector2 = L.star_vel(at, t) if star else L.bodies[at].vel(t)
			d["v"] = (d.v as Vector2) + v1 - v0
		return
	var cen := int(d.get("cen", -99))
	if not L.twin or not SystemLayout.is_star(cen) or mode != &"free":
		return
	d["p"] = (d.get("p", Vector2.ZERO) as Vector2) + L.star_pos(cen, t) - L.star_pos(cen, own)


## Host only; the guard lives here, like `claim()`'s, so no call site needs a branch.
func push_hellbender(feeding: bool) -> void:
	if not is_host() or not _can_talk():
		return
	if not multiplayer.get_peers().is_empty():
		_push_hellbender_to.rpc(Run.hellbender_at, Run.hellbender_hp, Run.hellbender_moves, feeding)


## For outcomes you cannot lose a race for. A no-op solo, so call sites need no branch.
## Why: docs/why/NetSession.md#claims
func claim(index: int, option: int = MapGen.OPTION_WHOLE) -> void:
	if not _can_talk() or index < 0:
		return
	if is_host():
		_apply_claim(index, option, 1)
	else:
		# The caller marked its own copy already; waiting for the host would flicker the chart.
		_claim_at_host.rpc_id(1, index, option)


## Ask, do not assume: two ships at one wreck would each roll loot. First message wins.
## Why: docs/why/NetSession.md#claims
func take(index: int, option: int = MapGen.OPTION_WHOLE) -> int:
	var me := local_id()
	if not _can_talk() or index < 0:
		return me
	var owner := who_took(index, option)
	if owner != 0:
		return owner
	if is_host():
		_apply_claim(index, option, 1)
		return who_took(index, option)
	_claim_at_host.rpc_id(1, index, option)
	# Waits on the roster push: an answer is already coming, and a second message is more to sync.
	var deadline := _now() + TAKE_TIMEOUT
	while _now() < deadline:
		await get_tree().process_frame
		owner = who_took(index, option)
		if owner != 0:
			return owner
	return 0


# --- fights ---------------------------------------------------------------

## Null means fight it alone. The host may seat a second asker in an existing fight.
## No private fight while the link is up: a private copy once left the party on WAIT.
## `join_only` (PROTOCOL 18): a JOIN door's ask opens nothing; past the kill it gets the ended fight.
## The hull is built for `party_count()`; the host scales it to its own count.
## Why: docs/why/NetSession.md#shared-fights
func open_fight(index: int, ids: PackedStringArray, hp: PackedInt32Array,
		brace: PackedInt32Array, cur: PackedInt32Array, grown: int = -1,
		join_only: bool = false) -> SharedFight:
	if not _can_talk() or index < 0 or party_size() < 2:
		return null
	if is_host():
		_open_or_join(index, ids, hp, brace, cur, grown, 1, party_count(), join_only)
		return fights.get(index, null)
	# Ask and wait like `take()`: an optimistic private frigate would get different numbers.
	_asking_at = index
	_held_swings.clear()
	_no_fight_at = -1
	_open_fight_at_host.rpc_id(1, index, ids, hp, brace, cur, grown, party_count(), join_only)
	var me := local_id()
	var out: SharedFight = null
	while _can_talk():
		await get_tree().process_frame
		var f: SharedFight = fights.get(index, null)
		if f != null and f.crew.has(me):
			out = f
			break
		# The host's "nothing open there" comes after the push it sent first,
		# so the copy here is the ended fight by now
		if _no_fight_at == index:
			out = f
			if out == null:
				out = SharedFight.new()
				out.at = index
				out.over = true
			break
	_asking_at = -1
	_no_fight_at = -1
	if out == null:
		_held_swings.clear()
	return out


## The fight at a system, shared or not, over or not. Callers check `over`.
func fight_at(index: int) -> SharedFight:
	return fights.get(index, null)


## Whether arriving here means joining something rather than starting it.
func fight_open_at(index: int) -> bool:
	var f: SharedFight = fights.get(index, null)
	return f != null and not f.over


## Zero when flying alone, so it can salt solo streams; fixed by the host, unlike peer ids.
## Why: docs/why/NetSession.md#seat-order
func seat() -> int:
	var me := local_id()
	return int(roster[me].get("order", 0)) if roster.has(me) else 0


## One player's name, or "" if the party has never heard of them.
func name_of(id: int) -> String:
	return String(roster[id].get("name", "")) if roster.has(id) else ""


## Everyone else in the fight, by name, for a line the player can read.
func fight_crew_names(index: int) -> PackedStringArray:
	var out := PackedStringArray()
	var f: SharedFight = fights.get(index, null)
	if f == null:
		return out
	var me := local_id()
	for p in f.crew:
		if p != me and roster.has(p):
			out.append(String(roster[p].get("name", "")))
	return out


## Your shot. Fire and forget — you have already drawn the number locally, and
## the host's push is what corrects it. See SharedFight.hurt().
func hurt_foe(index: int, which: int, amount: int, hits: int) -> void:
	if not _can_talk():
		return
	if is_host():
		_apply_hurt(index, which, amount, hits, 1)
	else:
		_hurt_at_host.rpc_id(1, index, which, amount, hits)


## You pressed END TURN. The enemy acts when the last ship does.
func report_end_turn(index: int) -> void:
	if not _can_talk():
		return
	if is_host():
		_apply_end_turn(index, 1)
	else:
		_end_turn_at_host.rpc_id(1, index)


## A guest stops counting itself at once, or a leave-and-return would rejoin the fight it left.
## Why: docs/why/NetSession.md#shared-fights
func leave_fight(index: int) -> void:
	if not _can_talk():
		return
	if is_host():
		_apply_leave(index, 1)
	else:
		var f: SharedFight = fights.get(index, null)
		if f != null:
			f.leave(local_id())
		_leave_fight_at_host.rpc_id(1, index)


## Who owns one option here, or 0 if nobody does.
func who_took(index: int, option: int = MapGen.OPTION_WHOLE) -> int:
	var here: Dictionary = claims.get(index, {})
	return int(here.get(option, 0))


## Everything used up at one system, as `{option id: peer id}`.
func taken_at(index: int) -> Dictionary:
	return claims.get(index, {})


## The name of whoever took it, for a screen to print. Empty when nobody has.
func taker_name(index: int, option: int = MapGen.OPTION_WHOLE) -> String:
	var who := who_took(index, option)
	if who == 0 or who == local_id() or not roster.has(who):
		return ""
	return String(roster[who].get("name", ""))


## Whether `index` names a system of the dive's galaxy. Before this machine has built it there is
## nothing to check against, so only a negative index fails. `none` also allows -1, no place yet.
func _is_place(index: int, none: bool = false) -> bool:
	if none and index == -1:
		return true
	return index >= 0 and (not _on_dive_galaxy() or index < Run.map.size())


func _apply_claim(index: int, option: int, by: int) -> void:
	if not _is_place(index) or option < 0 or option > OPTION_MAX:
		return
	var here: Dictionary = claims.get(index, {})
	# First message wins. Every later one is a no-op, which is the whole of the
	# race resolution — there is nothing to compare and no clock to trust.
	if here.has(option) or here.size() >= CLAIMS_PER_NODE:
		return
	here[option] = by
	claims[index] = here
	_push_claims()
	Sig.party_map_changed.emit()


func _push_claims() -> void:
	if not is_host() or multiplayer.get_peers().is_empty():
		return
	_push_claims_to.rpc(claims)


# --- fights, on the host --------------------------------------------------

func _fight_ask_ok(ids: PackedStringArray, hp: PackedInt32Array, brace: PackedInt32Array,
		cur: PackedInt32Array) -> bool:
	var n := ids.size()
	if n < 1 or n > FIGHT_FOES_MAX or hp.size() != n or brace.size() > n or cur.size() > n:
		return false
	for id in ids:
		if not DB.enemies.has(StringName(id)):
			return false
	for list in [hp, brace, cur]:
		for v: int in list:
			if v < 0 or v > FOE_STAT_MAX:
				return false
	return true


func _open_or_join(index: int, ids: PackedStringArray, hp: PackedInt32Array,
		brace: PackedInt32Array, cur: PackedInt32Array, grown: int, by: int,
		players: int = 1, join_only: bool = false) -> void:
	# A peer's ask is not trusted: a bad one is dropped, as a real `Combat.plan` is never out of range.
	# A join opens nothing, so its foes are never read.
	if not _is_place(index) or not (join_only or _fight_ask_ok(ids, hp, brace, cur)):
		return
	var f: SharedFight = fights.get(index, null)
	if f != null and not f.over:
		# A second ship in is help, not a second frigate (stunned past turn one): its `grown`, hp and ids are ignored.
		# Why: docs/why/NetSession.md#shared-fights
		f.join(by)
	elif join_only and f != null:
		# A JOIN THAT CAME AFTER THE KILL (PROTOCOL 18): it opens nothing, as
		# a JOIN door never opens a fight. The asker is sent the fight that
		# ended, then told. (The host's own JOIN reads its copy at once.)
		if by != 1:
			_push_fight_to.rpc_id(by, f.to_wire())
			_no_fight_to.rpc_id(by, index)
		return
	else:
		# BUILT FOR THE GAME'S PLAYERS AS THE HOST COUNTS THEM (PROTOCOL 18).
		# The asker built its hull for the count it had heard; a roster push
		# still on its way to it is the only way the two differ.
		var mine := party_count()
		players = clampi(players, 1, MAX_PLAYERS)
		if players != mine:
			var k := PartyScale.hull(mine) / PartyScale.hull(players)
			hp = _scaled(hp, k)
			cur = _scaled(cur, k)
		f = SharedFight.open(index, ids, hp, brace, cur, by, grown, mine)
		fights[index] = f
		# Fold the opener's count first, then grow a fight grown at less before anyone sees it.
		_fold_growth(grown)
		_regrow(f)
		for i in f.foes.size():
			_pick_intent(f, i)
	_push_fight(f)


static func _scaled(v: PackedInt32Array, k: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	for x in v:
		out.append(maxi(1, int(round(x * k))))
	return out


func _apply_hurt(index: int, which: int, amount: int, hits: int, by: int) -> void:
	var f: SharedFight = fights.get(index, null)
	if f == null or f.over or not f.crew.has(by):
		return
	f.hurt(which, amount, hits, by)
	# The kill must reach the host's map even if the host was not in the fight. Idempotent.
	if f.over and f.paid > 0 and _is_hellbender_fight(f):
		Run.hellbender_defeated()
	_push_fight(f)


func _apply_end_turn(index: int, by: int) -> void:
	var f: SharedFight = fights.get(index, null)
	if f == null or f.over:
		return
	if not f.end_turn(by):
		# Not everybody yet. Pushed anyway so the others can see who is still
		# out — a button that says WAITING with no name on it is a hang.
		_push_fight(f)
		return
	_swing(f)


func _apply_leave(index: int, by: int) -> void:
	var f: SharedFight = fights.get(index, null)
	if f == null:
		return
	var was_over := f.over
	f.leave(by)
	# `paid == 0` says nobody killed it: `leave()` sets `over`, and a won fight empties its crew.
	if f.over and not was_over and f.paid == 0 and not f.broke \
			and _is_hellbender_fight(f) and not f.foes.is_empty():
		# in one ship's terms, whoever fought it (`PartyScale.solo_hull`)
		Run.hellbender_scarred(PartyScale.solo_hull(f.foes[0].hp, f.party))
	# Somebody leaving can be the thing that closes the barrier — three ships
	# waiting on a fourth who just died is a fight that would otherwise stop. Not mid-swing:
	# the host's own death leaves from inside it, and that swing closes the barrier itself.
	if not _swinging and not f.over and not f.crew.is_empty() and f.waiting_on().is_empty():
		_swing(f)
		return
	_push_fight(f)


## Each hull swings at one ship, resolved on the victim's machine against its own `Run`.
## Why: docs/why/NetSession.md#enemy-turn
func _swing(f: SharedFight) -> void:
	# The escape burn resolves instead of a turn, and only the host may decide it.
	for i in f.alive():
		var e0 := f.foes[i]
		if e0.kind == SharedFight.Pick.ESCAPE:
			f.broke = true
			f.over = true
			Run.hellbender_breaks_off(PartyScale.solo_hull(e0.hp, f.party))
			_push_fight(f)
			return
	_swinging = true
	for i in f.alive():
		var target := _who_gets_hit(f)
		if target == 0:
			break
		var e := f.foes[i]
		_foe_acts(f, i)
		if target == 1:
			Sig.party_fight_swing.emit(f.at, i, e.kind, e.pick)
		elif multiplayer.get_peers().has(target):
			_enemy_swings.rpc_id(target, f.at, i, e.kind, e.pick)
		# A target no longer connected gets no message, or Godot logs an RPC error (Nov 5 gate).
	_swinging = false
	f.advance()
	for i in f.foes.size():
		_pick_intent(f, i)
	# The turn number IS the "everybody go again" message. A separate one would
	# be a second thing to keep in step with the first.
	_push_fight(f)


## The enemy's own half of an intent, which only the host may keep: last turn's block expires as it
## acts again, then the intent's block and heal land, scaled as `Combat._spawn` scaled them.
## Why: docs/why/NetSession.md#foe-block-and-heal
func _foe_acts(f: SharedFight, i: int) -> void:
	var e := f.foes[i]
	e.block = 0
	if i >= f.foe_ids.size() or e.kind == SharedFight.Pick.ESCAPE:
		return
	var t: EnemyTemplate = DB.enemies.get(StringName(f.foe_ids[i]))
	if t == null:
		return
	var danger: int = Run.map[f.at].danger if f.at >= 0 and f.at < Run.map.size() else 1
	var scaled := Combat.scaled_for(t, danger)
	var list: Array[IntentData] = scaled.pool if e.kind == SharedFight.Pick.POOL else scaled.loop
	if e.pick < 0 or e.pick >= list.size():
		return
	e.block += list[e.pick].block
	e.hp = mini(e.max_hp, e.hp + list[e.pick].heal)


## Weighted by heat with a floor, so a cold ship is never safe and a party cannot elect a victim.
## A stunned ship is in the pool: it can be shot (Jon, Nov 5).
## Why: docs/why/NetSession.md#target-weighting
func _who_gets_hit(f: SharedFight) -> int:
	if forced_target != 0 and f.crew.has(forced_target):
		return forced_target
	var pool: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	var total := 0.0
	for p in f.crew:
		var b := build_of(p)
		if b != null and b.dead:
			continue
		var w := 0.5 + (b.heat_ratio() if b != null else 0.0)
		pool.append(p)
		weights.append(w)
		total += w
	if pool.is_empty():
		return 0
	var roll := Rng.fight.randf() * total
	var acc := 0.0
	for i in pool.size():
		acc += weights[i]
		if roll < acc:
			return pool[i]
	return pool[pool.size() - 1]


## Whether this fight's lead is the roaming set piece — the thing whose map
## state the host has to keep honest when the fight ends any way at all.
func _is_hellbender_fight(f: SharedFight) -> bool:
	if f.foe_ids.is_empty():
		return false
	var t: EnemyTemplate = DB.enemies.get(StringName(f.foe_ids[0]))
	return t != null and t.miniboss


## Host only: `pick_intent` draws from an ordered `Rng.fight` stream, so machines would disagree.
func _pick_intent(f: SharedFight, i: int) -> void:
	if i >= f.foe_ids.size() or i >= f.foes.size():
		return
	var t: EnemyTemplate = DB.enemies.get(StringName(f.foe_ids[i]))
	if t == null:
		return
	var e := f.foes[i]
	# Same rule as the solo `EnemyState.pick_intent()`, using the crew-grown max.
	if t.miniboss and e.hp > 0 \
			and e.hp <= int(ceil(e.max_hp * Combat.MINIBOSS_BREAKS_AT)):
		e.kind = SharedFight.Pick.ESCAPE
		e.pick = 0
		return
	if not t.pool.is_empty():
		var total := 0
		for it in t.pool:
			total += it.weight
		var roll := Rng.fight.randi() % maxi(1, total)
		var acc := 0
		e.kind = SharedFight.Pick.POOL
		e.pick = 0
		for k in t.pool.size():
			acc += t.pool[k].weight
			if roll < acc:
				e.pick = k
				return
	elif not t.loop.is_empty():
		e.kind = SharedFight.Pick.LOOP
		e.pick = e.step % t.loop.size()
		e.step += 1


func _push_fight(f: SharedFight) -> void:
	if not is_host():
		return
	if not multiplayer.get_peers().is_empty():
		_push_fight_to.rpc(f.to_wire())
	Sig.party_fight_changed.emit(f.at)


func _apply_hull(id: int, hull_id: StringName) -> void:
	if not roster.has(id):
		return
	roster[id].hull = hull_id
	_push_roster()
	Sig.party_changed.emit()


func _apply_dive(seed_value: int, unlocked: Array = []) -> void:
	dive_seed = seed_value
	galaxy_jumps = 0
	_jumps_said.clear()
	dive_unlocked.clear()
	for m in unlocked:
		var id := StringName(str(m))
		if Unlocks.CHAIN.has(id) and not dive_unlocked.has(id):
			dive_unlocked.append(id)
	_set_state(State.DIVING)
	Sig.party_launched.emit(seed_value)


func _turn_away(who: int, reason: String) -> void:
	_refuse.rpc_id(who, reason)
	# One frame so the refusal is sent before the socket shuts, or the client says connection lost.
	await get_tree().process_frame
	# And the host may itself have gone in that frame.
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	multiplayer.multiplayer_peer.disconnect_peer(who)


func _push_roster() -> void:
	if not is_host():
		return
	# Skip an empty party: an RPC through a still-connecting peer is reported as an error.
	if multiplayer.get_peers().is_empty():
		return
	_push_roster_to.rpc(slots())


func _slot(id: int, player_name: String, hull_id: StringName, order: int) -> Dictionary:
	# `build` is empty and `at` is -1 until that player has a ship and a place to
	# be in. See build_of() and where_is().
	return {"id": id, "name": player_name, "hull": hull_id, "ready": false,
		"order": order, "build": {}, "at": -1}


func _set_state(next: State) -> void:
	if state == next:
		return
	state = next
	Sig.party_state_changed.emit(int(next))


func _fail(message: String) -> String:
	_error = message
	transport = null
	_set_state(State.FAILED)
	Sig.party_failed.emit(message)
	return ""


func _drop(message: String) -> void:
	_error = message
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	roster.clear()
	_builds.clear()
	claims.clear()
	fights.clear()
	_held_asks.clear()
	spots.clear()
	flights.clear()
	_own_flight = {}
	_flight_said = 0
	_galaxy_theirs.clear()
	galaxy_mine.clear()
	galaxy_warning = ""
	# The party's copy goes with the party; `Run.party_jumps` stays, so a guest
	# whose host left flies on at the count it had and its boss never shrinks
	galaxy_jumps = 0
	_jumps_said.clear()
	_set_state(State.FAILED)
	Sig.party_failed.emit(message)


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
