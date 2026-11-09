#!/usr/bin/env python3
"""Maintainability ratchet for game code (tkg/scripts, not sim). Fails on NEW debt:
a function over MAX_FUNC lines, a file over MAX_FILE lines, a function returning a bare
Dictionary, Array or Variant. What predates the rule is in tools/code_check_baseline.txt;
a recorded length may not grow. Run: python tools/code_check.py [--update]
Why the rules, and how a line is counted: docs/why/code_check.md."""
import re
import sys
from pathlib import Path

MAX_FUNC = 100
MAX_FILE = 3000
BARE = ("Dictionary", "Array", "Variant")

ROOT = Path(__file__).resolve().parent.parent
BASELINE = ROOT / "tools" / "code_check_baseline.txt"
HEADER = (
    "# Debt that predates tools/code_check.py. The gate ignores these and fails on anything\n"
    "# new, or a length that grew. Shrink it by fixing code, then: python tools/code_check.py --update\n"
    "# length <file>::<func> <lines> | file <file> <lines> | bare <file>::<func>\n"
)

DECL = re.compile(r"(static\s+(?:func|var)\b|func\b|var\b|const\b|signal\b|class\b|class_name\b|enum\b|extends\b|@)")
FUNC = re.compile(r"(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(")


def indent_of(raw):
    lead = raw[:len(raw) - len(raw.lstrip(" \t"))]
    return len(lead.replace("\t", "    "))


def lex(raws):
    """Each line with its string literals kept and its # comment dropped."""
    codes, state = [], None
    for raw in raws:
        out, i, n = [], 0, len(raw)
        while i < n:
            if state:
                j = raw.find(state, i)
                out.append(raw[i:] if j < 0 else raw[i:j + 3])
                i, state = (n, state) if j < 0 else (j + 3, None)
                continue
            c = raw[i]
            if c == "#":
                break
            if raw.startswith('"""', i) or raw.startswith("'''", i):
                state = raw[i:i + 3]
                out.append(state)
                i += 3
            elif c in "\"'":
                j = i + 1
                while j < n and raw[j] != c:
                    j += 2 if raw[j] == "\\" else 1
                out.append(raw[i:j + 1])
                i = j + 1
            else:
                out.append(c)
                i += 1
        codes.append("".join(out))
    return codes


def return_type(codes, s, m):
    """The text after `->` in the signature of the func on line s, or None."""
    buf = " ".join([codes[s].lstrip()[m.end() - 1:]] + codes[s + 1:s + 12])
    depth = 0
    for i, ch in enumerate(buf):
        depth += (ch in "([{") - (ch in ")]}")
        if depth == 0:
            colon = buf.find(":", i + 1)
            seg = buf[i + 1:colon if colon >= 0 else len(buf)]
            r = re.search(r"->\s*(.*)$", seg)
            return r.group(1).strip() if r else None
    return None


def functions(raws):
    """(name, lines, return type) per func. A func runs from its `func` line to the last
    code line before the next declaration at its indent or less."""
    codes, found, seen = lex(raws), [], {}
    for s, line in enumerate(codes):
        m = FUNC.match(line.lstrip())
        if not m:
            continue
        ind, last = indent_of(raws[s]), s
        for j in range(s + 1, len(raws)):
            if not codes[j].strip():
                continue
            if indent_of(raws[j]) <= ind and DECL.match(codes[j].lstrip()):
                break
            last = j
        name = m.group(1)
        seen[name] = seen.get(name, 0) + 1
        if seen[name] > 1:
            name = f"{name}#{seen[name]}"
        found.append((name, last - s + 1, return_type(codes, s, m)))
    return found


def measure():
    """{key: size} for every debt in the tree; size is None where it has no length."""
    debt = {}
    for gd in sorted((ROOT / "tkg" / "scripts").rglob("*.gd")):
        rel = gd.relative_to(ROOT / "tkg").as_posix()
        if rel.startswith("scripts/sim/"):
            continue
        raws = gd.read_text(encoding="utf-8", errors="replace").splitlines()
        if len(raws) > MAX_FILE:
            debt[f"file {rel}"] = len(raws)
        for name, lines, ret in functions(raws):
            if lines > MAX_FUNC:
                debt[f"length {rel}::{name}"] = lines
            if ret in BARE:
                debt[f"bare {rel}::{name}"] = None
    return debt


def read_baseline():
    out = {}
    if BASELINE.is_file():
        for line in BASELINE.read_text(encoding="utf-8").splitlines():
            if line.strip() and not line.startswith("#"):
                if line.startswith("bare"):
                    out[line] = None
                else:
                    key, _, size = line.rpartition(" ")
                    out[key] = int(size)
    return out


def write_baseline(debt):
    rows = [f"{k} {v}" if v is not None else k for k, v in sorted(debt.items())]
    BASELINE.write_text(HEADER + "\n".join(rows) + "\n", encoding="utf-8")


def main():
    debt, old = measure(), read_baseline()
    if "--update" in sys.argv:
        for k, v in sorted(debt.items()):
            if k not in old or (v or 0) > (old[k] or 0):
                print(f"ADDED {k} {v or ''}".rstrip())
        write_baseline(debt)
        print(f"code check: recorded {len(debt)} entries (was {len(old)})")
        return 0
    problems, fixed = [], []
    for k, v in sorted(debt.items()):
        if k not in old:
            problems.append(f"NEW {k}" + (f" is {v} lines" if v else " returns a bare type; give it Array[T] or Dictionary[K, V]"))
        elif v and v > old[k]:
            problems.append(f"GREW {k}: {old[k]} lines, now {v}")
    for k, v in sorted(old.items()):
        if k not in debt:
            fixed.append(f"FIXED {k}")
        elif v and debt[k] < v:
            fixed.append(f"SHRANK {k}: {v} lines, now {debt[k]}")
    for line in problems + fixed:
        print(line)
    if fixed:
        print("run python tools/code_check.py --update to shrink the baseline")
    print(f"code check: {'FAIL' if problems else 'PASS'} ({len(problems)} new, "
          f"{len(debt) - len(problems)} baselined, {len(fixed)} fixed)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
