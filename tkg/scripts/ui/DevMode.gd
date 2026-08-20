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
##   - CARDS tab in the HUD                    (every card in the game, on a page)
##   - the star chart's three view buttons     (show all systems / links / icons)
##   - the chassis select's C-B-A-S tier row   (launch in any hull grade)
##
## Adding to that list is one `if DevMode.enabled` at the point of construction.
## Prefer NOT BUILDING the control at all over building it hidden: a hidden node
## still takes layout, still takes focus order, and still has to be reasoned
## about by whoever changes that screen next.
##
## ON by default while the game is being built. That is the right default for
## exactly one audience and it is the audience currently playing it — a fresh
## checkout should hand a developer the tools, not make them go and find the
## switch. Flip this to `false` before anyone who is not us installs it.

const PATH := "user://settings.cfg"

static var enabled: bool = true

static func toggle() -> void:
	enabled = not enabled
	save()
	# Long-lived screens rebuild on this. The HUD in particular is built once in
	# Main._ready() and outlives every screen swap, so without a signal it keeps
	# the tabs it was born with until the process restarts.
	Sig.dev_mode_changed.emit()

static func save() -> void:
	var cfg := ConfigFile.new()
	# Load before writing, or this drops the display and audio sections. See the
	# same note in DisplaySettings.save().
	cfg.load(PATH)
	cfg.set_value("dev", "enabled", enabled)
	cfg.save(PATH)

static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		enabled = bool(cfg.get_value("dev", "enabled", true))
