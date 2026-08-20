# Art contract — Three Kelvin

**Read this before generating any sprite.** The single biggest risk to this project's
look is 150 assets drifting in style. This document is the thing that prevents it.

Generation happens through the PixelLab MCP server in Claude Code. **Never**
`create_character` or `animate_character` — those are a skeleton-rigged humanoid pipeline
and ships are not characters. Use `create_image_pixflux` to iterate (1 generation),
`create_image_pro` to finalise (20–40), `inpaint_image` to fix one region. Full mechanics
in `PIXELLAB_WORKFLOW.md`. Tool names may be bare or prefixed `mcp__pixellab__*`.

---

## 1. The canonical style reference

**`art/sprites/hull_medium_cold.png` is the style reference for the entire game.**

Every generation passes it as the style/concept reference input. Do not generate from a
bare text prompt — you will get a stylistically unrelated sprite that looks fine alone
and wrong next to everything else.

If a better hull is produced and approved, it *replaces* this file and becomes the new
reference. There is only ever one canonical reference at a time.

---

## 2. Hard rules — every sprite, no exceptions

| Rule | Detail |
|---|---|
| **Perspective** | **Edge on.** Flat side elevation, camera exactly level with the ship, no top surface visible, no foreshortening. Not 3/4, not top-down. **REVERSED** — see §2a. |
| **Banded lighting** | Lit from directly above: a **bright top edge**, a mid-tone flank, and a **shadowed underside**, with weathering running straight down. Every raised object still needs a light-to-dark break across it or it reads as a schematic. This is the successor to the two-plane rule and it does the same job with less surface. |
| **Facing** | Nose points **right** (+X). The player faces the encounter, which is always to the right. Enemies nose left. |
| **Symmetry** | Edge on is a true elevation, so the silhouette is what carries the ship. **Hardpoints live along the dorsal line (top edge) and the ventral line (bottom edge)**, plus an aft mount and an upper spine — the vocabulary `ShipView._draw_weapon` already uses. There is no far row and no near row, and nothing occludes anything else. |
| **Lighting** | Lit from the **top of the frame**, cold and directional. The top edge catches light, the flank sits mid-tone, the underside falls into shadow; weathering streaks run *down* the flank. |
| **Warm light** | Warm colour appears **only** where something emits it: reactor glow, thruster wash, weapon muzzle, vent cores, lit windows. Never as ambient warmth. This is the whole visual thesis of the game. |
| **Outlines** | Silhouette gets a 1px dark outline (`#0b0f16`). Interior detail is defined by value contrast, **not** by black outlines around every shape. |
| **Background** | Fully transparent. No baked shadows, no background gradient, no ground plane. |
| **Dithering** | Ordered/checkerboard dithering for gradients. No anti-aliasing, no soft blur, no gaussian edges. |
| **Detail density** | Lush: panel seams, rivet rows, weathering streaks, stencilled numbers, decals, lit viewports. Density is what makes it read as Stardew-adjacent craft — not warmth or saturation. |

## 2a. The camera was reversed, deliberately — and what it cost

This document used to open with **3/4 view** and **two-plane lighting**, and
called the second one "the single most important rule in this document." Both
are gone. That is a real reversal and it is recorded here rather than quietly
worked around.

**What decided it**, from thirteen generated candidates across three cameras:

- **Legibility at 1×.** The edge-on candidates read at native size. The 3/4 ones
  went muddy and only resolved when blown up to 3×. The game renders at 640×360.
  Judging sprites zoomed in is how you ship art that is mush in play.
- **Module compositing, which `ASSET_PIPELINE.md` already names as the hard
  part**: a module generated in isolation must share the hull's camera and
  lighting or it looks pasted on. In 3/4 that meant ~30 modules each matching a
  45° tilt and occluding correctly across two rows. Edge on makes each one a
  silhouette bolted onto a line. This is the whole argument.
- **The code already assumed edge on.** `ShipView._draw_weapon` mounts at
  *dorsal ordnance*, *ventral twin barrels*, *aft mount* and *upper spine* —
  side positions, not deck positions. `EnemyArt.gd` draws side-view. Combat is a
  two-panel split with ships facing each other. Only this document said 3/4.

