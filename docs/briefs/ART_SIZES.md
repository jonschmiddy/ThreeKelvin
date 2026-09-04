# Art sizes — one spec before anything is generated

*Written 2026-08-31. Every current figure was measured off the files and the
running game, not read off an older document. Nothing here has been generated
yet; this exists so that nothing is generated twice.*

**The problem, in the words it was reported in:** *"since I made the modules
bigger, the ships are smaller in comparison."* That is exactly right, and it is
measurable — see §1.

---

## 1. What changed, and why the ships shrank

`HoldGrid.CELL` went **30 → 40** and `GAP` went **1 → 0**. A fitted module is
drawn on the hull at half the hold's scale, so:

| | cell 30 / gap 1 | cell 40 / gap 0 |
|---|---|---|
| one cell, in the hold | 30 px | **40 px** |
| one cell, on the hull | 15 px | **20 px** |

Modules grew **33%** on the hull. The hulls did not move. A heavy is 100 px
tall, so it went from **six and a half module-rows** to **five**.

Nothing is wrong with the module size. The hulls are simply now too small for
it.

### It also fixed something

At 15 px a cell, every module footprint fell under PixelLab's floor (16 px per
side, 1024 px area) and had to be generated at 2–3× and reduced — which the
earlier art plan flagged as lossy: *"a 46×15 gun carries roughly seven pixels of
barrel height."* At 20 px a cell, **three of the five footprints clear the floor
outright** and can be generated at their authored size. See §3.

---

## 2. Hulls

### The two ceilings, and they bind on different axes

| | limit | where it comes from |
|---|---|---|
| **height** | **150** | `ShipScreen.HULL_VIEW_H` — `magnify(1, 150)` crops the view to 150 rows |
| **width** | **324** | the sector's ship slot: 460 wide, art box 324 after `HULL_BIAS 0.68` |

A heavy is **324 × 100** today. So it is **already at the width ceiling** and
using two thirds of the height one. Width cannot grow without taking the
enemy's half of the combat frame; height can grow by half for free.

That is the right axis anyway. Height is what makes a ship read as a body a gun
is bolted to rather than a rail a gun is longer than.

### Current against proposed

| weight | | full | bare | half | tall in module-rows | aspect |
|---|---|---|---|---|---|---|
| **light** | now | 226 × 60 | 180 × 60 | 113 × 30 | 3.0 | 3.77 : 1 |
| | **proposed** | **240 × 90** | 180 × 90 | 120 × 45 | **4.5** | 2.67 : 1 |
| | change | +14 w, **+30 h** | +0 w, +30 h | | +50% | chunkier |
| **medium** | now | 276 × 80 | 200 × 80 | 138 × 40 | 4.0 | 3.45 : 1 |
| | **proposed** | **280 × 120** | 210 × 120 | 140 × 60 | **6.0** | 2.33 : 1 |
| | change | +4 w, **+40 h** | +10 w, +40 h | | +50% | chunkier |
| **heavy** | now | 324 × 100 | 248 × 100 | 162 × 50 | 5.0 | 3.24 : 1 |
| | **proposed** | **320 × 150** | 240 × 150 | 160 × 75 | **7.5** | 2.13 : 1 |
| | change | **−4 w**, **+50 h** | −8 w, +50 h | | +50% | chunkier |

**Height goes up 50% across the board. Width barely moves** — and on the heavy it
goes *down* four pixels, because 324 was already sitting on the sector's art box
and 320 is the nearest multiple of ten under it.

That is the whole fix. The modules grew 33% and the hulls did not; giving the
hulls 50% more height puts a heavy back above where it was before the cell
change (7.5 module-rows against the old 6.5) without touching the axis that has
no room.

The proposed ladder is also even, which the current one is not:

| | width step | height step |
|---|---|---|
| now | +50, +48 | +20, +20 |
| proposed | **+40, +40** | **+30, +30** |

### The one thing this does not cover

**A party takes width, not height.** The convoy strip is `SHRINK_BEGIN`
horizontally, so three partners narrow the slot your own hull sits in. It
measures 0 wide solo and could not be measured without a party in the room.
Since the proposal changes **height only** on the binding axis, it does not
depend on that number — but anything that widens a hull later must measure it
first.

---

## 3. Modules

Already clean. Every figure below is divisible by 10.

| footprint | cells | authored (hold size) | drawn on the hull | area | generate at |
|---|---|---|---|---|---|
| `FIT` | 1×1 | 40 × 40 | 20 × 20 | 1600 | **native** |
| `UNIT` | 2×1 | 80 × 40 | 40 × 20 | 3200 | **native** |
| `LONG` | 3×1 | 120 × 40 | 60 × 20 | 4800 | **native** |
| `SPINE` | 4×1 | 160 × 40 | 80 × 20 | 6400 | **native** |
| `BULK` | 2×2 | 80 × 80 | 40 × 40 | 6400 | **native** |

**Author at hold size.** It is exactly 2× the hull size, so one asset serves
both: full resolution in the refit screen's hold, halved onto the hull. No
separate reduction pass and no lossy step.

