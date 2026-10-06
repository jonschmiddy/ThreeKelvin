class_name DevMode
extends RefCounted

## The developer switch, persisted to user://settings.cfg beside display and audio.
##
## ONE FLAG, read by everything that exists for us rather than for a player. The
## point is not that these tools are secret — it is that a build with a card
## gallery tab, a star chart that shows the whole galaxy and a run you can start
## in an S-tier hull is not the game, and judging pacing or difficulty against it
## quietly measures the wrong thing. `enabled` off is the game; on is the
## workshop.
##
## What it gates today:
##   - CARDS and MODULES tabs in the HUD       (every card and part, on a page)
##   - the star chart's view buttons           (hide systems / reach / show all)
##     and REGENERATE GALAXY                   (a new galaxy under the same ship)
##   - the chassis select's C-B-A-S tier row   (launch in any hull grade)
##   - every manufacturer unlocked             (Unlocks.unlocked)
##
## Adding to that list is one `if DevMode.enabled` at the point of construction.
## Prefer NOT BUILDING the control at all over building it hidden: a hidden node
## still takes layout, still takes focus order, and still has to be reasoned
## about by whoever changes that screen next.
##
## IT EXISTS ONLY WHERE THE EDITOR DOES. `available` is `OS.has_feature("editor")`:
## true when the game runs from the editor binary (`godot --path .`, and every
## harness the gate runs), false in any exported build, debug template or
## release. Where it is false the workshop is simply not there: `enabled` stays
## false whatever settings.cfg says, toggle() and save() do nothing and write
## nothing, and the title screen does not build the switch. A friend's install
## cannot reach it, and there is no line left to remember to flip before one
## goes out.
##
## ON by default where it is available. That is the right default for exactly
## one audience and it is the audience running the editor — a fresh checkout
## should hand a developer the tools, not make them go and find the switch.
##
## (Not airtight: an exported .pck run under a downloaded editor binary with
## --main-pack has the "editor" feature. A custom feature tag on the export
## preset would close that, once there is a preset.)
##
## To play without developer mode from the editor:
##   godot --path . -- asrelease
## turns `available` off for that run. It is NOT the build a friend gets: it
## still reads your own settings.cfg, suspend save and flight record, and loose
## res:// files an export leaves out. For that, launch the export from a clean
## profile. `-- devtest` checks both sides.

const PATH := "user://settings.cfg"

## Where the switch is saved. A harness points this at a scratch file, so the
## player's own settings are never read or written by a test.
static var path: String = PATH

## Whether this build has a workshop at all. Decided once, at load. The editor
## FEATURE, not is_debug_build(): a debug export is a debug build too.
static var available: bool = _detect(OS.get_cmdline_user_args(), OS.has_feature("editor"))

## Never true where the workshop is not available, whoever sets it, and checked
## on every read as well as every write: a harness line, a stray assignment or
## `available` going off after the fact cannot leave the tools on.
static var enabled: bool = available:
	get:
		return enabled and available
	set(v):
		enabled = v and available

## The editor binary, less `-- asrelease`. `editor` is passed in rather than
## asked here, so `-- devtest` can put the question an export would put: from
## the editor binary OS.has_feature("editor") is always true, and a rule that
## forgot it would look right. An export has no "editor" feature, so no setting
## turns this on there. (`-- devtest` flips it by hand for its editor half, on
## scratch files, then puts it back and quits.)
static func _detect(args: PackedStringArray, editor: bool) -> bool:
	return editor and not "asrelease" in args

static func toggle() -> void:
	if not available:
		return
	enabled = not enabled
	save()
	# Long-lived screens rebuild on this. The HUD in particular is built once in
	# Main._ready() and outlives every screen swap, so without a signal it keeps
	# the tabs it was born with until the process restarts.
	Sig.dev_mode_changed.emit()

static func save() -> void:
	# Never a [dev] key where the switch does not exist. An export that wrote one
	# would leave a player's file saying something about a tool they never had.
	if not available:
		return
	var cfg := ConfigFile.new()
	# Load before writing, or this drops the display and audio sections. See the
	# same note in DisplaySettings.save().
	cfg.load(path)
	cfg.set_value("dev", "enabled", enabled)
	cfg.save(path)

static func load_settings() -> void:
	if not available:
		enabled = false
		return
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		enabled = bool(cfg.get_value("dev", "enabled", true))
