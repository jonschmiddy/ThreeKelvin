class_name MiniShell
extends RefCounted

## Everything round a science mini game on the desk's glass (150 x 140, an art pixel each): the
## game's canvas, the whole glass (A, Nov 20); its sounds, the win, the tier's reward a beat later
## (Jon, Nov 18); and after the end the result card over the game, NAME [TIER] swept in on the
## reward. The game never shows a tier; this does, from score and depth (`ScienceHaul.tier_of`).
## Why: docs/why/MiniGame.md#the-shell

## Said once the game ends, with the tier its score and depth earned.
signal scored(tier: int)

const GW := 150
const GH := 140
## THE ONE BORDER COLOUR (Jon, Nov 19): the terminal's panel, under any room a game leaves.
const BORDER := MiniPix.PANEL
## The card's word after a give-up the game did not name.
const GAVE_UP := "GAVE UP"
## Each game's sounds (the phone page's sfx.json, Jon's picks Nov 17 to 18): [file, offset s].
## A positive offset starts it that much later, a negative one starts that far into the file.
const SFX := {
	&"coolant": {&"turn": [&"mg_coolant_turn", 0.0], &"flow": [&"mg_coolant_flow", 0.0], &"win": [&"mg_win", 1.3]},
	&"centrifuge": {&"seat": [&"mg_centrifuge_seat", 0.0], &"spin": [&"mg_centrifuge_spin", -0.06], &"win": [&"mg_win", 0.0]},
	&"icecore": {&"place": [&"mg_icecore_place", 0.0], &"confirm": [&"mg_icecore_confirm", 0.0], &"win": [&"mg_win", 0.4]},
	&"pulsar": {&"tick": [&"mg_pulsar_tick", 0.0], &"lock": [&"mg_pulsar_lock", 0.0], &"win": [&"mg_win", 0.3]},
	&"tray": {&"slide": [&"mg_tray_slide", 0.0], &"out": [&"mg_tray_out", 0.0], &"win": [&"mg_win", 0.3]},
	&"anomaly": {&"mark": [&"mg_anomaly_mark", 0.0], &"clear": [&"mg_anomaly_clear", 0.0], &"win": [&"mg_win", 0.3]},
	&"beams": {&"turn": [&"mg_beams_turn", 0.0], &"lit": [&"mg_beams_lit", 0.0], &"win": [&"mg_win", 0.3]},
	&"spectrum": {&"tube": [&"mg_spectrum_tube", 0.0], &"match": [&"mg_spectrum_match", 0.0], &"win": [&"mg_win", 0.35]},
	&"fourkelvin": {&"bump": [&"mg_fourk_bump", 0.0], &"thrust": [&"mg_fourk_thrust", 0.0], &"win": [&"mg_win", 0.0]},
	&"torch": {&"free": [&"mg_torch_free", 0.0], &"torch": [&"mg_torch_torch", 0.0], &"win": [&"mg_win", 0.35]},
	&"leak": {&"puff": [&"mg_leak_puff", 0.0], &"seal": [&"mg_leak_seal", 0.0], &"win": [&"mg_win", 0.15]},
	&"sling": {&"hit": [&"mg_sling_hit", 0.0], &"launch": [&"mg_sling_launch", 0.0], &"win": [&"mg_win", 0.3]},
	&"tuning": {&"detent": [&"mg_tuning_detent", 0.0], &"lock": [&"mg_tuning_lock", 0.0], &"win": [&"mg_win", 0.35]},
	&"seismic": {&"scan": [&"mg_seismic_scan", 0.0], &"dig": [&"mg_seismic_dig", 0.0], &"ore": [&"mg_seismic_ore", 0.0], &"win": [&"mg_win", 0.0]},
	&"corescan": {&"fill": [&"mg_tomo_fill", 0.0], &"crack": [&"mg_tomo_crack", -0.06], &"win": [&"mg_win", 0.1]},
	&"culture": {&"drop": [&"mg_culture_drop", 0.0], &"grow": [&"mg_culture_grow", 0.0], &"win": [&"mg_win", 0.0]},
	&"dock": {&"dock": [&"mg_dock_dock", 0.0], &"puff": [&"mg_dock_puff", 0.0], &"win": [&"mg_win", 0.15]},
}
const SFX_PATH := "res://assets/audio/sfx/%s.wav"
## The reward waits for the win (its peak, 1.283 s in) or, with none, 1.1 s after the end.
const WIN_PEAK := 1.283
const REWARD_MIN := 1.1
## NAME [TIER]'s reveal on the card (the loot reveal's S1 sweep): 0.65 s up to the reward's sound,
## 0.35 s after.
const REVEAL_PRE := 0.65
const REVEAL_POST := 0.35
const FRINGE: Array[Color] = [Color(1.0, 0.27, 0.27), Color(1.0, 0.86, 0.24), Color(0.27, 1.0, 0.47), Color(0, 0, 0, 0), Color(0.31, 0.55, 1.0)]

