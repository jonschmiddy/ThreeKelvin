extends Node

## JON'S WELCOME NOTE, on a fresh profile and after it:
##   godot --headless --path . -- sheet=WelcomeTest welcome
## (`welcome` lets it open by itself under a harness; the seen flags go to this
## process's scratch settings file, so the profile starts fresh every run.)
##
## The title on a fresh profile opens the note, word for word, inside the screen;
## showing it does not mark it seen, so a title opened again before it is closed
## shows it again; CLOSE shuts it and marks it; the next title (the second
## launch) does not open it. MESSAGE FROM JON sits directly above QUIT, styled as
## its neighbours and reachable by focus, and opens it again; Escape shuts it.
## And what follows it on a first launch (tutorial direction B, Oct 17): NEW
## RUN on a fresh profile goes straight to the hull pick with no seed panel (the
## panel stays once a save exists), and LAUNCH there puts you on LOCAL with no
## tour and no note: the goal line under the HUD, and the controls yours.

var _tree: SceneTree
var _fails := 0


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	print("  [settings] %s" % DisplaySettings.hints_path())
	_ok("a fresh profile has not seen the note", not WelcomePopup.seen())

	Router.show_launcher()
	await _frames(4)
	var w := _welcome()
	if not _ok("the title opens the welcome note", w != null and w.is_visible_in_tree()):
		return _finish()
	_check_letter(w)
	var start := _button(w, WelcomePopup.FIRST_BUTTON)
	_ok("its one button reads START YOUR JOURNEY on a first launch",
		start != null and _count_buttons(w) == 1)
	if start != null:
		_ok("and is the primary: heading-size type on the amber plate",
			start.get_theme_font_size("font_size") == UITheme.FS_HEAD
			and start.get_theme_stylebox("normal") is StyleBoxTexture)
		var letter := w.card.body.get_parent_control()
		_ok("clear of the note", not letter.get_global_rect().intersects(start.get_global_rect()))
	_ok("showing it does not mark it seen", not WelcomePopup.seen())

	# quit with it still up: the next title shows it again
	Router.show_launcher()
	await _frames(4)
	w = _welcome()
	_ok("a title opened again before it was closed shows it again", w != null)
	if w == null:
		return _finish()
	_button(w, WelcomePopup.FIRST_BUTTON).pressed.emit()
	await _frames(3)
	_ok("START YOUR JOURNEY shuts it", _welcome() == null)
	_ok("and marks it seen", WelcomePopup.seen())

	# the second launch
	Router.show_launcher()
	await _frames(4)
	_ok("the second launch does not open it", _welcome() == null)

	# MESSAGE FROM JON, above QUIT
	var ls := Router.current as LauncherScreen
	var mfj := _button(ls, "MESSAGE FROM JON")
	var quit := _button(ls, "QUIT")
	var settings := _button(ls, "SETTINGS")
	if _ok("the title menu has MESSAGE FROM JON", mfj != null and quit != null):
		_ok("directly above QUIT", mfj.get_parent() == quit.get_parent()
			and mfj.get_index() == quit.get_index() - 1
			and mfj.get_global_rect().end.y <= quit.get_global_rect().position.y + 0.5)
		_ok("in the menu's own size and look", settings != null
			and mfj.get_theme_font_size("font_size") == settings.get_theme_font_size("font_size")
			and mfj.get_theme_color("font_color") == settings.get_theme_color("font_color")
			and mfj.size.y == settings.size.y)
		_ok("pressable and in the focus walk", not mfj.disabled
			and mfj.focus_mode != Control.FOCUS_NONE and mfj.mouse_filter == Control.MOUSE_FILTER_STOP)
		mfj.pressed.emit()
		await _frames(3)
		w = _welcome()
		_ok("pressing it opens the note again", w != null and w.is_visible_in_tree())
		if w != null:
			_check_letter(w)
			_ok("its button reads CLOSE from the menu", _button(w, WelcomePopup.AGAIN_BUTTON) != null
				and _button(w, WelcomePopup.FIRST_BUTTON) == null and _count_buttons(w) == 1)
		await _press(KEY_ESCAPE)
		await _frames(3)
		_ok("Escape shuts it", _welcome() == null)
		ls.open_welcome()
		await _frames(3)
		w = _welcome()
		var reopened := w != null
		if reopened:
			_button(w, WelcomePopup.AGAIN_BUTTON).pressed.emit()
			await _frames(3)
		_ok("and so does CLOSE", reopened and _welcome() == null)
		_ok("and the title is still up", Router.current is LauncherScreen)

	await _check_new_things()

	# NEW RUN ON A FRESH PROFILE: straight to the hull pick, no seed panel
	WelcomePopup.mark_seen(false)
	SaveGame.clear()
	RunHistory.clear()
	Router.show_launcher()
	await _frames(4)
	var w2 := _welcome()
	if w2 != null:
		_button(w2, WelcomePopup.FIRST_BUTTON).pressed.emit()
		await _frames(3)
	_ok("a fresh profile: no save, no flight record", LauncherScreen.fresh_profile())
	var nr := _button(Router.current, "NEW RUN")
	if _ok("the title has NEW RUN", nr != null):
		nr.pressed.emit()
		await _frames(6)
		_ok("NEW RUN on a fresh profile opens the hull pick, with no seed panel",
			Router.current is ChassisSelect and _find(_tree.root, func(n: Node) -> bool:
				return n is Label and (n as Label).text == "LAUNCH A RUN" and (n as Label).is_visible_in_tree()) == null)
		# LAUNCH: LOCAL, no tour, no note
		var go := _button(Router.current, "LAUNCH")
		if _ok("the hull pick has LAUNCH", go != null):
			go.pressed.emit()
			await _frames(30)
			_ok("LAUNCH puts you on LOCAL", Router.current is SectorScreen)
			_ok("with no tour and no note over it: nothing at the root of the picture but the screens",
				_find(_tree.root, func(n: Node) -> bool:
					return n is WelcomePopup or (n.get_script() != null
						and String((n.get_script() as Script).get_global_name()) == "FirstRunIntro")) == null)
			var g: GoalLine = Router.hud.goal if Router.hud != null else null
			_ok("and the goal under the HUD", g != null and g._goal.text == GoalLine.GOAL)
	# with a save: the panel stays (it warns that launching abandons the run)
	SaveGame.save()
	Router.show_launcher()
	await _frames(4)
	_ok("a save exists: not a fresh profile", SaveGame.has_save() and not LauncherScreen.fresh_profile())
	nr = _button(Router.current, "NEW RUN")
	if nr != null:
		nr.pressed.emit()
		await _frames(6)
		_ok("NEW RUN with a save opens the seed panel", Router.current is LauncherScreen
			and _find(Router.current, func(n: Node) -> bool:
				return n is Label and (n as Label).text == "LAUNCH A RUN" and (n as Label).is_visible_in_tree()) != null)
	SaveGame.clear()
	_finish()


