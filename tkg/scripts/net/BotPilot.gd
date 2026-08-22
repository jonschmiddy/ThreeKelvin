class_name BotPilot
extends RefCounted

## A ship in the party that nobody is sitting in front of.
##
##   godot --headless --path . -- bot join ABC-123
##   godot --headless --path . -- bot join ABC-123 mailbox=/tmp/crew think=30
##   tools/bot.sh ABC-123
##
## It is a PLAYER, not a spectator and not a service. It joins by lobby code
## like anybody else, gets a peer id from the relay, rolls its own chassis, and
## from that moment holds its own `Run` — its own hull, hold, heat, credits and
## `Rng` seat. Nothing about the party knows or cares that the pilot is a
## program. That is not a flourish; it is the only design that works, because
## `Run` is a singleton and one process therefore holds exactly one ship.
##
## THE PRICE IS A SEAT. `NetTransport.MAX_PLAYERS` bounds the party and the
## relay's door policy enforces it, so a bot in the party means one fewer human.
## There is no spectator slot to hide in and adding one would mean the relay
## counting something it deliberately does not count.
##
## Stated without the number on purpose. This paragraph said "four" and went on
## saying it after the cap became eight — the same bump that left NetTest
## asserting a four-seat party in nine places. A comment that repeats a constant
## is a second copy of it.
##
## WHY NOT READ THE RELAY INSTEAD. The obvious cheaper idea is to watch the
## Cloudflare Durable Object and narrate. It does not work, twice over.
## `relay/src/index.js` never opens a payload — it checks byte 0, rewrites the
## sender id and forwards — so what is on that socket is Godot's binary RPC
## frames and nothing else; reading them means reimplementing the engine's
## serialiser. And the relay cannot invent a peer, so even after all that the
## result is a spectator with no ship, no hold and no cards. The seat is the
## feature. See docs/netcode.md §7.

## How long a remote brain gets to answer before the autopilot takes the turn.
##
## THE SHOT CLOCK IS NOT OPTIONAL, and it is the single most important number in
## this file. `SharedFight.end_turn()` is a barrier: the enemy does not swing
## until every ship in the fight has ended its turn, so a bot that is still
## thinking is three other people watching a static screen. A brain with a
## language model behind it answers in seconds and occasionally in minutes, and
## "occasionally in minutes" is a hung party.
##
## So the deal is: the board is offered, an answer is waited for, and when the
## clock runs out `Policy` plays the turn and the fight moves on. The bot is
## allowed to be slow. It is not allowed to be slow at everybody else.
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

## Where the brain and the ship leave notes for each other. Empty means there is
## no brain and the autopilot flies the whole run, which is a useful mode in its
## own right: it is a fourth ship for a party of three.
var mailbox: String = ""
var think: float = THINK_DEFAULT
var pilot_name: String = "Claude"
var verbose: bool = false

## Fly toward the rest of the party rather than off on its own dive.
##
## Without this the bot is a fourth ship in the same galaxy, which is not the
## same thing as a crewmate: everybody flies their own route, the routes diverge
## on the first fork, and the shared fight — the one feature the party actually
## has — never once happens. `Policy.choose_jump` is a SOLO player's model and
## correctly so; it has no concept of anybody else being on the map.
##
## Following is deliberately dumb: take a link somebody is standing in, else
## take the link that moves toward the nearest of them, else HOLD. Pathfinding
## across the whole galaxy would be a better bot and a worse crewmate — it would
## arrive by a route nobody watched it take.
##
## HOLDING IS THE HALF THAT MATTERS, and it is the half the first version was
## missing. A headless ship plays a complete run in about forty seconds; a
## person takes an hour. So a bot that only ever moves TOWARD the party arrives
## at their system, wins the fight, and is four jumps deeper before anybody
## lands — the two ships visit exactly the same systems and never once meet.
## Two bots flown against each other did precisely that: identical first two
## fights, identical payouts, not one shared enemy between them.
##
## So a following ship does not leave a system somebody is in, and does not jump
## anywhere that does not close the distance. Standing still is a move.
var follow: bool = false
var patience: float = PATIENCE_DEFAULT
## What the party looked like last time anything about it changed, and when.
var _stamp: int = 0
var _stamp_at: float = 0.0

## Every board gets a number and every move must quote it.
##
## Without this a move written while the bot was mid-decision applies to the
## NEXT board — the brain answers "play 2" about a hand it can still see, the
## card is drawn and discarded in the meantime, and 2 is now something else
## entirely. A stale move is not a wrong move, it is a move about a different
## game, and it has to be dropped rather than clamped.
var _seq: int = 0
var _asked: int = 0
var _answered: int = 0
var _expired: int = 0


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	_read_args()

	# Router builds real screens on every swap and `content` is null when Main
	# returned before registering one. Giving it a detached holder is cheaper
	# than teaching every screen about a mode it will never otherwise run in,
	# and it means the bot exercises the same Router the humans do rather than a
	# second path that can rot without anybody noticing.
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
	# The Router holder from _run(). Freed rather than left to the tree, because
	# a headless exit reports every live Control as a leak and a real leak would
	# then be one line in a wall of them.
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
	# A move left over from the last session is a move about a galaxy that no
	# longer exists. Clearing it here rather than checking for it later is the
	# difference between a confusing first turn and none.
	DirAccess.remove_absolute(mailbox.path_join(MOVE_FILE))
	print("[bot] mailbox %s · shot clock %.0fs" % [mailbox, think])


