extends Node

## Every landed jump film through the real Router, headless on a fixed clock: the commit on
## time, the cues on their frames, the HUD still, the stage inside EncounterView and gone
## with the commit, a skip that hushes, deterministic picks, REDUCE FLASHES capping the flash.
##   godot --headless --fixed-fps 60 --path . -- sheet=JumpSeqTest
## Why: docs/why/JumpSeqTest.md#jump-sequence-test

var _tree: SceneTree
var h := Harness.new()
var _cues: Dictionary = {}


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _quiet_target() -> int:
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.index != Run.at and Run.can_jump_to(m) and m.type == MapGen.NodeType.SYSTEM:
			m.ambush_rolled = true
			m.ambush_pending = false
			return m.index
	return -1


func _hud() -> Control:
	return _tree.root.find_child("HudBar", true, false) as Control if _tree.root.find_child("HudBar", true, false) != null else _find_hud(_tree.root)


func _find_hud(n: Node) -> Control:
	if n is HudBar:
		return n
	for c in n.get_children():
		var f := _find_hud(c)
		if f != null:
			return f
	return null


func _count(n: Node, cls: String) -> int:
	var k := 1 if n.get_script() != null and n.get_script().get_global_name() == cls else 0
	for c in n.get_children():
		k += _count(c, cls)
	return k


## One jump on film `id`: returns what was seen, for the checks.
func _jump(id: StringName, skip_at: float = -1.0) -> Dictionary:
	JumpRegistry.forced = id
	var to := _quiet_target()
	var seen := {to = to, began = false, commit_t = -1.0, hud_moved = false, canvas_moved = false,
		stage_ok = true, hull_hidden_at = -1.0, max_flash = 0.0, film = &"", stage_left = false, flash_floor = -1.0,
		director_left = false, skipped_at = -1.0, max_shake = 0.0}
	if not _ok("%s: a quiet system in reach (%d)" % [id, to], to >= 0):
		return seen
	var hud := _find_hud(_tree.root)
	var hud_rect := hud.get_global_rect() if hud != null else Rect2()
	var jumps0 := Run.jumps
	Audio.tape.clear()
	Audio.hushed.clear()
	Audio.taping = true
	Router.begin_jump(to)
	var t0 := -1.0
	for i in 60 * 16:
		await _tree.process_frame
		var sc := Router.current as SectorScreen
		var d: JumpDirector = sc._jump if sc != null else null
		if d != null and d._begun and t0 < 0.0:
			t0 = d._t0
			seen.began = true
			seen.film = d.film()
		if d != null and d._begun and Run.jumps == jumps0:
			var st: JumpStage = d.stage
			if st == null or st.get_parent() != sc._view or st.get_index() != sc._view.get_child_count() - 1:
				seen.stage_ok = false
			if hud != null and hud.get_global_rect() != hud_rect:
				seen.hud_moved = true
			if sc.get_viewport().canvas_transform != Transform2D.IDENTITY:
				seen.canvas_moved = true
			if seen.hull_hidden_at < 0.0 and not d.art.visible:
				seen.hull_hidden_at = d.t
			seen.max_flash = maxf(seen.max_flash, d.seq.flash)
			if d.seq.flash > 0.0 and st != null:
				seen.flash_floor = float(st.mat2.get_shader_parameter(&"flash_floor"))
			seen.max_shake = maxf(seen.max_shake, absf(d.seq.shake.x) + absf(d.seq.shake.y))
			if skip_at >= 0.0 and d.t >= skip_at and seen.skipped_at < 0.0:
				seen.skipped_at = d.t
				sc._skip()
		if Run.jumps > jumps0 and seen.commit_t < 0.0:
			seen.commit_t = GameClock.now() - t0
		if Run.jumps > jumps0 and i > 0 and seen.commit_t >= 0.0 and GameClock.now() - t0 > seen.commit_t + 0.5:
			break
	Audio.taping = false
	seen.t0 = t0
	seen.tape = Audio.tape.duplicate()
	seen.hushed = Audio.hushed.duplicate()
	seen.stage_left = _count(_tree.root, "JumpStage") > 0
	seen.director_left = _count(_tree.root, "JumpDirector") > 0
	seen.jumped = Run.jumps == jumps0 + 1
	return seen


func _cue_t(tape: Array, cue: StringName, t0: float) -> float:
	for e in tape:
		if e[0] == cue:
			return float(e[4]) - t0
	return -99.0


