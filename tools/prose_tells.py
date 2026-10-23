# -*- coding: utf-8 -*-
"""The prose tells a machine can find, in every string a player reads.

    python tools/prose_tells.py               report: errors, then the review list
    python tools/prose_tells.py --strict      exit non-zero on errors not in the baseline
    python tools/prose_tells.py --baseline    re-record the baseline after a real fix
    python tools/prose_tells.py --rank        the densest files and strings, worst first

`encounter_lint.py` checks what an encounter DOES and `prose_grade.py` how hard it
is to READ. Neither looks at how it is WRITTEN, and both stop at OptionTable.gd.
The tells themselves were already written down -- `.claude/skills/encounter-prose`
SKILL.md §3 to §3c lists them, with counts -- but only for a person to catch by
eye. A list a person has to remember is a list that stops being applied around
the third batch.

The method is borrowed from the Meridian manuscript's voice-and-mannerism pass
(`drafts/revision-pass/voice-and-mannerism-pass.md` there): one regex per tic, a
count, and a CEILING rather than a ban. "X was not Y. X was Z." lands once; it
stops landing past that. So a reframe is allowed once per encounter, and the
second one is the finding.

Two levels, as in encounter_lint:

  ERRORS   precise enough to gate. BASELINED: what was already in the game when
           this was written is recorded in prose_tells_baseline.txt, stays
           visible in the report, and does not block. Whether to fix it is a
           ruling, not a lint.
  REVIEW   too noisy to gate: a general truth used as a capper, a run of
           verbless fragments, the soft words. Read them; most are fine.

Debug output (print, push_error, asserts) and comments are not player text and
are skipped; so is scripts/sim/, which only the harness reads.

The second set of rules (2026-10-23) is a port of the Meridian manuscript's
mannered-prose pass (its style sheet §9.13 and §9.18, `tools/audit.py` there):
figure standing in for a statement. The plain-voice overhaul of 2026-10-13 had
already taken the slang and the epigrams out; what it left was the same moves
in plain words. Measured before this pass, over the encounters: "still" ran 49
per 10k words against 10 in a shelf of novels, and 49 strings ended on "X is
still Y when you leave", the quiet closing image in a plainer coat. The rules:

  still-closer   the lingering camera: a last sentence on "still ... when you
                 leave / when the dish loses it / out of range"
  personified    a clamp, a meter, an arm or a herd that does not care, does
                 not notice, complains, decides or expects
  wink           the pair that winks: "They say X, and they are not.", "It is
                 uncomfortable and it is free."
  vague-thing    "the best thing", "the one thing it could reach": name the
                 piece, the crate, the part
  idiom          "worth having", "costs you nothing", "the whole of it"
  tautology      "the digit is the digit", "the order is the order"
  pronouncement  (REVIEW) a short abstract last sentence: "It is slow and safe."
  flourish-verb  (REVIEW) the one-word verb as a whole sentence: "It holds."
  span           (REVIEW) "a long time", "long ago": name the span if the body has it
  tricolon       (REVIEW) three sentences in a row opening on the same word

A string that carries one of Jon's approved lines (SKILL.md §0, the KEEP list
below) is skipped by every rule, so a rule can fire hard without re-litigating
a decided line; that is Meridian's keep-list, in one tuple.
"""
from __future__ import annotations

import collections
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "tkg", "scripts")
BASELINE = os.path.join(ROOT, "tools", "prose_tells_baseline.txt")
ENCOUNTERS = "systems/OptionTable.gd"
SKIP_DIRS = ("sim",)

# Every string on the line, each one whole, and only then the long ones. The
# first version asked the regex for 20 characters or more directly, so after a
# short string it could start at that string's CLOSING quote and read the code
# up to the next opening one: about 205 of the 2,018 "strings" it counted were
# `]) >= 0.0 and t >= float(d[` and the like.
STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
MIN_CHARS = 20
NOT_PLAYER_TEXT = re.compile(
	r"\b(push_error|push_warning|print|printerr|prints|print_rich|assert|_fail|fail)\s*\(")

