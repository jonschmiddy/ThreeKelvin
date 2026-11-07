The reasoning behind `tkg/scripts/data/AshTutorLines.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Ash teaching

Above `const LINES: Dictionary = {`:

```text
A.S.H. TEACHING (Jon picked how A for the tutorial, Oct 17: "A.S.H. replaces
the hint cards"). Her corner says each first-run hint (`Hints`) and each goal
step (`GoalLine`) in these words, and the thing she means gets an outline.
With her switched off, the cards come back with their own words
(`Hints.lines`), exactly as before. These are Jon's picks, character for
character; `{}` fields are filled from the live game when she says them
(`fill`), never a number written here.

A LINE'S ID is the hint's id, except where one hint has several lines (the
fuel hint: a dock in reach, none, or here) and the goal steps (`step_*`).

HER VOICE: one take per line id, `VOICE_DIR` + `tut_<id>.ogg`, the folder her
other takes are in. A missing take is silence and the words still show. SHE
NEVER SAYS A NUMBER OR A NAME (Jon, Oct 18, "numbers:A"): the text shows the
live values, and a line with a field is recorded from its `SPOKEN` script
instead, so one take serves every value. The typing follows the take as her
barks do, over the SHOWN text (`AshPortrait`): the words end when she stops,
whatever the numbers make their length.
```

Above `&"drawer": "Pick a choice. Some show the odds. The rest are a surprise. NOT NOW saves it for later.",`:

```text
THE DEEP TUTORIAL (Jon, Oct 22: "Tutorial: scope:all voice:record
bugs:fix", after Kevin's playtest: he did not know the energy meter or
when to loot a dead ship). The audit's 35 rows, each checked against the
code; where the code disagreed with a draft, the words were changed to
match it. A line whose words changed after its take was recorded plays its
new take's name (`RETAKE`), so the old take is never heard under new words.
```

Above `const CUTAWAY_KEYS := "{turn} turns a part."`:

```text
AND ITS KEY, shown on a line of its own under her words and never said
(Jon, Oct 21, for 0.3.0): the key as bound (`Hints.values`' `turn`,
`Keys.describe`), so a rebound key shows as it is. The flip key's half went
Oct 22 (the deep tutorial): a flip is drawing only (`ModuleData.flipped`), so
it is not a thing to teach. Her take stays
the one recorded from `CUTAWAY_LINE` (`SPOKEN`), and the typing runs over
both lines as her take plays, as on every line with a field.
```

Above `const RETAKE: Dictionary = {`:

```text
RE-RECORDED (Oct 22, the deep tutorial): lines whose words changed after
their take was recorded. Each plays the take named here once it is installed
(`VOICE_DIR` + name + ".ogg"), and is text alone until then; the old
`tut_<id>.ogg` is never played under the new words. The scratchpad's
`tutorial-deep-voice.json` is their script. Every other new line is
`tut_<id>.ogg` as before, and silent until its take is installed.
```
