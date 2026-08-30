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
class OptionCard extends PanelContainer:
	var index: int = 0
	var on_open: Callable
	## The option's tag colour, on the left edge. See `tag_colour`.
	var edge: Color = UITheme.LINE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL

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
		add_theme_stylebox_override("panel", UITheme.flat(
			UITheme.PANEL2.lightened(0.06) if hot else UITheme.PANEL2,
			UITheme.COLD if hot else UITheme.LINE, 0, 0, 0))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER:
			dress(true)
		elif what == NOTIFICATION_MOUSE_EXIT:
			dress(false)

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if on_open.is_valid():
			on_open.call(index)
		accept_event()




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


## Every untaken option in this system, side by side.
##
## The screen used to run this loop itself and add one child per option; it is
## here because it is a picture, and because the exclusive-set bracket below has
## to be laid out ALONGSIDE the loose options rather than above them.
static func option_row(n: MapGen.MapNode, left: Array,
		on_open: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var placed: Dictionary = {}
	for i in left:
		var opt := OptionTable.by_id(n.options[i])
		var g := StringName(opt.get("group", &""))
		if g == &"":
			row.add_child(option_card(i, opt, on_open))
			continue
		if placed.has(g):
			continue
		placed[g] = true
		row.add_child(group_strip(n, g, left, on_open))
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
static func option_card(i: int, opt: Dictionary, on_open: Callable) -> Control:
	var card := OptionCard.new()
	card.index = i
	card.on_open = on_open
	card.edge = tag_colour(opt)
	card.dress(false)
	var lane := HBoxContainer.new()
	lane.add_theme_constant_override("separation", 0)
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# WHAT KIND OF THING THIS IS, at two pixels. An untagged option gets `LINE`
	# back, which is the frame's own colour -- so no tag draws no stripe rather
	# than drawing a grey one that means nothing.
	var tag := ColorRect.new()
	tag.color = card.edge
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
	var nm := UITheme.body(String(opt.get("title", "")).to_upper(),
		UITheme.ICE, UITheme.FS_SMALL)
	# WRAPPED, NOT CLIPPED. A fixed name column is what the bar had, and a long
	# title lost its last word to it. A card is as tall as it needs to be.
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(nm)
	var lead := UITheme.body(first_sentence(String(opt.get("body", ""))),
		UITheme.COLD, UITheme.FS_SMALL)
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lead.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(lead)
	pad.add_child(col)
	card.add_child(lane)
	return card



## An exclusive set, bracketed.
##
## RULING 1: you see what a choice forecloses while you are still deciding. It
## is a border and two words rather than a box with a caption, because it is
## competing for room with the options it contains.
static func group_strip(n: MapGen.MapNode, g: StringName, left: Array,
		on_open: Callable) -> Control:
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var members := 0
	for i in left:
		var opt := OptionTable.by_id(n.options[i])
		if StringName(opt.get("group", &"")) != g:
			continue
		members += 1
		inner.add_child(option_card(i, opt, on_open))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.add_child(UITheme.body("ONE ONLY", UITheme.EMBER, UITheme.FS_SMALL))
	col.add_child(inner)
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel",
		UITheme.flat(Color(0, 0, 0, 0), UITheme.EMBER.darkened(0.5), 0, 4, 5))
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# IT TAKES THE ROOM ITS MEMBERS WOULD HAVE. Every card in the row expands
	# into an equal share, so a bracket holding two of them beside one loose
	# option would come out the same width as that option and squeeze both of
	# its own to half size -- the exclusive pair reading as the SMALL choice.
	wrap.size_flags_stretch_ratio = float(maxi(1, members))
	wrap.add_child(col)
	return wrap



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

## PRIORITY, NOT AUTHORING ORDER. This read the option's own `tags` array and
## returned on the first one it recognised, so `[signal, fight]` came out cyan
## and `[fight, signal]` came out red -- the same option two colours depending
## on which word got typed first. A fight is the fact that changes what you
## would do about the thing, so it outranks whatever else is true of it.
static func tag_colour(opt: Dictionary) -> Color:
	var tags: Array = opt.get("tags", [])
	for want in [&"fight", &"salvage", &"signal", &"contract"]:
		for t in tags:
			if StringName(t) == want:
				match want:
					&"fight": return UITheme.LEAVE
					&"salvage": return Color("#9a7b52")
					&"signal": return Color("#8ec8e6")
					_: return TAG_CONTRACT
	return UITheme.LINE
static func choice_button(n: MapGen.MapNode, i: int, j: int, c: Dictionary,
		opt: Dictionary, on_take: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	var b := Widgets.button(String(c.get("label", "…")).to_upper(),
		func() -> void: on_take.call(i, j))
	b.custom_minimum_size = Vector2(150, 22)
	# RULING 8: an unaffordable hard gate greys and says by how much. A gate is a
	# meter payment and 40 credits genuinely is not 60 -- but a disabled thing
	# still says what it wants and how far off you are.
	var note := ""
	var tone := UITheme.COLD
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
			b.disabled = true
			tone = UITheme.FLARE
	elif c.has("cost_credits"):
		var cost := int(c.cost_credits)
		note = "%d credits · you have %d" % [cost, Run.credits]
		if Run.credits < cost:
			b.disabled = true
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
	col.add_child(b)
	if note != "":
		col.add_child(UITheme.body(note, tone, UITheme.FS_SMALL))
	return col


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
