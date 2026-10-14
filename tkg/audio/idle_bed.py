"""The engines at idle, heard: three looping beds for `Audio.ship_idle`.

    uv run --with numpy --with scipy --with soundfile python audio/idle_bed.py [--review DIR]

Jon, Oct 13: "Let's have a low burn sound for the idle engines". The coded flame
idles wherever your ship sits (LOCAL, fights), and an arrival sputters down to
that idle and stays there. This is the sound of it: a bed you notice when it
stops, well under the map's thrust loop and under every UI and combat sound.

NOTHING HERE IS GENERATED. All three are cut from audio already in the game, and
shaped (filtered, pitched down, gated) -- never a bad take processed into a good
one. Three IDEAS, not three takes of one:

  A  `ship_idle_a`  the map's thrust loop (`ship_thrust_loop.wav`, the arrival
     clip's clean burn), pitched down a fourth and low-passed: the same drive,
     throttled back to a soft low rumble. 1.333 s.
  B  `ship_idle_b`  the calmest 1.6 s of the HEAVY arrival take's clean burn
     (row h has the longest burn), re-cut as its own loop: a darker, breathier
     roar with some air left on it. A different recording of the drive than A.
  C  `ship_idle_c`  a sparse low burble at the flame's own rate: the thrust loop
     an octave down, low-passed hard, gated into 16 uneven puffs over 2 s -- 8 a
     second, the rate `ThrusterFx` holds its idle shapes at.

HOW EACH LOOP IS MADE SEAMLESS, and why the join is measured, not listened to:
  * A and C are resampled and filtered IN THE FREQUENCY DOMAIN over exactly one
    period of an already-seamless loop. A periodic signal stays periodic under
    both, so the join is a sample step like any other.
  * B is not periodic to start with: it is cut 1.6 s + a 0.25 s ramp long and the
    ramp is folded over its head with an equal-power crossfade (two stretches of
    the same roar are uncorrelated, so equal power keeps the level flat across
    the fold). Then it is low-passed circularly, the same as A and C.
  * Every file is N + 1 frames, the last a copy of the first, and imports with
    loop_end -1 (the way `ship_thrust_loop` does): Godot loops at frames - 1, so
    the loop is exactly N and the copy is only read as the interpolation partner.
  * Mono, 16-bit PCM. Ogg cannot hold a loop.
The script prints, per loop, the step across the join against the loop's own
step distribution (median and 99.9th percentile) and the 10 ms RMS either side
of the join. A click is a join step far out of the loop's own range.
"""
from __future__ import annotations

import argparse
import json
import os

import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
SFX = os.path.join(HERE, "..", "assets", "audio", "sfx")
SR = 44100


def mono(path: str) -> np.ndarray:
    x, sr = sf.read(path, dtype="float64")
    assert sr == SR, (path, sr)
    return x.mean(axis=1) if x.ndim > 1 else x


def loop_of(path: str) -> np.ndarray:
    """A shipped N+1 loop file, as its N-frame period."""
    return mono(path)[:-1]


