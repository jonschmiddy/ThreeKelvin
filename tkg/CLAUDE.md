# Three Kelvin — project context

Pixel-art turn-based roguelite. Godot 4.3+, GDScript. Solo developer.
**Your ship is your character and your modules are your deck.**
*FTL's ship fantasy × Out There's exploration × Slay the Spire's combat × Diablo's loot.*

Named after the cosmic microwave background temperature — the universe's leftover
warmth, three degrees above absolute zero. A heat-management game named for the cold.

---

## How to work in this repo

- **Development happens in VS Code.** Godot's editor is used only to run the game (F5),
  read the Output panel, and host the language server. Do not create or edit `.tscn`
  files unless there is no reasonable alternative.
- **UI is built in code**, not scenes. There is exactly one scene, `scenes/Main.tscn`.
  Screens are `Control` subclasses that construct their own children against `UITheme`
  and `Widgets`. Keep it that way — it avoids scene-merge conflicts and keeps styling
  in one place.
- **Content is data, not code.** New modules, cards, enemies, hulls and affixes go in
  `scripts/autoload/Database.gd` as dictionary entries. `CardResolver` already handles
  every effect field on `CardData`, so a new card should require zero new logic. If you
  find yourself adding a `match` on card name, stop — add a field to `CardData` instead.
- **Systems never reach across scenes.** They emit on `Sig` (the signal bus autoload);
  UI listens. Autoloads are `Sig`, `DB` (Database), `Run` (RunState), `Router`.
- **Indentation is tabs.** Godot requires it.
- **Static typing where practical** (`var x: int = 0`, typed arrays, `-> void`).
  Typed array assignment from literals often needs `arr.assign([...])` rather than
  `arr = [...]`.

## Run and test

```bash
# Play
godot                      # then F5, or run from the editor

# Balance simulation — RUN THIS AFTER ANY BALANCE CHANGE
godot --headless --path . -- sim runs=200      # ~4 min at 200 runs

# Dev shortcuts. Flags, not menu items, because each one skips part of the run
# the balance depends on.
godot --headless --path . -- attrs   # every chassis's six attributes, as a table
godot --path . -- ship               # straight to the refit screen
godot --path . -- cards              # every card in the game on one page
godot --path . -- fight 10           # straight into a fight, dealing 10 cards
godot --path . -- fight foes=3       # ...against a pack

# Rebuild the global class cache — REQUIRED after adding any new class_name,
# and required once on a fresh clone before anything will compile at all
godot --headless --path . --import
```

The sim boots the project normally and quits before building UI. It cannot run via
`--script`: that flag replaces the main loop and never creates the autoloads, so
`Run` and `DB` fail to resolve at compile time.

Global `class_name` registration lives in `.godot/global_script_class_cache.cfg`,
which only `--import` writes. Without it every `class_name` reports "Could not find
type X in the current scope" — a wall of errors from one cause, not many.

`HeadlessSim.gd` plays complete runs with a competent-player model and reports win
rate, jumps, kills, and death causes. Healthy target: **40–55% win rate**. This tool
has already paid for itself — in the earlier web prototype it caught three real bugs
(including an infinite draw loop) and a structural map flaw in minutes.

---

## Design rulings — do not silently reverse these

These were settled deliberately. Each has a reason. If a change would contradict one,
say so and ask rather than quietly working around it.

