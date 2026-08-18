# PixelLab workflow — Three Kelvin

How to actually generate this game's art. Read `ART_CONTRACT.md` first for the rules;
this file is the mechanics.

---

## ⚠️ Do not use `create_character`

`create_character` and `animate_character` are a **skeleton-rigged humanoid/quadruped
pipeline** — walk cycles, 8-direction character turnarounds, body proportions. Ships are
not characters. Using it will produce something with legs.

The right tools for this project:

| Need | Tool | Cost | Notes |
|---|---|---|---|
| **Cheap iteration on a hull** | `create_image_pixflux` | 1 gen | Has `init_image_url` (img2img) and `color_image_url` (forced palette). Your workhorse. |
| **Final quality hull** | `create_image_pro` | 20–40 gen | `style_image_url` + `style_copy`, or up to 4 labelled `reference_images`. Max 512×512 square. |
| **Fix one bad region** | `inpaint_image` | 20–40 gen | Regenerates a masked rectangle, leaves the rest pixel-identical. |
| **Same edit across frames** | `edit_image` | 20–40 gen | Pass all three heat states, get one consistent edit. |
| **Modules / props** | `create_1_direction_object` | 20–40 gen | Takes `style_images`. Max 256px. |
| **Vent flicker, engine flame** | `animate_image` | scales w/ px | Text-described motion from a first frame. Even frame counts only. |
| **Card frames, HUD panels** | `create_ui_asset` | 20–40 gen | Takes `style_image_base64`. Aspect-gated sizes. |
| **UI font** | `create_font` | — | `glyph_px` 8/16/32/64. |
| **Check credits** | `get_balance` | free | Run this first. |

All creation tools are **async**: they return a job id immediately, then take ~30s–5min.
Poll with the matching `get_*` tool (`get_image`, `get_object`, `get_ui_asset`).

---

## Verified findings (tested live, 3 generations spent)

These were confirmed by actually running the tools, not read from docs.

**1. Text-only prompts ignore orientation, perspective and palette.** A detailed prompt
asking for 3/4 top-down, nose right, cold blue-grey steel produced a good-looking ship
that faced **left**, used an oblique near-side view, and came out warm white-grey — even
with the palette passed as `color_image_base64`. The docs are honest that `view`,
`direction`, `outline`, `shading` and `detail` are "weakly guiding". Believe them.

**2. `init_image` is the only reliable control.** Passing a downscaled hull sprite as
`init_image_base64` at `init_image_strength=240` preserved the silhouette, the nose-right
orientation, the deck/wall split, the engine placement and the mount layout. **Always pass
an init image.** Never generate a hull from text alone.

**3. Dimensions must be divisible by 4.** 262×156 was rejected with a clear error; 260×156
works. Project sprites are now authored at 220×128, 260×156 and 300×188 for this reason.

**4. `init_image` must exactly match the output size.** You cannot feed a 128×76 reference
and ask for 256×152 out — the call is rejected. So a large output needs a large init image,
which runs straight into the next problem.

**5. Base64 truncation is real and hits around 2–3 KB.** A 2083-byte PNG (128×76) went
through fine. A 2862-byte PNG (160×96) came back "broken data stream". A 4985-byte PNG
(260×156) was explicitly reported as truncated. **This is the blocker for full-size
generation, and URLs are the fix.**

**Therefore: commit `art/sprites/` to GitHub before doing serious generation**, and pass
raw URLs. That removes the size ceiling entirely:
```
init_image_url="https://raw.githubusercontent.com/<you>/three-kelvin/main/art/sprites/hull_medium_cold.png"
color_image_url="https://raw.githubusercontent.com/<you>/three-kelvin/main/art/sprites/palette_three_kelvin.png"
```

**6. Quality is good.** The rendering itself — shading, panel detail, crispness — is
clearly better than the procedural sprites. The problem was never quality, only control.

---

## Critical gotchas

**1. Prefer URLs over base64.** The docs warn repeatedly that MCP clients truncate large
inline base64 mid-string, corrupting the image. Since you have a git repo, the cleanest fix:
commit `art/sprites/` and pass raw GitHub URLs.

```
https://raw.githubusercontent.com/<you>/three-kelvin/main/art/sprites/hull_medium_cold.png
```

**2. Size limits bite.** Several tools cap at 256px per side. Current sprite sizes:

| Sprite | Size | Fits 256 cap? |
|---|---|---|
| `hull_light` | 220 × 128 | yes |
| `hull_medium` | 260 × 156 | **no** — 4px over |
| `hull_heavy` | 300 × 188 | **no** |
| `station` | 200 × 240 | yes |

