"""'Golden Hour' -- standalone piece, not part of the album.

THE BRIEF (pinned, corrected by the listener-in-chief): a classic jazz
quartet is horn + chords + bass + drums.  Here: harmon-muted trumpet,
piano playing REAL CHORDS (full comping voicings, left-hand shells under
its solo), upright-style bass, brushed kit.  A jazz waltz (3/4) around 144 BPM in G major with
lydian color.  Spring flowers, golden skies: lyrical, warm, sunlit,
optimistic.  Flute sings the head, piano takes a real solo chorus, head out.
Gentle dynamics, nothing harsh, melody clearly leading.  ~3:00.

    TK_VOICES=sampled python3 golden.py --out out_golden
"""
import numpy as np
np.random.seed(33)
import synth; synth.set_tempo(144)
from synth import *
import sampler

_pf = sampler._piano()
_bs = sampler._pizz()
_tp = sampler.trumpet
kick, snare, hat = sampler.kick, sampler.snare, sampler.hat

def down8(seq):
    return [(n[:-1] + str(int(n[-1]) - 1), b, d) for n, b, d in seq]

def b3(bar):
    """3/4: bar n starts at beat 3(n-1)."""
    return (bar - 1)*3.0

# The conductor: a slow shared drift in the time feel, +/-25 ms over a
# couple of bars.  Track.add already gives each player a private 5 ms
# wander; this is the other half of "playing together" -- the whole band
# leaning into and out of the time as one.
_DRIFT_N = 4096
_dr = np.cumsum(np.random.randn(_DRIFT_N))*0.010
_dr -= np.linspace(_dr[0], _dr[-1], _DRIFT_N)
_dr = np.convolve(_dr, np.ones(24)/24, 'same')
_dr = np.clip(_dr, -0.10, 0.10)
def W(beat):
    i = min(int(beat), _DRIFT_N - 1)
    return beat + _dr[i]

def sw(b):
    f = b % 1
    return b - f + 0.62 if abs(f - 0.5) < 0.01 else b

# --- changes: 32-bar AABA waltz in G ----------------------------------
CH = {
    'G':   ['G3', 'B3', 'D4', 'F#4'],
    'Am':  ['A3', 'C4', 'E4', 'G4'],
    'D7':  ['A3', 'C4', 'D4', 'F#4'],
    'Bm':  ['B3', 'D4', 'F#4', 'A4'],
    'E7':  ['B3', 'D4', 'E4', 'G#4'],
    'C':   ['C4', 'E4', 'G4', 'B4'],
    'Cm':  ['C4', 'Eb4', 'G4', 'A4'],       # Cm6
    'A7':  ['A3', 'C#4', 'E4', 'G4'],
}
ROOT = {'G': 'G2', 'Am': 'A2', 'D7': 'D2', 'Bm': 'B2', 'E7': 'E2',
        'C': 'C3', 'Cm': 'C3', 'A7': 'A2'}
FIFTH = {'G': 'D3', 'Am': 'E3', 'D7': 'A2', 'Bm': 'F#3', 'E7': 'B2',
         'C': 'G2', 'Cm': 'G2', 'A7': 'E3'}

A1 = ['G', 'G', 'Am', 'D7', 'Bm', 'E7', 'Am', 'D7']
A2 = ['G', 'G', 'Am', 'D7', 'Bm', 'E7', 'Am', 'G']
B  = ['C', 'Cm', 'Bm', 'E7', 'A7', 'A7', 'Am', 'D7']
CHORUS = A1 + A1 + B + A2                        # 32 bars of 3

# --- the head (beats within a 96-beat chorus) -------------------------
# The head, as a horn player has it: PHRASES.  Each is one breath -- an
# entry a hair late (the inhale), an arc through the middle, an early
# release at the end (the exhale).  The rests are not empty; they are
# where the band answers.
PHR_A = [
    (0,  [('D4', 0, 1), ('G4', 1, 1), ('B4', 2, 1), ('A4', 3, 1.6),
          ('F#4', 5, 0.8)]),
    (6,  [('C5', 0, 1), ('B4', 1, 1), ('A4', 2, 1), ('D5', 3, 2.5)]),
    (12, [('D5', 0, 1), ('C#5', 1, 1), ('D5', 2, 1), ('E5', 3, 1.7),
          ('B4', 5, 0.8)]),
    (18, [('C5', 0, 1), ('A4', 1, 1), ('F#4', 2, 1), ('A4', 3, 2.2)]),
]
PHR_A_END = PHR_A[:3] + [
    (18, [('C5', 0, 1), ('A4', 1, 1), ('B4', 2, 0.5), ('A4', 2.5, 0.5),
          ('G4', 3, 2.4)]),
]
PHR_B = [
    (0,  [('E5', 0, 1.8), ('G5', 2, 0.8)]),
    (3,  [('F#5', 0, 1.8), ('Eb5', 2, 0.8)]),
    (6,  [('D5', 0, 1.8), ('F#5', 2, 0.8)]),
    (9,  [('G#5', 0, 1.8), ('E5', 2, 0.8)]),
    (12, [('C#5', 0, 1), ('E5', 1, 1), ('G5', 2, 1), ('F#5', 3, 2.5)]),
    (18, [('E5', 0, 1), ('C5', 1, 1), ('B4', 2, 1), ('A4', 3, 2.2)]),
]

