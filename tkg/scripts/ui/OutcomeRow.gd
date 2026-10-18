class_name OutcomeRow
extends RefCounted

## WHAT YOU END UP WITH, at the foot of an event's result on LOCAL
## (`LocalEventDrawer._result`).
##
## Jon, Oct 17, of the Drifting Lifepod's result: "it's kinda hard to read what
## you end up getting at the bottom. It should be more clear." It was four fixed
## pairs -- CREDITS — HEAT — HULL -5 FUEL — -- in the body's 8 px, dim grey,
## a dash for every stat that did not move, the one real change a small red -5
## among them, and the words and numbers on two baselines. Nothing a part, a
## crate, a document or a marked place could say: those had no line at all.
##
## THREE LOOKS, ONE SWITCH (`look`), today's until Jon picks one:
##   A  ONLY WHAT CHANGED, BIG. The dashes go. Each change is the number at
##      FS_HEAD with its word beside it on the same baseline, signed and in its
##      colour ("-5 HULL" red, "+40 CREDITS" green), in the order it matters:
##      hull, fuel, credits, heat, then the things. A part is named in full
##      with the cards it would add to your deck.
##   B  A LEDGER. A small receipt beside the text, GAINED | LOST, each row the
##      stat's mark, its word, the amount and where it leaves you ("HULL -5
##      35 > 30"), so you read where you stand now and not only what moved.
##   D  A LITTLE TABLE ON THE RIGHT (Jon, of the first three: "can we have the
##      results be on the right side right above the reward and continue? Like
##      in a little table?"). Directly above REWARD and CONTINUE, its right edge
##      on theirs and at least their width: a row a change, its mark, its name,
##      the signed change and the new total ("HULL -5 31"), hull, fuel,
##      credits, heat, then the things, a part with its cards under it. The
##      text on the left wraps to stay clear of it; the buttons do not move.
##   C  SHOW IT. Today's size, only what changed, each with its mark; once the
##      text is in, each change flies from the band to the HUD readout it moves
##      (the hull gauge, credits, fuel, heat; a document to ARCHIVE, a place to
##      STARCHART) and that readout flickers as it lands -- and only then does
##      the HUD number change (`held`). A part or a crate makes REWARD flicker
##      on its turn instead: it is on the band already, and a copy sliding
##      along the row would cross the other entries. Nothing that takes a click
##      moves: the readouts and buttons only flicker.
##
## WHAT AN EVENT CAN HAND YOU, all of it read off `OptionResolve.take`: the four
## ledger stats (`bill`), and the things (`got`) -- a part or a material put on
## the system's pile, a hull frame found, a document recovered, a place marked
## on the chart, an item taken out of your hold. No event gives or takes a card
## or a malfunction directly (malfunctions come from fights); a part's cards are
## the only cards an event ever offers, so a part names them.

## The look up now. Jon picks; `-- sheet=OutcomeShot` photographs all four.
static var look: StringName = &"today"
const LOOKS: Array[StringName] = [&"today", &"A", &"B", &"C", &"D"]

## Every drawn outcome entry is in this group, so a test can find and box it.
const GROUP := &"outcome_entry"

## The HUD's numbers, held at what they were until C's flight for them lands
## (`HudBar.refresh` reads this). Empty whenever nothing is flying.
static var held: Dictionary = {}

## The order a change matters in: what kills you, what strands you, money, heat.
const ORDER: Array[String] = ["hp", "fuel", "credits", "heat"]
const WORDS := {"hp": "HULL", "fuel": "FUEL", "credits": "CREDITS", "heat": "HEAT"}
## The words a thing goes by, ahead of its name.
const THING_WORDS := {&"part": "PART", &"frame": "HULL FRAME", &"document": "DOCUMENT",
	&"place": "MARKED", &"material": "", &"item": ""}

## C's flight: how long one takes, the gap between two, the flicker on landing.
const FLY_S := 0.8
const STAGGER_S := 0.14
const FLICKER := [0.07, 0.06, 0.07]


# ------------------------------------------------------------------ the changes

