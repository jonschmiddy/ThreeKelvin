"""Recorded instruments behind the same doors the oscillators use.

`synth.py`'s instruments are all one shape: `f, dur, amp -> mono float array`.
Nothing in the eight scores knows what happens behind that, which is the whole
reason this file can exist -- a sampled `whistle()` is a drop-in for the
synthesised one, so the scores are untouched, the stems are still stems, and
`master()`'s sample-exact sum still holds.

    import synth; synth.use_samples()      # BEFORE `from synth import *`
    -- or --
    TK_VOICES=sampled python3 arrange.py

Samples come from two CC0 libraries fetched by `fetch_samples.py`.  They are
build inputs: the game loads rendered stems and never sees a .wav from either.

Why only some instruments
-------------------------
The bass, the drone, the blade and the FX stay synthesised, and that is a
choice rather than unfinished work.  `sub()` is a sine with a controlled
second harmonic that sits under a mix without fighting it; a recorded
contrabass in the same slot is mud plus room. `drone()` and `blade()` are not
imitating anything, so there is nothing to sample.  What samples buy is the
part synthesis is worst at -- the attack transient and the small per-note
irregularity of a played instrument -- which is exactly the melodic material.

The register split
------------------
`arrange.py` plays the whistle stem at F6 and the lead stem at F5 through the
SAME function.  One sampled instrument cannot cover both: 1397 Hz is a piccolo
and 698 Hz is a flute, and stretching either across both octaves is audibly a
stretched sample.  `Layered` picks by frequency, which is what an orchestrator
does with the same two notes.

Tuning
------
Sources are chosen by nearest available pitch and then resampled by the exact
ratio `f_target / f_source`, not by semitones.  The scores call `hz('Ab3')`,
so every note is equal-tempered and the ratio set is small and cached -- but
doing it by ratio rather than by rounded semitone means a score that ever asks
for a bent or microtonal pitch gets it for free, and `dread.py`'s
`whistle_bend` does exactly that.
"""
import os, re, sys
from fractions import Fraction

import numpy as np
import soundfile as sf
from scipy import signal
from scipy import signal as sp_signal

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, 'samples')

VSCO = os.path.join(ROOT, 'vsco2')
VCSL = os.path.join(ROOT, 'vcsl')

_SEMI = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
_NOTE = re.compile(r'^([A-Ga-g])([#b]?)(-?\d)$')
_VEL = re.compile(r'^vl?(\d+)$', re.I)
# Dynamic markings used as filenames where there is no vN.  Ranked, not
# measured -- the actual level is normalised out below, so these only decide
# which layer an `amp` selects.
_DYN = {'ppp': 0, 'pp': 1, 'p': 2, 'mp': 3, 'mf': 4, 'f': 5, 'ff': 6, 'fff': 7}


def _midi(tok):
    """'C#5' -> 61.  None if the token is not a note name."""
    m = _NOTE.match(tok)
    if not m:
        return None
    letter, acc, octv = m.groups()
    letter = letter.upper()
    n = _SEMI[letter] + (1 if acc == '#' else -1 if acc == 'b' else 0)
    return 12 * (int(octv) + 1) + n


def _hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


# ---------------- sample loading ----------------

_wav_cache = {}


