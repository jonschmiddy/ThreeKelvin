class_name EncounterDrawer

## How a system describes itself, before anything is shooting.
##
## Lifted out of `SectorScreen`, which is BOTH the arrival screen and the combat
## screen and had reached 2,357 lines carrying the two of them. `ROADMAP.md`
## flagged that when it was 1,221 -- "E and L both make large edits to
## SectorScreen.gd ... sequence them" -- and three queued jobs edit it now.
## Sequencing is not the fix when the file keeps growing; separating is.
##
## Everything here is STATIC and builds a Control from data. That is not a style
## choice, it is the test that decided what could move: eleven of these twelve
## touched no screen state at all, and the two that did reached for exactly one
## thing each -- opening an option, and taking one. Both are now `Callable`
## parameters, which is the pattern `Widgets.module_row` and `PileView.opened`
## already use here.
##
## What stayed behind is the state machine: which of LIST, OPTION and RESULT the
## drawer is in, what is open, and what happens when you take something. That is
## the screen's business and it reads its own fields. This file is the pictures.


## `on_jump` is the third and last thing these builders reached back into the
## screen for: the PLOT NEXT JUMP button hangs off the heading, and pressing it
## is the screen's business.
## `loose` is how much is lying around this system's own pile, and `on_loot`
## opens it. Zero hides the button: a door onto an empty room lies once per
## system.
##
## Beside PLOT NEXT JUMP because those are the two things you do with a system
## once you have read it -- take what is in it, and leave. What a WRECK holds is
## reached through the wreck, which is sitting in the picture above.
## WHAT A SECTOR'S BUTTONS MEASURE, everywhere.
##
## They were 148x17 in the option drawer and 150x24 in the one-thing drawer, so
## the same three controls changed height depending on what kind of place you
## had flown into -- which reads as the panel being rebuilt rather than as the
## contents changing.
##
## Narrower than either, and then narrower again. They were sized to fill a row
## that had nothing else in it; with three abreast they only need to hold their
## own words. 104 fits "PLOT NEXT JUMP" and "SECTOR LOOT - 12" at FS_SMALL with
## the stylebox's own padding either side and nothing spare.
const BTN := Vector2(94, 20)

