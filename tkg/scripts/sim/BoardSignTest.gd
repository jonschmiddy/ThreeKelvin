extends Node

## SIGN CHANGES ONE NOTE, headless:
##   godot --headless --path . -- sheet=BoardSignTest
## Jon, Oct 22: "When you pick a quest from the hiring board... the whole hiring
## board resets." SIGN took the job down and put it on the SIGNED, ELSEWHERE
## card at the front, rebuilding every note: each note slid along a slot, and
## the board, laid out round its notes, laid itself out again -- the cork's and
## the whiteboard's scatter (the WANTED poster, the manufacturers' notices,
## every piece of paper) jumped to new places, and the screen's other people's
## listings moved along their slots with new stamps and prices.
##
## On the outpost's cork, the settlement's whiteboard and the city's screen
## (one tab picked, a popup open), through the station screen and its deck
## button, with a DELIVER sticky and the SIGNED, ELSEWHERE card up: SIGN
## clicked as a player clicks it signs that job, its note stays in its place
## and size stamped SIGNED with no SIGN on it, and nothing else changes -- every
## other note the same node in the same place, the tab, the board's scatter or
## its listings, the ticker, the popup, the lamp's power-on, the offers
## themselves (never rolled again). Then a refresh from elsewhere (credits
## moving) changes nothing either. And a heat job signed with the heat already
## on the hull is paid off its own note, in place, which then reads SIGN again.

