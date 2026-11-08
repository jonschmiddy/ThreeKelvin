The reasoning behind `tkg/scripts/sim/WearSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Wear sheet

Above `const OUT := "user://wear"`:

```text
Every damage band of every hull with real art, as PNGs — plus the cost of
building one, which is the number that decides whether this can run in a fight.

    godot --headless --path . -- wear

Needs no renderer: HullWear works on an Image and an Image is a file. It also
PROVES the thing that matters, which is not that the grades render but that
they render CLEAN — the whole argument for drawing wear rather than generating
it is that arithmetic cannot introduce a colour, and this counts them.
```
