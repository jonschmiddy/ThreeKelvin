# Three Kelvin — handbook

*The long-form half of what used to be `tkg/CLAUDE.md`. That file grew to 1,120
lines and every one of them was loaded into every session, which is the wrong
place for reference material: an agent needs the rules and the commands in
context and needs the screen-layout arithmetic only on the day it touches a
screen.*

*So this is the reference and `CLAUDE.md` is the index. Nothing was deleted in
the split — every section below is the text that was there, moved. What changed
is that you now have to open it, which is the point.*

---

## Developer Mode, and the Korvan focus

Two switches decide how much of the game is visible. Both are deliberate and both
will mislead you about the state of the project if you do not know they are there.

**`DevMode.enabled` — a `[ ] DEVELOPER MODE` checkbox in the corner of the title
screen**, persisted to `user://settings.cfg` under `[dev]`, **defaulting ON**. It is
the god-mode switch: it unlocks every manufacturer, shows the HUD's CARDS tab, and
shows the star chart's view-mode buttons. Turn it off to see the game a player sees.

- Controls behind it are **not built** rather than hidden. A hidden node still takes
  layout, still takes focus order, and still has to be reasoned about by whoever edits
  that screen next.
- Which means anything long-lived has to be told. **The HUD is constructed once in
  `Main._ready()` and outlives every screen swap**, so it keeps whichever tabs it was
  born with — hence `Sig.dev_mode_changed`, which `HudBar` rebuilds on. A screen
  built per visit (the chart, the chassis select) just reads the flag.
- **Flipping it must not restart anything.** It used to call `Router.show_launcher()`,
  which rerolled the title screen's galaxy; the checkbox now repaints in place.
- **It is ON by default, which is right for exactly one audience** and it is the two
  people currently playing this. `DevMode.gd` has a note to flip it before anyone else
  does.

**`DB.ACTIVE_MAKERS = [&"korvan"]` — only Korvan parts DROP.** `STARTABLE` is
still all seven, so run start still offers seven houses and their attribute signatures
still differ. The combination is intentional and has a cost worth stating plainly: a
Solari ship never finds a second Solari part, so the 3+/5+ set bonuses of the other six
are **unreachable while the loot is narrowed**, and the win rate is six points lower
(measured; see Current state). Reopening it is one line.

**The whole-map reveal was deleted rather than gated.** Dev mode should not include not
playing the game, and the chart's whole subject is the map you have earned. Nothing was
ever reachable through it — jumping has always been gated on `Run.can_jump_to()`.

---

## The economy — one file, three prices

`Market.gd` owns every number anybody pays. Read its header before changing a
constant; the short version is that all three prices are fractions of one base
value, which is what makes the ordering true by construction rather than by review:

| | multiple of base value | who sets it |
|---|---|---|
| **melt** — what a part breaks down to, anywhere, with no station. **The player calls this SCRAPPING** | `MELT` 0.80, ×1.4 with `salvage_rack` | nobody. It is the floor |
| **bid** — what a station pays you | `ask × SPREAD` 0.62 × market saturation | the place, through `ask` |
| **ask** — what a station charges | `MARKUP` 1.5 × `ask_index` × `demand`, floored at `ASK_FLOOR` 1.20 | the place |

**One operation, two names, and that was the confusion.** SCRAP and MELT were never
two things: `RunState.scrap_module()` has always priced by `Market.melt()` and has
always worn a SCRAP label on screen. The refit screen briefly showed both, which made
it look like a choice; the melt cell is gone and scrapping is the survivor. `Market.gd`
keeps the name `melt()` because it is the FLOOR in the price ordering above and that
ordering is what `-- market` proves — renaming it would rename the invariant.

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

