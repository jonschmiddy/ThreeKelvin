# Three Kelvin

A pixel-art, turn-based roguelite where **your ship is your character and your modules are your deck**. Chart an open galaxy at your own pace, fight ships and megafauna in telegraphed Slay-the-Spire-style combat, and chase Diablo-style loot.

*FTL's ship fantasy × Out There's lonely exploration × Slay the Spire's combat × Diablo's loot.*

Named after the temperature of the cosmic microwave background — the universe's leftover warmth, three degrees above absolute zero. A heat-management game named for the cold.

---

## Running it

Godot **4.7.1**. Open the project and press F5. Migrated from the original 4.3
target with no code changes — `docs/handbook.md` has the record.

Art is **generated procedurally as a fallback** (see `scripts/ui/ShipView.gd`).
Real sprites load where they are present: hull pictures for Korvan and Solari,
most module sprites, the enemies and the card illustrations. Run `-- artcheck` to
see which.

First clone? Run `./setup.sh` once — it points git at the hooks in `.githooks/`,
which git cannot do for you.

### Balance simulator

```bash
godot --headless --path . -- sim runs=200
```

Plays complete runs with a competent-player model and reports win rate, average jumps, kills, and death causes. **Run this after any balance change.** In the earlier web prototype this tool found three real bugs and a structural map flaw within minutes. There is no win-rate target: read the death causes (`docs/design-doc.md` §Pillar 5 and `CLAUDE.md`).

---

## Documentation

Everything that is prose lives in [`../docs/`](../docs/) — the design doc, the
co-op rulings, the netcode, and the art and audio notes. Start at
[`../docs/README.md`](../docs/README.md).

`CLAUDE.md` in this directory is the working memory for the codebase itself: the
rulings, the traps, and the dev flags. It stays here because it is loaded from
here.

---

## Architecture

```
scripts/
  autoload/       Sig (signal bus) · Database (content) · RunState (Run) · Router (screens) · Rng · Audio · Keys
  data/           Typed Resources: CardData, ModuleData, HullData, EnemyTemplate, AffixData…
  systems/        Combat, CardResolver, DeckBuilder, LootGen, MapGen, OptionTable (the encounters)
  net/            the co-op party: NetSession, the transports, SharedFight
  ui/             Code-built screens and widgets, UITheme, Hints, Ash, procedural fallback art
  sim/            HeadlessSim and the headless harnesses (`-- <flag>`)
shaders/          the screen and sky shaders, heat.gdshader among them
tools/            export.sh and build_alpha.sh (builds), cofight.sh / coplay.sh (co-op), export_resources.gd
resources/        (made by export_resources.gd when run; not in the repo)
```

**Content is authored in `Database.gd` as plain dictionaries**, seeded into typed Resources at boot. It diffs cleanly in git and needs no editor round-trip. When you want inspector editing instead, run `tools/export_resources.gd` and the same data becomes `.tres` files.

**UI is built in code**, not `.tscn`. Two scene files exist (`Shell.tscn`, the main scene, and `Main.tscn`); everything else is constructed by the screen scripts against `UITheme`. This keeps styling in one place and avoids scene-merge conflicts.

**Systems never reach across scenes** — they emit on `Sig` and the UI listens.

---

## Design rulings already baked in

These were settled during design and prototyping. Don't re-litigate them without a reason.

> **`tkg/CLAUDE.md`'s rulings table is the authority.** This one is a shorter
> read for newcomers and has been a revision behind more than once — it carried
> "hulls have no manufacturer" and "one currency: scrap" for months after both
> were overturned. When the two disagree, CLAUDE.md is right; fix this one.

