extends Node

## A.S.H. (`Ash`, `AshPortrait`, `AshLines`), on the real screens, headless:
##   godot --headless --fixed-fps 60 --path . -- sheet=AshTest
##
## THE LINES are the thirty Jon and Ashlee kept, character for character
## (`docs/ash_lines.json`), seven moments.
##
## EACH MOMENT FIRES ITS LINE, through the real LOCAL and the real fight: the
## launch; a new hull, once the move is done and not mid-dock; the hull failing
## (on LOCAL and in a fight); over the heat cap in a fight; a big haul (a chit,
## an epic part) and not a small one; the third wreck opened since docking and
## not the second; a doubt on a late jump. Each line said is one of its own
## moment's.
##
## THE RATE LIMITS HOLD: one at a time; COOLDOWN_S of quiet before an ordinary
## line and only BIG_GAP_S before a big one; one line a fight, a second only for
## the hull failing; never started during a card drag; never on the enemy's
## turn; a moment past its wait is dropped.
##
## A CLICK NEVER CUTS HER (Jon, Oct 22: "He also clicked to make her shut up
## when she was giving her quips"; a quip "plays out and ends on its own"): real
## clicks through the viewport on her box and on the picture, a card picked up
## and dragged, a wreck's window opened clear of her: she is still saying it,
## and ends of herself with her power-down.
##
## NOTHING AFTER LOSS: the hull at 0 or the run over, nothing is said whatever is
## waiting, and a line up when the ship goes is gone that frame.
##
## HINTS WIN: with the hints on, she does not start while a hint card is up or a
## hint is settling, a hint coming due while she talks waits for her to end, and
## she speaks after the hint is done.
##
## THE BOX TEST, on every screen she speaks on -- LOCAL fresh in each weight,
## LOCAL with one to six wrecks, LOCAL with an event's subject, a fight against
## every kind alone and in packs of two and three, in each weight -- her box is
## inside the view and clear of a list gathered here, apart from
## `Ash.avoid_rects`, so she cannot pass by agreeing with herself: the HUD, the
## goal line's band, the bar under the view and everything on it, the hand
## panel and every card, pile, gauge and button in it, your hull, its shield's
## oval, its plate, the numbers a hit on it pops (made by the fight's own
## `_pop_at`), every enemy's hull, words, plate, oval and pops, every wreck and
## its name, an event's subject, a hint card. A screen where no spot is clear
## fails: she must have somewhere to stand. Prints which spots were clear where.
##
## THE TALK: the mouth follows the letters, and the face changes 8 to 12 times a
## second while she talks (Jon judges motion per second; the fire ruling), every
## change a held frame at least TICK_S long; she blinks and the hologram slips.
##
## HER VOICE (`AshLines.VOICE`, `Audio.ash_voice`), read off `Audio.tape`, which
## records her takes headless where nothing plays: every voiced line plays its
## own take exactly once, VOICE_AT after she appears (after the chirp) on the
## frame its words start, and the words type for as long as the take within
## 10%; the lines with no take yet are text alone, at once, with nothing taped;
## END TURN, the ship lost and Settings' switch each stop the voice where they
## cut the words (a card picked up and a hint settling no longer cut her);
## switched off, no voice.
##
## HER POWER-DOWN AND NO CLICK AS SHE GOES: a line that ends of itself plays the
## power-on's two blips reversed (`text_blip_rev`), the higher first, the last
## ending on the frame the projection goes and the first CHIRP_GAP before it
## (one blip in reduced motion), and so does one a card dragged or a hint
## coming due let play out; END TURN, the ship lost and Settings play none, and
## a cut during it hushes it. Every take,
## rendered through Godot's own decoder (`AudioStreamPlayback.mix_audio`), stops
## at the end of her last word without a step: the sharpest sample jump within
## 30 ms of it under CLICK_MAX times the jumps round it (the takes as first made
## measured up to 159: ElevenLabs ends a take mid-waveform, and the chain's
## silence after it made the edge a click); the blip and its reverse start and
## end at rest; and every looped room tone under her (`Audio.loop_whole`)
## crosses its seam without a step (they clicked every lap, 17 to 148 times).
##
## NOT PRESSABLE: everything in her ignores the mouse, no button, no hand.
## OFF: under a harness that did not ask, and with Settings' switch off.

var _tree: SceneTree
var _fails := 0
var _checks := 0
var _quiet := false


func _ok(what: String, c: bool) -> bool:
	_checks += 1
	if not c or not _quiet:
		print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	_ok("off under a harness that did not ask", not Ash.enabled())
	Ash.forced = true
	Ash.reload()
	Ash.set_on(true)
	Hints.forced = false
	_lines()
	await _talk()
	await _voice()
	await _exits()
	await _clicks()
	await _moments()
	await _limits()
	await _loss()
	await _hints()
	await _boxes_everywhere()
	await _switch()
	_finish()


# ------------------------------------------------------------------ helpers

func _local(weight: int = HullData.Weight.MEDIUM, wrecks: Array = [], seed_v: int = 4242) -> SectorScreen:
	Rng.forced = seed_v
	Run.start_new_run(&"korvan", weight)
	for m: MapGen.MapNode in Run.map:
		if m.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(m):
			Run.at = m.index
			break
	Run.map[Run.at].visited = true
	SectorScreen._approached_at = Run.at
	for w: Array in wrecks:
		Run.new_wreck(Run.node_at(), DB.enemies[w[0]], int(w[1]))
	Router.show_local()
	await _frames(12)
	_settle()
	return Router.current as SectorScreen


func _fight(weight: int, foe: StringName, more: Array = []) -> SectorScreen:
	var sc := await _local(weight)
	var extras: Array = []
	for x in more:
		extras.append(DB.enemies[x])
	Run.node_at().danger = maxi(Run.node_at().danger, 4)
	Router.start_combat(DB.enemies[foe], extras, false, false)
	await _frames(20)
	_settle()
	return Router.current as SectorScreen


## Nothing waiting, nothing up, the quiet over: the next moment is the only one.
func _settle() -> void:
	Ash.waiting.clear()
	if Ash.portrait != null:
		Ash.portrait.cut()
	# (and no introduction pending or just said, nor its beat: every new run has
	# one, which the moments checked here are not about)
	Ash.mark_intro(true)
	Ash._introducing = false
	Ash.poll(0.0)
	Ash._last_end = -INF


## Poll her a few frames; the line said, or "".
func _said_after(frames: int = 6) -> String:
	var before := Ash.said_log.size()
	for i in frames:
		await _tree.process_frame
	return String(Ash.said_log.back().kind) if Ash.said_log.size() > before else ""


## Whether she said a "hull" line anywhere in her log from entry `from` on.
func _hull_said_since(from: int) -> bool:
	for i in range(from, Ash.said_log.size()):
		if Ash.said_log[i].kind == &"hull":
			return true
	return false


func _kind_of(line: String) -> StringName:
	for k in AshLines.MOMENTS:
		if AshLines.of(k).has(line):
			return k
	return &""


# ------------------------------------------------------------------ the lines

func _lines() -> void:
	print("the lines")
	var path := ProjectSettings.globalize_path("res://").path_join("../docs/ash_lines.json")
	var f := FileAccess.open(path, FileAccess.READ)
	if not _ok("docs/ash_lines.json reads (%s)" % path, f != null):
		return
	var doc: Dictionary = JSON.parse_string(f.get_as_text())
	var same := doc.size() == AshLines.MOMENTS.size()
	var n := 0
	for k in doc:
		var mine: Dictionary = AshLines.MOMENTS.get(StringName(k), {})
		same = same and String(mine.get("moment", "")) == String(doc[k].moment)
		same = same and str(mine.get("lines", [])) == str(doc[k].lines)
		n += (doc[k].lines as Array).size()
	_ok("the game's lines are the approved ones, character for character (%d moments, %d lines)" % [doc.size(), n],
		same and n == 30 and AshLines.count() == 30)
	var long := 0
	for k in AshLines.MOMENTS:
		for l in AshLines.of(k):
			long = maxi(long, AshPortrait.lines_for(String(l)))
	_ok("every line fits her column in four lines or fewer (longest %d)" % long, long <= 4)


# ------------------------------------------------------------------ the talk

