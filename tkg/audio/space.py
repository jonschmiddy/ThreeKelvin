"""The soundtrack, second edition. Drone, texture, and one five-note theme.

    py -3.14 space.py            render every cue
    py -3.14 space.py theme      render one
    py -3.14 space.py --wav      stop at the WAVs, for listening

WHY THERE IS A SECOND EDITION. The first soundtrack was thirteen cues built
from one whistled phrase, and the design behind it is sound: a motif that never
touches the fifth, a question with no answer. Jon listened to it in the finished
game and said it was hollow, sickly, a slow funeral, not musical at all. He was
describing the FORM rather than the details -- a four-bar loop with a tune over
it is a song, and a game about flying into a dying galaxy wanted a score.

So this is built the other way round, and every rule here exists because
breaking it produced something he rejected.

  A PEDAL THAT NEVER MOVES. One low F under everything. Harmony changes above
  it and the floor does not, which is what makes it read as weather instead of
  as a chord progression.

  HARMONY THAT MOVES ONCE A MINUTE. Three or four areas per cue. Every area
  contains F, because the pedal is F and a pedal that is not in the chord above
  it is a mistake -- the version that got that wrong had the melody a semitone
  from the harmony for three bars in four.

  EXACT TUNING EVERYWHERE. No detuned oscillators, no tape wow, nothing that
  drifts. The one exception is 0.06 Hz between the two pedal octaves, which is
  a sixteen-second swell rather than a wobble. Grit is not instability: an
  earlier lead had four detunings and a wow stacked on it and the word for the
  result was "sickly".

  THE THEME IS AN EVENT. F, up a fifth to C, up a semitone to D flat, back to
  C, down to A flat. The D flat is the flat sixth and the reason the phrase
  aches; it leans on the C and gives up. It may only sound where the harmony
  holds a D flat, and cues whose areas have none state the answer form instead,
  which has no D flat and comes home.

  HEAVY GRIT ON THE THEME AND NOWHERE ELSE. 7-bit, four-times decimation, the
  wavefolder at 1.85, and the post-crush filter at 4.2 kHz. That filter is a
  tuned number: lower and it removes the rasp that is the whole point, higher
  and the aliasing turns to hiss.

  NO ARC, BECAUSE A CUE LOOPS. The standalone pieces had a dynamic arc from
  silence to enormous. A loop cannot: the arc is what the RUNG LADDER does
  instead, and every stem is a seamless loop of the same length so they stay
  locked together forever.

SIX STEMS, FOUR RUNGS, THE SAME IN EVERY CUE. The old table gave each cue its
own vocabulary of stem names, which meant thirteen private languages. This is
one:

    pedal   the floor          rung 0, always
    organ   the harmony        rung 0, always
    breath  wind over a hull   rung 1
    metal   struck, inharmonic rung 1
    theme   the five notes     rung 2
    upper   theme doubled and harmonised, plus shimmer   rung 3
"""
from __future__ import annotations

import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import synth                                                   # noqa: E402
from synth import SR, bp, hp, lp                               # noqa: E402

OUT = os.path.join(HERE, "out", "space")
SHIP = os.path.join(HERE, "..", "assets", "audio", "music")

## Every stem of every cue is this long, so they loop together for ever.
LOOP_S = 96.0
## Seconds of tail folded back over the head to hide the seam. Both sides ramp,
## equal power: a one-sided fold hides a reverb tail but leaves the joint, and
## on a continuous tone that is an audible click once a loop, forever.
WRAP_S = 4.0

PC = {"C": 0, "Db": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "Gb": 6,
      "G": 7, "Ab": 8, "A": 9, "Bb": 10, "B": 11}


def nt(name: str) -> float:
    n, o = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((PC[n] + 12 * (o - 4) - 9) / 12.0)


## The theme, and its answer. Seconds, not beats: nothing here has a tempo.
THEME = [("F4", 0.0, 3.2), ("C5", 3.0, 4.5), ("Db5", 7.2, 4.5),
         ("C5", 11.4, 3.4), ("Ab4", 14.4, 6.0)]
ANSWER = [("F4", 0.0, 3.2), ("C5", 3.0, 4.5), ("C5", 7.4, 3.0),
          ("Ab4", 10.2, 4.0), ("F4", 14.0, 8.0)]
THIRD_BELOW = {"F4": "Db4", "C5": "Ab4", "Db5": "Bb4", "Ab4": "F4"}

