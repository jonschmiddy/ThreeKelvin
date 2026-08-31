"""How much of each cue is literally the motif?

    python3 motif_audit.py [cue ...]

"Every cue in this game is that phrase" is the design (README, "The eight
cues are one idea") and it is not in question here.  What is in question is
the difference between a cue that is *built on* the motif and a cue that is
nothing but the motif played over and over, which is a different thing and
an easy one to arrive at by accident.  "First Light" arrived at it: fourteen
melodic call-sites, all fourteen the motif, no other melodic material in the
cue at all.  Nobody noticed until it was listened to.

So this counts rather than argues.  It runs each score with `Track.add`
instrumented, recovers the actual note stream per stem -- every pitch and
where it lands -- and slides the motif's interval signature over it.  A
match is five consecutive notes in one voice whose semitone offsets are
0 +2 0 +2 +3 from wherever they start, or one of the transformations the
scores use.  Transposition and octave are free by construction, and
augmentation and diminution are free because only pitch is matched.

What the number means
---------------------
The percentage is *of the notes a lead voice plays*, not of all notes --
accompaniment is supposed to be accompaniment.  A high number is not
automatically wrong: "Hard Burn" makes its engine out of the motif on
purpose and should read high.  A cue at or near 100% with no second theme
is the failure case, because the motif has nothing to be the motif of.
"""
import os, runpy, sys
from collections import defaultdict

import numpy as np

# Voices that carry a tune.  Everything else -- pad, strings, sub, drone,
# kick, air, noise_swell -- is harmony, bass or texture, and a motif in the
# bass line is not what is being counted.
LEAD = {'whistle', 'whistle_bend', 'reed', 'glass', 'bell', 'hammer',
        'pluck', 'blade', 'bowed', 'metal', 'organ'}

# The signatures, as semitone offsets from the first note of the group.
SIGS = {
    'MOTIF':     (0, 2, 0, 2, 3),
    'INVERT':    (0, -2, 0, -2, -3),
    'PHRYGIAN':  (0, 1, 0, 1, 3),
    'MAGGIORE':  (0, 2, 0, 2, 4),
    'SINK':      (0, 2, 0, 2, 1),
    'TRITONE':   (0, 2, 0, 2, 6),
}

CUES = [('arrange.py', 'theme'), ('dread.py', 'dread'), ('burn.py', 'burn'),
        ('warm.py', 'warm'), ('boss.py', 'boss'), ('shells.py', 'shells'),
        ('business.py', 'business'), ('home.py', 'home'),
        ('first_light.py', 'first_light'), ('perpetuity.py', 'perpetuity'),
        ('core.py', 'core'), ('fauna.py', 'fauna'), ('nofault.py', 'nofault')]


def capture(script):
    """Run a score, returning {stem: [(beat, midi)]} for the lead voices.

    The hook works on evaluation order and nothing else: a score always
    writes `track.add(whistle(hz(n), ...), beat)`, so the instrument runs
    before `add` does.  Each wrapped instrument pushes its frequency; `add`
    pops it and pairs it with the beat it was given.  Anything that reaches
    `add` without a pending frequency is a chord, a drum or a noise bed, and
    is dropped -- which is the intent.
    """
    import synth
    pending, notes = [], defaultdict(list)
    orig_add = synth.Track.add
    originals = {}

    def wrap(name):
        fn = getattr(synth, name)
        def g(f, *a, **k):
            pending.append((f, a[0] if a else k.get('dur', 0.0)))
            return fn(f, *a, **k)
        originals[name] = fn
        setattr(synth, name, g)

    for n in LEAD:
        if hasattr(synth, n):
            wrap(n)

    # Keyed on the Track OBJECT, not on a name.  The first version tagged
    # each Track with its dict key after the score had finished running, by
    # which time every note had already been filed under the placeholder --
    # so all six voices went into one stream, and "five consecutive notes"
    # meant five notes interleaved from different instruments.  It reported
    # burn and warm at 0% motif, which the README alone is enough to know is
    # false.  Identity is available during the run; the name is not.
    def add(self, x, at_beat, pan=0.0, gain=1.0):
        if pending:
            f, dur = pending.pop()
            notes[id(self)].append(
                (float(at_beat), 69 + 12 * np.log2(max(1e-9, f) / 440.0),
                 float(dur)))
        return orig_add(self, x, at_beat, pan, gain)

    synth.Track.add = add
    try:
        g = runpy.run_path(script, run_name='__audit__')
        names = {}
        for d in g.values():
            if isinstance(d, dict):
                for k, v in d.items():
                    if isinstance(v, synth.Track):
                        names[id(v)] = k
        return {names.get(k, 'track%d' % i): v
                for i, (k, v) in enumerate(notes.items())}, g
    finally:
        synth.Track.add = orig_add
        for n, fn in originals.items():
            setattr(synth, n, fn)


def count(stream):
    """(lead notes, motif notes, which signatures) for one voice's stream.

    Matching is over the pitch SET at each beat rather than over a flat list
    of consecutive notes, and that is not a refinement -- the flat version
    was simply wrong.  Two things defeat it, and both are ordinary writing:

      * a unison doubling.  `burn.py` adds its motif to the same track twice
        at two pans, so every beat carries the same pitch twice and the
        offsets read 0 0 2 2 ... .  It reported burn as 0% motif, in the cue
        whose entire premise is that the engine is made out of the motif.
      * two lines sharing a voice.  A tune under a statement interleaves
        when the stream is sorted by beat and neither is found.

    So: take the distinct beats, and at each one the set of pitches present.
    A match is five consecutive beats where SOME choice of pitch from each
    fits the signature.  Octave doublings, unisons and an accompanying line
    all stop mattering, which is the point.
    """
    by_beat = defaultdict(set)
    secs = defaultdict(float)
    for b, m, d in stream:
        by_beat[round(b, 3)].add(round(m))
        secs[round(b, 3)] = max(secs[round(b, 3)], d)
    beats = sorted(by_beat)
    hits, used, mtime = 0, defaultdict(int), [0.0]
    i = 0
    while i + 4 < len(beats):
        matched = None
        for p0 in by_beat[beats[i]]:
            for name, sig in SIGS.items():
                if all(p0 + sig[k] in by_beat[beats[i + k]] for k in range(5)):
                    matched = name
                    break
            if matched:
                break
        if matched:
            hits += 5
            used[matched] += 1
            mtime[0] += sum(secs[beats[i + k]] for k in range(5))
            i += 5
        else:
            i += 1
    return len(beats), hits, used, sum(secs.values()), mtime[0]


if __name__ == '__main__':
    only = sys.argv[1:]
    print('%-12s %7s %6s %7s %5s   %s' % (
        'cue', 'onsets', 'motif', 'secs', 'motif', 'as'))
    print('-' * 70)
    for script, name in CUES:
        if only and name not in only:
            continue
        notes, _ = capture(script)
        tot = mot = 0
        ts = ms = 0.0
        kinds = defaultdict(int)
        for stem, stream in notes.items():
            a, b, u, t, m = count(stream)
            tot += a; mot += b; ts += t; ms += m
            for k, v in u.items():
                kinds[k] += v
        print('%-12s %7d %6.0f%% %7.0f %5.0f%%   %s' % (
            name, tot, 100.0 * mot / max(1, tot), ts, 100.0 * ms / max(1e-9, ts),
            ' '.join('%s x%d' % (k, v) for k, v in sorted(kinds.items()))))
