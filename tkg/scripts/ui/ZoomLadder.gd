class_name ZoomLadder
extends Control

## ONE PICTURE, FOUR DISTANCES (Jon picked C on "Where LOCAL fits", Oct 8: "Let's
## go with that, but the transitions need to be MUCH better than a simple
## fade"). The star chart, the sector map, LOCAL and the station are one camera
## at four distances, and moving between them is a camera move centred on your
## ship (or your star), never a cut.
##
## THE SCREENS STAY FOUR SCREENS. Each is drawn by its own renderer with its own
## palette and tone, and they are coordinated rather than merged: a move is
##   1. PRE-ROLL: the screen being left moves its own camera, live, toward the
##      next distance (the map zooms onto your ship, the chart onto your star,
##      LOCAL pulls back, or pushes in on the station's ring);
##   2. THE HANDOFF: its last frame is held (the Router frees it as it always
##      did), and the screen arriving is built underneath, its own camera placed
##      at the matching distance;
##   3. THE MOVE: the arriving screen's camera eases to rest, live, while the
##      held picture is carried with it -- scaled by exactly the arriving camera's
##      own change of scale, its anchor riding the arriving anchor -- and taken
##      away in the dither of the design picked for that seam (`zoom_ladder`).
## So the two renderers never have to agree on a pixel: the held picture moves
## the way the live one does, and the handoff is a dither, not an alpha.
##
## THE SEAMS AND THEIR DESIGNS, the first of each the default:
##   1 chart <-> map:    A the system opens out of your star (an iris);
##                       B the chart's stars stream past, dark first;
##                       C mosaic blocks.
##   2 map <-> LOCAL:    A dive past your ship; B the map lies down into LOCAL's
##                       plane; C the world you orbit carried into LOCAL's.
##   3 LOCAL <-> station: A through the ring; B your hull carried to its berth;
##                       C mosaic blocks.
## Two distances apart (LOCAL <-> chart, map <-> station) is one dive.
##
## THE SWITCHES. `[flow] ladder=false` in settings.cfg, or `-- flow=legacy`, is
## today's flow (the alpha's fallback); `[flow] seam1=B` (seam2, seam3) or
## `-- flow1=B` picks a design. Off under reduced motion and wherever
## `Router.animating()` is false, so every harness and the sim take the plain
## swap they always took. Any key or click during a move finishes it at once,
## and is not eaten.

enum { CHART = 0, MAP = 1, LOCAL = 2, STATION = 3 }

const SECTION := "flow"
const DESIGNS := {1: ["A", "B", "C"], 2: ["A", "B", "C"], 3: ["A", "B", "C", "D"]}
## Jon's picks (Oct 8): 1A toned down, 2C smoothed, 3B with the hull flying in.
const DEFAULTS := {1: "A", 2: "C", 3: "B"}
## what each design is called where a person picks one (Settings, the sheet)
const NAMES := {
	"1A": "STAR OPENS", "1B": "STARS STREAM", "1C": "MOSAIC",
	"2A": "DIVE PAST THE SHIP", "2B": "INTO THE PLANE", "2C": "WORLD HANDOFF",
	"3A": "THROUGH THE RING", "3B": "INTO THE HANGAR, BULKHEAD", "3C": "MOSAIC",
	"3D": "INTO THE HANGAR",
}
## how long the screen being left moves first, and how long the move takes, s
const PRE_S := 0.38
const MOVE_S := 0.72
## how long an arriving screen may take to be ready before the move goes anyway
const WAIT_MAX_S := 1.2
## 3B AT THE DRUM, in seconds (Jon: "it's an arrival, let it breathe"):
## LOCAL, your ship from where it sits into the hallway's bay as the station's
## lights come on to meet it (`SectorScreen.HALL_*` split this up)
const DOCK_APPROACH_S := 3.6
## the camera's pan sideways through the station's hull into the yard
const DOCK_PAN_S := 1.4
## the yard: your ship in from the left onto its stands (and then the elevator,
## `StationScreen.ELEVATOR_S`)
const DOCK_YARD_S := 1.8
## undocking: the elevator out, your ship off its stands and away to the left
const UNDOCK_YARD_S := 1.6
## and LOCAL: your ship backing out of the hallway to where it sat, the lights
## going down behind it (after the same pan the other way)
const UNDOCK_LOCAL_S := 3.0
## how much of the station's hull the pan passes through (game px)
const PAN_HULL_W := 520.0
## THE HAND-OFF INTO THE YARD (3B). "F", Jon's pick and the default: a dip to
## black once your ship is out of sight in the hull; the EMPTY yard comes up
## from black slowly (Jon: "let's have the yard show up without our ship
## first" -- "and the black should slowly fade out"), holds a beat, and your
## ship -- travelling all along, off the picture -- comes in from the left and
## lands; then the elevator. Undocking: the elevator out, your ship off its
## stands and away to the left, a beat of the empty yard, the yard slowly down
## to black, and up on LOCAL with your ship coming out of the hull. "P", kept
## as the alternative: the pan through the hull. `[flow] seam3_fade=`.
const FADES := ["F", "P"]
static var force_fade := ""
## F: the dip to black at the approach's end (s); the empty yard up from black,
## and its beat before your ship comes in; LOCAL up from black undocking
const FADE_DOWN := 0.4
const YARD_FADE_S := 1.0
const YARD_BEAT_S := 0.4
const LOCAL_FADE_S := 0.5


static func seam3_fade() -> String:
	if force_fade in FADES:
		return force_fade
	var a := _arg("seam3_fade").to_upper()
	if a in FADES:
		return a
	_read_cfg()
	var v := String(_cfg.get("seam3_fade", "F")).to_upper()
	return v if v in FADES else "F"


## A Hermite curve from 0 to 1 over u 0..1, leaving at slope `m0` and arriving at
## slope `m1` (in units of its whole length over its whole time): ONE SMOOTH
## MOTION's pieces, each starting at the speed the last one ended on.
static func herm(u: float, m0: float, m1: float) -> float:
	u = clampf(u, 0.0, 1.0)
	var u2 := u * u
	var u3 := u2 * u
	return (u3 - 2.0 * u2 + u) * m0 + (-2.0 * u3 + 3.0 * u2) + (u3 - u2) * m1
## the wheel past a screen's end: this many notches, this close together
const OVERSCROLL_N := 2
const OVERSCROLL_S := 0.7
const SHADER := preload("res://shaders/zoom_ladder.gdshader")

## The move under way, if any.
static var active: ZoomLadder = null
## A harness steps the move by this many seconds a frame (frames filmed at 30
## fps then play at true speed however slowly the window drew); <= 0: real time.
static var fixed_dt := -1.0
## A harness's real-time trace: microseconds spent this frame, by what (`probe_add`;
## the harness reads and clears it each frame). Off unless a harness turns it on.
static var probe_on := false
static var probe := {}
## A screen swap in the middle of a move leaves the autosave to the move's end
## (`Router._swap`): writing the run is ~15 ms of one frame, and mid-move that
## frame shows.
static var save_after := false


static func probe_add(k: String, us: int) -> void:
	if probe_on:
		probe[k] = int(probe.get(k, 0)) + us
