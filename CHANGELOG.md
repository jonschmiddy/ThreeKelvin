# Changelog

All notable changes to **Three Kelvin** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Alpha builds carry a pre-release tag (`-alpha.N`).

## [Unreleased]

### Changed

- **Docking** opens with a new system's arrival, exactly: LOCAL cuts to black, then your ship
  flies in from off screen to its mooring as it does in the first system, on the same path, with the
  same burn sputtering down to idle. Then a beat, the station's lights come on, and the ship lights
  its engines and flies in. A key or click during it still docks at once.
- **The station's left column of decks** slides in like the other panels once your ship is on
  its stands, with its dark ground under it. It used to slide in see-through over the hangar and
  then pop to its dark column when it landed.

### Roadmap

The next build is **0.2.0-alpha.1**, with the fixes from the first playtest. See
[`docs/DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md) for the build order and the balance spine.

## 2026-10-20

### [0.1.0-alpha.1]

The first alpha, for playtesters. The Windows and Mac builds come from the same commit.

- **Added** — a run to the core of a galaxy. The galaxy has 15 layers and about 287 star systems,
  and you can jump to any system within your drive's range. Danger rises from 1 at the rim to 10 at the core. A run ends
  when the hull reaches 0, the tank runs dry, or you abandon it. You win by destroying The
  Custodian at the core.
- **Added** — four views, all one camera at different distances, and the archive:
  - **LOCAL:** your ship side-on, the world you orbit, its wrecks and its events.
  - **SECTOR:** the system map. You fly the ship to events and the station.
  - **STARCHART:** the galaxy, with your jump range and the danger and fuel cost of each system.
  - **The station:** you dock and the camera goes in.
  - **ARCHIVE:** its own screen, with 41 documents recovered from wrecks and events.
- **Added** — card fights:
  - The reactor sets your energy, and the hull's weight sets your hand size. Press END TURN to
    end your turn.
  - Cards make heat. Past the heat cap, each point over costs 1 hull at the end of the turn.
  - Keywords: Brace, Charge, Salvo, Lock on, Vent and drones, plus 16 malfunctions that enemies
    can put in your deck.
  - FLEE and HAIL are checks.
- **Added** — nine enemy kinds:
  - five ship types;
  - two creatures, the Voidwhale Calf and the Void Leviathan;
  - The Hellbender, a rival harvester that roams the chart and runs at 35% hull;
  - The Custodian.

  Every kill leaves a wreck where the fight happened, and you can loot it.
- **Added** — 135 encounters, with checks against the ship's six attributes: HULL, THRUST,
  MANEUVER, THERMAL, SENSORS and STEALTH. A choice that is a check shows its odds, and a check you
  meet always passes. After an encounter, a small table shows only what changed among credits, fuel, hull and
  heat.
- **Added** — weather. There are eight kinds of sky and about 43 weather events. They play on the
  SECTOR map and, more rarely, on LOCAL.
- **Added** — 24 hulls: seven manufacturers at three weights, plus three unbranded salvage frames.
  Each comes in four grades, C to S. A new profile flies Korvan. Winning with a manufacturer
  unlocks the next one.
- **Added** — 95 modules, with seven rarities and 10 affixes, and 68 trade materials. The hold is a
  grid. Press R to turn a part and F to flip it.
- **Added** — the ship editor. Click your ship to open it. Drag a module onto an empty slot to
  install it, or off the ship into the hold to remove it. You can rename the ship here.
- **Added** — stations, with five decks:
  - **PROMENADE:** buy parts.
  - **SHIPYARD:** patch, repair, refuel, clear a fault, or buy a new hull with yours in part
    exchange.
  - **EXCHANGE:** sell parts and materials.
  - **HIRING BOARD:** fetch, hunt and heat contracts.
  - **LABORATORY:** relic analysis, in cities only.

  Outposts have fewer decks.
- **Added** — A.S.H., the ship's AI. She is a holographic face with 30 voiced lines for the
  moments that matter.
  - She introduces herself at the start of every new run, then gives the tutorial in 21 more voiced
    lines.
  - Settings can switch her off. The hints then show as cards.
- **Added** — a light tutorial:
  - The goal line (GOAL: REACH THE CORE) shows your first two steps.
  - 15 one-time hints each wait for a click.
  - Settings > HINTS has TUTORIAL ON/OFF and REPLAY TUTORIAL.
- **Added** — co-op. FLY TOGETHER on the title screen lets you host or join a party of up to 8
  ships, by code over a relay or by direct address. Fights are shared. A party has no hints or tutorial.
  A.S.H. still speaks, but does not teach.
- **Added** — the look:
  - pixel art drawn at 960×540 and shown at 2x;
  - four render styles, with SIMPLIFIED the default;
  - five screen looks, with CRT the default;
  - star fields that drift in layers when you pan;
  - a breakup for every ship you destroy, your own included.
- **Added** — a low-hull warning, from 30% hull down. The screen edges glow red, every piece of
  text decodes badly (letters flip to noise and back), and A.S.H.'s voice stutters and crackles.
  It gets worse as the hull falls and clears when you repair. The escape menu and Settings stay
  clean, and nothing on screen moves. Under reduced motion it is only a faint red edge.
- **Added** — sound: 27 music cues by danger tier, for fights and for death, about 150 sound
  effects, and station ambience with PA announcements.
- **Added** — settings:
  - window mode, monitor and window size;
  - render style, graphics level, screen look, colorblind modes, contrast and brightness;
  - reduced motion, screen shake and a frame cap;
  - four volume sliders;
  - 21 rebindable keys.
- **Added** — saving. The run saves at safe points and when you close the window. SAVE & EXIT TO
  TITLE, then CONTINUE, picks up where you left off. A fight is not saved: if you quit
  mid-fight, it starts again. The flight record and the archive carry over between runs.
- **Added** — Settings > PLAYTEST > SAVE MY LOGS. It puts one zip on the Desktop to send with a
  report. The same button is on the RUN ENDED screen. The game never sends anything by itself.
- **Added** — builds:
  - **Windows:** one exe, plus a console exe that shows errors.
  - **Mac:** one universal app, for Apple Silicon and Intel.

  Neither build is signed. `README-ALPHA.txt` explains the first launch. The version shows on
  the title screen and in the pause menu.
- **Known issue** — only Korvan, Solari and unbranded parts drop. The other five manufacturers can
  be unlocked and flown, but they have only 4 to 7 parts each and use Korvan's hull art. Their set
  bonuses can't be completed.
- **Known issue** — three set bonuses don't do what their text says:
  - **Cygnet 5:** drones persisting between encounters is not built.
  - **Korvan 3:** does nothing for cards that already charge in one turn.
  - **Solari 3:** applies to Solari cards that scale with heat, not to plasma weapons.