| Ruling | Reason |
|---|---|
| **Hulls ARE built by a manufacturer** — seven branded chassis, plus three unbranded salvage frames | REVERSED, deliberately. The old ruling was "hulls have no manufacturer", to keep hull swaps a pure power decision. It made `attributes-and-checks.md` §1.5 unimplementable: that section gives each maker an attribute signature, and every one of those (thermal capacity, dodge, hull mass) is a property of a chassis, not of a bolt-on module. The cost is real and accepted — swapping hulls now moves your set count |
| **Set bonuses are the class system** (3+ / 5+ modules from one maker), **and the hull counts as one** | Identity is now *leaned* at the start and still assembled mid-run. You pick a chassis, which starts you at 3+ with its own kit; the run is whether you push that to 5+ or diversify. Unbranded salvage frames count for nobody, so taking one is a real cost |
| **Charge fires automatically** when ready | Tension belongs in *when you start* charging, not in a release button |
| **Overheat = predictable self-damage.** 1 hull per point over cap, at end of turn. No cliff, no shutdowns, no cap on heat | Heat becomes a second health bar you can choose to spend. Repairs cost scrap, so overheating burns money |
| **The deck only reshuffles at the start of your turn** | Without this, zero-cost draw cards (Emergency Vent, Jury-Rig, Foresight) loop forever once the discard recycles. Also makes deck size strategically meaningful |
| **Player attacks never miss. Only enemies miss** (light hulls dodge incoming fire) | Player-side miss RNG feels terrible in a game built on perfect information |
| **Ballistics run cold; energy weapons run hot** | Gives materials a readable thermal language before you read any numbers |
| **Ships use fixed intent loops; fauna use weighted random pools** | Machines are predictable, animals are not. Worldbuilding through mechanics |
| **Bosses are hand-tuned, never danger-scaled** | A boss-grade stat block in a random encounter is a run-killer. This was a real bug once |
| **Enemy HP scales faster than enemy damage** (0.10 vs 0.05 per danger tier) | Deeper fights should be longer, not one-shot lethal. Halved when danger went 1-5 -> 1-10, so the top of the ladder sits where it always did |
| **Danger runs 1-10, but balance-sensitive tables read `MapGen.tier()`** | Enemy pools, loot rarity gates, hull tiers and station stock were calibrated against five tiers. Widening the *displayed* scale must not silently reweight every drop table |
| **Lateral map travel is always available and cheap** | You can farm a danger band before descending, so every death is self-authored. This *is* the greed clock |
| **A place is three independent axes** — development, security 1-5, and who operates there | One label could not say "rich city, no law". `Region` still exists but is *derived* from the axes in `_derive_region()`, because loot bias, fauna pools and station stock branch on it in five files |
| **The galaxy is nine shells, spaced so neighbours are near in every direction** | Twenty-four thin rings made a ring step 0.03 of the disc while a rim ring was 0.51 wide — a factor of seventeen, so nothing was near anything. Populations follow ring perimeter, which trades light-following density for a map you can navigate |
| **Fuel cost is chart distance; travel is anything within range** | A flat lateral/coreward rate made every jump cost 1 no matter how far it plainly was. Range covers your six nearest neighbours, so it self-scales from rim to core |
| **Depth is gated by shells** (you may only move one shell at a time) | Geometric necessity, not taste: ring spacing is tiny next to ring width, so an unrestricted distance rule lets you cross most of the galaxy in two hops |
| **The Core is a supermassive black hole, not a settlement** | Nobody develops or polices it. The social axes do not apply to the thing at the centre of a galaxy |
| **Galaxy *shape* is purely cosmetic** | Systems sit on shells and never consult the arms, which is what makes fifteen galaxy types in `GalaxyGen` cost nothing in balance |
| **Every arrival lands on the sector screen** | You should see a place before being asked to do anything with it. Station/event/salvage are reached *from* there, which is what finally retired `LootScreen` |
| **One currency: scrap** — repair, upgrade, and purchase all compete for it | This is where the difficulty actually lives |
| **No crew management.** Ever | The whole premise: ship systems, not little people running around |

## The most important tuning rule

Simulation showed **individual fights are not the difficulty — the economy is.** A
starter deck beats a danger-5 Rustjaw Cutter for about nine hull. Runs end from
cumulative attrition against expensive repairs.

**So: raise station repair prices before touching enemy damage.** If repairs are cheap,
heat becomes decorative and the entire risk structure collapses.

---

## Art direction

**Lush objects in a cold void.** Stardew Valley's craft density applied to space — but
lushness is *detail density, not warmth*. The emptiness stays cold and lonely;
everything in it is rendered with obsessive care.

- **Perspective: 3/4 view** (Stardew Valley register). Deck plane plus near-side wall,
  two-plane lighting. Hardpoints sit on the visible deck in a far row and a near row.
  Nose points right, toward whatever you are facing.
- **The void is never flat black.** Deep indigo-to-black dithered gradients with nebula
  wash coloured per region. Cheapest richness available, and it gives regions colour
  signatures (Korvan rusty amber, fauna teal bioluminescence, precursor violet).
