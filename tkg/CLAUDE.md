# Three Kelvin — project context

Pixel-art turn-based roguelite. Godot 4.3+, GDScript. Solo developer.
**Your ship is your character and your modules are your deck.**
*FTL's ship fantasy × Out There's exploration × Slay the Spire's combat × Diablo's loot.*

Named after the cosmic microwave background temperature — the universe's leftover
warmth, three degrees above absolute zero. A heat-management game named for the cold.

---

## How to work in this repo

- **Respond in Simplified Technical English (ASD-STE100).** Use short sentences. Put one
  instruction in one sentence. Use the active voice. Use approved, common words. Do not use
  metaphor, idiom, or figurative language. This rule applies to your replies in chat, not to
  the source comments — the comment voice in this codebase is deliberate and is described in
  "The most important tuning rule" and throughout the sections below.
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

# Save/load round-trip — RUN THIS AFTER TOUCHING SaveGame OR RunHistory
godot --headless --path . -- savetest          # ~3 s

# Star chart sky cache — RUN THIS AFTER ADDING TO _build_stars OR ITS BUILDERS
godot --path . -- charttest                    # ~10 s, needs a window

# Every chassis's six attributes as one table — RUN THIS AFTER TOUCHING attr_*()
# or the hull tables. The numbers only mean anything against each other.
godot --headless --path . -- attrs             # ~5 s

# The price table, and 12,600 checks that the market cannot be gamed —
# RUN THIS AFTER TOUCHING Market.gd
godot --headless --path . -- market            # ~4 s

# Boot destinations. The launcher is the default; every dev flag skips it.
godot --path . -- nolauncher                   # straight into a new run
godot --path . -- resume                       # straight into the suspend save

# Dev shortcuts. Flags, not menu items, because each one skips part of the run
# the balance depends on.
godot --path . -- ship                         # straight to the refit screen
godot --path . -- station                      # straight to the dock, hold full
godot --path . -- cards                        # every card in the game on one page
godot --path . -- fight 10                     # into a fight, dealing 10 cards
godot --path . -- fight foes=3                 # ...against a pack

