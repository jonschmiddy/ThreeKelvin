The reasoning behind `tkg/scripts/ui/Hints.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hints overview

Above `const SECTION := "hints"`:

```text
FIRST-RUN HINTS, so a friend playing alone is not lost (alpha; scratchpad
`alpha/onboarding.md`). There is NO TOUR (tutorial direction B, "learn by
doing", Jon Oct 17): the controls are yours when the ship stops, the goal and
the next step sit under the HUD (`GoalLine`), and each of these teaches one
thing at the moment it first matters, never as a wall:

  chart    the chart's in-range list, and its two bars (danger, fuel)
  events   the sector map's events: click one to read it, GO flies you there
  drawer   the event band's choices, and the odds printed on them
  hand     a fight's hand: drag a card onto an enemy; the cost corner
  intent   after your first card: the words over an enemy are its next move
  endturn  nothing left to play: END TURN, and what it does
  brace    brace held over an end of turn: it stays up, and costs heat
  heat     heat has risen: the cap, and the hull it burns past it
  salvage  a wreck's window: drag a part into your hold, or double-click it
  cutaway  inside your ship: drag parts onto rings, R turns, F flips
  wreck    a wreck is clicked to loot it
  loot     SECTOR LOOT, beside SCAN SECTOR
  dock     the first station: what it does, and its decks
  shipyard, promenade, exchange, hiring_board, laboratory
           the first time each deck is open: what it is for and the one
           thing to do there, on its main thing (`DECK_HINTS`)
  fuel     a third of the tank left: running dry ends the run, and the
           nearest dock in reach by name (or what to do with none)
  ship     click your ship (LOCAL or the shipyard) to open it up

THE DEEP TUTORIAL (Jon, Oct 22: "Tutorial: scope:all voice:record bugs:fix",
after Kevin's playtest: he clicked the tutorial away and did not know the
energy meter or when to loot a dead ship). The audit's 35 rows, each a
lesson with its trigger, subject, end and pacing (`docs/ash.md`):

  in a fight   energy (after the first card), heat_corner, keywords,
               discard_pick, malfunction, flee_hail, piles; intent moved to
               the start of turn 2; heat, brace and intent end on their
               action (a card or END TURN), not on a reading time
  the band     odds (a choice with a check), result (REWARD, CONTINUE)
  LOCAL        hull; the wreck, salvage and loot lines say more
  the map      fuel_first (the first arrival), map_fly (a world to fly to, or by hand)
  the chart    layers, contract_track, quest, jump_blocked
  the cutaway  mounts, cards_from_parts, attributes (the flip key dropped)
  the station  faults, hull_sale, undock
  the menu     save (over the escape menu: the one lesson said there)
  the yard     chassis_card (a card only: she has not introduced herself), under
               the row of ships until one is picked, then on LAUNCH

PACING (the audit's, binding). One lesson at a time; each starts only when its
screen has held still (SETTLE_S) and ends when the player does what it
teaches. IN A FIGHT (`pace_ok`) a lesson starts only while the hand is
settled and no card is held; only the hand's, energy, discard_pick and END
TURN's start after a card this turn (`MID_TURN`), the rest at a turn's start.
Turn 1 of the first fight teaches the hand, energy and END TURN alone
(`TURN_ONE`); flee_hail, malfunction and piles are one a fight
(`ONE_A_FIGHT`), piles not in the first. OUTSIDE A FIGHT the gap after a
lesson is GAP_S (3 s; 1.2 in a fight, `GAP_FIGHT_S`), and a screen as it
stands (`_front`: the screen, its station deck, an open cutaway, window or
event) teaches one new lesson, but for the chains (`CHAINS`). The goal
steps still yield to lessons.

ONE AT A TIME, a `HintCard` beside its subject. Its subject has to hold still
for SETTLE_S first, so nothing shows mid-transition.

A CLICK NEVER DISMISSES ONE (Jon, Oct 22, after the first outside playtest:
"Kevin also clicked away the tutorial and subsequently had no idea what he
was doing. Can we soft lock the screen so A.S.H. can't be dismissed?"). It
used to go on any click (his earlier "let's have them advance with a click").
Now each stays until the player has DONE what it teaches (`_done`, the table
at `DONE`): the chart's until a star is picked or a jump made, the hand's
until a card is played, END TURN's until it is pressed, and so on. The few
that only tell you something (`INFO`: the intent, brace, heat, fuel) stay for
their reading time after her voice ends and go by themselves, spent. If its
subject goes first, it hides unspent and shows again the next time (but the
six Jon ruled are said once, `SPENT_ONCE_HEARD`). NEVER STUCK: one that has
been said whole and stood YIELD_S while another line is waiting here (a hint,
or a goal step) gives way unspent and rests REST_S, so no line holds the goal
or another hint for good; a line whose action cannot be done here has no
subject (`probe`) and hides. Seen is per hint in
settings.cfg `[hints] <id>` (`DisplaySettings.hints_path`), beside the welcome
note's and the goal line's steps. Under a harness that is the harness
settings file, never the player's. Settings' REPLAY TUTORIAL (`reset`) brings
all of them back, and the goal line's steps.

TUTORIAL ON / OFF (Jon, Oct 20: "Have a setting in the options for tutorial
on or tutorial off"): Settings' TUTORIAL row, `[hints] tutorial` in the
settings file, on by default (`set_tutorial`). Off: no hint, no goal step and
nothing of A.S.H.'s teaching; the goal line's GOAL stays, and her introduction
and her other lines are hers, not the tutorial's. Turned off mid-run, what is
up goes at once, unspent; turned on, the hints pick up where the player is
(what was seen stays seen; REPLAY TUTORIAL works either way).

OFF UNDER HARNESSES (`TestRun.active`) unless the run asks with `-- hints`;
`-- hinttest` turns it on by hand (`forced`). OFF IN A PARTY too (Jon, Oct 17:
"coop:B"): a networked run shows no hints and no goal-line steps. They still
show on a seeded solo run. Not off under reduced motion: those players need
hints too; only the fade goes.

It finds its subjects by looking at the screens as they are each frame, so no
screen has to call it.

A.S.H. SAYS THEM (Jon picked how A for the tutorial, Oct 17: "A.S.H. replaces
the hint cards"). While she is on (`Ash.teaches`), a hint that is due is said
in her corner in her words (`AshTutorLines`) with its subject outlined,
instead of a card: the same trigger, the same order, the same subject, the
same action to spend it, the same hiding unspent when the subject goes. Where
she has nowhere clear to stand it is the card after all, so a lesson never
waits for room. With her off, the cards, exactly as before. She also says
each goal step (`GoalLine`) once as it starts (`said_<step>`), after any hint
due on that screen; the goal line itself does not change. All of it is off in
a party with the hints (`enabled`).

SHE NEVER SAYS THE SAME LINE ALOUD TWICE (Jeremy, a playtester, Oct 23: "it
doesn't need to repeat everything when I jump out of a menu after it has
already said it"; Jon's log of 0.4.1-alpha.1 had the hull's line five times,
heat's four times in one fight, the ship for sale's and SAVE & EXIT's twice).
The come-back rules above (a line left unspent shows again, a line that gave
way returns) said the whole line again each time, in her voice. Now a line
she has said whole is HEARD (`heard_<line>` beside `seen`, cleared by REPLAY
TUTORIAL), and if it is still unspent because its action has not been done it
comes back QUIETLY: her box with the words already out, no chirp, no voice
(`AshPortrait`'s quiet), held as before until its action. A line cut off while
she was saying it may be said aloud once more, on a later visit or fight
(`_visit`), never on the one it was cut on; after that it is text only too. An
information line (`INFO`) is spent as it shows: said once, ever. The lines
stay undismissable: a quiet line still ends only by its action.
```

## Deck hints

Above `const DECK_HINTS := {&"shipyard": &"services", &"promenade": &"stock", &"exchange": &"hold",`:

```text
ONE HINT A DECK, the first time it is open (Jon, Oct 20, playing the alpha:
"There is no tutorial tip for the promenade, exchange, shipyard, laboratory,
or hiring board"): hint id -> the station's page (`StationScreen.DECKS`). Each
points at the deck's main thing (`StationScreen.deck_subject`): the yard's
drones, the shelf, the sell counter, the notes on the board, the lab's
screen. After `dock`, which still comes first on arrival.
```

## Said once

Above `const SPENT_ONCE_HEARD: Array[StringName] = [&"cutaway", &"shipyard", &"promenade", &"exchange",`:

```text
SAID ONCE, HEARD WHOLE (Jon, Oct 20: "when I enter the ship editor, A.S.H.
keeps saying the tutorial line every time I enter. It should only be the
first time"; the decks' the same day: people leave a deck by clicking another).
Each still stays up until its action (`DONE`), but leaving its screen after
she has said it whole spends it too, so it is said once however the player
goes. Left while she is still saying it, it is unspent and comes again. (They
were spent as they showed while a click was what spent the rest.) A card is
read whole as it shows. SHOW HINTS AGAIN brings them back.
```

## Info lines

Above `const INFO: Array[StringName] = [&"fuel", &"fuel_first"]`:

```text
THE LINES THAT ONLY TELL YOU SOMETHING: no action to wait for, so each stays
its reading time after her voice ends (`AshPortrait`'s own hold) and goes by
itself; as a card, `info_s`. Spent as it shows (Oct 23): said once, ever,
however it goes.
```

## Soft lock

Above `const SOFT_LOCK := false`:

```text
SOFT LOCK, option (b) of Jon's "soft lock the screen" (Oct 22): while she is
SPEAKING a hint's line (not after), a click anywhere but the thing she points
at does nothing (`ClickGate`). Off: blocking the game reads as a bug, and the
player must be free to do the step; on to try it. `soft_lock` is the live
switch (a harness flips it).
```

## Hint prose

Above `func lines(id: StringName) -> Array:`:

```text
The two lines of each hint. Graded with `tools/prose_grade.py` (grade 7.0 or
under, ruled 2026-10-13; the ones added Oct 17 are held to 5.2). The
cutaway's names the keys as bound; the heat and END TURN ones read the live
cap and hand size, never a number written here.
```

## Pacing

Above `func pace_ok(id: StringName) -> bool:`:

```text
THE AUDIT'S PACING: whether lesson `id` may START now (not whether it may
stay: that is its subject's). In a fight: no card held; after a card this
turn only `MID_TURN`; turn 1 of the first fight only `TURN_ONE`; one of
`ONE_A_FIGHT` a fight, and piles not in the first fight nor on turn 1.
Outside one: a screen as it stands teaches one new lesson, or the next of a
chain.
```

## Menu hint

Inside `_done()`, above `return not menu_up() or _exit_asked()`:

```text
THE MENU SHUT, OR A WAY OUT PRESSED: its question ("SAVE AND LEAVE?")
takes the plates' place, so the line's subject went with it and it
came back in full at the next menu (Jon's 0.4.1 log, twice)
```

## Goal step bark

Inside `_step_now()`, above `if not GoalLine.shows_on(Router.current):`:

```text
(whether the goal line is up this frame, not whether it has drawn yet: a
bark asked first on the frame the ship stopped, the line not yet faded in,
so the launch bark started and the step cut it 0.6 s later)
```

## Heat hint

Inside `probe()`, above `if not _hand_settled(sc) or (Run.heat <= 0 and not staying) or Router.hud == null:`:

```text
HEAT HAS RISEN, in a fight: the gauge, the cap and its price. Up,
it stays when the heat is vented to nothing (Bleed Heat is in every
starting deck): the gauge is still there and its action is END TURN.
It went, unspent, and came back at the next turn's start in full,
four times in one fight in Jon's 0.4.1 log.
```

## Fuel hint

Inside `probe()`, above `if Router.hud == null or ZoomLadder.busy() or not _fuel_low():`:

```text
A THIRD OF THE TANK LEFT (`Run.fuel_low`), out of a fight on a screen
that is still. It waited for "under two of the dearest jump" (about
12 of 279) and in every stranded run the sim flew, that was one to
three jumps from the end.
```

## Chart dock hint

Inside `probe()`, above `if cur is StarchartScreen:`:

```text
ON THE CHART IT POINTS AT THE DOCK IT NAMES, in the in-range list, or
at the list when the dock is further: the readout is in the bar's
corner and on the chart the only room near it is the bar itself (the
side bar under it, the toolbar and the picture's frame beside it), so
the card stood on the HUD. Kept off the HUD and the side bar, as the
chart's own hint is, which puts it on the picture beside the list.
```

## Map fly hint

Above `func _map_fly_probe(map: SystemMapScreen, hud: Rect2) -> Dictionary:`:

```text
THE MAP, the ship on no place's orbit (circling the star as it arrived, or
free): "Click a world twice and we fly there. Or fly us by hand." Shown while
`reached()` is -9, as it is on the wide orbit round the star every arriving
ship is put on (`ShipFlight.setup`: free, `star_orbiting`): no place's events
are open there, and a world clicked twice flies from it (`can_fly`).

THE OUTLINE IS ON A WORLD A CLICK FLIES TO (Jon, Nov 4: "Shouldn't a world be
highlighted here and not my ship?"). It was on the ship, from when the line
taught flying by hand alone. The world (`_fly_world`): a planet or the giant
(not a belt, a station, a derelict or a contact), not the place the ship is
on, one a click at its middle picks (`SystemOverlay.hit`: not behind a sun,
not under another place's beacon), its box whole on the picture and clear of
the HUD and the side bar; of those, one whose box is clear of the ship if
there is one, so the outline is not round the ship and the world together;
the one nearest the ship on screen, kept while it still qualifies so the
outline does not hop from world to world as they go round. Only while a
world clicked twice flies (`can_fly`: a ship drifting under its own thrust
flies by hand). Its box is the map's own reticle round
it (`SystemOverlay._reticle` at `_reach`, which holds the click's circle),
read where the world is drawn each frame the probe runs, so it goes round
with the world. With no such world it is on the ship, as it was: the line's
second half is flying it by hand.
```

Inside `_fly_ok()`, above `var h: Dictionary = map.overlay.hit(map.view.at[i])`:

```text
a click at its middle picks it, as `SystemMapScreen.tap` reads it: not
behind a sun, not under another place's beacon (seed 4242's LAMBDA
ABYSSAL IX: a fight's beacon over its first world opened the fight)
```

## Ship hint

Above `func _local_idle(sc: SectorScreen) -> bool:`:

```text
LOCAL out of a fight, nothing over it, and nothing on its way: no camera
move, no event band up, going down, or waiting to come up (`deferred`,
`LocalEventDrawer.pending`). The ship hint used to show in the 0.6 s between
GO's landing and the band rising, and hide unread (tutorial audit, 0.44 s).
```
