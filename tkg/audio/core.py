"""Score for "The Last Warm Place" -- the core.  71 BPM, 48 bars, 162.3 s.

    python3 core.py [--out DIR] [--loop] [--hp HZ]

The finale.  Built the way a game finale is actually built -- a bed that
never stops, an ostinato that gives it a pulse, and layers that enter and
leave on eight-bar blocks -- rather than as an ambience with quotations in
it, which is what the first version was.

THE THEME is this cue's own and does the one thing no other melody in the
game is allowed to do: it reaches both answers.  Its first phrase opens with
the motif's rise (1-2-b3 as a springboard, not a quotation) and lands on
**C6** -- the true answer, in the melody, for the first time anywhere.  Its
second phrase makes the identical approach and lands on **B5** -- the false
one.  Same gesture, two destinations, and the phrase ends hanging on the 2.
The question could never touch the fifth; the core's own theme touches both
of them and cannot choose.  That is the design doc's unanswerable ruling as
a tune.

The two answers also arrive HARMONICALLY in their own voices -- the C on
glass ("Warm Ship"), the B on bowed strings ("Poisoned Ground") -- under the
theme's second statement, so melody and harmony disagree about the same two
notes at the same time.

Layer map, one entry per 8-bar block (the Halo discipline: change ONE thing
per block, in and out are both events):

    bars   1-8    bed: pedal, air, THE LOOP (3-beat tick, indifferent)
    bars   9-16   + ostinato (low fortepiano eighths) + pulse (heart)
    bars  17-24   + THE THEME, first statement + soft kit
    bars  25-32   + the answers (glass C, bowed B) under the theme
    bars  33-40   full: theme doubled 8va, counterline, kit opens up
    bars  41-48   strip, one layer per two bars; the loop is last out
"""
import numpy as np
np.random.seed(1729)          # renders are deterministic
import synth; synth.set_tempo(71)
from synth import *
from motif import bar as bb, loop_beats

BARS = 48

T = {k: Track(BARS) for k in
     ['pedal', 'loop', 'ost', 'perc', 'theme', 'answers', 'fx']}

_h, _cache = {}, {}


def hm(f, d, a, br=0.9):
    k = (round(f, 2), round(d, 3), br)
    if k not in _h:
        _h[k] = hammer(f, d, 1.0, br)
    return _h[k]*a


#: This cue's own theme.  16 bars, 64 beats.  Phrase 1 lands on C, phrase 2
#: on B natural, coda hangs on G -- see the header.
THEME = [
    ('F5', 0, 2), ('G5', 2, 1), ('Ab5', 3, 1),        # the motif's rise, as
    ('C6', 4, 4),                                     # a springboard -> C
    ('Bb5', 8, 2), ('Ab5', 10, 2), ('G5', 12, 3), ('F5', 15, 1),
    ('F5', 16, 2), ('G5', 18, 1), ('Ab5', 19, 1),     # same approach
    ('B5', 20, 4),                                    # -> B natural
    ('C6', 24, 2), ('B5', 26, 2),                     # the argument, stated
    ('G5', 28, 4),                                    # and left hanging
    ('Ab5', 32, 2), ('Bb5', 34, 2), ('C6', 36, 4),    # second half: higher
    ('Db6', 40, 2), ('C6', 42, 2), ('B5', 44, 2), ('C6', 46, 2),
    ('G5', 48, 6), ('F5', 54, 6),                     # long fall home
]

#: Ostinato, one bar of eighths, F minor with the flat 7 passing.
OST = ['F2', 'F3', 'C3', 'F2', 'Eb3', 'F3', 'C3', 'Eb2']


def ost_bar(bar, amp):
    for i, n in enumerate(OST):
        T['ost'].add(hm(hz(n), 0.62, amp, 0.85), bb(bar) + i*0.5,
                     pan=-0.12 + 0.04*(i % 3))


def kit(bar, lvl=1.0, full=False):
    T['perc'].add(kick(0.40*lvl), bb(bar))
    T['perc'].add(kick(0.26*lvl), bb(bar)+2.5)
    if full:
        T['perc'].add(kick(0.30*lvl), bb(bar)+3.5)
        T['perc'].add(snare(0.16*lvl), bb(bar)+2)


def sing(notes, bar0, amp, voice, pan=0.0, mul=1.0, oct_=0):
    for n, b, d in notes:
        f = hz(n)*(2**oct_)
        T['theme'].add(voice(f, d*SPB*0.96*mul, amp), bb(bar0)+b, pan=pan)


# ---- bed: the whole piece ---------------------------------------------
for b0 in range(1, BARS, 8):
    T['pedal'].add(drone(hz('F1'), 8*BAR, 0.52, 76, 150), bb(b0))
