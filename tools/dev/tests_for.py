#!/usr/bin/env python3
"""tests_for.py: which tests does this change need?

    python3 tools/dev/tests_for.py                  # changed since main, plus the working tree
    python3 tools/dev/tests_for.py --base <commit>  # changed since that commit
    python3 tools/dev/tests_for.py --staged         # only what is staged for the next commit
    python3 tools/dev/tests_for.py --run            # also run the headless ones (tools/dev/godot.sh)
    python3 tools/dev/tests_for.py --list-all       # every row of docs/tests.md, as this tool reads it

It does by machine what tkg/CLAUDE.md asks a session to do by hand: for each changed
game file, find the rows of docs/tests.md that name its class, and the functions the
diff touched. Standard library only. Why: docs/why/check.md#tests_for
"""
import argparse
import fnmatch
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TESTS_MD = ROOT / "docs" / "tests.md"

# Rows a --run may start besides Godot ones: they only read the tree. Anything else
# (installers that write art, export, build_alpha) is left to a person.
SAFE_SCRIPTS = ("tools/code_check.py", "tools/code_graph.py", "tools/cofight.sh", "tools/cojoin.sh")
# Function names too common to say anything about which row is meant.
COMMON_FUNCS = {"_ready", "_process", "_init", "_draw", "_input", "_to_string", "_physics_process",
                "_unhandled_input", "_notification", "_exit_tree", "_enter_tree", "new", "get", "set"}
LEAK_OK = re.compile(r"resources still in use at exit|RID allocations of type .* were leaked at exit")
ERR_RE = re.compile(r"SCRIPT ERROR|Parse Error|Compile Error|^ERROR:")
FAIL_RE = re.compile(r"^=== FAIL|^[A-Za-z0-9_]+: [0-9]+ FAILURES|^[A-Za-z0-9_]+: FAIL$|"
                     r"^[A-Za-z0-9_]+: .*\([1-9][0-9]* failed\)")


# ---------------------------------------------------------------- the table

class Command(object):
    """One runnable thing named in a row's first cell."""

    def __init__(self, text):
        self.text = text          # as written, without backticks
        self.kind = "godot"       # godot | script
        self.flags = []           # Godot flags before `--`
        self.args = []            # what follows `--` (or the script's arguments), optional parts dropped
        self.label = ""           # the harness's own name, lower case, for its PASS line
        self.needs_arg = False    # a required <placeholder> is left: a person must fill it in


class Row(object):
    def __init__(self, cell1, cell2, line):
        self.cell1 = cell1
        self.cell2 = cell2
        self.line = line
        self.commands = []
        self.mode = "headless"    # headless | windowed | unstated
        self.fixed_fps = ""       # "60" when the row says --fixed-fps 60
        self.minutes = 0          # "~4 min" in the second cell


def split_cells(line):
    return [c.strip() for c in re.split(r"(?<!\\)\|", line.strip().strip("|"))]


def split_segments(cell):
    """The cell as (backtick spans outside parentheses, text of parentheses with its spans)."""
    spans, paren = [], []
    depth, i, buf, in_tick = 0, 0, "", False
    while i < len(cell):
        ch = cell[i]
        if ch == "`":
            in_tick = not in_tick
            if not in_tick:
                if depth:
                    paren.append("`" + buf + "`")
                else:
                    spans.append(buf)
                buf = ""
            i += 1
            continue
        if in_tick:
            buf += ch
        elif ch == "(":
            depth += 1
            paren.append("(")
        elif ch == ")":
            depth = max(0, depth - 1)
            paren.append(")")
        elif depth:
            paren.append(ch)
        i += 1
    return spans, "".join(paren)


def drop_optional(text):
    prev = None
    while prev != text:
        prev = text
        text = re.sub(r"\[[^\[\]]*\]", "", text)
    return text


