class_name LobbyCode
extends RefCounted

## Defined once apart from transport: DIRECT carries the host address, ROOM a room number.
## Crockford base 32 with a check character, so a typo is refused at once, by name.
## Why: docs/why/LobbyCode.md#lobby-code

const ALPHABET: String = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

## The four letters left out above, and what a human who types them meant.
const CONFUSABLES: Dictionary = {
	"I": "1", "L": "1", "O": "0", "U": "V",
}

enum Kind { INVALID, DIRECT, ROOM }

## 25 bits is 33.5 million rooms; collisions are the rendezvous service's problem.
const ROOM_BITS: int = 25
const ROOM_MAX: int = 1 << ROOM_BITS


static func encode_direct(ip: String, port: int) -> String:
	var octets := ip.split(".")
	if octets.size() != 4:
		return ""
	var bits: Array[int] = []
	for o in octets:
		_push(bits, int(o), 8)
	_push(bits, port, 16)
	return _finish(Kind.DIRECT, bits)


static func encode_room(room: int) -> String:
	var bits: Array[int] = []
	_push(bits, room % ROOM_MAX, ROOM_BITS)
	return _finish(Kind.ROOM, bits)


## A room number nobody else is likely to be holding. The caller is expected to
## ask the rendezvous service to confirm that, and to roll again if it says no.
static func roll_room() -> int:
	return randi() % ROOM_MAX


## Returns { kind, ip, port, room, error }. `error` is empty on success and is
## written for a player to read, not for a log file.
static func parse(code: String) -> Dictionary:
	var out: Dictionary = {
		"kind": Kind.INVALID, "ip": "", "port": 0, "room": 0, "error": "",
	}
	var clean := normalise(code)
	if clean.is_empty():
		out.error = "Enter a code."
		return out

	var kind: Kind = Kind.INVALID
	match clean[0]:
		"D": kind = Kind.DIRECT
		"R": kind = Kind.ROOM
		_:
			out.error = "That is not a Three Kelvin code."
			return out

	var want := 12 if kind == Kind.DIRECT else 7
	if clean.length() != want:
		out.error = "A %s code is %d characters. That one is %d." % [
			("direct" if kind == Kind.DIRECT else "party"), want, clean.length(),
		]
		return out

	var body := clean.substr(1, clean.length() - 2)
	var check := clean[clean.length() - 1]
	var values: Array[int] = []
	for i in body.length():
		var v := ALPHABET.find(body[i])
		if v < 0:
			out.error = "The character '%s' is not part of a code." % body[i]
			return out
		values.append(v)
	if _check_char(clean[0], values) != check:
		out.error = "That code has a typo in it."
		return out

	var bits := _unpack(values)
	if kind == Kind.DIRECT:
		var ip := "%d.%d.%d.%d" % [
			_take(bits, 0, 8), _take(bits, 8, 8), _take(bits, 16, 8), _take(bits, 24, 8),
		]
		var port := _take(bits, 32, 16)
		if port <= 0:
			out.error = "That code carries no port."
			return out
		out.kind = kind
		out.ip = ip
		out.port = port
		return out

	out.kind = kind
	out.room = _take(bits, 0, ROOM_BITS)
	return out


## Exposed so the join field corrects as the player types, teaching that o and 0 match.
static func normalise(code: String) -> String:
	var out := ""
	for c in code.to_upper():
		if c == "-" or c == " " or c == "_":
			continue
		out += String(CONFUSABLES.get(c, c))
	return out


## Grouped for reading aloud. `pretty()` is for eyes, `normalise()` for machines: keep apart.
static func pretty(code: String) -> String:
	var clean := normalise(code)
	if clean.length() <= 4:
		return clean
	var parts: PackedStringArray = []
	var i := 0
	while i < clean.length():
		parts.append(clean.substr(i, 4))
		i += 4
	return "-".join(parts)


# --- bit plumbing ---------------------------------------------------------
# Payloads are not multiples of five bits, so spare zeros pad the end and `_unpack` pads.
# Why: docs/why/LobbyCode.md#bit-plumbing

static func _push(bits: Array[int], value: int, count: int) -> void:
	for i in range(count - 1, -1, -1):
		bits.append((value >> i) & 1)


static func _take(bits: Array[int], from: int, count: int) -> int:
	var v := 0
	for i in count:
		v = (v << 1) | (bits[from + i] if from + i < bits.size() else 0)
	return v


static func _unpack(values: Array[int]) -> Array[int]:
	var bits: Array[int] = []
	for v in values:
		_push(bits, v, 5)
	return bits


static func _finish(kind: Kind, bits: Array[int]) -> String:
	var head := "D" if kind == Kind.DIRECT else "R"
	var values: Array[int] = []
	var i := 0
	while i < bits.size():
		var v := 0
		for j in 5:
			v = (v << 1) | (bits[i + j] if i + j < bits.size() else 0)
		values.append(v)
		i += 5
	var body := ""
	for v in values:
		body += ALPHABET[v]
	return head + body + _check_char(head, values)


## The kind is folded into the checksum, or a D and R code could pass as each other.
static func _check_char(head: String, values: Array[int]) -> String:
	var sum := ALPHABET.find(head) if ALPHABET.find(head) >= 0 else 7
	for i in values.size():
		sum += values[i] * (i + 1)
	return ALPHABET[sum % 32]
