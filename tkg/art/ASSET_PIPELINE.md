# Asset pipeline — from PixelLab to playable

How generated sprites become working game assets, and what PixelLab can and cannot cover.

---

## The rule that protects the design

**Never generate a finished ship.** The core pillar is that your ship visually changes as
your build changes. A pre-composed hull-with-guns image kills that.

Instead:

1. **Bare hulls** — generated with visible *empty mount pads* (flat plates with bolt holes
   where modules attach). The hull must look deliberate when flying with nothing installed.
2. **Modules as isolated transparent sprites** — same 3/4 camera angle, same top-of-frame
   light direction, same pixel scale as the hull.
3. **Composited in Godot** at hardpoint anchors.

The hard part is not quality, it is that a module generated in isolation must share the
hull's camera angle and lighting or it looks pasted on. Fix: always pass the approved hull
as the style reference when generating modules, and generate each slot type as one batch.

---

## Coverage: what PixelLab can realistically do

| Asset | Count | Tool | Confidence |
|---|---|---|---|
| Bare hulls | 3 | `create_image_pixflux` (init) → `create_image_pro` | High — proven |
| Weapon mounts | ~12 | `create_1_direction_object` w/ `style_images` | High |
| System blisters | ~10 | same | High |
| Utility masts/pods | ~10 | same | Medium — small sprites, fiddly |
| Enemy ships | 6 | `create_image_pro` w/ hull as style ref | High |
| Station / derelict / ruins | 3 | `create_image_pro` | High |
| Card illustrations | ~33 | `create_image_pixen` (clean at small sizes) | High |
| UI panels, card frames | ~6 | `create_ui_asset` w/ `style_image` | Medium |
| UI font | 1 | `create_font` | Medium |
| Vent flicker, engine flame, muzzle flash | ~6 | `animate_image` (**256px cap**) | Medium |
| Megafauna | 2 | `create_image_pro` — try it, but budget to commission | Low |
| Nebula backgrounds | — | **Keep procedural.** Layered translucent masses, dithered edges, coloured per region | n/a |

Rough total: **~90 generated assets**. At 1 generation per pixflux iteration and 20–40 per
pro finalisation, budget accordingly — check `get_balance` and your plan before committing.
Iterate cheap, finalise expensive.

---

## Prerequisite: host your sprites

Base64 truncates around 2–3 KB in practice. Commit `art/sprites/` to GitHub and use raw
URLs for every `init_image_url`, `style_image_url` and `color_image_url`:

```
https://raw.githubusercontent.com/<you>/three-kelvin/main/art/sprites/<file>.png
```

This removes the size ceiling and is the single unblocking step for full-size generation.

---

## Sprite requirements for the game

| Requirement | Why |
|---|---|
| Transparent background, no baked shadow | Sprites composite over a procedural starfield |
| Dimensions divisible by 4 | PixelLab rejects otherwise |
| Hull ≤ 300px wide | Keeps `animate_image` (256 cap) usable after a small crop |
| Modules trimmed to their bounding box | Anchor maths assumes no dead padding |
| Consistent pixel scale | A module authored at 2× the hull's scale will never composite cleanly |
| One light direction (top of frame) | Composited parts must agree or the ship falls apart visually |

---

## Godot integration

### Data model

`ModuleData` and `HullData` now carry sprite fields:

```gdscript
# ModuleData
@export var sprite: Texture2D            # transparent, trimmed
@export var mount_offset: Vector2        # where the sprite's origin sits on its anchor

# HullData
@export var sprite: Texture2D
@export var weapon_anchors: Array[Vector2]   # deck positions, far row first
@export var system_anchors: Array[Vector2]
@export var utility_anchors: Array[Vector2]
```

Anchors are ordered **far row first, near row second** so painter order works: iterate the
array and add children in order, and near-row modules naturally draw over far-row ones.

### Composition

`ShipSprite` (new) builds the ship from a hull plus installed modules:

- One `Sprite2D` for the hull
- One `Sprite2D` per installed module, positioned at `hull.anchor[i] + module.mount_offset`
- Children added in anchor order → correct occlusion for free
- Rebuilds on `Sig.ship_changed`

The existing procedural `ShipView` stays as a fallback for slots with no sprite yet, so the
game keeps running through a partial art migration. That matters: you will not generate all
90 assets in one sitting.

### Heat

**Test the shader before generating heat-state sprites.** `shaders/heat.gdshader` takes a
`heat` uniform (0–1.7) and does the palette shift plus emissive bloom. If it looks right on
a real sprite, you save 2× the hull assets and get smooth transitions instead of three
steps. Drive it from `ShipSprite`:

```gdscript
material.set_shader_parameter("heat", float(Run.heat) / Run.heat_cap())
```

### Import settings

`project.godot` already sets `default_texture_filter=0` (nearest), which is what keeps pixel
art crisp. Do not override per-texture. Leave mipmaps off.

### Animation

Two options for vent flicker and engine flame:
- **Shader pulse** — cheapest, no assets, add a time-based term to `heat.gdshader`
- **`animate_image` frames** → `AnimatedSprite2D` — better looking, costs generations and
  runs into the 256px cap

Start with the shader.

---

## Recommended order

1. Commit `art/sprites/` to GitHub → get raw URLs
2. Generate and approve **one bare medium hull** with empty mount pads. Iterate on pixflux.
3. Test `heat.gdshader` on it. Decide sprites-vs-shader for heat.
4. Wire `ShipSprite` with that one hull + procedural fallback for modules. **Play the game.**
5. Only then: light and heavy hulls, then the Korvan module batch, then enemies.

Step 4 before step 5 is deliberate. Seeing one real hull in the running game will change
your mind about something, and it is cheaper to change your mind before 90 assets exist.
