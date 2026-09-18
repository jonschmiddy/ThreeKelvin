# Effects

All effects are Web Audio nodes built at runtime. Every one of them is baked into the rendered
WAVs, so the game doesn't need to reproduce any of this — but if you ever play the cues live in
a browser build, this is what the signal chain is.

## Per part

Each of the seven parts has its own three settings. In the Copy line they appear in brackets
after the instrument number, and anything left at Normal is not mentioned.

| Setting | Options | What it does |
|---|---|---|
| Reverb | Dry, Normal, Wet, Huge | how much of that part is sent to the shared reverb |
| Delay | Off, Normal, Long | the echo repeat time and feedback for that part |
| Volume | Quiet, Normal, Loud | the part's level in the mix |

There is one shared reverb for the whole mix rather than one per part. That was a deliberate
fix: separate convolvers for seven parts overloaded the audio thread and produced crackling.

## Everything at once

These apply to the whole mix, after the parts are summed.

| Setting | Options | What it does |
|---|---|---|
| Space | Small room, Hall, Deep space | the reverb's size: a 1.1 s, 2.8 s or 6 s tail |
| Reverb amount | Less, Normal, More | the level of the reverb return |
| Tone | Dark, Normal, Bright | a 2.6 kHz low-pass, nothing, or a +5 dB shelf at 5 kHz |
| Warmth | Clean, Warm tape, Crunchy | soft saturation, from none to heavy |
| Tape wobble | Off, Gentle, Seasick | slow pitch drift, 0.7 Hz, like a worn reel |
| Flutter | Off, Worn tape, Broken tape | fast pitch shake, 6.3 Hz, stacks with wobble |
| Lo-fi | Off, Old radio, Old console, Behind a wall, Laptop speaker | band-limiting and bit crushing |
| Vinyl crackle | Off, Light, Dusty | surface noise with random pops |
| Tape hiss | Off, Soft, Loud | steady high hiss |
| Dropouts | Off, Now and then, Often | short random volume dips |
| Width | Stereo, Narrow, Mono | cross-mixes left and right |

The whole soundtrack currently uses **Deep space, Reverb amount Normal, Tone Normal, Warmth Warm
tape, Tape wobble Gentle, Flutter Worn tape**, and everything else off. That combination is what
gives the set its "old equipment, big empty room" character, and it's the main thing tying seven
different songs together.

## Signal chain

```
part -> per-part gain -> per-part delay --+--> master --> tape wobble and flutter (modulated delay)
                     \                    |                 -> warmth (parallel saturation paths)
                      +--> reverb send ---+                 -> tone filter
                                                            -> lo-fi filters
                                                            -> bit crush (parallel)
                                                            -> width (left/right cross-mix)
                                                            -> dropouts (gain)
                                                            -> compressor -> out
     vinyl crackle and tape hiss are mixed in before the lo-fi filters, so they get coloured too
```

Warmth and lo-fi crush are parallel paths that crossfade rather than curves being swapped on a
single shaper, so changing them mid-playback never clicks.
