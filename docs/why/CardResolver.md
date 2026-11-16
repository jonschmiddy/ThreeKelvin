The reasoning behind `tkg/scripts/systems/CardResolver.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Vent dissipation

Inside `resolve()`, above `var v := mini(Run.heat, c.vent + Run.dissipation())`:

```text
PLUS THE SHIP'S DISSIPATION, which no longer sheds on its own. The
stat's prominence is finally earned: it was half of attr_thermal and
worth one point a turn, and it is now a multiplier on a decision the
player makes rather than a drip that happens to them. Fifteen vent
cards get better and stop competing against free automatic cooling.

`vent_all` is untouched -- it already zeroes heat and there is nothing
for a multiplier to add to.
```

## Heat blast

Above `static func heat_blast(shed: int, cb: Combat) -> void:`:

Jon, Nov 16 (Solari pick 2A, named Heat Blast): the 3-set was a flat +2 a hit on
Solari damage cards. It touched 16 of 40 cards, favoured the multi-hit guns and
asked nothing new. Now every vent hits: the enemy takes half the heat you shed.

- **Every vent, whoever made the card.** "When you vent heat" reads as any vent, so
  that is what it does: a shared Bleed Heat or a Korvan coolant card counts. Only
  Solari's own vents would need the text to say so, and a vent is a vent.
- **Rounded up**, as Ignition rounds its halved burn up. Shedding 1 still hits for 1,
  so a vent never does nothing with the set on.
- **Thermal Purge counts.** It hits for heat + 2 and then purges, so with the set it
  hits again for half. That is the "build up, then dump" turn the pick asked for.
- **One hit, no lock-on, not an attack.** It goes through the foe's block and brace
  like any hit, but it does not spend lock-on or count toward Salvo.
- Card previews do not show it: it is a second hit, not the card's own number.