All five clear PixelLab's floor (16 px side, 1024 px area) and all five are
divisible by 4, which `ART_CONTRACT.md` §4 records as a real, undocumented,
size-dependent constraint — *200×80 accepted, 250×100 refused with "Use 248x100
instead"*. **Probe each size once and read the error before committing a batch
to it.**

---

## 4. Card art

`CardView.Z_ART` is **`Rect2(16, 42, 93, 60)`** — 93 is not divisible by 5, and
it is the only number in the whole art set that is not.

**Proposed: `Rect2(11, 40, 90, 60)`.** 90 × 60, centred horizontally in the
112-wide card (`(112 − 90) ÷ 2 = 11`), and the y moves 42 → 40 so the offset is
on the grid too. **The art window moves up 2 px and narrows 3 px** — small, but
it is a visible change to every card face and wants a look before it lands.

Generated at native: 90 × 60 is 5400 px, well clear of the floor.

---

## 5. What has to change in code

| | |
|---|---|
| nothing, for modules | the sizes are already what the cells imply |
| nothing, for hull ceilings | 320 × 150 fits both existing limits |
| `CardView.Z_ART` | only if the card window is regularised — §4 |

The hull change is **assets only**. `ShipView` sizes its canvas from the sprite
(`custom_minimum_size = Vector2(_w, _h)`), so a taller sprite is picked up with
no code change at all. That is worth stating plainly: **this is a redraw, not a
refactor.**

---

## 6. Order

1. **Hulls first, at one weight.** Draw the heavy at 320 × 150 and put it on the
   ship screen and in a fight before drawing eleven more. The whole point is a
   proportion, and a proportion is judged on screen.
2. **Then the other two weights**, so the family reads as a family.
3. **Then modules**, biggest footprints first — a `SPINE` at 160 × 40 is the one
   most likely to expose a problem with authoring at hold size.
4. **Cards last.** They are per-card rather than per-module and are the largest
   count; `ART_CONTRACT.md` Stage 7 was reversed to make them per-card, at
   roughly 40% more generation.

**Standing rule, unchanged: no PixelLab generation without explicit
go-ahead.** Every step above stops and asks.

---

## 7. The Korvan design language

*Read off `hull_light_c`, `hull_medium_a` and `hull_heavy_s` rather than
invented. Ninety sprites are being generated and the whole point of them is that
they look like one manufacturer's line, so this is the part of the brief that
matters most.*

### What a Korvan hull is

**A monitor.** Long, low and horizontal — a naval gun-platform that happens to
be in space, not an aircraft and not a wedge. The silhouette sits far wider than
it is tall, and the mass is carried low.

| | |
|---|---|
| **orientation** | side-on profile, **nose to the right**, flat to the viewer |
| **proportion** | 2.1 : 1 to 2.7 : 1, wider than tall, mass low in the frame |
| **hull line** | a long spine with a blunt, slightly tapered bow and a squared stern |
| **superstructure** | a boxy layered stack rising forward of centre — a bridge tower, stepped, two to four tiers |
| **plating** | visible panel seams dividing the flank into segments; riveted, industrial, worked-on |
| **underside** | a darker keel band running the length, so the hull reads as sitting IN light rather than glowing |
| **stern** | an engine block, squared, with the warmest colour in the sprite |

### The palette

Cold steel body, **one warm accent**, and the accent is rationed.

| role | colour | where |
|---|---|---|
| hull | slate blue-grey, `#5c6b7d` family | the body, most of the sprite |
| shadow | deep blue-black | keel band, panel recesses, under the stack |
| highlight | pale grey-blue | top faces, the lip where deck meets flank |
| **accent** | **amber / orange** | a flank stripe, a hatch, the engine block, one or two lit ports |

**The amber is the signature and it must stay rationed.** On the existing three
it is well under a tenth of the pixels: a stripe along the flank, the stern
glow, and a couple of lit windows. A Korvan hull with orange panels all over it
is not a Korvan hull.

### What tells the tiers apart

C to S is **accumulation, not redesign**. The same ship, further along.

| tier | reads as |
|---|---|
| **C** | flat deck, minimal stack, few seams, almost no accent. A working hull |
| **B** | a second tier on the stack, more panel detail, the flank stripe appears |
| **A** | a full bridge tower, dorsal clutter, sensor masts, more lit ports |
| **S** | the tower crowned with fittings, heavy plating, the most amber — but still rationed |

A tier is not a new shape. If a C and an S from the same weight do not read as
the same yard's work, the pair has failed regardless of how good either looks
alone.

### What is NOT Korvan

Stated because a generator will reach for all of these:

- swept wings, fins, or anything aerodynamic
- a cockpit canopy, or a nose that reads as a face
- curves as the dominant line — Korvan is boxes and slabs
- glow, bloom, engine flares baked into the sprite (the exhaust is a separate
  animated asset — see `tkg/art/sprites/exhaust/`)
- a second accent colour. One warm, and it is amber
- symmetry top-to-bottom. The deck is busy and the keel is plain
- anti-aliasing of any kind — see `ART_CONTRACT.md` §6

### Checking a batch