def parse_command(span, annotation):
    s = span.replace("\\|", "|").strip()
    c = Command(s)
    if s.startswith("--") or " -- " in s:
        if s.startswith("-- "):
            flags, args = "", s[3:]
        elif " -- " in s:
            flags, args = s.split(" -- ", 1)
        else:
            return None   # a flag-only modifier such as `--headless --fixed-fps 60`
        c.flags = drop_optional(flags).split()
        c.args = drop_optional(args).split()
        first = c.args[0] if c.args else ""
        if first.startswith("sheet="):
            c.label = first[len("sheet="):].lower()
        else:
            c.label = first.lower()
        for a in c.args:
            if re.search(r"<[^>]*>|\.\.\.|\|", a):
                c.needs_arg = True
        return c
    m = re.match(r"(python3?|bash|sh)?\s*([A-Za-z0-9_./-]+\.(py|sh))\b(.*)", s)
    if m:
        c.kind = "script"
        c.args = [m.group(2)] + drop_optional(m.group(4)).replace("\\|", "|").split()
        c.label = Path(m.group(2)).stem
        return c
    c.kind = "other"      # `uv run ...` and the like: shown, never run
    return c


def gate_labels():
    """Names the merge gate runs headless (`-- savetest`, `-- sheet=X`): a row that never says
    headless is still safe to run when the gate runs its command."""
    out = set()
    f = ROOT / ".github" / "scripts" / "validate.sh"
    if f.is_file():
        text = f.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r"--path \"\$PROJECT\"[^\n]*?-- (?:sheet=)?([A-Za-z0-9_]+)", text):
            out.add(m.group(1).lower())
    return out


def parse_table():
    gate = gate_labels()
    rows = []
    lines = TESTS_MD.read_text(encoding="utf-8").split("\n")
    seen_sep = False
    for n, line in enumerate(lines, 1):
        if not line.startswith("|"):
            continue
        if not seen_sep:
            if re.match(r"^\|\s*-+", line):
                seen_sep = True
            continue
        cells = split_cells(line)
        if len(cells) < 2:
            continue
        cell1, cell2 = cells[0], " | ".join(cells[1:])
        row = Row(cell1, cell2, n)
        spans, ann = split_segments(cell1)
        fps = re.search(r"--fixed-fps\s+(\d+)", cell1)
        row.fixed_fps = fps.group(1) if fps else ""
        for sp in spans:
            cmd = parse_command(sp, ann)
            if cmd is not None:
                row.commands.append(cmd)
        # windowed or headless, from the first cell first, then the prose
        c1 = cell1.lower()
        win1 = re.search(r"--windowed|--write-movie|--resolution|render\.sh|windowed", c1)
        head1 = re.search(r"headless", c1)
        c2 = cell2.lower()
        win2 = re.search(r"needs a window|\bwindowed\b|render\.sh|manual, not in the gate|on demand only", c2)
        in_gate = re.search(r"(?<!not )in the (merge )?gate", c2) is not None
        if win1:
            row.mode = "windowed"
        elif head1 or in_gate:
            row.mode = "headless"
        elif win2:
            row.mode = "windowed"
        elif row.commands and all(c.kind == "godot" and c.label in gate for c in row.commands):
            row.mode = "headless"     # the merge gate runs it headless
        else:
            row.mode = "unstated"     # the row never says: a person decides
        mins = re.search(r"~\s*(\d+)\s*min", cell2)
        row.minutes = int(mins.group(1)) if mins else 0
        rows.append(row)
    return rows


# ---------------------------------------------------------------- the change

def git(*args):
    p = subprocess.run(["git", "-C", str(ROOT)] + list(args), stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, universal_newlines=True)
    return p.returncode, p.stdout, p.stderr


def ref_exists(ref):
    return git("rev-parse", "--verify", "--quiet", ref + "^{commit}")[0] == 0


def changed_files(base, staged, head="HEAD"):
    """{path: status} of files changed (A added, M modified); deleted files are left out."""
    out = {}

    def take(args):
        rc, text, err = git(*args)
        if rc != 0:
            sys.stderr.write("tests_for: git %s failed: %s\n" % (" ".join(args), err.strip()))
            sys.exit(2)
        for line in text.splitlines():
            if "\t" not in line:
                continue
            st, path = line.split("\t", 1)
            st = st[0]
            if st == "D":
                out.pop(path, None)
                continue
            out[path] = "A" if (st == "A" and path not in out) else out.get(path, st)

    if staged:
        take(["diff", "--cached", "--name-status", "--no-renames"])
    else:
        take(["diff", "--name-status", "--no-renames", base + "..." + head])
        if head == "HEAD":
            take(["diff", "--name-status", "--no-renames", "HEAD"])
            rc, text, _ = git("ls-files", "--others", "--exclude-standard")
            for path in text.splitlines():
                out[path] = "A"
    return out