def fft_lowpass(x: np.ndarray, fc: float, width: float) -> np.ndarray:
    """Circular low-pass: a raised-cosine roll-off from fc - width to fc."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    g = np.clip((fc - f) / width, 0.0, 1.0)
    g = 0.5 - 0.5 * np.cos(np.pi * g)
    g[0] = 0.0                                       # and no DC
    return np.fft.irfft(X * g, len(x))


def fft_resample(x: np.ndarray, n: int) -> np.ndarray:
    """Periodic resample to n frames (n > len(x) pitches down)."""
    X = np.fft.rfft(x)
    Y = np.zeros(n // 2 + 1, dtype=complex)
    k = min(len(X), len(Y))
    Y[:k] = X[:k]
    return np.fft.irfft(Y, n) * (n / len(x))


def fold(seg: np.ndarray, ramp: int) -> np.ndarray:
    """Fold the last `ramp` frames over the head, equal-power."""
    n = len(seg) - ramp
    t = (np.arange(ramp) + 0.5) / ramp
    out = seg[:n].copy()
    out[:ramp] = seg[:ramp] * np.sin(0.5 * np.pi * t) + seg[n:] * np.cos(0.5 * np.pi * t)
    return out


def normalise(x: np.ndarray, rms_db: float) -> np.ndarray:
    rms = np.sqrt(np.mean(x ** 2))
    return x * (10 ** (rms_db / 20.0) / rms)


def seam(x: np.ndarray) -> dict:
    """The join, measured: x is one period; the join is x[-1] -> x[0]."""
    steps = np.abs(np.diff(x))
    join = abs(x[0] - x[-1])
    w = int(0.010 * SR)
    before = np.sqrt(np.mean(x[-w:] ** 2))
    after = np.sqrt(np.mean(x[:w] ** 2))
    # the second derivative too: a kink with no step still clicks
    d2 = np.abs(np.diff(x, 2))
    join2 = abs(x[1] - 2 * x[0] + x[-1])
    join2b = abs(x[0] - 2 * x[-1] + x[-2])
    return {
        "join_step": float(join),
        "median_step": float(np.median(steps)),
        "p999_step": float(np.percentile(steps, 99.9)),
        "max_step": float(steps.max()),
        "join_over_median": float(join / np.median(steps)),
        "join_curv_over_p999": float(max(join2, join2b) / np.percentile(d2, 99.9)),
        "rms_10ms_before_db": float(20 * np.log10(before)),
        "rms_10ms_after_db": float(20 * np.log10(after)),
    }


def calmest(x: np.ndarray, lo: float, hi: float, length: float) -> int:
    """Start frame of the steadiest `length` s in x[lo:hi]: least 20 ms RMS spread."""
    h = int(0.020 * SR)
    a, b, n = int(lo * SR), int(hi * SR), int(length * SR)
    best, at = 1e9, a
    for s in range(a, b - n, h):
        seg = x[s:s + n]
        e = np.sqrt(np.mean(seg[: len(seg) // h * h].reshape(-1, h) ** 2, axis=1))
        spread = float(np.std(20 * np.log10(e + 1e-9)))
        if spread < best:
            best, at = spread, s
    return at


def make_a() -> np.ndarray:
    src = loop_of(os.path.join(SFX, "ship_thrust_loop.wav"))     # 44100
    y = fft_resample(src, int(round(len(src) * 4 / 3)))          # down a fourth
    return fft_lowpass(y, 520.0, 260.0)


def make_b() -> np.ndarray:
    x = mono(os.path.join(SFX, "thruster_arrive_heavy_h.wav"))
    n, ramp = int(1.6 * SR), int(0.25 * SR)
    s = calmest(x, 1.05, 2.95, (n + ramp) / SR)
    y = fold(x[s:s + n + ramp], ramp)
    # dark but breathing: the body below 300 Hz kept whole, a gentle slope
    # above it, and nothing over 2.2 kHz
    X = np.fft.rfft(y)
    f = np.fft.rfftfreq(len(y), 1.0 / SR)
    tilt = np.where(f < 300.0, 1.0, (300.0 / np.maximum(f, 1.0)) ** 0.6)
    X *= tilt
    y = np.fft.irfft(X, len(y))
    return fft_lowpass(y, 2200.0, 1200.0)


def make_c() -> np.ndarray:
    src = loop_of(os.path.join(SFX, "ship_thrust_loop.wav"))
    y = fft_resample(src, 2 * len(src))                          # an octave down
    y = fft_lowpass(y, 360.0, 180.0)
    # 16 puffs over 2 s, uneven: each its own depth and length, a raised-cosine
    # swell that never quite closes (the flame never goes out at idle).
    rng = np.random.default_rng(813)
    n = len(y)
    per = n // 16
    env = np.zeros(n)
    t = np.arange(per) / per
    for i in range(16):
        depth = rng.uniform(0.45, 1.0)
        width = rng.uniform(0.55, 0.9)
        u = np.clip(t / width, 0.0, 1.0)
        env[i * per:(i + 1) * per] = depth * (0.5 - 0.5 * np.cos(2 * np.pi * u))
    env = 0.22 + 0.78 * env
    # the envelope is itself one period long, so the gate cannot add a seam;
    # smooth it circularly so a puff never starts on a corner
    E = np.fft.rfft(env)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    E[f > 40.0] = 0.0
    env = np.fft.irfft(E, n)
    return y * env


def write_loop(path: str, x: np.ndarray) -> None:
    pcm = np.round(np.clip(x, -1, 1) * 32767.0).astype(np.int16)
    sf.write(path, np.concatenate([pcm, pcm[:1]]), SR, subtype="PCM_16")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--review", default="")
    args = ap.parse_args()
    report = {}
    for name, make in (("a", make_a), ("b", make_b), ("c", make_c)):
        x = normalise(make(), -20.0)        # every bed mastered to -20 dBFS RMS;
        #                                     Audio.IDLE_DB sets where it sits
        pcm = np.round(np.clip(x, -1, 1) * 32767.0) / 32767.0
        write_loop(os.path.join(SFX, f"ship_idle_{name}.wav"), x)
        r = seam(pcm)
        r["seconds"] = len(x) / SR
        r["peak_db"] = float(20 * np.log10(np.abs(pcm).max()))
        report[name] = r
        print(f"ship_idle_{name}: {len(x)} frames ({len(x) / SR:.3f} s)  "
              f"join {r['join_step']:.5f} = {r['join_over_median']:.2f}x median step "
              f"(p99.9 {r['p999_step']:.5f}, max {r['max_step']:.5f}); "
              f"curvature {r['join_curv_over_p999']:.2f}x p99.9; "
              f"10 ms rms {r['rms_10ms_before_db']:.1f} | {r['rms_10ms_after_db']:.1f} dB")
        if args.review:
            reps = int(np.ceil(8.0 * SR / len(x)))
            sf.write(os.path.join(args.review, f"{name}_idle.wav"),
                     np.round(np.tile(pcm, reps) * 32767).astype(np.int16), SR,
                     subtype="PCM_16")
    if args.review:
        with open(os.path.join(args.review, "seams.json"), "w") as fh:
            json.dump(report, fh, indent=2)


if __name__ == "__main__":
    main()