# --- getting into the party -----------------------------------------------

## Join by code, or host and wait. Hosting is the mode for "the bot is the
## party" — a fourth ship a solo player can dive with — and joining is the mode
## for everything else.
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
	# The transport comes out of the CODE, not off the command line. A lobby
	# code carries its own kind — an address for a direct party, a room number
	# for a relayed one — so a bot that took the transport from a flag could be
	# told to reach a relay room over a socket to nowhere. This is the same call
	# LobbyScreen._join() makes.
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
	# The chassis the select screen would have asked about. A bot has no taste
	# in hulls, and picking one at random on the party's seat is the same thing
	# the launcher does for a player who presses the button without reading.
	Run.fit_chassis()
	await _tree.process_frame
	# The pilot's generator, on this ship's seat rather than on the sim's
	# convention. `Rng.derive` keys on a tag and an index, and every ship in the
	# party derives from the same master seed — so without the seat in the tag,
	# a bot and a human who both flew a Policy would make identical choices.
	policy.pilot = Rng.derive(&"pilot", Rng.seat)
	print("[bot] %s flying a %s · galaxy %s · seat %d" % [
		pilot_name, Run.hull.display_name(), Run.galaxy_name, Rng.seat])
	return true


# --- the run --------------------------------------------------------------

func _fly() -> void:
	var guard := 0
	# The node this ship has already dealt with. A holding bot sits on one
	# system for minutes waiting for the party, and without this it would sell
	# its hold to the same station on every pass of the loop.
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
				MapGen.NodeType.DERELICT:
					if not n.cleared:
						Router.salvage_here()
				MapGen.NodeType.FIGHT:
					if not n.cleared:
						Router.engage_here()
						continue
			if Run.dead or Run.won:
				break
			policy.manage_cargo()

		# Somebody else opened a fight in the system this ship is sitting in.
		# Getting into it is the entire reason a wingman holds position, and it
		# is not automatic: a fight is joined by ENGAGING, not by being present.
		if Net.fight_open_at(Run.at) and not n.cleared:
			Router.engage_here()
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


## How long a wingman waits on a party that is not doing anything.
##
## HOLDING HAS TO EXPIRE. Two following ships that find each other both see a
## partner in their own system, both decide the right move is to stay, and both
## stay — forever. Flown, and it is not a hypothetical: two bots met at system 7
## and sat there until they were killed. The same shape catches a bot whose
## human closed the lid.
##
## The clock resets on any sign of life — anybody moving, a fight opening,
## anybody arriving or leaving. So it is not a timeout on the wait, it is a
## timeout on NOTHING HAPPENING, which is the thing actually worth giving up on.
## Generous by default, because a person at a station picking over a shelf looks
## exactly like a person who has stopped playing, and of the two mistakes,
## abandoning somebody mid-shop is the worse one.
const PATIENCE_DEFAULT: float = 150.0

## A beat, spent watching rather than deciding. Long enough that a held station
## is not a busy loop, short enough that a partner arriving is noticed within a
## breath of it happening.
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


## Where to go next: an index, HOLD, or -1 for nowhere.
##
## Deciding and moving are separate because HOLD has to be expressible. A
## function that jumps cannot return "do not jump" — the first version returned
## a bool and had no way to say it, which is how the bot ended up outrunning the
## party it was supposed to be flying with.
func _next_system(here: MapGen.MapNode) -> int:
	var move := await _ask(BotBoard.map(_seq + 1))
	if move == "hold" or move == "wait":
		return HOLD
	if move.begins_with("jump "):
		var want := int(move.substr(5))
		# Checked rather than trusted. A brain that names an unreachable system
		# is not cheating, it is looking at a board from two jumps ago — and
		# jump_to() on an illegal target silently does nothing, which would spin
		# the flight loop until the guard caught it.
		if want >= 0 and want < Run.map.size() and here.links.has(want) \
				and Run.can_jump_to(Run.map[want]):
			return want
		print("[bot] %d is not somewhere this ship can go." % want)
	if follow:
		var w := _wingman(here)
		if w != -1:
			return w
	return policy.choose_jump(here)


