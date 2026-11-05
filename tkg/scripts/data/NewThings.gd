class_name NewThings
extends RefCounted

## WHAT CHANGED IN EACH BUILD, for the title menu's NEW THINGS page
## (`NewThingsPopup`). Jon, Nov 5: "a NEW THINGS button on the main menu that
## shares changes that are done per version ... just a brief bulleted list".
##
## NEWEST FIRST. Each entry is a version, the day it went out (YYYY-MM-DD) and a
## few short lines a player would notice, in plain words: no internal names, one
## line each. CHANGELOG.md holds the long form; this is the short one.
##
## THE VERSION RULE. A build's version is `application/config/version` in
## project.godot; `tools/export.sh` stamps that same string into the build
## (`BuildInfo`), and `tools/dev/release.sh` cuts a release under it. Work on
## main that has not gone out yet sits in ONE entry at the top whose version is
## NEXT, with no date. The release branch, the same commit that raises
## config/version and cuts the CHANGELOG, renames NEXT to the new version and
## dates it; `release.sh` refuses a version whose entry is not the newest one
## here (`tools/dev/new_things_check.sh`). So the newest entry is either NEXT,
## with config/version's own entry right under it, or config/version itself.
## Until it is cut, NEXT is headed "dev" from source, as the title's corner
## says (`BuildInfo.stamp`), and "NEXT · <commit>" in an exported build that is
## not a release: the corner's version there is the last release's, and these
## lines did not go out in it.
##
## THE GRADE. `tools/prose_tells.py --strict` reads these lines like any other
## player text. `tools/prose_grade.py --all` does NOT grade them: it skips a
## string of one sentence, and most lines here are one. So grade each new line
## by hand before it lands, 7.0 or under:
##     cd tools && python -c "import prose_grade as p; print(p.grade('A line.'))"
## Jon's own words for 0.4.0-alpha.1 ("Initial alpha release.", 13.1) stay as
## he wrote them.

const NEXT := "next"

const LIST := [
	{
		version = NEXT,
		date = "",
		lines = [
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


## What an entry is headed with: its version, or for NEXT "dev" from source
## (the title's corner) and "NEXT · <commit>" in an exported build, whose corner
## version is the last release's and must not head lines that missed it.
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


## The key the seen mark compares against: the newest entry's heading, and for
## NEXT its count of lines too ("dev +14"), so a line added to NEXT marks the
## button again on a profile that opened the page before it.
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
