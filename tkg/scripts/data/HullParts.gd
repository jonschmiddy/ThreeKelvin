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
	"solari/hull_light_zero": {
		bow = Vector2i(262, 78),
		bridge = Vector2i(132, 19),
		guns = Vector2i(142, 23),
		mast = Vector2i(106, 11),
		radiators = Vector2i(76, 14),
		engines = Vector2i(60, 44),
		hold = Vector2i(85, 73),
		flank = Vector2i(128, 68),
		plating = Vector2i(173, 49),
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
	"solari/hull_medium_zero": {
		bow = Vector2i(318, 92),
		bridge = Vector2i(189, 19),
		guns = Vector2i(190, 12),
		mast = Vector2i(150, 12),
		radiators = Vector2i(126, 16),
		engines = Vector2i(95, 56),
		hold = Vector2i(146, 92),
		flank = Vector2i(200, 96),
		plating = Vector2i(254, 79),
	},
	"solari/hull_heavy_zero": {
		bow = Vector2i(386, 97),
		bridge = Vector2i(237, 24),
		guns = Vector2i(243, 17),
		mast = Vector2i(221, 16),
		radiators = Vector2i(193, 22),
		engines = Vector2i(128, 70),
		hold = Vector2i(192, 102),
		flank = Vector2i(249, 119),
		plating = Vector2i(311, 100),
	},
}


## The hull picture `key`'s part points ({part: Vector2i}), or {} for one nobody has placed.
static func of(key: String) -> Dictionary[StringName, Vector2i]:
	var out: Dictionary[StringName, Vector2i] = {}
	var d: Dictionary = SPOTS.get(key, {})
	for k: Variant in d:
		out[StringName(k)] = d[k]
	return out
