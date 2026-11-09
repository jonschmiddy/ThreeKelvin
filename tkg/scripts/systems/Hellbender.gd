class_name Hellbender
extends RefCounted

## The galaxy's rival crew: one furnace of a ship that walks the chart and eats derelicts. `Run`
## holds one and keeps every `hellbender_*` name, so no caller changes (`Run.hellbender_at`).
## Host-authoritative because it moves and the game has no shared clock.
## Why: docs/why/Hellbender.md#the-hellbender

## Jumps between moves, SOLO. At ~65 jumps a run this is ~20 moves — enough to
## matter on the chart, slow enough to be caught.
const STRIDE := 3
## Scaled per ship, so a bigger crew does not outrun it.
## Why: docs/why/Hellbender.md#the-hellbender
const STRIDE_CREW := 2
## Hops taken all at once when it breaks off a fight. Two, so it is out of the
## system and out of jump range, but never out of the story.
const FLEE_HOPS := 2
## Hull mended per ordinary move, never per flee hop, so it escapes hurt and stays
## hurt: the mending window is the chase.
const MEND := 6

## Node index, or -1 once it is dead. There is no `alive` flag; a position is
## the one fact everything else about it hangs off, so absence of one IS death.
var at: int = -1
var hp: int = 0
var hull_max: int = 0
## How many moves it has made. Drives the stride and seeds each move's roll.
var moves: int = 0
## Jumps counted toward the next move.
var ticks: int = 0
## Test seam: `-- sim nohellbender` measures the control cell. Never set from game
## code — the same discipline as Net.forced_protocol.
var off: bool = false

func alive() -> bool:
	return at >= 0 and hp > 0

## Whether this run HAD a Hellbender and it is gone: below HELLBENDER_ASCENSION there never was one.
func destroyed() -> bool:
	return hull_max > 0 and not alive()

## Whether this machine is the one that moves it: the host, or nobody's client.
func _authority() -> bool:
	return not Net.is_networked() or Net.is_host()

## Placed off a positional roll so the world stream does not shift. Middle shells: not
## on a fresh chassis, but on every run's ground.
func spawn() -> void:
	at = -1
	hp = 0
	hull_max = 0
	moves = 0
	ticks = 0
	# Ascension 7 and up only. `hull_max` stays 0 below it, which is how a board tells "never here" from "killed".
	if off or not Run.hellbender_in_play():
		return
	var t: EnemyTemplate = DB.enemies.get(&"hellbender")
	if t == null or Run.map.is_empty():
		return
	var candidates: Array = []
	for n in Run.map:
		var node: MapGen.MapNode = n
		# (never a station: there are no fights at stations, `Router.no_fights_at`)
		if node.layer >= 3 and node.layer <= MapGen.LAYERS - 3 and node.type != MapGen.NodeType.STATION:
			candidates.append(node.index)
	if candidates.is_empty():
		return
	hull_max = t.max_hull
	hp = hull_max
	at = Rng.pick(Rng.derive(&"hellbender", 0), candidates)

## Compared with `<`, so a crew that shrinks still moves it on the next jump.
## Why: docs/why/Hellbender.md#the-hellbender
func stride() -> int:
	var crew := maxi(1, Net.party_size())
	return STRIDE if crew <= 1 else STRIDE_CREW * crew

## A jump happened somewhere in the party; the authority guard makes every caller safe.
func jumped() -> void:
	if not alive() or not _authority():
		return
	# Pinned while anyone is in its fight: it leaves only by the escape burn.
	if Net.fight_open_at(at):
		return
	ticks += 1
	if ticks < stride():
		return
	ticks = 0
	step(true)
	Net.push_hellbender(true)

## A flee hop does not feed and never lands back where it fled from.
## Why: docs/why/Hellbender.md#the-hellbender
func step(feeding: bool, away_from: int = -1) -> void:
	if not alive():
		return
	moves += 1
	var r := Rng.derive(&"hellbender", moves)
	var here_n: MapGen.MapNode = Run.map[at]
	var options: Array = []
	var food: Array = []
	for i in here_n.links:
		if i == away_from:
			continue
		var n: MapGen.MapNode = Run.map[i]
		# Not the rim's first system and not the core: one is the front door,
		# and the other already has a custodian in it.
		if n.type == MapGen.NodeType.START or n.type == MapGen.NodeType.CORE:
			continue
		# nor a station: there are no fights at stations (`Router.no_fights_at`)
		if n.type == MapGen.NodeType.STATION:
			continue
		options.append(i)
		# What is actually here, not the node's label: a wreck is a system with salvage to strip.
		if OptionTable.system_has_tag(n, &"salvage") and not n.cleared:
			food.append(i)
	if options.is_empty():
		return
	# Mending rides the ordinary stride, never a flee hop — it escapes HURT and
	# stays hurt until it has had quiet moves, which is the window the chase is.
	if feeding and hp < hull_max:
		hp = mini(hull_max, hp + MEND)
	# It goes where the salvage is. That is what makes it legible enough to
	# route around — and what makes racing it to a wreck a real race.
	var to: int = Rng.pick(r, food if feeding and not food.is_empty() else options)
	land(to, feeding)

## Apply a landing, on the authority and on clients alike: a pure function of the
## landing, so the party cannot disagree.
func land(to: int, feeding: bool) -> void:
	if to < 0 or to >= Run.map.size():
		return
	at = to
	var n: MapGen.MapNode = Run.map[to]
	if feeding and OptionTable.system_has_tag(n, &"salvage") and not n.cleared:
		# Consumed locally, not via Net.claim(): the movement push is already the shared fact.
		n.cleared = true
		n.eaten = true
		Run._mark_taken(n, MapGen.OPTION_WHOLE)
		Run.log_line("The wreck at %s goes dark on the scope. The Hellbender stripped it." % MapGen.star_name(n), &"them")
	if to == Run.at:
		Run.log_line("A very hot signature fills the scope. THE HELLBENDER IS HERE.", &"big")
	Sig.map_changed.emit()

## A fight ended without a kill; the hull it lost stays lost between engagements.
func scarred(hp_left: int) -> void:
	if not alive() or not _authority():
		return
	hp = clampi(hp_left, 1, hull_max)
	Net.push_hellbender(false)

## The escape burn went unchecked: damage written back, then FLEE_HOPS at once.
func breaks_off(hp_left: int) -> void:
	if not alive() or not _authority():
		return
	hp = clampi(hp_left, 1, hull_max)
	var fled_from := at
	for i in FLEE_HOPS:
		step(false, fled_from)
	Net.push_hellbender(false)

## The kill. Idempotent, because in a party several callers fire it.
func defeated() -> void:
	if at < 0:
		return
	at = -1
	hp = 0
	Run.log_line("The Hellbender breaks apart. All the heat it stole this run leaks into space.", &"good")
	Sig.map_changed.emit()
	Net.push_hellbender(false)

## Position, hull and counter arrive whole from the host, so a dropped push costs one
## update rather than a drift.
func adopt(to: int, host_hp: int, host_moves: int, feeding: bool) -> void:
	moves = maxi(0, host_moves)
	hp = maxi(0, host_hp)
	if to < 0:
		# Only a machine not in the fight gets here still thinking it alive, so this line
		# tells it what it missed.
		if at >= 0:
			at = -1
			hp = 0
			Run.log_line("Word on the convoy channel: the Hellbender is dead.", &"good")
			Sig.map_changed.emit()
		return
	if to == at:
		Sig.map_changed.emit()
		return
	land(to, feeding)
