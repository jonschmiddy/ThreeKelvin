# Three Kelvin — project context

Pixel-art turn-based roguelite. Godot 4.7.1, GDScript. Solo developer.
**Your ship is your character and your modules are your deck.**
*FTL's ship fantasy × Out There's exploration × Slay the Spire's combat × Diablo's loot.*

Named after the cosmic microwave background temperature — the universe's leftover
warmth, three degrees above absolute zero. A heat-management game named for the cold.

**This file is the index.** It was 1,120 lines and every one of them loaded into
every session, which is the wrong place for reference material: you need the rules
and the commands in context, and the screen-layout arithmetic only on the day you
touch a screen. The long half is `docs/handbook.md` and nothing was deleted in the
split.

| Read this | When |
|---|---|
| `docs/why/<FileStem>.md` | **Before changing code with a `Why:` pointer.** The reasoning moved out of that file's comments, verbatim, by heading |
| `docs/handbook.md` | Screen layout, art direction and generation, audio, the economy's internals, the two procedural engines, the manufacturer table, dev mode |
| `docs/design-doc.md` | What the game IS. Pillars, core loop, combat, loot, the setting |
| `docs/lore.md` | Who pays for all this, the rules for in-world paperwork, contracts |
| `docs/coop-design.md` | What four players do to each other |
| `docs/netcode.md` | How four machines are joined, and what each protocol bump bought |
| `docs/design-doc.md` §Pillar 5 | **Before calling a win-rate rise a regression.** The ceiling is meant to break; watch the death causes, not the win rate |
| `docs/building-a-manufacturer.md` | **Before writing a manufacturer's parts.** The sequence, the four gates to run, the six audit questions, and the traps that cost time on the first two manufacturers |
| `docs/catalogue.md` | **Before writing a module or a card.** The Grant Count Law, the Card Rarity Law, the reactor ladder, the shared library, and the six gates that stop a duplicate, a card named after a keyword, or a frame that launches without a deck |
| `docs/tests.md` | **Before finishing any change.** Which harness covers which code, and when to run it |
| `docs/rulings.md` | **Before contradicting a ruling below.** The reason behind each one |
| `docs/art/ART_CONTRACT.md` | Before generating any art |
| `audio/README.md` | Before touching a sound effect |
| `../music/CLAUDE.md` | **Before touching the music.** The lab HTML is the source; the oggs and the JSON are outputs. Run `music/tools/check_cue.mjs` and `check_lab.mjs` after any music change — `validate.sh` runs both |

---

## How to work in this repo

- **Talk like a person in chat.** Plain sentences. No headers, no tables, no bullet
  scaffolding, no bold every third word. Say the thing and stop. Condense — if it fits in
  four sentences, use four. Lead with the answer, then the reasoning only if it is actually
  needed, and do not restate the question first. Be direct about problems, tradeoffs and
  things that are broken; brevity is about format, not about hedging or leaving things out.
  Use structure only when the content really is structured — a measured comparison, a list
  of files, a table of numbers — and that should be rare.
  The design documents are the exception: they record what was measured and the
  reasoning behind a decision that was reversed.
- **Comments are one or two lines saying why.** The long reasoning (what was measured,
  what was tried and rejected, the bug it prevents, the date Jon ruled) goes in
  `docs/why/<FileStem>.md` under a heading, and the code keeps its short why plus a
  pointer: `# Why: docs/why/RunState.md#moving-ships`. Add to the existing heading when
  there is one. `tools/comment_check.py` (in the gate) fails a run of more than five
  comment lines and any pointer that does not resolve. Read the doc before changing
  code that points to it.
- **Development happens in VS Code.** Godot's editor is used only to run the game (F5),
  read the Output panel, and host the language server. Do not create or edit `.tscn`
  files unless there is no reasonable alternative.
- **UI is built in code**, not scenes. There are two scenes: `scenes/Shell.tscn`, the
  main scene (`ui/GameShell.gd`), and `scenes/Main.tscn`. Screens are `Control` subclasses that construct their own children against `UITheme`
  and `Widgets`.
- **Content is data, not code.** New modules, cards, enemies, hulls and affixes
  go in `scripts/autoload/Database.gd` as dictionary entries. `CardResolver`
  already handles every effect field on `CardData`, so a new card should require zero new
  logic. If you find yourself adding a `match` on card name, stop — add a field to
  `CardData` instead.
- **Systems never reach across scenes.** They emit on `Sig` (the signal bus autoload);
  UI listens.
