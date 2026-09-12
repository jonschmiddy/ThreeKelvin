class_name SpaceLayer
extends Control
## The sky, once, behind every screen.
##
## `SpaceBackdrop` and `NebulaWeather` were built for the encounter view and
## constructed inside it, so the one screen that fights had a world behind it
## and the nine that do not — the refit bay, the hold, both galleries, the
## archive, the record, chassis select, the party, the lobby — were panels on
## the clear colour. The generator was never the problem. Its only consumer was.
##
## So the pair moves up to `Router`, above the screen that happens to be open,
## and a screen swap changes what is IN FRONT of the sky rather than replacing
## it. That is most of what "one continuous space" means in practice: the place
## does not blink out because you opened your own hold.
##
## WHY IT IS NOT REBUILT PER SCREEN. `SpaceBackdrop.setup()` bakes a world into
## an ImageTexture — tens of thousands of pixels of noise — and early-outs on a
## node it has already baked. Hosting one layer for the run means that early-out
## does its job: the bake happens on arrival, and walking from the refit bay to
## the hold and back costs nothing. Rebuilding the pair per screen would put a
## world bake on every navigation in the game.
##
## WHERE IT MUST NOT GO. The station decks are interiors and say so in their own
## header: "you are inside this thing. Nothing here is drawn from outside, there
## is no starfield." A layer that sits behind everything will leak sky into them
## unless something turns it off, so `set_active(false)` is not an optimisation,
## it is the ruling. `-- stationshot` is the check.

## The sky itself, and the gas blowing through it. Child order is depth order:
## a Control draws itself, then its children, in order.
var backdrop: SpaceBackdrop
var weather: NebulaWeather

## Whether the sky belongs behind what is currently on screen. Interiors set
## this false; everything that happens in space leaves it true.
var _active: bool = true
## Headless has no window to draw into and the sim boots the whole project, so
## the layer is inert there. Same guard `Audio._ready` uses, for the same
## reason: a balance run should not pay for scenery it cannot see.
var _enabled: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if "sim" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		_enabled = false
		return
	backdrop = SpaceBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	weather = NebulaWeather.new()
	weather.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weather.visible = false
	add_child(weather)


## Point the sky at a system. Safe to call as often as you like — the backdrop
## compares the node index and returns before doing any work when it is the same
## place, which is what makes this callable from a screen swap.
func setup(n: MapGen.MapNode) -> void:
	if not _enabled or n == null:
		return
	backdrop.setup(n)
	weather.visible = n.in_nebula and _active
	if n.in_nebula:
		weather.setup(n.nebula_emission,
			Color("#8a5f7a") if n.nebula_emission else Color("#4a7a8a"))


## Show or hide the whole sky. The station uses this; nothing else should need
## to. Kept separate from `visible` so that hiding for an interior does not
## discard the bake — walking back out of a station must not re-bake the world.
func set_active(on: bool) -> void:
	_active = on
	if not _enabled:
		return
	visible = on
	if not on:
		weather.visible = false
