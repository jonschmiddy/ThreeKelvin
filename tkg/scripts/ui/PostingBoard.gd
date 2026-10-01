class_name PostingBoard
extends Control

## The Hiring Hall: a bulletin board, and the whole deck is the board.
##
## IT WAS A BOARD IN A ROOM, and before that a board filling a panel with nothing
## on it but the work. Neither looked like the thing every station actually has,
## which is a bulletin board somebody has been pinning to for years: notices hung
## wherever there was room, a wanted poster, a clipping, a flyer with half its
## tabs torn off, and the holes of every pin that was ever pulled out. The WORK is
## what you came for; the rest is how the deck says people live here.
##
## EVERYTHING WITH WORDS ON IT HANGS SQUARE. The notices and the town's sheets
## were each turned a few degrees for one pass, and pixel text turned by even a
## degree breaks into stair-steps. The board is made of things to read, so the
## lived-in look comes from overlaps, shadows and pin holes instead.
##
## TWO KINDS OF PAPER, AND ONLY ONE OF THEM IS A BUTTON. The real contracts are the
## dark printed notices down the left -- `_offer_row` and `_deliver_row` build
## them as they always did, pinned in a straight column. Everything in the
## right-hand column is drawn here and is scenery: nothing in it can be signed, so
## none of it is printed the way the notices that can be are.
##
## AND THE MANUFACTURERS PIN THINGS UP TOO. Every manufacturer holding the station
## has a notice of its own on the board, in its own colours and in its own voice
## -- Korvan's misfire counter, Calyx asking you not to feed the hull. A board at a
## Korvan yard and a board at a Calyx one should not read the same, and a notice
## is the cheapest way there is to say who runs a place.
##
## Drawn rather than loaded, like the rest of the station's furniture.

## The notices pinned to this. Read every redraw, never cached -- the rows are
## rebuilt from scratch on every refresh of the deck.
var list: Control = null
## The layer the pins are drawn on, above the notices.
var _pins: Control = null
## The manufacturers whose own notices are pinned up here, in order. Set by the
## screen from who holds the station; see `StationScreen._board_posts`.
var posts: Array[StringName] = []

const CORK := Color("#241c14")
const GRAIN := Color("#2e2418")
const HOLE := Color("#15100b")
const FRAME := Color("#3a2c1c")
const FRAME_DARK := Color("#2a1f14")
const LIP := Color("#54402a")
const SHADE := Color("#070a10")
const PIN := Color("#d4614f")
const PIN_COOL := Color("#6f8fb0")

## WHAT THE BOARD IS, by the station's development level (Jon, 2026-10-01:
## "Unclaimed and outpost is like a cheap corkboard / settlement could be a
## whiteboard / city and capital are more of a LCD screen"), drawn here rather
## than generated ("Maybe we just stick with the coded for right now ... Can you
## code generate these at the different development levels?"). The paper on it
## is the same everywhere: the work and the town's are what the deck is for.
var dev := 2
const KINDS := {
	0: {"kind": "cork", "frame": Color("#b08c5c"), "frame_dark": Color("#7a5c34"), "lip": Color("#d8bc8c")},
	1: {"kind": "cork", "frame": Color("#9aa2aa"), "frame_dark": Color("#626a72"), "lip": Color("#d4dae0")},
	2: {"kind": "white", "frame": Color("#a8b0b8"), "frame_dark": Color("#6c747c"), "lip": Color("#e4e8ec")},
	3: {"kind": "lcd", "frame": Color("#4a525c"), "frame_dark": Color("#2c323a"), "lip": Color("#7c8692")},
	4: {"kind": "lcd", "frame": Color("#a8823a"), "frame_dark": Color("#6a501c"), "lip": Color("#ecca7a")},
}
const WHITE := Color("#e2e6e8")

## THE SCREEN IS A MARKETPLACE (Jon: "maybe we can have ads and popups on the
## LCD screens ... or we can make it look like a craigslist / facebook
## marketplace", then "Both"). An app bar across the top -- a title, a search
## box, category tabs -- the work as listings under it, and down the side the
## town's bounty as the featured listing, a rotating ad, the manufacturers'
## sponsored posts, and now and then a popup that opens over the side and
## closes itself. Popups never cover the work: nothing moves over what you can
## click.
const HEADER := 22.0
## THE TABS FILTER THE WORK (Jon: only what can be pressed may look as if it
## can). Each is a contract kind -- -1 for all of them -- and `tab_counts` is
## how many of each are on offer here, set by `StationScreen`. Picking one
## sends `tab_picked`; `StationScreen` lists only that kind.
const TABS := ["ALL", "HAULAGE", "BOUNTY", "HEAT"]
const TAB_KINDS := [-1, ContractData.Kind.FETCH, ContractData.Kind.HUNT, ContractData.Kind.HEAT]
signal tab_picked(i: int)
var tab := 0
var tab_counts: Array[int] = [0, 0, 0, 0]
var _tab_rects: Array[Rect2] = []
var _tab_hover := -1
const AD_EVERY := 6.0
## A POPUP STAYS UP UNTIL YOU SHUT IT (Jon: "the popups should stay up until
## you click on them"), by its X or its button; the next one comes POP_EVERY
## seconds after, the first POP_FIRST seconds after the screen is first drawn.
const POP_EVERY := 19.0
const POP_FIRST := 8.0


## THE STATION'S NUMBER (`StationScreen` sets it from the map), so each board is
## its own: which pieces of the pools it shows, where they sit, which ad and
## which headlines its screen starts on. The same station always looks the same.
var station_seed := 0:
	set(v):
		if v != station_seed:
			station_seed = v
			tab = 0
			_orders.clear()
			_laid.clear()
			_ticker_cache = ""
			queue_redraw()

var _orders := {}


## The k-th entry of a list of `n` in this station's own order for `salt`: every
## list is shuffled once per station, so two stations start in different places
## and one station turns through all of it before it repeats.
func _nth(n: int, salt: int, k: int) -> int:
	if n <= 0:
		return 0
	var key := Vector2i(n, salt)
	if not _orders.has(key):
		var a: Array[int] = []
		for j in n:
			a.append(j)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([station_seed, salt])
		for j in range(n - 1, 0, -1):
			var r := rng.randi_range(0, j)
			var t := a[j]
			a[j] = a[r]
			a[r] = t
		_orders[key] = a
	return (_orders[key] as Array[int])[posmod(k, n)]


var _ticker_cache := ""


## This station's run of headlines, joined by stars, for the ticker to crawl.
func _ticker_text() -> String:
	if _ticker_cache == "":
		var n := BoardScreen.TICKER.size()
		var parts: PackedStringArray = []
		for k in mini(n, 10):
			parts.append(String(BoardScreen.TICKER[_nth(n, 4, k)]))
		_ticker_cache = "  *  ".join(parts) + "  *  "
	return _ticker_cache


## EVERYTHING BUT THE WORK GOES WHERE IT LANDS (Jon: "having things in random
## locations would be cool. we can have a designated spot for the quests (top
## left), but the rest can just be random"). The work flows from the top left.
## The WANTED poster and the manufacturers' notices are always up: they are
## placed first, so they find room, and nothing lies over them. Then pieces
## from the board's pool, in this station's order, each tried at random spots
## until one is clear of the work and lies over no more than a little of what
## is already up. Nothing ever goes over the work.
const SCATTER_TRIES := 90
## How many pieces from the pool a board puts up, at most.
const SCATTER_MAX := {"cork": 14, "white": 10}
## How much of a piece may lie over pieces already up: paper on cork overlaps,
## as a real board's does; marker is never written over marker.
const OVERLAP := {"cork": 0.22, "white": 0.0}
## The top of a piece, where its title is, which nothing may land over.
const TITLE_BAND := 24.0
## The town's own paper, in every board's pool: the DOCK CRIER, the lost-drone
## flyer, the shift rota.
const TOWN := [
	{"paint": "_news", "size": Vector2(122, 106), "pin": 0.88},
	{"paint": "_flyer", "size": Vector2(110, 96), "pin": 0.88},
	{"paint": "_card", "size": Vector2(100, 58), "pin": 0.88},
]

var _laid := {}


## Where the real notices are, in the board's pixels.
func _work_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if list != null and is_instance_valid(list):
		var off := list.position - position
		for child in list.get_children():
			var c := child as Control
			if c != null and c.visible and c.size.x > 0.0:
				out.append(Rect2(off + c.position, c.size))
	return out


