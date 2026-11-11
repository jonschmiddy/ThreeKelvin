The reasoning behind `tkg/scripts/sim/AshTutorTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Test overview

Above `const HintActs := preload("res://scripts/sim/HintActs.gd")`:

```text
A.S.H. TEACHING (Jon picked how A for the tutorial, Oct 17: "A.S.H. replaces
the hint cards"), on the real screens, headless:
  godot --headless --fixed-fps 60 --path . -- sheet=AshTutorTest

THE USED STATE, NOT THE FRESH ONE: a run already under way, a line of hers
already said, a settings file with hints seen, reset once and one seen
since, in the harness's settings file. The hints' clock is stepped by hand
(`Hints.poll`); hers runs on the game's.

THE LINES are Jon's picks, character for character, their fields filled from
the live game (the hand, the heat cap, the dock and its jumps, the keys), and
every one fits her frame on every screen.

EACH MOMENT, through the real screens in the order a first run meets them:
the goal steps on LOCAL, the chart and the map; the chart's list; the map's
events; LOCAL's wreck, loot and ship; the cutaway; the event band; a wreck's
window; a fight's hand, intent, END TURN, brace and heat (five lines, one
fight); the station's decks, each deck the first time it is open (the yard,
the Promenade, the Exchange, the Hiring Board, the Laboratory), its yard's
ship and its cutaway; fuel low with a
dock in reach, none, and here. Each is her line with the right words, in her
corner and not a card, the outline on the hint's own subject.

THE DEEP TUTORIAL (Jon, Oct 22: "Tutorial: scope:all"), in the same walk: the
map's fuel on the first arrival and flying by hand; the chart's layer strip,
a JUMP that cannot go, a signed job's ring and a mark; LOCAL's hull; the
band's odds and a result with REWARD; the cutaway's mounts, its cards from a
fitted part and the ship's stats; a first fight taught over its turns (the
hand, energy and END TURN on turn 1, then a lesson at each turn's start: the
intent, a card's heat corner, heat, brace, underlined words; a discard asked
for mid-turn; a malfunction), a second (FLEE and HAIL, the hull at half) and a
third (the piles, turn 2); the yard's FAULTS, a ship for sale and UNDOCK; the
escape menu's SAVE & EXIT (said over the menu); the chassis select's card.

