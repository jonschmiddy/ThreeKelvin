class_name GameClock
extends RefCounted

## The wall clock ran films 12.7x too fast under the movie writer. This is process-delta
## time, one clock.
## Why: docs/why/GameClock.md#game-clock

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