## One encounter, as a plate you click into.
##
## A ROW IS A LEDGER LINE AND AN ENCOUNTER IS NOT ONE. These were full-width
## bars 21 pixels tall: a name column, a sentence clipped mid-word, and a
## right-aligned number. Three of them stacked read as a table of accounts,
## which is the wrong promise -- a table is something you scan for a value, and
## these are things you go and do. Side by side and square-ish, they read as
## choices instead, and the drawer stops looking like a receipt.
##
## THE PLATE IS THE CLICK TARGET, which is most of the argument for a
## `PanelContainer` over the `Button` the row used. A Button is not a container:
## it cannot pad itself from its own stylebox, so the row anchored its contents
## to the full rect and had no margins at all. This sizes to its contents and
## the stylebox does the spacing, which is what makes the padding uniform.
## `press` TAKES NO ARGUMENTS. It was an index and a callable to hand it to,
## which only suited the one caller; a choice needs an option AND a choice
## number. Binding at the call site means the plate does not have to know what
## kind of thing it is pressing.
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
	## Pointed at from a card that would foreclose this one. Still takeable --
	## you have not committed to anything by hovering -- so this is a warning
	## about what the OTHER card costs, drawn on the thing it would cost.
	var doomed: bool = false
	## Faded when doomed or spent: everything the card SAYS about its option.
	var flesh: Control = null
	## The word across the middle. One label, because a card is never both
	## warned-about and finished: a spent option is out of every group it was in.
	var stamp: Label = null

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

	## THE FRAME IS STATE AND THE STRIPE IS IDENTITY, and putting both on the
	## border was the mistake. `tag_colour` spans a bright cyan for a signal, a
	## muted brown for salvage and `LINE` itself for an untagged option, so four
	## cards edged in their own tag came out at four different weights and the
	## brightest one read as the selected one. It is a uniform frame now, and the
	## tag is the flush stripe down the left that `option_card` adds.
	##
	## Zero padding, because the stripe has to touch the edge: a PanelContainer
	## insets its whole child by the stylebox margins, so the spacing moved to a
	## MarginContainer around the text only.
	func dress(hot: bool) -> void:
		if not live or doomed:
			add_theme_stylebox_override("panel", UITheme.flat(
				UITheme.PANEL, UITheme.LINE.darkened(0.3), 0, 0, 0))
			return
		add_theme_stylebox_override("panel", UITheme.flat(
			UITheme.PANEL2.lightened(0.06) if hot else UITheme.PANEL2,
			UITheme.COLD if hot else UITheme.LINE, 0, 0, 0))

	## RULING 1, AS A GESTURE RATHER THAN A BOX.
	##
	## An exclusive set used to be a bordered panel labelled ONE ONLY wrapped
	## around its members: a caption you read once and then stopped seeing, and a
	## second level of layout that made a pair of options a different SHAPE from
	## every other option on the row. Pointing at one and watching the other go
	## grey says the same thing at the moment it is worth knowing, costs no
	## chrome, and lets every card be one card again.
	##
	## The warning is at full strength while everything else in the card fades,
	## because the fade is the thing being said and the sentence is what says it.
	func doom(on: bool) -> void:
		if doomed == on:
			return
		doomed = on
		if flesh != null:
			flesh.modulate = Color(1, 1, 1, 0.55 if on else 1.0)
		if stamp != null:
			stamp.modulate = Color(1, 1, 1, 1.0 if on else 0.0)
		dress(false)


	## THE WORD ACROSS THE MIDDLE, over everything else on the card.
	##
	## In a plain `Control` rather than a container, and that is the whole
	## trick: a `PanelContainer` takes its own minimum size from its children,
	## and a heading-sized label saying WILL BECOME UNAVAILABLE reports a
	## minimum two hundred pixels wide -- which would push the card past its
	## fifth of the row and take the drawer with it. A bare Control reports
	## nothing, and the panel stretches it to fill instead.
	func seal(text: String, ink: Color, shown: bool) -> void:
		if stamp == null:
			var over := Control.new()
			over.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(over)
			# THE THING THAT MAKES IT A STAMP RATHER THAN A CAPTION. A word
			# lying on top of legible prose reads as part of the card; the same
			# word over a card you can no longer quite read reads as a seal on
			# it. `ColorRect` has no minimum size of its own, so the scrim is
			# free -- see the note above about what a heading-sized label would
			# have cost.
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
		stamp.modulate = Color(1, 1, 1, 1.0 if shown else 0.0)

	func _notification(what: int) -> void:
		if not live:
			return
		if what == NOTIFICATION_MOUSE_ENTER:
			# BOTH DIRECTIONS, and the order the two events arrive in stops
			# mattering: sliding from one card of a pair to the other fires an
			# exit and an enter, and whichever lands second still leaves exactly
			# the pointed-at card lit and its rival grey.
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


## The plate itself, without any opinion about what goes on it.
##
## Three callers now: an encounter, a choice, and whatever is next. Each one
## fills the box; none of them repeats the stripe, the padding or the hover.
static func plate(stripe: Color, on_press: Callable) -> Array:
	var card := OptionCard.new()
	card.press = on_press
	card.edge = stripe
	card.dress(false)
	var lane := HBoxContainer.new()
	lane.add_theme_constant_override("separation", 0)
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# WHAT KIND OF THING THIS IS, at two pixels. An untagged option gets `LINE`
	# back, which is the frame's own colour -- so no tag draws no stripe rather
	# than drawing a grey one that means nothing.
	var tag := ColorRect.new()
	tag.color = stripe
	tag.custom_minimum_size = Vector2(2, 0)
	tag.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane.add_child(tag)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 7)
	for side2 in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side2, 9)
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
	# ALWAYS THERE, GREYED WHEN EMPTY, and no count on it.
	#
	# A button that appears and disappears moves the two beside it, so the jump
	# is somewhere different depending on whether you happen to have dropped
	# something -- and a number on it was a running total of a thing you open to
	# look at anyway. Greyed says "nothing here" and keeps the row still.
	if on_loot.is_valid():
		var loot := Widgets.button("SECTOR LOOT", on_loot)
		loot.custom_minimum_size = BTN
		loot.disabled = loose <= 0
		loot.tooltip_text = Widgets.tip("What is loose in this system that no hull is holding: what an event paid out, and anything you have put down here. It stays for the rest of the run."
			if loose > 0 else "Nothing is loose in this system.")
		row.add_child(loot)
	var b := Widgets.button("PLOT NEXT JUMP", on_jump)
	b.custom_minimum_size = BTN
	row.add_child(b)
	return row


