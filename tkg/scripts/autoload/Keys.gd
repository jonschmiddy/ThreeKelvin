extends Node

## THE KEYS, BY NAME. Every key the game listens for that a player may move,
## held as a Godot InputMap action with a label a player reads in Settings.
##
## Jon: "We need a way to bind keys and such." Before this every screen read a
## keycode straight off the event (`k.keycode == KEY_R`), so a key was wherever
## the line that read it said it was. Now a screen asks for the ACTION
## (`event.is_action_pressed(&"hold_turn")`) and this file is the one place that
## says which key that is.
##
## TWO SLOTS AN ACTION, a primary and an optional second key, which is what a
## player who wants the arrows AND WASD on the ship needs and no more. The
## defaults fill only the primary, so with nothing rebound the game reacts to
## exactly the keys it reacted to before.
##
## A CLASH IS ONLY A CLASH WHERE BOTH KEYS COULD BE PRESSED. W thrusts on the
## sector map and pans the star chart; those two screens are never up together,
## so the same key doing both is fine and is how it shipped. GENERAL is live
## on every screen, so it clashes with everything; and the hold's keys clash
## with the sector map's because the salvage drawer opens over that map
## (`TOGETHER`).
##
## WHAT IS NOT HERE, ON PURPOSE. Escape opens the menu and backs out of
## everything, including this screen's own "press a key", so it cannot be
## moved -- a player who bound it to something else could lock themselves out
## of the menu. Backspace and Delete are how Settings clears a key. The "any
## key" moments (the chart's first-visit card, skipping a jump) take any key by
## design. Mouse clicks, drags and the wheel are not keys. See `FIXED`.
##
## SAVED BESIDE THE OTHER SETTINGS, in `user://settings.cfg` under [keys], and
## only the actions a player has moved: an action left alone keeps following
## the default, so a default changed in a later build reaches them.

signal changed

const SECTION := "keys"

## The screens a key belongs to, in the order Settings lists them.
const GENERAL := &"general"
const HOLD := &"hold"
const SECTOR := &"sector"
const CHART := &"chart"

const GROUPS := [
	{"id": GENERAL, "name": "EVERYWHERE"},
	{"id": HOLD, "name": "SHIP AND HOLD"},
	{"id": SECTOR, "name": "SECTOR MAP"},
	{"id": CHART, "name": "STAR CHART"},
]

## Groups that can be on screen at the same time, besides GENERAL (which is
## with everything). The salvage drawer -- a hold you turn parts in -- opens
## over the sector map.
const TOGETHER := [[HOLD, SECTOR]]

## Every action a player can move: its name, the screen it works on, what
## Settings calls it, and its key out of the box.
const ACTIONS := [
	{"id": &"next_screen", "group": GENERAL, "label": "NEXT SCREEN", "key": KEY_TAB},
	{"id": &"fullscreen", "group": GENERAL, "label": "FULLSCREEN", "key": KEY_F11},

	{"id": &"hold_turn", "group": HOLD, "label": "TURN PART", "key": KEY_R},
	{"id": &"part_flip", "group": HOLD, "label": "FLIP PART", "key": KEY_F},
	{"id": &"ship_zoom", "group": HOLD, "label": "ZOOM SHIP", "key": KEY_Z},

	{"id": &"ship_thrust", "group": SECTOR, "label": "THRUST", "key": KEY_W},
	{"id": &"ship_brake", "group": SECTOR, "label": "BRAKE", "key": KEY_S},
	{"id": &"ship_left", "group": SECTOR, "label": "TURN LEFT", "key": KEY_A},
	{"id": &"ship_right", "group": SECTOR, "label": "TURN RIGHT", "key": KEY_D},
	{"id": &"map_up", "group": SECTOR, "label": "PAN UP", "key": KEY_UP},
	{"id": &"map_down", "group": SECTOR, "label": "PAN DOWN", "key": KEY_DOWN},
	{"id": &"map_left", "group": SECTOR, "label": "PAN LEFT", "key": KEY_LEFT},
	{"id": &"map_right", "group": SECTOR, "label": "PAN RIGHT", "key": KEY_RIGHT},
	{"id": &"map_location", "group": SECTOR, "label": "LOCATION", "key": KEY_L},
	{"id": &"event_prev", "group": SECTOR, "label": "PREVIOUS EVENT", "key": KEY_BRACKETLEFT},
	{"id": &"event_next", "group": SECTOR, "label": "NEXT EVENT", "key": KEY_BRACKETRIGHT},

	# The arrows pan the chart too, as they pan the sector map (Jon, 2026-10-03).
	{"id": &"chart_up", "group": CHART, "label": "PAN UP", "key": KEY_W, "key2": KEY_UP},
	{"id": &"chart_down", "group": CHART, "label": "PAN DOWN", "key": KEY_S, "key2": KEY_DOWN},
	{"id": &"chart_left", "group": CHART, "label": "PAN LEFT", "key": KEY_A, "key2": KEY_LEFT},
	{"id": &"chart_right", "group": CHART, "label": "PAN RIGHT", "key": KEY_D, "key2": KEY_RIGHT},
	{"id": &"chart_region", "group": CHART, "label": "LOCAL REGION", "key": KEY_L},
]

