"""Resolve CHANGELOG.md merge conflicts by keeping both sides' bullets.

Each conflict block is split into sections by "### " headers; bullets
(a "- " line plus its indented continuation lines) are gathered per section,
main's first, then the branch's, duplicates dropped. Sections come out as
Fixed, Changed, Added, then any other header. Usage: python resolve_changelog.py <CHANGELOG.md>
"""
import sys

ORDER = ["### Fixed", "### Changed", "### Added"]


def sections(lines):
    out, cur = {}, None
    bullet = None
    for line in lines:
        if line.startswith("### "):
            cur = line.strip()
            out.setdefault(cur, [])
            bullet = None
        elif line.startswith("- "):
            bullet = [line]
            out.setdefault(cur, []).append(bullet)
        elif line.startswith("  ") and bullet is not None:
            bullet.append(line)
        # blank lines are dropped; they are re-added between sections
    return out


def resolve(text):
    lines = text.split("\n")
    res = []
    i = 0
    while i < len(lines):
        if lines[i].startswith("<<<<<<< "):
            m = next(j for j in range(i, len(lines)) if lines[j] == "=======")
            e = next(j for j in range(m, len(lines)) if lines[j].startswith(">>>>>>> "))
            head, theirs = sections(lines[i + 1:m]), sections(lines[m + 1:e])
            merged = {}
            for src in (theirs, head):
                for h, bl in src.items():
                    dest = merged.setdefault(h, [])
                    for b in bl:
                        if b not in dest:
                            dest.append(b)
            block = []
            if None in merged:
                # bullets inside a section whose header sits outside the conflict
                for b in merged.pop(None):
                    block += b
                block.append("")
            heads = [h for h in ORDER if h in merged] + [h for h in merged if h not in ORDER]
            for h in heads:
                block += [h, ""]
                for b in merged[h]:
                    block += b
                block.append("")
            res += block
            i = e + 1
        else:
            res.append(lines[i])
            i += 1
    out = "\n".join(res)
    while "\n\n\n" in out:
        out = out.replace("\n\n\n", "\n\n")
    return out


if __name__ == "__main__":
    p = sys.argv[1]
    s = open(p, encoding="utf-8").read()
    open(p, "w", encoding="utf-8", newline="\n").write(resolve(s))
