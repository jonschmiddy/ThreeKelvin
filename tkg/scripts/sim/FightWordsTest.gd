extends Node

## THE WORDS ON LOCAL AND IN A FIGHT SAY WHAT THE RULES DO (the tutorial audit,
## Oct 22), headless:
##   godot --headless --fixed-fps 60 --path . -- sheet=FightWordsTest
##
##  - THE STATUS CHIPS NAME THE CARD'S KEYWORD. Negate showed as SLIP and Grows
##    as ADAPT. A real fight on LOCAL, each set on your ship, the chip row
##    rebuilt: each chip's heading is the keyword the card that sets it prints
##    (`CardData.keywords`, read off a real card of the catalogue), and no chip
##    says SLIP or ADAPT.
##  - THE DISCARD SAYS WHAT GOES THERE. It said "What you have played so far".
##    A card played, END TURN with cards left in the hand: the played card and
##    every unplayed one (fused ones stay) are in the discard, and the pile's
##    tooltip names both.
##  - THE BAR'S LINE HAS NO DASH. "NOTHING ELSE HERE - SEE SECTOR" had one, and
##    its three siblings too. Every place in the galaxy, its line
##    (`SectorScreen.here_line`), and the label LOCAL draws.

var _fails := 0
var _tree: SceneTree


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


## Whether `s` holds a dash between words: a spaced hyphen, an en or an em dash.
static func _dashed(s: String) -> bool:
	return s.contains(" - ") or s.contains("–") or s.contains("—")


## A real card of the catalogue that `has` accepts, or null.
static func _card_where(has: Callable) -> CardData:
	for id in DB.modules:
		for c in (DB.modules[id] as ModuleData).resolved_cards():
			if has.call(c):
				return c
	return null


## The keyword a card prints for a rule, by its definition's first words.
static func _keyword(c: CardData, starts: String) -> String:
	if c == null:
		return ""
	for kw: Array in c.keywords():
		if String(kw[1]).begins_with(starts):
			return String(kw[0])
	return ""


