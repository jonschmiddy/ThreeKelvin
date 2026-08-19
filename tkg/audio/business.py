"""Score for "Ship's Business" -- the event cue.

    python3 business.py [--out DIR] [--loop] [--hp HZ]
"""
import numpy as np
np.random.seed(1729)          # renders are deterministic
import synth; synth.set_tempo(142)
from synth import *
from motif import (MOTIF, MAGGIORE, bar as bb, pitches, transpose,
                   diminish, appoggiatura, turn, F_MINOR)

# =====================================================================
#  "SHIP'S BUSINESS"  -  142 BPM, F minor.  48 bars, 81.13 s.
#
#  A sonata-form miniature, and the first music in the game with a
#  **cadence** in it.
#
#  That absence was structural, not an oversight.  The motif has no fifth
#  and no leading tone, so five cues had no dominant available and nothing
#  in them could ever arrive -- which is right for a run that can end at
#  any moment, and wrong for the one screen where something specific has
#  happened and you must decide what to do about it.  Bar 4 puts an E♮
#  under the tune, the first leading tone in the score, and the phrase
#  stops on it.  Bar 8 answers with a perfect cadence in A♭ major.
#
#  From there the piece uses the classical apparatus for exactly the thing
#  the brief needed: **it changes key**.  Bars 9-16 are a diatonic circle
#  of fifths that states the motif in eight keys in eight bars, which is
#  more key centres than the previous five cues have between them.
#
#  And sonata form turns out to describe something already true here.  A
#  sonata has two subjects, in different keys, reconciled in the tonic at
#  the end.  The second subject (bars 17-24, A♭ major) is MAGGIORE; the
#  first is MOTIF.  They are one note apart.  So the recapitulation's job
#  -- bring the second subject home -- is done by flattening a single note,
#  and bars 37-40 have both voices playing what is audibly the same tune.
# =====================================================================

BARS = 48

# --- harmony ---------------------------------------------------------
# (voicing, bass).  Close position, octave 3, the way a string quartet
# would actually sit -- the wide spread the other cues use is a synthesiser
# habit and it makes counterpoint impossible to hear.
FM    = (['F3', 'Ab3', 'C4'],          'F2')
FM6   = (['Ab3', 'C4', 'F4'],          'Ab2')
BBM   = (['Bb3', 'Db4', 'F4'],         'Bb2')
C7    = (['C3', 'E3', 'G3', 'Bb3'],    'C2')     # E natural: the leading tone
DB    = (['Db3', 'F3', 'Ab3'],         'Db2')
EB7   = (['Eb3', 'G3', 'Bb3', 'Db4'],  'Eb2')
AB    = (['Ab2', 'C3', 'Eb3', 'Ab3'],  'Ab2')
ABM   = (['Ab3', 'B3', 'Eb4'],         'Ab2')
DBM   = (['Db3', 'E3', 'Ab3'],         'Db2')
GB    = (['Gb3', 'Bb3', 'Db4'],        'Gb2')
BDIM  = (['Bb2', 'Db3', 'E3', 'G3'],   'Bb2')
ABE   = (['Eb3', 'Ab3', 'C4'],         'Eb2')
FMF   = (['F3', 'Ab3', 'C4', 'F4'],    'F2')
GDIM  = (['G3', 'Bb3', 'Db4'],         'G2')
EB    = (['Eb3', 'G3', 'Bb3'],         'Eb2')

## Antecedent ends on C7 -- a half cadence, the phrase left open.
## Consequent ends on A♭ -- a perfect cadence in the relative major.
PERIOD  = [FM, FM6, BBM, C7, FM, DB, EB7, AB]
## Recapitulation: same antecedent, consequent bent back to close in F minor.
RECAP   = [FM, FM6, BBM, C7, FM, DB, C7, FMF]
## Second group, A♭ major.
SECOND  = [AB, EB7, AB, DB, ABE, EB7, AB, AB]
## Development: flatwards through the minor side, then two bars of dominant.
DEVEL   = [ABM, DBM, GB, BDIM, EB7, ABM, C7, C7]
## Coda: V-VI deceptive, then the real thing.
CODA    = [C7, DB, BBM, C7, FM, BBM, FM, FMF]

