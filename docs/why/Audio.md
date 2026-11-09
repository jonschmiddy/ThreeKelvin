The reasoning behind `tkg/scripts/autoload/Audio.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Music design

Above `const SFX_PATH := "res://assets/audio/sfx/%s.wav"`:

```text
Music and sound.

Music is vertical, not horizontal. A cue is not one file: it is six stems
that all start on the same sample, and `intensity` decides how many of them
you can hear. Nothing restarts when a fight begins -- the arrangement opens
up. That is why the transition costs nothing and cannot land you in the
wrong place.

THE SECOND EDITION, 2026-09-12. The first soundtrack was thirteen cues built
from one whistled five-note phrase, tempo-locked at 142 BPM, each cue doing
one thing to the motif. Jon played the finished game and called it hollow,
sickly, a slow funeral, not musical at all. The fault was the FORM rather
than the details: a four-bar loop with a tune over it is a song, and this
game wanted a score.

So there is no tempo now, and no bar lines. Every cue is a low F pedal that
never moves, harmony that changes about once a minute above it, texture that
opens over twenty seconds, and one five-note theme that arrives three times a
loop as an event rather than a layer. Cues differ by how dark they are, which
harmonic areas they use, and whether the theme states its aching form or its
answer. Crossfading between two of them still works because they share the
pedal -- the same trick the old set used, for the same reason.

The rulings that shape it, and the mistakes that produced them, are in
`audio/space.py`. The old composition notes in `docs/audio/` describe the
first edition and are kept as its record.
```

## Room tone loops

Above `const ROOM_WAV := "res://assets/audio/ambience/%s.wav"`:

```text
ROOM TONE IS PCM WHERE IT LOOPS, and ogg where it is too long to be.

Vorbis has no neighbour for its first and last windows, so it reconstructs
the very edges of a file wrongly -- inaudible in a cue that ends, and on a
LOOP it is a click, once a lap, forever. Jon heard it through four rounds of
me fixing the source and the encoder putting it back. Measured on one build:
the wav reads x0.4 against the loudest surprise in the lap, the ogg of that
same wav x53, and still x28 at the encoder's best quality with the length
unchanged -- so it is the lapped transform, not padding.

