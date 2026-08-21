class_name HistoryScreen
extends Control

## Every run you have finished. Career totals across the top, then the runs
## themselves newest first.
##
## Reachable from two places with one class: the HUD during a run, and the
## launcher before one. `setup()` takes the way back rather than deciding it,
## because the screen genuinely does not know which door it came through.
##
## A run is summarised by where it ENDED and how deep it got, not by how long it
## lasted. Depth in shells is the honest measure — jump count rewards farming
## the rim, which is the reading this game least wants to encourage.

var _back: Callable

func setup(back: Callable) -> void:
	_back = back
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	var runs := RunHistory.recent()

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UITheme.header("FLIGHT RECORD"))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	head.add_child(Widgets.button("BACK", func() -> void: _back.call()))
	col.add_child(head)
	col.add_child(UITheme.hsep())

	col.add_child(_totals())

	if runs.is_empty():
		col.add_child(_empty())
		return

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	for e in runs:
		list.add_child(_row(e))
	var scroll := Widgets.scroller(list, 240)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

## Career totals. Win rate is against FINISHED runs, and the line says so —
## a rate that silently counted abandoned openings would improve every time you
## restarted a bad one.
func _totals() -> Control:
	var s := RunHistory.stats()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(Widgets.stat("runs", str(s.runs)))
	row.add_child(Widgets.stat("reached the core", str(s.wins),
		UITheme.HOT if int(s.wins) > 0 else UITheme.COLD))
	row.add_child(Widgets.stat("win rate", "%.0f%%" % float(s.win_rate)))
	# A depth reading with no runs behind it would print "1/9 shells", which
	# looks like a record rather than the absence of one.
	row.add_child(Widgets.stat("deepest", "%d/%d shells" % [
		int(s.best_depth) + 1, MapGen.LAYERS] if int(s.runs) > 0 else "—"))
	row.add_child(Widgets.stat("kills", str(s.kills)))
	row.add_child(Widgets.stat("jumps", str(s.jumps)))
	var pad := Widgets.pad(null, 10, 7)
	pad.add_child(row)
	return Widgets.panel_with(pad)

func _empty() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var a := UITheme.body("No runs on record.", UITheme.CHILL, UITheme.FS_BODY)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(a)
	var b := UITheme.body("Every run that ends is logged here — won, lost or abandoned.",
		UITheme.COLD, UITheme.FS_SMALL)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(b)
	var centre := CenterContainer.new()
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centre.add_child(Widgets.panel_with(box))
	return centre

## One run. Outcome and depth first because they are what you scan for; the
## galaxy, the frame and the build are what you stop on.
func _row(e: Dictionary) -> Control:
	var outcome := int(e.get("outcome", RunHistory.Outcome.DIED))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(UITheme.body(RunHistory.outcome_name(outcome),
		_outcome_colour(outcome), UITheme.FS_SMALL))
	top.add_child(UITheme.body(RunHistory.depth_text(e), UITheme.ICE, UITheme.FS_SMALL))
	top.add_child(UITheme.body("danger %d" % int(e.get("danger", 1)),
		UITheme.COLD, UITheme.FS_SMALL))
	top.add_child(UITheme.body(_count(int(e.get("kills", 0)), "kill"),
		UITheme.COLD, UITheme.FS_SMALL))
	top.add_child(UITheme.body(_count(int(e.get("jumps", 0)), "jump"),
		UITheme.COLD, UITheme.FS_SMALL))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	top.add_child(UITheme.body(RunHistory.duration_text(float(e.get("seconds", 0.0))),
		UITheme.COLD, UITheme.FS_SMALL))
	top.add_child(UITheme.body(RunHistory.date_text(float(e.get("ended_at", 0.0))),
		UITheme.QUOTE, UITheme.FS_SMALL))
	col.add_child(top)

	var where := "%s · %s" % [str(e.get("galaxy_title", "")), str(e.get("hull", ""))]
	var makers := _makers_text(e.get("makers", []))
	if makers != "":
		where += " · " + makers
	col.add_child(UITheme.body(where, UITheme.CHILL, UITheme.FS_SMALL))

	# The seed, on its own line and in the dimmest colour on the screen. It is
	# not a stat — nobody is comparing seeds — it is a thing you copy down when a
	# run was worth flying twice, so it wants to be findable and not loud.
	#
	# Runs recorded before this existed have no seed and get no line, rather than
	# a zero pretending to be one.
	var run_seed := int(e.get("seed", 0))
	if run_seed != 0:
		col.add_child(UITheme.body("seed %d" % run_seed, UITheme.QUOTE, UITheme.FS_SMALL))

	var reason := str(e.get("reason", ""))
	if reason != "":
		var r := UITheme.body(reason, UITheme.QUOTE, UITheme.FS_SMALL)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(r)

	var pad := Widgets.pad(null, 9, 6)
	pad.add_child(col)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.PANEL2, UITheme.LINE, 0, 0, 0))
	panel.add_child(pad)
	return panel

## What the ship was flying, in the vocabulary set bonuses use: house and count,
## biggest first. Two entries is enough to name a build.
func _makers_text(raw: Variant) -> String:
	if typeof(raw) != TYPE_ARRAY:
		return ""
	var parts: PackedStringArray = []
	for e in (raw as Array):
		if parts.size() >= 2:
			break
		var d: Dictionary = e
		var id := StringName(str(d.get("id", "")))
		var label := "unbranded" if id == &"unbranded" else DB.manufacturer_name(id)
		parts.append("%dx %s" % [int(d.get("n", 0)), label])
	return " ".join(parts)

func _count(n: int, noun: String) -> String:
	return "%d %s%s" % [n, noun, "" if n == 1 else "s"]

func _outcome_colour(o: int) -> Color:
	match o:
		RunHistory.Outcome.WON: return UITheme.HOT
		RunHistory.Outcome.ABANDONED: return UITheme.COLD
		_: return UITheme.THEM
