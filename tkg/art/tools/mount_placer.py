"""Build the mount placer: a manufacturer's base hulls with their guns standing on them.

    python art/tools/mount_placer.py korvan --out mounts.html
    python art/tools/mount_placer.py korvan --guns-src DIR --out mounts.html
    python art/tools/mount_placer.py korvan --guns-src DIR1 --guns-src DIR2 --out mounts.html

The rig bench's sibling for hulls drawn as ONE base picture per weight (`DB.HULL_ART`,
Korvan's "zero" set) whose weapon mounts carry a side (`guns = [&"top", &"belly"]`).
It reads the same tables the rig bench does (the slot counts, `HULL_MOUNTS`,
`HULL_EXHAUST`) and adds what the bench cannot show:

- every weapon mount carries the gun's on-ship picture at its real size, its anchor on
  the mount exactly as `MountPoints.part_rect` puts it (top-left = point - anchor);
- a top/belly side per weapon mount; a gun with no drawing for that side shows its hold
  icon in the hold box, as the game does (and GunClipTest fails);
- gun boxes overlapping go red live, and the any-gun-on-any-mount check GunOverlapTest
  runs is run live, while dragging too: the grade with the most weapon mounts, every
  pair of weapon mounts on its own side, every weapon in the game on each as the GAME
  draws it (its installed picture, else its hold box), listing each clashing pair with
  its count and its deepest overlap in px;
- every system and utility mount carries the box its part is drawn in on the hull, cell
  grid and all: cells x `CELL_1X`, centred on the point (`ModuleIcon.mount_anchor`), the
  picture turned so its long axis matches the slot's (`part_turn`: systems lie wide,
  utilities stand tall). Any maker's part fits any hull, so each slot offers every
  distinct box across ALL its modules; the default draws the biggest ones (none inside
  another). Part boxes overlapping go red live. Guns paint over parts in the game, so a
  gun over a part box is not a fault;
- mounts are numbered in the order grades open them, with A and S marked;
- the page saves through the artifact `db` capability (collection `rigs`, one doc per
  hull) and through `downloads` (rigging-<manufacturer>.json, which `read_rig.py`
  finds); `read_rig.py --apply` writes either into `HULL_MOUNTS`.

The gun pictures are the ones `ship_guns.py` installs in art/sprites/guns (already 60%
of the drawn size). `--guns-src DIR` runs `ship_guns.install` on an artist's folder
into a temp folder first, so guns not yet installed can be tried on. Give it more than
once to merge folders (their gun_*.png and guns.json, a later folder winning a clash):
any maker's weapon with a picture is offered, grouped by maker. A picture only tried
on this way is drawn but not counted in the GunOverlapTest check: the test sees the
installed set, so a gun not installed is its hold box there.
"""

import base64
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pixeltools as pt
import rig_bench as rb

TEMPLATE = os.path.join(HERE, 'mount_placer.tmpl.html')
GUNS = os.path.join(rb.SPRITES, 'guns')
MODULES = os.path.join(rb.SPRITES, 'modules')
GRADES = ['C', 'B', 'A', 'S']
# HoldGrid.CELL / ModuleIcon.HOLD_K: one hold cell at the ship's 1x, as part_rect sizes a part
# with no on-ship picture (GAP is 0).
CELL_1X = 20
# A weapon's natural extent is long across (ModuleIcon.part_extent): a part turns when it is tall.
SIZES = {'SPINE': (4, 1), 'LONG': (3, 1), 'BULK': (2, 2), 'UNIT': (2, 1), 'FIT': (1, 1)}


def b64(path):
    return base64.b64encode(open(path, 'rb').read()).decode()


def hull_art(src, manufacturer):
    """`HULL_ART[manufacturer]`: {weight: base name}, or None."""
    m = re.search(r'const HULL_ART := \{(.*?)\n\}', src, re.S)
    assert m, 'HULL_ART not found'
    e = re.search(r'&"%s": \{(.*?)\}' % re.escape(manufacturer), m.group(1))
    if not e:
        return None
    return dict(re.findall(r'"(\w+)": "(\w+)"', e.group(1)))


