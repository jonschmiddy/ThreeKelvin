# Encounters — the rebuild

*Design brief. Written 2026-08-24, re-checked 2026-08-25 against `main` as
merged (SaveGame VERSION 13, PROTOCOL 8 at time of writing; **now 14 / 8** — see `ROADMAP.md` §1). Line numbers will move; grep the
quoted strings.*

Sibling document: `GALAXY_SCALE.md`. §5 and §8 depend on it.

**Status: design agreed, nothing built.** §9 lists what is still open. This is
the argument and the data model, not a work order — read §8 before estimating,
because the sim is part of the feature rather than a check on it.

---

## 1. The model, in one paragraph

*Nothing below has been built. Verified against the current tree on 2026-08-25:
`NodeType` still reads `{ START, FIGHT, STATION, EVENT, DERELICT, GOAL, PULSAR }`,
the type bag is still 16 FIGHT / 8 STATION / 8 EVENT / 4 DERELICT, and
`EventTable.gd` is still 319 lines holding 14 events of which 6 carry a check.*

**A system is a place with things to do in it, and the chart does not say what
they are.** Only stations are telegraphed — they are the safe node, the bonfire,
and nothing happens at one except trade, repair and refuel. Every other system
looks identical from the chart and rolls **2–4 options** on arrival: a fight, a
wreck to strip, a signal to answer, a claim to mine, a contract to close. Some
options carry a skill check, some do not. Sometimes none of them is a fight.
Sometimes the only one is.

**Depth does not change how many options a system holds. It changes what they
cost you to take, and how many of them you must give up.** At the rim options
are low-stakes and mostly independent — take them all, build your ship. Deep in,
the stakes rise and the options increasingly **compete**, so arriving at a rich
system means choosing what to leave.

---

## 2. Why depth scales stakes and not count

The obvious version — more options the deeper you go — was considered and
rejected, because **the galaxy already applies that gradient and applying it
twice compounds**.

`MapGen.ring_count()` tilts node population inward on a power curve. Its comment
states the intent in as many words — *sparse and safe at the edge, dense and
lethal in* — and records the measurement: **areal density runs about fifty to
one from rim to core.** A linear tilt was tried first and cancelled out, because
the perimeter shrinks inward at almost the rate the weight grows; the power was
added specifically to empty the frontier and pack the deep galaxy.

Stack option count on top of that and a deep ring compounds three ways:

1. Far more systems inside jump range (the fifty-to-one).
2. Cheaper to reach each one — `RunState.fuel_cost_to()` is raw disc-radii
   distance clamped to a floor of 1, so tightly packed core hops pin at the
   floor while rim hops run several units.
3. More to extract per system.

And `MapGen._link()` builds full lateral connectivity inside every layer, with
the stated intent *farm before you descend*. The dominant line becomes: dive to
the deepest survivable ring, farm sideways indefinitely, never return. The rim
turns into a corridor.

*The economic half of this argument has since weakened, and it is worth being
honest about which leg the design now stands on.* The original second reason was
that the economy could not absorb compounding income: `handbook.md` records 16%
win rate Korvan-only and 22% with the pool open, against a 40–55% band. **The
target has since moved — the base game is now meant to be generous and clearly
winnable** (§8), so "it would pay too much" is no longer decisive on its own.

What survives is the design argument, and it stands alone: **choosing what to
give up is more interesting than working through a longer list.** A system with
five things to do and time for all five is an errand. A system with three where
you may have one is a decision. Depth should make that decision harder, not the
errand longer.

**The second reason is that sparse-and-easy is not tension, it is dead air.** A
rim system holding one easy option is not a decision. Today every rim node at
least guarantees a fight and its loot. The rim needs options for *texture* —
it is where you are weakest and have nothing to work with. The core needs them
for *pressure*. Same count, opposite job.

---

## 3. What survives from the current system

Four things, and they are the reason this is a smaller change than it looks.

