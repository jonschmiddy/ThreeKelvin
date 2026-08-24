extends RefCounted

## Build a PixelLab prompt from a manufacturer, rather than from memory.
##
##     godot --headless --path . -- artprompt korvan structures
##     godot --headless --path . -- artprompt verity fittings
##     godot --headless --path . -- artprompt      (every manufacturer, every batch)
##
## WHY THIS EXISTS. Every prompt sent this session said "spaceship hull
## fittings" and nothing else, so the generator produced generic parts that
## belong to nobody. The game already knows who Korvan are in four separate
## fields and none of it was reaching the model.
##
## `art/ART_CONTRACT.md` states the rule — "silhouette reads chassis, modules
## read faction" — and then never says what any faction LOOKS like. That gap is
## SHAPE below. The rest is read live from DB.manufacturers, so the fiction has
## exactly one home and a prompt cannot quietly drift from the tooltip a player
## reads on the same manufacturer.

## What each manufacturer's parts are SHAPED like. The one thing here that is not
## already in the game, because the game had no reason to know it.
##
## Written to be CONTRASTIVE. The point is not that Korvan looks industrial —
## it is that Korvan looks nothing like Verity, so a part is placeable by
## silhouette before the palette is read. Each line was derived from that
## manufacturer's own backstory rather than invented: Korvan "inherited the jigs",
## Probate is "everything is salvage", Verity signs each hull.
const SHAPE := {
	&"korvan": "Heavy stamped plate, blunt right angles, exposed bolt heads and "
		+ "stencilled navy part numbers. Overbuilt and interchangeable, tooled to a "
		+ "specification two centuries obsolete. Nothing streamlined, nothing "
		+ "decorative, no curves that are not structural.",
	&"solari": "Finned radiators, ribbed heat sinks, exposed coolant runs and "
		+ "heat-stained discoloured metal. Vents everywhere. Every part looks like it "
		+ "is working hard not to melt.",
	&"probate": "Assembled from salvage: mismatched plate in three different metals, "
		+ "visible weld beads, cut-and-shut joins, fasteners that do not match each "
		+ "other. Parts bolted where they fit rather than where they belong.",
	&"redline": "Thin swept panels, raked angles, quick-release catches and hidden "
		+ "compartments. Filed-off serial numbers and fresh paint over older paint. "
		+ "Light, fast and faintly illegal.",
	&"verity": "Thin precise panels with flush fasteners and almost no visible "
		+ "seams. Clean unbroken curves, one small maker's mark, nothing surplus. "
		+ "Expensive restraint.",
	&"cygnet": "Honeycomb launch cells and hexagonal apertures, small repeated "
		+ "openings, rails and cradles. Every part is a housing for something smaller "
		+ "that comes out of it.",
	&"calyx": "Grown rather than built. Ribbed organic forms, segmented chitinous "
		+ "plates, no straight lines, seams that look sutured, surfaces that look "
		+ "faintly alive.",
}

## What the surface is made of, and how it is held together.
##
## Both used to be hardcoded into the tail of the prompt, which told Calyx to
## have "steel blue plating" and "rivets and panel seam lines" two sentences
## after telling it that it is grown rather than built. A prompt that argues
## with itself gets to pick which half to believe.
const BASE := {
	&"calyx": "pale chitinous shell",
	&"cygnet": "light alloy panelling",
}
const BASE_DEFAULT := "steel blue armour plating"

const FINISH := {
	&"calyx": "growth rings and sutured seams",
	&"verity": "flush fasteners and almost invisible seams",
	&"probate": "mismatched rivets and visible weld beads",
	&"cygnet": "hex apertures and fine panel joins",
}
const FINISH_DEFAULT := "rivets and panel seam lines"


## The camera, spelled out.
##
## "side view" is not enough on its own — a run came back as cylinders seen
## slightly off-axis, circular end caps facing the viewer, which satisfies "side"
## and violates the contract. A part drawn round cannot sit on a hull drawn flat,
## so this says FLAT four different ways and names the specific failure.
const CAMERA := "FLAT SIDE ELEVATION, drawn perfectly side-on. No perspective, "  	+ "no foreshortening, no three-quarter angle. No circular end caps or round "  	+ "openings facing the viewer — every opening is seen edge-on as a straight "  	+ "line. Each part is a flat profile seen from directly beside it, as in a "  	+ "technical elevation drawing."


## The part lists worth asking for, and roughly how big each one is.
##
## STRUCTURES are the tier ladder: a C-class is the bare frame and every grade
## above bolts one of these on, so they are half the length of a hull and they
## change its outline. FITTINGS are the small stuff that fills a bay.
const BATCH := {
	&"structures": {
		noun = "large spaceship components lying separately",
		size = Vector2i(280, 72),
		# TWO OR THREE CLAUSES EACH, and deliberately different shapes.
		#
		# One clause apiece produced four variations on a cylinder: given room to
		# settle, the generator finds one comfortable form and repeats it. Naming
		# a proportion and a distinguishing feature per part is what stops that.
		# COLOUR NAMED PER PART, not once at the end.
		#
		# Measured: a forced palette constrains which colours are LEGAL and says
		# nothing about proportion — a reference that was half amber produced 0.1%
		# amber. And a single colour sentence trailing after five sentences of
		# camera instruction got ignored: the run that finally got shape and camera
		# right came back with 7 colours and zero amber.
		#
		# So the accent is attached to the objects instead. "%s" is the manufacturer
		# colour, filled in by _prompt() from the manufacturer record.
		parts = ["a long flat-topped rectangular cargo block, twice as wide as it "
				+ "is tall, its flank faced with %s ribbed panels set in steel "
				+ "framing, and a square hatch at one end",
			"a wide shallow ventral hold, a flat-bottomed steel box with a bold "
				+ "%s stripe running along its side and two landing skids hanging "
				+ "below it on short vertical struts",
			"a pair of stacked engine nacelles on an upright mounting pylon, each "
				+ "a blunt slab-sided tube with %s heat shielding around a flared "
				+ "exhaust at the left end"],
		scale = "These are DETACHED PARTS, not ships. Each is one section that "
			+ "bolts onto a spaceship, drawn alone with nothing else attached to "
			+ "it. No complete ships, no masts, no superstructure, no water.",
	},
	&"fittings": {
		noun = "small spaceship components lying separately",
		size = Vector2i(160, 48),
		parts = ["a louvred vent grille", "a ribbed cargo panel",
			"a lit sensor strip with indicator lights", "a short blunt gun mount"],
		scale = "Each one a small rectangular bolt-on module about twenty pixels wide.",
	},
	&"weapons": {
		noun = "spaceship weapon components lying separately",
		size = Vector2i(200, 56),
		parts = ["a short autocannon with a stubby barrel",
			"a long mass driver with a heavy breech",
			"a multi-barrel rotary cannon"],
		scale = "Each one a hull-mounted weapon, barrel pointing right.",
	},
}


