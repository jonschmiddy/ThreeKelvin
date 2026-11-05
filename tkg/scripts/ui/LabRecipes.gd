class_name LabRecipes
extends Control

## THE LAB'S RECIPES PAGE, in AUGMENT's layout (Jon, Nov 5: "Can't we make the
## recipes page like the augment page in its layout? Just slightly different
## probably."). The rows of words with a MAKE key on each are gone. Now:
##   left    what you hold that the Lab takes (survey film, relics), on a rail
##           with their pictures, as AUGMENT's FITTED / IN THE HOLD;
##   middle  the one in hand, drawn large on its grid, under the Lab's scanner
##           (the line that sweeps down it is what makes this page not AUGMENT);
##   right   the recipes it can go into, as rings like the affix offers: film
##           to DEVELOP FILM, a relic to READ FOR DATA or RELIC ANALYSIS, each
##           with what it makes and what it uses;
##   bottom  the recipe picked, named, with what it does, its bill and MAKE.
## With nothing held, the rail shows each thing as a faded outline with where
## it comes from, and every recipe greyed with what it needs.
##
## PORTED FROM THE MOCK (tk-wt/recipes-mock RecipeMock.gd, idea B; stills in
## tk-scratch/science/review_lab/recipes/B/): its rail, bench, rings and strip
## are drawn where and how it drew them. The recipes are DB.RECIPES, read
## through `Fabricator`, so a recipe added there shows up here with no code.
##
## BUILT ONCE. MAKE is made with the page and only restyled on a refresh, so a
## click survives the `resources_changed` its own press sends.

## Something that glows changed: whoever blooms it (`LabZoom`) redraws.
signal lit_changed

const W := 960
const H := 540
const T := 26
const GLASS := Rect2i(26, 26, 908, 488)
const BG := LabBoard.BG
const OWN := LabBoard.OWN
const OWN_D := LabBoard.OWN_D
const NEXT := LabBoard.NEXT
const NEXT_D := LabBoard.NEXT_D
const HOT := LabBoard.HOT
const LATER_T := LabBoard.LATER_T
const LATER_I := LabBoard.LATER_I
const LATER_R := LabBoard.LATER_R
const BAD := LabBoard.BAD
const ICE := LabBoard.ICE
const CHILL := LabBoard.CHILL
const NR := LabBoard.NR

## The rail: its pips' x, the first row's middle, and a row's pitch.
const RAIL_X := 44
const ROW0 := 112
const ROW := 72
## The bench: its left edge and the line its picture's middle sits on.
const SX := 396
const MID := 262
## The recipe rings' column, and where their words start.
const NODE_X := 700
const WORDS_X := 736

## The rail's order; anything else a recipe takes goes after, as it comes.
const ORDER := [&"survey_film", &"relic"]
## The rings' order (the old rows' order): DATA first, then the part.
const RECIPE_ORDER := [&"develop", &"read", &"analysis"]
## THE PICTURES ARE DRAWN HERE, IN CODE, as shaded images the size of a part's
## sprite, and go through AUGMENT's own two hands: its phosphor on the rail,
## its schematic (outline, a line at each step of shading, four tones) on the
## bench. One drawing in both places; the film's leader, pulled out of its slot
## on the bench, is its only change. The relic is a broken slab of precursor
## circuitry, not an Earth thing: three faces, a crack, traces that run off its
## broken edges, and a ringed core.
static var _imgs := {}
static var _texs := {}
## Each thing in words: all of it, its unit (one, many), what it is on the bench, what a
## recipe needs of it, what a recipe uses, where it comes from (short, long),
## and its line on the rail's key.
const WORDS := {
	&"survey_film": {all = "SURVEY FILM", one = "ROLL", many = "ROLLS", kind = "UNDEVELOPED", need = "A ROLL OF FILM",
		uses = "1 ROLL", the = "1 ROLL", from = "FROM SOME EVENTS",
		from_long = "SOME EVENTS PAY YOU IN SURVEY FILM.", key = "FILM COMES FROM SOME EVENTS."},
	&"relic": {all = "RELICS", one = "RELIC", many = "RELICS", kind = "PRECURSOR FRAGMENT", need = "A RELIC",
		uses = "THE RELIC", the = "THE RELIC", from = "FROM WRECKS, DANGER 7+",
		from_long = "RELICS COME FROM WRECKS AT DANGER 7 AND UP.", key = "RELICS COME FROM WRECKS."},
}

var tint := Color(190.0 / 255.0, 240.0 / 255.0, 235.0 / 255.0)
## The light pass (see LabBoard): only what glows.
var light := false
## Every box drawn, for the box test: [name, Rect2i].
var leaves: Array = []
## Every text's box, and the key's, for the test that no line crosses one.
var tboxes: Array = []
var phase := 0.0

## The thing in hand (a material id; &"" with nothing held), and which of its
## recipes is picked (an index into its offers).
var hand: StringName = &""
var choice := 0
## What the last press made: {id, line}; empty when nothing was.
var done: Dictionary = {}
## Makes a recipe and returns its log line ("" when it did not happen). Set by
## `LabZoom` (the station's `_fabricate`); the page alone uses `Fabricator`.
var maker: Callable

var commit_button: LabPlate
## The bill under the key, as drawn ("1 RELIC + 30 CREDITS"): what a test reads.
var bill_words := ""

## Read off the run on each refresh: [{id, n, name, offers, cy}].
var _items: Array = []
## The rings on the right now: [{r, at, st}].
var _rings: Array = []
var _pic := Rect2i()
var _lines := PackedByteArray()
var _live: Control
var _clock := 0.0
var _frame := -1
## THE SCANNER'S OWN CLOCK (s into its sweep) and the row it is on: it steps
## one pixel at a time down the drawing over `SCAN_S`, then rests at the
## bottom for `SCAN_REST_S`. On the page's 0.09 s loop it jumped 5 to 6 px.
var _scan := 0.0
var _scan_row := -1
const SCAN_S := 3.0
const SCAN_REST_S := 0.5


