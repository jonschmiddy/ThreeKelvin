The reasoning behind `tkg/scripts/ui/Ash.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Ash behaviour

Above `const SECTION := "ash"`:

```text
A.S.H., THE SHIP'S AI, SPEAKING (Jon and Ashlee, Oct 17; `docs/ash.md`; the
ruling "A.S.H. is the ship, not crew"). Her face comes up in a small hologram
frame on LOCAL and in fights, says one of the thirty approved lines at the
moment it was written for, and fades (`AshPortrait` draws it; `AshLines`
holds the lines), in her voice as it types (`AshLines.VOICE`, `Audio.ash_voice`).

THE MOMENTS, each line's own (`AshLines` has the list):
  launch  a new run, once the ship is at rest on LOCAL; gone at the first jump
  hull    the first time she is up in a hull BOUGHT at a station's yard mid-run
          (after the dock, never in it); not if the move is called off, and
          never for the chassis select, a load or a hull found in the field
  hurt    the hull at a quarter or under, alive; again only after it has been
          back over half
  hot     over the heat cap in a fight; once a fight
  haul    a chit of HAUL_CREDITS or more, or an epic or better part, taken
          aboard on LOCAL
  greed   the third wreck opened since you last docked, and every third after
  doubt   arriving somewhere new, DOUBT_CHANCE a time, at least DOUBT_EVERY
          jumps after the last one and never before jump DOUBT_FROM
A moment waits for its chance (`WAIT_S`) and is dropped if it does not get
one: a line about the heat said once the heat is gone would be about nothing.

SHE INTRODUCES HERSELF EVERY NEW RUN (Jon, Oct 18, "intro:A"; Oct 20: "On the
first LOCAL section you load into on a new game, A.S.H. should introduce
herself. Short beat. THEN the first tutorial hint." -- every run, not once a
profile). A new run's launch line is `AshLines.INTRO` (launch_04,
"Autonomous Systems Handler, reporting..."), not a pick from the bag; a run
picked up with CONTINUE does not hear it again (`SaveGame.restoring`), and
its launch, if it is still before the first jump, is the bag's. Same moment
and slot as any launch line; the one difference is the order: the hints and
the goal steps wait for it (`intro_holds`, read by `Hints`), where every
other bark waits for them, so her first words are her name and no lesson
cuts them; and after it ends, a beat (`INTRO_BEAT_S`) before the first of
them. The once-a-profile flag it had (`[hints] ash_intro`) is not read any
more; an old settings file that has it loads as before.

SHE NEVER TALKS OVER HERSELF OR EVERY TURN:
  - one line at a time, and COOLDOWN_S of quiet after one before the next;
    the big moments (hurt, hull) wait only BIG_GAP_S;
  - at most ONE line a fight, unless the hull starts failing in it;
  - in a fight, only on your turn with the hand settled: never during a card
    drag, the enemy's turn, a number in the air, the flee or hail question;
    END TURN mid-line sends her off at once;
  - she does not start over a jump, an arrival, the camera moving between
    distances, the cutaway, a wreck's window, the event band, the escape menu.
ONCE STARTED, A LINE PLAYS OUT (Jon, Oct 22, after the first outside playtest:
"He also clicked to make her shut up when she was giving her quips"): nothing
the player clicks cuts it. A card picked up or dragged, a wreck's window, the
pile or SECTOR LOOT opened, the event band raised: she stays unless what came
up covers her box (`_must_go`). A hint coming due waits for her to finish
(`Hints`, `bark_up`). What still takes her off: the screen itself going (a
jump, the camera moving, another screen, the escape menu), END TURN and the
enemy's turn (their numbers land where she stands), something in her box,
the ship lost, her switch, a new run.
NOTHING AFTER THE SHIP IS LOST (Jon: "No lines after the ship is lost. The ship
has blown up."): she is the ship. Up when it goes, she cuts with it, no fade.
HINTS WIN (`Hints`): she does not start while a hint is up, settling or due
on this screen.

SHE NEVER COVERS ANYTHING. She stands at the first of `SPOTS` that is clear of
everything listed in `avoid_rects` (the HUD, the goal line's band, the event
band and the bar under the view, the hand and its buttons, both ships and the
words, plates and shield ovals round them, the wrecks, an event's subject, a
number in the air, a hint card, a side bar) and inside the view; with none
clear she waits. Once up she does not move: if something comes into her box
she goes. `-- sheet=AshTest` holds her to that on every screen she shows on.

OFF UNDER HARNESSES (`TestRun.active`) unless the run asks with `-- ash`;
`-- sheet=AshTest` turns her on by hand (`forced`). Off for good with Settings'
SHIP'S VOICE (`[ash] on` in the settings file, the harness's under a harness).

