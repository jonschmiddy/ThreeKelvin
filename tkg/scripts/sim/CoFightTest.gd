class_name CoFightTest
extends Harness

## Nettest cannot reach `Combat`'s shared path: `Run` is a singleton, one ship per process.
## Without this it would first run in front of a person. NAT is not covered.
## Why: docs/why/CoFightTest.md#test-purpose

const CODE_TAG := "[cofight] code "
## Long enough for a partner to launch a second Godot, load its content tables
## and pick a chassis. This is a real process start, not a frame.
const PARTNER_TIMEOUT := 45.0
## A stuck-fight ceiling, above HeadlessSim's 60 as shared turns take a round trip.
const TURN_CEILING := 80
## Not the default port, so this runs while a playtest is open; the lobby code carries the port.
const PORT := DirectTransport.DEFAULT_PORT + 11

var _tree: SceneTree
var _me: String = ""
## The core reaches `Router.start_combat` down its own branch, the kind of path that goes unshared.
var _boss: bool = false
## The guest holds off until the host is shooting: joining an open fight is a different path.
## Past turn one the guest walks in STUNNED (PROTOCOL 18), no hand until the host's END TURN.
var _late: bool = false
## The roamer, flown: host-authority movement, presence-ticked clock, blockade and both endings.
var _hellbender: bool = false
## The same-second race (Nov 5), both orders: one ship opens a fight, the other another.
## The shell checks the pair from outside: same ids, intent and wrecks.
## Why: docs/why/CoFightTest.md#race-leg
var _race: bool = false
## What this ship's log said, in race mode, for the line the second ship owes.
var _said: PackedStringArray = PackedStringArray()
## How long the late arrival waits. Long enough that the host is unambiguously
## in the fight first, short enough that the harness is not mostly sleeping.
const LATE_ARRIVAL := 6.0
## `boss`: the two ships' jumps, the guest the lead ship (PROTOCOL 16). Past
## the wake, so the badge is awake on both, and short of the cap.
const BOSS_HOST_JUMPS := 3
const BOSS_GUEST_JUMPS := 17
var _at: int = -1
## Members, not locals: a lambda captures a local by value, which reported zero partner shots.
var _partner_shots: int = 0
var _swings_at_me: int = 0
var _seen_hit: int = 0
## How the fight ended, for the cross-process comparison (`outcome`).
var _outcome: String = ""


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	var argv := OS.get_cmdline_user_args()
	var hosting := "host" in argv
	_boss = "boss" in argv
	_late = "late" in argv
	_hellbender = "hellbender" in argv
	_race = "race" in argv
	_me = "HOST" if hosting else "GUEST"

	if hosting:
		await _host()
	else:
		await _join(argv)
	if _fails == 0:
		await _fly()
	# The other ship may still be reading: a host quitting early clears the guest's table.
	await _until(func() -> bool: return false, 3.0)

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
	# The tag the shell script greps for, printed alone so the joiner's argument is unambiguous.
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
	# The seed is shared, the loot stream must not be; the shell compares the two lines.
	print("[cofight] seat %d" % Rng.seat)
	print("[cofight] lootseed %d" % Rng.loot.seed)

	if _hellbender:
		await _hellbender_leg()
		return
	if _race:
		await _race_legs()
		return

	_at = _find(MapGen.NodeType.CORE) if _boss else _find(MapGen.NodeType.SYSTEM)
	if not _ok("the shared galaxy holds a %s to share" % (
			"core" if _boss else "fight"), _at >= 0):
		return

	# The late arrival hangs back so the host is already shooting. `_until` with
	# a condition that never holds is the sleep — this harness has no other.
	if _late and _me == "GUEST":
		print("  GUEST holding off %.0fs so the host opens the fight first"
			% LATE_ARRIVAL)
		await _until(func() -> bool: return false, LATE_ARRIVAL)
		# what the log says from here: the stun, then the turn (a stunned ship
		# counts as ended, so the host's END TURN can move the turn the frame
		# after this ship is seated; the log keeps the order)
		Sig.log_line.connect(func(t: String, _k: StringName) -> void: _said.append(t))

	# One Custodian for the galaxy (PROTOCOL 16, Jon, Nov 4): the guest's 17 is pushed back.
	# Both machines grow the boss and draw the badge on the lead ship.
	# Why: docs/why/CoFightTest.md#custodian
	if _boss:
		Run.jumps = BOSS_GUEST_JUMPS if _me == "GUEST" else BOSS_HOST_JUMPS
		Net._mark_presence()
		var agreed := await _until(func() -> bool:
			return Net.galaxy_jumps == BOSS_GUEST_JUMPS and Run.custodian_jumps() == BOSS_GUEST_JUMPS, 10.0)
		_ok("both ships know the lead ship's %d jumps (own %d, count %d)" % [BOSS_GUEST_JUMPS, Run.jumps,
			Run.custodian_jumps()], agreed)
	# Placed, not flown: routing two ships across an unexplored map would test the pathfinder.
	Run.at = _at
	Run.map[_at].visited = true
	Router.resolve_current_node()
	# The core opens on ENGAGE, not on arrival, which is why a party can be at the boss together.
	await _tree.process_frame
	if _boss:
		Router.engage_here()
	else:
		# No system holds a fight on arrival; this opens the one the option would, on both.
		# Why: docs/why/CoFightTest.md#fight-opening
		var pool := DB.fight_pool(Run.node_at().danger, false)
		Router.start_combat(DB.enemies[pool[_at % pool.size()]], [], true, true)

	var started := await _until(func() -> bool:
		return Router.combat != null, 10.0)
	if not _ok("the fight started", started):
		return
	var cb: Combat = Router.combat
	# Not immediately: `Router.start_combat` assigns `combat` then asks the party.
	# Why: docs/why/CoFightTest.md#shared-window
	var shared := await _until(func() -> bool: return cb.is_shared(), 15.0)
	if not _ok("and it is the party's fight, not a private one", shared):
		return
	# LATE: the host ends its first turn alone, so the guest walks in on turn 2
	if _late and _me == "HOST":
		cb.end_turn()
		_ok("the host ended its first turn alone: turn 2 before the guest arrives", await _until(func() -> bool:
			return Net.fight_at(_at) != null and Net.fight_at(_at).turn >= 2 and not cb.waiting, 10.0))

	# Both ships must be in before either ends a turn, or a barrier of one measures a solo fight.
	var together := await _until(func() -> bool:
		var f := Net.fight_at(_at)
		return f != null and f.crew.size() >= 2, PARTNER_TIMEOUT)
	if not _ok("both ships are in the same fight%s" % (
			" the host had already opened" if _late else ""), together):
		return
	# A stunned ship counts as ended, so the host's next END TURN moves the
	# turn at once: it holds a moment first, so the guest is seen stunned
	# rather than seated straight into turn 3 (which is right too: the swing is
	# held for it, `MidJoinTest`)
	if _late and _me == "HOST":
		await _until(func() -> bool: return false, 3.0)
	if _late and _me == "GUEST":
		await _until(func() -> bool: return _said.has("Stunned. You act after the enemy's turn."), 3.0)
		print("  GUEST seated: the fight's turn %d, stunned %s, said %s" % [Net.fight_at(_at).turn,
			str(Net.fight_at(_at).stunned), str(_said)])
		var stun_at := _said.find("Stunned. You act after the enemy's turn.")
		_ok("the guest walked in after turn 1: stunned (the log says so, line %d)" % stun_at, stun_at >= 0)
		var freed := await _until(func() -> bool: return not cb.stunned and not cb.hand.is_empty(), 30.0)
		_ok("the host's END TURN moved the turn: the stun is gone and the hand came (turn %d, \"Your turn.\" at %d)" % [
			cb.turn, _said.find("Your turn.")], freed and _said.find("Your turn.") > stun_at)

	var f0 := Net.fight_at(_at)
	var scaled := f0.foes[0].max_hp
	var solo := Combat.new()
	solo.plan(cb.enemies[0].template, Run.node_at().danger, [], 1)
	var two := Combat.new()
	two.plan(cb.enemies[0].template, Run.node_at().danger, [], 2)
	print("  %s sees %s at %d hull, built for %d players; one player's is %d" % [
		_me, cb.enemies[0].template.name, scaled, f0.party, solo.enemies[0].max_hp])
	_ok("the enemy is built for the game's two players (%d), not one (%d)" % [two.enemies[0].max_hp, solo.enemies[0].max_hp],
		f0.party == 2 and scaled == two.enemies[0].max_hp and scaled > solo.enemies[0].max_hp)
	_ok("and both machines agree what it is",
		cb.enemies[0].max_hp == scaled)
	if _boss:
		_ok("the Custodian is grown at the lead ship's %d jumps for two (%d, %d)" % [BOSS_GUEST_JUMPS, f0.grown, scaled],
			f0.grown == BOSS_GUEST_JUMPS and scaled == PartyScale.party_hull(
				(DB.enemies[&"custodian"] as EnemyTemplate).hull_at(BOSS_GUEST_JUMPS), 2))
		print("[cofight] custodian hull %d grown %d count %d stage %s" % [scaled, f0.grown,
			CustodianBadge.count(), CustodianBadge.stage(CustodianBadge.count())])

	await _play(cb)
	# Winning at the core ends the run, so there is no dive left to go shopping
	# in. The station leg is about the shelf, not about the boss.
	if not _boss:
		await _shop()


