import numpy as np, os
np.random.seed(1729)          # renders are deterministic
import synth; synth.set_tempo(71)
from synth import *
from motif import (PHRYGIAN as PHRY, TRITONE as TRI, SINK, _midi, _name,
                   bar as bb, octave as oc, augment as aug)

# =====================================================================
#  "DEAD SECTOR"  -  71 BPM (exactly half the main theme), F Phrygian
#  Motif mutation:  F G F G Ab   ->   F Gb F Gb Ab
#  The whole tone becomes a semitone. That single flat is the whole piece.
# =====================================================================

BARS = 40

# --- harmony ---------------------------------------------------------
# F Phrygian. bII (Gbmaj7) over an F pedal = a minor 9th clash that never resolves.
FM    = ['F3','Ab3','C4']
GBM7  = ['Gb3','Bb3','Db4','F4']          # bII - the Neapolitan
DBM    = ['Db3','F3','Ab3']               # bVI
CLUST = ['F3','Gb3','Ab3','Bb3']          # semitone stack
TRIC  = ['F3','B3','Db4','Gb4']           # F + tritone

T = {k: Track(BARS) for k in
     ['drone','sub','pad','motif','bowed','metal','pulse','fx','cluster']}

# --- the line --------------------------------------------------------
# This cue audits lowest of the eight for motif share and is still the most
# saturated by ear, because the count is not the problem: EVERY melodic note
# in it is the motif.  Everything else is drone, cluster, bowed pedal and
# heartbeat, so there is nothing for the phrase to be heard against and it
# does not matter that it only arrives fourteen times.
#
# LAMENT is the answer and it is the oldest one there is.  F Phrygian's
# descending tetrachord -- F E♭ D♭ C -- is the lament figure, and it is the
# one line this mode wants to make: the ♭2 above the tonic is what makes
# Phrygian sound like Phrygian, and a descent through it lands on the
# dominant degree without ever being a dominant.  It moves at one note every
# two bars, so it is slower than anything else here and reads as the ground
# giving way rather than as a tune.
#
# It goes on the bowed voice, which had nothing but pedals and the 7-beat
# ostinato, and it runs underneath the motif rather than answering it --
# a cue about something being wrong should not have a conversation in it.

#: One note every two bars.  Descends a fourth across each section, and each
#: section starts a step lower than the last, so across the piece it walks
#: down an octave and never comes back up.
LAMENT = [('F3', 0, 8), ('Eb3', 8, 8), ('Db3', 16, 8), ('C3', 24, 8)]


def lament(bar0, drop=0, amp=0.22, pan=0.0):
    """The tetrachord from `bar0`, transposed down `drop` semitones."""
    out = []
    for n, b, d in LAMENT:
        m = _midi(n) - drop
        out.append((_name(m), b, d))
    for n, b, d in out:
        T['bowed'].add(bowed(hz(n), d*SPB*0.92, amp, 2.4), bb(bar0)+b, pan=pan)




# ============ I. SILENCE WITH SOMETHING IN IT : bars 1-8 ============
# Pedal only. Motif appears as a fragment - two notes, no answer.
T['sub'].add(drone(hz('F1'), 8*BAR, 0.55, 90, 190), bb(1))
T['drone'].add(drone(hz('F2'), 8*BAR, 0.26, 160, 420), bb(1))
T['fx'].add(air(8*BAR, 0.11, 90, 900), bb(1))
for bar, pan in [(3, -0.5), (6, 0.5)]:                 # fragment: F-Gb only
    for n, b, d in [('F4',0,1),('Gb4',1,3)]:
        T['motif'].add(whistle_bend(hz(n), d*SPB*0.9, 0.26, -8), bb(bar)+b, pan=pan)
T['metal'].add(metal(hz('Gb5'), 7.0, 0.14), bb(7), pan=0.4)
# the transponder itself, briefly: the tick from the sector cue, same pitch,
# same three-beat indifference -- a schedule still running in an empty system
from motif import loop_beats as _lb
_tick = bell(hz('F6'), 1.4, 1.0)
for _b in _lb(3.0, 12.0):
    T['metal'].add(_tick*0.026, bb(5) + _b, pan=0.38)

