class_name ContractData
extends RefCounted

## @guarded-by SaveGame.VERSION
## Part of the save format. Contracts never expire, refusing is free, and they name a place only.
## Why: docs/why/ContractData.md#contract-rules

enum Kind {
	## Something was left somewhere. Go and get it, bring it back.
	FETCH,
	## Something is out there. Kill it, come and say so.
	HUNT,
	## Arrive at one of their berths still carrying heat. See `amount`.
	HEAT,
}

enum State {
	## On the board at a station, not yours.
	OFFERED,
	## Yours, and not done.
	TAKEN,
	## Done out there. Walk into any of their berths to be paid.
	READY,
	## Paid.
	CLOSED,
}

## Assigned on acceptance, as an untaken contract needs no identity.
var id: int = 0
## Who is paying. Never empty. A station with no berth posts for its dock desk
## (`Contracts.dock_desk`), so the money still has a manufacturer behind it.
var manufacturer: StringName = &""
var kind: Kind = Kind.FETCH
var state: State = State.OFFERED

## Where the work is, as a node index. -1 for HEAT, which happens wherever you
## are standing when you walk in hot.
var at: int = -1
## The node the offer was posted at. Kept so a taken contract can still say where
## it came from after you have flown four systems away.
var posted_at: int = -1

## What it pays, in credits. The human economy — see `docs/lore.md` §1. Heat is
## what the manufacturers are buying; credits are what they pay a person in.
var pay: int = 0
## What it adds to your standing with this manufacturer on delivery. See
## `RunState.standing`.
var standing: int = 1
## For HEAT: how much heat has to be on the hull when you dock.
var amount: int = 0

## Written at generation, as it names a real system and a template would need the map again.
var text: String = ""
## What was left out there, for FETCH. A name only — see Contracts.recover().
var item: String = ""


## Delivery is to the manufacturer, not the posting desk, as the map may offer no route home.
static func berth_of(n: MapGen.MapNode, manufacturer: StringName) -> bool:
	if n == null or manufacturer == &"" or n.type != MapGen.NodeType.STATION:
		return false
	# A DOCK DESK TAKES DELIVERY TOO (Jon, Nov 3): a station with no berth posts
	# work for one manufacturer, and the work goes back to it there.
	return n.manufacturer == manufacturer or n.berths.has(manufacturer) \
		or Contracts.dock_desk(n) == manufacturer


## One line for the ledger. Deliberately says the STATE first: a player checking
## their contracts is asking "what can I close", not "what did I agree to".
func status_line() -> String:
	# What comes from the kind, where from the state: heat said 'somewhere out there'.
	# Why: docs/why/ContractData.md#status-line
	var who := DB.short_name(DB.manufacturer_name(manufacturer))
	if state == State.CLOSED:
		return "Closed."
	if state == State.READY:
		return "Ready to deliver at any %s yard." % who
	if kind == Kind.HEAT:
		return "Dock at any %s yard carrying %d heat." % [who, amount]
	return _where() if state == State.OFFERED else "Open: %s" % _where()


func _where() -> String:
	if at < 0 or Run.map.is_empty() or at >= Run.map.size():
		return "somewhere out there"
	var n: MapGen.MapNode = Run.map[at]
	# Counted from one, as the chart does; the raw `n.layer` sent readers one layer short.
	return "%s · layer %d" % [MapGen.star_name(n), n.layer + 1]


func to_wire() -> Dictionary:
	return {
		"id": id, "manufacturer": String(manufacturer), "kind": int(kind), "state": int(state),
		"at": at, "posted_at": posted_at, "pay": pay, "standing": standing,
		"amount": amount, "text": text, "item": item,
	}


static func from_wire(d: Dictionary) -> ContractData:
	var c := ContractData.new()
	c.id = int(d.get("id", 0))
	c.manufacturer = StringName(d.get("manufacturer", ""))
	c.kind = clampi(int(d.get("kind", 0)), 0, Kind.size() - 1) as Kind
	c.state = clampi(int(d.get("state", 0)), 0, State.size() - 1) as State
	c.at = int(d.get("at", -1))
	c.posted_at = int(d.get("posted_at", -1))
	c.pay = maxi(0, int(d.get("pay", 0)))
	c.standing = maxi(0, int(d.get("standing", 0)))
	c.amount = maxi(0, int(d.get("amount", 0)))
	c.text = String(d.get("text", ""))
	c.item = String(d.get("item", ""))
	return c
