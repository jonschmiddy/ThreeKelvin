The reasoning behind `tkg/scripts/ui/YardSound.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Yard sound

Above `const POWER_ON_SOUNDS := {`:

```text
The Yard, heard, as Jon set it on the Yard Drones page's sound panel (v46,
"bed 1 at 0 dB · welder 1 at 0 dB · drones in and out 2 at -6 st, wind-down
30%, 0 dB, at work: patch 1/2, repair 1/2, refuel 2/3, faults 2/3 at 0 dB ·
now and then: clank 1, clank 2, clank 3, airtool 1, airtool 2, hiss 2, hiss
3, hoist 1, hoist 2 at 0 dB, every 15-30 s"):

  the deal TV     powers on in its lab's sounds, each level its own ("Each
                  TV turning on should be treated different"), at the times
                  its lights strike
  the bed         one loop under every level, rising as you come onto the
                  deck and gone when you leave it
  now and then    the hall's distant work, one take every 15 to 30 s, never
                  the same twice running and another kind when there is one
  the welder      his arc, on while it burns and off when he lowers the
                  torch, a little to the right where he stands
  the drones      a whir in, winding down as each brakes to a hover and
                  stopping at 1.6 s ("ramp it down less aggressively": 30%),
                  the same whir whole as they fly away, both six semitones
                  down; and each service's own sound as its work lands on the
                  hull, panned to where it happens. Hovering is silent.
  the flickers    a light that stutters ticks on the frame it goes dark: a
                  70 ms slice of its lab's flicker, cut off by the next, so a
                  buzzing bulb crackles exactly as fast as it flashes; a pop
                  snaps louder

Every file's level is baked in (LUFS-matched to the labs' sounds): all of it
plays at 0 dB on the Ambient bus, beside the station's crowd and PA. None of
it in the sim or a headless run.
```