**Decide once, on arrival.** `Router._roll_here()` writes what a system holds
onto the node so the save carries it, and it is idempotent. Both `n.foes` and
`n.event_key` used to be rolled when the screen opened, which meant quitting and
resuming re-rolled them — save-scumming through the front door. Options inherit
this rule exactly: rolled in `_roll_here()`, before the autosave, stored on the
node.

**Positional versus stream.** What is *at* a place is `Rng.derive(tag,
node.index)` so four machines agree; what happens *to you* comes off a stream
salted by seat. Options are a property of the system, so they are positional.
The ambush roll is not — see §6.

**The option claim layer already exists.** `MapNode.taken` is a
`PackedInt32Array` of option ids, saved since version 5, and
`NetSession.claims` is `{node: {option: peer}}`, host-authoritative. It has
already been used two ways: `OPTION_WHOLE = 0` for an encounter that eats the
system, and `OPTION_SHOP + i` for the i-th part on a station shelf.
`RunState.take_option()` is the door and it already returns whether *you* got
it. **This model is what that field was built for.** Today `OPTION_WHOLE` is
used by every encounter and the comment says so almost apologetically.

**`SkillCheck`.** The shortfall ladder is the best-designed thing in this area
and only six of fourteen events use it. Meeting a requirement is certain — no
roll — because an attribute you earned should never fail you. Failure splits
evenly between PARTIAL and BOTCHED with a 5% floor so a desperate option is
never a disabled button with extra steps. It reads *current* values, so a holed
ship really does fail a Hull check it would have passed at full. Options adopt
it unchanged: `check = {attr, need}` plus up to four outcome callables, with
`SkillCheck.pick_outcome()` falling down the ladder so an option may author only
the bands it cares about.

---

## 4. What an option is

```gdscript
{
    id: StringName,          # stable identity. NOT the display title -- see below
    label: String,           # "Strip the wreck"
    body: String,            # optional flavour shown under the label
    group: StringName,       # &"" = independent; shared = mutually exclusive
    weight: int,             # roll weight before gating
    tags: Array[StringName], # &"fight", &"salvage", &"signal", &"claim", &"contract"

    # gating -- all optional, all ANDed
    min_danger: int, max_danger: int,
    regions: Array,          # MapGen.Region values; empty = any
    needs_berth: bool,       # only where a manufacturer operates
    needs_fauna: bool,
    min_security: int, max_security: int,

    # resolution -- exactly as EventTable options work today
    check: Dictionary,       # {attr = &"hull", need = 5}; omit for no check
    effect: Callable,        # unchecked options
    met/clean/partial/botched: Callable,   # checked options
}
```

**Identity is a `StringName` id, never the display title.** `EventTable.by_key()`
matches on `str(e.title)`, so renaming "Whale fall" invalidates every save that
rolled it — it re-rolls with a `push_warning`. Do not carry that forward. The
title is copy; the id is a key.

### Option ids on the node

`MapGen` gains `const OPTION_SITE := 300`, and the i-th option at a system is
`OPTION_SITE + i`.

**300, not 200.** `OPTION_BAG := 200` is the shared-kill bag and its comment
explains the spacing reasoning — the shelf bases are set far enough apart to
grow. Follow it: leave room above 300 for a system to hold more options than the
current 2–4, and never re-base an existing constant, because the numbers are in
saved `taken` arrays and in the co-op claims table.

Two more rules, both learned the hard way in `OPTION_SHOP`:

- **The list must never shrink.** `n.shop` used to have the bought part erased
  out of it, which silently renumbered everything after it — one purchase and
  every machine disagreed about slot 2. A taken option stays in the array and is
  marked in `taken`.
- **The node stores the rolled option ids, not just a count.** The list is
  derived positionally so every machine builds the same one, but a save must be
  able to rebuild it after the table has changed underneath it. Store
  `Array[StringName]`; resolve to definitions on load; drop an unknown id with a
  warning rather than refusing the save.

### Exclusivity

`group` is the whole mechanism. Taking an option marks its group spent; every
other option in that group becomes unavailable. Empty group means independent.