## The wingman rule: go where they are, move toward them, or stay put.
##
## Distance is measured in map position rather than in jumps. A jump count would
## need a search over a graph that changes as the party moves through it, and it
## would buy nothing: what this has to answer is "which of these four systems is
## the one toward them", and a straight line answers that correctly almost every
## time and harmlessly the rest.
##
## Returns -1 only when there is nobody left to follow, which hands the run back
## to Policy — a lone survivor should finish the dive rather than orbit an empty
## galaxy waiting for ships that are not coming.
func _wingman(here: MapGen.MapNode) -> int:
	# A WINGMAN FOLLOWS THE SHIPS THAT WERE HERE BEFORE IT. Seat order, and
	# nothing cleverer, because the alternative was flown and it deadlocks: two
	# ships that both follow mirror each other exactly. A leaves for the next
	# system, B follows, A sees B gone and follows back, and the pair bounce
	# between two stars until the tank runs dry. That is not a bug in the
	# distance maths — it is what "follow whoever is nearest" MEANS when the
	# other ship is running the same line of code.
	#
	# So the order in the roster breaks it: seat 0 leads and never follows,
	# every later seat follows the seats before it. The host is the human who
	# opened the party, which is also the right answer socially.
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
	# Nothing closes the gap. Wait for them rather than wander: every jump that
	# is not toward the party is fuel spent getting further from the only thing
	# this ship is out here to do.
	if best >= 0:
		return best
	return HOLD if _still_waiting() else -1


## Is anything still happening? Resets the clock when the party moves, and
## reports false once it has been quiet for `patience` seconds.
##
## The stamp deliberately includes THIS ship's position: a bot that has just
## jumped is a bot with a fresh reason to wait where it landed.
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


## Dock. Selling and the workbench are Policy's, because they are bookkeeping;
## buying is the brain's, because the shelf is CONTESTED — a part bought here is
## a part another ship in the party cannot have, and that is a decision somebody
## should get to make on purpose.
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
			var rp := Market.refuel_price(n)
			if Run.credits >= rp:
				Run.add_credits(-rp)
				Run.fuel += Market.REFUEL_UNITS
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


## Reach for a shelf slot, and ASK THE PARTY FIRST.
##
## This is the same claim StationScreen makes when a person clicks it, and it
## goes through the same `Run.take_option`, so the bot loses the same races a
## human loses and for the same reason. Doing it any other way — buying locally
## and telling the party afterwards — is how the shop duplication bug worked.
func _buy(n: MapGen.MapNode, slot: int) -> void:
	if slot < 0 or slot >= n.shop.size():
		return
	var m: ModuleData = n.shop[slot]
	var price := Market.ask(n, m)
	if Run.credits < price:
		print("[bot] cannot afford %s at %d." % [m.name, price])
		return
	if Run.hold_full():
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
	# Announced once, and not at the top: `Router.start_combat` assigns the
	# fight and THEN asks the party, so on a client there is a round trip during
	# which a shared fight is indistinguishable from a private one.
	var said := false
	while not cb.finished and turns < TURN_CEILING:
		# Yield first. A turn that opens the instant the last one closed gives
		# the socket no frame to deliver anything in.
		await _tree.process_frame
		if Net.state == NetSession.State.OFFLINE:
			return
		if not said and cb.is_shared():
			# EXCLUDES YOU. `fight_crew_names` is written for the convoy strip,
			# which draws the OTHER ships — so one name here means two in the
			# fight, and testing for two meant this line never printed through a
			# whole run of two ships killing the same enemy together.
			var crew := Net.fight_crew_names(cb.shared_at)
			if crew.size() > 0:
				said = true
				print("[bot] in this one alongside %s." % ", ".join(crew))
		# Waiting on the barrier is not a decision, so it is not offered as one.
		if cb.waiting:
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
					# Policy finishes the turn. The escape hatch the shot clock
					# lands on, and a move a brain can also choose on purpose.
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
		# And wait to be let back in, WHICH IS THE BARRIER. On a shared fight
		# `end_turn` returns immediately with `waiting` set and the host decides
		# when the next turn opens. A loop that does not wait here is a loop
		# that plays its whole deck into a fight nobody else has moved in.
		if not await _until(func() -> bool: return not cb.waiting or cb.finished, 90.0):
			print("[bot] the fight stopped moving. Standing down from it.")
			return
	if cb.finished:
		print("[bot] fight over: %s — %s" % [cb.result, cb.summary])


# --- the mailbox ----------------------------------------------------------

## Offer the board, wait for an answer, and give up on time.
##
## Files rather than a socket, and that is a considered choice. Godot has no
## HTTP server in it, so a socket here means hand-rolling one and a protocol to
## go with it, to talk to a process on the same machine. Two files in a
## directory need none of that and they have a property a socket does not:
## ANYTHING THAT CAN WRITE A FILE CAN PLAY. A shell one-liner, an MCP server, a
## person with a text editor and a slow hand — same interface, no client
## library, and the whole conversation is on disk afterwards to read back.
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


## The answer, if there is one for THIS board. A move quoting an older seq is
## dropped and the file removed — it was written about a hand that has since
## been played.
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
		# A bare string is allowed. Writing `echo end_turn > move.json` is the
		# fastest way to play one turn by hand and there is no reason to refuse
		# it — the seq check is a safety rail, not a toll booth.
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
