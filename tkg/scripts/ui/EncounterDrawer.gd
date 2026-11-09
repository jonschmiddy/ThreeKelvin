class_name EncounterDrawer

## Lifted out of `SectorScreen`: static builders, with screen calls passed in as `Callable`s.
## Why: docs/why/EncounterDrawer.md#drawer-split


## Buttons are one size everywhere, so they do not change height with the kind of place.
## Why: docs/why/EncounterDrawer.md#button-sizing
const BTN := Vector2(94, 20)

## LOCAL's way out to the sector map (Jon); the jump itself is plotted from the map.
const TO_SECTOR := "SCAN SECTOR"

## A plate, not a ledger row: encounters are things you do, so they should read as choices.
## Why: docs/why/EncounterDrawer.md#option-cards
class OptionCard extends PanelContainer:
	var press: Callable
	## The left edge stripe: what kind of thing this is, or what stands in the
	## way of it. See `tag_colour` and `choice_card`.
	var edge: Color = UITheme.LINE
	## A choice you cannot afford still says what it wants -- RULING 8 -- so it
	## is drawn and dimmed rather than hidden, and does not answer a click.
	var live: bool = true
	## The other cards this one would cost you. See `option_row`.
	var kin: Array = []
	## Still takeable, as hovering commits nothing: this only warns what the other card costs.
	var doomed: bool = false
	## Faded when doomed or spent: everything the card SAYS about its option.
	var flesh: Control = null
	## The word across the middle. One label, because a card is never both
	## warned-about and finished: a spent option is out of every group it was in.
	var stamp: Label = null
	## Fade the scrim holder, not just the label, or a grouped card sat permanently dimmed.
	## Why: docs/why/EncounterDrawer.md#option-cards
	var over: Control = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL

	func bar(on: bool) -> void:
		live = on
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on \
			else Control.CURSOR_ARROW
		dress(false)

	## Uniform frame, tag as left stripe: tag-coloured borders made the brightest look chosen.
	## Why: docs/why/EncounterDrawer.md#option-cards
	func dress(hot: bool) -> void:
		if not live or doomed:
			add_theme_stylebox_override("panel", UITheme.flat(
				UITheme.PANEL, UITheme.LINE.darkened(0.3), 0, 0, 0))
			return
		add_theme_stylebox_override("panel", UITheme.flat(
			UITheme.PANEL2.lightened(0.06) if hot else UITheme.PANEL2,
			UITheme.COLD if hot else UITheme.LINE, 0, 0, 0))

	## Ruling 1: an exclusive set is a hover gesture, not a labelled box; cards keep one shape.
	## Why: docs/why/EncounterDrawer.md#exclusive-sets
	func doom(on: bool) -> void:
		if doomed == on:
			return
		doomed = on
		if flesh != null:
			flesh.modulate = Color(1, 1, 1, 0.55 if on else 1.0)
		if over != null:
			over.modulate = Color(1, 1, 1, 1.0 if on else 0.0)
		dress(false)


	## A plain `Control`, since a heading-sized label would push the card past its fifth of the row.
	## Why: docs/why/EncounterDrawer.md#seal-overlay
	func seal(text: String, ink: Color, shown: bool) -> void:
		if stamp == null:
			over = Control.new()
			over.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(over)
			# The scrim makes the word a stamp, not a caption; `ColorRect` has no minimum size.
			# Why: docs/why/EncounterDrawer.md#seal-overlay
			var veil := ColorRect.new()
			veil.color = Color(UITheme.VOID.r, UITheme.VOID.g, UITheme.VOID.b,
				0.55)
			veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
			over.add_child(veil)
			stamp = UITheme.body("", ink, UITheme.FS_HEAD)
			stamp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			stamp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			over.add_child(stamp)
		stamp.text = text
		stamp.add_theme_color_override("font_color", ink)
		stamp.modulate = Color(1, 1, 1, 1.0)
		over.modulate = Color(1, 1, 1, 1.0 if shown else 0.0)

	func _notification(what: int) -> void:
		if not live:
			return
		if what == NOTIFICATION_MOUSE_ENTER:
			# Both directions, so the order of exit and enter events never matters.
			doom(false)
			for k in kin:
				(k as OptionCard).doom(true)
			dress(true)
		elif what == NOTIFICATION_MOUSE_EXIT:
			for k2 in kin:
				(k2 as OptionCard).doom(false)
			dress(false)

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if live and press.is_valid():
			press.call()
		accept_event()


