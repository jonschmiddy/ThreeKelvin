# UI design — Three Kelvin

Mockup sources for the interface rework. These are **Design Component** files
(`.dc.html`), each one an artboard on a pan/zoom canvas. They are the design
record: the engine implementation should match them, and when the design
changes these change first.

Published canvas: <https://claude.ai/code/artifact/4cc822fb-3336-4ac4-be96-35316be12168>

Only the sources live here. The seeded canvas file is ~2 MB of editor payload
and is regenerated, never committed.

---

## The decision

**Two-panel, in pixel art.** Ship on the left, whatever you face on the right,
one starfield behind both, context strip beneath, hand below that, persistent
HUD above.

Two other structures were explored and rejected — a diegetic cockpit and a
chart-primary layout where combat docked into the star map. They survive as
`ConceptB` / `ConceptC` for the record. Nothing was taken from them.

| File | Screen |
|---|---|
| `PixelCombat.dc.html` | Combat — the canonical screen |
| `PixelShip.dc.html` | Ship — install parts from storage |
| `PixelMap.dc.html` | Star chart |
| `ConceptA` · `ShipViewer` · `StarMap` | vector originals, kept as reference |
| `Main` · `ConceptB` · `ConceptC` | direction exploration, not taken |

---

## Rules the implementation must hold

**One pixel density.** Everything sits on a 2px grid — a 640×360 canvas drawn
at 2×. Silkscreen is an 8px face used at 16px, so type and chrome share the
same density. Mixing a 4× panel with a 2× font is the single most common way
pixel UI goes wrong.

**Integer scaling only.** 640×360 at 3× is exactly 1920×1080; at 2× it is
1280×720. Fractional scaling resamples every glyph and is what made the first
pass look blurry.

**Font antialiasing off.** `theme/default_font_antialiasing=0`. This reverses a
change made while the UI still used a vector font, where antialiasing was
correct. A bitmap face at integer scale needs no smoothing, and smoothing it
reintroduces exactly the mush it was turned on to fix. Texture filtering stays
`Nearest` throughout.

**Bevels, not borders.** Raised surfaces get a light top-left and dark
bottom-right inset; recessed surfaces invert it. This is the same two-plane
lighting rule the sprite contract uses, applied to interface chrome.

**Warm only where something emits.** Cold steel everywhere; ember and flare
appear on the reactor, vents, heat past the cap, and the active nav button.
Never as decoration.

**Countable boxes.** Heat and energy share one grammar: discrete bevelled
cells, not bars. Heat fills steel, turns ember approaching the cap, and
continues past a divider in red — each box past that divider is one hull paid
at end of turn. A bar hides that count; boxes state it.

**Icons, not labels, on the chart.** Map nodes are icons plus region colour,
with the name in the detail panel and a key row along the bottom. Labels under
every node are what forces the current build to truncate `STATION` to `STATIO`.

**Copy is shorter, but only where it must be.** Cards compress
(`Deal 3 damage twice. Salvo +2.` → `3 DMG x2 / SALVO +2`); the storage panel
is wide enough to keep full module names and affix lines. Rewrite the narrow
surfaces, not everything.

**SHIP and MAP sit top-left on every screen.** Ship is visibly dimmed during
combat rather than absent — you cannot refit mid-fight, and the button says so
instead of failing when pressed.

---

## Working on these

Edit the `.dc.html` files here, then re-seed and publish the canvas with the
`/design` skill, passing every artboard plus `canvas.json`. Keep artboard
positions in `canvas.json` — the pixel row sits above its vector reference row
deliberately, so the two can be compared at a glance.
