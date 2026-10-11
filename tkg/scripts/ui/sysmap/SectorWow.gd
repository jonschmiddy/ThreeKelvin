extends RefCounted

## THE SECTOR MAP'S "WOW" PROTOTYPES (Oct 11 ideas round; Jon: "I want the
## starchart, sector, and local to look MAGNIFICENT"). Each idea is its own
## switch, OFF by default, so the game is exactly as approved until Jon keeps
## one. SIMPLIFIED only for now: the other styles ignore every switch.
##
## Switched on by a harness's (or a play's) command line:
##   -- wow=glints,flarefront   some
##   -- wow=all                 every one
## or in code, `SectorWow.on[&"glints"] = true` (the harness flips them live to
## film the same moment before and after).
##
## The ideas, by key:
##   flarefront  a flare's light travelling out through the plane's dust as a
##               ring, the belt flashing and each world brightening as it arrives
##   glints      sunlight catching tumbling rocks in the belts
##   orbitdepth  the near half of each orbit ring a little bolder than the far
## (Tried and cut in the same round: the sun lighting the whole plane as a warm
## pool -- the palette set it in flat plates, and SIMPLIFIED's sky is clean black
## beyond the sun's glow by design; and the grid lit by the sun -- it only showed
## as the well's funnel, the grid being faint by Jon's ask; and the belts' bigger
## rocks drawn as lumpy lit stones close in -- a belt seen close holds too few
## of them for it to show.)

const KEYS: Array[StringName] = [&"flarefront", &"glints", &"orbitdepth"]

static var on := {}


static func _static_init() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("wow="):
			for k in s.substr(4).split(","):
				if k == "all":
					for kk in KEYS:
						on[kk] = true
				elif k != "" and k != "none":
					on[StringName(k)] = true


## Whether idea `k` is on (and the map is drawn SIMPLIFIED: `view` is the
## SystemView, or null to skip that check).
static func has(k: StringName, view: Object = null) -> bool:
	if not on.get(k, false):
		return false
	if view != null and (view.get("legacy") or view.get("painted") or view.get("radiant")):
		return false
	return true