def _load(path):
    """Mono float64 at SR, leading silence trimmed.

    The trim matters more than it looks.  Scores place notes on the beat, and
    VSCO's sustains carry 10-60 ms of room before the attack -- inaudible on
    one note and a soggy, uneven groove across a bar of sixteenths.  Trimming
    to the first sample over -60 dBFS puts every attack on the grid.
    """
    if path in _wav_cache:
        return _wav_cache[path]
    x, sr = sf.read(path, dtype='float64', always_2d=True)
    x = x.mean(axis=1)
    if sr != SR:
        g = np.gcd(int(sr), SR)
        x = signal.resample_poly(x, SR // g, int(sr) // g)
    loud = np.abs(x) > 10 ** (-60 / 20.0)
    if loud.any():
        x = x[max(0, np.argmax(loud) - 32):]
    _wav_cache[path] = x
    return x


VCSL_SFZ = os.path.join(ROOT, 'vcsl-sfz')

_sfz_map = None


def sfz_pitch():
    """{absolute wav path: sounding midi, as a float} from VCSL's own .sfz.

    A filename is a name.  The SFZ is the library's statement of what the
    recording actually SOUNDS, as `pitch_keycenter` plus a `tune` in cents,
    and where the two disagree the SFZ is right.

    The wine glasses are the case that proved it, and they proved it against
    me rather than against VCSL.  Their files are called glass1_D#4 ... and
    the SFZ maps that one to key 75 with tune=-28 -- D#5, 28 cents sharp.  An
    independent FFT of the recording puts it at 632.93 Hz, which is D#5 plus
    29 cents.  All four agree within 3 cents.  Nothing is mislabelled; this
    loader was reading the half of the library that is decoration and
    ignoring the half that is data.

    Only VCSL ships these.  VSCO-2 CE has no SFZ in its repository, so those
    patches still key off the filename -- which for them has been correct.
    """
    global _sfz_map
    if _sfz_map is not None:
        return _sfz_map
    _sfz_map = {}
    if not os.path.isdir(VCSL_SFZ):
        return _sfz_map
    for d, _, files in os.walk(VCSL_SFZ):
        for fn in files:
            if not fn.lower().endswith('.sfz'):
                continue
            base = d
            key = tune = None
            samp = None
            for raw in open(os.path.join(d, fn), errors='ignore'):
                line = raw.split('//')[0].strip()
                if line.startswith('<'):
                    if samp and key is not None:      # flush the previous one
                        _stash(_sfz_map, base, samp, key, tune)
                    samp, key, tune = None, None, None
                    continue
                for tok in line.split():
                    if '=' not in tok:
                        continue
                    k, v = tok.split('=', 1)
                    if k == 'sample':
                        samp = line.split('sample=', 1)[1].strip()
                    elif k == 'pitch_keycenter':
                        key = float(v)
                    elif k == 'tune':
                        tune = float(v)
            if samp and key is not None:
                _stash(_sfz_map, base, samp, key, tune)
    return _sfz_map


def _stash(m, base, samp, key, tune):
    """File the region under the WAV it names, in the samples tree."""
    rel = samp.replace('\\', '/')
    p = os.path.normpath(os.path.join(base, rel))
    p = p.replace(VCSL_SFZ, VCSL)
    # `tune` is the correction the player applies, so the recording sounds
    # that many cents the OTHER way from its key centre.
    m[p] = key - (tune or 0.0) / 100.0


def detect_hz(path, lo=110.0, hi=3000.0):
    """The frequency a sample actually SOUNDS, not the one in its filename.

    A cross-check, not the mechanism.  `sfz_pitch()` is the mechanism, and
    this is what caught the problem it solves and then confirmed the answer:
    VCSL's wine glasses sound an octave above their filenames and are out by
    +29, -10, +56 and +4 cents on top, and the SFZ says exactly that to
    within 3 cents.

    Useful for auditing a new library before trusting it, and useless as a
    blanket test -- on a harmonic instrument the strongest partial is often
    not the fundamental, and this reported the cello and the piano as wildly
    mistuned when the real problem was its own 110 Hz floor sitting above a
    cello's bottom string.

    Strongest partial in the steady state, parabolically interpolated,
    measured from a third of the way in so it is past any attack.
    """
    x = _load(path)
    i = int(0.3 * len(x))
    seg = x[i:i + int(3.0 * SR)]
    if len(seg) < 4096:
        seg = x[:4096] if len(x) >= 4096 else np.pad(x, (0, 4096 - len(x)))
    S = np.abs(np.fft.rfft(seg * np.hanning(len(seg))))
    df = SR / len(seg)
    a, b = int(lo / df), min(len(S) - 2, int(hi / df))
    k = a + int(np.argmax(S[a:b]))
    l, c, r = (np.log(S[k + d] + 1e-12) for d in (-1, 0, 1))
    return (k + 0.5 * (l - r) / (l - 2 * c + r + 1e-12)) * df


_onset_cache = {}


def trim_onset(x, frac, fade_ms=60.0):
    """Start a slow-swelling sample where it has actually arrived.

    A rubbed wine glass takes 2.2 seconds to reach half its peak.
    `_fit_sustain` takes the FIRST n samples of a recording, so a short note
    played only the swell-in and a long one reached the steady state -- a
    0.3 s note came out at 30% of the level of a held one, and a 0.6 s note
    at 52%.  Ten decibels of difference decided by nothing but note length,
    which is why the held tones sounded loud and everything shorter sounded
    like it was missing.

    So the usable sample starts where it first reaches `frac` of its own
    peak, with a short fade in so the new start cannot click.  The
    instrument still has no attack -- it is a glass, there is nothing to
    strike -- it just no longer has two seconds of nothing in front of it.
    """
    key = (id(x), frac, fade_ms)
    hit = _onset_cache.get(key)
    if hit is not None and len(hit) and hit is not x:
        return hit
    pk = float(np.max(np.abs(x))) if len(x) else 0.0
    if pk <= 0:
        return x
    idx = int(np.argmax(np.abs(x) >= frac * pk))
    if idx <= 0:
        return x
    y = x[idx:].copy()
    n = min(len(y) // 4, int(fade_ms * SR / 1000.0))
    if n > 1:
        y[:n] *= 0.5 * (1 - np.cos(np.linspace(0, np.pi, n)))
    _onset_cache[key] = y
    return y


class Patch:
    """One recorded instrument, keyed by pitch and velocity layer.

    Filenames across these two libraries agree on nothing except that the
    pitch, the velocity layer and the round-robin index are each their own
    `_`-delimited field: `LDFlute_susvib_A3_v1_1`, `VlnEns_susVib_A2_v1`,
    `piccolo_C5_sustain1`, `EWHarp_Normal_G#4_v3_RR1`.  So rather than a
    pattern per instrument, every field is tested against the three token
    shapes and whatever matches wins.  A field only looks like a note if it
    matches a note name WHOLE -- 'Snare2' and 'sustain1' do not.
    """

    def __init__(self, path, include=(), exclude=('rel',), decay=False,
                 gain=1.0, tune=0.0, amp_ref=0.5, loop=(0.55, 0.95),
                 detect=False, onset=0.0, lowpass=None):
        self.decay = decay          # True: let it ring, damp to the note length
        self.gain = gain            # per-patch trim, after normalisation
        self.tune = tune            # semitones, for a mis-labelled library
        self.amp_ref = amp_ref      # the `amp` that selects the top layer
        self.loop = loop            # fraction of the sample used as loop region
        self.onset = onset          # start at this fraction of the peak
        self.lowpass = lowpass      # Hz: strip a noisy library's hiss
        self.notes = {}             # midi -> [(vel_rank, [paths])]
        self._rr = {}
        self.truef = {}             # path -> measured Hz, when detect=True
        self._scan(path, include, exclude)
        if detect:
            self._redetect()
        if not self.notes:
            raise SystemExit('no samples under %s -- run fetch_samples.py' % path)
        self.keys = np.array(sorted(self.notes))
        self._norm = self._measure()

    def _scan(self, path, include, exclude):
        bag = {}
        for d, _, files in os.walk(path):
            for f in files:
                if not f.lower().endswith('.wav'):
                    continue
                toks = re.split(r'[_\-. ]+', f[:-4])
                low = [t.lower() for t in toks]
                if any(x.lower() not in low for x in include):
                    continue
                if any(x.lower() in low for x in exclude):
                    continue
                midi = vel = None
                for t in toks:
                    if midi is None and _midi(t) is not None:
                        midi = _midi(t)
                    elif _VEL.match(t):
                        vel = int(_VEL.match(t).group(1))
                    elif t.lower() in _DYN and vel is None:
                        vel = _DYN[t.lower()]
                full = os.path.join(d, f)
                true = sfz_pitch().get(os.path.normpath(full))
                if true is not None:
                    midi = true                      # the library's own word
                elif midi is None:
                    continue
                bag.setdefault(midi, {}).setdefault(vel or 0, []) \
                   .append(full)
        for midi, layers in bag.items():
            self.notes[float(midi)] = [(v, sorted(layers[v]))
                                       for v in sorted(layers)]

    def _redetect(self):
        """Re-key the patch on what the samples sound rather than what they
        are called.  Only for libraries known to be mislabelled -- see
        `detect_hz`.  Everything is re-filed under its measured pitch, so
        nearest-note selection picks the right sample as well as playing it
        at the right speed."""
        out = {}
        for midi, layers in self.notes.items():
            for vel, paths in layers:
                for p in paths:
                    f = detect_hz(p)
                    self.truef[p] = f
                    m = int(round(69 + 12 * np.log2(f / 440.0)))
                    out.setdefault(m, {}).setdefault(vel, []).append(p)
        self.notes = {m: [(v, sorted(ps)) for v, ps in sorted(d.items())]
                      for m, d in out.items()}

    def _measure(self):
        """A gain PER NOTE, so `amp` keeps meaning what it did everywhere.

        Sample libraries are recorded at whatever level the session ran at,
        and the oscillators are all built to peak near 1.0, so some
        normalisation is obviously needed.  What is not obvious is that one
        number for the whole patch is not enough.  VSCO's harp, peak per note
        across its 23 samples:

            E1 0.022   G1 0.003   B1 0.008   ...   A4 0.123   ...   F7 0.139

        which is a 33 dB spread, non-monotonic, and nothing a harp does -- it
        is session drift.  Normalising the patch by its median put the theme's
        arp stem within 0.7 dB and the combat cue's, which plays the same
        instrument an octave higher, 9.0 dB hot.  One constant cannot answer a
        curve.

        So every note is scaled to its own reference and the keyboard comes
        out flat.  The reference is the note's TOP velocity layer, which
        leaves the layers' relative levels intact -- the inconsistency being
        corrected is between notes, and the dynamics within a note are real.

        Peak for a struck or plucked patch, RMS for a sustained one: what the
        ear takes as the loudness of a plucked note is its attack, and what it
        takes as the loudness of a bowed one is its body.
        """
        out = {}
        for midi, layers in self.notes.items():
            x = _load(layers[-1][1][0])
            if self.onset:
                x = trim_onset(x, self.onset)
            lvl = (np.max(np.abs(x)) if self.decay
                   else np.sqrt(np.mean(x ** 2)))
            out[midi] = 1.0 / max(1e-6, float(lvl))
        return out

    def _source(self, f, vel):
        """Nearest recorded pitch, and the layer this VELOCITY asks for.

        Velocity is not gain and must not be derived from it.  `_voiced()`
        hands each voice of a chord `amp / len(freqs)`, and when that number
        also chose the velocity layer, adding voices to a chord quietly moved
        every one of them onto a softer, differently-recorded sample -- so a
        two-note chord came out **12 dB louder than a four-note chord** at the
        same written amp, and a score got quieter by adding notes.  The gain
        still divides; the velocity does not.
        """
        want = 69 + 12 * np.log2(max(1e-6, f) / 440.0) - self.tune
        midi = float(self.keys[np.argmin(np.abs(self.keys - want))])
        layers = self.notes[midi]
        i = int(round((len(layers) - 1) * min(1.0, vel / self.amp_ref)))
        _, paths = layers[i]
        k = (midi, i)
        j = self._rr.get(k, 0)
        self._rr[k] = j + 1                     # deterministic round robin --
        return paths[j % len(paths)], midi      # never touches np.random

    def note(self, f, dur, amp=1.0, cents=0.0, vel=None):
        n = max(1, int(dur * SR))
        path, midi = self._source(f, amp if vel is None else vel)
        src = self.truef.get(path) or _hz(midi + self.tune)
        x = _resample(path, f / src)
        if self.onset:
            x = trim_onset(x, self.onset)
        if cents:
            x = _bend(x, n, cents)
        y = _fit_decay(x, n) if self.decay else _fit_sustain(x, n, self.loop)
        if self.lowpass:
            b, a = sp_signal.butter(6, self.lowpass/(SR/2), 'low')
            y = sp_signal.lfilter(b, a, y)
        return y * (amp * self.gain * self._norm[midi])

    def chord(self, freqs, dur, amp=1.0):
        n = max(1, int(dur * SR))
        y = np.zeros(n)
        for f in freqs:
            v = self.note(f, dur, amp / len(freqs), vel=amp)
            y[:len(v)] += v[:n]
        return y


class Layered:
    """Two patches over one keyboard, split at a frequency.

    `Patch.note` already resamples any distance, so this is not about
    coverage.  It is about not asking one recording to be two instruments:
    piccolo pulled down an octave sounds like a slowed tape, and flute pushed
    up one sounds like a whistle in the worst sense.
    """

    def __init__(self, low, high, split):
        self.low, self.high, self.split = low, high, split

    def note(self, f, dur, amp=1.0, cents=0.0, vel=None):
        p = self.high if f >= self.split else self.low
        return p.note(f, dur, amp, cents, vel)

    def chord(self, freqs, dur, amp=1.0):
        n = max(1, int(dur * SR))
        y = np.zeros(n)
        for f in freqs:
            v = self.note(f, dur, amp / len(freqs), vel=amp)
            y[:len(v)] += v[:n]
        return y


class Kit:
    """An unpitched patch -- one hit, chosen by `amp`, cycled round-robin."""

    def __init__(self, path, include=(), exclude=('rel',), gain=1.0,
                 amp_ref=0.8):
        self.gain, self.amp_ref, self._i = gain, amp_ref, 0
        self.layers = []
        bag = {}
        for d, _, files in os.walk(path):
            for f in files:
                if not f.lower().endswith('.wav'):
                    continue
                toks = [t.lower() for t in re.split(r'[_\-. ]+', f[:-4])]
                if any(x.lower() not in toks for x in include):
                    continue
                if any(x.lower() in toks for x in exclude):
                    continue
                v = 0
                for t in toks:
                    if _VEL.match(t):
                        v = int(_VEL.match(t).group(1))
                    elif t in _DYN:
                        v = _DYN[t]
                bag.setdefault(v, []).append(os.path.join(d, f))
        if not bag:
            raise SystemExit('no samples under %s -- run fetch_samples.py' % path)
        self.layers = [sorted(bag[v]) for v in sorted(bag)]
        peaks = [np.max(np.abs(_load(p))) for ps in self.layers for p in ps[:1]]
        self._norm = 1.0 / max(1e-6, float(np.median(peaks)))

    def hit(self, amp=1.0, dur=None):
        i = int(round((len(self.layers) - 1) * min(1.0, amp / self.amp_ref)))
        ps = self.layers[i]
        x = _load(ps[self._i % len(ps)])
        self._i += 1
        if dur is not None:
            x = _fit_decay(x, max(1, int(dur * SR)))
        return x * (amp * self.gain * self._norm)


# ---------------- pitch and length ----------------

_rs_cache = {}


def _resample(path, ratio):
    """Play `path` back at `ratio` times its recorded speed.

    `resample_poly` rather than interpolation because pitching a sample UP
    folds everything above Nyquist/ratio back down as aliasing, and a
    glockenspiel has plenty up there to fold.  The rational approximation is
    capped at a denominator of 500, which is 3.5 cents of error worst case and
    inaudible; letting it run exact produces filter kernels with tens of
    thousands of taps and turned a 40-second render into minutes.

    Cached on the quantised ratio.  Every score note comes from `hz()` on a
    note name, so a cue asks for a few dozen distinct ratios and then asks for
    them again several hundred times each.
    """
    key = (path, round(ratio, 4))
    if key in _rs_cache:
        return _rs_cache[key]
    x = _load(path)
    if abs(ratio - 1.0) < 1e-4:
        y = x
    else:
        fr = Fraction(1.0 / ratio).limit_denominator(500)
        y = signal.resample_poly(x, fr.numerator, fr.denominator)
    _rs_cache[key] = y
    return y


def _bend(x, n, cents):
    """Slide the playback rate linearly across the note.

    `whistle_bend` exists because the dread and combat cues want a whistle
    that sags -- `burn.py` plays the motif 20 cents flat and falling.  A fixed
    ratio cannot do that, so the read head walks a cumulative index instead of
    a straight one, which is the same trick as varispeed tape.

    Only the first `n` samples are bent.  The bend is defined against the note
    length, so past the note there is nothing left to define it, and a sustain
    that loops afterwards should loop at the pitch it ended on.
    """
    m = min(n, len(x))
    t = np.arange(m) / max(1, n)
    idx = np.cumsum(2 ** ((cents * t) / 1200.0))
    idx = idx[idx < len(x) - 1]
    y = np.interp(idx, np.arange(len(x)), x)
    return np.concatenate([y, x[len(y):]]) if len(y) < len(x) else y


def _fade(x, n):
    """Release fade, in place on a copy. Cosine, so it cannot click."""
    n = min(n, len(x))
    if n > 1:
        x = x.copy()
        x[-n:] *= 0.5 * (1 + np.cos(np.linspace(0, np.pi, n)))
    return x


def _attack(x, n):
    """A fade-in proportional to the note, capped.

    A bowed or blown player articulates a short note faster than a long one
    but still articulates it; a sample sliced out of a steady state has no
    attack at all, so short notes arrived at full level instantly and read
    as louder than long ones -- +4.7 dB at 0.3 s against the oscillator the
    scores were written for.  A third of the note, up to 100 ms.
    """
    k = min(len(x), int(0.48 * n), int(0.13 * SR))
    if k > 1:
        x = x.copy()
        x[:k] *= 0.5 * (1 - np.cos(np.linspace(0, np.pi, k)))
    return x


def _fit_decay(x, n):
    """A struck or plucked note: keep the natural decay, damp it to length.

    The scores use `dur` on `bell()` and `pluck()` as a ring length, not as a
    gate -- `bell(hz(n), d*SPB*1.4, 0.16)` deliberately rings past its beat.
    So a sample shorter than `n` is simply left alone, and a longer one is
    faded over its final third rather than cut.
    """
    if len(x) <= n:
        return x
    return _fade(x[:n], max(1, n // 3))


def _fit_sustain(x, n, loop):
    """A bowed or blown note: hold it for exactly `n` samples.

    Sustains in both libraries run 2-4 seconds and the pad in `arrange.py`
    holds two bars, which at 142 BPM is 3.38 s and at 71 is 6.76 -- so looping
    is not optional.  The loop takes a window out of the steady state (past
    the attack, before the player runs out of bow or breath) and crossfades it
    onto itself, which is the standard trick and is inaudible as long as the
    window is long enough to span several vibrato cycles.  100 ms of crossfade
    at a 5 Hz vibrato is half a cycle, so the window is taken as a FRACTION of
    the sample rather than a fixed length.
    """
    if len(x) >= n:
        return _attack(_fade(x[:n], min(len(x) // 8, int(0.06 * SR))), n)
    a, b = int(len(x) * loop[0]), int(len(x) * loop[1])
    seg = x[a:b]
    xf = min(len(seg) // 4, int(0.10 * SR))
    if len(seg) <= 2 * xf or xf < 8:
        return _fade(np.pad(x, (0, n - len(x))), int(0.06 * SR))
    body = seg[:-xf]
    ramp = np.linspace(0, 1, xf)
    head = seg[-xf:] * (1 - ramp) + seg[:xf] * ramp    # loop point, crossfaded
    y = [x[:a + len(body)]]
    have = len(y[0])
    while have < n:
        y.append(head)
        y.append(body[xf:])
        have += len(head) + len(body) - xf
    y = np.concatenate(y)[:n]
    return _attack(_fade(y, min(len(y) // 8, int(0.06 * SR))), n)


# ---------------- the instrument set ----------------
#
# Which recording plays which door.  Everything absent from this table keeps
# its oscillator: see the module docstring for why that is on purpose.

_P = {}


def _patch(name, *a, **kw):
    if name not in _P:
        _P[name] = (Kit if kw.pop('kit', False) else Patch)(*a, **kw)
    return _P[name]


# Per-patch gain trims.  `Patch._measure` normalises each library to a common
# peak, which gets a patch into the right neighbourhood; these are the last
# few dB, and they are MEASURED rather than guessed.  Method: render `theme`
# both ways and compare per-stem RMS.  With every trim at 1.0 the first pass
# read
#
#     arp +4.2   lead +4.0   pad -5.8   bell -1.4   whistle -1.2 dB
#
# against the synthesised render, while the three stems that kept their
# oscillators (bass, fx, perc) sat within 0.7 dB -- which is also the check
# that nothing else moved.  The trims below are those deltas inverted.  Redo
# the measurement after changing an instrument here; a stem 4 dB hot is not
# wrong on its own, it is wrong against the eight-stem ladder Audio.gd climbs
# at runtime, and that only shows up in the game.
GAIN = {
    'flute':   0.61,        # lead stem
    'piccolo': 0.51,        # whistle stem
    'ocarina': 1.00,        # unmeasured -- no cue plays reed() yet
    'pad':     0.28,        # pad() -- a synthesiser, in the original
    'strings': 0.20,        # strings() -- a section, and NOT the same level:
                            # mapping both doors to one voice with one gain
                            # put the strings stem within 1 dB of the whole
                            # mix in four cues.  Measured per cue against the
                            # synthesised render: business +10.4, home +5.6,
                            # first_light +3.3, shells +3.0 dB.
    'harp':    0.85,        # arp stem, +3 dB over the level that matched
                            # synth.pluck -- asked for, not measured to
    'glock':   1.17,        # bell stem
    'piano':   3.30,        # lead=piano -- a struck note's RMS sits far
                            # below its peak, and GAIN is set from RMS
    'wineglass': 0.63,      # lead=glass, the default.  Set from the lead
                            # stem's level against the mix across five cues,
                            # not from a single note -- a single note cannot
                            # see how often the score holds one.
    'chimes':  2.18,        # lead=chimes
    'organ':   0.42,        # manuals
    'organped': 0.44,       # pedal division
    # -- the texture set: the full cutover.  Calibrated below, each against
    #    its oscillator's RMS at a representative call.
    'cbass':   0.54,        # sub
    'trem':    0.20,        # drone / cluster / bowed-above-C3
    'spic':    0.45,
    'eguitar': 4.50,
    'trumpet': 0.85,        # harmon: amp ~0.35 selects the v3 layer; this trims it to lead at ~-22        # trial lead; calibrated to the glass motif stem's -23.7 dB in burn
    'pizz':    0.80,        # blade: pizz snap over the piano ostinato
    'cymbal':  0.80,        # metal + the swells
    'kcello':  0.18,        # Karoryfer cello sustains
    'kstac':   0.65,        # Karoryfer cello staccato
    'meatbass': 0.30,       # Karoryfer double bass
    'gong':    1.20,        # impact
    'ocean':   1.70,        # air
    'heartbd': 3.30,        # heart's bass-drum strokes
    'vibes':   1.00,        # lead=vibes, and glass()
}


def _flute():
    return _patch('flute', os.path.join(VSCO, 'Woodwinds', 'Flute'),
                  include=('susvib',), amp_ref=0.5, gain=GAIN['flute'])


def _piccolo():
    return _patch('piccolo', os.path.join(VSCO, 'Woodwinds', 'Piccolo'),
                  amp_ref=0.5, gain=GAIN['piccolo'])


def _ocarina():
    return _patch('ocarina', os.path.join(
        VCSL, 'Aerophones', 'Edge-blown Aerophones', 'Ocarina, Typical'),
        amp_ref=0.5, gain=GAIN['ocarina'])


def _piano():
    return _patch('piano', os.path.join(
        VCSL, 'Chordophones', 'Zithers', 'Grand Piano, Kawai'),
        decay=True, amp_ref=0.5, gain=GAIN['piano'])


def _wineglass():
    """Rubbed glass: a glass harmonica, and the least terrestrial thing in
    either library.

    Four pitched samples only -- D#4, F#4, A#4, D5 -- so most notes are
    resampled a tone or two, which for a near-sine tone with no attack is
    inaudible.  They run 15 to 25 seconds each, so nothing loops.

    `Sustains/Slow` rather than the whole folder: the library also ships
    `Fast` (a quicker rub-in) and `Releases`, and the slow swell is the
    entire reason to use this instrument.
    """
    return _patch('wineglass', os.path.join(
        VCSL, 'Idiophones', 'Friction Idiophones', 'Wine Glasses',
        'Sustains', 'Slow'), amp_ref=0.5, gain=GAIN['wineglass'],
        loop=(0.35, 0.9), onset=0.55, lowpass=3800)
    # lowpass=3800: measured mid-sustain, 44% of these recordings' energy sits
    # above 4 kHz and none of it is glass -- it is the room and the preamp.
    # The tone peaks at the fundamental with weak partials well under 3 kHz,
    # so the cut removes the hiss and leaves the instrument.


def _chimes():
    """Struck metal tubes, long inharmonic decay -- shorter tails than the
    tubular bells, and pitched high enough to work as a lead."""
    return _patch('chimes', os.path.join(
        VCSL, 'Idiophones', 'Struck Idiophones', 'Hand Chimes'),
        decay=True, amp_ref=0.5, gain=GAIN['chimes'])


def _organ_man():
    """Pipe Organ, loud manual. midi 24-84, twelve-second samples."""
    return _patch('organ', os.path.join(
        VCSL, 'Aerophones', 'Edge-blown Aerophones', 'Pipe Organ', 'Loud'),
        amp_ref=0.5, gain=GAIN['organ'], loop=(0.4, 0.9))


def _organ_ped():
    """Pipe Organ, pedal division. A separate set of much larger pipes --
    midi 24-54 only, which is exactly the compass a pedal board has."""
    return _patch('organped', os.path.join(
        VCSL, 'Aerophones', 'Edge-blown Aerophones', 'Pipe Organ',
        'Loud Pedal'), amp_ref=0.5, gain=GAIN['organped'], loop=(0.4, 0.9))


def _vibes():
    return _patch('vibes', os.path.join(
        VCSL, 'Idiophones', 'Struck Idiophones', 'Vibraphone'),
        decay=True, amp_ref=0.4, gain=GAIN['vibes'])


def _sect(part, folder, sub, gain=1.0):
    return _patch(part, os.path.join(VSCO, 'Strings', folder),
                  include=(sub,), amp_ref=0.45, loop=(0.45, 0.92), gain=gain)


# ---- the doors ----------------------------------------------------------
# Each takes the signature synth.py uses, and ignores the parameters that
# described an oscillator -- `cutoff`, `damp`, `bright`, `vib` are all shapes
# of a waveform that no longer exists.  Keeping them in the signature is what
# lets the scores stay untouched.

#: What answers `whistle()` -- the melody, and the one choice in this file
#: that is taste rather than measurement.  Selected with TK_LEAD.
#:
#: `flute` is the closest thing to the whistled recording the whole score is
#: built on, which is why it is the default.  It is also the brightest, and
#: at F6 a piccolo sits at 1397 Hz with its formant right where the ear is
#: most sensitive -- so it can read as piercing over long stretches in a way
#: the sine-based `synth.whistle` never did.  The others trade that away:
#: `piano` puts an attack transient and a decay under the motif instead of a
#: sustained tone, which changes the phrasing as much as the timbre.
def _amp_head(y, drive=6.0):
    """A guitar amp, per note: pre-emphasis into a waveshaper into a cab.

    The DI guitar is clean by construction; rock tone is the amplifier's.
    Chain: tighten the lows (they turn to flub under gain), push the
    presence band into the clipper, clip asymmetrically (tanh plus a touch
    of second-harmonic bias -- tubes are not symmetric), then a 4x12-ish
    cabinet: steep rolloff above ~4.8 kHz and a presence lift near 2.5 kHz.
    Applied per NOTE, not per stem: each note drives the amp alone, the way
    layered guitar tracks do, so held doubles do not intermodulate into
    mush."""
    b, a = sp_signal.butter(2, 120/(SR/2), 'high')
    y = sp_signal.lfilter(b, a, y)
    b, a = sp_signal.butter(2, 900/(SR/2), 'high')
    y = y + 0.35*sp_signal.lfilter(b, a, y)
    y = np.tanh(drive*y + 0.12*drive*y*np.abs(y))
    b, a = sp_signal.butter(4, 4800/(SR/2), 'low')
    y = sp_signal.lfilter(b, a, y)
    b, a = sp_signal.butter(2, [1800/(SR/2), 3400/(SR/2)], 'band')
    y = y + 0.30*sp_signal.lfilter(b, a, y)
    return y


def _perform(y, dur, scoop=0.0, vib=0.0, rate=5.3, vib_delay=0.30):
    """A guitarist's left hand, applied to a recorded note.

    Real rock guitar is never at pitch: accented notes are scooped into
    from below (the finger lands and pulls up), and anything held gets
    finger vibrato -- wide, delayed past the attack, and slightly uneven.
    Implemented as variable-rate resampling along the note, so it is the
    pitch itself moving, not a chorus painted on top.  Applied BEFORE the
    amp, where the physical gesture lives."""
    n = len(y)
    t = np.arange(n)/SR
    c = np.zeros(n)
    if scoop > 0:
        tl = min(0.26, 0.06 + scoop*0.001)   # deep bends take longer
        k = t < tl
        c[k] -= scoop*(1 - t[k]/tl)**2
    if vib > 0:
        env = np.clip((t - vib_delay)/0.22, 0, 1)**2
        wob = 1 + 0.18*np.sin(2*np.pi*0.9*t + np.random.rand()*6.283)
        c += vib*env*np.sin(2*np.pi*rate*t*wob + np.random.rand()*0.5)
    step = 2.0**(c/1200.0)
    pos = np.cumsum(step) - step[0]
    pos = np.clip(pos, 0, n - 1)
    return np.interp(pos, np.arange(n, dtype=float), y)


class _Rock:
    """The electric guitar through the amp head, as a lead door.

    Every note goes in at full level (an amp's tone is set by how hard it
    is driven, and a lead that got cleaner as it got quieter would read as
    a different instrument), and `amp` becomes a pure output gain after
    the per-note normalisation."""

    def __init__(self, drive=6.0, trim=0.55):
        self.base = _eguitar()
        self.drive, self.trim = drive, trim

    def note(self, f, dur, amp=1.0, cents=0.0, vel=None):
        v = min(0.9, 0.35 + amp) + np.random.uniform(-0.08, 0.08)
        y = self.base.note(f, max(dur, 0.45), 1.0, cents, v)
        big = dur >= 1.8                    # a solo hold: full-step bend
        y = _perform(y, dur,                # in, wider and later vibrato
                     scoop=((170.0 if big else 45.0)
                            if (dur >= 0.5 and amp >= 0.28) else 0.0),
                     vib=(42.0 if big else 34.0) if dur >= 0.55 else 0.0,
                     rate=np.random.uniform(4.9, 5.7),
                     vib_delay=0.45 if big else min(0.32, 0.38*dur))
        y = _amp_head(y, self.drive*np.random.uniform(0.85, 1.15))
        if dur >= 0.8:
            # Sustain: a recorded pick decays, a cranked amp does not let
            # it.  Flatten the envelope toward its early level (up to
            # +12 dB late in the note), which is what compression at the
            # edge of feedback does, then release the last 80 ms.
            a1 = np.exp(-1.0/(0.040*SR))
            env = sp_signal.lfilter([1 - a1], [1, -a1], np.abs(y))
            i0 = int(0.12*SR)
            if len(env) > i0 + int(0.25*SR):
                ref = float(np.percentile(env[i0:i0 + int(0.25*SR)], 75))
                g = np.clip(ref/(env + 1e-9), 1.0, 4.0)
                a2 = np.exp(-1.0/(0.090*SR))
                g = sp_signal.lfilter([1 - a2], [1, -a2], g)
                ramp = np.clip((np.arange(len(g))/SR - 0.10)/0.15, 0.0, 1.0)
                y = y*(1.0 + (g - 1.0)*ramp)
                k = int(0.08*SR)
                y[-k:] *= np.linspace(1, 0, k)**0.7
        r = float(np.sqrt(np.mean(y**2)))
        if r > 1e-8:
            y *= self.trim*amp/r
        return y

    def chord(self, freqs, dur, amp=1.0):
        n = max(1, int(dur*SR))
        out = np.zeros(n)
        for f in freqs:
            v = self.note(f, dur, amp/len(freqs))
            out[:len(v)] += v[:n]
        return out


def trumpet(f, dur, amp=1.0, mute=False):
    """VSCO trumpet: open (susvib, F2-C5) or harmon-muted (A#2-A4).

    The harmon is the classic muted-ballad color, but it works by KILLING
    the fundamental -- which is fine in the middle register and pure buzz
    below it (a low-register harmon line measured 80% of its energy above
    2 kHz with nothing underneath).  Low, warm lines want the open horn;
    the mute is for mid-register color."""
    if mute:
        return _patch('tpt_harmon', os.path.join(
            VSCO, 'Brass', 'Trumpet', 'harmonM-sus'), amp_ref=0.5,
            loop=(0.45, 0.9), gain=GAIN['trumpet']).note(f, dur, amp)
    return _patch('tpt_open', os.path.join(
        VSCO, 'Brass', 'Trumpet', 'susvib'), amp_ref=0.5,
        loop=(0.45, 0.9), gain=GAIN['trumpet']).note(f, dur, amp)


def _eguitar():
    """Karoryfer Black and Green Guitars (CC0): a DI electric guitar.

    The 'green' guitar, 'ord' articulation -- normal picked notes, six-plus
    second sustains, two dynamics, four round robins.  Decay=True: a picked
    string rings and dies like a piano note, so short requests keep the
    pick and the ring is damped to length."""
    return _patch('eguitar', os.path.join(
        ROOT, 'karoryfer.black-and-green-guitars', 'Samples', 'green', 'ord'),
        decay=True, amp_ref=0.5, gain=GAIN['eguitar'])


LEADS = {
    'glass':   _wineglass,
    'chimes':  _chimes,
    'flute':   lambda: Layered(_flute(), _piccolo(), 1100.0),
    'piano':   _piano,
    'ocarina': _ocarina,
    'vibes':   _vibes,
    'eguitar': _eguitar,
    'rockguitar': _Rock,
}

#: `glass`, not `flute`, and the reason is timbre rather than taste.
#:
#: A flute is a column of air driven by a body: it has a breath transient at
#: every note, a strong fundamental with a nearly pure harmonic series above
#: it, and vibrato.  All three of those read as *someone playing*, which is
#: exactly wrong for this game -- and with every cue's melody going through
#: `whistle()`, every cue came out sounding like the same person with the
#: same flute.
#:
#: Rubbed glass has no attack at all, its partials are inharmonic, and it
#: does not breathe.  It is also much closer to the source: the phrase this
#: whole soundtrack is built on was WHISTLED, which is a near-sine tone, and
#: a wine glass is the only real instrument that is one.
DEFAULT_LEAD = 'glass'


def _lead():
    name = os.environ.get('TK_LEAD', DEFAULT_LEAD)
    if name not in LEADS:
        raise SystemExit('TK_LEAD=%s -- have: %s'
                         % (name, ' '.join(sorted(LEADS))))
    return LEADS[name]()


def whistle(f, dur, amp=1.0, vib=0.011, vrate=5.0):
    """The signature instrument.

    Under the default lead this is piccolo above the break and flute below,
    split at 1100 Hz -- between the lead stem's F5 (698 Hz) and the whistle
    stem's F6 (1397 Hz), so each stem lands wholly on one instrument and the
    two never trade mid-phrase.
    """
    return _lead().note(f, dur, amp)


def whistle_bend(f, dur, amp=1.0, cents=0.0, vib=0.013):
    """The lead instrument, with the pitch sliding across the note.

    A struck lead cannot really bend -- a piano has no such gesture -- but
    `Patch.note` applies it anyway rather than special-casing, because a
    20-cent sag on a decaying note reads as detuning, which is the effect the
    combat cue wanted from it in the first place.
    """
    return _lead().note(f, dur, amp, cents)


def reed(f, dur, amp=1.0, vib=0.008, bright=1.0):
    return _ocarina().note(f, dur, amp)


def pad(freqs, dur, amp=1.0, cutoff=1900):
    """A string section instead of three detuned saws.

    Voiced by register rather than played as one patch: below C3 the cellos,
    C3-C4 the violas, above that the violins.  A four-note chord handed
    wholesale to the violin section and transposed down is one section
    pretending to be an orchestra, and it sounds like it.
    """
    return _voiced(freqs, dur, amp, GAIN['pad'])


def strings(freqs, dur, amp=1.0, cutoff=2600, atk=0.18):
    return _voiced(freqs, dur, amp, GAIN['strings'])


#: Section balance.  `_measure` normalises each patch to its own level, which
#: is right within a patch and wrong between three of them: the violin
#: samples were recorded quieter, so normalising made the violins land about
#: 12 dB hot against the cellos and every chord came out top-heavy with no
#: taper.  A real section is not flat.  These put it back.
SECTIONS = ((130.8, 'cello', 'Cello Section', 'susvib', 1.00),
            (261.6, 'viola', 'Viola Section', 'susvib', 0.72),
            (1e9, 'violin', 'Violin Section', 'susVib', 0.42))


def _voiced(freqs, dur, amp, gain=1.0):
    n = max(1, int(dur * SR))
    y = np.zeros(n)
    for f in freqs:
        top, part, folder, sub, bal = next(x for x in SECTIONS if f < x[0])
        v = _sect(part, folder, sub, bal).note(f, dur, amp / len(freqs),
                                               vel=amp)
        y[:len(v)] += v[:n] * gain
    return y


def pluck(f, dur, amp=1.0, damp=0.494):
    return _patch('harp', os.path.join(VSCO, 'Strings', 'Harp'),
                  decay=True, amp_ref=0.4, gain=GAIN['harp']).note(f, dur, amp)


def bell(f, dur, amp=1.0):
    return _patch('glock', os.path.join(VSCO, 'Percussion', 'Glock'),
                  decay=True, amp_ref=0.4, gain=GAIN['glock']).note(f, dur, amp)


def organ(f, dur, amp=1.0, bright=1.0):
    """Pedal division below F3, manuals above -- which is where the break
    actually is on the instrument, not a crossfade invented here."""
    p = _organ_ped() if f < 175.0 else _organ_man()
    return p.note(f, dur, amp)


def glass(f, dur, amp=1.0, trem=3.1):
    """synth.py's glass() is a glass-harmonica voice. So is this."""
    return _wineglass().note(f, dur, amp)


def hammer(f, dur, amp=1.0, bright=1.0):
    """synth.hammer() is a fortepiano, and this door now honours that.

    It was mapped to the folk harp in the first sampler pass, which held up
    under slow writing and fell apart under fast: "Ship's Business" runs
    alberti sixteenths through this door, and sixteen plucked-string attacks
    a bar reads as rapid guitar picking -- a listening note said exactly
    that.  Figuration written for a keyboard gets a keyboard: the Kawai
    grand, four velocity layers, round robins.  The folk harp remains
    fetched for anything that actually wants a plucked colour later.
    """
    return _piano().note(f, dur, amp) * 0.20


def kick(amp=1.0):
    return _patch('bd', os.path.join(
        VCSL, 'Membranophones', 'Struck Membranophones', 'Bass Drum 2'),
        kit=True, include=('hit',), gain=0.9).hit(amp)


def snare(amp=1.0):
    return _patch('sn', os.path.join(
        VCSL, 'Membranophones', 'Struck Membranophones', 'Snare Drum, Modern 1'),
        kit=True, include=('hitsn',), gain=0.8).hit(amp)
    # 'hitsn', not 'hit': VCSL's snare files tokenise as HitNS/HitSN
    # (snares off/on) -- the bare 'hit' matched nothing, and the door had
    # never been exercised because the album renders kept the synth kit.


def hat(dur=0.055, amp=1.0):
    return _patch('hh', os.path.join(
        VCSL, 'Idiophones', 'Struck Idiophones', 'Hi-Hat Cymbal'),
        kit=True, include=('hitc',), gain=0.7).hit(amp, dur=max(dur, 0.12))


# ================= the texture doors: the full cutover =================
# The hybrid kept sub, drone, bowed, blade, metal, cluster, heart, impact,
# air and the swells as oscillators, on the theory that they were not
# imitating anything.  Listening said otherwise: a synthesised texture next
# to a recorded instrument reads as a different room.  Every door below maps
# the synth voice to the nearest thing a player would actually bow, strike
# or shake -- the game's low end is a contrabass section now, its dread is
# tremolo strings, its metal is a bowed cymbal, its air is an ocean drum.

KARO = ROOT


def _kcello_sus():
    """Karoryfer/bigcat cello, sustains.  One player, close, dark -- and the
    first patch in this soundtrack with real ROUND ROBINS: every note exists
    as down-bow and up-bow at four dynamics, so a repeated note is never the
    identical recording twice."""
    return _patch('kcello_sus', os.path.join(KARO, 'cello', 'Samples', 'sus'),
                  amp_ref=0.6, loop=(0.45, 0.92), gain=GAIN['kcello'])


def _kcello_stac():
    """The same cello, staccato: four round robins per note per dynamic."""
    return _patch('kcello_stac', os.path.join(KARO, 'cello', 'Samples',
                  'staccato'), decay=True, amp_ref=0.6, gain=GAIN['kstac'])


def _meatbass():
    """Karoryfer Meatbass: a 1958 Otto Rubner double bass, arco, three
    velocity layers, up/down bow round robins."""
    return _patch('meatbass', os.path.join(KARO, 'meatbass', 'Samples',
                  'arco_looped'), amp_ref=0.6, loop=(0.4, 0.92),
                  gain=GAIN['meatbass'])


def _cbass():
    return _patch('cbass', os.path.join(VSCO, 'Strings', 'Solo Contrabass'),
                  include=('susvib',), amp_ref=0.5, gain=GAIN['cbass'],
                  loop=(0.4, 0.92))


def _trem(part, folder):
    return _patch('trem_' + part, os.path.join(VSCO, 'Strings', folder),
                  include=('trem',), amp_ref=0.5, gain=GAIN['trem'],
                  loop=(0.35, 0.92))


def _spic(part, folder):
    return _patch('spic_' + part, os.path.join(VSCO, 'Strings', folder),
                  include=('spic',), decay=True, amp_ref=0.5,
                  gain=GAIN['spic'])


def _sublp(x, fc=105.0, order=6):
    b, a = sp_signal.butter(order, fc/(SR/2), 'low')
    return sp_signal.lfilter(b, a, x)


def sub(f, dur, amp=1.0):
    """Contrabass, low-passed to be a SUB.

    The first cutover used the contrabass raw and it moved the whole
    soundtrack's centre of gravity: the synth theme carried 45.7% of its
    energy below 80 Hz and the sampled render 16.3%, because a bowed string
    stacks partials exactly where the old sine had silence -- and "the
    weight is at 20-80" is a documented identity of these cues, not an
    accident.  So the sub door keeps the instrument's fundamental and bow
    weight and low-passes the partial stack; the UNFILTERED
    contrabass still speaks through the `drone` and `bowed` doors, where its
    midrange is the point.  Gain re-calibrated after the filter.
    """
    p = _cbass()
    y = p.note(f, dur, amp*0.80, vel=0.5)
    v = p.note(f*0.5, dur, amp*0.40, vel=0.5)
    n = max(len(y), len(v))
    out = np.zeros(n)
    out[:len(y)] += y
    out[:len(v)] += v
    out = _sublp(out)
    # Normalised AFTER the filter, per note, to the oscillator sub's own flat
    # law (rms = 0.665*amp).  A fixed gain cannot work here: how much of a
    # bowed note survives a 105 Hz low-pass depends on the register -- a
    # fixed 17x measured +23 dB at 43 Hz and -1 dB at 87 -- and the per-note
    # normalisation upstream was computed on the unfiltered recording.
    r = float(np.sqrt(np.mean(out**2)))
    if r > 1e-8:
        out *= (0.665*amp)/r
    return out


def drone(f, dur, amp=1.0, cut0=280, cut1=900):
    """Low bowed mass: contrabass sustain + cello tremolo a fifth up,
    detuned pair.  The cutoff sweep that defined the synth version is gone
    -- a tremolo section IS a slow boil and needs no filter to say so."""
    # vel pinned: amp must scale gain only, never re-pick the recorded
    # velocity layer.  The mass is Meatbass; the boil above it is the
    # Karoryfer cello doubled at the octave and the twelfth, whose bow-change
    # round robins keep the long tones alive where the tremolo section
    # sounded like a held preset.
    p = _meatbass(); t = _kcello_sus()
    y = p.note(f, dur, amp*0.60, vel=0.5)
    for df, a in ((1.0, 0.28), (1.5, 0.17)):
        v = t.note(max(f*2*df, 65.0), dur, amp*a, vel=0.5)
        y[:len(v)] += v[:len(y)]
    return y


def bowed(f, dur, amp=1.0, res=3.0):
    """One player, close.  Meatbass below C2, the Karoryfer cello above --
    a real soloist with round robins and four dynamics, which is the single
    biggest cure for the sampled set sounding like a mockup: a phrase on
    this voice never plays the same recording twice in a row."""
    if f < 65.0:
        return _meatbass().note(f, dur, amp*0.8, vel=0.55)
    return _kcello_sus().note(f, dur, amp*0.85, vel=0.55)


def cluster(freqs, dur, amp=1.0, cut=1400):
    """A minor-second stack of tremolo strings, which is what a cluster is
    when an orchestra plays one."""
    t = _trem('viola', 'Viola Section')
    n = max(1, int(dur*SR))
    y = np.zeros(n)
    for f in freqs:
        v = t.note(f, dur, amp/max(1, len(freqs)), vel=0.5)
        y[:len(v)] += v[:n]
    return y


def _pizz():
    return _patch('pizz_cello', os.path.join(VSCO, 'Strings', 'Cello Section'),
                  include=('pizzt',), decay=True, amp_ref=0.5,
                  gain=GAIN['pizz'])


def blade(f, dur, amp=1.0, bite=2.4, drive=2.2):
    """The combat riff, third instrument: piano and pizzicato.

    Two bowed articulations failed in this chair for the same reason:
    nothing bowed speaks in a tenth of a second.  What does is a struck
    string and a plucked one -- the standard action-ostinato pairing.  The
    Kawai grand carries the pitch and the drive; the cello section's
    pizzicato snaps on top of each attack.  Both are decay instruments, so
    speed costs them nothing, and the notes ring past the grid the way
    piano ostinati actually do."""
    d = max(dur, 0.30)
    y = _piano().note(f, d, amp) * 0.20
    v = _pizz().note(f, d, amp)
    n = max(len(y), len(v))
    out = np.zeros(n)
    out[:len(y)] += y
    out[:len(v)] += v
    return out * 0.375                 # measured: raw pairing sat 8.5 dB over
                                       # the chair's level; riff under motif


def metal(f, dur, amp=1.0):
    """Bowed suspended cymbal -- the real version of an inharmonic sour
    ring.  Unpitched, so the note request selects among the four bow
    recordings and `dur` damps the tail."""
    return _patch('cymbal', os.path.join(
        VCSL, 'Idiophones', 'Struck Idiophones', 'Suspended Cymbal 1'),
        kit=True, include=('bow',), gain=GAIN['cymbal']).hit(amp, dur=dur)


def impact(amp=1.0, dur=3.4):
    """A gong, which is what an impact is."""
    return _patch('gong', os.path.join(
        VCSL, 'Idiophones', 'Struck Idiophones', 'Gong 1'),
        kit=True, exclude=('scrape',), gain=GAIN['gong']).hit(amp, dur=dur)


def heart(amp=1.0):
    """Two soft bass-drum strokes, the second lighter -- a real skin."""
    k = _patch('bd', os.path.join(
        VCSL, 'Membranophones', 'Struck Membranophones', 'Bass Drum 2'),
        kit=True, include=('hit',), gain=GAIN['heartbd'])
    a = k.hit(amp*0.5, dur=0.6)
    b = k.hit(amp*0.31, dur=0.5)
    out = np.zeros(int(0.85*SR))
    out[:len(a)] += a[:len(out)]
    i = int(0.235*SR)
    m = min(len(b), len(out)-i)
    out[i:i+m] += b[:m]
    return out


def air(dur, amp=1.0, lo=120, hi=1400):
    """An ocean drum, which is air with a shore in it."""
    return _patch('ocean', os.path.join(
        VCSL, 'Membranophones', 'Other Membranophones', 'Ocean Drum'),
        kit=True, gain=GAIN['ocean']).hit(amp, dur=dur)


def noise_swell(dur, amp=1.0):
    """Suspended cymbal crescendo, length-matched to the ask."""
    return _patch('cresc', os.path.join(
        VCSL, 'Idiophones', 'Struck Idiophones', 'Suspended Cymbal 1'),
        kit=True, include=('cresc',), gain=GAIN['cymbal']).hit(amp, dur=dur)


def rev_swell(dur, amp=1.0, f=None):
    """The same crescendo, reversed -- landing on the downbeat after it."""
    y = noise_swell(dur, amp)
    return y[::-1].copy()


#: The names `synth.use_samples()` rebinds.  Everything else in synth.py --
#: sub, saw, drone, blade, bowed, metal, heart, impact, air, noise_swell, the
#: filters, the reverb, the Track mixer and the whole master bus -- is
#: untouched and still does the work.
#:
#: Drums are separate because they are the one group where the synthesised
#: version may well be the right answer: this is a game about a ship, and
#: `kick()` is a pitch-swept sine that reads as a machine rather than as a
#: room with a drummer in it.  Both are rendered so the choice can be made by
#: ear -- see `--drums` in build.py.
MELODIC = ('whistle', 'whistle_bend', 'reed', 'pad', 'strings', 'pluck',
           'bell', 'glass', 'hammer', 'organ')
TEXTURE = ('sub', 'drone', 'bowed', 'blade', 'cluster', 'metal', 'impact',
           'heart', 'air', 'noise_swell', 'rev_swell')
DRUMS = ('kick', 'snare', 'hat')
DOORS = MELODIC + TEXTURE + DRUMS
