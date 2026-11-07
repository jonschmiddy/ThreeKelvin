The reasoning behind `tkg/scripts/ui/NavField.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Navigation field

Above `const FAR := preload("res://shaders/local_far.gdshader")`:

```text
THE SPACE THE THREE NAVIGATION SCREENS ARE BUILT ON (Jon, Oct 18: "I just
want the swap to feel smooth and cohesive. Why don't we have stars fill the
entire panel edge-to-edge ... Let's have the panels built ON TOP of this
screen"). One field of stars and far galaxies across the whole screens' area,
behind LOCAL, the sector map and the star chart alike, that never cuts,
fades or changes when you move between them: a hop changes what is in front
of it, never it.

IT IS LOCAL'S OWN FAR SKY (`LocalSky`: `local_far.gdshader` on
`chart_bg.gdshaderinc`, the far galaxies and three depths of stars every chart
style keeps, toned by LOCAL's play tone and cut to the system's palette),
drawn the same way in the same frame -- a 480x270 picture of 2x2 blocks with
the window as its frame -- so on LOCAL, where the sky is drawn whole over it,
the stars LOCAL shows are this field's stars, pixel for pixel, wherever the
system's cloud and worlds are not. While a LOCAL sky is up its far sky's
settings are copied here (its camera's slide, its palette once cut), so the
field is LOCAL's far sky as it last stood when LOCAL goes. The one thing left
out is the clear sky's glow round the system's star: that is the star's light,
and it goes with LOCAL.

Above it: the map's and the chart's pictures with their own far stars off and
their empty sky keyed away (`nav_key.gdshader`), the panels and the toolbar
rows as glass plates. The ladder holds a screen's picture with this field
keyed out of it (`ZoomLadder`, `calm_ladder.gdshader`), so a move carries the
things in front and the stars stay where they are.

Router's, next above `SpaceLayer` (which the three screens hide), inert
headless but there, so the harness can hold it to the same instance.
```

## Glass plates

Above `const PLATE_A := 0.80`:

```text
HOW MUCH OF THE FIELD A PLATE LETS THROUGH (Jon, Oct 18: "Let's have the top
part also be a panel. Let's make both panels slightly see through like the
other panels"): the side panel and the toolbar row on the map and the chart,
glass over the stars at LOCAL's own event drawer's alpha
(`SectorScreen.DRAWER_A`, the plate already over this sky), a shade more
open than `UITheme.PANEL_A`.
```

## Toolbar plate

Above `const ROW_PAD_V := 5`:

```text
A TOOLBAR ROW ON ITS PLATE (Jon, Oct 18: "the size of that panel also
doesn't seem big enough... the border comes right up to the button's
edges"): the row inside a plate of the side panel's own look, its line as
far from the row's ends as the side panel's is from its contents (12 px),
and close above and below (`ROW_PAD_V`: "The row is good on the width...
but a bit excessive on the height"). The ladder's `ladder_bar`.
```

## Field drift

Above `var pan := Vector2.ZERO`:

```text
THE FIELD'S DRIFT (Jon: "Why is the parallax gone from the sector and
starchart views?"): its far layers slide by `pan` (`chart_bg`'s `u_skyPan`,
whole game px: the far nebulae 0.02 of it, the far galaxies 0.05, the three
depths of stars 0.04, 0.10 and 0.20) -- on the chart by the chart's own sky
pan (`MapChart.sky_pan`, exactly as its own far sky slid), on the map by the
map's (`SystemView._cam_pan`, at MAP_K: its old five fields slid 0.03-0.55
of it), on LOCAL by LOCAL's camera (copied, `feed`). Each screen moves it by
how far its own pan has gone since it came up, from wherever it stood, so a
hop never puts it back; and through a move it holds still (a move is not a
pan: `ZoomLadder.busy`).
```