func _talk() -> void:
	print("the talk")
	var sc := await _local()
	Router.animate_in_harness = true
	var longest := ""
	for k in AshLines.MOMENTS:
		for l in AshLines.of(k):
			if String(l).length() > longest.length():
				longest = l
	Ash.arm(&"launch")
	await _frames(2)
	var p := Ash.portrait
	if not _ok("she is up on LOCAL at launch", p != null and p.speaking()):
		Router.animate_in_harness = false
		return
	# say the longest line, typed on the game's clock
	p.say(longest, &"launch")
	var t0 := GameClock.now()
	var typed_for := 0.0
	var mouths := {}
	while p.speaking() and GameClock.now() - t0 < 12.0:
		await _tree.process_frame
		mouths[p._mouth] = true
		if p.phase == AshPortrait.Phase.TYPING:
			typed_for = GameClock.now() - t0
	await _frames(40)
	var log: Array = p.frames_log.duplicate()
	# changes a second while typing, and the shortest hold
	var changes := 0
	var shortest := INF
	var last_t := -1.0
	var last_f := -1
	var slips := 0
	var blinks := 0
	for e: Array in log:
		var at: float = e[0]
		if at - t0 > typed_for + 0.0001:
			break
		if last_t >= 0.0:
			changes += 1
			shortest = minf(shortest, at - last_t)
		last_t = at
		if int(e[1]) >= AshPortrait.BLINK:
			blinks += 1
		if bool(e[2]):
			slips += 1
		last_f = int(e[1])
	var all_slips := 0
	var all_blinks := 0
	for e: Array in log:
		all_slips += int(bool(e[2]))
		all_blinks += int(int(e[1]) >= AshPortrait.BLINK)
	var rate := float(changes) / maxf(typed_for, 0.001)
	print("    the longest line (%d letters) typed in %.2f s: %d changes, %.1f a second, shortest hold %.3f s" % [
		longest.length(), typed_for, changes, rate, shortest])
	print("    over the whole line: %d frames with a slip, %d with her eyes shut" % [all_slips, all_blinks])
	_ok("the face changes 8 to 12 times a second while she talks (%.1f)" % rate, rate >= 8.0 and rate <= 12.0)
	# and over every line she has, typed on the same clock
	var lo := INF
	var hi := 0.0
	var lo_line := ""
	var all_n := 0
	var all_t := 0.0
	for kk in AshLines.MOMENTS:
		for l in AshLines.of(kk):
			p.say(String(l), kk)
			var s0 := GameClock.now()
			var n0 := 0
			# (the power-on before her voice, then the words with it)
			while (p.phase == AshPortrait.Phase.UP or p.phase == AshPortrait.Phase.TYPING) \
					and GameClock.now() - s0 < 8.0:
				await _tree.process_frame
			var dur := GameClock.now() - s0
			n0 = p.frames_log.size() - 1
			all_n += n0
			all_t += dur
			var r := float(n0) / maxf(dur, 0.001)
			if String(l).length() < 30:
				continue
			if r < lo:
				lo = r
				lo_line = String(l)
			hi = maxf(hi, r)
			p.cut()
	var mean := float(all_n) / maxf(all_t, 0.001)
	_ok("over all thirty lines typed, %.1f changes a second; every line of 30 letters or more 8 to 12 (%.1f to %.1f; slowest: \"%s\")" % [mean, lo, hi, lo_line],
		mean >= 8.0 and mean <= 12.0 and lo >= 8.0 and hi <= 12.0)
	Ash.portrait.cut()
	Ash.poll(0.0)
	_ok("every change is held a tick (%.3f s) or longer (shortest %.3f)" % [AshPortrait.TICK_S, shortest],
		shortest >= AshPortrait.TICK_S - 0.02)
	_ok("all four mouths are used (%s)" % str(mouths.keys()), mouths.size() == 4)
	_ok("the hologram slips and she blinks over a line (%d, %d)" % [all_slips, all_blinks], all_slips > 0 and all_blinks > 0)
	_ok("the mouth is shut once the line is out (mouth %d)" % p._mouth, p._mouth == AshPortrait.Mouth.CLOSED)
	_ok("the power-on chirps twice (%d)" % p.chirps, p.chirps == 2)
	# the mouth's shapes follow the letters
	_ok("a vowel opens it, o rounds it, m shuts it, t is slight, a space shuts it",
		AshPortrait.shape_for("a") == AshPortrait.Mouth.OPEN and AshPortrait.shape_for("o") == AshPortrait.Mouth.ROUND
		and AshPortrait.shape_for("m") == AshPortrait.Mouth.CLOSED and AshPortrait.shape_for("t") == AshPortrait.Mouth.SLIGHT
		and AshPortrait.shape_for(" ") == AshPortrait.Mouth.CLOSED)
	_ok("it went on its own after holding (%s)" % AshPortrait.Phase.keys()[p.phase], p.phase == AshPortrait.Phase.GONE)
	# NOT PRESSABLE
	var bad: Array[String] = []
	var all: Array = [p]
	all.append_array(p.find_children("*", "", true, false))
	for n in all:
		var c := n as Control
		if c != null and (c.mouse_filter != Control.MOUSE_FILTER_IGNORE or c is BaseButton
				or c.mouse_default_cursor_shape != Control.CURSOR_ARROW or c.focus_mode != Control.FOCUS_NONE):
			bad.append(String(c.name))
	_ok("not pressable: ignores the mouse, no button, no hand, no focus (%s)" % ("all of it" if bad.is_empty() else ", ".join(bad)),
		bad.is_empty())
	_ok("drawn at a whole pixel (%s)" % p.position, p.position == p.position.round())
	Router.animate_in_harness = false
	sc = null


# ------------------------------------------------------------------ the voice

## Her rows on the tape (`Audio.taping`: headless plays nothing and tapes all).
func _taped(prefix: String) -> Array:
	var out: Array = []
	for row in Audio.tape:
		if String(row[0]).begins_with(prefix):
			out.append(String(row[0]))
	return out


## Until her voice is sounding, or `limit` frames; whether it is. A line she
## picked that has no take yet is swapped for one of its moment's that has.
func _voice_up(limit: int = 60) -> bool:
	var p := Ash.portrait
	if p != null and p.speaking() and p.voice == "":
		for l in AshLines.of(p.kind):
			if AshLines.voice_path(String(l)) != "":
				p.say(String(l), p.kind)
				break
	for i in limit:
		if Audio.voice_now != "":
			return true
		await _tree.process_frame
	return Audio.voice_now != ""