# Rebuild the global class cache — REQUIRED after adding any new class_name,
# and required once on a fresh clone before anything will compile at all
godot --headless --path . --import
```

The sim boots the project normally and quits before building UI. It cannot run via
`--script`: that flag replaces the main loop and never creates the autoloads, so
`Run` and `DB` fail to resolve at compile time. `savetest` boots the same way.

`savetest` plays a run into a messy state, fingerprints it, saves, **scrambles the
live state**, loads, and compares. The scramble is the point: without it a field the
save forgot to serialise still matches, because the value was already sitting there.
A save system fails silently by nature — nothing crashes, the field just comes back
as a default and the run continues around it looking almost right.

Global `class_name` registration lives in `.godot/global_script_class_cache.cfg`,
which only `--import` writes. Without it every `class_name` reports "Could not find
type X in the current scope" — a wall of errors from one cause, not many.

`HeadlessSim.gd` plays complete runs with a competent-player model and reports win
rate, jumps, kills, and death causes. Healthy target: **40–55% win rate**. This tool
has already paid for itself — in the earlier web prototype it caught three real bugs
(including an infinite draw loop) and a structural map flaw in minutes.

### The merge gate

```bash
.github/scripts/validate.sh              # everything CI runs, from the repo root
SIM_RUNS=200 .github/scripts/validate.sh # a real balance pass
LOG_DIR=./ci-logs .github/scripts/validate.sh
```

`.github/workflows/validate.yml` installs Godot and calls that same script, so a
green pull request and a green laptop mean the same thing. If you want to change
what gets checked, edit the script, not the workflow.

It runs six things, in the order that fails fastest first: GDScript is
tab-indented, the class cache builds, the project boots and constructs its UI, the
market invariant holds, the save round-trips, and the simulator plays `SIM_RUNS`
complete runs. Then it syntax-checks the Python audio generators — syntax only, because rendering needs numpy, scipy and soundfile
and writes about 850 MB, which is not what a pull request check is for.

Four things about it are worth knowing before you touch it:

- **Godot exits 0 even when a script fails to compile.** It prints the failure and
  moves to the next resource. So every check reads Godot's *output* for
  `SCRIPT ERROR`, `Parse Error` and `ERROR:` rather than trusting its exit status,
  and `run_godot` is the only place that logic lives.
- **Every Godot step runs under a wall-clock limit.** A script that will not
  compile does not always make the simulator fail — it can leave it wedged
  instead, which is exactly what happened the first time this was tested. Without
  the limit a pull request sits open for the runner's full six hours rather than
  failing in three minutes. `timeout` is GNU coreutils and absent on macOS, so
  `run_limited` does it by hand.
- **The market and save checks are in the gate because they fail silently.** A
  market whose melt price creeps above its ask price does not crash — it pays for
  the rest of the run. A save that drops a field does not crash either; the field
  comes back as a default and the run continues around it. Both print a verdict
  line rather than raising, so the script greps their logs for it. That is also
  why the market check exists at all rather than a comment saying "keep melt
  below ask": the invariant is three constants apart from being false.
- **The gate does not check the win rate**, deliberately. The 40–55% band above has
  not been re-derived against the current economy, and a check that fails on a
  number nobody trusts teaches people to ignore the check.

The workflow reports but does not block. **Blocking requires a branch protection
rule on `main`** requiring the `validate` check — that is a repository setting, not
something in this file, and until it is set a red run is only advice.

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
| **A station never pays more for a part than it charges for one** | It used to, and that was an exploit rather than a tuning error — the buy price lived in `StationScreen` and the melt price lived in `RunState`, and neither file had heard of the other. Every price is now a fraction of one base value in `Market.gd`, so `melt < ask` is true by construction. `-- market` proves it over 12,600 combinations, because the invariant is three constants away from being false |
| **The profit is in the distance between two places, not in one transaction** | Round-tripping a part where you stand is a guaranteed loss, and that is correct: a scrapyard is not a market. A house's own yard is thick with its own parts and pays a glut price; a rival's yard needs what it cannot press. Buy Korvan in Korvan space, sell it to Solari. The route IS the trade |
| **A station's shelf is rolled once per run** | The guard used to be `shop.is_empty()`, so buying a shelf out re-rolled it on the next visit. A station is a place, not a vending machine: what somebody brought here is what there is, and it is also the brake that stops any trade route from being farmed |
| **Prices are derived, never stored** | A price is a pure function of a place and a part. The old "price" meta was saved on every shop module, and a shelf that came back without it quietly held a 47% sale. A derived number that is also saved is a second copy of the truth, and it only ever goes one way |
| **Materials are prerequisites, not a second currency** | Nothing on a price tag is denominated in alloy. A recipe costing forty scrap is a purchase; a recipe costing one precursor fragment is a reason to have flown somewhere. This is how crafting gets a cost that scrap cannot pay without breaking the one-currency ruling |
| **No crew management.** Ever | The whole premise: ship systems, not little people running around |
| **One suspend save, deleted the moment it is read** | Quitting is a bookmark, not a checkpoint. Autosave rewrites it at every safe point, so there is never an older state to reload — which is the only thing keeping "every death is self-authored" true. A reloadable save repeals the greed clock without changing a single number |
| **Combat is outside the save.** Safe points are screen swaps outside a fight | A safe point is a moment when the only live state is `RunState`'s, so restoring one cannot strand a half-resolved fight. The autosave lands *before* a fight starts, so a force-quit mid-fight costs the fight, not the jump. It does refund the hull the fight had taken — the price of not serialising deck order, enemy intent loops, drones and charge timers |
| **The flight record is a record, not meta-progression** | Nothing in `RunHistory` feeds back into a run. Identity is assembled mid-run from what you find, and a history that granted a starting bonus would be the first crack in that |

## The most important tuning rule

Simulation showed **individual fights are not the difficulty — the economy is.** A
starter deck beats a danger-5 Rustjaw Cutter for about nine hull. Runs end from
cumulative attrition against expensive repairs.

**So: raise station repair prices before touching enemy damage.** If repairs are cheap,
heat becomes decorative and the entire risk structure collapses.

That lever now lives in `Market.repair_rate()` and is local: `REPAIR_BASE` times a
development index that runs 1.28 on unclaimed ground to 0.84 in a capital. Moving
`REPAIR_BASE` moves the whole game.

## The economy — one file, three prices

`Market.gd` owns every number anybody pays. Read its header before changing a
constant; the short version is that all three prices are fractions of one base
value, which is what makes the ordering true by construction rather than by review:

| | multiple of base value | who sets it |
|---|---|---|
| **melt** — what a part breaks down to, anywhere, with no station | `MELT` 0.80, ×1.4 with `salvage_rack` | nobody. It is the floor |
| **bid** — what a station pays you | `ask × SPREAD` 0.62 × market saturation | the place, through `ask` |
| **ask** — what a station charges | `MARKUP` 1.5 × `ask_index` × `demand`, floored at `ASK_FLOOR` 1.20 | the place |

`ask_index` is how dear goods are HERE (development, then depth). `demand` is how
badly this place wants THAT brand, and it is the whole cross-system economy in four
lines: 0.78 in the maker's own space, 1.26 in a rival's, 1.25 for unbranded relic and
organic tech that nobody presses more of anywhere. It is derived from `makers`, which
the chart already prints on every system — so the trade map is a map you are already
reading, and `Market.trade_line()` says it in words on the chart and at the dock.

Four things about it are load-bearing:

- **`MELT × MELT_PERK` must stay below `ASK_FLOOR`.** 1.12 against 1.20 today, a 7%
  margin. This is the whole invariant. `-- market` fails loudly if it is crossed.
- **Melting is a discount, and the discount is the design.** An average market pays
  about what melting used to pay outright; a market that wants your cargo pays half
  again more; melting is what you take when there is no market in reach. The floor
  moved down so that a ceiling could exist. Raising `MELT` back toward 1.0 does not
  make the game more generous, it makes the market pointless.
- **Selling into a market saturates it** (`_saturation`, 0.93 per sale, floored at
  0.6). Without it one good system absorbs an unlimited hold at one rate, and the
  question stops being *how far do I haul this* and becomes *carry everything to the
  best place I have seen*.
- **Buying to resell is deliberately thin** — a few percent between the cheapest ask
  and the richest bid. The real trade is loot you did not pay for: melt it in the
  yard that built it, haul it to the yard that cannot. A pure trading loop that
  out-earns playing the game is the failure mode here.

**Materials** (`DB.MATERIALS`) are the second half. Alloy comes off everything you
melt, exotic off megafauna and pulsars, relic off deep wrecks and precursor parts.
They are spent at the **fabricator** (`Fabricator.gd`, recipes in `DB.RECIPES`), which
exists at a station and gates its better half behind Development ≥ CITY — that is what
makes a developed system a destination rather than a scenery variant. A recipe is
`{cost} -> {one effect the game already applies}`, so adding one is a dictionary
entry. If you find yourself branching in `_apply` for one recipe, add a `kind`.

Four recipes ship. That is the stage crafting stands on, not crafting: the ledger, the
recipe shape, the resolver and the place it happens. Recipes that reach into a
specific module in the hold need a target and a picker, and that is the next piece.

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
never recorded or licensed. `python3 build.py` renders eight music cues and
twenty-four sound effects and encodes them into `assets/audio/`; add a cue name
(`build.py music burn`) to rebuild just one. `audio/out/` holds WAV
intermediates and is gitignored; `audio/.gdignore` keeps Godot out of the
generator directory.

**Music is vertical, not horizontal.** A cue is not one file: it is eight or
nine stems that all start on the same sample, and *intensity* decides how many
you can hear. Nothing restarts when a fight begins — the arrangement opens up.
`Audio.music_state(&"sector")` is the whole API; `Audio.STATES` is the only
table that decides what a screen sounds like, so retuning the game's music
pacing is a one-file edit.

**Eight cues, one tune.** All of them are the same whistled five-note motif —
scale degrees 1-2-1-2-♭3 — and each does exactly one thing to it. The forms
live in `audio/motif.py`.

| Cue | BPM | Where | What it does to the motif |
|---|---|---|---|
| **"Slow Drift"** | 142 | sector, game over | states it, recoloured under i–♭VI–iv–♭VII |
| **"Dead Sector"** | 71 | any sector/event at danger ≥ 8 | flattens the 2nd — Aeolian to Phrygian |
| **"Hard Burn"** | 142 | combat | halves its note values and makes the engine out of it |
| **"Warm Ship"** | 71 | station, refit, deck | gives it the fifth it never reaches |
| **"Poisoned Ground"** | 71 | bosses, and deep-space combat at rung 3 | gives it that fifth a semitone flat |
| **"Nine Shells"** | 71 | star chart | transposes it around the minor-third cycle |
| **"Ship's Business"** | 142 | events | runs it through a circle of fifths, and cadences |
| **"Five Ways Home"** | 142 | title, menu | varies it five ways, and turns it major |

The first five **recolour** the motif over a static F. The last three
**develop** it, and are the only cues that change key — see
`audio/DEVELOPMENT_NOTES.md`. Measuring the first five: they use 11 of the 12
pitch classes and never sound A♮, so the major mode was mechanically
unavailable to them, and their one E♮ is a passing note, so nothing could
cadence. That was the cost of never rewriting the melody, and it is worth
knowing before adding a sixth way to recolour it.

- **Every cue is 142 BPM or exactly half at 71**, so all 28 pairings are a 1:1
  or 2:1 bar lock and any two crossfade without a tempo match. Key is
  unconstrained; the lock is about bar lengths only.
- **The motif never touches the fifth** — no cadence, a question with no
  answer, which is what you want under a run that can end at any moment. Two
  cues answer it, once each: the station with the C, the boss with the ♭5.
  Do not spend that anywhere else.
- **`Audio.STATES` is still the only table that decides what a screen sounds
  like.** Eight cues did not change that, and a ninth should not either.
- **Use `motif.pitches()`, not `motif.octave()`, for a transposed form.**
  `octave()` names pitch classes in a fixed octave and the octave boundary
  moves under a transposition, which silently destroys the contour.
- **Ornamenting a melody has six separate ways to go wrong and none of them
  raise.** All six shipped in one line; `audio/DEVELOPMENT_NOTES.md` has them
  in full. In short: indexing into an already-expanded form, notes shorter than
  the voice's fixed envelope, a fixed interval where the key wants a scale
  degree, `pitches()` anchored on the grace note so the melody comes out a step
  flat, a `frac` that is not a notated subdivision so the line sits off the
  grid, and putting a sixteenth-note figure on a voice with a 45 ms attack.
  **The render pipeline reports success on a wrong note, a flat key, an
  off-grid rhythm and a click alike** — only a listener covers all of it.
- **Deep space swaps a cue for its darker counterpart** (`Audio.DEEP`), at the
  same rung, capped at `DEEP_MAX`. Each pair shares a common F pedal and
  differs by one note, so it reads as the *place* changing rather than the
  music changing. `DEEP_MAX` is what keeps the boss reveal — both mutations
  stated simultaneously — exclusive to an actual boss.

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
  falls and resolves, overheating rises and bites. "Warm Ship" is the same
  rule at cue scale — the only music in the game with no noise, no drums and
  no distortion anywhere in it, because it is the only music set *inside* the
  hull.
- **Do not normalise the cues to each other.** The level ladder is composed.
  Measured RMS: combat −10.7 dBFS, main theme −12.8, station −13.5, title
  −14.2, events −14.9, boss −15.5, chart −16.5, dread −17.6. The headroom is
  the effect (`DREAD_NOTES` §3). The two classical cues are also the brightest
  in the set by a wide margin, which is the style working — transparency is
  the point of the texture.

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

Balance sim: **17% win rate**, 82.3 avg jumps, 7.4 avg kills, 0 errors, at 600 runs.

That is a sixfold improvement and it was measured, not estimated. The same 200-run sim
against the commit *before* manufacturer hulls (`4f7f6ec`) scores **2%**, 32.2 jumps,
3.6 kills, 76% of deaths from hull loss. Two steps got it here, each measured:

| | wins | jumps | kills | hull deaths |
|---|---|---|---|---|
| `4f7f6ec` — one Korvan frame, six makers gated off | 2% | 32.2 | 3.6 | 76% |
| seven manufacturer hulls, `ACTIVE_MAKERS` reopened | 10% | 52.8 | 6.3 | 50% |
| all three weight classes per manufacturer | **13%** | 56.0 | 6.0 | 49% |
| the market, materials and the fabricator | **17%** | 82.3 | 7.4 | 41% |

The last row is measured at **600 runs a side**, not 200, and that is worth saying
because the 200-run comparison it started from was misleading. `origin/main` scored
18% on one 200-run sample and 14% over 600; four 200-run samples of the new economy
landed 13-16%. Every one of those numbers is inside the others' noise — a 200-run win
rate has a standard error of about 2.6 points, which is most of the difference anyone
would be tempted to read into it. **Two hundred runs is enough to catch a crash and
not enough to judge a three-point change.** The 600-run pair is the honest comparison,
and it says the restructuring is difficulty-neutral to slightly kinder.

Where it is NOT within noise is how far a run gets: **82.3 jumps against 56.8**, a 45%
increase, with kills up and the stranded rate down four points (25.8% from 29.7%). The
sim only sells what it was going to melt anyway — it never buys to resell, because
assuming a competent player already runs a trade route would report a win rate for a
game nobody has played yet. So that is the FLOOR of the new economy, not its ceiling.

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

Those packed arrays live in a **static cache shared by every `MapChart`**, keyed by galaxy
and panel size. `Router` builds a fresh `StarchartScreen` on every visit, so an
instance-level cache was thrown away each time the player looked at the chart and rebuilt
from scratch on the next look. Opening the chart went from ~290 ms to ~65 ms; a new run
clears the cache wholesale, since a run is one galaxy for its whole life.

`MapChart.SKY_FIELDS` names the 34 derived fields the cache saves and restores, and there is
exactly one way for this to break: **a builder gains a new output and nobody adds it to that
list.** Nothing errors — the field keeps whatever the previous galaxy left in it, on the
second visit only. `-- charttest` catches it by comparing a restored sky against a freshly
built one field for field. Screenshots cannot: `SkyAnim` redraws every frame, so two
captures of an identical sky differ anyway.

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
and distance-priced fuel, a market that prices goods and services off the place you are
standing in, raw materials and a station fabricator, full combat (charge, salvo, brace, heat, drones, riposte, adapt,
pacify), loot with rolled affixes, install/scrap/swap, stations with all services and
inspections, eight events, set bonuses for all seven manufacturers, twenty-four hulls with
a chassis-select at run start, the six attributes, procedural ship and enemy art, headless
simulator, suspend save/resume, flight record, launcher screen.

**The six attributes exist but do not yet bite.** `RunState.attr_*()` derive Hull,
Thrust, Maneuver, Thermal, Sensors and Stealth from live gauges, and the ship tab and
chassis select display them — but nothing *checks* them yet. Wiring them into events,
combat entry and the starchart reveal ladder is the next piece, and is what
`attributes-and-checks.md` was written for.

Not yet: real art, meta-progression.

**Save, history and launcher.** `SaveGame` writes the run to `user://run.save` at every
safe point — `Router._swap()` is the single chokepoint, so a new screen is saved by
construction rather than by remembering to add a call. `RunHistory` appends every ended
run to `user://history.json`; `HistoryScreen` reads it from the HUD's HISTORY tab and from
the launcher. `LauncherScreen` runs with **no run loaded**, so nothing on it may read ship
state — `Router` hides the HUD while it is up for the same reason.

One consequence worth knowing: a resumed run can land on the sector of an *unfought*
combat node, which never happens otherwise because arrival starts the fight immediately.
`SectorScreen`'s action button has always said ENGAGE there; it now does that rather than
quietly plotting a jump.

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