## A harness's override of the switch: 1 on, 0 off, -1 the setting.
static var force := -1
## And of a seam's design: seam -> letter.
static var force_design := {}
## The Router's own call, being made by a pre-roll's end: `preroll` declines it.
static var _going := false
static var _cfg_read := false
static var _cfg := {}
static var _over_n := 0
static var _over_dir := 0
static var _over_t := 0

enum Phase { PRE, PRE_DONE, WAIT, MOVE }
var phase: Phase = Phase.PRE
var old: Control = null
var new: Control = null
var r_old := -1
var r_new := -1
var seam := 0
var design := "A"
var _then: Callable
var _u := 0.0
var _waited := 0.0
var _pre_k := 0.0
var _rect: ColorRect
var _mat: ShaderMaterial
var _tex: ImageTexture
## the held picture: its anchor, its picture rect, the arriving camera's scale
## when the move began
var _a_old := Vector2.ZERO
var _pic := Rect2()
var _s0 := 1.0
var _style := {}
## THE ONE CURVE (`_style.curve`): both halves of a move -- the old screen's
## own camera, then the held picture and the new screen's camera -- ride a single
## smoothstep over `_T` seconds, split at `_F` of the motion, so there is no stop
## and no change of speed at the handoff. `_tau` is the time into it.
var _T := 1.0
var _F := 0.5
var _tau := 0.0
var _g_last := 0.0
var _pre_s := PRE_S
var _move_s := MOVE_S
## the held picture's own growth (log scale) over the second half, for the
## frame(s) before the new screen is ready
var _l_move := 0.0
## the hull carried over (3B): the art, its rect in each picture
var _hull: TextureRect = null
var _hull_from := Rect2()
var _hull_to := Rect2()
var _hull_tex: Texture2D = null
## what the held picture's screen said about itself as it went (it is freed at
## the end of the swap's frame, so nothing is asked of it after)
var _old_plane := {}
var _old_world := {}
## the arriving screen placed its camera on the held picture's anchor
var _met := false
## 1A: the map's sun as the held picture had it (coming out)
var _old_sun := {}
## 2C: where LOCAL will have the world, for the frame(s) before it is up
var _rest_est := Vector2.INF
## 2C: the map's own world node, given at the swap ({} once taken or for none)
var _given := {}
var _taken := false
## A harness's measurement: the first frame after the swap shows the arriving
## screen exactly where the held picture was (no motion, the world's clock the
## map's), so the two can be diffed pixel for pixel.
static var measure_hold := false
var _held_frames := 0
## the screen left moved first (the move then starts at speed)
var _had_pre := false


# ------------------------------------------------------------------ settings

static func _read_cfg() -> void:
	if _cfg_read:
		return
	_cfg_read = true
	var cf := ConfigFile.new()
	if cf.load(DisplaySettings.path) == OK and cf.has_section(SECTION):
		for k in cf.get_section_keys(SECTION):
			_cfg[k] = cf.get_value(SECTION, k)


## Read the switches again (Settings wrote them).
static func reload() -> void:
	_cfg_read = false
	_cfg.clear()


static func _arg(k: String) -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(k + "="):
			return (a as String).substr(k.length() + 1)
	return ""


## Whether C's flow is on (the setting, or a harness's `flow=`), animation aside.
static func chosen() -> bool:
	if force >= 0:
		return force == 1
	var a := _arg("flow")
	if a == "legacy" or a == "off":
		return false
	if a == "c" or a == "on":
		return true
	# A HARNESS takes today's flow unless it asks (`flow=c`): every test written
	# before the ladder expects the doors it was written against
	if TestRun.active():
		return false
	_read_cfg()
	return bool(_cfg.get("ladder", true))


static func enabled() -> bool:
	return chosen() and not hold_off and Router.animating()


## Set for the length of a call that must be instant (a skip).
static var hold_off := false


static func design_for(s: int) -> String:
	if force_design.has(s):
		return String(force_design[s])
	var a := _arg("flow%d" % s).to_upper()
	if a in DESIGNS.get(s, []):
		return a
	_read_cfg()
	var v := String(_cfg.get("seam%d" % s, DEFAULTS.get(s, "A"))).to_upper()
	return v if v in DESIGNS.get(s, []) else String(DEFAULTS.get(s, "A"))


static func save_setting(key: String, value: Variant) -> void:
	var cf := ConfigFile.new()
	cf.load(DisplaySettings.path)
	cf.set_value(SECTION, key, value)
	cf.save(DisplaySettings.path)
	reload()


static func rank_of(s: Control) -> int:
	if s == null or not is_instance_valid(s):
		return -1
	if s is StarchartScreen:
		return CHART
	if s is SystemMapScreen:
		return MAP
	if s is SectorScreen:
		return LOCAL
	if s is StationScreen:
		return STATION
	return -1


## Which seam a move crosses, or 0 for one two distances long (a dive).
static func seam_between(a: int, b: int) -> int:
	if absi(a - b) != 1:
		return 0
	return mini(a, b) + 1


## WHERE LOCAL DRAWS THE WORLD YOU ORBIT, at rest, by system and world: what the
## map aims the world at on its way in (2C), so it is already heading where LOCAL
## will have it. Kept as LOCAL is seen; before that, LocalSky's own rule.
static var world_rest := {}


static func rest_world(node_index: int, body: SystemLayout.Body) -> Dictionary:
	var key := "%d:%d" % [node_index, body.index]
	if world_rest.has(key):
		return world_rest[key]
	var giant := body.kind == &"giant"
	var R := roundf((LocalSky.NEAR_GIANT_R if giant else LocalSky.NEAR_WORLD_R) \
		* clampf(body.r / (22.0 if giant else 12.0), 0.8, 1.25) / 2.0) * 2.0
	return {"c": Vector2(698.0, 339.0 + 0.2 * R), "r": R}


static func busy() -> bool:
	return active != null and is_instance_valid(active)


## THE WHEEL PAST THE END OF A SCREEN'S ZOOM: true on the notch that should take
## the next distance. `dir` +1 in, -1 out.
static func overscroll(dir: int) -> bool:
	if not enabled() or busy():
		return false
	var now := Time.get_ticks_msec()
	if dir != _over_dir or now - _over_t > int(OVERSCROLL_S * 1000.0):
		_over_n = 0
	_over_dir = dir
	_over_t = now
	_over_n += 1
	if _over_n >= OVERSCROLL_N:
		_over_n = 0
		return true
	return false


## A SIDE PANEL off the edge of the screen by k (0 where it stands, 1 gone right),
## in whole pixels; `x` is where it stands. Chrome slides, it does not fade.
static func slide(c: Control, x: float, k: float) -> void:
	if c == null or not is_instance_valid(c) or is_nan(x):
		return
	var kk := clampf(k * 1.4, 0.0, 1.0)
	c.position.x = roundf(x + kk * kk * (c.size.x + 12.0))
	# at rest, its container places it again (as it would have)
	if k <= 0.0 and c.get_parent() is Container:
		(c.get_parent() as Container).queue_sort()


# ------------------------------------------------------------------ the doors

