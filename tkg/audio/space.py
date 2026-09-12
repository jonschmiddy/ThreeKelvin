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
    # FOUR CHANGES, NOT SEVEN. A chord every nine seconds under a pulse is the
    # harmony competing with the rhythm for the ear's attention; at four the
    # pulse is what moves and the harmony is what it moves over.
    "drive": [(0.00, [0, 3, 7, 10]), (0.26, [8, 12, 15, 19]),
              (0.52, [5, 8, 12, 15]), (0.78, [0, 3, 7, 12])],
    # a second driving progression, so the two fight cues do not share one
    "drive2": [(0.00, [0, 6, 7, 13]), (0.28, [5, 8, 12, 18]),
               (0.56, [0, 3, 10, 15]), (0.80, [8, 11, 15, 20])],
    # stacked fourths: no thirds at all, so it reads modern rather than modal
    "quartal": [(0.00, [0, 5, 10, 15, 22]), (0.36, [7, 12, 17, 22, 26]),
                (0.62, [2, 7, 12, 19, 24]), (0.82, [0, 5, 12, 17, 19])],
    # major sevenths: the brightest set, and the only one with a leading tone
    "bright": [(0.00, [0, 4, 7, 11, 16]), (0.40, [5, 9, 12, 16, 21]),
               (0.70, [7, 11, 14, 18, 23])],
    # the flat second. The darkest colour available without a tritone.
    "phryg": [(0.00, [0, 1, 7, 12, 13]), (0.32, [8, 12, 13, 20, 15]),
              (0.60, [1, 5, 8, 13, 17]), (0.84, [0, 3, 7, 12, 13])],
    # two chords, a very long time each. The stillest progression here.
    "vast": [(0.00, [0, 7, 12, 19, 24]), (0.52, [3, 10, 15, 22, 27])],
    # a slow descent: each area a step below the last
    "sink": [(0.00, [0, 3, 7, 12, 15]), (0.26, [10, 15, 19, 22, 27]),
             (0.52, [8, 12, 15, 20, 24]), (0.78, [7, 10, 14, 19, 22])],
    # suspended: fourths and ninths over the root, never resolving
    "susp": [(0.00, [0, 5, 7, 14, 17]), (0.38, [10, 14, 17, 22, 24]),
             (0.68, [5, 12, 14, 19, 21])],
}
## Which area sets contain a flat sixth (8 semitones) above the root.
HAS_FLAT6 = {k: any(8 in ch for _, ch in v) for k, v in AREAS.items()}

## THE THEME, AND ITS FAMILY. One shape thirteen times is one tune thirteen
## times. These are all recognisably the same idea -- they open on the root,
## they reach, they come back down -- but no two cues state the same contour,
## which is what a soundtrack does and a transposed loop does not.
##
## Intervals from the root, an offset in seconds, and a length in seconds.
THEMES = {
    # the original: up a fifth, lean on the flat sixth, give up, settle
    "ask": [(0, 0.0, 3.2), (7, 3.0, 4.5), (8, 7.2, 4.5), (7, 11.4, 3.4),
            (3, 14.4, 6.0)],
    # the same with the ache removed, and it comes home
    "answer": [(0, 0.0, 3.2), (7, 3.0, 4.5), (7, 7.4, 3.0), (3, 10.2, 4.0),
               (0, 14.0, 8.0)],
    # inverted: everything that rose now falls
    "invert": [(12, 0.0, 3.4), (5, 3.2, 4.2), (4, 7.0, 4.2), (5, 11.0, 3.2),
               (9, 14.0, 6.0)],
    # climbing fourths, no third anywhere: the least settled of them
    "climb": [(0, 0.0, 2.6), (5, 2.4, 3.2), (10, 5.4, 4.0), (15, 9.2, 5.0),
              (12, 14.0, 6.0)],
    # two octave leaps. The widest, for the cue with the most room
    "wide": [(0, 0.0, 3.0), (12, 2.8, 5.0), (7, 7.6, 3.2), (19, 10.6, 5.4),
             (12, 15.8, 6.0)],
    # a turn around the third, then away. The most vocal shape here
    "turn": [(3, 0.0, 2.4), (5, 2.2, 2.4), (3, 4.4, 3.0), (7, 7.2, 4.4),
             (0, 11.4, 7.0)],
    # a descent that lands on the root, four notes, nothing wasted
    "fall": [(15, 0.0, 3.6), (12, 3.4, 3.6), (7, 6.8, 4.4), (0, 11.0, 8.0)],
    # two notes. For the cue that should barely have a theme at all
    "frag": [(0, 0.0, 4.0), (7, 4.4, 8.0)],
    # short and hard, for the driving family
    "urgent": [(0, 0.0, 1.1), (7, 1.0, 1.4), (8, 2.2, 1.4), (7, 3.4, 1.1),
               (3, 4.4, 2.2)],
    # a second urgent shape so the two fight cues do not share one
    "urgent2": [(12, 0.0, 1.0), (7, 0.9, 1.2), (10, 2.0, 1.2), (3, 3.1, 1.0),
                (0, 4.1, 2.4)],
}

