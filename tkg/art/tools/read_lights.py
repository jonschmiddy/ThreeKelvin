"""Read the Light Placer's saves and, with --apply, write them into art/hull_grade.json.

    uv run python art/tools/read_lights.py lights.json                summarise
    uv run python art/tools/read_lights.py lights.json --apply [--all-hulls] [--dry-run]

READS THREE SHAPES. The page's `db` docs (collection "lights", one per hull) as a JSON
list of the docs or of {"id", "data"} rows, which is what Claude gets back from reading
the collection; one such doc on its own; or {key: entry} with hull_grade.json's own
arrays. A db doc cannot hold arrays of arrays, so the page stores each light as an
object: windows {x, y, w, h, kind?}, nav {x, y, kind}, markers {x, y, color, where}.

--apply replaces each hull's windows, nav and markers in hull_grade.json and keeps
everything else in its entry (band, chevrons, registry). Only hulls the page marked
edited are written unless --all-hulls; --dry-run prints the diff and writes nothing.
Every light is checked against its sprite first: inside it, and on an opaque pixel
(a 2x2 nav light on at least one), as HullGrade._lights paints only those. Run
`-- sheet=GradeSheet base=zero weight=<w>` after: the page draws the lights the
game's way, but the bake is the judge.
"""
import difflib
import io
import json
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.abspath(os.path.join(HERE, '..'))
PLACES = os.path.join(ART, 'hull_grade.json')
NAV = ('white', 'amber', 'beacon')
COLOURS = ('white', 'amber')
WHERE = ('hull', 'tip')
WINDOW_KINDS = ('', 'glass', 'pulse')


def alpha_of(path):
    """The sprite's alpha as rows of ints, read without pillow (8-bit RGBA or RGB PNGs)."""
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path + ' is not a PNG'
    i, idat, w = 8, b'', 0
    while i < len(data):
        n, kind = struct.unpack('>I4s', data[i:i + 8])
        body = data[i + 8:i + 8 + n]
        if kind == b'IHDR':
            w, h, depth, ctype = struct.unpack('>IIBB', body[:10])
            assert depth == 8 and ctype in (2, 6), path + ': only 8-bit RGB/RGBA'
            bpp = 4 if ctype == 6 else 3
        elif kind == b'IDAT':
            idat += body
        i += 12 + n
    raw, rows, prev, stride = zlib.decompress(idat), [], bytearray(w * bpp), w * bpp
    for y in range(h):
        f, line = raw[y * (stride + 1)], bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b, c = prev[x], prev[x - bpp] if x >= bpp else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b) & 255
            elif f == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append([line[x * bpp + 3] if bpp == 4 else 255 for x in range(w)])
        prev = line
    return w, h, rows


def _xy(p, *rest):
    """[x, y, ...] or {x, y, ...} -> [x, y] + the named fields in order."""
    if isinstance(p, dict):
        return [int(p['x']), int(p['y'])] + [p.get(k) for k in rest]
    return [int(p[0]), int(p[1])] + [p[2 + i] if len(p) > 2 + i else None for i in range(len(rest))]


def entry_of(r):
    """One doc or one hull_grade entry -> {windows, nav, markers} in hull_grade.json's arrays."""
    wins = []
    for w in r.get('windows', []):
        if isinstance(w, dict):
            e = [int(w['x']), int(w['y']), int(w['w']), int(w['h'])]
            kind = w.get('kind') or ''
        else:
            e, kind = [int(v) for v in w[:4]], (w[4] if len(w) > 4 else '')
        if kind:
            e.append(str(kind))
        wins.append(e)
    nav = [_xy(n, 'kind') for n in r.get('nav', [])]
    marks = [_xy(m, 'color', 'where') for m in r.get('markers', [])]
    return dict(windows=wins, nav=[[x, y, str(k)] for x, y, k in nav],
                markers=[[x, y, str(c), str(wh)] for x, y, c, wh in marks])


