"""'Caffe Sospeso' -- standalone piece, NOT part of the Three Kelvin album.

THE BRIEF (pinned before the refinement loop; the loop serves this, not the
listener's taste):  Easy-listening Italian cafe jazz, ~3:00.  Small combo:
brushed drums, upright-style pizzicato bass walking, soft piano comping,
mellow clean guitar carrying the tune, flute on the bridge, vibraphone
accents.  Medium-soft swing around 96 BPM, major key, warm and relaxed --
background music that rewards attention but never demands it.  No harsh
sounds, gentle dynamics, melody clearly audible but never loud.

    TK_VOICES=sampled python3 caffe.py --out out_caffe
"""
import numpy as np
np.random.seed(52)
import synth; synth.set_tempo(96)
from synth import *
from motif import bar as bb
import sampler

BARS = 72                                    # 72 x 2.5 s = 180 s

# combo, straight from the cupboards -- including the SAMPLED kit the album
# never used (the env gate kept it on oscillators; here we take the real one)
_pf   = sampler._piano()
_bs   = sampler._pizz()                      # cello section pizz, played low
_gt   = sampler._eguitar()                   # the DI guitar, clean = jazz
_fl   = sampler._flute()
_vb   = sampler._vibes()
kick, snare, hat = sampler.kick, sampler.snare, sampler.hat

def sw(b):
    """Swing: the off-eighth sits at 62%, not 50%."""
    f = b % 1
    return b - f + 0.62 if abs(f - 0.5) < 0.01 else b

# --- harmony: AABA in F -----------------------------------------------
CH = {
    'F':   ['F3', 'A3', 'C4', 'E4'],         # Fmaj7
    'F7':  ['F3', 'A3', 'Eb4', 'C4'],
    'Gm':  ['G3', 'Bb3', 'D4', 'F4'],
    'C7':  ['G3', 'Bb3', 'C4', 'E4'],
    'Am':  ['A3', 'C4', 'E4', 'G4'],
    'Dm':  ['D3', 'F3', 'A3', 'C4'],
    'Bb':  ['Bb3', 'D4', 'F4', 'A4'],
    'Bbm': ['Bb3', 'Db4', 'F4', 'G4'],       # Bbm6
    'D7':  ['D3', 'F#3', 'A3', 'C4'],
    'Cm':  ['C4', 'Eb4', 'G4', 'Bb3'],
}
ROOT = {'F': 'F2', 'F7': 'F2', 'Gm': 'G2', 'C7': 'C2', 'Am': 'A2',
        'Dm': 'D2', 'Bb': 'Bb2', 'Bbm': 'Bb2', 'D7': 'D2', 'Cm': 'C2'}
FIFTH = {'F': 'C3', 'F7': 'C3', 'Gm': 'D3', 'C7': 'G2', 'Am': 'E3',
         'Dm': 'A2', 'Bb': 'F3', 'Bbm': 'F3', 'D7': 'A2', 'Cm': 'G2'}

A_SEC = [['F'], ['Gm', 'C7'], ['F'], ['Cm', 'F7'],
         ['Bb'], ['Bbm'], ['Am', 'Dm'], ['Gm', 'C7']]
B_SEC = [['Am'], ['D7'], ['Gm'], ['C7'], ['Am'], ['D7'], ['Gm'], ['C7']]

