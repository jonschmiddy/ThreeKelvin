"""Score for "The Warm Things" -- megafauna.  71 BPM, 40 bars, 135.2 s.

    python3 fauna.py [--out DIR] [--loop] [--hp HZ]

The one cue that is warm toward something that is not the ship.  It owns a
SONG -- a real melody unique to this piece, opening on a minor-sixth leap,
which is a whale's interval and a gesture the five-note question cannot
make.  The motif appears exactly once, and it is the point when it does:
midway through, the whale sings THE PLAYER'S TUNE -- augmented four times,
bent like song, two octaves down -- while this cue's own melody keeps going
above it.  You hear your own phrase inside something enormous and realise
you are the same kind of animal.  That is the design doc's cruellest joke,
scored.

Layer map (change one thing per block):

    bars   1-8    bed: water pad, sub, the pulse (heart every 2 bars)
    bars   9-16   + harp arpeggios (the water moving) + THE SONG, reed
    bars  17-24   + the whale: THE MOTIF at whale size, under everything
    bars  25-32   full: song doubled on whistle 8va, glass long notes
    bars  33-40   ebb: arps thin, song falls to its last phrase --
                  and THE LOOP fades in, very quiet.  A schedule, arriving.
                  The warm things are hunted; the music knows first.

No metal anywhere, and no FIFTH: the institutions have no voice here until
that tick.
"""
import numpy as np
np.random.seed(1729)          # renders are deterministic
import synth; synth.set_tempo(71)
from synth import *
from motif import MOTIF, bar as bb, pitches, augment, loop_beats

BARS = 40

T = {k: Track(BARS) for k in ['water', 'arps', 'song', 'whale', 'pulse', 'fx']}

_p = {}


def pk(f, d, a):
    k = (round(f, 2), round(d, 3))
    if k not in _p:
        _p[k] = pluck(f, d, 1.0)
    return _p[k]*a


#: The song.  16 bars, 64 beats.  Opens with the minor-sixth leap, falls
#: back by step, and its second half turns the leap into an octave.
SONG = [
    ('F4', 0, 2), ('Db5', 2, 3), ('C5', 5, 1),        # the leap, and back
    ('Ab4', 6, 2), ('Bb4', 8, 3), ('G4', 11, 1), ('Ab4', 12, 4),
    ('F4', 16, 2), ('Db5', 18, 2), ('Eb5', 20, 2), ('C5', 22, 2),
    ('Bb4', 24, 3), ('Ab4', 27, 1), ('Bb4', 28, 4),
    ('F4', 32, 2), ('F5', 34, 4),                     # the leap, grown
    ('Eb5', 38, 2), ('C5', 40, 2), ('Db5', 42, 3), ('Ab4', 45, 1),
    ('Bb4', 46, 2), ('C5', 48, 4),                    # rests on the air
    ('Ab4', 52, 2), ('G4', 54, 2), ('F4', 56, 8),     # long home
]

#: The whale's statement of the question: x4, bent, deep.
WHALE = augment(pitches(MOTIF, 'F3'), 4)

