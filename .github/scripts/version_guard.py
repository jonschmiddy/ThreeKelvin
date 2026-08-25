#!/usr/bin/env python3
"""Fail when a serialised shape changes and the number guarding it does not.

    python3 .github/scripts/version_guard.py [BASE [HEAD]]

WHAT THIS IS FOR. Three subsystems here write files or wire messages, and each
carries a number whose entire job is to notice that the shape changed:
`SaveGame.VERSION`, `NetSession.PROTOCOL`, `RunHistory.VERSION`. Each is
designed to fail loudly on a mismatch. In August 2026 a vocabulary pass renamed
keys in all three -- `makers` to `berths`, `house` to `manufacturer`, `maker` to
`manufacturer`, `chassis_maker` to `chassis_manufacturer` -- and raised none of
them. Nothing failed. A save stamped with the current version was read with keys
that were not in it and came back as a galaxy with no contracts anywhere; two
co-op builds shook hands and drew every partner as an unbranded frame; every run
ever flown stopped unlocking its manufacturer.

The vocabulary guard in validate.sh could not have caught it, and neither could
any word grep: BOTH SPELLINGS ARE LEGAL. What changed was not the vocabulary but
the shape, and the thing that was supposed to notice was the number.

THE HARD PART IS NOT THE THREE FILES. It is the other two. `ShipBuild.gd` and
`ContractData.gd` carry keys that go into the wire and the save, and neither
defines a constant of its own -- they are guarded by somebody else's. A check
that looked for `const VERSION` in the changed file would have missed two of the
three breaks. So a file that is part of a format DECLARES it:

    ## @guarded-by SaveGame.VERSION

which is also the documentation that was missing: nothing said out loud that a
contract's `to_wire` was part of the save format until it broke.

WHAT COUNTS AS A KEY. Both spellings GDScript allows, because this codebase uses
both: `"chassis": x` in a dict literal, and the bare `chassis = x,` form that
`RunHistory` writes. Reads count too -- `d.get("berths", [])` names a key just as
much as writing one does.

FALSE POSITIVES ARE THE CHEAP SIDE. Renaming a local variable on a line that
happens to end in a comma will trip this. The answer is to bump the number or,
if the shape genuinely did not change, to say so in the commit and use
`--allow`. That is a worse afternoon than the alternative by a wide margin: the
alternative is a player's suspended run opening as an empty galaxy.
"""

import re
import subprocess
import sys

# The annotation a serialiser uses to name the constant that guards it.
GUARD_RE = re.compile(r"@guarded-by\s+([A-Za-z_][\w]*)\.([A-Z_][A-Z0-9_]*)")

# A file that carries its own number needs no annotation.
SELF_RE = re.compile(r"^const\s+(VERSION|PROTOCOL)\b")

# A key, in either spelling GDScript allows, plus the reads that name one.
KEY_PATTERNS = [
    re.compile(r'"([A-Za-z_][\w]*)"\s*:'),              # "chassis": x
    re.compile(r'\.get\(\s*"([A-Za-z_][\w]*)"'),        # d.get("chassis", ...)
    re.compile(r'\[\s*"([A-Za-z_][\w]*)"\s*\]'),        # d["chassis"]
    re.compile(r"^\s*([a-z_][\w]*)\s*=\s*.+,\s*$"),     # chassis = x,
]

# A line that changes the number itself.
BUMP_RE = re.compile(r"^[+-]\s*const\s+(VERSION|PROTOCOL)\b")


def run(*args):
    return subprocess.run(args, capture_output=True, text=True).stdout


def keys_in(line):
    """Every key named on one line of diff, without its +/- marker."""
    body = line[1:]
    out = set()
    for pat in KEY_PATTERNS:
        for m in pat.finditer(body):
            out.add(m.group(1))
    return out


