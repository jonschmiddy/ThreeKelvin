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
## other takes are in. A missing take is silence and the words still show. SHE
## NEVER SAYS A NUMBER OR A NAME (Jon, Oct 18, "numbers:A"): the text shows the
## live values, and a line with a field is recorded from its `SPOKEN` script
## instead, so one take serves every value. The typing follows the take as her
## barks do, over the SHOWN text (`AshPortrait`): the words end when she stops,
## whatever the numbers make their length.

const LINES: Dictionary = {
	&"chart": "These stars are in reach. Left bar is danger. Right bar is fuel.",
	&"events": "Click an event to read it. GO flies us there.",
	# THE DEEP TUTORIAL (Jon, Oct 22: "Tutorial: scope:all voice:record
	# bugs:fix", after Kevin's playtest: he did not know the energy meter or
	# when to loot a dead ship). The audit's 35 rows, each checked against the
	# code; where the code disagreed with a draft, the words were changed to
	# match it. A line whose words changed after its take was recorded plays its
	# new take's name (`RETAKE`), so the old take is never heard under new words.
	&"drawer": "Pick a choice. Some show the odds. The rest are a surprise. NOT NOW saves it for later.",
	&"odds": "This one tests the ship. It shows the stat, what we have, and the odds. Meet it and it can't fail.",
	&"result": "Here's what it cost and what we got. REWARD opens anything we found. Then press CONTINUE.",
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
	# THE DECKS, the first time each is open (`Hints.DECK_HINTS`): Jon's picks of
	# two drafts each (Oct 20, "promenade:B shipyard:B exchange:B hiring_board:A
	# laboratory:A"), recorded Oct 21. Each says what the deck is for and the one
	# thing to do there in the deck's own words; no number and no name.
	&"shipyard": "Repairs and fuel are here. Click a drone over the ship to pay for its job.",
	&"promenade": "The shelf sells parts. Drag one down to the till to buy it. It goes in the hold.",
	&"exchange": "Spare parts turn into credits here. Drag one to the counter to sell it.",
	&"hiring_board": "Manufacturers post paid work here. Press SIGN on a note to take the job.",
	&"laboratory": "The fabricator turns a relic into a part. Press MAKE when you can pay for it.",
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

## THE CUTAWAY'S LINE, Jon's words (Oct 20: "install modules by dragging them
## onto an empty module slot on the ship. Uninstall modules by dragging them off
## the ship into the hold"). It was his A of Oct 18, "Drag a part onto a ring to
## fit it. You can turn it ({turn}) and flip it ({flip})."
const CUTAWAY_LINE := "Drag a module onto an empty slot to install it. Drag it off the ship into the hold to remove it."
## AND ITS KEY, shown on a line of its own under her words and never said
## (Jon, Oct 21, for 0.3.0): the key as bound (`Hints.values`' `turn`,
## `Keys.describe`), so a rebound key shows as it is. The flip key's half went
## Oct 22 (the deep tutorial): a flip is drawing only (`ModuleData.flipped`), so
## it is not a thing to teach. Her take stays
## the one recorded from `CUTAWAY_LINE` (`SPOKEN`), and the typing runs over
## both lines as her take plays, as on every line with a field.
const CUTAWAY_KEYS := "{turn} turns a part."

## WHAT SHE SAYS where it differs from what shows (Jon's numbers:A, Oct 18): no
## number, no name, no key. Every other line is said as it shows. These are the
## scripts her takes were recorded from; `-- sheet=AshTutorTest` holds them to
## having no digit and no field.
const SPOKEN: Dictionary = {
	&"cutaway": CUTAWAY_LINE,
	&"endturn": "Out of energy. Press END TURN. They act, then you draw new cards.",
	# (the deep tutorial's, Oct 22: no number and no key; the keys show on a
	# line of their own, never said)
	&"heat": "This is heat. Past the limit, every point over costs us hull at the end of the turn.",
	&"map_fly": "Click a world twice and we fly there. Or fly us by hand.",
	&"fuel_dock": "Fuel is low. Run dry and the run ends. Here's the nearest dock.",
}

## TAKES RECORDED FOR WORDS THAT HAVE SINCE CHANGED: said as text alone until a
## new take is approved, never the old take under the new words. (Empty: the
## cutaway's was here until Jon picked take 1 of his Oct 20 words.)
const SILENT: Array[StringName] = []

## RE-RECORDED (Oct 22, the deep tutorial): lines whose words changed after
## their take was recorded. Each plays the take named here once it is installed
## (`VOICE_DIR` + name + ".ogg"), and is text alone until then; the old
## `tut_<id>.ogg` is never played under the new words. The scratchpad's
## `tutorial-deep-voice.json` is their script. Every other new line is
## `tut_<id>.ogg` as before, and silent until its take is installed.
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


## FOR THE HARNESS ONLY (`-- sheet=AshTutorTest`): a take's name -> a file to
## play for it, so the typing's pace can be held to a take before one is
## installed. Empty in the game.
static var stand_in: Dictionary = {}


static func _take(name: String) -> String:
	if stand_in.has(name):
		return String(stand_in[name])
	var path := VOICE_DIR + name + ".ogg"
	return path if ResourceLoader.exists(path) else ""


static func all_ids() -> Array:
	return LINES.keys()
