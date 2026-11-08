extends Node

## Covers starting and leaving a shared fight through the game's own doors (Nov 5 review).
## Why: docs/why/MidJoinTest.md#mid-join-test

const PORT_HOSTING := DirectTransport.DEFAULT_PORT + 29
const PORT_GUEST := DirectTransport.DEFAULT_PORT + 31

var _tree: SceneTree
var _fails := 0
var _said: PackedStringArray = PackedStringArray()
var _systems: Array[int] = []
var _branch: Node = null
var _killed := false
var _kill_at := -1
var _host: NetSession = null
var _errs := ErrCount.new()


## Errors, not warnings: a fight left listening on the signal bus ran a turn
## with no hull, which is a script error and nothing else shows it.
class ErrCount extends Logger:
	var n := 0
	## Of those, the game's own scripts' (`res://`): an RPC to a partner that is
	## a roster row only is the engine's error, and expected on the host.
	var scripts := 0
	var first: Array[String] = []
	var lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		lock.lock()
		n += 1
		if file.begins_with("res://"):
			scripts += 1
		if first.size() < 6:
			first.append("%s  (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
		lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	Sig.log_line.connect(func(t: String, _k: StringName) -> void: _said.append(t))
	OS.add_logger(_errs)
	await _host_side()
	await _guest_side()
	_finish()


# --- on the host --------------------------------------------------------------

func _host_side() -> void:
	print("\n=== on the host: a partner's fight here that this ship's check missed ===")
	_new_run()
	var at := _systems[0]
	await _go(at)
	var t := DirectTransport.new()
	t.port = PORT_HOSTING
	t.advertise = "127.0.0.1"
	if not _ok("(host) the game's session hosts a party", Net.host_party("Kevin", &"korvan", t) != ""):
		return
	# VELA: a roster row only, nobody on the wire (CoreWinTest's way); her ask
	# for a Vex Marauder landed first
	Net.roster[777] = Net._slot(777, "Vela", &"korvan", 1)
	var y := _plan(&"marauder", [])
	Net._open_or_join(at, y.foe_ids(), y.foe_hp(), y.foe_brace(), y.foe_hp_now(), y.grown, 777)
	_said.clear()
	Router.forced_race = true
	Router.start_combat(DB.enemies[&"cutter"], [DB.enemies[&"hulk"]], true, true)
	await _frames(3)
	var cb: Combat = Router.combat
	var f := Net.fight_at(at)
	if _ok("(host) the fight started, and it is the party's", cb != null and cb.is_shared() and f != null):
		_takes(cb, f, "(host)", PackedStringArray(["marauder"]))
		_ok("(host) the fight its SAVE & EXIT restarts is VELA's (%s), joined as a contact (clears %s)" % [
			str(Router.current_fight.get("ids", [])), str(Router.current_fight.get("clears", "?"))],
			Router.current_fight.get("ids", []) == ["marauder"] and Router.current_fight.get("clears", true) == false
			and cb.clears_node == false)
		_said_once("(host)", "VELA got here first. You join their fight.")
		_ok("(host) and no second line about fighting alongside her",
			not Array(_said).any(func(s: String) -> bool: return s.begins_with("Fighting alongside")))
	if cb != null:
		cb.release()
	Router.combat = null
	await _host_save_exit_closes_the_barrier()
	Net.leave_party()
	await _frames(2)


## A host's leave closes the barrier at once, so `abandon` lets go of the signal bus first.
## Why: docs/why/MidJoinTest.md#host-save-and-exit
func _host_save_exit_closes_the_barrier() -> void:
	print("\n--- (host) SAVE & EXIT on a turn VELA has ended")
	var at := _systems[1]
	await _go(at)
	SaveGame.save()
	Router.start_combat(DB.enemies[&"cutter"], [], false, true)
	await _frames(3)
	var cb: Combat = Router.combat
	if not _ok("(host-exit) the host's own fight is open, and shared",
			cb != null and cb.is_shared() and Net.fight_at(at) != null):
		return
	var v := _plan(&"cutter", [])
	Net._open_or_join(at, v.foe_ids(), v.foe_hp(), v.foe_brace(), v.foe_hp_now(), v.grown, 777)
	Net._apply_end_turn(at, 777)
	await _frames(2)
	_ok("(host-exit) VELA is in it and has ended her turn",
		Net.fight_at(at).crew.has(777) and Net.fight_at(at).ended.has(777) and Net.fight_at(at).turn == 1)
	var errs := _errs.scripts
	await _menu(&"save")
	await _frames(5)
	var f := Net.fight_at(at)
	_ok("(host-exit) the leave closes the barrier: the host is out, the turn moves (crew %s, turn %d)" % [
		str(f.crew), f.turn], not f.crew.has(Net.local_id()) and f.turn == 2)
	_ok("(host-exit) and the fight left was not listening when it did (%d script errors%s)" % [
		_errs.scripts - errs, (": " + " | ".join(_errs.first)) if _errs.scripts > errs else ""],
		_errs.scripts == errs)


# --- as a guest ---------------------------------------------------------------

func _guest_side() -> void:
	print("\n=== as a guest of a host in this process ===")
	_new_run()
	_host = _host_peer()
	var t := DirectTransport.new()
	t.port = PORT_GUEST
	t.advertise = "127.0.0.1"
	var code := _host.host_party("Vela", &"redline", t)
	Net.join_party(code, "Kevin", &"korvan", DirectTransport.new())
	var seated := await _until(func() -> bool:
		return Net.state == NetSession.State.IN_PARTY and _host.party_size() == 2, 6.0)
	if not _ok("(guest) the game's session joins a host in this process", seated):
		await _guest_done()
		return
	await _race_unstaged()
	await _save_exit_and_continue()
	await _join_on_the_kill()
	await _ambush_at_their_fight()
	await _slow_answer()
	await _left_while_asking()
	await _continue_after_the_kill()
	await _pressed_while_asking()
	await _join_answered_with_another()
	await _guest_done()


## THE RACE, UNSTAGED: this ship's check finds nothing, it asks for its own
## two-hull pack, and in that same frame the host opens a one-hull fight here.
func _race_unstaged() -> void:
	print("\n--- the race: this ship asks for two hulls, the host opens one in the same frame")
	var at := _systems[1]
	await _go(at)
	_said.clear()
	var kills := Run.kills
	Router.start_combat(DB.enemies[&"lancer"], [DB.enemies[&"hulk"]], false, true)
	var x := _plan(&"cutter", [])
	await _host.open_fight(at, x.foe_ids(), x.foe_hp(), x.foe_brace(), x.foe_hp_now(), x.grown)
	var shared := await _until(func() -> bool: return Router.combat != null and Router.combat.is_shared(), 5.0)
	var cb: Combat = Router.combat
	if not _ok("(race) the answer came and the fight is the party's", shared):
		return
	_takes(cb, _host.fight_at(at), "(race)", PackedStringArray(["cutter"]))
	_ok("(race) SAVE & EXIT would restart the host's fight (%s)" % str(Router.current_fight.get("ids", [])),
		Router.current_fight.get("ids", []) == ["cutter"])
	_said_once("(race)", "VELA got here first. You join their fight.")
	# The kill, by the host. A hull that lived only on this machine kept
	# `alive()` from ever emptying, so the win never came.
	for i in _host.fight_at(at).foes.size():
		_host.hurt_foe(at, i, 9999, 1)
	var won := await _until(func() -> bool: return cb.finished, 5.0)
	_ok("(race) the host's kill ends the fight here: %s, paid as one of %d" % [cb.result, cb.wreck_hands],
		won and cb.result == &"victory" and cb.wreck_hands == 2 and Run.kills == kills + 1)
	if not cb.finished:
		# stuck, as it was: let go of it so the cases below start clean
		Net.leave_fight(at)
		cb.release()
		Router.combat = null
	await _settle()


## SAVE & EXIT while waiting on the barrier, then CONTINUE; then ABANDON mid-turn.
func _save_exit_and_continue() -> void:
	print("\n--- SAVE & EXIT while waiting, CONTINUE, then ABANDON")
	var at := _systems[2]
	await _go(at)
	SaveGame.save()
	var me := Net.local_id()
	var z := _plan(&"cutter", [])
	await _host.open_fight(at, z.foe_ids(), z.foe_hp(), z.foe_brace(), z.foe_hp_now(), z.grown)
	if not _ok("(save) JOIN FIGHT is offered at the host's fight", await _until(func() -> bool:
			return Router.can_join_fight(), 4.0)):
		return
	Router.join_fight()
	var joined := await _until(func() -> bool:
		return Router.combat != null and Router.combat.is_shared() and _host.fight_at(at).crew.has(me), 5.0)
	if not _ok("(save) joined", joined):
		return
	var cb: Combat = Router.combat
	cb.end_turn()
	await _until(func() -> bool: return _host.fight_at(at).ended.has(me), 3.0)
	_ok("(save) this ship ended its turn and is waiting on VELA", cb.waiting)
	var errs := _errs.n
	await _menu(&"save")
	await _frames(3)
	_ok("(save) SAVE & EXIT leaves the fight: the host's crew drops this ship", await _until(func() -> bool:
		return not _host.fight_at(at).crew.has(me), 3.0))
	_host.report_end_turn(at)
	_ok("(save) VELA's END TURN moves the turn", await _until(func() -> bool:
		return _host.fight_at(at).turn == 2, 3.0))
	await _frames(10)
	_ok("(save) and nothing here breaks when it does (%d errors%s)" % [_errs.n - errs,
		(": " + " | ".join(_errs.first)) if _errs.n > errs else ""], _errs.n == errs)

	# CONTINUE: the fight starts again from the save, and it is a JOIN
	var before := _host.fight_at(at).foes[0].max_hp
	var share := maxi(1, int(round(_host.fight_at(at).foes[0].base * SharedFight.CREW_SHARE)))
	Router.continue_run()
	var back := await _until(func() -> bool:
		return Router.combat != null and Router.combat.is_shared(), 5.0)
	_ok("(save) CONTINUE comes back into the party's fight", back)
	await _until(func() -> bool: return _host.fight_at(at).foes[0].max_hp != before, 2.0)
	_ok("(save) as a join: the enemy grows once for it (%d -> %d, want %d)" % [before,
		_host.fight_at(at).foes[0].max_hp, before + share], _host.fight_at(at).foes[0].max_hp == before + share)
	_ok("(save) seated once, on the party's turn (%d, the fight's %d)" % [
		Router.combat.turn if Router.combat != null else -1, _host.fight_at(at).turn],
		Array(_host.fight_at(at).crew).count(me) == 1 and Router.combat != null
		and Router.combat.turn == _host.fight_at(at).turn)

	# ABANDON, mid-turn (not waiting): VELA must not be left on "WAIT KEVIN"
	errs = _errs.n
	var turn := _host.fight_at(at).turn
	await _menu(&"abandon")
	await _frames(3)
	_ok("(abandon) ABANDON leaves the fight: the host's crew drops this ship", await _until(func() -> bool:
		return not _host.fight_at(at).crew.has(me), 3.0))
	_host.report_end_turn(at)
	_ok("(abandon) VELA's END TURN moves the turn, with nobody to wait on", await _until(func() -> bool:
		return _host.fight_at(at).turn == turn + 1, 3.0))
	await _frames(10)
	_ok("(abandon) and nothing here breaks (%d errors%s)" % [_errs.n - errs,
		(": " + " | ".join(_errs.first)) if _errs.n > errs else ""], _errs.n == errs)
	# a ship again, for what follows
	_new_run()
	await _frames(2)


## JOIN, answered on the kill: the host seats this ship and the last hull dies
## in the same host frame, so the answer comes back already over.
func _join_on_the_kill() -> void:
	print("\n--- a join the host answers in the same frame as the kill")
	var at := _systems[3]
	await _go(at)
	var me := Net.local_id()
	var w := _plan(&"cutter", [])
	await _host.open_fight(at, w.foe_ids(), w.foe_hp(), w.foe_brace(), w.foe_hp_now(), w.grown)
	if not _ok("(kill) JOIN FIGHT is offered", await _until(func() -> bool: return Router.can_join_fight(), 4.0)):
		return
	_killed = false
	_kill_at = at
	Sig.party_fight_changed.connect(_kill_on_seat)
	var kills := Run.kills
	Router.join_fight()
	# (set before the ask goes out, so it is here now)
	var cb: Combat = Router.combat
	var ended := await _until(func() -> bool: return cb != null and cb.finished, 5.0)
	Sig.party_fight_changed.disconnect(_kill_on_seat)
	_ok("(kill) the host seated this ship and killed the last hull in one frame", _killed)
	_ok("(kill) the answer, already over, goes to the win: %s, paid as one of %d" % [
		cb.result if cb != null else &"none", cb.wreck_hands if cb != null else 0],
		ended and cb.result == &"victory" and cb.wreck_hands == 2 and Run.kills == kills + 1)
	if cb != null and not cb.finished:
		cb.release()
		Router.combat = null
	await _settle()


## On the host's push that seats this ship, the kill, in the same frame.
func _kill_on_seat(at: int) -> void:
	if _killed or at != _kill_at or _host == null:
		return
	var f := _host.fight_at(at)
	if f == null or f.over or not f.crew.has(Net.local_id()):
		return
	_killed = true
	for i in f.foes.size():
		_host.hurt_foe(at, i, 9999, 1)


## An arrival ambush at a system where VELA is fighting: her fight, said so.
func _ambush_at_their_fight() -> void:
	print("\n--- an arrival ambush where a partner is already fighting")
	var at := _systems[4]
	await _go(at)
	var v := _plan(&"cutter", [])
	await _host.open_fight(at, v.foe_ids(), v.foe_hp(), v.foe_brace(), v.foe_hp_now(), v.grown)
	await _until(func() -> bool: return not Router.party_fight_here().is_empty(), 4.0)
	Run.map[at].ambush_rolled = true
	Run.map[at].ambush_pending = true
	_said.clear()
	Router.resolve_current_node()
	var joined := await _until(func() -> bool:
		return Router.combat != null and Router.combat.is_shared(), 5.0)
	_ok("(ambush) the ambush joins VELA's fight", joined and Router.combat.foe_ids() == PackedStringArray(["cutter"]))
	_said_once("(ambush)", "VELA is already fighting here. You join their fight.")
	_ok("(ambush) not \"Contact.\", and no second line about fighting alongside her",
		not Array(_said).any(func(s: String) -> bool:
			return s.begins_with("Contact.") or s.begins_with("Fighting alongside")))
	for i in _host.fight_at(at).foes.size():
		_host.hurt_foe(at, i, 9999, 1)
	await _until(func() -> bool: return Router.combat == null or Router.combat.finished, 5.0)
	await _settle()


## A HOST SLOW TO ANSWER: still asking past three seconds, not fighting alone.
func _slow_answer() -> void:
	print("\n--- a host slow to answer")
	var at := _systems[5]
	await _go(at)
	_host.hold_asks = true
	_said.clear()
	Router.start_combat(DB.enemies[&"cutter"], [], false, true)
	await _until(func() -> bool: return false, NetSession.TAKE_TIMEOUT + 0.6)
	var cb: Combat = Router.combat
	_ok("(slow) past %.0f s the ship is still asking, not fighting a private copy (shared %s, hand %d)" % [
		NetSession.TAKE_TIMEOUT, str(cb != null and cb.is_shared()), cb.hand.size() if cb != null else -1],
		cb != null and not cb.is_shared() and cb.hand.is_empty() and not _host.fight_open_at(at))
	_said_once("(slow)", "Waiting for the host.")
	_host.release_asks()
	_host.hold_asks = false
	var took := await _until(func() -> bool: return cb != null and cb.is_shared(), 5.0)
	_ok("(slow) the late answer is taken: one fight, this ship in the host's crew",
		took and _host.fight_at(at) != null and _host.fight_at(at).crew.has(Net.local_id()))
	if cb != null:
		Net.leave_fight(at)
		cb.release()
	Router.combat = null
	await _frames(2)


## SAVE & EXIT while the host is still answering: the answer, when it comes,
## seats a ship that is not there any more, so it is left again.
func _left_while_asking() -> void:
	print("
--- SAVE & EXIT while the host is still answering")
	var at := _systems[6]
	await _go(at)
	SaveGame.save()
	var me := Net.local_id()
	_host.hold_asks = true
	Router.start_combat(DB.enemies[&"cutter"], [], false, true)
	await _frames(5)
	var errs := _errs.n
	await _menu(&"save")
	await _frames(3)
	_host.release_asks()
	_host.hold_asks = false
	var answered := await _until(func() -> bool: return _host.fight_at(at) != null, 3.0)
	_ok("(asking) the answer that comes after SAVE & EXIT is left again: the host's crew lets the ship go",
		answered and await _until(func() -> bool: return not _host.fight_at(at).crew.has(me), 3.0))
	await _frames(5)
	_ok("(asking) and nothing here breaks (%d errors%s)" % [_errs.n - errs,
		(": " + " | ".join(_errs.first)) if _errs.n > errs else ""], _errs.n == errs)


## CONTINUE after the party's kill restarted the saved fight and spawned a fresh enemy.
## Why: docs/why/MidJoinTest.md#continue-after-kill
func _continue_after_the_kill() -> void:
	print("\n--- CONTINUE after the party killed the fight this ship saved out of")
	_new_run()
	await _frames(2)
	var at := _systems[7]
	await _go(at)
	SaveGame.save()
	var me := Net.local_id()
	var z := _plan(&"cutter", [])
	await _host.open_fight(at, z.foe_ids(), z.foe_hp(), z.foe_brace(), z.foe_hp_now(), z.grown)
	if not _ok("(after-kill) JOIN FIGHT is offered", await _until(func() -> bool: return Router.can_join_fight(), 4.0)):
		return
	Router.join_fight()
	if not _ok("(after-kill) joined", await _until(func() -> bool:
			return Router.combat != null and Router.combat.is_shared() and _host.fight_at(at).crew.has(me), 5.0)):
		return
	await _menu(&"save")
	await _until(func() -> bool: return not _host.fight_at(at).crew.has(me), 3.0)
	var killed := _host.fight_at(at)
	for i in killed.foes.size():
		_host.hurt_foe(at, i, 9999, 1)
	_ok("(after-kill) VELA kills it while this ship is away (paid %d)" % killed.paid, await _until(func() -> bool:
		return Net.fight_at(at) != null and Net.fight_at(at).over, 3.0) and killed.over and killed.paid == 1)
	_said.clear()
	Router.continue_run()
	await _frames(20)
	_ok("(after-kill) CONTINUE opens no fight here: none on screen, the host's still the one she won (%s)" % [
		"none" if Router.combat == null else ("shared" if Router.combat.is_shared() else "own")],
		not Router.in_combat() and _host.fight_at(at) == killed and killed.over)
	_said_once("(after-kill)", "The fight ended while you were away.")
	if Router.combat != null:
		Router.drop_combat()

	# A FIGHT EVERYONE SIMPLY LEFT is not finished: CONTINUE starts it again,
	# as SAVE & EXIT always has.
	at = _systems[8]
	await _go(at)
	SaveGame.save()
	Router.start_combat(DB.enemies[&"cutter"], [], false, true)
	if not _ok("(left-alone) this ship opens a fight alone", await _until(func() -> bool:
			return Router.combat != null and Router.combat.is_shared(), 5.0)):
		return
	await _menu(&"save")
	var gone := await _until(func() -> bool:
		return _host.fight_at(at) != null and _host.fight_at(at).over, 3.0)
	_ok("(left-alone) SAVE & EXIT leaves it empty and unpaid (paid %d)" % _host.fight_at(at).paid,
		gone and _host.fight_at(at).paid == 0)
	Router.continue_run()
	_ok("(left-alone) and CONTINUE starts it again, the party's", await _until(func() -> bool:
		return (Router.combat != null and Router.combat.is_shared() and _host.fight_open_at(at)
			and _host.fight_at(at).crew.has(me)), 5.0))
	if Router.combat != null:
		Router.drop_combat()
	await _frames(3)


## While the host holds the ask, END TURN ran a private turn; FLEE and HAIL were open.
## Why: docs/why/MidJoinTest.md#host-holds-the-ask
func _pressed_while_asking() -> void:
	print("\n--- END TURN, FLEE and HAIL while the host holds the ask")
	_new_run()
	await _frames(2)
	var at := _systems[9]
	await _go(at)
	var me := Net.local_id()
	_host.hold_asks = true
	Router.start_combat(DB.enemies[&"cutter"], [], false, true)
	await _frames(5)
	var cb: Combat = Router.combat
	if not _ok("(press) asking", cb != null and not cb.is_shared()):
		_host.release_asks()
		_host.hold_asks = false
		return
	var hp := Run.hp
	cb.end_turn()
	await _frames(3)
	_ok("(press) END TURN does nothing yet: turn %d, hand %d, hull %d -> %d" % [cb.turn, cb.hand.size(), hp, Run.hp],
		cb.turn == 1 and cb.hand.is_empty() and Run.hp == hp and not cb.waiting)
	_ok("(press) FLEE and HAIL are shut (flee %s, hail %s)" % [str(cb.can_flee()), str(cb.can_hail())],
		not cb.can_flee() and not cb.can_hail())
	var card: CardData = cb.deck[0] if not cb.deck.is_empty() else null
	_ok("(press) and no card can be played", card != null and not cb.can_play(card))
	_host.release_asks()
	_host.hold_asks = false
	_ok("(press) the answer begins it: the party's, turn 1, a hand dealt", await _until(func() -> bool:
		return cb.is_shared() and cb.turn == 1 and not cb.hand.is_empty(), 5.0))
	Router.drop_combat()
	await _frames(3)

	# ENDED UNBEGUN: the late answer must not attach it
	at = _systems[10]
	await _go(at)
	_host.hold_asks = true
	Router.start_combat(DB.enemies[&"cutter"], [], false, true)
	await _frames(5)
	cb = Router.combat
	if cb == null:
		_fail("(press) no fight to end while asking")
		_host.release_asks()
		_host.hold_asks = false
		return
	cb._finish(&"fled", "Gone.")
	_host.release_asks()
	_host.hold_asks = false
	await _until(func() -> bool: return _host.fight_at(at) != null, 3.0)
	var let_go := await _until(func() -> bool:
		return _host.fight_at(at) != null and not _host.fight_at(at).crew.has(me), 3.0)
	_ok("(press) a fight that ended while asking is never attached: the seat is left (shared %s)" % str(cb.is_shared()),
		let_go and not cb.is_shared())
	await _settle()


## A join answered with a newer fight must write down that one for SAVE & EXIT.
## Why: docs/why/MidJoinTest.md#join-answered-otherwise
func _join_answered_with_another() -> void:
	print("\n--- a JOIN the host answers with a newer fight here")
	var at := _systems[11]
	await _go(at)
	var x := _plan(&"cutter", [])
	await _host.open_fight(at, x.foe_ids(), x.foe_hp(), x.foe_brace(), x.foe_hp_now(), x.grown)
	if not _ok("(newer) JOIN FIGHT is offered", await _until(func() -> bool: return Router.can_join_fight(), 4.0)):
		return
	_host.hold_asks = true
	Router.join_fight()
	await _frames(5)
	for i in _host.fight_at(at).foes.size():
		_host.hurt_foe(at, i, 9999, 1)
	var y := _plan(&"lancer", [&"hulk"])
	await _host.open_fight(at, y.foe_ids(), y.foe_hp(), y.foe_brace(), y.foe_hp_now(), y.grown)
	_host.release_asks()
	_host.hold_asks = false
	var cb: Combat = Router.combat
	if not _ok("(newer) seated in the newer fight", await _until(func() -> bool:
			return cb != null and cb.is_shared(), 5.0)):
		return
	var want := PackedStringArray(["lancer", "hulk"])
	_ok("(newer) the enemy is the newer fight's (%s)" % str(cb.foe_ids()), cb.foe_ids() == want)
	_ok("(newer) and SAVE & EXIT would restart it (%s)" % str(Router.current_fight.get("ids", [])),
		Router.current_fight.get("ids", []) == ["lancer", "hulk"])
	for i in _host.fight_at(at).foes.size():
		_host.hurt_foe(at, i, 9999, 1)
	await _until(func() -> bool: return cb.finished, 5.0)
	await _settle()


func _guest_done() -> void:
	Net.leave_party()
	if _host != null:
		_host.leave_party()
	if _branch != null:
		_tree.root.remove_child(_branch)
		_branch.queue_free()
		_branch = null
	await _frames(2)


# --- checks -------------------------------------------------------------------

## The fight on this machine is the party's: hull for hull, with the host's
## intents under each name.
func _takes(cb: Combat, f: SharedFight, tag: String, want: PackedStringArray) -> void:
	var got := PackedStringArray()
	for e in cb.enemies:
		got.append(String(e.template.id))
	_ok("%s the enemy here is the party's, hull for hull (%s, want %s)" % [tag, str(got), str(want)],
		got == want and cb.foe_ids() == want and f.foe_ids == want)
	var names := PackedStringArray()
	var host_names := PackedStringArray()
	for i in f.foes.size():
		host_names.append(_picked_name(f, i))
		names.append(cb.enemies[i].intent.name if i < cb.enemies.size() and cb.enemies[i].intent != null else "?")
	_ok("%s each hull shows the intent the host picked (%s, host %s)" % [tag, str(names), str(host_names)],
		names == host_names)


func _said_once(tag: String, line: String) -> void:
	_ok("%s the log says \"%s\" once" % [tag, line], Array(_said).count(line) == 1)


func _picked_name(f: SharedFight, i: int) -> String:
	var e := f.foes[i]
	if e.kind == SharedFight.Pick.ESCAPE:
		return Combat.escape_intent().name
	var tpl: EnemyTemplate = DB.enemies.get(StringName(f.foe_ids[i]))
	if tpl == null:
		return "?"
	var list: Array[IntentData] = tpl.pool if e.kind == SharedFight.Pick.POOL else tpl.loop
	return list[e.pick].name if e.pick >= 0 and e.pick < list.size() else "?"


# --- plumbing -----------------------------------------------------------------

## A fresh run on a fixed galaxy, and the plain systems to fight at.
func _new_run() -> void:
	Rng.forced = 4242
	print("  [seed] 4242")
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_systems.clear()
	for n: MapGen.MapNode in Run.map:
		if n.index > 0 and n.type == MapGen.NodeType.SYSTEM and not n.cleared \
				and n.region != MapGen.Region.FAUNA:
			_systems.append(n.index)


## Parked at system `at`, on LOCAL.
func _go(at: int) -> void:
	Run.at = at
	Run.map[at].visited = true
	SectorScreen._approached_at = at
	Router.show_local()
	await _frames(3)


## Numbers for a fight, as a ship plans it here.
func _plan(lead: StringName, extras: Array) -> Combat:
	var more: Array = []
	for id in extras:
		more.append(DB.enemies[id])
	var cb := Combat.new()
	cb.plan(DB.enemies[lead], maxi(1, Run.node_at().danger), more)
	return cb


## The host in this process, on its own branch with its own multiplayer API.
func _host_peer() -> NetSession:
	_branch = Node.new()
	_branch.name = "midjoin_host"
	_tree.root.add_child(_branch)
	var api := SceneMultiplayer.new()
	api.root_path = _branch.get_path()
	_tree.set_multiplayer(api, _branch.get_path())
	var s := NetSession.new()
	s.name = "Net"
	s.handshake_timeout = 4.0
	_branch.add_child(s)
	return s


## The escape menu's SAVE & EXIT or ABANDON, as a player reaches them.
func _menu(which: StringName) -> void:
	var main := get_parent()
	if main == null or not main.has_method(&"toggle_menu"):
		_fail("no Main to open the escape menu on")
		return
	main.call(&"toggle_menu", false)
	await _frames(1)
	var pm := _find(_tree.root, func(n: Node) -> bool: return n is PauseMenu) as PauseMenu
	if pm == null:
		_fail("the escape menu did not open")
		return
	if which == &"save":
		pm.save_and_quit_requested.emit()
	else:
		pm.quit_requested.emit()


## Whatever the fight's end handed over to, played out.
func _settle() -> void:
	await _frames(6)
	if Router.combat != null and Router.combat.finished:
		Router.after_combat(Router.combat)
		await _frames(3)


func _find(root: Node, matches: Callable) -> Node:
	if root == null:
		return null
	if matches.call(root):
		return root
	for c in root.get_children():
		var f := _find(c, matches)
		if f != null:
			return f
	return null


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _until(condition: Callable, timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await _tree.process_frame
	return condition.call()


func _fail(why: String) -> void:
	print("  FAIL %s" % why)
	_fails += 1


func _finish() -> void:
	print("midjointest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
