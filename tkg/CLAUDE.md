# Three Kelvin — project context

Pixel-art turn-based roguelite. Godot 4.3+, GDScript. Solo developer.
**Your ship is your character and your modules are your deck.**
*FTL's ship fantasy × Out There's exploration × Slay the Spire's combat × Diablo's loot.*

Named after the cosmic microwave background temperature — the universe's leftover
warmth, three degrees above absolute zero. A heat-management game named for the cold.

**This file is the index.** It was 1,120 lines and every one of them loaded into
every session, which is the wrong place for reference material: you need the rules
and the commands in context, and the screen-layout arithmetic only on the day you
touch a screen. The long half is `docs/handbook.md` and nothing was deleted in the
split.

| Read this | When |
|---|---|
| `docs/handbook.md` | Screen layout, art direction and generation, audio, the economy's internals, the two procedural engines, the manufacturer table, dev mode |
| `docs/design-doc.md` | What the game IS. Pillars, core loop, combat, loot, the setting |
| `docs/lore.md` | Who pays for all this, the archive's writing rules, contracts |
| `docs/coop-design.md` | What four players do to each other |
| `docs/netcode.md` | How four machines are joined, and what each protocol bump bought |
| `docs/art/ART_CONTRACT.md` | Before generating any art |
| `audio/README.md` | Before touching sound |

---

## How to work in this repo

- **Talk like a person in chat.** Plain sentences. No headers, no tables, no bullet
  scaffolding, no bold every third word. Say the thing and stop. Condense — if it fits in
  four sentences, use four. Lead with the answer, then the reasoning only if it is actually
  needed, and do not restate the question first. Be direct about problems, tradeoffs and
  things that are broken; brevity is about format, not about hedging or leaving things out.
  Use structure only when the content really is structured — a measured comparison, a list
  of files, a table of numbers — and that should be rare.
  This applies to replies in chat and NOT to the source comments or the design documents,
  whose voice is deliberate: they say WHY, they record what was measured, and they keep
  the reasoning behind a decision that was reversed.
- **Development happens in VS Code.** Godot's editor is used only to run the game (F5),
  read the Output panel, and host the language server. Do not create or edit `.tscn`
  files unless there is no reasonable alternative.
- **UI is built in code**, not scenes. There is exactly one scene, `scenes/Main.tscn`.
  Screens are `Control` subclasses that construct their own children against `UITheme`
  and `Widgets`.
- **Content is data, not code.** New modules, cards, enemies, hulls, affixes and archive
  entries go in `scripts/autoload/Database.gd` as dictionary entries. `CardResolver`
  already handles every effect field on `CardData`, so a new card should require zero new
  logic. If you find yourself adding a `match` on card name, stop — add a field to
  `CardData` instead.
- **Systems never reach across scenes.** They emit on `Sig` (the signal bus autoload);
  UI listens.
- **Never call the global `randi()`/`randf()`/`pick_random()`/`shuffle()` for
  anything that decides something.** Draw from a named stream — `Rng.world`,
  `Rng.loot`, `Rng.event`, `Rng.foe`, `Rng.fight` — so that a run replays from
  its seed and one system's rolls cannot move another's. Anything a player can
  reach out of ORDER (a station's shelf, a wreck's contents, a station's job
  board, what is waiting at a node) uses `Rng.derive(tag, node.index)` instead, so
  it depends on WHERE it is rather than on when it was asked for. Cosmetic rolls —
  audio pitch, damage jitter, the title screen's galaxy — keep the global
  generator on purpose. `Rng.gd`'s header has the reasoning; `-- rngtest` enforces it.
- **Indentation is tabs.** Godot requires it.
- **Static typing where practical** (`var x: int = 0`, typed arrays, `-> void`).
  Typed array assignment from literals often needs `arr.assign([...])` rather than
  `arr = [...]`.

---

## The shape of the code

Six autoloads and one scene. Everything else hangs off them, and the ten most
connected things in the codebase are these six plus `Combat`, `MapGen`, `Widgets`
and `ShipView` — measured, not asserted: `graphify-out/graph.json` holds the graph
and `GRAPH_REPORT.md` its god nodes.

