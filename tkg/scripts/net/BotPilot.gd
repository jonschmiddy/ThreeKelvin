class_name BotPilot
extends RefCounted

## The bot is a player holding its own `Run`, since `Run` is a singleton; it costs one seat.
## Why: docs/why/BotPilot.md#bot-as-player

## A slow brain stalls the `SharedFight` barrier, so the autopilot takes the turn at timeout.
## Why: docs/why/BotPilot.md#shot-clock
const THINK_DEFAULT: float = 25.0

## Nothing waits longer than this, whatever the command line says. A think time
## of 600 typed into a shell is a party wedged for ten minutes by a flag.
const THINK_MAX: float = 180.0

## A fight that has not ended in this many turns is a fight that is stuck.
const TURN_CEILING: int = 120

## A run that has not ended in this many jumps is a loop, not a dive.
const JUMP_CEILING: int = 600

const BOARD_FILE := "board.json"
const MOVE_FILE := "move.json"

var _tree: SceneTree
var policy: Policy = Policy.new()

## Empty means no brain: the autopilot flies the whole run, a spare ship for a small party.
var mailbox: String = ""
var think: float = THINK_DEFAULT
var pilot_name: String = "Claude"
var verbose: bool = false

## A follower must hold, not only approach: a fast bot reaches the party's systems first.
## Why: docs/why/BotPilot.md#following
var follow: bool = false
var patience: float = PATIENCE_DEFAULT
## What the party looked like last time anything about it changed, and when.
var _stamp: int = 0
var _stamp_at: float = 0.0

## Moves quote the board number; a stale move is about a different game and is dropped.
## Why: docs/why/BotPilot.md#board-numbers
var _seq: int = 0
var _asked: int = 0
var _answered: int = 0
var _expired: int = 0


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	_read_args()

	# A detached holder lets the bot use the same Router as humans, not a second path that rots.
	var holder := Control.new()
	tree.root.add_child(holder)
	Router.register(holder, null)

	if not await _seat():
		tree.quit(1)
		return
	if not await _launch():
		tree.quit(1)
		return
	await _fly()

	print("[bot] %s: %s after %d jumps and %d kills — %s" % [
		pilot_name,
		"WON" if Run.won else ("LOST" if Run.dead else "stopped"),
		Run.jumps, Run.kills,
		Run.death_reason if Run.dead else "the core"])
	print("[bot] boards offered %d · answered %d · timed out %d" % [
		_asked, _answered, _expired])
	Net.leave_party()
	await tree.process_frame
	# Freed explicitly: a headless exit reports every live Control as a leak.
	Router.current = null
	holder.queue_free()
	await tree.process_frame
	tree.quit(0)


func _read_args() -> void:
	var argv := OS.get_cmdline_user_args()
	for i in argv.size():
		var a := argv[i]
		if a.begins_with("mailbox="):
			mailbox = a.substr(8)
		elif a.begins_with("think="):
			think = clampf(float(a.substr(6)), 0.0, THINK_MAX)
		elif a.begins_with("name="):
			pilot_name = a.substr(5)
		elif a == "verbose":
			verbose = true
		elif a == "follow":
			follow = true
		elif a.begins_with("patience="):
			patience = maxf(0.0, float(a.substr(9)))
	if follow:
		print("[bot] following the party · patience %.0fs" % patience)
	if mailbox.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(mailbox)
	# Clear a leftover move: it is about a galaxy that no longer exists.
	DirAccess.remove_absolute(mailbox.path_join(MOVE_FILE))
	print("[bot] mailbox %s · shot clock %.0fs" % [mailbox, think])


# --- getting into the party -----------------------------------------------

