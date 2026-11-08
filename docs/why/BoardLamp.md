The reasoning behind `tkg/scripts/ui/BoardLamp.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Board lamp

Above `var dev := 2:`:

```text
THE LIGHT ON THE HIRING BOARD, and the room it leaves dim.

Jon, 2026-10-01, after 80 generated boards lost to the coded one ("the
aesthetic of the computed placeholder is kinda the vibe i liked"): keep the
board, light it, dust in the light, and a power-on once a docking like the
Shipyard and the Laboratory. Then, of a hanging lamp: "why dont we just use
the lighting from the labs or something like that. flourescent bars"; and
of the bars on the rail, "no light bar and just have it lit from behind?
same flicker and all". So the board is lit by tubes nobody sees, over the
viewer's shoulder: one at an unclaimed station, two at an outpost or a
settlement, three in a city or a capital, in the level's colour.

THE TUBES BEHAVE LIKE THE LAB'S. On the power-on they strike one after
another, the fluorescent ping, gentler than the lab's (`catch`); after that
each stutters now and then on its
own clock (`YardLight.stutter`, the lab's tubes), and an unclaimed station's
one tube is the tiredest.

A LAYER OVER EVERYTHING ON THE BOARD, notices included, because a light
lights the paper pinned to the board as much as the board. It takes no
clicks.

THE LIGHT IS A MAP, NOT A HAZE: banded, dithered at each band's edge, worked
out once for the board's size and level and kept as two textures -- the
room's dark and the tubes' light, added -- that the tubes only scale.

THE NOTICES HAVE TO STAY READABLE. They are the deck. So the room never goes
more than DARK away from the light, and dead tubes take only OFF more.
```

## Board sounds

Above `const STRIKE_SOUND := [&"lab_unclaimed_bulb", &"lab_outpost_lamp", &"lab_settlement_lamp"]`:

```text
THE TUBES, HEARD, with the sounds Jon passed for the same level's lab (Lab
Sounds, 2026-09-28) -- AND HEARD AS THEY ARE SEEN (Jon: "Cant we just have
the sounds match how the lights look for the hiring board?"). The sound
follows the board's light, not a timetable: every flash you see as the tubes
strike, and every stutter after, is a flicker; the lamp's clunk-and-hum
plays once, on the frame the board settles fully lit. Two tubes striking in
turn used to be two clunks 0.3 s apart over a board that just looked
flickery. A screen has no tubes: its backlight catches with the lab's monitor
pop and the level's display swelling up. Every level is baked into its file,
so each plays at 0 dB.
```
