extends Harness

## The music system lets go of what it is not playing.
##
##   godot --path . -- audiotest
##
## NOT HEADLESS, and for once not because of `frame_post_draw`. `Audio._ready`
## disables itself outright on a headless run or under `-- sim`, so the whole
## subject of this test does not exist there: it would pass by measuring
## nothing, which is the failure this project keeps finding in its own checks.
##
## What it guards is a leak rather than a crash. `_ensure_loaded` loaded a cue
## on first use and nothing ever released it, so a session that touched the
## title, the chart, a station, a sector and a fight held all of them decoded at
## once -- and the per-cue figures run to 17 MB. Nothing about that is visible:
## the game sounds correct the whole time it is happening.

var _tree: SceneTree


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame

	if not _ok("audio is enabled, so there is something here to measure",
			Audio.resident() != null and Audio._enabled):
		return _finish()

	# Four cues, so the set is unambiguously more than one.
	#
	# WHAT IS ASSERTED IS THAT THESE FOUR ARE RESIDENT, NOT THAT FOUR ARE. The
	# check used to be `resident().size() == 4`, and it passed for a year by
	# coincidence: whatever cue STATES gives the menu is already loaded when this
	# runs, and the menu happened to point at a cue in this very list -- first
	# "first_light", then "warm". The moment the title moved to "theme", which is
	# not in the list, five were resident and a correct mixer failed its own
	# test.
	#
	# A test that silently depends on an unrelated table is worse than no test,
	# because it reports the wrong subsystem. So the baseline is recorded and
	# what is checked is that playing four cues makes those four resident.
	var before := Audio.resident().size()
	var asked: Array[StringName] = [&"first_light", &"shells", &"warm", &"burn"]
	for pair in [[&"first_light", 2], [&"shells", 2], [&"warm", 1], [&"burn", 4]]:
		Audio.play_cue(pair[0], pair[1])
		await tree.process_frame
	var loaded := Audio.resident()
	var missing: Array[StringName] = []
	for c: StringName in asked:
		if not loaded.has(c):
			missing.append(c)
	if not _ok("playing four cues loads four, and they stay while warm "
			+ "(%d resident, %d before)" % [loaded.size(), before],
			missing.is_empty()):
		return _finish()

	# WAIT FOR THE CROSSFADE TO FINISH, DO NOT TIME IT. A cue whose gain is
	# still falling is still running, and `_release_idle` skips a running cue on
	# purpose -- freeing one mid-fade would cut the fade it is in. So a cue only
	# just left reads as a leak when it is doing exactly the right thing.
	#
	# This was `create_timer(CROSSFADE + 0.5)`, which is the same mistake
	# `quittest` made: a fixed wait is a race with whatever else the frame is
	# doing. It passed until the second-edition cues landed, which are six
	# 96-second stems each and slow enough to load that the margin vanished.
	# Waiting on the thing actually being waited for cannot go stale.
	# AND THE BOUND IS A FAILURE, NOT A SHRUG. A loop that runs out and carries
	# on silently turns a timing problem into a wrong answer about the thing
	# being tested, which is how a flaky check is worse than no check.
	#
	# THE BOUND IS WALL CLOCK, NOT FRAMES, AND THAT IS THE WHOLE FIX. It was 600
	# frames, then 3600, and it still failed about one run in three once the
	# title cue grew a sixth stem. Both numbers were the wrong UNIT rather than
	# the wrong size: this is checking that a 2.2-second crossfade finishes, and
	# a frame count only measures time if frames take a predictable while. These
	# frames do not -- they are stalling on exactly the stream loading that makes
	# the crossfade slow, so the budget shrank precisely when the thing it
	# measures got harder. Thirty seconds is thirteen crossfades and cannot be
	# eaten by a slow frame.
	var settled := false
	var began := Time.get_ticks_msec()
	var stuck: Array[StringName] = []
	while Time.get_ticks_msec() - began < 30000:
		stuck.clear()
		for c: StringName in Audio.resident():
			if c != Audio._cue and Audio._running.get(c, false):
				stuck.append(c)
		if stuck.is_empty():
			settled = true
			break
		await tree.process_frame
	# NAME WHAT DID NOT SETTLE. A timeout that says only "it did not finish"
	# sends you looking at the timeout; one that names the cue sends you to the
	# cue. That distinction cost an hour.
	if not _ok("the crossfades finish in reasonable time"
			+ ("" if settled else " -- still running: %s, current is %s"
				% [stuck, Audio._cue]), settled):
		return _finish()

	# THE CLOCK IS MOVED, NOT WAITED OUT. The threshold is 45 seconds and a test
	# that slept for it is a test nobody runs. `_idle_since` is the only input
	# to the decision, so winding it back is the same measurement.
	var back := Audio.RELEASE_AFTER_MS + 1000
	for cue: StringName in Audio._idle_since.keys():
		Audio._idle_since[cue] = int(Audio._idle_since[cue]) - back
	for i in 6:
		await tree.process_frame

	var after := Audio.resident()
	_ok("the silent ones are released (%s)" % str(after), after.size() == 1)
	_ok("and the one still playing is kept", after.has(&"burn"))

	# TWO CUES IN TWO KEYS MUST NEVER SOUND AT ONCE.
	#
	# This is the rule the third edition needs and the second edition did not:
	# thirteen cues on one pedal could be crossfaded in any combination, and
	# thirteen independent pieces in nine keys cannot. Walking ship, sector,
	# chart, archive used to put B flat major over F minor over G minor over E
	# flat, two at a time, and Jon heard it immediately.
	#
	# Measured rather than asserted: step the mixer through the whole switch and
	# record the largest product of two different cues' gains. Any frame where
	# both are up is a frame where two keys are sounding.
	Audio.play_cue(&"theme", 2)
	for i in 40:
		await tree.process_frame
	Audio.play_cue(&"shells", 2)
	var worst := 0.0
	for i in 400:
		var t: float = float(Audio._gain.get(&"theme", 0.0))
		var sh: float = float(Audio._gain.get(&"shells", 0.0))
		worst = maxf(worst, minf(t, sh))
		if sh > 0.99:
			break
		await tree.process_frame
	_ok("an unrelated cue waits for silence (overlap %.3f)" % worst, worst < 0.02)

	# And the opposite, because the DEEP swap depends on the overlap EXISTING:
	# theme and dread are both on F, and holding both is what makes deep space
	# read as the place turning rather than as the music cutting.
	#
	# Back to theme first and wait for it to be fully up. The obvious version of
	# this test went straight from shells to dread and measured no overlap -- but
	# shells is in G and dread is in F, so the mixer was right and the test was
	# asking the wrong question.
	Audio.play_cue(&"theme", 2)
	for i in 600:
		if float(Audio._gain.get(&"theme", 0.0)) > 0.99:
			break
		await tree.process_frame
	Audio.play_cue(&"dread", 2)
	var together := 0.0
	for i in 600:
		var t2: float = float(Audio._gain.get(&"theme", 0.0))
		var dr: float = float(Audio._gain.get(&"dread", 0.0))
		together = maxf(together, minf(t2, dr))
		if dr > 0.99:
			break
		await tree.process_frame
	_ok("a cue sharing a root still crossfades (overlap %.3f)" % together,
			together > 0.2)
	# The players went with them. A dictionary that forgot a cue while its eight
	# AudioStreamPlayers stayed children of the singleton would report a fix it
	# had not made.
	#
	# Counted against what SHOULD be on the bus rather than a round number: the
	# stems of whatever is still resident, plus the three ambience beds, which
	# also sit on Music and are meant to outlive every cue.
	# Recounted here rather than reusing the list from the release check: the
	# overlap checks above load cues of their own, and counting against a stale
	# snapshot reports a leak that is only bookkeeping.
	after = Audio.resident()
	var want := Audio._beds.size()
	for cue: StringName in after:
		want += (Audio._stems[cue] as Dictionary).size()
	var players := 0
	for c in Audio.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).bus == &"Music":
			players += 1
	_ok("no orphan music players left behind (%d on the bus, %d accounted for)"
		% [players, want], players == want)
	_finish()


func _finish() -> void:
	print("")
	verdict("audiotest")
	_tree.quit(code())