## A move toward distance `target` is about to be asked of the Router: the
## screen being left moves its camera first, and `then` (the Router's own call)
## runs when it has. False: go now (no ladder, or nothing to move).
static func preroll(target: int, then: Callable) -> bool:
	if _going or not enabled():
		return false
	# (the jump's own flare is the cut on its far side)
	if Router._post_arrive:
		return false
	var cur := Router.current
	var r := rank_of(cur)
	if r < 0 or r == target or not cur.has_method(&"ladder_cam"):
		return false
	if busy():
		active.finish_now()
	var lad := _make()
	lad.old = cur
	lad.r_old = r
	lad.r_new = target
	lad.seam = seam_between(r, target)
	lad.design = design_for(lad.seam) if lad.seam > 0 else "A"
	lad._then = then
	lad._pre_k = float(cur.call(&"ladder_pre", target, lad.seam, lad.design))
	if lad._pre_k <= 0.0:
		active = null
		lad.queue_free()
		return false
	lad._had_pre = true
	lad._style = lad._style_for()
	lad._pre_s = float(lad._style.get("pre_s", PRE_S))
	lad._move_s = float(lad._style.get("move_s", MOVE_S))
	lad._T = lad._pre_s + lad._move_s
	lad._F = lad._pre_s / lad._T
	cur.call(&"ladder_cam_begin", target, lad.seam, lad.design)
	# THE MAP BUILT WHILE THE OLD SCREEN MOVES (Jon on 1A: "it hitches"): its
	# system drawn and its sky baked out of sight during the pre-roll, so it is
	# up the frame it is asked for and the move never waits on it
	# (drawn, but not seen: its pictures have to be drawn to finish -- the map's
	# palette is cut from its own first frames -- so it stands in the tree at no
	# opacity, under nothing it could take a click from for long)
	var _pt_pre := Time.get_ticks_usec()
	if (target == MAP or target == CHART) and not Run.map.is_empty() and Router.content != null:
		var pm: Control = SystemMapScreen.new() if target == MAP else StarchartScreen.new()
		pm.modulate.a = 0.0
		pm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# (laid out where the screens are, with nothing beside it: under this
		# ladder, which stands exactly over the screens' place)
		lad._fit()
		lad.add_child(pm)
		lad.move_child(pm, 0)
		pm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if pm is SystemMapScreen:
			(pm as SystemMapScreen).show_system(Run.node_at(), 0.0, false)
		else:
			(pm as StarchartScreen).setup()
		prebuilt = pm
		ZoomLadder.probe_add("prebuild", Time.get_ticks_usec() - _pt_pre)
	# LOCAL TOO, ON 2C (Jon: "2C still has a small delay/hitch"): built here, at
	# the click, before anything has moved, instead of at the swap in the middle
	# of the dive, where building it took 60-90 ms of one frame. Not when LOCAL
	# would play something as it is built -- an event opening, a fight, a jump's
	# arrival or departure, undocking -- which would play out unseen
	elif target == LOCAL and lad.seam == 2 and lad.design == "C" and _local_quiet() and Router.content != null:
		var ps := SectorScreen.new()
		ps.modulate.a = 0.0
		ps.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lad._fit()
		lad.add_child(ps)
		lad.move_child(ps, 0)
		ps.setup(null)
		prebuilt = ps
		ZoomLadder.probe_add("prebuild", Time.get_ticks_usec() - _pt_pre)
	# 3B TOO, BOTH WAYS (one smooth motion: the screen arriving was built at the
	# swap, a quarter of a second stood still in the middle of the move): the
	# yard built at DOCK, before anything moves, and held still (not ticking, so
	# none of its sound starts) until it is shown; LOCAL built at UNDOCK
	elif target == STATION and lad.seam == 3 and lad.design == "B" and Router.content != null and not Router.in_combat():
		var ss := StationScreen.new()
		ss.modulate.a = 0.0
		ss.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lad._fit()
		lad.add_child(ss)
		lad.move_child(ss, 0)
		ss.setup()
		ss.process_mode = Node.PROCESS_MODE_DISABLED
		ss.set_meta(&"ladder_at", Run.at)
		prebuilt = ss
		# (and its room's tone, loaded while LOCAL moves)
		var rn: Variant = Router._room_for(ss)
		if rn != null:
			Audio.warm_room(StringName(rn))
	elif target == LOCAL and lad.seam == 3 and lad.design == "B" and Router.content != null and _local_quiet(true):
		# (leaving a berth is arriving at the system it is in: `Router.show_local`)
		SectorScreen._approached_at = Run.at
		var pl := SectorScreen.new()
		pl.modulate.a = 0.0
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lad._fit()
		lad.add_child(pl)
		lad.move_child(pl, 0)
		pl.setup(null)
		prebuilt = pl
	# the motion's split, from how far each half travels (log scale), so the
	# speed is the same on both sides of the handoff
	if bool(lad._style.get("curve", false)) and cur.has_method(&"ladder_spans"):
		var sp: Vector2 = cur.call(&"ladder_spans")
		if sp.x > 0.01 and sp.y > 0.01:
			lad._F = clampf(sp.x / (sp.x + sp.y), 0.35, 0.9)
			lad._l_move = sp.y * (1.0 if target > r else -1.0)
	# (and the screen being left told how much of the way across it carries the
	# thing it closes on, so the next screen carries the rest at the same speed)
	if bool(lad._style.get("curve", false)) and cur.has_method(&"ladder_split"):
		cur.call(&"ladder_split", lad._F)
	lad.phase = Phase.PRE
	return true


## Called by `Router._swap` before the old screen goes: hold its picture.
static func capture(o: Control, n: Control) -> void:
	if not enabled():
		if busy():
			active.finish_now()
		return
	var ro := rank_of(o)
	var rn := rank_of(n)
	var lad: ZoomLadder = null
	if busy() and active.phase == Phase.PRE_DONE and active.old == o:
		lad = active
	elif busy():
		active.finish_now()
	if ro < 0 or rn < 0 or ro == rn or Router._post_arrive:
		if lad != null:
			lad._end()
		return
	if lad == null:
		lad = _make()
		lad.old = o
		lad.r_old = ro
		lad.seam = seam_between(ro, rn)
		lad.design = design_for(lad.seam) if lad.seam > 0 else "A"
	lad.r_new = rn
	lad.new = n
	if not lad._had_pre:
		lad._style = lad._style_for()
		lad._move_s = float(lad._style.get("move_s", MOVE_S))
		lad._pre_s = 0.0
		lad._T = lad._move_s
		lad._F = 0.0
	var th := Time.get_ticks_usec()
	lad._hold()
	probe_add("hold", Time.get_ticks_usec() - th)
	# A SCREEN BUILT AHEAD is up already: the move goes on this very frame, so
	# the frame of the swap is not a frame the picture stands still
	# (deferred to the end of this frame: the Router has not put it in its place
	# yet, and where it is decides where its anchor is)
	if lad.phase == Phase.WAIT and n.has_method(&"ladder_ready") and bool(n.call(&"ladder_ready")):
		lad._start_move.call_deferred()


## Whether the Router should leave this screen's arrival to the ladder (no fade).
static func takes(s: Control) -> bool:
	return busy() and active.new == s