def hull_names(src, manufacturer):
    m = re.search(r'&"%s": \{.*?names = \[(.*?)\]' % re.escape(manufacturer), src, re.S)
    return re.findall(r'"([^"]+)"', m.group(1)) if m else ['', '', '']


def mounts_table(src):
    """`HULL_MOUNTS` by key, sides included: the rig bench's reader skips `guns` and
    keys with a folder prefix ("solari/hull_light_zero")."""
    i = src.find('const HULL_MOUNTS')
    assert i >= 0, 'HULL_MOUNTS not found'
    blk = src[i:src.index('\n}\n', i)]
    out = {}
    for m in re.finditer(r'\t"((?:\w+/)?hull_\w+)": \{(.*?)\n\t\},', blk, re.S):
        e = {}
        for slot in rb.SLOTS:
            pts = re.search(r'\b' + slot + r' = \[(.*?)\],', m.group(2), re.S)
            e[slot] = ([[int(a), int(b)] for a, b in
                        re.findall(r'Vector2\((-?\d+), (-?\d+)\)', pts.group(1))] if pts else [])
        g = re.search(r'\bguns = \[(.*?)\],', m.group(2), re.S)
        e['guns'] = re.findall(r'&"(\w+)"', g.group(1)) if g else []
        out[m.group(1)] = e
    return out


def exhaust_table(src):
    """`HULL_EXHAUST` by key, prefixed keys too."""
    i = src.find('const HULL_EXHAUST')
    if i < 0:
        return {}
    blk = src[i:src.index('\n}\n', i)]
    out = {}
    for m in re.finditer(r'\t"((?:\w+/)?hull_\w+)": \[(.*?)\n\t\],', blk, re.S):
        out[m.group(1)] = [dict(id=int(e.group(1)), x=int(e.group(2)), y=int(e.group(3)),
                                back=e.group(4) == 'true')
                           for e in re.finditer(r'\{id = (\d+), at = Vector2i\((-?\d+), (-?\d+)\)'
                                                r'(?:, back = (true|false))?\}', m.group(2))]
    return out


def modules(src):
    """Every module: {id: (name, manufacturer, slot letter)}."""
    return {m.group(1): (m.group(2), m.group(3), m.group(4)) for m in re.finditer(
        r'_module\(&"(\w+)", "([^"]+)", &"(\w*)", ([WSU]),', src)}


def module_sizes(src, mods):
    """`_seed_module_sizes`, in cells: the named lists, else the slot's default."""
    i = src.find('func _seed_module_sizes')
    assert i >= 0, '_seed_module_sizes not found'
    blk = src[i:src.find('\nfunc ', i + 10)]

    def ids(var):
        m = re.search(r'var %s: Array\[StringName\] = \[(.*?)\]' % var, blk, re.S)
        assert m, '_seed_module_sizes has no %s' % var
        return set(re.findall(r'&"(\w+)"', m.group(1)))
    spinal, long_ones, bulky, units = ids('spinal'), ids('long_ones'), ids('bulky'), ids('util_units')
    out = {}
    for mid, (_n, _mf, slot) in mods.items():
        out[mid] = (SIZES['SPINE'] if mid in spinal else SIZES['LONG'] if mid in long_ones
                    else SIZES['BULK'] if mid in bulky else SIZES['UNIT'] if mid in units
                    else SIZES['FIT'] if slot == 'U' else SIZES['UNIT'])
    return out


def hold_box(f):
    """`MountPoints.part_rect` for a weapon with no on-ship picture, at 1x: size and anchor."""
    w, h = f[0] * CELL_1X, f[1] * CELL_1X
    turned = f[0] != f[1] and f[1] > f[0]
    ax, ay = (w * 0.5, h - CELL_1X * 0.5) if turned else (CELL_1X * 0.5, h * 0.5)
    return dict(w=w, h=h, ax=ax, ay=ay)


