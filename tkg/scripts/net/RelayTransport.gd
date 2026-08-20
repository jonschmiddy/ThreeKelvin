class_name RelayTransport
extends NetTransport

## A room number, and a Cloudflare Durable Object to meet in.
##
## This is the transport that makes the game playable by four friends who have
## never heard of port forwarding, and it is the reason `LobbyCode` has always
## had two kinds of code. `DirectTransport` puts an ADDRESS in the code, which
## works and asks the host to open a port. This puts a ROOM NUMBER in it — and
## the room number is the Durable Object's own name, so there is no registry,
## no allocation service and nothing to clean up. A party exists for exactly as
## long as somebody is connected to it.
##
## See `docs/netcode.md` §2 for the cost, which is roughly nothing, and for the two
## constraints that shaped it: Cloudflare cannot carry UDP, and a Durable Object
## must hibernate or it bills for wall-clock time.

## Filled in after `wrangler deploy` prints it. Empty means the relay has not
## been deployed yet, and the lobby says so rather than offering a button that
## cannot work.
##
## `wss://`, not the `https://` that deploy prints. Same host, and the scheme is
## the difference between a socket and a page.
const DEFAULT_URL: String = "wss://threekelvin-relay.james-e09.workers.dev"

## Overridable from the command line so that `wrangler dev` can be tested
## against without editing and rebuilding:
##   godot --path . -- lobby host relay ws://localhost:8787
var base_url: String = ""

var peer: RelayPeer = null


func _init() -> void:
	base_url = url_from_args()


## The relay to talk to: the command line if it named one, otherwise the
## deployed default.
## The token after `relay` is only taken as a URL if it looks like one. Without
## that check, `-- lobby host relay auto` sets the relay address to "auto" and
## fails with a connection error about a host that was never named — the flag
## reads as a transport switch, so it has to keep working as one when no
## address follows it.
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
	# Rolled locally rather than asked for. 33.5 million rooms and at most a few
	# thousand in flight means a collision is vanishingly unlikely, and the relay
	# refuses a second host on a code that is already hosting — so a collision
	# is reported as a refusal rather than as two parties in one room.
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


## What the relay said, if it said anything, in preference to what the socket
## looked like. "The party is full" and "connection closed" are the same event
## at the transport and completely different facts to a player.
func last_error() -> String:
	if peer != null and not peer.deny_reason.is_empty():
		return peer.deny_reason
	return _error
