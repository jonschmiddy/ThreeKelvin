class_name SkillCheck
extends RefCounted

## A check asks how far short you are, in fixed steps; meeting it is certain, with no roll.
## Why: docs/why/SkillCheck.md#shortfall-ladder
const ODDS: Array[float] = [1.0, 0.65, 0.40, 0.20, 0.05]

## What came out. MET is its own band rather than a perfect CLEAN because the
## fiction differs: one is doing the thing, the other is getting away with it.
enum Band { MET, CLEAN, PARTIAL, BOTCHED }

## Reads the CURRENT value, so a holed ship fails a Hull check it would pass at full.
## Why: docs/why/SkillCheck.md#current-values
static func shortfall(check: Dictionary) -> int:
	return maxi(0, int(check.get("need", 0)) - value_of(check))

static func value_of(check: Dictionary) -> int:
	match StringName(check.get("attr", &"")):
		&"hull": return Run.attr_hull()
		&"thrust": return Run.attr_thrust()
		&"maneuver": return Run.attr_maneuver()
		&"thermal": return Run.attr_thermal()
		&"sensors": return Run.attr_sensors()
		&"stealth": return Run.attr_stealth()
	return 0

## A 5% floor keeps a desperate option from being a disabled button with extra steps.
static func odds(check: Dictionary) -> float:
	return ODDS[mini(shortfall(check), ODDS.size() - 1)]

## A harness's band: every check lands here when it is 0 or more, so
## `-- sheet=RewardShownTest` can reach every outcome of every choice. -1 rolls.
static var forced := -1

## Failure splits evenly between PARTIAL and BOTCHED; partial is where the design effort goes.
## Why: docs/why/SkillCheck.md#failure-split
static func roll(check: Dictionary) -> Band:
	if forced >= 0:
		return forced as Band
	if shortfall(check) <= 0:
		return Band.MET
	var p := odds(check)
	var r := Rng.event.randf()
	if r < p:
		return Band.CLEAN
	return Band.PARTIAL if r < p + (1.0 - p) * 0.5 else Band.BOTCHED

## Shows requirement, value and odds together: the player chooses against odds, not surprises.
## Why: docs/why/SkillCheck.md#odds-badge
static func badge(check: Dictionary) -> String:
	var have := value_of(check)
	var need := int(check.get("need", 0))
	var pct := int(round(odds(check) * 100.0))
	if have >= need:
		return "%s %d · you have %d · %s" % [attr_name(check), need,
			have, verdict(check)]
	return "%s %d · you have %d · %d%% · %s" % [
		attr_name(check), need, have, pct, verdict(check)]


## One word per rung; the bottom is not certain failure, as the 5% floor must stay a bet.
## Why: docs/why/SkillCheck.md#odds-in-words
const VERDICTS: Array[String] = ["certain success", "likely", "uncertain",
	"unlikely", "near-certain failure"]

static func verdict(check: Dictionary) -> String:
	return VERDICTS[mini(shortfall(check), VERDICTS.size() - 1)]

## Read before the outcome runs: `value_of` reads the current attribute, so later changes mislead.
## Why: docs/why/SkillCheck.md#read-before-outcome
static func odds_line(check: Dictionary) -> String:
	if check.is_empty():
		return ""
	return "%s %d · %d%%" % [attr_name(check), int(check.get("need", 0)),
		int(round(odds(check) * 100.0))]


static func attr_name(check: Dictionary) -> String:
	match StringName(check.get("attr", &"")):
		&"hull": return "HULL"
		&"thrust": return "THRUST"
		&"maneuver": return "MANEUVERABILITY"
		&"thermal": return "THERMAL"
		&"sensors": return "SENSORS"
		&"stealth": return "STEALTH"
	return "?"

## Green when certain, warming as odds worsen, so long shots show without reading.
static func badge_colour(check: Dictionary) -> Color:
	match mini(shortfall(check), 4):
		0: return UITheme.GOOD
		1: return UITheme.CHILL
		2: return UITheme.EMBER
		3: return UITheme.FLARE
	return Color("#d4614f")

## Falls back down the ladder so an event may author only the bands it cares about.
static func pick_outcome(opt: Dictionary, band: Band) -> Callable:
	var order: Array[StringName] = []
	match band:
		Band.MET: order = [&"met", &"clean", &"partial", &"botched"]
		Band.CLEAN: order = [&"clean", &"met", &"partial", &"botched"]
		Band.PARTIAL: order = [&"partial", &"botched", &"clean", &"met"]
		Band.BOTCHED: order = [&"botched", &"partial", &"clean", &"met"]
	for key in order:
		if opt.has(key):
			return opt[key] as Callable
	return Callable()

static func band_name(band: Band) -> String:
	match band:
		# SUCCESS, not MET: the other labels are outcomes, and one odd noun never parsed.
		# Why: docs/why/SkillCheck.md#band-names
		Band.MET: return "SUCCESS"
		Band.CLEAN: return "SCRAPED THROUGH"
		Band.PARTIAL: return "PARTIAL"
	return "BOTCHED"

## MET and CLEAN collapse for the stamp, which only has room for you succeeded.
## Why: docs/why/SkillCheck.md#band-names
static func band_result(band: Band) -> StringName:
	match band:
		Band.PARTIAL: return MapGen.R_PARTIAL
		Band.BOTCHED: return MapGen.R_BOTCHED
	return MapGen.R_SUCCESS


static func band_colour(band: Band) -> Color:
	match band:
		Band.MET: return UITheme.GOOD
		Band.CLEAN: return UITheme.CHILL
		Band.PARTIAL: return UITheme.EMBER
	return Color("#d4614f")
