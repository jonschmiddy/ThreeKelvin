class_name GameClock
extends RefCounted

## THE CLOCK WHAT YOU SEE RUNS ON: game seconds, the process delta summed, so
## `Engine.time_scale` reaches it and a film made with the movie writer runs it
## at the film's speed.
##
## `Time.get_ticks_msec()` is the wall's clock. In play the two agree; in a film
## they do not. The movie writer steps the game 1/60 s a frame, and a 1080p
## frame takes about 210 ms of wall time to write, so everything on the wall
## clock ran 12.7 times too fast (Jon, of the fight films: "the hovering
## animation is REALLY fast"; the cutter's bob measured 0.375 s a cycle against
## its 4.76). The wall clock also ignored the hit-stop's slow motion.
##
## ONE CLOCK, ADVANCED ONCE A FRAME by whichever reader asks first, so a pack's
## bobs stay a third of a cycle apart (`EnemySlot._bob_phase`) and a slot made
## later lands in step with the ones already there. A frame nobody reads is a
## frame it does not count: nothing on screen was keeping time then, and the
## next reader carries on from where the last one left off.
##
## Not for measuring how long something took: that is the wall's question.

static var _t := 0.0
static var _frame := -1


## Seconds of game time.
static func now() -> float:
	var f := Engine.get_process_frames()
	if f != _frame:
		if _frame >= 0:
			var tree := Engine.get_main_loop() as SceneTree
			if tree != null:
				_t += tree.root.get_process_delta_time()
		_frame = f
	return _t


## Milliseconds of game time, for the deadlines kept as whole ms.
static func now_ms() -> int:
	return int(now() * 1000.0)
