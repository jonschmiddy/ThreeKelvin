"""Score for "Warm Ship" -- the station and refit cue.

    python3 warm.py [--out DIR] [--loop] [--hp HZ]
"""
import numpy as np
np.random.seed(1729)          # renders are deterministic
import synth; synth.set_tempo(71)
from synth import *
from motif import MOTIF, INVERT, ANSWER, bar as bb, octave as oc

# =====================================================================
#  "WARM SHIP"  -  71 BPM, F minor coloured from the ♭VI.  24 bars, 81.13 s.
#
#  The audio half of "cold universe, warm ship".  Every other cue is the
#  void; this is the inside of the hull, and it is the only music in the
#  game with no noise, no drums and no distortion in it anywhere.
#
#  Two decisions carry the whole piece:
#
#  * **It starts on the ♭VI, not on i.**  THEME_NOTES §3: over D♭maj7 the
#    motif's G is a ♯11 and the phrase reads as wonder rather than home.
#    The cycle ♭VI - ♭III - ♭VII - i then walks *towards* the tonic, so
#    arriving at a station is a cadence and leaving one re-opens it.
#  * **It answers the motif.**  The source phrase never touches the fifth
#    -- a question with no answer, which is exactly right under a run that
#    can end at any moment.  Bars 23-24 finally give it the C, over Fm9,
#    once per loop.  A station is the only place in the game that is safe,
#    so it is the only place the tune is allowed to finish.
#
#  71 BPM, so one bar here is two "Slow Drift" bars and the chart-to-dock
#  crossfade needs no tempo match.  24 bars is exactly "Hard Burn"'s 48.
# =====================================================================

BARS = 24

# --- harmony ---------------------------------------------------------
# ♭VI - ♭III - ♭VII - i, two bars each.  Three cycles.
DB7  = (['Db3', 'F3', 'Ab3', 'C4'],        'Db2')   # Dbmaj7  : G is the ♯11
AB7  = (['Ab2', 'C3', 'Eb3', 'G3'],        'Ab2')   # Abmaj7  : F is the 13th
EB69 = (['Eb3', 'G3', 'Bb3', 'C4', 'F4'],  'Eb2')   # Eb6/9   : suspended
FM9  = (['F3', 'Ab3', 'C4', 'G4'],         'F2')    # Fm9     : home
CYCLE = [DB7, AB7, EB69, FM9]

T = {k: Track(BARS) for k in
     ['pad', 'glass', 'sub', 'motif', 'arp', 'bell', 'lead', 'fx']}

_pc = {}
def pk(f, d, a):
    k = (round(f, 2), round(d, 4))
    if k not in _pc: _pc[k] = pluck(f, d, 1.0)
    return _pc[k]*a

def chords(cycle_start):
    """(bar, voicing, root) for one 8-bar pass."""
    for c in range(4):
        v, root = CYCLE[c]
        yield cycle_start + c*2, v, root

# ============ I. DOCKED : bars 1-8 ============
# Pad and glass only.  The motif twice, high and far off, with two bars of
# nothing after each -- the room before anyone speaks in it.
T['fx'].add(air(8*BAR, 0.13, 200, 2400), bb(1))
for bar, v, root in chords(1):
    T['pad'].add(pad([hz(x) for x in v], 2*BAR, 0.34, 1800), bb(bar))
    T['glass'].add(glass(hz(v[-1])*2, 2*BAR*0.9, 0.22), bb(bar), pan=0.30)
    T['glass'].add(glass(hz(v[1])*2, 2*BAR*0.85, 0.13), bb(bar)+2, pan=-0.32)
    for k in range(2):
        T['sub'].add(sub(hz(root), SPB*2.6, 0.34), bb(bar)+k*4)
    if bar >= 5:                                     # circulation starts
        for s in range(8):
            T['arp'].add(pk(hz(v[s % len(v)])*2, 0.65, 0.11), bb(bar)+s,
                         pan=-0.35+0.7*((s % 4)/3))
for bar, pan in [(1, -0.28), (3, 0.30), (5, 0.28), (7, -0.30)]:
    for n, b, d in oc(MOTIF, 6):
        T['motif'].add(glass(hz(n), d*SPB*0.9, 0.22), bb(bar)+b, pan=pan)

