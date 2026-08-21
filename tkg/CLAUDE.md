# Three Kelvin — project context

Pixel-art turn-based roguelite. Godot 4.3+, GDScript. Solo developer.
**Your ship is your character and your modules are your deck.**
*FTL's ship fantasy × Out There's exploration × Slay the Spire's combat × Diablo's loot.*

Named after the cosmic microwave background temperature — the universe's leftover
warmth, three degrees above absolute zero. A heat-management game named for the cold.

---

## How to work in this repo

- **Talk like a person in chat.** Plain sentences. No headers, no tables, no bullet
  scaffolding, no bold every third word. Say the thing and stop. Condense — if it fits in
  four sentences, use four. Lead with the answer, then the reasoning only if it is actually
  needed, and do not restate the question first. Be direct about problems, tradeoffs and
  things that are broken; brevity is about format, not about hedging or leaving things out.
  Use structure only when the content really is structured — a measured comparison, a list
  of files, a table of numbers — and that should be rare.
  This applies to replies in chat and NOT to the source comments, or to the design documents
  in this repository. The comment voice here is deliberate and is described in "The most
  important tuning rule" and throughout the sections below.
- **Development happens in VS Code.** Godot's editor is used only to run the game (F5),
  read the Output panel, and host the language server. Do not create or edit `.tscn`
  files unless there is no reasonable alternative.
- **UI is built in code**, not scenes. There is exactly one scene, `scenes/Main.tscn`.
  Screens are `Control` subclasses that construct their own children against `UITheme`
  and `Widgets`. Keep it that way — it avoids scene-merge conflicts and keeps styling
  in one place.
- **Content is data, not code.** New modules, cards, enemies, hulls and affixes go in
  `scripts/autoload/Database.gd` as dictionary entries. `CardResolver` already handles
  every effect field on `CardData`, so a new card should require zero new logic. If you
  find yourself adding a `match` on card name, stop — add a field to `CardData` instead.
- **Systems never reach across scenes.** They emit on `Sig` (the signal bus autoload);
  UI listens. Autoloads are `Sig`, `DB` (Database), `Rng`, `Run` (RunState),
  `Router` and `Net` (NetSession). `Net` is inert in the solo game — it holds no
  peer and costs nothing until somebody hosts or joins.
- **Never call the global `randi()`/`randf()`/`pick_random()`/`shuffle()` for
  anything that decides something.** Draw from a named stream — `Rng.world`,
  `Rng.loot`, `Rng.event`, `Rng.foe`, `Rng.fight` — so that a run replays from
  its seed and one system's rolls cannot move another's. Anything a player can
  reach out of ORDER (a station's shelf, a wreck's contents, what is waiting at
  a node) uses `Rng.derive(tag, node.index)` instead, so it depends on WHERE it
  is rather than on when it was asked for. Cosmetic rolls — audio pitch, damage
  jitter, the title screen's galaxy — keep the global generator on purpose.
  `Rng.gd`'s header has the reasoning; `-- rngtest` is what enforces it.
- **Indentation is tabs.** Godot requires it.
- **Static typing where practical** (`var x: int = 0`, typed arrays, `-> void`).
  Typed array assignment from literals often needs `arr.assign([...])` rather than
  `arr = [...]`.

## Run and test