# --- ERRORS -----------------------------------------------------------------
#
# id, how many a unit may carry before it is a finding, pattern, what it is.
# A unit is one encounter in OptionTable.gd and one string everywhere else.
ERRORS = [
	("reframe", 1,
		r"\b(?:is|was|are|were) not\b[^.!?]{1,60}[.!?]\s+"
		r"(?:It|That|This|They|He|She|You)\s+(?:is|was|are|were)\b",
		'"It is not X. It is Y." -- the sentence restating itself (SKILL §3)'),
	("reversal", 1,
		r"\b(?:did|had|does|do) not\s+[a-z]+\.\s+(?:You|It|They|He|She)\s+(?:did|had|does|do)\b",
		'"You did not X. You did." -- interiority by inverting itself (Meridian V7)'),
	("states-the-point", 0,
		r"\bwhich (?:is|was) (?:how|why|the point|what)\b|\b(?:That|This) (?:is|was) the point\b",
		"the narrator explains what it meant (SKILL §2, §3)"),
	("summing-closer", 0,
		r"\b(?:That|This) (?:is|was) the (?:part|thing|whole|only)\b",
		'a summing-up closer, "That is the part worth knowing" (SKILL §3)'),
	("dash", 0,
		r"[a-z,] (?:—|–|--) [a-z]",
		"a dash inside a sentence (RULED 2026-09-10, SKILL §3)"),
	("round", 0,
		r"\b(?:goes|go|went|come|came|turn|turned|turns|all) round\b",
		'"round" for "around" (SKILL §3b)'),
	# --- ported from Meridian's mannered-prose pass (2026-10-23), see the docstring ---
	("personified", 0,
		r"(?<!\bshe )(?<!\bhe )(?<!\bthey )(?<!\byou )(?<!\bwe )(?<!\bcrew )(?<!\bnobody )(?<!\bno one )"
		r"(?<!\bpilot )(?<!\bwoman )(?<!\bman )(?<!\bforeman )(?<!\bclerk )(?<!\bpeople )(?<!\bthem )"
		r"(?<!\bdockmaster )(?<!\bone )(?<!\banyone )(?<!\bsomeone )"
		r"\b(?:does|do|did) not (?:care|mind|notice|complain)\b(?! to\b)"
		r"|\bcomplains?\b(?! to\b)|\b(?:does|do) not ask who\b|\blike it was expecting\b|\bdecided (?:that )?you\b|\bkeeps its (?:fittings|secrets)\b",
		"a machine or a herd doing a person's verb: say what it did (Meridian §9.18)"),
	("wink", 0,
		r", and (?:it|they|she|he) (?:is|are|was|were) not\.|(?:^|[.!?] )It is not\. |\band it is free\b",
		'the pair that winks, "They say X, and they are not." (SKILL §0, no winking)'),
	("vague-thing", 0,
		r"\bthe (?:one|best|first|last|only|nearest|heaviest|warmest|hottest|coldest|biggest|smallest|worst) thing\b"
		r"|\bthe thing (?:at|in|about|on)\b",
		'"the best thing": name the piece, the crate, the part (Meridian §9.13)'),
	("idiom", 0,
		r"\bworth (?:having|knowing)\b|\bcosts? (?:you|them|him|her) nothing\b|\bthe whole of (?:it|what)\b"
		r"|\bdid the work\b|\bearn(?:ed|s)? (?:its|their) keep\b|\bcarr(?:y|ies|ied) weight\b|\bat leisure\b",
		"an idiom standing in for the plain phrase (Meridian §9.18)"),
	("tautology", 0,
		r"\b[Tt]he ([a-z]+) (?:is|was|are|were) the \1\b(?!\s+(?:of|the|that|which|who|whose|I|he|she|they|we|you)\b)",
		'"the X is the X" (Meridian §9.13)'),
]

