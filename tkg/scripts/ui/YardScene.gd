class_name YardScene
extends Control

## The Shipyard: one of Jon's five painted halls, lit and running, with your ship
## and the one for sale on their stands, the yard's four services flying over
## yours on drones, and the deal on a TV at the bottom right.
##
## IT WAS A HANGAR DRAWN IN CODE, with the services standing in a bay as four
## machines. It is the Yard Drones page now -- the artifact Jon built this with,
## note by note, and passed at v46 -- and `tools/yard_install.py` installed its
## halls, pictures and light (`art/sprites/station/yard/`) with every lamp's
## pool worked out ahead of time. What happens here is the part that moves, and
## every piece of it names the function on the page it ports.
##
## LAYERS, BACK TO FRONT, as the page drew its frame:
##
##   the hall      the painted hall, lit per pixel (`yard_light.gdshader`)
##   the wall      what lives in the wall: the city's tenants and lift cars
##   the back      what stands on the floor behind the ships, each with its
##                 shadow and its reflection, in depth order
##   the ships     their stands' shadows, their reflections, the stands, and
##                 the two hulls (`ShipView`s, lit as the page lit a hull)
##   the front     what stands on the floor in front of the ships
##   the TV's foot its shadow and reflection
##   over          what the light does not reach in the frame: the welder's
##                 arc, dust in the cones, the ships' names, sparks, flyers,
##                 the deal TV, the drones and their screens
##
## ON A 30 HZ CLOCK, like the labs and the page, which drew at 30.
##
## 766 x 482, the deck's size at 1x: the page was drawn at it, and every number
## in `yard.json` is in its pixels.

signal service(i: int)
signal take()

const W := 766
const H := 482
const DIR := YardLight.DIR
const DOC := DIR + "yard.json"
const HZ := 30.0
## The hull's own tint as the page blitted it.
const HULL_TINT := Color(1.02, 1.02, 1.04)
## The names over the ships, as Jon passed them ("needs more contrast for
## lighter text"): yours amber, the one for sale ice, and what each is under it.
const NAME_MINE := Color("#ffb444")
const NAME_SALE := Color("#dce9f7")
const NAME_SUB := Color("#d6dee9")
const NAME_OUT := Color("#05070b")

## The clock held at this many seconds after the TV powered on, for
## `stationshot yardclock=`: a yard caught at a known moment. Below zero it runs.
static var pin_clock := -1.0
## The drawn picture only, unlit, for the harness to set against Jon's halls.
static var fullbright := false
## The hall and the ships only, lit, for the harness to set against the page's.
static var bare := false

static var _doc: Dictionary = {}
static var _doc_read := false


## yard.json, read once.
static func doc() -> Dictionary:
	if not _doc_read:
		_doc_read = true
		if FileAccess.file_exists(DOC):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DOC))
			if parsed is Dictionary:
				_doc = parsed
	return _doc


## How built-up this station is, from `MapGen.Development`: which hall.
var dev: int = MapGen.Development.CITY
var manufacturer: StringName = &""
var level := ""
var light: YardLight = null
## The level's installed entry, and the page's dials.
var lv: Dictionary = {}
var dial: Dictionary = {}

var _mats: Dictionary = {}
var _hall_rect: TextureRect
var _wall: Control
var _back: Control
var _shipl: Control
var _ships: Control
var _front: Control
var _foot: Control
var _over: Control
var _p_wall: YardPaint
var _p_back: YardPaint
var _p_ship: YardPaint
var _p_front: YardPaint
var _p_foot: YardPaint
var _p_over: YardPaint

var _clock := 0.0
var _tick_n := -1
## When the TV powered on, on this clock.
var _tp := 0.0
var _powered := false
## How long ago a yard already on this docking powered on: the TV's reveal and
## the drones' arrival long over.
const SETTLED := 60.0
## This tick's time, and the time since the last tick.
var _t := 0.0
var _dt := 0.0
var _quiet := "sim" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless"
## The harness asked for a tick now, on its held clock.
var _force := false
var _times: Array[int] = []
## For the harness: time each tick (`yardtime` on the command line).
var _timing := OS.get_cmdline_user_args().has("yardtime")

# --- the ships
var _mine: ShipView = null
var _sale: ShipView = null
var _mine_name := ""
var _sale_name := ""
## Where each ship stands: [mine, sale], each {x0, top, w, h, bottom, ink,
## supports: [{tex, img, x, y}]} in the hall's pixels, or {} for none.
var placed: Array = [{}, {}]
var _ship_img: Image = null
var _ship_tex: ImageTexture = null
var _bay_vp: SubViewport = null
var _bay_ready := false
## Each hull's top row per column, for the drones' work on it.
var hull_top := PackedInt32Array()
var hull_bot := PackedInt32Array()

var _font: Font
## The yard's working parts: the drones, the deal TV, and everyone on the floor.
var drones: YardDrones = null
var deal_tv: YardDeal = null
var life: YardLife = null
var sound: YardSound = null
## The first tick, when the yard's rare events start their clocks.
var _t0 := -1.0
var _next_ev := 0.0
var _last_ev := ""
var _next_fly := 0.0
var _next_small := 0.0
## The welder's arc on what is round it, and the copy of the screen it reads.
var _weld_copy: BackBufferCopy
var _weld_fx: ColorRect
var _weld_mat: ShaderMaterial
var _tex_cache: Dictionary = {}
var _img_cache: Dictionary = {}
## For the harness: events to fire at seconds after power-on, [[key, s], ...].
static var fire_at: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size = Vector2(W, H)
	_font = UITheme.pixel_font()


