"""Score for "Warm Ship" -- station, refit, deck.  71 BPM, 24 bars, 81.13 s.

    python3 warm.py [--out DIR] [--loop] [--hp HZ]

The audio half of "cold universe, warm ship", rebuilt as an arrangement:
a bed that never stops, moving inner layers, and a song of its own.  Still
the only music in the game with no noise, no drums and no distortion --
that absence is what makes it read as an interior.

THE HEARTH is this cue's song and it is written around a hole: **it does not
contain a C.**  The cue's whole event is the five-note question finally
getting its fifth -- once per loop, at bars 23-24, on the glass -- and a
tune that had already sung the note four times would arrive there with
nothing to give.  So the melody works the whole warm mode except the one
pitch the cue is saving, and the first C in any voice IS the answer.

The institutions appear exactly once: a single soft FIFTH under bar 9, the
berth clamp taking hold.  You are docked at *their* station; the room is
warm because somebody's invoice says it may be.  One stamp, quiet, never
again -- planted, not the subject.

Layer map (stem names are the game's ladder and are load-bearing):

    bars   1-8   pad+fx (rung 0): the room.  glass+sub (rung 1) breathe in
                 from bar 5.  The stamp under bar 9's downbeat.
    bars   9-16  motif+arp (rung 2): circulation -- harp eighths -- and THE
                 HEARTH, first statement, low, on the glass voice.
                 bell (rung 3) doubles the song's long notes from bar 13.
    bars  17-24  lead (rung 4): THE HEARTH restated a fourth higher on the
                 whistle; bar 19 keeps the old INVERT lift (its D natural is
                 A-flat maj7's sharp 11); bars 23-24 the ANSWER -- the five
                 notes, then the C, held on the warmest voice in the set.
"""
import numpy as np
np.random.seed(1729)          # renders are deterministic
import synth; synth.set_tempo(71)
from synth import *
from motif import MOTIF, INVERT, ANSWER, FIFTH, bar as bb, octave as oc, pitches

BARS = 24

# --- harmony: bVI - bIII - bVII - i, two bars each, three cycles -------
DB7  = (['Db3', 'F3', 'Ab3', 'C4'],       'Db2')
AB7  = (['Ab2', 'C3', 'Eb3', 'G3'],       'Ab2')
EB69 = (['Eb3', 'G3', 'Bb3', 'C4', 'F4'], 'Eb2')
FM9  = (['F3', 'Ab3', 'C4', 'G4'],        'F2')
CYCLE = [DB7, AB7, EB69, FM9]

#: The song.  Eight bars, and no C anywhere in it -- see the header.
HEARTH = [('Ab4', 0, 3), ('Bb4', 3, 1), ('F4', 4, 4),
          ('G4', 8, 2), ('Ab4', 10, 2), ('Eb5', 12, 4),
          ('Db5', 16, 2), ('Bb4', 18, 2), ('G4', 20, 3), ('Ab4', 23, 1),
          ('F4', 24, 4), ('Ab4', 28, 4)]

#: The restatement, a fourth up, the top opened out.  Still no C.
HEARTH_HI = [('Db5', 0, 3), ('Eb5', 3, 1), ('Bb4', 4, 4),
             ('Db5', 8, 2), ('Eb5', 10, 2), ('Ab5', 12, 4),
             ('G5', 16, 2), ('Eb5', 18, 2), ('Db5', 20, 3), ('Eb5', 23, 1)]

T = {k: Track(BARS) for k in
     ['pad', 'glass', 'sub', 'motif', 'arp', 'bell', 'lead', 'fx']}

_pc = {}


def pk(f, d, a):
    k = (round(f, 2), round(d, 4))
    if k not in _pc:
        _pc[k] = pluck(f, d, 1.0)
    return _pc[k]*a


def chords(cycle_start):
    for c in range(4):
        v, root = CYCLE[c]
        yield cycle_start + c*2, v, root


# ============ I. DOCKED : bars 1-8 ============
T['fx'].add(air(8*BAR, 0.12, 200, 2400), bb(1))
for bar, v, root in chords(1):
    T['pad'].add(pad([hz(x) for x in v], 2*BAR, 0.32, 1700), bb(bar))
    for k in range(2):
        T['sub'].add(sub(hz(root), SPB*2.6, 0.09), bb(bar)+k*4)
    if bar >= 5:                                  # the interior breathes in
        T['glass'].add(glass(hz(v[-1])*2, 2*BAR*0.9, 0.16), bb(bar), pan=0.30)
        T['glass'].add(glass(hz(v[1])*2, 2*BAR*0.85, 0.10), bb(bar)+2, pan=-0.32)
# the motif far off, once -- the room before anyone speaks in it
for n, b, d in oc(MOTIF, 6):
    T['motif'].add(glass(hz(n), d*SPB*0.9, 0.20), bb(3)+b, pan=-0.26)
# the berth clamp: one soft stamp, and the institutions are never heard again
for n in FIFTH:
    T['sub'].add(sub(hz(n), SPB*3.2, 0.05), bb(9))

