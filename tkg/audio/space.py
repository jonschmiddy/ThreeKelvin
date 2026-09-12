"""The soundtrack, second edition. Three families, not one form.

    py -3.14 space.py            render every cue
    py -3.14 space.py burn boss  render some
    py -3.14 space.py --wav      stop at the WAVs, for listening

WHY THERE IS A SECOND EDITION. The first was thirteen cues built from one
whistled phrase at 142 BPM, each doing one thing to the motif. Jon played the
finished game and called it hollow, sickly, a slow funeral. The fault was the
FORM: a four-bar loop with a tune over it is a song, and this game wanted a
score.

WHY THE FIRST ATTEMPT AT THE SECOND EDITION WAS ALSO WRONG. It replaced one
form with one other form. Thirteen cues, one F pedal, one set of six voices,
one theme placement, differing only by five scalar dials -- which is variation
by parameter rather than by composition, and Jon's verdict was the obvious one:
"these all sound the same." He was also right that the combat cue did not feel
like combat, and that is the same mistake seen from the other end. "No tempo,
no bar lines" is correct for a starchart and wrong for a fight.

So: THREE FAMILIES, and a cue belongs to one of them.

  STILL     drone, almost no events, no theme or the answer only. The archive,
            the end of a run. Nothing is asking anything.
  DRIFTING  drone plus the theme as an event. The chart, a sector, a station.
            This is the form the whole edition was built on and it stays, for
            the eight cues it actually suits.
  DRIVING   an ostinato with a pulse in it, harmony changing four times as
            fast, hits that land ON the pulse, and the theme in short urgent
            notes rather than long ones. Combat and bosses.

DRIVING IS NOT A DRUM KIT, and the ruling in DREAD_NOTES holds: rhythm is a
pulse, not a groove. There is no kick, no snare, no backbeat. What drives is a
low ostinato and filtered stabs -- pitch and filter doing rhythm's job, which
is how this idiom has always done it.

AND THEY ARE NOT ALL IN F. One pedal for thirteen cues is most of why they
blurred together. The five cues that crossfade into each other through the DEEP
table -- theme, dread, burn, boss, business -- still share F, because a shared
pedal is what makes that swap read as the place turning. The other eight are
free and now live in five different keys.

THE RULES THAT DO NOT MOVE, each of them bought by getting it wrong first:

  EVERY AREA CONTAINS THE ROOT. A pedal not in the chord above it is a mistake,
  not a tension. The version that got this wrong put the melody a semitone from
  the harmony three bars in four and sounded, accurately, like a dying animal.

  THE THEME'S FLAT SIXTH MAY ONLY SOUND WHERE THE HARMONY HOLDS ONE. Cues whose
  areas have none state the answer form instead, which has no flat sixth and
  comes home.

  EXACT TUNING. Nothing detuned, no tape wow. Grit is not instability; a lead
  that confused the two was called sickly.

  HEAVY GRIT ON THE THEME AND NOWHERE ELSE. 7-bit, four-times decimation, fold
  1.85, post-crush filter 4.2 kHz. Filtering lower removes the rasp that is the
  entire point.

  EFFECTS FIRST, THEN ONE EQUAL-POWER FOLD. Wrapping before the delay and the
  reverb truncates both tails at the loop point: measured, a 29%-of-peak step
  on the pedal, which is a click every loop forever.
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

WRAP_S = 4.0
PC = {"C": 0, "Db": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "Gb": 6,
      "G": 7, "Ab": 8, "A": 9, "Bb": 10, "B": 11}


def hz(semis_from_a4: float) -> float:
    return 440.0 * 2 ** (semis_from_a4 / 12.0)


def root_hz(name: str) -> float:
    n, o = name[:-1], int(name[-1])
    return hz(PC[n] + 12 * (o - 4) - 9)


## AREAS ARE INTERVALS, NOT NOTES, so a cue can be transposed by changing one
## string. Semitones above the cue's root; 0 is always present, which is the
## pedal rule made structural rather than remembered.
AREAS = {
    # minor, the flat sixth available: the theme may ache here
    "home": [(0.00, [0, 3, 7, 12, 15]), (0.30, [8, 12, 15, 20, 24]),
             (0.58, [5, 8, 12, 15, 17]), (0.80, [0, 3, 7, 10, 12])],
    # open fifths and a ninth, no third: neither major nor minor
    "open": [(0.00, [0, 7, 12, 14, 19]), (0.34, [8, 12, 19, 24, 15]),
             (0.66, [10, 17, 12, 15, 22])],
    # tritone colour, no comfort
    "cold": [(0.00, [0, 6, 7, 12, 15]), (0.38, [8, 6, 12, 15, 20]),
             (0.72, [6, 11, 12, 15, 18])],
    # very low, very wide
    "deep": [(0.00, [-12, -5, 0, 3, 7]), (0.44, [-6, 0, 3, 8, 12]),
             (0.74, [-12, -9, -2, 0, 3])],
    # driving cues change four times as often
    "drive": [(0.00, [0, 3, 7, 10]), (0.14, [8, 12, 15, 19]),
              (0.28, [5, 8, 12, 15]), (0.42, [0, 3, 7, 12]),
              (0.56, [10, 13, 17, 20]), (0.70, [8, 12, 15, 18]),
              (0.84, [0, 6, 7, 12])],
}
## Which area sets contain a flat sixth (8 semitones) above the root.
HAS_FLAT6 = {k: any(8 in ch for _, ch in v) for k, v in AREAS.items()}

## The theme as intervals from the root: up a fifth, up a semitone to the flat
## sixth, back, down to the minor third.
THEME = [(0, 0.0, 3.2), (7, 3.0, 4.5), (8, 7.2, 4.5), (7, 11.4, 3.4),
         (3, 14.4, 6.0)]
ANSWER = [(0, 0.0, 3.2), (7, 3.0, 4.5), (7, 7.4, 3.0), (3, 10.2, 4.0),
          (0, 14.0, 8.0)]
## Combat states it short and hard, in half the time.
URGENT = [(0, 0.0, 1.1), (7, 1.0, 1.4), (8, 2.2, 1.4), (7, 3.4, 1.1),
          (3, 4.4, 2.2)]

## cue -> root, area set, family, dark, theme form, metal, shimmer, loop
## seconds, and beats a minute for the driving ones.
##
## THE FIVE THAT CROSSFADE STAY IN F. `DEEP` swaps theme->dread, burn->boss and
## business->dread, and that swap only reads as the place turning if both sides
## share a pedal. Everything else is free, and now sits in five other keys.
CUES = {
    "first_light": ("F2",  "open",  "drift", 0.7, "answer", 0.7, 0.9, 96.0, 0),
    "shells":      ("C2",  "home",  "drift", 1.2, "theme",  0.8, 0.7, 96.0, 0),
    "warm":        ("Ab1", "open",  "drift", 0.6, "answer", 0.5, 0.6, 96.0, 0),
    "home":        ("Ab1", "open",  "drift", 0.5, "answer", 0.4, 0.7, 96.0, 0),
    "perpetuity":  ("Bb1", "home",  "still", 1.1, "answer", 0.3, 0.4, 96.0, 0),
    "nofault":     ("Db2", "deep",  "still", 1.9, "answer", 0.3, 0.3, 96.0, 0),
    "core":        ("F1",  "deep",  "drift", 1.0, "theme",  1.1, 1.0, 96.0, 0),
    "fauna":       ("Eb2", "open",  "drift", 1.0, "theme",  0.9, 0.8, 96.0, 0),
    # the five on F
    "theme":       ("F2",  "home",  "drift", 1.5, "theme",  1.0, 0.6, 96.0, 0),
    "business":    ("F2",  "home",  "drift", 1.3, "theme",  1.2, 0.5, 96.0, 0),
    "dread":       ("F2",  "cold",  "still", 2.0, None,     1.4, 0.3, 96.0, 0),
    "burn":        ("F2",  "drive", "drive", 1.5, "urgent", 1.6, 0.5, 64.0, 132),
    "boss":        ("F2",  "drive", "drive", 2.0, "urgent", 1.8, 0.4, 64.0, 138),
}
## Stems per family. Driving cues trade breath and upper for a pulse and stabs:
## wind is what a place has when nothing is happening.
FAMILY_STEMS = {
    "still": ["pedal", "organ", "breath", "metal", "theme", "upper"],
    "drift": ["pedal", "organ", "breath", "metal", "theme", "upper"],
    "drive": ["pedal", "organ", "pulse", "metal", "theme", "stab"],
}

HEAVY = (7, 4, 1.85, 4.0)
THEME_CUT = 4200.0


# ------------------------------------------------------------------ helpers

def wrap(x, length_s):
    n = int(length_s * SR)
    w = int(WRAP_S * SR)
    two = x.ndim == 2
    body = (x[:, :n] if two else x[:n]).copy()
    tail = x[:, n:n + w] if two else x[n:n + w]
    k = tail.shape[-1]
    if k > 0:
        a = np.linspace(0.0, np.pi / 2, k)
        if two:
            body[:, :k] = body[:, :k] * np.sin(a) + tail * np.cos(a)
        else:
            body[:k] = body[:k] * np.sin(a) + tail * np.cos(a)
    return body


def place(buf, x, at_s, g=1.0):
    i = int(at_s * SR)
    j = min(len(buf), i + len(x))
    if j > i:
        buf[i:j] += x[:j - i] * g


def fold(x, k):
    return np.sin(x * k * np.pi / 2.0)


def crush(x, bits, decim, cut):
    q = float(2 ** (bits - 1))
    y = np.round(x * q) / q
    if decim > 1:
        n = len(y)
        y = np.repeat(y[::decim], decim)[:n]
        if len(y) < n:
            y = np.pad(y, (0, n - len(y)))
    return lp(y, cut, order=3)


def env_shape(n, up, down):
    t = np.linspace(0.0, 1.0, n)
    return (np.clip(t / up, 0, 1) * np.clip((1 - t) / down, 0, 1)) ** 1.4


# ------------------------------------------------------------------- voices

def v_pedal(n, root, dark, drive):
    """The floor in three parts: depth, the note, and the body between 90 and
    180 Hz that sines have none of. Driving cues get a tighter, drier floor --
    a long swelling pedal under a fast ostinato is mud."""
    t = np.arange(n) / SR
    w = 1.0 + 0.30 * dark
    y = np.zeros(n)
    for mult, a in ((0.25, 0.30), (0.5, 0.72), (1.0, 0.88)):
        f = root * mult
        v = np.sin(2 * np.pi * f * t)
        v += np.sin(2 * np.pi * (f * 2.0 + 0.06) * t) * 0.34
        y += a * w * v
    y += lp(synth.saw(root, n), root * 2.1, order=3) * 0.34 * w
    if not drive:
        y *= 1.0 + 0.06 * np.sin(2 * np.pi * t / 23.0)
    return hp(y, 19.0, order=2)


def v_organ(n, root, areas, dark, total, drive):
    y = np.zeros(n)
    bright = max(0.12, 1.0 - 0.42 * dark)
    for k, (at, ch) in enumerate(areas):
        start = at * total
        end = areas[k + 1][0] * total if k + 1 < len(areas) else total
        pad = 6.0 if drive else 26.0
        seg = min(int((end - start + pad) * SR), n - int(start * SR))
        if seg <= SR // 2:
            continue
        t = np.arange(seg) / SR
        v = np.zeros(seg)
        for i, iv in enumerate(ch):
            f = root * 2 ** (iv / 12.0)
            for h, a in ((1, 1.0), (2, 0.30), (3, 0.16), (4, 0.07)):
                if f * h > SR / 2.2:
                    continue
                v += (a / (i + 1.4)) * np.sin(2 * np.pi * f * h * t + h * 0.4 + i)
        v /= 3.2
        v = lp(v, 300.0 + 1500.0 * bright, order=2)
        up, down = (0.10, 0.16) if drive else (0.34, 0.30)
        place(y, v * env_shape(seg, up, down), start, 0.40)
    return y


def v_breath(n, dark):
    t = np.arange(n) / SR
    y = bp(np.random.randn(n), 200.0, 1700.0, order=2)
    y *= (0.55 + 0.45 * np.sin(2 * np.pi * t / 17.0 + 1.1)) * (0.013 + 0.006 * dark)
    hi = max(0.0, 0.0035 - 0.0016 * dark)
    if hi > 0:
        y += bp(np.random.randn(n), 3000.0, 9000.0, order=2) * hi
    return y


def v_pulse(n, root, areas, total, bpm, dark):
    """THE ENGINE. A low ostinato on the eighth, following the harmony, with a
    filter that reopens on every downbeat. No kit anywhere -- the rhythm is
    carried by pitch and by the filter, which is how this idiom has always done
    it and what keeps DREAD_NOTES' pulse-not-groove ruling intact.

    Two notes in three is a rest. A continuous line is a texture; a line with
    holes in it is a pulse."""
    spb = 60.0 / bpm
    y = np.zeros(n)
    step = spb * 0.5
    i = 0
    at = 0.0
    while at < total + WRAP_S:
        frac = (at / total) % 1.0
        ch = areas[0][1]
        for a_at, a_ch in areas:
            if frac >= a_at:
                ch = a_ch
        # a rest every third eighth, and the downbeat always sounds
        if i % 8 == 0 or i % 3 != 2:
            iv = ch[(i // 2) % len(ch)]
            f = root * 2 ** (iv / 12.0)
            if i % 8 != 0:
                f *= 0.5
            m = int(step * 0.92 * SR)
            t = np.arange(m) / SR
            v = synth.saw(f, m) * 0.8 + np.sin(2 * np.pi * f * 0.5 * t) * 0.5
            cut = 900.0 + (2400.0 if i % 8 == 0 else 900.0) * np.exp(-t / 0.09).mean()
            v = lp(v, cut * (1.0 - 0.22 * dark), order=3)
            v = np.tanh(v * 2.4) / np.tanh(2.4)
            v *= np.exp(-t / (step * 0.40))
            place(y, v, at, 0.30 if i % 8 == 0 else 0.19)
        at += step
        i += 1
    return hp(y, 40.0, order=2)


def v_stab(n, root, areas, total, bpm, dark):
    """Chord hits on the bar. Sparse, hard, and the only thing in the set with
    a fast attack -- everything else fades in."""
    spb = 60.0 / bpm
    bar = spb * 4
    y = np.zeros(n)
    at = 0.0
    k = 0
    while at < total + WRAP_S:
        if k % 2 == 0:
            frac = (at / total) % 1.0
            ch = areas[0][1]
            for a_at, a_ch in areas:
                if frac >= a_at:
                    ch = a_ch
            m = int(min(bar * 0.8, 1.4) * SR)
            t = np.arange(m) / SR
            v = np.zeros(m)
            for iv in ch:
                f = root * 2 ** (iv / 12.0) * 2.0
                v += synth.saw(f, m) / len(ch)
            v = lp(v, 2600.0 * (1.0 - 0.3 * dark), order=2)
            v = np.tanh(v * 2.0) / np.tanh(2.0)
            v *= np.exp(-t / 0.26)
            place(y, v, at, 0.16)
        at += bar
        k += 1
    return hp(y, 90.0, order=2)


def v_metal(n, density, total, seed, on_grid, bpm):
    """Struck, tuned to nothing. In a driving cue the strikes land ON the bar,
    which turns the same sound from weather into percussion without it becoming
    a drum."""
    r = np.random.RandomState(seed)
    y = np.zeros(n)
    count = max(3, int((10 if on_grid else 5) * density))
    for i in range(count):
        if on_grid:
            at = i * (60.0 / bpm) * 4.0 * 2
            if at > total + WRAP_S:
                break
            dur = 4.0 + r.rand() * 3.0
        else:
            at = (i + 0.35 + 0.3 * r.rand()) / count * total
            dur = 9.0 + r.rand() * 9.0
        f = 70.0 + r.rand() * 120.0
        m = int(dur * SR)
        t = np.arange(m) / SR
        v = np.zeros(m)
        for rr, a in ((1.0, 1.0), (1.83, 0.5), (2.41, 0.33), (3.77, 0.2),
                      (5.13, 0.11), (7.31, 0.06)):
            v += a * np.sin(2 * np.pi * f * rr * t + rr) * np.exp(
                -t / (dur * 0.34 / rr ** 0.3))
        place(y, v * (0.045 if on_grid else 0.033), at)
    return y


def v_sing(f, dur, amp):
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
    attack = min(0.9, dur * 0.22)
    env = np.clip(t / attack, 0, 1) * np.exp(
        -np.clip(t - dur * 0.42, 0, None) / (dur * 0.34))
    return amp * y * env


def _forms(form):
    return {"theme": THEME, "answer": ANSWER, "urgent": URGENT}.get(form)


def v_theme(n, root, form, total, drive):
    notes = _forms(form)
    if notes is None:
        return np.zeros(n)
    y = np.zeros(n)
    # Driving cues state it more often, because a fight is not contemplative.
    spots = ([0.08, 0.30, 0.52, 0.74] if drive else [0.16, 0.46, 0.72])
    for s in spots:
        base = s * total
        for iv, off, dur in notes:
            place(y, v_sing(root * 4 * 2 ** (iv / 12.0), dur, 0.115), base + off)
    return hp(y, 60.0, order=2)


def v_upper(n, root, form, total, shimmer):
    notes = _forms(form)
    if notes is None:
        return np.zeros(n)
    y = np.zeros(n)
    for s in (0.16, 0.46, 0.72):
        base = s * total
        for iv, off, dur in notes:
            f = root * 4 * 2 ** (iv / 12.0)
            place(y, v_sing(f * 2.0, dur, 0.036 * shimmer), base + off)
            place(y, v_sing(f * 2 ** (-4 / 12.0), dur, 0.045), base + off)
    return hp(y, 120.0, order=2)


# -------------------------------------------------------------------- build

def stem(cue, name):
    root_n, area_k, family, dark, form, density, shimmer, total, bpm = CUES[cue]
    root = root_hz(root_n)
    areas = AREAS[area_k]
    drive = family == "drive"
    # The flat sixth may only sound where the harmony holds one.
    if form == "theme" and not HAS_FLAT6[area_k]:
        form = "answer"
    if form == "urgent" and not HAS_FLAT6[area_k]:
        form = "urgent"
    n = int((total + WRAP_S + 2.0) * SR)
    seed = abs(hash(cue)) % 100000
    np.random.seed(seed)

    if name == "pedal":
        y = v_pedal(n, root, dark, drive)
    elif name == "organ":
        y = v_organ(n, root, areas, dark, total, drive)
    elif name == "breath":
        y = v_breath(n, dark)
    elif name == "pulse":
        y = v_pulse(n, root, areas, total, bpm, dark)
    elif name == "stab":
        y = v_stab(n, root, areas, total, bpm, dark)
    elif name == "metal":
        y = v_metal(n, density, total, seed, drive, bpm or 120)
    elif name == "theme":
        y = v_theme(n, root, form, total, drive)
    elif name == "upper":
        y = v_upper(n, root, form, total, shimmer)
    else:
        raise ValueError(name)

    st = np.vstack([y, y])
    for ch, d in ((0, 0.019), (1, 0.031)):
        k = int(d * SR)
        st[ch, k:] += st[ch, :-k] * 0.26
    st = synth.reverb(st, wet=0.34 if drive else 0.52)
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
        fam = CUES[cue][2]
        for name in FAMILY_STEMS[fam]:
            st = stem(cue, name)
            w = os.path.join(OUT, "%s_%s.wav" % (cue, name))
            synth.write_wav(w, st)
            if wav_only:
                print("  %-12s %-7s %s" % (cue, name, fam))
                continue
            dst = os.path.join(SHIP, cue, "%s.ogg" % name)
            bld.ogg(dst, w, compression=0.5)
            sz = os.path.getsize(dst)
            total_bytes += sz
            print("  %-12s %-7s %-6s %6.0f KB" % (cue, name, fam, sz / 1024.0))
    if not wav_only:
        print("\n%.1f MB total" % (total_bytes / 1e6))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    render(args or list(CUES), "--wav" in sys.argv)
