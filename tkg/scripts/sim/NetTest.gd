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
## readable text; a full party turns the fifth player away; a launch puts the
## same seed on all four machines; and losing the host is reported rather than
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

	var clients: Array = []
	for i in 3:
		var c := _make_peer("client%d" % i)
		var ct := DirectTransport.new()
		c.join_party(code, "Pilot%d" % i, &"korvan", ct)
		clients.append(c)

	# The host reaching four is not the party reaching four. The roster is a
	# broadcast, and a client that has not polled it yet still reads three —
	# so the wait has to be on the last machine to agree, not the first.
	var joined := await _wait_until(func() -> bool:
		if host.party_size() != 4:
			return false
		for c in clients:
			if c.party_size() != 4:
				return false
		return true, 5.0)
	ok("all three friends joined, on every machine", joined)
	check("the host sees four", host.party_size(), 4)
	for i in clients.size():
		check("client %d sees four" % i, clients[i].party_size(), 4)
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
	check("the roster carries names", str(names), str(["Pilot0", "Pilot1", "Pilot2", "Vela"]))

	# Ready flags travel from a client, through the host, back to everyone.
	# Followed by peer id rather than by position, for the same reason.
	var readier: int = clients[1].local_id()
	clients[1].set_ready(true)
	var spread := await _wait_until(func() -> bool: return clients[2].roster[readier].ready, 3.0)
	ok("one client's ready reaches a third machine", spread)
	ok("the party is not ready with one flag", not host.everyone_ready())

	host.set_ready(true)
	clients[0].set_ready(true)
	clients[2].set_ready(true)
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

	# A fifth ship, after the party is full.
	var extra := _make_peer("gatecrash")
	extra.join_party(code, "Late", &"solari", DirectTransport.new())
	var turned := await _wait_until(func() -> bool: return extra.state == NetSession.State.FAILED, 5.0)
	ok("the fifth player is turned away", turned)
	check("and told why", extra.last_error(), "The party is full.")
	check("the party is still four", host.party_size(), 4)
	print("  four peers joined, agreed, and launched on seed %d" % host.dive_seed)

	await _teardown()


# --- refusals -------------------------------------------------------------

func _refusal_tests() -> void:
	await _one_refusal("a different protocol", PORT_BASE + 1, 99, 0,
		"Different game version. Host is protocol 1, you are 99.")
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


func _wait_until(condition: Callable, timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await _tree.process_frame
	return condition.call()
