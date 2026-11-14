#!/usr/bin/env python3
"""Test-map ratchet: every harness in tkg/scripts/sim that can be run has a row in docs/tests.md.
Three kinds of fact, none of them a line number:
  uncovered <Stem>        a runnable harness that no row in docs/tests.md names
  stale-row <token>       a row that runs `sheet=<Stem>` or `-- <flag>` which no longer exists
  gate-missing <token>    validate.sh runs a `sheet=<Stem>` or `-- <flag>` which no longer exists
What predates the rule is in tools/tests_map_check_baseline.txt; the gate fails only on NEW entries.
Run: python3 tools/tests_map_check.py [--update] [--selftest]
Why the rule, and what counts as runnable: docs/why/tests_map_check.md."""
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASELINE = ROOT / "tools" / "tests_map_check_baseline.txt"
HEADER = (
    "# Harnesses with no row in docs/tests.md that predate tools/tests_map_check.py (mostly look-and-dump\n"
    "# tools left without a row on purpose). The gate ignores these and fails on anything new.\n"
    "# Shrink it by adding the row, then: python3 tools/tests_map_check.py --update\n"
    "# uncovered <Stem> | stale-row <token> | gate-missing <token>\n"
)

# A script that extends one of these cannot be added to the scene tree, so `sheet=` cannot start it.
NOT_NODES = ("RefCounted", "Object", "Resource")
ROW_FLAG = re.compile(r"flag = \"([A-Za-z0-9_]+)\"")
ROW_STARTS = re.compile(r"starts = \"([A-Za-z0-9_]+)=\"")
SIM_PATH = re.compile(r"scripts/sim/([A-Za-z0-9_]+)\.gd")
FUNC_HEAD = re.compile(r"^func (_?[A-Za-z0-9_]+)\(", re.M)


def read(p):
    return p.read_text(encoding="utf-8", errors="replace") if p.is_file() else ""


def sim_scripts(root):
    """{Stem: text} for every .gd directly in tkg/scripts/sim."""
    return {p.stem: read(p) for p in sorted((root / "tkg" / "scripts" / "sim").glob("*.gd"))}


def node_based(stem, scripts, seen=None):
    """True when the script's chain of `extends` ends at something that can join the scene tree
    AND some script on the chain defines `_ready` (what `sheet=` relies on)."""
    seen = seen or set()
    if stem in seen or stem not in scripts:
        return False
    seen.add(stem)
    text = scripts[stem]
    has_ready = re.search(r"^func _ready\(", text, re.M) is not None
    m = re.search(r"^extends\s+(\"res://scripts/sim/(\w+)\.gd\"|(\w+))", text, re.M)
    if not m:
        return False  # no extends is a RefCounted
    parent = m.group(2) or m.group(3)
    if parent in scripts:
        return has_ready or node_based(parent, scripts, seen)
    return has_ready and parent not in NOT_NODES


def dispatch_table(root):
    """({flag: set of Stems it runs}, set of flags and `starts` prefixes, sheet_prefix_runs_any)
    read from DevFlags.gd. A row with a `fn` runs the Stems that function's body names."""
    text = read(root / "tkg" / "scripts" / "DevFlags.gd") + "\n" + read(root / "tkg" / "scripts" / "Main.gd")
    heads = list(FUNC_HEAD.finditer(text))
    bodies = {}
    for i, h in enumerate(heads):
        bodies[h.group(1)] = text[h.end():heads[i + 1].start() if i + 1 < len(heads) else len(text)]
    flag_stems, names = {}, set()
    for row in re.finditer(r"\{[^{}\n]*\}", text):
        r = row.group(0)
        f, st = ROW_FLAG.search(r), ROW_STARTS.search(r)
        key = f.group(1) if f else (st.group(1) if st else None)
        if not key:
            continue
        names.add(key)
        stems = set(SIM_PATH.findall(r))
        fn = re.search(r"fn = \"(\w+)\"", r)
        if fn:
            stems |= set(SIM_PATH.findall(bodies.get(fn.group(1), "")))
            stems |= set(re.findall(r"\b([A-Z][A-Za-z0-9]+)\.new\(", bodies.get(fn.group(1), "")))
        flag_stems[key] = stems
    return flag_stems, names


def runnable(root):
    """{Stem: [names it is run by]}. A flag row's script is runnable by that flag; any other
    Node-based script with a `_ready` is runnable as `sheet=<Stem>` (the `sheet=` row loads any)."""
    scripts = sim_scripts(root)
    flag_stems, names = dispatch_table(root)
    out = {}
    for flag, stems in flag_stems.items():
        for s in stems:
            if s in scripts:
                out.setdefault(s, []).append(flag)
    if "sheet" in names:
        for s in scripts:
            if node_based(s, scripts):
                out.setdefault(s, []).append("sheet=" + s)
    return out, scripts, names


