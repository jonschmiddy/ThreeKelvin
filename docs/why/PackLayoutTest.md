The reasoning behind `tkg/scripts/sim/PackLayoutTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Pack layout

Above `var _fails := 0`:

```text
NOTHING IN A FIGHT SITS ON ANYTHING ELSE, headless:
  godot --headless --path . -- sheet=PackLayoutTest [packlayout=A|B|C|all] [quick]
Jon, Oct 13, on three enemies piled on each other: no ship, wreck, name, hull
bar, chips or intent may overlap another enemy's or yours. For each pack
layout (`EncounterView.pack_layout`; `all` runs A, B and C), the real fight is
opened and its ships re-dressed as every pair and every triple of the
pictures a fight can bring (the five ordinary kinds' three each, the
Hellbender, the Custodian), and every triple again with its first ship a
wreck. Once laid out, every box -- each ship's own ink at rest, each line of
its readout (intent, what it does, name, number: the text's own width), its
bars, its chips; and yours: your hull, your name, bar, number and chips --
must not cross any other box, and must lie inside the view. Your ship must
not have moved from where it stands with one enemy out there.

Written against the slots' own nodes rather than any helper the layout
added, so the same file runs on a build without them (it did, on main at
d4d2bf0, and failed).
```

## Shield room

Inside `_measure()`, above `var ovals: Array = []   # [owner, Rect2]`:

```text
THE SAME ROOM UNDER EVERY HULL (Jon: "The hellbender is a bit close to
its text box"), and THE SHIELD'S ROOM ("shield:A"). A ship in a fight:
the oval its block raises (`ShieldFx.fit`, the shield's own) clear of its
words, its name, its bars and chips, and of every other ship's boxes, with
RIM_GAP from its rim to the words above and to the name below. A wreck on
LOCAL (no shield): its name UNDER_GAP under its ink.
```
