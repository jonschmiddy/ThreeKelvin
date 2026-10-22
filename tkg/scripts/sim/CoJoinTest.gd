class_name CoJoinTest
extends Harness

## Two processes, flown the way two friends fly: into one system, into one
## fight, and back out again. The co-op playtest of Oct 22, as a harness.
##
##   godot --headless --path . -- cojoin host [relay]
##   godot --headless --path . -- cojoin join CODE
##   tools/cojoin.sh [relay] [late]
##
## Jon and Kevin, Oct 22: "I couldn't join the fight he was in", "we could not
## see each other flying around on the sector map", and where both ships were
## drawn together they were "totally on top of each other". `cofight` never saw
## any of it, because it PLACES both ships on a node and opens the fight by
## hand, and the game stopped opening fights that way when the three node types
## became one: a system's hostiles are an option now, and an option's fight was
## private. This one goes through the doors a player uses -- the jump, LOCAL,
## the SECTOR map, the option's fight, JOIN -- and fails on what they found.
##
## `late`: the host dives alone and flies a jump before the guest has even
## typed the code. A friend whose game crashed and who joins back in is that.

const CODE_TAG := "[cojoin] code "
const PARTNER_TIMEOUT := 45.0
const TURN_CEILING := 80
## Not cofight's port, so both can run beside a playtest and beside each other.
const PORT := DirectTransport.DEFAULT_PORT + 13

var _tree: SceneTree
var _me: String = ""
var _late: bool = false
var _relay: bool = false
var _skew: bool = false
## `shots=<dir>`: a still of each moment Jon asked to look at, from this
## machine's side, as `<dir>/<nn>_<what>_<host|guest>.png`. Needs a window (run
## through render_slot.sh); headless has no pixels and saves nothing.
var _shots: String = ""
## `hold=<seconds>`: how long a host waits before each move, so a partner in a
## window (slower: it animates) is still beside it when it takes its stills.
var _hold: float = 0.0


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	var argv := OS.get_cmdline_user_args()
	var hosting := "host" in argv
	_late = "late" in argv
	_relay = "relay" in argv
	_skew = "skew" in argv
	for a in argv:
		if a.begins_with("shots="):
			_shots = a.substr(6)
		if a.begins_with("hold="):
			_hold = float(a.substr(5))
	if _shots != "" and DisplayServer.get_name() == "headless":
		_shots = ""
	# THE GUEST CLAIMS A DIFFERENT GALAXY, so the mismatch guard is flown for
	# real: both machines must log it and put it on screen.
	if _skew and not hosting:
		Net.forced_galaxy = 777
	_me = "HOST" if hosting else "GUEST"
	if hosting:
		await _host()
	else:
		await _join(argv)
	if _fails == 0:
		await _fly()
	# Let the last pushes leave before the socket shuts, or the partner reads a
	# clean ending as the host dropping.
	await _wait(1.5)
	print("")
	verdict("cojoin[%s]" % _me)
	Net.leave_party()
	tree.quit(code())


# --- into one galaxy --------------------------------------------------------

func _host() -> void:
	var t: NetTransport
	if _relay:
		t = RelayTransport.new()
	else:
		var d := DirectTransport.new()
		d.advertise = "127.0.0.1"
		d.port = PORT
		t = d
	var code := Net.host_party("Kevin", &"", t)
	if code.is_empty():
		_fail("could not host: %s" % Net.last_error())
		return
	# A relay code is known before the socket opens; wait until it has, or the
	# guest knocks on a room nobody is in yet.
	await _until(func() -> bool:
		return Net.multiplayer.multiplayer_peer != null and \
			Net.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, 15.0)
	print(CODE_TAG + LobbyCode.pretty(code))
	Net.set_ready(true)
	if _late:
		# Alone into the dive, and a jump flown, before anybody else is here.
		_ok("the host launched alone", Net.launch_dive())
		return
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
		_fail("no code: -- cojoin join CODE")
		return
	if not Net.join_party(code, "Jon", &"", NetTransport.for_code(code)):
		_fail("could not join: %s" % Net.last_error())
		return
	var seated := await _until(func() -> bool:
		return Net.state == NetSession.State.IN_PARTY or Net.state == NetSession.State.DIVING,
		PARTNER_TIMEOUT)
	if not _ok("joined the party", seated):
		print("  GUEST: %s" % Net.last_error())
		return
	Net.set_ready(true)


