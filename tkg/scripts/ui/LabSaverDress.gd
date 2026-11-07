class_name LabSaverDress
extends RefCounted

## EACH OWNER'S DRESSING OF THE SEVEN KEPT SAVERS (Jon, Nov 7: "S:B,1,2,3,4,5,6
## OWNER", all seven kept, in the owner's dress). The savers (`LabSavers` B and
## 1 to 6) draw the same pictures at every Lab; what changes per owner is here:
## its colour where the lab's ink was plain, the words it logs, its posters.
## From the r6 review's dressing notes (review_lab/r6, one per owner).
##
## Keys, every one optional (`of` fills the rest from `BASE`, the undressed look
## an independent lab shows):
##
##   acc          the owner's accent, or null for the lab's own ink
##   B   b_hub    the flight computer's glow in the accent
##       b_pulse  the DATA running down the owned arms in the accent
##       b_owned  the owned steps' rings in the accent
##       b_diamond  the DATA drawn as small unit diamonds (Cygnet)
##   1   s1_label   the column's label over the target
##       s1_cross   the crosshair in the accent
##       s1_style   "" plain; "navy" TARGET n and RANGE; "heat" TEMP first in
##                  the accent and the star in the heat ramp; "mask" the name
##                  under a hatched bar; "rules" the crosshair as two rules and
##                  a hairline; "hex" a hex aperture and UNITS NEAR n; "bio"
##                  SPECIMEN VIABLE and the fauna
##       s1_band    a riveted band under the header (Korvan's card hem)
##       s1_foot    the count at the foot (%d); s1_foot_short where it will not fit
##   2   s2_label, s2_code (%d, or no number), s2_done   the column's words
##       s2_shape   "crystal", "pod", "housing" or "fitting"
##       s2_heat    the spectrum in the heat ramp
##       s2_field   the box filled with the owner's field, faintly, and the
##                  specimen's wire in the accent
##       s2_node    the code seeded from the station, not the owner
##   3   s3_title   the header after the owner's name; s3_full replaces both
##       s3_counter, s3_base   the counter's label and where it starts (-1: by owner)
##       s3_own     the owner's own lines, in its voice
##       s3_src     the owner's rows' source (%d the lab's number, or none)
##       s3_stamp   whether the owner's rows carry a time
##       s3_every   seconds between lines
##       s3_units   a third of the rows from units, not pilots (Cygnet)
##       s3_open    no lab of its own: pilots and the seven makers only
##   4   s4_title (after the name) or s4_full; s4_tag what each part's callout
##       adds: "navy", "heat", "scrap", "heal", "serial", "appt" or ""
##       s4_own     only the owner's own parts take the accent
##   5   s5         the five posters
##   6   s6_route   the route in the accent; s6_disc the arms in it; s6_heat
##                  the disc in the heat ramp; s6_core the core's colour or
##                  null; s6_beat the core's pulse (s); s6_right the words top
##                  right ("" the galaxy's name); s6_mark the sign on the
##                  owner's own stations ("sun", "diamond", "tick", "flag");
##                  s6_claims the foot counts those on your route; s6_arcs
##                  where you are drawn as two signal arcs

const LIGHTENED := ["big", "LIGHTENED PARTS", "TURN FASTER.", "+2 MNV, -1 HUL."]

const BASE := {
	acc = null,
	b_hub = false, b_pulse = false, b_owned = false, b_diamond = false,
	s1_label = "TRACKING", s1_cross = false, s1_style = "", s1_band = false, s1_foot = "LOGGED %d", s1_foot_short = "LOGGED %d",
	s2_label = "SPECIMEN", s2_code = "RELIC R-%03d", s2_done = "NO MATCH ON FILE", s2_shape = "crystal",
	s2_acc = false, s2_heat = false, s2_field = false, s2_node = false,
	s3_title = " RESEARCH NET", s3_full = "", s3_counter = "ROUTINES RESEARCHED, ALL LABS", s3_base = -1,
	s3_own = [], s3_src = "%s LAB %d", s3_stamp = true, s3_every = 2.6, s3_units = false, s3_open = false, s3_acc = false,
	s4_title = " FIT CHECK", s4_full = "", s4_tag = "", s4_acc = false, s4_own = false,
	s5 = [],
	s6_route = false, s6_disc = false, s6_heat = false, s6_core = null, s6_beat = 1.6, s6_right = "",
	s6_mark = "", s6_claims = false, s6_arcs = false,
}

