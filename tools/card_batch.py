# -*- coding: utf-8 -*-
"""Take generated card art from raw PNG to shipping illustration.

    python tools/card_batch.py --post <indir> <outdir>
    python tools/card_batch.py --bank <outdir> <take> "<why>"
    python tools/card_batch.py --install <src.png> <card_key>
    python tools/card_batch.py --wanted
    python tools/card_batch.py --palette

THE CARD PIPELINE IS NOT THE MODULE PIPELINE, and the difference is one line:
a module is a SPRITE and a card illustration is a PICTURE. Modules are cut out
of their background and centred in a box; cards are full-bleed, 92x60, opaque to
the last pixel. So there is no strip_bg here, no despeckle, no trim and no fit --
stripping the background off a picture whose background IS the art would eat the
starfield, and the five that shipped are 100% opaque by measurement.

    92x60 AND NOT 93x60. `create_image_pixflux` refuses an odd side at this
    size and answers 93x60 with "Use 92x60 instead", which `ArtCheck` records
    at its CARD_ART constant. The window is 93 wide, so the art is generated one
    column short and centred -- half a pixel of margin against a recessed dark
    box, which nothing can see.

NO REDUCTION EITHER. Every module is generated at 2x its box because every
module box is under PixelLab's floor of 1024 px of area. A card is 5520 and
clears it comfortably, so card art is generated at exactly the size it ships
and never resampled. That is the whole reason card art escaped the entire
scale_to_box / expand_box argument the modules needed.

THE PALETTE IS THE UNION OF THE FIVE THAT SHIPPED, for the same reason the
module palette is the union of the six accepted modules: the tone is decided
once, off art somebody actually liked, and every later batch lands on it instead
of hoping the generator repeats itself. Twenty-nine colours, twenty-one of them
shared with the module ramp -- which is what makes a card and the part that
grants it look like two things from one game.

SNAPPED WITH THE SAME NO-CROSSING RULE modules use. A card illustration is cold
steel with a hot muzzle flash in it, so a blanket snap to the nearest colour
would drag greys into the flash and flash into the greys. `module_batch`'s
`snap_split` already implements exactly this and is imported rather than copied.
WHAT A CARD ILLUSTRATION HAS TO BE, learned by having twenty-one of
twenty-three generations cut and asking rather than guessing a third time.

  THE PRO MODEL WILL LETTERBOX AN OBJECT ON WHITE even with
  `no_background=false`, if the prompt describes a thing with nothing around it.
  Two brace prompts ending "the violet the only colour" and "cold blue light
  only" came back 75% white in all eight candidates -- the model read them as an
  asset request rather than a scene. Cards are FULL BLEED, so a prompt must
  always say what fills the rest of the frame: stars, a nebula wash, more of the
  same plating. `--post` cannot fix this; the pixels are simply white.
    Worth measuring rather than eyeballing, because 9-16% white is legitimate
  frost or ice and 70%+ is a letterbox. CHECK THE EDGES SEPARATELY: one take
  shipped with a five-column white bar down its left side, 8% of the frame,
  which sailed under a whole-image threshold. A column or row that is more than
  half near-white is a bar whatever the total says. Repairing it is a five-pixel
  edge extension, not a regeneration.

  AND THE EDGE COLUMNS ARE WHERE A STRAY PIXEL HIDES. Slag shipped with one
  pixel of its own brightest colour, (167,195,199), alone at (91,49) in a field
  of (23,27,34) -- the last column. It was in the raw, so the generator made it;
  it survived review because a local-maximum scan written as `range(1, w - 1)`
  never looks at x=0 or x=w-1. Scan the border, and clamp the neighbourhood
  instead of skipping the pixel. ONE stray pixel IS the case where copying a
  neighbour is right; the no-hand-repair rule below is about regions.

  NEVER ASK FOR LETTERING. Hairline came back with three lines of garbled
  stencil text across a blank panel, and the prompt that made it says "Rivets
  and STENCILLED LETTERING around it" -- the boilerplate `scale` and `world`
  fields of every malfunction brief asked for it, so 191 takes were generated
  requesting text. This is `name-the-parts-never-the-category` again from the
  other side: naming a thing gets you the thing, and the thing here is glyphs
  the model cannot spell.
    "NOTHING" IS A WORD THAT PRODUCES WHITE, and so is any other way of naming
  an absence. Unmade asked for debris "thinning away to NOTHING" and all four
  takes drew nothing as blank white canvas, three of them tripping the
  border-connected check. Jon: "the background is totally white. Shouldn't it be
  something else?" -- and it should, because a card is full bleed and opaque and
  white is only ever undrawn.
    This is the letterbox rule again, one level down. It is not enough to
  describe what fills the frame AROUND the subject; anywhere the picture says a
  thing STOPS, ends, dissolves, fades or runs out, the prompt has to say what
  is there afterwards. Name the far side positively -- void, starfield, nebula,
  more plating -- and never leave the generator to draw an absence, because the
  only absence it has is the empty canvas.

  IT IS NOT THE WORD ALONE, IT IS THE WORD PLUS ROOM. Of the eleven shipped
  cards whose prompt asked for lettering, dross reads "SECTOR-4 / WASTE" and
  deadcell reads "UNIT 4", both clean, because both sit as a short tag on a
  small crowded surface. Hairline had a wide flat empty panel in the middle of
  the frame and the model filled it with three long lines. So the second half of
  the fix is compositional: say the frame is crowded to every edge with no blank
  surface, and there is nowhere for text to go even if it wants to write some.

  THE STYLE IMAGE CARRIES DENSITY TOO, and that turned out to matter more than
  shape. Nine of 68 malfunctions landed off `full_auto`, a dense plated
  stencilled close-up. One of 28 brace cards landed off `auspice` and
  `sympathetic_burst`, which are single objects in empty space -- and eight of
  those 28 came back letterboxed on white. Re-firing the same six briefs against
  `lattice` and `hairline`, both dense and both accepted the same day, filled
  every frame. A sparse reference makes sparse pictures however the prompt reads.

  THE STYLE IMAGE CARRIES COMPOSITION, NOT JUST COLOUR -- so choose it for
  SHAPE. Eight takes of Walking Fire from one prompt idea: four with `auspice`
  as the style reference came back as a bright diagonal line with a ring at the
  end, which is auspice's own layout and has no craft in it at all. Four with
  `rack_and_load` -- picked because it is several distinct objects spaced along
  a line, which is what the card needed -- came back as a craft with a row of
  separate hits along its length, first time in thirty takes.
    So `style_copy` is not a filter over colours. Pick the accepted card whose
  STRUCTURE matches the new card, not the most recent or the prettiest one. The
  cost to watch for: the result also inherits the reference's palette, so a
  warm reference makes a warm picture whatever the prompt says about cold light.

  USE THE PRO MODEL WITH A STYLE IMAGE. `docs/art/PIXELLAB_WORKFLOW.md` gives a
  two-step recipe for every asset in this game and card art used NEITHER half of
  it for roughly 250 generations: iterate cheaply with `create_image_pixflux`
  passing an `init_image_url` (download URLs need no auth and feed straight back
  in) sweeping `init_image_strength` 140-240, THEN finish with
  `create_image_pro`, `style_image_*` pointed at an approved asset and
  `style_copy` on all four aspects. Pro returns FOUR candidates per call at
  92x60 for 20 generations, which is better value than 20 cold pixflux rolls.
    Every card take before that point was a cold text-to-image roll with no
  reference at all, so nothing ever built on the last result and nothing was
  anchored to art that had already been accepted. The first four pro calls
  produced usable rows for three cards that had failed 21, 25 and 54 takes.
  The doc's own words about the approved asset: "That file is now the style
  reference for every future generation." Read that file before generating.

  DO NOT HAND-REPAIR PIXELS -- USE `inpaint_image`. Slag came back with a
  stencil in a corner that had to go. Repainting it from neighbouring pixels
  twice produced exactly what the art director then described: "it's just a box
  covering the text", because copying a neighbour along a row smears a flat
  patch. The same technique had already left a five-pixel smear down the edge
  of Full Auto.
    `inpaint_image` regenerates one rectangle in context and freezes every
  pixel outside it -- 20 generations, and the machinery continues through the
  hole instead of being papered over. It is named in PIXELLAB_WORKFLOW.md as
  "fix specific problems, don't regenerate" and was ignored twice before being
  tried once.
    Keep the raw. Both repairs were made ON the raw, so the untouched original
  was only recoverable because the PixelLab job was still live; a day later it
  would have been gone.

  IT IS A SPACE OPERA AND THE PICTURE HAS TO BE IN SPACE. Twenty takes at Full
  Auto returned a WWII factory -- brass, deck grating, a gloved hand, oily steel
  -- and the note was "these should be spaceship and space opera themed you
  know?". `docs/design-doc.md` had already said how, in a section nobody had
  read before writing a card prompt: the void is never flat black but dithered
  indigo with a nebula wash (Korvan space rusty amber); objects are lush and
  weathered with stencilled numbers, decals and LIT VIEWPORTS; everything is
  COLDLY LIT with the only warm light self-emitted -- reactor, heat, an arc.
    Industrial is not the problem; the tone is named "lush-cold industrial"
  against Cobalt Core's "linear cartoon brightness". The problem is industry on
  EARTH. An interior needs a viewport with the dark outside it, or a bay open to
  the void, or a nebula wash instead of a black ground. Read that section before
  writing prompts, not after twenty of them.

  TWO THINGS IN RELATIONSHIP. Every illustration that survived has an actor and
  a subject with direction between them: a beam and the rock it is cutting, a
  reticle and the ship inside it, a gun and the station it is firing over. Every
  one that was cut is ONE OBJECT ALONE -- a barrel, a slug, a breech, floating
  in the dark, beautifully rendered and about nothing. The art director's words
  were "the ones I kept are storytelling; the ones I rejected are disembodied,
  no story, no direction".

  This is not the same as "busy". Two rounds were lost to that misreading: the
  first asked for restraint and got empty frames, the second asked for close
  detailed machinery and got cluttered ones. Neither is the axis. A picture of
  one thing is wrong however much or little is in it.

  SMOKE AND HAZE ARE FINE. Three takes were flagged in review as "a rocket in
  an atmosphere, not vacuum" on the grounds that a plume should not billow where
  there is no air. The art director kept one of them. Physics is not the test
  here; the picture is. Do not fence out drifting smoke, dust or haze -- they
  give a flat starfield depth, and the objection was invented rather than
  observed.

  SAY VACUUM, NOT NAVY. "A long-barrelled naval gun on a warship's flank" came
  back as a battleship at sea, wake and all. The words warship, naval, flank and
  broadside all pull toward water; starship, vacuum and starfield do not.
    HULL AND VESSEL ARE ON THE LIST TOO, added after a prompt containing no
  banned word at all -- "a heavy weapon mount set into the side of a vast
  starship... hull plating filling the lower half of the frame" -- came back as
  a grey battleship on an ocean under clouds. "Starship" in the same sentence
  did not save it. Prefer starship, plating, armour, deck and mount; treat hull
  and vessel as water words.
    AND "SHELL" PULLS TOWARD GROUND. Two takes in a batch containing no banned
  word put the subject on a rocky floor, one of them with a staircase behind it.
  Three separate words have now imported a setting nobody asked for -- naval,
  hull, shell -- so this is not a blacklist to be finished but a habit to keep:
  name the thing by what it is DOING (a round in flight, a bolt crossing) rather
  than by the object noun, because an object noun arrives with a ground under it.

  SAY BORES, NOT BARREL OR CANNON -- and in general, prefer the noun for the
  PART OF THE OBJECT the composition is about over the noun for the object. Of
  twelve takes at Ripple Fire whose prompts said "barrel" or "cannon", EIGHT
  came back as a side-on hero gun with a muzzle flash and two of those put it on
  the ground with a horizon, in flat contradiction of an approved brief that said
  not to. Six more that said "bores" and never "barrel" produced no horizon, no
  side-on portrait and no flash in any of them. Same brief, same card, same
  reviewer; one noun.
    This is the same failure as "say vacuum, not navy" one paragraph up and it
  generalises: a word arrives with its own most-common picture attached, and
  that picture beats the sentence around it. When a brief keeps losing to the
  generator, suspect the nouns before rewriting the brief.

  "ROUND" DRAWS A BALL. Nine of twelve takes asking for "a heavy round" on a
  chain returned a SPHERE hanging in a doorway. The word was chosen because
  "shell" is banned for dragging in a rocky floor, and it turns out to be read
  as the adjective rather than the noun. Say cartridge, canister or projectile
  -- unambiguously a long thing. Same class as the category-noun rule below,
  from the other direction: not a word that means something too big, but a word
  whose commonest sense is the wrong part of speech.

  NEVER SAY "GUN" OR "WEAPON" IN A PROMPT. Twelve takes at Full Auto asked for
  a feed mechanism; the three prompts that used the word "weapon" or "gun"
  returned a rifle, a pistol and a rifle, and none of the nine that avoided both
  did. Eight more with the two words banned outright returned ZERO firearms.
  Say machinery, belt, links, brass, breech block, feed housing -- the parts,
  never the category. Third time this has been the whole answer, after
  "bores, not barrel" and "vacuum, not navy".

  A 92x60 FRAME HAS NO SCALE OF ITS OWN, so something in it must have a known
  size or the generator picks one. Eighteen takes at Ripple Fire were reviewed
  as "most of these are just handguns" -- the subject was a starship weapon and
  it kept arriving as a personal firearm, because pixel-art guns are
  overwhelmingly handheld ITEM SPRITES and nothing in the frame said otherwise.
  Put a hull running out of the frame, a deck, a distant ship, anything with an
  unarguable size, in every brief whose subject is an object.
    This is the same bug as briefing a card to act on ITSELF, and on that card
  it was the same brief: one object alone in a void is both storyless AND
  scaleless. `design_sheet.py` refuses "itself" in the acting-on column now, and
  every brief carries a "sized by" line.

  ROUND THINGS AT SEVERAL DISTANCES ON A STARFIELD ARE PLANETS. Asking for
  three rounds in flight receding toward a small distant target produced, five
  times in twelve, a planet with moons -- and once an asteroid belt. The
  arrangement IS the arrangement of a solar system, and a starfield behind it
  settles the reading. If a card needs several objects at several depths in
  space, give them shapes that cannot be spherical (a tapered body, a trailing
  glow) or put them against something that is not stars.

  NAME WHAT IS BEING DONE TO. The card is a verb -- Clear the Breech, Walking
  Fire, Cold Read -- so the prompt needs the object of that verb in it, or the
  generator draws the noun and stops.
"""
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixeltools as pt  # noqa: E402
import module_batch as mb  # noqa: E402