var game: MiniGame
var glass: Image
var depth := 1
var t := 0.0
var tier := -1
var score := 0.0
var detail := ""
var haul := ""
## The material's own tier (a tier with no material pays the nearest lower one).
var haul_tier: StringName = &""
## The game's canvas on the glass.
var at := Vector2i.ZERO
## NAME [TIER] is in (0.35 s after the reward's sound).
var revealed := false
## The END word on the card, and its kind (the game's `finish`, else GAVE UP).
var end_text := ""
var end_kind := "neutral"
var _gave_up := false
## Whether the take has paid (`set_haul`): the card waits for it.
var _paid := false
var _win_at := -1.0
var _done_at := -1.0
var _reward_at := -1.0
var _rewarded := false
var _queued: Array = []
var _dirty := true
## Where looping sounds play (the desk); none headless, where nothing sounds.
var host: Node = null
var _loops: Dictionary = {}


## The game `g`, dealt now from `r` (seeded with `sd`) at `d` and `s`.
func start(g: MiniGame, d: int, s: int, r: RandomNumberGenerator, sd := 0) -> void:
	game = g
	game.seed = sd
	depth = clampi(d, 1, 5)
	glass = Image.create(GW, GH, false, Image.FORMAT_RGBA8)
	game.finished.connect(_on_finished)
	game.mount(depth, s, r)
	# a canvas two wider than the glass (152) loses a column each side, its own frame inside it
	at = Vector2i((GW - game.px.w) / 2, maxi(0, (GH - game.px.h) / 2))
	_compose()


func playing() -> bool:
	return game != null and not game.is_done()


## Seconds `dt` on: the game, its sounds, the reward and the line. True when the glass changed.
func tick(dt: float) -> bool:
	t += dt
	game.tick(dt)
	_take_asked()
	_play_due()
	_sync_loops()
	if _reward_at >= 0.0:
		if not _rewarded and t >= _reward_at:
			_rewarded = true
			Audio.play(StringName("mg_reward_%d" % tier), 0.0)
		if t >= _reward_at - REVEAL_PRE:
			_dirty = true
		if t >= _reward_at + REVEAL_POST and not revealed:
			revealed = true
	# the card comes up, then NAME [TIER] sweeps in: drawn every step until both are in
	if _done_at >= 0.0 and not (revealed and card_up()):
		_dirty = true
	if game.dirty or _dirty:
		_compose()
		return true
	return false


## The player gives up (Esc): the game scores what it had (often 0).
func give_up() -> void:
	if playing():
		_gave_up = true
		game.give_up()


## What the haul paid, for the card: the material's name and its own tier (the take is in).
func set_haul(name: String, of_tier: StringName) -> void:
	haul = name
	haul_tier = of_tier
	_paid = true
	_dirty = true


## Whether the result card is up: 0.6 s after the end, once the haul is paid. While it is, a
## click anywhere on the glass, or Esc, leaves (A).
func card_up() -> bool:
	return _done_at >= 0.0 and _paid and t >= _done_at + MiniKit.CARD_DELAY


## The pointer at glass point `gf` (fractional glass pixels).
func press(gf: Vector2) -> void:
	var g := Vector2i(gf.floor())
	if playing():
		game.pf = gf - Vector2(at)
		game.down(g - at)
		_take_asked()


func motion(gf: Vector2) -> void:
	if playing():
		game.pf = gf - Vector2(at)
		game.move(Vector2i(gf.floor()) - at)


func release(gf: Vector2) -> void:
	if playing():
		game.pf = gf - Vector2(at)
		game.up(Vector2i(gf.floor()) - at)
		_take_asked()


func key(k: StringName, pressed: bool) -> void:
	if playing():
		game.key(k, pressed)
		_take_asked()


func wheel(dir: int) -> void:
	if playing():
		game.wheel(dir)
		_take_asked()


## Every looping sound off (the game ended, or the desk is left).
func stop_sounds() -> void:
	for p: AudioStreamPlayer in _loops.values():
		p.stop()
		p.queue_free()
	_loops.clear()