def word(token, text, flag_form=False):
    """True if `token` appears in text as a whole word (a flag only after `-- `)."""
    if flag_form:
        return re.search(r"--\s+" + re.escape(token) + r"(?![A-Za-z0-9_=])", text) is not None
    return re.search(r"(?<![A-Za-z0-9_])" + re.escape(token) + r"(?![A-Za-z0-9_])", text) is not None


def covered(stem, flags, docs):
    if word(stem, docs) or word(stem.lower(), docs):
        return True
    for f in flags:
        if f.startswith("sheet="):
            continue
        if word(f, docs, flag_form=True):
            return True
    return False


def named_in(text):
    """Every `sheet=<Stem>` and first word after `-- ` in the text, as (kind, name)."""
    found = set()
    for m in re.finditer(r"`-- ([A-Za-z0-9_]+)(=([A-Za-z0-9_]+))?", text):
        if m.group(1) == "sheet" and m.group(3):
            found.add(("sheet", m.group(3)))
        elif m.group(2) is None:
            found.add(("flag", m.group(1)))
        else:
            found.add(("flag", m.group(1) + "="))
    return found


def gate_named(text):
    """What validate.sh passes to the game after the lone ` -- ` of a Godot command."""
    found = set()
    for line in text.splitlines():
        if "--path" not in line:
            continue
        m = re.search(r"--path\s+\"?\$\w+\"?\s+--\s+([A-Za-z0-9_=]+)", line)
        if not m:
            continue
        tok = m.group(1).strip("\"'")
        if tok.startswith("sheet="):
            found.add(("sheet", tok[6:]))
        elif re.match(r"[a-z][a-z0-9_]*$", tok):
            found.add(("flag", tok))
    return found


def literal_somewhere(root, token):
    """True if a game script outside DevFlags tests for the flag itself (`s == "gfxprobe"`, `"ash" in args`)."""
    needle = '"' + token + '"'
    for p in (root / "tkg" / "scripts").rglob("*.gd"):
        if needle in read(p):
            return True
    return False


def facts(root=ROOT):
    """{key: detail} for every problem in the tree."""
    run, scripts, names = runnable(root)
    docs = read(root / "docs" / "tests.md")
    out = {}
    for stem in sorted(run):
        if not covered(stem, run[stem], docs):
            out["uncovered " + stem] = sorted(run[stem])[0]
    for where, text, label in (("stale-row", docs, "a row in docs/tests.md"),
                               ("gate-missing", read(root / ".github" / "scripts" / "validate.sh"), "validate.sh")):
        pairs = named_in(text) if where == "stale-row" else gate_named(text)
        for kind, name in sorted(pairs):
            if kind == "sheet":
                if name not in run or "sheet=" + name not in run[name]:
                    # a stem runnable only by its own flag is not a `sheet=` target
                    out[f"{where} sheet={name}"] = label
            elif name not in names and name != "sheet" and not name.endswith("=") and not literal_somewhere(root, name):
                out[f"{where} {name}"] = label
    return out


def read_baseline():
    out = set()
    if BASELINE.is_file():
        for line in BASELINE.read_text(encoding="utf-8").splitlines():
            if line.strip() and not line.startswith("#"):
                out.add(line.strip())
    return out


def row_template(stem, flag):
    how = f"-- sheet={stem}" if flag.startswith("sheet=") else f"-- {flag}"
    return f"| `{how}` | touching <what this harness guards: the class or file>. <What it proves, in one line.> In the merge gate, or not in the gate. |"


def explain(key, detail):
    kind, _, name = key.partition(" ")
    if kind == "uncovered":
        stem = name
        return (f"NEW {key}\n"
                f"    {stem} (tkg/scripts/sim/{stem}.gd) is a harness you can run, and docs/tests.md has no row for it.\n"
                f"    A row is how the next session knows to run it: it greps that file for the class it touched and runs every\n"
                f"    row that names it. With no row, this test passes today and nobody runs it when it matters.\n"
                f"    Fix: add one row to docs/tests.md, next to its neighbours, like this:\n"
                f"    {row_template(stem, detail)}")
    if kind == "stale-row":
        return (f"NEW {key}\n"
                f"    docs/tests.md tells a session to run `{name}`, and the game no longer has it. A session that follows the row\n"
                f"    gets an error, or worse, the game boots normally and looks like it passed.\n"
                f"    Fix: delete the row, or point it at the harness's new name (see tkg/scripts/DevFlags.gd).")
    return (f"NEW {key}\n"
            f"    .github/scripts/validate.sh runs `{name}` and the game has no such harness or flag, so that unit tests nothing.\n"
            f"    Fix: correct the name in validate.sh (a unit's owner should do this), or remove the unit.")