**Materials** (`DB.MATERIALS`) are the second half. Exotic comes off megafauna and
pulsars, relic off deep wrecks and precursor parts. Both come from PLACES, which is
the whole test — see the alloy row in the rulings table for the one that failed it.
They are spent at the **fabricator** (`Fabricator.gd`, recipes in `DB.RECIPES`), which
exists at a station and gates its better half behind Development ≥ CITY — that is what
makes a developed system a destination rather than a scenery variant. A recipe is
`{cost} -> {one effect the game already applies}`, so adding one is a dictionary
entry. If you find yourself branching in `_apply` for one recipe, add a `kind`.

Two recipes ship, down from four when alloy was retired. That is the stage crafting
stands on, not crafting: the ledger, the recipe shape, the resolver and the place it
happens. Recipes that reach into a
specific module in the hold need a target and a picker, and that is the next piece.

---

---

## Art direction

**Lush objects in a cold void.** Stardew Valley's craft density applied to space — but
lushness is *detail density, not warmth*. The emptiness stays cold and lonely;
everything in it is rendered with obsessive care.

- **Perspective: edge on.** Flat side elevation, camera level, no top surface. Lit from
  above: bright top edge, mid flank, shadowed underside. Hardpoints sit along the dorsal
  and ventral lines. Nose points right, toward whatever you are facing. **REVERSED** from
  3/4 + two-plane lighting; `docs/art/ART_CONTRACT.md` §2a records why and what it cost.
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
`EnemyArt.gd` (side-view — which is now **correct by ruling** rather than a leftover; the
camera moved to meet it). When real art lands, drive `shaders/heat.gdshader` with a `heat`
uniform.

---

## Art generation — read `docs/art/ART_CONTRACT.md` first

Pixel art is generated via the **PixelLab MCP server** (tool names may be bare or prefixed
`mcp__pixellab__*`). If those tools are not available, say so — do not fall back to curl or
the REST API. Full mechanics in `docs/art/PIXELLAB_WORKFLOW.md`.

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

**Read `docs/art/PIXELLAB_WORKFLOW.md`'s "Worked pipelines" before generating anything.**
It has three end-to-end recipes — hull sprite, isolating an emitter into its own
layer, animating that layer — each followed by what went wrong. The two that cost
most: `no_background=true` is silently ignored by `create_image_pixflux` when an
init image is passed (12 of 12 results came back fully opaque), and a
`create_image_pro` call burned 25 generations because the prompt described the
surface before the object. `art/tools/pixeltools.py` does the post-processing that
every generated sprite needs — background stripping, cropping, palette snapping,
frame strips — in pure stdlib, because there is no Pillow here and Windows'
`convert` is not ImageMagick.

**Non-negotiable:** every generation passes `art/sprites/hull_medium_cold.png` as the
style/concept reference. Never generate a sprite from a bare text prompt — the result will
look fine alone and wrong beside everything else. There is exactly one canonical style
reference at a time; a newly approved hull replaces that file.

Hard rules, in short (full detail and the palette hexes are in `docs/art/ART_CONTRACT.md`):

- **Edge on**: flat side elevation, camera exactly level, no top surface, no
  foreshortening. Player ships nose **right**; enemies nose **left**.
- **Banded lighting**: bright top edge, mid-tone flank, shadowed underside. Every raised
  object still needs a light-to-dark break across it or it reads as a schematic. This
  replaces two-plane lighting and does the same job with less surface to do it on.
- An elevation has one plane, so **hardpoints sit along the dorsal and ventral lines**
  plus an aft mount and an upper spine — the vocabulary `ShipView._draw_weapon` already
  uses. Nothing occludes anything else. Plus one asymmetric detail — a perfectly regular
  ship reads dead.
- Lit from the top of the frame, cold and directional; weathering runs down the flank.
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

---

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
`docs/audio/DEVELOPMENT_NOTES.md`. Measuring the first five: they use 11 of the 12
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
  raise.** All six shipped in one line; `docs/audio/DEVELOPMENT_NOTES.md` has them
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

---

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

### Four ships in a frame built for one

