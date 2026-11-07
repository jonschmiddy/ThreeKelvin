class_name RelayTransport
extends NetTransport

## The room number is the Durable Object's name, so there is no registry.
## Why: docs/why/RelayTransport.md#relay-transport

## Use `wss://`, not the `https://` deploy prints: the scheme separates a socket from a page.
## Why: docs/why/RelayTransport.md#relay-transport
const DEFAULT_URL: String = "wss://threekelvin-relay.james-e09.workers.dev"

## Overridable on the command line so `wrangler dev` can be tested without a rebuild.
var base_url: String = ""

var peer: RelayPeer = null


func _init() -> void:
	base_url = url_from_args()


## Take the token after `relay` as a URL only if it looks like one, so `relay auto` stays a switch.
## Why: docs/why/RelayTransport.md#relay-transport
static func url_from_args() -> String:
	var argv := OS.get_cmdline_user_args()
	for i in argv.size():
		if argv[i] != "relay" or i + 1 >= argv.size():
			continue
		var next := argv[i + 1].strip_edges()
		if next.begins_with("ws://") or next.begins_with("wss://"):
			return next
	return DEFAULT_URL


static func is_configured() -> bool:
	return not url_from_args().is_empty()


func kind() -> Kind:
	return Kind.ROOM


func label() -> String:
	return "relay"


## The whole point. Nobody opens a port and nobody types an address.
func is_traversal_free() -> bool:
	return true


func create_host() -> MultiplayerPeer:
	if base_url.is_empty():
		return _fail("No relay is configured in this build.")
	# Rolled locally: 33.5M rooms make collisions unlikely, and the relay refuses a second host.
	code = LobbyCode.encode_room(LobbyCode.roll_room())
	return _open(code, "host")


func create_client(lobby_code: String) -> MultiplayerPeer:
	if base_url.is_empty():
		return _fail("No relay is configured in this build.")
	var parsed := LobbyCode.parse(lobby_code)
	if parsed.error != "":
		return _fail(parsed.error)
	if parsed.kind != LobbyCode.Kind.ROOM:
		return _fail("That is a direct code. It carries an address, not a party.")
	code = LobbyCode.normalise(lobby_code)
	return _open(code, "client")


func _open(room_code: String, role: String) -> MultiplayerPeer:
	peer = RelayPeer.new()
	var err := peer.open("%s/party/%s?role=%s" % [
		base_url.trim_suffix("/"), LobbyCode.normalise(room_code), role],
		role == "host")
	if err != OK:
		peer = null
		return _fail("Could not open a connection to the relay (error %d)." % err)
	return peer


## Prefer the relay's message: a full party and a closed connection differ to a player.
func last_error() -> String:
	if peer != null and not peer.deny_reason.is_empty():
		return peer.deny_reason
	return _error
