"""cut_changelog.py VERSION [DATE]: fold changes/*.md into CHANGELOG.md as the new build.

The fragments, in name order, become a `## DATE` / `### [VERSION]` section placed
above the last build's, and are deleted. Write the section's opening paragraph
(what the build is, in a few lines) by hand afterwards; the script leaves a
marker where it goes. Run from the repository root; DATE defaults to today.
"""
import datetime
import glob
import os
import re
import sys

if len(sys.argv) not in (2, 3):
    sys.exit(__doc__)
version = sys.argv[1]
date = sys.argv[2] if len(sys.argv) == 3 else datetime.date.today().isoformat()

files = sorted(f for f in glob.glob("changes/*.md") if os.path.basename(f) != "README.md")
if not files:
    sys.exit("changes/ holds nothing to fold in")
bullets = "".join(open(f, encoding="utf-8").read().rstrip("\n") + "\n" for f in files)

path = "CHANGELOG.md"
text = open(path, encoding="utf-8").read()
m = re.search(r"^## \d{4}-\d{2}-\d{2}$", text, re.M)
if not m:
    sys.exit("CHANGELOG.md has no dated build section to put the new one above")
section = f"## {date}\n\n### [{version}]\n\n(Write what this build is, in a few lines.)\n\n{bullets}\n"
open(path, "w", encoding="utf-8").write(text[:m.start()] + section + text[m.start():])
for f in files:
    os.remove(f)
print(f"{len(files)} files folded into CHANGELOG.md as [{version}], {date}; write its opening paragraph")