def down8p(phr):
    return [(st, [(n[:-1] + str(int(n[-1]) - 1), b, d) for n, b, d in ph])
            for st, ph in phr]

def head_phrases():
    out = []
    # everything down an octave: the mute's recorded range is A#2-A4, and
    # the old top (E5, resampled +7 semitones) was the shrillness itself.
    # The bridge keeps its register, so it now lifts ABOVE the verse.
    for off, phr in ((0, down8p(PHR_A)), (24, down8p(PHR_A)),
                     (48, down8p(PHR_B)), (72, down8p(PHR_A_END))):
        out += [(off + st, ph) for st, ph in phr]
    return out

# --- piano solo chorus: lyrical single-note lines with air ------------
PSOLO = [
    ('B4', 0.5, 0.5), ('D5', 1, 0.5), ('G5', 1.5, 1.5),
    ('F#5', 3.5, 0.5), ('E5', 4, 0.5), ('D5', 4.5, 1.5),
    ('C5', 6.5, 0.5), ('E5', 7, 0.5), ('A4', 7.5, 1.5),
    ('F#4', 9.5, 0.5), ('A4', 10, 0.5), ('C5', 10.5, 1.5),
    ('D5', 12.5, 0.5), ('F#5', 13, 0.5), ('A5', 13.5, 1.5),
    ('G#5', 15.5, 0.5), ('E5', 16, 0.5), ('B4', 16.5, 1.5),
    ('C5', 18.5, 0.5), ('B4', 19, 0.5), ('A4', 19.5, 1),
    ('F#4', 21, 0.5), ('A4', 21.5, 0.5), ('D5', 22, 1),
    ('G4', 24.5, 0.5), ('B4', 25, 0.5), ('D5', 25.5, 1.5),
    ('E5', 27.5, 0.5), ('D5', 28, 0.5), ('B4', 28.5, 1.5),
    ('A4', 30.5, 0.5), ('C5', 31, 0.5), ('E5', 31.5, 1.5),
    ('D5', 33.5, 0.5), ('C5', 34, 0.5), ('A4', 34.5, 1.5),
    ('B4', 36.5, 0.5), ('D5', 37, 0.5), ('F#5', 37.5, 1),
    ('E5', 39, 1), ('G#4', 40, 0.5), ('B4', 40.5, 1),
    ('A4', 42, 0.5), ('B4', 42.5, 0.5), ('C5', 43, 0.5), ('E5', 43.5, 1),
    ('D5', 45, 1.5), ('A4', 46.5, 1.5),
    ('E5', 48.5, 0.5), ('G5', 49, 0.5), ('B5', 49.5, 1.5),
    ('A5', 51.5, 0.5), ('G5', 52, 0.5), ('Eb5', 52.5, 1.5),
    ('D5', 54.5, 0.5), ('F#5', 55, 0.5), ('A5', 55.5, 1),
    ('G#5', 57, 1), ('E5', 58, 1),
    ('C#5', 60.5, 0.5), ('E5', 61, 0.5), ('G5', 61.5, 1),
    ('F#5', 63, 2),
    ('E5', 66, 0.5), ('D5', 66.5, 0.5), ('C5', 67, 0.5), ('B4', 67.5, 1),
    ('A4', 69, 1), ('C5', 70, 0.5), ('F#4', 70.5, 1.5),
    ('G4', 72.5, 0.5), ('B4', 73, 0.5), ('D5', 73.5, 1.5),
    ('C5', 75.5, 0.5), ('B4', 76, 0.5), ('A4', 76.5, 1.5),
    ('B4', 78.5, 0.5), ('C5', 79, 0.5), ('E5', 79.5, 1.5),
    ('D5', 81.5, 1), ('A4', 82.5, 1.5),
    ('B4', 84.5, 0.5), ('D5', 85, 0.5), ('F#5', 85.5, 1),
    ('E5', 87, 1), ('B4', 88, 1),
    ('C5', 90, 1), ('A4', 91, 0.5), ('B4', 91.5, 0.5), ('A4', 92, 0.5),
    ('G4', 92.5, 2.5),
]