## A ROW IS ALWAYS FIVE CARDS WIDE, however many are in it.
##
## Every card takes an equal share of whatever room the row has, so a system
## with one thing in it drew one card nine hundred pixels across -- a bar again,
## and the shape a card exists not to be. Padding the row out to five keeps a
## card the same object from system to system: the same width, the same amount
## of prose before it wraps, the same thing in the same place.
##
## Five rather than four because the table rolls two to FOUR and an exclusive
## pair beside three loose options is five slots' worth. `maxi` is the guard for
## the day that stops being true.
const SLOTS := 5

## Every untaken option in this system, side by side.
##
## The screen used to run this loop itself and add one child per option; it is
## here because it is a picture, and because the exclusive-set bracket below has
## to be laid out ALONGSIDE the loose options rather than above them.
## EVERY OPTION THE SYSTEM EVER HAD, not just the live ones. What you did here
## is part of what the place is, so a spent option keeps its card and wears its
## outcome -- see `option_card`.
static func option_row(n: MapGen.MapNode, on_open: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# FLAT. Every option is one card in one row, including the members of an
	# exclusive set -- what makes them exclusive is now the hover, not a box
	# around them, so there is no second level of layout and no option that is a
	# different shape from the option beside it.
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
	# AND THE REST OF THE ROW IS NOTHING, DELIBERATELY. Spacers on the same
	# stretch ratio as a card, which is the whole mechanism: the row divides
	# itself five ways and hands four of them to air.
	for _s in maxi(0, SLOTS - used):
		var gap := Control.new()
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(gap)
	return row


## ITS NAME AND ONE SENTENCE, AND NOTHING ELSE.
##
## The row printed a third column: the odds on its check, or what it cost, or
## what the dish read off the contact. That is the detail view leaking into the
## list. A number you can compare across four rows turns choosing an encounter
## into arithmetic before you have read what any of them ARE -- and the numbers
## are all still there, one click away, on the choice buttons where you are
## actually committing to one. `row_hint` and `lead_check` went with it.
##
## `n` is not a parameter any more for the same reason: everything the old row
## needed the system for was in that column.
## THE WORD A SPENT CARD WEARS, and its colour.
##
## Success, partial and botched take the bands' own colours, so the stamp and
## the result panel that produced it agree. `DONE` is an option with no check in
## it -- there was nothing to succeed at, so it says what happened and no more.
static func result_stamp(r: StringName) -> Array:
	match r:
		MapGen.R_SUCCESS: return ["SUCCESS", UITheme.GOOD]
		MapGen.R_PARTIAL: return ["PARTIAL", UITheme.EMBER]
		MapGen.R_BOTCHED: return ["BOTCHED", Color("#d4614f")]
		# CHILL, NOT COLD. Every other seal is a saturated band colour and this
		# one is a grey on a scrim over a dimmed card -- three things making it
		# fainter at once, and it came out looking like a card that had simply
		# gone grey for no stated reason. It is the one seal that has to explain
		# itself, because nothing you did produced it.
		MapGen.R_GONE: return ["UNAVAILABLE", UITheme.CHILL]
	return ["RESOLVED", UITheme.CHILL]


## `result` empty means an option nobody has touched. Anything else is a card
## that stays on the row with the word across it and does not answer a click.
static func option_card(i: int, opt: Dictionary, on_open: Callable,
		result: StringName = &"") -> Control:
	var kind := lead_tag(opt)
	var ink := tag_colour(opt)
	var made := plate(ink, on_open.bind(i))
	var card: OptionCard = made[0]
	var outer: VBoxContainer = made[1]
	# THE HALF THAT FADES, and the half that does not. Everything the card SAYS
	# about its option dims when a rival is pointed at or when it is spent; the
	# word explaining why is an overlay rather than a child, so it stays lit.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(col)
	card.flesh = col
	# THE NAME AND WHAT KIND OF THING IT IS, as one block. Tight, because they
	# are two readings of the same heading -- the gap before the prose is what
	# separates the heading from the body.
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
	# THE STRIPE, SPELLED OUT. Two pixels of colour is a code you have to be
	# taught; the word beside it in the same colour teaches it, and after a
	# few systems the colour alone carries. An untagged option says nothing
	# rather than saying UNTAGGED.
	if kind != &"":
		head.add_child(UITheme.body(String(kind).to_upper(), ink,
			UITheme.FS_SMALL))
	var lead := UITheme.body(first_sentence(String(opt.get("body", ""))),
		UITheme.COLD, UITheme.FS_SMALL)
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A CEILING, WHICH A LABEL DOES NOT OTHERWISE HAVE. `custom_minimum_size` is
	# a floor and an autowrapped label reports its wrapped height as a minimum,
	# so a long first sentence in a fifth-width card pushed the whole drawer to
	# 206 -- past the fixed band, and out of step with the hand band that is
	# supposed to match it. `max_lines_visible` is the one thing that actually
	# caps a Label, and the ellipsis is what keeps a cut sentence honest: the
	# row it replaced clipped mid-word with no mark at all.
	lead.max_lines_visible = 5
	lead.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lead.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(lead)
	# SPENT, AND STILL HERE. A resolved option used to drop off the list, so a
	# system you had worked through went blank and the drawer said "nothing else
	# wants anything from you" over an empty band -- the record of what you did
	# there erased at the moment it became history. It stays, greyed, wearing
	# what it came to.
	if result != &"":
		var m := result_stamp(result)
		card.bar(false)
		col.modulate = Color(1, 1, 1, 0.55)
		card.seal(String(m[0]), m[1] as Color, true)
		return card
	# RESERVED, NOT SHOWN. Built for every card in an exclusive set and faded to
	# nothing until one of its rivals is pointed at -- appearing on hover would
	# make the card taller at the moment the cursor lands on it, and a drawer
	# that grows under the pointer is the one thing this row must not do.
	if StringName(opt.get("group", &"")) != &"":
		card.seal("WILL BECOME UNAVAILABLE", UITheme.LEAVE, false)
	return card



## WHAT MOVED, as four fixed rows.
##
## FIXED, and printing an em dash for the two that did not. The alternative is
## listing only what changed, which makes the rail a different height and a
## different shape on every outcome -- so CREDITS is on the second line
## sometimes and the fourth line other times, and you have to read it to find
## out. Four rows always means you learn where each number lives once.
##
## HEAT RISING IS NOT A LOSS, and gets `FLARE` rather than the red the other
## three use when they fall: nothing was taken off the ship. It is a bill that
## comes due at the end of the turn, which is what that colour means everywhere
## else on this screen.
const BILL: Array[Array] = [
	["CREDITS", "credits", 1], ["HEAT", "heat", -1],
	["HULL", "hp", 1], ["FUEL", "fuel", 1],
]

static func bill_rows(before: Dictionary, after: Dictionary) -> Array:
	var out: Array = []
	for row in BILL:
		var key := String(row[1])
		var n := int(after.get(key, 0)) - int(before.get(key, 0))
		var good := (n * int(row[2])) > 0
		out.append({
			name = String(row[0]),
			text = "—" if n == 0 else ("%+d" % n),
			tone = UITheme.COLD if n == 0 \
				else (UITheme.GOOD if good else \
					(UITheme.FLARE if key == "heat" else UITheme.LEAVE)),
		})
	return out


## WHAT JUST HAPPENED, at the size it happened.
##
## The result was an eyebrow, a sentence, and a hundred and forty pixels of
## nothing: the band in small type, the prose beside it, and a CONTINUE button
## marooned in the far corner of a drawer that had gone empty. It is the payoff
## of the only decision the screen asks you to make, and it was the quietest
## thing on it.
##
## The same plate as the card you pressed to get here, which is the point --
## you chose a thing that looked like this, and this is that thing answering.
## The band gets the heading size the seals on the list already use, so the
## outcome reads from across the room and the prose is what you lean in for.
##
## It also names the encounter, which the old one did not: three clicks after
## you opened it, the only thing on screen was an outcome with nothing attached.
static func outcome(opt: Dictionary, word: String, ink: Color, odds: String,
		said: String, rows: Array, got: String) -> Control:
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
	# THE BET YOU TOOK, under the verdict, and this is the line the drawer used
	# to throw away. It knows you just took a twenty percent shot and forgot it
	# the instant it resolved -- so a botch and a safe choice that happened to
	# go wrong read identically afterwards. Four words, and it is the difference
	# between "this game is random" and "I knew".
	if odds != "":
		var o := UITheme.body(odds, UITheme.COLD, UITheme.FS_SMALL)
		o.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		verdict.add_child(o)
	lane.add_child(verdict)
	lane.add_child(_wall())

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + s, 9)
	for s2 in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + s2, 12)
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
	# WHAT CAME OUT OF IT AS AN OBJECT, which the rail cannot hold: the rail is
	# four numbers and a material is a thing with a name.
	if got != "":
		col.add_child(UITheme.body(got.to_upper(), UITheme.GOOD,
			UITheme.FS_SMALL))

	lane.add_child(_wall())
	var rail := MarginContainer.new()
	rail.custom_minimum_size = Vector2(132, 0)
	for s3 in ["top", "bottom"]:
		rail.add_theme_constant_override("margin_" + s3, 9)
	for s4 in ["left", "right"]:
		rail.add_theme_constant_override("margin_" + s4, 12)
	lane.add_child(rail)
	var ledger := VBoxContainer.new()
	ledger.add_theme_constant_override("separation", 3)
	rail.add_child(ledger)
	# RESULT on screen, `bill` in the code, and they are allowed to differ --
	# same rule `berth` and the containers follow. The identifiers name the
	# mechanism (a ledger closed either side of a resolution); the label names
	# what the player is looking at, which is what came of the thing they did.
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


