The reasoning behind `tkg/scripts/ui/CutawayView.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Cutaway

Above `signal closed`:

```text
THE CUTAWAY (Jon: "THE CUTAWAY IS CLEANNNN."; scratchpad `local_role/cutaway`
and notes section 4). On LOCAL, out of a fight, click your own ship: the
camera pushes in on it -- the scene itself, LOCAL's or the yard's, zoomed onto
your ship (Jon: "can we actually just zoom into the scene?"),
every fitted part lifts off its mount on a dotted leader line to a labelled
tag, empty mounts show as rings, and the LEFT PANEL slides in: the ship's
name (and a pencil to rename it), its hold, its numbers, perks, set bonuses
and any malfunctions, the R and F keys, and DONE. Point at a module anywhere -- the hold,
the hull, the popup -- and the MODULES page's own popup for it shows beside
it. SECTOR LOOT on LOCAL's bottom bar (left showing under the cutaway) opens
this system's own pile in a popup beside it. A wreck is not opened from in
here: a click on it is a click on the sky. Drag between the
hold, a popup and the rings on the hull. Close with a click on the ship or
the sky -- anywhere that is not the ship, its parts, tags and rings, the left
panel or a popup; with a popup open, that click shuts the popup first -- Esc
(a popup first), or DONE. A drag let go of anywhere else puts the part back
and shuts nothing.

EVERY MOVE IS RUN'S RULE (`RunState.lift_part` / `fit_at_mount` / `stow_at`),
the same calls the refit screen makes, so the two cannot disagree; the loot is
claimed through `Run.take_item` / `take_from_jetsam`, the same calls the
map's SECTOR LOOT popup (`TransferView`) makes, so taking a thing in one shows
it gone in the other. Local only: nothing here is sent over the network
beyond what those calls already send.

