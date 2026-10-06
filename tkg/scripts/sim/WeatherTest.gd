extends Harness

## THE SECTOR MAP'S WEATHER, ITS SCHEDULER ALONE (`SkyWeather`):
##   godot --headless --path . -- weathertest
## Two hours of every sky at every temperament, a quarter second a step, with
## no picture at all: every event "places" (the scheduler's timing is what is
## tested; where each one goes is the harness's `wclip`). Asserts:
##   * one slot-A event at a time, and none starting within 6 s of the last's end;
##   * showpieces at least 90 s apart and 40 s into the visit (Oct 5: rarer was never seen);
##   * no event twice running in a slot;
##   * no small event starting while a showpiece is live;
##   * no slot-A start inside a 60 s busy hold (a page being read, a glide);
##   * nothing starting with reduced motion, and a live event gone the step after;
##   * temperament changes how often, never how long;
##   * EVERY event in the table fires at least once in its sky (a dead entry
##     fails: the lesson of a green gate that cannot see the feature).
## Prints events a minute by tier, sky and temperament.
## `-- weathertest rates` instead prints how often each event comes, sky by sky:
## minutes between one and the next, steady systems and the calm-to-stormy
## range, averaged over systems with each favourite (a measurement, no verdict).

const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")
const SKIES: Array[StringName] = [&"emission", &"reflection", &"planetary", &"remnant", &"dark", &"calm", &"pulsar", &"core"]
const TEMPERS: Array[StringName] = [&"calm", &"steady", &"stormy"]
const SECONDS := 7200.0
const STEP := 0.25
## the busy hold, and the reduced-motion window, in seconds of the visit
const HOLD := Vector2(600.0, 660.0)
const REDUCED := Vector2(1500.0, 1560.0)
## events whose length is rolled (or set by a beat, a plunge, a chain) rather than fixed
const ROLLED: Array[StringName] = [&"strike", &"globule", &"comet", &"sungrazer", &"magnetar", &"ringflash", &"pulse", &"starmood", &"gwave", &"newstar"]


func run() -> void:
	if "rates" in OS.get_cmdline_user_args():
		_rates()
		return
	var was := DisplaySettings.reduced_motion
	for sky in SKIES:
		var fired := {}
		var lasts := {}
		var gaps := {}
		for tp in TEMPERS:
			var W = SkyWeatherS.new()
			W.setup_sim(sky, 1000 + SKIES.find(sky) * 7, tp)
			W.log_on = true
			W.arrive(0.0)
			var t := 0.0
			var cleared_ok := true
			var started_in_reduced := 0
			var reduced_n0 := -1
			while t < SECONDS:
				W.sim_hold = t >= HOLD.x and t < HOLD.y
				# the ship moving a minute in every three, for the reactive events
				W.sim_moving = fmod(t, 180.0) < 60.0
				var red := t >= REDUCED.x and t < REDUCED.y
				if red and not DisplaySettings.reduced_motion:
					DisplaySettings.reduced_motion = true
					reduced_n0 = W.log_starts.size()
					W.sim_step(STEP)
					if not W.live().is_empty():
						cleared_ok = false
				elif not red and DisplaySettings.reduced_motion:
					DisplaySettings.reduced_motion = false
					started_in_reduced = W.log_starts.size() - reduced_n0
					W.sim_step(STEP)
				else:
					W.sim_step(STEP)
				t += STEP
			DisplaySettings.reduced_motion = false
			var label := "%s/%s" % [sky, tp]
			_ok("%s: a live event is gone the step after reduced motion goes on" % label, cleared_ok)
			_ok("%s: nothing starts with reduced motion on (%d)" % [label, started_in_reduced], started_in_reduced == 0)
			_check_log(W, label, fired, lasts, gaps, tp)
			W.free()
		# every entry fires in its sky
		var want: Array = SkyWeatherS.TABLE[sky].keys()
		want.append_array(SkyWeatherS.SHARED.keys())
		want.append(&"bowshock")
		var dead: Array = []
		for nm: StringName in want:
			if not fired.has(nm):
				dead.append(nm)
		_ok("%s: every event fires (%s)" % [sky, "all %d" % want.size() if dead.is_empty() else "never: " + ", ".join(PackedStringArray(dead))], dead.is_empty())
		# how long an event lasts does not depend on the temperament
		var bad: Array = []
		for nm: StringName in lasts:
			if ROLLED.has(nm):
				continue
			var by: Dictionary = lasts[nm]
			if by.has(&"calm") and by.has(&"stormy") and absf(float(by[&"calm"]) - float(by[&"stormy"])) > 0.01:
				bad.append(nm)
		_ok("%s: temperament never changes how long an event lasts%s" % [sky, "" if bad.is_empty() else " (" + ", ".join(PackedStringArray(bad)) + ")"], bad.is_empty())
		if gaps.has(&"calm") and gaps.has(&"stormy"):
			_ok("%s: a calm system's weather comes less often than a stormy one's (%.0f s vs %.0f s)" % [sky, float(gaps[&"calm"]), float(gaps[&"stormy"])], float(gaps[&"calm"]) > float(gaps[&"stormy"]))
	DisplaySettings.reduced_motion = was
	verdict("weathertest")


