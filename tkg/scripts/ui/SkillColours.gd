class_name SkillColours
extends RefCounted

## The skill check's colours, kept with the screens that paint them; `SkillCheck` is rules and names no colour.

## Green when certain, warming as odds worsen, so long shots show without reading.
static func badge_colour(check: Dictionary) -> Color:
	match mini(SkillCheck.shortfall(check), 4):
		0: return UITheme.GOOD
		1: return UITheme.CHILL
		2: return UITheme.EMBER
		3: return UITheme.FLARE
	return Color("#d4614f")

static func band_colour(band: SkillCheck.Band) -> Color:
	match band:
		SkillCheck.Band.MET: return UITheme.GOOD
		SkillCheck.Band.CLEAN: return UITheme.CHILL
		SkillCheck.Band.PARTIAL: return UITheme.EMBER
	return Color("#d4614f")