# ============ II. THE MOTIF ARRIVES : bars 9-16 ============
# Full Phrygian motif, low register, alternating i and bII.
for i, bar in enumerate([9, 11, 13, 15]):
    voice = FM if i % 2 == 0 else GBM7
    T['pad'].add(cluster([hz(x) for x in voice], 2*BAR, 0.24, 1100), bb(bar))
    T['sub'].add(drone(hz('F1'), 2*BAR, 0.50, 85, 175), bb(bar))     # pedal never moves
    if i % 2 == 0:                                   # twice, not four times
        for n, b, d in oc(PHRY, 4):
            T['motif'].add(whistle_bend(hz(n), d*SPB*0.92, 0.34, -6), bb(bar)+b,
                           pan=-0.12)
lament(9, 0, 0.20, pan=0.32)
T['pulse'].add(heart(0.42), bb(13)); T['pulse'].add(heart(0.42), bb(15))

# ============ III. POLYMETER : bars 17-24 ============
# A 7-beat ostinato under 4/4. Realigns only every 7 bars - so it never
# settles inside this section. Instability as a compositional device.
T['sub'].add(drone(hz('F1'), 8*BAR, 0.52, 85, 210), bb(17))
# This ostinato is THE LOOP -- the album's constant, native here before it
# was named: a cell repeating on a cycle that does not fit the bar,
# indifferent, outliving whoever hears it.  motif.py documents the cast.
OST = [('F2',0),('Gb2',1.5),('F2',3),('Db2',4.5),('F2',5.5)]         # 7-beat cell
b0 = bb(17)
for cell in range(5):                                   # 5 x 7 = 35 beats > 32
    for n, off in OST:
        beat = b0 + cell*7 + off
        if beat < bb(25):
            T['bowed'].add(bowed(hz(n), SPB*1.3, 0.30), beat, pan=-0.4+0.16*cell)
for i, bar in enumerate([17, 19, 21, 23]):
    T['pad'].add(cluster([hz(x) for x in (GBM7 if i % 2 else CLUST)],
                         2*BAR, 0.26, 1500), bb(bar))
    if i == 2:                                          # once, floating on top
        for n, b, d in aug(oc(PHRY, 5), 2):
            T['motif'].add(whistle_bend(hz(n), d*SPB*0.85, 0.22, -14), bb(bar)+b,
                           pan=0.25)
for bar in [18, 20, 21, 22, 23, 24]:
    T['pulse'].add(heart(0.40 + 0.02*(bar-18)), bb(bar))
lament(17, 2, 0.22, pan=0.28)                       # a whole step lower
T['metal'].add(metal(hz('Gb5'), 8.0, 0.13), bb(21), pan=-0.45)
T['fx'].add(rev_swell(2*BAR, 0.30, hz('Gb3')), bb(23))

# ============ IV. TRITONE : bars 25-32 ============
# The motif's last note is dragged from Ab up to B natural - the flat five.
# This is the only real "event" in the piece.
T['fx'].add(impact(0.85, 5.0), bb(25))
T['sub'].add(drone(hz('F1'), 8*BAR, 0.62, 80, 260), bb(25))
T['drone'].add(drone(hz('B1'), 8*BAR, 0.30, 90, 300), bb(27))       # tritone pedal
for i, bar in enumerate([25, 27, 29, 31]):
    T['cluster'].add(cluster([hz(x) for x in TRIC], 2*BAR, 0.30, 1900), bb(bar))
    if i % 2 == 1:                                  # twice, not four times
        for n, b, d in oc(TRI, 4):
            T['motif'].add(whistle_bend(hz(n), d*SPB*0.94, 0.38, -5), bb(bar)+b,
                           pan=-0.2)

    if i % 2 == 1:                    # with its voice, never alone: the main
        for n, b, d in oc(TRI, 5):    # statement is gated to alternate bars
            T['motif'].add(whistle_bend(hz(n)*0.9971, d*SPB*0.94, 0.20, -18),
                       bb(bar)+b+0.5, pan=0.35)
    T['bowed'].add(bowed(hz('B2'), 2*BAR, 0.26, 3.4), bb(bar), pan=0.42)
    T['bowed'].add(bowed(hz('F2'), 2*BAR, 0.26, 3.4), bb(bar), pan=-0.42)
