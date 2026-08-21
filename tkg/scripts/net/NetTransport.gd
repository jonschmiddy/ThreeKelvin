class_name NetTransport
extends RefCounted

## How four machines are joined. Nothing above this line knows or cares.
##
## There are only three real answers to "how do a host and three friends find
## each other across the internet", and they differ in what they need from the
## world, not in what the game does with them:
##
##   DIRECT    ENet straight at the host's address. Needs a forwarded port or
##             an open NAT. Costs nothing and depends on nobody. Works today.
##   ROOM      A rendezvous service hands out room numbers and either punches a
##             hole between the peers or relays the traffic itself. Needs a
##             machine that is always up, and a bill.
##   PLATFORM  Steam, or Epic. The platform is the rendezvous service and the
##             relay, at no cost, for players who own the game on it.
##
## This class exists so that choosing between them stays a one-line decision
## for as long as possible. NetSession never names a transport; it asks for a
## peer and gets one. The lobby code is the seam: every transport can produce a
## string and consume the same string, and that is the whole contract.
##
## The interface is deliberately thin. Godot's MultiplayerPeer is already the
## abstraction for moving packets — re-wrapping it would buy nothing. What
## Godot does NOT abstract is the part before the packets: finding the host.
## That is the only thing this adds.

enum Kind { DIRECT, ROOM, PLATFORM }

## How many ships one galaxy holds. The number lives here rather than in
## NetSession because a platform transport gets it from the lobby it created,
## and would otherwise have two of them to keep in step.
##
## IT IS ALSO IN `relay/src/index.js`, and the two must agree. Both ends police
## the door independently — the relay denies with "The party is full." and
## `NetSession._hello` refuses at `roster.size() >= MAX_PLAYERS` — so a mismatch
## is a player the relay lets in that the host then turns away, which reads to
## them as a random disconnect. Raise both or neither.
##
## EIGHT, RAISED FROM FOUR AND FLOWN BEFORE IT WAS RAISED. `tools/coplay.sh 6`
## put six windows in one party on one code: six ships readied, one seed, the
## same 161-system galaxy on every machine, and no errors in any of the six
## logs. Nothing in the session layer had an opinion — the seed is one integer
## however many receive it, seat salting is `_mix(base, seat)` for any seat, and
## claims, the bag and `SharedFight.crew` are lists that simply got longer.
##
## What did have an opinion was the interface, twice, and both are fixed rather
## than tolerated: the lobby roster had no scroll and pushed READY and LAUNCH
## DIVE off a 540px viewport at about six ships, and the convoy strip is a
## fixed-height column measured for three partners. See LobbyScreen._build_party
## and EncounterView.CONVOY_MAX.
##
## What is still only argued: `SharedFight.CREW_SHARE` is linear with no ceiling
## and has been flown at two. An eight-ship custodian is 120 + 7x72 hull against
## eight hands of cards, and nobody has played that. The cap allows it; the
## tuning has not been done.
const MAX_PLAYERS: int = 8


## The transport a code belongs to, from the code itself.
##
## Joining should never ask which kind of party this is. `LobbyCode` already
## tells a room number from an address by its first character, so the answer is
## in the player's hand before they press anything — and a wrong choice here
## would fail as "could not connect", which is the least useful sentence in
## networking.
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


## Open a session. Returns a live MultiplayerPeer, or null on failure with
## last_error() set. `code` is filled in by the transport and is what the host
## reads out.
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


## True when the transport can carry a session without the players doing
## anything to their routers. DIRECT cannot promise this and says so, which is
## the honest thing to put in front of a host before they read a code out.
func is_traversal_free() -> bool:
	return false
