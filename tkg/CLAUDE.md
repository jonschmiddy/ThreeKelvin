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
godot --headless --path . -- sim runs=200

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
| **Hulls have no manufacturer** — weight class × tier only, with rolled stats and a rolled perk | Build identity comes entirely from parts you find; hull swapping stays a pure power decision with no identity whiplash |
| **Set bonuses are the class system** (3+ / 5+ modules from one maker) | Identity is assembled mid-run, not picked at the start. Every drop becomes a commitment-vs-flexibility question |
| **Charge fires automatically** when ready | Tension belongs in *when you start* charging, not in a release button |
| **Overheat = predictable self-damage.** 1 hull per point over cap, at end of turn. No cliff, no shutdowns, no cap on heat | Heat becomes a second health bar you can choose to spend. Repairs cost scrap, so overheating burns money |
| **The deck only reshuffles at the start of your turn** | Without this, zero-cost draw cards (Emergency Vent, Jury-Rig, Foresight) loop forever once the discard recycles. Also makes deck size strategically meaningful |
| **Player attacks never miss. Only enemies miss** (light hulls dodge incoming fire) | Player-side miss RNG feels terrible in a game built on perfect information |
| **Ballistics run cold; energy weapons run hot** | Gives materials a readable thermal language before you read any numbers |
| **Ships use fixed intent loops; fauna use weighted random pools** | Machines are predictable, animals are not. Worldbuilding through mechanics |
| **Bosses are hand-tuned, never danger-scaled** | A boss-grade stat block in a random encounter is a run-killer. This was a real bug once |
| **Enemy HP scales faster than enemy damage** (0.20 vs 0.10 per danger tier) | Deeper fights should be longer, not one-shot lethal |
| **Lateral map travel is always available and cheap** | You can farm a danger band before descending, so every death is self-authored. This *is* the greed clock |
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
coloured per region).

`art/pixelart.py` authors sprites programmatically and still works — useful for geometric
variants and for producing concept inputs. It is the fallback, not the enemy.

## Screen layout: one grammar for everything

**FTL two-panel split for every node type.** Your ship is always on the left; the right
panel is whatever you are facing — enemy in combat, docking bay at a station, dead hull at
a derelict, illustration at an event. Below the split: a context strip (enemy intent /
dock services / event choices) and your hand. Above: persistent HUD.

This replaces separate Combat/Station/Loot/Event screens with **one frame and swappable
right-hand content**. Less UI, less art, and the ship never disappears between fights so
it reads as a companion rather than a stat block. The star chart stays a separate
full-screen view.

**Note:** the current scaffold still has separate screen classes. Consolidating them into
`EncounterScreen` (ship left, swappable right panel) is a known pending refactor.

## Manufacturers (seven, each a playstyle)

`korvan` ballistics + charged ordnance (starter) · `solari` weaponised heat ·
`dredge` scrap economy and sustain · `redline` evasion, refits, contraband ·
`veyra` thin perfect deck · `cygnet` drones · `calyx` regeneration and adaptation.

Korvan/Solari mirror each other (manage heat vs. surf it); Dredge/Redline mirror each
other (melt it down vs. repurpose it).

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

Balance sim over 200 runs: **44% win rate**, 17.1 avg jumps, 6.0 avg kills, 0 errors —
inside the healthy band, so the economy tuning holds as authored.

**Known open bug:** 8.5% of sim runs (17/200) end neither won nor dead. `_play_one()`
breaks out when a node has no jumpable options, so those runs are stranded rather than
resolved — likely a map connectivity or fuel gate issue in `MapGen`. Wins and deaths
are counted, so the reported win rate is over all runs including the stranded ones.

Implemented: galaxy generation with six region types, jumps and fuel, full combat
(charge, salvo, brace, heat, drones, riposte, adapt, pacify), loot with rolled affixes,
install/scrap/swap, stations with all services and inspections, eight events, set
bonuses for all seven manufacturers, procedural ship and enemy art, headless simulator.

Not yet: real art, audio, meta-progression, save/load.

## Priorities

1. Get it compiling and running
2. Play five runs; note what feels *unsatisfying* (not broken)
3. Fix the single worst feeling
4. Resist adding content — 33 modules is plenty until the loop feels good
