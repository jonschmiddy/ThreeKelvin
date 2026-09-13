"""The seven lead voices Jon kept, out of twenty auditioned.

    Warm          410 Hz    travel, the long exposure
    Drawbar       651 Hz    station, settled space
    Octave Stack  720 Hz    the theme
    Squelch       786 Hz    combat
    Sub Drive     798 Hz    deep space, danger 8 and up
    Wavefold      866 Hz    the theme, alternate
    Four Bit     2353 Hz    combat

The numbers are measured spectral centroids and the order is by them, which is
also roughly the order from restful to abrasive.

WHAT IS FIXED IN ALL SEVEN, AND WHY:

  EXACT TUNING. Nothing detuned, no wow, no drift anywhere. Thickening a synth
  by detuning two copies of it is the usual trick and it is what made an earlier
  lead sound SICKLY: slow beating between near-unisons reads as out of tune, not
  as wide. Where a voice here is wide it is wide because its two channels carry
  different WAVEFORMS at the same pitch, which nothing downstream can undo.

  THEY GLIDE. The oscillator runs on an instantaneous frequency and phase is the
  running sum of it, so pitch can travel inside a note without the waveform
  tearing at the joint. The ramp is exponential, because equal ratios are equal
  intervals and a straight line in hertz slides fast at the bottom and crawls at
  the top. Timed off the size of the leap: about 70 ms for a tone, 150 for an
  octave, and a note that follows a rest does not glide at all -- sliding in out
  of silence is a different effect and not this one.

  SUSTAIN, NOT DECAY, except where a voice is a struck thing by definition.
  A slow tune made of struck notes is a row of separate events rather than a
  line, and that is most of what made the lead read as a piano.

  LEVEL IS NOT THEIR BUSINESS. Every one returns whatever amplitude falls out of
  its construction and is normalised by the caller. A voice that happens to be
  3 dB louder wins a blind listen every time and wins it for the wrong reason.
"""
from __future__ import annotations

import numpy as np
from scipy import signal

from synth import SR, bp, lp

GRIT = (7, 4, 1.85, 4.0)     ## bits, decimation, fold, drive -- see space.v_sing
GRIT_CUT = 4600.0

SAW = ((1, 1.00, 0.35), (2, 0.52, 1.10), (3, 0.30, 2.00), (4, 0.20, 0.70),
       (5, 0.15, 1.40), (6, 0.13, 1.60), (8, 0.08, 0.20))
ODD = ((1, 1.00, 0.35), (3, 0.42, 2.00), (5, 0.26, 0.90), (7, 0.17, 1.70),
       (9, 0.11, 0.40), (11, 0.07, 2.30))


def fold(x, k):
    return np.sin(x * k * np.pi / 2.0)


