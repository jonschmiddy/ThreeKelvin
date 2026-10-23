"""A.S.H. robotic / Cortana chains. Local processing only.

usage: python ash_robotic.py <in.mp3> <out_dir>      -> A/B/C x subtle/strong + chains.json
       python ash_robotic.py <in.mp3> <out.mp3> <chain> <strength>
"""
import json, subprocess, sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal
import imageio_ffmpeg

FF = imageio_ffmpeg.get_ffmpeg_exe()
SR = 44100

CHAINS = {
    "A": {  # Cortana: polished digital sheen
        "subtle": {"detune_cents": 10, "detune_gain_db": -16, "oct_up_gain_db": -30, "oct_down_gain_db": None,
                   "chorus": {"delay_ms": 4.0, "depth_ms": 1.0, "rate_hz": 0.6, "feedback": 0.0, "wet": 0.18},
                   "air": {"shelf_hz": 9000, "gain_db": 3.0, "exciter_wet": 0.06},
                   "room": {"combs_ms": [5.3, 7.1, 9.7, 12.9], "fb": 0.62, "damp_hz": 9000, "wet": 0.10}},
        "strong": {"detune_cents": 12, "detune_gain_db": -11, "oct_up_gain_db": -21, "oct_down_gain_db": -24,
                   "chorus": {"delay_ms": 2.5, "depth_ms": 1.6, "rate_hz": 0.35, "feedback": 0.45, "wet": 0.28},
                   "air": {"shelf_hz": 8500, "gain_db": 5.5, "exciter_wet": 0.12},
                   "room": {"combs_ms": [3.1, 4.7, 6.3, 8.9], "fb": 0.72, "damp_hz": 11000, "wet": 0.18}},
    },
    "B": {  # Synth edge: vocoder at her pitch, crushed, under the voice
        "subtle": {"bands": 24, "lo_hz": 120, "hi_hz": 8000, "env_ms": 8, "wet": 0.22,
                   "carrier": "saw at tracked f0, noise when unvoiced", "bits": 12, "hold": 2, "air_db": 1.5},
        "strong": {"bands": 20, "lo_hz": 120, "hi_hz": 7000, "env_ms": 6, "wet": 0.36,
                   "carrier": "saw at tracked f0, noise when unvoiced", "bits": 8, "hold": 4, "air_db": 2.5},
    },
    "C": {  # Hologram glitch: holo chain + word-boundary stutters/dropouts + noise bed
        "subtle": {"holo": True, "events_per_line": 1, "stutter_ms": 45, "stutter_repeats": 2, "dropout_ms": 45,
                   "noise_db": -58, "seed": 3},
        "strong": {"holo": True, "events_per_line": 2, "stutter_ms": 60, "stutter_repeats": 3, "dropout_ms": 70,
                   "noise_db": -48, "seed": 3},
    },
}
LEVEL = {"rms_dbfs": -20.0, "ceiling_dbfs": -1.5, "knee_dbfs": -6.0}


