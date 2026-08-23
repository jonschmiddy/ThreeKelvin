extends RefCounted

## Four peers, one process, no network hardware.
##
##   godot --headless --path . -- nettest
##
## RUN THIS AFTER TOUCHING ANYTHING IN scripts/net/. A session layer fails the
## same way a save file does: silently, and in front of other people. A roster
## that drops a player, a refusal that arrives as a bare disconnect, or two
## machines that launch on different seeds all look like working code and are
## only visible when four humans have already set aside an evening.
##
## The trick that makes this possible in one process is SceneMultiplayer's
## root_path. Each peer gets its own branch under the tree root and its own
## MultiplayerAPI rooted at that branch, so every peer's NetSession answers to
## the same relative path "Net" while living at a different absolute one. RPCs
## resolve by the relative path, so the peers can talk to each other exactly as
## they would across a wire. Without this the test would need four processes
## and could not run in CI.
##
## What this proves: codes survive a round trip and refuse typos; a party forms
## and the roster reaches everyone; the two version refusals fire and arrive as
## readable text; a full party turns the next one away; a launch puts the
## same seed on every machine; a ship crosses the wire and comes back as
## the same ship on the other machine; a system consumed on one machine is
## consumed on all of them; and losing the host is reported rather than
## swallowed.
##
## What this does NOT prove: that any of it works through a NAT. Nothing that
## runs on one machine can prove that, and pretending otherwise is how the
## direct transport gets shipped as if it were finished.

const PORT_BASE: int = 34210

var fails: int = 0
var _tree: SceneTree
var _branches: Array[Node] = []
## Branch names are never reused. A MultiplayerAPI is registered against a node
## path and there is no call to unregister one, so a second peer at a path the
## first one used inherits a registration pointing at a freed node. Counting up
## is cheaper than working around that.
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
	# One frame before anything. run() is called from Main._ready(), and the
	# tree root is still adding its own children at that moment — add_child()
	# on it refuses, and every peer this test builds would come back rootless.
	await tree.process_frame
	print("\n=== lobby codes ===")
	_code_tests()
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
	await _solo_take_test()
	await _map_test()
	print("\n=== one enemy, several ships ===")
	_fight_rules_test()
	await _fight_net_test()
	print("\n=== the host leaves ===")
	await _host_loss_test()

	print("")
	if fails == 0:
		print("nettest: PASS")
	else:
		print("nettest: %d FAILURES" % fails)
	tree.quit(1 if fails > 0 else 0)


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

	# Every room number is five characters and comes back as itself. A thousand
	# rolls rather than a handful, because a bit-packing error usually only
	# shows on the values that straddle a character boundary.
	for i in 1000:
		var room := LobbyCode.roll_room()
		var code := LobbyCode.encode_room(room)
		var back := LobbyCode.parse(code)
		if back.room != room or code.length() != 7:
			fails += 1
			print("  FAIL room %d -> %s -> %s" % [room, code, back])
			break
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

	# SEATS, not four. This test was written when the cap was four and asserted
	# the number in nine places; the cap became eight and every one of them went
	# stale, unnoticed, because `-- nettest` was not in the merge gate. Both
	# halves of that are fixed: the gate runs it now, and the only place the
	# number lives is NetTransport.
	var seats := NetTransport.MAX_PLAYERS
	var clients: Array = []
	for i in seats - 1:
		var c := _make_peer("client%d" % i)
		var ct := DirectTransport.new()
		c.join_party(code, "Pilot%d" % i, &"korvan", ct)
		clients.append(c)

	# The host reaching a full party is not the party reaching it. The roster is
	# a broadcast, and a client that has not polled it yet still reads one short
	# — so the wait has to be on the last machine to agree, not the first.
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

	# Names crossed the wire, not just ids. Compared as a set, and only the host
	# is asserted to be first: three clients dialling at once arrive at the host
	# in whatever order ENet delivers them, so the tail of the roster is not
	# deterministic and a test that pretends it is fails one run in six.
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
	ok("the host can", host.launch_dive())
	# Every client, not just one. The launch is a broadcast and the last peer to
	# see it is the one that matters — waiting on a single client passes while
	# another is still sitting in the lobby, which is the exact bug the test is
	# supposed to catch.
	var launched := await _wait_until(func() -> bool:
		for c in clients:
			if c.state != NetSession.State.DIVING:
				return false
		return true, 3.0)
	ok("the launch reached every client", launched)
	for i in clients.size():
		check("client %d dives on the host's seed" % i, clients[i].dive_seed, host.dive_seed)
	ok("the seed is not zero", host.dive_seed != 0)

	# One ship past the last seat.
	var extra := _make_peer("gatecrash")
	extra.join_party(code, "Late", &"solari", DirectTransport.new())
	var turned := await _wait_until(func() -> bool: return extra.state == NetSession.State.FAILED, 5.0)
	ok("the seat past the last is turned away", turned)
	check("and told why", extra.last_error(), "The party is full.")
	check("the party is still %d" % seats, host.party_size(), seats)
	print("  %d peers joined, agreed, and launched on seed %d" % [seats, host.dive_seed])

	await _teardown()


