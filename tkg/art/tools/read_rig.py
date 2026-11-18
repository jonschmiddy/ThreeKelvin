"""Find the newest rigging export, report what is in it, and optionally write it into the game.

The browser never overwrites: a second save is `rigging (1).json`, a twenty-third
is `rigging (23).json`. Those sort WRONG alphabetically -- "(9)" lands after
"(23)" -- so the file is chosen by modification time, which is the only ordering
that matches "the one saved last".

    python read_rig.py                 summarise the newest
    python read_rig.py --all           list every export with its age
    python read_rig.py C:/some/dir     look somewhere else as well
    python read_rig.py rigs.json       read this file, not the newest
    python read_rig.py rigs.json --apply [--all-hulls] [--dry-run]
                                       write its mounts into HULL_MOUNTS in Database.gd

A browser save does not always land in Downloads -- "save as" and a moved
default both put it on the Desktop -- so both are searched, newest wins, and a
directory named on the command line joins the search rather than replacing it.

READS THREE SHAPES. The rig bench's and the mount placer's download
(`rigging.json`, `rigging-korvan.json`: {"hulls": {key: {...}}}), and the mount
placer's `db` docs (collection "rigs", one per hull), as a JSON list of the docs
or of {"id", "data"} rows -- what Claude gets back from reading the collection.
Points may be [x, y] or {"x", "y"} (a db doc cannot hold arrays of arrays).

--apply replaces each hull's entry in `HULL_MOUNTS` (weapon, guns when the export
has them, system, utility), or adds it before the table's end. Only hulls the
page marked edited are written unless --all-hulls is given; --dry-run prints the
diff and writes nothing. Run `-- sheet=GunOverlapTest` and the `-- mounts` check
after: the page runs the overlap rule, but the game is the judge.
"""
import difflib
import glob
import io
import json
import os
import re
import sys
import time

HOME = os.path.expanduser('~')
DIRS = [os.path.join(HOME, 'Downloads'), os.path.join(HOME, 'Desktop')]
SLOTS = ('weapon', 'system', 'utility')
HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.abspath(os.path.join(HERE, '..', '..', 'scripts', 'autoload', 'Database.gd'))


def exports(extra=()):
    found = []
    for d in list(extra) + DIRS:
        found += glob.glob(os.path.join(d, 'rigging*.json'))
    return sorted(set(found), key=os.path.getmtime, reverse=True)


def age(sec):
    d = time.time() - sec
    if d < 90:
        return '%ds ago' % int(d)
    if d < 5400:
        return '%dm ago' % int(d / 60)
    return '%.1fh ago' % (d / 3600.0)


def points(a):
    return [[int(p['x']), int(p['y'])] if isinstance(p, dict) else [int(p[0]), int(p[1])]
            for p in (a or [])]


def hulls_of(data):
    """Any of the three shapes -> {key: {canvas, edited, weapon, guns?, system, utility, thrusters}}."""
    if isinstance(data, dict) and 'hulls' in data:
        rows = [dict(h, key=h.get('key', k)) for k, h in data['hulls'].items()]
    elif isinstance(data, list):
        rows = [r.get('data', r) if isinstance(r, dict) else {} for r in data]
    elif isinstance(data, dict) and 'key' in data:
        rows = [data]
    else:
        raise ValueError('not a rigging export or a list of rigs docs')
    out = {}
    for r in rows:
        key = r.get('key')
        if not key:
            continue
        c = r.get('canvas', [0, 0])
        h = dict(canvas=[int(c['w']), int(c['h'])] if isinstance(c, dict) else [int(c[0]), int(c[1])],
                 edited=bool(r.get('edited')), thrusters=r.get('thrusters', []))
        for s in SLOTS:
            h[s] = points(r.get(s))
        if 'guns' in r:
            h['guns'] = [str(g) for g in r['guns']]
        out[key] = h
    return out


def entry(key, h):
    """One `HULL_MOUNTS` entry, in Database.gd's own layout."""
    v = lambda a: '[%s]' % ', '.join('Vector2(%d, %d)' % (x, y) for x, y in a)
    lines = ['\t"%s": {' % key, '\t\tweapon = %s,' % v(h['weapon'])]
    if h.get('guns'):
        lines.append('\t\tguns = [%s],' % ', '.join('&"%s"' % g for g in h['guns']))
    lines += ['\t\tsystem = %s,' % v(h['system']), '\t\tutility = %s,' % v(h['utility']), '\t},']
    return '\n'.join(lines)


