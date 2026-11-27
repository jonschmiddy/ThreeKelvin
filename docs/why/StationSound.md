# StationSound

The reasoning behind `tkg/scripts/ui/StationSound.gd` and `StationBus.gd`: the station decks' sound.

## station-sound

Jon, Nov 25, on the station sound brief (`tk-scratch/station-sound/brief.md`): 1B five rooms, each deck its own bed and
reverb as the hangars have, no station bed under all of them; the PA keeps its several voices; unclaimed gets an old
recorded PA loop that cuts out; the yard's joke events stay silent; the Lab and the Board keep their own sound with the
station muffled behind them. Nov 26, from whole-room mixes over each deck's film (page KqbFQqBfBSy2Z9Vo36Sn4s): Promenade
B "Lunch arcade", Promenade unclaimed C "Closing time", Shipyard B "Clean factory", Shipyard unclaimed A "Empty hangar",
Exchange B "Server room", Hiring Board B "Strip lights". Later that day the Lab: C "Far plant" (the-lab).

The page played baked mixes cut to films. The game does not: every deck's life runs on its own clock, so a loop laid
over it would drift off the picture. As in the hangars, every stem the mixer used is played by the game and started from
what the deck shows, with the mixer's rules (`tk-scratch/station-sound/mix/tools/smix.py`) applied as it applied them:

| Deck | Sound | What starts it |
|---|---|---|
| Promenade | `step` (hit) | the nearest walker you can see (the tallest drawn in the last tenth of a second) reaching a foot-down frame (frame 0 or half its cycle); quieter, wetter and darker by its depth, 1 - its height over the tallest's |
| Promenade, unclaimed | `lamp` | the failing lamp's flicker jumping after a second of calm (the lamp's tick, `lab_unclaimed_flicker`) |
| Shipyard | `weld` (span) | the welder's arc on (`YardLife.weld_now`), faded in over `fin`, out over `fout` |
| Shipyard | `fork` (loop) | the forklift: its level from its speed and its lift's (`FK`), panned with it, every frame |
| Shipyard | `flyer` | a flyer under the ceiling (`AMB`): started its lead (2 s) before it crosses the yard's middle |
| Shipyard | `hatch` (hit), `bump` (hit) | the floor hatch's head (`HEAD`), the two drones' contact (`YardDrones.bonks`) |
| Shipyard, unclaimed | `bulb` (hit), `console` | the bad bulb's pop (`YardLight.pop_t0`), the console crash (`CRASH`) |
| Exchange | `pass`, `pass_far` | a ship through the window, started its lead (1.6 s) before its middle crosses the screen's (`ExchangeScene.passes`, the same rolls `_pose_cast` draws) |
| Hiring Board | `tube` (loop) | the tubes' light (`BoardLamp.level`), every frame: it cuts on every stutter |
| Hiring Board | `layer:station` | steady: the Promenade's bed low-passed at 420 Hz, as through a closed door |

The yard's jokes (E6 the screen joke, E11 the cat, E12 the cat's ride, E13 the paper plane, E18 the sneeze, E20 the cat
chase) have no sound (`StationSound.JOKES`). The random clank, air tool, hiss and hoist are gone (the brief: "replace
the random clank/airtool/hiss/hoist with the welder, grinder and forklift you can see"); so is `yard_bed`'s place on
the deck. `YardSound` keeps the TV's power-on, the drones, their work and the lights' flickers, as they were.

The Board's own sounds (the tubes' strikes and flickers, a screen's power-on, the ads' jingles, the popups) play
through the Board's room as the mix had them (`StationSound.keep`): a tamed copy of each (`board_<name>.wav`) at its
plan level, 0 dB, the popups -10 (the plan's flag). They used to play through `Audio.play`; matched there by the raw
file's loudness, the flicker came out 13 dB short of the mix in its mids, as the mixer's `tame` takes 13 dB off it
before levelling it. Off the Board (and with no plan) `keep` is `Audio.play` as before.

The yard's tired lamps no longer tick on every dropout (`YardSound._dropouts`, about two a second at an unclaimed
station): Jon's pick has no such sound, and the bulb's pop is the room's own event. The TV's flicker stays.