- **Never call the global `randi()`/`randf()`/`pick_random()`/`shuffle()` for
  anything that decides something.** Draw from a named stream — `Rng.world`,
  `Rng.loot`, `Rng.event`, `Rng.foe`, `Rng.fight` — so that a run replays from
  its seed and one system's rolls cannot move another's. Anything a player can
  reach out of ORDER (a station's shelf, a wreck's contents, a station's job
  board, what is waiting at a node) uses `Rng.derive(tag, node.index)` instead, so
  it depends on WHERE it is rather than on when it was asked for. Cosmetic rolls —
  audio pitch, damage jitter, the title screen's galaxy — keep the global
  generator on purpose. `docs/why/Rng.md` has the reasoning; `-- rngtest` enforces it.
- **Indentation is tabs.** Godot requires it.
- **Static typing where practical** (`var x: int = 0`, typed arrays, `-> void`).
  Typed array assignment from literals often needs `arr.assign([...])` rather than
  `arr = [...]`.

---

## The shape of the code

Ten autoloads (`project.godot` [autoload]) and two scenes. Everything else hangs off
them. When the graph was last measured, the ten most connected things in the codebase
were the first six below plus `Combat`, `MapGen`, `Widgets` and `ShipView`:
`graphify-out/graph.json` holds the graph and `GRAPH_REPORT.md` its god nodes.

| Autoload | Holds |
|---|---|
| `Run` (`RunState`) | The run. Hull, hold, credits, heat, fuel, map, position, contracts, standing. A SINGLETON, so one process holds exactly one ship — which is why a co-op partner is a second process and why `Net` exists |
| `DB` (`Database`) | Every content table, seeded at boot. Modules, cards, hulls, enemies, affixes, manufacturers |
| `Rng` | Five named streams plus `derive()`. See the rule above |
| `Router` | Which screen is up, and what an arrival at a node means |
| `Sig` | The signal bus. Systems emit, UI listens |
| `Net` (`NetSession`) | The party. Inert in the solo game — no peer, no cost, until somebody hosts or joins |
| `Keys` | Every key a player can rebind, as InputMap actions with the labels Settings shows, saved in `settings.cfg` under [keys]. Screens ask for the action, never the keycode |
| `Audio` | Sound effects, the music cues and A.S.H.'s voice (`audio/README.md`, `../music/CLAUDE.md`) |
| `Hints` (`ui/Hints.gd`) | The first-run hints and the tutorial steps, each shown once at the moment it matters |
| `Ash` (`ui/Ash.gd`) | A.S.H., the ship's AI: when she speaks and which line (`docs/ash.md`) |

```
scripts/
  autoload/   Run, DB, Rng, Router, Sig, Audio, Keys  (Net is in net/, Hints and Ash in ui/)
  data/       plain resources — CardData, ModuleData, HullData, ShipBuild, ContractData
  systems/    rules, no UI — Combat, CardResolver, MapGen, Market, LootGen, SaveGame,
              Contracts, Unlocks
  net/        the party — NetSession, SharedFight, the transports, the bot
  ui/         one Control subclass per screen, built in code
  sim/        headless harnesses and contact sheets. Everything under `-- flag`
```

---

## Run and test

Every one of these is a claim somebody could not check by looking. The right-hand
column is the whole point: a harness you do not know when to run is a harness that
does not run.

```bash
godot                                          # then F5
godot --headless --path . --import             # REQUIRED after any new class_name,
                                               # and once on a fresh clone
.github/scripts/validate.sh                    # the merge gate, from the repo root:
                                               # ~10 min, six steps at once
GATE_JOBS=1 .github/scripts/validate.sh        # the same gate one step at a time (~45 min)
```

**The gate runs its steps side by side.** Each step is a `unit_<name>()` function in
`validate.sh`; `import` runs first and alone, then a pool of `GATE_JOBS` (default 6)
longest first, then the `SOLO_UNITS` one at a time: the steps that time something
against the wall clock, measure motion frame to frame without `--fixed-fps`, or race
threads (`maplagtest`, `gameclocktest`, `playerdeathtest`, `faunatest`,
`threadstress`, `lowhulltest`, `ashteachcosttest`, `flightclicks`, the sim). Every unit gets its own user folder (`APPDATA` on Windows,
`XDG_DATA_HOME`/`HOME` elsewhere), so user:// is never shared between steps and never
the real profile; output prints whole per step in file order, then each step's time and
every FAIL. A new gated harness is a new `unit_` function; if it times anything, it
goes in `SOLO_UNITS`.

Which harness covers which code is in `docs/tests.md`: one row per harness, with what
to run it after. Before you finish a change, grep it for the class, file or function you
touched and run every row that names it. The everyday ones:

```bash
tools/dev/godot.sh --headless --path tkg -- parseall       # every script parses
tools/dev/godot.sh --headless --path tkg -- sim runs=200   # any balance change, ~4 min
```