## The fight itself. Deliberately not HeadlessSim's loop: that one runs inside a
## single frame, and every turn here needs the tree to tick so the wire moves.
func _play(cb: Combat) -> void:
	# Counted off signals: a push carries the last hit, so once-a-turn polling undercounted.
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
		if cb.waiting or cb.stunned or cb.asking_at >= 0:
			continue
		turns += 1
		var acted := true
		while acted and not cb.finished:
			acted = false
			# A pending pick blocks every play, so answer it first.
			while cb.choosing > 0:
				cb.choose(cb.best_choice())
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
	# The fight's outcome as both machines must see it: how it ended, what it
	# was, how big the party made it, and how many hands it paid.
	var f1 := Net.fight_at(_at)
	_outcome = "%s %s %d paid%d" % [cb.result, cb.enemies[0].template.id,
		cb.enemies[0].max_hp, f1.paid if f1 != null else -1]
	print("  %s was swung at %d times, took %d hull, and saw %d shots from the other ship"
		% [_me, _swings_at_me, hp_before - Run.hp, _partner_shots])
	_ok("the other ship's cards landed on this machine's copy of the enemy",
		_partner_shots > 0)
	# Each process asserts its own payout: the only way to check both were paid.
	if cb.result == &"victory":
		_ok("and the win paid THIS ship", Run.kills == kills_before + 1)
		# Killing the hellbender must not consume its system; waited for, as a push trails.
		if not _hellbender:
			_ok("and consumed the system for the party", await _until(func() -> bool:
				return Run.map[_at].cleared, 5.0))
		# The race legs compare their wrecks from outside and reach for nothing:
		# a part taken in one leg would sit in the hold through the next.
		if not _race:
			await _bag(cb)


