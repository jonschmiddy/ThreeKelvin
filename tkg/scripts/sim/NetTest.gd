extends RefCounted

## Run after touching `scripts/net/`: session faults are silent and show in front of others.
## A per-peer `root_path` fits four peers in one process; it cannot prove NAT traversal.
## Why: docs/why/NetTest.md#test-scope

const PORT_BASE: int = 34210
const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")

var fails: int = 0
var _tree: SceneTree
var _branches: Array[Node] = []
## Branch names are never reused: a `MultiplayerAPI` path cannot be unregistered.
var _peer_serial: int = 0


func check(what: String, got: Variant, want: Variant) -> void:
	if str(got) != str(want):
		fails += 1
		print("  FAIL %s\n    got:  %s\n    want: %s" % [what, got, want])


func ok(what: String, condition: bool) -> void:
	if not condition:
		fails += 1
		print("  FAIL %s" % what)


func run(tree: SceneTree) -> void:
	_tree = tree
	# Wait a frame: in `Main._ready()` the root refuses `add_child()` and peers are rootless.
	await tree.process_frame
	print("\n=== lobby codes ===")
	_code_tests()
	print("\n=== the content check is the same in every process ===")
	_fingerprint_order_tests()
	print("\n=== a party forms ===")
	await _party_test()
	print("\n=== refusals ===")
	await _refusal_tests()
	print("\n=== ship builds ===")
	_wire_tests()
	print("\n=== ships across the wire ===")
	await _build_test()
	print("\n=== one map, not four ===")
	_consume_tests()
	_per_ship_claim_tests()
	await _solo_take_test()
	await _map_test()
	print("\n=== one enemy, several ships ===")
	_fight_rules_test()
	_growth_rules_test()
	await _fight_net_test()
	print("\n=== the enemy's turn ===")
	await _swing_test()
	print("\n=== a peer says things it should not ===")
	await _hostile_peer_test()
	_bot_shelf_test()
	print("\n=== two ships start different fights at one system in the same second ===")
	await _race_test()
	print("\n=== joining a fight after its first turn: stunned (PROTOCOL 18) ===")
	_stun_rules_test()
	await _stun_net_test()
	print("\n=== the party's size sets the enemy and the pay (PROTOCOL 18) ===")
	_party_scale_rules_test()
	await _party_scale_net_test()
	print("\n=== one Custodian for the galaxy ===")
	await _growth_fold_test()
	print("\n=== joining a dive under way, and where a ship is in its system ===")
	await _late_join_test()
	print("\n=== two machines that built different galaxies are told ===")
	await _galaxy_test()
	print("\n=== the host leaves ===")
	await _host_loss_test()
	print("\n=== a turning pair, seen from two clocks ===")
	_turning_pair_test()

	print("")
	if fails == 0:
		print("nettest: PASS")
	else:
		print("nettest: %d FAILURES" % fails)
	tree.quit(1 if fails > 0 else 0)


# --- the content check's order ----------------------------------------------

## Ids sort as text: two exports of one commit refused each other (Oct 20).
## Why: docs/why/NetTest.md#fingerprint-order
func _fingerprint_order_tests() -> void:
	var a := {&"zebra": 1, &"apple": 2, &"mango": 3, &"banana": 4}
	var b := {&"banana": 4, &"mango": 3, &"zebra": 1, &"apple": 2}
	check("ids sort by their text", NetSession.sorted_ids(a), PackedStringArray(["apple", "banana", "mango", "zebra"]))
	check("whatever order the table was built in", NetSession.sorted_ids(b), NetSession.sorted_ids(a))
	for t in [["modules", DB.modules], ["enemies", DB.enemies]]:
		var ids := NetSession.sorted_ids(t[1])
		var in_order := true
		for i in range(1, ids.size()):
			if ids[i - 1] > ids[i]:
				in_order = false
				break
		ok("the %s ids are alphabetical (%d)" % [t[0], ids.size()], in_order and ids.size() == (t[1] as Dictionary).size())


# --- codes ----------------------------------------------------------------

func _code_tests() -> void:
	var cases := [
		["127.0.0.1", 31337], ["192.168.1.42", 7777], ["8.8.8.8", 65535],
		["255.255.255.255", 1], ["10.0.0.1", 34567], ["0.0.0.0", 1024],
	]
	for c in cases:
		var code: String = LobbyCode.encode_direct(c[0], c[1])
		var back := LobbyCode.parse(code)
		check("direct %s:%d round trip" % [c[0], c[1]], "%s:%d" % [back.ip, back.port], "%s:%d" % [c[0], c[1]])
		check("direct %s is 12 characters" % code, code.length(), 12)
		check("direct %s parses clean" % code, back.error, "")

	# A bad octet or port is refused, not masked into a code for another address.
	for bad: Array in [["999.1.1.1", 1], ["a.b.c.d", 1], ["1.2.3", 1], ["1.1.1.1", 70000], ["1.1.1.1", 0]]:
		check("direct %s:%d is refused" % [bad[0], bad[1]], LobbyCode.encode_direct(bad[0], bad[1]), "")

	# A thousand rolls, as bit-packing errors only show on values straddling a character boundary.
	var rooms_ok := true
	for i in 1000:
		var room := LobbyCode.roll_room()
		var code := LobbyCode.encode_room(room)
		var back := LobbyCode.parse(code)
		if back.room != room or code.length() != 7:
			fails += 1
			print("  FAIL room %d -> %s -> %s" % [room, code, back])
			rooms_ok = false
			break
	if rooms_ok:
		print("  1000 room codes round-tripped")

	# Confusables. A player reading a code aloud says "oh" and the listener
	# types the letter; both must reach the same party.
	var real := LobbyCode.encode_direct("10.0.0.1", 34567)
	var typed := real.replace("0", "O").replace("1", "I").to_lower()
	check("O and I fold onto 0 and 1", LobbyCode.parse(typed).ip, "10.0.0.1")
	check("dashes are ignored", LobbyCode.parse(LobbyCode.pretty(real)).ip, "10.0.0.1")

	# Every single-character substitution in a direct code must be caught, or
	# the check character is not earning its place.
	var caught := 0
	var tried := 0
	for i in real.length():
		for j in LobbyCode.ALPHABET.length():
			var c: String = LobbyCode.ALPHABET[j]
			if c == real[i]:
				continue
			var bad := real.substr(0, i) + c + real.substr(i + 1)
			tried += 1
			var got := LobbyCode.parse(bad)
			if got.error != "" or got.ip != "10.0.0.1" or got.port != 34567:
				caught += 1
	print("  %d of %d single-character typos rejected (%.1f%%)" % [caught, tried, 100.0 * caught / tried])
	ok("the check character catches at least 90%% of typos", float(caught) / tried >= 0.90)

	check("a room code is not a direct code", LobbyCode.parse(LobbyCode.encode_room(5)).kind, LobbyCode.Kind.ROOM)
	ok("an empty code is refused", LobbyCode.parse("").error != "")
	ok("a foreign code is refused", LobbyCode.parse("XKCD1234").error != "")
	ok("a short code is refused", LobbyCode.parse("D123").error != "")


# --- a party --------------------------------------------------------------

func _party_test() -> void:
	var port := PORT_BASE
	var host := _make_peer("host")
	var t := DirectTransport.new()
	t.port = port
	t.advertise = "127.0.0.1"
	var code := host.host_party("Vela", &"redline", t)
	ok("the host opened a port and got a code", not code.is_empty())
	if code.is_empty():
		print("  (%s)" % host.last_error())
		return
	print("  code: %s" % LobbyCode.pretty(code))
	check("the host holds slot 1", host.party_size(), 1)

	# Uses `MAX_PLAYERS`: nine hardcoded fours went stale when the cap became eight.
	var seats := NetTransport.MAX_PLAYERS
	var clients: Array = []
	for i in seats - 1:
		var c := _make_peer("client%d" % i)
		var ct := DirectTransport.new()
		c.join_party(code, "Pilot%d" % i, &"korvan", ct)
		clients.append(c)

	# Wait on the last machine to agree: the roster is a broadcast and clients lag the host.
	var joined := await _wait_until(func() -> bool:
		if host.party_size() != seats:
			return false
		for c in clients:
			if c.party_size() != seats:
				return false
		return true, 8.0)
	ok("all %d friends joined, on every machine" % (seats - 1), joined)
	check("the host sees %d" % seats, host.party_size(), seats)
	for i in clients.size():
		check("client %d sees %d" % [i, seats], clients[i].party_size(), seats)
		check("client %d is in the party" % i, clients[i].state, NetSession.State.IN_PARTY)

	# Names compared as a set, host first: ENet delivery order of the clients is not deterministic.
	var names: Array = []
	for row in clients[0].slots():
		names.append(row.name)
	check("the host is first on the roster", clients[0].slots()[0].name, "Vela")
	names.sort()
	var want: Array = []
	for i in seats - 1:
		want.append("Pilot%d" % i)
	want.append("Vela")
	want.sort()
	check("the roster carries names", str(names), str(want))

	# Ready flags travel from a client, through the host, back to everyone.
	# Followed by peer id rather than by position, for the same reason.
	var readier: int = clients[1].local_id()
	clients[1].set_ready(true)
	var spread := await _wait_until(func() -> bool: return clients[2].roster[readier].ready, 3.0)
	ok("one client's ready reaches a third machine", spread)
	ok("the party is not ready with one flag", not host.everyone_ready())

	# Everyone else, by loop rather than by index — clients[1] is already ready
	# from the spread check above, and set_ready(true) twice is a no-op.
	host.set_ready(true)
	for c in clients:
		c.set_ready(true)
	var all_ready := await _wait_until(func() -> bool: return host.everyone_ready(), 3.0)
	ok("the host sees everyone ready", all_ready)

	ok("a client cannot start the dive", not clients[0].launch_dive())
	# At ascension 7 (PROTOCOL 19): the host's level goes with the seed, so
	# every ship's galaxy has the Hellbender or none does (Jon, Nov 8). Set only
	# for the launch, which reads it once.
	Run.forced_ascension = Run.HELLBENDER_ASCENSION
	ok("the host can", host.launch_dive())
	Run.forced_ascension = -1
	check("the host dives at its ascension", host.dive_ascension, Run.HELLBENDER_ASCENSION)
	# Wait on every client: the launch is a broadcast and the last peer to see it matters.
	var launched := await _wait_until(func() -> bool:
		for c in clients:
			if c.state != NetSession.State.DIVING:
				return false
		return true, 3.0)
	ok("the launch reached every client", launched)
	for i in clients.size():
		check("client %d dives on the host's seed" % i, clients[i].dive_seed, host.dive_seed)
		# And on the host's unlocks (PROTOCOL 10): one world, one pool of parts.
		check("client %d rolls from the host's unlocks" % i, str(clients[i].dive_unlocked),
			str(host.dive_unlocked))
		check("client %d dives at the host's ascension" % i, clients[i].dive_ascension, host.dive_ascension)
	ok("the seed is not zero", host.dive_seed != 0)
	ok("the host's unlocks went with it", host.dive_unlocked.has(&"korvan"))

	# One ship past the last seat.
	var extra := _make_peer("gatecrash")
	extra.join_party(code, "Late", &"solari", DirectTransport.new())
	var turned := await _wait_until(func() -> bool: return extra.state == NetSession.State.FAILED, 5.0)
	ok("the seat past the last is turned away", turned)
	check("and told why", extra.last_error(), "The party is full.")
	check("the party is still %d" % seats, host.party_size(), seats)
	print("  %d peers joined, agreed, and launched on seed %d" % [seats, host.dive_seed])

	await _teardown()


# --- a flight said ----------------------------------------------------------

## A plan with no tail (none, or one point), said a sample past its end: that sample is the end.
## It read `tail[-1]` (2 cojoin runs in 7, Nov 8).
func _said_no_tail(L: SystemLayout, t0: float) -> void:
	var a := L.bodies[0].pos(t0)
	var b := L.bodies[1].pos(t0 + 1.0)
	for tail: PackedVector3Array in [PackedVector3Array(), PackedVector3Array([Vector3(b.x, 0.0, b.y)])]:
		var sf = ShipFlightS.new()
		sf.setup(L, Vector2(-L.edge * 0.95, 0.0), t0)
		var pl = ShipFlightS.FlightPlan.new()
		pl.samp = PackedVector3Array([Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y)])
		pl.burns = PackedByteArray([0, 0])
		pl.dur = 1.0
		pl.tail = tail
		sf.plan = pl
		sf.mode = &"fly"
		sf.fly_t0 = t0
		# (0.3 s apart from t0: the fifth sample is 0.2 s past the end)
		var sp = sf.said_path(t0, 0.3)
		var pts: PackedVector2Array = sp[0] if sp is Array and sp.size() == 4 else PackedVector2Array()
		ok("a flight with %d tail points said 0.2 s past its end: 5 points, the last its end (%s)" % [tail.size(), pts],
			pts.size() == 5 and pts[4].distance_to(b) < 1e-3)