# ============ II. SYSTEMS UP : bars 9-16 ============
T['fx'].add(air(8*BAR, 0.08, 180, 2000), bb(9))
for bar, v, root in chords(9):
    T['pad'].add(pad([hz(x) for x in v], 2*BAR, 0.30, 2200), bb(bar))
    T['glass'].add(glass(hz(v[-1])*2, 2*BAR*0.9, 0.12), bb(bar), pan=0.34)
    for k in range(4):
        T['sub'].add(sub(hz(root), SPB*1.7, 0.12), bb(bar)+k*2)
    order = [0, 1, 2, 1, 2, 3]                    # circulation, rising
    for s in range(16):
        f = hz(v[order[s % 6] % len(v)])*2
        T['arp'].add(pk(f, 0.55, 0.12), bb(bar)+s*0.5,
                     pan=-0.40 + 0.8*((s % 4)/3))
for n, b, d in HEARTH:                            # the song, low and plain
    T['motif'].add(glass(hz(n), d*SPB*0.94, 0.22), bb(9)+b, pan=0.10)
for n, b, d in HEARTH:                            # long notes ring from 13
    if d >= 4 and b >= 16:
        T['bell'].add(bell(hz(n)*2, d*SPB*1.5, 0.13), bb(9)+b, pan=0.42)

# ============ III. THE ANSWER : bars 17-24 ============
T['fx'].add(air(8*BAR, 0.09, 160, 1800), bb(17))
for bar, v, root in chords(17):
    T['pad'].add(pad([hz(x) for x in v], 2*BAR, 0.32, 2800), bb(bar))
    T['glass'].add(glass(hz(v[-1])*2, 2*BAR*0.9, 0.14), bb(bar), pan=0.30)
    for k in range(8):
        T['sub'].add(sub(hz(root), SPB*0.95, 0.13), bb(bar)+k)
    order = [0, 2, 1, 3, 2, 1]
    for s in range(16):
        f = hz(v[order[s % 6] % len(v)])*2
        T['arp'].add(pk(f, 0.50, 0.13), bb(bar)+s*0.5,
                     pan=0.40 - 0.8*((s % 4)/3))
for n, b, d in HEARTH_HI:                         # the song, opened out
    T['lead'].add(whistle(hz(n), d*SPB*0.94, 0.36), bb(17)+b, pan=-0.10)
for n, b, d in HEARTH_HI:
    if d >= 4:
        T['bell'].add(bell(hz(n)*2, d*SPB*1.5, 0.14), bb(17)+b, pan=0.44)
# The Lydian lift, kept -- but on the GLASS, not the lead: at bar 19 the
# lead is mid-phrase in HEARTH_HI, and one instrument playing two tunes at
# once is the collision the score sheet made visible.
for n, b, d in oc(INVERT, 5):
    T['motif'].add(glass(hz(n), d*SPB*0.94, 0.20), bb(19)+b, pan=0.30)
for n, b, d in oc(ANSWER, 5):                     # the five notes, then the C
    T['lead'].add(whistle(hz(n), d*SPB*0.94, 0.42), bb(23)+b, pan=-0.08)
T['motif'].add(glass(hz('C6'), 3.2, 0.20), bb(23)+5, pan=0.0)
T['fx'].add(noise_swell(2*BAR, 0.07), bb(23))

# ---------------- mix ----------------
# Wettest cue in the set: a hull interior is small, but reverb here is
# comfort rather than distance, so the tails are long and the top is soft.
FX = {'pad':   (0.55, None, 1.00), 'glass': (0.60, 1.50, 0.95),
      'sub':   (0.10, None, 1.05), 'motif': (0.55, None, 1.00),
      'arp':   (0.45, 0.75, 0.90), 'bell':  (0.58, 1.50, 0.90),
      'lead':  (0.50, 0.75, 1.00), 'fx':    (0.55, None, 0.85)}


def render(name, tr):
    y = tr.out()
    wet, dl, lvl = FX[name]
    if dl:
        y = delay(y, dl*SPB, fb=0.28, mix=0.18)
    return reverb(y, wet)*lvl


def build(out_dir='out', loop=False, highpass=None):
    mix, stems = master(
        {n: render(n, t) for n, t in T.items()},
        shelf=(0.26, 90), drive=1.08, peak=0.84,
        fade_in=(0.8, 1.1), fade_out=(2.8, 1.5),
        highpass=highpass,
        loop_len=int(BARS*BAR*SR) if loop else None)
    tag = '_loop' if loop else ''
    write_wav('%s/warm%s.wav' % (out_dir, tag), mix)
    for n, y in stems.items():
        write_wav('%s/warm_stems%s/%s.wav' % (out_dir, tag, n), y)
    return mix, stems


if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', default='out')
    ap.add_argument('--loop', action='store_true')
    ap.add_argument('--hp', type=float, default=None)
    a = ap.parse_args()
    m, _ = build(a.out, loop=a.loop, highpass=a.hp)
    print('warm%s  %.3f s  peak %.3f' % ('_loop' if a.loop else '',
                                         m.shape[1]/SR, np.max(np.abs(m))))