## One kill, one set of wrecks, one hand per part: checked from outside, as neither sees the other.
## Four claims: wrecks match, nothing paid privately, one ship took it, both agree who.
## Why: docs/why/CoFightTest.md#wreck-bag
func _bag(cb: Combat) -> void:
	var n: MapGen.MapNode = Run.map[_at]
	var wrecks: Array = []
	for raw in n.jetsam:
		if (raw as MapGen.Jetsam).is_wreck():
			wrecks.append(raw)
	var desc := PackedStringArray()
	for raw in wrecks:
		var h: MapGen.Jetsam = raw
		var ids := PackedStringArray()
		for m in h.items:
			ids.append(_item_id(m))
		desc.append("%s[%s]" % [h.art, ",".join(ids)])
	print("[cofight] wreck %s" % ("|".join(desc) if desc.size() > 0 else "none"))
	print("[cofight] outcome %s" % _outcome)
	if not _ok("the kill left a wreck in the system", wrecks.size() > 0):
		return
	_ok("one wreck per hull killed", wrecks.size() == cb.enemies.size())
	_ok("and paid nothing straight into either hold", Run.cargo.is_empty())
	# The first module in the first wreck: the part both ships reach for.
	var h0: MapGen.Jetsam = null
	var at := -1
	var parts := 0
	for raw in wrecks:
		var h: MapGen.Jetsam = raw
		for i in h.items.size():
			if h.items[i] is ModuleData:
				parts += 1
				if at < 0:
					h0 = h
					at = i
	# Each wreck rolls once per paid ship; both machines must agree on that count.
	var hands := cb.wreck_hands
	var expect := 0
	for i in wrecks.size():
		var w: MapGen.Jetsam = wrecks[i]
		for m in Combat.roll_wreck(n, DB.enemies[w.art], i, PartyScale.loot(hands)):
			if m is ModuleData:
				expect += 1
	_ok("sized for the game's players, not for one ship (%d parts for %d players, the roll says %d)"
		% [parts, hands, expect], hands >= 2 and parts == expect)
	if not _ok("and there is a part to reach for", at >= 0):
		return

	# Both hands over the same part before either reaches, or this measures one
	# ship looting alone and calls it a race.
	var both := await _until(func() -> bool:
		for p in Net.partners():
			if int(p.get("at", -1)) == _at:
				return true
		return false, PARTNER_TIMEOUT)
	if not _ok("both ships are standing over the wreck", both):
		return

	var wanted: ModuleData = h0.items[at]
	var got := await Run.take_from_jetsam(n, h0, at)
	# The loser's refusal has to arrive too, and it arrives as a push.
	await _until(func() -> bool: return false, 1.5)
	print("[cofight] took %s" % (String(wanted.id) if got else "none"))
	_ok("a refused reach leaves the hold empty",
		got == Run.cargo.has(wanted))
	_ok("and a part somebody took is marked taken for everybody",
		n.taken.has(h0.option(at)))
	# By name off the claims table, the party's record; 'me' and 'them' flip between machines.
	await _until(func() -> bool: return Net.who_took(n.index, h0.option(at)) != 0, 5.0)
	print("[cofight] taker %s" % _claimant(n.index, h0.option(at)))


