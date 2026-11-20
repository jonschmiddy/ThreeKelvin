The reasoning behind `tkg/scripts/systems/SolariScars.gd`; each heading is referenced from the code by a `Why:` line.

## Solari wear

Jon, Nov 20, on Solari's first graded set (the JUNKER scars over the noise wear): "Retry
the wear. It's so-so currently." Its C read mostly as speckle: HullGrade's grime is 3x2
noise blotches, the C primer is 12x8 noise cells, and on a warm brass hull neither reads as
anything in particular. Three ideas are on trial, each drawn on the hull's own structure:

- HEAT, heat-scarred: a ragged tint round the furnace ring (rust nearest, then a darker
  band, then a dither, reaching further above the ring as heat rises), the plates either
  side of the line scorched most near the furnace, the bells blackened back from the mouth,
  soot trailing aft from the ring's stern side, cracks run out from the ring with their
  lower lip lit, and the plate nearest the ring buckled in bands.
- PATCHED, a patched junker: plates swapped for others in another bronze (a lighter or
  darker colour of the hull's own, redder or yellower), each welded in with a bead along
  its top and stern edges and a scorched line beside it, rivet patches bolted on, and a
  plate or two gone down to the ribs.
- PATINA, old bronze: the seams filled and widened, the lower plates dulled from the belly
  up, rust bled down from under the rivets, and the orange band faded a step, flaked to the
  brass in square chips and scratched. Verdigris was asked for; the hull has no green, and
  a green would break the palette rule (`docs/why/HullGrade.md#hull-grades`), so the
  patina is the dark of the hull's own bronze.

On Solari, a chosen idea replaces HullGrade's noise wear and C primer (`_wear`, `_paint`):
the idea is the whole of the wear. The ladder is HullScars.AMT: C all of it, B half, A a
little, S none. Every colour is one the hull has, so `-- sheet=GradeSheet`'s palette check
holds, and the furnace, the line and the glass are put back as drawn after every pass
(`HullGrade._unlit`).
