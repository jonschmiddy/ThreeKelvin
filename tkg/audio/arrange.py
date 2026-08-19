import numpy as np, os
np.random.seed(1729)          # renders are deterministic
import synth; synth.set_tempo(142)
from synth import *
from motif import MOTIF, INVERT, bar as bb, octave as at_oct, augment

BARS = 72

# ---------------- harmony ----------------
# A / A' cycle : i - bVI - iv - bVII   (F minor, Aeolian)
A_CYCLE = [
    (['F3','Ab3','C4','F4'],   'F2'),
    (['Db3','F3','Ab3','C4'],  'Db2'),
    (['Bb2','Db3','F3','Ab3'], 'Bb1'),
    (['Eb3','G3','Bb3','Eb4'], 'Eb2'),
]
# B : F Dorian (D natural) -> i9 - IV - bVI - bVII
B_CYCLE = [
    (['F3','Ab3','C4','G4'],   'F2'),
    (['Bb2','D3','F3','Bb3'],  'Bb1'),
    (['Ab2','C3','Eb3','G3'],  'Ab1'),
    (['Eb3','G3','Bb3','F4'],  'Eb2'),
]
C_CHORDS = [(['Db3','F3','Ab3','C4'], 'Db2'), (['C3','Eb3','G3','C4'], 'C2')]

tracks = {k: Track(BARS) for k in
          ['whistle','lead','pad','bass','arp','perc','bell','fx']}

# ================= INTRO : bars 1-8 =================
# Motif alone in the ORIGINAL recorded register (F6), ping-pong delay.
for i, bar in enumerate([1, 3, 5, 7]):
    for n, b, d in at_oct(MOTIF, 6):
        tracks['whistle'].add(whistle(hz(n), d*SPB*0.94, 0.50),
                              bb(bar)+b, pan=-0.25+0.16*i)
for bar, (v, r) in zip([5, 7], [A_CYCLE[0], A_CYCLE[1]]):
    tracks['pad'].add(pad([hz(x) for x in v], 2*BAR, 0.22, 1500), bb(bar))
tracks['fx'].add(noise_swell(2*BAR, 0.12), bb(7))

# ================= A : bars 9-24 =================
# Same 5 notes, 4 harmonic colours. Melody static, harmony moves.
for rep in range(2):
    for c in range(4):
        bar = 9 + rep*8 + c*2
        v, root = A_CYCLE[c]
        tracks['pad'].add(pad([hz(x) for x in v], 2*BAR, 0.30, 2000), bb(bar))
        for k in range(4):                                  # bass: dotted pulse
            tracks['bass'].add(sub(hz(root), SPB*0.9, 0.55), bb(bar)+k*2)
        for n, b, d in at_oct(MOTIF, 5):
            tracks['lead'].add(whistle(hz(n), d*SPB*0.96, 0.42), bb(bar)+b, pan=0.05)
        if rep == 1:                                        # octave sparkle on 2nd pass
            for n, b, d in at_oct(MOTIF, 6):
                tracks['bell'].add(bell(hz(n), d*SPB*1.4, 0.16), bb(bar)+b, pan=0.4)
    # half-time drums
    for bar in range(9+rep*8, 17+rep*8):
        tracks['perc'].add(kick(0.75), bb(bar))
        tracks['perc'].add(snare(0.42), bb(bar)+2)
        for k in range(8):
            tracks['perc'].add(hat(0.05, 0.12+0.05*(k % 2 == 0)), bb(bar)+k*0.5,
                               pan=0.3 if k % 2 else -0.3)

# ================= B : bars 25-40 =================
# Modal lift to F Dorian, motif inverted, arp + full drums.
pluck_cache = {}
def pk(f, d, a):
    key = (round(f, 2), round(d, 3))
    if key not in pluck_cache:
        pluck_cache[key] = pluck(f, d, 1.0)
    return pluck_cache[key]*a

for rep in range(2):
    for c in range(4):
        bar = 25 + rep*8 + c*2
        v, root = B_CYCLE[c]
        tracks['pad'].add(pad([hz(x) for x in v], 2*BAR, 0.26, 2600), bb(bar))
        for k in range(8):
            tracks['bass'].add(sub(hz(root), SPB*0.85, 0.60), bb(bar)+k)
        # 16th arpeggio, up-down over chord tones
        order = [0, 1, 2, 3, 2, 1]
        for s in range(32):
            f = hz(v[order[s % len(order)]])*(2 if s % 12 > 8 else 1)
            tracks['arp'].add(pk(f, 0.38, 0.13), bb(bar)+s*0.25,
                              pan=-0.45+0.9*((s % 6)/5))
        seq = INVERT if rep == 0 else MOTIF
        for n, b, d in at_oct(seq, 5):
            tracks['lead'].add(whistle(hz(n), d*SPB*0.96, 0.44), bb(bar)+b, pan=-0.05)
    for bar in range(25+rep*8, 33+rep*8):
        tracks['perc'].add(kick(0.85), bb(bar))
        tracks['perc'].add(kick(0.62), bb(bar)+2.5)
        tracks['perc'].add(snare(0.55), bb(bar)+1)
        tracks['perc'].add(snare(0.55), bb(bar)+3)
        for k in range(16):
            tracks['perc'].add(hat(0.04, 0.10+0.06*(k % 4 == 0)), bb(bar)+k*0.25,
                               pan=0.35 if k % 2 else -0.35)

