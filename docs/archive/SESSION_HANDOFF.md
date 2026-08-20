# Three Kelvin — session handoff

Everything decided and built in the design session, in the order you'll need it.
Drop this in the repo root. `CLAUDE.md` is the short version Claude Code reads
automatically; this is the full narrative including *why*.

---

## What the game is

A pixel-art, turn-based roguelite where **your ship is your character and your modules are
your deck**. Chart an open procedural galaxy at your own pace, fight ships and megafauna in
telegraphed Slay-the-Spire-style combat, chase Diablo-style loot with rolled affixes.

*FTL's ship fantasy × Out There's lonely exploration × Slay the Spire's combat × Diablo's loot.*

**The name:** three kelvin is the temperature of the cosmic microwave background — the
universe's leftover warmth, three degrees above absolute zero. A heat-management game named
for the cold. (Vetted against Steam; no blocking collision. "Farlight" was the earlier pick
and is **dead** — Farlight Games is an active publisher with a battle royale. It survives as
in-fiction vocabulary: the farlight is the glow of the galactic core, and the run objective.)

### Design pillars

1. **The ship IS the character.** No crew management, ever. A neutral hull plus the modules
   you find define your build.
2. **Loot is the engine.** Frequent drops, seven rarity tiers, rolled affixes. Installing a
   module changes your combat deck.
3. **Greed is the clock.** No pursuing fleet. Danger and loot quality both climb coreward,
   and lateral travel is always cheap — so you choose when to descend. Every death is
   self-authored.
4. **Readable builds.** The ship sprite shows what you assembled.

---

## Design rulings — do not silently reverse these

| Ruling | Why |
|---|---|
| **Hulls have no manufacturer** — weight class × tier only, rolled stats, rolled perk | Build identity comes entirely from found parts; hull swapping stays a pure power decision |
| **Set bonuses are the class system** (3+ / 5+ modules from one maker) | Identity is assembled mid-run, not picked at the start. Every drop is a commitment-vs-flexibility question |
| **Charge fires automatically** when ready | Tension belongs in *when you start* charging, not a release button |
| **Overheat = predictable self-damage**, 1 hull per point over cap, no cliff, no cap on heat | Heat becomes a second health bar you can spend. Repairs cost scrap, so overheating burns money |
| **The deck only reshuffles at the start of your turn** | Without this, zero-cost draw cards loop forever once the discard recycles. Also makes deck size strategic |
| **Player attacks never miss; only enemies miss** (light hulls dodge) | Player-side miss RNG feels awful in a perfect-information game |
| **Ballistics run cold, energy weapons run hot** | Materials get a readable thermal language before you read numbers |
| **Ships use fixed intent loops; fauna use weighted random pools** | Machines are predictable, animals are not — worldbuilding through mechanics |
| **Bosses are hand-tuned, never danger-scaled** | A boss stat block in a random encounter is a run-killer. This was a real bug |
| **Enemy HP scales faster than damage** (0.20 vs 0.10 per tier) | Deeper fights should be longer, not one-shot lethal |
| **Lateral map travel is cheap and always available** | Farm a danger band before descending. This *is* the greed clock |
| **One currency: scrap** — repair, upgrade and purchase all compete | This is where the difficulty actually lives |
| **Core ship systems are baked into the hull, not hardpoints** | Engines/bridge/reactor/vents are hull identity; hull stats already cover reactor and dissipation |
| **Hardpoints are generic within slot type** | Named sockets (radar/heatsink) fracture loot pools and create dead drops |

### The single most important tuning rule

Simulation showed **individual fights are not the difficulty — the economy is.** A starter
deck beats a danger-5 Rustjaw Cutter for about nine hull. Runs end from cumulative attrition
against expensive repairs.

**So: raise station repair prices before touching enemy damage.** If repairs are cheap, heat
becomes decorative and the whole risk structure collapses.

---

## Systems

**Combat.** Slay the Spire grammar. Energy = reactor output, the only cost you pay. Heat is a
printed byproduct. Enemy intent is always telegraphed. Keywords: **Charge X** (auto-fires
after N turns), **Salvo** (bonus if not your first attack this turn), **Brace X** (armor that
persists but costs 1 heat/turn to hold), **Vent X**, **Overheat** (self-damage past cap).
Heavy hulls: big hand, big heat capacity, poor dissipation → burst rhythm. Light hulls: small
hand, fast dissipation, dodge → sustain rhythm.

**Hulls.** Weight class (Light/Medium/Heavy) × tier (C/B/A/S). Tier sets stat *ranges*; stats
roll within them, so a god-rolled B can rival a bad A. Each hull rolls one generic perk.
Mid-run hull swapping transfers modules.

**Manufacturers (7).** Korvan Heavy Works (*"It fires. Every time."* — ballistics + charged
ordnance; the starter kit), Solari Foundry (weaponised heat), The Dredge Combine (scrap
economy, sustain), Redline Shipyards (evasion, refits, contraband), Veyra Ateliers (thin
perfect deck), Cygnet Dynamics (drones), Calyx Systems (regeneration, adaptation).
Korvan/Solari mirror each other; Dredge/Redline mirror each other.