## Keys no action may take. Escape is the menu and the way out of every
## "press a key"; Backspace and Delete clear a key in Settings.
const FIXED := [KEY_ESCAPE, KEY_BACKSPACE, KEY_DELETE]

## Where the bindings are kept. A var so `-- bindtest` can point it at a file
## of its own and never touch the player's settings.
var path: String = DisplaySettings.PATH

## action -> [primary, secondary] keycodes, 0 for an empty slot.
var _bound: Dictionary = {}
## action -> its row in ACTIONS.
var _info: Dictionary = {}


func _ready() -> void:
	for row: Dictionary in ACTIONS:
		_info[row.id] = row
		if not InputMap.has_action(row.id):
			InputMap.add_action(row.id)
	for id: StringName in _info:
		_bound[id] = defaults(id)
		_apply(id)
	load_keys()


# ------------------------------------------------------------------ reading

## Every action, in Settings' order.
func actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for row: Dictionary in ACTIONS:
		out.append(row.id)
	return out


func actions_in(group: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for row: Dictionary in ACTIONS:
		if row.group == group:
			out.append(row.id)
	return out


func label(action: StringName) -> String:
	return String(_info.get(action, {}).get("label", String(action).to_upper()))


func group_of(action: StringName) -> StringName:
	return _info.get(action, {}).get("group", GENERAL)


func group_name(group: StringName) -> String:
	for g: Dictionary in GROUPS:
		if g.id == group:
			return g.name
	return String(group).to_upper()


## [primary, secondary], 0 for an empty slot. A copy.
func slots(action: StringName) -> Array:
	return (_bound.get(action, [0, 0]) as Array).duplicate()


func defaults(action: StringName) -> Array:
	var row: Dictionary = _info.get(action, {})
	return [int(row.get("key", 0)), int(row.get("key2", 0))]


func is_default(action: StringName) -> bool:
	return slots(action) == defaults(action)


## True while any key bound to `action` is down on the keyboard.
##
## For letting go of a held key whose release went missing (alt-tab, a snip
## shortcut, a lost window): it can only ever say a key is UP, so a screen that
## asks it can stop something, never start it.
func held(action: StringName) -> bool:
	for code: int in _bound.get(action, []):
		if code != 0 and Input.is_key_pressed(code as Key):
			return true
	return false


## What Settings writes on a chip: one key, short.
static func key_name(code: int) -> String:
	match code:
		0: return "--"
		KEY_UP: return "UP"
		KEY_DOWN: return "DOWN"
		KEY_LEFT: return "LEFT"
		KEY_RIGHT: return "RIGHT"
		KEY_BRACKETLEFT: return "["
		KEY_BRACKETRIGHT: return "]"
		KEY_SEMICOLON: return ";"
		KEY_APOSTROPHE: return "'"
		KEY_COMMA: return ","
		KEY_PERIOD: return "."
		KEY_SLASH: return "/"
		KEY_BACKSLASH: return "\\"
		KEY_MINUS: return "-"
		KEY_EQUAL: return "="
		KEY_QUOTELEFT: return "`"
		KEY_ESCAPE: return "ESC"
		KEY_ENTER: return "ENTER"
		KEY_KP_ENTER: return "PAD ENTER"
		KEY_PAGEUP: return "PG UP"
		KEY_PAGEDOWN: return "PG DN"
		KEY_CAPSLOCK: return "CAPS"
		KEY_INSERT: return "INS"
		KEY_DELETE: return "DEL"
		KEY_BACKSPACE: return "BKSP"
		KEY_CTRL: return "CTRL"
	var s := OS.get_keycode_string(code as Key).to_upper()
	if s.begins_with("KP "):
		s = "PAD " + s.substr(3)
	return s if s != "" else "KEY %d" % code


## Every key bound to `action`, for a line of prose: "W" or "W OR UP".
func describe(action: StringName) -> String:
	var names: Array[String] = []
	for code: int in _bound.get(action, []):
		if code != 0:
			names.append(key_name(code))
	return " OR ".join(names) if not names.is_empty() else "NO KEY"


static func fixed(code: int) -> bool:
	return code in FIXED


## Could these two groups' keys both be live at once?
static func overlap(a: StringName, b: StringName) -> bool:
	if a == b or a == GENERAL or b == GENERAL:
		return true
	for pair: Array in TOGETHER:
		if a in pair and b in pair:
			return true
	return false


## Every OTHER action that `code` would collide with if `action` took it.
func clashes(action: StringName, code: int) -> Array[StringName]:
	var out: Array[StringName] = []
	if code == 0:
		return out
	var mine := group_of(action)
	for other: StringName in _bound:
		if other == action or not overlap(mine, group_of(other)):
			continue
		if code in (_bound[other] as Array):
			out.append(other)
	return out


# ------------------------------------------------------------------ changing

## Put `code` in `action`'s slot (0 primary, 1 second key). Refuses a fixed key.
## Does NOT look for clashes: Settings asks `clashes` first and either calls
## `swap_in` or does not call this at all.
##
## The same key already in the action's other slot swaps the two, rather than
## binding one key twice.
func set_key(action: StringName, slot: int, code: int) -> bool:
	if not _bound.has(action) or slot < 0 or slot > 1 or fixed(code):
		return false
	var s: Array = _bound[action]
	if code != 0 and s[1 - slot] == code:
		s[1 - slot] = s[slot]
	s[slot] = code
	_tidy(s)
	_apply(action)
	save_keys()
	changed.emit()
	return true


## Take `code` for `action` and hand every action it clashed with the key this
## slot had, so nothing is left doing two things -- the SWAP in Settings.
func swap_in(action: StringName, slot: int, code: int) -> bool:
	if not _bound.has(action) or fixed(code):
		return false
	var old: int = (_bound[action] as Array)[slot]
	for other: StringName in clashes(action, code):
		var s: Array = _bound[other]
		for i in 2:
			if s[i] == code:
				s[i] = old if not (old in s) else 0
		_tidy(s)
		_apply(other)
	return set_key(action, slot, code)


## Empty a slot. Emptying the primary moves the second key up; an action with
## only one key keeps it, because a key nobody can press is not a setting.
func clear(action: StringName, slot: int) -> bool:
	if not _bound.has(action):
		return false
	var s: Array = _bound[action]
	if slot == 0 and s[1] == 0:
		return false
	if s[slot] == 0:
		return false
	s[slot] = 0
	_tidy(s)
	_apply(action)
	save_keys()
	changed.emit()
	return true


func reset(action: StringName) -> void:
	if not _bound.has(action):
		return
	_bound[action] = defaults(action)
	_apply(action)
	save_keys()
	changed.emit()


func reset_all() -> void:
	for id: StringName in _bound:
		_bound[id] = defaults(id)
		_apply(id)
	save_keys()
	changed.emit()


## A second key with no first is moved up into the first.
func _tidy(s: Array) -> void:
	if s[0] == 0 and s[1] != 0:
		s[0] = s[1]
		s[1] = 0


## Into Godot's InputMap, which is what every screen actually asks.
##
## By KEYCODE, the letter the layout types, which is what every screen read
## before this (`k.keycode == KEY_W`). No modifiers: shift-R still turns a part,
## as it always did.
func _apply(action: StringName) -> void:
	InputMap.action_erase_events(action)
	for code: int in _bound[action]:
		if code == 0:
			continue
		var e := InputEventKey.new()
		e.keycode = code as Key
		InputMap.action_add_event(action, e)


# ------------------------------------------------------------------ the file

## Into settings.cfg's [keys], loaded first so display, audio and dev survive
## -- the same rule DisplaySettings.save learned the hard way. Only what a
## player has moved is written.
func save_keys() -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	if cfg.has_section(SECTION):
		cfg.erase_section(SECTION)
	for id: StringName in _bound:
		if not is_default(id):
			cfg.set_value(SECTION, String(id), slots(id))
	cfg.save(path)


## From the file, over the defaults. Anything malformed or fixed is ignored and
## that action keeps its default: a hand-edited file cannot take the menu key.
func load_keys() -> void:
	for id: StringName in _bound:
		_bound[id] = defaults(id)
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK and cfg.has_section(SECTION):
		for key: String in cfg.get_section_keys(SECTION):
			var id := StringName(key)
			var v: Variant = cfg.get_value(SECTION, key, null)
			if not _bound.has(id) or typeof(v) != TYPE_ARRAY or (v as Array).size() != 2:
				continue
			var s: Array = [int((v as Array)[0]), int((v as Array)[1])]
			if fixed(s[0]) or fixed(s[1]) or (s[0] == 0 and s[1] == 0):
				continue
			_tidy(s)
			_bound[id] = s
	for id: StringName in _bound:
		_apply(id)
	changed.emit()
