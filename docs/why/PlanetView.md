The reasoning behind `tkg/scripts/ui/planets/PlanetView.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Ring look

Above `static var ring_style := Rings.Look.ICY`:

```text
WHICH RINGS (`Rings.Look`): ICY, Jon's pick of three (2026-10-03, "A is the
best rings") -- a broad bright ring with ringlets and a clear gap, painted per
pixel by `planet_ring.gdshader` with its shadow on the world. DUSTY and DARK
were the other two; DOTS is the ring as it was, half a ring of dots. Set
before a world is drawn (`set_world`); the harnesses take `ring=A|B|C|DOTS`.
```

## Memory clip

Above `var mem_clip := false`:

```text
THE MEMORY ONLY WHERE IT CAN BE SEEN (LOCAL's near world, `LocalSky`: drawn
hundreds of px across, much of it below its picture or past its side). When
set, the memory's pass covers only the blocks inside the picture this view is
drawn in, `MEM_MARGIN` more each way and `mem_clip_lead` more on its right
(where the picture's camera, following a ship as it leaves, brings more of
the world in), the rest of the memory left clear. Nothing outside the picture
is ever drawn from it, and a block that comes into view has been worked out
all along, so nothing seen changes. (A block left clear that did come into
view would start afresh there, as every block of a new world does.)
```

## Memory hysteresis

Inside `_mem_sync()` (now in `WorldView.gd`), above `var cl := float(maxi(_cell, 1))`:

```text
(a drift of the centre is held through; a jump starts afresh, and so does a
new size -- but not every sliver of one: the map's smooth zoom changes a
world's radius every frame, so its memory started afresh every frame and the
whole surface re-rasterised unheld, its fine features crawling and its
lights scattering as the wheel eased. Its blocks are counted from the
world's centre, so within a block of radius each still holds nearly the same
ground; the memory is kept until the size has moved a block from where it
started, and the hysteresis lets through any shade that really changed.)
```

## Memory window

Above `func _mem_window() -> void:`:

```text
The blocks of the memory its pass works out this frame: with `mem_clip`, those
the picture this view is drawn in can show (`MEM_MARGIN` more each way), and
all of them otherwise. A block's place in the memory is its px from this
view's middle, a block a `_cell`, `mem_half` in (as `planet.gdshader` counts).
Told to the shader alone, which stops at once on a block outside: its pass
stays drawn over the whole memory. (Moving and sizing the pass's rect to the
window was tried: run here, just before drawing, a control's new size waits
for its redraw, which comes a frame late -- so on every frame the window
moved, on a push-in or a ship leaving, the memory was written a block-grid
off from where the world read it, and showed as a second, smaller world.)
```
