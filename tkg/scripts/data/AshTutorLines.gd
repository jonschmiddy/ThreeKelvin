class_name AshTutorLines
extends RefCounted

## A.S.H. TEACHING (Jon picked how A for the tutorial, Oct 17: "A.S.H. replaces
## the hint cards"). Her corner says each first-run hint (`Hints`) and each goal
## step (`GoalLine`) in these words, and the thing she means gets an outline.
## With her switched off, the cards come back with their own words
## (`Hints.lines`), exactly as before. These are Jon's picks, character for
## character; `{}` fields are filled from the live game when she says them
## (`fill`), never a number written here.
##
## A LINE'S ID is the hint's id, except where one hint has several lines (the
## fuel hint: a dock in reach, none, or here) and the goal steps (`step_*`).
##
## HER VOICE: one take per line id, `VOICE_DIR` + `tut_<id>.ogg`, the folder her
## other takes are in. A missing take is silence and the words still show. A
## line with a field (`FIELD`) may have a take per value, `tut_<id>_<value>.ogg`
## (`tut_endturn_5.ogg`), used when it exists; otherwise the base take. No take
## has been recorded yet (Oct 17): every line is text alone until Jon approves
## the spend.

const LINES: Dictionary = {
	&"chart": "These stars are in reach. Left bar is danger. Right bar is fuel.",
	&"events": "Click an event to read it. GO flies us there.",
	&"drawer": "Pick one. Some choices show the odds. The rest are a surprise.",
	&"hand": "Drag a card onto an enemy to fire. Top left is its energy cost.",
	&"intent": "That's what it will do when you press END TURN.",
	&"endturn": "Out of energy. Press END TURN. They act, then you draw {hand} cards.",
	&"brace": "Brace stops damage till gone. Holding it costs 1 heat a turn.",
	&"heat": "Heat. Past {cap}, we lose 1 hull per point over, at end of turn.",
	&"salvage": "Drag a part into the hold. Double-click works too.",
	&"cutaway": CUTAWAY_LINE,
	&"wreck": "Click a wreck to loot it. Its parts and credits are ours.",
	&"loot": "SECTOR LOOT is what's loose here. It stays until you take it.",
	&"dock": "Stations repair, refuel and trade. Pick a deck on the left.",
	&"fuel_dock": "Fuel is low. Run dry and the run ends. Nearest dock is {jumps} jumps: {name}.",
	&"fuel_none": "Fuel is low, and empty ends the run. No dock in reach. Jump short and look.",
	&"fuel_here": "Fuel is low. Run dry and the run ends. Refuel here before we go.",
	&"ship": "Click the ship to open it up. You fit and swap parts in there.",
	&"step_jump": "Open STARCHART. Pick a star in range, then press JUMP.",
	&"step_jump_chart": "Pick a star in range, then press JUMP.",
	&"step_event": "Open SECTOR. Click an event, then press GO.",
	&"step_event_map": "Click an event, then press GO.",
}

## THE CUTAWAY'S LINE is Jon's A (Oct 18): the keys show in the text but her
## voice never says them, since a player may have rebound them.
const CUTAWAY_LINE := "Drag a part onto a ring to fit it. You can turn it ({turn}) and flip it ({flip})."

## The field a line's per-value takes are keyed by.
const FIELD: Dictionary = {&"endturn": "hand", &"heat": "cap", &"fuel_dock": "jumps"}

## Words typed but never spoken: the dock's name (3,024 of them) follows her
## last word at her own pace.
const UNSPOKEN := ["{name}"]

const VOICE_DIR := "res://assets/audio/voice/ash/"


## The line id for hint `id` now (the fuel hint picks one of three by where the
## nearest dock is: `dock` is `Run.nearest_dock`'s answer).
static func line_id(id: StringName, dock: Dictionary = {}) -> StringName:
	if id != &"fuel":
		return id
	if dock.is_empty():
		return &"fuel_none"
	if int(dock.get("jumps", 0)) == 0:
		return &"fuel_here"
	return &"fuel_dock"


## The words for line `lid`, its fields filled from `values` (hand, cap, jumps,
## name, turn, flip). One jump is "1 jump": the line's own "jumps" agrees with
## the number, so a dock next door never reads "1 jumps".
static func fill(lid: StringName, values: Dictionary) -> String:
	var s := String(LINES.get(lid, ""))
	if lid == &"fuel_dock" and int(values.get("jumps", 0)) == 1:
		s = s.replace("{jumps} jumps", "{jumps} jump")
	for k in values:
		s = s.replace("{%s}" % k, str(values[k]))
	return s


## What she SAYS of the filled line: everything before the first unspoken field
## (the dock's name), so the typing keeps her pace and the name types after.
static func spoken(lid: StringName, values: Dictionary) -> String:
	var raw := String(LINES.get(lid, ""))
	for u in UNSPOKEN:
		var i := raw.find(u)
		if i >= 0:
			var head := raw.substr(0, i)
			for k in values:
				head = head.replace("{%s}" % k, str(values[k]))
			if lid == &"fuel_dock" and int(values.get("jumps", 0)) == 1:
				head = head.replace(" jumps", " jump")
			return head.strip_edges()
	return fill(lid, values)


## Her take for line `lid` with these values: the per-value take if there is
## one, the base take, or "" (silent, the words alone).
static func voice_path(lid: StringName, values: Dictionary = {}) -> String:
	var f := String(FIELD.get(lid, ""))
	if f != "" and values.has(f):
		var per := _take("tut_%s_%s" % [lid, str(values[f])])
		if per != "":
			return per
	return _take("tut_%s" % lid)


## FOR THE HARNESS ONLY (`-- sheet=AshTutorTest`): a take's name -> a file to
## play for it, so the per-value rule and the typing's pace can be held to it
## before any take exists. Empty in the game.
static var stand_in: Dictionary = {}


static func _take(name: String) -> String:
	if stand_in.has(name):
		return String(stand_in[name])
	var path := VOICE_DIR + name + ".ogg"
	return path if ResourceLoader.exists(path) else ""


static func all_ids() -> Array:
	return LINES.keys()