## A flight, said once as it leaves (PROTOCOL 17): kept whole by host and late joiner, not said twice,
## gone when let go of; drawn on its path at the sender's clock and moved with its places 10 s behind.
## Why: docs/why/NetTest.md#flight-said-test
func _flight_said_test(host: NetSession, early: NetSession, late: NetSession, id: int) -> void:
	var n12: MapGen.MapNode = Run.map[12] if Run.map.size() > 12 else null
	ok("system 12 is on the map for the flight", n12 != null)
	if n12 == null:
		return
	var L := SystemLayout.of(n12)
	ok("system 12 has two places for it", L.bodies.size() >= 2)
	if L.bodies.size() < 2:
		return
	var t0 := 100.0
	var dur := 3.0
	_said_no_tail(L, t0)
	var pts := PackedVector2Array()
	var lit := PackedByteArray()
	var a := L.bodies[0].pos(t0)
	var b := L.bodies[1].pos(t0 + dur)
	for j in 181:
		var u := float(j) / 180.0
		var bow := Vector2(-(b - a).y, (b - a).x) * 0.2 * sin(PI * u)
		pts.append(a.lerp(b, u) + bow)
		lit.append(1 if (u < 0.05 or u > 0.95) else 0)
	early.report_flight(12, 4242, 0, 1, t0, dur / 180.0, pts, lit, t0)
	var heard := await _wait_until(func() -> bool:
		return late.flights.has(id) and host.flights.has(id), 3.0)
	ok("a flight said reaches the host and the other guest", heard)
	if not heard:
		return
	var fl: Dictionary = late.flights[id]
	ok("whole: its 181 points and burns, from world 0 to world 1, at its clock", (fl.pts as PackedVector2Array) == pts
		and (fl.burns as PackedByteArray) == lit and int(fl.from) == 0 and int(fl.to) == 1 and float(fl.t0) == t0)
	# (the same flight again: nothing goes)
	var got0 := int(fl.got)
	early.report_flight(12, 4242, 0, 1, t0, dur / 180.0, PackedVector2Array([Vector2.ZERO, Vector2.ONE]), lit, t0)
	await _wait_frames(10)
	ok("said again with the same key, nothing goes", int((late.flights[id] as Dictionary).got) == got0)
	var worst := 0.0
	for s: float in [0.0, 0.7, 1.5, 2.2, 3.0]:
		# (this machine's clock the sender's: `now_ms` as the sender's clock at t0 + s)
		var now_ms := int(fl.got) + roundi((t0 + s - float(fl.said)) * 1000.0)
		var fp := NetSession.flight_point(fl, L, t0 + s, now_ms)
		if fp.is_empty():
			worst = INF
			continue
		var j := s / dur * 180.0
		var want := pts[mini(int(j), 179)].lerp(pts[mini(int(j), 179) + 1], j - float(mini(int(j), 179)))
		worst = maxf(worst, ((fp[0] as Vector2) - want).length())
	ok("at the sender's own clock, drawn on its path (worst %.4f px over 5 moments)" % worst, worst < 1.0)
	# ITS CLOCK HELD (a zoom move, LOCAL: a spot since saying so, its clock at
	# t0 + 1): drawn where its clock stopped, not flown on by the wall clock 1.5
	# s more; let go, by its spot's clock, not the wall clock's (the code
	# review, Nov 5)
	var held_ms := int(fl.got) + roundi((t0 + 2.5 - float(fl.said)) * 1000.0)
	var sp_h := {"t": t0 + 1.0, "held": true, "got": int(fl.got) + 1}
	var fh := NetSession.flight_point(fl, L, t0 + 1.0, held_ms, sp_h)
	var off_h := INF if fh.is_empty() else ((fh[0] as Vector2) - pts[60]).length()
	ok("its clock held at 1 s in, drawn there 2.5 s on by the wall clock (%.4f px)" % off_h, off_h < 1.0)
	var sp_r := {"t": t0 + 1.2, "held": false, "got": held_ms}
	var fr := NetSession.flight_point(fl, L, t0 + 1.5, held_ms + 300, sp_r)
	var off_r := INF if fr.is_empty() else ((fr[0] as Vector2) - pts[90]).length()
	ok("let go, by its spot's clock (1.2 s, 0.3 s on: at 1.5 s in, %.4f px)" % off_r, off_r < 1.0)
	# THE RIDE BEFORE AND THE SPIN-DOWN AFTER (`shape`: it leaves 1 s in and
	# arrives 2 s in): at a clock 10 s behind, riding it goes with world 0 and
	# spinning down with world 1, wholly
	var fl2 := fl.duplicate()
	fl2.dep_s = 1.0
	fl2.arr_s = 2.0
	var ms_at := func(s0: float) -> int: return int(fl.got) + roundi((t0 + s0 - float(fl.said)) * 1000.0)
	var rid := NetSession.flight_point(fl2, L, t0 + 0.5 - 10.0, ms_at.call(0.5))
	var spn := NetSession.flight_point(fl2, L, t0 + 2.5 - 10.0, ms_at.call(2.5))
	var off_rid := INF
	var off_spn := INF
	if not rid.is_empty() and not spn.is_empty():
		off_rid = ((rid[0] as Vector2) - (pts[30] + L.bodies[0].pos(t0 + 0.5 - 10.0) - L.bodies[0].pos(t0 + 0.5))).length()
		off_spn = ((spn[0] as Vector2) - (pts[150] + L.bodies[1].pos(t0 + 2.5 - 10.0) - L.bodies[1].pos(t0 + 2.5))).length()
	ok("a clock 10 s behind: riding round to leave it goes with world 0 (%.4f px), spinning down with world 1 (%.4f px)" % [off_rid, off_spn],
		off_rid < 0.01 and off_spn < 0.01)
	var at_start := NetSession.flight_point(fl, L, t0 - 10.0, int(fl.got) + roundi((t0 - float(fl.said)) * 1000.0))
	var at_end := NetSession.flight_point(fl, L, t0 + dur - 10.0, int(fl.got) + roundi((t0 + dur - float(fl.said)) * 1000.0))
	var off0 := INF
	var off1 := INF
	if not at_start.is_empty() and not at_end.is_empty():
		off0 = ((at_start[0] as Vector2) - L.bodies[0].pos(t0 - 10.0) - (pts[0] - a)).length()
		off1 = ((at_end[0] as Vector2) - L.bodies[1].pos(t0 + dur - 10.0) - (pts[180] - b)).length()
	ok("a clock 10 s behind: it leaves from world 0 where it is there (%.4f px) and lands on world 1 where it is there (%.4f px)" % [off0, off1], off0 < 0.01 and off1 < 0.01)
	early.report_flight_off(12)
	var gone := await _wait_until(func() -> bool:
		return not late.flights.has(id) and not host.flights.has(id), 3.0)
	ok("let go of, the flight is gone on the others", gone)


# --- refusals -------------------------------------------------------------

func _refusal_tests() -> void:
	# Against `NetSession.PROTOCOL`, so the next bump does not fail with a false message.
	await _one_refusal("a different protocol", PORT_BASE + 1, 99, 0,
		"Different game version. Host is protocol %d, you are 99." % NetSession.PROTOCOL)
	# PROTOCOL 13 peers are turned away by name: their spots are two numbers short.
	# Why: docs/why/NetTest.md#protocol-refusals
	await _one_refusal("a version 13 peer", PORT_BASE + 32, 13, 0,
		"Different game version. Host is protocol %d, you are 13." % NetSession.PROTOCOL)
	ok("PROTOCOL is past 13, when the pair held still", NetSession.PROTOCOL >= 14)
	# (and past 14, which built twice the stations from the same seed, Nov 3)
	ok("PROTOCOL is past 14, when stations were twice as many", NetSession.PROTOCOL >= 15)
	# PROTOCOL 16 (Jon, Nov 4): a 15 peer grows the boss on its own jumps, so it is refused.
	# Why: docs/why/NetTest.md#protocol-refusals
	await _one_refusal("a version 15 peer", PORT_BASE + 33, 15, 0,
		"Different game version. Host is protocol %d, you are 15." % NetSession.PROTOCOL)
	ok("PROTOCOL is past 15, when each ship grew its own Custodian", NetSession.PROTOCOL >= 16)
	# JOINING LATE, STUNNED, AND THE PARTY'S SIZE (PROTOCOL 18, Jon, Nov 5): a
	# 16 peer reads no stun and grows every fight it walks into; its worlds also
	# turn at the old pace and it never says a flight (17's reasons): turned away
	await _one_refusal("a version 16 peer", PORT_BASE + 35, 16, 0,
		"Different game version. Host is protocol %d, you are 16." % NetSession.PROTOCOL)
	# FAST TRANSFERS AND FASTER WORLDS (PROTOCOL 17, Nov 4-5) landed with 18: a
	# 17 peer has the fast worlds and says its flights, but has no stun
	await _one_refusal("a version 17 peer", PORT_BASE + 36, 17, 0,
		"Different game version. Host is protocol %d, you are 17." % NetSession.PROTOCOL)
	ok("PROTOCOL is past 17, when a late ship was dealt a hand at once and the worlds turned at the old pace", NetSession.PROTOCOL >= 18)
	await _one_refusal("different content", PORT_BASE + 2, 0, 0x5EEDBAD,
		"Your content does not match the host's. Compare builds or mods.")
	# Two exported builds from different commits, refused by name, and the
	# message names both (PROTOCOL 9).
	await _one_refusal("a different build", PORT_BASE + 30, 0, 0,
		"Your friend is on build 0.1.0-alpha.1 · aaaaaaa; you're on 0.1.0-alpha.1 · bbbbbbb. Both need the same build.",
		"0.1.0-alpha.1 · aaaaaaa", "0.1.0-alpha.1 · bbbbbbb")
	# And a run from source joins an export: "dev" is judged by protocol and
	# content alone.
	await _one_join("a run from source joining an export", PORT_BASE + 31,
		"0.1.0-alpha.1 · aaaaaaa", "dev")

	# A code that parses but points nowhere is the common case, and must not look like a typo.
	var lonely := _make_peer("lonely")
	lonely.join_party(LobbyCode.encode_direct("127.0.0.1", PORT_BASE + 90), "Nobody", &"redline", DirectTransport.new())
	var gave_up := await _wait_until(func() -> bool: return lonely.state == NetSession.State.FAILED, 6.0)
	ok("an unreachable host fails rather than hanging", gave_up)
	ok("and the message names the port", lonely.last_error().contains("port") or lonely.last_error().contains("connect"))
	print("  unreachable: %s" % lonely.last_error())
	await _teardown()

	# A typo, refused locally without any packet leaving the machine.
	var typo := _make_peer("typo")
	var good := LobbyCode.encode_direct("127.0.0.1", PORT_BASE)
	var bad := good.substr(0, 4) + ("Z" if good[4] != "Z" else "Y") + good.substr(5)
	ok("a mistyped code is refused before connecting", not typo.join_party(bad, "Butter", &"redline", DirectTransport.new()))
	check("and named as a typo", typo.last_error(), "That code has a typo in it.")
	await _teardown()


func _one_refusal(what: String, port: int, protocol: int, fingerprint: int, want: String,
		host_build: String = "", client_build: String = "") -> void:
	var host := _make_peer("host")
	host.forced_build = host_build
	var t := DirectTransport.new()
	t.port = port
	t.advertise = "127.0.0.1"
	var code := host.host_party("Vela", &"redline", t)
	if code.is_empty():
		fails += 1
		print("  FAIL could not host for '%s': %s" % [what, host.last_error()])
		await _teardown()
		return
	var c := _make_peer("odd")
	c.forced_protocol = protocol
	c.forced_fingerprint = fingerprint
	c.forced_build = client_build
	c.join_party(code, "Odd", &"korvan", DirectTransport.new())
	var refused := await _wait_until(func() -> bool: return c.state == NetSession.State.FAILED, 5.0)
	ok("%s is refused" % what, refused)
	check("%s is explained" % what, c.last_error(), want)
	print("  %s: %s" % [what, c.last_error()])
	check("%s leaves the party empty" % what, host.party_size(), 1)
	await _teardown()


## The other side of the build check: a pairing it must let through.
func _one_join(what: String, port: int, host_build: String, client_build: String) -> void:
	var host := _make_peer("host")
	host.forced_build = host_build
	var t := DirectTransport.new()
	t.port = port
	t.advertise = "127.0.0.1"
	var code := host.host_party("Vela", &"redline", t)
	if code.is_empty():
		fails += 1
		print("  FAIL could not host for '%s': %s" % [what, host.last_error()])
		await _teardown()
		return
	var c := _make_peer("dev")
	c.forced_build = client_build
	c.join_party(code, "Dev", &"korvan", DirectTransport.new())
	var joined := await _wait_until(func() -> bool: return c.state == NetSession.State.IN_PARTY, 5.0)
	ok("%s is let in" % what, joined)
	await _teardown()


# --- what everybody is flying ---------------------------------------------

## Values a real run takes long to reach, as losing those fields would be invisible.
## Why: docs/why/NetTest.md#wire-tests
func _wire_tests() -> void:
	var b := ShipBuild.new()
	b.pilot = "Mercer"
	b.hull = DB.hull_for(&"probate", HullData.Weight.MEDIUM)
	b.parts = [
		{"slot": int(ModuleData.Slot.WEAPON), "mount": 2, "manufacturer": &"verity", "id": &"beam"},
		{"slot": int(ModuleData.Slot.UTILITY), "mount": 0, "manufacturer": &"cygnet", "id": &"coolline"},
	]
	b.hp = 7
	b.max_hp = 44
	b.heat = 15
	b.heat_cap = 10

	var back := ShipBuild.from_wire(b.to_wire())
	check("the pilot survives", back.pilot, "Mercer")
	check("the hull manufacturer survives", back.hull.manufacturer, &"probate")
	check("the weight class survives", int(back.hull.weight), int(HullData.Weight.MEDIUM))
	check("the part count survives", back.parts.size(), 2)
	check("the hardpoint survives", int(back.parts[0].mount), 2)
	check("who built the part survives", StringName(back.parts[0].manufacturer), &"verity")
	check("damage survives", back.hp, 7)
	# Over cap is a state the ship art has its own colours for, so it has to
	# arrive as itself rather than clamped on the way.
	ok("and an overheat arrives as an overheat", back.heat_ratio() > 1.0)

	# A showroom hull is an ordinary build with nothing on it, as `ShipView` has no preview mode.
	var shown := ShipBuild.showroom(DB.hull_for(&"korvan", HullData.Weight.LIGHT))
	check("a showroom ship carries no parts", shown.parts.size(), 0)
	check("and is undamaged", shown.damage(), 0.0)
	check("and is cold", shown.heat_ratio(), 0.0)

	# A weight of 99 must not take down the sector screen on every machine over one bad peer.
	var junk := ShipBuild.from_wire({"manufacturer": &"nobody", "weight": 99,
		"parts": "not a list", "hp": "seven"})
	ok("nonsense off the wire still names a hull", junk.hull != null)
	check("and carries no parts", junk.parts.size(), 0)
	var empty := ShipBuild.from_wire({})
	ok("and so does an empty message", empty.hull != null)
	# The renderer calls `get` on each part, so one that is not a dictionary raises every draw.
	var odd := ShipBuild.from_wire({"parts": [5, "x", {"slot": 0, "mount": 1}, null]})
	check("only dictionary parts survive the wire", odd.parts.size(), 1)
	var crowd: Array = []
	crowd.resize(ShipBuild.MAX_PARTS + 40)
	crowd.fill({"slot": 0})
	check("and no more than a hull could carry", ShipBuild.from_wire({"parts": crowd}).parts.size(), ShipBuild.MAX_PARTS)


## Catches a partner drawn as the wrong ship, which looks like art, not a bug.
## Why: docs/why/NetTest.md#build-test
func _build_test() -> void:
	var host := _make_peer("host")
	var t := DirectTransport.new()
	t.port = PORT_BASE + 4
	t.advertise = "127.0.0.1"
	var code := host.host_party("Vela", &"redline", t)
	var c := _make_peer("client")
	c.join_party(code, "Mercer", &"korvan", DirectTransport.new())
	var joined := await _wait_until(func() -> bool: return c.state == NetSession.State.IN_PARTY, 5.0)
	ok("the client joined", joined)
	if not joined:
		await _teardown()
		return

	# One process holds one `Run`, so both peers describe the same ship: a harness limit only.
	Run.fit_chassis(&"solari", HullData.Weight.HEAVY)
	var told := await _wait_until(func() -> bool: return c.build_of(1) != null, 3.0)
	ok("the host's ship reached the client without being asked for", told)
	if told:
		var seen: ShipBuild = c.build_of(1)
		check("and it is the right hull", seen.hull.manufacturer, &"solari")
		check("and the right weight class", int(seen.hull.weight), int(HullData.Weight.HEAVY))
		check("and carries the same parts", seen.parts.size(), Run.installed.size())

	# A refit, and the party sees the new ship. This is the whole feature: a gun
	# bolted on here is a gun drawn over there.
	Run.fit_chassis(&"redline", HullData.Weight.LIGHT)
	var changed := await _wait_until(func() -> bool:
		var b: ShipBuild = c.build_of(1)
		return b != null and b.hull.manufacturer == &"redline", 3.0)
	ok("a refit reaches the client too", changed)

	# And the other way, with the two gauges the art actually reads.
	var them := c.local_id()
	Run.hp = 7
	Run.heat = Run.heat_cap() + 5
	Sig.resources_changed.emit()
	var hurt := await _wait_until(func() -> bool:
		var b: ShipBuild = host.build_of(them)
		return b != null and b.hp == 7 and b.heat_ratio() > 1.0, 3.0)
	ok("the client's damage and heat reached the host", hurt)
	if hurt:
		var got: ShipBuild = host.build_of(them)
		check("with the right hull", got.hull.manufacturer, &"redline")
		var want: Array = []
		for m in Run.installed:
			want.append("%d/%d/%s" % [int(m.slot), maxi(m.mount, 0), m.manufacturer])
		var have: Array = []
		for part in got.parts:
			have.append("%d/%d/%s" % [int(part.slot), int(part.mount), part.manufacturer])
		check("and every part on its own hardpoint", "|".join(have), "|".join(want))
	await _teardown()


# --- one map, not four ----------------------------------------------------

