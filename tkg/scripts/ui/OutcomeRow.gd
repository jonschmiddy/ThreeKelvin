class_name OutcomeRow
extends RefCounted

## Jon, Oct 17: what you end up with was hard to read. D, his pick (Oct 18): only the stats that
## moved (DATA a fifth), no totals, a table beside REWARD (Oct 19). Today's, A, B, C and E were
## retired Nov 14.
## Why: docs/why/OutcomeRow.md#outcome-looks

## Every drawn outcome entry is in this group, so a test can find and box it.
const GROUP := &"outcome_entry"

## The order a change matters in: what kills you, what strands you, money,
## what a lab takes, heat.
const ORDER: Array[String] = ["hp", "fuel", "credits", "data", "heat"]
const WORDS := {"hp": "HULL", "fuel": "FUEL", "credits": "CREDITS", "data": "DATA", "heat": "HEAT"}
## The words a thing goes by, ahead of its name.
const THING_WORDS := {&"part": "PART", &"frame": "HULL FRAME",
	&"place": "MARKED", &"material": "", &"item": ""}


# ------------------------------------------------------------------ the changes

## Every change one result made, in the order it matters. Empty when nothing changed.
## Why: docs/why/OutcomeRow.md#change-entries
static func changes(out: Dictionary) -> Array:
	var rows: Array = []
	var bill := {}
	for r in out.get("bill", []):
		bill[String((r as Dictionary).get("key", ""))] = r
	for key in ORDER:
		if not bill.has(key):
			continue
		var r: Dictionary = bill[key]
		var n := int(r.get("n", 0))
		if n == 0:
			continue
		rows.append({key = key, kind = &"stat", n = n, was = int(r.get("was", 0)),
			now = int(r.get("now", 0)), good = bool(r.get("good", n > 0)),
			tone = r.get("tone", UITheme.ICE), big = "%+d" % n, word = String(WORDS[key]),
			name = "", item_tone = UITheme.ICE, cards = [], item = null})
	# THE THINGS, two of one name merged: "+2 EXOTIC TISSUE", not the line twice
	var by := {}
	var things: Array = []
	for raw in out.get("got", []):
		var g: Dictionary = raw
		var id := "%s|%s|%s" % [g.get("kind", &""), g.get("name", ""), g.get("gain", true)]
		if by.has(id):
			(by[id] as Dictionary).n = int((by[id] as Dictionary).n) + (1 if g.get("gain", true) else -1)
			continue
		var gain := bool(g.get("gain", true))
		var kind := StringName(g.get("kind", &"item"))
		var e := {key = String(kind), kind = kind, n = 1 if gain else -1, was = 0, now = 0,
			good = gain, tone = UITheme.GOOD if gain else UITheme.LEAVE,
			big = "", word = String(THING_WORDS.get(kind, "")), name = String(g.get("name", "")),
			item_tone = g.get("tone", UITheme.ICE), cards = g.get("cards", []),
			item = g.get("item", null)}
		by[id] = e
		things.append(e)
	# gains before losses, and in the stats' spirit: a part first
	var rank := {&"part": 0, &"frame": 1, &"material": 2, &"place": 3, &"item": 4}
	things.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.good) != bool(b.good):
			return bool(a.good)
		return int(rank.get(a.kind, 9)) < int(rank.get(b.kind, 9)))
	for e: Dictionary in things:
		# a place has no count; everything else says how many
		e.big = "" if e.kind == &"place" else ("%+d" % int(e.n))
		rows.append(e)
	return rows


## One entry as the line a player reads, and what the tests look for:
## "-5 HULL", "+1 PART: TALON RAILGUN", "MARKED: SIGMA HOLLOW".
static func line_text(e: Dictionary) -> String:
	var words := String(e.word)
	if String(e.name) != "":
		words = (words + ": " + String(e.name)) if words != "" else String(e.name)
	return (String(e.big) + " " + words).strip_edges()


const NOTHING := "NOTHING GAINED OR LOST"


# ------------------------------------------------------------------ the marks

## 7 px marks reuse the HUD's cells (`BoxGauge._cell`, `ChitIcon`) to look like the readout.
## DATA's is a reading's trace in ICE, never the notes' brown: DATA is not money.
const MARK := 7.0

