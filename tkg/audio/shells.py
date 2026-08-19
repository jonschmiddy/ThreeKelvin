"""Score for "Nine Shells" -- the star chart cue.

    python3 shells.py [--out DIR] [--loop] [--hp HZ]
"""
import numpy as np
np.random.seed(1729)          # renders are deterministic
import synth; synth.set_tempo(71)
from synth import *
from motif import (MOTIF, MAGGIORE, bar as bb, transpose, pitches,
                   whole_tone, pentatonic)

# =====================================================================
#  "NINE SHELLS"  -  71 BPM.  40 bars, 135.2 s.  No key, five key centres.
#
#  The first cue in the set that is not in F, and the first that modulates
#  at all.  Five cues had recoloured a static F pedal; this one moves.
#
#  It moves on something the motif turned out to already contain.  There
#  are only two whole-tone collections, and every note is in exactly one:
#
#      F, G  ->  WT1   { D♭ E♭ F G A B }
#      A♭    ->  WT0   { C  D  E G♭ A♭ B♭ }
#
#  So the motif's rocking 1-2 sits wholly inside one collection and its
#  single upward gesture -- the leap to ♭3, the only thing the phrase ever
#  *does* -- is the moment it crosses into the other.  That is not a reading
#  imposed on the tune; it is arithmetic on the five measured pitches.
#
#  The piece is that crossing, made structural.  The motif is transposed
#  around the **minor-third cycle F - A♭ - B - D - F**, which alternates
#  collections at every step and closes after four, and in every section the
#  same thing happens: four notes belong, one note does not.
#
#  A whole-tone scale contains no perfect fifth, so it has no root and no
#  cadence available anywhere.  That is the right colour for a screen where
#  you are choosing where to go next -- and the first version of this piece
#  ran it for thirty-two bars straight, which is a minute and forty-eight
#  seconds with no consonance in it anywhere.  Measured, that version was the
#  *least* rough cue in the set and still the hardest to sit with: the
#  problem was never the chords, it was that nothing ever landed.
#
#  So the cycle is interleaved.  Each six-bar whole-tone section is answered
#  by four bars of **major pentatonic on the same root** -- the exact
#  complement, five stacked perfect fifths against six equal steps -- and
#  every centre is therefore stated twice, once floating and once landed.
#  This is how Debussy actually uses the scale: the whole-tone passages in
#  Voiles are episodes between pentatonic ones, not the substance.
#
#  The motif follows the ground.  In the whole-tone bars it is MOTIF and its
#  ♭3 crosses out of the collection; in the pentatonic bars it is MAGGIORE
#  and every note belongs, because F, G and A are the pentatonic's own first
#  three notes *and* are all in WT1.  Minor and crossing, or major and home,
#  from one edit -- and the bass can only put a perfect fifth under the
#  second one, because in the first one there isn't a perfect fifth to use.
# =====================================================================

BARS = 40

# --- registers ---------------------------------------------------------

def rise(names, o):
    """Attach octaves to an ascending list of pitch classes, carrying up at
    each wrap. `octave()` deliberately does not do this -- see motif.py."""
    out, cur, prev = [], o, -1
    for n in names:
        pc = NAMES[n]
        if pc <= prev:
            cur += 1
        out.append(n + str(cur))
        prev = pc
    return out

def spread(scale, o):
    """Voice a scale's 1st, 4th, 2nd and 5th degrees, letting rise() carry
    each wrap into the next octave.

    One rule, two opposite results, which is the whole piece in four lines.
    On a **pentatonic** scale it produces a stack of perfect fifths --
    F2 C3 G3 D4 -- about as consonant as four notes get.  On a **whole-tone**
    scale the same indices give F3 B3 G4 D♭5: two tritones, and no interval
    smaller than a minor sixth below the fourth octave.

    That last part is the fix for the first version, which voiced the
    whole-tone tetrad closed as F3 G3 B3 D♭4.  A major second at 175 Hz sits
    well inside one critical band and beats; the same major second two
    octaves up is shimmer.  Same four pitch classes either way.
    """
    return rise([scale[i] for i in (0, 3, 1, 4)], o)