## The game's looping sounds as it wants them now (Four Kelvin's thrust, the torch's flame).
func _sync_loops() -> void:
	if host == null:
		return
	var want: Dictionary = game.loops if playing() else {}
	for name: StringName in _loops.keys():
		if not want.has(name):
			(_loops[name] as AudioStreamPlayer).stop()
			(_loops[name] as AudioStreamPlayer).queue_free()
			_loops.erase(name)
	for name: StringName in want:
		if _loops.has(name):
			continue
		var row: Array = (SFX.get(game.id(), {}) as Dictionary).get(name, [])
		if row.is_empty():
			continue
		var w := (load(SFX_PATH % row[0]) as AudioStreamWAV).duplicate() as AudioStreamWAV
		Audio.loop_whole(w)
		var p := AudioStreamPlayer.new()
		p.stream = w
		p.bus = &"SFX"
		host.add_child(p)
		p.play()
		_loops[name] = p


func _take_asked() -> void:
	for name: StringName in game.asked:
		_sound(name)
	game.asked.clear()


func _on_finished(sc: float, d: String) -> void:
	# the sounds the last move asked for (the win among them) are timed first
	_take_asked()
	score = sc
	detail = d
	end_text = game.end_text
	end_kind = game.end_kind
	if _gave_up:
		# a give-up says so; every game names its own end (`say_end`, held by MiniGameTest)
		end_text = GAVE_UP
		end_kind = "neutral"
	tier = ScienceHaul.tier_of(sc, depth)
	_done_at = t
	# the phone page's timing: 0.45 s, then the win's peak or 0.65 s, whichever is later
	_reward_at = _done_at + REWARD_MIN
	if _win_at >= 0.0:
		_reward_at = maxf(_reward_at, _win_at + WIN_PEAK)
	_dirty = true
	scored.emit(tier)


func _sound(name: StringName) -> void:
	var row: Array = (SFX.get(game.id(), {}) as Dictionary).get(name, [])
	if row.is_empty():
		return
	var off := float(row[1])
	if name == &"win":
		_win_at = t + maxf(0.0, off)
	_queued.append([t + maxf(0.0, off), StringName(row[0]), maxf(0.0, -off)])
	_play_due()


func _play_due() -> void:
	var keep: Array = []
	for q: Array in _queued:
		if float(q[0]) <= t:
			Audio.play(q[1], 0.0, 30, 0.0, 1.0, float(q[2]))
		else:
			keep.append(q)
	_queued = keep


## The glass: the game's canvas, the whole of it; after the end, the result card over it.
func _compose() -> void:
	glass.fill(BORDER)
	var src := Rect2i(Vector2i(maxi(0, -at.x), maxi(0, -at.y)), game.px.img.get_size())
	src.size -= src.position
	glass.blit_rect(game.px.img, src, at + src.position)
	game.dirty = false
	_dirty = false
	if card_up():
		_card(MiniPix.new(GW, GH, glass))


## Whether a press at glass point `gf` leaves: anywhere on the glass once the card is up (A).
func leave_hit(_gf: Vector2) -> bool:
	return not playing() and card_up()


## The card's tier: the material's own (a tier with no material pays the nearest lower one).
func card_tier() -> int:
	var key := haul_tier if haul_tier != &"" else ScienceHaul.tier_key(tier)
	return clampi(UITheme.TIER_ORDER.find(key), 0, 4)


## The result card (`MiniKit.result_card`), its NAME [TIER] row swept in left to right up to the
## reward's sound (the S1 split's sweep): the row not yet reached is the card's face again.
func _card(c: MiniPix) -> void:
	var ti := card_tier()
	var b := MiniKit.result_card(c, end_text, end_kind, haul, ti, t - _done_at)
	var tau := t - _reward_at
	if haul == "" or tau >= 0.0:
		return
	var pp := (tau + REVEAL_PRE) / REVEAL_PRE
	var x0 := b.position.x + 1
	var x1 := b.end.x - 1
	var lx := x0 - 4 + MiniPix.jr((x1 - x0 + 8) * clampf(pp / 0.55, 0.0, 1.0))
	var y := b.position.y + 15
	c.rect(maxi(lx, x0), y, x1 - maxi(lx, x0), 9, BORDER)
	if pp < 0.6:
		for k in FRINGE.size():
			var fx := lx - 3 + k
			if fx >= x0 and fx < x1:
				c.rect(fx, y, 1, 9, FRINGE[k] if FRINGE[k].a > 0.0 else MiniKit.tier_ink(ti))