# --- refusals -------------------------------------------------------------

func _refusal_tests() -> void:
	# Against NetSession.PROTOCOL, not against the number it happens to be
	# today. The message names the host's version, so a hardcoded 1 here turns
	# the next protocol bump into a test failure that says nothing true.
	await _one_refusal("a different protocol", PORT_BASE + 1, 99, 0,
		"Different game version. Host is protocol %d, you are 99." % NetSession.PROTOCOL)
	await _one_refusal("different content", PORT_BASE + 2, 0, 0x5EEDBAD,
		"Your content does not match the host's. Compare builds or mods.")

	# A code that parses but points at nothing. This is the common case in the
	# real world — a host who never forwarded the port — and it must not look
	# like a typo, because the two have opposite fixes.
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


func _one_refusal(what: String, port: int, protocol: int, fingerprint: int, want: String) -> void:
	var host := _make_peer("host")
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
	c.join_party(code, "Odd", &"korvan", DirectTransport.new())
	var refused := await _wait_until(func() -> bool: return c.state == NetSession.State.FAILED, 5.0)
	ok("%s is refused" % what, refused)
	check("%s is explained" % what, c.last_error(), want)
	print("  %s: %s" % [what, c.last_error()])
	check("%s leaves the party empty" % what, host.party_size(), 1)
	await _teardown()


# --- what everybody is flying ---------------------------------------------

## The description on its own, before any network is involved.
##
## Deliberately given values a real run would take a while to reach — a part on
## the third hardpoint, a part built by somebody who did not build the hull, a
## ship over its heat cap — because those are the fields whose loss is invisible.
## A build that comes back with every mount at zero draws every gun on the spine
## and looks like a rendering decision.
func _wire_tests() -> void:
	var b := ShipBuild.new()
	b.pilot = "Mercer"
	b.hull = DB.hull_for(&"dredge", HullData.Weight.MEDIUM)
	b.parts = [
		{"slot": int(ModuleData.Slot.WEAPON), "mount": 2, "maker": &"halcyon", "id": &"beam"},
		{"slot": int(ModuleData.Slot.UTILITY), "mount": 0, "maker": &"cygnet", "id": &"coolline"},
	]
	b.hp = 7
	b.max_hp = 44
	b.heat = 15
	b.heat_cap = 10

	var back := ShipBuild.from_wire(b.to_wire())
	check("the pilot survives", back.pilot, "Mercer")
	check("the hull maker survives", back.hull.manufacturer, &"dredge")
	check("the weight class survives", int(back.hull.weight), int(HullData.Weight.MEDIUM))
	check("the part count survives", back.parts.size(), 2)
	check("the hardpoint survives", int(back.parts[0].mount), 2)
	check("who built the part survives", StringName(back.parts[0].maker), &"halcyon")
	check("damage survives", back.hp, 7)
	# Over cap is a state the ship art has its own colours for, so it has to
	# arrive as itself rather than clamped on the way.
	ok("and an overheat arrives as an overheat", back.heat_ratio() > 1.0)

	# A showroom hull is an ordinary build with nothing on it. ShipView has no
	# preview MODE any more, so this is what makes the chassis select show a
	# bare ship rather than the one you are flying.
	var shown := ShipBuild.showroom(DB.hull_for(&"korvan", HullData.Weight.LIGHT))
	check("a showroom ship carries no parts", shown.parts.size(), 0)
	check("and is undamaged", shown.damage(), 0.0)
	check("and is cold", shown.heat_ratio(), 0.0)

	# And a message that makes no sense. A weight class of 99 names no hull, and
	# the slot that draws a partner asks that hull for its manufacturer — so the
	# cost of not checking is the sector screen going down, on every machine,
	# because of one bad field on one peer.
	var junk := ShipBuild.from_wire({"maker": &"nobody", "weight": 99,
		"parts": "not a list", "hp": "seven"})
	ok("nonsense off the wire still names a hull", junk.hull != null)
	check("and carries no parts", junk.parts.size(), 0)
	var empty := ShipBuild.from_wire({})
	ok("and so does an empty message", empty.hull != null)


