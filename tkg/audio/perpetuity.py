"""Score for "Perpetuity" -- the archive, the institutions.  71 BPM, 48 bars,
162.25 s.

    python3 perpetuity.py [--out DIR] [--loop] [--hp HZ]

The word is Verity's: *"We repair what we sold you. Forever."* -- the
warranty clause drafted by people who knew what the sky was doing.  This is
the eternal things' own music, and its home is the archive reading room,
where the player reads their paperwork.

The first version was a passacaglia-and-fugue for full organ -- an
experiment in registration that came out busy and over the top, which is
everything an institution is not.  An institution is PATIENT.  So the form
keeps the one idea that was right -- a ground bass, because a line that
repeats forever without needing anyone is what perpetuity *is* -- and
discards the fugue, the stretto, and the plenum.  The organ remains as one
voice: the bed, quiet, the institution breathing under everything.  The
other layers are the album's own palette passing through the file room.

The cast, in their own piece:

  * THE FIFTH is structural, not planted: the ground CADENCES onto the bare
    open fifth at the end of every statement -- six receipts, one per cycle.
    And the piece ends there: no Picardy this time, no arrival, just the
    empty perfect interval held and the loop wrapping.  Perpetuity does not
    end.  It continues.
  * THE LOOP ticks from statement III onward, indifferent.
  * THE QUESTION passes exactly once, on the reed, quietly, mid-piece --
    a person in the file, processed without comment.
  * THE LAMENT passes once in the strings, late -- the file has deaths in
    it, and they are filed too.

Layer map (change one thing per 8-bar statement):

    I    (1-8)    the ground alone: organ, 16'+8'.  The organ carries the
                  main line the whole piece; everything else visits.
    II   (9-16)   + strings: soft sustained chords, the breathing
    III  (17-24)  + THE LOOP + harp arpeggios (the file room at work)
    IV   (25-32)  + glass descant (pages turning); THE QUESTION once, reed
    V    (33-40)  fullest, still modest: bell doubles the descant;
                  THE LAMENT passes, bowed
    VI   (41-48)  strip: organ ground, tick, and the bare fifth held
"""
import numpy as np
np.random.seed(1729)          # renders are deterministic
import synth; synth.set_tempo(71)
from synth import *
from motif import (MOTIF, LAMENT, FIFTH, bar as bb, octave as oc,
                   pitches, augment, loop_beats)

BARS = 48

T = {k: Track(BARS) for k in
     ['pedal', 'harmony', 'arps', 'descant', 'stamp', 'fx']}

_c = {}


def og(f, d, a, br=0.8):
    k = (round(f, 2), round(d, 3), br)
    if k not in _c:
        _c[k] = organ(f, d, 1.0, br)
    return _c[k]*a


#: The ground.  Eight bars, 32 beats.  Opens with the motif's oscillation in
#: the bass -- the one place in the soundtrack the phrase is load-bearing --
#: walks down the flat side, and lands on the bottom of an open fifth, which
#: the stamp completes.  Six times.  It does not develop.
GROUND = [('F2', 0, 4), ('G2', 4, 4),
          ('Ab2', 8, 4), ('Db2', 12, 4),
          ('Bb1', 16, 4), ('Ab1', 20, 4),
          ('C2', 24, 4), ('F1', 28, 4)]

#: The manual's harmony, one soft chord per four bars.  Modal, no dominant.
CHORDS = [(0, ['F3', 'Ab3', 'C4']), (16, ['Db3', 'F3', 'Ab3'])]

#: The descant: this piece's own line, glass, unhurried.  Not the motif --
#: it moves by step around the fifth the ground keeps landing on, the way an
#: eye moves down a page.
DESCANT = [('C5', 0, 6), ('Db5', 6, 2),
           ('C5', 8, 4), ('Ab4', 12, 4),
           ('Bb4', 16, 6), ('G4', 22, 2),
           ('Ab4', 24, 4), ('C5', 28, 4)]


def ground(bar0, amp):
    for n, b, d in GROUND:
        T['pedal'].add(og(hz(n), d*SPB*0.99, amp), bb(bar0)+b)
        T['pedal'].add(og(hz(n)*0.5, d*SPB*0.99, amp*0.55), bb(bar0)+b)


_pc = {}


def pk(f, d, a):
    k = (round(f, 2), round(d, 3))
    if k not in _pc:
        _pc[k] = pluck(f, d, 1.0)
    return _pc[k]*a


def breath(bar0, amp):
    """The strings' soft chords, one per four bars -- the breathing that
    used to be a second organ manual and read as more of the same."""
    for b0, v in CHORDS:
        T['harmony'].add(strings([hz(x) for x in v], 4*4*SPB*0.98, amp,
                                 1900, 0.9), bb(bar0) + b0, pan=0.10)