## Build the level this yard is at. Called once `dev` is set.
func setup() -> void:
	level = ShopScene.level_name(dev)
	var d := doc()
	dial = d.get("dial", {})
	lv = ((d.get("levels", {}) as Dictionary).get(level, {}) as Dictionary)
	light = YardLight.new()
	if lv.is_empty() or not light.load_level(level, lv, float(dial.get("dark", 10))):
		push_warning("yard: no %s hall installed -- run tools/yard_install.py" % level)
		return
	_mats = {
		YardPaint.HALL: light.material(0),
		YardPaint.FLOOR: light.material(1),
		YardPaint.SHIP: light.material(2),
		YardPaint.MIRROR: light.material(3),
	}
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_mats[YardPaint.ADD] = add
	light.set_fullbright(fullbright)
	_hall_rect = TextureRect.new()
	_hall_rect.texture = light.hall
	_hall_rect.stretch_mode = TextureRect.STRETCH_KEEP
	_hall_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hall_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hall_rect.material = _mats[YardPaint.HALL]
	_hall_rect.size = Vector2(W, H)
	add_child(_hall_rect)
	_wall = _layer("Wall")
	_back = _layer("Back")
	_shipl = _layer("ShipBack")
	_ships = _layer("Ships")
	_front = _layer("Front")
	_foot = _layer("Foot")
	_over = _layer("Over")
	_p_wall = YardPaint.new(_wall.get_canvas_item(), _mats)
	_p_back = YardPaint.new(_back.get_canvas_item(), _mats)
	_p_ship = YardPaint.new(_shipl.get_canvas_item(), _mats)
	_p_front = YardPaint.new(_front.get_canvas_item(), _mats)
	_p_foot = YardPaint.new(_foot.get_canvas_item(), _mats)
	_p_over = YardPaint.new(_over.get_canvas_item(), _mats)
	# the welder's arc lays the frame back brighter round the torch: it reads the
	# screen, so it goes after the floor and before what the light does not reach
	_weld_copy = BackBufferCopy.new()
	_weld_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_weld_copy.visible = false
	add_child(_weld_copy)
	move_child(_weld_copy, _over.get_index())
	_weld_fx = ColorRect.new()
	_weld_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weld_fx.size = Vector2(33, 33)
	_weld_mat = ShaderMaterial.new()
	_weld_mat.shader = preload("res://shaders/yard_weld.gdshader")
	_weld_fx.material = _weld_mat
	_weld_fx.visible = false
	add_child(_weld_fx)
	move_child(_weld_fx, _over.get_index())
	_ship_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_ship_tex = ImageTexture.create_from_image(_ship_img)
	light.set_ship_map(_ship_tex)
	drones = YardDrones.new(self)
	deal_tv = YardDeal.new(self)
	life = YardLife.new(self)
	if not _quiet:
		sound = YardSound.new()
		sound.scene = self
		add_child(sound)
	_show(false)


func _layer(n: String) -> Control:
	var c := Control.new()
	c.name = n
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(W, H)
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(c)
	return c


## Nothing is shown until the floor lamps are baked: a floor with no lamps on it
## for a frame reads as the power failing.
func _show(on: bool) -> void:
	for c in get_children():
		if c is CanvasItem and c != _weld_fx and c != _weld_copy:
			(c as CanvasItem).visible = on


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for p: YardPaint in [_p_wall, _p_back, _p_ship, _p_front, _p_foot, _p_over]:
			if p != null:
				p.release()
		if life != null:
			life.release()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_pointer(Vector2(-100, -100))


# ------------------------------------------------------------------ the ships

## Stand the two ships: yours in the left berth, the one for sale (or nobody) in
## the right, each on a pair of the level's stands (the page's `buildFloor`).
## The views are this scene's from here on; the caller keeps its references.
func set_ships(mine: ShipView, mine_name: String, sale: ShipView, sale_name: String) -> void:
	for v: ShipView in [_mine, _sale]:
		if v != null and is_instance_valid(v) and v != mine and v != sale:
			v.queue_free()
	_mine = mine
	_sale = sale
	_mine_name = mine_name
	_sale_name = sale_name
	if light == null or lv.is_empty():
		return
	var berths: Array = doc().get("berths", [190, 585])
	var views: Array = [mine, sale]
	for i in 2:
		var v: ShipView = views[i]
		placed[i] = {}
		if v == null:
			continue
		if v.get_parent() != _ships:
			if v.get_parent() != null:
				v.get_parent().remove_child(v)
			_ships.add_child(v)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.material = _mats[YardPaint.SHIP]
		v.self_modulate = HULL_TINT
		_parent_material(v)
		placed[i] = _stand(v, float(berths[i]))
		if not placed[i].is_empty():
			placed[i]["view"] = v
	if life != null:
		life.has_welder = sale != null
	if bare:
		for i in 2:
			var Q: Dictionary = placed[i]
			if not Q.is_empty():
				var sup := []
				for s2: Dictionary in Q["supports"]:
					sup.append([s2["x"], s2["y"], (s2["img"] as Image).get_size()])
				print("  yard ship %d: x0 %d top %d w %d h %d ink %s canvas %s supports %s" % [i, Q["x0"], Q["top"], Q["w"], Q["h"], Q["ink"], (Q["img"] as Image).get_size(), sup])
	_bake_ships()
	for i in 2:
		_capture_fitted(i)


## THE MODULES ARE IN THE REFLECTION. A fitted part is not in the hull's
## picture -- `MountPoints` draws it over the hull -- so the floor gave back a
## bare hull under a ship with guns on it, and the floor lamps threw its shadow
## without them. Jon: "Do modules show up in the reflections?" They did not.
## So a copy of the ship, mounts and all, is photographed off screen once each
## time the ships are stood, and that picture is what the floor reflects and
## what the lamps' shadows are cut from. Two frames, then read back.
const FIT_PAD := 24
var _fit_vp: Array = [null, null]