## Who holds a claim, by name, as the party's claims table says.
func _claimant(index: int, option: int) -> String:
	var id := Net.who_took(index, option)
	return Net.name_of(id) if id != 0 else "nobody"


## What a wreck item is, for the cross-process comparison: a part by its id, the
## money by its kind (each ship's purse is its own, so not the amount).
func _item_id(m: Variant) -> String:
	if m is ModuleData:
		return String((m as ModuleData).id)
	if m is CreditChit:
		return "credits"
	return "?"


## The roamer, end to end: clock, wire, blockade, fight, ending.
func _hellbender_leg() -> void:
	if not _ok("a rival spawned with the galaxy", Run.hellbender_alive()):
		return

	if _me == "HOST":
		# One stride of party jumps, the call `jump_to()` makes, so fuel and adjacency are moot.
		var was := Run.hellbender_at
		for i in Run.hellbender_stride():
			Run.hellbender_jumped()
		_ok("one stride moved it on the authority's chart", Run.hellbender_at != was)
	else:
		# The same call is a no-op on a client, proving the guard; no awaits, so no faked failure.
		var was := Run.hellbender_at
		for i in Run.hellbender_stride():
			Run.hellbender_jumped()
		_ok("a client cannot move it", Run.hellbender_at == was)
		# The guest jumps a stride; the host sees only presence, so each hop moves `at`.
		var a := Run.at
		var b := int(Run.map[a].links[0])
		for i in Run.hellbender_stride():
			Run.at = b if Run.at == a else a
			Sig.resources_changed.emit()
			await _until(func() -> bool: return false, 0.4)

	# Two moves: one off the host's own stride, one off the guest's stride of
	# presence hops. Both machines converge on one chart or this fails.
	var moved := await _until(func() -> bool: return Run.hellbender_moves >= 2, 20.0)
	if not _ok("the party's jumps moved it twice on both charts", moved):
		return
	# Let the last push land everywhere before anything is printed or engaged.
	await _until(func() -> bool: return false, 1.0)
	print("[cofight] hellbenderat %d" % Run.hellbender_at)

	_at = Run.hellbender_at
	var was_cleared: bool = Run.map[_at].cleared
	Run.at = _at
	Run.map[_at].visited = true
	Router.resolve_current_node()
	await _tree.process_frame
	# The blockade, and the core's lesson applied to it: a set piece a party
	# cannot gather at is fought alone by design.
	_ok("arrival does not auto-engage the set piece", Router.combat == null)

	if _me == "GUEST":
		print("  GUEST holding off 3s so the host opens the fight first")
		await _until(func() -> bool: return false, 3.0)
	Router.engage_here()
	var started := await _until(func() -> bool:
		return Router.combat != null, 10.0)
	if not _ok("ENGAGE opened the hellbender fight", started):
		return
	var cb: Combat = Router.combat
	_ok("and it is the rival, hand-tuned", cb.enemies[0].template.miniboss)
	var shared := await _until(func() -> bool: return cb.is_shared(), 15.0)
	if not _ok("and it is the party's fight, not a private one", shared):
		return
	var together := await _until(func() -> bool:
		var f := Net.fight_at(_at)
		return f != null and f.crew.size() >= 2, PARTNER_TIMEOUT)
	if not _ok("both ships are in it", together):
		return
	var f0 := Net.fight_at(_at)
	print("  %s sees the Hellbender at %d of %d hull, built for %d players" % [
		_me, f0.foes[0].hp, f0.foes[0].max_hp, f0.party])
	_ok("built for the game's two players (%d), not one (%d)" % [f0.foes[0].max_hp, Run.hellbender_max],
		f0.party == 2 and f0.foes[0].max_hp == PartyScale.party_hull(Run.hellbender_max, 2))

	await _play(cb)

	# Two possible endings, each must leave the fate line matching on both machines.
	if cb.result == &"victory":
		_ok("the rival is dead on this machine's chart", not Run.hellbender_alive())
		_ok("and its system was not consumed by the kill",
			Run.map[_at].cleared == was_cleared)
		print("[cofight] hellbenderfate dead")
	elif cb.result == &"broke_off":
		var gone := await _until(func() -> bool:
			return Run.hellbender_at != _at, 10.0)
		_ok("the escape moved it off this system on this machine's chart", gone)
		_ok("carrying the damage it took", Run.hellbender_hp < Run.hellbender_max)
		print("[cofight] hellbenderfate fled")
		print("[cofight] hellbenderafter %d:%d" % [Run.hellbender_at, Run.hellbender_hp])
	else:
		print("[cofight] hellbenderfate %s" % cb.result)


