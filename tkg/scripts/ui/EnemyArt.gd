class_name EnemyArt
extends TextureRect

## Everything obeys ART_CONTRACT's two-plane rule, written once in `_hull`.
## Flat fills read as boxes, so a ramp and a profile were added: shapes were never the problem.
## Why: docs/why/EnemyArt.md#enemy-art

## The box the ship occupies inside this canvas, in local pixels. See set_enemy.
var _used: Rect2i = Rect2i(0, 0, 240, 120)
var _bounds: Rect2i = Rect2i()
var _track: bool = false

func used_rect() -> Rect2i:
	return _used

## The picture's own box on the canvas -- the sprite, without the light a
## wind-up throws past it; the whole drawing for a coded ship.
var _ink_box: Rect2i = Rect2i()

func ink_rect() -> Rect2i:
	return _ink_box if _ink_box.size != Vector2i.ZERO else _used

## 340x160 since the Custodian outgrew 240x120 (Oct 13). Coded drawings stay centred in the old box.
const W := 340
const H := 160
## The box the coded drawings were authored in.
const CODED := Vector2i(240, 120)

var _img: Image
var _tex: ImageTexture

## Live enemies with a picture idle their engines (look A, Jon, Oct 13), not coded or dead.
## Drawn by `_flame_layer` outside this control, which clips to the ship's box: top level until
## a slot hosts it (`host_flame`).
## Why: docs/why/EnemyArt.md#engine-flame
const NO_FLAME := ["custodian_tetra", "whale_fan", "leviathan_lev_spine"]
var _flame_fx: ThrusterFx = null
var _flame_at := Vector2.ZERO        ## where the picture's (0, 0) sits on the canvas
var _pic_at := Vector2i.ZERO
var _flame_layer: Control

class EnemyFlame extends Control:
	var art: EnemyArt
	func _process(_d: float) -> void:
		if is_instance_valid(art) and art._flame_fx != null and art.is_visible_in_tree():
			queue_redraw()
	func _draw() -> void:
		if not is_instance_valid(art) or art._flame_fx == null or not art.is_visible_in_tree():
			return
		var origin := ((art.size - Vector2(EnemyArt.W, EnemyArt.H)) * 0.5).floor() + art._flame_at
		# In the art's frame from wherever this sits: top level, or a holder (`host_flame`).
		draw_set_transform_matrix(get_global_transform().affine_inverse()
			* art.get_global_transform() * Transform2D(0.0, origin))
		var mod := Color.WHITE
		var n: CanvasItem = art
		while n != null:
			mod *= n.modulate * (n.self_modulate if n == art else Color.WHITE)
			n = n.get_parent() as CanvasItem
		var t := ShipView.shot_clock if ShipView.shot_clock >= 0.0 else GameClock.now()
		art._flame_fx.draw(self, Vector2.ZERO, ThrusterFx.Thrust.IDLE, t, false, mod)

## What the current image was drawn from. See set_enemy.
var _sig: String = ""

## Six stops from ART_CONTRACT section 3. A new manufacturer gets a whole ramp, not a seventh stop.
## The gap between stops 1 and 3 is the two-plane break: closing it flattens the sprite.
## Why: docs/why/EnemyArt.md#ramps
var _steel: Array[Color] = [Color("#131a23"), Color("#232d3a"), Color("#344254"),
	Color("#4a5c72"), Color("#6c8098"), Color("#92aac4")]
var _brass: Array[Color] = [Color("#2c2212"), Color("#4a3a20"), Color("#6c542e"),
	Color("#927440"), Color("#bc9a5c"), Color("#d8bc84")]
var _chitin: Array[Color] = [Color("#182636"), Color("#283e56"), Color("#3a5876"),
	Color("#4d7096"), Color("#6a90b2"), Color("#9cc4de")]
var _gun: Array[Color] = [Color("#0e1116"), Color("#1a1e26"), Color("#2a3038"),
	Color("#3a404c"), Color("#5c6474"), Color("#7d8698")]
## The only warm ramp any of these are allowed, and only where something emits.
var _heat: Array[Color] = [Color("#5c280c"), Color("#964214"), Color("#cc641c"),
	Color("#ffa63c"), Color("#ffdca0"), Color("#fff6e2")]
var _ink: Color = Color("#0b0f16")

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Native size, centred: KEEP_ASPECT rescaled the enemy whenever a rail opened.
	stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	# A TextureRect takes its minimum from its texture, so IGNORE_SIZE lets cropping work.
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clip_contents = true
	custom_minimum_size = Vector2(W, H)
	_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)
	texture = _tex
	var fl := EnemyFlame.new()
	fl.art = self
	fl.top_level = true
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fl.material = ThrusterFx.add_material()
	_flame_layer = fl
	add_child(fl, false, Node.INTERNAL_MODE_FRONT)

## The flame as `holder`'s child right after this art, in tree order, so a panel opened later
## (the piles, #56) covers it. Top level, it drew over everything on the screen.
## Why: docs/why/EnemyArt.md#engine-flame
func host_flame(holder: Control) -> void:
	_flame_layer.get_parent().remove_child(_flame_layer)
	_flame_layer.top_level = false
	holder.add_child(_flame_layer)

func _notification(what: int) -> void:
	# A hosted flame outlives this art unless it goes with it.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_flame_layer) \
			and _flame_layer.get_parent() != self:
		_flame_layer.queue_free()

func px(x: int, y: int, w: int, h: int, c: Color) -> void:
	# Tracked per stroke: the starfield makes `get_used_rect()` say the whole canvas.
	if _track:
		var r := Rect2i(x, y, maxi(w, 1), maxi(h, 1))
		_bounds = r if _bounds.size == Vector2i.ZERO else _bounds.merge(r)
	for j in h:
		for i in w:
			var xx := x + i
			var yy := y + j
			if xx >= 0 and xx < _img.get_width() and yy >= 0 and yy < _img.get_height():
				_img.set_pixel(xx, yy, c)

