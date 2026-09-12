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
	for pair in [[&"first_light", 2], [&"shells", 2], [&"warm", 1], [&"burn", 4]]:
		Audio.play_cue(pair[0], pair[1])
		await tree.process_frame
	var loaded := Audio.resident()
	if not _ok("playing four cues loads four, and they stay while warm (%d)"
			% loaded.size(), loaded.size() == 4):
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
	# AND THE BOUND IS A FAILURE, NOT A SHRUG. At 600 frames this passed, then
	# failed once, then passed again -- because the second-edition cues are six
	# 96-second streams and loading four of them can stall long enough to eat
	# the budget. A loop that runs out and carries on silently turns a timing
	# problem into a wrong answer about the thing being tested, which is how a
	# flaky check is worse than no check.
	var settled := false
	for i in 3600:
		var busy := false
		for c: StringName in Audio.resident():
			if c != Audio._cue and Audio._running.get(c, false):
				busy = true
		if not busy:
			settled = true
			break
		await tree.process_frame
	if not _ok("the crossfades finish in reasonable time", settled):
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
	# The players went with them. A dictionary that forgot a cue while its eight
	# AudioStreamPlayers stayed children of the singleton would report a fix it
	# had not made.
	#
	# Counted against what SHOULD be on the bus rather than a round number: the
	# stems of whatever is still resident, plus the three ambience beds, which
	# also sit on Music and are meant to outlive every cue.
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
