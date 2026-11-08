The reasoning behind `tkg/scripts/autoload/Sig.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Party map

Above `signal party_map_changed()`:

```text
The party consumed a system — somebody stripped a wreck, won a fight or
answered a hail. RunState listens and marks its own copy of the map.

It exists because a seed gives four machines an IDENTICAL galaxy rather than
a SHARED one. Everything a node holds is positional and therefore already
agrees; what does not agree is whether it is still there. Without this every
player strips every wreck and the hold economy is paid four times over.
```