func _init() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_live = Control.new()
	_live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_live.size = Vector2(W, H)
	_live.draw.connect(func() -> void:
		paint_live(_live)
		lit_changed.emit())
	add_child(_live)
	commit_button = LabPlate.new("MAKE", &"commit")
	commit_button.visible = false
	commit_button.size = Vector2(150, 19)
	commit_button.position = Vector2(W - T - 14 - 150, 461)
	commit_button.pressed.connect(_commit)
	add_child(commit_button)


# ------------------------------------------------------------------ the state

## A fresh visit: nothing in hand yet, nothing just made.
func reset() -> void:
	hand = &""
	choice = 0
	done = {}


## Read the run again and put the key where it goes. Never builds a node.
func refresh() -> void:
	_items.clear()
	var n: MapGen.MapNode = Run.node_at()
	var recipes: Array[Dictionary] = Fabricator.available(n) if n != null else ([] as Array[Dictionary])
	recipes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ia := RECIPE_ORDER.find(StringName(a.id))
		var ib := RECIPE_ORDER.find(StringName(b.id))
		return (ia if ia >= 0 else 99) < (ib if ib >= 0 else 99))
	var ids: Array[StringName] = []
	for id: StringName in ORDER:
		ids.append(id)
	for r in recipes:
		for m: StringName in (r.mats as Dictionary).keys():
			if not ids.has(m):
				ids.append(m)
	var cy := ROW0
	for id2 in ids:
		var offers: Array[Dictionary] = []
		for r2 in recipes:
			if (r2.mats as Dictionary).has(id2):
				offers.append(r2)
		if offers.is_empty():
			continue
		var nm := str(MaterialTable.by_id(id2).get("name", id2)).to_upper()
		_items.append({id = id2, n = Run.material(id2), name = nm, offers = offers, cy = cy})
		cy += ROW
	# THE HAND: kept while its thing is on the rail (at none, just made, the
	# strip still says what came of it); else the first thing held
	if hand == &"" or _item(hand).is_empty():
		hand = &""
		choice = 0
		for it: Dictionary in _items:
			if int(it.n) > 0:
				hand = it.id
				break
		if hand != &"":
			choice = _first_makeable()
	var offs := _offers()
	if choice >= offs.size():
		choice = 0
	_relayout()


func _item(id: StringName) -> Dictionary:
	for it: Dictionary in _items:
		if it.id == id:
			return it
	return {}


## The recipes the thing in hand goes into.
func _offers() -> Array:
	var it := _item(hand)
	return it.offers if not it.is_empty() else []


func _first_makeable() -> int:
	var n: MapGen.MapNode = Run.node_at()
	var offs := _offers()
	for i in offs.size():
		if n != null and Fabricator.can_make(n, offs[i]):
			return i
	return 0


## Whether nothing the Lab takes is aboard.
func empty() -> bool:
	for it: Dictionary in _items:
		if int(it.n) > 0:
			return false
	return true


## The rings on the right and their states: the thing in hand's recipes, or,
## with nothing held, every recipe greyed.
func _relayout() -> void:
	_rings.clear()
	var n: MapGen.MapNode = Run.node_at()
	var list: Array = []
	if hand == &"":
		for it: Dictionary in _items:
			for r: Dictionary in it.offers:
				if not list.has(r):
					list.append(r)
	else:
		list = _offers()
	var ys := _node_ys(list.size())
	var held := int(_item(hand).get("n", 0))
	for i in list.size():
		var r: Dictionary = list[i]
		var can := n != null and Fabricator.can_make(n, r)
		var st := &"later"
		if hand != &"" and held > 0:
			if i == choice:
				st = &"next" if can else &"short"
			else:
				st = &"plain" if can else &"short"
		_rings.append({r = r, at = Vector2i(NODE_X, ys[i]), st = st})
	_restyle()


func _node_ys(k: int) -> Array:
	match k:
		0:
			return []
		1:
			return [MID]
		2:
			return [160, 340]
		3:
			return [130, 250, 370]
	var out: Array = []
	for i in k:
		out.append(110 + roundi(270.0 * i / float(k - 1)))
	return out


## The recipe picked, or an empty dictionary.
func picked() -> Dictionary:
	if hand == &"" or choice < 0 or choice >= _rings.size():
		return {}
	return _rings[choice].r


## What a press would cost and whether it can be made: {credits, ok}.
func bill() -> Dictionary:
	var n: MapGen.MapNode = Run.node_at()
	var r := picked()
	if n == null or r.is_empty():
		return {credits = 0, ok = false}
	return {credits = Fabricator.price(n, r), ok = Fabricator.can_make(n, r)}


func _commit() -> void:
	var r := picked()
	if r.is_empty():
		return
	var line := ""
	if maker.is_valid():
		line = str(maker.call(r))
	else:
		line = Fabricator.make(Run.node_at(), r)
		if not line.is_empty():
			Audio.play(&"fabricate", 0.04)
	if line.is_empty():
		Audio.denied()
		refresh()
		return
	done = {id = StringName(r.id), line = line}
	refresh()


## Put a thing on the rail in hand (a click on its row).
func pick_item(id: StringName) -> void:
	if _item(id).is_empty() or empty():
		return
	hand = id
	done = {}
	choice = _first_makeable()
	_relayout()


## Put recipe `i` on the right in hand (a click on its ring).
func pick_recipe(i: int) -> void:
	if hand == &"" or i < 0 or i >= _rings.size():
		return
	choice = i
	done = {}
	_relayout()


# ------------------------------------------------------------------ input

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	_scan = fmod(_scan + delta, SCAN_S + SCAN_REST_S)
	var row := _scan_y()
	var f := int(floorf(_clock / LabBoard.FRAME_S)) % LabBoard.FRAMES
	if f != _frame or row != _scan_row:
		_frame = f
		_scan_row = row
		phase = float(f) / float(LabBoard.FRAMES)
		_live.queue_redraw()


