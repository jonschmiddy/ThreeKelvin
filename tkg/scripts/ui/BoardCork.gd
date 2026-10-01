class_name BoardCork
extends RefCounted
## WHAT IS PINNED TO A CHEAP CORKBOARD, an unclaimed station's and an outpost's,
## besides the work. A pool to pick from (Jon: "Not 20X on the board, just a big
## pool to pick from for diversity"): `PostingBoard` takes a handful of these per
## station, by the station's number, and pins them where it likes around the
## work, overlapping a little, as a real board's paper does.
##
## Every piece is drawn in its own box, `size_of(i)` from (0, 0): its paper, the
## shadow it throws down and to the right (inside the box), and its pins through
## `b._pin`, which makes a push pin on cork and a magnet on enamel.
##
## The first five are drawn by hand below. The rest are rows of `POOL`, each a
## kind of paper (`k`) and what is on it, painted by the `_kind` funcs further
## down. Square paper only: pixel text turned on its side goes to stair-steps.
## The top 24 pixels of a piece are its title, which nothing else lands over.

const SHADE := PostingBoard.SHADE
const INK := PostingBoard.INK
const INK_SOFT := PostingBoard.INK_SOFT
const RED := PostingBoard.RED
const BLUE := PostingBoard.BLUE
const EMBER := PostingBoard.EMBER
const PIN := PostingBoard.PIN
const PIN_COOL := PostingBoard.PIN_COOL


static func count() -> int:
	return SIZES.size() + POOL.size()


const SIZES := [
	Vector2(122, 120),  # 0 an old job, stamped FILLED
	Vector2(122, 72),   # 1 three stickies
	Vector2(122, 120),  # 2 Tinker's card and a polaroid
	Vector2(106, 126),  # 3 the noodle menu
	Vector2(124, 122),  # 4 an old job with TAKEN, SORRY over it
]


static func size_of(i: int) -> Vector2:
	var n := count()
	var j := ((i % n) + n) % n
	if j < SIZES.size():
		return SIZES[j]
	return POOL[j - SIZES.size()]["s"]


static func _shadow(b: PostingBoard, r: Rect2, a: float = 0.4) -> void:
	b.draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(SHADE.r, SHADE.g, SHADE.b, a))


static func draw(b: PostingBoard, i: int) -> void:
	match i:
		0:
			var sh := Rect2(Vector2(2, 2), Vector2(116, 114))
			_shadow(b, sh)
			b.draw_rect(sh, Color("#b8ab88"))
			for k in 6:
				b.draw_rect(Rect2(sh.position.x + 8.0, sh.position.y + 14.0 + float(k) * 10.0,
					sh.size.x - 20.0 - float((k * 13) % 30), 2.0), Color(INK_SOFT.r, INK_SOFT.g, INK_SOFT.b, 0.5))
			var sr := Rect2(sh.position.x + 14.0, sh.get_center().y - 12.0, sh.size.x - 28.0, 22.0)
			b.draw_rect(sr, Color(RED.r, RED.g, RED.b, 0.85), false, 2.0)
			b._centre_at("FILLED", sr.position.x, sr.position.y + 17.0, sr.size.x, UITheme.FS_HEAD, Color(RED.r, RED.g, RED.b, 0.85))
			b._pin(Vector2(sh.position.x + sh.size.x * 0.5, sh.position.y + 3.0), PIN)
		1:
			# three stickies, overlapping
			var cols := [Color("#f0d878"), Color("#f0a0b8"), Color("#a8e0a0")]
			for k in 3:
				var at := Vector2(2.0 + float(k) * 34.0, 2.0 + float((k * 17) % 30))
				_shadow(b, Rect2(at, Vector2(48, 48)), 0.35)
				b.draw_rect(Rect2(at, Vector2(48, 48)), cols[k])
				for l in 3:
					b.draw_rect(Rect2(at.x + 6.0, at.y + 12.0 + float(l) * 9.0, 34.0 - float(l * 7), 2.0), Color(INK.r, INK.g, INK.b, 0.6))
		2:
			# a business card and a polaroid
			var bc := Rect2(Vector2(2, 2), Vector2(84.0, 46.0))
			_shadow(b, bc, 0.35)
			b.draw_rect(bc, Color("#e8e2d0"))
			b._text("TINKER", bc.position.x + 6.0, bc.position.y + 14.0, UITheme.FS_SMALL, INK)
			b._text("FIXES ANYTHING", bc.position.x + 6.0, bc.position.y + 26.0, UITheme.FS_SMALL, INK_SOFT)
			b._text("DECK 2", bc.position.x + 6.0, bc.position.y + 38.0, UITheme.FS_SMALL, BLUE)
			var po := Rect2(Vector2(58, 48), Vector2(60.0, 66.0))
			_shadow(b, po)
			b.draw_rect(po, Color("#eeeae0"))
			var ph := Rect2(po.position + Vector2(5, 5), Vector2(50, 42))
			b.draw_rect(ph, Color("#1c2a3a"))
			b.draw_rect(Rect2(ph.position.x + 10.0, ph.position.y + 20.0, 28.0, 6.0), Color("#a8b8c8"))
			b.draw_rect(Rect2(ph.position.x + 18.0, ph.position.y + 16.0, 8.0, 4.0), Color("#a8b8c8"))
			b.draw_rect(Rect2(ph.position.x + 38.0, ph.position.y + 22.0, 4.0, 2.0), EMBER)
			b._text("MY GIRL", po.position.x + 8.0, po.end.y - 6.0, UITheme.FS_SMALL, INK_SOFT)
			b._pin(Vector2(bc.position.x + 40.0, bc.position.y + 2.0), PIN_COOL)
			b._pin(Vector2(po.position.x + 30.0, po.position.y + 2.0), PIN)
		3:
			# a takeout menu
			var mn := Rect2(Vector2(2, 2), Vector2(100.0, 120.0))
			_shadow(b, mn)
			b.draw_rect(mn, Color("#d8463a"))
			b._centre_at("NOODLES", mn.position.x, mn.position.y + 18.0, mn.size.x, UITheme.FS_HEAD, Color("#f8e8c0"))
			b._centre_at("DECK 3 - LATE", mn.position.x, mn.position.y + 32.0, mn.size.x, UITheme.FS_SMALL, Color("#f8e8c0"))
			for k in 5:
				b.draw_rect(Rect2(mn.position.x + 10.0, mn.position.y + 44.0 + float(k) * 11.0, mn.size.x - 40.0, 2.0), Color("#f8e8c0"))
				b._text("%d" % (3 + k * 2), mn.end.x - 22.0, mn.position.y + 48.0 + float(k) * 11.0, UITheme.FS_SMALL, Color("#f8e8c0"))
			b._pin(Vector2(mn.position.x + mn.size.x * 0.5, mn.position.y + 3.0), PIN)
		4:
			# an old job, faded, and a sticky over its corner
			var sh2 := Rect2(Vector2(2, 2), Vector2(118.0, 106.0))
			_shadow(b, sh2, 0.3)
			b.draw_rect(sh2, Color("#a8a090"))
			for k in 5:
				b.draw_rect(Rect2(sh2.position.x + 8.0, sh2.position.y + 12.0 + float(k) * 10.0,
					sh2.size.x - 24.0 - float((k * 11) % 26), 2.0), Color(INK_SOFT.r, INK_SOFT.g, INK_SOFT.b, 0.45))
			var st := Rect2(sh2.end - Vector2(46, 40), Vector2(48, 48))
			_shadow(b, st, 0.35)
			b.draw_rect(st, Color("#f0d878"))
			b._text("TAKEN", st.position.x + 6.0, st.position.y + 16.0, UITheme.FS_SMALL, RED)
			b._text("SORRY", st.position.x + 6.0, st.position.y + 30.0, UITheme.FS_SMALL, INK)
			b._pin(Vector2(sh2.position.x + 20.0, sh2.position.y + 3.0), PIN_COOL)
		_:
			_pool(b, i)


# ---------------------------------------------------------------------------
# THE REST OF THE POOL: years of paper. Each row is one piece: `k` its kind,
# `s` its box, and what the kind's painter needs.
# ---------------------------------------------------------------------------

const F := UITheme.FS_SMALL
const H := UITheme.FS_HEAD
const CORK := PostingBoard.CORK

const WHITE := Color("#ece8dc")
const CREAM := Color("#e6dcc0")
const YELLOW := Color("#f0dc78")
const PINK := Color("#f0bcc8")
const MINT := Color("#bfe2b6")
const SKY := Color("#bcd6ee")
const ORANGE := Color("#f2ae68")
const LILAC := Color("#d6c8ee")
const MANILA := Color("#dcc894")
const KRAFT := Color("#b48c5a")
const NEWS := Color("#cdc9ba")
const INDEX := Color("#dcd6c3")
const GREEN := Color("#2f7a4a")
const GOLD := Color("#b08a30")
const SKIN := [Color("#e8b890"), Color("#b07850"), Color("#7a4a30"), Color("#f0c8a8")]
const HAIR := [Color("#3a2a1c"), Color("#c87830"), Color("#1c1c20"), Color("#d8c070"), Color("#8a8a90")]
const PINS := [PIN, PIN_COOL, Color("#d8b840"), Color("#5aa060"), Color("#dcd8cc"), Color("#a060c0")]