# --- the flight -------------------------------------------------------------

func _fly() -> void:
	var launched := await _until(func() -> bool: return Net.dive_seed != 0, PARTNER_TIMEOUT)
	if not _ok("%s is in the dive" % _me, launched):
		return
	# What LobbyScreen._on_launched and the chassis select do.
	Router.new_run(Net.dive_seed)
	Run.fit_chassis()
	Router.show_local()
	await _wait(0.3)
	print("[cojoin] galaxy %s" % _galaxy_print())
	print("[cojoin] seat %d" % Rng.seat)

	if _late:
		await _late_leg()
		return
	if _skew:
		var warned := await _until(func() -> bool: return Net.galaxy_warning != "", 15.0)
		_ok("%s is told the galaxies differ" % _me, warned)
		var notice: PartyNotice = null
		for c in _tree.root.find_children("*", "PartyNotice", true, false):
			notice = c
		_ok("and it is on %s's screen" % _me, notice != null and notice.visible)
		print("  %s: %s" % [_me, Net.galaxy_warning])
		await _wait(1.0)
		return
	# Everybody built the same galaxy, and nobody was told otherwise.
	await _wait(1.0)
	_ok("%s was not warned about the galaxy" % _me, Net.galaxy_warning == "")

	var other := _other_id()
	if not _ok("the partner is in the roster", other != 0):
		return
	# --- both at the start ---------------------------------------------------
	var both := await _until(func() -> bool: return Net.where_is(other) == Run.at, PARTNER_TIMEOUT)
	_ok("both ships start in one system, and each knows it", both)
	await _wait(0.5)
	await _check_local_together("at the start")
	if _shots != "":
		# the run's opening fly-in and the partner's own arrival, played out
		await _wait(5.0)
	await _shot("01_local_start")
	await _check_sector_map("at the start")

	# --- the host jumps, the guest follows ----------------------------------
	var target := -1
	if _me == "HOST":
		await _wait(_hold)
		target = _pick_jump()
		if not _ok("there is a system to jump to", target >= 0):
			return
		await _jump(target)
		_ok("the host jumped", Run.at == target)
	else:
		var moved := await _until(func() -> bool:
			var w := Net.where_is(other)
			return w >= 0 and w != Run.at, PARTNER_TIMEOUT)
		if not _ok("the guest saw the host leave", moved):
			return
		target = Net.where_is(other)
		_ok("and can follow it there", Run.can_jump_to(Run.map[target]))
		await _jump(target)
		_ok("the guest followed into the host's system", Run.at == target)
	print("[cojoin] target %d %s" % [target, MapGen.star_name(Run.map[target])])
	var met := await _until(func() -> bool: return Net.where_is(other) == Run.at, PARTNER_TIMEOUT)
	_ok("both ships are in the same system", met)
	await _wait(0.5)
	await _check_local_together("after the jump")
	await _check_chart("after the jump")
	await _check_sector_map("after the jump", true)

	# --- the host opens the system's fight, the guest joins it ------------------
	await _fight_leg(target, other)

	# --- apart, then together again -----------------------------------------
	await _apart_leg(other)