## The scanner's line, in page px (its picture's top, down to its bottom).
func _scan_y() -> int:
	if not _pic.has_area():
		return -1
	var t := clampf(_scan / SCAN_S, 0.0, 1.0)
	return _pic.position.y + mini(_pic.size.y, int(floorf(t * float(_pic.size.y + 1))))


func hold_phase(p: float) -> void:
	set_process(false)
	phase = p
	_scan = p * (SCAN_S + SCAN_REST_S)
	_live.queue_redraw()


func _gui_input(e: InputEvent) -> void:
	var mm := e as InputEventMouseMotion
	if mm != null:
		var on := node_at(mm.position) >= 0 or row_at(mm.position) >= 0
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW
		return
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var nd := node_at(mb.position)
		if nd >= 0:
			pick_recipe(nd)
			Audio.click()
			accept_event()
			return
		var rw := row_at(mb.position)
		if rw >= 0:
			pick_item(_items[rw].id)
			Audio.click()
			accept_event()


## The recipe ring under `p` (page px), or -1. None with nothing in hand: the
## greyed rings only say what each needs.
func node_at(p: Vector2) -> int:
	if hand == &"":
		return -1
	for i in _rings.size():
		if p.distance_to(Vector2(_rings[i].at)) <= NR + 4:
			return i
	return -1


## The rail row under `p`, or -1: its picture, its words, the room between.
func row_at(p: Vector2) -> int:
	# (with nothing aboard the rows are outlines that say where each thing
	# comes from: nothing to pick, so nothing that looks pressable)
	if empty():
		return -1
	for i in _items.size():
		var cy: int = _items[i].cy
		if Rect2(RAIL_X - 4, cy - 30, 300, 60).has_point(p):
			return i
	return -1


# ------------------------------------------------------------------ restyle

func _restyle() -> void:
	# (none of it aboard, as after the last one is made: the bar says what
	# came of it, and a key that cannot be pressed is not drawn)
	var show := hand != &"" and not picked().is_empty() and Run.material(hand) > 0
	commit_button.visible = show
	if show:
		commit_button.disabled = not bool(bill().ok)
		commit_button.queue_redraw()
	queue_redraw()
	_live.queue_redraw()
	lit_changed.emit()


# ------------------------------------------------------------------ drawing kit

func _px(ci: CanvasItem, x: int, y: int, c: Color, lit: bool = false) -> void:
	if light and not lit:
		return
	ci.draw_rect(Rect2(x, y, 1, 1), c)


func _rect(ci: CanvasItem, r: Rect2i, c: Color, lit: bool = false) -> void:
	if light and not lit:
		return
	ci.draw_rect(Rect2(r), c)


func _ring(ci: CanvasItem, cx: int, cy: int, r: int, c: Color, lit: bool = false, dash: int = 0, off: float = 0.0) -> void:
	if light and not lit:
		return
	for p in LabBoard.ring_pts(r):
		if dash > 0:
			var ang := atan2(p.y, p.x) / TAU + off
			if int(ang * dash * 2) % 2 != 0:
				continue
		ci.draw_rect(Rect2(cx + int(p.x), cy + int(p.y), 1, 1), c)


func _disc(ci: CanvasItem, cx: int, cy: int, r: int, c: Color) -> void:
	if light:
		return
	var lim := (r - 0.5) * (r - 0.5) + 0.25
	for dy in range(-r, r + 1):
		var half := -1
		for dx in range(0, r + 1):
			if dx * dx + dy * dy < lim:
				half = dx
		if half >= 0:
			ci.draw_rect(Rect2(cx - half, cy + dy, half * 2 + 1, 1), c)


func _dither_ring(ci: CanvasItem, cx: int, cy: int, r0: int, r1: int, c: Color, a0: float) -> void:
	for dy in range(-r1, r1 + 1):
		for dx in range(-r1, r1 + 1):
			var d := sqrt(float(dx * dx + dy * dy))
			if d >= r0 and d <= r1:
				var t := 1.0 - (d - r0) / maxf(1.0, float(r1 - r0))
				if t * a0 > LabBoard.bayer(cx + dx, cy + dy):
					ci.draw_rect(Rect2(cx + dx, cy + dy, 1, 1), c)


func _icon(ci: CanvasItem, name: String, cx: int, cy: int, c: Color, lit: bool = true) -> void:
	if light and not lit:
		return
	var rows: Array = LabIcons.ICONS.get(name, LabIcons.ICONS.get("LIGHTENED"))
	var n := rows.size()
	var c2 := LabBoard.mixc(c, BG, 0.5)
	for j in n:
		var row: String = rows[j]
		for i in row.length():
			var ch := row[i]
			if ch == "#":
				ci.draw_rect(Rect2(cx - n / 2 + i, cy - n / 2 + j, 1, 1), c)
			elif ch == "+":
				ci.draw_rect(Rect2(cx - n / 2 + i, cy - n / 2 + j, 1, 1), c2)
			elif ch == "O":
				ci.draw_rect(Rect2(cx - n / 2 + i, cy - n / 2 + j, 1, 1), LabBoard.WHITE)


func _text(ci: CanvasItem, x: int, ycap: int, s: String, c: Color, sz: int = 8, lit: bool = false, name: String = "") -> int:
	var w := LabBoard.tw(s, sz)
	if light:
		if lit:
			LabBoard.text_at(ci, x, ycap, s, c, sz)
		return w
	LabBoard.text_at(ci, x, ycap, s, c, sz)
	var r := Rect2i(x, ycap - 1, w, (5 if sz == 8 else 10) + 2)
	leaves.append([name if name != "" else s, r])
	tboxes.append([name if name != "" else s, r])
	return w


## Words in several inks on one line, one box.
func _runs(ci: CanvasItem, x: int, ycap: int, parts: Array, name: String, lit: bool = false) -> int:
	var cx := x
	for p: Array in parts:
		var s: String = p[0]
		if not light or lit:
			LabBoard.text_at(ci, cx, ycap, s, p[1])
		cx += LabBoard.tw(s)
	if not light:
		var r := Rect2i(x, ycap - 1, cx - x, 7)
		leaves.append([name, r])
		tboxes.append([name, r])
	return cx - x