## Shared by encounter, choice and later cards, so none repeats stripe, padding or hover.
static func plate(stripe: Color, on_press: Callable) -> Array:
	var card := OptionCard.new()
	card.press = on_press
	card.edge = stripe
	card.dress(false)
	var lane := HBoxContainer.new()
	lane.add_theme_constant_override("separation", 0)
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# An untagged option gets `LINE` back, so no tag draws no stripe rather than a grey one.
	var tag := ColorRect.new()
	tag.color = stripe
	tag.custom_minimum_size = Vector2(2, 0)
	tag.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane.add_child(tag)
	var pad := Widgets.pad(null, 9, 7)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	# THROUGH TO THE PLATE. The card is the thing that answers a click, and a
	# label that ate the press would leave dead spots over the words.
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)
	card.add_child(lane)
	return [card, col]




static func head(text: String, on_jump: Callable, loose: int = 0,
		on_loot: Callable = Callable()) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UITheme.body(text, UITheme.COLD, UITheme.FS_SMALL)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	# Always there, greyed when empty: a button that comes and goes moves the two beside it.
	# Why: docs/why/EncounterDrawer.md#loot-button
	if on_loot.is_valid():
		var loot := Widgets.button("SECTOR LOOT", on_loot)
		loot.custom_minimum_size = BTN
		loot.disabled = loose <= 0
		loot.tooltip_text = Widgets.tip("Things loose in this system: event rewards and anything you put down here. They stay for the rest of the run."
			if loose > 0 else "Nothing is loose in this system.")
		row.add_child(loot)
	# NO CLICK: the page turn is this button's sound. See
	# SectorScreen._plot_next_jump.
	var b := Widgets.button(TO_SECTOR, on_jump, false)
	b.custom_minimum_size = BTN
	row.add_child(b)
	return row


## A row is always five cards wide, or a lone card becomes a nine hundred pixel bar.
## Why: docs/why/EncounterDrawer.md#row-width
const SLOTS := 5

