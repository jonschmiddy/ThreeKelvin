class_name LowHull
extends Node

## THE HULL IS FAILING, AND THE SCREEN KNOWS (Jon, Oct 20: "When you are low
## health, can you have all the text kinda glitch a bit? Maybe with the screen
## turning red? I don't want it to be too overt. Just kinda like a gentle
## warning state." And then: "Maybe even A.S.H.'s voice could glitch a bit?").
##
## WHEN: the hull at or under TIER1_AT of its max (a second, slightly stronger
## step at TIER2_AT), read as the HUD reads it -- the figure the fight has
## SHOWN, not the one the click already decided (`SectorScreen.shown_hull`,
## `OutcomeRow.held`) -- so the warning arrives with the number that says so.
## Only inside a run: never on the title, the lobby, the hull pick, RUN ENDED or
## the records room from the title, and never once the hull is at 0 (the
## ship's loss has its own picture, `DeathHandoff`). It eases in and out over
## EASE_S as the hull crosses the line either way; a repair clears it.
##
## WHAT, all of it drawn over the finished frame (`low_hull.gdshader`, on a
## CanvasLayer of its own at LAYER: above the screens and the HUD, under the
## escape menu) and none of it touching a control:
##   * THE RED: a faint red at the picture's edges, breathing (BREATH_S a
##     cycle), never reaching the middle of the screen;
##   * THE TEXT GLITCHES: now and then (a rate a second, across the whole
##     screen) one text on screen -- a Label, a RichTextLabel, a Button's
##     words, the event band's `SignalText` -- slips a few rows a pixel or two
##     sideways, splits red from cyan, or has a letter-wide cell dim, for
##     GLITCH_S (a few frames). Never the hull readouts: that is what the
##     player is reading, and it holds still (`steady`: the HUD's, and the
##     plate under your ship in a fight).
##   * HER VOICE: A.S.H.'s lines while it is on get a few short glitches each
##     (`voice_plan`, rendered by `VoiceGlitch`), and her portrait slips in
##     step with them (`AshPortrait`).
##
## NO SOUND OF ITS OWN. The game has no low-hull sound and this adds none: the
## heat warning (`heat_warn`) is the only alarm the ship has.
##
## REDUCED MOTION (`Router.animating()` false): no glitches and no breathing --
## the red stands still at REDUCED_RED of its strength -- and her voice glitches
## at the SUBTLE preset whatever PRESET is (a sound does not move on screen, so
## it stays, at its quietest).
##
## THE STRENGTH IS ONE CONSTANT: PRESET, from LOOKS. `-- lowhull=subtle|medium|
## strong` overrides it for a film.

enum Preset { SUBTLE, MEDIUM, STRONG }
## Jon's pick of LOOKS. Default subtle ("I don't want it to be too overt").
const PRESET := Preset.SUBTLE

## The hull's share at or under which it comes on, and its second step.
const TIER1_AT := 0.30
const TIER2_AT := 0.15
## In and out, s, on the game's clock.
const EASE_S := 1.0
## One breath, s: tier 1, and tier 2 (a little quicker).
const BREATH_S := [2.6, 2.0]
## How long a glitch holds, s: three to five frames at 60.
const GLITCH_S := [0.045, 0.085]
## The share of the red that stands, still, under reduced motion.
const REDUCED_RED := 0.6
## Above the screens (layer 0), under the escape menu and Settings (10).
const LAYER := 5

## Per preset. Each pair is (tier 1, tier 2).
##   red     the red at the very edge (`low_hull.gdshader`'s `red`)
##   breath  how far a breath takes it down, as a share of itself
##   rate    glitches a second, across the whole screen
##   px      how far a slip or a split moves, game px
##   dim     a glitched letter's brightness
##   voice   the most glitches in one of her lines (a line has room for fewer
##           when it is short)
##   kinds   which of `VoiceGlitch`'s she may get
##   amt     how hard each of those bites (`VoiceGlitch.apply`)
const LOOKS := {
	Preset.SUBTLE: {
		red = [0.30, 0.42], breath = 0.4, rate = [0.5, 0.9], px = [1, 1], dim = 0.45,
		voice = [2, 3], kinds = [&"gap", &"repeat", &"wobble", &"crush"], amt = 0.55,
	},
	Preset.MEDIUM: {
		red = [0.48, 0.62], breath = 0.4, rate = [0.8, 1.4], px = [1, 2], dim = 0.35,
		voice = [3, 3], kinds = [&"gap", &"repeat", &"wobble", &"crush", &"ring"], amt = 0.75,
	},
	Preset.STRONG: {
		red = [0.68, 0.85], breath = 0.45, rate = [1.3, 2.2], px = [2, 2], dim = 0.25,
		voice = [3, 4], kinds = [&"gap", &"repeat", &"wobble", &"crush", &"ring"], amt = 1.0,
	},
}

