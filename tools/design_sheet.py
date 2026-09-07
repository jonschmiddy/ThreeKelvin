"""Build a card-art DESIGN SHEET: one approvable brief per card, before a
single generation is spent.

    python tools/design_sheet.py tools/briefs/weapons.json out.html

WHY THIS EXISTS. Rounds 3 and 4 spent 31 generations on five cards and kept
none of them, and the post-mortem was not "the pictures were bad" -- every take
was competent pixel art. It was that four of the five cards had been briefed as
the same picture. `CardData.gd` had already written that failure down about the
procedural glyphs ("a hand of eight was two pictures") and the illustrations
walked into it again.

A generation is the expensive place to discover a brief is wrong. A sentence is
the cheap place. So the brief is now the reviewable artifact, and nothing is
generated until the sheet comes back approved.

THE BRIEF IS TWO THINGS AND A DIRECTION, which is the rule the accepted
illustrations were reverse-engineered from: an ACTOR, a thing it is ACTING ON,
and the moment between them. "A gun firing" fails the rule -- it names an actor
and nothing to act on, which is why six drafts of it all looked the same. Every
row here has to fill both halves or it does not go in the sheet.

COLLISION IS THE THING BEING CHECKED. The sheet is built per SET (a glyph family
-- the 15 brace cards, the 16 malfunctions) rather than per module, because a
family is exactly where the collisions live: fifteen cards that all mean "take
less damage" will all be briefed as a plate unless they are written side by side
and forced apart. The sheet prints the actors together so a repeat is visible.

The manifest columns are ArtCheck's (`-- artcheck cards`), which is the game's
own answer to what each card is, not a second taxonomy invented here.
"""

import base64
import html
import json
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "tools", "out", "card_manifest.tsv")
SHOTS = os.path.join(ROOT, "tools", "out", "cardshot")

# ArtCheck's column order. Named rather than indexed at the call sites: this
# file is read by whoever has to add a column to the manifest next.
COLS = ["key", "state", "name", "glyph", "type", "does",
        "manufacturer", "from", "module", "flavour"]


## THE WORLD EVERY CARD IS IN, and it is not a per-card decision.
##
## Twenty takes at Full Auto came back as a WWII factory -- brass, grating, a
## gloved hand, oily steel -- and the note was "these should be spaceship and
## space opera themed you know?". They should, and `docs/design-doc.md` had
## already said how, in a section I had not read before writing a single prompt.
## Quoting it rather than paraphrasing, because the paraphrase is what went
## wrong:
##
##   "The void is never flat black. Deep indigo-to-black dithered gradients with
##   nebula wash coloured per region... Korvan space rusty amber."
##
##   "Objects are genuinely lush. Weathered plating, stencilled hull numbers,
##   decals, lit viewports with tiny interior detail... Spend the pixel budget
##   here."
##
##   "Warm/cold survives as lighting logic, not a saturation cap. Objects are
##   richly coloured but COLDLY LIT, with warm rim light from your own reactor
##   and engines. Your heat glow reads because it is the only SELF-EMITTED
##   warmth in frame."
##
##   "Melancholy comes from composition: small ship, vast frame, generous
##   negative space."
##
## An industrial interior is not disqualified -- the game's tone is named as
## "lush-cold industrial" against Cobalt Core's "linear cartoon brightness". But
## it has to be industry IN SPACE: a viewport with the void outside it, a nebula
## wash instead of a black ground, cold ambient with one warm self-emitted
## source. That is the difference between a bomber's belly and a starship's.
HOUSE = ("industry in space, not on Earth: the void is never flat black but a "
         "dithered indigo with a rusty amber nebula wash; a lit viewport or an "
         "open bay with the dark outside it wherever the picture is an "
         "interior; everything coldly lit with the only warm light "
         "self-emitted -- reactor glow, heat, a cutting arc; weathered plating "
         "with stencilled numbers and decals")


def manifest():
    """Every card in art scope, keyed by art_key."""
    out = {}
    with open(MANIFEST, encoding="utf-8") as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < len(COLS):
                continue
            row = dict(zip(COLS, parts))
            out[row["key"]] = row
    return out


