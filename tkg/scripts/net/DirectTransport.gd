class_name DirectTransport
extends NetTransport

## ENet at a plain address, with the address folded into the lobby code.
##
## This is the transport that needs nobody: no service, no account, no bill,
## no dependency that can be switched off. It is also the one that asks the
## host to forward a port, which is a real cost paid by a real person before
## anyone can play. Both halves of that are true at once and neither should be
## hidden from the host.
##
## It earns its place regardless of what ships, because it is the only
## transport that can be tested on one machine with no external parts. Every
## rule above it — the roster, the handshake, the version check, the launch —
## is exercised by the headless test through this class. A relay or a platform
## backend arriving later inherits a session layer that has already been made
## to work, rather than being the thing that has to prove it.

## Chosen from the unassigned range and away from anything common. The host may
## move it; the code carries whatever port was actually bound, so a moved port
## costs the joining players nothing.
const DEFAULT_PORT: int = 31337

var port: int = DEFAULT_PORT
## The address the code advertises. Left empty to be discovered, which is
## almost always wrong — see public_guess() for why.
var advertise: String = ""


func kind() -> Kind:
	return Kind.DIRECT


func label() -> String:
	return "direct"


## Deliberately more sockets than seats. If ENet enforced the party size, a
## fifth player would be dropped by the transport with no message attached, and
## would see the same silent nothing as a closed port — two problems with
## opposite fixes, reported identically. Let them connect, then let NetSession
## turn them away in words.
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


## A direct transport cannot promise anything about the host's router, and
## saying otherwise in the lobby is how a host finds out about NAT from three
## friends who cannot connect.
func is_traversal_free() -> bool:
	return false


## The best address this machine can name for itself WITHOUT asking anything
## on the internet, which on a home connection is a LAN address and therefore
## wrong for anyone outside the house.
##
## This is not a gap to be closed by trying harder. A machine behind NAT cannot
## learn its own public address by looking inward; something outside has to
## tell it, and the moment you add that something you have a service, and once
## you have a service the room transport is strictly better than this one. So
## the LAN address is the honest answer here, and the lobby is expected to let
## the host type a public address over it.
func public_guess() -> String:
	var best := "127.0.0.1"
	for a in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127."):
			continue
		best = a
		if a.begins_with("192.168.") or a.begins_with("10."):
			return a
	return best
