class_name QuestLog
extends RefCounted

## THE QUESTS YOU HOLD (Jon, Oct 22, design A of the quest log, after Kevin's
## playtest: "I needed a quest menu or some type of quest [log]"). The HUD's
## QUESTS tab opens them as a table (`QuestPanel`), and a row's SHOW ON STARCHART
## and PLOT ROUTE open the chart on the quest's place, tagged with its number
## (`StarchartScreen.MapChart.place_quest_tags`), with its route from YOU.
##
## A QUEST IS A SIGNED CONTRACT, `Run.contracts` less the closed ones, in the
## order you signed them; AND AN EVENT QUEST (Jon, Oct 22: an event that plants
## a follow-up "is essentially a quest"), an option an event put on a system
## ahead (`OptionTable.place`) and not taken yet, in the order placed. Nothing
## here is saved: every line is read off the contract, the map and the run's
## record of who placed what (`Run.event_quests`) when asked. Only this ship's
## own -- `Run` is one ship, so a co-op partner's quests are on their machine
## and never on yours.
##
## FINISHED ONES STAY (Jon, Oct 22: "quests shouldn't vanish when they're
## done"): `done_entries`, a contract delivered and an event quest taken,
## newest first, with what each paid, for the table's COMPLETED rows.
##
## The words are the chart's: QUEST, as its tags and the sector map's key say,
## while the board and its notes keep their own (SIGN, DELIVER).

## The kind's mark, 5x5, each pixel drawn 2x2: a fetch wears the sector map's
## QUEST cross (the pickup it puts there carries it), a hunt the map's FIGHT
## mark, a heat job a little stack of heat.
const MARK := {
	# an event quest wears the chart's own mark for one, the gold box
	EVENT: ["#####", "#...#", "#...#", "#...#", "#####"],
	ContractData.Kind.FETCH: ["..#..", "..#..", "#####", "..#..", "..#.."],
	ContractData.Kind.HUNT: ["..#..", ".#.#.", "#...#", ".#.#.", "..#.."],
	ContractData.Kind.HEAT: ["..#..", ".###.", ".###.", "#####", "#####"],
}

## The chart's word for each kind of place a tag marks.
const TAG_WORD := {
	ContractData.Kind.FETCH: "PICK UP",
	ContractData.Kind.HUNT: "TARGET",
	ContractData.Kind.HEAT: "HEAT",
}

const EMPTY := "No quests. Sign one at a station's hiring board."

## An event quest's kind, beside `ContractData.Kind`'s.
const EVENT := 100
## An event quest's id in the table and on the chart: this plus its system's
## index (one quest a system, `OptionTable.place`), clear of contract ids.
const EVENT_ID := 1 << 24
## What an open event quest pays, in the PAY column: it names no number until
## it is taken.
const ON_ARRIVAL := "ON ARRIVAL"


static func mark_colour(kind: int) -> Color:
	match kind:
		EVENT:
			return EncounterDrawer.TAG_QUEST
		ContractData.Kind.FETCH:
			return EncounterDrawer.TAG_QUEST
		ContractData.Kind.HUNT:
			return UITheme.LEAVE
	return UITheme.EMBER


## Draw a kind's mark at `at` (its top left), 10 px square.
static func draw_mark(ci: CanvasItem, kind: int, at: Vector2) -> void:
	var rows: Array = MARK.get(kind, [])
	var ink := mark_colour(kind)
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			if r[x] == "#":
				ci.draw_rect(Rect2(at + Vector2(x * 2, y * 2), Vector2(2, 2)), ink)


# --- how far, by jumps -------------------------------------------------------

## JUMPS FROM YOU, by the chart's own reach rule (`RunState.reachable_from`),
## found once per place and ship and kept: the walk asks the rule of every pair
## it meets, and the panel asks on every refresh.
static var _key := ""
static var _dist: Dictionary = {}
static var _back: Dictionary = {}


