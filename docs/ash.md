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
- **Off the goal and its step** (Jon, Oct 20: "The GOAL and the tutorial tip are right under
  her box"). The goal's line stands just below the map's and the chart's top plate, at their
  picture's top left (24, 89 on the 960x540 grid). On LOCAL it is snug under the HUD at the
  same left, 24, 46 (Jon, "snug:B": no empty gap where the plate would be). The step's line is
  under it. She keeps off the two lines as drawn and off the room they keep whether a step is
  pending or not (`GoalLine.stack_rect`), so a step coming up never lands on her. A top spot
  that would touch it stands 6 px under the step's room instead: top left is 14, 79 on LOCAL
  and 26, 122 on the chart and the map. In a fight there is no step (its tabs are locked there,
  so `GoalLine.step` gives none), so the room is the goal's line alone, and her top left is her
  old corner, 14, 65, under it. Her teaching spots follow the same rule. The map's "IN ORBIT ·
  ..." status line was under the new goal and moved down under the step's room
  (`SystemOverlay.STATUS_AT`).
- **The three move as one with the top plate** (Jon: "Can we make it smooth animation as it
  drops down or up"). On a move between LOCAL and the map or the chart, the goal, the step and
  her box slide down or up with the plate as it slides on or off. They use the plate's own
  point on its curve (`GoalLine.drop`, read off its `PanelSlide`), on the same frame (the goal
  line processes after the ladder), in whole pixels. They hold still while the camera moves and
  do not move between the map and the chart. `CalmLadderTest` holds this to every frame of a hop.
- **Said once, not twice** (Jon, "twice:hide"). While she has a goal step to say, or is saying
  it, the step's line under the goal is not shown; its room stays kept. When she is done it
  comes back as the quiet reminder: a 0.45 s eased fade with a 3 px settle up into its place,
  in whole pixels, on the game's clock (`GoalLine.APPEAR_S`, `APPEAR_DY`). A step that changes
  while she talks keeps it hidden until she has said that one too, so it never flickers.
- **One line at a time, the step before a bark.** A launch line waits for the goal's first step
  to be said, as barks wait for teaching. That used to fail in play: the step counted as due
  only once the goal line had drawn, and the goal fades in after the ship stops, so on that
  frame the launch line started and the step cut it 0.6 s later. The step is due from the frame
  the line is up (`GoalLine.shows_on`), drawn or not. The intro is the one line that goes before
  the step (below).
- **When:** each line at its own moment: a new run's launch; the first time she is up in a new
  hull; the hull at a quarter or under; over the heat cap in a fight; a chit of 60 credits or
  an epic part taken aboard; the third wreck opened since the last dock; and, from jump 6, a
  three-in-ten chance on arrival at least ten jumps after the last doubt.
- **Limits:** one line at a time; 40 s of quiet after a line (6 s before the hull failing or a
  new hull); one line a fight unless the hull starts failing in it; never started during a card
  drag or the enemy's turn (END TURN takes her off that frame); never started over a jump, an
  arrival, the camera moving, the cutaway, a wreck's window, the event band or the escape menu;
  a moment that cannot be said in time is dropped. **Nothing after the ship is lost**: up when
  it goes, she cuts with it. **Hints win**: she waits while a hint is up, settling or due on the
  screen.
- **A quip plays out** (Jon, Oct 22, after the first outside playtest: "He also clicked to make
  her shut up when she was giving her quips"). Once she has started, nothing the player clicks
  cuts her: not a click on her box, not a card picked up or dragged, not a wreck's window, the
  pile, SECTOR LOOT or the event band opened (unless what opens covers her box). A hint that
  comes due while she talks waits for her to finish (`Ash.bark_up`; it used to cut her). What
  still takes her off: the screen going (a jump, the camera moving, another screen, the escape
  menu), END TURN and the enemy's turn (their numbers land where she stands), something coming
  into her box, the ship lost, her switch, a new run. `Ash._must_go`.
- **She introduces herself every new run** (Jon, Oct 18, intro:A; Oct 20: "On the first LOCAL
  section you load into on a new game, A.S.H. should introduce herself. Short beat. THEN the
  first tutorial hint", every run, not once a profile). A new run's launch line is launch_04,
  "Autonomous Systems Handler, reporting. Please don't make me handle much."
  (`AshLines.INTRO`), in its own take, not a pick from the bag. A run picked up with CONTINUE
  does not hear it again (`SaveGame.restoring`): its launch, if it is still before the first
  jump, is the bag's. The once-a-profile flag it had (`[hints] ash_intro`) is read by nothing
  now; an old settings file with it loads as before. Same moment and slot as any launch line.
  The one difference is the order: an ordinary launch line waits for the goal's first step
  (barks wait for teaching). The intro goes first instead: while it is up, or next and able to
  start, no hint or step starts and none can cut it (`Ash.intro_holds`, read by `Hints`), and
  the moment anything else would keep it waiting (the screen, a card already up, no room) the
  hints go on as before. After her LAST WORD, **a beat**: nothing of hers and no lesson for
  `Ash.INTRO_BEAT_S` (1.5 s, the step's own 0.6 s settle inside it), then the first lesson.
  Her box goes with her voice (`AshPortrait.quick`: 1 s past her last word, no reading
  allowance). It used to hold her reading allowance first (2.6 s + 0.035 s a letter) and
  count the beat after, about 7 s from her last word to the step (Jon, Oct 20: "The delay
  between the intro and the first hint is WAY too long"). In a party it plays like her
  other lines: each player's own, on their own machine.
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
- **Cut short:** wherever her words go before their time (END TURN, something coming into
  her box, the screen going, the ship lost, Settings' switch, a new run) her voice stops too,
  faded over 60 ms (`Audio.ash_voice_stop`). A card picked up and a hint coming due no longer
  cut her (Oct 22).
- **Off** with Settings' switch, and under harnesses that do not ask, like the words.
  Headless and in harnesses nothing plays, but `Audio.tape` records each take
  (`ash/<id>`) and each cut (`ash/stop`); `-- sheet=AshTest` reads it.
- **Co-op:** her voice is on your machine only, like the rest of her.
- **The hull failing** (Jon, Oct 20: "Maybe even A.S.H.'s voice could glitch a bit?"): while
  the hull is at or under 30% (`LowHull`, the same state that reddens the screen's edges and
  glitches its text), each line she starts gets a few short glitches in her take: a dropout,
  a stutter (the 25 to 50 ms before, again), a bit-crush, a ring-mod blip or a small pitch
  wobble, 20 to 60 ms each (the wobble 100 to 150), never on her first or last tenth of a
  second, at least 0.2 s apart, one or two a line on the subtle preset (up to three at 15%). Live, from the same
  take: decoded by Godot's own decoder, edited in place (`VoiceGlitch`, every window faded in
  and out over 4 ms so no glitch puts a click back), and played from memory, the same length
  to the sample, so the words still end with her. The decode and the edits run on a worker
  during her power-on (`Audio.ash_voice_prepare`; 40 ms at worst against the 0.35 s before she
  speaks), and her line's start costs the main thread half a millisecond (it was 19 to 29 ms
  done there, a dropped frame); a take not ready in time is said clean, with no glitches. No new takes. Her portrait slips one tick
  on each (her own slip, reused). Reduced motion keeps the voice glitches at the subtle
  preset and drops the slips. `-- sheet=LowHullTest` holds all of it.
- The words and the voice part a little in the hit-stop's slow motion: the words run
  on the game's clock and a playing sound does not slow. A hit-stop is a fraction of
  a second and she is rarely up for one.

Later, maybe: lines that shift with the hull's manufacturer.

## She teaches (Oct 17, tutorial A)

Jon picked how A for the tutorial: **A.S.H. replaces the hint cards.** While she is on,
each first-run hint is said in her corner in Jon's words (`tkg/scripts/data/AshTutorLines.gd`),
and the thing it is about gets a 1 px ice outline, as the goal line outlines a tab. No card.

- **Same hints, new delivery.** `Hints` still decides everything: the same triggers, the
  same order, the same subjects, settle time, what spends one, hiding unspent
  when the subject goes, REPLAY TUTORIAL. Only `_show` changed: it asks `Ash.teach`, and
  only if she has nowhere clear to stand on that screen does the card come instead (so a
  lesson never waits for room).
- **The goal steps** are said once each as they start (`said_<step>` in the hints file,
  cleared by REPLAY TUTORIAL), after any hint due on that screen. The goal line itself
  is unchanged and keeps showing.
- **Live values** fill the fields: the hand size, the heat cap, the dock's jumps and name,
  the cutaway's keys. One jump reads "1 jump". The dock's name is typed after her last
  word, never spoken.
- **The cutaway's line** is Jon's words of Oct 20, "Drag a module onto an empty slot to
  install it. Drag it off the ship into the hold to remove it." (`AshTutorLines.CUTAWAY_LINE`;
  grade 3.7). Its take is the first of three recorded for these words in her warm voice
  (Jon, Oct 20, "take:1"; 6.7 s). `AshTutorLines.SILENT` is empty again, kept for the next
  line whose words change after its take. The card, with her off, says the same (Jon, merge:A),
  with the turn key under it (the flip key's half went Oct 22: a flip is drawing only). **Said once** (Jon: "A.S.H. keeps saying the tutorial line every time I enter. It
  should only be the first time"): a hint is spent by a click, and the cutaway is shut with
  DONE, Escape or a key as often as with a click, so it went unspent and came back at every
  opening. It was spent as it showed; since Oct 22 it stays until a module is moved, and
  leaving the cutaway once she has said it whole spends it too (`Hints.SPENT_ONCE_HEARD`), so
  it is still said once. Shut while she is still saying it, it comes again. REPLAY TUTORIAL
  brings it back.
- **The decks' lines** (Jon, Oct 20, playing the alpha: "There is no tutorial tip for the
  promenade, exchange, shipyard, laboratory, or hiring board"): one first-visit hint a deck
  (`Hints.DECK_HINTS`), after the station's own `dock`. Each shows the first time its deck is
  open and still, on the deck's main thing (`StationScreen.deck_subject`): the yard's drones
  once all that came have flown in (a box that takes in their bob, `YardDrones.services_rect`),
  the shelf, the sell counter, the notes on the board once its lamp is lit, the fabricator's
  screen once its scan has passed. Each stays until its deck is used; leaving the deck once she
  has said it whole spends it too, like the cutaway's (people leave a deck by clicking another). The yard's ship hint follows the yard's. On the
  Hiring Board she stands over the town's side (`PostingBoard.town_rect`), never the app bar's
  tabs, the ticker, a popup or any part of a job note, real or drawn (the other listings, the
  FEATURED listing or WANTED poster: `PostingBoard.job_rects`; Oct 20, "a job note is a pressable
  thing even where it has no words"), and no popup comes up while she teaches. Ads and
  scenery she may cover. The words are Jon's picks of two drafts each (Oct 20,
  "promenade:B shipyard:B exchange:B hiring_board:A laboratory:A"); the cards stay as
  drafted. Text alone until a take is recorded.
- **Never dismissed by a click** (Jon, Oct 22, after the first outside playtest: "Kevin also
  clicked away the tutorial and subsequently had no idea what he was doing. Can we soft lock
  the screen so A.S.H. can't be dismissed?"). It replaces his earlier rule, "let's have them
  advance with a click". A hint's line stays until the player has done what it teaches
  (`Hints.DONE`, below); a line that only tells you something (`Hints.INFO`) stays its reading
  time after her voice ends (her floor of 2.6 s plus 0.035 s a letter, and at least 1 s past her
  last word) and goes by itself, spent; a goal step's line types, holds its reading time on
  `GameClock` and goes. A click lands on whatever is under her and does that thing's job. The
  cards, with her off, follow the same rules (an information card goes after the same reading
  time from when it shows).
- **What spends each hint** (`Hints._done`, read off the screens and the run like the subjects):

  | Hint | Spent when |
  | --- | --- |
  | chart | a star picked on the chart, or a jump made |
  | events | an event opened from the map's list (its page), or GO |
  | drawer | a choice taken in the event band, or NOT NOW |
  | hand | a card played |
  | intent | a card played, or END TURN pressed (Oct 22: it was information) |
  | endturn | END TURN pressed |
  | brace | END TURN pressed (Oct 22: it was information) |
  | heat | END TURN pressed (Oct 22: it was information) |
  | salvage | a part or a chit taken aboard from a wreck's window, or DONE |
  | cutaway | a module moved (installed, removed or moved on the ship); or said whole and the cutaway left |
  | wreck | a wreck opened |
  | loot | SECTOR LOOT pressed (the pile's window open) |
  | dock | a deck picked on the left |
  | shipyard | the yard used: a drone's job paid, or a hull taken; or said whole and the deck left |
  | promenade | a part bought; or said whole and the deck left |
  | exchange | a part sold; or said whole and the deck left |
  | hiring_board | a job signed; or said whole and the deck left |
  | laboratory | something made at the fabricator; or said whole and the deck left |
  | fuel | information: spent as it shows, gone after its reading time |
  | ship | your ship opened up |
  | the deep tutorial's | as in its table below |
  | the goal steps | their reading time (the goal line keeps the step as the reminder) |

- **Never stuck.** A line whose action cannot be done has no subject, so it does not stand: the
  hand's line wants a card you can play (with none, END TURN's comes instead), the events' an
  open event in the list, the salvage's a part in the window. Its subject leaving (the screen
  changed, the window shut) takes her off, unspent, and the line comes again the next time it
  is possible. A line said whole and up `Hints.YIELD_S` (20 s, the hints' clock) while another
  is waiting here (an unseen hint with its subject up, or a goal step to say) gives way, unspent,
  and rests `Hints.REST_S` (45 s) so the waiting one goes first; then it comes back. So no line
  holds the goal or another hint for good; with nothing waiting, it simply stays.
- **Said aloud once** (Oct 23; Jeremy, a playtester: "it doesn't need to repeat everything when I
  jump out of a menu after it has already said it"). The come-back rules above said the whole line
  again in her voice every time. Jon's 0.4.1-alpha.1 log had the hull's line five times (LOCAL left
  for the map before her last word, each visit), heat's four times in one fight (Bleed Heat vented
  the heat to nothing, the line hid unspent and came back at each turn's start), the ship for
  sale's twice on one visit (a drone flew into her box 0.1 s in) and SAVE & EXIT's twice (its
  question took the plate's place, so the line hid unspent). Now a line she has said to its end is
  heard (`heard_<line>` in the hints file, cleared by REPLAY TUTORIAL). If its action is still not
  done it comes back quietly: her box with the words already out, no chirp, no voice, no power-on
  slip (`AshPortrait.quiet`), held as before. A line cut off after her words started may be said
  aloud once more, on a later visit or fight (`Hints._visit`), never on the one it was cut on;
  after that it is words only. An information line (`Hints.INFO`) is spent as it shows. Heat's
  line stays up through the heat vented to nothing, and SAVE & EXIT pressed spends the menu's. The
  log prints `[ash] tut <id> (back, text only)` for a quiet line and `[hints] <id>: she went (why),
  unspent` when one goes unspent.
- **COMMS** (Oct 23; Jeremy: "Give me an option to revisit all communications"). A tab on the HUD
  after QUESTS (`CommsPanel`, `Ash.comms`): every line she said aloud this run, quips, lessons and
  steps, newest first, each with its jump; PLAY says a voiced one again (not while she is
  speaking). A line enters the log when her words start, so one cut before a word is not in it, and
  a quiet return is not said again. No count on the tab. The bar had the room: on LOCAL its row
  wants 702 of 932 px with COMMS, 832 in developer mode, so it is a tab and not a page of the
  escape menu. Same place and rules as the QUESTS table, one of the two open at a time. Kept in the
  run's save as `ash_comms`, optional, so a version 35 save without it loads with an empty log.
- **The soft lock (option b), off.** Jon asked to "soft lock the screen". Built as (a): she
  cannot be dismissed, and the game is still the player's to click, since they have to click to
  do the step, and a screen that refuses clicks reads as a bug. Option (b) is built behind
  `Hints.SOFT_LOCK` (false): while she is SPEAKING a hint's line (coming up and typing, not
  after), a gate over the picture takes every click but those on the thing she points at
  (`Hints.ClickGate`, under the escape menu); once her words are out it is gone. Set the
  constant to try it. `-- sheet=AshTutorTest` holds both.
- **Exceptions to her bark rules, for teaching only:** she may stand over the cutaway, a
  wreck's window and the event band; no quiet before one; any number a fight. A teaching
  line outranks a bark: no bark starts while one is up, settling or due, but her
  introduction, which goes first ("Her first line introduces her", above). A bark already
  under way plays out first (Oct 22; it used to be cut).
- **New screens:** the STARCHART and the SECTOR map (inside the picture's frame) and the
  station (the deck's picture). Her spot is the first of her corners, then the middles,
  clear of everything (`Ash.tut_avoid_rects`) and of anything a click picks in the
  picture (`Ash.covers`: the chart's systems, the map's worlds, beacons, star, belts and
  orbit lines).
- **Voice:** one take per line id, `tkg/assets/audio/voice/ash/tut_<id>.ogg`. A missing take
  is silence and the words alone. **She never says a number or a name** (Jon, Oct 18,
  numbers:A): the text shows them, and the four lines with a field (END TURN, heat, the
  dock in reach, the cutaway's keys) are recorded from scripts of their own,
  `AshTutorLines.SPOKEN`. The typing spans the shown words over her take, so they end when
  she stops. 21 lines recorded Oct 18, two takes each; Jon's pick of each is installed as
  `assets/audio/voice/ash/tut_<id>.ogg`.
- **TUTORIAL ON / OFF** (Jon, Oct 20: "Have a setting in the options for tutorial on or
  tutorial off"): Settings' HINTS, first row, ON by default, `[hints] tutorial` in the settings
  file (`Hints.set_tutorial`). Off: no hint card, no goal step and none of her teaching; the
  goal line's GOAL stays, and her introduction and her other lines play. Turned off mid-line,
  what is up goes at once, unspent; on again, the lessons pick up where the player is (what
  was seen stays seen). REPLAY TUTORIAL works either way.
- **Off:** her switch off brings today's cards back exactly; off in a party (hints are).
  `-- sheet=AshTutorTest` holds all of it, in the merge gate.

## The deep tutorial (Oct 22)

Jon, after the first outside playtest: "Tutorial: scope:all voice:record bugs:fix". Kevin
clicked the tutorial away (it can no longer be, above) and did not know the energy meter or
when to loot a dead ship. The tutorial audit wrote 35 rows; all of them are built
(`Hints.ORDER`, words in `AshTutorLines`, cards in `Hints.lines`, actions in `Hints.DONE`,
done for the harnesses by `sim/HintActs.gd`). Every line was checked against the code before it
shipped; where a draft said something the code does not do, the words follow the code.

| # | Lesson | First time | A.S.H. says | Outline | Ends when |
| --- | --- | --- | --- | --- | --- |
| 1 | hand | a fight, turn 1, the hand settled | Drag a card onto an enemy to fire it. Cards that help us go on our own ship. | the hand | a card played |
| 2 | energy | right after the first card, a card still playable | That card cost energy. This box is what's left. It fills back up every turn. | the ENERGY box | the next card, or END TURN |
| 3 | endturn | nothing left to play | (as before) | END TURN | END TURN |
| 4 | intent | the start of turn 2 | (as before) | the intent | a card, or END TURN |
| 5 | heat_corner | a turn's start with a card that adds heat | Top right is heat. Playing the card adds that much. A green minus cools us down. | that card's corner | a card, or END TURN |
| 6 | heat | heat above 0 at a turn's start | This is heat. Past {cap}, every point over costs us hull at the end of the turn. (said: "Past the limit") | the HUD's heat | END TURN |
| 7 | brace | brace held over an end of turn | Brace stops damage until it's used up. It stays up, but holding it warms us every turn. | the brace chip | END TURN |
| 8 | keywords | a turn's start with an underlined word in the hand | Underlined words have rules. Rest the pointer on a card to read them. | the card | a card's readout open |
| 9 | discard_pick | a card asks for a discard | That card wants a discard. Click a card in your hand to put it in the discard pile. | the hand | a card picked |
| 10 | malfunction | a turn's start with a malfunction in the hand | That's a malfunction. It clogs the deck. Play it to clear it for this fight. A shipyard clears it for good. | the card | it played, or END TURN |
| 11 | flee_hail | a turn's start with the hull at half or less | FLEE and HAIL end a fight early. Each one is a check, and a miss costs us. | both buttons | a card, END TURN, FLEE or HAIL |
| 12 | wreck | LOCAL still, a wreck with something in it | We broke it, so now it's a wreck. Click it to see what we can take. It stays here if we go. | the wreck | it opened |
| 13 | salvage | a wreck's window open (not an event's REWARD) | Drag parts into the hold, or double-click them. What we leave stays in the wreck. Press DONE when we're through. | its grid | a thing taken, or DONE |
| 14 | loot | SECTOR LOOT up | SECTOR LOOT is everything loose here, like what we left in wrecks. It waits for us. Click it to look. | SECTOR LOOT | its window open |
| 15 | drawer | the first event's choices | Pick a choice. Some show the odds. The rest are a surprise. NOT NOW saves it for later. | the choices | a choice, or NOT NOW |
| 16 | odds | a choice with a check | This one tests the ship. It shows the stat, what we have, and the odds. Meet it and it can't fail. | that choice | a choice, or NOT NOW |
| 17 | result | a result with REWARD to open | Here's what it cost and what we got. REWARD opens anything we found. Then press CONTINUE. | REWARD, CONTINUE, the table | REWARD or CONTINUE |
| 18 | fuel_first | the first arrival after a jump (the map), before the event step | Each jump burns fuel. Run dry between stars and the run ends. Stations sell more. | the HUD's fuel | information: its reading time |
| 19 | hull | LOCAL still, the hull short of full | That's our hull. At zero, the ship is lost. A shipyard can patch it. | the HUD's hull | said whole and the screen left |
| 20 | layers | a chart other than the first | This strip is how deep we are. Each ring in means more danger and better pay. The core is at the end. | the LAYER strip | a star picked |
| 21 | cutaway | (as before) | (as before; the keys line is the turn key alone) | the ship | a module moved, or said whole and left |
| 22 | mounts | a part in hand in the cutaway | Each slot takes one kind of part. The slots that light up will take this one. | the mounts that take it | the part put down, or said whole and left |
| 23 | cards_from_parts | a part fitted, after the mounts' line | Every part brings its own cards. Fit it, and they join the deck. Point at a part to see them. | the mounts and cards line | a part pointed at, or said whole and left |
| 24 | attributes | a cutaway after the odds lesson | These are the ship's stats. Event checks test most of them. Fitting parts moves them up or down. | the stats | a module moved, or said whole and left |
| 25 | contract_track | a chart with a signed job's ring in sight | That ring on the chart is the job. Do it there, then press DELIVER at any of their docks. | the ring | a star picked, or said whole and left |
| 26 | the five decks | (as before) | (as before; recorded Oct 21) | (as before) | (as before) |
| 27 | piles | a later fight, turn 2 or after | Played cards go to the discard. When the draw pile runs out, they shuffle back in at the next turn. | the DISCARD pile | a card, or END TURN |
| 28 | map_fly | the map, the ship on no world's orbit | Click a world twice and we fly there. Or fly us by hand. / {thrust} pushes. {left} and {right} turn. | the ship | a key held, or a world flown to |
| 29 | faults | the yard, a malfunction aboard | FAULTS clears a malfunction out of the deck, for a price. | the FAULTS drone | it clicked, or said whole and left |
| 30 | undock | the station, after the first deck's line (not before this deck's own) | UNDOCK takes us back out when we're done here. | UNDOCK | UNDOCK, or another deck |
| 31 | quest | a chart with an event's mark in sight | Something is marked on the chart now. Fly there to follow it up. | the mark | a star picked |
| 32 | jump_blocked | a star picked that JUMP cannot go to | We can't jump there yet. The button says why. | JUMP | another star picked |
| 33 | hull_sale | the yard with a ship for sale, its deal on the TV | That ship is for sale. TAKE IT trades ours in. It comes empty, so we move everything over. | the TV | the ship taken, or said whole and left |
| 34 | save | the escape menu | SAVE AND EXIT keeps the run. CONTINUE on the title picks it back up. | SAVE & EXIT | the menu shut, or SAVE & EXIT pressed |
| 35 | chassis_card | the chassis select (a card only) | (card) Pick a ship, then press LAUNCH. / Point at a line or a card to read more. | LAUNCH | LAUNCH |

**Changed to match the code** (each draft line was checked):

- heat_corner: "Most guns warm us up" was not true (the two Snap Shots every deck starts with,
  the Slug and the salvo guns add none), so: "Playing the card adds that much."
- keywords: the readout opens after the pointer rests a second on the card, whatever it does
  inside it: "Rest the pointer on a card", not "hold still".
- discard_pick: the card goes to the discard pile, and back on a reshuffle, so not "throw it
  away". Taught for discards only (a decommission is another verb).
- wreck: a wreck pays credits only sometimes, and can be empty: "see what we can take", not
  "its parts and credits".
- drawer: some choices show a price or a contact reading rather than odds: "Some show the odds.
  The rest are a surprise."
- piles: the discard shuffles back in when the next turn's hand is drawn, never mid-turn: "at
  the next turn".
- mounts: an empty mount that takes the part pulses a ring, a filled one gets a frame: "The
  slots that light up", not "the rings".
- attributes: the reactor is on the block and no event checks it: "test most of them".
- contract_track: no player text spells colour either way here, and pay is not automatic (the
  DELIVER button on any of their boards): "That ring on the chart is the job. Do it there, then
  press DELIVER at any of their docks."
- hull_sale: the hold comes off too (all to the pad): "we move everything over".
- quest: the event's mark is not in the QUESTS table (it lists signed jobs), so the line does not
  send the player there.
- heat's spoken script says "Past the limit" (the gauge has no line on it).
- chassis_card: not everything has a readout (rows and cards do): "Point at a line or a card".
- fuel_first: a jump lands on the map, not LOCAL, so it teaches there, as information.

**Pacing** (the audit's, binding; `Hints._pace_ok`). One lesson at a time; each starts once its
screen has held still and ends when the player does what it teaches; none can be clicked away;
a subject gone ends it unspent and it comes back. In a fight: only while the hand is settled and
no card is held, never during END TURN's playback or the enemy's turn; only the hand's, energy,
END TURN's and a discard's start after a card this turn (`MID_TURN`); turn 1 of the first fight
teaches the hand, energy and END TURN alone (`TURN_ONE`); flee_hail, malfunction and piles are
one a fight (`ONE_A_FIGHT`), piles never in the first fight. Outside fights the gap after a
lesson is 3 s (`GAP_S`; 1.2 in a fight, `GAP_FIGHT_S`), and a screen as it stands (`_front`: the
screen, its station deck, an open cutaway, window, event or the menu) teaches one new lesson a
visit, but for the chains (`CHAINS`: wreck, salvage, loot; shipyard, ship, cutaway, mounts,
cards_from_parts; drawer, odds, result; fuel_first, events; chart or layers, jump_blocked). The
goal steps still yield to lessons. A line that gives way to a waiting one (`YIELD_S`) lets that
one start on the same visit.

**Over the escape menu** (`save`): the one lesson said there. Her box and the outline go on the
menu's own layer, above it (`Ash.teach`'s `host`), right of its drawer (`Ash.menu_spot`); she
stays while the menu is up and goes with it. **The chassis select** is a card only
(`Hints.CARD_ONLY`): she has not introduced herself yet.

**Her voice for them:** recorded after Jon OKs the spend, from the scratchpad's
`tutorial-deep-voice.json` (each line's shown words, its spoken script and its take's path; 23
new lines and 7 rewritten). A new line plays `tut_<id>.ogg` once installed; a rewritten one plays
the take named in `AshTutorLines.RETAKE` (`tut_<id>_2.ogg`), never its old take under the new
words; each is text alone until then.

**Harnesses:** `-- sheet=AshTutorTest` walks every lesson through a first run on the real
screens (each taught exactly once, clicked on and never dismissed, never stuck);
`-- hinttest` holds the first set's triggers and parks the deep ones (`Hints.DEEP`).
