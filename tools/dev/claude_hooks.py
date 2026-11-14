#!/usr/bin/env python3
"""claude_hooks.py: the Claude Code hooks for Three Kelvin, one script that dispatches on the event.

Run through the launcher `tools/dev/claude_hooks.sh EVENT` (it finds a working python and fails open).

  bash-guard      PreToolUse on Bash: blocks a direct Godot start and a push or commit that skips the gate
  edit-ratchets   PostToolUse on Write|Edit of tkg/scripts/**/*.gd: the four static ratchets, NEW problems only
  stop-nudge      Stop: once per tree state, if code changed and no passing check.sh covers it
  stamp [--tests] record "check.sh passed on this tree" (check.sh calls it after a pass)
  root-of PATH    print the tree an edited file belongs to if it is the project or one of its worktrees (gdcheck.sh)
  --selftest      every hook against realistic payloads, no Godot (the gate runs it: unit_claudehooks)

The contract each hook relies on, and why each fails open: docs/why/claude_hooks.md.
Standard library only. Every path below that cannot decide exits 0: a hook must never stop work
because a tool is missing.
"""
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))          # the tree this script lives in
RATCHETS = ("code_check", "comment_check", "code_graph", "frame_check")
RATCHET_SECONDS = 12                                    # per tool; a slow disk is not a failure
STATE_PATHS = ("tkg", "tools", ".github", ".githooks", ".claude")
RECENT_COMMIT_SECONDS = 3 * 3600
WHY = "docs/why/claude_hooks.md"


# ------------------------------------------------------------------ small helpers

def clean_env():
    """The environment without any GIT_* variable. Inside a git hook (the pre-commit hook runs the gate's
    static checks, and the self-test among them) GIT_DIR and GIT_INDEX_FILE point at the REAL repository:
    a `git init` or `git commit` in a temp directory would then act on it. Never inherit them."""
    return dict((k, v) for k, v in os.environ.items() if not k.startswith("GIT_"))


def git(cwd, *args, **kw):
    """Run git in cwd; return stdout text, or None when git or the directory is missing."""
    env = clean_env()
    env.update(kw.get("env") or {})
    try:
        p = subprocess.run(["git"] + list(args), cwd=cwd, stdout=subprocess.PIPE,
                           stderr=subprocess.DEVNULL, env=env, timeout=20)
    except Exception:
        return None
    if p.returncode != 0:
        return None
    return p.stdout.decode("utf-8", "replace").strip()


def read_payload():
    try:
        data = json.loads(sys.stdin.read() or "{}")
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def base(path):
    return re.split(r"[\\/]", path.rstrip("/\\"))[-1]


# ------------------------------------------------------------------ the command parser

class Words(list):
    """One simple command's words, plus what the parser knows about its surroundings: `piped_from` (the command
    whose output it reads, when a single | came before it), `hdoc` (the text of a heredoc given to it) and
    `here` (the text of a here-string)."""
    piped_from = None
    hdoc = ""
    here = None


def heredoc_head(cmd, i):
    """For `<<[-]['"]WORD['"]` at cmd[i:]: (delimiter, strip tabs, quoted, index just past the word)."""
    n = len(cmd)
    j = i + 2
    strip = j < n and cmd[j] == "-"
    j += 1 if strip else 0
    while j < n and cmd[j] in " \t":
        j += 1
    k = j
    while k < n and cmd[k] not in " \t\n;&|)":
        k += 1
    word = cmd[j:k]
    return word.strip("'\""), strip, ("'" in word or '"' in word or "\\" in word), k


def read_heredoc(cmd, i, delim, strip):
    """(body text, index after the terminator line, found) for a heredoc whose body starts at cmd[i]."""
    n = len(cmd)
    body = []
    while i < n:
        j = cmd.find("\n", i)
        j = n if j < 0 else j
        line = cmd[i:j]
        i = j + 1
        if (line.strip("\t") if strip else line) == delim:
            return "\n".join(body), i, True
        body.append(line)
    return "\n".join(body), n, False


def split_commands(cmd, depth=0, info=None):
    """The simple commands in a shell command line, each a Words list (quotes removed).
    Splits on ; && || | & and newlines, skips # comments, and also returns the contents of $( ... ) and
    `...` as commands of their own. Heredoc bodies are kept on the command that owns them (Words.hdoc); an
    unquoted body's $( ) is returned as commands too. Not a full shell: enough to ask 'which program does
    each simple command run'. When something cannot be read with confidence (a quote or $( never closed, a
    heredoc without its terminator) info["unsure"] is set, and the caller judges the raw text as well."""
    info = {} if info is None else info
    cmds, words, cur = [], [], []
    inner = []
    i, n = 0, len(cmd)
    in_word = False
    heredocs = []                   # (delimiter, strip, quoted, index of the owning command)
    pipe_next = False
    here_next = None

    def unsure():
        info["unsure"] = True

    def end_word():
        nonlocal cur, in_word
        if in_word:
            words.append("".join(cur))
        cur, in_word = [], False

    def end_cmd():
        nonlocal words, pipe_next, here_next
        end_word()
        if words:
            w = Words(words)
            if pipe_next and cmds:
                w.piped_from = cmds[-1]
            w.here = here_next
            cmds.append(w)
            pipe_next, here_next = False, None
        words = []

    def matching(start):
        """Index just past the ) that closes the ( at start-1. Skips quoted strings, escapes, comments and
        heredoc bodies, so a stray ( in a message does not swallow the rest of the line. Unclosed: n, unsure."""
        d, j = 1, start
        pend = []
        while j < n:
            c = cmd[j]
            if c == "\\":
                j += 2
            elif c == "'":
                k = cmd.find("'", j + 1)
                if k < 0:
                    unsure(); return n
                j = k + 1
            elif c == '"':
                j += 1
                while j < n and cmd[j] != '"':
                    if cmd[j] == "\\":
                        j += 2
                    elif cmd.startswith("$(", j):
                        j = matching(j + 2)
                    elif cmd[j] == "`":
                        k = cmd.find("`", j + 1)
                        j = n if k < 0 else k + 1
                    else:
                        j += 1
                if j >= n:
                    unsure(); return n
                j += 1
            elif c == "`":
                k = cmd.find("`", j + 1)
                if k < 0:
                    unsure(); return n
                j = k + 1
            elif c == "#" and (j == start or cmd[j - 1] in " \t\n;&|("):
                while j < n and cmd[j] != "\n":
                    j += 1
            elif cmd.startswith("<<", j) and not cmd.startswith("<<<", j):
                delim, strip, _q, j = heredoc_head(cmd, j)
                pend.append((delim, strip))
            elif c == "\n" and pend:
                j += 1
                while pend:
                    delim, strip = pend.pop(0)
                    _b, j, found = read_heredoc(cmd, j, delim, strip)
                    if not found:
                        unsure()
            else:
                if c == "(":
                    d += 1
                elif c == ")":
                    d -= 1
                    if d == 0:
                        return j + 1
                j += 1
        unsure()
        return n

    while i < n:
        c = cmd[i]
        if c == "\\" and i + 1 < n:
            cur.append(cmd[i + 1]); in_word = True; i += 2; continue
        if c == "'":
            j = cmd.find("'", i + 1)
            if j < 0:
                unsure(); j = n
            cur.append(cmd[i + 1:j]); in_word = True; i = j + 1; continue
        if c == '"':
            j = i + 1
            while j < n and cmd[j] != '"':
                if cmd[j] == "\\" and j + 1 < n:
                    cur.append(cmd[j + 1]); j += 2; continue
                if cmd.startswith("$(", j):
                    k = matching(j + 2)
                    inner.append(cmd[j + 2:k - 1]); cur.append("$(...)"); j = k; continue
                if cmd[j] == "`":
                    k = cmd.find("`", j + 1)
                    if k < 0:
                        unsure(); k = n - 1
                    inner.append(cmd[j + 1:k]); cur.append("`...`"); j = k + 1; continue
                cur.append(cmd[j]); j += 1
            if j >= n:
                unsure()
            in_word = True; i = j + 1; continue
        if cmd.startswith("$(", i):
            k = matching(i + 2)
            inner.append(cmd[i + 2:k - 1]); cur.append("$(...)"); in_word = True; i = k; continue
        if c == "`":
            k = cmd.find("`", i + 1)
            if k < 0:
                unsure(); k = n - 1
            inner.append(cmd[i + 1:k]); cur.append("`...`"); in_word = True; i = k + 1; continue
        if c == "#" and not in_word:
            while i < n and cmd[i] != "\n":
                i += 1
            continue
        if c in " \t":
            end_word(); i += 1; continue
        if c == "\n":
            end_cmd(); i += 1
            while heredocs:
                delim, strip, quoted, owner = heredocs.pop(0)
                body, i, found = read_heredoc(cmd, i, delim, strip)
                if not found:
                    unsure()
                if owner < len(cmds):
                    cmds[owner].hdoc += body + "\n"
                if not quoted and depth < 4 and ("$(" in body or "`" in body):
                    # an unquoted heredoc expands $( ) and `...`: those run
                    inner_cmds = split_commands('"%s"' % body.replace('"', '\\"'), depth + 1, info)
                    cmds.extend(inner_cmds[1:])
            continue
        if cmd.startswith("<<", i) and not cmd.startswith("<<<", i):
            delim, strip, quoted, k = heredoc_head(cmd, i)
            heredocs.append((delim, strip, quoted, len(cmds)))
            cur.append(cmd[i:k]); in_word = True; i = k; continue
        if cmd.startswith("<<<", i):
            j = i + 3
            while j < n and cmd[j] in " \t":
                j += 1
            if j < n and cmd[j] in "'\"":
                q_ = cmd[j]
                k = j + 1
                while k < n and cmd[k] != q_:
                    k += 2 if (q_ == '"' and cmd[k] == "\\") else 1
                here_next = cmd[j + 1:k]
                i = k + 1 if k < n else n
                continue
            k = j
            while k < n and cmd[k] not in " \t\n;&|)":
                k += 1
            here_next = cmd[j:k]
            i = k
            continue
        if c in ";|(){}" or c == "&":
            if c == "&" and ((i > 0 and cmd[i - 1] in "<>") or (i + 1 < n and cmd[i + 1] == ">")):
                cur.append(c); in_word = True; i += 1; continue   # 2>&1 and &>file
            if c in "{}" and in_word:
                cur.append(c); i += 1; continue                     # ${VAR}, a{b,c}
            end_cmd()
            i += 1
            is_pipe = c == "|" and not (i < n and cmd[i] == "|")
            if c in "&|" and i < n and cmd[i] in "&|":
                i += 1
            if is_pipe and i < n and cmd[i] == "&":
                i += 1                                              # |&
            pipe_next = is_pipe
            continue
        cur.append(c); in_word = True; i += 1
    end_cmd()
    if depth < 4:
        for sub in inner:
            cmds.extend(split_commands(sub, depth + 1, info))
    return cmds


