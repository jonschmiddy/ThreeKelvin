# A.S.H. — Autonomous Systems Handler

The ship's AI, and the one person aboard. Named for Ashlee, by Jon, Oct 17.
Her voice was chosen by Ashlee: **dry, humorous and teasing.** Her face is a
**hologram.**

Status: in the game (Oct 17): her face on LOCAL and in fights, the 30 approved lines
(`docs/ash_lines.json`) at their moments, all 30 in her recorded voice. Moods are still
to come.

## Why she exists

Ashlee's note: "you're a ship right now disembodied from anything, separate from
something with consciousness. People get more engaged with something that feels
alive that they can connect to."

"The ship IS the character" is a ruling, and A.S.H. is how it becomes literal:
she is the ship's mind, not a crew member. **Nobody manages her.** She has no
stats, no levels, no slot, no upgrade tree. She cannot be hired, fired or lost.

## Who she is

- **The constant.** Hulls change; she moves with you. A new frame is a new body
  she complains about. You get attached to her, not to a hull.
- **Dry.** She under-reacts. Disaster is reported like a mild inconvenience in a
  maintenance log.
- **Humorous.** The joke is usually in what she declines to say.
- **Teasing.** She needles the pilot about their choices — the greed, the heat,
  the detour for one more wreck — and is quietly on their side anyway.
- **Bureaucratic by birth.** Her designation is a job title on a work order. She
  knows it, and uses the register of filings, riders and invoices the game
  already speaks.

## What she carries

The design doc's doubt: this might be a rescue, or "a very long, very cold
delusion." A.S.H. never settles it. She can joke past it, and once in a long
while she lets a line land that suggests she has done the arithmetic too.

## How she talks

- **Short.** One line, usually under twelve words. Never a paragraph.
- **At moments that matter**, not as commentary on every action: first launch, a
  big haul, overheating, hull failing, a new hull, one more wreck, and once in a
  long while a line of doubt.