Every repeat picks its take, pitch (+-3 %) and level (+-1.5 dB) by a fixed hash of (deck, event, occurrence). A shot
synced on its contact starts 0.05 s before its contact when it is seen as it happens, or its contact lands on the
predicted frame when the action can be seen coming (a flyer, a ship, a bump); synced on its onset it starts there.
Nothing starts while the car rides (`tick`): a ride fades every event out over 0.2 s and the next deck's bed comes in
from the hand-over. The PA waits for the car to stop.

The files are made by `tools/dev/station_sound.py build` from the station-sound folder: beds tamed (the mixer's `tame`
at their darkness) and folded seamless, the Board's muffled station low-passed and stored at 11.025 kHz, every point
source mono and tamed, each file at -20 dB loudest second with its loudness, onset, contact and low-pass table in
`tkg/assets/audio/station/station.json`. Loops import PCM with `edit/loop_mode=2`; one-shots QOA.

Headless (the tests) it decides and logs every start and plays nothing; it loads no stream. In the sim, nothing.

## tiers

Every station has all five decks at every level (Jon, Nov 3), and Jon picked two rooms a deck. plan.md's tiers: the low
beds below settlement, the high from it, capital the same bed darker and lower. The PA's speaker is by deck, #the-pa. So:

| Deck | unclaimed | outpost | settlement, city | capital |
|---|---|---|---|---|
| Promenade | C, the tape | C's bed | B | B, its bed darker (0.35) and 3 dB down |
| Shipyard | A, the tape far off | A's bed, the live PA far off | B | B, darker and 3 dB down |
| Exchange | B, the tape | B | B | B, 3 dB down |
| Hiring Board | B, the low tiers' Promenade behind the wall, the tape | B, the low Promenade behind | B (the high Promenade behind, the mix's own) | B |
| Laboratory | C's bed; the low Promenade behind the door, the tape | C, the low Promenade behind | C, the high Promenade behind | C |

The bus numbers (the level the mixer's bus gave a room, its compressor's threshold) come from re-running the picked
mixes; a tier's variant takes its pick's.

## levels

As the hangars' (`docs/why/HangarSound.md#the-bus`): each room's bus sits where its page mix does (-37 LUFS, the
mixer's target, before the Master and Ambient faders), so a capture at the default faders (Master 0.9, Ambient 0.7)
reads about 4 dB under its page mix, as a hangar's does, and about where the old station tone sat (-41.9). The bus gain
the mixer gave each room is in `station.json`; `LEVEL_TRIM` is what the captures (Nov 26, 40 s from 8 s in, the
compressor's detect at +8 dB) said was left: -3.6 to -5.1 dB, the Godot compressor and EQ being gentler than the
mixer's, as in the hangars. The tier variants share their pick's trim.

## crispness

Jon, Nov 26: "The Shipyard sounds should also be as crisp as hangar B2." Both Shipyard rooms take the hangar's B2:
every darkness x0.85, the hall's 5 kHz shelf 0.8/0.5 of its own, the hall 2 dB down, the bus EQ -2 dB at 175-500 Hz,
+4 dB at 1.4-5.6 kHz and +4 dB from 8 kHz; then a trim (`LEVEL_TRIM`) holds its loudness to its page mix's by capture.
The hangar's B2 also lowered the reverb's damping; Godot's damping runs the other way (a higher value is a brighter
tail: `reverb_filter.cpp` damps with `exp(-2 pi (damp / 2 + 0.5)^2 10 kHz / rate)`), so the station leaves it alone.

## the-pa

Jon's Nov 26 script and takes (tk-scratch/station-sound/pa_script_v2.json, pa_v2/takes; ship_4 and welder_1 cut). The
game reads `tkg/assets/audio/station/pa.json`, made by tk-scratch/station-sound/pa_v2/game/make_pa.py and measured by
`station_sound.py pa`: one row a line (id, speaker, text, `when`, tiers, file, `play`, its loudness and length), the
chime and the bang. The takes are dry (no chime, no echo), so the game adds both.

**The chime** is the head of an old Sep 18 take (`ambience/pa_02.ogg`; every one opened on the same two-tone chime),
cut where its voice came in and faded. It plays before each staff and Recording line through the deck's speaker, at the
level it sat on the old take (`ref_loud`), and the voice comes in 2 s after it starts (the old takes waited 2.58 s; the
chime is gone by 1.5 s). The tape has none: it is a recording, not someone at a desk.

**When.** After a fresh docking the first line is a dock line, 5 to 8 s after the first deck shows, past the dock's
clunk and the deck's power-on; where the tier has none (capital, unclaimed), a bag line 15 to 25 s in. Then a line 60 to
120 s after one ends, never in a ride, one at a time. Jon (Nov 26) wants it really random: the bag and the dock lines'
own bag are static, so they last the whole run across dockings and decks, and the pool is heard before any line twice.
A bag drawn dry of lines that fit here gets the lines it no longer holds back at its front, shuffled, so what is left
is heard first. No two lines with the same `when` run back to back while another fits, and no line twice running.
`pa_rng` deals it all (the test seeds it).

**Roles** (`play`). `dock`: the dock lines' bag. `bag`: everything else that plays on its own, filtered by tier, by
`decks` where a row names some (the five lines about things in the yard: forklift_1, welder_2, shift_1, scrubber_1,
free_5), and by `needs` (lift_2, "working again", only once lift_1 was heard this docking). `after`: a follow-up, never
on its own: about one lead in three, 5 to 10 s after it ends (free_2 after a ship_ line, correct_1 after a hauler_,
correct_2 after a board_), dropped if a ride holds it 15 s. `leave`: no moment plays it. Undocking goes straight to the
sector (or rides to the yard first, which hushes the PA) and the decks fall silent as the screen goes, so no station
sound is heard as you leave; the rows wait for such a moment. reactor_1 ("That bang was the reactor venting") has
`bang`: no deck has a reactor sound of its own, so the game's heaviest low blast (`sfx/explosion_small_3`) plays first
far off through the deck's room (fully dark, wet 0.6, 2 dB under the deck's PA level), and the chime 1.2 s after it.