## THE SAME-SECOND RACE, both orders. See `_race` above.
func _race_legs() -> void:
	Sig.log_line.connect(func(t: String, _k: StringName) -> void: _said.append(t))
	var a := _find(MapGen.NodeType.SYSTEM)
	var b := -1
	for i in Run.map.size():
		var n: MapGen.MapNode = Run.map[i]
		if i > a and n.type == MapGen.NodeType.SYSTEM and not n.cleared 				and n.region != MapGen.Region.FAUNA:
			b = i
			break
	if not _ok("the shared galaxy holds two systems to race at", a >= 0 and b >= 0):
		return
	await _race_leg(1, a, "HOST", [&"cutter", &"lancer"], [&"hulk"])
	if _fails == 0:
		await _race_leg(2, b, "GUEST", [&"marauder"], [&"lancer", &"hulk"])


## One leg: `first` opens `opened` at system `at`; the other ship, once it can
## see that fight, starts `asked` there without looking.
func _race_leg(leg: int, at: int, first: String, opened: Array, asked: Array) -> void:
	_at = at
	Run.at = at
	Run.map[at].visited = true
	# whole again, cold, and no ambush of this ship's own on the way in: the
	# leg is the race, not the last leg's damage
	Run.hp = Run.max_hp()
	Run.heat = 0
	Run.map[at].ambush_rolled = true
	Run.map[at].ambush_pending = false
	Router.resolve_current_node()
	await _tree.process_frame
	var mine: Array = opened if _me == first else asked
	if _me != first:
		var seen := await _until(func() -> bool: return Net.fight_open_at(at), PARTNER_TIMEOUT)
		if not _ok("leg %d: %s sees the fight %s opened" % [leg, _me, first], seen):
			return
		Router.forced_race = true
	_said.clear()
	Router.start_combat(DB.enemies[mine[0]], mine.slice(1).map(
		func(id: StringName) -> EnemyTemplate: return DB.enemies[id]), true, true)
	var cb: Combat = Router.combat
	var shared := await _until(func() -> bool: return cb != null and cb.is_shared(), 15.0)
	if not _ok("leg %d: %s is in the party's fight" % [leg, _me], shared):
		return
	var together := await _until(func() -> bool:
		var f := Net.fight_at(at)
		return f != null and f.crew.size() >= 2, PARTNER_TIMEOUT)
	if not _ok("leg %d: both ships are in it" % leg, together):
		return
	var ids := PackedStringArray()
	var intents := PackedStringArray()
	for e in cb.enemies:
		ids.append(String(e.template.id))
		intents.append(e.intent.name if e.intent != null else "?")
	var want := PackedStringArray(opened.map(func(id: StringName) -> String: return String(id)))
	_ok("leg %d: %s fights the fight %s opened (%s), whatever it asked for" % [leg, _me, first, ",".join(ids)],
		ids == want and cb.foe_ids() == want and Net.fight_at(at).foe_ids == want)
	if _me != first:
		var line := "%s got here first. You join their fight." % Router.opener_name(Net.fight_at(at))
		_ok("leg %d: and its log says \"%s\"" % [leg, line], _said.has(line))
	print("[cofight] race%d ids %s" % [leg, ",".join(ids)])
	print("[cofight] race%d intents %s" % [leg, "|".join(intents)])
	await _play(cb)
	print("[cofight] race%d outcome %s" % [leg, _outcome])
	print("[cofight] race%d wreck %s" % [leg, _wreck_desc(at)])
	# the fight's own hand-off, played out before the next leg starts one
	await _until(func() -> bool: return Router.combat == null, 5.0)
	if Router.combat != null and Router.combat.finished:
		Router.after_combat(Router.combat)
	await _until(func() -> bool: return false, 1.0)


