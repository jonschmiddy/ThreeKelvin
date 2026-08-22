class_name ArchiveScreen
extends Control

## Somebody else's paperwork, and the only place in the game that is quiet.
##
## Two panels: what you have recovered on the left, the page itself on the right.
## The list is the WHOLE catalogue — read entries by name, unread ones as a rule
## of redacted characters — because a count of 14/16 with two blanks under it is
## a different feeling from a list that simply stops, and the feeling is the
## content here.
##
## `docs/lore.md` §5 is the contract this screen serves and it is worth restating
## where it can be broken: PRIMARY SOURCES, NEVER EXPOSITION. Nothing on this
## page is written in the voice of the game. There is no summary, no index of
## factions, no timeline, no map key, and no entry that explains what the heat is
## for — because no such answer exists to be written. If a future entry starts
## sounding like a narrator, the entry is wrong, not the screen.
##
## Deliberately reachable and deliberately not required. A player who never opens
## this should still be able to say what the world is like, because the prices,
## the log lines and the module flavour carry it. This is the corner, not the
## setting.

## Where LEAVE returns to. Reached from the HUD in a run and from the title
## screen out of one, and those go back to different places.
var _back: Callable = Callable()

var _list: VBoxContainer
var _page: VBoxContainer
var _count: Label
var _open: StringName = &""
## The rows, so opening one can un-light the others without a rebuild.
var _rows: Dictionary = {}

## The left rail. Wide enough for the longest title at FS_SMALL — "ROUTING
## MANIFEST, BANKED THERMAL" is the measure — plus the room a redacted rule needs
## to look deliberate rather than clipped.
const RAIL_W := 268
## An unread entry, drawn as the shape of a title rather than as nothing. Long
## enough to read as a withheld line, short enough that a column of them does not
## look like damage.
const REDACTED := "— — — — — — — —"


func setup(back: Callable = Callable()) -> void:
	_back = back
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Sig.archive_changed.connect(_refresh)
	_refresh()
	# Opened on the newest thing you have not read, or on the first entry. A
	# screen that opens on an empty right-hand panel makes the player click
	# before it has said anything.
	# `-- archive all open=vault_routing` lands on a named entry. The screen opens
	# on the shallowest thing you have read, which is correct for a player and
	# useless for looking at one particular page.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("open="):
			var want := StringName(a.split("=")[1])
			if Archive.has(want):
				_show(want)
				return
	_open_first()


func _build() -> void:
	var pad := Widgets.pad(null, 12, 8)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	pad.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(UITheme.header("THE ARCHIVE"))
	_count = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_count)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	top.add_child(Widgets.button("LEAVE", func() -> void:
		if _back.is_valid():
			_back.call()
		else:
			Router.show_sector()))
	col.add_child(top)
	col.add_child(UITheme.hsep())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left := ScrollContainer.new()
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.custom_minimum_size = Vector2(RAIL_W, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_list)
	row.add_child(Widgets.panel_with(left))

	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 5)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := ScrollContainer.new()
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_page)
	var wrap := Widgets.panel_with(right)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(wrap)


func _refresh() -> void:
	Widgets.clear(_list)
	_rows.clear()
	_count.text = "%d / %d RECOVERED" % [Archive.count(), Archive.total()]

	# Shallowest first, which is roughly the order a player finds them and
	# exactly the order they get stranger in.
	for d in DB.documents_by_depth(MapGen.LAYERS):
		var doc: DocumentData = d
		_list.add_child(_row(doc))


func _row(d: DocumentData) -> Control:
	var read := Archive.has(d.id)
	var b := Widgets.button("", func() -> void:
		if read:
			_show(d.id))
	b.text = d.title if read else REDACTED
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not read
	if read:
		b.tooltip_text = Widgets.tip(Archive.where(d.id))
	else:
		# Says what is missing without saying what it is. A locked entry that
		# names itself has already been read.
		b.tooltip_text = Widgets.tip(
			"Not recovered. Somewhere at layer %d or deeper." % d.depth)
		b.add_theme_color_override("font_disabled_color",
			Color(UITheme.COLD.r, UITheme.COLD.g, UITheme.COLD.b, 0.30))
	_rows[d.id] = b
	return b


## Open the page.
##
## The right panel is rebuilt rather than updated: an entry is a handful of
## labels and this runs on a click, so there is nothing to gain by diffing and a
## whole class of stale-field bug to avoid.
func _show(id: StringName) -> void:
	if not DB.documents.has(id) or not Archive.has(id):
		return
	_open = id
	var d: DocumentData = DB.documents[id]
	Widgets.clear(_page)

	_page.add_child(UITheme.body(d.title, UITheme.ICE, UITheme.FS_BODY))
	# Who held the pen, and when they thought it was. The epochs do not
	# reconcile and are not meant to — see Database._seed_documents.
	var by := UITheme.body("%s · %s" % [d.by, d.dated],
		DB.manufacturer_colour(d.house) if d.house != &"" else UITheme.COLD,
		UITheme.FS_SMALL)
	by.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(by)
	_page.add_child(UITheme.hsep())

	# The document itself, at the body size and wrapped. QUOTE grey rather than
	# CHILL: this is not the game talking to the player, and the colour is the
	# cheapest way to say so before a word is read.
	var text := UITheme.body(d.body, UITheme.CHILL, UITheme.FS_SMALL)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(text)

	_page.add_child(UITheme.hsep())
	# WHERE YOU GOT IT, last and quiet. The same manifest off a rim wreck and a
	# hulk at the core is not the same document, and this is the half that says
	# so — see DocumentData.found_at.
	var where := UITheme.body(Archive.where(id), UITheme.QUOTE, UITheme.FS_SMALL)
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(where)

	for key in _rows:
		var b: Button = _rows[key]
		b.modulate = Color.WHITE if key == id else Color(0.72, 0.76, 0.82)


func _open_first() -> void:
	for d in DB.documents_by_depth(MapGen.LAYERS):
		var doc: DocumentData = d
		if Archive.has(doc.id):
			_show(doc.id)
			return
	# Nothing recovered yet. Said in the register of the screen rather than in
	# the register of a tutorial — the archive does not explain itself any more
	# than the documents in it do.
	Widgets.clear(_page)
	var empty := UITheme.body(
		"Nothing recovered yet.\n\nPeople leave paperwork. Strip a wreck, fly a pulsar, finish a fight — whatever is still readable comes back with you.",
		UITheme.QUOTE, UITheme.FS_SMALL)
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(empty)
