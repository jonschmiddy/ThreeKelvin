class_name ScreenHooks
extends Node

## A BOSS DEATH'S HOLD ON THE SCREEN (Oct 13). The set pieces in ShipBreakup name
## what the whole screen should do as `moment`s -- `shake` (strength in px,
## length in s), `slowmo` (the fight's clock scale, length), `flash` (white's
## peak over the whole screen, length), `duck` (how far the music drops,
## length) and `stinger` (a music hit) -- and this plays them:
##   shake    moves `target` (the fight view) in whole pixels: a jolt that
##            decays as (1-x)^2, a new direction at most every three frames,
##            swung back across and eased to (the boss-death round's fix for
##            the shake that read as flicker);
##   slowmo   Engine.time_scale for its length, in real time;
##   flash    a white layer over the whole screen, eased out a frame at a time;
##   duck / stinger  through Audio.
## Everything on the game's clock (`GameClock`), as everything on screen is, so
## a film made with the movie writer plays it at true speed and the slow motion
## reaches the shake and the flash too. A slow motion's length is screen time:
## it is kept in game seconds scaled down by its own rate. Reduced motion (`Router.animating()` false) and the
## screen-shake setting are honoured: no shake, no flash, no slow motion then.

var target: Control
var _base := Vector2.ZERO
var _shakes: Array = []      ## {t0, len, amp}
var _flashes: Array = []     ## {t0, len, s}
var _slow_until := -1.0
var _layer: CanvasLayer
var _white: ColorRect
var _at := Vector2.ZERO
var _to := Vector2.ZERO
var _frame := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 991
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 110
	add_child(_layer)
	_white = ColorRect.new()
	_white.color = Color(1, 1, 1, 0)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_white)
	if target != null:
		_base = target.position


static func _now() -> float:
	return GameClock.now()


## Wire to a breakup's `moment`.
func on_moment(kind: StringName, s: float, len: float) -> void:
	var calm := not Router.animating()
	match kind:
		&"shake":
			if not calm and DisplaySettings.screen_shake:
				_shakes.append({t0 = _now(), len = maxf(0.05, len), amp = s})
		&"flash":
			if not calm:
				_flashes.append({t0 = _now(), len = maxf(0.1, len), s = s})
		&"slowmo":
			if not calm:
				Engine.time_scale = clampf(s, 0.1, 1.0)
				_slow_until = _now() + len * Engine.time_scale
		&"duck":
			Audio.duck_music(s, len)
		&"stinger":
			Audio.music_stinger(s)


func _process(_dt: float) -> void:
	var now := _now()
	if _slow_until > 0.0 and now >= _slow_until:
		Engine.time_scale = 1.0
		_slow_until = -1.0
	# the shake
	var amp := 0.0
	var live: Array = []
	for sh in _shakes:
		var x := (now - float(sh.t0)) / float(sh.len)
		if x < 1.0:
			amp = maxf(amp, float(sh.amp) * (1.0 - x) * (1.0 - x))
			live.append(sh)
	_shakes = live
	_frame += 1
	if amp >= 0.5:
		if _frame % 3 == 0:
			var d := Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
			if _to.length() > 0.1 and d.dot(_to.normalized()) > 0.0:
				d = -d
			_to = d * amp
		_at = _at.lerp(_to, 0.6)
	else:
		_to = Vector2.ZERO
		_at = _at.lerp(Vector2.ZERO, 0.6)
	if target != null and is_instance_valid(target):
		target.position = _base + _at.round()
	# the flash
	var fa := 0.0
	var lf: Array = []
	for fl in _flashes:
		var x2 := (now - float(fl.t0)) / float(fl.len)
		if x2 < 1.0:
			fa = maxf(fa, float(fl.s) * 0.85 * (1.0 - x2) * (1.0 - x2))
			lf.append(fl)
	_flashes = lf
	_white.color = Color(1, 1, 1, fa)


## Done: everything back as it was.
func settle() -> void:
	if _slow_until > 0.0:
		Engine.time_scale = 1.0
	_slow_until = -1.0
	if target != null and is_instance_valid(target):
		target.position = _base
	_shakes.clear()
	_flashes.clear()
	if _white != null:
		_white.color = Color(1, 1, 1, 0)


func busy() -> bool:
	return not _shakes.is_empty() or not _flashes.is_empty() or _slow_until > 0.0


func _exit_tree() -> void:
	settle()
