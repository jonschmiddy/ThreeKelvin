"""Score for "Five Ways Home" -- the title and menu cue.

    python3 home.py [--out DIR] [--loop] [--hp HZ]
"""
import numpy as np
np.random.seed(1729)          # renders are deterministic
import synth; synth.set_tempo(142)
from synth import *
from motif import (MOTIF, MAGGIORE, bar as bb, pitches, augment,
                   appoggiatura, turn, whole_tone, F_MINOR)

# =====================================================================
#  "FIVE WAYS HOME"  -  142 BPM, F minor.  48 bars, 81.13 s.
#
#  Theme and five variations -- the oldest form there is for the problem
#  this soundtrack has, which is that one whistled phrase has to carry a
#  whole game without wearing out.  Every other cue solves that by putting
#  the motif in a different *place*.  This one just varies it, in front of
#  you, on the title screen, and says so.
#
#    Theme  bars  1-8   plain, F minor, one voice and a quartet
#    I            9-16  ornamental -- appoggiatura on every note, a turn
#                       on the ♭3, sixteenths underneath.  Mozart's way of
#                       repeating something without repeating it
#    II          17-24  **maggiore: F major.**  A♭ becomes A♮ and the
#                       soundtrack is, for eight bars, not in a minor key
#                       for the first time since the game booted
#    III         25-32  whole-tone.  No new material at all -- see below
#    IV          33-40  canon at the octave, two beats apart, back in minor
#    V           41-48  chorale, augmented, four parts, cadence home
#
#  The hinge is variation III, and it costs nothing.  F, G and A are all in
#  the same whole-tone collection, so the maggiore variation is *already*
#  whole-tone; III does not modulate away from II, it just stops harmonising
#  the notes as F major and starts planing them.  The most classical moment
#  in the set and the most impressionist one are the same five notes with
#  the same one edit, and the join between them is not a modulation but a
#  change of mind about what the chord under them is for.
# =====================================================================

BARS = 48

# --- harmony ---------------------------------------------------------
MINOR = [                                    # theme, var I
    (['F3', 'Ab3', 'C4'],         'F2'),
    (['Db3', 'F3', 'Ab3'],        'Db2'),
    (['Bb3', 'Db4', 'F4'],        'Bb2'),
    (['C3', 'E3', 'G3', 'Bb3'],   'C2'),
    (['F3', 'Ab3', 'C4'],         'F2'),
    (['Ab3', 'C4', 'Eb4'],        'Ab2'),
    (['Eb3', 'G3', 'Bb3', 'Db4'], 'Eb2'),
    (['F3', 'Ab3', 'C4', 'F4'],   'F2'),
]
MAJOR = [                                    # var II -- the same bars, major
    (['F3', 'A3', 'C4'],          'F2'),
    (['Bb3', 'D4', 'F4'],         'Bb2'),
    (['C3', 'E3', 'G3', 'Bb3'],   'C2'),
    (['F3', 'A3', 'C4'],          'F2'),
    (['D3', 'F3', 'A3'],          'D2'),
    (['Bb3', 'D4', 'F4'],         'Bb2'),
    (['C3', 'E3', 'G3', 'Bb3'],   'C2'),
    (['F3', 'A3', 'C4', 'F4'],    'F2'),
]
CANON = [MINOR[0], MINOR[0], MINOR[2], MINOR[3],
         MINOR[0], MINOR[1], MINOR[3], MINOR[7]]
CHORALE = [MINOR[0], MINOR[1], MINOR[5], MINOR[6],
           MINOR[0], MINOR[2], MINOR[3], MINOR[7]]

# --- the theme -------------------------------------------------------
# A period: statement, link, continuation to a half cadence; then the same
# again, continuing instead to a perfect cadence at home.
THEME = pitches(MOTIF, 'F5') + [
    ('F5', 6, 1), ('G5', 7, 1),
    ('Ab5', 8, 2), ('G5', 10, 2),
    ('F5', 12, 2), ('E5', 14, 2),                       # half cadence on C7
] + [(n, b + 16, d) for n, b, d in pitches(MOTIF, 'F5')] + [
    ('Ab5', 22, 1), ('Bb5', 23, 1),
    ('C6', 24, 2), ('Bb5', 26, 2),
    ('Ab5', 28, 1), ('G5', 29, 1), ('F5', 30, 2),       # PAC in F minor
]
## Every note leaned on from a semitone above, and a turn on the ♭3. Same
## rhythm, same harmony, same pitches underneath -- only the surface moves.
## Lean on each of the four oscillating notes. Two rules, both learned the
## hard way:
##
##   * **frac=0.5, so the ornament is on the grid.** An appoggiatura takes a
##     *notated* fraction of its note -- half of a duple note, here. 0.34 is
##     not a 16th (0.25) and not a triplet 8th (0.333); it is nothing, and it
##     put every resolution 38 ms behind the sixteenths the fortepiano is
##     playing underneath while alternating 138 and 268 ms note lengths. It
##     sounded exactly like what it was: off the beat and lumpy.
##   * **The whistle does not get the fast ornament.** The turn is four notes
##     at a sixteenth apiece, and whistle() has a 45 ms attack and a vibrato;
##     it cannot articulate that, and four of them in a row is a stutter. The
##     turn goes on the fortepiano, which has a 1.5 ms attack and is the
##     instrument the figure was written for. The whistle holds the ♭3 plainly
##     underneath it, which is also what a singer would do.
ORNAMENTED = pitches(appoggiatura(MOTIF[:4], frac=0.5, scale=F_MINOR)
                     + MOTIF[4:], 'F5', anchor=1)