## The pieces and where they sit, worked out once per station, size and set of
## notices.
func _lay_out(w: float, h: float) -> Array:
	var kind := String(KINDS.get(dev, KINDS[2])["kind"])
	var work := _work_rects()
	var key := "%d|%d|%d|%d|%s|%s" % [station_seed, dev, int(w), int(h), str(work), str(posts)]
	if String(_laid.get("key", "")) == key:
		return _laid["items"]
	# inside the frame, and clear of the whiteboard's marker tray
	var area := Rect2(FRAME_W + 4.0, FRAME_W + 4.0, w - FRAME_W * 2.0 - 8.0,
		h - FRAME_W * 2.0 - 8.0 - (14.0 if kind == "white" else 0.0))
	var blocked: Array[Rect2] = []
	for r in work:
		blocked.append(r.grow(6.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([station_seed, dev, 11])

	var musts: Array = [{"what": "wanted", "size": Vector2(136, 170), "pin": 0.5}]
	for mid in posts:
		if musts.size() < 4 and DB.manufacturers.has(mid):
			musts.append({"what": "post", "mid": mid, "size": Vector2(118, 96), "pin": 0.86})
	var pool: Array = []
	var n := BoardWhite.count() if kind == "white" else BoardCork.count()
	for j in n:
		pool.append({"what": kind, "i": j,
			"size": BoardWhite.size_of(j) if kind == "white" else BoardCork.size_of(j)})
	for t: Dictionary in TOWN:
		pool.append({"what": "town", "paint": t["paint"], "size": t["size"], "pin": t["pin"]})
	for j in range(pool.size() - 1, 0, -1):
		var r := rng.randi_range(0, j)
		var tmp: Variant = pool[j]
		pool[j] = pool[r]
		pool[r] = tmp

	var up_musts: Array = []
	for m: Dictionary in musts:
		var at: Variant = _spot(m["size"], area, blocked, [], 0.0, rng)
		if at != null:
			m["at"] = at
			up_musts.append(m)
			blocked.append(Rect2(at, m["size"]).grow(4.0))
	var up: Array = []
	var laid: Array[Rect2] = []
	for piece: Dictionary in pool:
		if up.size() >= int(SCATTER_MAX.get(kind, 12)):
			break
		var at: Variant = _spot(piece["size"], area, blocked, laid, float(OVERLAP.get(kind, 0.0)), rng)
		if at == null:
			continue
		piece["at"] = at
		up.append(piece)
		laid.append(Rect2(at, piece["size"]))
	# what was put up first lies underneath; the musts go on top of it all
	_laid = {"key": key, "items": up + up_musts}
	return _laid["items"]


## A random spot inside `area` for a piece of `sz`, clear of `blocked`, lying
## over no more than `allow` of its own area of what is `laid` -- or null.
func _spot(sz: Vector2, area: Rect2, blocked: Array[Rect2], laid: Array[Rect2], allow: float,
		rng: RandomNumberGenerator) -> Variant:
	if sz.x > area.size.x or sz.y > area.size.y:
		return null
	for _try in SCATTER_TRIES:
		var at := Vector2(floorf(rng.randf_range(area.position.x, area.end.x - sz.x)),
			floorf(rng.randf_range(area.position.y, area.end.y - sz.y)))
		var r := Rect2(at, sz)
		var ok := true
		for b in blocked:
			if b.intersects(r):
				ok = false
				break
		if not ok:
			continue
		var over := 0.0
		for l in laid:
			if allow <= 0.0:
				if l.grow(6.0).intersects(r):
					ok = false
					break
			else:
				# never over the head of a piece already up, where its title is
				if Rect2(l.position, Vector2(l.size.x, TITLE_BAND)).intersects(r):
					ok = false
					break
				over += l.intersection(r).get_area()
		if ok and over <= allow * r.get_area():
			return at
	return null


## FOR THE HARNESS (`boardpool=`): the board's whole pool laid out in rows, from
## piece `gallery_from`, in place of the scatter, each with its number. On a
## screen, the ads, then the strip ads, then the popups. `gallery_shown` is how
## many fitted.
var gallery_from := -1
## How many moments of each commercial a pool page shows.
const REEL_FRAMES := 6
var gallery_shown := 0


func gallery_count() -> int:
	match String(KINDS.get(dev, KINDS[2])["kind"]):
		"white":
			return BoardWhite.count()
		"lcd":
			return BoardScreen.ADS.size() + BoardScreen.STRIPS.size() + BoardScreen.POPUPS.size() 				+ BoardCommercial.count() * REEL_FRAMES
		_:
			return BoardCork.count()


func _gallery_size(kind: String, j: int) -> Vector2:
	if kind == "white":
		return BoardWhite.size_of(j)
	if kind == "cork":
		return BoardCork.size_of(j)
	var na := BoardScreen.ADS.size()
	var ns := BoardScreen.STRIPS.size()
	if j < na:
		return Vector2(104, 170)
	if j < na + ns:
		return Vector2(240, 30)
	if j < na + ns + BoardScreen.POPUPS.size():
		return Vector2(176, 88)
	return Vector2(104, 170)


func _gallery_draw(w: float, h: float) -> void:
	var kind := String(KINDS.get(dev, KINDS[2])["kind"])
	var x0 := FRAME_W + 6.0
	var x := x0
	var y := FRAME_W + 12.0
	var row := 0.0
	gallery_shown = 0
	var na := BoardScreen.ADS.size()
	var ns := BoardScreen.STRIPS.size()
	for j in range(gallery_from, gallery_count()):
		var sz := _gallery_size(kind, j)
		if x + sz.x > w - FRAME_W - 6.0:
			x = x0
			y += row + 14.0
			row = 0.0
		if y + sz.y > h - FRAME_W - 16.0:
			break
		_text(str(j), x, y - 2.0, UITheme.FS_SMALL, Color("#ff3040"))
		draw_set_transform(Vector2(x, y), 0.0, Vector2.ONE)
		match kind:
			"white":
				BoardWhite.draw(self, j)
			"cork":
				BoardCork.draw(self, j)
			_:
				if j < na:
					_ad(sz, j)
				elif j < na + ns:
					var S: Dictionary = BoardScreen.STRIPS[j - na]
					var strip := Rect2(Vector2.ZERO, sz)
					draw_rect(strip, S["bg"])
					_centre_at(String(S["t"]), 0.0, 13.0, sz.x, UITheme.FS_SMALL, S["ink"])
					_centre_at(String(S["s"]), 0.0, 25.0, sz.x, UITheme.FS_SMALL, Color(S["ink"]).darkened(0.25))
				elif j < na + ns + BoardScreen.POPUPS.size():
					_popup(BoardScreen.POPUPS[j - na - ns], Rect2(Vector2.ZERO, sz), 1.0)
				else:
					# a commercial, REEL_FRAMES moments through it
					var f := j - na - ns - BoardScreen.POPUPS.size()
					BoardCommercial.draw(self, sz, f / REEL_FRAMES,
						(float(f % REEL_FRAMES) + 0.5) * BoardCommercial.LENGTH / float(REEL_FRAMES))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# the piece's box, faintly, to see that it keeps inside it
		draw_rect(Rect2(Vector2(x, y), sz), Color(1.0, 0.2, 0.3, 0.35), false, 1.0)
		x += sz.x + 10.0
		row = maxf(row, sz.y)
		gallery_shown += 1


func _scatter_draw(w: float, h: float) -> void:
	for piece: Dictionary in _lay_out(w, h):
		var at: Vector2 = piece["at"]
		var sz: Vector2 = piece["size"]
		match String(piece["what"]):
			"wanted":
				_sheet(at, sz, 0.0, _wanted, 0.5)
			"post":
				_sheet(at, sz, 0.0, _post.bind(piece["mid"]), 0.86)
			"town":
				_sheet(at, sz, 0.0, Callable(self, String(piece["paint"])), float(piece["pin"]))
			"white":
				draw_set_transform(at, 0.0, Vector2.ONE)
				BoardWhite.draw(self, int(piece["i"]))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"cork":
				draw_set_transform(at, 0.0, Vector2.ONE)
				BoardCork.draw(self, int(piece["i"]))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A COMMERCIAL'S JINGLE, once, as it plays (Jon: "Can we just do little jingles
## for the ads?"): each of BoardCommercial's, in its order, and how far into
## the commercial it starts, as he set them on Hiring Board, Heard. Composed on
## the game's own synth; levelled for a screen across the hall.
const JINGLES: Array[StringName] = [&"board_ad_hull_wax", &"board_ad_star_taxi", &"board_ad_noodles",
	&"board_ad_drone", &"board_ad_coolant", &"board_ad_lucky_spin"]
const JINGLE_AT := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
## The ad turn whose jingle has played, so each commercial plays it once.
var _jingled := -1


## LEAVING THE DECK TAKES THE JINGLE WITH IT: it is the screen's sound, and the
## screen is gone.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and screen():
		Audio.hush(JINGLES)


func _process(_dt: float) -> void:
	# the ads turn over, the cursor blinks, the popups come and go
	if screen() and is_visible_in_tree():
		queue_redraw()
		var turn := int(_t() / AD_EVERY)
		if turn % 3 == 2 and turn != _jingled and gallery_from < 0 and reel < 0:
			var ci := _nth(BoardCommercial.count(), 8, turn / 3)
			var into := fposmod(_t(), AD_EVERY) - float(JINGLE_AT[ci])
			if into >= 0.0:
				_jingled = turn
				# SCORED TO THE PICTURE, so it starts on the commercial's first
				# frame or not at all: come in partway through one and it stays
				# quiet rather than play out of step
				if into < 0.1:
					Audio.play(JINGLES[ci], 0.0)


static func _t() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


## The note's size and the gap the work's flow keeps (`StationScreen.NOTE`).
const SLOT := 136.0
const SLOT_GAP := 8.0
## A ticker crawling along the bottom of the glass, on a screen.
const TICKER := 13.0



## The work's grid of slots, in the board's pixels, that no real notice covers.
func _free_slots(h: float) -> Array[Rect2]:
	var x0 := FRAME_W + 8.0
	var y0 := FRAME_W + 10.0 + (HEADER if screen() else 0.0)
	var x1 := size.x * NOTICE_SHARE
	var y1 := h - FRAME_W - 8.0 - (TICKER if screen() else 0.0)
	var taken: Array[Rect2] = []
	if list != null and is_instance_valid(list):
		var off := list.position - position
		for child in list.get_children():
			var c := child as Control
			if c != null and c.visible and c.size.x > 0.0:
				taken.append(Rect2(off + c.position, c.size).grow(2.0))
	# column by column, from under the lowest real notice in it
	var out: Array[Rect2] = []
	var x := x0
	while x + SLOT <= x1 + 1.0:
		var y := y0
		for t in taken:
			if t.position.x < x + SLOT and t.end.x > x:
				y = maxf(y, t.end.y + SLOT_GAP)
		while y + SLOT * 0.6 <= y1:
			out.append(Rect2(x, y, SLOT, minf(SLOT, y1 - y)))
			y += SLOT + SLOT_GAP + 2.0
		x += SLOT + SLOT_GAP
	return out


## FOR THE HARNESS (`reelclip=`): one commercial alone, running from `reel_from`
## on the real clock, so it can be filmed and heard against its sting.
var reel := -1
var reel_from := 0.0


func _fill(w: float, h: float) -> void:
	if reel >= 0:
		var rs := Vector2(107, 170)
		draw_set_transform(Vector2(FRAME_W + 8.0, FRAME_W + 8.0), 0.0, Vector2.ONE)
		BoardCommercial.draw(self, rs, reel, minf(_t() - reel_from, BoardCommercial.LENGTH - 0.01))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if gallery_from >= 0:
		_gallery_draw(w, h)
		return
	if screen():
		var slots := _free_slots(h)
		for i in slots.size():
			_decoy_listing(slots[i], i)
		_ticker(w, h)
	else:
		_scatter_draw(w, h)


## Somebody else's listing on the marketplace, gone or going: a photo strip with
## a manufacturer's emblem, a price, a title, how long ago, and a stamp.
func _decoy_listing(r: Rect2, i: int) -> void:
	var ids: Array = DB.manufacturers.keys()
	var mid: StringName = ids[_nth(ids.size(), 7, i)]
	var m: ManufacturerData = DB.manufacturers.get(mid)
	draw_rect(r, Color("#0a1a2a"))
	var ph := Rect2(r.position, Vector2(r.size.x, 40.0))
	draw_rect(ph, m.field if m != null else Color("#203040"))
	if m != null:
		CardView.draw_emblem(self, mid, ph.get_center(), 1.2, m.colour, m.field)
	draw_rect(ph, Color(0.02, 0.06, 0.1, 0.45))
	var p := r.position + Vector2(6.0, 40.0)
	_text("%d CR" % (20 + (i * 37) % 180), p.x, p.y + 16.0, UITheme.FS_HEAD, Color("#8a6a3a"))
	_text(String(BoardScreen.DECOYS[_nth(BoardScreen.DECOYS.size(), 5, i)]), p.x, p.y + 30.0, UITheme.FS_SMALL, Color("#6f8ea4"))
	_text("%dH AGO" % (1 + (i * 5) % 23), p.x, p.y + 43.0, UITheme.FS_SMALL, Color("#3e5a70"))
	if r.size.y > 110.0:
		for k in 2:
			draw_rect(Rect2(p.x, p.y + 52.0 + float(k) * 7.0, r.size.x - 30.0 - float(k) * 24.0, 2.0), Color("#1c3448"))
	draw_rect(r, Color("#1c3a52"), false, 1.0)
	# the stamp, across the photo
	var st := String(BoardScreen.STAMPS[_nth(BoardScreen.STAMPS.size(), 6, i)])
	var col := Color("#ff7a66") if st != "PENDING" else Color("#f0c040")
	var sw := float(st.length()) * 12.0 + 12.0
	var sr := Rect2(r.position.x + (r.size.x - sw) * 0.5, r.position.y + 10.0, sw, 22.0)
	draw_rect(sr, Color(0, 0, 0, 0.5))
	draw_rect(sr, col, false, 2.0)
	_centre_at(st, sr.position.x, sr.position.y + 17.0, sw, UITheme.FS_HEAD, col)


func _centre_at(t: String, x: float, baseline: float, width: float, fs: int, col: Color) -> void:
	var tw := UITheme.pixel_font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(UITheme.pixel_font(), Vector2(floorf(x + (width - tw) * 0.5), baseline), t,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## THE LETTERS ARE STROKES, NOT A TYPEFACE (Jon: "let's make the text a little
## more believeable as hand written"). Each is a few pen strokes on a grid four
## wide and six tall, written with a steady lean, each letter a touch bigger or
## smaller than the last and spaced by hand. Calm, not shaky (Jon: "WAY too
## shakey"): no jitter inside a letter, at most a pixel off the line.
const PEN := {
	"A": [[[0, 6], [2, 0], [4, 6]], [[1, 3.6], [3, 3.6]]],
	"B": [[[0, 6], [0, 0], [3, 0], [4, 1], [3, 3], [0, 3]], [[3, 3], [4, 4.5], [3, 6], [0, 6]]],
	"C": [[[4, 1], [3, 0], [1, 0], [0, 1.5], [0, 4.5], [1, 6], [3, 6], [4, 5]]],
	"D": [[[0, 0], [0, 6], [2.5, 6], [4, 4.5], [4, 1.5], [2.5, 0], [0, 0]]],
	"E": [[[4, 0], [0, 0], [0, 6], [4, 6]], [[0, 3], [3, 3]]],
	"F": [[[4, 0], [0, 0], [0, 6]], [[0, 3], [3, 3]]],
	"G": [[[4, 1], [3, 0], [1, 0], [0, 1.5], [0, 4.5], [1, 6], [3, 6], [4, 5], [4, 3.5], [2, 3.5]]],
	"H": [[[0, 0], [0, 6]], [[4, 0], [4, 6]], [[0, 3], [4, 3]]],
	"I": [[[2, 0], [2, 6]]],
	"J": [[[1, 0], [4, 0]], [[3, 0], [3, 5], [2, 6], [1, 6], [0, 5]]],
	"K": [[[0, 0], [0, 6]], [[4, 0], [0, 3.5]], [[1, 2.8], [4, 6]]],
	"L": [[[0, 0], [0, 6], [4, 6]]],
	"M": [[[0, 6], [0, 0], [2, 3.5], [4, 0], [4, 6]]],
	"N": [[[0, 6], [0, 0], [4, 6], [4, 0]]],
	"O": [[[1, 0], [3, 0], [4, 1.5], [4, 4.5], [3, 6], [1, 6], [0, 4.5], [0, 1.5], [1, 0]]],
	"P": [[[0, 6], [0, 0], [3, 0], [4, 1], [4, 2], [3, 3], [0, 3]]],
	"R": [[[0, 6], [0, 0], [3, 0], [4, 1], [4, 2], [3, 3], [0, 3]], [[2, 3], [4, 6]]],
	"S": [[[4, 1], [3, 0], [1, 0], [0, 1], [0, 2], [1, 3], [3, 3], [4, 4], [4, 5], [3, 6], [1, 6], [0, 5]]],
	"T": [[[0, 0], [4, 0]], [[2, 0], [2, 6]]],
	"U": [[[0, 0], [0, 5], [1, 6], [3, 6], [4, 5], [4, 0]]],
	"V": [[[0, 0], [2, 6], [4, 0]]],
	"W": [[[0, 0], [1, 6], [2, 3], [3, 6], [4, 0]]],
	"X": [[[0, 0], [4, 6]], [[4, 0], [0, 6]]],
	"Y": [[[0, 0], [2, 3], [4, 0]], [[2, 3], [2, 6]]],
	"Z": [[[0, 0], [4, 0], [0, 6], [4, 6]]],
	"0": [[[1, 0], [3, 0], [4, 1.5], [4, 4.5], [3, 6], [1, 6], [0, 4.5], [0, 1.5], [1, 0]]],
	"1": [[[1, 1], [2, 0], [2, 6]]],
	"2": [[[0, 1], [1, 0], [3, 0], [4, 1], [4, 2], [0, 6], [4, 6]]],
	"3": [[[0, 0.5], [1, 0], [3, 0], [4, 1], [4, 2], [3, 3], [1.5, 3]], [[3, 3], [4, 4], [4, 5], [3, 6], [1, 6], [0, 5.5]]],
	"4": [[[3, 6], [3, 0], [0, 4], [4, 4]]],
	"5": [[[4, 0], [0, 0], [0, 3], [3, 3], [4, 4], [4, 5], [3, 6], [0, 6]]],
	"6": [[[3, 0], [1, 0], [0, 2], [0, 5], [1, 6], [3, 6], [4, 5], [4, 4], [3, 3], [0, 3]]],
	"7": [[[0, 0], [4, 0], [1.5, 6]]],
	"8": [[[1, 3], [0, 2], [0, 1], [1, 0], [3, 0], [4, 1], [4, 2], [3, 3], [1, 3], [0, 4], [0, 5], [1, 6], [3, 6], [4, 5], [4, 4], [3, 3]]],
	"9": [[[4, 3], [1, 3], [0, 2], [0, 1], [1, 0], [3, 0], [4, 1], [4, 4], [3, 6], [1, 6]]],
	"!": [[[2, 0], [2, 4]], [[2, 5.6], [2, 6]]],
	":": [[[2, 1.5], [2, 2]], [[2, 4.5], [2, 5]]],
	"-": [[[1, 3], [3, 3]]],
	"+": [[[0.5, 3], [3.5, 3]], [[2, 1.5], [2, 4.5]]],
	"Q": [[[1, 0], [3, 0], [4, 1.5], [4, 4.5], [3, 6], [1, 6], [0, 4.5], [0, 1.5], [1, 0]], [[2.5, 4.5], [4.5, 6.5]]],
	"?": [[[0, 1], [1, 0], [3, 0], [4, 1], [4, 2], [2, 3.5], [2, 4.5]], [[2, 5.6], [2, 6]]],
	".": [[[2, 5.6], [2, 6]]],
	",": [[[2, 5.4], [1.4, 7]]],
	"'": [[[2, 0], [2, 1.6]]],
	"/": [[[0, 6], [4, 0]]],
	"=": [[[0.5, 2.4], [3.5, 2.4]], [[0.5, 4], [3.5, 4]]],
	"#": [[[1.2, 0.5], [1.2, 5.5]], [[2.8, 0.5], [2.8, 5.5]], [[0, 2], [4, 2]], [[0, 4], [4, 4]]],
	"(": [[[2.5, 0], [1.2, 2], [1.2, 4], [2.5, 6]]],
	")": [[[1.5, 0], [2.8, 2], [2.8, 4], [1.5, 6]]],
}


## Words in marker, in strokes: `at` is where the line sits (the foot of the
## letters), as a string's baseline is.
func _hand(t: String, at: Vector2, col: Color, seed: float, fs: int = UITheme.FS_SMALL) -> void:
	var sc := 1.35 if fs <= UITheme.FS_SMALL else 2.8
	var x := at.x
	for k in t.length():
		var ch := t.substr(k, 1).to_upper()
		var h1 := ShopLight.hash1(seed * 3.1 + float(k) * 1.7)
		var h2 := ShopLight.hash1(seed * 1.3 + float(k) * 2.9)
		if ch == " ":
			x += 3.5 * sc + h1 * 1.5
			continue
		var g: Array = PEN.get(ch, [])
		var ls := sc * (0.96 + 0.08 * h2)
		var foot := Vector2(x, at.y + roundf((h1 - 0.5) * 1.2))
		var lean := 0.14 + (h2 - 0.5) * 0.04
		for stroke: Array in g:
			var prev := Vector2.ZERO
			for j in stroke.size():
				var pt: Array = stroke[j]
				var gy := float(pt[1])
				# up from the foot, leaning right as it rises
				var q := foot + Vector2(float(pt[0]) * ls + (6.0 - gy) * ls * lean, (gy - 6.0) * ls)
				if j > 0:
					draw_line(prev.round(), q.round(), col, 1.0)
					# the marker's width, laid beside the stroke
					draw_line(prev.round() + Vector2(1, 0), q.round() + Vector2(1, 0), Color(col.r, col.g, col.b, 0.6), 1.0)
				prev = q
		x += 4.0 * ls + 1.8 * sc + (h2 - 0.5) * 0.6


## A marker line: one gentle bow along its length, never a shake (Jon: the
## writing was "WAY too shakey"), two pixels wide.
func _wobble_line(a: Vector2, b: Vector2, col: Color, seed: float) -> void:
	var d := b - a
	var n := maxi(1, int(d.length() / 8.0))
	var bow := (ShopLight.hash1(seed * 1.9) - 0.5) * minf(3.0, d.length() * 0.05)
	var nrm := Vector2(-d.y, d.x).normalized()
	var prev := a
	for k in n:
		var t := float(k + 1) / float(n)
		var j := sin(t * PI) * bow
		var pt := a + d * t + nrm * j
		draw_line(prev.round(), pt.round(), col, 2.0)
		prev = pt


## A box by hand: four strokes, each overshooting its corner a little.
func _wobble_rect(r: Rect2, col: Color, seed: float) -> void:
	var o := 2.0
	_wobble_line(r.position + Vector2(-o, 0), Vector2(r.end.x + o, r.position.y), col, seed)
	_wobble_line(Vector2(r.end.x, r.position.y - o), r.end + Vector2(0, o), col, seed + 1.0)
	_wobble_line(r.end + Vector2(o, 0), Vector2(r.position.x - o, r.end.y), col, seed + 2.0)
	_wobble_line(Vector2(r.position.x, r.end.y + o), r.position + Vector2(0, -o), col, seed + 3.0)


## A circle by hand: a little lumpy, and closed -- the pen runs a touch past
## where it started, as a hand does. (It used to stop short, and the gap always
## fell at the top: Jon, "why are the circles cut off at the top?")
func _wobble_circle(c: Vector2, rad: float, col: Color, seed: float) -> void:
	var n := 24
	var start := ShopLight.hash1(seed * 2.3) * TAU
	var sweep := TAU + 0.3
	var prev := Vector2.ZERO
	for k in n + 1:
		var u := float(k) / float(n)
		var ang := start + u * sweep
		# the lumps follow the angle, so the overlap lands where it began
		var rr := rad + sin(ang - start + seed) * 0.8 + u * 0.6
		var pt := c + Vector2(cos(ang), sin(ang)) * rr
		if k > 0:
			draw_line(prev.round(), pt.round(), col, 2.0)
		prev = pt


## The news, crawling along the bottom of the glass.
func _ticker(w: float, h: float) -> void:
	var r := Rect2(FRAME_W, h - FRAME_W - TICKER, w - FRAME_W * 2.0, TICKER)
	draw_rect(r, Color("#0a2a44"))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), Color("#3ec8e0"))
	draw_rect(Rect2(r.position.x, r.position.y + 1.0, 30.0, TICKER - 1.0), Color("#c83a3a"))
	_text("LIVE", r.position.x + 4.0, r.position.y + 10.0, UITheme.FS_SMALL, Color.WHITE)
	var f := UITheme.pixel_font()
	var text := _ticker_text()
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	var x := r.position.x + 36.0 - fposmod(_t() * 32.0, tw)
	while x < r.end.x:
		draw_string(f, Vector2(floorf(x), r.position.y + 10.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, r.end.x - x, UITheme.FS_SMALL, Color("#c8f0ff"))
		x += tw
	draw_rect(Rect2(r.position.x, r.position.y + 1.0, 30.0, TICKER - 1.0), Color("#c83a3a"))
	_text("LIVE", r.position.x + 4.0, r.position.y + 10.0, UITheme.FS_SMALL, Color.WHITE)


## The app bar across the top of the glass.
func _app_bar(w: float) -> void:
	var e := FRAME_W
	draw_rect(Rect2(e, e, w - e * 2.0, HEADER), Color("#0a2a44"))
	draw_rect(Rect2(e, e + HEADER - 1.0, w - e * 2.0, 1.0), Color("#3ec8e0"))
	_text("STATION LISTINGS", e + 8.0, e + 14.0, UITheme.FS_SMALL, Color("#c8f0ff"))
	# the search box, kept for the look of the thing (Jon: "you can keep the
	# search box")
	var sx := e + 126.0
	draw_rect(Rect2(sx, e + 4.0, 120.0, 13.0), Color("#061426"))
	draw_rect(Rect2(sx, e + 4.0, 120.0, 13.0), Color("#3ec8e0"), false, 1.0)
	_text("SEARCH WORK", sx + 5.0, e + 14.0, UITheme.FS_SMALL, Color("#4a7a96"))
	if int(_t() * 2.0) % 2 == 0:
		draw_rect(Rect2(sx + 76.0, e + 7.0, 1.0, 8.0), Color("#c8f0ff"))
	# the tabs: real ones, each with how many it holds
	_tab_rects.clear()
	var tx := sx + 132.0
	for i in TABS.size():
		var label := "%s %d" % [TABS[i], tab_counts[i] if i < tab_counts.size() else 0]
		var tr := Rect2(tx, e + 4.0, float(label.length()) * 6.0 + 10.0, 13.0)
		_tab_rects.append(tr)
		if i == tab:
			draw_rect(tr, Color("#3ec8e0"))
			_text(label, tr.position.x + 5.0, e + 14.0, UITheme.FS_SMALL, Color("#061426"))
		else:
			var hot := i == _tab_hover
			draw_rect(tr, Color("#12405e") if hot else Color("#0c2a40"))
			draw_rect(tr, Color("#3ec8e0") if hot else Color("#2c6a88"), false, 1.0)
			var empty := i < tab_counts.size() and tab_counts[i] == 0
			_text(label, tr.position.x + 5.0, e + 14.0, UITheme.FS_SMALL,
				Color("#3e6a84") if empty else Color("#a8dcf0"))
		tx += tr.size.x + 6.0
	# the avatar and the bell, kept (Jon: "you can keep the bell and avatar,
	# they're good"), and who is on
	var rx := w - e - 8.0
	draw_rect(Rect2(rx - 14.0, e + 3.0, 14.0, 15.0), Color("#c86a3a"))
	draw_rect(Rect2(rx - 10.0, e + 5.0, 6.0, 6.0), Color("#f0d0a8"))
	draw_rect(Rect2(rx - 12.0, e + 12.0, 10.0, 6.0), Color("#f0d0a8"))
	var bx := rx - 34.0
	draw_rect(Rect2(bx, e + 6.0, 9.0, 8.0), Color("#c8f0ff"))
	draw_rect(Rect2(bx - 1.0, e + 13.0, 11.0, 2.0), Color("#c8f0ff"))
	draw_rect(Rect2(bx + 3.0, e + 15.0, 3.0, 2.0), Color("#c8f0ff"))
	draw_rect(Rect2(bx + 6.0, e + 2.0, 9.0, 9.0), Color("#e03a3a"))
	_text("%d" % (3 + int(_t() / 11.0) % 7), bx + 8.0, e + 10.0, UITheme.FS_SMALL, Color.WHITE)
	var on := 40 + int(_t() / 5.0) % 9
	draw_rect(Rect2(bx - 74.0, e + 9.0, 4.0, 4.0), Color("#46e07a"))
	_text("%d ONLINE" % on, bx - 66.0, e + 14.0, UITheme.FS_SMALL, Color("#7fb8d4"))


## The side of the marketplace: featured, an ad, the sponsored, a popup.
func _side(col: Rect2) -> void:
	var x := col.position.x
	var y := col.position.y + 4.0
	var poster := Vector2(minf(136.0, col.size.x * 0.56), 170.0)
	_tag("FEATURED", Vector2(x + 4.0, y), Color("#f0c040"))
	_sheet(Vector2(x + 4.0, y + 10.0), poster, 0.0, _featured, 0.5)
	# the ad, turning over every AD_EVERY seconds
	var aw := col.end.x - (x + poster.x + 14.0)
	var ad_at := Vector2(col.end.x - aw, y + 10.0)
	var turn := int(_t() / AD_EVERY)
	var k := _nth(BoardScreen.ADS.size(), 1, turn)
	_tag("AD", Vector2(ad_at.x, y), Color("#7fb8d4"))
	if turn % 3 == 2:
		# every third turn, a commercial plays in the slot instead
		var ci := _nth(BoardCommercial.count(), 8, turn / 3)
		_sheet(ad_at, Vector2(aw, poster.y), 0.0, _commercial.bind(ci, fposmod(_t(), AD_EVERY)), 0.5)
	else:
		_sheet(ad_at, Vector2(aw, poster.y), 0.0, _ad.bind(k), 0.5)
	# four dots under it, as a carousel has, the lit one walking along
	for d in 4:
		draw_rect(Rect2(ad_at.x + aw * 0.5 - 16.0 + float(d) * 9.0, ad_at.y + poster.y + 4.0, 5.0, 2.0),
			Color("#c8f0ff") if d == turn % 4 else Color("#2c4a60"))
	# the manufacturers' own, as sponsored posts
	var sy := y + poster.y + 26.0
	var put := 0
	for mid in posts:
		if put >= 2 or not DB.manufacturers.has(mid):
			continue
		var at := Vector2(x + 4.0 + float(put) * 126.0, sy)
		if at.y + 106.0 > col.end.y:
			break
		_sheet(at + Vector2(0.0, 10.0), Vector2(118.0, 96.0), 0.0, _sponsored.bind(mid), 0.86)
		put += 1
	# a strip ad along the foot of the side, turning over on its own clock
	var strip := Rect2(x + 4.0, sy + 116.0, col.size.x - 8.0, 30.0)
	if strip.end.y <= col.end.y:
		var S: Dictionary = BoardScreen.STRIPS[_nth(BoardScreen.STRIPS.size(), 2, int(_t() / 4.0))]
		draw_rect(strip, S["bg"])
		_centre_at(String(S["t"]), strip.position.x, strip.position.y + 13.0, strip.size.x, UITheme.FS_SMALL, S["ink"])
		_centre_at(String(S["s"]), strip.position.x, strip.position.y + 25.0, strip.size.x, UITheme.FS_SMALL, Color(S["ink"]).darkened(0.25))
		draw_rect(Rect2(strip.end.x - 16.0, strip.position.y + 2.0, 14.0, 9.0), Color(0, 0, 0, 0.35))
		_text("AD", strip.end.x - 14.0, strip.position.y + 9.0, UITheme.FS_SMALL, Color(1, 1, 1, 0.85))
	# a popup, now and then, over the side only, up until it is shut
	pop_x = Rect2()
	pop_btn = Rect2()
	if _pop_next < 0.0:
		_pop_next = _t() + POP_FIRST
	if _pop_at < 0.0 and _t() >= _pop_next:
		_pop_at = _t()
		_pops += 1
		# Jon's picks on Hiring Board, Heard: a soft chime chord to open, a
		# muffled pop to shut
		Audio.play(&"board_popup_open", 0.0)
	if _pop_at >= 0.0:
		var n := _pops % 3
		var pw := minf(176.0, col.size.x - 8.0)
		var at2 := Vector2(x + (col.size.x - pw) * 0.5 + float(n % 2) * 10.0 - 5.0, col.position.y + 70.0 + float(n) * 26.0)
		_popup(BoardScreen.POPUPS[_nth(BoardScreen.POPUPS.size(), 3, _pops)],
			Rect2(at2, Vector2(pw, 88.0)), _t() - _pop_at)


## THE FEATURED LISTING, a marketplace's, not a poster (Jon: "let's have the
## sponsered and featured different from the corkboard and whiteboard"): a
## photo of the Hellbender across the top with a gold star on its corner, the
## bounty as the price, what it is and what for. No VIEW chip: it is an ad,
## and nothing that cannot be pressed may look as if it can (Jon: "just remove
## the view and more buttons entirely. Just have it be an ad").
func _featured(sz: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, sz), Color("#0c2034"))
	var ph := Rect2(0.0, 0.0, sz.x, 70.0)
	draw_rect(ph, Color("#183a5a"))
	# a sky behind the photo: a few stars
	for i in 14:
		draw_rect(Rect2(floorf(_scatter(i * 7 + 3, sz.x - 4.0)) + 2.0,
			floorf(_scatter(i * 11 + 5, ph.size.y - 6.0)) + 2.0, 1.0, 1.0), Color(1, 1, 1, 0.5))
	# the Hellbender, side on
	var cy := 38.0
	var bx := 22.0
	var bw := sz.x - 54.0
	var hull := Color("#c8e4f4")
	draw_rect(Rect2(bx, cy - 6.0, bw, 12.0), hull)
	for k in 5:
		draw_rect(Rect2(bx + bw + float(k) * 2.0, cy - 5.0 + float(k), 2.0, 10.0 - float(k) * 2.0), hull)
	draw_rect(Rect2(bx + bw * 0.3, cy - 12.0, bw * 0.25, 6.0), hull)
	draw_rect(Rect2(bx - 6.0, cy - 3.0, 6.0, 6.0), hull)
	for d in 4:
		draw_rect(Rect2(bx + 8.0 + float(d) * bw * 0.2, cy - 1.0, 3.0, 2.0), EMBER)
	# the gold star on the corner, and the photo's edge
	var st := Vector2(sz.x - 16.0, 4.0)
	draw_rect(Rect2(st, Vector2(13.0, 13.0)), Color("#f0c040"))
	draw_rect(Rect2(st.x + 5.0, st.y + 2.0, 3.0, 9.0), Color("#7a5a10"))
	draw_rect(Rect2(st.x + 2.0, st.y + 5.0, 9.0, 3.0), Color("#7a5a10"))
	draw_rect(Rect2(0.0, ph.end.y, sz.x, 1.0), Color("#3ec8e0"))
	_text("2500 CR", 6.0, 92.0, UITheme.FS_HEAD, UITheme.EMBER)
	_text("BOUNTY: THE HELLBENDER", 6.0, 108.0, UITheme.FS_SMALL, Color("#c8f0ff"))
	_text("RIVAL HARVESTER", 6.0, 121.0, UITheme.FS_SMALL, Color("#6fa8c4"))
	_text("FOR STOLEN HEAT", 6.0, 132.0, UITheme.FS_SMALL, Color("#6fa8c4"))
	if not Run.hellbender_alive():
		draw_rect(Rect2(6.0, 18.0, sz.x - 12.0, 24.0), Color("#ff7a66"), false, 2.0)
		_centre("CLAIMED", 36.0, sz.x, UITheme.FS_HEAD, Color("#ff7a66"))
	draw_rect(Rect2(Vector2.ZERO, sz), Color("#f0c040"), false, 1.0)


## A SPONSORED POST, an ad in the manufacturer's own colours: its field, its
## emblem large, its words in a band under it, and SPONSORED in small. No MORE
## chip: it cannot be pressed, so it does not look as if it can.
func _sponsored(sz: Vector2, mid: StringName) -> void:
	var m: ManufacturerData = DB.manufacturers.get(mid)
	if m == null:
		return
	var pale := m.field.get_luminance() > 0.5
	var ink := m.colour.darkened(0.3) if pale else m.colour.lightened(0.15)
	draw_rect(Rect2(Vector2.ZERO, sz), m.field)
	# a sheen across the field, as a banner ad has
	draw_colored_polygon(PackedVector2Array([Vector2(sz.x * 0.55, 0.0), Vector2(sz.x * 0.8, 0.0),
		Vector2(sz.x * 0.45, sz.y), Vector2(sz.x * 0.2, sz.y)]), Color(1, 1, 1, 0.06))
	CardView.draw_emblem(self, mid, Vector2(sz.x * 0.5, 22.0), 1.6, m.colour, m.field)
	var entry: Array = POSTS.get(mid, [[], ""])
	var lines: Array = entry[0]
	var band := Rect2(0.0, 44.0, sz.x, 32.0)
	draw_rect(band, Color(0, 0, 0, 0.35))
	var baseline := band.position.y + 10.0
	for i in mini(lines.size(), 3):
		_centre(String(lines[i]), baseline, sz.x, UITheme.FS_SMALL, ink)
		baseline += 10.0
	var big: String = entry[1]
	if big != "":
		_text(big, 5.0, sz.y - 6.0, UITheme.FS_SMALL, ink)
	_text("SPONSORED", 4.0, 9.0, UITheme.FS_SMALL, Color(ink.r, ink.g, ink.b, 0.7))


func _tag(s: String, at: Vector2, col: Color) -> void:
	_text(s, at.x, at.y + 7.0, UITheme.FS_SMALL, col)


## One ad, in its colours, its lines centred down it, an AD mark in its corner.
func _ad(sz: Vector2, k: int) -> void:
	var A: Dictionary = BoardScreen.ADS[k]
	draw_rect(Rect2(Vector2.ZERO, sz), A["bg"])
	var lines: Array = A["lines"]
	var total := 0.0
	for L: Array in lines:
		total += float(L[1]) + 6.0
	var y := floorf((sz.y - total) * 0.5)
	for L: Array in lines:
		var fs := int(L[1])
		y += float(fs) + 6.0
		_centre(String(L[0]), y, sz.x, fs, A["ink"])
	draw_rect(Rect2(sz.x - 16.0, 2.0, 14.0, 9.0), Color(0, 0, 0, 0.35))
	_text("AD", sz.x - 14.0, 9.0, UITheme.FS_SMALL, Color(1, 1, 1, 0.85))


func _commercial(sz: Vector2, i: int, t: float) -> void:
	BoardCommercial.draw(self, sz, i, t * BoardCommercial.LENGTH / AD_EVERY)


## An old-style popup: a window with a title bar and a close box, two lines, a
## button. It opens with a jolt and stays until it is shut.
func _popup(P: Dictionary, r: Rect2, age: float) -> void:
	var grow := clampf(age / 0.12, 0.3, 1.0)
	var rr := Rect2((r.get_center() - r.size * grow * 0.5).round(), (r.size * grow).round())
	draw_rect(Rect2(rr.position + Vector2(3, 3), rr.size), Color(0, 0, 0, 0.45))
	draw_rect(rr, Color("#d8dce4"))
	draw_rect(rr, Color("#1a1e28"), false, 1.0)
	if grow < 1.0:
		return
	draw_rect(Rect2(rr.position + Vector2(1, 1), Vector2(rr.size.x - 2.0, 12.0)), Color("#2a5ad8"))
	_text(String(P["title"]), rr.position.x + 4.0, rr.position.y + 10.0, UITheme.FS_SMALL, Color.WHITE)
	var xb := Rect2(rr.end.x - 12.0, rr.position.y + 2.0, 10.0, 10.0)
	pop_x = xb
	draw_rect(xb, Color("#c83a3a"))
	_text("X", xb.position.x + 2.0, xb.position.y + 8.0, UITheme.FS_SMALL, Color.WHITE)
	var body: Array = P["body"]
	for i in body.size():
		_text(String(body[i]), rr.position.x + 8.0, rr.position.y + 30.0 + float(i) * 12.0, UITheme.FS_SMALL, Color("#1a1e28"))
	var bw := float(String(P["btn"]).length()) * 6.0 + 12.0
	var bb := Rect2(rr.end.x - bw - 8.0, rr.end.y - 20.0, bw, 13.0)
	pop_btn = bb
	draw_rect(bb, Color("#b8bec8"))
	draw_rect(bb, Color("#1a1e28"), false, 1.0)
	_text(String(P["btn"]), bb.position.x + 6.0, bb.position.y + 10.0, UITheme.FS_SMALL, Color("#1a1e28"))

## A SCREEN, NOT A BOARD (Jon: "so for the city and capital... it needs to be
## a screen"). In a city or a capital nothing is pinned up: the work and the
## town's notices are shown on the panel, lit, in its colours, square, with no
## pins and no shadows.
func screen() -> bool:
	return dev >= 3


## The colours the town's sheets are painted in: paper and ink on a board,
## panels and light on a screen.
func _pal(c: Color) -> Color:
	if not screen():
		return c
	match c:
		PAPER: return Color("#0e2236")
		NEWSPRINT: return Color("#10263a")
		CARD: return Color("#0e2030")
		INDEX: return Color("#12283a")
		INK: return Color("#c8f0ff")
		INK_SOFT: return Color("#6fa8c4")
		RED: return Color("#ff7a66")
		BLUE: return Color("#7fd4ff")
	return c
const SMUDGE := Color("#9aa4ac")
const GLASS := Color("#08101c")
const GRID := Color("#0d1828")

## THE TOWN'S PAPER. Every sheet is lighter than the cork, because it is furniture
## on a surface, and every sheet is a different shade from the next, because
## nothing on a real board came out of the same packet.
const PAPER := Color("#c2b48e")
const NEWSPRINT := Color("#a7a397")
const CARD := Color("#cdc1a0")
const INDEX := Color("#d6d0bd")
const INK := Color("#2a241a")
const INK_SOFT := Color("#5d5445")
const RED := Color("#9b3a2b")
const BLUE := Color("#3d5a86")
const EMBER := Color("#d97b29")

## How thick the board's wooden frame is.
const FRAME_W := 16.0
## How much of the board's width the real notices get, from the left. The rest of
## it is the town's column.
const NOTICE_SHARE := 0.62
## Where on a notice its pin goes through: the top middle, clear of the
## manufacturer's flag in its corner.
const PIN_AT := Vector2(68.0, 2.0)


func _init() -> void:
	# PASS, for the popups' close boxes: the board takes a click only on an X,
	# and everything else goes on through
	mouse_filter = Control.MOUSE_FILTER_PASS


## THE X WORKS (Jon: "making the x work is funny. yes"). Where the open
## popup's close box is, and which popup was closed, so it stays shut until the
## next one comes round.
var pop_x := Rect2()
## The popup's own button. It shuts the popup too, as the X does: anything that
## looks pressable on this board can be pressed (Jon: "Clicking claim/scan now
## or whatever button on the popup just closes them lol").
var pop_btn := Rect2()


## Whether `at` is on the open popup's X or its button.
func _on_pop(at: Vector2) -> bool:
	return (pop_x.has_area() and pop_x.grow(2.0).has_point(at)) \
		or (pop_btn.has_area() and pop_btn.grow(1.0).has_point(at))
## When the open popup came up (-1: none is up), when the next one is due,
## and how many have come.
var _pop_at := -1.0
var _pop_next := -1.0
var _pops := 0


func _tab_at(at: Vector2) -> int:
	if not screen():
		return -1
	for i in _tab_rects.size():
		if _tab_rects[i].grow(1.0).has_point(at):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _tab_at(mb.position) >= 0:
		var i := _tab_at(mb.position)
		accept_event()
		Audio.click()
		if i != tab:
			tab = i
			queue_redraw()
			tab_picked.emit(i)
		return
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _on_pop(mb.position):
		_pop_at = -1.0
		_pop_next = _t() + POP_EVERY
		Audio.play(&"board_popup_close", 0.0)
		pop_x = Rect2()
		pop_btn = Rect2()
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		accept_event()
		queue_redraw()
		return
	var mm := event as InputEventMouseMotion
	if mm != null:
		# the pointer closes over the X, as over any button
		var over := _tab_at(mm.position)
		if over != _tab_hover:
			_tab_hover = over
			queue_redraw()
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND \
			if _on_pop(mm.position) or over >= 0 else Control.CURSOR_ARROW


func watch(l: Control) -> void:
	list = l
	var redraw := _redraw_all
	var box := l as Container
	if box != null and not box.sort_children.is_connected(redraw):
		box.sort_children.connect(redraw)
	if not l.resized.is_connected(redraw):
		l.resized.connect(redraw)


func _redraw_all() -> void:
	queue_redraw()
	if _pins != null and is_instance_valid(_pins):
		_pins.queue_redraw()


## The pins through the notices, as a layer for the page to add ABOVE them.
##
## A control draws under its children, and a pin goes THROUGH the paper -- so the
## notices' pins cannot be drawn by the board. This hands back a layer whose
## drawing the board does, the same pattern the Shipyard's old service rows used.
func make_pins() -> Control:
	var p := Control.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.draw.connect(_draw_pins.bind(p))
	_pins = p
	return p


## A repeatable scatter, so the holes land in the same place every redraw.
func _scatter(i: int, span: float) -> float:
	return fmod(float(i) * 2654435761.0 / 65536.0, maxf(1.0, span))


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 60.0 or h <= 60.0:
		return

	var k: Dictionary = KINDS.get(dev, KINDS[2])
	match String(k["kind"]):
		"white":
			_whiteboard(w, h)
		"lcd":
			_lcd(w, h)
		_:
			_cork(w, h, dev == 0)

	# --- WHAT FILLS THE WORK'S EMPTY SPACE (Jon: "make the screen busier ...
	# add a ton more content to all of these"): old jobs, stickies and cards on
	# cork, marker on a whiteboard, other people's listings on a screen. Only
	# where no real notice is, and always under them.
	_fill(w, h)

	# --- ON A SCREEN, the marketplace's app bar across the top and its side
	# column. (On a board the town's paper is scattered with the rest, above.)
	if screen() and gallery_from < 0 and reel < 0:
		_app_bar(w)
		_side(Rect2(w * NOTICE_SHARE + 8.0, FRAME_W + HEADER + 6.0,
			w * (1.0 - NOTICE_SHARE) - FRAME_W - 16.0, h - FRAME_W * 2.0 - HEADER - TICKER - 14.0))

	# --- THE SHADOWS THE REAL NOTICES CAST, down and right of each, which is what
	# makes a notice sit ON the board rather than printed into it.
	if list != null and is_instance_valid(list) and not screen():
		var off := list.position - position
		for child in list.get_children():
			var c := child as Control
			if c == null or not c.visible or c.size.x <= 0.0:
				continue
			var t := c.get_transform()
			var pts := PackedVector2Array()
			for corner: Vector2 in [Vector2.ZERO, Vector2(c.size.x, 0.0), c.size,
					Vector2(0.0, c.size.y)]:
				pts.append(off + t * corner + Vector2(3.0, 4.0))
			draw_colored_polygon(pts, Color(SHADE.r, SHADE.g, SHADE.b, 0.55))

	# --- AND THE FRAME, last, so anything pinned near an edge tucks under it.
	_frame(w, h, k)


## A CHEAP CORKBOARD, an unclaimed station's and an outpost's: a pressed mat, so
## its texture has no beat, every pin ever pulled out still a hole in it; the
## unclaimed one older, stapled and torn where paper was ripped off.
func _cork(w: float, h: float, worn: bool) -> void:
	draw_rect(Rect2(0.0, 0.0, w, h), CORK)
	var gy := 4.0
	var step := 0
	while gy < h - 3.0:
		var gx := 6.0 + float((step * 37) % 23)
		while gx < w - 6.0:
			draw_rect(Rect2(gx, gy, 2.0 + float((step + int(gx)) % 3), 1.0), GRAIN)
			gx += 13.0 + float((step * 11 + int(gx)) % 11)
		gy += 4.0
		step += 1
	for i in (260 if worn else 170):
		draw_rect(Rect2(floorf(8.0 + _scatter(i * 7 + 2, w - 16.0)),
			floorf(8.0 + _scatter(i * 13 + 9, h - 16.0)), 1.0, 1.0), HOLE)
	for g in 3:
		draw_rect(Rect2(w * (0.08 + 0.21 * float(g)), h * (0.56 + 0.1 * float(g % 2)),
			70.0 + 12.0 * float(g), 44.0 + 8.0 * float(g)), Color(GRAIN.r, GRAIN.g, GRAIN.b, 0.55))
	if worn:
		# staples left behind, in pairs
		for i in 26:
			var sx := floorf(14.0 + _scatter(i * 17 + 5, w - 28.0))
			var sy := floorf(14.0 + _scatter(i * 23 + 11, h - 28.0))
			draw_rect(Rect2(sx, sy, 4.0, 1.0), Color("#9a9a92"))
			draw_rect(Rect2(sx + 7.0, sy + 1.0, 4.0, 1.0), Color("#7e7e78"))
		# corners of paper torn off, still stapled
		for i in 7:
			var tx := floorf(20.0 + _scatter(i * 29 + 3, w - 50.0))
			var ty := floorf(20.0 + _scatter(i * 31 + 7, h - 50.0))
			var sz := 6.0 + float(i % 3) * 3.0
			draw_colored_polygon(PackedVector2Array([Vector2(tx, ty), Vector2(tx + sz, ty),
				Vector2(tx, ty + sz)]), Color("#b8ab88"))
			draw_rect(Rect2(tx + 1.0, ty + 1.0, 3.0, 1.0), Color("#8a8a84"))


## A SETTLEMENT'S WHITEBOARD: white enamel, the grey ghosts of a hundred things
## written and wiped, a tray along the bottom with the markers in it.
func _whiteboard(w: float, h: float) -> void:
	draw_rect(Rect2(0.0, 0.0, w, h), WHITE)
	for i in 9:
		var sx := floorf(FRAME_W + _scatter(i * 41 + 3, w - 160.0))
		var sy := floorf(FRAME_W + _scatter(i * 37 + 9, h - 90.0))
		var sw := 60.0 + _scatter(i * 13 + 1, 90.0)
		var sh := 14.0 + _scatter(i * 19 + 5, 30.0)
		draw_rect(Rect2(sx, sy, sw, sh), Color(SMUDGE.r, SMUDGE.g, SMUDGE.b, 0.10))
		# a wiped line, streaked sideways
		draw_rect(Rect2(sx + 6.0, sy + sh * 0.5, sw - 12.0, 1.0), Color(SMUDGE.r, SMUDGE.g, SMUDGE.b, 0.18))
	# a dull sheen across the enamel
	for i in 3:
		var x0 := w * (0.2 + 0.28 * float(i))
		draw_colored_polygon(PackedVector2Array([Vector2(x0, FRAME_W), Vector2(x0 + 30.0, FRAME_W),
			Vector2(x0 - h * 0.4 + 30.0, h - FRAME_W), Vector2(x0 - h * 0.4, h - FRAME_W)]),
			Color(1, 1, 1, 0.35))


## A CITY'S AND A CAPITAL'S: the panel ON, a deep blue field brighter toward
## its middle, its pixel grid showing faintly, a title bar across the top.
func _lcd(w: float, h: float) -> void:
	draw_rect(Rect2(0.0, 0.0, w, h), Color("#061426"))
	# lit from within: bands of a little more light toward the middle
	for i in 4:
		var m := 0.12 + 0.1 * float(i)
		draw_rect(Rect2(w * m, h * m, w * (1.0 - 2.0 * m), h * (1.0 - 2.0 * m)),
			Color(0.1, 0.35, 0.6, 0.06))
	var y := FRAME_W + 1.0
	while y < h - FRAME_W:
		draw_rect(Rect2(FRAME_W, y, w - FRAME_W * 2.0, 1.0), Color(0, 0, 0, 0.18))
		y += 3.0
	var x := FRAME_W + 1.0
	while x < w - FRAME_W:
		draw_rect(Rect2(x, FRAME_W, 1.0, h - FRAME_W * 2.0), Color(0, 0, 0, 0.10))
		x += 3.0
	# the title bar, and a cursor blinking at its end
	draw_rect(Rect2(FRAME_W, FRAME_W, w - FRAME_W * 2.0, 1.0), Color("#3ec8e0"))
	draw_rect(Rect2(FRAME_W + 4.0, h - FRAME_W - 5.0, w * 0.3, 1.0), Color(0.25, 0.78, 0.9, 0.5))


func _frame(w: float, h: float, k: Dictionary) -> void:
	var e := FRAME_W
	var fr: Color = k["frame"]
	var fd: Color = k["frame_dark"]
	var lip: Color = k["lip"]
	for r: Rect2 in [Rect2(0.0, 0.0, w, e), Rect2(0.0, h - e, w, e),
			Rect2(0.0, 0.0, e, h), Rect2(w - e, 0.0, e, h)]:
		draw_rect(r, fr)
	if dev == 0:
		# cheap pine: grain along the rails
		for i in 9:
			var gx2 := 16.0 + float(i) * (w - 40.0) / 9.0
			draw_rect(Rect2(gx2, 3.0 + float(i % 3) * 2.0, w / 13.0, 1.0), fd)
			draw_rect(Rect2(gx2 + 20.0, h - e + 3.0 + float((i + 1) % 3) * 2.0, w / 14.0, 1.0), fd)
		for i in 5:
			var gy2 := 20.0 + float(i) * (h - 40.0) / 5.0
			draw_rect(Rect2(3.0 + float(i % 2) * 3.0, gy2, 1.0, h / 9.0), fd)
			draw_rect(Rect2(w - e + 4.0 + float((i + 1) % 2) * 3.0, gy2 + 14.0, 1.0, h / 10.0), fd)
	draw_rect(Rect2(0.0, 0.0, w, 1.0), lip)
	draw_rect(Rect2(0.0, 0.0, 1.0, h), Color(lip.r, lip.g, lip.b, 0.7))
	draw_rect(Rect2(0.0, h - 1.0, w, 1.0), fd)
	draw_rect(Rect2(w - 1.0, 0.0, 1.0, h), fd)
	draw_rect(Rect2(e, e, w - e * 2.0, 1.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.7))
	draw_rect(Rect2(e, e, 1.0, h - e * 2.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.5))
	match dev:
		0:
			# mitred corners, roughly cut
			for s in int(e):
				for corner: Vector2 in [Vector2(float(s), float(s)), Vector2(w - 1.0 - float(s), float(s)),
						Vector2(float(s), h - 1.0 - float(s)), Vector2(w - 1.0 - float(s), h - 1.0 - float(s))]:
					draw_rect(Rect2(corner.x, corner.y, 1.0, 1.0), fd)
		1, 2:
			# aluminium: a bright bevel inside the rail, plastic corner pieces
			draw_rect(Rect2(2.0, 2.0, w - 4.0, 1.0), lip)
			draw_rect(Rect2(e - 2.0, e - 2.0, w - e * 2.0 + 4.0, 1.0), fd)
			for c: Vector2 in [Vector2(0.0, 0.0), Vector2(w - 12.0, 0.0), Vector2(0.0, h - 12.0), Vector2(w - 12.0, h - 12.0)]:
				draw_rect(Rect2(c.x, c.y, 12.0, 12.0), Color("#3a3e44"))
				draw_rect(Rect2(c.x + 1.0, c.y + 1.0, 10.0, 1.0), Color("#5a6068"))
			if dev == 2:
				# the marker tray, and what is in it (Jon: "make the pens and
				# erasers on the white board a bit bigger")
				var ty := h - e - 4.0
				draw_rect(Rect2(e + 30.0, ty, w * 0.46, 9.0), fr)
				draw_rect(Rect2(e + 30.0, ty, w * 0.46, 1.0), lip)
				draw_rect(Rect2(e + 30.0, ty + 8.0, w * 0.46, 1.0), fd)
				for m in 3:
					var mc: Color = [Color("#2a2a2a"), Color("#c0302a"), Color("#2a4ab0")][m]
					var mx := e + 42.0 + float(m) * 46.0
					# the barrel, white, with its colour band and a cap at one end
					draw_rect(Rect2(mx + 2.0, ty - 5.0, 38.0, 7.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.3))
					draw_rect(Rect2(mx, ty - 7.0, 30.0, 7.0), Color("#e8e8e4"))
					draw_rect(Rect2(mx, ty - 7.0, 30.0, 1.0), Color("#ffffff"))
					draw_rect(Rect2(mx, ty - 1.0, 30.0, 1.0), Color("#a8a8a4"))
					draw_rect(Rect2(mx + 12.0, ty - 7.0, 6.0, 7.0), mc)
					draw_rect(Rect2(mx + 30.0, ty - 8.0, 10.0, 9.0), mc)
					draw_rect(Rect2(mx + 30.0, ty - 8.0, 10.0, 1.0), mc.lightened(0.4))
					draw_rect(Rect2(mx + 39.0, ty - 6.0, 2.0, 5.0), mc.darkened(0.3))
				# the eraser: felt underneath, a dark handle on top
				var ex := e + 42.0 + 3.0 * 46.0 + 8.0
				draw_rect(Rect2(ex + 2.0, ty - 9.0, 50.0, 12.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.3))
				draw_rect(Rect2(ex, ty - 14.0, 48.0, 9.0), Color("#2e2e34"))
				draw_rect(Rect2(ex, ty - 14.0, 48.0, 1.0), Color("#5a5a62"))
				draw_rect(Rect2(ex + 6.0, ty - 12.0, 36.0, 2.0), Color("#46464e"))
				draw_rect(Rect2(ex, ty - 5.0, 48.0, 5.0), Color("#c8c0b0"))
				draw_rect(Rect2(ex, ty - 5.0, 48.0, 1.0), Color("#a89c88"))
				# marker dust on the felt
				for dk in 5:
					draw_rect(Rect2(ex + 6.0 + float(dk) * 8.0, ty - 3.0 + float(dk % 2), 3.0, 1.0), Color("#6a6a78"))
		3, 4:
			_monitor(w, h, k)


## A MONITOR'S CASING, not a picture frame (Jon: "Can we make the frame of the
## LCD monitors have little buttons or something? Just to make it look more like
## a TV monitor or screen instead of a painting frame"): rounded corners, a
## speaker grille and a blank nameplate along the chin, a row of push buttons
## and the power light on the right of it, a camera eye at the top. A city's
## is grey plastic; a capital's is brushed brass with gold buttons.
func _monitor(w: float, h: float, k: Dictionary) -> void:
	var e := FRAME_W
	var fr: Color = k["frame"]
	var fd: Color = k["frame_dark"]
	var lip: Color = k["lip"]
	var gold := dev >= 4
	# rounded corners: the wall shows through where the casing curves away
	for c: Vector2 in [Vector2(0.0, 0.0), Vector2(w - 3.0, 0.0), Vector2(0.0, h - 3.0), Vector2(w - 3.0, h - 3.0)]:
		draw_rect(Rect2(c.x + (0.0 if c.x == 0.0 else 2.0), c.y + (0.0 if c.y == 0.0 else 2.0), 1.0, 1.0), Color("#0d1016"))
	draw_rect(Rect2(0.0, 0.0, 2.0, 1.0), Color("#0d1016"))
	draw_rect(Rect2(0.0, 0.0, 1.0, 2.0), Color("#0d1016"))
	draw_rect(Rect2(w - 2.0, 0.0, 2.0, 1.0), Color("#0d1016"))
	draw_rect(Rect2(w - 1.0, 0.0, 1.0, 2.0), Color("#0d1016"))
	draw_rect(Rect2(0.0, h - 1.0, 2.0, 1.0), Color("#0d1016"))
	draw_rect(Rect2(0.0, h - 2.0, 1.0, 2.0), Color("#0d1016"))
	draw_rect(Rect2(w - 2.0, h - 1.0, 2.0, 1.0), Color("#0d1016"))
	draw_rect(Rect2(w - 1.0, h - 2.0, 1.0, 2.0), Color("#0d1016"))
	# the glass sits in a recess: a dark lip all round it
	draw_rect(Rect2(e - 2.0, e - 2.0, w - e * 2.0 + 4.0, 2.0), fd.darkened(0.3))
	draw_rect(Rect2(e - 2.0, h - e, w - e * 2.0 + 4.0, 2.0), fd.darkened(0.3))
	draw_rect(Rect2(e - 2.0, e - 2.0, 2.0, h - e * 2.0 + 4.0), fd.darkened(0.3))
	draw_rect(Rect2(w - e, e - 2.0, 2.0, h - e * 2.0 + 4.0), fd.darkened(0.3))
	if gold:
		# brushed: fine streaks along the rails
		for i in 22:
			var sx := 6.0 + float(i) * (w - 12.0) / 22.0
			draw_rect(Rect2(sx, 3.0 + float(i % 3) * 3.0, w / 30.0, 1.0), Color(lip.r, lip.g, lip.b, 0.35))
			draw_rect(Rect2(sx + 9.0, h - e + 3.0 + float((i + 1) % 3) * 3.0, w / 34.0, 1.0), Color(lip.r, lip.g, lip.b, 0.25))
	# the camera eye, top middle
	var cx := floorf(w * 0.5)
	draw_rect(Rect2(cx - 2.0, 5.0, 5.0, 5.0), fd.darkened(0.4))
	draw_rect(Rect2(cx - 1.0, 6.0, 3.0, 3.0), Color("#0a0e18"))
	draw_rect(Rect2(cx - 1.0, 6.0, 1.0, 1.0), Color("#5a7aa8"))
	# the chin: a speaker grille on the left
	var cy := h - e + 4.0
	for gx in 18:
		for gy in 4:
			draw_rect(Rect2(e + 6.0 + float(gx) * 3.0, cy + float(gy) * 2.0, 1.0, 1.0), fd.darkened(0.35))
	# a nameplate in the middle, blank but for a bar where a logo would be
	var np := Rect2(cx - 22.0, cy, 44.0, 8.0)
	draw_rect(np, Color("#d4a84a") if gold else fd)
	draw_rect(Rect2(np.position.x, np.position.y, np.size.x, 1.0), Color("#f0d488") if gold else lip)
	draw_rect(Rect2(np.position.x + 8.0, np.position.y + 3.0, 28.0, 2.0), Color("#8a6420") if gold else fr.lightened(0.25))
	# push buttons on the right: raised, lit from above, the power one last
	var bx := w - e - 92.0
	for i in 5:
		var br := Rect2(bx + float(i) * 14.0, cy, 10.0, 7.0)
		var face := Color("#c89a3a") if gold else fr.darkened(0.15)
		draw_rect(Rect2(br.position + Vector2(0, 1), br.size), fd.darkened(0.4))
		draw_rect(br, face)
		draw_rect(Rect2(br.position.x, br.position.y, br.size.x, 1.0), Color("#f0d488") if gold else lip)
		draw_rect(Rect2(br.position.x, br.end.y - 1.0, br.size.x, 1.0), face.darkened(0.3))
		# a little mark on each: minus, plus, menu, input, power
		var ic := Color("#5a3a10") if gold else fd.darkened(0.2)
		var m := br.position + Vector2(3.0, 3.0)
		match i:
			0:
				draw_rect(Rect2(m.x, m.y, 4.0, 1.0), ic)
			1:
				draw_rect(Rect2(m.x, m.y, 4.0, 1.0), ic)
				draw_rect(Rect2(m.x + 1.0, m.y - 1.0, 1.0, 3.0), ic)
			2:
				draw_rect(Rect2(m.x, m.y - 1.0, 4.0, 1.0), ic)
				draw_rect(Rect2(m.x, m.y + 1.0, 4.0, 1.0), ic)
			3:
				draw_rect(Rect2(m.x, m.y - 1.0, 4.0, 3.0), ic, false, 1.0)
			4:
				draw_rect(Rect2(m.x + 1.0, m.y - 1.0, 1.0, 2.0), Color("#c83a3a"))
				draw_rect(Rect2(m.x, m.y, 1.0, 2.0), ic)
				draw_rect(Rect2(m.x + 3.0, m.y, 1.0, 2.0), ic)
				draw_rect(Rect2(m.x, m.y + 2.0, 4.0, 1.0), ic)
	# and the power light beside them
	draw_rect(Rect2(bx + 74.0, cy + 2.0, 3.0, 3.0), Color("#46e07a"))
	draw_rect(Rect2(bx + 73.0, cy + 1.0, 5.0, 5.0), Color(0.27, 0.88, 0.48, 0.25))

func _draw_pins(p: Control) -> void:
	if list == null or not is_instance_valid(list) or screen():
		return
	var off := list.position - p.position
	var n := 0
	for child in list.get_children():
		var c := child as Control
		if c == null or not c.visible:
			continue
		var at := off + c.position + PIN_AT
		var col := PIN_COOL if n % 3 == 2 else PIN
		if dev >= 2:
			# nothing pins into enamel: a magnet holds it
			draw_magnet(p, at + Vector2(1, 0), MAGNETS[n % MAGNETS.size()])
		else:
			draw_pushpin(p, at, col)
		n += 1


# ------------------------------------------------------------- the town's paper


## One sheet, with its shadow and its pin -- turned about its corner only when
## `deg` is not zero, which is only ever the scrap with nothing written on it.
##
## THE PIN GOES WHERE THE WORDS ARE NOT. It sat dead centre on every sheet, and on
## a sheet whose title starts at its left edge the centre is the end of the title:
## the rota card read SHIFT ROT with a pin where the A was. `pin_x` is a fraction
## of the width -- the middle for a centred title, the right-hand corner for one
## that starts at the left.
func _sheet(at: Vector2, sz: Vector2, deg: float, paint: Callable, pin_x: float) -> void:
	if screen():
		draw_set_transform(at, 0.0, Vector2.ONE)
		paint.call(sz)
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.25, 0.78, 0.9, 0.55), false, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_set_transform(at, deg_to_rad(deg), Vector2.ONE)
	# The flyer throws its own shadow: none where its tabs were torn off.
	if paint.get_method() != &"_flyer":
		draw_rect(Rect2(3.0, 4.0, sz.x, sz.y), Color(SHADE.r, SHADE.g, SHADE.b, 0.5))
	paint.call(sz)
	_pin(Vector2(floorf(sz.x * pin_x), 4.0), PIN)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _pin(p: Vector2, col: Color) -> void:
	if screen():
		return
	if dev >= 2:
		draw_magnet(self, p + Vector2(1, 0), MAGNETS[int(absf(p.x * 7.0 + p.y)) % MAGNETS.size()])
	else:
		draw_pushpin(self, p, col)