def changed_functions(base, staged, path, status, head="HEAD"):
    """Names of the functions a diff touched in one .gd file: a func line added or removed,
    or a hunk inside a func body (git names the enclosing func in the hunk header)."""
    names = set()
    diffs = []
    if staged:
        diffs.append(git("diff", "--cached", "-U0", "--no-color", "--no-renames", "--", path)[1])
    else:
        diffs.append(git("diff", "-U0", "--no-color", "--no-renames", base + "..." + head, "--", path)[1])
        if head == "HEAD":
            diffs.append(git("diff", "-U0", "--no-color", "--no-renames", "HEAD", "--", path)[1])
    func_line = re.compile(r"(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)")
    for d in diffs:
        for line in d.splitlines():
            if line.startswith("@@"):
                m = re.match(r"@@[^@]*@@\s*" + func_line.pattern, line)
                if m:
                    names.add(m.group(1))
            elif line[:1] in "+-" and not line.startswith(("+++", "---")):
                m = re.match(r"[+-]\s*" + func_line.pattern, line)
                if m:
                    names.add(m.group(1))
    if not names:
        f = ROOT / path
        if f.is_file() and head == "HEAD" and (status == "A" or path in untracked_files()):
            for m in re.finditer(r"^\s*(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)", f.read_text(
                    encoding="utf-8", errors="replace"), re.M):
                names.add(m.group(1))
    return names


_UNTRACKED = []


def untracked_files():
    if not _UNTRACKED:
        _UNTRACKED.append(set(git("ls-files", "--others", "--exclude-standard")[1].splitlines()))
    return _UNTRACKED[0]


def class_name_of(path):
    f = ROOT / path
    if f.is_file():
        for line in f.read_text(encoding="utf-8", errors="replace").splitlines()[:40]:
            m = re.match(r"\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", line)
            if m:
                return m.group(1)
    return ""


def word(name):
    return re.compile(r"(?<![A-Za-z0-9_])" + re.escape(name) + r"(?![A-Za-z0-9_])")


def is_game_file(path):
    return ((path.startswith("tkg/scripts/") and path.endswith(".gd"))
            or (path.startswith("tkg/shaders/")))


def names_for(path):
    """The words a test row would use for this file: its stem and class_name."""
    stem = Path(path).stem
    out = [stem]
    cn = class_name_of(path)
    if cn and cn != stem:
        out.append(cn)
    return out


def distinctive(name):
    """A bare (un-backticked) word names a class only when it is not an ordinary English word."""
    return bool(re.search(r"[a-z][A-Z]|[A-Z]{2}|_|[0-9]", name)) or name.isupper()


def match_row(row, path, funcs):
    """The reasons a row applies to this file, or []."""
    reasons = []
    text1, text2 = row.cell1, row.cell2
    both = text1 + " " + text2
    ticks = " ".join(re.findall(r"`([^`]*)`", both))
    for name in names_for(path):
        if word(name).search(ticks):
            reasons.append("names `%s`" % name)
            break
        if distinctive(name) and word(name).search(re.sub(r"`[^`]*`", " ", both)):
            reasons.append("names %s" % name)
            break
        for c in row.commands:
            if c.label and c.label == name.lower():
                reasons.append("is the `%s` harness" % name)
                break
    if path.startswith("tkg/shaders/"):
        rel = path[len("tkg/"):]
        d = rel.rsplit("/", 1)[0] + "/"
        if rel in both or d in both:
            reasons.append("names `%s`" % d)
    for tok in re.findall(r"[A-Za-z0-9_*]*\*[A-Za-z0-9_*]*\.gd", ticks):
        if len(tok.replace("*", "").replace(".gd", "")) >= 3 and fnmatch.fnmatch(Path(path).name, tok):
            reasons.append("names `%s`" % tok)
            break
    # Functions: a span that is exactly `func`, `func()` or `Class.func`. With the class named
    # too, any such function is a precise hit; alone, only a public snake_case name is
    # distinctive enough (`heal`, `release` also occur in other classes).
    mine = [n.lower() for n in names_for(path)]
    named_funcs = []
    for span in re.findall(r"`([^`]*)`", both):
        m = re.match(r"^(?:([A-Za-z0-9_]+)\.)?([A-Za-z_][A-Za-z0-9_]*)(?:\(\))?$", span.strip())
        if not m or m.group(2) not in funcs or m.group(2) in COMMON_FUNCS or m.group(2) in named_funcs:
            continue
        cls, fn = m.group(1), m.group(2)
        if cls and cls.lower() not in mine:
            continue
        if reasons or cls or (not fn.startswith("_") and "_" in fn):
            named_funcs.append(fn)
    if named_funcs:
        reasons.append("names the changed " + ", ".join("`%s`" % f for f in sorted(named_funcs)))
    return reasons