static func _make() -> ZoomLadder:
	var lad := ZoomLadder.new()
	active = lad
	var root: Node = Router.content.get_viewport() if Router.content != null else null
	if root != null:
		root.add_child(lad)
		# the first-run intro's words stay over the move
		if FirstRunIntro.playing != null and is_instance_valid(FirstRunIntro.playing) \
				and FirstRunIntro.playing.get_parent() == root:
			root.move_child(FirstRunIntro.playing, -1)
	return lad


# ------------------------------------------------------------------ the move

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


func _fit() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(960, 540))
	if Router.content != null and is_instance_valid(Router.content):
		r = Router.content.get_global_rect()
	position = r.position
	size = r.size
	_rect.position = Vector2.ZERO
	_rect.size = r.size
	_mat.set_shader_parameter(&"rect_pos", r.position)
	_mat.set_shader_parameter(&"rect_size", r.size)


## (a long frame -- a screen being built -- holds the move for that frame rather
## than jumping it on: no step is ever more than a 30th of a second)
func _dt(delta: float) -> float:
	if fixed_dt > 0.0:
		return fixed_dt
	# (2C: a frame far longer than its neighbours -- something built, a cache
	# filled -- counts as one ordinary frame, so the move waits it out and goes
	# on from where it was instead of jumping a stretch of it)
	if bool(_style.get("wait_long", false)) and delta > 1.0 / 24.0:
		return 1.0 / 60.0
	return minf(delta, 1.0 / 30.0)


static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## Ease out (fast start, long settle): the camera's own curve.
static func _ease_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


func _process(delta: float) -> void:
	var dt := _dt(delta)
	var curve := bool(_style.get("curve", false))
	match phase:
		Phase.PRE:
			if not is_instance_valid(old) or Router.current != old:
				_end()
				return
			if curve:
				_tau += dt
				var g := _ease(_tau / _T)
				# (handed over BEFORE this frame moves the old camera: the picture
				# held is the frame it last drew, and what it says of itself --
				# anchors, its world -- must be of that same frame)
				if g >= _F:
					# (the second half runs on from where the last drawn frame was)
					_F = _g_last
					_fire()
					return
				old.call(&"ladder_cam", _pre_k * clampf(g / maxf(_F, 0.001), 0.0, 1.0))
				_g_last = g
				_place_bar(g)
				if old.has_method(&"ladder_peek"):
					old.call(&"ladder_peek")
				return
			_u += dt / maxf(_pre_s, 0.001)
			# eased IN: the move that follows starts at speed, so the two halves
			# are one motion with no stop at the handoff
			var ui := clampf(_u, 0.0, 1.0)
			old.call(&"ladder_cam", _pre_k * (ui if bool(_style.get("pan", false)) else ui * ui))
			if String(_style.get("fade", "")) == "F":
				# (F: down to black over the pre-roll's last stretch -- docking, your
				# ship already out of sight in the hull; undocking, the empty yard,
				# slowly)
				var fd := FADE_DOWN if old is SectorScreen else YARD_FADE_S
				_black_at(_ease(clampf((_u * _pre_s - (_pre_s - fd)) / fd, 0.0, 1.0)))
			if _u >= 1.0:
				# (the move goes on from where the clock is, not a frame later)
				_pan_t0 = (_u - 1.0) * _pre_s
				_fire()
		Phase.WAIT:
			_waited += dt
			if not is_instance_valid(new):
				_end()
				return
			# (1A waits for the map with the chart's star held where it is: the
			# map's sun has to be there to take over from it, so the clock waits too)
			if curve and not measure_hold and not bool(_style.get("sun", false)):
				# the clock runs on, and the held picture with it
				_tau += dt
				var ew := _curve_e()
				_mat.set_shader_parameter(&"scl", Vector2.ONE * exp(_l_move * ew))
				# (and on along its line, so the frame before LOCAL is up is not a stop)
				if _rest_est != Vector2.INF:
					_mat.set_shader_parameter(&"to_pt", _a_old.lerp(_rest_est, ew))
				# (the bulkhead never waits on the screen behind it)
				_place_bar(_ease(_tau / maxf(_T, 0.001)))
			if bool(new.call(&"ladder_ready")) or _waited >= WAIT_MAX_S:
				_start_move()
		Phase.MOVE:
			if not is_instance_valid(new):
				_end()
				return
			if bool(_style.get("pan", false)):
				_u += dt
				_step_pan(_u)
				if _u >= _move_s:
					_end()
				return
			if curve:
				if measure_hold and _held_frames < 1:
					_held_frames += 1
					return
				_tau += dt
				_step(_curve_e())
				_place_bar(_ease(_tau / maxf(_T, 0.001)))
				if _tau >= _T:
					_end()
				return
			_u += dt / maxf(_move_s, 0.001)
			_step(_u)
			if _u >= 1.0:
				_end()


## How far into the second half of the one curve the clock is (0 to 1).
func _curve_e() -> float:
	var g := _ease(_tau / maxf(_T, 0.001))
	return clampf((g - _F) / maxf(1.0 - _F, 0.001), 0.0, 1.0)


## The pre-roll is done (or skipped): make the Router's call.
func _fire() -> void:
	if phase != Phase.PRE:
		return
	phase = Phase.PRE_DONE
	var cb := _then
	_then = Callable()
	_going = true
	var t0 := Time.get_ticks_usec()
	cb.call()
	probe_add("door", Time.get_ticks_usec() - t0)
	_going = false
	# the call did not swap (refused on its own terms): the old screen stays, at rest
	if phase == Phase.PRE_DONE:
		if is_instance_valid(old):
			old.call(&"ladder_cam", 0.0)
			old.call(&"ladder_cam_end")
		_end()


func _input(e: InputEvent) -> void:
	var press := (e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo) \
		or (e is InputEventMouseButton and (e as InputEventMouseButton).pressed
			and (e as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE])
	if not press:
		return
	# NOT EATEN: the move ends where it was going and the press does what it does
	finish_now()


## Straight to the end of the move.
func finish_now() -> void:
	match phase:
		Phase.PRE:
			_fire()
			if phase == Phase.WAIT:
				_start_move()
			if phase == Phase.MOVE:
				_step_last()
				_end()
		Phase.WAIT:
			_start_move()
			_step_last()
			_end()
		Phase.MOVE:
			_step_last()
			_end()
		_:
			_end()


