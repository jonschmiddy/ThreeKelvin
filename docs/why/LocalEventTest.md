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