## Is nm the only event of its kind for its slot in this sky (it may then repeat)?
func _only_one(W, slot: int, nm: StringName) -> bool:
	var tier: int = int(W._spec(nm)[0])
	var n := 0
	for k: StringName in W.TABLE[W.sky]:
		if int(W.TABLE[W.sky][k][0]) == tier:
			n += 1
	return slot == 1 and n == 1


func _check_log(W, label: String, fired: Dictionary, lasts: Dictionary, gaps: Dictionary, tp: StringName) -> void:
	var L: Array = W.log_starts
	var a_end := -1e9
	var last_name := ["", "", ""]
	var sp_t := -1e9
	var sp_end := -1e9
	var ok_one := true
	var ok_gap := true
	var ok_sp := true
	var ok_twice := true
	var ok_s := true
	var ok_hold := true
	var per := [0, 0, 0, 0]
	var m_starts: Array[float] = []
	var prev_n: StringName = &""
	var prev_t := -1e9
	for e: Array in L:
		var t: float = e[0]
		var nm: StringName = e[1]
		var slot: int = e[2]
		var tier: int = e[3]
		var dur: float = e[4]
		fired[nm] = true
		per[tier] += 1
		if not lasts.has(nm):
			lasts[nm] = {}
		lasts[nm][tp] = dur
		# reduced motion cut whatever was live then short
		if t >= REDUCED.y and a_end > REDUCED.x and a_end < REDUCED.y + 120.0 and prev_t < REDUCED.x:
			a_end = REDUCED.x
		if t >= REDUCED.y and sp_end > REDUCED.x and sp_t < REDUCED.x:
			sp_end = REDUCED.x
		if slot == 0:
			if t < a_end - 0.01:
				if ok_one:
					print("    (%s at %.2f while %s, from %.2f, lasts to %.2f)" % [nm, t, prev_n, prev_t, a_end])
				ok_one = false
			if t < a_end + 6.0 - STEP - 0.01:
				if ok_gap:
					print("    (%s at %.2f, %.2f s after %s ended at %.2f)" % [nm, t, t - a_end, prev_n, a_end])
				ok_gap = false
			if t >= HOLD.x + STEP and t < HOLD.y:
				ok_hold = false
			a_end = t + dur
			prev_n = nm
			prev_t = t
			if tier == SkyWeatherS.SP:
				if t < 40.0 or t - sp_t < 90.0:
					ok_sp = false
				sp_t = t
				sp_end = t + dur
			if tier == SkyWeatherS.M:
				m_starts.append(t)
		if slot == 1 and t >= sp_t and t < sp_end:
			if ok_s:
				print("    (%s at %.2f under the showpiece from %.2f to %.2f)" % [nm, t, sp_t, sp_end])
			ok_s = false
		if slot < 2:
			if last_name[slot] == String(nm) and not _only_one(W, slot, nm):
				ok_twice = false
			last_name[slot] = String(nm)
	var mins := SECONDS / 60.0
	print("  %-16s A %.2f/min (M %d, SP %d, R %d), S %.2f/min; showpiece every %.1f min" % [label, (per[1] + per[2] + per[3]) / mins, per[1], per[2], per[3], per[0] / mins, mins / maxf(1.0, float(per[2]))])
	_ok("%s: one slot-A event at a time" % label, ok_one)
	_ok("%s: 6 s between slot-A events" % label, ok_gap)
	_ok("%s: showpieces 90 s apart, 40 s in" % label, ok_sp)
	_ok("%s: no event twice running in a slot" % label, ok_twice)
	_ok("%s: no small event under a showpiece" % label, ok_s)
	_ok("%s: no slot-A start in a busy hold" % label, ok_hold)
	if m_starts.size() > 1:
		gaps[tp] = (m_starts[m_starts.size() - 1] - m_starts[0]) / float(m_starts.size() - 1)


## HOW OFTEN EACH EVENT COMES (`rates`): two hours of each sky at each
## temperament, over twelve systems (so every favourite is in the mix), the ship
## moving a minute in three; minutes between one start and the next.
func _rates() -> void:
	var was := DisplaySettings.reduced_motion
	DisplaySettings.reduced_motion = false
	for sky in SKIES:
		var counts := {}
		var mins := {}
		for tp in TEMPERS:
			for sys in 12:
				var W = SkyWeatherS.new()
				W.setup_sim(sky, 2000 + sys * 13 + SKIES.find(sky) * 7, tp)
				W.log_on = true
				var t := 0.0
				while t < SECONDS:
					W.sim_moving = fmod(t, 180.0) < 60.0
					W.sim_step(STEP)
					t += STEP
				for e: Array in W.log_starts:
					var key := "%s|%s" % [e[1], tp]
					counts[key] = int(counts.get(key, 0)) + 1
				mins[tp] = float(mins.get(tp, 0.0)) + SECONDS / 60.0
				W.free()
		var names: Array = SkyWeatherS.TABLE[sky].keys()
		names.append_array(SkyWeatherS.SHARED.keys())
		for nm: StringName in names:
			var per := []
			for tp in TEMPERS:
				var n := int(counts.get("%s|%s" % [nm, tp], 0))
				per.append(float(mins[tp]) / float(n) if n > 0 else -1.0)
			print("  rates %-10s %-12s every %5.1f min (calm %5.1f, stormy %5.1f)" % [sky, nm, per[1], per[0], per[2]])
	DisplaySettings.reduced_motion = was