static func _walk() -> void:
	if Run.map.is_empty():
		_key = ""
		_dist = {}
		_back = {}
		return
	var key := "%d|%d|%d|%.4f" % [Run.galaxy_seed, Run.at, Run.map.size(), Run.jump_range()]
	if key == _key:
		return
	_key = key
	_dist = {Run.at: 0}
	_back = {Run.at: -1}
	var queue: Array[int] = [Run.at]
	while not queue.is_empty():
		var i: int = queue.pop_front()
		var a: MapGen.MapNode = Run.map[i]
		# the core ends a run: a way there, never a way through
		if a.type == MapGen.NodeType.CORE and i != Run.at:
			continue
		for raw in Run.map:
			var b: MapGen.MapNode = raw
			if _dist.has(b.index):
				continue
			if Run.reachable_from(a, b):
				_dist[b.index] = int(_dist[i]) + 1
				_back[b.index] = i
				queue.append(b.index)


## Forget the walk (a harness that moves the ship by hand, or a new map).
static func forget() -> void:
	_key = ""


## Jumps from where you are to `to`, or -1 if no chain of jumps reaches it.
static func jumps(to: int) -> int:
	_walk()
	return int(_dist.get(to, -1))


## The hops from YOU to `to`, YOU first and `to` last; empty if out of reach.
static func route(to: int) -> Array[int]:
	_walk()
	var out: Array[int] = []
	if not _back.has(to):
		return out
	var k := to
	while k != -1:
		out.push_front(k)
		k = int(_back[k])
	return out


## The yard that pays `manufacturer` fewest jumps away (nearer in the galaxy
## when two tie), or -1 if none of its yards can be reached.
static func nearest_yard(manufacturer: StringName) -> int:
	_walk()
	var here: MapGen.MapNode = Run.node_at()
	var best := -1
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if not ContractData.berth_of(n, manufacturer) or not _dist.has(n.index):
			continue
		if best < 0:
			best = n.index
			continue
		var d := int(_dist[n.index])
		var bd := int(_dist[best])
		if d < bd or (d == bd and n.gal.distance_squared_to(here.gal)
				< (Run.map[best] as MapGen.MapNode).gal.distance_squared_to(here.gal)):
			best = n.index
	return best


# --- the list ----------------------------------------------------------------

## Every open quest, numbered from 1: the signed contracts in the order you
## signed them, then the event quests in the order placed. As the table's rows
## and the chart's tags read them:
##   n, id (the contract's id, or EVENT_ID + the system's index), job (the
##   ContractData; null for an event quest), event, done, kind, what, where,
##   jumps (words), pay, pay2 (a second line under it, or ""), state,
##   state_colour, place (the system its tag stands on: the target, or for a
##   heat quest and a READY one the nearest yard that pays it; -1 if none), tag,
##   tip, note (the poster's or the event's own words), who (the poster's short
##   name, or the event's title), manufacturer (&"" for an event), yard
##   (whether `place` is the nearest of any of its yards), place_name, layer
##   ("LAYER 7", from 1), paid (what a finished one paid; "" for an open one).
static func entries() -> Array:
	var out: Array = []
	var n := 0
	for raw in Run.contracts:
		var job: ContractData = raw
		if job.state == ContractData.State.CLOSED:
			continue
		n += 1
		out.append(_entry(job, n))
	for q in _events(false):
		n += 1
		out.append(_event_entry(q, n))
	return out


## Every finished quest, newest first: a contract delivered and an event quest
## taken, in the order `Run.quests_done` wrote them; then any finished under a
## save from before it kept that order, contracts first, last signed first.
static func done_entries() -> Array:
	var by_key := {}
	for raw in Run.contracts:
		var job: ContractData = raw
		if job.state == ContractData.State.CLOSED:
			by_key["c%d" % job.id] = _entry(job, 0)
	for q in _events(true):
		by_key["e%d" % int(q.at)] = _event_entry(q, 0)
	var out: Array = []
	for i in range(Run.quests_done.size() - 1, -1, -1):
		var k: String = Run.quests_done[i]
		if by_key.has(k):
			out.append(by_key[k])
			by_key.erase(k)
	var rest: Array = by_key.values()
	rest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.event) != bool(b.event):
			return not bool(a.event)
		return int(a.id) > int(b.id))
	out.append_array(rest)
	return out