KEYWORDS = ("if", "then", "else", "elif", "do", "while", "until", "!", "time", "exec", "nohup", "setsid",
            "sudo", "builtin", "caffeinate", "stdbuf", "nice", "ionice")
SHELLS = ("bash", "sh", "zsh", "dash", "ksh")
ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*\+?=")


def strip_wrappers(words):
    """Drop leading VAR=value, env, time, timeout N, nice, command (not -v) ...: what is left starts at the
    program that really runs. Returns [] when nothing runs (e.g. `command -v godot`)."""
    w = list(words)
    for _ in range(12):
        while w and ASSIGN.match(w[0]):
            w.pop(0)
        if not w:
            return []
        b = base(w[0])
        if b in KEYWORDS:
            w.pop(0)
            while b in ("nice", "ionice", "stdbuf", "sudo") and w and w[0].startswith("-"):
                opt = w.pop(0)
                if opt in ("-n", "-c", "-u", "-g", "-e", "-i", "-o", "-p") and w:
                    w.pop(0)
            continue
        if b == "env":
            w.pop(0)
            while w and (w[0].startswith("-") or ASSIGN.match(w[0])):
                opt = w.pop(0)
                if opt in ("-u", "-C", "-S") and w:
                    w.pop(0)
            continue
        if b == "timeout":
            w.pop(0)
            while w and w[0].startswith("-"):
                opt = w.pop(0)
                if opt in ("-k", "-s", "--signal", "--kill-after") and w:
                    w.pop(0)
            if w:
                w.pop(0)                    # the duration
            continue
        if b in ("command", "type", "which", "whereis"):
            if b == "command" and len(w) > 1 and not w[1].startswith("-v") and not w[1].startswith("-V"):
                w.pop(0)
                continue
            return []                       # asking where a program is does not run it
        if b == "watch":
            w.pop(0)
            while w and w[0].startswith("-"):
                opt = w.pop(0)
                if opt in ("-n", "--interval") and w:
                    w.pop(0)
            continue
        if b == "xargs":
            w.pop(0)
            while w and w[0].startswith("-"):
                opt = w.pop(0)
                if opt in ("-I", "-n", "-L", "-P", "-d", "-E", "-s") and w:
                    w.pop(0)
            continue
        return w
    return w


GODOT_NAME = re.compile(r"^(godot(4|_?v?\d[\w.\-]*)?(_console|\.console|_mono|_headless)*|godot_v[\w.\-]*)$")
GODOT_VAR = re.compile(r"^\$\{?(TK_)?GODOT\w*(:?[-=+?][^}]*)?\}?$")
VAR_REF = re.compile(r"^\$\{?([A-Za-z_]\w*)(?::?[-=+?][^}]*)?\}?$")


def is_godot(prog):
    if GODOT_VAR.match(prog):
        return True
    if "Godot.app/Contents/MacOS/" in prog.replace("\\", "/"):
        return True
    name = base(prog).lower()
    if name.endswith(".exe"):
        name = name[:-4]
    return bool(GODOT_NAME.match(name))


def shell_c_script(words):
    """For `bash -c "..."` (also -lc, -ec): the script text; else None."""
    if not words or base(words[0]) not in SHELLS:
        return None
    for k in range(1, len(words) - 1):
        a = words[k]
        if re.match(r"^-[a-zA-Z]*c[a-zA-Z]*$", a):
            return words[k + 1]
        if not a.startswith("-"):
            return None
    return None


def q(words):
    return " ".join(shlex.quote(x) for x in words)


# ------------------------------------------------------------------ the command guard

class Verdict(object):
    def __init__(self):
        self.blocks, self.warns = [], []


def msg(what, why, instead):
    return "BLOCKED: %s Why: %s Run instead: %s" % (what, why, instead)


def godot_block(prog_words, whole):
    args = q(prog_words[1:] + ([] if "--path" in prog_words else ["--path", "tkg"]))
    return msg("`%s` starts the Godot binary directly." % whole[:90],
               "every Godot run goes through tools/dev/godot.sh or tools/dev/render.sh, so a throwaway profile is used "
               "and Jon's real saves and settings are never read or written (the first of the two rules in CLAUDE.md "
               "at the repo root; tools/dev/README.md, 'How we work').",
               "`bash tools/dev/godot.sh -t 300 %s` for a headless run (add `-C ../tk-wt/<name>` for a worktree), "
               "`bash tools/dev/render.sh ...` for a windowed one, `bash tools/dev/check.sh --tests` to run the tests "
               "a change needs. After a new class_name: `bash tools/dev/godot.sh --headless --path tkg --import`."
               % args.strip())


_BRANCH_CACHE = {}


def main_checkout_branch(cwd):
    """(branch, is_main_checkout) for the repo at cwd, or (None, False) when unknown. One git call, remembered."""
    if not cwd or not os.path.isdir(cwd):
        return None, False
    if cwd in _BRANCH_CACHE:
        return _BRANCH_CACHE[cwd]
    res = (None, False)
    out = git(cwd, "rev-parse", "--path-format=absolute", "--absolute-git-dir", "--git-common-dir")
    if out and len(out.split("\n")) == 2:
        gd, common = out.split("\n")
        try:
            with open(os.path.join(gd, "HEAD")) as fh:
                head = fh.read().strip()
            if head.startswith("ref: refs/heads/"):
                res = (head[len("ref: refs/heads/"):], os.path.realpath(gd) == os.path.realpath(common))
        except OSError:
            pass
    _BRANCH_CACHE[cwd] = res
    return res