var _fails := 0
var _tree: SceneTree


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_tree = get_tree()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _run() -> void:
	await _tree.process_frame
	_no_bounty()
	for dev: int in [MapGen.Development.OUTPOST, MapGen.Development.SETTLEMENT, MapGen.Development.CITY]:
		await _board(dev, false)
	await _board(MapGen.Development.OUTPOST, true)
	print("boardsigntest: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	_tree.quit(1 if _fails > 0 else 0)


## NO BOARD PROMISES A BOUNTY FOR THE HELLBENDER (Jon, Oct 22: the bounty was
## promised and never paid, so the posters just say WANTED). Every piece of
## paper, ad, popup and ticker line that names the Hellbender, on every kind of
## board, says nothing of a bounty, a reward, a sum or a claim. The two posters
## drawn in code, the WANTED sheet and the screen's FEATURED listing, say
## WANTED and nothing of the sort, and are stamped DESTROYED after the kill,
## never CLAIMED: CLAIMED says somebody was paid.
const PROMISE := "BOUNTY|REWARD|WORTH|CLAIM|PAID|PAYS|\\d+ ?CR\\b|CREDITS"


func _no_bounty() -> void:
	var promise := RegEx.create_from_string(PROMISE)
	var tables := {"BoardScreen.ADS": BoardScreen.ADS, "BoardScreen.STRIPS": BoardScreen.STRIPS,
		"BoardScreen.POPUPS": BoardScreen.POPUPS, "BoardScreen.TICKER": BoardScreen.TICKER,
		"BoardScreen.DECOYS": BoardScreen.DECOYS, "BoardWhite.MORE": BoardWhite.MORE,
		"BoardCork.POOL": BoardCork.POOL, "PostingBoard.POSTS": PostingBoard.POSTS}
	var named := 0
	var bad: Array[String] = []
	for t: String in tables:
		var rows: Array = tables[t].values() if tables[t] is Dictionary else tables[t]
		for row: Variant in rows:
			var words := " / ".join(_words(row)).to_upper()
			if not words.contains("HELLBENDER"):
				continue
			named += 1
			if promise.search(words) != null:
				bad.append("%s: %s" % [t, words])
	_ok("the boards' own paper names the Hellbender (%d pieces)" % named, named > 0)
	_ok("none of it promises a bounty for it (%s)" % ("; ".join(bad) if not bad.is_empty() else "none"), bad.is_empty())
	var src: String = (load("res://scripts/ui/PostingBoard.gd") as GDScript).source_code
	for f: String in ["_wanted", "_featured"]:
		var body := _body(src, f)
		var said: Array[String] = []
		for m in RegEx.create_from_string("\"([^\"]*)\"").search_all(body):
			if not m.get_string(1).begins_with("#"):
				said.append(m.get_string(1))
		var promised := said.filter(func(s: String) -> bool: return promise.search(s.to_upper()) != null)
		_ok("PostingBoard.%s says WANTED and no bounty (%s)" % [f, ", ".join(said)],
			not body.is_empty() and said.has("WANTED") and promised.is_empty())
		_ok("PostingBoard.%s is stamped %s after the kill" % [f, PostingBoard.DEAD_STAMP],
			body.contains("_stamp(DEAD_STAMP"))
	_ok("the stamp is DESTROYED, not CLAIMED", PostingBoard.DEAD_STAMP == "DESTROYED")


## Every string in a board's table row, however deep, but its "k": that names
## which drawing paints it (the whiteboard's Hellbender note is drawn by
## `_p_bounty`) and is never written on the board.
func _words(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is String or v is StringName:
		out.append(String(v))
	elif v is Array:
		for x: Variant in v:
			out.append_array(_words(x))
	elif v is Dictionary:
		for k: Variant in v:
			if String(k) != "k":
				out.append_array(_words(v[k]))
	return out


## A function's body in a script's source: from its `func` line to the next.
func _body(src: String, f: String) -> String:
	var a := src.find("\nfunc %s(" % f)
	if a < 0:
		return ""
	var b := src.find("\nfunc ", a + 1)
	return src.substr(a, (b if b >= 0 else src.length()) - a)


## The station you are at, set up as `-- stationshot` sets it: two
## manufacturers posting (two offers), a delivery waiting here and a job open
## elsewhere, so the board carries a DELIVER sticky and the SIGNED, ELSEWHERE
## card in front of the offers. `heat`: the first offer a heat job, the heat on
## the hull.
func _station(dev: int, heat: bool) -> MapGen.MapNode:
	for s in 40:
		Rng.forced = 9100 + s
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var here: MapGen.MapNode = Run.node_at()
		here.type = MapGen.NodeType.STATION
		here.development = dev
		here.security = 4
		here.danger = 5
		here.manufacturer = &"korvan"
		here.berths.clear()
		here.berths.append(&"korvan")
		here.berths.append(&"probate")
		var offers := Contracts.board(here)
		if offers.size() < 2:
			continue
		if heat and int((offers[0] as ContractData).kind) != ContractData.Kind.HEAT:
			continue
		if not heat:
			# a job somewhere else, open (the SIGNED, ELSEWHERE card), and one
			# done and payable here (a DELIVER sticky)
			var far := ContractData.new()
			far.manufacturer = &"probate"
			far.kind = ContractData.Kind.FETCH
			far.at = 1
			far.posted_at = 2
			far.pay = 40
			Run.take_contract(far)
			var done := Run.take_contract(far)
			done.posted_at = 3
			done.manufacturer = &"korvan"
			done.state = ContractData.State.READY
		else:
			Run.heat = (offers[0] as ContractData).amount + 1
		Router.park_at_station(here)
		return here
	return null


## What the board shows, to be set against itself after SIGN.
func _look(st: StationScreen) -> Dictionary:
	var notes: Array = []
	for c in st._work.get_children():
		var k := c as Control
		notes.append({id = k.get_instance_id(), rect = k.get_global_rect(), say = String(k.get_meta(&"note", ""))})
	var bd := st._board
	return {
		notes = notes,
		tab = bd.tab,
		counts = str(bd.tab_counts),
		deck = st._tab,
		laid = str(bd._lay_out(bd.size.x, bd.size.y)) if not bd.screen() else "",
		slots = str(bd._free_slots(bd.size.y)) if bd.screen() else "",
		jobs = str(bd.job_rects()),
		ticker = bd._ticker_text(),
		pop = [bd._pop_at, bd._pops],
		boot = st._board_lamp._boot_at,
		lit = st._board_lamp.lit(),
	}


func _offers_wire(n: MapGen.MapNode) -> String:
	var out: Array = []
	for c in Contracts.board(n):
		out.append((c as ContractData).to_wire())
	return str(out)


func _find_button(n: Node, text: String) -> Button:
	var b := n as Button
	if b != null and b.text == text and b.is_visible_in_tree():
		return b
	for c in n.get_children():
		var got := _find_button(c, text)
		if got != null:
			return got
	return null


func _find_label(n: Node, text: String) -> bool:
	if n is Label and (n as Label).text == text:
		return true
	for c in n.get_children():
		if _find_label(c, text):
			return true
	return false


func _has_stamp(n: Node) -> bool:
	if n is StationScreen._SignedStamp:
		return true
	for c in n.get_children():
		if _has_stamp(c):
			return true
	return false


## A click on `b` as a player makes one: down and up on its middle.
func _click(b: Control) -> void:
	var at := b.get_global_rect().get_center()
	var target := GameShell.input_target(_tree)
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	target.push_input(mv)
	await _tree.process_frame
	# HEADLESS THE WINDOW NEVER HAS THE POINTER IN IT, so no control is ever
	# hovered, and a button takes a press only while it is (BaseButton). The
	# press and the release still go through the viewport, to whatever is on
	# top at that point, so what covers the button takes the click instead.
	b.notification(Control.NOTIFICATION_MOUSE_ENTER)
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		mb.position = at
		mb.global_position = at
		target.push_input(mb)
		await _tree.process_frame


func _board(dev: int, heat: bool) -> void:
	var tag := String(MapGen.Development.keys()[dev]).to_lower() + (" heat" if heat else "")
	var n := _station(dev, heat)
	if not _ok("%s: a station posting two offers%s" % [tag, ", the first a heat job" if heat else ""], n != null):
		return
	Router.show_station()
	await _frames(30)
	var st := Router.current as StationScreen
	if not _ok("%s: the station is up, its Hiring Board on" % tag, st != null and st._tabs.has(&"work")):
		return
	(st._tabs[&"work"] as Button).pressed.emit()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000 and not st.deck_subject(&"work").has_area():
		await _tree.process_frame
	await _frames(4)
	if not _ok("%s: the board is open and lit" % tag, st.deck_subject(&"work").has_area()):
		return
	var bd := st._board
	_ok("%s: the board is %s" % [tag, ["a cork board", "a cork board", "a whiteboard", "a screen", "a screen"][dev]],
		bd.screen() == (dev >= MapGen.Development.CITY))
	var target_kind := int((Contracts.board(n)[0] as ContractData).kind)
	if bd.screen():
		# ONE TAB PICKED, as a player picks it, and a popup up
		var i := PostingBoard.TAB_KINDS.find(target_kind)
		var at := bd.get_global_transform() * bd._tab_rects[i].get_center()
		var target := GameShell.input_target(_tree)
		for pressed in [true, false]:
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			mb.pressed = pressed
			mb.position = at
			mb.global_position = at
			target.push_input(mb)
			await _tree.process_frame
		bd._pop_next = PostingBoard._t()
		await _frames(6)
		_ok("%s: the %s tab picked (tab %d) and a popup up" % [tag, PostingBoard.TABS[i], bd.tab], bd.tab == i and bd._pop_at >= 0.0)

	var before := _look(st)
	var offers0 := _offers_wire(n)
	# what each note is, read off the note (not off how the screen keys it, so
	# this reads the same on any version of the board)
	var says: Array[String] = []
	for c in st._work.get_children():
		if _find_button(c, "SIGN") != null:
			says.append("offer")
		elif _find_button(c, "DELIVER") != null:
			says.append("deliver")
		elif _find_label(c, "SIGNED, ELSEWHERE"):
			says.append("mine")
		else:
			says.append("other")
	print("    notes before: %s" % ", ".join(says))
	if not heat:
		_ok("%s: the DELIVER sticky and the SIGNED, ELSEWHERE card are up in front of the offers" % tag,
			says.size() >= 3 and says[0] == "deliver" and says[1] == "mine" and says[2] == "offer")
	# the first offer's note on the board
	var at_i := says.find("offer")
	if not _ok("%s: an offer's note is on the board" % tag, at_i >= 0):
		return
	var note := st._work.get_child(at_i) as Control
	var sign := _find_button(note, "SIGN")
	if not _ok("%s: it carries SIGN" % tag, sign != null):
		return
	var job: ContractData = Contracts.board(n)[0]
	var held0 := Run.contracts.size()
	await _click(sign)
	await _frames(10)
	var after := _look(st)
	_ok("%s: SIGN signed it (%d jobs in the ledger, %d before)" % [tag, Run.contracts.size(), held0],
		Run.contracts.size() == held0 + 1 and Run.holds_contract(job))
	_ok("%s: the offers are the same offers, not rolled again" % tag, _offers_wire(n) == offers0)
	_ok("%s: the same number of notes (%d, %d before)" % [tag, after.notes.size(), before.notes.size()],
		after.notes.size() == before.notes.size())
	if after.notes.size() == before.notes.size():
		var moved: Array[String] = []
		for i in before.notes.size():
			var b: Dictionary = before.notes[i]
			var a: Dictionary = after.notes[i]
			if i == at_i:
				continue
			if a.id != b.id or a.rect != b.rect:
				moved.append("%d %s: %s -> %s%s" % [i, b.say.get_slice("|", 0), b.rect, a.rect, "" if a.id == b.id else " (made again)"])
		_ok("%s: every other note is the same note in the same place (%s)" % [tag, "; ".join(moved) if not moved.is_empty() else "all"],
			moved.is_empty())
		var sb: Dictionary = before.notes[at_i]
		var sa: Dictionary = after.notes[at_i]
		_ok("%s: the signed note keeps its place and size (%s, %s before)" % [tag, sa.rect, sb.rect], sa.rect == sb.rect)
		var now := st._work.get_child(at_i)
		if heat:
			var pay := _find_button(now, "OFFLOAD %d HEAT" % job.amount)
			_ok("%s: it reads OFFLOAD, payable here at once, and no SIGN (%s)" % [tag, sa.say],
				pay != null and _find_button(now, "SIGN") == null and sa.say.contains("|pay|"))
			if pay != null:
				var cash := Run.credits
				await _click(pay)
				await _frames(10)
				var paid := _look(st)
				_ok("%s: OFFLOAD paid it (credits %d -> %d)" % [tag, cash, Run.credits], Run.credits > cash and not Run.holds_contract(job))
				var still := true
				for i in before.notes.size():
					if i != at_i and (paid.notes[i].id != before.notes[i].id or paid.notes[i].rect != before.notes[i].rect):
						still = false
				_ok("%s: paid, the note is back to SIGN in its place, the rest unmoved" % tag,
					_find_button(st._work.get_child(at_i), "SIGN") != null and paid.notes[at_i].rect == sb.rect and still
					and paid.laid == before.laid)
		else:
			_ok("%s: it is stamped SIGNED, with no SIGN on it (%s)" % [tag, sa.say],
				_find_button(now, "SIGN") == null and _has_stamp(now) and sa.say.contains("|signed|"))
	for k: String in ["tab", "counts", "deck", "laid", "slots", "jobs", "ticker", "pop", "boot", "lit"]:
		_ok("%s: the board's %s is unchanged%s" % [tag, k, "" if str(after[k]) == str(before[k]) else " (%s -> %s)" % [str(before[k]).left(160), str(after[k]).left(160)]],
			str(after[k]) == str(before[k]))
	if heat:
		return
	# A REFRESH FROM ELSEWHERE (credits moving fires it) changes nothing either
	Run.credits += 5
	Sig.resources_changed.emit()
	await _frames(6)
	var later := _look(st)
	var same: bool = later.notes.size() == after.notes.size()
	if same:
		for i in after.notes.size():
			if later.notes[i].id != after.notes[i].id or later.notes[i].rect != after.notes[i].rect:
				same = false
	_ok("%s: a refresh after (credits moving) makes no note again and moves nothing" % tag,
		same and later.laid == after.laid and later.slots == after.slots)