## Every change one result made, in the order it matters, as entries:
##   key    "hp" "fuel" "credits" "heat", or the thing's kind
##   kind   &"stat" or the thing's kind (part, material, frame, document, place, item)
##   n      the move (a stat), or the count (a thing; negative when taken)
##   was    now   a stat's totals either side
##   good   whether it went your way; tone  its colour
##   big    the signed number; word  what it is; name  a thing's name
##   cards  a part's cards, by name
## Empty when nothing changed.
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
			name = "", item_tone = UITheme.ICE, cards = []})
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
			item_tone = g.get("tone", UITheme.ICE), cards = g.get("cards", [])}
		by[id] = e
		things.append(e)
	# gains before losses, and in the stats' spirit: a part first
	var rank := {&"part": 0, &"frame": 1, &"material": 2, &"document": 3, &"place": 4, &"item": 5}
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
## How far under a part's name its cards' line sits, game px.
const CARD_LINE := 10.0


# ------------------------------------------------------------------ A and C

## A's and C's line: only what changed, one entry each, wrapping when it has to.
static func line(out: Dictionary, which: StringName) -> Control:
	var flow := HFlowContainer.new()
	flow.name = "OutcomeLine"
	flow.add_theme_constant_override("h_separation", 18 if which == &"A" else 14)
	flow.add_theme_constant_override("v_separation", 2)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows := changes(out)
	var big := UITheme.FS_HEAD if which == &"A" else UITheme.FS_SMALL
	if rows.is_empty():
		flow.add_child(Chip.new({key = "none", kind = &"none", big = "", word = NOTHING,
			name = "", tone = UITheme.COLD, item_tone = UITheme.COLD, cards = [], n = 0}, big, false))
		return flow
	for e: Dictionary in rows:
		flow.add_child(Chip.new(e, big, which == &"C"))
	return flow