The four short rooms are PCM: about 5 MB, and the fault cannot exist. The
station is six minutes and stays ogg, where its seam is one moment in a
crowd rather than every few seconds under a hum.
```

Above `static func loop_whole(w: AudioStreamWAV) -> void:`:

```text
LOOP A ROOM TONE ON ITS WHOLE LENGTH, seamlessly (this, `LabScene` and
`YardSound`). ONE FRAME SHORT OF THE END, AND PCM (the rooms' imports say
compress/mode=0). Looped at the frame count, Godot's player reads a frame past
the data at every lap, and the QOA the rooms were imported as also restarts
its decoder wrong at the wrap: rendered through `mix_audio`, amb_red's seam
stepped 128 times its typical sample step, amb_pulsar 112, amb_space 30, a
click every lap (every 7.75 s on a red star, one of them half a second before
A.S.H.'s fade in her film). PCM and frames - 1 measure 2 to 4.4 on all ten
looped rooms, which is the files' own seams. `-- sheet=AshTest` holds it.
```

## Ambient fader

Above `var ambient_volume: float = 0.7`:

```text
ROOM TONE HAS ITS OWN FADER. It used to ride the Music bus -- scenery rather
than feedback, so it did not belong with the effects -- but that tied the
reactor, the station and the hypergiants to the score, and a player who
wants the music down usually does not mean the room with it.

It starts at what Music starts at, so every room is exactly as loud today as
it was when its level was set: those numbers were tuned by ear through this
bus at 0.7, and moving the default would quietly retune all five of them.
```

## Room levels

Above `const ROOM_DB := -14.0`:

```text
MEASURED, NOT CHOSEN. The file is levelled to peak −1.0 dB so the ogg keeps
its resolution, and this puts back what that normalise took off.

−14.0 SINCE THE BENCH, and it was −3. Jon mixed the station on a page that
plays at the game's own gain, and the faders came down 6 to 16 dB: a
quieter station, asked for by ear. The build lifts the file back to the
ceiling, so the drop has to be restored here or it is silently undone. The
bench's master is −18.7 dB (the old build gain −15.7, plus −3); the new
build's gain is −4.75, so the player makes up the rest: −18.7 + 4.75.
RE-DERIVE THIS after any change to station.py's MIXDB -- it moves the gain.
```

Above `const ROOM_LEVELS: Dictionary = {&"amb_space": -14.3, &"amb_blue": -14.5,`:

```text
EACH ROOM AT ITS OWN LEVEL, all of them set by ear and none by arithmetic.

OPEN SPACE is the bed: your own reactor and nothing else, under the score.
THE THREE STARS are things outside making a noise, a few dB over it. THE
STATION is neither -- the only room mixed by hand on a bench, and the only
one the score steps aside for (ROOM_DUCKS), which is how it reads loud while
measuring quiet.

IN LUFS, NOT RMS, because RMS was wrong about one of them. Jon: "let's have
blue hypergiant be a tad bit quieter ... the high pitched makes it seem
louder for some reason." An ear is far more sensitive at 3 kHz than at 60 Hz,
and the blue room is all top while the others are all bottom: measured by
ITU-R BS.1770 (`scratchpad/lufs.py`) it was 6.2 dB louder than red and pulsar
at the same RMS, while those two agreed to 0.2 dB. So the whole family is
levelled in LUFS now and the RMS column is only there to be read.

THE NUMBERS ARE NOT COMPARABLE BY EYE and must not be edited as if they
were: each is `target - the file's own measurement`, so a quiet file takes a
bigger number for the same loudness. Rebuild a room and BOTH its numbers move
-- the scripts that build them print the pair.

  room      secs   file rms   file LUFS   level      plays at
  space      5.75     -15.7      -12.0     -14.3    -30.0 rms / -26.3 LUFS
  blue       7.75     -15.6      -10.2     -14.5    -30.1 rms / -24.7 LUFS
  red        7.75     -12.7      -13.4      -9.2    -21.9 rms / -22.6 LUFS
  pulsar     5.00     -13.5      -14.3      -8.5    -22.0 rms / -22.8 LUFS
  station  360.00     -30.3      -26.5     -15.4    -45.7 rms / -41.9 LUFS

THE STATION MEASURES QUIETER THAN IT DID AND IS NOT. Its announcements left
the file -- the game deals them now -- so the loud seconds left the average
with them. The hum, the air, the deck and the crowd are untouched and the
level is untouched, which is what keeps the announcements sitting exactly
where they sat when they were baked in.

THE STATION CAME BACK DOWN 4 dB. It went up to -40 rms on Jon's own number,
and what that actually raised was the REVERB on the announcements: "there is
sooo much echo now with the PA system". The echo is baked into the bed, so
the bed is the only dial there is -- a room whose tail is its loudest
feature gets quiet before it gets dry.

AND THE BLUE ONE HAS ITS TAKES UN-FADED FIRST. Every bought loop tapers,
even one bought as a loop: its three takes run 8 to 10 dB under themselves in
their first and last second, so the sum was quiet at both ends. Rotating the
lap moved that dip instead of fixing it -- into the middle, where the two
quiet ends landed side by side and dug a 3 dB hole once a lap, which Jon went
on hearing and calling the seam. The fade now comes off each take at the
source, and the lap holds within 1.6 dB of itself the whole way round.

THE LENGTHS ARE NOT ROUND ANY MORE, and that is the seam being fixed rather
than a mistake. Every one of these loops is FOLDED: the end crossfaded over
the beginning, so the lap finishes in the sound it starts with. Jon heard
what a plain fold does to tonal material -- "still a dip in volume at the
seam" -- and he was right: equal power only holds the level when the two ends
are uncorrelated, and open space is a hum whose ends correlate at +0.85, so
they partly cancel. `scratchpad/seamless.py` folds, measures the result in
20 ms windows and puts the difference back, which fixes a dip and a bump with
the same arithmetic. The pulsar is folded by exactly ONE BEAT rather than a
quarter second, so its grid still closes: five passes in five seconds.
```

## Station duck

Above `const DUCK_DB := -9.0      ## how far the music drops under an announcement`:

```text
THE SCORE STEPS ASIDE WHILE SOMEBODY IS TALKING. The announcements are baked
into the bed, so raising them only fights the crowd — against the soundtrack
they still lost, which is what "it fades behind the music" means. A PA does
not win that argument by being louder, it wins by being the thing a room
goes quiet for.

The bed loops on a known length and the lines sit at known offsets, so the
playhead says exactly when one is running. No analysis, no envelope
follower, no sidechain — a lookup against a list of six pairs.
```

Above `const ROOM_DUCK := 0.0     ## silent, while docked`:

```text
AND THE SCORE SITS BACK WHENEVER THERE IS A ROOM AT ALL. A docked station is
the one place in this game with other people in it, and it now has a crowd,
six announcements and ships arriving of its own. The soundtrack at full over
that is two pieces of music competing; at half it is a score playing
somewhere in the building, which is what it is.

SEPARATE FROM THE ANNOUNCEMENT DUCK, and they multiply. Being docked is a
PLACE and a line being read is a MOMENT -- folding them into one number would
mean picking between "quieter in stations" and "quieter while somebody
talks", and both are wanted.

"LIKE 50%" WAS ASKED FOR WHEN THE MUSIC WAS 14 dB LOUDER, and half of that
turned out to be too far: docked came back "a bit too quiet". Both cuts were
landing on top of each other -- -6 here on a baseline that had just dropped
-14 -- so this is the one that gave, since MUSIC_DB is right everywhere else
and this is right in exactly one place. -3 dB instead of -6: the score still
steps back for the room, by half as much.

AND THEN ALL THE WAY. Jon mixed the station on the bench with the music at
−40 and no duck, and asked: "What about no music in the stations?" So a
docked station is its own room and nothing else. The cue does NOT stop: it
keeps its place, silent, and comes back up over the same 1.6 s on leaving,
so undocking resumes the run's music mid-phrase rather than restarting it.
The announcement duck above still runs and now has nothing to act on --
left in place, because a room tone somewhere else may want music under it.
```

Inside `_process()`, above `if _room_now == &"amb_station" and not _pa_lines.is_empty():`:

```text
ASKED EVERY FRAME, NOT FIRED ON AN EVENT. Whether a line is playing is a
fact about the playhead, so reading it each frame is both simpler than
scheduling six timers against a loop and immune to a missed edge: tab away
mid-sentence and come back and the duck is simply correct, where a timer
would be stuck down until the next announcement let it up.
THE STATION'S CLOCK. It only runs while its room is the one playing, so
leaving the station stops the talking with it rather than letting a line
arrive over open space.
```

## Room tone history

Above `func _ready() -> void:`:

```text
THERE IS NO ROOM TONE ANY MORE, and this note is the whole record of why.

Three procedural loops used to run under everything — a reactor pedal riding
heat, a hull that ticked and creaked, a distant radio near settled space.
They are gone: Jon is sourcing ambience from ElevenLabs instead, which is a
better tool for the job than a numpy script with opinions. `audio/ambience.py`
and `assets/audio/ambience/` went with them; git has them if they are wanted.

WHEN THEY COME BACK, they do not come back as cues. A cue is a composition
with a bar line, a rung ladder and a crossfade that has to land on a beat.
Room tone is continuous, seamless on its own length, and its level answers to
the ship and the place rather than to a screen — so it wants its own player
on the Music bus (scenery, not feedback: turning effects down should not take
the room with it) and a fade measured in seconds, not in beats.
```

Above `func _ready() -> void:`:

```text
AND THEY HAVE COME BACK, ON EXACTLY THOSE TERMS. `amb_station` is the first:
one ogg, ninety seconds, seamless on its own length, on its own player on
the Music bus with a fade in seconds. It is NOT in the cue system and must
not be — `room()` is four lines because room tone genuinely is four lines
once you stop trying to make it a cue.

IT IS NOT SYNTHESISED EITHER. The three loops that used to live here were a
numpy script with opinions, and the replacement is assembled: bought crowd
and bought berthings under bought announcements, over a hum and a deck that
oscillators are genuinely good at. `audio/station.py` in the scratchpad
builds it and prints its own seam and level checks on every run.
```

## Hit sound timing

Inside `_connect_signals()`, above `Sig.hit_landed.connect(_on_hit_landed)`:

```text
ON THE FRAME THE SHOT ARRIVES, not when the maths ran. `damage_dealt`
fires as the card resolves, which is before the tracer has crossed the
gap -- so every impact played 8 to 17 frames ahead of the hit it belonged
to, and a kill stacked five sounds on the release frame (combat polish
audit F1). The screen says when a shot is seen landing.
```

## Charge sounds

Inside `_connect_signals()`, above `Sig.charge_fired.connect(func(_n: String) -> void: play(&"shot_heavy", 0.05))`:

```text
THE RELEASE of a charged card is a heavy shot, because that is what it is.
It used to play `charge_fire` here and the heavy shot on PLAY -- a gunshot
at the one moment nothing fires. Jon: "there should be a charging sound
and a release sound. separate." The charging half is in _on_card_played.
```

## Signal sounds

Inside `_connect_signals()`, above `Sig.combat_ended.connect(_on_combat_ended)`:

```text
(overheat: played by the fight's screen when the burn is shown, on the
same frame as the hull it costs -- see SectorScreen._show_burn)
NO STING WHEN A FIGHT STARTS. The music already tells you: combat moves the
cue to Hard Burn, which is 160 BPM of sixteenths against everything else in
the soundtrack. A sting on top of that is the score saying the same thing
twice, half a second apart, and the second one is louder.
```

Inside `_connect_signals()`, above `Sig.contracts_changed.connect(func() -> void:`:

```text
NO SOUND ON Sig.jumped. It played `jump`, the convoy's bang, and the
player's own departure had to suppress it under the drive and the flare
-- which play their own. Jon cut `jump` in the sound pass: "Just use the
jump out sound." The convoy plays `hyperjump` itself (EncounterView).
(a kill: played by the fight's screen on each visible break of the hull,
`ShipBreakup.broke`, rather than when the last hit was resolved -- see
`play_kill`)
Paperwork: the ledger stamps with the institutions' bare fifth, same
figure the score's stamp lanes carry.
```

Inside `_connect_signals()`, above `Sig.screen_changed.connect(func() -> void:`:

```text
Every screen change is the same pressure door -- _swap() is the one
chokepoint, so the sound is right by construction, like the resource
poll. limit_ms soaks the double-swap paths (flee already stings, and
some routes swap twice on the way somewhere) -- 60 ms, not the 350 it
was: a double swap lands within a frame or two, and 350 swallowed real
clicks when you tabbed quickly ("sometimes doesn't happen").
```

## Music cues

Above `const RUN_CUES := {`:

```text

ONE FILE PER CUE, NOT A STACK OF STEMS. The edition before this built
intensity by adding rungs to a piece already playing; finished cues
arrived instead, each arranged end to end, so intensity is now a different
PIECE rather than more of the same one. Everything a rung ladder needed --
CUES, STATES, DEEP, TRACKS, the stem mixer -- went with it. git has it.

The cues live in `music/`, where one browser page is the source of every
note. Read `music/CLAUDE.md` before changing any of them, and run
`music/tools/check_cue.mjs` and `check_lab.mjs` after; validate.sh does both.
```

Above `const RUN_CUES := {`:

```text
WHICH CUE, BY TIER AND BY WHETHER YOU ARE FIGHTING. Straight out of
`docs/audio/music/tiers.md`, which is the handoff's own table.

FOUR RUN CUES A TIER NOW, up from two or three. The second handoff added ten
cues and they all land here; the fight cues did not change. With four, "not
the same one twice running" stops being strict alternation and becomes a real
shuffle with the one repeat that matters ruled out.
```

## Music level

Above `const MUSIC_DB := -14.0`:

```text
HOW LOUD A CUE PLAYS, and it is not "as rendered". Every cue is normalised to
about -1 dBFS peak, and this played them at full gain -- Jon: "the music in
general is about 5X louder than I would ever want it." Five times in
amplitude is 20*log10(5), so:
```

Above `var music_asked: StringName = &""`:

```text

The handoff said as much and I did not do it: `docs/audio/music/godot.md`
says "start the Music bus around -6 dB and tune from there", and nothing was
trimmed anywhere. -14 is what the tuning actually came to, which is why it
lives here as a measured number rather than as the doc's starting guess.

HERE AND NOT ON THE BUS, so `music_volume` stays what the player set and this
stays what the mix wants. A slider that has to sit at 0.2 to sound right is a
slider with four fifths of its travel wasted.
```

## Panels and music

Inside `music_state()`, above `match state:`:

```text
A PANEL ASKS FOR NOTHING, and that ruling outlived the system it was written
for. Jon: "I don't really want the music to change when I change panels. At
all." The new set has no cue for a station, a chart or a hold
either, so the rule now covers all of them: whatever the place put on keeps
playing, and only leaving the run changes it.
```

## Room fades

Above `func warm_room(name: StringName) -> void:`:

```text
The room you are standing in. `&""` is outside, and outside is silent.

FADED, NEVER CUT. A room that stops dead is the loudest possible way to say
"that was a file". Both directions run through the same tween, which is
killed first — tabbing between the station and the ship screen fast enough
would otherwise leave two fades fighting over one volume.
A room's tone loaded ahead, off the main thread, so `room` finds it ready (the
yard built ahead for 3B's dock: loading the tone at the swap was 26 ms of the
move's one frame).
```

## Station PA

Above `func _load_pa(name: StringName) -> void:`:

```text
THE STATION DEALS ITS OWN LINES NOW.

Six announcements used to be baked into the six-minute bed at fixed offsets,
which meant every dock heard the same six of the sixteen, in the same order,
at the same moments. Jon: "Can we randomize the PA speech? I don't want it to
be in the same order every time." Nothing at runtime can shuffle a mixdown,
so `station.py --split` renders the bed with the PA silent and writes all
sixteen lines as their own files, each at exactly the amplitude it had in the
bed. The balance is the same arithmetic; only the order is free.

The sidecar changed meaning with it: it used to say WHEN the bed talks, and
now it says WHAT there is to say.
```

## Music fade out

Above `func stop_music(secs: float = SWAP) -> void:`:

```text
THE FADE IS AN ARGUMENT BECAUSE THE QUIT NEEDS A DIFFERENT ONE. Everywhere
else this is one cue leaving as another arrives, and SWAP's two and a half
seconds is right for that. At the shutdown it is not a swap at all -- it is
the power going -- and Jon heard the difference: "after the snap lands the
music should stop. it continues for a bit afterward." It was still playing,
and still bending down in pitch, for 2.5 s after the click.
```

## Power down

Above `func power_down(secs: float, to: float = 0.30) -> void:`:

```text
THE SET TAKES THE SOUND DOWN WITH IT. Jon: "the music should maybe warp down
in pitch as the tv closes? like it's being shut down."

A FADE IS A MIXER; A PITCH DROP IS A MACHINE. Turning the volume down says
somebody moved a fader. Bending the pitch down says the thing PLAYING it is
losing speed, which is the only reading that matches a picture folding into a
line -- and it is what tape and a film projector actually do when the power
goes, which is where the ear learned it.

EVERY VOICE, INCLUDING THE ROOM. If the music slows and the reactor hum does
not, the hum becomes the one thing in the mix that is not dying, and it reads
as a music effect rather than as the set going off.

ONE WAY ONLY. Nothing restores this, because the only caller is the quit and
the process is about to end. A harness that wants the game afterwards should
not be calling it.
```

## Music voices

Above `func _voices() -> void:`:

```text

TWO PLAYERS AND NOTHING ELSE. One carries the cue, the other is free; a cue
change crossfades between them, and so does the loop. A third would only be
wanted if a loop could land inside a cue change, which SWAP and TAIL are
sized to prevent.
```

## Ash voice

Above `const VOICE_DB := -4.0`:

```text
HER VOICE (`AshPortrait` asks; `AshLines.VOICE` names the takes): one line at
a time on a player of its own, so a line never steals an effect's voice from
the pool or has one stolen from it, on the SFX bus -- she is the ship
talking, and the EFFECTS slider is the ship's own sounds. Ogg, not WAV like
the effects: a line is seconds long and never loops, so the codec's edges
(the reason looping room tone is PCM) never meet.

HER LEVEL is set against the in-game mix, measured off the movie writer's
`f.wav` (`-- sheet=AshFilm`): the takes are levelled to -18.3 LUFS, and
VOICE_DB puts her where the measurement says (`docs/ash.md`, "Her voice").
```

Above `var _prep := {}`:

```text
THE GLITCHED TAKE IS MADE OFF THE MAIN THREAD. Decoding and editing a take
cost up to 19 ms, which on the frame she started speaking was a dropped
frame. So `ash_voice_prepare` (called as her power-on starts, 0.35 s before
she speaks) plans the line and hands the decode and the edits to a worker
(`VoiceGlitch.bake`, pure CPU on arrays, `OffThread`'s rule); `ash_voice`
takes the finished bytes and makes the stream on the main thread. Not
finished in time: the clean take, and no glitches planned (so her portrait
does not slip on sounds that are not there). The main thread never waits.
{path, plan, task, out}; `out` gets the worker's bytes.
```

## Play parameters

Above `func play(name: StringName, pitch_var: float = 0.06, limit_ms: int = 0,`:

```text
pitch_var randomises playback rate a little, which is what keeps a click
you hear four hundred times an hour from turning into a machine gun.
limit_ms drops repeats inside a window, for signals that fire in bursts.
`db` is an OFFSET, and it is new. Every cue played at whatever level it was
mastered at, which is right for a game where each sound happens once at a
moment that earned it -- and wrong the moment one of them starts happening
six times a system. `loot_drop` is written as a reward sting; taking a crate
off the floor does not deserve one, but the alternative was authoring a second
quieter file rather than turning the existing one down.
`pitch` is the note the spread is taken round (A.S.H.'s power-on plays the
text blip twice, the second a minor third up: `AshPortrait`).
```

## Suppression

Inside `play()`, above `if int(_last.get(name, 0)) > now:`:

```text
SUPPRESSION IS NOT A RATE LIMIT, and it was only ever read as one. `suppress`
writes a moment in the future into `_last`, and that was checked solely when
the caller passed a limit -- so `Sig.jumped`, which plays `jump` with none,
went straight through, and the convoy crack played on every jump it had been
silenced for. The sound tape in `jumpcine whole` is what caught it.
```

## Hush

Above `func hush(names: Array[StringName], fade_ms: int = 120) -> void:`:

```text
Cut sounds that are still in the air, because what they were describing is
over.

THE OTHER HALF OF `suppress`, which only ever worked on a sound that had not
started. Skipping the jump killed the tween that had the rest of the sequence
in it and left everything ALREADY PLAYING to run on -- a 5.7-second warp over
a sector that had finished arriving.

FADED, NOT STOPPED. A stream cut between samples clicks, and on a hyperdrive
at full level the click is louder than the sound it interrupted. 120 ms is
under a frame and a half of the sequence being skipped and still long enough
to land on zero.

A name matches whether it was the one asked for or the take the round robin
chose, so a caller hushes `thruster_arrive` without knowing which of the eight
it got.
```

## Capped sounds

Above `func play_capped(name: StringName, pitch_var: float, cap: int, db: float = 0.0,`:

```text
AT MOST `cap` OF ONE SOUND IN THE AIR. The event text's blip (`SignalText`)
lands on every third letter, about eleven a second at 40 cps, and each rings
for 0.3 s, so left alone four would stack. The Lead's rule is never more than
two at once. Before a new one starts, the oldest still playing at the cap is
faded out over `steal_ms`. It fades rather than stops, for the reason `hush`
gives. The new one still plays, so the rhythm Jon picked on the audition page
is kept; only the tails get shorter. A voice already fading does not count.
```

## Effect moments

Above `const FX: Dictionary = {`:

```text

OCTOBER'S EFFECTS WERE SILENT (the sound plan of Oct 17, scratchpad
`sfx-plan/plan.json`). Every one of them already said when it acts -- a
`moment(kind, strength, length)` from ShipHitFx, ShieldFx, BraceFx and
ShipBreakup -- and the one listener played two of them. Now each is heard on
the frame its picture acts: first with files the game already had (the free
pass), then with the ElevenLabs takes Jon picked by ear (Oct 17), copied into
`sfx/` under the plan's names (`brace_clang` and `brace_clang_2` are his
A1 and A2, alternated as round robins).

ONE ROW PER MOMENT, AND EVERY ROW IS SWITCHABLE. `pick` is what plays;
`free` the free pass's pick where a bought take replaced it; `before` what
played there before any of this (empty: nothing did); `off` silence. On the
command line `fx=brace_on:free`, `:before`, `:off`, or a file of its own
(`fx=brace_on:brace_on_b@-3[@offset]`); the same under `[fx]` in
settings.cfg. `fx=all:before` puts every row back as it was.

In a row's take:
  file    the sfx played (round robins as `play` finds them)
  db      its level against its peers (the bought takes are levelled to the
          plan's targets already, so 0 unless the row says why not)
  at      the moment kind it lands on, where the caller sees more than one
          (bolt_on starts the plates, clamp locks them 0.35 s later)
  offset  s: later than the moment (> 0, on the game's clock) or that far
          into the file (< 0), to put a file's own hit on the picture's
  end_on  started far enough into the file that it runs out as the moment's
          length does: a whine into the blast it leads to
  limit   s on the game's clock between two of this row: never chatters
  cap     at most this many of the file in the air (`play_capped`)
  pitch   the round robin's pitch spread (0.05 if not given)
  hush    a name to keep quiet instead of a sound (`suppress`)
  duck    how far the music steps back, for the caller's length
  bed     a loop (`ambience/` or `sfx/`) faded in, held until `fx_stop`
```

## Kill boom

Inside `denied()`, above `&"kill_boom": {pick = {pool = [[&"explosion_small_3", -0.9], [&"explosion_small_4", 2.1],`:

```text
A SHIP'S DEATH, HEARD AS ONE (Jon, Oct 19, of a hulk's: "the ship exploding
at the end of that video is weak"). Measured (`scratchpad/death-punch/`):
the kill pool's five takes spread 5 dB -- explosion_small and _2 are 4 dB
under a plain hit landing (momentary max -17.6 / -17.2 against
impact_enemy's -13.8), _3 to _5 the old boss takes (-12.6 to -14.9) -- so
a death came out as loud as a round robin's luck, and a D under the hit
that caused it. Its MAIN BREAK (`broke` at 0.6 or more, on the frame the
picture bursts) is now three layers: the three heavy takes alone, each
levelled to -12.8 (`pool`, a take and its own offset); a sub thump, the
first impact_hull (80% of it under 90 Hz, gone in 0.45 s), down 6; and
hull_crunch's buckling metal, down 4. Together about 1.5 dB over a hit's
impact and level with a hit's whole volley (card, shot and impact), every
look within about a dB of the others, peaks under -0.5 dBFS (_3 a touch
lower for it). The
lesser breaks (a burst before the break, a prelude) are the two short
takes, down 3. `before` is the one pool as it was.
```

## Beds

Above `var _beds: Dictionary = {}		  ## row -> AudioStreamPlayer`:

```text

ONE PLAYER A ROW, so the Hellbender's furnace, the Custodian's arcs and a
shield's hum are each their own and none cuts another off. A row's bed is
up from its `fx` until its `fx_stop` (or `fx_hold` false), faded both ways.
`bed` names a room tone (`ambience/<bed>.wav`) or an effect's loop
(`sfx/<bed>.wav`); either is looped on its whole length, as `room` loops.
```

## Taping

Above `var _dry: Array = []                ## [asked, end game s]`:

```text

A harness without a window has no Audio at all (`_ready`), so a test of
WHEN a sound plays had nothing to read. While `taping`, `play` runs its rate
limits, suppression and pick and tapes the result here instead; the voices it
would hold are kept as lengths, so `play_capped`'s cap can be read too.
```

## Resource polling

Above `func _poll_resources() -> void:`:

```text
Scrap and modules arrive from a dozen places — combat rewards, salvage,
events, station stock, card effects — and not all of them emit the same
signal. Chasing every site would mean a sound call in six files that each
have to remember to keep it; watching the two totals instead means the
sound is right by construction. One of these two signals always fires
after anything has changed.
```

## Kill sounds

Above `func kill_beat(s: float) -> void:`:

```text
A kill flashes warm and dies cold -- but WHAT died decides the sound.
Bosses get the two-stage reactor death with the tritone in the debris;
fauna do not explode at all, because one of the warm things going out is
a loss even when it was trying to eat you. limit_ms: a card that clears
a board is one explosion, not a drum roll.
A ship's breakup breaking, on the frame it does (`ShipBreakup.broke`): its
main break (`s` 0.6 or more) the layered boom, a lesser one a pop. A
creature never breaks (its first beat is `play_kill`'s).
```

## Run end silence

Above `func _on_run_ended(_won: bool, _reason: String) -> void:`:

```text
NOTHING EITHER WAY AT THE END OF A RUN.

WINNING had a sting until Jon cut it: "I just don't want the victory sound at
all." The kill, the wreck opening and the rarity ladder under it are the
reward, and a fanfare over them was the game applauding itself.

DYING had one too, once: a two-second sting, F to Gb on a low bowed note. The
reasoning was sound -- the semitone is the whole idea of the dread cue, so
dying sounded like the thing that had been following you all run. What it
actually did was announce the ending over the top of a cue written to BE the
ending: "No Fault" is a line that falls three times and does not come back up,
and it does not need help. Silence, and then the music that is already the
answer.
```

## Thrust loop

Above `const SHIP_LOOP := &"ship_thrust_loop"`:

```text
THE THRUST LOOP, held while a thrust key is: a second of the arrival clip's
clean burn (constant rate and level), its last 0.15 s folded over its head so
the seam is continuous, and PCM so no codec touches the join. Low-passed at
1.2 kHz around its own period (the burn is all under 1 kHz; a tick 0.65 s in
clicked once a loop, Jon: "clicks in between the loops"). 44101 frames, the
last a copy of the first: the import loops at frames-1 (loop_end -1), so the
loop is exactly 44100 and the copy is only read as the interpolation partner.
```

## Idle engines

Above `const IDLE_LOOP := &"ship_idle"`:

```text
YOUR ENGINES AT IDLE, HEARD (Jon, Oct 13: "Let's have a low burn sound for
the idle engines"). A bed you notice when it stops: it plays exactly while
your ship's idle flame is on screen and fades with it. The view that is your
ship on LOCAL and in fights (`ShipView.hums`) hands itself in, and this asks
it every frame (`ShipView.idle_heard`) -- the same reasoning as the duck in
`_process`: a fact about the picture, read each frame, cannot miss an edge.
So the arrival's clean burn is the clip alone and the bed comes up under the
first gap after it; a hyperdrive's dark, a departure, a screen without your
ship (or a view freed with its screen) all take it down the same way.

THE BED: the map's thrust loop pitched down a fourth and low-passed, a soft
low rumble (`audio/idle_bed.py` makes it from audio already in the game and
says how the loop is made seamless). Jon picked it from three, Oct 13: "bed:A";
the others were a darker re-cut of the heavy arrival's burn and a sparse
burble at the flame's 8 a second. git has them.
```

Above `const IDLE_DB := -21.0`:

```text
Where it sits, measured, not guessed. Mastered to -20 dBFS RMS; at IDLE_DB it
is -44 LUFS as heard: 16 LU under the map's thrust loop as it is heard
(SHIP_DB at 0.7, -28 LUFS), about 11 under a UI click's 400 ms loudness (-33)
and 24 under a hit on your hull (-20). It was -17 (-40 LUFS); Jon picked the
quieter of three levels ("level:C"), 4 dB down.
```

## Flight sound

Above `func ship_flight(dur: float, conic: bool) -> void:`:

```text
A FLIGHT, HEARD: the departure burn as it sets off, and an arrival flameout
(a row picked as `ShipView.arrive` picks one, the hull's weight picking the
clip) started at the point in it where its clean burn ends 0.08 s before the
ship settles, so the stutter plays over the settling. On a transfer orbit the
departure burn is short and the coast between is quiet; on the swoop the two
crossfade.
```

## The labs glass

Above `func lab_hover() -> void: play(&"lab_glass_hover", 0.02, 120)`:

```text
THE LAB'S GLASS (Jon's picks, Nov 7, the round-2 page: hover h2_03, login
l2_05). Both play at 0 dB, as `click` and `hover` do: the files carry their
level, fitted on the page against their peers by one meter (loudest second):
the hover -37 LUFS, between ui_hover (-44.6) and card_hover (-35.4); the
login -28, over the ui_click it plays with (-34.4) and under the lab's own
screen power-on (lab_settlement_screen, -24.6). A boost here would undo the
fit he picked by ear.
`lab_hover`: the pointer arriving on the glass (`StationScreen._process`, on
the edge alone). A small pitch spread, since the take is a tone; the limit is
only for a pointer jittering on the glass's edge.
```
