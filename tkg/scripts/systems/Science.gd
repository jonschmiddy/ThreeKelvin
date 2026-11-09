class_name Science
extends RefCounted

## THE LAB'S SERVICES (Phase 12, science; Jon's picks 1A 2B 3A, Nov 4): the board's steps,
## AUGMENT and STRIP.
## Why: docs/why/Science.md#the-labs-services

## What AUGMENT costs in DATA, beside `Market.augment_price` in credits.
const AUGMENT_DATA := 5
## What STRIP costs in DATA, beside `Market.strip_price` in credits.
const STRIP_DATA := 2
## How many affixes the Lab offers for one part.
const OFFER_SIZE := 3

# ------------------------------------------------------------------- the board

## THE BOARD AS THE SCREEN DRAWS IT: three branches, FRAME, CORE and DRIVE, each
## three cells in order. A cell is `{id, name, text, price, state}`, its state
## &"owned", &"next" (the one step that branch sells now) or &"locked" (behind
## the next). A finished branch has no &"next". An empty board (a run with
## none dealt) is three empty branches.
static func board_state() -> Array:
	var out: Array = []
	for b in DB.BRANCHES.size():
		var cells: Array = []
		var owned := clampi(Run.board_owned[b] if b < Run.board_owned.size() else 0, 0, 3)
		for k in 3:
			var i := b * 3 + k
			if i >= Run.board.size():
				break
			var id: StringName = Run.board[i]
			var r: Dictionary = DB.routines.get(id, {})
			var state := &"owned" if k < owned else (&"next" if k == owned else &"locked")
			cells.append({id = id, name = String(r.get("name", id)),
				text = String(r.get("text", "")), price = DB.BOARD_PRICES[k],
				state = state})
		out.append(cells)
	return out

## Whether branch `b`'s next step can be bought now: science on, a step left,
## and the DATA for it.
static func can_buy(b: int) -> bool:
	if Run.science_off:
		return false
	if Run.next_step(b) == &"":
		return false
	return Run.data >= Run.step_cost(b)

## Buy branch `b`'s next step. `Run.buy_step` spends the DATA, raises the
## branch and logs the line; this returns the same line, or "" on a refusal.
static func buy(b: int) -> String:
	if not can_buy(b):
		return ""
	var id := Run.next_step(b)
	if not Run.buy_step(b):
		return ""
	# (the line `Run.buy_step` wrote; keep the two in step)
	return "The Lab wrote %s into the flight computer." % DB.routines[id].name

# ---------------------------------------------------------------- AUGMENT/STRIP

## Whether this is a place with a Lab: a station, and only a station. The Lab
## is a room aboard one, so the start, a pulsar or an empty system has none,
## whatever node a caller happens to hold (`Router.at_station` asks the same).
static func lab_here(n: MapGen.MapNode) -> bool:
	return n != null and n.type == MapGen.NodeType.STATION

## Whether the part is yours to work on: fitted or in the hold. A part on the
## pad, on a shelf or floating as jetsam is not on the Lab's bench.
static func _yours(m: ModuleData) -> bool:
	return m != null and (Run.installed.has(m) or Run.cargo.has(m))

## The three affixes this Lab offers for this part.
## Why: docs/why/Science.md#the-three-affixes-this-lab-offers
static func augment_offer(m: ModuleData, n: MapGen.MapNode) -> Array[AffixData]:
	var out: Array[AffixData] = []
	if m == null or n == null:
		return out
	var names: Array[String] = []
	for a in m.affixes:
		names.append((a as AffixData).name)
	for a in _offer_order(m, n):
		if out.size() >= OFFER_SIZE:
			break
		if not names.has(a.name):
			out.append(a)
	return out

## This Lab's ranking of its affixes for this part, drawn the way loot rolls
## them (`LootGen._roll_affixes`): an even pick, with a scarce affix (Bus-Fed,
## weight 0.35) refused that often and dropped rather than tried again.
static func _offer_order(m: ModuleData, n: MapGen.MapNode) -> Array[AffixData]:
	var pool: Array[AffixData] = []
	for want in DB.LAB_AFFIXES:
		var a := _affix(want)
		if a != null:
			pool.append(a)
	var r := Rng.derive(&"augment", hash([n.index, String(m.id), m.scrap_value]))
	var order: Array[AffixData] = []
	while not pool.is_empty():
		var pick: AffixData = pool[r.randi() % pool.size()]
		pool.erase(pick)
		if pick.weight < 1.0 and r.randf() > pick.weight:
			continue
		order.append(pick)
	return order