T['fx'].add(air(16*BAR, 0.05, 60, 800), bb(1))
T['fx'].add(air(16*BAR, 0.05, 60, 1000), bb(17))
T['fx'].add(air(16*BAR, 0.05, 60, 900), bb(33))
_tick = bell(hz('F6'), 1.6, 1.0)
for i, b in enumerate(loop_beats(3.0, BARS*4)):
    T['loop'].add(_tick*0.05, bb(1) + b, pan=0.30 if i % 2 else -0.30)

# ---- block II : ostinato + pulse --------------------------------------
for bar in range(9, 17):
    ost_bar(bar, 0.16)
for bar in range(9, 17, 2):
    T['perc'].add(heart(0.22), bb(bar))

# ---- block III : the theme --------------------------------------------
for bar in range(17, 25):
    ost_bar(bar, 0.18)
    kit(bar, 0.8)
sing(THEME[:14], 17, 0.34, whistle, pan=-0.10)      # first 8 bars of it
for bar in range(17, 25, 2):
    T['perc'].add(heart(0.24), bb(bar))

# ---- block IV : the answers -------------------------------------------
T['fx'].add(impact(0.45, 4.0), bb(25))
T['answers'].add(glass(hz('C5'), 8*BAR, 0.24), bb(25), pan=0.20)
T['answers'].add(bowed(hz('B3'), 8*BAR, 0.20, 2.6), bb(27), pan=-0.24)
for bar in range(25, 33):
    ost_bar(bar, 0.18)
    kit(bar, 0.9)
# THEME's entries carry absolute beats, so the second half must be
# re-zeroed before placing -- without this it landed at bar 33 on top of
# block V's statement, and bars 25-32 had answers with no theme over them.
# Found by LOOKING at the score sheet; every numeric check missed it.
sing([(n, b - 32, d) for n, b, d in THEME[14:]], 25, 0.36, whistle, pan=-0.08)

# ---- block V : full ---------------------------------------------------
T['fx'].add(impact(0.60, 4.5), bb(33))
T['answers'].add(glass(hz('C5'), 8*BAR, 0.28), bb(33), pan=0.22)
T['answers'].add(bowed(hz('B3'), 8*BAR, 0.24, 2.8), bb(33), pan=-0.26)
T['answers'].add(bowed(hz('B4'), 6*BAR, 0.11, 3.0), bb(35), pan=-0.32)
for bar in range(33, 41):
    ost_bar(bar, 0.20)
    kit(bar, 1.0, full=True)
sing(THEME[:14], 33, 0.38, whistle, pan=-0.12)
sing(THEME[:14], 33, 0.15, whistle, pan=0.30, oct_=1)          # doubled 8va
for n, b, d in THEME[:14]:                                     # counterline:
    if d >= 3:                                                 # long notes on
        T['answers'].add(reed(hz(n)*0.5, d*SPB*0.94, 0.16), bb(33)+b, pan=0.30)

# ---- block VI : strip, one layer per two bars -------------------------
for bar in range(41, 45):
    ost_bar(bar, 0.15)
kit(41, 0.6)
sing([('C6', 0, 4), ('B5', 4, 4), ('G5', 8, 6)], 41, 0.28, whistle, pan=0.0)
T['answers'].add(glass(hz('C5'), 4*BAR, 0.18), bb(41), pan=0.18)
T['answers'].add(bowed(hz('B3'), 4*BAR, 0.15, 2.4), bb(41), pan=-0.20)
# bars 45-48: pedal and loop only.  The loop was here first and leaves last.

# ---------------- mix ----------------
FX = {'pedal': (0.20, None, 1.05), 'loop': (0.55, 1.5, 0.95),
      'ost':   (0.30, None, 1.00), 'perc': (0.18, None, 1.00),
      'theme': (0.48, 0.75, 1.00), 'answers': (0.55, None, 1.00),
      'fx':    (0.50, None, 0.85)}


def render(name, tr):
    y = tr.out()
    wet, dl, lvl = FX[name]
    if dl:
        y = delay(y, dl*SPB, fb=0.30, mix=0.18)
    return reverb(y, wet)*lvl


def build(out_dir='out', loop=False, highpass=None):
    mix, stems = master(
        {n: render(n, t) for n, t in T.items()},
        shelf=(0.22, 80), drive=1.08, peak=0.86,
        fade_in=(1.2, 1.2), fade_out=(3.6, 1.6),
        highpass=highpass,
        loop_len=int(BARS*BAR*SR) if loop else None)
    tag = '_loop' if loop else ''
    write_wav('%s/core%s.wav' % (out_dir, tag), mix)
    for n, y in stems.items():
        write_wav('%s/core_stems%s/%s.wav' % (out_dir, tag, n), y)
    return mix, stems


if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', default='out')
    ap.add_argument('--loop', action='store_true')
    ap.add_argument('--hp', type=float, default=None)
    a = ap.parse_args()
    m, _ = build(a.out, loop=a.loop, highpass=a.hp)
    print('core%s  %.3f s  peak %.3f' % ('_loop' if a.loop else '',
                                         m.shape[1]/SR, np.max(np.abs(m))))
