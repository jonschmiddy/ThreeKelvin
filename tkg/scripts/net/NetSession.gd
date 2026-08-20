class_name NetSession
extends Node

## The party: who is in it, whether their builds agree, and what galaxy they
## are about to share. Autoloaded as `Net`.
##
## This is the session layer and nothing else. It does not move a ship, resolve
## a card or own a run. That separation is on purpose and it is what makes the
## thing testable before any of the co-op design in `coop-design.md` exists:
## the questions "can four machines find each other, agree, and start together"
## and "what happens once they have" are independent, and the first one is the
## one that is hard to change later.
##
## Three rules hold the design up.
##
## **The host is the authority.** There is no vote and no merge. The host's
## roster is the roster, the host's seed is the seed. `Combat` is already a
## plain RefCounted with no UI dependency and `HeadlessSim` already plays whole
## runs headless, so the machine that decides is a machine that can already run
## the game with nothing drawn — the expensive precondition for authority is
## paid for.
##
## **The handshake refuses before it connects.** A party whose builds disagree
## does not fail at connect time; it fails forty minutes in, at the one node
## where one player's build rolled a module the others do not have. So the
## protocol number and a fingerprint of the content tables are checked in the
## first message, and a mismatch is refused by name.
##
## **Nothing here knows the transport.** See NetTransport. The code is the
## seam.
##
## What is NOT here yet, and is deliberately not here: any gameplay RPC. The
## galaxy seed goes across and the dive starts; from that moment the two
## machines are running the same generator over the same seed and nothing is
## being kept in step. That is not a shipping model — it is the smallest thing
## that proves the layer works, and it is the reason RNG determinism is listed
## as a prerequisite rather than a nicety.

## Bumped on any change to the messages below, or to the meaning of the fields
## in them. Two builds with different numbers refuse each other immediately.
## This is cheap to raise and very expensive to have forgotten.
const PROTOCOL: int = 1

const MAX_PLAYERS: int = NetTransport.MAX_PLAYERS

## Long enough for a slow machine to finish loading its content tables, short
## enough that a player staring at a spinner gives up after it rather than
## before it. A variable rather than a constant only so the headless test does
## not have to spend ten real seconds proving that a timeout times out.
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

var _error: String = ""
var _local_name: String = "Pilot"
var _local_hull: StringName = &""
var _content_hash: int = 0
var _handshake_deadline: float = 0.0

## Test seams. Zero means "use the real value". A session with either of these
## set is pretending to be a different build, which is the only way to exercise
## the two refusal paths without keeping a second checkout on disk — and those
## two paths are exactly the ones that must not be found by a player forty
## minutes into a dive. Never set from game code.
var forced_protocol: int = 0
var forced_fingerprint: int = 0

## Arrival order, kept by the host. Peer ids are random 32-bit numbers, not a
## count, so sorting a roster by id shuffles the party every time somebody
## reconnects — and the lobby list is the one place four people look to check
## that everyone is there. Order is assigned once, travels with the slot, and
## the host is always zero.
var _join_serial: int = 0
var _said_hello: bool = false


func _ready() -> void:
	# Only the autoload copy should be reachable by name. The headless test
	# builds its own instances under their own multiplayer roots, and those
	# must not be mistaken for the session the game is playing.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_host_lost)


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
	_said_hello = false
	_join_serial = 0
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
	_said_hello = false
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
	transport = null
	dive_seed = 0
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
	# Through Rng, not randi(), so that `-- seed N` on the host's machine puts
	# the whole party in a known galaxy. A co-op bug report is four people's
	# time; being able to hand back the number that produced it is worth more
	# here than it is solo.
	var seed_value := Rng.roll_master()
	_begin_dive.rpc(seed_value)
	_apply_dive(seed_value)
	return true


# --- what a screen reads -------------------------------------------------

func is_networked() -> bool:
	return state != State.OFFLINE and state != State.FAILED


func is_host() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()


func local_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 1
	return multiplayer.get_unique_id()


func party_size() -> int:
	return roster.size()


func everyone_ready() -> bool:
	if roster.is_empty():
		return false
	for slot in roster.values():
		if not slot.ready:
			return false
	return true


func last_error() -> String:
	return _error


## Ordered for display: the host first, then by the order people arrived.
func slots() -> Array:
	var out: Array = roster.values().duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.order < b.order)
	return out


## A number that must match across the party, standing in for "we are playing
## the same game". It covers the content tables rather than the build, because
## two players on the same commit with different mods is the case that actually
## happens, and a version string would call that a match.
##
## Deliberately cheap and deliberately coarse. It cannot tell you WHAT differs,
## only that something does — the message it produces sends the player to
## compare builds, which is the only useful action anyway.
func content_fingerprint() -> int:
	var parts: PackedStringArray = []
	var mod_ids := DB.modules.keys()
	mod_ids.sort()
	for id in mod_ids:
		parts.append(String(id))
	var foe_ids := DB.enemies.keys()
	foe_ids.sort()
	for id in foe_ids:
		parts.append(String(id))
	for h in DB.hull_frames:
		parts.append("%s/%d" % [h.manufacturer, int(h.weight)])
	for a in DB.affixes:
		parts.append(a.name)
	return hash("|".join(parts))