The test is not "is this a good ship". It is **"put beside the three that exist,
does this come out of the same yard."** Judge them side by side at 1× on the
game's own background, never alone and never zoomed.

---

## 8. The hull prompt, and where it came from

Round 1 fired one prompt per weight, varied only by seed, and **32 of 90
survived the cull**. The prompt was not varied, so the keeps and cuts are a
clean readout of what the generator does when left alone -- and of which of its
habits are wanted.

### What the keeps had in common

Read off all 32, and consistent across every weight:

| | |
|---|---|
| **silhouette** | a long low slender wedge, tapering the whole way to a fine point |
| **superstructure** | ONE low block, a single storey, set well forward, thin masts on top |
| **the amber** | ONE narrow VERTICAL band across the hull, roughly amidships |
| **plating** | uniform cool grey-white, fine speckle, horizontal seams |
| **flanks** | plain. Very little clutter |

### What the cuts had

- bulbous domes, blisters and round pods on the flank
- a tall stacked bridge tower, two or three tiers -- the submarine look
- deep, fat, blunt hulls that never taper
- amber run as a long HORIZONTAL stripe, or spread over many panels
- dense greebles and containers on the upper deck
- hulls off the palette: teal, brown, near-black

### The two corrections that mattered

Round 1's prompt asked for the wrong thing twice, and the cull found both:

| | round 1 said | the keeps actually showed |
|---|---|---|
| bow | "steps down toward a **blunt** angular wedge bow" | tapered the whole length to a **fine sharp point** |
| amber | "one short amber stripe **near the rear** only" | one narrow **vertical band amidships** |

### The round 2 prompt

Weight word and engine clause vary; everything else is fixed.

> Flat side view of a {**heavy** / **medium** / **small light**} armoured
> spaceship pointing right. A long low slender hull built from thick flat armour
> plates like a tank rather than a boat. Deepest at the stern, tapering over its
> whole length to a fine sharp point at the bow. Its upper works are one low
> armoured block set well forward, a single storey, flush and squared off,
> topped by a few thin antenna masts. {**Blocky engine housings** / **A single
> blocky engine housing**} at the stern. The flanks are plain and unbroken: flat
> plating, fine panel seams, a few small lit ports, no domes and no round pods.
> Weathered grey-white armour and one narrow vertical amber band painted across
> the hull amidships, the only colour on the ship. Brutalist, industrial,
> {**workmanlike** / **spare**}.

`create_image_pixflux`, `view: side`, `direction: east`, `no_background: true`,
`detail: highly detailed`, `outline: selective outline`,
`text_guidance_scale: 12`. Seeds 401-430 heavy, 501-530 medium, 601-630 light;
round 1 used 101-130 / 201-230 / 301-330, so neither batch repeats the other.

**`direction: east` mostly works.** MEASURED over round 2 by comparing the
opaque mass either side of centre: **77 of 90 came out nose-right**, 13 nose-left.
Round 1 agrees -- only 6 of 90 were flipped in the cull. Do not spend
generations chasing the other 13; the bench has a flip toggle and mirroring is
free offline.

---

## 9. The prow the generator will not draw

Round 2's silhouette was accepted except at the front: the bow tapers to a fine
point, and it wants a **Pillar of Autumn prow** -- cut off square, a flat
vertical face of armour.

**Four promptings and an img2img edit all failed to produce it:**

| attempt | result |
|---|---|
| "a flat squared-off prow: a blunt vertical armoured face, chisel-like" | pointed |
| "cut off square ... as if the tip had been sawn off" | pointed |
| "a thick square-fronted ram block ... like the head of a hammer" | pointed |
| "squared off flat like the Pillar of Autumn", plus "a UNSC cruiser from Halo" | pointed |
| img2img over an accepted hull, `init_image_strength` 220 and 150 | pointed |

Two of those also dragged the rest of the sprite off what had already been
approved: dropping the word "slender" turned the slab hulls into rounded
submarine tubes, and the amber drifted back to a horizontal stripe. **The prior
is too strong to argue with, and every attempt risks the parts that already
work.**

### So the prow is cut offline

`tools/blunt_bow.py`. The taper is wanted right up until the last stretch, so
the fix is to stop it early rather than to ask for a different shape:

1. find the bow -- the end carrying less of the ship, read off the sprite rather
   than assumed, because 13 of 90 face the other way
2. walk in from it until the hull reaches **0.32** of its thickest column
3. drop everything beyond, and repaint that column in the darkest colour the
   ship already uses on its own silhouette

Every pixel in the result was drawn by the generator; the cap is the ship's own
outline, so it reads as an armoured face rather than an amputation.

**0.32 is measured, not chosen.** On a 320x140 heavy: 0.20 is still visibly
pointed, 0.26 is close, **0.32 gives a clean flat prow with the length intact**,
0.38 starts eating hull, and 0.50 removes a third of the ship. Applied across
all 90 it takes 63,889 pixels, about 710 a hull.

Pointed originals are kept in `tools/out/hull_candidates_r2_pointed/` -- the cut
is a pipeline step, not a destructive edit, and the threshold can be re-run.