`EncounterView` now carries a **convoy column** to the left of your hull: one slot per
party member, each drawn from *their* build, with their name, their hull class and their
hull and heat gauges. It is hidden — the whole cell, not just its contents — when nobody
is flying with you, so the solo game is the screen it always was.

The thing that made this possible is that **`ShipView` takes a subject rather than
reading `Run`**. `ShipBuild` is that subject: a hull's maker and weight class, the
`{slot, mount, maker, id}` of every fitted part, and the two gauges the art reacts to.
Three rules hold it up:

- **It carries what is drawn, not what is played.** No cards, no affixes, no rolled
  stats. None of those move a pixel and every one of them would be on the wire.
- **Identity travels as ids.** A manufacturer and a weight class, not a `HullData`. Both
  machines hold the same catalogue or the handshake refused the join. A looted hull is a
  `duplicate()` of a catalogue frame, so maker plus weight names its appearance exactly —
  which is also why tier is not sent.
- **Parts are dictionaries, not `ModuleData`.** The catalogue entry is shared. Writing a
  remote player's `mount` onto `DB.modules[id]` would move that hardpoint on every ship
  in the game.

`NetSession` carries a build in each roster slot and pushes it whenever `ship_changed` or
either gauge moves, coalesced to one send a frame and skipped when the description is
unchanged. Resolved builds are cached against a fingerprint of the wire, because a roster
replaces every slot and repainting a procedural hull is fifteen thousand pixels of
GDScript.

### One map, not four copies

A shared seed puts four ships in the same galaxy. It does **not** put them in the same
*instance*, and the difference is a real bug: every wreck holds the same two modules on
every machine — that is what `Rng.derive(tag, node.index)` buys — so without a shared
notion of what has been used up, four players each strip the same derelict and the closed
per-dive economy pays out four times.

So `NetSession` holds `claims` — `{node index: {option id: peer id}}`, host-authoritative
and pushed whole. A claim names an **option**, not a system, because a system offering
three things to do is not one resource: one ship strips the wreck and another still wants
the fight. `MapGen.OPTION_WHOLE` is the id for an encounter that eats the whole system,
which is every encounter today, so nothing reading `cleared` had to change. It records
**who** took it as well, because "Mercer stripped this" is the difference between a system
that is empty and one somebody emptied.

`RunState.take_whole()` and `take_option()` are the two doors; `adopt_party_claims()`
applies an incoming list, including one that predates this machine's map. Save version 5
carries `MapNode.taken`, which `cleared` alone cannot express.

Everybody's position rides the same presence message as their ship, and the star chart
draws the party from it — **outside** the visibility filter that hides unvisited systems.
That filter is right for a place and wrong for a person: `docs/coop-design.md` §7's leash only
works if you can see how deep somebody is. §9's sensor-range fog is not built; when it is,
it gates the position going *onto* the wire, not coming off it.

### Arriving and leaving

A ship enters and leaves the sector strip in a column of cold light —
`EncounterView.JumpFlare`.

**One animation for both directions.** A jump is a column of light with a hull
either side of it: what differs between arriving and leaving is only whether the
ship is there before the flash or after it. Two effects would be two things to
keep in step and would read as two events, which they are not. The hull changes
hands at `PEAK`, and the width curve is built as two segments meeting exactly
there — a single sine across the whole life put the widest frame at 0.62 while
the swap happened at 0.42, and the swap was visible beside the flash instead of
inside it.

**Cold, not ember.** Every other light in this game is heat — weapons, the hull
shader, the overheat warning — so a jump has to be the one bright thing on
screen that is not warm, or it reads as another gun going off.

**The column is diffed, not rebuilt.** `refresh_convoy()` used to clear the
strip and build it again whenever the id set changed, which gave every remaining
ship a fresh arrival for somebody else's jump and gave the ship that left no
frame to leave in — it was simply absent from the next list. A departing slot
stays a child until its light goes out, frees itself, and `tree_exited` brings
`refresh_convoy` back to close the column up.

