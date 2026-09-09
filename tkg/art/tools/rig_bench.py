"""Build the rigging bench for a manufacturer's hulls.

    python art/tools/rig_bench.py korvan
    python art/tools/rig_bench.py solari --out /tmp/solari-bench.html

Produces a self-contained page: every hull that manufacturer has art for, every exhaust
strip in the library, mounts you drag, thrusters you drop, alignment snapping,
and a `rigging.json` save. Nothing is hardcoded to one manufacturer -- the folder, the
hull list, the slot counts and the seed positions are all read from the repo.

WHY A TOOL AND NOT A ONE-OFF. Rigging is not a thing you do once. Every manufacturer
that gains art needs the same pass, and the numbers that drive it move
underneath: WEIGHT_BASE sets a slot count, TIER_DELTA adds to it at A and S, and
six of the seven manufacturers change it again. A page built by hand against Korvan's
numbers would be quietly wrong for Probate, which trades a weapon for a utility.
So the counts are PARSED from Database.gd, and this file fails loudly if the
shape it expects has moved rather than guessing.

WHAT IT SEEDS FROM. Mounts open on `DB.HULL_LINES` run through the real
`mounts_along()`, so a manufacturer whose lines are already measured opens on the status
quo. A manufacturer with art but no lines yet opens with its mounts spread evenly down
the middle -- something to drag, rather than nothing.

The page saves through the `downloads` capability; read the result back with
`art/tools/read_rig.py`.
"""

import base64
import io
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pixeltools as pt

TKG = os.path.abspath(os.path.join(HERE, '..', '..'))
SPRITES = os.path.join(TKG, 'art', 'sprites')
DB = os.path.join(TKG, 'scripts', 'autoload', 'Database.gd')
TEMPLATE = os.path.join(HERE, 'rig_bench.tmpl.html')
FRAMES = 9
WEIGHTS = ['light', 'medium', 'heavy']
CLASSES = ['c', 'b', 'a', 's']          # HullData.TIER_NAMES, lowercased
SLOTS = ['weapon', 'system', 'utility']


def gd():
    return io.open(DB, encoding='utf-8').read()


def weight_base(src):
    """`weapon_slots` / `system_slots` / `utility_slots` per weight."""
    out = {}
    for w in WEIGHTS:
        m = re.search(r'HullData\.Weight\.%s: \{(.*?)\}' % w.upper(), src, re.S)
        assert m, 'WEIGHT_BASE has no %s entry' % w
        blk = m.group(1)
        got = {}
        for s in SLOTS:
            n = re.search(r'%s_slots = (\d+)' % s, blk)
            assert n, 'WEIGHT_BASE.%s has no %s_slots' % (w, s)
            got[s] = int(n.group(1))
        out[w] = got
    return out


def tier_delta(src):
    """Per class, what TIER_DELTA adds. Utility is never moved by tier."""
    m = re.search(r'const TIER_DELTA := \[(.*?)\n\]', src, re.S)
    assert m, 'TIER_DELTA not found'
    rows = re.findall(r'\{(.*?)\}', m.group(1), re.S)
    assert len(rows) == len(CLASSES), 'TIER_DELTA is %d rows, expected %d' % (
        len(rows), len(CLASSES))
    out = {}
    for cls, row in zip(CLASSES, rows):
        out[cls] = {
            'weapon': int(re.search(r'weapon = (-?\d+)', row).group(1)),
            'system': int(re.search(r'system = (-?\d+)', row).group(1)),
            'utility': 0,
        }
    return out


def manufacturer_delta(src, manufacturer):
    """A manufacturer's own slot changes, if it has any.

    Entries do NOT end on a predictable line, so a lazy `.*?` hunting for a
    closing brace runs straight past this manufacturer into the next one -- which is
    how Korvan first came back carrying Probate's `weapon_slots = -1`, and every
    manufacturer came back with identical deltas. Cut the block at the next entry
    instead, and read only inside its own `d = {...}`.
    """
    m = re.search(r'const MANUFACTURER_HULLS := \{(.*?)\n\}', src, re.S)
    assert m, 'MANUFACTURER_HULLS not found'
    body = m.group(1)
    start = body.find('&"%s":' % manufacturer)
    if start < 0:
        return {s: 0 for s in SLOTS}
    nxt = re.search(r'\n\t&"', body[start:])
    blk = body[start:start + nxt.start()] if nxt else body[start:]
    dm = re.search(r'\bd = \{(.*?)\}', blk, re.S)
    assert dm, 'manufacturer "%s" has no d = {...}' % manufacturer
    out = {}
    for s in SLOTS:
        n = re.search(r'%s_slots = (-?\d+)' % s, dm.group(1))
        out[s] = int(n.group(1)) if n else 0
    return out


def hull_lines(src):
    """The measured lines, by hull art name."""
    i = src.find('const HULL_LINES')
    if i < 0:
        return {}
    blk = src[i:src.index('\n}\n', i)]
    out = {}
    for m in re.finditer(r'"(hull_\w+)": \{(.*?)\n\t\},', blk, re.S):
        e = {}
        for line in ('dorsal', 'ventral', 'flank'):
            pts = re.search(line + r' = \[(.*?)\],', m.group(2), re.S)
            e[line] = ([[int(a), int(b)] for a, b in
                        re.findall(r'Vector2\((-?\d+), (-?\d+)\)', pts.group(1))]
                       if pts else [])
        out[m.group(1)] = e
    return out


