class_name NetSession
extends Node

## The party: who is in it, whether their builds agree, and what galaxy they
## are about to share. Autoloaded as `Net`.
##
## This is the session layer and nothing else. It does not move a ship, resolve
## a card or own a run. That separation is on purpose and it is what makes the
## thing testable before any of the co-op design in `docs/coop-design.md` exists:
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
##
## 2: a roster slot carries `build` — the ship that player is flying, as
##    `ShipBuild.to_wire()`. A version 1 host would send slots without it and
##    every partner would be drawn as an empty hull.
## 3: a roster slot also carries `at` — which system that player is in — and
##    the host holds `claims`, the systems the party has consumed. A version 2
##    host answers neither, so every wreck would be strippable four times.
## 4: a claim names an OPTION within a system rather than the whole system, and
##    records WHO took it. A version 3 host would answer a request for one
##    option by consuming the entire node.
## 5: fights are shared. The host owns the enemy — hull, block, brace and
##    intent — and decides who it swings at. A version 4 host answers none of
##    the fight messages, so two ships in one system would fight two private
##    copies of the same frigate and both be paid for killing it.
## 6: a kill pays ONE bag rather than paying every ship privately, and the
##    fight carries how many hands were in it when the last hull came apart.
##    A version 5 partner would roll a bag of the wrong size and reach for
##    parts nobody else believes are there. The roster's `build` also carries
##    the hull's GRADE now, without which every partner is drawn as a C-class.
const PROTOCOL: int = 6

## How long a contested option waits for the host to say who got it.
##
## Generous. A relay round trip is well under 200 ms and this only runs when a
## player has clicked something, so the cost of being patient is nothing and the
## cost of giving up early is a wreck the player watched themselves reach first.
## If the host really is gone the session fails on its own and this refuses,
## which is the right way round: refusing costs one wreck, assuming costs the
## party's whole economy.
const TAKE_TIMEOUT: float = 3.0

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

## Everyone's ship, resolved from the wire and kept until the wire changes.
## Keyed by peer id, holding `[fingerprint, ShipBuild]`.
##
## The fingerprint is what makes this a cache rather than a delay. A roster
## arrives as a whole and REPLACES every slot, so four ships are new objects
## every time one player vents a point of heat — and a partner's build being a
## new object is what a view uses to decide it has to repaint. Repainting a hull
## is fifteen thousand pixels of GDScript, three times over, several times a
## turn. So the wire is fingerprinted and an unchanged ship comes back as the
## same object it was.
var _builds: Dictionary = {}

## The local presence, as last described to the party.
##
## A fingerprint rather than the dictionary: the comparison is what stops a
## fight from broadcasting a roster on every point of heat, and comparing two
## nested dictionaries every frame to save sending one is the wrong trade.
var _presence_sent: int = 0
var _presence_dirty: bool = false

## What the party has used up: `{node index: {option id: peer id}}`.
## Host-authoritative and pushed whole.
##
## THE MAP IS ONE INSTANCE, NOT FOUR COPIES. This is the line that decides it,
## and it is worth being explicit because the seed alone implies the opposite. A
## shared seed gives four machines an identical galaxy: the same systems, the
## same fights, the same wrecks holding the same modules, because everything a
## node holds is drawn from `Rng.derive(tag, node.index)` and therefore depends
## on WHERE it is rather than on who asked. What a seed cannot say is whether
## somebody has already been there. Without this list four players strip the
## same derelict and each keep the Legendary, and `docs/coop-design.md` §3's closed
## per-dive economy is paid out four times.
##
## Whole rather than incremental. A dive consumes tens of systems, not
## thousands, and a list that is rebuilt from scratch on every push cannot drift
## — which an append-only stream of deltas can, the first time one is dropped
## or arrives twice.
##
## AN OPTION, NOT A SYSTEM. A system that offers three or four things to do is
## not one resource: one ship strips the wreck and another still wants the
## fight, so the unit has to be the option. `MapGen.OPTION_WHOLE` is the id for
## an encounter that consumes the system entirely, which is every encounter that
## exists today — so a node with one thing to do carries exactly one entry.
##
## AND WHO TOOK IT. The peer id is not bookkeeping: arriving at a wreck that
## says "Mercer stripped this" is the whole social texture of flying together,
## and it is the difference between a system that is empty and a system that
## somebody emptied.
var claims: Dictionary = {}

