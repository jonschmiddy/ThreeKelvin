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
# What this cue actually is, is the 3-BEAT CELL AGAINST 4/4 -- locked to the
# bar it leaves one beat for a tail, let go it walks and realigns twice in
# eight bars.  That is the engine, and it is a rhythmic idea, not a melodic
# one.  The cell used to be `diminish(MOTIF, 2)` as well, which meant the
# engine and the tune were the same five notes and the cue audited at 57%
# motif with nothing else in it.
#
# So the cell keeps its rhythm to the sample and gets its own pitches.  It is
# built to be a riff rather than a phrase: up a minor third, down to the ♭7,
# back, then a leap to the fifth -- angular, and nothing like the motif's
# rocking 1-2.  The 1-beat tail and the B natural on alternate bars are
# unchanged, because that is what puts the dread cue's tritone inside the
# combat cue before you ever meet a boss.
# Reworked once on a listening note: the first cell's tail (Ab-Eb-C) was a
# plain stepwise descent, and with the hook's own falling phrases above it,
# bars 9-13 were two layers of predictable descent stacked.  This cell is
# angular instead: a repeated-note drive with a 16th pickup, then the b6 --
# Db, the one dark note the riff never touched -- biting down onto C, then a
# kick back up before the Eb lean into the next cell.  Same 3 beats, same
# polymetre, same B-natural tail on RIFF_B.
# Second rework, tempo edition: the 16th-note version of this cell put six
# ~0.1 s notes in every 3 beats, and no bowed string speaks in 0.1 s -- the
# riff read as chatter and the whole cue as faster than its own 142.  Same
# angular contour, in eighths: rise F-Ab-C, then the b6 bite (Db-C, the one
# surviving 16th pair -- a bite is the one thing that SHOULD be short), then
# the Ab kickback and the Eb lean into the next cell.
CELL   = [('F', 0, 0.5), ('Ab', 0.5, 0.5), ('C', 1, 0.5),
          ('Db', 1.5, 0.25), ('C', 1.75, 0.25),
          ('Ab', 2, 0.5), ('Eb', 2.5, 0.5)]                      # 3 beats
RIFF_A = CELL + [('F', 3, 0.5), ('F', 3.5, 0.5)]
RIFF_B = CELL + [('F', 3, 0.5), ('B', 3.5, 0.5)]

#: The hook that sits over the engine.  Four bars, one per chord of CYCLE,
#: syncopated against a riff that is already fighting the barline -- and it
#: climbs chromatically through B natural into the C at the end, which is the
#: same interval the riff lands on and the only place in the cue anything
#: resolves upward.
# The hook's first three phrases used to be a sequence of stepwise falls
# (C5.. / Bb4.. / Ab4..), which read as filler over a riff that was also
# falling.  Now it leaps: rising fourths with falls AFTER the peaks, a G5
# apex in the third phrase, and the same chromatic Bb-B-C climb at the end
# -- the one place anything in this cue resolves upward, kept.
HOOK = [('C5', 0, 1.5), ('F5', 1.5, 0.5), ('Eb5', 2, 1), ('C5', 3, 1),
        ('Db5', 4, 1.5), ('Ab4', 5.5, 0.5), ('Bb4', 6, 2),
        ('C5', 8, 0.5), ('Eb5', 8.5, 0.5), ('F5', 9, 1), ('G5', 10, 1),
        ('Eb5', 11, 1),
        ('Bb4', 12, 1), ('B4', 13, 1), ('C5', 14, 2)]

#: The same hook an octave up and stripped to its long notes, for the
#: sections that need a top line without another busy one.
HOOK_HI = [(n[:-1] + str(int(n[-1]) + 1), b, d) for n, b, d in HOOK if d >= 2]

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

def fill(bar, big=False):
    """Turnaround: a snare run up the back of the bar.  Sections that end
    without one just stop; a fill is the drummer announcing the corner."""
    n = 8 if big else 6
    for k in range(n):
        T['perc'].add(snare(0.18 + 0.06*k), bb(bar) + 4 - (n - k)*0.25)
    if big:
        T['perc'].add(kick(0.80), bb(bar) + 3.0)

# ============ I. IGNITION : bars 1-8 ============
# Reactor spins up.  The riff arrives as its first two notes only -- the
# same withholding "Dead Sector" opens with, at four times the speed.
for bar in range(1, 9):
    T['pad'].add(pad([hz(x) for x in FM], BAR, 0.16+0.02*bar, 700+120*bar), bb(bar))
    T['sub'].add(sub(hz('F2'), SPB*1.6, 0.11), bb(bar))
    T['sub'].add(sub(hz('F2'), SPB*1.2, 0.09), bb(bar)+2)
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