def slot_counts(src, manufacturer, weight):
    """Per slot, the count at each grade as the game builds it: `_manufacturer_hull` floors
    the weight's base plus the manufacturer's delta at 1, then `at_tier` adds TIER_DELTA."""
    base, tier = rb.weight_base(src)[weight], rb.tier_delta(src)
    mk = rb.manufacturer_delta(src, manufacturer)
    out = {}
    for s in rb.SLOTS:
        b = max(1, base[s] + mk[s])
        out[s] = [b + tier[c][s] for c in rb.CLASSES]
    return out


def column_edges(path):
    """Per column, the first opaque row and the row under the last: where a top gun's
    anchor and a belly gun's anchor sit on this hull (HULL_MOUNTS' own convention)."""
    w, h, rows = pt.decode(path)
    top, bot = [], []
    for x in range(w):
        ys = [y for y in range(h) if rows[y][x * 4 + 3] > 25]
        top.append(ys[0] if ys else -1)
        bot.append(ys[-1] + 1 if ys else -1)
    return w, h, top, bot


def installed():
    """What the game draws, per gun and side: {id: {side: {w, h, ax, ay}}} from art/sprites/guns."""
    path = os.path.join(GUNS, 'guns.json')
    if not os.path.exists(path):
        return {}
    out = {}
    for gid, sides in json.load(io.open(path, encoding='utf-8')).items():
        for side, e in sides.items():
            p = os.path.join(GUNS, e['file'])
            if os.path.exists(p):
                w, h, _r = pt.decode(p)
                out.setdefault(gid, {})[side] = dict(w=w, h=h, ax=e['anchor'][0], ay=e['anchor'][1])
    return out


def guns(src, manufacturer, gun_dir):
    """Every weapon with an on-ship picture, any maker's: this manufacturer's first, then
    the other makers', then the makerless ones. `game`: the installed picture's box per
    side, which is what GunOverlapTest measures."""
    mods = modules(src)
    sizes = module_sizes(src, mods)
    table = json.load(io.open(os.path.join(gun_dir, 'guns.json'), encoding='utf-8'))
    game = installed()
    out = []

    def order(gid):
        mf = mods[gid][1]
        return (0 if mf == manufacturer else 2 if mf == '' else 1, mf, gid)
    for gid in sorted((g for g in table if not g.startswith('_') and g in mods), key=order):
        name, mf, slot = mods[gid]
        if slot != 'W':
            continue
        sides = {}
        for side, e in table[gid].items():
            p = os.path.join(gun_dir, e['file'])
            if not os.path.exists(p):
                continue
            w, h, _r = pt.decode(p)
            sides[side] = dict(img=b64(p), w=w, h=h, ax=e['anchor'][0], ay=e['anchor'][1])
        if not sides:
            continue
        icon = os.path.join(MODULES, gid + '.png')
        out.append(dict(id=gid, name=name, maker=mf, sides=sides, hold=hold_box(sizes[gid]),
                        icon=b64(icon) if os.path.exists(icon) else '', game=game.get(gid, {})))
    # (GunOverlapTest tries every weapon in the game on every mount: the ones with no
    # picture stand on it as their hold box, so each distinct box is checked too)
    drawn = {g['id'] for g in out}
    boxes = {}
    for mid, (name, _mf, slot) in sorted(mods.items()):
        if slot != 'W' or mid in drawn:
            continue
        hb = hold_box(sizes[mid])
        boxes.setdefault((hb['w'], hb['h'], hb['ax'], hb['ay']), []).append(mid)
    others = [dict(w=k[0], h=k[1], ax=k[2], ay=k[3], ids=v) for k, v in sorted(boxes.items())]
    n_weapons = sum(1 for _n, _mf, s in mods.values() if s == 'W')
    return out, others, n_weapons


