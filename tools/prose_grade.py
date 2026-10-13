# -*- coding: utf-8 -*-
"""How hard the encounter prose is to read.

    python tools/prose_grade.py                 every encounter, worst first
    python tools/prose_grade.py the_long_crew   one encounter, string by string
    python tools/prose_grade.py --all           every player-facing string over
                                                the target, worst first (report)

RULED 2026-09-12, by Jonathan, reading the batch that had just landed: "The
language of these is kind of dense... hard to read. Almost verbose in a way that
no real human would write," and "I don't want people to need a PhD or
college-level education to play this game."

So the target is a number rather than a taste. The grade is Flesch-Kincaid,
which is two ratios -- words per sentence and syllables per word -- so the two
ways to fail it are a long clause chain and a long word, in that order.

RE-RULED 2026-10-13, by Jonathan: GRADE 7.0 OR UNDER for ALL player-facing
text, encounters included (it was 5.0, encounters only). The gate still runs
over the encounters; `--all` reports the rest and does not fail.

  - The words-a-sentence average moves with it, 13 to 17. At the table's 1.24
    syllables a word, grade 5 sits at about 15 words a sentence and grade 7 at
    about 20; 13 was a little under the first, so 17 is a little under the
    second. It still fails the 42 below (19.0), which is what the cap is for.
  - No sentence over 22 words stays. A cap on the longest sentence only ever
    splits a chain into two real sentences, and 22 is already past the 19-word
    average Jon called dense.
  - THE GRADE IS A CEILING, NOT A GOAL. Never chop a line into fragments to
    lower it. `prose_tells.py` flags a string whose sentences are mostly
    verbless ("fragments" on its REVIEW list); that is the floor, and a rewrite
    that trips it has been cut too far.

Measured when the rule was made, over the bodies of each cohort:

    the original 47    grade 7.1   17.5 words a sentence
    batches 01-06      grade 6.0   16.8
    the 42 written     grade 7.1   19.0     <- the ones he was reading

The 42 got there with the longest sentences of the three, because the brief they
were written to said "long chains of and clauses are fine" and said nothing on
the other side of it.
"""
from __future__ import annotations

import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tkg", "scripts", "systems", "OptionTable.gd")
GRADE_MAX = 7.0     # RULED 2026-10-13 (was 5.0)
WORDS_MAX = 17.0    # follows the grade (was 13.0)
SENTENCE_MAX = 22

VOWELS = "aeiouy"


def syllables(word: str) -> int:
	w = re.sub(r"[^a-z]", "", word.lower())
	if not w:
		return 0
	n, prev = 0, False
	for ch in w:
		v = ch in VOWELS
		if v and not prev:
			n += 1
		prev = v
	if w.endswith("e") and n > 1:
		n -= 1
	return max(1, n)


def sentences(text: str) -> list:
	return [s.strip() for s in re.split(r"(?<=[.!?]) ", text) if s.strip()]


def grade(text: str):
	"""Grade, words a sentence, longest sentence in words."""
	ss = sentences(text)
	words = re.findall(r"[A-Za-z']+", text)
	if not ss or not words:
		return 0.0, 0.0, 0
	syl = sum(syllables(w) for w in words)
	return (0.39 * (len(words) / len(ss)) + 11.8 * (syl / len(words)) - 15.59,
		len(words) / len(ss),
		max(len(s.split()) for s in ss))


def blocks() -> dict:
	t = io.open(SRC, encoding="utf-8").read()
	out = {}
	for blk in re.split(r"\n(?=\t\t\{\n)", t):
		m = re.search(r'id = &"([a-z_0-9]+)"', blk)
		if m:
			out[m.group(1)] = blk
	return out


def strings_of(blk: str) -> list:
	"""Every string a player reads in one entry: body, outcomes, death lines."""
	out = []
	m = re.search(r'body = "(.*?)",\n', blk, re.S)
	if m:
		out.append(("body", m.group(1)))
	for s in re.findall(r'return \{text = "((?:[^"\\]|\\.)*)"', blk):
		out.append(("text", s))
	for s in re.findall(r'take_hull_damage\([^,]+, "((?:[^"\\]|\\.)*)"', blk):
		out.append(("death", s))
	return out


def report_all() -> int:
	"""Every player-facing string of two sentences or more that is over the
	target, worst first. A report, never a failure: the ruling covers all text,
	but only the encounters had been brought under it when it was made."""
	sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
	import prose_tells
	rows = []
	checked = 0
	for rel, n, _unit, text in prose_tells.player_strings():
		# a slot reads as a word or a number, not as nothing
		filled = re.sub(r"%[-0-9.]*[sd]|\{[A-Z_]+\}", "nine", text)
		if len(sentences(filled)) < 2:
			continue
		checked += 1
		g, wps, longest = grade(filled)
		if g > GRADE_MAX or wps > WORDS_MAX or longest > SENTENCE_MAX:
			rows.append((g, wps, longest, rel, n, text))
	rows.sort(reverse=True)
	for g, wps, longest, rel, n, text in rows:
		print("%5.1f %5.1f %3d  %s:%d" % (g, wps, longest, rel, n))
		print("        " + text[:150])
	print("\n%d strings of two sentences or more | %d over target (grade %.1f, %.0f words a sentence, longest %d)"
		% (checked, len(rows), GRADE_MAX, WORDS_MAX, SENTENCE_MAX))
	return 0


def main() -> int:
	if "--all" in sys.argv:
		return report_all()
	by_id = blocks()
	want = [a for a in sys.argv[1:] if not a.startswith("-")]
	if want:
		for i in want:
			if i not in by_id:
				print("no encounter %s" % i)
				continue
			print("=== %s" % i)
			for kind, s in strings_of(by_id[i]):
				g, wps, longest = grade(s)
				flag = "  <<<" if g > GRADE_MAX or wps > WORDS_MAX or longest > SENTENCE_MAX else ""
				print("  %-6s grade %4.1f  %4.1f words a sentence  longest %2d%s"
					% (kind, g, wps, longest, flag))
				if flag:
					print("         " + max(sentences(s), key=lambda x: len(x.split())))
		return 0

	rows = []
	over = 0
	for i, blk in by_id.items():
		ss = strings_of(blk)
		text = " ".join(s for _, s in ss)
		g, wps, longest = grade(text)
		worst = max((grade(s)[0] for _, s in ss), default=0.0)
		rows.append((g, wps, longest, worst, i))
		if g > GRADE_MAX or wps > WORDS_MAX or longest > SENTENCE_MAX:
			over += 1
	rows.sort(reverse=True)
	print("%-24s %5s %6s %8s %7s" % ("encounter", "grade", "words", "longest", "worst"))
	for g, wps, longest, worst, i in rows:
		print("%-24s %5.1f %6.1f %8d %7.1f" % (i, g, wps, longest, worst))
	whole = " ".join(s for blk in by_id.values() for _, s in strings_of(blk))
	g, wps, longest = grade(whole)
	print("\n%d encounters | whole table grade %.1f, %.1f words a sentence | %d over target"
		% (len(rows), g, wps, over))
	return 1 if over else 0


if __name__ == "__main__":
	sys.exit(main())
