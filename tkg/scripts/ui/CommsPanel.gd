class_name CommsPanel
extends PanelContainer

## COMMS, opened by the HUD's COMMS tab (Jeremy, a playtester, Oct 23: "The AI
## is amazing, but it doesn't need to repeat everything when I jump out of a
## menu after it has already said it. Give me an option to revisit all
## communications."). Everything A.S.H. has said aloud this run (`Ash.comms`):
## her quips, her teaching lines and the goal steps, newest first, a row each
## with the jump it was said on and her words. A row with her voice has PLAY,
## which says it again; a line said as text alone has none.
##
## THE HUD, NOT THE ESCAPE MENU: the bar had the room. Measured on LOCAL at the
## 960 picture, its row wants 655 px of 932 with developer mode off and 785 with
## it on; COMMS is 42 more (702 and 832), and a party's PARTY tab about as much
## again, still under. `-- sheet=AshTutorTest` holds the row to fitting.
##
## LAID OUT AS THE QUESTS TABLE IS (`QuestPanel`): over whatever is up, in the
## HUD's column after the screens, right of the goal line and of A.S.H.'s first
## place and under the HUD (`QuestPanel.frame_rect`), so it covers neither. One
## of the two is open at a time. Closed by its tab, by CLOSE, by any change of
## screen and by the escape menu opening over it. No count on the tab, ever, so
## it never changes size.

static var _open: CommsPanel = null

## The jump column and PLAY's, px.
const JUMP_W := 52.0
const PLAY_W := 44.0
const GAP := 8
## What it says with nothing said yet.
const EMPTY := "Nothing said yet this run."

var _rows: VBoxContainer
var _scroll: ScrollContainer
var _screen: Control
## How many lines were in the log when the rows were made: more, and they are
## made again (never every frame: a button rebuilt under the pointer cannot be
## clicked).
var _count := -1


static func is_open() -> bool:
	return _open != null and is_instance_valid(_open)


static func toggle() -> void:
	if is_open():
		close()
	else:
		open()


static func open() -> CommsPanel:
	if is_open():
		return _open
	if Router.hud == null or not is_instance_valid(Router.hud) or Run.hull == null:
		return null
	# (one table over the picture at a time)
	if QuestPanel.is_open():
		QuestPanel.close()
	var p := CommsPanel.new()
	p.name = "CommsPanel"
	p.top_level = true
	p.z_index = 45
	Router.hud.get_parent().add_child(p)
	_open = p
	p._screen = Router.current
	p._build()
	Router.hud.refresh()
	return p


static func close() -> void:
	if is_open():
		_open.queue_free()
	_open = null
	if Router.hud != null and is_instance_valid(Router.hud):
		Router.hud.refresh()


func _process(_d: float) -> void:
	# the escape menu opening over it shuts it, and so does any other screen
	if Hints.menu_up() or Router.current != _screen:
		CommsPanel.close()
		return
	if Ash.comms.size() != _count:
		fill()
	# PLAY waits while she speaks (it would talk over her), lit again after
	var can := Ash.can_replay()
	for b in _rows.find_children("Play*", "Button", true, false):
		(b as Button).disabled = not can


func _build() -> void:
	add_theme_stylebox_override("panel", UITheme.bevel(UITheme.PANEL, 6, 8))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(UITheme.body("COMMS", UITheme.ICE, UITheme.FS_HEAD))
	var sub := UITheme.body("WHAT A.S.H. SAID THIS RUN, NEWEST FIRST", UITheme.COLD, UITheme.FS_SMALL)
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sub)
	var shut := Widgets.button("CLOSE", func() -> void: CommsPanel.close())
	shut.name = "Close"
	head.add_child(shut)
	col.add_child(head)
	col.add_child(UITheme.hsep())
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(_rows)
	col.add_child(_scroll)
	fill()


## The rows, again: newest first.
func fill() -> void:
	_count = Ash.comms.size()
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	if Ash.comms.is_empty():
		var none := UITheme.body(EMPTY, UITheme.CHILL, UITheme.FS_SMALL)
		none.name = "Empty"
		_rows.add_child(none)
	for i in range(Ash.comms.size() - 1, -1, -1):
		_rows.add_child(_row(i, Ash.comms[i] as Dictionary))
	_place()
	# and again once the rows have measured themselves in the tree
	_place.call_deferred()


## Sized to its rows, scrolled past the room under the HUD, where the quests
## table stands.
func _place() -> void:
	if not is_inside_tree():
		return
	var fr := QuestPanel.frame_rect()
	reset_size()
	_scroll.custom_minimum_size = Vector2(0, 0)
	var want := _rows.get_combined_minimum_size().y
	var head := get_combined_minimum_size().y
	var room := fr.size.y - head
	_scroll.custom_minimum_size = Vector2(0, minf(want, maxf(40.0, room)))
	size = Vector2(fr.size.x, 0)
	reset_size()
	size.x = fr.size.x
	position = fr.position


## The words' column: what the frame leaves after the jump and PLAY.
func _words_w() -> float:
	return maxf(120.0, QuestPanel.frame_rect().size.x - 16.0 - JUMP_W - PLAY_W - GAP * 2)


func _row(i: int, e: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.name = "Said%d" % i
	line.set_meta(&"comms", i)
	line.add_theme_constant_override("separation", GAP)
	var j := UITheme.body("JUMP %d" % int(e.get("jump", 0)), UITheme.COLD, UITheme.FS_SMALL)
	j.custom_minimum_size = Vector2(JUMP_W, 0)
	j.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(j)
	var words := UITheme.body(String(e.line), UITheme.ICE if bool(e.get("tutorial", false)) else UITheme.QUOTE,
		UITheme.FS_SMALL)
	words.name = "Words"
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size = Vector2(_words_w(), 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(words)
	if String(e.get("voice", "")) != "":
		var play := Widgets.button("PLAY", func() -> void: Ash.replay(i))
		play.name = "Play%d" % i
		play.custom_minimum_size = Vector2(PLAY_W, 0)
		play.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		play.tooltip_text = Widgets.tip("Hear her say it again.")
		line.add_child(play)
	else:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(PLAY_W, 0)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(gap)
	return line