## A ship described on one machine, drawn on another.
##
## The failure this catches is not "no ship appears" — that is loud. It is a
## partner drawn as the WRONG ship, which looks like art rather than like a bug
## and which cannot be seen without two machines.
##
## Nothing here asks for a build to be sent. That is the point: fitting a
## chassis is what a player does, and the party seeing it is supposed to be a
## consequence rather than a call somebody remembered to make.
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

	# One process holds one `Run`, so both peers describe the same ship. That is
	# a limit of the harness and not of the feature — what is being checked is
	# that a description travels intact in both directions, which does not need
	# the two ships to differ.
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
			have.append("%d/%d/%s" % [int(part.slot), int(part.mount), part.maker])
		check("and every part on its own hardpoint", "|".join(have), "|".join(want))
	await _teardown()


# --- one map, not four ----------------------------------------------------

## The local half, with nobody to tell.
##
## `consume_node()` is the one door and it has to work in the solo game
## unchanged, because every call site was rewritten to use it. A chokepoint that
## only works in a party is a chokepoint that broke the game for one player.
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
	Run.adopt_party_claims()
	ok("a claim from the party clears this machine's copy", Run.map[40].cleared)
	# One OPTION taken is not the whole system taken. That distinction is the
	# entire point of the option id: a ship that stripped the wreck has not also
	# taken the fight that was waiting beside it.
	ok("but one option taken leaves the system open", not Run.map[41].cleared)
	ok("and the option itself is recorded", Run.map[41].taken.has(3))
	# Out-of-range indices cannot happen behind the content fingerprint and a
	# shared seed. They are checked because the alternative is an index error
	# taking the chart down on whoever receives it.
	ok("an index off the end of the map is ignored, not fatal", true)
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


## The networked half: one machine uses a system up, and every other machine
## agrees that it is used up.
##
## This is the message that stops four players each stripping the same derelict.
## The wreck holds the same two modules on all four machines already — that is
## what the shared seed and `Rng.derive()` buy — so without this the hold
## economy in `docs/coop-design.md` §3 pays out four times for one wreck.
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

	# THE RACE. Both clients ask for the same thing in the same frame, without
	# either waiting first. Exactly one may come away with it, and the loser has
	# to be told who did — before it rolls any loot.
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

	# Where everybody is. One process holds one `Run`, so all three report the
	# same system — what is being checked is that the number travels at all and
	# lands in the right slot.
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

	host.leave_party()
	var noticed := await _wait_until(func() -> bool: return c.state == NetSession.State.FAILED, 5.0)
	ok("the client notices the host left", noticed)
	check("and says so", c.last_error(), "The host left.")
	check("and the roster is emptied", c.party_size(), 0)
	print("  the client was told: %s" % c.last_error())
	await _teardown()


# --- shared fights --------------------------------------------------------