## Hosting makes the bot the party; joining is for everything else.
func _seat() -> bool:
	var argv := OS.get_cmdline_user_args()

	if "host" in argv:
		# Hosting picks: the relay unless told otherwise, because a bot that
		# hosts is a bot somebody has to reach from another machine.
		var t: NetTransport = DirectTransport.new() if "direct" in argv \
			else RelayTransport.new()
		var code := Net.host_party(pilot_name, &"", t)
		if code.is_empty():
			printerr("[bot] could not host: %s" % Net.last_error())
			return false
		print("[bot] code %s" % LobbyCode.pretty(code))
		Net.set_ready(true)
		return true

	var code2 := ""
	for i in argv.size():
		if argv[i] == "join" and i + 1 < argv.size():
			code2 = LobbyCode.normalise(argv[i + 1])
	if code2.is_empty():
		printerr("[bot] no code: godot --headless --path . -- bot join CODE")
		return false
	# Transport comes from the lobby code, as `LobbyScreen._join()` does, not from a flag.
	if not Net.join_party(code2, pilot_name, &"", NetTransport.for_code(code2)):
		printerr("[bot] could not join: %s" % Net.last_error())
		return false
	if not await _until(func() -> bool: return Net.state == NetSession.State.IN_PARTY, 30.0):
		printerr("[bot] never seated: %s" % Net.last_error())
		return false
	print("[bot] %s joined the party as peer %d" % [pilot_name, Net.local_id()])
	# Ready immediately and stay ready. A bot that has to be told to be ready is
	# a bot the host has to wait for, and it has no opinion about when to leave.
	Net.set_ready(true)
	return true


## Wait for the dive, then roll a ship on the party's galaxy.
func _launch() -> bool:
	if Net.is_host():
		# Hosting: go when the humans are ready. Nobody else can start it.
		if not await _until(func() -> bool:
				return Net.party_size() >= 2 and Net.everyone_ready(), 600.0):
			printerr("[bot] nobody joined")
			return false
		Net.launch_dive()
	if not await _until(func() -> bool: return Net.dive_seed != 0, 900.0):
		printerr("[bot] the dive never started")
		return false

	Router.new_run(Net.dive_seed)
	# A bot picks a random chassis, as the launcher does for a player who skips reading.
	Run.fit_chassis()
	await _tree.process_frame
	# The pilot generator keys on the seat, or a bot and a human would make identical choices.
	policy.pilot = Rng.derive(&"pilot", Rng.seat)
	print("[bot] %s flying a %s · galaxy %s · seat %d" % [
		pilot_name, Run.hull.display_name(), Run.galaxy_name, Rng.seat])
	return true


# --- the run --------------------------------------------------------------

func _fly() -> void:
	var guard := 0
	# A holding bot would otherwise sell its hold to the same station on every loop pass.
	var done := -1
	while not Run.won and not Run.dead and guard < JUMP_CEILING:
		guard += 1
		await _tree.process_frame
		if Net.state == NetSession.State.OFFLINE:
			print("[bot] the party ended. Standing down.")
			return

		# A fight can start on arrival without being asked for — an ambush
		# follows heat in — so this is checked before anything else is decided.
		if Router.in_combat():
			await _fight(Router.combat)
			continue

		var n: MapGen.MapNode = Run.node_at()
		if Run.at != done:
			done = Run.at
			match n.type:
				MapGen.NodeType.STATION:
					await _station()
				MapGen.NodeType.PULSAR:
					if not n.cleared:
						Run.harvest_pulsar()
				MapGen.NodeType.SYSTEM:
					if not n.cleared:
						Router.show_sector()
			if Run.dead or Run.won:
				break
			policy.manage_cargo()

		# A fight is joined by engaging, not by being present.
		if Router.can_join_fight():
			Router.join_fight()
			continue

		var pick := await _next_system(n)
		if pick == HOLD:
			await _hold()
			continue
		if pick < 0:
			Run.check_stranded()
			print("[bot] nowhere to go from %s." % MapGen.star_name(n))
			return
		if verbose:
			print("[bot] %s -> %s (%s, danger %d)" % [
				MapGen.star_name(n), MapGen.star_name(Run.map[pick]),
				BotBoard._node_type(Run.map[pick].type), Run.map[pick].danger])
		Run.jump_to(pick)
		await _tree.process_frame