## The fight a system's hostile option opens, as `LocalEventDrawer._fight`
## opens it, and the guest's way into it.
func _fight_leg(at: int, other: int) -> void:
	# Out of the band, back on a LOCAL with nothing over it.
	if Router.current is SectorScreen and Router.combat == null:
		pass
	if _me == "HOST":
		await _wait(_hold * 0.5)
		Router.start_ambush()
		var up := await _until(func() -> bool: return Router.combat != null, 5.0)
		if not _ok("the host's option opened a fight", up):
			return
	else:
		var open := await _until(func() -> bool: return Net.fight_open_at(at), 30.0)
		if not _ok("the guest can see the host's fight is open here", open):
			# What the game offered the guest before this fix: engage_here on a
			# node that has no fight of its own (BotPilot's door).
			print("  GUEST: Net.fight_at(%d) = %s" % [at, Net.fight_at(at)])
			return
		var can := Router.has_method("can_join_fight") and bool(Router.call("can_join_fight"))
		_ok("and the screen offers to join it", can)
		if _shots != "":
			if not Router.current is SectorScreen:
				Router.show_local()
			await _wait(2.0)
			await _shot("05_local_join_fight_bar")
			Router.show_system()
			await _until(func() -> bool: return Router.current is SystemMapScreen, 6.0)
			await _wait(1.5)
			await _shot("06_map_panel_join_fight")
		if Router.has_method("join_fight"):
			Router.call("join_fight")
		else:
			# The only door the game had: BotPilot's, ENGAGE on the system.
			Router.engage_here()
		var up := await _until(func() -> bool: return Router.combat != null, 5.0)
		if not _ok("the guest's JOIN opened a fight", up):
			return
	var cb: Combat = Router.combat
	var shared := await _until(func() -> bool: return cb.is_shared(), 10.0)
	if not _ok("%s's fight is the party's, not a private one" % _me, shared):
		await _play(cb)
		return
	var together := await _until(func() -> bool:
		var f := Net.fight_at(at)
		return f != null and f.crew.size() >= 2, PARTNER_TIMEOUT)
	if not _ok("both ships are in one fight", together):
		await _play(cb)
		return
	if _shots != "":
		await _wait(3.0)
		await _shot("07_shared_fight")
	var f0 := Net.fight_at(at)
	_ok("against the same enemy on both machines (%s)" % f0.foe_ids[0],
		String(cb.enemies[0].template.id) == f0.foe_ids[0])
	_ok("grown for two ships", f0.foes[0].max_hp > f0.foes[0].base)
	await _play(cb)
	var f1 := Net.fight_at(at)
	print("[cojoin] outcome %s %s paid%d" % [cb.result, f0.foe_ids[0], f1.paid if f1 != null else -1])
	if cb.result != &"victory":
		return
	# The wrecks belong to the system: both machines see one pile.
	var n: MapGen.MapNode = Run.map[at]
	var desc := PackedStringArray()
	var h0: MapGen.Jetsam = null
	var slot := -1
	for raw in n.jetsam:
		var h: MapGen.Jetsam = raw
		if not h.is_wreck():
			continue
		var ids := PackedStringArray()
		for i in h.items.size():
			var m: Variant = h.items[i]
			ids.append(String((m as ModuleData).id) if m is ModuleData else "credits")
			if slot < 0:
				h0 = h
				slot = i
		desc.append("%s[%s]" % [h.art, ",".join(ids)])
	print("[cojoin] wreck %s" % "|".join(desc))
	if slot < 0:
		# An empty wreck is a roll, not a bug: the pile matching on both machines
		# (`wreck`, compared by the shell) is the claim, and there is nothing to
		# race for. Said so, rather than failed.
		print("  %s: the wreck rolled empty this seed; nothing to race for" % _me)
		print("[cojoin] took skip")
		print("[cojoin] taker nobody")
		await _until(func() -> bool: return not Router.fight_up(), 5.0)
		return
	var here := await _until(func() -> bool: return Net.where_is(other) == at, PARTNER_TIMEOUT)
	_ok("both still standing over it", here)
	var got := await Run.take_from_jetsam(n, h0, slot)
	await _wait(1.5)
	print("[cojoin] took %s" % ("yes" if got else "none"))
	await _until(func() -> bool: return Net.who_took(n.index, h0.option(slot)) != 0, 5.0)
	print("[cojoin] taker %s" % Net.name_of(Net.who_took(n.index, h0.option(slot))))
	# Back to LOCAL, the way the game hands a won fight over.
	await _until(func() -> bool: return not Router.fight_up(), 5.0)


