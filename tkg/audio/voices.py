"""Eighteen lead voices: the seven Jon kept out of twenty auditioned, ten more
written when the seven turned out to be seven shades of one instrument, and a
piano, which he asked for by name and which nothing here had.

THE SEVEN ARE ALL THE SAME KIND OF THING. Every one is a set of exact partials
held flat for the length of the note, which is what an organ pipe is -- so they
could differ in colour and never in what was playing them. Jon, on First Light
through the warmest of them: "it still sounds like a funeral procession organ."
The ten below have ONSETS: struck, plucked, blown, bowed. See "the ten".

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

from synth import SR, bp, hp, lp

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


# ------------------------------------------------------------------- the ten
#
# JON: "it still sounds like a funeral procession organ." All seven above are
# SUSTAINED HARMONIC STACKS -- a set of exact partials held flat for the length
# of the note -- and that is the definition of an organ pipe, so the seven could
# only ever differ in colour, never in what kind of thing was playing. Six of the
# ten below are STRUCK or PLUCKED and three are BLOWN or BOWED; the note has an
# onset and a life, which is the thing no filter setting on a held stack can buy.
#
# The sustain-not-decay rule above still holds where it was aimed -- a slow tune
# made of short struck events is a row of dots rather than a line -- so nothing
# here decays inside the first second of a long note. First Light holds notes for
# up to 6.7 seconds; a marimba's 0.4 s ring under one of those is a rest with a
# click at the front of it, and the rings here are scaled to the note they are
# in rather than fixed.
#
# DETERMINISTIC NOISE. Four of these want noise -- a bow's rosin, a flute's
# chiff, a plucked string's excitation. They seed off the note's own frequency
# rather than the global RNG, so the same note is the same sound in every render
# and a re-run of the album is byte-identical.


def _noise(f, n):
    """The same hiss every time this note is played."""
    return np.random.RandomState(int(f * 100.0) % 2147483647).standard_normal(n)


def _hit(t, dur, ring, atk=0.004, hold=0.0):
    """A struck envelope that is scaled to the note it is in.

    `ring` is the decay in seconds at a 1-second note and grows with the square
    root of the length -- so a 4-second note rings about twice as long rather
    than the same 0.4 s with three and a half seconds of silence behind it. The
    tail is still cut to the note, or one long ring would run into the next.
    """
    k = ring * max(dur, 0.25) ** 0.5
    e = np.clip(t / atk, 0, 1) * np.exp(-np.clip(t - hold, 0, None) / k)
    return e * np.clip((dur - t) / min(0.12, dur * 0.25), 0, 1)


def glass(f, dur, f0=None):
    """FM, at a ratio that is not a whole number, so the partials it makes do not
    land on the harmonic series. That is the whole of a bell: inharmonic metal
    with a bright strike that leaves before the body does."""
    n, t, ph = phase(f, dur, f0)
    e = _hit(t, dur, 1.5, atk=0.002)
    idx = 5.2 * np.exp(-t / (0.22 * max(dur, 0.4) ** 0.5))
    y = np.sin(ph + idx * np.sin(1.4142 * ph)) * e
    y = y + 0.22 * np.sin(2.76 * ph) * _hit(t, dur, 0.55, atk=0.001)
    return lp(y, 7000.0, order=2)


def pluck(f, dur, f0=None):
    """A real string, by the oldest trick there is: fill a delay one period long
    with noise and feed it back through a loss. The noise becomes a pitch because
    only the frequencies that fit the delay survive, and the high partials die
    first because the loss is a filter -- which is exactly what a string does."""
    n, t, ph = phase(f, dur, f0)
    d = max(int(round(SR / f)), 4)
    x = np.zeros(n)
    x[:d] = _noise(f, d) * np.hanning(d) ** 0.4
    # The feedback IS the string. Longer notes need a slower loss or they die
    # inside the beat; the cap keeps it short of ringing forever.
    g = min(0.9996 - 0.30 / (f * max(dur, 0.5)), 0.99985)
    a = np.zeros(d + 2)
    a[0], a[d], a[d + 1] = 1.0, -g * 0.5, -g * 0.5
    y = signal.lfilter([1.0], a, x)
    return y * np.clip((dur - t) / min(0.20, dur * 0.3), 0, 1)


def breath(f, dur, f0=None):
    """A flute: a nearly pure tone with air around it, and the air arrives FIRST.
    The chiff before the pitch is most of what tells an ear that somebody blew
    this rather than that a circuit was switched on."""
    n, t, ph = phase(f, dur, f0)
    e = np.clip(t / 0.06, 0, 1) ** 0.8
    e = e * np.clip((dur - t) / min(0.18, dur * 0.3), 0, 1)
    air = bp(_noise(f, n), f * 0.8, f * 2.6, order=2)
    chiff = np.exp(-t / 0.055) * 0.85
    y = (np.sin(ph) + 0.16 * np.sin(2.0 * ph) + 0.05 * np.sin(3.0 * ph)) * e
    return y + air * (0.16 * e + chiff) * 0.9


def reed(f, dur, f0=None):
    """A pulse whose width narrows across the note. A square is hollow and a
    narrow pulse is nasal, so the note starts woody and grows a reed as it goes
    -- one parameter, and no filter anywhere."""
    n, t, ph = phase(f, dur, f0)
    e = env(t, dur, atk=0.035, rel=0.20)
    duty = 0.50 - 0.34 * np.clip(t / max(dur * 0.45, 0.12), 0, 1)
    y = np.where((ph / (2.0 * np.pi)) % 1.0 < duty, 1.0, -1.0)
    y = lp(y, 4200.0, order=2) - lp(y, 120.0, order=1)
    return y * e


def marimba(f, dur, f0=None):
    """Struck wood. A marimba's bar is carved until its first overtone is two
    octaves above the fundamental, which is why it reads as WOOD and not as a
    bell -- the 4:1 is the whole signature, and the knock of the mallet under it
    is the other half."""
    n, t, ph = phase(f, dur, f0)
    y = (np.sin(ph) * _hit(t, dur, 1.1)
         + 0.42 * np.sin(4.0 * ph) * _hit(t, dur, 0.30, atk=0.001)
         + 0.16 * np.sin(9.2 * ph) * _hit(t, dur, 0.12, atk=0.001))
    knock = lp(_noise(f + 1.0, n), 1800.0, order=2) * np.exp(-t / 0.012) * 0.5
    return y + knock


def formant(f, dur, f0=None):
    """A saw through three resonances, moving from an open vowel to a closed one.
    Formants are what make a sound read as a MOUTH, and a mouth is the one
    timbre nobody mistakes for a pipe organ."""
    n, t, ph = phase(f, dur, f0)
    src = harm(ph, SAW) / 2.3
    e = env(t, dur, atk=0.08, rel=0.30)
    r = np.clip(t / max(dur * 0.6, 0.2), 0, 1)
    y = np.zeros(n)
    # ah (730, 1090, 2440) travelling to oo (300, 870, 2240). Crossfaded pairs
    # rather than a moving filter, the same trick `sweep` uses and for the same
    # reason: partials that stay in phase, and no Python loop per note.
    for (lo, hi, amp) in ((730.0, 300.0, 1.00), (1090.0, 870.0, 0.55),
                          (2440.0, 2240.0, 0.22)):
        a = bp(src, lo * 0.86, lo * 1.16, order=2)
        b = bp(src, hi * 0.86, hi * 1.16, order=2)
        y += amp * (a * (1.0 - r) + b * r)
    return y * e


def tine(f, dur, f0=None):
    """An electric piano: a metal tine under a pickup. FM at a high whole-number
    ratio makes the bark of the hammer, the sine under it is the tine itself, and
    the bark is gone in a tenth of a second while the tine rings on."""
    n, t, ph = phase(f, dur, f0)
    bark = 3.4 * np.exp(-t / 0.055)
    y = np.sin(ph + bark * np.sin(14.0 * ph)) * _hit(t, dur, 1.35, atk=0.003)
    y += 0.30 * np.sin(2.0 * ph) * _hit(t, dur, 0.70, atk=0.002)
    return lp(y, 6500.0, order=2)


def bowed(f, dur, f0=None):
    """Sustained, like the seven -- and not an organ, because a bow SCRAPES. The
    rosin noise at the start and the swell into the note are the two things a
    pipe cannot do: a pipe speaks at full pressure and holds there."""
    n, t, ph = phase(f, dur, f0)
    e = np.clip(t / min(0.22, max(dur * 0.30, 0.06)), 0, 1) ** 1.3
    e = e * (0.88 + 0.12 * np.clip(t / 1.2, 0, 1))
    e = e * np.clip((dur - t) / min(0.28, dur * 0.35), 0, 1) ** 1.2
    body = harm(ph, SAW) / 2.3
    body = bp(body, f * 0.5, 3600.0, order=2) + 0.35 * lp(body, 900.0, order=2)
    rosin = bp(_noise(f + 2.0, n), 1400.0, 5200.0, order=2)
    rosin = rosin * (np.exp(-t / 0.10) * 0.55 + 0.05)
    return (body + rosin) * e


def music_box(f, dur, f0=None):
    """A comb tine plucked by a pin: tiny, bright, and gone. Almost no
    fundamental -- the bar is too short to carry one -- so the pitch is heard in
    the partials, which is why a music box sounds an octave higher than it is."""
    n, t, ph = phase(f, dur, f0)
    y = (0.35 * np.sin(ph) * _hit(t, dur, 0.55)
         + 1.00 * np.sin(2.0 * ph) * _hit(t, dur, 0.40, atk=0.001)
         + 0.55 * np.sin(3.93 * ph) * _hit(t, dur, 0.22, atk=0.001)
         + 0.28 * np.sin(9.5 * ph) * _hit(t, dur, 0.09, atk=0.001)
         + 0.12 * np.sin(16.4 * ph) * _hit(t, dur, 0.05, atk=0.001))
    pin = hp(_noise(f + 3.0, n), 3000.0, order=2) * np.exp(-t / 0.006) * 0.30
    return y + pin


def shimmer(f, dur, f0=None):
    """The note, and the note an octave up arriving a moment later on the other
    side. Two channels carrying different things at an exact 2:1 -- the widest
    voice in either list, and the only one whose colour changes because of where
    it is rather than what it is."""
    n, t, ph = phase(f, dur, f0)
    e = env(t, dur, atk=0.10, rel=0.40)
    low = (np.sin(ph) + 0.30 * np.sin(2.0 * ph) + 0.10 * np.sin(3.0 * ph)) * e
    up = np.sin(2.0 * ph) + 0.35 * np.sin(4.0 * ph)
    # The octave fades IN, so the note opens plain and blooms. A shimmer that is
    # there from the first sample is just a brighter note.
    bloom = np.clip((t - 0.12) / max(dur * 0.55, 0.3), 0, 1) ** 1.4
    up = up * e * bloom * 0.45
    d = int(0.021 * SR)
    l = low + np.concatenate([np.zeros(d), up[:-d]]) if n > d else low + up
    r = low * 0.85 + up
    return np.vstack([lp(l, 5200.0, order=2), lp(r, 6400.0, order=2)])



def piano(f, dur, f0=None):
    """A struck steel string. The one voice here that is a real instrument
    rather than a synthesizer setting.

    INHARMONICITY IS THE WHOLE THING. A stiff string's nth partial sits at
    n*f*sqrt(1 + B*n^2) rather than at n*f -- sharp, and further sharp the
    higher it goes -- which is why a piano's top octave is TUNED sharp to match
    and why a perfectly harmonic stack does not sound like one. B is small; at
    0.0004 the twelfth partial lands about a tenth of a semitone high, which is
    inaudible as pitch and audible as wood.

    The partials also die at different rates, fast ones first. That is a real
    string losing its high frequencies to the bridge, and it is what makes the
    note change colour as it rings instead of just getting quieter.
    """
    n, t, ph = phase(f, dur, f0)
    B = 0.0004
    y = np.zeros(n)
    for k in range(1, 13):
        stretch = (1.0 + B * k * k) ** 0.5
        amp = 1.0 / (k ** 1.35)
        ring = 1.55 / (1.0 + 0.40 * (k - 1))
        y += amp * np.sin(k * stretch * ph) * _hit(t, dur, ring, atk=0.002)
    # The hammer, and the thud of the key bed under it. Both are noise, and
    # both are gone before the first partial has decayed at all.
    ham = lp(_noise(f, n), 3800.0, order=2) * np.exp(-t / 0.007) * 0.40
    ham += lp(_noise(f + 5.0, n), 260.0, order=2) * np.exp(-t / 0.020) * 0.25
    return lp(y / 3.1 + ham, 9500.0, order=2)


VOICES = {
    "warm": warm,
    "drawbar": drawbar,
    "octave_stack": octave_stack,
    "squelch": squelch,
    "sub_drive": sub_drive,
    "wavefold": wavefold,
    "four_bit": four_bit,
    "glass": glass,
    "pluck": pluck,
    "breath": breath,
    "reed": reed,
    "marimba": marimba,
    "formant": formant,
    "tine": tine,
    "bowed": bowed,
    "music_box": music_box,
    "shimmer": shimmer,
    "piano": piano,
}
