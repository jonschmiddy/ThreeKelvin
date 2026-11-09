The reasoning behind `tkg/scripts/ui/FaunaGuard.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Fauna guard

Above `static var enabled := true`:

```text
BLOCK, BRACE AND DAMAGE ON A LIVING CREATURE (Oct 13). Jon, of the Void
Leviathan in a fight with the plated brace on it: "The void leviathan having
plating or shield is kinda weird", and "the damage to the void leviathan and
voidwhale calf should be more organic... not ship damage". The bubble
(`ShieldFx`), the plates (`BraceFx`) and the hull marks (`ShipHitFx`) are
machine looks; on the Voidwhale Calf and the Void Leviathan (`wants`)
`HitLayers` lays these instead, Jon's picks of three ideas each ("block:A
brace:A damage:A+B+C"). The Custodian is a construct and keeps the ship
looks ("custodian C"); so does every ship.
  BLOCK  (`FaunaShield`)  GLOW SKIN: its own outline lit cold, breathing with
                          it, packets of light running head to tail; a hit
                          runs a ring of light over the skin; at 0 it gutters
                          out pixel by pixel.
  BRACE  (`FaunaBrace`)   HARDENED HIDE: the hide darkens and goes glassy
                          teal, a rim light along its back and a sheen
                          crossing it; hits flake patches off.
  DAMAGE (`FaunaHitFx`)   WOUNDS, BRUISES and SHED scales, rolled per hit;
                          its lights die and, badly hurt, it trails vapour.

WITH THE BODY, NOT OVER IT. Everything is drawn in the picture's own rest
space and shown where `FaunaMotion` shows that pixel now: a shader layer
(`GuardSkin`, `PRELUDE`) maps each pixel through the motion's own column table
(the swell, the spines' lift, the flippers' sweep), and motes and flakes
take `FaunaMotion.off_at` at their foot. Damage is baked into the picture the
motion is cut from, so it moves as the body does for nothing. Steps are the
motion's (8 a second the Leviathan, 12 the calf), on its own phase, so a
guard's step and the body's never land a frame apart (flip-backs).

NOTHING ON THE WORDS. `HitLayers.keep` holds the intent words and the
readout (name, bars, hull, chips) in this layer's space; no mote is drawn and
no shader pixel lights inside them.
```
