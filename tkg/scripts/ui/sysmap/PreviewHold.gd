extends RefCounted
## THE MAP'S PREVIEW FROM A RING, held as drawn until it leaves (Jon's ruling 1A, Nov 15): how far
## ahead it is planned and when it is planned again, one rule for the overlay and the harnesses.
## Why: docs/why/ShipFlight.md#preview-window

const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")

## From a ring the preview is planned WINDOW s ahead; `-- window=S` (FlightTest) sets window_k.
const WINDOW := 3.0
static var window_k := -1.0


static func window() -> float:
	return window_k if window_k >= 0.0 else WINDOW


## How far ahead fl's preview is planned: its window on a ring, else PREVIEW_AHEAD.
static func ahead(fl) -> float:
	if fl.mode == &"rail" and not (fl.rail as Dictionary).is_empty() and not fl.inserting():
		return window()
	return ShipFlightS.PREVIEW_AHEAD


## Whether the drawn preview pl is due to be planned again (its place and orbit unchanged): one made
## ahead is held while a click can still fly it (`stale`: it no longer can, `_takeable`); none, or today's
## planner's made for the moment, on a cadence.
static func due(fl, pl, t: float, since: float, stale: bool) -> bool:
	if pl != null and (pl.res != null or pl.ahead):
		return t >= float(pl.t0) - ShipFlightS.PLAN_AHEAD or stale
	var every := 3.0 if fl.mode == &"rail" and not fl.inserting() else 1.0
	if pl != null:
		every = maxf(every, 2.0)
	return since > every


## fl's preview planned here and now, as the map's worker plans it (for a harness).
static func now(fl, i: int, t: float, prefer: Dictionary = {}):
	var ah := ahead(fl)
	var pl = fl.make_plan(i, t, prefer, ah)
	if pl != null:
		pl.held = ah > ShipFlightS.PREVIEW_AHEAD
	return pl
