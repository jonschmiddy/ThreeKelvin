# -*- coding: utf-8 -*-
"""Every encounter fault that a machine can find, so a human never has to.

Written after four encounters were reviewed by hand and five of the six problems
found turned out to be patterns rather than judgement calls:

    a dominated choice          -- pattern
    credits with nobody to pay  -- pattern
    an untagged walk-away       -- pattern
    an encounter taking from the hold -- pattern
    a ship and a person sharing one pronoun -- pattern
    a clause that needs a second read -- NOT a pattern, and the only one worth
                                         a person's time

Run:  python tools/encounter_lint.py [--strict]

`--strict` exits non-zero on ERRORs, for the gate. Without it, everything is a
report.
"""
import io
import os
import re
import sys
import collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# The encounters are authored in OptionsPart01..NN.gd, joined in number order by
# OptionTable._authored, so sorted names are the table's order.
SRC = os.path.join(ROOT, "tkg", "scripts", "systems", "options")

# The steep ladder, from the ruling. Index by tier 1..5.
CHECK_BAND = {1: (3, 4), 2: (4, 5), 3: (5, 6), 4: (6, 7), 5: (7, 8)}
PAY = [0, 1.0, 1.8, 3.0, 4.7, 7.2]
TOLL = [0, 1.0, 1.9, 3.0, 4.3, 5.8]
CRD_MAX = [0, 40, 70, 110, 170, 260]
HULL_MAX = [0, 6, 10, 15, 20, 28]
BODY_MIN = 300          # measured: the four reviewed bodies run 402-573
TIER_NAME = ["", "EASY", "ROUGH", "HARD", "BRUTAL", "LETHAL"]

# What every named material is worth, read off the table rather than guessed.
VALUE = {}
_mt = os.path.join(ROOT, "tkg", "scripts", "systems", "MaterialTable.gd")
if os.path.exists(_mt):
	for _m in re.finditer(
			r'\{id = &"([a-z_]+)".*?value = (\d+)',
			io.open(_mt, encoding="utf-8").read(), re.S):
		VALUE[_m.group(1)] = int(_m.group(2))

# A walk-away by its label. Declining a thing must not spend the encounter.
WALK = re.compile(
	r"^(leave|let|decline|pass|wave|ignore|refuse|walk|hold off|say no|"
	r"keep (going|clear)|do not|don't|stay out|give it a miss|move on)\b", re.I)

# Somebody is present to hand over money.
PERSON = re.compile(
	r"\b(she|he|her|his|they|them|their|crew|master|clerk|pilot|somebody|"
	r"someone|courier|buyer|dockmaster|hail|hails|hailing|voice|asks|offers|"
	r"wants|says|tells|woman|man|captain|owner|foreman|broker|agent|"
	r"quartermaster|trader|smuggler|patrol|inspector)\b", re.I)

# A vessel, for the pronoun-slide check.
VESSEL = re.compile(r"\b(barge|hauler|cutter|freighter|hull|ship|tug|skiff|"
	r"lighter|tender|relay|station|dock|rig|yard)\b", re.I)


def _key(entry):
	"""id + message. Deliberately NOT the line number: everything shifts when an
	encounter above it is edited, and a baseline that decays on every edit is a
	baseline nobody trusts."""
	parts = entry.split(None, 2)
	return "%s %s" % (parts[1], parts[2]) if len(parts) > 2 else entry


