#!/usr/bin/env bash
# Export the game for friends: Windows and macOS, release mode, stamped.
#
#   tools/export.sh            both platforms
#   tools/export.sh windows    just Windows
#   tools/export.sh mac        just macOS
#
# Writes into the repo's gitignored builds/<version>-<commit>/ folder:
#   windows/ThreeKelvin.exe (the game, its data EMBEDDED, one file) and
#   ThreeKelvin.console.exe (the same game with a text window, which a friend
#   can run to see errors), and macos/ThreeKelvin.zip -- a universal, ad-hoc
#   signed .app, zipped by Godot. Push that zip EXACTLY as written: re-zipping it
#   on Windows drops the app's run permission, and anything put inside the .app
#   after signing breaks the signature.
#
# ONE EXE, NOT EXE + PCK (binary_format/embed_pck). With the pack beside the exe,
# a friend who double-clicks the exe inside the zip without extracting it gets
# "Couldn't load project data" -- Explorer copies out the exe alone. Embedded,
# there is nothing to leave behind.
#
# THE VERSION STAMP (`BuildInfo`): `tkg/build.json` is written here, from
# project.godot's application/config/version and the short git hash, for the
# length of the export only, and removed after (a run from source says "dev").
# The export carries it as JSON (the presets' include filter: *.lmap, *.json).
#
# IT FAILS LOUDLY, and on more than Godot's exit code:
#   - any ERROR or WARNING line in an export log (EXPORT_LOG_OK is the one place
#     to excuse a line, by regex, with a reason beside it);
#   - THE PACK CHECK: every file the game can load at runtime (everything under
#     tkg/ but the tools, the .gdignore'd folders and the known source-only
#     types) must be in the pack, read off the export's own "Storing File"
#     lines. A file loaded by FileAccess rather than load() -- the .lmap light
#     maps, the room and station .json -- is invisible to Godot's dependency
#     walk, and dropping one is silent in the game: a room comes up unlit;
#   - the SMOKE TEST: the exported Windows game run headless with -- rngtest,
#     -- devtest asrelease and -- parseall (every script, as the export
#     tokenised it). Its user folder is pointed at a scratch one (APPDATA), so
#     a build never writes into this machine's real %APPDATA%/ThreeKelvinAlpha;
#   - the Mac zip must hold the app's binary with its run permission, its pack
#     and its signature.
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

# Export log lines that are not a problem, as one extended regex. Empty: there
# are none today. Add one only with a comment saying why it is harmless.
EXPORT_LOG_OK=''

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
		echo "  Install them once (about 1.3 GB download), either way:"
		echo "  - Godot editor: Editor > Manage Export Templates > Download and Install"
		echo "  - or download Godot_v${GVER%.stable}-stable_export_templates.tpz from"
		echo "    https://github.com/godotengine/godot/releases/tag/${GVER%.stable}-stable"
		echo "    (check it against SHA512-SUMS.txt there; it is a zip), and copy what is"
		echo "    inside its templates/ folder into"
		echo "    $TDIR/"
		echo "    (version.txt, windows_release_x86_64.exe, windows_release_x86_64_console.exe"
		echo "    and macos.zip are the ones this script uses)"
		exit 1
	fi
}
case "$WHICH" in
	windows) check_templates "windows_release_x86_64.exe"; check_templates "windows_release_x86_64_console.exe" ;;
	mac) check_templates "macos.zip" ;;
	all) check_templates "windows_release_x86_64.exe"; check_templates "windows_release_x86_64_console.exe"
		check_templates "macos.zip" ;;
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

# Scratch user folder for the smoke test; removed on exit with the stamp.
SMOKE_HOME="$(mktemp -d)"
printf '{"version":"%s","commit":"%s","date":"%s"}\n' "$VERSION" "$COMMIT" "$DATE" > "$PROJ/build.json"
trap 'rm -f "$PROJ/build.json"; rm -rf "$SMOKE_HOME"' EXIT
echo "export: $VERSION · $COMMIT -> $OUT"

RC=0
fail() { echo "export: FAIL: $*"; RC=1; }

# Lines in a log Godot printed that should stop a build: errors and warnings,
# less any excused above. Godot colours its output; the codes are stripped.
log_problems() {
	sed 's/\x1b\[[0-9;]*m//g' "$1" | grep -E '^(ERROR|WARNING|SCRIPT ERROR|USER ERROR|USER WARNING)|Parse Error|Failed to (load|export)' \
		| { if [ -n "$EXPORT_LOG_OK" ]; then grep -vE "$EXPORT_LOG_OK"; else cat; fi; }
}

