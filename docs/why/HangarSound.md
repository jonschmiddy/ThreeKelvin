# HangarSound

The reasoning behind `tkg/scripts/ui/HangarSound.gd` and `HangarCues.gd`: the ship-select rooms' sound.

## hangar-sound

Jon, Nov 25, after the sound3 page (`tk-scratch/shipselect/sound3/`, "The sounds are AWESOME"): "K A, S A, O A +
flicker 1 (filament tick) at +10 dB, buzz at +10 dB". All three rooms take concept A, "Cathedral of industry"; Old
adds the dying bulb's filament-tick flicker and a mains buzz, each 10 dB up on the page's sliders. The banner push is
B2 in every room.

The page played baked mixes (`out/mix/<room>_A.wav`) synced to the rooms' films. The game does not: the rooms' life
runs on the room's own clock (`ShipRoom.t`, process time, so films run true) and the banner pushes come from the
pointer, so a loop laid over them would drift off the picture. Instead every stem the mixer used is played by the
game, started from the life event it belongs to (`HangarCues`), with the mixer's rules applied as it applied them
(`sound3/tools/mix.py`, `_rules` in `out/cues.json`):

- **Sync**: a shot starts its stem `lead` s before its action, so its first sound (onset) or its contact (hit) lands
  on the frame the action shows. A hit more than 0.15 s into its take starts 0.12 s before the contact with a 0.1 s
  fade in (the mixer trimmed those takes the same way). The lead is divided by the take's pitch.
- **Depth**: `depth = clamp((400 - lane_y) / 190, 0, 1.4)`; dry level -7 dB a unit (heroes -2), the hall send
  0.35 (heroes 0.7) + 0.35 a unit, and a low-pass from 7 kHz toward 1.8 kHz with darkness (the cue's own darkness
  + 0.25 a unit). Each voice has its own bus with that low-pass (see depth-low-pass).
  The mixer normalised every stem after darkening it; the game's files are normalised before, so each voice adds back
  what its low-pass takes off that file (`lp` in `hangar.json`, 21 steps of darkness).
- **Pan**: `clamp(x / 960 x 2 - 1) x 0.75` (heroes 0.6, the flicker 0.3), constant power. Godot's panner is a
  balance control, so `pan_for` gives it the balance and the make-up dB that land on the mixer's constant-power
  gains. Point sources are stored mono (the mixer narrowed them to 30 %), heroes narrowed to 60 % and the hum to 80 %.