# --- melody ----------------------------------------------------------
# The motif is the head of a real period: statement, link, continuation,
# cadence.  Everywhere else in the score it is a loop; here it is a
# sentence, and it stops.
ANTE = pitches(MOTIF, 'F5') + [
    ('F5', 6, 1), ('G5', 7, 1),                                  # link
    ('Bb5', 8, 1), ('Ab5', 9, 1), ('G5', 10, 1), ('Ab5', 11, 1), # continuation
    ('G5', 12, 2), ('E5', 14, 2)]                                # half cadence
CONS = [(n, b + 16, d) for n, b, d in pitches(MOTIF, 'F5')] + [
    ('Ab5', 22, 1), ('Bb5', 23, 1),
    ('C6', 24, 1), ('Bb5', 25, 1), ('Ab5', 26, 1), ('G5', 27, 1),
    ('Ab5', 28, 4)]                                              # PAC in Ab
CONS_MIN = [(n, b + 16, d) for n, b, d in pitches(MOTIF, 'F5')] + [
    ('Ab5', 22, 1), ('G5', 23, 1),
    ('F5', 24, 1), ('E5', 25, 1), ('F5', 26, 1), ('G5', 27, 1),
    ('F5', 28, 4)]                                               # PAC in F minor

CELL = diminish(MOTIF, 2)                     # 3 beats: fits one bar
## Diatonic, not chromatic: F B♭ E♭ A♭ D♭ G C F.  The G is a diminished
## triad because F minor has G♮ and not G♭, which is exactly why the
## sequence sounds like it is going somewhere rather than merely sliding.
CIRCLE = [(0, 'F5'), (5, 'Bb4'), (10, 'Eb5'), (3, 'Ab4'),
          (8, 'Db5'), (2, 'G4'), (7, 'C5'), (0, 'F4')]
CIRCLE_CH = [FM, BBM, EB7, AB, DB, GDIM, C7, FM]

T = {k: Track(BARS) for k in ['strings', 'hammer', 'motif', 'reed', 'bass', 'fx']}

_h, _s, _p = {}, {}, {}
def hm(f, d, a, br=1.0):
    k = (round(f, 2), round(d, 4), br)
    if k not in _h: _h[k] = hammer(f, d, 1.0, br)
    return _h[k]*a
def st(freqs, d, a, cut=2600, atk=0.16):
    k = (tuple(round(f, 2) for f in freqs), round(d, 4), cut, atk)
    if k not in _s: _s[k] = strings(freqs, d, 1.0, cut, atk)
    return _s[k]*a
def pz(f, d, a):
    k = (round(f, 2), round(d, 4))
    if k not in _p: _p[k] = pluck(f, d, 1.0)
    return _p[k]*a

def bed(chords, bar0, amp=0.70, cut=4200, atk=0.16):
    for i, (v, root) in enumerate(chords):
        T['strings'].add(st([hz(x) for x in v], BAR, amp, cut, atk), bb(bar0 + i))

def walk(chords, bar0, amp=0.24, per=2):
    """Bass: root on the downbeat, fifth at the half. Not a drone -- a line."""
    for i, (v, root) in enumerate(chords):
        T['bass'].add(sub(hz(root), SPB*1.7, amp), bb(bar0 + i))
        if per > 1:
            T['bass'].add(pz(hz(root)*1.4983, SPB*1.3, amp*0.34), bb(bar0 + i) + 2)

def alberti(chords, bar0, amp=0.40, n=8, br=1.0):
    """Root - fifth - third - fifth. The cheapest way to keep a slow harmony
    moving, which is why it is under half of Mozart."""
    order = [0, 2, 1, 2]
    for i, (v, root) in enumerate(chords):
        for s in range(n):
            f = hz(v[order[s % 4] % len(v)])
            T['hammer'].add(hm(f, 4.0*SPB/n*1.6, amp, br), bb(bar0 + i) + s*(4.0/n),
                            pan=-0.22 + 0.44*((s % 4)/3.0))

def sing(track, notes, bar0, amp, voice, pan=0.0, art=0.94):
    for n, b, d in notes:
        track.add(voice(hz(n), d*SPB*art, amp), bb(bar0) + b, pan=pan)

