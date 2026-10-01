class_name BoardWhite
extends RefCounted
## WHAT IS DRAWN ON A SETTLEMENT'S WHITEBOARD, in marker, by hand. A pool to pick
## from (Jon: "Not 20X on the board, just a big pool to pick from for
## diversity"): `PostingBoard` takes a few of these per station, by the
## station's number, and puts them where it likes around the work.
##
## Every drawing is drawn in its own box, `size_of(i)` from (0, 0), with
## `PostingBoard`'s marker helpers -- `_hand` for words, `_wobble_line`,
## `_wobble_rect` and `_wobble_circle` for strokes -- so the lines bow and
## overshoot the way the rest of the board's do. Nothing here may shimmer: the
## wobble is seeded by the drawing's own number.
##
## The first eight are drawn one by one, below. The rest are rows of `MORE`:
## each names a kind of scribble (a list, a tally, a hangman game, a pie chart)
## and what is written in it, and `_paint` draws it. The handwriting knows
## A-Z, 0-9 and ! : - + Q ? . , ' / = # ( ) and nothing else, so every word in
## the table is upper case and keeps to those.

const BLACK := Color("#2a2a30")
const RED := Color("#b0302a")
const BLUE := Color("#2a4aa0")
const GREEN := Color("#2a7a4a")


static func count() -> int:
	return SIZES.size() + MORE.size()


## Each drawing's box, in board pixels.
const SIZES := [
	Vector2(128, 72),   # 0 days since last incident
	Vector2(120, 76),   # 1 chores
	Vector2(128, 60),   # 2 ship going ZOOM
	Vector2(128, 64),   # 3 DO NOT ERASE
	Vector2(106, 46),   # 4 smiley, call Tik
	Vector2(78, 78),    # 5 noughts and crosses
	Vector2(140, 104),  # 6 meeting
	Vector2(60, 60),    # 7 initials in a heart
]


static func size_of(i: int) -> Vector2:
	if i < SIZES.size():
		return SIZES[i]
	return _size(MORE[(i - SIZES.size()) % MORE.size()])


static func draw(b: PostingBoard, i: int) -> void:
	if i >= SIZES.size():
		_paint(b, MORE[(i - SIZES.size()) % MORE.size()], float(i) * 31.7 + 5.3, size_of(i))
		return
	var sd := float(i) * 13.7 + 3.1
	match i:
		0:
			var p := Vector2(2, 2)
			b._hand("DAYS SINCE LAST", p + Vector2(0, 10), BLACK, sd)
			b._hand("INCIDENT:", p + Vector2(2, 23), BLACK, sd + 4.0)
			# the old counts, each struck out when it went back to nought, in the
			# order they were written, up to the one in the box now
			var x := p.x + 2.0
			for k in 3:
				var o := str(12 - k * 4)
				var at := Vector2(x, p.y + 50.0)
				b._hand(o, at, BLUE, sd + float(k))
				var ow := 8.0 * float(o.length())
				b._wobble_line(at + Vector2(-2, -4), at + Vector2(ow + 2.0, -5), BLUE, sd + 9.0 + float(k))
				x += ow + 10.0
			b._wobble_rect(Rect2(x + 2.0, p.y + 31.0, 38.0, 30.0), RED, sd + 1.0)
			b._hand("0", Vector2(x + 14.0, p.y + 54.0), RED, sd + 2.0, UITheme.FS_HEAD)
		1:
			var p := Vector2(2, 2)
			b._hand("CHORES", p + Vector2(0, 10), BLUE, sd)
			b._wobble_line(p + Vector2(0, 13), p + Vector2(40, 12), BLUE, sd + 1.0)
			var names := ["JO", "MAX", "TIK", "REN"]
			var gx := p.x + 32.0
			var gy := p.y + 17.0
			# the grid, ruled by eye
			for row in 5:
				b._wobble_line(Vector2(gx, gy + float(row) * 12.0), Vector2(gx + 74.0, gy + float(row) * 12.0 + 1.0), BLACK, sd + float(row) * 2.1)
			for col in 5:
				b._wobble_line(Vector2(gx + float(col) * 18.0, gy), Vector2(gx + float(col) * 18.0 + 1.0, gy + 48.0), BLACK, sd + 30.0 + float(col))
			for k in names.size():
				b._hand(names[k], Vector2(p.x, gy + 10.0 + float(k) * 12.0), BLACK, sd + 40.0 + float(k))
				for c in 4:
					if (k + c * 3) % 4 == 0:
						# a tick, scrawled
						var cc := Vector2(gx + 5.0 + float(c) * 18.0, gy + 6.0 + float(k) * 12.0)
						b._wobble_line(cc, cc + Vector2(3, 3), RED, sd + 50.0 + float(k * 4 + c))
						b._wobble_line(cc + Vector2(3, 3), cc + Vector2(9, -4), RED, sd + 60.0 + float(k * 4 + c))
		2:
			# a ship, doodled, with a speech bubble
			var c := Vector2(64, 48)
			b._wobble_rect(Rect2(c.x - 30.0, c.y - 5.0, 56.0, 11.0), BLUE, sd)
			b._wobble_line(c + Vector2(26, -5), c + Vector2(36, 0), BLUE, sd + 1.0)
			b._wobble_line(c + Vector2(36, 0), c + Vector2(26, 6), BLUE, sd + 2.0)
			b._wobble_rect(Rect2(c.x - 10.0, c.y - 13.0, 16.0, 8.0), BLUE, sd + 3.0)
			for k in 3:
				b._wobble_line(c + Vector2(-36.0 - float(k) * 3.0, -3.0 + float(k) * 3.0),
					c + Vector2(-48.0 - float(k) * 5.0, -3.0 + float(k) * 3.0), RED, sd + 4.0 + float(k))
			# the bubble, and its tail
			b._wobble_rect(Rect2(c.x + 12.0, c.y - 42.0, 48.0, 18.0), BLACK, sd + 8.0)
			b._wobble_line(c + Vector2(20, -24), c + Vector2(14, -14), BLACK, sd + 9.0)
			b._hand("ZOOM", c + Vector2(20, -28), BLACK, sd + 10.0)
		3:
			var p := Vector2(2, 2)
			b._wobble_rect(Rect2(p.x + 2.0, p.y + 4.0, 114.0, 34.0), RED, sd)
			b._hand("DO NOT", p + Vector2(10, 18), RED, sd + 1.0)
			b._hand("ERASE!!", p + Vector2(10, 31), RED, sd + 2.0)
			b._hand("- MGMT", p + Vector2(58, 52), BLACK, sd + 3.0)
			# somebody erased half of it anyway: a wiped streak over the corner
			var w := PostingBoard.WHITE
			for k in 7:
				b.draw_rect(Rect2(p.x + 62.0 + float(k % 2) * 3.0, p.y + 2.0 + float(k) * 6.0, 52.0, 6.0),
					Color(w.r, w.g, w.b, 0.78))
		4:
			# a smiley that does not quite close, and a number
			var c2 := Vector2(20, 22)
			b._wobble_circle(c2, 16.0, BLACK, sd)
			b._wobble_line(c2 + Vector2(-6, -7), c2 + Vector2(-5, -3), BLACK, sd + 1.0)
			b._wobble_line(c2 + Vector2(5, -7), c2 + Vector2(6, -3), BLACK, sd + 2.0)
			var prev := c2 + Vector2(-9, 3)
			for a2 in 6:
				var ang := 0.4 + float(a2 + 1) / 6.0 * 2.3
				var nxt := c2 + Vector2(cos(ang), sin(ang)) * 9.0
				b._wobble_line(prev, nxt, BLACK, sd + 3.0 + float(a2))
				prev = nxt
			b._hand("CALL TIK", c2 + Vector2(26, -2), BLUE, sd + 10.0)
			b._hand("4-1170", c2 + Vector2(28, 11), BLUE, sd + 11.0)
			b._wobble_line(c2 + Vector2(26, 14), c2 + Vector2(70, 15), BLUE, sd + 12.0)
		5:
			# noughts and crosses, somebody winning
			var o := Vector2(8, 8)
			for k in 2:
				b._wobble_line(o + Vector2(20.0 + float(k) * 20.0, 0), o + Vector2(21.0 + float(k) * 20.0, 60), BLACK, sd + float(k))
				b._wobble_line(o + Vector2(0, 20.0 + float(k) * 20.0), o + Vector2(60, 21.0 + float(k) * 20.0), BLACK, sd + 5.0 + float(k))
			for cell: Vector2 in [Vector2(0, 0), Vector2(1, 1), Vector2(2, 2)]:
				var cc := o + cell * 20.0 + Vector2(4, 4)
				b._wobble_line(cc, cc + Vector2(11, 11), RED, sd + 10.0 + cell.x)
				b._wobble_line(cc + Vector2(11, 0), cc + Vector2(0, 11), RED, sd + 20.0 + cell.x)
			for cell2: Vector2 in [Vector2(2, 0), Vector2(0, 2)]:
				b._wobble_circle(o + cell2 * 20.0 + Vector2(10, 10), 6.0, BLUE, sd + 30.0 + cell2.x)
			b._wobble_line(o + Vector2(-2, -2), o + Vector2(62, 62), RED, sd + 40.0)
		6:
			var p := Vector2(0, 0)
			b._hand("MEETING", p + Vector2(4, 16), BLACK, sd)
			b._hand("TUES 0900", p + Vector2(8, 30), BLACK, sd + 1.0)
			b._wobble_line(p + Vector2(4, 34), p + Vector2(70, 35), RED, sd + 2.0)
			# an arrow, pointing at nothing in particular
			b._wobble_line(p + Vector2(70, 50), p + Vector2(30, 80), BLUE, sd + 3.0)
			b._wobble_line(p + Vector2(30, 80), p + Vector2(42, 79), BLUE, sd + 4.0)
			b._wobble_line(p + Vector2(30, 80), p + Vector2(33, 68), BLUE, sd + 5.0)
			b._hand("BRING SNACKS", p + Vector2(40, 94), BLUE, sd + 6.0)
		7:
			# initials in a heart
			var hc := Vector2(30, 30)
			var prev := Vector2.ZERO
			for k in 25:
				var t := float(k) / 24.0 * TAU
				var hx := 16.0 * pow(sin(t), 3.0)
				var hy := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				var pt := hc + Vector2(hx, hy) * 1.6
				if k > 0:
					b.draw_line(prev.round(), pt.round(), RED, 2.0)
				prev = pt
			b._hand("J+M", hc + Vector2(-12, 2), RED, sd + 1.0)


# ---------------------------------------------------------------------------
# THE REST OF THE POOL, as rows: who scribbles on a hiring hall's board is
# crew, dock hands, haulers and the people who live there, so it is lists and
# games and grudges and doodles, not notices. `k` is the kind; the other keys
# are what that kind needs. A row with no `s` sizes itself from its words.
# ---------------------------------------------------------------------------

