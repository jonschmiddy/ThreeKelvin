The reasoning behind `tkg/scripts/ui/ShipParts.gd`; each heading is referenced from the code by a `Why:` line.

## Parts

Jon, Nov 15, picked C of three ways to show an event's choices in the scene ("use your own ship",
https://claude.ai/artifact/UFYW9E4C4sWWfyBjvawSVw): each choice sits on the part of your ship that
would do the work, so you learn what each part is for by using it.

No encounter is mapped by hand in this stage. The part is read off the choice: a check's stat first
(maneuver the flank, sensors the comm mast, thrust the engines, hull the plating, thermal and
stealth the radiators), then a science reading (the mast), a declared fight (the guns), a burn
(the engines), a price or a material (the hold), and walking away (the bow). An encounter's own walk-away
takes the bow and NOT NOW is not shown (Jon, Nov 15, A): to put an event off you fly off, and the
place's tag keeps OPEN IT. An encounter with no walk-away keeps NOT NOW on the bow. A choice may name its own
part with a `part` key, which wins over everything.

When two choices want the same part, the later one takes the next free part round the hull in
`NEXT` (the nearest neighbours first). `-- sheet=ShipChoicesTest report` counts how often that
happens across every authored encounter.

The spots are fractions of the hull's drawn box (its opaque pixels, `ShipView.ship_rect`): rear
fifth the engines, the top in three (radiators, mast, guns), the front the bow, the keel in three
(hold, flank, plating). Every hull has these at roughly these places, so no hull needs new art;
`-- sheet=ShipChoicesShot hulls` draws them on every hull to check.