**Rarity ladder — top tiers are *sources*, not bigger numbers.** Common → Legendary are
manufactured. **Exotic** is grown/harvested (megafauna). **Artifact** is precursor relic tech,
brand-agnostic, rule-breaking. **Contraband is a tag, not a tier** — above-curve power plus
station-inspection risk.

**Map.** 8 layers, edge → core, procedural each run. Six region types, each answering a
different need: **Territory** (branded loot, makes set bonuses reachable by route choice),
**Cosmopolitan** (multi-brand markets you can shop deliberately; higher prices, lower rarity
ceiling, strict inspections), **Frontier** (thin random drops), **Lawless** (contraband, fences
with high-rarity stock, no inspections), **Migration Route** (fauna, exotic materials),
**Precursor Ruins** (artifacts). Fully lateral connectivity within layers.

---

## Repo layout

```
project.godot          Godot 4.3+, autoloads: Sig, DB, Run, Router
CLAUDE.md              short context Claude Code reads automatically
README.md              architecture + design rulings
.vscode/               tabs-for-gdscript, tasks, launch, extension recs
scripts/
  autoload/            Sig (signal bus) · Database (content) · RunState · Router
  data/                CardData, ModuleData, HullData, EnemyTemplate, IntentData,
                       AffixData, ManufacturerData
  systems/             Combat, CardResolver, DeckBuilder, LootGen, MapGen, EventTable
  ui/                  code-built screens + widgets, UITheme, ShipView (procedural),
                       ShipSprite (sprite compositor), EnemyArt, CardView, LogPanel
  sim/HeadlessSim.gd   balance simulator
shaders/heat.gdshader  cold-universe / warm-ship palette shift
tools/export_resources.gd   dump Database to .tres for inspector editing
art/
  ART_CONTRACT.md      the rules every sprite must follow
  PIXELLAB_WORKFLOW.md how to generate, incl. verified live findings
  ASSET_PIPELINE.md    generated sprites → working game assets
  pixelart.py          procedural sprite authoring (fallback + concept inputs)
  sprites/             PNGs incl. palette_three_kelvin.png
```

**Content is authored in `Database.gd`** as dictionaries, seeded into typed Resources at boot
— diffs cleanly, no editor round-trip. Run `tools/export_resources.gd` if you'd rather edit
`.tres` in the inspector. **UI is built in code**, one scene (`Main.tscn`). Systems emit on
`Sig`; UI listens. **Indentation is tabs.**

Currently implemented: galaxy generation, jumps and fuel, full combat (charge, salvo, brace,
heat, drones, riposte, adapt, pacify), loot with rolled affixes, install/scrap/swap, stations
with all services and inspections, 8 events, set bonuses for all 7 makers, procedural ship and
enemy art, headless simulator. **33 modules, 9 enemies, 3 hull frames, 10 affixes.**

Not yet: real art, audio, meta-progression, save/load.

**The scaffold has never been compiled** — it was written without a Godot binary. Expect
first-run parse errors. Likely offenders: typed-array assignment, inner-class type hints
(`MapGen.MapNode`), Control layout properties. Run the **"Check for script errors"** VS Code
task (`godot --headless --check-only --quit`) to batch through them fast.

---

## Balance simulator

```bash
godot --headless --path . -- sim runs=200
```

Plays complete runs with a competent-player model, reports win rate, jumps, kills, death
causes. **Healthy target: 40–55%.** Run it after any balance change.

This tool has already earned its keep. In the web prototype it found three real bugs — an
off-by-one in `mkMod`'s parameter list corrupting every drop roll, a `find()` that re-rolled
its random key on every element so it usually matched nothing, and an **infinite loop** where
zero-cost draw cards recycle forever once the discard reshuffles. It also found a structural
map flaw: a path through a layered graph only visits ~8 nodes, giving 3–4 fights per run when
a roguelite needs 15+. Widening the map and making lateral hops cheap took runs from 3.5 jumps
to 14.5 and win rate from 0% to 46%.

---

## Art direction

**Lush objects in a cold void.** Stardew Valley craft density, but lushness is *detail
density, not warmth*. The emptiness stays cold and lonely; everything in it is rendered with
care.

- **3/4 view**, camera tilted ~45°, vertical foreshortening ~0.6. Player ships nose **right**;
  enemies nose **left**.
- **Two-plane lighting is the most important rule.** Every raised object gets a bright top
  face, a darker front wall, and a bright lip between them.
- 3/4 breaks bilateral symmetry, so **hardpoints sit on the visible deck** in a far row and a
  near row. Draw far row first → near mounts occlude correctly for free.
- **The void is never flat black.** Deep indigo-to-black dithered gradients with nebula wash
  coloured per region. Cheapest richness available; gives regions colour signatures.
- **Warm colour only where something emits it** — reactor, thrusters, muzzle, vents, lit
  windows. Never ambient warmth. Heat glow reads because it's the only self-emitted warmth.
- Objects get portholes with one lit amber, grime streaks in two tones, scorch, stencilled
  hull numbers, contact shadows, greebles.