func _capture_fitted(i: int) -> void:
	var S: Dictionary = placed[i]
	if S.is_empty() or _quiet:
		return
	var v: ShipView = S["view"]
	var fitted: MountPoints = null
	for c in v.get_children():
		if c is MountPoints:
			fitted = c
	if fitted == null or v._fixed == null:
		return
	var canvas: Image = S["img"]
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.size = Vector2i(canvas.get_width() + 2 * FIT_PAD, canvas.get_height() + 2 * FIT_PAD)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var copy := ShipView.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.self_clip = false
	copy.setup_build(v._fixed)
	vp.add_child(copy)
	copy.position = Vector2(FIT_PAD, FIT_PAD)
	copy.size = Vector2(canvas.get_width(), canvas.get_height())
	var mounts := MountPoints.new()
	mounts.ship = fitted.ship
	mounts.fitted = fitted.fitted
	copy.add_child(mounts)
	mounts.attach(copy)
	mounts.passive()
	mounts.refresh()
	add_child(vp)
	_fit_vp[i] = vp
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vp) or _fit_vp[i] != vp:
		return
	_fit_vp[i] = null
	var got := vp.get_texture().get_image()
	vp.queue_free()
	if placed[i].get("view") != v or got == null:
		return
	if got.get_format() != Image.FORMAT_RGBA8:
		got.convert(Image.FORMAT_RGBA8)
	var ink := _ink(got)
	if ink.size.x <= 0:
		return
	placed[i]["fitted"] = got
	placed[i]["fitted_ink"] = ink
	placed[i]["fitted_tex"] = ImageTexture.create_from_image(got)
	_bake_ships()


## Where a ship's picture sits in the yard: its canvas's corner, or the
## photograph's (FIT_PAD up and to the left of it) once there is one.
func _fitted_origin(P: Dictionary) -> Vector2i:
	var ink: Rect2i = P["ink"]
	var corner := Vector2i(int(P["x0"]) - ink.position.x, int(P["top"]) - ink.position.y)
	if P.has("fitted"):
		corner -= Vector2i(FIT_PAD, FIT_PAD)
	return corner