**What was given up, honestly.** Two-plane lighting was load-bearing: a bright
deck face against a dark wall is a wider value break than a top edge against a
flank, and "lush objects in a cold void" had more surface to live on. Detail
density now has to come from the flank alone — panel seams, rivet rows, patches,
stencils, viewports — and it will be harder to make a ship read as *solid*
rather than as a decal. Accept the cost; do not pretend it was free.

## 3. Palette

Sampled from `art/pixelart.py`. Stay inside these ramps; add a new ramp only for a new
manufacturer, and keep it to 5 stops with the same value spacing.

**Cold hull steel** (primary surface)
`#131a23` `#232d3a` `#344254` `#4a5c72` `#6c8098` — rim light `#92aac4`

**Ink** (outline / recess) `#0b0f16` `#10161f`

**Gun metal** (barrels) `#1a1e26` `#3a404c` `#5c6474`

**Heat / combustion** (the only warm ramp on a ship)
`#5c280c` `#964214` `#cc641c` `#ffa63c` `#ffdca0` `#fff6e2`

**Korvan brass-olive** (weapon housings)
`#2c2212` `#4a3a20` `#6c542e` `#927440` `#bc9a5c` — hazard stripe `#a8873f`

**Cygnet cold blue** (drone tech)
`#182636` `#283e56` `#3a5876` `#5c82a4` `#8cb6d4`

**Glass / viewports** `#162e40` `#3a6b8c` `#8ec8e6` `#cfe8f5`

**Station hull grey** `#1e202a` `#2e313e` `#424758` `#5c6376` `#80889e`
**Station window warm** `#8a5c20` `#ffc66c` `#ffe8b8`

**Signals** warning red `#d64a3a` · status teal `#4fbfa8`

### Manufacturer accent ramps still to define
Solari (hot orange-red), Dredge (industrial ochre-grey), Redline (dirty green-grey),
Veyra (pale violet-white), Calyx (clean sage-green). Define each as 5 stops before
generating that faction's modules.

---

## 4. Sprite sizes

**Every dimension below is divisible by 4.** PixelLab rejects anything else — 262×156 was
rejected live, 260×156 works. Do not "round up for detail"; you will waste a generation.

| Asset | Size | Notes |
|---|---|---|
| Light hull | 220 × 128 | Short, shallow flank, 2 vents |
| Medium hull | 260 × 156 | 3 vents — **the canonical style reference** |
| Heavy hull | 300 × 188 | Long, deep flank, 4 vents |
| Weapon module | 88 × 32 | Housing plus barrel, in profile; sits on the dorsal or ventral line |
| System module | 32 × 20 | Low blister in profile, still needs a light-to-dark break |
| Utility module | 20 × 28 | Mast, dish or pod rising off the spine |
| Enemy ship | 152–260 wide | Match its danger tier's menace |
| Megafauna | 240–340 wide | Organic; **commission or hand-draw these** |
| Station | 200 × 240 | Vertical, lit windows with interior silhouettes |
| Card illustration | 104 × 44 | **Per module, not per card** — see below |

Native game resolution is ~640×360, integer-scaled. Sprites are authored at 1x.

These are the dimensions of the files actually in `art/sprites/`, verified by measurement.
Two further constraints make them non-negotiable rather than approximate:

- **`init_image` must exactly match the output size.** Generating the medium hull from
  `hull_medium_cold.png` therefore *must* request 260×156 — no other value is valid.
- **Hulls stay ≤300px wide** so `animate_image` (256px cap) remains usable after a small
  crop. See `ASSET_PIPELINE.md`.

---

## 5. Generation order

Order matters: each stage inherits style from the stage above it. Do not skip ahead.

### Stage 1 — the reference (do this first, iterate hard)
1. Medium hull, cold state, no modules — using current `hull_medium_cold.png` as concept
   input. **Iterate until you genuinely love it.** Everything else inherits from this.
2. Approve it, overwrite `art/sprites/hull_medium_cold.png`, commit.

### Stage 2 — remaining hulls
3. Light hull · 4. Heavy hull
Same silhouette language, different proportions. Verify all three side by side in
grayscale: weight class must be identifiable from outline alone.

### Stage 3 — Korvan modules (the starter kit is what players see first)
5. KH-20 Chatterbox autocannon · 6. KM-4 Mass Driver (long barrel) ·
7. Ablative Plate Welder (system blister) · 8. Coolant Flush Assembly ·
9. Targeting Servo (utility mast)
Then the aspirational tier: 10. KH-88 Jackhammer · 11. Widowmaker Siege Driver ·
12. Reactive Plating Array