const POOL := [
	# FOR SALE, with tear-off tabs, some taken
	{"k": "sale", "s": Vector2(106, 120), "t": "FOR SALE", "l": ["SPACE SUIT", "ONE OWNER", "SMELLS OK"], "ph": "4417", "torn": [1, 4], "c": CREAM},
	{"k": "sale", "s": Vector2(100, 114), "t": "BIKE", "l": ["FOLDING BIKE", "GOOD TYRES", "NO BRAKES"], "ph": "2290", "torn": [0, 2, 3], "c": YELLOW, "tc": INK},
	{"k": "sale", "s": Vector2(110, 118), "t": "LESSONS", "l": ["GUITAR", "FIRST ONE FREE", "BRING EARS"], "ph": "7051", "torn": [5], "c": SKY, "tc": BLUE},
	{"k": "sale", "s": Vector2(96, 114), "t": "BOOTS", "l": ["SIZE 11", "MAG SOLES", "STICK GREAT"], "ph": "3318", "torn": [], "c": WHITE, "n": 6},
	{"k": "sale", "s": Vector2(100, 116), "t": "PLANT", "l": ["IT IS ALIVE", "MOSTLY", "WATER IT"], "ph": "0907", "torn": [0, 1, 2, 3, 4], "c": MINT, "tc": GREEN},
	{"k": "sale", "s": Vector2(108, 116), "t": "WILL SWAP", "l": ["MY SOCKS", "FOR FUEL", "CLEAN SOCKS"], "ph": "1123", "torn": [3], "c": ORANGE, "tc": INK},
	{"k": "sale", "s": Vector2(110, 118), "t": "BAND", "l": ["NEEDS A DRUMMER", "OR A BUCKET", "WE ARE LOUD"], "ph": "6640", "torn": [2, 6], "c": LILAC},

	# LOST, and one FOUND, with a drawing
	{"k": "lost", "s": Vector2(108, 132), "t": "LOST CAT", "pic": "cat", "pc": Color("#d88a3a"), "l": ["SOCKS", "ORANGE. ANGRY.", "LIKES VENTS"], "rw": "REWARD"},
	{"k": "lost", "s": Vector2(108, 132), "t": "LOST", "pic": "drone", "pc": Color("#7a9ab8"), "l": ["MY DRONE PIP", "HUMS WHEN HAPPY", "BEEPS WHEN SAD"], "rw": "REWARD 50 CR", "c": SKY},
	{"k": "lost", "s": Vector2(108, 128), "t": "LOST", "pic": "lizard", "pc": Color("#5aa050"), "l": ["BIG GREEN LIZARD", "DO NOT FEED IT", "IT BITES"], "rw": "PLEASE CALL", "c": YELLOW},
	{"k": "lost", "s": Vector2(108, 128), "t": "FOUND", "pic": "bird", "pc": Color("#4a8ac8"), "l": ["ONE BIRD", "SAYS RUDE WORDS", "LIVES IN MY BUNK"], "rw": "COME GET IT", "c": WHITE},

	# index cards: rooms, bunks, thanks
	{"k": "index", "s": Vector2(112, 74), "t": "ROOM TO RENT", "l": ["DECK 5", "NEAR THE PUMPS", "WARM AT NIGHT", "40 CR A WEEK"]},
	{"k": "index", "s": Vector2(100, 70), "t": "BUNK TO SHARE", "l": ["TOP BUNK", "I SNORE", "SORRY"], "hand": true},
	{"k": "index", "s": Vector2(110, 82), "t": "LOST AND FOUND", "l": ["1 GLOVE (LEFT)", "2 SPOONS", "A WIG", "ASK AT THE BAR"], "ink": INK},
	{"k": "index", "s": Vector2(100, 70), "t": "THANK YOU", "l": ["TO WHOEVER", "FIXED MY", "DOOR"], "hand": true, "c": Color("#e8d8d8")},

	# gig posters
	{"k": "gig", "s": Vector2(118, 126), "t": "THE VENTS", "deco": "eq", "l": ["LIVE AT THE BAR", "DECK 4", "FRI LATE"], "c": Color("#b83a3a"), "a": Color("#f8e070")},
	{"k": "gig", "s": Vector2(104, 132), "t": "COLD", "t2": "START", "deco": "bolt", "l": ["NO COVER", "DECK 3 SAT"], "c": Color("#2a8a8a"), "a": Color("#f0e060")},
	{"k": "gig", "s": Vector2(112, 124), "t": "DJ ZERO K", "deco": "eq", "l": ["DANCE ALL", "SHIFT LONG", "DOCK 2"], "c": Color("#6a4aa8"), "a": Color("#90f0e0")},
	{"k": "gig", "s": Vector2(108, 124), "t": "KARAOKE", "deco": "note", "l": ["EVERY THURS", "SING BADLY", "WIN A PIE"], "c": Color("#e8843a"), "a": Color("#40180c"), "lt": Color("#40180c")},

	# ticket stubs
	{"k": "ticket", "s": Vector2(100, 46), "t": "ADMIT ONE", "l": "FIGHT NIGHT", "n": "NO 0412", "c": PINK},
	{"k": "ticket", "s": Vector2(100, 46), "t": "RAFFLE", "l": "WIN A HAM", "n": "NO 0081", "c": YELLOW},

	# receipts
	{"k": "receipt", "s": Vector2(64, 124), "t": "FUEL STOP", "u": "DOCK 2", "it": [["FUEL", "40"], ["SNACK", "3"], ["GUM", "1"], ["TIP", "0"]], "tot": "44"},
	{"k": "receipt", "s": Vector2(64, 124), "t": "KORVAN", "u": "SPARES", "it": [["BOLTS", "6"], ["SEAL", "12"], ["FUSE", "2"], ["FUSE", "2"], ["FUSE", "2"]], "tot": "24"},

	# postcards
	{"k": "postcard", "s": Vector2(114, 82), "t": "ICE MOON", "sky": Color("#1c3058"), "pl": Color("#c8e0f0"), "ring": false},
	{"k": "postcard", "s": Vector2(114, 82), "t": "BIG ORANGE", "sky": Color("#3a2050"), "pl": Color("#e08a3a"), "ring": true},

	# a child's crayon drawings
	{"k": "crayon", "s": Vector2(100, 92), "t": "MY MUM", "pic": "mum", "cc": Color("#c83a8a")},
	{"k": "crayon", "s": Vector2(104, 88), "t": "SPACE WALE", "pic": "whale", "cc": Color("#2a6ac8")},
	{"k": "crayon", "s": Vector2(100, 92), "t": "ME AND DAD", "pic": "dad", "cc": Color("#2a9a4a")},
	{"k": "crayon", "s": Vector2(110, 86), "t": "THE BAD SHIP", "pic": "bad", "cc": Color("#d03a2a")},

	# polaroids
	{"k": "polaroid", "s": Vector2(66, 80), "t": "OLD BETSY", "pic": "ship", "bg": Color("#16243a")},
	{"k": "polaroid", "s": Vector2(66, 80), "t": "THE CREW", "pic": "crew", "bg": Color("#3a4a5a")},
	{"k": "polaroid", "s": Vector2(66, 80), "t": "MOTH", "pic": "cat", "bg": Color("#5a4a3a")},
	{"k": "polaroid", "s": Vector2(66, 80), "t": "MY 40TH", "pic": "cake", "bg": Color("#2a2030")},

	# a calendar page
	{"k": "calendar", "s": Vector2(100, 112), "t": "JUNE", "x": 17, "o": 21, "n": "PAY DAY"},

	# safety
	{"k": "safety", "s": Vector2(102, 116), "t": "DANGER", "l": ["HIGH HEAT", "SOLARI LINE", "DO NOT TOUCH"]},
	{"k": "safety", "s": Vector2(102, 116), "t": "CAUTION", "l": ["AIRLOCK", "CHECK YOUR", "HELMET"]},
	{"k": "safety", "s": Vector2(102, 116), "t": "WARNING", "l": ["THE SWARM", "IS NOT", "A PET"]},
	{"k": "safety", "s": Vector2(106, 116), "t": "RECALL", "l": ["CYGNET DRONE 7", "MAY FOLLOW", "YOU HOME"], "c": WHITE, "tc": RED},

	# typed notices
	{"k": "notice", "s": Vector2(110, 120), "t": "CREW MEETING", "icon": "horn", "l": ["DECK 2 MESS", "AFTER SHIFT", "RE: OUR PAY"], "f": "BRING A CHAIR"},
	{"k": "notice", "s": Vector2(108, 116), "t": "BLOOD DRIVE", "icon": "drop", "l": ["GIVE A LITTLE", "GET A COOKIE"], "f": "MED BAY", "c": WHITE},
	{"k": "notice", "s": Vector2(104, 106), "t": "BOARD RULES", "left": true, "l": ["1. NO ADS", "2. NO ADS", "3. REALLY", "4. NO ADS"], "f": "- THE OFFICE", "c": WHITE},
	{"k": "notice", "s": Vector2(108, 120), "t": "FREE CLASS", "icon": "spark", "l": ["LEARN TO WELD", "BRING GLOVES", "BOTH OF THEM"], "f": "DECK 1", "c": Color("#d8e4ec")},

	# notes by hand, on lined paper
	{"k": "note", "s": Vector2(104, 82), "l": ["FOUND:", "ONE GLOVE", "LEFT HAND", "ASK AT BAR"], "pen": BLUE},
	{"k": "note", "s": Vector2(100, 82), "l": ["WHO TOOK", "MY MUG???", "IT WAS", "MY MUG"], "pen": RED},
	{"k": "note", "s": Vector2(100, 82), "l": ["SORRY", "ABOUT THE", "AIRLOCK", "- DEV"], "pen": INK},
	{"k": "note", "s": Vector2(100, 70), "l": ["GONE TO", "LAYER 3", "BACK SOON"], "pen": BLUE},
	{"k": "note", "s": Vector2(114, 58), "l": ["DEAR BOARD", "I MISS RAIN"], "pen": INK},

	# business cards
	{"k": "biz", "s": Vector2(100, 52), "t": "DOC ODA", "l": ["STITCHES", "NO QUESTIONS"], "icon": "cross", "c": WHITE},
	{"k": "biz", "s": Vector2(96, 52), "t": "MADAME VEX", "l": ["SEES ALL", "5 CR A LOOK"], "icon": "eye", "c": Color("#5a3a70"), "ink": Color("#f0d070"), "soft": Color("#d8c0f0")},
	{"k": "biz", "s": Vector2(96, 52), "t": "SPARKY", "l": ["WELDING", "FAST. CHEAP."], "icon": "spark", "c": Color("#d0d8e0")},
	{"k": "biz", "s": Vector2(96, 52), "t": "SNIP SNIP", "l": ["HAIR CUTS", "DECK 6"], "icon": "scissors", "c": PINK},

	# food stall menus
	{"k": "menu", "s": Vector2(104, 120), "t": "SOUP", "it": [["PEA", "3"], ["BEAN", "3"], ["MYSTERY", "1"], ["BREAD", "1"]], "f": "HOT HOT HOT", "c": CREAM, "a": GREEN},
	{"k": "menu", "s": Vector2(104, 120), "t": "BUGS!", "it": [["FRIED", "4"], ["ON A STICK", "5"], ["SPICY", "5"], ["DARE YOU", "9"]], "f": "THEY CRUNCH", "c": YELLOW, "a": Color("#8a4a1a")},

	# coupons
	{"k": "coupon", "s": Vector2(98, 60), "t": "2 FOR 1", "l": ["FRIED BUGS", "ENDS FRIDAY"], "c": YELLOW},
	{"k": "coupon", "s": Vector2(98, 60), "t": "FREE TEA", "l": ["WITH ANY SOUP", "ONE EACH"], "c": MINT},

	# calm
	{"k": "calm", "s": Vector2(100, 120), "t": "BREATHE", "l": ["CALM CLASS", "DECK 6", "BRING A MAT"], "c": LILAC, "a": Color("#8a6ac8")},
	{"k": "calm", "s": Vector2(102, 120), "t": "BE STILL", "l": ["THE QUIET STARS", "DOCK 2 AT DAWN", "ALL WELCOME"], "c": Color("#c8e4e0"), "a": Color("#3a8a8a")},

	# have you seen this ship
	{"k": "seen", "s": Vector2(112, 124), "pic": 0, "l": ["THE LUCKY OTTER", "GREEN STRIPE", "OWES ME 200 CR"]},
	{"k": "seen", "s": Vector2(112, 124), "pic": 1, "l": ["MY BROTHER", "FLIES IT", "TELL HIM: CALL MUM"]},

	# maps
	{"k": "map", "s": Vector2(112, 94), "t": "DECK 5"},
	{"k": "route", "s": Vector2(112, 90), "t": "LAYER 3"},

	# a star chart scrap
	{"k": "stars", "s": Vector2(98, 86), "t": "STAR CHART", "n": "HOME?"},

	# old WANTED posters, stamped
	{"k": "caught", "s": Vector2(102, 126), "t": "SKIP", "l": "FOR CHEATING", "st": "CAUGHT", "sc": RED},
	{"k": "caught", "s": Vector2(112, 126), "t": "BIG LU", "l": "FOR SNORING", "st": "FORGIVEN", "sc": BLUE},

	# tables: a timetable, a league, a price list
	{"k": "table", "s": Vector2(100, 120), "t": "SHUTTLE", "a": BLUE, "dog": true, "rows": [["DOCK A", "06:10"], ["RING 2", "07:45"], ["MARKET", "09:00"], ["DOCK A", "12:30"], ["RING 2", "15:15"], ["LAST ONE", "23:50"]]},
	{"k": "table", "s": Vector2(112, 96), "t": "DARTS LEAGUE", "a": RED, "rows": [["1 HAULERS", "12"], ["2 THE VENTS", "9"], ["3 MED BAY", "7"], ["4 OFFICE", "0"]], "strike": 3},
	{"k": "table", "s": Vector2(104, 98), "t": "DOCK FEES", "a": GREEN, "rows": [["SMALL", "5"], ["MEDIUM", "10"], ["BIG", "20"], ["HUGE", "ASK"]]},

	# a pad of stickies
	{"k": "pad", "s": Vector2(72, 72), "l": ["CALL", "MUM"], "c": Color("#a8d0f0")},
	{"k": "pad", "s": Vector2(72, 72), "l": ["BUY", "GLUE"], "c": Color("#f0a868")},

	# cardboard signs in marker
	{"k": "sign", "s": Vector2(112, 84), "t": "FREE", "l": "KITTENS", "pic": "kittens"},
	{"k": "sign", "s": Vector2(112, 76), "t": "FREE", "l": "DAMP COUCH", "pic": ""},

	# envelopes
	{"k": "envelope", "s": Vector2(96, 64), "t": "TO RIKA", "l": "DO NOT OPEN", "c": WHITE},
	{"k": "envelope", "s": Vector2(96, 64), "t": "FOR TAM", "l": "YOUR KEYS", "c": MANILA},

	# a stamp card, holes punched
	{"k": "punch", "s": Vector2(90, 64), "t": "SOUP CARD", "n": 7, "c": Color("#e8c0a0")},

	# bingo
	{"k": "bingo", "s": Vector2(104, 124), "t": "BINGO!", "l": ["DECK 4 THURS", "PRIZE: A HAM"], "c": PINK},

	# torn corners left under their pins
	{"k": "scrap", "s": Vector2(44, 34), "shape": 0, "c": WHITE},
	{"k": "scrap", "s": Vector2(62, 40), "shape": 1, "c": YELLOW},

	# clippings
	{"k": "clip", "s": Vector2(104, 112), "l": ["CREW FINDS", "ICE AT LAYER 3"], "pic": "ice"},
	{"k": "clip", "s": Vector2(104, 112), "l": ["HELLBENDER", "SEEN NEAR DOCK"], "pic": "hb"},
	{"k": "clip", "s": Vector2(104, 112), "l": ["CAT ELECTED", "DECK CHIEF"], "pic": "cat"},

	# a sign-up sheet
	{"k": "signup", "s": Vector2(104, 120), "t": "FIVE A SIDE", "names": ["ROO", "DEX", "", "BIG LU", "", ""]},

	# a certificate
	{"k": "cert", "s": Vector2(118, 86), "t": "FIRST AID", "n": "DEX ORR"},

	# a crew pass
	{"k": "badge", "s": Vector2(74, 110), "t": "DEV ORR", "l": "DECK 2"},

	# shipping labels
	{"k": "label", "s": Vector2(102, 78), "t": "FRAGILE", "icon": "glass", "l": "THIS WAY UP", "a": ORANGE},
	{"k": "label", "s": Vector2(102, 78), "t": "HOT", "icon": "flame", "l": "USE GLOVES", "a": Color("#e86a4a")},

	# a graph
	{"k": "graph", "s": Vector2(100, 100), "t": "HEAT THIS WEEK", "bars": [0.2, 0.3, 0.3, 0.5, 0.6, 0.8, 1.0], "n": "UH OH"},

	# an IOU
	{"k": "iou", "s": Vector2(100, 48), "t": "IOU 20 CR", "l": "- BOSK"},

	# a photo booth strip
	{"k": "strip", "s": Vector2(40, 120)},

	# memos
	{"k": "memo", "s": Vector2(108, 118), "t": "RE: THE SMELL", "l": ["IT IS BEING", "LOOKED AT.", "PLEASE STAY", "CALM."]},
	{"k": "memo", "s": Vector2(108, 118), "t": "RE: HEAT", "l": ["DO NOT TAKE", "HEAT HOME", "IN BUCKETS.", "AGAIN."]},

	# a petition
	{"k": "petition", "s": Vector2(106, 120), "t": "SAVE THE", "u": "GARDEN DECK"},

	# a key on a tag
	{"k": "key", "s": Vector2(76, 56), "t": "FOUND", "l": "KEY"},

	# a birthday card
	{"k": "bday", "s": Vector2(98, 104), "t": "HAPPY", "l": "BIRTHDAY TOV"},

	# fortune slips
	{"k": "fortune", "s": Vector2(106, 36), "l": ["YOU WILL FIND", "WHAT YOU LOST"]},
	{"k": "fortune", "s": Vector2(106, 36), "l": ["DO NOT JUMP", "ON A TUESDAY"]},

	# an election poster
	{"k": "vote", "s": Vector2(104, 126), "t": "ODA", "l": ["FOR DECK CHIEF", "SHE FIXED", "THE LIGHTS"]},

	# hang in there
	{"k": "hang", "s": Vector2(92, 108)},

	# a crossword, half done
	{"k": "xword", "s": Vector2(94, 104)},

	# a playing card
	{"k": "card", "s": Vector2(52, 68)},
]


static var _now := -1


static func _pool(b: PostingBoard, i: int) -> void:
	var j := i - SIZES.size()
	if j < 0 or j >= POOL.size():
		return
	var P: Dictionary = POOL[j]
	var sz: Vector2 = P["s"]
	_now = i
	match String(P["k"]):
		"sale": _sale(b, P, sz, i)
		"lost": _lost(b, P, sz, i)
		"index": _index(b, P, sz, i)
		"gig": _gig(b, P, sz, i)
		"ticket": _ticket(b, P, sz, i)
		"receipt": _receipt(b, P, sz, i)
		"postcard": _postcard(b, P, sz, i)
		"crayon": _crayon(b, P, sz, i)
		"polaroid": _polaroid(b, P, sz, i)
		"calendar": _calendar(b, P, sz, i)
		"safety": _safety(b, P, sz, i)
		"notice": _notice(b, P, sz, i)
		"note": _note(b, P, sz, i)
		"biz": _biz(b, P, sz, i)
		"menu": _menu(b, P, sz, i)
		"coupon": _coupon(b, P, sz, i)
		"calm": _calm(b, P, sz, i)
		"seen": _seen(b, P, sz, i)
		"map": _map(b, P, sz, i)
		"route": _route(b, P, sz, i)
		"stars": _stars(b, P, sz, i)
		"caught": _caught(b, P, sz, i)
		"table": _table(b, P, sz, i)
		"pad": _pad(b, P, sz, i)
		"sign": _sign(b, P, sz, i)
		"envelope": _envelope(b, P, sz, i)
		"punch": _punch(b, P, sz, i)
		"bingo": _bingo(b, P, sz, i)
		"scrap": _scrap(b, P, sz, i)
		"clip": _clip(b, P, sz, i)
		"signup": _signup(b, P, sz, i)
		"cert": _cert(b, P, sz, i)
		"badge": _badge(b, P, sz, i)
		"label": _label(b, P, sz, i)
		"graph": _graph(b, P, sz, i)
		"iou": _iou(b, P, sz, i)
		"strip": _strip(b, P, sz, i)
		"memo": _memo(b, P, sz, i)
		"petition": _petition(b, P, sz, i)
		"key": _key(b, P, sz, i)
		"bday": _bday(b, P, sz, i)
		"fortune": _fortune(b, P, sz, i)
		"vote": _vote(b, P, sz, i)
		"hang": _hang(b, P, sz, i)
		"xword": _xword(b, P, sz, i)
		"card": _card(b, P, sz, i)


# --- helpers ---------------------------------------------------------------

## The paper of a piece that fills its box: its shadow lands on the box's edge.
static func _r(sz: Vector2) -> Rect2:
	return Rect2(2.0, 2.0, sz.x - 6.0, sz.y - 6.0)


static func _paper(b: PostingBoard, r: Rect2, col: Color, a: float = 0.4, edge: bool = true) -> void:
	_shadow(b, r, a)
	b.draw_rect(r, col)
	if edge:
		b.draw_rect(r, col.darkened(0.22), false, 1.0)