## What a tag reads as at three pixels wide. A fight is a threat, salvage is a
## wreck, a signal is somebody talking.
## CONTRACT WAS MISSING, and it is the biggest group in the table: fifteen of
## forty-nine options are tagged `contract` and nothing else, so a third of the
## table fell through to `LINE` and drew no stripe at all. A code that is silent
## about its largest category is not a code.
##
## Violet because it has to be cold and it has to be unused. The palette note at
## the top of `UITheme` reserves every warm colour for combustion, and salvage's
## brown is already stretching that; green is the hull bar's.
const TAG_CONTRACT := Color("#9b8ec8")

## Hazard orange, and it is the one warm tag that earns the palette's exception.
##
## `UITheme`'s note reserves the warm end for combustion -- reactor glow, weapon
## fire, heat on your own hull -- and four of these seven options ARE combustion:
## a star mid-tantrum, a flare forty minutes out, a pulsar beam, a lane you
## cannot thread. Saturated past `EMBER`, which is a reading on your own ship,
## and away from `LEAVE`, which is somebody shooting.
const TAG_HAZARD := Color("#f2761d")

## Bone. A wreck is not dirt, and brown said dirt.
##
## This was `#9a7b52`, which worked while it was the only warm tag and stopped
## the moment HAZARD arrived beside it: red, orange and brown are one family,
## and salvage is the SAFE one of the three -- the tag that says nothing here is
## trying to kill you. Bleached and desaturated, it reads as material rather
## than as heat, and it never competes with the two that are warnings.
##
## Warm on purpose even so. The cold half of the wheel is where this game keeps
## its TEXT -- `COLD`, `CHILL`, `ICE` are the body, the labels and the titles --
## so a grey stripe would sit a shade away from the words printed next to it,
## and a green one would collide with `GOOD`, which is the SUCCESS stamp.
const TAG_SALVAGE := Color("#b3a488")