## Each chip in the row, by its tooltip's heading (the line before the blank).
static func _chip_heads(row: Control) -> PackedStringArray:
	var out := PackedStringArray()
	for c in row.get_children():
		if c is StatusChip:
			out.append((c as Control).tooltip_text.split("\n")[0])
	return out


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	if _tree.root.size.x < 1000:
		_tree.root.size = Vector2i(1920, 1080)
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM:
			idx = n.index
			break
	Run.at = idx
	SectorScreen._approached_at = idx
	for raw in Run.map:
		(raw as MapGen.MapNode).ambush_rolled = true
		(raw as MapGen.MapNode).ambush_pending = false

	# 3. THE BAR'S LINE, everywhere and on LOCAL
	var dashed: Array[String] = []
	for n: MapGen.MapNode in Run.map:
		var line := SectorScreen.here_line(n)
		if _dashed(line):
			dashed.append(line)
	_ok("no place's bar line holds a dash (%d places, %d with one%s)" % [Run.map.size(), dashed.size(),
		": " + dashed[0] if not dashed.is_empty() else ""], dashed.is_empty())
	Router.show_local()
	await _frames(30)
	var sc := Router.current as SectorScreen
	if not _ok("LOCAL is up", sc != null):
		_end()
		return
	var bar := ""
	for x in sc.find_children("*", "Label", true, false):
		if (x as Label).is_visible_in_tree() and (x as Label).text.contains("SEE SECTOR"):
			bar = (x as Label).text
	if bar == "":
		# (an event's band up instead of the bar: the line above covers it)
		print("  --   LOCAL opened on an event, so its bar line is not drawn")
	else:
		_ok("LOCAL's bar line has no dash (\"%s\")" % bar,
			not _dashed(bar) and bar == SectorScreen.here_line(Run.node_at()))

	# A FIGHT on LOCAL
	Router.start_combat(DB.enemies[&"hulk"], [], false, false)
	await _frames(40)
	sc = Router.current as SectorScreen
	var cb: Combat = Router.combat
	if not _ok("a fight opens on LOCAL", sc != null and sc.fighting() and cb != null):
		_end()
		return

	# 1. THE CHIPS
	var negate := _card_where(func(c: CardData) -> bool: return c.negate_next)
	var grows := _card_where(func(c: CardData) -> bool: return c.adapt > 0)
	var kw_negate := _keyword(negate, "Cancels the next attack")
	var kw_grows := _keyword(grows, "Gains this permanently")
	_ok("a card that negates prints its keyword (%s: \"%s\")" % [negate.name if negate else "none", kw_negate],
		kw_negate != "")
	_ok("a card that grows prints its keyword (%s: \"%s\")" % [grows.name if grows else "none", kw_grows],
		kw_grows != "")
	cb.negate_next = true
	cb.adapt_bonus = 2
	sc._refresh_player()
	var heads := _chip_heads(sc._player_chips)
	_ok("the negate chip is headed with the card's keyword, %s (%s)" % [kw_negate.to_upper(), ", ".join(heads)],
		heads.has(kw_negate.to_upper()))
	_ok("the grows chip is headed with the card's keyword, %s" % kw_grows.to_upper(),
		heads.has(kw_grows.to_upper()))
	_ok("no chip says SLIP or ADAPT", not heads.has("SLIP") and not heads.has("ADAPT"))
	cb.negate_next = false
	cb.adapt_bonus = 0
	sc._refresh_player()

	# 2. THE DISCARD: one card played, END TURN with the rest still in hand
	var played: CardData = null
	for i in cb.hand.size():
		if cb.can_play(cb.hand[i]) and not cb.hand[i].unplayable and not cb.hand[i].self_decommission:
			played = cb.hand[i]
			cb.play(i, 0)
			break
	await _frames(10)
	var left: Array[CardData] = []
	for c in cb.hand:
		if not c.fused:
			left.append(c)
	_ok("a card was played and %d stay in the hand unplayed" % left.size(), played != null and not left.is_empty())
	if not cb.finished:
		cb.end_turn()
	await _frames(10)
	var all_in := cb.discard.has(played)
	for c in left:
		all_in = all_in and cb.discard.has(c)
	_ok("after END TURN the discard holds the played card and every unplayed one (%d in it)" % cb.discard.size(),
		all_in)
	var tip := sc._discard_pile.tooltip_text
	_ok("the discard's tooltip is the one that says so (%s)" % tip.c_escape(),
		tip == Widgets.tip(SectorScreen.DISCARD_TIP) and SectorScreen.DISCARD_TIP.contains("played")
		and SectorScreen.DISCARD_TIP.contains("rest of your hand at END TURN")
		and not tip.contains("What you have played so far"))
	# 4. LOCK-ON STACKS (Jon, Oct 23). Two sight cards add up, and the next
	# attack spends the lot.
	var sight := _card_where(func(c: CardData) -> bool: return c.lock_on > 0 and c.damage <= 0)
	if _ok("a lock-on card exists (%s)" % (sight.name if sight else "none"), sight != null):
		cb.lock_on = 0
		CardResolver.resolve(sight, cb, false)
		CardResolver.resolve(sight, cb, false)
		_ok("two %s add up to lock-on +%d" % [sight.name, cb.lock_on], cb.lock_on == sight.lock_on * 2)
		var gun := _card_where(func(c: CardData) -> bool: return c.damage > 0 and not c.damage_equals_heat)
		if gun != null and not cb.alive().is_empty():
			CardResolver.resolve(gun, cb, false)
			_ok("the next attack spends it all (lock-on %d after %s)" % [cb.lock_on, gun.name], cb.lock_on == 0)
	Run.hp = Run.max_hp()
	_end()


func _end() -> void:
	print("fightwordstest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