## A whiteboard's magnets: bright plastic buttons, no two the same colour in a row.
const MAGNETS := [Color("#d8402a"), Color("#2a6ad8"), Color("#e8b820"), Color("#2aa858"), Color("#a840c8")]


## Rows of a filled circle, as half-widths from its middle, top to bottom.
static func _disc_rows(r: int) -> Array[int]:
	var out: Array[int] = []
	for y in range(-r, r + 1):
		out.append(int(floorf(sqrt(maxf(0.0, float(r * r) - float(y * y)) + 0.6))))
	return out


static func _disc(ci: CanvasItem, c: Vector2, r: int, col: Color) -> void:
	var rows := _disc_rows(r)
	for i in rows.size():
		var hw := rows[i]
		ci.draw_rect(Rect2(c.x - float(hw), c.y - float(r) + float(i), float(hw * 2 + 1), 1.0), col)


## A PUSH PIN, seen from the front: its shadow thrown down and right where the
## needle goes in, a round cap darker at its rim, lighter in its middle, and a
## glint (Jon: "make the corkboard pins look like pins").
static func draw_pushpin(ci: CanvasItem, at: Vector2, col: Color) -> void:
	var c := (at + Vector2(1, -1)).round()
	_disc(ci, c + Vector2(2, 3), 4, Color(SHADE.r, SHADE.g, SHADE.b, 0.5))
	# the needle, going in below the cap
	ci.draw_rect(Rect2(c.x + 1.0, c.y + 4.0, 1.0, 2.0), Color("#b8b8b0"))
	ci.draw_rect(Rect2(c.x + 2.0, c.y + 5.0, 2.0, 1.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.6))
	_disc(ci, c, 4, col.darkened(0.4))
	_disc(ci, c + Vector2(0, -1), 3, col)
	ci.draw_rect(Rect2(c.x - 2.0, c.y - 3.0, 2.0, 1.0), col.lightened(0.6))
	ci.draw_rect(Rect2(c.x - 3.0, c.y - 2.0, 1.0, 2.0), col.lightened(0.4))
	ci.draw_rect(Rect2(c.x - 1.0, c.y - 2.0, 1.0, 1.0), Color(1, 1, 1, 0.7))