## PRIORITY, NOT AUTHORING ORDER. `lead_tag` read the option's own `tags` array
## and returned the first one it recognised, so `[signal, fight]` came out cyan
## and `[fight, signal]` came out red -- the same option two colours depending
## on which word got typed first. A fight is the fact that changes what you
## would do about the thing, so it outranks whatever else is true of it.
##
## HAZARD SITS SECOND, under a fight and over everything else. The corona and
## the mine drift are both wrecks worth stripping and both are tagged salvage,
## which is true and is not the thing you need to know first: what decides
## whether you go in is the star and the mines. A fight still outranks it,
## because something aiming at you is a shorter clock than something you are
## flying into.
const TAG_ORDER: Array[StringName] = [&"fight", &"hazard", &"salvage",
	&"signal", &"contract"]

## WHICH ONE OF ITS TAGS THIS OPTION IS, once and for both readings of it.
##
## The colour and the word under the title have to agree or the stripe is
## teaching the wrong lesson, and they can only agree by coming from the same
## resolution -- two priority lists is one of them going stale.
static func lead_tag(opt: Dictionary) -> StringName:
	var tags: Array = opt.get("tags", [])
	for want in TAG_ORDER:
		for t in tags:
			if StringName(t) == want:
				return want
	return &""


static func tag_colour(opt: Dictionary) -> Color:
	match lead_tag(opt):
		&"fight": return UITheme.LEAVE
		&"hazard": return TAG_HAZARD
		&"salvage": return TAG_SALVAGE
		&"signal": return Color("#8ec8e6")
		&"contract": return TAG_CONTRACT
	return UITheme.LINE