## The fights the party is in, as `{node index: SharedFight}`.
##
## THE ENEMY IS THE SHARED OBJECT. Nothing about your own ship is in here, and
## that is not an omission — see SharedFight's header. A fight has exactly one
## thing in it that several players touch at once, and it is the hull they are
## all shooting at.
##
## Host-authoritative like `claims`, and pushed one fight at a time rather than
## whole: a fight changes several times a turn while claims change a few times
## an hour, and four people in three different systems have no use for each
## other's enemy bars.
##
## Kept after `over` rather than deleted. A fight ends by the host saying so,
## and the message that says so is the same push everything else arrives on —
## dropping the entry would leave the last one with nowhere to land. They are
## cleared with the rest of the session.
var fights: Dictionary = {}


func _ready() -> void:
	# Only the autoload copy should be reachable by name. The headless test
	# builds its own instances under their own multiplayer roots, and those
	# must not be mistaken for the session the game is playing.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_host_lost)

	# Your ship, whenever it changes, so the party can draw it.
	#
	# This is the one place the session layer reads run state, and it is worth
	# being explicit about why it is not a breach of the rule at the top of this
	# file. It does not move a ship or resolve anything: it forwards a picture.
	# The roster has carried `hull` since the first version for exactly the same
	# reason — what somebody is flying is a fact about the PARTY.
	Sig.ship_changed.connect(_mark_presence)
	Sig.resources_changed.connect(_mark_presence)
	Sig.player_combat_state_changed.connect(_mark_presence)
	# And where you are. A jump is the one thing in this game that moves a ship
	# between systems, so it is the only event that can change the answer.
	Sig.jumped.connect(func(_index: int) -> void: _mark_presence())


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
	_said_hello = false
	_join_serial = 0
	_presence_sent = 0
	_presence_dirty = true
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
	_said_hello = false
	_presence_sent = 0
	_presence_dirty = true
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


## What one player's ship looks like, or null if they have not said yet.
##
## Null is a real answer and callers have to mean it: a slot exists from the
## moment somebody joins, and their ship exists from the moment they leave the
## chassis select. Between those two the party knows a name and nothing else.
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


## Which system somebody is in, or -1 if they have not said.
##
## -1 is a real answer: a player still on the chassis select has a galaxy and no
## position in it yet, and the chart draws nothing for them rather than putting
## them on system zero.
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
	# Coalesced to one send per frame. Playing a card fires `resources_changed`
	# and `player_combat_state_changed` together, and venting fires the first of
	# them once per point — so the signals say "something moved" several times
	# for one thing a partner would see move once.
	if _presence_dirty and _can_talk():
		_presence_dirty = false
		_send_presence()
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
	# NOT `_builds.clear()`. Every slot here is a new dictionary and most of them
	# describe a ship that has not changed; build_of() compares fingerprints and
	# hands the old object back, which is what stops three hulls being redrawn
	# every time one of them takes a point of damage.
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


## "This is my ship, and this is where it is." Through the host like everything
## else, rather than peer to peer.
##
## Client-to-client would be one hop shorter and it is not worth having: the
## host is the authority, `_push_roster()` is already the tested path for
## telling four machines one fact, and the relay transport routes through the
## host anyway. One message shape, one direction, one place it can go wrong.
##
## The ship and the position travel together because they change for the same
## reasons and neither is worth a message of its own. A jump moves you and
## cools you; a fight damages you and heats you.
@rpc("any_peer", "call_remote", "reliable")
func _report_presence_at_host(wire: Dictionary, at: int) -> void:
	if is_host():
		_apply_presence(multiplayer.get_remote_sender_id(), wire, at)


