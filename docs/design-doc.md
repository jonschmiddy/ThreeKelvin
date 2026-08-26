# THREE KELVIN — High-Level Design Document
*Titled after the temperature of the cosmic microwave background: the universe's leftover warmth, three degrees above absolute zero. A heat-management game named for the cold. Draft v0.2 — living document.*

---

## High Concept

A pixel-art, turn-based roguelite where **your ship is your character and your modules are your deck**. Chart an open star map at your own pace, fight ships and space megafauna in Slay the Spire–style telegraphed combat, and chase Diablo-style loot — modules, and even hulls, drop with rolled stats and affixes. Start each run in a shitbox; end it in a legend (or a debris field).

**Elevator pitch:** *FTL's ship fantasy × Out There's lonely exploration × Slay the Spire's combat × Diablo's loot.*

---

## The Setting

*Added 2026-08-20. The premise the title has been carrying since v0.1, written down.*

### The opening

> The last stars are going out on a schedule nobody can argue with. What's left of the warmth is scattered — banked in dead reactors, cooling in the bones of things that swim between systems, buried in wrecks older than anyone who could have built them — and there are still ships out here collecting it. They say that if you gather enough of it in one place, in the right place, you can start it all over again. Nobody knows if that's true. Nobody has come back to say. So you fly in cold and quiet, because heat is the only thing left worth taking and everything still alive out there can feel you carrying it. And then you take more anyway. That's the job, and it's how you'll die: not because the dark found you, but because you went one jump deeper for one more ember, and the long way home got longer.

Short, for a title card: *The universe is going out. Somewhere at the bottom of it there's still one warm thing. Bring it home, or die a little closer to it than you were.*

The last sentence of the long version is load-bearing. It is Pillar 3 — *greed is the clock, deaths are self-authored* — stated as fiction rather than as a rule, so a player who reads the intro already knows how the game is going to kill them and has agreed to it.

### What it is

**The universe is running down, and the last people in it are going around collecting warmth.**

That is the whole of it. Stars are going out on a schedule nobody can move. What is left is scattered — in old hulls, in the cores of dying things, in wrecks that predate anyone who could have built them — and there are ships out here gathering it, because somewhere ahead of them is the idea that if you collect enough of it in one place you can start something again.

**Nobody knows whether that is true.** The game never says. It is entirely possible that this is a rescue, and entirely possible that it is a very long, very cold delusion held by people who cannot accept the alternative — and the run ending with the ember in the hold does not settle it. The doubt is the tone. A crew flying nine shells into the dark on a theory is more interesting than a crew flying nine shells into the dark on a certainty, and it is the only framing under which *greed is the clock* reads as tragic rather than merely mechanical.

### What this explains that was already built

The fiction was reverse-engineered from the mechanics rather than the other way round, which is why it fits without any of them changing:

- **Heat is the resource you cannot hold.** Every hull leaks it, capacity is small, and carrying more than yours burns you. That is the game's argument about warmth stated as a rule, and it was in the first prototype.
- **Warmth is what everything comes toward.** A hot ship attracts an ambush on the map and draws the enemy's fire inside a fight — see `coop-design.md` §6 and §15. In a universe going out, heat is the only thing left worth taking, so this is not a difficulty knob. It is what the setting does to you.
- **The ember cannot be carried out alone.** §13's carrier runs permanently hot, cannot vent, cannot hide, and lights up the entire convoy. If the ember is a seed rather than a trophy, that rule stops being a balance decision and becomes the point: the thing worth saving is the thing that makes you visible to everything that wants it.
- **The core is not a boss arena.** Something is guarding the last warm place. Whether it is guarding it *from* you or *for* you is not answered either.
- **Three Kelvin is a measurement, not a metaphor.** The leftover heat of everything that has already happened, three degrees above nothing. The title was always the premise.

### What it does not license

No prophecy, no chosen crew, no faction explaining the cosmology in a text box. The people out here are salvagers with a theory and a fuel budget. Keep the fiction in the ship names, the log lines, the wrecks and the silence — the same places it already lives.