# ================= C bridge : bars 41-48 =================
# Augmentation: the motif at half speed. Everything else drops out.
for i, bar in enumerate([41, 45]):
    v, root = C_CHORDS[i]
    tracks['pad'].add(pad([hz(x) for x in v], 4*BAR, 0.34, 1300), bb(bar))
    for k in range(4):
        tracks['bass'].add(sub(hz(root), SPB*3.4, 0.42), bb(bar)+k*4)
    for n, b, d in augment(at_oct(MOTIF, 5), 2):
        tracks['lead'].add(whistle(hz(n), d*SPB*0.9, 0.40), bb(bar)+b, pan=0.0)
    for n, b, d in augment(at_oct(MOTIF, 6), 2):
        tracks['bell'].add(bell(hz(n), d*SPB*1.1, 0.13), bb(bar)+b+0.5, pan=-0.35)
tracks['fx'].add(noise_swell(2*BAR, 0.16), bb(47))

# ================= A' : bars 49-64 =================
# Full tutti. Motif in canon with itself, one octave down, two beats late.
for rep in range(2):
    for c in range(4):
        bar = 49 + rep*8 + c*2
        v, root = A_CYCLE[c]
        tracks['pad'].add(pad([hz(x) for x in v], 2*BAR, 0.30, 3000), bb(bar))
        for k in range(8):
            tracks['bass'].add(sub(hz(root), SPB*0.8, 0.62), bb(bar)+k)
        for n, b, d in at_oct(MOTIF, 5):                      # dux
            tracks['lead'].add(whistle(hz(n), d*SPB*0.96, 0.46), bb(bar)+b, pan=-0.2)
        for n, b, d in at_oct(MOTIF, 4):                      # comes, +2 beats
            tracks['lead'].add(whistle(hz(n), d*SPB*0.96, 0.30), bb(bar)+b+2, pan=0.3)
        for n, b, d in at_oct(MOTIF, 6):
            tracks['bell'].add(bell(hz(n), d*SPB*1.5, 0.19), bb(bar)+b, pan=0.45)
        order = [0, 2, 1, 3, 2, 0]
        for s in range(32):
            tracks['arp'].add(pk(hz(v[order[s % 6]]), 0.34, 0.11), bb(bar)+s*0.25,
                              pan=0.45-0.9*((s % 6)/5))
    for bar in range(49+rep*8, 57+rep*8):
        tracks['perc'].add(kick(0.92), bb(bar))
        tracks['perc'].add(kick(0.70), bb(bar)+2.5)
        tracks['perc'].add(kick(0.55), bb(bar)+3.5)
        tracks['perc'].add(snare(0.60), bb(bar)+1)
        tracks['perc'].add(snare(0.60), bb(bar)+3)
        for k in range(16):
            tracks['perc'].add(hat(0.04, 0.11+0.07*(k % 4 == 0)), bb(bar)+k*0.25,
                               pan=0.35 if k % 2 else -0.35)

# ================= OUTRO : bars 65-72 =================
v, root = A_CYCLE[0]
tracks['pad'].add(pad([hz(x) for x in v], 8*BAR, 0.30, 1100), bb(65))
for k in range(6):
    tracks['bass'].add(sub(hz(root), SPB*1.6, 0.50*(1-k/7)), bb(65)+k*2)
for bar in [65, 66, 67]:
    tracks['perc'].add(kick(0.55), bb(bar))
    tracks['perc'].add(snare(0.30), bb(bar)+2)
for n, b, d in at_oct(MOTIF, 5):
    tracks['lead'].add(whistle(hz(n), d*SPB*0.96, 0.38), bb(65)+b, pan=-0.1)
for n, b, d in augment(at_oct(MOTIF, 6), 2):       # last word: original register
    tracks['whistle'].add(whistle(hz(n), d*SPB*1.0, 0.44), bb(69)+b, pan=0.0)
tracks['whistle'].add(whistle(hz('F6'), 3.2, 0.30), bb(72)+2)

# ---------------- mix ----------------

FX = {  # (reverb wet, delay time in beats or None, level)
    'whistle': (0.42, 0.75, 1.00),
    'lead':    (0.30, 0.75, 1.00),
    'pad':     (0.45, None, 0.95),
    'bass':    (0.05, None, 1.00),
    'arp':     (0.34, 0.50, 0.85),
    'perc':    (0.14, None, 0.95),
    'bell':    (0.50, 1.50, 0.80),
    'fx':      (0.55, None, 0.80),
}

def render(name, tr):
    y = tr.out()
    wet, dl, lvl = FX[name]
    if dl: y = delay(y, dl*SPB, fb=0.40, mix=0.28)
    y = reverb(y, wet)*lvl
    if name == 'bass': y = lp(y, 220, 2)*1.0 + hp(y, 220, 2)*0.35
    return y

def build(out_dir='out', loop=False, highpass=None):
    """loop=True drops the fade-out and wraps the reverb tail over the head."""
    mix, stems = master(
        {n: render(n, t) for n, t in tracks.items()},
        shelf=(0.25, 90), drive=1.25, peak=0.89,
        fade_in=(0.05, 1.0), fade_out=(2.6, 1.6),
        highpass=highpass,
        loop_len=int(BARS*BAR*SR) if loop else None)
    tag = '_loop' if loop else ''
    write_wav('%s/theme%s.wav' % (out_dir, tag), mix)
    for n, y in stems.items():
        write_wav('%s/stems%s/%s.wav' % (out_dir, tag, n), y)
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
    print('theme%s  %.3f s  peak %.3f' % (
        '_loop' if a.loop else '', m.shape[1]/SR, np.max(np.abs(m))))