## Everything a view draws takes its light: the mounts on it too.
func _parent_material(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasItem:
			(c as CanvasItem).use_parent_material = true
		_parent_material(c)


## One ship on its stands (the page's `buildFloor`, stands in pairs): each stand
## under a flat stretch near a quarter and three quarters of the hull, its
## column made to reach the hull there, and the hull let down into their saddles.
func _stand(v: ShipView, cx: float) -> Dictionary:
	var img := v.canvas()
	if img == null:
		return {}
	if img.get_format() != Image.FORMAT_RGBA8:
		img = img.duplicate() as Image
		img.convert(Image.FORMAT_RGBA8)
	var ink := _ink(img)
	if ink.size.x <= 0:
		return {}
	var iw := ink.size.x
	var ih := ink.size.y
	var x0 := int(floorf(cx - float(iw) / 2.0 + 0.5))
	var under := PackedInt32Array()
	under.resize(iw)
	var inked: Array[int] = []
	for x in iw:
		under[x] = -1
		for y in range(ih - 1, -1, -1):
			if img.get_pixel(ink.position.x + x, ink.position.y + y).a8 >= 128:
				under[x] = y
				break
		if under[x] >= 0:
			inked.append(under[x])
	inked.sort()
	var belly: int = inked[inked.size() / 2] if not inked.is_empty() else ih - 1
	var floor_y := int(dial.get("ships", 310))
	var st: Dictionary = ((doc().get("art", {}) as Dictionary).get("stands", {}) as Dictionary).get(level, {})
	var si := _stand_image(st)
	var supports: Array = []
	var top := floor_y - ih
	if si != null:
		# THE STANDS ARE PICKED AS A PAIR. Each still wants a flat stretch near a
		# quarter of the hull (the page's rule), but the page picked them one at
		# a time, and a part bolted under one quarter -- a fin, a pod, a gun --
		# let one column down onto it and left the other reaching up to the
		# belly. Jon: "Why are the stands two different heights." So the two are
		# chosen together, over a wider stretch, and a pair that meets the hull
		# at the same row wins over a flatter pair that does not -- but never
		# closer than 40% of the hull apart, and each moves off its quarter only
		# when that buys a real match (a row of height is worth 25 px of travel).
		var hw := int(floorf(float(si.get_width()) * 0.4 + 0.5))
		var spots: Array = [[], []]
		for k in 2:
			var f: float = [0.26, 0.74][k]
			for px in range(int(floorf(float(iw) * (f - 0.16) + 0.5)), int(floorf(float(iw) * (f + 0.16) + 0.5)) + 1):
				var lo := 1000000000
				var hi := -1
				var ok := true
				for x in range(px - hw, px + hw + 1):
					if x < 0 or x >= iw or under[x] < 0:
						ok = false
						break
					lo = mini(lo, under[x])
					hi = maxi(hi, under[x])
				if ok:
					spots[k].append({"px": px, "c": hi, "score": float(hi - lo) + 0.12 * absf(float(px) - float(iw) * f)})
		var picks: Array = []
		var best := 1e9
		for A: Dictionary in spots[0]:
			for B: Dictionary in spots[1]:
				if float(B["px"]) - float(A["px"]) < float(iw) * 0.4:
					continue
				var sc := float(A["score"]) + float(B["score"]) + 3.0 * absf(float(A["c"]) - float(B["c"]))
				if sc < best:
					best = sc
					picks = [A, B]
		if picks.is_empty():
			for k2 in 2:
				var f2: float = [0.26, 0.74][k2]
				var one: Dictionary = {"px": int(floorf(float(iw) * f2 + 0.5)), "c": belly}
				for C: Dictionary in spots[k2]:
					if float(C["score"]) < float(one.get("score", 1e9)):
						one = C
				picks.append(one)
		var cmax := maxi(int(picks[0]["c"]), int(picks[1]["c"]))
		var cmin := mini(int(picks[0]["c"]), int(picks[1]["c"]))
		var base := int(dial.get("columns", 60))
		top = floor_y - base - cmax - 1 + int(st.get("seat", 0))
		# BOTH THE SAME HEIGHT, ALWAYS. Where no level pair exists -- a fin hangs
		# under one quarter of a light and nowhere is flat -- both stands reach
		# the higher meeting point, and the one by the lower part stands up
		# behind it to the belly: its saddle hidden, never short of the hull.
		for p: Dictionary in picks:
			var J := _sized(si, st, base + cmax - cmin)
			supports.append({"img": J, "tex": ImageTexture.create_from_image(J),
				"x": x0 + int(p["px"]) - int(floorf(float(J.get_width()) / 2.0 + 0.5)), "y": floor_y - J.get_height()})
	v.position = Vector2(x0 - ink.position.x, top - ink.position.y)
	v.size = Vector2(img.get_width(), img.get_height())
	return {"x": cx, "x0": x0, "top": top, "w": iw, "h": ih, "bottom": top + belly + 1, "ink": ink,
		"img": img, "supports": supports, "floor": floor_y, "under": under}


## The opaque box of a picture, by the page's measure (alpha from 128).
static func _ink(img: Image) -> Rect2i:
	var x0 := img.get_width()
	var y0 := img.get_height()
	var x1 := -1
	var y1 := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a8 >= 128:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i()
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


var _stand_cache: Dictionary = {}


func _stand_image(st: Dictionary) -> Image:
	var name := String(st.get("picture", ""))
	if name == "":
		return null
	if not _stand_cache.has(name):
		var t := load(DIR + name) as Texture2D
		var img: Image = t.get_image() if t != null else null
		if img != null and img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		_stand_cache[name] = img
	return _stand_cache[name]


## A stand made `h` tall: a repeated row to grow it, or rows taken out of its
## middle where the rows either side of the cut match best to shorten it (the
## page's `sized`, `stretch` and `shorten`).
func _sized(si: Image, st: Dictionary, h: int) -> Image:
	var w := si.get_width()
	var sh := si.get_height()
	if h >= sh:
		var row := int(st.get("row", int(floorf(float(sh) * 0.6))))
		var extra := h - sh
		var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			var sy := y if y <= row else (row if y <= row + extra else y - extra)
			out.blit_rect(si, Rect2i(0, sy, w, 1), Vector2i(0, y))
		return out
	var n := sh - h
	var cut: Array = st.get("cut", [0, sh])
	if level == "outpost" and int(dial.get("columns", 60)) < 53 and st.has("cut_low"):
		cut = st["cut_low"]
	var lo := int(cut[0])
	var hi := int(cut[1])
	var data := si.get_data()
	var best_a := -1
	var best_t := 0
	var a := maxi(1, lo)
	while a + n <= mini(sh - 1, hi):
		var t := 0
		var r1 := (a - 1) * w * 4
		var r2 := (a + n) * w * 4
		for i in w * 4:
			t += absi(int(data[r1 + i]) - int(data[r2 + i]))
		if best_a < 0 or t < best_t:
			best_a = a
			best_t = t
		a += 1
	if best_a < 0:
		best_a = maxi(1, int(floorf(float(lo + hi - n) / 2.0 + 0.5)))
	var out2 := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out2.blit_rect(si, Rect2i(0, 0, w, best_a), Vector2i.ZERO)
	out2.blit_rect(si, Rect2i(0, best_a + n, w, sh - best_a - n), Vector2i(0, best_a))
	return out2


## The ships' masks and their bellies (`ship_map`), and the floor lamps baked
## round them. The page's `bakeShips`: hulls and stands in the depth buffer, the
## floor lamps' pools with the ships' shadows in them, and a hull darker toward
## its belly in three steps.
func _bake_ships() -> void:
	_ship_img.fill(Color(0, 0, 0, 0))
	for P: Dictionary in placed:
		if P.is_empty():
			continue
		for s: Dictionary in P["supports"]:
			var J: Image = s["img"]
			for y in J.get_height():
				for x in J.get_width():
					if J.get_pixel(x, y).a8 >= 128:
						var X := int(s["x"]) + x
						var Y := int(s["y"]) + y
						if X >= 0 and X < W and Y >= 0 and Y < H:
							_ship_img.set_pixel(X, Y, Color8(0, 255, 0, 255))
	for P: Dictionary in placed:
		if P.is_empty():
			continue
		# the ship as photographed with its modules on, once that is in
		var img: Image = P.get("fitted", P["img"])
		var ink: Rect2i = P.get("fitted_ink", P["ink"])
		var at := _fitted_origin(P)
		for y in ink.size.y:
			for x in ink.size.x:
				if img.get_pixel(ink.position.x + x, ink.position.y + y).a8 >= 128:
					var X2 := at.x + ink.position.x + x
					var Y2 := at.y + ink.position.y + y
					if X2 >= 0 and X2 < W and Y2 >= 0 and Y2 < H:
						_ship_img.set_pixel(X2, Y2, Color8(255, 0, 0, 255))
	# a hull lit from above: toward its belly it falls into its own shade
	hull_top.resize(W)
	hull_bot.resize(W)
	for x in W:
		var top := -1
		var bot := -1
		for y in H:
			if _ship_img.get_pixel(x, y).r8 == 255:
				if top < 0:
					top = y
				bot = y
		hull_top[x] = top
		hull_bot[x] = bot
		if top < 0 or bot - top < 6:
			continue
		for y in range(top, bot + 1):
			var c := _ship_img.get_pixel(x, y)
			if c.r8 != 255:
				continue
			var u := float(y - top) / float(bot - top)
			var k := floorf(clampf((u - 0.5) / 0.5, 0.0, 1.0) * 3.0 + 0.5) / 3.0
			c.b8 = clampi(int(floorf((1.0 - 0.45 * k) * 255.0 + 0.5)), 1, 255)
			_ship_img.set_pixel(x, y, c)
	_ship_tex.update(_ship_img)
	_bake_bay()


## The floor lamps' pools, baked on the GPU into the half grid the page used,
## then read back for what asks the light off the GPU.
func _bake_bay() -> void:
	_bay_ready = false
	if _quiet:
		light.set_bay(null)
		_bay_ready = true
		_show(true)
		return
	if _bay_vp != null and is_instance_valid(_bay_vp):
		_bay_vp.queue_free()
	var cam: Dictionary = doc().get("cam", {})
	var vx := float(cam.get("vx", 383))
	var hy := float(cam.get("hy", 30))
	var f := float(cam.get("f", 500))
	var ch := float(cam.get("ch", 300))
	var zs := ch * f / maxf(0.5, float(dial.get("ships", 310)) - hy)
	var zsf := f / zs
	var u0 := 1e9
	var u1 := -1e9
	var h0 := 1e9
	var h1 := -1e9
	var any := false
	for y in H:
		for x in W:
			if _ship_img.get_pixel(x, y).r8 == 255:
				any = true
				var u := (float(x) - vx) / zsf
				var h := ch - (float(y) - hy) / zsf
				u0 = minf(u0, u)
				u1 = maxf(u1, u)
				h0 = minf(h0, h)
				h1 = maxf(h1, h)
	var vp := SubViewport.new()
	vp.size = Vector2i(384, 242)
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var r := ColorRect.new()
	r.size = Vector2(384, 242)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/yard_bay.gdshader")
	var fx: Array = lv.get("floorX", [])
	var fl := PackedFloat32Array()
	fl.resize(12)
	for i in mini(12, fx.size()):
		fl[i] = float(fx[i])
	var rows: Array = lv.get("floor", [])
	var rv := PackedVector2Array()
	rv.resize(4)
	for i in mini(4, rows.size()):
		rv[i] = Vector2(float(rows[i][0]), float(rows[i][1]))
	m.set_shader_parameter(&"mask", _ship_tex)
	m.set_shader_parameter(&"floorx", fl)
	m.set_shader_parameter(&"nfloor", mini(12, fx.size()))
	m.set_shader_parameter(&"rows", rv)
	m.set_shader_parameter(&"nrows", mini(4, rows.size()))
	m.set_shader_parameter(&"vx", vx)
	m.set_shader_parameter(&"hy", hy)
	m.set_shader_parameter(&"f", f)
	m.set_shader_parameter(&"ch", ch)
	m.set_shader_parameter(&"wallrow", float(doc().get("wallrow", 207)))
	m.set_shader_parameter(&"bayr", float((doc().get("bay", {}) as Dictionary).get("r", 115)))
	m.set_shader_parameter(&"lamph", float((doc().get("bay", {}) as Dictionary).get("lamph", 330)))
	m.set_shader_parameter(&"zs", zs)
	m.set_shader_parameter(&"zsf", zsf)
	m.set_shader_parameter(&"bounds", Vector4(u0, u1, h0, h1))
	m.set_shader_parameter(&"ships", any)
	m.set_shader_parameter(&"scale", YardLight.BSCALE)
	r.material = m
	vp.add_child(r)
	add_child(vp)
	_bay_vp = vp
	_read_bay(vp)


func _read_bay(vp: SubViewport) -> void:
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vp) or vp != _bay_vp:
		return
	var img := vp.get_texture().get_image()
	light.set_bay(img)
	vp.queue_free()
	_bay_vp = null
	_bay_ready = true
	_show(true)