def check(update):
    cur, old = facts(), read_baseline()
    if update:
        for k in sorted(set(cur) - old):
            print(f"ADDED {k}")
        BASELINE.write_text(HEADER + "".join(k + "\n" for k in sorted(cur)), encoding="utf-8")
        print(f"tests map: recorded {len(cur)} entries (was {len(old)})")
        return 0
    new = sorted(k for k in cur if k not in old)
    fixed = sorted(old - set(cur))
    for k in new:
        print(explain(k, cur[k]))
    for k in fixed:
        print(f"FIXED {k}")
    if fixed:
        print("run python3 tools/tests_map_check.py --update to shrink the baseline")
    print(f"tests map: {'FAIL' if new else 'PASS'} ({len(new)} new, {len(cur) - len(new)} baselined, {len(fixed)} fixed)")
    return 1 if new else 0


# ---------------------------------------------------------------- self-test

DEVFLAGS = '''class_name DevFlags
const EARLY: Array[Dictionary] = [
	{flag = "alpha", script = "res://scripts/sim/AlphaTest.gd", how = "quit"},
	{flag = "beta", script = "res://scripts/sim/BetaSheet.gd", how = "hold"},
	{flag = "gamma", fn = "_gamma"},
	{flag = "delta", script = "res://scripts/sim/DeltaTest.gd", how = "quit"},
]
const BOOTED: Array[Dictionary] = [
	{starts = "sheet=", script = "res://scripts/sim/%s.gd", how = "add"},
	{starts = "dump=", script = "res://scripts/sim/DumpTool.gd", how = "hold"},
]
func _gamma() -> bool:
	var t: RefCounted = load("res://scripts/sim/GammaTest.gd").new()
	return true
'''
SYNTH = {
    "AlphaTest": "extends Harness\nfunc run() -> void:\n\tpass\n",
    "BetaSheet": "extends RefCounted\nfunc run(tree) -> void:\n\tpass\n",
    "GammaTest": "extends RefCounted\nfunc run() -> void:\n\tpass\n",
    "DeltaTest": "extends Harness\nfunc run() -> void:\n\tpass\n",
    "NodeProbe": "extends Node\nfunc _ready() -> void:\n\tpass\n",
    "NodeTwo": "extends Node\nfunc _ready() -> void:\n\tpass\n",
    "NodeKid": 'extends "res://scripts/sim/NodeTwo.gd"\n',
    "DumpTool": "extends RefCounted\nfunc run(tree) -> void:\n\tpass\n",
    "Harness": "extends RefCounted\nclass_name Harness\n",
    "HelperOnly": "extends RefCounted\nfunc make():\n\tpass\n",
    "NodeNoReady": "extends Node\nfunc go():\n\tpass\n",
}
DOCS = """| Command | Run it after |
|---|---|
| `-- alpha` | touching alpha |
| `-- sheet=NodeTwo` | touching two |
| `-- beta` | touching beta |
| `-- sheet=Gone` | a harness that was deleted |
| `-- removedflag` | a flag that was deleted |
the GammaTest run is covered by its stem; deltatest is covered by its lowercase stem.
"""
GATE = """run_godot a 60 --headless --path "$PROJECT" -- sheet=NodeProbe
run_godot b 60 --headless --path "$PROJECT" -- sheet=Vanished
run_godot c 60 --headless --path "$PROJECT" -- alpha
run_godot d 60 --headless --path "$PROJECT" -- nosuchflag
"""
EXPECTED = {
    "uncovered DumpTool",                 # runnable by `dump=`, no row names it
    "uncovered NodeKid",                  # a Node by inheritance
    "uncovered NodeProbe",                # runnable as sheet=, no row
    "stale-row sheet=Gone",
    "stale-row removedflag",
    "gate-missing sheet=Vanished",
    "gate-missing nosuchflag",
}


def selftest():
    bad = []
    with tempfile.TemporaryDirectory(prefix="tests_map_selftest_") as tmp:
        root = Path(tmp)
        (root / "tkg" / "scripts" / "sim").mkdir(parents=True)
        (root / "docs").mkdir()
        (root / ".github" / "scripts").mkdir(parents=True)
        (root / "tkg" / "scripts" / "DevFlags.gd").write_text(DEVFLAGS)
        for stem, text in SYNTH.items():
            (root / "tkg" / "scripts" / "sim" / (stem + ".gd")).write_text(text)
        (root / "docs" / "tests.md").write_text(DOCS)
        (root / ".github" / "scripts" / "validate.sh").write_text(GATE)
        got = set(facts(root))
        for k in sorted(EXPECTED - got):
            bad.append("missed " + k)
        for k in sorted(got - EXPECTED):
            bad.append("false " + k)
    return bad


def main(argv):
    if "--selftest" in argv:
        bad = selftest()
        for b in bad:
            print(b)
        print("tests map selftest: %s" % ("FAIL (%d)" % len(bad) if bad else "PASS"))
        return 1 if bad else 0
    return check("--update" in argv)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
