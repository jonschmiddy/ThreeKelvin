class_name CoFightTest
extends Harness

## Two processes, one enemy. The end of the chain, flown rather than argued.
##
## `-- nettest` proves `SharedFight` and `NetSession` in one process, and that
## is as far as one process can go: `Run` is a singleton, so a single instance
## holds exactly one ship. Everything in `Combat`'s shared path — attaching to
## the party's enemy, adopting a push, taking a swing, waiting on the barrier —
## therefore CANNOT execute in nettest, and without this it would first execute
## in front of a person.
##
##   godot --headless --path . -- cofight host
##   godot --headless --path . -- cofight join CODE
##
## or both at once, which is how it is actually run:
##
##   tools/cofight.sh
##
## What it proves: two machines open ONE fight at one system; the enemy is
## scaled for two and both see the same hull; each ship's cards land on the
## other's copy of it; the enemy does not swing until both have ended their
## turn; it swings at exactly one of them; and when it dies BOTH ships are paid.
##
## What it does not prove: any of it through a NAT. Nothing that runs on one
## machine can.

const CODE_TAG := "[cofight] code "
## Long enough for a partner to launch a second Godot, load its content tables
## and pick a chassis. This is a real process start, not a frame.
const PARTNER_TIMEOUT := 45.0
## A fight that has not ended in this many turns is a fight that is stuck. The
## real ceiling is much lower — HeadlessSim uses 60 for a solo fight — but a
## shared one takes a round trip per turn and the enemy is scaled for two.
const TURN_CEILING := 80
## Not `DirectTransport.DEFAULT_PORT`. This harness has to be runnable WHILE a
## playtest is open, and two hosts on one port is the test failing for a reason
## that has nothing to do with the code under it. The port travels inside the
## lobby code, so the joiner needs to be told nothing.
const PORT := DirectTransport.DEFAULT_PORT + 11

var _tree: SceneTree
var _me: String = ""
## `-- cofight host boss` / `-- cofight join CODE boss`. The core is the one
## fight in the game that is not rolled from a node's own table, so it reaches
## `Router.start_combat` down its own branch — which is exactly the kind of
## second path that goes unshared without anybody deciding it should be.
var _boss: bool = false
## `-- cofight join CODE late`. The guest holds off until the host is already
## shooting, which is what actually happens between two people: nobody arrives
## at a system on the same second as anybody else. Joining an OPEN fight is a
## different path through `_open_or_join` than opening one, and it is the one a
## playtest exercises.
var _late: bool = false
## How long the late arrival waits. Long enough that the host is unambiguously
## in the fight first, short enough that the harness is not mostly sleeping.
const LATE_ARRIVAL := 6.0
var _at: int = -1
## Counters, and members rather than locals ON PURPOSE. A GDScript lambda
## captures a local BY VALUE, so `count += 1` inside one increments the
## closure's own copy and the outer variable never moves. The first version of
## this file did exactly that and reported zero partner shots on both machines —
## which looks precisely like the network being broken.
var _partner_shots: int = 0
var _swings_at_me: int = 0
var _seen_hit: int = 0


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	var argv := OS.get_cmdline_user_args()
	var hosting := "host" in argv
	_boss = "boss" in argv
	_late = "late" in argv
	_me = "HOST" if hosting else "GUEST"

	if hosting:
		await _host()
	else:
		await _join(argv)
	if _fails == 0:
		await _fly()

	print("")
	verdict("cofight[%s]" % _me)
	tree.quit(code())


# --- getting two processes into one galaxy --------------------------------

func _host() -> void:
	var t := DirectTransport.new()
	t.advertise = "127.0.0.1"
	t.port = PORT
	var code := Net.host_party("Vela", &"", t)
	if code.is_empty():
		_fail("could not host: %s" % Net.last_error())
		return
	# The tag the shell script greps for. Printed on its own line and nowhere
	# else, so the joiner's argument cannot come from a log line about
	# something similar.
	print(CODE_TAG + LobbyCode.pretty(code))
	Net.set_ready(true)
	var came := await _until(func() -> bool:
		return Net.party_size() >= 2 and Net.everyone_ready(), PARTNER_TIMEOUT)
	if not _ok("a second ship joined and readied", came):
		return
	_ok("the host launched the dive", Net.launch_dive())