## A MAGNET: a round plastic button, bigger than a pin, its edge bevelled dark
## underneath and light on top, a shiny crescent, and its shadow on the enamel.
static func draw_magnet(ci: CanvasItem, at: Vector2, col: Color) -> void:
	var c := (at + Vector2(1, 0)).round()
	_disc(ci, c + Vector2(1, 3), 6, Color(SHADE.r, SHADE.g, SHADE.b, 0.35))
	_disc(ci, c, 6, col.darkened(0.45))
	_disc(ci, c + Vector2(0, -1), 5, col)
	# the shine: a crescent up and to the left, and a spot of light
	ci.draw_rect(Rect2(c.x - 3.0, c.y - 5.0, 4.0, 1.0), col.lightened(0.6))
	ci.draw_rect(Rect2(c.x - 5.0, c.y - 3.0, 1.0, 3.0), col.lightened(0.5))
	ci.draw_rect(Rect2(c.x - 4.0, c.y - 4.0, 1.0, 1.0), col.lightened(0.55))
	ci.draw_rect(Rect2(c.x + 2.0, c.y - 4.0, 1.0, 1.0), Color(1, 1, 1, 0.55))


func _text(s: String, x: float, baseline: float, fs: int, col: Color) -> void:
	draw_string(UITheme.pixel_font(), Vector2(x, baseline), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _centre(s: String, baseline: float, width: float, fs: int, col: Color) -> void:
	var f := UITheme.pixel_font()
	var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(floorf((width - tw) * 0.5), baseline), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## WANTED: THE HELLBENDER. The rival harvester every run shares its galaxy with,
## drawn as the salamander of a hull the log describes, its holds glowing.
## Stamped CLAIMED once somebody has actually killed it, so the board keeps up
## with the run it is in.
func _wanted(sz: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, sz), _pal(PAPER))
	draw_rect(Rect2(Vector2.ZERO, sz), _pal(PAPER).darkened(0.3), false, 1.0)
	_centre("WANTED", 22.0, sz.x, UITheme.FS_HEAD, _pal(RED))
	draw_rect(Rect2(8.0, 27.0, sz.x - 16.0, 1.0), _pal(INK_SOFT))
	var box := Rect2(10.0, 32.0, sz.x - 20.0, 58.0)
	draw_rect(box, Color(_pal(INK).r, _pal(INK).g, _pal(INK).b, 0.16))
	draw_rect(box, _pal(INK_SOFT), false, 1.0)
	var cy := box.position.y + box.size.y * 0.55
	var bx := box.position.x + 12.0
	var bw := box.size.x - 30.0
	draw_rect(Rect2(bx, cy - 6.0, bw, 12.0), _pal(INK))
	for s in 5:
		draw_rect(Rect2(bx + bw + float(s) * 2.0, cy - 5.0 + float(s), 2.0,
			10.0 - float(s) * 2.0), _pal(INK))
	draw_rect(Rect2(bx + bw * 0.3, cy - 12.0, bw * 0.25, 6.0), _pal(INK))
	draw_rect(Rect2(bx - 6.0, cy - 3.0, 6.0, 6.0), _pal(INK))
	for d in 4:
		draw_rect(Rect2(bx + 8.0 + float(d) * bw * 0.2, cy - 1.0, 3.0, 2.0), EMBER)
	_centre("THE HELLBENDER", 102.0, sz.x, UITheme.FS_SMALL, _pal(INK))
	_centre("RIVAL HARVESTER", 113.0, sz.x, UITheme.FS_SMALL, _pal(INK_SOFT))
	_centre("FOR STOLEN HEAT", 124.0, sz.x, UITheme.FS_SMALL, _pal(INK_SOFT))
	draw_rect(Rect2(8.0, 131.0, sz.x - 16.0, 1.0), _pal(INK_SOFT))
	_centre("BOUNTY", 145.0, sz.x, UITheme.FS_SMALL, _pal(INK))
	_centre("2500 CR", 164.0, sz.x, UITheme.FS_HEAD, _pal(RED))
	if not Run.hellbender_alive():
		draw_rect(Rect2(14.0, 48.0, sz.x - 28.0, 24.0), _pal(RED), false, 2.0)
		_centre("CLAIMED", 66.0, sz.x, UITheme.FS_HEAD, _pal(RED))


