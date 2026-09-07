"""Build a card-art REVIEW BENCH: every take beside the card it is for.

    python tools/bench.py <postdir> <title> <out.html> [notes.html]

The other half of `design_sheet.py`. The sheet approves a brief before anything
is generated; this looks at what came back. Takes are grouped by card, named
`<art_key>_<n>.png`, and each row is headed by the card as the game draws it
TODAY -- procedural glyph, real text, native 112x160 out of `-- cardshot`.

WHY THE CARD IS IN THE ROW. Four rounds were judged on bare 92x60 rectangles on
a contact sheet, and 21 of 23 takes were cut. The thing a candidate has to beat
is not the other candidates, it is the glyph already sitting in that window
under a name and three lines of rules text. Put the two side by side at the same
zoom and the comparison is the real one; leave the card out and it is a beauty
contest between strangers.

THREE VERDICTS, because the art director asked for a third: keep, STORE, cut.
Store is for a take that is wrong for its card and too good to delete -- it goes
to `tools/out/bank/` with its raw and its prompt, and Phase 8's ninety art-less
event options want exactly this shape. Cut is deletion, and a cut take is not
shown again: "if a card is cut you don't have to show it in the artifact".
"""

import base64
import json
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(ROOT, "tools", "out", "cardshot")
MANIFEST = os.path.join(ROOT, "tools", "out", "card_manifest.tsv")
CARD_SIZE = (112, 160)
ART_SIZE = (92, 60)

TAKE = re.compile(r"^(?P<key>.+)_(?P<n>\d+)\.png$")


def b64(p):
    return base64.b64encode(open(p, "rb").read()).decode()


def png_size(p):
    return struct.unpack(">II", open(p, "rb").read()[16:24])


def names():
    """art_key -> (card name, module, what it does), from ArtCheck's manifest."""
    out = {}
    if not os.path.exists(MANIFEST):
        return out
    with open(MANIFEST, encoding="utf-8") as fh:
        for line in fh:
            p = line.rstrip("\n").split("\t")
            if len(p) >= 10:
                out[p[0]] = (p[2], p[8], p[5])
    return out


def collect(postdir):
    """Group every take in a directory by the card it belongs to."""
    man = names()
    prompts = {}
    pj = os.path.join(postdir, "prompts.json")
    if os.path.exists(pj):
        prompts = json.load(open(pj, encoding="utf-8"))

    groups = {}
    for f in sorted(os.listdir(postdir)):
        m = TAKE.match(f)
        if not m:
            continue
        key, n = m.group("key"), int(m.group("n"))
        p = os.path.join(postdir, f)
        if png_size(p) != ART_SIZE:
            raise SystemExit("%s is not %dx%d" % (p, ART_SIZE[0], ART_SIZE[1]))
        pr = prompts.get(f[:-4], {})
        groups.setdefault(key, []).append({
            "id": f[:-4], "n": n, "img": b64(p),
            "prompt": pr.get("prompt", "") if isinstance(pr, dict) else pr,
        })

    out = []
    for key in sorted(groups, key=lambda k: (-len(groups[k]), k)):
        # A POOL ROW has no card. Takes named `pool_N` are not made for any
        # particular card -- they are generic scenes generated to be assigned
        # afterwards with `card_batch.py --install`, which is the art director's
        # idea after four cards in a row failed their own bespoke briefs. There
        # is nothing to photograph beside them, so the "on the card today" tile
        # is dropped rather than shown as a missing-shot placeholder.
        name, module, does = man.get(key, (key, "", ""))
        if key not in man:
            name, module, does = ("Pool", "unassigned scenes",
                                  "install onto any card with --install")
        shot = os.path.join(SHOTS, "%s.png" % key)
        card = ""
        if os.path.exists(shot):
            if png_size(shot) != CARD_SIZE:
                raise SystemExit("%s is not a native %dx%d cardshot"
                                 % (shot, CARD_SIZE[0], CARD_SIZE[1]))
            card = b64(shot)
        out.append({"key": key, "name": name, "module": module, "does": does,
                    "card": card,
                    "takes": sorted(groups[key], key=lambda t: t["n"])})
    return out


def main(argv):
    if len(argv) not in (3, 4):
        raise SystemExit("usage: bench.py <postdir> <title> <out.html> "
                         "[notes.html]")
    postdir, title, out = argv[:3]
    # WHAT I ALREADY SEE IN THE BATCH, optional and mine to write. A bench that
    # only asks "which do you like" wastes the one look the art director gives
    # it: if three takes break their own brief I should say so on the page
    # rather than let them be found.
    note = ""
    if len(argv) == 4:
        note = open(argv[3], encoding="utf-8").read()
    rows = collect(postdir)
    tmpl = open(os.path.join(ROOT, "tools", "bench.tmpl.html"),
                encoding="utf-8").read()
    page = (tmpl.replace("__TITLE__", title)
                .replace("__NOTE__", note)
                .replace("__DATA__", json.dumps(rows, ensure_ascii=False)))
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(page)
    n = sum(len(r["takes"]) for r in rows)
    print("%s: %d cards, %d takes, %d with a card shot -> %s"
          % (title, len(rows), n, sum(1 for r in rows if r["card"]), out))


if __name__ == "__main__":
    main(sys.argv[1:])