def hulls_of(data):
    """Any of the three shapes -> {key: {edited, windows, nav, markers}}."""
    if isinstance(data, list):
        rows = [r.get('data', r) if isinstance(r, dict) else {} for r in data]
    elif isinstance(data, dict) and 'key' in data:
        rows = [data]
    elif isinstance(data, dict):
        rows = [dict(v, key=k, edited=True) for k, v in data.items() if not k.startswith('_')]
    else:
        raise ValueError('not a list of lights docs or a {key: entry} table')
    out = {}
    for r in rows:
        if r.get('key'):
            out[r['key']] = dict(entry_of(r), edited=bool(r.get('edited', True)))
    return out


def problems(key, e):
    """Everything wrong with one hull's lights against its sprite."""
    path = os.path.join(ART, 'sprites', 'hulls', key + '.png')
    if not os.path.exists(path):
        return ['%s: no sprite at %s' % (key, path)]
    w, h, a = alpha_of(path)
    op = lambda x, y: 0 <= x < w and 0 <= y < h and a[y][x] > 0
    bad = []
    for b in e['windows']:
        if len(b) > 4 and b[4] not in WINDOW_KINDS:
            bad.append('window %s: kind must be glass or pulse' % b)
        if b[2] < 1 or b[3] < 1 or not any(op(b[0] + dx, b[1] + dy) for dx in range(b[2]) for dy in range(b[3])):
            bad.append('window %s lights nothing' % b)
    for x, y, k in e['nav']:
        if k not in NAV:
            bad.append('nav %d,%d: kind %r' % (x, y, k))
        if not any(op(x + dx, y + dy) for dx in (0, 1) for dy in (0, 1)):
            bad.append('nav %s %d,%d is off the hull' % (k, x, y))
    for x, y, c, wh in e['markers']:
        if c not in COLOURS or wh not in WHERE:
            bad.append('marker %d,%d: %r %r' % (x, y, c, wh))
        if not op(x, y):
            bad.append('marker %d,%d is off the hull (HullGrade skips it)' % (x, y))
    return ['%s: %s' % (key, b) for b in bad]


def apply(hulls, everything, dry):
    src = io.open(PLACES, encoding='utf-8', newline='').read()
    table = json.loads(src)
    changed = []
    for key in sorted(hulls):
        h = hulls[key]
        if not (everything or h['edited']):
            continue
        old = table.get(key, {})
        new = dict(old, windows=h['windows'], nav=h['nav'], markers=h['markers'])
        if new != old:
            table[key] = new
            changed.append(key)
    if not changed:
        print('hull_grade.json already says this; nothing to write')
        return 0
    out = json.dumps(table, indent=1) + '\n'
    sys.stdout.writelines(difflib.unified_diff(src.splitlines(True), out.splitlines(True),
                                               'hull_grade.json', 'hull_grade.json (lights applied)', n=0))
    if dry:
        print('\n--dry-run: %d hull%s would change, nothing written' % (len(changed), '' if len(changed) == 1 else 's'))
        return 0
    io.open(PLACES, 'w', encoding='utf-8', newline='').write(out)
    print('\nwrote %s' % ', '.join(changed))
    print('next: tools/dev/godot.sh --headless --path tkg -- sheet=GradeSheet base=zero weight=<w> out=<dir>')
    return 0


def main(argv):
    named = [a for a in argv if not a.startswith('-')]
    if not named:
        print(__doc__)
        return 1
    try:
        hulls = hulls_of(json.load(io.open(named[0], encoding='utf-8')))
    except (ValueError, KeyError, TypeError) as e:
        print('NOT READABLE: %s' % e)
        return 1
    print('%-26s %-8s %-5s %-8s %s' % ('hull', 'windows', 'nav', 'markers', ''))
    bad = []
    for key in sorted(hulls):
        h = hulls[key]
        print('%-26s %-8d %-5d %-8d %s' % (key, len(h['windows']), len(h['nav']), len(h['markers']),
                                           '' if h['edited'] else '(untouched)'))
        bad += problems(key, h)
    if bad:
        print('\nNOT WRITTEN, fix these first:')
        for b in bad:
            print('  ' + b)
        return 1
    print('\nevery light lands on its hull')
    if '--apply' in argv:
        print()
        return apply(hulls, '--all-hulls' in argv, '--dry-run' in argv)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
