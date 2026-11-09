The reasoning behind `tkg/scripts/ui/AshPortrait.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## A.S.H. portrait

Above `const SHEET := "res://art/ash/face.png"`:

```text
A.S.H. SPEAKING (`Ash` decides when and where): her hologram face, with the
line arriving beside it in the event band's signal type (`SignalText`), under
her designation. It comes up, the line types out, it holds long enough to
read, and it fades.

THE FACE IS ONE FILE, `art/ash/face.png`: eight 64x64 frames in a row --
closed, slight, open, round, then the same four with her eyes shut -- made by
`art/tools/ash_face.py` from the frames hand-drawn on B15. Swapping her face
is swapping that file. Drawn at the game's own pixel (64 game px, 128 on a
1080p screen), at whole-pixel places, never scaled or filtered.

HOW SHE MOVES, all of it on `GameClock` (a film runs it at the film's speed),
stepped TICK_S at a time so every change is a held frame and no faster than
the tick (Jon judges motion per second; the fire ruling put living things at
8-12 changes a second):
  - THE MOUTH FOLLOWS THE LETTERS: each tick it takes the shape of the last
    letter that settled in that tick (a vowel open, o/u/w/y round, m/b/p
    shut, any other letter slight; a space or a mark shut), and a shape the
    same as the tick before gives way to another (open or round to slight,
    slight to shut, shut to slight) so a mouth that is talking moves every
    tick. Shut through a mark's pause, and once the line is out.
  - SHE BLINKS for one tick every 2.2 to 5.7 s.
  - THE HOLOGRAM SLIPS: a band of one to three rows shifted a whole pixel
    sideways for one tick, with a faint lit row over it, every 0.9 to 3.5 s
    while she talks and every 2 to 6 s while she holds; twice as often with
    the hull failing (`docs/ash.md`: "the image breaks up"). Two ticks of it
    as she comes up, which is her power-on.
Reduced motion keeps the face and the words and drops the slips and the fades
(the line arrives whole, so the mouth stays shut).

IT IS NOT A CONTROL, and does not look like one: no plate edge, no hover, no
hand; it ignores the mouse, so a click lands on whatever is under it. The
words sit on the dim edgeless backing the goal line uses (an edged box is
what this game's buttons look like). Nothing dismisses it but time.

THE SOUND: her power-on is two of the event text's own `text_blip`, the
second a minor third up, at her appearance and at the end of the power-on
slip, at the text's own level (Jon, Oct 17: "the beep when ash comes in can
be a little louder": it was 3 dB under). THEN HER VOICE (`AshLines.VOICE`,
`Audio.ash_voice`), VOICE_AT after she appears: after the chirp rather than
under it. Measured over all 30 takes at their in-game levels, the chirp
against her first quarter second: at -3 dB and 0.3 s it sat 27.5 dB under on
average and 18 at worst; 3 dB up at 0.3 s that was 24.5 and 15, so her voice
moved to 0.35 s, which gives back 26.9 and 17.5 (started with her, the louder
chirp would sit only 6 dB under at worst, the second blip's click inside the
first word).
HER POWER-DOWN IS THE POWER-ON REVERSED (Jon: "Can the sound go in reverse
when she goes away?"): the same two blips, each played backwards
(`text_blip_rev`, the file reversed, so the same level), in mirror order and
mirror time, so the second blip's reverse ends as the fade starts and the
first's ends on the frame the projection goes. Only when a line ends of
itself: it has to start before the fade does, which only a natural end
knows, and the other exits (END TURN, a hint, a card picked up, something
in her box, Settings, the ship lost) are the game taking the floor, with
sounds of their own, and she is gone in a tenth of a second; a power-down
there would land after her and over them. A cut while it plays hushes it.
The words start typing WITH the voice, at the speed that ends them when she
stops (`SignalText.rate_for`, over the take's length less VOICE_TAIL_S), so
the mouth, which follows the letters, follows her. A line with no take yet
types at once at the text's own speed, as before. Wherever her words are cut
or sent off (`cut`, `leave`) the voice stops too, faded (`Audio.ash_voice_stop`).
```