## `px`: how many game px one of the mark's pixels is (2 beside text at
## FS_HEAD, so the mark grows with the words, still in whole pixels).
static func draw_mark(ci: CanvasItem, at: Vector2, e: Dictionary, px: int = 1) -> void:
	var o := at.round()
	var k := String(e.key)
	var r := func(x: int, y: int, w: int, h: int, c: Color) -> void:
		ci.draw_rect(Rect2(o + Vector2(x, y) * px, Vector2(w, h) * px), c, true)
	match k:
		"hp", "heat":
			# the gauge's cell, in the gauge's own colours: hull green (red when
			# it fell), heat ember
			var bg := UITheme.HULL_GREEN
			var hi := UITheme.GOOD
			var lo := Color("#25402f")
			if k == "heat":
				bg = UITheme.EMBER
				hi = UITheme.HOT
				lo = Color("#964214")
			elif not bool(e.good):
				bg = Color("#d64a3a")
				hi = UITheme.FLARE
				lo = Color("#5c280c")
			r.call(1, 0, 5, 7, bg)
			r.call(1, 0, 5, 1, hi)
			r.call(1, 0, 1, 7, hi)
			r.call(1, 6, 5, 1, lo)
			r.call(5, 0, 1, 7, lo)
		"credits":
			var note := Color("#b8894a")
			var ink := Color("#0b0f16")
			r.call(2, 0, 5, 5, note.lerp(ink, 0.45))
			r.call(0, 2, 5, 5, note)
			r.call(0, 2, 5, 1, note.lerp(Color.WHITE, 0.34))
			r.call(1, 4, 3, 1, ink)
		"data":
			# a trace going up, ICE, over the baseline it is read off, COLD
			# (the Lab sheet's e_a mockup, Nov 4, pixel for pixel)
			for p: Vector2i in [Vector2i(5, 0), Vector2i(4, 1), Vector2i(6, 2),
					Vector2i(0, 3), Vector2i(3, 3), Vector2i(1, 4), Vector2i(2, 4)]:
				r.call(p.x, p.y, 1, 1, UITheme.ICE)
			r.call(0, 6, 7, 1, UITheme.COLD)
		"fuel":
			r.call(2, 0, 3, 1, UITheme.CHILL)
			r.call(1, 1, 5, 6, UITheme.CHILL)
			r.call(2, 2, 3, 4, UITheme.COLD)
			r.call(2, 4, 3, 2, UITheme.ICE)
		"part":
			var t: Color = e.item_tone
			r.call(0, 0, 7, 7, t)
			r.call(1, 1, 5, 5, t.darkened(0.55))
			r.call(3, 3, 1, 1, t)
		"material", "item":
			var t2: Color = e.item_tone
			r.call(0, 1, 7, 6, t2.darkened(0.3))
			r.call(0, 1, 7, 1, t2)
			r.call(3, 1, 1, 6, t2.darkened(0.6))
		"place":
			r.call(3, 0, 1, 7, UITheme.ICE)
			r.call(1, 3, 5, 1, UITheme.ICE)
			r.call(2, 2, 3, 3, UITheme.ICE)
		"frame":
			r.call(0, 3, 7, 2, UITheme.CHILL)
			r.call(2, 2, 4, 1, UITheme.ICE)
			r.call(1, 5, 4, 1, UITheme.COLD)


## `text` in lines no wider than `w` px at `fs`, broken at spaces (a word
## longer than the line is cut with ".." as `fit` does).
static func wrap(text: String, fs: int, w: float) -> Array:
	var f := UITheme.pixel_font()
	var lines: Array = []
	var cur := ""
	for word in text.split(" ", false):
		var t := word if cur == "" else cur + " " + word
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w or cur == "":
			cur = t
		else:
			lines.append(cur)
			cur = word
	if cur != "":
		lines.append(cur)
	for i in lines.size():
		lines[i] = fit(String(lines[i]), fs, w)
	return lines