TURN_FIG = pitches(turn(MOTIF[4:], 0, frac=0.5, up=2, down=-1)[:4], 'Ab5')

T = {k: Track(BARS) for k in ['whistle', 'strings', 'hammer', 'glass', 'reed', 'fx']}

_h, _s, _p = {}, {}, {}
def hm(f, d, a, br=1.0):
    k = (round(f, 2), round(d, 4), br)
    if k not in _h: _h[k] = hammer(f, d, 1.0, br)
    return _h[k]*a
def st(freqs, d, a, cut=4200, atk=0.16):
    k = (tuple(round(f, 2) for f in freqs), round(d, 4), cut, atk)
    if k not in _s: _s[k] = strings(freqs, d, 1.0, cut, atk)
    return _s[k]*a
def pk(f, d, a):
    k = (round(f, 2), round(d, 4))
    if k not in _p: _p[k] = pluck(f, d, 1.0)
    return _p[k]*a

def quartet(chords, bar0, amp=0.72, cut=4200, atk=0.16, bass=0.24):
    for i, (v, root) in enumerate(chords):
        T['strings'].add(st([hz(x) for x in v], BAR, amp, cut, atk), bb(bar0 + i))
        T['strings'].add(st([hz(root)], BAR, bass, 900, 0.22), bb(bar0 + i))
        T['strings'].add(sub(hz(root)*0.5, BAR*0.92, bass*0.62), bb(bar0 + i))

def keys(chords, bar0, amp=0.34, n=8, br=1.0):
    order = [0, 2, 1, 2]
    for i, (v, root) in enumerate(chords):
        T['hammer'].add(hm(hz(root)*0.5, 4.0*SPB*0.9, amp*0.9, br), bb(bar0 + i))
        for s in range(n):
            f = hz(v[order[s % 4] % len(v)])
            T['hammer'].add(hm(f, 4.0*SPB/n*1.7, amp, br), bb(bar0 + i) + s*(4.0/n),
                            pan=-0.20 + 0.40*((s % 4)/3.0))

def sing(track, notes, bar0, amp, voice, pan=0.0, art=0.94, off=0.0):
    for n, b, d in notes:
        track.add(voice(hz(n), d*SPB*art, amp), bb(bar0) + b + off, pan=pan)

# ============ THEME : bars 1-8 ============
# As bare as it goes: the tune, a quartet, and nothing else in the frame.
quartet(MINOR, 1, amp=0.62, cut=3600)
sing(T['whistle'], THEME, 1, 0.40, whistle, pan=-0.10)
T['fx'].add(air(8*BAR, 0.05, 300, 2600), bb(1))

# ============ VAR I : ornamental : bars 9-16 ============
quartet(MINOR, 9, amp=0.66)
keys(MINOR, 9, amp=0.34, n=16, br=0.95)
sing(T['whistle'], ORNAMENTED, 9, 0.38, whistle, pan=-0.10, art=0.96)
sing(T['hammer'], TURN_FIG, 9, 0.26, hammer, pan=0.18)      # turn, on the keys
sing(T['whistle'], [(n, b, d) for n, b, d in THEME if b >= 6], 9, 0.38, whistle, pan=-0.10)
sing(T['reed'], pitches(MOTIF, 'F4'), 13, 0.20, reed, pan=0.30)

# ============ VAR II : maggiore : bars 17-24 ============
# One note. A♭ -> A♮, and the piece is in F major. Nothing else changes:
# same rhythm, same phrase lengths, same bar-by-bar harmonic rhythm.
quartet(MAJOR, 17, amp=0.70, cut=5000, atk=0.13)
keys(MAJOR, 17, amp=0.32, n=8)
for k, bar in enumerate([17, 21]):
    sing(T['reed'], pitches(MAGGIORE, 'F5'), bar, 0.28, reed, pan=0.20)
    sing(T['whistle'], pitches(MAGGIORE, 'F6'), bar, 0.18, whistle, pan=-0.34)
sing(T['whistle'], [('C6', 0, 2), ('Bb5', 2, 2), ('A5', 4, 2), ('G5', 6, 1),
                    ('F5', 7, 1)], 19, 0.34, whistle, pan=-0.10)
sing(T['whistle'], [('A5', 0, 2), ('G5', 2, 2), ('F5', 4, 4)], 23, 0.34, whistle)