# ---------------------------------------------------------------- printing

def tags(row):
    t = [{"windowed": "windowed", "unstated": "headless or windowed not stated"}.get(row.mode, "headless")]
    if row.fixed_fps:
        t.append("--fixed-fps " + row.fixed_fps)
    return ", ".join(t)


def runnable(row):
    """The commands of a row this tool will start itself."""
    if row.mode != "headless":
        return []
    out = []
    for c in row.commands:
        if c.needs_arg or c.kind == "other":
            continue
        if c.kind == "script":
            if c.args[0] not in SAFE_SCRIPTS:
                continue
        out.append(c)
    return out


def hand_reason(row):
    if row.mode == "windowed":
        return "needs a window"
    if row.mode == "unstated":
        return "the row does not say headless"
    for c in row.commands:
        if c.needs_arg:
            return "needs an argument filled in"
        if c.kind != "godot" and c not in runnable(row):
            return "writes files or builds: not run by this tool"
    return "no command to run"


def row_commands_text(row):
    return " and ".join("`%s`" % c.text for c in row.commands) or row.cell1


def godot_argv(row, cmd, limit):
    flags = [f for f in cmd.flags]
    # re-join flag values (`--fixed-fps 60`) as written; add what the row says
    if row.fixed_fps and "--fixed-fps" not in flags:
        flags += ["--fixed-fps", row.fixed_fps]
    if "--headless" not in flags:
        flags = ["--headless"] + flags
    return ["bash", "tools/dev/godot.sh", "-t", str(limit)] + flags + ["--path", "tkg", "--"] + cmd.args


def time_limit(row, cap):
    base = 600
    if row.minutes:
        base = max(base, row.minutes * 60 * 3)
    return min(base, cap) if cap else base