# ============ II. BURN : bars 9-20 ============
# The engine, locked.  Twelve bars, not sixteen: the extra statement of this
# texture was the repetition a listener called out -- a fight that says the
# same thing four times is a sparring drill.  Hook once at 9, engine alone
# from 13, restatement with the octave line at 17, and OUT into the break
# while it still has somewhere to go.
for i in range(12):
    bar = 9 + i
    v, root = CYCLE[i % 4]
    T['pad'].add(pad([hz(x) for x in v], BAR, 0.24, 2400), bb(bar))
    for k in range(8):
        T['sub'].add(sub(hz(root), SPB*0.75, 0.15), bb(bar)+k*0.5)
    riff_bar(bar, pan=-0.10)
    kit(bar)
    if i == 0:
        for n, b, d in HOOK:
            T['motif'].add(whistle(hz(n), d*SPB*0.94, 0.40), bb(bar)+b, pan=0.20)
    if i == 8:                                   # restated, now with the top
        for n, b, d in HOOK:
            T['motif'].add(whistle(hz(n), d*SPB*0.94, 0.40), bb(bar)+b, pan=0.20)
        for n, b, d in HOOK_HI:
            T['motif'].add(whistle(hz(n), d*SPB*0.94, 0.15), bb(bar)+b, pan=-0.30)
    if i >= 6:
        riff_bar(bar, oct_=4, amp=0.20, pan=0.34)        # riff octave, fills the mids
    if i >= 8:                                           # terrace: arps and bells
        order = [0, 1, 2, 1]                             # join for the last four only
        for q in range(16):
            T['arp'].add(pk(hz(v[order[q % 4]])*2, 0.30, 0.16), bb(bar)+q*0.25,
                         pan=-0.45+0.9*((q % 4)/3))
        T['bell'].add(bell(hz(v[0])*2, SPB*2.0, 0.15), bb(bar), pan=0.42)
    if i % 4 == 0:
        T['stab'].add(metal(hz(root)*4, 3.2, 0.12), bb(bar), pan=-0.3+0.2*i/4)
    if i == 11:
        fill(bar)

# ============ III. THE BREAK : bars 21-24 ============
# Stop-time.  The band hits the downbeat and SHUTS UP; the lead answers in
# the silence -- call and response, the oldest fight-scene device there is.
# No pad, no arps, no hats: four bars of air in the middle of the cue is
# what makes both halves land.  The last fill climbs D-Eb-F#-G: F sharp,
# which exists nowhere else in the piece, is G minor's leading tone, and it
# kicks the door open on the lift.
HITS = [(21, FM, 'F2'), (22, DB, 'Db2'), (23, EB, 'Eb2')]
RUNS = {
    21: [('F4', 1.5, 0.5), ('Ab4', 2, 0.5), ('C5', 2.5, 0.5), ('Ab4', 3, 1)],
    22: [('Db5', 1.5, 0.5), ('C5', 2, 0.5), ('Ab4', 2.5, 0.5), ('F4', 3, 1)],
    23: [('Bb4', 1.5, 0.5), ('C5', 2, 0.75), ('D5', 2.75, 0.25), ('Eb5', 3, 1)],
    24: [('D5', 2, 0.5), ('Eb5', 2.5, 0.5), ('F#5', 3, 0.5), ('G5', 3.5, 0.5)],
}
def _hit(bar, chord, root, beat=0.0, a=1.0):
    T['perc'].add(kick(0.95*a), bb(bar)+beat)
    T['perc'].add(snare(0.60*a), bb(bar)+beat)
    T['sub'].add(sub(hz(root), SPB*1.5, 0.22*a), bb(bar)+beat)
    for j, n in enumerate(chord):
        T['riff'].add(bl(hz(n), SPB*1.1, (0.55-0.12*j)*a), bb(bar)+beat,
                      pan=-0.2+0.2*j)
for bar, v, root in HITS:
    _hit(bar, v, root)
_hit(24, FM, 'F2', 0.0, 0.95)
_hit(24, FM, 'F2', 2.0, 0.90)
for k in range(8):                               # snare ramp into the lift
    T['perc'].add(snare(0.16+0.06*k), bb(24)+2+k*0.25)
for bar, run in RUNS.items():
    for n, b, d in run:
        T['motif'].add(whistle(hz(n), d*SPB*0.95, 0.40), bb(bar)+b, pan=0.10)

# ============ IV. THE LIFT : bars 25-32 ============
# Up a whole step.  Same engine cell, same polymetre walk -- ten 3-beat
# cells against eight bars of 4/4 -- but in G minor, under the GUITAR SOLO:
# eight bars that arc from a pushed mid-register entrance to one screaming
# three-beat peak, then fall away and hand the stage back on the cue's
# chromatic Bb-B-C climb, landing exactly on the hook's first note as F
# minor returns for the finale.
GM  = ['G3', 'Bb3', 'D4']
FGM = ['F3', 'A3', 'C4']
CYCLE_G = [(GM, 'G2'), (FGM, 'F2'), (EB, 'Eb2'), (FGM, 'F2')]
CELL_G = [('G', 0, 0.5), ('Bb', 0.5, 0.5), ('D', 1, 0.5),
          ('Eb', 1.5, 0.25), ('D', 1.75, 0.25),
          ('Bb', 2, 0.5), ('F', 2.5, 0.5)]
