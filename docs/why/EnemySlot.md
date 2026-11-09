The reasoning behind `tkg/scripts/ui/EnemySlot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Brace pips

Above `class BracePips extends Control:`:

```text
Brace as countable cells, sitting on the hull bar.

Brace was a small bar with "2 ARMOR" written under it, which is a bar doing
a number's job and a number doing a bar's. Brace values are small and every
point is one hit's worth of nothing happening — so what matters is HOW MANY,
exactly, the same reason heat and energy are cells rather than bars. Read
them and the label is redundant; the label goes.
```

## Idle bob

Above `const BOB_AMP := 2.0`:

```text
The idle drift: whole pixels, up and down, so a contact reads as floating
rather than pinned to the panel.

Done by MOVING THE ART, which `ShipView` explicitly cannot do -- its note says
animating the Control's position "would fight the containers every screen puts
this inside", so it bobs inside its own canvas instead. This one can, because
the entrance already gave the art a plain holder to move in, and moving a
Control is far cheaper than regenerating an image eight times a second.

Slower and shallower than your ship's `bob(2)`: they are further away, and a
pack drifting in step reads as one object rather than three ships. The phase
comes off the slot index for the same reason. The clock is `GameClock`: one
clock the whole pack reads, so the phases hold, and game time, so a film
made with the movie writer bobs at 4.76 s a cycle like play does.
```

## Fly-in

Above `func holder_rect() -> Rect2:`:

```text
Fly in, as the fight opens.

Your own approach is `ShipView.arrive()` and is deliberately NOT played when
a fight starts -- you were already here, parked. The contact was not: it is
the thing that just turned up, so it is the thing that moves.
Where the brackets go, in screen space. For `-- sectorshot entrance`, which
checks it against the art's own rect -- the two are the same box, and the
reticle is wrong the moment they stop being.
```

## Per-ship intent

Inside `_init()`, above `_intent = UITheme.body("", UITheme.THEM, UITheme.FS_SMALL)`:

```text
What THIS one is about to do, over its own hull. One strip at the bottom
of the screen could only ever name a turn's worth of intent for the whole
pack — with two enemies it printed "Lancer: Strafe   Hulk: Ram", which is
a sentence you parse rather than a thing you see. Above each ship it is
just a label on the thing it describes.
The move, then what the move does. The name alone tells you a Lancer is
about to Strafe, which is only useful if you already know what a Strafe
costs you — and the number underneath is the half you actually plan
against.
```

## Column alignment

Inside `_init()`, above `col.alignment = BoxContainer.ALIGNMENT_BEGIN`:

```text
The column centres itself and the art stops expanding, so name and bars
sit directly under the ship instead of being shoved to the floor of a slot
that happens to be tall. A health bar half a screen below its ship is a
health bar you have to go looking for.
TOP-ALIGNED, with the intent's lines reserved (`reserve_readout`), so the
ship stands at the same height whatever its readout says -- a kill or a
new intent changes the words, never where the hull is.
```

## Art holder

Inside `_init()`, above `_art_holder = Control.new()`:

```text
A PLAIN CONTROL BETWEEN THE ART AND THE COLUMN, so the art has a position
of its own to animate. A container child's position belongs to the
container -- it is rewritten on the next sort -- so `enter()` tweening it
directly would hold until the next layout pass and then snap back.
`ShipView` needs none of this because its slot is not a container.

The holder is what the column measures, so the size flags move onto it and
the art fills it.
```

## Bar width

Inside `_init()`, above `var bars := VBoxContainer.new()`:

```text
Bars sized to the SHIP, not to the slot.

The slot expands to share the arena, so a lone enemy owned the full width
and its health bar with it — a seven-hundred-pixel readout for one
freighter. A health bar belongs to the thing it measures: read at a
glance, its length should say how much is left, not how much room the
layout had. Centred in a fixed BAR_W so two enemies read the same as one.
```

## Salvage label

Inside `bind()`, above `_hp.text = ("SALVAGE" if opened.is_valid() else "WRECKED") if _dead \`:

```text
SALVAGE, not WRECKED, once there is a reason to touch it.

"WRECKED" is a state and states are not affordances -- it told you the
thing was dead and said nothing about it being the way into what it was
carrying. The word only changes when the slot can actually be opened, so
a hull with nothing left in it goes back to being a fact.
```

## Salvage count

Above `func set_salvage(left: int) -> void:`:

```text
THE COUNT CAME OFF THE HULL, 2026-09-03, by Jonathan: a wreck says
"SALVAGE" and nothing more.

IT WAS PUT THERE ON PURPOSE and the reasoning still reads: "SALVAGE" alone
said the door existed and nothing about whether walking through it was worth
it — a stripped wreck and a loaded one wore the same word, and a fight's
whole payout could sit behind a label indistinguishable from scenery. That is
why the tooltip still carries the number: the wreck stops advertising, but
the answer is one hover away rather than gone.