# ------------------------------------------------------------------ the clock

## For the harness: hold the clock at `s` seconds after power-on and draw that
## tick now.
func step_to(s: float) -> void:
	pin_clock = s
	_force = true


## Power the TV on: the first time the deck is shown at a station. The drones
## fly in after it. `settled` comes back to a yard already on this docking
## (`Router.powered`): the TV long on, the drones at their screens, nothing of
## the power-on heard again.
func power_on(settled: bool = false) -> void:
	if _powered or light == null or lv.is_empty():
		return
	_powered = true
	_tp = floorf(_clock * HZ) / HZ - (SETTLED if settled else 0.0)
	_tick_n = -1
	var rv: Array = (deal_tv.T.get("reveal", [2.7, 3.3]) as Array)
	drones.bring(_tp, float(rv[1]), settled)
	if sound != null:
		sound.power_on(_tp, settled)


func _process(delta: float) -> void:
	if light == null or lv.is_empty() or not is_visible_in_tree():
		return
	_clock += delta
	var fr := int(floorf(_clock * HZ))
	if fr == _tick_n and not _force:
		return
	_force = false
	var t := float(fr) / HZ
	if pin_clock >= 0.0:
		t = _tp + pin_clock
		if _tick_n < 0:
			print("  yard: held at %.4f s (%.2f after power-on)" % [t, pin_clock])
	_dt = clampf(t - _t, 0.0, 0.1) if _tick_n >= 0 else 0.0
	_tick_n = fr
	_t = t
	if _timing:
		var u0 := Time.get_ticks_usec()
		_tick(t)
		_times.append(Time.get_ticks_usec() - u0)
		if _times.size() == 90:
			var slow := _times.find(_times.max())
			_times.sort()
			print("  yard tick: median %.2f ms, 90th %.2f ms, max %.2f ms (tick %d) over 90 ticks, the game at %d fps" % [_times[45] / 1000.0, _times[81] / 1000.0, _times[89] / 1000.0, slow, Engine.get_frames_per_second()])
			_times.clear()
		return
	_tick(t)


## One frame of the yard (the page's `paint`): who is where and what is lit,
## then every layer drawn afresh, then this tick's light to the shader.
func _tick(t: float) -> void:
	light.set_origin(get_global_transform().origin)
	_events(t)
	light.weigh(t)
	if sound != null:
		sound.tick(t, t - _tp)
	life.tick(t, _dt)
	light.dyn.clear()
	var tb := t - _tp
	if bare:
		light.feed()
		_draw_ships()
		_p_over.begin()
		_p_over.use(YardPaint.PLAIN)
		_names(_p_over)
		_p_over.end()
		return
	deal_tv.light_up(t, tb)
	life.light_up(t)
	light.feed()
	_p_wall.begin()
	life.draw_wall(_p_wall, t, _dt)
	_p_wall.end()
	_p_back.begin()
	_p_front.begin()
	life.draw_floor(_p_back, _p_front)
	_p_back.end()
	_p_front.end()
	_draw_ships()
	_p_foot.begin()
	deal_tv.draw_ground(_p_foot)
	_p_foot.end()
	_draw_weld(t)
	var P := _p_over
	P.begin()
	life.draw_dust(P, t, _dt)
	P.use(YardPaint.PLAIN)
	_names(P)
	life.draw_air(P, t, _dt)
	deal_tv.draw(P, t, tb)
	drones.draw(P, t)
	life.draw_glyphs(P)
	drones.draw_marks(P, t, _dt)
	P.end()