## NEW THINGS (Jon, Nov 5): the data's version rule, the button above MESSAGE
## FROM JON with its unseen mark, the page (every heading and line as written,
## each inside the page and none on another, the list scrolling by wheel and
## keys) and the mark cleared by opening it, saved and read back.
func _check_new_things() -> void:
	# THE DATA. Newest first: NEXT (work not out yet) with this build's version
	# right under it, or this build's version itself. See NewThings' rule.
	var list: Array = NewThings.LIST
	var ver := NewThings.build_version()
	var top := str(list[0].version) if not list.is_empty() else ""
	_ok("NEW THINGS' newest entry is this build's (%s) or NEXT right above it (%s)" % [ver, top],
		list.size() >= 1 and (top == ver
			or (top == NewThings.NEXT and list.size() >= 2 and str(list[1].version) == ver)))
	var seen_v := {}
	var order_ok := true
	var dated := true
	var lines_ok := true
	var prev := ""
	for i in list.size():
		var e: Dictionary = list[i]
		var v := str(e.version)
		if v == NewThings.NEXT:
			order_ok = order_ok and i == 0 and str(e.date) == ""
		else:
			dated = dated and RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}$").search(str(e.date)) != null
			order_ok = order_ok and not seen_v.has(v) and (prev == "" or _ver_less(v, prev))
			prev = v
		seen_v[v] = true
		lines_ok = lines_ok and (e.lines as Array).size() >= 1
		for l in e.lines:
			lines_ok = lines_ok and str(l).strip_edges() != "" and not "—" in str(l) and not " - " in str(l)
	_ok("  versions newest first, each once, NEXT only at the top", order_ok)
	_ok("  every released entry dated YYYY-MM-DD", dated)
	_ok("  every entry has lines, none empty, no dashes", lines_ok)
	var first: Dictionary = list[-1] if not list.is_empty() else {}
	_ok("  0.4.0-alpha.1 in Jon's words: \"Initial alpha release.\"", first.get("version") == "0.4.0-alpha.1"
		and first.get("lines") == ["Initial alpha release."])

	# THE BUTTON, with its mark on a profile that never opened the page
	NewThings.forget()
	Router.show_launcher()
	await _frames(4)
	var ls := Router.current as LauncherScreen
	var nt := _button(ls, "NEW THINGS")
	var mfj := _button(ls, "MESSAGE FROM JON")
	var settings := _button(ls, "SETTINGS")
	if not _ok("the title menu has NEW THINGS", nt != null and mfj != null):
		return
	_ok("  between SETTINGS and MESSAGE FROM JON", nt.get_parent() == mfj.get_parent()
		and settings != null and nt.get_index() == mfj.get_index() - 1
		and settings.get_index() == nt.get_index() - 1
		and nt.get_global_rect().end.y <= mfj.get_global_rect().position.y + 0.5)
	_ok("  in the menu's own size and look", settings != null
		and nt.get_theme_font_size("font_size") == settings.get_theme_font_size("font_size")
		and nt.get_theme_color("font_color") == settings.get_theme_color("font_color")
		and nt.get_theme_color("font_hover_color") == settings.get_theme_color("font_hover_color")
		and nt.size.y == settings.size.y)
	_ok("  pressable and in the focus walk", not nt.disabled
		and nt.focus_mode != Control.FOCUS_NONE and nt.mouse_filter == Control.MOUSE_FILTER_STOP)
	var mark := _mark(nt)
	_ok("  never opened: NEW THINGS carries its mark", NewThings.unseen() and mark != null and mark.is_visible_in_tree())
	if mark != null:
		var mr := mark.get_global_rect()
		var clear := true
		for b in _menu_buttons(nt.get_parent()):
			clear = clear and not mr.intersects(b.get_global_rect())
		print("    mark %s beside %s" % [mr, nt.get_global_rect()])
		_ok("  the mark is small, inside the screen, right of the words and on no menu line",
			mr.size.x > 0.0 and mr.size.x <= 8.0 and mr.size.y <= 8.0 and clear
			and ls.get_global_rect().encloses(mr)
			and mr.position.x >= nt.get_global_rect().end.x
			and absf(mr.get_center().y - nt.get_global_rect().get_center().y) <= 2.0)
		_ok("  in the menu's accent, still (a plain square, no shader)", mark is ColorRect
			and (mark as ColorRect).color == UITheme.FLARE and mark.material == null
			and mark.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	# an older version seen still marks the newest
	NewThings.mark_seen("0.4.0-alpha.1")
	Router.show_launcher()
	await _frames(4)
	nt = _button(Router.current, "NEW THINGS")
	_ok("  a profile that saw an older build's notes sees the mark", nt != null
		and _mark(nt) != null and _mark(nt).is_visible_in_tree())

	# THE PAGE
	nt.pressed.emit()
	await _frames(4)
	var pop := _new_things()
	if not _ok("pressing NEW THINGS opens its page", pop != null and pop.is_visible_in_tree()):
		return
	_ok("  opening it clears the mark at once", not _mark(nt).is_visible_in_tree())
	var cfg := ConfigFile.new()
	var loaded := cfg.load(DisplaySettings.hints_path())
	_ok("  and saves the newest seen to the settings file ([news] seen = %s)" % NewThings.latest_key(),
		loaded == OK and str(cfg.get_value("news", "seen", "")) == NewThings.latest_key()
		and not NewThings.unseen())
	var card: NoteCard = pop.get("card")
	var title := _find(pop, func(n: Node) -> bool: return n.name == &"NoteTitle") as Label
	_ok("  headed NEW THINGS in the note's own case", card != null and title != null
		and title.text == "NEW THINGS")
	var screen := (Router.current as Control).get_global_rect()
	var panel := card.panel_rect()
	print("    screen %s, panel %s, scrolls %s" % [screen, panel, card.note_scrolls()])
	_ok("  the panel is inside the screen", screen.grow(0.5).encloses(panel))
	var close := _button(pop, "CLOSE")
	_ok("  one button, CLOSE, on the amber plate", close != null and _count_buttons(pop) == 1
		and close.get_theme_stylebox("normal") is StyleBoxTexture)

	# every heading and line, as written, in order
	var vers := _all(pop, func(n: Node) -> bool: return n.name == &"Version")
	var days := _all(pop, func(n: Node) -> bool: return n.name == &"Day")
	var texts := _all(pop, func(n: Node) -> bool: return n.name == &"Text")
	var want_v := []
	var want_d := []
	var want_t := []
	for e in list:
		want_v.append(NewThings.heading(e))
		want_d.append(NewThings.day(e))
		for l in e.lines:
			want_t.append(str(l))
	_ok("  each version's heading, newest first (%s)" % ", ".join(want_v),
		vers.map(func(l: Label) -> String: return l.text) == want_v)
	_ok("  each version's day (%s)" % ", ".join(want_d),
		days.map(func(l: Label) -> String: return l.text) == want_d)
	_ok("  every line word for word, in order (%d)" % want_t.size(),
		texts.map(func(l: Label) -> String: return l.text) == want_t)

	# FIT: inside the page across, nothing on anything, no label cut short
	var boxes: Array = []
	boxes.append_array(vers)
	boxes.append_array(days)
	# (the rows by their words: Godot renames a row's siblings "Line" past the first)
	boxes.append_array(texts.map(func(l: Label) -> Control: return l.get_parent_control()))
	var across := true
	var cut := true
	for c in boxes:
		var r: Rect2 = (c as Control).get_global_rect()
		across = across and r.size.x > 0.0 and r.position.x >= panel.position.x - 0.5 \
			and r.end.x <= panel.end.x + 0.5
	for l in vers + days + texts:
		var lab := l as Label
		var need := lab.get_minimum_size()
		if lab.autowrap_mode != TextServer.AUTOWRAP_OFF:
			need.y = lab.get_line_count() * lab.get_line_height()
			need.x = 0.0
		cut = cut and need.x <= lab.size.x + 0.5 and need.y <= lab.size.y + 0.5 \
			and lab.get_visible_line_count() == lab.get_line_count()
	var overlaps := []
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if (boxes[i] as Control).get_global_rect().intersects((boxes[j] as Control).get_global_rect()):
				overlaps.append("%s/%s" % [(boxes[i] as Node).name, (boxes[j] as Node).name])
	_ok("  every heading and line inside the page across (%d boxes)" % boxes.size(), across)
	_ok("  no box on another%s" % ("" if overlaps.is_empty() else ": " + ", ".join(overlaps.slice(0, 6))),
		overlaps.is_empty())
	_ok("  no label cut short", cut)

	# SCROLL: long at the game's size, every row reachable inside the page
	var sc: ScrollContainer = card.note_scroll()
	_ok("  the list scrolls at the game's size", card.note_scrolls() and sc != null
		and sc.get_v_scroll_bar().max_value > sc.size.y + 1.0)
	var shown := true
	for c in boxes:
		sc.ensure_control_visible(c as Control)
		await _frames(2)
		var r := (c as Control).get_global_rect()
		shown = shown and sc.get_global_rect().grow(0.5).encloses(r) and panel.grow(0.5).encloses(r)
	_ok("  scrolled to, every heading and line shows whole inside the page", shown)
	sc.scroll_vertical = 0
	await _frames(2)
	_ok("  the page and CLOSE do not overlap the list", close != null
		and not sc.get_global_rect().intersects(close.get_global_rect())
		and panel.encloses(close.get_global_rect()))
	await _press(KEY_DOWN)
	await _frames(2)
	var after_down := sc.scroll_vertical
	await _press(KEY_PAGEDOWN)
	await _frames(2)
	var after_page := sc.scroll_vertical
	await _press(KEY_END)
	await _frames(2)
	var at_end := sc.scroll_vertical
	await _press(KEY_HOME)
	await _frames(2)
	var most := int(sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page)
	print("    keys: down %d, page down %d, end %d (of %d), home %d" % [after_down, after_page, at_end, most, sc.scroll_vertical])
	_ok("  Down, Page Down, End and Home scroll the list", after_down > 0 and after_page > after_down
		and at_end == most and sc.scroll_vertical == 0)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = sc.get_global_rect().get_center()
	wheel.global_position = wheel.position
	sc.scroll_vertical = 0
	await _frames(1)
	get_viewport().push_input(wheel, true)
	await _frames(2)
	_ok("  the mouse wheel scrolls it (%d)" % sc.scroll_vertical, sc.scroll_vertical > 0)

	await _press(KEY_ESCAPE)
	await _frames(3)
	_ok("  Escape shuts it", _new_things() == null and Router.current is LauncherScreen)
	# read back: the next title has no mark
	Router.show_launcher()
	await _frames(4)
	nt = _button(Router.current, "NEW THINGS")
	_ok("  the next title, read from the file: no mark", nt != null and _mark(nt) != null
		and not _mark(nt).is_visible_in_tree())
	nt.pressed.emit()
	await _frames(4)
	pop = _new_things()
	var cl := _button(pop, "CLOSE") if pop != null else null
	var had := cl != null
	if had:
		cl.pressed.emit()
		await _frames(3)
	_ok("  CLOSE shuts it too", had and _new_things() == null)


## 0.4.2-alpha.1 before 0.4.10-alpha.1, numerically, then the pre-release tag.
func _ver_less(a: String, b: String) -> bool:
	var pa := a.split("-", true, 1)
	var pb := b.split("-", true, 1)
	var na := pa[0].split(".")
	var nb := pb[0].split(".")
	for i in maxi(na.size(), nb.size()):
		var x := int(na[i]) if i < na.size() else 0
		var y := int(nb[i]) if i < nb.size() else 0
		if x != y:
			return x < y
	var ta := pa[1] if pa.size() > 1 else ""
	var tb := pb[1] if pb.size() > 1 else ""
	return ta.naturalnocasecmp_to(tb) < 0


func _mark(b: Button) -> Control:
	return b.get_node_or_null("NewMark") as Control if b != null else null


func _menu_buttons(menu: Node) -> Array:
	return menu.get_children().filter(func(n: Node) -> bool: return n is Button)


func _new_things() -> Control:
	return _find(Router.current, func(n: Node) -> bool:
		return n.name == &"NewThingsPopup" and not n.is_queued_for_deletion()) as Control


func _all(root: Node, matches: Callable) -> Array:
	var out := []
	if matches.call(root):
		out.append(root)
	for c in root.get_children():
		out.append_array(_all(c, matches))
	return out


## The note as a letter: word for word (its body and its sign-off together),
## the "<3" a pixel heart before JON, the heading, and all of it on screen.
func _check_letter(w: WelcomePopup) -> void:
	var card := w.card
	var title := _find(w, func(n: Node) -> bool: return n.name == &"NoteTitle") as Label
	_ok("  headed %s" % WelcomePopup.TITLE, title != null and title.text == WelcomePopup.TITLE)
	_ok("  Jon's note, word for word", card.full_text == AlphaNotes.ALPHA_WELCOME
		and card.body.text + "\n\n<3\n\nJon" == AlphaNotes.ALPHA_WELCOME)
	var heart := _find(w, func(n: Node) -> bool: return n.name == &"Heart") as TextureRect
	var sig := _find(w, func(n: Node) -> bool: return n.name == &"Signature") as Label
	_ok("  signed with a pixel heart, then JON, right-aligned", heart != null and sig != null
		and sig.text == "JON" and heart.get_global_rect().end.x <= sig.get_global_rect().position.x
		and sig.get_global_rect().end.x >= card.body.get_global_rect().end.x - 2.0)
	var screen := (Router.current as Control).get_global_rect()
	print("    screen %s, panel %s, note scrolls: %s" % [screen,
		w.panel_rect(), w.note_scrolls()])
	_ok("  the panel is inside the screen", screen.grow(0.5).encloses(w.panel_rect()))
	# THE DIM REACHES THE GLASS (Jon, Oct 20: "a weird dark box around the
	# background ... in the corners and side of the screen"): the title's galaxy
	# runs past the screen's rect, which stops Main's margin short of the
	# picture's edge, so a dim the size of the screen left it lit round the note
	var dim := card.get_child(0) as ColorRect
	var pic := w.get_viewport_rect()
	_ok("  its dim covers the whole picture, Main's margin too (%s on %s)" % [
		dim.get_global_rect() if dim != null else Rect2(), pic],
		dim != null and dim.get_global_rect().grow(0.5).encloses(pic))
	_ok("  the note shows whole at the game's size (no scroll)", not w.note_scrolls())


func _welcome() -> WelcomePopup:
	return _find(Router.current, func(n: Node) -> bool:
		return n is WelcomePopup and not n.is_queued_for_deletion()) as WelcomePopup


func _button(root: Node, text: String) -> Button:
	return _find(root, func(n: Node) -> bool:
		return n is Button and (n as Button).text == text and (n as Button).is_visible_in_tree()) as Button


func _count_buttons(root: Node) -> int:
	var n := 1 if root is Button else 0
	for c in root.get_children():
		n += _count_buttons(c)
	return n


func _find(root: Node, matches: Callable) -> Node:
	if root == null:
		return null
	if matches.call(root):
		return root
	for c in root.get_children():
		var f := _find(c, matches)
		if f != null:
			return f
	return null


func _press(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(1)


func _finish() -> void:
	print("welcometest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