func _join(argv: PackedStringArray) -> void:
	var code := ""
	for i in argv.size():
		if argv[i] == "join" and i + 1 < argv.size():
			code = LobbyCode.normalise(argv[i + 1])
	if code.is_empty():
		_fail("no code: godot --headless --path . -- cofight join CODE")
		return
	if not Net.join_party(code, "Mercer", &"", DirectTransport.new()):
		_fail("could not join: %s" % Net.last_error())
		return
	var seated := await _until(func() -> bool:
		return Net.state == NetSession.State.IN_PARTY, PARTNER_TIMEOUT)
	if not _ok("joined the party", seated):
		return
	Net.set_ready(true)


# --- one fight ------------------------------------------------------------

func _fly() -> void:
	var launched := await _until(func() -> bool:
		return Net.dive_seed != 0, PARTNER_TIMEOUT)
	if not _ok("both ships are in the dive", launched):
		return

	# The run the lobby screen would have started, without the lobby screen.
	Router.new_run(Net.dive_seed)
	Run.fit_chassis()
	await _tree.process_frame
	print("  %s flying a %s, galaxy seed %d" % [
		_me, Run.hull.display_name(), Run.galaxy_seed])
	# The seed is shared and the LOOT STREAM MUST NOT BE. Printed rather than
	# asserted here because a single process cannot see the other one's — the
	# shell script compares the two lines, which is the only place the claim can
	# actually be checked.
	print("[cofight] seat %d" % Rng.seat)
	print("[cofight] lootseed %d" % Rng.loot.seed)

	_at = _find(MapGen.NodeType.GOAL) if _boss else _find(MapGen.NodeType.FIGHT)
	if not _ok("the shared galaxy holds a %s to share" % (
			"core" if _boss else "fight"), _at >= 0):
		return

	# The late arrival hangs back so the host is already shooting. `_until` with
	# a condition that never holds is the sleep — this harness has no other.
	if _late and _me == "GUEST":
		print("  GUEST holding off %.0fs so the host opens the fight first"
			% LATE_ARRIVAL)
		await _until(func() -> bool: return false, LATE_ARRIVAL)

	# Placed rather than flown. Adjacency and fuel are not what is under test,
	# and making both ships legally reach one system means routing two of them
	# across a map neither has explored — which would test the pathfinder.
	Run.at = _at
	Run.map[_at].visited = true
	Router.resolve_current_node()
	# The core does not open on arrival any more — it is a place you land at and
	# then commit to, which is the whole point of the change and the reason a
	# party can be at the boss together at all. So this presses ENGAGE, which is
	# what `SectorScreen._on_action` does with the button the player sees.
	if _boss:
		await _tree.process_frame
		Router.engage_here()

	var started := await _until(func() -> bool:
		return Router.combat != null, 10.0)
	if not _ok("the fight started", started):
		return
	var cb: Combat = Router.combat
	# Not immediately. `Router.start_combat` assigns `combat` and THEN asks the
	# party, so there is a real window — one round trip on a client, nothing on
	# the host — where the fight exists and is not yet shared. Checking inside it
	# is how this test failed the first time it ran, and the window is worth
	# knowing about: it is also a moment where a screen draws a fight with no
	# hand in it.
	var shared := await _until(func() -> bool: return cb.is_shared(), 15.0)
	if not _ok("and it is the party's fight, not a private one", shared):
		return

	# Both ships have to be IN it before either ends a turn, or the first one
	# closes a barrier of one and this quietly measures a solo fight with extra
	# round trips in it.
	var together := await _until(func() -> bool:
		var f := Net.fight_at(_at)
		return f != null and f.crew.size() >= 2, PARTNER_TIMEOUT)
	if not _ok("both ships are in the same fight%s" % (
			" the host had already opened" if _late else ""), together):
		return

	var f0 := Net.fight_at(_at)
	var scaled := f0.foes[0].max_hp
	var solo := f0.foes[0].base
	print("  %s sees %s at %d hull — one ship's worth is %d" % [
		_me, cb.enemies[0].template.name, scaled, solo])
	_ok("the enemy is scaled for the crew, not for one ship", scaled > solo)
	_ok("and both machines agree what it is",
		cb.enemies[0].max_hp == scaled)

	await _play(cb)
	# Winning at the core ends the run, so there is no dive left to go shopping
	# in. The station leg is about the shelf, not about the boss.
	if not _boss:
		await _shop()


