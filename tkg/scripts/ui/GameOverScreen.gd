class_name GameOverScreen
extends Control

## JON'S THANK-YOU NOTE, shown on the win screen when the core's boss is beaten.
## The text lives in `AlphaNotes.ALPHA_THANKS`, beside his welcome note.
const ALPHA_THANKS := AlphaNotes.ALPHA_THANKS

## How wide the win screen is. Wider than the death screen's 250, which was
## sized to three short lines, because the note is a letter: about sixty
## letters a line reads as one.
const WIN_W := 400

## What the win screen leaves clear of the window's edges when it is tall.
const EDGE := 12

## Set on a win: the note's scroll and the panel, for `_fit`.
var _scroll: ScrollContainer = null
var _panel: PanelContainer = null

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var box := VBoxContainer.new()
	# TIGHT AROUND WHAT IT SAYS. It was 330 wide with 14 between its three
	# blocks, and the longest line in it is about 220 -- so the panel was mostly
	# air, which reads as an unfinished screen rather than a quiet one (Jon).
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(WIN_W if Run.won else 250, 0)

	# The two endings do not get the same colour. Reaching the core is the one
	# thing in this game that goes right; a run ending is the other outcome and
	# it should say so before the sentence under it is read. BAD rather than a
	# literal, so it moves with the palette like everything else.
	var title := UITheme.body("YOU WON" if Run.won else "RUN ENDED",
		UITheme.ICE if Run.won else UITheme.BAD, UITheme.FS_HEAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	# THE WIN'S NOTE, under the title and over the numbers: the moment first,
	# then the record. In a scroll that only scrolls if the window is too short
	# for the whole panel (`_fit`); otherwise it is simply the letter.
	if Run.won:
		var thanks := UITheme.body(ALPHA_THANKS, UITheme.CHILL, UITheme.FS_BODY)
		thanks.name = "AlphaThanks"
		thanks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		thanks.custom_minimum_size = Vector2(WIN_W, 0)
		_scroll = ScrollContainer.new()
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.add_child(thanks)
		box.add_child(_scroll)
		var rule := ColorRect.new()
		rule.color = UITheme.LINE
		rule.custom_minimum_size = Vector2(0, 1)
		box.add_child(rule)

	var lines: PackedStringArray = []
	if Run.won:
		lines.append("You cross into the light with %d hull left." % Run.hp)
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
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# BACK TO THE TITLE, on a win: the alpha ends here. Left the way the escape
	# menu's quit leaves a run -- no ship, the state the title expects. The run
	# is already in the record and its save already gone (`Router._on_run_ended`).
	if Run.won:
		row.add_child(Widgets.button("TITLE", func() -> void:
			Run.hull = null
			Router.show_launcher()))
	row.add_child(Widgets.button("NEW RUN", func(): Router.new_run()))
	# SAVE MY LOGS, beside it: the end of a run is when a friend has something
	# to send (`PlaytestLogs`). Says where the zip went, under the buttons.
	var said := UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(Widgets.button("SAVE MY LOGS", func() -> void:
		var r := PlaytestLogs.save_bundle()
		if r.get("ok", false):
			said.text = "Saved to your %s: %s. Drag it into the chat." % [r.where, String(r.path).get_file()]
			PlaytestLogs.show_in_folder(String(r.path))
		else:
			said.text = String(r.error)))
	box.add_child(row)
	box.add_child(said)
	# Its own panel rather than `panel_with`, whose 12 px all round was written
	# for panels with a list in them.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		UITheme.flat(Color(UITheme.PANEL, UITheme.PANEL_A), UITheme.LINE, 0, 14, 18))
	panel.add_child(box)
	centre.add_child(panel)
	_panel = panel
	if _scroll != null:
		resized.connect(_fit)
		_fit.call_deferred()


## THE NOTE SCROLLS ONLY IF THE PANEL WOULD NOT FIT. At the game's 960x540 the
## whole letter shows; a shorter window (or a longer letter) caps the note's
## height so the title, the numbers and the buttons all stay on screen.
func _fit() -> void:
	if _scroll == null or _panel == null or not is_inside_tree():
		return
	var note := _scroll.get_child(0) as Control
	var want := note.get_combined_minimum_size().y
	# the panel's height without the note in it
	var rest := _panel.get_combined_minimum_size().y - _scroll.get_combined_minimum_size().y
	var room := size.y - 2.0 * EDGE - rest
	if want <= room:
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.custom_minimum_size.y = 0.0
	else:
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_scroll.custom_minimum_size.y = maxf(48.0, room)


## For the harness: whether the note fits whole (no scroll), and the panel's
## rect in this screen.
func note_scrolls() -> bool:
	return _scroll != null and _scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED

func panel_rect() -> Rect2:
	return _panel.get_global_rect() if _panel != null else Rect2()
