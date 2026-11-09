The reasoning behind `tkg/scripts/ui/NoteCard.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Note card

Above `const WIDTH := 420`:

```text
JON'S NOTES AS A LETTER: the welcome note over the title (`WelcomePopup`) and
the thank-you note on the win screen (`GameOverScreen`), one look for both.

THE CLEAN LOOK, Jon's pick of three (Oct 13; a riveted pixel bezel and the
same bezel with a glow round it were the others): the salvage popup's
chamfered case and its readout heading -- a hazard mark, the title, a
scanline -- so the notes read as part of the same interface as the wreck you
just stripped.

Full-rect: a dim behind, then the panel centred on it. The panel is the
heading, the note (its sign-off split off and set apart: a pixel heart for
"<3", then the name, right-aligned like a letter's), whatever the caller adds
under it (`add_section`), a row of buttons (`add_buttons`) and a footer
(`add_footer`). The note scrolls only if the window is too short for the
whole panel (`_fit`). It fades in when it opens.
```
