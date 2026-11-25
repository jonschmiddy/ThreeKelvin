# TarpMark

## stencil

Jon, Nov 24, on a locked Calyx in the Old hangar: "The Calyx Biosystems logo isn't on these ships." Every manufacturer's
tarps carry its banner emblem, stencilled on the cloth when the tarps were made (`tk-scratch/yard-tarps/gen/src/emblem.py`:
the `YardBanner.EMBLEM` rects, about 27, 36 and 45 px across on the light, medium and heavy, fold-shaded and worn).
Calyx's export missed it: its tarps showed a faint green smear and the specimen patch, no cross. The other five were
checked at all three weights (Solari's cross, Probate's stack, Redline's two blocks, Verity's two bars, Cygnet's
bars and body) and all five carry their emblem. `YardSeatTest` measures every one, so a tarp that loses its mark fails.

The fix is in code, not in the PNGs, so the mark stays the manufacturer's own (its `colour`, its `EMBLEM`) and lands
the same on both copies of a tarp: the yard's art (`art/sprites/station/yard/tarps/`) and the Old hangar's dusted,
padded wind texture (`shiprooms/old/tarps/`, the art 6 px in, the hold field under it). `texture()` stamps once
a session per path and caches the result.

- **Where.** `AT` gives each stencilled tarp its centre, its unit (Solari's cross's span over nine units: 3, 4 and
  5 px) and its tone. The medium's and heavy's centres are Solari's cross's. On the light, Solari's spot is where
  Calyx's old smear is, so the cross moved right of it, clear of the patch.
- **Probate's light.** Jon, Nov 24: "The light probate ship tarp is too flat compared to the others." It was
  redrawn (his pick b1 of four: PixelLab pixflux at strength 150 from the medium's cloth fitted into the light's
  own outline, the light's chains pasted back; `tk-scratch/shipselect/port/tarps/probate_light/`) without a mark,
  and is stencilled here where its old mark was, at tone 1.3 to match the medium's cream. Its Old hangar texture
  was rebuilt by export.py's own steps (`wind.py` there, byte-identical on the old art first).
- **The hangar's clamp.** The hangar's shader holds a tarp's pixels to the cloth's lightest and darkest (the
  wind texture's param row). A pale mark on a dark cloth would be held down to the cloth's lightest, so the
  stencil widens that range to take its paint.
- **The paint.** Each cloth pixel under the emblem becomes the mark colour x tone x its own brightness over the
  cloth's median round the mark (held to 0.55 to 1.35), so the folds show through it. Calyx's tone is 0.65: at
  its own colour (tone 1) the green read as a pale patch on the mint cloth; a darker stencil read as paint.
- **Only on cloth.** A pixel is painted only when it and its four neighbours are opaque (the hem and the outline
  stay) and its chroma is within 0.06 of the cloth's median (clips, straps, the patch and the dust stay over it).
- **Worn.** A fixed hash of the art pixel leaves 8 % of the inside and 28 % of the edge bare and fades 18 % more
  halfway, so both copies wear alike. It is a hash, not `Rng`: the picture decides nothing.
