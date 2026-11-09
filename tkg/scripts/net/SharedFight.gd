class_name SharedFight
extends RefCounted

## @guarded-by NetSession.PROTOCOL
## Wire format: a renamed or added key in `to_wire` or `from_wire` is a protocol change.
## Only the enemy crosses the wire, host-authoritative and pushed whole so it cannot drift.
## Why: docs/why/SharedFight.md#shared-fight-overview

## Nothing grows when a ship walks in (Jon, Nov 5): the enemy is built for the game's players.
## Why: docs/why/SharedFight.md#party-size
## The highest count `grown` may say (a wire value is clamped to it).
const MAX_GROWN: int = 9999

## An index into the identically scaled lists is a name the whole party agrees on.
## ESCAPE is in no template list, so it travels as a kind and `Combat.escape_intent()` rebuilds it.
## Why: docs/why/SharedFight.md#intent-pick
enum Pick { LOOP, POOL, ESCAPE }

class Foe extends RefCounted:
	var hp: int = 1
	var max_hp: int = 1
	## This enemy's hull before growth (`regrow` scales the hull by the
	## Custodian's count against it). A joiner adds nothing to it.
	var base: int = 1
	var brace: int = 0
	var block: int = 0
	var kind: int = Pick.LOOP
	var pick: int = 0
	## Where it is in its fixed rotation, for the enemies that have one.
	var step: int = 0

	func alive() -> bool:
		return hp > 0

## The node index is the only name for a place that every machine already agrees on.
var at: int = -1
## Carried on the fight, not re-derived from the node: an ambush or the core custodian is not on it.
var foe_ids: PackedStringArray = PackedStringArray()
var foes: Array[Foe] = []
## Who is in it, in the order they arrived. The opener is first.
var crew: PackedInt32Array = PackedInt32Array()
## Who has pressed END TURN and is waiting on everybody else. A stunned ship
## is in here from its join, so the turn never waits on it.
var ended: PackedInt32Array = PackedInt32Array()
## Who is stunned: joined after turn 1, sitting out that turn and its enemy turn (Jon, Nov 5).
## Cleared by `advance`. Turn 1 never stuns.
## Why: docs/why/SharedFight.md#stunned
var stunned: PackedInt32Array = PackedInt32Array()
var turn: int = 1
var over: bool = false
## Over because the enemy left, not won: a broke fight pays and consumes nothing.
var broke: bool = false
## Carried so a partner's shot can be drawn; the serial makes 'once' mean once.
## Every push carries it, so comparing the value would redraw old shots and merge identical ones.
## Why: docs/why/SharedFight.md#last-hit
var last_hit: PackedInt32Array = PackedInt32Array()
var hit_serial: int = 0
## A frozen number, not `crew.size()`: `leave()` empties the crew list as the fight ends.
## The bag's size is a fact the host states once, or machines disagree on the pile.
## Why: docs/why/SharedFight.md#paid-count
var paid: int = 0
## The count the hull was grown at (PROTOCOL 16), -1 if nothing grows; the host raises it.
## So the boss in the fight is the boss the badge shows.
## Why: docs/why/SharedFight.md#grown-count
var grown: int = -1
## THE PLAYERS IN THE GAME THIS FIGHT WAS BUILT FOR (`PartyScale`, PROTOCOL
## 18): the host's count as it opened. Its hull was built for them and its
## wrecks pay for them. A player who drops or joins mid-fight changes nothing
## here; the next fight takes the new count.
var party: int = 1


## `hp` and `brace` come from the opener's own `Combat._spawn`, keeping the scaling in one place.
## `base` stays one ship's worth of the full enemy, so a joiner's share ignores earlier damage.
## `players` is the game's count the hull was built for (`PartyScale`).
## Why: docs/why/SharedFight.md#opening
static func open(node_index: int, ids: PackedStringArray, hp: PackedInt32Array,
		brace: PackedInt32Array, cur: PackedInt32Array, first: int, grown_at: int = -1,
		players: int = 1) -> SharedFight:
	var f := SharedFight.new()
	f.at = node_index
	f.foe_ids = ids
	f.grown = clampi(grown_at, -1, MAX_GROWN)
	f.party = clampi(players, 1, NetTransport.MAX_PLAYERS)
	for i in hp.size():
		var e := Foe.new()
		e.max_hp = maxi(1, hp[i])
		e.hp = clampi(cur[i] if i < cur.size() else e.max_hp, 1, e.max_hp)
		e.base = e.max_hp
		e.brace = brace[i] if i < brace.size() else 0
		f.foes.append(e)
	f.crew.append(first)
	return f


