The reasoning behind the Claude Code hooks (`.claude/settings.json`, `tools/dev/claude_hooks.sh` and `.py`, `tkg/tools/gdcheck.sh`) and the project skill `.claude/skills/finish-a-change`. Most code here is written by Jon's AI sessions, so the rules that matter have to reach the session at the moment it acts, not only sit in a file it may not reread.

## What each hook is for

- **Command guard** (PreToolUse on Bash, `bash-guard`). Blocks the two things the repo says never to do: starting Godot by hand (`godot`, `godot4`, `Godot`, `godot_console.exe`, `/Applications/Godot.app/...`, `$GODOT`, `open -a Godot`), and pushing to `main` or merging, rebasing or committing on `main` in the main checkout. It splits the command into its simple commands (`;`, `&&`, `||`, `|`, `&`, `$( )`, backticks, `bash -c "..."` and `eval`, skipping heredoc bodies and comments), drops `VAR=value`, `env`, `time`, `timeout N`, `nice`, `command`, and judges the program each one runs. `godot.sh`, `grep godot`, `command -v godot`, `GODOT=... validate.sh` and a path that merely contains "godot" pass. `godot --version` passes (it prints a line and exits). It warns, without blocking, on `git commit --no-verify` and on `--update` of a baseline (the PR must say why each ADDED line is a move, not new debt).
- **Edit hook, import** (PostToolUse on Write|Edit, `gdcheck.sh`). Compiles the project after a `.gd` edit. It now goes through `tools/dev/godot.sh` (same binary discovery and throwaway profile as every other run) instead of a bare `godot`, and needs no `jq`.
- **Edit hook, ratchets** (PostToolUse, `edit-ratchets`). After an edit to `tkg/scripts/**/*.gd`, runs `code_check`, `comment_check`, `code_graph` and `frame_check` side by side. NEW problems come back at once, in the tools' own words; FIXED and SHRANK lines are left out. Silent when clean.
- **Stop reminder** (Stop, `stop-nudge`). See below.
- **The skill** `finish-a-change`: the checklist, loaded when a session is finishing, committing or opening a PR.

## The contract relied on

Fetched 2026-11-13 from https://code.claude.com/docs/en/hooks and https://code.claude.com/docs/en/skills.

- stdin is JSON: `cwd`, `hook_event_name`; for a Bash call `tool_input.command`; for Write/Edit `tool_input.file_path` ("always absolute, with the platform's native separators, so backslashes on Windows") and `tool_response.filePath`.
- Exit 2 per event: "`PreToolUse` | Yes | Blocks the tool call"; "`PostToolUse` | No | Shows stderr to Claude; the tool already ran"; "`Stop` | Yes | Prevents Claude from stopping, continues the conversation".
- "A hook that blocks by exiting 2 routes the same way as "deny": Claude sees the stderr message as the denial reason."
- "Claude never sees stderr from a hook that exits 0." "To surface a warning to Claude from a `PostToolUse` ... hook, exit 2 instead." So a warning that must reach the assistant without blocking goes out as JSON on stdout, `hookSpecificOutput.additionalContext` ("Return `additionalContext` inside `hookSpecificOutput` alongside the event name"; the page lists PreToolUse among the events that take it, next to the tool result). Not seen live: see "What was not tested".
- Stop: "`stop_hook_active` ... is `true` when Claude Code is already continuing as a result of a stop hook. Check this value ... to avoid blocking on a condition that will never resolve." "Claude Code applies an 8-consecutive-continuation cap." `hookSpecificOutput.additionalContext` is "Non-error feedback for Claude. The conversation continues so Claude can act on it", through "the same loop protections".
- `matcher`: "Only letters, digits, `_`, `-`, spaces, `,`, and `|` | Exact string, or list of exact strings separated by `|`" so `Write|Edit` and `Bash` are exact tool names. `timeout`: "Seconds before canceling" (default 600 for a command). `statusMessage`: "Custom spinner message displayed while the hook runs". `${CLAUDE_PROJECT_DIR}`: "the project root where the session started". "When an event fires, its matching hooks run in parallel." (The import hook and the ratchet hook run together.)
- Skills: project skills live in `.claude/skills/<skill-name>/SKILL.md`; "Claude uses skills when relevant" from the `description`, which is "truncated at 1,536 characters", so the trigger moments go first.