A new harness adds its row to `docs/tests.md`, and a `unit_` in `validate.sh` if it gates.

**Getting somewhere fast.** Every one is a flag rather than a menu item, because each
skips part of the run the balance depends on.

```bash
godot --path . -- nolauncher | resume | seed 12345
godot --path . -- ship | station | cards | fight 10 | fight foes=3
godot --path . -- salvage 8 [bag=4]            # the sector with a full hold, or a loot bag
godot --path . -- party 6                      # the party page against a fake roster
godot --path . -- quest                        # signs work and opens the chart on it
godot --path . -- lobby [host|join CODE] [auto] [relay ws://localhost:8787]
tools/coplay.sh [N]                            # N playable windows, one party
tools/bot.sh [CODE] [MAILBOX]                  # a ship nobody is sitting in front of
godot --path . -- <any of the above> shot=user://x.png   # photograph it and quit
```

**Why the sim boots normally.** It cannot run via `--script`: that flag replaces the
main loop and never creates the autoloads, so `Run` and `DB` fail to resolve at
compile time. `savetest` boots the same way.

**Why `savetest` scrambles the live state before loading.** Without it a field the
save forgot to serialise still matches, because the value was already sitting there.
A save system fails silently by nature — nothing crashes, the field comes back as a
default and the run continues around it looking almost right.

**Why `--import` is not optional.** Global `class_name` registration lives in
`.godot/global_script_class_cache.cfg`, which only `--import` writes. Without it
every `class_name` reports "Could not find type X in the current scope" — a wall of
errors from one cause, not many.

---

## Design rulings — do not silently reverse these

These were settled deliberately. Each has a reason. If a change would contradict one,
say so and ask rather than quietly working around it. The reasons are in `docs/rulings.md`.

- **Hulls ARE built by a manufacturer** — seven branded chassis, plus three unbranded salvage frames
- **Set bonuses are the class system** (3+ / 5+ modules from one manufacturer), **and the hull counts as one**
- **Korvan draws on the shared cards; the other six grant their own** (Jon, Oct 15)
- **You launch with one branded weapon and generic yard stock**
- **A gauge is the chassis PLUS everything bolted to it** — `Run.max_hp()`, `heat_cap()`, `dissipation()`, `dodge()`, `initiative()`, `fuel_factor()` all sum `installed`
- **`fuel_factor` cuts both ways, so no module carries it**
- **No module ever grants a malfunction**
- **Malfunctions are three keywords, not sixteen sentences**
- **Fused is the only malfunction keyword that COMPOUNDS**
- **`Run.dross` is WHICH malfunctions you carry, not how many**
- **A malfunction charges you at the END OF THE TURN, never on the draw**
- **Two verbs for losing a card, and they are two different sizes of decision**
- **A choice is an index, never a click**
- **A pending choice cannot outlive the turn that asked it**
- **A card belongs to the manufacturer of the part that granted it**
- **THE CARD RARITY LAW: cells decide what grades a module may grant**
- **Charge fires automatically** when ready
- **Overheat = predictable self-damage.** 1 hull per point over cap, at end of turn. No cliff, no shutdowns, no cap on heat
- **In-world paperwork is PRIMARY SOURCES, never exposition** — manifests, riders, receipts, transponder loops, and never a narrator
- **Heat does NOT gate loot.** Winning a fight pays the loot. Fleeing pays nothing. Heat's only job on the map is the residual you carry into the next jump — the ambush mechanic
- **The deck only reshuffles at the start of your turn**
- **Player attacks never miss. Only enemies miss** (light hulls dodge incoming fire)
- **Ballistics run cold; energy weapons run hot**
- **Ships use fixed intent loops; fauna use weighted random pools**
- **Bosses are hand-tuned, never danger-scaled**
- **The Custodian grows with `Run.jumps`, hull only, capped at twice its hull** (Jon, Nov 3, rule G3 with cap B)
- **The Custodian's badge is 9b, "The eye opens, loud"** (Jon, Nov 4: "Yeah, 9B like this"; https://claude.ai/artifact/6sMbQ25hJP3pimr93ro9rj)
- **Every station has all five decks, at every development level** (Jon, Nov 3)
- **Stations are rarer and spaced: half as many, none within a light hull's jump of another** (Jon, Nov 3, his pick S3)
- **Enemy HP scales faster than enemy damage** (0.10 vs 0.05 per danger tier)
- **Danger runs 1-10, but balance-sensitive tables read `MapGen.tier()`**
- **Lateral map travel is always available and cheap**
- **A place is three independent axes** — development, security 1-5, and who operates there
- **The galaxy is fifteen shells (`MapGen.LAYERS`), spaced so neighbours are near in every direction**
- **Fuel cost is chart distance; travel is anything within range**
- **Depth is not gated by shells** (it was: one shell at a time)
- **The Core is a supermassive black hole, not a settlement**
- **Galaxy *shape* is purely cosmetic**
- **Every arrival lands on the sector screen**
- **One currency: credits** — repair, upgrade, and purchase all compete for it
- **A station never pays more for a part than it charges for one**
- **The profit is in the distance between two places, not in one transaction**
- **A station's shelf is rolled once per run**
- **Prices are derived, never stored**
- **In a shared fight the host owns the ENEMY and nothing else**
- **Free-running turns with one barrier, NOT simultaneous lock-in**
- **The world agrees; anything paid to a PLAYER does not**
- **A contested LIST is claimed by slot, and the list must not shrink**
- **The sector strip draws who is HERE; the star chart draws everybody**
- **Materials are prerequisites, not a second currency** — and ALLOY failed that test and is gone
- **Heat capacity comes off a thermal module and nowhere else**
- **An AI crewmate is a PLAYER, not a service** — it joins by lobby code, takes a seat out of eight, and holds its own `Run`
- **The bot's brain is behind a file mailbox, and the shot clock is not optional**
- **One pilot model, two callers** — `Policy` is the simulator's competent player, and the bot flies it
- **A wingman follows the seats that arrived before it, and holding is a move**
- **A.S.H. is the ship, not crew** (Jon and Ashlee, Oct 17)
- **No crew management.** Ever
- **A system is consumed through `RunState.take_whole()` or `take_option()`, and nowhere else**
- **One suspend save, deleted the moment it is read**
- **Combat is outside the save.** Safe points are screen swaps outside a fight
- **Condition is DRAWN, not authored. A class is a SPECIFICATION, not a condition**
- **Generated art may not drift the palette, so damage is not generated**
- **A whale does not weld, and a hull does not scar**
- **The flight record unlocks MANUFACTURERS, and nothing else**