static func _runs_w(parts: Array) -> int:
	var w := 0
	for p: Array in parts:
		w += LabBoard.tw(p[0])
	return w


func _leaf(name: String, x: int, y: int, w: int, h: int) -> void:
	if not light:
		leaves.append([name, Rect2i(x, y, w, h)])


func _reticle(ci: CanvasItem, cx: int, cy: int, r: int, ry: int = -1) -> void:
	var r2 := ry if ry > 0 else r
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for k in 5:
				_px(ci, cx + sx * (r - k), cy + sy * r2, ICE, true)
				_px(ci, cx + sx * r, cy + sy * (r2 - k), ICE, true)


func _path(ci: CanvasItem, pts: Array, c: Color, lit: bool, style: StringName, record: bool = true) -> void:
	var n := 0
	for p: Vector2i in pts:
		n += 1
		if record and not light and p.x >= 0 and p.y >= 0 and p.x < W and p.y < H:
			_lines[p.y * W + p.x] = 1
		if style == &"dash" and (n / 4) % 2 == 1:
			continue
		if style == &"dot" and n % 3 != 0:
			continue
		_px(ci, p.x, p.y, c, lit)


func _hline(x0: int, x1: int, y: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(x0, x1 + 1):
		out.append(Vector2i(x, y))
	return out


func ground_ink(a: float) -> Color:
	return LabBoard.mixc(BG, tint, a)


static func word_ink(a: float) -> Color:
	return LabAugment.word_ink(a)


## The picture of `id` as a shaded image (its grey is the shading, its alpha
## its shape), with the film's leader out of its slot (`out`).
static func pic_image(id: StringName, out: bool = false) -> Image:
	var key := "%s|%s" % [id, out]
	if _imgs.has(key):
		return _imgs[key]
	var lum: Array
	if id == &"survey_film":
		lum = _film(out)
	elif id == &"relic":
		lum = _relic()
	else:
		lum = _crate()
	var h := lum.size()
	var w := (lum[0] as PackedFloat32Array).size()
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: PackedFloat32Array = lum[y]
		for x in w:
			if row[x] >= 0.0:
				var v := clampf(row[x], 0.0, 1.0)
				im.set_pixel(x, y, Color(v, v, v, 1.0))
	_imgs[key] = im
	return im


## On the rail: AUGMENT's phosphor of the picture, [as it looks, what glows].
static func rail_tex(id: StringName, hi: Color, lo: Color, lit: bool) -> Array:
	var key := "rail|%s|%s|%s|%s" % [id, hi.to_html(), lo.to_html(), lit]
	if not _texs.has(key):
		_texs[key] = LabAugment._phosphor(pic_image(id), hi, lo, lit)
	return _texs[key]


## On the bench: AUGMENT's schematic at `k`, [as it looks, what glows, the row
## its body is widest on].
static func bench_tex(id: StringName, k: int) -> Array:
	var key := "bench|%s|%d" % [id, k]
	if not _texs.has(key):
		_texs[key] = LabAugment._schematic(pic_image(id, id == &"survey_film"), k)
	return _texs[key]


static func _blank(w: int, h: int) -> Array:
	var out: Array = []
	for y in h:
		var row := PackedFloat32Array()
		row.resize(w)
		row.fill(-1.0)
		out.append(row)
	return out


static func _lum_at(l: Array, x: int, y: int) -> float:
	if y < 0 or y >= l.size() or x < 0 or x >= (l[y] as PackedFloat32Array).size():
		return -1.0
	return (l[y] as PackedFloat32Array)[x]


## Set one pixel's shade (`only_in`: only where the picture already is).
static func _put(l: Array, x: int, y: int, v: float, only_in: bool = false) -> void:
	if y < 0 or y >= l.size() or x < 0 or x >= (l[y] as PackedFloat32Array).size():
		return
	var row: PackedFloat32Array = l[y]
	if only_in and row[x] < 0.0:
		return
	row[x] = v
	l[y] = row


static func _line(l: Array, pts: Array, v: float) -> void:
	for i in pts.size() - 1:
		var a: Vector2i = pts[i]
		var b: Vector2i = pts[i + 1]
		var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
		for j in n + 1:
			var t := float(j) / float(maxi(1, n))
			_put(l, roundi(a.x + (b.x - a.x) * t), roundi(a.y + (b.y - a.y) * t), v, true)


static func _side(a: Vector2, b: Vector2, p: Vector2) -> float:
	return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)