**Speakers** (Jon, Nov 26, from three ideas filmed). The old takes were already a PA's band (250 Hz sat 30 dB under
1 kHz); the new are full range. Through the mixer's wall and door low-passes (520, 380 Hz) they came out all chest, a
boomy mumble played at full level once `speaker_db` made the loudness up, and through `clear` (220 Hz-6 kHz) a hi-fi
voice in the room; Jon: "weird". The yard's `far` chain (260 Hz-2.4 kHz, steep) cuts them to the old band and its wet
puts them far off; Jon: "GREAT". Of three ideas (A the yard's PA everywhere, B a small speaker in the room, C the PA out
on the concourse through a doorway) he picked per deck: the Promenade and the Exchange A, `far` at wet 0.4 into the
deck's own hall; the Hiring Board and the Lab B, `ceiling` (300 Hz-3 kHz) in the room, not behind the wall, the room's
own short echo (its `wet_base`), 4 dB over the mixer's through-wall level, then by capture the Board 3 dB more and the
Lab 2 dB less, so each line sits about as far over its bed as the old ones did; the yard its `far` as the mixer had it.
Unclaimed reads the tape (`tape`) through each the same way. `station_sound.py` (PA_KIND, PA_DB, `pa_room`) makes each
room's `pa` from the mixer's, kept beside it as `mixer`. `speaker_db` is measured on the dry takes.

**The tape** (unclaimed) is code too: wow and flutter on the pitch, band-limited 380 Hz-3 kHz, two dropouts (38-47 % of
the line at 8 %, 61-64.5 % at 25 %), cut dead with a small clunk where its row's `cut` says the written line stops:
tape_1 at 8.93 s (after "cla-"), tape_4 at 4.10 s (the take says all of "stock": just into its vowel, after the
"st"), tape_5 at 3.40 s ("gr-"), from whisper's word times and a 10 ms envelope, each then cut as the game cuts it and
whispered back (pa_v2/game/cutcheck.py): "clai-", "insta-", "show gr-"; 20 ms later whisper hears "stock" and "show". The mixer's tape drive and hiss are left out
(the hiss sat 58 dB down).

## the-lab