## `consume_node()` must work in the solo game too, or the chokepoint broke it for one player.
func _consume_tests() -> void:
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n: MapGen.MapNode = Run.map[12]
	n.cleared = false
	n.taken = PackedInt32Array()
	Run.take_whole(n)
	ok("a system is consumed with no party", n.cleared)
	ok("and the option is recorded beside the flag", n.taken.has(MapGen.OPTION_WHOLE))
	check("and nothing was claimed offline", Net.claims.size(), 0)
	# Idempotent, because the sector can offer the same wreck twice on the way
	# through a resume and the second answer must not be a second haul.
	Run.take_whole(n)
	check("consuming it twice records it once", n.taken.size(), 1)

	# And the other direction: a list that arrived from the party, applied to a
	# map this machine generated itself.
	for i in [40, 41]:
		Run.map[i].cleared = false
		Run.map[i].taken = PackedInt32Array()
	Net.claims = {40: {MapGen.OPTION_WHOLE: 2}, 41: {3: 2}, 99999: {0: 2}, -3: {0: 2}}
	var map_size := Run.map.size()
	var tail: MapGen.MapNode = Run.map[map_size - 3]
	var tail_was: Array = [tail.cleared, tail.taken.size()]
	Run.adopt_party_claims()
	ok("a claim from the party clears this machine's copy", Run.map[40].cleared)
	# One option taken is not the whole system: stripping the wreck leaves the fight.
	ok("but one option taken leaves the system open", not Run.map[41].cleared)
	ok("and the option itself is recorded", Run.map[41].taken.has(3))
	# Checked because a bad index would otherwise take the chart down on the receiver.
	ok("an index off the end of the map is ignored, not fatal",
		Run.map.size() == map_size and [tail.cleared, tail.taken.size()] == tail_was)
	Net.claims = {}


## A partner's claim never closes this ship's own options (Oct 22).
## Why: docs/why/NetTest.md#per-ship-claims
func _per_ship_claim_tests() -> void:
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	ok("an event quest and a contract pickup are per ship, a rolled event is not",
		OptionTable.is_mine(&"paid_in_full") and OptionTable.is_mine(&"job_pickup")
		and OptionTable.is_mine(&"job_target") and not OptionTable.is_mine(&"the_runner"))
	# two unvisited systems: one rolled before the claims, one after
	var picks: Array[MapGen.MapNode] = []
	for raw in Run.map:
		var c: MapGen.MapNode = raw
		if c.type == MapGen.NodeType.SYSTEM and not c.visited and c.layer >= 4 and c.options.is_empty():
			picks.append(c)
		if picks.size() == 2:
			break
	if picks.size() < 2:
		ok("two unrolled systems to test on", false)
		return
	var n := picks[0]
	OptionTable.ensure(n)
	var rolled := n.options.size()
	n.options.append(&"paid_in_full")
	n.options.append(&"job_pickup")
	var q := MapGen.OPTION_SITE + rolled
	var p := MapGen.OPTION_SITE + rolled + 1
	Net.claims = {n.index: {q: 2, p: 2, MapGen.OPTION_SITE: 2}}
	Run.adopt_party_claims()
	ok("a partner's claim at the same system and slot leaves my placed quest open",
		not n.taken.has(q) and OptionTable.holds_quest(n))
	ok("and my contract pickup open", not n.taken.has(p))
	ok("while their claim on a rolled option still closes it here", n.taken.has(MapGen.OPTION_SITE))
	# a claim past the list on a system not rolled yet
	var m := picks[1]
	var past := MapGen.OPTION_SITE + OptionTable.roll_for(m).size()
	Net.claims = {m.index: {past: 2}}
	Run.adopt_party_claims()
	OptionTable.ensure(m)
	m.options.append(&"paid_in_full")
	Run.adopt_party_claims()
	ok("a claim past an unrolled list does not close what I place there after",
		not m.taken.has(past) and OptionTable.holds_quest(m))
	Net.claims = {}


## An option taken with nobody to ask. Solo has to answer YES immediately, or
## every contested encounter in the single-player game stalls for the timeout.
func _solo_take_test() -> void:
	var n: MapGen.MapNode = Run.map[55]
	n.cleared = false
	n.taken = PackedInt32Array()
	var got: bool = await Run.take_option(n, MapGen.OPTION_WHOLE)
	ok("a solo ship always wins the thing it reached", got)
	ok("and the system is finished", n.cleared)
	var again: bool = await Run.take_option(n, MapGen.OPTION_WHOLE)
	ok("and cannot take the same thing twice", not again)


## This message stops four players each stripping the same derelict.
## Why: docs/why/NetTest.md#map-test
func _map_test() -> void:
	var host := _make_peer("host")
	var t := DirectTransport.new()
	t.port = PORT_BASE + 5
	t.advertise = "127.0.0.1"
	var code := host.host_party("Vela", &"redline", t)
	var others: Array = []
	for i in 2:
		var c := _make_peer("client%d" % i)
		c.join_party(code, "Pilot%d" % i, &"korvan", DirectTransport.new())
		others.append(c)
	var joined := await _wait_until(func() -> bool:
		if host.party_size() != 3:
			return false
		for c in others:
			if c.party_size() != 3:
				return false
		return true, 5.0)
	ok("three ships in the party", joined)
	if not joined:
		await _teardown()
		return

	# A client uses one up. It has to reach the host AND the other client, which
	# is the half a host-only check would miss.
	others[0].claim(214)
	var spread := await _wait_until(func() -> bool:
		if host.who_took(214) == 0:
			return false
		for c in others:
			if c.who_took(214) == 0:
				return false
		return true, 4.0)
	ok("a system consumed by one ship is consumed for the party", spread)
	check("and the party knows who took it", host.who_took(214), others[0].local_id())

	# And the host's own, which takes a different path — no round trip.
	host.claim(7)
	var from_host := await _wait_until(func() -> bool:
		for c in others:
			if c.who_took(7) == 0:
				return false
		return true, 4.0)
	ok("and one consumed by the host reaches everybody too", from_host)
	check("recorded against the host", host.who_took(7), 1)

	# Twice is once. The list is pushed whole, so a duplicate would grow it
	# forever across a dive.
	others[1].claim(214)
	await _wait_frames(12)
	check("claiming the same system twice records it once", host.taken_at(214).size(), 1)
	check("and it still belongs to whoever was first", host.who_took(214),
		others[0].local_id())
	check("the party has used two systems", host.claims.size(), 2)

	# One option is not the whole system. A ship that stripped the wreck has not
	# taken the fight that was waiting beside it.
	others[0].claim(214, 2)
	await _wait_until(func() -> bool: return host.who_took(214, 2) != 0, 3.0)
	check("a second option at the same system is its own claim",
		host.taken_at(214).size(), 2)
	check("and the party has still used two systems", host.claims.size(), 2)

	# The race: exactly one of two same-frame askers wins, and the loser is told who did.
	var got: Array = [0, 0]
	_take_into(others[0], 300, got, 0)
	_take_into(others[1], 300, got, 1)
	var settled := await _wait_until(func() -> bool:
		return got[0] != 0 and got[1] != 0, 5.0)
	ok("both ships got an answer", settled)
	ok("and they agree who owns it", got[0] == got[1])
	ok("and the owner is one of the two who asked", got[0] == others[0].local_id()
		or got[0] == others[1].local_id())
	var winners := 0
	for i in 2:
		if got[i] == others[i].local_id():
			winners += 1
	check("exactly one of them won", winners, 1)
	print("  two ships asked for option 300 at once; %s got it" % host.taker_name(300))

	# One process holds one `Run`, so this only checks the number travels into the right slot.
	var placed := await _wait_until(func() -> bool:
		return host.where_is(1) == Run.at and others[0].where_is(1) == Run.at, 4.0)
	ok("everybody's position reaches everybody", placed)
	check("and an unknown position is -1, not system zero", host.where_is(99), -1)
	print("  party used %d systems · everybody at %d" % [
		host.claims.size(), host.where_is(1)])
	await _teardown()


## Start a take without waiting for it, so two of them are in flight together.
## Awaiting each in turn would test the queue rather than the race.
func _take_into(session: NetSession, index: int, out: Array, slot: int) -> void:
	out[slot] = await session.take(index)


# --- losing the host ------------------------------------------------------

func _host_loss_test() -> void:
	var host := _make_peer("host")
	var t := DirectTransport.new()
	t.port = PORT_BASE + 3
	t.advertise = "127.0.0.1"
	var code := host.host_party("Vela", &"redline", t)
	var c := _make_peer("client")
	c.join_party(code, "Pilot", &"korvan", DirectTransport.new())
	var joined := await _wait_until(func() -> bool: return c.state == NetSession.State.IN_PARTY, 5.0)
	ok("the client joined", joined)

	# The lead ship's count as the guest last heard it (PROTOCOL 16)
	var kept_party := Run.party_jumps
	Run.party_jumps = 17
	c.galaxy_jumps = 17
	host.leave_party()
	var noticed := await _wait_until(func() -> bool: return c.state == NetSession.State.FAILED, 5.0)
	ok("the client notices the host left", noticed)
	check("and says so", c.last_error(), "The host left.")
	check("and the roster is emptied", c.party_size(), 0)
	check("the party's copy of the lead ship's count goes with it", c.galaxy_jumps, 0)
	check("but the ship keeps it, so its Custodian never shrinks", Run.party_jumps, 17)
	Run.party_jumps = kept_party
	print("  the client was told: %s" % c.last_error())
	await _teardown()


# --- shared fights --------------------------------------------------------

## Rules with no wire, which is why `SharedFight` is a plain `RefCounted`.
func _fight_rules_test() -> void:
	var f := SharedFight.open(42, PackedStringArray(["cutter"]),
		PackedInt32Array([100]), PackedInt32Array([3]), PackedInt32Array([100]), 11)
	check("one ship, one ship's frigate", f.foes[0].max_hp, 100)

	# NOTHING GROWS WHEN A SHIP WALKS IN (Jon, Nov 5): the hull was built for
	# the players in the game (`PartyScale`, `party`), wherever they are.
	f.join(22)
	f.join(33)
	check("three ships walk in, and the frigate is what it was built as", f.foes[0].max_hp, 100)
	check("and at full health", f.foes[0].hp, 100)
	check("three in the crew", f.crew.size(), 3)
	ok("joining twice is joining once", not f.join(22))

	# Block first, then brace, as `Combat.damage_enemy` does, or the hull bar and log disagree.
	f.foes[0].block = 5
	var landed := f.hurt(0, 10, 2, 22)
	# Mitigation is per fight, not per hit, which makes multi-hit cards good into brace.
	check("block and brace come off the first hit only", landed, 12)
	check("hull took exactly that", f.foes[0].hp, 88)
	check("the shot is stamped with who fired it", f.last_hit[0], 22)
	check("and with a serial, so it is drawn once", f.hit_serial, 1)

	# The barrier. Nothing about a turn is gated except the enemy swinging.
	ok("one ship ending is not the turn ending", not f.end_turn(11))
	ok("nor two", not f.end_turn(22))
	check("and the fight says who it is waiting for", f.waiting_on()[0], 33)
	ok("the last one closes it", f.end_turn(33))
	f.advance()
	check("then everybody goes again", f.turn, 2)
	check("and the enemy's block is spent", f.foes[0].block, 0)

	# Leaving has to release the barrier, or three people wait forever on
	# somebody who is dead.
	f.end_turn(11)
	f.end_turn(22)
	f.leave(33)
	ok("a ship that leaves is not waited for", f.waiting_on().is_empty())
	check("and the enemy does not shrink", f.foes[0].max_hp, 100)

	# A shot off a socket is bounded: a huge `hits` once held the host's frame, a negative amount healed.
	var shot := SharedFight.open(43, PackedStringArray(["cutter"]),
		PackedInt32Array([100]), PackedInt32Array([0]), PackedInt32Array([100]), 11)
	var t0 := Time.get_ticks_msec()
	shot.hurt(0, 1, 2147483647, 11)
	ok("a shot of two billion hits returns promptly", Time.get_ticks_msec() - t0 < 2000)
	var mend := SharedFight.open(44, PackedStringArray(["cutter"]),
		PackedInt32Array([100]), PackedInt32Array([0]), PackedInt32Array([50]), 11)
	mend.hurt(0, -500, 1, 11)
	check("a negative shot does not heal", mend.foes[0].hp, 50)
	var big := SharedFight.open(45, PackedStringArray(["cutter"]),
		PackedInt32Array([100]), PackedInt32Array([0]), PackedInt32Array([100]), 11)
	check("a shot at the cap still lands in full", big.hurt(0, 40, SharedFight.MAX_HITS, 11) > 0, true)

	# Killing it ends it, once, for everyone.
	f.hurt(0, 999, 1, 11)
	ok("a dead enemy ends the fight", f.over)
	ok("and cannot be shot again", f.hurt(0, 10, 1, 11) == 0)

	# The wire is the whole of it. A field that does not round-trip is a field
	# three machines disagree about.
	var back := SharedFight.from_wire(f.to_wire())
	check("the fight round-trips: hull", back.foes[0].hp, f.foes[0].hp)
	check("  scale", back.foes[0].max_hp, f.foes[0].max_hp)
	check("  what it is", String(back.foe_ids[0]), "cutter")
	check("  who is in it", back.crew.size(), f.crew.size())
	check("  whose turn", back.turn, f.turn)
	check("  the last shot", back.hit_serial, f.hit_serial)
	ok("  and that it is over", back.over)

	# Junk off a socket must not reach a renderer that dereferences it.
	var junk := SharedFight.from_wire({"at": 3, "foes": [42, [], "x"]})
	check("a malformed fight arrives empty rather than wrong", junk.foes.size(), 0)

	# The count its hull was grown at (PROTOCOL 16) is on the wire; a cutter's says -1.
	var g20 := SharedFight.open(5, PackedStringArray(["custodian"]), PackedInt32Array([243]),
		PackedInt32Array([8]), PackedInt32Array([243]), 1, 20)
	check("a fight's grown count round-trips", SharedFight.from_wire(g20.to_wire()).grown, 20)
	check("an opener's count defaults to nothing grown", SharedFight.open(5, PackedStringArray(["cutter"]),
		PackedInt32Array([10]), PackedInt32Array([0]), PackedInt32Array([10]), 1).grown, -1)
	check("a fight with no grown count reads -1", SharedFight.from_wire({"at": 5, "foes": []}).grown, -1)
	check("a wild one is clamped high", SharedFight.from_wire({"at": 5, "grown": 123456789}).grown, SharedFight.MAX_GROWN)
	check("and low", SharedFight.from_wire({"at": 5, "grown": -40}).grown, -1)