**The label lives on the slot, not on the hull.** `ConvoySlot._draw` paints the
name and gauges OVER the ship, so it bails out while there is no hull under
them — and the `peaked` callback has to `queue_redraw()`, or the ship returns
and its label does not. Nothing else repaints a settled convoy.

### A shared fight

`SharedFight` is the party's copy of **the enemy, and only the enemy**. Your deck, hand,
energy, block, armor, heat and hull stay in `Run` and `Combat` on your own machine and
never cross, because no other player targets them, spends them or reads them. That
asymmetry is why joint combat is one field on `Combat` rather than a rewrite of it — and
why it needed no part of the `Run` instance refactor.

Every attack funnels through `Combat.damage_enemy()`. Five call sites, three in
`CardResolver`. That is the seam.

**The two directions are asymmetric on purpose.** Your card resolves locally and instantly
— you played it, you see the number, no round trip — and the **raw** amount is then sent
for the host to re-mitigate against the block it actually has, because the copy you just
spent may already have been spent by somebody else. Its push is authoritative. Death is
host-only: a client calling `_victory()` off its own optimistic view pays itself for a kill
the host has not seen. The other direction goes to **one machine**: the host names the
target and the intent, and dodge, block, armor and hull resolve where those numbers live.

`SharedFight.last_hit` carries `[who, foe, total, serial]` so a partner's shot can be
drawn. You skip your own. The serial is not decoration — every push carries the last hit,
including pushes about something else entirely, so a reader comparing the value would
redraw an old shot forever and swallow two identical ones.

**The enemy aims at heat**: `0.5 + heat_ratio`. About 4× the fire on a redlining ship, and
a cold one is never safe — a target rule with a zero in it is a party that elects a victim.
It cost nothing on the wire; `ShipBuild` has carried heat since the convoy strip needed a
gauge.

**One barrier, in one place.** Everyone plays their own turn immediately, at their own
pace. Only the enemy's turn waits, because it is one object acting on several private
ones. `docs/coop-design.md` §5 asked for face-down simultaneous lock-in and that was
**rejected** — it turns cards into deferred effects, and draw, energy-gain and
block-then-attack do not survive resolving out of order. Free-running plus one barrier buys
the same "nobody waits on a phase" for zero card changes.

**Leaving is not optional.** Dying, fleeing, winning and disconnecting all call
`leave_fight()`; a crew list holding someone who will never press END TURN again is a fight
that never takes another turn. Losing the host mid-fight drops back to local resolution
rather than hanging.

Not shared: an ambush (rolled from `Rng.foe`, a stream, precisely so four ships at one
system do not all get jumped — so two ambushes at one node are different events sharing an
address), and an event that drops you into a fight. Off rather than wrong in a shared
fight: reinforcements and pacification, both of which need the host counting something it
does not count yet.

**Known gap, and it predates this.** A hull with real art is blitted whole and modules
are not drawn on it — `hull_sprite()` returns art for MEDIUM only, so a light or heavy
frame shows its fitted weapons and a medium shows none, for your own ship as much as for
a partner's. Closing it needs module sprites and populated `HullData.weapon_anchors`,
which is what `ShipSprite.gd` was written for and what `docs/art/ART_CONTRACT.md` schedules
after hulls. `-- shipsheet` shows the gap directly: `medium_bare` and `medium_armed` come
out identical.

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
- **Energy is countable boxes. Heat and hull are ten cells** — and heat keeps
  one box per point ABOVE its cap, each of which is one hull paid at end of turn.
  PARTIALLY REVERSED: the old ruling was "heat and energy are countable boxes,
  not bars", on the grounds that a bar hides the number that matters. That reason
  survives exactly where it is true, which is above the cap, where a cell is a
  bill to count. Below the cap it was buying nothing and costing something: a cap
  is 8 on a Hairpin and 26 on a Furnace Baron and every vent module moves it, so
  the gauge changed length as you refitted, for a number the label beside it has
  always printed in full. Ten cells hold still. The divider is now where the
  gauge changes what a cell MEANS, which is why it stays a break and not a tick.