## The old screen's last frame, held; where its anchor and picture were.
func _hold() -> void:
	_fit()
	var vp := get_viewport()
	# (headless there is no picture to read, only the moves to run)
	var img: Image = null
	if vp != null and vp.get_texture() != null and DisplayServer.get_name() != "headless":
		img = vp.get_texture().get_image()
	if img == null or img.is_empty():
		img = Image.create(960, 540, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(img)
	_a_old = old.call(&"ladder_anchor", r_new, seam, design)
	# (3B's one motion: the speed the screen being left hands on, and where its
	# hull tiled)
	if old.has_method(&"ladder_track_speed"):
		_v_old = float(old.call(&"ladder_track_speed", UNDOCK_YARD_S * 0.7 if old is StationScreen else _pre_s))
	if old.has_method(&"ladder_hull_at"):
		_hull_at_old = old.call(&"ladder_hull_at")
	_pic = old.call(&"ladder_picture")
	if old.has_method(&"ladder_hull"):
		_hull_from = old.call(&"ladder_hull")
	if old.has_method(&"ladder_hull_texture"):
		_hull_tex = old.call(&"ladder_hull_texture")
	if old.has_method(&"ladder_plane"):
		_old_plane = old.call(&"ladder_plane")
	if old.has_method(&"ladder_world"):
		_old_world = old.call(&"ladder_world")
	_mat.set_shader_parameter(&"hole", Vector3.ZERO)
	if old.has_method(&"ladder_sun"):
		_old_sun = old.call(&"ladder_sun")
	if old.has_method(&"ladder_rest"):
		_rest_est = old.call(&"ladder_rest")
	if bool(_style.get("world", false)) and seam == 2 and r_new > r_old and old.has_method(&"ladder_give_world"):
		_given = old.call(&"ladder_give_world")
	_mat.set_shader_parameter(&"old_tex", _tex)
	_mat.set_shader_parameter(&"old_lin", _tex)
	_mat.set_shader_parameter(&"vp", Vector2(img.get_width(), img.get_height()))
	_mat.set_shader_parameter(&"pic", Vector4(_pic.position.x, _pic.position.y, _pic.size.x, _pic.size.y))
	_mat.set_shader_parameter(&"from_pt", _a_old)
	_mat.set_shader_parameter(&"to_pt", _a_old)
	_mat.set_shader_parameter(&"scl", Vector2.ONE)
	_mat.set_shader_parameter(&"mode", 0)
	_mat.set_shader_parameter(&"t", 0.0)
	_mat.set_shader_parameter(&"chrome_t", 0.0)
	_mat.set_shader_parameter(&"block", 1.0)
	_rect.visible = true
	_u = 0.0
	_waited = 0.0
	phase = Phase.WAIT
	_style = _style_for()
	# ON THE ONE CURVE THE SWAP'S OWN FRAME MOVES TOO: the clock has already run
	# on this frame (the pre-roll's last step was this frame's), so the held
	# picture is drawn where the curve has it, not stopped for a frame
	if bool(_style.get("curve", false)) and not measure_hold and _had_pre:
		var ew := _curve_e()
		_mat.set_shader_parameter(&"scl", Vector2.ONE * exp(_l_move * ew))
		if _rest_est != Vector2.INF:
			_mat.set_shader_parameter(&"to_pt", _a_old.lerp(_rest_est, ew))


## What the move looks like: the dither's mode and how the held picture travels.
func _style_for() -> Dictionary:
	var inward := r_new > r_old
	var s := {"mode": 0, "spread": 0.7 if inward else -0.7, "extra": 1.0, "reach": 520.0,
		"axis": Vector2.ONE, "chrome": 0.45, "block": 0.0, "plane": false, "world": false, "hull": false}
	if seam == 0:
		s.extra = 3.0 if inward else 0.3
	# a picture going small loses its own edge first (`edge`), and is taken on
	# the camera's own curve, fast at first
	s["edge"] = 0.0 if inward else 1.8
	s["fast"] = not inward and _had_pre
	s.reach = 420.0
	match "%d%s" % [seam, design]:
		"1A":
			# YOUR STAR HANDED OVER (Jon: "zoom in on the star icon on the star chart
			# and THAT transitions into the star in the sector map"): the chart
			# closes on your system's star; the map arrives so far out that its sun
			# is the size of the chart's star and on it; the held chart has a hole
			# exactly the size of the live sun, so the icon becomes the sun, and
			# the system opens round it as the chart thins away, one curve
			s.curve = true
			s.soft = true
			s.sharp = true
			s.sun = true
			s.pre_s = 0.4
			s.move_s = 0.7
			s.reach = 340.0
			s.t_from = 0.0
			s.t_to = 0.9
			if inward:
				s.spread = 0.8
			else:
				s.spread = -0.9
				s.extra = 0.9
		"1B":
			s.mode = 2
			s.extra = 3.0 if inward else 0.6
		"1C", "3C":
			s.mode = 3
			s.block = 12.0
			s.extra = 1.6 if inward else 0.7
		"2B":
			s.plane = true
			s.spread = -0.8
			s.axis = Vector2(40.0, 1.0)
			s.reach = 260.0
		"2C":
			# SMOOTHED (Jon: "the transition can be smoother"): one curve with the
			# same speed both sides of the handoff, the world's size and place
			# carried exactly, the held picture sampled between its pixels so it
			# slides rather than steps, and taken away by a soft edge from the
			# outside in, the world itself last
			s.world = true
			s.curve = true
			s.soft = true
			s.sharp = true
			s.spread = -0.75
			s.edge = 0.0
			s.reach = 380.0
			s.pre_s = 0.7
			s.move_s = 0.45
			s.t_from = 0.05
			s.t_to = 0.95
			s.wait_long = true
		"3A":
			if inward:
				s.mode = 1
				s.axis = Vector2(1.0, 0.45)
				s.reach = 900.0
				s.extra = 2.5
				s.rim = 8.0
			else:
				s.spread = -0.85
				s.extra = 0.6
		"3B", "3D":
			# INTO THE HANGAR (Jon: "the station becomes something on the far right
			# of the screen that the ship flies into .... and THAT becomes the
			# shipyard"): LOCAL draws the station's side with its hallway at your
			# height (`StationFace`); your ship flies into it and the camera after
			# it. 3B: once your ship is all inside, the camera pans sideways through
			# the station's own hull into the yard (`_step_pan`). 3D: on
			# into the mouth until the hangar fills the picture, and across into the
			# yard by a soft edge. In the yard your ship flies in from the left onto
			# its stands, and then the elevator slides in (`StationScreen`).
			# Undocking runs it all the other way.
			s.soft = true
			s.spread = 0.8 if inward else -0.8
			s.reach = 520.0
			s.extra = 1.0
			s.edge = 0.0
			s.pin = true
			if design == "B":
				# THE ARRIVAL (Jon: "let it breathe"): the approach on LOCAL is the
				# pre-roll docking, linear (LOCAL eases its own phases); then the
				# camera pans sideways through the station's hull (`_step_pan`) into
				# the yard, where your ship flies in onto its stands. Undocking runs
				# it the other way. A long frame waits.
				s.pan = true
				s.wait_long = true
				s.fade = seam3_fade()
				var f := String(s.fade) == "F"
				s.pre_s = DOCK_APPROACH_S if inward else UNDOCK_YARD_S + (YARD_BEAT_S + YARD_FADE_S if f else 0.0)
				if f:
					s.move_s = YARD_FADE_S + YARD_BEAT_S + DOCK_YARD_S if inward else UNDOCK_LOCAL_S
				else:
					s.move_s = DOCK_PAN_S + (DOCK_YARD_S if inward else UNDOCK_LOCAL_S)
			else:
				s.pre_s = 0.75 if inward else 0.85
				s.move_s = 1.4 if inward else 0.8
				s.t_from = 0.0
				s.t_to = 0.4 if inward else 0.6
			# (no eaten edge: the hangar and the sky cross by the soft edge alone;
			# and the held picture stays where it was, the hull being what travels)
			s.edge = 0.0
			s.pin = true
	return s


## THE BULKHEAD (3B): the station's own dark structure passing close to the
## camera, a slab of its steel lit along its edges, swept across the picture on
## the move's one curve so it covers the whole of it at the handoff.
class Bulkhead extends Control:
	var x := 0.0
	var w := 1600.0
	## which way it travels: -1 right to left (docking), 1 left to right
	var dir := -1.0
	const STEEL := [Color("#0c0f15"), Color("#121620"), Color("#1a1f2b"), Color("#262c3a"), Color("#3a4152"), Color("#5c6376")]
	const WARM := Color("#ffa63c")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(x, 0, w, size.y)
		draw_rect(r, STEEL[1], true)
		# its plates, side on: tall panels and their seams
		var px := x + 30.0
		var i := 0
		while px < x + w - 10.0:
			var pw := 70.0 + float((i * 37) % 60)
			draw_rect(Rect2(px, 0, 1, size.y), STEEL[0], true)
			draw_rect(Rect2(px + 1, 0, 1, size.y), STEEL[2], true)
			for ry in range(int(size.y / 28.0) + 1):
				draw_rect(Rect2(px + 6, 10 + ry * 28, 2, 2), STEEL[3], true)
			px += pw
			i += 1
		# the edge leading into the light from the hangar, warm, stepped in;
		# the trailing edge cold, the star's
		var lead := x if dir < 0.0 else x + w - 1.0
		var trail := x + w - 1.0 if dir < 0.0 else x
		var sgn := 1.0 if dir < 0.0 else -1.0
		draw_rect(Rect2(lead, 0, 1, size.y), WARM.lerp(STEEL[5], 0.3), true)
		draw_rect(Rect2(lead + sgn, 0, 1, size.y), STEEL[5], true)
		for k in 6:
			var c := STEEL[4].lerp(STEEL[1], float(k) / 6.0)
			var th := [0.0, 0.5, 0.75, 0.25]
			var col := lead + sgn * float(2 + k)
			for yy in int(size.y):
				if th[(int(col) % 2) + (yy % 2) * 2] < 0.6 - 0.1 * float(k):
					draw_rect(Rect2(col, yy, 1, 1), c, true)
		draw_rect(Rect2(trail, 0, 1, size.y), STEEL[3], true)


var _bar: Bulkhead = null


# ------------------------------------------------------------------ the pan (3B)

## THE PAN THROUGH THE STATION (3B, Jon: "When the LAST part of the ship (its
## tail) has gone in behind the lip, the screen PANS"): the camera slides
## sideways -- the held picture out to the left, the station's own hull close
## past the camera (`StationFace.draw_hull`), and the screen arriving in from the
## right behind it -- and stops on the yard, the hull gone past (Jon: no
## station in the yard), the yard's own hall running on where the elevator will
## slide in (`StationScreen`'s yard edge). Undocking pans the other way.
var _pan_view: _PanView = null
var _pan_x0 := 0.0
var _pan_vr := 0.0
var _hull_at_old := Vector2.INF


class _PanView extends Control:
	var tex: Texture2D
	var src := Rect2()
	var held_x := 0.0
	var slab_x := 0.0
	var slab_w := 520.0
	var row_y := 270.0
	## where the hull's panels tile (this view's px), as LOCAL's drum tiles them
	var tile_x0 := 0.0
	var show_held := true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		if tex != null and show_held:
			draw_texture_rect_region(tex, Rect2(Vector2(roundf(held_x), 0), src.size), src)
		StationFace.draw_hull(self, Rect2(roundf(slab_x), 0, slab_w, size.y), roundf(tile_x0), row_y)


## the move's own clock where the pre-roll left it (s), and the speeds the two
## screens hand on at the seam (screen px a second)
var _pan_t0 := 0.0
var _v_old := 0.0
var _v_new := 0.0
var _hull_x0 := 0.0
var _black: ColorRect = null


## The dip to black (F) or the pan's shadow (PF): `a` of black over the screens.
func _black_at(a: float) -> void:
	if _black == null:
		if a <= 0.0:
			return
		_fit()
		_black = ColorRect.new()
		_black.color = Color(0, 0, 0, 0)
		_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_black)
	# (side to side the whole window: the yard's hall run on into the elevator's
	# column reaches past this box's left edge, into the margin)
	var vw := get_viewport_rect().size.x
	var gx := get_global_rect().position.x
	_black.position = Vector2(-gx, 0.0)
	_black.size = Vector2(maxf(vw, gx + size.x), size.y)
	_black.color.a = clampf(a, 0.0, 1.0)
	move_child(_black, -1)