# The lingering camera: a walk-away or an outcome that ends on the thing
# still doing what it was doing as you go. One is a fact; forty-nine were the
# house closer. Tested on the LAST sentence only.
STILL_CLOSER = re.compile(
	r"\bstill\b.*\b(?:when|as|while|until) (?:you|your dish|the dish)\b"
	r"|\b(?:when|until) (?:you|your dish|the dish) (?:leave|lose|loses|pass|go)\b.*\bstill\b"
	r"|\b(?:out of|past|leaves) (?:sensor )?range\b")

# Jon's approved lines (SKILL.md §0, 2026-10-13). A string carrying one is
# skipped by every rule: the keep-list, so rules can fire hard.
KEEP = (
	"A neutron star's beam killed the crew. The hull held.",
	"Four million suns in one point. Ruins from whoever came first still orbit it.",
	"Its density waves never settled into one pattern.",
	"Their argument is still on the open channel",
	"Korvan stamps parts to an old navy specification.",
	"Charges for a turn, then hits hard.",
	"Power cells with the serials ground off.",
	"Removed for the rest of this fight. It does not return when the deck reshuffles.",
	"Puts it in your hold. The first pilot to take it keeps it.",
	"This system's star, what orbits it, and any threats nearby.",
)

# Hands are ruled out of ENCOUNTER prose (SKILL §3b, §3c). Elsewhere "hand" is
# the card hand, which is a mechanic and not a body part.
HANDS = re.compile(r"\bhands?\b", re.I)

# --- REVIEW -------------------------------------------------------------------
REVIEW = [
	("capper",
		r"(?:^|[.!?]\s+)(?:Nobody|Nothing|No one|Everyone|Everything|Some things)\b[^.!?]{3,70}\.\s*$",
		"a general truth as the last word (SKILL §3c). Fine when it is a fact about THIS place"),
	("staged-reaction",
		r"\bof (?:a|an|someone|somebody) (?:person |man |woman )?(?:who|that) (?:has|had|is|was|knows|knew)\b",
		'"the exact gratitude of a person who..." (SKILL §2)'),
	("the-way",
		r"\bthe way (?:a|an|someone|somebody|people|you would)\b",
		'"did Y the way someone does Y when Z" (Meridian V1)'),
	("soft-word",
		r"\b(?:quietly|softly|somehow|gently)\b",
		"humanizer's soft words; weak alone, flag with company (SKILL §3)"),
	# The narrator explaining the line before: "Heat is what they leave
	# behind.", "The ore is what they are paying with.", "That is why." The
	# ERROR above catches only "which is how / why / the point".
	("explains",
		r"(?:^|[.!?]\s+)(?:That|This|It|Which)\s+(?:is|was)\s+(?:how|why|what|the reason|all)\b"
		r"|\b(?:is|are|was|were)\s+what\s+(?:they|it|you|we|he|she|people|ships?|crews?)\s+"
		r"(?:leave|leaves|left|do|does|did|want|wants|are|is|were|was|get|gets|have|has|had"
		r"|need|needs|pay|pays)\b"
		r"|\bwhich\s+(?:is|was)\s+(?:all|the whole|exactly)\b",
		"the narrator explaining what the line meant, \"X is what they leave behind\" (SKILL §0)"),
	# --- ported from Meridian's mannered-prose pass (2026-10-23) ---
	("flourish-verb",
		r"(?:^|[.!?] )(?:It|That|This|They|The [a-z]+) (?:holds|held|lands|landed|settles|settled|stays|stayed)\.",
		'the one-word verb as a whole sentence, "It holds." (Meridian §9.18)'),
	("span",
		r"\ba long (?:time|while)\b|\blong ago\b|\bfor some time\b",
		"a vague span; name it if the body has the number (SKILL §2, name things)"),
	("which-is",
		r", which is (?:more|less|all|why|how|what|where|not)\b",
		'", which is more than you expected": the narrator\'s aside (Meridian §9.18)'),
]