Check each mounted on the hull, mirrored, before moving on. A module that looks great
in isolation and wrong on the ship is a failed asset.

### Stage 4 — heat states
13. Warm and overheating variants of each hull. These may be achievable with the
existing `shaders/heat.gdshader` instead of separate sprites — **test the shader first**,
it is cheaper than 3× the hull assets.

### Stage 5 — enemies (ships only)
14. Rustjaw Cutter · 15. Corsair Lancer · 16. Dreg Hulk · 17. Vex Marauder ·
18. Combine Sentinel · 19. Farlight Custodian (boss — most detailed thing in the game)
Enemies face **left** (they oppose you). Style reference is still the player hull, so the
universe reads as one shipyard tradition.

### Stage 6 — station and props
20. Cosmopolitan station · 21. Derelict hull (dark, no lit windows) ·
22. Precursor structure (violet, non-manufactured geometry)

### Stage 7 — card illustrations
23. One illustration **per module**, not per card. Both Chatterbox cards share the
autocannon illustration. This cuts the set from ~50 to ~33 and strengthens the fiction —
cards showing the same gun feel like the same gun.

### Stage 8 — remaining manufacturers
24+. Define the accent ramp, then generate that faction's modules as a batch so they
share a look.

### Not for generation — commission or hand-draw
- **Megafauna** (Voidwhale Calf, Void Leviathan). Organic curves, bioluminescence and
  tapering fins are where generated pixel art is weakest and a human artist is strongest.
- **Nebula backgrounds.** Keep these procedural — layered translucent masses with
  dithered edges, coloured per region. Cheapest richness in the game.

---

## 6. Acceptance checklist

Before committing any sprite:

- [ ] Transparent background, no baked shadow
- [ ] Nose right (player) or left (enemy)
- [ ] Edge on: flat elevation, no top surface, no foreshortening
- [ ] Bright top edge, mid flank, shadowed underside
- [ ] Dorsal and ventral mounts sit on the hull line, not floating off it
- [ ] Nothing occludes anything else — an elevation has one plane
- [ ] At least one asymmetric detail (decal, patch, warning light)
- [ ] Top-lit; every warm pixel is an emitter
- [ ] Palette stays inside the defined ramps
- [ ] Silhouette outlined; interior defined by value, not black lines
- [ ] No anti-aliasing anywhere (zoom to 8x and check the edges)
- [ ] Sits correctly on its hardpoint when composited
- [ ] Readable at 1x, not just zoomed in
- [ ] Grayscale test: still identifiable with colour removed

## 7. Workflow notes

- Generated sprites land in `art/sprites/`. Keep rejects out of git.
- `art/pixelart.py` still works and is useful for quick geometric variants and for
  regenerating concept inputs — it is the fallback, not the enemy.
- Commit approved sprites individually with the asset name in the message, so a bad batch
  is easy to revert.
- **Rotate your PixelLab API token if it has ever been pasted into a chat, issue, or
  commit.** Store it in the environment, never in a tracked file.

---

## Warning: `pixelart.py` will overwrite the canonical reference

`__main__` in `art/pixelart.py` saves directly over `hull_medium_cold.png`,
`hull_medium_warm.png`, `hull_medium_overheat.png`, all three `hull_*.png` and
`station.png`. **Do not run it casually** — it silently replaces the canonical style
reference that every other asset inherits from.

Worse, the script has drifted from its own output. `build_hull_34` declares:

| Weight | Script says | File on disk |
|---|---|---|
| light | 222 × 128 | **220 × 128** |
| medium | **262 × 156** | **260 × 156** |
| heavy | 300 × 188 | 300 × 188 |

222 and 262 are **not divisible by 4**, and `PIXELLAB_WORKFLOW.md` records 262×156 as
explicitly rejected by PixelLab. Running the script as-is would replace a valid 260×156
reference with an invalid 262×156 one, breaking both the divisibility rule and the
`init_image` exact-size-match requirement in one step.

Before running it: fix the `spec` dict in `build_hull_34` to 220/260/300, install Pillow
(`pip install Pillow`), and back up `art/sprites/` first. `build_hull_34` also hardcodes
its module list per weight, so producing a **bare** hull (empty deck, mount pads only)
requires passing an empty `mods` list to `draw_34_hull` — there is no argument for it yet.