## A relic: a slab broken off something bigger, 46 x 32.
static func _relic() -> Array:
	var w := 46
	var h := 32
	var l := _blank(w, h)
	var poly := PackedVector2Array([Vector2(0, 21), Vector2(9, 7), Vector2(20, 1), Vector2(33, 2), Vector2(45, 7),
		Vector2(40, 13), Vector2(45, 18), Vector2(37, 23), Vector2(31, 31), Vector2(23, 26), Vector2(15, 30), Vector2(8, 25)])
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.is_point_in_polygon(p, poly):
				continue
			# three faces off two ridges, lit from the top left
			var v := 0.40 if _side(Vector2(20, 1), Vector2(23, 26), p) < 0.0 else 0.30
			if _side(Vector2(0, 21), Vector2(45, 12), p) < 0.0:
				v += 0.12
			v += 0.10 * (1.0 - float(x + y) / float(w + h))
			_put(l, x, y, v)
	# the bevel: its top and left edges catch the light, the others fall away
	var bev := l.duplicate(true)
	for y2 in h:
		for x2 in w:
			var v2 := _lum_at(l, x2, y2)
			if v2 < 0.0:
				continue
			if _lum_at(l, x2, y2 - 1) < 0.0 or _lum_at(l, x2 - 1, y2) < 0.0:
				_put(bev, x2, y2, minf(1.0, v2 + 0.14))
			elif _lum_at(l, x2, y2 + 1) < 0.0 or _lum_at(l, x2 + 1, y2) < 0.0:
				_put(bev, x2, y2, v2 - 0.12)
	l = bev
	# its cracks
	_line(l, [Vector2i(41, 8), Vector2i(36, 12), Vector2i(37, 16), Vector2i(33, 18)], 0.08)
	_line(l, [Vector2i(20, 26), Vector2i(21, 29)], 0.08)
	# circuit traces off the core, cut off where the slab broke, a groove under each
	var traces := [
		[Vector2i(17, 15), Vector2i(9, 15), Vector2i(9, 11), Vector2i(4, 11)],
		[Vector2i(17, 15), Vector2i(17, 6), Vector2i(26, 6), Vector2i(26, 1)],
		[Vector2i(17, 15), Vector2i(29, 15), Vector2i(29, 10), Vector2i(40, 10), Vector2i(40, 13)],
		[Vector2i(17, 15), Vector2i(17, 22), Vector2i(24, 22), Vector2i(24, 26)],
		[Vector2i(29, 15), Vector2i(29, 20), Vector2i(38, 20)],
		[Vector2i(9, 15), Vector2i(9, 20), Vector2i(12, 20), Vector2i(12, 25)],
		[Vector2i(26, 6), Vector2i(33, 6)],
	]
	for t: Array in traces:
		var low: Array = []
		for q: Vector2i in t:
			low.append(q + Vector2i(1, 1))
		_line(l, low, 0.12)
	for t2: Array in traces:
		_line(l, t2, 0.92)
	for t3: Array in traces:
		var e: Vector2i = t3[-1]
		for dx in 2:
			for dy in 2:
				_put(l, e.x + dx - (1 if e.x > 17 else 0), e.y + dy - (1 if e.y > 15 else 0), 1.0, true)
	# the core: a ring round a bright eye
	for y3 in h:
		for x3 in w:
			var d := Vector2(x3 - 17, y3 - 15).length()
			if d > 2.6 and d < 4.0:
				_put(l, x3, y3, 0.98, true)
			elif d <= 1.2:
				_put(l, x3, y3, 1.0, true)
			elif d <= 2.6:
				_put(l, x3, y3, 0.18, true)
	return l


static func _cyl(x: int, x0: int, x1: int, lo: float, hi: float) -> float:
	var t := (x - x0 + 0.5) / float(x1 - x0 + 1)
	return lo + (hi - lo) * pow(maxf(0.0, 1.0 - absf(t - 0.3) / 0.7), 1.5)


## A can of survey film, 24 x 32, or 36 wide with its leader out (`out`).
static func _film(out: bool) -> Array:
	var w := 36 if out else 24
	var l := _blank(w, 32)
	# the spool's hub, the caps a little wider than the can, the can
	for y in 3:
		for x in range(9, 15):
			_put(l, x, y, _cyl(x, 9, 14, 0.35, 0.9))
	for y2: int in [3, 4, 5, 27, 28, 29]:
		for x2 in range(2, 22):
			_put(l, x2, y2, 0.2 if y2 == 5 or y2 == 27 else _cyl(x2, 2, 21, 0.3, 0.85))
	for y3 in range(6, 27):
		for x3 in range(4, 20):
			var band := y3 >= 11 and y3 < 19
			_put(l, x3, y3, _cyl(x3, 4, 19, 0.12, 0.35) if band else _cyl(x3, 4, 19, 0.25, 0.7))
	# the band's marks, and the slot the film comes out of
	for x4 in range(5, 19, 3):
		for y4 in range(13, 17):
			_put(l, x4, y4, 0.95)
	for y5 in range(12, 18):
		_put(l, 19, y5, 0.08)
	if out:
		for y6 in range(13, 18):
			for x6 in range(20, 35):
				if (y6 == 13 and x6 >= 33) or (y6 == 17 and x6 >= 32):
					continue
				_put(l, x6, y6, 0.55 if y6 == 13 or y6 == 17 else 0.45)
		for x7 in range(20, 33):
			_put(l, x7, 15, 0.62)
		for x8 in range(22, 33, 3):
			_put(l, x8, 14, 0.1)
			_put(l, x8, 16, 0.1)
	return l


## Anything else a recipe might take one day: a plain crate, 20 x 16.
static func _crate() -> Array:
	var l := _blank(20, 16)
	for y in range(1, 15):
		for x in range(1, 19):
			var edge := y == 1 or y == 14 or x == 1 or x == 18 or y == 7 or y == 8
			_put(l, x, y, 0.8 if edge else 0.4 - 0.1 * float(x) / 18.0)
	return l


static func _words(id: StringName) -> Dictionary:
	if WORDS.has(id):
		return WORDS[id]
	var nm := str(MaterialTable.by_id(id).get("name", id)).to_upper()
	return {all = nm, one = nm, many = nm, kind = "MATERIAL", need = "1 " + nm, uses = "1 " + nm, the = "1 " + nm,
		from = "", from_long = "", key = ""}


## "2 ROLLS", "1 RELIC", "NONE".
static func count_words(id: StringName, n: int) -> String:
	if n <= 0:
		return "NONE"
	var w := _words(id)
	return "%d %s" % [n, str(w.one) if n == 1 else str(w.many)]


static func _gets(r: Dictionary) -> String:
	if StringName(r.kind) == &"data":
		return "+%d DATA" % int(r.amount)
	if StringName(r.kind) == &"artifact":
		return "1 RANDOM PART"
	return str(r.name).to_upper()


static func _mat_of(r: Dictionary) -> StringName:
	var keys: Array = (r.mats as Dictionary).keys()
	return keys[0] if not keys.is_empty() else &""


# ------------------------------------------------------------------ the page

func _draw() -> void:
	leaves.clear()
	tboxes.clear()
	bill_words = ""
	_lines = PackedByteArray()
	_lines.resize(W * H)
	paint(self)