`create_image_pro` allows 512×512, so hulls are fine there. For `animate_image` (256 max)
and object tools, crop or downscale first. Simplest: author hulls at ≤256 wide.

**3. Style hints are "weakly guiding".** `outline`, `shading`, `detail` and `view` are
suggestions, not constraints. Real control comes from `style_image_url` /
`color_image_url` / `init_image_url`.

**4. `init_image_strength` is inverted** from normal img2img — it's how much is
*preserved*. 500 barely changes the input, 300 is subtle, 150 is a real edit, ~50 keeps
only the composition.

**5. `create_image_pro` costs 20–40 generations per call.** Iterate on pixflux at 1 gen,
then spend pro credits once you know what you want.

---

## The palette swatch

`art/sprites/palette_three_kelvin.png` is a 45-colour swatch of the game's exact ramps.
Pass it as `color_image_url` to **force** generations onto the palette. This is the single
most effective consistency tool available — stronger than describing colours in text.

---

## Workflow: the canonical hull

### Step 0 — check credits
```
get_balance()
```

### Step 1 — cheap iteration loop (1 generation per attempt)
```
create_image_pixflux(
  description="top-down 3/4 view spaceship hull, industrial ex-military salvage,
               riveted armour plating, glowing orange vent strips along the spine,
               twin engine nozzles at the rear, bridge with lit canopy at the front,
               nose pointing right, weathered and lived-in",
  init_image_url="<raw github url>/hull_medium_cold.png",
  init_image_strength=220,
  color_image_url="<raw github url>/palette_three_kelvin.png",
  no_background=true,
  view="high top-down",
  detail="highly detailed",
  shading="detailed shading",
  outline="selective outline",
  width=260, height=156
)
```
Then `get_image(job_id)`. Vary `init_image_strength` between roughly 120 and 320:
lower gives it more freedom, higher keeps your composition. Run several; pick a direction.

### Step 2 — final quality pass
```
create_image_pro(
  description="<same description, refined by what you learned in step 1>",
  style_image_url="<url to the best pixflux result>",
  style_copy=["color_palette", "outline", "detail", "shading"],
  no_background=true,
  width=260, height=156
)
```

### Step 3 — fix specific problems, don't regenerate
This is the tool that solves the exact failure we hit by hand — over-detailed mid-deck:
```
inpaint_image(
  description="clean open deck plating with a few large hatches, no small clutter",
  image_url="<url to the pro result>",
  mask_x=90, mask_y=60, mask_width=80, mask_height=50,
  crop_to_mask=true
)
```

### Step 4 — approve and lock
Overwrite `art/sprites/hull_medium_cold.png` with the winner, commit it. **That file is
now the style reference for every future generation.**

---

## Workflow: everything else

**Other hulls** — `create_image_pro` with `style_image_url` pointing at the approved
medium hull. Describe the weight class difference (narrower/broader, fewer/more vents).

**Heat states** — try the shader first (`shaders/heat.gdshader`); it may make sprite
variants unnecessary. If you do want sprites, `edit_image` with all three frames in one
call gives you a *consistent* edit across them:
```
edit_image(
  image_urls=["<cold>", "<warm>", "<overheat>"],
  description="<the edit>"
)
```

**Modules** — `create_1_direction_object` with `style_images` (list of
`{"base64": "...", "format": "png"}`, max 256px each), `view="top-down"`. Generate the
Korvan starter kit as one batch so they share a look.

**Enemies** — `create_image_pro` with the player hull as `style_image_url`, described
facing left. Keeps the universe one shipyard tradition.

**Vent flicker and engine flame** — `animate_image(action="vent strips flickering with
heat", frame_count=8, first_frame_url=...)`. Frame count must be even. Watch the 256px cap.

**Card frames and HUD** — `create_ui_asset` with `style_image_base64` from a hull so the
chrome matches the ships. Note the aspect gating: square ≤512×512, 16:9 ≤688×384.

**Nebulae** — do **not** generate. Keep procedural, per the art contract.

**Megafauna** — organic curves and bioluminescence. Try `create_image_pro` if you like,
but budget for commissioning these.

---

## Godot integration resources

The MCP server exposes docs resources worth reading when you wire assets in:

- `pixellab://docs/godot/wang-tilesets`
- `pixellab://docs/godot/isometric-tiles`
- `pixellab://docs/overview`

---

## Hygiene

- **Rotate your API token** if it has ever been pasted into a chat, issue, or commit.
  Keep it in the environment, never in a tracked file.
- Downloads need no auth — the UUID is the key. Treat download URLs as semi-public.
- Commit approved sprites one at a time with the asset name in the message. Keep rejects
  out of git.
- `art/pixelart.py` still works. Use it to produce concept inputs and quick geometric
  variants — it is the fallback, not the enemy.