## THE SAME PLATE THE ENCOUNTER WAS, one screen further in.
##
## These were stock buttons with a caption underneath: a grey rectangle, a word
## in the middle of it, and the number that the whole decision turns on floating
## outside the thing you were about to press. Three of them in a row read as a
## form. On a plate the label and its number are one object, the number is INSIDE
## what you are committing to, and the OPTION state matches the list you reached
## it from -- the same shape means the same kind of act.
##
## The stripe is what stands in the way. `tag_colour` answers "what kind of thing
## is this" for an encounter; here there is only one kind of thing and the useful
## fact is the gate: red when you cannot pay, the band's own colour when it is a
## roll, the contact colour when it opens a fight.
static func choice_card(n: MapGen.MapNode, i: int, j: int, c: Dictionary,
		_opt: Dictionary, on_take: Callable) -> Control:
	# RULING 8: an unaffordable hard gate greys and says by how much. A gate is a
	# meter payment and 40 credits genuinely is not 60 -- but a disabled thing
	# still says what it wants and how far off you are.
	var note := ""
	var tone := UITheme.COLD
	var open := true
	# A GATE ON WHAT YOU ARE CARRYING, not on what you can pay. `holding_pattern`
	# trades an exotic-tier item to a queue that has been waiting long enough to
	# want one, and the handoff asked for the choice to be HIDDEN if this could
	# not land tonight. Greying it is better and costs the same: RULING 8 already
	# says a disabled thing states what it wants and how far off you are, and a
	# hidden row teaches the player nothing about why the trade was possible the
	# last time they saw it.
	if c.has("needs_material"):
		var mid := StringName(c.needs_material)
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
		# RULING 3: the odds are on the button, so there is no confirm step. A
		# dialog after showing 40% asks the same question twice and teaches the
		# player the number was not the commitment.
		note = SkillCheck.badge(c.check)
		tone = SkillCheck.badge_colour(c.check)
	elif bool(c.get("fight", false)) or opens_fight(c):
		note = contact_reading(n)
		tone = UITheme.THEM
	var made := plate(tone, on_take.bind(i, j))
	var card: OptionCard = made[0]
	var col: VBoxContainer = made[1]
	# TALLER THAN ITS WORDS. A plate the exact height of one line and a caption
	# is a button with extra steps; the room is what makes it a thing you press
	# rather than a row you read.
	card.custom_minimum_size = Vector2(150, 44)
	if not open:
		card.bar(false)
	var lb := UITheme.body(String(c.get("label", "…")).to_upper(),
		UITheme.ICE if open else UITheme.COLD, UITheme.FS_SMALL)
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(lb)
	if note != "":
		var nl := UITheme.body(note, tone, UITheme.FS_SMALL)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(nl)
	return card