def footprints(src):
    """Per non-weapon slot, every distinct box its parts are drawn in on the hull, at 1x.

    `MountPoints.part_rect` sizes the part's rect cells x CELL_1X, unturned, and centres it
    on the point; `ModuleIcon.draw_sprite` turns the picture inside it about that centre
    when `part_turn` says so (a utility's long axis is down, a system's across). The
    picture is what shows, so the box here is the turned one: a 2x1 utility is 20 x 40.
    `max`: no other box of the slot holds this one."""
    mods = modules(src)
    sizes = module_sizes(src, mods)
    found = {'system': {}, 'utility': {}}
    for mid, (name, _mf, slot) in sorted(mods.items()):
        if slot not in 'SU':
            continue
        f = sizes[mid]
        # part_turn: the system's natural extent is wide, the utility's tall
        turn = f[0] != f[1] and ((f[1] > f[0]) != (slot == 'U'))
        cols, rows = (f[1], f[0]) if turn else f
        e = found['system' if slot == 'S' else 'utility'].setdefault((cols, rows), dict(
            cells=list(f), cols=cols, rows=rows, w=cols * CELL_1X, h=rows * CELL_1X,
            turned=turn, ids=[], names=[]))
        e['ids'].append(mid)
        e['names'].append(name)
    out = {}
    for S, d in found.items():
        L = sorted(d.values(), key=lambda e: (-e['w'] * e['h'], -e['w'], -e['h']))
        for e in L:
            e['max'] = not any(o is not e and o['w'] >= e['w'] and o['h'] >= e['h'] for o in L)
        out[S] = L
    return out


def hints(src, manufacturer):
    """The manufacturer's own system and utility parts, for the faded hint icons."""
    mods = modules(src)
    sizes = module_sizes(src, mods)
    out = {'system': [], 'utility': []}
    for mid, (name, mf, slot) in mods.items():
        if mf != manufacturer or slot not in 'SU':
            continue
        p = os.path.join(MODULES, mid + '.png')
        if os.path.exists(p):
            out['system' if slot == 'S' else 'utility'].append(
                dict(id=mid, name=name, f=list(sizes[mid]), img=b64(p)))
    return out


