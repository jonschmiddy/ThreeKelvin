class_name KeyBindings
extends VBoxContainer

## CONTROLS, the last section of Settings: every key a player can move, by the
## screen it works on (`Keys`).
##
## A ROW IS AN ACTION: what the key does on the left, then two chips -- its
## key, and a second key if it has one -- and RESET, shown only on a row that
## has been changed, so a page of defaults is a quiet page and a moved key is
## easy to find again.
##
## CLICK A CHIP AND PRESS A KEY. Escape backs out without changing anything,
## and Backspace or Delete empties the slot. A key another action on the same
## screen already uses is not taken silently: the row says which action has it
## and offers SWAP (the two trade keys) or CANCEL.
##
## Built for the drawer's width, like the rest of Settings, and rebuilt only
## itself when a key changes -- the rest of the page and its scroll stay put.

const CHIP_W := 46.0
const RESET_W := 40.0

## The slot waiting for a key: an action and 0 (its key) or 1 (its second key).
var _action: StringName = &""
var _slot := -1
## A key that clashed, waiting on SWAP or CANCEL, and the slot it was for.
var _clash_action: StringName = &""
var _clash_slot := -1
var _clash_code := 0
## A line under a row after a refused change, until the next one.
var _note_action: StringName = &""
var _note := ""
var _asking_reset := false


func _init() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	Keys.changed.connect(_rebuild)
	_rebuild()


# ------------------------------------------------------------- what it shows

func _rebuild() -> void:
	Widgets.clear(self)
	for g: Dictionary in Keys.GROUPS:
		var ids := Keys.actions_in(g.id)
		if ids.is_empty():
			continue
		add_child(_gap(2))
		add_child(UITheme.body(String(g.name), UITheme.CHILL, UITheme.FS_SMALL))
		for id: StringName in ids:
			add_child(_row(id))
			_under(id)
	add_child(_gap(6))
	if _asking_reset:
		var ask := UITheme.body("PUT EVERY KEY BACK AS IT CAME?", UITheme.WARN, UITheme.FS_SMALL)
		ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(ask)
		var yn := _chips()
		var yes := DrawerPlate.chip_for("YES, RESET ALL", false, confirm_reset_all)
		yes.tone = DrawerPlate.Tone.BAD
		yn.add_child(yes)
		yn.add_child(DrawerPlate.chip_for("NO", false, cancel))
		add_child(yn)
	else:
		var all := DrawerPlate.chip_for("RESET ALL KEYS", false, ask_reset_all)
		all.tooltip_text = Widgets.tip("Every key back to how the game came. Asks first.")
		all.disabled = _all_default()
		add_child(all)


## One action: what it does, its two keys, and RESET if it has been moved.
func _row(id: StringName) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var what := UITheme.body(Keys.label(id), UITheme.COLD, UITheme.FS_SMALL)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	what.clip_text = true
	h.add_child(what)
	var s := Keys.slots(id)
	for slot in 2:
		var waiting := _action == id and _slot == slot
		# A clash shows the key it is asking about, lit, in the slot it would go in.
		var asking := _clash_action == id and _clash_slot == slot
		var text := Keys.key_name(int(s[slot]))
		if waiting:
			text = "?"
		elif asking:
			text = Keys.key_name(_clash_code)
		var chip := DrawerPlate.chip_for(text, false, listen.bind(id, slot))
		chip.lead = waiting or asking
		chip.custom_minimum_size = Vector2(CHIP_W, DrawerPlate.CHIP_H)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_END
		chip.tooltip_text = Widgets.tip(
			"Click, then press the key for this." if slot == 0
			else "A second key that does the same. Click, then press it.")
		h.add_child(chip)
	if Keys.is_default(id):
		h.add_child(_gap_w(RESET_W))
	else:
		var r := DrawerPlate.chip_for("RESET", false, func() -> void:
			_settle()
			Keys.reset(id))
		r.custom_minimum_size = Vector2(RESET_W, DrawerPlate.CHIP_H)
		r.size_flags_horizontal = Control.SIZE_SHRINK_END
		r.tooltip_text = Widgets.tip("Back to %s." % Keys.key_name(int(Keys.defaults(id)[0])))
		h.add_child(r)
	return h


## What goes under a row: "press a key", a clash and its choice, or a refusal.
func _under(id: StringName) -> void:
	if _action == id:
		var what := "PRESS A KEY FOR %s. ESC CANCELS" % Keys.label(id)
		# Only when Delete would do something: the slot has a key, and it is not
		# the action's only one.
		var s := Keys.slots(id)
		if int(s[_slot]) != 0 and int(s[1]) != 0:
			what += ", DEL EMPTIES IT"
		add_child(_line(what + ".", UITheme.FLARE))
	elif _clash_action == id:
		add_child(_line(clash_text(), UITheme.WARN))
		var row := _chips()
		var swap_b := DrawerPlate.chip_for("SWAP", false, swap)
		swap_b.tooltip_text = Widgets.tip(
			"This action takes the key, and the other gets the key this one had.")
		row.add_child(swap_b)
		row.add_child(DrawerPlate.chip_for("CANCEL", false, cancel))
		add_child(row)
	elif _note_action == id and _note != "":
		add_child(_line(_note, UITheme.WARN))