## Holding must expire or two followers wait forever; the clock resets on any sign of life.
## Why: docs/why/BotPilot.md#patience
const PATIENCE_DEFAULT: float = 150.0

## Long enough not to busy-loop, short enough to notice a partner arriving.
const HOLD_BEAT: float = 1.5
## Not an index and not "no route" — "the right move is to stay here".
const HOLD: int = -2

func _hold() -> void:
	var until := _now() + HOLD_BEAT
	while _now() < until:
		await _tree.process_frame
		# Interrupted the moment anything happens worth reacting to.
		if Router.in_combat() or Net.state == NetSession.State.OFFLINE:
			return


## Deciding and moving are separate so HOLD is expressible; a bool return outran the party.
## Why: docs/why/BotPilot.md#next-system
func _next_system(here: MapGen.MapNode) -> int:
	var move := await _ask(BotBoard.map(_seq + 1))
	if move == "hold" or move == "wait":
		return HOLD
	if move.begins_with("jump "):
		var want := int(move.substr(5))
		# Check a brain's target: it may be an old board, and `jump_to()` ignores illegal ones.
		if want >= 0 and want < Run.map.size() and here.links.has(want) \
				and Run.can_jump_to(Run.map[want]):
			return want
		print("[bot] %d is not somewhere this ship can go." % want)
	if follow:
		var w := _wingman(here)
		if w != -1:
			return w
	return policy.choose_jump(here)


## Distance is map position, not jump count; -1 hands a lone survivor back to Policy.
## Why: docs/why/BotPilot.md#wingman-rule
func _wingman(here: MapGen.MapNode) -> int:
	# Seat order breaks mirrored following, which deadlocked two followers between two stars.
	# Why: docs/why/BotPilot.md#follow-order
	var mine := Net.seat()
	var mates: Array[int] = []
	for s in Net.partners():
		if int(s.get("order", 0)) >= mine:
			continue
		var at := int(s.get("at", -1))
		if at >= 0 and at < Run.map.size():
			mates.append(at)
	if verbose:
		var where: Array = []
		for m in Net.partners():
			where.append("%s@%s" % [m.get("name", "?"), m.get("at", -1)])
		print("[bot] wingman: I am at %d, party %s" % [Run.at, " ".join(where)])
	if mates.is_empty():
		return -1

	# Somebody is standing right here. Do not leave. Whatever they are about to
	# do, this ship wants to be in the room for it — until the room goes quiet.
	if mates.has(Run.at):
		return HOLD if _still_waiting() else -1

	# Somebody is one jump away. Go, whatever it costs — a system with a party
	# member in it is a system with a fight you can be paid for.
	for idx in here.links:
		if mates.has(idx) and Run.can_jump_to(Run.map[idx]):
			return idx

	var target: MapGen.MapNode = Run.map[mates[0]]
	for at in mates:
		if Run.map[at].pos.distance_to(here.pos) < target.pos.distance_to(here.pos):
			target = Run.map[at]
	var best := -1
	var best_d := here.pos.distance_to(target.pos)
	for idx in here.links:
		var n: MapGen.MapNode = Run.map[idx]
		if not Run.can_jump_to(n):
			continue
		var d := n.pos.distance_to(target.pos)
		if d < best_d:
			best_d = d
			best = idx
	# Wait rather than wander: a jump away from the party is wasted fuel.
	if best >= 0:
		return best
	return HOLD if _still_waiting() else -1


## The stamp includes this ship's position: a ship that just jumped has a fresh reason to wait.
func _still_waiting() -> bool:
	var now := _now()
	var rows: Array = [Run.at]
	for s in Net.partners():
		rows.append([int(s.get("id", 0)), int(s.get("at", -1))])
	rows.append(Net.fight_open_at(Run.at))
	var next := hash(rows)
	if next != _stamp:
		_stamp = next
		_stamp_at = now
		return true
	if patience <= 0.0:
		return false
	if now - _stamp_at < patience:
		return true
	print("[bot] nothing has moved in %.0fs. Flying on." % patience)
	_stamp_at = now
	return false