```bash
# Play
godot                      # then F5, or run from the editor

# Balance simulation — RUN THIS AFTER ANY BALANCE CHANGE
godot --headless --path . -- sim runs=200      # ~4 min at 200 runs

# Save/load round-trip — RUN THIS AFTER TOUCHING SaveGame OR RunHistory
godot --headless --path . -- savetest          # ~3 s

# Lobby codes, four peers forming a party in one process, one map rather than
# four copies, and one enemy rather than four —
# RUN THIS AFTER TOUCHING ANYTHING IN scripts/net/ OR Combat's shared path
godot --headless --path . -- nettest           # ~5 s

# The same seed twice, and streams that do not move each other —
# RUN THIS AFTER TOUCHING Rng OR ANY GENERATOR
godot --headless --path . -- rngtest           # ~5 s

# Six frames of a ship jumping in, side by side, in one PNG —
# RUN THIS AFTER TOUCHING JumpFlare. The effect is 24 frames long, so what has
# to be checked is the SHAPE over time: the column opens, flares, and closes,
# and the hull changes hands BEHIND the widest frame rather than beside it.
godot --path . -- convoy flare

# Two PROCESSES, one enemy — the only way Combat's shared path ever runs.
# RUN THIS AFTER TOUCHING Combat's shared path, SharedFight, OR Router.start_combat.
# nettest cannot reach any of it: `Run` is a singleton, so one process holds one
# ship. This starts a host, greps its lobby code, joins from a second process,
# flies both to one system and plays the fight out.
tools/cofight.sh                               # ~25 s

# ...and the same pairing with windows, to actually play it.
tools/coplay.sh                                # two clients, side by side
tools/coplay.sh 3                              # three

# A ship in the party that nobody is sitting in front of. Joins by lobby code
# like a person, rolls its own chassis, holds its own Run.
tools/bot.sh                                   # a window for you, a bot alongside
tools/bot.sh ABC-123                           # send one to a party already up
tools/bot.sh ABC-123 /tmp/crew                 # ...taking orders from a mailbox
godot --headless --path . -- bot join ABC-123 follow name=Claude think=30

# One PNG per ship, drawn straight out of ShipView's own canvas —
# RUN THIS AFTER TOUCHING ShipView, ShipBuild OR THE MODULE MOUNT VOCABULARY.
# Each hull twice, bare and loaded, because "a ship drew" is not the question;
# "the ship that drew is the one described" is. Needs no renderer: the view
# composites into an Image and the Image is the file.
godot --headless --path . -- shipsheet         # ~3 s, writes to user://shipsheet

# The sector with a party in it — RUN THIS AFTER TOUCHING THE CONVOY STRIP.
# Fakes a roster, opens no port, screenshots the real screen. `solo` is the
# control shot: the convoy cell must cost the solo game nothing.
godot --path . -- convoy                       # ~8 s, needs a window
godot --path . -- convoy solo                  # the control: no party, no cost
godot --path . -- convoy chart                 # the star chart with a party on it

# Star chart sky cache — RUN THIS AFTER ADDING TO _build_stars OR ITS BUILDERS
godot --path . -- charttest                    # ~10 s, needs a window

# Every sector sky on one contact sheet, and again behind a real ship —
# RUN THIS AFTER TOUCHING SpaceBackdrop. Writes two PNGs to user:// and prints
# the path. Needs a window: the sheets are grabbed from the renderer.
godot --path . -- sky                          # ~20 s, needs a window

# Every chassis's six attributes as one table — RUN THIS AFTER TOUCHING attr_*()
# or the hull tables. The numbers only mean anything against each other.
godot --headless --path . -- attrs             # ~5 s

# The price table, and 12,600 checks that the market cannot be gamed —
# RUN THIS AFTER TOUCHING Market.gd
godot --headless --path . -- market            # ~4 s

# Boot destinations. The launcher is the default; every dev flag skips it.
godot --path . -- nolauncher                   # straight into a new run
godot --path . -- resume                       # straight into the suspend save

# The party screen. Reachable from the title screen — FLY TOGETHER — so these
# flags are for testing it, not for using it. Two instances on one machine is
# the way: host in one, COPY the code, PASTE it in the other. `auto` presses
# READY and LAUNCH for you, which is how the two-machines-one-galaxy claim is
# checked without two people clicking at once.
godot --path . -- lobby
godot --path . -- lobby host
godot --path . -- lobby join DR2M-08BB-TD49
godot --path . -- lobby host auto

# ...and against a relay, local or deployed. See relay/README.md.
cd relay && wrangler dev --port 8787 --local
godot --path . -- lobby host relay ws://localhost:8787 auto wait 4
godot --path . -- lobby join <CODE> relay ws://localhost:8787 auto

# A run is one number. This flag replays it exactly — the same galaxy, the same
# map, the same loot, the same fights. Use it in bug reports.
godot --path . -- seed 12345

# ...and the sim version, which gives run i the seed N+i, so a whole sweep is
# reproducible and any single run in it can be flown again by hand.
godot --headless --path . -- sim runs=200 seed=12345

# Dev shortcuts. Flags, not menu items, because each one skips part of the run
# the balance depends on.
godot --path . -- ship                         # straight to the refit screen
godot --path . -- station                      # straight to the dock, hold full
godot --path . -- cards                        # every card in the game on one page
godot --path . -- fight 10                     # into a fight, dealing 10 cards
godot --path . -- fight foes=3                 # ...against a pack

# Every damage band of every hull with real art, and the colour count that is
# the whole claim — RUN THIS AFTER TOUCHING HullWear. Anything but 0 is a bug.
godot --headless --path . -- wear                # ~4 s
godot --headless --path . -- wear seed=12345 pilot=Jon

# Every specification class, and the same again composed with damage.
# RUN THIS AFTER TOUCHING HullFit.
godot --headless --path . -- fit
godot --headless --path . -- fit damage=3

# Every enemy body at every damage band — RUN THIS AFTER TOUCHING the organic
# operations. EnemyArt is a TextureRect but composites CPU-side, so no renderer.
godot --headless --path . -- bestiary

# Rebuild the global class cache — REQUIRED after adding any new class_name,
# and required once on a fresh clone before anything will compile at all
godot --headless --path . --import
```