## Centred, never scaled: no per-ship anchor table, and crisp pixels are the art direction.
## Bounds come from the sprite's own ink, so transparent margin does not leak into them.
## Why: docs/why/EnemyArt.md#sprite-blit
func _blit_sprite(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var src := tex.get_image()
	if src == null:
		return false
	if src.is_compressed():
		src = src.duplicate()
		if src.decompress() != OK:
			push_warning("EnemyArt: could not decompress sprite; drew instead")
			return false
	if src.get_format() != Image.FORMAT_RGBA8:
		src = src.duplicate()
		src.convert(Image.FORMAT_RGBA8)
	var ink := src.get_used_rect()
	if ink.size == Vector2i.ZERO:
		return false
	# Oversized art is refused, not squeezed: a failed asset, as `pixeltools.fit` treats modules.
	if ink.size.x > W or ink.size.y > H:
		push_warning("EnemyArt: sprite ink is %dx%d, canvas is %dx%d; drew instead"
			% [ink.size.x, ink.size.y, W, H])
		return false
	var at := Vector2i((W - ink.size.x) / 2, (H - ink.size.y) / 2)
	_img.blend_rect(src, ink, at)
	_pic_at = at - ink.position
	if _track:
		var r := Rect2i(at, ink.size)
		_bounds = r if _bounds.size == Vector2i.ZERO else _bounds.merge(r)
		_ink_box = r
	return true

## 1, or 0.5 from the half sheet: three or more ships draw at half (Jon), from a file made offline.
var draw_scale: float = 1.0
## The picture's size and its half sheet's: what the pack layout plans with
## (zero while a coded drawing is drawn).
var full_ink: Vector2i = Vector2i.ZERO
var half_ink: Vector2i = Vector2i.ZERO

func set_draw_scale(s: float) -> void:
	if not is_equal_approx(s, draw_scale):
		draw_scale = s
		_sig = ""

func dither(x: int, y: int, w: int, h: int, c: Color, density: float) -> void:
	var thresholds := [0.0, 0.5, 0.75, 0.25]
	for j in h:
		for i in w:
			var t: float = thresholds[(i % 2) + (j % 2) * 2]
			if t < density:
				px(x + i, y + j, 1, 1, c)

func rivets(x: int, y: int, count: int, step: int, c: Color) -> void:
	for i in count:
		px(x + i * step, y, 1, 1, c)


# --- The two-plane kit -------------------------------------------------------

## Six points interpolated, not rectangles. Equal taper on both edges looked like an airship.
## Why: docs/why/EnemyArt.md#hull-profile
func _profile(pts: Array) -> Dictionary:
	var out := {}
	for i in range(pts.size() - 1):
		var a: Vector3i = pts[i]
		var b: Vector3i = pts[i + 1]
		for x in range(a.x, b.x + 1):
			var t := 0.0 if b.x == a.x else float(x - a.x) / float(b.x - a.x)
			out[x] = Vector2i(
				int(round(lerpf(float(a.y), float(b.y), t))),
				int(round(lerpf(float(a.z), float(b.z), t))))
	return out

## Column by column since the shape changes by column. `deck` is the top face's share.
## Turn `cap` off for a piece that runs into another, or a black seam appears.
## Why: docs/why/EnemyArt.md#hull-drawing
func _hull(prof: Dictionary, r: Array, deck: float = 0.55, cap: bool = true) -> void:
	var xs := prof.keys()
	xs.sort()
	if xs.is_empty():
		return
	for x in xs:
		var span: Vector2i = prof[x]
		var t: int = span.x
		var b: int = span.y
		var h := b - t
		if h < 2:
			continue
		var d: int = maxi(2, int(round(h * deck)))
		px(x, t, 1, d, r[3])
		px(x, t, 1, 1, r[4])
		dither(x, t + 1, 1, mini(3, d - 1), r[4], 0.5)
		px(x, t + d - 1, 1, 1, r[5])
		px(x, t + d, 1, h - d, r[1])
		px(x, t + d, 1, mini(2, h - d), r[2])
		dither(x, t + d + 2, 1, maxi(1, (h - d) / 2), r[2], 0.4)
		dither(x, b - 4, 1, 3, r[0], 0.45)
		px(x, b - 1, 1, 1, r[0])
		px(x, t - 1, 1, 1, _ink)
		px(x, b, 1, 1, _ink)
	if cap:
		for raw in [[int(xs[0]), -1], [int(xs[xs.size() - 1]), 1]]:
			var pair: Array = raw
			var e: Vector2i = prof[pair[0]]
			px(int(pair[0]) + int(pair[1]), e.x - 1, 1, e.y - e.x + 2, _ink)

## Slung under a hull sits in its shadow: the ramp two stops down, else it floats apart.
func _under(r: Array) -> Array:
	return [r[0], r[0], r[1], r[1], r[2], r[3]]

## A raised box on the deck. Same lighting as a hull, no taper.
func _plate(x: int, y: int, w: int, h: int, r: Array, deck: float = 0.6) -> void:
	_hull(_profile([Vector3i(x, y, y + h), Vector3i(x + w, y, y + h)]), r, deck)

## A panel seam: a dark line with the light catching the plate edge beside it.
func _seam(x: int, y: int, h: int, r: Array) -> void:
	px(x, y, 1, h, r[0])
	px(x + 1, y, 1, h, r[4])

## Weathering. It runs DOWN the wall, because that is the direction things run.
func _streak(x: int, y: int, h: int, r: Array) -> void:
	dither(x, y, 2, h, r[0], 0.55)

## The only warmth a hull is allowed: solid near the nozzle, dithered out so it has no boundary.
func _glow(x: int, y: int, half: int, length: int) -> void:
	for i in length:
		var t := float(i) / float(length)
		var hh: int = maxi(1, int(round(float(half) * (1.0 - t * 0.72))))
		var col: Color = _heat[1]
		if t < 0.10:
			col = _heat[5]
		elif t < 0.24:
			col = _heat[4]
		elif t < 0.44:
			col = _heat[3]
		elif t < 0.68:
			col = _heat[2]
		if t < 0.34:
			px(x + i, y - hh, 1, hh * 2, col)
		else:
			dither(x + i, y - hh, 1, hh * 2, col, 0.9 - t * 0.85)

## A radiator louvre, glowing from inside its recess.
func _vent(x: int, y: int, w: int, h: int) -> void:
	px(x - 1, y - 1, w + 2, h + 2, _ink)
	px(x, y, w, h, _heat[0])
	px(x, y, w, maxi(1, h / 2), _heat[1])
	px(x, y, w, 1, _heat[2])

## A hole, not a decal: scorch rings and a ragged three-box core, as one box reads as a sticker.
## Why: docs/why/EnemyArt.md#wounds
func _wound(cx: int, cy: int, w: int, h: int, ember: bool = true) -> void:
	# Scorched into the hull's own pixels: flat rectangles read as a cut-out (audit F5).
	var bayer := [0.0, 0.5, 0.75, 0.25]
	var rx := maxi(2, w / 2 + 3)
	var ry := maxi(2, h / 2 + 2)
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			var c := _img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var d := Vector2(float(x - cx) / rx, float(y - cy) / ry).length()
			if d > 1.0:
				continue
			var thr: float = bayer[(y % 2) * 2 + (x % 2)]
			var k := 0.3
			if d >= 0.45 and d < 0.75:
				k = 0.5 if thr < 0.75 else 0.72
			elif d >= 0.75:
				if thr >= 0.5:
					continue
				k = 0.72
			_img.set_pixel(x, y, Color(c.r * k, c.g * k * 0.94, c.b * k * 0.88, c.a))
	if not ember:
		return
	# A still-hot crack drawn as light, on plating only.
	var half := maxi(2, w / 2)
	for i in range(-half, half + 1):
		var x2 := cx + i
		var y2 := cy + ((i * 7 + 3) % 3) - 1
		if x2 < 0 or y2 < 1 or x2 >= W or y2 >= H - 1:
			continue
		if _img.get_pixel(x2, y2).a < 0.5:
			continue
		var f := absf(float(i)) / float(half)
		_img.set_pixel(x2, y2, _heat[3] if f < 0.3 else (_heat[2] if f < 0.7 else _heat[1]))
		for dy in [-1, 1]:
			var y3: int = y2 + dy
			if (x2 + y3) % 2 == 0 and _img.get_pixel(x2, y3).a >= 0.5 and f < 0.7:
				_img.set_pixel(x2, y3, _heat[0])


# --- The enemies -------------------------------------------------------------

## Ships and creatures roll from separate pools (Jon, Oct 13). E CHAIN and H SLICE are cut.
## The Custodian rolls from the ships' pool and plays its boss version.
## Why: docs/why/EnemyArt.md#death-styles
const SHIP_STYLES: Array[int] = [0, 1, 2, 3, 5, 6, 8, 9, 10, 11, 12]
const CREATURE_STYLES: Array[int] = [13, 14, 15]
## Bosses die their own set pieces (ShipBreakup, Oct 13). Jon picked the Custodian's three.
const CUSTODIAN_STYLES: Array[int] = [16, 22, 23]
const HELLBENDER_STYLES: Array[int] = [21]

## A fact about where the wreck lies, so the kill and LOCAL's wreck agree with nothing saved.
## `Rng.derive`, as every positional thing is, so a seeded run replays the same deaths.
## Why: docs/why/EnemyArt.md#death-styles
static func death_style(t: EnemyTemplate, node_index: int, nth_wreck: int) -> int:
	var pool := CREATURE_STYLES if t.fauna else SHIP_STYLES
	if t.id == &"custodian":
		pool = CUSTODIAN_STYLES
	elif t.id == &"hellbender":
		pool = HELLBENDER_STYLES
	var r := Rng.derive(&"death", node_index * 64 + nth_wreck)
	return pool[r.randi() % pool.size()]

## A style for a dead ship nothing has told us about: the first of its pool.
static func _default_style(t: EnemyTemplate) -> int:
	return CREATURE_STYLES[0] if t.fauna else SHIP_STYLES[0]

## The same cut every time a ship of this kind dies, so the wreck on LOCAL is the
## wreck the fight left.
static func wreck_seed(t: EnemyTemplate) -> int:
	return hash(String(t.id)) & 0x7fffffff

## A copy of what is on the canvas now: what a breakup cuts up.
func snapshot() -> Image:
	return _img.duplicate()

## Cut ahead of the kill: 40 to 90 ms on the killing frame froze three to six frames.
## No lock and no object in a static: a Mutex in a static var crashed on exit (139).
## Why: docs/why/EnemyArt.md#wreck-cache
static var _wrecks: Dictionary = {}
## Wrecks keep their fight's hit marks (Jon, Oct 13). This session only: a save restores clean ones.
## Why: docs/why/EnemyArt.md#wreck-cache
static var _marked: Dictionary = {}

## Hit marks are baked in under the dark blend, so the wreck cut from the picture keeps them.
var marks: ShipHitFx = null
## Where this ship's wreck will lie (`node * 64 + nth`), or -1.
var wreck_id: int = -1

static func set_marked_wreck(id: int, style: int, img: Image) -> void:
	if id >= 0 and img != null:
		_marked[id] = {style = style, img = img}
static var _wreck_tasks: Dictionary = {}

## Keyed to the kind: `max_hp > 60` called every calf big once enemy hull went to x2.
static func big_fauna(t: EnemyTemplate) -> bool:
	return t.fauna and t.id == &"leviathan"

static func _wreck_key(t: EnemyTemplate, style: int, look: int, scale: float = 1.0) -> String:
	# Size only changes fauna. `look` is the picture worn, `scale` is how big the pack drew it.
	return "%s|%d|%d|%d|%.3f" % [t.id, int(big_fauna(t)), style, look, scale]

## Start cutting this enemy's wreck now, off the main thread. Drawing the dead
## canvas to cut is the only part done here (a few ms).
static func warm_wreck(e: Combat.EnemyState, style: int, scale: float = 1.0) -> void:
	var key := _wreck_key(e.template, style, e.look, scale)
	if _wrecks.has(key) or _wreck_tasks.has(key):
		return
	var dc := dead_canvas(e, null, scale)
	var img: Image = dc[0]
	var used: Rect2i = dc[1]
	var seed := wreck_seed(e.template)
	var boss: bool = e.template.boss
	var held := {}
	var task := WorkerThreadPool.add_task(func() -> void:
		held[&"w"] = ShipBreakup.wreck_image(img, used, seed, boss, style))
	_wreck_tasks[key] = [task, held]

static func _take_wreck(key: String) -> Image:
	if _wreck_tasks.has(key):
		var t: Array = _wreck_tasks[key]
		_wreck_tasks.erase(key)
		WorkerThreadPool.wait_for_task_completion(int(t[0]))
		var held: Dictionary = t[1]
		if held.has(&"w"):
			_wrecks[key] = held[&"w"]
	return _wrecks.get(key)

## The breakup cuts this, not the live picture, so every later dead draw is one image to the pixel.
## Why: docs/why/EnemyArt.md#dead-canvas
static func dead_canvas(e: Combat.EnemyState, with_marks: ShipHitFx = null, scale: float = 1.0) -> Array:
	var art := EnemyArt.new()
	art.marks = with_marks
	# at the size the pack draws it (`draw_scale`: 0.5 from its half sheet)
	art.draw_scale = scale
	var ghost := Combat.EnemyState.new()
	ghost.template = e.template
	ghost.max_hp = e.max_hp
	ghost.hp = 0
	# THE SAME PICTURE the ship wears: a kind has three, and a wreck cut from
	# another would not be this ship's.
	ghost.look = e.look
	art.set_enemy(ghost, false, -1, false)
	var out := [art._img.duplicate(), art._used]
	art.free()
	return out

## Wait out every cut still running and keep what they made. Called when a
## fight's screen goes, so no task outlives the scene that asked for it.
static func reap_wrecks() -> void:
	for key in _wreck_tasks.keys():
		_take_wreck(key)

## `hp` stands in for hull while the screen holds a number back (combat polish, Oct 13).
func set_enemy(e: Combat.EnemyState, telegraphing: bool, hp: int = -1,
		cut_wreck: bool = true, style: int = -1) -> void:
	var hull := e.hp if hp < 0 else hp
	var wounded := float(hull) / float(maxi(1, e.max_hp))
	var dead := hull <= 0
	# Skip the redraw unless art, wind-up, hurt or size moved: bind() runs every refresh.
	# The id is in the signature: three kinds share `cutter`, three `hulk`.
	# Why: docs/why/EnemyArt.md#redraw-cache
	var sig := "%s|%s|%d|%d|%d|%d|%d" % [e.template.id, e.template.art, int(telegraphing),
		int(wounded * 20.0), int(big_fauna(e.template)), int(dead), int(cut_wreck) * (style + 2)]
	sig += "|look %d|scale %.3f" % [e.look, draw_scale]
	if marks != null:
		sig += "|marks %d" % marks.version
	if dead and _marked.has(wreck_id):
		sig += "|marked"
	if sig == _sig:
		return
	_sig = sig

	# Transparent: the encounter draws one starfield behind everything, and an
	# opaque fill turns the sprite into a box sitting on top of it.
	_img.fill(Color(0, 0, 0, 0))
	# Bounds track after the starfield and before the tint, so they measure the ship alone.
	_bounds = Rect2i()
	_ink_box = Rect2i()
	_track = true
	# One door: sprite if it has one, drawing if not, so no enemy vanishes for a missing file.
	# Damage and telegraph stay drawn over a sprite, keeping the asset set at nine files.
	# Why: docs/why/EnemyArt.md#sprite-or-drawing
	_flame_fx = null
	if not _draw_sprite(e, wounded, telegraphing):
		_draw_coded(e, wounded, telegraphing)
	elif not dead:
		var stex := DB.enemy_sprite(e.template.id, e.look)
		if stex != null and not (stex.resource_path.get_file().get_basename() in NO_FLAME):
			# the half sheet when that is what `_draw_sprite` drew
			var htex := DB.enemy_sprite(e.template.id, e.look, true) if draw_scale < 1.0 else null
			_flame_fx = ThrusterFx.for_picture(stex, 1.0, htex)
			_flame_at = Vector2(_pic_at)
	_track = false
	if marks != null:
		var mi := marks.marks()
		if mi != null:
			_img.blend_rect(mi, Rect2i(Vector2i.ZERO, mi.get_size()), marks.marks_at())
		for q in marks.cut_px():
			_img.set_pixel(int(q.x), int(q.y), Color(0, 0, 0, 0))
	_used = _bounds if _bounds.size != Vector2i.ZERO else Rect2i(0, 0, W, H)

	# The Control shrinks to the ship: eighty empty pixels held the health bar and intent far away.
	# Sized symmetrically about the centre, as the texture is KEEP_CENTERED.
	# Why: docs/why/EnemyArt.md#control-sizing
	var cx := W * 0.5
	var cy := H * 0.5
	# The picture's own box, not its light: a wind-up flare would move its neighbours.
	var box := _ink_box if _ink_box.size != Vector2i.ZERO else _used
	var half_w: float = maxf(absf(float(box.position.x) - cx), absf(float(box.end.x) - cx))
	var half_h: float = maxf(absf(float(box.position.y) - cy), absf(float(box.end.y) - cy))
	clip_contents = true
	custom_minimum_size = Vector2(half_w, half_h) * 2.0 + Vector2(6, 6)
	if wounded < 0.3:
		_blend_rect(0, 0, W, H, Color(0.031, 0.043, 0.067, 0.35))
	# A dead ship is its wreck, so LOCAL's wrecks match the hull the animation ended on.
	if dead and cut_wreck:
		var st := style if style >= 0 else _default_style(e.template)
		var key := _wreck_key(e.template, st, e.look, draw_scale)
		var w := _take_wreck(key)
		var mk: Dictionary = _marked.get(wreck_id, {})
		if not mk.is_empty() and int(mk.style) == st:
			w = mk.img
		if w == null:
			w = ShipBreakup.wreck_image(_img, _used, wreck_seed(e.template),
				e.template.boss, st)
			_wrecks[key] = w
		_img = w.duplicate()
	_tex.update(_img)

## No stars on this canvas: a star through a gap would break off as hull in the breakup cut.
## Why: docs/why/EnemyArt.md#sprite-drawing
func _draw_sprite(e: Combat.EnemyState, wounded: float, telegraphing: bool) -> bool:
	var full := DB.enemy_sprite(e.template.id, e.look)
	var half := DB.enemy_sprite(e.template.id, e.look, true)
	full_ink = Vector2i(full.get_size()) if full != null else Vector2i.ZERO
	half_ink = Vector2i(half.get_size()) if half != null else full_ink
	if not _blit_sprite(half if draw_scale < 1.0 and half != null else full):
		return false
	var ink := _bounds
	# Damage uses `_wound` like coded ships. A fight's hit marks stand in for the stock wounds.
	if wounded < 0.5 and marks == null:
		var p := _on_hull(ink, Vector2(0.42, 0.55))
		_wound(p.x, p.y, clampi(ink.size.x / 9, 10, 22), clampi(ink.size.y / 6, 7, 14))
	if wounded < 0.25 and marks == null:
		var q := _on_hull(ink, Vector2(0.7, 0.42))
		_wound(q.x, q.y, clampi(ink.size.x / 13, 8, 16), clampi(ink.size.y / 8, 6, 10))
	if telegraphing:
		_windup(e.template, ink, e.look)
	return true

## For kinds with no picture. Authored in 240x120, laid in the middle, stars behind as ever.
func _draw_coded(e: Combat.EnemyState, wounded: float, telegraphing: bool) -> void:
	var full := _img
	_img = Image.create(CODED.x, CODED.y, false, Image.FORMAT_RGBA8)
	var before := _bounds
	_bounds = Rect2i()
	match e.template.art:
		&"cutter": _draw_cutter(wounded)
		&"hulk": _draw_hulk(wounded, telegraphing)
		&"hellbender": _draw_hellbender(wounded, telegraphing)
		# Explicit: the `_:` fallback turned unmatched keys into fauna (the Custodian).
		&"whale": _draw_fauna(wounded, big_fauna(e.template))
		_:
			push_warning("EnemyArt: no drawing for art key '%s' (%s); drew fauna"
				% [e.template.art, e.template.id])
			_draw_fauna(wounded, big_fauna(e.template))
	var drawn := _img
	_img = full
	var o := (Vector2i(W, H) - CODED) / 2
	var was_tracking := _track
	_track = false
	_starfield(77, 26)
	_track = was_tracking
	_img.blend_rect(drawn, Rect2i(Vector2i.ZERO, CODED), o)
	if _bounds.size != Vector2i.ZERO:
		_bounds = Rect2i(_bounds.position + o, _bounds.size)
	if before.size != Vector2i.ZERO:
		_bounds = before.merge(_bounds) if _bounds.size != Vector2i.ZERO else before


## A pixel inside the hull near a point of its box (`at`, 0..1 across and down),
## with hull all round it, so a wound lands on plating rather than in a gap.
func _on_hull(ink: Rect2i, at: Vector2) -> Vector2i:
	var want := ink.position + Vector2i(int(ink.size.x * at.x), int(ink.size.y * at.y))
	for r in range(0, 40):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var p := want + Vector2i(dx, dy)
				if _solid(p, 3):
					return p
	return want

## Hull all the way round `p`, `r` pixels out.
func _solid(p: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := p.x + dx
			var y := p.y + dy
			if x < 0 or y < 0 or x >= W or y >= H or _img.get_pixel(x, y).a < 0.5:
				return false
	return true


## A sprite is lit, not painted: plating near the source brightens, emitters pass the edge.
## Still while the intent holds, as the picture redraws only on change.
## Why: docs/why/EnemyArt.md#wind-up-light
const WINDUP := {&"hulk": &"nose", &"hellbender": &"stern"}
const COLD: Array[Color] = [Color("#3a6b8c"), Color("#5c9cc4"), Color("#8ec8e6"),
	Color("#cfe8f5"), Color("#eaf6fc"), Color("#ffffff")]

## Where a picture's heart is, as a box share. Unlisted ones charge at their mass.
const CORE_AT := {"custodian_t1_grown": Vector2(0.23, 0.46)}

func _windup(t: EnemyTemplate, ink: Rect2i, look: int = 0) -> void:
	var where: StringName = WINDUP.get(t.id, &"core")
	match where:
		&"nose":
			var p := _end_point(ink, ink.position.x)
			_light(p, clampf(ink.size.y * 0.7, 16.0, 34.0), _heat[3], 1.0)
			_flare(p, 7)
		&"stern":
			var p := _end_point(ink, ink.end.x - 1)
			_light(p, clampf(ink.size.y * 0.8, 18.0, 40.0), _heat[3], 1.0)
			_glow(p.x + 1, p.y, maxi(4, ink.size.y / 7), 30)
		_:
			var files := DB.enemy_sprite_files(t.id)
			var key := String(files[posmod(look, files.size())]).get_basename() if not files.is_empty() else ""
			var p := _on_hull(ink, CORE_AT.get(key, _mass(ink)))
			_pool(p, clampf(minf(ink.size.x, ink.size.y) * 0.7, 20.0, 52.0), COLD[3], 1.6)
			# the heart itself, white, on the hull only
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var q := p + Vector2i(dx, dy)
					if absi(dx) + absi(dy) <= 2 and _img.get_pixel(q.x, q.y).a > 0.5:
						_img.set_pixel(q.x, q.y, COLD[5] if absi(dx) + absi(dy) <= 1 else COLD[4])

## Where the hull's mass sits in its box, 0..1.
func _mass(ink: Rect2i) -> Vector2:
	var sx := 0.0
	var sy := 0.0
	var n := 0
	for y in range(ink.position.y, ink.end.y, 2):
		for x in range(ink.position.x, ink.end.x, 2):
			if _img.get_pixel(x, y).a > 0.5:
				sx += x
				sy += y
				n += 1
	if n == 0:
		return Vector2(0.5, 0.5)
	return Vector2((sx / n - ink.position.x) / maxf(1.0, ink.size.x),
		(sy / n - ink.position.y) / maxf(1.0, ink.size.y))

## The middle of the hull's run down the column nearest `x` that has some: a
## nose, or a drive.
func _end_point(ink: Rect2i, x: int) -> Vector2i:
	var step := 1 if x <= ink.get_center().x else -1
	for k in range(0, 16):
		var cx := x + k * step
		var ys: Array[int] = []
		for y in range(ink.position.y, ink.end.y):
			if _img.get_pixel(cx, y).a > 0.5:
				ys.append(y)
		if ys.size() >= 2:
			return Vector2i(cx, ys[ys.size() / 2])
	return Vector2i(x, ink.get_center().y)

## Light falling on the plating round `p`: added, with falloff, in quarter
## steps, the outer band dithered so the pool has no ring.
func _light(p: Vector2i, r: float, col: Color, strength: float) -> void:
	var bayer := [0.0, 0.5, 0.75, 0.25]
	var ri := int(ceil(r))
	for y in range(p.y - ri, p.y + ri + 1):
		for x in range(p.x - ri, p.x + ri + 1):
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			var c := _img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var d := Vector2(x - p.x, y - p.y).length() / r
			if d >= 1.0:
				continue
			var k := floorf((1.0 - d) * (1.0 - d) * strength * 4.0 + 0.5) / 4.0
			if d > 0.7:
				k = 0.12 if float(bayer[(y % 2) * 2 + (x % 2)]) < 0.5 else 0.0
			if k <= 0.0:
				continue
			_img.set_pixel(x, y, Color(minf(1.0, c.r + col.r * k), minf(1.0, c.g + col.g * k),
				minf(1.0, c.b + col.b * k), c.a))

## Smooth pool via a 4x4 ordered dither: `_light`'s quarter steps read as rings on the core guard.
const BAYER4: Array[float] = [0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0]

func _pool(p: Vector2i, r: float, col: Color, strength: float) -> void:
	var ri := int(ceil(r))
	for y in range(p.y - ri, p.y + ri + 1):
		for x in range(p.x - ri, p.x + ri + 1):
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			var c := _img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var d := Vector2(x - p.x, y - p.y).length() / r
			if d >= 1.0:
				continue
			var e := (1.0 - d) * (1.0 - d) * (1.0 + 0.5 * (1.0 - d)) / 1.5 * strength
			var thr: float = (BAYER4[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0
			var k := floorf(e * 8.0 + thr) / 8.0
			if k <= 0.0:
				continue
			_img.set_pixel(x, y, Color(minf(1.0, c.r + col.r * k), minf(1.0, c.g + col.g * k),
				minf(1.0, c.b + col.b * k), c.a))

## A hot point standing off the nose: the one place a ram's wind-up lights
## empty space. Solid at the point, dithered out, the heat ramp.
func _flare(p: Vector2i, r: int) -> void:
	for y in range(p.y - r, p.y + r + 1):
		for x in range(p.x - r - 4, p.x + 2):
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			var d := Vector2(float(x - p.x) * 0.7, float(y - p.y)).length() / float(r)
			if d >= 1.0 or (_img.get_pixel(x, y).a > 0.5 and x > p.x):
				continue
			if d >= 0.7 and (x + y) % 2 == 0:
				continue
			px(x, y, 1, 1, _heat[5] if d < 0.25 else (_heat[4] if d < 0.45 else (_heat[3] if d < 0.7 else _heat[2])))


## Rustjaw Cutter: a blade with an engine bolted to the back of it, nosing left.
func _draw_cutter(wounded: float) -> void:
	var body := _profile([
		Vector3i(40, 66, 71), Vector3i(50, 58, 75), Vector3i(62, 50, 77),
		Vector3i(78, 44, 78), Vector3i(100, 41, 79), Vector3i(130, 41, 78),
		Vector3i(146, 43, 75), Vector3i(158, 46, 71), Vector3i(166, 49, 68)])

	# Dorsal blade first, so the hull's own rim light cuts across its foot and
	# it reads as growing out of the deck rather than floating over it.
	_hull(_profile([
		Vector3i(90, 40, 46), Vector3i(100, 31, 46), Vector3i(110, 26, 46),
		Vector3i(118, 25, 46), Vector3i(134, 33, 46), Vector3i(146, 41, 46)]),
		_steel, 0.62, false)
	# Ventral strake, in the hull's shadow.
	_hull(_profile([
		Vector3i(100, 75, 85), Vector3i(112, 75, 89), Vector3i(128, 75, 87),
		Vector3i(136, 75, 80)]), _under(_steel), 0.3, false)
	_hull(body, _steel, 0.56)

	# Seams stop at the lip. A seam drawn across it flattens the one value break
	# that is holding the whole sprite up.
	for x in [92, 110, 128]:
		var span: Vector2i = body[x]
		_seam(x, span.x + 2, int(float(span.y - span.x) * 0.56) - 3, _steel)
	rivets(84, 47, 20, 4, _steel[1])
	rivets(84, 71, 20, 4, _steel[0])
	# Recessed hatches go one stop down with a far-side lip: near black they read as holes.
	for raw in [[94, 12], [110, 9], [123, 12]]:
		var hatch: Array = raw
		var hx: int = hatch[0]
		var hw: int = hatch[1]
		px(hx, 47, hw, 6, _steel[1])
		px(hx, 47, hw, 2, _steel[0])
		dither(hx, 49, hw, 2, _steel[2], 0.4)
		px(hx, 52, hw, 1, _steel[4])
	# Hull number, stencilled. Four glyphs of three pixels: enough to read as
	# writing, not enough to pretend it says anything.
	for i in 4:
		var bits: int = [0b111, 0b010, 0b101, 0b110][i]
		for b in 3:
			if (bits >> (2 - b)) & 1:
				px(136 + i * 4, 62 + b, 2, 1, _steel[5])
	for x in [84, 100, 116, 132, 146]:
		_streak(x, 66, 11, _steel)

	# Canopy, set into the deck behind the nose.
	px(68, 49, 18, 8, _ink)
	px(69, 50, 16, 6, Color("#162e40"))
	px(69, 50, 16, 3, Color("#3a6b8c"))
	px(70, 50, 10, 2, Color("#8ec8e6"))
	px(70, 50, 6, 1, Color("#cfe8f5"))

	# Korvan gun, slung under the prow with the barrel out front.
	_hull(_profile([Vector3i(58, 72, 84), Vector3i(84, 72, 84)]), _brass, 0.5)
	for i in 4:
		px(61 + i * 6, 78, 3, 2, Color("#a8873f"))
	px(46, 75, 13, 5, _ink)
	px(46, 76, 12, 3, _gun[2])
	px(46, 76, 12, 1, _gun[4])
	px(40, 77, 6, 1, _gun[1])

	# Engine block, louvres and the wash it throws.
	_hull(_profile([Vector3i(166, 48, 70), Vector3i(178, 50, 68)]), _gun, 0.5)
	_vent(158, 51, 8, 5)
	_vent(158, 62, 8, 5)
	px(178, 53, 5, 12, _ink)
	px(178, 54, 5, 10, _gun[1])
	px(178, 54, 5, 1, _gun[3])
	_glow(183, 59, 6, 20)

	# Mast, with a running light on it.
	px(107, 22, 3, 8, _gun[2])
	px(106, 21, 5, 2, _gun[4])
	px(107, 19, 3, 2, Color("#d64a3a"))

	if wounded < 0.5:
		_wound(112, 58, 17, 12)

## Dreg Hulk: tonnage. The hull steps at both ends and the deck is stacked, so
## the mass reads as decks and containers instead of one filled rectangle.
func _draw_hulk(wounded: float, telegraphing: bool) -> void:
	var body := _profile([
		Vector3i(42, 46, 70), Vector3i(50, 34, 84), Vector3i(56, 29, 91),
		Vector3i(58, 28, 92), Vector3i(146, 28, 92), Vector3i(150, 29, 91),
		Vector3i(156, 34, 86), Vector3i(164, 40, 80)])

	# Containers first: the hull's outline then cuts their feet off, which is
	# what puts them ON the deck rather than behind it.
	for raw in [[60, 24, 13], [88, 28, 16], [122, 22, 12]]:
		var box: Array = raw
		var bx: int = box[0]
		var bw: int = box[1]
		var bh: int = box[2]
		_plate(bx, 30 - bh, bw, bh, _brass, 0.66)
		rivets(bx + 3, 32 - bh, (bw - 6) / 4, 4, _brass[1])
	_hull(body, _brass, 0.52)

	for x in [74, 98, 122, 146]:
		var span: Vector2i = body[x]
		var d := int(float(span.y - span.x) * 0.52)
		_seam(x, span.x + 2, d - 3, _brass)
		_streak(x + 3, span.x + d + 4, 22, _brass)
	rivets(58, 33, 26, 4, _brass[1])
	rivets(58, 56, 26, 4, _brass[0])
	# Hazard banding along the deck edge, and cargo tie-down points. Density is
	# what makes tonnage read as tonnage.
	for i in 11:
		px(64 + i * 8, 37, 4, 2, Color("#a8873f"))
	for i in 8:
		px(66 + i * 11, 44, 2, 2, _brass[0])
		px(66 + i * 11, 44, 2, 1, _brass[4])
	# Cargo wells, open, with something down in each of them.
	for raw2 in [[64, 16], [86, 20], [112, 14], [132, 12]]:
		var well: Array = raw2
		var hx: int = well[0]
		var hw: int = well[1]
		px(hx, 48, hw, 9, _brass[1])
		px(hx, 48, hw, 2, _brass[0])
		dither(hx, 50, hw, 4, _brass[2], 0.4)
		px(hx + 2, 52, hw - 4, 4, _brass[2])
		px(hx + 2, 52, hw - 4, 1, _brass[3])
		px(hx, 56, hw, 1, _brass[4])
	# Lit portholes: there is a crew aboard. This looks like ambient warmth and
	# is not — every one of these pixels is a window with a light behind it.
	for i in 11:
		px(58 + i * 9, 70, 4, 3, _heat[0])
		px(58 + i * 9, 70, 4, 1, _heat[2])
	for i in 9:
		px(62 + i * 10, 82, 3, 2, _brass[0])
		px(62 + i * 10, 82, 3, 1, _brass[2])
	# Ventral pod, so the underside is not one uninterrupted wall.
	_hull(_profile([
		Vector3i(86, 86, 98), Vector3i(100, 86, 103), Vector3i(122, 86, 101),
		Vector3i(134, 86, 93)]), _under(_brass), 0.25, false)

	# Bridge blister aft.
	_plate(126, 20, 24, 12, _brass, 0.5)
	px(130, 24, 16, 5, Color("#162e40"))
	px(130, 24, 16, 2, Color("#3a6b8c"))
	px(131, 24, 9, 1, Color("#8ec8e6"))

	# Stern engine bank.
	_hull(_profile([Vector3i(166, 40, 80), Vector3i(182, 44, 76)]), _gun, 0.5)
	for y in [46, 58, 70]:
		_vent(158, y, 8, 6)
	px(182, 50, 6, 20, _ink)
	px(182, 51, 6, 18, _gun[1])
	px(182, 51, 6, 1, _gun[3])
	_glow(188, 60, 10, 18)

	# The ram prow. Telegraphing lights it, so the tell and the weapon are the
	# same object — you learn what the glow means by being hit by it once.
	_hull(_profile([Vector3i(30, 50, 66), Vector3i(44, 46, 70)]), _brass, 0.5)
	if telegraphing:
		px(24, 51, 8, 14, _heat[2])
		px(24, 51, 8, 3, _heat[4])
		px(18, 54, 6, 8, _heat[4])
		px(13, 56, 5, 4, _heat[5])
		dither(4, 48, 12, 20, _heat[3], 0.5)
		dither(0, 52, 5, 12, _heat[2], 0.3)
	else:
		px(24, 51, 8, 14, _ink)
		px(25, 52, 7, 12, _brass[2])
		px(25, 52, 7, 2, _brass[4])

	if wounded < 0.5:
		_wound(100, 58, 24, 17)

## A furnace wearing a hull: black iron with ember light. No new ramp, those are for manufacturers.
## Its telegraph is the escape burn, so the tell lights the drive, not a weapon.
## Why: docs/why/EnemyArt.md#hellbender-art
func _draw_hellbender(wounded: float, telegraphing: bool) -> void:
	var body := _profile([
		Vector3i(46, 52, 74), Vector3i(58, 44, 82), Vector3i(72, 40, 86),
		Vector3i(96, 38, 88), Vector3i(128, 38, 88), Vector3i(150, 40, 85),
		Vector3i(164, 44, 80), Vector3i(174, 48, 74)])

	# Radiator spine first, so the hull's rim light cuts across its foot — the
	# same trick that seats the hulk's containers on its deck.
	_hull(_profile([
		Vector3i(78, 32, 44), Vector3i(90, 29, 44), Vector3i(140, 28, 44),
		Vector3i(152, 31, 44)]), _gun, 0.6, false)
	_hull(body, _gun, 0.5)
	# The spine's louvres, glowing out of their recesses. Five of them: this is
	# the ship the chart draws in ember, and the sprite has to be why.
	for i in 5:
		_vent(84 + i * 13, 31, 8, 5)

	# Seams carry the hold's fire in their lower half. The two-plane break stays above the lip.
	for x in [70, 92, 114, 136, 156]:
		var span: Vector2i = body[x]
		var d := int(float(span.y - span.x) * 0.5)
		_seam(x, span.x + 2, d - 3, _gun)
		px(x, span.x + d + 4, 1, 10, _heat[1])
		px(x, span.x + d + 4, 1, 2, _heat[2])
		_streak(x + 3, span.x + d + 4, 18, _gun)
	rivets(64, 42, 24, 4, _gun[1])
	# Crew windows, every one of them furnace-coloured. The hulk's portholes
	# say somebody lives aboard; these say what they live inside.
	for i in 9:
		px(66 + i * 11, 78, 3, 2, _heat[0])
		px(66 + i * 11, 78, 3, 1, _heat[3])

	# The salamander device on a plaque: enough pixels for heraldry, unglossed (docs/lore.md).
	px(99, 55, 18, 13, _ink)
	px(100, 56, 16, 11, _gun[1])
	px(100, 56, 16, 1, _gun[3])
	px(112, 58, 2, 2, _heat[4])
	for raw in [[110, 59], [108, 60], [106, 61], [105, 62], [106, 63], [108, 64]]:
		var seg: Array = raw
		px(int(seg[0]), int(seg[1]), 2, 1, _heat[3])
	for fx in [103, 107, 111]:
		px(fx, 65, 1, 1, _heat[2])

	# The intake maw is the bow, as it is what the ship is for. Never fully cold.
	_hull(_profile([Vector3i(26, 46, 58), Vector3i(48, 44, 60)]), _gun, 0.55)
	_hull(_profile([Vector3i(30, 64, 76), Vector3i(48, 62, 78)]),
		_under(_gun), 0.35, false)
	px(28, 59, 18, 4, _ink)
	dither(30, 60, 14, 2, _heat[0], 0.6)
	dither(32, 60, 8, 1, _heat[1], 0.4)
	# Cutting teeth along both jaws.
	for i in 4:
		px(28 + i * 5, 57, 2, 2, _gun[4])
		px(30 + i * 5, 63, 2, 2, _gun[3])

	# Stern drive block, oversized for the tonnage — it runs hot because it can.
	_hull(_profile([Vector3i(174, 46, 76), Vector3i(188, 49, 73)]), _gun, 0.5)
	_vent(166, 52, 8, 5)
	_vent(166, 64, 8, 5)
	px(188, 52, 6, 18, _ink)
	px(188, 53, 6, 16, _gun[1])
	px(188, 53, 6, 1, _gun[3])

	# Escape burn spooling: one full turn of this is the window to finish it.
	if telegraphing:
		px(189, 55, 4, 12, _heat[5])
		for i in 5:
			px(84 + i * 13, 31, 8, 3, _heat[3])
			px(84 + i * 13, 31, 8, 1, _heat[5])
		_glow(194, 61, 11, 34)
		dither(196, 44, 30, 34, _heat[3], 0.35)
	else:
		_glow(194, 61, 9, 22)

	if wounded < 0.5:
		_wound(94, 60, 20, 14)
	# A second, older hole: damage carries between engagements, so a repeat meeting shows it.
	if wounded < 0.25:
		_wound(142, 50, 13, 9)


## Fauna light is cold: nothing alive out here runs a furnace.
func _draw_fauna(wounded: float, big: bool) -> void:
	var segs := 12 if big else 10
	var seg_w := 11 if big else 10
	var span := 52.0 if big else 42.0
	var x0 := 54

	# Tail first so plates overlap, trailing edge laid last or it merges into a teardrop.
	for k in segs:
		var i := segs - 1 - k
		var h := int(round(span - absf(float(i) - float(segs) / 2.0 + 0.5) * 4.4))
		var x := x0 + i * seg_w
		var t := 60 - int(float(h) * 0.52)
		var nxt := int(round(span - absf(float(i + 1) - float(segs) / 2.0 + 0.5) * 4.4))
		var nt := 60 - int(float(nxt) * 0.52)
		_hull(_profile([Vector3i(x, t, t + h),
			Vector3i(x + seg_w + 2, nt, nt + nxt)]), _chitin, 0.5, false)
		px(x + seg_w + 2, t - 1, 1, h + 3, _ink)
		px(x + seg_w + 1, t, 1, int(float(h) * 0.5), _chitin[5])
		px(x + seg_w + 1, t + int(float(h) * 0.5), 1,
			h - int(float(h) * 0.5), _chitin[0])
		# Dorsal ridge, and a bio-light in the shadow under the shell.
		px(x + 1, t + 1, seg_w - 1, 2, _chitin[5])
		if i % 2 == 0:
			px(x + 4, t + int(float(h) * 0.5) + 3, 3, 2, Color("#4fbfa8"))
			px(x + 4, t + int(float(h) * 0.5) + 3, 3, 1, Color("#a8f0dc"))
		if i >= 1 and i < segs - 1:
			px(x + 5, t + h, 2, 4 + (i % 3) * 2, _chitin[0])
			px(x + 5, t + h, 1, 3, _chitin[1])

	# Head: heavier than the body, and where the mouth is.
	_hull(_profile([Vector3i(26, 48, 68), Vector3i(34, 41, 76),
		Vector3i(44, 37, 82), Vector3i(56, 36, 84)]), _chitin, 0.48)
	px(30, 42, 24, 2, _chitin[5])

	# Mandibles. The lower one is a stop darker than the upper one for the same
	# reason everything else here is: the light comes from above.
	px(16, 44, 12, 5, _ink)
	px(16, 45, 12, 3, _chitin[3])
	px(16, 45, 12, 1, _chitin[5])
	px(16, 70, 12, 5, _ink)
	px(16, 71, 12, 3, _chitin[1])
	px(16, 71, 12, 1, _chitin[3])
	px(10, 47, 7, 2, _chitin[2])
	px(10, 72, 7, 2, _chitin[0])

	# Eye cluster. Four is a creature; one is a robot.
	for raw in [[32, 52], [39, 50], [33, 61], [41, 59]]:
		var eye: Array = raw
		var ex: int = eye[0]
		var ey: int = eye[1]
		px(ex - 1, ey - 1, 7, 6, _ink)
		px(ex, ey, 5, 4, Color("#1d3a4e"))
		px(ex, ey, 5, 2, Color("#5c82a4"))
		px(ex + 1, ey, 3, 1, Color("#cfe8f5"))

	var tx := x0 + segs * seg_w
	_hull(_profile([Vector3i(tx, 52, 68), Vector3i(tx + 10, 55, 65),
		Vector3i(tx + 18, 58, 62)]), _chitin, 0.5)

	if wounded < 0.55:
		for raw2 in [[-8, -6, 16, 12, 0.25, "#7a3a54"], [-5, -3, 10, 6, 0.5, "#5a2c44"],
				[-2, -1, 4, 2, 0.85, "#3a1c2e"]]:
			var g: Array = raw2
			dither(110 + int(g[0]), 51 + int(g[1]), 18 + int(g[2]),
				11 + int(g[3]), Color(String(g[5])), float(g[4]))
		for raw3 in [[0, 0, 16, 10], [-4, 3, 11, 6], [5, -2, 9, 5]]:
			var q: Array = raw3
			px(119 - int(q[2]) / 2 + int(q[0]), 51 - int(q[3]) / 2 + int(q[1]),
				int(q[2]), int(q[3]), Color("#20101c"))
		px(116, 54, 5, 2, Color("#4fbfa8"))
		px(116, 54, 3, 1, Color("#a8f0dc"))

func _starfield(seed_value: int, count: int) -> void:
	var s := seed_value
	for i in count:
		s = (s * 9301 + 49297) % 233280
		var x := int(float(s) / 233280.0 * W)
		s = (s * 9301 + 49297) % 233280
		var y := int(float(s) / 233280.0 * H)
		px(x, y, 1, 1, Color("#141c26"))

func _blend_rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			var xx := x + i
			var yy := y + j
			if xx >= 0 and xx < W and yy >= 0 and yy < H:
				# On the hull only: lerping transparent pixels left a faint box round the ship.
				var was := _img.get_pixel(xx, yy)
				if was.a <= 0.0:
					continue
				var mix := was.lerp(c, c.a)
				mix.a = was.a
				_img.set_pixel(xx, yy, mix)
