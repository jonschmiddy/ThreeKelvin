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
