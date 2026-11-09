The reasoning behind `tkg/scripts/sim/HintTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Test overview

Above `const HintActs := preload("res://scripts/sim/HintActs.gd")`:

```text
The first-run hints (`Hints`), on the real screens, headless:
  godot --headless --path . -- hinttest

Each hint fires once at its trigger, as a `HintCard` in the game's picture,
never over what it points at; NO CLICK DISMISSES IT (Jon, Oct 22: real clicks
through the viewport on the card leave it up and unspent), and it is spent
when the player does what it teaches (`HintActs`), or, for the ones that only
tell you something (`Hints.INFO`), after its reading time; never again after;
the ones a moment decides (the intent after the first card, END TURN when
nothing is playable, brace once held over an end of turn, heat once it rises,
fuel at a third of the tank) are also shown NOT to fire before it. SHOW HINTS
AGAIN (`Hints.reset`) brings them back, and the goal line's steps.

THE USED STATE, NOT THE FRESH ONE: the run starts from a settings file that
already has hints seen, has been reset once, and has one hint (the map's
events) seen again since. The flags go to the harness settings file, never
the player's. What is checked is the card in the tree, not only the flag, so
this cannot pass while nothing draws. The clock is stepped by hand
(`Hints.poll`).

THE FIRST SET, NOT THE DEEP TUTORIAL'S: the lessons added Oct 22
(`Hints.DEEP`) are parked (marked seen) after every reset here, so this holds
the first set's triggers and order as they were; `-- sheet=AshTutorTest`
walks every lesson, the deep ones too, through a first run. The intent's line
now comes at the start of turn 2, and brace's and heat's end on END TURN.
```

## Decks hints

Above `func _decks() -> void:`:

```text
THE DECKS' FIRST-VISIT HINTS (Jon, Oct 20, playing the alpha: "There is no
tutorial tip for the promenade, exchange, shipyard, laboratory, or hiring
board"), through the real station screen and its deck buttons, from the dock
just spent: each deck's hint shows the first time it is open, on its main
thing, clear of the decks, UNDOCK and everything on the deck; clicked on, it
stays unspent; the deck used spends it (every other one), or it is left by
the next deck's button (a card is read as it shows, so that spends it too:
said once, Jon's Oct 20 ruling); again, none comes back. The dock's, with a
deck picked under it, is spent by that (its action); off with TUTORIAL OFF,
back with REPLAY TUTORIAL; off in a party.
```
