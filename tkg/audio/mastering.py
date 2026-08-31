"""Mastering tools.  Meters and processors, not a pipeline.

Every processor here is `x -> y` on a mono or stereo array, exactly like an
instrument door -- so they apply to whatever layer needs them: one stem in a
score's render() (before the master bus, where the stem-sum invariant is not
yet in force), a whole mix after master(), or an offline check on a wav.
Nothing in this module is called automatically by anything: a score reaches
for a tool the way it reaches for a reverb.

The meters follow ITU-R BS.1770-4: K-weighted, gated loudness in LUFS, and
4x-oversampled true peak in dBTP.  Peak normalisation (what master() does)
answers "will it clip"; LUFS answers "how loud does it feel", and two songs
with one peak can sit 6 dB apart in LUFS.  The album's quiet-station /
loud-fight tiering should be enforced in LUFS, which is what `report` prints.

    python3 mastering.py report [out_s]        LUFS / dBTP, one row per song
    python3 mastering.py stems out_s/burn_stems   windowed per-layer balance
"""
import os
import sys
import glob
import wave

import numpy as np
from scipy import signal as sp_signal
from scipy import ndimage as sp_ndimage

SR = 44100


# ---------------- meters ----------------

def _k_filters(fs=SR):
    """The two BS.1770 pre-filters, redesigned for our rate.

    The spec prints coefficients for 48 kHz only; these are the analog
    prototypes (a +4 dB high shelf at 1681.97 Hz modelling the head, and a
    38.14 Hz highpass) run through the bilinear transform at `fs` -- the
    same derivation pyloudnorm uses.
    """
    db, f0, Q = 3.999843853973347, 1681.974450955533, 0.7071752369554196
    K = np.tan(np.pi * f0 / fs)
    Vh = 10.0 ** (db / 20.0)
    Vb = Vh ** 0.4996667741545416
    a0 = 1.0 + K / Q + K * K
    shelf = ([(Vh + Vb * K / Q + K * K) / a0,
              2.0 * (K * K - Vh) / a0,
              (Vh - Vb * K / Q + K * K) / a0],
             [1.0, 2.0 * (K * K - 1.0) / a0, (1.0 - K / Q + K * K) / a0])
    f0, Q = 38.13547087602444, 0.5003270373238773
    K = np.tan(np.pi * f0 / fs)
    a0 = 1.0 + K / Q + K * K
    hp = ([1.0, -2.0, 1.0],
          [1.0, 2.0 * (K * K - 1.0) / a0, (1.0 - K / Q + K * K) / a0])
    return shelf, hp


def lufs(x, fs=SR):
    """Integrated loudness in LUFS.  x: (n,) mono or (n, ch)."""
    if x.ndim == 1:
        x = x[:, None]
    shelf, hp = _k_filters(fs)
    y = np.stack([sp_signal.lfilter(*hp, sp_signal.lfilter(*shelf, x[:, c]))
                  for c in range(x.shape[1])], axis=1)
    blk = int(0.400 * fs)
    hop = blk // 4                                  # 75% overlap per spec
    n = (len(y) - blk) // hop + 1
    if n < 1:
        return -np.inf
    idx = np.arange(blk)[None, :] + hop * np.arange(n)[:, None]
    z = np.array([np.mean(y[:, c][idx] ** 2, axis=1)
                  for c in range(y.shape[1])])      # (ch, blocks)
    lb = -0.691 + 10.0 * np.log10(np.maximum(z.sum(axis=0), 1e-12))
    keep = lb > -70.0                               # absolute gate
    if not keep.any():
        return -np.inf
    ref = -0.691 + 10.0 * np.log10(z[:, keep].sum(axis=0).mean())
    keep &= lb > ref - 10.0                         # relative gate
    if not keep.any():
        return -np.inf
    return -0.691 + 10.0 * np.log10(z[:, keep].sum(axis=0).mean())


def true_peak(x, fs=SR):
    """True peak in dBTP: 4x oversampled, per BS.1770 annex 2."""
    if x.ndim == 1:
        x = x[:, None]
    pk = max(np.abs(sp_signal.resample_poly(x[:, c], 4, 1)).max()
             for c in range(x.shape[1]))
    return 20.0 * np.log10(max(pk, 1e-12))