def shot(key):
    """The card as the game draws it today, native 112x160, base64.

    Missing is not an error -- a set can be sheeted before its shots are taken,
    and a sheet with a gap is more useful than no sheet. It IS worth saying so
    on the page, which is what the empty string ends up doing.
    """
    p = os.path.join(SHOTS, "%s.png" % key)
    if not os.path.exists(p):
        return ""
    raw = open(p, "rb").read()
    w, h = struct.unpack(">II", raw[16:24])
    if (w, h) != (112, 160):
        raise SystemExit("%s is %dx%d, expected a native 112x160 cardshot"
                         % (p, w, h))
    return base64.b64encode(raw).decode()


def esc(s):
    return html.escape(s or "", quote=False)


def build(spec):
    man = manifest()
    rows = []
    seen_actor = {}
    for c in spec["cards"]:
        key = c["id"]
        if key not in man:
            raise SystemExit("no card %r in the manifest -- rerun "
                             "`-- artcheck cards`" % key)
        m = man[key]
        if m["state"] == "DONE" and not c.get("redo"):
            raise SystemExit("%s already has art; set \"redo\": true to "
                             "brief it again" % key)
        # A BRIEF MAY NOT ACT ON ITSELF. Of eight briefs in the first set,
        # exactly one answered "acting on" with "itself" -- and that one card
        # then failed 21 straight takes while the other seven produced usable
        # art. The reviewer's words for the result were "most of these are just
        # handguns": with no second thing in the frame there is nothing to give
        # the subject scale, so the generator draws the object as an ITEM
        # SPRITE, which is what a gun with nothing around it looks like.
        #
        # "One object alone, beautifully rendered and about nothing" is the
        # exact failure the two-things rule exists to prevent, and writing
        # "itself" in this column is how it gets past the rule while appearing
        # to satisfy it. So it is refused here rather than discovered later.
        a = c["actor"].strip().lower()
        on = c["on"].strip().lower()
        if on.startswith("itself") or on == a:
            raise SystemExit("%s acts on itself. A brief needs a SECOND thing "
                             "-- something the actor is doing this to. Without "
                             "one the generator draws an object portrait at no "
                             "particular scale." % key)
        # THE COLLISION CHECK, and the only thing this script asserts. Two rows
        # in one set naming the same actor is the exact failure that cost 31
        # generations, and it is trivially detectable before anything is spent.
        if a in seen_actor:
            raise SystemExit("collision: %r and %r are both briefed as %r"
                             % (seen_actor[a], key, c["actor"]))
        seen_actor[a] = key
        rows.append({
            "key": key,
            "name": m["name"],
            "module": m["module"],
            "flavour": m["flavour"],
            "does": m["does"],
            "glyph": m["glyph"],
            "type": m["type"],
            "maker": m["manufacturer"],
            "actor": c["actor"],
            "on": c["on"],
            "moment": c["moment"],
            # WHAT SIZES IT. Optional, but the answer to the only review note
            # that has ever killed a whole eighteen-take round: "most of these
            # are just handguns". A 92x60 frame carries no scale of its own, so
            # unless something in it has a known size the generator is free to
            # draw a starship weapon as a pistol, and it will -- pixel-art guns
            # are overwhelmingly handheld item sprites.
            "scale": c.get("scale", ""),
            # The house style, on every row, because it is not per-card and
            # forgetting it once cost twenty takes.
            "world": c.get("world", HOUSE),
            "avoid": c.get("avoid", ""),
            "shot": shot(key),
        })
    return rows


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__.strip().splitlines()[2].strip())
    spec = json.load(open(sys.argv[1], encoding="utf-8"))
    rows = build(spec)
    tmpl = open(os.path.join(ROOT, "tools", "design_sheet.tmpl.html"),
                encoding="utf-8").read()
    page = (tmpl
            .replace("__SET__", esc(spec["set"]))
            .replace("__LEDE__", spec["lede"])
            .replace("__DATA__", json.dumps(rows, ensure_ascii=False)))
    with open(sys.argv[2], "w", encoding="utf-8", newline="\n") as fh:
        fh.write(page)
    print("%s: %d briefs, %d with a card shot -> %s"
          % (spec["set"], len(rows), sum(1 for r in rows if r["shot"]),
             sys.argv[2]))


if __name__ == "__main__":
    main()
