class_name HullParts
extends RefCounted

## WHERE EACH PART OF A HULL IS, BY HAND (Jon, Nov 15: "designate parts of the ship for each type of
## decision, for current and future ships"): per hull picture, the point on the sprite (its own px,
## bow to the right) that each part's choice brackets. Every hull picture declares all of `ShipParts.SPOTS`;
## `-- sheet=HullPartsTest` fails a picture that does not. Why: docs/why/HullParts.md#hull-parts

## Keyed as `Database.HULL_MOUNTS` and `HULL_EXHAUST` are, by `DB.hull_art_key`.
const SPOTS := {
	"hull_light_c": {
		bow = Vector2i(262, 47),
		bridge = Vector2i(165, 20),
		guns = Vector2i(220, 30),
		mast = Vector2i(135, 14),
		radiators = Vector2i(110, 30),
		engines = Vector2i(92, 45),
		hold = Vector2i(143, 74),
		flank = Vector2i(178, 64),
		plating = Vector2i(217, 61),
	},
	"hull_medium_a": {
		bow = Vector2i(318, 67),
		bridge = Vector2i(170, 30),
		guns = Vector2i(249, 50),
		mast = Vector2i(153, 6),
		radiators = Vector2i(125, 52),
		engines = Vector2i(84, 67),
		hold = Vector2i(153, 95),
		flank = Vector2i(201, 102),
		plating = Vector2i(254, 85),
	},
	"hull_heavy_a": {
		bow = Vector2i(386, 91),
		bridge = Vector2i(215, 48),
		guns = Vector2i(243, 53),
		mast = Vector2i(198, 18),
		radiators = Vector2i(160, 62),
		engines = Vector2i(97, 90),
		hold = Vector2i(182, 116),
		flank = Vector2i(242, 119),
		plating = Vector2i(307, 107),
	},
	"solari/hull_light_a": {
		bow = Vector2i(264, 50),
		bridge = Vector2i(193, 45),
		guns = Vector2i(171, 38),
		mast = Vector2i(143, 30),
		radiators = Vector2i(118, 30),
		engines = Vector2i(93, 49),
		hold = Vector2i(130, 72),
		flank = Vector2i(160, 66),
		plating = Vector2i(195, 54),
	},
	"hull_light_zero": {
		bow = Vector2i(258, 46),
		bridge = Vector2i(215, 33),
		guns = Vector2i(154, 19),
		mast = Vector2i(180, 16),
		radiators = Vector2i(100, 30),
		engines = Vector2i(68, 33),
		hold = Vector2i(147, 72),
		flank = Vector2i(185, 62),
		plating = Vector2i(205, 50),
	},
	"hull_medium_zero": {
		bow = Vector2i(316, 59),
		bridge = Vector2i(284, 43),
		guns = Vector2i(214, 28),
		mast = Vector2i(151, 6),
		radiators = Vector2i(120, 40),
		engines = Vector2i(78, 45),
		hold = Vector2i(108, 88),
		flank = Vector2i(190, 95),
		plating = Vector2i(270, 75),
	},
	"hull_heavy_zero": {
		bow = Vector2i(384, 74),
		bridge = Vector2i(206, 30),
		guns = Vector2i(276, 43),
		mast = Vector2i(191, 17),
		radiators = Vector2i(165, 55),
		engines = Vector2i(92, 54),
		hold = Vector2i(206, 115),
		flank = Vector2i(250, 108),
		plating = Vector2i(330, 90),
	},
	"solari/hull_medium_a": {
		bow = Vector2i(319, 63),
		bridge = Vector2i(216, 39),
		guns = Vector2i(186, 31),
		mast = Vector2i(145, 31),
		radiators = Vector2i(125, 31),
		engines = Vector2i(73, 61),
		hold = Vector2i(145, 95),
		flank = Vector2i(196, 95),
		plating = Vector2i(252, 82),
	},
	"solari/hull_heavy_a": {
		bow = Vector2i(388, 80),
		bridge = Vector2i(262, 45),
		guns = Vector2i(230, 43),
		mast = Vector2i(205, 43),
		radiators = Vector2i(175, 48),
		engines = Vector2i(83, 77),
		hold = Vector2i(173, 107),
		flank = Vector2i(236, 120),
		plating = Vector2i(304, 106),
	},
}


## The hull picture `key`'s part points ({part: Vector2i}), or {} for one nobody has placed.
static func of(key: String) -> Dictionary[StringName, Vector2i]:
	var out: Dictionary[StringName, Vector2i] = {}
	var d: Dictionary = SPOTS.get(key, {})
	for k: Variant in d:
		out[StringName(k)] = d[k]
	return out