def refspec_targets_main(spec, _unused=None):
    s = spec.lstrip("+")
    dst = s.split(":", 1)[1] if ":" in s else s
    if dst in ("main", "refs/heads/main"):
        return True
    return False


GIT_VALUE_OPTS = ("-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path")


MAIN_WHY = ("nothing reaches main except through tools/dev/gate_land.sh, one full gate at a time, and merging is the "
            "owner's call (the second of the two rules in CLAUDE.md at the repo root; tools/dev/README.md, 'How we work').")
MAIN_INSTEAD = ("hand the PR to Jon to merge, or land the branch with "
                "`bash tools/dev/gate_land.sh ../tk-wt/<name> <branch> <label>`.")


def judge_gh(words, v):
    """words start at `gh`: `gh pr merge` and `gh api .../merge` are merges into main."""
    w = words[1:]
    pos, skip = [], False
    for a in w:
        if skip:
            skip = False
        elif a in ("-R", "--repo", "--hostname"):
            skip = True
        elif not a.startswith("-"):
            pos.append(a)
    if pos[:2] == ["pr", "merge"] and not any(a in ("--help", "-h") for a in w):
        v.blocks.append(msg("`gh pr merge` merges into main.", MAIN_WHY, MAIN_INSTEAD))
    elif pos[:1] == ["api"] and any(re.search(r"/merges?(?:[/?]|$)|mergePullRequest", a) for a in w):
        v.blocks.append(msg("`gh api` call to a merge endpoint.", MAIN_WHY, MAIN_INSTEAD))


def judge_git(words, cwd, v):
    """words start at `git`. Applies the two block rules and the --no-verify warning."""
    w = words[1:]
    gcwd, k = cwd, 0
    while k < len(w) and w[k].startswith("-"):
        if w[k] == "-C" and k + 1 < len(w):
            gcwd = w[k + 1] if os.path.isabs(w[k + 1]) or not gcwd else os.path.join(gcwd, w[k + 1])
        k += 2 if w[k] in GIT_VALUE_OPTS else 1
    if k >= len(w):
        return
    sub, args = w[k], w[k + 1:]
    if sub == "push":
        pos, repo, skip = [], False, False
        for a in args:
            if skip:
                skip = False
            elif a in ("--repo", "-o", "--push-option", "--receive-pack", "--exec"):
                skip = True
                repo = repo or a == "--repo"
            elif a.startswith("--repo="):
                repo = True
            elif not a.startswith("-"):
                pos.append(a)
        specs = pos if repo else pos[1:]
        hit = None
        if specs:
            hit = next((s for s in specs if refspec_targets_main(s, None)), None)
            if not hit and any(s.split(":")[-1] == "HEAD" for s in specs):
                hit = next((s for s in specs if main_checkout_branch(gcwd)[0] == "main"), None)
        elif "--all" in args or "--mirror" in args:
            hit = "--all/--mirror"
        elif main_checkout_branch(gcwd)[0] == "main":
            hit = "(current branch)"
        if hit:
            v.blocks.append(msg("`git push` to main (%s)." % hit,
                                "nothing reaches main except through tools/dev/gate_land.sh, one full gate at a time "
                                "(the second of the two rules in CLAUDE.md at the repo root; tools/dev/README.md, 'How we work').",
                                "push your branch with `git push -u origin <branch>` and open a PR (`gh pr create`; "
                                "merging is the humans' call), or land it with "
                                "`bash tools/dev/gate_land.sh ../tk-wt/<name> <branch> <label>`; branches live in "
                                "worktrees under ../tk-wt/<name>."))
        return
    if sub == "update-ref":
        pos = [a for a in args if not a.startswith("-")]
        if pos and pos[0] in ("main", "refs/heads/main"):
            v.blocks.append(msg("`git update-ref` moves main.", MAIN_WHY, MAIN_INSTEAD))
        return
    if sub == "branch":
        flags = [a for a in args if a.startswith("-")]
        forceish = any(a in ("-f", "--force", "-M", "-m", "-D", "-d", "--delete", "--move") or
                       (re.match(r"^-[a-zA-Z]+$", a) and re.search(r"[fMmDd]", a)) for a in flags)
        pos = [a for a in args if not a.startswith("-")]
        if forceish and any(p in ("main", "refs/heads/main") for p in pos):
            v.blocks.append(msg("`git branch` forces, moves or deletes main.", MAIN_WHY, MAIN_INSTEAD))
        return
    if sub in ("merge", "rebase", "commit"):
        if sub in ("merge", "rebase") and any(a in ("--abort", "--continue", "--skip", "--quit", "--edit-todo") for a in args):
            return
        if sub == "commit":
            skip_val = False
            for a in args:
                if skip_val:
                    skip_val = False
                    continue
                if a in ("-m", "-F", "-C", "-c", "--message", "--file", "--author", "--date"):
                    skip_val = True
                    continue
                if a == "--no-verify" or (re.match(r"^-[a-zA-Z]+$", a) and "n" in a):
                    v.warns.append("WARNING: `git commit --no-verify` skips the pre-commit checks (.githooks/pre-commit "
                                   "runs tools/dev/check.sh --static). They exist to be run: fix what they print and commit "
                                   "again unless you must skip them, and if you skip, say so in your report. "
                                   "(docs/why/check.md#pre-commit)")
                    break
        branch, is_main = main_checkout_branch(gcwd)
        if branch == "main" and is_main:
            v.blocks.append(msg("`git %s` on branch main in the main checkout." % sub,
                                "main moves only by the gate: work and commits happen on a branch in a worktree, and "
                                "gate_land.sh fast-forwards main (tools/dev/README.md, 'How we work'; the second rule in "
                                "CLAUDE.md at the repo root).",
                                "`git worktree add ../tk-wt/<name> -b <branch> main`, work and commit there, then "
                                "`bash tools/dev/gate_land.sh ../tk-wt/<name> <branch> <label>`."))
        return


BASELINED = ("code_check.py", "code_graph.py", "frame_check.py", "tests_map_check.py")


RAW_CAND = re.compile(r"""(?:^|[\s;&|(`'"])([^\s;&|()`'"]+)\s+--?[A-Za-z]""")
RAW_PUSH = re.compile(r"\bgit\b[^;&|\n]*?\bpush\b[^;&|\n]*?(?<![\w./-])\+?(?:[\w./-]*:)?(?:refs/heads/)?main(?![\w./-])")
RAW_MERGE = re.compile(r"\bgh\b[^;&|\n]*\bpr\s+merge\b(?![^;&|\n]*(?:--help|\s-h\b))")


def judge_raw(text, cwd, v):
    """The text of a command that could not be parsed with confidence, judged conservatively for the two
    blocked things: a Godot binary as a command word (a word that names Godot, then an option), and a push to
    main (or a merge). More false alarms than the parser would give, never fewer; the parser's verdict on what
    it did read still applies."""
    for m in RAW_CAND.finditer(text):
        if is_godot(m.group(1)):
            blk = godot_block([m.group(1)], m.group(1))
            v.blocks.append(blk + " (The command could not be parsed with confidence, so its raw text was judged.)")
            break
    if RAW_PUSH.search(text):
        v.blocks.append(msg("`git push` to main (the command could not be parsed with confidence; raw text judged).", MAIN_WHY,
                            "push your branch with `git push -u origin <branch>` and open a PR, or " + MAIN_INSTEAD[3:]))
    if RAW_MERGE.search(text):
        v.blocks.append(msg("`gh pr merge` merges into main (raw text judged).", MAIN_WHY, MAIN_INSTEAD))


def new_scope():
    return {"var": {}, "alias": {}}


def record_assignments(words, scope):
    """One-line indirection: `x=godot`, `export x=godot`, `alias g=godot` are remembered for later commands."""
    w = list(words)
    if w and all(ASSIGN.match(a) for a in w):
        pairs = w
    elif w and base(w[0]) in ("export", "declare", "local", "readonly", "typeset"):
        pairs = [a for a in w[1:] if ASSIGN.match(a)]
    elif w and w[0] == "alias":
        for a in w[1:]:
            if "=" in a:
                k, val = a.split("=", 1)
                scope["alias"][k] = val
        return
    else:
        return
    for a in pairs:
        k, val = a.split("=", 1)
        if k.endswith("+"):
            continue
        scope["var"][k] = val