## "I have used this up." Only the host keeps the list.
##
## The message is a NODE INDEX and an OPTION ID and nothing else. What was in
## the system does not travel, because it never had to: `Rng.derive(tag,
## node.index)` already puts the same modules in the same wreck on every
## machine. This says the wreck is empty now, which is the one fact a seed
## cannot carry.
@rpc("any_peer", "call_remote", "reliable")
func _claim_at_host(index: int, option: int) -> void:
	if is_host():
		_apply_claim(index, option, multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func _push_claims_to(all: Dictionary) -> void:
	claims = all
	Sig.party_map_changed.emit()


## Engage here. Open-or-join in one message, because the client asking cannot
## know which one it is: two ships jumping into the same system in the same
## second both believe they are first, and only the host can say otherwise.
@rpc("any_peer", "call_remote", "reliable")
func _open_fight_at_host(index: int, ids: PackedStringArray, hp: PackedInt32Array,
		brace: PackedInt32Array) -> void:
	if is_host():
		_open_or_join(index, ids, hp, brace, multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _hurt_at_host(index: int, which: int, amount: int, hits: int) -> void:
	if is_host():
		_apply_hurt(index, which, amount, hits, multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _end_turn_at_host(index: int) -> void:
	if is_host():
		_apply_end_turn(index, multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _leave_fight_at_host(index: int) -> void:
	if is_host():
		_apply_leave(index, multiplayer.get_remote_sender_id())


## One fight, not all of them. Claims are pushed whole because they change a few
## times an hour; a fight changes several times a turn, and three people in
## three different systems have no use for each other's enemy bars.
@rpc("authority", "call_remote", "reliable")
func _push_fight_to(wire: Dictionary) -> void:
	var f := SharedFight.from_wire(wire)
	if f.at < 0:
		return
	fights[f.at] = f
	Sig.party_fight_changed.emit(f.at)


## Something is shooting at YOU. Sent to one peer, never broadcast — see
## _swing(). The intent is named by index into the enemy's own scaled lists,
## which every machine built identically, so nothing about the attack itself has
## to travel by value.
@rpc("authority", "call_remote", "reliable")
func _enemy_swings(at: int, which: int, kind: int, pick: int) -> void:
	Sig.party_fight_swing.emit(at, which, kind, pick)


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
	# Out of every fight first. A dropped connection is indistinguishable from a
	# player who walked away mid-turn, and a crew list still holding them is a
	# barrier that never closes — the other three would sit on a WAITING button
	# for the rest of the run. See SharedFight.leave().
	for index in fights.keys():
		var f: SharedFight = fights[index]
		if f.crew.has(id):
			_apply_leave(int(index), id)
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


## Whether there is anybody to tell. HOSTING covers a host alone in a lobby,
## whose own slot still has to carry a build so that the next arrival is handed
## one; JOINING does NOT, and that is the point of this being separate from
## is_networked() — an RPC through a peer that is still connecting is reported
## as an error for a message that was never going to arrive.
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
	var stamp := hash([wire, at])
	if stamp == _presence_sent:
		return
	_presence_sent = stamp
	if is_host():
		_apply_presence(1, wire, at)
	else:
		_report_presence_at_host.rpc_id(1, wire, at)


func _apply_presence(id: int, wire: Dictionary, at: int) -> void:
	if not roster.has(id):
		return
	roster[id].build = wire
	roster[id].at = at
	_push_roster()
	Sig.party_changed.emit()


## Use something up, without waiting to hear whether you got it.
##
## For the outcomes you cannot lose a race for: the fight you just won, the hail
## you were already inside. Nobody else can arrive and take those out from under
## you, so the round trip would buy nothing.
##
## Safe to call in the solo game, where it does nothing at all — which is why
## every call site could be changed without gaining a branch.
func claim(index: int, option: int = MapGen.OPTION_WHOLE) -> void:
	if not _can_talk() or index < 0:
		return
	if is_host():
		_apply_claim(index, option, 1)
	else:
		# The caller has already marked its own copy of the node — see
		# RunState.consume_node(). A client that waited for the round trip would
		# show the wreck it just stripped as still full until the host answered,
		# which on a relay is a visible flicker on the chart.
		_claim_at_host.rpc_id(1, index, option)


## Ask for something only one ship can have, and wait for the answer. Returns
## the peer id that owns it — yours if you won.
##
## ASK, DO NOT ASSUME. This is the half `claim()` gets wrong on purpose and this
## one has to get right. Two ships reach the same wreck in the same second; both
## mark it locally, both roll the loot, and the flag agreeing a moment later
## does not take the module back out of the loser's hold. One wreck, two
## Legendaries, and `docs/coop-design.md` §3's closed economy paying out twice.
##
## The host already resolves the race correctly by doing nothing clever:
## `_apply_claim` ignores an option somebody already owns, so the first message
## to arrive wins and every later one is told who did. All the client has to do
## is wait to be told, and a click is exactly the kind of moment that can afford
## a round trip.
##
## A timeout refuses rather than assuming. See TAKE_TIMEOUT.
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
	# Waiting on the roster push rather than on a reply of its own. The host
	# broadcasts the whole list on every change anyway, so an answer is already
	# on its way and a second message would be a second thing to keep in step.
	var deadline := _now() + TAKE_TIMEOUT
	while _now() < deadline:
		await get_tree().process_frame
		owner = who_took(index, option)
		if owner != 0:
			return owner
	return 0


# --- fights ---------------------------------------------------------------

## Engage at a system, alone or beside whoever is already shooting.
##
## `hp` and `brace` are what the caller's own `Combat._spawn` produced. They are
## passed in rather than worked out here so that danger scaling, boss exemption
## and the pack split stay in the one function that has always owned them — the
## session layer is not going to grow a second opinion about how tough a frigate
## is.
##
## Returns the shared fight, or null. NULL IS A NORMAL ANSWER AND MEANS "FIGHT
## IT ALONE": it is what the solo game gets, what a party of one gets, and what
## a client gets if the host never answers. All three want the same behaviour,
## which is the fight the game has always had.
func open_fight(index: int, ids: PackedStringArray, hp: PackedInt32Array,
		brace: PackedInt32Array) -> SharedFight:
	if not _can_talk() or index < 0 or party_size() < 2:
		return null
	if is_host():
		_open_or_join(index, ids, hp, brace, 1)
		return fights.get(index, null)
	# Ask and wait, for the same reason `take()` does: two ships arriving at one
	# system in the same second must end up in ONE fight. A client that opened
	# optimistically would spawn a private frigate, and the host's would arrive
	# a moment later holding different numbers.
	_open_fight_at_host.rpc_id(1, index, ids, hp, brace)
	var me := local_id()
	var deadline := _now() + TAKE_TIMEOUT
	while _now() < deadline:
		await get_tree().process_frame
		var f: SharedFight = fights.get(index, null)
		if f != null and f.crew.has(me):
			return f
	return null


## The fight at a system, shared or not, over or not. Callers check `over`.
func fight_at(index: int) -> SharedFight:
	return fights.get(index, null)


## Whether arriving here means joining something rather than starting it.
func fight_open_at(index: int) -> bool:
	var f: SharedFight = fights.get(index, null)
	return f != null and not f.over


## Which ship in the party this machine is: 0 for the host, then arrival order.
##
## ZERO WHEN FLYING ALONE, and that is what makes it safe to salt a solo run's
## streams with — see `Rng.seat`. The order is assigned once by the host and
## travels with the slot, so it does not shuffle when somebody reconnects the
## way a peer id would.
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


## You are out of it — dead, fled, or done. Not optional: a crew list holding
## somebody who will never press END TURN again is a fight that never takes
## another turn.
func leave_fight(index: int) -> void:
	if not _can_talk():
		return
	if is_host():
		_apply_leave(index, 1)
	else:
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


func _apply_claim(index: int, option: int, by: int) -> void:
	var here: Dictionary = claims.get(index, {})
	# First message wins. Every later one is a no-op, which is the whole of the
	# race resolution — there is nothing to compare and no clock to trust.
	if here.has(option):
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

func _open_or_join(index: int, ids: PackedStringArray, hp: PackedInt32Array,
		brace: PackedInt32Array, by: int) -> void:
	var f: SharedFight = fights.get(index, null)
	if f != null and not f.over:
		# Already somebody's fight. The second ship in is help, not a second
		# frigate — see SharedFight.join().
		if not f.join(by):
			return
	else:
		f = SharedFight.open(index, ids, hp, brace, by)
		fights[index] = f
		for i in f.foes.size():
			_pick_intent(f, i)
	_push_fight(f)


func _apply_hurt(index: int, which: int, amount: int, hits: int, by: int) -> void:
	var f: SharedFight = fights.get(index, null)
	if f == null or f.over or not f.crew.has(by):
		return
	f.hurt(which, amount, hits, by)
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
	f.leave(by)
	# Somebody leaving can be the thing that closes the barrier — three ships
	# waiting on a fourth who just died is a fight that would otherwise stop.
	if not f.over and not f.crew.is_empty() and f.waiting_on().is_empty():
		_swing(f)
		return
	_push_fight(f)


## The enemy turn. The one moment in a shared fight that is not free-running,
## because it is the one moment a shared object acts on several private ones.
##
## Each hull swings at ONE ship and the message goes to that ship alone. What
## happens next — dodge, block, brace, hull, feedback — is resolved on the
## victim's machine against its own `Run`, because those numbers live nowhere
## else and no other player has any use for them. Mirroring three partners'
## block values across the party would be a lot of wire for something nobody
## reads.
func _swing(f: SharedFight) -> void:
	for i in f.alive():
		var target := _who_gets_hit(f)
		if target == 0:
			break
		var e := f.foes[i]
		if target == 1:
			Sig.party_fight_swing.emit(f.at, i, e.kind, e.pick)
		else:
			_enemy_swings.rpc_id(target, f.at, i, e.kind, e.pick)
	f.advance()
	for i in f.foes.size():
		_pick_intent(f, i)
	# The turn number IS the "everybody go again" message. A separate one would
	# be a second thing to keep in step with the first.
	_push_fight(f)


## Who it swings at. Weighted by heat, and heat is already on the wire.
##
## THE FIELD REACHES INSIDE THE FIGHT. `docs/coop-design.md` §6 makes signature the
## dial for flying together, but every consequence it lists happens on the map —
## ambushes on arrival, a Stealth penalty, the overheat burn. This is the same
## rule one level down: the loudest ship in the room is the one being shot at.
## It gives the Korvan line a job it can do for the party (soak, run hot, hold
## the attention) and it makes venting a thing you do FOR somebody rather than
## only to survive your own reactor.
##
## The floor is the point. 0.5 base against a ceiling of 0.5 + 1.7 means a
## redlining ship draws roughly four times the fire of a cold one and a cold one
## is still never safe — a target rule with a zero in it is a party that solves
## the fight by electing a victim.
func _who_gets_hit(f: SharedFight) -> int:
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


## The next thing one hull intends to do. Host only, and that is the whole
## reason intents cross the wire at all: `pick_intent` draws from `Rng.fight`,
## which is an ordered stream rather than a positional derivation, so four
## machines rolling it independently would agree about nothing.
func _pick_intent(f: SharedFight, i: int) -> void:
	if i >= f.foe_ids.size() or i >= f.foes.size():
		return
	var t: EnemyTemplate = DB.enemies.get(StringName(f.foe_ids[i]))
	if t == null:
		return
	var e := f.foes[i]
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
	_set_state(State.FAILED)
	Sig.party_failed.emit(message)


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
