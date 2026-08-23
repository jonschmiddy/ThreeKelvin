class_name SharedFight
extends RefCounted

## One fight that more than one ship is in.
##
## This is the enemy, and only the enemy. Everything on YOUR side of a shared
## fight — deck, hand, energy, block, brace, heat, hull — stays in `Run` and
## `Combat` on your own machine and never crosses the wire, because it never
## has to: no other player targets it, spends it or reads it. That asymmetry is
## the whole reason joint combat is a small feature rather than a rewrite. The
## contested object in a fight is the thing being shot at, so the contested
## object is the only thing the host owns.
##
## Host-authoritative and pushed whole, for the same reason `NetSession.claims`
## is: a fight is tens of numbers, not thousands, and a list rebuilt from
## scratch cannot drift the way an append-only stream of deltas can the first
## time one arrives twice.
##
## Nothing here touches `Run`, `Combat`, `Rng` or a screen. It is rules and a
## wire format, which is what makes it testable without four machines.

## What each extra ship adds to the enemy, as a fraction of what it was worth
## alone.
##
## Not 1.0. Three ships on one frigate is three hands of cards against one
## intent, so a frigate scaled linearly would be easier than the solo fight, not
## harder — the party's action economy grows faster than its exposure. 0.6 is
## the same number `Combat.start()` already uses to split a pack's health, which
## is the same problem seen from the other side: more hulls in a fight are worth
## less than the sum of them.
const CREW_SHARE: float = 0.6

## Where the intent came from. `Combat._spawn` scales a private copy of both
## lists, identically on every machine, so an index into them is a name the
## whole party already agrees on and no intent has to be sent by value.
## ESCAPE is the miniboss spooling its way out of the fight — an intent that
## exists in no template list, so it travels as a kind rather than an index.
## Every machine builds the same card from it: Combat.escape_intent().
enum Pick { LOOP, POOL, ESCAPE }

class Foe extends RefCounted:
	var hp: int = 1
	var max_hp: int = 1
	## What one ship's worth of this enemy is. A joiner adds CREW_SHARE of it.
	var base: int = 1
	var brace: int = 0
	var block: int = 0
	var kind: int = Pick.LOOP
	var pick: int = 0
	## Where it is in its fixed rotation, for the enemies that have one.
	var step: int = 0

	func alive() -> bool:
		return hp > 0

## Which system this fight is at. A fight is a thing that happens somewhere, and
## the node index is the only name for a place that every machine already
## agrees on.
var at: int = -1
## What is being fought, by database id. Carried on the fight rather than
## re-derived from the node, so a ship that arrives mid-fight learns what it has
## joined from the fight itself. An ambush is not written on the node it
## happened at, and the GOAL node's custodian is not in `foes` at all, so the
## node is not a reliable name for what is actually in the room.
var foe_ids: PackedStringArray = PackedStringArray()
var foes: Array[Foe] = []
## Who is in it, in the order they arrived. The opener is first.
var crew: PackedInt32Array = PackedInt32Array()
## Who has pressed END TURN and is waiting on everybody else.
var ended: PackedInt32Array = PackedInt32Array()
var turn: int = 1
var over: bool = false
## Over because the enemy LEFT, not because anybody won or walked out. The
## distinction decides what every crew machine does next: a broke fight pays
## nothing and consumes nothing, and the stoker's hull was written back by the
## host before this was pushed. See NetSession._swing().
var broke: bool = false
## The last hit anybody landed: `[peer, foe index, total, serial]`, or empty.
##
## Carried so a partner's shot can be DRAWN. Your own hits you already saw —
## you played the card — so this exists to give the other three machines the
## damage number and the hull flash they would otherwise have no way to know
## about. Read once, on arrival, and never used as state.
##
## The serial is what makes "once" mean once. Every push carries the last hit,
## including the pushes that are about something else entirely — somebody
## joining, the turn advancing — so a reader comparing the VALUE would redraw an
## old shot every time the fight moved, and two identical hits in a row would
## draw as one. A counter has neither problem.
var last_hit: PackedInt32Array = PackedInt32Array()
var hit_serial: int = 0
## How many ships were still in it when the last hull came apart.
##
## The size of the bag, and it is a FROZEN NUMBER rather than `crew.size()` read
## at the moment of payment. Winning makes every ship call `Combat._finish()`,
## which calls `leave()`, so the crew list starts emptying on the same frame the
## fight ends — and each machine would read it at whatever point its own copy had
## reached. Two ships would then disagree about how many parts are floating out
## there, which is worse than either answer: the bag is a shared object, so its
## SIZE has to be a fact the host states once.
##
## Zero until something dies, so a fight that ends any other way pays no bag.
var paid: int = 0


