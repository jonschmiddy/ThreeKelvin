# Galaxy scale, declared shape, and the chart primer

*Design brief, 2026-08-25. Written offline against `main` as merged (SaveGame VERSION 13,
PROTOCOL 8 at time of writing; **now 14 / 8** — see `ROADMAP.md` §1). Line numbers will move; grep the quoted strings.*

**Status: design agreed, nothing built.** Three separable changes that want doing
in one pass because they all touch `MapGen`'s scale maths. §6 lists what is open.

Sibling document: `ENCOUNTER_REBUILD.md`. §5 of this file depends on it.

---

## 0. The problem, measured

**⚠ CORRECTED.** *Eight is the shortest FORCED path to the core, not what a run
actually takes — a competent player takes 38–47 jumps. The FTL and Slay the Spire
comparisons in this section are between a minimum and an actual and should be
ignored. `ROADMAP.md` §6.* The structural finding below still stands.

**A run is eight jumps long and nothing stops you taking them.**

`LAYERS := 9`, and `_link()` gives *every* system in a ring at least one
coreward link — `_connect(n, ranked[0])`, unconditionally, for every `n` in
`here`. So from anywhere you can always step inward. Minimum path start to core:
**8 jumps.** No galaxy roll makes it longer.

Fuel is not a brake. You start with 150 and `fuel_cost_to()` clamps every jump
to 1–6, so even at worst case that is 25 jumps of budget, and realistically far
more. **And the curve runs backwards for this**: cost is raw distance, and
`ring_count()` deliberately tilts population inward, so core systems are packed
tight and their hops pin at the floor of 1 while rim hops are the expensive
ones. Travel gets *cheaper* the deeper you go.

The only real brake is whether you survive the dive — and per
`ENCOUNTER_REBUILD.md` §8 the target is now a high base win rate, so **that
brake is being deliberately removed. This gets worse before it gets better.**

For scale: Slay the Spire is ~50 nodes, FTL 40–60 jumps. This is 8.

---

## 1. Do NOT just add rings

The obvious fix re-creates a geometry that was already tried and reversed. The
comment on `LAYERS` records it: twenty-four thin shells made a ring step 0.03 of
the disc against a 0.51 gap between neighbours on a rim ring — a factor of
seventeen, and nothing was near anything. Eight wide shells was the answer.

And raising `LAYERS` alone does not scale linearly, because **`target` is one
number doing two jobs**:

```gdscript
var target := (RIM - CORE) / float(maxi(1, LAYERS - 2))   # radial gap between rings
...
return clampi(int(round(perim / maxf(0.001, target) * weight)), RING_MIN, RING_MAX)
                              # ^^^^^^ and the divisor setting ring POPULATION
```

Shrink the ring gap and every ring's population inflates at the same time.
Measured, at the real `LIGHT_BLEND` of 0.42 and a Grand-Design Spiral:

| config | min jumps | systems |
| --- | --- | --- |
| now — `LAYERS` 9, target derived | 8 | 157 |
| `LAYERS` 15, target still derived | 14 | **528** |
| `LAYERS` 15, `RING_SPACING` held | 14 | 287 |
| `LAYERS` 27, `RING_SPACING` held | 26 | 539 |

Tripling the layers without splitting `target` more than triples the node count
and pins sixteen rings at `RING_MAX`. Same shape of fault as everything in
`DOC_RECONCILIATION.md`: one quantity, two jobs.

---

## 2. Split the constant, then set LAYERS to 15

### Do

```gdscript
## The radial gap between rings, as a fraction of the disc. Independent of
## LAYERS on purpose: this is ring GEOMETRY, and it was hard-won -- see the
## note on LAYERS about the twenty-four-shell version where a ring step was
## 0.03 against a 0.51 gap along the ring.
const RING_SPACING := 0.1157

const LAYERS := 15
```

`ring_count()` divides by `RING_SPACING` instead of the derived `target`.
`ring_radius()` is unaffected — it uses `LAYERS` for depth interpolation, which
is correct and should stay.

Result: **14 forced jumps, ~287 systems**, ring geometry unchanged from today.

### Why 15 and not 27

27 gives 26 forced jumps *before* any lateral movement, and §3 is about to add
lateral movement on top. A long forced spine plus mandatory sideways travel is a
long game. 15 plus §3 should land around 25–35 actual jumps, which is the genre
range. Easy to raise later; the constant is now honest.

---

## 3. Sparse coreward links

The structural half, and the one that makes the galaxy *feel* large rather than
merely be large.

Today every system holds a coreward link, so lateral travel is always optional.
Thin the forward links out of `here` so only a fraction of a ring's systems have
a way in, and crossing a ring becomes work — which is what makes the full
lateral connectivity already in `_link()` load-bearing instead of decorative.

**⚠ THIS INSTRUCTION WAS WRONG AND WAS CHANGED.** *It contradicts the section it
appears in: the every-system loop is exactly what made door-thinning impossible.
Reachability was moved from every system to every ring. `ROADMAP.md` §5.*