- **Crew**: at most two crew sounds at once, by priority (then id). A span over the limit fades out and back in over
  70 ms; a crew shot that would be the third is not started (the mixer's rule).
- **Variation**: every repeat picks its take, pitch (+-2.5 %, heroes +-1.5 %) and level (+-1.5 dB) by a fixed hash of
  (room, event, occurrence), so a room sounds the same each visit and never the same twice running.
- **Beds**: the room's two bed takes alternate every 15 s (Old 10 s) with 3 s equal-power crossfades, each segment
  from its own fixed place in its take, drifting +-12 % over 60 s (Old 30 s); under them the mixer's synthesized air
  (`mix.air`, 30 s, at 22.05 kHz since nothing in it is above 1 kHz) 4 dB down. All as the mixer built them.

The files are made by `tools/dev/hangar_sound.py build` from the sound3 folder (its game stems, `mix.air`,
`flick.idea_sounds(1)`, `keep/banner_B2.mp3`): every one at -20 dB loudest second (a sharp take lower, so it never
clips; its `loud` says so), loops folded seamless (the mixer's `fold`), with each file's loudness, onset, contact and
low-pass table in `tkg/assets/audio/hangar/hangar.json`. Loops import with `edit/loop_mode=2` and PCM (as
`ship_idle`, `shield_idle_bed`); one-shots with QOA, as every other effect.

Headless (the tests) it decides and logs every start and plays nothing; it loads no stream. In the sim, nothing.

It lives under the `Audio` autoload (`HangarSound.shared()`), not in the yard: a screen is freed the frame it is
left, and a player freed mid-sound clicks. Left, hidden or switched, a room's voices fade over 0.3 s; the hall's
tail rings out on its own.

**What it replaced.** The hull pick's room tone was the Shipyard deck's bed (`yard_bed`, `Audio.YARD_ROOM`, Jon's
Nov 11 "the yard front is the Shipyard deck's own hall"). The rooms now have their own beds, so the hull pick has no
room tone (`Router._room_for` gives `&""`, which fades whatever was playing) and `YARD_ROOM` is gone; the deck still
played `yard_bed` through `YardSound` until the station decks got their own rooms (Nov 26, `docs/why/StationSound.md`); the file is gone. The banners' `ui_hover` blip on pointing is gone too: the cloth's
push (B2) is the sound of pointing at a banner now, and two sounds for one gesture was the conflict. The banner's
click (`ui_click`) stays.

## cues

What starts each sound, read off the room's life (never the cue map's times, which were the film's). Korvan's life
draws film frame `pyround(t x 30)`, so its predicates read the state at that frame and an edge falls half a frame
before the film's time. Edges are sampled at 60 Hz (half the shortest life state) and halved to a tenth of a millisecond. Each room's cues are
worked out offline and baked (see baked-cues).

Korvan (30 s, `ShipRoomKorvanFilm`):

| Sound | Its event |
|---|---|
| `crane.brake` (hero, hit) | the first frame the crane is at its slowest on each 15 s pass (`film.json` crane x): frames 215 and 216 tie to 1e-12, the first is taken (the mix had 216) |
| `door.open`, `door.close` (hero) | the door panel's first moving frame up (`opening > 0`) and down (`opening < 1` after the hold) |
| `engine.spool` | the engine test's first burning frame (`burn > 0`) |
| `lamps.sag` | the first frame the hall's lamps dim below 0.99 and stay dim, once the engine burns: 10.18 s, where the mix had the burn's 10.0 (the dim shows 0.17 s after the burn starts, and the sound is the lamps') |
| `crane.travel` (loop) | the crane's speed x on screen, panned by its x, every frame |
| `forklift.cross` (loop) | the forklift's x (`fork_x` + 40, its middle), on screen, 1-27 s with 0.8 s ramps |
| `crew.weld.lift` | the lift welder's arc (`weld_pose`) |
| `crew.weld.ladder`, `crew.grind.ladder` | the ladder jobs' runs (`weld_state` of `weld8`) |
| `crew.grind.bench` | the bench grinder (`GRIND`) |
| `crew.crate.set` (hit) | the courier sets each crate down (`ShipRoomKorvanFront.crates_at`: carried, then not), and the drones set the deck's crate on its stack (`ShipRoomKorvanBack.stack_crate_shown`) |

Solari (30 s, `ShipRoomSolariCycle`, `ShipRoomSolariCrew`):

| Sound | Its event |
|---|---|
| `roar.furnace2` (hero) | furnace 2's roar starts (`roar_k > 0`) |
| `pour.tap1..6` | the stream reaches the mould (`u >= FALL`, the splash's first frame); tap 4 is the big one on even laps, tap 3 on odd |
| `crew.weld.lift`, `crew.grind.fettler` | `weld_state`, `grind_on` |
| `crew.plate.set` (hit) | the jib stops carrying its plate (the lowering's end) |
| `crew.jib.chain` | the hook's four moves (`JIB` down, lift, lower, up): over the mould, then the stack |
| `crew.trolley.roll` | each run of frames a bay's trolley moves (`ShipRoomSolariCrew.trolley_at`), gaps under 0.5 s closed |
| `embers` (loop) | steady |

Old (10 s, `ShipRoomOld`):

| Sound | Its event |
|---|---|
| `lamp.die.short`, `lamp.die` (hero) | the lamp's first dark instant of each outage (`lamp_step <= 0`): 2.05 s, 5.55 s |
| `flick.out` | the same instants |
| `flick.back` | the first lit instant after each outage (2.80 s, 6.85 s) |
| `flick.dip` | every other drop of the step (`0 < lamp_step < 1` begins): the bursts and the stutters back on, 20 a lap |
| `lamp.hum` (loop) | the lamp's drawn level each frame (`ShipRoomOld.level`, its schedule times a launch's beat) |
| `lamp.buzz` (loop) | see flicker-and-buzz |

Nothing in the cue map is left without a game event. One cue time moved to its event (`lamps.sag`, above), and the
crane's brake is one film frame earlier than the mix (the tie). Old's events land on the lamp's continuous clock
(2.050 s), where the mix had the film frame after (62/30 = 2.067 s).

## depth-low-pass

The mixer darkens a stem with a 2nd-order Butterworth run forward and back (`sosfiltfilt`): 24 dB an octave, 6 dB
down at the cutoff, no ringing. The game first used one `AudioEffectLowPassFilter` at `FILTER_24DB`, but Godot's
`db` counts biquad stages (6DB is one 2-pole stage, 24DB four, each stage's Q raised), so it fell about 48 dB an
octave with a bump below the cutoff: Jon's Nov 25 captures were 10 to 13 dB down at 4-8 kHz against the approved
mixes ("muddy, not as crisp"). Each voice bus now has two `FILTER_6DB` stages at Q 0.707, the mixer's response.

## crispness

Jon, Nov 25, on the captures that matched the page mixes: "maybe even less muddy sound for all three". `CRISP`
holds three levels he picks between by ear: A is the page mixes, B1 a bit crisper, B2 clearly crisper. Each sets
`dark_k` (every voice's darkness scaled, so the depth low-pass sits higher), the hall's `damp`ing and its 5 kHz
`shelf` (a brighter tail) and its level `hall_db` (less wash), and dB added to the bus EQ's bands: `mud` at
175-500 Hz, `pres` at 1.4-5.6 kHz, `air` from 8 kHz. `trim` holds each room's loudness (LUFS) to A's, measured
by capture, so a level is never just louder. The level comes from the command line (`hangarcrisp=B2`), else
`[audio] hangar_crisp` in settings.cfg, else `CRISP_DEFAULT` (B2, Jon's pick on Nov 26); `set_crisp` switches it live.

A first try (darkness x0.7 and x0.4) lifted Korvan's 4-8 kHz 11 and 17 dB and Old's 2 and 4: the darkness is
the big lever in the rooms with deep crews and does nothing in Old, so the levels lean on the bus EQ and only
nudge the darkness (x0.93, x0.85). Nov 25 captures, 30 s each, share of 20 Hz-16 kHz, at A's LUFS to 0.01 dB:

| | page mix | A | B1 | B2 |
|---|---|---|---|---|
| Korvan 2-8 / 4-8 kHz | -23.1 / -30.8 | -22.9 / -30.3 | -19.7 / -25.5 | -16.5 / -20.8 |
| Solari | -22.7 / -28.1 | -21.5 / -27.3 | -18.2 / -22.7 | -15.0 / -18.4 |
| Old | -34.3 / -48.1 | -33.6 / -46.5 | -31.4 / -44.0 | -29.1 / -41.7 |

## baked-cues

Working a room's cues out of its life samples its predicates every 60th of a second over the lap and halves each
edge: about 90 ms for Korvan and 140 to 165 ms for Solari, a visible hitch the first time a room showed. The lives
are fixed functions of the room clock, so `-- sheet=HangarCuesBake` (run by `python tools/dev/hangar_sound.py plans`)
works them out once (`HangarCues.compute`) into `tkg/assets/audio/hangar/cues.json`, one cue a line, and
`HangarCues.plan_for` reads that file (once a run) instead. Only the cues are baked; the layers (the crane, the
forklift, the hum and the buzz) follow the room each frame and are cheap to build. HangarSoundTest works every room's
cues out again and fails, naming the first cue and field that differ and the command above, when they are not the
baked ones (times within a microsecond): a changed life fails the test until the cues are rebaked.

## flicker-and-buzz

`flick_1.wav` on the page sat 12.2 dB over the cue map's flicker gains (`out/flick_levels.json`), so Jon's +10 dB
is each `flick.dip` / `flick.out` / `flick.back` at its cue gain (-10, -4, -12 dB, +-1.5 dB by its hash) + 22.2 dB,
at the lamp's lane (-9.8 dB, send 0.7), through the hall. The takes are `flick.py`'s idea 1, as it built them (four
ticks for the dips, two fizz-and-pop outs, two ticks back), each picked by (its place in the lamp's schedule + the
lap), pitch +-3 %.

The buzz is `buzz_dry.wav`, a 30 s loop of three lamp cycles already enveloped to the lamp (a faint bed 20 dB down
while it holds, swelling through each burst and dip, cut dead on each out's first dark frame). It plays at the room
clock's place in it (`fposmod(t, 30)`), re-seeked if it ever drifts 0.1 s, at -9.8 dB vs the bed + Jon's 10 dB,
send 0.7. On top of its own envelope the game cuts it to nothing on any frame the lamp is drawn dark, so it follows
the lamp's real state (a launch's beat too), not only the schedule it was built on.

## the-hall

One hall for the hangars (all three rooms are concept A: rt60 5.5 s, size 1.0, warmth 0.6), a Godot reverb bus
(`HangarHall`, wet only) with its tail shelved 6 dB above 5 kHz, fed by each voice's send player. Godot's reverb is
not the mixer's convolution, so it was set by measurement: `-- sheet=ShipRoomShot room=old hallprobe=1 film=24`
plays crate_1 dry alone, then into the hall alone; `tools/dev/hangar_sound.py hall` compares that capture with the
mixer's own hall fed the same thud. At room size 0.955, damping 0.5 and the hall bus at -10.5 dB: wet over dry
+2.25 dB (mixer +2.21), RT60 6.6 s (-5 to -25 dB; mixer 6.8 s) and 6.1 s early (mixer 6.8 s). Its top end is
Godot's (damping, the shelf), not the mixer's band-by-band decay.

## the-bus

`Hangar`, into Ambient: the mixer's bus EQ (HP 30 Hz, shelves and bells, `BUS_EQ`) as Godot EQ21 band gains (its
response at each band's centre), its 2:1 compression, a hard limiter at -3.5 dB, then the level the mixer's bus gave
that room's mix (`gain_db` per room in `hangar.json`, measured by re-running `mix.render`) and a trim.

Godot's compressor is not the mixer's: it multiplies the dB over its threshold by 2.08 and smooths the per-sample dB
rather than a 50 ms RMS, so its ratio is 1.3165 (2.08 x (1 - 1/r) = 0.5) and its threshold was set by capture
against each room's approved mix, `COMP_DETECT` dB over the mixer's RMS threshold. Nov 25, 30 s captures, LRA
(the mixer's meter): at -5.5 the rooms read 3.9 / 2.9 / 4.4 LU, at +2 4.9 / 3.5 / 5.4, at +6 Korvan 6.1 and Solari
4.2; the references read Korvan 6.0 (its 30 s halves 6.6 and 5.5), Solari 7.7 (6.5 and 8.5), Old with Jon's flicker
and buzz 5.5. So Korvan +6, Solari +12, Old +2. `LEVEL_TRIM` then sets each room's level so the Hangar bus (before
the Master and Ambient faders) sits where its approved mix does: -37, -37 and -33.5 LUFS (Old A at -38 plus the
flicker and the buzz each at Jon's +10 dB, summed as the page played them). At the default faders (Master 0.9,
Ambient 0.7) a capture reads 4.0 dB under that.

## banner-push

B2 (`sound2/all/banner/B2`, Jon's pick on Nov 24 and again on Nov 25), played on the frame the pointer shoves a
banner (`YardClothAir.forces`: the pointer comes onto the cloth and kicks it), through `Audio.play` like the
banner's click. Its level is the page's (-16.1 dB on a file whose loudest second is -15.9) beside the rooms, less
the faders' default gap (SFX 0.9 against Ambient 0.7). A soft shove is quieter, a fast one louder, by the kick's
strength: 10 log10(kick / 2.4), held to -4..+2 dB. A stir with nobody pointing makes no sound.

## the-test

`-- sheet=HangarSoundTest` (headless, `--fixed-fps 60`) shows each room on the real hull pick (Korvan, then Solari
and a locked set's Old hangar) for a lap and a second, and reads its life with its own predicates each frame. Every
life event must have its sound landing within one frame (start + lead), held-back crew shots counting, and every
sound must have its event; at most two crew sounds may be let through at once; Old's buzz must be cut on every dark
frame and full on every lit one, and run at the lamp's place in its three cycles. Then a room switched away from
plays nothing more and its voices are out in 0.4 s, the hull pick hidden starts nothing for 3 s, shown again it
plays, and leaving the screen leaves the hangar silent. `red=1` moves `door.open` 0.3 s off its door: it must fail.
