The reasoning behind the science mini games in the game (`tkg/scripts/ui/science/`); each heading is referenced from the code by a `Why:` line.

## The contract

The prototypes are the source: `tk-scratch/science/minigames/` (`API.md` is the contract; the phone
page `phone/src/` holds the final game files with their sound hooks, Nov 18; the review page in the
session scratchpad loads `coolant2.js` and `centrifuge2.js`, the same rules without the hooks). The
contract carries over as it is:

- `mount(depth 1-5, sensors 0-5, a seeded stream)`; the game draws only its puzzle.
- `done(score 0..1, detail)` exactly once (`MiniGame.finished`), a give-up included.
- The shell turns score and depth into the tier; a game never shows a tier.

`MiniGame` is a RefCounted, not a Node: the desk ticks it on its own clock (`DeskScene`'s, capped
at 0.1 s a frame and stepped by `--fixed-fps` in films), so a game never reads the wall clock (the
prototypes' `Date.now()` heat and `setTimeout`s become `t` and `after`). The headless test drives
the same object with a fixed step.

Which game a site deals, and its puzzle's seed, come from `Rng.derive(&"minigame", index)`
(`MiniGames.deal`), so a site deals the same puzzle every visit: leaving before the tap and
coming back cannot reroll it. The ship's SENSORS become the games' 0 to 5 at one step per two
points (`MiniGames.sensors_of`), a first guess: skill checks ask for 3 to 8 SENSORS, so most ships
sit at 1 to 4. Depth is the system's `MapGen.tier`.

`MiniGames.enabled` is the switch, as `DeskScene.enabled` is the desk's. `MiniGames.force` is the
dev flag's pick (`-- minigame coolant depth=3 sensors=1`).

## The canvas

`MiniPix` is the prototypes' `TK.pixel` canvas as an Image: `fillRect` is `Image.fill_rect`
(clipped), a pixel is `set_pixel`, a static layer drawn once (the centrifuge's housing and rotor)
is `blend_rect`. The palette is `TK.PAL` (UITheme's colours) plus the exotic and artifact tiers;
`TK.text`'s 3x5 font, `TK.dither` and `TK.icon` are ported whole, every kind of icon, so the next
games need nothing new. JS `Math.round` rounds halves up, negatives too, where GDScript's `round`
goes away from zero, so every port of a `Math.round` is `MiniPix.jr`.

A drawn frame costs about 1.3 ms (Coolant) and 2 ms (Centrifuge) at sector 5 (`MiniGameTest`
prints it). A game draws when something changed: Coolant at 30 frames a second while its coolant
flows, Centrifuge on a move, during the spin and for its start frame's icon.

## The shell

`MiniShell` owns the glass, 150 x 140 art pixels, one to an art pixel of the room: the game's
canvas centred above a strip (rows 131 to 139) that holds GIVE UP while it plays and the haul line
after. Both games' canvases are 144 wide and at most 126 tall, so they fit at 1:1, as on the
phone page (one shared scale, Jon: "bigger than the others?").

The tell (the game's one line and its control icons, Jon's Nov 17 rulings) goes on the desk's
title card under the site's name, in the card's phosphor, so it is read before the tap; the game's
own start frame repeats it, as the prototype's did. GIVE UP is a real button on the glass (and
Esc); it scores what the game had, and a failure still pays common.

The glass is set every frame it changes (`DeskRoom.show_screen`, the texture updated in place).
The rooms whose screen light follows the picture (DESK 2, BUNK, NOOK) read it on the CPU, about
21,000 pixels in GDScript, so that light follows the game twice a second (`LIGHT_EVERY`), not every
frame.

## Sounds

Jon's picks, copied from the phone page's `src/sfx/` (`sfx.json`, wired Nov 18) as
`assets/audio/sfx/mg_*.wav`, played at the file's level on the SFX bus as the page played them:

- Coolant: `turn` on every turn, `flow` when it routes, Four Kelvin's `win` 1.3 s after.
- Centrifuge: `seat` when a tube lands in a slot, `spin` (60 ms into the file), `win` on a balance.
- The reward ladder (Jon, Nov 18: the FTL-style blips, round 10; artifact is `art8_H`):
  `mg_reward_0` to `_6`, common to artifact. It plays a beat after the win, at the win's peak
  (1.283 s in), or 1.1 s after the end when there was no win, as the page timed it; a failure
  plays the common one, never a buzzer.

The haul line is swept in over the 0.65 s before the reward sound, the loot reveal's S1 split
shortened to one line. It reads `FLARE GLASS [EPIC]` (Jon, Nov 19: "ITEM NAME [RARITY]"): the
name in its tier's ink (`UITheme.tier_colour`, as the result page and the hold colour an item),
the bracketed tier in COLD, as the item tooltips set the rarity word quiet under the coloured
name. The tier is the material's own, which can sit under the tier won when the catalogue has
nothing at it (no uncommon rows today).

## Input on the glass

The desk's picture reaches the screen through the tube (`desk_tube.gdshader`), whose barrel curve
moves every glass pixel a little outward. A click is mapped back the way the shader samples:
the screen point, onto the 1920 x 1080 canvas, then through the same curve to the source glass
pixel (`DeskRoom.glass_at`), so a click lands on the pixel drawn under it, corners included.
While a game plays, every mouse event on the desk goes to it; Esc gives up instead of leaving, and
the desk cannot be left between the game's end and its take.

## The round 2 games

The nine more Jon loved (Nov 17) are ported the same way, each from its final file on the phone page
(`phone/src/games/`, the review page's `*2.js` plus the sound hooks): Ice Core (`icecore2.js`),
Pulsar (`pulsar2.js`), Tray (`tray2.js`), Anomaly (`anomaly2.js`), Beams (`beams2.js`), Spectrum
(`spectrum2.js`), Four Kelvin (`fourkelvin.js`), Cutting Torch (`wreck1.js`) and Leak Hunt
(`wreck3.js`). The prototypes' WebAudio tones were muted on that page (`TK_MUTE_TONES`), so they
are not ported; the picked takes play instead.

## Beams and Spectrum on the glass

The two prototypes were taller than the glass's game area (Beams 150 x 150; Spectrum up to 153 at
sector 5, a 13-px row a tube). Jon, Nov 19, shown three ways to fit them (shrink, the whole glass,
fewer tubes): "can't you make it the same aspect ratio and size as the other games?" So both were
re-laid out to the 150 x 130 area every game gets, the GIVE UP strip kept, rules and puzzle sizes
unchanged (his yes to the "fit2" sheet):
- Beams: LIT and its lamps, and TURNS, move into a 20-px column on the left; the table is the
  square beside it, cells `106 / n` (21 px at 5x5, was 23; 15 at 7x7, was 16); ALL LIT shows in the
  column.
- Spectrum: the tube rows keep 13 px; STAR and YOU sit closer, the meter is 5 px, the header is 37
  rows (was 46) and the empty bottom margin is gone; MATCH! prints on the meter, whose segment
  dividers drop once it is full so the word reads clean.

The prototype diff holds each against the prototype's own file with the same layout swaps
(`tools/dev/minigame/diff.py`, `LAYOUT`).

## Which game a site deals

Jon grouped the games by the site they are played at (Nov 18, page 6pDoF6JJ9CGLB8xiD4ytoQ):
- WRECKS, at derelicts and wreck fields: Cutting Torch, Tumble Dock, Leak Hunt.
- LIFE, at systems with fauna: Culture Dish, Centrifuge, Anomaly Count.
- ROCK, at barren worlds, moons, ice worlds and belts: Seismic Scan, Core Scan, Ice Core, Four Kelvin.
- SKY, at pulsars, red and blue stars, giants: Pulsar Fold, Star Light (Spectrum), Gravity Sling,
  Signal Tuning, Beam Bench.
- LAB, at any site: Coolant Routing, Sample Tray, Centrifuge.

`MiniGames.pool` is a group's games and the lab's, ported ones only. Today's science readings are
at barren worlds, belts and comets, all rock, so a reading deals `pool(ROCK)`. Science sites of
their own, with the sky, life and wreck kinds, are a separate feature (Jon, Nov 18: sites fully
apart from encounters); until then those games open by the dev flag.

## Coolant

`coolant2.js`, rule for rule: the walk, the second chamber's branch, the decoys, cracks beside the
route, the valve, sensors bolting route tiles that needed turning (the fix for Jon's "some harder
ones with high sensors are impossible?"), never dealt solved, the time limit from the pace model,
the score from heat and turns over par. Drawing order and every colour are the prototype's.

## Centrifuge

`centrifuge2.js`, rule for rule: the balanced load from rotationally symmetric sets, the per-sector
shape checks, blocked slots, the heaviest tube placed at sensors 3+, the dot's blur by sensors,
drag and tap both, the 2.2 s spin with the shake, the score from the imbalance and extra moves.

## Gravity Sling

`sling2.js`, rule for rule: the AIM dial and the pulled sling (Jon's "should be a dial, not a
click", which the final file already answers), masses placed off the launcher and the target with
one near the straight line, the control space scanned so a deal has at least two clean shots and
no more than 6% of shots hit, the moving target from sector 4, the no-fly zone at 5, the sensors'
predicted stub and extra launches. JS `Math.hypot` is V8's (scaled by the larger value), so
`GameSling.hyp` computes it that way and a pixel on a disc's edge lands where the page put it.

The scan flies 2,387 shots of up to 1,600 steps each, a blink in the page and far slower in
GDScript, so it stops at the 144th hit (the deal is dropped then either way) and the straight aim
is tried before it; neither touches the stream, so the deal is the page's (checked against the
page's own `gen` on the same draws: 20 deals, every field equal). The flight loop always pulls
three masses, a missing one far off with no pull, which adds exactly nothing. A deal still takes
about half a second, so the desk starts it on a worker as the card goes up, as it does the tray's
(`MiniGames.prefetch`), and the test keeps each deal for the scripted solve and the give-up
(`GameSling.memo_on`). The solver searches round the deal's good shot for one that lands near the
ring's centre, since a perfect score asks for a first-launch hit within about a fifth of the ring.

## The tray's search

Tray deals as `tray2.js` does: up to 400 random layouts, each one's every reachable state walked
(given up past 15,000) for its farthest start, then at sectors 4 and 5 every block tried as the
bolted one. In the page that takes a blink; in GDScript a sector 5 deal took several seconds. The walk
now holds each state as one integer and the tray as a 36-bit mask, and the bolted-block searches
reuse the walk's moves (`solve_in`), in the page's order, so ties break alike and the deal is the
page's (the diff at sector 3, and a check that the old and new walks agree, Nov 19). A deal can still
take 2 to 5 s at sectors 4 and 5, so the desk starts it on a worker as the card goes up
(`MiniGames.prefetch`) and the mount takes it, waiting out what is left. The test keeps each deal
so the scripted solve and the give-up skip a third and fourth search (`GameTray.memo_on`).

## The haul

`ScienceHaul.tier_of` is the prototype's `tierOf`: sector 1 tops out at RARE, 3 at EPIC, 5 at
LEGENDARY; only a near-perfect run reaches the top. The prototype's rare roll (EXOTIC at life
sites, ARTIFACT deep at wrecks) is not ported: today's science sites are worlds, belts and comets,
rock sites that stop at legendary.

`ScienceHaul.pay` is the one seam for the materials work. On main, materials exist
(`MaterialTable`, by `drops` table and tier) but not by science source, so it pays one material
of the tier won: from the site's table (mining for a world, a belt or a comet) when it has one at
that tier, else from any rolled table at that tier, else the nearest lower tier
(`row_for`). Into the system as every grant goes (`MaterialTable.grant`). The catalogue has no
uncommon row today, so an uncommon pays a common, and mining holds two rows, so most hauls come
from the other tables. The draft's twenty materials per source replace `row_for`.

It is paid inside the reading's take (`OptionResolve.take`'s `also`), so LOCAL's result page lists
it with the reading's own outcome. The reading's rule is unchanged: its fuel and its DATA are paid
as before, by the one rule the sim flies. Only the haul is new.

## Signal Tuning

The prototype's curves are 1200-point Lissajous figures, and its match test (`dist`) takes, for
every fourth point of one curve, the nearest point of the other by a full scan: 720,000 distances
a call. The deal calls it for every setting that might draw the target (40 at sector 5), and a turn
of a dial calls it again with the green-stretch map (`nearMap`). In GDScript that is seconds.
`GameTuning` sorts each curve into a 40 x 40 grid of cells and searches outward ring by ring; the
nearest distance it finds is the same number the full scan finds, summed in the same order, so the
deal and the score are the prototype's. Where the deal only asks "under the cap?", the sum stops
once it can only end over it, and a start under par 3 of the target itself is skipped before the
matching settings are listed (the best match can only be closer). None of these draws from the
stream.

The slow wander of your curve reads the page's clock itself (`performance.now()`), not the time
since the mount; the game's clock starts at 1000 ms, where the prototype diff holds the page's.

## Tests

`-- sheet=MiniGameTest` (headless, gated): every game, 50 seeds at every depth, sensors 0 to 5 in
turn; deals, deals the same twice, a scripted solve (`MiniSolver`: a plan of moves read from the
deal, or a pilot that flies Four Kelvin and the torch frame by frame, every move through the game's
own input) scores about 1, a give-up 0 to 0.2; the tier
ladder; every tier pays; a solve through the shell's glass at sector 5 pays legendary once, the
win then the reward sound. It counts work done, never time, so it holds on a busy machine.
`dump=<dir>` writes each game's deal and canvases for `tools/dev/minigame/diff.py`, which draws the
same deal in the prototype's own file in Chrome and counts the pixels that differ (0 for all eleven).

`-- minigame <id> auto=1` (windowed) plays the same solver through the screen in a real run (the
clicks found through the tube's curve), and with `--write-movie` it is the film.