## Why each fails open

A hook that stops work because a tool is missing is worse than no hook. Every path that cannot decide exits 0: no python (the launcher says nothing), no git, a payload it cannot parse, a ratchet that crashes or takes more than 12 s (one line on stderr, which Claude does not see on exit 0, but the debug log does), no Godot found, a Godot that exits with no error text. A bug in a hook shows as `claude_hooks ...: skipped (...)` and the edit or command goes ahead. A guard that blocks wrongly costs an unblocking round trip; a guard that is silent wrongly costs what it was there to stop, so the guard blocks what it can read and, when it cannot read a command with confidence (a quote or `$(` never closed, a heredoc without its end), judges the raw text for the two blocked things: a word that names Godot followed by an option, and a push to main or a merge.

### What the command guard does NOT catch

It is a seat belt for an assistant that means well, not a security boundary. It does not catch:

- a command run on another machine (`ssh host godot ...`, a container, a CI job);
- a copied or renamed binary (`cp Godot g; ./g --path tkg`, a symlink named something else);
- a command assembled at run time (`"$(printf 'go%s' dot)" ...`, a variable set from a file or another command, `eval` of a built string, a name read from the environment, indirection that spans more than one command line);
- a script file that starts Godot itself (`bash myscript.sh` where the script calls `godot`): only the command line is read, never the files it names;
- a main moved by a route the guard does not list: `git fetch origin x:main`, `git checkout -B main`, `git reset --hard` on main in the main checkout, `git push` through an alias or a wrapper script, a merge through the web page or a tool other than `gh`/`git`;
- anything in a language other than shell (`python -c "os.system(...)"`).

The guard tests the words of a command, so a message that mentions a blocked thing in a string passes, and an unusual spelling of a blocked thing can too. A session that goes round it on purpose will succeed.

## Why the Stop reminder is a hook, and why it cannot loop