func _voice() -> void:
	print("her voice")
	# THE TABLE: an entry for every line, and every take it names loads, one-shot
	var missing: Array[String] = []
	var voiced := 0
	for k in AshLines.MOMENTS:
		for l in AshLines.of(k):
			var id := AshLines.id_of(String(l))
			if not AshLines.VOICE.has(id):
				missing.append("%s has no entry" % id)
				continue
			var path := AshLines.voice_path(String(l))
			if path == "":
				continue
			voiced += 1
			var s: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
			if s == null or s.get_length() <= 0.0:
				missing.append(path)
			elif s is AudioStreamOggVorbis and (s as AudioStreamOggVorbis).loop:
				missing.append("%s loops" % path)
	_ok("every line has a voice entry; the %d takes named all load, none looping (%s)" % [
		voiced, "all" if missing.is_empty() else ", ".join(missing)],
		missing.is_empty() and AshLines.VOICE.size() == AshLines.count() and voiced > 0)

	# EVERY LINE SAID: its take once, as the words start, after the chirp; the
	# words as long as the take
	var sc := await _local()
	Router.animate_in_harness = true
	Ash.arm(&"launch")
	await _frames(2)
	var p := Ash.portrait
	if not _ok("she is up to speak", p != null and p.speaking()):
		Router.animate_in_harness = false
		return
	Audio.taping = true
	var once_bad: Array[String] = []
	var when_bad: Array[String] = []
	var len_bad: Array[String] = []
	var pend_bad: Array[String] = []
	var pend_ok: Array[String] = []
	var worst := 0.0
	var worst_line := ""
	var mean_gap := 0.0
	var timed := 0
	var frame := 1.0 / 60.0
	for k in AshLines.MOMENTS:
		for l in AshLines.of(k):
			var line := String(l)
			var id := String(AshLines.id_of(line))
			Audio.tape.clear()
			p.say(line, k)
			var born := GameClock.now()
			var first_at := -1.0
			while (p.speaking() and p.phase != AshPortrait.Phase.HOLDING or Audio.ash_speaking()) \
					and GameClock.now() - born < 8.0:
				await _tree.process_frame
				if first_at < 0.0 and not _taped("ash/").is_empty():
					first_at = GameClock.now()
			var rows := _taped("ash/")
			if p.voice == "":
				# NO TAKE YET: the words at once at the text's own speed, nothing taped
				var at_once := p.typed_at >= 0.0 and absf(p.typed_at - born) < 0.001
				if rows.is_empty() and at_once and p.voice_secs == 0.0 and p.typed_for > 0.0:
					pend_ok.append(id)
				else:
					pend_bad.append("%s (taped %s, typed at %+.2f)" % [id, str(rows), p.typed_at - born])
				continue
			if rows.count("ash/" + id) != 1 or rows.size() != 1:
				once_bad.append("%s %s" % [id, str(rows)])
			# it starts after the chirp, on the frame the words start
			if absf(first_at - (born + AshPortrait.VOICE_AT)) > frame + 0.001 \
					or absf(p.voice_started_at - first_at) > frame + 0.001 \
					or absf(p.typed_at - p.voice_started_at) > 0.001:
				when_bad.append("%s (voice %+.3f, words %+.3f)" % [id, first_at - born, p.typed_at - born])
			# against what she SAYS: the take less the silence trimmed after her
			# last word (the words would end with the file, not the word)
			var said := p.voice_secs - AshPortrait.VOICE_TAIL_S
			var off := absf(p.typed_for - said) / maxf(said, 0.001)
			mean_gap += p.voice_secs - p.typed_for
			timed += 1
			if off > worst:
				worst = off
				worst_line = "%s: typed %.2f s, said %.2f s of a %.2f s take" % [id, p.typed_for, said, p.voice_secs]
			if off > 0.10:
				len_bad.append("%s %.0f%%" % [id, off * 100.0])
	print("    the words end %.2f s before the take on average (its tail is %.2f s); worst %.1f%% (%s)" % [
		mean_gap / maxf(timed, 1), AshPortrait.VOICE_TAIL_S, worst * 100.0, worst_line])
	_ok("each voiced line plays its file exactly once (%d lines; %s)" % [timed,
		"all" if once_bad.is_empty() else ", ".join(once_bad)], timed == voiced and once_bad.is_empty())
	_ok("each starts %.2f s after she appears, after the chirp, with the words (%s)" % [AshPortrait.VOICE_AT,
		"all" if when_bad.is_empty() else ", ".join(when_bad)], timed == voiced and when_bad.is_empty())
	_ok("the typing takes as long as she speaks, within 10%% (worst %.1f%%%s)" % [worst * 100.0,
		"" if len_bad.is_empty() else "; " + ", ".join(len_bad)], timed == voiced and len_bad.is_empty())
	_ok("the lines with no take yet are text alone, at once, without errors (%s%s)" % [", ".join(pend_ok),
		"" if pend_bad.is_empty() else "; BAD " + ", ".join(pend_bad)],
		pend_bad.is_empty() and pend_ok.size() == AshLines.count() - voiced)
	p.cut()
	Router.animate_in_harness = false

	# A CUT STOPS HER VOICE, wherever her words are cut or sent off
	var cuts: Array[String] = []
	var bad: Array[String] = []
	# END TURN, in a fight
	sc = await _fight(HullData.Weight.MEDIUM, &"cutter")
	Run.heat = Run.heat_cap() + 2
	await _said_after()
	if await _voice_up():
		Audio.tape.clear()
		sc._on_end_turn()
		Ash.poll(0.0)
		(cuts if Audio.voice_now == "" and _taped("ash/stop").size() == 1 else bad).append("END TURN")
	else:
		bad.append("END TURN (never spoke)")
	Run.heat = 0
	await _frames(30)
	# A CARD DRAGGED AND A HINT COMING DUE NO LONGER CUT HER (Jon, Oct 22): her
	# voice goes on
	var kept: Array[String] = []
	sc = await _fight(HullData.Weight.MEDIUM, &"cutter")
	Run.heat = Run.heat_cap() + 2
	await _said_after()
	if await _voice_up():
		Audio.tape.clear()
		sc._grab_view = sc._hand._views[0] if sc._hand._views.size() > 0 else null
		sc._grab_mode = 2
		Ash.poll(0.0)
		await _frames(3)
		(kept if Audio.voice_now != "" and _taped("ash/stop").is_empty() else bad).append("a drag")
		sc._grab_view = null
		sc._grab_mode = 0
	else:
		bad.append("a drag (never spoke)")
	Run.heat = 0
	sc = await _local()
	Ash.arm(&"launch")
	await _said_after()
	if await _voice_up():
		Audio.tape.clear()
		Hints._cand = &"wreck"
		Ash.poll(0.0)
		await _frames(3)
		Hints._cand = &""
		(kept if Audio.voice_now != "" and _taped("ash/stop").is_empty() else bad).append("a hint coming due")
	else:
		bad.append("a hint (never spoke)")
	# the ship lost
	sc = await _local()
	Ash.arm(&"launch")
	await _said_after()
	if await _voice_up():
		Audio.tape.clear()
		Run.hp = 0
		Ash.poll(0.0)
		(cuts if Audio.voice_now == "" and _taped("ash/stop").size() == 1 else bad).append("the ship lost")
	else:
		bad.append("the ship lost (never spoke)")
	Run.hp = Run.max_hp()
	# Settings' switch turned off mid-line
	sc = await _local()
	Ash.arm(&"launch")
	await _said_after()
	if await _voice_up():
		Audio.tape.clear()
		Ash.set_on(false)
		Ash.poll(0.0)
		(cuts if Audio.voice_now == "" and _taped("ash/stop").size() == 1 else bad).append("Settings off")
	else:
		bad.append("Settings off (never spoke)")
	_ok("a cut stops her voice, faded over %d ms (%s; and goes on through %s%s)" % [Audio.VOICE_CUT_MS, ", ".join(cuts),
		", ".join(kept), "" if bad.is_empty() else "; NOT " + ", ".join(bad)], bad.is_empty() and cuts.size() == 3 and kept.size() == 2)
	# SETTINGS OFF: no voice at all
	Audio.tape.clear()
	sc = await _local()
	Ash.arm(&"launch")
	await _frames(40)
	_ok("Settings off: no voice (taped %s)" % str(_taped("ash/")), _taped("ash/").is_empty() and Audio.voice_now == "")
	Ash.set_on(true)
	Audio.taping = false
	Audio.tape.clear()


# ------------------------------------------------------------------ the exits

## A take's sharpest step: the largest second difference within 30 ms of where
## her last word ends (the last 5 ms block within 40 dB of the loudest), against
## the 95th centile of those 4 to 50 ms round it.
const CLICK_MAX := 4.0
## A room tone's seam: its sharpest sample step across the wrap, against its
## typical step just before (the files' own seams measure 2 to 4.4).
const ROOM_SEAM_MAX := 6.0


static func _render(path: String) -> Dictionary:
	var st := load(path) as AudioStream
	var pb := st.instantiate_playback()
	pb.start(0.0)
	var x := PackedFloat32Array()
	while pb.is_playing() and x.size() < 44100 * 12:
		for v: Vector2 in pb.mix_audio(1.0, 4096):
			x.append((v.x + v.y) * 0.5)
	return {x = x, sr = float(x.size()) / maxf(st.get_length(), 0.001)}


static func _d2(x: PackedFloat32Array, i: int) -> float:
	return absf(x[i + 1] - 2.0 * x[i] + x[i - 1])


static func word_end_step(path: String) -> float:
	var r := _render(path)
	var x: PackedFloat32Array = r.x
	var sr: float = r.sr
	var w := int(0.005 * sr)
	var n := x.size() / w
	var e := PackedFloat32Array()
	var top := 0.0
	for b in n:
		var acc := 0.0
		for i in range(b * w, b * w + w):
			acc += x[i] * x[i]
		e.append(sqrt(acc / w))
		top = maxf(top, e[b])
	var last := 0
	for b in n:
		if e[b] > top * 0.01:
			last = b
	var end := (last + 1) * w
	var a := maxi(1, end - int(0.03 * sr))
	var z := mini(x.size() - 2, end + int(0.03 * sr))
	var j := a
	for i in range(a, z):
		if _d2(x, i) > _d2(x, j):
			j = i
	var near: Array[float] = []
	for i in range(maxi(1, j - int(0.05 * sr)), j - int(0.004 * sr)):
		near.append(_d2(x, i))
	for i in range(j + int(0.004 * sr), mini(x.size() - 2, j + int(0.05 * sr))):
		near.append(_d2(x, i))
	near.sort()
	var p95: float = near[int(near.size() * 0.95)] if not near.is_empty() else 0.0
	return _d2(x, j) / maxf(p95, 1e-9)


