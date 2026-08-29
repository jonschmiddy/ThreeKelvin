class_name Widgets
extends RefCounted

## Shared UI building blocks. Everything is built in code so there is one
## source of truth for how a module row or a stat readout looks.

## CARGO is the hold anywhere; HOLD is the hold WITH A BUYER STANDING THERE.
## They are separate because the verbs differ by exactly one — a station can be
## sold to and deep space cannot — and folding them together would mean the
## SCRAP button either quoting a sale price nobody is offering or hiding one
## that is.
enum ModuleContext { CARGO, INSTALLED, SHOP, HOLD, BAG }

## A module entry: name, rarity, manufacturer, rolled affixes, and its cards.
##
## `note` is for a row whose action has already been taken by somebody else. It
## replaces the button rather than removing it, because a row that loses its
## button changes height and the list reflows under the cursor — and because
## "MERCER TOOK THIS" is the single most interesting thing the bag has to say.
## Empty for every other context, which is all of them but BAG.
## A row for whatever is in the hold, whichever kind it is.
##
## THE ONE PLACE THIS IS DECIDED. Three screens iterate `Run.cargo` and build a
## row per entry, and every one of them called `module_row` directly -- which was
## correct right up until cargo held two kinds of thing, and then failed at the
## parameter type on the first crate. A private branch on each screen would be
## the same bug waiting on the fourth.
static func item_row(thing: Variant, ctx: ModuleContext, price: int,
		on_action: Callable, note: String = "",
		deck_size: int = -1) -> PanelContainer:
	if thing is MaterialData:
		return material_row(thing as MaterialData, ctx, price, on_action, note)
	return module_row(thing as ModuleData, ctx, price, on_action, note,
		deck_size)


## One material, as a row.
##
## NOT a branch inside `module_row`. That function reads a rarity, a
## manufacturer, a slot, an affix list and a card count -- five things a crate of
## ore does not have and never will -- so folding materials into it would be
## threading nulls through every one of them to save a panel.
##
## What it shares is the SHAPE: same stylebox, same name-and-grade top line, same
## button strip on the right, so a bag holding a gun and a crate reads as one
## list rather than as two.
static func material_row(m: MaterialData, ctx: ModuleContext, price: int,
		on_action: Callable, note: String = "") -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := UITheme.flat(UITheme.PANEL2, UITheme.LINE, 0, 8, 10)
	sb.border_width_left = 3
	# The tier, on the edge, where the manufacturer's colour sits on a module.
	# Both answer "what sort of thing is this" at a glance down a list.
	sb.border_color = UITheme.tier_colour(m.tier)
	panel.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	top.add_child(UITheme.body(m.name, UITheme.ICE, UITheme.FS_BODY))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UITheme.body(String(m.tier).to_upper(),
		UITheme.tier_colour(m.tier), UITheme.FS_SMALL))

	# The two facts a decision turns on: what it costs you in room, and what it
	# is worth when you find somewhere to sell it.
	box.add_child(UITheme.body("%d x %d · sells for %d"
		% [m.size.x, m.size.y, m.value], UITheme.COLD, UITheme.FS_SMALL))
	var blurb := UITheme.body(m.text, UITheme.CHILL, UITheme.FS_SMALL)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(blurb)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)
	if ctx == ModuleContext.BAG:
		if note != "":
			var gone := _btn(note, on_action.bind("noop", m))
			gone.disabled = true
			buttons.add_child(gone)
		else:
			var take := _btn("TAKE", on_action.bind("take", m))
			take.tooltip_text = tip("Into your hold, if there is room for it.")
			buttons.add_child(take)
	return panel


