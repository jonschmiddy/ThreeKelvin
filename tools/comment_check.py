#!/usr/bin/env python3
"""Comments in tkg/**/*.gd stay short: no run of more than MAX_RUN comment lines, and
every `docs/why/<Stem>.md#<anchor>` pointer resolves to a heading there. Longer
reasoning goes in docs/why/<Stem>.md, the source file's own doc."""
import re
import sys
from pathlib import Path

MAX_RUN = 5

ROOT = Path(__file__).resolve().parent.parent
REF = re.compile(r"docs/why/([\w./-]+?\.md)#([\w-]+)")


def slug(heading):
    return re.sub(r"[^\w\- ]", "", heading.strip().lower()).replace(" ", "-")


def anchors(doc):
    found, fence = set(), None
    for line in doc.read_text(encoding="utf-8").splitlines():
        if fence:
            if line.strip() == fence:
                fence = None
        elif line.startswith("```"):
            fence = line[:len(line) - len(line.lstrip("`"))]
        elif line.startswith("#"):
            found.add(slug(line.lstrip("#")))
    return found


def in_strings(lines):
    """Line numbers inside a triple-quoted string, where a '#' is not a comment."""
    inside, out = False, set()
    for n, line in enumerate(lines, 1):
        if inside:
            out.add(n)
        if (line.count('"""') + line.count("'''")) % 2:
            inside = not inside
    return out


def main():
    problems, cache = [], {}
    for gd in sorted((ROOT / "tkg").rglob("*.gd")):
        rel = gd.relative_to(ROOT).as_posix()
        lines = gd.read_text(encoding="utf-8").splitlines()
        own = f"{gd.stem}.md"
        for n, line in enumerate(lines, 1):
            for name, anchor in REF.findall(line):
                doc = ROOT / "docs" / "why" / name
                if doc not in cache:
                    cache[doc] = anchors(doc) if doc.is_file() else None
                if cache[doc] is None:
                    problems.append(f"{rel}:{n}: docs/why/{name} does not exist")
                elif anchor not in cache[doc]:
                    problems.append(f"{rel}:{n}: no heading in docs/why/{name} for #{anchor}")
        skip, start = in_strings(lines), None
        for n, line in enumerate(lines + [""], 1):
            if n not in skip and line.lstrip().startswith("#"):
                start = start or n
                continue
            if start and n - start > MAX_RUN:
                problems.append(f"{rel}:{start}: {n - start} comment lines in a row "
                                f"(max {MAX_RUN}); move the reasoning to docs/why/{own}")
            start = None
    for p in problems:
        print(p)
    print(f"comment check: {'FAIL' if problems else 'PASS'} ({len(problems)} problems)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