The sim boots the project normally and quits before building UI. It cannot run via
`--script`: that flag replaces the main loop and never creates the autoloads, so
`Run` and `DB` fail to resolve at compile time. `savetest` boots the same way.

`savetest` plays a run into a messy state, fingerprints it, saves, **scrambles the
live state**, loads, and compares. The scramble is the point: without it a field the
save forgot to serialise still matches, because the value was already sitting there.
A save system fails silently by nature — nothing crashes, the field just comes back
as a default and the run continues around it looking almost right.

Global `class_name` registration lives in `.godot/global_script_class_cache.cfg`,
which only `--import` writes. Without it every `class_name` reports "Could not find
type X in the current scope" — a wall of errors from one cause, not many.

`HeadlessSim.gd` plays complete runs with a competent-player model and reports win
rate, jumps, kills, and death causes. Healthy target: **40–55% win rate**. This tool
has already paid for itself — in the earlier web prototype it caught three real bugs
(including an infinite draw loop) and a structural map flaw in minutes.

### The merge gate

```bash
.github/scripts/validate.sh              # everything CI runs, from the repo root
SIM_RUNS=200 .github/scripts/validate.sh # a real balance pass
LOG_DIR=./ci-logs .github/scripts/validate.sh
```

`.github/workflows/validate.yml` installs Godot and calls that same script, so a
green pull request and a green laptop mean the same thing. If you want to change
what gets checked, edit the script, not the workflow.

It runs six things, in the order that fails fastest first: GDScript is
tab-indented, the class cache builds, the project boots and constructs its UI, the
market invariant holds, the save round-trips, and the simulator plays `SIM_RUNS`
complete runs. Then it syntax-checks the Python audio generators — syntax only, because rendering needs numpy, scipy and soundfile
and writes about 850 MB, which is not what a pull request check is for.

Four things about it are worth knowing before you touch it:

- **Godot exits 0 even when a script fails to compile.** It prints the failure and
  moves to the next resource. So every check reads Godot's *output* for
  `SCRIPT ERROR`, `Parse Error` and `ERROR:` rather than trusting its exit status,
  and `run_godot` is the only place that logic lives.
