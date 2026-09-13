"""The third edition: every cue is a written piece, not a texture.

    py -3.14 written.py            render every cue that is written
    py -3.14 written.py theme      one cue
    py -3.14 written.py --check    harmony only, render nothing

WHY THERE IS A THIRD EDITION. The second replaced a four-bar loop with a pedal
that never moves, harmony changing about once a minute, and a five-note motif
arriving three times a loop. That fixed hollow and it fixed sickly. It did not
produce music: a drone with events in it is a texture, and Jon, having heard a
written piece next to it, asked for the whole soundtrack to have that much depth.

WHAT DEPTH MEANT, CONCRETELY, MEASURED AGAINST WHAT WAS THERE:

                    second edition                  this one
    harmony         one pedal, area once a minute   a chord every two bars, with
                                                    sevenths and ninths
    melody          a five-note motif, three times  phrases that answer each other
    form            texture opening over 20 s       A / A' / B / A''
    bass            a pedal                         a written line that moves

THIRTEEN INDEPENDENT PIECES, which is Jon's call over my recommendation of a
suite. Each cue gets its own chart, its own tune and its own form, and they are
not variations of one another.

ONE THING SURVIVES THAT INDEPENDENCE AND IT IS NOT A STYLE CHOICE. The five cues
that crossfade through Audio.DEEP -- theme, dread, burn, boss, business -- are
all rooted on F. A shared root is what makes deep space read as the PLACE
TURNING rather than as the music cutting, and DEEP swaps between them mid-play.
Independent material, same root. `check_roots()` enforces it.

THE RULINGS INHERITED FROM space.py STILL APPLY. Exact tuning, no detune, no
tape wow. Heavy grit only where a voice is built for it and the post-crush filter
never below about 4 kHz. Effects first and then ONE equal-power fold, because
wrapping before the reverb truncates its tail at the loop point and that is a
click every loop forever -- measured once at 29% of peak.

AND ONE THIS EDITION ADDED. A bass you FEEL is a bass with a FRONT on it. The
line here is not a pedal and not a sustained tone: every note has a pitched thump
that sweeps an octave down onto it in about 50 ms, which took the peak-over-
sustain ratio from 1.41 to 2.75 while leaving the low end exactly where it was.
Feel turned out to live in the attack, not in the spectrum.
"""
from __future__ import annotations

import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import synth                                                    # noqa: E402
from synth import SR, bp, hp, lp                                # noqa: E402
from voices import VOICES, fold, phase, quant                   # noqa: E402
from charts import WRITTEN as _CHARTS                           # noqa: E402

SHIP = os.path.abspath(os.path.join(HERE, "..", "assets", "audio", "music"))
OUT = os.path.join(HERE, "out", "written")

BPB = 4                      ## beats in a bar
WRAP_S = 4.0                 ## tail folded back over the head
MEL_OCTAVE = 12              ## the melody sounds this far above the chart

NOTE = {"C": 0, "Db": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "Gb": 6, "G": 7,
        "Ab": 8, "A": 9, "Bb": 10, "B": 11}

## Stems per family, exactly as Audio.CUES already names them. Keeping these
## identical is what lets the whole edition ship without touching one line of
## GDScript: the mixer never looked inside a stem.
FAMILY_STEMS = {
    "drift": ("pedal", "organ", "motion", "metal", "theme", "upper"),
    "still": ("pedal", "organ", "breath", "metal", "theme", "upper"),
    "drive": ("pedal", "organ", "pulse", "metal", "theme", "stab"),
}

## Baked balance. Every stem plays at unit gain when the mixer turns it on, so
## the balance between them has to be in the files. The theme is deliberately
## well under the bass: Jon asked for the synth back and the bass forward, and
## the measured figure he settled on was about 8 dB.
GAIN = {
    "pedal": 1.00, "organ": 0.40, "motion": 0.30, "breath": 0.26,
    "pulse": 0.36, "metal": 0.20, "theme": 1.00, "upper": 0.24, "stab": 0.30,
}

## Where the tune sits against the bass. Jon asked for the bass forward and the
## synth back and settled on about this; `render_cue` measures rather than
## trusting GAIN["theme"], which is why that entry is 1.0 and does nothing.
THEME_UNDER_BASS_DB = -8.0


# --------------------------------------------------------------- the pieces