## `text` cut to `w` px at `fs`, ".." where it was cut.
static func fit(text: String, fs: int, w: float) -> String:
	var f := UITheme.pixel_font()
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
		return text
	var t := text
	while t.length() > 1 and f.get_string_size(t + "..", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + ".."


# ------------------------------------------------------------------ D

## The table at its widest at FS_SMALL, game px: past this a name wraps (as
## many characters wide at a bigger size, `Table.max_w`).
const TABLE_MAX_W := 230.0
## Only multiples of 8 stay crisp on the 960x540 grid. Jon turned down 16 (Oct 19, 'size 8').
const D_FS := UITheme.FS_SMALL

## `stats_only` is D's moved stats (the four and DATA), no totals (Jon).
static func table(out: Dictionary, fs: int = UITheme.FS_SMALL, stats_only := false) -> Control:
	var rows := changes(out)
	if stats_only:
		rows = rows.filter(func(e: Dictionary) -> bool: return e.kind == &"stat")
		if rows.is_empty():
			return null
	var t := Table.new()
	t.name = "OutcomeTable"
	t.fs = fs
	t.totals = not stats_only
	t.setup(rows)
	return t


## Change and total right-aligned so digits line up, ending where the buttons end.
## Why: docs/why/OutcomeRow.md#outcome-table
class Table extends Control:
	## A row's height and the columns' gap at FS_SMALL; at a bigger size each
	## scales with it (`px`), so a table at 16 is the one at 8 drawn twice as big.
	const ROW8 := 11.0
	const GAP8 := 6.0
	## The text's size (FS_SMALL; D's is `OutcomeRow.D_FS`), and what one of
	## the 8 px face's pixels is at it.
	var fs := UITheme.FS_SMALL
	var px := 1
	## Whether a stat's row ends on its new total ("HULL -5 31"); D's does
	## not ("HULL -5").
	var totals := true
	var ROW := ROW8
	var GAP := GAP8
	## [y, mark entry or null, [[text, ink, x, right_aligned]], text]
	var rows: Array = []
	var content_w := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_FILL
		add_to_group(OutcomeRow.GROUP)

	func max_w() -> float:
		return OutcomeRow.TABLE_MAX_W * px

	func setup(entries: Array) -> void:
		px = maxi(1, int(float(fs) / UITheme.FS_SMALL))
		ROW = ROW8 * px
		GAP = GAP8 * px
		var f := UITheme.pixel_font()
		var sm := fs
		var sw := func(t: String) -> float: return f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sm).x
		rows.clear()
		if entries.is_empty():
			rows.append([0.0, null, [[OutcomeRow.NOTHING, UITheme.COLD, 0.0, false]], OutcomeRow.NOTHING])
			content_w = ceilf(sw.call(OutcomeRow.NOTHING))
			custom_minimum_size = Vector2(content_w, ROW)
			queue_redraw()
			return
		var name_w := 0.0
		var chg_w := 0.0
		var tot_w := 0.0
		for e: Dictionary in entries:
			if e.kind == &"stat":
				chg_w = maxf(chg_w, sw.call(String(e.big)))
				name_w = maxf(name_w, sw.call(String(e.word)))
				if totals:
					tot_w = maxf(tot_w, sw.call(str(int(e.now))))
		var x_name := (OutcomeRow.MARK + 4.0) * px
		# THE STATS AS A COMPACT BLOCK: name, change, total, the digits lined
		# up; a thing is a line of its own under them, its count leading
		var x_chg := x_name + name_w + GAP + chg_w
		var x_tot := x_chg + GAP + tot_w
		content_w = ceilf(x_tot if tot_w > 0.0 else (x_chg if chg_w > 0.0 else 0.0))
		var y := 0.0
		for e: Dictionary in entries:
			var tone: Color = e.tone
			if e.kind == &"stat":
				var runs: Array = [[String(e.word), UITheme.CHILL, x_name, false], [String(e.big), tone, x_chg, true]]
				if totals:
					runs.append([str(int(e.now)), UITheme.ICE, x_tot, true])
				rows.append([y, e, runs,
					("%s %s %d" % [e.word, e.big, int(e.now)]) if totals else ("%s %s" % [e.word, e.big])])
				y += ROW
				continue
			var lead := String(e.big)
			var x_txt: float = x_name + (sw.call(lead + " ") if lead != "" else 0.0)
			var room: float = max_w() - x_txt
			var first := true
			for ln: String in OutcomeRow.wrap(_thing_name(e), sm, room):
				var runs: Array = [[ln, e.item_tone if int(e.n) > 0 else UITheme.LEAVE, x_txt, false]]
				if first and lead != "":
					runs.append([lead, tone, x_name, false])
				rows.append([y, e if first else null, runs, OutcomeRow.line_text(e) if first else ""])
				content_w = maxf(content_w, ceilf(x_txt + sw.call(ln)))
				first = false
				y += ROW
			if (e.cards as Array).size() > 0:
				for ln: String in OutcomeRow.wrap("CARDS: " + ", ".join(e.cards), sm, room):
					rows.append([y, null, [[ln, UITheme.COLD, x_txt, false]], ""])
					content_w = maxf(content_w, ceilf(x_txt + sw.call(ln)))
					y += ROW
		custom_minimum_size = Vector2(content_w, y)
		queue_redraw()

	## "PART: TARGETING SERVO", "DECK PLATE", "MARKED: SIGMA HOLLOW".
	static func _thing_name(e: Dictionary) -> String:
		var w := String(e.word)
		return (w + ": " + String(e.name)) if w != "" else String(e.name)

	## Where the content starts: against the right edge.
	func _left() -> float:
		return floorf(size.x - content_w)

	func _draw() -> void:
		var f := UITheme.pixel_font()
		var sm := fs
		var base := roundf(f.get_ascent(sm))
		var x0 := _left()
		for row: Array in rows:
			var y := float(row[0])
			if row[1] != null:
				OutcomeRow.draw_mark(self, Vector2(x0, y + base - OutcomeRow.MARK * px), row[1], px)
			for run: Array in row[2]:
				var x := x0 + float(run[2])
				if bool(run[3]):
					x -= f.get_string_size(String(run[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, sm).x
				draw_string(f, Vector2(roundf(x), y + base), String(run[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, sm, run[1] as Color)

	## {rect, text} per drawn row, each its ink's box.
	func entry_boxes() -> Array:
		var f := UITheme.pixel_font()
		var sm := fs
		var outb: Array = []
		var x0 := _left()
		for row: Array in rows:
			var lo := INF
			var hi := 0.0
			if row[1] != null:
				lo = 0.0
			for run: Array in row[2]:
				var w := f.get_string_size(String(run[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, sm).x
				var a := float(run[2]) - (w if bool(run[3]) else 0.0)
				lo = minf(lo, a)
				hi = maxf(hi, a + w)
			outb.append({rect = Rect2(global_position + Vector2(x0 + lo, float(row[0])), Vector2(hi - lo, ROW - 1.0)),
				text = String(row[3]), col = -1, cw = 0.0})
		return outb
