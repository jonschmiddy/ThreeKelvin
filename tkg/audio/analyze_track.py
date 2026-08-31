"""Take a finished mix apart into the numbers a score can be written from.

`analyze.py` does this for the whistled source, but that is one monophonic
line and the question there is "what pitches".  This asks a different set of
questions about a full arrangement -- where the sections are, what enters at
each one, how the loudness and the brightness climb, and what the harmony is
doing -- because those are the things a build is made of, and an impression of
them ("slow build to grandiose") is not something you can write a score from.

    python3 analyze_track.py <file.wav|mp3> [--bars-at 142]

numpy and scipy only, like everything else here.  Chroma, onset detection and
the novelty curve are all a few lines each and the alternative is a
dependency, which `audio/` does not have and should not grow.
"""
import os, subprocess, sys, tempfile

import numpy as np
import soundfile as sf
from scipy import signal, ndimage

SR = 22050              # analysis rate. Nothing here cares above 11 kHz.
N_FFT = 2048
HOP = 512
FPS = SR / HOP

A4 = 440.0
PC = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']

# Krumhansl-Kessler key profiles -- the standard probe-tone ratings.  Used
# only to name a key, so their exact provenance matters less than the fact
# that everyone uses the same two vectors and they are not tuned per track.
KK_MAJ = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52,
                   5.19, 2.39, 3.66, 2.29, 2.88])
KK_MIN = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54,
                   4.75, 3.98, 2.69, 3.34, 3.17])