- **Every Godot step runs under a wall-clock limit.** A script that will not
  compile does not always make the simulator fail — it can leave it wedged
  instead, which is exactly what happened the first time this was tested. Without
  the limit a pull request sits open for the runner's full six hours rather than
  failing in three minutes. `timeout` is GNU coreutils and absent on macOS, so
  `run_limited` does it by hand.
- **The market and save checks are in the gate because they fail silently.** A
  market whose melt price creeps above its ask price does not crash — it pays for
  the rest of the run. A save that drops a field does not crash either; the field
  comes back as a default and the run continues around it. Both print a verdict
  line rather than raising, so the script greps their logs for it. That is also
  why the market check exists at all rather than a comment saying "keep melt
  below ask": the invariant is three constants apart from being false.
- **The gate does not check the win rate**, deliberately. The 40–55% band above has
  not been re-derived against the current economy, and a check that fails on a
  number nobody trusts teaches people to ignore the check.

The workflow reports but does not block. **Blocking requires a branch protection
rule on `main`** requiring the `validate` check — that is a repository setting, not
something in this file, and until it is set a red run is only advice.

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
| **Charge fires automatically** when ready | Tension belongs in *when you start* charging, not in a release button |
| **Overheat = predictable self-damage.** 1 hull per point over cap, at end of turn. No cliff, no shutdowns, no cap on heat | Heat becomes a second health bar you can choose to spend. Repairs cost scrap, so overheating burns money |
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
| **An AI crewmate is a PLAYER, not a service** — it joins by lobby code, takes a seat out of four, and holds its own `Run` | `Run` is a singleton, so one process holds exactly one ship; a bot that flew "alongside" you inside your process would be your ship wearing a second name. The seat is the cost and there is no spectator slot to hide in — the relay's door policy counts peers, and `NetTransport.MAX_PLAYERS` is four. **Reading the Cloudflare relay instead does not work**, and it is the obvious cheaper idea: `relay/src/index.js` never opens a payload (it checks byte 0, rewrites the sender id and forwards), so what is on that socket is Godot's binary RPC and reading it means reimplementing the engine's serialiser — and the relay cannot invent a peer, so the result would be a spectator with no ship. See `docs/netcode.md` §7 |
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

## The most important tuning rule

Simulation showed **individual fights are not the difficulty — the economy is.** A
starter deck beats a danger-5 Rustjaw Cutter for about nine hull. Runs end from
cumulative attrition against expensive repairs.

**So: raise station repair prices before touching enemy damage.** If repairs are cheap,
heat becomes decorative and the entire risk structure collapses.

That lever now lives in `Market.repair_rate()` and is local: `REPAIR_BASE` times a
development index that runs 1.28 on unclaimed ground to 0.84 in a capital.

**MEASURED, AND IT NO LONGER HOLDS IN THAT DIRECTION.** Cutting `REPAIR_BASE` by
40% — 2.0 to 1.2 — moved the win rate 9.2% to 10.3% over 1,000 runs each, inside
the noise band, and hull deaths did not move at all (502 to 510 of 1,000). The
rule was derived against an economy that has since changed twice, and the note
below already warned its band was never re-derived. Repairs are still the lever
for making the game HARDER; they are not the lever for making it easier, because
the player is not repair-limited — they are dying between stations.

What actually moved it was the enemy scaling in `Combat._spawn()`. Halving both
multipliers (0.10/0.05 to 0.05/0.025, keeping the 2:1 ratio the ruling requires)
took 9% to a measured 20.5 / 19.7 / 18.9 across three 1,000-run passes. Runs got
longer rather than easier: 65 average jumps to 92, and hull deaths fell from 50%
to 35% while fuel deaths rose from 15% to 17%.

### Heat has a map layer now, and it still does not drive difficulty

`dissipation()` used to be read in exactly one gameplay site, `Combat.end_turn()`.
Outside a fight, heat was a fossil: the three things reading `Run.heat` on the map
were the hull shader, the HUD label and an audio cue, all cosmetic. The design
doc's "hot ships attract encounters, cold ships slip past" did not exist in code.

