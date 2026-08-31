"""Mine MusicGen for SINGLE NOTES: the sample-library pipeline.

MusicGen composes; a sample library wants one instrument holding one pitch.
So: prompt hard for a single held note, take several draws, and let a pitch
tracker be the judge -- a take survives only if one stable f0 runs its
whole length.  Survivors are trimmed, faded, and filed under their MEASURED
pitch (midi name in the filename), which is exactly the layout Patch._scan
reads.  One clean take per instrument is already a playable door: the
resampler covers distance, same as the four-note wine glasses.

    musicgen-env/bin/python gen_notes.py choir 8      # 8 takes of choir
"""
import os
import subprocess
import sys

import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, 'samples', 'mgstubs')
GEN = [os.path.join(HERE, 'musicgen-env', 'bin', 'python'),
       os.path.join(HERE, 'musicgen-mlx', 'generate.py')]

PROMPTS = {
    'choir': ('a choir holding one single sustained vocal note, one pitch '
              'only, no melody, no words, constant unchanging drone, ahh'),
    'violin': ('a solo violin bowing one single sustained note, one pitch '
               'only, no melody, long constant bow, no vibrato'),
    'brass': ('a french horn holding one single sustained note, one pitch '
              'only, no melody, constant unchanging long tone'),
    'sax': ('a tenor saxophone holding one single sustained note, one '
            'pitch only, no melody, constant long tone'),
}


def f0_track(x, sr, fmin=60.0, fmax=1200.0, win=0.09, hop=0.045):
    """Autocorrelation f0 per window; returns (times, f0s, voiced_strength)."""
    n = int(win * sr)
    h = int(hop * sr)
    out = []
    for i in range(0, len(x) - n, h):
        seg = x[i:i + n]
        seg = seg - seg.mean()
        if np.sqrt(np.mean(seg**2)) < 1e-3:
            out.append((i / sr, 0.0, 0.0))
            continue
        ac = np.correlate(seg, seg, 'full')[n - 1:]
        ac /= ac[0] + 1e-12
        lo, hi = int(sr / fmax), int(sr / fmin)
        hi = min(hi, len(ac) - 2)
        if hi <= lo:
            out.append((i / sr, 0.0, 0.0))
            continue
        k0 = lo + int(np.argmax(ac[lo:hi]))
        v = float(ac[k0])
        a, b, c = ac[k0 - 1], ac[k0], ac[k0 + 1]
        denom = a - 2 * b + c
        k = k0 + (0.5 * (a - c) / denom if abs(denom) > 1e-12 else 0.0)
        k = min(max(k, lo), hi)
        out.append((i / sr, sr / k, v))
    return out


def judge(path):
    """Is this ONE note?  Returns (ok, hz, reason)."""
    x, sr = sf.read(path)
    if x.ndim > 1:
        x = x.mean(axis=1)
    tr = [(t, f, v) for t, f, v in f0_track(x, sr) if v > 0.45 and f > 0]
    if len(tr) < 8:
        return False, 0.0, 'unvoiced'
    f0 = np.array([f for _, f, _ in tr])
    med = float(np.median(f0))
    if med > 1100 or med < 70:
        return False, med, 'tracker at rail (%.0f Hz)' % med
    cents = 1200 * np.log2(f0 / med)
    stable = np.mean(np.abs(cents) < 80)
    if stable < 0.85:
        return False, med, 'melody (%.0f%% on pitch)' % (stable * 100)
    # the tracker can be fooled; the spectrum cannot.  A real held note has
    # its strongest partials at multiples of med -- demand that the top
    # spectral peak lies near a harmonic of the claimed f0.
    seg = x[len(x)//4:len(x)//2]
    X = np.abs(np.fft.rfft(seg))**2
    fr = np.fft.rfftfreq(len(seg), 1.0/sr)
    pk = float(fr[np.argmax(X[fr < 4000][:len(X)])]) if len(X) else 0.0
    if pk < 40:
        return False, med, 'spectral floor only (peak %.0f Hz)' % pk
    ratio = pk / med
    if abs(ratio - round(ratio)) > 0.12:
        return False, med, 'peak %.0f Hz not harmonic of %.0f' % (pk, med)
    return True, med, 'stable %.0f%%, peak %.0fHz' % (stable * 100, pk)


def midi_name(hz):
    m = int(round(69 + 12 * np.log2(hz / 440.0)))
    names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    return '%s%d' % (names[m % 12], m // 12 - 1), m


def trim(path, out_path):
    x, sr = sf.read(path)
    if x.ndim > 1:
        x = x.mean(axis=1)
    env = np.abs(x)
    k = int(0.02 * sr)
    env = np.convolve(env, np.ones(k) / k, 'same')
    thr = env.max() * 0.05
    idx = np.where(env > thr)[0]
    x = x[idx[0]:idx[-1]]
    f = int(0.03 * sr)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    sf.write(out_path, x.astype(np.float32), sr)
    return len(x) / sr


def main():
    inst = sys.argv[1]
    takes = int(sys.argv[2]) if len(sys.argv) > 2 else 6
    os.makedirs(os.path.join(OUTDIR, inst), exist_ok=True)
    kept = 0
    for t in range(takes):
        raw = '/tmp/mgnote_%s_%d.wav' % (inst, t)
        subprocess.run(GEN + [PROMPTS[inst], '--duration', '8',
                              '--temperature', '0.9', '-o', raw],
                       capture_output=True, check=True)
        ok, hz, why = judge(raw)
        if not ok:
            print('take %d: reject (%s)' % (t, why))
            continue
        name, m = midi_name(hz)
        dst = os.path.join(OUTDIR, inst, '%s_%s_t%d.wav' % (inst, name, t))
        dur = trim(raw, dst)
        kept += 1
        print('take %d: KEEP %s (%.1f Hz, %s, %.1fs) -> %s'
              % (t, name, hz, why, dur, os.path.basename(dst)))
    print('%s: kept %d/%d' % (inst, kept, takes))


if __name__ == '__main__':
    main()
