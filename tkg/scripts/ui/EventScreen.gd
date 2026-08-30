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
var _then_fight: bool = false
## The prize popup, while it is up. One at a time, like the sector's.
var _transfer: TransferView = null

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
		# The badge goes UNDER its option, not inside the label. It is a
		# different kind of statement — the label is what you would be doing, the
		# badge is what it would take — and running them together made options
		# read as sentences with numbers stuck on the end.
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
	var opt: Dictionary = _event.options[index]
	# Checked options carry four callables and no `effect`; plain ones are
	# unchanged. Both shapes are legal so the existing events did not have to be
	# rewritten to add checks to new ones.
	var band := SkillCheck.Band.MET
	var call: Callable = opt.get("effect", Callable())
	if opt.has("check"):
		band = SkillCheck.roll(opt.check)
		call = SkillCheck.pick_outcome(opt, band)
	var outcome: Dictionary = call.call() if call.is_valid() else {}
	# The node is consumed here rather than when the hail opened, so that
	# quitting at the options costs nothing and cannot be quit into a cleared
	# node that gives nothing. Router holds the pick until this call.
	Router.event_resolved(SkillCheck.band_result(band) if opt.has("check") \
		else MapGen.R_DONE)
	_resolved = true
	# THE REWARD AN OPTION PAYS, which this screen never had to handle before.
	#
	# `module = true` in the returned dictionary means "one rolled at this
	# system's danger", and both other resolution paths honour it -- `Policy` for
	# the sim and `SectorScreen` for a row that resolves in place. This screen
	# predates the option model and only read `fight`, so when RULING 2 made it
	# the detail view it became the one path that silently dropped the pay: it is
	# reached by exactly the options with prose AND a check, and those are the
	# ones that pay in parts. `salvage_rights` pays a module in two of its bands
	# and paid nothing through here.
	#
	# No EventTable event grants one, which is why nothing caught it earlier.
	var got := OptionTable.pay(outcome, Run.node_at())
	_then_fight = bool(outcome.get("fight", false))
	_refresh()
	var panel := PanelContainer.new()
	var edge := SkillCheck.band_colour(band) if opt.has("check") else UITheme.EMBER
	var sb := UITheme.flat(UITheme.PANEL2, edge, 0, 9, 11)
	sb.border_width_left = 2
	panel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	# Name the band above the prose. The outcome text is written in fiction and
	# deliberately does not say "you failed" — so without this, a Partial and a
	# Botched are two paragraphs you cannot tell apart, and the ladder the player
	# just gambled against never resolves visibly.
	if opt.has("check"):
		col.add_child(UITheme.body(SkillCheck.band_name(band), edge, UITheme.FS_SMALL))
	var said := String(outcome.get("text", ""))
	if got != "":
		said += "  [%s]" % got
	var text := UITheme.body(said, UITheme.HOT, UITheme.FS_BODY)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	panel.add_child(col)
	_result.add_child(panel)
	if Run.dead:
		_result.add_child(Widgets.button("…", func(): Router.show_game_over()))
		return
	# THE DOOR, WHICH THIS SCREEN NEVER HAD.
	#
	# `pay` has always put a module on the system's floor from here, and this
	# screen has always said nothing about it -- the prose named the thing and
	# then the thing was somewhere else, two screens away, behind a button in a
	# sector you had to walk back to. `salvage_rights` pays a module in two of
	# its bands and is reached by exactly this path.
	#
	# Same word and same pile as the drawer's: see `SectorScreen._open_prize`.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	if OptionTable.pays_item(outcome):
		var claim := Widgets.button("PRIZE", _open_prize)
		claim.custom_minimum_size = Vector2(120, 22)
		claim.tooltip_text = Widgets.tip("Your hold on one side, what this left you on the other. Anything you do not take stays in this system as jetsam -- open SECTOR LOOT and it is still there.")
		row.add_child(claim)
	row.add_child(Widgets.button("CONTINUE", _continue))
	_result.add_child(row)


## What this event just paid, on the system's floor. See
## `SectorScreen._open_prize` -- one pile per system, and it is jetsam the
## moment you stop standing in the result.
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
	_transfer.setup(h, n, _close_transfer, true, "PRIZE")


func _close_transfer() -> void:
	if _transfer == null:
		return
	_transfer.queue_free()
	_transfer = null

func _continue() -> void:
	if _then_fight:
		Router.start_ambush()
	else:
		Router.after_event()