const OWNERS := {
	&"korvan": {
		acc = Color("#d97b2e"),
		b_hub = true, b_pulse = true,
		s1_cross = true, s1_style = "navy", s1_band = true,
		s2_label = "NAVY STORES", s2_code = "REF %04d-B", s2_acc = true, s2_field = true,
		s3_own = ["PLATE BATCH 12 TO SPEC.", "STOCK COUNT AT A STATION FIXED.", "STANDARD ISSUE CHARGE TEST HELD."],
		s4_tag = "navy", s4_acc = true, s4_own = true,
		s5 = [
			["mark", "KORVAN", "IT FIRES. EVERY TIME."],
			["big", "ROUNDS FIRED.", "NO MISFIRES.", "71,204 SO FAR."],
			["big", "STANDARD ISSUE", "CHARGES 1 TURN FASTER.", "THREE KORVAN PARTS FITTED."],
			["big", "THE FRAMES WERE", "DRAWN FOR A WAR.", "THE WAR ENDED. THEY STILL FIT."],
			LIGHTENED,
		],
		s6_route = true, s6_disc = true,
	},
	&"solari": {
		acc = Color("#ef9f27"),
		b_hub = true, b_pulse = true,
		s1_cross = true, s1_style = "heat",
		s2_acc = true, s2_heat = true,
		s3_own = ["LANCE COIL HELD AT 2050 K.", "NEW FIN SHEDS 9% MORE HEAT.", "PLASMA CELL RAN HOT FOR AN HOUR."],
		s3_acc = true,
		s4_tag = "heat", s4_acc = true, s4_own = true,
		s5 = [
			["big", "NOW HIRING", "FURNACE HANDS.", "ASK AT ANY SOLARI LAB."],
			["big", "RUN HOT.", "HIT HARDER.", "MORE DAMAGE FOR EVERY FEW HEAT."],
			["big", "SUNWARD SET", "PLASMA +2.", "THREE SOLARI PARTS FITTED."],
			["big", "IGNITION SET", "OVERHEAT HALVED.", "FIVE SOLARI PARTS FITTED."],
			LIGHTENED,
		],
		s6_route = true, s6_heat = true, s6_mark = "sun",
	},
	&"probate": {
		acc = Color("#b3924e"),
		s1_label = "SURVEYING",
		s2_label = "SALVAGE", s2_code = "S-%03d", s2_done = "WEIGHED, NOT PRICED", s2_shape = "fitting", s2_acc = true,
		s3_own = ["CLAIM FILED ON A LIGHT HULL.", "PLATE FROM THE MERIDIAN WEIGHED. 38 T.", "DRIVE SECTION TOWED IN. PAID ON WEIGHT."],
		s3_counter = "CLAIMS FILED, ALL LABS", s3_acc = true,
		s4_full = "PROBATE VALUATION", s4_tag = "scrap",
		s5 = [
			["mark", "PROBATE", "EVERYTHING IS SALVAGE. EVEN YOU."],
			["big", "WE BUY WRECKS.", "PAID ON WEIGHT.", "ASK AT ANY PROBATE LAB."],
			["big", "WE FILE FIRST.", "FIRST CLAIM HOLDS.", "MOST CLAIMS ARE FILED IN A MINUTE."],
			["big", "ONE AUGMENT", "PER PART.", "DATA IN, BETTER PARTS OUT."],
			LIGHTENED,
		],
		s6_mark = "flag", s6_claims = true,
	},
	&"redline": {
		acc = Color("#e24b4a"),
		b_owned = true,
		s1_cross = true, s1_style = "mask", s1_foot = "LOGGED %d, NOT FILED", s1_foot_short = "UNFILED %d",
		s2_code = "RELIC, NO SERIAL", s2_acc = true,
		s3_own = ["BAFFLES FITTED ON A SLOOP.", "NEW PAINT ON A CUTTER.", "QUIET DRIVE REFIT DONE IN 9 HOURS."],
		s3_src = "REDLINE SHOP", s3_stamp = false, s3_counter = "REFITS DONE, ALL SHOPS",
		s4_full = "REDLINE REFIT CHECK", s4_tag = "serial", s4_acc = true,
		s5 = [
			["mark", "REDLINE", "STILL FLYING? THEN WE DID OUR JOB."],
			["big", "FAST REFITS.", "NO SERIALS.", "NO RECORDS."],
			["big", "PAY IN CASH.", "NO RECEIPT.", "ASK AT ANY REDLINE SHOP."],
			["big", "ONE AUGMENT", "PER PART.", "WE DO NOT ASK WHERE IT CAME FROM."],
			LIGHTENED,
		],
		s6_route = true, s6_right = "POSITION NOT GIVEN",
	},
	&"verity": {
		acc = Color("#ad9d79"),
		b_owned = true, b_hub = true,
		s1_cross = true, s1_style = "rules", s1_foot = "ENTERED %d",
		s2_label = "VERITY PART", s2_code = "NO. %04d", s2_done = "SIGNED. GENUINE.", s2_acc = true,
		s3_own = ["NO. 0102 BACK FOR REFIT.", "NO. 0311 BACK FOR A SEAM CHECK.", "NO. 0398 SIGNED AND ENTERED."],
		s3_every = 5.0, s3_acc = true,
		s4_tag = "appt", s4_acc = true,
		s5 = [
			["mark", "VERITY", "MADE ONCE, MADE PROPERLY."],
			["big", "WE REPAIR", "WHAT WE SOLD YOU.", "FOR AS LONG AS IT FLIES."],
			["big", "FEWER THAN 400", "HULLS IN 200 YEARS.", "EACH ONE SIGNED."],
			["big", "BESPOKE SET", "CARDS COST 1 LESS.", "THREE VERITY PARTS FITTED."],
			LIGHTENED,
		],
		s6_route = true, s6_core = Color("#efe6cf"), s6_mark = "tick",
	},
	&"cygnet": {
		acc = Color("#58c8d8"),
		b_pulse = true, b_diamond = true,
		s1_cross = true, s1_style = "hex",
		s2_code = "HOUSING R-%03d", s2_shape = "housing", s2_acc = true,
		s3_units = true, s3_acc = true,
		s4_acc = true,
		s5 = [
			["mark", "CYGNET", "YOU ARE NEVER ALONE."],
			["big", "A UNIT IS", "ALREADY ON IT.", "ASK AT ANY CYGNET LAB."],
			["big", "ONE AUGMENT", "PER PART.", "FITTED BY UNITS. NO STAFF ON SITE."],
			["big", "DATA IN.", "UNITS OUT.", "RESULTS ARE LOGGED."],
			LIGHTENED,
		],
		s6_route = true, s6_mark = "diamond", s6_arcs = true,
	},
	&"calyx": {
		acc = Color("#5fb08a"),
		b_owned = true,
		s1_style = "bio", s1_foot = "SAMPLES %d",
		s2_code = "C-%03d", s2_shape = "pod", s2_acc = true,
		s3_own = ["CULTURE 14 REACHED SPEC. TRIMMED.", "TANK 4 STAYS CAPPED. NOT RATED.", "PLATE CULTURE GREW 9% PAST SPEC."],
		s3_acc = true,
		s4_tag = "heal", s4_acc = true, s4_own = true,
		s5 = [
			["mark", "CALYX", "GROWN, NOT BUILT."],
			["big", "YOUR HULL HEALS", "AFTER A FIGHT.", "THREE CALYX PARTS FITTED."],
			["big", "ONE AUGMENT", "PER PART.", "THE PART GROWS AROUND IT."],
			["big", "GROWN IN A TANK.", "TRIMMED TO FIT.", "EVERY PART IS CHECKED."],
			LIGHTENED,
		],
		s6_route = true, s6_beat = 4.0,
	},
	&"": {
		s2_node = true,
		s3_full = "OPEN RESEARCH NET", s3_open = true,
		s5 = [
			["mark", "INDEPENDENT", "NO OWNER. OPEN TO ALL."],
			["big", "THIS LAB IS OPEN", "TO ANY PILOT.", "PUT THE TOOLS BACK."],
			["big", "ONE AUGMENT", "PER PART.", "SAME RULE AS EVERY LAB."],
			["big", "DATA IN.", "BETTER PARTS OUT.", "RESULTS VARY."],
			LIGHTENED,
		],
	},
}


## The owner's dress, every key filled. Anyone not in the table dresses as an
## independent lab.
static func of(owner: StringName) -> Dictionary:
	var d := BASE.duplicate()
	var o: Dictionary = OWNERS.get(owner, OWNERS[&""])
	for k in o:
		d[k] = o[k]
	return d