func _start_pan() -> void:
	new.call(&"ladder_cam_begin", r_old, seam, design)
	new.call(&"ladder_cam", 1.0)
	_fit()
	_rect.visible = false
	_pan_x0 = new.position.x
	var inward := r_new > r_old
	# (the hull starts at LOCAL's picture's right edge, over the strip beside it)
	var pic: Rect2 = _pic if inward else new.call(&"ladder_picture")
	_pan_vr = clampf(pic.end.x - position.x, 0.0, size.x)
	# the speeds at the seam: what LOCAL's approach (or the yard's flight out)
	# ended on, and what the yard's flight in (or LOCAL's flight out) starts on
	var rest_s := DOCK_YARD_S if inward else UNDOCK_LOCAL_S
	if new.has_method(&"ladder_track_speed"):
		_v_new = float(new.call(&"ladder_track_speed", rest_s))
	# the hull's tiling, carried on from LOCAL's drum
	var at: Vector2 = Vector2.INF
	var local: Control = new if not inward else null
	if local != null and local.has_method(&"ladder_hull_at"):
		at = local.call(&"ladder_hull_at")
	elif inward:
		at = _hull_at_old
	_pan_view = _PanView.new()
	_pan_view.tex = _tex
	_pan_view.src = Rect2(position, size)
	_pan_view.size = size
	_pan_view.slab_w = PAN_HULL_W
	_pan_view.row_y = roundf(size.y * 0.5) if at == Vector2.INF else roundf(at.y - position.y)
	_hull_x0 = (_pan_vr if at == Vector2.INF else at.x - position.x)
	add_child(_pan_view)
	phase = Phase.MOVE
	# (on from where the pre-roll's clock left off: no frame stands still)
	_u = maxf(_pan_t0, 0.0) + _dt(get_process_delta_time())
	_step_pan(_u)
	# (and again once the screen just put in place has laid itself out -- a
	# container sorting its children puts the elevator back in its place)
	_step_pan.call_deferred(_u)