TOTAL_BEATS = 12 + 4*96 + 18
T = {k: Track(int(TOTAL_BEATS/4) + 3) for k in
     ['bass', 'drums', 'piano', 'horn']}

def comp(bar0, chorus, amp=0.26, skip=()):
    """Comping as a vocabulary, not a pattern: push-and-stab, a lone push,
    a held color, a late stab -- and sometimes the pianist just LISTENS.
    Identical gestures every bar for 32 bars is the loudest possible tell
    that nobody is in the room."""
    for i, c in enumerate(chorus):
        if i in skip: continue
        fr = [hz(x) for x in CH[c]] + [hz(CH[c][1])*2]
        at = b3(bar0 + i)
        g = amp*np.random.uniform(0.85, 1.1)
        r = np.random.rand()
        if r < 0.30:
            T['piano'].add(_pf.chord(fr, 1.2*SPB, g), W(at + sw(1.5)))
            T['piano'].add(_pf.chord(fr[:4], 0.6*SPB, g*0.7), W(at + sw(2.5)))
        elif r < 0.55:
            T['piano'].add(_pf.chord(fr, 1.1*SPB, g), W(at + sw(1.5)))
        elif r < 0.75:
            T['piano'].add(_pf.chord(fr[:4], 2.2*SPB, g*0.8), W(at + sw(0.5)))
        elif r < 0.90:
            T['piano'].add(_pf.chord(fr[:4], 0.7*SPB, g*0.85), W(at + 2))
        # else: lay out

def walk(bar0, chorus, amp=0.62):
    for i, c in enumerate(chorus):
        nxt = chorus[(i + 1) % len(chorus)]
        g = amp*np.random.uniform(0.88, 1.08)
        r = np.random.rand()
        T['bass'].add(_bs.note(hz(ROOT[c]), (2.7 if r < 0.15 else 1.8)*SPB, g),
                      W(b3(bar0 + i)))
        if r >= 0.15:
            third = hz(ROOT[nxt]) / 2**(1/12.0) if nxt != c else hz(FIFTH[c])
            T['bass'].add(_bs.note(third, 0.9*SPB, g*0.8),
                          W(b3(bar0 + i) + (sw(1.5) if r > 0.8 else 2)))

def waltz_brushes(bar, accent=False):
    r = np.random.rand()
    if r > 0.08:                                  # even the kick breathes
        T['drums'].add(kick(0.50*np.random.uniform(0.85, 1.1)), W(b3(bar)))
    if r < 0.6:
        T['drums'].add(snare(0.20 + 0.08*accent), W(b3(bar) + 1))
    else:
        T['drums'].add(snare(0.16), W(b3(bar) + 2))
    pat = ((0, 1, sw(1.5), 2), (0, 1, 2), (0, sw(0.5), 1, 2))[
        int(np.random.rand()*3)]
    for k in pat:
        T['drums'].add(hat(0.05, (0.24 + 0.10*(k == 0))
                       * np.random.uniform(0.8, 1.15)), W(b3(bar) + k),
                       pan=0.2)

def play(seq, bar0, track, note_fn, amp, pan=0.0):
    for n, b, d in seq:
        T[track].add(note_fn(hz(n), d*SPB*0.95, amp), W(b3(bar0) + sw(b)),
                     pan=pan)