~~**Keep the reachability loop exactly as it is.**~~ `_link()` already guarantees
every forward system is reachable from its nearest neighbour; that loop is what
stops anything being orphaned and it must run after the thinning.

Suggested starting point: roughly half to two thirds of systems in a ring carry
a coreward link, rolled from `Rng.world` so it is positional and every machine
agrees. **Verify no ring ends up with zero forward links** — the reachability
loop guarantees every *target* is reachable, not that every *source* has an
exit, and a ring with no exits is an unwinnable run.

That check belongs in `-- maptest` if it exists, or a new assertion: *every ring
has at least one coreward link, and the core is reachable from the start.*

---

## 4. Galaxy shape becomes declared, not accidental

### The leak

`GalaxyGen`'s header claims a clean separation:

> Systems are laid out on rings by MapGen ... so the shape of the galaxy behind
> them can vary freely without moving a single jump or changing a single fuel
> cost. That separation is what makes fourteen of these cheap.

**That is not true.** `MapGen` reads the galaxy in two places, and
`galaxy_pos()` ends on `Vector2(cos(a), sin(a) * float(g.squash)) * r` while
`hop_distance()` is a plain `distance_to` on that vector. So the drawing metric
*is* the distance metric, and `squash` scales the fuel bill directly:

| kind | squash | systems | mean coreward hop | fuel |
| --- | --- | --- | --- | --- |
| Flocculent Spiral | 0.66 | 163 | 0.109 | 2 |
| Grand-Design Spiral | 0.62 | 160 | 0.105 | 2 |
| Lenticular | 0.36 | 135 | 0.086 | **1** |
| jitter floor | 0.28 | 128 | 0.080 | 1 |

A Lenticular is a 20% smaller galaxy that costs about half as much per jump to
cross. Nobody chose that. (There are **15** kinds, not fourteen — the header is
stale on that too.)

### The ruling: promote it, do not normalise it away

Different galaxies playing differently is **wanted**. The fault is that it is
accidental, invisible, and *welded*: how tilted a galaxy looks is currently the
same number as how many systems it has, so you cannot author a sprawling edge-on
galaxy or a dense face-on one.

Add two fields to every entry in `GalaxyGen.KINDS`:

```
density   how many systems the rings hold, 1.0 nominal
reach     how far apart they sit; scales fuel cost per jump, 1.0 nominal
```

- `ring_count()` multiplies by `density` and **stops reading `squash`**.
- After `_layout()` and `galaxy_pos()`, scale every `gal` by `reach`.

Then a Lenticular is `density = 0.85, reach = 0.9` **because that was decided**,
and the blurb can say so. And the thing the current code forbids becomes
possible: a Starburst Spiral at `density = 1.3, reach = 1.2`, sprawling and
expensive; a Dwarf Spheroidal that is genuinely tiny.

This is strictly *more* variety. Today all fifteen kinds vary along one hidden
axis in lockstep; declared, they vary along two that are authored per kind.

### `squash` in `ring_count()` is a bug on its own terms

Independent of any of the above. The field's own docstring: *vertical
foreshortening; 1.0 is face-on round, 0.3 is edge-on.* **Those are camera
angles.** You do not lose 20% of a galaxy's stars by tilting the camera. Node
count has no business depending on it, and this needs no balance argument.

`core_pow` in `ring_radius()` stays. Unlike squash it is a real structural
property — how hard the population packs inward — and `reach` absorbs its knock-on
effect on fuel.

### Still open: the anisotropy

Because distance is measured in squashed space, a north–south jump costs
**1.5× to 3.6× less** than an east–west one at the same angular separation,
depending on the roll. Optimal routes hug the minor axis. This is invisible and
nothing says it.

Two defensible answers. **Accept it** — a foreshortened disc genuinely is
shorter across the middle, routing along it is a nice thing for a player to
notice, and §5 is where it gets explained. Or **measure un-squashed**, at the
cost that two systems which look equally far apart sometimes are not, which
breaks the `hop_distance` comment's promise that cost is *as the chart draws
them*.

**Recommend accepting**, explaining it in §5, and tightening the `roll()` jitter
clamp from `0.28` to about `0.45` so the worst case is ~2.2× rather than 3.6×.

### Sim requirement

If fifteen galaxies genuinely play differently, **`-- sim` must report per
kind.** A single win rate becomes an average over fifteen different games and
the target band stops meaning anything. Same legibility argument that motivated
the high-win-rate target in the first place.

---

## 5. The chart primer

### What and when

A non-blocking overlay on the **first time a player opens the starchart in a
run**, covering two things at once: what galaxy this is and what it does to your
fuel, and **how to read the chart at all**.

The second half matters because of `ENCOUNTER_REBUILD.md` §7: the icon set
collapses to station, start and core, and route planning moves onto `region`,
`danger`, `security`, `berths` and `fauna`, which today are closer to flavour
than to decision inputs. Nothing currently teaches that. A galaxy-blurb popup
and a chart primer are the same amount of work and very different amounts of
value.

### Gate it on `trail.is_empty()` — **WRONG, see below**

