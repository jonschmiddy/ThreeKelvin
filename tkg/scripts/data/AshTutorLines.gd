class_name AshTutorLines
extends RefCounted

## Words are Jon's picks character for character; fields are filled live, never written as numbers.
## She never says a number or a name (Jon, Oct 18): takes are recorded from `SPOKEN`.
## Why: docs/why/AshTutorLines.md#ash-teaching

const LINES: Dictionary = {
	&"chart": "These stars are in reach. Left bar is danger. Right bar is fuel.",
	&"events": "Click an event to read it. GO flies us there.",
	# The deep tutorial (Jon, Oct 22) was checked against the code; changed words get a new take.
	# Why: docs/why/AshTutorLines.md#ash-teaching
	&"drawer": "Pick a choice. Some show the odds. The rest are a surprise. NOT NOW saves it for later.",
	&"odds": "This one tests the ship. It shows the stat, what we have, and the odds. Meet it and it can't fail.",
	&"result": "Here's what it cost and what we got. SECTOR LOOT opens anything we found. Then press CONTINUE.",
	&"hand": "Drag a card onto an enemy to fire it. Cards that help us go on our own ship.",
	&"energy": "That card cost energy. This box is what's left. It fills back up every turn.",
	&"intent": "That's what it will do when you press END TURN.",
	&"endturn": "Out of energy. Press END TURN. They act, then you draw {hand} cards.",
	&"heat_corner": "Top right is heat. Playing the card adds that much. A green minus cools us down.",
	&"brace": "Brace stops damage until it's used up. It stays up, but holding it warms us every turn.",
	&"heat": "This is heat. Past {cap}, every point over costs us hull at the end of the turn.",
	&"keywords": "Underlined words have rules. Rest the pointer on a card to read them.",
	&"discard_pick": "That card wants a discard. Click a card in your hand to put it in the discard pile.",
	&"malfunction": "That's a malfunction. It clogs the deck. Play it to clear it for this fight. A shipyard clears it for good.",
	&"flee_hail": "FLEE and HAIL end a fight early. Each one is a check, and a miss costs us.",
	&"piles": "Played cards go to the discard. When the draw pile runs out, they shuffle back in at the next turn.",
	&"salvage": "Drag parts into the hold, or double-click them. What we leave stays in the wreck. Press DONE when we're through.",
	&"cutaway": CUTAWAY_LINE + "\n" + CUTAWAY_KEYS,
	&"mounts": "Each slot takes one kind of part. The slots that light up will take this one.",
	&"cards_from_parts": "Every part brings its own cards. Fit it, and they join the deck. Point at a part to see them.",
	&"attributes": "These are the ship's stats. Event checks test most of them. Fitting parts moves them up or down.",
	&"wreck": "We broke it, so now it's a wreck. Click it to see what we can take. It stays here if we go.",
	&"loot": "SECTOR LOOT is everything loose here, like what we left in wrecks. It waits for us. Click it to look.",
	&"hull": "That's our hull. At zero, the ship is lost. A shipyard can patch it.",
	&"fuel_first": "Each jump burns fuel. Run dry between stars and the run ends. Stations sell more.",
	&"map_fly": "Click a world twice and we fly there. Or fly us by hand.\n{thrust} pushes. {left} and {right} turn.",
	&"layers": "This strip is how deep we are. Each ring in means more danger and better pay. The core is at the end.",
	&"contract_track": "That ring on the chart is the job. Do it there, then press DELIVER at any of their docks.",
	&"quest": "Something is marked on the chart now. Fly there to follow it up.",
	&"jump_blocked": "We can't jump there yet. The button says why.",
	&"dock": "Stations repair, refuel and trade. Pick a deck on the left.",
	# The decks' lines are Jon's picks of two drafts each (Oct 20), recorded Oct 21.
	# The lab's is science's, under its own id `research`; text only (`tut_research` unrecorded).
	# Why: docs/why/AshTutorLines.md#the-decks
	&"shipyard": "Repairs and fuel are here. Click a drone over the ship to pay for its job.",
	&"promenade": "The shelf sells parts. Drag one down to the till to buy it. It goes in the hold.",
	&"exchange": "Spare parts turn into credits here. Drag one to the counter to sell it.",
	&"hiring_board": "Manufacturers post paid work here. Press SIGN on a note to take the job.",
	&"research": "The lab takes DATA. Click the screen to spend it on a routine or a part.",
	&"faults": "FAULTS clears a malfunction out of the deck, for a price.",
	&"hull_sale": "That ship is for sale. TAKE IT trades ours in. It comes empty, so we move everything over.",
	&"undock": "UNDOCK takes us back out when we're done here.",
	&"fuel_dock": "Fuel is low. Run dry and the run ends. Nearest dock is {jumps} jumps: {name}.",
	&"fuel_none": "Fuel is low, and empty ends the run. No dock in reach. Jump short and look.",
	&"fuel_here": "Fuel is low. Run dry and the run ends. Refuel here before we go.",
	&"ship": "Click the ship to open it up. You fit and swap parts in there.",
	&"save": "SAVE AND EXIT keeps the run. CONTINUE on the title picks it back up.",
	&"step_jump": "Open STARCHART. Pick a star in range, then press JUMP.",
	&"step_jump_chart": "Pick a star in range, then press JUMP.",
	&"step_event": "Open SECTOR. Click an event, then press GO.",
	&"step_event_map": "Click an event, then press GO.",
}

