class_name CoFightTest
extends RefCounted

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

var _tree: SceneTree
var _me: String = ""
var _fails: int = 0
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
	_me = "HOST" if hosting else "GUEST"

	if hosting:
		await _host()
	else:
		await _join(argv)
	if _fails == 0:
		await _fly()

	print("")
	print("cofight[%s]: %s" % [_me, "PASS" if _fails == 0 else "%d FAILURES" % _fails])
	tree.quit(1 if _fails > 0 else 0)


# --- getting two processes into one galaxy --------------------------------

func _host() -> void:
	var t := DirectTransport.new()
	t.advertise = "127.0.0.1"
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

	_at = _find_fight()
	if not _ok("the shared galaxy holds a fight to share", _at >= 0):
		return

	# Placed rather than flown. Adjacency and fuel are not what is under test,
	# and making both ships legally reach one system means routing two of them
	# across a map neither has explored — which would test the pathfinder.
	Run.at = _at
	Run.map[_at].visited = true
	Router.resolve_current_node()

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
	if not _ok("both ships are in the same fight", together):
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


func _count_hit(_at2: int) -> void:
	var f := Net.fight_at(_at)
	if f == null or f.hit_serial <= _seen_hit:
		return
	_seen_hit = f.hit_serial
	if f.last_hit.size() == 4 and f.last_hit[0] != Net.local_id():
		_partner_shots += 1


func _count_swing(_a: int, _w: int, _k: int, _p: int) -> void:
	_swings_at_me += 1


func _find_fight() -> int:
	for i in Run.map.size():
		var n: MapGen.MapNode = Run.map[i]
		if i > 0 and n.type == MapGen.NodeType.FIGHT and not n.cleared:
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


func _ok(what: String, condition: bool) -> bool:
	if condition:
		print("  ok   %s" % what)
	else:
		print("  FAIL %s" % what)
		_fails += 1
	return condition


func _fail(why: String) -> void:
	print("  FAIL %s" % why)
	_fails += 1
