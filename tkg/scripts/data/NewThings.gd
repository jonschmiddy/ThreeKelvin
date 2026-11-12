class_name NewThings
extends RefCounted

## Short per-build list for the NEW THINGS page (Jon, Nov 5), newest first, with a NEXT entry.
## `release.sh` renames NEXT on release. Grade new lines by hand: 7.0 or under.
## Why: docs/why/NewThings.md#new-things

const NEXT := "next"

const LIST := [
	{
		version = NEXT,
		date = "",
		lines = [
			"A jump is a ten second film now, one of eleven picked at random each time. After it you arrive at the edge of the system map.",
			"Most enemies have four times the hull, so fights last longer.",
			"The Custodian grows stronger with each jump after your fifteenth.",
			"An eye beside the goal shows how strong the Custodian is.",
			"In co-op the whole party fights the same Custodian.",
			"About one system in four is a binary, its stars circling each other.",
			"The autopilot flies a real path through the pull of suns and giants.",
			"A jump can go two rings deeper, up from one.",
			"Stations are rarer, and each one has all five decks.",
			"UNDOCK is the only way to leave a station.",
			"The sector map shows your own ship, with a blue ion drive.",
			"The star chart grays out stars too deep to jump to.",
			"A derelict hauler says which frame you would claim. SCRAP pays for one you don't want.",
			"A.S.H. points at a world, not your ship, when she says to click one twice.",
			"NEW THINGS on the title menu lists what changed in each version.",
			"In co-op, join a fight after its first turn and you are stunned until the enemy's turn ends.",
			"In co-op, enemies have more hull and fights pay more for each player in the game.",
			"The star chart's round galaxies are drawn the way the spirals are, and each kind has its own look.",
			"Flights between worlds take 3 to 7 seconds, down from about 14. Pick a curved or a straight path in Settings.",
			"The LEGACY render style is gone. If you used it, the game now starts in SIMPLIFIED.",
			"In a fight your brace is a steel part of your hull bar, shown as 37 / 40 +17.",
			"An encounter's text arrives a word at a time.",
			"Your ship eases out of the bay when you undock. UNDOCK blinks if you try to leave another way.",
			"An enemy's engine flame no longer shows through your draw and discard piles.",
			"The title screen no longer draws a faint dotted box round the galaxy.",
			"On a Mac, trackpad scrolling and a pinch zoom the star chart and the system map.",
			"GO on the system map's panel is a wide orange button.",
			"The Shipyard no longer freezes for seconds when you click your ship.",
		],
	},
	{
		version = "0.4.2-alpha.1",
		date = "2026-10-23",
		lines = [
			"COMMS on the top bar lists everything A.S.H. has said this run.",
			"A.S.H. no longer says a tutorial line aloud twice.",
			"Your ship shows only its weapons on LOCAL, in fights and at stations.",
			"A part with hull on it brings its hull, so a full ship stays full.",
			"Lock on stacks. A second lock on card adds to the first.",
			"A part found a grade higher now gives the stats it shows.",
			"A hull swap can no longer leave your parts stuck on the pad.",
			"A win counts for the manufacturer you launched with. A hull swap does not change that.",
		],
	},
	{
		version = "0.4.1-alpha.1",
		date = "2026-10-22",
		lines = [
			"QUESTS lists the quests that events give you.",
			"Quests you finish stay in QUESTS, under COMPLETED.",
			"R turns a material in the hold, as it turns a part.",
			"In co-op a partner can no longer close your quest or your job.",
		],
	},
	{
		version = "0.4.0-alpha.1",
		date = "2026-10-22",
		lines = [
			"Initial alpha release.",
		],
	},
]

const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
	"JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]


## The version in project.godot: what this build is, or will be stamped as.
static func build_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


## NEXT is headed dev from source and NEXT plus commit in an export, which missed these lines.
static func heading(e: Dictionary) -> String:
	var v := str(e.get("version", ""))
	if v != NEXT:
		return v
	if not BuildInfo.stamped():
		return BuildInfo.stamp()
	return "NEXT · %s" % BuildInfo.info().get("commit", "?")


## "OCT 23" from "2026-10-23"; NOT OUT YET for an entry with no date.
static func day(e: Dictionary) -> String:
	var d := str(e.get("date", "")).split("-")
	if d.size() != 3:
		return "NOT OUT YET"
	return "%s %d" % [MONTHS[clampi(int(d[1]) - 1, 0, 11)], int(d[2])]


## The seen-mark key includes NEXT's line count, so an added line marks the button again.
static func latest_key() -> String:
	if LIST.is_empty():
		return ""
	var e: Dictionary = LIST[0]
	if str(e.get("version", "")) == NEXT:
		return "%s +%d" % [heading(e), (e.get("lines", []) as Array).size()]
	return heading(e)


# ------------------------------------------------------------------ seen mark

## Beside the welcome note's flag, in the settings file (`[news] seen`), so under
## a harness it is that process's scratch file (`DisplaySettings.hints_path`).
const SECTION := "news"
const KEY := "seen"


static func seen_key() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(DisplaySettings.hints_path()) != OK:
		return ""
	return str(cfg.get_value(SECTION, KEY, ""))


static func mark_seen(key: String = "") -> void:
	var cfg := ConfigFile.new()
	cfg.load(DisplaySettings.hints_path())
	cfg.set_value(SECTION, KEY, latest_key() if key == "" else key)
	cfg.save(DisplaySettings.hints_path())


## As if never opened (the tests' fresh profile).
static func forget() -> void:
	var cfg := ConfigFile.new()
	cfg.load(DisplaySettings.hints_path())
	if cfg.has_section_key(SECTION, KEY):
		cfg.erase_section_key(SECTION, KEY)
	cfg.save(DisplaySettings.hints_path())


## The newest notes have not been opened on this profile.
static func unseen() -> bool:
	return latest_key() != "" and seen_key() != latest_key()