CARDS = os.path.join("tkg", "art", "sprites", "cards")
SIZE = (92, 60)

## The illustrations that were accepted. THE TONE COMES FROM THESE and nothing
## else. `cold_read` is in the list deliberately even though it is the odd one
## out -- a reticle over a ship rather than a gun firing -- because a palette
## drawn only from muzzle flashes would have no vocabulary for a card that is
## not a weapon, and forty of the seventy-one left are not.
ACCEPTED = ["charged_slug", "cold_read", "drumfire", "siege_round",
            "suppressing_fire"]


def card_palette():
    """The five accepted illustrations, PLUS the module ramp.

    The five alone are twenty-nine colours and only FOUR of them are usable
    warms: #4c1613, #c4300e, #bf9a33, #d6b043 -- luminance 39, 86, 132, 152.
    That is a hole from 86 to 132 exactly where a flame lives, so every mid
    orange the generator produced landed on gold by nearest-RGB and the first
    probe came back with mustard beams. Correct arithmetic, wrong ramp.

    The module palette has fourteen warms in a smooth ladder: 34, 39, 56, 57,
    68, 69, 73, 85, 90, 101, 108, 118, 131, 152. Taking the union fills the
    flame and costs nothing in tone -- twenty-one of the twenty-nine card
    colours were already module colours, which is what made a card and the part
    that grants it look like one game in the first place.

    Sixty-one colours, sixteen of them warm.
    """
    seen = []
    for name in ACCEPTED:
        p = os.path.join(CARDS, name + ".png")
        if not os.path.exists(p):
            continue
        w, h, rows = pt.decode(p)
        for c in pt.palette(w, h, rows):
            if c not in seen:
                seen.append(c)
    for c in mb.module_palette():
        if c not in seen:
            seen.append(c)
    return seen