## The quest `id`, open or finished, or {}.
static func find(id: int) -> Dictionary:
	for e in entries() + done_entries():
		if int((e as Dictionary).id) == id:
			return e
	return {}


## The event quests on the map, open (`done` false) or finished: an option only
## ever placed (`OptionTable.placed_ids`) on its system, and either not taken,
## or taken with an outcome (`MapNode.results`, and not `R_GONE`). READ OFF THE
## MAP, so a save from before `Run.event_quests` still has them; the record adds
## who gave it and what it paid. In the order placed, then by system.
##   {at, slot, id, done, rec (the record, or {})}
static func _events(done: bool) -> Array:
	var out: Array = []
	var set := OptionTable.placed_ids()
	for raw in Run.map:
		var node: MapGen.MapNode = raw
		for i in node.options.size():
			if not set.has(node.options[i]):
				continue
			var taken := node.taken.has(MapGen.OPTION_SITE + i)
			var finished := taken and node.results.has(i) and StringName(node.results[i]) != MapGen.R_GONE
			if not (finished if done else not taken):
				continue
			var rec := Run.event_quest_at(node.index)
			if StringName(rec.get("id", &"")) != node.options[i]:
				rec = {}
			var k := Run.event_quests.find(rec) if not rec.is_empty() else -1
			out.append({at = node.index, slot = i, id = node.options[i], done = done, rec = rec,
				order = k if k >= 0 else 100000 + node.index})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.order) < int(b.order))
	return out


static func _entry(job: ContractData, n: int) -> Dictionary:
	var who := DB.short_name(DB.manufacturer_name(job.manufacturer))
	var item := job.item
	if item == "" or item.begins_with("a crate"):
		item = "an unmarked crate"
	var done := job.state == ContractData.State.CLOSED
	var e := {n = n, id = job.id, job = job, event = false, done = done, kind = int(job.kind),
		what = _task(job, who, item), pay = "%d CR" % job.pay, pay2 = "",
		tag = "%d %s" % [n, TAG_WORD.get(job.kind, "QUEST")], who = who,
		manufacturer = job.manufacturer, place_name = "", layer = "", note = job.text, paid = ""}
	var yard := false
	if done:
		e.state = "DONE"
		e.state_colour = UITheme.COLD
		e.tag = "DONE"
		e.pay2 = "+%d STANDING" % job.standing if job.standing > 0 else ""
		e.paid = "Paid %d credits%s." % [job.pay,
			(" and %d standing with %s" % [job.standing, who]) if job.standing > 0 else ""]
	elif job.state == ContractData.State.READY:
		e.what = "Hand in at any %s yard" % who
		e.state = "READY"
		e.state_colour = UITheme.GOOD
		e.tag = "%d HAND IN" % n
		yard = true
	elif job.kind == ContractData.Kind.HEAT:
		e.state = "%d OF %d HEAT" % [mini(Run.heat, job.amount), job.amount]
		e.state_colour = UITheme.GOOD if Run.heat >= job.amount else UITheme.WARN
		yard = true
	else:
		e.state = "SIGNED"
		e.state_colour = UITheme.ICE
	var place := nearest_yard(job.manufacturer) if yard else job.at
	# A FINISHED HEAT JOB HAS NO ONE PLACE: it was handed in at whichever yard
	# you docked at, and the run does not keep which.
	if done and job.kind == ContractData.Kind.HEAT:
		place = -1
	if place >= Run.map.size():
		place = -1
	e.place = place
	e.yard = yard
	if place < 0:
		if done:
			e.where = "ANY %s YARD" % who.to_upper()
		else:
			e.where = "NO %s YARD IN REACH" % who.to_upper() if yard else "OUT OF REACH"
		e.jumps = ""
	else:
		_where(e, place)
	var tip: String = e.what + "."
	if place >= 0:
		var p2: MapGen.MapNode = Run.map[place]
		if yard:
			tip += "\nAny %s yard. Nearest: %s, layer %d, %s." % [who, MapGen.star_name(p2), p2.layer + 1, String(e.jumps).to_lower()]
		else:
			tip += "\n%s, layer %d, %s." % [MapGen.star_name(p2), p2.layer + 1, String(e.jumps).to_lower()]
	if done:
		tip += "\n%s Posted by %s." % [e.paid, DB.manufacturer_name(job.manufacturer)]
	else:
		tip += "\nPays %d credits. Posted by %s." % [job.pay, DB.manufacturer_name(job.manufacturer)]
	e.tip = tip
	return e