# ============ II. SYSTEMS UP : bars 9-16 ============
# Bass, a pluck figure that reads as something circulating, and the motif
# down where you can hum it.
for bar, v, root in chords(9):
    T['pad'].add(pad([hz(x) for x in v], 2*BAR, 0.30, 2200), bb(bar))
    T['glass'].add(glass(hz(v[-1])*2, 2*BAR*0.9, 0.13), bb(bar), pan=0.34)
    for k in range(4):
        T['sub'].add(sub(hz(root), SPB*1.7, 0.44), bb(bar)+k*2)
    order = [0, 1, 2, 1, 2, 3]                       # rising, never resolving down
    for s in range(16):
        f = hz(v[order[s % len(order)] % len(v)])*2
        T['arp'].add(pk(f, 0.55, 0.13), bb(bar)+s*0.5, pan=-0.40+0.8*((s % 4)/3))
    for n, b, d in oc(MOTIF, 5):
        T['lead'].add(whistle(hz(n), d*SPB*0.94, 0.34), bb(bar)+b, pan=-0.10)
    if bar >= 13:
        for n, b, d in oc(MOTIF, 6):
            T['bell'].add(bell(hz(n), d*SPB*1.6, 0.14), bb(bar)+b, pan=0.42)
T['fx'].add(air(8*BAR, 0.08, 180, 2000), bb(9))

# ============ III. THE ANSWER : bars 17-24 ============
# Bars 19-20 lift: INVERT's D natural over A♭maj7 is that chord's ♯11, so
# the mirrored motif turns Lydian exactly where the harmony can take it.
# Bars 23-24 give the phrase its fifth and stop.
for bar, v, root in chords(17):
    T['pad'].add(pad([hz(x) for x in v], 2*BAR, 0.32, 2800), bb(bar))
    T['glass'].add(glass(hz(v[-1])*2, 2*BAR*0.9, 0.15), bb(bar), pan=0.30)
    for k in range(8):
        T['sub'].add(sub(hz(root), SPB*0.95, 0.46), bb(bar)+k)
    order = [0, 2, 1, 3, 2, 1]
    for s in range(16):
        f = hz(v[order[s % len(order)] % len(v)])*2
        T['arp'].add(pk(f, 0.50, 0.14), bb(bar)+s*0.5, pan=0.40-0.8*((s % 4)/3))
    seq = {17: MOTIF, 19: INVERT, 21: MOTIF, 23: ANSWER}[bar]
    for n, b, d in oc(seq, 5):
        T['lead'].add(whistle(hz(n), d*SPB*0.94, 0.40), bb(bar)+b, pan=-0.08)
    for n, b, d in oc(seq, 6):
        T['bell'].add(bell(hz(n), d*SPB*1.6, 0.15), bb(bar)+b, pan=0.44)
    if bar == 21:                                    # canon into the answer
        for n, b, d in oc(MOTIF, 4):
            T['lead'].add(whistle(hz(n), d*SPB*0.94, 0.24), bb(bar)+b+2, pan=0.34)
# the C, held, on the warmest voice in the set
T['motif'].add(glass(hz('C6'), 3.2, 0.20), bb(23)+5, pan=0.0)
T['fx'].add(air(8*BAR, 0.09, 160, 1800), bb(17))
T['fx'].add(noise_swell(2*BAR, 0.07), bb(23))

# ---------------- mix ----------------
# Wettest cue in the set: a hull interior is small, but reverb here is
# comfort rather than distance, so the tails are long and the top is soft.

FX = {  # (reverb wet, delay in beats or None, level)
    'pad':   (0.48, None, 1.00),
    'glass': (0.52, None, 1.25),
    'sub':   (0.06, None, 0.78),
    'motif': (0.60, 1.50, 1.10),
    'arp':   (0.40, 0.75, 1.15),
    'bell':  (0.55, 1.50, 1.00),
    'lead':  (0.38, 0.75, 1.00),
    'fx':    (0.55, None, 0.85),
}

def render(name, tr):
    y = tr.out()
    wet, dl, lvl = FX[name]
    if dl: y = delay(y, dl*SPB, fb=0.34, mix=0.26)
    y = reverb(y, wet)*lvl
    if name == 'sub': y = lp(y, 200, 2)*1.0 + hp(y, 200, 2)*0.32
    return y

def build(out_dir='out', loop=False, highpass=None):
    """loop=True drops the fade-out and wraps the reverb tail over the head."""
    mix, stems = master(
        {n: render(n, t) for n, t in T.items()},
        shelf=(0.22, 80), drive=1.08, peak=0.84,
        fade_in=(1.0, 1.2), fade_out=(3.4, 1.6),
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
    ap.add_argument('--loop', action='store_true',
                    help='no fade-out; wrap the reverb tail back over the head')
    ap.add_argument('--hp', type=float, default=None, help='bus high-pass, Hz')
    a = ap.parse_args()
    m, _ = build(a.out, loop=a.loop, highpass=a.hp)
    print('warm%s  %.3f s  peak %.3f' % (
        '_loop' if a.loop else '', m.shape[1]/SR, np.max(np.abs(m))))