static func _pc(i: int, k: int = 0) -> Color:
	return PINS[(i * 7 + k * 3) % PINS.size()]


static func _a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


static func _poly(b: PostingBoard, pts: Array, col: Color, off: Vector2 = Vector2.ZERO) -> void:
	var q := PackedVector2Array()
	for p: Vector2 in pts:
		q.append(p + off)
	b.draw_colored_polygon(q, col)


static func _disc(b: PostingBoard, c: Vector2, r: int, col: Color) -> void:
	PostingBoard._disc(b, c.round(), r, col)


## A ring: a disc with its middle in another colour.
static func _ring(b: PostingBoard, c: Vector2, r: int, col: Color, fill: Color) -> void:
	if fill.a > 0.0:
		_disc(b, c, r - 1, fill)
	# the ring alone, row by row: what the outer disc has and the inner has not
	c = c.round()
	var outer := PostingBoard._disc_rows(r)
	var inner := PostingBoard._disc_rows(r - 1)
	for k in outer.size():
		var y := k - r
		var ho := outer[k]
		var hi := inner[y + r - 1] if absi(y) <= r - 1 else -1
		var row := c.y + float(y)
		if hi < 0:
			b.draw_rect(Rect2(c.x - float(ho), row, float(ho * 2 + 1), 1.0), col)
		else:
			b.draw_rect(Rect2(c.x - float(ho), row, float(ho - hi), 1.0), col)
			b.draw_rect(Rect2(c.x + float(hi) + 1.0, row, float(ho - hi), 1.0), col)


static func _tape(b: PostingBoard, r: Rect2) -> void:
	b.draw_rect(r, Color(0.93, 0.9, 0.76, 0.55))
	b.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), Color(1, 1, 1, 0.2))
	# the torn ends
	b.draw_rect(Rect2(r.position.x, r.position.y + 1.0, 1.0, r.size.y - 2.0), Color(0.93, 0.9, 0.76, 0.3))
	b.draw_rect(Rect2(r.end.x - 1.0, r.position.y, 1.0, r.size.y - 1.0), Color(0.93, 0.9, 0.76, 0.3))


static func _staple(b: PostingBoard, at: Vector2) -> void:
	b.draw_rect(Rect2(at + Vector2(1, 2), Vector2(9, 1)), _a(SHADE, 0.45))
	b.draw_rect(Rect2(at, Vector2(9, 1)), Color("#e4e8ec"))
	b.draw_rect(Rect2(at + Vector2(0, 1), Vector2(9, 1)), Color("#8a9098"))


static func _w(s: String, fs: int) -> float:
	return UITheme.pixel_font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## Says so in the harness's output when words will not fit where they are put.
static func _warn(s: String, need: float, room: float) -> void:
	if need > room + 0.5:
		print("  cork %d: \"%s\" needs %d, has %d" % [_now, s, int(need), int(room)])


static func _tx(b: PostingBoard, s: String, x: float, y: float, fs: int, col: Color, room: float) -> void:
	_warn(s, _w(s, fs), room)
	b._text(s, x, y, fs, col)


static func _cx(b: PostingBoard, s: String, x: float, y: float, w: float, fs: int, col: Color) -> void:
	_warn(s, _w(s, fs), w)
	b._centre_at(s, x, y, w, fs, col)


static func _rx(b: PostingBoard, s: String, right: float, y: float, fs: int, col: Color) -> void:
	b._text(s, floorf(right - _w(s, fs)), y, fs, col)


## How wide `PostingBoard._hand` writes, near enough.
static func _hw(s: String, fs: int = F) -> float:
	var sc := 1.35 if fs <= F else 2.8
	var w := 0.0
	for ch in s:
		w += (3.5 * sc + 0.75) if ch == " " else (5.8 * sc)
	return w + 1.0 * sc


static func _hx(b: PostingBoard, s: String, at: Vector2, col: Color, sd: float, room: float, fs: int = F) -> void:
	_warn(s, _hw(s, fs), room)
	b._hand(s, at, col, sd, fs)


## Lines of print too small to read, as print is from a step back.
static func _greek(b: PostingBoard, x: float, y: float, w: float, n: int, step: float, col: Color, sd: int = 0) -> void:
	for k in n:
		var cut := float((k * 13 + sd * 7) % 23)
		b.draw_rect(Rect2(x, y + float(k) * step, maxf(8.0, w - cut), 2.0), col)


static func _dash_h(b: PostingBoard, x0: float, x1: float, y: float, col: Color, on: float = 3.0, off: float = 2.0) -> void:
	var x := x0
	while x < x1:
		b.draw_rect(Rect2(x, y, minf(on, x1 - x), 1.0), col)
		x += on + off


static func _dash_v(b: PostingBoard, x: float, y0: float, y1: float, col: Color, on: float = 3.0, off: float = 2.0) -> void:
	var y := y0
	while y < y1:
		b.draw_rect(Rect2(x, y, 1.0, minf(on, y1 - y)), col)
		y += on + off


## A torn bottom edge: bits of the paper hanging below `y`.
static func _ragged_bottom(b: PostingBoard, x: float, y: float, w: float, col: Color, sd: int) -> void:
	var k := 0
	var xx := x
	while xx < x + w:
		var h := float((k * 7 + sd * 3) % 4)
		if h > 0.0:
			b.draw_rect(Rect2(xx, y, minf(2.0, x + w - xx), h), col)
		xx += 2.0
		k += 1


static func _ragged_right(b: PostingBoard, x: float, y: float, h: float, col: Color, sd: int) -> void:
	var k := 0
	var yy := y
	while yy < y + h:
		var w := float((k * 5 + sd * 3) % 4)
		if w > 0.0:
			b.draw_rect(Rect2(x, yy, w, minf(2.0, y + h - yy)), col)
		yy += 2.0
		k += 1


## A twinkle: a plus with a bright middle.
static func _star(b: PostingBoard, c: Vector2, r: int, col: Color) -> void:
	b.draw_rect(Rect2(c.x - float(r), c.y, float(r * 2 + 1), 1.0), col)
	b.draw_rect(Rect2(c.x, c.y - float(r), 1.0, float(r * 2 + 1)), col)
	if r >= 2:
		b.draw_rect(Rect2(c.x - 1.0, c.y - 1.0, 3.0, 3.0), col)


## A name signed: a pen line going up and down as it runs along.
static func _squiggle(b: PostingBoard, x: float, y: float, w: float, col: Color, sd: int) -> void:
	var prev := Vector2(x, y)
	var k := 0
	var xx := x
	while xx < x + w:
		xx += 3.0
		var dy := float(((k * 5 + sd * 3) % 7) - 3)
		var p := Vector2(minf(xx, x + w), y + dy)
		b.draw_line(prev, p, col, 1.0)
		prev = p
		k += 1


static func _barcode(b: PostingBoard, x: float, y: float, w: float, h: float, sd: int) -> void:
	var xx := x
	var k := 0
	while xx < x + w - 1.0:
		var bw := 1.0 + float((k * 7 + sd) % 3 == 0)
		b.draw_rect(Rect2(xx, y, bw, h), INK)
		xx += bw + 1.0 + float((k * 3 + sd) % 2)
		k += 1


## Black and yellow stripes across a band.
static func _hazard(b: PostingBoard, r: Rect2, col: Color = INK) -> void:
	for j in int(r.size.y):
		var k := -2
		while float(k) * 10.0 < r.size.x + 10.0:
			var x0 := r.position.x + float(k) * 10.0 + float(j)
			var x1 := x0 + 5.0
			x0 = maxf(x0, r.position.x)
			x1 = minf(x1, r.end.x)
			if x1 > x0:
				b.draw_rect(Rect2(x0, r.position.y + float(j), x1 - x0, 1.0), col)
			k += 1


## A ship, side on, small. `kind` 0 sleek, 1 hauler, 2 needle.
static func _ship(b: PostingBoard, c: Vector2, w: float, col: Color, glow: Color, kind: int = 0) -> void:
	var x0 := floorf(c.x - w * 0.5)
	var y := floorf(c.y)
	match kind:
		0:
			b.draw_rect(Rect2(x0, y - 3.0, w, 7.0), col)
			b.draw_rect(Rect2(x0 + w, y - 2.0, 2.0, 5.0), col)
			b.draw_rect(Rect2(x0 + w + 2.0, y - 1.0, 2.0, 3.0), col)
			b.draw_rect(Rect2(x0 + floorf(w * 0.4), y - 6.0, floorf(w * 0.3), 3.0), col)
			b.draw_rect(Rect2(x0, y - 7.0, 5.0, 4.0), col)
			b.draw_rect(Rect2(x0, y + 4.0, 5.0, 3.0), col)
			b.draw_rect(Rect2(x0 - 3.0, y - 2.0, 3.0, 5.0), glow)
			for k in 3:
				b.draw_rect(Rect2(x0 + floorf(w * 0.3) + float(k) * 5.0, y - 1.0, 2.0, 1.0), _a(glow, 0.8))
		1:
			var pods := 3
			var pw := floorf(w * 0.7 / float(pods))
			for k in pods:
				b.draw_rect(Rect2(x0 + float(k) * pw, y - 5.0, pw - 1.0, 11.0), col)
			b.draw_rect(Rect2(x0 + float(pods) * pw, y - 3.0, w - float(pods) * pw, 7.0), col)
			b.draw_rect(Rect2(x0 + w - 4.0, y - 2.0, 3.0, 2.0), glow)
			b.draw_rect(Rect2(x0 - 3.0, y - 3.0, 3.0, 7.0), glow)
		_:
			b.draw_rect(Rect2(x0, y - 5.0, floorf(w * 0.25), 11.0), col)
			b.draw_rect(Rect2(x0 + floorf(w * 0.25), y - 1.0, floorf(w * 0.6), 2.0), col)
			b.draw_rect(Rect2(x0 + floorf(w * 0.85), y - 3.0, ceilf(w * 0.15), 6.0), col)
			b.draw_rect(Rect2(x0 - 3.0, y - 4.0, 3.0, 3.0), glow)
			b.draw_rect(Rect2(x0 - 3.0, y + 2.0, 3.0, 3.0), glow)


static func _person(b: PostingBoard, feet: Vector2, body: Color, skin: Color, tall: float = 18.0) -> void:
	var x := floorf(feet.x)
	var leg := floorf(tall * 0.35)
	b.draw_rect(Rect2(x - 3.0, feet.y - leg, 2.0, leg), body.darkened(0.4))
	b.draw_rect(Rect2(x + 1.0, feet.y - leg, 2.0, leg), body.darkened(0.4))
	var torso := floorf(tall * 0.4)
	b.draw_rect(Rect2(x - 4.0, feet.y - leg - torso, 8.0, torso), body)
	b.draw_rect(Rect2(x - 6.0, feet.y - leg - torso + 1.0, 2.0, torso - 2.0), body)
	b.draw_rect(Rect2(x + 4.0, feet.y - leg - torso + 1.0, 2.0, torso - 2.0), body)
	_disc(b, Vector2(x, feet.y - leg - torso - 4.0), 3, skin)


## A head and shoulders, front on, for posters and passes.
static func _face(b: PostingBoard, c: Vector2, r: int, skin: Color, hair: Color, shirt: Color) -> void:
	var rf := float(r)
	b.draw_rect(Rect2(c.x - rf - 4.0, c.y + rf, rf * 2.0 + 9.0, rf * 0.9), shirt)
	b.draw_rect(Rect2(c.x - 2.0, c.y + rf - 2.0, 5.0, 3.0), skin)
	_disc(b, c, r, hair)
	_disc(b, c + Vector2(0, 2), r - 1, skin)
	var ey := c.y + 1.0
	b.draw_rect(Rect2(c.x - floorf(rf * 0.4) - 1.0, ey, 2.0, 2.0), INK)
	b.draw_rect(Rect2(c.x + floorf(rf * 0.4), ey, 2.0, 2.0), INK)
	b.draw_rect(Rect2(c.x - 2.0, c.y + rf - 2.0, 5.0, 1.0), skin.darkened(0.4))


static func _critter(b: PostingBoard, kind: String, c: Vector2, col: Color) -> void:
	var dk := col.darkened(0.4)
	c = c.round()
	match kind:
		"cat":
			b.draw_rect(Rect2(c.x - 12.0, c.y - 4.0, 18.0, 9.0), col)
			b.draw_rect(Rect2(c.x - 16.0, c.y - 12.0, 3.0, 11.0), col)
			b.draw_rect(Rect2(c.x - 14.0, c.y - 3.0, 2.0, 3.0), col)
			for lx in [-11, -7, 1, 4]:
				b.draw_rect(Rect2(c.x + float(lx), c.y + 5.0, 2.0, 4.0), col)
			for sx in [-9, -5, -1]:
				b.draw_rect(Rect2(c.x + float(sx), c.y - 4.0, 2.0, 5.0), dk)
			_disc(b, c + Vector2(9, -6), 5, col)
			_poly(b, [c + Vector2(4, -8), c + Vector2(6, -15), c + Vector2(9, -10)], col)
			_poly(b, [c + Vector2(10, -10), c + Vector2(13, -15), c + Vector2(14, -8)], col)
			b.draw_rect(Rect2(c.x + 7.0, c.y - 7.0, 1.0, 2.0), INK)
			b.draw_rect(Rect2(c.x + 11.0, c.y - 7.0, 1.0, 2.0), INK)
			b.draw_rect(Rect2(c.x + 9.0, c.y - 4.0, 1.0, 1.0), Color("#d86a7a"))
		"drone":
			b.draw_rect(Rect2(c.x - 15.0, c.y - 7.0, 30.0, 2.0), dk)
			b.draw_rect(Rect2(c.x - 15.0, c.y - 9.0, 2.0, 3.0), dk)
			b.draw_rect(Rect2(c.x + 13.0, c.y - 9.0, 2.0, 3.0), dk)
			b.draw_rect(Rect2(c.x - 20.0, c.y - 10.0, 12.0, 1.0), INK_SOFT)
			b.draw_rect(Rect2(c.x + 8.0, c.y - 10.0, 12.0, 1.0), INK_SOFT)
			b.draw_rect(Rect2(c.x - 10.0, c.y - 5.0, 20.0, 10.0), col)
			b.draw_rect(Rect2(c.x - 10.0, c.y + 3.0, 20.0, 2.0), dk)
			_disc(b, c, 3, dk)
			_disc(b, c, 2, EMBER)
			b.draw_rect(Rect2(c.x - 8.0, c.y + 5.0, 3.0, 3.0), dk)
			b.draw_rect(Rect2(c.x + 5.0, c.y + 5.0, 3.0, 3.0), dk)
		"lizard":
			b.draw_rect(Rect2(c.x - 10.0, c.y - 3.0, 20.0, 6.0), col)
			b.draw_rect(Rect2(c.x + 10.0, c.y - 3.0, 8.0, 5.0), col)
			b.draw_rect(Rect2(c.x + 18.0, c.y - 2.0, 2.0, 3.0), col)
			b.draw_rect(Rect2(c.x + 14.0, c.y - 2.0, 1.0, 1.0), INK)
			b.draw_rect(Rect2(c.x - 16.0, c.y - 2.0, 6.0, 4.0), col)
			b.draw_rect(Rect2(c.x - 21.0, c.y - 1.0, 5.0, 2.0), col)
			b.draw_rect(Rect2(c.x - 25.0, c.y, 4.0, 1.0), col)
			for lx in [-8, 6]:
				b.draw_rect(Rect2(c.x + float(lx), c.y + 3.0, 2.0, 4.0), col)
				b.draw_rect(Rect2(c.x + float(lx) - 1.0, c.y + 7.0, 4.0, 1.0), col)
				b.draw_rect(Rect2(c.x + float(lx), c.y - 7.0, 2.0, 4.0), col)
				b.draw_rect(Rect2(c.x + float(lx) - 1.0, c.y - 8.0, 4.0, 1.0), col)
			for sx in [-6, -1, 4]:
				b.draw_rect(Rect2(c.x + float(sx), c.y - 1.0, 2.0, 2.0), dk)
		"bird":
			b.draw_rect(Rect2(c.x - 13.0, c.y - 1.0, 6.0, 3.0), dk)
			_disc(b, c, 7, col)
			_disc(b, c + Vector2(7, -7), 4, col)
			_poly(b, [c + Vector2(11, -9), c + Vector2(16, -7), c + Vector2(11, -5)], EMBER)
			b.draw_rect(Rect2(c.x + 8.0, c.y - 9.0, 2.0, 2.0), INK)
			_disc(b, c + Vector2(-2, 1), 4, dk)
			b.draw_rect(Rect2(c.x - 2.0, c.y + 7.0, 1.0, 4.0), EMBER)
			b.draw_rect(Rect2(c.x + 2.0, c.y + 7.0, 1.0, 4.0), EMBER)


