class_name LocalUndock
extends RefCounted

## THE UNDOCK on LOCAL, nose first: the ENTER's path run back (`undock_fly`), the engines
## on that path (`undock_engines`) and the hold for a dock from the station's right.

## THE UNDOCK, NOSE FIRST: where along the ENTER's path back your ship is at the
## ladder's `hk` (1 in the berth, 0 at the mooring): a slow pull-away, fastest
## mid-way, eased into place. Keeps how far out it is in `hall.u_out`.
static func undock_fly(hall: Dictionary, hk: float) -> float:
	hall["t"] = (1.0 - hk) * ZoomLadder.DOCK_ENTER_S
	hall["u_out"] = 1.0 - hk
	return 1.0 - smoothstep(0.0, 1.0, pow(1.0 - hk, 1.5))


## Its engines: the idle through the pull-away, the dock's burn from `BURN_FROM` of the
## way out, then the flameout's coughs, over `COAST_S` before it is in its mooring.
const BURN_FROM := 0.25
const COAST_S := 0.4


static func undock_engines(screen: SectorScreen, art: ShipView, hall: Dictionary) -> void:
	var u := float(hall.get("u_out", 0.0))
	var row := int(hall.get("row", 0))
	var cough_u := clampf(1.0 - (COAST_S + ShipView.sputter_s(row)) / ZoomLadder.DOCK_ENTER_S, BURN_FROM + 0.1, 0.95)
	screen._dock_burn(art, hall, u >= BURN_FROM and u < cough_u)
	if u < cough_u:
		return
	var tc := (u - cough_u) * ZoomLadder.DOCK_ENTER_S
	if not hall.has("cough_clip"):
		hall["cough_clip"] = art.sputter(row)
		hall["cough_at"] = 0.0
		if not (ZoomLadder.active != null and ZoomLadder.active._cut):
			Audio.play(hall.cough_clip as StringName, 0.0, 0, Audio.SHIP_DB + linear_to_db(SectorScreen.DOCK_BURN_LEVEL), 1.0,
				ShipView.sputter_from_s(row) + tc)
	art.sputter_step(tc)


## A dock from the station's right: your ship held where it is while LOCAL goes to black.
static func hold(art: ShipView, p0: Vector2, step: int) -> void:
	art.position = p0
	art.visible = step == 0