for bar in range(25, 33):
    T['pulse'].add(heart(0.60), bb(bar))
    T['pulse'].add(heart(0.36), bb(bar)+2)
# The lament reaches the tritone here: transposed down a further fourth, its
# own descent lands on B natural in the bars the cue is named for.
lament(25, 6, 0.24, pan=0.20)
T['metal'].add(metal(hz('B5'), 9.0, 0.17), bb(29), pan=0.3)
T['fx'].add(rev_swell(1.5*BAR, 0.26), bb(31.5))

# ============ V. COLLAPSE : bars 33-40 ============
# Motif inverted downward and bent flat. Ends a semitone BELOW where it began.
T['fx'].add(impact(0.55, 6.0), bb(33))
T['sub'].add(drone(hz('F1'), 8*BAR, 0.44, 78, 150), bb(33))
T['pad'].add(cluster([hz(x) for x in CLUST], 6*BAR, 0.22, 700), bb(33))
for n, b, d in oc(SINK, 4):
    T['motif'].add(whistle_bend(hz(n), d*SPB*0.9, 0.30, -22), bb(33)+b, pan=0.0)
T['pulse'].add(heart(0.34), bb(34)); T['pulse'].add(heart(0.26), bb(36))
lament(33, 12, 0.18, pan=0.0)                     # an octave below where it began
T['metal'].add(metal(hz('F5'), 10.0, 0.12), bb(35), pan=-0.35)
# last gesture: the opening two notes, alone, sliding a quarter-tone flat
T['motif'].add(whistle_bend(hz('F4'), SPB*2, 0.24, -12), bb(38), pan=-0.15)
T['motif'].add(whistle_bend(hz('Gb4'), SPB*5, 0.22, -55), bb(38)+2, pan=0.15)
T['fx'].add(air(6*BAR, 0.10, 70, 700), bb(35))

# ---------------- mix ----------------

FX = {'drone':(0.50,0.95),'sub':(0.06,1.00),'pad':(0.55,0.95),'motif':(0.52,1.00),
      'bowed':(0.46,0.92),'metal':(0.62,0.80),'pulse':(0.16,1.00),'fx':(0.50,0.90),
      'cluster':(0.58,0.92)}

def render(name, tr):
    y = tr.out(); wet, lvl = FX[name]
    if name in ('motif','metal'):
        y = delay(y, 3*SPB, fb=0.46, mix=0.30)
    y = reverb(y, wet)*lvl
    if name == 'sub': y = lp(y, 170, 2)*1.05 + hp(y, 170, 2)*0.28
    return y

def build(out_dir='out', loop=False, highpass=None):
    """loop=True drops the fade-out and wraps the reverb tail over the head."""
    mix, stems = master(
        {n: render(n, t) for n, t in T.items()},
        shelf=(0.18, 70), drive=1.15, peak=0.86,
        fade_in=(1.2, 1.4), fade_out=(5.0, 1.8),
        highpass=highpass,
        loop_len=int(BARS*BAR*SR) if loop else None)
    tag = '_loop' if loop else ''
    write_wav('%s/dread%s.wav' % (out_dir, tag), mix)
    for n, y in stems.items():
        write_wav('%s/dread_stems%s/%s.wav' % (out_dir, tag, n), y)
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
    print('dread%s  %.3f s  peak %.3f' % (
        '_loop' if a.loop else '', m.shape[1]/SR, np.max(np.abs(m))))