static func module_row(m: ModuleData, ctx: ModuleContext, price: int,
		on_action: Callable, note: String = "", deck_size: int = -1) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := UITheme.flat(UITheme.PANEL2, UITheme.LINE, 0, 8, 10)
	sb.border_width_left = 3
	sb.border_color = DB.manufacturer_colour(m.manufacturer)
	if m.contraband:
		sb.border_color = Color("#d4614f")
	panel.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	top.add_child(UITheme.body(m.name, UITheme.ICE, UITheme.FS_BODY))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UITheme.body(ModuleData.rarity_name(m.rarity),
		ModuleData.rarity_ink(m.rarity), UITheme.FS_SMALL))

	# Grants is a STAT, printed like one. The Grant Count Law only does its job
	# if the count is visible at the point of choice — a law nobody can see is
	# just a rule the designer knows.
	var meta := "%s · %s · grants %d" % [DB.manufacturer_name(m.manufacturer),
		ModuleData.slot_name(m.slot), m.grant_count()]
	if m.contraband:
		meta += " · CONTRABAND"
	box.add_child(UITheme.body(meta, UITheme.COLD, 10))

	for a in m.affixes:
		box.add_child(UITheme.body("%s: %s" % [a.name, a.text], Color("#d4b98f"), 10))

	for c in m.resolved_cards():
		var line := "×1  %s · %dnrg%s · %s" % [
			c.name, c.energy,
			"" if c.heat == 0 else " · %dheat" % c.heat,
			c.describe(),
		]
		box.add_child(UITheme.body(line, UITheme.CHILL, 10))

	# Install-time deck delta, at the point of choice.
	#
	# Deck size is a managed resource and this is the only moment the player can
	# act on it, so the number moves where they can see it move — the same
	# philosophy as printing the odds on an event option before they commit.
	# Without it the Grant Count Law is invisible: you would feel a thickening
	# deck three fights later and never know which pickup did it.
	# Passed in, not rebuilt. DeckBuilder.build() deep-duplicates every card on
	# every installed module and allocates two Snap Shots plus one per Dross —
	# and this ran ONCE PER ROW, so a station with twenty rows on screen did
	# twenty full deck builds to answer the same question twenty times. The
	# callers below already loop, so they compute it once and hand it down.
	var here := deck_size if deck_size >= 0 else DeckBuilder.build().size()
	var delta := 0
	if ctx == ModuleContext.INSTALLED:
		delta = -m.grant_count()
	else:
		# Every other context ends with the part fitted: cargo, shop stock and
		# the hold at a station all read the deck AFTER installing it.
		delta = m.grant_count()
		# A swap into a full rack takes the displaced module's cards with it.
		if Run.slots_used(m.slot) >= Run.slots_for(m.slot):
			for inst in Run.installed:
				var im: ModuleData = inst
				if im.slot == m.slot:
					delta -= im.grant_count()
					break
	if delta != 0:
		var arrow := "deck %d → %d" % [here, here + delta]
		box.add_child(UITheme.body(arrow,
			UITheme.THEM if delta > 0 else UITheme.GOOD, 10))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 5)
	box.add_child(buttons)
	match ctx:
		ModuleContext.CARGO:
			var full := Run.slots_used(m.slot) >= Run.slots_for(m.slot)
			buttons.add_child(_btn("SWAP IN" if full else "INSTALL",
				on_action.bind("install", m)))
			buttons.add_child(_scrap_button(m, on_action))
		ModuleContext.HOLD:
			var full2 := Run.slots_used(m.slot) >= Run.slots_for(m.slot)
			buttons.add_child(_btn("SWAP IN" if full2 else "INSTALL",
				on_action.bind("install", m)))
			# `price` is the local bid. Zero means this station will not touch
			# it, which is only ever contraband in policed space — so the button
			# says why rather than vanishing and leaving the player to wonder
			# whether the part is broken.
			if price > 0:
				var sell := _btn("SELL +%d" % price, on_action.bind("sell", m))
				sell.tooltip_text = tip("What this market pays. A manufacturer's own yard is thick with its own parts; a rival's yard is short of them.")
				buttons.add_child(sell)
			else:
				var refused := _btn("WILL NOT BUY", on_action.bind("noop", m))
				refused.disabled = true
				refused.tooltip_text = tip("Illegal here. Fences in lawless space pay over the odds for it.")
				buttons.add_child(refused)
			buttons.add_child(_scrap_button(m, on_action))
		ModuleContext.INSTALLED:
			buttons.add_child(_btn("REMOVE", on_action.bind("uninstall", m)))
		ModuleContext.SHOP:
			var b := _btn("BUY %d" % price, on_action.bind("buy", m))
			b.disabled = Run.credits < price
			buttons.add_child(b)
		ModuleContext.BAG:
			if note != "":
				var gone := _btn(note, on_action.bind("noop", m))
				gone.disabled = true
				gone.tooltip_text = tip("One bag, and somebody else got here first.")
				buttons.add_child(gone)
			else:
				var take := _btn("TAKE", on_action.bind("take", m))
				# Said out loud, because the cost of pressing it is that nobody
				# else can. A race is only fair if both players know it is one.
				take.tooltip_text = tip("Into your hold, and out of everybody else's reach. One bag, first hand in.")
				buttons.add_child(take)
	return panel

