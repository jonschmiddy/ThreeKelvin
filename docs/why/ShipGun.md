The reasoning behind the on-ship gun pictures (`tkg/scripts/data/ShipGun.gd`, made by `tkg/art/tools/ship_guns.py`); each heading is referenced by a `Why:` line.

## Solari guns

Solari's seven guns (Nov 20) are drawn in the hulls' lit bronze: brass highlights, and
thin orange glows in coils, muzzles and vents. Two of `ship_guns.py`'s Korvan steps broke
them, so a gun's entry in the artist's guns.json can turn them off:

- `"own_colours": true`: after the area shrink each pixel takes the drawing's own nearest
  colour, weighing saturation (`shrink_own`), instead of a 24-colour median cut, which
  merged the glows into the bronze round them. The lamp stamp (`lights`) is skipped: on
  bronze, every bright warm brass highlight read as a lamp and came back as a white speck.
- `"relight": false`: the belly copy is a plain vertical flip. The faces relight splashed
  orange across the breeches (plasma, ventcan, heliostat, sunspot); Jon, Nov 20: "The flipped
  versions' colorations are really weird and don't make sense".

`ship_guns.py SRC --keep` installs a folder's guns alongside the ones already installed,
so Solari's guns go in without reinstalling Korvan's from their sources.

## Manufacturer-drawn yard guns

The three unbranded yard guns (Mining Laser, Slug Thrower, Cutting Torch) stand on any hull,
so on a Korvan or Solari hull they are drawn in that manufacturer's colours (Jon, Nov 23: pick B of
A palette map, B map plus manufacturer detail, C PixelLab redraw; the decision sheet in tk-scratch). In play
the gun stays unbranded: same rules, name, hold icon and card. Only the picture on the hull
changes.

- `art/tools/manufacturer_guns.py` makes each manufacturer's copy in code from the installed plain gun, at 0
  generations: every pixel goes to the manufacturer's ramp at its own brightness, then the manufacturer's detail
  is drawn at whole pixels. Korvan gets a steel collar, rivets and a hazard stencil in the hull band's
  colour. Solari gets brass bands, a furnace vent, muzzle soot and a warm lens. The detail is
  placed per gun (`GEO`) and lit from above on both sides. `ship_guns.py` runs it after every
  install, so the copies follow the plain gun.
- Each manufacturer's copies sit in their own folder, `art/sprites/guns/<manufacturer>/`, with a `guns.json`
  laid out like the plain table: same files, same canvases, same anchors. The plain table
  stays exactly as `mount_placer.py` and the tests read it, and a manufacturer without copies (the
  other five, for now) needs no entry.
- `ShipGun.of(id, side, manufacturer)` tries the manufacturer's table, then the plain one. `MountPoints.gun_for`
  passes the hull's manufacturer only for an unbranded weapon, so a branded gun keeps its own
  picture on any hull. An unbranded gun with no manufacturer copy falls back to the plain
  picture, or to none: the Singing Core, a precursor relic, has only its hold icon.
