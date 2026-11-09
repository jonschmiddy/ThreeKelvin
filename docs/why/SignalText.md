The reasoning behind `tkg/scripts/ui/SignalText.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Signal text

Above `signal char_settled(index: int, ch: String)`:

```text
TEXT THAT ARRIVES LIKE A SIGNAL (Jon: "let's have the text read in letter by
letter ... like a signal transmission? IDK something stylized"). Each
character comes in as one or two scrambled glyphs from the pixel font before
it settles on the true letter, with a block cursor at the leading edge and,
now and then, a short dropout. At `cps` a second, punctuation holding a beat.

THE LAYOUT NEVER MOVES: the whole text is broken into lines and measured
before a character shows, so the control is its full height from the start
and nothing reflows while it reveals. Drawn by hand in the game's pixel face
(`UITheme.pixel_font`), one character at a time.

`skip()` finishes it at once; reduced motion (`Router.animating`) shows it
whole.

THE SOUND is Jon's pick from the audition page: "cps 40 · A blip_5 every 3,
±100c, 0 dB · B off · C off". Every third settled letter plays `text_blip`
(spaces do not count), pitch spread ±100 cents, at its levelled gain, with at
most two in the air (`Audio.play_capped`). Only a settling letter makes a
blip. So `skip()` finishes silently and also fades any tail still ringing,
and reduced motion, which has no reveal, has no blips.

`by_word` (the event band, issue #38) settles whole words, one blip each, so a
long body never shows half a word; no dropouts, which would cut one again.
```
