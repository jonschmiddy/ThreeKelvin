class_name GameOverScreen
extends Control

## JON'S THANK-YOU NOTE, shown on the win screen when the core's boss is beaten.
## The text lives in `AlphaNotes.ALPHA_THANKS`, beside his welcome note.
const ALPHA_THANKS := AlphaNotes.ALPHA_THANKS
const WIN_TITLE := "YOU WON"

## The win screen's letter (`NoteCard`): the note, the numbers under it, the
## buttons. Null on the death screen.
var card: NoteCard = null

## `still`: the picture the run ended on (`DeathHandoff`), drawn under the
## panel in place of the sky; `look`: how the panel arrives over it, &"rise"
## (fades and rises in) or &"type" (RUN ENDED typed in, then the rest).
func setup(still: Texture2D = null, look: StringName = &"") -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if Run.won:
		_win()
		return
	if still != null:
		# The whole game picture, wherever this screen sits in it.
		# (not top_level: that draws it over everything, the panel included)
		var pic := TextureRect.new()
		pic.texture = still
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pic)
		_still = pic
		_place_still()
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var box := VBoxContainer.new()
	# TIGHT AROUND WHAT IT SAYS. It was 330 wide with 14 between its three
	# blocks, and the longest line in it is about 220 -- so the panel was mostly
	# air, which reads as an unfinished screen rather than a quiet one (Jon).
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(250, 0)

	# The two endings do not get the same colour. Reaching the core is the one
	# thing in this game that goes right; a run ending is the other outcome and
	# it should say so before the sentence under it is read. BAD rather than a
	# literal, so it moves with the palette like everything else.
	var title := UITheme.body("RUN ENDED", UITheme.BAD, UITheme.FS_HEAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_stats_label = _stats()
	box.add_child(_stats_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(Widgets.button("NEW RUN", func(): Router.new_run()))
	# A PLAIN WAY BACK TO THE TITLE (the tutorial audit, Oct 22): the only one
	# was Esc and then ABANDON, on a run already over. The win's TITLE does it.
	row.add_child(Widgets.button("TITLE", to_title))
	var said := _said()
	row.add_child(_logs_button(said))
	box.add_child(row)
	box.add_child(said)
	# Its own panel rather than `panel_with`, whose 12 px all round was written
	# for panels with a list in them.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		UITheme.flat(Color(UITheme.PANEL, UITheme.PANEL_A), UITheme.LINE, 0, 14, 18))
	panel.add_child(box)
	centre.add_child(panel)
	if still != null and look != &"":
		_arrive(centre, panel, title, [_stats_label, row, said], look)


var _stats_label: Control = null
var _still: TextureRect = null


## The kept picture over the whole game picture, wherever this screen has been
## laid out: the HUD going away moves this screen up a frame after it arrives.
func _place_still() -> void:
	if _still == null or not is_inside_tree():
		return
	_still.position = -get_global_transform().origin
	_still.size = get_viewport_rect().size


func _process(_d: float) -> void:
	if _still != null:
		_place_still()

## THE PANEL ARRIVES over the picture the run ended on, and nothing can be
## pressed until its buttons are up.
func _arrive(centre: Control, panel: Control, title: Label, rest: Array, look: StringName) -> void:
	var buttons: Array[Button] = []
	for b in find_children("*", "Button", true, false):
		(b as Button).disabled = true
		buttons.append(b)
	var block := Control.new()
	block.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	block.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(block)
	var tw := create_tween()
	if look == &"type":
		# On the dark screen: the panel's ground, then RUN ENDED a letter at a
		# time, then what it says under it.
		panel.self_modulate.a = 0.0
		title.visible_characters = 0
		for r in rest:
			(r as CanvasItem).modulate.a = 0.0
		tw.tween_property(panel, "self_modulate:a", 1.0, 0.15)
		tw.tween_property(title, "visible_characters", title.text.length(), 0.05 * title.text.length())
		var first := true
		for r in rest:
			if first:
				tw.tween_property(r, "modulate:a", 1.0, 0.25)
				first = false
			else:
				tw.parallel().tween_property(r, "modulate:a", 1.0, 0.25)
	else:
		# Fades and rises in, 10 px.
		centre.modulate.a = 0.0
		centre.position.y += 10.0
		var y0 := centre.position.y - 10.0
		tw.tween_property(centre, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(centre, "position:y", y0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		for b in buttons:
			if is_instance_valid(b):
				b.disabled = false
		block.queue_free())


## THE WIN: Jon's note as a letter, the same look as his welcome note
## (`NoteCard`), with the run's numbers under it and the way out. The moment
## first, then the record. The dim is lighter than the title's, so the sky
## behind still shows.
func _win() -> void:
	card = NoteCard.new()
	card.build(WIN_TITLE, ALPHA_THANKS, 0.5)
	add_child(card)
	card.add_section(_stats())
	# BACK TO THE TITLE: the alpha ends here (`to_title`).
	#
	# TITLE IS THE PRIMARY, the welcome note's amber plate: the alpha ends at the
	# core, so the way on is back to the title. NEW RUN and SAVE MY LOGS stay the
	# game's own buttons beside it.
	var said := _said()
	card.add_buttons([
		NoteCard.primary("TITLE", to_title),
		Widgets.button("NEW RUN", func(): Router.new_run()),
		_logs_button(said),
	])
	card.add_footer(said)


## BACK TO THE TITLE, from either ending. Left the way the escape menu's quit
## leaves a run -- no ship, the state the title expects. The run is already in
## the record and its save already gone (`Router._on_run_ended`).
static func to_title() -> void:
	Run.hull = null
	Router.show_launcher()


func _stats() -> Label:
	var lines: PackedStringArray = []
	if Run.won:
		lines.append("You reach the core with %d hull left." % Run.hp)
	else:
		lines.append(Run.death_reason)
	lines.append("%d jumps · %d kills · danger %d when it ended" % [
		Run.jumps, Run.kills, Run.node_at().danger])
	# The whole ledger, not just the row that used to be a field — exotics you
	# never got to a bench is as much a thing you were carrying when it ended as
	# scrap you never spent.
	var held: PackedStringArray = ["%d credits unspent" % Run.credits]
	for stock in Run.material_stock():
		held.append("%d %s" % [int(stock.count), str(stock.name).to_lower()])
	lines.append(" · ".join(held))
	var body := UITheme.body("\n".join(lines), UITheme.COLD, UITheme.FS_BODY)
	body.name = "RunStats"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return body


## Where SAVE MY LOGS says the zip went, under the buttons.
func _said() -> Label:
	var said := UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return said


## SAVE MY LOGS, beside the way on: the end of a run is when a friend has
## something to send (`PlaytestLogs`).
func _logs_button(said: Label) -> Button:
	return Widgets.button("SAVE MY LOGS", func() -> void:
		var r := PlaytestLogs.save_bundle()
		if r.get("ok", false):
			said.text = "Saved to your %s: %s. Drag it into the chat." % [r.where, String(r.path).get_file()]
			PlaytestLogs.show_in_folder(String(r.path))
		else:
			said.text = String(r.error))


## For the harness: whether the note fits whole (no scroll), and the panel's
## rect in this screen.
func note_scrolls() -> bool:
	return card != null and card.note_scrolls()

func panel_rect() -> Rect2:
	return card.panel_rect() if card != null else Rect2()
