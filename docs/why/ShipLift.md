The reasoning behind `tkg/scripts/ui/ShipLift.gd`, `LiftPlume.gd` and the screens that fly them; each heading is referenced from the code by a `Why:` line.

## Heavy lift

Jon, Nov 12, on the hull pick: "When a launch happens... maybe we can have the ship lift off ... and then fly off the screen to the right?" Three ideas were filmed (tk-scratch/yard-launch/page): L1 heavy and grounded, L2 crane and gantry, L3 fast and punchy. He picked L1: "It should be the same slow heavy animation for the shipyard and the ship selection screen. When undocking from the shipyard, let's have the ship move to the right."

One class, so the front door and the deck cannot drift apart. The host owns time (the front door its own `_process` clock, the deck the zoom ladder's) and calls `lift_at` or `land_at`; `ShipLift` poses the hull and everything that answers it. Its beats are constants because a sound is cut to them (tk-scratch/yard-launch/beats.json): the jets at 0.15 s, the rise from 0.45 s with a sag, the stands sinking from 0.7 s, the mains at 2.05 s, then the burn off the picture.

The weight is the idea, and a slow rise needs about a second and a half to read as heavy. The burn off the picture was 1.05 s, and Jon found it "WAY too fast": the hull crossed the screen in about a second. It now gathers speed from near still all the way off (`pow(burn, 2.6)`) over 3.15 s (his E2 of E1 2.1, E2 3.15, E3 4.2 s); the smoke, the lamps and the shiver answer it the whole way. The front door then holds the hall 0.8 s with the smoke drifting before the cut: 6.0 s in all (it was 3.9).

The mains light on one beat, `MAINS_ON` (2.05 s), and nowhere sooner: the flame, the sideways burn and the `lateral` signal the thruster sound keys off all start on it (Jon, Nov 12: "The horizontal thrusters shouldn't visually turn on until the thrusters sound turns on"). Through the rise the mains are dark; only the belly jets and their smoke are lit.

The light is drawn as light (the memory "draw light as light"): the jets' floor light goes in as the yard's own small lights (`YardLight.dyn`, through `YardLife.extra`), so it lands on the floor, the stands, the crew and the hull through the hall's shader; the jets' line and the nozzle glow are an added layer stepped in six levels with a dither (`launch_glow.gdshader`). The lamps stutter through `YardLight.lamp_k`, on top of whatever else sets them.

## Plume

The smoke is P1 from the page, the rolling ground cloud: puffs added into one density in `lift_plume.gdshader`, torn by a noise field that moves ten times a second (fire's rate, the memory "fire should move"), stepped in four levels and lit from inside in four more. It lingers: the puffs live three to four and a half seconds, longer than the lift. The knobs (`size_k`, `strength`, `floor_y`) fit it to a hall; another kind of smoke is another `_spawn`.

## Attach

Jon, Nov 12: P1 "doesn't align perfectly with the ships." The first cut put the smoke and the jets at fixed shares of the hull's picture box, which a nose spike or a fin moves off the belly. Now every source comes from the hull's own pixels at rest (`_read_belly`: each column's lowest inked pixel), offset each frame by where the hull is. Four ways to hang it were filmed (P1a under the belly's lowest stretch, P1b one jet per stand, P1c the belly's low points, P1d a sheet along the belly); Jon picked P1a: four jets across the belly's lowest stretch, one cloud as wide as it.

## Front door

LAUNCH runs the lift and emits `launched` when it ends; the Router's cut to LOCAL is unchanged, and LOCAL's name card and fly-in follow as before (the ship leaves right and LOCAL brings it in from the left, so the direction carries across the cut). A second press does nothing; a full-screen control takes every click while the ship is in the air, and the escape menu's BACK TO TITLE waits. Reduced motion, and the harnesses that do not animate, cut straight to the run (`Router.animating()`). The hull's berth moves rather than the hull, so its light map (`launch_mask_at`) follows it. The hover blur fades so the whole hall is sharp for the lift.

## Deck

Undocking: the elevator goes, then the same lift at three quarters the size, off to the RIGHT (it left to the left before Nov 12), then F's beat of the empty yard and its fade with the smoke still drifting. `UNDOCK_YARD_S` grew from 2.0 s to the elevator plus `MAINS_ON + BURN_S` (5.68 s). With F, the default, the yard goes to black before LOCAL, so the yard's exit direction does not have to meet LOCAL's backing out.

Landing (Jon, Nov 12: "the ship comes in far too low. It should come in higher, hover over the stands, and then slowly descend"): in high on the mains, its belly ten rows over the wall's foot (from the hall art: under the lamps and hoists), slowing to a hover over the stands; 0.8 s on the jets with a whole-pixel bob and the smoke building; a slow 1.6 s descent with the smoke rolling out harder as it nears the floor; the stands take the weight with a pixel's give. Then ("The ship enters too fast") the way in slowed to 2.6 s, easing out hard into the hover as the takeoff eases in, with the belly jets lighting over the stands as it slows (1.8 s) and the flameout's coughs tied to the hover (`YARD_COUGH_AT_S` is `LAND_FLY_S - 0.85`). `LAND_S` is 5.25 s, so `DOCK_YARD_S` grew from 2.2 s to 5.25 s. The landing's sound (roar, coughs, quiet, clamps) is unchanged and fits itself to the length (`yard_flameout`); the clamps land as it settles. The mains cough out at the hover on the landing's flameout row and stay dark (`ShipView.dark_idle`: dark between the coughs and after; Jon, Nov 12: "When the thruster sputters out can it visually turn off too?"), so only the belly jets hold the hull through the hover and descent; on its stands it idles again as a berthed hull does. Taking off, the hull clears the picture by `EXIT_CLEAR` and its engines go dark (Jon: "the ship's thrusters show up in the right side, like stuck there": the flame and nozzle glow sat at the edge). The hull moves across in fractions of a pixel, as the dock's flight always has: whole pixels stall a slow burn a frame at a time.

The deck shivers the hull, up and down only, not the yard: the camera holds still on the deck (LadderTest), and a sideways shiver would break the flight's one motion.

One takeoff (Jon, Nov 12: "the same for the shipyard and ship selection screen"): the deck runs the same `lift_at` with the same beats. What differs, and why: the deck's starts after its elevator slides out (0.48 s); its rise, stands and smoke are three quarters the size, as its hulls stand smaller; it shivers the hull and not the screen; after the exit it holds F's beat and fade (1.7 s) rather than the front door's 0.8 s before the cut.

`lateral(on, speed)` reports the mains pushing the hull sideways (the takeoff's burn right, the landing's approach until the hover) for the thruster layer under the sound; `lateral_speed` is px/s every frame.

## Heard

Jon picked LC2 with the LTC layer (Nov 12). The take (`ship_liftoff`) is the sound builder's game cut of LC2 (tk-scratch/yard-launch/sound/final/LC2_game.wav, 5.85 s), levelled to -16 LUFS for its loudest second and carrying its own fade. It starts with the belly jets (`PLUME_AT`, 0.15 s; 0.63 s into the deck's undock pre-roll): from `MAINS_ON` it was "far too late". Under it, the LTC layer is the game's own: `thruster_depart_<weight>` once and `ship_thrust_loop` at `Audio.SHIP_DB`, both from the `lateral` signal at `MAINS_ON`, the loop faded over 0.3 s at the exit. It ships as WAV like every other sound effect (`audio/README.md`: SFX are WAV so they start at once; `Audio.SFX_PATH` loads WAV).

The landing's take is one of four at random, each landing (Jon's "ALL", Nov 12): DA3, DB3, DC2 and DC4, the sound builder's game cuts (a 3.2 s body from the jets to touchdown, a 0.5 s ease-out, starting and ending on zero), shipped as `ship_landing`, `_2`, `_3` and `_4` for `Audio.play`'s round robin. It starts on the belly jets (`LAND_JETS_AT`; LadderTest checks within a frame), over the dock's own drive loop in, the row's flameout and the idle bed under the dark mains (`ShipView.dark_hum`), then the clamps.

## Crew

The crew near the blast walk off from it, whole steps on their own strides; the rest stop and look at it. On the deck, once the landing is over, they walk on from where they stood (`release`).

## Test

`ShipLiftTest`: both screens run the same class to its end, LAUNCH fires once, no click reaches the hall while the ship is in the air, reduced motion cuts, UNDOCK goes right and lands on LOCAL undocked.
