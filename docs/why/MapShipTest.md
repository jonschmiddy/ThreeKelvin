The reasoning behind `tkg/scripts/sim/MapShipTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Map ship test

Above `var _tree: SceneTree`:

```text
YOUR OWN SHIP ON THE SECTOR MAP, AND ITS ION DRIVE:
  godot --headless --fixed-fps 60 --path . -- sheet=MapShipTest

Jeremy, friends' alpha: the sector map's ship should be the player's own,
not a generic one, and its engine flame blue, an ion drive, so flying in a
system reads as the drive and not the warp. A new run's sector map, through
the real screen (`SystemOverlay._draw_ship`, its pixels kept by `record_px`,
since headless draws nothing that can be read back):
  - the ship is drawn from your hull's own picture, the one LOCAL draws (the
    grade's bake, worked out here on its own, not asked of the code under
    test), at the map's length for its weight: the picture's colours are that
    art's (a dark hull lifted to read, `MapHull.LIFT_TO`), and pointing
    straight along the map every hull pixel drawn is the picture's pixel for
    pixel;
  - after a hull swap (`Run.transfer_to_hull`, a Solari heavy) the map draws
    the new hull the same way, longer;
  - W held through the real step: the flame lit, and every pixel of it and of
    the engine glow in the ion ramp (blue over red and green), none warm;
  - fit means nothing overlaps: YOU clear of the hull pointing straight up,
    and a partner sitting where you are drawn in formation clear of it;
  - AFTER THE MAP'S KEY: the map's picture is keyed onto the field
    (`nav_key.gdshader` on `SystemMapScreen._box`), so a colour can be drawn
    and still not be seen. Each solid pixel of the hull and its dark rim is
    put through the key's own rule, read off the screen's material, and must
    stand. The rim was the old arrow's #05070b, inside the key's band, and
    never showed; the colours recorded before the key could not tell.
```