## Little drawings for cards and notices, in about 16 by 16.
static func _icon(b: PostingBoard, kind: String, c: Vector2, col: Color) -> void:
	c = c.round()
	match kind:
		"cross":
			b.draw_rect(Rect2(c.x - 2.0, c.y - 6.0, 5.0, 13.0), col)
			b.draw_rect(Rect2(c.x - 6.0, c.y - 2.0, 13.0, 5.0), col)
		"spark":
			for d in 8:
				var ang := float(d) * TAU / 8.0
				var ln := 7.0 if d % 2 == 0 else 4.0
				b.draw_line(c, c + Vector2(cos(ang), sin(ang)) * ln, col, 2.0)
			_disc(b, c, 2, Color("#fff0b0"))
		"eye":
			_poly(b, [c + Vector2(-8, 0), c + Vector2(-3, -4), c + Vector2(3, -4), c + Vector2(8, 0), c + Vector2(3, 4), c + Vector2(-3, 4)], col)
			_disc(b, c, 3, Color("#3a8ac8"))
			_disc(b, c, 1, INK)
		"scissors":
			_ring(b, c + Vector2(-5, 4), 3, col, Color(0, 0, 0, 0))
			_ring(b, c + Vector2(5, 4), 3, col, Color(0, 0, 0, 0))
			b.draw_line(c + Vector2(-3, 2), c + Vector2(5, -7), col, 1.0)
			b.draw_line(c + Vector2(3, 2), c + Vector2(-5, -7), col, 1.0)
		"horn":
			# a loud hailer: the bell opening to the right, a handle under it
			_poly(b, [c + Vector2(-6, -2), c + Vector2(6, -8), c + Vector2(6, 8), c + Vector2(-6, 2)], col)
			b.draw_rect(Rect2(c.x - 9.0, c.y - 2.0, 3.0, 5.0), col)
			b.draw_rect(Rect2(c.x - 3.0, c.y + 2.0, 2.0, 6.0), col)
			b.draw_line(c + Vector2(9, -5), c + Vector2(11, -7), col, 1.0)
			b.draw_line(c + Vector2(9, 0), c + Vector2(12, 0), col, 1.0)
			b.draw_line(c + Vector2(9, 5), c + Vector2(11, 7), col, 1.0)
		"drop":
			_disc(b, c + Vector2(0, 2), 5, col)
			_poly(b, [c + Vector2(-5, 1), c + Vector2(0, -8), c + Vector2(5, 1)], col)
			b.draw_rect(Rect2(c.x - 2.0, c.y, 1.0, 3.0), Color(1, 1, 1, 0.6))
		"glass":
			_poly(b, [c + Vector2(-6, -8), c + Vector2(6, -8), c + Vector2(4, -1), c + Vector2(-4, -1)], col)
			b.draw_rect(Rect2(c.x - 1.0, c.y - 1.0, 2.0, 7.0), col)
			b.draw_rect(Rect2(c.x - 5.0, c.y + 6.0, 10.0, 2.0), col)
		"flame":
			_poly(b, [c + Vector2(0, -9), c + Vector2(6, 0), c + Vector2(4, 7), c + Vector2(-4, 7), c + Vector2(-6, 0), c + Vector2(-2, -3)], col)
			_poly(b, [c + Vector2(0, -2), c + Vector2(3, 3), c + Vector2(2, 7), c + Vector2(-2, 7), c + Vector2(-3, 3)], Color("#f8d860"))
		"note":
			_disc(b, c + Vector2(-3, 5), 3, col)
			b.draw_rect(Rect2(c.x, c.y - 8.0, 1.0, 13.0), col)
			b.draw_rect(Rect2(c.x, c.y - 8.0, 6.0, 2.0), col)
			b.draw_rect(Rect2(c.x + 5.0, c.y - 8.0, 1.0, 5.0), col)


# --- the painters ----------------------------------------------------------

## FOR SALE, with its number on tear-off tabs. A taken tab leaves a stub, and the
## cork shows where it was: the paper throws no shadow there.
static func _sale(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var tabs_h := 32.0
	var n: int = P.get("n", 7)
	var body := Rect2(2.0, 2.0, sz.x - 6.0, sz.y - 6.0 - tabs_h)
	var tw := floorf(body.size.x / float(n))
	var col: Color = P.get("c", CREAM)
	var torn: Array = P.get("torn", [])
	var sh := _a(SHADE, 0.4)
	b.draw_rect(Rect2(body.position + Vector2(3, 4), body.size), sh)
	for k in n:
		if not torn.has(k):
			b.draw_rect(Rect2(body.position.x + float(k) * tw + 3.0, body.end.y + 4.0, tw - 1.0, tabs_h), sh)
	b.draw_rect(body, col)
	var t: String = P["t"]
	var tc: Color = P.get("tc", RED)
	if t.length() <= 8:
		_cx(b, t, body.position.x, 23.0, body.size.x, H, tc)
	else:
		_cx(b, t, body.position.x, 20.0, body.size.x, F, tc)
		b.draw_rect(Rect2(body.position.x + 12.0, 23.0, body.size.x - 24.0, 1.0), tc)
	var y := 36.0
	var lines: Array = P.get("l", [])
	for k in lines.size():
		_cx(b, String(lines[k]), body.position.x + 2.0, y, body.size.x - 4.0, F, INK if k == 0 else INK_SOFT)
		y += 11.0
	var ph: String = P.get("ph", "4417")
	for k in n:
		var tx := body.position.x + float(k) * tw
		if torn.has(k):
			b.draw_rect(Rect2(tx, body.end.y, tw - 1.0, 1.0 + float((k * 5 + i) % 3)), col)
			continue
		b.draw_rect(Rect2(tx, body.end.y, tw - 1.0, tabs_h), col)
		for c in ph.length():
			_cx(b, ph.substr(c, 1), tx, body.end.y + 9.0 + float(c) * 7.0, tw - 1.0, F, INK)
	_dash_h(b, body.position.x, body.end.x, body.end.y, _a(INK_SOFT, 0.7))
	b._pin(Vector2(body.position.x + floorf(body.size.x * 0.5), 5.0), _pc(i))


## LOST, with a drawing done by somebody who misses it.
static func _lost(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var col: Color = P.get("c", WHITE)
	_paper(b, r, col)
	_cx(b, String(P["t"]), r.position.x, 22.0, r.size.x, H, RED)
	var box := Rect2(r.position.x + 8.0, 28.0, r.size.x - 16.0, 38.0)
	b.draw_rect(box, col.darkened(0.08))
	b.draw_rect(box, INK_SOFT, false, 1.0)
	_critter(b, String(P["pic"]), box.get_center() + Vector2(0, 4), P.get("pc", EMBER))
	var y := 78.0
	var lines: Array = P.get("l", [])
	for k in lines.size():
		_cx(b, String(lines[k]), r.position.x + 2.0, y, r.size.x - 4.0, F, INK if k == 0 else INK_SOFT)
		y += 11.0
	if P.has("rw"):
		_cx(b, String(P["rw"]), r.position.x, r.end.y - 6.0, r.size.x, F, RED)
	b._pin(Vector2(r.position.x + 5.0, 5.0), _pc(i))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i, 1))


## An index card: its title over the red line, the rest on the blue ones, typed
## or in biro.
static func _index(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, P.get("c", INDEX), 0.4, false)
	b.draw_rect(Rect2(r.position.x, 16.0, r.size.x, 1.0), _a(RED, 0.7))
	var hand: bool = P.get("hand", false)
	# biro is taller than type, so its lines are further apart
	var step := 13.0 if hand else 11.0
	var ly := 27.0 if not hand else 30.0
	while ly < r.end.y - 1.0:
		b.draw_rect(Rect2(r.position.x, ly, r.size.x, 1.0), _a(BLUE, 0.22))
		ly += step
	_tx(b, String(P["t"]), r.position.x + 5.0, 13.0, F, INK, r.size.x - 20.0)
	var ink: Color = P.get("ink", BLUE)
	var lines: Array = P.get("l", [])
	var y := 25.0 if not hand else 28.0
	for k in lines.size():
		if hand:
			_hx(b, String(lines[k]), Vector2(r.position.x + 6.0, y), ink, float(i * 5 + k), r.size.x - 10.0)
		else:
			_tx(b, String(lines[k]), r.position.x + 6.0, y, F, ink, r.size.x - 10.0)
		y += step
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i))


## A gig poster: a loud colour, the act's name big, a picture of the noise.
static func _gig(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var bg: Color = P["c"]
	var a: Color = P["a"]
	var lt: Color = P.get("lt", Color("#f8f0e0"))
	_paper(b, r, bg, 0.45, false)
	_cx(b, String(P["t"]), r.position.x, 22.0, r.size.x, H, a)
	var top := 28.0
	if P.has("t2"):
		_cx(b, String(P["t2"]), r.position.x, 38.0, r.size.x, H, lt)
		top = 42.0
	var lines: Array = P.get("l", [])
	var foot := r.end.y - 6.0 - float(lines.size() - 1) * 11.0
	var art := Rect2(r.position.x + 10.0, top, r.size.x - 20.0, foot - top - 12.0)
	match String(P.get("deco", "eq")):
		"eq":
			var k := 0
			var x := art.position.x
			while x + 4.0 <= art.end.x:
				var hgt := 4.0 + float((k * 7 + i * 3) % int(maxf(art.size.y - 4.0, 2.0)))
				b.draw_rect(Rect2(x, art.end.y - hgt, 4.0, hgt), a if k % 2 == 0 else lt)
				x += 6.0
				k += 1
		"bolt":
			var c := art.get_center()
			_poly(b, [c + Vector2(4, -16), c + Vector2(-8, 2), c + Vector2(0, 2), c + Vector2(-4, 16), c + Vector2(8, -2), c + Vector2(0, -2)], a)
			for k in 6:
				_star(b, Vector2(art.position.x + float((k * 29 + i * 7) % int(art.size.x)), art.position.y + float((k * 17 + i) % int(art.size.y))), 1, lt)
		"note":
			var c := art.get_center()
			_icon(b, "note", c + Vector2(-14, 0), a)
			_icon(b, "note", c + Vector2(10, -4), a)
			_disc(b, c + Vector2(-1, 6), 2, a)
			b.draw_rect(Rect2(c.x + 1.0, c.y - 4.0, 1.0, 10.0), a)
	for k in lines.size():
		_cx(b, String(lines[k]), r.position.x + 2.0, foot + float(k) * 11.0, r.size.x - 4.0, F, lt)
	b._pin(Vector2(r.position.x + 5.0, 5.0), _pc(i))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i, 2))