# --- harmony: two chords, four bars each -------------------------------
DB = ['Db3', 'F3', 'Ab3', 'C4']
FM9 = ['F3', 'Ab3', 'C4', 'G4']
PLAN = [(b, DB if (b//4) % 2 == 0 else FM9) for b in range(0, BARS*4, 16)]


def bed(bar0, n_bars, amp):
    for i in range(0, n_bars, 4):
        v = DB if (i//4) % 2 == 0 else FM9
        T['water'].add(pad([hz(x) for x in v], 4*BAR, amp, 1500), bb(bar0+i))
        T['water'].add(sub(hz(v[0][:-1] + '1'), 4*BAR*0.96, 0.15), bb(bar0+i))


def arps(bar0, n_bars, amp, dens=2):
    """Rising-falling harp over the chord: the water moving."""
    for i in range(n_bars):
        v = DB if ((bar0 - 1 + i)//4) % 2 == 0 else FM9
        order = [0, 1, 2, 3, 2, 1]
        for s_ in range(4*dens):
            f = hz(v[order[s_ % 6]])*2
            T['arps'].add(pk(f, 0.8, amp), bb(bar0+i) + s_/dens,
                          pan=-0.38 + 0.76*((s_ % 6)/5.0))


def sing(notes, bar0, amp, voice, pan=0.0, oct_=0, track='song'):
    for n, b, d in notes:
        T[track].add(voice(hz(n)*(2**oct_), d*SPB*0.96, amp), bb(bar0)+b,
                     pan=pan)


# ---- bed, whole piece -------------------------------------------------
bed(1, BARS, 0.24)
T['fx'].add(air(20*BAR, 0.07, 100, 1100), bb(1))
T['fx'].add(air(20*BAR, 0.06, 90, 1000), bb(21))
for i, bar in enumerate(range(1, BARS, 2)):
    T['pulse'].add(heart(0.15 + 0.02*(9 <= bar <= 32)), bb(bar))

# ---- II : the water moves, and the song begins ------------------------
arps(9, 8, 0.085)
sing(SONG[:7], 9, 0.26, reed, pan=0.16)

# ---- III : the whale --------------------------------------------------
for n, b, d in WHALE:
    T['whale'].add(whistle_bend(hz(n), d*SPB*0.96, 0.28, -14), bb(17)+b,
                   pan=-0.20)
    T['whale'].add(whistle_bend(hz(n)*0.5, d*SPB*0.96, 0.12, -20), bb(17)+b,
                   pan=0.24)
arps(17, 8, 0.08)
# Slices of SONG carry absolute beats and must be re-zeroed at placement.
# Without this every statement after the first landed 4-8 bars late and
# stacked at the end of the piece -- found by looking at the score sheet.
sing([(n, b - 16, d) for n, b, d in SONG[7:14]], 17, 0.27, reed, pan=0.18)

# ---- IV : full --------------------------------------------------------
arps(25, 8, 0.10, dens=3)
S3 = [(n, b - 32, d) for n, b, d in SONG[14:]]
sing(S3, 25, 0.28, reed, pan=0.16)
sing(S3, 25, 0.16, whistle, pan=-0.22, oct_=1)                 # doubled 8va
for n, b, d in S3:
    if d >= 4:
        T['whale'].add(glass(hz(n)*2, d*SPB*0.95, 0.10), bb(25)+b, pan=0.30)

# ---- V : ebb, and the schedule ----------------------------------------
arps(33, 4, 0.06)
sing([(n, b - 52, d) for n, b, d in SONG[-4:]], 33, 0.24, reed, pan=0.10)
for n, b, d in WHALE[:3]:                              # the whale, receding
    T['whale'].add(whistle_bend(hz(n)*0.5, d*SPB*0.96, 0.10, -24), bb(35)+b,
                   pan=0.20)
_tick = bell(hz('F6'), 1.4, 1.0)
for b in loop_beats(3.0, 14.0):
    T['fx'].add(_tick*0.028, bb(37) + b, pan=0.32)

# ---------------- mix ----------------
FX = {'water': (0.55, None, 1.00), 'arps': (0.45, 0.75, 0.95),
      'song':  (0.46, None, 1.00), 'whale': (0.58, None, 1.05),
      'pulse': (0.30, None, 0.95), 'fx': (0.50, None, 0.85)}


def render(name, tr):
    y = tr.out()
    wet, dl, lvl = FX[name]
    if dl:
        y = delay(y, dl*SPB, fb=0.28, mix=0.16)
    return reverb(y, wet)*lvl


def build(out_dir='out', loop=False, highpass=None):
    mix, stems = master(
        {n: render(n, t) for n, t in T.items()},
        shelf=(0.24, 85), drive=1.06, peak=0.84,
        fade_in=(1.0, 1.1), fade_out=(3.0, 1.5),
        highpass=highpass,
        loop_len=int(BARS*BAR*SR) if loop else None)
    tag = '_loop' if loop else ''
    write_wav('%s/fauna%s.wav' % (out_dir, tag), mix)
    for n, y in stems.items():
        write_wav('%s/fauna_stems%s/%s.wav' % (out_dir, tag, n), y)
    return mix, stems


if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', default='out')
    ap.add_argument('--loop', action='store_true')
    ap.add_argument('--hp', type=float, default=None)
    a = ap.parse_args()
    m, _ = build(a.out, loop=a.loop, highpass=a.hp)
    print('fauna%s  %.3f s  peak %.3f' % ('_loop' if a.loop else '',
                                          m.shape[1]/SR, np.max(np.abs(m))))