## THE ONE MOTION AFTER THE SEAM (3B): F's way up from black, or P's pan, then
## the yard's flight in (docking) or LOCAL's flight out (undocking).
func _step_pan(t: float) -> void:
	if not is_instance_valid(new) or _pan_view == null:
		return
	var inward := r_new > r_old
	if String(_style.get("fade", "")) == "F":
		# F: no pan. Docking: the empty yard up from black slowly, a beat of it
		# empty, then your ship in from the left -- off the picture till then --
		# slowing once onto its stands. Undocking: up on LOCAL, your ship already
		# coming out of the hull.
		_pan_view.visible = false
		new.position.x = _pan_x0
		if inward:
			_black_at(1.0 - _ease(clampf(t / YARD_FADE_S, 0.0, 1.0)))
			# (coming in at the speed LOCAL's approach ended on, within reason)
			var lad: Variant = new.get("_lad")
			var off := maxf(float((lad as Dictionary).get("off", 1.0)) if lad is Dictionary else 1.0, 1.0)
			var m0 := clampf(_v_old * DOCK_YARD_S / off, 1.5, 3.0)
			var rest := clampf((t - YARD_FADE_S - YARD_BEAT_S) / DOCK_YARD_S, 0.0, 1.0)
			new.call(&"ladder_cam", 1.0 - herm(rest, m0, 0.0))
		else:
			_black_at(1.0 - _ease(clampf(t / LOCAL_FADE_S, 0.0, 1.0)))
			new.call(&"ladder_cam", 1.0 - clampf(t / UNDOCK_LOCAL_S, 0.0, 1.0))
		return
	var P := DOCK_PAN_S
	var W := _pan_vr if _pan_vr > 0.0 else size.x
	var S := PAN_HULL_W
	var D := W + S
	# P: the pan, from the speed handed on to the speed handed over
	var hu := herm(t / P, _v_old * P / D, _v_new * P / D)
	var X := D * (hu if inward else 1.0 - hu)
	var held := -X if inward else W + S - X
	var live := W + S - X if inward else -X
	new.position.x = _pan_x0 + roundf(live)
	_pan_view.held_x = held
	_pan_view.slab_x = W - X
	_pan_view.tile_x0 = _hull_x0 - X
	_pan_view.visible = t < P
	_pan_view.queue_redraw()
	if t >= P:
		new.position.x = _pan_x0
	var rest2 := clampf((t - P) / maxf(_move_s - P, 0.001), 0.0, 1.0)
	if inward:
		new.call(&"ladder_cam", 1.0 - herm(rest2, YARD_M_IN, 0.0))
	else:
		new.call(&"ladder_cam", 1.0 - rest2)


const YARD_M_IN := 2.0


## The move's last frame, whichever kind of move it is.
func _step_last() -> void:
	if bool(_style.get("pan", false)):
		_step_pan(_move_s)
	else:
		_step(1.0)


func _start_move() -> void:
	if phase != Phase.WAIT:
		return
	if bool(_style.get("pan", false)):
		_start_pan()
		return
	# THE ARRIVING CAMERA STARTS WHERE THE HELD PICTURE IS: its anchor (your ship,
	# your star, the world you orbit) placed on the held one's, so the two move
	# as one picture from the first frame
	_met = new.has_method(&"ladder_meet")
	if _met:
		new.call(&"ladder_meet", _a_old, _old_world)
	new.call(&"ladder_cam_begin", r_old, seam, design)
	new.call(&"ladder_cam", 1.0)
	# THE WORLD ITSELF HANDED OVER (2C): the held picture leaves a hole where its
	# world is, and LOCAL draws the map's own world there
	if not _given.is_empty() and new.has_method(&"ladder_take_world"):
		var g := _given.duplicate()
		g["freeze"] = measure_hold
		_taken = bool(new.call(&"ladder_take_world", g))
		if _taken and not _old_world.is_empty():
			var c: Vector2 = _old_world.c
			# (with the world's lit rim of air, which reaches past its disc)
			_mat.set_shader_parameter(&"hole", Vector3(c.x, c.y, float(_old_world.r) * 1.22 + 2.0))
			new.call(&"ladder_cam", 1.0)
	if not _taken and not _given.is_empty() and is_instance_valid(_given.view):
		(_given.view as Node).queue_free()
	_given = {}
	_s0 = maxf(float(new.call(&"ladder_scale")), 0.0001)
	_mat.set_shader_parameter(&"mode", int(_style.mode))
	_mat.set_shader_parameter(&"spread", float(_style.spread))
	_mat.set_shader_parameter(&"reach", float(_style.reach))
	_mat.set_shader_parameter(&"axis", _style.axis)
	_mat.set_shader_parameter(&"rim", float(_style.get("rim", 10.0)))
	_mat.set_shader_parameter(&"edge", float(_style.get("edge", 0.0)))
	_mat.set_shader_parameter(&"soft", 1.0 if bool(_style.get("soft", false)) else 0.0)
	_mat.set_shader_parameter(&"sharp", 1.0 if bool(_style.get("sharp", false)) else 0.0)
	if bool(_style.hull) and new.has_method(&"ladder_hull"):
		_hull_to = new.call(&"ladder_hull")
		var art: Texture2D = new.call(&"ladder_hull_texture") if new.has_method(&"ladder_hull_texture") else null
		if art == null:
			art = _hull_tex
		if art != null and _hull_from.size.x > 1.0 and _hull_to.size.x > 1.0:
			_hull = TextureRect.new()
			_hull.texture = art
			_hull.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_hull.stretch_mode = TextureRect.STRETCH_SCALE
			_hull.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_hull)
			new.call(&"ladder_hide_hull", true)
	phase = Phase.MOVE
	_u = 0.0
	_step(0.0 if measure_hold else (_curve_e() if bool(_style.get("curve", false)) else 0.0))