- **Objects are lush.** Weathered plating, stencilled hull numbers, decals, lit viewports
  with interior detail, station windows with warm light and silhouettes inside, barnacles
  and scars on megafauna. Spend the pixel budget here.
- **Warm/cold is lighting logic, not a saturation cap.** Objects are richly coloured but
  coldly lit, with warm rim light from your own reactor. Heat glow reads because it is the
  only *self-emitted* warmth in frame.
- Native ~640×360, integer scaling. Ship sprites ~180–220px so detail has room.
- **Silhouette reads chassis; modules read faction.** Hull outline = weight class.
  Manufacturer identity = module shape language and palette accents.
- Melancholy comes from composition: small ship, vast frame, negative space, sparse
  animation with strong impact effects.
- Palette constants live in `UITheme`. Use them; never hardcode colours.

Sprites are currently generated procedurally in `scripts/ui/ShipView.gd` and
`EnemyArt.gd` (side-view — **this predates the top-down decision and needs replacing**).
When real art lands, use `Sprite2D` + mirrored `Marker2D` hardpoint anchors and drive
`shaders/heat.gdshader` with a `heat` uniform.

## Art generation — read `art/ART_CONTRACT.md` first

Pixel art is generated via the **PixelLab MCP server** (tool names may be bare or prefixed
`mcp__pixellab__*`). If those tools are not available, say so — do not fall back to curl or
the REST API. Full mechanics in `art/PIXELLAB_WORKFLOW.md`.

**Do NOT use `create_character` / `animate_character`** — that is a skeleton-rigged
humanoid/quadruped pipeline. Ships are not characters. Use instead:
`create_image_pixflux` (1 generation, has `init_image_url` img2img and `color_image_url`
forced palette — the iteration workhorse), `create_image_pro` (20–40 gen, `style_image_url`
+ `style_copy`, max 512×512 — final quality), `inpaint_image` (fix one region, leave the
rest pixel-identical), `edit_image` (same edit across several frames consistently),
`create_1_direction_object` (modules/props, `style_images`, 256px cap), `animate_image`
(vent flicker, engine flame), `create_ui_asset` (card frames, HUD), `create_font`.
Run `get_balance` before spending pro credits.

**Always pass an init image.** Live testing showed text-only prompts ignore orientation,
perspective and palette entirely — a fully specified prompt produced a left-facing oblique
ship in the wrong colours. Passing the reference as `init_image_url` at strength ~210-240
preserved silhouette, orientation, deck/wall split and mount layout. Sprite dimensions must
be divisible by 4, and `init_image` must exactly match the output size.

**Base64 truncates around 2-3 KB in practice** (2083 bytes fine, 2862 bytes corrupted,
4985 bytes rejected). Commit `art/sprites/` to GitHub and use raw.githubusercontent.com URLs
for anything full-size.

Pass `art/sprites/palette_three_kelvin.png` as `color_image_url` to force the game palette —
stronger than describing colours in text. Prefer image **URLs** over inline base64: MCP
clients truncate large base64 and corrupt the image. `init_image_strength` is inverted —
higher preserves more of the input (500 barely changes it, 150 is a real edit).

**Non-negotiable:** every generation passes `art/sprites/hull_medium_cold.png` as the
style/concept reference. Never generate a sprite from a bare text prompt — the result will
look fine alone and wrong beside everything else. There is exactly one canonical style
reference at a time; a newly approved hull replaces that file.

Hard rules, in short (full detail and the palette hexes are in `art/ART_CONTRACT.md`):

- **3/4 view** (Stardew register): camera tilted ~45°, deck plane plus near-side hull wall,
  vertical foreshortening ~0.6. Player ships nose **right**; enemies nose **left**.
- **Two-plane lighting is the most important rule**: every raised object gets a bright top
  face, a darker front wall, and a bright lip between them. This is what makes objects read
  as solid instead of as schematics.
- 3/4 breaks bilateral symmetry, so **hardpoints sit on the visible top deck** in a far row
  and a near row. Draw the far row first so near mounts occlude correctly. Plus one
  asymmetric detail — a perfectly regular ship reads dead.
- Lit from the top of the frame, cold and directional; weathering runs down the wall.
- **Warm colour only where something emits it** — reactor, thrusters, muzzle, vents, lit
  windows. Never ambient warmth. This is the game's whole visual thesis.