# The solo.  Halo puts a guitar solo over the ostinato and lets it SOAR:
# long bent holds with wide vibrato, stitched together by fast runs, arcing
# upward for eight bars to one screaming peak -- then it hands the stage
# back to the theme.  Phrases enter after the beat (a player pushes off the
# drummer, not with him).  The door does the left hand: notes over ~2 beats
# get a full-step bend in, wide late vibrato, and amp sustain.
SOLO = [
    # phrase 1: enter off the beat, speak, answer
    ('G4', 0.5, 2.5),
    ('F4', 3, 0.25), ('G4', 3.25, 0.25), ('Bb4', 3.5, 0.5), ('C5', 4, 1.25),
    ('Bb4', 5.5, 0.25), ('C5', 5.75, 0.25), ('D5', 6, 2),
    # phrase 2: the first run, and the A-natural color hold
    ('G4', 8.5, 0.25), ('Bb4', 8.75, 0.25), ('C5', 9, 0.25), ('D5', 9.25, 0.25),
    ('Eb5', 9.5, 0.25), ('F5', 9.75, 0.25), ('F5', 10, 1.5),
    ('D5', 11.5, 0.5), ('C5', 12, 0.5), ('D5', 12.5, 1.0),
    ('Bb4', 13.5, 0.5), ('A4', 14, 1.5), ('C5', 15.5, 0.5),
    # phrase 3: climbing sequence, first touch of the top
    ('D5', 16, 1), ('Eb5', 17, 0.5), ('D5', 17.5, 0.25), ('C5', 17.75, 0.25),
    ('D5', 18, 1.5), ('F5', 19.5, 0.5), ('G5', 20, 1.5),
    ('F5', 21.5, 0.25), ('Eb5', 21.75, 0.25), ('F5', 22, 1),
    ('D5', 23, 0.25), ('Eb5', 23.25, 0.25), ('F5', 23.5, 0.5),
    # phrase 4: the scream, the fall, the handoff
    ('G5', 24, 3.0),
    ('F5', 27, 0.25), ('Eb5', 27.25, 0.25), ('D5', 27.5, 0.25), ('C5', 27.75, 0.25),
    ('Bb4', 28, 0.5), ('G4', 28.5, 1.2),
    ('Bb4', 30, 0.66), ('B4', 30.66, 0.67), ('C5', 31.33, 0.67),
]
T['fx'].add(impact(0.25, 3.5), bb(25))
for i in range(8):
    bar = 25 + i
    v, root = CYCLE_G[i % 4]
    T['pad'].add(pad([hz(x) for x in v], BAR, 0.26, 1900), bb(bar))
    for k in range(4):
        T['sub'].add(sub(hz(root), SPB*0.95, 0.16), bb(bar)+k)
    T['perc'].add(kick(0.78), bb(bar))                   # four on the floor
    T['perc'].add(kick(0.60), bb(bar)+1)
    T['perc'].add(kick(0.60), bb(bar)+2)
    T['perc'].add(kick(0.60), bb(bar)+3)
    T['perc'].add(snare(0.56), bb(bar)+1)
    T['perc'].add(snare(0.56), bb(bar)+3)
    for k in range(8):
        T['perc'].add(hat(0.04, 0.09+0.07*(k % 4 == 0)), bb(bar)+k*0.5,
                      pan=0.4 if k % 2 else -0.4)
    T['perc'].add(heart(0.30), bb(bar)+2)                # the pilot, not the kit
    if i == 7:
        fill(bar, big=True)
for cell in range(10):                                   # 10 x 3 = 30 beats
    beat = bb(25) + cell*3
    if beat + 3 <= bb(33):
        for n, b, d in oc(CELL_G, 3):
            T['riff'].add(bl(hz(n), d*SPB*0.92, 0.48), beat+b, pan=-0.4+0.09*cell)
for n, b, d in SOLO:
    T['motif'].add(whistle(hz(n), d*SPB*0.97, 0.42 if d >= 1.0 else 0.34),
                   bb(25)+b, pan=0.15)