def tier(d):
	return max(1, min(5, (d + 1) // 2))


def sources():
	"""(file name, text) for each authored file, in table order."""
	return [(n, io.open(os.path.join(SRC, n), encoding="utf-8").read())
		for n in sorted(os.listdir(SRC)) if n.endswith(".gd")]


def encounters():
	"""(id, block, line, file name) for each encounter, in table order."""
	for fname, src in sources():
		lines = src.split("\n")
		st = [(m.group(1), n) for n, l in enumerate(lines)
			for m in [re.match(r'\t*id = &"([a-z_]+)",\s*$', l)] if m]
		for k, (eid, n) in enumerate(st):
			end = st[k + 1][1] if k + 1 < len(st) else len(lines)
			yield eid, "\n".join(lines[n:end]), n + 1, fname


def choices_of(blk):
	"""Each choice as (label, chunk)."""
	out = []
	for m in re.finditer(r"\n\t{4}\{label = \"(.*?)\"", blk):
		start = m.start()
		nxt = blk.find('\n\t\t\t\t{label = ', m.end())
		out.append((m.group(1), blk[start:nxt if nxt > 0 else len(blk)]))
	return out


# An outcome callable, by the key it sits under.
OUTCOME = re.compile(r"\b(effect|met|clean|partial|botched) = func\(")
DRAIN = "Run.drain_fuel(OptionTable.science_fuel())"
READ = "Run.add_data(OptionTable.reading("


def science_faults(blk, tags, chs):
	"""Check 10 (science, Phase 12): the shape BUILD_PLAN.md section 1 gives a
	science event, which the screen, the fuel gate and the sim pilot read off
	its plain keys without running it. DATA comes from science events only."""
	out = []
	if "science" not in tags:
		if re.search(r"add_data|reading\(|burns = true", blk):
			out.append("pays DATA or burns fuel for a reading, and is not tagged science")
		return out
	site = re.search(r'\n\t+site = &"([a-z_]+)"', blk)
	if not site or site.group(1) not in ("barren", "belt"):
		out.append("a science event sits on site barren or belt (%s)"
			% (site.group(1) if site else "no site"))
	for k in ("min_danger", "max_danger"):
		if not re.search(r"\n\t+%s = \d+" % k, blk):
			out.append("a science event names its %s" % k)
	if re.search(r"add_data\(\s*-?\d", blk):
		out.append("DATA paid as a literal number; pay OptionTable.reading(k)")
	credits = 0
	for label, chunk in chs:
		mults = [int(x) for x in re.findall(r"OptionTable\.reading\((\d+)\)", chunk)]
		if "burns = true" in chunk:
			calls = len(OUTCOME.findall(chunk))
			if chunk.count(DRAIN) != calls:
				out.append('"%s" burns fuel, and %d of its %d outcomes call %s'
					% (label, chunk.count(DRAIN), calls, DRAIN))
			if READ not in chunk:
				out.append('"%s" burns fuel and never calls %s...)' % (label, READ))
			if 2 in mults and "check = {" not in chunk:
				out.append('"%s" pays reading(2) with no check in front of it' % label)
			reads = re.search(r"reads = (\d+)", chunk)
			if not reads:
				out.append('"%s" burns fuel and does not say how many readings (reads)' % label)
			elif mults and int(reads.group(1)) != max(mults):
				out.append('"%s" says reads = %s and pays reading(%d)'
					% (label, reads.group(1), max(mults)))
		elif DRAIN in chunk or "add_data" in chunk or mults:
			out.append('"%s" pays DATA or burns fuel without burns = true' % label)
		elif "add_credits" in chunk:
			credits += 1
	if credits != 1:
		out.append("a science event has exactly one credits line (it has %d)" % credits)
	return out


TAGS = re.compile(r'&"(quest|fight|hazard|salvage|signal|contract|science)"')


def _sub1(s, old, new, start=0):
	"""s with the first `old` at or after `start` made `new`, or None."""
	i = s.find(old, start)
	return None if i < 0 else s[:i] + new + s[i + len(old):]


def science_selfcheck():
	"""Check 10 run on broken copies of the table's first science event, every
	run: each break must raise a fault the event does not have, so a check that
	stops seeing one fails `--strict` here and not after a bad event lands.
	Returns the breaks it missed."""
	blk = next((b for _e, b, _l, _f in encounters()
		if "science" in set(TAGS.findall(b))), None)
	if blk is None:
		return ["no science event in the table to break"]

	def faults(b):
		return science_faults(b, set(TAGS.findall(b)), choices_of(b))

	base = len(faults(blk))
	nocheck = None
	for label, chunk in choices_of(blk):
		if "burns = true" in chunk and "check = {" not in chunk:
			fixed = _sub1(_sub1(chunk, "reads = 1", "reads = 2") or "",
				"OptionTable.reading(1)", "OptionTable.reading(2)")
			nocheck = blk.replace(chunk, fixed, 1) if fixed else None
			break
	site = re.search(r'site = &"[a-z_]+"', blk)
	breaks = {
		"a burns line's drain taken out": _sub1(blk, DRAIN, ""),
		"reading(2) on a line with no check": nocheck,
		"the site moved off barren and belt":
			blk.replace(site.group(0), 'site = &"planet"', 1) if site else None,
		"the credits line paying nothing": _sub1(blk, "Run.add_credits(", "Run.add_nothing("),
		"DATA paid as a literal": _sub1(blk, DRAIN, DRAIN + "\n\t\t\t\t\tRun.add_data(3)"),
		"the science tag taken off": _sub1(blk, '&"science"', '&"signal"'),
	}
	return [name for name, b in breaks.items() if b is None or len(faults(b)) <= base]


def main():
	errors, warns = [], []
	seen = 0

	for eid, blk, ln, fname in encounters():
		seen += 1
		lo = re.search(r"min_danger = (\d+)", blk)
		hi = re.search(r"max_danger = (\d+)", blk)
		lo = int(lo.group(1)) if lo else 1
		hi = int(hi.group(1)) if hi else 10
		tlo, thi = tier(lo), tier(hi)
		tags = set(TAGS.findall(blk))
		bm = re.search(r'body = "(.*?)",\n', blk, re.S)
		body = bm.group(1) if bm else ""
		chs = choices_of(blk)

		def err(msg):
			errors.append("%s:%d  %-22s %s" % (fname, ln, eid, msg))

		def warn(msg):
			warns.append("%s:%d  %-22s %s" % (fname, ln, eid, msg))

		# --- 1. nothing reaches into the hold ---------------------------
		if "consume_material_tier" in blk:
			err("takes from the hold by TIER -- the player never picks which item")

		# --- 2. a decline must not spend the encounter ------------------
		for label, chunk in chs:
			if WALK.match(label.strip()) and "stay = true" not in chunk:
				err('walk-away "%s" is not tagged `stay = true`' % label)

		# --- 3. credits need somebody to hand them over -----------------
		pays = re.findall(r"Run\.add_credits\(OptionTable\.purse\((\d+)\)", blk)
		if pays and not PERSON.search(body) and not (tags & {"contract"}):
			err("pays credits with nobody in the body to pay them (%s)"
				% ",".join(sorted(tags) or ["untagged"]))

		# --- 4. checks sit in their tier's band -------------------------
		for a, v in re.findall(r'attr = &"([a-z_]+)", need = (\d+)', blk):
			v = int(v)
			band = CHECK_BAND[thi]
			if v < CHECK_BAND[tlo][0] or v > band[1]:
				warn("check %s %d outside the band for its tiers (%d..%d)"
					% (a, v, CHECK_BAND[tlo][0], band[1]))

		# --- 5. payouts and tolls stay under their ceiling --------------
		for p in pays:
			if round(int(p) * PAY[thi]) > CRD_MAX[thi]:
				warn("pays %d at its deepest tier, ceiling is %d"
					% (round(int(p) * PAY[thi]), CRD_MAX[thi]))
		for t in re.findall(r"OptionTable\.toll\((\d+)\)", blk):
			if round(int(t) * TOLL[thi]) > HULL_MAX[thi]:
				warn("hits for %d at its deepest tier, ceiling is %d"
					% (round(int(t) * TOLL[thi]), HULL_MAX[thi]))

		# --- 6. no choice that costs nothing and gives nothing ----------
		# unless it is a tagged walk-away, which is never dominated: it keeps
		# the encounter open, and that is a reason to pick it.
		for label, chunk in chs:
			if "stay = true" in chunk:
				continue
			moves = re.search(
				r"add_credits|take_hull_damage|heat \+=|Run\.fuel|Run\.drain_fuel|material|"
				r"module = true|fight = true|place =|find_hull|add_data|reading\(|"
				# readying a signed contract is the gain a job's pickup exists for
				r"reach_contract_target", chunk)
			if not moves and "check" not in chunk:
				err('choice "%s" costs nothing and gives nothing, and is not a '
					"tagged walk-away" % label)

		# --- 7. a deep branch paying only a CHEAP named material --------
		#
		# Value-aware, and it has to be. The first version fired on any
		# named-only branch and flagged `LAST BROADCAST` -- artifact tier, 150,
		# a perfectly good LETHAL payout. The fault is not "named", it is
		# "named and worth less than the tier pays", which is what happened to
		# `survey_film` at 35 in a band that pays 170-260.
		if thi >= 4:
			for label, chunk in chs:
				named = re.findall(r'material_id = &"([a-z_]+)"', chunk)
				if not named or re.search(
						r'material = &"|add_credits|module = true', chunk):
					continue
				worth = sum(VALUE.get(x, 0) for x in named)
				floor = CRD_MAX[thi] // 3
				if worth < floor:
					warn('"%s" pays only %d in named materials; %s pays %d-%d, '
						"and a named value never grades with depth"
						% (label, worth, TIER_NAME[thi],
							CRD_MAX[thi] // 3, CRD_MAX[thi]))

		# --- 8. one pronoun, two referents ------------------------------
		if VESSEL.search(body) and re.search(r"\b(her|she)\b", body, re.I):
			# a vessel called `her` AND a person called `she` in one paragraph
			if re.search(r"\b(her|its)\s+(master|pilot|crew|owner)\b", body, re.I):
				warn("a vessel and a person may be sharing a pronoun -- read it")

		# --- 9. bodies carry their weight -------------------------------
		if len(body) < BODY_MIN:
			warn("body is %d chars; the reviewed four run 402-573" % len(body))

		# --- 10. a science event pays DATA the one way ------------------
		for e in science_faults(blk, tags, chs):
			err(e)

	# --- the baseline -----------------------------------------------------
	#
	# `--strict` has to be usable on the day it is written or nobody adopts it.
	# The table had 35 findings the moment the linter existed, so a gate that
	# failed on all of them was a gate that could only ever be switched on after
	# a cleanup nobody had time for -- and meanwhile eighty new encounters would
	# arrive ungated.
	#
	# So: known findings are recorded once, and `--strict` fails only on ones
	# that are NOT in that record. Old debt stays visible in the plain report and
	# stops blocking new work. `--baseline` re-records after a genuine fix.
	base = set()
	bp = os.path.join(ROOT, "tools", "encounter_lint_baseline.txt")
	if os.path.exists(bp):
		base = set(l.strip() for l in io.open(bp, encoding="utf-8")
			if l.strip() and not l.startswith("#"))
	if "--baseline" in sys.argv:
		io.open(bp, "w", encoding="utf-8", newline="\n").write(
			"# Findings that predate the linter. `--strict` ignores these\n"
			"# and fails on anything new. Re-record with --baseline after a\n"
			"# real fix.\n"
			+ "\n".join(sorted(_key(e) for e in errors)) + "\n")
		print("baselined %d findings" % len(errors))
		return 0
	fresh = [e for e in errors if _key(e) not in base]

	print("%d encounters checked" % seen)
	print()
	if errors:
		print("ERRORS  (%d, of which %d are new since the baseline)"
			% (len(errors), len(fresh)))
		for e in errors:
			print("  %s%s" % ("NEW  " if _key(e) not in base else "     ", e))
		print()
	if warns:
		print("REVIEW  (%d) -- worth a look, not automatically wrong" % len(warns))
		for w in warns:
			print("  " + w)
		print()
	# --- check 10 on itself: each break of a science event must be seen --
	missed = science_selfcheck()
	if missed:
		print("SELF-CHECK  check 10 missed %d break(s) of a science event:" % len(missed))
		for m in missed:
			print("  " + m)
		print()
	if not errors and not warns and not missed:
		print("clean")
	return 1 if ((fresh or missed) and "--strict" in sys.argv) else 0


if __name__ == "__main__":
	sys.exit(main())