# (root, semitone step from F, motif start, chord octave, first bar)
#
# The minor-third cycle, alternating whole-tone collections at every step and
# closing after four: F(WT1) - A♭(WT0) - B(WT1) - D(WT0) - F.
WHOLE = [('F',  0, 'F5',  3,  1), ('Ab', 3, 'Ab5', 3, 11),
         ('B',  6, 'B4',  3, 21), ('D',  9, 'D5',  3, 31)]
# Each answered by its own root, landed. The last one comes home to F.
PENT  = [('F',  0, 'F5',  2,  7), ('Ab', 3, 'Ab5', 2, 17),
         ('B',  6, 'B4',  2, 27), ('F',  0, 'F5',  2, 37)]

T = {k: Track(BARS) for k in ['pad', 'harp', 'motif', 'reed', 'bell', 'fx']}

_pc, _st = {}, {}
def pk(f, d, a):
    k = (round(f, 2), round(d, 4))
    if k not in _pc: _pc[k] = pluck(f, d, 1.0)
    return _pc[k]*a
def st(freqs, d, a, cut=2400, atk=0.5):
    k = (tuple(round(f, 2) for f in freqs), round(d, 4), cut, atk)
    if k not in _st: _st[k] = strings(freqs, d, 1.0, cut, atk)
    return _st[k]*a

def arabesque(notes, bar, amp, voice, dur, step=0.5, pan0=-0.40):
    """A gesture, not a texture.

    The first version ran eight plucked notes a bar for all forty bars with no
    rest anywhere. Two things were wrong with that and they were the same
    thing: it is relentless to listen to, and pluck() is Karplus-Strong, so
    every note begins as a burst of filtered noise. Three hundred and twenty
    of them overlapping measured a spectral flatness of 0.08 on that stem --
    the noisiest pitched material in the whole score. Figuration should come
    and go.
    """
    for i, n in enumerate(notes):
        T['harp'].add(voice(hz(n), dur, amp), bb(bar) + i*step,
                      pan=pan0 + (-2*pan0)*(i/max(1, len(notes) - 1)))

# ============ THE CYCLE : four whole-tone sections, six bars each ============
for si, (root, step, start, cho, bar0) in enumerate(WHOLE):
    sc = whole_tone(root, 6)
    lift = 0.05*si                                   # each section a shade brighter
    for p in range(3):                               # planing, two bars a chord
        bar = bar0 + p*2
        T['pad'].add(st([hz(x) for x in spread([sc[(p + k) % 6] for k in range(6)], cho)],
                        2*BAR, 0.32, 2000 + 240*si), bb(bar))
        # root only, doubled at the octave. There is no perfect fifth in this
        # scale to put under it, which is exactly what the pentatonic bars are
        # for -- but the octave has to be there or the bass is a hole.
        T['pad'].add(sub(hz(sc[p] + str(cho - 1)), 2*BAR, 0.080), bb(bar))
        T['pad'].add(sub(hz(sc[p] + str(cho - 2)), 2*BAR, 0.055), bb(bar))
    # bell(), not pluck(): inharmonic but struck cleanly, with no noise burst
    up = rise(sc + [sc[0]], cho + 2)
    arabesque(up, bar0, 0.10 + lift*0.2, bell, 1.1)
    arabesque(up[::-1], bar0 + 3, 0.09 + lift*0.2, bell, 1.1, pan0=0.40)
    for k, bar in enumerate([bar0, bar0 + 3]):
        for n, b, d in pitches(transpose(MOTIF, step), start):
            T['motif'].add(glass(hz(n), d*SPB*0.95, 0.22 + lift), bb(bar) + b,
                           pan=-0.28 + 0.56*k)
    lo = start[:-1] + str(int(start[-1]) - 1)
    for n, b, d in pitches(transpose(MOTIF, step), lo):
        T['reed'].add(reed(hz(n), d*SPB*0.9, 0.15 + lift*0.4), bb(bar0 + 1) + b, pan=0.28)
    # air only where the ground is unstable, so landing lifts the noise floor
    T['fx'].add(air(6*BAR, 0.045, 200, 1600), bb(bar0))