## cue -> root, area set, family, dark, theme form, metal, shimmer, loop
## seconds, and beats a minute for the driving ones.
##
## THE FIVE THAT CROSSFADE STAY IN F. `DEEP` swaps theme->dread, burn->boss and
## business->dread, and that swap only reads as the place turning if both sides
## share a pedal. Everything else is free, and now sits in five other keys.
CUES = {
    # cue: root, areas, family, dark, theme shape, metal, shimmer, loop, bpm
    "first_light": ("F2",  "open",    "drift", 0.7, "climb",  0.7, 0.9, 96.0, 0),
    "shells":      ("C2",  "quartal", "drift", 1.2, "wide",   0.8, 0.7, 96.0, 0),
    "warm":        ("Ab1", "susp",    "drift", 0.6, "turn",   0.5, 0.6, 96.0, 0),
    "home":        ("Ab1", "bright",  "drift", 0.5, "answer", 0.4, 0.7, 96.0, 0),
    "perpetuity":  ("Bb1", "vast",    "still", 1.1, "frag",   0.3, 0.4, 96.0, 0),
    "nofault":     ("Db2", "sink",    "still", 1.9, "fall",   0.3, 0.3, 96.0, 0),
    "core":        ("F1",  "deep",    "drift", 1.0, "invert", 1.1, 1.0, 96.0, 0),
    "fauna":       ("Eb2", "susp",    "drift", 1.0, "climb",  0.9, 0.8, 96.0, 0),
    # the five that crossfade into each other keep F
    "theme":       ("F2",  "home",    "drift", 1.5, "ask",    1.0, 0.6, 96.0, 0),
    "business":    ("F2",  "phryg",   "drift", 1.3, "turn",   1.2, 0.5, 96.0, 0),
    "dread":       ("F2",  "cold",    "still", 2.0, None,     1.4, 0.3, 96.0, 0),
    "burn":        ("F2",  "drive",   "drive", 1.5, "ask",    1.6, 0.5, 64.0, 132),
    "boss":        ("F2",  "drive2",  "drive", 2.0, "fall",   1.8, 0.4, 64.0, 138),
}
## Stems per family. Driving cues trade breath and upper for a pulse and stabs:
## wind is what a place has when nothing is happening.
## Which pattern each driving cue uses.
##
## BOTH FIGHTS ARE THREE-THREE-TWO, chosen by Jon out of five. The gaps inside
## the bar are uneven, so it swings; the bar itself repeats exactly, so it never
## becomes something to track. That combination is the whole answer to four
## rounds of "too complicated to follow" and one round of "math rock".
##
## The two fights stay apart by everything else: 132 against 138, different
## harmonic progressions, different melodic contours, and boss half a step
## darker. Giving them different beats as well was an option and the wrong one
## -- a beat is the thing the player locks into, and locking into a different
## one because a bigger enemy arrived is a worse moment than a familiar groove
## getting meaner.
PULSE_OF = {"burn": "tresillo", "boss": "tresillo"}

