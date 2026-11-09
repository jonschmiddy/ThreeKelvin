The reasoning behind `tkg/scripts/sim/LocalEventTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Event band checks

Above `var _tree: SceneTree`:

```text
Every authored option, opened and resolved through LOCAL's event band
(`LocalEventDrawer`), the one place a choice is taken now:
  godot --headless --path . -- localeventtest

For every option in `OptionTable` and every one of its choices, on a fresh
copy of one system: the band opens on it (its text, one card per choice),
the choice resolves through `OptionResolve` -- the one rule -- and the band
shows how it went: the result page with the band word and CONTINUE, or LEFT
ALONE with CHOOSE AGAIN for a walk-away, or THEY ARE FIRING for a fight with
something to read, or straight to the fight (`fight_now`), or the game over.
A choice the band will not let you afford (credits, a material you are not
carrying) is given what it wants first, so every branch is reached. In all
three layouts. The screens a fight or a death would open are not opened
(`LocalEventDrawer.quiet`).

And WHAT YOU END UP WITH, in every look (`OutcomeRow`): each result drawn
again as today, A, B and C and held to what the run actually moved
(`OutcomeCheck`: the ledger, the system's pile, the hold and the frame,
diffed), with the box test. Every choice in the column layout,
every fifth option in the other two.
```

## What a reading burns is on

Above `func _fuel_cards(holder: Control, n: MapGen.MapNode) -> void:`:

```text
WHAT A READING BURNS IS ON ITS CARD (`EncounterDrawer.choice_card`), in all
three layouts, for every science event: with a full tank each `burns` card's
note ends "· N fuel" after its odds ("N fuel" alone on the careful line), N
the reading's own `OptionTable.science_fuel()`, and the card answers a
click; the credits line says nothing of fuel. With exactly the way out plus
the reading in the tank the card is still live and still reads "N fuel" (the
gate's edge). One fuel short of that, each `burns` card reads "needs N fuel +
K to leave · you have M" (N the same price as on the full card, K the way out
`Run.fuel_floor()` keeps, M the tank), in FLARE, and is not pressable: no
live plate, no pointing hand (only pressable things look pressable); the
credits line still is. And with the note showing it fits: every note inside
its card, every card inside the band and clear of the others, the band
asking for no more than its cap.
```