# --- the tune (A, 8 bars; beats within the section) -------------------
TUNE_A = [
    ('C5', 0, 1), ('A4', 1, 0.5), ('F4', 1.5, 0.5), ('G4', 2, 2),
    ('A4', 4.5, 0.5), ('G4', 5, 0.5), ('F4', 5.5, 0.5), ('D4', 6, 2),
    ('F4', 8, 1), ('G4', 9, 0.5), ('A4', 9.5, 0.5), ('C5', 10, 2),
    ('Bb4', 12.5, 0.5), ('A4', 13, 0.5), ('G4', 13.5, 0.5), ('A4', 14, 2),
    ('A4', 16.5, 0.5), ('C5', 17, 1), ('D5', 18, 2),
    ('Db5', 20, 1), ('C5', 21, 1), ('Bb4', 22, 2),
    ('A4', 24, 1.5), ('F4', 25.5, 0.5), ('G4', 26, 1), ('A4', 27, 1),
    ('G4', 28, 3.5),
]
# the bridge (flute)
TUNE_B = [
    ('E5', 0, 1.5), ('C5', 1.5, 0.5), ('A4', 2, 2),
    ('D5', 4, 1.5), ('A4', 5.5, 0.5), ('F#4', 6, 2),
    ('Bb4', 8, 1), ('D5', 9, 1), ('G4', 10, 2),
    ('C5', 12, 1), ('Bb4', 13, 0.5), ('A4', 13.5, 0.5), ('G4', 14, 2),
    ('E5', 16, 1.5), ('C5', 17.5, 0.5), ('A4', 18, 2),
    ('D5', 20, 1.5), ('F#4', 21.5, 0.5), ('A4', 22, 2),
    ('Bb4', 24, 1), ('C5', 25, 1), ('D5', 26, 1), ('E5', 27, 1),
    ('F5', 28, 2), ('C5', 30, 2),
]
# the solo chorus (guitar, 16 bars -- paraphrase, not bebop; space is money)
SOLO = [
    ('A4', 0.5, 0.5), ('C5', 1, 0.5), ('D5', 1.5, 1.5),
    ('C5', 4, 0.5), ('A4', 4.5, 0.5), ('G4', 5, 0.5), ('A4', 5.5, 2),
    ('F4', 8.5, 0.5), ('G4', 9, 0.5), ('A4', 9.5, 0.5), ('C5', 10, 1.5),
    ('D5', 12, 0.5), ('C5', 12.5, 0.5), ('A4', 13, 0.5), ('G4', 13.5, 2.5),
    ('A4', 16.5, 0.5), ('C5', 17, 0.5), ('D5', 17.5, 0.5), ('F5', 18, 1.5),
    ('E5', 20, 0.5), ('D5', 20.5, 0.5), ('Db5', 21, 0.5), ('C5', 21.5, 1.5),
    ('A4', 24, 0.5), ('C5', 24.5, 0.5), ('B4', 25, 0.5), ('C5', 25.5, 1),
    ('G4', 27, 0.5), ('A4', 27.5, 0.5),
    ('F4', 28, 1), ('G4', 29, 0.5), ('A4', 29.5, 2),
    ('C5', 32.5, 0.5), ('D5', 33, 0.5), ('E5', 33.5, 1.5),
    ('D5', 36, 0.5), ('C5', 36.5, 0.5), ('A4', 37, 0.5), ('C5', 37.5, 2),
    ('Bb4', 40.5, 0.5), ('A4', 41, 0.5), ('G4', 41.5, 0.5), ('F4', 42, 1.5),
    ('D4', 44, 0.5), ('F4', 44.5, 0.5), ('G4', 45, 0.5), ('A4', 45.5, 2.5),
    ('C5', 48.5, 0.5), ('A4', 49, 0.5), ('G4', 49.5, 0.5), ('A4', 50, 1),
    ('F4', 52, 0.5), ('G4', 52.5, 0.5), ('A4', 53, 0.5), ('C5', 53.5, 1),
    ('D5', 56, 1), ('C5', 57, 0.5), ('A4', 57.5, 0.5), ('G4', 58, 2),
    ('F4', 60.5, 0.5), ('G4', 61, 0.5), ('A4', 61.5, 0.5), ('G4', 62, 1.5),
]

T = {k: Track(BARS) for k in
     ['bass', 'drums', 'piano', 'guitar', 'flute', 'vibes']}

def comp(sec, bar0, amp=0.24):
    """Piano comping: the Charleston -- beat 1 short, and-of-2 held."""
    for i, chords in enumerate(sec):
        for j, c in enumerate(chords):
            fr = [hz(x) for x in CH[c]]
            at = bb(bar0+i) + j*2
            T['piano'].add(_pf.chord(fr, 0.5*SPB, amp*0.8), at + sw(0.5)*0)
            T['piano'].add(_pf.chord(fr, 1.4*SPB, amp), at + sw(1.5))

def walk(sec, bar0, amp=0.55):
    """Bass: root, fifth, chord tone, approach -- quarters."""
    for i, chords in enumerate(sec):
        c0 = chords[0]
        c1 = chords[-1]
        nxt = sec[(i+1) % len(sec)][0]
        line = [ROOT[c0], FIFTH[c0], ROOT[c1] if len(chords) > 1 else CH[c0][1][:-1]+'2',
                FIFTH[c1]]
        # approach the next root chromatically from below on beat 4
        tgt = hz(ROOT[nxt])
        line[3] = tgt / 2**(1/12.0)
        for k, n in enumerate(line):
            f = hz(n) if isinstance(n, str) else n
            T['bass'].add(_bs.note(f, 0.9*SPB, amp), bb(bar0+i)+k)