## Spent options keep their card and outcome: what you did is part of what the place is.
## Why: docs/why/EncounterDrawer.md#option-row
static func option_row(n: MapGen.MapNode, on_open: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Flat: exclusivity is the hover, not a box, so no option has a different shape.
	var sets: Dictionary = {}
	var used := 0
	for i in n.options.size():
		var opt := OptionTable.by_id(n.options[i])
		if opt.is_empty():
			continue
		var done := StringName(n.results.get(i, &""))
		# A CLAIM WITH NO RESULT BEHIND IT is a version 22 save, or an option
		# spent before this was recorded. It happened; we do not know how.
		if done == &"" and n.taken.has(MapGen.OPTION_SITE + i):
			done = MapGen.R_DONE
		var card := option_card(i, opt, on_open, done) as OptionCard
		row.add_child(card)
		used += 1
		var g := StringName(opt.get("group", &""))
		# ONLY THE LIVE ONES ARE RIVALS. A spent card cannot be foreclosed and
		# has nothing left to warn you about.
		if g == &"" or done != &"":
			continue
		if not sets.has(g):
			sets[g] = []
		(sets[g] as Array).append(card)
	# WHAT EACH ONE WOULD COST YOU. Wired after the row is built because a card
	# cannot know its rivals while it is the only one that exists yet.
	for g2 in sets:
		var members: Array = sets[g2]
		for c in members:
			for other in members:
				if other != c:
					(c as OptionCard).kin.append(other)
	# Spacers on a card's stretch ratio hand the unused slots to air.
	for _s in maxi(0, SLOTS - used):
		var gap := Control.new()
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(gap)
	return row


## Name and one sentence only: odds in the list turn choosing into arithmetic.
## Stamp colours are the bands' own, so the stamp and the result panel agree.
## Why: docs/why/EncounterDrawer.md#option-card-text
static func result_stamp(r: StringName) -> Array:
	match r:
		MapGen.R_SUCCESS: return ["SUCCESS", UITheme.GOOD]
		MapGen.R_PARTIAL: return ["PARTIAL", UITheme.EMBER]
		MapGen.R_BOTCHED: return ["BOTCHED", UITheme.LEAVE]
		# `CHILL`, not `COLD`: this seal is already faint and nothing you did produced it.
		MapGen.R_GONE: return ["UNAVAILABLE", UITheme.CHILL]
	return ["RESOLVED", UITheme.CHILL]


## Read off what the run already records; a partner's claim used to stamp RESOLVED as yours.
## Why: docs/why/EncounterDrawer.md#option-state
static func option_state(n: MapGen.MapNode, i: int) -> Dictionary:
	var oid := MapGen.OPTION_SITE + i
	var r := StringName(n.results.get(i, &""))
	if r == MapGen.R_GONE:
		var out := {"kind": &"gone", "word": "UNAVAILABLE", "ink": UITheme.CHILL, "by": "", "by_who": ""}
		var g := StringName(OptionTable.by_id(n.options[i]).get("group", &""))
		for j in n.options.size():
			if j == i or StringName(OptionTable.by_id(n.options[j]).get("group", &"")) != g:
				continue
			if n.taken.has(MapGen.OPTION_SITE + j) and StringName(n.results.get(j, &"")) != MapGen.R_GONE:
				out.by = String(OptionTable.by_id(n.options[j]).get("title", ""))
				out.by_who = Net.taker_name(n.index, MapGen.OPTION_SITE + j)
		return out
	if n.taken.has(oid):
		var who := Net.taker_name(n.index, oid)
		if who != "":
			return {"kind": &"who", "word": who.to_upper() + " TOOK IT", "ink": UITheme.THEM, "who": who}
		var m := result_stamp(r if r != &"" else MapGen.R_DONE)
		return {"kind": &"band", "word": m[0], "ink": m[1]}
	if n.left.has(i):
		return {"kind": &"left", "word": "LEFT ALONE", "ink": UITheme.CHILL}
	return {"kind": &"open", "word": "", "ink": UITheme.ICE}


## The ledger rows that moved, as one line: "FUEL -16 · HULL -3", or "".
static func moved_line(bill: Array) -> String:
	var bits: Array = []
	for r in bill:
		if String(r.text) != "—":
			bits.append("%s %s" % [r.name, r.text])
	return " · ".join(bits)


## `result` empty means an option nobody has touched. Anything else is a card
## that stays on the row with the word across it and does not answer a click.
static func option_card(i: int, opt: Dictionary, on_open: Callable,
		result: StringName = &"") -> Control:
	var kind := lead_tag(opt)
	var ink := tag_colour(opt)
	var made := plate(ink, on_open.bind(i))
	var card: OptionCard = made[0]
	var outer: VBoxContainer = made[1]
	# The seal is an overlay, so the card's words fade but the reason stays lit.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(col)
	card.flesh = col
	# Name and kind are one tight block: two readings of the same heading.
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 1)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var nm := UITheme.body(String(opt.get("title", "")).to_upper(),
		UITheme.ICE, UITheme.FS_SMALL)
	# WRAPPED, NOT CLIPPED. A fixed name column is what the bar had, and a long
	# title lost its last word to it. A card is as tall as it needs to be.
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(nm)
	# The stripe is spelled out in a word, so the colour code teaches itself.
	if kind != &"":
		head.add_child(UITheme.body(String(kind).to_upper(), ink,
			UITheme.FS_SMALL))
	var lead := UITheme.body(first_sentence(String(opt.get("body", ""))),
		UITheme.COLD, UITheme.FS_SMALL)
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# `max_lines_visible` caps the lead: an autowrapped label pushed the drawer to 206.
	# Why: docs/why/EncounterDrawer.md#card-height
	lead.max_lines_visible = 5
	lead.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lead.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(lead)
	# A spent option stays, greyed, so the record is not erased when it becomes history.
	if result != &"":
		var m := result_stamp(result)
		card.bar(false)
		col.modulate = Color(1, 1, 1, 0.55)
		card.seal(String(m[0]), m[1] as Color, true)
		return card
	# Reserved and faded, not shown on hover: a drawer must not grow under the pointer.
	if StringName(opt.get("group", &"")) != &"":
		card.seal("WILL BECOME UNAVAILABLE", UITheme.LEAVE, false)
	return card



## Fixed rows (four, and DATA a fifth, last) so each number lives in one place; rising heat
## uses `FLARE`, not loss red.
## Why: docs/why/EncounterDrawer.md#bill-rows
const BILL: Array[Array] = [
	["CREDITS", "credits", 1], ["HEAT", "heat", -1],
	["HULL", "hp", 1], ["FUEL", "fuel", 1],
	["DATA", "data", 1],
]