# ============ THE ANSWERS : four pentatonic passages, four bars each ============
for pi, (root, step, start, cho, bar0) in enumerate(PENT):
    sc = pentatonic(root)
    home = (pi == 3)
    for p in range(2):
        bar = bar0 + p*2
        T['pad'].add(st([hz(x) for x in spread(sc, cho)], 2*BAR,
                        0.34 + 0.04*home, 2600, 0.42), bb(bar))
        # root and fifth -- the interval the whole-tone sections cannot form
        T['pad'].add(sub(hz(sc[0] + str(cho)), 2*BAR, 0.090 + 0.02*home), bb(bar))
        T['pad'].add(sub(hz(sc[0] + str(cho - 1)), 2*BAR, 0.060), bb(bar))
        T['pad'].add(st([hz(sc[3] + str(cho + 1))], 2*BAR, 0.20, 900, 0.6), bb(bar))
    # pluck() here and bell() in the whole-tone bars: the noise burst that
    # made it the wrong choice for a continuous texture is exactly right as
    # a harp, sparingly, where the harmony is warm
    run = rise(sc + [sc[0]], cho + 2)
    for k, bar in enumerate([bar0, bar0 + 2]):
        for i, n in enumerate(run):
            T['harp'].add(pk(hz(n), 0.95, 0.12), bb(bar) + i*0.75,
                          pan=(-0.34 if k == 0 else 0.34)*(1 - 2*i/6.0))
        for n, b, d in pitches(transpose(MAGGIORE, step), start):
            T['motif'].add(glass(hz(n), d*SPB*0.95, 0.26 + 0.04*home), bb(bar) + b,
                           pan=-0.18 + 0.36*k)
    lo = start[:-1] + str(int(start[-1]) - 1)
    for n, b, d in pitches(transpose(MAGGIORE, step), lo):
        T['reed'].add(reed(hz(n), d*SPB*0.9, 0.20), bb(bar0 + 1) + b, pan=0.30)
    T['bell'].add(bell(hz(rise(sc, cho + 3)[0]), 4.5, 0.11), bb(bar0 + 1), pan=0.36)
T['fx'].add(noise_swell(2*BAR, 0.05), bb(39))

# ---------------- mix ----------------
# Wide and wet. The subject is a galaxy; nothing here is close to you.

FX = {  # (reverb wet, delay in beats or None, level)
    'pad':   (0.52, None, 1.00),
    'harp':  (0.46, 1.50, 0.92),
    'motif': (0.60, 3.00, 1.00),
    'reed':  (0.50, None, 0.95),
    'bell':  (0.62, 3.00, 0.72),
    'fx':    (0.55, None, 0.85),
}

def render(name, tr):
    y = tr.out()
    wet, dl, lvl = FX[name]
    if dl: y = delay(y, dl*SPB, fb=0.36, mix=0.24)
    return reverb(y, wet)*lvl

def build(out_dir='out', loop=False, highpass=None):
    """loop=True drops the fade-out and wraps the reverb tail over the head."""
    mix, stems = master(
        {n: render(n, t) for n, t in T.items()},
        shelf=(0.14, 70), drive=1.14, peak=0.86,
        fade_in=(1.4, 1.3), fade_out=(4.0, 1.6),
        highpass=highpass,
        loop_len=int(BARS*BAR*SR) if loop else None)
    tag = '_loop' if loop else ''
    write_wav('%s/shells%s.wav' % (out_dir, tag), mix)
    for n, y in stems.items():
        write_wav('%s/shells_stems%s/%s.wav' % (out_dir, tag, n), y)
    return mix, stems

if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', default='out')
    ap.add_argument('--loop', action='store_true',
                    help='no fade-out; wrap the reverb tail back over the head')
    ap.add_argument('--hp', type=float, default=None, help='bus high-pass, Hz')
    a = ap.parse_args()
    m, _ = build(a.out, loop=a.loop, highpass=a.hp)
    print('shells%s  %.3f s  peak %.3f' % (
        '_loop' if a.loop else '', m.shape[1]/SR, np.max(np.abs(m))))
