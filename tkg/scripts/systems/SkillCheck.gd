class_name SkillCheck
extends RefCounted

## An event option gated on one of the six attributes.
##
## A check is a dictionary on the option: `{attr = &"hull", need = 5}`. The
## screen asks this class what it costs, what the odds are, and — once pressed —
## which of four outcomes happened.
##
## THE SHORTFALL LADDER IS THE WHOLE DESIGN. A check is not a die roll against a
## target; it is a question about how far short you are, and the answer degrades
## in fixed steps. Meeting it is CERTAIN — no roll at all — because an attribute
## you have earned should never fail you, and a 5% chance of disaster on a
## requirement you exceeded is the kind of thing that makes players stop trusting
## the numbers on their ship.
##
## Being one short is a real attempt. Being four short is a stunt.
const ODDS: Array[float] = [1.0, 0.65, 0.40, 0.20, 0.05]

## What came out. MET is its own band rather than a perfect CLEAN because the
## fiction differs: one is doing the thing, the other is getting away with it.
enum Band { MET, CLEAN, PARTIAL, BOTCHED }

## How far under the requirement you are. Zero or less means you meet it.
##
## Reads the CURRENT value, which is the rule from attributes-and-checks.md §0
## and the reason the attributes are derived rather than stored: a holed ship
## really does fail a Hull check it would have passed at full, and that is the
## damage mattering outside combat.
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

## Chance of the good outcome. Past four short the ladder stops rather than
## reaching zero — a 5% floor keeps a desperate option from being a disabled
## button with extra steps, and someone will always take it.
static func odds(check: Dictionary) -> float:
	return ODDS[mini(shortfall(check), ODDS.size() - 1)]

## Roll it.
##
## On a shortfall, failure splits evenly between PARTIAL and BOTCHED rather than
## everything landing on the worst case. Partial is where the design effort goes:
## it is the outcome that has to be interesting rather than merely bad, because
## it is the one a marginal attempt produces most often.
static func roll(check: Dictionary) -> Band:
	if shortfall(check) <= 0:
		return Band.MET
	var p := odds(check)
	var r := Rng.event.randf()
	if r < p:
		return Band.CLEAN
	return Band.PARTIAL if r < p + (1.0 - p) * 0.5 else Band.BOTCHED

## The label under the option: what it wants, what you have, what that is worth.
##
## All three, always. The requirement alone cannot be judged without your value,
## your value alone does not say whether it is enough, and the percentage alone
## hides which attribute to go and improve. attributes-and-checks.md §7.3 asks
## for exactly this and it is the only honest form: the player is choosing
## against odds, so the odds are not a surprise to be sprung.
static func badge(check: Dictionary) -> String:
	var have := value_of(check)
	var need := int(check.get("need", 0))
	var pct := int(round(odds(check) * 100.0))
	if have >= need:
		return "%s %d · you have %d · %s" % [attr_name(check), need,
			have, verdict(check)]
	return "%s %d · you have %d · %d%% · %s" % [
		attr_name(check), need, have, pct, verdict(check)]


## THE ODDS IN WORDS, and it replaced what one more pip would buy.
##
## The badge used to end "one more: 65%", pricing the next module for you at the
## moment you were short. That is a shopping answer to a gambling question: you
## are standing in front of a thing you are about to do, and what you want to
## know is whether to do it. The number is already there; the word is what it
## MEANS, and reading the two together is how the percentage stops being a
## digit and starts being a feeling.
##
## ONE WORD PER RUNG, not thresholds on the percentage. `ODDS` has exactly five
## steps and they are fixed, so there is nothing to interpolate and no boundary
## to get wrong -- the ladder is the vocabulary.
##
## THE BOTTOM RUNG IS NOT "CERTAIN FAILURE" and that is deliberate. It is 5%,
## kept off zero on purpose -- see `odds` -- so that a desperate option is a bet
## someone will take rather than a disabled button with extra steps. Calling it
## certain would talk the player out of the exact choice the floor exists to
## preserve, and it would be a lie about a number printed beside it.
const VERDICTS: Array[String] = ["certain success", "likely", "uncertain",
	"unlikely", "near-certain failure"]

static func verdict(check: Dictionary) -> String:
	return VERDICTS[mini(shortfall(check), VERDICTS.size() - 1)]

static func attr_name(check: Dictionary) -> String:
	match StringName(check.get("attr", &"")):
		&"hull": return "HULL"
		&"thrust": return "THRUST"
		&"maneuver": return "MANEUVERABILITY"
		&"thermal": return "THERMAL"
		&"sensors": return "SENSORS"
		&"stealth": return "STEALTH"
	return "?"

## Colour for the badge: green when it is a certainty, warming as it gets
## further out of reach. The odds are already written; this is so you can see
## which options are long shots without reading any of them.
static func badge_colour(check: Dictionary) -> Color:
	match mini(shortfall(check), 4):
		0: return UITheme.GOOD
		1: return UITheme.CHILL
		2: return UITheme.EMBER
		3: return UITheme.FLARE
	return Color("#d4614f")

## Which of the four outcome callables an option should run. Falls back down the
## ladder so an event may author only the bands it cares about: a check with one
## `met` and one `botched` is a legal, complete option.
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
		Band.MET: return "MET"
		Band.CLEAN: return "SCRAPED THROUGH"
		Band.PARTIAL: return "PARTIAL"
	return "BOTCHED"

static func band_colour(band: Band) -> Color:
	match band:
		Band.MET: return UITheme.GOOD
		Band.CLEAN: return UITheme.CHILL
		Band.PARTIAL: return UITheme.EMBER
	return Color("#d4614f")
