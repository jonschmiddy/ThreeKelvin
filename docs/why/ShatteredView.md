The reasoning behind `tkg/scripts/ui/planets/ShatteredView.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Surface memory

Above `var _mem_vp: SubViewport` (now in `WorldView.gd`, shared with `PlanetView`):

```text
ITS SURFACE'S MEMORY (`PixelTurn.world_mode` BLENDED, the default; as
`PlanetView`'s): the shader run a second time into a picture a pixel a block
(`mem_mode` 1) that remembers each block's kind, eased value and the shade it
shows, reading itself last frame from a copy (`_mem_copy`, inside it, so it
renders first); the pieces on screen drawn from it (`mem_mode` 2). Turned
plainly, the rock's grain and the pieces' edges went A, B, A as they slid
across the pixel grid. `worldmem=off` draws it as before.
```