## The first ship engages. `hp` and `brace` are what its own `Combat._spawn`
## produced, so the danger scaling and the pack split stay in one place.
## `cur` is current hull — below `hp` only when the enemy arrives already hurt,
## the stoker carrying a previous engagement's damage. `base` stays what one
## ship's worth of the FULL enemy is, so a joiner's share does not shrink just
## because somebody softened it up first.
static func open(node_index: int, ids: PackedStringArray, hp: PackedInt32Array,
		brace: PackedInt32Array, cur: PackedInt32Array, first: int) -> SharedFight:
	var f := SharedFight.new()
	f.at = node_index
	f.foe_ids = ids
	for i in hp.size():
		var e := Foe.new()
		e.max_hp = maxi(1, hp[i])
		e.hp = clampi(cur[i] if i < cur.size() else e.max_hp, 1, e.max_hp)
		e.base = e.max_hp
		e.brace = brace[i] if i < brace.size() else 0
		f.foes.append(e)
	f.crew.append(first)
	return f


## Another ship arrives at a system somebody is already fighting in.
##
## The enemy grows to meet them, hp AND max_hp together, so the bar stays
## honest and a fight that is half over does not suddenly read as full. Growing
## a wounded enemy is deliberate: joining a fight late is help, and help that
## arrives at 10% health should not be worth the same share of the loot as help
## that was there from the first turn. It is, and this is the price.
func join(peer: int) -> bool:
	if peer == 0 or over or crew.has(peer):
		return false
	crew.append(peer)
	for e in foes:
		if not e.alive():
			continue
		var add := maxi(1, int(round(e.base * CREW_SHARE)))
		e.max_hp += add
		e.hp += add
	return true


## Somebody died, fled, disconnected, or won and walked away.
##
## The enemy does NOT shrink back. A ship that breaks contact leaves the rest of
## the party holding a frigate scaled for four, which is the honest consequence
## of the thing it just did — and `Combat.flee()` already charges six fuel for
## it, so the game has never pretended disengaging was free.
##
## What must happen is the barrier releasing. A crew list that still holds
## somebody who is never pressing END TURN again is a fight that never takes
## another turn, so leaving is the one part of this that is not optional.
func leave(peer: int) -> void:
	var i := crew.find(peer)
	if i >= 0:
		crew.remove_at(i)
	var j := ended.find(peer)
	if j >= 0:
		ended.remove_at(j)
	if crew.is_empty():
		over = true


## Apply one attack. Mirrors `Combat.damage_enemy`'s mitigation exactly — block
## first, then brace, per hit — because the client ran that maths a moment ago
## to draw the number, and two answers to "how much did that do" is a hull bar
## that disagrees with the combat log.
func hurt(which: int, amount: int, hits: int, by: int) -> int:
	if over or which < 0 or which >= foes.size():
		return 0
	var e := foes[which]
	if not e.alive():
		return 0
	var total := 0
	for i in maxi(1, hits):
		var d := amount
		if e.block > 0:
			var a := mini(e.block, d)
			e.block -= a
			d -= a
		if d > 0 and e.brace > 0:
			var a2 := mini(e.brace, d)
			e.brace -= a2
			d -= a2
		e.hp -= d
		total += d
	if e.hp <= 0:
		e.hp = 0
	hit_serial += 1
	last_hit = PackedInt32Array([by, which, total, hit_serial])
	if alive().is_empty():
		over = true
		# Stamped HERE and nowhere else. `leave()` also sets `over` — that is a
		# fight everybody walked out of, and nobody is owed a bag for it.
		paid = crew.size()
	return total