def resolve_prog(w, scope):
    """Replace a program word that is a remembered variable or alias with what it was set to."""
    for _ in range(3):
        if not w:
            return w
        m = VAR_REF.match(w[0])
        val = scope["var"].get(m.group(1)) if m else scope["alias"].get(w[0])
        if val is None:
            return w
        try:
            parts = shlex.split(val)
        except ValueError:
            parts = [val]
        w = strip_wrappers(parts + w[1:])
    return w


def stdin_scripts(words, w):
    """The texts a bare shell (`bash`, `bash -s`, `sh -`) would read: its here-string, its heredoc, and what a
    pipe feeds it from echo, printf or a heredoc'd cat."""
    if not w or base(w[0]) not in SHELLS:
        return []
    args, texts, k = list(w[1:]), [], 0
    rest = []
    while k < len(args):
        if args[k] == "<<<" and k + 1 < len(args):
            texts.append(args[k + 1]); k += 2; continue
        if args[k].startswith("<<<"):
            texts.append(args[k][3:])
        elif not args[k].startswith("<<"):
            rest.append(args[k])
        k += 1
    nonopt = [a for a in rest if not a.startswith("-") or a == "-"]
    if nonopt and "-s" not in rest and "-" not in rest:
        return texts + ([words.hdoc] if getattr(words, "hdoc", "") else [])   # runs a script file
    if getattr(words, "here", None):
        texts.append(words.here)
    if getattr(words, "hdoc", ""):
        texts.append(words.hdoc)
    pf = getattr(words, "piped_from", None)
    if pf:
        pw = strip_wrappers(pf)
        if pw and base(pw[0]) in ("echo", "printf"):
            texts.append(" ".join(a for a in pw[1:] if not a.startswith("-")))
        if getattr(pf, "hdoc", ""):
            texts.append(pf.hdoc)
        if getattr(pf, "here", None):
            texts.append(pf.here)
    return texts


GODOT_QUIET = ("--headless", "--quiet")
INFO_FLAGS = ("--version", "-v", "--help", "-h")


def judge_simple(words, cwd, v, depth=0, scope=None):
    scope = scope if scope is not None else new_scope()
    w = resolve_prog(strip_wrappers(words), scope)
    if not w:
        return
    prog = w[0]
    for text in (stdin_scripts(words, w) if depth < 3 else []):
        judge_command(text, cwd, v, depth + 1)
    script = shell_c_script(w)
    if script is not None and depth < 3:
        judge_command(script, cwd, v, depth + 1)
        return
    if base(prog) == "eval" and depth < 3:
        judge_command(" ".join(w[1:]), cwd, v, depth + 1)
        return
    if " " in prog.strip() and depth < 3:
        judge_command(prog, cwd, v, depth + 1)      # a quoted command line given as the program: watch "godot ..."
        return
    if base(prog) == "find" and depth < 3:
        for k, a in enumerate(w):
            if a in ("-exec", "-execdir", "-ok", "-okdir"):
                sub = []
                for b in w[k + 1:]:
                    if b in (";", "+"):
                        break
                    sub.append(b)
                judge_simple(sub, cwd, v, depth + 1, scope)
        return
    if is_godot(prog):
        rest = [a for a in w[1:] if a not in GODOT_QUIET]
        if rest and all(a in INFO_FLAGS for a in rest):
            return              # prints a line and exits: no profile is touched
        v.blocks.append(godot_block(w, " ".join(w)))
        return
    if base(prog) == "open" and any(base(a).lower().startswith("godot") for a in w[1:]):
        v.blocks.append(godot_block(["godot"] + [a for a in w[1:] if not base(a).lower().startswith("godot")], " ".join(w)))
        return
    if base(prog) == "git":
        judge_git(w, cwd, v)
        return
    if base(prog) == "gh":
        judge_gh(w, v)
        return
    if "--update" in w[1:]:
        for a in w[:4]:
            if base(a) in BASELINED:
                v.warns.append("NOTE: `%s --update` rewrites a ratchet baseline. It is allowed for a file that was moved "
                               "or renamed, but the PR must say why each ADDED line is legitimate (a moved thing, not new "
                               "debt); to clear a NEW failure, fix the code instead. (docs/why/code_check.md; "
                               ".claude/skills/finish-a-change/SKILL.md)" % base(a))
                break


def judge_command(cmd, cwd, v, depth=0, scope=None):
    cur = cwd
    scope = scope if scope is not None else new_scope()
    info = {}
    for words in split_commands(cmd, info=info):
        if words and words[0] == "cd":
            tgt = words[1] if len(words) > 1 else None
            if tgt and not re.search(r"[$`~]|^-$", tgt) and cur:
                cur = tgt if os.path.isabs(tgt) else os.path.join(cur, tgt)
            else:
                cur = None
            continue
        judge_simple(words, cur, v, depth, scope)
        record_assignments(words, scope)
    if info.get("unsure"):
        judge_raw(cmd, cur, v)


def bash_guard(payload):
    """Returns (exit code, stdout text, stderr text)."""
    if payload.get("tool_name", "Bash") != "Bash":
        return 0, "", ""
    cmd = (payload.get("tool_input") or {}).get("command") or ""
    v = Verdict()
    judge_command(cmd, payload.get("cwd") or os.getcwd(), v)
    if v.blocks:
        return 2, "", "\n".join(v.blocks) + "\n"
    if v.warns:
        out = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": " ".join(v.warns)}}
        return 0, json.dumps(out), ""
    return 0, "", ""


# ------------------------------------------------------------------ the edit-time ratchets

def tree_of(path):
    """(root, relative path) when path is a tkg/scripts .gd file, else (None, None)."""
    p = path.replace("\\", "/")
    m = re.match(r"^(.*?)/?(tkg/scripts/.+\.gd)$", p)
    if not m:
        return None, None
    root = m.group(1) or "/"
    if re.match(r"^[A-Za-z]:$", root):
        root += "/"
    return root, m.group(2)


def _real(path):
    try:
        return os.path.normcase(os.path.realpath(path))
    except (OSError, ValueError):
        return None


def _inside(path, root):
    return path == root or path.startswith(root.rstrip("/\\") + os.sep)


def accepted_root(path, project=None):
    """(root, rel) for an edited file, or (None, None). The root is the file's own tree only when it is the
    project directory or one of this repository's worktrees (`git worktree list`, read-only, from the project
    directory), compared after realpath so `..` and symlinks cannot lead anywhere else; a file that is inside
    the project but not in the tkg/scripts layout gets the project as root and rel None. Anything else is
    refused: a path in /tmp/x/tkg/scripts must not make us run /tmp/x/tools/*.py."""
    project = project or os.environ.get("CLAUDE_PROJECT_DIR") or REPO
    proj = _real(project)
    if not proj or not path:
        return None, None
    drive = re.match(r"^[A-Za-z]:[\\/]", path)
    full = path if (os.path.isabs(path) or drive) else os.path.join(project, path)
    allowed = {proj}
    out = git(project, "worktree", "list", "--porcelain") or ""
    for line in out.splitlines():
        if line.startswith("worktree "):
            r = _real(line[9:])
            if r:
                allowed.add(r)
    root, rel = tree_of(full)
    if root:
        r = _real(root)
        if r in allowed and ".." not in rel.split("/") and _inside(_real(os.path.join(root, rel)) or "", r):
            return r, rel
    f = _real(full)
    if f and _inside(f, proj):
        return proj, None
    return None, None


NOISE = re.compile(r"^(FIXED |SHRANK |run python|[a-z ]+ (check|graph): (PASS|FAIL))")