## How far from grey a pixel must be before its HUE is worth protecting.
##
## `module_batch.is_warm` is `r > b + 12`, which is the right test on a sprite
## and the wrong one on an illustration. A white-hot muzzle core is about
## #fff5e0: red does beat blue, so it classifies as warm, and the nearest warm
## colour on a palette whose hottest entry is #d6b043 is GOLD. Measured on the
## first probe -- every beam, spark and flash came back mustard, and the raw
## generation it came from was fine.
##
## The warm/cold split exists to stop STEEL migrating into an accent. A
## near-white highlight is not steel being pulled into an accent; it is a
## highlight, and it belongs to whichever palette entry is closest. So a pixel
## only counts as warm if it is also SATURATED: max channel minus min channel.
## #fff5e0 is 31 and #d6b043 is 147, with the cold ramp all under 35.
CHROMA = 45


def _warm(c):
    return mb.is_warm(c) and (max(c) - min(c)) >= CHROMA


def post_one(src, pal):
    """Raw generation -> shipping illustration. Returns (w, h, rows, report)."""
    w, h, rows = pt.decode(src)
    cold = [c for c in pal if not _warm(c)]
    warm = [c for c in pal if _warm(c)]
    drift, hot = _snap_split(w, h, rows, cold, warm)
    # OPAQUE TO THE EDGE. The generator is asked for a scene rather than a
    # sprite, but a stray transparent pixel in a full-bleed illustration draws
    # as a hole in the card, so anything not fully opaque is filled with the
    # darkest colour on the palette rather than left to the renderer.
    floor = min(pal, key=lambda c: sum(c))
    holes = 0
    for y in range(h):
        for x in range(w):
            o = x * 4
            if rows[y][o + 3] == 255:
                continue
            holes += 1
            rows[y][o], rows[y][o + 1], rows[y][o + 2] = floor
            rows[y][o + 3] = 255
    return w, h, rows, {"snapped": drift, "warm": hot, "holes": holes}