## "SCRAP +14". No materials on it any more, because scrapping no longer yields
## any: it used to read "SCRAP +14 · 2 ALLOY", and the alloy was the half that
## made a part into a second currency.
static func _scrap_button(m: ModuleData, on_action: Callable) -> Button:
	var b := _btn("SCRAP +%d" % Run.scrap_value_of(m), on_action.bind("scrap", m))
	b.tooltip_text = tip("Break it down where you stand. The floor under every part — no station and no route needed.")
	return b

static func hull_row(h: HullData, label: String, price: int,
		on_action: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := UITheme.flat(UITheme.PANEL2, UITheme.LINE, 0, 8, 10)
	sb.border_width_left = 3
	sb.border_color = Color("#d99b29")
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	top.add_child(UITheme.body(h.display_name(), UITheme.ICE, UITheme.FS_BODY))
	if price > 0:
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(sp)
		top.add_child(UITheme.body("%d credits" % price, Color("#d99b29"), UITheme.FS_SMALL))

	box.add_child(UITheme.body(
		"%s · %d nrg · hand %d · %d hull · heat %d/%d · slots %d/%d/%d" % [
			HullData.weight_name(h.weight), h.reactor, h.hand_size, h.max_hull,
			h.heat_cap, h.dissipation, h.weapon_slots, h.system_slots, h.utility_slots,
		], UITheme.COLD, 10))
	# EVERY PERK, not just the manufacturer's. This is the card you decide to BUY a
	# hull from, and an S-tier carries four -- showing one understated the
	# offer by three and the player had no way to find the rest.
	for pid in h.perks():
		box.add_child(UITheme.body(DB.perk_text(pid), Color("#d4b98f"), 10))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 5)
	box.add_child(buttons)
	var take := _btn(label, on_action.bind("take_hull", h))
	if price > 0:
		take.disabled = Run.credits < price
	buttons.add_child(take)
	if price == 0:
		buttons.add_child(_btn("LEAVE IT", on_action.bind("leave_hull", h)))
	return panel

static func _btn(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	# Sound before action. Every button in the game is built here, so this is
	# the one place the interface needs wiring — and the action is usually a
	# screen swap, so the click has to be queued before the tree changes.
	b.pressed.connect(Audio.click)
	b.mouse_entered.connect(Audio.hover)
	b.pressed.connect(action)
	# A disabled button never emits `pressed`, so clicking one is completely
	# silent — indistinguishable from the game not registering the click. It
	# did register it. The answer is no, and the interface should say so.
	b.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and b.disabled:
			Audio.denied())
	return b

static func button(text: String, action: Callable) -> Button:
	return _btn(text, action)

## Label + value readout used in the HUD and unit panels.
static func stat(key: String, value: String, value_colour: Color = UITheme.ICE) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UITheme.body(key.to_upper(), UITheme.COLD, UITheme.FS_SMALL))
	var v := UITheme.body(value, value_colour, UITheme.FS_SMALL)
	v.name = "Value"
	row.add_child(v)
	return row

static func chip(text: String, colour: Color = UITheme.LINE) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UITheme.flat(Color(0, 0, 0, 0), colour, 2, 2, 6)
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(UITheme.body(text, UITheme.CHILL, 10))
	return p