## A clipping from the station's sheet, cut out along a ragged bottom edge.
func _news(sz: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, sz), _pal(NEWSPRINT))
	for i in int(sz.x / 4.0):
		draw_rect(Rect2(float(i) * 4.0, sz.y, 4.0, float((i * 3) % 3)), _pal(NEWSPRINT))
	_text("DOCK CRIER", 5.0, 11.0, UITheme.FS_SMALL, _pal(INK))
	draw_rect(Rect2(4.0, 14.0, sz.x - 8.0, 1.0), _pal(INK))
	draw_rect(Rect2(4.0, 16.0, sz.x - 8.0, 1.0), _pal(INK_SOFT))
	_text("LANE CLOSED", 5.0, 27.0, UITheme.FS_SMALL, _pal(INK))
	var photo := Rect2(sz.x - 44.0, 32.0, 38.0, 30.0)
	draw_rect(photo, Color(_pal(INK).r, _pal(INK).g, _pal(INK).b, 0.35))
	draw_rect(Rect2(photo.position.x + 12.0, photo.position.y + 12.0, 12.0, 5.0), _pal(INK))
	draw_rect(Rect2(photo.position.x + 22.0, photo.position.y + 10.0, 3.0, 3.0), EMBER)
	for row in 10:
		var yy := 34.0 + float(row) * 6.0
		if yy > sz.y - 4.0:
			break
		var right := sz.x - 50.0 if yy < 64.0 else sz.x - 6.0
		draw_rect(Rect2(5.0, yy, right - 5.0 - float((row * 13) % 17), 2.0),
			Color(_pal(INK).r, _pal(INK).g, _pal(INK).b, 0.5))