def _snap_split(w, h, rows, cold, warm):
    """`module_batch.snap_split`, with `_warm` in place of `is_warm`.

    Copied rather than imported for the one predicate, because the module rule
    has to keep its own definition: a 20x20 sprite has no highlights big enough
    for the chroma test to matter, and loosening it there would let a warm-ish
    grey drift into an accent, which is the exact bug snap_split was written to
    stop.
    """
    cache, n, hot = {}, 0, 0
    for y in range(h):
        for x in range(w):
            o = x * 4
            if not rows[y][o + 3]:
                continue
            c = (rows[y][o], rows[y][o + 1], rows[y][o + 2])
            pool = warm if _warm(c) else cold
            if not pool:
                pool = cold or warm
            if _warm(c):
                hot += 1
            if c in pool:
                continue
            n += 1
            key = (c, len(pool))
            if key not in cache:
                cache[key] = min(pool, key=lambda p: (c[0] - p[0]) ** 2
                                 + (c[1] - p[1]) ** 2 + (c[2] - p[2]) ** 2)
            rows[y][o], rows[y][o + 1], rows[y][o + 2] = cache[key]
    return n, hot


## Where a take goes when it is good but wrong for its card.
##
## The art director asked for a third verdict beside keep and cut: "art like that
## might not fit a card, but is good enough that it might generally work
## elsewhere". A cut take is DELETED -- he was explicit that a cut does not need
## showing again -- so without a bank the only way to keep a picture was to ship
## it on a card it did not suit.
##
## It is a supply and not a graveyard: Phase 8 has ninety authored event options
## with no art at all, and an event illustration wants the same 92x60 full-bleed
## shape a card does.
BANK = os.path.join("tools", "out", "bank")