def edit_ratchets(payload, project=None):
    ti = payload.get("tool_input") or {}
    path = ti.get("file_path") or (payload.get("tool_response") or {}).get("filePath") or ""
    root, rel = accepted_root(path, project)
    if not root or not rel:
        return 0, "", ""
    tools = [t for t in RATCHETS if os.path.isfile(os.path.join(root, "tools", t + ".py"))]
    if not tools:
        return 0, "", "claude_hooks: no tools/*.py ratchets under %s; skipped\n" % root
    procs = {}
    for t in tools:
        try:
            procs[t] = subprocess.Popen([sys.executable, os.path.join(root, "tools", t + ".py")], cwd=root,
                                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        except Exception:
            pass
    deadline = time.time() + RATCHET_SECONDS
    problems, notes = [], []
    for t in tools:
        p = procs.get(t)
        if p is None:
            notes.append("%s did not start" % t)
            continue
        try:
            out, _ = p.communicate(timeout=max(0.5, deadline - time.time()))
        except subprocess.TimeoutExpired:
            p.kill()
            p.communicate()
            notes.append("%s timed out" % t)
            continue
        text = out.decode("utf-8", "replace")
        if p.returncode == 0:
            continue
        lines = [l for l in text.splitlines() if l.strip() and not NOISE.match(l)]
        if p.returncode != 1 or not lines or "Traceback" in text:
            notes.append("%s crashed (exit %s)" % (t, p.returncode))
            continue
        problems.extend(lines)
    err = ("claude_hooks: edit-time ratchets skipped: %s\n" % "; ".join(notes)) if notes else ""
    if not problems:
        return 0, "", err
    body = ["A ratchet check failed after the edit to %s. New problems (fix them now, while the edit is fresh):" % rel]
    body += problems
    body += ["", "Fix the code. `--update` of a baseline is only for a thing that moved or was renamed, and the PR must say so.",
             "(tools/dev/claude_hooks.sh edit-ratchets; why: %s; what each message means: tkg/CLAUDE.md, 'Checks that will stop you')" % WHY]
    return 2, "", "\n".join(body) + "\n" + err


# ------------------------------------------------------------------ the stamp and the Stop nudge

STATE_VERSION = "v2"
HASH_CAP = 4 * 1024 * 1024      # a changed file over this is recorded by size and mtime, not read


def _file_mark(root, rel):
    """What identifies a changed or untracked file's content, computed here: nothing is written to git."""
    f = os.path.join(root, rel)
    try:
        if os.path.islink(f):
            return "link:" + os.readlink(f)
        st = os.stat(f)
        if st.st_size > HASH_CAP:
            return "big:%d:%d" % (st.st_size, st.st_mtime_ns)
        with open(f, "rb") as fh:
            return "sha1:" + hashlib.sha1(fh.read()).hexdigest()
    except OSError:
        return "gone"


def code_state(root, gd=None, with_head=False):
    """A fingerprint of the code paths in the working tree (ignored files left out), or None. Computed with
    read-only git calls and no object written: the index entries of the tracked files (`ls-files -s`), plus a
    content hash (or size and mtime, past HASH_CAP) of each file that differs from the index or is untracked.
    The old way ran `git add -A` on a copy of the index, which left a loose blob in the real object database
    for every changed file on every Stop. The string starts with STATE_VERSION, so a stamp from another
    scheme never matches. with_head=True returns (state, paths that differ from HEAD)."""
    gd = gd or git(root, "rev-parse", "--absolute-git-dir")
    if not gd:
        return None
    paths = [p for p in STATE_PATHS if os.path.isdir(os.path.join(root, p))]
    if not paths:
        return None
    staged = git(root, "--no-optional-locks", "ls-files", "-s", "--", *paths)
    changed = git(root, "--no-optional-locks", "ls-files", "-z", "-m", "-o", "--exclude-standard", "--", *paths)
    if staged is None or changed is None:
        return None
    files = sorted(set(f for f in changed.split("\0") if f))
    h = hashlib.sha1()
    h.update(staged.encode("utf-8", "replace"))
    for f in files:
        h.update(("\n%s\0%s" % (f, _file_mark(root, f))).encode("utf-8", "replace"))
    state = "%s:%s" % (STATE_VERSION, h.hexdigest())
    if not with_head:
        return state
    cached = git(root, "--no-optional-locks", "diff", "--cached", "--name-only", "-z", "HEAD", "--", *paths)
    if cached is None:      # no HEAD yet: everything tracked is new
        names = [l.split("\t", 1)[1] for l in staged.splitlines() if "\t" in l]
    else:
        names = [f for f in cached.split("\0") if f]
    tops = set(f.split("/")[0] for f in names + files)
    return state, [p for p in paths if p in tops]


def write_stamp(root, tests):
    gd = git(root, "rev-parse", "--absolute-git-dir")
    state = code_state(root, gd)
    f = os.path.join(gd, "tk-check-ok") if gd else None
    if not state or not f:
        return 0
    try:
        with open(f, "w") as fh:
            fh.write("%s\n%d\n" % (state, 1 if tests else 0))
    except OSError:
        pass
    return 0


def read_stamp(gd):
    f = os.path.join(gd, "tk-check-ok")
    try:
        with open(f) as fh:
            lines = fh.read().split("\n")
        return lines[0], lines[1] == "1"
    except Exception:
        return None, False


def stop_nudge(payload, now=None):
    """Silent unless code changed and no passing check.sh covers this exact tree, and then only once per
    tree state. Loop guards: stop_hook_active, the once-per-state file, and Claude Code's own cap of 8."""
    if payload.get("stop_hook_active"):
        return 0, "", ""
    cwd = payload.get("cwd") or os.getcwd()
    top = git(cwd, "rev-parse", "--show-toplevel", "--absolute-git-dir")
    if not top or len(top.split("\n")) != 2:
        return 0, "", ""
    root, gd = top.split("\n")
    if not os.path.isfile(os.path.join(root, "tools", "dev", "check.sh")):
        return 0, "", ""
    got = code_state(root, gd, with_head=True)
    if not got:
        return 0, "", ""
    state, differ = got
    recent = False
    if not differ:
        paths = [p for p in STATE_PATHS if os.path.isdir(os.path.join(root, p))]
        ct = git(root, "log", "-1", "--format=%ct")
        if ct and ct.isdigit() and (now or time.time()) - int(ct) < RECENT_COMMIT_SECONDS:
            recent = bool(git(root, "diff-tree", "--no-commit-id", "--name-only", "-r", "--root", "HEAD", "--", *paths))
        if not recent:
            return 0, "", ""
    needs_tests = recent or "tkg" in differ
    stamped, with_tests = read_stamp(gd)
    if stamped == state and (with_tests or not needs_tests):
        return 0, "", ""
    nudged = os.path.join(gd, "tk-stop-nudged")
    try:
        with open(nudged) as fh:
            if fh.read().strip() == state:
                return 0, "", ""
    except Exception:
        pass
    try:
        with open(nudged, "w") as fh:
            fh.write(state + "\n")
    except Exception:
        return 0, "", ""    # cannot record that we spoke: stay quiet rather than risk speaking twice
    text = ("Before you say this change is done: game code or tools changed and no passing check covers this exact state. "
            "Run `bash tools/dev/check.sh --tests`; add `changes/YYYY-MM-DD-what-changed.md` (one bold line) if a player "
            "would notice it; and in your final message list plainly what you could not verify (windowed rows, Windows, "
            "a real session). The checklist is .claude/skills/finish-a-change/SKILL.md. This reminder is shown once per "
            "state of the tree.")
    out = {"hookSpecificOutput": {"hookEventName": "Stop", "additionalContext": text}}
    return 0, json.dumps(out), ""


# ------------------------------------------------------------------ the self-test

GUARD_CASES = [
    # (command, expected: "block" | "warn" | "pass", key words that must be in the message, git setup)
    # must be blocked
    ("godot --headless --path tkg --import", "block", ["godot.sh", "profile"], None),
    ("cd tkg && godot --path . -- sim runs=10", "block", ["godot.sh"], None),
    ("godot4 --headless --path tkg -- parseall", "block", ["godot.sh"], None),
    ("/Applications/Godot.app/Contents/MacOS/Godot --path tkg", "block", ["godot.sh"], None),
    ("\"/c/Users/jon/AppData/Local/Microsoft/WinGet/Links/godot_console.exe\" --headless --path tkg", "block", ["godot.sh"], None),
    ("GODOT_FOO=1 timeout 60 godot --headless --path tkg --import", "block", ["godot.sh"], None),
    ("env HOME=/tmp time godot --path tkg", "block", ["godot.sh"], None),
    ("make build | tee log; Godot --headless --path tkg", "block", ["godot.sh"], None),
    ("bash -c \"cd tkg && godot --headless --import\"", "block", ["godot.sh"], None),
    ("$GODOT --headless --path tkg -- parseall", "block", ["godot.sh"], None),
    ("open -a Godot --args --path tkg", "block", ["godot.sh"], None),
    ("git push origin main", "block", ["gate_land.sh", "main"], "feature"),
    ("git push origin HEAD:main", "block", ["gate_land.sh"], "feature"),
    ("git push --force origin main", "block", ["gate_land.sh"], "feature"),
    ("git push", "block", ["gate_land.sh"], "main"),
    ("git -C ../tk-wt/x push origin +main", "block", ["gate_land.sh"], "feature"),
    ("git commit -m 'work'", "block", ["worktree", "gate_land.sh"], "main"),
    ("git merge feat/x", "block", ["worktree"], "main"),
    ("git rebase main", "block", ["worktree"], "main"),
    # closed in the review: indirection, wrappers, a stray ( in a heredoc, a shell fed by a pipe, merges
    ("git commit -m \"$(cat <<'EOF'\nfix (a\nEOF\n)\" && godot --path tkg", "block", ["godot.sh"], "feature"),
    ("${GODOT:-godot} --headless --path tkg", "block", ["godot.sh"], None),
    ("${GODOT} --headless --path tkg", "block", ["godot.sh"], None),
    ("find . -name '*.gd' -exec godot --headless --script {} \\;", "block", ["godot.sh"], None),
    ("watch -n1 godot --path tkg", "block", ["godot.sh"], None),
    ("echo \"godot --path tkg\" | bash", "block", ["godot.sh"], None),
    ("bash <<< \"godot --path tkg\"", "block", ["godot.sh"], None),
    ("bash <<'EOF'\ngodot --path tkg\nEOF", "block", ["godot.sh"], None),
    ("alias g=godot; g --path tkg", "block", ["godot.sh"], None),
    ("x=godot; $x --path tkg", "block", ["godot.sh"], None),
    ("echo \"unterminated; godot --path tkg", "block", ["godot.sh", "raw text"], None),
    ("echo \"unterminated; git push origin main", "block", ["gate_land.sh", "raw text"], "feature"),
    ("gh pr merge 12 --squash", "block", ["Jon", "gate_land.sh"], None),
    ("gh -R o/r pr merge 12", "block", ["Jon", "gate_land.sh"], None),
    ("gh api -X PUT repos/o/r/pulls/12/merge", "block", ["Jon", "gate_land.sh"], None),
    ("git update-ref refs/heads/main HEAD", "block", ["gate_land.sh"], "feature"),
    ("git branch -f main HEAD~1", "block", ["gate_land.sh"], "feature"),
    ("git push --repo=origin main", "block", ["gate_land.sh"], "feature"),
    ("git push --repo origin main", "block", ["gate_land.sh"], "feature"),
    # warned, not blocked
    ("git commit --no-verify -m wip", "warn", ["pre-commit"], "feature"),
    ("git commit -nm wip", "warn", ["pre-commit"], "feature"),
    ("python3 tools/code_check.py --update", "warn", ["ADDED", "baseline"], None),
    ("python tools/frame_check.py --update", "warn", ["baseline"], None),
    ("tools/code_graph.py --update && git add -A", "warn", ["baseline"], None),
    ("python3 tools/tests_map_check.py --update", "warn", ["baseline"], None),
    # lookalikes that must pass
    ("bash tools/dev/godot.sh --headless --path tkg --import", "pass", [], None),
    ("tools/dev/godot.sh -t 30 --headless --path tkg -- parseall", "pass", [], None),
    ("bash tools/dev/render.sh --path tkg -- ship shot=user://x.png", "pass", [], None),
    ("GODOT=/Applications/Godot.app/Contents/MacOS/Godot bash .github/scripts/validate.sh", "pass", [], None),
    ("GATE_STATIC=1 bash .github/scripts/validate.sh", "pass", [], None),
    ("bash tools/dev/check.sh --tests", "pass", [], None),
    ("bash tools/dev/gate_land.sh ../tk-wt/x feat/x label", "pass", [], "main"),
    ("grep godot tools/dev/env.sh", "pass", [], None),
    ("grep -rn 'godot --headless' docs | head", "pass", [], None),
    ("command -v godot || command -v godot4", "pass", [], None),
    ("which godot; type godot", "pass", [], None),
    ("ls /Applications/Godot.app/Contents/MacOS/", "pass", [], None),
    ("echo godot --headless --path tkg", "pass", [], None),
    ("git commit -m \"run godot --import before the tests\"", "pass", [], "feature"),
    ("cat <<'EOF' > note.txt\ngodot --headless --path tkg\nEOF", "pass", [], None),
    ("godot --version", "pass", [], None),
    ("pgrep -x Godot; pkill Godot", "pass", [], None),
    ("python3 tools/code_check.py", "pass", [], None),
    ("git push -u origin feat/x", "pass", [], "feature"),
    ("git push origin HEAD", "pass", [], "feature"),
    ("git push origin feature/main-menu", "pass", [], "feature"),
    ("git commit -m 'a change'", "pass", [], "feature"),
    ("git merge --abort", "pass", [], "main"),
    ("git log --oneline main..HEAD", "pass", [], "main"),
    ("bash tkg/tools/coplay.sh 2", "pass", [], None),
    ("ls tkg/scripts | grep -i godot", "pass", [], None),
    ("godot --headless --version", "pass", [], None),
    ("godot --headless --help", "pass", [], None),
    ("ssh host godot --headless --path tkg", "pass", [], None),       # a remote machine: documented, not guarded
    ("gh pr view 12", "pass", [], None),
    ("gh pr create --fill", "pass", [], None),
    ("gh pr checks 12", "pass", [], None),
    ("gh pr merge --help", "pass", [], None),
    ("gh api repos/o/r/pulls/12", "pass", [], None),
    ("git branch -f feature/x HEAD~1", "pass", [], "feature"),
    ("git branch --list main", "pass", [], "feature"),
    ("git update-ref refs/heads/feature/x HEAD", "pass", [], "feature"),
    ("find . -name '*godot*'", "pass", [], None),
    ("watch -n5 git status", "pass", [], None),
    ("x=godot.sh; bash tools/dev/$x", "pass", [], None),
    ("echo \"docs mention godot --path\" | tee notes.txt", "pass", [], None),
    ("echo \"godot --path tkg\" | grep godot", "pass", [], None),
    ("bash <<'EOF'\necho hello (not a command\nEOF", "pass", [], None),
    ("git commit -m \"$(cat <<'EOF'\nfix (a\nEOF\n)\"", "pass", [], "feature"),
    ("git push --repo=origin feature/main-menu", "pass", [], "feature"),
]


def _run(argv, cwd, env_extra=None):
    env = clean_env()
    env.update(env_extra or {})
    return subprocess.run(argv, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def _mk_git(tmp):
    """A main checkout on `main` and a worktree on `feature`. Returns (main_dir, worktree_dir)."""
    main, wt = os.path.join(tmp, "main"), os.path.join(tmp, "wt")
    os.makedirs(main)
    cfg = ["-c", "user.name=t", "-c", "user.email=t@t", "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgsign=false"]
    for argv in (["git", "init", "-q", "-b", "main"], ["git"] + cfg + ["commit", "-q", "--allow-empty", "-m", "init"],
                 ["git", "worktree", "add", "-q", wt, "-b", "feature"]):
        p = _run(argv, main)
        top = os.path.realpath(git(main, "rev-parse", "--show-toplevel") or "") if argv[1] == "init" else main
        if argv[1] == "init" and top != os.path.realpath(main):      # never go on in someone else's repository
            raise RuntimeError("selftest git setup: %s is not its own repository (%s)" % (main, top))
        if p.returncode != 0:
            raise RuntimeError("selftest git setup failed: %s" % p.stdout.decode("utf-8", "replace"))
    return main, wt


PLANT_LONG = "extends Node\n\n\nfunc long_one():\n" + "".join("\tvar v%d := %d\n" % (i, i) for i in range(120)) + "\tpass\n"
PLANT_COMMENT = "extends Node\n\n\nfunc ok():\n\tpass\n\n" + "".join("# line %d of an essay in a comment\n" % i for i in range(7)) + "func ok2():\n\tpass\n"
PLANT_FRAME = "extends Node\n\n\nfunc _process(_d):\n\tvar t = load(\"res://x.png\")\n\tprint(t)\n"
PLANT_LAYER = "class_name Planted\nextends Node\n\nvar pane: Pane\n"
PLANT_UI = "class_name Pane\nextends Node\n"
PLANT_CLEAN = "extends Node\n\n\nfunc fine():\n\tpass\n"


def _edit_tests(tmp, check):
    """The edit ratchets against a temp tree that has its own copies of the tools. Returns seconds spent."""
    tree = os.path.join(tmp, "tree")
    os.makedirs(os.path.join(tree, "tools"))
    os.makedirs(os.path.join(tree, "docs", "why"))
    for t in RATCHETS:
        shutil.copy(os.path.join(REPO, "tools", t + ".py"), os.path.join(tree, "tools"))
        b = os.path.join(REPO, "tools", t + "_baseline.txt")
        if os.path.isfile(b):
            shutil.copy(b, os.path.join(tree, "tools"))
    for sub in ("systems", "ui", "data"):
        os.makedirs(os.path.join(tree, "tkg", "scripts", sub))
    with open(os.path.join(tree, "tkg", "project.godot"), "w") as fh:
        fh.write("[autoload]\n")

    def edit(rel, text, name, want_code, words):
        f = os.path.join(tree, rel)
        with open(f, "w") as fh:
            fh.write(text)
        code, out, err = edit_ratchets({"hook_event_name": "PostToolUse", "tool_name": "Edit", "cwd": tree,
                                        "tool_input": {"file_path": f}, "tool_response": {"filePath": f}}, tree)
        check("edit  %s" % name, code == want_code and all(w in err for w in words)
              and "FIXED" not in err and "SHRANK" not in err, "exit %d: %s" % (code, err[:300]))
        os.remove(f)

    t0 = time.time()
    edit("tkg/scripts/systems/Planted.gd", PLANT_LONG, "a 120-line function is flagged", 2, ["long_one", "lines"])
    edit("tkg/scripts/systems/Planted.gd", PLANT_COMMENT, "a 7-line comment is flagged", 2, ["Planted.gd"])
    edit("tkg/scripts/systems/Planted.gd", PLANT_FRAME, "load( in _process is flagged", 2, ["_process", "load("])
    with open(os.path.join(tree, "tkg", "scripts", "ui", "Pane.gd"), "w") as fh:
        fh.write(PLANT_UI)
    edit("tkg/scripts/systems/Planted.gd", PLANT_LAYER, "a systems file naming a ui class is flagged", 2, ["Pane"])
    os.remove(os.path.join(tree, "tkg", "scripts", "ui", "Pane.gd"))
    edit("tkg/scripts/systems/Planted.gd", PLANT_CLEAN, "a clean file is silent", 0, [])
    for other in ("tkg/project.godot", "docs/why/x.md", "tools/code_check.py"):
        code, out, err = edit_ratchets({"tool_input": {"file_path": os.path.join(tree, other)}}, tree)
        check("edit  not a tkg/scripts .gd (%s) is silent" % other, code == 0 and not err)
    nowhere = os.path.join(tmp, "nowhere")
    os.makedirs(os.path.join(nowhere, "tkg", "scripts"))
    code, out, err = edit_ratchets({"tool_input": {"file_path": os.path.join(nowhere, "tkg", "scripts", "A.gd")}}, nowhere)
    check("edit  no ratchet tools present: fails open", code == 0)
    # a root that is neither the project nor one of its worktrees is refused: its tools are never run
    evil = os.path.join(tmp, "evil")
    os.makedirs(os.path.join(evil, "tools"))
    os.makedirs(os.path.join(evil, "tkg", "scripts"))
    mark = os.path.join(evil, "ran.txt")
    for t in RATCHETS:
        with open(os.path.join(evil, "tools", t + ".py"), "w") as fh:
            fh.write("open(%r, 'w').write('ran')\nprint('PLANTED problem')\nraise SystemExit(1)\n" % mark)
    ef = os.path.join(evil, "tkg", "scripts", "a.gd")
    for label, path in (("a layout-mimicking path under another directory", ef),
                        ("a path whose .. escapes the project", os.path.join(tree, "tkg", "..", "..", "evil", "tkg", "scripts", "a.gd")),
                        ("a path with .. after the layout", os.path.join(tree, "tkg", "scripts", "..", "..", "..", "evil", "x.gd"))):
        code, out, err = edit_ratchets({"tool_input": {"file_path": path}}, tree)
        check("edit  refused: %s" % label, code == 0 and not err and not os.path.exists(mark), "exit %d: %s" % (code, err[:200]))
    check("edit  refused: the same path is refused by root-of",
          accepted_root(ef, tree) == (None, None))
    check("edit  a Windows-style path does not crash and is refused",
          accepted_root("C:\\Users\\jon\\x\\tkg\\scripts\\A.gd", tree) == (None, None)
          and accepted_root("\\\\server\\share\\tkg\\scripts\\A.gd", tree)[1] is None)
    check("edit  accepted: the project's own tree", accepted_root(os.path.join(tree, "tkg", "scripts", "systems", "A.gd"), tree)[0] == _real(tree))
    # a tool that crashes must not block
    with open(os.path.join(tree, "tools", "frame_check.py"), "w") as fh:
        fh.write("raise SystemExit(7)\n")
    f = os.path.join(tree, "tkg", "scripts", "systems", "Planted.gd")
    with open(f, "w") as fh:
        fh.write(PLANT_CLEAN)
    code, out, err = edit_ratchets({"tool_input": {"file_path": f}}, tree)
    check("edit  a crashing ratchet fails open with one line", code == 0 and "frame_check crashed" in err)
    return time.time() - t0


def _stop_tests(wt, tmp, check):
    """The Stop nudge and the stamp, in a temp repo of its own (a git call costs 40 ms here, so it runs beside the others)."""
    _run(["git", "init", "-q", "-b", "main"], wt)
    top = git(wt, "rev-parse", "--show-toplevel")      # never go on in someone else's repository
    if not top or os.path.realpath(top) != os.path.realpath(wt):
        raise RuntimeError("selftest stop: %s is not its own repository (%s)" % (wt, top))
    # 3. the Stop nudge and the stamp, in the temp worktree
    os.makedirs(os.path.join(wt, "tools", "dev"))
    os.makedirs(os.path.join(wt, "tkg", "scripts"))
    with open(os.path.join(wt, "tools", "dev", "check.sh"), "w") as fh:
        fh.write("#!/bin/sh\n")
    with open(os.path.join(wt, "tkg", "scripts", "A.gd"), "w") as fh:
        fh.write(PLANT_CLEAN)
    old = {"cwd": wt, "hook_event_name": "Stop", "stop_hook_active": False}
    stop = lambda **kw: stop_nudge(dict(old, **kw))
    code, out, err = stop(stop_hook_active=True)
    check("stop  stop_hook_active is silent", code == 0 and not out)
    code, out, err = stop()
    check("stop  changed code, no stamp: nudges once", code == 0 and "check.sh --tests" in out and "changes/" in out, out)
    code, out, err = stop()
    check("stop  the same state again: silent (once per state)", code == 0 and not out)
    with open(os.path.join(wt, "tkg", "scripts", "A.gd"), "a") as fh:
        fh.write("\n# edited\n")
    code, out, err = stop()
    check("stop  a new state nudges again", code == 0 and "check.sh --tests" in out)
    write_stamp(wt, True)
    code, out, err = stop()
    check("stop  a passing check covers the state: silent", code == 0 and not out)
    with open(os.path.join(wt, "tkg", "scripts", "A.gd"), "a") as fh:
        fh.write("# edited again\n")
    write_stamp(wt, False)
    code, out, err = stop()
    check("stop  a check without --tests does not cover tkg changes", code == 0 and "check.sh --tests" in out)
    # the state is computed without writing a single object into the object database
    def loose():
        return sum(len(fs) for _d, _ds, fs in os.walk(os.path.join(wt, ".git", "objects")))
    with open(os.path.join(wt, "tools", "big.bin"), "wb") as fh:
        fh.write(b"x" * (1024 * 1024))
    before = loose()
    s1 = code_state(wt)
    for _ in range(5):
        stop()
    check("stop  the state is computed without writing git objects (a 1 MB untracked file present)",
          loose() == before and s1 and s1.startswith(STATE_VERSION + ":"), "%d -> %d" % (before, loose()))
    with open(os.path.join(wt, "tools", "big.bin"), "ab") as fh:
        fh.write(b"y")
    check("stop  a changed untracked file changes the state", code_state(wt) != s1)
    with open(os.path.join(wt, "tools", "huge.bin"), "wb") as fh:
        fh.truncate(HASH_CAP + 1)
    s2 = code_state(wt)
    os.utime(os.path.join(wt, "tools", "huge.bin"), (1, 1))
    check("stop  a file over the size cap is recorded by size and mtime, not read", s2 and code_state(wt) != s2)
    os.remove(os.path.join(wt, "tools", "huge.bin"))
    os.remove(os.path.join(wt, "tools", "big.bin"))
    write_stamp(wt, True)
    with open(os.path.join(wt, ".git", "tk-check-ok")) as fh:
        stamp_state = fh.readline().strip()
    with open(os.path.join(wt, ".git", "tk-check-ok"), "w") as fh:
        fh.write("0123456789abcdef,0123\n1\n")      # an old-format stamp
    check("stop  a stamp in an old format never matches", read_stamp(os.path.join(wt, ".git"))[0] != stamp_state)
    # a temp directory inside a repository would resolve to it: only run the case when it is outside any
    if git(tmp, "rev-parse", "--show-toplevel") is None:
        code, out, err = stop_nudge({"cwd": tmp})
        check("stop  not a git repo: silent", code == 0 and not out)
    else:
        print("  note  'not a git repo' case skipped: %s is inside a repository (TMPDIR?)" % tmp)


def _gdcheck_test(tmp, main, wt, check):
    """tkg/tools/gdcheck.sh imports the tree that holds the edited file (the project's or a registered worktree's),
    and quietly does nothing for any other directory. Godot is a stub that notes it ran, so nothing real starts."""
    bash = shutil.which("bash")
    if not bash:
        print("  note  gdcheck.sh cases skipped: no bash on this machine")
        return
    evil = os.path.join(tmp, "evil2")
    for tree, noisy in ((main, False), (wt, True), (evil, True)):
        d = os.path.join(tree, "tools", "dev")
        os.makedirs(d, exist_ok=True)
        os.makedirs(os.path.join(tree, "tkg", "scripts"), exist_ok=True)
        for name in ("claude_hooks.sh", "claude_hooks.py"):
            shutil.copy(os.path.join(HERE, name), d)
        with open(os.path.join(tree, "tkg", "project.godot"), "w") as fh:
            fh.write("[autoload]\n")
        with open(os.path.join(d, "env.sh"), "w") as fh:
            fh.write("GODOT=/bin/sh\n")
        with open(os.path.join(d, "godot.sh"), "w") as fh:
            fh.write('echo ran > "$(dirname "$0")/ran.txt"\n%s' % ('echo "SCRIPT ERROR: planted"\n' if noisy else ""))
    gd = os.path.join(REPO, "tkg", "tools", "gdcheck.sh")

    def run(tree):
        f = os.path.join(tree, "tkg", "scripts", "A.gd")
        payload = json.dumps({"tool_name": "Write", "tool_input": {"file_path": f}})
        p = subprocess.run([bash, gd], input=payload.encode(), cwd=main, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           env=dict(clean_env(), CLAUDE_PROJECT_DIR=main))
        return p.returncode, p.stderr.decode("utf-8", "replace")

    ran = lambda tree: os.path.exists(os.path.join(tree, "tools", "dev", "ran.txt"))
    code, err = run(wt)
    check("gdcheck  an edit in a registered worktree imports THAT tree, not the project's",
          code == 2 and "planted" in err and ran(wt) and not ran(main), "exit %d: %s" % (code, err[:200]))
    code, err = run(evil)
    check("gdcheck  an edit under an unrelated directory is skipped, its scripts never run",
          code == 0 and not err and not ran(evil), "exit %d: %s" % (code, err[:200]))
    code, err = run(main)
    check("gdcheck  an edit in the project itself runs the project's check", code == 0 and ran(main), "exit %d" % code)


def selftest():
    fails, rows = [], []

    def check(name, ok, detail=""):
        rows.append((name, ok))
        if not ok:
            fails.append("%s %s" % (name, detail))

    tmp = tempfile.mkdtemp(prefix="tk-hooks-selftest-")
    try:
        edit_rows, edit_secs = [], []
        th = threading.Thread(target=lambda: edit_secs.append(
            _edit_tests(tmp, lambda name, ok, detail="": (edit_rows.append((name, ok)),
                                                          None if ok else fails.append("%s %s" % (name, detail))))))
        th.start()
        stop_rows, sd = [], os.path.join(tmp, "stop")
        os.makedirs(sd)
        th2 = threading.Thread(target=lambda: _stop_tests(
            sd, tmp, lambda name, ok, detail="": (stop_rows.append((name, ok)),
                                                  None if ok else fails.append("%s %s" % (name, detail)))))
        th2.start()
        main, wt = _mk_git(tmp)
        # 1. the command guard
        for cmd, want, words, setup in GUARD_CASES:
            cwd = main if setup == "main" else wt if setup == "feature" else tmp
            code, out, err = bash_guard({"hook_event_name": "PreToolUse", "tool_name": "Bash", "cwd": cwd,
                                         "tool_input": {"command": cmd}})
            text = (out + err)
            got = "block" if code == 2 else "warn" if (code == 0 and out) else "pass"
            ok = got == want and all(w in text for w in words)
            if want == "block":
                ok = ok and "Why:" in err and "Run instead:" in err
            check("guard %-5s %s" % (want, cmd.split("\n")[0][:70]), ok, "got %s (exit %d): %s" % (got, code, text[:200]))
        # 2. (the edit ratchets run in their own thread: see _edit_tests)
        # 3. (the Stop nudge runs in its own thread: see _stop_tests)
        code, out, err = bash_guard({})
        check("guard  an empty payload is silent", code == 0 and not out)
        # a registered worktree is accepted (the main checkout is the project, the worktree another tree)
        check("edit  accepted: a registered worktree of the project",
              accepted_root(os.path.join(wt, "tkg", "scripts", "A.gd"), main)[0] == _real(wt))
        _gdcheck_test(tmp, main, wt, check)
        pt = _run([sys.executable, os.path.join(HERE, "tests_for.py"), "--selftest"], REPO)
        check("tests_for  engine flags outside the allowlist are never run", pt.returncode == 0,
              pt.stdout.decode("utf-8", "replace")[-300:])
        th.join()
        th2.join()
        rows[:0] = edit_rows
        rows.extend(stop_rows)
        edit_s = edit_secs[0] if edit_secs else 0.0
    except Exception as e:      # a selftest that cannot run is a failure, not a pass
        fails.append("selftest crashed: %r" % (e,))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for name, ok in rows:
        print("  %s  %s" % ("ok  " if ok else "FAIL", name))
    npass = sum(1 for _, ok in rows if ok)
    if fails:
        for f in fails:
            print("FAIL: %s" % f)
        print("claude_hooks selftest: FAIL (%d of %d)" % (len(fails), len(rows)))
        return 1
    print("claude_hooks selftest: PASS (%d checks; edit ratchets %.1f s)" % (npass, edit_s))
    return 0


# ------------------------------------------------------------------ dispatch

def main(argv):
    ev = argv[1] if len(argv) > 1 else ""
    if ev == "--selftest":
        return selftest()
    if ev == "root-of":
        root, _rel = accepted_root(argv[2] if len(argv) > 2 else "")
        if root:
            sys.stdout.write(root + "\n")
        return 0
    if ev == "stamp":
        return write_stamp(os.getcwd(), "--tests" in argv)
    if ev not in ("bash-guard", "edit-ratchets", "stop-nudge"):
        sys.stderr.write("usage: claude_hooks.sh bash-guard|edit-ratchets|stop-nudge|stamp [--tests]|root-of PATH|--selftest\n")
        return 0
    try:
        payload = read_payload()
        code, out, err = {"bash-guard": bash_guard, "edit-ratchets": edit_ratchets, "stop-nudge": stop_nudge}[ev](payload)
    except Exception as e:      # fail open: a bug in a hook never stops the work
        sys.stderr.write("claude_hooks %s: skipped (%r)\n" % (ev, e))
        return 0
    if out:
        sys.stdout.write(out + "\n")
    if err:
        sys.stderr.write(err)
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