static func bill_rows(before: Dictionary, after: Dictionary) -> Array:
	var out: Array = []
	for row in BILL:
		var key := String(row[1])
		var n := int(after.get(key, 0)) - int(before.get(key, 0))
		var good := (n * int(row[2])) > 0
		out.append({
			# the stat, the move and both ends of it, for the result's outcome
			# line (`OutcomeRow`): "HULL 35 > 30" needs the totals, not the text
			key = key, n = n, was = int(before.get(key, 0)), now = int(after.get(key, 0)),
			good = good,
			name = String(row[0]),
			text = "—" if n == 0 else ("%+d" % n),
			tone = UITheme.COLD if n == 0 \
				else (UITheme.GOOD if good else \
					(UITheme.FLARE if key == "heat" else UITheme.LEAVE)),
		})
	return out


## The same plate as the card you pressed, sized as the payoff of the screen's one decision.
## Why: docs/why/EncounterDrawer.md#outcome-panel
static func outcome(opt: Dictionary, word: String, ink: Color, odds: String,
		said: String, rows: Array) -> Control:
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.PANEL2, UITheme.LINE, 0, 0, 0))
	var lane := HBoxContainer.new()
	lane.add_theme_constant_override("separation", 0)
	card.add_child(lane)
	# THE BAND'S OWN COLOUR, not the tag's. On the list a stripe says what KIND
	# of thing this is; here you already know, and the live fact is how it went.
	var bar := ColorRect.new()
	bar.color = ink
	bar.custom_minimum_size = Vector2(3, 0)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lane.add_child(bar)

	# THE VERDICT AS A BLOCK OF ITS OWN. It was a heading over a paragraph,
	# which makes the paragraph the subject; the outcome is the subject.
	var verdict := VBoxContainer.new()
	verdict.add_theme_constant_override("separation", 4)
	verdict.alignment = BoxContainer.ALIGNMENT_CENTER
	verdict.custom_minimum_size = Vector2(118, 0)
	var w := UITheme.body(word, ink, UITheme.FS_HEAD)
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	verdict.add_child(w)
	# The bet you took shows under the verdict, so a botch differs from a safe choice gone wrong.
	if odds != "":
		var o := UITheme.body(odds, UITheme.COLD, UITheme.FS_SMALL)
		o.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		verdict.add_child(o)
	lane.add_child(verdict)
	lane.add_child(_wall())

	var pad := Widgets.pad(null, 12, 9)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	pad.add_child(col)
	# IT NAMES THE ENCOUNTER, which the old one did not: three clicks after you
	# opened it, the only thing on screen was an outcome with nothing attached.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.add_child(UITheme.body(String(opt.get("title", "")).to_upper(),
		UITheme.ICE, UITheme.FS_SMALL))
	var kind := lead_tag(opt)
	if kind != &"":
		head.add_child(UITheme.body("· " + String(kind).to_upper(),
			tag_colour(opt), UITheme.FS_SMALL))
	col.add_child(head)
	var body := UITheme.body(said, UITheme.HOT, UITheme.FS_SMALL)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	# It does not name the reward: the crate is in REWARD, one button away, so naming repeats it.
	# Why: docs/why/EncounterDrawer.md#outcome-panel

	lane.add_child(_wall())
	var rail := Widgets.pad(null, 12, 9)
	rail.custom_minimum_size = Vector2(132, 0)
	lane.add_child(rail)
	var ledger := VBoxContainer.new()
	ledger.add_theme_constant_override("separation", 3)
	rail.add_child(ledger)
	# Label RESULT, identifier `bill`: identifiers name the mechanism, labels what the player sees.
	ledger.add_child(UITheme.body("RESULT", UITheme.COLD, UITheme.FS_SMALL))
	for r in rows:
		var line := HBoxContainer.new()
		var nm := UITheme.body(String(r.name), r.tone as Color, UITheme.FS_SMALL)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(nm)
		line.add_child(UITheme.body(String(r.text), r.tone as Color,
			UITheme.FS_SMALL))
		ledger.add_child(line)
	return card


## A hairline between two columns of one plate. `VSeparator` carries theme
## padding that would show up as a gap either side of it.
static func _wall() -> ColorRect:
	var c := ColorRect.new()
	c.color = UITheme.LINE
	c.custom_minimum_size = Vector2(1, 0)
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## The option you clicked, with its choices.

static func untaken(n: MapGen.MapNode) -> Array:
	var out: Array = []
	for i in n.options.size():
		if OptionTable.by_id(n.options[i]).is_empty():
			continue
		if not n.taken.has(MapGen.OPTION_SITE + i):
			out.append(i)
	return out