## The fight itself. Deliberately not HeadlessSim's loop: that one runs inside a
## single frame, and every turn here needs the tree to tick so the wire moves.
func _play(cb: Combat) -> void:
	# Counted off the signals, not polled once a turn. Polling was the first
	# version and it undercounted: a push carries the LAST hit, one push per hit,
	# so a reader that looks once a turn sees one shot out of however many landed
	# in that window. The events are the truth and there is one per hit.
	_partner_shots = 0
	_swings_at_me = 0
	_seen_hit = 0
	Sig.party_fight_changed.connect(_count_hit)
	Sig.party_fight_swing.connect(_count_swing)

	var turns := 0
	var hp_before := Run.hp
	var kills_before := Run.kills
	while not cb.finished and turns < TURN_CEILING:
		# Yield first. A turn that opens the instant the last one closed gives
		# the socket no frame to deliver anything in.
		await _tree.process_frame
		if cb.waiting:
			continue
		turns += 1
		var acted := true
		while acted and not cb.finished:
			acted = false
			var best := -1
			var best_at := 0.0
			for i in cb.hand.size():
				var c := cb.hand[i]
				if not cb.can_play(c):
					continue
				var sc := _score(c, cb)
				if sc > best_at:
					best_at = sc
					best = i
			if best >= 0:
# A pending pick blocks every play, so answer it first.
while cb.choosing > 0:
	cb.choose(cb.best_choice())
				cb.play(best)
				acted = true
		if not cb.finished:
			cb.end_turn()
			# And wait to be let back in, which IS the barrier. A turn that comes
			# back without waiting is a turn the host never gated.
			var released := await _until(func() -> bool:
				return not cb.waiting or cb.finished, 20.0)
			if not released:
				_fail("the barrier never released on turn %d" % turns)
				break
	Sig.party_fight_changed.disconnect(_count_hit)
	Sig.party_fight_swing.disconnect(_count_swing)

	_ok("the fight ended rather than stalling", cb.finished)
	print("  %s: %d turns, result %s — %s" % [_me, turns, cb.result, cb.summary])
	print("  %s was swung at %d times, took %d hull, and saw %d shots from the other ship"
		% [_me, _swings_at_me, hp_before - Run.hp, _partner_shots])
	_ok("the other ship's cards landed on this machine's copy of the enemy",
		_partner_shots > 0)
	# Winning a fight gets you the loot, and everyone still in it when the last
	# hull came apart is in it. Both processes assert this about themselves,
	# which is the only way to check "both were paid" without a third observer.
	if cb.result == &"victory":
		_ok("and the win paid THIS ship", Run.kills == kills_before + 1)
		_ok("and consumed the system for the party", Run.map[_at].cleared)
		await _bag()


## One kill, one bag, and one hand in it.
##
## The third contested thing in the game, and the one the last playtest asked
## for by name. Before this a shared kill paid each ship its own private roll —
## which is duplication solved and distribution never attempted: one frigate paid
## the party twice. It is checked from outside for the same reason the shelf is,
## because neither process can see the other's hold.
##
## Three claims, and they are not the same claim:
##   the bag MATCHES on both machines — it belongs to the node, so it is rolled
##     positionally and every ship is looking at one pile;
##   nothing was paid privately — a hold with something already in it means the
##     old per-ship roll is still running somewhere;
##   and exactly ONE ship walks away with part zero.
func _bag() -> void:
	var n: MapGen.MapNode = Run.map[_at]
	var ids := PackedStringArray()
	for m in n.bag:
		ids.append(String(m.id))
	print("[cofight] bag %s" % ("-".join(ids) if ids.size() > 0 else "none"))
	if not _ok("the kill left a bag at the node", n.bag.size() > 0):
		return
	_ok("and paid nothing straight into either hold", Run.cargo.is_empty())
	# One entry per ship per drop. Both machines have to agree on that number or
	# they are not looking at the same pile — see SharedFight.paid.
	_ok("sized for the crew, not for one ship", n.bag.size() >= 2)

	# Both hands over the same part before either reaches, or this measures one
	# ship looting alone and calls it a race.
	var both := await _until(func() -> bool:
		for p in Net.partners():
			if int(p.get("at", -1)) == _at:
				return true
		return false, PARTNER_TIMEOUT)
	if not _ok("both ships are standing over the bag", both):
		return

	var wanted: ModuleData = n.bag[0]
	var got := await Run.take_from_bag(n, 0)
	# The loser's refusal has to arrive too, and it arrives as a push.
	await _until(func() -> bool: return false, 1.5)
	print("[cofight] took %s" % (String(wanted.id) if got else "none"))
	_ok("a refused reach leaves the hold empty",
		got == Run.cargo.has(wanted))
	_ok("and a part somebody took is marked taken for everybody",
		n.taken.has(MapGen.OPTION_BAG))