## The guest flies on alone; the host goes somewhere else; then the host flies
## to wherever the guest is.
func _apart_leg(other: int) -> void:
	if Router.in_combat():
		return
	var from := Run.at
	if _me == "GUEST":
		var y := _pick_jump([from])
		if not _ok("the guest has somewhere else to go", y >= 0):
			return
		await _jump(y)
		print("[cojoin] apart guest %d" % Run.at)
		# The host must see it, on the chart's data, without anybody doing anything.
		await _until(func() -> bool: return Net.where_is(other) == Run.at, PARTNER_TIMEOUT)
		_ok("and the host came to it", Net.where_is(other) == Run.at)
	else:
		var gone := await _until(func() -> bool:
			var w := Net.where_is(other)
			return w >= 0 and w != Run.at, PARTNER_TIMEOUT)
		if not _ok("the host sees the guest fly on", gone):
			return
		var y := Net.where_is(other)
		print("[cojoin] apart guest %d" % y)
		# Straight there if it can, through one system if it cannot.
		if not Run.can_jump_to(Run.map[y]):
			var mid := _pick_jump([], y)
			if mid >= 0:
				await _jump(mid)
		if _ok("the host can reach the guest's system", Run.can_jump_to(Run.map[y])):
			await _jump(y)
			_ok("and is there", Run.at == y)
	await _wait(0.8)
	await _check_local_together("after meeting again")


## A friend joining a dive that already started.
func _late_leg() -> void:
	if _me == "HOST":
		var target := _pick_jump()
		if target >= 0:
			Router.begin_jump(target)
		var came := await _until(func() -> bool: return Net.party_size() >= 2, PARTNER_TIMEOUT)
		if not _ok("a late ship joined the running dive", came):
			return
		var other := _other_id()
		var placed := await _until(func() -> bool: return Net.where_is(other) >= 0, PARTNER_TIMEOUT)
		_ok("and is flying in it (it reported a system)", placed)
		await _wait(2.0)
	else:
		var other := _other_id()
		_ok("the late ship knows where the host is",
			await _until(func() -> bool: return Net.where_is(other) >= 0, 10.0))
		_ok("in the same galaxy (seed %d)" % Net.dive_seed, Run.map.size() > 0)
		await _wait(2.0)


# --- what each screen shows --------------------------------------------------

## LOCAL with the partner in it: drawn, and not drawn on top of your own ship.
func _check_local_together(when: String) -> void:
	if not Router.current is SectorScreen:
		Router.show_local()
		await _wait(0.4)
	var sc := Router.current as SectorScreen
	if not _ok("LOCAL is up %s" % when, sc != null):
		return
	var view: EncounterView = sc.get("_view")
	# Until your own hull has finished flying in and stopped: the arrival runs
	# about four seconds, and a hull measured mid-flight is in no place at all.
	var last := Rect2()
	var still := 0
	for i in 120:
		await _wait(0.1)
		var now: Rect2 = view.player_boxes()[0] if not view.player_boxes().is_empty() else Rect2()
		still = still + 1 if now.position.distance_to(last.position) < 0.5 else 0
		last = now
		# (and on screen: in a window a run opens with the ship held off the
		# left edge before its fly-in, which is still and in no place either)
		if still >= 8 and now.position.x >= 0.0:
			break
	var slots: Array = view.get("_made_convoy")
	if not _ok("LOCAL draws the partner %s" % when, slots.size() >= 1):
		return
	var partner: EncounterView.ConvoySlot = slots[0]
	_ok("and the partner's slot is on screen %s" % when, partner.is_inside_tree() and partner.is_visible_in_tree())
	# The INK of each hull, not the canvases: a canvas carries the exhaust's
	# clearance and the bob's headroom, and two canvases may touch where no
	# ship does.
	var a: Rect2 = view.player_boxes()[0]
	var b: Rect2 = partner.art.get_global_transform() * partner.art.ship_rect()
	b = b.intersection(partner.get_global_rect())
	print("  %s LOCAL: own hull %s, partner hull %s" % [_me, a, b])
	_ok("and the partner is not drawn over your own ship %s" % when,
		b.size.x > 0.0 and not a.intersects(b))