## Buying is the brain's, because the shelf is contested with the rest of the party.
func _station() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n.type != MapGen.NodeType.STATION:
		return
	policy.sell_hold(n)
	policy.bench(n)
	var guard := 0
	while guard < 12:
		guard += 1
		var move := await _ask(BotBoard.station(_seq + 1))
		if move == "leave" or move.is_empty():
			break
		if move == "pass":
			policy.shop(n)
			break
		if move == "repair":
			var missing := Run.max_hp() - Run.hp
			var price := Market.repair_price(n, missing)
			if missing > 0 and Run.credits >= price:
				Run.add_credits(-price)
				Run.heal(missing)
			continue
		if move == "refuel":
			Run.buy_refuel(n)
			continue
		if move.begins_with("sell "):
			var si := int(move.substr(5))
			if si >= 0 and si < Run.cargo.size():
				var m: ModuleData = Run.cargo[si]
				Run.take_from_hold(m)
				Run.add_credits(Market.bid(n, m))
				n.trades += 1
			continue
		if move.begins_with("buy "):
			await _buy(n, int(move.substr(4)))
			continue
		break


## Ask the party first through `Run.take_option`, as a human does; buying locally duplicated shops.
## Why: docs/why/BotPilot.md#shelf-claims
func _buy(n: MapGen.MapNode, slot: int) -> void:
	if slot < 0 or slot >= n.shop.size():
		return
	var m: ModuleData = n.shop[slot]
	var price := Market.ask(n, m)
	if Run.credits < price:
		print("[bot] cannot afford %s at %d." % [m.name, price])
		return
	if not Run.has_room_for(m):
		print("[bot] the hold is full.")
		return
	if not await Run.take_option(n, MapGen.OPTION_SHOP + slot):
		var who := Net.taker_name(n.index, MapGen.OPTION_SHOP + slot)
		print("[bot] %s was already sold%s." % [
			m.name, (" — %s got there first" % who) if who != "" else ""])
		return
	Run.add_credits(-price)
	Run.stow(m)
	print("[bot] bought %s for %d." % [m.name, price])


# --- a fight --------------------------------------------------------------

func _fight(cb: Combat) -> void:
	var turns := 0
	# Announced once, not at the top: `Router.start_combat` asks the party after assigning.
	var said := false
	while not cb.finished and turns < TURN_CEILING:
		# Yield first. A turn that opens the instant the last one closed gives
		# the socket no frame to deliver anything in.
		await _tree.process_frame
		if Net.state == NetSession.State.OFFLINE:
			return
		if not said and cb.is_shared():
			# Excludes you: `fight_crew_names` lists the other ships, so one name means two.
			var crew := Net.fight_crew_names(cb.shared_at)
			if crew.size() > 0:
				said = true
				print("[bot] in this one alongside %s." % ", ".join(crew))
		# Waiting on the barrier is not a decision, so it is not offered as one.
		# Nor is waiting for the host's answer, or a stun: nothing is dealt yet.
		if cb.waiting or cb.asking_at >= 0 or cb.stunned:
			continue
		turns += 1
		var acting := true
		var guard := 0
		while acting and not cb.finished and guard < 40:
			guard += 1
			var move := await _ask(BotBoard.fight(cb, _seq + 1))
			if cb.finished:
				return
			match move:
				"end_turn", "":
					acting = false
				"pass":
					# Policy finishes the turn: the shot clock's escape hatch.
					while cb.choosing > 0:
						cb.choose(cb.best_choice())
					var best := policy.best_card(cb)
					while best >= 0 and not cb.finished:
						cb.play(best)
						best = policy.best_card(cb)
					acting = false
				"flee":
					cb.flee()
					return
				_:
					if move.begins_with("play "):
						var i := int(move.substr(5))
						if i >= 0 and i < cb.hand.size() and cb.can_play(cb.hand[i]):
							cb.play(i)
						else:
							print("[bot] %s is not a card this ship can play." % move)
							acting = false
					else:
						acting = false
		if cb.finished:
			break
		cb.end_turn()
		# Wait to be let back in: `end_turn` returns at once with `waiting` set on a shared fight.
		if not await _until(func() -> bool: return not cb.waiting or cb.finished, 90.0):
			print("[bot] the fight stopped moving. Standing down from it.")
			return
	if cb.finished:
		print("[bot] fight over: %s — %s" % [cb.result, cb.summary])