## Harmonic areas, as fractions of the loop. EVERY CHORD CONTAINS F.
AREAS_HOME = [(0.00, ["F2", "Ab2", "C3", "F3", "Ab3"]),
              (0.30, ["Db2", "Ab2", "C3", "F3", "Ab3"]),
              (0.58, ["Bb1", "Db3", "F3", "Ab3", "Bb3"]),
              (0.80, ["F2", "Ab2", "C3", "Eb3", "F3"])]
AREAS_OPEN = [(0.00, ["F2", "C3", "F3", "G3", "C4"]),
              (0.34, ["Db2", "Ab2", "F3", "C4", "Ab3"]),
              (0.66, ["Eb2", "Bb2", "F3", "Ab3", "Eb3"])]
AREAS_COLD = [(0.00, ["F2", "Gb2", "C3", "F3", "Ab3"]),
              (0.38, ["Db2", "Gb2", "Ab2", "F3", "Db3"]),
              (0.72, ["B1", "Gb2", "F3", "Ab3", "Db3"])]
AREAS_DEEP = [(0.00, ["F1", "C2", "F2", "Ab2", "C3"]),
              (0.44, ["B1", "F2", "Ab2", "Db3", "F3"]),
              (0.74, ["F1", "Ab1", "Eb2", "F2", "Ab2"])]

## cue -> (areas, dark, theme form or None, metal density, high shimmer)
##
## dark closes the organ, strips the air and adds weight. 0 is open, 2 is the
## bottom of the useful range: past that the grit goes with everything else.
CUES = {
    "first_light": (AREAS_OPEN, 0.7, "answer", 0.7, 0.9),
    "shells":      (AREAS_HOME, 1.2, "theme", 0.8, 0.7),
    "warm":        (AREAS_OPEN, 0.6, "answer", 0.5, 0.6),
    "home":        (AREAS_OPEN, 0.5, "answer", 0.4, 0.7),
    "theme":       (AREAS_HOME, 1.5, "theme", 1.0, 0.6),
    "business":    (AREAS_HOME, 1.3, "theme", 1.2, 0.5),
    "perpetuity":  (AREAS_HOME, 1.1, "answer", 0.6, 0.4),
    "core":        (AREAS_DEEP, 1.0, "theme", 1.1, 1.0),
    "fauna":       (AREAS_OPEN, 1.0, "theme", 0.9, 0.8),
    "burn":        (AREAS_COLD, 1.6, "theme", 1.6, 0.5),
    "dread":       (AREAS_COLD, 2.0, None, 1.4, 0.3),
    "boss":        (AREAS_DEEP, 2.1, "theme", 1.8, 0.4),
    "nofault":     (AREAS_DEEP, 1.9, "answer", 0.5, 0.3),
}
STEMS = ["pedal", "organ", "breath", "metal", "theme", "upper"]

## Heavy, and settled. Bits, decimation, fold, drive.
HEAVY = (7, 4, 1.85, 4.0)
THEME_CUT = 4200.0


# ------------------------------------------------------------------ helpers

def wrap(x: np.ndarray, length_s: float) -> np.ndarray:
    """Fold the tail over the head so the loop has no seam."""
    n = int(length_s * SR)
    w = int(WRAP_S * SR)
    body = x[:n].copy() if x.ndim == 1 else x[:, :n].copy()
    tail = x[n:n + w] if x.ndim == 1 else x[:, n:n + w]
    k = tail.shape[-1]
    if k > 0:
        a = np.linspace(0.0, np.pi / 2, k)
        if x.ndim == 1:
            body[:k] = body[:k] * np.sin(a) + tail * np.cos(a)
        else:
            body[:, :k] = body[:, :k] * np.sin(a) + tail * np.cos(a)
    return body


def place(buf: np.ndarray, x: np.ndarray, at_s: float, g: float = 1.0) -> None:
    i = int(at_s * SR)
    j = min(len(buf), i + len(x))
    if j > i:
        buf[i:j] += x[:j - i] * g


def fold(x: np.ndarray, k: float) -> np.ndarray:
    return np.sin(x * k * np.pi / 2.0)


def crush(x: np.ndarray, bits: int, decim: int, cut: float) -> np.ndarray:
    q = float(2 ** (bits - 1))
    y = np.round(x * q) / q
    if decim > 1:
        n = len(y)
        y = np.repeat(y[::decim], decim)[:n]
        if len(y) < n:
            y = np.pad(y, (0, n - len(y)))
    return lp(y, cut, order=3)


