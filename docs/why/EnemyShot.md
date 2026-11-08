The reasoning behind `tkg/scripts/sim/EnemyShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Enemy shot

Above `const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")`:

```text
Every enemy type in the fight, photographed: the real fight view (`SectorScreen`,
`EncounterView`, `EnemySlot`, `EnemyArt`) opened on each enemy in turn, the
picture taken once it has flown in and settled.

  godot --path . --windowed --position 3840,0 -- sheet=EnemyShot out=<dir>
      [ids=cutter,lancer:2,...] [packs=cutter+hulk:1,...] [seed=N] [sky=calm]
      [style=...] [wait=150] [hp=<0..1>] [tele] [tag=<suffix>]
      [film=<frames>]   (with --fixed-fps 30)

For each id (default: every enemy in `DB.enemies`) and each pack (ids joined
with `+`, the first leads), writes `<out>/<name>.png` -- the window as it is on
screen -- and `<out>/<name>_1x.png`, the game's own 960x540 picture, and one
JSON line per shot to `<out>/shots.jsonl`: where each enemy's holder and drawn
ship (`used_rect`) are, which picture it wears (`look`), where your ship is,
and the enemy row (`slots`: left, width, gap, the room it has, the row's
width), in game pixels. A ship whose box ends past the view's right edge is
cut off.

WHAT IT DRAWS IS WHAT THE GAME DRAWS. The enemy's picture comes through
`DB.enemy_sprite` like any fight's; `id:N` makes it wear its kind's Nth
picture. The bob is stopped once the ship has arrived, so two runs line up
pixel for pixel. `hp=0.4` opens every enemy at that share of its hull (the
wound bands); `tele` has every enemy winding up (its own telegraph move, else
the escape burn) for the wind-up light. `film=N` instead films the fight's
first N frames from the moment it opens (the fly-in, then a card played at
the first enemy every 45 frames) into `<out>/<name>_clip/f_####.png`, for an
MP4. Needs a window.
```
