"""Find the newest rigging export and report what is in it.

The browser never overwrites: a second save is `rigging (1).json`, a twenty-third
is `rigging (23).json`. Those sort WRONG alphabetically -- "(9)" lands after
"(23)" -- so the file is chosen by modification time, which is the only ordering
that matches "the one saved last".

    python read_rig.py            summarise the newest
    python read_rig.py --all      list every export with its age
    python read_rig.py C:/some/dir   look somewhere else as well

A browser save does not always land in Downloads -- "save as" and a moved
default both put it on the Desktop -- so both are searched, newest wins, and a
directory named on the command line joins the search rather than replacing it.
"""
import glob
import io
import json
import os
import sys
import time

HOME = os.path.expanduser('~')
DIRS = [os.path.join(HOME, 'Downloads'), os.path.join(HOME, 'Desktop')]
SLOTS = ('weapon', 'system', 'utility')


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


def main(argv):
    extra = [a for a in argv if not a.startswith('-')]
    found = exports(extra)
    if not found:
        print('no rigging export yet in:')
        for d in extra + DIRS:
            print('  ' + d)
        return 1

    if '--all' in argv:
        print('%-28s %-12s %-8s %s' % ('file', 'saved', 'size', 'where'))
        for f in found:
            print('%-28s %-12s %-8s %s'
                  % (os.path.basename(f), age(os.path.getmtime(f)),
                     '%d B' % os.path.getsize(f), os.path.dirname(f)))
        print()

    newest = found[0]
    print('newest: %s  (%s)  in %s'
          % (os.path.basename(newest), age(os.path.getmtime(newest)),
             os.path.dirname(newest)))
    if len(found) > 1:
        print('        %d older export%s ignored'
              % (len(found) - 1, '' if len(found) == 2 else 's'))
    print()

    try:
        data = json.load(io.open(newest, encoding='utf-8'))
    except ValueError as e:
        print('NOT VALID JSON: %s' % e)
        return 1

    hulls = data.get('hulls') or {}
    print('version %s, clearance %s, %d hulls'
          % (data.get('version'), data.get('clearance'), len(hulls)))
    print()
    print('%-16s %-10s %-7s %-7s %-8s %s'
          % ('hull', 'canvas', 'weapon', 'system', 'utility', 'thrusters'))
    bad = []
    for name in sorted(hulls):
        h = hulls[name]
        cw, ch = h.get('canvas', [0, 0])
        for s in SLOTS:
            for x, y in h.get(s, []):
                if not (0 <= x < cw and 0 <= y < ch):
                    bad.append('%s %s (%d,%d) outside %dx%d'
                               % (name, s, x, y, cw, ch))
        th = h.get('thrusters', [])
        print('%-16s %-10s %-7d %-7d %-8d %s%s'
              % (name, '%dx%d' % (cw, ch), len(h.get('weapon', [])),
                 len(h.get('system', [])), len(h.get('utility', [])),
                 ', '.join('#%d at %d,%d' % (t['id'], t['x'], t['y'])
                           for t in th) or '-',
                 '' if h.get('edited') else '   (untouched)'))
    print()
    if bad:
        print('OUT OF BOUNDS:')
        for b in bad:
            print('  ' + b)
    else:
        print('every mount lands inside its sprite')
    edited = sum(1 for h in hulls.values() if h.get('edited'))
    print('%d of %d hulls edited' % (edited, len(hulls)))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