## The affix the catalogue holds under this name, or null.
static func _affix(name: StringName) -> AffixData:
	return DB.affix_named(String(name))

## What AUGMENT costs here: DATA, and credits by the place's service index.
static func augment_cost(n: MapGen.MapNode) -> Dictionary:
	return {data = AUGMENT_DATA, credits = Market.augment_price(n)}

## Whether this part can be augmented here and now. Refused for a part the Lab
## has already augmented (once per part, ever, STRIP or no STRIP), for a part
## that is not yours, with no Lab, and when DATA or credits are short.
static func can_augment(m: ModuleData, n: MapGen.MapNode) -> bool:
	if Run.science_off or not lab_here(n) or not _yours(m) or m.augmented:
		return false
	var cost := augment_cost(n)
	return Run.data >= int(cost.data) and Run.credits >= int(cost.credits)

## Add affix `a` to part `m`.
## Why: docs/why/Science.md#add-affix-a-to-part-m
static func augment(m: ModuleData, a: AffixData, n: MapGen.MapNode) -> String:
	if a == null or not can_augment(m, n):
		return ""
	var offered := false
	for o in augment_offer(m, n):
		if o.name == a.name:
			offered = true
	if not offered:
		return ""
	var cost := augment_cost(n)
	if not Run.spend_data(int(cost.data)):
		return ""
	Run.add_credits(-int(cost.credits))
	var list: Array[AffixData] = m.affixes.duplicate()
	list.append(_affix(StringName(a.name)))
	m.affixes = list
	m.augmented = true
	var line := "The Lab put %s on %s." % [a.name, m.name]
	Run.log_line(line, &"good")
	Sig.ship_changed.emit()
	return line

## What STRIP costs here: DATA, and credits by the place's service index.
static func strip_cost(n: MapGen.MapNode) -> Dictionary:
	return {data = STRIP_DATA, credits = Market.strip_price(n)}

## Whether affix `a` can come off part `m` here and now.
## Why: docs/why/Science.md#whether-affix-a-can-come-off
static func can_strip(m: ModuleData, a: AffixData, n: MapGen.MapNode) -> bool:
	if Run.science_off or not lab_here(n) or not _yours(m) or a == null:
		return false
	var i := _index_of(m, a)
	if i < 0:
		return false
	if Run.installed.has(m) and a.raw_for(&"reactor") > 0.0 and not _powered_without(m, i):
		return false
	var cost := strip_cost(n)
	return Run.data >= int(cost.data) and Run.credits >= int(cost.credits)

## Whether the fitted parts still have the cells they draw with affix `i` off
## fitted part `m`. Asked of `Run.power_cap()` and `Run.power_draw()` with the
## affix really off for the question and put back before anything can see it,
## so no copy of the cap's arithmetic lives here: whatever else raises the cap
## (SPARE CELLS, say) counts the way the ship counts it.
static func _powered_without(m: ModuleData, i: int) -> bool:
	var keep := m.affixes
	var list: Array[AffixData] = keep.duplicate()
	list.remove_at(i)
	m.affixes = list
	var ok := Run.power_draw() <= Run.power_cap()
	m.affixes = keep
	return ok

## Where affix `a` sits on the part, by name (a loaded part's affixes are the
## catalogue's own objects, but a caller may hold a copy), or -1.
static func _index_of(m: ModuleData, a: AffixData) -> int:
	for i in m.affixes.size():
		if (m.affixes[i] as AffixData).name == a.name:
			return i
	return -1

## Take affix `a` off part `m`. The AUGMENTED mark stays. Its numbers go with
## it: STRIP of Reinforced on a fitted part takes 47/47 back to 40/40, and of
## Deregulated makes the part clean (`ModuleData.contraband` reads the list).
static func strip(m: ModuleData, a: AffixData, n: MapGen.MapNode) -> String:
	if not can_strip(m, a, n):
		return ""
	var cost := strip_cost(n)
	if not Run.spend_data(int(cost.data)):
		return ""
	Run.add_credits(-int(cost.credits))
	var list: Array[AffixData] = m.affixes.duplicate()
	list.remove_at(_index_of(m, a))
	m.affixes = list
	var line := "The Lab took %s off %s." % [a.name, m.name]
	Run.log_line(line, &"good")
	Sig.ship_changed.emit()
	return line