- Transparent background, no baked shadow, no anti-aliasing, ordered dithering only.
- Silhouette gets a 1px `#0b0f16` outline; interior detail is value contrast, not outlines.
- Stay inside the defined palette ramps.

Follow the generation order in the contract — hulls, then modules, then heat states, then
enemies, then station, then card illustrations. Each stage inherits style from the one
above, so skipping ahead produces drift.

**Card illustrations are per module, not per card.** Both Chatterbox cards share the
autocannon art. ~33 illustrations instead of ~50, and it strengthens the fiction.

**Do not generate megafauna or nebulae.** Whales and leviathans are organic — commission
or hand-draw them. Nebulae stay procedural (layered translucent masses, dithered edges,
coloured per region) — the chart's `_build_nebulae` is that rule implemented, and any
nebula elsewhere in the game should be built the same way rather than drawn as an asset.

`art/pixelart.py` authors sprites programmatically and still works — useful for geometric
variants and for producing concept inputs. It is the fallback, not the enemy.

## Audio — read `audio/README.md` before touching sound

All audio is **generated by Python in `audio/`** (numpy + scipy + soundfile),
never recorded or licensed. `python3 build.py` renders two music cues and
twenty-four sound effects and encodes them into `assets/audio/`. `audio/out/`
holds WAV intermediates and is gitignored; `audio/.gdignore` keeps Godot out of
the generator directory.

**Music is vertical, not horizontal.** A cue is not one file: it is eight or
nine stems that all start on the same sample, and *intensity* decides how many
you can hear. Nothing restarts when a fight begins — the arrangement opens up.
`Audio.music_state(&"sector")` is the whole API; `Audio.STATES` is the only
table that decides what a screen sounds like, so retuning the game's music
pacing is a one-file edit.

- **"Slow Drift"** — F minor, 142 BPM, the run. Chart, refit, station, sector,
  combat, all on one intensity ladder.
- **"Dead Sector"** — F Phrygian, 71 BPM, danger. Bosses, and any sector at
  danger ≥ 8.
- The two are an **exact 2:1 tempo lock** (one dread bar = two theme bars), so
  they crossfade without a tempo match. The mutation between them is a single
  flat, 2 → ♭2, over a common F pedal — which is why a sector turning dread
  reads as the *place* changing, not the music changing.

**Rules that are easy to break by accident:**

- **Stems must sum to the mix.** `synth.master()` prints every stem through the
  same bus as the mix, applying the soft clipper as a shared gain curve. If you
  add a stage to the bus, add it inside `master()` — a stage applied to the mix
  only silently puts the stems at the wrong level, and the game builds its mix
  out of stems.
- **Shipped cues render with `--loop`**: no fade-out, reverb tail wrapped over
  the head. A fade baked into a stem fades out mid-loop.
- **Sound sits in F minor.** Every pitched effect uses F, G, A♭, C, D♭, E♭, so a
  click landing under the score is consonant with whatever chord is running.
  Do not add an untuned beep.
- **Cold chrome, warm ship** — the audio half of the art direction. Interface
  sounds are dry, thin and quiet; only things that actually radiate (reactor,
  weapons, heat, hull) get a warm low body. Two design rulings are audible:
  ballistics crack dry and cold, energy weapons zap bright and hot; venting
  falls and resolves, overheating rises and bites.

**Wiring.** `Widgets._btn` is the one chokepoint every button in the game passes
through, so clicks, hovers and the refusal sound on a disabled button live
there. Everything else hangs off `Sig` in `Audio._connect_signals()` — one place
to read, one place to retune. `Router` names the screen state because it is the
only thing that knows which screen you are on.

Buses are `Master` → `Music` / `SFX` in `default_bus_layout.tres`. Volumes
persist to `user://settings.cfg` alongside the display settings; anything
writing that file must `cfg.load()` first or it drops the other section.

## Screen layout: one grammar for everything

**FTL two-panel split for every node type.** Your ship is always on the left; the right
panel is whatever you are facing — enemy in combat, docking bay at a station, dead hull at
a derelict, illustration at an event. Below the split: a context strip (enemy intent /
dock services / event choices) and your hand. Above: persistent HUD.