Built: `cool_in_transit()` on every jump, `signature()`, `ambush_chance()`, heat
costing up to 4 of 10 Stealth, ambushes rolled once on arrival and stored on the
node (`MapNode.ambush`, save version 3), and `Combat.clears_node` so winning an
ambush does not consume the station you were flying to. `HeadlessSim` gained
ambush modelling, signature sampling, and a `-- sim hot` policy that spends heat
for tempo instead of venting on sight.

**MEASURED, 1,000 RUNS PER CELL, AND IT DOES NOT BITE.** Win rate stays in the
16–21% band against a 20.5% baseline whichever way it is cut — cold model or hot,
layer on or off. What the instrumentation did establish:

- **Fights end hot.** Post-fight signature 0.34; 37% of fights end above the
  ambush floor. The heat is genuinely there when the shooting stops.
- **A run makes ~65 jumps for ~8 fights.** Eight jumps per fight, so any per-jump
  cooling clears the residue long before the next one. Arrival signature is 0.06
  at a full turn's cooling and 0.06 at half — the rate barely matters, the jump
  count does. Halved anyway, because a jump you were making already should not be
  a free vent.
- **The layer fires:** 0.42 ambushes per run, 22–24% of runs jumped at least once.
- **And pays.** An ambush drops scrap and a module, so it is roughly EV-neutral
  for a competent player.

So: **attaching consequences to heat adds texture, not pressure. To drive
difficulty, heat has to gate REWARD.** That is the next thing to try — two ways
to take every contact, where skirmishing pays scrap at low heat and committing
pays modules at high heat. See `docs/coop-design.md` §0 and §6.

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

## Rarity ladder — top tiers are *sources*, not bigger numbers

Common → Legendary are manufactured. **Exotic** is grown/harvested (megafauna).
**Artifact** is precursor relic tech, brand-agnostic, rule-breaking.
**Contraband is a tag, not a tier** — above-curve power plus station-inspection risk.

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
standing in, raw materials and a station fabricator, full combat (charge, salvo, brace, heat, drones, riposte, adapt,
pacify), loot with rolled affixes, install/scrap/swap, stations with all services and
inspections, eight events, set bonuses for all seven manufacturers, twenty-four hulls with
a chassis-select at run start, the six attributes, procedural ship and enemy art, headless
simulator, suspend save/resume, flight record, launcher screen.

**The six attributes exist but do not yet bite.** `RunState.attr_*()` derive Hull,
Thrust, Maneuver, Thermal, Sensors and Stealth from live gauges, and the ship tab and
chassis select display them — but nothing *checks* them yet. Wiring them into events,
combat entry and the starchart reveal ladder is the next piece, and is what
`attributes-and-checks.md` was written for.

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

## Priorities

1. ~~Get it compiling and running~~ — done
2. **Play five full runs.** Still not done, and it is still the blocker. Every balance
   number in this file comes from the simulator's competent-player model, which cannot
   tell you what is *unsatisfying*
3. Re-derive the healthy win-rate band against the current economy, then tune to it
4. Fix the single worst feeling
5. **Fill Korvan's ladder** ' + E + ' this is the one place "resist adding content" no longer
   applies, and the measurement above is why. 46 modules exist and only **8 are
   Korvan**, occupying **6 of the 15 rungs** a maker has (3 slots × 5 rarities). The
   nine holes: no Uncommon anywhere, system stops at Common and jumps to Legendary,
   and utility stops dead at Common. Note the arithmetic — `15 - 8 = 7` is WRONG and
   was written into a commit message before it was checked, because two of the eight
   double up on rungs already filled.

   The old form of this priority — "37 modules is plenty, thin per-maker pools are
   the known cost" — was right that thin pools were the cost and wrong that it could
   be deferred indefinitely. Narrowing to one maker turned a slow loot stream into a
   six-point difficulty change