## A ticket stub, its perforation down the right where the rest was torn away.
static func _ticket(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var col: Color = P["c"]
	_paper(b, r, col, 0.4, false)
	var perf := r.end.x - 20.0
	b.draw_rect(Rect2(r.position.x + 3.0, r.position.y + 3.0, perf - r.position.x - 6.0, r.size.y - 6.0), col.darkened(0.25), false, 1.0)
	_dash_v(b, perf, r.position.y + 1.0, r.end.y - 1.0, _a(INK_SOFT, 0.8), 1.0, 2.0)
	_tx(b, String(P["t"]), r.position.x + 7.0, 15.0, F, INK_SOFT, perf - r.position.x - 12.0)
	_tx(b, String(P["l"]), r.position.x + 7.0, 26.0, F, INK, perf - r.position.x - 12.0)
	_tx(b, String(P["n"]), r.position.x + 7.0, 36.0, F, RED, perf - r.position.x - 12.0)
	_star(b, Vector2(perf + 10.0, r.position.y + 26.0), 3, col.darkened(0.35))
	b._pin(Vector2(perf + 9.0, 6.0), _pc(i))


## A till receipt, long and thin, its bottom torn off along the teeth.
static func _receipt(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := Rect2(2.0, 2.0, sz.x - 6.0, sz.y - 12.0)
	var col := Color("#f2f0ea")
	var pts := [r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y)]
	var x := r.end.x
	var down := true
	while x > r.position.x:
		x = maxf(r.position.x, x - 3.0)
		pts.append(Vector2(x, r.end.y + (3.0 if down else 0.0)))
		down = not down
	pts.append(Vector2(r.position.x, r.end.y))
	_poly(b, pts, _a(SHADE, 0.4), Vector2(3, 4))
	_poly(b, pts, col)
	var w := r.size.x
	_cx(b, String(P["t"]), r.position.x, 19.0, w, F, INK)
	_cx(b, String(P.get("u", "")), r.position.x, 29.0, w, F, INK_SOFT)
	_dash_h(b, r.position.x + 3.0, r.end.x - 3.0, 33.0, INK_SOFT, 2.0, 2.0)
	var y := 44.0
	var items: Array = P.get("it", [])
	for it: Array in items:
		_tx(b, String(it[0]), r.position.x + 4.0, y, F, INK_SOFT, w - 18.0)
		_rx(b, String(it[1]), r.end.x - 4.0, y, F, INK_SOFT)
		y += 10.0
	_dash_h(b, r.position.x + 3.0, r.end.x - 3.0, y - 5.0, INK_SOFT, 2.0, 2.0)
	_tx(b, "TOTAL", r.position.x + 4.0, y + 6.0, F, INK, w - 18.0)
	_rx(b, String(P.get("tot", "")), r.end.x - 4.0, y + 6.0, F, INK)
	_cx(b, "THANK YOU", r.position.x, r.end.y - 4.0, w, F, INK_SOFT)
	b._pin(Vector2(r.position.x + floorf(w * 0.5), 5.0), _pc(i))


## A postcard: somewhere else, in colours this place has not got.
static func _postcard(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, Color("#f0ece2"), 0.4, false)
	var pic := r.grow(-3.0)
	var sky: Color = P["sky"]
	b.draw_rect(pic, sky)
	for k in 18:
		var sx := pic.position.x + 2.0 + float((k * 37 + i * 11) % int(pic.size.x - 4.0))
		var sy := pic.position.y + 2.0 + float((k * 23 + i * 7) % int(pic.size.y - 4.0))
		b.draw_rect(Rect2(sx, sy, 1.0, 1.0), Color(1, 1, 1, 0.5 + 0.1 * float(k % 4)))
	var pl: Color = P["pl"]
	var c := Vector2(pic.position.x + floorf(pic.size.x * 0.66), pic.position.y + floorf(pic.size.y * 0.56))
	_disc(b, c, 17, pl.darkened(0.45))
	_disc(b, c + Vector2(-2, -2), 15, pl)
	b.draw_rect(Rect2(c.x - 9.0, c.y - 6.0, 14.0, 2.0), pl.lightened(0.25))
	b.draw_rect(Rect2(c.x - 12.0, c.y + 2.0, 10.0, 2.0), pl.darkened(0.15))
	if P.get("ring", false):
		var rc := Color("#f0e0b0")
		b.draw_rect(Rect2(c.x - 30.0, c.y + 3.0, 16.0, 2.0), rc)
		b.draw_rect(Rect2(c.x - 14.0, c.y + 1.0, 28.0, 2.0), rc)
		b.draw_rect(Rect2(c.x + 14.0, c.y - 1.0, 16.0, 2.0), rc)
	_tx(b, "HELLO FROM", pic.position.x + 4.0, 17.0, F, Color("#f0f0e8"), pic.size.x - 26.0)
	var t: String = P["t"]
	var fs := H if _w(t, H) <= pic.size.x - 8.0 else F
	b._text(t, pic.position.x + 5.0, pic.end.y - 4.0, fs, Color(0, 0, 0, 0.6))
	_tx(b, t, pic.position.x + 4.0, pic.end.y - 5.0, fs, Color("#f8d860"), pic.size.x - 8.0)
	# the stamp, top right
	var st := Rect2(pic.end.x - 16.0, pic.position.y + 3.0, 13.0, 15.0)
	b.draw_rect(st, Color("#f0ece2"))
	b.draw_rect(st.grow(-2.0), Color("#c84a4a"))
	_disc(b, st.get_center(), 2, Color("#f0d070"))
	_tape(b, Rect2(0.0, 1.0, 16.0, 7.0))
	_tape(b, Rect2(sz.x - 22.0, sz.y - 14.0, 16.0, 7.0))


## A child's drawing, in crayon, by the hand of the marker helpers.
static func _crayon(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, Color("#f6f4ee"), 0.4, false)
	var sd := float(i) * 7.3
	var cc: Color = P["cc"]
	var o := r.position
	_hx(b, String(P["t"]), o + Vector2(7, 17), cc, sd, r.size.x - 12.0)
	var blue := Color("#3a6ad8")
	var yellow := Color("#e8b820")
	var orange := Color("#e8782a")
	var green := Color("#3aa04a")
	var brown := Color("#8a5a2a")
	match String(P["pic"]):
		"mum":
			# a sun, a ship, and Mum, as big as the ship
			b._wobble_circle(o + Vector2(80, 32), 6.0, yellow, sd)
			for d in 6:
				var ang := float(d) * TAU / 6.0
				b._wobble_line(o + Vector2(80, 32) + Vector2(cos(ang), sin(ang)) * 9.0, o + Vector2(80, 32) + Vector2(cos(ang), sin(ang)) * 12.0, yellow, sd + float(d))
			b._wobble_circle(o + Vector2(22, 38), 6.0, cc, sd + 1.0)
			b._wobble_line(o + Vector2(22, 44), o + Vector2(22, 62), cc, sd + 2.0)
			b._wobble_line(o + Vector2(13, 50), o + Vector2(31, 48), cc, sd + 3.0)
			b._wobble_line(o + Vector2(22, 62), o + Vector2(15, 76), cc, sd + 4.0)
			b._wobble_line(o + Vector2(22, 62), o + Vector2(29, 76), cc, sd + 5.0)
			b._wobble_rect(Rect2(o.x + 42.0, o.y + 54.0, 30.0, 12.0), blue, sd + 6.0)
			b._wobble_line(o + Vector2(72, 54), o + Vector2(84, 60), blue, sd + 7.0)
			b._wobble_line(o + Vector2(84, 60), o + Vector2(72, 66), blue, sd + 8.0)
			b._wobble_line(o + Vector2(40, 57), o + Vector2(32, 60), orange, sd + 9.0)
			b._wobble_line(o + Vector2(40, 63), o + Vector2(34, 66), orange, sd + 10.0)
		"whale":
			b._wobble_circle(o + Vector2(44, 52), 17.0, blue, sd)
			b._wobble_line(o + Vector2(60, 50), o + Vector2(78, 40), blue, sd + 1.0)
			b._wobble_line(o + Vector2(78, 40), o + Vector2(76, 60), blue, sd + 2.0)
			b._wobble_line(o + Vector2(76, 60), o + Vector2(60, 56), blue, sd + 3.0)
			b.draw_rect(Rect2(o.x + 34.0, o.y + 46.0, 3.0, 3.0), Color("#202020"))
			b._wobble_line(o + Vector2(32, 58), o + Vector2(42, 60), Color("#d04a6a"), sd + 4.0)
			for k in 5:
				_star(b, o + Vector2(10.0 + float(k * 19 % 80), 30.0 + float(k * 13 % 50)), 2, yellow)
		"dad":
			b._wobble_circle(o + Vector2(28, 40), 7.0, brown, sd)
			b._wobble_line(o + Vector2(28, 47), o + Vector2(28, 66), brown, sd + 1.0)
			b._wobble_line(o + Vector2(18, 54), o + Vector2(44, 56), brown, sd + 2.0)
			b._wobble_line(o + Vector2(28, 66), o + Vector2(20, 80), brown, sd + 3.0)
			b._wobble_line(o + Vector2(28, 66), o + Vector2(36, 80), brown, sd + 4.0)
			b._wobble_circle(o + Vector2(54, 54), 5.0, cc, sd + 5.0)
			b._wobble_line(o + Vector2(54, 59), o + Vector2(54, 70), cc, sd + 6.0)
			b._wobble_line(o + Vector2(44, 58), o + Vector2(62, 62), cc, sd + 7.0)
			b._wobble_line(o + Vector2(54, 70), o + Vector2(49, 80), cc, sd + 8.0)
			b._wobble_line(o + Vector2(54, 70), o + Vector2(59, 80), cc, sd + 9.0)
			# a heart over them
			b._wobble_circle(o + Vector2(76, 40), 3.0, Color("#e04a6a"), sd + 10.0)
			b._wobble_circle(o + Vector2(82, 40), 3.0, Color("#e04a6a"), sd + 11.0)
			b._wobble_line(o + Vector2(73, 42), o + Vector2(79, 50), Color("#e04a6a"), sd + 12.0)
			b._wobble_line(o + Vector2(85, 42), o + Vector2(79, 50), Color("#e04a6a"), sd + 13.0)
			b._wobble_line(o + Vector2(4, 80), o + Vector2(90, 81), green, sd + 14.0)
		"bad":
			# a long ship with teeth and two red eyes: the one the grown-ups talk about
			b._wobble_rect(Rect2(o.x + 14.0, o.y + 40.0, 66.0, 20.0), Color("#303030"), sd)
			for k in 6:
				var tx := o.x + 18.0 + float(k) * 10.0
				b._wobble_line(Vector2(tx, o.y + 60.0), Vector2(tx + 5.0, o.y + 52.0), Color("#303030"), sd + float(k))
			b._wobble_circle(o + Vector2(70, 47), 2.0, cc, sd + 8.0)
			b._wobble_circle(o + Vector2(60, 47), 2.0, cc, sd + 9.0)
			b._wobble_line(o + Vector2(14, 44), o + Vector2(4, 40), orange, sd + 10.0)
			b._wobble_line(o + Vector2(14, 56), o + Vector2(4, 60), orange, sd + 11.0)
			b._wobble_line(o + Vector2(14, 50), o + Vector2(2, 50), yellow, sd + 12.0)
	_tape(b, Rect2(floorf(sz.x * 0.5) - 9.0, 0.0, 18.0, 7.0))


## A polaroid: the photo square, the caption below in pen.
static func _polaroid(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, Color("#eeeae0"), 0.4, false)
	var ph := Rect2(r.position.x + 5.0, r.position.y + 5.0, r.size.x - 10.0, r.size.x - 12.0)
	var bg: Color = P.get("bg", Color("#1c2a3a"))
	b.draw_rect(ph, bg)
	var c := ph.get_center()
	match String(P["pic"]):
		"ship":
			for k in 8:
				b.draw_rect(Rect2(ph.position.x + float((k * 17 + 3) % int(ph.size.x)), ph.position.y + float((k * 11 + 5) % int(ph.size.y)), 1.0, 1.0), Color(1, 1, 1, 0.6))
			_ship(b, c + Vector2(2, 2), 28.0, Color("#b8c4d0"), EMBER, 0)
		"crew":
			b.draw_rect(Rect2(ph.position.x, ph.end.y - 8.0, ph.size.x, 8.0), bg.darkened(0.3))
			_person(b, Vector2(ph.position.x + 12.0, ph.end.y - 6.0), Color("#c85a3a"), SKIN[0], 20.0)
			_person(b, Vector2(ph.position.x + 25.0, ph.end.y - 6.0), Color("#3a8ac8"), SKIN[2], 24.0)
			_person(b, Vector2(ph.position.x + 38.0, ph.end.y - 6.0), Color("#e8c040"), SKIN[1], 18.0)
		"cat":
			b.draw_rect(Rect2(ph.position.x, ph.end.y - 10.0, ph.size.x, 10.0), Color("#8a6a4a"))
			_critter(b, "cat", c + Vector2(2, 6), Color("#9a9aa0"))
		"cake":
			b.draw_rect(Rect2(c.x - 14.0, c.y + 2.0, 28.0, 12.0), Color("#f0d0e0"))
			b.draw_rect(Rect2(c.x - 14.0, c.y + 2.0, 28.0, 3.0), Color("#f8f0f0"))
			b.draw_rect(Rect2(c.x - 18.0, c.y + 14.0, 36.0, 2.0), Color("#d8d8d8"))
			for k in 4:
				var cx := c.x - 9.0 + float(k) * 6.0
				b.draw_rect(Rect2(cx, c.y - 5.0, 2.0, 7.0), Color("#80c0f0"))
				b.draw_rect(Rect2(cx, c.y - 9.0, 2.0, 3.0), Color("#f8d040"))
				b.draw_rect(Rect2(cx - 2.0, c.y - 11.0, 6.0, 6.0), Color(1.0, 0.8, 0.3, 0.2))
	_cx(b, String(P["t"]), r.position.x + 2.0, r.end.y - 6.0, r.size.x - 4.0, F, BLUE)
	b._pin(Vector2(r.position.x + floorf(r.size.x * 0.5), 5.0), _pc(i))


## A page torn off a calendar: the days gone by crossed out, one ringed.
static func _calendar(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, WHITE)
	b.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 22.0), Color("#c8483a"))
	_cx(b, String(P["t"]), r.position.x, 20.0, r.size.x, H, Color("#f8f0e0"))
	var cw := 12.0
	var x0 := r.position.x + floorf((r.size.x - cw * 7.0) * 0.5)
	var days := ["M", "T", "W", "T", "F", "S", "S"]
	for d in 7:
		_cx(b, days[d], x0 + float(d) * cw, 34.0, cw, F, INK_SOFT if d < 5 else RED)
	var y0 := 37.0
	var crossed: int = P.get("x", 10)
	var ringed: int = P.get("o", 20)
	for row in 5:
		for d in 7:
			var day := row * 7 + d + 1
			if day > 30:
				continue
			var cell := Rect2(x0 + float(d) * cw, y0 + float(row) * 11.0, cw, 11.0)
			b.draw_rect(cell, _a(INK_SOFT, 0.35), false, 1.0)
			if day <= crossed:
				b.draw_line(cell.position + Vector2(3, 2), cell.end - Vector2(3, 2), _a(RED, 0.85), 1.0)
				b.draw_line(Vector2(cell.end.x - 3.0, cell.position.y + 2.0), Vector2(cell.position.x + 3.0, cell.end.y - 2.0), _a(RED, 0.85), 1.0)
			if day == ringed:
				b._wobble_circle(cell.get_center(), 6.0, BLUE, float(i))
	_hx(b, String(P.get("n", "")), Vector2(r.position.x + 10.0, r.end.y - 4.0), BLUE, float(i) * 2.0, r.size.x - 14.0)
	b._pin(Vector2(r.position.x + 5.0, 5.0), _pc(i))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i, 1))


## A safety notice: a word in capitals, a triangle, stripes.
static func _safety(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var col: Color = P.get("c", Color("#f0cc3a"))
	_paper(b, r, col)
	_cx(b, String(P["t"]), r.position.x, 22.0, r.size.x, H, P.get("tc", INK))
	var c := Vector2(r.position.x + floorf(r.size.x * 0.5), 42.0)
	var tc: Color = P.get("tc", INK)
	_poly(b, [c + Vector2(0, -13), c + Vector2(14, 11), c + Vector2(-14, 11)], tc)
	_poly(b, [c + Vector2(0, -8), c + Vector2(10, 8), c + Vector2(-10, 8)], col)
	b.draw_rect(Rect2(c.x - 1.0, c.y - 4.0, 2.0, 7.0), tc)
	b.draw_rect(Rect2(c.x - 1.0, c.y + 5.0, 2.0, 2.0), tc)
	var y := 66.0
	for line in P.get("l", []):
		_cx(b, String(line), r.position.x + 2.0, y, r.size.x - 4.0, F, INK)
		y += 11.0
	_hazard(b, Rect2(r.position.x + 1.0, r.end.y - 9.0, r.size.x - 2.0, 8.0), tc)
	b._pin(Vector2(r.position.x + 5.0, 5.0), _pc(i))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i, 1))


## A typed notice: a title, maybe a picture, the facts, and a last word.
static func _notice(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var col: Color = P.get("c", CREAM)
	_paper(b, r, col)
	_cx(b, String(P["t"]), r.position.x, 18.0, r.size.x, F, INK)
	b.draw_rect(Rect2(r.position.x + 8.0, 22.0, r.size.x - 16.0, 1.0), INK_SOFT)
	var y := 36.0
	if P.has("icon"):
		_icon(b, String(P["icon"]), Vector2(r.position.x + floorf(r.size.x * 0.5), 38.0), RED)
		y = 60.0
	var left: bool = P.get("left", false)
	for line in P.get("l", []):
		if left:
			_tx(b, String(line), r.position.x + 12.0, y, F, INK_SOFT, r.size.x - 16.0)
		else:
			_cx(b, String(line), r.position.x + 2.0, y, r.size.x - 4.0, F, INK_SOFT)
		y += 11.0
	if P.has("f"):
		_cx(b, String(P["f"]), r.position.x + 2.0, r.end.y - 6.0, r.size.x - 4.0, F, RED)
	b._pin(Vector2(r.position.x + 5.0, 5.0), _pc(i))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i, 1))


