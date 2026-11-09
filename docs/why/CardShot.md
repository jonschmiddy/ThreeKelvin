The reasoning behind `tkg/scripts/sim/CardShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Card shot

Above `const SCALE_DEFAULT := 1`:

```text
One card, as the game draws it today, cropped to the card:

  godot --path . -- cardshot "Ripple Fire" "Full Auto"
  godot --path . -- cardshot all

NOT `--headless`, for the reason ShipShot records at length: the settle waits
on `frame_post_draw`, which the dummy display server never emits.

WHY THIS EXISTS. Card art is being chosen against a baseline nobody can see.
Every candidate illustration is judged on a contact sheet as a bare 92x60
rectangle, but the thing it REPLACES is `CardView._type_glyph()` drawing into
that window under a name, an energy pip and three lines of rules text. A
picture that looks thin on a sheet can still be the better card, and a picture
that looks rich on a sheet can fight the text under it. So: photograph the
card, put it beside the options, and let the comparison be the real one.

Cards are looked up BY NAME because that is what a card has. There is no card
id in the schema — CardData carries `name` and `source_id` and nothing else
that identifies it — so the argument is the display name, quoted.
```

## Shot naming

Inside `run()`, above `var path := "res://../tools/out/cardshot/%s.png" % (by_name[n] as CardData).art_key()`:

```text
NAMED BY art_key(), NOT by the display name. Every other tool in this
pipeline -- the manifest, design_sheet.py, bench.py, the installed
sprite -- keys on art_key. Slugging the name agreed with it by luck
for module cards ("Rack and Load" -> rack_and_load) and disagreed for
every malfunction ("Hairline Crack" -> hairline_crack, key `hairline`),
so thirteen shots were written where nothing would look for them.
```