def load(path):
    """Stereo at SR, plus the mono sum. mp3 goes through ffmpeg."""
    if path.lower().endswith(('.mp3', '.m4a', '.ogg', '.flac')):
        tmp = os.path.join(tempfile.gettempdir(), '_at.wav')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', path,
                        '-ar', str(SR), '-ac', '2', tmp], check=True)
        path = tmp
    x, sr = sf.read(path, dtype='float64', always_2d=True)
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    if sr != SR:
        g = np.gcd(int(sr), SR)
        x = np.stack([signal.resample_poly(x[:, c], SR // g, int(sr) // g)
                      for c in range(2)], axis=1)
    return x, x.mean(axis=1)


def stft(y):
    f, t, Z = signal.stft(y, SR, nperseg=N_FFT, noverlap=N_FFT - HOP,
                          window='hann', boundary=None, padded=False)
    return f, t, np.abs(Z)


def onset_env(S):
    """Spectral flux: how much energy APPEARED since the last frame.

    Rectified on purpose -- energy leaving is a note ending and says nothing
    about where the beat is.  Log first, so a hi-hat in a quiet bar counts
    for as much as one in a loud bar; on a track with a 30 dB build the
    linear version finds every onset in the last minute and none in the first.
    """
    L = np.log1p(1000 * S)
    d = np.diff(L, axis=1, prepend=L[:, :1])
    e = np.maximum(0, d).sum(axis=0)
    return e - ndimage.uniform_filter1d(e, int(FPS))     # local mean removed


def tempo(env, lo=60, hi=190):
    """Autocorrelation of the onset envelope, peak inside a BPM window."""
    e = env - env.mean()
    ac = np.correlate(e, e, 'full')[len(e) - 1:]
    lags = np.arange(1, len(ac))
    bpm = 60.0 * FPS / lags
    m = (bpm >= lo) & (bpm <= hi)
    return float(bpm[m][np.argmax(ac[1:][m])])


def chroma(f, S):
    """Fold the spectrum onto 12 pitch classes.

    Bins below 55 Hz and above 2 kHz are dropped: the bass is where octave
    errors come from and above 2 kHz almost everything is a partial of
    something already counted.
    """
    keep = (f > 55) & (f < 2000)
    fk, Sk = f[keep], S[keep]
    pc = np.round(12 * np.log2(fk / A4)).astype(int) % 12
    C = np.zeros((12, S.shape[1]))
    for i in range(12):
        if (pc == i).any():
            C[i] = Sk[pc == i].sum(axis=0)
    return C / (C.sum(axis=0, keepdims=True) + 1e-12)


def key_of(c):
    """Best (tonic, mode) for a mean chroma vector, by correlation.

    Treat this as a hint and not as an answer.  Krumhansl profiles assume
    functional tonality, and this soundtrack deliberately has none -- no
    dominant, no leading tone, nothing cadences -- so the relative major and
    minor are near-indistinguishable to it.  Measured on cues whose key is
    known from their own scores: `theme` and `home` are F minor and both come
    back G# minor; `warm` is F minor and comes back G# major.  It reads the
    reference mp3 as A# minor at r=0.84, which IS right, because that track
    has a B-flat pedal under most of its length and this one does not do
    pedals.
    """
    best = None
    for i in range(12):
        for prof, mode in ((KK_MAJ, 'major'), (KK_MIN, 'minor')):
            r = np.corrcoef(c, np.roll(prof, i))[0, 1]
            if best is None or r > best[0]:
                best = (r, PC[i], mode)
    return best[1], best[2], best[0]


def novelty(C, band, k=48):
    """Checkerboard novelty over a self-similarity matrix.

    The kernel is the standard Foote one: it scores high where the frames
    before it resemble each other, the frames after it resemble each other,
    and the two halves do not resemble each other -- which is what a section
    boundary IS.  Chroma and band energy together, because an arrangement
    change with no harmonic change (the strings entering) has to count.
    """
    F = np.vstack([C, band / (band.max(axis=1, keepdims=True) + 1e-12)])
    F = F / (np.linalg.norm(F, axis=0, keepdims=True) + 1e-12)
    Sm = F.T @ F
    g = np.outer(signal.windows.gaussian(2 * k, k / 2),
                 signal.windows.gaussian(2 * k, k / 2))
    ker = np.sign(np.add.outer(np.arange(-k, k), np.arange(-k, k))
                  * np.subtract.outer(np.arange(-k, k), np.arange(-k, k)))
    ker = -ker * g                       # +1 on the diagonal blocks, -1 off
    n = np.zeros(Sm.shape[0])
    for i in range(k, Sm.shape[0] - k):
        n[i] = (Sm[i - k:i + k, i - k:i + k] * ker).sum()
    n = np.maximum(0, n - ndimage.uniform_filter1d(n, int(8 * FPS)))
    return n / (n.max() + 1e-12)


def bands(f, S):
    """Low / mid / high energy. The arrangement's shape, three numbers wide."""
    return np.vstack([S[(f >= 20) & (f < 250)].sum(axis=0),
                      S[(f >= 250) & (f < 2000)].sum(axis=0),
                      S[(f >= 2000)].sum(axis=0)])


def db(v):
    return 20 * np.log10(np.maximum(v, 1e-9))


def main(path, bpm_grid=None):
    x, y = load(path)
    f, t, S = stft(y)
    env = onset_env(S)
    C, B = chroma(f, S), bands(f, S)
    bpm = tempo(env)

    rms = np.sqrt(ndimage.uniform_filter1d(y ** 2, int(0.4 * SR)))
    rms_f = np.interp(t, np.arange(len(y)) / SR, rms)
    cent = (f[:, None] * S).sum(axis=0) / (S.sum(axis=0) + 1e-12)
    mid = x.mean(axis=1); side = (x[:, 0] - x[:, 1]) / 2
    width = np.interp(t, np.arange(len(mid)) / SR,
                      np.sqrt(ndimage.uniform_filter1d(side ** 2, int(0.4 * SR)))
                      / (np.sqrt(ndimage.uniform_filter1d(mid ** 2,
                                                          int(0.4 * SR))) + 1e-9))

    print('%s\n%s' % (os.path.basename(path), '=' * 64))
    print('length      %.2f s' % (len(y) / SR))
    print('tempo       %.1f BPM  (bar %.3f s)' % (bpm, 4 * 60 / bpm))
    if bpm_grid:
        print('            %.2f bars at %g BPM' % (len(y) / SR / (4 * 60 / bpm_grid),
                                                   bpm_grid))
    k = key_of(C.mean(axis=1))
    print('key         %s %s  (r=%.2f)' % (k[0], k[1], k[2]))
    print('peak        %.3f      rms %.1f dBFS' % (np.abs(y).max(),
                                                   db(np.sqrt((y ** 2).mean()))))

    n = novelty(C, B)
    pk, _ = signal.find_peaks(n, height=0.12, distance=int(8 * FPS))
    edges = [0] + list(pk) + [len(t) - 1]
    print('\n%-6s %-6s %6s %6s %6s %6s %6s %6s  %s' % (
        'start', 'end', 'rms', 'low', 'mid', 'high', 'centr', 'width', 'chord'))
    print('-' * 78)
    for a, b in zip(edges[:-1], edges[1:]):
        if t[b] - t[a] < 4:
            continue
        sl = slice(a, b)
        c = C[:, sl].mean(axis=1)
        top = np.argsort(c)[::-1][:4]
        bl = B[:, sl].mean(axis=1); bl = bl / bl.sum()
        print('%5.1f  %5.1f  %6.1f %5.0f%% %5.0f%% %5.0f%% %6.0f %6.2f  %s' % (
            t[a], t[b], db(rms_f[sl].mean()), 100 * bl[0], 100 * bl[1],
            100 * bl[2], cent[sl].mean(), width[sl].mean(),
            ' '.join(PC[i] for i in sorted(top, key=lambda i: -c[i]))))

    # The build, sampled on a coarse grid -- the shape of the thing.
    print('\nbuild (10 s steps)')
    print('%-6s %7s %7s %7s %7s' % ('t', 'rms dB', 'centr', 'width', 'onsets'))
    for s in range(0, int(t[-1]) - 5, 10):
        m = (t >= s) & (t < s + 10)
        print('%5.0f  %7.1f %7.0f %7.2f %7.1f' % (
            s, db(rms_f[m].mean()), cent[m].mean(), width[m].mean(),
            np.maximum(0, env[m]).mean()))


if __name__ == '__main__':
    a = [v for v in sys.argv[1:] if not v.startswith('--')]
    g = [v for v in sys.argv[1:] if v.startswith('--bars-at')]
    main(a[0], float(g[0].split('=')[1]) if g else None)