const MORE := [
	# -- lists: a title, the items, which are done, and how they are marked
	{"k": "list", "t": "SHOPPING", "it": ["FUSES", "TAPE", "SOAP", "MORE TAPE"], "x": [0, 2], "m": "strike", "c": BLUE, "ic": BLACK, "xc": RED},
	{"k": "list", "t": "TO DO", "it": ["FIX LIFT", "FEED KEVIN", "CALL MUM", "SLEEP"], "x": [1, 2], "m": "box", "c": BLACK, "ic": BLACK, "xc": GREEN},
	{"k": "list", "t": "LOST + FOUND", "it": ["1 BOOT (LEFT)", "RED MUG", "9MM SPANNER", "FALSE TEETH?"], "x": [1], "m": "dash", "c": RED, "ic": BLUE, "xc": RED},
	{"k": "list", "t": "TIK'S STEW", "it": ["2 CANS BEANS", "1 CAN MORE BEANS", "SALT", "HOPE"], "x": [], "m": "num", "c": GREEN, "ic": BLACK},
	{"k": "list", "t": "PACK FOR LEAVE", "it": ["SOCKS", "TOOTHBRUSH", "MORE SOCKS", "A SMILE"], "x": [0, 1, 2], "m": "tick", "c": BLUE, "ic": BLUE, "xc": GREEN},
	{"k": "list", "t": "BAND NAMES", "it": ["THE HEAT SINKS", "COLD START", "DOCK FIVE", "THREE KELVIN"], "x": [1], "m": "dash", "c": BLACK, "ic": BLUE, "xc": RED},
	{"k": "list", "t": "NAMES FOR THE DRONE", "it": ["BOLT", "SPARKY", "BEEPS", "KEVIN 2"], "x": [0, 1], "m": "strike", "c": GREEN, "ic": BLACK, "xc": RED},
	{"k": "list", "t": "DO NOT FEED", "it": ["THE CAT", "THE DRONE", "TIK"], "x": [], "m": "dash", "c": RED, "ic": RED},
	{"k": "list", "t": "WHY STAY?", "it": ["THE VIEW", "HOT WATER (SOME)", "FRIENDS"], "x": [0, 2], "m": "tick", "c": BLACK, "ic": BLACK, "xc": RED},
	{"k": "list", "t": "SNACK ORDER", "it": ["JO - NOODLES", "MAX - NOODLES", "REN - SOUP", "TIK - ALL OF IT"], "x": [3], "m": "strike", "c": BLUE, "ic": BLACK, "xc": RED},
	{"k": "list", "t": "BEFORE YOU DOCK", "it": ["VENT HEAT", "CHECK SEALS", "WAVE AT DOCK 3"], "x": [0, 1], "m": "box", "c": GREEN, "ic": BLACK, "xc": GREEN},
	{"k": "list", "t": "FREE!", "it": ["BOX OF CABLES", "ONE SOCK", "OLD BUNK", "ADVICE"], "x": [2], "m": "dash", "c": GREEN, "ic": BLACK, "xc": BLUE},
	{"k": "list", "t": "SPARE PARTS", "it": ["SOLARI COIL", "CYGNET EYE", "3 BOLTS", "GLUE"], "x": [1], "m": "box", "c": BLACK, "ic": BLUE, "xc": RED},
	{"k": "list", "t": "PARTY", "it": ["CUPS", "MUSIC", "SNACKS", "NO WELDING"], "x": [0, 1], "m": "tick", "c": RED, "ic": BLUE, "xc": GREEN},
	{"k": "list", "t": "TOP SECRET", "it": ["NOTHING", "TO SEE", "HERE"], "x": [], "m": "num", "c": RED, "ic": BLACK},
	{"k": "list", "t": "RAFFLE PRIZES", "it": ["HOT SHOWER", "BUNK BY THE VENT", "TIK'S HAT", "1 DAY OFF"], "x": [0], "m": "num", "c": BLUE, "ic": GREEN, "xc": RED},

	# -- tally marks of something silly
	{"k": "tally", "t": ["TIMES THE LIFT", "BROKE"], "n": 13, "c": BLACK, "tc": RED},
	{"k": "tally", "t": ["TIK SAID", "'TRUST ME'"], "n": 17, "c": BLUE, "tc": BLUE},
	{"k": "tally", "t": ["DAYS NO HOT WATER"], "n": 6, "c": RED, "tc": BLACK},
	{"k": "tally", "t": ["HELLBENDER SEEN"], "n": 4, "c": BLACK, "tc": RED},

	# -- scoreboards
	{"k": "score", "t": "CARDS", "a": "DOCK 3", "b": "DOCK 5", "sa": "12", "sb": "9"},
	{"k": "score", "t": "DARTS", "a": "REDS", "b": "BLUES", "sa": "4", "sb": "40"},
	{"k": "score", "t": "ARM WRESTLE", "a": "PILOTS", "b": "COOKS", "sa": "0", "sb": "7"},
	{"k": "score", "t": "STARING", "a": "CAT", "b": "DRONE", "sa": "1", "sb": "0"},

	# -- hangman, mid-game: the word, the letters found, the wrong ones, how much is drawn
	{"k": "hang", "w": "AIRLOCK", "r": "AIK", "bad": "ESTU", "p": 4, "c": "A DOOR"},
	{"k": "hang", "w": "BEANS", "r": "EA", "bad": "OTR", "p": 3},
	{"k": "hang", "w": "SWARM", "r": "SA", "bad": "EIOTN", "p": 5},
	{"k": "hang", "w": "COFFEE", "r": "OFE", "bad": "A", "p": 1},

	# -- dots and boxes
	{"k": "dots", "a": "JO", "b": "MAX", "nx": 6, "ny": 4, "dn": 0.62},
	{"k": "dots", "a": "REN", "b": "TIK", "nx": 5, "ny": 4, "dn": 0.8},
	{"k": "dots", "a": "ME", "b": "YOU", "nx": 7, "ny": 3, "dn": 0.5},

	# -- noughts and crosses: the boards, row by row, and each one's winning line
	{"k": "ttt", "g": ["XXXOO    "], "w": [[0, 2]], "cap": "X WINS"},
	{"k": "ttt", "g": ["OXOXXOOOX"], "w": [[]], "cap": "AGAIN?"},
	{"k": "ttt", "g": ["XOOOX   X", "OOOXX X  ", "XO XO X  "], "w": [[0, 8], [0, 2], [0, 6]], "cap": "JO 2  TIK 1"},
	{"k": "ttt", "g": ["    X    "], "w": [[]], "cap": "YOUR GO MAX"},

	# -- bar charts
	{"k": "bars", "t": "COFFEE CUPS", "l": ["M", "T", "W", "T", "F"], "v": [0.3, 0.45, 0.6, 0.8, 1.0], "c": BLUE, "hl": 4},
	{"k": "bars", "t": "WHO IS LATE", "l": ["JO", "MAX", "TIK"], "v": [0.2, 0.35, 1.0], "c": GREEN, "hl": 2},
	{"k": "bars", "t": "HEAT", "l": ["1", "2", "3", "4", "5", "6"], "v": [0.4, 0.5, 0.45, 0.7, 0.9, 1.0], "c": RED, "hl": -1},
	{"k": "bars", "t": "SOCKS LOST", "l": ["L", "R"], "v": [0.9, 0.3], "c": BLUE, "hl": -1},

	# -- line graphs, mostly going the wrong way
	{"k": "graph", "t": "MORALE", "v": [0.9, 0.8, 0.85, 0.6, 0.5, 0.2, 0.08], "xl": "WEEK", "n": "UH OH", "c": RED},
	{"k": "graph", "t": "SAVINGS", "v": [0.7, 0.66, 0.6, 0.52, 0.45, 0.3], "xl": "YEARS", "n": "", "c": GREEN},
	{"k": "graph", "t": "COMPLAINTS", "v": [0.05, 0.15, 0.3, 0.45, 0.7, 0.95], "xl": "MONTHS", "n": "", "c": BLACK},
	{"k": "graph", "t": "SKY HEAT", "v": [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3], "xl": "ALWAYS", "n": "SAD", "c": BLUE},

	# -- pie charts
	{"k": "pie", "t": "MY PAY", "f": [0.5, 0.3, 0.2], "l": ["RENT", "FOOD", "FUN"]},
	{"k": "pie", "t": "LUNCH", "f": [0.85, 0.15], "l": ["BEANS", "NOT BEANS"]},
	{"k": "pie", "t": "WHY I'M LATE", "f": [0.6, 0.25, 0.15], "l": ["LIFT", "SLEEP", "CAT"]},

	# -- two circles and who is in the middle
	{"k": "venn", "a": "CAN FLY", "b": "CAN COOK", "o": "NOBODY"},
	{"k": "venn", "a": "LOUD", "b": "FUNNY", "o": "TIK"},
	{"k": "venn", "a": "TIRED", "b": "HUNGRY", "o": "ALL OF US"},

	# -- sums somebody got wrong, and somebody else ringed
	{"k": "sum", "l": ["2 + 2 = 5"], "big": true, "fix": "NO!"},
	{"k": "sum", "l": ["12 X 3 = 33"], "fix": "36. - REN"},
	{"k": "sum", "l": ["PAY 40", "RENT 45", "LEFT = -5"], "fix": "NO SNACKS THEN"},
	{"k": "sum", "l": ["1 DRONE + 1 DRONE", "= 3 DRONES"], "fix": "HOW?!"},

	# -- countdowns
	{"k": "count", "t": "SHORE LEAVE IN", "n": "12", "u": "DAYS!", "old": ["15", "14", "13"]},
	{"k": "count", "t": "PAYDAY IN", "n": "3", "u": "SLEEPS", "old": ["5", "4"]},
	{"k": "count", "t": "REFIT DONE IN", "n": "40", "u": "DAYS??", "old": ["9", "20", "31"]},

	# -- a cake with candles
	{"k": "cake", "t": ["HAPPY", "B-DAY REN!"], "n": 3, "c": BLUE},
	{"k": "cake", "t": ["CAKE IN THE", "MESS AT 4"], "n": 1, "c": GREEN},

	# -- the station cat
	{"k": "cat", "t": ["THIS IS", "KEVIN"], "no": false},
	{"k": "cat", "t": ["NO CATS", "ON DECK 2"], "no": true},

	# -- drones
	{"k": "drone", "t": ["DRONE 7"], "bub": "BEEP"},
	{"k": "drone", "t": ["IT WATCHES", "YOU"], "bub": ""},

	# -- stick figures
	{"k": "stick", "p": "wave", "t": ["HI!"]},
	{"k": "stick", "p": "two", "t": ["JO", "MAX", "BEST", "CREW"]},
	{"k": "stick", "p": "lift", "t": ["LIFT WITH", "YOUR LEGS"]},
	{"k": "stick", "p": "sleep", "t": ["ME AFTER SHIFT"]},

	# -- planets and rockets
	{"k": "planet", "t": ["THE VIEW!"], "moon": true, "flag": false},
	{"k": "planet", "t": ["OURS NOW"], "moon": false, "flag": true},
	{"k": "rocket", "t": ["TO THE", "PUB"]},
	{"k": "rocket", "t": ["3, 2, 1..."]},

	# -- maps: rooms as boxes, a mark, an arrow
	{"k": "here", "s": Vector2(132, 96), "t": "YOU ARE HERE", "tc": RED,
		"rm": [[4, 24, 52, 28, "MESS"], [62, 24, 64, 28, "BUNKS"], [4, 58, 40, 32, "DOCK"], [50, 58, 76, 32, "GYM"]],
		"mk": [114, 40], "ar": [96, 9, 112, 33]},
	{"k": "here", "s": Vector2(124, 86), "t": "DOCKS", "tc": BLACK,
		"rm": [[6, 22, 26, 38, "1"], [34, 22, 26, 38, "2"], [62, 22, 26, 38, "3"], [90, 22, 26, 38, "4"]],
		"mk": [75, 46], "ar": [60, 72, 72, 54], "lb": ["MY SHIP", 4, 82]},
	{"k": "ring", "ang": 0.0, "t": ["WE ARE", "HERE"]},
	{"k": "ring", "ang": 3.4, "t": ["THE PUB", "(GOOD)"]},

	# -- tear-off notes, with one tab gone
	{"k": "tear", "t": "BUNK FOR RENT", "s2": "QUIET, NO RATS", "nm": "JO", "ph": "117"},
	{"k": "tear", "t": "GUITAR LESSONS", "s2": "CHEAP. LOUD.", "nm": "REN", "ph": "402"},

	# -- rotas
	{"k": "rota", "t": "COFFEE MACHINE", "d": ["M", "T", "W", "T", "F"], "n": ["JO", "MX", "TK", "RN", "JO"], "x": 2, "r": "ME!"},
	{"k": "rota", "t": "DISHES", "d": ["M", "T", "W", "T", "F"], "n": ["RN", "RN", "RN", "RN", "RN"], "x": -1, "r": "WHY ME - REN"},

	# -- quotes
	{"k": "quote", "l": ["'IT'S NOT A LEAK,", "IT'S A FEATURE'"], "by": "- TIK", "c": BLUE, "bc": BLACK},
	{"k": "quote", "l": ["'COLD IS JUST", "HEAT, BUT SAD'"], "by": "- REN", "c": BLACK, "bc": RED},
	{"k": "quote", "l": ["'I CAN FIX", "THAT'"], "by": "- TIK, LAST WEEK", "c": GREEN, "bc": BLACK},
	{"k": "quote", "l": ["'NEVER TRUST A", "QUIET DRONE'"], "by": "- GRAN", "c": BLACK, "bc": BLUE},
	{"k": "quote", "l": ["'WE'RE ALL JUST", "SPACE DUST'"], "by": "- MAX, 3 AM", "c": RED, "bc": BLACK},

	# -- rules
	{"k": "rule", "l": ["NO WELDING", "IN THE MESS"], "c": RED, "sym": true},
	{"k": "rule", "l": ["WIPE THE SEATS!"], "c": BLUE, "sym": false},
	{"k": "rule", "l": ["QUIET AFTER", "2200 PLEASE"], "c": BLACK, "sym": false},
	{"k": "rule", "l": ["NO PETS IN", "THE AIRLOCK"], "c": RED, "sym": true},
	{"k": "rule", "l": ["LABEL YOUR", "FOOD!!"], "c": GREEN, "sym": false},
	{"k": "rule", "l": ["DOCK 3 SHUT.", "USE DOCK 5"], "c": BLUE, "sym": false},

	# -- polls, with ticks
	{"k": "poll", "t": "MOVIE NIGHT?", "o": ["YES", "NO", "WHAT MOVIE"], "n": [7, 2, 4]},
	{"k": "poll", "t": "PIZZA OR NOODLES", "o": ["PIZZA", "NOODLES"], "n": [6, 6]},
	{"k": "poll", "t": "NAME FOR DOCK 5", "o": ["DOCK 5", "DOCKY", "FIVE"], "n": [3, 9, 1]},

	# -- a week on a calendar
	{"k": "week", "t": "THIS WEEK", "x": 3, "o": 5, "n": "LEAVE!"},
	{"k": "week", "t": "CARGO RUN", "x": 2, "o": 4, "n": "SHIP IN"},

	# -- wanted
	{"k": "wanted", "what": "mug", "l": ["MUG THIEF", "REWARD: 1 CR"]},
	{"k": "wanted", "what": "cake", "l": ["CAKE THIEF", "I KNOW IT'S U"]},

	# -- a sun in sunglasses
	{"k": "sun", "t": ["SUN DECK?", "NO."]},
	{"k": "sun", "t": ["STAY COOL"]},

	# -- ships, with labels
	{"k": "ship", "v": 0},
	{"k": "ship", "v": 1},

	# -- flowcharts
	{"k": "flow", "q": "IS IT BROKEN?", "ya": "CALL TIK", "na": "DON'T TOUCH"},
	{"k": "flow", "q": "HUNGRY?", "ya": "MESS", "na": "LIAR"},

	# -- signatures
	{"k": "sign", "t": "THANKS DOC!", "names": ["JO", "", "REN", "", ""], "c": RED},
	{"k": "sign", "t": "GET WELL TIK", "names": ["", "MAX", "", "", "KEVIN"], "c": BLUE},

	# -- hearts
	{"k": "heart", "t": "R+T", "c": RED, "sc": 1.4, "arrow": true},
	{"k": "heart", "t": "DOCK 5", "c": BLUE, "sc": 2.2, "arrow": false},

	# -- faces
	{"k": "face", "f": "frown", "t": ["NO COFFEE"]},
	{"k": "face", "f": "meh", "t": ["MONDAY"]},
	{"k": "face", "f": "wow", "t": ["PAYDAY?!"]},
	{"k": "face", "f": "smile", "t": ["HAVE A", "NICE SHIFT"]},

	# -- half-erased messages
	{"k": "erased", "s": Vector2(122, 46), "l": ["MEET AT DOCK 4", "AT 1900 FOR"], "c": BLUE, "wx": 64, "wy": [16, 40], "add": ["???", 80, 30, RED]},
	{"k": "erased", "s": Vector2(116, 46), "l": ["CODE FOR DOOR", "IS 4417"], "c": BLACK, "wx": 26, "wy": [20, 40], "add": ["NICE TRY", 40, 40, RED]},

	# -- bets and debts
	{"k": "iou", "l": ["I OWE REN", "5 CR"], "by": "- JO", "paid": false},
	{"k": "iou", "l": ["BET: TIK CAN'T", "GO A WEEK", "WITHOUT BEANS"], "by": "- MAX", "paid": false},
	{"k": "iou", "l": ["I OWE MAX", "1 COFFEE"], "by": "- REN", "paid": true},

	# -- quiz night
	{"k": "quiz", "t": "QUIZ NIGHT", "r": [["DOCK RATS", "12"], ["THE BOLTS", "9"], ["MAX", "2"]]},
	{"k": "quiz", "t": "CARD NIGHT", "r": [["JO", "40"], ["REN", "35"], ["TIK", "-6"]]},

	# -- the Hellbender
	{"k": "bounty", "t": "HELLBENDER", "l": "BOUNTY 500 CR"},
	{"k": "bounty", "t": "SEEN IT?", "l": "TELL DOCK 3"},

	# -- odds and ends, one or two of each
	{"k": "swarm", "t": ["SWARM AT", "GATE 4.", "STAY IN!"]},
	{"k": "thermo", "t": ["HEAT", "TOO HOT"], "lv": 0.9},
	{"k": "clock", "h": 3, "m": 0, "t": ["BACK", "AT 3"]},
	{"k": "clock", "h": 9, "m": 40, "t": ["LATE", "AGAIN, JO"]},
	{"k": "chat", "l": [["WHO TOOK MY SPANNER?", BLACK], ["NOT ME", BLUE], ["NOT ME", GREEN], ["ME. SORRY.", RED]]},
	{"k": "chat", "l": [["IS DOCK 5 OPEN?", BLUE], ["NO", BLACK], ["WHY", BLUE], ["CAT ON THE RAMP", BLACK]]},
	{"k": "chat", "l": [["WHO IS COOKING?", GREEN], ["TIK", BLACK], ["OH NO", GREEN]]},
	{"k": "stars", "t": "MESS FOOD", "r": [["SOUP", 3], ["BEANS", 1], ["CAKE", 5]], "c": RED},
	{"k": "jump", "t": "OUR RUN", "p": [[12, 26, "HERE"], [44, 44, ""], [70, 30, "GATE"], [104, 54, "PAY?"]]},
	{"k": "crate", "t": "THIS WAY UP"},
	{"k": "bingo", "n": ["4", "17", "31", "48", "62", "9", "22", "FREE", "51", "70", "12", "29", "40", "55", "66"], "x": [0, 3, 7, 8, 11]},
	{"k": "crown", "t": ["TOP CREW:", "THE DRONE"]},
	{"k": "ghost", "t": ["DECK 9 IS", "HAUNTED", "(IT'S A PIPE)"]},
	{"k": "plant", "t": ["WATER ME!", "- PLANT"]},
	{"k": "queue", "t": "NOW SERVING", "n": "47", "me": ["YOU:", "52"]},
	{"k": "doodles", "set": ["cube", "spiral", "star"]},
	{"k": "doodles", "set": ["flower", "zig", "eye"]},
	{"k": "comic", "t": "MY DAY", "f": ["frown", "meh", "smile"], "l": ["6 AM", "NOON", "BED"]},
	{"k": "comic", "t": "PAYDAY", "f": ["wow", "smile", "frown"], "l": ["PAY", "PUB", "BROKE"]},
	{"k": "robot", "t": ["HELLO", "HUMAN"], "bub": false},
	{"k": "robot", "t": ["BEEP"], "bub": true},
	{"k": "gauge", "t": "FUEL", "lo": "E", "hi": "F", "a": 0.12, "cap": ["UH OH"]},
	{"k": "gauge", "t": "COFFEE", "lo": "0", "hi": "MAX", "a": 0.92, "cap": ["READY", "FOR WORK"]},
	{"k": "lift"},
	{"k": "whale", "t": ["SPACE WHALE?", "SAW IT. - JO"]},
	{"k": "spanner", "t": "LOST!", "l": "REWARD: SOUP"},
	{"k": "arrow", "t": "COFFEE", "sub": "", "flip": false, "c": GREEN},
	{"k": "arrow", "t": "DOCK 5", "sub": "THIS WAY", "flip": true, "c": BLUE},
	{"k": "cloud", "t": ["STATION", "WEATHER:", "DRY. AGAIN."]},
	{"k": "notes", "t": ["KARAOKE", "FRI 2000", "(NOT TIK)"]},
	{"k": "cards", "t": ["CARDS", "2100", "BRING CR"]},
	{"k": "dice", "t": ["ROLL FOR", "DISHES:", "LOW ONE", "WASHES"]},
	{"k": "mug", "t": ["COFFEE IS", "BROKEN", "AGAIN"]},
	{"k": "darts", "t": ["DARTS", "THURS", "MIND THE", "PIPES"]},
]