| Autoload | Holds |
|---|---|
| `Run` (`RunState`) | The run. Hull, hold, credits, heat, fuel, map, position, contracts, standing. A SINGLETON, so one process holds exactly one ship — which is why a co-op partner is a second process and why `Net` exists |
| `DB` (`Database`) | Every content table, seeded at boot. Modules, cards, hulls, enemies, affixes, manufacturers, archive documents |
| `Rng` | Five named streams plus `derive()`. See the rule above |
| `Router` | Which screen is up, and what an arrival at a node means |
| `Sig` | The signal bus. Systems emit, UI listens |
| `Net` (`NetSession`) | The party. Inert in the solo game — no peer, no cost, until somebody hosts or joins |

```
scripts/
  autoload/   Run, DB, Rng, Router, Sig  (+ Audio)
  data/       plain resources — CardData, ModuleData, HullData, ShipBuild, ContractData
  systems/    rules, no UI — Combat, CardResolver, MapGen, Market, LootGen, SaveGame,
              Contracts, Archive, Unlocks
  net/        the party — NetSession, SharedFight, the transports, the bot
  ui/         one Control subclass per screen, built in code
  sim/        headless harnesses and contact sheets. Everything under `-- flag`
```

---

## Run and test

Every one of these is a claim somebody could not check by looking. The right-hand
column is the whole point: a harness you do not know when to run is a harness that
does not run.

```bash
godot                                          # then F5
godot --headless --path . --import             # REQUIRED after any new class_name,
                                               # and once on a fresh clone
.github/scripts/validate.sh                    # the merge gate, from the repo root
```

| Command | Run it after |
|---|---|
| `-- sim runs=200` | **any balance change.** ~4 min. `seed=N` makes a whole sweep reproducible |
| `-- market` | touching `Market.gd`. 12,600 checks that the market cannot be gamed |
| `-- contracttest` | touching `Contracts`, standing or `Market` — it drives standing to 40 and proves a part still cannot sell or melt for its own price, which `-- market` cannot reach |
| `-- repairs` | touching `heal` or `heal_scale`. What a repair is worth at full, half and three hull — a dial you cannot read off the data |
| `-- content` | adding cards or modules. A MEASUREMENT, not a gate: prints unique cards per house against the target — Korvan 40, unbranded 20, malfunctions 15 — and passes either way. Counts unique NAMES, so two modules granting the same verb are one card |
| `-- parts` | touching modules, `ModuleIcon` or the hold's cell size. Every module in the game at its own footprint, grouped by house. The sibling of `-- cards`, and dev-only for the same reason |
| `-- glyphs` | adding a card or changing `CardData.glyph_kind()`. Distribution over all 89, so no picture becomes a catch-all |
| `-- stowtest` | touching the salvage rail or `SectorScreen`'s lifetime. Drives the real screen through a real jump — the rail's dismissal has been wrong three times and the first was invisible to any assertion on the rule itself |
| `-- archivetest` | adding an archive document. Machinery AND a style gate over the prose — see `docs/lore.md` §5 |
| `-- savetest` | touching `SaveGame` or `RunHistory` |
| `-- rngtest` | touching `Rng` or any generator. **In the merge gate** |
| `-- nettest` | touching anything in `scripts/net/`. A full party in one process. **In the merge gate** — it was not, and the cap going 4→8 left it asserting four seats in nine places for a whole day before anything said so |
| `tools/cofight.sh` | touching `Combat`'s shared path, `SharedFight` or `Router.start_combat`. `boss` for the core, `late` for joining a fight already open. **`nettest` cannot reach any of it** — `Run` is a singleton, so one process holds one ship |
| `-- attrs` | touching `attr_*()` or the hull tables |
| `-- wear` / `-- fit` / `-- bestiary` | touching `HullWear` / `HullFit` / the organic operations |
| `-- shipsheet` | touching `ShipView`, `ShipBuild` or the mount vocabulary |
| `art/tools/boxes.py` | working on the ship creator, the hold or any screen the hull sits in. Writes PLACEHOLDER hulls at the agreed 75x30 / 100x40 / 125x50; `--restore` puts the real ones back. Re-run `anchors.py` after either, or `-- mounts` fails |
| `-- holdtest` | touching the hold grid, module sizes or `place_in_hold`. In the gate. The failure is invisible in the data — two parts sharing a cell still total a sensible "17 of 28" and still save and load, so the only symptom is one plate drawn over another |
| `-- fittest` | touching the hold, the hardpoints, `ModuleIcon`, module ROTATION or either drop handler. **Needs a window, so it is NOT in the gate** — it drives real drags. Crossings between the hold and the hull both ways, a refused drop, and R turning a part — including a turn with nowhere to go, which is the branch where the part is out of the hold and has to get back. The return journey was unreachable for weeks and looked written: `_on_hold_drop` had always handled a part arriving off the ship and nothing could start that drag |
| `-- mounts` | **replacing a hull sprite.** In the gate, so this is a backstop rather than a thing to remember. The dorsal/ventral/flank lines are measured per sprite by `art/tools/anchors.py`, so a swapped hull aims its guns at empty space with nothing thrown and nothing logged. Checks all 89 mounts against the sprite's own opaque pixels |
| `-- convoy [N\|solo\|chart\|flare]` | touching the convoy strip. `solo` is the control: the party cell must cost the solo game nothing |
| `-- charttest` / `-- sky` | touching the chart's star cache / `SpaceBackdrop`. Both need a window |