---

## The most important tuning rule

**Individual fights are not the difficulty — the economy is.** The Nov 3 study flew
enemy hull x4 (tk-scratch/hull-study/STUDY.md). In it, the human pilot on a fresh
Korvan profile beats a Rustjaw Cutter for about seven hull, in about nine turns. It
loses 4% of those fights, over every depth. The same study has harder fights. A lone Vex
Marauder is lost 60% of the time, a lone Dreg Hulk 35%, and a pack of two 63.5%.
Enemy fire causes 61% of that pilot's deaths (54% at x2). At x4, then, fights carry
more of the difficulty than this heading says. Runs still end from cumulative attrition.

**Measure before and after, at a fixed seed, and write the number down.** Every claim
in this file that turned out to be wrong was wrong because somebody asserted it once
and nobody re-derived it. Two worked examples, both of which reversed an earlier note:

- **Repairs are the lever for making the game HARDER, not easier.** Cutting
  `REPAIR_BASE` 40% moved the win rate 9.2% → 10.3% over 1,000 runs each — inside the
  noise — and hull deaths did not move. The player is not repair-limited; they are
  dying between stations.
- **What actually moved it was enemy scaling in `Combat._spawn()`.** Halving both
  multipliers took 9% to a measured 20.5 / 19.7 / 18.9 across three 1,000-run passes.
  Runs got longer rather than easier: 65 average jumps to 92.

**Neither hull loss nor fuel is half the deaths.** Re-measured 2026-10-17 on the
corrected sim (`-- sim runs=200 seed=777`, the gate pilot): of 192 deaths, events
86 (45%), fights 54 (28%), heat 51 (27%), a pulsar 1, a dry tank 0. With the 45
tank (Jon, Oct 17), 2 dry tanks (1%); the human pilot (`-- sim human`), 1 in 172.
The note this replaces said 56% of deaths were running the tank dry, measured
2026-08-21 on a sim that counted its pilot running out of charted links as a strand
and wandered whatever the tank said (`docs/briefs/SIM_INSTRUMENT_FIX.md`, 6b62c81).
Anybody reaching for "sustain decides the game" or "fuel decides the game" should
reach for the current number.

---

## Priorities

The flight record is the one thing that survives a dive, and it grants no power —
that is the shape meta-progression is allowed to take here and the reason it was safe
to build. See `Unlocks.gd`. (The archive of recovered documents was the second, until
it was cut on Oct 22.)

Open, in rough order: the `Run` singleton is still the largest single obstacle to
anything the host has to hold four of (`docs/netcode.md` §5); `PartyScale` is linear
with no ceiling and was measured at two to four, so an eight-player custodian is allowed
and untuned; and `_push_roster_to` sends the whole roster to everyone on every presence
change, which is O(n²) and invisible at four.