## One ship is done for the turn. True when that was the last one and the enemy
## may now act.
##
## THE BARRIER IS ONLY HERE. Nothing gates the start of a turn — everybody draws
## and plays at their own pace, immediately, exactly as they do alone. What
## cannot happen concurrently is the enemy swinging, because that is the one
## moment a shared object acts on several private ones at once. So the fight is
## free-running everywhere except the seam where it cannot be, which is
## `docs/coop-design.md` §5's "do not gate the tick" applied one level down.
func end_turn(peer: int) -> bool:
	if over or not crew.has(peer):
		return false
	if not ended.has(peer):
		ended.append(peer)
	return waiting_on().is_empty()


## Who the fight is still waiting for.
func waiting_on() -> PackedInt32Array:
	var out := PackedInt32Array()
	for p in crew:
		if not ended.has(p):
			out.append(p)
	return out


## The enemy has swung. Clear block, take the next intent, open a new turn.
func advance() -> void:
	if over:
		return
	for e in foes:
		e.block = 0
	ended = PackedInt32Array()
	turn += 1


func alive() -> Array[int]:
	var out: Array[int] = []
	for i in foes.size():
		if foes[i].alive():
			out.append(i)
	return out


func to_wire() -> Dictionary:
	var rows: Array = []
	for e in foes:
		rows.append([e.hp, e.max_hp, e.base, e.brace, e.block, e.kind, e.pick, e.step])
	return {
		"at": at, "turn": turn, "over": over, "broke": broke, "ids": foe_ids,
		"crew": crew, "ended": ended, "foes": rows,
		"hit": last_hit, "serial": hit_serial, "paid": paid,
	}


## Everything read here came off a socket, so everything read here is checked.
## The renderer indexes `foes` against a locally spawned enemy list, and a row
## count that disagrees is a fight drawn against the wrong hulls.
static func from_wire(d: Dictionary) -> SharedFight:
	var f := SharedFight.new()
	f.at = int(d.get("at", -1))
	f.turn = maxi(1, int(d.get("turn", 1)))
	f.over = bool(d.get("over", false))
	f.broke = bool(d.get("broke", false))
	f.crew = PackedInt32Array(d.get("crew", PackedInt32Array()))
	f.ended = PackedInt32Array(d.get("ended", PackedInt32Array()))
	f.last_hit = PackedInt32Array(d.get("hit", PackedInt32Array()))
	f.hit_serial = maxi(0, int(d.get("serial", 0)))
	# Clamped to the party ceiling rather than trusted. It multiplies a loot
	# roll, so a bad number here is not a wrong drawing, it is an arbitrary pile
	# of modules — the one field on this wire that can print money.
	f.paid = clampi(int(d.get("paid", 0)), 0, NetTransport.MAX_PLAYERS)
	f.foe_ids = PackedStringArray(d.get("ids", PackedStringArray()))
	var rows: Array = d.get("foes", [])
	for row in rows:
		if typeof(row) != TYPE_ARRAY or (row as Array).size() < 8:
			continue
		var e := Foe.new()
		e.hp = maxi(0, int(row[0]))
		e.max_hp = maxi(1, int(row[1]))
		e.base = maxi(1, int(row[2]))
		e.brace = maxi(0, int(row[3]))
		e.block = maxi(0, int(row[4]))
		e.kind = clampi(int(row[5]), 0, 2)
		e.pick = maxi(0, int(row[6]))
		e.step = maxi(0, int(row[7]))
		f.foes.append(e)
	return f