The documented contract gives three guards, and the reminder uses all of them: it does nothing when `stop_hook_active` is true; it records the tree state it spoke about in `.git/<worktree>/tk-stop-nudged` and does not speak twice for one state (if it cannot write that file it stays silent); and Claude Code stops it itself after 8 continuations in a row. It also never fires when nothing needs it: `tools/dev/check.sh` writes `tk-check-ok` after a full pass (`--tests` marked), holding a versioned fingerprint (`v2:`, so an older stamp never matches) of `tkg tools .github .githooks .claude` in the working tree: the index entries of the tracked files plus a content hash of each changed or untracked file, with a file over 4 MB recorded by size and mtime instead of being read. It is computed with read-only git calls and writes no object (the first version ran `git add -A` on a copy of the index, which left a loose blob in the real object database for every changed file on every Stop). `check.sh` stamps only a run that parsed the scripts (no Godot: no stamp), and marks `--tests` only when the tests ran. The reminder fires only when those paths differ from `HEAD` (or HEAD's commit is under three hours old and touched them), no passing check holds this exact state, and, for a `tkg/` change, the pass was not a `--tests` pass. A note in `changes/` or `docs/` changes no hash. It speaks with `additionalContext`, not `decision: block`: the work continues as guidance, not as an error.

Known gap: a session that commits everything and runs no check is only caught within three hours of the commit, and a clean tree is never nudged. The pre-commit hook and the skill cover that case.

## How to turn one off

Remove its entry from `.claude/settings.json` (or put an override in `.claude/settings.local.json`, which is not tracked). One at a time: the Bash guard is the `PreToolUse` block, the ratchets and the import check are the two entries under `PostToolUse`, the reminder is `Stop`. `TK_GDCHECK=parseall` makes the import hook run `-- parseall` instead of `--import`.

## The import hook does not see syntax errors

Found while building this: on Godot 4.7.1 `--headless --import` printed nothing and exited 0 for a planted script with a syntax error (a new `class_name` file nothing loads), while `-- parseall` reported `SCRIPT ERROR: Parse Error: Expected parameter name.` for it. So the old hook, and this one by default, only catch what `--import` itself prints. `parseall` costs about 14 s against about 9 s here, and a new `class_name` needs an import first or it reports a false unknown class; that is why the default is unchanged. `check.sh` runs `parseall` anyway.

## Direct Godot starts that remain in the repo's own scripts

The guard sees the command a session types, not what a script does inside. These documented wrappers start Godot without `godot.sh`: `tkg/tools/bot.sh`, `coplay.sh`, `cofight.sh` (no isolation at all: the real profile), `cojoin.sh` (isolates with `APPDATA` and `XDG_DATA_HOME` only, which does not move `user://` on a Mac, where Godot reads `HOME`), `export.sh` (isolates its smoke run with `APPDATA` only, the same gap on a Mac), `.github/scripts/validate.sh` (isolates every unit with `HOME`, `XDG_DATA_HOME` and `APPDATA`, so it is sound). `tools/dev/godot_quiet.sh` is the gate's own wrapper under `env.sh`. These are not blocked (they are documented); they are the holes in the rule.

## gate_land.sh is not blocked

`gate_land.sh` runs `git merge` and `git push` inside the script. A PreToolUse hook sees only the command the assistant typed, `bash tools/dev/gate_land.sh ...`, whose program is `bash` and whose argument is a script path. The self-test runs it as a lookalike that must pass.

## The self-test must not inherit GIT_* variables

Inside a git hook, `GIT_DIR` and `GIT_INDEX_FILE` point at the real repository. The pre-commit hook runs the gate's static checks, the self-test among them, so the first version's `git init` and `git commit` in a temp directory acted on the real repository instead: an `init` commit, a `feature` branch, a registered worktree, and `core.bare = true` written into the shared `.git/config`. Every `git` call in `claude_hooks.py` (hooks and self-test) now drops all `GIT_*` variables first (`clean_env`), and the setup refuses to go on unless the temp directory is its own repository. If `git status` in the main checkout ever says "this operation must be run in a work tree", run `git config core.bare false` there.

## How to test them by hand

```bash
bash tools/dev/claude_hooks.sh --selftest        # all of them, no Godot, about 2 s; the gate runs it (unit_claudehooks)
echo '{"tool_name":"Bash","cwd":".","tool_input":{"command":"godot --path tkg"}}' | bash tools/dev/claude_hooks.sh bash-guard; echo "exit $?"
echo '{"tool_input":{"file_path":"'"$PWD"'/tkg/scripts/ui/Hud.gd"}}' | bash tools/dev/claude_hooks.sh edit-ratchets; echo "exit $?"
echo '{"cwd":"'"$PWD"'","stop_hook_active":false}' | bash tools/dev/claude_hooks.sh stop-nudge; echo "exit $?"
echo '{"tool_input":{"file_path":"'"$PWD"'/tkg/scripts/Main.gd"}}' | bash tkg/tools/gdcheck.sh; echo "exit $?"
```

## Which tree an edit hook runs in

Both edit hooks (the ratchets and `gdcheck.sh`) take the tree from the edited file's path: the part before `/tkg/scripts/`, so a session started in the main checkout checks the worktree it edits. That root is only accepted when it is the project directory (`$CLAUDE_PROJECT_DIR`) or a worktree `git worktree list` registers for it, compared after `realpath` (so `..` and symlinks lead nowhere else); a file elsewhere inside the project gets the project as its root, and any other path is skipped silently. Otherwise an edit to `/tmp/x/tkg/scripts/a.gd` would run `/tmp/x/tools/code_check.py`. The rule lives in `accepted_root` in `claude_hooks.py`; `gdcheck.sh` asks it through `claude_hooks.sh root-of PATH`. Windows-style paths are normalised and refused if they are not a registered tree; a path with `..` that leaves the tree is refused.

## What was not tested

Windows (Git Bash): the paths, `python` versus `python3`, and the WinGet console binary. A live Claude Code session firing each hook: the exit codes and JSON shapes follow the documentation above and are asserted by the self-test, but whether `additionalContext` from a PreToolUse or Stop hook is shown to the model exactly as documented was not seen end to end.