def shape(n: int, up: float, down: float) -> np.ndarray:
    t = np.linspace(0.0, 1.0, n)
    a = np.clip(t / max(up, 1e-6), 0.0, 1.0)
    b = np.clip((1.0 - t) / max(down, 1e-6), 0.0, 1.0)
    return (a * b) ** 1.4


# ------------------------------------------------------------------- voices

def v_pedal(n: int, dark: float) -> np.ndarray:
    """The floor, in three parts. DEEP and FULL are different requests: F0 is
    felt rather than heard, F1 and F2 are the note, and the filtered saw is the
    harmonic content between 90 and 180 Hz that sines have none of. A mix can be
    deep and still sound thin if that band is empty."""
    t = np.arange(n) / SR
    w = 1.0 + 0.30 * dark
    y = np.zeros(n)
    for name, a in (("F0", 0.30), ("F1", 0.72), ("F2", 0.88)):
        f = nt(name)
        v = np.sin(2 * np.pi * f * t)
        v += np.sin(2 * np.pi * (f * 2.0 + 0.06) * t) * 0.34
        v += np.sin(2 * np.pi * f * 0.5 * t) * 0.22
        y += a * w * v
    y += lp(synth.saw(nt("F2"), n), 180.0, order=3) * 0.34 * w
    y += lp(synth.saw(nt("F1"), n), 120.0, order=3) * 0.24 * w
    y *= 1.0 + 0.06 * np.sin(2 * np.pi * t / 23.0)
    return hp(y, 19.0, order=2)


def v_organ(n: int, areas: list, dark: float, total_s: float) -> np.ndarray:
    y = np.zeros(n)
    bright = max(0.12, 1.0 - 0.42 * dark)
    for k, (at, ch) in enumerate(areas):
        start = at * total_s
        end = areas[k + 1][0] * total_s if k + 1 < len(areas) else total_s
        seg = min(int((end - start + 26.0) * SR), n - int(start * SR))
        if seg <= SR:
            continue
        t = np.arange(seg) / SR
        v = np.zeros(seg)
        for i, name in enumerate(ch):
            f = nt(name)
            for h, a in ((1, 1.0), (2, 0.30), (3, 0.16), (4, 0.07)):
                if f * h > SR / 2.2:
                    continue
                v += (a / (i + 1.4)) * np.sin(2 * np.pi * f * h * t + h * 0.4 + i)
        v /= 3.2
        v = lp(v, 300.0 + 1500.0 * bright, order=2)
        place(y, v * shape(seg, 0.34, 0.30), start, 0.40)
    return y


def v_breath(n: int, dark: float) -> np.ndarray:
    t = np.arange(n) / SR
    y = bp(np.random.randn(n), 200.0, 1700.0, order=2)
    y *= (0.55 + 0.45 * np.sin(2 * np.pi * t / 17.0 + 1.1)) * (0.013 + 0.006 * dark)
    hi = max(0.0, 0.0035 - 0.0016 * dark)
    if hi > 0:
        y += bp(np.random.randn(n), 3000.0, 9000.0, order=2) * hi
    return y


def v_metal(n: int, density: float, total_s: float, seed: int) -> np.ndarray:
    """Tuned to nothing. The one sound here that is not a note, and the reason
    the set reads as a machine rather than an orchestra."""
    r = np.random.RandomState(seed)
    y = np.zeros(n)
    count = max(3, int(5 * density))
    for i in range(count):
        at = (i + 0.35 + 0.3 * r.rand()) / count * total_s
        f = 70.0 + r.rand() * 120.0
        dur = 9.0 + r.rand() * 9.0
        m = int(dur * SR)
        t = np.arange(m) / SR
        v = np.zeros(m)
        for rr, a in ((1.0, 1.0), (1.83, 0.5), (2.41, 0.33), (3.77, 0.2),
                      (5.13, 0.11), (7.31, 0.06)):
            v += a * np.sin(2 * np.pi * f * rr * t + rr) * np.exp(
                -t / (dur * 0.34 / rr ** 0.3))
        place(y, v * 0.033, at)
    return y