The hull is drawn here at the push-in's scale (2x wherever the lifted parts
and their tags fit round it right of the left panel, else 1x: a 960x540 game
has no clean 1.5x), and LOCAL's own hull is hidden while it is open, so the
backdrop the shader breaks up is the sky and everything in it but your ship.
```

Above `var scenes: Array[Control] = []`:

```text
THE SCENE ITSELF IS ZOOMED (Jon, in the yard: "can we actually just zoom into
the scene?", and then "LOCAL should zoom the real scene too"): the pictures
your ship is drawn in -- the yard; LOCAL's ships, dust and shots -- are
scaled with the push-in, 2x onto your ship in the same whole-pixel steps, and
carried so your ship in them lands where the parts are lifted from. Your ship
there IS the ship here: this view's own hull is not drawn, only the parts
lifted off it, their lines and tags. `sky` is LOCAL's sky, zoomed layer by
layer by its own depth (`LocalSky.set_zoom`). All put back on close.
```

Inside `_measure()`, above `if _src != null and is_instance_valid(_src) and Router.animating() and _src._bob_amp > 0:`:

```text
THE SHIP KEEPS ITS IDLE BOB (Jon: "the ship and modules should still be
hovering slightly"), in art pixels, so at 2x it steps two screen pixels at a
time; the lifted parts, their lines, tags and rings ride the mounts, which
follow it. Where the scene itself is zoomed, LOCAL's own ship IS the ship,
so this one takes its step from it, frame for frame (`_process`), rather
than keeping a clock of its own a frame apart. None under reduced motion.
```

## Exploded layout

Above `func _layout(kk: int, room: Rect2) -> Rect2:`:

```text
THE EXPLODED LAYOUT, in sprite pixels at scale `kk`, inside `room` (screen
px, the hull centred in it). Each fitted part goes to the NEAREST place --
straight out first, sideways costing a little more -- where it and its tag
are inside the room, off the hull's own pixels and clear of every part, tag
and ring already placed; its tag beside it (toward the hull's middle first)
or above or below it, which is what lets parts stack in narrow columns off a
heavy's nose and tail. Then each empty mount's words: near its ring, or, where
there is no room near it, in the nearest clear space with a leader to it.
The boxes are the ones `MountPoints` draws (`tag_box`, `label_box`), so what
is kept apart here is what is on screen. Written into the mounts widget
(`lift`, `tag_side`); `_layout_ok` says whether everything found a place.
Returns the whole picture's bounds, in sprite px. Skipped when nothing it
reads has changed: a move in the hold is a `ship_changed` too (#34).
```

Inside `_layout()`, above `_words_ok = true`:

```text
AND WHERE THERE IS NO ROOM NEAR THE RING, THE NEAREST CLEAR SPACE, with a
1 px leader back to it (Jon: "There is no text for an empty utility, just
empty systems and empty weapons."). The ring used to keep itself alone
here, and "EMPTY UTILITY" -- the widest of the three words, on mounts set
deep in the hull's middle -- never once found room within the near reach,
so the utilities lost theirs on every hull and the heavies' inboard guns
and systems with them. Still never on the plating, another word, a part, a
tag or a ring, and the leader crosses none of them either. Kept out of the
bounds the picture is centred on, so no word set out here moves the ship
or anything on it; inside the room as it really lands.
```

## Cutaway card

Above `func _show(m: Variant, at: Rect2 = Rect2()) -> void:`:

```text
THE CARD FOR WHAT IS POINTED AT: the MODULES page's own popup for it (Jon:
"Why don't we use the old module popup (the one that's on the module page)"),
built by the same function -- `ModuleIcon.tip_for` -- so the two cannot
drift; on the theme's tooltip plate, as Godot draws it there. Beside the
thing pointed at, right of the left panel, off any open popup, never on the
thing itself; placed once when what is pointed at changes, not every frame
(the hull bobs under it). Null hides it.
```

## Left panel

Above `func _build_left() -> void:`:

```text
THE LEFT PANEL, the cutaway's only one (Jon, in turn: "Maybe we can have the
hold in a panel to the left?", "The hold AND the stats can go in the left
panel maybe?", "maybe we don't need the bottom drawer?", "no right panel",
"the hold on top and the attributes on the bottom"): the ship's name, its
hold at the hold's own cell size -- every row of every hull's hold on screen
-- its numbers, then DONE. The cutaway's full
height (it ends above LOCAL's bottom bar, whose SECTOR LOOT opens this
system's own pile in a popup here); it slides in from the left with the
push-in.
```

## Cutaway popup

Above `func open_popup(h: MapGen.Jetsam, beside: Rect2) -> void:`:

```text
A CONTAINER, OPENED BESIDE WHAT OPENED IT: this system's own pile, from
SECTOR LOOT on LOCAL's bottom bar. (A wreck's bay was one too, for a round;
Jon: "Just keep the original popup" -- wrecks open LOCAL's two-grid screen,
from outside the cutaway.) Its title,
its grid (four across, three rows shown before it scrolls), TAKE ALL and a
close. Drag out of it to the hold or straight onto a ring; drag from the hold
into it to put a thing down. One at a time.

A LIGHTER SHELL THAN `TransferView`, on purpose: that screen is a whole page
with its own copy of your hold beside the container, and here the hold is
already on screen. What it shares is everything that decides anything -- the
grid (`SalvageGrid`) and the calls (`take_item`, `take_from_jetsam`,
`put_in`) -- so the two cannot disagree about what is left in a wreck.
```

## Hull outline

Above `class Outline extends Control:`:

```text
THE AMBER OUTLINE IN THE HULL'S OWN PIXELS, while the pointer is on your ship:
every clear pixel touching an opaque one, so the line hugs the silhouette and
nothing else on screen gets one. A child of the ship's view, so it rides its
bob.

FOUND ON THE GPU, FROM THE SHIP'S OWN TEXTURE. It was traced here a pixel at
a time (`get_pixel` through a lambda, five per pixel of the canvas) every
time the bob stepped: 40 ms on the main thread, a stall about every quarter
second for as long as the pointer stayed on the ship -- the hitch Jon saw as
his ship came to rest under the pointer (Oct 13). The shader asks the same
question of the texture the hull is drawn from, so it follows every repaint
for nothing.
```
