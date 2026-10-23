# Sourced by every script in tools/dev. Works on Windows (Git Bash) and macOS.
#
# Finds, in this order of trust:
#   TK_REPO     the MAIN checkout (not a worktree): where main lands and pushes
#   TK_WT       the folder of worktrees beside it (../tk-wt)
#   TK_SCRATCH  throwaway files: test profiles, logs, takes, pages (../tk-scratch)
#   GODOT       the Godot binary (console build on Windows, the app's binary on a Mac)
#   PY          python3, or python where that is all there is
# Any of them can be set in the environment first to override.
#
# THE ONE RULE THIS FILE EXISTS TO KEEP: no Godot run made through these tools
# ever touches the real profile (%APPDATA%\ThreeKelvinAlpha on Windows,
# ~/Library/Application Support/ThreeKelvinAlpha on a Mac). `tk_isolated` points
# user:// at a fresh folder under TK_SCRATCH, and `tk_guard` PROVES that works
# on this machine before anything runs (see probe/).

_tk_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
	Darwin) TK_OS=mac ;;
	MINGW*|MSYS*|CYGWIN*) TK_OS=win ;;
	*) TK_OS=linux ;;
esac

if [ -z "${TK_REPO:-}" ]; then
	# The first entry of `git worktree list` is always the main checkout, even
	# when this file is read from inside a worktree.
	TK_REPO="$(git -C "$_tk_here" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')"
fi
TK_WT="${TK_WT:-$(dirname "$TK_REPO")/tk-wt}"
TK_SCRATCH="${TK_SCRATCH:-$(dirname "$TK_REPO")/tk-scratch}"
mkdir -p "$TK_WT" "$TK_SCRATCH/profiles" "$TK_SCRATCH/logs"

# THE REAL BINARY, NEVER A WRAPPER. gate_land.sh hands validate.sh
# GODOT=tools/dev/godot_quiet.sh, and godot_quiet.sh reads this file: taking
# GODOT from the environment there made it exec itself forever (Oct 23, every
# gate unit timed out). TK_GODOT_BIN carries the real one through.
if [ -n "${TK_GODOT_BIN:-}" ]; then GODOT="$TK_GODOT_BIN"; fi
case "${GODOT:-}" in *tools/dev/*) GODOT="" ;; esac
if [ -z "${GODOT:-}" ]; then
	if [ "$TK_OS" = mac ] && [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
		GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
	elif [ "$TK_OS" = win ] && [ -x "/c/Users/$USERNAME/AppData/Local/Microsoft/WinGet/Links/godot_console.exe" ]; then
		GODOT="/c/Users/$USERNAME/AppData/Local/Microsoft/WinGet/Links/godot_console.exe"
	else
		GODOT="$(command -v godot || command -v godot4 || echo godot)"
	fi
fi

if [ -z "${PY:-}" ]; then
	if python3 -c "" >/dev/null 2>&1; then PY=python3; else PY=python; fi
fi

TK_GODOT_BIN="$GODOT"
export TK_OS TK_REPO TK_WT TK_SCRATCH GODOT TK_GODOT_BIN PY

# Tools installed per user come first: uv in ~/.local/bin, and on the Mac a
# current Node in ~/.local/node (the system one in /usr/local/bin is v4, too old
# for the gate's manifest step).
for _d in "$HOME/.local/node/bin" "$HOME/.local/bin"; do
	case ":$PATH:" in *":$_d:"*) ;; *) [ -d "$_d" ] && PATH="$_d:$PATH" ;; esac
done
export PATH

# THE GATE ON A SMALL MACHINE. Six steps at once ran several past their time
# limits on Jon's Mac (Intel, 8 GB: 23 minutes and five timeouts, Oct 23). With
# 8 GB or less, run three. GATE_JOBS set in the environment still wins.
if [ -z "${GATE_JOBS:-}" ] && [ "$TK_OS" = mac ]; then
	_mem=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
	[ "$_mem" -le 8589934592 ] && export GATE_JOBS=3
fi

# tk_timeout <seconds> <command...>
# GNU `timeout` is not on a stock Mac; gtimeout is (Homebrew coreutils); perl always is.
tk_timeout() {
	local s="$1"; shift
	if command -v timeout >/dev/null 2>&1; then timeout "$s" "$@"
	elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$s" "$@"
	else perl -e 'alarm shift; exec @ARGV' "$s" "$@"
	fi
}

# tk_new_profile -> prints a fresh, empty profile folder under TK_SCRATCH.
tk_new_profile() {
	local d
	d="$(mktemp -d "$TK_SCRATCH/profiles/p.XXXXXX")"
	mkdir -p "$d/AppData" "$d/home/.local/share" "$d/home/.config"
	printf '%s\n' "$d"
}

# tk_isolated <profile-dir> <command...>
# Runs the command with user:// pointed inside <profile-dir>: APPDATA and
# LOCALAPPDATA on Windows; HOME and the XDG folders on macOS and Linux (Godot
# reads ~/Library/Application Support from HOME on a Mac).
tk_isolated() {
	local p="$1"; shift
	if [ "$TK_OS" = win ]; then
		local w; w="$(cygpath -w "$p/AppData")"
		APPDATA="$w" LOCALAPPDATA="$w" "$@"
	else
		HOME="$p/home" XDG_DATA_HOME="$p/home/.local/share" XDG_CONFIG_HOME="$p/home/.config" "$@"
	fi
}

# tk_guard: refuses (returns 1) unless an isolated Godot really writes inside
# the scratch profile. Runs the probe project once per Godot binary and
# remembers a pass in TK_SCRATCH.
tk_guard() {
	local stamp="$TK_SCRATCH/.guard_ok_$(printf '%s' "$GODOT" | cksum | cut -d' ' -f1)"
	[ -f "$stamp" ] && return 0
	local p out dir
	p="$(tk_new_profile)"
	out="$(tk_isolated "$p" tk_timeout 120 "$GODOT" --headless --audio-driver Dummy \
		--path "$_tk_here/probe" --script res://probe.gd 2>&1)"
	dir="$(printf '%s\n' "$out" | sed -n 's/^USER_DIR=//p' | tr -d '\r' | head -n 1)"
	# One spelling for both sides: Git Bash paths on Windows, and real paths
	# (symlinks resolved) on a Mac, where /var is /private/var.
	local want="$p"
	if [ "$TK_OS" = win ]; then
		dir="$(cygpath -u "$dir" 2>/dev/null || echo "$dir")"
		want="$(cygpath -u "$p")"
	else
		want="$(cd "$p" && pwd -P)"
		[ -d "$dir" ] && dir="$(cd "$dir" && pwd -P)"
	fi
	if [ -n "$dir" ] && [ "${dir#"$want"}" != "$dir" ]; then
		: >"$stamp"
		rm -rf "$p"
		return 0
	fi
	echo "tk_guard: REFUSED. An isolated Godot would use '$dir', not a folder inside $p." >&2
	echo "tk_guard: nothing was run. The real profile is not safe with these settings on this machine." >&2
	printf '%s\n' "$out" | tail -n 5 >&2
	rm -rf "$p"
	return 1
}