def v_sing(f: float, dur: float, amp: float) -> np.ndarray:
    bits, decim, k, drive = HEAVY
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for h, a in ((0.5, 0.34), (1, 1.0), (2, 0.42), (3, 0.20), (4, 0.10),
                 (5, 0.05), (6, 0.03)):
        y += a * np.sin(2 * np.pi * f * h * t + h * 0.5)
    y /= 2.1
    y = fold(y, k)
    y = np.tanh(y * drive) / np.tanh(drive)
    y = crush(y, bits, decim, THEME_CUT)
    env = np.clip(t / 0.9, 0, 1) * np.exp(
        -np.clip(t - dur * 0.42, 0, None) / (dur * 0.34))
    return amp * y * env


def _statements(total_s: float) -> list:
    """Three statements a loop, spaced so none lands on the seam."""
    return [0.16 * total_s, 0.46 * total_s, 0.72 * total_s]


def v_theme(n: int, form, total_s: float) -> np.ndarray:
    if form is None:
        return np.zeros(n)
    notes = THEME if form == "theme" else ANSWER
    y = np.zeros(n)
    for base in _statements(total_s):
        for name, off, dur in notes:
            place(y, v_sing(nt(name), dur, 0.115), base + off)
    return hp(y, 60.0, order=2)


def v_upper(n: int, form, total_s: float, shimmer: float) -> np.ndarray:
    """The theme doubled at the octave and harmonised a third below, plus a
    high shimmer. This is the top rung: the cue opening up under pressure."""
    if form is None:
        return np.zeros(n)
    notes = THEME if form == "theme" else ANSWER
    y = np.zeros(n)
    for base in _statements(total_s):
        for name, off, dur in notes:
            f = nt(name)
            place(y, v_sing(f * 2.0, dur, 0.036 * shimmer), base + off)
            if name in THIRD_BELOW:
                place(y, v_sing(nt(THIRD_BELOW[name]), dur, 0.045), base + off)
    return hp(y, 120.0, order=2)


# -------------------------------------------------------------------- build

def stem(cue: str, name: str) -> np.ndarray:
    areas, dark, form, density, shimmer = CUES[cue]
    total = LOOP_S
    n = int((total + WRAP_S + 2.0) * SR)
    seed = abs(hash(cue)) % 100000
    np.random.seed(seed)

    if name == "pedal":
        y = v_pedal(n, dark)
    elif name == "organ":
        y = v_organ(n, areas, dark, total)
    elif name == "breath":
        y = v_breath(n, dark)
    elif name == "metal":
        y = v_metal(n, density, total, seed)
    elif name == "theme":
        y = v_theme(n, form, total)
    elif name == "upper":
        y = v_upper(n, form, total, shimmer)
    else:
        raise ValueError(name)

    # WRAPPED ONCE, AND LAST. The first version wrapped the dry signal and then
    # ran the delay and the reverb on the result, which truncates both of their
    # tails at the loop point and leaves the head with no pre-history to answer
    # them. Measured, that put a step of 29% of peak on the pedal stem: a click,
    # once every 96 seconds, for as long as the game is open.
    #
    # Delay and reverb first, on a signal that is longer than the loop, then one
    # equal-power fold. Now the tail that wraps into the head carries the
    # reverb and the echoes with it, and the joint is continuous by construction.
    st = np.vstack([y, y])
    for ch, d in ((0, 0.019), (1, 0.031)):
        k = int(d * SR)
        st[ch, k:] += st[ch, :-k] * 0.26
    st = synth.reverb(st, wet=0.52)
    st = wrap(st, total)
    m = float(np.max(np.abs(st)))
    if m > 0.92:
        st = st / m * 0.92
    return st


def render(cues, wav_only=False):
    os.makedirs(OUT, exist_ok=True)
    import build as bld
    total_bytes = 0
    for cue in cues:
        for name in STEMS:
            st = stem(cue, name)
            w = os.path.join(OUT, "%s_%s.wav" % (cue, name))
            synth.write_wav(w, st)
            if wav_only:
                print("  %-12s %-7s %6.1f MB wav"
                      % (cue, name, os.path.getsize(w) / 1e6))
                continue
            dst = os.path.join(SHIP, cue, "%s.ogg" % name)
            bld.ogg(dst, w, compression=0.5)
            sz = os.path.getsize(dst)
            total_bytes += sz
            print("  %-12s %-7s %6.0f KB" % (cue, name, sz / 1024.0))
    if not wav_only:
        print("\n%d cues x %d stems = %d files, %.1f MB total"
              % (len(cues), len(STEMS), len(cues) * len(STEMS),
                 total_bytes / 1e6))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    render(args or list(CUES), "--wav" in sys.argv)