# ---------------------------------------------------------------------------
# Helpers: all of them draw through the board's own marker strokes.
# ---------------------------------------------------------------------------

## Words, foot of the letters at `y`.
static func _say(b: PostingBoard, t: String, x: float, y: float, col: Color, s: float, big := false) -> void:
	b._hand(t, Vector2(x, y), col, s, UITheme.FS_HEAD if big else UITheme.FS_SMALL)


## How wide `_hand` writes `t`, near enough: 7.8 a letter, 5.5 a space.
static func _tw(t: String, big := false) -> float:
	var w := 0.0
	for ch in t:
		if ch == " ":
			w += 11.6 if big else 5.5
		else:
			w += 16.2 if big else 7.8
	return w


static func _widest(lines: Array, big := false) -> float:
	var w := 0.0
	for t in lines:
		w = maxf(w, _tw(String(t), big))
	return w


static func _ln(b: PostingBoard, a: Vector2, c: Vector2, col: Color, s: float) -> void:
	b._wobble_line(a, c, col, s)


## A run of marker strokes, corner to corner.
static func _poly(b: PostingBoard, pts: Array, col: Color, s: float, closed := false) -> void:
	for k in pts.size() - 1:
		b._wobble_line(pts[k], pts[k + 1], col, s + float(k) * 0.37)
	if closed:
		b._wobble_line(pts[pts.size() - 1], pts[0], col, s + 9.1)


## A smooth stroke through `pts`, for curves too tight to bow.
static func _curve(b: PostingBoard, pts: Array, col: Color) -> void:
	for k in pts.size() - 1:
		b.draw_line((pts[k] as Vector2).round(), (pts[k + 1] as Vector2).round(), col, 2.0)


static func _arc(b: PostingBoard, c: Vector2, rx: float, ry: float, a0: float, a1: float, col: Color, n := 16) -> void:
	var pts: Array = []
	for k in n + 1:
		var a := lerpf(a0, a1, float(k) / float(n))
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	_curve(b, pts, col)


static func _arrow(b: PostingBoard, a: Vector2, c: Vector2, col: Color, s: float) -> void:
	b._wobble_line(a, c, col, s)
	var d := (c - a).normalized()
	var n := Vector2(-d.y, d.x)
	b._wobble_line(c, c - d * 6.0 + n * 4.0, col, s + 0.5)
	b._wobble_line(c, c - d * 6.0 - n * 4.0, col, s + 0.7)


## A tick about ten wide, `p` at its top left.
static func _tick(b: PostingBoard, p: Vector2, col: Color, s: float) -> void:
	b._wobble_line(p + Vector2(0, 4), p + Vector2(3, 7), col, s)
	b._wobble_line(p + Vector2(3, 7), p + Vector2(9, -1), col, s + 0.5)


static func _cross(b: PostingBoard, c: Vector2, r: float, col: Color, s: float) -> void:
	b._wobble_line(c + Vector2(-r, -r), c + Vector2(r, r), col, s)
	b._wobble_line(c + Vector2(r, -r), c + Vector2(-r, r), col, s + 0.5)


## A line through words written at `x`, `base`, `w` wide.
static func _strike(b: PostingBoard, x: float, base: float, w: float, col: Color, s: float) -> void:
	b._wobble_line(Vector2(x - 2.0, base - 4.0), Vector2(x + w + 1.0, base - 3.0), col, s)


static func _dot(b: PostingBoard, p: Vector2, col: Color) -> void:
	b.draw_circle(p.round(), 1.5, col)


## Tally marks in fives, `h` tall from `top`.
static func _tally(b: PostingBoard, x: float, top: float, n: int, h: float, col: Color, s: float) -> void:
	var g := 0
	var left := n
	while left > 0:
		var m := mini(5, left)
		var x0 := x + float(g) * 24.0
		for j in mini(4, m):
			b._wobble_line(Vector2(x0 + float(j) * 4.0, top), Vector2(x0 + float(j) * 4.0 - 1.0, top + h),
				col, s + float(g * 5 + j))
		if m == 5:
			b._wobble_line(Vector2(x0 - 3.0, top + h - 2.0), Vector2(x0 + 15.0, top + 2.0), col, s + float(g * 5) + 4.5)
		left -= m
		g += 1


static func _tally_w(n: int) -> float:
	return float(ceili(float(n) / 5.0)) * 24.0 - 6.0


## A stick figure standing at `foot`; `arms` are the two hands from the shoulder.
static func _fig(b: PostingBoard, foot: Vector2, col: Color, s: float, arms: Array) -> void:
	b._wobble_circle(foot + Vector2(0, -30), 5.0, col, s)
	var sh := foot + Vector2(0, -22)
	var hip := foot + Vector2(0, -12)
	b._wobble_line(foot + Vector2(0, -25), hip, col, s + 1.0)
	b._wobble_line(hip, foot + Vector2(-5, 0), col, s + 2.0)
	b._wobble_line(hip, foot + Vector2(5, 0), col, s + 3.0)
	b._wobble_line(sh, sh + (arms[0] as Vector2), col, s + 4.0)
	b._wobble_line(sh, sh + (arms[1] as Vector2), col, s + 5.0)


## A face in a circle: smile, frown, meh or wow.
static func _face(b: PostingBoard, c: Vector2, r: float, f: String, col: Color, s: float) -> void:
	b._wobble_circle(c, r, col, s)
	var e := r * 0.38
	if f == "wow":
		_dot(b, c + Vector2(-e, -e), col)
		_dot(b, c + Vector2(e, -e), col)
		b._wobble_circle(c + Vector2(0, r * 0.4), maxf(2.5, r * 0.22), col, s + 1.0)
		return
	b._wobble_line(c + Vector2(-e, -e - 2.0), c + Vector2(-e, -e + 1.0), col, s + 1.0)
	b._wobble_line(c + Vector2(e, -e - 2.0), c + Vector2(e, -e + 1.0), col, s + 2.0)
	match f:
		"smile":
			_arc(b, c + Vector2(0, -r * 0.05), r * 0.55, r * 0.5, 0.35, PI - 0.35, col, 8)
		"frown":
			_arc(b, c + Vector2(0, r * 0.75), r * 0.5, r * 0.35, PI + 0.5, TAU - 0.5, col, 8)
		_:
			b._wobble_line(c + Vector2(-r * 0.45, r * 0.4), c + Vector2(r * 0.45, r * 0.35), col, s + 3.0)


## The heart from drawing 7, at any size.
static func _heart(b: PostingBoard, hc: Vector2, sc: float, col: Color) -> void:
	var prev := Vector2.ZERO
	for k in 25:
		var t := float(k) / 24.0 * TAU
		var hx := 16.0 * pow(sin(t), 3.0)
		var hy := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		var pt := hc + Vector2(hx, hy) * sc
		if k > 0:
			b.draw_line(prev.round(), pt.round(), col, 2.0 if sc > 0.6 else 1.0)
		prev = pt


## A mug, `p` the top left of its body (16 by 18).
static func _mug(b: PostingBoard, p: Vector2, col: Color, s: float, steam := true) -> void:
	b._wobble_line(p + Vector2(-1, 0), p + Vector2(17, 0), col, s)
	b._wobble_line(p, p + Vector2(1, 18), col, s + 1.0)
	b._wobble_line(p + Vector2(1, 18), p + Vector2(15, 18), col, s + 2.0)
	b._wobble_line(p + Vector2(15, 18), p + Vector2(16, 0), col, s + 3.0)
	_arc(b, p + Vector2(16, 9), 5.0, 5.0, -PI * 0.5, PI * 0.5, col, 8)
	if steam:
		for k in 2:
			var pts: Array = []
			for j in 6:
				pts.append(p + Vector2(5.0 + float(k) * 6.0 + sin(float(j) * 1.4 + float(k)) * 1.5, -3.0 - float(j) * 2.0))
			_curve(b, pts, col)


## A five-point star.
static func _star(b: PostingBoard, c: Vector2, r: float, col: Color) -> void:
	var pts: Array = []
	for k in 6:
		var a := -PI * 0.5 + float((k * 2) % 5) * TAU / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	for k in 5:
		var p0: Vector2 = (pts[k] as Vector2).round()
		var p1: Vector2 = (pts[k + 1] as Vector2).round()
		b.draw_line(p0, p1, col, 1.0)
		b.draw_line(p0 + Vector2(1, 0), p1 + Vector2(1, 0), Color(col.r, col.g, col.b, 0.6), 1.0)


## A signature: a looping scrawl `w` wide and a flick under it.
static func _squig(b: PostingBoard, p: Vector2, w: float, col: Color, s: float, initial := "") -> void:
	# a big capital, then the rest of the name run out into humps that shrink
	var caps := "ABDEJKLMNPRSTW"
	var cap := initial if initial != "" else caps[int(ShopLight.hash1(s) * float(caps.length())) % caps.length()]
	_say(b, cap, p.x, p.y + 5.0, col, s, true)
	var pts: Array = []
	var n := 20
	var humps := 4.0 + floorf(ShopLight.hash1(s + 0.3) * 2.0)
	var x0 := p.x + 15.0
	for j in n + 1:
		var t := float(j) / float(n)
		var y := p.y + 3.0 - absf(sin(t * humps * PI)) * lerpf(5.0, 2.0, t) - t * 3.0
		pts.append(Vector2(x0 + t * (w - 15.0), y))
	_curve(b, pts, col)
	b._wobble_line(p + Vector2(-2, 8), p + Vector2(w + 2.0, 6), col, s + 3.0)


# ---------------------------------------------------------------------------
# Sizes, for the rows that size themselves.
# ---------------------------------------------------------------------------

static func _list_x(d: Dictionary, k: int) -> float:
	match String(d.get("m", "dash")):
		"box":
			return 19.0
		"num":
			return 5.0 + _tw("%d." % (k + 1)) + 3.0
		"dash":
			return 5.0 + _tw("-") + 3.0
	return 6.0


static func _size(d: Dictionary) -> Vector2:
	if d.has("s"):
		return d["s"]
	match String(d["k"]):
		"list":
			var items: Array = d["it"]
			var done: Array = d.get("x", [])
			var w := _tw(String(d["t"])) + 10.0
			for k in items.size():
				var extra := 16.0 if String(d.get("m", "")) == "tick" and done.has(k) else 0.0
				w = maxf(w, _list_x(d, k) + _tw(String(items[k])) + extra + 6.0)
			return Vector2(ceilf(w), 22.0 + 13.0 * float(items.size()))
		"tally":
			var lines: Array = d["t"]
			var top := 12.0 + 13.0 * float(lines.size() - 1) + 7.0
			return Vector2(ceilf(maxf(_widest(lines) + 8.0, 7.0 + _tally_w(int(d["n"])) + 10.0)), top + 20.0)
		"score":
			var cw := maxf(maxf(_tw(String(d["a"])), _tw(String(d["b"]))),
				maxf(_tw(String(d["sa"]), true), _tw(String(d["sb"]), true))) + 20.0
			return Vector2(ceilf(maxf(cw * 2.0, _tw(String(d["t"])) + 12.0)), 62)
		"hang":
			var w := 54.0 + 11.0 * float(String(d["w"]).length()) + 2.0
			w = maxf(w, 54.0 + 13.0 * float(String(d["bad"]).length()) + 4.0)
			w = maxf(w, 54.0 + _tw(String(d.get("c", ""))) + 6.0)
			return Vector2(ceilf(w), 68)
		"dots":
			var nx := int(d["nx"])
			var head := _tw(String(d["a"]) + " 0") + _tw(String(d["b"]) + " 0") + 10.0
			return Vector2(ceilf(maxf(12.0 + float(nx - 1) * 14.0, head + 8.0)), 24.0 + float(int(d["ny"]) - 1) * 14.0 + 6.0)
		"ttt":
			var n := (d["g"] as Array).size()
			return Vector2(ceilf(maxf(float(n) * 58.0 - 2.0, _tw(String(d["cap"])) + 8.0)), 70)
		"bars":
			var slot := maxf(16.0, _widest(d["l"]) + 8.0)
			return Vector2(ceilf(maxf(16.0 + float((d["l"] as Array).size()) * slot + 6.0, _tw(String(d["t"])) + 8.0)), 80)
		"graph":
			return Vector2(120, 80)
		"pie":
			var w := 0.0
			var ls: Array = d["l"]
			for k in ls.size():
				w = maxf(w, _tw("%d %s" % [k + 1, ls[k]]))
			return Vector2(ceilf(60.0 + w + 6.0), 68)
		"venn":
			return Vector2(ceilf(maxf(112.0, maxf(_tw(String(d["a"])) + _tw(String(d["b"])) + 20.0, _tw(String(d["o"])) + 8.0))), 86)
		"sum":
			var lines: Array = d["l"]
			var big := bool(d.get("big", false))
			var step := 22.0 if big else 14.0
			var yb := (22.0 if big else 14.0) + step * float(lines.size() - 1)
			return Vector2(ceilf(maxf(_widest(lines, big) + 20.0, _tw(String(d["fix"])) + 16.0)), yb + 24.0)
		"count":
			var ow := 0.0
			for o in d["old"]:
				ow += _tw(String(o)) + 8.0
			return Vector2(ceilf(maxf(_tw(String(d["t"])) + 8.0, 4.0 + ow + 42.0 + _tw(String(d["u"])) + 8.0)), 64)
		"cake":
			return Vector2(ceilf(64.0 + _widest(d["t"]) + 4.0), 66)
		"cat":
			return Vector2(ceilf((60.0 if bool(d["no"]) else 50.0) + _widest(d["t"]) + 4.0), 64)
		"drone":
			var w := _widest(d["t"])
			if String(d["bub"]) != "":
				w = maxf(w, _tw(String(d["bub"])) + 10.0)
			return Vector2(ceilf(62.0 + w + 6.0), 50)
		"stick":
			match String(d["p"]):
				"wave":
					return Vector2(ceilf(36.0 + _tw(String(d["t"][0])) + 14.0), 64)
				"two":
					return Vector2(ceilf(66.0 + maxf(_tw(String(d["t"][2])), _tw(String(d["t"][3]))) + 4.0), 64)
				"lift":
					return Vector2(ceilf(46.0 + _widest(d["t"]) + 4.0), 66)
			return Vector2(ceilf(maxf(106.0, _widest(d["t"]) + 8.0)), 72)
		"planet":
			return Vector2(ceilf(62.0 + _widest(d["t"]) + 4.0), 64)
		"rocket":
			return Vector2(ceilf(44.0 + _widest(d["t"]) + 4.0), 62)
		"ring":
			return Vector2(ceilf(76.0 + _widest(d["t"]) + 4.0), 74)
		"tear":
			return Vector2(ceilf(maxf(128.0, maxf(_tw(String(d["t"])), _tw(String(d["s2"]))) + 8.0)), 66)
		"rota":
			var n := (d["n"] as Array).size()
			return Vector2(ceilf(maxf(maxf(4.0 + float(n) * 22.0 + 6.0, _tw(String(d["t"])) + 8.0), _tw(String(d["r"])) + 8.0)), 64)
		"quote":
			var lines: Array = d["l"]
			return Vector2(ceilf(maxf(_widest(lines) + 12.0, _tw(String(d["by"])) + 12.0)), 12.0 + 13.0 * float(lines.size() - 1) + 21.0)
		"rule":
			var lines: Array = d["l"]
			var x0 := 36.0 if bool(d["sym"]) else 11.0
			return Vector2(ceilf(x0 + _widest(lines) + 12.0), 20.0 + 13.0 * float(lines.size() - 1) + 13.0)
		"poll":
			var mx := 0
			for v in d["n"]:
				mx = maxi(mx, int(v))
			var os: Array = d["o"]
			return Vector2(ceilf(maxf(6.0 + _widest(os) + 10.0 + _tally_w(mx) + 8.0, _tw(String(d["t"])) + 8.0)), 28.0 + 14.0 * float(os.size() - 1) + 8.0)
		"week":
			return Vector2(122, 64)
		"wanted":
			return Vector2(112, 106)
		"sun":
			return Vector2(ceilf(54.0 + _widest(d["t"]) + 4.0), 58)
		"ship":
			return Vector2(136, 84)
		"flow":
			var half := maxf(_tw(String(d["ya"])), _tw(String(d["na"]))) + 16.0
			return Vector2(ceilf(maxf(_tw(String(d["q"])) + 20.0, half * 2.0 + 8.0)), 66)
		"sign":
			return Vector2(122, 82)
		"heart":
			var sc := float(d["sc"])
			return Vector2(ceilf(32.0 * sc + 14.0 + (10.0 if bool(d["arrow"]) else 0.0)), ceilf(30.0 * sc + 12.0))
		"face":
			return Vector2(ceilf(42.0 + _widest(d["t"]) + 4.0), 40)
		"iou":
			var lines: Array = d["l"]
			var row := 8.0 + _tw(String(d["by"])) + 8.0 + 34.0 + (_tw("PAID!") + 8.0 if bool(d["paid"]) else 0.0)
			return Vector2(ceilf(maxf(_widest(lines) + 18.0, row + 6.0)), 16.0 + 13.0 * float(lines.size() - 1) + 34.0)
		"quiz":
			var names: Array = []
			var scores: Array = []
			for r in d["r"]:
				names.append(r[0])
				scores.append(r[1])
			return Vector2(ceilf(maxf(6.0 + _widest(names) + 22.0 + _widest(scores) + 12.0, _tw(String(d["t"])) + 8.0)), 30.0 + 13.0 * float(scores.size() - 1) + 9.0)
		"bounty":
			return Vector2(130, 80)
		"swarm":
			return Vector2(ceilf(62.0 + _widest(d["t"]) + 6.0), 66)
		"thermo":
			return Vector2(ceilf(36.0 + maxf(_tw(String(d["t"][0]), true), _tw(String(d["t"][1]))) + 6.0), 68)
		"clock":
			return Vector2(ceilf(48.0 + _widest(d["t"]) + 4.0), 48)
		"chat":
			var w := 0.0
			var ls: Array = d["l"]
			for k in ls.size():
				w = maxf(w, 6.0 + float(k % 2) * 12.0 + _tw(String(ls[k][0])))
			return Vector2(ceilf(w + 6.0), 13.0 + 13.0 * float(ls.size() - 1) + 7.0)
		"stars":
			var names: Array = []
			for r in d["r"]:
				names.append(r[0])
			return Vector2(ceilf(maxf(6.0 + _widest(names) + 8.0 + 60.0 + 4.0, _tw(String(d["t"])) + 8.0)), 28.0 + 14.0 * float(names.size() - 1) + 8.0)
		"jump":
			return Vector2(136, 74)
		"crate":
			return Vector2(ceilf(maxf(96.0, _tw(String(d["t"])) + 8.0)), 82)
		"bingo":
			return Vector2(110, 72)
		"crown":
			return Vector2(ceilf(50.0 + _widest(d["t"]) + 4.0), 44)
		"ghost":
			return Vector2(ceilf(42.0 + _widest(d["t"]) + 4.0), 62)
		"plant":
			return Vector2(ceilf(44.0 + _widest(d["t"]) + 4.0), 64)
		"queue":
			return Vector2(ceilf(maxf(_tw(String(d["t"])) + 8.0, 62.0 + _widest(d["me"]) + 6.0)), 54)
		"doodles":
			return Vector2(4.0 + float((d["set"] as Array).size()) * 42.0, 46)
		"comic":
			return Vector2(134, 72)
		"robot":
			var w := _widest(d["t"]) + (12.0 if bool(d["bub"]) else 0.0)
			return Vector2(ceilf(50.0 + w + 6.0), 54)
		"gauge":
			return Vector2(ceilf(maxf(60.0 + _widest(d["cap"]) + 6.0, _tw(String(d["t"])) + 8.0)), 60)
		"lift":
			return Vector2(130, 72)
		"whale":
			return Vector2(ceilf(maxf(110.0, _widest(d["t"]) + 8.0)), 90)
		"spanner":
			return Vector2(ceilf(maxf(110.0, _tw(String(d["l"])) + 8.0)), 76)
		"arrow":
			return Vector2(100, 62 if String(d["sub"]) != "" else 50)
		"cloud", "notes", "cards", "dice", "mug", "darts":
			return Vector2(ceilf(62.0 + _widest(d["t"]) + 6.0), maxf(56.0, 14.0 + 13.0 * float((d["t"] as Array).size()) + 4.0))
	return Vector2(100, 60)


