class_name QuestLog
extends RefCounted

## THE QUESTS YOU HOLD (Jon, Oct 22, design A of the quest log, after Kevin's
## playtest: "I needed a quest menu or some type of quest [log]"). The HUD's
## QUESTS tab opens them as a table (`QuestPanel`), and a row's SHOW ON STARCHART
## and PLOT ROUTE open the chart on the quest's place, tagged with its number
## (`StarchartScreen.MapChart.place_quest_tags`), with its route from YOU.
##
## A QUEST IS A SIGNED CONTRACT, `Run.contracts` less the closed ones, in the
## order you signed them, and nothing here is saved: every line is read off the
## contract and the map when asked. Only this ship's own -- `Run` is one ship,
## so a co-op partner's quests are on their machine and never on yours.
##
## The words are the chart's: QUEST, as its tags and the sector map's key say,
## while the board and its notes keep their own (SIGN, DELIVER).

## The kind's mark, 5x5, each pixel drawn 2x2: a fetch wears the sector map's
## QUEST cross (the pickup it puts there carries it), a hunt the map's FIGHT
## mark, a heat job a little stack of heat.
const MARK := {
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


static func mark_colour(kind: int) -> Color:
	match kind:
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

## Every quest you hold, numbered from 1 in the order you signed them, as the
## table's rows and the chart's tags read them:
##   n, job, kind, what, where, jumps (words), pay, state, state_colour,
##   place (the system its tag stands on: the target, or for a heat quest and
##   a READY one the nearest yard that pays it; -1 if none), tag, tip,
##   who (the poster's short name), manufacturer, yard (whether `place` is the
##   nearest of any of its yards), place_name, layer ("LAYER 7", from 1).
static func entries() -> Array:
	var out: Array = []
	var n := 0
	for raw in Run.contracts:
		var job: ContractData = raw
		if job.state == ContractData.State.CLOSED:
			continue
		n += 1
		out.append(_entry(job, n))
	return out


static func _entry(job: ContractData, n: int) -> Dictionary:
	var who := DB.short_name(DB.manufacturer_name(job.manufacturer))
	var item := job.item
	if item == "" or item.begins_with("a crate"):
		item = "an unmarked crate"
	var e := {n = n, job = job, kind = int(job.kind), pay = "%d CR" % job.pay,
		tag = "%d %s" % [n, TAG_WORD.get(job.kind, "QUEST")], who = who,
		manufacturer = job.manufacturer, place_name = "", layer = ""}
	var yard := false
	if job.state == ContractData.State.READY:
		e.what = "Hand in at any %s yard" % who
		e.state = "READY"
		e.state_colour = UITheme.GOOD
		e.tag = "%d HAND IN" % n
		yard = true
	elif job.kind == ContractData.Kind.HEAT:
		e.what = "Bring heat to any %s yard" % who
		e.state = "%d OF %d HEAT" % [mini(Run.heat, job.amount), job.amount]
		e.state_colour = UITheme.GOOD if Run.heat >= job.amount else UITheme.WARN
		yard = true
	else:
		e.what = "Pick up %s" % item if job.kind == ContractData.Kind.FETCH else "Destroy the contact"
		e.state = "SIGNED"
		e.state_colour = UITheme.ICE
	var place := nearest_yard(job.manufacturer) if yard else job.at
	if place >= Run.map.size():
		place = -1
	e.place = place
	e.yard = yard
	if place < 0:
		e.where = "NO %s YARD IN REACH" % who.to_upper() if yard else "OUT OF REACH"
		e.jumps = ""
	else:
		var p: MapGen.MapNode = Run.map[place]
		var j := jumps(place)
		e.place_name = MapGen.star_name(p)
		e.layer = "LAYER %d" % (p.layer + 1)
		# COUNTED FROM ONE, as the chart's LAYER and its COREWARD L7 count it
		e.where = "%s · L%d" % [MapGen.star_name(p), p.layer + 1]
		e.jumps = "HERE" if j == 0 else ("1 JUMP" if j == 1 else ("%d JUMPS" % j if j > 0 else "NO ROUTE"))
	var tip: String = e.what + "."
	if place >= 0:
		var p2: MapGen.MapNode = Run.map[place]
		if yard:
			tip += "\nAny %s yard. Nearest: %s, layer %d, %s." % [who, MapGen.star_name(p2), p2.layer + 1, String(e.jumps).to_lower()]
		else:
			tip += "\n%s, layer %d, %s." % [MapGen.star_name(p2), p2.layer + 1, String(e.jumps).to_lower()]
	tip += "\nPays %d credits. Posted by %s." % [job.pay, DB.manufacturer_name(job.manufacturer)]
	e.tip = tip
	return e
