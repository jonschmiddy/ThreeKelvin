extends RefCounted

## The refit screen, photographed, one weight at a time.
##
##   godot --path . -- shipshot            the heavy, which is the tight one
##   godot --path . -- shipshot medium
##   godot --path . -- shipshot all        one PNG per weight
##
## WHY THIS EXISTS. The refit screen's layout is a budget between two panels: the
## masthead is as deep as the ship in it and the workbench gets what is left. The
## question every change to it asks is "does the deepest hold still fit", and the
## deepest hold belongs to the heavy — 6x5 cells against the light's 4x3. That is
## not a question you can answer by opening the screen on whatever ship a new run
## happened to roll, and it is not one a still of the wrong weight can answer at
## all.
##
## Same shape as ConvoyTest's `convoy` mode and for the same reason: it needs a
## window, it cannot assert anything, and it exists because layout questions are
## answered by looking.

const WEIGHTS := {
	"light": HullData.Weight.LIGHT,
	"medium": HullData.Weight.MEDIUM,
	"heavy": HullData.Weight.HEAVY,
}


func run(tree: SceneTree) -> void:
	# One frame before anything is added, for the reason ConvoyTest records:
	# Main is still inside _ready() and a node cannot take children while it is
	# setting up its own.
	await tree.process_frame
	var argv := OS.get_cmdline_user_args()
	var want: Array = []
	if "all" in argv:
		want = ["light", "medium", "heavy"]
	else:
		for w in WEIGHTS:
			if w in argv:
				want = [w]
				break
		# The heavy by default. A tool whose job is the tight case should not
		# need to be told which one that is.
		if want.is_empty():
			want = ["heavy"]

	for name in want:
		await _shot(tree, name)
	tree.quit()


func _shot(tree: SceneTree, weight_name: String) -> void:
	Run.start_new_run(&"korvan", int(WEIGHTS[weight_name]))
	Router.show_ship()
	# The ship flies in and the mounts settle behind it. Shorter than the
	# convoy's 460 because nothing is staggered here, long enough that the
	# arrival is over rather than half done.
	for i in 200:
		await RenderingServer.frame_post_draw
	var path := "user://ship_%s.png" % weight_name
	tree.root.get_texture().get_image().save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