## The SECTOR map (`SystemMapScreen`) with the partner on it, and -- when
## `fly` -- the host flying to a world while the guest watches it go.
func _check_sector_map(when: String, fly: bool = false) -> void:
	Router.show_system()
	await _until(func() -> bool: return Router.current is SystemMapScreen, 6.0)
	await _wait(1.2 if _shots != "" else 0.8)
	var sm := Router.current as SystemMapScreen
	# In a window the map builds its system across frames (the sky is baked)
	# and has no ship, yours or anybody's, until it has.
	if sm != null:
		await _until(func() -> bool: return sm.flight != null, 8.0)
		await _wait(0.5)
	if not _ok("the SECTOR map is up %s" % when, sm != null):
		Router.show_local()
		return
	var marks: Array = sm.call("partner_marks") if sm.has_method("partner_marks") else []
	if _ok("the SECTOR map draws the partner's ship %s" % when, marks.size() >= 1):
		var own: Vector2 = sm.call("own_mark")
		print("  %s SECTOR: own %s, partner %s" % [_me, own, marks[0]])
		_ok("and not on top of your own %s" % when, (marks[0] as Vector2).distance_to(own) >= 8.0)
	await _shot("02_map_both_jumped_in" if fly else "02a_map_start")
	if fly:
		if _me == "HOST":
			var body := -1
			for i in sm.view.layout.bodies.size():
				if sm.view.layout.bodies[i].kind != &"belt":
					body = i
					break
			await _wait(_hold * 0.5)
			if body >= 0:
				sm.call("_fly", body, func() -> void: pass)
			print("  HOST flies to world %d on the map" % body)
			await _wait(2.5)
			await _shot("04_map_flying")
			await _wait(3.5)
		else:
			var first: Vector2 = marks[0] if marks.size() >= 1 else Vector2.INF
			var far := 0.0
			var deadline := float(Time.get_ticks_msec()) / 1000.0 + 8.0
			var shot_at := deadline - 5.0
			while float(Time.get_ticks_msec()) / 1000.0 < deadline:
				await _tree.process_frame
				if shot_at > 0.0 and float(Time.get_ticks_msec()) / 1000.0 > shot_at:
					shot_at = -1.0
					await _shot("04_map_flying")
				var m: Array = sm.call("partner_marks") if sm.has_method("partner_marks") else []
				if m.size() >= 1 and first != Vector2.INF:
					far = maxf(far, (m[0] as Vector2).distance_to(first))
			print("  GUEST saw the host's ship move %.0f px on the map" % far)
			_ok("the guest's map shows the host flying", far >= 6.0)
	Router.show_local()
	await _wait(0.4)


## The STAR CHART with the partner in your own system: beside your marker, not
## on it.
func _check_chart(when: String) -> void:
	Router.show_starchart()
	await _until(func() -> bool: return Router.current is StarchartScreen, 6.0)
	await _wait(0.6)
	var sc := Router.current as StarchartScreen
	if not _ok("the STAR CHART is up %s" % when, sc != null):
		Router.show_local()
		return
	var chart = sc.get("_chart")
	var marks: Array = chart.call("party_marks") if chart.has_method("party_marks") else []
	if _ok("the STAR CHART marks the partner %s" % when, marks.size() >= 1 or not chart.has_method("party_marks")):
		var own: Vector2 = chart.call("_screen_pos", Run.node_at())
		var theirs: Vector2 = marks[0][1] if marks.size() >= 1 else own
		print("  %s CHART: own %s, partner %s" % [_me, own, theirs])
		_ok("beside your own marker, not on top of it %s" % when, theirs.distance_to(own) >= 10.0)
	await _wait(1.0)
	await _shot("03_chart_partner_beside_you")
	Router.show_local()
	await _wait(0.4)