## Until she has gone, or `limit` s; the game second she went.
func _until_gone(p: AshPortrait, limit: float = 14.0) -> float:
	while p.phase != AshPortrait.Phase.GONE and GameClock.now() - p._born < limit:
		await _tree.process_frame
	return GameClock.now()


func _exits() -> void:
	print("her power-down, and no click as she goes")
	var b := AshPortrait.blip_secs()
	var frame := 1.0 / 60.0
	# A NATURAL END, animated: both blips, in mirror order and time
	var sc := await _local()
	Router.animate_in_harness = true
	Ash.arm(&"launch")
	await _frames(2)
	var p := Ash.portrait
	var gone_at := await _until_gone(p)
	var log: Array = p.rev_log.duplicate()
	var want := [gone_at - AshPortrait.CHIRP_GAP - b / AshPortrait.CHIRP_UP, gone_at - b]
	var ok_order := log.size() == 2 and is_equal_approx(float(log[0][1]), AshPortrait.CHIRP_UP) \
		and is_equal_approx(float(log[1][1]), 1.0)
	var off := 0.0
	var seen: Array[String] = []
	for i in log.size():
		seen.append("%.2f at %+.3f s" % [float(log[i][1]), float(log[i][0]) - gone_at])
		if i < 2:
			off = maxf(off, absf(float(log[i][0]) - float(want[i])))
	_ok("a line that ends of itself powers down: the two blips reversed, the higher first, the last ending as she goes (%s; %.3f s off)" % [
		", ".join(seen), off], ok_order and off <= frame + 0.001 and not p.rev_hushed)
	_ok("the power-on still chirps twice, now at the text's level (%d, %+.0f dB)" % [p.chirps, AshPortrait.CHIRP_DB],
		p.chirps == 2 and AshPortrait.CHIRP_DB == 0.0)
	Router.animate_in_harness = false
	# reduced motion: one blip, the lower, ending as she goes
	sc = await _local()
	Ash.arm(&"launch")
	await _frames(2)
	p = Ash.portrait
	gone_at = await _until_gone(p)
	_ok("reduced motion: one blip reversed, ending as she goes (%s)" % str(p.rev_log),
		p.rev_log.size() == 1 and is_equal_approx(float(p.rev_log[0][1]), 1.0)
		and absf(float(p.rev_log[0][0]) - (gone_at - b)) <= frame + 0.001)
	# THE OTHER EXITS: none
	var none: Array[String] = []
	var some: Array[String] = []
	sc = await _fight(HullData.Weight.MEDIUM, &"cutter")
	Run.heat = Run.heat_cap() + 2
	await _said_after()
	await _voice_up()
	sc._on_end_turn()
	Ash.poll(0.0)
	await _frames(40)
	(none if Ash.portrait.rev_log.is_empty() else some).append("END TURN")
	Run.heat = 0
	await _frames(30)
	# A CARD DRAGGED, A HINT COMING DUE: she plays out, and powers down of herself
	var played: Array[String] = []
	var cut_short: Array[String] = []
	sc = await _fight(HullData.Weight.MEDIUM, &"cutter")
	Run.heat = Run.heat_cap() + 2
	await _said_after()
	await _voice_up()
	sc._grab_view = sc._hand._views[0] if sc._hand._views.size() > 0 else null
	sc._grab_mode = 2
	p = Ash.portrait
	await _until_gone(p)
	(played if p._natural and not p.rev_log.is_empty() else cut_short).append("a drag")
	sc._grab_view = null
	sc._grab_mode = 0
	Run.heat = 0
	sc = await _local()
	Ash.arm(&"launch")
	await _said_after()
	await _voice_up()
	Hints._cand = &"wreck"
	p = Ash.portrait
	await _until_gone(p)
	Hints._cand = &""
	(played if p._natural and not p.rev_log.is_empty() else cut_short).append("a hint coming due")
	_ok("through a drag and a hint coming due she plays out and powers down of herself (%s%s)" % [", ".join(played),
		"" if cut_short.is_empty() else "; CUT: " + ", ".join(cut_short)], cut_short.is_empty() and played.size() == 2)
	sc = await _local()
	Ash.arm(&"launch")
	await _said_after()
	await _voice_up()
	Run.hp = 0
	await _frames(40)
	(none if Ash.portrait.rev_log.is_empty() else some).append("the ship lost")
	Run.hp = Run.max_hp()
	sc = await _local()
	Ash.arm(&"launch")
	await _said_after()
	await _voice_up()
	Ash.set_on(false)
	await _frames(40)
	(none if Ash.portrait.rev_log.is_empty() else some).append("Settings off")
	Ash.set_on(true)
	_ok("no power-down when she is sent off (%s%s)" % [", ".join(none), "" if some.is_empty() else "; BUT " + ", ".join(some)],
		some.is_empty() and none.size() == 3)
	# the ship lost DURING the power-down: hushed, she goes with the ship
	sc = await _local()
	Router.animate_in_harness = true
	Ash.arm(&"launch")
	await _frames(2)
	p = Ash.portrait
	while p.rev_log.is_empty() and p.speaking() and GameClock.now() - p._born < 14.0:
		await _tree.process_frame
	var started := not p.rev_log.is_empty()
	Run.hp = 0
	Ash.poll(0.0)
	await _frames(20)
	_ok("the ship lost during the power-down hushes it (started %s, hushed %s, %d blip)" % [started, p.rev_hushed, p.rev_log.size()],
		started and p.rev_hushed and p.rev_log.size() == 1)
	Run.hp = Run.max_hp()
	Router.animate_in_harness = false
	# NO CLICK: every take ends her last word without a step, through Godot's decoder
	var worst := 0.0
	var worst_id := ""
	var bad: Array[String] = []
	for k in AshLines.MOMENTS:
		for l in AshLines.of(k):
			var path := AshLines.voice_path(String(l))
			if path == "":
				continue
			var r := word_end_step(path)
			if r > worst:
				worst = r
				worst_id = path.get_file()
			if r > CLICK_MAX:
				bad.append("%s %.1f" % [path.get_file(), r])
	_ok("every take ends her last word without a click: its sharpest step under %.0f x the jumps round it (worst %.1f, %s%s)" % [
		CLICK_MAX, worst, worst_id, "" if bad.is_empty() else "; " + ", ".join(bad)], bad.is_empty() and worst > 0.0)
	var edges: Array[String] = []
	var rough := false
	for nm in [AshPortrait.CHIRP, AshPortrait.CHIRP_REV]:
		var x: PackedFloat32Array = _render(Audio.SFX_PATH % nm).x
		var head := absf(x[0])
		var tail := absf(x[x.size() - 1])
		edges.append("%s %.4f / %.4f" % [nm, head, tail])
		rough = rough or head > 0.01 or tail > 0.01
	_ok("the blip and its reverse start and end at rest (%s)" % ", ".join(edges), not rough)
	_ok("every stop of hers is faded: the voice and the power-down over %d ms" % Audio.VOICE_CUT_MS, Audio.VOICE_CUT_MS >= 30)
	# AND THE ROOM UNDER HER: every looped room tone (`Audio.loop_whole`) crosses
	# its seam without a step, rendered across the wrap
	var rooms: Array[String] = []
	var loud: Array[String] = []
	var dir := DirAccess.open("res://assets/audio/ambience")
	for f in dir.get_files():
		if not f.ends_with(".wav"):
			continue
		var w := (load("res://assets/audio/ambience/" + f) as AudioStreamWAV).duplicate() as AudioStreamWAV
		Audio.loop_whole(w)
		var sr := float(w.mix_rate)
		var pb := w.instantiate_playback()
		var lead := 0.05
		pb.start(float(w.loop_end) / sr - lead)
		var x := PackedFloat32Array()
		while x.size() < int(sr * lead * 2.0):
			for v: Vector2 in pb.mix_audio(1.0, 1024):
				x.append(v.x)
		var c := int(sr * lead)
		var step := 0.0
		for i in range(c - 40, c + 40):
			step = maxf(step, absf(x[i + 1] - x[i]))
		var typ := 0.0
		for i in range(c - 1200, c - 200):
			typ += absf(x[i + 1] - x[i])
		var r := step / maxf(typ / 1000.0, 1e-9)
		rooms.append("%s %.1f" % [f.get_basename(), r])
		if r > ROOM_SEAM_MAX:
			loud.append(f.get_basename())
	_ok("every looped room crosses its seam without a click: under %.0f x its typical step (%s)" % [ROOM_SEAM_MAX, ", ".join(rooms)],
		loud.is_empty() and rooms.size() >= 10)