## The boss grows mid-fight (Jon, Nov 4, decision 2): damage done stays done.
## Why: docs/why/NetTest.md#boss-growth
func _growth_rules_test() -> void:
	var cust: EnemyTemplate = DB.enemies[&"custodian"]
	var h20 := cust.hull_at(20)
	var h33 := cust.hull_at(33)
	var f := SharedFight.open(7, PackedStringArray(["custodian"]), PackedInt32Array([h20]),
		PackedInt32Array([0]), PackedInt32Array([h20]), 1, 20)
	f.join(2)
	var joined := f.foes[0].max_hp
	f.hurt(0, 100, 1, 1)
	var done := f.foes[0].max_hp - f.foes[0].hp
	var r := NetSession.growth_ratios(f, 33)
	check("a Custodian's growth from 20 to 33 is hull_at(33) / hull_at(20)", "%.6f" % r[0], "%.6f" % (float(h33) / float(h20)))
	ok("grown to 33 it moves", f.regrow(33, r))
	var want := int(round(joined * float(h33) / float(h20)))
	check("its hull is the joined hull grown by that (%d to %d)" % [joined, want], f.foes[0].max_hp, want)
	check("and the damage done stays done", f.foes[0].max_hp - f.foes[0].hp, done)
	check("one ship's worth is the new hull", f.foes[0].base, h33)
	check("the fight says it is grown at 33", f.grown, 33)
	ok("and it does not grow again at the same count", not f.regrow(33, NetSession.growth_ratios(f, 33)))
	var before_join := f.foes[0].max_hp
	f.join(3)
	check("a later joiner adds nothing", f.foes[0].max_hp - before_join, 0)
	# a pilot leaving before the growth: the ratio is the same
	var g := SharedFight.open(8, PackedStringArray(["custodian"]), PackedInt32Array([h20]),
		PackedInt32Array([0]), PackedInt32Array([h20]), 1, 20)
	g.join(2)
	g.leave(2)
	g.regrow(33, NetSession.growth_ratios(g, 33))
	check("a pilot who left first does not change the ratio", g.foes[0].max_hp, want)
	# a lone Custodian lands on the hull a fight at 33 would field
	var lone := SharedFight.open(9, PackedStringArray(["custodian"]), PackedInt32Array([h20]),
		PackedInt32Array([0]), PackedInt32Array([h20]), 1, 20)
	lone.regrow(33, NetSession.growth_ratios(lone, 33))
	check("a lone Custodian grown to 33 is hull_at(33)", lone.foes[0].max_hp, h33)
	# nothing that does not grow moves, and a fight with no count never does
	var cut := SharedFight.open(10, PackedStringArray(["cutter"]), PackedInt32Array([40]),
		PackedInt32Array([0]), PackedInt32Array([40]), 1, 20)
	cut.regrow(33, NetSession.growth_ratios(cut, 33))
	check("a cutter's hull does not grow", cut.foes[0].max_hp, 40)
	var none := SharedFight.open(11, PackedStringArray(["custodian"]), PackedInt32Array([h20]),
		PackedInt32Array([0]), PackedInt32Array([h20]), 1)
	ok("a fight with no grown count does not grow", not none.regrow(33, NetSession.growth_ratios(none, 33)))
	# Asleep or capped counts grow no hull but the fight's count still rises.
	var h7 := cust.hull_at(7)
	var asleep := SharedFight.open(12, PackedStringArray(["custodian"]), PackedInt32Array([h7]),
		PackedInt32Array([0]), PackedInt32Array([h7]), 1, 7)
	var asleep_moved := asleep.regrow(8, NetSession.growth_ratios(asleep, 8))
	ok("asleep, 7 to 8 moves nothing (%s, %d hull), its count 8" % [asleep_moved, asleep.foes[0].max_hp],
		not asleep_moved and asleep.foes[0].max_hp == h7 and asleep.grown == 8)
	ok("and 8 to 16, the wake, does (%d)" % asleep.foes[0].max_hp,
		asleep.regrow(16, NetSession.growth_ratios(asleep, 16)) and asleep.foes[0].max_hp == cust.hull_at(16))
	var capped := SharedFight.open(13, PackedStringArray(["custodian"]), PackedInt32Array([h33]),
		PackedInt32Array([0]), PackedInt32Array([h33]), 1, 33)
	var capped_moved := capped.regrow(40, NetSession.growth_ratios(capped, 40))
	ok("past the cap, 33 to 40 moves nothing (%s, %d hull), its count 40" % [capped_moved, capped.foes[0].max_hp],
		not capped_moved and capped.foes[0].max_hp == h33 and capped.grown == 40)
	print("  a Custodian opened at 20 jumps with a joiner went %d -> %d at 33, %d hull of damage kept" % [joined, want, done])


## THE LEAD SHIP'S COUNT, folded by the host (PROTOCOL 16): a max, never lower,
## clamped, and only in a dive and from a report that says something.
func _growth_fold_test() -> void:
	var host := _make_peer("folder")
	var t := DirectTransport.new()
	t.port = PORT_BASE + 34
	t.advertise = "127.0.0.1"
	host.host_party("Kevin", &"", t)
	var kept_party := Run.party_jumps
	Run.party_jumps = 0
	host._fold_growth(9)
	check("the host folds nothing before the dive", host.galaxy_jumps, 0)
	host.dive_seed = Run.galaxy_seed
	host._set_state(NetSession.State.DIVING)
	host._fold_growth(9)
	check("in the dive a report raises the count", host.galaxy_jumps, 9)
	check("and the host's own copy", Run.party_jumps, 9)
	host._fold_growth(4)
	check("a ship behind the lead adds nothing", host.galaxy_jumps, 9)
	host._fold_growth(-1)
	check("nor does a report that says nothing", host.galaxy_jumps, 9)
	host._fold_growth(9)
	check("and the same report twice is once", host.galaxy_jumps, 9)
	host._fold_growth(123456)
	check("a wild one is clamped", host.galaxy_jumps, SharedFight.MAX_GROWN)
	host._set_state(NetSession.State.HOSTING)
	host.galaxy_jumps = 3
	host._fold_growth(50)
	check("out of the dive it is not folded", host.galaxy_jumps, 3)
	# and _my_jumps says nothing out of a dive, or in another galaxy
	check("a ship out of a dive says no jumps", host._my_jumps(), -1)
	host._set_state(NetSession.State.DIVING)
	host.dive_seed = Run.galaxy_seed + 1
	check("nor one in another galaxy (a NEW RUN while diving)", host._my_jumps(), -1)
	host.dive_seed = Run.galaxy_seed
	check("but one on the dive's galaxy says its own", host._my_jumps(), Run.jumps)
	# A pilot on NEW RUN is in another galaxy: only the session's copy of the count moves.
	var kept_seen := Run.custodian_seen
	Run.party_jumps = 0
	Run.custodian_seen = 0
	host.galaxy_jumps = 3
	host.dive_seed = Run.galaxy_seed + 1
	host._fold_growth(20)
	ok("a host on a NEW RUN's galaxy folds 20 into the session (%d) and not into its run (%d)" % [
		host.galaxy_jumps, Run.party_jumps], host.galaxy_jumps == 20 and Run.party_jumps == 0)
	var guest := _make_peer("newrun")
	guest._set_state(NetSession.State.DIVING)
	guest.dive_seed = Run.galaxy_seed + 1
	guest._push_growth_to(26, false)
	guest._push_growth_to(30, true)
	ok("a guest on a NEW RUN's galaxy takes pushes of 26 and 30 into the session (%d) and keeps its run's at 0, seen 0 (%d, %d)" % [
		guest.galaxy_jumps, Run.party_jumps, Run.custodian_seen],
		guest.galaxy_jumps == 30 and Run.party_jumps == 0 and Run.custodian_seen == 0)
	guest.dive_seed = Run.galaxy_seed
	guest._push_growth_to(31, false)
	check("on the dive's galaxy the push is the run's", Run.party_jumps, 31)
	print("  the host folded 9, 4, -1, 9 and 123456 to %d; out of the dive it kept 3" % SharedFight.MAX_GROWN)
	Run.party_jumps = kept_party
	Run.custodian_seen = kept_seen
	await _teardown()


## And the same rules across three machines.
func _fight_net_test() -> void:
	var host := _make_peer("host")
	var t := DirectTransport.new()
	t.port = PORT_BASE + 7
	t.advertise = "127.0.0.1"
	var code := host.host_party("Vela", &"redline", t)
	var others: Array = []
	for i in 2:
		var c := _make_peer("fc%d" % i)
		c.join_party(code, "Pilot%d" % i, &"korvan", DirectTransport.new())
		others.append(c)
	var joined := await _wait_until(func() -> bool:
		if host.party_size() != 3:
			return false
		for c in others:
			if c.party_size() != 3:
				return false
		return true, 5.0)
	ok("three ships in the party", joined)
	if not joined:
		await _teardown()
		return

	var foe: StringName = DB.enemies.keys()[0]
	var ids := PackedStringArray([String(foe)])

	# A client engages first. It does NOT get to decide it is first — the host
	# does — so this is the ask-and-wait path, not the fire-and-forget one.
	var mine: SharedFight = await others[0].open_fight(
		214, ids, PackedInt32Array([100]), PackedInt32Array([0]),
		PackedInt32Array([100]))
	ok("a client can open a fight", mine != null and mine.crew.size() == 1)
	var spread := await _wait_until(func() -> bool:
		return host.fight_open_at(214) and others[1].fight_open_at(214), 4.0)
	ok("and the whole party can see it", spread)

	# The second and third ships walk into a fight that already exists. One
	# frigate, not three.
	await host.open_fight(214, ids, PackedInt32Array([100]), PackedInt32Array([0]),
		PackedInt32Array([100]))
	await others[1].open_fight(214, ids, PackedInt32Array([100]),
		PackedInt32Array([0]), PackedInt32Array([100]))
	var all_in := await _wait_until(func() -> bool:
		var f: SharedFight = others[0].fight_at(214)
		return f != null and f.crew.size() == 3, 4.0)
	ok("everybody who arrives joins the one fight", all_in)
	check("and it is one frigate, as built", host.fight_at(214).foes[0].max_hp, 100)
	print("  three ships walked into one fight; the frigate stayed %d"
		% host.fight_at(214).foes[0].max_hp)

	# A client's gun reaches the host AND the other client, which is the half a
	# host-only check would miss.
	others[1].hurt_foe(214, 0, 20, 1)
	var hit := await _wait_until(func() -> bool:
		return others[0].fight_at(214).foes[0].hp == 80, 4.0)
	ok("one ship's shot lands on everybody's copy of the enemy", hit)
	check("stamped with who fired it",
		others[0].fight_at(214).last_hit[0], others[1].local_id())

	# The barrier, across the wire.
	others[0].report_end_turn(214)
	others[1].report_end_turn(214)
	await _wait_frames(12)
	check("two of three ending does not move the turn",
		others[0].fight_at(214).turn, 1)
	check("and the fight is still waiting on the host",
		host.fight_at(214).waiting_on()[0], 1)
	host.report_end_turn(214)
	var advanced := await _wait_until(func() -> bool:
		return others[0].fight_at(214).turn == 2 \
			and others[1].fight_at(214).turn == 2, 4.0)
	ok("the last one moves the turn for the whole party", advanced)

	# And a ship that drops out mid-turn must not stall the rest of them.
	others[0].report_end_turn(214)
	host.report_end_turn(214)
	await _wait_frames(8)
	check("still turn 2 with one ship out", host.fight_at(214).turn, 2)
	others[1].leave_fight(214)
	var released := await _wait_until(func() -> bool:
		return host.fight_at(214).turn == 3, 4.0)
	ok("a ship leaving releases the barrier rather than hanging it", released)

	# Killing it ends it for everyone at once, which is what pays everyone.
	others[0].hurt_foe(214, 0, 999, 1)
	var over := await _wait_until(func() -> bool:
		var a: SharedFight = others[0].fight_at(214)
		var b: SharedFight = host.fight_at(214)
		return a != null and b != null and a.over and b.over, 4.0)
	ok("the host declares the kill and the party hears it", over)

	# Targeting. Read straight off the roster's heat, so this needs no fight.
	_targeting_test(host)
	await _teardown()


## Two ships on one loopback: the host, and a guest with the given name.
func _party_of_two(port: int, guest_name: String = "Pilot0") -> Array:
	var host := _make_peer("host")
	var t := DirectTransport.new()
	t.port = port
	t.advertise = "127.0.0.1"
	var code := host.host_party("Vela", &"redline", t)
	var guest := _make_peer("guest")
	guest.join_party(code, guest_name, &"korvan", DirectTransport.new())
	var joined := await _wait_until(func() -> bool:
		return host.party_size() == 2 and guest.party_size() == 2, 5.0)
	ok("two ships in the party", joined)
	return [host, guest] if joined else []


## The first template whose loop (or pool) holds an intent with `field` set, and which one.
func _intent_with(field: String, in_pool: bool) -> Array:
	for t: EnemyTemplate in DB.enemies.values():
		if t.boss or t.miniboss:
			continue
		var list: Array[IntentData] = t.pool if in_pool else t.loop
		for k in list.size():
			if int(list[k].get(field)) > 0:
				return [String(t.id), k]
	return []


## The enemy keeps its own block and heal, and a host that dies mid-swing does not swing twice.
## Why: docs/why/NetTest.md#enemy-turn
func _swing_test() -> void:
	if Run.map.is_empty():
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var pair := await _party_of_two(PORT_BASE + 50)
	if pair.is_empty():
		await _teardown()
		return
	var host: NetSession = pair[0]
	var guest: NetSession = pair[1]
	var juke := _intent_with("block", false)
	var song := _intent_with("heal", true)
	ok("an enemy that blocks and one that heals exist", juke.size() == 2 and song.size() == 2)
	if juke.size() != 2 or song.size() != 2:
		await _teardown()
		return
	var places: Array[int] = []
	for n: MapGen.MapNode in Run.map:
		if n.danger >= 3 and places.size() < 12:
			places.append(n.index)
	var ids := PackedStringArray([juke[0], song[0]])
	var swung := false
	for at in places:
		var danger: int = Run.map[at].danger
		host.open_fight(at, ids, PackedInt32Array([100, 100]), PackedInt32Array([0, 0]), PackedInt32Array([100, 100]))
		await guest.open_fight(at, ids, PackedInt32Array([100, 100]), PackedInt32Array([0, 0]), PackedInt32Array([100, 100]))
		var f: SharedFight = host.fight_at(at)
		f.foes[0].kind = SharedFight.Pick.LOOP
		f.foes[0].pick = juke[1]
		f.foes[1].kind = SharedFight.Pick.POOL
		f.foes[1].pick = song[1]
		f.foes[1].hp -= 40
		var hp_before := f.foes[1].hp
		var raw: Array[IntentData] = (DB.enemies[StringName(juke[0])] as EnemyTemplate).loop
		var raw_song: Array[IntentData] = (DB.enemies[StringName(song[0])] as EnemyTemplate).pool
		var block: int = int(round(raw[juke[1]].block * (1.0 + (danger - 1) * 0.05)))
		var heal: int = int(round(raw_song[song[1]].heal * (1.0 + (danger - 1) * 0.05)))
		# The host leaves from inside the first swing that lands on it, as a killing blow does.
		var swings: Array[int] = [0]
		var left: Array[bool] = [false]
		var on_swing := func(a: int, _w: int, _k: int, _p: int) -> void:
			if a != at:
				return
			swings[0] += 1
			if not left[0]:
				left[0] = true
				host.leave_fight(at)
		Sig.party_fight_swing.connect(on_swing)
		guest.report_end_turn(at)
		await _wait_until(func() -> bool: return f.ended.has(guest.local_id()), 4.0)
		host.report_end_turn(at)
		await _wait_frames(12)
		Sig.party_fight_swing.disconnect(on_swing)
		if not left[0]:
			host.leave_fight(at)
			guest.leave_fight(at)
			continue
		swung = true
		check("the enemy's block is granted on the host (danger %d)" % danger, f.foes[0].block, block)
		check("and its heal", f.foes[1].hp, mini(f.foes[1].max_hp, hp_before + heal))
		ok("block is real: a shot is soaked by it", f.hurt(0, 2, 1, guest.local_id()) == 0 and f.foes[0].block == block - 2)
		check("the swing that the host's death interrupted ran once", f.turn, 2)
		check("each foe swung once, not again at the partner", swings[0], 2)
		print("  danger %d: Juke gave %d block, the song %d hull; the turn went 1 -> %d with %d swings" % [
			danger, block, heal, f.turn, swings[0]])
		break
	ok("a swing landed on the host in twelve tries", swung)
	await _teardown()


