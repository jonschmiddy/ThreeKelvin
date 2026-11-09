The reasoning behind `tkg/scripts/data/HoldItem.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hold items

Above `@export var name: String = ""`:

```text
Anything that takes up room in the hold.

The hold was written for modules, because until now modules were the only
things in it. Materials become a second item class -- see
`docs/briefs/MATERIALS_NOTE.md` -- and they are not modules: no slot, no
mount, no power draw, no affixes. What they share with a module is the only
thing the hold ever cared about, which is that they occupy cells and remember
which ones.

So that is what lives here, and nothing else. If a field is about being a
MODULE it stays on `ModuleData`; if it is about being an OBJECT WITH A SHAPE
it belongs to this class. `HoldGrid` and every hold function in `RunState`
take one of these, and neither needs to know which kind it got.

`MATERIALS_NOTE` §3.1 rules that materials do not stack, and §3.2 follows from
it: a tally cannot say "one is here and the other is over there", so every
item is its own instance with its own cell. This class is that decision made
structural.
```

## Authored shape

Above `@export var size: Vector2i = Vector2i.ONE`:

```text
The shape it was AUTHORED as, in hold cells.

`ModuleData`'s own note reads the vocabulary out loud -- 1x1 a small box,
1x2 a compact unit, 1x3 something long, 2x2 something bulky -- so a hold full
of long things is visibly a hold full of guns before any word is read.
Materials join the same vocabulary: the catalogue authored a `cells` string
per row for exactly this reason, and it is parsed into this field.
```