## The yard's rare events, one at a time every minute or so, and the flyers and
## small drones on their own clocks (the page's `life`); unclaimed's bad bulb
## pops now and then. Nothing starts on a held clock.
func _events(t: float) -> void:
	if _t0 < 0.0:
		_t0 = t
		_next_ev = t + 35.0 + randf() * 25.0
		_next_fly = t + 6.0 + randf() * 8.0
		_next_small = t + 3.0 + randf() * 5.0
		light.pop_next = t + 7.0 if light.pop_k >= 0 else 1e9
	for e: Array in fire_at:
		if e.size() < 3 and t - _tp >= float(e[1]):
			e.append(true)
			fire(String(e[0]), t)
	if pin_clock >= 0.0:
		return
	if t >= _next_fly:
		life.send_flyer(t)
		_next_fly = t + 18.0 + randf() * 22.0
	if t >= _next_ev:
		var keys: Array = EVENTS.filter(func(k: String) -> bool: return k != _last_ev)
		for n in 8:
			var k: String = keys[randi() % keys.size()]
			if fire(k, t):
				_last_ev = k
				break
		_next_ev = t + 45.0 + randf() * 45.0
	if t >= _next_small:
		life.send_small(t)
		_next_small = t + 8.0 + randf() * 9.0
	if light.pop_k >= 0 and t >= light.pop_next:
		life.pop_bulb(t)


## The rare events Jon kept (the page's E1-E6, E10-E15, E17-E20; E7, E8, E9, E16
## and E21 were cut).
const EVENTS := ["E1", "E2", "E3", "E4", "E5", "E6", "E10", "E11", "E12", "E13", "E14", "E15", "E17", "E18", "E19", "E20"]


## Start one now; false when nothing is free for it.
func fire(k: String, t: float) -> bool:
	match k:
		"E1": return drones.doze(t)
		"E2": return life.forgot(t)
		"E3": return life.late(t)
		"E4": return light.flicker(t)
		"E5": return drones.bump(t)
		"E6": return drones.joke(t)
		"E10": return life.send_bot(t)
		"E11": return life.send_cat(t)
		"E12": return life.cat_ride(t)
		"E13": return life.paper_plane(t)
		"E14": return life.hatch_peek(t)
		"E15": return life.shuffle(t)
		"E17": return life.balloon(t)
		"E18": return drones.sneeze(t)
		"E19": return life.crash(t)
		"E20": return life.cat_chase(t)
		"D1": return life.send_flyer(t)
		"D2": return life.send_small(t)
		"POP":
			life.pop_bulb(t)
			return true
	return false


## The welder's arc on the frame round the torch (the page's `weldLight`).
func _draw_weld(t: float) -> void:
	var on: bool = life.weld_now["on"]
	_weld_copy.visible = on
	_weld_fx.visible = on
	if not on:
		return
	var ax := float(life.weld_now["x"])
	var ay := float(life.weld_now["y"])
	_weld_fx.position = Vector2(ax - 16.0, ay - 16.0)
	_weld_mat.set_shader_parameter(&"origin", get_global_transform().origin)
	_weld_mat.set_shader_parameter(&"arc", Vector2(ax, ay))
	_weld_mat.set_shader_parameter(&"fl", 0.55 + 0.45 * YardLight.hash1(floorf(t * 22.0) * 1.37))


## The ships' stands and reflections, under the hulls (the page's baked frame):
## each stand's shadow, each hull's reflection, the stands.
func _draw_ships() -> void:
	var P := _p_ship
	P.begin()
	P.use(YardPaint.PLAIN)
	# EVERY STAND THE SAME SHADOW. Jon: "all of the stands should have the same
	# shadow. so it doesn't look like they're floating." Each stand also stood
	# in the floor lamps and threw its own shadow there, different at every
	# spot, so no two matched; the lamps now pass the stands by (only a hull
	# throws a lamp shadow, `yard_bay.gdshader`). Every stand gets the shadow
	# Jon passed under the unclaimed yard's stands ("that shadow checks out"),
	# one picture measured off that render: the contact at the foot's sides and
	# the lamps' shadow in front, deepest two rows down and gone before the
	# hazard stripe four rows down -- "why is there a shadow on the hazard lines
	# in front of the stand?" A dark band hard under the foot read as floating
	# four times before, as did the stands' reflections (they have none now).
	var sh: Dictionary = (doc().get("art", {}) as Dictionary).get("stand_shadow", {})
	var shadow := tex(String(sh.get("picture", "")))
	for S: Dictionary in placed:
		if S.is_empty() or shadow == null:
			continue
		for s: Dictionary in S["supports"]:
			P.tex(shadow, Vector2(float(s["x"]) + float(sh.get("x", 0)), float(S["floor"]) + float(sh.get("y", 0))))
	P.use(YardPaint.MIRROR)
	var tint := Color(0.8, 0.8, 0.82)
	for i in 2:
		var S: Dictionary = placed[i]
		if S.is_empty():
			continue
		var v: ShipView = _mine if i == 0 else _sale
		var fl := float(S["floor"])
		# the photograph with the modules on, once there is one
		var t: Texture2D = S.get("fitted_tex", v.texture)
		var ink: Rect2i = S.get("fitted_ink", S["ink"])
		var at := _fitted_origin(S)
		var x := float(at.x + ink.position.x)
		var bottom := float(at.y + ink.position.y + ink.size.y - 1)
		P.mirror(t, Rect2(ink.position, ink.size), x, 2.0 * fl - bottom, 0.22 * 0.7, tint, false)

	P.use(YardPaint.SHIP)
	for S: Dictionary in placed:
		if S.is_empty():
			continue
		for s: Dictionary in S["supports"]:
			P.tex(s["tex"], Vector2(float(s["x"]), float(s["y"])))
	P.end()