FAMILY_STEMS = {
    "still": ["pedal", "organ", "breath", "metal", "theme", "upper"],
    "drift": ["pedal", "organ", "motion", "metal", "theme", "upper"],
    "drive": ["pedal", "organ", "pulse", "metal", "theme", "stab"],
}

## The theme sounds this many octaves above the organ. Named, because the
## voicing rule depends on it and a silent change here would reintroduce
## clashes nothing would catch.
## AN OCTAVE LOWER THAN IT WAS. At 2 the theme played two octaves above the
## pedal -- F4 and up on an F2 cue, with the upper stem another octave above
## that again -- and Jon's word for it was "too high pitched". At 1 it sits an
## octave over the root, in the register a lead actually lives in, and close
## enough to the organ that the voicing rule has real work to do.
##
## The clash rule may still raise a voicing by an octave when the melody would
## land a semitone from something the organ is holding, so this is a floor
## rather than a fixed register.
THEME_OCTAVES = 1

## The theme's envelope. Jon: "less of a swelling synth, something punchier."
## ATTACK_S is the whole difference -- 6 ms arrives, 900 ms swells -- and the
## drop to SUSTAIN over DECAY_S is what makes it read as struck rather than
## faded up.
ATTACK_S = 0.006
DECAY_S = 0.22
SUSTAIN = 0.46

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

def bass_line(areas, total, form):
    """A slow melody for the bottom of the mix.

    THE DRONE SINGS THE THEME, TWO OCTAVES DOWN AND FOUR TIMES SLOWER. That is
    augmentation, and it is the oldest way to make a bass line belong to a piece
    rather than merely support it: the shape is already the cue's own, so the
    floor is melodic without introducing a second idea to compete with the
    first.

    Every note is taken from the area sounding under it, so the bass cannot
    argue with the harmony. Where the contour asks for a degree the area does
    not contain, the nearest tone it does contain is used instead -- the shape
    survives, the collision does not.
    """
    notes = THEMES.get(form) or THEMES["answer"]
    span = max(off + dur for _, off, dur in notes)
    out = []
    for iv, off, dur in notes:
        at = (off / span) * total
        ln = (dur / span) * total
        ch = area_at(areas, (at / total) % 1.0)
        low = sorted(ch)[:3] or [0]
        pick = min(low, key=lambda c: abs(((c - iv) % 12 + 6) % 12 - 6))
        out.append((pick - 12, at, ln))
    return out


def v_pedal(n, root, dark, drive, areas=None, total=0.0, form=None):
    """The floor in three parts -- depth, the note, and the body between 90 and
    180 Hz that sines have none of -- plus, now, a melody.

    THE SUSTAINED ROOT STAYS UNDERNEATH IT. It is quieter than it was, but it
    never stops, because it is the anchor that makes a crossfade between two
    cues read as the place turning rather than as the music changing. A bass
    that only moves would take that with it.
    """
    t = np.arange(n) / SR
    w = 1.0 + 0.30 * dark
    y = np.zeros(n)
    for mult, a in ((0.25, 0.26), (0.5, 0.52), (1.0, 0.58)):
        f = root * mult
        v = np.sin(2 * np.pi * f * t)
        v += np.sin(2 * np.pi * (f * 2.0 + 0.06) * t) * 0.34
        y += a * w * v
    y += lp(synth.saw(root, n), root * 2.1, order=3) * 0.24 * w

    # NO BASS MELODY IN A DRIVING CUE. The pulse is already the bass, and two
    # independent low lines is two things to follow where there should be one.
    # The still and drifting cues keep it: there, nothing else is moving.
    if areas and total > 0 and not drive:
        for iv, at, ln in bass_line(areas, total, form):
            f = root * 2 ** (iv / 12.0)
            # NOT BELOW 35 Hz. On the deepest cue the contour asked for two
            # octaves under an F1 root, which is 11 Hz: inaudible on anything,
            # removed by the high-pass a moment later, and until then just
            # excursion the mix pays for. Raised by octaves until it is a note.
            while f < 35.0:
                f *= 2.0
            m = int(min(ln * 1.25, total) * SR)
            tt = np.arange(m) / SR
            v = np.sin(2 * np.pi * f * tt) * 1.0
            v += np.sin(2 * np.pi * f * 2 * tt) * 0.42
            v += lp(synth.saw(f * 2, m), 220.0, order=3) * 0.5
            v = np.tanh(v * 1.7) / np.tanh(1.7)
            # struck, like the theme, not faded up
            env = np.clip(tt / 0.02, 0, 1) * (0.5 + 0.5 * np.exp(-tt / 0.5))
            env *= np.exp(-np.clip(tt - ln * 0.55, 0, None) / (ln * 0.34))
            place(y, v * env, at, 0.42 * w)

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
        # The organ opens faster than it did as well, for the same reason.
        up, down = (0.08, 0.14) if drive else (0.18, 0.26)
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