const SHADER := preload("res://shaders/low_hull.gdshader")
const SLOTS := 4

static var instance: LowHull = null
## The preset in force: PRESET, or what `-- lowhull=` asked for.
static var preset: Preset = PRESET
## What the hull says now: 0 fine, 1 at or under TIER1_AT, 2 at or under TIER2_AT.
static var tier := 0
## Eased toward on (1) and toward the second step (1), 0..1.
static var on := 0.0
static var deep := 0.0
## The red the shader was given this frame.
static var red_now := 0.0
## Every glitch drawn, for a harness: {at, kind, node, rect}.
static var glitch_log: Array = []

var _layer: CanvasLayer
var _rect: ColorRect
var _mat: ShaderMaterial
var _breath := 0.0
var _last := -1.0
var _next_glitch := 0.0
var _live: Array = []      ## {until, rect, par, node}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "LowHull"


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("lowhull="):
			match (a as String).substr(8):
				"medium": preset = Preset.MEDIUM
				"strong": preset = Preset.STRONG
				_: preset = Preset.SUBTLE
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect = ColorRect.new()
	_rect.name = "LowHullGlass"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.focus_mode = Control.FOCUS_NONE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.material = _mat
	_rect.visible = false
	_layer.add_child(_rect)
	_clear_slots()


func _exit_tree() -> void:
	if instance == self:
		instance = null


## The look in force (`preset`).
static func look() -> Dictionary:
	return LOOKS[preset]


## The hull as the HUD shows it, and its max. 0 max outside a run.
static func shown() -> Vector2i:
	if Run.hull == null:
		return Vector2i(0, 0)
	var hp := Run.hp if SectorScreen.shown_hull < 0 else SectorScreen.shown_hull
	hp = int(OutcomeRow.held.get("hp", hp))
	return Vector2i(hp, Run.max_hp())


## Which step a hull of `hp` out of `top` is on.
static func tier_for(hp: int, top: int) -> int:
	if top <= 0 or hp <= 0:
		return 0
	var s := float(hp) / float(top)
	if s <= TIER2_AT + 0.00001:
		return 2
	if s <= TIER1_AT + 0.00001:
		return 1
	return 0


## A run is up and on screen: not the title, the lobby, the hull pick, RUN
## ENDED, or the records room opened from the title.
static func in_run() -> bool:
	var cur := Router.current
	if cur == null or not is_instance_valid(cur) or Run.hull == null:
		return false
	if Router.is_front_door(cur) or cur is GameOverScreen:
		return false
	if cur is ArchiveScreen and Router.hud != null and not Router.hud.visible:
		return false
	return true


static func moving() -> bool:
	return Router.animating()


func _process(_d: float) -> void:
	var now := GameClock.now()
	var dt := 0.0 if _last < 0.0 else clampf(now - _last, 0.0, 0.25)
	_last = now
	var h := shown()
	tier = tier_for(h.x, h.y) if in_run() else 0
	on = move_toward(on, 1.0 if tier > 0 else 0.0, dt / EASE_S)
	deep = move_toward(deep, 1.0 if tier > 1 else 0.0, dt / EASE_S)
	var lk := look()
	var e_on := smoothstep(0.0, 1.0, on)
	var e_deep := smoothstep(0.0, 1.0, deep)
	var base := lerpf(float(lk.red[0]), float(lk.red[1]), e_deep)
	if moving():
		_breath = fposmod(_breath + dt / lerpf(float(BREATH_S[0]), float(BREATH_S[1]), e_deep), 1.0)
		var b := 0.5 - 0.5 * cos(TAU * _breath)
		red_now = e_on * base * (1.0 - float(lk.breath) * (1.0 - b))
	else:
		_breath = 0.0
		red_now = e_on * base * REDUCED_RED
	# the glitches: the live ones run out, and a new one when one is due
	var changed := false
	for i in range(_live.size() - 1, -1, -1):
		if now >= float(_live[i].until) or not moving():
			_live.remove_at(i)
			changed = true
	if moving() and e_on > 0.5 and not get_tree().paused:
		if _next_glitch <= 0.0:
			_next_glitch = now + _gap(lk, e_deep) * 0.5
		elif now >= _next_glitch:
			_next_glitch = now + _gap(lk, e_deep)
			if _live.size() < SLOTS and _glitch(now, lk, e_deep):
				changed = true
	else:
		_next_glitch = 0.0
	var show := red_now > 0.0005 or not _live.is_empty()
	_rect.visible = show
	if show:
		_mat.set_shader_parameter(&"red", red_now)
	if changed:
		_push_slots()


