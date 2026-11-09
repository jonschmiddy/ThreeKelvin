class_name EventScreen
extends Control

## Narrative nodes. Choices should interact with your build and economy rather
## than being coin flips.

var _title: Label
var _body: Label
var _options: VBoxContainer
var _result: VBoxContainer
var _event: Dictionary
var _resolved: bool = false
## Held while a claim is in the air, so a double-click cannot commit twice.
var _claiming: bool = false
var _then_fight: bool = false
## What that fight brings: the event's creature tag, or &"" for a ship.
var _then_foe: StringName = &""
## The prize popup, while it is up. One at a time, like the sector's.
var _transfer: TransferView = null
## CONTINUE is held while a crate sits unopened; kept, since the result is built once.
var _go: Button = null

func setup(event: Dictionary) -> void:
	_event = event
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()

func _build() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var section := VBoxContainer.new()
	section.custom_minimum_size = Vector2(620, 0)
	section.add_theme_constant_override("separation", 10)
	_title = UITheme.body("", UITheme.ICE, UITheme.FS_HEAD)
	section.add_child(_title)
	_body = UITheme.body("", UITheme.CHILL, UITheme.FS_BODY)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(_body)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 6)
	section.add_child(_options)
	_result = VBoxContainer.new()
	_result.add_theme_constant_override("separation", 10)
	section.add_child(_result)
	centre.add_child(Widgets.panel_with(section))

func _refresh() -> void:
	_title.text = _event.title
	_body.text = _event.body
	Widgets.clear(_options)
	Widgets.clear(_result)
	if _resolved:
		return
	var options: Array = _event.options
	for i in options.size():
		var opt: Dictionary = options[i]
		var b := Widgets.button(opt.label, _choose.bind(i))
		b.custom_minimum_size = Vector2(0, 36)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_options.add_child(b)
		# The badge goes under its option: the label is what you do, the badge is what it takes.
		if opt.has("check"):
			var chk: Dictionary = opt.check
			var badge := UITheme.body(SkillCheck.badge(chk),
				SkillCheck.badge_colour(chk), UITheme.FS_SMALL)
			var pad := MarginContainer.new()
			pad.add_theme_constant_override("margin_left", 8)
			pad.add_theme_constant_override("margin_bottom", 4)
			pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pad.add_child(badge)
			_options.add_child(pad)

func _choose(index: int) -> void:
	if _resolved or _claiming:
		return
	# Ask the party first, as `SectorScreen._take` does; the claim lands when a choice commits.
	_claiming = true
	var won_it: bool = await Router.claim_open_option()
	_claiming = false
	if not won_it:
		Run.log_line("Too late. Somebody in the party got there first.", &"them")
		Router.event_resolved(MapGen.R_GONE)
		Router.after_event()
		return
	var opt: Dictionary = _event.options[index]
	# Checked options carry four callables and no `effect`; both shapes stay legal.
	var band := SkillCheck.Band.MET
	var call: Callable = opt.get("effect", Callable())
	if opt.has("check"):
		band = SkillCheck.roll(opt.check)
		call = SkillCheck.pick_outcome(opt, band)
	# what is on the pile before the choice runs, so REWARD can ask what arrived
	var pile_was := OptionResolve.pile_now(Run.node_at())
	var ledger_was := Run.ledger()
	var slot := Router._open_option
	var outcome: Dictionary = call.call() if call.is_valid() else {}
	# Consume the node here, not on hail, so quitting at the options costs nothing.
	Router.event_resolved(SkillCheck.band_result(band) if opt.has("check") \
		else MapGen.R_DONE)
	_resolved = true
	# This screen silently dropped `module = true` pay; `salvage_rights` paid nothing through here.
	# Why: docs/why/EventScreen.md#option-rewards
	OptionTable.pay(outcome, Run.node_at(), StringName(_event.get("id", &"")))
	# an event quest taken: what it paid, for the QUESTS table (`OptionResolve.take`)
	var here := Run.node_at()
	var names: Array = []
	for it in OptionResolve.pile_now(here):
		if not pile_was.has(it):
			names.append(String(OptionResolve._thing(it, true).name))
	Run.finish_event_quest(here, slot, int(Run.credits) - int(ledger_was.credits), names)
	_then_fight = bool(outcome.get("fight", false))
	# the option's tag rides in on `setup` (`Router.show_option_at`); a choice's own wins
	_then_foe = OptionTable.fight_foe(_event, opt)
	_refresh()
	var panel := PanelContainer.new()
	var edge := SkillCheck.band_colour(band) if opt.has("check") else UITheme.EMBER
	var sb := UITheme.flat(UITheme.PANEL2, edge, 0, 9, 11)
	sb.border_width_left = 2
	panel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	# Name the band above the prose: the fiction never says failed, so bands look alike.
	if opt.has("check"):
		col.add_child(UITheme.body(SkillCheck.band_name(band), edge, UITheme.FS_SMALL))
	var said := String(outcome.get("text", ""))
	# Do not name what it paid: REWARD below shows it, and a bracketed name cannot be picked up.
	var text := UITheme.body(said, UITheme.HOT, UITheme.FS_BODY)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	panel.add_child(col)
	_result.add_child(panel)
	if Run.dead:
		_result.add_child(Widgets.button("…", func(): Router.show_game_over()))
		return
	# Say where the paid module went: it used to land on the system's floor with no word.
	# Why: docs/why/EventScreen.md#prize-door
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	# One count drives both buttons: REWARD greys on it, CONTINUE holds on it.
	# Anything that landed on the pile, not `module` alone (`OptionResolve.shows_reward`).
	var pays := OptionResolve.pile_gained(Run.node_at(), pile_was) > 0
	var left := 0
	if pays:
		var n2: MapGen.MapNode = Run.node_at()
		left = Run.jetsam_left(n2, Run.sector_jetsam(n2, false))
	if pays:
		var claim := Widgets.button("REWARD", _open_prize)
		claim.custom_minimum_size = Vector2(120, 22)
		# Stays put and greys, as a vanishing button moves CONTINUE from under your hand.
		claim.disabled = left <= 0
		claim.tooltip_text = Widgets.tip("Shows your hold beside what this left you. Anything you do not take stays in this system, under SECTOR LOOT."
			if left > 0 else "You have taken everything this left you.")
		row.add_child(claim)
	_go = Widgets.button("CONTINUE", _continue)
	# HELD UNTIL YOU HAVE LOOKED, and only while there is something to look at.
	if left > 0:
		_go.disabled = true
		_go.tooltip_text = Widgets.tip("There is something in REWARD. Open it before you go. Anything you leave stays in this system.")
	row.add_child(_go)
	_result.add_child(row)


## What this event paid, on the system's floor: one pile per system, jetsam once you leave.
func _open_prize() -> void:
	if _transfer != null:
		return
	var n: MapGen.MapNode = Run.node_at()
	if n == null:
		return
	var h := Run.sector_jetsam(n, false)
	if h == null:
		return
	_transfer = TransferView.new()
	add_child(_transfer)
	_transfer.setup(h, n, _close_transfer, true, "REWARD")


func _close_transfer() -> void:
	if _transfer == null:
		return
	_transfer.queue_free()
	_transfer = null
	# You have seen it. Whether you took it is your business.
	if _go != null:
		_go.disabled = false

func _continue() -> void:
	if _then_fight:
		Router.start_ambush(_then_foe)
	else:
		Router.after_event()