def phase(f, dur, f0=None):
    """Samples, time, and running phase, with the glide folded into it."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    if f0 is not None and abs(np.log2(f0 / f)) > 0.01:
        steps = abs(12.0 * np.log2(f0 / f))
        g = min(0.05 + 0.009 * steps, 0.15, dur * 0.45)
        r = np.clip(t / g, 0, 1)
        r = r * r * (3.0 - 2.0 * r)
        inst = f0 * (f / f0) ** r
    else:
        inst = np.full(n, f)
    return n, t, 2.0 * np.pi * np.cumsum(inst) / SR


def env(t, dur, atk=0.07, rel=0.45):
    e = np.clip(t / atk, 0, 1) * (0.86 + 0.14 * np.exp(-t / 0.6))
    return e * np.clip((dur - t) / min(rel, dur * 0.35), 0, 1) ** 1.4


def harm(ph, parts):
    y = np.zeros(len(ph))
    for h, a, off in parts:
        y += a * np.sin(h * ph + off)
    return y


def sweep(y, t, dur, cuts=(520.0, 1150.0, 2400.0, 4800.0), speed=0.22,
          tilt=0.70, res=0.0):
    """A filter opening across the note, then easing shut again.

    Four fixed filters crossfaded, not one moving filter: the partials stay in
    phase, and a real per-sample sweep would cost a Python loop per note to buy
    nothing anyone can hear. `res` adds a bandpass at the cutoff, which is what
    resonance is.
    """
    n = len(y)
    bands = []
    for c in cuts:
        b = lp(y, c, order=2)
        if res:
            b = b + res * bp(y, c * 0.75, min(c * 1.35, 20000.0), order=2)
        bands.append(b)
    bands = np.vstack(bands)
    rise = np.clip(t / max(dur * speed, 0.09), 0, 1) ** tilt
    fall = np.exp(-np.clip(t - dur * 0.35, 0, None) / max(dur * 0.70, 0.5))
    sw = 0.35 + 2.65 * rise * (0.45 + 0.55 * fall)
    k = np.clip(sw.astype(int), 0, 2)
    fr = sw - k
    ix = np.arange(n)
    return bands[k, ix] * (1.0 - fr) + bands[k + 1, ix] * fr


def quant(y, bits, decim, cut, off=0):
    """Bit-crush and decimate, then filter -- and the filter must stay high.

    Crushing ADDS aliasing, aliasing is high-frequency content, so a crushed
    voice comes out brighter than it went in and every instinct says to filter it
    back down. Filter below about 4 kHz and the rasp goes with it, which is the
    entire reason for crushing it. `off` moves the decimation grid, which is
    used for stereo decorrelation where a voice wants it.
    """
    q = float(2 ** (bits - 1))
    y = np.round(y * q) / q
    if decim > 1:
        n = len(y)
        head, tail = y[:off], y[off:]
        tail = np.repeat(tail[::decim], decim)[:len(tail)]
        y = np.concatenate([head, tail])[:n]
        if len(y) < n:
            y = np.pad(y, (0, n - len(y)))
    return lp(y, cut, order=3)


# ------------------------------------------------------------------ the seven

def warm(f, dur, f0=None):
    """Low harmonics, filtered soft, no grit and barely any movement. The
    quietest thing on the list: nothing here competes for attention, which over
    forty minutes is a feature rather than a shortcoming."""
    n, t, ph = phase(f, dur, f0)
    y = harm(ph, ((0.5, 0.40, 0.0), (1, 1.00, 0.35), (2, 0.38, 1.10),
                  (3, 0.14, 2.00), (4, 0.06, 0.70))) / 2.0
    y = np.tanh(y * 1.3) / np.tanh(1.3)
    return lp(y, 1500.0, order=2) * env(t, dur, atk=0.13)


def drawbar(f, dur, f0=None):
    """Octaves and a fifth, no filter movement at all, on and off, with the key
    click the real instrument makes because its contacts close out of step. The
    only voice with nothing happening inside the note."""
    n, t, ph = phase(f, dur, f0)
    y = harm(ph, ((0.5, 0.42, 0.0), (1, 1.00, 0.0), (2, 0.55, 0.0),
                  (3, 0.34, 0.0), (4, 0.22, 0.0), (6, 0.10, 0.0))) / 2.7
    y = y + 0.30 * np.sin(6.0 * ph) * np.exp(-t / 0.020)
    return lp(y, 3400.0, order=2) * env(t, dur, atk=0.004, rel=0.10)


def octave_stack(f, dur, f0=None):
    """Three saws an exact octave apart. Not a detune -- an octave is a 2:1 ratio
    and two exact octaves cannot beat against one another. The honest way to get
    the size that detuning is usually used to fake, and the widest voice here:
    every harmonic on one side, only the odd ones on the other."""
    n, t, ph = phase(f, dur, f0)
    e = env(t, dur)
    a = (0.55 * harm(0.5 * ph, SAW) + 1.00 * harm(ph, SAW)
         + 0.30 * harm(2.0 * ph, SAW)) / 4.2
    b = (0.55 * harm(0.5 * ph, ODD) + 1.00 * harm(ph, ODD)
         + 0.30 * harm(2.0 * ph, ODD)) / 3.6
    return np.vstack([sweep(a, t, dur, cuts=(460.0, 1050.0, 2300.0, 4600.0)) * e,
                      sweep(b, t, dur, cuts=(560.0, 1250.0, 2700.0, 5200.0),
                            speed=0.28) * e])


def squelch(f, dur, f0=None):
    """A lowpass with the resonance up, sweeping. One filter doing all of the
    work, which is the whole architecture of the most famous bassline machine
    ever built. It moves like something reacting rather than something played."""
    n, t, ph = phase(f, dur, f0)
    y = sweep(harm(ph, SAW) / 2.3, t, dur, cuts=(380.0, 900.0, 2000.0, 4200.0),
              speed=0.30, tilt=0.55, res=1.7)
    return np.tanh(y * 1.6) / np.tanh(1.6) * env(t, dur, atk=0.02)


def sub_drive(f, dur, f0=None):
    """An octave DOWN, driven hard and crushed. The same tune played by something
    whose weight is much lower -- the one voice that changes the balance of a
    piece rather than just its colour."""
    n, t, ph = phase(f, dur, f0)
    bits, decim, kf, drive = GRIT
    y = harm(0.5 * ph, SAW) / 2.3 + 0.5 * np.sin(ph)
    y = np.tanh(y * 2.6) / np.tanh(2.6)
    y = quant(fold(y, 1.7), bits, decim, GRIT_CUT)
    return sweep(y, t, dur, cuts=(300.0, 700.0, 1600.0, 3400.0)) * env(t, dur)


def wavefold(f, dur, f0=None):
    """A sine folded back on itself, harder as the note gets louder. West coast
    synthesis: the timbre is a function of the amplitude, so the note changes
    colour as it settles rather than because a filter told it to."""
    n, t, ph = phase(f, dur, f0)
    e = env(t, dur, atk=0.09)
    y = fold(np.sin(ph) * (0.55 + 0.45 * e), 1.0 + 2.6 * e) + 0.25 * np.sin(0.5 * ph)
    return lp(y, 5600.0, order=2) * e


def four_bit(f, dur, f0=None):
    """Four bits and an eighth of the sample rate. No filter, no sweep, nothing
    smooth anywhere -- the hardware end of retro rather than the nostalgic end.
    The brightest voice here by a factor of two and the one most at risk over a
    long loop, which is exactly why it was tested on one."""
    n, t, ph = phase(f, dur, f0)
    y = np.sign(np.sin(ph)) * 0.8 + 0.25 * np.sign(np.sin(1.5 * ph))
    return quant(y, 4, 8, 8000.0) * env(t, dur, atk=0.004, rel=0.08)


VOICES = {
    "warm": warm,
    "drawbar": drawbar,
    "octave_stack": octave_stack,
    "squelch": squelch,
    "sub_drive": sub_drive,
    "wavefold": wavefold,
    "four_bit": four_bit,
}
