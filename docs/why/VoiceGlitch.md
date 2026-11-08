The reasoning behind `tkg/scripts/ui/VoiceGlitch.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Voice glitch

Above `const EDGE_S := 0.004`:

```text
A.S.H.'S VOICE BREAKING UP while the hull fails (`LowHull`; Jon: "Maybe even
A.S.H.'s voice could glitch a bit?"). Her take, decoded by Godot's own
decoder (`AudioStreamPlayback.mix_audio`, as `AshTest` renders it), a few
short windows changed (`LowHull.voice_plan`), and played from memory as an
AudioStreamWAV in the take's place. NO NEW RECORDING AND NO SPEND: the same
take, edited live.

THE SAME LENGTH, SAMPLE FOR SAMPLE. Every glitch replaces samples in place;
none adds or removes any. The words type to the take's length
(`SignalText.rate_for`), so a repeat that pushed the rest of her line later
would part her words from her voice.

THE KINDS (`LowHull.plan_for` says where, how long and how hard). A dropout
and a stutter replace what she said, so they are short (110 ms at most: under
a short word); the rest keep her words under them, so she stays understood:
  gap      a dropout: the window drops to `1 - amt` of itself
  repeat   a stutter: the window's first stretch, said `rep` times over it
  chop     her voice gated on and off at `hz` (each edge of the gate eased
           over CHOP_EDGE_S), so a word breaks up like a bad link
  crackle  sparse clicks of static over her (CRACKLE_HZ of them a second at
           amt 1, each a few samples), on a slightly crushed voice
  crush    bit-crushed and sample-held (fewer bits and a lower rate)
  ring     ring-modulated at RING_HZ, mixed in at `amt`
  wobble   a pitch wobble: a delay that swells to WOBBLE_MS and back, so the
           pitch bends down and up and lands where it started
EVERY WINDOW IS FADED IN AND OUT over EDGE_S, so no glitch starts or ends on a
step (her takes were de-clicked once: `docs/ash.md`, "The takes are
de-clicked"; a glitch must not put the click back).
```

## Glitch placement

Above `const PLACE_QUIET := 0.12`:

```text
A GLITCH IN A PAUSE IS NOT HEARD (Jon: "I don't hear A.S.H.'s voice glitch
that much"): a stutter of silence is silence. So each window that would land
where she is quiet (fewer than PLACE_VOICED of its 10 ms steps over
PLACE_QUIET of her loudest) is moved to the nearest stretch where she is
speaking, within PLACE_REACH_S, keeping the
order, MIN_APART between two and the take's lead-in and tail clear. One that
finds nowhere is dropped: it would not be heard, and her portrait would slip
on a silence. Pure CPU on arrays (the worker's).
```
