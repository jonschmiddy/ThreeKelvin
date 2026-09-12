"""The bed under everything: what the ship sounds like when nothing is happening.

    py -3.14 ambience.py            render and encode all three
    py -3.14 ambience.py --wav      stop at the WAVs, for listening

THIRTEEN CUES AND SIXTY EFFECTS, AND NO ROOM TONE.  The music is the most
finished thing in this project and it is also the only thing making noise, so
the gaps between cues read as the audio having stopped rather than as deep
space.  A bed fixes that by being the thing you notice only when it goes.

Three loops, and the third is the important one:

  reactor   your own ship, always there, level following heat
  hull      cold metal moving, sparse and irregular
  radio     other people, near settled space, and NOTHING out deep

The silence out deep is a feature and it is the setting's own idea.  lore.md
calls the cheapest horror in this world "a system that is empty and still
talking"; the other half of that is a system that is empty and does not.  If
the bed played everywhere it would be wallpaper.  It thins as you go coreward
so that the one place it stops means something.

RULES THIS OBEYS, from DREAD_NOTES.md and the docs around it:

* No drum kit anywhere; rhythm is a pulse, not a groove.  The hull ticks are
  spaced by a random walk with a hard minimum, never on a grid -- the moment
  two of them land a bar apart the ship has a tempo and the dread is gone.
* No pitch centre.  The reactor sits on a low F pedal, the same note the cues
  hang off, so the bed is never in an argument with the music above it.  It
  states no third and no fifth, which is what lets any cue sit on top.
* Quiet.  These are mixed to sit under a cue at its lowest rung, not beside it.

SEAMLESS, AND WHY IT IS NOT THE CUES' WRAP.  `synth.Track` wraps a reverb tail
past a bar line because a cue is music with a known bar.  A bed has no bar, so
these wrap on their own length: the last WRAP_S seconds are faded over the head
and dropped.  A loop point you can hear is worse than no bed.

DETERMINISM.  Seeded, so two renders here are identical.  Across machines they
are not -- a different numpy build gives the same design with different noise,
which for a noise bed is the whole content.  These are new material with nothing
to match, so unlike the cues there is no master to avoid mixing with.
"""
from __future__ import annotations

import os
import sys

import numpy as np

import synth
from synth import SR, bp, hp, lp

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SHIP = os.path.join(HERE, "..", "assets", "audio", "ambience")

## Seconds of tail folded back over the head to hide the seam.
WRAP_S = 2.0
## The pedal the whole soundtrack hangs off. THEME_NOTES has the motif refusing
## to touch its fifth; this refuses to touch anything at all.
F_PEDAL = 43.65          # F1


def _wrap(x: np.ndarray, length_s: float) -> np.ndarray:
    """Fold the tail over the head so the loop has no seam.

    BOTH SIDES RAMP, and the first version only ramped one. Adding a fading
    tail on top of a head left at full level hides a reverb tail, which is what
    the cues need, but it does nothing about the joint itself: the last sample
    of the body still has to meet the first, and for a continuous tone it does
    not. Measured on the reactor bed, that version left a step of 0.060 against
    a peak of 0.112 -- a click, once every twelve seconds, forever.

    With the head rising from zero the first output sample IS the first sample
    of the tail, which is the sample that followed the body's last one in the
    original render. So the joint is continuous by construction rather than by
    luck, whatever the content is.

    Equal power rather than linear: these are noise beds, and a linear
    crossfade of two uncorrelated signals dips ~3 dB in the middle.
    """
    n = int(length_s * SR)
    w = int(WRAP_S * SR)
    body = x[:, :n].copy()
    tail = x[:, n:n + w]
    k = tail.shape[1]
    if k > 0:
        a = np.linspace(0.0, np.pi / 2, k)
        body[:, :k] = body[:, :k] * np.sin(a) + tail * np.cos(a)
    return body


def _stereo(mono_l: np.ndarray, mono_r: np.ndarray) -> np.ndarray:
    n = min(len(mono_l), len(mono_r))
    return np.vstack([mono_l[:n], mono_r[:n]])


def _norm(x: np.ndarray, peak_db: float) -> np.ndarray:
    m = float(np.max(np.abs(x)))
    if m <= 0.0:
        return x
    return x / m * (10.0 ** (peak_db / 20.0))