This replaces separate Combat/Station/Loot/Event screens with **one frame and swappable
right-hand content**. Less UI, less art, and the ship never disappears between fights so
it reads as a companion rather than a stat block. The star chart stays a separate
full-screen view.

**Status:** largely done. `SectorScreen` is the one frame — ship left, subject right, a
context strip that carries either the enemy intent or the location's single action — and
every arrival routes to it. `LootScreen` is gone; salvage resolves in place. Station and
event still swap to their own screens *from* the sector, which is the last piece.

### Settled: two-panel, in pixel art

The interface was designed out before implementation. Mockups and the full rule
set live in `art/ui/` — read `art/ui/README.md` before touching UI code.

Decided, do not silently reverse:

- **Pixel art UI on a 2px grid** — a 640x360 canvas drawn at 2x, with an 8px
  bitmap face used at 16px so type and chrome share one pixel density.
- **Integer scaling only.** 640x360 at 3x is exactly 1920x1080. Fractional
  scaling resamples glyphs and looks blurry.
- **Font antialiasing off**, texture filtering `Nearest`. This reverses a change
  made while the UI used a vector font; a bitmap face at integer scale must not
  be smoothed.
- **Heat and energy are countable boxes, not bars** — each box past the cap
  divider is one hull paid at end of turn.
- **Map nodes are icons plus region colour**, name in the detail panel. Labels
  under every node are why the build currently truncates `STATION` to `STATIO`.
- **SHIP and MAP buttons top-left on every screen**; Ship dimmed during combat.

Two other structures — a diegetic cockpit and a chart-primary layout — were
explored and rejected. Nothing was taken from them.

## Manufacturers (seven, each a playstyle)

`korvan` ballistics + charged ordnance (starter) · `solari` weaponised heat ·
`dredge` scrap economy and sustain · `redline` evasion, refits, contraband ·
`halcyon` thin perfect deck · `cygnet` drones · `calyx` regeneration and adaptation.

Korvan/Solari mirror each other (manage heat vs. surf it); Dredge/Redline mirror each
other (melt it down vs. repurpose it).

**Each one builds a chassis in all three weight classes**, and you pick both at run
start — manufacturer *and* light/medium/heavy. Two genuinely different questions: the
maker is who you are (which cards, which set bonus, which attribute signature), the
weight is how much ship (hull, hardpoints, hand size, evasion). Picking Redline does
not force a paper hull; it means a Redline heavy is the fastest heavy in the game.

The hull sets four of the six attributes and counts as one toward its own set bonus.
Three unbranded salvage frames still exist for hulls you find; they belong to nobody
and count for nobody, which is what keeps taking one a real cost.

**Hulls are authored as baseline + signature**, not as 21 stat blocks — `WEIGHT_BASE`
holds what a weight class is, `MAKER_HULLS` holds one row of deltas per maker. Writing
all 21 by hand would scatter each identity across three rows, so "what IS Solari" would
only be answerable by diffing tables, and a signature could drift between weights
unnoticed. Solari is `+8 heat cap, -1 dissipation, -2 stealth` on every frame it welds.
Starting kits install only what fits, so a light frame launches with fewer modules than
a heavy one carrying the same kit.

## Rarity ladder — top tiers are *sources*, not bigger numbers

Common → Legendary are manufactured. **Exotic** is grown/harvested (megafauna).
**Artifact** is precursor relic tech, brand-agnostic, rule-breaking.
**Contraband is a tag, not a tier** — above-curve power plus station-inspection risk.

---

## Current state

**Compiles and runs clean on Godot 4.7.1** (migrated from the original 4.3 target; the
migration required no code changes). `--check-only` and a headless boot both exit 0.
The predicted first-run failures — typed-array assignment, inner-class type hints
(`MapGen.MapNode`), `Control` layout properties — did not materialise; the only real
blocker was the missing class cache described above.

Balance sim: **13% win rate**, 56.0 avg jumps, 6.0 avg kills, 0 errors, at 200 runs.

That is a sixfold improvement and it was measured, not estimated. The same 200-run sim
against the commit *before* manufacturer hulls (`4f7f6ec`) scores **2%**, 32.2 jumps,
3.6 kills, 76% of deaths from hull loss. Two steps got it here, each measured:

| | wins | jumps | kills | hull deaths |
|---|---|---|---|---|
| `4f7f6ec` — one Korvan frame, six makers gated off | 2% | 32.2 | 3.6 | 76% |
| seven manufacturer hulls, `ACTIVE_MAKERS` reopened | 10% | 52.8 | 6.3 | 50% |
| all three weight classes per manufacturer | **13%** | 56.0 | 6.0 | 49% |

Runs last longer and get further. Fuel deaths rose with them (12% to 16%), which is
simply what more jumps cost.

Still well *below* the 40-55% band quoted above, and two things about that band need
saying before anyone tunes against it:

1. It was measured against an economy that double-paid scrap on charge kills. That bug is
   fixed, so the band has never been re-derived and is not currently a trustworthy target.
2. The most recent drop (39% -> 15%) is one fixed bug, not drift: the danger ramp divided
   by `LAYERS - 1`, which put the top tier on the Core alone — and the Core is a hand-tuned
   boss that is never danger-scaled. Regular fights capped one tier below the maximum for
   the whole game. They no longer do.

Fuel deaths sit around 3-10% depending on the ring layout; they were 83% for one iteration
when distance-based fuel landed before the economy was rescaled to match.

The map has changed shape substantially. `MapGen` now owns the galaxy's geometry
(`galaxy_pos`, `ring_radius`, `hop_distance`) because links AND fuel prices are derived
from position — the chart only scales it to the disc it draws. Two copies would mean
pricing a jump for a position nobody draws.

**Chart performance:** the star field is precomputed once per galaxy into packed arrays and
drawn on its own `CanvasItem`. Both matter. Re-deriving 40,000 stars per repaint cost
~150ms, and drawing them on the same canvas as the systems meant hovering a system
repainted the entire galaxy. Godot retains a CanvasItem's draw list until that item asks
to redraw — that is the whole optimisation.

**The galaxy holds more than stars.** Nebulae, dust lanes, globular clusters and supernova
remnants are built into those same packed arrays, so they cost a rect apiece and nothing to
derive. Three things about them are load-bearing:

- **`gas` in `GalaxyGen` decides how much of it there is.** Nebula count, dust lanes and
  remnants all scale off that one field, so an elliptical has none of it and a starburst is
  full of it. That absence is the point — it is what makes fifteen galaxy types read as
  fifteen different objects rather than fifteen spirals.
- **Order in `_build_stars` is the compositing order.** Nebulae go in before the arms so arm
  stars sit in front of the gas; dust lanes go in after, because a lane is made of the stars
  it hides. Moving either call breaks the depth.
- **Nebulae and lanes are never flagged `_star_dim`.** That tier is dropped mid-drag, which
  is invisible on a star and very visible on a coloured mass or a dark lane opening up.

Implemented: nine-shell galaxy with fifteen cosmetic galaxy types, three-axis places, jumps
and distance-priced fuel, full combat (charge, salvo, brace, heat, drones, riposte, adapt,
pacify), loot with rolled affixes, install/scrap/swap, stations with all services and
inspections, eight events, set bonuses for all seven manufacturers, ten hulls with a
chassis-select at run start, the six attributes, procedural ship and enemy art, headless
simulator.

**The six attributes exist but do not yet bite.** `RunState.attr_*()` derive Hull,
Thrust, Maneuver, Thermal, Sensors and Stealth from live gauges, and the ship tab and
chassis select display them — but nothing *checks* them yet. Wiring them into events,
combat entry and the starchart reveal ladder is the next piece, and is what
`attributes-and-checks.md` was written for.

Not yet: real art, audio, meta-progression, save/load.

## Priorities

1. ~~Get it compiling and running~~ — done
2. **Play five full runs.** Still not done, and it is still the blocker. Every balance
   number in this file comes from the simulator's competent-player model, which cannot
   tell you what is *unsatisfying*
3. Re-derive the healthy win-rate band against the current economy, then tune to it
4. Fix the single worst feeling
5. Resist adding content — 34 modules is plenty until the loop feels good.
   Manufacturer hulls added exactly one (a Solari utility, the only genuine slot gap)
   and put Sensors/Stealth on six modules that already existed rather than authoring
   bearers for them. Thin per-maker pools are the known cost: Cygnet, Halcyon and
   Calyx have three modules each, so their loot streams repeat. Fix that when the
   loop feels good, not before
