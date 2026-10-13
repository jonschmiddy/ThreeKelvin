class_name SideSwap
extends ColorRect

## THE SIDE BAR'S SWAP (Jon, Oct 13: "When going from local to sector or sector
## to starchart etc... the side bar goes blank and then draws the new side bar.
## Can we not have it go blank and just have it transition to the new side
## bar?"). It went blank because the side bar was part of each screen's UI
## (`ladder_chrome`), which leaves before the camera moves and comes back after
## it lands: the chart's and the map's panels faded out over 0.22 s, the side
## column stood empty through the whole camera move, and the new panel faded in
## over 0.4 s after it -- 60 to 122 frames of empty column at 60 fps a hop.
##
## Now the side bar is not the screens' UI. The panel being left stays whole
## while its camera moves (`ZoomLadder.preroll`), and from the swap -- the
## arriving screen built, its panel laid out and live underneath -- this draws
## over the side bar's rect, from the held picture's copy of the old panel to
## the live new one, in the look picked (`ZoomLadder.SIDE_LOOK`), and goes once
## the new one stands alone. The held picture leaves this rect to it
## (`zoom_ladder.gdshader`'s `side`). The other UI keeps its three beats.
##
## A hop with a side bar at one end only (LOCAL <-> the map) runs the same look
## with the picture arriving (LOCAL's own, live) as the new, or, arriving from
## LOCAL, the picture that was there as the old -- going on the held picture's
## own curve, as the rest of it goes, the look kept at least level with it.
##
## CLICKS (Jon on the Lab's rolling screen: anything that moves the rows "can
## cause a misclick"): nothing a hand can click moves while it can be clicked.
## `blocks` says where a click would land on content not yet resolved -- A
## before the crossfade's middle, B and C until they are done, D below the
## line, E and F a row or icon not yet written -- and the ladder eats a click
## there (`ZoomLadder._input`), ending the move but landing on nothing.

const SHADER := preload("res://shaders/side_swap.gdshader")
const MAXR := 64
const MAXS := 16
## E and F: a glyph's cell, px (Silkscreen at the panels' sizes)
const CELL := Vector2(6.0, 8.0)
## B's and A's length is the rest of the move (`ZoomLadder._hold`); the others
## are their own: C a section every 40 ms, each crossing in 120; D's line down
## the rect; E's rows resolving; F's lost signal and its print
const C_STAGGER := 0.04
const C_EACH := 0.12
const D_S := 0.5
## E, SLOW (Jon: "can we have the decode animation happen slowly and not so
## fast?"): each line resolves left to right over `E_ROW`, the lines starting
## one after another down the panel 60-80 ms apart, the whole about 1.1 s, or
## to 0.3 s past the camera landing on a longer move; a hop shorter than that
## (LOCAL -> map) lets the decode run on past the zoom rather than hurrying it
## (`ZoomLadder._end` hands it on). The glyphs turn over `GLYPH_HZ` a second.
const E_ROW := 0.45
## E leaving for a screen with no side bar (map -> LOCAL): once the letters have
## decoded away on the old panel's ground, the empty panel fades over this
## (a toolbar on its band goes with the band instead, `SideBand`)
const OUT_FADE := 0.3
const E_STAGGER := Vector2(0.06, 0.08)
const E_TARGET := 1.1
const GLYPH_HZ := 13.0
const F_LOST := 0.05
const F_PRINT := 0.42

## Laid out: the rect it draws over (viewport px), for the held picture to leave
signal laid(r: Rect2)

var look := "A"
var _li := 0
## (no old side bar) how much of the held picture still stands over the rect,
## drawn over this: `ZoomLadder.held_alpha`
var held: Callable
var dur := 1.0
## the rest of the move when it began, s
var _rem := 1.0
## A TOOLBAR, not a side bar (`ZoomLadder.bar_of`): one row of things, so E
## starts each one after the one to its left rather than each line after the
## one above
var across := false
## (a toolbar between LOCAL and a screen with one) its missing side is the
## band's ground, never the scene under it (`SideBand`)
var banded := false
var _decode_end := 0.0