## CONTRACT was missing though it is a third of the table; violet as it is cold and unused.
## Why: docs/why/EncounterDrawer.md#tag-colours
const TAG_CONTRACT := Color("#9b8ec8")

## Hazard orange earns the warm exception: four of its seven options are combustion.
## Why: docs/why/EncounterDrawer.md#tag-colours
const TAG_HAZARD := Color("#f2761d")

## Bone, not brown: salvage is the safe warm tag and must not read like a warning.
## Why: docs/why/EncounterDrawer.md#tag-colours
const TAG_SALVAGE := Color("#b3a488")

## Gold marks origin, not kind: the one option that could not have been rolled.
## Why: docs/why/EncounterDrawer.md#tag-colours
const TAG_QUEST := Color("#e0b83c")

## Rose, for a reading (science): the last hue the six leave open, light enough at 2 px.
## Why: docs/why/EncounterDrawer.md#science-hue
const TAG_SCIENCE := Color("#e07ac8")

## Priority, not authoring order, so tag order cannot recolour an option; quest outranks all.
## Science comes after salvage.
## Why: docs/why/EncounterDrawer.md#tag-priority
const TAG_ORDER: Array[StringName] = [&"quest", &"fight", &"hazard", &"salvage",
	&"science", &"signal", &"contract"]

## One resolution feeds colour and word, as two priority lists would go stale.
static func lead_tag(opt: Dictionary) -> StringName:
	var tags: Array = opt.get("tags", [])
	for want in TAG_ORDER:
		for t in tags:
			if StringName(t) == want:
				return want
	return &""


static func tag_colour(opt: Dictionary) -> Color:
	match lead_tag(opt):
		&"quest": return TAG_QUEST
		&"fight": return UITheme.LEAVE
		&"hazard": return TAG_HAZARD
		&"salvage": return TAG_SALVAGE
		&"science": return TAG_SCIENCE
		&"signal": return Color("#8ec8e6")
		&"contract": return TAG_CONTRACT
	return UITheme.LINE
## Same plate as the encounter, number inside what you commit to; the stripe shows the gate.
## Why: docs/why/EncounterDrawer.md#choice-cards
static func choice_card(n: MapGen.MapNode, i: int, j: int, c: Dictionary,
		_opt: Dictionary, on_take: Callable) -> Control:
	# Ruling 8: an unaffordable hard gate greys and says by how much.
	var note := ""
	var tone := UITheme.COLD
	var open := true
	# A material gate greys instead of hiding (ruling 8), so the player learns why it worked.
	# Why: docs/why/EncounterDrawer.md#choice-gates
	if c.has("needs_material"):
		var mid := StringName(c.needs_material)
		# Aboard, not in a ledger: `Run.material` counts the hold, so a gate wants carried things.
		var have := Run.material(mid)
		note = "1 %s · you have %d" % [String(mid), have]
		if have < 1:
			open = false
			tone = UITheme.FLARE
	elif c.has("cost_credits"):
		var cost := int(c.cost_credits)
		note = "%d credits · you have %d" % [cost, Run.credits]
		if Run.credits < cost:
			open = false
			tone = UITheme.FLARE
	elif c.has("check"):
		# Ruling 3: the odds are on the button, so there is no confirm step.
		note = SkillCheck.badge(c.check)
		tone = SkillCheck.badge_colour(c.check)
	elif bool(c.get("fight", false)) or opens_fight(c):
		note = contact_reading(n)
		tone = UITheme.THEM
	# A READING BURNS FUEL (science, `burns`): what it costs goes on the card, after any odds,
	# so the number you pay is inside what you press.
	# Why: docs/why/EncounterDrawer.md#a-reading-burns-fuel
	if bool(c.get("burns", false)):
		var burn := OptionTable.science_fuel()
		if not OptionResolve.fuel_ok(c):
			var keep := Run.fuel_floor()
			note = "needs %d fuel%s · you have %d" % [burn,
				" + %d to leave" % keep if keep > 0 else "", Run.fuel]
			open = false
			tone = UITheme.FLARE
		else:
			note = "%d fuel" % burn if note == "" else "%s · %d fuel" % [note, burn]
	var made := plate(tone, on_take.bind(i, j))
	var card: OptionCard = made[0]
	var col: VBoxContainer = made[1]
	# Taller than its words, so it is a thing you press rather than a row you read.
	card.custom_minimum_size = Vector2(150, 44)
	if not open:
		card.bar(false)
	# THE WORDS AS THIS SYSTEM HAS THEM (`OptionTable.label_of`): a label may
	# name something rolled here, as the derelict hauler's frame does.
	var words := OptionTable.label_of(c, n)
	var lb := UITheme.body((words if words != "" else "…").to_upper(),
		UITheme.ICE if open else UITheme.COLD, UITheme.FS_SMALL)
	lb.name = "Words"
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(lb)
	if note != "":
		var nl := UITheme.body(note, tone, UITheme.FS_SMALL)
		nl.name = "Note"
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(nl)
	return card