### Who is paying for it

`docs/lore.md`, added later, answers the question this section left open — who buys the heat and why anybody would fit out a stranger to go and get it — **without** repealing the paragraph above. Its one idea: *corporations are eternal and they are buying heat; people are temporary and they want scrap and credits; you are a person, and the eternal things will not tell you what the heat is for.*

That frame is what lets the game have lore at all under this ruling. Nobody explains the cosmology because the people who could are not talking and the things that are talking are not people — so the silence stops being an authorial choice the player has to tolerate and becomes a fact about the world they can be angry at. The archive that carries it is primary sources only: manifests, riders, receipts, transponder loops. Never a narrator.

---

## Design Pillars

1. **The ship IS the character.** No crew micromanagement. A neutral hull plus the modules you find define your build. All progression, customization, and expression flows through the parts.
2. **Loot is the engine.** Frequent drops, rarity tiers, rolled affixes. Every module you install adds cards to your combat deck — loot literally *is* deckbuilding.
3. **Greed is the clock.** No pursuing fleet. Danger (and loot quality) scales with how deep you chart into hostile space. Deaths are self-authored: you pushed one jump too far.
4. **Readable builds.** Your ship's sprite visually changes as modules are installed. Anyone can look at a ship and tell what it's building toward.
5. **The ceiling is meant to break.** A build that comes together should feel absurd — not balanced, not "strong for its tier", genuinely overpowered, and briefly. That is the reward Pillar 2 is paying out and the reason anyone runs the clock in Pillar 3. **Sometimes** is doing the work in that sentence: the average run is punishing, the peak is not, and the gap between them is the fantasy.

---

### Reading the simulator against Pillar 5

The headless sim prints a win rate and a healthy target of 40–55%. The game runs at 15–24% and that is not a bug to be fixed — it is Pillar 3 and Pillar 5 in the same number. Most runs end because you pushed one jump too far; some end with a ship that should not exist.

**So a change that raises the win rate is not automatically a regression, and a change that raises the CEILING is usually the point.** The reactor becoming a single level that grants cells and energy together took the sim from 15% to 20% and jumps from 47 to 60, because a coupling can now cross an energy step. That was flagged as a reversed ruling and it is: modules were forbidden from granting energy. The ruling loses. A part that makes the reactor bigger should make the reactor bigger.

What still matters is that the FLOOR stays honest. A run that never had the option was stopped by arithmetic; a run that spent its option and pushed anyway authored the death. Watch the death causes, not the win rate.

---

## Core Loop

**Run loop (macro):**
Jump to a system → resolve what's there (combat / event / planet / derelict / station) → collect loot & resources → manage ship (install, scrap, repair, reconfigure deck) → choose next jump (risk vs. reward gradient) → push deeper or bank progress → die or achieve run goal → meta-progression.

**Combat loop (micro):**
See enemy intent → draw hand from module-generated deck → spend reactor energy playing cards (attack / defend / utility) → end turn → enemy executes telegraphed move → repeat until destruction, escape, or (for some entities) pacification.

---

## Combat System

Slay the Spire grammar adapted to ships:

- **Energy = reactor output.** Your hull's reactor determines energy per turn. Upgrading reactors (or hulls) is upgrading your energy curve.
- **Hand size = hull weight class.** Light hulls draw few cards but are evasive, cheap to fly, and get the opening move; heavy hulls draw big hands and tank, but dodge poorly, pay more fuel per jump, and can be alpha-struck. Consistency (card draw) is deliberately expensive.
- **Heat (BattleTech lineage):** cards generate heat as a printed byproduct (energy remains the only cost you *pay*). Hulls have heat capacity and dissipation-per-turn — **heavy hulls: big capacity, poor dissipation (burst rhythm); light hulls: small capacity, fast dissipation (sustain rhythm)**. **Overheat rule: at end of turn, take 1 hull damage per point of heat above capacity.** No caps, no shutdowns — heat is a second health bar you can choose to spend (StS Offering/Bloodletting energy), and since hull repair costs credits, overheating literally burns money. Venting is a real action. Heat sinks are a module/loot category. An affix cannot be one: affixes pay in ship attributes and never touch a card's printed heat, so "generates 0 heat" is a thing a MODULE can be authored to do and a thing a roll can no longer grant. See the affix bullet below.
- **Asymmetric miss rule:** enemy attacks can miss you (dodge lives on the incoming side); **player attacks never miss**. No player-side miss RNG in telegraphed combat.
- **Initiative = ambush & escape,** not turn order: determines who acts first when an encounter opens and how feasible fleeing is. Battleships don't sneak away.
- **Deck = installed modules.** Each module contributes specific cards to the deck (e.g., a Burst Laser adds 2× "Fire Burst Laser"; a Shield Capacitor adds "Overcharge Shields"; an alien relic adds something weird). Swap a module, reshape the deck.
- **Enemy intent is telegraphed.** Enemies show what they'll do next turn (attack values, charging big moves, buffs, spawns). Skill = sequencing your response.
- **Block/shields decay or persist per defensive module rules** (design space: some shields carry over, most don't — mirrors StS block vs. barricade).
- **Starter hulls are bad on purpose:** tiny reactor (2–3 energy), few module slots, weak base cards, possibly dead "Malfunction" cards clogging the deck. Progression is *felt* in combat.

**Enemy variety:**
- **Ships** — faction-flavored, drop modules/credits, may have 1–2 destructible parts (kept minimal; full FTL subsystem targeting is cut to reduce per-turn friction).
- **Space megafauna** (whales, spore clouds, void leviathans) — biological telegraphs, no module drops (drop organic/exotic crafting materials instead), some can be **pacified or befriended** rather than killed, feeding the event layer.

**Open combat questions:** hand size, draw rules, card upgrades (do modules level up?), status effects, escape mechanics, multi-enemy encounters.

---

## Loot & Affix System

- **Module drops are frequent; installation is constrained.** Constraint = reactor budget + hull hardpoint/slot limits. Inventory is a hand of options; the build puzzle is what fits.
- **Rarity ladder — top tiers are sources, not just bigger numbers:**
  - **Common → Uncommon → Rare → Epic → Legendary:** manufacturer-made; affix count and quality scale up the ladder.
  - **Exotic:** grown/harvested — megafauna-derived and crafted from exotic materials; organic mechanics.
  - **Artifact:** precursor/alien relics — never manufactured, found in anomalies and deep-core ruins; rule-breaking effects. Any faction can chase them.
- **Contraband is a tag, not a tier.** Any module can exist as an illegally-modified variant: above-curve power, safety-limiter-removed affixes. Carrying contraband creates map-layer risk — station inspections roll against your contraband load (fines, confiscation, or a fight you can't afford). Generates: smuggling-compartment modules, lawless stations (no inspections, worse prices), Redline's innate smuggling capacity, and a whole event category. Inventory itself becomes a risk decision.
- **Rolled affixes** on modules pay in **ship attributes** — hull, thermal, maneuverability, sensors, stealth, reactor, thrust — and never in card behaviour. Examples: *Reinforced — +1 HULL*; *Stripped — +2 MANEUVERABILITY, −1 HULL*; *Deregulated — +2 REACTOR, −1 STEALTH* (contraband).
    - **REVERSED 2026-08-25.** This bullet used to read *"modify both stats and card behavior"*, with three examples — draw-on-kill, charge-on-damage, cost-reduction — that are now impossible by design. The reason is a rule worth keeping: affixes wrote into card fields, and `CardData.describe()` prints one clause per non-zero field, so three affixes grew a card's rules text out of the bottom of a 93×39 box. The deeper cost was that two copies of the same card read differently depending on which module granted each — **a card you cannot learn is a card you re-read every time it appears.** The variance moved to the attributes panel, which has a column to say it in where a card face had thirty-nine pixels. See `AffixData.gd`.
- **Manufacturer-branded modules** have themed affix pools; **set bonuses** for running 3+ modules from one manufacturer.
- **No dead loot — unified credit economy:** unwanted modules are **scrapped** into credits, the game's single primary currency: it repairs hull, funds crafting, and pays for all station services. Repair vs. upgrade vs. save-for-that-hull is one budget fighting itself (FTL's scrap economy × Diablo's trash-loot-as-income). *A rename, not a re-ruling — `scrap_value` and `scrap_module()` keep their names, because scrapping is still the verb and only the unit changed. The rename is what made a HOLD make sense: scrap is a substance and sits in cargo, credits are a number and do not.*
- **Exotic materials** (megafauna organs, relic fragments) are a rare secondary currency for special crafting only — keeps whale hunts and anomalies uniquely rewarding without complicating the core economy. *Settled: one wallet. Exotic materials remain the only secondary, and craft-only.*
- **Hulls are loot too** (see below).

---

## Hulls: Size & Tier

> **REVERSED, and this section is kept because the reasoning still matters.**
> This used to read *"Hulls have no manufacturer"* — a chassis was two axes and
> nobody's manufacturer, so a hull swap stayed a pure power decision with no identity
> whiplash. **Hulls CARRY a manufacturer now:** seven chassis × three weight classes ×
> four grades, plus three unbranded salvage frames, and the hull counts as one
> toward its own set bonus.
>
> What forced it: `attributes-and-checks.md` §1.5 gives every manufacturer an
> attribute signature, and every one of those — thermal capacity, dodge, hull
> mass — is a property of a chassis, not of a bolt-on module. Under neutral
> hulls that section was unimplementable.
>
> **The cost was real and was accepted: swapping hulls now moves your set
> count.** The authority is `CLAUDE.md`'s rulings table; this paragraph is a
> pointer to it, not a second copy.

A hull is a chassis defined by two axes plus its manufacturer:

- **Weight class:** Light / Medium / Heavy. Sets hand size, dodge, initiative, fuel cost per jump, heat capacity/dissipation, and HP/slot baselines. Light sustains and evades; heavy bursts and cooks.
- **Tier:** C / B / A / S (NMS-style). Sets the *ranges* for reactor output, slot count, HP, and heat stats.
- **Stats roll within tier ranges,** so a god-rolled B-tier medium can rival a badly-rolled A-tier. Hulls are Diablo loot.
- **Each hull carries its manufacturer's perk,** at every grade, plus what the grade adds on top. Perks are manufacturer identity, not chassis quirks — see `HullData` and `DB.TIER_PERKS`.
- **Mid-run hull swapping:** derelict or purchasable hulls can be claimed mid-run, transferring modules (slot limits permitting). Swapping moves your set count as well as your stats — that is the accepted cost of branded chassis.

## Manufacturers: Parts & Set Bonuses (the class system)

**Manufacturers make modules, not hulls.** Your build identity comes entirely from the parts you find and install — assembled mid-run rather than chosen at the start.

- **Set bonuses are the class mechanic.** 3+ modules from one manufacturer unlocks a tier-1 bonus; 5+ unlocks tier-2 (e.g. Korvan: charge weapons charge one turn faster). Committing sharpens your build; mixing stays viable but generalist. Every drop becomes a question about commitment vs. flexibility.
- **Runs start with a loadout, not a class.** Your starting module kit is the choice that replaces class selection — a Korvan surplus kit is a gunboat, a Cygnet kit is a drone carrier, same neutral chassis underneath. Unlocking a manufacturer unlocks its starting kit and its presence in loot pools.

The roster of seven:

| Manufacturer | Identity | Mechanics | Weakness |
|---|---|---|---|
| **Korvan Heavy Works** | *"It fires. Every time."* Ex-military surplus; ugly, riveted, reliable | Two lanes — **Ballistics** (cheap multi-hit kinetics, near-zero heat; Salvo) and **Ordnance** (Charge mega-weapons, banked payoffs) — plus heat-costing persistent armor (Brace). Full spec: `korvan-heavy-works.md` | Poor dissipation; low dodge/initiative; if the alpha misses the window, panic |
| **Solari Foundry** | Sun-worshipping industrial cult | Weaponized heat: plasma damage scales with current heat, deliberate overheating for payoff, offensive venting | Self-damage is real; heat-reduction loot is anti-synergy (inverted chase items) |
| **The Probate Combine** | Breaker yards that stopped competing and started invoicing | Credit & salvage galore: credits-on-kill, salvage→armor conversion, armor sustain, salvage bonuses from wrecks | Low burst, bad initiative; fights drag |
| **Redline Shipyards** | Chop-shop salvage-tech; jury-rigged refits | Stealth, refitting, stolen tech: evasion, initiative, mid-combat module reconfiguration, **innate contraband affinity** (smuggling capacity, black-market access) | Paper hull; cornered = dead |
| **Verity Ateliers** | Luxury manufacturer; waiting-list prestige (Origin Jumpworks energy) | The thin, perfect deck: few slots but modules pre-upgraded, retain/scry/card-selection, superb initiative & dodge | Everything is expensive: premium repair costs, won't interface with low-rarity modules, dainty heat capacity |
| **Cygnet Dynamics** | Hyper-tech drone specialist; wirey, more antenna than hull | Defect-style drone slots: autonomous per-turn triggers, drones intercept telegraphed hits, evoke/sacrifice for burst | AoE feasts on drones; sustained energy upkeep |
| **Calyx Biosystems** | Clean corporate biotech; sterile, faintly unsettling (NuCaloric energy) | Adaptation: cards mutate/evolve through use mid-run, hull regeneration, exotic-material scaling, megafauna symbiosis | Stations can't repair you well — you heal your own way or not at all |

**Roster notes:** Korvan/Solari are mirrored heat philosophies (manage it vs. surf it); Probate/Redline are mirrored salvage philosophies (melt it down vs. repurpose it). Mirrored pairs drive "try the next unlock" appetite. **Starter kit: Korvan** (teaches energy, charging, and heat honestly; legible power fantasy). The former relic-faction identity is dissolved into the Artifact loot tier — every faction can chase precursor tech.

**Visual identity:** modular sprite composition — hull chassis (shape reads weight class and tier) + module sprites snapped to hardpoint anchors, carrying manufacturer shape language and palette accents. Identity is *assembled*: a chassis launches with its hull and one branded weapon, which is 2 of the 3 a set needs, so you start pointed at a manufacturer and arrive at it later.

---

## Map, Exploration & Events

- **Procedurally generated galaxy each run.** Starting region at the safe edge; danger/loot rating scales toward the galactic core. Regions seeded with guaranteed anchors (≥1 station per region). Rumor threads generated as breadcrumb chains toward the run objective.
- **Seeded runs:** galaxy seeds are shareable for community challenges and comparisons.
- **Fog of war:** sensors and star-chart data determine what you can see; chart data is itself lootable/purchasable.
- **Manufacturer territories bias loot pools.** Regions are controlled or dominated by specific manufacturers, and their modules dominate local drops, shop stock, and derelict salvage. This is what makes set bonuses reachable by *choice* rather than luck: if you're two Korvan parts from "Full Broadside," you route through Korvan space to fish for them — trading the loot gradient (deeper = better) against build coherence (this direction = my manufacturer). Route planning becomes a build decision.
  - Territories are procedurally placed each run, so the same build plan doesn't work twice.
  - **Cosmopolitan sectors:** trade crossroads where multiple manufacturers sell side by side. Stations carry broad stock from many manufacturers you can browse and buy *deliberately* — the "shopping" region, versus territory's "fishing." Trade-off: higher prices and a lower rarity ceiling (Legendary/Exotic/Artifact don't move through legitimate open markets), plus high law presence and thorough contraband inspections. Where you go to fix a build gap. Tonally, the only crowded places in a lonely game — the emptiness reads louder after a crossroads.
  - Contested frontier regions have mixed *drops* — random, thin, nobody's territory. You take what you find.
  - Lawless regions: contraband variants common, no inspections, black-market fences carry high-rarity stock, worse prices on everything legitimate.
  - Fauna-dense regions (nebulae, migration routes): Exotic-tier drops and exotic materials.
  - Deep core / precursor ruins: Artifact-tier tech, manufacturer-agnostic.
- **Danger gradient = loot gradient.** Deeper/hostile space (nebulae, dead zones, core regions, alien territory) = harder fights, better drops. Fuel cost per jump scales with hull mass, tying weight class into exploration economics.
- **Node types:** combat encounters, narrative events, planets (landable, Out There–style surveying/harvesting), derelicts (hull + module loot, risk-laden), stations (see below), anomalies (relic tech, weirdness).
- **Stations = paid campfires.** All services cost credits: hull repair, module upgrades (improves **all** cards a module contributes — StS rest-stop analog), junk-card removal, shop inventory, chart data, fuel. Tension comes from the unified economy, not artificial pick limits — every purchase is credits not spent on something else.
- **Heat signature (map layer):** hot-running ships attract more encounters/ambushes; cold light ships can slip past. Suns and nebulae modify heat dissipation regionally, making route-planning a thermal decision for heavy hulls.
- **Events emphasize meaningful choice** over stat-check coin flips; outcomes should interact with build (e.g., options unlocked by installed modules or manufacturer reputation).
- **Run goal:** rumor/star-chart threads point toward a deep-space objective (jump gate home? derelict mothership? artifact?). Flavor TBD; melancholy "long way home" framing is the current lean.

---

## Meta-Progression

- **Unlock manufacturers** — each unlock adds a starting loadout kit and puts that manufacturer's modules into loot pools. **Unlock hull tiers/sizes** as available starting chassis.
- **Unlock starting regions / map layers** for run variety.
- Possibly a light permanent-upgrade layer (starting resources, reroll tokens) — kept restrained to protect run integrity. **Avoid** numeric power creep that trivializes early game.
- Death feeds knowledge + unlocks, not raw stats (lean toward StS/FTL-style unlock meta over Rogue Legacy–style stat meta). *Open question — revisit.*

---

## Tone & Art Direction

**Thesis: lush objects in a cold void.** Stardew Valley's craft density applied to space — but lushness is *detail density, not warmth*. The emptiness stays cold and lonely; everything in it is rendered with obsessive care.

- **Perspective: EDGE ON.** Flat side elevation, camera exactly level with the ship, no top surface, no foreshortening. Mounts live on the **dorsal line (top edge) and the ventral line (bottom edge)**, plus an aft mount and an upper spine. There is no far row and no near row, and nothing occludes anything else. Your nose points right, toward whatever you're facing.

  > **REVERSED.** This read *"top-down, hardpoints in mirrored port/starboard
  > pairs"* — and the argument for it was good: installing one module lighting
  > two visible mounts genuinely does read better than bolting a part onto a
  > side silhouette. **That is what was given up.**
  >
  > What decided it, over thirteen candidates across three cameras: edge-on
  > candidates read at 1×, the 3/4 ones did not; compositing a module meant
  > drawing it at a 45° tilt occluding correctly across two rows, where edge on
  > makes each one a flat sprite; and `ShipView._draw_weapon` had already
  > assumed edge on. Authority is `ART_CONTRACT.md` §2 and §2a.
- **The void is never flat black.** Deep indigo-to-black dithered gradients with nebula wash coloured per region — this is where most of the visual richness comes from at almost no asset cost, and it gives each region a colour signature (Korvan space rusty amber, fauna space teal bioluminescence, precursor ruins violet).
- **Objects are genuinely lush.** Weathered plating, stencilled hull numbers, decals, lit viewports with tiny interior detail, station windows with warm interior light and silhouettes moving inside, barnacles and scars on megafauna. Spend the pixel budget here.
- **Warm/cold survives as lighting logic, not a saturation cap.** Objects are richly coloured but *coldly lit*, with warm rim light from your own reactor and engines. Your heat glow reads because it's the only *self-emitted* warmth in frame.
- **Heat still drives the hull.** Cold and dark at 0; ember vents along the spine as it climbs; past capacity the ship is the brightest object on screen while taking damage. Warmth = life = danger.
- **Resolution:** mid-res pixel art, native 960×540, shown at 1920×1080 (×2, integer). Ship sprites 150–248px wide so there's room for real detail. Modules snap to hardpoint anchors **measured per sprite** by `art/tools/anchors.py`; `-- mounts` checks all 89 against the sprite's own opaque pixels.
- **Silhouette reads chassis; modules read faction.** Hull outline communicates weight class (light frames narrow and open, heavy frames broad and slab-sided). Manufacturer identity lives in module shape language and palette accents: Korvan slabs/rivets/oversized barrels; Cygnet thin frames and antennae; Verity continuous curves; Calyx too-organic symmetry.
- **Melancholy comes from composition:** small ship, vast frame, generous negative space, sparse animation with strong impact effects.
- **Cards: hybrid UI.** Pixel art inside card frames, clean vector type on top — readability and localisation-proofing over purism.
- **Know the neighbour:** Cobalt Core exists. Differentiation: open-map loot game, modular ships, lush-cold industrial tone vs. its linear cartoon brightness.

## Screen Layout: One Grammar for Everything

**FTL's two-panel split, applied to every node type.** Your ship is *always* on the left. The right panel is whatever you're currently facing:

| Node | Right panel holds |
|---|---|
| Combat | Enemy ship or megafauna, with telegraphed intent |
| Station | Docking bay, lit windows, service list |
| Derelict | Dead hull, salvage readout |
| Event | Illustration and choice buttons |

Below the split: a context strip (enemy intent / dock services / event options) and your hand of cards. Above: the persistent HUD with hull, heat, economy, and live set-bonus progress.

This is a significant simplification — rather than separate Map/Combat/Station/Loot/Event screens, there is **one frame with swappable right-hand content**. Less UI to build, less to art, and the ship stops disappearing between fights, so it reads as a constant companion rather than a stat block. The star chart remains its own full-screen view.

---

## Scope Notes (Solo-Dev Reality Check)

Turn-based combat + node-based map + 2D pixel art = very buildable solo scope. Suggested MVP slice:
1 manufacturer, 2 hull tiers, ~15 modules/cards, 5 enemy types (incl. 1 megafauna), 1 map region, ~10 events, credit economy, no meta-progression yet. Prove the loop: *jump → fight → loot → reconfigure → jump.*

---

## Open Questions

- Final names for the luxury and biotech manufacturers
- Territory tuning: how strong is the local loot bias (70/30? 90/10?), how many territories per galaxy, do factions have reputation systems?
- Set bonus tuning: are 3/5 the right thresholds for a ~6-slot chassis? Do hull-innate cards count toward nothing (currently yes)?
- Contraband details: inspection odds, regional law levels, penalty ladder, how contraband variants generate
- Combat details: draw/discard rules, statuses, multi-enemy fights, exact escape mechanics
- Heat tuning: capacity/dissipation numbers per weight class, overheat penalty curve, venting cost
- Economy tuning: credit income rates vs. service prices; what do exotic materials craft, exactly?
- Fuel model: how soft is the constraint? What refuels you (stations, planet harvesting, whale... byproducts)?
- Galaxy generation specifics: size, region count, arm/core topology, run length target
- Win condition flavor & narrative frame
- Meta-progression depth (unlocks only vs. light permanent upgrades)
- Subsystem targeting: fully cut, or 1–2 destructible enemy parts?
- Planet landings: how deep does the Out There surveying layer go?
- Engine/tech stack (Godot is the obvious pixel-roguelite candidate — discuss)