## EVERY SWAP STILL DRAWING, the ladder's and any it handed on when it ended
## before the decode did (`ZoomLadder._end`): finished at once by the next
## screen change or move (`finish_all`).
static var live: Array = []


static func finish_all() -> void:
	for s: Variant in live.duplicate():
		if is_instance_valid(s):
			(s as SideSwap).finish()
	live.clear()


## The swap drawing over the side bar now, or null.
static func side_now() -> SideSwap:
	for s: Variant in live:
		if is_instance_valid(s) and not (s as SideSwap).done and not (s as SideSwap).across:
			return s as SideSwap
	return null


## And over the toolbar.
static func bar_now() -> SideSwap:
	for s: Variant in live:
		if is_instance_valid(s) and not (s as SideSwap).done and (s as SideSwap).across:
			return s as SideSwap
	return null


## (freed with its ladder, not finished: out of the list all the same)
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		live.erase(self)


## A click here lands on nothing while what is under it has not resolved: the
## ladder eats it while the move is on (`ZoomLadder._side_eats`); once a decode
## runs on past the move, this does.
func _has_point(point: Vector2) -> bool:
	return blocks(get_global_transform() * point)
## +1 zooming in (the content goes up), -1 out
var dir := 1.0
var old_rect := Rect2()
var new_side: Control = null
var _new_rect := Rect2()
var _rect := Rect2()
## rows: [Rect2, kind (0 text, 1 icon), t0, t1]; sections: [top, t0, t1]
var _rows: Array = []
var _secs: Array = []
var _old_rows: Array = []
var _old_secs: Array = []
var _laid := false
var t := 0.0
var _total := 1.0
var _mat: ShaderMaterial
var done := false


static func look_index(l: String) -> int:
	return maxi(0, ZoomLadder.SIDE_LOOKS.find(l))


## Over `old_side` (the panel being left, still in the tree: the held frame
## `tex` is its picture) to `new_side_` (the arriving screen's, laid out or
## about to be); either may be null, not both.
func setup(old_side: Control, new_side_: Control, tex: Texture2D, look_: String, dir_: float, dur_: float) -> void:
	look = look_
	_li = look_index(look)
	dir = dir_
	_rem = dur_
	dur = clampf(dur_, 0.35, 1.4)
	if old_side == null:
		# (arriving where there was none: up while the held picture over it goes)
		dur = minf(dur, 0.4)
	_material(tex)
	if old_side != null and is_instance_valid(old_side) and old_side.is_visible_in_tree():
		old_rect = old_side.get_global_rect()
		_old_rows = rows_of(old_side, old_rect)
		_old_secs = sections_of(old_side)
	new_side = new_side_
	# (the arriving screen is put in its place later this frame, and laid out
	# again under the game's theme once it is: a screen built ahead stood
	# outside it, its buttons in Godot's own, taller -- so after that)
	(func() -> void: _lay.call_deferred()).call_deferred()


func _material(tex: Texture2D) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color.WHITE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_mat.set_shader_parameter(&"old_tex", tex)
	_mat.set_shader_parameter(&"glyph_hz", GLYPH_HZ)
	live.append(self)


## Where letters are being decoded this frame (E's and F's rows not yet
## resolved), viewport px: for the harness, which holds them to a band.
func scrambling() -> Array:
	var out: Array = []
	if done or not _laid or not (_li in [4, 5]):
		return out
	for r: Array in _rows_now:
		if int(r[1]) == 0 and t < float(r[3]):
			out.append(r[0])
	return out


## The rect drawn over (viewport px).
func rect() -> Rect2:
	return _rect