## The prompt that made each raw generation, written beside the images at
## generation time and carried through posting.
##
## The first two banked takes have no prompt recorded, because this file did not
## exist yet and reconstructing one from memory would have filed a guess as a
## record. That is the whole reason it exists now: a banked picture is worth
## nothing later if nobody can ask for another one like it.
PROMPTS = "prompts.json"


def prompts(d):
    """The prompt log in a directory, or {} if it has none."""
    p = os.path.join(d, PROMPTS)
    if not os.path.exists(p):
        return {}
    with io_open(p) as fh:
        return json.load(fh)


def io_open(p, mode="r"):
    return open(p, mode, encoding="utf-8")


## Words that have each, at least once, imported a setting or an object nobody
## asked for. The docstring above explains every one; this is the machine
## readable copy so a batch cannot go out containing one by accident. It has
## happened: four prompts in one round used "flank" and one came back as a ship
## at sea, months after the rule was written down.
BANNED = ("flank", "naval", "warship", "broadside", "hull", "vessel", "shell",
          "starship", "derelict", "gun", "weapon", "cannon", "barrel")


def audit(log):
    """Prompts in a log that contain a banned word. Returns [(take, [words])]."""
    out = []
    for take, rec in sorted(log.items()):
        text = (rec.get("prompt", "") if isinstance(rec, dict) else rec).lower()
        hits = [w for w in BANNED if w in text]
        if hits:
            out.append((take, hits))
    return out