static func section(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(UITheme.header(title))
	box.add_child(UITheme.hsep())
	return box

## Empty a container NOW, not at the end of the frame.
##
## queue_free() is DEFERRED. So the common `for c in box.get_children():
## c.queue_free()` followed immediately by add_child() leaves the container
## holding the old children AND the new ones until the frame ends, and it is
## laid out at that doubled size in between.
##
## Usually invisible — a column of text rows is briefly too tall inside a panel
## that clips it. It was very visible on the refit screen: that grid is 44px
## module icons, it is rebuilt synchronously from the drop handler, and nothing
## in the layout clips, so putting a part in the hold splashed a surplus row of
## icons across the screen underneath for a frame.
##
## Ten other screens still free deferred this way. They are not known to misdraw;
## this is here so the next one written has the right thing to call.
static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

## Tooltip text, hard-wrapped so every tooltip in the game is the same shape.
##
## The theme gives TooltipPanel its padding and its plate, but Godot still
## sizes the panel to whatever the text asks for — so a long line makes a
## tooltip most of the viewport wide and a short one makes a sliver. A Label
## inside a themed TooltipPanel cannot be handed an autowrap mode from the
## theme, so the wrap has to happen in the STRING, before it is assigned.
##
## Breaks on spaces and preserves newlines already in the text, so a tooltip
## written as "NAME\nbody" keeps its heading and only the body folds.
static func tip(text: String) -> String:
	var out: PackedStringArray = []
	for para in text.split("\n"):
		var line := ""
		for word in (para as String).split(" "):
			if line == "":
				line = word
			elif line.length() + 1 + (word as String).length() <= UITheme.TOOLTIP_WRAP:
				line += " " + word
			else:
				out.append(line)
				line = word
		out.append(line)
	return "\n".join(out)

## A child in a margin. The fourth copy of this was written before it became
## obvious it wanted to live here.
##
## Four screens had grown a private `_pad()` — LobbyScreen, PartyScreen, and
## StationScreen twice, since it needed two margin sizes in one file and had no
## way to say so. They differed only in the two numbers, which is the definition
## of an argument rather than a fork.
##
## Horizontal first, because it is the one that varies: every caller so far wants
## more air at the sides than at the top.
## `child` is OPTIONAL, because half the call sites build the margin before they
## build what goes in it — they anchor it, set a mouse filter, park it in the
## tree, and only then assemble the column. Passing null gives them the same
## configured container to fill in later, which is what let the remaining nine
## hand-rolled copies come here instead of being restructured around a signature
## that only suited the other half.
static func pad(child: Control = null, h: int = 8, v: int = 6) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, h)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, v)
	if child != null:
		m.add_child(child)
	return m

static func panel_with(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 12, 12))
	p.add_child(child)
	return p

static func scroller(child: Control, min_height: int = 200) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size = Vector2(0, min_height)
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s