## What a contract asks, in the table's words.
static func _task(job: ContractData, who: String, item: String) -> String:
	match job.kind:
		ContractData.Kind.FETCH:
			return "Pick up %s" % item
		ContractData.Kind.HEAT:
			return "Bring heat to any %s yard" % who
	return "Destroy the contact"


## An event quest's row: what the placed option says of itself (`quest`), who
## gave it (the record's `from`, or for a save from before the record the
## option's own `quest.from`), and once taken what it paid.
static func _event_entry(q: Dictionary, n: int) -> Dictionary:
	var opt := OptionTable.by_id(StringName(q.id))
	var words: Dictionary = opt.get("quest", {})
	var rec: Dictionary = q.rec
	var from := StringName(rec.get("from", &""))
	if from == &"":
		from = StringName(words.get("from", &""))
	var giver: Dictionary = OptionTable.by_id(from) if from != &"" else {}
	var who := String(giver.get("title", ""))
	var at := int(q.at)
	var done := bool(q.done)
	var e := {n = n, id = EVENT_ID + at, job = null, event = true, done = done, kind = EVENT,
		what = String(words.get("task", opt.get("title", ""))),
		pay = ON_ARRIVAL, pay2 = "",
		state = "MARKED", state_colour = EncounterDrawer.TAG_QUEST,
		tag = "%d %s" % [n, String(words.get("tag", "QUEST"))],
		who = who, manufacturer = &"", yard = false, place = at,
		place_name = "", layer = "", paid = "",
		note = String(words.get("note", giver.get("body", "")))}
	_where(e, at)
	var p: MapGen.MapNode = Run.map[at]
	var tip: String = "%s.\n%s, layer %d, %s." % [e.what, MapGen.star_name(p), p.layer + 1,
		String(e.jumps).to_lower()]
	if done:
		e.state = "DONE"
		e.state_colour = UITheme.COLD
		e.tag = "DONE"
		if rec.has("credits"):
			var got: Array = rec.get("got", [])
			e.pay = "%d CR" % int(rec.credits)
			if got.size() == 1:
				e.pay2 = "+1 THING"
			elif got.size() > 1:
				e.pay2 = "+%d THINGS" % got.size()
			var names: Array = got.map(func(x: Variant) -> String: return String(x).to_lower())
			e.paid = "Paid %d credits%s." % [int(rec.credits),
				"" if names.is_empty() else " and " + ", ".join(names)]
		else:
			# taken under a save from before the record: what it paid was not kept
			e.pay = ""
			e.paid = "What it paid was not kept."
		tip += "\n" + e.paid
	else:
		tip += "\nPays on arrival."
	if who != "":
		tip += " %s gave it to you." % who
	e.tip = tip
	return e


## The where and the jumps of a row whose place is one system.
static func _where(e: Dictionary, place: int) -> void:
	var p: MapGen.MapNode = Run.map[place]
	var j := jumps(place)
	e.place_name = MapGen.star_name(p)
	e.layer = "LAYER %d" % (p.layer + 1)
	# COUNTED FROM ONE, as the chart's LAYER and its COREWARD L7 count it
	e.where = "%s · L%d" % [MapGen.star_name(p), p.layer + 1]
	e.jumps = "HERE" if j == 0 else ("1 JUMP" if j == 1 else ("%d JUMPS" % j if j > 0 else "NO ROUTE"))
