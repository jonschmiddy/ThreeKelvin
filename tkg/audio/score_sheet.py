"""Draw a cue as a conductor's score.

    python3 score_sheet.py <cue.py> [--out sheet.svg]

The scores in this directory are written like extracted parts -- a tune is a
named list, placed into time by reference -- which is good for composing and
bad for the one thing a conductor's book is for: putting a finger on bar 23
and seeing what every player does at that instant.  This renders that view:
systems of 8 bars per row ("pages"), one lane per stem, pitch as height,
rests visible as the white space they actually are.

It captures by instrumenting the render, same trick as motif_audit.py but
wider: every pitched voice logs (frequency, duration), chord voices log each
constituent, and the unpitched set (kick, snare, hat, heart, impact, the
swells and air) logs as percussion ticks on a single line.
"""
import os, runpy, sys
from collections import defaultdict

import numpy as np

PITCHED = ['whistle', 'whistle_bend', 'reed', 'glass', 'bell', 'hammer',
           'pluck', 'blade', 'bowed', 'metal', 'organ', 'sub', 'drone']
CHORDAL = ['pad', 'strings', 'cluster']
PERC = ['kick', 'snare', 'hat', 'heart', 'impact', 'noise_swell',
        'rev_swell', 'air']

LANE_COLORS = ['#3a6ea5', '#a5533a', '#3aa56e', '#8a5aa5', '#a5913a',
               '#5aa5a0', '#a53a70', '#6e7a3a', '#4a4a8a', '#8a6a4a']


class _Ev(np.ndarray):
    """An ndarray that remembers what note it is.

    The scores cache instrument calls -- `_h[k] = hammer(f, d, 1.0)` once,
    then `_h[k]*amp` forty times -- so hooking the instrument call sees one
    event where the piece has forty.  The placement is the `Track.add`, and
    the only thing that survives from the call to the add, through caches
    and `*amp` and slices, is the ARRAY.  So the array carries the metadata:
    numpy propagates the subclass (and `__array_finalize__` the attribute)
    through arithmetic, which is exactly the path a cached note travels.
    """
    _meta = None

    def __array_finalize__(self, obj):
        if obj is not None and getattr(obj, '_meta', None) is not None:
            self._meta = obj._meta


def capture(script):
    import synth
    notes = defaultdict(list)
    originals = {}

    def wrap(name, kind):
        fn = getattr(synth, name, None)
        if fn is None:
            return
        def g(*a, **k):
            y = np.asarray(fn(*a, **k)).view(_Ev)
            if kind == 'pitched':
                f = a[0]; d = a[1] if len(a) > 1 else k.get('dur', 0.5)
                y._meta = [('note', float(f), float(d))]
            elif kind == 'chord':
                d = a[1] if len(a) > 1 else k.get('dur', 1.0)
                y._meta = [('note', float(f), float(d)) for f in a[0]]
            else:
                d = a[1] if len(a) > 1 and isinstance(a[1], (int, float)) \
                    else k.get('dur', 0.3)
                y._meta = [('perc', name, float(d) if d else 0.3)]
            return y
        originals[name] = fn
        setattr(synth, name, g)

    for n in PITCHED:
        wrap(n, 'pitched')
    for n in CHORDAL:
        wrap(n, 'chord')
    for n in PERC:
        wrap(n, 'perc')

    orig_add = synth.Track.add

    def add(self, x, at_beat, pan=0.0, gain=1.0):
        for ev in (getattr(x, '_meta', None) or []):
            notes[id(self)].append((float(at_beat),) + ev)
        return orig_add(self, x, at_beat, pan, gain)

    synth.Track.add = add
    try:
        g = runpy.run_path(script, run_name='__sheet__')
        spb = synth.SPB                # durations are logged in SECONDS
        names = {}
        for d in g.values():
            if isinstance(d, dict):
                for k, v in d.items():
                    if isinstance(v, synth.Track):
                        names[id(v)] = str(k)
        fixed = {names.get(k, '?'):
                 [(b, kd, a, d/spb) for b, kd, a, d in v]   # -> beats
                 for k, v in notes.items()}
        return fixed, g.get('BARS', 48)
    finally:
        synth.Track.add = orig_add
        for n, fn in originals.items():
            setattr(synth, n, fn)