# ---------------------------------------------------------------------------
# The painters, one per kind.
# ---------------------------------------------------------------------------

static func _paint(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	match String(d["k"]):
		"list": _p_list(b, d, s)
		"tally": _p_tally(b, d, s)
		"score": _p_score(b, d, s, z)
		"hang": _p_hang(b, d, s)
		"dots": _p_dots(b, d, s)
		"ttt": _p_ttt(b, d, s)
		"bars": _p_bars(b, d, s, z)
		"graph": _p_graph(b, d, s, z)
		"pie": _p_pie(b, d, s)
		"venn": _p_venn(b, d, s, z)
		"sum": _p_sum(b, d, s)
		"count": _p_count(b, d, s)
		"cake": _p_cake(b, d, s)
		"cat": _p_cat(b, d, s)
		"drone": _p_drone(b, d, s)
		"stick": _p_stick(b, d, s)
		"planet": _p_planet(b, d, s)
		"rocket": _p_rocket(b, d, s)
		"here": _p_here(b, d, s)
		"ring": _p_ring(b, d, s)
		"tear": _p_tear(b, d, s)
		"rota": _p_rota(b, d, s)
		"quote": _p_quote(b, d, s, z)
		"rule": _p_rule(b, d, s, z)
		"poll": _p_poll(b, d, s)
		"week": _p_week(b, d, s)
		"wanted": _p_wanted(b, d, s, z)
		"sun": _p_sun(b, d, s)
		"ship": _p_ship(b, d, s)
		"flow": _p_flow(b, d, s, z)
		"sign": _p_sign(b, d, s)
		"heart": _p_heart(b, d, s, z)
		"face": _p_face(b, d, s)
		"erased": _p_erased(b, d, s, z)
		"iou": _p_iou(b, d, s, z)
		"quiz": _p_quiz(b, d, s, z)
		"bounty": _p_bounty(b, d, s)
		"swarm": _p_swarm(b, d, s)
		"thermo": _p_thermo(b, d, s)
		"clock": _p_clock(b, d, s)
		"chat": _p_chat(b, d, s)
		"stars": _p_stars(b, d, s)
		"jump": _p_jump(b, d, s)
		"crate": _p_crate(b, d, s)
		"bingo": _p_bingo(b, d, s)
		"crown": _p_crown(b, d, s)
		"ghost": _p_ghost(b, d, s)
		"plant": _p_plant(b, d, s)
		"queue": _p_queue(b, d, s)
		"doodles": _p_doodles(b, d, s)
		"comic": _p_comic(b, d, s)
		"robot": _p_robot(b, d, s)
		"gauge": _p_gauge(b, d, s)
		"lift": _p_lift(b, s)
		"whale": _p_whale(b, d, s)
		"spanner": _p_spanner(b, d, s)
		"arrow": _p_arrow(b, d, s, z)
		"cloud": _p_cloud(b, d, s, z)
		"notes": _p_notes(b, d, s, z)
		"cards": _p_cards(b, d, s, z)
		"dice": _p_dice(b, d, s, z)
		"mug": _p_mug(b, d, s, z)
		"darts": _p_darts(b, d, s, z)


## Lines of words at `x`, centred down a box `h` tall.
static func _caption(b: PostingBoard, lines: Array, x: float, h: float, col: Color, s: float) -> void:
	var y0 := h * 0.5 - 13.0 * float(lines.size() - 1) * 0.5 + 4.0
	for k in lines.size():
		_say(b, String(lines[k]), x, y0 + 13.0 * float(k), col, s + float(k))


static func _title(b: PostingBoard, t: String, col: Color, s: float) -> void:
	_say(b, t, 4, 12, col, s)
	_ln(b, Vector2(3, 15), Vector2(5.0 + _tw(t), 16), col, s + 0.5)


static func _p_list(b: PostingBoard, d: Dictionary, s: float) -> void:
	var tc: Color = d.get("c", BLACK)
	var ic: Color = d.get("ic", BLACK)
	var xc: Color = d.get("xc", RED)
	var m := String(d.get("m", "dash"))
	var done: Array = d.get("x", [])
	var items: Array = d["it"]
	_title(b, String(d["t"]), tc, s)
	for k in items.size():
		var y := 29.0 + 13.0 * float(k)
		var t := String(items[k])
		var x := _list_x(d, k)
		match m:
			"box":
				b._wobble_rect(Rect2(6, y - 8.0, 7, 7), ic, s + 10.0 + float(k))
			"num":
				_say(b, "%d." % (k + 1), 5, y, ic, s + 20.0 + float(k))
			"dash":
				_say(b, "-", 5, y, ic, s + 20.0 + float(k))
		_say(b, t, x, y, ic, s + 30.0 + float(k))
		if done.has(k):
			match m:
				"box":
					_tick(b, Vector2(6, y - 9.0), xc, s + 40.0 + float(k))
				"tick":
					_tick(b, Vector2(x + _tw(t) + 4.0, y - 8.0), xc, s + 40.0 + float(k))
				_:
					_strike(b, x, y, _tw(t), xc, s + 40.0 + float(k))


static func _p_tally(b: PostingBoard, d: Dictionary, s: float) -> void:
	var lines: Array = d["t"]
	for k in lines.size():
		_say(b, String(lines[k]), 4, 12.0 + 13.0 * float(k), d["c"], s + float(k))
	var top := 12.0 + 13.0 * float(lines.size() - 1) + 7.0
	_tally(b, 8, top, int(d["n"]), 14, d["tc"], s + 10.0)


static func _p_score(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	var t := String(d["t"])
	var half := z.x * 0.5
	var tx := half - _tw(t) * 0.5
	_say(b, t, tx, 12, BLACK, s)
	_ln(b, Vector2(tx - 2.0, 15), Vector2(tx + _tw(t) + 2.0, 16), BLACK, s + 1.0)
	_ln(b, Vector2(half, 21), Vector2(half + 1.0, z.y - 5.0), BLACK, s + 2.0)
	var ta := String(d["a"])
	var tb := String(d["b"])
	_say(b, ta, half * 0.5 - _tw(ta) * 0.5, 31, RED, s + 3.0)
	_say(b, tb, half * 1.5 - _tw(tb) * 0.5, 31, BLUE, s + 4.0)
	var sa := String(d["sa"])
	var sb := String(d["sb"])
	_say(b, sa, half * 0.5 - _tw(sa, true) * 0.5 + 1.0, 55, RED, s + 5.0, true)
	_say(b, sb, half * 1.5 - _tw(sb, true) * 0.5 + 1.0, 55, BLUE, s + 6.0, true)


static func _p_hang(b: PostingBoard, d: Dictionary, s: float) -> void:
	# the gallows
	_ln(b, Vector2(4, 62), Vector2(34, 63), BLACK, s)
	_ln(b, Vector2(12, 62), Vector2(12, 6), BLACK, s + 1.0)
	_ln(b, Vector2(11, 6), Vector2(38, 6), BLACK, s + 2.0)
	_ln(b, Vector2(12, 16), Vector2(21, 6), BLACK, s + 3.0)
	_ln(b, Vector2(38, 6), Vector2(38, 12), BLACK, s + 4.0)
	var p := int(d["p"])
	if p > 0:
		b._wobble_circle(Vector2(38, 17), 5.0, BLUE, s + 5.0)
	var parts := [[Vector2(38, 22), Vector2(38, 38)], [Vector2(38, 27), Vector2(32, 33)], [Vector2(38, 27), Vector2(44, 33)],
		[Vector2(38, 38), Vector2(33, 48)], [Vector2(38, 38), Vector2(43, 48)]]
	for k in mini(p - 1, parts.size()):
		_ln(b, parts[k][0], parts[k][1], BLUE, s + 6.0 + float(k))
	# the word, in blanks
	var w := String(d["w"])
	var r := String(d["r"])
	for k in w.length():
		var x := 54.0 + 11.0 * float(k)
		_ln(b, Vector2(x, 62), Vector2(x + 8.0, 62), BLACK, s + 12.0 + float(k))
		if r.contains(w[k]):
			_say(b, w[k], x + 1.0, 59, BLACK, s + 24.0 + float(k))
	# the wrong guesses, along the top
	var bad := String(d["bad"])
	for k in bad.length():
		_say(b, bad[k], 54.0 + 13.0 * float(k), 20, RED, s + 40.0 + float(k))
	var clue := String(d.get("c", ""))
	if clue != "":
		_say(b, clue, 54, 38, GREEN, s + 52.0)


static func _p_dots(b: PostingBoard, d: Dictionary, s: float) -> void:
	var nx := int(d["nx"])
	var ny := int(d["ny"])
	var dn := float(d["dn"])
	var sp := 14.0
	var o := Vector2(6, 24)
	var hz := {}
	var vt := {}
	for j in ny:
		for i in nx - 1:
			hz[Vector2i(i, j)] = ShopLight.hash1(s * 0.37 + float(j * 17 + i) * 1.31) < dn
	for j in ny - 1:
		for i in nx:
			vt[Vector2i(i, j)] = ShopLight.hash1(s * 0.53 + float(j * 17 + i) * 1.71 + 50.0) < dn
	var k := 0
	for key: Vector2i in hz:
		if hz[key]:
			var a := o + Vector2(key) * sp
			var col := RED if ShopLight.hash1(s + float(k) * 0.9) < 0.5 else BLUE
			_ln(b, a + Vector2(3, 0), a + Vector2(sp - 3.0, 0), col, s + 60.0 + float(k))
		k += 1
	for key: Vector2i in vt:
		if vt[key]:
			var a := o + Vector2(key) * sp
			var col := RED if ShopLight.hash1(s + float(k) * 0.9) < 0.5 else BLUE
			_ln(b, a + Vector2(0, 3), a + Vector2(0, sp - 3.0), col, s + 60.0 + float(k))
		k += 1
	var ta := String(d["a"])
	var tb := String(d["b"])
	var ca := 0
	var cb := 0
	for j in ny - 1:
		for i in nx - 1:
			if hz[Vector2i(i, j)] and hz[Vector2i(i, j + 1)] and vt[Vector2i(i, j)] and vt[Vector2i(i + 1, j)]:
				var mine := ShopLight.hash1(s + float(i) * 3.1 + float(j) * 7.3) < 0.5
				var at := o + Vector2(i, j) * sp
				if mine:
					ca += 1
					_say(b, ta[0], at.x + 4.0, at.y + 11.0, RED, s + 90.0 + float(i + j * 9))
				else:
					cb += 1
					_say(b, tb[0], at.x + 4.0, at.y + 11.0, BLUE, s + 90.0 + float(i + j * 9))
	for j in ny:
		for i in nx:
			b.draw_circle((o + Vector2(i, j) * sp).round(), 2.0, BLACK)
	var ha := "%s %d" % [ta, ca]
	_say(b, ha, 4, 12, RED, s + 1.0)
	_say(b, "%s %d" % [tb, cb], 4.0 + _tw(ha) + 10.0, 12, BLUE, s + 2.0)


static func _p_ttt(b: PostingBoard, d: Dictionary, s: float) -> void:
	var boards: Array = d["g"]
	var wins: Array = d["w"]
	for n in boards.size():
		var o := Vector2(4.0 + float(n) * 58.0, 4)
		var sn := s + float(n) * 20.0
		for k in 2:
			_ln(b, o + Vector2(16.0 + 16.0 * float(k), 0), o + Vector2(17.0 + 16.0 * float(k), 48), BLACK, sn + float(k))
			_ln(b, o + Vector2(0, 16.0 + 16.0 * float(k)), o + Vector2(48, 17.0 + 16.0 * float(k)), BLACK, sn + 2.0 + float(k))
		var g := String(boards[n])
		for c in 9:
			var cc := o + Vector2(float(c % 3), floorf(float(c) / 3.0)) * 16.0 + Vector2(8, 8)
			if g[c] == "X":
				_cross(b, cc, 4.0, RED, sn + 4.0 + float(c))
			elif g[c] == "O":
				b._wobble_circle(cc, 5.0, BLUE, sn + 4.0 + float(c))
		var wl: Array = wins[n]
		if wl.size() == 2:
			var a := o + Vector2(float(int(wl[0]) % 3), floorf(float(wl[0]) / 3.0)) * 16.0 + Vector2(8, 8)
			var e := o + Vector2(float(int(wl[1]) % 3), floorf(float(wl[1]) / 3.0)) * 16.0 + Vector2(8, 8)
			var dir := (e - a).normalized()
			_ln(b, a - dir * 6.0, e + dir * 6.0, GREEN, sn + 15.0)
	_say(b, String(d["cap"]), 4, 66, BLACK, s + 70.0)


static func _p_bars(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	var ls: Array = d["l"]
	var vs: Array = d["v"]
	var slot := maxf(16.0, _widest(ls) + 8.0)
	_say(b, String(d["t"]), 4, 12, BLACK, s)
	var base := z.y - 14.0
	_ln(b, Vector2(12, 18), Vector2(12, base), BLACK, s + 1.0)
	_ln(b, Vector2(10, base), Vector2(z.x - 4.0, base), BLACK, s + 2.0)
	var hmax := base - 24.0
	for k in ls.size():
		var col: Color = RED if k == int(d["hl"]) else d["c"]
		var x := 16.0 + float(k) * slot + (slot - 12.0) * 0.5
		var bh := float(vs[k]) * hmax
		var top := base - bh
		b._wobble_rect(Rect2(x, top, 12, bh), col, s + 10.0 + float(k))
		var yy := top + 4.0
		while yy + 2.0 < base - 1.0:
			b.draw_line(Vector2(x + 2.0, yy + 2.0), Vector2(x + 10.0, yy - 1.0), Color(col.r, col.g, col.b, 0.7), 1.0)
			yy += 4.0
		var t := String(ls[k])
		_say(b, t, 16.0 + float(k) * slot + (slot - _tw(t)) * 0.5, z.y - 2.0, BLACK, s + 20.0 + float(k))


static func _p_graph(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	var col: Color = d["c"]
	_say(b, String(d["t"]), 16, 12, BLACK, s)
	var base := z.y - 14.0
	_arrow(b, Vector2(10, base), Vector2(10, 6), BLACK, s + 1.0)
	_arrow(b, Vector2(10, base), Vector2(z.x - 5.0, base), BLACK, s + 2.0)
	var vs: Array = d["v"]
	var pts: Array = []
	for k in vs.size():
		pts.append(Vector2(18.0 + float(k) * (z.x - 34.0) / float(vs.size() - 1), base - 4.0 - float(vs[k]) * (base - 30.0)))
	_poly(b, pts, col, s + 3.0)
	for p: Vector2 in pts:
		_dot(b, p, col)
	var xl := String(d["xl"])
	_say(b, xl, z.x - 6.0 - _tw(xl), z.y - 2.0, BLACK, s + 4.0)
	var n := String(d["n"])
	if n != "":
		# a word in the empty top corner, and an arrow down to where it ends
		var lp: Vector2 = pts[pts.size() - 1]
		_say(b, n, z.x - 6.0 - _tw(n), 26, RED, s + 5.0)
		_arrow(b, Vector2(z.x - 10.0, 30), Vector2(lp.x + 1.0, lp.y - 5.0), RED, s + 6.0)


static func _p_pie(b: PostingBoard, d: Dictionary, s: float) -> void:
	var c := Vector2(30, 41)
	var r := 22.0
	var cols := [RED, BLUE, GREEN]
	_say(b, String(d["t"]), 4, 12, BLACK, s)
	b._wobble_circle(c, r, BLACK, s + 1.0)
	var fs: Array = d["f"]
	var ls: Array = d["l"]
	var ang := -PI * 0.5
	for k in fs.size():
		var dir := Vector2(cos(ang), sin(ang))
		_ln(b, c, c + dir * r, BLACK, s + 2.0 + float(k))
		var mid := ang + float(fs[k]) * PI
		var p := c + Vector2(cos(mid), sin(mid)) * r * 0.55
		_say(b, str(k + 1), p.x - 3.0, p.y + 4.0, cols[k % 3], s + 10.0 + float(k))
		ang += float(fs[k]) * TAU
		_say(b, "%d %s" % [k + 1, ls[k]], 60, 30.0 + 13.0 * float(k), cols[k % 3], s + 20.0 + float(k))


static func _p_venn(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	var cx := z.x * 0.5
	var cy := 42.0
	b._wobble_circle(Vector2(cx - 13.0, cy), 22.0, BLUE, s)
	b._wobble_circle(Vector2(cx + 13.0, cy), 22.0, RED, s + 1.0)
	var ta := String(d["a"])
	var tb := String(d["b"])
	_say(b, ta, 4, 12, BLUE, s + 2.0)
	_say(b, tb, z.x - 4.0 - _tw(tb), 12, RED, s + 3.0)
	_arrow(b, Vector2(cx, z.y - 14.0), Vector2(cx, cy + 4.0), BLACK, s + 4.0)
	var o := String(d["o"])
	_say(b, o, cx - _tw(o) * 0.5, z.y - 2.0, BLACK, s + 5.0)


static func _p_sum(b: PostingBoard, d: Dictionary, s: float) -> void:
	var lines: Array = d["l"]
	var big := bool(d.get("big", false))
	var step := 22.0 if big else 14.0
	var base0 := 22.0 if big else 14.0
	for k in lines.size():
		_say(b, String(lines[k]), 6, base0 + step * float(k), BLACK, s + float(k), big)
	var last := String(lines[lines.size() - 1])
	var idx := last.find("=")
	var pre := last.substr(0, idx + 1)
	var ans := last.substr(idx + 1).strip_edges()
	var x0 := 6.0 + _tw(pre, big) + (11.6 if big else 5.5)
	var aw := _tw(ans, big)
	var yb := base0 + step * float(lines.size() - 1)
	var hgt := 17.0 if big else 8.0
	_arc(b, Vector2(x0 + aw * 0.5 - 1.0, yb - hgt * 0.5), aw * 0.5 + 6.0, hgt * 0.5 + 5.0, -2.0, TAU - 2.4, RED, 20)
	_say(b, String(d["fix"]), 10, yb + 18.0, RED, s + 10.0)


## A COUNT KEPT BY HAND: each number struck out where it was written and the
## next one written after it, so they read in order up to the one ringed now
## (Jon: "why are these crossed out OUTSIDE of the circled letter").
static func _p_count(b: PostingBoard, d: Dictionary, s: float) -> void:
	_say(b, String(d["t"]), 4, 12, BLACK, s)
	var x := 4.0
	var olds: Array = d["old"]
	for k in olds.size():
		var o := String(olds[k])
		_say(b, o, x, 44, BLUE, s + 4.0 + float(k))
		_strike(b, x, 44, _tw(o), BLUE, s + 10.0 + float(k))
		x += _tw(o) + 8.0
	var n := String(d["n"])
	var cx := x + 18.0
	b._wobble_circle(Vector2(cx, 40), 18.0, RED, s + 1.0)
	_say(b, n, cx - _tw(n, true) * 0.5 + 1.0, 48, RED, s + 2.0, true)
	_say(b, String(d["u"]), cx + 24.0, 44, BLACK, s + 3.0)


static func _p_cake(b: PostingBoard, d: Dictionary, s: float) -> void:
	var col: Color = d["c"]
	b._wobble_rect(Rect2(8, 42, 46, 16), BLACK, s)
	b._wobble_rect(Rect2(13, 30, 36, 12), BLACK, s + 1.0)
	# icing, dripping over the bottom layer
	var pts: Array = []
	for k in 10:
		pts.append(Vector2(9.0 + float(k) * 5.0, 46.0 + (3.0 if k % 2 == 1 else 0.0)))
	_curve(b, pts, RED)
	var n := int(d["n"])
	for k in n:
		var x := 31.0 + (float(k) - float(n - 1) * 0.5) * 8.0
		_ln(b, Vector2(x, 29), Vector2(x, 21), BLUE, s + 2.0 + float(k))
		_poly(b, [Vector2(x - 2.0, 18), Vector2(x, 12), Vector2(x + 2.0, 18)], RED, s + 8.0 + float(k))
	_ln(b, Vector2(4, 62), Vector2(58, 61), BLACK, s + 20.0)
	_caption(b, d["t"], 64, 66, col, s + 30.0)


static func _p_cat(b: PostingBoard, d: Dictionary, s: float) -> void:
	var no := bool(d["no"])
	var o := Vector2(12, 8) if no else Vector2(6, 6)
	b._wobble_circle(o + Vector2(14, 16), 9.0, BLACK, s)
	_poly(b, [o + Vector2(7, 11), o + Vector2(8, 2), o + Vector2(13, 8)], BLACK, s + 1.0)
	_poly(b, [o + Vector2(16, 8), o + Vector2(21, 2), o + Vector2(22, 11)], BLACK, s + 2.0)
	_dot(b, o + Vector2(11, 15), BLACK)
	_dot(b, o + Vector2(18, 15), BLACK)
	for k in 2:
		var y := 19.0 + float(k) * 3.0
		b.draw_line((o + Vector2(9, y)).round(), (o + Vector2(2, y - 1.0 + float(k) * 3.0)).round(), BLACK, 1.0)
		b.draw_line((o + Vector2(20, y)).round(), (o + Vector2(27, y - 1.0 + float(k) * 3.0)).round(), BLACK, 1.0)
	_arc(b, o + Vector2(14, 38), 11.0, 13.0, -1.0, PI + 1.0, BLACK, 16)
	_curve(b, [o + Vector2(24, 48), o + Vector2(31, 47), o + Vector2(35, 41), o + Vector2(34, 34), o + Vector2(31, 31)], BLACK)
	if no:
		var c := Vector2(28, 34)
		b._wobble_circle(c, 25.0, RED, s + 4.0)
		_ln(b, c + Vector2(-17, -17), c + Vector2(17, 17), RED, s + 5.0)
	_caption(b, d["t"], 60.0 if no else 50.0, 64, BLUE if not no else RED, s + 10.0)


static func _p_drone(b: PostingBoard, d: Dictionary, s: float) -> void:
	var o := Vector2(4, 10)
	b._wobble_rect(Rect2(o.x + 10.0, o.y + 12.0, 28, 14), BLACK, s)
	b._wobble_circle(o + Vector2(24, 19), 4.0, BLUE, s + 1.0)
	_dot(b, o + Vector2(24, 19), BLUE)
	_ln(b, o + Vector2(10, 14), o + Vector2(4, 6), BLACK, s + 2.0)
	_ln(b, o + Vector2(38, 14), o + Vector2(44, 6), BLACK, s + 3.0)
	# the rotors, a blur seen edge-on
	_arc(b, o + Vector2(4, 4), 7.0, 2.0, 0.0, TAU, BLACK, 12)
	_arc(b, o + Vector2(44, 4), 7.0, 2.0, 0.0, TAU, BLACK, 12)
	_ln(b, o + Vector2(14, 26), o + Vector2(12, 32), BLACK, s + 6.0)
	_ln(b, o + Vector2(34, 26), o + Vector2(36, 32), BLACK, s + 7.0)
	var bub := String(d["bub"])
	var lines: Array = d["t"]
	if bub != "":
		b._wobble_rect(Rect2(62, 6, _tw(bub) + 8.0, 15), BLACK, s + 8.0)
		_ln(b, Vector2(64, 21), Vector2(52, 26), BLACK, s + 9.0)
		_say(b, bub, 66, 18, BLACK, s + 10.0)
		for k in lines.size():
			_say(b, String(lines[k]), 62, 38.0 + 13.0 * float(k), BLUE, s + 11.0 + float(k))
	else:
		_caption(b, lines, 62, 50, BLUE, s + 11.0)


static func _p_stick(b: PostingBoard, d: Dictionary, s: float) -> void:
	var t: Array = d["t"]
	match String(d["p"]):
		"wave":
			_fig(b, Vector2(16, 60), BLACK, s, [Vector2(-6, 8), Vector2(8, -10)])
			_ln(b, Vector2(28, 25), Vector2(31, 22), BLACK, s + 6.0)
			_ln(b, Vector2(30, 30), Vector2(34, 28), BLACK, s + 7.0)
			var w := _tw(String(t[0]))
			b._wobble_rect(Rect2(36, 6, w + 10.0, 15), BLUE, s + 8.0)
			_ln(b, Vector2(38, 21), Vector2(24, 26), BLUE, s + 9.0)
			_say(b, String(t[0]), 41, 18, BLUE, s + 10.0)
		"two":
			_fig(b, Vector2(14, 60), BLACK, s, [Vector2(-6, 8), Vector2(14, 4)])
			_fig(b, Vector2(44, 60), BLUE, s + 10.0, [Vector2(-14, 4), Vector2(6, 8)])
			_say(b, String(t[0]), 14.0 - _tw(String(t[0])) * 0.5, 20, BLACK, s + 20.0)
			_say(b, String(t[1]), 44.0 - _tw(String(t[1])) * 0.5, 20, BLUE, s + 21.0)
			_heart(b, Vector2(29, 27), 0.3, RED)
			_caption(b, [t[2], t[3]], 66, 64, RED, s + 22.0)
		"lift":
			_fig(b, Vector2(22, 62), BLACK, s, [Vector2(-8, -12), Vector2(8, -12)])
			b._wobble_rect(Rect2(8, 12, 28, 14), RED, s + 6.0)
			_ln(b, Vector2(37, 32), Vector2(41, 30), BLUE, s + 7.0)
			_ln(b, Vector2(37, 37), Vector2(42, 37), BLUE, s + 8.0)
			_caption(b, t, 48, 66, BLACK, s + 10.0)
		_:
			# asleep in a bunk: headboard, pillow, a head, a lumpy blanket
			_ln(b, Vector2(6, 30), Vector2(6, 56), BLACK, s)
			_ln(b, Vector2(6, 48), Vector2(100, 48), BLACK, s + 1.0)
			_ln(b, Vector2(100, 48), Vector2(100, 56), BLACK, s + 2.0)
			b._wobble_rect(Rect2(11, 37, 14, 8), BLACK, s + 3.0)
			b._wobble_circle(Vector2(22, 36), 6.0, BLUE, s + 4.0)
			_curve(b, [Vector2(28, 46), Vector2(30, 38), Vector2(44, 36), Vector2(60, 39), Vector2(76, 38),
				Vector2(88, 33), Vector2(94, 38), Vector2(96, 46)], BLUE)
			_say(b, "Z", 34, 26, BLACK, s + 8.0)
			_say(b, "Z", 46, 22, BLACK, s + 9.0, true)
			_say(b, String(t[0]), 4, 68, RED, s + 10.0)


static func _p_planet(b: PostingBoard, d: Dictionary, s: float) -> void:
	var c := Vector2(30, 36)
	var r := 14.0
	_arc(b, c, 27.0, 7.0, PI, PI + 0.95, BLUE, 6)
	_arc(b, c, 27.0, 7.0, TAU - 0.95, TAU, BLUE, 6)
	b._wobble_circle(c, r, BLACK, s)
	_arc(b, c + Vector2(0, -5), r * 0.8, 3.0, 0.3, PI - 0.3, BLACK, 8)
	_arc(b, c, 27.0, 7.0, 0.0, PI, BLUE, 18)
	for p: Vector2 in [Vector2(6, 10), Vector2(56, 58), Vector2(10, 58)]:
		b.draw_line(p + Vector2(-2, 0), p + Vector2(2, 0), BLACK, 1.0)
		b.draw_line(p + Vector2(0, -2), p + Vector2(0, 2), BLACK, 1.0)
	if bool(d["moon"]):
		b._wobble_circle(Vector2(52, 12), 4.0, BLACK, s + 1.0)
	if bool(d["flag"]):
		_ln(b, Vector2(30, 22), Vector2(30, 6), BLACK, s + 2.0)
		_poly(b, [Vector2(30, 6), Vector2(40, 9), Vector2(30, 13)], RED, s + 3.0)
	_caption(b, d["t"], 62, 64, BLUE, s + 10.0)


static func _p_rocket(b: PostingBoard, d: Dictionary, s: float) -> void:
	_poly(b, [Vector2(12, 44), Vector2(12, 18), Vector2(20, 4), Vector2(28, 18), Vector2(28, 44)], BLACK, s, true)
	b._wobble_circle(Vector2(20, 24), 4.0, BLUE, s + 1.0)
	_poly(b, [Vector2(12, 34), Vector2(5, 46), Vector2(12, 44)], BLACK, s + 2.0)
	_poly(b, [Vector2(28, 34), Vector2(35, 46), Vector2(28, 44)], BLACK, s + 3.0)
	_curve(b, [Vector2(14, 46), Vector2(16, 53), Vector2(18, 48), Vector2(20, 58), Vector2(22, 48), Vector2(24, 53), Vector2(26, 46)], RED)
	_caption(b, d["t"], 44, 62, RED, s + 10.0)


static func _p_here(b: PostingBoard, d: Dictionary, s: float) -> void:
	_say(b, String(d["t"]), 4, 12, d["tc"], s)
	var rooms: Array = d["rm"]
	for k in rooms.size():
		var r: Array = rooms[k]
		b._wobble_rect(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])), BLACK, s + 2.0 + float(k) * 4.0)
		_say(b, String(r[4]), float(r[0]) + 4.0, float(r[1]) + 12.0, BLUE, s + 30.0 + float(k))
	var mk: Array = d["mk"]
	_cross(b, Vector2(float(mk[0]), float(mk[1])), 4.0, RED, s + 40.0)
	var ar: Array = d["ar"]
	_arrow(b, Vector2(float(ar[0]), float(ar[1])), Vector2(float(ar[2]), float(ar[3])), RED, s + 41.0)
	if d.has("lb"):
		var lb: Array = d["lb"]
		_say(b, String(lb[0]), float(lb[1]), float(lb[2]), RED, s + 42.0)


static func _p_ring(b: PostingBoard, d: Dictionary, s: float) -> void:
	var c := Vector2(36, 37)
	b._wobble_circle(c, 30.0, BLACK, s)
	b._wobble_circle(c, 14.0, BLACK, s + 1.0)
	b._wobble_circle(c, 4.0, BLACK, s + 2.0)
	for k in 4:
		var a := PI * 0.25 + float(k) * PI * 0.5
		var dir := Vector2(cos(a), sin(a))
		_ln(b, c + dir * 14.0, c + dir * 30.0, BLACK, s + 3.0 + float(k))
	var ang := float(d["ang"])
	var mk := c + Vector2(cos(ang), sin(ang)) * 22.0
	_cross(b, mk, 4.0, RED, s + 10.0)
	var lines: Array = d["t"]
	_caption(b, lines, 76, 74, RED, s + 20.0)
	if absf(cos(ang)) < 0.5 or cos(ang) < 0.0:
		_arrow(b, Vector2(74, 30), mk + Vector2(6, -3), RED, s + 30.0)


static func _p_tear(b: PostingBoard, d: Dictionary, s: float) -> void:
	var t := String(d["t"])
	_title(b, t, BLACK, s)
	_say(b, String(d["s2"]), 4, 27, BLUE, s + 1.0)
	var y0 := 33.0
	var x := 4.0
	while x < 124.0:
		b.draw_line(Vector2(x, y0), Vector2(x + 3.0, y0), BLACK, 1.0)
		x += 6.0
	for k in 5:
		var tx := 4.0 + float(k) * 30.0
		var y := y0
		while y < 62.0:
			b.draw_line(Vector2(tx, y), Vector2(tx, y + 3.0), BLACK, 1.0)
			y += 6.0
		if k < 4 and k != 1:
			_say(b, String(d["nm"]), tx + 4.0, 46, BLACK, s + 10.0 + float(k))
			_say(b, String(d["ph"]), tx + 4.0, 58, RED, s + 20.0 + float(k))


static func _p_rota(b: PostingBoard, d: Dictionary, s: float) -> void:
	var t := String(d["t"])
	_title(b, t, GREEN, s)
	var days: Array = d["d"]
	var names: Array = d["n"]
	var cw := 22.0
	var n := names.size()
	for k in 3:
		var y := [20.0, 34.0, 50.0][k] as float
		_ln(b, Vector2(4, y), Vector2(4.0 + float(n) * cw, y + 1.0), BLACK, s + 1.0 + float(k))
	for k in n + 1:
		var x := 4.0 + float(k) * cw
		_ln(b, Vector2(x, 20), Vector2(x + 1.0, 50), BLACK, s + 5.0 + float(k))
	var crossed := int(d["x"])
	for k in n:
		var x := 4.0 + float(k) * cw
		var dy := String(days[k])
		var nm := String(names[k])
		_say(b, dy, x + (cw - _tw(dy)) * 0.5, 31, BLUE, s + 12.0 + float(k))
		_say(b, nm, x + (cw - _tw(nm)) * 0.5, 46, BLACK, s + 20.0 + float(k))
		if k == crossed:
			_cross(b, Vector2(x + cw * 0.5, 42), 6.0, RED, s + 30.0)
	var r := String(d["r"])
	if crossed >= 0:
		var cx := 4.0 + (float(crossed) + 0.5) * cw
		_say(b, r, clampf(cx - _tw(r) * 0.5, 4.0, 4.0 + float(n) * cw - _tw(r)), 62, RED, s + 31.0)
	else:
		_say(b, r, 4, 62, RED, s + 31.0)


static func _p_quote(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	var lines: Array = d["l"]
	for k in lines.size():
		_say(b, String(lines[k]), 6, 12.0 + 13.0 * float(k), d["c"], s + float(k))
	var by := String(d["by"])
	_say(b, by, z.x - 6.0 - _tw(by), 12.0 + 13.0 * float(lines.size() - 1) + 15.0, d["bc"], s + 10.0)


static func _p_rule(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	var col: Color = d["c"]
	var sym := bool(d["sym"])
	var x0 := 36.0 if sym else 11.0
	b._wobble_rect(Rect2(4, 4, z.x - 8.0, z.y - 8.0), col, s)
	var lines: Array = d["l"]
	for k in lines.size():
		_say(b, String(lines[k]), x0, 20.0 + 13.0 * float(k), col, s + 5.0 + float(k))
	if sym:
		var c := Vector2(20, z.y * 0.5)
		b._wobble_circle(c, 10.0, RED, s + 10.0)
		_ln(b, c + Vector2(-7, -7), c + Vector2(7, 7), RED, s + 11.0)
	else:
		var last := String(lines[lines.size() - 1])
		var y := 20.0 + 13.0 * float(lines.size() - 1) + 3.0
		_ln(b, Vector2(x0, y), Vector2(x0 + _tw(last), y + 1.0), col, s + 12.0)


static func _p_poll(b: PostingBoard, d: Dictionary, s: float) -> void:
	_title(b, String(d["t"]), BLACK, s)
	var os: Array = d["o"]
	var ns: Array = d["n"]
	var tx := 6.0 + _widest(os) + 10.0
	var cols := [BLUE, RED, GREEN]
	for k in os.size():
		var y := 29.0 + 14.0 * float(k)
		_say(b, String(os[k]), 6, y, BLACK, s + 2.0 + float(k))
		_tally(b, tx, y - 9.0, int(ns[k]), 10, cols[k % 3], s + 10.0 + float(k) * 10.0)


static func _p_week(b: PostingBoard, d: Dictionary, s: float) -> void:
	_title(b, String(d["t"]), BLACK, s)
	var days := ["M", "T", "W", "T", "F", "S", "S"]
	_ln(b, Vector2(4, 20), Vector2(116, 21), BLACK, s + 1.0)
	_ln(b, Vector2(4, 38), Vector2(116, 38), BLACK, s + 2.0)
	for k in 8:
		_ln(b, Vector2(4.0 + float(k) * 16.0, 20), Vector2(4.0 + float(k) * 16.0, 38), BLACK, s + 3.0 + float(k))
	for k in 7:
		_say(b, days[k], 4.0 + float(k) * 16.0 + 5.0, 33, BLUE, s + 12.0 + float(k))
		if k < int(d["x"]):
			_cross(b, Vector2(12.0 + float(k) * 16.0, 29), 6.0, RED, s + 20.0 + float(k))
	var o := int(d["o"])
	var cx := 12.0 + float(o) * 16.0
	b._wobble_circle(Vector2(cx, 29), 11.0, GREEN, s + 30.0)
	var n := String(d["n"])
	var nx := clampf(cx - _tw(n) * 0.5, 4.0, 118.0 - _tw(n))
	_arrow(b, Vector2(cx, 50), Vector2(cx, 42), GREEN, s + 31.0)
	_say(b, n, nx, 61, GREEN, s + 32.0)


static func _p_wanted(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	_say(b, "WANTED", 8, 22, RED, s, true)
	b._wobble_rect(Rect2(24, 30, 64, 42), BLACK, s + 1.0)
	if String(d["what"]) == "mug":
		_mug(b, Vector2(46, 44), BLUE, s + 2.0)
		_say(b, "?", 72, 52, RED, s + 3.0)
	else:
		# a cake on a plate, side on, with a step cut out of it where a slice was
		_ln(b, Vector2(30, 66), Vector2(84, 66), BLACK, s + 2.0)
		_poly(b, [Vector2(34, 64), Vector2(34, 44), Vector2(62, 44), Vector2(62, 54), Vector2(80, 54), Vector2(80, 64)], BLUE, s + 3.0, true)
		_ln(b, Vector2(36, 52), Vector2(60, 52), RED, s + 4.0)
		_ln(b, Vector2(36, 59), Vector2(78, 59), RED, s + 5.0)
		b._wobble_circle(Vector2(46, 39), 3.0, RED, s + 6.0)
		for p: Vector2 in [Vector2(68, 50), Vector2(73, 48), Vector2(77, 51)]:
			_dot(b, p, BLUE)
	var lines: Array = d["l"]
	for k in lines.size():
		var t := String(lines[k])
		_say(b, t, (z.x - _tw(t)) * 0.5, 88.0 + 13.0 * float(k), BLACK if k == 0 else BLUE, s + 10.0 + float(k))


static func _p_sun(b: PostingBoard, d: Dictionary, s: float) -> void:
	var c := Vector2(26, 29)
	b._wobble_circle(c, 13.0, RED, s)
	for k in 10:
		var a := float(k) * TAU / 10.0 + 0.2
		var dir := Vector2(cos(a), sin(a))
		_ln(b, c + dir * 16.0, c + dir * 23.0, RED, s + 1.0 + float(k))
	# the sunglasses, scribbled in
	for e in 2:
		var x := c.x - 10.0 + float(e) * 11.0
		b._wobble_rect(Rect2(x, c.y - 6.0, 8, 5), BLACK, s + 20.0 + float(e) * 4.0)
		b.draw_line(Vector2(x + 1.0, c.y - 4.0), Vector2(x + 7.0, c.y - 4.0), BLACK, 2.0)
	_ln(b, Vector2(c.x - 2.0, c.y - 5.0), Vector2(c.x + 1.0, c.y - 5.0), BLACK, s + 30.0)
	_arc(b, c + Vector2(0, 1), 6.0, 5.0, 0.4, PI - 0.4, BLACK, 8)
	_caption(b, d["t"], 54, 58, BLACK, s + 40.0)


static func _p_ship(b: PostingBoard, d: Dictionary, s: float) -> void:
	if int(d["v"]) == 0:
		_poly(b, [Vector2(30, 36), Vector2(46, 26), Vector2(96, 26), Vector2(118, 36), Vector2(96, 48), Vector2(46, 48)], BLUE, s, true)
		b._wobble_rect(Rect2(16, 30, 14, 12), BLUE, s + 1.0)
		_ln(b, Vector2(12, 33), Vector2(5, 33), RED, s + 2.0)
		_ln(b, Vector2(12, 39), Vector2(4, 39), RED, s + 3.0)
		b._wobble_circle(Vector2(104, 36), 3.0, BLUE, s + 4.0)
		_ln(b, Vector2(62, 26), Vector2(62, 48), BLUE, s + 5.0)
		_say(b, "ENGINE", 4, 66, BLACK, s + 10.0)
		_arrow(b, Vector2(18, 56), Vector2(21, 45), BLACK, s + 11.0)
		_say(b, "BUNKS", 44, 12, BLACK, s + 12.0)
		_arrow(b, Vector2(56, 15), Vector2(52, 31), BLACK, s + 13.0)
		_say(b, "LEAK?", 76, 74, RED, s + 14.0)
		_arrow(b, Vector2(86, 63), Vector2(80, 51), RED, s + 15.0)
		_say(b, "ME", 110, 14, BLUE, s + 16.0)
		_arrow(b, Vector2(112, 17), Vector2(106, 31), BLUE, s + 17.0)
	else:
		# a hauler: a cab and three cans of cargo
		b._wobble_rect(Rect2(98, 30, 22, 20), BLACK, s)
		_ln(b, Vector2(120, 34), Vector2(127, 40), BLACK, s + 1.0)
		_ln(b, Vector2(127, 40), Vector2(120, 47), BLACK, s + 2.0)
		for k in 3:
			b._wobble_rect(Rect2(12.0 + float(k) * 28.0, 28, 24, 24), GREEN, s + 3.0 + float(k) * 4.0)
		_ln(b, Vector2(8, 40), Vector2(96, 40), BLACK, s + 20.0)
		_say(b, "CARGO", 22, 14, GREEN, s + 21.0)
		_arrow(b, Vector2(40, 17), Vector2(40, 26), GREEN, s + 22.0)
		_say(b, "CAB", 94, 14, BLACK, s + 23.0)
		_arrow(b, Vector2(106, 17), Vector2(108, 28), BLACK, s + 24.0)
		_say(b, "DO NOT LICK", 30, 72, RED, s + 25.0)
		_arrow(b, Vector2(26, 69), Vector2(20, 56), RED, s + 26.0)


static func _p_flow(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	var q := String(d["q"])
	var cx := z.x * 0.5
	var qx := cx - _tw(q) * 0.5
	b._wobble_rect(Rect2(qx - 5.0, 4, _tw(q) + 10.0, 15), BLACK, s)
	_say(b, q, qx, 16, BLACK, s + 1.0)
	var lx := z.x * 0.25 + 2.0
	var rx := z.x * 0.75 - 2.0
	_arrow(b, Vector2(cx - 8.0, 22), Vector2(lx, 38), BLACK, s + 2.0)
	_arrow(b, Vector2(cx + 8.0, 22), Vector2(rx, 38), BLACK, s + 3.0)
	_say(b, "YES", (cx - 8.0 + lx) * 0.5 - 26.0, 30, GREEN, s + 4.0)
	_say(b, "NO", (cx + 8.0 + rx) * 0.5 + 8.0, 30, RED, s + 5.0)
	var ya := String(d["ya"])
	var na := String(d["na"])
	b._wobble_rect(Rect2(lx - _tw(ya) * 0.5 - 4.0, 44, _tw(ya) + 8.0, 16), GREEN, s + 6.0)
	_say(b, ya, lx - _tw(ya) * 0.5, 56, GREEN, s + 7.0)
	b._wobble_rect(Rect2(rx - _tw(na) * 0.5 - 4.0, 44, _tw(na) + 8.0, 16), RED, s + 8.0)
	_say(b, na, rx - _tw(na) * 0.5, 56, RED, s + 9.0)


static func _p_sign(b: PostingBoard, d: Dictionary, s: float) -> void:
	_title(b, String(d["t"]), d["c"], s)
	var slots := [Vector2(8, 38), Vector2(66, 36), Vector2(12, 56), Vector2(70, 58), Vector2(34, 72)]
	var cols := [BLACK, BLUE, GREEN, BLACK, RED]
	var names: Array = d["names"]
	for k in slots.size():
		var p: Vector2 = slots[k]
		var nm := String(names[k])
		if nm != "":
			_say(b, nm, p.x, p.y + 3.0, cols[k], s + 10.0 + float(k))
			_ln(b, Vector2(p.x - 2.0, p.y + 6.0), Vector2(p.x + _tw(nm) + 6.0, p.y + 5.0), cols[k], s + 20.0 + float(k))
		else:
			_squig(b, p, 40.0, cols[k], s + 30.0 + float(k) * 3.3)


static func _p_heart(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	var sc := float(d["sc"])
	var col: Color = d["c"]
	var hc := Vector2(z.x * 0.5, 12.0 * sc + 6.0)
	_heart(b, hc, sc, col)
	var t := String(d["t"])
	var arrow := bool(d["arrow"])
	_say(b, t, hc.x - _tw(t) * 0.5, hc.y + (0.0 if arrow else 4.0), col, s)
	if arrow:
		# through the heart, under the words
		var a := hc + Vector2(-16.0 * sc - 4.0, 14.0 * sc)
		var e := hc + Vector2(16.0 * sc + 4.0, -1.0 * sc)
		_arrow(b, a, e, BLACK, s + 1.0)
		var dir := (e - a).normalized()
		var n := Vector2(-dir.y, dir.x)
		for k in 2:
			var p := a + dir * (2.0 + float(k) * 4.0)
			_ln(b, p, p - dir * 4.0 + n * 4.0, BLACK, s + 2.0 + float(k))
			_ln(b, p, p - dir * 4.0 - n * 4.0, BLACK, s + 4.0 + float(k))


static func _p_face(b: PostingBoard, d: Dictionary, s: float) -> void:
	var f := String(d["f"])
	var col := BLACK
	if f == "frown":
		col = BLUE
	elif f == "wow":
		col = GREEN
	_face(b, Vector2(20, 20), 15.0, f, col, s)
	_caption(b, d["t"], 42, 40, BLACK, s + 10.0)


static func _p_erased(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	var lines: Array = d["l"]
	for k in lines.size():
		_say(b, String(lines[k]), 6, 14.0 + 14.0 * float(k), d["c"], s + float(k))
	var w := PostingBoard.WHITE
	var wx := float(d["wx"])
	var wy: Array = d["wy"]
	var y := float(wy[0]) - 12.0
	var k2 := 0
	while y < float(wy[1]) - 6.0:
		var off := float(k2 % 2) * 3.0
		b.draw_rect(Rect2(wx + off, y, z.x - 2.0 - wx - off, 6.0), Color(w.r, w.g, w.b, 0.8))
		y += 6.0
		k2 += 1
	var add: Array = d["add"]
	_say(b, String(add[0]), float(add[1]), float(add[2]), add[3], s + 10.0)


static func _p_iou(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	b._wobble_rect(Rect2(4, 4, z.x - 8.0, z.y - 8.0), BLACK, s)
	var lines: Array = d["l"]
	for k in lines.size():
		_say(b, String(lines[k]), 9, 18.0 + 13.0 * float(k), BLUE, s + 5.0 + float(k))
	var yb := 18.0 + 13.0 * float(lines.size() - 1) + 20.0
	var by := String(d["by"])
	_say(b, by, 9, yb, BLACK, s + 10.0)
	var sx := 9.0 + _tw(by) + 8.0
	_squig(b, Vector2(sx, yb - 2.0), 30.0, BLACK, s + 11.0, by.trim_prefix("- ").left(1))
	if bool(d["paid"]):
		_say(b, "PAID!", sx + 40.0, yb, RED, s + 12.0)
		_ln(b, Vector2(8, z.y - 10.0), Vector2(z.x - 10.0, 10), RED, s + 13.0)


static func _p_quiz(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	_title(b, String(d["t"]), BLUE, s)
	var rows: Array = d["r"]
	var best := -1
	var top := -999
	for k in rows.size():
		if int(rows[k][1]) > top:
			top = int(rows[k][1])
			best = k
	for k in rows.size():
		var y := 30.0 + 13.0 * float(k)
		var sc := String(rows[k][1])
		_say(b, String(rows[k][0]), 6, y, BLACK, s + 2.0 + float(k))
		var sx := z.x - 9.0 - _tw(sc)
		_say(b, sc, sx, y, RED, s + 10.0 + float(k))
		if k == best:
			_arc(b, Vector2(sx + _tw(sc) * 0.5 - 1.0, y - 4.0), _tw(sc) * 0.5 + 4.0, 7.5, -2.0, TAU - 2.4, GREEN, 16)


static func _p_bounty(b: PostingBoard, d: Dictionary, s: float) -> void:
	var t := String(d["t"])
	_say(b, t, 4, 12, RED, s)
	_ln(b, Vector2(3, 15), Vector2(5.0 + _tw(t), 16), RED, s + 0.5)
	_say(b, String(d["l"]), 4, 74, BLACK, s + 10.0)
	# the salamander: a body that thickens toward the head, four legs, a curl of tail
	var up: Array = []
	var dn: Array = []
	for k in 21:
		var x := 20.0 + float(k) * 4.0
		var th := _sal_th(x)
		up.append(Vector2(x, _sal_y(x) - th))
		dn.append(Vector2(x, _sal_y(x) + th))
	_curve(b, up, BLACK)
	_curve(b, dn, BLACK)
	# the flat wide head, a mouth, an eye
	var hy := _sal_y(100.0)
	_arc(b, Vector2(108, hy), 12.0, 10.0, -(PI - 0.85), PI - 0.85, BLACK, 16)
	b.draw_circle(Vector2(111, hy - 4.0), 1.8, BLACK)
	_ln(b, Vector2(108, hy + 4.0), Vector2(119, hy + 2.0), BLACK, s + 1.0)
	# four stubby legs, three toes each
	for k in 2:
		var x := 46.0 + float(k) * 34.0
		var th := _sal_th(x)
		var y := _sal_y(x)
		for side in 2:
			var sg := -1.0 if side == 0 else 1.0
			var root := Vector2(x, y + sg * th)
			var foot := root + Vector2(5, sg * 8.0)
			_ln(b, root, foot, BLACK, s + 2.0 + float(k * 2 + side))
			for toe in 3:
				b.draw_line(foot.round(), (foot + Vector2(float(toe) * 2.0 - 1.0, sg * 3.0)).round(), BLACK, 1.0)
	# the tail runs out thin and curls
	_arc(b, Vector2(18, _sal_y(20.0) - 3.0), 3.0, 3.0, 0.5, TAU - 0.5, BLACK, 8)
	for k in 5:
		var x := 50.0 + float(k) * 10.0
		b.draw_circle(Vector2(x, _sal_y(x) - 1.0).round(), 1.6, RED)


static func _sal_y(x: float) -> float:
	return 42.0 + sin(x * 0.09) * 3.0


static func _sal_th(x: float) -> float:
	return lerpf(1.5, 8.0, clampf((x - 20.0) / 76.0, 0.0, 1.0))


static func _p_swarm(b: PostingBoard, d: Dictionary, s: float) -> void:
	var c := Vector2(30, 34)
	for k in 46:
		var a := ShopLight.hash1(s + float(k) * 1.7) * TAU
		var rr := sqrt(ShopLight.hash1(s + float(k) * 2.3 + 0.5)) * 24.0
		_dot(b, c + Vector2(cos(a) * rr, sin(a) * rr * 0.8), BLACK)
	_caption(b, d["t"], 62, 66, RED, s + 10.0)


static func _p_thermo(b: PostingBoard, d: Dictionary, s: float) -> void:
	_ln(b, Vector2(12, 52), Vector2(12, 10), BLACK, s)
	_ln(b, Vector2(20, 52), Vector2(20, 10), BLACK, s + 1.0)
	_arc(b, Vector2(16, 10), 4.0, 4.0, PI, TAU, BLACK, 6)
	b._wobble_circle(Vector2(16, 58), 7.0, BLACK, s + 2.0)
	var top := lerpf(52.0, 12.0, float(d["lv"]))
	b.draw_line(Vector2(15, 58), Vector2(15, top), RED, 2.0)
	b.draw_line(Vector2(17, 58), Vector2(17, top), RED, 2.0)
	b.draw_circle(Vector2(16, 58), 4.0, RED)
	for k in 6:
		var y := 16.0 + float(k) * 7.0
		b.draw_line(Vector2(22, y), Vector2(25, y), BLACK, 1.0)
	var t: Array = d["t"]
	_say(b, String(t[0]), 34, 30, RED, s + 10.0, true)
	_say(b, String(t[1]), 34, 50, BLACK, s + 11.0)
	_ln(b, Vector2(34, 54), Vector2(34.0 + _tw(String(t[1])), 55), RED, s + 12.0)


static func _p_clock(b: PostingBoard, d: Dictionary, s: float) -> void:
	var c := Vector2(22, 24)
	b._wobble_circle(c, 17.0, BLACK, s)
	for k in 12:
		var a := float(k) * TAU / 12.0
		var p := c + Vector2(cos(a), sin(a)) * 13.0
		b.draw_line(p.round(), p.round() + Vector2(1, 0), BLACK, 1.0)
	var h := float(d["h"])
	var m := float(d["m"])
	var ha := (fmod(h, 12.0) + m / 60.0) * TAU / 12.0 - PI * 0.5
	var ma := m * TAU / 60.0 - PI * 0.5
	_ln(b, c, c + Vector2(cos(ha), sin(ha)) * 8.0, RED, s + 1.0)
	_ln(b, c, c + Vector2(cos(ma), sin(ma)) * 12.0, RED, s + 2.0)
	_caption(b, d["t"], 48, 48, BLUE, s + 10.0)


static func _p_chat(b: PostingBoard, d: Dictionary, s: float) -> void:
	var ls: Array = d["l"]
	for k in ls.size():
		_say(b, String(ls[k][0]), 6.0 + float(k % 2) * 12.0, 13.0 + 13.0 * float(k), ls[k][1], s + float(k) * 2.0)


static func _p_stars(b: PostingBoard, d: Dictionary, s: float) -> void:
	_title(b, String(d["t"]), BLACK, s)
	var rows: Array = d["r"]
	var names: Array = []
	for r in rows:
		names.append(r[0])
	var sx := 6.0 + _widest(names) + 8.0
	for k in rows.size():
		var y := 29.0 + 14.0 * float(k)
		_say(b, String(rows[k][0]), 6, y, BLUE, s + 2.0 + float(k))
		for j in 5:
			var c := Vector2(sx + float(j) * 12.0 + 5.0, y - 4.0)
			if j < int(rows[k][1]):
				_star(b, c, 5.0, d["c"])
			else:
				_dot(b, c, BLACK)


static func _p_jump(b: PostingBoard, d: Dictionary, s: float) -> void:
	_title(b, String(d["t"]), BLUE, s)
	var ps: Array = d["p"]
	for k in ps.size() - 1:
		var a := Vector2(float(ps[k][0]), float(ps[k][1]))
		var e := Vector2(float(ps[k + 1][0]), float(ps[k + 1][1]))
		var n := int((e - a).length() / 7.0)
		for j in n:
			if j == 0:
				continue
			var p0 := a.lerp(e, float(j) / float(n))
			var p1 := a.lerp(e, (float(j) + 0.5) / float(n))
			b.draw_line(p0.round(), p1.round(), BLACK, 2.0)
	for k in ps.size():
		var p := Vector2(float(ps[k][0]), float(ps[k][1]))
		var last := k == ps.size() - 1
		if last:
			_cross(b, p, 4.0, RED, s + 10.0)
		else:
			b._wobble_circle(p, 3.0, BLACK, s + 10.0 + float(k))
		var lb := String(ps[k][2])
		if lb != "":
			var lx := p.x + 7.0 if p.x + 7.0 + _tw(lb) < 132.0 else p.x - 7.0 - _tw(lb)
			_say(b, lb, lx, p.y + 4.0, RED if last else BLUE, s + 20.0 + float(k))


static func _p_crate(b: PostingBoard, d: Dictionary, s: float) -> void:
	_poly(b, [Vector2(8, 26), Vector2(70, 26), Vector2(70, 62), Vector2(8, 62)], BLACK, s, true)
	_poly(b, [Vector2(8, 26), Vector2(20, 14), Vector2(82, 14), Vector2(70, 26)], BLACK, s + 2.0)
	_poly(b, [Vector2(82, 14), Vector2(82, 50), Vector2(70, 62)], BLACK, s + 4.0)
	_say(b, "FRAGILE", 12, 48, RED, s + 6.0)
	_arrow(b, Vector2(76, 46), Vector2(76, 28), BLUE, s + 7.0)
	_say(b, String(d["t"]), 4, 78, BLUE, s + 8.0)


static func _p_bingo(b: PostingBoard, d: Dictionary, s: float) -> void:
	var head := "BINGO"
	for k in 5:
		_say(b, head[k], 4.0 + float(k) * 20.0 + 7.0, 14, RED, s + float(k))
	for k in 4:
		_ln(b, Vector2(4, 18.0 + float(k) * 16.0), Vector2(104, 18.0 + float(k) * 16.0 + 1.0), BLACK, s + 5.0 + float(k))
	for k in 6:
		_ln(b, Vector2(4.0 + float(k) * 20.0, 18), Vector2(4.0 + float(k) * 20.0 + 1.0, 66), BLACK, s + 10.0 + float(k))
	var ns: Array = d["n"]
	var xs: Array = d["x"]
	for k in ns.size():
		var col := k % 5
		var row := floori(float(k) / 5.0)
		var x := 4.0 + float(col) * 20.0
		var y := 18.0 + float(row) * 16.0
		var t := String(ns[k])
		if t == "FREE":
			_star(b, Vector2(x + 10.0, y + 8.0), 5.0, GREEN)
		else:
			_say(b, t, x + (20.0 - _tw(t)) * 0.5, y + 12.0, BLACK, s + 20.0 + float(k))
		if xs.has(k):
			_cross(b, Vector2(x + 10.0, y + 8.0), 6.0, BLUE, s + 40.0 + float(k))


static func _p_crown(b: PostingBoard, d: Dictionary, s: float) -> void:
	_poly(b, [Vector2(8, 36), Vector2(8, 18), Vector2(16, 27), Vector2(24, 10), Vector2(32, 27), Vector2(40, 18), Vector2(40, 36)], RED, s, true)
	for k in 3:
		_dot(b, Vector2(16.0 + float(k) * 8.0, 32), BLUE)
	_caption(b, d["t"], 50, 44, BLACK, s + 10.0)


static func _p_ghost(b: PostingBoard, d: Dictionary, s: float) -> void:
	_arc(b, Vector2(20, 22), 12.0, 12.0, PI, TAU, BLUE, 12)
	_ln(b, Vector2(8, 22), Vector2(8, 44), BLUE, s)
	_ln(b, Vector2(32, 22), Vector2(32, 44), BLUE, s + 1.0)
	_curve(b, [Vector2(8, 44), Vector2(12, 40), Vector2(16, 44), Vector2(20, 40), Vector2(24, 44), Vector2(28, 40), Vector2(32, 44)], BLUE)
	_dot(b, Vector2(16, 22), BLUE)
	_dot(b, Vector2(24, 22), BLUE)
	b._wobble_circle(Vector2(20, 31), 3.0, BLUE, s + 2.0)
	var t: Array = d["t"]
	_say(b, String(t[0]), 42, 18, BLACK, s + 10.0)
	_say(b, String(t[1]), 42, 31, BLACK, s + 11.0)
	_say(b, String(t[2]), 42, 50, RED, s + 12.0)


static func _p_plant(b: PostingBoard, d: Dictionary, s: float) -> void:
	_poly(b, [Vector2(10, 42), Vector2(30, 42), Vector2(27, 60), Vector2(13, 60)], RED, s, true)
	_ln(b, Vector2(7, 42), Vector2(33, 42), RED, s + 2.0)
	_ln(b, Vector2(20, 42), Vector2(20, 14), GREEN, s + 3.0)
	_curve(b, [Vector2(20, 32), Vector2(13, 29), Vector2(8, 23), Vector2(15, 24), Vector2(20, 30)], GREEN)
	_curve(b, [Vector2(20, 24), Vector2(27, 20), Vector2(32, 13), Vector2(25, 15), Vector2(20, 22)], GREEN)
	b._wobble_circle(Vector2(20, 11), 3.0, RED, s + 4.0)
	_caption(b, d["t"], 44, 64, GREEN, s + 10.0)


static func _p_queue(b: PostingBoard, d: Dictionary, s: float) -> void:
	_say(b, String(d["t"]), 4, 12, BLACK, s)
	b._wobble_rect(Rect2(8, 20, 46, 26), BLACK, s + 1.0)
	var n := String(d["n"])
	_say(b, n, 31.0 - _tw(n, true) * 0.5 + 1.0, 42, RED, s + 2.0, true)
	var me: Array = d["me"]
	for k in me.size():
		_say(b, String(me[k]), 62, 30.0 + 13.0 * float(k), BLUE, s + 3.0 + float(k))


static func _p_doodles(b: PostingBoard, d: Dictionary, s: float) -> void:
	var items: Array = d["set"]
	var cols := [BLUE, RED, GREEN]
	for k in items.size():
		var o := Vector2(4.0 + float(k) * 42.0, 4)
		var c := o + Vector2(19, 19)
		var col: Color = cols[k % 3]
		var sk := s + float(k) * 10.0
		match String(items[k]):
			"cube":
				_poly(b, [o + Vector2(4, 12), o + Vector2(26, 12), o + Vector2(26, 34), o + Vector2(4, 34)], col, sk, true)
				_poly(b, [o + Vector2(12, 4), o + Vector2(34, 4), o + Vector2(34, 26), o + Vector2(12, 26)], col, sk + 3.0, true)
				for v: Vector2 in [Vector2(4, 12), Vector2(26, 12), Vector2(26, 34), Vector2(4, 34)]:
					_ln(b, o + v, o + v + Vector2(8, -8), col, sk + 6.0 + v.x * 0.1 + v.y * 0.03)
			"spiral":
				var pts: Array = []
				for j in 48:
					var a := float(j) * 0.38
					pts.append(c + Vector2(cos(a), sin(a)) * (1.0 + float(j) * 0.34))
				_curve(b, pts, col)
			"star":
				_star(b, c, 15.0, col)
			"flower":
				for j in 5:
					var a := float(j) * TAU / 5.0 - PI * 0.5
					b._wobble_circle(o + Vector2(19, 15) + Vector2(cos(a), sin(a)) * 7.0, 4.0, col, sk + float(j))
				_dot(b, o + Vector2(19, 15), BLACK)
				_ln(b, o + Vector2(19, 26), o + Vector2(20, 38), GREEN, sk + 6.0)
			"zig":
				_poly(b, [o + Vector2(22, 2), o + Vector2(10, 20), o + Vector2(20, 20), o + Vector2(12, 38), o + Vector2(30, 14), o + Vector2(20, 14), o + Vector2(28, 2)], col, sk, true)
			"eye":
				_arc(b, c, 16.0, 11.0, PI + 0.2, TAU - 0.2, col, 12)
				_arc(b, c, 16.0, 11.0, 0.2, PI - 0.2, col, 12)
				b._wobble_circle(c, 6.0, col, sk + 1.0)
				b.draw_circle(c, 2.5, BLACK)


static func _p_comic(b: PostingBoard, d: Dictionary, s: float) -> void:
	_title(b, String(d["t"]), BLACK, s)
	var fs: Array = d["f"]
	var ls: Array = d["l"]
	var cols := [BLUE, BLACK, RED]
	for k in 3:
		var x := 4.0 + float(k) * 44.0
		b._wobble_rect(Rect2(x, 22, 38, 32), BLACK, s + 2.0 + float(k) * 4.0)
		_face(b, Vector2(x + 19.0, 38), 10.0, String(fs[k]), cols[k], s + 20.0 + float(k) * 4.0)
		var t := String(ls[k])
		_say(b, t, x + 19.0 - _tw(t) * 0.5, 68, BLACK, s + 40.0 + float(k))


static func _p_robot(b: PostingBoard, d: Dictionary, s: float) -> void:
	b._wobble_rect(Rect2(10, 16, 28, 22), BLACK, s)
	_ln(b, Vector2(24, 16), Vector2(24, 9), BLACK, s + 1.0)
	b._wobble_circle(Vector2(24, 6), 2.5, RED, s + 2.0)
	b._wobble_circle(Vector2(18, 24), 3.0, BLUE, s + 3.0)
	b._wobble_circle(Vector2(30, 24), 3.0, BLUE, s + 4.0)
	b._wobble_rect(Rect2(16, 30, 16, 5), BLACK, s + 5.0)
	for k in 3:
		b.draw_line(Vector2(20.0 + float(k) * 4.0, 30), Vector2(20.0 + float(k) * 4.0, 35), BLACK, 1.0)
	_ln(b, Vector2(7, 22), Vector2(7, 32), BLACK, s + 6.0)
	_ln(b, Vector2(41, 22), Vector2(41, 32), BLACK, s + 7.0)
	_ln(b, Vector2(20, 38), Vector2(20, 44), BLACK, s + 8.0)
	_ln(b, Vector2(28, 38), Vector2(28, 44), BLACK, s + 9.0)
	_ln(b, Vector2(8, 46), Vector2(40, 46), BLACK, s + 10.0)
	var t: Array = d["t"]
	if bool(d["bub"]):
		var w := _widest(t)
		b._wobble_rect(Rect2(52, 8, w + 10.0, 15), BLUE, s + 11.0)
		_ln(b, Vector2(54, 23), Vector2(44, 28), BLUE, s + 12.0)
		_say(b, String(t[0]), 57, 20, BLUE, s + 13.0)
	else:
		_caption(b, t, 52, 54, BLUE, s + 13.0)


static func _p_gauge(b: PostingBoard, d: Dictionary, s: float) -> void:
	var c := Vector2(30, 48)
	var r := 22.0
	_say(b, String(d["t"]), 4, 12, BLACK, s)
	_arc(b, c, r, r, PI, TAU, BLACK, 18)
	for k in 5:
		var a := PI + float(k) * PI * 0.25
		var dir := Vector2(cos(a), sin(a))
		b.draw_line((c + dir * (r - 5.0)).round(), (c + dir * (r - 1.0)).round(), BLACK, 2.0)
	var lo := String(d["lo"])
	var hi := String(d["hi"])
	_say(b, lo, c.x - r - 2.0, c.y + 10.0, RED, s + 1.0)
	_say(b, hi, c.x + r - _tw(hi) + 3.0, c.y + 10.0, GREEN, s + 2.0)
	var a := PI + float(d["a"]) * PI
	_ln(b, c, c + Vector2(cos(a), sin(a)) * (r - 4.0), RED, s + 3.0)
	b.draw_circle(c, 2.0, BLACK)
	_caption(b, d["cap"], 60, 66, BLUE, s + 10.0)


static func _p_lift(b: PostingBoard, s: float) -> void:
	b._wobble_rect(Rect2(6, 8, 24, 60), BLACK, s)
	for k in 4:
		_ln(b, Vector2(6, 20.0 + float(k) * 12.0), Vector2(30, 20.0 + float(k) * 12.0), BLACK, s + 1.0 + float(k))
	for k in 5:
		_say(b, str(5 - k), 15, 18.0 + float(k) * 12.0, BLUE, s + 6.0 + float(k))
	_ln(b, Vector2(4, 6), Vector2(32, 70), RED, s + 12.0)
	_ln(b, Vector2(32, 6), Vector2(4, 70), RED, s + 13.0)
	_poly(b, [Vector2(40, 66), Vector2(40, 58), Vector2(48, 58), Vector2(48, 50), Vector2(56, 50), Vector2(56, 42), Vector2(64, 42), Vector2(64, 34), Vector2(72, 34)], GREEN, s + 14.0)
	_arrow(b, Vector2(46, 44), Vector2(62, 28), GREEN, s + 20.0)
	_say(b, "LIFT OUT", 40, 14, RED, s + 21.0)
	_say(b, "USE THE", 78, 48, GREEN, s + 22.0)
	_say(b, "STAIRS", 78, 61, GREEN, s + 23.0)


static func _p_whale(b: PostingBoard, d: Dictionary, s: float) -> void:
	_arc(b, Vector2(44, 40), 34.0, 20.0, PI, TAU, BLUE, 20)
	_curve(b, [Vector2(10, 40), Vector2(18, 50), Vector2(44, 55), Vector2(70, 49), Vector2(78, 40)], BLUE)
	_poly(b, [Vector2(78, 40), Vector2(90, 33), Vector2(98, 24)], BLUE, s)
	_poly(b, [Vector2(90, 33), Vector2(102, 38)], BLUE, s + 2.0)
	_dot(b, Vector2(22, 36), BLACK)
	_ln(b, Vector2(12, 44), Vector2(26, 46), BLUE, s + 3.0)
	# it blows, even out here
	_ln(b, Vector2(24, 23), Vector2(24, 14), BLUE, s + 4.0)
	_ln(b, Vector2(24, 18), Vector2(19, 12), BLUE, s + 5.0)
	_ln(b, Vector2(24, 18), Vector2(29, 12), BLUE, s + 6.0)
	for k in 3:
		b.draw_line(Vector2(30.0 + float(k) * 10.0, 49), Vector2(36.0 + float(k) * 10.0, 50), BLUE, 1.0)
	for p: Vector2 in [Vector2(90, 10), Vector2(8, 12), Vector2(70, 8), Vector2(104, 52)]:
		b.draw_line(p + Vector2(-2, 0), p + Vector2(2, 0), BLACK, 1.0)
		b.draw_line(p + Vector2(0, -2), p + Vector2(0, 2), BLACK, 1.0)
	var t: Array = d["t"]
	_say(b, String(t[0]), 4, 72, BLACK, s + 10.0)
	_say(b, String(t[1]), 4, 85, RED, s + 11.0)


static func _p_spanner(b: PostingBoard, d: Dictionary, s: float) -> void:
	_say(b, String(d["t"]), 4, 21, RED, s, true)
	_ln(b, Vector2(22, 38), Vector2(78, 38), BLACK, s + 1.0)
	_ln(b, Vector2(22, 46), Vector2(78, 46), BLACK, s + 2.0)
	b._wobble_circle(Vector2(15, 42), 7.0, BLACK, s + 3.0)
	_arc(b, Vector2(87, 42), 10.0, 10.0, 0.7, TAU - 0.7, BLACK, 14)
	_ln(b, Vector2(94, 35), Vector2(88, 39), BLACK, s + 4.0)
	_ln(b, Vector2(94, 49), Vector2(88, 45), BLACK, s + 5.0)
	_say(b, String(d["l"]), 4, 70, BLUE, s + 10.0)


static func _p_arrow(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	var flip := bool(d["flip"])
	var col: Color = d["c"]
	var shape := [Vector2(4, 14), Vector2(68, 14), Vector2(68, 4), Vector2(94, 24), Vector2(68, 44), Vector2(68, 34), Vector2(4, 34)]
	var pts: Array = []
	for p: Vector2 in shape:
		pts.append(Vector2(z.x - p.x, p.y) if flip else p)
	_poly(b, pts, col, s, true)
	var t := String(d["t"])
	var tx := z.x - 9.0 - _tw(t) if flip else 9.0
	_say(b, t, tx, 28, BLACK, s + 10.0)
	var sub := String(d["sub"])
	if sub != "":
		_say(b, sub, (z.x - _tw(sub)) * 0.5, 58, col, s + 11.0)


static func _p_cloud(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	_arc(b, Vector2(15, 28), 7.0, 7.0, PI * 0.5, PI * 1.6, BLUE, 8)
	_arc(b, Vector2(28, 22), 10.0, 10.0, PI * 1.1, PI * 1.95, BLUE, 10)
	_arc(b, Vector2(42, 27), 8.0, 8.0, PI * 1.3, PI * 2.5, BLUE, 10)
	_ln(b, Vector2(15, 35), Vector2(42, 35), BLUE, s)
	for k in 3:
		var x := 18.0 + float(k) * 9.0
		_ln(b, Vector2(x, 40), Vector2(x - 3.0, 48), BLUE, s + 1.0 + float(k))
	_cross(b, Vector2(27, 44), 9.0, RED, s + 5.0)
	_caption(b, d["t"], 62, z.y, BLACK, s + 10.0)


static func _p_notes(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	# one note on its own, two beamed together
	b._wobble_circle(Vector2(12, 44), 3.0, BLACK, s)
	_ln(b, Vector2(15, 44), Vector2(15, 26), BLACK, s + 1.0)
	_curve(b, [Vector2(15, 26), Vector2(20, 30), Vector2(21, 35)], BLACK)
	b._wobble_circle(Vector2(30, 40), 3.0, BLUE, s + 2.0)
	b._wobble_circle(Vector2(46, 36), 3.0, BLUE, s + 3.0)
	_ln(b, Vector2(33, 40), Vector2(33, 20), BLUE, s + 4.0)
	_ln(b, Vector2(49, 36), Vector2(49, 16), BLUE, s + 5.0)
	_ln(b, Vector2(33, 20), Vector2(49, 16), BLUE, s + 6.0)
	_ln(b, Vector2(33, 24), Vector2(49, 20), BLUE, s + 7.0)
	_caption(b, d["t"], 62, z.y, RED, s + 10.0)


static func _p_cards(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	var pivot := Vector2(30, 54)
	for k in 3:
		var a := (float(k) - 1.0) * 0.6
		var corners := [Vector2(-9, -34), Vector2(9, -34), Vector2(9, -8), Vector2(-9, -8)]
		var pts: Array = []
		for v: Vector2 in corners:
			pts.append(pivot + v.rotated(a))
		_poly(b, pts, BLACK, s + float(k) * 4.0, true)
		var mid := pivot + Vector2(0, -26).rotated(a)
		if k == 1:
			_heart(b, mid + Vector2(0, -1), 0.3, RED)
		elif k == 0:
			_poly(b, [mid + Vector2(0, -5), mid + Vector2(4, 0), mid + Vector2(0, 5), mid + Vector2(-4, 0)], RED, s + 20.0, true)
		else:
			_say(b, "A", mid.x - 3.0, mid.y + 4.0, BLACK, s + 21.0)
	_caption(b, d["t"], 62, z.y, BLUE, s + 30.0)


static func _p_dice(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	b._wobble_rect(Rect2(6, 12, 22, 22), BLACK, s)
	for p: Vector2 in [Vector2(11, 17), Vector2(23, 17), Vector2(17, 23), Vector2(11, 29), Vector2(23, 29)]:
		b.draw_circle(p, 1.8, BLACK)
	b._wobble_rect(Rect2(30, 30, 22, 22), RED, s + 4.0)
	for p: Vector2 in [Vector2(35, 35), Vector2(47, 47)]:
		b.draw_circle(p, 1.8, RED)
	_caption(b, d["t"], 62, z.y, BLACK, s + 10.0)


static func _p_mug(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	_mug(b, Vector2(18, z.y * 0.5 - 4.0), BLUE, s)
	_caption(b, d["t"], 62, z.y, BLACK, s + 10.0)


static func _p_darts(b: PostingBoard, d: Dictionary, s: float, z: Vector2) -> void:
	var c := Vector2(26, z.y * 0.5 + 2.0)
	b._wobble_circle(c, 20.0, BLACK, s)
	b._wobble_circle(c, 12.0, RED, s + 1.0)
	b._wobble_circle(c, 5.0, BLACK, s + 2.0)
	_dot(b, c, RED)
	for e: Array in [[c + Vector2(1, -1), c + Vector2(14, -16)], [c + Vector2(-10, 8), c + Vector2(-2, 22)]]:
		var tip: Vector2 = e[0]
		var end: Vector2 = e[1]
		_ln(b, tip, end, BLUE, s + 3.0 + tip.x * 0.1)
		var dir := (end - tip).normalized()
		var n := Vector2(-dir.y, dir.x)
		_ln(b, end, end - dir * 4.0 + n * 4.0, BLUE, s + 5.0 + tip.x * 0.1)
		_ln(b, end, end - dir * 4.0 - n * 4.0, BLUE, s + 6.0 + tip.x * 0.1)
	_caption(b, d["t"], 62, z.y, BLACK, s + 10.0)