func _line(text: String, colour: Color) -> Label:
	var l := UITheme.body(text, colour, UITheme.FS_SMALL)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _chips() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	return r


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _gap_w(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	return c


func _all_default() -> bool:
	for id: StringName in Keys.actions():
		if not Keys.is_default(id):
			return false
	return true


## The clash, said: which key, which action has it, and what SWAP would do.
func clash_text() -> String:
	if _clash_action == &"":
		return ""
	var key := Keys.key_name(_clash_code)
	var parts: Array[String] = []
	for other: StringName in Keys.clashes(_clash_action, _clash_code):
		var where := ""
		if Keys.group_of(other) != Keys.group_of(_clash_action):
			where = " (%s)" % Keys.group_name(Keys.group_of(other))
		parts.append(Keys.label(other) + where)
	var who := " AND ".join(parts)
	var old := int(Keys.slots(_clash_action)[_clash_slot])
	if old != 0:
		return "%s IS ALREADY %s. SWAP GIVES %s %s." % [key, who, who, Keys.key_name(old)]
	# Nothing to give back: this was an empty second slot. Say plainly when the
	# other action would be left with no key at all.
	var bare: Array[String] = []
	for other: StringName in Keys.clashes(_clash_action, _clash_code):
		var s := Keys.slots(other)
		if (int(s[0]) == _clash_code and int(s[1]) == 0) or (int(s[1]) == _clash_code and int(s[0]) == 0):
			bare.append(Keys.label(other))
	var after := " %s WILL HAVE NO KEY." % " AND ".join(bare) if not bare.is_empty() else ""
	return "%s IS ALREADY %s. SWAP TAKES IT.%s" % [key, who, after]


# ------------------------------------------------------------- what it does

## Start waiting for a key for this slot. Clicking the waiting chip again stops.
func listen(id: StringName, slot: int) -> void:
	var again := _action == id and _slot == slot
	_settle()
	if not again:
		_action = id
		_slot = slot
	_rebuild()


func listening() -> bool:
	return _action != &""


## A key, as if it had been pressed while a slot was waiting. Public so
## `-- bindtest` and the settings shot can drive it without a keyboard.
func offer(code: int) -> void:
	if _action == &"":
		return
	var id := _action
	var slot := _slot
	_settle()
	if code == KEY_ESCAPE:
		_rebuild()
		return
	if code == KEY_BACKSPACE or code == KEY_DELETE:
		if not Keys.clear(id, slot):
			_note_action = id
			_note = "%s NEEDS A KEY. GIVE IT ANOTHER FIRST." % Keys.label(id) \
				if int(Keys.slots(id)[slot]) != 0 else ""
			_rebuild()
		return
	var hits := Keys.clashes(id, code)
	if hits.is_empty():
		if not Keys.set_key(id, slot, code):
			_rebuild()
		return
	_clash_action = id
	_clash_slot = slot
	_clash_code = code
	_rebuild()


func swap() -> void:
	if _clash_action == &"":
		return
	var id := _clash_action
	var slot := _clash_slot
	var code := _clash_code
	_settle()
	Keys.swap_in(id, slot, code)


func cancel() -> void:
	_settle()
	_rebuild()


func ask_reset_all() -> void:
	_settle()
	_asking_reset = true
	_rebuild()


func confirm_reset_all() -> void:
	_settle()
	Keys.reset_all()


## Forget whatever was waiting: a slot, a clash, a question, a note.
func _settle() -> void:
	_action = &""
	_slot = -1
	_clash_action = &""
	_clash_slot = -1
	_clash_code = 0
	_note_action = &""
	_note = ""
	_asking_reset = false


## THE KEY, CAUGHT FIRST. `_input`, ahead of everything else in the game, so a
## key pressed for a binding does not also open the menu, change the screen or
## fly the ship. Every key event is eaten while a slot is waiting, the release
## too. Escape also backs out of a clash or the RESET ALL question before it
## can reach the menu.
func _input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null:
		return
	if _action != &"":
		get_viewport().set_input_as_handled()
		if not k.pressed or k.echo:
			return
		var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
		if code != KEY_NONE:
			offer(code)
		return
	if (_clash_action != &"" or _asking_reset) and k.pressed and not k.echo \
			and k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancel()