func _lay() -> void:
	if _laid or done or not is_inside_tree():
		return
	if new_side != null and is_instance_valid(new_side):
		if not new_side.is_inside_tree() or new_side.size.x < 2.0:
			return
		_new_rect = new_side.get_global_rect()
	_rect = old_rect.merge(_new_rect) if old_rect.size.x > 0.0 and _new_rect.size.x > 0.0 \
		else (old_rect if old_rect.size.x > 0.0 else _new_rect)
	_rect = Rect2(_rect.position.floor(), _rect.size.ceil())
	_laid = true
	var p := get_parent() as Control
	position = _rect.position - (p.global_position if p != null else Vector2.ZERO)
	size = _rect.size
	_content()
	_mat.set_shader_parameter(&"rect", _v4(_rect))
	_mat.set_shader_parameter(&"old_r", _v4(old_rect))
	_mat.set_shader_parameter(&"new_r", _v4(_new_rect))
	_mat.set_shader_parameter(&"look", _li)
	_mat.set_shader_parameter(&"dir", dir)
	_mat.set_shader_parameter(&"cell", CELL)
	_mat.set_shader_parameter(&"lost_s", F_LOST)
	_mat.set_shader_parameter(&"bg_dx", -2.0 if across else 3.0)
	_mat.set_shader_parameter(&"banded", 1 if banded else 0)
	_mat.set_shader_parameter(&"ground", Vector3(UITheme.VOID.r, UITheme.VOID.g, UITheme.VOID.b))
	_mat.set_shader_parameter(&"ice", Vector3(UITheme.ICE.r, UITheme.ICE.g, UITheme.ICE.b))
	_mat.set_shader_parameter(&"line_col", Vector3(UITheme.LINE.r, UITheme.LINE.g, UITheme.LINE.b))
	_mat.set_shader_parameter(&"cold", Vector3(UITheme.COLD.r, UITheme.COLD.g, UITheme.COLD.b))
	_mat.set_shader_parameter(&"chill", Vector3(UITheme.CHILL.r, UITheme.CHILL.g, UITheme.CHILL.b))
	_push()
	visible = true
	laid.emit(_rect)
	# (on a band already open (`SideBand`) there is nothing to cross from: the
	# looks without letters put the toolbar straight up on it, this frame)
	if old_rect.size.x <= 0.0 and banded and _li in [0, 1, 2, 3]:
		finish()


## The arriving panel's rows and sections, and the look's times from them;
## again whenever the panel lays itself out anew in the middle of the swap (the
## map's panel is rebuilt as the map arrives, its rows where they were not).
var _sig := ""


