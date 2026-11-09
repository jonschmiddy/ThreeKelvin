class_name OffThread

## Workers do pure CPU work only: RID tables are not safe to fill from two threads (Oct 14).
## On a worker `tex` returns an empty texture and `pay` fills it on the main thread.
## Why: docs/why/OffThread.md#worker-thread-rule


static func on_main() -> bool:
	return OS.get_thread_caller_id() == OS.get_main_thread_id()


## A texture of `im`, now on the main thread, owed (in `owed`) on a worker.
static func tex(im: Image, owed: Array) -> ImageTexture:
	if on_main():
		return ImageTexture.create_from_image(im)
	var t := ImageTexture.new()
	owed.append([t, im.duplicate()])
	return t


## On the main thread: every owed texture its picture.
static func pay(owed: Array) -> void:
	assert(on_main())
	for o in owed:
		(o[0] as ImageTexture).set_image(o[1])
	owed.clear()