# ============ VAR III : whole-tone : bars 25-32 ============
# No modulation happens here. F G A is already one whole-tone collection --
# variation II handed it over intact. All that changes is what the chord
# under it is doing: instead of functioning, it planes.
WT = whole_tone('F', 6)                       # F G A B Db Eb
def tetrad(i, o):
    sc = [WT[(i + k) % 6] for k in range(6)]
    out, cur, prev = [], o, -1
    for n in [sc[0], sc[3], sc[1], sc[4]]:
        pc = NAMES[n]
        if pc <= prev: cur += 1
        out.append(n + str(cur)); prev = pc
    return out
for p in range(4):
    bar = 25 + p*2
    T['strings'].add(st([hz(x) for x in tetrad(p, 3)], 2*BAR, 0.60, 3800, 0.5), bb(bar))
    T['strings'].add(st([hz(WT[p] + '2')], 2*BAR, 0.30, 700, 0.6), bb(bar))
    T['strings'].add(sub(hz(WT[p] + '1'), 2*BAR*0.94, 0.17), bb(bar))
run = []
cur, prev = 4, -1
for n in WT + [WT[0]]:
    pc = NAMES[n]
    if pc <= prev: cur += 1
    run.append(n + str(cur)); prev = pc
for b in range(4):
    up = run if b % 2 == 0 else run[::-1]
    for i, n in enumerate(up):
        T['glass'].add(bell(hz(n), 1.3, 0.11), bb(25 + b*2) + i*0.5,
                       pan=-0.40 + 0.80*(i/6.0))
for k, bar in enumerate([25, 29]):
    sing(T['glass'], pitches(MAGGIORE, 'F5'), bar, 0.32, glass, pan=-0.24 + 0.48*k)
    sing(T['glass'], pitches(MAGGIORE, 'F6'), bar, 0.15, glass, pan=0.24 - 0.48*k)
    sing(T['reed'], pitches(MAGGIORE, 'F4'), bar, 0.26, reed, pan=0.30, off=2)

# ============ VAR IV : canon : bars 33-40 ============
# Strict, at the octave, two beats apart. The learned style, and the one
# variation that adds no colour at all -- just the tune against itself.
quartet(CANON, 33, amp=0.50, cut=3200, bass=0.26)
for bar in [33, 35, 37, 39]:
    sing(T['whistle'], pitches(MOTIF, 'F5'), bar, 0.38, whistle, pan=-0.30)   # dux
    sing(T['reed'], pitches(MOTIF, 'F4'), bar, 0.24, reed, pan=0.32, off=2)   # comes
for i, bar in enumerate([34, 36, 38, 40]):
    T['hammer'].add(hm(hz(CANON[bar - 33][1])*0.5, 3.2*SPB, 0.30), bb(bar))

# ============ VAR V : chorale : bars 41-48 ============
# Augmented to half speed, four parts, and the cadence the theme promised.
# The loop turns over out of the tonic straight back into bar 1, so the
# title screen restates the tune plainly every eighty seconds.
quartet(CHORALE, 41, amp=0.80, cut=3400, atk=0.30, bass=0.30)
for bar in [41, 45]:
    sing(T['whistle'], [(n, b, d) for n, b, d in augment(pitches(MOTIF, 'F5'), 2)],
         bar, 0.36, whistle, pan=-0.10, art=0.92)
    sing(T['reed'], [(n, b, d) for n, b, d in augment(pitches(MOTIF, 'F4'), 2)],
         bar, 0.22, reed, pan=0.28)
    sing(T['glass'], [(n, b, d) for n, b, d in augment(pitches(MOTIF, 'F6'), 2)],
         bar, 0.14, glass, pan=0.34)
T['whistle'].add(whistle(hz('F5'), 2.6, 0.28), bb(47) + 2, pan=0.0)
T['fx'].add(air(8*BAR, 0.05, 260, 2200), bb(41))
T['fx'].add(noise_swell(2*BAR, 0.06), bb(47))

# ---------------- mix ----------------

FX = {  # (reverb wet, delay in beats or None, level)
    'whistle': (0.34, 0.75, 1.00),
    'strings': (0.34, None, 1.10),
    'hammer':  (0.24, None, 1.10),
    'glass':   (0.48, 1.50, 1.00),
    'reed':    (0.30, None, 1.15),
    'fx':      (0.45, None, 0.80),
}

def render(name, tr):
    y = tr.out()
    wet, dl, lvl = FX[name]
    if dl: y = delay(y, dl*SPB, fb=0.30, mix=0.20)
    return reverb(y, wet)*lvl

def build(out_dir='out', loop=False, highpass=None):
    """loop=True drops the fade-out and wraps the reverb tail over the head."""
    mix, stems = master(
        {n: render(n, t) for n, t in T.items()},
        shelf=(0.28, 95), drive=1.12, peak=0.87,
        fade_in=(0.6, 1.1), fade_out=(2.6, 1.5),
        highpass=highpass,
        loop_len=int(BARS*BAR*SR) if loop else None)
    tag = '_loop' if loop else ''
    write_wav('%s/home%s.wav' % (out_dir, tag), mix)
    for n, y in stems.items():
        write_wav('%s/home_stems%s/%s.wav' % (out_dir, tag, n), y)
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
    print('home%s  %.3f s  peak %.3f' % (
        '_loop' if a.loop else '', m.shape[1]/SR, np.max(np.abs(m))))