def reactor(length_s: float = 12.0) -> np.ndarray:
    """The ship itself. A low pedal that never resolves and never stops.

    Detuned so it beats slowly against itself: one oscillator is a tone and
    three are a machine, and the beating is what stops it sounding synthetic.
    The game rides its VOLUME with heat, so nothing here brightens on its own --
    a bed that changed by itself would read as an event.
    """
    np.random.seed(31)
    n = int((length_s + WRAP_S) * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for f, a in ((F_PEDAL, 1.0), (F_PEDAL * 1.004, 0.7), (F_PEDAL * 2.0, 0.32),
                 (F_PEDAL * 2.995, 0.13)):
        y += a * np.sin(2 * np.pi * f * t + np.random.rand() * 6.283)
    # Coolant moving somewhere behind it. Filtered hard: this is felt, not heard.
    flow = lp(np.random.randn(n), 190.0, order=4) * 0.55
    y = y * 0.5 + flow
    # A very slow swell, prime-ratio periods so it never lines up with itself
    # inside the loop and never with the music above it.
    swell = (1.0
             + 0.055 * np.sin(2 * np.pi * t / 7.0)
             + 0.035 * np.sin(2 * np.pi * t / 11.0))
    y *= swell
    st = _stereo(y, np.roll(y, 313))          # a few ms of width, no more
    return _norm(_wrap(st, length_s), -19.0)


def hull(length_s: float = 24.0) -> np.ndarray:
    """Cold metal deciding to move. Sparse, irregular, never on a grid.

    The spacing is a random walk with a floor rather than a rate, because a
    Poisson process still clusters and two ticks close together read as a
    machine starting up. A floor of MIN_GAP keeps every one of them alone.
    """
    np.random.seed(17)
    n = int((length_s + WRAP_S) * SR)
    # Built in stereo from the start, because WHERE a creak came from is most
    # of what makes it sound like a hull rather than a sample. Summing to mono
    # and widening afterwards, as the other two beds do, would put every tick
    # in the middle of your head.
    st = np.zeros((2, n))
    min_gap, at = 1.6, 0.9
    while at < length_s + WRAP_S:
        i = int(at * SR)
        # Two kinds: a short tick, and a longer creak that bends as it decays.
        creak = np.random.rand() < 0.42
        dur = 0.55 if creak else 0.08
        m = int(dur * SR)
        if i + m >= n:
            break
        tt = np.arange(m) / SR
        env = np.exp(-tt * (3.2 if creak else 42.0))
        if creak:
            f0 = 180.0 + np.random.rand() * 140.0
            v = np.sin(2 * np.pi * f0 * tt * (1.0 - 0.18 * tt)) * env
            v += bp(np.random.randn(m), 300.0, 1400.0, order=2) * env * 0.5
        else:
            v = bp(np.random.randn(m), 900.0, 4200.0, order=2) * env
        v *= 0.35 + np.random.rand() * 0.4
        pan = np.random.rand() * 1.6 - 0.8
        st[0, i:i + m] += v * np.cos((pan + 1) * np.pi / 4)
        st[1, i:i + m] += v * np.sin((pan + 1) * np.pi / 4)
        at += min_gap + np.random.rand() * 3.4
    return _norm(_wrap(st, length_s), -24.0)


def radio(length_s: float = 20.0) -> np.ndarray:
    """Other people, a long way off, saying nothing you can make out.

    NO WORDS AND NO MORSE. A pattern a player could learn to decode is a puzzle,
    and this is a place. What survives a hundred astronomical units of nothing is
    the envelope of speech and none of its content, so that is what this is:
    band-limited noise shaped like somebody talking, through a filter far too
    narrow to carry a voice.
    """
    np.random.seed(5)
    n = int((length_s + WRAP_S) * SR)
    y = np.zeros(n)
    at = 1.2
    while at < length_s + WRAP_S:
        # A burst is a few syllables, then a long gap. The gap is most of it.
        burst = 0.6 + np.random.rand() * 1.4
        m = int(burst * SR)
        i = int(at * SR)
        if i + m >= n:
            break
        tt = np.arange(m) / SR
        # Syllable envelope: a slow wobble, rectified, so it opens and closes
        # the way speech does without ever being speech.
        rate = 3.4 + np.random.rand() * 2.2
        syl = np.abs(np.sin(2 * np.pi * rate * tt + np.random.rand() * 6.283))
        syl *= np.exp(-((tt - burst / 2) ** 2) / (burst * 0.34) ** 2)
        v = bp(np.random.randn(m), 620.0, 2200.0, order=4) * syl
        y[i:i + m] += v * (0.5 + np.random.rand() * 0.5)
        at += burst + 2.2 + np.random.rand() * 5.0
    y = hp(y, 380.0, order=2)
    st = _stereo(y, np.roll(y, 911))
    return _norm(_wrap(st, length_s), -27.0)


BEDS = {"reactor": reactor, "hull": hull, "radio": radio}


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    wav_only = "--wav" in sys.argv
    import build

    for name, fn in BEDS.items():
        x = fn()
        wav = os.path.join(OUT, "ambience_%s.wav" % name)
        synth.write_wav(wav, x)
        size = os.path.getsize(wav) / 1024.0
        if wav_only:
            print("  %-8s %5.1fs  %7.0f KB  %s" % (name, x.shape[1] / SR, size, wav))
            continue
        dst = os.path.join(SHIP, "%s.ogg" % name)
        build.ogg(dst, wav)
        print("  %-8s %5.1fs  wav %6.0f KB -> ogg %5.0f KB"
              % (name, x.shape[1] / SR, size, os.path.getsize(dst) / 1024.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
