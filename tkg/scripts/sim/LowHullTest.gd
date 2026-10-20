extends Node

## THE HULL FAILING (`LowHull`, `low_hull.gdshader`, `HullScramble`,
## `low_hull_mask.gdshader`, `VoiceGlitch`), headless:
##   godot --headless --path . --fixed-fps 60 -- sheet=LowHullTest
## From a run under way, animated (`Router.animate_in_harness`):
##   * the state: off at half the hull; on at TIER1_AT exactly and stepping up
##     at TIER2_AT; easing in over EASE_S (part way at half of it, whole after
##     it) and out the same way when the hull is repaired; off at 0 hull, on the
##     title and with no run;
##   * every place a run is played: LOCAL, the sector map, the star chart, a
##     fight, the station -- scrambling at each;
##   * the red breathes, and never past its preset's edge;
##   * THE WORDS: none above the line; at 30, 20, 10, 5 and 1% of the hull the
##     scramble rises (runs started, letters scrambled at once), under its
##     ceiling, a small share of the letters on screen even at 5%; the hull
##     readout among the texts that scramble;
##   * NOTHING MOVES: every text control's rect and minimum size, and every
##     control that takes the mouse, unchanged on every frame of all of it (the
##     screen's own movement measured first, with the hull sound, and not
##     counted), and the glass ignores the mouse;
##   * NOTHING IS REWRITTEN: every text read while it scrambles is its real
##     text, and after a repair nothing is left (no cell, no canvas item, no
##     mask), every SignalText's noise cleared;
##   * hand-drawn text (`LowHull.scr`): the string drawn is as wide as the real
##     one to the pixel, its letters' places unchanged, and the real one kept;
##   * a tooltip scrambles; the escape menu never, and nothing at all while it
##     is open;
##   * reduced motion: the red still and faint (REDUCED_RED), no scramble;
##   * the cost: its frame time at 5% against with the hull sound;
##   * her voice: every preset's plan inside her words, each window short
##     enough not to cover a word, apart, under MOST_SHARE; glitches a second
##     rising 30 -> 20 -> 10 -> 5%; a stutter or a chop first; rendered through
##     Godot's decoder the take keeps its length to the sample, is untouched
##     outside its windows, and starts and ends each window without a step; her
##     portrait slips once for each glitch (none under reduced motion, where her
##     voice keeps the subtle preset's glitches); baked on a worker.
## No pixels are looked at (headless draws nothing): the films are
## `-- sheet=LowHullFilm`'s.

var _tree: SceneTree
const TIP := preload("res://scripts/sim/LowHullFilm.gd")
var _fails := 0


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


func _secs(s: float) -> void:
	var t0 := GameClock.now()
	while GameClock.now() - t0 < s:
		await _tree.process_frame


func _set_share(s: float) -> void:
	Run.hp = maxi(0, int(floorf(Run.max_hp() * s + 0.00001)))
	SectorScreen.shown_hull = -1
	Sig.resources_changed.emit()


## Every control that takes the mouse, and every text, on the game's layer and
## in its windows, by id: [rect, minimum size].
func _rects() -> Dictionary:
	var out := {}
	for n in _tree.root.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		if c.mouse_filter == Control.MOUSE_FILTER_IGNORE and not HullScramble._is_text(c):
			continue
		out[c.get_instance_id()] = [LowHull._screen_rect(c), c.get_combined_minimum_size()]
	return out


func _same(a: Array, b: Array) -> bool:
	return (a[0] as Rect2).is_equal_approx(b[0]) and (a[1] as Vector2).is_equal_approx(b[1])


static func _words_of(n: Object) -> String:
	if n is Label:
		return (n as Label).text
	if n is Button:
		return (n as Button).text
	if n is RichTextLabel:
		return (n as RichTextLabel).text + "|" + (n as RichTextLabel).get_parsed_text()
	if n is SignalText:
		return (n as SignalText).text
	return ""


