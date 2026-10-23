#!/usr/bin/env bash
# release.sh <worktree> <branch> <label> <version>
#
# Land the branch (gate_land.sh), build the Windows and Mac zips from a CLEAN
# detached copy of the landed main (tkg/tools/build_alpha.sh), check the Mac
# app still has its executable bit, copy the zips to <repo>/builds/<version>-<sha>/
# (gitignored), and tag and push alpha-<version>.
#
# Before running: the branch sets config/version="<version>" in tkg/project.godot
# and has its CHANGELOG cut (## date, ### [version]). Nothing is uploaded
# anywhere: Jon shares the zips himself.
#
# The build needs Godot's export templates for this exact Godot version
# installed (Godot > Editor > Manage Export Templates).
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$D/env.sh"
WT="$1"; BR="$2"; LB="$3"; VER="$4"
out=$(bash "$D/gate_land.sh" "$WT" "$BR" "$LB" 2>&1 | tail -4); echo "$out"
echo "$out" | grep -q "^LANDED" || { echo "STOPPED: gate did not land"; exit 1; }
SHA=$(git -C "$TK_REPO" rev-parse --short main); echo "main $SHA"
git -C "$TK_REPO" show main:tkg/project.godot | grep -q "config/version=\"$VER\"" \
	|| { echo "STOPPED: main is not version $VER"; exit 1; }
REL="$TK_WT/release-$VER"
git -C "$TK_REPO" worktree add -q --detach "$REL" "$SHA" || exit 1
cd "$REL" || exit 1
p="$(tk_new_profile)"
tk_isolated "$p" tk_timeout 900 "$GODOT" --headless --audio-driver Dummy --path tkg --import >/dev/null 2>&1 \
	|| tk_isolated "$p" tk_timeout 900 "$GODOT" --headless --audio-driver Dummy --path tkg --import >/dev/null 2>&1
rm -rf "$p"
BLOG="$TK_SCRATCH/logs/build_$VER.log"
# NOT isolated: Godot finds its export templates through the same user folder
# (APPDATA on Windows, HOME on a Mac). tools/export.sh points its own smoke runs
# at a scratch folder (Windows; it skips them on a Mac).
tk_timeout 1800 bash tkg/tools/build_alpha.sh >"$BLOG" 2>&1; echo "build exit $?"
grep -E "pack check|smoke" "$BLOG"
B=$(ls -d "$REL"/builds/"$VER"-* 2>/dev/null | head -n 1)
ls "$B"/*.zip || { echo "STOPPED: no zips (log $BLOG)"; exit 1; }
"$PY" - "$B" <<'EOF'
import glob, io, os, sys, zipfile
m = glob.glob(os.path.join(sys.argv[1], '*-mac.zip'))[0]
f = zipfile.ZipFile(m)
inner = [n for n in f.namelist() if n.endswith('.zip')]
g = zipfile.ZipFile(io.BytesIO(f.read(inner[0]))) if inner else f
print('mac app:', [(oct((i.external_attr >> 16) & 0o777), i.filename) for i in g.infolist()
                   if '/MacOS/' in i.filename or 'CodeResources' in i.filename])
EOF
DEST="$TK_REPO/builds/$(basename "$B")"
mkdir -p "$DEST" && cp "$B"/*.zip "$DEST"/ && (cd "$DEST" && shasum -a 256 *.zip 2>/dev/null || sha256sum *.zip)
git -C "$TK_REPO" tag -a "alpha-$VER" "$SHA" -m "$VER. Windows and Mac zips built from this commit." \
	&& git -C "$TK_REPO" push -q origin "alpha-$VER" && git -C "$TK_REPO" ls-remote --tags origin "alpha-$VER"
echo "ZIPS: $DEST"
