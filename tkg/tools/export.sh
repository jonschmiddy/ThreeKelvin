#!/usr/bin/env bash
# Export the game for friends: Windows and macOS, release mode, stamped.
#
#   tools/export.sh            both platforms
#   tools/export.sh windows    just Windows
#   tools/export.sh mac        just macOS
#
# Writes into the repo's gitignored builds/<version>-<commit>/ folder:
#   windows/ThreeKelvin.exe (+ .pck beside it, + ThreeKelvin.console.exe, which
#   a friend can run to see errors), and macos/ThreeKelvin.zip -- a universal,
#   ad-hoc signed .app, zipped by Godot. Push that zip EXACTLY as written:
#   re-zipping it on Windows drops the app's run permission, and anything put
#   inside the .app after signing breaks the signature.
#
# THE VERSION STAMP (`BuildInfo`): `tkg/build.json` is written here, from
# project.godot's application/config/version and the short git hash, for the
# length of the export only, and removed after (a run from source says "dev").
# The export carries it as JSON (the presets' include filter: *.lmap, *.json).
#
# Release exports never have the editor feature, so developer mode cannot be
# reached in what this makes (`DevMode.available`; `-- devtest asrelease`).
#
# Needs Godot 4.7.1's export templates installed -- see check_templates below.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJ="$ROOT/tkg"
GODOT="${GODOT:-godot}"
command -v "$GODOT" >/dev/null 2>&1 || GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
WHICH="${1:-all}"

# --- the templates ---------------------------------------------------------
# Godot looks for them under its own data folder, by exact version.
GVER="$("$GODOT" --version 2>/dev/null | head -1 | cut -d. -f1-4)"   # 4.7.1.stable
case "$(uname -s)" in
	MINGW*|MSYS*|CYGWIN*) TDIR="$APPDATA/Godot/export_templates/$GVER" ;;
	Darwin) TDIR="$HOME/Library/Application Support/Godot/export_templates/$GVER" ;;
	*) TDIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$GVER" ;;
esac
check_templates() {
	local need="$1"
	if [ ! -f "$TDIR/$need" ]; then
		echo "export: Godot's export templates for $GVER are not installed ($TDIR/$need missing)."
		echo "  Install them once (about 1 GB, no CPU load), either way:"
		echo "  - Godot editor: Editor > Manage Export Templates > Download and Install"
		echo "  - or download Godot_v${GVER%.stable}-stable_export_templates.tpz from"
		echo "    https://github.com/godotengine/godot/releases/tag/${GVER%.stable}-stable"
		echo "    (it is a zip), and copy what is inside its templates/ folder into"
		echo "    $TDIR/"
		exit 1
	fi
}
case "$WHICH" in
	windows) check_templates "windows_release_x86_64.exe" ;;
	mac) check_templates "macos.zip" ;;
	all) check_templates "windows_release_x86_64.exe"; check_templates "macos.zip" ;;
	*) echo "usage: tools/export.sh [all|windows|mac]"; exit 2 ;;
esac

# --- the stamp -------------------------------------------------------------
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$PROJ/project.godot" | head -1)"
[ -n "$VERSION" ] || { echo "export: no application/config/version in project.godot"; exit 1; }
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD)"
# A dirty tree is exported, but it says so in the stamp: a build nobody can
# check out again should not wear a hash that claims otherwise.
if [ -n "$(git -C "$ROOT" status --porcelain -- tkg ':!tkg/build.json')" ]; then
	COMMIT="$COMMIT+dirty"
	echo "export: WARNING, uncommitted changes under tkg/ -- stamped $COMMIT"
fi
DATE="$(date -u +%Y-%m-%dT%H:%MZ)"
OUT="$ROOT/builds/$VERSION-${COMMIT/+/-}"
mkdir -p "$OUT"

printf '{"version":"%s","commit":"%s","date":"%s"}\n' "$VERSION" "$COMMIT" "$DATE" > "$PROJ/build.json"
trap 'rm -f "$PROJ/build.json"' EXIT
echo "export: $VERSION · $COMMIT -> $OUT"

RC=0
export_one() {
	local preset="$1" path="$2"
	mkdir -p "$(dirname "$path")"
	echo "export: $preset"
	if ! "$GODOT" --headless --path "$PROJ" --export-release "$preset" "$path" >"$OUT/export-$3.log" 2>&1; then
		echo "export: $preset FAILED -- see $OUT/export-$3.log"; RC=1; return
	fi
	[ -e "$path" ] || { echo "export: $preset wrote nothing -- see $OUT/export-$3.log"; RC=1; }
}

if [ "$WHICH" = all ] || [ "$WHICH" = windows ]; then
	export_one "Windows Desktop" "$OUT/windows/ThreeKelvin.exe" windows
	# SMOKE TEST, where it can run: the packed, tokenised scripts boot, the
	# stamp is in, developer mode is not. rngtest is quick and touches the
	# autoloads and every generator.
	CON="$OUT/windows/ThreeKelvin.console.exe"
	if [ -e "$CON" ] && [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
		SMOKE="$("$CON" --headless -- rngtest 2>&1)"
		echo "$SMOKE" | grep -m1 '^\[build\]' || { echo "export: the exported game printed no build line"; RC=1; }
		echo "$SMOKE" | grep -q '^rngtest: PASS' && echo "export: smoke test (rngtest) PASS" \
			|| { echo "export: smoke test FAILED"; echo "$SMOKE" | tail -20; RC=1; }
	fi
fi
if [ "$WHICH" = all ] || [ "$WHICH" = mac ]; then
	export_one "macOS" "$OUT/macos/ThreeKelvin.zip" macos
fi

[ "$RC" -eq 0 ] && echo "export: done, $OUT" || { echo "export: FAILED"; exit 1; }
