class_name DirectTransport
extends NetTransport

## Needs no service but asks the host to forward a port; it is the one testable on one machine.
## Why: docs/why/DirectTransport.md#direct-transport

## An unassigned, uncommon port; the code carries the bound port, so a moved one costs nothing.
const DEFAULT_PORT: int = 31337

var port: int = DEFAULT_PORT
## The address the code advertises. Left empty to be discovered, which is
## almost always wrong — see public_guess() for why.
var advertise: String = ""


func kind() -> Kind:
	return Kind.DIRECT


func label() -> String:
	return "direct"


## More sockets than seats, so NetSession can refuse a player past MAX_PLAYERS in words, not a silent drop.
const CONNECTION_SLACK: int = 4

func create_host() -> MultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1 + CONNECTION_SLACK)
	if err != OK:
		if err == ERR_ALREADY_IN_USE:
			return _fail("Port %d is already in use on this machine." % port)
		return _fail("Could not open port %d (error %d)." % [port, err])
	var address := advertise if not advertise.is_empty() else public_guess()
	code = LobbyCode.encode_direct(address, port)
	if code.is_empty():
		peer.close()
		return _fail("'%s' is not an address a code can carry." % address)
	return peer


func create_client(lobby_code: String) -> MultiplayerPeer:
	var parsed := LobbyCode.parse(lobby_code)
	if parsed.error != "":
		return _fail(parsed.error)
	if parsed.kind != LobbyCode.Kind.DIRECT:
		return _fail("That is a party code. This build joins by address.")
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(parsed.ip, parsed.port)
	if err != OK:
		return _fail("Could not reach %s:%d (error %d)." % [parsed.ip, parsed.port, err])
	code = LobbyCode.normalise(lobby_code)
	return peer


## A direct transport cannot promise anything about the router; saying so avoids NAT surprises.
func is_traversal_free() -> bool:
	return false


## A NAT machine cannot learn its public address by looking inward; the host types it in.
## Why: docs/why/DirectTransport.md#public-guess
func public_guess() -> String:
	var best := "127.0.0.1"
	for a in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127."):
			continue
		best = a
		if a.begins_with("192.168.") or a.begins_with("10."):
			return a
	return best
