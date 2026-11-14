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

A call is given an edge only when its receiver is known: none or `self` (the class and its bases);
a `class_name` or autoload (`Router.go()`); `(x as Board)._m()` or `Board.new()._m()`; or a variable
with a class declared where it is declared (`var b: Board`, `x := Board.new()`, `x = y as Board`,
`for x: Board in`, a typed parameter). A parameter belongs to its own function; a member
declaration to the file; a name typed two ways in one scope is dropped. An annotation counts only
in those positions, so `if ok: Board.show()` types nothing. Failing all that, a private `_name`
defined in exactly one GAME file resolves (marked UNIQUE; sim definitions are not counted).

Never resolved: a PUBLIC method on an untyped receiver (`a.resize()` would land on whatever class
defines `resize`; an earlier version did that and invented edges), and any receiver that is another
expression (`arr[i]._m()`, `f()._m()`, `a.b._m()`: not `self`, and only the unique-private rule
may name it). That under-reports; it never accuses. A call through a property chain such as
`zoom.lab._draw_life()` is therefore found only while that private name is unique.

An INFERRED key (found by name alone; `--report` says how many) can appear or vanish when another
game file adds or removes a method of the same name. Such a NEW is legitimate to `--update` with a
note in the PR; the check output says so on those lines.

A file depends on a class when its name appears as an identifier in code (comments, strings and
triple-quoted blocks stripped). Not a reference: `$Board`, `%Hints`, `Kind.Board` (a member access),
and any name the file declares itself (variable, constant, parameter, loop variable, inner class,
enum or enum member), which shadows the class in that file. Loading `res://...gd` and `extends`
count as well. Scenes and `project.godot` are read for the orphan census; `.godot/` never is.

## Self-test

`python3 tools/code_graph.py --selftest` builds a small synthetic tree in a temp folder (about
0.1 s) and asserts the exact facts: parameter scope, cast and `.new()` receivers, expression
receivers, a triple-quoted block, `$Name`, enum members and shadowing, same-named inner functions
and a property setter, `if cond: Class.call()`, a method name duplicated only in sim, and that the
check and report modes find the same facts. `unit_codegraph` runs it before the check.

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

569 scripts (the number `--update` prints). Baseline: 190 entries, 17 `layer` (1 game-to-sim: `BotPilot -> Policy`; 12 into ui,
nine from systems, one from net, two from data; 4 data into systems) and 173 `private` (17 of them rest on the unique-name guess). The
report: 1 orphan game file, 43 orphan game functions, 579 game-to-game private call sites on 129
methods (`PostingBoard` takes 300 of them, from the `Board*` painters), one 5-group set of cycles.
The check takes about 2 seconds; the report about 4.

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
