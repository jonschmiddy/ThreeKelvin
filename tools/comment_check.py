#!/usr/bin/env python3
"""Every `docs/why/<file>.md#<anchor>` in tkg/**/*.gd must resolve to a heading
there, and no STRICT file may hold more than MAX_RUN comment lines in a row.
Add a file to STRICT once its long comments have moved to docs/why/."""
import re
import sys
from pathlib import Path

STRICT = [
    "tkg/scripts/autoload/RunState.gd",
]
MAX_RUN = 5

ROOT = Path(__file__).resolve().parent.parent
REF = re.compile(r"docs/why/([\w./-]+?\.md)#([\w-]+)")


def slug(heading):
    return re.sub(r"[^\w\- ]", "", heading.strip().lower()).replace(" ", "-")


def anchors(doc):
    found, fenced = set(), False
    for line in doc.read_text(encoding="utf-8").splitlines():
        if line.startswith("```"):
            fenced = not fenced
        elif not fenced and line.startswith("#"):
            found.add(slug(line.lstrip("#")))
    return found


def main():
    problems, cache = [], {}
    for gd in sorted((ROOT / "tkg").rglob("*.gd")):
        rel = gd.relative_to(ROOT).as_posix()
        lines = gd.read_text(encoding="utf-8").splitlines()
        for n, line in enumerate(lines, 1):
            for name, anchor in REF.findall(line):
                doc = ROOT / "docs" / "why" / name
                if doc not in cache:
                    cache[doc] = anchors(doc) if doc.is_file() else None
                if cache[doc] is None:
                    problems.append(f"{rel}:{n}: docs/why/{name} does not exist")
                elif anchor not in cache[doc]:
                    problems.append(f"{rel}:{n}: no heading in docs/why/{name} for #{anchor}")
        if rel in STRICT:
            start = None
            for n, line in enumerate(lines + [""], 1):
                if line.lstrip().startswith("#"):
                    start = start or n
                    continue
                if start and n - start > MAX_RUN:
                    problems.append(f"{rel}:{start}: {n - start} comment lines in a row "
                                    f"(max {MAX_RUN}); move the reasoning to docs/why/")
                start = None
    for p in problems:
        print(p)
    print(f"comment check: {'FAIL' if problems else 'PASS'} ({len(problems)} problems)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