## PULSE PATTERNS, on a sixteen-slot bar. A number is how hard that slot is
## struck; a dot is a rest. Every one of them repeats every bar, and every one
## sits on the root -- the two things that took four rounds to learn.
##
## They are deliberately different KINDS of feel rather than variations on one:
## a plain four, a swung three-three-two, a straight eighth line, a driving
## sixteenth line, and a half-time that leaves most of the bar empty.
PULSE_PATTERNS = {
    #            1               2               3               4
    "four":     [9, 0, 0, 0, 6, 0, 0, 0, 8, 0, 0, 0, 6, 0, 0, 0],
    "tresillo": [9, 0, 0, 6, 0, 0, 7, 0, 8, 0, 0, 5, 0, 0, 6, 0],
    "eighths":  [9, 0, 2, 0, 6, 0, 2, 0, 8, 0, 2, 0, 6, 0, 3, 0],
    "sixteen":  [9, 2, 3, 2, 6, 2, 3, 2, 8, 2, 3, 2, 6, 2, 4, 3],
    "half":     [9, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 3, 0],
}


def v_pulse(n, root, areas, total, bpm, dark, pattern="tresillo"):
    """THE RIFF. It repeats, it stays on the root, and its shape is a table.

    The pitch is pinned to the root because every harmonic area in this file
    contains a 0, so the riff is consonant with whatever moves above it and can
    repeat for the length of a fight without knowing what the harmony is doing.
    That rule was written for the pedal and turns out to be what makes a groove
    possible at all.

    What is left is the pattern, and that is now a sixteen-slot table rather
    than arithmetic on the bar number. Arithmetic is how the first version
    became a 3-against-8 polyrhythm and how the second walked its pitch through
    sixteen notes without repeating: both of those were emergent, and neither
    was anything anybody chose. A table cannot surprise you.
    """
    pat = PULSE_PATTERNS[pattern]
    spb = 60.0 / bpm
    step = spb * 0.25                      # a sixteenth
    y = np.zeros(n)
    i = 0
    at = 0.0
    while at < total + WRAP_S:
        slot = i % 16
        hit = pat[slot]
        if hit:
            # The one octave lift, on the last struck slot of every second bar.
            bar = i // 16
            lift = bar % 2 == 1 and slot >= 12
            f = root * (2.0 if lift else 1.0)
            accent = hit / 9.0
            m = int(spb * 0.46 * SR)
            t = np.arange(m) / SR
            v = synth.saw(f, m) * 0.8 + np.sin(2 * np.pi * f * 0.5 * t) * 0.5
            cut = (2400.0 if hit >= 8 else 1250.0) * (1.0 - 0.22 * dark)
            v = lp(v, cut, order=3)
            v = np.tanh(v * 2.4) / np.tanh(2.4)
            v *= np.exp(-t / (spb * 0.30))
            place(y, v, at, 0.30 * accent)
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
        if k % 4 == 0:
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