## The ships' names, over each hull: Silkscreen with a dark outline and a drop
## under it. The page drew them at 24 and 16 pixels; in the game, where the
## whole yard is shown at twice its size, Jon: "The text for the ships are too
## big." So 16 and 8, the next sizes down that keep the font on whole pixels,
## the name's baseline 11 rows over the hull and YOURS / FOR SALE 2 rows over.
## Your ship's name over it off, while the cutaway has it zoomed in: at 2x the
## sign stood over the parts lifted off the hull.
var hide_mine_name := false


func _names(P: YardPaint) -> void:
	for i in 2:
		var S: Dictionary = placed[i]
		if S.is_empty() or (i == 0 and hide_mine_name):
			continue
		var x := floorf(float(S["x0"]) + 3.0 + 0.5)
		var y := floorf(float(S["top"]) + 0.5)
		var nm := _mine_name if i == 0 else _sale_name
		_outlined(P, nm, Vector2(x, y - 11.0), 16, NAME_MINE if i == 0 else NAME_SALE)
		_outlined(P, "YOURS" if i == 0 else "FOR SALE", Vector2(x, y - 2.0), 8, NAME_SUB)


const _OUTLINE := [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0),
	Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1), Vector2(2, 2), Vector2(1, 2), Vector2(2, 1)]


func _outlined(P: YardPaint, s: String, at: Vector2, size: int, c: Color) -> void:
	for d: Vector2 in _OUTLINE:
		P.text(_font, at + d, s, size, NAME_OUT)
	P.text(_font, at, s, size, c)


# ------------------------------------------------------------------ the services and the deal

var offers: Array = []
var deal: Dictionary = {}


## What each drone sells now: [{label, cost, ok, done, tip}] for PATCH, REPAIR,
## REFUEL and FAULTS; `done` is why it has nothing to do ("" while it has).
func set_offers(o: Array) -> void:
	offers = o
	if drones != null:
		drones.offers_changed(_t)


## A service is about to go through (before the money moves).
func serving(i: int) -> void:
	if drones != null:
		drones.serving(i)


## A service went through: the drone that sold it does the work.
func served(i: int, text: String) -> void:
	if drones != null:
		drones.served(i, text, _t)


## The TV's deal: {ask, trade, price, ok}, or {} with nothing on the blocks.
func set_deal(d: Dictionary) -> void:
	deal = d


# ------------------------------------------------------------------ shadows

var _shade_cache: Dictionary = {}


## A contact shadow on the floor (the page's `shade` / `_shadow` / `shadeZ`): an
## ellipse darkened in three dithered steps, as a picture of black laid over it.
func shade(P: YardPaint, cx: float, cy: float, rx: float, ry: float, k: float) -> void:
	var y0 := int(maxf(0.0, floorf(cy - ry)))
	var y1 := int(minf(float(H - 1), floorf(cy + ry)))
	var x0 := int(maxf(0.0, floorf(cx - rx)))
	var x1 := int(minf(float(W - 1), floorf(cx + rx)))
	if x1 < x0 or y1 < y0:
		return
	var key := "%s|%s|%s|%s|%s|%d|%d|%d|%d|%d" % [cx - floorf(cx), cy - floorf(cy), rx, ry, k, x0 - int(floorf(cx)), y0 - int(floorf(cy)), (x0 + y0) & 1, x1 - x0, y1 - y0]
	var t: ImageTexture = _shade_cache.get(key)
	if t == null:
		var img := Image.create(x1 - x0 + 1, y1 - y0 + 1, false, Image.FORMAT_RGBA8)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var dd := pow((float(x) - cx) / rx, 2.0) + pow((float(y) - cy) / ry, 2.0)
				if dd > 1.0:
					continue
				var q := 1.0 - k * (1.0 if dd < 0.55 else (0.6 if dd < 0.8 else 0.3)) * (1.0 if ((x + y) % 2 == 0 or dd < 0.55) else 0.7)
				img.set_pixel(x - x0, y - y0, Color(0, 0, 0, 1.0 - q))
		t = ImageTexture.create_from_image(img)
		_shade_cache[key] = t
	P.tex(t, Vector2(x0, y0))


# ------------------------------------------------------------------ the pointer

func _gui_input(e: InputEvent) -> void:
	var mm := e as InputEventMouseMotion
	if mm != null:
		_pointer(mm.position)
		return
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_click(mb.position)


## What the pointer is on: a drone that will sell lights its glass; TAKE IT
## lights once the deal is on the glass.
func _pointer(p: Vector2) -> void:
	if drones == null:
		return
	var i := drones.hit(p)
	drones.hover = i
	deal_tv.hover_take = i < 0 and deal_tv.on_take(p) and deal_tv.reveal >= 1.0 and bool(deal.get("ok", false))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if (i >= 0 or deal_tv.hover_take) else Control.CURSOR_ARROW


func _click(p: Vector2) -> void:
	if drones == null:
		return
	var i := drones.hit(p)
	if i >= 0:
		# a click wakes a dozing drone with a jolt, whether or not it can sell
		drones.wake(i, _t)
		var o: Dictionary = offers[i] if i < offers.size() else {}
		if bool(o.get("ok", false)) and String(o.get("done", "")) == "":
			service.emit(i)
		accept_event()
		return
	if deal_tv.on_take(p) and deal_tv.reveal >= 1.0 and bool(deal.get("ok", false)):
		accept_event()
		take.emit()


func _get_tooltip(at: Vector2) -> String:
	if drones == null:
		return ""
	var i := drones.hit(at)
	if i >= 0 and i < offers.size():
		return Widgets.tip(String((offers[i] as Dictionary).get("tip", "")))
	return ""


# ------------------------------------------------------------------ helpers

func now() -> float:
	return _t


func font() -> Font:
	return _font


## The row the drones take their light from: just under the hulls' feet.
func shiprow() -> int:
	return mini(H - 1, int(dial.get("ships", 310)) + 10)


## The top of your hull at a column: where a drone's work lands.
func top_at(x: float) -> float:
	var c := clampi(int(floorf(x + 0.5)), 0, W - 1)
	if hull_top.size() == W and hull_top[c] >= 0:
		return float(hull_top[c])
	var m: Dictionary = placed[0]
	return float(m.get("top", 200))


