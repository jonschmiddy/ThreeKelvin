"""The engines at idle, heard: the looping bed `Audio` plays under your idle flame.

    uv run --with numpy --with scipy --with soundfile python audio/idle_bed.py [--review DIR]

Jon, Oct 13: "Let's have a low burn sound for the idle engines". The coded flame
idles wherever your ship sits (LOCAL, fights), and an arrival sputters down to
that idle and stays there. This is the sound of it: a bed you notice when it
stops, well under the map's thrust loop and under every UI and combat sound.

NOTHING HERE IS GENERATED. `ship_idle.wav` is the map's thrust loop
(`ship_thrust_loop.wav`, a second of the arrival clip's clean burn) pitched down
a fourth and low-passed at about 520 Hz: the same drive, throttled back to a
soft low rumble. 1.333 s.

JON PICKED IT FROM THREE IDEAS (Oct 13, "bed:A"). The other two, in git with
the commit before this one's: B, the calmest 1.6 s of the heavy arrival take's
clean burn re-cut as its own loop with a folded ramp (darker, breathier); C,
the thrust loop an octave down, gated into 16 uneven puffs over 2 s at the
flame's 8 a second (a sparse burble).

HOW THE LOOP IS MADE SEAMLESS, and why the join is measured, not listened to:
  * It is resampled and filtered IN THE FREQUENCY DOMAIN over exactly one period
    of an already-seamless loop. A periodic signal stays periodic under both, so
    the join is a sample step like any other -- and with nothing above 520 Hz
    there is no energy at the join to click with.
  * The file is N + 1 frames, the last a copy of the first, and imports with
    loop_end -1 (the way `ship_thrust_loop` does): Godot loops at frames - 1, so
    the loop is exactly N and the copy is only read as the interpolation partner.
    Imported uncompressed (compress/mode 0): Godot's default for a new wav is
    lossy, and a lossy codec is the thing that touches a join.
  * Mono, 16-bit PCM. Ogg cannot hold a loop.
The script prints the step across the join against the loop's own step
distribution (median and 99.9th percentile) and the 10 ms RMS either side of it.
A click is a join step far out of the loop's own range. Last run: the join is
0.43x the median step and 0.10x the 99.9th percentile.

Mastered to -20 dBFS RMS; `Audio.IDLE_DB` sets where it sits in the game.
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
OUT = "ship_idle"


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


def make() -> np.ndarray:
    src = loop_of(os.path.join(SFX, "ship_thrust_loop.wav"))     # 44100
    y = fft_resample(src, int(round(len(src) * 4 / 3)))          # down a fourth
    return fft_lowpass(y, 520.0, 260.0)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--review", default="")
    args = ap.parse_args()
    x = normalise(make(), -20.0)
    pcm16 = np.round(np.clip(x, -1, 1) * 32767.0).astype(np.int16)
    sf.write(os.path.join(SFX, OUT + ".wav"), np.concatenate([pcm16, pcm16[:1]]), SR,
             subtype="PCM_16")
    pcm = pcm16 / 32767.0
    r = seam(pcm)
    r["seconds"] = len(x) / SR
    r["peak_db"] = float(20 * np.log10(np.abs(pcm).max()))
    print(f"{OUT}: {len(x)} frames ({len(x) / SR:.3f} s)  "
          f"join {r['join_step']:.5f} = {r['join_over_median']:.2f}x median step "
          f"(p99.9 {r['p999_step']:.5f}, max {r['max_step']:.5f}); "
          f"curvature {r['join_curv_over_p999']:.2f}x p99.9; "
          f"10 ms rms {r['rms_10ms_before_db']:.1f} | {r['rms_10ms_after_db']:.1f} dB")
    if args.review:
        reps = int(np.ceil(8.0 * SR / len(x)))
        sf.write(os.path.join(args.review, "idle.wav"), np.tile(pcm16, reps), SR,
                 subtype="PCM_16")
        with open(os.path.join(args.review, "seam.json"), "w") as fh:
            json.dump(r, fh, indent=2)


if __name__ == "__main__":
    main()
