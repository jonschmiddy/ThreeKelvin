The reasoning behind `tkg/scripts/ui/sysmap/CoreLegacy.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Core black hole

Above `const SHADER := preload("res://shaders/core_legacy.gdshader")`:

```text
THE CORE ON THE SYSTEM MAP, in every style: the black hole Jon fixed for every
style from the Oct 5 showcase (direction C's: "This is the best black hole
rendition we have gotten. I love this shape and perspective. I want this no
matter what style we pick."), the same one the star chart draws, from the
shared `legacy_hole.gdshaderinc` (its photon table traced once a process by
`LegacyHole`). `core_legacy.gdshader` draws it, the map behind bent through
its lens and lit by its disc.

SIZED AMONG THE ORBITS: the shadow is SHADOW map pixels across at star_k
1, so the disc's outer edge (three shadow radii, 116 px) is where the fabric
and the orbit lines already stop round the core, and it grows with the map as
the old hole did (`SystemView.star_k`, never under 1).

In the map's order it sits where `CoreView` sat: among the worlds, after the
ones behind it (which its lens bends) and before the ones in front. It keeps
`CoreView`'s handles for the weather (`_hmat` with `hs` and `rf`,
`drawn_zoom`, `breath_add`, `ready_to_draw`, `next_plunge`).
```