# ============ EXPOSITION, first group : bars 1-8 ============
bed(PERIOD, 1)
walk(PERIOD, 1)
alberti(PERIOD, 1)
sing(T['motif'], ANTE, 1, 0.38, whistle, pan=-0.12)
sing(T['motif'], CONS, 1, 0.38, whistle, pan=-0.12)
sing(T['reed'], [(n, b, d) for n, b, d in ANTE if b >= 8], 1, 0.16, reed, pan=0.30)
T['fx'].add(air(8*BAR, 0.05, 300, 2600), bb(1))

# ============ TRANSITION : circle of fifths : bars 9-16 ============
# Eight keys in eight bars. The motif is halved so one statement fits one
# bar, and it lands on the root of each new chord as that chord arrives --
# so what modulates is the tune, not the accompaniment under a fixed tune.
bed(CIRCLE_CH, 9, amp=0.64)
walk(CIRCLE_CH, 9, amp=0.26)
alberti(CIRCLE_CH, 9, amp=0.40, n=16, br=0.85)
for i, (step, start) in enumerate(CIRCLE):
    sing(T['motif'], pitches(transpose(CELL, step), start), 9 + i, 0.36, whistle,
         pan=-0.34 + 0.68*(i/7.0))
    if i >= 3:                                   # the wind joins the descent
        lo = start[:-1] + str(int(start[-1]) - 1)
        sing(T['reed'], pitches(transpose(CELL, step), lo), 9 + i, 0.17, reed,
             pan=0.34 - 0.68*(i/7.0))

# ============ EXPOSITION, second group : bars 17-24 ============
# A♭ major, and the second subject is MAGGIORE -- the motif with its ♭3
# raised. One note is the whole difference between the two subjects of this
# movement, which is either a very economical piece of writing or the only
# honest thing to do with a five-note tune.
bed(SECOND, 17, amp=0.66, cut=4600, atk=0.13)
walk(SECOND, 17, amp=0.24)
alberti(SECOND, 17, amp=0.40, n=16)
for k, bar in enumerate([17, 21]):
    sing(T['reed'], pitches(MAGGIORE, 'Ab5'), bar, 0.26, reed, pan=0.22)
    sing(T['motif'], pitches(MAGGIORE, 'Ab4'), bar + 1, 0.22, whistle, pan=-0.28)
sing(T['motif'], [('Eb5', 0, 1), ('C5', 1, 1), ('Ab4', 2, 2)], 23, 0.28, whistle)
sing(T['reed'], [('Ab5', 0, 4)], 23, 0.22, reed, pan=0.22)

# ============ DEVELOPMENT : bars 25-32 ============
# The head only, two notes, thrown between the two voices a beat apart and
# dragged flatwards. Nothing is stated whole until the recapitulation.
bed(DEVEL, 25, amp=0.70, cut=3600)
walk(DEVEL, 25, amp=0.26, per=1)
alberti(DEVEL, 25, amp=0.36, n=16, br=0.8)
HEAD = CELL[:4]                                  # F G F G, half a bar
for i, (step, hi, lo) in enumerate([(3, 'Ab5', 'Ab4'), (8, 'Db5', 'Db4'),
                                    (6, 'Gb5', 'Gb4'), (10, 'Bb4', 'Bb3'),
                                    (10, 'Eb5', 'Eb4'), (3, 'Ab4', 'Ab3'),
                                    (7, 'C5', 'C4'),  (7, 'C5', 'C4')]):
    bar = 25 + i
    sing(T['motif'], pitches(transpose(HEAD, step), hi), bar, 0.34, whistle, pan=-0.36)
    sing(T['reed'], [(n, b + 1, d) for n, b, d in pitches(transpose(HEAD, step), lo)],
         bar, 0.20, reed, pan=0.36)               # stretto at one beat
    if i >= 6:                                    # dominant pedal, retransition
        T['bass'].add(sub(hz('C2'), SPB*3.6, 0.26), bb(bar))
T['fx'].add(noise_swell(2*BAR, 0.10), bb(31))

# ============ RECAPITULATION : bars 33-40 ============
# Ornamented on the way in -- appoggiatura on every note of the head and a
# turn on the ♭3, which is what a Mozart reprise does rather than repeat
# itself. The consequent no longer leaves for A♭; it cadences at home.
bed(RECAP, 33, amp=0.76, cut=4800)
walk(RECAP, 33, amp=0.26)
alberti(RECAP, 33, amp=0.42, n=16)
# frac=0.5 so the leans land on the eighth-note grid, and the fast turn goes
# on the fortepiano rather than the whistle -- see home.py for both reasons.
ORN = pitches(appoggiatura(MOTIF[:4], frac=0.5, scale=F_MINOR)
              + MOTIF[4:], 'F5', anchor=1)
