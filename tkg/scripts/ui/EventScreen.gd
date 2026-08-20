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
	for c in _options.get_children():
		c.queue_free()
	for c in _result.get_children():
		c.queue_free()
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
	Router.event_resolved()
	_resolved = true
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
	var text := UITheme.body(String(outcome.get("text", "")), UITheme.HOT, UITheme.FS_BODY)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	panel.add_child(col)
	_result.add_child(panel)
	if Run.dead:
		_result.add_child(Widgets.button("…", func(): Router.show_game_over()))
	else:
		_result.add_child(Widgets.button("CONTINUE", _continue))

func _continue() -> void:
	if _then_fight:
		Router.start_ambush()
	else:
		Router.after_event()