func _content() -> void:
	if new_side != null and is_instance_valid(new_side) and new_side.is_inside_tree():
		_rows = rows_of(new_side, _new_rect)
		_secs = sections_of(new_side)
	_sig = str(_rows.map(func(r: Array) -> Rect2: return r[0]))
	# THE TIMES, from the content they act on: the arriving panel's rows, or
	# (E leaving for a screen with none) the old one's
	var rows: Array = _rows if _new_rect.size.x > 0.0 else _old_rows
	# (leaving for a screen with none: a button goes whole with its word -- its
	# plate breaks up with the letters, on the ground round it)
	if _new_rect.size.x <= 0.0:
		for i in rows.size():
			var hit: Rect2 = rows[i][5]
			if hit.has_area():
				rows[i] = [Rect2(hit.position.floor(), hit.size.ceil()), rows[i][1], rows[i][2], rows[i][3], -1.0, hit, rows[i][6]]
	var secs: Array = _secs if _new_rect.size.x > 0.0 else _old_secs
	match _li:
		0, 1:
			_total = dur
		2:
			for i in secs.size():
				secs[i] = [float(secs[i][0]), C_STAGGER * i, C_STAGGER * i + C_EACH]
			_total = C_STAGGER * maxi(secs.size() - 1, 0) + C_EACH
		3:
			_total = D_S
		4:
			# (line by line down the panel: the rows that share a line start
			# together, each line 60-80 ms after the one above; along a toolbar,
			# each thing 60-80 ms after the one to its left, a run of things
			# closer than 8 px -- the layer pips -- one thing)
			var key := func(r: Rect2) -> float: return r.position.x if across else r.position.y
			var keys: Array = rows.map(func(r: Array) -> float: return key.call(r[0] as Rect2))
			var order := range(rows.size())
			order.sort_custom(func(a: int, b: int) -> bool: return float(keys[a]) < float(keys[b]))
			var group := {}
			var g := -1
			var end := -INF
			for i: int in order:
				var rr := rows[i][0] as Rect2
				var at := float(keys[i])
				if g < 0 or at > end + (8.0 if across else 3.0):
					g += 1
				group[i] = g
				end = maxf(end, rr.end.x) if across else at
			var target := maxf(E_TARGET, _rem + 0.3)
			var st := clampf((target - E_ROW) / float(maxi(g, 1)), E_STAGGER.x, E_STAGGER.y)
			_total = E_ROW
			for i in rows.size():
				var t0 := st * int(group[i])
				rows[i] = [rows[i][0], rows[i][1], t0, t0 + E_ROW, rows[i][4], rows[i][5], rows[i][6]]
				_total = maxf(_total, t0 + E_ROW)
			# WHAT DOES NOT CHANGE DOES NOT DECODE (LOCAL's band and the map's
			# both read DANGER 1/10): a word the old side had, the same, in the
			# same place, is resolved from the start; and the pips after a
			# readout that did not change, where the old side had them too
			if _new_rect.size.x > 0.0 and old_rect.size.x > 0.0:
				var same_word := func(r: Array) -> bool:
					if String(r[6]) == "":
						return false
					for o: Array in _old_rows:
						if String(o[6]) == String(r[6]) and absf((o[0] as Rect2).position.x - (r[0] as Rect2).position.x) <= 1.0 								and absf((o[0] as Rect2).position.y - (r[0] as Rect2).position.y) <= 1.0:
							return true
					return false
				var kept := {}
				for i in rows.size():
					if same_word.call(rows[i]):
						kept[i] = true
				for i in rows.size():
					var rr := rows[i][0] as Rect2
					var keep: bool = kept.has(i)
					if not keep and int(rows[i][1]) == 1:
						# (an icon: kept if the old side had one here, and the word
						# nearest it on its left was kept)
						var had := _old_rows.any(func(o: Array) -> bool: return int(o[1]) == 1 and (o[0] as Rect2).is_equal_approx(rr))
						var left := -1
						for j in rows.size():
							var rj := rows[j][0] as Rect2
							if int(rows[j][1]) == 0 and absf(rj.get_center().y - rr.get_center().y) < 6.0 and rj.end.x <= rr.position.x 									and (left < 0 or rj.end.x > (rows[left][0] as Rect2).end.x):
								left = j
						keep = had and left >= 0 and kept.has(left)
					if keep:
						rows[i][2] = -1.0
						rows[i][3] = -1.0
			_decode_end = _total
			if _new_rect.size.x <= 0.0 and not banded:
				_total += OUT_FADE
		5:
			# (each line of text as long as it is wide, one after another in
			# reading order; pictures up with the frame)
			var wsum := 0.0
			for r: Array in rows:
				if int(r[1]) == 0:
					wsum += maxf((r[0] as Rect2).size.x, 12.0)
			var order := range(rows.size())
			order.sort_custom(func(a: int, b: int) -> bool:
				var ra := rows[a][0] as Rect2
				var rb := rows[b][0] as Rect2
				return ra.position.y < rb.position.y or (ra.position.y == rb.position.y and ra.position.x < rb.position.x))
			var at := F_LOST
			for i: int in order:
				var d := 0.0 if int(rows[i][1]) == 1 else F_PRINT * maxf((rows[i][0] as Rect2).size.x, 12.0) / maxf(wsum, 1.0)
				rows[i] = [rows[i][0], rows[i][1], at, at + d, rows[i][4], rows[i][5], rows[i][6]]
				at += d
			_total = (F_LOST + F_PRINT) if _new_rect.size.x > 0.0 else F_LOST
	var rv := PackedVector4Array()
	var rt := PackedVector4Array()
	for r: Array in rows:
		var rr := r[0] as Rect2
		rv.append(Vector4(rr.position.x, rr.position.y, rr.size.x, rr.size.y))
		rt.append(Vector4(float(r[2]), float(r[3]), float(r[1]), float(r[4])))
	rv.resize(MAXR)
	rt.resize(MAXR)
	var sv := PackedVector4Array()
	for s: Array in secs:
		sv.append(Vector4(float(s[0]), float(s[1]) if s.size() > 1 else 0.0, float(s[2]) if s.size() > 2 else 0.0, 0.0))
	sv.resize(MAXS)
	_rows_now = rows
	_secs_now = secs
	_mat.set_shader_parameter(&"rows", rv)
	_mat.set_shader_parameter(&"rowt", rt)
	_mat.set_shader_parameter(&"nrows", mini(rows.size(), MAXR))
	_mat.set_shader_parameter(&"secs_y", sv)
	_mat.set_shader_parameter(&"nsecs", mini(secs.size(), MAXS))


