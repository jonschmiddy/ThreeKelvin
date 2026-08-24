class_name RunHistory
extends RefCounted

## Every run that has ended, oldest first, in user://history.json.
##
## Deliberately a separate file from the save. The save is the present tense and
## gets deleted the moment it is read; the history is the past tense and is only
## ever appended to. Putting them in one file would mean one bad write could
## take both.
##
## This is a record, not meta-progression. Nothing here feeds back into a run —
## no unlocks, no carried-over currency. The design ruling is that identity is
## assembled mid-run from what you find, and a history that handed you a
## starting bonus would be the first crack in that.

const PATH := "user://history.json"
const VERSION := 1
## Old runs fall off the end. A file that grows forever eventually costs a
## visible pause on a screen whose whole job is to open instantly.
const LIMIT := 200

enum Outcome { DIED, WON, ABANDONED }

static func outcome_name(o: int) -> String:
	match o:
		Outcome.WON: return "REACHED THE CORE"
		Outcome.ABANDONED: return "ABANDONED"
		_: return "LOST"

# ---------------------------------------------------------------------- write

## Snapshot the run that just ended. Reads RunState directly rather than taking
## arguments, because the caller that knows a run is over is never the same one
## that knows what was in the hold.
static func record(outcome: Outcome, reason: String) -> void:
	if Run.hull == null or Run.map.is_empty():
		return
	var now := Time.get_unix_time_from_system()
	var seconds := maxf(0.0, now - Run.started_at) if Run.started_at > 0.0 else 0.0
	var entry := {
		outcome = int(outcome),
		reason = reason,
		# Wall clock, not a frame count. A run spans sessions now.
		ended_at = now,
		seconds = seconds,
		jumps = Run.jumps,
		kills = Run.kills,
		hp = Run.hp,
		max_hp = Run.max_hp(),
		credits = Run.credits,
		exotic = Run.exotic,
		danger = Run.node_at().danger,
		# How far in you actually got. Shells run rim (0) to core, so the
		# deepest shell touched is the honest measure of a run's reach —
		# jump count rewards farming the rim, which is the opposite reading.
		depth = _deepest_shell(),
		shells = MapGen.LAYERS,
		hull = Run.hull.display_name(),
		# WHO YOU LAUNCHED AS, by id. `hull` is a display string and `manufacturers` is a
		# tally of the parts you ended up carrying; neither answers "which manufacturer
		# did this player fly", which is the question the unlock chain asks. See
		# Unlocks.
		chassis_manufacturer = String(Run.hull.manufacturer),
		perk = String(Run.hull.perk_id),
		# THE GRADE'S PERKS TOO. `perk` alone answers "which manufacturer", which the
		# line above already answers; what a record of a flight wants is what the
		# ship could actually DO.
		tier_perks = ",".join(Array(Run.hull.tier_perks).map(
			func(x: StringName) -> String: return String(x))),
		# THE RUN, AS ONE NUMBER. Everything a run is — the galaxy, the map, the
		# loot, who was waiting at every node — derives from this, so recording
		# it turns the flight record from a list of things that happened into a
		# list of things that can happen AGAIN. It is what makes "that was a
		# great run" actionable rather than nostalgic.
		#
		# Run.galaxy_seed rather than Rng.master: the master is reseeded per
		# seat in co-op, and what identifies a run is the galaxy everyone shares.
		seed = Run.galaxy_seed,
		galaxy = Run.galaxy_name,
		galaxy_title = Run.galaxy_title,
		galaxy_type = GalaxyGen.type_name(Run.galaxy_kind),
		# The build, as the set-bonus system sees it: who you ended up flying.
		manufacturers = _manufacturer_tally(),
		system = MapGen.star_name(Run.node_at()),
	}
	var all := load_all()
	all.append(entry)
	while all.size() > LIMIT:
		all.remove_at(0)
	_write(all)

static func _deepest_shell() -> int:
	var deepest := 0
	for i in Run.trail:
		if i >= 0 and i < Run.map.size():
			deepest = maxi(deepest, (Run.map[i] as MapGen.MapNode).layer)
	return deepest

## Installed modules by manufacturer, biggest first — the thing a run is actually
## remembered by. Cargo is excluded: what you were flying is what you committed
## to, and set bonuses only count what is installed.
static func _manufacturer_tally() -> Array:
	var counts: Dictionary = {}
	for m in Run.installed:
		var key := String(m.manufacturer)
		if key == "":
			key = "unbranded"
		counts[key] = int(counts.get(key, 0)) + 1
	var out: Array = []
	for k in counts.keys():
		out.append({id = k, n = counts[k]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.n) > int(b.n))
	return out

static func _write(all: Array) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("RunHistory: could not open %s for writing (%d)" % [
			PATH, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify({version = VERSION, runs = all}))
	f.close()

# ----------------------------------------------------------------------- read

## Oldest first. A version mismatch reads as no history rather than as an error:
## these are records, and losing them must never block a run from starting.
static func load_all() -> Array:
	if not FileAccess.file_exists(PATH):
		return []
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return []
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var d: Dictionary = parsed
	if int(d.get("version", -1)) != VERSION:
		return []
	var runs: Variant = d.get("runs", [])
	return runs if typeof(runs) == TYPE_ARRAY else []

## Newest first, which is the order a history screen wants.
static func recent() -> Array:
	var all := load_all()
	all.reverse()
	return all

static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

# ------------------------------------------------------------------ aggregate

## Career totals. Abandoned runs count as runs but never as wins — otherwise
## the win rate quietly improves every time you restart a bad opening.
static func stats() -> Dictionary:
	var all := load_all()
	var wins := 0
	var jumps := 0
	var kills := 0
	var best_depth := 0
	var best_kills := 0
	var finished := 0
	for e in all:
		var r: Dictionary = e
		if int(r.get("outcome", Outcome.DIED)) == Outcome.WON:
			wins += 1
		if int(r.get("outcome", Outcome.DIED)) != Outcome.ABANDONED:
			finished += 1
		jumps += int(r.get("jumps", 0))
		kills += int(r.get("kills", 0))
		best_depth = maxi(best_depth, int(r.get("depth", 0)))
		best_kills = maxi(best_kills, int(r.get("kills", 0)))
	return {
		runs = all.size(),
		finished = finished,
		wins = wins,
		# Against finished runs, not all of them.
		win_rate = (float(wins) / float(finished) * 100.0) if finished > 0 else 0.0,
		jumps = jumps,
		kills = kills,
		best_depth = best_depth,
		best_kills = best_kills,
	}

# ----------------------------------------------------------------- formatting

## Shells as a depth reading. "4/9 shells" says more about where a run ended
## than a ring index does, and it is the same vocabulary the chart uses.
static func depth_text(r: Dictionary) -> String:
	var shells := int(r.get("shells", MapGen.LAYERS))
	return "%d/%d shells" % [int(r.get("depth", 0)) + 1, shells]

static func duration_text(seconds: float) -> String:
	if seconds <= 0.0:
		return "—"
	var m := int(seconds) / 60
	if m < 60:
		return "%dm" % maxi(1, m)
	return "%dh %02dm" % [m / 60, m % 60]

## Local date, no clock time. The hour a run ended is noise; the day it happened
## is what makes a list of them read as a log.
static func date_text(unix: float) -> String:
	if unix <= 0.0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(int(unix))
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]