def window_scan(x, fs=SR, win=0.4):
    """(avg_db, peak_db, peak_at_seconds) of RMS over `win`-second windows.

    The tool that found burn's gong: whole-track RMS averages a loud event
    into silence; the windowed view keeps it visible.
    """
    if x.ndim > 1:
        x = x.mean(axis=1)
    w = int(win * fs)
    n = len(x) // w
    if n < 1:
        return -np.inf, -np.inf, 0.0
    r = np.sqrt(np.mean(x[:n * w].reshape(n, w) ** 2, axis=1))
    i = int(np.argmax(r))
    db = lambda v: 20.0 * np.log10(max(float(v), 1e-9))
    return db(np.sqrt(np.mean(x ** 2))), db(r[i]), i * win


# ---------------- processors ----------------

def compress(x, thresh_db=-24.0, ratio=2.0, attack=0.030, release=0.300,
             knee_db=6.0, makeup_db=0.0, fs=SR):
    """A slow bus compressor: RMS detector, soft knee, gentle by default.

    2:1 above -24 dB with a 30 ms attack is glue, not squash -- transients
    pass, sustained loudness converges.  Apply to a stem in render() (a
    glass lead that swells 8 dB past its average) or to a submix.  Returns
    the gained signal; same length, works on mono or stereo.
    """
    mono = x if x.ndim == 1 else x.mean(axis=1)
    # one-pole RMS detector
    a_a = np.exp(-1.0 / (attack * fs))
    a_r = np.exp(-1.0 / (release * fs))
    env = sp_signal.lfilter([1 - a_r], [1, -a_r], mono ** 2)
    lvl = 10.0 * np.log10(np.maximum(env, 1e-12))
    over = lvl - thresh_db
    # soft knee
    gr = np.where(over <= -knee_db / 2, 0.0,
                  np.where(over >= knee_db / 2,
                           over * (1 - 1 / ratio),
                           (1 - 1 / ratio) * (over + knee_db / 2) ** 2
                           / (2 * knee_db)))
    # attack/release smoothing on the gain-reduction envelope
    g = np.empty_like(gr)
    s = 0.0
    for i in range(len(gr)):
        a = a_a if gr[i] > s else a_r
        s = a * s + (1 - a) * gr[i]
        g[i] = s
    gain = 10.0 ** ((makeup_db - g) / 20.0)
    return x * gain if x.ndim == 1 else x * gain[:, None]


def limit(x, ceiling_db=-1.0, lookahead=0.005, release=0.050, fs=SR):
    """Look-ahead brickwall: transparent under the ceiling, never over it."""
    c = 10.0 ** (ceiling_db / 20.0)
    mono = np.abs(x) if x.ndim == 1 else np.abs(x).max(axis=1)
    la = int(lookahead * fs)
    need = np.minimum(1.0, c / np.maximum(
        sp_ndimage.maximum_filter1d(mono, la * 2 + 1), 1e-9))
    a_r = np.exp(-1.0 / (release * fs))
    g = np.empty_like(need)
    s = 1.0
    for i in range(len(need)):
        s = need[i] if need[i] < s else a_r * s + (1 - a_r) * need[i]
        g[i] = s
    return x * g if x.ndim == 1 else x * g[:, None]


def loudness_normalize(x, target_lufs, fs=SR):
    """Scale to an integrated loudness.  Pure gain -- no dynamics touched."""
    cur = lufs(x, fs)
    if not np.isfinite(cur):
        return x
    return x * 10.0 ** ((target_lufs - cur) / 20.0)


# ---------------- CLI ----------------

def _load(p):
    w = wave.open(p, 'rb')
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
    ch = w.getnchannels()
    w.close()
    return x.reshape(-1, ch).astype(np.float64) / 32768.0


def report(out_dir='out_s'):
    rows = []
    for p in sorted(glob.glob(os.path.join(out_dir, '*.wav'))):
        x = _load(p)
        rows.append((os.path.basename(p)[:-4], lufs(x), true_peak(x)))
    print('%-14s %9s %8s' % ('song', 'LUFS', 'dBTP'))
    for name, l, tp in rows:
        print('%-14s %9.1f %8.2f' % (name, l, tp))
    return rows


def stems(stem_dir):
    print('%-12s %8s %8s %10s' % ('stem', 'avg dB', 'peak dB', 'peak at'))
    for p in sorted(glob.glob(os.path.join(stem_dir, '*.wav'))):
        avg, pk, at = window_scan(_load(p))
        print('%-12s %8.1f %8.1f %9.1fs' % (os.path.basename(p)[:-4],
                                            avg, pk, at))


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'report'
    if cmd == 'report':
        report(sys.argv[2] if len(sys.argv) > 2 else 'out_s')
    elif cmd == 'stems':
        stems(sys.argv[2])
    else:
        raise SystemExit('usage: mastering.py report [dir] | stems <stem_dir>')