class Piece:
    """One cue: a key, a tempo, a chart, a tune, and which voice plays it."""

    def __init__(self, key, bpm, family, lead, chords, melody, note="",
                 pulse=(6, 6, 4), stabs=1):
        self.key, self.bpm, self.family = key, bpm, family
        self.lead, self.note = lead, note
        self.chords, self.melody = chords, melody
        # THE PULSE IS THE PIECE'S, NOT THE FAMILY'S. Three-three-two was
        # hardcoded for every drive cue, and it earned that: it is what came out
        # of "it is like math rock" when everything busier was rejected. But
        # three-three-two is SYNCOPATED, and syncopation reads as interesting
        # rather than as driving -- which is fine for a threat and wrong for a
        # battle. A cue can now say what its own pulse is, in eighth notes per
        # step, so relentless and syncopated are both reachable and neither is
        # the default for the other.
        self.pulse, self.stabs = pulse, stabs

    @property
    def root(self):
        return 440.0 * 2 ** ((NOTE[self.key[:-1]]
                              + 12 * (int(self.key[-1]) - 4) - 9) / 12.0)

    @property
    def spb(self):
        return 60.0 / self.bpm

    @property
    def body(self):
        return len(self.chords) * BPB * self.spb


def rich(ch, ninth=True):
    """A triad, extended. Root, third and fifth has told you everything it is
    going to tell you; the seventh is a direction it leans in and the ninth is
    colour belonging to no particular key.

    The quality is READ OFF THE TRIAD rather than declared -- a minor third takes
    a minor seventh, a major third a major one. Getting that backwards is the one
    way an extension sounds wrong rather than merely rich.
    """
    root, third = ch[0], ch[1]
    minor = (third - root) % 12 == 3
    out = list(ch) + [root + (10 if minor else 11)]
    if ninth:
        out.append(root + 14)
    return out