Symmetric rather than asymmetric on purpose — a `closes: [...]` list is more
expressive but much harder to communicate, and the player has to be able to see
what a choice forecloses *before* making it. One group renders as one boxed set
labelled "one of these."

**The depth dial is what fraction of a system's options share a group:**

| Tier (`MapGen.tier(danger)`, 1–5) | Options | Grouped |
| --- | --- | --- |
| 1 — rim | 2–3 | none |
| 2 | 2–4 | one pair |
| 3 | 2–4 | one pair, sometimes two |
| 4 | 3–4 | most in one group |
| 5 — core | 3–4 | all one group: pick exactly one |

Counts stay flat. Only the last column moves. Numbers are a starting point for
the sim to argue with, not a ruling.

---

## 5. Rolling a system

In `_roll_here()`, for a non-station node, seeded from
`Rng.derive(&"options", n.index)`:

1. Filter the pool by the node's axes — `danger`, `region`, `development`,
   `security`, `berths`, `manufacturer`, `fauna`. **All of these are already
   generated and richly derived, and `EventTable.pick_key()` reads none of
   them.** That is most of what makes the current 14 events feel same-y: a whale
   fall can appear in the core, a customs cordon in unclaimed space.
2. Draw count by tier, weighted, without replacement.
3. Assign groups by the tier table.
4. Store ids on the node. Do not instantiate callables here.

**One fight option is not guaranteed and neither is its absence.** Both come out
of the pool honestly.

### Reward classes — what each kind of option pays

Ruled 2026-08-24, and it answers the problem that every option being voluntary
would otherwise create: a cold ship taking only safe options never fights, and
the deck of modules is the game.

**Fights and the wrecks they leave are where modules and rarity come from.**
Not "fights pay more" — a multiplier would just make the greedy line the violent
one and flatten the choice the exclusivity dial exists to create. Instead the
*kind* of payout differs:

| Tag | Pays |
| --- | --- |
| `fight` | modules, and the only reliable access to the top of the rarity ladder |
| `salvage` | modules at lower rarity; hulls; relic fragments deep |
| `signal`, `claim`, `contract` | credits, fuel, materials, archive entries, standing — rarely a module, never a good one |

This mostly **formalises what already happens** rather than inventing a rule.
`LootGen.roll_module()` is the fight and derelict payout, `Market` is the station
one, and of the fourteen current events exactly one drops a module.

The rarity ladder already does the high-risk half by itself:
`LootGen.roll_module()` refuses EPIC below danger 3 and LEGENDARY below danger 4,
and upgrades rarity at `0.06 * danger`. So deep fights are already the only door
to the best parts — nothing new is needed, it just must not be duplicated
elsewhere.

**The pacifist line stays playable and gets poorer in the currency that
matters.** A player who takes only safe options accumulates credits with
progressively less worth buying: stations are sparse, a shelf is a handful of
parts, and `Market` prices scale off the same rarity table. The deck starves on
its own, with no forced encounter and no reward multiplier. That also gives
stations more weight, which suits their being the one telegraphed safe node.

**The exclusivity dial stays free to do its own job.** Deep systems can put the
fight and the safe thing in one group, so skipping the fight costs something
specific and legible rather than costing an abstract percentage.

---

## 5a. What the galaxy resize does to this

`GALAXY_SCALE.md` lands `LAYERS := 15` with ring spacing decoupled, sparse
coreward links, and per-kind `density`. Three consequences for this design, and
they are not small.

**Systems roughly double: ~157 today to ~287, and up to ~1.3x that again on a
high-`density` galaxy.** Every one rolls its own option list. Two things follow:

- **Rolling must stay cheap.** Store ids, resolve to definitions lazily.
  `EventTable.build_all()` currently reconstructs all fourteen dictionaries and
  every closure on each call — including from `by_key()`, which then linear
  searches. At 287 systems that pattern is no longer merely wasteful.
