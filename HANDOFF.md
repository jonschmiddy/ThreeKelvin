# Three Kelvin: handoff

For a new person or a new session picking up the project. Written 2026-10-20 and brought up
to 2026-10-21, when the first alpha sent out, **0.2.0-alpha.1**, goes to a playtester. If something here
disagrees with the code, the code is right; fix this file.

The writing guide for encounters that used to live in this file is now
[`docs/briefs/ENCOUNTER_OPTIONS_GUIDE.md`](docs/briefs/ENCOUNTER_OPTIONS_GUIDE.md).

---

## What the game is

A pixel-art, turn-based roguelite in Godot 4.7.1 (GDScript). Your ship is your
character and its modules are your deck. You fly from the rim of a generated
galaxy to its core, fight ships and creatures in card battles, loot modules,
refit, and manage heat, fuel and credits on the way. You win by destroying The
Custodian at the core.

- What it is and why: [`docs/design-doc.md`](docs/design-doc.md).
- Who works on it and how: Jon designs and rules on craft; playtesters rule on fun.
- What is in the current build: [`CHANGELOG.md`](CHANGELOG.md).

---

## Where things live

```
CHANGELOG.md         what each alpha build holds
HANDOFF.md           this file
README-ALPHA.txt     the player's first-launch notes; ships in the zips
LICENSES.txt         Godot and font licences; ships in the zips
play.bat / play.command   import, then launch the game from source
setup.sh             run once per clone: points git at .githooks/
docs/                every design and reference document (index: docs/README.md)
tkg/                 the Godot project
  CLAUDE.md          the working rules, the harness table and the rulings table
  project.godot      version string, autoloads, the main scene
  scenes/            Shell.tscn (the main scene) and Main.tscn; all UI is built in code
  scripts/autoload/  Run (RunState), DB (Database), Rng, Router, Sig, Audio, Keys
  scripts/data/      plain resources: CardData, ModuleData, HullData, AshLines, ...
  scripts/systems/   rules with no UI: Combat, CardResolver, MapGen, GalaxyGen,
                     OptionTable (the 135 encounters), Market, LootGen, SaveGame, ...
  scripts/net/       co-op: NetSession (the Net autoload), transports, SharedFight
  scripts/ui/        one Control per screen; Hints and Ash (both autoloads) live here
  scripts/sim/       headless harnesses and contact sheets, run as `-- <flag>`
  art/               sprites (hulls, modules, cards, enemies), stations, art tools
  assets/            audio (music, sfx, ambience, A.S.H.'s voice) and fonts
  audio/             the Python sound generators and their README
  tools/             export.sh, build_alpha.sh, cofight.sh, coplay.sh, bot.sh
music/               the music lab: one HTML page is the source of every cue
relay/               the co-op relay, a Cloudflare Durable Object worker
tools/               repo tools: encounter_lint.py, prose_grade.py, prose_tells.py,
                     and the art pipeline scripts (hulls, rooms, walkers, benches)
```

The ten autoloads are listed in `project.godot` and described in `tkg/CLAUDE.md`
("The shape of the code"). Content (modules, cards, hulls, enemies, affixes,
manufacturers, archive documents) is data in `tkg/scripts/autoload/Database.gd`.
Encounters are data in `tkg/scripts/systems/OptionTable.gd`.

---

## Run it

- **Play from source:** `play.bat` (Windows) or `play.command` (Mac). Both run
  `--import` and then launch `tkg`. Or open `tkg/project.godot` in Godot 4.7.1 and
  press F5.
- **After any new `class_name`, and once on a fresh clone:**
  `godot --headless --path tkg --import`.
- **Headless harnesses:** `godot --headless --path tkg -- <flag>`, for example
  `-- sim runs=200`, `-- parseall`, `-- holdtest`, `-- content`. Add
  `--audio-driver Dummy` so a harness does not take the sound device. The table in
  `tkg/CLAUDE.md` ("Run and test") says which harness to run after which change.
- **Developer mode** exists only in the editor. `-- asrelease` plays without it.

Exported builds keep their saves, settings and logs in their own folder
(`%APPDATA%\ThreeKelvinAlpha` on Windows, `~/Library/Application Support/ThreeKelvinAlpha`
on a Mac). Never point a harness or a test at that folder; `export.sh` points its
smoke test at a scratch one.

---

## Gate and land a change

1. Work on a branch in its own git worktree, never on `main` directly.
2. Merge `main` into the branch so the gate tests what will land.
3. Run the gate from the repo root: `.github/scripts/validate.sh`. Useful
   variables: `GODOT=<path to the console binary>`, `SIM_RUNS=<n>` (default 40),
   `LOG_DIR=<dir>`. It reads Godot's output rather than its exit code, because
   Godot exits 0 even when a script fails to compile. CI
   (`.github/workflows/validate.yml`) runs the same file on every pull request
   into `main` and on `main` itself.
4. On a pass, fast-forward `main` to the branch (`git merge --ff-only`) and push.

Run one gate at a time on a machine; two at once compete for the same resources
and fail each other. The gate runs its steps side by side: `GATE_JOBS` at once
(6, or the core count if lower), longest first, each with its own scratch user
folder, then the timing-sensitive steps alone. A full run takes about 10
minutes. `GATE_JOBS=1` runs them one after another, about 45 minutes.

