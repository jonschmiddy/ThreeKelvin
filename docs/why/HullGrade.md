The reasoning behind `tkg/scripts/systems/HullGrade.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hull grades

Above `enum Look { WEAR, PAINT, MARKS, LIGHTS, KIT }`:

```text
ONE HULL PER WEIGHT, FOUR GRADES DRAWN FROM IT (Jon, Oct 14: "Instead of
generating 12 ships per manufacturer. We just do Three... use shader code to
modify each ship at each heaviness to make them more shitty (C tier)" or new
looking at S).

A BAKE, NOT A LIVE SHADER: one pass per hull and grade, cached, so it costs a
frame nothing, and every operation ends on a colour the sprite ALREADY HAS (a
step along its own ramp, its amber turned to the grey of the same lightness,
its own lightest colour) -- the ruling that generated art may not drift the
palette holds by construction, as it does in HullWear, and `palette()` before
and after can prove it.

GRADE IS BUILD QUALITY, DAMAGE IS CONDITION. HullWear draws what the fights
did, off hull points; this draws what the yard did. The three looks below are
three ideas of what a C has that an S does not, on trial (Jon picks one):
  A  wear:   age -- grime in the panels, drips under the seams, the amber faded
  B  paint:  livery -- C in primer with odd panels, B chipped, S trimmed
  C  finish: light -- C flat and dull, S crisp with lit edges and lit ports
A is the one that leans on condition's register; that is a known risk against
the "a class is a SPECIFICATION, not a condition" ruling, and why B and C exist.
```

## Mixed looks

Above `static func bake_mix(src: Image, grade: int, looks: Array, seed_in: int = 7, hull: String = "") -> Image:`:

```text
More than one look on one hull (Jon: "the combinations of wear using A B and
C"). Always in the same order whatever order they are asked in -- the paint
the yard put on, then the age on top of the paint, then the light falling on
all of it -- and every pass steps along the ramps read off the SOURCE, so a
pass after the paint still knows the amber the paint took away.
`hull` is the hull's key in art/hull_grade.json ("korvan/hull_medium_a"): the
markings and the lights are placed by hand there, and a hull with no entry
gets neither.
```

## Manufacturer colour stays

Inside `_wear()`, above `if r.is_accent(c):`:

```text
the amber dulls in patches and wears through to the grey in a few:
the manufacturer's colour is always still there (Jon, Oct 14).
Soft patches, no speckle: on the band a checker of cells read as
pixelation, not as paint worn off
```

Inside `_paint()`, above `if r.is_accent(c):`:

```text
THE MANUFACTURER'S COLOUR STAYS (Jon, Oct 14: "there should be SOME COLOR even
at C class. The color of the bands is really important for
manufacturer identity"): a shade darker and worn through to the
grey in patches, never gone
```

## Manufacturer band

Above `const BAND_FROM := {"korvan": "res://art/sprites/hulls/korvan/hull_medium_a.png"}`:

```text
THE MANUFACTURER'S BAND IN ITS OWN AMBER on every weight (Jon, Oct 14: "can
we make the orange band ... as vibrantly orange as the medium?"). Today's
light and heavy sprites were generated apart and their band came out a
duller, browner orange, with its lower half in shadow. The band's colours
are the manufacturer's, so they are read off one sprite (the medium's) and
every other hull's band is put onto them by lightness. The palette lock
still holds, against the sprite's own colours AND the manufacturer's ramp.
```

## Markings

Above `static var reg_look: StringName = &"A"`:

```text
MARKINGS: the registry painted straight on the hull where its entry puts it
(a plate behind it looked stuck on: Jon, "Can't we have it more integrated
into the ship?"), in a grey that reads on that panel. Scraped at C (a few
strokes left), faded through a dither at B, clean at A, fresh at S -- the
lightest ink -- with two amber chevrons on the nose.
THE REGISTRY'S LOOK, on trial (Jon, Oct 15: "THE TEXT PLACEMENT HERE LOOKS
BAD AND PRINTED ON", of the white number on L1 and H3): "" the white stencil
as it was; &"A" tone on tone, each stroke the panel under it two shades
lighter; &"B" the number alone, in dark paint across the band; &"C" no
number. Jon picked A (Oct 15), "a bit lighter, it's too faint": a fifth
lighter, up from a tenth.
```

Inside `_marks()`, above `if reg_look == &"A":`:

```text
LOOK A'S ONE INK: a fifth lighter than the panel under the whole number,
not under each stroke. Lifted pixel by pixel, a speckled panel gave a
speckled number that read fainter on one hull than another (Jon: "why are
all three of these letters different brightness?")
```

## Running lights

Above `static func _lights(img: Image, r: _Ramps, grade: int, at: Dictionary) -> void:`:

```text
RUNNING LIGHTS where the hull's entry puts them: its own dark glass (the
ports' panes, the bridge windows) and the nav lights. Dead at C; at B a third
of the panes and the white nose light; at A two thirds and every nav light; at
S every pane. Lit panes are warm, in the manufacturer's colour. A nav light is
2x2 with a glow round it: the hull a step or two lighter along its own ramp,
so the light spills without a colour the sprite does not have. Which panes
light is fixed by their order, never rolled.
```

## Light glow

Above `const GLOW := [0.55, 0.28, 0.12]`:

```text
THE GLOW, which the bake cannot make: a light is brighter than any colour the
hull has, so it is a separate layer added over the hull where it is drawn
(ThrusterFx.add_material, the flames' own blend), the one thing here off the
palette, as a flame is. Three stepped rings round every lit pane and nav
light, pixel-sharp, fading out (two round a surface marker); a hull with no
entry gets none. `dy` moves it
with a bake that moved the hull. Jon: "The lights look just like rectangular
pixels."
```

## Live lights

Above `static func level(kind: String, i: int, t: float) -> float:`:

```text
THE LIGHTS LIVE (Jon: "Can the lights on the surface flicker?"). `t` is
the game clock in seconds; -1 draws every light at rest (a still, a test).
A surface marker strobes: a short flash every 1.2-1.6 s on its own beat, a
white one twice. The masthead beacon swells and fades once a second and a
half. A window is steady, but now and then dips for a moment, as if someone
crossed in front of it. Nav lights are steady, as a ship's are. A pulsing
pane (Solari's bar strips: Jon, "softly pulsate... BACK to front") swells
and eases in turn, aft to fore by its order, one wave every 2.4 s.
```

## Kit

Above `static func _kit(img: Image, r: _Ramps, grade: int, seed_in: int, at: Dictionary) -> void:`:

```text
KIT. Every thin thing standing proud of the hull's top edge -- masts,
antennas, the small fittings on the roof and the nose -- is DETAIL, and the
grades take it away: S is the sprite exactly as drawn, A loses the top third
of each, B two thirds, C all of it. Nothing is ever drawn, only removed (Jon,
Oct 14: "I don't want you to DRAW pixels for S. I want you to remove details
towards C"). A thin thing: a column's top pixels while the row's run of
opaque pixels through them is three wide or narrower.
```


## Baked ahead

Above `static func bake_ahead(hulls: Array[HullData], seed_of: Callable) -> void:`:

```text
For the front door (Nov 12): a graded picture is 100 to 300 ms of GDScript,
seeded by the run, so a banner's three cost 0.6 s on its first click. The
bake reads two tables, `_band_ramps` and `_places`, filled here on the main
thread first so the workers only read them. Whose hull it is used to be a
static (`_manufacturer`) set at the top of each bake; it is now `_Ramps.mf`,
so bakes of two manufacturers can run at once. `-- sheet=YardPerfTest`
checks a worker's bake equals the main thread's, byte for byte.
```