## One change, drawn: the signed number, then its word and name on the same
## baseline (Jon's screenshot had the words and numbers on two), a part's cards
## after it. Drawn rather than built from Labels so the baseline is one number
## and the box is exactly the ink's.
class Chip extends Control:
	var e: Dictionary
	var big_fs := 16
	var mark := false
	## [text, size, ink, x] for each run of text, and the baseline.
	var runs: Array = []
	var base := 0.0

	func _init(entry: Dictionary, fs: int, with_mark: bool) -> void:
		e = entry
		big_fs = fs
		mark = with_mark and entry.kind != &"none"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_to_group(OutcomeRow.GROUP)
		set_meta(&"outcome_text", OutcomeRow.line_text(e) if e.kind != &"none" else OutcomeRow.NOTHING)
		_lay()

	func _lay() -> void:
		var f := UITheme.pixel_font()
		var sm := UITheme.FS_SMALL
		runs.clear()
		var x := 0.0
		if mark:
			x += OutcomeRow.MARK + 4.0
		var tone: Color = e.tone
		if String(e.big) != "":
			runs.append([String(e.big), big_fs, tone, x])
			x += f.get_string_size(String(e.big), HORIZONTAL_ALIGNMENT_LEFT, -1, big_fs).x + (5.0 if big_fs > sm else 4.0)
		var text_x := x
		var word := String(e.word)
		if word != "":
			var w := word + (":" if String(e.name) != "" else "")
			# a stat's word wears its change's colour; a thing's kind is quieter
			runs.append([w, sm, tone if e.kind == &"stat" else UITheme.CHILL, x])
			x += f.get_string_size(w + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, sm).x
		if String(e.name) != "":
			runs.append([String(e.name), sm, e.item_tone, x])
			x += f.get_string_size(String(e.name), HORIZONTAL_ALIGNMENT_LEFT, -1, sm).x
		var extra := 0.0
		if (e.cards as Array).size() > 0:
			# A PART'S CARDS ON A LINE UNDER ITS NAME, so the entry is as wide as
			# the longer of the two and not the two end to end
			var c := "CARDS: " + ", ".join(e.cards)
			runs.append([c, sm, UITheme.CHILL, text_x, OutcomeRow.CARD_LINE])
			x = maxf(x, text_x + f.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, sm).x)
			extra = OutcomeRow.CARD_LINE
		if e.kind == &"none":
			runs.append([OutcomeRow.NOTHING, sm, UITheme.COLD, x])
			x += f.get_string_size(OutcomeRow.NOTHING, HORIZONTAL_ALIGNMENT_LEFT, -1, sm).x
		var top := maxi(big_fs, sm) if String(e.big) != "" else sm
		base = roundf(f.get_ascent(top))
		custom_minimum_size = Vector2(ceilf(x), ceilf(maxf(f.get_height(top), base + extra + f.get_descent(sm))))

	func _draw() -> void:
		var f := UITheme.pixel_font()
		for r: Array in runs:
			var dy := float(r[4]) if r.size() > 4 else 0.0
			draw_string(f, Vector2(float(r[3]), base + dy), String(r[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(r[1]), r[2] as Color)
		if mark:
			OutcomeRow.draw_mark(self, Vector2(0.0, base - OutcomeRow.MARK), e)

	## Where the number is, global: where C's flight takes off from.
	func launch_point() -> Vector2:
		return global_position + Vector2(0.0, base - OutcomeRow.MARK)

	## {rect, text}: the box test's view of this entry.
	func entry_boxes() -> Array:
		return [{rect = get_global_rect(), text = String(get_meta(&"outcome_text"))}]


# ------------------------------------------------------------------ the marks

## A stat's mark, 7 px: the same cell the HUD's hull and heat gauges are made of
## (`BoxGauge._cell`), the stacked notes credits are drawn as everywhere
## (`ChitIcon`), a tank for fuel; for a thing, a plate in its grade's colour.
const MARK := 7.0

static func draw_mark(ci: CanvasItem, at: Vector2, e: Dictionary) -> void:
	var o := at.round()
	var k := String(e.key)
	var r := func(x: int, y: int, w: int, h: int, c: Color) -> void:
		ci.draw_rect(Rect2(o + Vector2(x, y), Vector2(w, h)), c, true)
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
		"document":
			r.call(1, 0, 5, 7, UITheme.ICE)
			r.call(2, 2, 3, 1, UITheme.COLD)
			r.call(2, 4, 3, 1, UITheme.COLD)
		"place":
			r.call(3, 0, 1, 7, UITheme.ICE)
			r.call(1, 3, 5, 1, UITheme.ICE)
			r.call(2, 2, 3, 3, UITheme.ICE)
		"frame":
			r.call(0, 3, 7, 2, UITheme.CHILL)
			r.call(2, 2, 4, 1, UITheme.ICE)
			r.call(1, 5, 4, 1, UITheme.COLD)


# ------------------------------------------------------------------ B

## B's receipt: GAINED | LOST, `w` wide.
static func ledger(out: Dictionary, w: float) -> Control:
	var l := Ledger.new()
	l.name = "OutcomeLedger"
	l.setup(changes(out), w)
	return l


## A small receipt, drawn: two columns, a heading each, a row a change. A stat
## row is its mark, its word, the amount and the totals either side ("35 > 30",
## the arrow drawn: the face has none); a thing row is its mark and its name, a
## part's cards on a quieter row under it. Long names are cut to the column
## with "..": the column's edge is the box, and nothing crosses it.
class Ledger extends Control:
	const ROW := 11.0
	const HEAD := 12.0
	const GAP := 12.0
	var cols: Array = [[], []]
	var w := 300.0
	## Each drawn row: [col, y, mark_e or null, [runs], text, indent]
	var rows: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	func setup(entries: Array, width: float) -> void:
		w = width
		cols = [[], []]
		for e: Dictionary in entries:
			# GAINED and LOST are said literally: eight heat came aboard, so it
			# is gained, in the heat's warning colour
			var up := int(e.n) > 0
			(cols[0 if up else 1] as Array).append(e)
		_lay()

	func col_w() -> float:
		return floorf((w - GAP) * 0.5)

	func _lay() -> void:
		var f := UITheme.pixel_font()
		var sm := UITheme.FS_SMALL
		rows.clear()
		var cw := col_w()
		var tallest := 0.0
		if (cols[0] as Array).is_empty() and (cols[1] as Array).is_empty():
			# one line across the receipt (column -1: both)
			rows.append([-1, 0.0, null, [[OutcomeRow.NOTHING, UITheme.COLD, 0.0]], OutcomeRow.NOTHING, 0.0])
			custom_minimum_size = Vector2(w, ROW)
			queue_redraw()
			return
		for ci in 2:
			var list: Array = cols[ci]
			# the stat rows' columns line up within a receipt column
			var word_w := 0.0
			var amt_w := 0.0
			for e: Dictionary in list:
				if e.kind == &"stat":
					word_w = maxf(word_w, f.get_string_size(String(e.word), HORIZONTAL_ALIGNMENT_LEFT, -1, sm).x)
					amt_w = maxf(amt_w, f.get_string_size(String(e.big), HORIZONTAL_ALIGNMENT_LEFT, -1, sm).x)
			var y := HEAD
			if list.is_empty():
				rows.append([ci, y, null, [["NOTHING", UITheme.COLD, 0.0]], "NOTHING", 0.0])
				y += ROW
			for e: Dictionary in list:
				var x0 := OutcomeRow.MARK + 4.0
				if e.kind == &"stat":
					var tone: Color = e.tone
					var amt := String(e.big)
					var ax := x0 + word_w + 6.0 + amt_w - f.get_string_size(amt, HORIZONTAL_ALIGNMENT_LEFT, -1, sm).x
					var tx := x0 + word_w + 6.0 + amt_w + 8.0
					var was_s := str(int(e.was))
					var now_s := str(int(e.now))
					var nx := tx + f.get_string_size(was_s, HORIZONTAL_ALIGNMENT_LEFT, -1, sm).x + 9.0
					rows.append([ci, y, e, [[String(e.word), UITheme.CHILL, x0], [amt, tone, ax],
						[was_s, UITheme.COLD, tx], [">", null, tx + f.get_string_size(was_s, HORIZONTAL_ALIGNMENT_LEFT, -1, sm).x + 2.0],
						[now_s, UITheme.ICE, nx]],
						"%s %s %s > %s" % [e.word, amt, was_s, now_s], 0.0])
				else:
					# NAMED IN FULL, wrapped to the column rather than cut
					var label := OutcomeRow.line_text(e)
					var ink: Color = e.item_tone if int(e.n) > 0 else UITheme.LEAVE
					var first := true
					for ln: String in OutcomeRow.wrap(label, sm, cw - x0):
						rows.append([ci, y, e if first else null, [[ln, ink, x0]], label if first else "", 0.0 if first else x0])
						first = false
						y += ROW
					if (e.cards as Array).size() > 0:
						for ln: String in OutcomeRow.wrap("CARDS: " + ", ".join(e.cards), sm, cw - x0):
							rows.append([ci, y, null, [[ln, UITheme.COLD, x0]], "", x0])
							y += ROW
					continue
				y += ROW
			tallest = maxf(tallest, y)
		custom_minimum_size = Vector2(w, tallest)
		queue_redraw()

	func _draw() -> void:
		var f := UITheme.pixel_font()
		var sm := UITheme.FS_SMALL
		var base := roundf(f.get_ascent(sm))
		var cw := col_w()
		var lone := (cols[0] as Array).is_empty() and (cols[1] as Array).is_empty()
		if not lone:
			draw_string(f, Vector2(0, base), "GAINED", HORIZONTAL_ALIGNMENT_LEFT, -1, sm, UITheme.GOOD)
			draw_string(f, Vector2(cw + GAP, base), "LOST", HORIZONTAL_ALIGNMENT_LEFT, -1, sm, UITheme.LEAVE)
			# the rule under the headings, and the one between the columns
			draw_rect(Rect2(0, HEAD - 3.0, w, 1), UITheme.LINE, true)
			draw_rect(Rect2(cw + floorf(GAP * 0.5), HEAD - 1.0, 1, size.y - HEAD + 1.0), UITheme.LINE, true)
		for row: Array in rows:
			var x := 0.0 if int(row[0]) <= 0 else cw + GAP
			var y := float(row[1])
			if row[2] != null:
				OutcomeRow.draw_mark(self, Vector2(x, y + base - OutcomeRow.MARK), row[2])
			for run: Array in row[3]:
				if String(run[0]) == ">" and run[1] == null:
					_arrow(Vector2(x + float(run[2]), y + base))
					continue
				draw_string(f, Vector2(x + float(run[2]), y + base), String(run[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, sm, run[1] as Color)

	## A small arrow, pointing on to the new total. Five pixels.
	func _arrow(at: Vector2) -> void:
		var o := at.round() + Vector2(0, -5)
		draw_rect(Rect2(o + Vector2(0, 2), Vector2(4, 1)), UITheme.COLD, true)
		draw_rect(Rect2(o + Vector2(3, 1), Vector2(1, 3)), UITheme.COLD, true)
		draw_rect(Rect2(o + Vector2(4, 2), Vector2(1, 1)), UITheme.COLD, true)
		draw_rect(Rect2(o + Vector2(2, 0), Vector2(1, 1)), UITheme.COLD, true)
		draw_rect(Rect2(o + Vector2(2, 4), Vector2(1, 1)), UITheme.COLD, true)

	## {rect, text} per drawn row: the box test's view, each row its own ink's box.
	func entry_boxes() -> Array:
		var f := UITheme.pixel_font()
		var sm := UITheme.FS_SMALL
		var outb: Array = []
		var cw := col_w()
		for row: Array in rows:
			var x := 0.0 if int(row[0]) <= 0 else cw + GAP
			var right := 0.0
			for run: Array in row[3]:
				var tw := 5.0 if run[1] == null else f.get_string_size(String(run[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, sm).x
				right = maxf(right, float(run[2]) + tw)
			var r := Rect2(global_position + Vector2(x, float(row[1])), Vector2(right, ROW - 1.0))
			outb.append({rect = r, text = String(row[4]), col = int(row[0]), cw = cw})
		return outb

	func _enter_tree() -> void:
		add_to_group(OutcomeRow.GROUP)


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

## D's table at its widest, game px: past this a name wraps.
const TABLE_MAX_W := 230.0

static func table(out: Dictionary) -> Control:
	var t := Table.new()
	t.name = "OutcomeTable"
	t.setup(changes(out))
	return t


## A small table, drawn: mark | name | change | total, a row a stat, the
## change and the total right-aligned in their columns so the digits line up.
## The things after, a line each with their count leading ("+1 PART: ..."),
## wrapped to TABLE_MAX_W, a part's cards under it in the quiet grey. As wide
## as it needs and drawn against its right edge, so stretched to the buttons'
## width it still ends where they end.
class Table extends Control:
	const ROW := 11.0
	const GAP := 6.0
	## [y, mark entry or null, [[text, ink, x, right_aligned]], text]
	var rows: Array = []
	var content_w := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_FILL
		add_to_group(OutcomeRow.GROUP)

	func setup(entries: Array) -> void:
		var f := UITheme.pixel_font()
		var sm := UITheme.FS_SMALL
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
				tot_w = maxf(tot_w, sw.call(str(int(e.now))))
		var x_name := OutcomeRow.MARK + 4.0
		# THE STATS AS A COMPACT BLOCK: name, change, total, the digits lined
		# up; a thing is a line of its own under them, its count leading
		var x_chg := x_name + name_w + GAP + chg_w
		var x_tot := x_chg + GAP + tot_w
		content_w = ceilf(x_tot if tot_w > 0.0 else 0.0)
		var y := 0.0
		for e: Dictionary in entries:
			var tone: Color = e.tone
			if e.kind == &"stat":
				rows.append([y, e, [[String(e.word), UITheme.CHILL, x_name, false],
					[String(e.big), tone, x_chg, true], [str(int(e.now)), UITheme.ICE, x_tot, true]],
					"%s %s %d" % [e.word, e.big, int(e.now)]])
				y += ROW
				continue
			var lead := String(e.big)
			var x_txt: float = x_name + (sw.call(lead + " ") if lead != "" else 0.0)
			var room: float = OutcomeRow.TABLE_MAX_W - x_txt
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
		var sm := UITheme.FS_SMALL
		var base := roundf(f.get_ascent(sm))
		var x0 := _left()
		for row: Array in rows:
			var y := float(row[0])
			if row[1] != null:
				OutcomeRow.draw_mark(self, Vector2(x0, y + base - OutcomeRow.MARK), row[1])
			for run: Array in row[2]:
				var x := x0 + float(run[2])
				if bool(run[3]):
					x -= f.get_string_size(String(run[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, sm).x
				draw_string(f, Vector2(roundf(x), y + base), String(run[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, sm, run[1] as Color)

	## {rect, text} per drawn row, each its ink's box.
	func entry_boxes() -> Array:
		var f := UITheme.pixel_font()
		var sm := UITheme.FS_SMALL
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


# ------------------------------------------------------------------ C's flight

## C, as the result comes up: the HUD's numbers held at what they were, so the
## flights can change them. Only once a result (`out.flown`), only when things
## animate and motion is not reduced.
static func hold(d: LocalEventDrawer) -> void:
	if look != &"C" or d.out.get("flown", false) or not _animating(d):
		return
	for e: Dictionary in changes(d.out):
		if e.kind == &"stat":
			held[String(e.key)] = int(e.was)
	_hud_refresh()


## C, once the text is in: every change in the band takes off for the readout
## it moves. Reduced motion: no flight, the readouts change and flicker at once.
static func fly(d: LocalEventDrawer) -> void:
	if look != &"C" or d.out.get("flown", false) or d.panel == null:
		return
	d.out["flown"] = true
	# any old flight landed, but what `hold` is holding stays held: these
	# flights are what let it go
	settle(d, false)
	var fl := Flight.new()
	fl.name = "OutcomeFlight"
	d.add_child(fl)
	var t := GameClock.now() + 0.05
	var calm := DisplaySettings.reduced_motion or not _animating(d)
	for c in d.panel.find_children("*", "Control", true, false):
		if not (c is Chip):
			continue
		var chip := c as Chip
		var to := _targets(d, chip.e)
		if to.is_empty():
			# nothing to fly to: whatever it holds, it is not held any more
			fl.land_key(String(chip.e.key))
			continue
		fl.add(chip, to, t, calm)
		if not calm:
			t += STAGGER_S
	if fl.flights.is_empty():
		fl.queue_free()


## Every flight landed now, every flicker over, every held number let go.
static func settle(d: Node, release := true) -> void:
	if d != null:
		for c in d.get_children():
			if c is Flight:
				(c as Flight).finish()
				c.queue_free()
	if release and not held.is_empty():
		held.clear()
		_hud_refresh()


static func _animating(d: Node) -> bool:
	return Router.animating() and d.is_inside_tree()


static func _hud_refresh() -> void:
	if Router.hud != null and is_instance_valid(Router.hud):
		Router.hud.refresh()


## What a change flies to: the HUD readout for a stat, REWARD for what is on
## the pile, ARCHIVE for a document, STARCHART for a marked place.
static func _targets(d: LocalEventDrawer, e: Dictionary) -> Array:
	var hud: HudBar = Router.hud if Router.hud != null and is_instance_valid(Router.hud) and Router.hud.is_visible_in_tree() else null
	match String(e.key):
		"hp", "heat", "credits", "fuel":
			return hud.stat_nodes(String(e.key)) if hud != null else []
		"part", "material":
			if int(e.n) > 0:
				var rw := d.find_child("Reward", true, false)
				return [rw] if rw != null else []
		"document":
			return hud.tab_nodes(&"archive") if hud != null else []
		"place":
			return hud.tab_nodes(&"chart") if hud != null else []
	return []


## C's flights and flickers, on the game's clock (`GameClock`): each change a
## copy of its mark and number travelling from the band to its readout, eased
## at both ends, in whole pixels; the readout flickering as it lands.
class Flight extends Control:
	## {e, from, to (Array of Control), t0, landed}
	var flights: Array = []
	## {nodes, t0}
	var flickers: Array = []
	## Each flickered node's own modulate, by instance id.
	var _orig: Dictionary = {}

	func _init() -> void:
		top_level = true
		z_index = 100
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		position = Vector2.ZERO

	func add(chip: Chip, to: Array, t0: float, calm: bool) -> void:
		# A TARGET ON THE BAND ITSELF (REWARD) IS NOT FLOWN TO: the copy would
		# slide along the row over the other entries. It flickers on its turn.
		var near := false
		for n in to:
			if n is Control and get_parent() != null and get_parent().is_ancestor_of(n):
				near = true
		flights.append({e = chip.e, from = chip.launch_point(), to = to, t0 = t0, landed = false, calm = calm, still = near})
		if calm:
			_land(flights[flights.size() - 1], t0)

	func _process(_dt: float) -> void:
		var now := GameClock.now()
		for f: Dictionary in flights:
			if not f.landed and now >= float(f.t0) + OutcomeRow.FLY_S:
				_land(f, now)
		_flicker(now)
		queue_redraw()
		var busy := flickers.size() > 0
		for f: Dictionary in flights:
			busy = busy or not f.landed
		if not busy:
			set_process(false)

	func _target_point(f: Dictionary) -> Vector2:
		var r := Rect2()
		for n in f.to:
			if is_instance_valid(n):
				var g := (n as Control).get_global_rect()
				r = g if r.size == Vector2.ZERO else r.merge(g)
		return r.get_center()

	func land_key(key: String) -> void:
		if OutcomeRow.held.has(key):
			OutcomeRow.held.erase(key)
			OutcomeRow._hud_refresh()

	func _land(f: Dictionary, now: float) -> void:
		if f.landed:
			return
		f.landed = true
		land_key(String(f.e.key))
		var live: Array = []
		for n in f.to:
			if is_instance_valid(n):
				live.append(n)
				# what it looked like before ANY flicker: two landings on one
				# readout must not take the first one's bright frame for its own
				if not _orig.has(n.get_instance_id()):
					_orig[n.get_instance_id()] = (n as CanvasItem).modulate
		flickers.append({nodes = live, t0 = now})

	## On, off, on, then as it was: a flicker, never a move.
	func _flicker(now: float) -> void:
		var keep: Array = []
		for k: Dictionary in flickers:
			var u := now - float(k.t0)
			var on := u < OutcomeRow.FLICKER[0] or (u >= OutcomeRow.FLICKER[0] + OutcomeRow.FLICKER[1] \
				and u < OutcomeRow.FLICKER[0] + OutcomeRow.FLICKER[1] + OutcomeRow.FLICKER[2])
			var over := u >= OutcomeRow.FLICKER[0] + OutcomeRow.FLICKER[1] + OutcomeRow.FLICKER[2]
			for i in (k.nodes as Array).size():
				var n: CanvasItem = k.nodes[i]
				if not is_instance_valid(n):
					continue
				var base: Color = _orig.get(n.get_instance_id(), Color.WHITE)
				n.modulate = base if (over or not on) else Color(base.r * 1.8, base.g * 1.8, base.b * 1.8, base.a)
			if not over:
				keep.append(k)
		flickers = keep

	## Everything landed and every readout as it was.
	func finish() -> void:
		for f: Dictionary in flights:
			if not f.landed:
				f.landed = true
				land_key(String(f.e.key))
		for k: Dictionary in flickers:
			for n in k.nodes:
				if is_instance_valid(n):
					(n as CanvasItem).modulate = _orig.get(n.get_instance_id(), Color.WHITE)
		flickers.clear()
		set_process(false)
		queue_redraw()

	func _exit_tree() -> void:
		finish()

	## What is in the air now: [{e, at}] global, for the film's boxes.
	func in_air() -> Array:
		var outa: Array = []
		var now := GameClock.now()
		for f: Dictionary in flights:
			if f.landed or f.still or now < float(f.t0):
				continue
			var u := clampf((now - float(f.t0)) / OutcomeRow.FLY_S, 0.0, 1.0)
			var k := 0.5 - 0.5 * cos(PI * u)
			outa.append({e = f.e, at = (f.from as Vector2).lerp(_target_point(f), k).round()})
		return outa

	func _draw() -> void:
		var font := UITheme.pixel_font()
		var sm := UITheme.FS_SMALL
		var base := roundf(font.get_ascent(sm))
		var dark := Color("#05070b")
		for a: Dictionary in in_air():
			var e: Dictionary = a.e
			var p: Vector2 = a.at - global_position
			var txt := String(e.big)
			# a dark ring round the number, so it reads over the sky and the HUD
			for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				draw_string(font, p + off + Vector2(OutcomeRow.MARK + 3.0, base), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sm, dark)
			draw_rect(Rect2(p + Vector2(-1, base - OutcomeRow.MARK - 1.0), Vector2(OutcomeRow.MARK + 2.0, OutcomeRow.MARK + 2.0)), dark, true)
			OutcomeRow.draw_mark(self, p + Vector2(0, base - OutcomeRow.MARK), e)
			draw_string(font, p + Vector2(OutcomeRow.MARK + 3.0, base), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sm, e.tone as Color)