def v_motion(n, root, areas, total, shimmer):
    """MOVEMENT WITHOUT A BEAT, for the cues that are not fights.

    Jon: "it's also WAYYYY too droney." It was: the drifting cues had a held
    pedal, a held organ, a noise bed, five struck metals and three statements of
    the theme across ninety-six seconds, and nothing else. Almost all of the
    running time was sustain.

    This replaces the noise bed on those cues -- filtered noise being the single
    most drone-ish thing in the mix -- with a slow arpeggio through whatever
    chord is sounding. One note every 1.3 seconds, climbing the area and falling
    back, plucked and left to ring.

    IT IS NOT A PULSE. The rate is steady so it never becomes something to
    track, but there is no accent pattern and no bar, so it reads as a place
    with something happening in it rather than as a rhythm. The fights keep
    their ostinato; this is the other half of the same idea at a tenth of the
    speed.
    """
    step = 1.30
    y = np.zeros(n)
    at = 0.0
    k = 0
    while at < total + WRAP_S:
        ch = area_at(areas, (at / total) % 1.0)
        # up the chord and back down, so the line has a shape rather than
        # cycling in one direction forever
        span = len(ch) * 2 - 2 if len(ch) > 1 else 1
        idx = k % span
        if idx >= len(ch):
            idx = span - idx
        f = root * 2 ** ((ch[idx] + 12) / 12.0)
        dur = step * 2.6
        m = int(dur * SR)
        t = np.arange(m) / SR
        v = np.sin(2 * np.pi * f * t)
        v += 0.34 * np.sin(4 * np.pi * f * t)
        v += 0.14 * np.sin(6 * np.pi * f * t)
        v = lp(v, 2600.0, order=2) * np.exp(-t / (dur * 0.30))
        place(y, v, at, 0.055 * (0.7 + 0.5 * shimmer))
        at += step
        k += 1
    return hp(y, 90.0, order=2)


def v_metal(n, density, total, seed, on_grid, bpm):
    """Struck, tuned to nothing. In a driving cue the strikes land ON the bar,
    which turns the same sound from weather into percussion without it becoming
    a drum."""
    r = np.random.RandomState(seed)
    y = np.zeros(n)
    # Sparse on a grid: ringing inharmonic metal over a pulse is mud.
    count = max(2, int((3 if on_grid else 5) * density))
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
    # PUNCH, NOT SWELL. This was a 0.9-second fade-in on every note, which is a
    # swell by construction -- and it also threw away the transient the heavy
    # grit exists to produce, because there was nothing at the front of the note
    # loud enough to hear it on.
    #
    # Four parts now, and the first two are the punch: an attack of 6 ms, a fast
    # drop to a sustain, the sustain, then the release. A note arrives and then
    # settles, which is what every struck or plucked thing does and what no pad
    # does.
    env = np.clip(t / ATTACK_S, 0.0, 1.0)
    env = env * (SUSTAIN + (1.0 - SUSTAIN) * np.exp(-t / DECAY_S))
    env = env * np.exp(-np.clip(t - dur * 0.42, 0, None) / (dur * 0.34))
    return amp * y * env


def area_at(areas, frac):
    ch = areas[0][1]
    for at, c in areas:
        if frac >= at:
            ch = c
    return ch


def clashes(semi, ch):
    """Is this absolute pitch a semitone from anything the organ is holding?"""
    return any(abs(semi - c) == 1 for c in ch)


def voicing(iv, ch, want=2):
    """The melody note plus chord tones below it, as absolute pitches.

    A single note over a pad is always thinner than the pad, which is what made
    the lead sound small however much grit went on it. Each theme note is voiced
    with up to two tones taken from the area sounding underneath it -- taken
    from the area, never stacked by fixed interval, because a fixed third and
    fifth collides the moment the melody leaves the chord.

    JUDGED IN ABSOLUTE PITCH. The theme plays octaves above the organ, so a
    semitone in pitch CLASS between them is a major seventh spread over two
    octaves, which is a colour rather than a fault. Only a semitone in the same
    register is a clash.

    TWO THINGS THIS GETS RIGHT THAT EARLIER VERSIONS DID NOT. There is no
    unchecked fallback: if fewer than `want` safe tones exist the voicing is
    simply smaller, where stacking blind octaves to fill the quota put the
    clashes back in through the side door. And if the MELODY note itself would
    collide, the whole voicing moves up an octave rather than the melody being
    bent -- the tune is not negotiable, its register is.
    """
    base = THEME_OCTAVES * 12
    while clashes(base + iv, ch) and base < (THEME_OCTAVES + 1) * 12:
        base += 12
    out = [base + iv]
    for c in sorted({c for c in ch if c < iv}, reverse=True):
        if len(out) - 1 >= want:
            break
        semi = base + c
        if any(abs(semi - o) == 1 for o in out) or clashes(semi, ch):
            continue
        out.append(semi)
    return out


