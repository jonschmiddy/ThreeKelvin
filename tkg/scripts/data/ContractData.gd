class_name ContractData
extends RefCounted

## One piece of work a manufacturer has posted at a station.
##
## `docs/lore.md` §6 specified these as "an offer to take delivery, not a quest —
## no objectives, no waypoints". That line is AMENDED rather than broken, and the
## amendment is worth stating because the reasoning behind the original still
## holds: what §6 was protecting is the third pillar, *greed is the clock, deaths
## are self-authored*. A contract that expires, or that pushes you deeper on
## somebody else's schedule, replaces a death you chose with one that was imposed.
##
## A waypoint does none of that so long as three things stay true, and they are
## the design of this class rather than notes about it:
##
## **Nothing expires.** There is no clock on a contract and there never will be.
## It sits in your ledger until you deliver it or die holding it.
## **Refusing is free and normal.** Most offers should be declined. An offer you
## always take is a tax with extra steps.
## **It names a place, it does not send you there.** The pay is set against the
## trip, so a contract to somewhere you were not going is priced like one — and
## going anyway because the money is good is a greedy decision, which is the
## correct kind.

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

## Unique within a run, and the id everything else refers to. Assigned from
## `RunState.next_contract_id` on acceptance rather than at generation, because a
## contract nobody has taken does not need to be told apart from anything.
var id: int = 0
## Who is paying. Never empty — an unbranded station posts no work, because the
## whole point is that the money has a manufacturer behind it.
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

## The ask, in the manufacturer's own voice. Written at generation because it names a
## real system on a real map and a template rendered at display time would have
## to be handed the map again.
var text: String = ""
## What was left out there, for FETCH. A name only — see Contracts.recover().
var item: String = ""


## Whether this station is one of the issuing manufacturer's berths.
##
## Delivery is to the MANUFACTURER, not to the desk that posted it. A contract you can
## only close where you took it is a contract that sends you backwards, and the
## map does not guarantee a route home.
static func berth_of(n: MapGen.MapNode, manufacturer: StringName) -> bool:
	if n == null or manufacturer == &"" or n.type != MapGen.NodeType.STATION:
		return false
	return n.manufacturer == manufacturer or n.berths.has(manufacturer)


## One line for the ledger. Deliberately says the STATE first: a player checking
## their contracts is asking "what can I close", not "what did I agree to".
func status_line() -> String:
	# The WHAT comes from the kind and the WHERE from the state, so a heat
	# contract — which has no target node and never will — is never asked to
	# describe a place. It used to fall through to _where() and answer
	# "somewhere out there" on the board, which is a heat contract describing
	# itself as a fetch.
	var who := DB.short_name(DB.manufacturer_name(manufacturer))
	if state == State.CLOSED:
		return "Closed."
	if state == State.READY:
		return "Ready to deliver at any %s berth." % who
	if kind == Kind.HEAT:
		return "Dock at any %s berth carrying %d heat." % [who, amount]
	return _where() if state == State.OFFERED else "Open — %s" % _where()


func _where() -> String:
	if at < 0 or Run.map.is_empty() or at >= Run.map.size():
		return "somewhere out there"
	var n: MapGen.MapNode = Run.map[at]
	return "%s · layer %d" % [MapGen.star_name(n), n.layer]


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