# The pronouncement closer: a short abstract last sentence, "It is slow and
# safe.", "It is not the good one." Meridian's aphorism-closer; REVIEW, because
# "It is in the hold." is a status line and right.
PRONOUNCEMENT = re.compile(r"^(?:It|That|This|There) (?:is|was|were|are|came|did)\b")
TRICOLON_OK = set("the you it they a he she an your this that there then".split())

# An epigram: two short sentences on one frame, the second answering the first.
# "Nothing they build is clever. Everything they build still works." The capper
# test sees only a last line that opens on Nobody or Nothing; this sees the pair.
EPIGRAM_PAIRS = [("nothing", "everything"), ("nobody", "everybody"), ("no one", "everyone"),
	("nobody", "everyone"), ("never", "always"), ("none", "all")]


def epigram(text: str):
	"""The two sentences that make an epigram, or None."""
	ss = sentences(text)
	for a, b in zip(ss, ss[1:]):
		wa, wb = re.findall(r"[a-z']+", a.lower()), re.findall(r"[a-z']+", b.lower())
		if not wa or not wb or len(wa) > 9 or len(wb) > 9:
			continue
		la, lb = " ".join(wa) + " ", " ".join(wb) + " "
		for x, y in EPIGRAM_PAIRS:
			if ((la.startswith(x + " ") and lb.startswith(y + " "))
					or (la.startswith(y + " ") and lb.startswith(x + " "))):
				return a + " " + b
		# one frame, a new first word: "Nothing THEY BUILD ... Everything THEY BUILD"
		if len(wa) >= 3 and len(wb) >= 3 and wa[1:3] == wb[1:3] and wa[0] != wb[0]:
			return a + " " + b
	return None

# A fragment: a sentence with no finite verb a cheap test can see. Two or more
# in a string, making up most of it, is the clipped catalogue cadence -- "Sparse,
# exact, and priced accordingly." "One bag, first hand in." -- which is most of
# the mannered text OUTSIDE the encounters and which no phrase regex catches.
AUX = set("""is are was were be been am isn't aren't wasn't weren't has have had
	hasn't haven't hadn't do does did don't doesn't didn't can can't could will
	won't would should shall may might must""".split())
IRREGULAR = set("""took came went gave got made ran kept held left found felt
	saw put cut let told said brought caught sat stood lost won paid sold bought
	broke spoke drove flew threw grew knew drew fell began""".split())
DETERMINERS = set("the a an this that these those its your their our his her one "
	"two three four five every each no some any".split())
SUBJECT = set("i you he she it we they nobody nothing someone something this that "
	"there everyone everything".split())


def is_fragment(sentence: str) -> bool:
	words = re.findall(r"[A-Za-z']+[,;:]?", sentence)
	if not words or len(words) > 9:
		return False
	bare = [w.rstrip(",;:").lower() for w in words]
	if any(w in AUX for w in bare):
		return False
	if any(w.endswith("ed") and len(w) > 4 for w in bare):
		return False
	if any(w in IRREGULAR for w in bare):
		return False
	# "the cold gets", "the grapple takes": a word ending in s after another
	# word is usually a present-tense verb. It also lets "cheap rounds" through,
	# which costs a finding rather than inventing one.
	if any(w.endswith("s") and not w.endswith("ss") and len(w) > 3
			and a not in DETERMINERS for a, w in zip(bare, bare[1:])):
		return False
	# a subject followed directly by a word is almost always subject + verb
	for a, b in zip(words, words[1:]):
		if a.lower() in SUBJECT and not a[-1] in ",;:":
			return False
	return True


def sentences(text: str) -> list:
	return [s.strip() for s in re.split(r"(?<=[.!?])\s+", text) if s.strip()]