def letterbox(w, h, rows):
    """-> [] or a list of complaints about white filling the frame.

    EVERY COLUMN AND EVERY ROW, NOT JUST THE BORDER. The first version of this
    walked the outer five columns and the outer two rows, because the bar that
    prompted it ran down the left edge. `standing_load_2` then shipped a white
    column 57 pixels of 60 tall THROUGH THE MIDDLE of the frame at 21% white
    overall -- under a whole-image threshold of 25%, and nowhere near an edge,
    so both halves of the check waved it through while it was obvious to the
    eye. A check written around the last failure only ever catches the last
    failure.
    """
    def px(x, y):
        r = rows[y]
        i = x * 4
        return r[i], r[i + 1], r[i + 2]

    def wht(x, y):
        return min(px(x, y)) >= 200

    out = []
    # THE TEST THAT ACTUALLY WORKS IS CONNECTEDNESS, NOT A PERCENTAGE. A
    # background is white that REACHES THE EDGE and joins up; a highlight is
    # white that does not. Two thresholds were tried before this and both let a
    # whole round through: 40% of the frame, then a column or row two-thirds
    # white. All four `standing_load` takes were 14-21% white with the white
    # broken up between girders, so no single line was two-thirds anything, and
    # the eye saw a white background on every one of them instantly.
    #   Flood-filled from the border instead, those four measure 12, 16, 16 and
    # 19 per cent, while 39 of the 43 shipped cards measure ZERO. The margin is
    # real but it is not wide: `coolloss` is a legitimate 11%, because its steam
    # plume genuinely runs off the edge of the frame. So 12 is the line, and
    # this is a flag to LOOK at a take, never a verdict on it.
    seen = [[False] * w for _ in range(h)]
    stack = [(x, y) for x in range(w) for y in (0, h - 1) if wht(x, y)]
    stack += [(x, y) for y in range(h) for x in (0, w - 1) if wht(x, y)]
    bg = 0
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y][x] or not wht(x, y):
            continue
        seen[y][x] = True
        bg += 1
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    if bg * 100 // (w * h) >= 12:
        out.append("%d%% of the frame is white joined to the border -- "
                   "background showing through?" % (bg * 100 // (w * h)))
    for x in range(w):
        n = sum(1 for y in range(h) if wht(x, y))
        if n > h * 2 // 3:
            out.append("column %d is %d/%d white" % (x, n, h))
    for y in range(h):
        n = sum(1 for x in range(w) if wht(x, y))
        if n > w * 2 // 3:
            out.append("row %d is %d/%d white" % (y, n, w))
    return out


# NO AUTOMATED STRAY-PIXEL CHECK. There was one here for about an hour, after
# the single white pixel that shipped on Slag at (91,49). It does not work, and
# the measurement is worth keeping so nobody writes it a third time:
#
#   isolation threshold   catches Slag's pixel   fires across 43 shipped cards
#            150                  yes                        810
#            250                  yes                        305
#            300                  yes                        163
#            400                  yes                         63
#
# Sixty-three at the loosest useful setting, and every one of them is correct
# art: stars, weld sparks, rivet specular. A refinement -- flag a bright pixel
# only when nothing of comparable brightness sits within five pixels -- MISSED
# the Slag pixel outright and still fired 35 times on shipped cards.
#   The reason is that the metric cannot see what made Slag's pixel wrong. It
# was not isolation; a star is isolated. It was the brightest colour in the
# picture sitting in a dark corner of machinery, where nothing in the SUBJECT
# could be that bright. That is a judgment about what the picture is OF, and it
# belongs to the eye. What the border taught is still real and is kept in
# `letterbox` below: scan the whole frame, clamp the neighbourhood, and never
# write a loop that skips x=0 and x=w-1.


def bank(outdir, take, why):
    """Copy one posted take, its raw, and its prompt into the bank."""
    if not os.path.isdir(BANK):
        os.makedirs(BANK)
    src = os.path.join(outdir, take + ".png")
    if not os.path.exists(src):
        return "no such take: %s" % src
    n = 1 + max([int(f.split("_")[1]) for f in os.listdir(BANK)
                 if f.startswith("bank_") and f.split("_")[1].isdigit()]
                or [0])
    stem = "bank_%02d_%s" % (n, take)
    shutil.copyfile(src, os.path.join(BANK, stem + ".png"))
    # THE RAW TOO. Posting is lossy -- it snaps to a palette and fills holes --
    # and every rule this pipeline has was changed at least once after the fact.
    # A re-post under a changed rule needs the original; the module work lost a
    # sprite to exactly this and had to regenerate it.
    raw = os.path.join(outdir + "_raw", take + ".png")
    if os.path.exists(raw):
        shutil.copyfile(raw, os.path.join(BANK, stem + ".raw.png"))
    pr = prompts(outdir + "_raw").get(take) or prompts(outdir).get(take, "")
    with io_open(os.path.join(BANK, stem + ".txt"), "w") as fh:
        fh.write("take: %s\nwhy: %s\nprompt: %s\n"
                 % (take, why, pr or "NOT RECORDED"))
    return "%s  %s" % (stem, "with prompt" if pr else "NO PROMPT RECORDED")


## Cards that are OPEN: no art, and waiting to be filled from somewhere other
## than their own round.
##
## Ripple Fire is the first entry and the reason this exists. It took four
## briefs and 54 takes without landing, and the decision was to stop rather than
## spend a fifth -- but the art director's note was not "give up", it was
## "maybe another card might generate the art for ripple fire".
##
## That is the bank running backwards. A take is banked because it is good and
## wrong for the card it was made for; a card is listed here because it is
## waiting and will take a good picture from anywhere. Check this list against
## the bank at the end of every round, before deleting anything.
## FOUR CARDS ARE OPEN, and they have something in common worth reading before
## briefing anything else. Each one needs the viewer to read a SEQUENCE out of a
## still 92x60 frame -- first this, then this, then this:
##
##   ripple_fire    three shots at three moments
##   walking_fire   hits arriving one after another
##   rack_and_load  a loading cycle
##   torch          a cut progressing along a plate
##
## Every illustration that has ever been accepted is a single INSTANT instead:
## a beam firing, a round in flight, fire leaving a nozzle, a shard projecting a
## line, a plate splitting, one shard waking two. Even full_auto, which is the
## most process-like of them, is a mechanism caught at one moment rather than a
## before-and-after.
##
## That is an observation and not yet a proven rule -- full_auto is multi-hit
## and landed, torch is single-hit and did not -- but 140+ takes across these
## four cards have produced two shipped pictures and neither was a sequence.
## Brief a card as ONE MOMENT before assuming it needs a story told in stages.
WANTED = {
    # Empty is the good state. Ripple Fire, Walking Fire, Rack and Load and
    # Torch all sat here after failing their own rounds, and all four were
    # eventually filled once the method changed rather than the brief.
}

def wanted():
    """Open cards, and what would fill them, against what is in the bank."""
    print("OPEN CARDS -- will take a picture from any round")
    for k, why in WANTED.items():
        print("  %-18s %s" % (k, why))
    if not os.path.isdir(BANK):
        print("\nbank is empty")
        return
    print("\nIN THE BANK")
    for f in sorted(os.listdir(BANK)):
        if f.endswith(".png") and not f.endswith(".raw.png"):
            print("  ", f[:-4])
    print("\ninstall one:  --install %s/<entry>.png <card_key>" % BANK)


def install(src, key):
    """Put any 92x60 picture on any card, whatever round it came from."""
    if not os.path.exists(src):
        return "no such file: %s" % src
    w, h, rows = pt.decode(src)
    if (w, h) != SIZE:
        return ("%s is %dx%d, the art window wants %dx%d"
                % ((src, w, h) + SIZE))
    dst = os.path.join(CARDS, key + ".png")
    pt.encode(dst, w, h, rows)
    return ("%s -> %s\n  run `godot --headless --import` so Godot picks it up, "
            "then `-- artcheck`" % (src, dst))


def main(argv):
    if not argv or argv[0] == "--palette":
        pal = card_palette()
        print("%d colours from %d accepted illustrations"
              % (len(pal), len(ACCEPTED)))
        for c in sorted(pal, key=sum):
            print("   #%02x%02x%02x%s" % (c[0], c[1], c[2],
                                          "  WARM" if mb.is_warm(c) else ""))
        return 0
    if argv[0] == "--post" and len(argv) >= 3:
        indir, outdir = argv[1], argv[2]
        if not os.path.isdir(outdir):
            os.makedirs(outdir)
        pal = card_palette()
        print("palette: %d colours from %d accepted" % (len(pal), len(ACCEPTED)))
        for f in sorted(os.listdir(indir)):
            if not f.endswith(".png"):
                continue
            w, h, rows, rep = post_one(os.path.join(indir, f), pal)
            note = ""
            if (w, h) != SIZE:
                note = "  WRONG SIZE, wants %dx%d" % SIZE
            for c in letterbox(w, h, rows):
                note += "\n      WHITE: " + c
            pt.encode(os.path.join(outdir, f), w, h, rows)
            print("  %-24s %dx%d  %4d snapped  %4d warm  %d holes%s"
                  % (f[:-4], w, h, rep["snapped"], rep["warm"],
                     rep["holes"], note))
        # The log travels with the pictures, so a take that is banked months
        # from now still knows what was asked for.
        log = prompts(indir)
        if log:
            with io_open(os.path.join(outdir, PROMPTS), "w") as fh:
                json.dump(log, fh, indent=1, ensure_ascii=False)
            print("  carried %d prompts forward" % len(log))
            for take, hits in audit(log):
                print("  BANNED WORD in %s: %s" % (take, ", ".join(hits)))
        else:
            print("  NO PROMPT LOG in %s -- write one at generation time" % indir)
        return 0
    if argv[0] == "--bank" and len(argv) >= 4:
        print(bank(argv[1], argv[2], " ".join(argv[3:])))
        return 0
    if argv[0] == "--wanted":
        wanted()
        return 0
    if argv[0] == "--install" and len(argv) == 3:
        print(install(argv[1], argv[2]))
        return 0
    print(__doc__)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
