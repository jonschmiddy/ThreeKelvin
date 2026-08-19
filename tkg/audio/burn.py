"""Score for "Hard Burn" -- the combat cue.

    python3 burn.py [--out DIR] [--loop] [--hp HZ]
"""
import numpy as np
np.random.seed(1729)          # renders are deterministic
import synth; synth.set_tempo(142)
from synth import *
from motif import MOTIF, bar as bb, octave as oc, diminish

# =====================================================================
#  "HARD BURN"  -  142 BPM, F Aeolian.  48 bars, 81.13 s.
#
#  Same tempo as "Slow Drift", so combat is a change of arrangement and
#  never a change of clock.  The motif is not restated over a faster
#  backing -- it *becomes* the backing.  diminish() halves it, which puts
#  the five-note cell in 3 beats against a 4/4 bar: it realigns only every
#  three bars, so the engine under a fight is the melody, running at a
#  metre that will not sit still.
#
#  This is the one cue with distortion on it (blade()).  Everywhere else
#  the ship is a small warm thing in a cold frame; in a fight it is loud.
# =====================================================================

BARS = 48

# --- harmony ---------------------------------------------------------
# i - bVII - bVI - bVII, one bar each: twice the theme's harmonic rate, and
# no iv, so the cycle never gets the moment of rest the main theme has.
FM = ['F3', 'Ab3', 'C4']
EB = ['Eb3', 'G3', 'Bb3']
DB = ['Db3', 'F3', 'Ab3']
CYCLE = [(FM, 'F2'), (EB, 'Eb2'), (DB, 'Db2'), (EB, 'Eb2')]

# --- riff ------------------------------------------------------------
# The motif at 8th notes (3 beats) plus a 1-beat tail that fills the bar.
# RIFF_B ends on B natural -- the flat five, the interval "Dead Sector" is
# built on.  It lands every other bar, so the dread cue's one idea is
# already inside the combat cue before you ever meet a boss.
CELL   = diminish(MOTIF, 2)                                  # 3 beats
RIFF_A = CELL + [('F', 3, 0.5), ('F', 3.5, 0.5)]
RIFF_B = CELL + [('F', 3, 0.5), ('B', 3.5, 0.5)]

T = {k: Track(BARS) for k in
     ['sub', 'riff', 'pad', 'motif', 'arp', 'bell', 'perc', 'stab', 'fx']}

# blade() and pluck() are the two expensive voices and the riff repeats the
# same handful of pitches all track.  Neither is stochastic once cached, so
# this is a pure speed-up.
_bc, _pc = {}, {}
def bl(f, d, a, **kw):
    k = (round(f, 2), round(d, 4), tuple(sorted(kw.items())))
    if k not in _bc: _bc[k] = blade(f, d, 1.0, **kw)
    return _bc[k]*a
def pk(f, d, a):
    k = (round(f, 2), round(d, 4))
    if k not in _pc: _pc[k] = pluck(f, d, 1.0)
    return _pc[k]*a

def riff_bar(bar, oct_=3, amp=0.62, pan=0.0, form=None, off=0.0):
    """Place one riff cell. Odd bars take the ♭5 tail."""
    seq = form if form is not None else (RIFF_B if bar % 2 == 0 else RIFF_A)
    for n, b, d in oc(seq, oct_):
        T['riff'].add(bl(hz(n), d*SPB*0.92, amp), bb(bar)+b+off, pan=pan)

def kit(bar, heavy=True, hats=16):
    T['perc'].add(kick(0.80), bb(bar))
    T['perc'].add(kick(0.58), bb(bar)+2.5)
    T['perc'].add(snare(0.52), bb(bar)+1)
    T['perc'].add(snare(0.52), bb(bar)+3)
    if heavy:
        T['perc'].add(kick(0.44), bb(bar)+3.75)
    for k in range(hats):
        T['perc'].add(hat(0.04, 0.10+0.07*(k % 4 == 0)), bb(bar)+k*(4.0/hats),
                      pan=0.35 if k % 2 else -0.35)

# ============ I. IGNITION : bars 1-8 ============
# Reactor spins up.  The riff arrives as its first two notes only -- the
# same withholding "Dead Sector" opens with, at four times the speed.
for bar in range(1, 9):
    T['pad'].add(pad([hz(x) for x in FM], BAR, 0.16+0.02*bar, 700+120*bar), bb(bar))
    T['sub'].add(sub(hz('F2'), SPB*1.6, 0.42), bb(bar))
    T['sub'].add(sub(hz('F2'), SPB*1.2, 0.34), bb(bar)+2)
    T['perc'].add(kick(0.60 + 0.04*bar), bb(bar))
    if bar >= 3:
        T['perc'].add(kick(0.44), bb(bar)+2)
    if bar >= 5:
        T['perc'].add(snare(0.40), bb(bar)+3)
        for k in range(8):
            T['perc'].add(hat(0.045, 0.09), bb(bar)+k*0.5, pan=0.3 if k % 2 else -0.3)
        for n, b, d in oc(CELL[:2], 3):                  # F-G fragment only
            T['riff'].add(bl(hz(n), d*SPB*0.92, 0.46), bb(bar)+b, pan=-0.15)