## Is a pixel under a ship or a stand?
func covered(x: int, y: int) -> bool:
	if _ship_img == null:
		return false
	var c := _ship_img.get_pixel(x, y)
	return c.r8 > 0 or c.g8 > 0


## An installed picture of the yard's, loaded once.
func tex(name: String) -> Texture2D:
	if name == "":
		return null
	if not _tex_cache.has(name):
		_tex_cache[name] = load(DIR + name) as Texture2D
	return _tex_cache[name]


## One of the station's own pictures (the flyers).
func tex_abs(name: String) -> Texture2D:
	if name == "":
		return null
	var key := "abs:" + name
	if not _tex_cache.has(key):
		_tex_cache[key] = load("res://art/sprites/station/" + name) as Texture2D
	return _tex_cache[key]


## An installed picture's pixels, for what reads them.
func img(name: String) -> Image:
	if name == "":
		return null
	if not _img_cache.has(name):
		var t := tex(name)
		var im: Image = t.get_image() if t != null else null
		if im != null and im.get_format() != Image.FORMAT_RGBA8:
			im.convert(Image.FORMAT_RGBA8)
		_img_cache[name] = im
	return _img_cache[name]


static func cell(x: float, y: float) -> Vector2:
	return Vector2(YardLight.cell_x(x), YardLight.cell_y(y))


## The light on a picture as the page cached its lit copies: in 48ths, then
## to the byte its multiply used.
static func quant(M: Color) -> Color:
	return Color(floorf(floorf(clampf(M.r, 0.0, 1.0) * 48.0 + 0.5) / 48.0 * 255.0 + 0.5) / 255.0,
		floorf(floorf(clampf(M.g, 0.0, 1.0) * 48.0 + 0.5) / 48.0 * 255.0 + 0.5) / 255.0,
		floorf(floorf(clampf(M.b, 0.0, 1.0) * 48.0 + 0.5) / 48.0 * 255.0 + 0.5) / 255.0)


## A colour in the light (the page's `mHex`).
static func lit(c: Color, M: Color) -> Color:
	return Color8(int(floorf(float(c.r8) * M.r + 0.5)), int(floorf(float(c.g8) * M.g + 0.5)), int(floorf(float(c.b8) * M.b + 0.5)), c.a8)


static func _grey(f: float) -> float:
	return floorf(255.0 * clampf(f, 0.0, 1.0) + 0.5) / 255.0


## A picture in the light, lit from above: toward its bottom it falls into its
## own shade in steps, and whatever hangs over it shades its top (the page's
## `litCopy` with a `shade`).
func draw_shaded(P: YardPaint, t: Texture2D, src: Rect2, at: Vector2, M: Color, from: float, k: float, steps: int, cast: Array) -> void:
	if t == null:
		return
	P.use(YardPaint.PLAIN)
	var sw := int(src.size.x)
	var sh := int(src.size.y)
	var y0 := int(floorf(float(sh) * from + 0.5))
	var bands: Array = [[0, y0, 1.0]]
	for j in range(1, steps + 1):
		var ya := y0 + int(floorf(float(sh - y0) * float(j - 1) / float(steps) + 0.5))
		var yb := y0 + int(floorf(float(sh - y0) * float(j) / float(steps) + 0.5))
		bands.append([ya, yb, _grey(1.0 - k * float(j) / float(steps))])
	# the cast along the top, softer at its ends and in a band under it
	var cuts: Array = []
	if not cast.is_empty():
		var cx := float(cast[0])
		var cw := int(cast[1])
		var chh := int(cast[2])
		var ck := float(cast[3])
		var x0 := int(floorf(cx - float(cw) / 2.0 + 0.5))
		cuts = [[0, chh, [[x0 - 4, x0, _grey(1.0 - ck / 2.0)], [x0, x0 + cw, _grey(1.0 - ck)], [x0 + cw, x0 + cw + 4, _grey(1.0 - ck / 2.0)]]],
			[chh, chh + 2, [[x0, x0 + cw, _grey(1.0 - ck / 2.0)]]]]
	for b: Array in bands:
		var ya2 := int(b[0])
		var yb2 := mini(int(b[1]), sh)
		if yb2 <= ya2:
			continue
		# split the band's rows where the cast rows begin and end
		var edges: Array[int] = [ya2, yb2]
		for c: Array in cuts:
			for e: int in [int(c[0]), int(c[1])]:
				if e > ya2 and e < yb2:
					edges.append(e)
		edges.sort()
		for n in edges.size() - 1:
			var ra := edges[n]
			var rb := edges[n + 1]
			if rb <= ra:
				continue
			var cols: Array = [[0, sw, 1.0]]
			for c2: Array in cuts:
				if ra >= int(c2[0]) and ra < int(c2[1]):
					cols = _split(sw, c2[2])
			for cc: Array in cols:
				var xa := maxi(0, int(cc[0]))
				var xb := mini(sw, int(cc[1]))
				if xb <= xa:
					continue
				var f := float(b[2]) * float(cc[2])
				P.tex(t, at + Vector2(xa, ra), Rect2(src.position.x + float(xa), src.position.y + float(ra), float(xb - xa), float(rb - ra)),
					Color(M.r * f, M.g * f, M.b * f))


## A row split into runs by the cast's columns: [[x0, x1, factor], ...].
static func _split(w: int, cols: Array) -> Array:
	var out: Array = []
	var x := 0
	for c: Array in cols:
		var a := clampi(int(c[0]), 0, w)
		var b := clampi(int(c[1]), 0, w)
		if a > x:
			out.append([x, a, 1.0])
		if b > a:
			out.append([a, b, float(c[2])])
		x = maxi(x, b)
	if x < w:
		out.append([x, w, 1.0])
	return out


# ------------------------------------------------------------------ sound

func sound_arrive(x: float) -> void:
	if sound != null:
		sound.arrive(x)


func sound_leave(x: float) -> void:
	if sound != null:
		sound.leave(x)


func sound_work(i: int, x: float) -> void:
	if sound != null:
		sound.work(i, x)


func flick_sound(key: String, strong: bool = false) -> void:
	if sound != null:
		sound.flick(key, strong)