## The cutaway line is Jon's words (Oct 20), replacing his Oct 18 draft.
const CUTAWAY_LINE := "Drag a module onto an empty slot to install it. Drag it off the ship into the hold to remove it."
## The key line shows as bound and is never said; the flip half went Oct 22 as drawing only.
## Why: docs/why/AshTutorLines.md#ash-teaching
const CUTAWAY_KEYS := "{turn} turns a part."

## What she says where it differs from what shows: no number, name or key.
const SPOKEN: Dictionary = {
	&"cutaway": CUTAWAY_LINE,
	&"endturn": "Out of energy. Press END TURN. They act, then you draw new cards.",
	# (the deep tutorial's, Oct 22: no number and no key; the keys show on a
	# line of their own, never said)
	&"heat": "This is heat. Past the limit, every point over costs us hull at the end of the turn.",
	&"map_fly": "Click a world twice and we fly there. Or fly us by hand.",
	&"fuel_dock": "Fuel is low. Run dry and the run ends. Here's the nearest dock.",
}

## Takes recorded for words since changed are text only until a new take is approved.
## `result` said REWARD on its take; the button is SECTOR LOOT now (Nov 9).
const SILENT: Array[StringName] = [&"result"]

## Changed lines play the named retake, never the old take under the new words.
## Why: docs/why/AshTutorLines.md#ash-teaching
const RETAKE: Dictionary = {
	&"hand": "tut_hand_2",
	&"heat": "tut_heat_2",
	&"brace": "tut_brace_2",
	&"wreck": "tut_wreck_2",
	&"salvage": "tut_salvage_2",
	&"loot": "tut_loot_2",
	&"drawer": "tut_drawer_2",
}

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


## One jump reads as 1 jump, so a dock next door never says 1 jumps.
static func fill(lid: StringName, values: Dictionary) -> String:
	var s := String(LINES.get(lid, ""))
	if lid == &"fuel_dock" and int(values.get("jumps", 0)) == 1:
		s = s.replace("{jumps} jumps", "{jumps} jump")
	for k in values:
		s = s.replace("{%s}" % k, str(values[k]))
	return s


## What she SAYS for line `lid`: its `SPOKEN` script, or the line as it shows.
static func spoken(lid: StringName) -> String:
	return String(SPOKEN.get(lid, LINES.get(lid, "")))


## Her take for line `lid`, or "" (silent, the words alone). One take a line:
## she never says the values, so no take is kept per value.
static func voice_path(lid: StringName) -> String:
	var name := String(RETAKE.get(lid, "tut_%s" % lid))
	if SILENT.has(lid) and not stand_in.has(name):
		return ""
	return _take(name)


## Harness only: maps a take name to a file so typing pace can be held to a take.
static var stand_in: Dictionary = {}


static func _take(name: String) -> String:
	if stand_in.has(name):
		return String(stand_in[name])
	var path := VOICE_DIR + name + ".ogg"
	return path if ResourceLoader.exists(path) else ""


static func all_ids() -> Array:
	return LINES.keys()
