class_name NetTransport
extends RefCounted

## Three ways to join: DIRECT, ROOM, PLATFORM. The
## lobby code is the seam, so choosing stays one line.
## Why: docs/why/NetTransport.md#transports

enum Kind { DIRECT, ROOM, PLATFORM }

## Eight, raised from four after `tools/coplay.sh 6` flew six clean. The relay's copy must agree.
## Still argued, not played: `SharedFight.CREW_SHARE` is linear with no ceiling and flown at two.
## Why: docs/why/NetTransport.md#max-players
const MAX_PLAYERS: int = 8


## Joining never asks the kind: `LobbyCode` tells a room
## from an address, and a wrong guess fails vaguely.
## Why: docs/why/NetTransport.md#transport-from-code
static func for_code(code: String) -> NetTransport:
	var parsed := LobbyCode.parse(code)
	if parsed.kind == LobbyCode.Kind.ROOM:
		return RelayTransport.new()
	return DirectTransport.new()


func kind() -> Kind:
	return Kind.DIRECT


## Human name for an error message, never for a comparison.
func label() -> String:
	return "direct"


## Open a session: a live MultiplayerPeer, or null with last_error(). The transport fills `code`.
func create_host() -> MultiplayerPeer:
	return null


## Join a session named by a lobby code.
func create_client(_code: String) -> MultiplayerPeer:
	return null


## Set by create_host(). Empty until then.
var code: String = ""

var _error: String = ""

func last_error() -> String:
	return _error


func _fail(message: String) -> MultiplayerPeer:
	_error = message
	return null


## DIRECT cannot promise this and says so, which is honest to tell a host before reading a code out.
func is_traversal_free() -> bool:
	return false
