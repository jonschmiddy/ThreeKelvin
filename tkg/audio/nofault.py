"""Score for "No Fault Found" -- the end of a run.  71 BPM, 24 bars, 81.1 s.

    python3 nofault.py [--out DIR] [--loop] [--hp HZ]

Death as the lore writes it: processed.  Still short, still unmoved -- but a
piece now, not a gesture.  Its melody is THE FILING: the lament's four-note
fall used as a seed and sequenced, each phrase starting a step lower than
the last, a compound descent that takes twelve bars to reach the C the
question never touched.  The answer, arrived at by falling, in this cue's
own handwriting.

Layer map:

    bars   1-8    bed: pedal + the toll (bell, every 3 beats -- THE LOOP as
                  a funeral device) + THE FILING, first descent, glass
    bars   9-16   + chorale (strings, the lament harmonised) + the descent
                  an octave lower, bowed + the question once, reed, filed
    bars  17-24   the stamps: THE FIFTH twice -- the receipt.  Everything
                  human stops at bar 22; the toll keeps its schedule into
                  the silence and is cut mid-cell.  End on business.
"""
import numpy as np
np.random.seed(1729)          # renders are deterministic
import synth; synth.set_tempo(71)
from synth import *
from motif import (MOTIF, LAMENT, FIFTH, bar as bb, octave as oc,
                   pitches, augment, loop_beats)

BARS = 24

T = {k: Track(BARS) for k in ['pedal', 'toll', 'filing', 'chorale',
                              'stamp', 'fx']}

#: The filing: the lament shape (down four steps) sequenced from three
#: starting heights.  Twelve bars.  Each phrase is the seed a step lower,
#: and the last one lands on C and stays there.
FILING = [
    ('F5', 0, 2), ('Eb5', 2, 2), ('Db5', 4, 2), ('C5', 6, 2),
    ('Eb5', 8, 2), ('Db5', 10, 2), ('C5', 12, 2), ('Bb4', 14, 2),
    ('Db5', 16, 2), ('C5', 18, 2), ('Bb4', 20, 2), ('Ab4', 22, 2),
    ('Bb4', 24, 2), ('Ab4', 26, 2), ('G4', 28, 2), ('C5', 30, 10),
]

#: The chorale under the second block: the lament harmonised in three
#: voices, one chord per two bars.
CHORALE = [(0, ['F3', 'Ab3', 'C4']), (8, ['Eb3', 'G3', 'Bb3']),
           (16, ['Db3', 'F3', 'Ab3']), (24, ['C3', 'E3', 'G3'])]

# ---- bed --------------------------------------------------------------
T['pedal'].add(drone(hz('F1'), 21*BAR, 0.42, 75, 130), bb(1))
T['fx'].add(air(12*BAR, 0.05, 80, 800), bb(1))
_toll = bell(hz('F5'), 2.2, 1.0)
for b in loop_beats(3.0, 21*4):                    # the toll, to the cut
    T['toll'].add(_toll*0.075, bb(1) + b, pan=0.18)

# ---- I : the filing, glass --------------------------------------------
for n, b, d in FILING:
    T['filing'].add(glass(hz(n), d*SPB*0.95, 0.24), bb(2)+b, pan=0.10)

# ---- II : chorale + the octave-down descent + the question ------------
for b0, v in CHORALE:
    T['chorale'].add(strings([hz(x) for x in v], 2*BAR, 0.16, 2000, 0.5),
                     bb(9) + b0, pan=-0.12)
for n, b, d in FILING[:12]:
    T['filing'].add(bowed(hz(n)*0.5, d*SPB*0.95, 0.17, 2.4), bb(10)+b,
                    pan=-0.20)
Q = augment(pitches(MOTIF, 'F4'), 2)
Q[-1] = (Q[-1][0], Q[-1][1], Q[-1][2] + 1)         # the pen rests
for n, b, d in Q:
    T['filing'].add(reed(hz(n), d*SPB*0.94, 0.13), bb(13)+b, pan=0.28)

# ---- III : the stamps, and the cut ------------------------------------
for bar in (17, 20):
    for n in FIFTH:
        T['stamp'].add(hammer(hz(n), 3.0*SPB, 0.30, 0.85), bb(bar), pan=-0.06)
T['filing'].add(glass(hz('C5'), 4*BAR, 0.18), bb(19), pan=0.08)   # the answer,
                                                                  # held to the stop
# bars 22-24: the toll alone, cut mid-cell by the end of the piece.

# ---------------- mix ----------------
FX = {'pedal': (0.22, None, 1.05), 'toll': (0.45, None, 0.95),
      'filing': (0.50, None, 1.00), 'chorale': (0.48, None, 0.95),
      'stamp': (0.30, None, 1.00), 'fx': (0.45, None, 0.90)}


def render(name, tr):
    y = tr.out()
    wet, dl, lvl = FX[name]
    if dl:
        y = delay(y, dl*SPB, fb=0.28, mix=0.16)
    return reverb(y, wet)*lvl


def build(out_dir='out', loop=False, highpass=None):
    mix, stems = master(
        {n: render(n, t) for n, t in T.items()},
        shelf=(0.24, 85), drive=1.05, peak=0.80,
        fade_in=(0.4, 1.0), fade_out=(2.0, 1.4),
        highpass=highpass,
        loop_len=int(BARS*BAR*SR) if loop else None)
    tag = '_loop' if loop else ''
    write_wav('%s/nofault%s.wav' % (out_dir, tag), mix)
    for n, y in stems.items():
        write_wav('%s/nofault_stems%s/%s.wav' % (out_dir, tag, n), y)
    return mix, stems


if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', default='out')
    ap.add_argument('--loop', action='store_true')
    ap.add_argument('--hp', type=float, default=None)
    a = ap.parse_args()
    m, _ = build(a.out, loop=a.loop, highpass=a.hp)
    print('nofault%s  %.3f s  peak %.3f' % ('_loop' if a.loop else '',
                                            m.shape[1]/SR, np.max(np.abs(m))))
