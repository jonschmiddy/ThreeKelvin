extends Node

## THE EFFECTS' MOMENTS ARE HEARD, ONCE, ON THE FRAME THE PICTURE ACTS (the free
## half of the sound plan, Oct 17: `Audio.FX`), headless:
##   godot --headless --fixed-fps 60 --path . -- sheet=SoundMomentTest
## Audio makes no sound headless, but while it tapes it runs every decision --
## rate limits, suppression, the pick, the caps -- and writes down what would
## have played (`Audio.tape`, `Audio.fx_heard`). Through the real screens with
## the animation on, each picture's own `moment` written down as it is emitted:
##   * the table: every row's files exist, and a row can be set back, silenced
##     or given a file of its own;
##   * a hulk's fight: the band rising (hold_lift), its plates going on and
##     yours (module_install on the wave's start, and no shield_block from the
##     card or the clamp), plates shed (jettison), a hit partly taken
##     (shield_block -8 under the impact), its shield up and a hit taken whole
##     (shield_block as before), three vents opened at once (one hiss) and ten
##     seconds of their sputters (never closer than 0.4 s);
##   * a cutter dying in G (its jets and sputters, the vent's);
##   * the calf dying in N, O and P (fauna_falls on the first beat, -4 dB);
##   * the Hellbender's furnace (in on the heat, out on the burst) and its pops,
##     and the Custodian's C1c pops and split;
##   * your ship lost: power_off as the handoff starts, the score ducked through
##     the gap, and no page click on the swap into RUN ENDED;
##   * the ladder: the chrome sliding (menu_open / menu_close as the column
##     first moves) and the side bar's decode (a text_blip as each line starts,
##     never more than two in the air).
## Written to run on main too (it reaches the new parts by name): there it runs
## in a window, where Audio is on and tapes what it plays, and fails.

var _tree: SceneTree
var _fails := 0
## every moment a picture emitted: [source, kind, frame, game s]
var _moments: Array = []
## Sig.hit_landed: [amount, to_player, absorbed, frame]
var _landed: Array = []
## screens swapped in: [frame, class name]
var _swaps: Array = []
## (main's tape has no frame on its rows: stamped here as they appear)
var _stamped := 0
var _stamp: Array = []
## the sampler, run at the start of each frame on the frame before
var _sampler: Callable = Callable()

var _sfx: Dictionary = {}


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _fr() -> int:
	return Engine.get_process_frames()


# ---------------------------------------------------------------- the tape

## The table, by name (none on main).
func _fx_table() -> Dictionary:
	return (Audio.get_script() as Script).get_script_constant_map().get("FX", {})


func _heard_rows() -> Array:
	var h: Variant = Audio.get("fx_heard")
	return h if h is Array else []


## The tape's rows from `from` on: [file, asked, db, frame, game s].
func _tape(from: int = 0) -> Array:
	var out: Array = []
	for i in range(from, Audio.tape.size()):
		var r: Array = Audio.tape[i]
		var f: int = int(r[5]) if r.size() > 5 else int(_stamp[i]) if i < _stamp.size() else -1
		var asked := StringName(r[6]) if r.size() > 6 else _asked_of(StringName(r[0]))
		out.append([StringName(r[0]), asked, float(r[2]), f, float(r[4]) if r.size() > 4 else 0.0])
	return out


func _asked_of(pick: StringName) -> StringName:
	var s := String(pick)
	var i := s.rfind("_")
	if i > 0 and s.substr(i + 1).is_valid_int():
		return StringName(s.substr(0, i))
	return pick


## Rows of the table heard since `from` (an index into fx_heard).
func _heard(row: StringName, from: int = 0) -> Array:
	var out: Array = []
	var h := _heard_rows()
	for i in range(from, h.size()):
		if StringName(h[i][0]) == row:
			out.append(h[i])
	return out


func _taped_at(asked: StringName, frame: int, from: int = 0) -> Array:
	return _tape(from).filter(func(r: Array) -> bool: return r[1] == asked and int(r[3]) == frame)


func _moments_of(src: StringName, kinds: Array, from: int = 0) -> Array:
	var out: Array = []
	for i in range(from, _moments.size()):
		var m: Array = _moments[i]
		if StringName(m[0]) == src and StringName(m[1]) in kinds:
			out.append(m)
	return out


func _on_frame() -> void:
	# the tape's new rows belong to the frame just finished
	while _stamp.size() < Audio.tape.size():
		_stamp.append(_fr() - 1)
	if _sampler.is_valid():
		_sampler.call(_fr() - 1)


func _on_node_added(n: Node) -> void:
	if n is HitLayers:
		var src := &"you" if (n as HitLayers).follow != null else &"enemy"
		(n as HitLayers).moment.connect(func(k: StringName, _s: float, _l: float) -> void:
			_moments.append([src, k, _fr(), GameClock.now()]))
	elif n is ShipBreakup:
		var b := n as ShipBreakup
		b.moment.connect(func(k: StringName, _s: float, _l: float) -> void:
			_moments.append([&"death", k, _fr(), GameClock.now()]))
		b.finished.connect(func() -> void:
			_moments.append([&"death", &"finished", _fr(), GameClock.now()]))
	elif n is DeathHandoff:
		_moments.append([&"handoff", &"start", _fr(), GameClock.now()])