# ---------- io ----------
def decode(path):
    raw = subprocess.run([FF, "-loglevel", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def encode(x, path):
    wav = Path(str(path) + ".tmp.wav")
    sf.write(wav, x, SR, subtype="PCM_16")
    subprocess.run([FF, "-y", "-loglevel", "error", "-i", str(wav), "-codec:a", "libmp3lame", "-b:a", "160k", str(path)], check=True)
    wav.unlink()


def rms(x):
    return float(np.sqrt(np.mean(x ** 2)) + 1e-12)


def db(g):
    return 10 ** (g / 20)


def level(y):
    y = y * db(LEVEL["rms_dbfs"]) / rms(y)
    ceil, knee = db(LEVEL["ceiling_dbfs"]), db(LEVEL["knee_dbfs"])
    a = np.abs(y); o = a > knee
    a[o] = knee + (ceil - knee) * np.tanh((a[o] - knee) / (ceil - knee))
    return np.sign(y) * a


# ---------- building blocks ----------
def mod_delay(x, delay_ms, depth_ms, rate_hz, feedback=0.0, phase=0.0):
    n = np.arange(len(x))
    d = (delay_ms + depth_ms * np.sin(2 * np.pi * rate_hz * n / SR + phase)) * SR / 1000
    if feedback == 0:
        return np.interp(n - d, n, x, left=0.0)
    # feedback flanger, sample loop on a short buffer
    out = np.zeros_like(x); buf = np.zeros_like(x)
    for i in range(len(x)):
        p = i - d[i]; j = int(p); f = p - j
        tap = (buf[j] * (1 - f) + buf[j + 1] * f) if j >= 0 else 0.0
        buf[i] = x[i] + feedback * tap
        out[i] = tap
    return out


def pitch_shift(x, ratio, win_ms=40.0):
    """Delay-line (two-tap granular) pitch shifter; keeps duration."""
    W = win_ms * SR / 1000
    n = np.arange(len(x))
    ph = ((1 - ratio) * n / W) % 1.0
    out = np.zeros_like(x)
    for off in (0.0, 0.5):
        p = (ph + off) % 1.0
        d = p * W
        out += np.interp(n - d, n, x, left=0.0) * np.sin(np.pi * p) ** 2
    return out


def shelf_high(x, f, gain_db):
    sos = signal.butter(2, f, btype="highpass", fs=SR, output="sos")
    return x + (db(gain_db) - 1) * signal.sosfilt(sos, x)


def exciter(x, wet):
    h = signal.sosfilt(signal.butter(2, 4000, "highpass", fs=SR, output="sos"), x)
    s = np.tanh(h * 4 / (np.max(np.abs(h)) + 1e-9))
    s = signal.sosfilt(signal.butter(2, 7000, "highpass", fs=SR, output="sos"), s)
    return x + wet * s * rms(x) / (rms(s) + 1e-12)


def metal_room(x, combs_ms, fb, damp_hz, wet):
    y = np.zeros_like(x)
    lp_b, lp_a = signal.butter(1, damp_hz, fs=SR)
    for ms in combs_ms:
        D = int(ms * SR / 1000)
        # feedback comb y[n] = x[n-D] + fb * lp(y[n-D]) approximated with lfilter (lp folded in after)
        a = np.zeros(D + 1); a[0] = 1; a[D] = -fb
        b = np.zeros(D + 1); b[D] = 1
        y += signal.lfilter(lp_b, lp_a, signal.lfilter(b, a, x))
    for g, ms in ((0.6, 1.7), (0.6, 0.6)):  # allpass diffusion
        D = int(ms * SR / 1000)
        b = np.zeros(D + 1); b[0] = -g; b[D] = 1
        a = np.zeros(D + 1); a[0] = 1; a[D] = -g
        y = signal.lfilter(b, a, y)
    return x + wet * y * rms(x) / (rms(y) + 1e-12)


def track_f0(x, hop=256, frame=1024, fmin=110, fmax=500):
    """Autocorrelation f0 per hop; 0 where unvoiced."""
    nf = 1 + (len(x) - frame) // hop
    f0 = np.zeros(nf); gate = db(-40) * np.max(np.abs(x))
    lo, hi = int(SR / fmax), int(SR / fmin)
    w = np.hanning(frame)
    for i in range(nf):
        s = x[i * hop:i * hop + frame] * w
        if np.sqrt(np.mean(s ** 2)) < gate * 0.3:
            continue
        ac = np.fft.irfft(np.abs(np.fft.rfft(s, 2 * frame)) ** 2)[:frame]
        if ac[0] <= 0:
            continue
        ac /= ac[0]
        k = lo + int(np.argmax(ac[lo:hi]))
        if ac[k] > 0.45:
            # parabolic refine
            a_, b_, c_ = ac[k - 1], ac[k], ac[k + 1]
            k = k + 0.5 * (a_ - c_) / (a_ - 2 * b_ + c_ + 1e-12)
            f0[i] = SR / k
    f0 = signal.medfilt(f0, 5)
    return f0, hop


def vocoder(x, p, rng):
    f0, hop = track_f0(x)
    t_hop = np.arange(len(f0)) * hop + 512
    n = np.arange(len(x))
    f = np.interp(n, t_hop, f0)
    voiced = np.interp(n, t_hop, (f0 > 0).astype(float))
    voiced = signal.sosfiltfilt(signal.butter(1, 30, fs=SR, output="sos"), voiced).clip(0, 1)
    fv = np.where(f > 0, f, np.median(f0[f0 > 0]) if np.any(f0 > 0) else 200.0)
    phase = np.cumsum(fv / SR) % 1.0
    dt = fv / SR
    saw = 2 * phase - 1
    # polyBLEP
    t = phase
    m1 = t < dt; tt = t[m1] / dt[m1]; saw[m1] -= tt + tt - tt * tt - 1
    m2 = t > 1 - dt; tt = (t[m2] - 1) / dt[m2]; saw[m2] -= tt * tt + tt + tt + 1
    carrier = voiced * saw + (1 - voiced) * rng.standard_normal(len(x)) * 0.5
    edges = np.geomspace(p["lo_hz"], p["hi_hz"], p["bands"] + 1)
    env_sos = signal.butter(2, 1000 / p["env_ms"] / (2 * np.pi), fs=SR, output="sos")
    out = np.zeros_like(x)
    for lo, hi in zip(edges[:-1], edges[1:]):
        bp = signal.butter(2, [lo, hi], btype="bandpass", fs=SR, output="sos")
        env = signal.sosfilt(env_sos, np.abs(signal.sosfilt(bp, x)))
        out += signal.sosfilt(bp, carrier) * env
    # crush this layer only
    hold = p["hold"]
    out = np.repeat(out[::hold], hold)[:len(x)]
    q = 2 ** (p["bits"] - 1)
    out = np.round(out / (np.max(np.abs(out)) + 1e-12) * q) / q
    return out, f0


def holo(x):
    sos = signal.butter(4, [300, 3400], btype="bandpass", fs=SR, output="sos")
    y = signal.sosfiltfilt(sos, x)
    y = y + 0.25 * signal.sosfilt(signal.butter(2, [1800, 3000], btype="bandpass", fs=SR, output="sos"), y)
    y = 0.8 * y + 0.3 * mod_delay(y, 7, 1.2, 0.9)
    k = int(0.0019 * SR); c = np.zeros_like(y); c[k:] = y[:-k]
    return y + 0.18 * c


def segments(x, gate_db=-38, min_gap_ms=80):
    """Return (gaps, line_breaks) as sample ranges of low energy between words."""
    env = np.sqrt(signal.sosfiltfilt(signal.butter(2, 40, fs=SR, output="sos"), x ** 2).clip(0))
    quiet = env < db(gate_db) * np.max(env)
    edges = np.flatnonzero(np.diff(quiet.astype(int)))
    if quiet[0]: edges = np.r_[0, edges]
    if quiet[-1]: edges = np.r_[edges, len(x) - 1]
    gaps = [(a, b) for a, b in zip(edges[::2], edges[1::2]) if b - a > min_gap_ms * SR / 1000]
    gaps = [g for g in gaps if g[0] > 0 and g[1] < len(x) - 1]  # inner gaps only
    return gaps


def glitch(x, p, rng):
    gaps = segments(x)
    # lines are split at the long pauses (>250 ms)
    # lines are split at the "..." pauses (>1 s); shorter gaps are word/phrase boundaries
    longs = [g for g in gaps if g[1] - g[0] > 1.0 * SR]
    bounds = [0] + [(a + b) // 2 for a, b in longs] + [len(x)]
    word_gaps = [g for g in gaps if g not in longs]
    events = []
    for lo, hi in zip(bounds[:-1], bounds[1:]):
        cands = [(g, None) for g in word_gaps if lo < g[0] and g[1] < hi]
        # the onset after a "..." pause (line start) can take a stutter only
        if lo > 0:
            cands.append(((lo, next((g[1] for g in longs if g[0] < lo < g[1]), lo)), "stutter"))
        if not cands:
            continue
        pick = rng.choice(len(cands), size=min(p["events_per_line"], len(cands)), replace=False)
        for i in sorted(pick):
            g, forced = cands[i]
            n_st = sum(1 for e in events if e[1] == "stutter")
            kind = forced or ("dropout" if n_st > len(events) - n_st else "stutter")
            events.append((g, kind))
    events.sort(key=lambda e: e[0][1])
    out = []; pos = 0; log = []
    fade = int(0.003 * SR); ramp = np.linspace(0, 1, fade)
    for (a, b), kind in events:
        if kind == "stutter":
            # repeat the next word's onset grain before the word (b = word onset)
            g = int(p["stutter_ms"] * SR / 1000)
            grain = x[b:b + g].copy(); grain[:fade] *= ramp; grain[-fade:] *= ramp[::-1]
            out.append(x[pos:b])
            for r in range(p["stutter_repeats"]):
                out.append(grain * (0.85 ** r))
                out.append(np.zeros(int(0.012 * SR)))
            pos = b
            log.append({"type": "stutter", "at_s": round(b / SR, 3)})
        else:
            # drop the tail of the previous word into the gap: hard cut to silence + a crushed blip
            d = int(p["dropout_ms"] * SR / 1000)
            cut = max(pos, a - d // 2)
            seg = x[pos:cut].copy(); seg[-fade:] *= ramp[::-1]
            out.append(seg)
            blip = np.repeat(rng.standard_normal(int(0.012 * SR) // 6), 6) * 0.04
            sil = np.zeros(max(0, b - cut)); sil[:len(blip)] += blip[:len(sil)]
            out.append(sil)
            pos = b
            log.append({"type": "dropout", "at_s": round(cut / SR, 3)})
    out.append(x[pos:])
    return np.concatenate(out), log


def noise_bed(n, level_db, rng):
    w = np.repeat(rng.standard_normal(n // 4 + 1), 4)[:n]
    w = signal.sosfilt(signal.butter(2, [900, 6000], btype="bandpass", fs=SR, output="sos"), w)
    flutter = 1 + 0.3 * np.sin(2 * np.pi * 0.27 * np.arange(n) / SR)
    return w / rms(w) * db(level_db) * flutter


# ---------- chains ----------
def apply(chain, strength, x):
    p = CHAINS[chain][strength]
    rng = np.random.default_rng(p.get("seed", 7))
    info = {}
    if chain == "A":
        y = x.copy()
        r = 2 ** (p["detune_cents"] / 1200)
        y += db(p["detune_gain_db"]) * (pitch_shift(x, r) + pitch_shift(x, 1 / r)) / 2
        y += db(p["oct_up_gain_db"]) * pitch_shift(x, 2.0, 25)
        if p["oct_down_gain_db"] is not None:
            y += db(p["oct_down_gain_db"]) * pitch_shift(x, 0.5, 60)
        c = p["chorus"]
        y = (1 - c["wet"]) * y + c["wet"] * mod_delay(y, c["delay_ms"], c["depth_ms"], c["rate_hz"], c["feedback"])
        y = shelf_high(y, p["air"]["shelf_hz"], p["air"]["gain_db"])
        y = exciter(y, p["air"]["exciter_wet"])
        rm = p["room"]
        y = metal_room(y, rm["combs_ms"], rm["fb"], rm["damp_hz"], rm["wet"])
    elif chain == "B":
        v, f0 = vocoder(x, p, rng)
        v *= rms(x) / rms(v)
        y = x + p["wet"] / (1 - p["wet"]) * v
        y = shelf_high(y, 9000, p["air_db"])
        vf = f0[f0 > 0]
        info["f0_median_hz"] = round(float(np.median(vf)), 1) if len(vf) else None
    else:
        y = holo(x)
        y, log = glitch(y, p, rng)
        y = level(y)
        y = y + noise_bed(len(y), p["noise_db"], rng)
        info["events"] = log
    return level(y), info


if __name__ == "__main__":
    src = Path(sys.argv[1]); x = decode(src)
    if len(sys.argv) == 5:
        y, _ = apply(sys.argv[3], sys.argv[4], x); encode(y, sys.argv[2]); sys.exit()
    out = Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
    report = {"source": src.name, "level": LEVEL, "chains": CHAINS, "renders": {}}
    for ch in "ABC":
        for st in ("subtle", "strong"):
            y, info = apply(ch, st, x)
            f = out / f"{ch}_{st}.mp3"
            encode(y, f)
            report["renders"][f.name] = {"duration_s": round(len(y) / SR, 2), "rms_dbfs": round(20 * np.log10(rms(y)), 1),
                                         "peak_dbfs": round(20 * np.log10(np.max(np.abs(y))), 1), **info}
            print(f.name, report["renders"][f.name])
    report["usage"] = ("python ash_robotic.py <line_clean.mp3> <out.mp3> <A|B|C> <subtle|strong>; "
                       "C's glitch events are placed per file from its pauses (seeded).")
    (out / "chains.json").write_text(json.dumps(report, indent=1))
