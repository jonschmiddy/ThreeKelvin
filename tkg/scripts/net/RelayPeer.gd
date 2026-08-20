class_name RelayPeer
extends MultiplayerPeerExtension

## A Godot MultiplayerPeer that speaks to the Cloudflare relay.
##
## This class exists so that NOTHING ELSE HAS TO CHANGE. `NetSession` is built
## on Godot RPCs, and RPCs need a `MultiplayerPeer`. A `MultiplayerPeerExtension`
## IS one — so this returns from `NetTransport.create_host()` exactly where an
## `ENetMultiplayerPeer` used to, and the roster, the handshake, the version
## refusal and the launch all keep working without knowing the transport moved
## from UDP to a WebSocket on the other side of the planet.
##
## **Why not `WebSocketMultiplayerPeer`, which already exists.** Because its
## client mode expects a server that speaks Godot's own multiplayer framing —
## peer-id assignment and packet headers defined in engine source rather than in
## any specification. A Durable Object could reimplement that, and would then be
## reverse-engineering an engine internal that is free to change between Godot
## versions, in a file nobody would think to check when upgrading. Owning both
## ends of a nine-byte header is less work and cannot rot.
##
## ## The wire
##
## Little-endian, binary frames, byte 0 is the type. Must match `relay/src/index.js`.
##
##   HELLO  [1][u32 your_id]
##   JOIN   [2][u32 peer_id]
##   LEAVE  [3][u32 peer_id]
##   DENY   [4][utf8 reason]        ...and then the socket closes
##   DATA   [16][i32 from][i32 to][u8 mode][u8 channel][payload]
##
## `from` is written by the relay and never trusted from a sender. `to` follows
## Godot's targeting exactly: 0 is everyone, a positive id is one peer, and a
## negative id is everyone except that one.

const T_HELLO: int = 1
const T_JOIN: int = 2
const T_LEAVE: int = 3
const T_DENY: int = 4
const T_DATA: int = 16
const DATA_HEADER: int = 11

const HOST_ID: int = 1

## Application close codes from the relay. 1006 is the browser/engine's own
## "closed abnormally", which is what a network failure looks like from here.
const CLOSE_DENIED: int = 4001
const CLOSE_HOST_LEFT: int = 4002

## Godot's default is 64 KiB in and out. A jump commit is tens of bytes and the
## largest thing this will ever carry is a roster, so the default is already
## generous — it is set explicitly because a silent truncation at the transport
## is the kind of bug that looks like a game bug.
const BUFFER_BYTES: int = 65536

var _ws: WebSocketPeer = null
var _id: int = 0
var _status: int = MultiplayerPeer.CONNECTION_DISCONNECTED
var _target: int = 0
var _mode: int = MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _channel: int = 0
var _refusing: bool = false
var _tuned: bool = false

## Incoming, in arrival order: {from, data, mode, channel}.
var _queue: Array[Dictionary] = []
var _peers: Dictionary = {}

## Why the socket closed, in words, when the relay bothered to say. Read by
## RelayTransport after the fact — a MultiplayerPeer has nowhere to put a
## sentence, which is exactly why refusals arrive as bare disconnects so often.
var deny_reason: String = ""


## Open the socket. The URL carries the room and the role; see the relay.
##
## `hosting` is not a request — the host's peer id is 1 by protocol, so it is
## known before the socket opens and is claimed here rather than waited for.
## That matters because `NetSession.host_party()` asks `is_host()` in the next
## line, and an ENet server is a server the moment it binds. A relay host that
## only learned its own id a round trip later would be, for those few frames, a
## host that did not believe it was one — which is the sort of difference
## between transports the session layer was built specifically not to see.
##
## The status stays CONNECTING until the relay actually says HELLO, so nothing
## is sent into a socket that has not opened.
func open(url: String, hosting: bool) -> Error:
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = BUFFER_BYTES
	_ws.outbound_buffer_size = BUFFER_BYTES
	# No write mode is set here, and there is nothing missing. Godot 4.7's
	# WebSocketPeer dropped `write_mode` entirely — put_packet() sends binary
	# frames and that is the only behaviour there is. Older guidance says to set
	# WRITE_MODE_BINARY; on this engine that call does not exist and neither
	# does the property.
	var err := _ws.connect_to_url(url)
	if err != OK:
		_ws = null
		return err
	_id = HOST_ID if hosting else 0
	_status = MultiplayerPeer.CONNECTION_CONNECTING
	return OK


# --- the peer ------------------------------------------------------------

func _poll() -> void:
	if _ws == null:
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not _tuned:
		# Only once the handshake is done: there is no TCP socket to set an
		# option on before that, and asking for one on a connecting peer is an
		# engine error rather than a no-op.
		_tuned = true
		_ws.set_no_delay(true)

	# Drained whatever the state, and the closing states are the point. A
	# refusal is one message followed immediately by a close, so a poll that
	# reads the state first and gives up on CLOSED throws away the only sentence
	# the relay sent — and the player is told the connection failed instead of
	# being told the party is full.
	while _ws.get_available_packet_count() > 0:
		_receive(_ws.get_packet())

	if state == WebSocketPeer.STATE_CLOSED:
		_shut_down()