## The rules, with no wire under them. Everything here is what the host decides
## when a second ship walks into a fight, and none of it needs a peer to be
## true — which is the point of SharedFight being a plain RefCounted.
func _fight_rules_test() -> void:
	var f := SharedFight.open(42, PackedStringArray(["cutter"]),
		PackedInt32Array([100]), PackedInt32Array([3]), PackedInt32Array([100]), 11)
	check("one ship, one ship's frigate", f.foes[0].max_hp, 100)

	# 0.6 each, not 1.0. Three hands of cards against one intent is already an
	# advantage; a linearly scaled enemy would make the party fight EASIER.
	f.join(22)
	f.join(33)
	check("three ships, a frigate scaled for three", f.foes[0].max_hp, 220)
	check("and it is at full health, not two thirds of it", f.foes[0].hp, 220)
	check("three in the crew", f.crew.size(), 3)
	ok("joining twice is joining once", not f.join(22))

	# Block first, then armor, per hit — the same order Combat.damage_enemy
	# spends them in. If these two ever disagree the hull bar contradicts the
	# combat log.
	f.foes[0].block = 5
	var landed := f.hurt(0, 10, 2, 22)
	# Two hits of 10 into 5 block and 3 armor: the first hit spends both and
	# lands 2, the second lands all 10. Mitigation is per-fight, not per-hit,
	# which is what makes multi-hit cards good into armor.
	check("block and armor come off the first hit only", landed, 12)
	check("hull took exactly that", f.foes[0].hp, 208)
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
	check("and the enemy does not shrink back", f.foes[0].max_hp, 220)

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
	check("and it is one frigate, scaled", host.fight_at(214).foes[0].max_hp, 220)
	print("  three ships walked into one fight; the frigate went 100 -> %d"
		% host.fight_at(214).foes[0].max_hp)

	# A client's gun reaches the host AND the other client, which is the half a
	# host-only check would miss.
	others[1].hurt_foe(214, 0, 20, 1)
	var hit := await _wait_until(func() -> bool:
		return others[0].fight_at(214).foes[0].hp == 200, 4.0)
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


## Who the enemy swings at.
##
## The rule is `0.5 + heat_ratio`, and both halves matter. The ratio is what
## makes running hot dangerous INSIDE a fight rather than only on the map, which
## is `docs/coop-design.md` §6 one level down. The floor is what stops a party from
## solving the fight by electing a victim: a cold ship is safer, never safe.
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
	host.roster[cold].build = {"maker": &"redline", "weight": 1, "parts": [],
		"hp": 30, "max_hp": 30, "heat": 0, "heat_cap": 10, "dead": false}
	host.roster[hot].build = {"maker": &"solari", "weight": 1, "parts": [],
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


# --- one process, four multiplayer roots ----------------------------------

func _make_peer(peer_name: String) -> NetSession:
	_peer_serial += 1
	var branch := Node.new()
	branch.name = "%s_%d" % [peer_name, _peer_serial]
	_tree.root.add_child(branch)
	_branches.append(branch)

	# Order matters. The API has to own the branch before NetSession enters it,
	# because NetSession._ready() reads `multiplayer` and would otherwise bind
	# to the tree's default API — which is the autoloaded session, not this one.
	var api := SceneMultiplayer.new()
	api.root_path = branch.get_path()
	_tree.set_multiplayer(api, branch.get_path())

	var session := NetSession.new()
	session.name = "Net"
	# Two seconds, not ten. The point of the timeout is that it fires, not how
	# long it takes; a test that spends the real interval proves nothing extra
	# and costs it on every run.
	session.handshake_timeout = 2.0
	branch.add_child(session)
	return session


func _teardown() -> void:
	for b in _branches:
		var session := b.get_node_or_null("Net") as NetSession
		if session != null:
			session.leave_party()
	# Out of the tree first, then freed. Removing detaches the branch from its
	# MultiplayerAPI while the path is still valid; freeing it while registered
	# leaves the tree polling an API rooted at nothing.
	for b in _branches:
		_tree.root.remove_child(b)
		b.queue_free()
	_branches.clear()
	# Two frames: one for the sockets to close, one for the freed branches to
	# actually leave the tree before the next test binds the same ports.
	await _tree.process_frame
	await _tree.process_frame


## A fixed number of frames, for checking that something did NOT happen.
##
## _wait_until() cannot express "nothing changed": it returns the moment the
## condition holds, and a condition that already holds returns immediately.
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