def apply(hulls, everything, dry):
    src = io.open(DB, encoding='utf-8', newline='').read()
    i = src.find('const HULL_MOUNTS := {')
    if i < 0:
        print('HULL_MOUNTS not found in %s' % DB)
        return 1
    j = src.index('\n}\n', i)
    table = src[i:j]
    changed = []
    for key in sorted(hulls):
        h = hulls[key]
        if not (everything or h['edited']):
            continue
        if 'guns' in h and len(h['guns']) != len(h['weapon']):
            print('%s: %d weapon points but %d sides, not written' % (key, len(h['weapon']), len(h['guns'])))
            continue
        bad = [s for s in h.get('guns', []) if s not in ('top', 'belly')]
        if bad:
            print('%s: sides must be top or belly, got %s; not written' % (key, bad))
            continue
        new = entry(key, h)
        m = re.search(r'\t"%s": \{\n.*?\n\t\},' % re.escape(key), table, re.S)
        if m:
            if m.group(0) == new:
                continue
            table = table[:m.start()] + new + table[m.end():]
        else:
            table = table + '\n' + new
        changed.append(key)
    if not changed:
        print('HULL_MOUNTS already says this; nothing to write')
        return 0
    out = src[:i] + table + src[j:]
    sys.stdout.writelines(difflib.unified_diff(src.splitlines(True), out.splitlines(True),
                                               'Database.gd', 'Database.gd (rig applied)', n=0))
    if dry:
        print('\n--dry-run: %d hull%s would change, nothing written' % (len(changed), '' if len(changed) == 1 else 's'))
        return 0
    io.open(DB, 'w', encoding='utf-8', newline='').write(out)
    print('\nwrote %s to %s' % (', '.join(changed), DB))
    print('next: tools/dev/godot.sh --headless --path tkg -- sheet=GunOverlapTest, and the -- mounts check')
    return 0


def main(argv):
    named = [a for a in argv if not a.startswith('-') and a.lower().endswith('.json')]
    extra = [a for a in argv if not a.startswith('-') and a not in named]
    if named:
        found = named
    else:
        found = exports(extra)
    if not found:
        print('no rigging export yet in:')
        for d in extra + DIRS:
            print('  ' + d)
        return 1

    if '--all' in argv and not named:
        print('%-28s %-12s %-8s %s' % ('file', 'saved', 'size', 'where'))
        for f in found:
            print('%-28s %-12s %-8s %s'
                  % (os.path.basename(f), age(os.path.getmtime(f)),
                     '%d B' % os.path.getsize(f), os.path.dirname(f)))
        print()

    newest = found[0]
    print('%s: %s  (%s)  in %s'
          % ('reading' if named else 'newest', os.path.basename(newest),
             age(os.path.getmtime(newest)), os.path.dirname(os.path.abspath(newest))))
    if len(found) > 1 and not named:
        print('        %d older export%s ignored'
              % (len(found) - 1, '' if len(found) == 2 else 's'))
    print()

    try:
        data = json.load(io.open(newest, encoding='utf-8'))
        hulls = hulls_of(data)
    except ValueError as e:
        print('NOT READABLE: %s' % e)
        return 1

    if isinstance(data, dict) and 'hulls' in data:
        print('version %s, %s%d hulls'
              % (data.get('version'), 'clearance %s, ' % data['clearance'] if 'clearance' in data else '',
                 len(hulls)))
    else:
        print('%d rigs docs' % len(hulls))
    print()
    print('%-20s %-10s %-7s %-7s %-8s %-26s %s'
          % ('hull', 'canvas', 'weapon', 'system', 'utility', 'sides', 'thrusters'))
    bad = []
    for name in sorted(hulls):
        h = hulls[name]
        cw, ch = h['canvas']
        for s in SLOTS:
            for x, y in h[s]:
                # (a belly gun's point is the row under the hull, so y may equal the height)
                if not (0 <= x < cw and 0 <= y <= ch):
                    bad.append('%s %s (%d,%d) outside %dx%d' % (name, s, x, y, cw, ch))
        th = h.get('thrusters', [])
        print('%-20s %-10s %-7d %-7d %-8d %-26s %s%s'
              % (name, '%dx%d' % (cw, ch), len(h['weapon']), len(h['system']), len(h['utility']),
                 ','.join(h.get('guns', [])) or '-',
                 ', '.join('#%d at %d,%d' % (t['id'], t['x'], t['y']) for t in th) or '-',
                 '' if h['edited'] else '   (untouched)'))
    print()
    if bad:
        print('OUT OF BOUNDS:')
        for b in bad:
            print('  ' + b)
    else:
        print('every mount lands inside its sprite')
    edited = sum(1 for h in hulls.values() if h['edited'])
    print('%d of %d hulls edited' % (edited, len(hulls)))
    if '--apply' in argv:
        print()
        return apply(hulls, '--all-hulls' in argv, '--dry-run' in argv)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