## A lost-and-found flyer with its number on tear-off tabs, a third of them gone.
func _flyer(sz: Vector2) -> void:
	var body := sz.y - 26.0
	var tabs := 8
	var tw := sz.x / float(tabs)
	if not screen():
		var sh := Color(SHADE.r, SHADE.g, SHADE.b, 0.5)
		draw_rect(Rect2(3.0, 4.0, sz.x, body), sh)
		for i in tabs:
			if i % 3 != 1:
				draw_rect(Rect2(float(i) * tw + 3.0, body + 4.0, tw - 1.0, 26.0), sh)
	draw_rect(Rect2(0.0, 0.0, sz.x, body), _pal(CARD))
	_text("LOST DRONE", 6.0, 14.0, UITheme.FS_SMALL, _pal(INK))
	_text("ANSWERS TO", 6.0, 28.0, UITheme.FS_SMALL, _pal(INK_SOFT))
	_text("BLIP", 6.0, 40.0, UITheme.FS_SMALL, _pal(BLUE))
	# A drawing of Blip, done by somebody who loved it.
	draw_rect(Rect2(sz.x - 34.0, 22.0, 20.0, 10.0), _pal(INK_SOFT))
	draw_rect(Rect2(sz.x - 30.0, 25.0, 4.0, 3.0), EMBER)
	draw_rect(Rect2(sz.x - 38.0, 26.0, 4.0, 2.0), _pal(INK_SOFT))
	draw_rect(Rect2(sz.x - 14.0, 26.0, 4.0, 2.0), _pal(INK_SOFT))
	for i in tabs:
		if i % 3 == 1:
			continue
		var tr := Rect2(float(i) * tw, body, tw - 1.0, 26.0)
		draw_rect(tr, _pal(CARD))
		for d in 4:
			draw_rect(Rect2(tr.position.x + tw * 0.5 - 1.0, tr.position.y + 4.0 + float(d) * 5.0,
				2.0, 3.0), Color(_pal(INK).r, _pal(INK).g, _pal(INK).b, 0.6))
	var dx := 0.0
	while dx < sz.x:
		draw_rect(Rect2(dx, body, 3.0, 1.0), _pal(INK_SOFT))
		dx += 5.0