def brushes(bar, fill=False):
    T['drums'].add(kick(0.55), bb(bar))
    T['drums'].add(kick(0.40), bb(bar)+2)
    T['drums'].add(snare(0.26), bb(bar)+1)
    T['drums'].add(snare(0.30), bb(bar)+3)
    for k in (0, 1, sw(1.5), 2, 3, sw(3.5)):
        T['drums'].add(hat(0.05, 0.26+0.10*(k in (1, 3))), bb(bar)+k,
                       pan=0.2)
    if fill:
        for k in range(3):
            T['drums'].add(snare(0.20+0.06*k), bb(bar)+3+k*0.33)

def tune(seq, bar0, door, amp, pan=0.0, mul=1):
    for n, b, d in seq:
        T[door if isinstance(door, str) else 'guitar']
    pass

def play(seq, bar0, track, note_fn, amp, pan=0.0):
    for n, b, d in seq:
        T[track].add(note_fn(hz(n), d*SPB*0.95, amp), bb(bar0)+sw(b), pan=pan)

gnote = lambda f, d, a: _gt.note(f, d, a)
fnote = lambda f, d, a: _fl.note(f, d, a)
vnote = lambda f, d, a: _vb.note(f, d, a)

# --- form -------------------------------------------------------------
# intro: piano alone, then brushes slip in
comp([['Gm', 'C7'], ['F'], ['Gm', 'C7'], ['F']], 1, amp=0.26)
walk([['Gm', 'C7'], ['F']], 3, amp=0.45)
brushes(3); brushes(4)

SECTIONS = [(A_SEC, 5), (A_SEC, 13), (B_SEC, 21), (A_SEC, 29),
            (A_SEC, 37), (A_SEC, 45), (B_SEC, 53), (A_SEC, 61)]
for sec, bar0 in SECTIONS:
    comp(sec, bar0)
    walk(sec, bar0)
    for i in range(8):
        brushes(bar0+i, fill=(i == 7 and bar0 not in (61,)))

play(TUNE_A, 5, 'guitar', gnote, 0.46)
play(TUNE_A, 13, 'guitar', gnote, 0.46)
play(TUNE_B, 21, 'flute', fnote, 0.30, pan=0.15)
play(TUNE_A, 29, 'guitar', gnote, 0.46)
play(SOLO, 37, 'guitar', gnote, 0.44)
play(TUNE_B, 53, 'flute', fnote, 0.30, pan=0.15)
play(TUNE_A, 61, 'guitar', gnote, 0.48)

# vibes: a held colour tone at each section door, and answers in A2
for _, bar0 in SECTIONS:
    T['vibes'].add(vnote(hz('A4'), 3*SPB, 0.34), bb(bar0), pan=-0.3)
for bar, beat, n in ((15, 2, 'C5'), (17, sw(2.5), 'D5'), (19, 2, 'Bb4')):
    T['vibes'].add(vnote(hz(n), 2*SPB, 0.36), bb(bar)+beat, pan=-0.3)

# outro: tag ii-V, land the tonic, let it ring
comp([['Gm', 'C7'], ['Gm', 'C7'], ['F']], 69, amp=0.26)
walk([['Gm', 'C7'], ['F']], 69, amp=0.42)
brushes(69); brushes(70)
T['piano'].add(_pf.chord([hz(x) for x in CH['F']], 8*SPB, 0.30), bb(71))
T['bass'].add(_bs.note(hz('F2'), 6*SPB, 0.5), bb(71))
T['vibes'].add(vnote(hz('C5'), 6*SPB, 0.2), bb(71), pan=-0.2)
T['guitar'].add(gnote(hz('A4'), 5*SPB, 0.3), bb(71)+sw(0.5))

FX = {'bass': (0.10, None, 1.0), 'drums': (0.14, None, 2.6),
      'piano': (0.18, None, 1.0), 'guitar': (0.16, None, 1.0),
      'flute': (0.22, None, 1.0), 'vibes': (0.25, None, 2.8)}

def render(name, tr):
    y = tr.out()
    wet, dl, lvl = FX[name]
    y = reverb(y, wet)*lvl
    if name == 'guitar': y = lp(y, 6000, 2)     # mellow the DI top
    if name == 'drums': y = hp(y, 60, 2)*1.0 + lp(y, 60, 2)*0.4
    return y

if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='out_caffe')
    a = ap.parse_args()
    mix, stems = master({n: render(n, t) for n, t in T.items()},
                        shelf=(0.15, 90), drive=1.05, peak=0.52,
                        fade_in=(0.05, 0.8), fade_out=(3.0, 2.5))
    write_wav('%s/caffe.wav' % a.out, mix)
    for n, y in stems.items():
        write_wav('%s/caffe_stems/%s.wav' % (a.out, n), y)
    print('caffe  %.1f s  peak %.3f' % (mix.shape[1]/SR, np.max(np.abs(mix))))