func _receive(frame: PackedByteArray) -> void:
	if frame.is_empty():
		return
	match frame[0]:
		T_HELLO:
			if frame.size() < 5:
				return
			_id = frame.decode_u32(1)
			# CONNECTED before any JOIN is handled, and that order is load
			# bearing: SceneMultiplayer ignores a peer that is still connecting,
			# so a peer_connected emitted first would be dropped on the floor
			# and the party would never appear.
			_status = MultiplayerPeer.CONNECTION_CONNECTED
		T_JOIN:
			if frame.size() < 5:
				return
			var joined := int(frame.decode_u32(1))
			if joined == _id or _peers.has(joined):
				return
			_peers[joined] = true
			emit_signal(&"peer_connected", joined)
		T_LEAVE:
			if frame.size() < 5:
				return
			var left := int(frame.decode_u32(1))
			if not _peers.erase(left):
				return
			emit_signal(&"peer_disconnected", left)
		T_DENY:
			# We hang up, not the relay. It sends the reason and leaves the socket
			# open precisely so this can be read first — see relay/src/index.js.
			deny_reason = frame.slice(1).get_string_from_utf8()
			if _ws != null:
				_ws.close(CLOSE_DENIED, "denied")
			# Disconnected NOW, not when the socket finishes closing. A refusal
			# is final the moment it is read, and a WebSocket close handshake
			# takes long enough that waiting for it let the layer above sit on
			# the ten-second handshake timeout instead — so an answer that
			# arrived in milliseconds was delivered to the player in eleven
			# seconds, which reads as a hang rather than as a refusal.
			_shut_down()
		T_DATA:
			if frame.size() < DATA_HEADER:
				return
			_queue.append({
				"from": frame.decode_s32(1),
				"mode": frame.decode_u8(9),
				"channel": frame.decode_u8(10),
				"data": frame.slice(DATA_HEADER),
			})


## The socket is gone. Everything after this is about telling the layers above
## in the right order — peers first, then the status — because SceneMultiplayer
## stops looking at a disconnected peer and would never deliver the departures.
func _shut_down() -> void:
	if _status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	if deny_reason.is_empty() and _ws != null:
		match _ws.get_close_code():
			CLOSE_HOST_LEFT:
				deny_reason = "The host left."
			CLOSE_DENIED:
				deny_reason = "The relay refused the connection."
			_:
				if _status == MultiplayerPeer.CONNECTION_CONNECTING:
					deny_reason = "Could not reach the relay."
	for id in _peers.keys():
		emit_signal(&"peer_disconnected", int(id))
	_peers.clear()
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _ws == null or _status != MultiplayerPeer.CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	var frame := PackedByteArray()
	frame.resize(DATA_HEADER)
	frame.encode_u8(0, T_DATA)
	# Written for readability on the wire only. The relay overwrites it with the
	# id it assigned, because a sender that can name itself can name the host.
	frame.encode_s32(1, _id)
	frame.encode_s32(5, _target)
	frame.encode_u8(9, _mode)
	frame.encode_u8(10, _channel)
	frame.append_array(buffer)
	return _ws.put_packet(frame)


func _get_packet_script() -> PackedByteArray:
	if _queue.is_empty():
		return PackedByteArray()
	return (_queue.pop_front() as Dictionary).data


func _get_available_packet_count() -> int:
	return _queue.size()


## THE NEXT packet's sender, not the last one's.
##
## `SceneMultiplayer.poll()` asks who sent a packet BEFORE it asks for the
## packet, so these three have to peek at the front of the queue rather than
## report what was handed over last. Reporting the previous sender does not look
## broken with two machines, because every packet comes from the same peer and
## the value is only wrong once — the engine drops the first message of the
## handshake with "Condition !connected_peers.has(sender) is true" and the
## roster broadcast behind it papers over the loss.
##
## With three or four ships it stops being cosmetic: every packet is attributed
## to whoever sent the one before it, so an RPC from one player is processed as
## though it came from another. In a design where the host is the authority and
## the roster is keyed by peer id, that is as bad as it sounds.
func _get_packet_peer() -> int:
	return 0 if _queue.is_empty() else int(_queue[0].from)


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	if _queue.is_empty():
		return MultiplayerPeer.TRANSFER_MODE_RELIABLE
	return _queue[0].mode


func _get_packet_channel() -> int:
	return 0 if _queue.is_empty() else int(_queue[0].channel)


func _get_max_packet_size() -> int:
	return BUFFER_BYTES


func _get_unique_id() -> int:
	return _id


func _is_server() -> bool:
	return _id == HOST_ID


## The relay reaches every peer directly, so nothing needs forwarding through
## the host. Saying otherwise would make Godot wrap client-to-client traffic
## for peer 1 to pass on — work the relay has already done.
func _is_server_relay_supported() -> bool:
	return false


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status


func _set_target_peer(peer: int) -> void:
	_target = peer


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


## Accepted and ignored. Everything here is reliable and ordered because a
## WebSocket is TCP and cannot be anything else — a caller asking for unreliable
## delivery gets reliable delivery, which is safe in the direction that matters.
func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode


func _set_refuse_new_connections(enable: bool) -> void:
	_refusing = enable


func _is_refusing_new_connections() -> bool:
	return _refusing


## Only the relay can evict anybody — a peer cannot close somebody else's
## socket. The host closing its own connection ends the party, which is what
## the relay does with it, so the effect a caller wants still happens.
func _disconnect_peer(peer: int, _force: bool) -> void:
	if peer == _id:
		_close()


func _close() -> void:
	if _ws != null:
		_ws.close()
	_shut_down()
	_ws = null