## RULING 5 — what a fight row prints, and it is something the player bought.
##
## Every other row prints a number and this one printed nothing until the fight
## started. A flat enemy count spoils a reveal worth keeping; leaving it bare is
## inconsistent. So it is `chart_from()` one scale down: the dish already tells
## you WHERE things are, and a better dish tells you WHAT they are.
##
## It also finally gives SENSORS something to do outside event checks -- its
## attribute row prints an empty effect string today because nothing reads it.
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
	# One adjective, not a build readout. Composition starts to read the enemy's
	# loadout, which is closer to a combat preview than a chart reading -- see
	# ENCOUNTER_FLOW.md 7, which asks for count first and a measurement before
	# going further.
	var hot: String = String(DB.enemies[pack[0]].name).to_lower()
	return "Fight · %d %s, one of them a %s" % [pack.size(),
		"contact" if pack.size() == 1 else "contacts", hot]


## Does this choice SAY it leads to a fight?
##
## The declaration, not the trigger -- see the note on `hostile_contact`. A list
## has to print its reading before the click, and the trigger only exists after
## the callable has run.
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
		return ["Nothing on this hull answers any more.", "SUMMARY"]
	if Run.hellbender_alive() and Run.hellbender_at == n.index:
		return ["The Hellbender rides at anchor here, holds glowing with everything it has taken. Nothing else in this system is reachable past it.",
			"ENGAGE THE HELLBENDER"]
	match n.type:
		MapGen.NodeType.STATION:
			return ["A hab ring turns slowly, lights on. They will trade, repair and refuel — all of it out of the same pocket.", "DOCK"]
		MapGen.NodeType.SYSTEM:
			if n.eaten:
				return ["Cut open along the spine, and the cuts are fresh. The Hellbender fed here first.", "PLOT NEXT JUMP"]
			# THE LIST SAYS WHAT IS HERE; this line only says where you are. It
			# used to name a button -- LOOK -- because a system opened one thing
			# at a time, and the button is now every row below.
			var left := 0
			for i in n.options.size():
				if not n.taken.has(MapGen.OPTION_SITE + i):
					left += 1
			if n.cleared or left <= 0:
				# RULING 7. Every system rolls two to four options, so an empty one
				# only ever means you took it all -- and in a setting whose premise
				# is extraction from a universe running down, that is not a
				# completion tick. A small subtraction, which is also simply true.
				return ["Nothing else here wants anything from you.", "PLOT NEXT JUMP"]
			return ["The lane is quiet and the board is not.", "PLOT NEXT JUMP"]
		MapGen.NodeType.PULSAR:
			if n.cleared:
				return ["The beam still sweeps. Nothing left aboard can hold any more of it.",
					"PLOT NEXT JUMP"]
			return ["A neutron star, turning eleven times a second. Its wind is the densest fuel in the galaxy and its beam will cook you through the hull. Close enough to scoop is close enough to die.",
				"FLY THE BEAM"]
		MapGen.NodeType.START:
			return ["Open space, and the reactor holding. The core is a long way in from here.", "PLOT NEXT JUMP"]
		# The core, waiting. Arriving here no longer opens the fight, so this is
		# what the screen says while the party gathers and somebody decides to
		# commit — the line above the button has to name what pressing it does.
		MapGen.NodeType.CORE:
			if n.cleared:
				return ["The light is behind you.", "PLOT NEXT JUMP"]
			if n.fled:
				return ["You broke off. It is still between you and the light.", "PLOT NEXT JUMP"]
			return ["The core fills the viewport. Something is still guarding it.", "ENGAGE"]
		_:
			return ["", "PLOT NEXT JUMP"]

## The intent strip is gone.
##
## Everything it held moved to the thing it was describing: the move and its
## effect sit over each enemy, each enemy's chips sit under it, and yours sit
## with your energy. A strip at the bottom of the screen naming which ship an
## intent belonged to was doing work that position does for free — and in a
## pack it had to name them all in one line.