def player_strings():
	"""(file, line, unit, text) for every string a player could read."""
	for dirpath, dirs, files in os.walk(SCRIPTS):
		rel_dir = os.path.relpath(dirpath, SCRIPTS)
		if rel_dir.split(os.sep)[0] in SKIP_DIRS:
			dirs[:] = []
			continue
		for name in sorted(files):
			if not name.endswith(".gd"):
				continue
			rel = os.path.normpath(os.path.join(rel_dir, name)).replace(os.sep, "/")
			unit = None
			for n, line in enumerate(io.open(os.path.join(dirpath, name), encoding="utf-8"), 1):
				if rel == ENCOUNTERS:
					m = re.match(r'\t*id = &"([a-z_0-9]+)",\s*$', line)
					if m:
						unit = m.group(1)
				stripped = line.lstrip()
				if stripped.startswith("#") or NOT_PLAYER_TEXT.search(line):
					continue
				for m in STRING.finditer(line):
					if len(m.group(1)) < MIN_CHARS:
						continue
					text = m.group(1).replace("\\n", " ").replace('\\"', '"')
					# prose has spaces between lowercase words; keys and paths do not
					if len(text.split()) < 5 or not re.search(r"[a-z] [a-z]", text):
						continue
					yield rel, n, (unit if rel == ENCOUNTERS and unit else None), text


def _key(rel, tid, text, sentence):
	"""File, tell and the offending sentence. NOT the line number: every edit
	above a string would shift it, and a baseline that decays on every edit is
	a baseline nobody trusts (encounter_lint learned this first)."""
	return "%s %s %s" % (rel, tid, " ".join(sentence.split())[:80])


def sentence_at(text, pos):
	start = max(text.rfind(". ", 0, pos), text.rfind("? ", 0, pos), text.rfind("! ", 0, pos))
	end = re.search(r"[.!?](\s|$)", text[pos:])
	return text[start + 2 if start >= 0 else 0: pos + (end.end() if end else len(text) - pos)].strip()