func _check_film(id: StringName) -> void:
	var seq := JumpRegistry.make(id)
	var s := await _jump(id)
	if not seen_ok(id, s):
		return
	var dt := 1.0 / 60.0 + 1e-4
	_ok("%s: the film played (%s) and the jump committed once" % [id, s.film], s.film == id and s.jumped)
	_ok("%s: committed at %.3f s, the film's %.2f (within a frame)" % [id, s.commit_t, seq.commit_t],
		s.commit_t >= seq.commit_t - 1e-4 and s.commit_t <= seq.commit_t + 2.0 * dt)
	_ok("%s: landed on the system map" % id, Router.current is SystemMapScreen)
	var c: Dictionary = _cues.get(String(id), {})
	var bt := _cue_t(s.tape, StringName(c.build.cue), s.t0)
	var ht := _cue_t(s.tape, StringName(c.hit.cue), s.t0)
	_ok("%s: the build cue fired on the first frame (%.4f)" % [id, bt], absf(bt) <= dt)
	_ok("%s: the hit cue fired on the frame the clock crossed the cut (%.4f, cut %.3f)" % [id, ht, c.hit.at],
		ht >= float(c.hit.at) - 1e-4 and ht <= float(c.hit.at) + dt)
	var hit_from := -1.0
	for e in s.tape:
		if e[0] == StringName(c.hit.cue):
			hit_from = float(e[7])
	_ok("%s: and from inside the take by how late the frame was (%.4f vs %.4f)" % [id, hit_from, ht - float(c.hit.at)],
		absf(hit_from - (ht - float(c.hit.at))) < 1e-3)
	_ok("%s: no other effect played through the film (%d taped)" % [id, s.tape.size()], s.tape.size() <= 3)
	_ok("%s: the HUD never moved and the canvas never shook" % id, not s.hud_moved and not s.canvas_moved)
	_ok("%s: the stage stayed the last child of EncounterView" % id, s.stage_ok)
	_ok("%s: the live hull gave way to the stand-in at %.3f s (swap %.2f)" % [id, s.hull_hidden_at, seq.swap_t],
		s.hull_hidden_at >= seq.swap_t - 1e-4 and s.hull_hidden_at < seq.swap_t + 0.5)
	_ok("%s: the stage and the director went with the commit" % id, not s.stage_left and not s.director_left)
	_ok("%s: shook by whole pixels only (most %.1f)" % [id, s.max_shake], s.max_shake == floorf(s.max_shake))
	_ok("%s: the flash lit the whole frame as filmed (floor %.2f, most %.2f)" % [id, s.flash_floor, s.max_flash],
		s.max_flash == 0.0 or s.flash_floor == 0.10)


func seen_ok(id: StringName, s: Dictionary) -> bool:
	return _ok("%s: the director began" % id, bool(s.began))


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	Rng.forced = Harness.seed_arg(4242)
	var f := FileAccess.open("res://scripts/sim/jump_cues.json", FileAccess.READ)
	_cues = JSON.parse_string(f.get_as_text()) if f != null else {}
	_ok("jump_cues.json names every landed film (%s)" % ", ".join(JumpRegistry.ALL),
		JumpRegistry.ALL.all(func(i: StringName) -> bool: return _cues.has(String(i))))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	for i in 10:
		await _tree.process_frame
	(Router.current as SectorScreen)._skip()
	for i in 10:
		await _tree.process_frame

	# the pick: one draw per jump off the run's seed, both films drawn, the same again
	JumpRegistry.forced = &""
	var a: Array = []
	for j in 40:
		a.append(JumpRegistry.pick(j))
	var b: Array = []
	for j in 40:
		b.append(JumpRegistry.pick(j))
	_ok("picks are deterministic for a seed", a == b)
	_ok("and every film is drawn in forty jumps (%s)" % [a.slice(0, 8)],
		JumpRegistry.ALL.all(func(f: StringName) -> bool: return a.has(f))
		and a.all(func(x: StringName) -> bool: return x in JumpRegistry.ALL))

	for id in JumpRegistry.ALL:
		await _check_film(id)
		Router.show_local()
		for i in 10:
			await _tree.process_frame
		(Router.current as SectorScreen)._skip()
		for i in 5:
			await _tree.process_frame

	# a skip two seconds in: the cues hushed, the jump committed as skipped, nothing left
	var s := await _jump(&"r12", 2.0)
	_ok("skip: pressed at %.2f s, the jump committed" % s.skipped_at, s.skipped_at >= 2.0 and s.jumped)
	var hushed_names: Array = []
	for hs in s.hushed:
		hushed_names.append_array(hs[0])
	_ok("skip: both cues were hushed (%s)" % [hushed_names], hushed_names.has(&"jump_r12_build") and hushed_names.has(&"jump_r12_hit"))
	_ok("skip: no stage or director left", not s.stage_left and not s.director_left)
	Router.show_local()
	for i in 10:
		await _tree.process_frame
	(Router.current as SectorScreen)._skip()

	# REDUCE FLASHES: R4's full-frame flash is capped and keeps off the frame's floor
	DisplaySettings.reduce_flashes = true
	var r := await _jump(&"r4")
	_ok("reduce flashes: R4's flash capped at 0.35 (most %.2f) with no frame-wide floor (%.2f)" % [r.max_flash, r.flash_floor],
		r.max_flash <= 0.35 + 1e-4 and r.max_flash > 0.0 and r.flash_floor == 0.0)
	DisplaySettings.reduce_flashes = false
	_ok("the hull bake cache stays capped (%d)" % JumpHull._cache.size(), JumpHull._cache.size() <= JumpHull.CACHE_MAX)
	h.verdict("jumpseqtest")
	_tree.quit(h.code())