- Native ~640×360, integer scaling. Palette constants in `UITheme`.

**Lesson learned the hard way: detail hierarchy and rest areas beat detail density.** An
over-detailed pass was genuinely *worse* than the one before it — texture, greebles and thin
marks all competing at the same contrast, so the ship stopped reading as a shape. Keep texture
near-threshold, keep a few large focal elements, leave deliberate clean areas.

---

## Screen layout

**One continuous space scene, not split panels.** Your ship is always on the left; the right
side is whatever you're facing — enemy in combat, docking bay at a station, dead hull at a
derelict, illustration at an event. One nebula field behind both, UI overlaid with almost no
chrome. Below: a context strip (enemy intent / dock services / event choices) and your hand.

**Pending refactor:** the scaffold still has separate CombatScreen / StationScreen /
LootScreen / EventScreen. Consolidating into one `EncounterScreen` with a swappable right
panel is the first refactor to do — every screen added to the old structure is one you'll
have to merge later. The star chart stays its own full-screen view.

---

## Art generation (PixelLab MCP)

Server: `https://api.pixellab.ai/mcp`, HTTP transport, bearer token. **Requires Node.js** —
`npx` missing was the cause of a "Server disconnected" failure. Keep the token in the
environment, never in a tracked file, and rotate it if it leaks.

**Do NOT use `create_character`** — skeleton-rigged humanoid/quadruped pipeline. Ships are not
characters. Use: `create_image_pixflux` (1 gen, `init_image_url` img2img + `color_image_url`
forced palette — the iteration workhorse), `create_image_pro` (20–40 gen, `style_image_url` +
`style_copy`, max 512×512 — final quality), `inpaint_image` (fix one region, rest stays
pixel-identical), `edit_image` (same edit across several frames), `create_1_direction_object`
(modules/props, 256px cap), `animate_image` (vent flicker, engine flame), `create_ui_asset`,
`create_font`. Run `get_balance` first.

### Verified live findings

1. **Text-only prompts ignore orientation, perspective and palette.** A fully specified prompt
   produced a good-looking ship facing **left**, in oblique view, in warm white-grey — even
   with the palette passed in. `view`/`direction`/`shading`/`detail` really are "weakly
   guiding".
2. **`init_image` is the only reliable control.** At strength ~210–240 it preserved silhouette,
   nose-right orientation, deck/wall split, engine placement and mount layout. **Always pass
   an init image.**
3. **Dimensions must be divisible by 4.** Sprites are authored at 220×128, 260×156, 300×188.
4. **`init_image` must exactly match output size.**
5. **Base64 truncates around 2–3 KB.** 2083 bytes fine; 2862 corrupted; 4985 rejected.
   **Fix: commit `art/sprites/` to GitHub, pass raw.githubusercontent.com URLs.** This is the
   one unblocking step for full-size generation.
6. **Quality is good** — better than the procedural sprites. The problem was never quality,
   only control.
7. `init_image_strength` is **inverted**: higher preserves more (500 barely changes, 150 is a
   real edit).

### Asset plan

**Never generate a finished ship.** Generate **bare hulls with visible empty mount pads**,
plus **each module as its own transparent sprite** at the same angle and light direction, then
composite in Godot. Pass the approved hull as style reference for every module so angles agree.

Medium hull needs **9 pads**: 4 weapon (2 far row, 2 near row), 3 system (low blisters near the
wall lip), 2 utility (high — masts, dishes). C-tier only uses 3/2/1; tier rolls and the Spare
Bay perk can reach 4/3/2, and bare pads read as upgrade potential.

Roughly **90 generated assets** total. **Don't generate megafauna** (organic curves,
bioluminescence — commission) or **nebulae** (keep procedural).

`ShipSprite.gd` composites hull + module sprites at `HullData` anchor arrays, drives the heat
shader from `Run.heat / Run.heat_cap()`, and **falls back to procedural `ShipView`** when a
sprite is missing — so the game stays playable through a partial art migration.

---

## Do this next, in this order

1. **Get it compiling.** Unzip, open in Godot, run "Check for script errors", fix the parse
   errors. `git init` and commit the scaffold *before* changing anything.
2. **Play five runs** with placeholder art. Note what feels *unsatisfying*, not what's broken.
3. **Commit `art/sprites/`** to GitHub → get raw URLs.
4. **Generate one bare medium hull** with the 9 mount pads. Iterate on pixflux (1 gen each),
   finalise on pro. Approve it, overwrite `art/sprites/hull_medium_cold.png` — that file is
   the canonical style reference for everything after.
5. **Test `heat.gdshader`** on it. If it works, you skip 2× the hull assets.
6. **Wire `ShipSprite`** with that one hull, fallbacks everywhere else. **Play again.**
7. Only then: light and heavy hulls → Korvan module batch → enemies → station → card art.
8. Somewhere in here: the `EncounterScreen` consolidation.

Step 6 before step 7 is deliberate. Seeing one real hull in the running game will change your
mind about something, and it's far cheaper to change your mind before 90 assets exist.

**Resist adding content until the loop feels good.** 33 modules is plenty. A 34th module is
never the fix.