T['fx'].add(noise_swell(2*BAR, 0.20), bb(7))

# ============ II. BURN : bars 9-24 ============
# The engine, locked.  Motif overhead in the original recorded register, so
# the thing you hear on the title screen is the thing driving the fight.
for i in range(16):
    bar = 9 + i
    v, root = CYCLE[i % 4]
    T['pad'].add(pad([hz(x) for x in v], BAR, 0.24, 2400), bb(bar))
    for k in range(8):
        T['sub'].add(sub(hz(root), SPB*0.75, 0.58), bb(bar)+k*0.5)
    riff_bar(bar, pan=-0.10)
    kit(bar)
    if i >= 2 and i % 2 == 0:                            # the hook, every 2 bars
        for n, b, d in oc(MOTIF, 5):
            T['motif'].add(whistle(hz(n), d*SPB*0.94, 0.42), bb(bar)+b, pan=0.20)
        for n, b, d in oc(MOTIF, 6):                     # original register, light
            T['motif'].add(whistle(hz(n), d*SPB*0.94, 0.16), bb(bar)+b, pan=-0.30)
    if i >= 6:
        riff_bar(bar, oct_=4, amp=0.20, pan=0.34)        # riff octave, fills the mids
    if i >= 8:                                           # 2nd half opens up
        order = [0, 1, 2, 1]
        for s in range(16):
            T['arp'].add(pk(hz(v[order[s % 4]])*2, 0.30, 0.16), bb(bar)+s*0.25,
                         pan=-0.45+0.9*((s % 4)/3))
        T['bell'].add(bell(hz(v[0])*2, SPB*2.0, 0.15), bb(bar), pan=0.42)
    if i % 4 == 0:
        T['stab'].add(metal(hz(root)*4, 3.2, 0.20), bb(bar), pan=-0.3+0.2*i/4)

# ============ III. OVERHEAT : bars 25-32 ============
# The riff comes off the grid.  The 3-beat cell is placed every 3 beats and
# left to walk against 4/4 -- ten cells across eight bars, aligning with the
# barline exactly twice.  Harmony stops moving so the metre is all you hear.
# This is "Dead Sector"'s polymetre section rebuilt at combat speed.
T['fx'].add(impact(0.70, 4.0), bb(25))
for i in range(8):
    bar = 25 + i
    v, root = (DB, 'Db2') if i < 4 else (EB, 'Eb2')
    T['pad'].add(pad([hz(x) for x in v], BAR, 0.26, 1700), bb(bar))
    for k in range(4):
        T['sub'].add(sub(hz(root), SPB*0.95, 0.62), bb(bar)+k)
    T['perc'].add(kick(0.78), bb(bar))                   # four on the floor
    T['perc'].add(kick(0.60), bb(bar)+1)
    T['perc'].add(kick(0.60), bb(bar)+2)
    T['perc'].add(kick(0.60), bb(bar)+3)
    T['perc'].add(snare(0.56), bb(bar)+1)
    T['perc'].add(snare(0.56), bb(bar)+3)
    for k in range(16):
        T['perc'].add(hat(0.035, 0.09+0.09*(k % 4 == 0)), bb(bar)+k*0.25,
                      pan=0.4 if k % 2 else -0.4)
    T['perc'].add(heart(0.30), bb(bar)+2)                # the pilot, not the kit
    for n, b, d in oc(MOTIF, 5):                         # straining, bent flat
        T['motif'].add(whistle_bend(hz(n), d*SPB*0.9, 0.34, -20), bb(bar)+b, pan=0.25)
    for n, b, d in oc(MOTIF, 6):
        T['motif'].add(whistle_bend(hz(n), d*SPB*0.9, 0.15, -20), bb(bar)+b, pan=-0.30)
for cell in range(10):                                   # 10 x 3 = 30 beats
    beat = bb(25) + cell*3
    if beat + 3 <= bb(33):
        for n, b, d in oc(CELL, 3):
            T['riff'].add(bl(hz(n), d*SPB*0.92, 0.66), beat+b, pan=-0.4+0.09*cell)
T['stab'].add(metal(hz('B4'), 5.0, 0.22), bb(29), pan=0.35)
T['fx'].add(rev_swell(1.5*BAR, 0.30, hz('F3')), bb(31.5))