## The enemy does not grow: it was built for every player in the game (`party`).
## Past turn one the joiner is STUNNED and counted as ended. True when it is seated.
## Why: docs/why/SharedFight.md#joining
func join(peer: int) -> bool:
	if peer == 0 or over or crew.has(peer):
		return false
	crew.append(peer)
	if turn > 1:
		stunned.append(peer)
		if not ended.has(peer):
			ended.append(peer)
	return true


## The enemy does not shrink back; `Combat.flee()` already charges six fuel.
## The barrier must release, or a crew holding a gone ship never takes another turn.
## Why: docs/why/SharedFight.md#leaving
func leave(peer: int) -> void:
	var i := crew.find(peer)
	if i >= 0:
		crew.remove_at(i)
	var j := ended.find(peer)
	if j >= 0:
		ended.remove_at(j)
	var k := stunned.find(peer)
	if k >= 0:
		stunned.remove_at(k)
	if crew.is_empty():
		over = true


## Mirrors `Combat.damage_enemy`'s mitigation, or the hull bar disagrees with the log.
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


## The barrier is only here: turns start free, as when alone; only the enemy's swing is gated.
## That is coop-design.md section 5, do not gate the tick, applied one level down.
## Why: docs/why/SharedFight.md#turn-barrier
func end_turn(peer: int) -> bool:
	if over or not crew.has(peer) or stunned.has(peer):
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
	stunned = PackedInt32Array()
	turn += 1


## The lead ship jumped past the fight's count (Jon, Nov 4): growing foes scale by ratio.
## Scaling max_hp keeps the party's share in proportion. True only if a hull moved, so no false log line.
## Why: docs/why/SharedFight.md#regrow
func regrow(to: int, ratio: PackedFloat32Array) -> bool:
	if over or grown < 0 or to <= grown:
		return false
	grown = mini(to, MAX_GROWN)
	var moved := false
	for i in mini(foes.size(), ratio.size()):
		var e := foes[i]
		var r := float(ratio[i])
		if r <= 0.0 or is_equal_approx(r, 1.0) or not e.alive():
			continue
		var top := maxi(1, int(round(e.max_hp * r)))
		if top == e.max_hp:
			continue
		e.hp = clampi(e.hp + top - e.max_hp, 1, top)
		e.max_hp = top
		e.base = maxi(1, int(round(e.base * r)))
		moved = true
	return moved


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
		"hit": last_hit, "serial": hit_serial, "paid": paid, "grown": grown,
		"stun": stunned, "party": party,
	}


## Everything read came off a socket, so it is checked: a wrong row count draws the wrong hulls.
static func from_wire(d: Dictionary) -> SharedFight:
	var f := SharedFight.new()
	f.at = int(d.get("at", -1))
	f.turn = maxi(1, int(d.get("turn", 1)))
	f.over = bool(d.get("over", false))
	f.broke = bool(d.get("broke", false))
	f.crew = PackedInt32Array(d.get("crew", PackedInt32Array()))
	f.ended = PackedInt32Array(d.get("ended", PackedInt32Array()))
	# Only ships in the crew can be stunned: a stranger here would be a ship
	# the turn skips that is not in the fight at all.
	for p in PackedInt32Array(d.get("stun", PackedInt32Array())):
		if f.crew.has(p) and not f.stunned.has(p):
			f.stunned.append(p)
	# Missing reads as one player, a wild one is held to the party's ceiling:
	# it multiplies a hull and a pay.
	f.party = clampi(int(d.get("party", 1)), 1, NetTransport.MAX_PLAYERS)
	f.last_hit = PackedInt32Array(d.get("hit", PackedInt32Array()))
	f.hit_serial = maxi(0, int(d.get("serial", 0)))
	# Clamped to the party ceiling: `paid` multiplies a loot roll, so a bad value prints modules.
	f.paid = clampi(int(d.get("paid", 0)), 0, NetTransport.MAX_PLAYERS)
	# Missing reads as nothing grown; a wild one is held to a count a run can
	# reach, since it is only ever compared and fed to `hull_at`.
	f.grown = clampi(int(d.get("grown", -1)), -1, MAX_GROWN)
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
