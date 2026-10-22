class_name QuestPanel
extends PanelContainer

## THE QUESTS TABLE, opened by the HUD's QUESTS tab (Jon, Oct 22, design A:
## "I chose A, the JOBS tab", named QUESTS as the chart names them, and no count
## on the tab "so it doesn't change size"). Every quest you hold (`QuestLog`), a
## row each: its mark, its state, what to do, where (the system and its layer,
## or any of the poster's yards and the nearest), the jumps from you, the pay
## and the poster's flag and name. A row picked opens under itself: the note in
## the poster's own words, SHOW ON STARCHART and PLOT ROUTE.
##
## OVER WHATEVER IS UP -- LOCAL, the sector map, the chart, a station -- in the
## HUD's own column after the screens (where the goal line and A.S.H. stand),
## right of the goal line and of A.S.H.'s first place and under the HUD, so it
## covers neither. Closed by its tab, by CLOSE, by any change of screen, and by
## the escape menu opening over it.
##
## Only this ship's quests: `Run` is one ship, and a partner's are on theirs.

static var _open: QuestPanel = null
## The quest whose row is open, by contract id; -1 for none. Kept while the
## table is shut, so opening it again opens the same row.
static var picked: int = -1

## The table's columns, px: mark, state, quest, where, jumps, pay, from.
const COLS := [10.0, 74.0, 168.0, 150.0, 52.0, 48.0, 76.0]
const GAP := 8

## One quest's row: laid out by its own container (a Button lays nothing out,
## and its words piled on each other), pressed like a button, lit under the
## pointer as a button is.
class Row extends PanelContainer:
	signal pressed
	var open_row := false
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void: _look(true))
		mouse_exited.connect(func() -> void: _look(false))
	func _ready() -> void:
		_look(false)
	func _look(hot: bool) -> void:
		var bg := Color("#1a2534") if open_row else Color(0, 0, 0, 0)
		if hot:
			bg = Color("#1f2c3e")
		add_theme_stylebox_override("panel", UITheme.flat(bg,
			UITheme.BEVEL_HI if open_row or hot else Color(0, 0, 0, 0), 0, 3, 4))
	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			Audio.click()
			pressed.emit()


var _rows: VBoxContainer
## The screen it was opened over: another one up shuts it.
var _screen: Control
var _scroll: ScrollContainer
var _sub: Label


static func is_open() -> bool:
	return _open != null and is_instance_valid(_open)


static func toggle() -> void:
	if is_open():
		close()
	else:
		open()


static func open() -> QuestPanel:
	if is_open():
		return _open
	if Router.hud == null or not is_instance_valid(Router.hud) or Run.hull == null:
		return null
	var p := QuestPanel.new()
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


## Where it stands, global: under the HUD, right of the goal line's room and of
## A.S.H.'s first place on this screen, to the HUD's right edge.
static func frame_rect() -> Rect2:
	var hud := Router.hud.get_global_rect()
	var left := 290.0
	var cur := Router.current
	var st := GoalLine.stack_rect(cur)
	if st.size != Vector2.ZERO:
		left = maxf(left, st.end.x + 10.0)
	for r in keep_off():
		left = maxf(left, (r as Rect2).end.x + 10.0)
	var top := hud.end.y + 6.0
	return Rect2(Vector2(left, top), Vector2(hud.end.x - left, 540.0 - 12.0 - top))


## What the table must not cover beside the HUD: the goal line's room and
## A.S.H., where she is or where she would first stand.
static func keep_off() -> Array:
	var out: Array = []
	var cur := Router.current
	var st := GoalLine.stack_rect(cur)
	if st.size != Vector2.ZERO:
		out.append(st)
	if Ash.portrait != null and is_instance_valid(Ash.portrait) and Ash.portrait.visible:
		out.append(Ash.portrait.rect())
	elif st.size != Vector2.ZERO:
		out.append(Rect2(Vector2(st.position.x - 8.0, st.end.y + Ash.EDGE),
			Vector2(AshPortrait.W, AshPortrait.H)))
	return out


func _process(_d: float) -> void:
	# the escape menu opening over it shuts it, and so does any other screen
	if Hints.menu_up() or Router.current != _screen:
		QuestPanel.close()


func _build() -> void:
	add_theme_stylebox_override("panel", UITheme.bevel(UITheme.PANEL, 6, 8))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(UITheme.body("QUESTS", UITheme.ICE, UITheme.FS_HEAD))
	_sub = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_sub)
	var shut := Widgets.button("CLOSE", func() -> void: QuestPanel.close())
	shut.name = "Close"
	head.add_child(shut)
	col.add_child(head)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", GAP)
	for i in COLS.size():
		var l := UITheme.body(["", "STATE", "QUEST", "WHERE", "", "PAY", "FROM"][i], UITheme.COLD, UITheme.FS_SMALL)
		l.custom_minimum_size = Vector2(COLS[i], 0)
		cols.add_child(l)
	col.add_child(cols)
	col.add_child(UITheme.hsep())
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(_rows)
	col.add_child(_scroll)
	fill()


## The rows, again (a row picked, the run moved on).
func fill() -> void:
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	var list := QuestLog.entries()
	var ready := 0
	for e in list:
		if ((e as Dictionary).job as ContractData).state == ContractData.State.READY:
			ready += 1
	_sub.text = "" if list.is_empty() else ("%d SIGNED" % list.size()
		+ (" · %d READY TO HAND IN" % ready if ready > 0 else ""))
	if list.is_empty():
		var none := UITheme.body(QuestLog.EMPTY, UITheme.CHILL, UITheme.FS_SMALL)
		none.name = "Empty"
		_rows.add_child(none)
	for raw in list:
		_rows.add_child(_row(raw as Dictionary))
	_place()
	# and again once the rows have measured themselves in the tree
	_place.call_deferred()


