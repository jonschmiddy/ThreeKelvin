The reasoning behind `tkg/scripts/sim/ArtPrompt.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Prompt purpose

Above `const SHAPE := {`:

```text
Build a PixelLab prompt from a manufacturer, rather than from memory.

    godot --headless --path . -- artprompt korvan structures
    godot --headless --path . -- artprompt verity fittings
    godot --headless --path . -- artprompt      (every manufacturer, every batch)

WHY THIS EXISTS. Every prompt sent this session said "spaceship hull
fittings" and nothing else, so the generator produced generic parts that
belong to nobody. The game already knows who Korvan are in four separate
fields and none of it was reaching the model.

`art/ART_CONTRACT.md` states the rule — "silhouette reads chassis, modules
read faction" — and then never says what any faction LOOKS like. That gap is
SHAPE below. The rest is read live from DB.manufacturers, so the fiction has
exactly one home and a prompt cannot quietly drift from the tooltip a player
reads on the same manufacturer.
```

## Shape lines

Above `const SHAPE := {`:

```text
What each manufacturer's parts are SHAPED like. The one thing here that is not
already in the game, because the game had no reason to know it.

Written to be CONTRASTIVE. The point is not that Korvan looks industrial —
it is that Korvan looks nothing like Verity, so a part is placeable by
silhouette before the palette is read. Each line was derived from that
manufacturer's own backstory rather than invented: Korvan "inherited the jigs",
Probate is "everything is salvage", Verity signs each hull.
```

## Surface

Above `const BASE := {`:

```text
What the surface is made of, and how it is held together.

Both used to be hardcoded into the tail of the prompt, which told Calyx to
have "steel blue plating" and "rivets and panel seam lines" two sentences
after telling it that it is grown rather than built. A prompt that argues
with itself gets to pick which half to believe.
```

## Camera

Above `const CAMERA := "FLAT SIDE ELEVATION, drawn perfectly side-on. No perspective, "  	+ "no foreshortening, no three-quarter angle. No circular end caps or round "  	+ "openings facing the viewer — every opening is seen edge-on as a straight "  	+ "line. Each part is a flat profile seen from directly beside it, as in a "  	+ "technical elevation drawing."`:

```text
The camera, spelled out.

"side view" is not enough on its own — a run came back as cylinders seen
slightly off-axis, circular end caps facing the viewer, which satisfies "side"
and violates the contract. A part drawn round cannot sit on a hull drawn flat,
so this says FLAT four different ways and names the specific failure.
```

## Part clauses

Above `parts = ["a long flat-topped rectangular cargo block, twice as wide as it "`:

```text
TWO OR THREE CLAUSES EACH, and deliberately different shapes.

One clause apiece produced four variations on a cylinder: given room to
settle, the generator finds one comfortable form and repeats it. Naming
a proportion and a distinguishing feature per part is what stops that.
COLOUR NAMED PER PART, not once at the end.

Measured: a forced palette constrains which colours are LEGAL and says
nothing about proportion — a reference that was half amber produced 0.1%
amber. And a single colour sentence trailing after five sentences of
camera instruction got ignored: the run that finally got shape and camera
right came back with 7 colours and zero amber.

So the accent is attached to the objects instead. "%s" is the manufacturer
colour, filled in by _prompt() from the manufacturer record.
```

## Shape only

Inside `_prompt()`, above `out += String(SHAPE.get(m.id, ""))`:

```text
SHAPE ONLY. The backstory does NOT go in.

It used to, on the reasoning that the parts should agree with the fiction a
player reads. What came back was three naval surface ships — masts,
superstructures, waterlines. Korvan's backstory contains "navy
specification", "vessel" and "hull", which are words chosen to make a
person feel something and which a generator reads as an instruction to
draw a warship. The lore paragraph overrode every other line in the prompt.

So the backstory's job is to tell whoever writes SHAPE what this manufacturer is.
SHAPE is the translation, and only the translation is sent. Prose written
for players is not a prompt and pasting it in is not free.
```
