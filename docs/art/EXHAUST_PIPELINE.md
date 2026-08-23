# Making an exhaust plume

How the 24 strips in `art/sprites/exhaust/` were made, in the order that works
and with the reasons the obvious order does not. Written after building the
library, so every rule here cost generations to learn.

The short version:

> **Generate unforced against a nozzle you can strip. Let the canvas choose the
> proportion. Strip the hardware, then erode the tail in code. Animate from the
> raw, snap back to the still's palette, and pin the attachment column.**

Tools: `art/tools/plume_pipe.py` (the whole pipeline) and `art/tools/pixeltools.py`
(the PNG codec). Verify with `godot --headless --path . -- exhaust`.

---

## 1. Generate the still

**Do not force the palette.** This is the mistake that cost twelve generations
before anything worked. `create_image_pixflux` accepts `color_image_base64`, and
forcing the six-stop heat ramp produces plumes that look right and are unusable —
because **every roll welds hardware onto the hot end** (`ASSET_PIPELINE.md`
records the same for hulls), and `clean()` removes that hardware *by temperature*.
Forcing a warm ramp repaints the welded metal warm, and the filter reads warm as
fire. Three rounds were spent chasing a "flat cut" at the tip that turned out to
be a rocket's nose cone.

**Ask for a nozzle the filter can see.**

| ramp | nozzle to ask for | why |
|---|---|---|
| heat, whitehot | *dull grey steel* | cool grey against warm flame — strips cleanly |
| plasma, violet, viridian | *matte black* | a blue-grey bell is the same hue as a blue flame |

Black is not a guess: the viridian roll that stripped perfectly had a `#050806`
nozzle, and the two that failed had blue-grey ones.

**The canvas aspect IS the plume aspect.** The generator fills whatever frame it
is handed, every time. A 2.3:1 canvas gives a long plume, a 1.5:1 canvas gives a
square one. Cropping is never the fix — *choosing* is. `ART_CONTRACT.md` §4 sets
the length for you: every hull carries **76px of clearance behind the stern** —
the widest frame in the library, see §4b — so plume length is capped there and
only the height was ever a free choice.

**Shape answers a noun, never negative space.** Measured:

| asked for | got |
|---|---|
| "thick billowing cone" | a thick billowing cone |
| "fades to nothing before the left edge" | *less* clear space than not asking |
| "narrowing to a thin ragged point" | a small flame — it read "thin" as "minor" |

Eight generations across two rounds say the negative-space kind is worse than
ignored.

**Limits.** 16–400px per side, total area ≥ 1024 (48×20 is rejected, 52×20 is
not). Divisible-by-4 is real but size-dependent and in no schema — see §4 of the
contract. **10 concurrent jobs**, account-wide; the eleventh call is refused
outright, so fire in batches of ten.

## 2. Strip and finish the still

In order, all from `plume_pipe`:

1. **`clean(w, h, rows, ramp)`** — separates flame from hardware.
   Warm ramps test by hue. **Cool ramps cannot** and used to try: a violet plume
   is magenta, so `b > r` is false for its brightest pixels and the *flame* got
   stripped, while a blue-grey bell satisfied `b > r + 18` and the *nozzle*
   survived. Cool ramps now test **vividness** — near-white, or saturated and
   bright — with thresholds read off the art.
2. **`despeckle`** then **`keep_body`** — orphans, then islands. A bell's
   specular highlight is a 6px run of near-white that passes the flame test and
   floats free; despeckle cannot catch it because it is not an orphan.
3. **`trim_hardware`** — only when the bell was drawn in the same *value* as the
   flame (one came back as white bars against a white core). No colour rule
   separates those; the geometry does.
4. **`fill_holes`** — a cool-tinted pixel inside the flame fails the colour test
   and leaves a hole punched through the sprite.
5. **`erode`** — the tail dissipates in code, because the generator will not do
   it. Eats the boundary inward off a chamfer distance transform: removing
   pixels wherever noise says so punches holes through the middle, which reads
   as damage rather than as fire thinning out. **`depth` must scale with the
   plume** — 4px is a rim on a 40px heavy and most of the radius on a 20px
   light. `max(2, height // 10)` works.

**Do not snap to the §3 ramp.** Six stops flatten a plume, which is 80% white-hot,
into one cream mass. Unsnapped runs 7–31 colours — still disciplined. *Caveat
worth knowing*: on a black field unsnapped wins clearly; against a hull the two
are close and the snapped one arguably sits better with the hull's warm window
lights. §3 does not need changing.

## 3. Animate

`animate_image`, 8 frames — which returns **9 images**, the input plus eight.

**Feed the RAW still, nozzle still attached.** The hardware anchors the
composition and stops the plume wandering; it is stripped per frame afterwards.
Pass `no_background=True` explicitly — auto-detect follows the input, and a still
that came back opaque produces an opaque animation.

**Prompt beats seed, for motion.** Twice, decisively:

- A plume flat at 4px of length swing stayed flat at two more seeds. Changing the
  action to *"its whole length swelling and shrinking"* gave 20px — five times
  the motion. **"Flame flickering" asks for surface, and the model answers with
  surface.** Ask for the silhouette.
- Shock diamonds dissolved at two seeds — the model does not carry a repeating
  structure across frames. *"The bright rings hold their positions and stay
  solid, the plume never thins out"* fixed it in one.

Reach for a new seed only for **blank or thin frames**; those are luck.

Then `plume_pipe.sequence(paths, ramp, source)`:

- **`source` is the approved still's palette.** `animate_image` invents colours —
  one came back with 67 on a still carrying 21. `pt.snap`'s own docstring names
  the fix: snap to the source sprite's palette, never the project ramp.
- **One edge for the whole sequence**, from the per-column *minimum* across
  frames. Judging each frame against its own thickest column over-trims — one
  thin frame took fourteen columns off all nine. Anything right of that edge is
  cut, so the attachment point can neither blink nor wander. Both faults make a
  plume look like it is falling off the ship, and both happened.

**Judge on length swing**, the ink-box width variation across the nine frames.
Near zero is a decal; the liveliest in the library is 20px on a 64px plume.

## 4. Install

Strips go in `art/sprites/exhaust/` as `exhaust_N.png`: nine equal cells, nozzle
end flush right, one common ink box. This is the layout
`ShipView._flame_frames()` already slices.

- **The ids must stay contiguous.** `DB.exhaust_art()` indexes straight into the
  filename, so a deleted file in the middle is a null texture and an engine that
  silently stops burning. Removing one means renumbering the tail down.
- Update `EXHAUST_COUNT` in `Database.gd`.
- **Never hardcode the frame height.** It was `EXHAUST_H := 32` while one strip
  existed and would have mis-centred almost every one since; `hull_exhaust_at()`
  reads it off the texture.
- Any ship can fly any strip. Nothing is derived from weight class — a plume that
  changes size with the hull makes one engine read as three, and the weight is
  already legible from the ship in front of it.

Then, in order:

```
godot --headless --path . --import
godot --headless --path . -- exhaust        # every strip loads, widths divide by 9
godot --headless --path . --check-only --quit
SIM_RUNS=60 bash .github/scripts/validate.sh
```

`-- exhaust` exists because **a plume that fails to load is invisible, not
loud** — `exhaust` goes null, `ShipView` skips the blit, and the ship flies with
its engines out. Nothing throws and no test fails.

## 4b. Rigging: where it goes on the ship

A strip is only half the job — something has to say which hull carries it and
where. `art/tools/rig_bench.py <maker>` builds a self-contained page for that
maker's hulls: drag the mounts, drop as many thrusters as the ship has engines,
snap to align, save a `rigging.json`. `art/tools/read_rig.py` reads the newest
export back (by mtime — the browser writes `rigging (23).json`, and those sort
wrong alphabetically).

**Nothing in it is written for one maker.** The hull folder, the roster, the slot
counts and the seed positions are all read from the repo when the page is built:
`WEIGHT_BASE` sets a count, `TIER_DELTA` adds at A and S, and the house itself
changes it again — Probate trades a weapon for a utility. A page built by hand
against one maker's numbers is quietly wrong for the next.

Mounts seed from `HULL_LINES` run through the real `mounts_along()`, so a maker
whose lines are measured opens on the status quo; one with art but no lines gets
an even spread, which is something to drag rather than nothing.

**Hulls need clearance or the plume is cut off.** `ShipView._paste()` drops a
negative offset, so a bare hull cannot show a thruster at all. Every Korvan hull
carries 76px on the left — the widest exhaust frame in the library — added by
`scratch/pad_hulls.py`-style padding, with the bare originals kept in
`hulls/<maker>/bare/`. Width only: the screens budget hull HEIGHT at 120, and a
taller canvas clips on two of them.

## 5. When it goes wrong

| symptom | cause |
|---|---|
| tip ends on a hard flat cut | a rocket is welded on and the forced palette hid it |
| nozzle survives the strip | forced palette (warm), or a bell the same value as the flame |
| plume eaten to a sliver | cool ramp judged by hue — violet is magenta |
| black holes through the body | erosion depth too large for the plume's height |
| dashes floating off the tip | bell highlights kept; needs `keep_body` |
| plume blinks at the ship | a column lit in some frames and not others at the edge |
| plume slides frame to frame | per-frame alignment; use one edge for the sequence |
| loop looks static | prompt asked for flicker; ask for length |
| structure dissolves | model does not carry repeating detail — tell it to hold |

## 6. Cost

The library took **143 generations**: 30 stills across four axes, 23 animations,
plus re-rolls and repairs. A single new plume from scratch is **2** — one still,
one animation — if the still is right first time. Budget 3–4.

Anything published as an artifact **bakes its images in at build time**, so a
page goes stale silently when a sprite changes. The pages carry a per-sprite
content hash for that reason; compare against `sha256sum`.