func _count_hit(_at2: int) -> void:
	var f := Net.fight_at(_at)
	if f == null or f.hit_serial <= _seen_hit:
		return
	_seen_hit = f.hit_serial
	if f.last_hit.size() == 4 and f.last_hit[0] != Net.local_id():
		_partner_shots += 1


func _count_swing(_a: int, _w: int, _k: int, _p: int) -> void:
	_swings_at_me += 1


## And then both ships dock at the same station and reach for the same part.
##
## The shelf is the second contested thing in the game and the first that is a
## LIST: a wreck is taken whole, a shelf is taken a part at a time. It is also
## the one that looked correct in a playtest — the stock IS meant to be
## identical on both machines, because it is one shop — so the bug was not in
## the roll, it was that buying only emptied the local copy.
func _shop() -> void:
	var here := _find(MapGen.NodeType.STATION)
	if not _ok("the shared galaxy holds a station to share", here >= 0):
		return
	Run.at = here
	Run.map[here].visited = true
	Run.add_credits(100000)
	Router.show_station()
	await _tree.process_frame

	var n: MapGen.MapNode = Run.map[here]
	if not _ok("the shelf has something on it", n.shop.size() > 0):
		return
	# What the shop rolled, printed for the cross-process comparison. This one is
	# meant to MATCH: a station's shelf belongs to the station, so it is drawn
	# positionally and four ships docking in four different orders see one shelf.
	var shelf := PackedStringArray()
	for m in n.shop:
		shelf.append(String(m.id))
	print("[cofight] shelf %s" % "-".join(shelf))

	# Both ships in the doorway before either reaches, or this measures one
	# player shopping alone and calls it a race.
	var both := await _until(func() -> bool:
		for p in Net.partners():
			if int(p.get("at", -1)) == here:
				return true
		return false, PARTNER_TIMEOUT)
	if not _ok("both ships are at the same station", both):
		return

	# Through the real screen, not through the primitive under it. The handler
	# is where the ordering lives — ask the party, and pay only if you won.
	var screen := Router.current as StationScreen
	if not _ok("the station screen is up", screen != null):
		return
	var before := Run.credits
	var wanted: ModuleData = n.shop[0]
	await screen._on_action("buy", wanted)
	await _until(func() -> bool: return false, 1.5)

	var got := Run.cargo.has(wanted)
	print("[cofight] bought %s" % (String(wanted.id) if got else "none"))
	_ok("a refused purchase costs nothing", got or Run.credits == before)
	_ok("and a slot somebody took is marked taken for everybody",
		n.taken.has(MapGen.OPTION_SHOP))


## The first system of a kind, skipping the one you start on.
##
## One function rather than three. `_find_station`, `_find_fight` and
## `_find_goal` were the same six lines with the type constant swapped, and
## `ContractTest` — written the same day — had already generalised it. A third
## copy was one type constant's worth of value.
##
## `cleared` is honoured for a FIGHT because a spent contact is not a fight to
## share; a station and the core do not go away.
func _find(t: MapGen.NodeType) -> int:
	for i in Run.map.size():
		var n: MapGen.MapNode = Run.map[i]
		if i == 0 or n.type != t:
			continue
		if t == MapGen.NodeType.FIGHT and n.cleared:
			continue
		return i
	return -1


## Small on purpose. This is not a balance model — it only has to be competent
## enough that the fight ends.
func _score(c: CardData, cb: Combat) -> float:
	if c.unplayable:
		return -1.0
	if Run.heat + c.heat > Run.heat_cap() + 3 and c.heat > 0:
		return -1.0
	if c.energy_gain > 0:
		return 95.0
	if c.vent > 0 and Run.heat > Run.heat_cap() * 0.7:
		return 85.0
	if c.damage > 0:
		return 40.0 + float(c.damage * maxi(1, c.hits)) / 4.0
	if c.block > 0 or c.armor > 0:
		return 30.0
	return 5.0


# --- plumbing -------------------------------------------------------------

func _until(condition: Callable, timeout: float) -> bool:
	var deadline := float(Time.get_ticks_msec()) / 1000.0 + timeout
	while float(Time.get_ticks_msec()) / 1000.0 < deadline:
		if condition.call():
			return true
		await _tree.process_frame
	return false