# ---------------------------------------------------------------- the run

func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	_tree.process_frame.connect(_on_frame)
	_tree.node_added.connect(_on_node_added)
	Sig.hit_landed.connect(func(a: int, tp: bool, _w: int, ab: int) -> void:
		_landed.append([a, tp, ab, _fr()]))
	Sig.screen_changed.connect(func() -> void:
		_swaps.append([_fr(), Router.current.get_script().get_global_name() if Router.current != null else &""]))
	_sfx = _fx_table()
	Audio.taping = true
	Router.animate_in_harness = true
	print("  [mode] %s, table %s" % ["headless" if DisplayServer.get_name() == "headless" else "window",
		"%d rows" % _sfx.size() if not _sfx.is_empty() else "absent"])

	_table()
	await _hulk()
	await _vent_death()
	for st in [ShipBreakup.Style.GLOWOUT, ShipBreakup.Style.BLOOM, ShipBreakup.Style.PART]:
		await _creature(st)
	await _hellbender()
	await _loss()
	await _ladder()
	# last: a won core leaves the run's last loot open
	await _custodian()

	Router.animate_in_harness = false
	Audio.taping = false
	print("soundmomenttest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)


# ---------------------------------------------------------------- the table

func _table() -> void:
	print("-- the table")
	if not _ok("the table exists (Audio.FX)", not _sfx.is_empty()):
		return
	var missing: Array = []
	var no_pick: Array = []
	for row: StringName in _sfx:
		var r: Dictionary = _sfx[row]
		if (r.get("pick", {}) as Dictionary).is_empty():
			no_pick.append(row)
		for which in ["pick", "before"]:
			var t: Dictionary = r.get(which, {})
			if t.has("file") and not ResourceLoader.exists(Audio.SFX_PATH % t.file):
				missing.append("%s.%s %s" % [row, which, t.file])
			if t.has("bed") and not ResourceLoader.exists(Audio.ROOM_WAV % t.bed):
				missing.append("%s.%s %s" % [row, which, t.bed])
	_ok("every row's files are on disk %s" % [missing], missing.is_empty())
	_ok("every row has a pick %s" % [no_pick], no_pick.is_empty())
	# switchable: off, back to before, a file of its own, and the pick again
	var h0 := _heard_rows().size()
	var t0 := Audio.tape.size()
	Audio.call(&"fx_choose", &"boss_split", "off")
	var off: bool = Audio.call(&"fx", &"boss_split", &"split")
	Audio.call(&"fx_choose", &"boss_split", "before")
	var before: bool = Audio.call(&"fx", &"boss_split", &"split")
	Audio.call(&"fx_choose", &"brace_on", "before")
	var b_pick: bool = Audio.call(&"fx", &"brace_on", &"bolt_on")
	var b_clamp: bool = Audio.call(&"fx", &"brace_on", &"clamp")
	Audio.call(&"fx_choose", &"boss_split", "jettison@-3")
	var own: bool = Audio.call(&"fx", &"boss_split", &"split")
	var own_rows := _tape(t0).filter(func(r: Array) -> bool: return r[1] == &"jettison")
	(Audio.get("fx_choice") as Dictionary).clear()
	(Audio.get("_fx_last") as Dictionary).clear()
	var back: bool = Audio.call(&"fx", &"boss_split", &"split")
	(Audio.get("_fx_last") as Dictionary).clear()
	_ok("off is silent", not off)
	_ok("before is what played before (nothing, for C1c's split)", not before)
	_ok("brace_on before: shield_block on the clamp, not on bolt_on", not b_pick and b_clamp)
	_ok("a file of its own plays at its level (%s)" % [own_rows], own and own_rows.size() == 1
		and is_equal_approx(float(own_rows[0][2]), -3.0))
	_ok("and the pick again (heard twice: its own file, then the pick)", back and _heard(&"boss_split", h0).size() == 2)


# ---------------------------------------------------------------- a fight

func _start(seed: int, id: StringName, pick_node: Callable = Callable()) -> SectorScreen:
	Rng.forced = seed
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(n):
			if not pick_node.is_valid() or pick_node.call(n):
				idx = n.index
				break
	if idx < 0:
		return null
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	Router.show_local()
	await _frames(4)
	Router.start_combat(DB.enemies[id], [], false, false)
	for i in 900:
		await _tree.process_frame
		var sc := Router.current as SectorScreen
		if Router.combat != null and sc != null and sc.fighting() and not sc._opening:
			await _frames(30)
			return sc
	return null


## A card played as a player plays it, put in the hand first.
func _play(d: Dictionary) -> void:
	var cb: Combat = Router.combat
	var c := DB._card(d)
	cb.hand[0] = c
	cb.energy = maxi(cb.energy, 3)
	cb.play(0, 0)


func _hulk() -> void:
	print("-- a hulk's fight: the band, plates, shields, hits, vents")
	var m0 := _moments.size()
	var h0 := _heard_rows().size()
	var t0 := Audio.tape.size()
	var band := {frame = -1, was = true, sc = null}
	# (the band's holder shows on the frame the rise starts)
	_sampler = func(f: int) -> void:
		var cur := Router.current as SectorScreen
		if cur == null:
			return
		if band.sc != cur:
			band.sc = cur
			band.was = true
		var hh: Control = cur.get("_hand_holder")
		if hh == null:
			return
		if hh.visible and not band.was and band.frame < 0 and Router.combat != null:
			band.frame = f
		band.was = hh.visible
	var sc := await _start(4242, &"hulk")
	_sampler = Callable()
	if not _ok("a hulk's fight opens", sc != null):
		return
	# THE BAND RISING
	var fb := _heard(&"fight_band", h0)
	_ok("the band's rise heard once (%d), on the frame it starts (%s vs %d)"
		% [fb.size(), fb.map(func(r: Array) -> int: return int(r[4])), band.frame],
		fb.size() == 1 and int(fb[0][4]) == band.frame)
	_ok("as hold_lift at -4 dB", _taped_at(&"hold_lift", band.frame, t0).size() == 1
		and is_equal_approx(float(_taped_at(&"hold_lift", band.frame, t0)[0][2]), -4.0))
	var cb: Combat = Router.combat
	var e: Combat.EnemyState = cb.enemies[0]
	e.hp = e.max_hp
	# ITS STARTING PLATES went on while it was held off screen (the entrance
	# waits for LOCAL's line): unseen, so unheard
	var first := _moments_of(&"enemy", [&"bolt_on"], m0)
	_ok("its starting plates, put on unseen (%d), are not heard (%d)" % [first.size(), _heard(&"brace_on", h0).size()],
		first.size() >= 1 and _heard(&"brace_on", h0).is_empty())
	# ITS PLATES GOING ON where you see them
	var m0b := _moments.size()
	var h0b := _heard_rows().size()
	var t0b := Audio.tape.size()
	e.brace += 4
	sc._fx_sync_enemy(0)
	await _frames(40)
	var bolts := _moments_of(&"enemy", [&"bolt_on"], m0b)
	var clamps := _moments_of(&"enemy", [&"clamp"], m0b)
	var on := _heard(&"brace_on", h0b)
	_ok("its plates go on (%d waves, %d clamps)" % [bolts.size(), clamps.size()], bolts.size() == 1 and clamps.size() == 1)
	var on_frames := on.map(func(r: Array) -> int: return int(r[4]))
	var bolt_frames := bolts.map(func(m: Array) -> int: return int(m[2]))
	_ok("heard once a wave, on the wave's first frame (%s vs %s)" % [on_frames, bolt_frames],
		on_frames == bolt_frames)
	var mi_ok := true
	for f: int in bolt_frames:
		var rows := _taped_at(&"module_install", f, t0b)
		if rows.size() != 1 or not is_equal_approx(float(rows[0][2]), 0.0):
			mi_ok = false
	_ok("as module_install at 0 dB", mi_ok and not bolt_frames.is_empty())
	var sb_clamp := 0
	for m: Array in clamps:
		sb_clamp += _taped_at(&"shield_block", int(m[2]), t0b).size()
	_ok("and no shield_block on the clamp (%d)" % sb_clamp, sb_clamp == 0 and not clamps.is_empty())

	# YOURS
	print("-- your plates")
	var m1 := _moments.size()
	var h1 := _heard_rows().size()
	var t1 := Audio.tape.size()
	_play(DB.SHARED[&"brace"])
	await _frames(60)
	var mine := _moments_of(&"you", [&"bolt_on"], m1)
	var yours := _heard(&"brace_on_yours", h1)
	_ok("Bolt On: your plates go on (%d) and are heard on that frame (%s vs %s)"
		% [mine.size(), yours.map(func(r: Array) -> int: return int(r[4])), mine.map(func(m: Array) -> int: return int(m[2]))],
		mine.size() == 1 and yours.size() == 1 and int(yours[0][4]) == int(mine[0][2]))
	_ok("as module_install", not mine.is_empty() and _taped_at(&"module_install", int(mine[0][2]), t1).size() == 1)
	var sb := _tape(t1).filter(func(r: Array) -> bool: return r[1] == &"shield_block")
	_ok("and the card plays no shield_block (%d)" % sb.size(), sb.is_empty())

	# PLATES SHED, AND A HIT PARTLY TAKEN
	print("-- plates off, a hit partly taken")
	var m2 := _moments.size()
	var h2 := _heard_rows().size()
	var t2 := Audio.tape.size()
	var l2 := _landed.size()
	e.block = 0
	e.brace = 1
	sc._fx_sync_enemy(0)
	var offs := _moments_of(&"enemy", [&"plate_off"], m2)
	var shed := _heard(&"brace_off", h2)
	_ok("shed plates heard on the frame they go (%d, %d)" % [offs.size(), shed.size()],
		offs.size() == 1 and shed.size() == 1 and int(shed[0][4]) == int(offs[0][2]))
	_ok("as jettison at -10 dB", not offs.is_empty() and _taped_at(&"jettison", int(offs[0][2]), t2).size() == 1
		and is_equal_approx(float(_taped_at(&"jettison", int(offs[0][2]), t2)[0][2]), -10.0))
	await _frames(30)
	# (the impact's and the plate's own rate limits are the wall's: let some pass)
	OS.delay_msec(150)
	var shot: Dictionary = (DB.SHARED[&"cut"] as Dictionary).duplicate()
	shot.energy = 0
	_play(shot)
	await _until(func() -> bool: return _landed.size() > l2, 180)
	await _frames(20)
	var land: Array = _landed[l2] if _landed.size() > l2 else [0, false, 0, -1]
	_ok("the hit lands partly taken (%d through, %d taken)" % [land[0], land[2]], int(land[0]) > 0 and int(land[2]) > 0)
	var part := _heard(&"hit_partial", h2)
	_ok("heard on its landing (%s vs %d)" % [part.map(func(r: Array) -> int: return int(r[4])), land[3]],
		part.size() == 1 and int(part[0][4]) == int(land[3]))
	var sbp := _taped_at(&"shield_block", int(land[3]), t2)
	_ok("shield_block at -8 dB under the impact (%s)" % [sbp],
		sbp.size() == 1 and is_equal_approx(float(sbp[0][2]), -8.0)
		and _taped_at(&"impact_enemy", int(land[3]), t2).size() == 1)
	var spent := _moments_of(&"enemy", [&"plate_off"], m2)
	_ok("the last plate off with it (brace spent: %d sheds, %d heard)" % [spent.size(), _heard(&"brace_off", h2).size()],
		spent.size() == 2 and _heard(&"brace_off", h2).size() == 2)

	# ITS SHIELD UP, AND A HIT TAKEN WHOLE: as before
	print("-- a shield, a hit taken whole")
	var m3 := _moments.size()
	var h3 := _heard_rows().size()
	var t3 := Audio.tape.size()
	var l3 := _landed.size()
	e.block = 30
	# (shield_block's own limit is 90 ms of the wall's: headless, the last one
	# may be fewer ms ago than its frames say)
	OS.delay_msec(150)
	sc._fx_sync_enemy(0)
	var ups := _moments_of(&"enemy", [&"shield_up"], m3)
	_ok("its shield up plays shield_block at -6 dB as before",
		ups.size() == 1 and _taped_at(&"shield_block", int(ups[0][2]), t3).size() == 1
		and is_equal_approx(float(_taped_at(&"shield_block", int(ups[0][2]), t3)[0][2]), -6.0))
	await _frames(30)
	OS.delay_msec(150)
	_play(shot)
	await _until(func() -> bool: return _landed.size() > l3, 180)
	await _frames(20)
	var land3: Array = _landed[l3] if _landed.size() > l3 else [0, false, 0, -1]
	var whole := _taped_at(&"shield_block", int(land3[3]), t3)
	_ok("a hit taken whole: shield_block at -4 dB, no partial (%s)" % [whole],
		int(land3[0]) == 0 and whole.size() == 1 and is_equal_approx(float(whole[0][2]), -4.0)
		and _heard(&"hit_partial", h3).is_empty())

	# VENTS: three opened on one frame, then their sputters
	print("-- vents")
	e.block = 0
	var L := sc._enemy_fx(0)
	var hits := L.hits as ShipHitFx
	if not _ok("its marks are a ship's", hits != null):
		return
	# (down to a fifth, as the screen shows it, so nothing sets the hull back)
	e.hp = maxi(1, e.max_hp / 5)
	var shown: Variant = sc.get("_slot_shown")
	if shown is Dictionary:
		(shown as Dictionary)[0] = e.hp
	sc._fx_sync_enemy(0)
	await _frames(10)
	var m4 := _moments.size()
	var h4 := _heard_rows().size()
	var t4 := Audio.tape.size()
	hits.set_hull(float(e.hp) / float(e.max_hp))
	var pts: Array = []
	var mask: PackedByteArray = hits.get("_mask")
	var w: int = hits.get("_w")
	var step := maxi(1, mask.size() / 4)
	for i in range(step / 2, mask.size(), 1):
		if mask[i] == 1 and (pts.is_empty() or i - int(pts.back()) > step / 2):
			pts.append(i)
		if pts.size() >= 3:
			break
	for i: int in pts:
		hits.call(&"_vent", Vector2i(i % w, i / w), true)
	var hiss := _moments_of(&"enemy", [&"hiss"], m4)
	var hh := _heard(&"vent_hiss", h4)
	_ok("three vents opened on one frame (%d) heard once (%d)" % [hiss.size(), hh.size()],
		hiss.size() == 3 and hh.size() == 1 and int(hh[0][4]) == int(hiss[0][2]))
	_ok("as vent at -8 dB", not hh.is_empty() and _taped_at(&"vent", int(hh[0][4]), t4).size() == 1
		and is_equal_approx(float(_taped_at(&"vent", int(hh[0][4]), t4)[0][2]), -8.0))
	await _frames(600)
	var sp := _moments_of(&"enemy", [&"sputter"], m4)
	var sh := _heard(&"vent_sputter", h4)
	var sp_frames := sp.map(func(m: Array) -> int: return int(m[2]))
	var close := 0
	var stray := 0
	var bad_db := 0
	for i in sh.size():
		if not int(sh[i][4]) in sp_frames:
			stray += 1
		if i > 0 and float(sh[i][5]) - float(sh[i - 1][5]) < 0.4 - 0.001:
			close += 1
		var rows := _taped_at(&"vent", int(sh[i][4]), t4)
		if rows.size() != 1 or not is_equal_approx(float(rows[0][2]), -12.0):
			bad_db += 1
	# every sputter heard, or one was heard under 0.4 s before it
	var lost := 0
	for m: Array in sp:
		var t := float(m[3])
		if not sh.any(func(r: Array) -> bool: return float(r[5]) <= t + 0.0001 and t - float(r[5]) < 0.4):
			lost += 1
	_ok("ten seconds of sputters (%d) heard %d times, on their frames (%d not), never under 0.4 s apart (%d)"
		% [sp.size(), sh.size(), stray, close], sp.size() >= 3 and sh.size() >= 2 and stray == 0 and close == 0)
	_ok("none left unheard but for the limit (%d), all at -12 dB (%d not)" % [lost, bad_db], lost == 0 and bad_db == 0)
	var peak: Dictionary = Audio.get("dry_peak") if Audio.get("dry_peak") is Dictionary else {}
	print("    [vents] most vent voices in the air at once: %s" % str(peak.get(&"vent", "-")))
	# NOTHING SEEN, NOTHING HEARD: the ship hidden (as while it breaks up, and
	# as its wreck), its vents keep their clock and are not heard
	var m5 := _moments.size()
	var h5 := _heard_rows().size()
	sc._view.slot(0).hide_art(true)
	await _frames(400)
	var hid := _moments_of(&"enemy", [&"sputter"], m5)
	_ok("its layers hidden, its sputters (%d) are not heard (%d)" % [hid.size(), _heard(&"vent_sputter", h5).size()],
		hid.size() >= 1 and _heard(&"vent_sputter", h5).is_empty())
	sc._view.slot(0).hide_art(false)
	await _leave()


func _until(c: Callable, n: int) -> void:
	for i in n:
		if c.call():
			return
		await _tree.process_frame


## Out of a fight however it stands (won, as a fight is): a fresh run next.
func _leave() -> void:
	var cb: Combat = Router.combat
	if cb != null and not cb.finished and not cb.enemies.is_empty():
		cb.damage_enemy(9999, 1, "test", cb.enemies[0])
	for i in 1500:
		if Router.combat == null:
			break
		await _tree.process_frame
	await _frames(10)


## The first system (over seeds from `seed0`) where a `id` dies in `style`.
func _style_seed(id: StringName, style: int, seed0: int) -> Array:
	for s in range(seed0, seed0 + 40):
		Rng.forced = s
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		for n: MapGen.MapNode in Run.map:
			if n.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(n) \
					and EnemyArt.death_style(DB.enemies[id], n.index, 0) == style:
				return [s, n.index]
	return []


## Kill enemy 0 outright and watch its breakup to the end.
func _kill_and_watch(max_frames: int = 1500) -> bool:
	var cb: Combat = Router.combat
	var e: Combat.EnemyState = cb.enemies[0]
	e.block = 0
	e.brace = 0
	var m0 := _moments.size()
	cb.damage_enemy(9999, 1, "test", e)
	for i in max_frames:
		await _tree.process_frame
		if not _moments_of(&"death", [&"finished"], m0).is_empty():
			await _frames(20)
			return true
	return false


func _vent_death() -> void:
	print("-- a cutter dying in G")
	var at := _style_seed(&"cutter", ShipBreakup.Style.VENT, 4242)
	if not _ok("a system where a cutter dies in G", not at.is_empty()):
		return
	var m0 := _moments.size()
	var h0 := _heard_rows().size()
	var t0 := Audio.tape.size()
	var sc := await _start(int(at[0]), &"cutter", func(n: MapGen.MapNode) -> bool: return n.index == int(at[1]))
	if not _ok("its fight opens", sc != null):
		return
	m0 = _moments.size()
	h0 = _heard_rows().size()
	t0 = Audio.tape.size()
	_ok("it comes apart", await _kill_and_watch())
	var jets := _moments_of(&"death", [&"vent"], m0)
	var jh := _heard(&"vent_jet", h0)
	var jf := jets.map(func(m: Array) -> int: return int(m[2]))
	var ok_frames := jh.all(func(r: Array) -> bool: return int(r[4]) in jf)
	var lost := 0
	for m: Array in jets:
		var t := float(m[3])
		if not jh.any(func(r: Array) -> bool: return float(r[5]) <= t + 0.0001 and t - float(r[5]) < 0.15):
			lost += 1
	_ok("its jets (%d) heard %d times, on their frames, none lost but to the limit (%d)" % [jets.size(), jh.size(), lost],
		jets.size() >= 1 and jh.size() >= 1 and ok_frames and lost == 0)
	_ok("as vent at -8 dB", jh.all(func(r: Array) -> bool:
		var rows := _taped_at(&"vent", int(r[4]), t0)
		return rows.size() == 1 and is_equal_approx(float(rows[0][2]), -8.0)))
	var sps := _moments_of(&"death", [&"sputter"], m0)
	var sph := _heard(&"vent_sputter", h0)
	_ok("its sputters (%d) heard %d times, at least 0.4 s apart" % [sps.size(), sph.size()],
		sps.size() == 2 and sph.size() == 1)
	_ok("and its booms still the kill pool", _tape(t0).any(func(r: Array) -> bool: return r[1] == &"explosion_small"))
	await _leave()


func _creature(style: int) -> void:
	var nm := String(ShipBreakup.NAMES.get(style, str(style)))
	print("-- the calf dying in %s" % nm)
	var at := _style_seed(&"whale", style, 4242)
	if not _ok("a system where the calf dies in %s" % nm, not at.is_empty()):
		return
	var sc := await _start(int(at[0]), &"whale", func(n: MapGen.MapNode) -> bool: return n.index == int(at[1]))
	if not _ok("its fight opens", sc != null):
		return
	var m0 := _moments.size()
	var h0 := _heard_rows().size()
	var t0 := Audio.tape.size()
	_ok("%s: it dies" % nm, await _kill_and_watch())
	var beats := _moments_of(&"death", [&"flare", &"pulse"], m0)
	var fd := _heard(&"fauna_death", h0)
	var first := int(beats[0][2]) if not beats.is_empty() else -2
	_ok("%s: heard once (%d), on the death's first beat (%s vs %d)" % [nm, fd.size(),
		fd.map(func(r: Array) -> int: return int(r[4])), first], fd.size() == 1 and int(fd[0][4]) == first)
	var rows := _taped_at(&"fauna_falls", first, t0)
	_ok("%s: as fauna_falls at -4 dB (%s)" % [nm, rows], rows.size() == 1 and is_equal_approx(float(rows[0][2]), -4.0))
	_ok("%s: and no explosion" % nm, not _tape(t0).any(func(r: Array) -> bool: return r[1] == &"explosion_small"))
	await _leave()


func _hellbender() -> void:
	print("-- the Hellbender's furnace and its pops")
	var sc := await _start(4242, &"hellbender")
	if not _ok("its fight opens", sc != null):
		return
	var m0 := _moments.size()
	var h0 := _heard_rows().size()
	var t0 := Audio.tape.size()
	var bed := {on_frame = -1, off_frame = -1, up = false, down_after = false}
	_sampler = func(f: int) -> void:
		var now: StringName = Audio.get("bed_now") if Audio.get("bed_now") != null else &""
		if now == &"hb_heat" and bed.on_frame < 0:
			bed.on_frame = f
			bed.up = true
		if bed.up and now == &"" and bed.off_frame < 0:
			bed.off_frame = f
	_ok("it comes apart", await _kill_and_watch(1500))
	_sampler = Callable()
	var heat := _moments_of(&"death", [&"emblem_heat"], m0)
	var burst := _moments_of(&"death", [&"emblem_burst"], m0)
	var hb := _heard(&"hb_heat", h0)
	var ons := hb.filter(func(r: Array) -> bool: return r[1] == &"emblem_heat")
	var offs := hb.filter(func(r: Array) -> bool: return r[1] == &"stop")
	_ok("the furnace in on the device heating (%s vs %s)" % [ons.map(func(r: Array) -> int: return int(r[4])),
		heat.map(func(m: Array) -> int: return int(m[2]))],
		heat.size() == 1 and ons.size() == 1 and int(ons[0][4]) == int(heat[0][2]) and bed.on_frame == int(heat[0][2]))
	_ok("and out on its burst (%s vs %s)" % [offs.map(func(r: Array) -> int: return int(r[4])),
		burst.map(func(m: Array) -> int: return int(m[2]))],
		burst.size() == 1 and offs.size() >= 1 and int(offs[0][4]) == int(burst[0][2]) and bed.off_frame == int(burst[0][2]))
	_ok("nothing left of it after", Audio.get("bed_now") == &"")
	_pops(m0, h0, t0, "Hellbender")
	await _leave()


func _pops(m0: int, h0: int, t0: int, who: String) -> void:
	var pops := _moments_of(&"death", [&"pop", &"rupture"], m0)
	var ph := _heard(&"boss_pop", h0)
	var pf := pops.map(func(m: Array) -> int: return int(m[2]))
	var lost := 0
	for m: Array in pops:
		var t := float(m[3])
		if not ph.any(func(r: Array) -> bool: return float(r[5]) <= t + 0.0001 and t - float(r[5]) < 0.08):
			lost += 1
	_ok("%s: its pops (%d) heard %d times on their frames, none lost but to the limit (%d)"
		% [who, pops.size(), ph.size(), lost], pops.size() >= 2 and ph.size() >= 2
		and ph.all(func(r: Array) -> bool: return int(r[4]) in pf) and lost == 0)
	_ok("%s: as explosion_small at -10 dB" % who, ph.all(func(r: Array) -> bool:
		var rows := _taped_at(&"explosion_small", int(r[4]), t0).filter(func(x: Array) -> bool: return is_equal_approx(float(x[2]), -10.0))
		return rows.size() == 1))


func _custodian() -> void:
	print("-- the Custodian's C1c")
	var core := -1
	var seed := -1
	for s in range(4242, 4282):
		Rng.forced = s
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		for n: MapGen.MapNode in Run.map:
			if n.type == MapGen.NodeType.CORE and EnemyArt.death_style(DB.enemies[&"custodian"], n.index, 0) == ShipBreakup.Style.CUST_SPLIT:
				core = n.index
				seed = s
		if core >= 0:
			break
	if not _ok("a core where it splits", core >= 0):
		return
	Rng.forced = seed
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.at = core
	SectorScreen._approached_at = core
	Router.show_local()
	await _frames(4)
	Router.start_combat(DB.enemies[&"custodian"], [], false, false)
	var sc: SectorScreen = null
	for i in 900:
		await _tree.process_frame
		sc = Router.current as SectorScreen
		if Router.combat != null and sc != null and sc.fighting() and not sc._opening:
			break
	await _frames(30)
	if not _ok("its fight opens", Router.combat != null):
		return
	var m0 := _moments.size()
	var h0 := _heard_rows().size()
	var t0 := Audio.tape.size()
	_ok("it comes apart", await _kill_and_watch(1500))
	_pops(m0, h0, t0, "C1c")
	var split := _moments_of(&"death", [&"split"], m0)
	var sh := _heard(&"boss_split", h0)
	_ok("its split heard once on its frame (%s vs %s)" % [sh.map(func(r: Array) -> int: return int(r[4])),
		split.map(func(m: Array) -> int: return int(m[2]))],
		split.size() == 1 and sh.size() == 1 and int(sh[0][4]) == int(split[0][2]))
	_ok("as explosion_small at 0 dB", not split.is_empty() and _taped_at(&"explosion_small", int(split[0][2]), t0).any(
		func(r: Array) -> bool: return is_equal_approx(float(r[2]), 0.0)))


# ---------------------------------------------------------------- your ship lost

func _loss() -> void:
	print("-- your ship lost")
	var sc := await _start(6061, &"cutter")
	if not _ok("a cutter's fight opens", sc != null):
		return
	var cb: Combat = Router.combat
	var e: Combat.EnemyState = cb.enemies[0]
	var hits := maxi(1, e.intent.hits if e.intent != null else 1)
	var dmg := (e.intent.damage if e.intent != null else 0) * hits
	Run.hp = 5 if dmg >= 5 else 1
	cb.block = 0
	cb.brace = 0
	var m0 := _moments.size()
	var h0 := _heard_rows().size()
	var t0 := Audio.tape.size()
	var s0 := _swaps.size()
	var duck := {until = -1.0, to = 1.0, at_swap = -1.0}
	_sampler = func(_f: int) -> void:
		var u: Variant = Audio.get("_scene_duck_until")
		if u != null and float(u) > float(duck.until):
			duck.until = float(u)
			duck.to = float(Audio.get("_scene_duck_to"))
	sc._end_button.pressed.emit()
	for i in 1500:
		await _tree.process_frame
		if Router.current is GameOverScreen:
			duck.at_swap = GameClock.now()
			break
	await _frames(10)
	_sampler = Callable()
	if not _ok("the run's screen comes", Router.current is GameOverScreen):
		return
	var hand := _moments_of(&"handoff", [&"start"], m0)
	var lh := _heard(&"loss_handoff", h0)
	_ok("the handoff heard as it starts (%s vs %s)" % [lh.map(func(r: Array) -> int: return int(r[4])),
		hand.map(func(m: Array) -> int: return int(m[2]))],
		hand.size() == 1 and lh.size() == 1 and int(lh[0][4]) == int(hand[0][2]))
	_ok("as power_off at 0 dB", not hand.is_empty() and _taped_at(&"power_off", int(hand[0][2]), t0).size() == 1)
	var done := _moments_of(&"death", [&"finished"], m0)
	var dk := _heard(&"loss_duck", h0)
	_ok("the score ducked as the breakup ends (%s vs %s)" % [dk.map(func(r: Array) -> int: return int(r[4])),
		done.map(func(m: Array) -> int: return int(m[2]))],
		dk.size() == 1 and not done.is_empty() and int(dk[0][4]) == int(done.back()[2]))
	_ok("down to %.2f, held to the swap (%.2f s, swap at %.2f s)" % [float(duck.to), float(duck.until), float(duck.at_swap)],
		is_equal_approx(float(duck.to), 0.4) and float(duck.until) >= float(duck.at_swap) - 0.05
		and float(duck.until) <= float(duck.at_swap) + 0.5)
	var over := -1
	for i in range(s0, _swaps.size()):
		if StringName(_swaps[i][1]) == &"GameOverScreen":
			over = int(_swaps[i][0])
	var clicks := _tape(t0).filter(func(r: Array) -> bool: return r[1] == &"ui_tab" and absi(int(r[3]) - over) <= 1)
	_ok("no page click on the swap into RUN ENDED (swap frame %d, %d clicks)" % [over, clicks.size()],
		over >= 0 and clicks.is_empty())
	await _leave()


# ---------------------------------------------------------------- the ladder

func _ladder() -> void:
	print("-- the ladder: the chrome and the decode")
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 60.0
	Rng.forced = 7
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	StarchartScreen._primed_for = Run.galaxy_seed
	var sys := Run.at
	var lay := SystemLayout.of(Run.node_at())
	for b in lay.bodies:
		if b.world != &"" and b.kind != &"belt":
			SystemMapScreen._parked[sys] = {"at": b.index, "mode": &"rail"}
			break
	SectorScreen._approached_at = sys
	Router.show_local()
	await _frames(40)
	await _hop("LOCAL -> map", Router.show_system, &"chrome_on", &"menu_open", true)
	await _hop("map -> chart", Router.show_starchart, &"", &"", true)
	await _hop("chart -> map", Router.show_system, &"", &"", true)
	# (into LOCAL the side bar's column slides off whole: nothing decodes)
	await _hop("map -> LOCAL", Router.show_local, &"chrome_off", &"menu_close", false)
	ZoomLadder.force = -1
	ZoomLadder.fixed_dt = -1.0


func _hop(label: String, door: Callable, chrome_row: StringName, chrome_file: StringName, decodes: bool) -> void:
	var h0 := _heard_rows().size()
	var t0 := Audio.tape.size()
	if Audio.get("dry_peak") is Dictionary:
		(Audio.get("dry_peak") as Dictionary).clear()
	var seen := {moved = -1, start = Vector2.INF, starts = [], slide = null, swap = null, to = -1.0}
	_sampler = func(f: int) -> void:
		for pc: Variant in ChromeSlide.live:
			if is_instance_valid(pc) and (pc as ChromeSlide).kind == &"side":
				if seen.slide != pc:
					seen.slide = pc
					seen.start = Vector2.INF
				var p := (pc as ChromeSlide).at().position
				if seen.start == Vector2.INF:
					# where it was put: at its start before any move (main: as
					# first seen)
					var k0: Variant = (pc as ChromeSlide).get("_k0")
					seen.start = (pc as ChromeSlide).rest.position 						+ ((pc as ChromeSlide).off * (1.0 - float(k0))).round() if k0 != null else p
				if p != seen.start and seen.moved < 0:
					seen.moved = f
		var sw := SideSwap.side_now()
		if sw != null and sw.get("look") == "E":
			if seen.swap != sw:
				seen.swap = sw
				seen.to = -1.0
			var t := float(sw.t)
			if t <= float(seen.to) or t <= 0.0:
				return
			var any := false
			for r: Array in sw.get("_rows_now"):
				var r0 := float(r[2])
				if int(r[1]) == 0 and r0 >= 0.0 and r0 > float(seen.to) and r0 <= t:
					any = true
			seen.to = t
			if any:
				(seen.starts as Array).append(f)
	door.call()
	for i in 900:
		await _tree.process_frame
		if not ZoomLadder.busy() and ZoomLadder.chain == &"" and SideSwap.side_now() == null and SideSwap.bar_now() == null:
			break
	await _frames(4)
	_sampler = Callable()
	if chrome_row != &"":
		var ch := _heard(chrome_row, h0)
		_ok("%s: the chrome heard once (%d), as the column first moves (%s vs %d)" % [label, ch.size(),
			ch.map(func(r: Array) -> int: return int(r[4])), seen.moved],
			ch.size() == 1 and int(ch[0][4]) == int(seen.moved))
		var rows := _taped_at(chrome_file, int(seen.moved), t0)
		_ok("%s: as %s at -6 dB" % [label, chrome_file], rows.size() == 1 and is_equal_approx(float(rows[0][2]), -6.0))
	else:
		_ok("%s: no chrome sound (no chrome moves)" % label, _heard(&"chrome_on", h0).is_empty() and _heard(&"chrome_off", h0).is_empty())
	var dec := _heard(&"side_decode", h0)
	var df := dec.map(func(r: Array) -> int: return int(r[4]))
	if not decodes:
		_ok("%s: nothing decodes, nothing blips (%d lines, %d blips)" % [label, (seen.starts as Array).size(), dec.size()],
			(seen.starts as Array).is_empty() and dec.is_empty())
		return
	_ok("%s: a blip as each line starts (%d lines, %d blips; %s vs %s)" % [label, (seen.starts as Array).size(), dec.size(),
		df, seen.starts], (seen.starts as Array).size() >= 2 and df == seen.starts)
	var peak: Dictionary = Audio.get("dry_peak") if Audio.get("dry_peak") is Dictionary else {}
	var most := int(peak.get(&"text_blip", 0)) if DisplayServer.get_name() == "headless" else _most_at_once(t0, &"text_blip")
	_ok("%s: never more than two blips in the air (%d)" % [label, most], most <= 2 and most >= 1)


## (in a window: the blips' rows against the file's length, the cap's steals
## not seen -- an upper bound)
func _most_at_once(t0: int, asked: StringName) -> int:
	var rows := _tape(t0).filter(func(r: Array) -> bool: return r[1] == asked)
	var most := 0
	for r: Array in rows:
		var n := rows.filter(func(x: Array) -> bool: return int(x[3]) <= int(r[3]) and int(x[3]) > int(r[3]) - 18).size()
		most = maxi(most, n)
	return most