## A peer that skipped the handshake, or that sends what no ship could, changes nothing.
## Why: docs/why/NetTest.md#hostile-peer
func _hostile_peer_test() -> void:
	if Run.map.is_empty():
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var pair := await _party_of_two(PORT_BASE + 51, "[font_size=400]" + "x".repeat(40))
	if pair.is_empty():
		await _teardown()
		return
	var host: NetSession = pair[0]
	var guest: NetSession = pair[1]
	var gid := guest.local_id()
	check("a long name with markup is cut to the cap", host.name_of(gid).length(), NetSession.NAME_MAX)

	# Not on the roster: the sender of a direct call is 0, as a peer that never said hello is.
	host._claim_at_host(3, 7)
	ok("a message from a stranger is ignored", not host.claims.has(3))

	# The checks below read the dive's galaxy, so say this host is in it.
	host.dive_seed = Run.galaxy_seed if Run.galaxy_seed != 0 else 1
	Run.galaxy_seed = host.dive_seed
	host.state = NetSession.State.DIVING
	var last := Run.map.size() - 1
	host._apply_claim(-5, 3, gid)
	host._apply_claim(99999, 3, gid)
	host._apply_claim(1, -3, gid)
	host._apply_claim(1, NetSession.OPTION_MAX + 1, gid)
	ok("a claim off the map or past the options is dropped", host.claims.is_empty())
	host._apply_claim(last, MapGen.OPTION_SHOP, gid)
	check("a real claim still lands", host.who_took(last, MapGen.OPTION_SHOP), gid)
	var full := {}
	for o in NetSession.CLAIMS_PER_NODE:
		full[o] = gid
	host.claims[2] = full
	host._apply_claim(2, NetSession.CLAIMS_PER_NODE + 5, gid)
	check("a system's claim table stops growing", host.claims[2].size(), NetSession.CLAIMS_PER_NODE)

	var ids := PackedStringArray([String(DB.enemies.keys()[0])])
	var ten := PackedInt32Array([10])
	var none := PackedInt32Array([0])
	var lots := PackedInt32Array()
	lots.resize(100000)
	lots.fill(10)
	host._open_or_join(4, ids, lots, lots, lots, 0, gid)
	host._open_or_join(5, PackedStringArray(), PackedInt32Array(), none, none, 0, gid)
	host._open_or_join(6, PackedStringArray(["nobody"]), ten, none, ten, 0, gid)
	host._open_or_join(7, ids, PackedInt32Array([2000000000]), none, ten, 0, gid)
	host._open_or_join(99999, ids, ten, none, ten, 0, gid)
	ok("a fight opened with junk is never made", host.fights.is_empty())
	host._open_or_join(8, ids, ten, none, ten, 0, gid)
	ok("a real one still opens", host.fight_open_at(8))

	var at0 := int(host.roster[gid].at)
	var party0 := Run.party_jumps
	host._apply_presence(gid, {}, 99999, 3)
	check("a presence at no system is dropped", int(host.roster[gid].at), at0)
	host._apply_presence(gid, {}, last, 3)
	check("a real one lands", int(host.roster[gid].at), last)
	# (docked at a station: LOCAL leaves it off the column, and shows it dock and undock)
	host._apply_presence(gid, {}, last, 3, true)
	ok("a presence docked says so", bool(host.roster[gid].get("docked", false)))
	host._apply_presence(gid, {}, last, 3)
	ok("and one undocked says so", not bool(host.roster[gid].get("docked", true)))
	Run.party_jumps = party0

	host._apply_spot(gid, 1, 0, 0.0, 0.0, 0.0, INF, 0)
	host._apply_spot(gid, 1, 0, NAN, 0.0, 0.0, 5.0, 0)
	ok("a spot that is not a number is dropped", not host.spots.has(gid))
	host._apply_spot(gid, 1, 0, 0.0, 0.0, 0.0, 1.0e30, 0)
	check("a clock far past play is held to the cap", float(host.spots[gid].t), NetSession.MAP_CLOCK_MAX)

	# The other way: what a host says to its guests. A bad row is skipped, not a crash.
	var hb_at := Run.hellbender_at
	var hb_moves := Run.hellbender_moves
	var hb_hp := Run.hellbender_hp
	Run.hellbender_adopt(999999, 5, -3, false)
	check("a hellbender somewhere off the map is not followed", Run.hellbender_at, hb_at)
	check("and its count never goes below nothing", Run.hellbender_moves, 0)
	Run.hellbender_moves = hb_moves
	Run.hellbender_hp = hb_hp
	guest._push_roster_to([5, {}, {"id": 9999, "name": "Late"}])
	check("a roster with bad rows keeps the good one", guest.roster.keys(), [9999])
	print("  a stranger, a bad claim, fight, presence, spot, name and roster row: all refused, the real ones kept")
	await _teardown()


## A shelf part is not offered to a ship that cannot hold it, so it is never paid for and lost.
func _bot_shelf_test() -> void:
	var wide: ModuleData = null
	for m: ModuleData in DB.modules.values():
		if m.size.x * m.size.y >= 2:
			wide = m
			break
	ok("a part wider than one cell exists", wide != null)
	if wide == null or Run.hull == null:
		return
	var node: MapGen.MapNode = Run.node_at()
	var shop0 := node.shop
	var credits0 := Run.credits
	node.shop = [wide]
	Run.credits = 100000
	ok("an empty hold is offered the part", "buy 0" in BotBoard.station(1).moves)
	var filler: Array[HoldItem] = []
	while Run.cargo_slots() - Run.cargo_used() > 1:
		var one := ModuleData.new()
		filler.append(one)
		if not Run.place_in_hold(one):
			break
	ok("a hold with one cell free is not offered it", not ("buy 0" in BotBoard.station(2).moves))
	for one in filler:
		Run.take_from_hold(one)
	node.shop = shop0
	Run.credits = credits0


## The rule is `0.5 + heat_ratio`: heat matters in a fight, and the floor stops electing a victim.
## Why: docs/why/NetTest.md#targeting
func _targeting_test(host: NetSession) -> void:
	var f := SharedFight.open(9, PackedStringArray(["x"]),
		PackedInt32Array([10]), PackedInt32Array([0]), PackedInt32Array([10]), 1)
	var cold := 0
	var hot := 0
	for id in host.roster.keys():
		if int(id) == 1:
			continue
		if cold == 0:
			cold = int(id)
		elif hot == 0:
			hot = int(id)
	if cold == 0 or hot == 0:
		ok("two partners to aim at", false)
		return
	f.crew = PackedInt32Array([cold, hot])
	host.roster[cold].build = {"manufacturer": &"redline", "weight": 1, "parts": [],
		"hp": 30, "max_hp": 30, "heat": 0, "heat_cap": 10, "dead": false}
	host.roster[hot].build = {"manufacturer": &"solari", "weight": 1, "parts": [],
		"hp": 30, "max_hp": 30, "heat": 17, "heat_cap": 10, "dead": false}
	var tally := {cold: 0, hot: 0}
	for i in 4000:
		var who: int = host._who_gets_hit(f)
		tally[who] = int(tally.get(who, 0)) + 1
	var ratio := float(tally[hot]) / maxf(1.0, float(tally[cold]))
	# 2.2 against 0.5 is 4.4. Wide bounds: this is checking that heat is the
	# dial, not pinning the constant.
	print("  the redlining ship drew %.1fx the fire (%d hot / %d cold of 4000)"
		% [ratio, tally[hot], tally[cold]])
	ok("a redlining ship draws about four times the fire", ratio > 3.2 and ratio < 5.8)
	ok("and a cold ship is never safe", tally[cold] > 400)


# --- the same-second race (Nov 5) -------------------------------------------

## The asker takes the host's answer: a private plan left mismatched hulls and a softlock (Nov 5).
## Why: docs/why/NetTest.md#fight-race
func _race_test() -> void:
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var host := _make_peer("rhost")
	var t := DirectTransport.new()
	t.port = PORT_BASE + 40
	t.advertise = "127.0.0.1"
	var code := host.host_party("Vela", &"redline", t)
	var g: Array = []
	for i in 2:
		var c := _make_peer("rg%d" % i)
		c.join_party(code, "Race%d" % i, &"korvan", DirectTransport.new())
		g.append(c)
	var seated := await _wait_until(func() -> bool:
		return host.party_size() == 3 and g[0].party_size() == 3 and g[1].party_size() == 3, 5.0)
	ok("(race) three ships in the party", seated)
	if not seated:
		await _teardown()
		return
	var cutter: EnemyTemplate = DB.enemies[&"cutter"]
	var lancer: EnemyTemplate = DB.enemies[&"lancer"]
	var hulk: EnemyTemplate = DB.enemies[&"hulk"]
	var marauder: EnemyTemplate = DB.enemies[&"marauder"]

	# Host first in one frame: its own open has no await between the check and the ask.
	var x: Combat = _plan_race(cutter, [lancer])
	await host.open_fight(401, x.foe_ids(), x.foe_hp(), x.foe_brace(), x.foe_hp_now(), x.grown)
	var y: Array = await _ask_race(g[0], 401, hulk, [])
	await _takes_answer("host first: the guest planned one hull, the host holds two", y[0], y[1], g[0], 401,
		PackedStringArray(["cutter", "lancer"]))

	# Guest first: this is the answer path itself, and it runs on the host too.
	var gy: Array = [null, null]
	_ask_race_into(g[0], 402, marauder, [], gy)
	await _wait_until(func() -> bool: return host.fight_open_at(402), 4.0)
	var hx: Array = await _ask_race(host, 402, cutter, [hulk])
	await _wait_until(func() -> bool: return gy[1] != null, 4.0)
	await _takes_answer("guest first: the host planned two hulls, the guest's fight has one", hx[0], hx[1], host, 402,
		PackedStringArray(["marauder"]))
	await _takes_answer("and the guest that opened it keeps its own", gy[0], gy[1], g[0], 402,
		PackedStringArray(["marauder"]))

	# TWO GUESTS IN ONE FRAME, both orders: neither knows about the other, and
	# whichever ask the host reads first is the fight.
	for order in [[0, 1], [1, 0]]:
		var at: int = 403 + int(order[0])
		var plans := [[lancer, [hulk]], [marauder, []]]
		var outs: Array = [[null, null], [null, null]]
		for k in order:
			var p: Array = plans[k]
			_ask_race_into(g[k], at, p[0], p[1], outs[k])
		var both := await _wait_until(func() -> bool:
			return outs[0][1] != null and outs[1][1] != null, 5.0)
		ok("(race) two guests in one frame (Race%d first): both are answered" % order[0], both)
		if not both:
			continue
		var want: PackedStringArray = (outs[0][1] as SharedFight).foe_ids
		check("(race) and it is one fight, not two (Race%d first)" % order[0],
			(outs[1][1] as SharedFight).foe_ids, want)
		for k in 2:
			await _takes_answer("two guests (Race%d first): Race%d takes it" % [order[0], k],
				outs[k][0], outs[k][1], g[k], at, want)

	# A ship that left and asks again is a new arrival, never handed the copy it left.
	var before: int = host.fight_at(401).foes[0].max_hp
	var again: Array = await _ask_race(g[0], 401, cutter, [lancer])
	var fa: SharedFight = again[1]
	ok("(race) a repeat ask is answered with the fight it is in",
		fa != null and fa.foe_ids == PackedStringArray(["cutter", "lancer"]))
	check("(race) and grows nothing", host.fight_at(401).foes[0].max_hp, before)
	check("(race) and seats it once", Array(host.fight_at(401).crew).count(g[0].local_id()), 1)
	# The host always answers (review, Nov 5), or an ask met with silence waited for ever.
	g[0].fights.erase(401)
	var mute: Array = [null, null, -1.0]
	_ask_race_into(g[0], 401, cutter, [lancer], mute)
	var heard := await _wait_until(func() -> bool: return mute[1] != null, 3.0)
	ok("(race) the host answers a ship it has already seated, whatever its copy says", heard)
	if not heard:
		g[0].fights[401] = SharedFight.from_wire(host.fight_at(401).to_wire())
	check("(race) and grows nothing for it", host.fight_at(401).foes[0].max_hp, before)
	g[0].leave_fight(401)
	# At once, before the host has heard: on a real link the host's push of the
	# leave is a round trip away, and the ask below checks this copy first
	ok("(race) a ship that leaves stops counting itself in its own copy at once",
		not g[0].fight_at(401).crew.has(g[0].local_id()))
	var back: Array = await _ask_race(g[0], 401, cutter, [lancer])
	var fb: SharedFight = back[1]
	check("(race) a ship that left and asks again is answered, grown by nothing (%d)" % before,
		fb.foes[0].max_hp if fb != null else -1, before)
	ok("(race) and on turn 1 it is not stunned", fb != null and not fb.stunned.has(g[0].local_id()))
	var in_once := await _wait_until(func() -> bool:
		return Array(host.fight_at(401).crew).count(g[0].local_id()) == 1, 3.0)
	ok("(race) and is in the host's crew once", in_once)

	# Alone in a fight, leaving ends it in the copy at once (review, Nov 5), or JOIN offered it.
	var solo: Array = await _ask_race(g[1], 412, cutter, [])
	ok("(race) a ship opens a fight alone", solo[1] != null and (solo[1] as SharedFight).crew.size() == 1)
	g[1].leave_fight(412)
	var mine: SharedFight = g[1].fight_at(412)
	ok("(race) and leaving it ends it in its own copy at once (over %s, crew %s)" % [
		str(mine.over), str(mine.crew)], mine.over and mine.crew.is_empty() and not g[1].fight_open_at(412))
	await _wait_until(func() -> bool: return host.fight_at(412).over, 3.0)

	# A slow answer must wait while the link is up, or the guest fights a private enemy copy.
	# Why: docs/why/NetTest.md#fight-race
	host.hold_asks = true
	var slow: Array = [null, null, -1.0]
	var t0 := Time.get_ticks_msec()
	_ask_race_into(g[1], 410, cutter, [], slow)
	await _wait_until(func() -> bool: return slow[1] != null or slow[2] >= 0.0,
		NetSession.TAKE_TIMEOUT + 1.0)
	ok("(race) an ask the host holds past %.0f s is still waiting, not answered null (%s after %d ms)" % [
		NetSession.TAKE_TIMEOUT, "null" if slow[2] >= 0.0 else "waiting",
		Time.get_ticks_msec() - t0], slow[2] < 0.0 and slow[1] == null)
	host.release_asks()
	var late := await _wait_until(func() -> bool: return slow[1] != null, 4.0)
	ok("(race) and the late answer is taken: the guest is in the host's fight",
		late and (slow[1] as SharedFight).crew.has(g[1].local_id()))
	# ...and comes back null only when the link is gone, which is when fighting
	# alone is the right answer
	var lost: Array = [null, null, -1.0]
	_ask_race_into(g[1], 411, cutter, [], lost)
	await _wait_frames(30)
	ok("(race) a held ask is still waiting while the link is up", lost[2] < 0.0)
	host.leave_party()
	var dropped := await _wait_until(func() -> bool: return lost[2] >= 0.0, 6.0)
	ok("(race) and returns null once the host is gone", dropped and lost[1] == null)
	host.hold_asks = false
	await _teardown()


# --- joining late, stunned (PROTOCOL 18) -----------------------------------

## THE STUN'S RULES, with no wire (Jon, Nov 5): "They would enter the fight
## with a stunned condition until the enemy's turn is over (even if they join
## right at the end of the enemy's turn)." and "If other players in co op join
## on the FIRST player's turn of a fight they are not stunned."
func _stun_rules_test() -> void:
	var f := SharedFight.open(60, PackedStringArray(["cutter"]), PackedInt32Array([100]),
		PackedInt32Array([0]), PackedInt32Array([100]), 1)
	f.join(2)
	ok("(stun) a ship that walks in on turn 1 is not stunned", not f.stunned.has(2) and not f.ended.has(2))
	f.hurt(0, 10, 1, 1)
	f.end_turn(1)
	f.join(3)
	ok("(stun) nor one that walks in on turn 1 after a partner fired and ended: the first turn never stuns",
		not f.stunned.has(3) and f.waiting_on().has(3))
	check("(stun) and nothing grows for either", f.foes[0].max_hp, 100)
	f.end_turn(2)
	ok("(stun) turn 1 closes on the last ship", f.end_turn(3))
	f.advance()
	# turn 2, before anyone has acted: "even if they join right at the end of
	# the enemy's turn", which on the host is the start of the next
	f.join(4)
	ok("(stun) a ship that walks in on turn 2, before anyone acts, is stunned", f.stunned.has(4))
	ok("(stun) and counted as ended", f.ended.has(4))
	ok("(stun) and the turn never waits on it (%s)" % str(f.waiting_on()), not f.waiting_on().has(4))
	ok("(stun) its own END TURN does nothing", not f.end_turn(4))
	f.end_turn(1)
	f.end_turn(2)
	ok("(stun) the last unstunned END TURN closes the turn", f.end_turn(3))
	f.advance()
	ok("(stun) the enemy's turn over, every stun clears (%s)" % str(f.stunned), f.stunned.is_empty())
	ok("(stun) and turn 3 waits on it like anyone", f.waiting_on().has(4))
	# mid-turn, after a hit: stunned; then it leaves
	f.hurt(0, 5, 1, 2)
	f.join(5)
	ok("(stun) a ship that walks in mid-turn after a hit is stunned", f.stunned.has(5))
	f.leave(5)
	ok("(stun) and leaving takes it out of the crew, the ended and the stunned",
		not f.crew.has(5) and not f.ended.has(5) and not f.stunned.has(5))
	# a third and fourth stunned together clear together
	f.join(6)
	f.join(7)
	ok("(stun) two late ships, both stunned", f.stunned.has(6) and f.stunned.has(7))
	f.advance()
	ok("(stun) and both clear at the same advance", f.stunned.is_empty())
	# only stunned ships left: nobody to wait on
	var g := SharedFight.open(61, PackedStringArray(["cutter"]), PackedInt32Array([40]),
		PackedInt32Array([0]), PackedInt32Array([40]), 1)
	g.end_turn(1)
	g.advance()
	g.join(9)
	g.leave(1)
	ok("(stun) with only a stunned ship left, nobody is waited on", g.waiting_on().is_empty() and not g.over)
	# the wire
	var w := SharedFight.from_wire(f.to_wire())
	f.join(8)
	var w8 := SharedFight.from_wire(f.to_wire())
	check("(stun) the stun round-trips", str(w8.stunned), str(f.stunned))
	ok("(stun) an empty stun reads empty", w.stunned.is_empty())
	check("(stun) a fight with no stun on the wire reads none", SharedFight.from_wire({"at": 3, "crew": [1, 2]}).stunned.size(), 0)
	var stranger := SharedFight.from_wire({"at": 3, "crew": PackedInt32Array([1, 2]), "stun": PackedInt32Array([2, 99])})
	check("(stun) a stunned ship not in the crew is dropped", str(stranger.stunned), str(PackedInt32Array([2])))
	# it can be shot: the only ship in the room is stunned, and it is the target
	var s := _make_peer("stunhit")
	var h := SharedFight.open(62, PackedStringArray(["cutter"]), PackedInt32Array([40]),
		PackedInt32Array([0]), PackedInt32Array([40]), 1)
	h.advance()
	h.join(9)
	h.leave(1)
	check("(stun) a stunned ship can be shot: the host's pick lands on it", s._who_gets_hit(h), 9)
	s.forced_target = 9
	var k := SharedFight.open(63, PackedStringArray(["cutter"]), PackedInt32Array([40]),
		PackedInt32Array([0]), PackedInt32Array([40]), 1)
	k.advance()
	k.join(9)
	check("(stun) and the test's forced target picks it among others", s._who_gets_hit(k), 9)
	s.forced_target = 0