**Getting somewhere fast.** Every one is a flag rather than a menu item, because each
skips part of the run the balance depends on.

```bash
godot --path . -- nolauncher | resume | seed 12345
godot --path . -- ship | station | cards | fight 10 | fight foes=3
godot --path . -- salvage 8 [bag=4]            # the sector with a full hold, or a loot bag
godot --path . -- archive [all|5] [open=<id>]  # the reading room
godot --path . -- party 6                      # the party page against a fake roster
godot --path . -- quest                        # signs work and opens the chart on it
godot --path . -- lobby [host|join CODE] [auto] [relay ws://localhost:8787]
tools/coplay.sh [N]                            # N playable windows, one party
tools/bot.sh [CODE] [MAILBOX]                  # a ship nobody is sitting in front of
godot --path . -- <any of the above> shot=user://x.png   # photograph it and quit
```

**Why the sim boots normally.** It cannot run via `--script`: that flag replaces the
main loop and never creates the autoloads, so `Run` and `DB` fail to resolve at
compile time. `savetest` boots the same way.

**Why `savetest` scrambles the live state before loading.** Without it a field the
save forgot to serialise still matches, because the value was already sitting there.
A save system fails silently by nature — nothing crashes, the field comes back as a
default and the run continues around it looking almost right.

**Why `--import` is not optional.** Global `class_name` registration lives in
`.godot/global_script_class_cache.cfg`, which only `--import` writes. Without it
every `class_name` reports "Could not find type X in the current scope" — a wall of
errors from one cause, not many.

---

## Design rulings — do not silently reverse these

These were settled deliberately. Each has a reason. If a change would contradict one,
say so and ask rather than quietly working around it.