## The wrecks at a system, for the cross-process comparison.
func _wreck_desc(at: int) -> String:
	var desc := PackedStringArray()
	for raw in Run.map[at].jetsam:
		var h: MapGen.Jetsam = raw
		if not h.is_wreck():
			continue
		var ids := PackedStringArray()
		for m in h.items:
			ids.append(_item_id(m))
		desc.append("%s[%s]" % [h.art, ",".join(ids)])
	return "|".join(desc) if desc.size() > 0 else "none"


func _count_hit(_at2: int) -> void:
	var f := Net.fight_at(_at)
	if f == null or f.hit_serial <= _seen_hit:
		return
	_seen_hit = f.hit_serial
	if f.last_hit.size() == 4 and f.last_hit[0] != Net.local_id():
		_partner_shots += 1


func _count_swing(_a: int, _w: int, _k: int, _p: int) -> void:
	_swings_at_me += 1


## The shelf is the first contested list; buying only emptied the local copy.
## Why: docs/why/CoFightTest.md#shop-leg
func _shop() -> void:
	var here := _find(MapGen.NodeType.STATION)
	if not _ok("the shared galaxy holds a station to share", here >= 0):
		return
	Run.at = here
	Run.map[here].visited = true
	Run.add_credits(100000)
	# Docking without the screen, which cannot stand up headless: stocked as docking stocks it.
	Router.resolve_current_node()
	await _tree.process_frame
	var stocker := StationScreen.new()
	stocker._stock_up()
	stocker.free()

	var n: MapGen.MapNode = Run.map[here]
	if not _ok("the shelf has something on it", n.shop.size() > 0):
		return
	# Meant to match: a station's shelf is drawn positionally, so four orders see one shelf.
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

	# The purchase as every buyer makes it: room first, then ask the party, pay only if you won.
	var before := Run.credits
	var wanted: ModuleData = n.shop[0]
	var price := Market.ask(n, wanted)
	var got := false
	if _ok("there is room for it", Run.has_room_for(wanted)):
		if await Run.take_option(n, MapGen.OPTION_SHOP):
			Run.add_credits(-price)
			Run.stow(wanted)
			got = true
	await _until(func() -> bool: return false, 1.5)

	print("[cofight] bought %s" % (String(wanted.id) if got else "none"))
	_ok("a refused purchase costs nothing", got or Run.credits == before)
	_ok("and the winner paid the shelf's price", not got or Run.credits == before - price)
	_ok("and a slot somebody took is marked taken for everybody",
		n.taken.has(MapGen.OPTION_SHOP))
	await _until(func() -> bool: return Net.who_took(n.index, MapGen.OPTION_SHOP) != 0, 5.0)
	print("[cofight] buyer %s" % _claimant(n.index, MapGen.OPTION_SHOP))


## One function, not three copies. Fauna fights are skipped: they pay no drops.
## Why: docs/why/CoFightTest.md#find-a-system
func _find(t: MapGen.NodeType) -> int:
	for i in Run.map.size():
		var n: MapGen.MapNode = Run.map[i]
		if i == 0 or n.type != t:
			continue
		if t == MapGen.NodeType.SYSTEM \
				and (n.cleared or n.region == MapGen.Region.FAUNA):
			continue
		return i
	return -1


## Small on purpose. This is not a balance model — it only has to be competent
## enough that the fight ends.
func _score(c: CardData, _cb: Combat) -> float:
	if c.unplayable:
		return -1.0
	if Run.heat + c.heat > Run.heat_cap() + 3 and c.heat > 0:
		return -1.0
	if c.energy_gain > 0:
		return 95.0
	# Not `Policy.vent_cold`: it is a swept balance dial and must not decide a co-op test.
	# 0.7 holds under the new heat rules, as vent cards shed more than they print.
	# Why: docs/why/CoFightTest.md#bot-scoring
	if c.vent > 0 and Run.heat > Run.heat_cap() * 0.7:
		return 85.0
	if c.damage > 0:
		return 40.0 + float(c.damage * maxi(1, c.hits)) / 4.0
	if c.block > 0 or c.brace > 0:
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