- **The content bill roughly doubles with it.** §9's volume note was written
  against a ~65-jump run. Against 287 systems and 25–35 actual jumps it is
  worse, and repetition will be the first thing anyone notices.

**Sparse coreward links change what an option is worth.** Today lateral travel
is optional, so a system you dislike is free to skip. Afterwards, crossing a
ring is work, and a system you must pass through is one you will take the
options at. That makes the exclusivity dial (§4) do more work than it does in a
galaxy you can dive through, and it is an argument for keeping counts at the low
end of 2–4.

**Region gating gets sharper.** More systems per ring means `region`,
`development`, `security`, `berths` and `fauna` spread further apart, so gated
options genuinely cluster instead of being smeared over a handful of nodes. This
is the change that most rewards §5's gating — and the same one that makes an
ungated pool most obviously repetitive.

**Ordering:** this brief's §7 should land *before* `GALAXY_SCALE.md` §5, the
chart primer — otherwise the primer documents a legend that is about to lose
four of its six entries.

---

## 6. Ambush

`_roll_ambush` and `n.ambush` go away as node state. An ambush becomes an
**interrupt on arrival**: roll against `Run.ambush_chance(n)`, and on a hit open
a normal fight from `DB.fight_pool(n.danger, n.region == FAUNA)`. It already
*is* that — `_roll_foes()` draws from the same pool — it is just wearing a
costume.

Three things to preserve:

- **`share = false`.** The roll comes off the `Rng.foe` stream salted per seat,
  specifically so four ships at one system do not all get jumped. Two players'
  ambushes at the same node are different events that share an address; joining
  one to the other joins a fight that is not there.
- **It does not consume the system.** The options are still there afterwards.
- **The heat curve is unchanged and correct.** `signature()` gates it — below
  `SIGNATURE_FLOOR` of 0.25 nothing finds you at all, which is the promise that
  a player who decided to run cold has bought silence. Danger scales it. Stealth
  divides it last, capped at 60% off, so the hull and modules you fitted answer
  a problem your own throttle created.

This makes heat a genuine map-layer mechanic for the first time.
`coop-design.md` §0 measured that outside combat it was read by a shader, a
label and an audio warning — all cosmetic.

**Worth considering (not decided):** let signature also bias which options
appear, not just whether a fight interrupts. Fly hot and the distress beacon is
bait, the mining claim already has someone working it. Same machinery, and it
turns heat from a tax into a modifier on the whole system.

---

## 7. What collapses

Node type stops being behaviour. Today it is dispatched across **five parallel
`match n.type` statements** that nothing checks for agreement:

- `Router.resolve_current_node()`
- `Router.engage_here()`
- `SectorScreen._on_action()`
- `SectorScreen._quiet_lines()`
- `StarchartScreen` — the legend at :201, `_type_label()` at :461, and the icon
  match at :855

Adding a type means editing all five. `coop-design.md` §16 already proposes a
runtime `NodeType.WRECK`, which would be a sixth. After this rebuild
`NodeType` holds START, STATION, GOAL and SYSTEM, and everything else is data.

`SectorScreen` renders a list of options instead of one action button, so
`_quiet_lines()`'s two-element `[line, label]` array goes away with it.
`EventScreen` either becomes the option-detail view or is absorbed into the
sector — see §9.

**On the chart:** the icon set drops to station, start, core. The information
does not disappear, it moves — `danger`, `region`, `security`, `berths` and
`fauna` all still exist and must now carry route planning on their own. That is
a `StarchartScreen` job and that file is 4,260 lines. Budget for it separately.

---

## 8. Balance, and the sim

**The target is a high base win rate.** Ruled 2026-08-24, and it changes what
this section is for. At 16/22% nothing in this game can be tuned: when a run
fails there is no way to separate the build from the economy from the draw, so
every measurement arrives buried in noise. A generous, legible base is the
precondition for tuning anything else — including whatever difficulty ladder
gets designed later, which is **out of scope here and not assumed by anything
below**.