## The page's still parts onto `ci`: as it looks, or (`light`) what glows.
func paint(ci: CanvasItem) -> void:
	if _items.is_empty():
		_text(ci, SX, 118, "THE LAB HAS NO RECIPES HERE", ICE, 16)
		_caption(ci)
		return
	var idle_hi := LabBoard.mixc(CHILL, tint, 0.3)
	var idle_lo := Color("#2d3d4f")
	_text(ci, RAIL_X + 12, 70, "IN THE HOLD", word_ink(0.6))
	# ---- what you hold, on a rail down the left
	var picked_at := Vector2i(-1, -1)
	var last_cy := ROW0
	for it: Dictionary in _items:
		var id: StringName = it.id
		var n := int(it.n)
		var cy: int = it.cy
		last_cy = cy
		var on := id == hand
		var held := n > 0
		var hi := OWN if on and held else (idle_hi if held else (LabBoard.mixc(LATER_R, LATER_T, 0.5) if on else LATER_R))
		var lo := OWN_D if on and held else (idle_lo if held else BG)
		var lit := on and held
		var tex_pair := rail_tex(id, hi, lo, lit)
		var tex: Texture2D = tex_pair[1] if light else tex_pair[0]
		var tsz := Vector2i(tex.get_size())
		var px := RAIL_X + 52 - tsz.x / 2
		var py := cy - tsz.y / 2
		if id == &"survey_film" and n > 1:
			# (more than one roll: a second can behind the first)
			if not light:
				ci.draw_texture(tex_pair[0], Vector2(px - 7, py + 2), Color(1, 1, 1, 0.45))
			_leaf("pic " + str(it.name), px - 7, py, tsz.x + 7, tsz.y + 2)
		else:
			_leaf("pic " + str(it.name), px, py, tsz.x, tsz.y)
		if not light or lit:
			ci.draw_texture(tex, Vector2(px, py))
		var tx := RAIL_X + 98
		var w := _words(id)
		var l2 := ("%s  ·  SELLS FOR %d" % [count_words(id, n), _sells(id)]) if held else "NONE  ·  " + str(w.from)
		var nw := _text(ci, tx, cy - 7, str(it.name), ICE if on else (CHILL if held else LATER_T), 8, lit)
		var lw := _text(ci, tx, cy + 4, l2, word_ink(0.55) if held else LATER_T)
		_ring(ci, RAIL_X, cy, 2, hi, lit)
		_leaf("pip " + str(it.name), RAIL_X - 2, cy - 2, 5, 5)
		if on:
			_reticle(ci, RAIL_X + 52, cy, 42, 24)
			picked_at = Vector2i(tx + maxi(nw, lw) + 8, cy - 4)
	var pts: Array[Vector2i] = []
	for yy in range(ROW0 - 24, last_cy + 16):
		pts.append(Vector2i(RAIL_X, yy))
	_path(ci, pts, ground_ink(0.25), false, &"dot", false)
	# ---- the one in hand, on the bench under the scanner
	var it_h := _item(hand)
	var n_h := int(it_h.get("n", 0))
	var sch: Array = []
	var k := 5
	var sw := 150
	var sh := 90
	if hand != &"":
		var src := pic_image(hand, hand == &"survey_film")
		k = LabAugment.scale_for(src.get_width(), src.get_height())
		sch = bench_tex(hand, k)
		sw = src.get_width() * k
		sh = src.get_height() * k
	var sy := MID - sh / 2
	_pic = Rect2i(SX, sy, sw, sh)
	if hand == &"":
		_text(ci, SX, 118, "NOTHING ON THE BENCH", ICE, 16)
		_text(ci, SX, 134, "THE HOLD HAS NOTHING THE LAB TAKES.", CHILL)
		_text(ci, SX, 145, "HERE IS WHAT EACH RECIPE WOULD MAKE.", word_ink(0.6))
	else:
		var w2 := _words(hand)
		_text(ci, SX, 118, str(it_h.name), ICE, 16, n_h > 0)
		_text(ci, SX, 134, "%s  ·  %s ABOARD" % [w2.kind, count_words(hand, n_h)], CHILL if n_h > 0 else LATER_T)
		_text(ci, SX, 145, ("SELLS FOR %d AT THIS DOCK" % _sells(hand)) if n_h > 0 else str(w2.from_long), word_ink(0.6) if n_h > 0 else LATER_T)
	var bright := hand != &"" and n_h > 0
	var gcol := ground_ink(0.32 if bright else 0.2)
	var cell := 20
	if not light:
		for gy in range(sy, sy + sh + 1, cell):
			for i2 in range(0, sw + 1, 3):
				ci.draw_rect(Rect2(SX + i2, gy, 1, 1), gcol)
		for gx in range(SX, SX + sw + 1, cell):
			for j2 in range(0, sh + 1, 3):
				ci.draw_rect(Rect2(gx, sy + j2, 1, 1), gcol)
		for c: Vector2i in [Vector2i(SX, sy), Vector2i(SX + sw, sy), Vector2i(SX, sy + sh), Vector2i(SX + sw, sy + sh)]:
			for t in range(-3, 4):
				ci.draw_rect(Rect2(c.x + t, c.y, 1, 1), ground_ink(0.6 if bright else 0.35))
				ci.draw_rect(Rect2(c.x, c.y + t, 1, 1), ground_ink(0.6 if bright else 0.35))
	if not sch.is_empty():
		if bright:
			ci.draw_texture(sch[1] if light else sch[0], Vector2(SX, sy))
		elif not light:
			# (none of it left aboard: the drawing dimmed, nothing glows)
			ci.draw_texture(sch[0], Vector2(SX, sy), Color(1, 1, 1, 0.3))
	_leaf("schematic", SX - 4, sy - 4, sw + 9, sh + 9)
	# the centreline through its widest row, AUGMENT's, which the line in from
	# the rail meets
	var cl := MID if sch.is_empty() else sy + int(sch[2]) * k + k / 2
	if not light and not sch.is_empty():
		var n2 := 0
		for xx in range(SX - 12, SX + sw + 8):
			if (n2 % 9 < 5 or n2 % 9 == 6) and not (xx >= SX and xx < SX + sw):
				_px(ci, xx, cl, LabBoard.mixc(BG, OWN_D if bright else LATER_R, 0.9))
			n2 += 1
	if picked_at.x >= 0:
		_path(ci, LabAugment._curve(Vector2(picked_at), Vector2(SX - 13, cl)), OWN_D if bright else LATER_R, bright, &"dash")
	var hx := SX + sw + 18
	var mc := OWN if bright else LATER_R
	_ring(ci, hx, cl, 4, mc, bright)
	_px(ci, hx, cl, mc, bright)
	_leaf("mount", hx - 5, cl - 5, 11, 11)
	_path(ci, _hline(SX + sw + 9, SX + sw + 13, cl), mc, bright, &"solid" if bright else &"dot")
	# ---- the recipes it goes into, off its mount
	for i in _rings.size():
		var rg: Dictionary = _rings[i]
		var r2: Dictionary = rg.r
		var at: Vector2i = rg.at
		var st: StringName = rg.st
		var sel := st == &"next" or (st == &"short" and i == choice and bright)
		var lc := NEXT if st == &"next" else (LabBoard.mixc(BG, LATER_R, 0.8) if st == &"later" else LabBoard.mixc(BG, NEXT, 0.45))
		var style := &"solid" if st == &"next" else (&"dot" if st == &"later" else &"dash")
		_path(ci, LabAugment._curve(Vector2(hx + 6, cl), Vector2(at.x - NR - 6, at.y)), lc, st == &"next", style)
		_node_still(ci, at.x, at.y, str(r2.name).to_upper(), st)
		_leaf("recipe " + str(r2.name), at.x - NR - 5, at.y - NR - 5, 2 * NR + 11, 2 * NR + 11)
		_offer_words(ci, at.y, r2, st, sel)
	_caption(ci)


