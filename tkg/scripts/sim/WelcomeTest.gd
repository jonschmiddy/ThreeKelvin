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