NO CLICK DISMISSES HER (Jon, Oct 22, the first outside playtest: "Can we soft
lock the screen so A.S.H. can't be dismissed?"). Real clicks, through the
viewport, on her box (where Kevin clicked) and at seeded points in it, on
every line of that first run: each stays up and unspent until the player
DOES what it teaches (`HintActs`: the row, the card, END TURN, the deck's own
handler), and that spends it; an information line (`Hints.INFO`) goes by
itself after its reading time, spent; a goal step after its reading time.
Every hint is taught exactly once each time it is armed, and the run finishes
it. NEVER STUCK: a line said whole with another waiting gives way unspent and
comes back; a hand with nothing playable has no hand line, and END TURN's
comes instead. THE SOFT LOCK (option b, off): while she speaks, the gate takes
every click but where she points, and none after.

THE BOX TEST on every screen she speaks on: her box inside the view and clear
of a list gathered HERE, apart from `Ash.tut_avoid_rects`, so she cannot pass
by agreeing with herself -- the HUD, the goal line, every button and word on
the screen, every control that takes the mouse (but the backdrops that hold
the whole view), what she points at, and in the pictures what a click picks
(the chart's systems, the map's worlds, beacons, star and belts, its orbits,
the yard's drones and its TAKE IT), each asked of the picture's own hit test
at every 2 px.

A BARK NEVER INTERRUPTS A TEACHING LINE, and a teaching line due waits for a
bark already under way to end of itself (Jon, Oct 22: a quip "plays out").
HER INTRODUCTION (intro:A) is the exception: a fresh profile's first launch
says launch_04 first, the step waits for it and follows; never forced again.
HER VOICE: no take is silence and the words alone at her text pace; a take
types at its pace, and the shown words (numbers and names in them) end when
she stops; what she says has no field and no live number. OFF: her switch
off brings back today's cards, exactly, mid-lesson too; and in a party there
is no teaching at all. THE DECKS (Jon, Oct 20): each deck's line up until the
deck is used, or said whole and left (then spent: said once); left mid-line,
it comes back; queued behind the dock's (picking a deck is the dock's
action); off with TUTORIAL OFF, back with REPLAY TUTORIAL, a card with her
off, nothing in a party; her box clear on each deck.

SAID ALOUD ONCE (Jeremy, a playtester, Oct 23; Jon's 0.4.1 log): over the
whole walk no take of hers plays twice, and a line set up again after she
said it whole is back as text only. At her real pace: heat across the turns
of one fight, the chart left and come back to, the hull's line cut off on
three visits, information spent as it shows (`_said_once`). COMMS (Jeremy's
ask): the log in order, PLAY, the tab and the table's fit, the save
(`_comms`).
```

## Map fly line

Above `func _map_fly_world(m: SystemMapScreen) -> void:`:

```text
THE MAP_FLY LINE POINTS AT A WORLD (Jon, Nov 4: "Shouldn't a world be
highlighted here and not my ship?"): her subject holds a planet's or the
giant's place on screen and not the ship's, follows that world round its
star (the map's clock run on six minutes over two seconds, then put back)
until the world's box meets the ship's, at least a second's frames, and from
then on is on a world clear of the ship, as `Hints._fly_world` keeps it (G2's
seed 4242 swings its world past the ship at frame 104 of 120, Nov 10),
and is on the ship in a system with no world (its worlds made belts for one
probe, put back at once: every system has one). The world is one a click at
its middle picks, and not one under another place's beacon (seed 4242's
LAMBDA ABYSSAL IX); with the ship on that world the outline is on another,
clear of the ship; and with the ship drifting (no star orbit, so a click
does not fly) it is on the ship. Each of those for one probe, put back.
```

## LOCAL event flow

Inside `_flow()`, above `var oi := -1`:

```text
LOCAL AT AN EVENT'S OWN PLACE, WITH A WRECK THAT HOLDS SOMETHING AND A PILE.
LOCAL opens the event there as GO does (Jon, Oct 21: "Clicking GO or
clicking LOCAL should have the same result"), so its band comes first and
she teaches it; the scene's own lessons -- the wreck, the loot, your ship --
wait behind the band and come, each once, as soon as it is down. The step
("click an event, then GO") is done by the event opening: never said over it.
(an event the system already has, at a world: one planted now stands
nowhere, `SystemLayout.place_of`, and LOCAL opens only the place's own)
```

## Never stuck

Above `func _never_stuck() -> void:`:

```text
NEVER STUCK: no line holds the goal or another hint for good. LOCAL with the
pile's line (SECTOR LOOT) and your ship's both due: the loot's, higher, is
said, clicked on and left; said whole and up YIELD_S with the ship's waiting,
it gives way unspent and rests; the ship's is said; when the loot's rest is
over the ship's gives way back and the loot's returns, still unspent. And a
line whose action cannot be done does not stand: a hand with nothing
playable has no hand line, END TURN's comes instead, and the next turn,
playable, the hand's.
```

## Cutaway line once

Above `func _cutaway_once() -> void:`:

```text
THE CUTAWAY'S LINE ONCE (Jon, Oct 20: "when I enter the ship editor, A.S.H.
keeps saying the tutorial line every time I enter. It should only be the
first time"): your ship opened up and shut while she is still saying it, so
it comes again; then opened three times, shut each time with no module moved
once she has said it whole, and she says it the first of those only; it is
kept seen in the hints file; REPLAY TUTORIAL brings it back once more; with
the tutorial off it does not come at all.
```

## Decks lines

Above `func _decks() -> void:`:

```text
THE DECKS' LINES (Jon, Oct 20: "There is no tutorial tip for the promenade,
exchange, shipyard, laboratory, or hiring board"), through the real station
and its deck buttons: each said the first time its deck is open, clicked on
and still up, unspent, until the deck is used (`HintActs`: a drone's job, the
till, the counter, SIGN, the fabricator), or until she has said it whole and
the deck is left by another deck's button (then spent: said once, Jon's Oct
20 ruling); left while she is still saying it, it comes back. Picking a deck
is the dock's own action. TUTORIAL OFF: none, and REPLAY TUTORIAL brings each
back; her switch off: today's card; in a party: nothing.
```

## Introduction

Above `func _intro() -> void:`:

```text
SHE INTRODUCES HERSELF EVERY NEW RUN (Jon, Oct 18, "intro:A"; Oct 20: "On the
first LOCAL section you load into on a new game, A.S.H. should introduce
herself. Short beat. THEN the first tutorial hint."), through real new runs
with her and the hints both on the game's clock, as in play: three new runs
in a row, one with an old settings file that still says `[hints] ash_intro`;
each opens with the intro, its take, then a beat of at least 1.4 s before the
goal's first step. A run picked up with CONTINUE does not hear it again.
Read through her log and the tape, so it fails on a game without it.
```

## First launch

Above `func _first_launch() -> void:`:

```text
A RUN'S FIRST LAUNCH AS PLAYED (Jon, Oct 20: "A.S.H. introduces herself and
also reads the tutorial at the same time. The GOAL and the tutorial tip are
right under her box."), the screens animating as in play (the goal line
fades in, so it is not drawn on the frame the ship stops), her and the hints
on the game's clock. Both ways: a new run (the intro, then the step) and a
launch with no intro, as a run picked up has it (the step, then a launch line
from the bag). Every frame: one line of hers at a time, none cut by the next,
and her box clear of the goal, the step's line as drawn and the step's place.
```

## Said aloud once

Above `func _said_once() -> void:`:

```text
SHE NEVER SAYS THE SAME LINE ALOUD TWICE (Jeremy, a playtester, Oct 23: "it
doesn't need to repeat everything when I jump out of a menu after it has
already said it"; Jon's 0.4.1-alpha.1 log: the hull's line five times, heat's
four times in one fight against the Dreg Hulk). At her real pace (the words
typed over her take, so "said whole" is her last word), her voice on tape:
  - HEAT ACROSS THE TURNS OF ONE FIGHT: said whole at turn 1, it stays up
    through the heat vented to nothing (it used to go unspent and come back at
    the next turn's start in full), END TURN spends it and the later turns say
    nothing; set up again and cut off mid-line (something came into her box),
    it is back at the next turn's start of the same fight as text only, and
    END TURN spends it. One take of it each time;
  - A SCREEN LEFT AND COME BACK TO after a line was said whole: the chart's
    (a star picked spends it) is back quietly, the words out at once, no chirp
    and no take, and held until a star is picked;
  - CUT OFF, SAID ONCE MORE: the hull's, LOCAL left before her last word on
    three visits, is said aloud, aloud once more, then as text only, which
    leaving spends;
  - INFORMATION, ONCE EVER: the first arrival's fuel line, the map left while
    she says it, is spent and never comes again.
```

## Comms

Above `func _comms() -> void:`:

```text
COMMS (Jeremy, a playtester, Oct 23: "Give me an option to revisit all
communications"), through the HUD's COMMS tab: a new run's log is empty; her
teaching lines and a quip go in it as she says them, a line back quietly does
not; the tab is the same rect and the same word before and after (no count,
ever), and the HUD's row fits with it, nothing over anything; the table lists
the lines newest first, each with its words, and PLAY on every line with her
voice; PLAY says the take again, and waits while she is speaking; COMMS and
QUESTS take turns over the picture; the table clear of the HUD, the goal line
and her; the run's save keeps the log, CONTINUE puts it back in order, and a
save from before it (VERSION 35, no `ash_comms`) loads with an empty one.
```

## The huds row with comms

Above `func _comms_row_fits(hud: HudBar) -> void:`:

```text
The HUD's row with COMMS: every piece inside the bar, none over another, and
its minimum within the bar (`QuestLogTest._hud_fits`, the same test). The
bar is the row's clip, 932 at a 960 window, not the panel's 944: a row up to
twelve pixels wider than the clip had its right-hand end cut off and passed.
WITH DATA AT TWO FIGURES (science, Nov 4): the readout is always on the row,
reserved at "00", so it is held to the clip with 99 showing.
```