| Ruling | Reason |
|---|---|
| **Hulls ARE built by a manufacturer** — seven branded chassis, plus three unbranded salvage frames | REVERSED, deliberately. The old ruling was "hulls have no manufacturer", to keep hull swaps a pure power decision. It made `attributes-and-checks.md` §1.5 unimplementable: that section gives each maker an attribute signature, and every one of those (thermal capacity, dodge, hull mass) is a property of a chassis, not of a bolt-on module. The cost is real and accepted — swapping hulls now moves your set count |
| **Set bonuses are the class system** (3+ / 5+ modules from one maker), **and the hull counts as one** | Identity is assembled mid-run — the original ruling, restored. A chassis launches with its hull and ONE branded weapon, which is 2 of the 3 a set needs, so you start pointed at a manufacturer and arrive at it later. Unbranded salvage frames count for nobody, so taking one is a real cost |
| **You launch with one branded weapon and generic yard stock** | A run used to open holding a maker's whole catalogue, so its set bonus was already earned and nothing found afterwards could change what you were. The generic kit (`DB.GENERIC_KIT`) is deliberately dull — a beam, a plate, a coolant line — because the branded part in the next wreck has to be visibly better than *something*. Marked `starter_only`, so it is issued and never dropped: yard stock in the loot pool would crowd out the parts a run is spent collecting |
| **A gauge is the chassis PLUS everything bolted to it** — `Run.max_hp()`, `heat_cap()`, `dissipation()`, `dodge()`, `initiative()`, `fuel_factor()` all sum `installed` | They used to return the hull's field and stop, so armour plating added no armour. It was invisible because the two attributes that had no gauge — Sensors and Stealth — always summed modules, and nobody noticed the other four did not. Sum in the GAUGE, never in `attr_*()`: an attribute is a reading, and a plate that only moved the reading would show on the ship tab and not in the fight, because combat calls `max_hp()` and never calls `attr_hull()`. `RunState._clamp_hp` rides `Sig.ship_changed` so unbolting plate takes its hull back |
| **`fuel_factor` cuts both ways, so no module carries it** | It raises Thrust and the price of every jump together. The sim already strands 30-40% of runs, so any value invented for it moves the most fragile number in the game to change an attribute nobody asked about. The gauge sums it; the catalog waits for an actual engine module |
| **No module ever grants a malfunction** | Junk arrives, it is not equipped. There WAS a `dross` module and it was unreachable — the loot pool skipped it by id and the only thing that could hand it over was a function nothing called — so the yard listed a part nobody could be given. `Run.dross` is the real mechanism: a count that goes up when a spore enemy breathes on you, which `DeckBuilder` turns into unplayable cards at deck-build time. A malfunction costs a deck slot and nothing else: no hold cell, no hardpoint, no decision to carry it |
| **A malfunction charges you at the END OF THE TURN, never on the draw** | Charged on the draw it is a tax you cannot see coming and cannot answer — it has already happened by the time you know about it. Charged at the end, the same number is a QUESTION: you are holding something that will cost you, and you have a turn to find a way to shift it. `CardData.hand_damage` and `hand_heat` are that, and `purge` and `dump_hand` are the answers. This is why discard exists at all |
| **Three ways to get rid of a card, and they are three different sizes of decision** | REVERSES "discard verbs never ask the player to choose", which was a limit dressed as a design. **Jettison** is the ordinary one — you pick, it goes to the discard, it comes back when the deck reshuffles; `jettison_all` is the same verb at the scale of a hand and pairs with `draw`, which is a real cost because it throws away what you wanted too. **Write off** is the expensive one: gone for the rest of the fight. Against junk that is the whole difference, because a discarded malfunction is back the moment the deck reshuffles. And `exhausts` is a card that writes ITSELF off, which is how a card is allowed to be much stronger than its cost |
| **A choice is an index, never a click** | `Combat.choose(i)` takes a hand index and `Combat.best_choice()` answers it headlessly — junk first, then the most expensive card. The screen is one caller of that door; `Policy`, the bot and the co-op harness are the others. A choice only a mouse can make is a choice the simulator cannot play around, and the sim's win rate is the number the gate reports before every merge. `best_choice` is deliberately not random for the same reason: a coin flip inside it makes that number noisy for reasons unrelated to balance |
| **A pending choice cannot outlive the turn that asked it** | `end_turn` clears it. `can_play` refuses everything while a choice is open, so a leaked one locks the next turn solid with no way to clear it — and "pick 2" carried into a new hand is asking about cards that are no longer there |
| **Charge fires automatically** when ready | Tension belongs in *when you start* charging, not in a release button |
| **Overheat = predictable self-damage.** 1 hull per point over cap, at end of turn. No cliff, no shutdowns, no cap on heat | Heat becomes a second health bar you can choose to spend. Repairs cost scrap, so overheating burns money |
| **The archive is PRIMARY SOURCES, never exposition** — manifests, riders, receipts, transponder loops, and never a narrator | `docs/design-doc.md` rules that no faction explains the cosmology in a text box, and the obvious way to add lore breaks that. `docs/lore.md`'s frame is what makes lore possible under it: *corporations are eternal and buying heat, people are temporary and want scrap and credits, and the eternal things will not say what the heat is for.* Nobody explains the world because the people who could are not talking. **There is no answer written down anywhere**, including in the design docs — that is a commitment, not a gap, because the moment one exists somebody will put it in an entry. `-- archivetest` is a style gate as well as a machinery one and runs in the merge gate |
| **Heat does NOT gate loot.** Winning a fight pays the loot. Fleeing pays nothing. Heat's only job on the map is the residual you carry into the next jump — the ambush mechanic | REVERSES `docs/coop-design.md` §0's own conclusion, which proposed that heat must gate reward, and kills §6's "two doors" with it. The measurement behind that proposal still stands: 1,000 runs a cell say heat does not move the win rate, and under this ruling it is not going to. That is accepted. **Difficulty lives in the economy**, which is what the tuning rule below has said all along and what the enemy-scaling change actually moved. `docs/coop-design.md` §0 has the full record |
| **The deck only reshuffles at the start of your turn** | Without this, zero-cost draw cards (Emergency Vent, Jury-Rig, Foresight) loop forever once the discard recycles. Also makes deck size strategically meaningful |
| **Player attacks never miss. Only enemies miss** (light hulls dodge incoming fire) | Player-side miss RNG feels terrible in a game built on perfect information |
| **Ballistics run cold; energy weapons run hot** | Gives materials a readable thermal language before you read any numbers |
| **Ships use fixed intent loops; fauna use weighted random pools** | Machines are predictable, animals are not. Worldbuilding through mechanics |
| **Bosses are hand-tuned, never danger-scaled** | A boss-grade stat block in a random encounter is a run-killer. This was a real bug once |
| **Enemy HP scales faster than enemy damage** (0.10 vs 0.05 per danger tier) | Deeper fights should be longer, not one-shot lethal. Halved when danger went 1-5 -> 1-10, so the top of the ladder sits where it always did |
| **Danger runs 1-10, but balance-sensitive tables read `MapGen.tier()`** | Enemy pools, loot rarity gates, hull tiers and station stock were calibrated against five tiers. Widening the *displayed* scale must not silently reweight every drop table |
| **Lateral map travel is always available and cheap** | You can farm a danger band before descending, so every death is self-authored. This *is* the greed clock |
| **A place is three independent axes** — development, security 1-5, and who operates there | One label could not say "rich city, no law". `Region` still exists but is *derived* from the axes in `_derive_region()`, because loot bias, fauna pools and station stock branch on it in five files |
| **The galaxy is nine shells, spaced so neighbours are near in every direction** | Twenty-four thin rings made a ring step 0.03 of the disc while a rim ring was 0.51 wide — a factor of seventeen, so nothing was near anything. Populations follow ring perimeter, which trades light-following density for a map you can navigate |
| **Fuel cost is chart distance; travel is anything within range** | A flat lateral/coreward rate made every jump cost 1 no matter how far it plainly was. Range covers your six nearest neighbours, so it self-scales from rim to core |
| **Depth is gated by shells** (you may only move one shell at a time) | Geometric necessity, not taste: ring spacing is tiny next to ring width, so an unrestricted distance rule lets you cross most of the galaxy in two hops |
| **The Core is a supermassive black hole, not a settlement** | Nobody develops or polices it. The social axes do not apply to the thing at the centre of a galaxy |
| **Galaxy *shape* is purely cosmetic** | Systems sit on shells and never consult the arms, which is what makes fifteen galaxy types in `GalaxyGen` cost nothing in balance |
| **Every arrival lands on the sector screen** | You should see a place before being asked to do anything with it. Station/event/salvage are reached *from* there, which is what finally retired `LootScreen` |
| **One currency: credits** — repair, upgrade, and purchase all compete for it | This is where the difficulty actually lives. RENAMED from scrap, not re-ruled: one wallet, and everything competes for it. The rename is what made a HOLD make sense — scrap is a substance and sits in cargo, credits are a number and do not, so the hold became slots for things worth hauling (8 light / 12 medium / 16 heavy). `scrap_value` and `scrap_module()` keep their names on purpose: scrapping is still the VERB for breaking a part down, and only the unit it pays changed |
| **A station never pays more for a part than it charges for one** | It used to, and that was an exploit rather than a tuning error — the buy price lived in `StationScreen` and the melt price lived in `RunState`, and neither file had heard of the other. Every price is now a fraction of one base value in `Market.gd`, so `melt < ask` is true by construction. `-- market` proves it over 12,600 combinations, because the invariant is three constants away from being false |
| **The profit is in the distance between two places, not in one transaction** | Round-tripping a part where you stand is a guaranteed loss, and that is correct: a scrapyard is not a market. A house's own yard is thick with its own parts and pays a glut price; a rival's yard needs what it cannot press. Buy Korvan in Korvan space, sell it to Solari. The route IS the trade |
| **A station's shelf is rolled once per run** | The guard used to be `shop.is_empty()`, so buying a shelf out re-rolled it on the next visit. A station is a place, not a vending machine: what somebody brought here is what there is, and it is also the brake that stops any trade route from being farmed |
| **Prices are derived, never stored** | A price is a pure function of a place and a part. The old "price" meta was saved on every shop module, and a shelf that came back without it quietly held a 47% sale. A derived number that is also saved is a second copy of the truth, and it only ever goes one way |
| **In a shared fight the host owns the ENEMY and nothing else** | The general rule is *the host owns the contested object*, and in a fight the contested object is the thing being shot at. Everything on your side of it is private by construction — nobody else targets your block — so it stays local and costs nothing. This is the answer to `docs/netcode.md` N2 ("does the host simulate all four ships"): neither, and it needed no `Run` refactor. It generalises — the shared fuel tank and §6's summed heat field are the same shape |
| **Free-running turns with one barrier, NOT simultaneous lock-in** | `docs/coop-design.md` §5 asked for face-down lock-in and it is rejected. Lock-in makes every card a deferred effect, and draw, energy-gain and block-then-attack do not survive resolving out of order — it is a rework of `CardResolver` and a chunk of the card set. The barrier gets the same property (nobody waits on a phase, nobody sees another hand) for zero card changes. Do not re-propose lock-in without pricing the card rework |
| **The world agrees; anything paid to a PLAYER does not** | `Rng.world` is not salted, because four players who disagree about the galaxy are not in the same game. `loot`, `event`, `foe` and `fight` ARE salted, by `Rng.seat` — the ship's slot in the party, 0 when alone. These are cursors, not derivations: four machines that have made the same number of draws sit at the same place in them, so without this two ships that kill the same frigate are handed **the same two modules**. It is worse than it looks, because the duplication stops the moment the cursors drift apart, for no reason a player can see. Seat 0 is a deliberate NO-OP so a solo run still replays bit-for-bit from `-- seed N`. Positional content (`Rng.derive`) is the opposite case and must keep agreeing — a wreck holds what a wreck holds |
| **A contested LIST is claimed by slot, and the list must not shrink** | The station shelf is the second contested thing in the game and the first that is a list: a wreck is taken whole, a shelf is taken a part at a time. `MapGen.OPTION_SHOP + i` is the i-th slot. **`n.shop` no longer has the bought part erased out of it** — erasing renumbered everything after it, so one purchase and every machine's idea of "slot 2" disagreed. A sold part stays on the shelf and is hidden by `n.taken`, which is what that field was for. The shelf ITSELF is meant to be identical on every machine: it is drawn positionally because it is one shop, and four ships docking in four different orders must see one set of shelves |
| **The sector strip draws who is HERE; the star chart draws everybody** | A sector is a place. A ship two hundred light years away is in your convoy and is not in this room, and drawing it beside your hull says the opposite — during a fight it says it is helping. `EncounterView._here()` filters by `where_is(id) == Run.at`; `StarchartScreen` is where the whole party lives, because that screen's subject is where everyone is |
| **Materials are prerequisites, not a second currency** — and ALLOY failed that test and is gone | A recipe costing forty credits is a purchase; a recipe costing one precursor fragment is a reason to have flown somewhere. That is how crafting gets a cost credits cannot pay without breaking the one-currency ruling. Alloy broke it: it came off every part you broke down, so it accrued from the hold you were emptying anyway rather than from anywhere you WENT — a faucet that large is a second currency whatever the ruling calls it. Exotic and relic survive because their sources are places (megafauna, pulsars, deep wrecks). `HULL PATCH` and `FUEL SYNTHESIS` went with it, being the two recipes alloy paid for; `COOLANT BRAID` now costs credits and an exotic |
| **An AI crewmate is a PLAYER, not a service** — it joins by lobby code, takes a seat out of four, and holds its own `Run` | `Run` is a singleton, so one process holds exactly one ship; a bot that flew "alongside" you inside your process would be your ship wearing a second name. The seat is the cost and there is no spectator slot to hide in — the relay's door policy counts peers, and `NetTransport.MAX_PLAYERS` bounds the party (eight, raised from four and flown at six before it was raised). **Reading the Cloudflare relay instead does not work**, and it is the obvious cheaper idea: `relay/src/index.js` never opens a payload (it checks byte 0, rewrites the sender id and forwards), so what is on that socket is Godot's binary RPC and reading it means reimplementing the engine's serialiser — and the relay cannot invent a peer, so the result would be a spectator with no ship. See `docs/netcode.md` §7 |
| **The bot's brain is behind a file mailbox, and the shot clock is not optional** | `SharedFight.end_turn()` is a barrier: the enemy does not swing until every ship has ended its turn, so a bot that is still thinking is three other people watching a static screen. A language model answers in seconds and occasionally in minutes. So the board is offered, an answer is waited for, and when the clock runs out `Policy` plays the turn — the bot is allowed to be slow, not slow at everybody else. Files rather than a socket because Godot has no HTTP server and anything that can write a file can then play: a shell, `tools/crew-mcp.mjs`, a person with a text editor |
| **One pilot model, two callers** — `Policy` is the simulator's competent player, and the bot flies it | Extracted from `HeadlessSim` unchanged and proved neutral over 60 seeded runs. A bot with its own brain would be a second model nothing measures: the gate reports a win rate for `Policy` before every merge, and a private copy would drift from that number quietly. The split lands where it does because the two LOOPS cannot be shared — the sim's must not yield and the bot's must — but every decision inside them can |
| **A wingman follows the seats that arrived before it, and holding is a move** | Both halves were flown before they were written. Two ships that each "follow whoever is nearest" mirror each other exactly and bounce between two stars until the tank runs dry; seat order breaks it, so seat 0 leads and never follows. And a bot that only ever moves TOWARD the party arrives, wins the fight and is four jumps deeper before anybody lands — a headless ship plays a whole run in forty seconds against a person's hour. So a following ship does not leave a system somebody is in. Holding expires on `patience` seconds of NOTHING HAPPENING (not on the wait itself), because a person picking over a shelf looks exactly like a person who has closed the lid, and abandoning them mid-shop is the worse mistake |
| **No crew management.** Ever | The whole premise: ship systems, not little people running around. An AI crewmate is not a counter-example: it is another PILOT, in another ship, with its own hull and hold |
| **A system is consumed through `RunState.take_whole()` or `take_option()`, and nowhere else** | It is the seam co-op needs. A shared seed gives four machines an IDENTICAL galaxy, not a shared one: every wreck holds the same modules everywhere, because what a node holds comes from `Rng.derive(tag, node.index)`. The one thing a seed cannot say is whether somebody has already been there — so the host keeps that list, and one door means a new way to finish a system is shared by construction. `Net.claim()` does nothing in the solo game, which is why every call site changed without gaining a branch. **The two doors are not interchangeable.** `take_whole()` fires and forgets, which is right for what nobody can take from you — the fight you won, the hail you were inside. `take_option()` ASKS and returns whether you got it, which is required for anything two ships can race for: assume you won and both players roll the loot, and the flag agreeing afterwards does not take the module back out of the loser's hold |
| **One suspend save, deleted the moment it is read** | Quitting is a bookmark, not a checkpoint. Autosave rewrites it at every safe point, so there is never an older state to reload — which is the only thing keeping "every death is self-authored" true. A reloadable save repeals the greed clock without changing a single number |
| **Combat is outside the save.** Safe points are screen swaps outside a fight | A safe point is a moment when the only live state is `RunState`'s, so restoring one cannot strand a half-resolved fight. The autosave lands *before* a fight starts, so a force-quit mid-fight costs the fight, not the jump. It does refund the hull the fight had taken — the price of not serialising deck order, enemy intent loops, drones and charge timers |
| **Condition is DRAWN, not authored. A class is a SPECIFICATION, not a condition** | Two ideas wore one letter for a while. `DB.TIER_DELTA` grows an A-class frame a weapon hardpoint and an S-class one a system mount plus a reactor — no amount of maintenance sprouts a hardpoint, so the letters are a spec and nothing else. How beaten up a hull is lives on `hp` and is drawn by `HullWear` from the sprite's own palette. The arithmetic is what makes it affordable: 7 makers × 3 weights × 4 grades is 84 sprites, and generating the 63 damaged ones costs ~13,860 PixelLab generations against a 5,000 monthly allowance — near three months, for hulls alone. Drawn it costs nothing, on the twenty hulls that do not exist yet as readily as on the one that does |
| **Generated art may not drift the palette, so damage is not generated** | Every operation in `HullWear` ends by snapping to a colour the sprite ALREADY CONTAINS, measured at 0 new colours on every band of every hull. The generated attempts drifted 17-41 new colours per masked tile, and one pass over a whole hull invented a fresh palette and threw away every amber panel Korvan flies. Arithmetic cannot drift; there is nowhere for a new colour to come from. `-- wear` prints the count so the guarantee stays checkable rather than remembered |
| **A whale does not weld, and a hull does not scar** | `HullWear.Substance` splits the operations. Organics get bruising, gashes, weeping, necrosis, BARNACLES (the art direction asks for them by name) and SCARS — and scarring is the one a machine can never have. A hull that is cut stays cut until somebody welds it; a body closes its own wounds and keeps the record. An animal covered in scars has WON several times, which reads nothing like a ship covered in patches |
| **The flight record unlocks MANUFACTURERS, and nothing else** | REVERSED, deliberately. The old ruling was "the flight record is a record, not meta-progression", on the grounds that a history granting a starting bonus would be the first crack in identity-assembled-mid-run. It still would — so an unlock grants no POWER. Winning with one house unlocks the next (`Unlocks.CHAIN`), and because the seven are balanced against each other, finishing the chain widens the CHOICE at run start and changes nothing about difficulty. What it buys is a first run that is one ship rather than a menu of seven you have no way to choose between. Derived by folding over `RunHistory` rather than stored, so there is no unlock file to desync or cheat — at the cost that runs recorded before `chassis_maker` existed unlock nothing. `DevMode.enabled` unlocks everything |

