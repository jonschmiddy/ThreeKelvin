The reasoning behind `tkg/scripts/ui/sysmap/SystemPalette.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## System palette

Above `const K := 16`:

```text
A SYSTEM'S OWN SHORT PALETTE, for `map_palette.gdshader` (Jon picked the
strongest take, then "even more pixelated"). Found once per system from its
own first picture, so its colours stay true:
  * about sixteen colours, split again and again where the picture's
    colours spread widest (a median cut, weighted by how much of the
    picture each colour covers);
  * a few more from round the star, so a small bright star is not averaged
    away into the sky;
  * every other colour of the star painter's own palette, so a sun keeps
    the colours it was painted in (a cut alone turned the sun cream);
  * the void.
A fixed palette was tried first: it turned the sun green and filled dark
sky with grids of dots.
```

## Palette build

Above `static func build(img: Image, x0: int, star_at: Vector2, star_r: float, kind: String, y0: int = 0, k: int = K, extra: PackedVector3Array = PackedVector3Array(), own_pal: bool = true, no_grey: bool = false, merge: float = MERGE, void_first: bool = false,`:

```text
The palette for one system's picture `img`, its star at `star_at` with
radius `star_r`, of `kind` ("ORDINARY", "RED", "BLUE", "PULSAR", "CORE").
`y0`: the first row the map shows; above it is the HUD, not the system.
`extra`: colours of the system's weather (`SkyWeather.RAMP`), put in before
the void, so its brightest moments have steps of their own.
`merge`: twins closer than this (OKLab) are one colour (0: none).
TWO SUNS (ruling 20): `star2_r` > 0 adds star B's light -- a cut of its own
round `star2_at` and its own steps `star2_cols` -- straight after star A's, so
the merge keeps them before the painter's and the weather's. Only as many of
them as leave the whole within `most` colours (the palette pass holds 72, and
the caller cuts the rest off without a sound): star B's are what give way,
never the sky's, the weather's or the void. Left out (every one-sun call),
the palette is the one this always made.
```

## Twins merge

Above `const MERGE := 0.03`:

```text
TWINS ARE ONE COLOUR. The cut of a dark sky finds runs of near-identical
dark violets, a step or two apart; a block whose colour sat between two of
them took one or the other as the map zoomed, frame by frame, and the sky
shimmered with a flicker nobody could see as a colour change (the dark
cloud's zoom: half of every pixel that changed went back the next frame).
A colour within MERGE (OKLab) of one already kept is dropped; the earlier
one -- the cut's, the star's, the painter's -- stays.
```