## Every text's words as a read sees them, by id.
func _words() -> Dictionary:
	var out := {}
	for n in _tree.root.find_children("*", "", true, false):
		if HullScramble._is_text(n):
			out[n.get_instance_id()] = _words_of(n)
	return out


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	Router.animate_in_harness = true
	DisplaySettings.reduced_motion = false
	var lh := LowHull.instance
	_ok("the low-hull layer is up, over the game and under the menu (layer %d)" % LowHull.LAYER,
		lh != null and LowHull.LAYER > 0 and LowHull.LAYER < 10)
	if lh == null:
		_tree.quit(1)
		return
	var hs := lh.scramble
	hs.seed_rolls(99)
	_ok("its glass ignores the mouse and takes no focus",
		lh._rect.mouse_filter == Control.MOUSE_FILTER_IGNORE and lh._rect.focus_mode == Control.FOCUS_NONE)
	_ok("the preset is one constant, Jon's strong (Oct 20)", LowHull.PRESET == LowHull.Preset.STRONG)

	# no run: off
	await _secs(0.3)
	_ok("on the title, off", LowHull.tier == 0 and LowHull.on == 0.0 and not hs._active)

	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(m):
			Run.at = m.index
			break
	Run.map[Run.at].visited = true
	Router.show_local()
	_set_share(0.5)
	await _secs(2.5)
	_ok("LOCAL, half the hull: off (tier %d, on %.2f, glass %s)" % [LowHull.tier, LowHull.on, lh._rect.visible],
		LowHull.tier == 0 and LowHull.on == 0.0 and not lh._rect.visible)
	var base := _rects()
	_ok("a LOCAL with controls and texts to keep still (%d)" % base.size(), base.size() > 20)
	# THE CONTROL: the same 8 s with the hull sound, so what LOCAL moves or
	# rewrites of its own accord is known before the effect is blamed for it
	var words0 := _words()
	var restless := {}
	var frame_us: Array[int] = []
	var tick := Time.get_ticks_usec()
	for i in 480:
		await _tree.process_frame
		# a headless frame runs as fast as it can: its wall time is its work
		var now_us := Time.get_ticks_usec()
		frame_us.append(now_us - tick)
		tick = now_us
		var r := _rects()
		for id in base:
			if r.has(id) and not _same(r[id], base[id]):
				restless[id] = true
	var words1 := _words()
	for id in words1:
		if words0.get(id, "") != words1[id]:
			restless[id] = true
	print("    (LOCAL moved or rewrote %d texts and controls of its own over 8 s with the hull sound)" % restless.size())
	base = _rects()
	var words := _words()
	var calm_us := _median(frame_us.slice(60))
	HullScramble.cost_most = 0

	# ON, at the line exactly
	var top := Run.max_hp()
	Run.hp = int(floorf(top * LowHull.TIER1_AT))
	Sig.resources_changed.emit()
	var at_line := LowHull.tier_for(Run.hp, top)
	_ok("%d/%d (at %.0f%%) is on" % [Run.hp, top, LowHull.TIER1_AT * 100.0], at_line == 1)
	_ok("one over the line is off", LowHull.tier_for(int(floorf(top * LowHull.TIER1_AT)) + 1, top) == 0)
	_ok("the red's second step at %.0f%%" % (LowHull.TIER2_AT * 100.0),
		LowHull.tier_for(int(floorf(top * LowHull.TIER2_AT)), top) == 2
		and LowHull.tier_for(int(floorf(top * LowHull.TIER2_AT)) + 1, top) == 1)
	await _secs(LowHull.EASE_S * 0.5)
	var half_on := LowHull.on
	_ok("easing in: part way at half the ease (%.2f)" % half_on, half_on > 0.3 and half_on < 0.7)
	await _secs(LowHull.EASE_S * 0.6)
	_ok("whole after the ease (on %.2f)" % LowHull.on, LowHull.on >= 1.0)

	# THE WORDS, BY THE HULL: each level settled, then 8 s of it measured, and
	# every frame of it checked for anything moved or rewritten
	var lk: Dictionary = LowHull.look().scr
	var moved := 0
	var worst := ""
	var rewrote := 0
	var rewrote_what := ""
	var checked := 0
	var levels := [0.30, 0.20, 0.10, 0.05, 0.01]
	var starts: Array[float] = []
	var at_once: Array[float] = []
	var peak_once := 0
	var letters_on_screen := 0
	var kinds := {}
	var hull_known := false
	var scr_us: Array[int] = []
	var low_us: Array[int] = []
	for lv in levels:
		Run.hp = maxi(1, int(roundf(top * lv)))
		Sig.resources_changed.emit()
		await _secs(LowHull.EASE_S + 0.3)
		HullScramble.started_log.clear()
		var sum := 0.0
		var frames := 0
		var t0 := GameClock.now()
		var tick2 := Time.get_ticks_usec()
		while GameClock.now() - t0 < 8.0:
			await _tree.process_frame
			var now2 := Time.get_ticks_usec()
			var frame_cost := now2 - tick2
			tick2 = now2
			frames += 1
			sum += float(HullScramble.cells_now)
			peak_once = maxi(peak_once, HullScramble.cells_now)
			if lv == 0.05:
				scr_us.append(HullScramble.cost_usec)
				low_us.append(frame_cost)
			var r := _rects()
			for id in base:
				if restless.has(id):
					continue
				if r.has(id) and not _same(r[id], base[id]):
					moved += 1
					worst = "%s %s -> %s" % [instance_from_id(id), base[id], r[id]]
			# every scrambled letter, read back: the real letter, never the noise
			for key: Variant in hs.live():
				var e: Dictionary = hs.live()[key]
				kinds[int(e.kind)] = true
				var who = e.node
				if not is_instance_valid(who) or not HullScramble._is_text(who as Node):
					continue
				var now_w := HullScramble._text_of(who)
				for c: Dictionary in e.cells:
					var i := int(c.i)
					if i >= now_w.length() or now_w[i] != String(c.ch):
						rewrote += 1
						rewrote_what = "%s: \"%s\" at %d, noise %s" % [who, now_w, i, c.get("g", "")]
				checked += e.cells.size()
		starts.append(float(HullScramble.started_log.size()) / 8.0)
		at_once.append(sum / float(maxi(1, frames)))
		if lv == 0.05:
			for row: Array in hs._elig:
				letters_on_screen += int(row[1])
		for n in Router.hud.stat_nodes("hp"):
			if n != null and hs._elig_ix.has((n as Object).get_instance_id()):
				hull_known = true
		print("    at %2.0f%%: %.2f runs started a second, %.2f letters scrambled at once (depth %.2f)" % [
			lv * 100.0, starts.back(), at_once.back(), LowHull.depth])
	var rising := true
	for i in 3:
		if not (starts[i + 1] > starts[i] and at_once[i + 1] > at_once[i]):
			rising = false
	_ok("the scramble rises as the hull falls, 30 -> 20 -> 10 -> 5%% (runs a second %s; letters at once %s)" % [
		_fmt(starts), _fmt(at_once)], rising and starts[4] >= starts[3] * 0.9)
	_ok("barely there at the line (%.2f letters at once, %.2f runs a second)" % [at_once[0], starts[0]],
		at_once[0] > 0.0 and at_once[0] < 0.5 and starts[0] < 1.0)
	_ok("never past its ceiling (%d at once at most, the ceiling %d)" % [peak_once, int(lk.most)], peak_once <= int(lk.most))
	_ok("readable at 5%%: %.1f of %d letters on screen scrambled at once (%.1f%%)" % [
		at_once[3], letters_on_screen, 100.0 * at_once[3] / maxf(1.0, letters_on_screen)],
		# (under one letter in eight: Jon's strong is about 7 to 8% at 5%, Oct 20)
		letters_on_screen > 60 and at_once[3] / float(letters_on_screen) < 0.125)
	_ok("Labels and Buttons both scramble (kinds %s)" % str(kinds.keys()),
		kinds.has(HullScramble.Kind.LABEL) and kinds.has(HullScramble.Kind.BUTTON))
	_ok("the HUD's hull readout is among the texts that scramble", hull_known)
	_ok("NOTHING MOVED: every text's and every pressable control's rect and minimum size, every frame of 40 s (%d%s)" % [
		moved, (", " + worst) if moved > 0 else ""], moved == 0)
	_ok("NOTHING REWRITTEN: every scrambled letter read back as its real letter, every frame (%d reads, %d wrong%s)" % [
		checked, rewrote, (", " + rewrote_what) if rewrote > 0 else ""], rewrote == 0 and checked > 100)
	var red1: Array = LowHull.look().red
	_ok("the red at the second step, never past its edge (%.3f, most %.2f)" % [LowHull.red_now, float(red1[1])],
		LowHull.red_now > 0.0 and LowHull.red_now <= float(red1[1]) + 0.001)
	var sc_mean := _mean(scr_us)
	var sc_most := 0
	for u in scr_us:
		sc_most = maxi(sc_most, u)
	var low_mean := _median(low_us)
	_ok("THE COST at 5%%: the scramble %.0f us a frame (%.2f ms at most); the whole frame (median) %.2f ms against %.2f ms with the hull sound" % [
		sc_mean, sc_most / 1000.0, low_mean / 1000.0, calm_us / 1000.0],
		sc_mean < 300.0 and sc_most < 3000 and low_mean - calm_us < 500.0)

	# HAND-DRAWN TEXT: as wide to the pixel, and the real string kept
	await _drawn_check()

	# THE ESCAPE MENU at 5%: clean, and nothing scrambles behind it while it is up
	Run.hp = maxi(1, int(roundf(top * 0.05)))
	Sig.resources_changed.emit()
	await _secs(1.0)
	var main := lh.get_parent()
	main.toggle_menu()
	await _secs(0.6)
	HullScramble.started_log.clear()
	var menu_hit := false
	var t_menu := GameClock.now()
	while GameClock.now() - t_menu < 4.0:
		await _tree.process_frame
		if not hs.live().is_empty():
			menu_hit = true
		for row: Array in hs._elig:
			var o: Variant = row[0]
			if o is CanvasItem and is_instance_valid(o) and (o as CanvasItem).get_canvas_layer_node() == main._overlay:
				menu_hit = true
	_ok("the escape menu open at 5%%: not a letter scrambled anywhere in 4 s (%d started)" % HullScramble.started_log.size(),
		not menu_hit and HullScramble.started_log.is_empty() and HullScramble.cells_now == 0)
	main.toggle_menu()
	await _secs(1.5)
	_ok("and the menu shut, it scrambles again (%d started)" % HullScramble.started_log.size(), HullScramble.started_log.size() > 0)

	# A TOOLTIP at 10%
	await _tooltip_check(top)

	# REPAIRED, to the half it started at (so every text should read as it did)
	_set_share(0.5)
	await _secs(LowHull.EASE_S * 0.5)
	_ok("repaired: easing out (on %.2f)" % LowHull.on, LowHull.on > 0.3 and LowHull.on < 0.7)
	await _secs(LowHull.EASE_S * 0.5 + 0.15)
	_ok("and off (on %.2f, glass %s)" % [LowHull.on, lh._rect.visible], LowHull.on == 0.0 and not lh._rect.visible)
	var st_left := 0
	for n in _tree.root.find_children("*", "", true, false):
		if n is SignalText and not (n as SignalText).scramble.is_empty():
			st_left += 1
	var w_after := _words()
	var differ := 0
	for id in w_after:
		if words.has(id) and not restless.has(id) and words[id] != w_after[id]:
			differ += 1
	_ok("RESTORED EXACTLY: no letter scrambled, no canvas item or mask held, no SignalText noise, every text its words (%d cells, %d held, %d noisy, %d differ)" % [
		HullScramble.cells_now, hs.held(), st_left, differ],
		HullScramble.cells_now == 0 and hs.held() == 0 and hs.live().is_empty() and st_left == 0 and differ == 0)
	HullScramble.started_log.clear()
	await _secs(2.0)
	_ok("no scramble once off", HullScramble.started_log.is_empty())
	_ok("none above the line: %d/%d is off" % [int(floorf(top * LowHull.TIER1_AT)) + 1, top],
		LowHull.depth_for(float(int(floorf(top * LowHull.TIER1_AT)) + 1) / float(top)) == 0.0)

	# EVERY PLACE A RUN IS PLAYED, scrambling at each
	_set_share(0.2)
	var places := {}
	Router.show_system()
	await _secs(1.5)
	HullScramble.started_log.clear()
	await _secs(2.0)
	places["the sector map"] = LowHull.tier == 1 and LowHull.on > 0.9 and HullScramble.started_log.size() > 0
	Router.show_starchart()
	await _secs(1.5)
	HullScramble.started_log.clear()
	await _secs(2.0)
	places["the star chart"] = LowHull.tier == 1 and LowHull.on > 0.9 and HullScramble.started_log.size() > 0
	Router.show_local()
	await _secs(1.5)
	places["LOCAL"] = LowHull.tier == 1 and LowHull.on > 0.9
	Run.node_at().danger = maxi(Run.node_at().danger, 3)
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	await _secs(1.5)
	places["a fight"] = LowHull.tier == 1 and LowHull.on > 0.9 and Router.current is SectorScreen and Router.combat != null
	# the fight's own count: a hit lands as it is shown
	SectorScreen.shown_hull = int(top * 0.1)
	await _frames(2)
	places["a fight, its shown hull at 10%"] = LowHull.tier == 2
	await _secs(LowHull.EASE_S)
	var fight_base := _rects()
	var fmoved := 0
	HullScramble.started_log.clear()
	var fkinds := {}
	for i in 360:
		await _tree.process_frame
		var r := _rects()
		for id in fight_base:
			if r.has(id) and not _same(r[id], fight_base[id]):
				fmoved += 1
		for key: Variant in hs.live():
			fkinds[int(hs.live()[key].kind)] = true
	SectorScreen.shown_hull = -1
	_ok("in a fight at 10%%, nothing that takes the mouse or holds text moved over 6 s (%d), %d runs scrambled (kinds %s)" % [
		fmoved, HullScramble.started_log.size(), str(fkinds.keys())],
		fmoved == 0 and HullScramble.started_log.size() > 20)
	Router.combat = null
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.STATION:
			Run.at = m.index
			m.visited = true
			break
	Router.park_at_station()
	Router.show_station()
	_set_share(0.2)
	await _secs(1.5)
	HullScramble.started_log.clear()
	await _secs(2.0)
	places["the station"] = LowHull.tier == 1 and LowHull.on > 0.9 and Router.current is StationScreen and HullScramble.started_log.size() > 0
	for k in places:
		_ok("on, and scrambling, at %s" % k, places[k])
	_set_share(0.0)
	await _frames(2)
	_ok("off at 0 hull (the ship's loss has its own picture)", LowHull.tier == 0)
	_set_share(0.2)
	Router.show_launcher()
	await _frames(2)
	_ok("off on the title", LowHull.tier == 0 and not LowHull.in_run())
	await _frames(2)
	_ok("and nothing held there", hs.held() == 0 and HullScramble.cells_now == 0)

	# REDUCED MOTION
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	DisplaySettings.reduced_motion = true
	_set_share(0.05)
	await _secs(LowHull.EASE_S + 0.2)
	HullScramble.started_log.clear()
	var rlo := 9.0
	var rhi := 0.0
	for i in 240:
		await _tree.process_frame
		rlo = minf(rlo, LowHull.red_now)
		rhi = maxf(rhi, LowHull.red_now)
	var want := float(LowHull.look().red[1]) * LowHull.REDUCED_RED
	_ok("reduced motion: the red stands still and faint (%.3f to %.3f, want %.3f)" % [rlo, rhi, want],
		absf(rhi - rlo) < 0.0001 and absf(rhi - want) < 0.001)
	_ok("reduced motion at 5%: no scramble in 4 s", HullScramble.started_log.is_empty() and hs.live().is_empty())
	_ok("reduced motion: her voice keeps the subtle preset", LowHull.voice_look() == LowHull.LOOKS[LowHull.Preset.SUBTLE])
	DisplaySettings.reduced_motion = false

	await _voice()
	await _portrait()
	DisplaySettings.reduced_motion = false
	print("LowHullTest: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	_tree.quit(1 if _fails > 0 else 0)


func _peak(x: PackedVector2Array, s: int, n: int) -> float:
	var p := 0.0
	for i in range(s, mini(x.size(), s + n)):
		p = maxf(p, x[i].length())
	return p


func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += float(x)
	return s / float(a.size())


func _fmt(a: Array) -> String:
	var parts: PackedStringArray = []
	for x in a:
		parts.append("%.2f" % float(x))
	return " ".join(parts)


## A screen's own `_draw`, asking `LowHull.scr` for what to draw.
class Drawer extends Control:
	var said := "HULL BREACH AT FRAME 12 - VENT 4"
	var drawn: Array[String] = []
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var s := LowHull.scr(self, said, UITheme.FS_SMALL)
		drawn.append(s)
		draw_string(UITheme.pixel_font(), Vector2(0, 10), s, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, Color.WHITE)


func _drawn_check() -> void:
	var dr := Drawer.new()
	dr.position = Vector2(300, 300)
	dr.size = Vector2(300, 16)
	Router.current.add_child(dr)
	var real := dr.said
	var hs := LowHull.instance.scramble
	var key := "%d|%s" % [dr.get_instance_id(), real]
	var t0 := GameClock.now()
	var saw := 0
	while GameClock.now() - t0 < 10.0 and saw < 6:
		await _tree.process_frame
		# its letters among the screen's: picked by weight as any text is
		saw = 0
		for s in dr.drawn:
			if s != real:
				saw += 1
		if saw == 0 and hs._elig_ix.has(key) and GameClock.now() - t0 > 4.0:
			# a slow roll: hand it the next scramble, as a pick would
			var row: Array = hs._elig[hs._elig_ix[key]]
			hs._elig = [row]
			hs._elig_ix = {key: 0}
	var f := UITheme.pixel_font()
	var fs := UITheme.FS_SMALL
	var w0 := f.get_string_size(real, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var bad := 0
	var diff := 0
	for s in dr.drawn:
		if s == real:
			continue
		diff += 1
		if s.length() != real.length() or not is_equal_approx(f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, w0):
			bad += 1
			continue
		# every letter where it was: each prefix as wide
		for i in s.length():
			if not is_equal_approx(f.get_string_size(s.left(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x,
					f.get_string_size(real.left(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x):
				bad += 1
				break
	_ok("hand-drawn text: %d of %d draws scrambled, every one as wide as the real string with every letter in its place (%d off)" % [
		diff, dr.drawn.size(), bad], diff > 0 and bad == 0)
	_ok("and the screen's own string is still the real one", dr.said == real)
	dr.queue_free()
	await _frames(2)


func _tooltip_check(top: int) -> void:
	Run.hp = maxi(1, int(roundf(top * 0.10)))
	Sig.resources_changed.emit()
	await _secs(LowHull.EASE_S + 0.3)
	var hud := Router.hud
	var target: Control = hud._hull if hud != null else null
	var tip_nodes := 0
	var tip_hits := 0
	var tip: PopupPanel = null
	if target != null and target.tooltip_text != "":
		tip = TIP.show_tip(target)
		await _secs(0.3)
		var t0 := GameClock.now()
		while GameClock.now() - t0 < 15.0 and tip_hits == 0:
			await _tree.process_frame
			for key: Variant in LowHull.instance.scramble.live():
				var who: Object = LowHull.instance.scramble.live()[key].node
				if who is Control and is_instance_valid(who) and _in_tooltip(who as Control):
					tip_hits += 1
		for n in _tree.root.find_children("*", "Window", true, false):
			if (n as Window).visible and _in_tooltip(n as Node):
				for c in n.find_children("*", "", true, false):
					if HullScramble._is_text(c):
						tip_nodes += 1
	_ok("a tooltip at 10%% (the HUD hull's, in Godot's own TooltipPanel and TooltipLabel): up (%d texts in it), and its words scramble (%d)" % [tip_nodes, tip_hits], tip_nodes > 0 and tip_hits > 0)
	if tip != null:
		tip.queue_free()
	await _frames(4)


func _in_tooltip(c: Node) -> bool:
	var p: Node = c
	while p != null:
		if p is Popup and p != _tree.root:
			return true
		p = p.get_parent()
	return false


# ------------------------------------------------------------------ her voice

func _takes() -> Array:
	var out: Array = []
	var d := DirAccess.open("res://assets/audio/voice/ash")
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".ogg"):
			out.append("res://assets/audio/voice/ash/" + f)
	out.sort()
	return out


func _voice() -> void:
	print("her voice")
	var takes := _takes()
	_ok("her takes are there (%d)" % takes.size(), takes.size() >= 20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bad := ""
	var none_short := 0
	var not_heard_first := 0
	var lens := {}
	for take in takes:
		lens[take] = (load(take) as AudioStream).get_length()
	for p in LowHull.Preset.values():
		var lk: Dictionary = LowHull.LOOKS[p]
		for path in takes:
			var secs: float = lens[path]
			for share in [0.30, 0.2, 0.1, 0.05, 0.01]:
				var plan := LowHull.plan_for(secs, share, lk, rng)
				if plan.is_empty() and secs > 0.9:
					none_short += 1
				if not plan.is_empty() and not (plan[0].kind in [&"repeat", &"chop"]):
					not_heard_first += 1
				var last := -9.0
				var total := 0.0
				for g: Dictionary in plan:
					var cap := float(LowHull.KIND_MOST[g.kind]) + 0.0001
					total += float(g.len)
					if float(g.at) < 0.1 or float(g.at) + float(g.len) > secs - 0.2 or float(g.len) > cap \
							or float(g.at) - last < LowHull.MIN_APART - 0.0001:
						bad = "%s %s %s" % [path.get_file(), g.kind, g.at]
					last = float(g.at) + float(g.len)
				if total > LowHull.MOST_SHARE * (secs - 0.42) + 0.001:
					bad = "%s: %.2f s of %.2f glitched" % [path.get_file(), total, secs]
	_ok("every plan inside her words, every window under its kind's most (a dropout or a stutter %.0f ms at most), apart, under %.0f%% of a line%s" % [
		float(LowHull.KIND_MOST[&"repeat"]) * 1000.0, LowHull.MOST_SHARE * 100.0, (" (" + bad + ")") if bad != "" else ""], bad == "")
	_ok("every line of a second or more gets at least one", none_short == 0)
	_ok("HEARD AT THE LINE: every line's first glitch a stutter or a chop", not_heard_first == 0)
	_ok("none above the line", LowHull.plan_for(3.0, 0.31, LowHull.look(), rng).is_empty())
	# glitches a second of her words, by the hull: the mean over all her takes
	var per_s: Array[float] = []
	var ms_s: Array[float] = []
	for share in [0.30, 0.20, 0.10, 0.05]:
		var n := 0
		var t := 0.0
		var g_ms := 0.0
		for rep in 4:
			for path in takes:
				var secs: float = lens[path]
				var plan := LowHull.plan_for(secs, share, LowHull.look(), rng)
				n += plan.size()
				t += secs
				for g: Dictionary in plan:
					g_ms += float(g.len) * 1000.0
		per_s.append(float(n) / t)
		ms_s.append(g_ms / t)
	var up := true
	for i in 3:
		if not (per_s[i + 1] > per_s[i] and ms_s[i + 1] > ms_s[i]):
			up = false
	_ok("her glitches rise as the hull falls, a second of her voice, 30 -> 20 -> 10 -> 5%%: %s glitches, %s ms glitched" % [
		_fmt(per_s), _fmt(ms_s)], up)

	# AS HEARD: moved onto her words by the worker (`VoiceGlitch.place`), the
	# ones that found no words dropped
	var heard_s: Array[float] = []
	var kept := 0
	var planned := 0
	var pcm := {}
	for path in takes.slice(0, 16):
		pcm[path] = VoiceGlitch.decode(load(path) as AudioStream)
	for share in [0.30, 0.20, 0.10, 0.05]:
		var n := 0
		var t := 0.0
		for path in pcm:
			var d: Dictionary = pcm[path]
			var plan := LowHull.plan_for(float(lens[path]), share, LowHull.look(), rng)
			var placed := VoiceGlitch.place(d.x, d.sr, plan)
			planned += plan.size()
			kept += placed.size()
			n += placed.size()
			t += float(lens[path])
		heard_s.append(float(n) / t)
	# RISING to 10%, then LEVEL: on the strong preset the spacing and the 45% share
	# are full by 10%, and 5%'s glitches are longer, so as many fit or a few fewer
	var up2 := heard_s[1] > heard_s[0] and heard_s[2] > heard_s[1] and heard_s[3] >= heard_s[2] * 0.9
	_ok("as heard (moved onto her words): %s glitches a second of her voice, 30 -> 20 -> 10 -> 5%%; %d of %d planned kept" % [
		_fmt(heard_s), kept, planned], up2 and heard_s[0] >= 0.6 and kept >= planned * 0.75)

	# rendered through Godot's decoder
	var worst_edge := 0.0
	var outside := 0
	var changed := true
	var same_len := true
	var ms := 0.0
	var lk2: Dictionary = LowHull.LOOKS[LowHull.Preset.STRONG]
	var seen_kinds := {}
	for path in takes.slice(0, 10):
		var st := load(path) as AudioStream
		for share in [0.25, 0.05]:
			var t := Time.get_ticks_usec()
			var d := VoiceGlitch.decode(st)
			var x: PackedVector2Array = d.x
			var sr: float = d.sr
			var plan := VoiceGlitch.place(x, sr, LowHull.plan_for(st.get_length(), share, lk2, rng))
			var y := VoiceGlitch.apply(x.duplicate(), sr, plan)
			var wav := VoiceGlitch.to_wav(y, sr)
			ms = maxf(ms, (Time.get_ticks_usec() - t) / 1000.0)
			if wav == null or absf(wav.get_length() - st.get_length()) > 1.5 / sr + 0.0005 or y.size() != x.size():
				same_len = false
			var inside := PackedByteArray()
			inside.resize(x.size())
			for g: Dictionary in plan:
				seen_kinds[g.kind] = true
				var s := int(float(g.at) * sr)
				var n := int(float(g.len) * sr)
				for i in range(s, mini(x.size(), s + n)):
					inside[i] = 1
				var diff := 0.0
				for i in range(s, s + n):
					diff = maxf(diff, (y[i] - x[i]).length())
				if diff < 0.0005 and g.kind != &"gap":
					changed = false
					print("    unchanged: %s %s at %.2f s, %.0f ms (her loudest there %.4f)" % [path.get_file(), g.kind, float(g.at), float(g.len) * 1000.0, _peak(x, s, n)])
				var own := 0.0
				for i in range(s - 200, s + n + 200):
					own = maxf(own, (x[i + 1] - x[i]).length())
				var e := 0.0
				for i in [s - 1, s, s + 1, s + n - 2, s + n - 1, s + n]:
					e = maxf(e, (y[i + 1] - y[i]).length())
				worst_edge = maxf(worst_edge, e / maxf(own, 1e-4))
			for i in x.size():
				if inside[i] == 0 and not y[i].is_equal_approx(x[i]):
					outside += 1
	_ok("rendered, her take keeps its length to the sample", same_len)
	_ok("untouched outside its windows (%d samples differ)" % outside, outside == 0)
	_ok("each window changes what she says (kinds heard: %s)" % str(seen_kinds.keys()), changed and seen_kinds.size() >= 5)
	_ok("no step into or out of a window (worst %.2f x the take's own)" % worst_edge, worst_edge <= 1.05)
	_ok("the worker's whole job (decode, glitch, 16-bit PCM) %.1f ms at worst, inside her power-on (%.2f s)" % [ms, AshPortrait.VOICE_AT],
		ms < AshPortrait.VOICE_AT * 1000.0 * 0.5)


func _portrait() -> void:
	print("her portrait, in step")
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	_set_share(0.2)
	await _secs(1.2)
	var line := ""
	for k in AshLines.MOMENTS:
		for l in AshLines.of(k):
			if AshLines.voice_path(String(l)) != "" and String(l).length() > 40:
				line = String(l)
				break
		if line != "":
			break
	for rm in [false, true]:
		DisplaySettings.reduced_motion = rm
		var p := AshPortrait.new()
		LowHull.instance.get_parent().add_child(p)
		p.say(line, &"hurt")
		var t0 := GameClock.now()
		while p.phase != AshPortrait.Phase.GONE and GameClock.now() - t0 < 14.0:
			await _tree.process_frame
		var plan := Audio.voice_glitches.size()
		if rm:
			_ok("reduced motion: her voice still glitches (%d), the portrait never slips (%d)" % [plan, p.glitch_slips],
				plan > 0 and p.glitch_slips == 0)
		else:
			_ok("her voice glitches (%d) and the portrait slips once for each (%d)" % [plan, p.glitch_slips],
				plan > 0 and p.glitch_slips == plan)
		p.queue_free()
		await _frames(2)
	DisplaySettings.reduced_motion = false

	# MADE OFF THE MAIN THREAD (`Audio.ash_voice_prepare`): the glitched take
	# baked on a worker during her power-on, and her line's start on the main
	# thread costing only the stream made from the bytes
	var path := AshLines.voice_path(line)
	var st := load(path) as AudioStream
	var t_old := Time.get_ticks_usec()
	VoiceGlitch.render(st, LowHull.plan_for(st.get_length(), 0.2, LowHull.look()))
	var old_ms := (Time.get_ticks_usec() - t_old) / 1000.0
	Audio.bake_headless = true
	var p2 := AshPortrait.new()
	LowHull.instance.get_parent().add_child(p2)
	p2.say(line, &"hurt")
	# HEADLESS GAME TIME RUNS FASTER THAN THE WALL: the 0.35 s of her power-on
	# can pass in a few milliseconds here, where in play it is 0.35 s of real
	# time and the worker's 40 ms fits in it many times. So the wall time her
	# power-on would take is given back to the worker before the game moves on
	# (the worker's own time is checked above, against VOICE_AT).
	var wall := Time.get_ticks_msec()
	while int(Audio._prep.get("task", -1)) >= 0 and not WorkerThreadPool.is_task_completed(int(Audio._prep.task)) \
			and Time.get_ticks_msec() - wall < int(AshPortrait.VOICE_AT * 1000.0):
		OS.delay_msec(1)
	var started := false
	var start_ms := 0.0
	var t1 := GameClock.now()
	while p2.phase != AshPortrait.Phase.GONE and GameClock.now() - t1 < 14.0:
		await _tree.process_frame
		if not started and p2.voice_started_at >= 0.0:
			started = true
			start_ms = Audio.voice_start_usec / 1000.0
	var plan2 := Audio.voice_glitches.size()
	_ok("baked on a worker during her power-on: heard glitched (%s), %d glitches, the portrait in step (%d)" % [
		Audio.voice_heard_glitched, plan2, p2.glitch_slips],
		Audio.voice_heard_glitched and plan2 > 0 and p2.glitch_slips == plan2)
	_ok("her line's start costs the main thread %.2f ms (the old way, all of it on the main thread: %.1f ms)" % [start_ms, old_ms],
		start_ms < 2.0)
	p2.queue_free()
	await _frames(2)
	# NOT READY IN TIME: the clean take, nothing planned, no slips, no wait
	Audio.bake_hold = true
	var p3 := AshPortrait.new()
	LowHull.instance.get_parent().add_child(p3)
	p3.say(line, &"hurt")
	var t2 := GameClock.now()
	var start3 := -1.0
	while p3.phase != AshPortrait.Phase.GONE and GameClock.now() - t2 < 14.0:
		await _tree.process_frame
		if start3 < 0.0 and p3.voice_started_at >= 0.0:
			start3 = Audio.voice_start_usec / 1000.0
	_ok("a take not baked in time: the clean take, no glitches, no slips, no wait (%.2f ms)" % start3,
		not Audio.voice_heard_glitched and Audio.voice_glitches.is_empty() and p3.glitch_slips == 0 and start3 < 2.0)
	p3.queue_free()
	Audio.bake_hold = false
	Audio.bake_headless = false
	await _frames(30)
	_ok("its worker reaped once done", Audio._reap.is_empty())
	_set_share(0.9)
	await _frames(2)
	_ok("the hull sound: no glitches planned", LowHull.voice_plan(3.0).is_empty())