# ------------------------------------------------------------------ the moments

func _moments() -> void:
	print("each moment fires its line")
	# LAUNCH
	var sc := await _local()
	Ash.arm(&"launch")
	var k := await _said_after()
	_ok("launch: a new run's first launch is said on LOCAL (%s)" % k, k == &"launch"
		and _kind_of(String(Ash.said_log.back().line)) == &"launch")
	# the launch is gone at the first jump
	_settle()
	Ash._on_run_started()
	Run.jumps = 1
	k = await _said_after()
	_ok("launch: not after the first jump (%s)" % k, k == &"")
	Run.jumps = 0
	# HER INTRODUCTION, EVERY NEW RUN (Jon, Oct 20): two new runs in a row each
	# open with launch_04; a later launch in the same run is the bag's; a run
	# picked up with CONTINUE has none due
	var intro := String(AshLines.of(&"launch")[3])
	var opens: Array[String] = []
	for i in 2:
		_settle()
		Ash._on_run_started()
		k = await _said_after()
		opens.append(String(Ash.said_log.back().line) if k == &"launch" else "")
	_ok("launch: every new run opens with her introduction (%s)" % " / ".join(opens),
		opens.size() == 2 and opens[0] == intro and opens[1] == intro)
	var later := {}
	for i in 8:
		_settle()
		Ash.arm(&"launch")
		k = await _said_after()
		if k == &"launch":
			later[String(Ash.said_log.back().line)] = true
	_ok("launch: later in the same run, from the bag, not the intro forced (%d different lines)" % later.size(), later.size() >= 2)
	_settle()
	SaveGame.restoring = true
	Ash._on_run_started()
	SaveGame.restoring = false
	_ok("launch: a run picked up with CONTINUE has no intro due", Ash.intro_said())
	_settle()
	Ash._on_run_started()
	_settle()

	# HULL: ONLY A HULL BOUGHT MID-RUN (Jon, Oct 18: "New body..." only "when a
	# player buys a new ship mid run"). Not the chassis select's picks before
	# launch -- it fits a hull per click, and the first LOCAL heard "New body"
	# on every new run --, not a resume, not a hull found in the field.
	Rng.forced = 4242
	var said0 := Ash.said_log.size()
	Run.start_new_run(&"korvan", HullData.Weight.MEDIUM)
	_settle()
	Run.fit_chassis(&"korvan", HullData.Weight.LIGHT)
	Ash.poll(0.0)
	Run.fit_chassis(&"korvan", HullData.Weight.HEAVY)
	Ash.poll(0.0)
	for m: MapGen.MapNode in Run.map:
		if m.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(m):
			Run.at = m.index
			break
	SectorScreen._approached_at = Run.at
	Router.show_local()
	await _frames(12)
	k = await _said_after()
	_ok("hull: a new run's hull pick is not a new body (%s; waiting %s)" % [k, Ash.waiting.keys()],
		not _hull_said_since(said0) and not Ash.waiting.has(&"hull"))
	sc = await _local()
	said0 = Ash.said_log.size()
	SaveGame.save()
	_settle()
	Run.hull = null
	SaveGame.load_into_run()
	Router.resume_here()
	await _frames(12)
	k = await _said_after()
	_ok("hull: a resumed run is not a new body (%s; waiting %s)" % [k, Ash.waiting.keys()],
		not _hull_said_since(said0) and not Ash.waiting.has(&"hull"))
	SaveGame.clear()
	sc = await _local()
	said0 = Ash.said_log.size()
	Run.transfer_to_hull(DB.hull_for(&"korvan", HullData.Weight.LIGHT).duplicate() as HullData)
	Run.old_hull = null
	await _frames(4)
	k = await _said_after()
	_ok("hull: a hull found in the field and flown is not one bought (%s)" % k,
		not _hull_said_since(said0) and not Ash.waiting.has(&"hull"))
	# bought at a dock, the move called off; then one bought for good
	sc = await _local()
	var h := DB.hull_for(&"korvan", HullData.Weight.HEAVY).duplicate() as HullData
	Router.show_station()
	await _frames(10)
	Run.transfer_to_hull(h, 0, Run.node_at())
	await _frames(4)
	Run.abandon_move()
	Router.show_local()
	await _frames(12)
	k = await _said_after()
	_ok("hull: a move called off at the dock says nothing (%s)" % k, k == &"")
	Router.show_station()
	await _frames(10)
	Run.transfer_to_hull(h, 0, Run.node_at())
	await _frames(4)
	_ok("hull: nothing on the dock's own screens (%s)" % Ash.held_by, Ash.said_log.back().kind != &"hull")
	Run.old_hull = null
	Router.show_local()
	await _frames(12)
	k = String(Ash.said_log.back().kind)
	_ok("hull: the new hull, the first time she is up in it (%s)" % k, k == "hull")

	# HURT on LOCAL
	sc = await _local()
	Run.hp = maxi(1, int(Run.max_hp() * 0.2))
	k = await _said_after()
	_ok("hurt: a quarter of the hull or less, on LOCAL (%s)" % k, k == &"hurt")
	_settle()
	k = await _said_after()
	_ok("hurt: not again while it stays low (%s)" % k, k == &"")
	Run.hp = Run.max_hp()
	await _said_after(2)
	Run.hp = maxi(1, int(Run.max_hp() * 0.2))
	k = await _said_after()
	_ok("hurt: again once it has been back over half (%s)" % k, k == &"hurt")

	# HOT, in a fight
	sc = await _fight(HullData.Weight.MEDIUM, &"cutter")
	Run.heat = Run.heat_cap() + 2
	k = await _said_after()
	_ok("hot: over the heat cap in a fight (%s)" % k, k == &"hot")
	Run.heat = 0
	# HURT, in a fight
	sc = await _fight(HullData.Weight.MEDIUM, &"cutter")
	Run.hp = maxi(1, int(Run.max_hp() * 0.2))
	k = await _said_after()
	_ok("hurt: in a fight (%s)" % k, k == &"hurt")
	Run.hp = Run.max_hp()

	# HAUL
	sc = await _local()
	Run.stow(CreditChit.of(20))
	k = await _said_after()
	_ok("haul: a small chit is not a big haul (%s)" % k, k == &"")
	Run.stow(CreditChit.of(Ash.HAUL_CREDITS + 10))
	k = await _said_after()
	_ok("haul: a chit of %d is (%s)" % [Ash.HAUL_CREDITS + 10, k], k == &"haul")
	_settle()
	var m := (DB.modules.values()[0] as ModuleData).duplicate() as ModuleData
	m.rarity = ModuleData.Rarity.EPIC
	m.size = Vector2i.ONE
	Run.stow(m)
	k = await _said_after()
	_ok("haul: an epic part taken aboard (%s)" % k, k == &"haul")

	# GREED: the third wreck opened since docking
	sc = await _local(HullData.Weight.MEDIUM, [[&"cutter", 0], [&"lancer", 0], [&"marauder", 0], [&"cutter", 1]])
	var wrecks := Run.wrecks_here(Run.node_at())
	var said_at := []
	for i in 4:
		(wrecks[i] as MapGen.Jetsam).opened = true
		k = await _said_after()
		said_at.append(k)
		_settle()
	_ok("greed: said at the third wreck opened and not the first, second or fourth (%s)" % str(said_at),
		str(said_at) == str(["", "", "greed", ""]))

	# DOUBT: late in a run, a while after the last
	sc = await _local()
	Run.jumps = Ash.DOUBT_FROM + 4
	var got := false
	for i in 200:
		Ash._jumps_since_doubt = Ash.DOUBT_EVERY
		Ash._on_jumped(Run.at)
		if Ash.waiting.has(&"doubt"):
			got = true
			break
	k = await _said_after()
	_ok("doubt: a late jump can bring one (%s)" % k, got and k == &"doubt")
	Ash.waiting.clear()
	Run.jumps = 2
	Ash._jumps_since_doubt = 99
	var early := false
	for i in 200:
		Ash._on_jumped(Run.at)
		early = early or Ash.waiting.has(&"doubt")
	_ok("doubt: never before jump %d" % Ash.DOUBT_FROM, not early)
	Run.jumps = 0