def run_one(row, cmd, cap, outdir):
    limit = time_limit(row, cap)
    if cmd.kind == "script":
        script = cmd.args[0]
        if script.endswith(".py"):
            argv = [sys.executable] + cmd.args
        else:
            argv = ["bash"] + cmd.args
    else:
        argv = godot_argv(row, cmd, limit)
    log = os.path.join(outdir, re.sub(r"[^A-Za-z0-9]+", "_", cmd.text)[:60] + ".log")
    t0 = time.time()
    try:
        with open(log, "w") as fh:
            p = subprocess.run(argv, cwd=str(ROOT), stdout=fh, stderr=subprocess.STDOUT,
                               timeout=limit + 60)
        code = p.returncode
    except subprocess.TimeoutExpired:
        code = 124
    secs = int(time.time() - t0)
    text = open(log, errors="replace").read().splitlines()
    errs = [l for l in text if ERR_RE.search(l) and not LEAK_OK.search(l)]
    fails = [l for l in text if FAIL_RE.search(l)]
    label = re.escape(cmd.label)
    passes = [l for l in text if re.match(r"^(%s: PASS|=== PASS)" % label, l, re.I)]
    if not passes:
        passes = [l for l in text if re.match(r"^[A-Za-z0-9_ ]+: PASS\b", l)]
    measured = any("nothing judged" in l for l in text) or "MEASUREMENT" in row.cell2
    if cmd.kind == "script":
        ok = code == 0
        why = "exit %d" % code
    elif code == 124:
        ok, why = False, "still running after %ds, killed" % limit
    elif code != 0:
        ok, why = False, "godot exited %d" % code
    elif errs:
        ok, why = False, "%d error lines, first: %s" % (len(errs), errs[0].strip()[:100])
    elif fails:
        ok, why = False, "failing verdict: %s" % fails[0].strip()[:100]
    elif passes:
        ok, why = True, passes[0].strip()[:80]
    elif measured:
        ok, why = True, "measured, nothing judged"
    else:
        ok, why = False, "no PASS line printed"
    shown = "ok  " if ok else "FAIL"
    print("  %s %s (%ds): %s" % (shown, cmd.text, secs, why))
    if not ok:
        for l in (errs or fails or text[-8:])[:8]:
            print("        " + l)
        print("        log: " + log)
    return ok


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description="Which tests does this change need?")
    ap.add_argument("--base", default="main", help="compare with this commit (default main)")
    ap.add_argument("--head", default="HEAD", help="compare up to this commit (default HEAD; any other skips the working tree)")
    ap.add_argument("--staged", action="store_true", help="only what is staged for the next commit")
    ap.add_argument("--run", action="store_true", help="also run the headless rows")
    ap.add_argument("--list-all", action="store_true", help="list every row as this tool reads it")
    ap.add_argument("--max-secs", type=int, default=0, help="cap on one run's time limit (0: the row's own)")
    a = ap.parse_args()

    rows = parse_table()
    if a.list_all:
        for r in rows:
            run = "runs" if runnable(r) else "by hand"
            print("line %d  [%s, %s]  %s" % (r.line, tags(r), run, row_commands_text(r)[:150]))
        print("%d rows" % len(rows))
        return 0

    base = a.base
    if not a.staged and not ref_exists(base):
        for alt in ("origin/" + base,):
            if ref_exists(alt):
                base = alt
                break
        else:
            sys.stderr.write("tests_for: no commit called '%s' to compare with (use --base <commit>)\n" % a.base)
            return 2
    files = changed_files(base, a.staged, a.head)
    game = sorted(p for p in files if is_game_file(p))
    where = "staged" if a.staged else (
        "%s..HEAD plus the working tree" % base if a.head == "HEAD" else "%s..%s" % (base, a.head))
    print("tests_for: %d changed game files (%s)" % (len(game), where))
    if not game:
        print("  no game script or shader changed: no test row to run")
        return 0

    new_gd = [p for p in game if p.endswith(".gd") and files[p] == "A"]
    picked = []       # (row, cmd) in order, once each
    uncovered = []
    for path in game:
        funcs = changed_functions(base, a.staged, path, files[path], a.head) if path.endswith(".gd") else set()
        hits = []
        for r in rows:
            reasons = match_row(r, path, funcs)
            if reasons:
                hits.append((r, reasons))
        if path in new_gd:
            for r in rows:
                if any(c.label == "parseall" for c in r.commands) and r not in [h[0] for h in hits]:
                    hits.append((r, ["a new script: it must load"]))
        print("\n" + path + ("  (new)" if path in new_gd else ""))
        if not hits:
            print("  no test row covers this file: say so in the PR, or add a row to docs/tests.md")
            uncovered.append(path)
            continue
        for r, reasons in hits:
            hand = "" if runnable(r) else "  -> run by hand (%s)" % hand_reason(r)
            print("  %s  [%s]  %s%s" % (row_commands_text(r)[:110], tags(r), "; ".join(reasons), hand))
            for c in r.commands:
                if c in runnable(r) and c.text not in [x[1].text for x in picked]:
                    picked.append((r, c))
    if new_gd:
        cls = [p for p in new_gd if class_name_of(p)]
        if cls:
            print("\nA new class_name was added: run  bash tools/dev/godot.sh --headless --path tkg --import  first.")
    print("\n%d rows to run by machine, %d changed files with no row" % (len(picked), len(uncovered)))
    if not a.run:
        print("(add --run to run the headless ones; windowed rows are run by hand)")
        return 0
    if not picked:
        print("nothing headless to run")
        return 0
    if shutil.which("bash") is None:
        print("tests_for: bash not found: cannot run tools/dev/godot.sh")
        return 2
    outdir = tempfile.mkdtemp(prefix="tests_for_")
    print("\nrunning (logs in %s):" % outdir)
    bad = 0
    for r, c in picked:
        if not run_one(r, c, a.max_secs, outdir):
            bad += 1
    print("\ntests_for: %s" % ("PASS" if bad == 0 else "FAIL (%d of %d runs)" % (bad, len(picked))))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