## Ruling 5: a fight row prints what the dish read, `chart_from()` one scale down.
## Why: docs/why/EncounterDrawer.md#contact-reading
static func contact_reading(n: MapGen.MapNode) -> String:
	var s := Run.attr_sensors()
	if s < 3:
		return "Fight."
	var pack := Router._roll_foes(n)
	if pack.is_empty():
		return "Fight."
	if s < 6:
		return "Fight · %d %s" % [pack.size(),
			"contact" if pack.size() == 1 else "contacts"]
	# One adjective, not a build readout: ENCOUNTER_FLOW.md 7 asks for count first.
	var hot: String = String(DB.enemies[pack[0]].name).to_lower()
	return "Fight · %d %s, one of them a %s" % [pack.size(),
		"contact" if pack.size() == 1 else "contacts", hot]


## The declaration, not the trigger: the list prints before the callable has run.
static func opens_fight(c: Dictionary) -> bool:
	return bool(c.get("fight", false))


## One line of body for the list. The rest lives in the detail view.
static func first_sentence(body: String) -> String:
	var cut := body.find(". ")
	if cut < 0:
		return body
	return body.substr(0, cut + 1)


## Take one choice where it stands.

static func quiet_lines(n: MapGen.MapNode) -> Array:
	if Run.dead:
		return ["The ship is lost. The run is over.", "SUMMARY"]
	if Run.hellbender_alive() and Run.hellbender_at == n.index:
		if not Router.at_hellbender(n):
			return ["The Hellbender is anchored past the last orbit, its holds glowing with what it has taken. It blocks the rest of this system. Fly out to it to engage.", TO_SECTOR]
		return ["The Hellbender is anchored here, its holds glowing with what it has taken. It blocks the rest of this system.",
			"ENGAGE THE HELLBENDER"]
	match n.type:
		MapGen.NodeType.STATION:
			# (docks only at the station itself, dock:A; elsewhere the map, to fly there)
			if not Router.at_station(n):
				return ["A hab ring turns slowly, lights on. It trades, repairs and refuels, all paid from your one balance. " + Router.DOCK_AWAY, TO_SECTOR]
			return ["A hab ring turns slowly, lights on. It trades, repairs and refuels, all paid from your one balance.", "DOCK"]
		MapGen.NodeType.SYSTEM:
			if n.eaten:
				return ["The Hellbender stripped this system first. The cuts are still fresh.", TO_SECTOR]
			# The list says what is here; this line only says where you are.
			var left := 0
			for i in n.options.size():
				if not n.taken.has(MapGen.OPTION_SITE + i):
					left += 1
			if n.cleared or left <= 0:
				# Ruling 7: an empty list only means you took it all, a small subtraction.
				return ["There is nothing left here for you.", TO_SECTOR]
			return ["This system still has events open.", TO_SECTOR]
		MapGen.NodeType.PULSAR:
			if n.cleared:
				return ["You have already harvested the beam here.",
					TO_SECTOR]
			return ["A neutron star turns here eleven times a second. Its wind is the densest fuel in the galaxy. To scoop it you must fly close, where the beam cooks you through the hull.",
				"FLY THE BEAM"]
		MapGen.NodeType.START:
			return ["Open space, with the reactor running. The core is far in from here.", TO_SECTOR]
		# The core waits for the party; the line above the button must name what pressing does.
		MapGen.NodeType.CORE:
			if n.cleared:
				return ["The core is open. Its guard is gone.", TO_SECTOR]
			if n.fled:
				return ["You broke off. It still guards the core.", TO_SECTOR]
			if not Router.at_custodian(n):
				return ["The core fills the viewport. The Custodian guards it from the edge of the disc. Fly out to it to engage.", TO_SECTOR]
			return ["The core fills the viewport. The Custodian still guards it.", "ENGAGE"]
		_:
			return ["", TO_SECTOR]

## The strip is gone: position names each intent for free, over each enemy.
## Why: docs/why/EncounterDrawer.md#intent-strip