func run(tree: SceneTree) -> void:
	var args := OS.get_cmdline_user_args()
	var want_manufacturer := &""
	var want_batch := &""
	for a in args:
		var s := StringName(a)
		if DB.manufacturers.has(s):
			want_manufacturer = s
		elif BATCH.has(s):
			want_batch = s

	var manufacturers: Array = [want_manufacturer] if want_manufacturer != &"" else DB.manufacturers.keys()
	var batches: Array = [want_batch] if want_batch != &"" else BATCH.keys()
	for m in manufacturers:
		for b in batches:
			_emit(m, b)
	tree.quit()


func _emit(id: StringName, batch: StringName) -> void:
	var m: ManufacturerData = DB.manufacturers[id]
	var spec: Dictionary = BATCH[batch]
	var size: Vector2i = spec.size

	print("\n" + "=".repeat(72))
	print("%s  /  %s        %dx%d" % [m.name.to_upper(), String(batch).to_upper(),
		size.x, size.y])
	print("=".repeat(72))
	print("\n--- settings ---")
	print("  tool              create_image_pixflux   (1 generation)")
	print("  width, height     %d, %d" % [size.x, size.y])
	# Both of these were learned the hard way and neither is optional.
	print("  color_image_url   the hull sprite  <- forces the palette. inpaint_image")
	print("                    has no such parameter, which is why every masked edit")
	print("                    drifted 17-41 new colours.")
	print("  init_image        NONE             <- no_background is SILENTLY IGNORED")
	print("                    when an init is supplied. Measured 12 times out of 12.")
	print("  no_background     true")
	print("\n--- prompt ---")
	print(_prompt(m, spec))


## The prompt itself. Order matters: the OBJECT first, then who made it, then
## how it is lit. A prompt that opens by describing a surface produces a
## surface — a create_image_pro run burned 25 generations proving that.
func _prompt(m: ManufacturerData, spec: Dictionary) -> String:
	# Fill the accent into any part that asked for it.
	var accent := _accent_word(m.colour)
	var parts: Array = []
	for raw in spec.parts:
		var t := String(raw)
		parts.append(t % accent if t.contains("%s") else t)
	var listed := ", ".join(PackedStringArray(parts.slice(0, parts.size() - 1))) \
		+ " and " + String(parts[-1])
	# "vessel" is out too, along with "hull" as a noun for the whole thing. Both
	# read as SHIP, and a ship is what came back. What is wanted is a PART.
	var out := "%d detached %s, side view, on a " % [
		parts.size(), String(spec.noun)]
	out += "transparent background, evenly spaced in a row with clear empty gaps "
	out += "between them: %s. " % listed
	out += String(spec.scale) + " " + CAMERA + " "
	# SHAPE ONLY. The backstory does NOT go in.
	#
	# It used to, on the reasoning that the parts should agree with the fiction a
	# player reads. What came back was three naval surface ships — masts,
	# superstructures, waterlines. Korvan's backstory contains "navy
	# specification", "vessel" and "hull", which are words chosen to make a
	# person feel something and which a generator reads as an instruction to
	# draw a warship. The lore paragraph overrode every other line in the prompt.
	#
	# So the backstory's job is to tell whoever writes SHAPE what this manufacturer is.
	# SHAPE is the translation, and only the translation is sent. Prose written
	# for players is not a prompt and pasting it in is not free.
	out += String(SHAPE.get(m.id, ""))
	# Not capitalize(): GDScript's title-cases EVERY word, and "Steel Blue Armour
	# Plating" mid-sentence reads like a product listing.
	var base := String(BASE.get(m.id, BASE_DEFAULT))
	out += " %s%s throughout, with %s used generously on panels, stripes and "  		% [base.substr(0, 1).to_upper(), base.substr(1), accent]
	out += "shielding rather than as a thin trim. "
	out += "Lit along the top edge and shadowed underneath, cold directional light, "
	out += String(FINISH.get(m.id, FINISH_DEFAULT)) + ". No background."
	return out


## The manufacturer colour as a word, because a hex in a prompt reads as noise. The
## forced palette does the real work; this only nudges which of its entries the
## generator reaches for, which is the gap the fittings exposed — every colour
## was legal and the parts still came back greyer than the ship.
func _accent_word(c: Color) -> String:
	var h := c.h * 360.0
	if c.s < 0.2:
		return "pale steel"
	if h < 15.0 or h >= 345.0:
		return "red"
	if h < 40.0:
		return "amber-gold"
	if h < 65.0:
		return "brass-yellow"
	if h < 170.0:
		return "green"
	if h < 200.0:
		return "cyan"
	return "violet"