## THE STUN ACROSS THREE MACHINES (PROTOCOL 18).
func _stun_net_test() -> void:
	var host := _make_peer("shost")
	var t := DirectTransport.new()
	t.port = PORT_BASE + 41
	t.advertise = "127.0.0.1"
	var code := host.host_party("Vela", &"redline", t)
	var g: Array = []
	for i in 2:
		var c := _make_peer("sg%d" % i)
		c.join_party(code, "Late%d" % i, &"korvan", DirectTransport.new())
		g.append(c)
	var seated := await _wait_until(func() -> bool:
		return host.party_size() == 3 and g[0].party_size() == 3 and g[1].party_size() == 3, 5.0)
	ok("(stun-net) three ships in the party", seated)
	if not seated:
		await _teardown()
		return
	var id0: int = g[0].local_id()
	var id1: int = g[1].local_id()
	var swings: Array = []
	var hear := func(at: int, which: int, _k: int, _p: int) -> void: swings.append([at, which])
	Sig.party_fight_swing.connect(hear)
	var cutter: EnemyTemplate = DB.enemies[&"cutter"]

	# Late0 opens with the host on turn 1; the host fires; Late0 walks in: not
	# stunned. The turn moves on two END TURNs; then Late1 walks in on turn 2.
	host.forced_target = 1
	await _ask_race(host, 310, cutter, [])
	host.hurt_foe(310, 0, 5, 1)
	var a: Array = await _ask_race(g[0], 310, cutter, [])
	ok("(stun-net) a ship walking in on turn 1 after a shot is seated, not stunned",
		a[1] != null and (a[1] as SharedFight).crew.has(id0) and not (a[1] as SharedFight).stunned.has(id0))
	host.report_end_turn(310)
	g[0].report_end_turn(310)
	ok("(stun-net) the turn moves", await _wait_until(func() -> bool: return g[1].fight_at(310) != null and g[1].fight_at(310).turn == 2, 4.0))
	var b: Array = await _ask_race(g[1], 310, cutter, [])
	var all_see := await _wait_until(func() -> bool:
		for s: NetSession in [host, g[0], g[1]]:
			var f: SharedFight = s.fight_at(310)
			if f == null or not f.stunned.has(id1) or not f.ended.has(id1):
				return false
		return true, 4.0)
	ok("(stun-net) a ship walking in on turn 2 is stunned on every copy", b[1] != null and all_see)
	ok("(stun-net) and the host does not wait on it (%s)" % str(host.fight_at(310).waiting_on()),
		not host.fight_at(310).waiting_on().has(id1))
	g[1].report_end_turn(310)
	await _wait_frames(8)
	ok("(stun-net) its END TURN is ignored: still turn 2, and it is still stunned",
		host.fight_at(310).turn == 2 and host.fight_at(310).stunned.has(id1))
	host.report_end_turn(310)
	g[0].report_end_turn(310)
	var moved := await _wait_until(func() -> bool:
		for s: NetSession in [host, g[0], g[1]]:
			var f: SharedFight = s.fight_at(310)
			if f == null or f.turn != 3 or not f.stunned.is_empty():
				return false
		return true, 4.0)
	ok("(stun-net) the turn moves without it, and its stun clears everywhere", moved)
	ok("(stun-net) turn 3 waits on it", host.fight_at(310).waiting_on().has(id1))

	# ONLY A STUNNED SHIP LEFT: the opener leaves, the barrier closes at once,
	# and the swing goes to the stunned ship (forced), which takes that enemy
	# turn; the turn moves and it acts
	await _ask_race(host, 311, cutter, [])
	host.report_end_turn(311)
	await _ask_race(g[0], 311, cutter, [])
	ok("(stun-net) a second fight: Late0 walks in on turn 2, stunned", host.fight_at(311).stunned.has(id0))
	host.forced_target = id0
	swings.clear()
	host.leave_fight(311)
	var alone := await _wait_until(func() -> bool:
		var f: SharedFight = g[0].fight_at(311)
		return f != null and f.turn == 3 and f.stunned.is_empty(), 4.0)
	ok("(stun-net) with only the stunned ship left the enemy swings at once and the turn moves", alone)
	ok("(stun-net) and the swing went to it (%s)" % str(swings), swings.any(func(r: Array) -> bool: return int(r[0]) == 311))

	# THE ASK AND A PARTNER'S END TURN IN ONE HOST FRAME, the swing forced to
	# the joiner: its copy is not seated yet when the swing arrives, so its
	# session holds it for the Combat to play as it begins
	await _ask_race(host, 312, cutter, [])
	host.forced_target = 1
	host.report_end_turn(312)
	host.hold_asks = true
	var late: Array = [null, null, -1.0]
	_ask_race_into(g[1], 312, cutter, [], late)
	await _wait_frames(10)
	host.forced_target = id1
	swings.clear()
	host.release_asks()
	host.report_end_turn(312)
	host.hold_asks = false
	var got := await _wait_until(func() -> bool: return late[1] != null, 4.0)
	var held: Array = g[1].take_held_swings(312) if got else []
	ok("(stun-net) the swing that came while it was asking is held, not lost (%d held, %d heard)" % [held.size(), swings.size()],
		got and held.size() == 1 and swings.filter(func(r: Array) -> bool: return int(r[0]) == 312).is_empty())
	ok("(stun-net) and taken once", g[1].take_held_swings(312).is_empty())

	# A JOIN AFTER THE KILL gets the ended fight, not a new one
	await _ask_race(host, 313, cutter, [])
	var dead_one: SharedFight = host.fight_at(313)
	host.hold_asks = true
	var ask: Array = [null, null, -1.0]
	_ask_race_into(g[0], 313, cutter, [], ask, true)
	await _wait_frames(10)
	host.hurt_foe(313, 0, 9999, 1)
	host.release_asks()
	host.hold_asks = false
	var told := await _wait_until(func() -> bool: return ask[1] != null, 4.0)
	ok("(stun-net) a JOIN after the kill is answered with the ended fight, this ship not in it",
		told and (ask[1] as SharedFight).over and not (ask[1] as SharedFight).crew.has(id0))
	ok("(stun-net) and the host opened nothing new", host.fight_at(313) == dead_one and dead_one.over)
	# while a plain start after the kill opens a new fight, as it always has
	var fresh: Array = await _ask_race(g[0], 313, cutter, [])
	ok("(stun-net) a plain start there after the kill opens a new one",
		fresh[1] != null and not (fresh[1] as SharedFight).over and host.fight_at(313) != dead_one)
	Sig.party_fight_swing.disconnect(hear)
	host.forced_target = 0
	await _teardown()


# --- the party's size (PROTOCOL 18) ------------------------------------------

## `PartyScale` alone: 1 is the solo game exactly, and the numbers grow by the
## measured shares.
func _party_scale_rules_test() -> void:
	check("(size) one player: the hull is the solo hull", PartyScale.hull(1), 1.0)
	check("(size) and the pay the solo pay", PartyScale.loot(1), 1.0)
	check("(size) two players: hull x%.2f" % PartyScale.hull(2), PartyScale.hull(2), 1.0 + PartyScale.HULL_PER)
	check("(size) four players: hull", PartyScale.hull(4), 1.0 + 3.0 * PartyScale.HULL_PER)
	check("(size) a wild count is held to the party's ceiling", PartyScale.hull(99), PartyScale.hull(NetTransport.MAX_PLAYERS))
	check("(size) pay of 40 credits for two", PartyScale.pay(40, 2), int(round(40 * PartyScale.loot(2))))
	check("(size) pay alone is untouched", PartyScale.pay(40, 1), 40)
	check("(size) a pay of 1 is never cut", PartyScale.pay(1, 2) >= 1, true)
	check("(size) the Hellbender's hull goes out for two and back for one",
		PartyScale.solo_hull(PartyScale.party_hull(150, 2), 2), 150)
	# the wire
	var f := SharedFight.open(70, PackedStringArray(["cutter"]), PackedInt32Array([80]),
		PackedInt32Array([0]), PackedInt32Array([80]), 1, -1, 2)
	check("(size) a fight's count round-trips", SharedFight.from_wire(f.to_wire()).party, 2)
	check("(size) missing reads one", SharedFight.from_wire({"at": 70}).party, 1)
	check("(size) a wild one is held to the ceiling", SharedFight.from_wire({"at": 70, "party": 999}).party, NetTransport.MAX_PLAYERS)
	check("(size) and low to one", SharedFight.from_wire({"at": 70, "party": -3}).party, 1)


## THE HOST OWNS THE COUNT: two then three then two players in a dive, the
## fights built for each, a guest's stale count scaled to the host's, and a
## fight already open keeping its numbers when a player comes or goes.
func _party_scale_net_test() -> void:
	var host := _make_peer("phost")
	var t := DirectTransport.new()
	t.port = PORT_BASE + 42
	t.advertise = "127.0.0.1"
	var code := host.host_party("Vela", &"redline", t)
	var g := _make_peer("pg0")
	g.join_party(code, "Pair", &"korvan", DirectTransport.new())
	var seated := await _wait_until(func() -> bool: return host.party_size() == 2 and g.party_size() == 2, 5.0)
	ok("(size-net) two in the party", seated)
	if not seated:
		await _teardown()
		return
	# in the dive, on this galaxy (the peers share one Run)
	for s: NetSession in [host, g]:
		s.dive_seed = Run.galaxy_seed
		s._set_state(NetSession.State.DIVING)
	check("(size-net) the host counts two", host.party_count(), 2)
	check("(size-net) and so does the guest, off the host's roster", g.party_count(), 2)
	var base := 40
	var for2 := PartyScale.party_hull(base, 2)
	var asked: SharedFight = await g.open_fight(20, PackedStringArray(["cutter"]), PackedInt32Array([for2]),
		PackedInt32Array([0]), PackedInt32Array([for2]))
	ok("(size-net) a guest's fight built for two is opened for two: hull %d, party %d" % [
		asked.foes[0].max_hp if asked != null else -1, asked.party if asked != null else -1],
		asked != null and asked.foes[0].max_hp == for2 and asked.party == 2 and host.fight_at(20).party == 2)
	# A STALE COUNT: an ask built for three reaches a host that counts two
	var for3 := PartyScale.party_hull(base, 3)
	host._open_or_join(21, PackedStringArray(["cutter"]), PackedInt32Array([for3]),
		PackedInt32Array([0]), PackedInt32Array([for3]), -1, g.local_id(), 3)
	var k := PartyScale.hull(2) / PartyScale.hull(3)
	check("(size-net) an ask built for three is scaled to the host's two",
		host.fight_at(21).foes[0].max_hp, maxi(1, int(round(for3 * k))))
	check("(size-net) and says two", host.fight_at(21).party, 2)
	# A THIRD PLAYER ARRIVES: the count is three everywhere; the open fight
	# keeps its numbers, and the next is built for three
	var third := _make_peer("pg1")
	third.join_party(code, "Third", &"korvan", DirectTransport.new())
	var three := await _wait_until(func() -> bool:
		return host.party_size() == 3 and g.party_size() == 3, 5.0)
	third.dive_seed = Run.galaxy_seed
	third._set_state(NetSession.State.DIVING)
	ok("(size-net) a third player: the host counts %d, the guest %d" % [host.party_count(), g.party_count()],
		three and host.party_count() == 3 and g.party_count() == 3)
	check("(size-net) the fight already open keeps its count", host.fight_at(20).party, 2)
	check("(size-net) and its hull", host.fight_at(20).foes[0].max_hp, for2)
	var for3b := PartyScale.party_hull(base, g.party_count())
	var next: SharedFight = await g.open_fight(22, PackedStringArray(["cutter"]), PackedInt32Array([for3b]),
		PackedInt32Array([0]), PackedInt32Array([for3b]))
	ok("(size-net) the next fight is built for three (%d, party %d)" % [
		next.foes[0].max_hp if next != null else -1, next.party if next != null else -1],
		next != null and next.party == 3 and next.foes[0].max_hp == for3)
	# AND LEAVES: back to two, the fight built for three keeps its three
	third.leave_party()
	var two := await _wait_until(func() -> bool: return host.party_count() == 2 and g.party_count() == 2, 5.0)
	ok("(size-net) the third player leaves: two again on both", two)
	check("(size-net) the fight built for three keeps its numbers", host.fight_at(22).foes[0].max_hp, for3)
	# A DEAD PILOT IS NOT A PLAYER IN THE FIGHTS TO COME (review, Nov 5): the
	# ship left meets one ship's hulls, on both machines, not two ships' alone
	var gid := g.local_id()
	var wire: Dictionary = (host.roster[gid].get("build", {}) as Dictionary).duplicate()
	if wire.is_empty():
		wire = ShipBuild.local().to_wire()
	var at_g := host.where_is(gid)
	wire["dead"] = true
	host._apply_presence(gid, wire, at_g, 0)
	var one := await _wait_until(func() -> bool: return host.party_count() == 1 and g.party_count() == 1, 5.0)
	ok("(size-net) a pilot who died is not counted: the host counts %d, the guest %d" % [host.party_count(), g.party_count()], one)
	wire["dead"] = false
	host._apply_presence(gid, wire, at_g, 0)
	two = await _wait_until(func() -> bool: return host.party_count() == 2 and g.party_count() == 2, 5.0)
	ok("(size-net) and a ship alive on the dive's galaxy counts again: %d, %d" % [host.party_count(), g.party_count()], two)
	# GONE TO A NEW RUN'S GALAXY: its presence has no jumps here to say
	host._apply_presence(gid, wire, at_g, -1)
	one = await _wait_until(func() -> bool: return host.party_count() == 1 and g.party_count() == 1, 5.0)
	ok("(size-net) a pilot gone to a NEW RUN's galaxy is not counted: the host counts %d, the guest %d" % [host.party_count(), g.party_count()], one)
	await _teardown()