# ============ V. BURN' : bars 33-44 ============
# Back on the grid, and now the riff is in stretto with itself: the same
# 3-beat cell entered two beats later an octave down, so the two copies
# overlap for a beat every bar and the bassline argues with itself.
T['fx'].add(impact(0.28, 5.0), bb(33))
for i in range(12):
    bar = 33 + i
    v, root = CYCLE[i % 4]
    T['pad'].add(pad([hz(x) for x in v], BAR, 0.28, 3000), bb(bar))
    for k in range(8):
        T['sub'].add(sub(hz(root), SPB*0.72, 0.16), bb(bar)+k*0.5)
    riff_bar(bar, pan=-0.28)
    riff_bar(bar, oct_=4, amp=0.22, pan=0.20)                     # riff octave
    riff_bar(bar, oct_=2, amp=0.34, pan=0.32, form=CELL, off=2)   # comes
    kit(bar)
    if i % 8 == 0:
        for n, b, d in HOOK:
            T['motif'].add(whistle(hz(n), d*SPB*0.94, 0.35), bb(bar)+b, pan=0.15)
        for n, b, d in HOOK_HI:
            T['motif'].add(whistle(hz(n), d*SPB*0.94, 0.13), bb(bar)+b, pan=-0.42)
    if i == 8:                                           # canon, once, at the
        for n, b, d in HOOK:                             # section's height
            T['motif'].add(whistle(hz(n[:-1] + str(int(n[-1]) - 1)),
                                   d*SPB*0.94, 0.19), bb(bar)+b+2, pan=-0.35)
    if i == 10:                          # the motif, once more -- bar 43 and
        for n, b, d in oc(MOTIF, 6):     # not 41, so it is not sharing the
                                         # whistle with the hook
            T['motif'].add(whistle(hz(n), d*SPB*0.94, 0.26), bb(bar)+b, pan=-0.20)
    order = [0, 2, 1, 2]
    for s in range(16):
        T['arp'].add(pk(hz(v[order[s % 4]])*2, 0.28, 0.17), bb(bar)+s*0.25,
                     pan=0.45-0.9*((s % 4)/3))
    T['bell'].add(bell(hz(v[0])*2, SPB*2.2, 0.18), bb(bar), pan=0.45)
    if i % 4 == 0:
        T['stab'].add(metal(hz(root)*4, 3.6, 0.14), bb(bar), pan=0.3)
    if i in (3, 7, 11):
        fill(bar, big=(i == 11))                         # 44's big fill drops
                                                         # into the vent

# ============ VI. VENT : bars 45-48 ============
# Heat dumps.  Everything strips back to the pedal and the first two notes,
# which is where bar 1 starts -- so the loop point is a musical event and
# not a splice.
T['pad'].add(pad([hz(x) for x in FM], 4*BAR, 0.30, 1200), bb(45))
for k in range(6):
    T['sub'].add(sub(hz('F2'), SPB*1.4, 0.14*(1-k/8)), bb(45)+k*2)
T['perc'].add(kick(0.80), bb(45)); T['perc'].add(snare(0.50), bb(45)+2)
for k in range(8):
    T['perc'].add(hat(0.04, 0.09*(1-k/9)), bb(45)+k*0.5, pan=0.3 if k % 2 else -0.3)
T['perc'].add(kick(0.60), bb(46))
riff_bar(45, amp=0.50, pan=-0.15)
for n, b, d in oc(CELL[:2], 3):
    T['riff'].add(bl(hz(n), d*SPB*0.92, 0.38), bb(46)+b, pan=-0.15)
# One register only in the vent: the piece should be coming DOWN here.  The
# G5 apexes rhyme across the hook restatement (19-20), the lift's second
# subject, and the finale (43-44).
for n, b, d in oc(MOTIF, 5):
    T['motif'].add(whistle(hz(n), d*SPB*1.0, 0.38), bb(47)+b, pan=0.0)
T['fx'].add(noise_swell(2*BAR, 0.22), bb(47))

# ---------------- mix ----------------
# Combat runs dry.  Every wet value here is below its counterpart in the
# other three cues: reverb is distance, and a fight is not far away.

FX = {  # (reverb wet, delay in beats or None, level)
    'sub':   (0.04, None, 1.00),
    'riff':  (0.12, None, 1.25),   # up 2 dB: the accompaniment was vanishing under the glass
    'pad':   (0.32, None, 1.10),
    'motif': (0.28, 0.75, 0.60),   # 0.95->0.75->0.60 on listening: the glass kept shouting
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
    if name == 'perc': y = hp(y, 70, 2)*1.0 + lp(y, 70, 2)*0.35   # concert BD: keep the knock, cut the boom
    return y

def build(out_dir='out', loop=False, highpass=None):
    """loop=True drops the fade-out and wraps the reverb tail over the head."""
    mix, stems = master(
        {n: render(n, t) for n, t in T.items()},
        shelf=(0.25, 90), drive=1.30, # 0.86, from 0.90: the true-sub cutover put more energy in the bass and
        # sub stems and both cleared 1.0.  The ceiling is the lever, as ever.
        peak=0.74,
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
