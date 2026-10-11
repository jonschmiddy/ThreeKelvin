class_name LocalWow
extends RefCounted

## LOCAL'S "WOW" PROTOTYPES (Oct 11, the magnificent pass): ideas Jon keeps or
## cuts one by one, each behind its own switch, all OFF unless asked for. ROUGH
## AND SIMPLIFIED ONLY: the kept ones get finished in every style afterwards.
##
##   godot --path . -- wow=hull,night,...       (or wow=all)
##
## The names:
##   hull     the star's light catching your hull's edge, and the world you
##            orbit lighting its belly (`LocalSky._wow_hull`, `local_hull_light`)
##   night   the night side of the world you orbit lit by its cities when the
##            system is settled, and its air glowing at the limb
##   traffic  far ships crossing along the system's plane in settled systems
##   moons    the moons of the world you orbit going round it, in front and
##            behind, their shadows crossing its face
##
## `shown` is what a harness flips to film the same frame with an idea off and
## on (`LocalWowShot`): an idea is WORKED OUT every frame when asked for, and
## DRAWN only while shown -- so the before and the after differ by that alone.

const NAMES: Array[StringName] = [&"hull", &"night", &"traffic", &"moons"]

static var _asked := {}
static var _read := false
## a harness's veto: false draws nothing of any idea (the before)
static var shown := true
## the ideas' own CPU time, microseconds, since a harness last zeroed it
static var cpu_us := 0


static func _read_args() -> void:
	if _read:
		return
	_read = true
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("wow="):
			for nm in (a as String).substr(4).split(",", false):
				if nm == "all":
					for k in NAMES:
						_asked[k] = true
				else:
					_asked[StringName(nm)] = true


## The idea is asked for (worked out).
static func asked(nm: StringName) -> bool:
	_read_args()
	return _asked.has(nm)


## The idea is asked for and drawn now.
static func on(nm: StringName) -> bool:
	return shown and asked(nm)


static func set_asked(nm: StringName, v: bool) -> void:
	_read_args()
	if v:
		_asked[nm] = true
	else:
		_asked.erase(nm)