## Name, what it is, where it came from, and what its rules words mean.
##
## Shared by the card gallery and by combat. A keyword you can only look up on a
## development screen is a keyword the player has to have memorised, which is
## the exact thing a glossary exists to prevent.
##
## Deliberately NOT a field dump. An earlier version printed every non-default
## property on the card, which was self-maintaining and useless: it told you
## `feedback: 4` when what you needed was what feedback does. The numbers are
## already on the card face — this panel exists for the things the card has no
## room to say.
static func card_readout(c: CardData) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 7, 8)
	sb.border_width_left = 3
	sb.border_color = DB.manufacturer_colour(c.manufacturer)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(178, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	# The two NAMES first, then the two CLASSIFICATIONS. What the card is called
	# and what granted it are the pair you are looking for; type, rarity, manufacturer
	# and slot are all the same kind of fact and belong together underneath,
	# rather than interleaved so that the eye crosses a category line twice.
	# Two pairs. What the CARD is — its verb and its class — then where it came
	# FROM — the manufacturer and the module. Each pair is a name over its
	# classification, and the two questions never interleave.
	var mod: ModuleData = DB.modules.get(c.source_id)
	var rare := ModuleData.rarity_ink(c.source_rarity)
	box.add_child(UITheme.body(c.name.to_upper(), rare, UITheme.FS_SMALL))
	box.add_child(UITheme.body("%s · %s" % [c.type_name().to_upper(),
		ModuleData.rarity_name(c.source_rarity).to_upper()],
		UITheme.COLD, UITheme.FS_SMALL))
	if mod != null:
		# The manufacturer in its own colour. It is the only line in the panel that
		# names a manufacturer, and it already owns a colour everywhere else on
		# the card — the banner, the emblem, the border down the left of this
		# very panel. Printing it in cold grey was the one place the manufacturer went
		# unbranded.
		box.add_child(UITheme.body(
			DB.manufacturer_name(mod.manufacturer).to_upper(),
			DB.manufacturer_colour(mod.manufacturer), UITheme.FS_SMALL))
		# Unless the module is the card. Junk and hull-innate cards are named
		# after their own source, so printing both put DROSS over DROSS — a line
		# that answers a question nobody asked twice.
		if mod.name.to_upper() != c.name.to_upper():
			box.add_child(UITheme.body(mod.name.to_upper(),
				UITheme.ICE, UITheme.FS_SMALL))

	var terms := c.keywords()
	if not terms.is_empty():
		box.add_child(UITheme.hsep())
	for raw in terms:
		var pair: Array = raw
		box.add_child(UITheme.body(String(pair[0]).to_upper(),
			UITheme.ICE, UITheme.FS_SMALL))
		var def := UITheme.body(String(pair[1]), UITheme.COLD, UITheme.FS_SMALL)
		def.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		def.custom_minimum_size = Vector2(168, 0)
		box.add_child(def)

	# The quote last, in its own section.
	#
	# It was sitting with the module's name and slot, where it read as another
	# specification — and flavour next to specifications always loses, because
	# the eye is scanning for facts and finds a sentence in the middle of them.
	# At the bottom, after the rules are answered, it is the thing you read once
	# you have finished needing the panel.
	if mod != null and mod.flavour != "":
		box.add_child(UITheme.hsep())
		# Silkscreen at 8, like everything else — the grey is the whole signal.
		#
		# A second typeface was tried for this and it was the wrong tool. At
		# this resolution a different face does not read as a different VOICE,
		# it reads as a different UI, because there is not enough letterform
		# left at 8px for character to survive. Colour still works perfectly
		# well down here, and it costs no asset, no licence and no size guess.
		var fl := UITheme.body("\"%s\"" % mod.flavour, UITheme.QUOTE, UITheme.FS_SMALL)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size = Vector2(168, 0)
		box.add_child(fl)
	return panel

## One manufacturer ability: what it costs, what it is called, what it does.
##
## Shared by the chassis select and the refit screen, because they are asking
## the same question at two different moments — "what would flying this manufacturer
## give me" and "how close am I now" — and two copies of the row would drift the
## first time either one was reworded.
##
## The condition column says it in full ("3+ KORVAN") rather than a bare "3+",
## which leaves you to work out three of what. The hull perk shares that column
## with "BUILT IN": the other two name what you must collect, so this one names
## where it already is.
##
## Locked rows are dimmed rather than hidden. What a manufacturer is FOR is
## mostly what it does at 3 and 5 parts, so hiding those until you get there
## would hide the reason to chase them — greying says "later", which is the
## actual state.
## `count` is the progress column — "2 / 3" — and it is why the set chips are
## gone from the hardpoints header. A chip reading "KORVAN 2" told you what you
## have and left you to remember what you need; the number belongs on the row
## that states the thing it unlocks.
static func ability_row(at: String, title: String, text: String, accent: Color,
		unlocked: bool, count: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var tag := UITheme.body(at, accent if unlocked else UITheme.COLD, UITheme.FS_SMALL)
	tag.custom_minimum_size = Vector2(84, 0)
	row.add_child(tag)
	var have := UITheme.body(count, accent if unlocked else UITheme.CHILL,
		UITheme.FS_SMALL)
	have.custom_minimum_size = Vector2(40, 0)
	row.add_child(have)
	var name_label := UITheme.body(title.to_upper(),
		UITheme.ICE if unlocked else UITheme.COLD, UITheme.FS_SMALL)
	name_label.custom_minimum_size = Vector2(112, 0)
	row.add_child(name_label)
	var what := UITheme.body(text, UITheme.COLD if unlocked else UITheme.QUOTE,
		UITheme.FS_SMALL)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(what)
	return row

## The three ability rows for a manufacturer, given a live set count and the
## hull's own perk. Built as a list so a caller can drop them into whatever
## container it has.
static func ability_rows(manufacturer: StringName, perk_id: StringName, have: int) -> Array:
	var out: Array = []
	var m: ManufacturerData = DB.manufacturers.get(manufacturer)
	if m == null:
		return out
	# THE PERK ROW IS GONE FROM HERE. It is named in the masthead's top-right
	# corner now, with its effect on hover — and a hull can carry four of them,
	# so four full-width rows of always-on fact would have crowded out the two
	# rows that are actually a TRACKER. What is left in this block is only
	# progress: what you have not earned yet and how close you are.
	#
	# `perk_id` stays in the signature. Every caller has one, the argument costs
	# nothing, and a block about a manufacturer that cannot see the hull's perk
	# is the wrong shape to hand the next person.
	var short := DB.short_name(m.name).to_upper()
	out.append(ability_row("3+ %s" % short, m.set3_name, m.set3_text,
		m.colour, have >= 3, "%d / 3" % have))
	out.append(ability_row("5+ %s" % short, m.set5_name, m.set5_text,
		m.colour, have >= 5, "%d / 5" % have))
	return out


## THE MODULE'S OWN PANEL, built like card_readout so a part and a card look
## like two things from the same game.
##
## It carries what a part IS and nothing about what its cards DO, because the
## cards are drawn beside it — see ModuleIcon._make_custom_tooltip. A panel that
## also spelled out the effects would be describing the two objects sitting
## right next to it, which is how the module gallery ended up with three copies
## of the same facts before the readout panel was deleted.
##
## Same left border in the manufacturer colour, same width, same order of facts: what
## it is called, then what class of thing it is, then the flavour last. Flavour
## next to specifications always loses — the eye is scanning for facts and finds
## a sentence in the middle of them.
## `width` FIXES the box rather than merely floors it.
##
## custom_minimum_size is a minimum, so a long name pushed the panel wider
## than a card and every row in a column of these started at a different
## place — a KH-20 Chatterbox against a Mining Laser was 40px of difference.
## Passing a width clamps it too and lets the text wrap inside instead.
static func module_readout(m: ModuleData, width: float = 0.0) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 7, 8)
	sb.border_width_left = 3
	sb.border_color = DB.manufacturer_colour(m.manufacturer)
	panel.add_theme_stylebox_override("panel", sb)
	# A CARD'S WIDTH, so the three boxes are one object rather than a wide panel
	# with two cards stuck to it. card_readout is 178 because it stands alone at
	# the cursor; this one stands in a row of cards and has to belong to it.
	var w := width if width > 0.0 else float(CardView.CARD_W)
	panel.custom_minimum_size = Vector2(w, 0)
	if width > 0.0:
		# SHRINK_BEGIN so the parent row cannot stretch it past the minimum;
		# together they make the minimum an exact size.
		panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var nm := UITheme.body(m.name.to_upper(),
		ModuleData.rarity_ink(m.rarity), UITheme.FS_SMALL)
	if width > 0.0:
		# The name is the only line long enough to set the width, so it is the
		# only one that has to be allowed to wrap.
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size = Vector2(0, 0)
	box.add_child(nm)
	var f := m.footprint()
	box.add_child(UITheme.body("%s \u00b7 %s" % [
		ModuleData.rarity_name(m.rarity).to_upper(),
		ModuleData.slot_name(m.slot).to_upper()], UITheme.COLD, UITheme.FS_SMALL))
	var mk := UITheme.body("%s" % (DB.manufacturer_name(m.manufacturer)
		if m.manufacturer != &"" else "Unbranded"),
		DB.manufacturer_colour(m.manufacturer), UITheme.FS_SMALL)
	if width > 0.0:
		# THE MANUFACTURER LINE IS THE WIDEST, not the name: "KORVAN HEAVY WORKS"
		# is three characters longer than "KH-20 CHATTERBOX". Wrapping only
		# the name left this one setting the width and the column ragged.
		mk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(mk)
	box.add_child(UITheme.body("%dx%d \u00b7 %d %s" % [f.x, f.y, m.cells(),
		"cell" if m.cells() == 1 else "cells"], UITheme.CHILL, UITheme.FS_SMALL))

	# WHAT IT DOES TO THE SHIP, which is the half of a part that is not cards and
	# which nothing showed until the tooltip was rewritten. A legendary carrying
	# three pips of hull said nothing about them anywhere.
	# ZERO IS NOT PRINTED, reversing the ruling that used to sit here. That
	# ruling was that "HULL +0" on a common plate keeps the LADDER legible — it
	# says the part is on the hull axis and simply pays nothing at this grade,
	# where a part with no axis at all says nothing. True, and it cost more than
	# it bought: ATTR_BUMP is [0, 0, 1, ...], so EVERY common and EVERY uncommon
	# part in the game printed a line that reads as a fact about the part and
	# means "not yet". Two thirds of the catalogue wearing a +0.
	#
	# WHAT THIS GIVES UP, stated because it will be rediscovered otherwise: a
	# common plate and a Ripsaw now read identically in this box, and the only
	# way to tell that one is on the hull ladder is to find a better one. The
	# manifest still prints its +0 and draws it dashed, so the information is
	# not gone from the project, only from the hover.
	var gauges: Array = []
	for axis in DB.PASSIVE_AXIS.get(m.id, []):
		var pips: int = DB.ATTR_BUMP[int(m.rarity)]
		if pips == 0:
			continue
		gauges.append(["%s +%d" % [String(axis).to_upper(), pips],
			UITheme.ICE])
	if DB.PASSIVE_COST.has(m.id):
		var row: Array = DB.PASSIVE_COST[m.id]
		gauges.append(["%s \u2212%d" % [String(row[0]).to_upper(),
			int(row[1])], UITheme.LEAVE])
	if m.reactor != 0:
		gauges.append(["REACTOR +%d" % m.reactor, UITheme.ICE])
	if not gauges.is_empty():
		box.add_child(UITheme.hsep())
		for raw in gauges:
			var g: Array = raw
			box.add_child(UITheme.body(String(g[0]), g[1], UITheme.FS_SMALL))

	for a in m.affixes:
		box.add_child(UITheme.body("%s \u2014 %s" % [a.name, a.text],
			UITheme.EMBER, UITheme.FS_SMALL))

	if m.flavour != "":
		box.add_child(UITheme.hsep())
		var q := UITheme.body(m.flavour, UITheme.QUOTE, UITheme.FS_SMALL)
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q.custom_minimum_size = Vector2(CardView.CARD_W - 14, 0)
		box.add_child(q)
	return panel

## Every perk on a hull, in ONE tooltip, grouped by where it came from.
##
## Four perks used to mean four separate hovers, and no hover said whether what
## you were reading was a fact about the MANUFACTURER — carried by every hull
## they build, at every grade — or a fact about this hull's GRADE. Those are
## different things to know: one survives swapping chassis within the manufacturer,
## the other is precisely what upgrading bought.
##
## THE EMPTY CASE IS PRINTED. A C-class hull has no grade perks, and a tooltip
## that then shows only one section reads as a hull whose perks failed to load.
## Saying "none, and B/A/S each add one more" turns the same blank into the
## ladder explaining itself — which is the one moment a player is looking
## straight at the thing an upgrade would change.
static func perk_tip(h: HullData) -> String:
	if h == null:
		return ""
	var out: PackedStringArray = ["PERKS"]
	var manufacturer: ManufacturerData = DB.manufacturers.get(h.manufacturer)
	var own := _perk_line(h.perk_id)
	if own != "":
		out.append("")
		out.append(manufacturer.name.to_upper() if manufacturer != null
			else "UNBRANDED")
		out.append(own)
	out.append("")
	out.append("%s TIER" % h.tier_letter())
	var any := false
	for p in h.tier_perks:
		var line := _perk_line(p)
		if line != "":
			out.append(line)
			any = true
	if not any:
		out.append("None. B, A and S each add one more.")
	return "\n".join(out)


## "Salvage Rack — Scrapping modules pays +40%." Empty for a perk id that is
## not in the table, so a hull carrying a retired one prints nothing rather
## than a dash with a hole either side of it.
static func _perk_line(id: StringName) -> String:
	var pd: Dictionary = DB.hull_perks.get(id, {})
	if pd.is_empty():
		return ""
	return "%s \u2014 %s" % [str(pd.name), str(pd.text)]


## How wide the perk tooltip is. Named because two things need to agree on it:
## the panel, and the wrapped label inside it that would otherwise have no width
## to wrap against.
## The same perks as a PANEL, which is what actually shows on hover.
##
## `perk_tip` above is the plain-text fallback and the trigger string; this is
## the content. Built like `module_readout` and deliberately so — the border in
## the manufacturer's colour, the flat plate, the small type — because a tooltip
## that looks like the rest of the game reads as part of it, and one assembled
## out of default labels reads as debug output that shipped.
##
## TWO GROUPS, AND THE HEADINGS CARRY THE COLOUR. Which perk came from the
## manufacturer and which from the grade is the thing the old per-label tooltips
## could not say at all. The manufacturer's own is on every hull they build, at
## every grade, and survives swapping chassis inside the same manufacturer; the
## grade's are exactly what the upgrade bought, and are lost dropping back down.
static func perk_readout(h: HullData) -> VBoxContainer:
	# NO PLATE OF ITS OWN, and that is the whole of looking like the other
	# tooltips. Godot wraps whatever `_make_custom_tooltip` returns in a
	# PopupPanel styled as TooltipPanel -- `bevel(PANEL2)`, with content margins
	# already set -- so a PanelContainer here meant TWO plates: a darker
	# rectangle sitting inset inside the lighter tooltip, with both paddings
	# stacked. Removing the inner BORDER did not help, because the inner PLATE
	# was the thing being seen.
	#
	# Every plain tooltip in the game is a Label on the theme's plate. This is
	# that, with more rows. It also means the width comes from the same place
	# theirs does -- `tip()` wrapping at TOOLTIP_WRAP -- so it sits in the same
	# family of rectangles rather than being its own size.
	var accent := DB.manufacturer_colour(h.manufacturer)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	box.add_child(UITheme.body("PERKS", UITheme.COLD, UITheme.FS_SMALL))

	var manufacturer: ManufacturerData = DB.manufacturers.get(h.manufacturer)
	var own: Dictionary = DB.hull_perks.get(h.perk_id, {})
	if not own.is_empty():
		box.add_child(UITheme.hsep())
		box.add_child(UITheme.body(
			manufacturer.name.to_upper() if manufacturer != null else "UNBRANDED",
			accent, UITheme.FS_SMALL))
		_perk_rows(box, own)

	box.add_child(UITheme.hsep())
	box.add_child(UITheme.body("%s TIER" % h.tier_letter(), UITheme.ICE,
		UITheme.FS_SMALL))
	var any := false
	for p in h.tier_perks:
		var pd: Dictionary = DB.hull_perks.get(p, {})
		if pd.is_empty():
			continue
		_perk_rows(box, pd)
		any = true
	# THE EMPTY CASE IS DRAWN, for the reason `perk_tip` gives: a C hull showing
	# a heading and nothing under it reads as a failure to load, where the same
	# blank with a sentence in it is the ladder explaining itself.
	if not any:
		box.add_child(UITheme.body(tip("None yet. B, A and S each add one more."),
			UITheme.QUOTE, UITheme.FS_SMALL))
	return box


## One perk: its name, then what it does, indented under it.
##
## The name in EMBER and the effect in COLD, which is the same split the module
## readout uses for an affix — the thing you are looking for, then the thing you
## are looking it up for.
static func _perk_rows(box: VBoxContainer, pd: Dictionary) -> void:
	box.add_child(UITheme.body(str(pd.name), UITheme.EMBER, UITheme.FS_SMALL))
	# WRAPPED IN THE STRING, NOT BY THE LABEL, and that is the whole fix for a
	# tooltip that reached the bottom of the screen. An autowrapping Label
	# reports its minimum HEIGHT from its current WIDTH -- and a tooltip is
	# measured the instant it is built, before any container has handed it one.
	# Measured: this panel asked for 309 rows off-tree and settled at 168 once
	# laid out, and it is the first number a tooltip believes.
	#
	# A `custom_minimum_size.x` on the label is not enough either; that was tried
	# and it still came out at 309. `tip()` above already carries this same
	# finding for the plain tooltips -- "the wrap has to happen in the STRING"
	# -- so this uses it, and the label then measures the same on-tree and off.
	var body := UITheme.body(tip(str(pd.text)), UITheme.COLD, UITheme.FS_SMALL)
	box.add_child(pad(body, 8, 0))
