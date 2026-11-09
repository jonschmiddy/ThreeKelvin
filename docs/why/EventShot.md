The reasoning behind `tkg/scripts/sim/EventShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Event shot modes

Above `const FPS := 30.0`:

```text
EVENTS RESOLVED ON LOCAL, photographed (`LocalEventDrawer`):
  godot --path . --windowed --position 3840,0 -- sheet=EventShot keepwindow
      out=<dir> [seed=1] [node=11] [layout=row|column|card] [flow] [compare] [reveal]
      [revealav=<dir>]

`flow`     the map's list, an event's page (one sentence and GO), GO -- the
           flight and the zoom down, filmed into `flow/` -- the band up, the
           result, the bar under the view after CONTINUE, the map with the
           event stamped, and a fight event to its hand. Stills `01_`..`08_`.
`compare`  a short, a medium and a long event (the shortest, middle and
           longest bodies in `OptionTable`) in all three layouts, each still
           as the game draws it (`cmp_<layout>_<size>.png`), with the empty
           area of the drawer -- pixels that are bare panel, no text or card --
           printed as `[eventshot] empty <layout> <size> <px> <of> <share>`.
`reveal`   the medium event's text arriving (`SignalText`), one layout,
           stepped on a fixed 30 fps clock so the frames play at true speed,
           into `reveal_<layout>/`.
`revealav` the same reveal SEEN AND HEARD on the real clock. The text runs
           itself and the SFX bus is drained from an AudioEffectCapture every
           frame (as FlightClip's tape) into `<dir>/audio.wav`; Music and
           Ambient are muted. About 30 frames a second are saved with their
           times (`frames.txt`, "index seconds") so ffmpeg can lay them to the
           sound. Prints the blips played (`Audio.tape`) against the letters,
           and the most `text_blip` voices ever sounding at once, with and
           without the ones fading out.
Needs a window.
```