- **Map nodes are icons plus region colour**, name in the detail panel. Labels
  under every node are why the build currently truncates `STATION` to `STATIO`.
- **SHIP and MAP buttons top-left on every screen**; Ship dimmed during combat.

Two other structures — a diegetic cockpit and a chart-primary layout — were
explored and rejected. Nothing was taken from them.

---

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

---

## Rarity ladder — top tiers are *sources*, not bigger numbers

Common → Legendary are manufactured. **Exotic** is grown/harvested (megafauna).
**Artifact** is precursor relic tech, brand-agnostic, rule-breaking.
**Contraband is a tag, not a tier** — above-curve power plus station-inspection risk.

---

---

## Current state

**Compiles and runs clean on Godot 4.7.1** (migrated from the original 4.3 target; the
migration required no code changes). `--check-only` and a headless boot both exit 0.
The predicted first-run failures — typed-array assignment, inner-class type hints
(`MapGen.MapNode`), `Control` layout properties — did not materialise; the only real
blocker was the missing class cache described above.

Balance sim: **16% win rate**, 58.0 avg jumps, 7.7 avg kills, 0 errors, at 500 runs
— with the loot pool narrowed to Korvan. Off that narrowing it is **22%**, and
that six-point gap is the most useful number in this file right now, because it is
the price of the scope cut and it is paid in difficulty rather than in content:

| loot pool | wins / 500 | win rate | hull deaths |
|---|---|---|---|
| all seven makers dropping | 111 | **22%** | 160 |
| `ACTIVE_MAKERS = [korvan]` | 78 | **16%** | 218 |

Same build, one constant apart, 500 runs a side — about 2.6 standard errors, so it
is outside noise. **Earlier 250- and 300-run samples of the Korvan-only config read
22% and were believed.** They were under-powered, and the standard-error warning
three paragraphs down was already in this file when they were trusted. The pool lost
roughly three quarters of its modules, so a build improves more slowly and dies to
attrition — which is what the hull-death column says out loud.

Filling Korvan's ladder is what buys it back; 22% is the number to get back to.

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
standing in, raw materials and a station fabricator, full combat (charge, salvo, brace, heat, drones, feedback, adapt,
pacify), loot with rolled affixes, install/scrap/swap, stations with all services and
inspections, eight events, set bonuses for all seven manufacturers, twenty-four hulls with
a chassis-select at run start, the six attributes, procedural ship and enemy art, headless
simulator, suspend save/resume, flight record, launcher screen.

**The six attributes exist but do not yet bite.** `RunState.attr_*()` derive Hull,
Thrust, Maneuver, Thermal, Sensors and Stealth from live gauges, and the ship tab and
chassis select display them — but nothing *checks* them yet. Wiring them into events,
combat entry and the starchart reveal ladder is the next piece, and is what
`attributes-and-checks.md` was written for.

---

## Two engines draw what generation cannot afford

`HullWear` beats a hull up; `HullFit` kits it out. Same `Plate` and `Lcg`, same
palette guarantee, opposite directions, and they compose in that order because a
bolt-on should be able to get shot. Read `HullWear.gd`'s header before changing
either.

- **`worn_cached`, never `worn`.** `ShipView.refresh()` runs every time the idle
  bob changes offset, several times a second, and wear is a pass over every pixel.
- **Damage is BANDED into four**, not continuous. A ship rebuilds at most three
  times in a run. Measured on the medium: 0, 8, 19, 31 ms; a leviathan is 51 ms,
  because 240×120 against a hull's 188×88.
- **The band is NOT in the seed.** It was, and damage reshuffled instead of
  accumulating × 16% of marks survived a band change, which is chance. Each
  operation gets its own stream seeded independently, so a worse band draws
  further along the same sequence. Now 100%.