var _rows_now: Array = []
var _secs_now: Array = []


static func _v4(r: Rect2) -> Vector4:
	return Vector4(r.position.x, r.position.y, r.size.x, r.size.y)


func _process(delta: float) -> void:
	if done:
		return
	_lay()
	if not _laid:
		return
	if new_side != null and is_instance_valid(new_side) and new_side.is_inside_tree():
		var now := rows_of(new_side, _new_rect)
		if str(now.map(func(r: Array) -> Rect2: return r[0])) != _sig:
			_content()
	t += ZoomLadder.fixed_dt if ZoomLadder.fixed_dt > 0.0 else minf(delta, 1.0 / 30.0)
	# (where there was no side bar, the crossfade, the slide, the cascade and
	# the line keep at least level with the held picture going from over them,
	# so the rect is never the bare ground between the two)
	if old_rect.size.x <= 0.0 and held.is_valid() and _li in [0, 1, 2, 3]:
		t = maxf(t, (1.0 - clampf(float(held.call()), 0.0, 1.0)) * _total)
	if t >= _total:
		finish()
		return
	_push()


## Straight to the end: the new panel stands alone.
func finish() -> void:
	done = true
	visible = false
	live.erase(self)
	queue_free()


func _u() -> float:
	return clampf(t / maxf(_total, 0.001), 0.0, 1.0)


func _line_y() -> float:
	return _rect.position.y + floorf(clampf(t / D_S, 0.0, 1.0) * (_rect.size.y + 2.0) / 2.0) * 2.0


func _push() -> void:
	_mat.set_shader_parameter(&"held_a", clampf(float(held.call()), 0.0, 1.0) if held.is_valid() else 0.0)
	_mat.set_shader_parameter(&"secs", t)
	_mat.set_shader_parameter(&"u", _u())
	_mat.set_shader_parameter(&"line_y", _line_y())
	_mat.set_shader_parameter(&"out_fade", _out_fade())


func _out_fade() -> float:
	if _li != 4 or _new_rect.size.x > 0.0 or banded:
		return 0.0
	return clampf((t - _decode_end) / OUT_FADE, 0.0, 1.0)


# ------------------------------------------------------------ what it shows

