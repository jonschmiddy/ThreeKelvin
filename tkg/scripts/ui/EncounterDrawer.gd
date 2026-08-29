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


static func head(text: String, on_jump: Callable, loose: int = 0,
		on_loot: Callable = Callable()) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UITheme.body(text, UITheme.COLD, UITheme.FS_SMALL)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	if loose > 0 and on_loot.is_valid():
		var loot := Widgets.button("SECTOR LOOT - %d" % loose, on_loot)
		loot.custom_minimum_size = BTN
		loot.tooltip_text = Widgets.tip("What is loose in this system that no hull is holding: what an event paid out, and anything you have put down here. It stays until you jump.")
		row.add_child(loot)
	var b := Widgets.button("PLOT NEXT JUMP", on_jump)
	b.custom_minimum_size = BTN
	row.add_child(b)
	return row


## One condensed option: a stripe, its name, a line of body, and its hardest number.
static func list_row(n: MapGen.MapNode, i: int, opt: Dictionary,
		on_open: Callable) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 21)
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.pressed.connect(func() -> void: on_open.call(i))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var bar := ColorRect.new()
	bar.color = tag_colour(opt)
	bar.custom_minimum_size = Vector2(3, 0)
	row.add_child(bar)
	var nm := UITheme.body(String(opt.get("title", "")).to_upper(),
		UITheme.ICE, UITheme.FS_SMALL)
	nm.custom_minimum_size = Vector2(148, 0)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(nm)
	var lead := UITheme.body(first_sentence(String(opt.get("body", ""))),
		UITheme.COLD, UITheme.FS_SMALL)
	lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead.clip_text = true
	lead.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lead)
	# ALWAYS PRESENT, EVEN WHEN EMPTY. The lead above expands into whatever is
	# left, so a row with no number let its prose run further than a row with
	# one -- three rows clipping at three different x positions, which reads as
	# broken text rather than as a column. Reserving the width makes the ragged
	# edge a straight one.
	var hint := row_hint(n, opt)
	var h := UITheme.body(String(hint[0]), hint[1] as Color, UITheme.FS_SMALL)
	h.custom_minimum_size = Vector2(196, 0)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.clip_text = true
	row.add_child(h)
	return b


## The one number a condensed row is allowed.
##
## A row that printed every band would be the detail view with worse spacing, so
## it shows the hardest thing about the option: what is waiting if it opens a
## fight, else its check, else what it costs.
static func row_hint(n: MapGen.MapNode, opt: Dictionary) -> Array:
	for c in opt.get("choices", []):
		if bool((c as Dictionary).get("fight", false)):
			return [contact_reading(n).to_upper(), UITheme.THEM]
	var chk := lead_check(opt)
	if not chk.is_empty():
		# THE SHORT FORM: what it wants, and the odds. `SkillCheck.badge` also
		# carries "you have N" and "one more: X%", and both of those are for the
		# moment you are DECIDING -- in a list they overran the column and clipped
		# the attribute name off the front, which is the one part the badge exists
		# to show. The full badge is on the choice button in the OPTION state.
		return ["%s %d · %d%%" % [SkillCheck.attr_name(chk).to_upper(),
			int(chk.get("need", 0)), int(round(SkillCheck.odds(chk) * 100.0))],
			SkillCheck.badge_colour(chk)]
	for c2 in opt.get("choices", []):
		var cd := c2 as Dictionary
		if cd.has("cost_credits"):
			var cost := int(cd.cost_credits)
			return ["%d CREDITS" % cost,
				UITheme.EMBER if Run.credits >= cost else UITheme.FLARE]
	return ["", UITheme.COLD]


## An exclusive set, bracketed.
##
## RULING 1: you see what a choice forecloses while you are still deciding. In a
## drawer this has to be cheap -- a bordered strip and two words, not a box with
## a caption, because there are only a hundred and thirty-five pixels of it.
static func group_strip(n: MapGen.MapNode, g: StringName, left: Array,
		on_open: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.add_child(UITheme.body("ONE ONLY", UITheme.EMBER, UITheme.FS_SMALL))
	for i in left:
		var opt := OptionTable.by_id(n.options[i])
		if StringName(opt.get("group", &"")) != g:
			continue
		col.add_child(list_row(n, i, opt, on_open))
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.PANEL2, UITheme.EMBER.darkened(0.5), 0, 5, 2))
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
static func tag_colour(opt: Dictionary) -> Color:
	for t in opt.get("tags", []):
		match StringName(t):
			&"fight": return UITheme.LEAVE
			&"salvage": return Color("#9a7b52")
			&"signal": return Color("#8ec8e6")
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
static func lead_check(opt: Dictionary) -> Dictionary:
	var found: Dictionary = {}
	var count := 0
	for c in opt.get("choices", []):
		if not (c as Dictionary).has("check"):
			continue
		count += 1
		found = (c as Dictionary).check
	return found if count == 1 else {}


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
