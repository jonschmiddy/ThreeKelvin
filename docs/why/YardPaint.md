The reasoning behind `tkg/scripts/ui/YardPaint.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Yard layers

Above `const PLAIN := 0`:

```text
One layer of the Yard, drawn fresh every tick in the page's order.

THE PAGE WROTE EVERYTHING INTO ONE FRAME, back to front: a walker's shadow,
his reflection, then him, then the next one along. Here each of those needs a
different way of being lit -- a shadow is only dark, a reflection takes the
light where it lies, a walker the light at his feet -- and a canvas item has
one material. So a layer is a run of canvas items, one per stretch of draws
that are lit the same way, in the order they were asked for: the page's order.
A walker standing somewhere else gets his own item, because the light at his
feet is the item's (`cell`, `yard_light.gdshader`).

Items are kept between ticks and cleared, never freed and made again.
```