def sing(phrases, bar0, track, note_fn, amp, pan=0.0, answer=True):
    """Phrases, breathed: late entries, arced dynamics, early releases --
    and in each breath, someone answers: a piano fill, a brush accent, or
    (best of all) nothing."""
    for start, notes in phrases:
        breath = np.random.uniform(0.08, 0.22)
        n = len(notes)
        for i, (nm, b, d) in enumerate(notes):
            arc = 0.78 + 0.38*np.sin(np.pi*(i + 0.6)/n)
            dur = d*(0.72 if i == n - 1 else 0.94)
            T[track].add(note_fn(hz(nm), dur*SPB, amp*arc),
                         W(b3(bar0) + sw(start + b) + (breath if i == 0 else 0)),
                         pan=pan)
        if not answer:
            continue
        last = notes[-1]
        gap = start + last[1] + last[2]*0.8
        bar_i = int((b3(bar0) + gap - b3(1)) // 3 - (bar0 - 1))
        r = np.random.rand()
        if r < 0.45:
            c = CHORUS[min(max(bar_i, 0), 31)]
            v = CH[c]
            for j, x in enumerate((v[2], v[3], v[1])):
                T['piano'].add(_pf.note(hz(x)*2, 0.6*SPB, 0.22 - 0.03*j),
                               W(b3(bar0) + sw(gap + 0.5 + j*0.5)), pan=0.25)
        elif r < 0.72:
            T['drums'].add(snare(0.24), W(b3(bar0) + gap + 0.6))

hnote = lambda f, d, a: sampler._eguitar().note(f, d, a)   # the clean guitar takes the head
pnote = lambda f, d, a: _pf.note(f, d, a) * 0.9

# --- form: intro 4 / head / piano solo / head out / coda 6 ------------
T['piano'].add(_pf.chord([hz(x) for x in CH['Am']], 1.2*SPB, 0.22), b3(1) + 1)
T['piano'].add(_pf.chord([hz(x) for x in CH['D7']], 1.2*SPB, 0.22), b3(2) + 1)
T['piano'].add(_pf.chord([hz(x) for x in CH['G']], 2.0*SPB, 0.24), b3(3))
walk(3, ['Am', 'D7'], amp=0.46)
waltz_brushes(3); waltz_brushes(4)

for ch_i, bar0 in enumerate((5, 37, 69, 101)):
    comp(bar0, CHORUS)
    walk(bar0, CHORUS)
    for i in range(32):
        waltz_brushes(bar0 + i, accent=(i % 8 == 7))

sing(head_phrases(), 5, 'horn', hnote, 0.62)
play(PSOLO, 37, 'piano', pnote, 0.42)
for i, c in enumerate(CHORUS):                     # left hand under the solo
    fr = [hz(CH[c][0]), hz(CH[c][3])]              # root + seventh shells
    T['piano'].add(_pf.chord(fr, 1.6*SPB, 0.22), b3(37 + i))
# third chorus: the flute paraphrases -- same head, pushed and pulled a
# little and an octave up in the bridge; fourth chorus: head out
sing([(st + np.random.uniform(-0.10, 0.16), ph) for st, ph in head_phrases()],
     69, 'horn', hnote, 0.56)
sing(head_phrases(), 101, 'horn', hnote, 0.65)

# coda: the last line again, slower feel, landing on a lydian G
CODA = [('C4', 0, 1), ('A3', 1, 1), ('B3', 2, 0.5), ('A3', 2.5, 0.5),
        ('G3', 3, 4)]
play(CODA, 133, 'horn', hnote, 0.56)
comp(133, ['Am', 'D7'], amp=0.22)
T['piano'].add(_pf.chord([hz(x) for x in ['G3', 'B3', 'D4', 'F#4', 'C#5']],
                          6*SPB, 0.26), b3(135))
T['bass'].add(_bs.note(hz('G2'), 5*SPB, 0.5), b3(135))
waltz_brushes(133); waltz_brushes(134)
T['drums'].add(hat(0.05, 0.2), b3(135))

FX = {'bass': (0.10, None, 1.0), 'drums': (0.14, None, 3.4),
      'piano': (0.18, None, 1.0), 'horn': (0.22, None, 1.0)}

def render(name, tr):
    y = tr.out()
    wet, dl, lvl = FX[name]
    y = reverb(y, wet)*lvl
    if name == 'drums': y = hp(y, 60, 2)*1.0 + lp(y, 60, 2)*0.4
    if name == 'horn': y = lp(y, 5200, 2)      # take the mute's edge off
    return y

if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='out_golden')
    a = ap.parse_args()
    mix, stems = master({n: render(n, t) for n, t in T.items()},
                        shelf=(0.15, 90), drive=1.05, peak=0.42,
                        fade_in=(0.05, 0.8), fade_out=(3.0, 2.5))
    write_wav('%s/golden.wav' % a.out, mix)
    for n, y in stems.items():
        write_wav('%s/golden_stems/%s.wav' % (a.out, n), y)
    print('golden  %.1f s  peak %.3f' % (mix.shape[1]/SR, np.max(np.abs(mix))))