# ------------------------------------------------------------------ a click

## A REAL CLICK, as a hand makes it: through the viewport (`push_input`), so
## every input handler in the game sees it.
func _push_click(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	get_viewport().push_input(mm, true)
	for down: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		get_viewport().push_input(ev, true)


## A CLICK NEVER CUTS HER (Jon, Oct 22: "He also clicked to make her shut up
## when she was giving her quips"; a quip "plays out and ends on its own"). On
## LOCAL, real clicks on her box (where a player clicks to send her away); in a
## fight a card pressed and let go, and a card pressed and dragged out to aim;
## on LOCAL a wreck's window opened while she talks (she stays if it is clear
## of her box, as it is in her corner). Each time she is still saying it, and
## it ends of itself with her power-down.
func _clicks() -> void:
	print("a click never cuts her")
	var played: Array[String] = []
	var cut: Array[String] = []
	# CLICKS ON HER BOX, on LOCAL
	var sc := await _local()
	Ash.arm(&"launch")
	await _said_after()
	var p := Ash.portrait
	if p != null and p.speaking():
		var r := p.rect()
		for at: Vector2 in [r.get_center(), r.position + Vector2(4, 4), r.end - Vector2(4, 4), r.position + Vector2(r.size.x * 0.7, 10)]:
			_push_click(at)
			await _tree.process_frame
		var still := p.speaking() and p.kind == &"launch"
		await _until_gone(p)
		(played if still and p._natural else cut).append("four clicks on her box")
	else:
		cut.append("clicks (never spoke)")
	# A CARD PRESSED AND LET GO, AND A CARD DRAGGED OUT TO AIM, in a fight
	sc = await _fight(HullData.Weight.MEDIUM, &"cutter")
	Run.heat = Run.heat_cap() + 2
	await _said_after()
	p = Ash.portrait
	var v: CardView = sc._hand._views[0] if sc._hand._views.size() > 0 else null
	if p != null and p.speaking() and v != null:
		var at := v.get_global_rect().get_center()
		sc._on_card_grabbed(v, at)
		await _frames(3)
		var held := p.speaking()
		sc._end_reorder(false)
		sc._on_card_grabbed(v, at)
		sc._grab_decide(Vector2(at.x, sc._hand.get_global_rect().position.y - 120.0))
		await _frames(3)
		var dragged := p.speaking() and (sc._aim_view != null or sc._grab_mode != 0)
		sc._end_aim(false)
		await _until_gone(p)
		(played if held and dragged and p._natural else cut).append("a card pressed, and one dragged out to aim (pressed %s, dragged %s)" % [held, dragged])
	else:
		cut.append("a card (never spoke)")
	Run.heat = 0
	# A WRECK'S WINDOW OPENED BY ITS CLICK, on LOCAL
	sc = await _local(HullData.Weight.MEDIUM, [[&"cutter", 0]])
	Ash.arm(&"launch")
	await _said_after()
	p = Ash.portrait
	var sl := sc._view.slot(0)
	if p != null and p.speaking() and sl != null and sl.opened.is_valid():
		sl.opened.call()
		await _frames(3)
		var tv: TransferView = sc._transfer
		var covers := tv != null and tv.window_rect().intersects(p.rect())
		var still := p.speaking()
		sc._close_transfer()
		await _until_gone(p)
		if covers:
			(cut if still else played).append("a wreck's window over her box (she goes, as anything covering her)")
		else:
			(played if still and p._natural else cut).append("a wreck's window opened clear of her")
	else:
		cut.append("a wreck's window (never spoke)")
	_ok("a click never cuts a quip: it plays out and powers down of itself (%s%s)" % [", ".join(played),
		"" if cut.is_empty() else "; CUT: " + ", ".join(cut)], cut.is_empty() and played.size() == 3)


# ------------------------------------------------------------------ the limits

func _limits() -> void:
	print("the rate limits")
	var sc := await _local()
	Ash.arm(&"haul")
	var k := await _said_after()
	_ok("a line is up", k == &"haul" and Ash.portrait.speaking())
	Ash.arm(&"launch")
	k = await _said_after()
	_ok("never over herself: a moment while she talks waits (%s)" % k, k == &"" and Ash.waiting.has(&"launch"))
	Ash.portrait.cut()
	k = await _said_after()
	_ok("cooldown: not straight after a line (%s, held by %s)" % [k, Ash.held_by], k == &"" and Ash.held_by == "cooldown")
	Ash.now += Ash.COOLDOWN_S - 2.0
	k = await _said_after()
	_ok("cooldown: not %.0f s after (%s)" % [Ash.COOLDOWN_S - 2.0, k], k == &"")
	Ash.now += 3.0
	k = await _said_after()
	_ok("cooldown: said after %.0f s (%s)" % [Ash.COOLDOWN_S, k], k == &"launch")
	Ash.portrait.cut()
	await _said_after(1)
	Ash.now += Ash.BIG_GAP_S + 0.5
	Run.hp = maxi(1, int(Run.max_hp() * 0.2))
	k = await _said_after()
	_ok("a big moment waits only %.0f s (%s)" % [Ash.BIG_GAP_S, k], k == &"hurt")
	Run.hp = Run.max_hp()
	# a moment past its wait is dropped
	_settle()
	Ash.portrait = Ash.portrait
	Ash._last_end = Ash.now
	Ash.arm(&"haul")
	Ash.now += float(Ash.WAIT_S[&"haul"]) + 1.0
	await _said_after(2)
	_ok("a moment past its wait is dropped", not Ash.waiting.has(&"haul"))

	# ONE LINE A FIGHT, a second only for the hull failing
	sc = await _fight(HullData.Weight.MEDIUM, &"cutter")
	Run.heat = Run.heat_cap() + 2
	k = await _said_after()
	_ok("fight: the first line (%s)" % k, k == &"hot")
	Ash.portrait.cut()
	Run.heat = 0
	await _said_after(1)
	Ash.now += Ash.COOLDOWN_S + 1.0
	Ash.arm(&"doubt")
	k = await _said_after()
	_ok("fight: no second ordinary line in the same fight (%s, held by %s)" % [k, Ash.held_by], k == &"" and Ash.held_by == "fight")
	Ash.waiting.clear()
	Run.hp = maxi(1, int(Run.max_hp() * 0.2))
	k = await _said_after()
	_ok("fight: the hull failing is the one exception (%s)" % k, k == &"hurt")
	Ash.portrait.cut()
	Run.hp = Run.max_hp()

	# NEVER DURING A CARD DRAG, NEVER ON THE ENEMY'S TURN
	sc = await _fight(HullData.Weight.MEDIUM, &"cutter")
	var view: CardView = sc._hand._views[0] if sc._hand._views.size() > 0 else null
	sc._grab_view = view
	Run.heat = Run.heat_cap() + 2
	Ash.arm(&"hot")
	k = await _said_after()
	_ok("drag: not while a card is held (%s, held by %s)" % [k, Ash.held_by], view != null and k == &"" and Ash.held_by == "drag")
	sc._grab_view = null
	k = await _said_after()
	_ok("drag: said once it is let go (%s)" % k, k == &"hot")
	sc._grab_view = view
	sc._grab_mode = 2
	await _said_after(2)
	_ok("drag: a drag starting no longer sends her off: she plays out (%s)" % AshPortrait.Phase.keys()[Ash.portrait.phase],
		Ash.portrait.speaking() and Ash.portrait.kind == &"hot")
	sc._grab_view = null
	sc._grab_mode = 0
	Ash.portrait.cut()
	Run.heat = 0
	sc = await _fight(HullData.Weight.MEDIUM, &"cutter")
	sc._playing = true
	Run.heat = Run.heat_cap() + 2
	Ash.arm(&"hot")
	k = await _said_after()
	_ok("turn: not on the enemy's turn (%s, held by %s)" % [k, Ash.held_by], k == &"" and Ash.held_by == "turn")
	sc._playing = false
	k = await _said_after()
	_ok("turn: said on yours (%s)" % k, k == &"hot")
	# END TURN with the heat over the cap: the burn pops on your hull this turn
	_ok("turn: up before END TURN", Ash.portrait.speaking())
	sc._on_end_turn()
	Ash.poll(0.0)
	_ok("turn: END TURN takes her off that frame, before a number can land (%s, visible %s)" % [
		AshPortrait.Phase.keys()[Ash.portrait.phase], Ash.portrait.visible],
		Ash.portrait.phase == AshPortrait.Phase.GONE and not Ash.portrait.visible)
	await _frames(30)
	Run.heat = 0


# ------------------------------------------------------------------ loss

func _loss() -> void:
	print("nothing after the ship is lost")
	var sc := await _local()
	Run.hp = 0
	Ash.arm(&"hurt")
	Ash.arm(&"launch")
	var k := await _said_after(10)
	_ok("hull at 0: nothing is said (%s)" % k, k == &"")
	Run.hp = Run.max_hp()
	sc = await _local()
	Ash.arm(&"launch")
	k = await _said_after()
	_ok("a line is up", k == &"launch" and Ash.portrait.speaking())
	Run.hp = 0
	Ash.poll(0.0)
	_ok("the ship lost mid-line: she is gone that frame, no fade", not Ash.portrait.visible and not Ash.portrait.speaking())
	Ash.arm(&"hurt")
	k = await _said_after(10)
	_ok("and says nothing after (%s)" % k, k == &"")
	Run.hp = Run.max_hp()
	sc = await _local()
	Run.dead = true
	Ash.arm(&"hurt")
	k = await _said_after(10)
	_ok("the run over: nothing (%s)" % k, k == &"")
	Run.dead = false


# ------------------------------------------------------------------ hints

func _hints() -> void:
	print("hints win")
	Hints.forced = true
	Hints.set_process(false)
	Hints.reset()
	# after the first jump (the first screen of a run is the goal line's), a
	# wreck lying here: the wreck's, the loot's and the ship's hints are due
	var sc := await _local(HullData.Weight.MEDIUM, [[&"cutter", 0]])
	Run.jumps = 1
	Ash.arm(&"haul")
	var press := InputEventMouseButton.new()
	press.pressed = true
	press.button_index = MOUSE_BUTTON_LEFT
	# a new run's LOCAL with every hint unseen: each hint as it comes, clicked
	# away, and her line only once none is up, settling or due here
	# (she says the hints herself now, `Hints.lesson`: Jon's tutorial A; a card
	# only where she has no room. A bark is any line of hers that is not one.)
	var shown: Array[String] = []
	var over := 0
	var said_with_due := false
	var said := false
	for i in 1800:
		Hints.poll(1.0 / 60.0)
		await _tree.process_frame
		var card_up := (Hints.card != null and is_instance_valid(Hints.card)) or Hints.lesson != &""
		var up := Ash.portrait != null and Ash.portrait.visible and Ash.portrait.speaking() \
			and not String(Ash.portrait.kind).begins_with("tut_")
		if card_up and up:
			over += 1
		if card_up and Hints._up_t > 0.5:
			shown.append(String(Hints.card.id) if Hints.card != null else String(Hints.lesson))
			# (its action, stood in for: no click spends it now)
			Hints.spend()
		if up and not said:
			said = true
			for id in Hints.ORDER:
				if not Hints.seen(id) and not Hints.probe(id).is_empty():
					said_with_due = true
			break
	_ok("hints came first on a fresh LOCAL (%s)" % ", ".join(shown), shown.size() > 0)
	_ok("never up with a hint card on screen (%d frames)" % over, over == 0)
	_ok("she speaks once the hints here are done (%s)" % ("up" if said else "no"), said and not said_with_due)
	# A HINT COMING DUE WHILE SHE TALKS WAITS FOR HER (Jon, Oct 22: a quip
	# "plays out and ends on its own"; it used to send her off)
	if said:
		var p := Ash.portrait
		var k := p.kind
		# (your ship's, whose subject is up here: due at once)
		Hints.mark_seen(&"ship", false)
		_ok("a hint is due here while she talks", not Hints.probe(&"ship").is_empty() and p.speaking())
		var under := 0
		var natural := false
		for i in 900:
			Hints.poll(1.0 / 60.0)
			await _tree.process_frame
			if p.speaking() and p.kind == k and Hints.lesson != &"":
				under += 1
			if not p.speaking() or p.kind != k:
				natural = p._natural or p.kind != k
				break
		_ok("a hint coming due while she talks waits: she ends of herself (%s), never under a lesson (%d frames)" % [natural, under],
			natural and under == 0 and not (p.speaking() and p.kind == k))
		var next := false
		for i in 120:
			Hints.poll(1.0 / 60.0)
			await _tree.process_frame
			if Hints.lesson == &"ship" or (Hints.card != null and Hints.card.id == &"ship"):
				next = true
				break
		_ok("then the hint is said", next)
		Hints.spend()
	Run.jumps = 0
	# and in a fight: the hand's hints come before her heat line
	sc = await _fight(HullData.Weight.MEDIUM, &"cutter")
	Run.heat = Run.heat_cap() + 2
	Ash.arm(&"hot")
	await _frames(3)
	_ok("in a fight with hints due, her heat line waits (held by %s)" % Ash.held_by,
		Ash.held_by == "hint" and not Ash.portrait.speaking())
	Run.heat = 0
	Hints.forced = false
	Hints.reset()
	Hints.set_process(true)


# ------------------------------------------------------------------ the box test

## The screens she speaks on: [name, setup Callable].
func _boxes_everywhere() -> void:
	print("the box test")
	var plan: Array = []
	for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
		plan.append(["LOCAL %s" % _wname(w), _local.bind(w, [])])
	var piles := [
		[[&"cutter", 0]],
		[[&"cutter", 0], [&"marauder", 0], [&"lancer", 0]],
		[[&"cutter", 0], [&"marauder", 0], [&"lancer", 0], [&"hulk", 0], [&"sentinel", 0], [&"cutter", 1]],
	]
	for p: Array in piles:
		plan.append(["LOCAL, %d wrecks" % p.size(), _local.bind(HullData.Weight.MEDIUM, p)])
	plan.append(["LOCAL heavy, 6 wrecks", _local.bind(HullData.Weight.HEAVY, piles[2])])
	plan.append(["LOCAL, an event's subject", _subject_local])
	for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
		plan.append(["fight %s v cutter" % _wname(w), _fight.bind(w, &"cutter", [])])
		plan.append(["fight %s v three" % _wname(w), _fight.bind(w, &"cutter", [&"lancer", &"marauder"])])
	for id in DB.enemies.keys():
		plan.append(["fight v %s" % id, _fight.bind(HullData.Weight.MEDIUM, id, [])])
	# PACKS: every pair of the kinds that come in packs, and triples round them
	var kinds: Array = []
	for id in DB.enemies.keys():
		if not (DB.enemies[id] as EnemyTemplate).boss and id != &"hellbender":
			kinds.append(id)
	for i in kinds.size():
		for j in range(i, kinds.size()):
			plan.append(["fight v %s+%s" % [kinds[i], kinds[j]], _fight.bind(HullData.Weight.MEDIUM, kinds[i], [kinds[j]])])
		var t := [kinds[i], kinds[(i + 1) % kinds.size()], kinds[(i + 2) % kinds.size()]]
		for w in [HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
			plan.append(["fight %s v %s" % [_wname(w), "+".join(PackedStringArray(t))], _fight.bind(w, t[0], [t[1], t[2]])])
	var table: Dictionary = {}
	for row: Array in plan:
		var sc: SectorScreen = await (row[1] as Callable).call()
		if sc == null:
			_ok("%s: the screen is up" % row[0], false)
			continue
		await _check_screen(String(row[0]), sc, table)
	print("    where each spot was clear (%s):" % ", ".join(Ash.ALL_SPOTS))
	for s in table:
		print("      %-34s %s" % [s, table[s]])


func _subject_local() -> SectorScreen:
	for s in range(0, 40):
		var sc := await _local(HullData.Weight.MEDIUM, [], 4242 + s)
		var n := Run.node_at()
		OptionTable.ensure(n)
		for i in n.options.size():
			var o := OptionTable.by_id(n.options[i])
			if not o.has("subject") or EncounterDrawer.option_state(n, i).kind != &"open":
				continue
			# its band up, then NOT NOW: the subject as it stands while you are
			# parked at it, the band down
			sc._events.open(i)
			await _frames(20)
			sc._events.not_now()
			await _frames(20)
			_settle()
			if LocalSubject.of(sc._view) != null:
				print("    (the subject of %s, seed %d)" % [n.options[i], 4242 + s])
				return sc
	return null


func _check_screen(name: String, sc: SectorScreen, table: Dictionary) -> void:
	var boxes := _boxes(sc)
	var v := Ash.view_rect(sc)
	var goal := boxes.filter(func(b: Array) -> bool: return b[0] == "the goal line")
	_ok("%s: the goal line is up, and measured (%s)" % [name, goal[0][1] if goal.size() > 0 else "none"], goal.size() == 1)
	# which spots are clear, for the record
	var marks: Array[String] = []
	for s: Dictionary in Ash.survey_boxes(sc):
		var hits := _hits(s.rect, boxes, v)
		marks.append("%s:%s" % [s.name, "ok" if hits.is_empty() else hits[0]])
	table[name] = "  ".join(marks)
	# and the real thing: she speaks, where she chose
	if sc.fighting():
		Ash.arm(&"hot")
		Run.heat = Run.heat_cap() + 1
	else:
		Ash.arm(&"launch")
	var k := await _said_after()
	Run.heat = 0
	if not _ok("%s: she speaks (%s, held by %s)" % [name, k, Ash.held_by], k != ""):
		return
	var r := Ash.portrait.rect()
	var hits := _hits(r, boxes, v)
	_ok("%s: at %s %s, inside the view and clear of everything (%s)" % [name, Ash.said_log.back().spot, r,
		"nothing under her" if hits.is_empty() else ", ".join(hits)], hits.is_empty())
	_ok("%s: under the goal line's band (top %.0f, band ends %.0f)" % [name, r.position.y, Router.hud.get_global_rect().end.y + Ash.GOAL_BAND],
		r.position.y >= Router.hud.get_global_rect().end.y + Ash.GOAL_BAND)
	Ash.portrait.cut()
	Ash.poll(0.0)


func _hits(r: Rect2, boxes: Array, v: Rect2) -> Array[String]:
	var out: Array[String] = []
	if not v.grow(0.5).encloses(r):
		out.append("outside the view %s" % v)
	for b: Array in boxes:
		var x: Rect2 = b[1]
		if x.size.x > 0.0 and x.size.y > 0.0 and r.intersects(x):
			out.append("%s %s" % [b[0], x])
	return out


## THE STEP'S LINE under the goal (`GoalLine`, Jon, Oct 20), gathered here: as
## drawn while a step is pending, and where it stands when one is (the longest
## step's words under the goal), so a step coming up never lands on her. In a
## fight no step shows (its tabs are locked), so it has no place there: held to
## that here too.
func _step_boxes(goal: Control, fight: bool = false) -> Array:
	var out: Array = []
	if goal == null or not goal.visible or goal.modulate.a <= 0.0:
		return out
	var g := Rect2(goal.global_position, goal.size)
	for pc in goal.find_children("*", "PanelContainer", false, false):
		var p := pc as Control
		if p.visible and p.get_global_rect() != g:
			out.append(["the step's line", p.get_global_rect()])
	var w := UITheme.pixel_font().get_string_size("Open STARCHART. Pick a star in range, then JUMP.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x + 10.0
	if not fight:
		out.append(["the step's place", Rect2(g.position.x, g.end.y + 1.0, w, g.size.y)])
	elif not out.is_empty():
		_ok("in a fight, no step's line under the goal (%s)" % out[0][1], false)
	return out


## Everything she must not cover, [what, global rect], gathered here.
func _boxes(sc: SectorScreen) -> Array:
	var hud := Router.hud.get_global_rect()
	var out: Array = [["HUD", hud], ["goal line's band", Rect2(hud.position.x, hud.end.y, hud.size.x, 26.0)]]
	var goal := Router.hud.get_parent().get_node_or_null("GoalLine") as Control
	if goal != null and goal.visible and goal.modulate.a > 0.0:
		out.append(["the goal line", Rect2(goal.global_position, goal.size)])
	out.append_array(_step_boxes(goal, sc is SectorScreen and (sc as SectorScreen).fighting()))
	if Hints.card != null and is_instance_valid(Hints.card):
		out.append(["hint card", Hints.card.get_global_rect()])
	if sc._events != null and sc._events.visible:
		out.append(["event band", sc._events.get_global_rect()])
	for pair in [["bar under the view", sc._quiet_wrap], ["hand panel", sc._hand_wrap]]:
		var c: Control = pair[1]
		if c != null and c.is_visible_in_tree():
			out.append([pair[0], c.get_global_rect()])
			for ch in c.find_children("*", "", true, false):
				var k := ch as Control
				if k != null and k.is_visible_in_tree() and k.size.x > 0.0 and (k is Label or k is BaseButton or k is Panel or k is PanelContainer):
					out.append(["%s's %s" % [pair[0], k.name], k.get_global_rect()])
	if sc._self_plate != null and sc._self_plate.is_visible_in_tree():
		out.append(["your plate", sc._self_plate.get_global_rect()])
	var ship := sc._view.ship_view()
	if ship != null and ship.is_visible_in_tree():
		out.append(["your hull", ship.get_global_transform() * ship.ship_rect()])
	var L: HitLayers = sc._ship_fx
	if L != null and L.shield != null:
		var f := ShieldFx.fit(L._img, L._used)
		var rad := Vector2(float(f.rx), float(f.ry))
		out.append(["your shield's oval", L.shield.get_global_transform() * Rect2(L.shield._origin + (f.cc as Vector2) - rad, rad * 2.0)])
	# (no numbers on you here: they land only on the enemy's turn and at END
	# TURN, when she is gone -- the turn checks hold her to that)
	var i := 0
	while sc._view.slot(i) != null:
		var sl := sc._view.slot(i)
		if sl.is_visible_in_tree():
			out.append(["ship %d" % i, sl.get_global_transform() * sl.ink_rect()])
			out.append(["ship %d's words" % i, sl.intent_rect_global()])
			out.append(["ship %d's plate" % i, sl.readout_rect_global()])
			if sl.art != null:
				for p in sl.rooms(sl.art.draw_scale):
					out.append(["ship %d's %s" % [i, p[0]], sl.get_global_transform() * (p[1] as Rect2)])
			if sc.fighting() and i < Router.combat.enemies.size():
				for p in _pops(sc, false, i):
					out.append(["a number on ship %d" % i, p])
		i += 1
	var subj := LocalSubject.of(sc._view)
	if subj != null:
		for r: Rect2 in subj.drawn_rects():
			out.append(["the event's subject", r])
	return out


## The numbers a three-line landing pops on a hull, risen, global (the fight's
## own `_pop_at`, as `PopPlaceTest` takes them).
func _pops(sc: SectorScreen, to_player: bool, who: int) -> Array:
	var fx := sc._view.fx
	var keep := fx._pops.duplicate()
	fx._pops.clear()
	var q := {dealt = 6, absorbed = 5, missed = 1, hits = 2}
	sc._pop_hit(sc._pop_at(to_player, who, sc._pop_lines(q)), q, to_player)
	var out: Array = []
	var g := fx.get_global_transform()
	for p in fx._pops:
		var at := (p.at + Vector2(-HitText.ink_width(p.text) * 0.5, 0.0)).round()
		var r := HitText.ink_rect(at, p.text)
		r = r.merge(Rect2(r.position - Vector2(0, HitText.RISE), r.size))
		out.append(g * r)
	fx._pops.clear()
	fx._pops.append_array(keep)
	return out


func _wname(w: int) -> String:
	return ["light", "medium", "heavy"][w] if w >= 0 and w < 3 else str(w)


# ------------------------------------------------------------------ the switch

func _switch() -> void:
	print("the switch")
	var sc := await _local()
	Ash.set_on(false)
	Ash.arm(&"launch")
	var k := await _said_after()
	_ok("Settings off: nothing (%s)" % k, k == &"")
	var cfg := ConfigFile.new()
	cfg.load(DisplaySettings.path)
	_ok("kept in the harness's settings file, never the player's (%s)" % DisplaySettings.path,
		DisplaySettings.path != DisplaySettings.PATH and bool(cfg.get_value("ash", "on", true)) == false)
	Ash.set_on(true)
	Ash.forced = false
	_ok("off under a harness without -- ash", not Ash.enabled())
	Ash.forced = true


func _finish() -> void:
	Ash.forced = false
	print("  %d checks" % _checks)
	print("ashtest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
