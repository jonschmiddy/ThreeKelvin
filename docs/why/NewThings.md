The reasoning behind `tkg/scripts/data/NewThings.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## New things

Above `const NEXT := "next"`:

```text
WHAT CHANGED IN EACH BUILD, for the title menu's NEW THINGS page
(`NewThingsPopup`). Jon, Nov 5: "a NEW THINGS button on the main menu that
shares changes that are done per version ... just a brief bulleted list".

NEWEST FIRST. Each entry is a version, the day it went out (YYYY-MM-DD) and a
few short lines a player would notice, in plain words: no internal names, one
line each. CHANGELOG.md holds the long form; this is the short one.

THE VERSION RULE. A build's version is `application/config/version` in
project.godot; `tools/export.sh` stamps that same string into the build
(`BuildInfo`), and `tools/dev/release.sh` cuts a release under it. Work on
main that has not gone out yet sits in ONE entry at the top whose version is
NEXT, with no date. The release branch, the same commit that raises
config/version and cuts the CHANGELOG, renames NEXT to the new version and
dates it; `release.sh` refuses a version whose entry is not the newest one
here (`tools/dev/new_things_check.sh`). So the newest entry is either NEXT,
with config/version's own entry right under it, or config/version itself.
Until it is cut, NEXT is headed "dev" from source, as the title's corner
says (`BuildInfo.stamp`), and "NEXT · <commit>" in an exported build that is
not a release: the corner's version there is the last release's, and these
lines did not go out in it.

THE GRADE. `tools/prose_tells.py --strict` reads these lines like any other
player text. `tools/prose_grade.py --all` does NOT grade them: it skips a
string of one sentence, and most lines here are one. So grade each new line
by hand before it lands, 7.0 or under:
    cd tools && python -c "import prose_grade as p; print(p.grade('A line.'))"
Jon's own words for 0.4.0-alpha.1 ("Initial alpha release.", 13.1) stay as
he wrote them.
```
