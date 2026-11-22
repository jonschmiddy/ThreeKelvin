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

`MiniShell` owns the glass, 150 x 140 art pixels, one to an art pixel of the room. Since status A
(Nov 20) the game's canvas is the whole glass: while it plays the shell draws nothing over it (a
152-wide canvas loses a column each side). Its tell is on the desk's title card under the site's
name, so it is read before the tap; the game's own start frame repeats it, as the prototype's did.

Esc gives up while a game plays (`DeskScene._input`); it scores what the game had, and a failure
still pays common. No click on the glass gives up.

The glass is set every frame it changes (`DeskRoom.show_screen`, the texture updated in place).
The rooms whose screen light follows the picture (DESK 2, BUNK, NOOK) read it on the CPU, about
21,000 pixels in GDScript, so that light follows the game twice a second (`LIGHT_EVERY`), not every
frame.

## Status A: the card and toasts

Jon, Nov 20, picking A of three: "I like A. You can just get rid of the bottom bar with GIVE UP. You
can just press ESC to give up." The strip under the game (GIVE UP, then the haul line and LEAVE) and
every game's status line are gone; their words go three ways (`fit/status_inventory.md`):

- The END word (ROUTED, OVERHEAT...) is the RESULT CARD. The game says it with `MiniGame.say_end`
  before `done`; the shell draws `MiniKit.result_card` over the game 0.6 s after the end, once the
  haul is paid: the word in its kind's colour, NAME [TIER] (the name in its tier's ink, the tier
  quiet in COLD, as the hold colours an item), an amber LEAVE. A give-up with no word says GAVE UP.
- A LIVE word (LEAK, NO LOCK, TOO FAST...) is a TOAST: `MiniGame.say`, drawn by the game last in
  its frame (`draw_toast`), rows 12 to 22, full for 0.9 s, then two dithered steps, gone at 1.2 s.
  It never takes a click.
- A STANDING readout (COLD 1/2, VALVE DRY) finds its own spot or goes when the board shows it.

