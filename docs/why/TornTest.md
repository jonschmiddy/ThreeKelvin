The reasoning behind `tkg/scripts/sim/TornTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Torn test

Above `const SEEDS := [884043030, 4242, 11]`:

```text
TORN AWAY'S BIG DWARF (`ChartTorn`), in every style that draws one:
  godot --path . -- sheet=TornTest [styles=painted,simplified,radiant] [kinds=14,15] [shots=<dir>]

Jon, Nov 8 ("SIZE: bigger"; "I basically want the dwarf to be drawn large, and then
get smaller and smaller as it's stripped away to nothing"): the two dwarfs are
drawn big enough that their bodies cover all 14 rings of systems, TORN AWAY on or
off, and each ring lost strips the body at that ring's own radius, to nothing at
the end. The end is one switch (`ChartTorn.ending`): F, the rules as they are (rings
0-9 fall, the picture goes to nothing over them, the inner four rings' systems left
loose), or N (every ring falls).

THE RULE, headless (three seeds, both dwarfs, both endings):
  cover    the body's reach (`cover`) past every system, by COVER_MARGIN at least;
  edges    the picture's edge (`edge_at`) falls ring by ring, never rising, to
           nothing at `max_lost` (10 for F, 14 for N) and not before;
  inside   every system still standing is inside the edge, with every ring lost
           (F: until `F_FOLLOW`, past which its last four rings are loose on
           purpose), and inside the torn edge's floor (`live_r`: the rag never
           comes in past the farthest system standing; the shader keeps TORN_MARGIN
           past it);
  gone     exactly the systems on the lost rings are gone, the core never;
  alone    a big dwarf has no small companion drawn round it (its body stands where
           the companion stood, under the rim's systems): the giant is its story.
THE DRAWING (windowed; Jon's galaxy's seed, as BallHaloTest's, its far sky clear),
for each style and dwarf, the sky alone at the opening:
  on       every system on the screen sits on the dwarf's body, TORN AWAY off: the
           sky in a 9 x 9 box about its mark changed by the big body (against the
           same chart with the dwarf drawn as before, `ChartTorn.big` off) over
           ON_SHARE of its pixels, or lit already (the inner rings stand on the
           core's own body: LIT_T over the void). Systems inside a named cloud are counted apart
           (the cloud is drawn over the body there, by design) and printed;
  legible  the sky under every mark and YOU's name may not rise more than
           BallHaloTest's MARK_RISE to past its MARK_LUMA under the body; and no
           blow-out: the chart's cream (over 200) up CREAM_RISE (% of it) at most;
  stripped TORN AWAY on, ending N: with 4 and 8 rings lost, every system still
           standing sits on what is left of the body (its box changed against the
           chart with every ring gone, where nothing of the body is left);
  clear    the giant's middle (`ChartTorn.GIANT_S`, its bulge's box) stands clear of
           every system's mark, YOU's mark and name, every word the chart prints
           and every control over the chart (the goal line, the toggles, the scale),
           inside the chart.
Needs a window (it reads the drawn sky).
```
