The reasoning behind `tkg/scripts/ui/MarkOutline.gd`, the game's one highlight.

## One outline

Above `class_name MarkOutline`:

```text
STRIPPED-DOWN UI, PART 2, C1 (Jon, Nov 9). One outline means "this one": a
pale mint (`UITheme.MARK`) no art uses, 2 px, drawn round the shape of what
you point at and of what a held card will hit, joined by a dashed line, and
nowhere at rest. The audit (tk-scratch/ui-audit/README.md, section 2.3)
counted about seventeen highlight styles; Shroom and Gloom has one.

HOW IT IS DRAWN. The shader is the cutaway's hull outline (CutawayView.md,
"Hull outline"): from the texture the sprite is drawn from, every clear
pixel within MARK_PX of an opaque one (Manhattan reach, so corners stay
square) is painted MARK. It follows every repaint of the sprite for nothing
and rides the art's bob as its child. Rectangles (a card, a deck cell, a
beacon box) use `draw_rect_mark`, four filled rects inside the box; round
things drawn on the GPU (a world on the map, a star on the chart) use
`draw_ring_mark`, a ring of whole pixels, since the overlay cannot read
their alpha.

WHAT IT REPLACED, from the audit's list of seventeen, and why:
 3  your ship's HOT outline on LOCAL      -> MARK, 2 px (same class)
 4  the same, amber, in the yard           -> MARK, 2 px (same class)
 5  the map's hover reticle (corner ticks) -> MARK ring round the body
 6  a panel card's beacon brackets (ICE)   -> MARK box round the beacon
 7  panel card lighter fill and edge       -> MARK 2 px edge, fill unchanged
11  card hover lift + FLARE tint           -> lift kept, MARK 2 px frame
13  bevel button hover (lighter, FLARE)    -> MARK 2 px border, text as at rest
14  drawer plates CHILL edge under cursor  -> MARK edge; GOOD and BAD kept
15  title menu text going HOT              -> text goes MARK
16  deck cell 5% wash; drone glass amber   -> MARK 2 px outline, both
17  the part a hovered card came from (HOT ring on the hull) -> MARK
 -  the chart's hover ticks (white)        -> MARK ring round the star
 -  a wreck (cursor only)                  -> MARK outline when openable
KEPT AS ON MAIN, Jon's call on seeing part 2 (Nov 9, "I really liked the old
view for pointing a card at an enemy"): 9 the FLARE corner brackets on the
enemy, 10 the GOOD brackets on your hull, and the orange wavy aim line with
its lock (`AimLine`, now a class of its own, the same code). The first build
had replaced all three with the mint outline and a dashed mint line; it is
gone. The armed card's frame is in the aim's own orange (FLARE) instead,
"the same colour as the orange wavy line and orange brackets" (Jon), so
card, line and brackets read as one gesture; the hovered card keeps mint.
KEPT, because they carry meaning rather than "this one":
 1  A.S.H.'s ICE rectangle round a lesson's subject (the tutorial, B1-B3, a
    later pass; it says "look here" while she talks, not "under the pointer")
 2  the hint card's notch and leader (the same)
 8  rival choice cards dimmed to 55% (will be made unavailable: C2's idea)
12  unplayable cards faded (cannot pay: now `UITheme.DIM`, C2's level)
17  the tractor pings and swap marks while a part is carried (TRACTOR is the
    beam's own colour and the cutaway's tests measure them)
 -  the chart's selected star in FLARE brackets and YOU (the jump's
    destination and where you are: state, not pointing)
 -  commit plates in EMBER at rest, the lit HUD tab, FLEE red, HAIL yellow
    (what kind of thing it is; the outline is added on hover)
 -  the map's orbit ring (FLARE) and the forecast's HOT ring (where the ship
    goes, a flight's own instruments)
```

## Ship looks

Above `static var look: int = 0`:

```text
Jon on c1_local_wreck_after (Nov 9): "the stroke on the salvage ship is WAY
too intense": the 2 px stroke traces every broken piece and hole of a wreck.
He asked for options rather than a fix of mine. Three ideas, rendered side
by side (tk-scratch/ui-build/part2/ship_mark_options.png), picked by
`-- marklook=N`, the default left at 0 until he picks:

 0  today: the 2 px MARK stroke on every clear pixel next to ink
 1  A: the outer silhouette only, 1 px, at 0.8: clear pixels next to ink that
    the canvas edge can reach through clear pixels (a CPU flood fill, once
    per canvas size, handed to the shader as the `outside` mask), so inner
    holes and the gaps between a wreck's pieces are not traced
 2  B: a light lift, no stroke: the sprite's ink brightened a step (x1.18
    + 0.05) and a 1 px rim light at 0.55 on the outer edge
 3  C: the fight's own ember corner brackets (`AimTarget.draw_brackets`,
    FLARE, 7 px arms) round the picture's box, the ship untouched; the
    brackets Jon likes on the enemy he aims at
```