IN CO-OP each machine's A.S.H. is its own ship's: she reads this process's
`Run` and nothing else, sends nothing, and nothing waits on her, so a shared
fight's barrier never does. A partner's hull failing is not yours.

SHE TEACHES (Jon picked how A for the tutorial, Oct 17: "A.S.H. replaces the
hint cards"). While she is on, each first-run hint (`Hints`) comes in her
corner in her words (`AshTutorLines`), the thing she means outlined, instead
of a card; and each goal step (`GoalLine`) is said once as it starts. The
hints keep their triggers, their order and their subjects (`Hints` still
decides all of it and calls `teach`). A teaching line:
  - outranks a bark: none starts while a teaching line is up, settling or due
    (her "hints win"); one already under way plays out first (Oct 22);
  - is not held to her quiet, her one line a fight, or her keeping off the
    cutaway, a wreck's window and the event band;
  - stands on the STARCHART, the SECTOR map and the station as well as LOCAL
    and fights, at the first spot clear of everything there (`tut_avoid_rects`,
    `covers`: every system and world a click picks, their words and orbits,
    every button, the yard's ships, drones and screen);
  - a hint's holds once it is out until the player has done what it teaches
    (`Hints.DONE`; Jon, Oct 22: "Can we soft lock the screen so A.S.H. can't
    be dismissed?"), never a click; an information line's (`Hints.INFO`) and
    a step's hold for their reading time and go.
Off in a party, as the hints are (`Hints.enabled`, "coop:B"). Off with her
switch, and the cards come back exactly as they were.
```

Inside `_watch()`, above `if Run.hull != _known_hull:`:

```text
A NEW HULL: armed when the frame changes BECAUSE ONE WAS BOUGHT at a
station's yard (`Run.hulls_bought`; Jon, Oct 18: only "when a player buys
a new ship mid run" -- never the chassis select's picks before launch, a
load, or a hull found in the field), said the next time she is up, on
LOCAL or in a fight, so never mid-dock; and forgotten if the move is
called off and the old frame comes back (`Run.abandon_move`)
```

## Comms log

Above `var comms: Array = []`:

```text
HER COMMS (Jeremy, a playtester, Oct 23: "Give me an option to revisit all
communications"): every line she has said aloud this run, her quips and her
teaching lines and steps, oldest first, each {kind, line, voice, jump,
tutorial}. In the log once her words have started (a line cut before a word
is not in it); a line back quietly is not said again, so not again in it.
The HUD's COMMS tab lists it newest first (`CommsPanel`), with her voice to
play again. Kept with the run (`SaveGame`, `ash_comms`); a new run's starts
empty.
```

## Spot placement

Above `static func _under_goal(r: Rect2, cur: Control) -> Rect2:`:

```text
A TOP SPOT THAT WOULD STAND ON THE GOAL OR ITS STEP (`GoalLine`: at the top
left of the picture on LOCAL, the map and the chart, Jon, Oct 20) stands
under the two of them instead, EDGE below the step's room. In a fight beside
the goal's line instead, at the same height (a fight has no step, and under
the goal is your hull: the 65 screens of `AshTest` measured that corner as
the one clear in every fight). A spot that already stands below the goal's
words (under the band under the HUD) and only comes within EDGE of the
Custodian's badge, 2 px taller than the words, steps down under it instead.
```

## Teaching lines

Above `func teach(lid: StringName, text: String, hint: StringName, subject: Rect2, opts: Dictionary = {}) -> bool:`:

```text
Say teaching line `lid` (`AshTutorLines`) now, its words `text` (filled),
pointing at `subject` (global; Rect2() for none). `hint`: the hint it says,
held until let go; "" for a goal step, which goes after its reading time.
`opts`: `voice` and `spoken` (`AshTutorLines.voice_path` / `spoken`), and
`held` (false: an information hint, gone after its reading time). False
if she cannot: off, or nowhere on this screen clear for her (`tut_spot`).
```

Above `static func tut_avoid_rects(cur: Control) -> Array:`:

```text
EVERYTHING A TEACHING LINE MUST NOT COVER on `cur`, global: her bark list
(`avoid_rects`), and the toolbar row's pieces; over the cutaway its panel,
its exploded ship and its popup; over a wreck's window the window; on the
chart and the map every control in the picture, the scale and the words; on
the station the decks, UNDOCK, every button and word, the yard's ships and
their names, its drones and its screen. What a click picks in a picture
(a system, a world, a beacon) is `covers`.
```