def mounts_along(line, n):
    """HullData.mounts_along(), used once to seed the editor."""
    if n <= 0 or not line:
        return []
    if len(line) == 1:
        return [list(line[0]) for _ in range(n)]
    out = []
    for i in range(n):
        t = (i + 0.5) / n
        f = t * (len(line) - 1)
        a = min(int(f), len(line) - 2)
        r = f - a
        out.append([int(round(line[a][0] + (line[a + 1][0] - line[a][0]) * r)),
                    int(round(line[a][1] + (line[a + 1][1] - line[a][1]) * r))])
    return out


def spread(w, h, n, frac):
    """Fallback seed for a hull with art but no measured line yet."""
    if n <= 0:
        return []
    y = int(round(h * frac))
    return [[int(round(w * (i + 0.5) / n)), y] for i in range(n)]


def b64(path):
    return base64.b64encode(open(path, 'rb').read()).decode()


def collect(manufacturer):
    src = gd()
    base, tier, mk = weight_base(src), tier_delta(src), manufacturer_delta(src, manufacturer)
    lines = hull_lines(src)
    folder = os.path.join(SPRITES, 'hulls', manufacturer)
    if not os.path.isdir(folder):
        raise SystemExit('no hull art for "%s" -- expected %s' % (manufacturer, folder))

    hulls = []
    for weight in WEIGHTS:
        for cls in CLASSES:
            name = 'hull_%s_%s' % (weight, cls)
            png = os.path.join(folder, name + '.png')
            if not os.path.exists(png):
                continue
            w, h, _rows = pt.decode(png)
            need = {s: max(0, base[weight][s] + tier[cls][s] + mk[s])
                    for s in SLOTS}
            ln = lines.get(name)
            if ln:
                seed = {'weapon': mounts_along(ln['dorsal'], need['weapon']),
                        'system': mounts_along(ln['ventral'], need['system']),
                        'utility': mounts_along(ln['flank'], need['utility'])}
            else:
                seed = {'weapon': spread(w, h, need['weapon'], 0.30),
                        'system': spread(w, h, need['system'], 0.72),
                        'utility': spread(w, h, need['utility'], 0.50)}
            hulls.append(dict(name=name, weight=weight, cls=cls.upper(),
                              w=w, h=h, img=b64(png), need=need, seed=seed,
                              measured=bool(ln)))
    if not hulls:
        raise SystemExit('"%s" has a folder but no hull_*_*.png in it' % manufacturer)

    exh = os.path.join(SPRITES, 'exhaust')
    exhausts = []
    for i in sorted(int(m.group(1)) for m in
                    (re.match(r'exhaust_(\d+)\.png$', f)
                     for f in os.listdir(exh)) if m):
        p = os.path.join(exh, 'exhaust_%d.png' % i)
        ww, hh, _r = pt.decode(p)
        fw = ww // FRAMES
        k = min(76.0 / fw, 44.0 / hh, 1.0)
        exhausts.append(dict(id=i, fw=fw, h=hh, sw=ww, img=b64(p),
                             tw=int(round(fw * k)), th=int(round(hh * k)),
                             tsw=int(round(ww * k))))
    return hulls, exhausts, mk


def build(manufacturer, out_path):
    hulls, exhausts, mk = collect(manufacturer)
    html = io.open(TEMPLATE, encoding='utf-8').read()
    html = html.replace('__DATA__', json.dumps(
        dict(hulls=hulls, exhausts=exhausts, n=FRAMES, manufacturer=manufacturer)))
    html = html.replace('__MANUFACTURER__', manufacturer)
    io.open(out_path, 'w', encoding='utf-8', newline='').write(html)

    # A syntax error in the page script is SILENT -- the browser drops the whole
    # block and the page looks fine except that nothing works. Never ship one.
    js = re.search(r'<script>(.*)</script>', html, re.S).group(1)
    chk = os.path.join(os.path.dirname(os.path.abspath(out_path)), '_check.js')
    io.open(chk, 'w', encoding='utf-8', newline='').write(js)
    r = subprocess.run(['node', '--check', chk], capture_output=True, text=True)
    os.remove(chk)
    if r.returncode != 0:
        raise SystemExit('PAGE SCRIPT DOES NOT PARSE\n' + r.stderr)

    seeded = sum(len(h['seed'][s]) for h in hulls for s in SLOTS)
    unmeasured = [h['name'] for h in hulls if not h['measured']]
    print('%s: %d hulls, %d mounts, %d thrusters -> %s (%.0f KB)'
          % (manufacturer, len(hulls), seeded, len(exhausts), out_path,
             len(html) / 1024.0))
    if any(mk.values()):
        print('  manufacturer slot delta: %s'
              % ', '.join('%s %+d' % (k, v) for k, v in mk.items() if v))
    if unmeasured:
        print('  no measured lines yet, seeded evenly: %s'
              % ', '.join(unmeasured))


def main(argv):
    if not argv or argv[0].startswith('-'):
        print(__doc__)
        return 1
    manufacturer = argv[0]
    out = 'rigging-bench-%s.html' % manufacturer
    if '--out' in argv:
        out = argv[argv.index('--out') + 1]
    build(manufacturer, out)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