## One ship's own plan, as `Router.start_combat` makes it at danger 3.
func _plan_race(lead: EnemyTemplate, extras: Array) -> Combat:
	var cb := Combat.new()
	cb.plan(lead, 3, extras)
	return cb


## Plan, ask, and hand back `[the Combat, the answer]`.
func _ask_race(session: NetSession, at: int, lead: EnemyTemplate, extras: Array,
		join_only: bool = false) -> Array:
	var cb := _plan_race(lead, extras)
	var f: SharedFight = await session.open_fight(at, cb.foe_ids(), cb.foe_hp(),
		cb.foe_brace(), cb.foe_hp_now(), cb.grown, join_only)
	return [cb, f]


## Fire and forget into `out`, for asks a test watches while they wait.
func _ask_race_into(session: NetSession, at: int, lead: EnemyTemplate, extras: Array, out: Array,
		join_only: bool = false) -> void:
	var t0 := Time.get_ticks_msec()
	var cb := _plan_race(lead, extras)
	out[0] = cb
	var f: SharedFight = await session.open_fight(at, cb.foe_ids(), cb.foe_hp(),
		cb.foe_brace(), cb.foe_hp_now(), cb.grown, join_only)
	if out.size() > 2 and f == null:
		out[2] = float(Time.get_ticks_msec() - t0)
	out[1] = f


## The asker's enemy is the host fight's, hull for hull, with the intent the host picked.
func _takes_answer(what: String, cb: Combat, f: SharedFight, session: NetSession, at: int,
		want: PackedStringArray) -> void:
	if cb == null or f == null:
		ok("(race) %s: an answer came back" % what, false)
		return
	check("(race) %s: the answer is the host's fight" % what, f.foe_ids, want)
	cb.begin(f)
	var got := PackedStringArray()
	for e in cb.enemies:
		got.append(String(e.template.id))
	check("(race) %s: the enemy built is that fight's, hull for hull" % what, got, want)
	check("(race) %s: and so is what it would tell the host" % what, cb.foe_ids(), want)
	var names := PackedStringArray()
	var host_names := PackedStringArray()
	var copy := session.fight_at(at)
	for i in copy.foes.size():
		host_names.append(_picked_name(copy, i))
		names.append(cb.enemies[i].intent.name if i < cb.enemies.size() and cb.enemies[i].intent != null else "?")
	check("(race) %s: every hull shows the intent the host picked" % what, names, host_names)
	# The kill, as a push says it: every hull at zero on the copy this ship reads
	var dead := SharedFight.from_wire(copy.to_wire())
	for e in dead.foes:
		e.hp = 0
	dead.over = true
	cb._adopt(dead)
	ok("(race) %s: when the host's hulls are all dead, so are this ship's" % what, cb.alive().is_empty())
	cb.release()
	await _tree.process_frame


## The name of the intent the host picked for hull `i`, read off the template
## the way `Combat._adopt` reads it.
func _picked_name(f: SharedFight, i: int) -> String:
	var e := f.foes[i]
	if e.kind == SharedFight.Pick.ESCAPE:
		return Combat.escape_intent().name
	var tpl: EnemyTemplate = DB.enemies.get(StringName(f.foe_ids[i]))
	if tpl == null:
		return "?"
	var list: Array[IntentData] = tpl.pool if e.kind == SharedFight.Pick.POOL else tpl.loop
	return list[e.pick].name if e.pick >= 0 and e.pick < list.size() else "?"


# --- one process, four multiplayer roots ----------------------------------

## A friend joining after launch is handed seed, unlocks, used-up systems and the open fight.
## Why: docs/why/NetTest.md#late-join
func _late_join_test() -> void:
	var port := PORT_BASE + 8
	var host := _make_peer("host")
	var t := DirectTransport.new()
	t.port = port
	t.advertise = "127.0.0.1"
	var code := host.host_party("Kevin", &"", t)
	var early := _make_peer("early")
	early.join_party(code, "Mercer", &"", DirectTransport.new())
	var formed := await _wait_until(func() -> bool:
		return host.party_size() == 2 and early.party_size() == 2, 5.0)
	ok("two ships form a party", formed)
	host.set_ready(true)
	early.set_ready(true)
	await _wait_until(func() -> bool: return host.everyone_ready(), 3.0)
	# (at ascension 7, so the late ship below has a level to be told at the door)
	Run.forced_ascension = Run.HELLBENDER_ASCENSION
	ok("and the host launches", host.launch_dive())
	Run.forced_ascension = -1
	await _wait_until(func() -> bool: return early.state == NetSession.State.DIVING, 3.0)
	# Something used up and a fight open before the late ship arrives.
	host.claim(77, MapGen.OPTION_WHOLE)
	host.open_fight(88, PackedStringArray(["cutter"]), PackedInt32Array([40]),
		PackedInt32Array([0]), PackedInt32Array([40]))

	# One custodian for the galaxy (PROTOCOL 16): presence raises the count and grows the fight.
	var kept_seed := Run.galaxy_seed
	var kept_jumps := Run.jumps
	var kept_party := Run.party_jumps
	var kept_seen := Run.custodian_seen
	var kept_hb := [Run.hellbender_at, Run.hellbender_hp, Run.hellbender_ticks]
	Run.party_jumps = 0
	check("a dive starts at no jumps", host.galaxy_jumps, 0)
	var h20: int = (DB.enemies[&"custodian"] as EnemyTemplate).hull_at(20)
	host.open_fight(90, PackedStringArray(["custodian"]), PackedInt32Array([h20]),
		PackedInt32Array([8]), PackedInt32Array([h20]), 20)
	check("a Custodian's fight opened at 20 jumps folds them into the count", host.galaxy_jumps, 20)
	var told := await _wait_until(func() -> bool: return early.galaxy_jumps == 20, 3.0)
	ok("and the host's push tells the guest", told)
	Run.galaxy_seed = host.dive_seed
	Run.jumps = 33
	early._mark_presence()
	var raised := await _wait_until(func() -> bool:
		var ef: SharedFight = early.fight_at(90)
		return host.galaxy_jumps == 33 and early.galaxy_jumps == 33 and ef != null and ef.grown == 33, 3.0)
	ok("a guest's presence at 33 jumps raises the host's count and its push the guest's", raised)
	check("and the open Custodian grows to hull_at(33) on the host", host.fight_at(90).foes[0].max_hp, 400)
	check("and on the guest", early.fight_at(90).foes[0].max_hp if early.fight_at(90) != null else -1, 400)
	Run.jumps = 12
	early._mark_presence()
	await _wait_frames(12)
	check("a ship behind the lead does not lower it", host.galaxy_jumps, 33)
	# The host is the lead ship: its jump reaches the count only through `_on_jumped`.
	Run.jumps = 35
	host._on_jumped(Run.at)
	check("the host's own jump to 35 raises the count", host.galaxy_jumps, 35)
	var host_told := await _wait_until(func() -> bool: return early.galaxy_jumps == 35, 3.0)
	ok("and its push tells the guest (%d)" % early.galaxy_jumps, host_told)
	ok("the open Custodian is at 35 and still capped at 400 (%d, %d)" % [host.fight_at(90).grown, host.fight_at(90).foes[0].max_hp],
		host.fight_at(90).grown == 35 and host.fight_at(90).foes[0].max_hp == 400)
	await _wait_frames(12)
	ok("and not pushed for a growth that moved no hull (the guest's copy says %d)" % early.fight_at(90).grown,
		early.fight_at(90) != null and early.fight_at(90).grown == 33)
	Run.jumps = 12
	# A stale presence moving `at` is no jump and must not tick the hellbender's clock.
	Run.hellbender_at = 3
	Run.hellbender_hp = maxi(1, Run.hellbender_hp)
	Run.hellbender_ticks = 0
	host.roster[777] = host._slot(777, "Stale", &"", 99)
	host._apply_presence(777, {}, 41, -1)
	host._apply_presence(777, {}, 5, 0)
	check("a guest's first presence from the dive's galaxy ticks no hellbender", Run.hellbender_ticks, 0)
	host._apply_presence(777, {}, 6, 1)
	check("and its next jump does", Run.hellbender_ticks, 1)
	host._apply_presence(777, {}, 40, -1)
	check("but a move that says no jumps (a NEW RUN's galaxy) does not", Run.hellbender_ticks, 1)
	# and over the wire: the guest presses NEW RUN while diving (another
	# galaxy, a new `at`), so `_my_jumps` sends -1 and the host ticks nothing
	var eid := early.local_id()
	var was_at := host.where_is(eid)
	var kept_at0 := Run.at
	Run.galaxy_seed = host.dive_seed + 1
	Run.at = was_at + 1 if was_at + 1 < Run.map.size() else was_at - 1
	early._mark_presence()
	var wire_moved := await _wait_until(func() -> bool: return host.where_is(eid) == Run.at, 3.0)
	ok("a guest's NEW RUN moves it on the host's roster (%d to %d) and ticks no hellbender (%d)" % [
		was_at, host.where_is(eid), Run.hellbender_ticks], wire_moved and was_at >= 0 and Run.hellbender_ticks == 1)
	Run.galaxy_seed = host.dive_seed
	Run.at = kept_at0
	host.roster.erase(777)
	host._jumps_said.erase(777)
	host._push_roster()
	Run.hellbender_at = int(kept_hb[0])
	Run.hellbender_hp = int(kept_hb[1])
	Run.hellbender_ticks = int(kept_hb[2])
	Run.custodian_seen = 0

	# TWO FLIGHTS UNDER WAY AS A SHIP JOINS (PROTOCOL 17): each was said once,
	# to the peers there then; the host tells a late joiner the guest's it keeps
	# and its own, the sender's clock run on (the code review, Nov 5: a late
	# joiner never heard a flight already under way)
	var lj_pts := PackedVector2Array([Vector2(0, 0), Vector2(50, 0), Vector2(100, 0)])
	var lj_lit := PackedByteArray([0, 1, 0])
	var eid0 := early.local_id()
	early.report_flight(12, 777001, 0, 1, 500.0, 10.0, lj_pts, lj_lit, 500.0, PackedFloat64Array([-9.0, 2.0, 18.0]))
	host.report_flight(12, 777002, 1, 0, 600.0, 10.0, lj_pts, lj_lit, 600.0)
	var kept0 := await _wait_until(func() -> bool: return host.flights.has(eid0), 3.0)
	ok("the host keeps a guest's flight under way", kept0)

	var late := _make_peer("late")
	late.join_party(code, "Jon", &"", DirectTransport.new())
	var dived := await _wait_until(func() -> bool: return late.state == NetSession.State.DIVING, 5.0)
	var told_fl := await _wait_until(func() -> bool: return late.flights.has(eid0) and late.flights.has(1), 3.0)
	ok("a ship joining while two fly is told both flights, the guest's and the host's", told_fl)
	if told_fl:
		var lg: Dictionary = late.flights[eid0]
		var lh: Dictionary = late.flights[1]
		ok("whole, as said (from 0 to 1 at 500, its ride 2 s and its arrival 18 s in; the host's from 1 to 0 at 600)",
			(lg.pts as PackedVector2Array) == lj_pts and (lg.burns as PackedByteArray) == lj_lit and int(lg.from) == 0 and int(lg.to) == 1
			and float(lg.t0) == 500.0 and absf(float(lg.dep_s) - 2.0) < 1e-9 and absf(float(lg.arr_s) - 18.0) < 1e-9
			and int(lh.from) == 1 and int(lh.to) == 0 and float(lh.t0) == 600.0)
		ok("the sender's clock run on to when it was told (%.3f, %.3f)" % [float(lg.said), float(lh.said)],
			float(lg.said) >= 500.0 and float(lg.said) < 520.0 and float(lh.said) >= 600.0 and float(lh.said) < 620.0)
	early.report_flight_off(12)
	host.report_flight_off(12)
	var lj_gone := await _wait_until(func() -> bool: return not late.flights.has(eid0) and not late.flights.has(1), 3.0)
	ok("and let go of, both gone on the late ship", lj_gone)
	ok("a ship joining after launch is put in the dive", dived)
	check("on the host's seed", late.dive_seed, host.dive_seed)
	check("and the host's unlocks", str(late.dive_unlocked), str(host.dive_unlocked))
	check("and the host's ascension (%d)" % host.dive_ascension, late.dive_ascension, host.dive_ascension)
	check("which is the level it launched at", host.dive_ascension, Run.HELLBENDER_ASCENSION)
	check("knowing what the party has used up", late.who_took(77), 1)
	ok("and the fight open at the time", late.fight_open_at(88))
	# The host seats the late ship, then pushes the roster; the guest's copy
	# arrives a frame or more later, so it is waited for like the count below.
	await _wait_until(func() -> bool: return early.party_size() == 3, 3.0)
	check("in the party everybody sees", early.party_size(), 3)
	ok("seated after the others, so its loot is its own",
		late.seat() > early.seat())
	var counted := await _wait_until(func() -> bool: return late.galaxy_jumps == 35, 3.0)
	ok("the late ship is told the lead ship's count at the door (%d)" % late.galaxy_jumps, counted)
	check("quietly: its badge counts it as seen, with no arrival to play", Run.custodian_seen, 35)
	ok("and the fight it walks into is the grown one", late.fight_at(90) != null and late.fight_at(90).grown == 35
		and late.fight_at(90).foes[0].max_hp == 400)
	print("  the lead ship's count: host %d, guest %d, late %d at the door; the open Custodian %d -> %d" % [
		host.galaxy_jumps, early.galaxy_jumps, late.galaxy_jumps, h20, host.fight_at(90).foes[0].max_hp])
	Run.galaxy_seed = kept_seed
	Run.jumps = kept_jumps
	Run.party_jumps = kept_party
	Run.custodian_seen = kept_seen

	# The party clock counts a partner only where the roster has it, hence every ship in 12.
	var id := early.local_id()
	var kept_at := Run.at
	Run.at = 12
	for pe: NetSession in [host, early, late]:
		pe._mark_presence()
	var all_there := await _wait_until(func() -> bool:
		return late.where_is(id) == 12 and host.where_is(id) == 12 and late.where_is(1) == 12, 3.0)
	ok("every ship is in system 12 on every roster", all_there)
	early.report_spot(12, 3, Vector2(10.5, -4.0), 1.25, true)
	var seen := await _wait_until(func() -> bool:
		return not late.spot_of(id, 12).is_empty() and not host.spot_of(id, 12).is_empty(), 3.0)
	ok("a ship's place in its system reaches the others", seen)
	var sp := late.spot_of(id, 12)
	check("the world it is at", int(sp.get("body", -99)), 3)
	check("and where, off that world", Vector2(float(sp.get("x", 0.0)), float(sp.get("z", 0.0))), Vector2(10.5, -4.0))
	ok("and it is not said about any other system", late.spot_of(id, 13).is_empty())
	ok("nor about yourself", early.spot_of(id, 12).is_empty())
	await _flight_said_test(host, early, late, id)
	# Throttled: an unchanged place is not sent again, a changed one is.
	early.report_spot(12, 3, Vector2(10.5, -4.0), 1.25)
	early.report_spot(12, -9, Vector2(200.0, 0.0), 0.0, true)
	var moved := await _wait_until(func() -> bool:
		return int(late.spot_of(id, 12).get("body", 3)) == -9, 3.0)
	ok("and a ship that flies on is seen to", moved)
	# Two suns and the turning pair (PROTOCOL 13 and 14): offset from star B at the sender's clock.
	var off_b := Vector2(51.5, -18.25)
	early.report_spot(12, SystemLayout.STAR_B, off_b, 0.75, true, 100.0, SystemLayout.STAR_B)
	var to_b := await _wait_until(func() -> bool:
		return int(late.spot_of(id, 12).get("body", 3)) == SystemLayout.STAR_B \
			and int(host.spot_of(id, 12).get("body", 3)) == SystemLayout.STAR_B, 3.0)
	ok("a ship in star B's close orbit is seen there", to_b)
	var sb := late.spot_of(id, 12)
	check("at the offset from B it said", Vector2(float(sb.get("x", 0.0)), float(sb.get("z", 0.0))), off_b)
	check("with the map clock it said it at", float(sb.get("t", -1.0)), 100.0)
	check("and the sun it is said off", int(sb.get("host", 0)), SystemLayout.STAR_B)
	check("and the host heard the same clock", float(host.spot_of(id, 12).get("t", -1.0)), 100.0)
	# SETTLED ROUND BOTH SUNS: open space, said as the plane point it is (the
	# balance point holds still), off nothing (`host` -9)
	var round_both := Vector2(-140.0, 310.5)
	early.report_spot(12, -9, round_both, 2.0, true, 101.5, -9)
	var to_both := await _wait_until(func() -> bool:
		return int(late.spot_of(id, 12).get("body", 3)) == -9 and float(late.spot_of(id, 12).get("t", 0.0)) == 101.5, 3.0)
	ok("a ship settled round both suns is seen, off nothing", to_both)
	var s9 := late.spot_of(id, 12)
	check("at the plane point it said", Vector2(float(s9.get("x", 0.0)), float(s9.get("z", 0.0))), round_both)
	check("off no sun", int(s9.get("host", 0)), -9)
	# The party clock: a map behind takes it, one ahead keeps its own, and never moves back.
	var since := Time.get_ticks_msec()
	var pt := late.party_t(12)
	ok("the party's clock is the one said, run on since (%.3f from 101.5)" % pt,
		pt >= 101.5 and pt <= 101.5 + 3.0 + float(Time.get_ticks_msec() - since) / 1000.0)
	check("and there is none for a system nobody has said one about", late.party_t(13), -1.0)
	var kept_clock: Dictionary = Run.map_clock.duplicate()
	var kept_parked: Dictionary = SystemMapScreen._parked.get(12, {})
	SystemMapScreen._parked.erase(12)
	Run.map_clock[12] = 96.5
	var took := late.adopt_clock(12)
	ok("a map 5 s behind opens on the party's clock (%.3f), and keeps it" % took,
		took >= 101.5 and Run.map_t(12) == took)
	Run.map_clock[12] = 500.0
	check("a map ahead of it keeps its own: never moved back", late.adopt_clock(12), 500.0)
	Run.map_clock[12] = 96.5
	SystemMapScreen._parked[12] = {"at": 3, "mode": &"fly"}
	var took_fly := late.adopt_clock(12)
	ok("one whose ship was put away on its way takes it too (%.3f): it is put down at its end" % took_fly, took_fly >= 101.5)
	Run.map_clock[12] = 96.5
	SystemMapScreen._parked[12] = {"at": -9, "mode": &"free", "p": Vector2(300.0, 40.0), "v": Vector2(0.0, 20.0), "head": 0.0}
	check("but not one whose ship was put away coasting free", late.adopt_clock(12), 96.5)
	Run.map_clock[12] = 96.5
	SystemMapScreen._parked[12] = {"at": -9, "mode": &"free", "p": Vector2(300.0, 40.0), "v": Vector2(0.0, 20.0), "head": 0.0, "cen": -9, "r": 302.6, "sense": 1.0}
	ok("and one settled takes it", late.adopt_clock(12) >= 101.5)
	check("the rule: behind takes the party's", NetSession.clock_to_open(95.0, 100.25, false), 100.25)
	check("ahead keeps its own", NetSession.clock_to_open(110.0, 100.25, false), 110.0)
	check("coasting keeps its own", NetSession.clock_to_open(95.0, 100.25, true), 95.0)
	check("nobody said one: its own", NetSession.clock_to_open(95.0, -1.0, false), 95.0)
	# Held while a map is put away, or the next map jumped the pair by the unwatched time.
	early.report_spot(12, -9, round_both, 2.0, true, 101.5, -9, true)
	var to_held := await _wait_until(func() -> bool:
		return bool(late.spot_of(id, 12).get("held", false)), 3.0)
	ok("a partner's map put away says its clock holds", to_held)
	await _tree.create_timer(0.3).timeout
	check("and the party's clock is the one it said, not run on", late.party_t(12), 101.5)
	# A lost word costs seconds, not a visit: reliable send, repeat beat, capped run-on.
	var g_old := int(late.spot_of(id, 12).get("got", 0))
	early.report_spot(12, -9, round_both, 2.0, true, 101.5, -9, true)
	await _wait_until(func() -> bool: return int(late.spot_of(id, 12).get("got", 0)) > g_old, 3.0)
	var g0 := int(late.spot_of(id, 12).get("got", 0))
	early.report_spot(12, -9, round_both, 2.0, false, 101.5, -9, true)
	await _tree.create_timer(0.3).timeout
	early.report_spot(12, -9, round_both, 2.0, false, 101.5, -9, true)
	await _tree.create_timer(0.2).timeout
	check("a spot that holds still is not said again within a beat", int(late.spot_of(id, 12).get("got", 0)), g0)
	var beat := await _wait_until(func() -> bool:
		early.report_spot(12, -9, round_both, 2.0, false, 101.5, -9, true)
		return int(late.spot_of(id, 12).get("got", 0)) > g0, 3.0)
	ok("but it is said again a beat on (SPOT_BEAT_MS), though nothing moved", beat)
	var kept_row: Dictionary = late.spots[id].duplicate()
	late.spots[id]["held"] = false
	late.spots[id]["got"] = Time.get_ticks_msec() - 600000
	check("a partner's clock nothing has refreshed for ten minutes is run on only RUN_ON_MAX", late.party_t(12), 101.5 + NetSession.RUN_ON_MAX)
	late.spots[id] = kept_row
	# AN ARRIVAL says no clock: its map has not opened (it said 0.0, run on)
	early.report_arrival(12)
	var to_arr := await _wait_until(func() -> bool:
		return int(late.spot_of(id, 12).get("body", 3)) == -10, 3.0)
	ok("a partner just arrived is seen so", to_arr)
	check("and says no clock", late.party_t(12), -1.0)
	# A leaving partner takes its clock with it on every machine, not only the host.
	early.report_spot(12, -9, round_both, 2.0, true, 101.5, -9, false)
	var back_up := await _wait_until(func() -> bool:
		return int(late.spot_of(id, 12).get("body", 3)) == -9 and not bool(late.spot_of(id, 12).get("held", true)), 3.0)
	ok("a partner's map up again is seen so", back_up)
	ok("and its clock is the party's while it is in the party (%.3f)" % late.party_t(12), late.party_t(12) >= 101.5)
	early.leave_party()
	var gone := await _wait_until(func() -> bool: return not late.roster.has(id) and not host.roster.has(id), 5.0)
	ok("the partner who left is off the roster", gone)
	ok("and its spot gone from the other guest too", not late.spots.has(id))
	check("and the party's clock with it", late.party_t(12), -1.0)
	Run.at = kept_at
	Run.map_clock = kept_clock
	SystemMapScreen._parked.erase(12)
	if not kept_parked.is_empty():
		SystemMapScreen._parked[12] = kept_parked
	# (this file prints only its failures; the count says the case was seen)
	print("  twin cases: 2 (a spot in star B's close orbit, relayed to both: %s; one round both suns: %s)" % [
		"yes" if to_b else "no", "yes" if to_both else "no"])
	await _teardown()