# --- the mailbox ----------------------------------------------------------

## Files, not a socket: Godot has no HTTP server and anything that can write a file can play.
## Why: docs/why/BotPilot.md#file-mailbox
func _ask(board: Dictionary) -> String:
	_seq += 1
	if mailbox.is_empty():
		return "pass"
	_asked += 1
	board["seq"] = _seq
	board["think"] = think
	_write(BOARD_FILE, JSON.stringify(board, "\t"))
	print("[bot] #%d %s — %s" % [_seq, board.get("kind", "?"), _summary(board)])

	var deadline := _now() + think
	while _now() < deadline:
		await _tree.process_frame
		var move := _read_move()
		if move.is_empty():
			continue
		_answered += 1
		print("[bot] #%d -> %s" % [_seq, move])
		return move
	_expired += 1
	print("[bot] #%d timed out after %.0fs. Policy takes it." % [_seq, think])
	return "pass"


## A move quoting an older seq is dropped: it was written about a hand since played.
func _read_move() -> String:
	var path := mailbox.path_join(MOVE_FILE)
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var raw := f.get_as_text()
	f.close()
	DirAccess.remove_absolute(path)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		# A bare string is allowed: the seq check is a safety rail, not a toll booth.
		var bare := raw.strip_edges()
		return bare if not bare.is_empty() and not bare.begins_with("{") else ""
	var d := parsed as Dictionary
	var seq := int(d.get("seq", _seq))
	if seq != _seq:
		print("[bot] dropped a move for #%d; this is #%d." % [seq, _seq])
		return ""
	return String(d.get("do", "")).strip_edges()


## One line a human can read in a log, for the board that is a page of JSON.
func _summary(b: Dictionary) -> String:
	match String(b.get("kind", "")):
		"fight":
			var names: Array = []
			for e in b.get("enemies", []):
				if bool(e.get("alive", false)):
					names.append("%s %d/%d" % [e.get("name", "?"), e.get("hp", 0), e.get("max_hp", 0)])
			return "turn %d · %d energy · %s · hull %d/%d" % [
				b.get("turn", 0), b.get("energy", 0),
				" ".join(names) if names.size() > 0 else "nothing standing",
				b.get("me", {}).get("hp", 0), b.get("me", {}).get("max_hp", 0)]
		"map":
			return "%s · %d fuel · %d ways out" % [
				b.get("system", "?"), b.get("me", {}).get("fuel", 0),
				b.get("moves", []).size()]
		"station":
			return "%s · %d credits · %d on the shelf" % [
				b.get("system", "?"), b.get("me", {}).get("credits", 0),
				b.get("shelf", []).size()]
	return ""


func _write(name: String, text: String) -> void:
	var f := FileAccess.open(mailbox.path_join(name), FileAccess.WRITE)
	if f == null:
		printerr("[bot] cannot write %s" % mailbox.path_join(name))
		return
	f.store_string(text)
	f.close()


func _until(cond: Callable, seconds: float) -> bool:
	var deadline := _now() + seconds
	while _now() < deadline:
		if cond.call():
			return true
		await _tree.process_frame
	return cond.call()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
