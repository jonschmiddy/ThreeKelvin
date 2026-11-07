extends RefCounted

## Built from the manufacturer: a generic 'hull fittings' prompt gave parts belonging to nobody.
## ART_CONTRACT never says what a faction looks like; SHAPE does, the rest is read from the DB.
## Why: docs/why/ArtPrompt.md#prompt-purpose

## Contrastive: Korvan must look nothing like Verity, so a part is placeable by silhouette.
## Each line is derived from the manufacturer's backstory, not invented.
## Why: docs/why/ArtPrompt.md#shape-lines
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

## Hardcoded steel plating contradicted Calyx being grown: a prompt that argues picks a half.
## Why: docs/why/ArtPrompt.md#surface
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


## Says FLAT four ways and names the failure: 'side view' alone gave off-axis cylinders.
## Why: docs/why/ArtPrompt.md#camera
const CAMERA := "FLAT SIDE ELEVATION, drawn perfectly side-on. No perspective, "  	+ "no foreshortening, no three-quarter angle. No circular end caps or round "  	+ "openings facing the viewer — every opening is seen edge-on as a straight "  	+ "line. Each part is a flat profile seen from directly beside it, as in a "  	+ "technical elevation drawing."


## Structures are the tier ladder, half a hull long, and change its outline; fittings fill a bay.
const BATCH := {
	&"structures": {
		noun = "large spaceship components lying separately",
		size = Vector2i(280, 72),
		# Two or three clauses each: one clause gave four cylinders.
		# Colour named per part: a forced palette gave 0.1% amber from a half-amber reference.
		# Why: docs/why/ArtPrompt.md#part-clauses
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


## Object first, then maker, then light: opening on a surface produces a surface (25 generations).
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
	# Shape only, no backstory: Korvan's 'navy', 'vessel' and 'hull' made three naval warships.
	# Why: docs/why/ArtPrompt.md#shape-only
	out += String(SHAPE.get(m.id, ""))
	# Not capitalize(): GDScript's title-cases EVERY word, and "Steel Blue Armour
	# Plating" mid-sentence reads like a product listing.
	var base := String(BASE.get(m.id, BASE_DEFAULT))
	out += " %s%s throughout, with %s used generously on panels, stripes and "  		% [base.substr(0, 1).to_upper(), base.substr(1), accent]
	out += "shielding rather than as a thin trim. "
	out += "Lit along the top edge and shadowed underneath, cold directional light, "
	out += String(FINISH.get(m.id, FINISH_DEFAULT)) + ". No background."
	return out


## The maker colour as a word, as a hex reads as noise; it nudges which entry is reached for.
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