## Two clocks 5 s apart must agree where a spot is drawn (PROTOCOL 14, ruling 23).
## Why: docs/why/NetTest.md#turning-pair
func _turning_pair_test() -> void:
	Rng.forced = 7
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var B := SystemLayout.STAR_B
	var gap := 5.0
	for want_close: bool in [false, true]:
		var kind := "close" if want_close else "wide"
		var L: SystemLayout = null
		var ni := -1
		for raw in Run.map:
			var Lc := SystemLayout.of(raw as MapGen.MapNode)
			if Lc.twin and Lc.close == want_close and Lc.pair_n > 0.0:
				L = Lc
				ni = (raw as MapGen.MapNode).index
				break
		if L == null:
			fails += 1
			print("  FAIL seed 7 has no turning %s pair" % kind)
			continue
		var wb := -1
		for b in L.bodies:
			if b.host_id == B and b.hr != 0.0:
				wb = b.index
				break
		var worst := 0.0
		var both_worst := 0.0
		var world_worst := 0.0
		var old_miss := 0.0
		var turned_miss := 0.0
		for k in 8:
			var t_me := (float(k) + 0.5) / 8.0 * TAU / L.pair_n
			var t_them := t_me - gap
			old_miss = maxf(old_miss, L.star_pos(B, t_them).distance_to(L.star_pos(B, t_me)))
			# on a sun's orbit: in B's close orbit (body B), settled round B or A
			# (open space, host B / -1), each a point round where that sun is
			for c: Array in [[B, B], [-9, B], [-9, -1]]:
				var body: int = c[0]
				var host: int = c[1]
				var ring := Vector2(L.star_rail_of(host) + 3.0 * float(k), 0.0).rotated(0.9 * float(k))
				var p_them := L.star_pos(host, t_them) + ring
				var sent := p_them - NetSession.spot_anchor(L, body, host, t_them)
				var drawn := sent + NetSession.spot_anchor(L, body, host, t_me)
				worst = maxf(worst, drawn.distance_to(L.star_pos(host, t_me) + ring))
			# settled round both suns: the plane point itself
			var r := 0.6 * L.edge
			var p_both := L.bary + Vector2(r, 0.0).rotated(0.7 * float(k))
			var sent9 := p_both - NetSession.spot_anchor(L, -9, -9, t_them)
			var drawn9 := sent9 + NetSession.spot_anchor(L, -9, -9, t_me)
			both_worst = maxf(both_worst, drawn9.distance_to(p_both))
			turned_miss = maxf(turned_miss, 2.0 * r * absf(sin(0.5 * L.pair_n * gap)))
			# off the world round star B, carried round with it
			if wb >= 0:
				var w_off := Vector2(6.0, -2.0)
				var sent_w := (L.bodies[wb].pos(t_them) + w_off) - NetSession.spot_anchor(L, wb, -9, t_them)
				var drawn_w := sent_w + NetSession.spot_anchor(L, wb, -9, t_me)
				world_worst = maxf(world_worst, drawn_w.distance_to(L.bodies[wb].pos(t_me) + w_off))
		ok("%s pair (system %d): its clocks %.0f s apart move star B %.2f px, so the case means something" % [kind, ni, gap, old_miss], old_miss > 0.5)
		ok("%s pair: a ship on a sun's orbit, said at one clock, is drawn on that sun at the other (worst %.6f px over 8 angles; said as a plane point, as PROTOCOL 13 did, %.2f px off)" % [kind, worst, old_miss],
			worst < 1e-3)
		ok("%s pair: one settled round both suns is drawn where it was (worst %.6f px; turned with the pair it would have swung %.2f px)" % [kind, both_worst, turned_miss],
			both_worst < 1e-3)
		if not want_close:
			ok("wide pair: one off the world round star B, off that world as it is here (worst %.6f px)" % world_worst, wb >= 0 and world_worst < 1e-3)
		# Parked round star B then clock adopted: carried with B, restored at LOCAL's point.
		var own := 40.0
		var tn := own + 0.37 * TAU / L.pair_n
		var r_b := L.star_rail_of(B) + 30.0
		var off := Vector2(r_b, 0.0).rotated(1.1)
		var d := {"at": -9, "mode": &"free", "p": L.star_pos(B, own) + off, "v": Vector2.ZERO, "head": 0.0, "cen": B, "r": r_b, "sense": 1.0}
		var stale := ((d.p as Vector2) - L.star_pos(B, tn)).length() - r_b
		NetSession.carry_parked(L, d, own, tn)
		var fl = load("res://scripts/ui/sysmap/ShipFlight.gd").new()
		fl.setup(L, Vector2(-L.edge * 0.95, 0.0), tn)
		fl.restore_free(tn, d.p, d.v, float(d.head), B, r_b, 1.0)
		var carried := ((d.p as Vector2) - L.star_pos(B, tn)).distance_to(off)
		var agree: float = (fl.f.p as Vector2).distance_to(d.p)
		ok("%s pair: a ship parked settled round star B goes with B when the clock is taken on (%.6f px off its place round B; left where it was it is %.1f px off its circle), and the map puts it back where LOCAL reads it (%.6f px)" % [kind, carried, stale, agree],
			carried < 1e-3 and agree < 1e-3)
		print("  twin cases: %s pair, system %d: 8 angles, %d spots each" % [kind, ni, 5 if wb >= 0 else 4])
	# ONE SUN: every star spot is the plane point it always was, to the bit
	var L1: SystemLayout = null
	for raw in Run.map:
		var Lo := SystemLayout.of(raw as MapGen.MapNode)
		if not Lo.twin:
			L1 = Lo
			break
	if L1 != null:
		var p1 := Vector2(61.25, -17.5)
		var same := true
		for t1: float in [0.0, 12.5, 777.0]:
			for host: int in [-1, -9]:
				same = same and (p1 - NetSession.spot_anchor(L1, -9, host, t1)) == p1 \
					and (p1 - NetSession.spot_anchor(L1, -1, -1, t1)) == p1
		ok("one sun: a star's spot is the point it always was, at every clock", same)
## Sines can differ in the last bit between Mac and PC, so guests report a map fingerprint.
func _galaxy_test() -> void:
	var port := PORT_BASE + 9
	var host := _make_peer("host")
	var t := DirectTransport.new()
	t.port = port
	t.advertise = "127.0.0.1"
	var code := host.host_party("Kevin", &"", t)
	var same := _make_peer("same")
	same.join_party(code, "Mercer", &"", DirectTransport.new())
	var odd := _make_peer("odd")
	odd.join_party(code, "Jon", &"", DirectTransport.new())
	await _wait_until(func() -> bool:
		return host.party_size() == 3 and same.party_size() == 3 and odd.party_size() == 3, 5.0)
	host.set_ready(true)
	same.set_ready(true)
	odd.set_ready(true)
	await _wait_until(func() -> bool: return host.everyone_ready(), 3.0)
	host.launch_dive()
	await _wait_until(func() -> bool:
		return same.state == NetSession.State.DIVING and odd.state == NetSession.State.DIVING, 3.0)
	var sd := host.dive_seed
	# A guest reporting before the host has built its own is compared later.
	same.report_galaxy(sd, 300, 4242)
	await _wait_frames(10)
	host.report_galaxy(sd, 300, 4242)
	await _wait_frames(10)
	check("a guest whose galaxy matches is not warned about", host.galaxy_warning, "")
	odd.report_galaxy(sd, 301, 9999)
	var told := await _wait_until(func() -> bool:
		return host.galaxy_warning != "" and odd.galaxy_warning != "" and same.galaxy_warning != "", 3.0)
	ok("a galaxy that differs is said on every machine", told)
	ok("naming whose", odd.galaxy_warning.contains("Jon"))
	ok("and asking for the log", odd.galaxy_warning.contains("godot.log"))
	await _teardown()


func _make_peer(peer_name: String) -> NetSession:
	_peer_serial += 1
	var branch := Node.new()
	branch.name = "%s_%d" % [peer_name, _peer_serial]
	_tree.root.add_child(branch)
	_branches.append(branch)

	# The API must own the branch first, as `NetSession._ready()` reads `multiplayer`.
	var api := SceneMultiplayer.new()
	api.root_path = branch.get_path()
	_tree.set_multiplayer(api, branch.get_path())

	var session := NetSession.new()
	session.name = "Net"
	# Two seconds, not ten: the point is that the timeout fires, not how long it takes.
	session.handshake_timeout = 2.0
	branch.add_child(session)
	return session


func _teardown() -> void:
	for b in _branches:
		var session := b.get_node_or_null("Net") as NetSession
		if session != null:
			session.leave_party()
	# Out of the tree first, then freed, or the tree polls an API rooted at nothing.
	for b in _branches:
		_tree.root.remove_child(b)
		b.queue_free()
	_branches.clear()
	# Two frames: one for the sockets to close, one for the freed branches to
	# actually leave the tree before the next test binds the same ports.
	await _tree.process_frame
	await _tree.process_frame


## A fixed wait for checking that something did not happen, which `_wait_until()` cannot.
func _wait_frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _wait_until(condition: Callable, timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await _tree.process_frame
	return condition.call()