ORN_TURN = pitches(turn(MOTIF[4:], 0, frac=0.5, up=2, down=-1)[:4], 'Ab5')
sing(T['motif'], ORN, 33, 0.36, whistle, pan=-0.12, art=0.96)
sing(T['hammer'], ORN_TURN, 33, 0.26, hammer, pan=0.16)
sing(T['motif'], [(n, b, d) for n, b, d in ANTE if b >= 6], 33, 0.36, whistle, pan=-0.12)
sing(T['motif'], CONS_MIN, 33, 0.38, whistle, pan=-0.12)
# both subjects, in the tonic, one note apart and now identical
sing(T['reed'], [(n, b + 16, d) for n, b, d in pitches(MOTIF, 'F4')], 33, 0.24,
     reed, pan=0.30)

# ============ CODA : bars 41-48 ============
# V-VI first -- the cadence you were promised, withheld once. Then the real
# one, and then the motif goes into the bass under a held tonic so that the
# loop turns over on the tune rather than on a join.
bed(CODA, 41, amp=0.76, cut=4200)
walk(CODA, 41, amp=0.26)
alberti(CODA[:4], 41, amp=0.40, n=8)
sing(T['motif'], pitches(MOTIF, 'F5'), 41, 0.34, whistle, pan=-0.14)
sing(T['reed'], pitches(MOTIF, 'Ab4'), 42, 0.20, reed, pan=0.32)
sing(T['motif'], [('C6', 0, 1), ('Bb5', 1, 1), ('Ab5', 2, 1), ('G5', 3, 1),
                  ('F5', 4, 4)], 44, 0.34, whistle, pan=-0.10)
for n, b, d in pitches(MOTIF, 'F2'):             # the tune, in the bass
    T['bass'].add(pz(hz(n), SPB*1.5, 0.30), bb(46) + b, pan=-0.2)
T['strings'].add(st([hz(x) for x in ['F3', 'Ab3', 'C4', 'F4']], 3*BAR, 0.80, 4000, 0.5),
                 bb(46))
T['motif'].add(whistle(hz('F5'), 2.4, 0.26), bb(47) + 2, pan=0.0)
T['fx'].add(air(8*BAR, 0.05, 280, 2400), bb(41))

# ---------------- mix ----------------
# Small room, close, transparent. Four voices you can follow individually
# is the point of the style; a long tail would glue them into one.

FX = {  # (reverb wet, delay in beats or None, level)
    'strings': (0.30, None, 1.15),
    'hammer':  (0.22, None, 1.15),
    'motif':   (0.26, None, 1.00),
    'reed':    (0.28, None, 1.20),
    'bass':    (0.08, None, 0.80),
    'fx':      (0.45, None, 0.80),
}

def render(name, tr):
    y = tr.out()
    wet, dl, lvl = FX[name]
    if dl: y = delay(y, dl*SPB, fb=0.30, mix=0.20)
    y = reverb(y, wet)*lvl
    if name == 'bass': y = lp(y, 220, 2)*1.0 + hp(y, 220, 2)*0.34
    return y

def build(out_dir='out', loop=False, highpass=None):
    """loop=True drops the fade-out and wraps the reverb tail over the head."""
    mix, stems = master(
        {n: render(n, t) for n, t in T.items()},
        shelf=(0.30, 100), drive=1.15, peak=0.86,
        fade_in=(0.4, 1.1), fade_out=(2.4, 1.5),
        highpass=highpass,
        loop_len=int(BARS*BAR*SR) if loop else None)
    tag = '_loop' if loop else ''
    write_wav('%s/business%s.wav' % (out_dir, tag), mix)
    for n, y in stems.items():
        write_wav('%s/business_stems%s/%s.wav' % (out_dir, tag, n), y)
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
    print('business%s  %.3f s  peak %.3f' % (
        '_loop' if a.loop else '', m.shape[1]/SR, np.max(np.abs(m))))