# ============ IV. BURN' : bars 33-44 ============
# Back on the grid, and now the riff is in stretto with itself: the same
# 3-beat cell entered two beats later an octave down, so the two copies
# overlap for a beat every bar and the bassline argues with itself.
T['fx'].add(impact(0.50, 5.0), bb(33))
for i in range(12):
    bar = 33 + i
    v, root = CYCLE[i % 4]
    T['pad'].add(pad([hz(x) for x in v], BAR, 0.28, 3000), bb(bar))
    for k in range(8):
        T['sub'].add(sub(hz(root), SPB*0.72, 0.62), bb(bar)+k*0.5)
    riff_bar(bar, pan=-0.28)
    riff_bar(bar, oct_=4, amp=0.22, pan=0.20)                     # riff octave
    riff_bar(bar, oct_=2, amp=0.34, pan=0.32, form=CELL, off=2)   # comes
    kit(bar)
    for n, b, d in oc(MOTIF, 5):
        T['motif'].add(whistle(hz(n), d*SPB*0.94, 0.44), bb(bar)+b, pan=0.15)
    for n, b, d in oc(MOTIF, 6):
        T['motif'].add(whistle(hz(n), d*SPB*0.94, 0.17), bb(bar)+b, pan=-0.42)
    if i >= 4:
        for n, b, d in oc(MOTIF, 4):                     # canon, 2 beats late
            T['motif'].add(whistle(hz(n), d*SPB*0.94, 0.28), bb(bar)+b+2, pan=-0.35)
    order = [0, 2, 1, 2]
    for s in range(16):
        T['arp'].add(pk(hz(v[order[s % 4]])*2, 0.28, 0.17), bb(bar)+s*0.25,
                     pan=0.45-0.9*((s % 4)/3))
    T['bell'].add(bell(hz(v[0])*2, SPB*2.2, 0.18), bb(bar), pan=0.45)
    if i % 4 == 0:
        T['stab'].add(metal(hz(root)*4, 3.6, 0.24), bb(bar), pan=0.3)

# ============ V. VENT : bars 45-48 ============
# Heat dumps.  Everything strips back to the pedal and the first two notes,
# which is where bar 1 starts -- so the loop point is a musical event and
# not a splice.
T['pad'].add(pad([hz(x) for x in FM], 4*BAR, 0.30, 1200), bb(45))
for k in range(6):
    T['sub'].add(sub(hz('F2'), SPB*1.4, 0.54*(1-k/8)), bb(45)+k*2)
T['perc'].add(kick(0.80), bb(45)); T['perc'].add(snare(0.50), bb(45)+2)
for k in range(8):
    T['perc'].add(hat(0.04, 0.09*(1-k/9)), bb(45)+k*0.5, pan=0.3 if k % 2 else -0.3)
T['perc'].add(kick(0.60), bb(46))
riff_bar(45, amp=0.50, pan=-0.15)
for n, b, d in oc(CELL[:2], 3):
    T['riff'].add(bl(hz(n), d*SPB*0.92, 0.38), bb(46)+b, pan=-0.15)
for n, b, d in oc(MOTIF, 5):
    T['motif'].add(whistle(hz(n), d*SPB*1.0, 0.38), bb(47)+b, pan=0.0)
for n, b, d in oc(MOTIF, 6):
    T['motif'].add(whistle(hz(n), d*SPB*1.0, 0.18), bb(47)+b, pan=0.0)
T['fx'].add(noise_swell(2*BAR, 0.22), bb(47))

# ---------------- mix ----------------
# Combat runs dry.  Every wet value here is below its counterpart in the
# other three cues: reverb is distance, and a fight is not far away.

FX = {  # (reverb wet, delay in beats or None, level)
    'sub':   (0.04, None, 1.00),
    'riff':  (0.12, None, 1.00),
    'pad':   (0.32, None, 1.10),
    'motif': (0.28, 0.75, 0.95),
    'arp':   (0.22, 0.50, 1.00),
    'bell':  (0.42, 1.50, 0.75),
    'perc':  (0.10, None, 0.88),
    'stab':  (0.46, None, 0.80),
    'fx':    (0.50, None, 0.85),
}

def render(name, tr):
    y = tr.out()
    wet, dl, lvl = FX[name]
    if dl: y = delay(y, dl*SPB, fb=0.36, mix=0.24)
    y = reverb(y, wet)*lvl
    if name == 'sub': y = lp(y, 210, 2)*1.0 + hp(y, 210, 2)*0.30
    return y

def build(out_dir='out', loop=False, highpass=None):
    """loop=True drops the fade-out and wraps the reverb tail over the head."""
    mix, stems = master(
        {n: render(n, t) for n, t in T.items()},
        shelf=(0.25, 90), drive=1.30, peak=0.90,
        fade_in=(0.05, 1.0), fade_out=(2.2, 1.5),
        highpass=highpass,
        loop_len=int(BARS*BAR*SR) if loop else None)
    tag = '_loop' if loop else ''
    write_wav('%s/burn%s.wav' % (out_dir, tag), mix)
    for n, y in stems.items():
        write_wav('%s/burn_stems%s/%s.wav' % (out_dir, tag, n), y)
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
    print('burn%s  %.3f s  peak %.3f' % (
        '_loop' if a.loop else '', m.shape[1]/SR, np.max(np.abs(m))))
