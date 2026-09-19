# Getting the music into the game

## 1. Import the files

Drop `audio/*.wav` into `res://audio/music/`. For each one, in the Import dock:

- **Loop:** on, mode **Forward**
- **Loop Begin:** 0
- **Loop End:** the loop point in *samples* from the table below

Every WAV has about six seconds of reverb tail printed after the loop point. That tail is there
so the sound doesn't cut off when you fade a cue out. The loop point is the musical end of the
cue, not the end of the file, which is why Loop End has to be set by hand.

| File | Tier | Role | BPM | Bars | Loop length | Loop End (samples at 44.1 kHz) |
|---|---|---|---|---|---|---|
| `title.wav` | menu | run | 72 | 24 | 80.000 s | 3528000 |
| `fl.wav` | EASY | run | 71 | 42 | 141.972 s | 6260965 |
| `coldstart.wav` | EASY | run | 71 | 40 | 135.211 s | 5962805 |
| `longway.wav` | EASY | run | 71 | 32 | 108.169 s | 4770253 |
| `driftplane.wav` | EASY | run | 68 | 34 | 120.000 s | 5292000 |
| `closequarters.wav` | EASY | fight | 100 | 32 | 76.800 s | 3386880 |
| `ghostfreight.wav` | ROUGH | run | 88 | 30 | 81.818 s | 3608174 |
| `salvage.wav` | ROUGH | run | 82 | 36 | 105.366 s | 4646641 |
| `cutsignal.wav` | ROUGH | run | 96 | 30 | 75.000 s | 3307500 |
| `qo.wav` | ROUGH | run | 71 | 40 | 135.211 s | 5962805 |
| `slipstream.wav` | ROUGH | fight | 104 | 40 | 92.308 s | 4070783 |
| `redline.wav` | HARD | run | 116 | 40 | 82.759 s | 3649672 |
| `deadweight.wav` | HARD | run | 60 | 32 | 128.000 s | 5644800 |
| `coldiron.wav` | HARD | run | 92 | 32 | 83.478 s | 3681380 |
| `thinice.wav` | HARD | run | 104 | 32 | 73.846 s | 3256609 |
| `hairline.wav` | HARD | fight | 108 | 38 | 84.444 s | 3723980 |
| `nothingleft.wav` | BRUTAL | run | 52 | 32 | 147.692 s | 6513217 |
| `wrongship.wav` | BRUTAL | run | 71 | 36 | 121.690 s | 5366529 |
| `countdown.wav` | BRUTAL | run | 100 | 28 | 67.200 s | 2963520 |
| `attrition.wav` | BRUTAL | run | 92 | 36 | 93.913 s | 4141563 |
| `overpressure.wav` | BRUTAL | fight | 84 | 32 | 91.429 s | 4032019 |
| `eventhorizon.wav` | LETHAL | run | 46 | 28 | 146.087 s | 6442437 |
| `noair.wav` | LETHAL | run | 96 | 28 | 70.000 s | 3087000 |
| `sealed.wav` | LETHAL | run | 54 | 30 | 133.333 s | 5879985 |
| `aftermath.wav` | LETHAL | run | 56 | 30 | 128.571 s | 5669981 |
| `laststand.wav` | LETHAL | fight | 132 | 66 | 120.000 s | 5292000 |
| `lightsout.wav` | DEATH | death | 48 | 14 | 70.000 s | 3087000 |

If you'd rather not set loop points by hand, re-render with `TAIL = 0` in
`engine/render_wav.mjs` and let the whole file loop. You lose the tail across the seam, which is
audible on the reverb-heavy cues (Long Way Round, Cut Signal) and inaudible on the dry ones.


## WAV or OGG

Both are in `audio/`. The OGG files are about a twelfth the size and sound the same in a game
mix; the WAVs are there if you want to re-encode them yourself or edit them.

In Godot, OGG loop points are set on the import as **Loop Offset** in seconds rather than in
samples, using the same loop lengths from the table above.

## 2. A music player that crossfades

```gdscript
extends Node
## Plays one cue at a time and crossfades when the tier changes.

const CUES := {
    "menu":  ["res://audio/music/title.wav"],
    "EASY":  ["res://audio/music/fl.wav",
              "res://audio/music/coldstart.wav",
              "res://audio/music/longway.wav"],
    "ROUGH": ["res://audio/music/qo.wav",
              "res://audio/music/slipstream.wav",
              "res://audio/music/cutsignal.wav"],
}

const FADE := 2.5          # seconds; long enough that a change never feels like a cut

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _current: AudioStreamPlayer
var _tier := ""
var _last_played := {}     # tier -> index, so the same cue doesn't repeat back to back

func _ready() -> void:
    _a = _make_player()
    _b = _make_player()
    _current = _a

func _make_player() -> AudioStreamPlayer:
    var p := AudioStreamPlayer.new()
    p.bus = "Music"
    p.volume_db = -80.0
    add_child(p)
    return p

func play_tier(tier: String) -> void:
    if tier == _tier:
        return
    _tier = tier
    var files: Array = CUES.get(tier, [])
    if files.is_empty():
        fade_out()
        return
    var i := _pick(tier, files.size())
    var next := _b if _current == _a else _a
    next.stream = load(files[i])
    next.volume_db = -80.0
    next.play()
    var t := create_tween().set_parallel(true)
    t.tween_property(next, "volume_db", 0.0, FADE)
    t.tween_property(_current, "volume_db", -80.0, FADE)
    t.chain().tween_callback(_current.stop)
    _current = next

func fade_out() -> void:
    var t := create_tween()
    t.tween_property(_current, "volume_db", -80.0, FADE)
    t.tween_callback(_current.stop)

func _pick(tier: String, count: int) -> int:
    if count == 1:
        return 0
    var last: int = _last_played.get(tier, -1)
    var i := last
    while i == last:
        i = randi() % count
    _last_played[tier] = i
    return i
```

Call it from wherever difficulty is decided:

```gdscript
MusicPlayer.play_tier("menu")     # title screen
MusicPlayer.play_tier("EASY")     # run starts
MusicPlayer.play_tier("ROUGH")    # difficulty steps up
MusicPlayer.fade_out()            # death, or back to the menu
```

## 3. Things worth knowing

**Set up a Music bus.** Route all of this to a dedicated bus so the player can turn music down
separately from the effects, and so you can duck it under important sounds.

**The cues are not beat-matched to each other.** First Light, Cold Start, Long Way Round and
Quiet Orbit all run at 71 BPM and share a bar length of 3.38 seconds, so those four can be
crossfaded in time with each other if you ever want to switch mid-bar. Slipstream (104) and
Cut Signal (96) deliberately do not, because sitting at a different tempo is part of how they
read as more dangerous. A 2 to 3 second crossfade covers the difference.

**Don't fade in on a peak.** Each cue's loudest section sits about two thirds of the way in. If
you start a cue at a random offset, you may drop the player straight into the climax. Always
start cues from zero.

**Volume.** The WAVs are normalised to about -1 dB peak. Start the Music bus around -6 dB and
tune from there.

**Re-rendering.** If you change anything in the lab, re-run the renderer for that cue and the
WAV in this folder is replaced. The loop lengths in the table above only change if you change a
cue's tempo or bar count, both of which the renderer prints when it runs.