> **LANDED 2026-08-30, and this gate does not work.** `Run.trail` is NOT empty
> until the first jump: `start_new_run` sets it to `PackedInt32Array([0])`, the
> system you begin on. A primer gated on `is_empty()` would never once have
> appeared. Shipped as **`trail.size() <= 1`** — same intent, and it fires.
>
> The re-show wrinkle below was also cheap to fix rather than accept: a
> **static `_primed_for` holding `Run.galaxy_seed`** outlives a screen that is
> rebuilt on every open, and keying on the seed rather than a bool means a
> second run in the same session is primed again instead of silently skipped.
> Still no save key, still nothing on the wire.

`Run.trail` is a `PackedInt32Array`, empty until the first jump. Gate on that
and first-open behaviour costs **no new state, no save key, and no
`SaveGame.VERSION` bump** — which matters, since a single bool would take it to
14 and this codebase has been bitten three times this month by version gates.

It is also naturally per-player: `Run` is an autoload, so each client has its
own trail. A player joining mid-run has an empty trail and correctly gets the
card; a resumed save has a full one and correctly stays quiet.

Known wrinkle: opening the chart, dismissing, and reopening *before* jumping
shows it twice. Acceptable — you have not left yet, the survey is still current.
If it grates, add a plain in-memory bool on the screen node; still no save change.

### Constraints

- **Purely local.** No wire, no `content_fingerprint`, no save. Nothing crosses
  a machine boundary — this is as low-risk as a feature gets here.
- **Must not block.** Four people open the chart at different times. Dismissible
  by any input, never gates the JUMP button, never eats input while the party is
  mid-decision.
- **The card is not the only home.** Its content lives permanently in the
  no-selection destination panel (`StarchartScreen`:257-263), which already
  describes the galaxy and whose comment says why: *it is the one thing on this
  screen that is always true, and a run should know where it is happening.* The
  card is the moment; the panel is the reference at jump forty.

### Content

Galaxy identity — `galaxy_title`, `galaxy_name`, `type_name`, and the kind's
`blurb`. Then the mechanical line, now that §4 makes it authored: compact or
sprawling, cheap or dear to cross, sparse or thick with systems. Then, for a
strongly foreshortened disc, the §4 anisotropy in one sentence.

Then the chart legend proper: what the axes mean and what a station is.

Once §4 lands, the blurbs earn their keep — the Lenticular's *the bar swept the
inner disc clean* stops being pure flavour and becomes the explanation for how
the run will feel.

### Cost warning

There is **no existing overlay or modal machinery in `StarchartScreen`** — no
popup, no dismiss, nothing to hang this on. It is new UI in a 4,260-line file.
Do not estimate it as small.

**It was still true at 5,173 lines.** The overlay is a full-rect `Control` added
LAST so sibling order puts it on top — no `CanvasLayer` needed — with a scrim at
`MOUSE_FILTER_STOP` so the dismissing press does not also pick a destination,
and the card in a **`CenterContainer`**: `set_anchors_preset(PRESET_CENTER)`
moves the anchors and leaves the offsets, so the card lays out from the centre
going down-right and hangs off the bottom of the screen. It did exactly that.

**The legend was lying before the primer pointed at it.** The chart key drew
SYSTEM violet (`#b08ad0`) and STATION pale blue (`#8ec8e6`) from back when a
system was tinted by who held it; since the colours became starlight every glyph
on the map is `star_colour`, so two of five key entries named colours that
appear nowhere on the map. Fixed at the source: `MapGen.swatch(type, star)` is
the one implementation and `star_colour(n)` is a call to it, so the key and the
map cannot drift again.

**`chartshot` had to learn about it.** `flown=N` marks systems visited without
appending to `trail`, so every harness run is a first open and the card sat over
every photograph. The harness dismisses it by default, `primer` keeps it up, and
`primerkey` fires a real `InputEventKey` and asserts the card is gone — because
`dismiss_primer()` returning true proves nothing about whether a key REACHES it,
and a primer you cannot get past is the only failure mode that matters.

---

## 6. Open, and out of scope

- **The anisotropy ruling** (§4). Recommend accept + explain + tighten the clamp
  to 0.45.
- **Exact `density`/`reach` values for all fifteen kinds.** Author them against
  the blurbs, then let `-- sim` argue.
- **Sparse-link fraction** (§3). Start near 0.5–0.66 and measure.
- **Performance.** 287 systems against 157 today — nearly double — moves save
  size, `MapGen` runtime and starchart draw cost. Cheap to measure now,
  expensive to discover after the encounter rebuild lands on top.
- **`GalaxyGen`'s header is stale** on both counts: the separation it claims does
  not hold, and there are fifteen kinds rather than fourteen. Fix it in the same
  pass — this is the same drift class as the affix section in `design-doc.md`,
  and nothing automated can see it.
- **Not in scope:** the difficulty ladder, and open ruling #11.
- **Ordering:** §2 and §4 first (both are `MapGen` scale maths, one pass), then
  §3, then §5 — which wants `ENCOUNTER_REBUILD.md` §7 landed first, or it will
  document a legend that is about to change.