## An index card with the shift rota on it, in blue biro.
func _card(sz: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, sz), _pal(INDEX))
	draw_rect(Rect2(0.0, 11.0, sz.x, 1.0), Color(_pal(RED).r, _pal(RED).g, _pal(RED).b, 0.7))
	var ly := 19.0
	while ly < sz.y - 2.0:
		draw_rect(Rect2(0.0, ly, sz.x, 1.0), Color(_pal(BLUE).r, _pal(BLUE).g, _pal(BLUE).b, 0.25))
		ly += 8.0
	_text("SHIFT ROTA", 4.0, 9.0, UITheme.FS_SMALL, _pal(INK))
	for r in 4:
		var yy := 15.0 + float(r) * 8.0
		if yy > sz.y - 4.0:
			break
		draw_rect(Rect2(5.0, yy, 30.0 + float((r * 11) % 25), 2.0),
			Color(_pal(BLUE).r, _pal(BLUE).g, _pal(BLUE).b, 0.7))


## The corner of a notice torn down, left behind under its pin.
func _scrap(sz: Vector2) -> void:
	var row := 0.0
	while row < sz.y:
		var wide := floorf(sz.x * (1.0 - row / sz.y))
		draw_rect(Rect2(0.0, row, wide, 1.0), _pal(PAPER).darkened(0.08))
		row += 1.0