## A page torn out of a spiral pad, in pen: the holes along its top are the pad's.
static func _note(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, Color("#f2f0e6"), 0.4, false)
	var ly := 20.0
	while ly < r.end.y - 1.0:
		b.draw_rect(Rect2(r.position.x, ly, r.size.x, 1.0), _a(BLUE, 0.25))
		ly += 12.0
	b.draw_rect(Rect2(r.position.x + 11.0, r.position.y, 1.0, r.size.y), _a(RED, 0.4))
	var hx := r.position.x + 18.0
	while hx < r.end.x - 4.0:
		b.draw_rect(Rect2(hx, r.position.y + 2.0, 3.0, 2.0), CORK)
		hx += 9.0
	var pen: Color = P.get("pen", BLUE)
	var y := 18.0
	var lines: Array = P.get("l", [])
	for k in lines.size():
		_hx(b, String(lines[k]), Vector2(r.position.x + 14.0, y), pen, float(i) * 3.0 + float(k), r.size.x - 16.0)
		y += 12.0
	b._pin(Vector2(r.end.x - 7.0, 9.0), _pc(i))


## A business card: who, what, where, and a little picture of the work.
static func _biz(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var col: Color = P.get("c", WHITE)
	var ink: Color = P.get("ink", INK)
	var soft: Color = P.get("soft", INK_SOFT)
	_paper(b, r, col, 0.4, false)
	b.draw_rect(r, ink.lerp(col, 0.5), false, 1.0)
	_tx(b, String(P["t"]), r.position.x + 5.0, 15.0, F, ink, r.size.x - 22.0)
	var lines: Array = P.get("l", [])
	for k in lines.size():
		_tx(b, String(lines[k]), r.position.x + 5.0, 28.0 + float(k) * 10.0, F, soft, r.size.x - 26.0)
	var ic := {"cross": RED, "eye": Color("#f0e8d0"), "spark": EMBER, "scissors": INK}
	_icon(b, String(P["icon"]), Vector2(r.end.x - 12.0, 32.0), ic.get(String(P["icon"]), INK))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i))


## Another stall's menu: a band of colour, its dishes, their prices.
static func _menu(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var col: Color = P["c"]
	var a: Color = P["a"]
	_paper(b, r, col)
	b.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 22.0), a)
	_cx(b, String(P["t"]), r.position.x, 20.0, r.size.x, H, col)
	var y := 38.0
	for it: Array in P.get("it", []):
		var name := String(it[0])
		_tx(b, name, r.position.x + 6.0, y, F, INK, r.size.x - 26.0)
		var dx := r.position.x + 8.0 + _w(name, F)
		while dx < r.end.x - 16.0:
			b.draw_rect(Rect2(dx, y - 1.0, 1.0, 1.0), INK_SOFT)
			dx += 3.0
		_rx(b, String(it[1]), r.end.x - 6.0, y, F, a)
		y += 13.0
	_cx(b, String(P.get("f", "")), r.position.x, r.end.y - 6.0, r.size.x, F, a)
	b._pin(Vector2(r.position.x + 5.0, 5.0), _pc(i))


## A coupon, cut out along its dashed line, and stapled up.
static func _coupon(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var col: Color = P["c"]
	_paper(b, r, col, 0.4, false)
	var in_r := r.grow(-3.0)
	_dash_h(b, in_r.position.x, in_r.end.x, in_r.position.y, INK_SOFT)
	_dash_h(b, in_r.position.x, in_r.end.x, in_r.end.y - 1.0, INK_SOFT)
	_dash_v(b, in_r.position.x, in_r.position.y, in_r.end.y, INK_SOFT)
	_dash_v(b, in_r.end.x - 1.0, in_r.position.y, in_r.end.y, INK_SOFT)
	_cx(b, String(P["t"]), r.position.x, 23.0, r.size.x, H, RED)
	var lines: Array = P.get("l", [])
	for k in lines.size():
		_cx(b, String(lines[k]), r.position.x + 4.0, 36.0 + float(k) * 11.0, r.size.x - 8.0, F, INK if k == 0 else INK_SOFT)
	_staple(b, Vector2(r.position.x + 4.0, 6.0))
	_staple(b, Vector2(r.end.x - 13.0, 6.0))


## A calm flyer: a sun of rings in the middle, the words soft around it.
static func _calm(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var col: Color = P["c"]
	var a: Color = P["a"]
	_paper(b, r, col)
	_cx(b, String(P["t"]), r.position.x, 22.0, r.size.x, H, a.darkened(0.3))
	var c := Vector2(r.position.x + floorf(r.size.x * 0.5), 48.0)
	_disc(b, c, 17, col.lerp(a, 0.25))
	_disc(b, c, 12, col.lerp(a, 0.5))
	_disc(b, c, 7, a)
	var y := 80.0
	for line in P.get("l", []):
		_cx(b, String(line), r.position.x + 2.0, y, r.size.x - 4.0, F, INK_SOFT)
		y += 11.0
	b._pin(Vector2(r.position.x + 5.0, 5.0), _pc(i))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i, 1))


## HAVE YOU SEEN THIS SHIP: a photo of it, and who wants to know.
static func _seen(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, Color("#dedbd2"))
	_cx(b, "HAVE YOU SEEN", r.position.x, 13.0, r.size.x, F, INK)
	_cx(b, "THIS SHIP?", r.position.x, 23.0, r.size.x, F, RED)
	var ph := Rect2(r.position.x + 8.0, 28.0, r.size.x - 16.0, 40.0)
	b.draw_rect(ph, Color("#22303e"))
	for k in 10:
		b.draw_rect(Rect2(ph.position.x + float((k * 23 + i) % int(ph.size.x)), ph.position.y + float((k * 13 + 3) % int(ph.size.y)), 1.0, 1.0), Color(1, 1, 1, 0.5))
	_ship(b, ph.get_center() + Vector2(4, 0), 46.0, Color("#c0c8d0"), EMBER, int(P.get("pic", 0)))
	var y := 80.0
	for line in P.get("l", []):
		_cx(b, String(line), r.position.x + 2.0, y, r.size.x - 4.0, F, INK if y < 81.0 else INK_SOFT)
		y += 11.0
	b._pin(Vector2(r.position.x + 5.0, 5.0), _pc(i))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i, 1))


## A deck plan torn out of a guide: halls, rooms, and an X where somebody was.
static func _map(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := Rect2(2.0, 2.0, sz.x - 10.0, sz.y - 6.0)
	var col := Color("#d4e2c8")
	_shadow(b, r)
	b.draw_rect(r, col)
	_ragged_right(b, r.end.x, r.position.y, r.size.y, col, i)
	var gx := r.position.x + 4.0
	while gx < r.end.x:
		b.draw_rect(Rect2(gx, r.position.y, 1.0, r.size.y), _a(GREEN, 0.12))
		gx += 8.0
	var gy := r.position.y + 4.0
	while gy < r.end.y:
		b.draw_rect(Rect2(r.position.x, gy, r.size.x, 1.0), _a(GREEN, 0.12))
		gy += 8.0
	var hall := Color("#4a6a8a")
	b.draw_rect(Rect2(r.position.x + 6.0, 54.0, r.size.x - 8.0, 5.0), hall)
	b.draw_rect(Rect2(r.position.x + 40.0, 26.0, 5.0, r.size.y - 30.0), hall)
	b.draw_rect(Rect2(r.position.x + 76.0, 30.0, 5.0, 26.0), hall)
	for rm: Rect2 in [Rect2(8, 28, 26, 20), Rect2(52, 28, 20, 20), Rect2(8, 64, 26, 20), Rect2(52, 64, 40, 20)]:
		b.draw_rect(Rect2(r.position + rm.position, rm.size), _a(hall, 0.25))
		b.draw_rect(Rect2(r.position + rm.position, rm.size), hall, false, 1.0)
	_tx(b, String(P["t"]), r.position.x + 5.0, 15.0, F, INK, r.size.x - 22.0)
	var xm := r.position + Vector2(66, 74)
	b.draw_line(xm + Vector2(-4, -4), xm + Vector2(4, 4), RED, 2.0)
	b.draw_line(xm + Vector2(4, -4), xm + Vector2(-4, 4), RED, 2.0)
	_disc(b, r.position + Vector2(20, 56), 2, RED)
	b._pin(Vector2(r.end.x - 9.0, 5.0), _pc(i))


## A route chart: worlds as rings, the jumps between them as dashes.
static func _route(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var col := Color("#e4dcc4")
	_paper(b, r, col)
	_tx(b, "ROUTES", r.position.x + 5.0, 13.0, F, INK_SOFT, 60.0)
	_tx(b, String(P["t"]), r.position.x + 5.0, 23.0, F, BLUE, r.size.x - 22.0)
	var pts := [Vector2(14, 44), Vector2(40, 34), Vector2(66, 50), Vector2(92, 36), Vector2(52, 74), Vector2(86, 72), Vector2(20, 72)]
	var links := [[0, 1], [1, 2], [2, 3], [2, 4], [4, 5], [0, 6], [6, 4], [3, 5]]
	for l: Array in links:
		var a: Vector2 = r.position + pts[int(l[0])]
		var e: Vector2 = r.position + pts[int(l[1])]
		var n := int(a.distance_to(e) / 2.0)
		for k in n:
			if k % 2 == 0:
				var p := a.lerp(e, float(k) / float(n))
				b.draw_rect(Rect2(p.round(), Vector2(2, 1)), _a(INK_SOFT, 0.8))
	for k in pts.size():
		var p: Vector2 = r.position + pts[k]
		_ring(b, p, 3, BLUE if k != 5 else RED, col)
	b._wobble_circle(r.position + pts[5], 7.0, RED, float(i))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i))


## A scrap of star chart: navy, the stars joined up, one of them ringed in pen.
static func _stars(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, Color("#e8e4d8"), 0.4, false)
	_tx(b, String(P["t"]), r.position.x + 4.0, 12.0, F, INK, r.size.x - 20.0)
	var ch := Rect2(r.position.x + 3.0, 16.0, r.size.x - 6.0, r.size.y - 17.0)
	b.draw_rect(ch, Color("#24345a"))
	var pts := [Vector2(10, 12), Vector2(24, 20), Vector2(36, 14), Vector2(50, 26), Vector2(44, 44), Vector2(64, 40), Vector2(76, 18), Vector2(20, 50)]
	for k in pts.size() - 2:
		b.draw_line(ch.position + pts[k], ch.position + pts[k + 1], Color("#7a9ad0"), 1.0)
	for k in 24:
		b.draw_rect(Rect2(ch.position.x + float((k * 31 + i) % int(ch.size.x)), ch.position.y + float((k * 17 + 2) % int(ch.size.y)), 1.0, 1.0), Color(1, 1, 1, 0.45))
	for p: Vector2 in pts:
		_star(b, ch.position + p, 1, Color("#f0f0ff"))
	b._wobble_circle(ch.position + pts[6], 6.0, Color("#f0c040"), float(i))
	_hx(b, String(P.get("n", "")), ch.position + Vector2(46, 58), Color("#f0c040"), float(i), ch.size.x - 42.0)
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i))


## An old WANTED, gone yellow, stamped with how it ended.
static func _caught(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var col := Color("#cbbf9e")
	_paper(b, r, col, 0.35)
	_cx(b, "WANTED", r.position.x, 22.0, r.size.x, H, RED)
	var box := Rect2(r.position.x + 22.0, 28.0, r.size.x - 44.0, 36.0)
	b.draw_rect(box, col.darkened(0.12))
	_face(b, box.get_center() + Vector2(0, -4), 9, SKIN[i % SKIN.size()], HAIR[i % HAIR.size()], Color("#6a6a5a"))
	_cx(b, String(P["t"]), r.position.x, 95.0, r.size.x, F, INK)
	_cx(b, String(P["l"]), r.position.x, 106.0, r.size.x, F, INK_SOFT)
	_cx(b, "REWARD 30 CR", r.position.x, 117.0, r.size.x, F, INK_SOFT)
	# the stamp, across the bottom of the picture: the face still shows over it
	var st: String = P["st"]
	var sc: Color = _a(P["sc"], 0.85)
	var sw := _w(st, H) + 12.0
	var sr := Rect2(floorf(r.position.x + (r.size.x - sw) * 0.5), 60.0, sw, 22.0)
	b.draw_rect(sr, sc, false, 2.0)
	_cx(b, st, sr.position.x, sr.position.y + 17.0, sr.size.x, H, sc)
	b._pin(Vector2(r.position.x + floorf(r.size.x * 0.5), 5.0), _pc(i))


## A printed table: a band with its name, rows of two columns, one fold.
static func _table(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var col := WHITE
	var a: Color = P["a"]
	var dog: bool = P.get("dog", false)
	if dog:
		# the bottom right corner folded over
		var f := 14.0
		var pts := [r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y - f), Vector2(r.end.x - f, r.end.y), Vector2(r.position.x, r.end.y)]
		_poly(b, pts, _a(SHADE, 0.4), Vector2(3, 4))
		_poly(b, pts, col)
		_poly(b, [Vector2(r.end.x, r.end.y - f), Vector2(r.end.x - f, r.end.y - f), Vector2(r.end.x - f, r.end.y)], col.darkened(0.2))
	else:
		_paper(b, r, col)
	b.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 20.0), a)
	_cx(b, String(P["t"]), r.position.x, 16.0, r.size.x, F, Color("#f8f4ea"))
	var y := 34.0
	var rows: Array = P.get("rows", [])
	var strike: int = P.get("strike", -1)
	for k in rows.size():
		var row: Array = rows[k]
		_tx(b, String(row[0]), r.position.x + 5.0, y, F, INK, r.size.x - 34.0)
		_rx(b, String(row[1]), r.end.x - 5.0, y, F, a)
		if k == strike:
			b.draw_rect(Rect2(r.position.x + 3.0, y - 3.0, r.size.x - 6.0, 1.0), RED)
		if k < rows.size() - 1:
			b.draw_rect(Rect2(r.position.x + 4.0, y + 3.0, r.size.x - 8.0, 1.0), _a(INK_SOFT, 0.25))
		y += 13.0
	b._pin(Vector2(r.position.x + 5.0, 5.0), _pc(i))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i, 1))