func _sells(id: StringName) -> int:
	return Market.material_price(Run.node_at(), id)


## The three lines beside a recipe's ring, AUGMENT's offer hand: its name,
## what it makes, and what it uses (or, with none held, what it needs).
func _offer_words(ci: CanvasItem, ny: int, r: Dictionary, st: StringName, sel: bool) -> void:
	var later := st == &"later"
	var n: MapGen.MapNode = Run.node_at()
	var price := Fabricator.price(n, r) if n != null else 0
	var nm := str(r.name).to_upper()
	var name_c := HOT if st == &"next" else (LATER_T if later else (LabBoard.mixc(HOT, BG, 0.3) if sel else ICE))
	_text(ci, WORDS_X, ny - 14, nm, name_c, 8, st == &"next")
	var gets := _gets(r)
	if StringName(r.kind) == &"data":
		var dc := LATER_T if later else OWN
		_runs(ci, WORDS_X, ny - 3, [[gets.substr(0, gets.length() - 4), dc], ["DATA", LATER_T if later else CHILL]], "gets " + nm, st == &"next")
	else:
		_text(ci, WORDS_X, ny - 3, gets, LATER_T if later else ICE)
	var mat := _mat_of(r)
	var w := _words(mat)
	if later:
		var need := "NEEDS " + str(w.need)
		if price > 0:
			need += " + %d CREDITS" % price
		_text(ci, WORDS_X, ny + 8, need, LATER_T)
	elif price > 0:
		var short := Run.credits < price
		_runs(ci, WORDS_X, ny + 8, [[str(w.the) + " + ", CHILL], ["%d " % price, BAD if short else ICE], ["CREDITS", CHILL]], "uses " + nm)
	else:
		var uses := str(w.uses)
		_text(ci, WORDS_X, ny + 8, "USES " + uses if not uses.begins_with("THE ") else "USES " + uses + " UP", CHILL)


func _node_still(ci: CanvasItem, x: int, y: int, name: String, st: StringName) -> void:
	match st:
		&"next":
			_disc(ci, x, y, NR, LabBoard.mixc(BG, NEXT, 0.2))
			_ring(ci, x, y, NR, NEXT, true)
			_icon(ci, name, x, y, HOT)
		&"short":
			_disc(ci, x, y, NR, LabBoard.mixc(BG, NEXT, 0.07))
			_ring(ci, x, y, NR, LabBoard.mixc(NEXT, BG, 0.6))
			_icon(ci, name, x, y, LabBoard.mixc(HOT, BG, 0.5), false)
		&"plain":
			_disc(ci, x, y, NR, LabBoard.mixc(BG, NEXT, 0.07))
			_ring(ci, x, y, NR, LabBoard.mixc(BG, NEXT, 0.75))
			_icon(ci, name, x, y, LabBoard.mixc(HOT, BG, 0.25), false)
		&"owned":
			_disc(ci, x, y, NR, LabBoard.mixc(BG, OWN, 0.2))
			_ring(ci, x, y, NR, OWN, true)
			_ring(ci, x, y, NR - 2, OWN_D)
			_icon(ci, name, x, y, OWN)
		_:
			_disc(ci, x, y, NR, BG)
			_ring(ci, x, y, NR, LATER_R, false, 16)
			_icon(ci, name, x, y, LATER_I, false)