The gate also checks the documents: a retired-words scan over `docs/` and
`tkg/*.md` (the company word is "manufacturer"), `prose_grade.py` and
`prose_tells.py` over the encounter text, and `encounter_lint.py --strict`.

---

## Build the alpha

From a clean tree:

```bash
GODOT=<path to godot_console.exe> tkg/tools/build_alpha.sh
```

It refuses a dirty tree, runs `tkg/tools/export.sh all` (release exports for
Windows and macOS, stamped with the version and commit, pack-checked and
smoke-tested), zips each platform with `README-ALPHA.txt` and `LICENSES.txt`, and
prints sizes and sha256 sums. The output goes to `builds/<version>-<commit>/`,
which is gitignored. The upload and the git tag are commented steps at the end of
the script, done by hand. It needs the Godot 4.7.1 export templates. The version
string is `config/version` in `tkg/project.godot`.

---

## Design rulings

The rulings that matter, and the reversals with their reasons, are the rulings
table in [`tkg/CLAUDE.md`](tkg/CLAUDE.md). Read it before changing how anything
plays. The rules for writing modules and cards are in
[`docs/catalogue.md`](docs/catalogue.md); the sequence for building a manufacturer
is [`docs/building-a-manufacturer.md`](docs/building-a-manufacturer.md); the rules
for encounter prose are [`docs/briefs/ENCOUNTER_COMMISSION.md`](docs/briefs/ENCOUNTER_COMMISSION.md)
§2 and [`docs/briefs/ENCOUNTER_PROSE.md`](docs/briefs/ENCOUNTER_PROSE.md).

---

## What is in 0.2.0-alpha.1

See [`CHANGELOG.md`](CHANGELOG.md). In short: a full run from rim to core, card
fights, 135 encounters, 24 hulls, 95 modules, stations, A.S.H. and the tutorial,
co-op for up to eight ships, Windows and Mac builds, and Settings > PLAYTEST >
SAVE MY LOGS for reports.

---

## Known issues

- **Only Korvan, Solari and unbranded parts drop** (`Database.ACTIVE_MANUFACTURERS`),
  and Solari's only once a Korvan win has unlocked it (`LootGen.can_appear`; a
  locked manufacturer's parts and hulls appear nowhere). The other five
  manufacturers can be unlocked and flown, but have 4 to 7 parts each, use
  Korvan's hull art, and their set bonuses cannot be completed.
- **Three set bonus texts are wrong** (Cygnet 5, Korvan 3, Solari 3; listed in
  `CHANGELOG.md`). Parked until after the alpha.
- **A fight is not saved.** Quitting mid-fight starts the fight again on CONTINUE.
- **`-- sheet=FieldEdgeTest`** reports a step of about 2.7 levels at the chart's
  bottom edge inside a cloud. It is not in the gate.
- **`-- charttest` can crash on a machine short of memory.** Rerun it with other
  programs closed before reading a crash as a bug.
- **Korvan heavy wins with the human pilot** (`-- sim human`) fell from 38% to 23%
  between Oct 17 and Oct 18, from merges that did not touch fuel. Flagged, not yet
  re-measured.
- **`art/tools/boxes.py` is broken** (its header says why). Do not run it.
- **`validate.sh` calls `warn`, which it never defines.** It only matters when no
  Python is found.
- Four tracked `.uid` files had no script beside them; this pass removed them.

---

## On branches, not merged

| Branch | What it holds |
| --- | --- |
| `fx/hits` | Hit and block effects: a pool of hit kinds, the bubble shield, three rounds of brace. Mockups and a partial build from Oct 13. |
| `fx/fauna-motion` | Idle motion for the Custodian, the calf and the Leviathan, with the bob on the motion's held steps (Oct 13). |
| `art/core-depth` | The galaxy as a 3D object: bodies of cloud, more parallax, the core in front. SIMPLIFIED only, not yet reading as volumes. Parked until after the alpha. |
| `ui/locked-hint` | Three looks for a locked manufacturer's tooltip. Jon kept look A, which is on `main`; this holds the other two. |
| `audit/nav` | `NavFilm`, a harness that films every move between the distances with real input, for the navigation audit. |

Also parked until after the alpha, with no branch yet: the set bonus texts.

Rejected work is kept as annotated tags, not branches: `archive/art/half-parts`,
`archive/fix/mount-points`, `archive/art/cloud-shapes` and the older `archive/*`
tags. `git show archive/<name>` says what each was.

---

## What is next

1. The first outside playtest, of 0.2.0-alpha.1 (0.1.0-alpha.1 was built and
   tagged but never sent). Ask for the zip from SAVE MY LOGS with every report.
2. **0.3.0-alpha.1** (built Oct 21): Jon's own polish on top of 0.2.0-alpha.1; see
   `CHANGELOG.md`. **0.3.1-alpha.1** the same night: the world you orbit drawn large,
   and two fixes. **0.3.2-alpha.1** after it: LOCAL does what GO does (no stand-in
   pictures), the LOCAL fly-in, the station waking with its power-on sound, and the hangar
   landing sound.
3. **0.4.0-alpha.1:** the fixes from that playtest. Add them under
   `[Unreleased]` in `CHANGELOG.md` as they land, then cut the version by changing
   `config/version` in `tkg/project.godot` and building with `build_alpha.sh`.
4. After that: the parked items above, and the five manufacturers still to write
   (`docs/catalogue.md` §17 has the count; `docs/building-a-manufacturer.md` the
   method).