## The move at progress `u`.
func _step(u: float) -> void:
	if not is_instance_valid(new):
		return
	# out of a pre-roll, eased OUT (it arrives at speed); from a standstill, both
	var e := 1.0 - (1.0 - clampf(u, 0.0, 1.0)) * (1.0 - clampf(u, 0.0, 1.0)) if _had_pre else _ease(u)
	# (on the one curve, `u` is already where the curve is)
	if bool(_style.get("curve", false)):
		e = clampf(u, 0.0, 1.0)
	new.call(&"ladder_cam", 1.0 - e)
	_fit()
	var a_new: Vector2 = new.call(&"ladder_anchor", r_old, seam, design)
	var ratio := float(new.call(&"ladder_scale")) / _s0
	var extra := lerpf(1.0, float(_style.extra), e) if float(_style.extra) >= 1.0 \
		else pow(float(_style.extra), e)
	var scl := Vector2.ONE * ratio * extra
	var from := _a_old
	var to := a_new if _met else _a_old.lerp(a_new, e)
	if bool(_style.get("pin", false)):
		to = _a_old
	# 1A: THE HOLE IS THE SUN. Going in, the live map's sun shows through the
	# held chart exactly where (and as big as) the chart's star is drawn; coming
	# out, the chart's star shows through the held map where its sun was
	if bool(_style.get("sun", false)):
		var sun_r := 0.0
		if r_new > r_old and new.has_method(&"ladder_sun"):
			sun_r = float((new.call(&"ladder_sun") as Dictionary).get("r", 0.0)) / maxf(scl.x, 0.0001)
		elif r_new < r_old:
			sun_r = float(_old_sun.get("r", 0.0))
		if sun_r > 0.0:
			_mat.set_shader_parameter(&"hole", Vector3(_a_old.x, _a_old.y, sun_r + 0.5))
	if bool(_style.plane) and new.has_method(&"ladder_plane"):
		# THE MAP LAID DOWN INTO LOCAL'S PLANE: the map's star onto LOCAL's star, the
		# map's slant (0.38) pressed flat to LOCAL's (0.07), its scale to LOCAL's
		var pl_new: Dictionary = new.call(&"ladder_plane")
		var pl_old: Dictionary = _old_plane
		if not pl_old.is_empty() and not pl_new.is_empty():
			var inward := r_new > r_old
			var a: Dictionary = pl_old if inward else pl_new
			var b: Dictionary = pl_new if inward else pl_old
			var sx: float = float(b.s) / maxf(float(a.s), 0.0001)
			var sy: float = float(b.s) * float(b.tilt) / maxf(float(a.s) * float(a.tilt), 0.0001)
			var target := Vector2(sx, sy) if inward else Vector2(1.0 / sx, 1.0 / sy)
			from = pl_old.o
			to = (pl_old.o as Vector2).lerp(pl_new.o, e)
			scl = Vector2(pow(target.x, e), pow(target.y, e))
			_mat.set_shader_parameter(&"c", to)
	elif bool(_style.world) and not _met:
		var w_new: Dictionary = new.call(&"ladder_world") if new.has_method(&"ladder_world") else {}
		var w_old: Dictionary = _old_world
		if not w_old.is_empty() and not w_new.is_empty():
			# THE WORLD YOU ORBIT, carried: its disc in the held picture onto its
			# disc in the live one, sized to it
			var k := float(w_new.r) / maxf(float(w_old.r), 0.5)
			from = w_old.c
			to = (w_old.c as Vector2).lerp(w_new.c, e)
			scl = Vector2.ONE * pow(k, e)
	_mat.set_shader_parameter(&"from_pt", from)
	_mat.set_shader_parameter(&"to_pt", to)
	_mat.set_shader_parameter(&"scl", scl)
	if not bool(_style.plane):
		_mat.set_shader_parameter(&"c", to)
	# the held picture goes on a slightly faster curve than the camera, so the
	# arriving picture is whole well before the camera settles
	var tm := _ease_out(clampf(u / 0.85, 0.0, 1.0)) if bool(_style.get("fast", false)) 		else _ease(clampf(u / 0.85, 0.0, 1.0))
	if _style.has("t_from"):
		# (the held picture goes over its own stretch of the move)
		tm = _ease(clampf((u - float(_style.t_from)) / maxf(float(_style.t_to) - float(_style.t_from), 0.001), 0.0, 1.0))
	_mat.set_shader_parameter(&"t", tm)
	_mat.set_shader_parameter(&"chrome_t", _ease(clampf(u / float(_style.chrome), 0.0, 1.0)))
	if int(_style.mode) == 3:
		var bmax := float(_style.block)
		var tri := 1.0 - absf(u * 2.0 - 1.0)
		var b := roundf(lerpf(1.0, bmax, tri) / 2.0) * 2.0
		if u >= 1.0:
			b = 1.0
		_mat.set_shader_parameter(&"block", maxf(b, 1.0))
		_mat.set_shader_parameter(&"t", u)
	if _hull != null:
		var r := Rect2(_hull_from.position.lerp(_hull_to.position, e), _hull_from.size.lerp(_hull_to.size, e))
		_hull.position = (r.position - position).round()
		_hull.size = r.size.round()


## The bulkhead at G (0 to 1 of the whole move): off one side at 0, across the
## whole picture at the handoff, off the other side at 1.
func _place_bar(g: float) -> void:
	if not bool(_style.get("bar", false)):
		return
	_fit()
	if _bar == null:
		_bar = Bulkhead.new()
		add_child(_bar)
	_bar.position = Vector2.ZERO
	_bar.size = size
	var W := size.x
	_bar.w = W * 1.6
	_bar.dir = -1.0 if r_new > r_old else 1.0
	# a straight path whose middle (G = F) has the slab over all of the picture
	var span := W + _bar.w
	var u := clampf(0.5 + (g - _F) * 2.4, 0.0, 1.0)
	_bar.x = W - span * u if _bar.dir < 0.0 else -_bar.w + span * u
	_bar.queue_redraw()


## The map, built ahead for the move under way (`preroll`), for the Router to
## show instead of building one (`take_prebuilt`).
static var prebuilt: Control = null


## The map (or the chart) built ahead, if it is the kind asked for and ready;
## the Router takes it.
static func take_prebuilt(kind: int) -> Control:
	var pm := prebuilt
	if pm == null or not is_instance_valid(pm) or rank_of(pm) != kind:
		return null
	prebuilt = null
	# (LOCAL: only if nothing has happened since that it would have played)
	if pm is SectorScreen and (not _local_quiet() or (pm as SectorScreen)._events == null
			or (pm as SectorScreen)._events.node != Run.node_at()):
		pm.queue_free()
		return null
	if pm is StationScreen and int(pm.get_meta(&"ladder_at", -1)) != Run.at:
		pm.queue_free()
		return null
	if pm is StationScreen:
		pm.process_mode = Node.PROCESS_MODE_INHERIT
	if pm is SystemMapScreen and ((pm as SystemMapScreen).view == null or (pm as SystemMapScreen).view.node != Run.node_at()
			or not (pm as SystemMapScreen).ladder_ready()):
		pm.queue_free()
		return null
	if pm.get_parent() != null:
		pm.get_parent().remove_child(pm)
	pm.modulate.a = 1.0
	return pm


## Whether LOCAL built now would play nothing as it is built (`preroll`).
## (`undocking`: leaving a berth, where `Router.docked` is still set and the
## arrival latch is about to be)
static func _local_quiet(undocking: bool = false) -> bool:
	return (undocking or not Router.docked) and not Router.in_combat() and Router._post_depart < 0 \
		and not Router._post_arrive and LocalEventDrawer.pending.is_empty() \
		and (undocking or SectorScreen._approached_at == Run.at)


static func drop_prebuilt() -> void:
	if prebuilt != null and is_instance_valid(prebuilt):
		prebuilt.queue_free()
	prebuilt = null


## A move that goes on into the next when it lands (the map's DOCK: down to
## LOCAL, then into the hangar).
static var chain := &""


func _end() -> void:
	# (a map built ahead and never shown goes)
	if phase != Phase.MOVE:
		drop_prebuilt()
	if chain == &"station" and phase == Phase.MOVE and new is SectorScreen and is_instance_valid(new):
		chain = &""
		Router.show_station.call_deferred()
	if not _given.is_empty() and is_instance_valid(_given.view) and (_given.view as Node).get_parent() == null:
		(_given.view as Node).queue_free()
	_given = {}
	if phase == Phase.PRE and is_instance_valid(old) and Router.current == old:
		old.call(&"ladder_cam", 0.0)
		old.call(&"ladder_cam_end")
	if phase == Phase.MOVE and is_instance_valid(new):
		new.call(&"ladder_cam", 0.0)
		new.call(&"ladder_cam_end")
		if _hull != null and new.has_method(&"ladder_hide_hull"):
			new.call(&"ladder_hide_hull", false)
	if _pan_view != null and is_instance_valid(new):
		new.position.x = _pan_x0
	if active == self:
		active = null
	phase = Phase.PRE_DONE
	_rect.visible = false
	queue_free()
	# (the run written now the move has landed: `Router._swap` held it back)
	if save_after:
		save_after = false
		Router._autosave()