## What each manufacturer pins up: its lines, then one word set large.
##
## IN EACH ONE'S OWN VOICE, lifted from who they already are rather than invented
## beside it. Korvan stamps parts for a war two centuries over, and they fire every
## time; Solari lost an argument about safety margins; Probate follows other
## people's disasters; Redline is never at the address on its invoices; Verity
## makes few and signs them; Cygnet's drones anticipate you and nobody discusses
## it; Calyx hulls are grown, with a clause about what not to feed them.
const POSTS := {
	&"korvan": [["DAYS WITHOUT", "A MISFIRE"], "71204"],
	&"solari": [["NOW HIRING", "FURNACE HANDS", "MUST ENJOY"], "HEAT"],
	&"probate": [["ESTATE SALE", "HULLS OF THE", "RECENTLY LATE"], "BIDS"],
	&"redline": [["FAST REFITS", "NO SERIALS", "NO RECORDS"], "CASH"],
	&"verity": [["BY APPOINTMENT", "COMMISSIONS", "CLOSED"], ""],
	&"cygnet": [["A REMINDER", "FROM THE SWARM", "YOU ARE NEVER"], "ALONE"],
	&"calyx": [["PLEASE DO NOT", "FEED THE HULL", "THANK YOU"], ""],
}


## One manufacturer's notice: its field for paper, its mark for ink, its emblem at
## the head, a band of its colour across the top, and its lines under that.
func _post(sz: Vector2, mid: StringName) -> void:
	var m: ManufacturerData = DB.manufacturers.get(mid)
	if m == null:
		return
	# INK THAT READS ON ITS OWN PAPER. Verity and Calyx print on pale stock and the
	# rest on dark, so the mark is pushed away from whichever the field is.
	var pale := m.field.get_luminance() > 0.5
	var ink := m.colour.darkened(0.3) if pale else m.colour.lightened(0.12)
	var soft := Color(ink.r, ink.g, ink.b, 0.8)
	draw_rect(Rect2(Vector2.ZERO, sz), m.field)
	draw_rect(Rect2(0.0, 0.0, sz.x, 3.0), m.colour)
	draw_rect(Rect2(Vector2.ZERO, sz), Color(ink.r, ink.g, ink.b, 0.45), false, 1.0)
	CardView.draw_emblem(self, mid, Vector2(sz.x * 0.5, 14.0), 1.0, m.colour, m.field)
	var entry: Array = POSTS.get(mid, [[], ""])
	var lines: Array = entry[0]
	var big: String = entry[1]
	var baseline := 40.0
	for line in lines:
		_centre(String(line), baseline, sz.x, UITheme.FS_SMALL, soft)
		baseline += 11.0
	if big != "":
		_centre(big, sz.y - 8.0, sz.x, UITheme.FS_HEAD, ink)
	else:
		# A signature where the big word would go: somebody put their name to it.
		var sx := sz.x * 0.3
		var i := 0
		while sx < sz.x * 0.72:
			draw_rect(Rect2(sx, sz.y - 14.0 + float((i * 3) % 5) - 2.0, 4.0, 1.0), ink)
			sx += 3.0
			i += 1