def collect(manufacturer, gun_dir):
    src = rb.gd()
    art = hull_art(src, manufacturer)
    if not art:
        raise SystemExit('"%s" has no HULL_ART entry: the placer is for one base picture per weight'
                         % manufacturer)
    folder = os.path.join(rb.SPRITES, 'hulls', manufacturer)
    prefix = '' if manufacturer == 'korvan' else manufacturer + '/'
    placed, plumes, names = mounts_table(src), exhaust_table(src), hull_names(src, manufacturer)
    hulls = []
    for wi, weight in enumerate(rb.WEIGHTS):
        if weight not in art:
            continue
        name = 'hull_%s_%s' % (weight, art[weight])
        key = prefix + name
        png = os.path.join(folder, name + '.png')
        if not os.path.exists(png):
            raise SystemExit('HULL_ART names %s but %s is missing' % (key, png))
        w, h, top, bot = column_edges(png)
        counts = slot_counts(src, manufacturer, weight)
        rig = placed.get(key, {s: [] for s in rb.SLOTS + ['guns']})
        seed = {s: [list(p) for p in rig[s]] for s in rb.SLOTS}
        sides = list(rig['guns'])
        # a weapon point with no side said is a top one, as the hull's mounts start on the deck
        sides += ['top'] * (len(seed['weapon']) - len(sides))
        seed['guns'] = sides[:len(seed['weapon'])]
        for s in rb.SLOTS:
            want = counts[s][-1]
            if len(seed[s]) < want:
                seed[s] += [[w // 2, h // 2] for _ in range(want - len(seed[s]))]
                if s == 'weapon':
                    seed['guns'] += ['top'] * (want - len(seed['guns']))
        hulls.append(dict(key=key, name=name, weight=weight, title=names[wi] if wi < len(names) else '',
                          w=w, h=h, img=b64(png), top=top, bot=bot, counts=counts, seed=seed,
                          exs=plumes.get(key, []), rigged=key in placed))
    exh = os.path.join(rb.SPRITES, 'exhaust')
    exhausts = {}
    for f in os.listdir(exh):
        m = re.match(r'exhaust_(\d+)\.png$', f)
        if m:
            ww, hh, _r = pt.decode(os.path.join(exh, f))
            exhausts[m.group(1)] = dict(fw=ww // rb.FRAMES, h=hh, sw=ww, img=b64(os.path.join(exh, f)))
    used = {str(t['id']) for hl in hulls for t in hl['exs']}
    gl, others, n_weapons = guns(src, manufacturer, gun_dir)
    return dict(manufacturer=manufacturer, art=art, hulls=hulls, guns=gl, others=others,
                n_weapons=n_weapons, hints=hints(src, manufacturer), parts=footprints(src),
                exhausts={k: v for k, v in exhausts.items() if k in used},
                frames=rb.FRAMES, grades=GRADES)


def merge_sources(dirs, into):
    """The artists' folders as one: gun_*.png copied, guns.json merged (a later folder
    wins a clash). Copies only; the sources are not touched."""
    spec = {}
    for d in dirs:
        part = json.load(io.open(os.path.join(d, 'guns.json'), encoding='utf-8'))
        for gid, e in part.items():
            if gid in spec and not gid.startswith('_'):
                print('  %s is in more than one --guns-src: %s wins' % (gid, d))
            spec[gid] = e
        for f in os.listdir(d):
            if re.match(r'gun_\w+\.png$', f):
                shutil.copy2(os.path.join(d, f), os.path.join(into, f))
    io.open(os.path.join(into, 'guns.json'), 'w', encoding='utf-8').write(json.dumps(spec, indent=1))
    return spec


def build(manufacturer, out_path, guns_src=None):
    if isinstance(guns_src, str):
        guns_src = [guns_src]
    tmp = None
    gun_dir = GUNS
    if guns_src:
        import ship_guns   # needs pillow and numpy: uv run --with pillow --with numpy
        tmp = tempfile.mkdtemp(prefix='placer-guns-')
        src_dir, gun_dir = os.path.join(tmp, 'src'), os.path.join(tmp, 'out')
        os.makedirs(src_dir)
        merge_sources(guns_src, src_dir)
        ship_guns.OUT = gun_dir
        ship_guns.install(src_dir)
    try:
        data = collect(manufacturer, gun_dir)
    finally:
        if tmp:
            shutil.rmtree(tmp, ignore_errors=True)
    html = io.open(TEMPLATE, encoding='utf-8').read()
    html = html.replace('__DATA__', json.dumps(data, separators=(',', ':')))
    html = html.replace('__MANUFACTURER_LC__', manufacturer)
    html = html.replace('__MANUFACTURER__', manufacturer.capitalize())
    io.open(out_path, 'w', encoding='utf-8', newline='').write(html)

    # A syntax error in the page script is silent: the page draws and nothing works.
    # (no node on the PC: then open the page once in a browser and read its console)
    if shutil.which('node'):
        js = re.search(r'<script>(.*)</script>', html, re.S).group(1)
        chk = os.path.join(os.path.dirname(os.path.abspath(out_path)), '_check.js')
        io.open(chk, 'w', encoding='utf-8', newline='').write(js)
        r = subprocess.run(['node', '--check', chk], capture_output=True, text=True)
        os.remove(chk)
        if r.returncode != 0:
            raise SystemExit('PAGE SCRIPT DOES NOT PARSE\n' + r.stderr)
    else:
        print('  no node here: the page script is not syntax-checked')
    print('%s: %d hulls (%s), %d guns (%s), %d other weapon boxes, part boxes %s, %d mounts -> %s (%.0f KB)'
          % (manufacturer, len(data['hulls']), ', '.join(h['key'] for h in data['hulls']),
             len(data['guns']), ', '.join(g['id'] + ('' if g['game'] else '(not installed)') for g in data['guns']),
             len(data['others']),
             '; '.join(S + ' ' + ', '.join('%dx%d%s' % (e['w'], e['h'], '!' if e['max'] else '')
                                           for e in L) for S, L in data['parts'].items()),
             sum(len(h['seed'][s]) for h in data['hulls'] for s in rb.SLOTS), out_path,
             len(html) / 1024.0))


def main(argv):
    if not argv or argv[0].startswith('-'):
        print(__doc__)
        return 1
    out = 'mount-placer-%s.html' % argv[0]
    if '--out' in argv:
        out = argv[argv.index('--out') + 1]
    srcs = [argv[i + 1] for i, a in enumerate(argv[:-1]) if a == '--guns-src']
    build(argv[0], out, srcs or None)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