## At viewport point `p`, this frame: how much of the old content shows, how
## much of the new (or of the static that stands for it), and how settled the
## new is there for a click (1 resolved and still). The shader's own sums, on
## the CPU, for the harness and for `blocks`.
func state_at(p: Vector2) -> Vector3:
	if done or not _laid or not _rect.has_point(p):
		return Vector3(0.0, 1.0, 1.0)
	var st := _state_at(p)
	if old_rect.size.x <= 0.0:
		# (no old panel: the picture that was there, going as the rest of the
		# held picture's standing copy goes, then the screen's bare ground,
		# which is no content)
		var h := clampf(float(held.call()), 0.0, 1.0) if held.is_valid() else 0.0
		# (F's lost signal is drawn, never the bare ground: content)
		if _li == 5 and t < F_LOST:
			h = 1.0
		return Vector3(h, (1.0 - h) * st.y, st.z)
	return st


func _state_at(p: Vector2) -> Vector3:
	var hn := _new_rect.size.x > 0.0
	match _li:
		0:
			var e := smoothstep(0.0, 1.0, _u())
			return Vector3(1.0 - e, e, e)
		1:
			# (one or the other at every point, stacked; nothing settled until it
			# has stopped)
			var e2 := _u()
			e2 = e2 * e2 * e2 * (e2 * (e2 * 6.0 - 15.0) + 10.0)
			var off := floorf(e2 * _rect.size.y + 0.5)
			var qo := Vector2(p.x, p.y + dir * off)
			var on := old_rect.size.x > 0.0 and (_rect.has_point(qo) if hn else old_rect.has_point(qo))
			return Vector3(1.0 if on else 0.0, 0.0 if on else 1.0, 0.0)
		2:
			var k := 0
			for i in _secs_now.size():
				if p.y >= float(_secs_now[i][0]):
					k = i
			var e3 := 1.0
			if not _secs_now.is_empty():
				e3 = smoothstep(float(_secs_now[k][1]), float(_secs_now[k][2]), t)
			return Vector3(1.0 - e3, e3, e3)
		3:
			var g := _line_y() - p.y
			if g > 2.0:
				return Vector3(0.0, 1.0, 1.0)
			if g > 0.0:
				return Vector3(0.0, 1.0, 0.0)
			return Vector3(1.0, 0.0, 0.0)
		4:
			if not hn:
				# (leaving for a screen with none: the old panel -- its letters
				# decoding away on its own ground -- holds the rect, and takes no
				# click, until it has gone)
				var of := _out_fade()
				return Vector3(1.0 - of, of, 1.0 if of >= 1.0 else 0.0)
			for r: Array in _rows_now:
				var rr := r[0] as Rect2
				if not rr.has_point(p):
					continue
				var t0 := float(r[2])
				var t1 := float(r[3])
				if int(r[1]) == 1 and hn:
					var a := t - t0
					if a < 0.0 or (a >= 1.0 / 60.0 and a < 2.0 / 60.0):
						return Vector3(0.0, 0.0, 0.0)
					return Vector3(0.0, 1.0, 1.0 if a >= 2.0 / 60.0 else 0.0)
				var fr := rr.position.x + floorf(clampf((t - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0) * rr.size.x / CELL.x) * CELL.x
				if p.x >= fr:
					# (scrambled: glyphs drawn, of the new or of the old leaving)
					return Vector3(0.0, 1.0, 0.0) if hn else Vector3(1.0, 0.0, 0.0)
				return Vector3(0.0, 1.0, 1.0)
			return Vector3(0.0, 1.0, 1.0)
		5:
			if t < F_LOST:
				# (signal lost: drawn, never empty; counted as the old)
				return Vector3(1.0, 0.0, 0.0)
			if not hn:
				return Vector3(0.0, 1.0, 1.0)
			for r: Array in _rows_now:
				var rr := r[0] as Rect2
				if not rr.has_point(p):
					continue
				if int(r[1]) == 1:
					return Vector3(0.0, 1.0, 1.0)
				var t0 := float(r[2])
				var t1 := float(r[3])
				var fr := rr.position.x + floorf(clampf((t - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0) * rr.size.x / CELL.x) * CELL.x
				if p.x < fr:
					return Vector3(0.0, 1.0, 1.0)
				# (not yet printed: the panel's ground; the cursor counts as drawn)
				var cur := t >= t0 and t < t1 and p.x < fr + CELL.x
				return Vector3(0.0, 1.0 if cur else 0.0, 0.0)
			return Vector3(0.0, 1.0, 1.0)
	return Vector3(0.0, 1.0, 1.0)


## How settled the new content must be under a click for it to go through: A
## from the crossfade's middle, the rest only once it is all there.
func click_floor() -> float:
	return 0.5 if _li == 0 else 0.999


## Whether a click at `p` would land on content not yet resolved there.
func blocks(p: Vector2) -> bool:
	if done or not _laid or not _rect.has_point(p):
		return false
	if state_at(p).z < click_floor():
		return true
	# (a button: all of it, until its word has resolved, not only the word)
	for r: Array in _rows_now:
		var hit: Rect2 = r[5]
		if hit.has_area() and hit.has_point(p) and t < float(r[3]):
			return true
	return false


# ------------------------------------------------------------ the content

## The rows of text and the icons in a panel, top to bottom (viewport px,
## inside `clip`): a Label or a RichTextLabel a row per line, a Button one, any
## other leaf (a picture, a glyph) an icon. At most `MAXR`, the nearest merged.
static func rows_of(root: Control, clip: Rect2) -> Array:
	var out: Array = []
	_collect(root, clip, out)
	out.sort_custom(func(a: Array, b: Array) -> bool:
		var ra := a[0] as Rect2
		var rb := b[0] as Rect2
		return ra.position.y < rb.position.y or (ra.position.y == rb.position.y and ra.position.x < rb.position.x))
	while out.size() > MAXR:
		# (the pair closest together merged)
		var best := 0
		var bd := INF
		for i in out.size() - 1:
			var d := absf((out[i + 1][0] as Rect2).position.y - (out[i][0] as Rect2).position.y)
			if d < bd:
				bd = d
				best = i
		out[best] = [(out[best][0] as Rect2).merge(out[best + 1][0] as Rect2), 0, 0.0, 0.0, -1.0, Rect2(), ""]
		out.remove_at(best + 1)
	# (text before pictures, each in reading order: where a line of text lies on
	# a picture -- a card's ground, a stripe -- the line is what a point is in)
	var text := out.filter(func(r: Array) -> bool: return int(r[1]) == 0)
	text.append_array(out.filter(func(r: Array) -> bool: return int(r[1]) != 0))
	return text


static func _collect(c: Control, clip: Rect2, out: Array) -> void:
	if not c.is_visible_in_tree() or c.modulate.a < 0.05 or c.size.x < 1.0 or c.size.y < 1.0:
		return
	var r := c.get_global_rect()
	if c is ScrollContainer:
		clip = clip.intersection(r)
	if c is Label:
		var l := c as Label
		var lines := maxi(l.get_visible_line_count(), 1)
		var gx := -1.0
		# (one line: only as wide as its words, where its alignment puts them, so
		# a line resolves and prints over its letters, not the air beside them)
		if lines == 1:
			var w := l.get_theme_font(&"font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				l.get_theme_font_size(&"font_size")).x + 2.0
			if w < r.size.x:
				var k := 0.0
				if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
					k = 0.5
				elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
					k = 1.0
				r = Rect2(r.position.x + floorf((r.size.x - w) * k) - 1.0, r.position.y, ceilf(w) + 2.0, r.size.y)
				# (and its ground the pixel before its first letter)
				gx = 0.0
		var lh := float(l.get_line_height())
		var sp := float(l.get_theme_constant(&"line_spacing"))
		var h := lines * lh + (lines - 1) * sp
		var y0 := r.position.y + (r.size.y - h) * (0.5 if l.vertical_alignment == VERTICAL_ALIGNMENT_CENTER else
			(1.0 if l.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM else 0.0))
		# (each line a row, 2 px over at top and bottom: a glyph's ink can sit
		# past its line's box, and a row must hold all of it; the first row from
		# the label's own top, the last to its own bottom)
		for i in lines:
			var top := y0 + i * (lh + sp) - 2.0
			var bot := y0 + (i + 1) * (lh + sp) + 2.0
			if i == 0:
				top = minf(top, r.position.y)
			if i == lines - 1:
				bot = maxf(bot, r.end.y)
			_add(out, Rect2(r.position.x, top, r.size.x, bot - top), 0, clip, gx, Rect2(), l.text if lines == 1 else "")
		return
	if c is RichTextLabel:
		var rt := c as RichTextLabel
		var n := maxi(rt.get_line_count(), 1)
		var ch := minf(float(rt.get_content_height()), r.size.y)
		for i in n:
			_add(out, Rect2(r.position.x, r.position.y + ch * i / n - (2.0 if i > 0 else 0.0), r.size.x,
				ch / n + (2.0 if i > 0 else 0.0) + (r.size.y - ch if i == n - 1 else 2.0)), 0, clip)
		return
	if c is BaseButton:
		# (only as wide as its word, where it sits on the plate -- the plate
		# itself comes up with the layout -- its ground the plate just before
		# the word; a button with no word, its whole plate, read 3 px in)
		var gb := 3.0
		if c is Button and (c as Button).text != "":
			var bt := c as Button
			var w := bt.get_theme_font(&"font").get_string_size(bt.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				bt.get_theme_font_size(&"font_size")).x + 2.0
			if w + 4.0 < r.size.x:
				var k := 0.5
				if bt.alignment == HORIZONTAL_ALIGNMENT_LEFT:
					k = 0.0
				elif bt.alignment == HORIZONTAL_ALIGNMENT_RIGHT:
					k = 1.0
				var pad := bt.get_theme_stylebox(&"normal").get_margin(SIDE_LEFT) if k == 0.0 else 0.0
				r = Rect2(r.position.x + pad + floorf((r.size.x - pad - w) * k) - 1.0, r.position.y + 2.0, ceilf(w) + 2.0, r.size.y - 4.0)
				gb = 0.0
		_add(out, r, 0, clip, gb, c.get_global_rect(), (c as Button).text if c is Button else "")
		return
	var kids := 0
	for k in c.get_children():
		if k is Control:
			kids += 1
			_collect(k as Control, clip, out)
	# (a bare Control -- a spacer -- draws nothing: not a picture)
	if kids == 0 and not (c is Container) and not (c.get_class() == "Control" and c.get_script() == null):
		_add(out, r, 1, clip)


## A row: [rect, kind, t0, t1, where its ground is read -- px in from its left
## edge, or -1 for the panel's own ground, and for a button the whole of it,
## which takes no click until its word has resolved]
static func _add(out: Array, r: Rect2, kind: int, clip: Rect2, gx: float = -1.0, hit: Rect2 = Rect2(), text: String = "") -> void:
	var cr := r.intersection(clip)
	if cr.size.x >= 1.0 and cr.size.y >= 1.0:
		out.append([Rect2(cr.position.floor(), cr.size.ceil()), kind, 0.0, 0.0, gx, hit, text])


## A panel's sections, top to bottom (viewport y): its rows gathered into
## blocks wherever a gap of more than 5 px parts them, the panel's own top
## first. At most `MAXS`, the two nearest merged.
static func sections_of(side: Control) -> Array:
	var r := side.get_global_rect()
	var rows := rows_of(side, r)
	var out: Array = [[r.position.y]]
	var bottom := r.position.y + 12.0
	for row: Array in rows:
		var rr := row[0] as Rect2
		if rr.position.y > bottom + 5.0:
			out.append([rr.position.y])
		bottom = maxf(bottom, rr.end.y)
	while out.size() > MAXS:
		var best := 1
		var bd := INF
		for i in range(1, out.size()):
			var d := float(out[i][0]) - float(out[i - 1][0])
			if d < bd:
				bd = d
				best = i
		out.remove_at(best)
	return out