## A pad of stickies pinned up whole: the top one written on, the rest under it.
static func _pad(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var col: Color = P["c"]
	var top := Rect2(2.0, 2.0, sz.x - 10.0, sz.y - 12.0)
	_shadow(b, Rect2(top.position, top.size + Vector2(3, 4)), 0.35)
	for k in [3, 2, 1]:
		b.draw_rect(Rect2(top.position + Vector2(k, k + 1), top.size), col.darkened(0.08 * float(k)))
	b.draw_rect(top, col)
	b.draw_rect(Rect2(top.position.x, top.position.y, top.size.x, 6.0), col.darkened(0.06))
	var lines: Array = P.get("l", [])
	# short words big, longer ones small, each line as tall as its letters
	var y := 12.0
	for k in lines.size():
		var fs := H if String(lines[k]).length() <= 3 else F
		y += (17.0 if fs == H else 9.0) + 3.0
		_hx(b, String(lines[k]), Vector2(top.position.x + 6.0, y), INK, float(i) + float(k), top.size.x - 8.0, fs)
	b._pin(Vector2(top.position.x + floorf(top.size.x * 0.5), 5.0), _pc(i))


## A bit of a box, written on in marker, ragged where it was torn off the box.
static func _sign(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := Rect2(4.0, 3.0, sz.x - 10.0, sz.y - 9.0)
	var pts := []
	var n := 8
	for k in n:
		pts.append(Vector2(r.position.x + r.size.x * float(k) / float(n), r.position.y + float((k * 5 + i) % 3)))
	for k in n:
		pts.append(Vector2(r.end.x - float((k * 3 + i) % 3), r.position.y + r.size.y * float(k) / float(n)))
	for k in n:
		pts.append(Vector2(r.end.x - r.size.x * float(k) / float(n), r.end.y - float((k * 7 + i) % 3)))
	for k in n:
		pts.append(Vector2(r.position.x + float((k * 2 + i) % 3), r.end.y - r.size.y * float(k) / float(n)))
	_poly(b, pts, _a(SHADE, 0.45), Vector2(3, 4))
	_poly(b, pts, KRAFT)
	# the box's ribs, showing through
	for k in 3:
		b.draw_rect(Rect2(r.position.x + 3.0, r.position.y + 30.0 + float(k) * 16.0, r.size.x - 6.0, 1.0), _a(KRAFT.darkened(0.25), 0.5))
	var sd := float(i) * 3.0
	_hx(b, String(P["t"]), Vector2(r.position.x + 8.0, 26.0), INK, sd, r.size.x - 12.0, H)
	_hx(b, String(P["l"]), Vector2(r.position.x + 8.0, 42.0), INK, sd + 5.0, r.size.x - 12.0)
	if String(P.get("pic", "")) == "kittens":
		for k in 3:
			var c := Vector2(r.position.x + 22.0 + float(k) * 26.0, r.end.y - 16.0)
			b._wobble_circle(c, 6.0, INK, sd + float(k))
			b._wobble_line(c + Vector2(-5, -4), c + Vector2(-4, -10), INK, sd + float(k) + 0.3)
			b._wobble_line(c + Vector2(5, -4), c + Vector2(4, -10), INK, sd + float(k) + 0.6)
			b.draw_rect(Rect2(c.x - 3.0, c.y - 1.0, 1.0, 2.0), INK)
			b.draw_rect(Rect2(c.x + 2.0, c.y - 1.0, 1.0, 2.0), INK)
	else:
		# an arrow, pointing the way to it
		b._wobble_line(Vector2(r.position.x + 12.0, r.end.y - 12.0), Vector2(r.end.x - 16.0, r.end.y - 12.0), RED, sd)
		b._wobble_line(Vector2(r.end.x - 16.0, r.end.y - 12.0), Vector2(r.end.x - 24.0, r.end.y - 18.0), RED, sd + 1.0)
		b._wobble_line(Vector2(r.end.x - 16.0, r.end.y - 12.0), Vector2(r.end.x - 24.0, r.end.y - 6.0), RED, sd + 2.0)
	b._pin(Vector2(r.position.x + 5.0, 7.0), _pc(i))
	b._pin(Vector2(r.end.x - 8.0, 7.0), _pc(i, 1))


## An envelope pinned up for somebody: the flap, the stamp, the name.
static func _envelope(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var col: Color = P["c"]
	_paper(b, r, col)
	var tip := Vector2(r.position.x + floorf(r.size.x * 0.5), r.position.y + 22.0)
	b.draw_line(r.position + Vector2(1, 1), tip, col.darkened(0.3), 1.0)
	b.draw_line(Vector2(r.end.x - 1.0, r.position.y + 1.0), tip, col.darkened(0.3), 1.0)
	var st := Rect2(r.end.x - 17.0, r.position.y + 4.0, 12.0, 14.0)
	b.draw_rect(st, Color("#4a8a5a"))
	b.draw_rect(st, Color("#f0ece0"), false, 1.0)
	_disc(b, st.get_center(), 2, Color("#f0e0a0"))
	_hx(b, String(P["t"]), Vector2(r.position.x + 12.0, 44.0), BLUE, float(i), r.size.x - 16.0)
	_cx(b, String(P.get("l", "")), r.position.x, r.end.y - 5.0, r.size.x, F, RED)
	b._pin(tip + Vector2(0, -2), _pc(i))


## A stamp card for a stall, most of it punched out: the cork shows through.
static func _punch(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var col: Color = P["c"]
	_paper(b, r, col)
	_tx(b, String(P["t"]), r.position.x + 5.0, 14.0, F, INK, r.size.x - 22.0)
	var punched: int = P.get("n", 5)
	for k in 10:
		var c := Vector2(r.position.x + 10.0 + float(k % 5) * 15.0, 27.0 + floorf(float(k) / 5.0) * 13.0)
		if k < punched:
			_disc(b, c, 3, CORK)
		else:
			_ring(b, c, 4, INK_SOFT, col)
	_tx(b, "10TH FREE", r.end.x - 4.0 - _w("10TH FREE", F), r.end.y - 4.0, F, RED, 80.0)
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i))


## A bingo flyer, its card half daubed.
static func _bingo(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var col: Color = P["c"]
	_paper(b, r, col)
	_cx(b, String(P["t"]), r.position.x, 22.0, r.size.x, H, RED)
	var cw := 15.0
	var x0 := r.position.x + floorf((r.size.x - cw * 5.0) * 0.5)
	var y0 := 28.0
	for row in 5:
		for c in 5:
			var cell := Rect2(x0 + float(c) * cw, y0 + float(row) * 11.0, cw, 11.0)
			b.draw_rect(cell, WHITE)
			b.draw_rect(cell, INK_SOFT, false, 1.0)
			var num := c * 15 + 1 + (row * 7 + c * 3 + i) % 15
			if (row * 3 + c * 2 + i) % 4 == 0:
				_disc(b, cell.get_center(), 4, _a(Color("#3a8ad8"), 0.6))
			if row == 2 and c == 2:
				_star(b, cell.get_center(), 3, RED)
			else:
				_cx(b, str(num), cell.position.x, cell.position.y + 9.0, cw, F, INK)
	var y := y0 + 55.0 + 13.0
	for line in P.get("l", []):
		_cx(b, String(line), r.position.x + 2.0, y, r.size.x - 4.0, F, INK)
		y += 11.0
	b._pin(Vector2(r.position.x + 5.0, 5.0), _pc(i))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i, 1))


## What is left of a notice somebody tore down: a corner, under its pin.
static func _scrap(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var col: Color = P["c"]
	var w := sz.x - 6.0
	var h := sz.y - 6.0
	var pts := []
	if int(P.get("shape", 0)) == 0:
		pts = [Vector2(2, 2), Vector2(2 + w, 2), Vector2(2 + w * 0.7, 2 + h * 0.4), Vector2(2 + w * 0.45, 2 + h * 0.55), Vector2(2 + w * 0.2, 2 + h), Vector2(2, 2 + h * 0.8)]
	else:
		pts = [Vector2(2, 2), Vector2(2 + w, 2), Vector2(2 + w, 2 + h * 0.5), Vector2(2 + w * 0.8, 2 + h * 0.7), Vector2(2 + w * 0.55, 2 + h * 0.55), Vector2(2 + w * 0.3, 2 + h), Vector2(2, 2 + h * 0.75)]
	_poly(b, pts, _a(SHADE, 0.4), Vector2(3, 4))
	_poly(b, pts, col)
	if int(P.get("shape", 0)) == 1:
		_tx(b, "...ENT", 18.0, 16.0, F, INK_SOFT, 40.0)
	b._pin(Vector2(10.0, 7.0), _pc(i))


## A clipping out of the station's sheet: a headline, a photo, small print.
static func _clip(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := Rect2(2.0, 2.0, sz.x - 6.0, sz.y - 9.0)
	_shadow(b, r)
	b.draw_rect(r, NEWS)
	_ragged_bottom(b, r.position.x, r.end.y, r.size.x, NEWS, i)
	var lines: Array = P.get("l", [])
	for k in lines.size():
		_tx(b, String(lines[k]), r.position.x + 5.0, 12.0 + float(k) * 10.0, F, INK, r.size.x - 10.0)
	b.draw_rect(Rect2(r.position.x + 4.0, 26.0, r.size.x - 8.0, 1.0), INK)
	var ph := Rect2(r.position.x + 5.0, 31.0, 50.0, 38.0)
	b.draw_rect(ph, Color("#7a7a74"))
	var c := ph.get_center()
	match String(P.get("pic", "")):
		"ice":
			_poly(b, [c + Vector2(-16, 12), c + Vector2(-6, -10), c + Vector2(2, -2), c + Vector2(8, -12), c + Vector2(18, 12)], Color("#d8e0e4"))
			_person(b, c + Vector2(-14, 14), INK, SKIN[0], 12.0)
		"hb":
			b.draw_rect(Rect2(ph.position.x, ph.position.y, ph.size.x, ph.size.y), Color("#3a3a3a"))
			b.draw_rect(Rect2(c.x - 20.0, c.y - 4.0, 36.0, 9.0), INK)
			for s in 4:
				b.draw_rect(Rect2(c.x + 16.0 + float(s) * 2.0, c.y - 3.0 + float(s), 2.0, 7.0 - float(s) * 2.0), INK)
			b.draw_rect(Rect2(c.x - 8.0, c.y - 9.0, 10.0, 5.0), INK)
			for d in 3:
				b.draw_rect(Rect2(c.x - 14.0 + float(d) * 9.0, c.y, 3.0, 2.0), EMBER)
		"cat":
			b.draw_rect(Rect2(c.x - 18.0, c.y + 8.0, 36.0, 3.0), Color("#5a5a54"))
			_critter(b, "cat", c + Vector2(0, 0), Color("#c8c4bc"))
			b.draw_rect(Rect2(c.x + 4.0, c.y - 18.0, 10.0, 3.0), Color("#e8c040"))
	b.draw_rect(ph, INK, false, 1.0)
	_greek(b, ph.end.x + 4.0, 33.0, r.end.x - ph.end.x - 9.0, 6, 6.0, _a(INK, 0.45), i)
	_greek(b, r.position.x + 5.0, 75.0, r.size.x - 10.0, 4, 6.0, _a(INK, 0.45), i + 3)
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i))


## A sign-up sheet: numbered lines, a few names in a few hands, the rest bare.
static func _signup(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, WHITE)
	_cx(b, String(P["t"]), r.position.x, 14.0, r.size.x, F, INK)
	_cx(b, "SIGN UP", r.position.x, 24.0, r.size.x, F, RED)
	var names: Array = P.get("names", [])
	var pens := [BLUE, INK, RED, GREEN]
	for k in names.size():
		var y := 38.0 + float(k) * 13.0
		_tx(b, str(k + 1), r.position.x + 5.0, y, F, INK_SOFT, 10.0)
		b.draw_rect(Rect2(r.position.x + 14.0, y + 2.0, r.size.x - 20.0, 1.0), _a(INK_SOFT, 0.5))
		if String(names[k]) != "":
			_hx(b, String(names[k]), Vector2(r.position.x + 18.0, y), pens[(k + i) % pens.size()], float(i * 3 + k), r.size.x - 24.0)
	b._pin(Vector2(r.position.x + 5.0, 5.0), _pc(i))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i, 1))


## A certificate, framed in a printed border, a seal on it, a name in pen.
static func _cert(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, Color("#efe6cc"))
	b.draw_rect(r.grow(-3.0), GOLD, false, 1.0)
	b.draw_rect(r.grow(-5.0), _a(GOLD, 0.6), false, 1.0)
	_cx(b, "CERTIFICATE", r.position.x, 18.0, r.size.x, F, INK_SOFT)
	_cx(b, String(P["t"]), r.position.x, 32.0, r.size.x, F, INK)
	var n: String = P["n"]
	_hx(b, n, Vector2(r.position.x + floorf((r.size.x - _hw(n)) * 0.5), 50.0), BLUE, float(i), r.size.x - 12.0)
	b.draw_rect(Rect2(r.position.x + 20.0, 53.0, r.size.x - 40.0, 1.0), _a(INK_SOFT, 0.6))
	_squiggle(b, r.position.x + 12.0, r.end.y - 13.0, 34.0, INK, i)
	b.draw_rect(Rect2(r.position.x + 10.0, r.end.y - 9.0, 40.0, 1.0), _a(INK_SOFT, 0.6))
	var sc := Vector2(r.end.x - 22.0, r.end.y - 18.0)
	_poly(b, [sc + Vector2(-5, 4), sc + Vector2(-1, 4), sc + Vector2(-6, 15), sc + Vector2(-8, 12)], Color("#c8483a"))
	_poly(b, [sc + Vector2(1, 4), sc + Vector2(5, 4), sc + Vector2(8, 12), sc + Vector2(6, 15)], Color("#c8483a"))
	_disc(b, sc, 8, GOLD)
	_disc(b, sc, 6, Color("#e0b850"))
	_star(b, sc, 2, GOLD.darkened(0.2))
	_tape(b, Rect2(0.0, 1.0, 16.0, 7.0))
	_tape(b, Rect2(sz.x - 20.0, 1.0, 16.0, 7.0))


## A crew pass, out of date: photo, name, the code, EXPIRED across it.
static func _badge(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, Color("#e8ecee"))
	b.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 22.0), Color("#3a6a9a"))
	b.draw_rect(Rect2(r.position.x + floorf(r.size.x * 0.5) - 8.0, r.position.y + 3.0, 16.0, 3.0), CORK)
	_cx(b, "CREW PASS", r.position.x, 20.0, r.size.x, F, Color("#f0f4f8"))
	var ph := Rect2(r.position.x + 5.0, 27.0, 28.0, 32.0)
	b.draw_rect(ph, Color("#a8b8c4"))
	_face(b, ph.get_center() + Vector2(0, -2), 7, SKIN[(i + 1) % SKIN.size()], HAIR[(i + 2) % HAIR.size()], Color("#3a6a9a"))
	b.draw_rect(Rect2(ph.position.x, ph.end.y, ph.size.x, 1.0), Color("#a8b8c4"))
	_tx(b, String(P["t"]), r.position.x + 5.0, 70.0, F, INK, r.size.x - 8.0)
	_tx(b, String(P.get("l", "")), r.position.x + 5.0, 80.0, F, INK_SOFT, r.size.x - 8.0)
	_barcode(b, ph.end.x + 4.0, 30.0, r.end.x - ph.end.x - 8.0, 14.0, i)
	var sr := Rect2(r.position.x + 4.0, 86.0, r.size.x - 8.0, 13.0)
	b.draw_rect(sr, _a(RED, 0.85), false, 1.0)
	_cx(b, "EXPIRED", sr.position.x, sr.position.y + 10.0, sr.size.x, F, _a(RED, 0.9))
	b._pin(Vector2(r.position.x + floorf(r.size.x * 0.5), 5.0), _pc(i))


## A shipping label peeled off a crate: the warning, its picture, the code.
static func _label(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var a: Color = P["a"]
	_paper(b, r, WHITE)
	b.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 22.0), a)
	_cx(b, String(P["t"]), r.position.x, 20.0, r.size.x, H, INK)
	_icon(b, String(P["icon"]), Vector2(r.position.x + 16.0, 42.0), INK if String(P["icon"]) == "glass" else Color("#d8402a"))
	# arrows: this way up
	for k in 2:
		var ax := r.position.x + 40.0 + float(k) * 14.0
		_poly(b, [Vector2(ax, 32.0), Vector2(ax + 5.0, 38.0), Vector2(ax - 5.0, 38.0)], INK)
		b.draw_rect(Rect2(ax - 1.0, 38.0, 3.0, 9.0), INK)
	_tx(b, String(P.get("l", "")), r.position.x + 30.0, 58.0, F, INK, r.size.x - 34.0)
	_barcode(b, r.position.x + 30.0, 62.0, r.size.x - 36.0, 8.0, i)
	_staple(b, Vector2(r.position.x + 3.0, 5.0))
	_staple(b, Vector2(r.end.x - 12.0, 5.0))


