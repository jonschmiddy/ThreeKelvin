The reasoning behind `tkg/scripts/sim/DerelictShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Derelict shots

Above `const ID := &"derelict_hauler"`:

```text
THE DERELICT HAULER'S SCRAP, photographed for Jon's Phase 10 pick (Oct 29:
"I don't understand Derelict hauler · SCRAP"):
  godot --path . --windowed --resolution 1920x1080 -- sheet=DerelictShot out=<dir> [seed=4242]

A heavy Korvan at a derelict whose frame is light, as Jeremy met it:
  1_page      the derelict's page on LOCAL, the claim naming the frame
  2_result    YOU CHOSE, the frame claimed
  3_rail_A    LOCAL's rail with the frame on offer: TAKE IT and SCRAP (as built, pick A)
  4_rail_B    the same row with LEAVE IT put back beside SCRAP (pick B, the real
              row's own button added, not built anywhere else)
Each also as `<name>_crop.png`, the part that matters at 2x. Prints what the
strip pays and what SCRAP pays. Needs a window.
```