- **The seed is hull + pilot + run**, mixed rather than added. Every part is
  agreed between machines, so a peer's ship wears the same scars on both screens.
- **`HullFit` is written and BLOCKED**, and the block is art rather than code:
  a fitting needs bare plating, and the one hull with real art is 23% plain steel
  in pockets that fit a 3×3 in 1,226 places and a 10×6 in three. An S differs
  from a C by 116 pixels. It needs a PLAINER BASE HULL, not tuning.

**One hull has real art** — `hull_medium_cold.png`, edge-on, with a nine-frame
exhaust strip on its own layer. Light and heavy are still procedural, so the two paths
run side by side and `ShipView` picks per hull. Meta-progression is now exactly one
thing: manufacturer unlocks, which grant no power. See both rulings above.

Not yet: art for light/heavy or any module, and a per-tier hull table (C/B/A/S is
currently a rolled stat bump in `LootGen.roll_hull`, not a set of authored frames).

**Save, history and launcher.** `SaveGame` writes the run to `user://run.save` at every
safe point — `Router._swap()` is the single chokepoint, so a new screen is saved by
construction rather than by remembering to add a call. `RunHistory` appends every ended
run to `user://history.json`; `HistoryScreen` reads it from the HUD's HISTORY tab and from
the launcher. `LauncherScreen` runs with **no run loaded**, so nothing on it may read ship
state — `Router` hides the HUD while it is up for the same reason.

**The title screen's backdrop is the real galaxy, turning.** It is `MapChart` with
`show_icons = false` — the mode the chart already had for "the galaxy alone" — not a
simplified copy, because the sky is forty-eight thousand precomputed points and nine kinds
of structure, and a second renderer would be a second answer nobody would maintain. Three
things make it work:

- **The sky needs the GALAXY, not the map.** `draw_backdrop()` and `draw_anim()` contain no
  `Run.` references at all; `_build_stars()` reads only `galaxy`, `galaxy_kind` and
  `galaxy_seed`, all of which `RunState._ready()` guarantees exist before any run. The
  `Run.map.is_empty()` guards on `Backdrop`/`SkyAnim` were borrowed from the layers that
  draw systems and are gone.
- **The sky Control is a square as wide as the screen's diagonal.** A rotating rectangle
  sweeps its corners through the frame; a square whose inscribed circle reaches every screen
  corner cannot. Star counts are fixed constants, so the extra area costs nothing but a few
  more cull tests, and rotating a Control moves its retained draw list rather than
  repainting it — the turn is free.
- **Only OUR galaxy turns.** The backdrop is four canvases, in paint order: `DeepField`
  (flat black + distant galaxies), `Backdrop` (the star field), `SkyAnim` (orbiting core and
  accretion disc), `Halo` (22 parallax star layers). `MapChart.set_sky_rotation()` turns the
  middle two only — the far galaxies are millions of light years past this one and the halo
  is the sky it is being seen *through*, so neither shares its rotation. `_repaint_galaxy()`
  must queue all of them: the deep field and halo derive from `size` and `sky_pan`, so
  leaving either out means dragging the chart slides the galaxy across a fixed background.
- **Framing therefore cannot use `_radius()`,** which is derived from that oversized square.
  `MapChart.frame_to(screen, fill)` takes the view as an argument instead.

One visible consequence: `_region_tint()` picks a cloud's wash from the nearest system, so
with no map the nebulae lose their regional colour and fall back to one neutral blue-grey.
Emission-versus-reflection and the per-cloud ramp jitter still vary. Generating a map for
the launcher would restore it, at the cost of writing more run state for a title screen.

One consequence worth knowing: a resumed run can land on the sector of an *unfought*
combat node, which never happens otherwise because arrival starts the fight immediately.
`SectorScreen`'s action button has always said ENGAGE there; it now does that rather than
quietly plotting a jump.

---