def _forms(form):
    return THEMES.get(form)

def v_theme(n, root, areas, form, total, drive):
    """The theme, voiced as chords. Driving cues state it more often, because a
    fight is not contemplative."""
    notes = _forms(form)
    if notes is None:
        return np.zeros(n)
    y = np.zeros(n)
    spots = ([0.14, 0.58] if drive else [0.10, 0.33, 0.56, 0.79])
    for sp in spots:
        base = sp * total
        for iv, off, dur in notes:
            ch = area_at(areas, ((base + off) / total) % 1.0)
            # SINGLE NOTE IN A FIGHT. A chord-voiced theme over a pulse is three
            # more moving parts; one line over a beat is a tune you can hear.
            want = 0 if drive else 2
            for k, v in enumerate(voicing(iv, ch, want)):
                amp = 0.125 if k == 0 else 0.062 / k
                place(y, v_sing(root * 2 ** (v / 12.0), dur, amp), base + off)
    return hp(y, 55.0, order=2)


def v_upper(n, root, areas, form, total, shimmer):
    """The same an octave up, voiced as a chord of its own."""
    notes = _forms(form)
    if notes is None:
        return np.zeros(n)
    y = np.zeros(n)
    for sp in (0.16, 0.46, 0.72):
        base = sp * total
        for iv, off, dur in notes:
            ch = area_at(areas, ((base + off) / total) % 1.0)
            for k, v in enumerate(voicing(iv, ch, 2)):
                f = root * 2 ** ((v + 12) / 12.0)
                place(y, v_sing(f, dur, (0.036 if k == 0 else 0.020) * shimmer),
                      base + off)
    return hp(y, 120.0, order=2)


# -------------------------------------------------------------------- build

def stem(cue, name):
    root_n, area_k, family, dark, form, density, shimmer, total, bpm = CUES[cue]
    root = root_hz(root_n)
    areas = AREAS[area_k]
    drive = family == "drive"
    # The flat sixth may only sound where the harmony holds one.
    # THE FLAT SIXTH ONLY WHERE THE HARMONY HOLDS ONE. A shape containing an 8
    # over a set that has none puts the melody a semitone from the chord, which
    # is the fault that made an earlier version unlistenable. Swapped
    # automatically rather than left to me to remember.
    if form and any(iv == 8 for iv, _, _ in THEMES[form]) and not HAS_FLAT6[area_k]:
        form = "answer"
    n = int((total + WRAP_S + 2.0) * SR)
    seed = abs(hash(cue)) % 100000
    np.random.seed(seed)

    if name == "pedal":
        y = v_pedal(n, root, dark, drive, areas, total, form)
    elif name == "organ":
        y = v_organ(n, root, areas, dark, total, drive)
    elif name == "breath":
        y = v_breath(n, dark)
    elif name == "motion":
        y = v_motion(n, root, areas, total, shimmer)
    elif name == "pulse":
        y = v_pulse(n, root, areas, total, bpm, dark, PULSE_OF.get(cue, "tresillo"))
    elif name == "stab":
        y = v_stab(n, root, areas, total, bpm, dark)
    elif name == "metal":
        y = v_metal(n, density, total, seed, drive, bpm or 120)
    elif name == "theme":
        y = v_theme(n, root, areas, form, total, drive)
    elif name == "upper":
        y = v_upper(n, root, areas, form, total, shimmer)
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