## Sized to its rows, scrolled past the room under the HUD, at `frame_rect`.
func _place() -> void:
	if not is_inside_tree():
		return
	var fr := frame_rect()
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


func _row(e: Dictionary) -> Control:
	var job: ContractData = e.job
	var open_row := job.id == picked
	var b := Row.new()
	b.open_row = open_row
	b.set_meta(&"quest", job.id)
	b.name = "Quest%d" % job.id
	b.tooltip_text = Widgets.tip(String(e.tip))
	b.pressed.connect(func() -> void:
		picked = -1 if picked == job.id else job.id
		fill())
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	b.add_child(inner)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", GAP)
	var mark := Control.new()
	mark.custom_minimum_size = Vector2(COLS[0], 10)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var kind := int(e.kind)
	mark.draw.connect(func() -> void: QuestLog.draw_mark(mark, kind, Vector2.ZERO))
	line.add_child(mark)
	var st := PanelContainer.new()
	var sc: Color = e.state_colour
	st.add_theme_stylebox_override("panel", UITheme.flat(Color(sc, 0.16), sc, 0, 1, 4))
	st.custom_minimum_size = Vector2(COLS[1], 0)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st.add_child(UITheme.body(String(e.state), sc, UITheme.FS_SMALL))
	line.add_child(st)
	line.add_child(_cell(String(e.what).to_upper(), UITheme.ICE, COLS[2]))
	var where := VBoxContainer.new()
	where.add_theme_constant_override("separation", 0)
	where.custom_minimum_size = Vector2(COLS[3], 0)
	if int(e.place) < 0:
		where.add_child(_cell(String(e.where), UITheme.CHILL, COLS[3]))
	elif bool(e.yard):
		where.add_child(_cell("ANY %s YARD" % String(e.who).to_upper(), UITheme.CHILL, COLS[3]))
		where.add_child(_cell("NEAREST %s" % String(e.place_name), UITheme.COLD, COLS[3]))
	else:
		where.add_child(_cell(String(e.place_name), UITheme.CHILL, COLS[3]))
		where.add_child(_cell(String(e.layer), UITheme.COLD, COLS[3]))
	line.add_child(where)
	line.add_child(_cell(String(e.jumps), EncounterDrawer.TAG_QUEST, COLS[4]))
	line.add_child(_cell(String(e.pay), UITheme.EMBER, COLS[5]))
	var from := HBoxContainer.new()
	from.add_theme_constant_override("separation", 4)
	from.custom_minimum_size = Vector2(COLS[6], 0)
	from.add_child(_flag(job.manufacturer))
	var who := UITheme.body(String(e.who).to_upper(), DB.manufacturer_colour(job.manufacturer).lightened(0.2), UITheme.FS_SMALL)
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	from.add_child(who)
	line.add_child(from)
	inner.add_child(line)

	if open_row:
		var note := UITheme.body("\"%s\"" % job.text, UITheme.QUOTE, UITheme.FS_SMALL)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(_row_w() - 16.0, 0)
		inner.add_child(note)
		var acts := HBoxContainer.new()
		acts.add_theme_constant_override("separation", 6)
		var place := int(e.place)
		var can := place >= 0 and not (Router.in_combat() or Router.fight_up())
		var show := Widgets.button("SHOW ON STARCHART", func() -> void: QuestPanel.show_on_chart(job.id, false))
		show.name = "ShowOnStarchart"
		var plot := Widgets.button("PLOT ROUTE", func() -> void: QuestPanel.show_on_chart(job.id, true))
		plot.name = "PlotRoute"
		for a: Button in [show, plot]:
			a.disabled = not can
			if not can:
				a.tooltip_text = Widgets.tip("Not during a fight." if place >= 0 else "No yard of theirs is in reach.")
			acts.add_child(a)
		inner.add_child(acts)
	# the row's words are the row's, not things to press: the click goes to it
	# (SHOW ON STARCHART and PLOT ROUTE are buttons of their own)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in inner.find_children("*", "Control", true, false):
		if not (c is Button):
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _row_w() -> float:
	var w := 0.0
	for c: float in COLS:
		w += c
	return w + GAP * (COLS.size() - 1)


func _cell(text: String, colour: Color, w: float) -> Label:
	var l := UITheme.body(text, colour, UITheme.FS_SMALL)
	l.custom_minimum_size = Vector2(w, 0)
	l.clip_text = true
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _flag(m: StringName) -> Control:
	var mk: ManufacturerData = DB.manufacturers.get(m)
	var fl := ChassisSelect.Banner.new()
	fl.s = 1.0
	fl.custom_minimum_size = Vector2(ChassisSelect.Banner.UNITS_W, ChassisSelect.Banner.UNITS_H)
	fl.manufacturer = m
	if mk != null:
		fl.mark = mk.colour
		fl.field = mk.field
	return fl


## SHOW ON STARCHART / PLOT ROUTE: the chart, with the quest's place as the
## destination, its tag, and for PLOT ROUTE its route from YOU.
static func show_on_chart(id: int, route: bool) -> void:
	StarchartScreen.focus = {id = id, route = route}
	close()
	if Router.current is StarchartScreen:
		(Router.current as StarchartScreen).apply_focus()
		return
	Router.show_starchart()
	if Router.current is StarchartScreen:
		(Router.current as StarchartScreen).apply_focus()