# THE PACK CHECK. What the export stored, read off its log, against every file
# under tkg/ that the game could load at runtime. A script is stored compiled
# (.gdc) beside a .remap, an imported file as its .import (its data under
# .godot/imported), a scene or resource as a .remap; anything else as itself.
pack_check() {
	local log="$1" what="$2" stored missing
	stored="$(sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -oE 'Storing File: res://[^ ]*' | sed 's/^Storing File: //' | sort -u)"
	[ -n "$stored" ] || { fail "$what: the export log lists no stored files -- cannot check the pack"; return; }
	# Never shipped, on purpose: source and notes beside the art, the tools,
	# the generator folders Godot is told to ignore (.gdignore).
	local ignored=() d
	while IFS= read -r d; do ignored+=( -path "$d" -prune -o ); done \
		< <(cd "$PROJ" && find . -name .gdignore -not -path './.godot/*' -printf '%h\n')
	missing="$(cd "$PROJ" && find . \( -path ./.godot -o -path ./tools \) -prune -o "${ignored[@]}" -type f -print \
		| sed 's|^\./|res://|' \
		| grep -vE '\.(uid|import|py|md|txt|html|cfg|b64|gdignore|gitignore|DS_Store)$|^res://project\.godot$' \
		| while IFS= read -r f; do
			case "$f" in
				*.gd) want="$f.remap" ;;
				*.png|*.jpg|*.webp|*.svg|*.wav|*.ogg|*.mp3|*.ttf|*.otf|*.glb) want="$f.import" ;;
				*.tscn|*.tres|*.res) want="$f.remap" ;;
				*) want="$f" ;;
			esac
			grep -qxF "$want" <<<"$stored" || grep -qxF "$f" <<<"$stored" || echo "$f"
		done)"
	if [ -n "$missing" ]; then
		fail "$what: files the game can load are NOT in the pack:"
		echo "$missing" | sed 's/^/    /' | head -40
		echo "  (an export filter in export_presets.cfg dropped them -- include_filter takes non-resource types)"
	else
		echo "export: $what pack check: every runtime file is in it ($(grep -c . <<<"$stored") stored)"
	fi
}

export_one() {
	local preset="$1" path="$2" log="$OUT/export-$3.log"
	mkdir -p "$(dirname "$path")"
	rm -f "$path"
	echo "export: $preset"
	if ! "$GODOT" --headless --audio-driver Dummy --path "$PROJ" --export-release "$preset" "$path" >"$log" 2>&1; then
		fail "$preset: Godot returned an error -- see $log"; return 1
	fi
	[ -s "$path" ] || { fail "$preset wrote nothing -- see $log"; return 1; }
	local p; p="$(log_problems "$log")"
	if [ -n "$p" ]; then
		fail "$preset: the export log has errors or warnings (see $log):"
		echo "$p" | sed 's/^/    /' | head -20
	fi
	pack_check "$log" "$preset"
}

size_of() { du -h "$1" 2>/dev/null | cut -f1; }

if [ "$WHICH" = all ] || [ "$WHICH" = windows ]; then
	rm -f "$OUT/windows/ThreeKelvin.pck"
	if export_one "Windows Desktop" "$OUT/windows/ThreeKelvin.exe" windows; then
		[ -e "$OUT/windows/ThreeKelvin.pck" ] && fail "a ThreeKelvin.pck was written beside the exe -- embed_pck is off in the preset"
		CON="$OUT/windows/ThreeKelvin.console.exe"
		[ -e "$CON" ] || fail "no ThreeKelvin.console.exe (debug/export_console_wrapper)"
		# SMOKE TEST, where it can run: the packed, tokenised scripts boot, the
		# stamp is in, developer mode is not, and every script loads.
		if [ -e "$CON" ] && [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
			smoke() {
				APPDATA="$(cygpath -w "$SMOKE_HOME")" "$CON" --headless --audio-driver Dummy -- "$@" 2>&1
			}
			S1="$(smoke rngtest)"
			echo "$S1" | grep -m1 '^\[build\]' || fail "the exported game printed no build line"
			echo "$S1" | grep -q '^rngtest: PASS' && echo "export: smoke rngtest PASS" \
				|| { fail "smoke rngtest"; echo "$S1" | tail -20; }
			S2="$(smoke devtest asrelease)"
			echo "$S2" | grep -q '^devtest: PASS' && echo "export: smoke devtest asrelease PASS" \
				|| { fail "smoke devtest asrelease (developer mode reachable in the export?)"; echo "$S2" | grep -vE '^\s+ok ' | tail -20; }
			S3="$(smoke parseall)"
			if echo "$S3" | grep -qE 'Parse Error|Failed to load script|SCRIPT ERROR'; then
				fail "smoke parseall: a script does not load in the export"; echo "$S3" | grep -E -A2 'Parse Error|Failed to load|SCRIPT ERROR' | head -20
			elif echo "$S3" | grep -q '^parseall: PASS'; then
				echo "export: smoke parseall PASS ($(echo "$S3" | grep -oE 'touched [0-9]+ scripts'))"
			else
				fail "smoke parseall did not pass"; echo "$S3" | tail -10
			fi
		fi
	fi
fi
if [ "$WHICH" = all ] || [ "$WHICH" = mac ]; then
	if export_one "macOS" "$OUT/macos/ThreeKelvin.zip" macos; then
		# The app inside must run as it is: the binary executable, its pack and
		# its (ad-hoc) signature present. unzip -Z reads the stored permissions.
		Z="$OUT/macos/ThreeKelvin.zip"
		if command -v unzip >/dev/null 2>&1; then
			L="$(unzip -Z "$Z")"
			echo "$L" | grep -qE '^-rwx.*\.app/Contents/MacOS/' || fail "mac: the app's binary is not executable in the zip"
			echo "$L" | grep -qE '\.app/Contents/Resources/.*\.pck$' || fail "mac: no .pck in the app"
			echo "$L" | grep -q '_CodeSignature/CodeResources' || fail "mac: the app is not signed (codesign/codesign)"
		fi
	fi
fi

echo
for f in "$OUT/windows/ThreeKelvin.exe" "$OUT/windows/ThreeKelvin.console.exe" "$OUT/macos/ThreeKelvin.zip"; do
	[ -e "$f" ] && printf 'export:   %-6s %s\n' "$(size_of "$f")" "${f#"$ROOT"/}"
done
[ "$RC" -eq 0 ] && echo "export: done, $OUT" || { echo "export: FAILED (see above)"; exit 1; }