- **Nothing after the ship is lost** (Jon, Oct 17: "No lines after the ship is
  lost. The ship has blown up."). She is the ship; when it goes, she goes. Her
  last words are whatever she said while the hull was failing.
- **Never explains the world.** No lore dumps, no cosmology, no faction history
  ("No prophecy, no chosen crew, no faction explaining the cosmology in a text
  box"). If she knows more than the player, she does not say so.
- **Never cruel.** The teasing has affection under it. She roasts the decision,
  never the person.
- **Never cute.** No emoji energy, no "Yay!", no exclamation marks except in
  irony.
- Plain words. No technobabble she would have to explain.

## Her face

A holographic portrait: a face made of scanlines and projector light, in a small
frame on the main screen. It reacts to the ship, not to the script:

| The ship | Her face |
| --- | --- |
| Cold, calm | steady, half-lidded, mildly unimpressed |
| Heat climbing | flickers warmer; one eyebrow up |
| Over the heat cap | interference, colour bleeding, eyes narrowed |
| Hull low | the image breaks up, lines drop out, she keeps her composure |
| A big haul | the smallest smile she can get away with |
| Ship lost | the projection cuts with the ship, no line |

### Making the portrait (planned, Oct 17)

1. **Her face, calm.** 64x64 pixel art, shown at 2x and 3x. Three looks, one
   PixelLab pro call each (16 takes a call, about 10 generations):
   A, cyan projector light and scanlines; B, a pale white-blue wireframe face;
   C, warm amber light matching the UI. Jon and Ashlee pick one. Cap 50.
2. **Her moods**, edited from the picked face so she stays one person: hot,
   over the heat cap, hurt, pleased (the table above). Spend asked separately.
3. Never a real person's likeness: she is named for Ashlee, not drawn from her.

## Where she shows up (built Oct 17)

`scripts/ui/Ash.gd` decides, `AshPortrait` draws, `AshLines` holds the lines (held to
`docs/ash_lines.json` by `-- sheet=AshTest`, in the merge gate).

- **Her face** is one file, `tkg/art/ash/face.png`: eight 64x64 frames (four mouths, each
  with a blink), cut from the hand-drawn talk frames on B15 by `tkg/art/tools/ash_face.py`.
  When Jon picks a variation, `ash_face.py --face <png>` lays the same mouths and blink onto
  it and says how far the new face's features have moved; look at it at 2x before keeping it.
- **Where:** the top left of the picture, under the goal line's band, the face with her line
  typing beside it in the event text's signal type. It was the one spot clear on every screen
  she uses (65 built by AshTest: LOCAL with and without wrecks or a subject, fights of one to
  three ships in every weight); every other corner and the middles cover a plate, an enemy's
  words or its numbers in some fight. If something ever stands there, she tries the other
  corners and otherwise waits. Not pressable and not clickable: clicks go through her.
- **When:** each line at its own moment: a new run's launch; the first time she is up in a new
  hull; the hull at a quarter or under; over the heat cap in a fight; a chit of 60 credits or
  an epic part taken aboard; the third wreck opened since the last dock; and, from jump 6, a
  three-in-ten chance on arrival at least ten jumps after the last doubt.
- **Limits:** one line at a time; 40 s of quiet after a line (6 s before the hull failing or a
  new hull); one line a fight unless the hull starts failing in it; never during a card drag
  or the enemy's turn (END TURN takes her off that frame); nothing over a jump, an arrival, the
  camera moving, the cutaway, a wreck's window, the event band or the escape menu; a moment
  that cannot be said in time is dropped. **Nothing after the ship is lost**: up when it goes,
  she cuts with it. **Hints win**: she waits while a hint is up, settling or due on the screen.
- **Talking:** the mouth follows the typed letters, a held frame every 0.1 s, with blinks and
  one-pixel hologram slips (more often with the hull failing); about 9 changes a second while
  she talks, all on the game's clock. A two-note `text_blip` chirp as she appears, then
  her voice (below), and the chirp reversed as she goes.
- **Settings:** SHIP'S AI, A.S.H. ON / OFF, under HINTS. Off under harnesses unless `-- ash`.
- **Co-op:** each player's A.S.H. is their own ship's, on their own machine: she reads that
  machine's run, sends nothing, and nothing waits on her.

## Her voice (Oct 17)

Jon picked her voice and a take of each line: her warm voice (ElevenLabs eleven_v3,
voice W1_2, the subtle Cortana chain), levelled to -18.3 LUFS, trimmed to 30 ms before
the first word and 80 ms after the last (measured on the 30 picks: -18.2 to -18.4 LUFS,
speech from 30 to 40 ms in, 80 to 100 ms of silence after it). It replaced a first,
cooler set (C3) the same day. The takes are `tkg/assets/audio/voice/ash/<id>.ogg` (Ogg
Vorbis, imported without a loop), and `AshLines.VOICE` names each line's take; a line's
id is its moment and its place in that moment's list, `greed_05`. A line whose entry is
`""` is said as text alone, as every line was before.

New takes drop in: replace the files and fill the table, and nothing else changes. The
typing follows each file's own length (`AudioStream.get_length()` as it plays), and
`AshTest` counts the voiced lines off the table. Two numbers assume new takes are made
the same way: `VOICE_TAIL_S` (0.1 s, for the silence trimmed after the last word) and
`VOICE_DB` (set against takes levelled to -18.3 LUFS). Trim or level them differently
and re-measure both. The swap from C3 to the warm set moved neither.

**The takes are de-clicked** (Oct 17, Jon: "a bit of a click when she leaves?"). It
was in the takes, not the encode: ElevenLabs ends a take mid-waveform (its last 5 ms
-13 to -55 dB under the peak), and the chain's padding of silence after it turned that
edge into a one-sample step at the end of her last word, 4 to 159 times the steps round
it in 17 of the 30 (haul_02 32, launch_05 18; the film's mix showed it at 12.05 and
76.16 s). They are rebuilt from Jon's raw picks with the same chain, trim and level and
one change: the raw take's last 15 ms faded out (and its first 3 ms in) before the
chain. The same pipeline without that fade reproduces the old files sample for sample;
with it every step there is under 3. `AshTest` renders each take through Godot's own
decoder and holds it under 4. The script is the scratchpad's `ashv/declick.py`, beside
`ash_lines.py`; a new take needs the same fade.

The film also had a click every 7.75 s that was not hers: the red star's room tone
crossing its loop seam (`Audio.loop_whole`), the one half a second before each of her
fades. Fixed with the rooms: PCM, and looped a frame short.

- **When:** 0.35 s after she appears (`AshPortrait.VOICE_AT`), after the chirp. The
  chirp is at the text's own level (`CHIRP_DB` 0; it was -3 until Jon: "the beep when
  ash comes in can be a little louder"). Measured over all 30 takes at their game
  levels against her first quarter second: at -3 dB and 0.3 s the chirp sat 27.5 dB
  under on average and 18 at worst; 3 dB up at 0.3 s that would be 24.5 and 15, so
  her voice moved to 0.35 s, which gives back 26.9 and 17.5 (started with her, the
  louder chirp would sit only 6 dB under at worst, its second blip's click inside the
  first word).
- **Her power-down** (Jon: "Can the sound go in reverse when she goes away?"): the
  power-on's two blips reversed (`text_blip_rev`, the file reversed, so the same
  level), in mirror order and time, the higher first, ending 0.2 s before she goes;
  the lower ending on the frame the projection goes. Only when a line ends of itself:
  the power-down has to start a quarter second before her fade, which only a natural
  end knows, and every other exit (END TURN, a hint, a card picked up, something in
  her box, Settings, the ship lost) is the game taking the floor with sounds of its
  own while she goes in a tenth of a second; a power-down there would land after her
  and over them. A cut while it plays hushes it (the ship lost: she cuts out with
  the ship).
- **The words type with her:** they start on the frame her voice does and type at the
  speed that ends them as she stops (`SignalText.rate_for`, over the take less its
  0.1 s of trailing silence; punctuation keeps its beats). Over all 30 the words end
  0.07 s before the file and within 1.4% of what she says. The mouth follows the
  letters as before, so it follows her: 9.0 to 9.7 changes a second on every line of
  30 letters or more, 9.5 over all thirty.
- **Where:** her own player on the SFX bus (`Audio.ash_voice`): she is the ship
  talking, so the EFFECTS slider is hers too. No bus or slider of her own.
- **Level:** `Audio.VOICE_DB` -4 dB. Measured off the movie writer's audio in
  `-- sheet=AshFilm` (the warm set): the music and room bed sits at -25.6 to -26.1
  LUFS on LOCAL; her lines measure -20.1 to -20.4 LUFS in the mix (she alone is about
  -21), so about 5.5 LU over the bed before the duck and 9.5 over it ducked; the loud
  effects in a fight (hits, the kill) reach -12.7 to -13.1 momentary against her
  loudest -15.8, so she sits under the guns, never over them. (The C3 set measured
  the same within half a LU.)
- **The duck:** the music steps down 4 dB while she speaks (`Audio.VOICE_DUCK_DB`),
  on the station PA's own duck (asked every frame off her player). Measured in the
  film: down in 0.13 s, back up over 0.43 s once she stops.
- **Cut short:** wherever her words go before their time (END TURN, a card picked up,
  a hint settling, something coming into her box, the ship lost, Settings' switch, a
  new run) her voice stops too, faded over 60 ms (`Audio.ash_voice_stop`).
- **Off** with Settings' switch, and under harnesses that do not ask, like the words.
  Headless and in harnesses nothing plays, but `Audio.tape` records each take
  (`ash/<id>`) and each cut (`ash/stop`); `-- sheet=AshTest` reads it.
- **Co-op:** her voice is on your machine only, like the rest of her.
- The words and the voice part a little in the hit-stop's slow motion: the words run
  on the game's clock and a playing sound does not slow. A hit-stop is a fraction of
  a second and she is rarely up for one.

Later, maybe: lines that shift with the hull's manufacturer.
