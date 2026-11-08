The reasoning behind `tkg/scripts/sim/LocalLifeShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Local life film

Above `const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")`:

```text
LOCAL'S LIFE FILMED (`LocalLife`: the air, the city lights, the moons, the
traffic), each frame both ways:
  godot --path . --windowed --position 3840,0 --fixed-fps 30 -- sheet=LocalLifeShot
      out=<dir> [cases=<case>[:<hide>[:approach]],...] [hide=air|night|moons|traffic|all]
      [frames=240] [warm=70] [style=simplified|painted|radiant|legacy]
      [approach] [bench]
For each case: a new run (its seed), the ship parked as the sector map leaves
it, LOCAL shown; then `frames` frames, each saved TWICE -- as played
(`<case>/after/f_####.png`), and the same frame drawn again with what `hide`
names taken away (`LocalLife.hide`; no clock moved in a forced draw, the
worlds' surface memories held: `<case>/before/f_####.png`) -- so the two
differ by that alone (a case may name its own `hide`, and `approach`; its
folder is then `<case>_<hide>`). The game's 960x540 picture. The clocks step 1/30 s a
frame (run with `--fixed-fps 30`). `approach`: the ship flies in, as it does
arriving from the map. `bench`: the air's and the city lights' GPU time, each
drawn 40 times over in a viewport of its own, on and off alternated (the GPU
is shared, and a sliver of a millisecond is lost in a whole frame's noise).
LocalLife's own CPU a frame is printed for every case. Needs a window.
```