def midi_of(f):
    return 69 + 12*np.log2(max(1e-6, f)/440.0)


def render_svg(stems, bars, title, path, per_system=8):
    LANE_H, GAP, LEFT, BARW = 46, 10, 92, 96
    systems = int(np.ceil(bars/per_system))
    order = [k for k in stems if stems[k]]
    W = LEFT + per_system*BARW + 20
    sys_h = len(order)*(LANE_H+4) + 34
    H = 46 + systems*(sys_h + GAP)
    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
           'font-family="Georgia,serif">' % (W, H),
           '<rect width="100%" height="100%" fill="#faf7f0"/>',
           '<text x="%d" y="26" font-size="17" fill="#222">%s</text>'
           % (LEFT, title)]
    # per-lane pitch range for vertical scaling
    rng = {}
    for k in order:
        ms = [midi_of(f) for _, kind, f, d in
              [(b, e0, e1, e2) for b, e0, e1, e2 in stems[k]] if kind == 'note']
        rng[k] = (min(ms), max(ms)) if ms else (0, 1)
    for si in range(systems):
        top = 40 + si*(sys_h + GAP)
        b0 = si*per_system            # first bar of the system, 0-based
        out.append('<text x="8" y="%d" font-size="11" fill="#888">bar %d</text>'
                   % (top+12, b0+1))
        for li, k in enumerate(order):
            y0 = top + 18 + li*(LANE_H+4)
            out.append('<rect x="%d" y="%d" width="%d" height="%d" '
                       'fill="#ffffff" stroke="#ddd"/>' %
                       (LEFT, y0, per_system*BARW, LANE_H))
            out.append('<text x="%d" y="%d" font-size="11" fill="#555" '
                       'text-anchor="end">%s</text>' % (LEFT-6, y0+LANE_H/2+4, k))
            for bar in range(per_system+1):
                x = LEFT + bar*BARW
                out.append('<line x1="%d" y1="%d" x2="%d" y2="%d" '
                           'stroke="#eee"/>' % (x, y0, x, y0+LANE_H))
            col = LANE_COLORS[li % len(LANE_COLORS)]
            lo, hi = rng[k]
            span = max(4.0, hi-lo)
            for beat, kind, a, d in stems[k]:
                bar = beat/4.0
                if not (b0 <= bar < b0+per_system):
                    continue
                x = LEFT + (bar-b0)*BARW
                if kind == 'note':
                    m = midi_of(a)
                    y = y0 + LANE_H - 6 - (m-lo)/span*(LANE_H-12)
                    w = max(3, d/4.0*BARW - 1)
                    out.append('<rect x="%.1f" y="%.1f" width="%.1f" '
                               'height="4" rx="2" fill="%s" opacity="0.85"/>'
                               % (x, y, w, col))
                else:
                    out.append('<circle cx="%.1f" cy="%.1f" r="2.6" '
                               'fill="%s" opacity="0.6"/>'
                               % (x, y0+LANE_H-8, col))
    out.append('</svg>')
    open(path, 'w').write('\n'.join(out))
    return path


if __name__ == '__main__':
    script = sys.argv[1]
    out = sys.argv[sys.argv.index('--out')+1] if '--out' in sys.argv else \
        script.replace('.py', '_sheet.svg')
    stems, bars = capture(script)
    name = os.path.basename(script)[:-3]
    render_svg(stems, bars, '"%s" -- %d bars' % (name, bars), out)
    n = sum(len(v) for v in stems.values())
    print('%s: %d events across %d stems -> %s' % (name, n, len(stems), out))