def filework(bar0, n_bars, amp):
    """Harp eighths over the ground's own pitches -- the file room at
    work.  Sparse: four notes a bar, not a moto perpetuo."""
    order = [0, 2, 1, 2]
    for i in range(n_bars):
        v = CHORDS[0][1] if (i // 4) % 2 == 0 else CHORDS[1][1]
        for k in range(4):
            f = hz(v[order[k]])*2
            T['arps'].add(pk(f, 0.7, amp), bb(bar0+i) + k,
                          pan=-0.30 + 0.20*(k % 3))


def stamp(bar0, amp=0.20):
    """The receipt: the bare fifth, at the last bar of a statement."""
    for n in FIFTH:
        T['stamp'].add(hammer(hz(n), 3.2*SPB, amp, 0.8), bb(bar0+7), pan=-0.05)


# ---- I : the ground alone ---------------------------------------------
ground(1, 0.22)
stamp(1, 0.16)
T['fx'].add(air(16*BAR, 0.05, 90, 900), bb(1))

# ---- II : the breathing -----------------------------------------------
ground(9, 0.23)
stamp(9, 0.18)
breath(9, 0.12)

# ---- III : pages turning ----------------------------------------------
ground(17, 0.24)
stamp(17, 0.19)
breath(17, 0.13)
filework(17, 8, 0.075)
_tick = bell(hz('F6'), 1.6, 1.0)
for b in loop_beats(3.0, 30*4):
    T['fx'].add(_tick*0.038, bb(17) + b, pan=-0.32)

# ---- IV : a person in the file ----------------------------------------
ground(25, 0.24)
stamp(25, 0.20)
breath(25, 0.13)
filework(25, 8, 0.07)
for n, b, d in DESCANT:
    T['descant'].add(glass(hz(n), d*SPB*0.95, 0.19), bb(25)+b, pan=0.22)
for n, b, d in augment(pitches(MOTIF, 'F4'), 2):
    T['descant'].add(reed(hz(n), d*SPB*0.94, 0.13), bb(27)+b, pan=0.32)

# ---- V : the file has deaths in it ------------------------------------
ground(33, 0.25)
stamp(33, 0.21)
breath(33, 0.14)
filework(33, 8, 0.08)
for n, b, d in DESCANT:
    T['descant'].add(glass(hz(n), d*SPB*0.95, 0.19), bb(33)+b, pan=0.20)
    if d >= 4:
        T['descant'].add(bell(hz(n)*2, d*SPB*1.4, 0.09), bb(33)+b, pan=0.36)
for n, b, d in augment(oc(LAMENT, 3), 2):
    T['harmony'].add(bowed(hz(n), d*SPB*0.95, 0.13, 2.2), bb(35)+b, pan=-0.22)

# ---- VI : strip.  The fifth, held. ------------------------------------
ground(41, 0.23)
breath(41, 0.08)
# the last receipt is not struck -- it is HELD: the open fifth on the organ,
# four bars, and the loop wraps out of it back into the ground.
for n in FIFTH:
    T['stamp'].add(og(hz(n), 4*4*SPB*0.98, 0.16), bb(45), pan=-0.04)
T['fx'].add(air(8*BAR, 0.05, 80, 800), bb(41))

# ---------------- mix ----------------
FX = {'pedal':   (0.30, None, 1.05), 'harmony': (0.48, None, 0.95),
      'arps':    (0.42, 1.5, 0.90), 'descant': (0.52, 1.5, 0.98),
      'stamp':   (0.35, None, 1.00), 'fx':     (0.50, None, 0.90)}


def render(name, tr):
    y = tr.out()
    wet, dl, lvl = FX[name]
    if dl:
        y = delay(y, dl*SPB, fb=0.26, mix=0.15)
    return reverb(y, wet)*lvl


def build(out_dir='out', loop=False, highpass=None):
    mix, stems = master(
        {n: render(n, t) for n, t in T.items()},
        shelf=(0.24, 82), drive=1.05, peak=0.80,
        fade_in=(1.0, 1.1), fade_out=(3.0, 1.5),
        highpass=highpass,
        loop_len=int(BARS*BAR*SR) if loop else None)
    tag = '_loop' if loop else ''
    write_wav('%s/perpetuity%s.wav' % (out_dir, tag), mix)
    for n, y in stems.items():
        write_wav('%s/perpetuity_stems%s/%s.wav' % (out_dir, tag, n), y)
    return mix, stems


if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', default='out')
    ap.add_argument('--loop', action='store_true')
    ap.add_argument('--hp', type=float, default=None)
    a = ap.parse_args()
    m, _ = build(a.out, loop=a.loop, highpass=a.hp)
    print('perpetuity%s  %.3f s  peak %.3f' % ('_loop' if a.loop else '',
                                               m.shape[1]/SR, np.max(np.abs(m))))
