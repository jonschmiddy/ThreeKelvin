The reasoning behind `tkg/scripts/ui/HitText.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hit text

Above `const SHADOW := Color(0, 0, 0, 0.85)`:

```text
THE NUMBER ON A TARGET, ONE LOOK FOR BOTH TIMES IT IS SHOWN (Jon, Oct 13:
"let's have these numbers be the same as when a card is hovered over the
enemy ship").

A card held over a target paints what it would do there (`EnemySlot`,
`EncounterView.ShipSlot`); the same card landing pops what it did
(`CombatFx.pop`). They were two styles -- the landing smaller, its colours
its own -- so the answer did not read as the answer to the question the
preview had asked. Both draw through here now: the pixel font at the
heading size, a one-pixel dark outline all round, no plate, and one colour
per kind of number. The pop keeps its own motion (rise, hold, fade); the
letters are this.

THE OUTLINE (Jon, Oct 13, "Pops: B"): a 1 px dark ring round every glyph, so
a small number still reads over a bright, studded hull. It was a shadow down
and right only, and "-6" sank into the Rustjaw cutter's rivets.

WHERE (Jon, same note): held over a ship, the number is ON it, centred on the
hull's ink both ways (`centred_at`); landed, it is ABOVE the ship, centred on
the ink across and a few pixels clear of its top (`above`), and rises from
there. Measured off the INK, never the canvas or the slot: your hull's canvas
carries the exhaust's clearance on one side, which put BLOCKED 5 right of
centre.
```

Above `static func colour(kind: StringName) -> Color:`:

```text
The colour for a kind of number:
  damage, kill  what a card does to a contact (FLARE, as the preview always was)
  gain          what a card puts on your own hull (GOOD, likewise)
  hurt          what reached your hull
  block         what block and brace took
  miss          a shot that went by
  act           something a contact did that is not a shot
```