A wreck with nothing left is still told apart, by STRIPPED and by colour, so
the case the count was added for is the one case it was never needed in.

Asked after `bind`, by the view that knows the container — the slot only
knows the ghost. A wreck with nothing left goes back to being a fact:
grey, still openable, no longer advertising.
```

## Holder fit

Above `func _fit_holder() -> void:`:

```text
THE HOLDER IS THE SHIP'S BOX, NOT THE CANVAS (pack clipping, Oct 13).

Every slot reserved the whole canvas whatever was painted in it, so two
contacts asked for more than the arena's half and the second was cut off at
the screen's edge. The art measures its own ship (`custom_minimum_size`,
symmetric about the canvas middle); the holder takes that, and the canvas
sits centred inside it at a negative offset, which is `_art_base`.
```

## Pack formation rooms

Above `static var _fit_cache: Dictionary = {}`:

```text
THE ROOM THE SHIP KEEPS, IN ITS PARTS, for packing a rank behind into the
shoulders of the rank in front (Jon's formation, "shield:A"): its words'
lines (as wide as the widest it can say), its shield's oval (`ShieldFx.fit`,
the shield's own), and its plate (name, brace and hull bars, number, one row
of chips). In the slot's own coordinates, the slot `unit(s)` in size; drawn
at `s` already (the layout sets the size first). Each is [kind, Rect2]:
&"box", or &"oval" for the ellipse inside the rect. Empty for a wreck row,
a side readout, or a slot not drawn at `s`.
```

## Hit layers wait

Above `var layers_wait := false`:

```text
THE HIT LAYERS WAIT FOR THE PACK'S SIZE (perf, Oct 27). A pack of three or
more is drawn from half sheets, a size its layout sets after the bind
(`EncounterView._layout_pack`, through `apply_scale`). The layers are built
from the picture at the size it is drawn, so they were built at full size in
the bind and thrown away a moment later for the half sheet's: the full build
is the dearer of the two (on Jon's Mac 160-410 ms a ship, against 45-155 at
half), and a pack of three paid it three times as its fight opened. Set by
the view on a new slot before its first bind; the size changing builds them,
where the rebuild was, so everything after reads the same layers it did; or
`layers_sized`, if the layout leaves the size as it was.
`-- sheet=PackArmProf` times it.
```

## Reserved readout

Above `var reserve_intent := true`:

```text
THE READOUT'S ROOM IS RESERVED FOR THE FIGHT. Whatever this kind can say --
every move in its loop and its pool, and a set piece's escape -- has its
lines kept above the hull, and the rows under it (name, brace and hull bars,
number, one row of chips) are counted whether showing or not. So the slot is
one size from the opening to the wreck: a kill or an intent changes words,
never the formation (Jon: "the enemy dips down and then pops up"). LOCAL's
wreck rows say no intent and reserve none (`reserve_intent` false).
```

## Reticle bounds

Inside `_draw()`, above `var pad := 3.0`:

```text
THE HOLDER'S POSITION, THE ART'S EXTENT.

The holder is a fixed 240x120 -- EnemyArt.W by .H -- whatever is painted in
it, so bracketing the holder framed the same big empty box around a cutter
as around a hulk. `used_rect()` is the bounds EnemyArt tracks as it paints,
which is the ship and nothing else; it keeps its own rather than asking the
image, because a starfield goes down first and would swallow the answer.

The holder still supplies the ORIGIN. The art's own position is measured
inside it and is zero at rest, so using that would put the brackets in the
slot's top corner -- and the holder is the one that does not move, which is
what lets a reticle frame where the ship is going to be rather than chase
it in from off-screen.
```

## Damage preview number

Inside `_draw()`, above `if _hot and _drag_text != "":`:

```text
The number, over the target, while a card is held above it.

It used to live as a small label under the health bar and it read as part
of the enemy's own readout — a permanent stat that happened to change.
Painted across the target only while you are holding a card over it, it is
obviously a QUESTION being answered: this card, this enemy, this much.
The same letters the shot will pop when it lands (`HitText`).
```

## Fauna motion

Above `var _fauna: FaunaMotion`:

```text
THE CUSTODIAN AND THE MEGAFAUNA MOVE ON THEIR OWN (`FaunaMotion`, Jon's
picks of Oct 13). The motion draws in the art's place, as a child of it, so
the fly-in, the bob and the hit's flash (said to the art's `self_modulate`,
which the motion copies) all still reach it; the art keeps drawing every
picture as it always has, only its texture is off while the motion shows.

The motion is cut from the picture the art would show WITHOUT a wind-up (its
own charge is the motion's to light) and WITH the fight's hit marks
(`art.marks`, `HitLayers`), drawn here and cut on a worker thread, once per
picture: a new mark, a new wound band or the pack's half sheet cuts again
(one cut at a time; the newest picture is cut next), and the old cut moves
on until the new one is in. Without motion (reduced motion, headless,
`FaunaMotion.enabled` off) none of this exists.
```