Jon, Nov 26, after "the lab hum is annoying" (the old beds were near-pure tones: settlement 239 Hz, 99.6 % of its energy
in one band): C "Far plant", a low rough rumble of pumps far below the floor (`tk-scratch/station-sound/lab_beds`,
`make_beds.py`: a generated take low-passed to 90-130 Hz by tier, notched on the generator's 100 Hz comb, each tier
13 LU under the old bed). The beds are `tkg/assets/audio/station/lab_<tier>.wav`, their levels in the files;
`LabScene.bed_path` plays them at `BED_DB` (0). Everything else in the Lab is as it was: its power-on, flickers,
one-shots and glass (`LabScene`). The old tones and `amb_station` under the Lab are gone.

Behind the shut door, the Lab's room plays the old "Door shut" recipe: the concourse crowd (the Promenade's high bed A,
the low tiers' C) low-passed at 330 Hz, 12 dB under, and the PA (since Nov 26 a speaker in the room, #the-pa) against the old settlement hum's level (`ref_db`, -13.03: the new beds kept that ref in the page mix, so
everything but the bed sits where it sat). The page mix put a fixed bus over all of it (+5.35 dB, `lab_beds/old_bus.json`);
in the game the Lab's own sounds play at their own levels on Ambient as they always did, so the Lab's room bus has no
gain, and a Lab capture reads about 5.35 dB (and the faders' 4) under its page mix.

## the-buses

`Station`, into Ambient: the mixer's bus EQ (HP 30 Hz, shelves and bells) as Godot EQ21 band gains, its 2:1 compression
as Godot's compressor reads it (ratio 1.3165, the hangars'), a hard limiter at -3.5 dB, then the level the mixer's bus
gave that room and a trim. `StationHall`, wet only, into `Station`: one reverb, set per room as it shows (see the-halls).
Every voice has a dry bus and a wet one (pan, the depth low-pass); every PA speaker its own pair.

## depth-low-pass

The mixer darkens with a 2nd-order Butterworth run forward and back (24 dB an octave). Godot's `FILTER_24DB` is four
2-pole stages, far steeper (the hangars' captures were 10 to 13 dB down at 4-8 kHz: "muddy, not as crisp"), so each
voice bus has two `FILTER_6DB` stages at Q 0.707, the mixer's response, from 7 kHz toward 1.8 kHz with darkness. The
mixer normalised every stem after darkening it; each voice adds back what its low-pass takes off its file.

## the-halls

Each room's own hall (the mixer's rt, size, warmth) as Godot's reverb, fitted offline (`station_sound.py halls`) on an
emulation of Godot's `Reverb` (8 damped combs, 4 allpasses, wet x 0.6; its predelay does nothing at feedback 0): the
room size and damping whose comb decays best match the mixer's hall band by band (its bands decay at 1.25, 1, 0.62 -
0.2 warmth and 0.38 - 0.2 warmth times rt), then the hall bus level that matches its energy. Godot's shortest comb
decay is about 0.6 s, so the Exchange's 0.4 s room rings a little long. The emulation was checked on the hangar's
hall, measured in Godot.

## the-test

`-- sheet=StationSoundTest` (headless, `--fixed-fps 60`): the plan on disk resolves for every deck at every tier (files,
measurements, speaker, no joke class), the PA table has lines on disk at every tier; then at a settlement and an
unclaimed station on the real screen, the plan is read at docking before any deck opens; each deck for 24 s plays its
bed and its events (steps, the welder and forklift, the tube and the station behind, the ship passes each its lead
ahead of its crossing within a frame), and nothing but a room's steady loops starts while the car rides; a PA line due
mid-ride waits for the car and is read through the deck's speaker after its chime, and the unclaimed tape cuts with its
clunk where its line stops; each yard joke fired makes no sound; undocked, every voice is out. The PA's own: the table
is Jon's 69 lines with their roles, follow-ups' leads, cuts, chime and bang; on the table alone (seeded), the bag deals
a whole pass before any line twice across a docking with no `when` twice running, the dock lines rotate, lift_2 waits
for lift_1, the yard's lines stay on the yard, unclaimed hears only the tape and capital no Daniel or Bill, and a ship
call gets free_2 about one time in three; on the screen, the first line after docking is a dock line with its chime
(unclaimed: the tape, no chime), and reactor_1 comes after its bang and its chime.
