The reasoning behind `tkg/scripts/ui/sysmap/MapHull.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Map ship

Above `const LEN: Array[int] = [14, 17, 20]`:

```text
YOUR OWN SHIP ON THE SECTOR MAP (Jeremy, friends' alpha: the map flew a
generic arrow, not the ship he had built). The hull's own picture, the one
LOCAL draws (`ShipView.hull_art`: its art at its grade, paint and markings
and all), shrunk to the map's scale and turned the way the game turns a
sprite (`PixelTurn`, SOFT): never rotated on screen, each turn its own
picture, every pixel of it averaged from SS x SS points in linear light with
its edge partly clear. The map's other rules stay the overlay's: what hides
the ship, the flash it catches, the flame (`SystemOverlay._draw_ship`).

NO PARTS ON IT. At this scale a gun is a pixel or two; the hull's outline is
what says whose ship it is, and the pictures that do draw parts draw the
weapons only (`MountPoints.weapons_only`).

Cached for the session: a picture per hull picture, a turn per angle step,
each made the first time it is drawn (one a frame at most, since a frame
draws one ship), so a hull swap costs one shrink and nothing else changes.
```

## Dark rim

Above `const OUTLINE := Color("#000000")`:

```text
THE DARK RIM ROUND THE HULL, dark enough to be drawn at all. The map's
picture is keyed onto the field (`nav_key.gdshader`, `NavField`): a pixel
between the key's `dark` and `lo` is taken for empty sky and let through, so
the old arrow's #05070b (luma 0.027) was never seen -- the field's navy and
its stars showed where the rim was drawn. Under `dark - dark_w` (0.008) a
pixel is kept as the hole's black is, so the rim is black.
-- sheet=MapShipTest judges it after the key.
```

## Dark hull lift

Above `const LIFT_TO := 0.2`:

```text
A DARK HULL STILL READS ON THE MAP: shrunk to a few pixels, Korvan's grey
averaged to about the brightness of the galaxy's band behind it (the first
still: a grey sliver you had to hunt for, where the old arrow was the
brightest thing on the map). A hull whose mean brightness (linear) is under
LIFT_TO is lifted to it, by at most LIFT_MAX, its own shading and hues kept:
Korvan's medium 1.74x and its heavy at the cap, Solari's tan not at all. 0
draws the art as it is.
```

## Hull picture

Above `static func picture(h: HullData, src: Texture2D) -> Dictionary:`:

```text
THE HULL AT THE MAP'S SCALE, from `src` (`ShipView.hull_art`): {} when it has
no picture to shrink.
  W, H      the picture's size, its outline in, both odd so its middle is a
            pixel's middle (an unturned ship lands pixel for pixel)
  pm        per pixel: red, green, blue (linear, premultiplied), alpha, and
            1 where it is hull and not the outline
  img       the same, as an image (sRGB), to look at
  ev        the engines' row, from the middle row (the hull's own thrusters,
            else the middle)
  stern     per row from the middle (`ev` - 1 to + 1): the first column
            drawn, from the middle column
  nose      per row (-1 to +1 from the middle): the last column drawn
  R         the farthest a turned picture's pixel can be from its middle
  gain      how much it was lifted (`LIFT_TO`), 1 for none
```