## Seconds to the next glitch: about 1/rate, never twice the same.
func _gap(lk: Dictionary, e_deep: float) -> float:
	var rate := lerpf(float(lk.rate[0]), float(lk.rate[1]), e_deep)
	return _rng.randf_range(0.45, 1.55) / maxf(rate, 0.01)


## One glitch on one text. False if there was nothing to glitch.
func _glitch(now: float, lk: Dictionary, e_deep: float) -> bool:
	var picks := texts()
	if picks.is_empty():
		return false
	var row: Array = picks[_rng.randi() % picks.size()]
	var c: Control = row[0]
	var r: Rect2 = row[1]
	var px := float(lk.px[1] if e_deep > 0.5 else lk.px[0])
	var roll := _rng.randf()
	var par: Vector4
	if roll < 0.5:
		var hh := float(_rng.randi_range(1, mini(3, maxi(1, int(r.size.y) - 1))))
		var y := r.position.y + float(_rng.randi_range(0, maxi(0, int(r.size.y - hh))))
		par = Vector4(1, y, hh, px if _rng.randf() < 0.5 else -px)
	elif roll < 0.8:
		par = Vector4(2, 0, 0, px)
	else:
		var w := float(_rng.randi_range(5, 7))
		var x := r.position.x + float(_rng.randi_range(0, maxi(0, int(r.size.x - w))))
		par = Vector4(3, x, w, float(lk.dim))
	_live.append({until = now + _rng.randf_range(GLITCH_S[0], GLITCH_S[1]), rect = r, par = par, node = c})
	glitch_log.append({at = now, kind = int(par.x), node = c, rect = r})
	return true


func _clear_slots() -> void:
	var rects: Array[Vector4] = []
	var pars: Array[Vector4] = []
	for i in SLOTS:
		rects.append(Vector4.ZERO)
		pars.append(Vector4.ZERO)
	_mat.set_shader_parameter(&"g_rect", rects)
	_mat.set_shader_parameter(&"g_par", pars)