def guarded_files(_head=None):
    """path -> [guarding constants], for everything in the tree that has one.

    READ FROM THE WORKING TREE, not from either end of the diff. The annotation
    is a statement about what the format is TODAY; a file can have been part of
    the save for months and only now have its keys touched, and a diff that
    predates the annotation must still be judged by it. Reading it at the
    diff's own endpoint would mean a break could never be detected in the
    commit that also added the declaration -- which is exactly the commit where
    somebody first realises the file needed one.
    """
    out = {}
    listing = run("git", "ls-files", "tkg/scripts")
    for path in listing.splitlines():
        if not path.endswith(".gd"):
            continue
        try:
            src = open(path, encoding="utf-8").read()
        except OSError:
            continue
        # ALL of them, not the first. A file can be part of two formats at
        # once -- saved AND sent -- and then a renamed key breaks both, so both
        # numbers have to move. Taking only the first match would quietly
        # excuse the second, which is the same silence this whole file exists
        # to end. Nothing declares two today; the trap is that it would not say
        # so when something does.
        found = ["%s.%s" % (a, b) for a, b in GUARD_RE.findall(src)]
        if found:
            out[path] = found
            continue
        for line in src.splitlines():
            m2 = SELF_RE.match(line)
            if m2:
                out[path] = ["%s.%s" % (path.split("/")[-1][:-3], m2.group(1))]
                break
    return out


def check(diff, guards):
    """Guarded files in `diff` whose keys moved while their number did not."""
    moved, bumped, path = {}, set(), None
    for line in diff.splitlines():
        if line.startswith("+++ b/"):
            path = line[6:]
            continue
        if not path or line.startswith("+++") or line.startswith("---"):
            continue
        if not (line.startswith("+") or line.startswith("-")):
            continue
        if BUMP_RE.match(line):
            bumped.update(guards.get(path, []))
            continue
        if path in guards:
            found = keys_in(line)
            if found:
                side = moved.setdefault(path, {"+": set(), "-": set()})
                side[line[0]] |= found

    bad = []
    for path, sides in sorted(moved.items()):
        changed = sides["+"] ^ sides["-"]
        if not changed:
            continue                       # same keys either side: a reflow
        missing = [g for g in guards[path] if g not in bumped]
        if not missing:
            continue
        bad.append((path, " and ".join(missing), sorted(changed)))
    return bad


def main(argv):
    allow = "--allow" in argv
    args = [a for a in argv[1:] if not a.startswith("--")]
    head = args[1] if len(args) > 1 else "HEAD"
    if args:
        base = args[0]
    else:
        # Default to whatever this branch has added on top of main, and fall
        # back to the last commit when that is empty -- which is the case on
        # main itself, where the interesting diff is the commit just landed.
        base = run("git", "merge-base", "origin/main", "HEAD").strip()
        if not base or base == run("git", "rev-parse", "HEAD").strip():
            base = run("git", "rev-parse", "HEAD~1").strip()

    guards = guarded_files(head)
    # TWO RANGES, JUDGED SEPARATELY, and that is not fussiness. Committed branch
    # work and uncommitted work each need a bump of their own: lumping them
    # together lets a legitimate bump in the last commit excuse a key rename
    # still sitting in the working tree. Found by planting exactly that and
    # watching it pass.
    #
    # `git diff A..B` compares two commits and never sees the tree at all, which
    # is the moment this check is most useful -- before the mistake is committed.
    # `git diff A` reaches it.
    if len(args) > 1:
        ranges = ["%s..%s" % (base, head)]
    else:
        ranges = ["%s..HEAD" % base, "HEAD"]

    bad = []
    for rng in ranges:
        bad += check(run("git", "diff", "--unified=0", rng, "--", "tkg/scripts"),
                     guards)

    seen, out = set(), []
    for path, guard, keys in bad:
        if path in seen:
            continue
        seen.add(path)
        out.append((path, guard, keys))
    bad = out

    if not bad:
        print("version guard: PASS (%d guarded files, %s..%s)"
              % (len(guards), base[:9], head[:9]))
        return 0

    for path, guard, keys in bad:
        print("  FAIL %s changed keys %s" % (path, ", ".join(keys)))
        print("       and %s did not move" % guard)
    print("version guard: %d FAILURES" % len(bad))
    if allow:
        print("  (--allow given: reported, not failed)")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