A likely consequence worth watching: `DB.ACTIVE_MANUFACTURERS` is `[korvan]`
(blocker B4) because six switched on made things worse. If the base game becomes
winnable, that constraint may simply dissolve — difficulty stops needing
scarcity to enforce it.

**So the baseline is for attribution, not for holding a line.** Bank it before
touching anything:

```bash
godot --headless --path tkg -- sim runs=500
```

Record win rate, avg jumps, avg kills, avg danger reached, strand rate, and the
heat lines. Every change in this brief moves the economy, and the point of the
baseline is to know *which* change moved it — not to prove the number stayed
put. It is expected to rise.

**The sim is part of the feature.** And per `GALAXY_SCALE.md` §4 it will also
need to report **per galaxy kind** — fifteen kinds that genuinely play
differently make a single win rate an average over fifteen games. `HeadlessSim`
today has a fight policy and a hand-rolled ambush block around :190. It has no policy for *choosing among
options*, because nothing has ever offered it one. A naive take-everything model
will overstate income badly and will never exercise the exclusivity that is the
entire point of the depth curve. The model needs at minimum: a greedy policy, a
risk-averse policy that declines checks below some odds, and the ability to
report *what it left behind* at grouped systems.

Until that exists the rebuild cannot be measured, only played.

---

## 9. Open

- **Does `EventScreen` survive?** An option with four outcome bands and prose
  wants a screen. An option that is "strip the wreck" does not. Cleanest is
  probably: options resolve in place on the sector, and only those with a `body`
  and a check open the detail view.
- **`content_fingerprint()` must learn about the option table.** It currently
  hashes module ids, enemy ids, hull manufacturer/weight pairs and affix names.
  Two builds with different option tables would derive different lists at the
  same node index, agree on the fingerprint, connect — and their claims would
  point at different options. This is the same class of bug as the unbumped
  `PROTOCOL`: the guard exists and does not cover the new thing. **Add option
  ids to the fingerprint in the same commit that adds the option table**, not
  afterwards. `GALAXY_SCALE.md`'s `density`/`reach` want the same treatment for
  the same reason — two peers on different galaxy tables would lay out different
  maps from the same seed.
- **Save version.** `MapNode` gains fields, so **`SaveGame.VERSION` bumps 14 → 15**, not 13 → 14 — `be37b3e` already stamped 14 during the attributes work,
  and the old shape is discarded per the header rule. `GALAXY_SCALE.md` does
  **not** need one — `LAYERS`, `RING_SPACING`, `density` and `reach` change what
  gets generated, not the serialised shape — but if both land in the same window,
  two branches must not both stamp 14. That file's ladder records exactly that
  happening at 6 and again at 8. `version_guard.py` now catches the key-rename
  half of this automatically; it does not catch two branches picking the same
  number.
- **Content volume.** 14 events today. ~65 systems at 2–4 options needs an order
  of magnitude more, gated by region and danger or the same five appear
  everywhere. Read `docs/archive/events-batch-01-verification.md` first: 46
  outcome bands, 33% conforming, and the finding was that the whitelist's
  deferred list read like an inventory of the batch's own mechanics. Options
  that want to be remembered later are the best writing and the hardest to
  support.
- **Manufacturer-gated options can promise loot the game refuses to drop.**
  `MapGen` fills `berths` from **all seven** manufacturers regardless of
  `ACTIVE_MANUFACTURERS`, which gates loot only (`LootGen._allowed`). So
  `needs_berth` and manufacturer gating work fine today — but an option sited at
  a Verity berth that pays a Verity part will roll an option the loot filter then
  declines to fill. Either gate options by the active list too, or make the
  reward manufacturer-agnostic. Resolves itself if B4 dissolves (§8).
- **`PULSAR` and `DERELICT` become options, not types** — but the pulsar is
  placed deliberately against nebula clouds by `_seed_pulsars()` because a
  neutron star is a star's corpse and should not fall where the dice land. That
  placement logic has to survive the type going away.
