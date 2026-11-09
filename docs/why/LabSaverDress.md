The reasoning behind `tkg/scripts/ui/LabSaverDress.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Each owners dressing of the seven

Above `const LIGHTENED := ["big", "LIGHTENED PARTS", "TURN FASTER.", "+2 MNV, -1 HUL."]`:

```text
EACH OWNER'S DRESSING OF THE SEVEN KEPT SAVERS (Jon, Nov 7: "S:B,1,2,3,4,5,6
OWNER", all seven kept, in the owner's dress). The savers (`LabSavers` B and
1 to 6) draw the same pictures at every Lab; what changes per owner is here:
its colour where the lab's ink was plain, the words it logs, its posters.
From the r6 review's dressing notes (review_lab/r6, one per owner).

Keys, every one optional (`of` fills the rest from `BASE`, the undressed look
an independent lab shows):

  acc          the owner's accent, or null for the lab's own ink
  B   b_hub    the flight computer's glow in the accent
      b_pulse  the DATA running down the owned arms in the accent
      b_owned  the owned steps' rings in the accent
      b_diamond  the DATA drawn as small unit diamonds (Cygnet)
  1   s1_label   the column's label over the target
      s1_cross   the crosshair in the accent
      s1_style   "" plain; "navy" TARGET n and RANGE; "heat" TEMP first in
                 the accent and the star in the heat ramp; "mask" the name
                 under a hatched bar; "rules" the crosshair as two rules and
                 a hairline; "hex" a hex aperture and UNITS NEAR n; "bio"
                 SPECIMEN VIABLE and the fauna
      s1_band    a riveted band under the header (Korvan's card hem)
      s1_foot    the count at the foot (%d); s1_foot_short where it will not fit
  2   s2_label, s2_code (%d, or no number), s2_done   the column's words
      s2_shape   "crystal", "pod", "housing" or "fitting"
      s2_heat    the spectrum in the heat ramp
      s2_field   the box filled with the owner's field, faintly, and the
                 specimen's wire in the accent
      s2_node    the code seeded from the station, not the owner
  3   s3_title   the header after the owner's name; s3_full replaces both
      s3_counter, s3_base   the counter's label and where it starts (-1: by owner)
      s3_own     the owner's own lines, in its voice
      s3_src     the owner's rows' source (%d the lab's number, or none)
      s3_stamp   whether the owner's rows carry a time
      s3_every   seconds between lines
      s3_units   a third of the rows from units, not pilots (Cygnet)
      s3_open    no lab of its own: pilots and the seven manufacturers only
  4   s4_title (after the name) or s4_full; s4_tag what each part's callout
      adds: "navy", "heat", "scrap", "heal", "serial", "appt" or ""
      s4_own     only the owner's own parts take the accent
  5   s5         the five posters
  6   s6_route   the route in the accent; s6_disc the arms in it; s6_heat
                 the disc in the heat ramp; s6_core the core's colour or
                 null; s6_beat the core's pulse (s); s6_right the words top
                 right ("" the galaxy's name); s6_mark the sign on the
                 owner's own stations ("sun", "diamond", "tick", "flag");
                 s6_claims the foot counts those on your route; s6_arcs
                 where you are drawn as two signal arcs
```
