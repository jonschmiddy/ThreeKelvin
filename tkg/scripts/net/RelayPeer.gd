class_name RelayPeer
extends MultiplayerPeerExtension

## A MultiplayerPeerExtension, so `NetSession`'s RPCs need no change when UDP becomes a WebSocket.
## Not WebSocketMultiplayerPeer: its framing is an engine internal that may change between versions.
## Why: docs/why/RelayPeer.md#relay-peer-design

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

## Set explicitly: a silent truncation at the transport looks like a game bug.
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

## Why the socket closed, as a MultiplayerPeer has nowhere to put a sentence.
var deny_reason: String = ""


## The host's id is 1 by protocol, so it is claimed before the socket opens:
## `host_party()` asks `is_host()` on the next line, as it would of an ENet server.
## Why: docs/why/RelayPeer.md#opening
func open(url: String, hosting: bool) -> Error:
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = BUFFER_BYTES
	_ws.outbound_buffer_size = BUFFER_BYTES
	# No write mode: Godot 4.7's WebSocketPeer dropped it, and put_packet() sends binary frames.
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
		# Only after the handshake: setting an option on a connecting peer is an engine error.
		_tuned = true
		_ws.set_no_delay(true)

	# Drained in every state: a refusal is one message
	# then a close, and CLOSED must not discard it.
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
			# CONNECTED before any JOIN is handled,
			# or SceneMultiplayer drops `peer_connected` and no party appears.
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
			# Disconnect now, not when the socket finishes closing: waiting made a refusal
			# reach the player after the ten-second timeout, reading as a hang.
			# Why: docs/why/RelayPeer.md#refusal-timing
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


## Peers first, then the status, or SceneMultiplayer never delivers the departures.
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


## These report the next packet's sender, as `SceneMultiplayer.poll()` asks before reading.
## The previous sender looks fine with two machines but misattributes RPCs with more.
## Why: docs/why/RelayPeer.md#packet-sender
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


## The relay reaches every peer directly, so saying
## otherwise makes Godot forward through the host needlessly.
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


## Accepted and ignored: a WebSocket is TCP, so delivery is always reliable and ordered.
func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode


func _set_refuse_new_connections(enable: bool) -> void:
	_refusing = enable


func _is_refusing_new_connections() -> bool:
	return _refusing


## Only the relay can evict; the host closing its own connection ends the party, as the relay does.
func _disconnect_peer(peer: int, _force: bool) -> void:
	if peer == _id:
		_close()


func _close() -> void:
	if _ws != null:
		_ws.close()
	_shut_down()
	_ws = null