| Ruling | Why |
|---|---|
| **Hulls ARE built by a manufacturer** — seven branded chassis × three weights × four grades, plus three unbranded salvage frames | REVERSED from "hulls have no manufacturer". Every manufacturer attribute signature (thermal capacity, dodge, hull mass) is a chassis property, so the old ruling was unimplementable. The hull counts as one toward its own set, and swapping now moves your set count — an accepted cost. |
| **Set bonuses are the class system** (3+ / 5+ modules from one manufacturer) | Identity is *assembled mid-run*, not chosen at the start. Every drop is a commitment-vs-flexibility question. |
| **Charge fires automatically** when ready | Tension lives in *when you start* charging, not in a release button. |
| **Overheat = predictable self-damage**, 1 hull per point over cap, no cliff, no cap on heat | Heat becomes a second health bar you can choose to spend. Since repairs cost credits, overheating burns money. |
| **The deck only reshuffles at the start of your turn** | Without this, zero-cost draw cards (Emergency Vent, Jury-Rig, Foresight) loop forever once the discard recycles. Also makes deck size strategically meaningful. |
| **Your attacks never miss; only enemies can** | Player-side miss RNG feels awful in telegraphed combat. Light hulls dodge incoming fire. |
| **Ballistics run cold, energy weapons run hot** | Gives materials a readable thermal language before you read the numbers. |
| **Ships use fixed intent loops; fauna use weighted random pools** | Machines are predictable, animals are not. Legible worldbuilding through mechanics. |
| **Bosses are hand-tuned, not danger-scaled** | A boss-grade stat block appearing as a random encounter is a run-killer. |
| **HP scales faster than damage with danger** | Deeper fights should be *longer*, not one-shot lethal. |
| **Lateral map travel is cheap and always available** | You can farm a danger band before descending, so every death is self-authored. This is the greed clock. |
| **One currency: credits** | Repair, upgrade, and purchase all compete for the same pool. This is where the difficulty actually lives. RENAMED from scrap, not re-ruled — `scrap_value` and `scrap_module()` keep their names, because scrapping is still the verb and only the unit changed. |

---

## The balance insight that matters most

Simulation of the prototype showed **individual fights are not the difficulty — the economy is.** A starter deck beats a danger-5 Cutter for about nine hull. What ends runs is cumulative attrition against expensive repairs.

So when tuning: **raise repair prices before touching enemy damage.** If repairs are cheap, heat becomes decorative and the whole risk structure collapses.

---

## Manufacturers

Seven, each a playstyle, a worldbuilding hook, and an affix pool. Mirrored pairs drive the appetite to try the next unlock.

| Manufacturer | Identity | Mirror of |
|---|---|---|
| **Korvan Heavy Works** — *"It fires. Every time."* | Ballistics (cold, multi-hit, Salvo) + ordnance (Charge) + heat-costing persistent armor | Solari |
| **Solari Foundry** | Weaponised heat: damage scales with your own fever, deliberate overheating | Korvan |
| **The Probate Combine** | Scrap economy, armor sustain, wins slowly and richly | Redline |
| **Redline Shipyards** | Salvage tech, evasion, refits, innate contraband affinity | Probate |
| **Verity Ateliers** | The thin perfect deck: few slots, pre-upgraded cards, expensive everything | — |
| **Cygnet Dynamics** | Autonomous drones that fight and intercept | — |
| **Calyx Biosystems** | Regeneration and cards that mutate through use | — |

Korvan is the starter loadout: it teaches energy, charging, and heat honestly.

---

## Rarity ladder

The top tiers are **sources**, not just bigger numbers:

- **Common → Legendary** — manufactured; affix count and quality scale up
- **Exotic** — grown/harvested; megafauna-derived, organic mechanics
- **Artifact** — precursor relics; never manufactured, rule-breaking, manufacturer-agnostic

**Contraband is a tag, not a tier.** Any module can be an illegally-modified variant: above-curve power, and map-layer risk from station inspections. Lawless space doesn't inspect; cosmopolitan space inspects thoroughly.

---

## Next up

`HANDOFF.md` at the repo root has what is open and what comes next; `CHANGELOG.md`
has what each alpha holds.
