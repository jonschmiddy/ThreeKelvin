#!/usr/bin/env python3
"""The gate script checks itself: .github/scripts/validate.sh is built from `unit_<name>() {` functions
and lists of unit names, and a slip in either is silent (a unit defined twice runs twice, a renamed unit
loses its place in the order). Checks, no baseline (all are zero today and must stay so):
  1. no `unit_<name>() {` is defined twice
  2. every name in SOLO_UNITS, FIRST_UNITS, AFTER_UNITS and STATIC_UNITS is a defined unit
  3. every label in `gate_weight` is a defined unit (a trailing `*` matches a family: solvetest_*)
  4. every `docs/why/<file>.md#<anchor>` pointer in validate.sh names a real heading
Run: python3 tools/gate_lint.py [--selftest]   Why: docs/why/gate_lint.md"""
import fnmatch
import re
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from comment_check import REF, anchors  # the resolver the .gd pointers use

ROOT = Path(__file__).resolve().parent.parent
UNIT = re.compile(r"^unit_([A-Za-z0-9_]+)\(\) \{$", re.M)
LISTS = ("SOLO_UNITS", "FIRST_UNITS", "AFTER_UNITS", "STATIC_UNITS")


def lint(root):
    """A list of plain-words problems (empty when the script is sound)."""
    gate = root / ".github" / "scripts" / "validate.sh"
    text = gate.read_text(encoding="utf-8", errors="replace")
    problems = []
    names = UNIT.findall(text)
    defined = set(names)
    for n in sorted(defined):
        if names.count(n) > 1:
            problems.append(
                f"unit_{n}() is defined {names.count(n)} times in validate.sh. The unit list is built by sed, so it\n"
                f"    runs {names.count(n)} times and nobody sees it. Delete the extra definition (keep the newer one).")
    for lst in LISTS:
        m = re.search(r'^%s="([^"]*)"' % lst, text, re.M)
        if not m:
            problems.append(f"{lst} is not set in validate.sh (the scheduler reads it). Restore the line.")
            continue
        for n in m.group(1).split():
            if n not in defined:
                problems.append(
                    f"{lst} names {n}, and validate.sh has no unit_{n}() {{. The scheduler would stop with an error.\n"
                    f"    Fix the name in {lst}, or define the unit.")
    w = re.search(r"^gate_weight\(\) \{\n(.*?)^\}", text, re.M | re.S)
    if w:
        for label in sorted(set(re.findall(r"([A-Za-z0-9_*|]+)\) echo \d+", w.group(1)))):
            for part in label.split("|"):
                if part != "*" and not any(fnmatch.fnmatch(d, part) for d in defined):
                    problems.append(
                        f"gate_weight has a time for {part}, and there is no such unit. The weight does nothing: the unit it was\n"
                        f"    meant for starts late. Fix the label to the unit's real name, or delete the line.")
    cache = {}
    for n, line in enumerate(text.splitlines(), 1):
        for name, anchor in REF.findall(line):
            doc = root / "docs" / "why" / name
            if doc not in cache:
                cache[doc] = anchors(doc) if doc.is_file() else None
            if cache[doc] is None:
                problems.append(f"validate.sh:{n}: points at docs/why/{name}, which does not exist. Fix the path.")
            elif anchor not in cache[doc]:
                problems.append(
                    f"validate.sh:{n}: points at docs/why/{name}#{anchor}, and that file has no heading for it.\n"
                    f"    Add the heading (`## {anchor}`) or fix the pointer.")
    return problems


SYNTH_GATE = '''# Why: docs/why/validate.md#unit_good
unit_good() {
step "x"
}
unit_dup() {
step "x"
}
unit_dup() {
step "x"
}
unit_flight_1() {
step "x"
}
unit_flight_2() {
step "x"
}
# Why: docs/why/validate.md#unit_nowhere
# Why: docs/why/missing.md#anything
SOLO_UNITS="good ghost"
FIRST_UNITS="good"
AFTER_UNITS="dup"
STATIC_UNITS="good nostatic"
gate_weight() {
	case "$1" in
		good) echo 5 ;; flight_*) echo 9 ;; phantom) echo 7 ;;
		*) echo 15 ;;
	esac
}
'''


def selftest():
    bad = []
    with tempfile.TemporaryDirectory(prefix="gate_lint_selftest_") as tmp:
        root = Path(tmp)
        (root / ".github" / "scripts").mkdir(parents=True)
        (root / "docs" / "why").mkdir(parents=True)
        (root / ".github" / "scripts" / "validate.sh").write_text(SYNTH_GATE)
        (root / "docs" / "why" / "validate.md").write_text("# Why\n\n## unit_good\ntext\n")
        got = "\n".join(lint(root))
        want = ["unit_dup() is defined 2 times", "SOLO_UNITS names ghost", "STATIC_UNITS names nostatic", "time for phantom",
                "validate.md#unit_nowhere", "docs/why/missing.md, which does not exist"]
        for w in want:
            if w not in got:
                bad.append("missed: " + w)
        if len(lint(root)) != len(want):
            bad.append("expected exactly %d problems, got %d: %s" % (len(want), len(lint(root)), got))
    return bad


def main(argv):
    if "--selftest" in argv:
        bad = selftest()
        for b in bad:
            print(b)
        print("gate lint selftest: %s" % ("FAIL (%d)" % len(bad) if bad else "PASS"))
        return 1 if bad else 0
    problems = lint(ROOT)
    for p in problems:
        print("PROBLEM " + p)
    print(f"gate lint: {'FAIL' if problems else 'PASS'} ({len(problems)} problems)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
