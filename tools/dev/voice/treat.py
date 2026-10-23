"""A.S.H.'s finishing chain for a raw ElevenLabs take, and the cut-off check.

What every voiced line in the game went through (Oct 17 to 23): the raw take's
edges faded (15 ms at the end, 3 ms at the start) so the chain does not click,
chain A "subtle" from ash_robotic.py (the light digital sheen), trimmed of
silence, levelled to -18.3 LUFS (the robotic reference set), then a soft-knee
ceiling, written as Ogg Vorbis q6.
"""
import subprocess
from pathlib import Path

import numpy as np
import pyloudnorm as pyln
import soundfile as sf

import ash_robotic as R

TARGET_LUFS = -18.3
STRENGTH = "subtle"
FADE_OUT_MS, FADE_IN_MS = 15, 3


def faded(path):
    """The raw take, decoded, with its edges faded so the chain cannot click."""
    x = R.decode(path).copy()
    n = int(FADE_OUT_MS * R.SR / 1000)
    x[-n:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, n))
    n = int(FADE_IN_MS * R.SR / 1000)
    x[:n] *= 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, n))
    return x


def trim_fade(y, sr, gate_db=-45, head_ms=30, tail_ms=80, fade_ms=10):
    env = np.abs(y)
    k = int(0.01 * sr)
    env = np.convolve(env, np.ones(k) / k, mode="same")
    on = np.flatnonzero(env > R.db(gate_db) * env.max())
    a = max(0, on[0] - int(head_ms * sr / 1000))
    b = min(len(y), on[-1] + int(tail_ms * sr / 1000))
    y = y[a:b].copy()
    f = int(fade_ms * sr / 1000)
    ramp = np.linspace(0, 1, f)
    y[:f] *= ramp
    y[-f:] *= ramp[::-1]
    return y


def lufs(y, sr=R.SR):
    return float(pyln.Meter(sr).integrated_loudness(y))


def treat(raw, out_ogg, target=TARGET_LUFS):
    """Raw take -> finished Ogg. Returns (raw samples, finished samples)."""
    x = faded(raw)
    # Padded so the chain's room and doubler ring out instead of ending at the edge.
    xp = np.concatenate([np.zeros(int(0.05 * R.SR)), x, np.zeros(int(0.4 * R.SR))])
    y, _ = R.apply("A", STRENGTH, xp)
    y = trim_fade(y, R.SR)
    y = y * R.db(target - lufs(y))
    ceil, knee = R.db(R.LEVEL["ceiling_dbfs"]), R.db(R.LEVEL["knee_dbfs"])
    a = np.abs(y)
    o = a > knee
    a[o] = knee + (ceil - knee) * np.tanh((a[o] - knee) / (ceil - knee))
    y = np.sign(y) * a
    wav = Path(str(out_ogg) + ".tmp.wav")
    sf.write(wav, y, R.SR, subtype="PCM_16")
    subprocess.run([R.FF, "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "6",
                    str(out_ogg)], check=True)
    wav.unlink()
    return x, y


def end_check(x):
    """The raw ending: last 10 ms level against the peak, and voicing of the last 40 ms."""
    pk = np.abs(x).max()
    w = int(0.01 * R.SR)
    last = 20 * np.log10(np.sqrt(np.mean(x[-w:] ** 2)) / pk + 1e-9)
    s = x[-4 * w:] * np.hanning(4 * w)
    ac = np.fft.irfft(np.abs(np.fft.rfft(s, 8 * w)) ** 2)[:4 * w]
    v = float((ac / ac[0])[int(R.SR / 500):int(R.SR / 110)].max()) if ac[0] > 0 else 0.0
    return round(float(last), 1), round(v, 2)


def auto_flag(x):
    """A warning for the pick page when a take may end mid-word, else None."""
    last, v = end_check(x)
    if last > -30 and v > 0.5:
        return f"likely cut off: ends voiced at {last} dB"
    if last > -25:
        return f"abrupt ending at {last} dB (voicing {v}); may be a final consonant"
    return None