func _process(_delta: float) -> void:
	if state != State.JOINING:
		return
	# A peer that has gone away while we were still joining is a failed join,
	# whatever the engine did or did not emit about it. Watching the status
	# directly rather than waiting for a signal is what makes a refusal
	# immediate: the relay answers "the party is full" in milliseconds, and
	# without this the player sat through the full ten-second handshake timeout
	# before being told — an instant answer, delivered late, reads as a hang.
	var peer := multiplayer.multiplayer_peer if multiplayer != null else null
	if peer == null or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		_drop(_why("Could not reach the party."))
		return
	if _now() > _handshake_deadline:
		_drop(_why("The host did not answer. Check the code, and whether the port is open."))


# --- the handshake --------------------------------------------------------
#
# Host side is `_hello` and nothing else: one message in, a decision, and
# either a roster broadcast or a refusal. Everything the host needs to refuse
# is in that one message, so a client that is going to be turned away is turned
# away before it has been told anything about the party.

@rpc("any_peer", "call_remote", "reliable")
func _hello(protocol: int, fingerprint: int, player_name: String, hull_id: StringName) -> void:
	if not is_host():
		return
	var who := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		_turn_away(who, "Different game version. Host is protocol %d, you are %d." % [PROTOCOL, protocol])
		return
	if fingerprint != _content_hash:
		_turn_away(who, "Your content does not match the host's. Compare builds or mods.")
		return
	if roster.size() >= MAX_PLAYERS:
		_turn_away(who, "The party is full.")
		return
	_join_serial += 1
	roster[who] = _slot(who, player_name, hull_id, _join_serial)
	_accept.rpc_id(who)
	_push_roster()
	Sig.party_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _accept() -> void:
	_set_state(State.IN_PARTY)


@rpc("authority", "call_remote", "reliable")
func _refuse(reason: String) -> void:
	_drop(reason)


@rpc("authority", "call_remote", "reliable")
func _push_roster_to(rows: Array) -> void:
	roster.clear()
	for row in rows:
		roster[int(row.id)] = row
	if state == State.JOINING:
		_set_state(State.IN_PARTY)
	Sig.party_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _set_ready_at_host(value: bool) -> void:
	if is_host():
		_apply_ready(multiplayer.get_remote_sender_id(), value)


@rpc("any_peer", "call_remote", "reliable")
func _choose_hull_at_host(hull_id: StringName) -> void:
	if is_host():
		_apply_hull(multiplayer.get_remote_sender_id(), hull_id)


@rpc("authority", "call_remote", "reliable")
func _begin_dive(seed_value: int) -> void:
	_apply_dive(seed_value)


# --- plumbing -------------------------------------------------------------

## Say hello, once, however the news arrives.
##
## ENet makes SceneMultiplayer emit `connected_to_server`. A custom peer may
## instead only produce `peer_connected(1)` — the host appearing — depending on
## how the engine derives one from the other. Both are wired, and the flag makes
## the second one harmless. A handshake that fires twice is a refused duplicate;
## a handshake that never fires is a party that never forms, and the transport
## it fails on is the one nobody has tested yet.
func _on_connected() -> void:
	_say_hello()


func _say_hello() -> void:
	if is_host() or _said_hello:
		return
	_said_hello = true
	var speak := forced_protocol if forced_protocol != 0 else PROTOCOL
	_hello.rpc_id(1, speak, _content_hash, _local_name, _local_hull)


func _on_connect_failed() -> void:
	_drop(_why("Could not connect. The host may be offline, or the port closed."))


func _on_host_lost() -> void:
	_drop(_why("The host left."))


## What the transport says, if it knows something better.
##
## A MultiplayerPeer has nowhere to put a sentence — it can report that a socket
## closed and nothing about why — so a relay that politely answers "the party is
## full" and then hangs up arrives here as an ordinary disconnect, and the
## player is told to check a port that has nothing to do with it. The transport
## keeps the real reason; this is the only place that asks for it.
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
	if roster.erase(id):
		_push_roster()
		Sig.party_changed.emit()


func _apply_ready(id: int, value: bool) -> void:
	if not roster.has(id):
		return
	roster[id].ready = value
	_push_roster()
	Sig.party_changed.emit()


func _apply_hull(id: int, hull_id: StringName) -> void:
	if not roster.has(id):
		return
	roster[id].hull = hull_id
	_push_roster()
	Sig.party_changed.emit()


func _apply_dive(seed_value: int) -> void:
	dive_seed = seed_value
	_set_state(State.DIVING)
	Sig.party_launched.emit(seed_value)


func _turn_away(who: int, reason: String) -> void:
	_refuse.rpc_id(who, reason)
	# One frame, so the refusal is on the wire before the socket shuts. Without
	# it the client sees a bare disconnect and reports "connection lost", which
	# is the one message that tells the player nothing they can act on.
	await get_tree().process_frame
	# And the host may itself have gone in that frame.
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	multiplayer.multiplayer_peer.disconnect_peer(who)


func _push_roster() -> void:
	if not is_host():
		return
	# Nobody to tell. Broadcasting to an empty party is not merely wasted — on a
	# transport whose socket opens asynchronously it is an RPC through a peer
	# that is still connecting, which the engine reports as an error for
	# something that was never going to be sent anywhere.
	if multiplayer.get_peers().is_empty():
		return
	_push_roster_to.rpc(slots())


func _slot(id: int, player_name: String, hull_id: StringName, order: int) -> Dictionary:
	return {"id": id, "name": player_name, "hull": hull_id, "ready": false, "order": order}


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
	_set_state(State.FAILED)
	Sig.party_failed.emit(message)


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
