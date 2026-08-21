extends RefCounted

## Build a PixelLab prompt from a manufacturer, rather than from memory.
##
##     godot --headless --path . -- artprompt korvan structures
##     godot --headless --path . -- artprompt halcyon fittings
##     godot --headless --path . -- artprompt              (every house, every batch)
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
## reads on the same house.

## What each house's parts are SHAPED like. The one thing here that is not
## already in the game, because the game had no reason to know it.
##
## Written to be CONTRASTIVE. The point is not that Korvan looks industrial —
## it is that Korvan looks nothing like Halcyon, so a part is placeable by
## silhouette before the palette is read. Each line was derived from that
## house's own backstory rather than invented: Korvan "inherited the jigs",
## Dredge is "everything is salvage", Halcyon signs each hull.
const SHAPE := {
	&"korvan": "Heavy stamped plate, blunt right angles, exposed bolt heads and "
		+ "stencilled navy part numbers. Overbuilt and interchangeable, tooled to a "
		+ "specification two centuries obsolete. Nothing streamlined, nothing "
		+ "decorative, no curves that are not structural.",
	&"solari": "Finned radiators, ribbed heat sinks, exposed coolant runs and "
		+ "heat-stained discoloured metal. Vents everywhere. Every part looks like it "
		+ "is working hard not to melt.",
	&"dredge": "Assembled from salvage: mismatched plate in three different metals, "
		+ "visible weld beads, cut-and-shut joins, fasteners that do not match each "
		+ "other. Parts bolted where they fit rather than where they belong.",
	&"redline": "Thin swept panels, raked angles, quick-release catches and hidden "
		+ "compartments. Filed-off serial numbers and fresh paint over older paint. "
		+ "Light, fast and faintly illegal.",
	&"halcyon": "Thin precise panels with flush fasteners and almost no visible "
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
	&"halcyon": "flush fasteners and almost invisible seams",
	&"dredge": "mismatched rivets and visible weld beads",
	&"cygnet": "hex apertures and fine panel joins",
}
const FINISH_DEFAULT := "rivets and panel seam lines"


## The part lists worth asking for, and roughly how big each one is.
##
## STRUCTURES are the tier ladder: a C-class is the bare frame and every grade
## above bolts one of these on, so they are half the length of a hull and they
## change its outline. FITTINGS are the small stuff that fills a bay.
const BATCH := {
	&"structures": {
		noun = "large hull structures",
		size = Vector2i(280, 72),
		parts = ["a long dorsal cargo block with a hatch",
			"a wide ventral hold with landing skids beneath it",
			"a pair of engine nacelles on a mounting pylon"],
		scale = "Each one a LARGE bolt-on section, roughly half the length of the "
			+ "ship it attaches to.",
	},
	&"fittings": {
		noun = "small bolt-on hull modules",
		size = Vector2i(160, 48),
		parts = ["a louvred vent grille", "a ribbed cargo panel",
			"a lit sensor strip with indicator lights", "a short blunt gun mount"],
		scale = "Each one a small rectangular bolt-on module about twenty pixels wide.",
	},
	&"weapons": {
		noun = "hull-mounted weapons",
		size = Vector2i(200, 56),
		parts = ["a short autocannon with a stubby barrel",
			"a long mass driver with a heavy breech",
			"a multi-barrel rotary cannon"],
		scale = "Each one a hull-mounted weapon, barrel pointing right.",
	},
}


func run(tree: SceneTree) -> void:
	var args := OS.get_cmdline_user_args()
	var want_maker := &""
	var want_batch := &""
	for a in args:
		var s := StringName(a)
		if DB.manufacturers.has(s):
			want_maker = s
		elif BATCH.has(s):
			want_batch = s

	var makers: Array = [want_maker] if want_maker != &"" else DB.manufacturers.keys()
	var batches: Array = [want_batch] if want_batch != &"" else BATCH.keys()
	for m in makers:
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
	var parts: Array = spec.parts
	var listed := ", ".join(PackedStringArray(parts.slice(0, parts.size() - 1))) \
		+ " and " + String(parts[-1])
	var out := "%d %s for a %s vessel, side view, on a " % [
		parts.size(), String(spec.noun), m.name.to_upper()]
	out += "transparent background, evenly spaced in a row with clear empty gaps "
	out += "between them: %s. " % listed
	out += String(spec.scale) + " "
	# Who they are, in their own words. The tagline and the backstory are what a
	# player reads when choosing this house; the parts should agree with it.
	out += "%s is \"%s\" — %s " % [m.name, m.tagline, m.backstory]
	out += String(SHAPE.get(m.id, ""))
	# Not capitalize(): GDScript's title-cases EVERY word, and "Steel Blue Armour
	# Plating" mid-sentence reads like a product listing.
	var base := String(BASE.get(m.id, BASE_DEFAULT))
	out += " %s%s with %s accents. " % [
		base.substr(0, 1).to_upper(), base.substr(1), _accent_word(m.colour)]
	out += "Lit along the top edge and shadowed underneath, cold directional light, "
	out += String(FINISH.get(m.id, FINISH_DEFAULT)) + ". No background."
	return out


## The house colour as a word, because a hex in a prompt reads as noise. The
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