While the card is up a click anywhere on the glass, or Esc, leaves. This overrides Jon's Nov 19
"only LEAVE leaves" for the result card alone: the card covers the game, so every click on it is a
click on it. The reward sound keeps its timing (the win's peak, or 1.1 s after the end), and the
card's NAME [TIER] row is swept in over the 0.65 s before it, the loot reveal's S1 sweep.

## The start card goes on any click

Jon, Nov 20: any click anywhere on the glass hides the start (tell) card, in all seventeen games. In
Ice Core the card covered ONE UPSIDE DOWN until the first drag, and a click on empty space did
nothing: the card waited on the game's own `acted`, set only by a button or a drag.

The rule is in one place. The shell sends every press through `MiniGame.glass_down`, which sets
`told` and then calls the game's own `down`, so a click on something playable still does that
thing. Each game's card asks `not told` beside its own flag; nothing else reads `told`, so the
click changes no rule, score or deal. A key game (Four Kelvin's W, A, D) still hides it on its
first key. The paper pages do the same in `kit.js` (a capture `pointerdown` listener, then
`KIT.tell` draws nothing), so `diff.py` stays at 0 px. MiniGameTest clicks the header's top-left
corner (glass 1,1, a label in every game) on one of two twin shells: the next frame has no card,
the canvases differ only in the card's box, and the state is the twin's. Anomaly and Four Kelvin
already start their clock on any click and the tray marks itself started; those flags may differ.

## The UI kit

Jon, Nov 19: "I'd like the UI/UX for all of the games to be about the same as much as possible."
The kit (`tools/dev/minigame/layout/kit.js`, its rules in `kit_spec.md`) was drawn round every game
on sheets and approved Nov 20: "Perfect." `MiniKit` is its port, function for function, so a game
calls the kit and never draws its own chrome. The rules, in short (status A, Nov 20):

- Every game draws exactly 150 x 140, the whole glass (152 x 140 for the torch, the leak, the dock).
- One header row (band rows 0 to 8, rule on row 9): the game's main state left, its counters right.
- Games with on-screen controls have a deck: rule on row 116, the control row 117 to 139 centred
  on 128. Games without have none: the play area runs to row 139. There is no status line.
- One tell card, two lines (Jon, Nov 20: "CONTROL [GAME INSTRUCTIONS] / [ESC] TO GIVE UP"): the
  game's icons and words, then the ESC key cap (`MiniKit.ESC`, at rest) and TO GIVE UP in the quiet
  label ink. Rows 45 to 73, centred on x 75; rows 12 to 40 (`TELL_TOP`) for the tray and Four
  Kelvin, 33 to 61 (`TELL_HIGH`) for the dock, where the middle hides the sample, the ship or the
  spin arc. One button style, one meter, one dial, the result card and toasts,
  solid #111823 borders, and four accents with one meaning each: yours amber, goal blue, good
  green, bad red.
- Pulsar, Sling and Tuning keep their own dials.

`MiniKit.status` and `STATUS_TY` are no-ops kept only while games move to A; a moved game never calls them.

## Sounds

Jon's picks, copied from the phone page's `src/sfx/` (`sfx.json`, wired Nov 18) as
`assets/audio/sfx/mg_*.wav`, played at the file's level on the SFX bus as the page played them:

- Coolant: `turn` on every turn, `flow` when it routes, Four Kelvin's `win` 1.3 s after.
- Centrifuge: `seat` when a tube lands in a slot, `spin` (60 ms into the file), `win` on a balance.
- The reward ladder (Jon, Nov 18: the FTL-style blips, round 10; artifact is `art8_H`):
  `mg_reward_0` to `_6`, common to artifact. It plays a beat after the win, at the win's peak
  (1.283 s in), or 1.1 s after the end when there was no win, as the page timed it; a failure
  plays the common one, never a buzzer.

The result card's NAME [TIER] row is swept in over the 0.65 s before the reward sound, the loot
reveal's S1 split shortened to one line. It reads `FLARE GLASS [EPIC]` (Jon, Nov 19: "ITEM NAME [RARITY]"): the
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

On status A (Nov 20, `a_swaps.PULSAR` and `ANOMALY`): Pulsar keeps its own r 14 dial (Jon) and its
own deck, which moves down the 10 freed rows whole (rule 95 to 105, the dial's ring on rows 107 to
137); the phosphor glass grows into them (the waterfall 45 to 55 rows). NO LOCK, WEAK and the first
of two LOCKED are toasts; LOCKED, WEAK or LOST at the end is the card, said at the lock (the take
follows 0.9 s later, as before). Anomaly's lens goes back to its prototype size (r 55, critters
x1.7) in the middle of rows 10 to 139; the rule, a standing readout, sits in the bottom corners the
round lens leaves free, one term a line in goal blue, an OR rule's second half bottom-right under a
neutral OR. WRONG is a toast on a wrong pick; ALL LOGGED or TIME UP is the card.

Four Kelvin on status A (`a_swaps.FOURKELVIN`): the belt takes the freed rows, 82 to 100 (rows 10
to 109, world 1:1, the progress bar 112 and 113, the deck from 116). Rocks are dealt per area
(`dens x BH / 82`), so the taller belt is no emptier than the approved one. IMPACT or BELT CLEAR is
the card when the run ends; it has no live words (the WARNING: ROCK tag stays in the view).

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

On status A (Nov 20, `a_swaps.BEAMS` and `SPECTRUM`) both take the whole glass:
- Beams: the table, its frame and the emitter sit in rows 11 to 138 with 1 px side margins, cells
  as big as those allow (the 106-px cap was the LIT column's, gone with the kit header): 24 / 20 /
  17 px at 5x5 / 6x6 / 7x7 with the emitter at a side, 22 / 18 / 16 with it above or below. ALL
  LIT is the card; there are no live words.
- Spectrum: the tube rows share rows 36 to 139 (104, was 85), the tubes up to their 14-row cap.
  LINES m/n moves to the header, its value red while extras are on; the MATCH meter shrinks to fit
  the widest right side (33 px, or 25 when the star has 10 lines or more) and its percentage goes.
  n EXTRA is a toast when a wrong tube goes on; MATCH! is the card.

## Which game a site deals

Jon grouped the games by the site they are played at (Nov 18, page 6pDoF6JJ9CGLB8xiD4ytoQ):
- WRECKS, at derelicts and wreck fields: Cutting Torch, Tumble Dock, Leak Hunt.
- LIFE, at systems with fauna: Culture Dish, Centrifuge, Anomaly Count.
- ROCK, at barren worlds, moons, ice worlds and belts: Seismic Scan, Core Scan, Ice Core, Four Kelvin.
- SKY, at pulsars, red and blue stars, giants: Pulsar Fold, Star Light (Spectrum), Gravity Sling,
  Signal Tuning, Beam Bench.
- LAB, at any site: Coolant Routing, Sample Tray, Centrifuge.

Where the two places with no kind today go (Jon, Nov 19, for the science-sites feature): LIFE sites
are on living worlds, planets with a biosphere; PULSAR sites are at the pulsar itself, in pulsar
systems ("I couldn't imagine it any other way! Yes.").

`MiniGames.pool` is a group's games and the lab's, ported ones only. Today's science readings are
at barren worlds, belts and comets, all rock, so a reading deals `pool(ROCK)`. Science sites of
their own, with the sky, life and wreck kinds, are a separate feature (Jon, Nov 18: sites fully
apart from encounters); until then those games open by the dev flag.

## A site's own deal

`MiniGames.OWN` maps a site to the games a reading there deals in place of its group's and the
lab's. Before it every reading dealt `pool(ROCK)` wherever it was, which is how a comet dealt
Centrifuge (Jon, Nov 21: "When I tried to do the comet science, I got the centrifuge game, which
was weird").

Jon ruled C on Nov 21: "only the new comet game once you've picked it, with another, and also
Ice Core." Ice Core (ice cores; its tell is STACK THE LAYERS IN ORDER) dealt alone until his
comet pick was ported; since Nov 22 a comet deals Ice Core or Skim (`OWN`, below), the deal's
first draw picking one. Every other site deals as before.
The deal still draws from `Rng.derive(&"minigame", index)` in the same order, so no other site's
deal moves. The comet's haul stays mining: its readings are of ice and rock, the rock group's.
`MiniGameTest._site_deals` prints what each site deals and checks a comet deals those two and
nothing else, both turning up over 64 systems.

## Coolant

`coolant2.js`, rule for rule: the walk, the second chamber's branch, the decoys, cracks beside the
route, the valve, sensors bolting route tiles that needed turning (the fix for Jon's "some harder
ones with high sensors are impossible?"), never dealt solved, the time limit from the pace model,
the score from heat and turns over par. Drawing order and every colour are the prototype's.
Since Nov 20 it is the approved page (`layout.page_js("coolant")`: fit4 + `KIT_COOLANT` + `a_swaps.COOLANT`):
150 x 140, tiles as big as the play rows (11 to 138) and 1 px side margins allow (24 px at sectors 1
and 2, 20 at 3 and 4, 16 at 5), the header and the tell from `MiniKit`. It is the first
game on status A: COLD n/m and the valve's word drop (the grid shows both), LEAK is a toast when a
leak opens, ROUTED and OVERHEAT go on the shell's result card.

## Centrifuge

`centrifuge2.js`, rule for rule: the balanced load from rotationally symmetric sets, the per-sector
shape checks, blocked slots, the heaviest tube placed at sensors 3+, the dot's blur by sensors,
drag and tap both, the 2.2 s spin with the shake, the score from the imbalance and extra moves.
On status A (Nov 20, `a_swaps.CENTRIFUGE`) the bowl keeps its size (the width binds it beside the
rack) and the set drops 9 rows to the middle of the glass; READY and SPINNING drop (SPIN's amber and
the spin say them), BALANCED / WOBBLE n% / ROTOR FAULT go on the card.

## Ice Core

On status A (Nov 20, `a_swaps.ICECORE`) the 18 freed rows go to bigger pieces: core layers 8 -> 10
rows, the tray's sockets 10 -> 12, the tube's slots up to 11 rows (a 10-row layer, the cores' own)
in 88 rows. n/N IN PLACE after a CHECK is a toast; ORDER CONFIRMED, or the last check's count, is
the card. The tell reads STACK THE LAYERS IN ORDER. (140 px; ESC is on its second line).

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

On status A (Nov 20, `a_swaps.SLING`) the dial keeps r 13 and the sling its pull (Jon); the field
grows to the whole width at the scale the width allows (0.1375 to 0.15: 138 x 88 to 150 x 96, rows
10 to 105) and the deck's rule drops 98 to 106, its dial and sling 1 row lower in it so they sit
centred. The deck still greys out while a probe flies and after the end. TOO WEAK, MISS n, IMPACT
and NO-FLY are toasts; HIT or OUT OF PROBES is the card; LAST n stays in the header.

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

`ScienceHaul.pay` pays one material from the material list (Nov 19): the site's group picks the
source (rock: mining; sky and pulsar: cosmic; life: fauna; wreck: wreck; today's readings are all
rock), `MaterialTable.pick` takes a row of the tier won or the nearest lower one that source has,
and `MaterialTable.grant` puts it in the system as every grant goes. The line reads the row's own
name and tier (NAME [TIER]). Nothing of the table is kept in `ScienceHaul`: the tier keys are
`MaterialTable.TIERS`. MiniGameTest holds every site group to a real row of its own source at every
tier.

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

On status A (Nov 20, `a_swaps.TUNING`) it keeps its own knobs (r 7), now on the control row's centre
so their ticks fill rows 117-139; the knob values drop (a right dial wears its green collar, YOURS
draws the value); the two scopes, bound by the width, drop 9 rows to the middle of the play rows.
MATCH! / NO MATCH go on the card. Sample Tray (`a_swaps.TRAY`): cells 17 -> 18 px, UNDO at the foot
of the right column under the rim, SAMPLE OUT on the card.

## Seismic Scan

`seismic2.js` in its approved page (`layout.page_js("seismic")`: fit3, rings "B", the kit; Nov 20),
rule for rule: the finds placed off each other and the rare ones off the middle, a field kept only
when the page's own screen-only `solver` digs out every find (the first that fails is the fallback),
sensors as extra scans, reach and a dig, the score from the finds' value and the charges left. The
solver's distances are all between whole cells, so `GameSeismic.Field` takes them from a table
(V8's `Math.hypot`, as Sling's, so a tie breaks where the page's does), and a scan's echoes are
sorted stably, as V8 sorts. The sweep and its echoes move on the page's 30 frames a second whether
or not the frame is drawn. The page's touch path (press to preview, lift to act) is not ported: the
desk is a mouse, so a press acts, as the page's mouse path does.

On status A (Nov 20, `a_swaps.SEISMIC`) the field keeps its cells (the width binds it, beside the
tool column) and centres in rows 10-139; the graph screen grows 16 rows to row 137, its tier rows
14.2 px apart. A dig's result is a toast in the find's tier ink (the kit's `t0`-`t4` kinds), CLOSE
neutral, EMPTY bad; a scan that hears nothing says QUIET. ALL DUG / NO DIGS LEFT go on the card.

## Core Scan

`tomo2.js` in its approved page (`layout.page_js("corescan")`: fit3, the kit; Nov 20), rule for rule:
a picture of the sector's size (and its mirror) dealt from those a line-by-line solver can finish,
the rows sensors fill in drawn from the stream after the deal (`TK.shuffle`), cracks and the ones
forgiven, the score from cracks and time over par. On status A (Nov 20, `a_swaps.CORESCAN`) the
clues and glass centre in rows 10-139 (from `deck_y`); FOUND: NAME / SCAN LOST go on the card.

## Culture Dish

`culture2.js` in its approved page (`layout.page_js("culture")`: fit3, the kit; Nov 20), rule for
rule: seeds placed off each other, stains just past the reach, food near its far edge, a deal kept
only when every seed matters and few other spots win; GROW one ring at a time, the faint rings
ahead, extra tries from sensors, the score from the food fed, the try and the time. The page's
clock is in milliseconds from 1000 at the mount, and it works out the growth (food fed, cells killed)
only on the frames it draws, at most every 32 ms, so the game does the same whether or not the frame
is drawn; its buttons are the ones its last frame drew. A press works as the page's touch path:
press to preview the rings, lift to drop the seed (the diff's pointer is not a mouse); a hover
previews too. JS `sort` is stable and GDScript's is not, so the food's sort breaks ties by place.
The look's own hash (`hr`) multiplies past 2^53 in doubles, as the page does.

On status A (Nov 20, `a_swaps.CULTURE`) the dish grows (rim 55 -> 60, agar 51 -> 56, the hex
spacing 6 -> 6.5 and 5 -> 5.5: the same board and rule) on row 70, its shadow 1 px clear of the
buttons; the seeds and rings left sit on the buttons' row. DEAD k joins FED in the header while the
try has any; the try's line (ALL FED, or n/m FED  k DEAD  NO TRIES, or what KEEP kept) is the card's.

## Tumble Dock

`wreck2.js` in its approved page (`layout.page_js("dock")`: fit3, the kit; Nov 20), rule for rule:
the spin and the drift built up through the lag, the latch, the clamp's sway at sector 5, the score
from gas over par, time and how slowly it docked. 152 wide like the torch; the kit is drawn on a
150-wide layer laid 1 px in (the page's `translate(1,0)`). The cargo shift is never dealt (`shift`
is 0), so its debris is not ported. The page's own test bot goes over par at sectors 4 and 5 (a
third to a half of deals score 0.84 to 0.95), so `DockPilot` flies it better: it settles the drift first,
stops it as its rest point enters the bracket, then tapers the spin a turn ahead and stops it as
the port's rest point reaches the bracket's near edge, so it latches slowly. On the page's own
sim, 300 deals at each sector score 0.95 to 0.99.

## Skim

Jon's comet pick (Nov 21: comet A, round 2, the harder one; `tk-scratch/science/comet/games/comet_a.js`,
its film `films/comet_a.mp4`). A comet deals it or Ice Core (`OWN`). It is a port step for step:
the same 1/60 s step, the head's curve, the tail's drift and ripple, the grit's schedule, the
spring tether, the scoop and the spill, with every depth's number and the sensors' two (the scoop
3 + 0.35 S, the ice's life 3.4 (1 + 0.07 S)) as the page has them. The page's comet is drawn in
its mount from `ctx.rng`, so `GameSkim.gen` takes the same draws in the same order; the grain
noise is the page's `mulberry`, done on 32-bit values (`mb_next`, `mb_value`, `_imul`), and its
`Math.hypot` is `GameSling.hyp`. Grains are six parallel arrays kept in the page's order, because
the scoop draws noise grain by grain from the end. The glow's blur is scattered from each grain
rather than gathered per cell: every sum is a multiple of a quarter, exact in any order, and it
costs a ninth. Sparkles age a drawn frame at a time, as the page ages them in its draw.

The page was written in the kit, so `diff.py` runs `kit.js` and the file as they are (no layout
swaps). Its dump holds the stream's draws from the start, written at full precision, and flies a
second of frames 1/16 s apart, a step both clocks hold exactly; both frames are 0 px.

The page's own film bot rides behind the head and dodges by the next burst's lane; it fills the
hold at sector 3 about half the time (the page's own note), so `SkimPilot` plays it better. It
reads every rock's line (in flight, and the deal's schedule of the rest), tries spots in the head's
frame behind the keep-out ring, scores each by the young ice there a moment on, and throws out any
the probe would pass a rock on its way to (the way there is the tether's pull as its aim asks for
it). When every spot is near a lane it takes the one the grit passes farthest from. On 50 seeds at
each sector, sensors 0 to 5 in turn, and 60 at sector 5 with sensors 0, it fills the hold every
time. Before the way there was checked, 1 deal in 20 at sector 5 lost a fifth of the hold to grit.

## The camera games on the whole glass

Cutting Torch, Leak Hunt and Tumble Dock are camera views under the kit (status A, Nov 20,
`a_swaps.py`). Each view now runs to the deck's rule at 116, 18 rows more than before. The torch's
hull plate is 18 rows taller; the crate, the lines and the gaps are the same sizes. The leak's
back wall is 18 rows taller, and the band where a leak can sit grows with it, since it is the wall
above the consoles. The dock's spin centre drops 9 rows. Each game's toast and the rest of the kit
are drawn on the 150-wide layer, 1 px in, so the toast's dither lands where the page's does.
A word the status line held for 99 s is the END word, for the card; any other word is a toast.
The dock's SPIN, DRIFT and STILL readouts are gone, because the arrows already turn green when the
wreck is slow enough. TOO FAST is a toast that shows once each time the port enters the bracket
too fast for the clamp. The old status line said it whenever the port was close, so every slow
approach showed it too.

## Tests

`-- sheet=MiniGameTest` (headless, gated): every game, 50 seeds at every depth, sensors 0 to 5 in
turn; deals, deals the same twice, a scripted solve (`MiniSolver`: a plan of moves read from the
deal, or a pilot that flies Four Kelvin and the torch frame by frame, every move through the game's
own input) scores about 1, a give-up 0 to 0.2; the tier
ladder; every tier pays; a solve through the shell's glass at sector 5 pays legendary once, the
win then the reward sound; while it plays the glass is exactly the game's canvas and no click
leaves; the game names its end (`say_end`); 0.6 s after the end the result card is up, pixel for
pixel `MiniKit.result_card` with that word and the paid NAME [TIER], and a click anywhere leaves;
Esc (`give_up`) ends it with GAVE UP and the same card; at every depth the start card is the kit's,
its ESC TO GIVE UP line under the game's own, which lists no ESC, and a click on empty glass hides
it and changes nothing else. Every deal draws exactly 150 x 140. It counts work done, never time, so it holds on a busy machine.
`dump=<dir>` writes each game's deal and canvases for `tools/dev/minigame/diff.py`, which draws the
same deal in the prototype's own file in Chrome and counts the pixels that differ (0 for all eleven).

`-- minigame <id> auto=1` (windowed) plays the same solver through the screen in a real run (the
clicks found through the tube's curve), and with `--write-movie` it is the film.
