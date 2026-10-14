class_name OffThread

## WORKER THREADS DO PURE CPU WORK ONLY (Oct 14). A texture, a node, a
## material: each makes a RenderingServer RID, and the RID tables are not safe
## to fill from two threads at once (the headless dummy renderer's least of
## all). A motion cut or a breakup cut on a worker while the main thread loaded
## a card picture gave "Attempting to initialize the wrong RID" on the worker
## and `Parameter "t" is null` in `texture_2d_initialize` on the main thread
## (the gate's faunatest, only with the machine busy; `-- sheet=ThreadStress`
## makes it happen every run).
##
## So code that runs on a worker asks `tex` for its textures: on the main
## thread that is `ImageTexture.create_from_image`, as before; on a worker it
## is an empty `ImageTexture` (no RID until it has a picture) and a copy of the
## picture, owed, and `pay` -- on the main thread, once the worker is done --
## gives each its picture. The same object either way, so everything that
## holds it holds the finished texture; the same pixels, because the copy is
## taken when the texture was asked for.


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