def prune(chords, mel, keep=3):
    """Withdraw any extension that fights the tune. THE MELODY WINS.

    An added note landing a semitone or a tritone from a note the melody is
    holding over it is worse than the plain triad it improved on. So extensions
    are offered and then taken back where they would collide; the first `keep`
    tones are the triad and stay whatever happens.
    """
    out = []
    for bar, ch in enumerate(chords):
        held = [(iv + MEL_OCTAVE, ln) for iv, at, ln in mel
                if ln >= 1.0 and int(at // BPB) == bar]
        keepers = list(ch[:keep])
        for ext in ch[keep:]:
            clash = False
            for h, ln in held:
                d = abs(ext - h)
                if d in (1, 13) or (d % 12 == 6 and ln >= 2.0):
                    clash = True
                    break
            if not clash:
                keepers.append(ext)
        out.append(keepers)
    return out


def check(name, chords, mel):
    """Landing notes belong to the chord; passing notes may do as they like.

    IN ABSOLUTE PITCH, which is the part that went wrong three times in one day.
    Comparing pitch CLASSES calls a C over a D flat chord a semitone clash; it is
    a major seventh, the colour every maj7 chord is built on. What the ear
    objects to is a minor second or a minor ninth between two notes actually
    sounding, so this compares the pitches that actually sound.
    """
    bad = []
    for iv, at, ln in mel:
        if ln < 1.0:
            continue
        bar = int(at // BPB)
        if bar >= len(chords):
            bad.append("%s: beat %g is past the end" % (name, at))
            continue
        note = iv + MEL_OCTAVE
        for c in chords[bar]:
            d = abs(note - c)
            if d in (1, 13):
                bad.append("%s: bar %d, %+d over %+d -- %s"
                           % (name, bar + 1, iv, c,
                              "minor 2nd" if d == 1 else "minor 9th"))
            elif d % 12 == 6 and ln >= 2.0 and not _structural(chords[bar], note, c):
                bad.append("%s: bar %d, %+d over %+d -- tritone, held %g beats"
                           % (name, bar + 1, iv, c, ln))
    return bad


def _structural(chord, note, other, keep=3):
    """Is this tritone the CHORD rather than a clash with it?

    A diminished triad is a tritone. So is an augmented one, near enough. The
    rule "no held tritone against a chord tone" is right for the tertian chords
    everything else here is built from, and it is exactly wrong for these: it
    rejects the harmony for containing the interval that defines it, which would
    quietly put the most menacing chord in music off limits.

    So the tritone rule is skipped where both notes belong to the TRIAD -- the
    first three tones, before any seventh or ninth is added. That is narrow on
    purpose. The semitone rule is untouched, and a tritone against an ADDED tone
    is still a clash, because an extension has no business introducing an
    interval the chord underneath it does not have.
    """
    triad = set(c % 12 for c in chord[:keep])
    return (note % 12) in triad and (other % 12) in triad


def the_long_way_home():
    """THE MAIN THEME. F minor, 76 BPM, an arch that reaches higher the second
    time and comes home lower than it left.

    This is the piece Jon picked out of three and then kept through twenty synth
    voices, and it is in F minor, which is exactly the root the DEEP crossfade
    group requires. It did not have to be transposed to take the job.
    """
    Fm, Db, Ab, Eb = [0, 3, 7], [8, 12, 15], [3, 7, 10], [10, 14, 17]
    Bbm, Cm = [5, 8, 12], [7, 10, 14]
    chords = ([Fm]*2 + [Db]*2 + [Ab]*2 + [Eb]*2 +          # A
              [Fm]*2 + [Db]*2 + [Bbm]*2 + [Cm]*2 +         # A'
              [Ab]*2 + [Eb]*2 + [Db]*2 +                   # B
              [Fm] + [Db] + [Ab] + [Eb] + [Fm]*2)          # A''
    chords = [rich(c) for c in chords]
    m = []
    m += [(0, 0, 2), (3, 2, 2), (7, 4, 3), (3, 7, 1)]
    m += [(8, 8, 3), (7, 11, 1), (3, 12, 4)]
    m += [(7, 16, 2), (10, 18, 2), (7, 20, 4)]
    m += [(14, 24, 3), (10, 27, 1), (7, 28, 4)]
    m += [(0, 32, 2), (3, 34, 2), (7, 36, 3), (10, 39, 1)]
    m += [(12, 40, 3), (8, 43, 1), (7, 44, 4)]
    m += [(8, 48, 2), (12, 50, 2), (17, 52, 4)]
    m += [(14, 56, 2), (10, 58, 2), (7, 60, 4)]
    m += [(15, 64, 4), (12, 68, 4)]
    m += [(17, 72, 3), (14, 75, 1), (10, 76, 4)]
    m += [(12, 80, 4), (8, 84, 4)]
    m += [(0, 88, 2), (3, 90, 2), (7, 92, 4)]
    m += [(10, 96, 2), (7, 98, 2), (2, 100, 4)]   # G, not Ab: Eb is under it
    m += [(0, 104, 8)]
    return Piece("F2", 76, "drift", "warm", chords, m,
                 "the arch: up to the fifth, lean on the flat sixth, fall back")


def perpetuity():
    """THE ARCHIVE, and the end of a run. E flat, 56 BPM, fourteen notes.

    The record of things that already happened, so it does not develop: it
    states, restates a little higher, goes somewhere quieter, and comes back. On
    DRAWBAR, which is the least science-fictional voice in the set -- octaves, a
    fifth, a key click, and nothing happening inside the note. An archive should
    sound like a room somebody keeps, not like deep space.
    """
    Eb, Cm, Ab, Bb = [0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14]
    Fm, Gm = [2, 5, 9], [4, 7, 11]
    chords = ([Eb]*2 + [Cm]*2 + [Ab]*2 + [Bb]*2 +
              [Eb]*2 + [Cm]*2 + [Fm]*2 + [Bb]*2 +
              [Ab]*2 + [Gm]*2 +
              [Eb] + [Cm] + [Ab] + [Eb])
    chords = [rich(c) for c in chords]
    m = []
    m += [(0, 0, 6), (7, 6, 2)]
    m += [(12, 8, 4), (9, 12, 4)]
    m += [(16, 16, 4), (12, 20, 4)]
    m += [(14, 24, 4), (11, 28, 4)]
    m += [(19, 32, 5), (16, 37, 3)]
    m += [(21, 40, 4), (16, 44, 4)]
    m += [(14, 48, 4), (9, 52, 4)]
    m += [(14, 56, 4), (11, 60, 4)]
    m += [(12, 64, 6), (16, 70, 2)]
    m += [(11, 72, 8)]
    m += [(0, 80, 4), (12, 84, 4)]
    m += [(9, 88, 4), (0, 92, 4)]
    return Piece("Eb2", 56, "still", "drawbar", chords, m,
                 "states, restates higher, goes quiet, comes back")


def nofault():
    """WHEN THE RUN ENDS. B minor, 52 BPM, the slowest thing in the set.

    Not a funeral -- that verdict was passed on an earlier edition and it was
    correct about the tempo but wrong about the cause. What makes music read as
    resigned is not slowness, it is a line that keeps falling and a harmony that
    keeps agreeing with it. So the tune descends three times and the third
    descent does not come back up.

    WAVEFOLD plays it: the timbre is a function of the amplitude, so every note
    darkens as it settles. Nothing else in the set does that, and here it means
    the instrument itself gives up over the length of a note.
    """
    Bm, G, D, A = [0, 3, 7], [8, 12, 15], [3, 7, 10], [10, 14, 17]
    Em, F_m = [5, 8, 12], [7, 10, 14]
    chords = ([Bm]*2 + [G]*2 + [D]*2 + [A]*2 +
              [Bm]*2 + [Em]*2 + [F_m]*2 + [G]*2 +
              [D]*2 + [A]*2 +
              [Bm] + [G] + [F_m] + [Bm])
    chords = [rich(c) for c in chords]
    m = []
    m += [(14, 0, 4), (12, 4, 4)]
    m += [(15, 8, 4), (12, 12, 4)]
    m += [(10, 16, 4), (7, 20, 4)]
    m += [(14, 24, 4), (10, 28, 4)]
    m += [(19, 32, 4), (15, 36, 4)]
    m += [(17, 40, 4), (12, 44, 4)]
    m += [(14, 48, 4), (10, 52, 4)]
    m += [(15, 56, 4), (12, 60, 4)]
    m += [(10, 64, 6), (7, 70, 2)]
    m += [(14, 72, 4), (10, 76, 4)]
    m += [(7, 80, 4), (3, 84, 4)]
    m += [(2, 88, 4), (0, 92, 4)]
    return Piece("B1", 52, "still", "wavefold", chords, m,
                 "three descents, and the third does not come back up")


def dread():
    """DEEP SPACE PAST DANGER 8. F, 60 BPM, Phrygian.

    Rooted on F because Audio.DEEP swaps this in for the theme mid-play and the
    shared root is what makes that read as the place turning. Everything else
    about it is different on purpose: where the theme is F minor with a flat
    sixth it can lean on, this is F PHRYGIAN -- the second degree flattened, so
    the chord a semitone above the root is a real chord you can sit on. That
    interval is the oldest menace in music and it costs nothing to use here,
    because the root never moves underneath it.

    SUB DRIVE plays it, an octave below where a lead would normally sit. It is
    the one voice that changes the balance of a piece rather than its colour,
    which is what deep space should do to the soundtrack.
    """
    Fm, Gb, Bbm, Db = [0, 3, 7], [1, 5, 8], [5, 8, 12], [8, 12, 15]
    Cm, Ebm = [7, 10, 14], [10, 13, 17]
    chords = ([Fm]*2 + [Gb]*2 + [Bbm]*2 + [Fm]*2 +
              [Fm]*2 + [Db]*2 + [Gb]*2 + [Cm]*2 +
              [Bbm]*2 + [Ebm]*2 +
              [Fm] + [Gb] + [Bbm] + [Fm])
    chords = [rich(c) for c in chords]
    m = []
    m += [(0, 0, 6), (3, 6, 2)]
    m += [(1, 8, 4), (5, 12, 4)]
    m += [(8, 16, 4), (5, 20, 4)]
    m += [(3, 24, 4), (0, 28, 4)]
    m += [(7, 32, 6), (3, 38, 2)]
    m += [(8, 40, 4), (12, 44, 4)]
    m += [(13, 48, 4), (8, 52, 4)]
    m += [(10, 56, 4), (7, 60, 4)]
    m += [(12, 64, 6), (8, 70, 2)]
    m += [(13, 72, 4), (10, 76, 4)]
    m += [(0, 80, 4), (1, 84, 4)]
    m += [(5, 88, 4), (0, 92, 4)]
    return Piece("F2", 60, "still", "sub_drive", chords, m,
                 "Phrygian: the chord a semitone above the root, over a root "
                 "that never moves")


## Cues written so far. The rest still come from space.py until they are done,
## and `render` only touches the ones named here -- so the soundtrack is never
## in a half-converted state that does not play.
PIECES = {
    "theme": the_long_way_home,
    "perpetuity": perpetuity,
    "nofault": nofault,
    "dread": dread,
}

## The rest of the cues live in charts.py, which holds music and no machinery:
## adding a cue should never mean editing the engine. They take Piece and rich as
## arguments rather than importing them, so charts.py imports nothing from here
## and there is no cycle to trip over.
for _name, _fn in _CHARTS.items():
    PIECES[_name] = (lambda f: (lambda: f(Piece, rich)))(_fn)

## Audio.DEEP crossfades within this set, so they share a root. Not a style
## choice: the swap reads as the place turning only because the root holds.
DEEP_GROUP = ("theme", "dread", "burn", "boss", "business")


def check_roots():
    bad = []
    for cue in DEEP_GROUP:
        if cue not in PIECES:
            continue
        k = PIECES[cue]().key
        if not k.startswith("F"):
            bad.append("%s is in %s -- the DEEP group must be rooted on F" % (cue, k))
    return bad


# ------------------------------------------------------------------- voices

def nt(root, iv):
    return root * 2 ** (iv / 12.0)


def place(buf, x, at, g=1.0):
    i = int(at * SR)
    if x.ndim == 1:
        j = min(len(buf), i + len(x))
        if j > i:
            buf[i:j] += x[:j - i] * g
    else:
        j = min(buf.shape[1], i + x.shape[1])
        if j > i:
            buf[:, i:j] += x[:, :j - i] * g


def bass_note(f, dur, amp=1.0):
    """One note of the bottom line, and it has to be FELT.

    A whole-bar sustained tone with a soft fade-in has no transient, so nothing
    ever lands, and no amount of level fixes that. The thump is a sine sweeping
    from an octave above the note down onto it in about 50 ms -- the trick a kick
    drum uses, and the reason a kick reads as a hit rather than as a low note.
    Sweeping it from any higher puts its energy in the 120-250 band, which is
    audible but is not FELT: an earlier attempt swept from 227 Hz and lost eight
    points of chest while looking, on the meter, like an improvement.
    """
    n = int(dur * SR)
    t = np.arange(n) / SR
    # DEEP IS NOT THE SAME AS WEIGHTY. The fundamental here is around 43 Hz, and
    # leaning on it put 23% of the part between 40 and 70 Hz plus another 2.5%
    # below 40, which nothing reproduces and which only eats headroom. That reads
    # as deep and muddy rather than as strong. The weight moves up one partial:
    # the octave above the fundamental is now the loudest thing in the note, so
    # the line is carried where the ear is actually sensitive and the bottom is
    # support rather than subject.
    y = (0.72 * np.sin(2 * np.pi * f * t)
         + 1.00 * np.sin(4 * np.pi * f * t)
         + 0.26 * np.sin(6 * np.pi * f * t + 0.7))
    y = np.tanh(y * 1.5) / np.tanh(1.5)
    drop = f * (1.0 + 1.0 * np.exp(-t / 0.055))
    y = y + 0.70 * np.sin(2 * np.pi * np.cumsum(drop) / SR) * np.exp(-t / 0.121)
    # Everything under 32 Hz is inaudible on every speaker this game will meet
    # and costs real headroom in a mix normalised to its peak.
    y = hp(y, 32.0, order=2)
    # THE PUNCH COMES BACK OUT OF THE ENVELOPE, NOT OUT OF MORE BOTTOM. Moving
    # the weight up a partial to clear the mud cost peak-over-sustain, 2.75x down
    # to 2.14x, and the obvious repair -- put the low end back -- would undo the
    # thing that was just fixed. A lower sustain does it for free: the note still
    # arrives exactly as hard, it just gets out of its own way sooner. Measured
    # across twelve settings, 0.45 restores 2.68x and 0.38 would give 3.15x at
    # the cost of the note sounding plucked rather than held, which a bass LINE
    # cannot afford.
    e = np.clip(t / 0.004, 0, 1) * (0.45 + 0.55 * np.exp(-t / 0.13))
    e = e * np.clip((dur - t) / 0.25, 0, 1)
    return amp * 0.80 * y * e


def pad_chord(root, ivs, dur, cut=1600.0, amp=1.0):
    """The chords, AN OCTAVE ABOVE WHERE THEY WERE.

    THE PAD WAS THE MUD, not the bass. Measured on the shipped theme cue, 76% of
    this stem sat between 110 and 350 Hz -- which is the mud register by
    definition and also exactly where the bass is working. Two instruments in one
    octave is how an arrangement turns to soup no matter how good either of them
    is, and the fix is the oldest one there is: give them different rooms.

    So the chords are voiced from the octave above the chart now. The bass owns
    everything below about 120 Hz and the pad owns 200 to 600, and neither is
    fighting the other for the same air. Nothing about the harmony changed -- the
    same notes, an octave up.
    """
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for iv in ivs:
        f = nt(root, iv + 12)
        y += (np.sin(2 * np.pi * f * t) + 0.24 * np.sin(4 * np.pi * f * t))
    y = hp(lp(y / max(len(ivs), 1), cut, order=2), 150.0, order=2)
    sw = np.clip(t / (dur * 0.18), 0, 1) * np.clip((dur - t) / (dur * 0.22), 0, 1)
    return amp * y * sw


def v_pedal(p, n):
    """THE BASS, AND IT IS A LINE NOW. The root of every chord, which means it
    moves with the harmony instead of sitting under it. Every second bar takes
    the fifth on the offbeat, which is what stops a moving bass from reading as
    a series of announcements."""
    y = np.zeros(n)
    for b, ivs in enumerate(p.chords):
        at = b * BPB * p.spb
        f = nt(p.root, ivs[0]) * 0.5
        place(y, bass_note(f, BPB * p.spb * 0.96), at)
        if b % 2 == 1:
            place(y, bass_note(f * 2 ** (7 / 12.0), BPB * p.spb * 0.30, 0.26),
                  at + BPB * p.spb * 0.5)
    return y


def v_organ(p, n):
    """The harmony itself, held. This is the stem that carries the depth at rung
    zero: before any tune arrives, the chords are already moving."""
    y = np.zeros(n)
    for b, ivs in enumerate(p.chords):
        place(y, pad_chord(p.root, ivs, BPB * p.spb * 1.02), b * BPB * p.spb)
    return y


def v_motion(p, n, rs):
    """Chord tones rippling, no beat -- movement for the cues that are not
    fights. Each bar picks its tones from the chord under it, so the ripple is
    the harmony rather than an ornament laid over it."""
    y = np.zeros(n)
    for b, ivs in enumerate(p.chords):
        at = b * BPB * p.spb
        for k in range(4):
            iv = ivs[(k * 2 + b) % len(ivs)] + 12
            f = nt(p.root, iv)
            d = p.spb * (1.6 + 0.5 * rs.rand())
            m = int(d * SR)
            t = np.arange(m) / SR
            v = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t)
            v *= np.clip(t / 0.25, 0, 1) * np.exp(-t / (d * 0.42))
            place(y, lp(v, 2600.0, order=2), at + k * BPB * p.spb / 4.0
                  + 0.12 * rs.rand(), 0.5)
    return y


def v_breath(p, n, rs):
    """Air that swells with the chord changes. The still family gets this where
    drift gets motion: the place is not going anywhere, but it is breathing."""
    y = np.zeros(n)
    for b, ivs in enumerate(p.chords):
        at = b * BPB * p.spb
        d = BPB * p.spb * 1.1
        m = int(d * SR)
        t = np.arange(m) / SR
        f = nt(p.root, ivs[min(1, len(ivs) - 1)] + 12)
        v = bp(rs.randn(m), f * 0.7, f * 2.3, order=2)
        v *= np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.6
        place(y, v, at, 0.9)
    return y


def v_pulse(p, n, rs):
    """THE DRIVE FAMILY, AND IT IS NOT A DRUM KIT. Rhythm here is a pulse, not a
    groove: no kick, no snare, no backbeat. A low ostinato on the chord root with
    the filter doing the work a kit would do, in three-three-two, which is the
    pattern that survived when everything busier was called math rock."""
    y = np.zeros(n)
    steps = p.pulse
    for b, ivs in enumerate(p.chords):
        at = b * BPB * p.spb
        pos, unit = 0, p.spb / 4.0
        for s in steps:
            f = nt(p.root, ivs[0] + 12)
            d = s * unit * 0.92
            m = int(d * SR)
            t = np.arange(m) / SR
            v = np.tanh(3.0 * (np.sin(2 * np.pi * f * t)
                               + 0.5 * np.sin(4 * np.pi * f * t)))
            v *= np.clip(t / 0.003, 0, 1) * np.exp(-t / (d * 0.30))
            place(y, lp(v, 1800.0, order=2), at + pos * unit)
            pos += s
    return y


def v_metal(p, n, rs):
    """Struck accents that BELONG TO THE CHORD.

    These were inharmonic -- partials at 1, 2.76, 5.40 and 8.93, the measured
    ratios of a tubular bell -- and the note in this docstring defended that:
    whole multiples would only reinforce the chord and vanish into it. That
    reasoning came from the second edition, where there was no harmony for a bell
    to be out of tune WITH. A pedal that never moves has no opinion about an
    inharmonic ping over it.

    There are fourteen chords moving now, and against them an inharmonic partial
    is the one event in the arrangement that belongs to no chord at all. Jon
    heard it immediately and called it weird, which is exactly what it was.

    So the ratios are whole numbers and the pitch is a chord tone -- the third or
    the fifth of whatever is sounding, never the root, because the root is
    already the loudest thing in the cue. What makes it read as struck metal is
    now the ENVELOPE rather than the tuning: four milliseconds to full, upper
    partials dying faster than lower ones, and a long tail. That is what a struck
    metal bar actually does; the inharmonicity was never the part carrying it.
    """
    y = np.zeros(n)
    for b, ivs in enumerate(p.chords):
        if b % 2:
            continue
        at = b * BPB * p.spb + p.spb * (1.0 + 2.0 * rs.rand())
        iv = ivs[1 + int(rs.rand() * min(2, len(ivs) - 1))] + 24
        f = nt(p.root, iv)
        d = 2.2
        m = int(d * SR)
        t = np.arange(m) / SR
        v = np.zeros(m)
        for h, a_ in ((1, 1.00), (2, 0.44), (3, 0.20), (4, 0.11), (6, 0.05)):
            v += a_ * np.sin(2 * np.pi * f * h * t + h * 0.6) *                 np.exp(-t / (d * 0.34 / h ** 0.55))
        v *= np.clip(t / 0.004, 0, 1)
        place(y, hp(v, 400.0, order=2), at, 0.5)
    return y


def v_theme(p, n):
    """The tune, in the voice the cue was given. This is the only stem that
    changes instrument between cues, and it is rung 2 -- the place noticing you
    has harmony and motion already; the theme is what arrives on top."""
    fn = VOICES[p.lead]
    y = np.zeros((2, n))
    prev_f, prev_end = None, None
    for iv, at, ln in p.melody:
        f, start = nt(p.root, iv + MEL_OCTAVE), at * p.spb
        from_f = prev_f if (prev_end is not None
                            and start - prev_end < p.spb * 0.30) else None
        v = fn(f, ln * p.spb * 0.96, from_f)
        if v.ndim == 1:
            v = np.vstack([v, v])
        place(y, v, start)
        prev_f, prev_end = f, start + ln * p.spb
    return y


def v_upper(p, n, rs):
    """A counter-line: chord tones an octave and a half up, on the bars the tune
    leaves alone. It answers the melody rather than doubling it, which is the
    difference between an arrangement and a thickener."""
    busy = set(int(at // BPB) for iv, at, ln in p.melody)
    y = np.zeros(n)
    for b, ivs in enumerate(p.chords):
        if b in busy and b % 2 == 0:
            continue
        at = b * BPB * p.spb + BPB * p.spb * 0.5
        iv = ivs[min(2, len(ivs) - 1)] + 24
        d = BPB * p.spb * 0.45
        m = int(d * SR)
        t = np.arange(m) / SR
        f = nt(p.root, iv)
        v = np.sin(2 * np.pi * f * t) + 0.22 * np.sin(4 * np.pi * f * t)
        v *= np.clip(t / (d * 0.3), 0, 1) * np.clip((d - t) / (d * 0.4), 0, 1)
        place(y, lp(v, 5200.0, order=2), at, 0.7)
    return y


def v_stab(p, n, rs):
    """Filtered chord stabs landing ON the bar, for the fights. Short, bright,
    and harmonically the same chart as everything else -- a fight in this game is
    the same place, louder."""
    y = np.zeros(n)
    for b, ivs in enumerate(p.chords):
        for k in range(p.stabs):
            at = b * BPB * p.spb + k * BPB * p.spb / float(p.stabs)
            d = p.spb * 0.7
            m = int(d * SR)
            t = np.arange(m) / SR
            v = np.zeros(m)
            for iv in ivs[:4]:
                f = nt(p.root, iv + 12)
                v += np.sin(2 * np.pi * f * t) + 0.4 * np.sin(4 * np.pi * f * t)
            v = fold(v / len(ivs[:4]), 1.5)
            v *= np.clip(t / 0.003, 0, 1) * np.exp(-t / (d * 0.26))
            place(y, quant(v, 8, 2, 5200.0), at, 0.8 if k == 0 else 0.55)
    return y


# ------------------------------------------------------------------ rendering

def wrap(x, body_s):
    """Equal-power fold of the tail back over the head. EFFECTS FIRST.

    Wrapping before the delay and the reverb truncates both tails at the loop
    point: measured once at a 29%-of-peak step, which is a click every loop
    forever. Every stem folds at the same body length, so they stay aligned.
    """
    n = int(body_s * SR)
    w = int(WRAP_S * SR)
    body = x[:, :n].copy()
    tail = x[:, n:n + w]
    k = tail.shape[-1]
    if k > 0:
        a = np.linspace(0.0, np.pi / 2, k)
        body[:, :k] = body[:, :k] * np.sin(a) + tail * np.cos(a)
    return body


def stem(p, name, rs):
    n = int((p.body + WRAP_S + 2.0) * SR)
    if name == "pedal":
        y = v_pedal(p, n)
    elif name == "organ":
        y = v_organ(p, n)
    elif name == "motion":
        y = v_motion(p, n, rs)
    elif name == "breath":
        y = v_breath(p, n, rs)
    elif name == "pulse":
        y = v_pulse(p, n, rs)
    elif name == "metal":
        y = v_metal(p, n, rs)
    elif name == "theme":
        y = v_theme(p, n)
    elif name == "upper":
        y = v_upper(p, n, rs)
    elif name == "stab":
        y = v_stab(p, n, rs)
    else:
        raise ValueError(name)

    st = y if y.ndim == 2 else np.vstack([y, y])
    if name != "theme":
        # Width by a different short delay per channel. The theme voices are
        # already wide where they want to be and running them through this would
        # smear the width they have.
        #
        # THE PAD GETS A THIRD OF IT, AND THAT IS A CONSEQUENCE OF MOVING IT UP.
        # Two delays 12 ms apart decorrelate almost nothing at 90 Hz and a great
        # deal at 400, so voicing the chords an octave higher to clear the mud
        # silently doubled their width -- measured, the theme went from 0.17
        # mid/side to 0.60 and six cues lost between 1.5 and 1.9 dB when summed
        # to mono. Phones, laptops and most televisions do exactly that sum, so
        # it is not a hypothetical. A chord is already broad by having several
        # notes in it and needs very little help.
        g = 0.09 if name == "organ" else 0.26
        for ch, d in ((0, 0.019), (1, 0.031)):
            k = int(d * SR)
            st[ch, k:] += st[ch, :-k] * g
    st = synth.reverb(st, wet=0.34 if p.family == "drive" else 0.52)

    # THE BASS STAYS IN THE MIDDLE. Measured on the theme cue, the pedal was
    # carrying 0.081 of the mix's 0.089 side energy all by itself, at a mid/side
    # ratio of 0.65 -- a wide bass, which is the oldest mono-compatibility
    # failure there is and also why six cues were losing up to 1.9 dB when summed
    # to one speaker. It got there honestly: a short delay that differs per
    # channel plus a reverb with independent left and right impulses will
    # decorrelate anything, and moving the bass weight up a partial to clear the
    # mud gave both of them more to work with.
    #
    # I blamed the pad first and turned its width down, which changed the number
    # not at all. Measuring per stem took one minute and named the right one.
    if name == "pedal":
        st = np.vstack([st.mean(axis=0)] * 2)
    return wrap(st, p.body)


def render_cue(cue, wav_only=False):
    import build as bld
    p = PIECES[cue]()
    p.chords = prune(p.chords, p.melody)
    rs = np.random.RandomState(abs(hash(cue)) % 100000)

    stems = {}
    for name in FAMILY_STEMS[p.family]:
        stems[name] = stem(p, name, rs) * GAIN[name]

    # THE THEME LEVEL IS MEASURED, NOT ASSUMED. A fixed gain cannot hold this
    # balance: the seven voices differ enormously in how efficiently they turn a
    # waveform into audible energy, and at one setting for all of them the theme
    # came out anywhere from 3.4 to 10.8 dB under the bass across four cues. So
    # the theme stem is scaled per cue against the bass it actually sits on. It
    # is the same rule the twenty-voice audition ran on: a voice that happens to
    # be louder wins for the wrong reason.
    def rms(x):
        return float(np.sqrt(np.mean(x ** 2)))

    want = rms(stems["pedal"]) * 10 ** (THEME_UNDER_BASS_DB / 20.0)
    stems["theme"] *= want / max(rms(stems["theme"]), 1e-9)

    # ONE SCALE FOR ALL OF THEM. Normalising each stem on its own would throw
    # away the balance that was just baked in; the mixer plays them at unit gain
    # and only the files carry the mix. So the full arrangement decides the
    # scale and every stem is multiplied by the same number.
    full = sum(stems.values())
    peak = float(np.abs(full).max())
    k = 0.92 / peak if peak > 0 else 1.0

    os.makedirs(OUT, exist_ok=True)
    total = 0
    for name, st in stems.items():
        w = os.path.join(OUT, "%s_%s.wav" % (cue, name))
        synth.write_wav(w, st * k)
        if wav_only:
            continue
        dst = os.path.join(SHIP, cue, "%s.ogg" % name)
        bld.ogg(dst, w, compression=0.5)
        total += os.path.getsize(dst)
    return p, total, peak * k


def main(argv):
    want = [a for a in argv if not a.startswith("-")]
    only_check = "--check" in argv
    cues = want or sorted(PIECES)

    bad = check_roots()
    for cue in cues:
        p = PIECES[cue]()
        pruned = prune(p.chords, p.melody)
        bad += check(cue, pruned, p.melody)
    if bad:
        print("HARMONY PROBLEMS -- nothing rendered")
        for b in bad:
            print("  " + b)
        return 1
    print("harmony clean: %d cue(s)" % len(cues))
    if only_check:
        return 0

    grand = 0
    for cue in cues:
        p, total, peak = render_cue(cue)
        grand += total
        print("  %-12s %-6s %-13s %2d bars  %5.1f s  %3d notes  %6.0f KB"
              % (cue, p.family, p.lead, len(p.chords), p.body,
                 len(p.melody), total / 1024.0))
    print("\n%.1f MB" % (grand / 1e6))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