---

## The most important tuning rule

**Individual fights are not the difficulty — the economy is.** A starter deck beats a
danger-5 Rustjaw Cutter for about nine hull. Runs end from cumulative attrition.

**Measure before and after, at a fixed seed, and write the number down.** Every claim
in this file that turned out to be wrong was wrong because somebody asserted it once
and nobody re-derived it. Two worked examples, both of which reversed an earlier note:

- **Repairs are the lever for making the game HARDER, not easier.** Cutting
  `REPAIR_BASE` 40% moved the win rate 9.2% → 10.3% over 1,000 runs each — inside the
  noise — and hull deaths did not move. The player is not repair-limited; they are
  dying between stations.
- **What actually moved it was enemy scaling in `Combat._spawn()`.** Halving both
  multipliers took 9% to a measured 20.5 / 19.7 / 18.9 across three 1,000-run passes.
  Runs got longer rather than easier: 65 average jumps to 92.

**And hull loss is no longer half the deaths.** Measured over 600 runs while the
repair cards were added: 105 of 338, so 31%, against 56% for running the tank dry.
Anybody reaching for "sustain decides the game" should reach for the current number.

---

## Priorities

The flight record and the archive are the only two things that survive a dive, and
neither grants power — that is the shape meta-progression is allowed to take here and
the reason both were safe to build. See `Unlocks.gd` and `Archive.gd`.

Open, in rough order: the `Run` singleton is still the largest single obstacle to
anything the host has to hold four of (`docs/netcode.md` §5); `CREW_SHARE` is linear
with no ceiling and has been flown at two, so an eight-ship custodian is allowed and
untuned; and `_push_roster_to` sends the whole roster to everyone on every presence
change, which is O(n²) and invisible at four.
