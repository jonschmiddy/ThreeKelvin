The reasoning behind `tools/code_graph.py`, the gate's layering ratchet and the cleanup report.

## What it is, and is not

It reads every script under `tkg/scripts`, works out which file depends on which and which
function calls which, and answers two questions. In the gate: did this change add a NEW link that
breaks the layering? On demand (`--report`): where is the code nothing uses, and where is it tied
in oddly? It is deterministic (no LLM, stdlib Python, two runs give the same bytes) and it is a
LEAD FINDER, not a verdict. GDScript is dynamic: a call by string, a `Callable` built from a name,
a scene's signal connection, `call_deferred("x")` all reach code the graph cannot see, so a report
row is a place to look, never proof that code is dead.

## What the gate ratchets

Keys are file paths and function names, never line numbers, so an edit elsewhere does not churn
`tools/code_graph_baseline.txt`. Two line formats:

- `layer <from> -> <to>`: a dependency (the class or autoload is named, the path is loaded, or it
  is extended). Three rules write it:
  - game code (anything not under `scripts/sim`) depending on a `scripts/sim` file. Sim is test
    code (tkg/CLAUDE.md: "sim = headless harnesses"); the game must not need it. Exempt:
    `scripts/DevFlags.gd` and `scripts/Main.gd`, whose job is to load harnesses.
  - `scripts/systems`, `scripts/data` or `scripts/net` depending on a `scripts/ui` file.
    "Systems never reach across scenes. They emit on `Sig`; UI listens." Data is plain resources.
    Rule chosen for the autoloads: project.godot's `[autoload]` list is read, and a target that
    is an autoload is NOT ui, wherever its file lives. `Hints` and `Ash` sit under `ui/` but are
    singletons anyone may use, so a link to them is not a link to a screen.
  - `scripts/data` depending on `scripts/systems` or `scripts/net` (data is plain resources).
  - NOT ratcheted: autoloads into `ui/`. Router legitimately opens screens. It is in the report.
- `private <def-file>::<_method> <- <caller-file>`: game code calling an underscore method of a
  different, unrelated class (not its base or subclass). The underscore says "mine"; the call says
  it is really part of the class's interface (drop the underscore) or the caller is doing the
  class's job. Engine callbacks (`_ready`, `_draw`, `_input`...) are not private methods. Calls
  from `scripts/sim` are not ratcheted (a test may poke a private) but are counted in the report.

## How a call is resolved

A call is given an edge only when its receiver is known: `self` or none (the class and its bases),
a `class_name` or autoload (`Router.go()`), a variable with a declared class (`var b: Board`,
`x := Board.new()`, a typed parameter, taken per function, dropped if one name is typed two
ways), or a private `_name` defined in exactly one file. A PUBLIC method on an untyped receiver
is never resolved by name: `a.resize()` would land on whatever class happens to define `resize`,
and an earlier version of this tool did exactly that and invented edges. So an untyped
`thing.public_call()` is invisible. That under-reports; it never accuses. The cost of the other
rule (unique private name) is a wrong edge if a private name is also an engine private; the
engine's virtuals are listed in `VIRTUAL`.

Comments are stripped with `tools/code_check.py`'s lexer and strings are blanked, so a class named
in a comment or a message is not a dependency. Scenes and `project.godot` are read for the
orphan census (a script a scene attaches is not an orphan); the `.godot/` cache never is.

## Reading the report (`--report`)

1. Orphan files: no script names, loads or extends them, no scene, not an autoload. Sim files
   also named nowhere in the gate or docs.
2. Game files only sim code references: kept alive by a test.
3. Orphan functions: defined, then never named in code, a string, or a scene. Conservative: a
   same-named function elsewhere hides a dead one.
4. Game functions only tests call: a test hook, or game code that lost its last caller.
5. Orphan constants, variables, signals, enums at the top level.
6. Bus signals on `Sig` that game code never emits or never hears.
7. Links against the layering: the ratcheted rules and the reported-only one, with file pairs.
8. Private methods called from another file, worst targets first.
9. Dependency cycles between game files: groups that all reach each other. A big one cannot be read
   or tested a file at a time.
10. Hubs: most depended on, and depending on the most.

Run `python3 tools/code_graph.py --report` before planning a refactor. With no path it writes
`three_kelvin_code_graph.md` in the temp folder and prints where.

## Measured on 67ec663e

570 scripts. Baseline: 185 entries, 17 `layer` (1 game-to-sim: `BotPilot -> Policy`; 12 into ui,
nine from systems, one from net, two from data; 4 data into systems) and 168 `private`. The
report: 1 orphan game file, 36 orphan game functions, 570 game-to-game private call sites on 121
methods (`PostingBoard` takes 300 of them, from the `Board*` painters), one 5-group set of cycles.
The check takes about 4 seconds; the report about 7.

## The baseline

A key that is gone is reported `FIXED` and does not fail, so two branches never fight over the
file. `--update` rewrites it and prints every ADDED key, so growth shows in the diff.

Updating is legitimate when you MOVED or RENAMED a file or method and the same link now has a new
name: say so in the PR. It is not legitimate when you added a reach-in: a rule asking a screen
for a colour, a data table calling a system. Fix that instead: emit on `Sig`, pass the value in,
or move the shared piece down a layer (a colour table belongs in data, not in `UITheme`).

## Looking at it

graphify has no GDScript parser; this tool is the extractor.
`python3 tools/code_graph.py --graphify /tmp/extract.json` writes nodes (files, functions), edges
(`contains`, `references`, `extends`, `imports`, `calls`, tagged EXTRACTED or INFERRED) and empty
hyperedges, in the shape graphify's `build_from_json` takes. Put it at
`graphify-out/.graphify_extract.json` in a working folder and run graphify's clustering and HTML
export from there (`/graphify` and its `--update` path, which skip extraction when that file is
fresh). Treat INFERRED edges as hints.