# --- the fight ---------------------------------------------------------------

func _play(cb: Combat) -> void:
	var turns := 0
	while not cb.finished and turns < TURN_CEILING:
		await _tree.process_frame
		if cb.waiting:
			continue
		turns += 1
		var acted := true
		while acted and not cb.finished:
			acted = false
			while cb.choosing > 0:
				cb.choose(cb.best_choice())
			var best := -1
			var best_at := 0.0
			for i in cb.hand.size():
				var c := cb.hand[i]
				if not cb.can_play(c):
					continue
				var sc := _score(c)
				if sc > best_at:
					best_at = sc
					best = i
			if best >= 0:
				cb.play(best)
				acted = true
		if not cb.finished:
			cb.end_turn()
			var released := await _until(func() -> bool:
				return not cb.waiting or cb.finished, 20.0)
			if not released:
				_fail("the barrier never released on turn %d" % turns)
				break
	_ok("%s's fight ended rather than stalling (%d turns, %s)" % [_me, turns, cb.result], cb.finished)


func _score(c: CardData) -> float:
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
	if c.block > 0 or c.brace > 0:
		return 30.0
	return 5.0


# --- plumbing ----------------------------------------------------------------

func _other_id() -> int:
	for s in Net.partners():
		return int(s.id)
	return 0


## A system this ship can jump to now that holds options (not a station), not
## one of `avoid`, and -- when `toward` is given -- one from which `toward` can
## be reached on the tank left.
func _pick_jump(avoid: Array = [], toward: int = -1) -> int:
	var best := -1
	var best_d := INF
	for n in Run.map:
		var m: MapGen.MapNode = n
		if m.index == Run.at or avoid.has(m.index) or not Run.can_jump_to(m):
			continue
		if m.type != MapGen.NodeType.SYSTEM:
			continue
		if toward >= 0:
			var d: float = (m.gal - Run.map[toward].gal).length()
			if d < best_d:
				best_d = d
				best = m.index
			continue
		return m.index
	return best


## The galaxy as both machines must have built it: how many systems, and every
## one's type and position. Compared across the two logs by the shell.
func _galaxy_print() -> String:
	var parts := PackedStringArray()
	for n in Run.map:
		var m: MapGen.MapNode = n
		parts.append("%d:%d:%d,%d" % [m.index, int(m.type), roundi(m.gal.x * 1000.0), roundi(m.gal.y * 1000.0)])
	return "%d systems, hash %d" % [Run.map.size(), hash(",".join(parts))]


## A jump, whole: in a window it is a departure, a flight and an arrival.
func _jump(to: int) -> void:
	Router.begin_jump(to)
	await _until(func() -> bool: return Run.at == to, 25.0)
	await _until(func() -> bool: return not Router.animating() or Router.current is SectorScreen, 5.0)
	await _wait(0.3)


## A still of what this machine shows now, when `shots=` was given.
func _shot(what: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := _tree.root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_shots)
	var path := _shots.path_join("%s_%s.png" % [what, _me.to_lower()])
	img.save_png(path)
	print("[cojoin] shot %s" % path)


func _wait(s: float) -> void:
	await _until(func() -> bool: return false, s)


func _until(condition: Callable, timeout: float) -> bool:
	var deadline := float(Time.get_ticks_msec()) / 1000.0 + timeout
	while float(Time.get_ticks_msec()) / 1000.0 < deadline:
		if condition.call():
			return true
		await _tree.process_frame
	return false
