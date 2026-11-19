class_name MiniShell
extends RefCounted

## Everything round a science mini game on the desk's glass (150 x 140, an art pixel each): the
## game's canvas, GIVE UP, and the haul line; the game's sounds, Four Kelvin's win on a real
## success, then the tier's reward a beat later (Jon, Nov 18), with the line revealed on it.
## The game never shows a tier; this does, from score and depth (`ScienceHaul.tier_of`).
## Why: docs/why/MiniGame.md#the-shell

## Said once the game ends, with the tier its score and depth earned.
signal scored(tier: int)

const GW := 150
const GH := 140
## The game sits centred above the strip; the strip holds GIVE UP, then the haul line.
const AREA_H := 130
const STRIP_Y := 131
const INSET := Color("#05080d")
const GIVE_UP := "GIVE UP"
const BUTTON := Rect2i(GW - 3 - 33, STRIP_Y - 1, 33, 9)
## Each game's sounds (the phone page's sfx.json, Jon's picks Nov 17 to 18): [file, offset s].
## A positive offset starts it that much later, a negative one starts that far into the file.
const SFX := {
	&"coolant": {&"turn": [&"mg_coolant_turn", 0.0], &"flow": [&"mg_coolant_flow", 0.0], &"win": [&"mg_win", 1.3]},
	&"centrifuge": {&"seat": [&"mg_centrifuge_seat", 0.0], &"spin": [&"mg_centrifuge_spin", -0.06], &"win": [&"mg_win", 0.0]},
}
## The reward waits for the win (its peak, 1.283 s in) or, with none, 1.1 s after the end.
const WIN_PEAK := 1.283
const REWARD_MIN := 1.1
## The line's reveal (the loot reveal's S1 sweep): 0.65 s up to the reward's sound, 0.35 s after.
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
## The game's canvas on the glass.
var at := Vector2i.ZERO
var revealed := false
var _win_at := -1.0
var _done_at := -1.0
var _reward_at := -1.0
var _rewarded := false
var _queued: Array = []
var _dirty := true


## The game `g`, dealt now from `r` at `d` and `s`.
func start(g: MiniGame, d: int, s: int, r: RandomNumberGenerator) -> void:
	game = g
	depth = clampi(d, 1, 5)
	glass = Image.create(GW, GH, false, Image.FORMAT_RGBA8)
	game.finished.connect(_on_finished)
	game.mount(depth, s, r)
	at = Vector2i((GW - game.px.w) / 2, maxi(0, (AREA_H - game.px.h) / 2))
	_compose()


func playing() -> bool:
	return game != null and not game.is_done()


## Seconds `dt` on: the game, its sounds, the reward and the line. True when the glass changed.
func tick(dt: float) -> bool:
	t += dt
	game.tick(dt)
	_take_asked()
	_play_due()
	if _reward_at >= 0.0:
		if not _rewarded and t >= _reward_at:
			_rewarded = true
			Audio.play(StringName("mg_reward_%d" % tier), 0.0)
		if t >= _reward_at - REVEAL_PRE:
			_dirty = true
		if t >= _reward_at + REVEAL_POST and not revealed:
			revealed = true
	if game.dirty or _dirty:
		_compose()
		return true
	return false


## The player gives up: the game scores what it had (often 0).
func give_up() -> void:
	if playing():
		game.give_up()


## What the haul paid, for its line (the material's name).
func set_haul(name: String) -> void:
	haul = name
	_dirty = true


func press(g: Vector2i) -> void:
	if playing() and BUTTON.has_point(g):
		give_up()
		return
	if playing():
		game.down(g - at)
		_take_asked()


func motion(g: Vector2i) -> void:
	if playing():
		game.move(g - at)


func release(g: Vector2i) -> void:
	if playing():
		game.up(g - at)


func _take_asked() -> void:
	for name: StringName in game.asked:
		_sound(name)
	game.asked.clear()


func _on_finished(sc: float, d: String) -> void:
	# the sounds the last move asked for (the win among them) are timed first
	_take_asked()
	score = sc
	detail = d
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


## The glass: the inset, the game, the strip.
func _compose() -> void:
	glass.fill(INSET)
	glass.blit_rect(game.px.img, Rect2i(Vector2i.ZERO, game.px.img.get_size()), at)
	game.dirty = false
	_dirty = false
	var strip := MiniPix.new(GW, GH, glass)
	if playing():
		_button(strip)
	elif _reward_at >= 0.0 and t >= _reward_at - REVEAL_PRE:
		_line(strip)


func _button(c: MiniPix) -> void:
	var b := BUTTON
	c.rect(b.position.x, b.position.y, b.size.x, b.size.y, MiniPix.BEVEL_LO)
	c.rect(b.position.x + 1, b.position.y + 1, b.size.x - 2, b.size.y - 2, MiniPix.PANEL)
	c.rect(b.position.x + 1, b.position.y + 1, b.size.x - 2, 1, MiniPix.LINE)
	c.text(GIVE_UP, b.position.x + 3, b.position.y + 2, MiniPix.CHILL)


## The haul line, swept in left to right up to the reward's sound (the S1 split's sweep).
func _line(c: MiniPix) -> void:
	var col: Color = MiniPix.TIERS[clampi(tier, 0, MiniPix.TIERS.size() - 1)]
	var words := ScienceHaul.TIER_NAMES[clampi(tier, 0, ScienceHaul.TIER_NAMES.size() - 1)]
	if haul != "":
		words += "  " + haul
	var tau := t - _reward_at
	if tau >= 0.0:
		c.text(words, GW / 2, STRIP_Y, col, "center")
		return
	var pp := (tau + REVEAL_PRE) / REVEAL_PRE
	var lx := MiniPix.jr(-4.0 + (GW + 8) * minf(1.0, pp / 0.55))
	var line := MiniPix.new(GW, GH)
	line.text(words, GW / 2, STRIP_Y, col, "center")
	if lx > 0:
		c.img.blend_rect(line.img, Rect2i(0, STRIP_Y - 1, mini(lx, GW), 7), Vector2i(0, STRIP_Y - 1))
	if pp < 0.6:
		for k in FRINGE.size():
			var fc := FRINGE[k] if FRINGE[k].a > 0.0 else col
			c.rect(lx - 3 + k, STRIP_Y - 2, 1, 9, fc)