func _push_slots() -> void:
	var rects: Array[Vector4] = []
	var pars: Array[Vector4] = []
	for i in SLOTS:
		if i < _live.size():
			var r: Rect2 = _live[i].rect
			rects.append(Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
			pars.append(_live[i].par)
		else:
			rects.append(Vector4.ZERO)
			pars.append(Vector4.ZERO)
	_mat.set_shader_parameter(&"g_rect", rects)
	_mat.set_shader_parameter(&"g_par", pars)


## The glitches up this frame, for a harness: {rect, par, node}.
func live() -> Array:
	return _live


## WHAT MAY GLITCH: every text on the game's own layer that is on screen now,
## with the rect its words are drawn in (screen px), less the hull readout.
## [[control, rect], ...].
func texts() -> Array:
	var out: Array = []
	var main := get_parent()
	if main == null:
		return out
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var keep_off: Array[Rect2] = []
	var skip := {}
	for n in steady():
		skip[n] = true
		keep_off.append(_screen_rect(n).grow(2.0))
	for n in main.find_children("*", "Control", true, false):
		var c := n as Control
		if skip.has(c) or c is FpsMeter or not c.is_visible_in_tree():
			continue
		if c.get_viewport() != get_viewport() or c.get_canvas_layer_node() != null:
			continue
		var r := Rect2()
		if c is Label:
			if (c as Label).text.strip_edges() == "":
				continue
			r = _label_rect(c as Label)
		elif c is RichTextLabel:
			if (c as RichTextLabel).get_parsed_text().strip_edges() == "":
				continue
			r = _screen_rect(c)
		elif c is Button:
			if (c as Button).text.strip_edges() == "":
				continue
			# its words, inside its plate: a glitch on the plate's edge reads as
			# the button breaking, not the text
			r = _screen_rect(c).grow_individual(-4.0, -3.0, -4.0, -3.0)
		elif c is SignalText:
			r = _screen_rect(c)
		else:
			continue
		r = r.intersection(view)
		if r.size.x < 4.0 or r.size.y < 4.0:
			continue
		var clear := true
		for k in keep_off:
			if k.intersects(r):
				clear = false
				break
		if clear:
			out.append([c, r])
	return out


## THE HULL READOUTS, which never glitch: what the player is checking. The
## HUD's (its label, cells and figure) and, in a fight, the plate under your
## ship (its bar and its "8 / 40").
static func steady() -> Array[Control]:
	var out: Array[Control] = []
	if Router.hud != null and is_instance_valid(Router.hud):
		for n in Router.hud.stat_nodes("hp"):
			if n is Control and is_instance_valid(n):
				out.append(n as Control)
	var sc := Router.current as SectorScreen
	if sc != null and is_instance_valid(sc):
		for n in [sc._self_hp, sc._self_bar]:
			if n is Control and is_instance_valid(n) and (n as Control).is_visible_in_tree():
				out.append(n as Control)
	return out


static func _screen_rect(c: Control) -> Rect2:
	var xf := c.get_global_transform_with_canvas()
	return (xf * Rect2(Vector2.ZERO, c.size)).abs()


## A one-line label's words, not its whole box: a short word centred in a wide
## label would otherwise spend most of its glitches on nothing.
static func _label_rect(l: Label) -> Rect2:
	var full := Rect2(Vector2.ZERO, l.size)
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF or "\n" in l.text:
		return _screen_rect(l)
	var f := l.get_theme_font(&"font")
	if f == null:
		return _screen_rect(l)
	var w := minf(l.size.x, f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		l.get_theme_font_size(&"font_size")).x + 2.0)
	var x := 0.0
	match l.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x = floorf((l.size.x - w) * 0.5)
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = l.size.x - w
	full = Rect2(Vector2(x, 0.0), Vector2(w, l.size.y))
	return (l.get_global_transform_with_canvas() * full).abs()


# ------------------------------------------------------------------ her voice

## The preset her voice uses: PRESET's, or SUBTLE under reduced motion.
static func voice_look() -> Dictionary:
	return LOOKS[Preset.SUBTLE] if DisplaySettings.reduced_motion else look()


## Her voice glitches this line: the hull is on a step NOW (her line is decided
## as it starts, so no easing).
static func voice_on() -> bool:
	if instance == null:
		return false
	var h := shown()
	return in_run() and tier_for(h.x, h.y) > 0


## Where her line of `secs` glitches: [{at, len, kind, amt}], at and len in s
## from the take's start. Inside her words only (after the take's 30 ms lead-in
## and before its trailing silence), each window short enough never to cover a
## whole word (60 ms at most; the pitch wobble 150), at least MIN_APART apart.
const MIN_APART := 0.45
const KIND_LEN := {
	&"gap": [0.022, 0.045], &"repeat": [0.025, 0.05], &"crush": [0.04, 0.06],
	&"ring": [0.04, 0.06], &"wobble": [0.1, 0.15],
}

static func voice_plan(secs: float, rng: RandomNumberGenerator = null) -> Array:
	var out: Array = []
	if not voice_on():
		return out
	return plan_for(secs, tier_for(shown().x, shown().y), voice_look(), rng)


## The plan without asking the hull: `t` the step, `lk` the look.
static func plan_for(secs: float, t: int, lk: Dictionary, rng: RandomNumberGenerator = null) -> Array:
	var out: Array = []
	if t <= 0:
		return out
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var a := 0.12
	var z := secs - 0.1 - 0.2
	if z - a < 0.25:
		return out
	var most := int(lk.voice[1] if t > 1 else lk.voice[0])
	var n := mini(most, maxi(1, int((z - a) / MIN_APART)))
	# at least one less than the most on a step-one line, now and then
	if t == 1 and n > 1 and rng.randf() < 0.4:
		n -= 1
	var span := (z - a) / float(n)
	var kinds: Array = lk.kinds
	for i in n:
		var k: StringName = kinds[rng.randi() % kinds.size()]
		var ln := rng.randf_range(float(KIND_LEN[k][0]), float(KIND_LEN[k][1]))
		var lo := a + span * float(i)
		var hi := maxf(lo, lo + span - ln - 0.2)
		out.append({at = rng.randf_range(lo, hi), len = ln, kind = k, amt = float(lk.amt)})
	return out