def main() -> int:
	errors = []          # (key, rel, line, tid, why, sentence)
	review = []          # (rel, line, tid, why, text)
	per_unit = collections.Counter()
	density = collections.Counter()
	words = collections.Counter()
	scanned = 0
	compiled = [(t, cap, re.compile(rx), why) for t, cap, rx, why in ERRORS]
	compiled_review = [(t, re.compile(rx), why) for t, rx, why in REVIEW]

	still_words = collections.Counter()
	for rel, n, unit, text in player_strings():
		scanned += 1
		words[rel] += len(text.split())
		still_words[rel] += len(re.findall(r"\bstill\b", text.lower()))
		if any(k in text for k in KEEP):
			continue
		ukey = unit or (rel, n, text)
		ss_all = sentences(text)
		if len(ss_all) >= 2 and STILL_CLOSER.search(ss_all[-1]):
			s = ss_all[-1]
			density[rel] += 1
			errors.append((_key(rel, "still-closer", text, s), rel, n, "still-closer",
				"the lingering camera: ends on what is still happening as you leave (SKILL §0, Meridian §9.18)", s))
		for tid, cap, rx, why in compiled:
			for m in rx.finditer(text):
				per_unit[(ukey, tid)] += 1
				density[rel] += 1
				if 0 < per_unit[(ukey, tid)] <= cap:
					review.append((rel, n, tid, "under its ceiling of %d a unit; " % cap + why, text))
				if per_unit[(ukey, tid)] > cap:
					s = sentence_at(text, m.start())
					errors.append((_key(rel, tid, text, s), rel, n, tid, why, s))
		if rel == ENCOUNTERS:
			for m in HANDS.finditer(text):
				s = sentence_at(text, m.start())
				density[rel] += 1
				errors.append((_key(rel, "hands", text, s), rel, n, "hands",
					"hands in encounter prose (RULED, SKILL §3b, §3c)", s))
		for tid, rx, why in compiled_review:
			# a capper caps something: a one-sentence label has nothing under it
			if tid == "capper" and len(sentences(text)) < 2:
				continue
			if rx.search(text):
				review.append((rel, n, tid, why, text))
		if len(ss_all) >= 3:
			last = ss_all[-1]
			if 2 <= len(last.split()) <= 7 and PRONOUNCEMENT.match(last):
				review.append((rel, n, "pronouncement",
					"a short abstract last sentence; end on the concrete fact (Meridian §9.18)", text))
			opens = [s.split(" ")[0].lower().rstrip(".,;:") for s in ss_all]
			for i in range(len(opens) - 2):
				if opens[i] and opens[i] == opens[i + 1] == opens[i + 2] and opens[i] not in TRICOLON_OK:
					review.append((rel, n, "tricolon",
						"three sentences in a row open on '%s'; keep two (Meridian)" % opens[i], text))
					break
			if len(re.findall(r"\bstill\b", text.lower())) >= 3:
				review.append((rel, n, "stacked-still", "'still' three times in one string", text))
		pair = epigram(text)
		if pair:
			review.append((rel, n, "epigram",
				"two short sentences on one frame, the second answering the first (SKILL §0)",
				pair))
		# A string with a slot in it (%s, {PLACE}) is a status line or a
		# tooltip, and terse is right for those.
		ss = [] if re.search(r"%[sd0-9.]|\{[A-Z_]+\}", text) else sentences(text)
		frags = [s for s in ss if is_fragment(s)]
		if len(frags) >= 2 and len(frags) * 3 >= len(ss) * 2:
			review.append((rel, n, "fragments",
				"%d of %d sentences have no verb a cheap test can see" % (len(frags), len(ss)),
				text))

	base = set()
	if os.path.exists(BASELINE):
		base = set(l.rstrip("\n") for l in io.open(BASELINE, encoding="utf-8")
			if l.strip() and not l.startswith("#"))
	if "--baseline" in sys.argv:
		io.open(BASELINE, "w", encoding="utf-8", newline="\n").write(
			"# Tells that predate prose_tells.py. `--strict` ignores these and\n"
			"# fails on anything new. Whether to fix them is a ruling, not a lint.\n"
			"# Re-record with --baseline after a real fix.\n"
			+ "\n".join(sorted(set(e[0] for e in errors))) + "\n")
		print("baselined %d findings" % len(set(e[0] for e in errors)))
		return 0
	fresh = [e for e in errors if e[0] not in base]

	if "--rank" in sys.argv:
		print("%-34s %6s %6s %9s" % ("file", "words", "tells", "per 1000"))
		for rel, d in sorted(density.items(), key=lambda kv: -kv[1] * 1000.0 / max(1, words[kv[0]])):
			print("%-34s %6d %6d %9.2f" % (rel, words[rel], d, d * 1000.0 / max(1, words[rel])))
		print()

	print("%d player-facing strings checked" % scanned)
	enc_w = max(1, words[ENCOUNTERS])
	print("'still' in the encounters: %.0f per 10k words (a shelf of novels runs about 10; 49 before the 2026-10-23 pass)"
		% (still_words[ENCOUNTERS] * 1e4 / enc_w))
	print()
	if errors:
		print("ERRORS  (%d, of which %d are new since the baseline)" % (len(errors), len(fresh)))
		by_tid = collections.Counter(e[3] for e in errors)
		print("  " + ", ".join("%s %d" % kv for kv in by_tid.most_common()))
		for key, rel, n, tid, why, s in errors:
			print("  %s%s:%d  [%s] %s" % ("NEW  " if key not in base else "     ", rel, n, tid, why))
			print("         " + s[:160])
		print()
	if review and "--quiet" not in sys.argv:
		print("REVIEW  (%d) -- worth a look, not automatically wrong" % len(review))
		by_tid = collections.Counter(r[2] for r in review)
		print("  " + ", ".join("%s %d" % kv for kv in by_tid.most_common()))
		for rel, n, tid, why, text in review:
			print("  %s:%d  [%s] %s" % (rel, n, tid, why))
			print("         " + text[:160])
		print()
	if not errors and not review:
		print("clean")
	return 1 if (fresh and "--strict" in sys.argv) else 0


if __name__ == "__main__":
	sys.exit(main())