## A chart somebody drew to make a point, on squared paper.
static func _graph(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var col := Color("#e6ece2")
	_paper(b, r, col)
	var gx := r.position.x + 2.0
	while gx < r.end.x:
		b.draw_rect(Rect2(gx, r.position.y, 1.0, r.size.y), _a(Color("#5a9aba"), 0.18))
		gx += 6.0
	var gy := r.position.y + 2.0
	while gy < r.end.y:
		b.draw_rect(Rect2(r.position.x, gy, r.size.x, 1.0), _a(Color("#5a9aba"), 0.18))
		gy += 6.0
	_cx(b, String(P["t"]), r.position.x, 15.0, r.size.x, F, INK)
	var ax := Rect2(r.position.x + 10.0, 30.0, r.size.x - 18.0, r.end.y - 40.0)
	b.draw_rect(Rect2(ax.position.x, ax.position.y, 1.0, ax.size.y), INK)
	b.draw_rect(Rect2(ax.position.x, ax.end.y, ax.size.x, 1.0), INK)
	var bars: Array = P.get("bars", [])
	var bw := floorf(ax.size.x / float(bars.size()))
	for k in bars.size():
		var bh := floorf((ax.size.y - 4.0) * float(bars[k]))
		var col2 := Color("#d8783a") if k == bars.size() - 1 else Color("#4a7ab0")
		b.draw_rect(Rect2(ax.position.x + 3.0 + float(k) * bw, ax.end.y - bh, bw - 3.0, bh), col2)
	_hx(b, String(P.get("n", "")), Vector2(ax.position.x + 6.0, ax.position.y + 12.0), RED, float(i), 50.0)
	b._pin(Vector2(r.position.x + 5.0, 5.0), _pc(i))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i, 1))


## An IOU on a torn scrap.
static func _iou(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := Rect2(2.0, 2.0, sz.x - 10.0, sz.y - 6.0)
	var col := Color("#eae4d0")
	_shadow(b, r)
	b.draw_rect(r, col)
	_ragged_right(b, r.end.x, r.position.y, r.size.y, col, i)
	_hx(b, String(P["t"]), Vector2(r.position.x + 12.0, 20.0), INK, float(i), r.size.x - 14.0)
	_hx(b, String(P.get("l", "")), Vector2(r.position.x + 30.0, 34.0), BLUE, float(i) + 4.0, r.size.x - 32.0)
	b._pin(Vector2(r.position.x + 5.0, 6.0), _pc(i))


## A photo booth strip: four goes at the same picture.
static func _strip(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, Color("#f0eee8"), 0.4, false)
	for k in 4:
		var fr := Rect2(r.position.x + 3.0, r.position.y + 10.0 + float(k) * 26.0, r.size.x - 6.0, 23.0)
		b.draw_rect(fr, Color("#4a5a6a"))
		var c := fr.get_center()
		match k:
			0:
				_face(b, c + Vector2(-6, -2), 5, SKIN[0], HAIR[1], Color("#c85a3a"))
				_face(b, c + Vector2(7, -2), 5, SKIN[2], HAIR[2], Color("#3a8ac8"))
			1:
				_face(b, c + Vector2(-6, -4), 5, SKIN[0], HAIR[1], Color("#c85a3a"))
				_face(b, c + Vector2(7, 0), 5, SKIN[2], HAIR[2], Color("#3a8ac8"))
				b.draw_rect(Rect2(c.x + 4.0, c.y + 3.0, 6.0, 2.0), INK)
			2:
				_face(b, c + Vector2(-3, -2), 5, SKIN[0], HAIR[1], Color("#c85a3a"))
				_face(b, c + Vector2(4, -2), 5, SKIN[2], HAIR[2], Color("#3a8ac8"))
			3:
				_face(b, c + Vector2(0, -2), 6, SKIN[2], HAIR[2], Color("#3a8ac8"))
				b.draw_rect(Rect2(fr.position.x, fr.position.y, 4.0, fr.size.y), Color("#c85a3a"))
	b._pin(Vector2(r.position.x + floorf(r.size.x * 0.5), 6.0), _pc(i))


## A memo from the office, as the office writes them.
static func _memo(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, WHITE)
	_tx(b, "MEMO", r.position.x + 5.0, 21.0, H, INK, 70.0)
	b.draw_rect(Rect2(r.position.x + 4.0, 25.0, r.size.x - 8.0, 2.0), INK)
	_tx(b, "TO: ALL CREW", r.position.x + 5.0, 37.0, F, INK_SOFT, r.size.x - 10.0)
	_tx(b, String(P["t"]), r.position.x + 5.0, 48.0, F, INK, r.size.x - 10.0)
	var y := 62.0
	for line in P.get("l", []):
		_tx(b, String(line), r.position.x + 5.0, y, F, INK_SOFT, r.size.x - 10.0)
		y += 10.0
	_squiggle(b, r.end.x - 40.0, r.end.y - 8.0, 30.0, BLUE, i)
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i))


## A petition: what it wants, and every name it got.
static func _petition(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, Color("#e8f0e0"))
	_cx(b, String(P["t"]), r.position.x, 13.0, r.size.x, F, GREEN)
	_cx(b, String(P.get("u", "")), r.position.x, 23.0, r.size.x, F, GREEN)
	var pens := [BLUE, INK, RED, GREEN, Color("#8a4ab0")]
	for k in 7:
		var y := 38.0 + float(k) * 11.0
		b.draw_rect(Rect2(r.position.x + 6.0, y + 2.0, r.size.x - 12.0, 1.0), _a(INK_SOFT, 0.35))
		_squiggle(b, r.position.x + 8.0 + float((k * 7) % 12), y - 2.0, 30.0 + float((k * 11 + i) % 30), pens[(k + i) % pens.size()], i * 3 + k)
	b._pin(Vector2(r.position.x + 5.0, 5.0), _pc(i))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i, 1))


## A found key, on a paper tag, its string looped over the pin.
static func _key(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var tag := Rect2(18.0, 6.0, sz.x - 26.0, 32.0)
	var pts := [Vector2(tag.position.x, tag.position.y + 8.0), Vector2(tag.position.x + 8.0, tag.position.y), tag.position + Vector2(tag.size.x, 0), tag.end, Vector2(tag.position.x + 8.0, tag.end.y), Vector2(tag.position.x, tag.end.y - 8.0)]
	_poly(b, pts, _a(SHADE, 0.4), Vector2(3, 4))
	_poly(b, pts, MANILA)
	var hole := Vector2(tag.position.x + 6.0, tag.position.y + 16.0)
	_ring(b, hole, 3, MANILA.darkened(0.25), CORK)
	b.draw_line(Vector2(8.0, 7.0), hole, Color("#e8e0d0"), 1.0)
	_tx(b, String(P["t"]), tag.position.x + 13.0, 18.0, F, INK, tag.size.x - 16.0)
	_tx(b, String(P.get("l", "")), tag.position.x + 13.0, 30.0, F, RED, tag.size.x - 16.0)
	# the key, hanging from the tag's hole on a ring
	var metal := Color("#c8b878")
	_ring(b, hole + Vector2(0, 8), 3, Color("#a0a0a8"), Color(0, 0, 0, 0))
	var kc := hole + Vector2(2, 20)
	_ring(b, kc, 5, metal, Color(0, 0, 0, 0))
	_ring(b, kc, 4, metal, Color(0, 0, 0, 0))
	b.draw_rect(Rect2(kc.x + 5.0, kc.y - 1.0, 26.0, 3.0), metal)
	for t in [0, 1, 2]:
		b.draw_rect(Rect2(kc.x + 18.0 + float(t) * 4.0, kc.y + 2.0, 2.0, 2.0 + float(t % 2)), metal)
	b.draw_rect(Rect2(kc.x + 5.0, kc.y + 2.0, 26.0, 1.0), _a(SHADE, 0.4))
	b._pin(Vector2(7.0, 6.0), _pc(i))


## A birthday card, opened out: balloons and a cake.
static func _bday(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	var col := Color("#f8e4ec")
	_paper(b, r, col)
	_cx(b, String(P["t"]), r.position.x, 22.0, r.size.x, H, Color("#c83a7a"))
	_cx(b, String(P.get("l", "")), r.position.x, 34.0, r.size.x, F, BLUE)
	var bc := [Color("#e84a4a"), Color("#4a8ae8"), Color("#e8c03a")]
	for k in 3:
		var c := Vector2(r.position.x + 18.0 + float(k) * 11.0, 48.0 + float(k % 2) * 6.0)
		_disc(b, c, 5, bc[k])
		b.draw_rect(Rect2(c.x - 2.0, c.y - 3.0, 2.0, 2.0), Color(1, 1, 1, 0.5))
		b.draw_line(c + Vector2(0, 5), Vector2(r.position.x + 28.0, r.end.y - 10.0), INK_SOFT, 1.0)
	var ck := Vector2(r.end.x - 26.0, r.end.y - 16.0)
	b.draw_rect(Rect2(ck.x - 14.0, ck.y - 6.0, 28.0, 14.0), Color("#a8683a"))
	b.draw_rect(Rect2(ck.x - 14.0, ck.y - 6.0, 28.0, 3.0), Color("#f8f0f0"))
	for k in 3:
		b.draw_rect(Rect2(ck.x - 7.0 + float(k) * 6.0, ck.y - 13.0, 2.0, 7.0), Color("#80c0f0"))
		b.draw_rect(Rect2(ck.x - 7.0 + float(k) * 6.0, ck.y - 16.0, 2.0, 3.0), Color("#f8a030"))
	b._pin(Vector2(r.position.x + 5.0, 5.0), _pc(i))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i, 1))


## A fortune from a biscuit, kept.
static func _fortune(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, Color("#f4f2ec"))
	var lines: Array = P.get("l", [])
	for k in lines.size():
		_cx(b, String(lines[k]), r.position.x + 12.0, 14.0 + float(k) * 11.0, r.size.x - 14.0, F, Color("#c83a3a"))
	b._pin(Vector2(r.position.x + 5.0, 8.0), _pc(i))


## A poster for the deck chief's job: a face, a name, what they will do.
static func _vote(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, WHITE)
	b.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 22.0), Color("#2a5aa8"))
	_cx(b, "VOTE", r.position.x, 20.0, r.size.x, H, Color("#f8f0d0"))
	_disc(b, Vector2(r.position.x + floorf(r.size.x * 0.5), 44.0), 15, Color("#d8e0ec"))
	_face(b, Vector2(r.position.x + floorf(r.size.x * 0.5), 42.0), 8, SKIN[1], HAIR[0], Color("#c83a3a"))
	_cx(b, String(P["t"]), r.position.x, 78.0, r.size.x, H, Color("#c83a3a"))
	var y := 91.0
	for line in P.get("l", []):
		_cx(b, String(line), r.position.x + 2.0, y, r.size.x - 4.0, F, INK if y < 92.0 else INK_SOFT)
		y += 10.0
	b._pin(Vector2(r.position.x + 5.0, 5.0), _pc(i))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i, 1))


## HANG IN THERE, with a drone holding on to a pipe.
static func _hang(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, Color("#202830"), 0.45, false)
	b.draw_rect(r, Color("#f0ece0"), false, 1.0)
	_cx(b, "HANG IN THERE", r.position.x, 17.0, r.size.x, F, Color("#f0ece0"))
	var ph := Rect2(r.position.x + 5.0, 24.0, r.size.x - 10.0, r.size.y - 28.0)
	b.draw_rect(ph, Color("#3a5a7a"))
	b.draw_rect(Rect2(ph.position.x, ph.position.y + 8.0, ph.size.x, 4.0), Color("#8a8a90"))
	var c := Vector2(ph.position.x + floorf(ph.size.x * 0.5), ph.position.y + 34.0)
	b.draw_rect(Rect2(c.x - 9.0, ph.position.y + 12.0, 2.0, 14.0), Color("#c0c8d0"))
	b.draw_rect(Rect2(c.x + 7.0, ph.position.y + 12.0, 2.0, 14.0), Color("#c0c8d0"))
	b.draw_rect(Rect2(c.x - 10.0, ph.position.y + 7.0, 4.0, 3.0), Color("#c0c8d0"))
	b.draw_rect(Rect2(c.x + 6.0, ph.position.y + 7.0, 4.0, 3.0), Color("#c0c8d0"))
	b.draw_rect(Rect2(c.x - 11.0, c.y - 8.0, 22.0, 14.0), Color("#c0c8d0"))
	_disc(b, c + Vector2(0, -1), 4, Color("#404850"))
	_disc(b, c + Vector2(0, -1), 2, EMBER)
	b.draw_rect(Rect2(c.x - 5.0, c.y + 6.0, 2.0, 6.0), Color("#a0a8b0"))
	b.draw_rect(Rect2(c.x + 3.0, c.y + 6.0, 2.0, 8.0), Color("#a0a8b0"))
	b._pin(Vector2(r.position.x + 5.0, 5.0), _pc(i))
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i, 1))


## A crossword cut out of the sheet, a few of it filled in, in pen.
static func _xword(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, NEWS, 0.4, false)
	_tx(b, "CROSSWORD", r.position.x + 5.0, 13.0, F, INK, r.size.x - 20.0)
	# A REAL GRID, its words crossing (Jon: "The crossword doesn't make sense"):
	# HEAT and LOGO across, HULL, TOOL and SKY down. `#` is a black square, a
	# capital a letter somebody has filled in, a small one a square still empty.
	var grid := [
		"HEAT#S",
		"U##O#K",
		"LogO#y",
		"L##l##",
	]
	var cw := 12.0
	var x0 := r.position.x + floorf((r.size.x - cw * 6.0) * 0.5)
	var y0 := 20.0
	for row in grid.size():
		var line: String = grid[row]
		for col in line.length():
			var ch := line.substr(col, 1)
			var cell := Rect2(x0 + float(col) * cw, y0 + float(row) * cw, cw, cw)
			if ch == "#":
				b.draw_rect(cell, INK)
				continue
			b.draw_rect(cell, Color("#f0ece2"))
			b.draw_rect(cell, INK_SOFT, false, 1.0)
			if ch == ch.to_upper():
				_cx(b, ch, cell.position.x + 1.0, cell.position.y + 10.0, cw - 1.0, F, BLUE)
	# the clues, in small print under it
	var cy := y0 + cw * 4.0 + 10.0
	for clue: String in ["1A WARM", "1D SHIP SKIN", "3D UP THERE"]:
		_tx(b, clue, r.position.x + 5.0, cy, F, INK_SOFT, r.size.x - 10.0)
		cy += 10.0
	b._pin(Vector2(r.end.x - 7.0, 5.0), _pc(i))


## A playing card, taped up for luck.
static func _card(b: PostingBoard, P: Dictionary, sz: Vector2, i: int) -> void:
	var r := _r(sz)
	_paper(b, r, Color("#f8f6f0"))
	_tx(b, "A", r.position.x + 4.0, 14.0, F, Color("#c82a2a"), 10.0)
	_tx(b, "A", r.end.x - 9.0, r.end.y - 4.0, F, Color("#c82a2a"), 10.0)
	var c := r.get_center() + Vector2(0, 2)
	_disc(b, c + Vector2(-4, -3), 4, Color("#c82a2a"))
	_disc(b, c + Vector2(4, -3), 4, Color("#c82a2a"))
	_poly(b, [c + Vector2(-8, -2), c + Vector2(8, -2), c + Vector2(0, 9)], Color("#c82a2a"))
	_tape(b, Rect2(floorf(sz.x * 0.5) - 10.0, 0.0, 20.0, 7.0))