## The strip under the page: the recipe in words, and the one key that spends.
func _caption(ci: CanvasItem) -> void:
	if not light:
		for x in range(GLASS.position.x + 10, GLASS.end.x - 10):
			ci.draw_rect(Rect2(x, 446, 1, 1), ground_ink(0.3))
	if hand == &"":
		_text(ci, 46, 457, "NOTHING TO MAKE", ICE, 16)
		var bits: PackedStringArray = []
		var from: PackedStringArray = []
		for it: Dictionary in _items:
			bits.append(str(_words(it.id).all))
			var fl := str(_words(it.id).from_long)
			if fl != "":
				from.append(fl)
		var gets: PackedStringArray = []
		for rg: Dictionary in _rings:
			var g := "DATA" if StringName(rg.r.kind) == &"data" else "PARTS"
			if not gets.has(g):
				gets.append(g)
		if not bits.is_empty():
			_text(ci, 46, 475, "THE LAB TURNS %s INTO %s." % [" AND ".join(bits), " OR ".join(gets)], ICE)
		if not from.is_empty():
			_text(ci, 46, 487, " ".join(from), CHILL)
		return
	var r := picked()
	if r.is_empty():
		return
	var b := bill()
	var payable := bool(b.ok)
	var nm := str(r.name).to_upper()
	var just := not done.is_empty() and StringName(done.id) == StringName(r.id)
	var st := &"owned" if just else (&"next" if payable else &"short")
	if st == &"next":
		_node_live(ci, 60, 480, &"next", 0.35)
	_node_still(ci, 60, 480, nm, st)
	_leaf("caption icon", 60 - NR - 4, 480 - NR - 4, 2 * NR + 9, 2 * NR + 9)
	var tx := 96
	_text(ci, tx, 457, nm, OWN if just else (HOT if payable else LabBoard.mixc(HOT, BG, 0.3)), 16, true)
	if just:
		_text(ci, tx, 475, str(done.line).to_upper(), OWN, 8, true)
	else:
		_text(ci, tx, 475, str(r.text).to_upper(), ICE)
	var mat := _mat_of(r)
	var n_h := Run.material(mat)
	var l2 := ""
	if n_h > 0:
		# (what is aboard and what it sells for are on the rail and the bench:
		# the strip says only what a press leaves)
		var used := int((r.mats as Dictionary).get(mat, 1))
		l2 = "AFTER THIS, %s LEFT ABOARD." % count_words(mat, n_h - used)
	else:
		l2 = "NONE LEFT ABOARD. " + str(_words(mat).from_long)
	_text(ci, tx, 487, l2, CHILL)
	if commit_button.visible:
		var kr := Rect2i(commit_button.position, commit_button.size)
		_leaf("[MAKE]", kr.position.x, kr.position.y, kr.size.x, kr.size.y)
		if not light:
			tboxes.append(["[MAKE]", kr])
		if light and not commit_button.disabled:
			LabBoard.text_at(ci, kr.position.x + floori((kr.size.x - LabBoard.tw(commit_button.label)) / 2.0),
				kr.position.y + floori((kr.size.y - 5) / 2.0), commit_button.label, HOT)
		var short_m := n_h < int((r.mats as Dictionary).get(mat, 1))
		var price := int(b.credits)
		var cost: Array = [["%d " % int((r.mats as Dictionary).get(mat, 1)), BAD if short_m else ICE],
			[str(_words(mat).one), CHILL]]
		if price > 0:
			cost.append([" + %d " % price, BAD if Run.credits < price else ICE])
			cost.append(["CREDITS", CHILL])
		var words := ""
		for p: Array in cost:
			words += String(p[0])
		if not light:
			bill_words = words
		_runs(ci, kr.position.x + (kr.size.x - _runs_w(cost)) / 2, 486, cost, "make cost")


func _node_live(ci: CanvasItem, x: int, y: int, st: StringName, p: float) -> void:
	match st:
		&"owned":
			var pr := NR + 2 + LabBoard.pyround(9.0 * p)
			_dither_ring(ci, x, y, pr, pr + 3, OWN_D if p > 0.5 else OWN, 1.0 - p)
		&"next":
			_dither_ring(ci, x, y, NR + 1, NR + 6, NEXT_D, 0.7 + 0.3 * sin(TAU * p))
			_ring(ci, x, y, NR + 4, LabBoard.mixc(BG, NEXT, 0.6), true, 12, p / 12.0)


## What moves round the page's loop: the halo of the recipe picked, a pulse on
## one just made, and THE SCANNER: a line that sweeps down the thing on the
## bench with a dithered wake above it (AUGMENT's bench has none; this is the
## page's own hand).
func paint_live(ci: CanvasItem) -> void:
	if _items.is_empty():
		return
	for i in _rings.size():
		var rg: Dictionary = _rings[i]
		_node_live(ci, rg.at.x, rg.at.y, rg.st, fposmod(phase + 0.29 * i, 1.0))
		if i == choice and hand != &"" and (rg.st == &"next" or rg.st == &"short"):
			_reticle(ci, rg.at.x, rg.at.y, NR + 8)
	if not done.is_empty() and not picked().is_empty() and StringName(done.id) == StringName(picked().id):
		_node_live(ci, 60, 480, &"owned", phase)
	if hand != &"" and Run.material(hand) > 0 and _pic.has_area():
		var y := _scan_y()
		for d in range(0, 7):
			var yy := y - d
			if yy < _pic.position.y:
				break
			var a := 1.0 - float(d) / 7.0
			for x in range(_pic.position.x - 3, _pic.end.x + 4):
				if d == 0:
					ci.draw_rect(Rect2(x, yy, 1, 1), LabBoard.mixc(BG, OWN, 0.85))
				elif a * 0.5 > LabBoard.bayer(x, yy):
					ci.draw_rect(Rect2(x, yy, 1, 1), LabBoard.mixc(BG, OWN, 0.45 * a))


# ------------------------------------------------------------------ the tests

## THE MOCKUP'S BOX TEST on what is drawn now, with the header's boxes: every
## leaf inside the glass, no two overlapping, no line across a word or a key.
## Empty when it passes.
func check(extra: Array = []) -> PackedStringArray:
	var bad := PackedStringArray()
	var all: Array = leaves.duplicate()
	all.append_array(extra)
	for l: Array in all:
		if not GLASS.encloses(l[1]):
			bad.append("'%s' %s is outside the glass" % [l[0], l[1]])
	for i in all.size():
		for j in range(i + 1, all.size()):
			if (all[i][1] as Rect2i).intersects(all[j][1]):
				bad.append("'%s' overlaps '%s'" % [all[i][0], all[j][0]])
	if _lines.size() == W * H:
		for t: Array in tboxes:
			var r: Rect2i = t[1]
			var hit := false
			for x in range(r.position.x - 1, r.end.x + 1):
				for y in range(r.position.y - 1, r.end.y + 1):
					if x >= 0 and y >= 0 and x < W and y < H and _lines[y * W + x] != 0:
						hit = true
			if hit:
				bad.append("a line crosses '%s'" % t[0])
	return bad
