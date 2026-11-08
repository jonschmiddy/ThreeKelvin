The reasoning behind `tkg/scripts/ui/LocalSubject.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Subject staging

Above `const INDEX_PATH := "res://art/subjects/index.json"`:

```text
WHAT AN ENCOUNTER IS ABOUT, IN LOCAL'S SCENE (Jon: LOCAL scenes "rich and
unique"; the audit, scratchpad `local_role/subjects.md`). An option in
`OptionTable` may carry a `subject`: which kept pieces of art, and how they are
staged -- one crate, six tanks on a tether, nine of them in a line, a field of
mines, a herd round a body of ice, containers clamped to a rock in rows. While
that event is open on LOCAL, and while you are parked where it stands, this
draws it: on the subject side, right of centre and opposite your ship, at the
ships' own pixel scale, above the event's band, behind the hulls.

GROUNDED, NOT PASTED ON ("ground what you draw over the scene"): every piece is
lit from the system's star side and shaded on its far side in steps, its
star-facing edge caught in the star's colour, far ones dimmed toward the sky,
and pulled toward the system's own palette where LOCAL has one
(`local_subject.gdshader`); PAINTED steps its light harder instead. The rocks
and the ice moon are not sprites: the planet painter draws them (`PlanetView`,
lit by the star like any world), cut to a lumpy outline as the approved
samples were.

ONLY GENTLE MOTION: pieces drift a few pixels and turn a degree or two over
many seconds, creatures swim as slowly, a tumbling pod tumbles slowly.
Nothing here moves fast, and nothing at all under reduced motion.

CONTENT IS DATA. The staging kinds are the code (`_stage_*`); which pieces,
how many and where are the option's `subject` (see `OptionTable`), and the art
is `art/subjects/` with its `index.json` (`tools`: the scratchpad's
`sync_subjects.py` copies Jon's KEEPs in).

A `subject` is one stage, or `{layers = [stage, ...]}` drawn back to front.
A stage:
  stage   single | row | tether | field | herd | line | around | on_rock | strewn
          | ring | group | structure
  pieces  piece ids from the index, cycled; or `role:<name>` (a kept pool
          ship of that role, the same one for this encounter every time:
          `resolve`). Never the fight's own coded ship (`EnemyArt`): Jon
          picked kept pool ships on LOCAL, and the fight draws its own
  count   how many (row, tether, field, herd, line, around, on_rock)
  at      offset of this stage from the subject's centre, px
  r       a painter piece's radius, px (else the recipe's own)
  base    a painter rock or moon the stage sits on or round (around, on_rock)
  span    how far it runs, px (row, tether, line, herd, field)
  near    how many of a row/herd/line/field are near (1x); the rest are far
          (half scale, dimmed toward the sky)
  seed    the scatter's seed
  pick    the stage's pieces are KEPT TAKES OF ONE THING (Jon kept more than
          one): one of them is drawn, picked per system the way the sky's
          looks are (`pick_of`: the system's index with the run's galaxy) --
          the same take at the same system every visit in a run, another
          take at another system, so every kept take gets seen
  tumble  a slow tumble, degrees (single)
  roll    single: turning right over, degrees a second, through the soft
          turner -- never stepped
  spin    single: a ring of modules spinning about its own axis, seconds a
          turn (its index record's `spin`: the ring unwrapped into a strip;
          `ring_spin.gdshader`), its modules travelling round it, the light
          staying with the star, its own lights riding round with them
  lift    strewn: each piece's offset down (+) or up (-) from the line, px
  turn    strewn: each piece's turn, degrees -- turned once when it is built,
          pixel for pixel (`turned`), never turned on screen, so it does not
          shimmer; it only drifts
  gap     strewn: the air between neighbours, px
  far     strewn: the whole stage far (half size, dimmed toward the sky)
  ships   group: [{piece, at, far?, turn?} + any of the ship states below],
          each placed where it says
  rx, ry  ring: the ellipse the ships hold, px; the back half far
A SHIP'S STATE, on a stage (every piece in it) or on one ship of a group:
  dark    0..1, cold: no heat, no lights, lit only by the star
  lights  &"run" (running lights) | &"battery" (a few dim ones, breathing) |
          &"patrol" (red and blue, turn about)
  drive   its drive lit at the stern
  flood   a floodlight from its bow, on you
  tow     a slack tow line off its bow, px long
  dock    group: {to = <index of another ship in the group>}: this one is ON
          that one -- set down on its top edge, touching it and not crossing
          it, clamped there (two clamps drawn over the seam), moving with it
And on a stage: `strobe` (a light run along the line of its ships).
`fights = true`, on a stage, a layer or one ship of a group: this is what the
event's fight is with. Once that fight has left its wreck here it is not drawn
again (`fought_out`, `without_foes`); the rest of the scene stays.

A BIG STRUCTURE YOU ARE PULLING UP TO (`structure`; Jon's "Pulling up to it"
page: a breaking frame, a repair yard, a clamp tower, a dead yard's cradle, a
carcass). One picture (`kind` "structure" in the index, 400 x 530 at the
ships' own pixel size) PINNED to the view's right edge -- its right edge `over`
px past it, its row `anchor` level with your ship's middle -- so it runs off
the top, the right and the bottom (under the band), from about x 540, and its
nearest part is at your height. It never moves for a fight's wrecks: it stays
BEHIND them (the hulls' row draws after this, and this takes no clicks), dimmed
the way far pieces are while they are there. It zooms and blurs with the scene
in the cutaway (`SectorScreen.open_cutaway` hands this control over whole).
Lit by the star like any piece (`local_subject.gdshader`), but by its edges
only: a light falling across 530 px would cross it in stepped bands.
  pieces   [the structure's id]
  with     [{piece, at (its centre, in the structure's own pixels), scale?,
           far?, swim?, tumble?, flip?, turn?}]: kept pieces that belong to
           it, pinned with it, drifting on their own clocks
  cluster  {pieces, count, rect (Rect2, the structure's own pixels), size
           [smallest, largest], turns, seed}: a loose knot of small things
           on it (Jon on the whale's feeders: "more small and ... facing in
           different directions"), each its own size, facing either way and
           turned its own way, scattered through `rect` (not round a point),
           clear of one another, swimming and turning a little through the
           soft turner
  add_lights  more `lights` this encounter adds (a berth lit where he waits),
           each may carry a `cone` (a spill of light that long, leftward, at
           `cone_k` of the lamp, default a half)
  with ... and on each `with` entry any ship state (`lights`, `dark`, ...)
  lines    [{from (the structure's own pixels), to (an index into `with`),
           to_at (that piece's own 1x pixels)}]: mooring lines, slack
  (any point on the structure -- a `with`'s `at`, a light's `at`, a line's
  `from`, the grip's `at` -- may instead NAME one of its `anchors`, plus an
  `off`: so kept takes of one structure, `pick`ed per system, each put these
  on their own parts)
  parted   {from, len, lean?}: a line parted at its far end, hanging and
           drifting, trailing `lean` px aside at its end (default 8 leftward)
  grip     {from_x | at}: one clamp's arm run out from the structure (from
           its first metal on the arm's row near x `from_x`, or the named
           part), level, all the way to your hull's bow, its jaws
           on your bow (touching, never across it), a red fault lamp on them
           -- the one thing that may touch your ship, as a clamp does. Its
           lattice and jaw are the structure's own (`lattice`, `jaw`)
Its life is in the index record, in its own pixels, all code and all light:
`lights` (steady | breathe | blink | flicker | cycle | glint; a light with a
`part` rides that moving part), `windows` (panes lit
as their own glow), `glows` (light baked onto its surfaces, breathing),
`sparks` (a cutting head that runs now and then), `parts` (pictures turned
live about a pivot by the soft turner and eased: a boom's `sway` or `slide`, a
cradle's arms on their `cycle`), `caps` (a layer over the parts), `swarm` (specks
crawling its ribs).

NOTHING IS DRAWN ACROSS ANYTHING ELSE (Jon: "why are they stacked on top of
each other"; "it has to make sense where it stands"). No two pieces' opaque
pixels come within the drift each can travel of one another (`mask_of`,
`drift_of`, `clear_of`), except a piece on its own rock or round its own body,
and a declared `dock`, which touches along an edge. `-- subjecttest` holds
every subject to it.
Lights, drives, floods and strobes are drawn in code over the art, as light
(gathered, stepped and dithered, eased), never painted on the pictures. A
piece's own lights are in its index record (`own_lights`, the structure's
light kinds, at its own 1x pixels): they come round with it as it turns.
```

## Small pictures

Above `static func small_image(path: String, k: int) -> Image:`:

```text
A KEPT PICTURE AT 1/k, MADE THE FLYBY'S WAY (`tools/flyby_ships.py` `reduce`,
which made the pool ships' own half and quarter pictures): each k x k block
averaged by its cover, kept where it is at least half covered, and snapped to
the picture's own commonest colours -- pixel art at its size, never every
k-th pixel of the big one. For kept pieces drawn small that have no small
picture of their own (a gutted frame in a ring, glazed hulls far off).
```

## Nose to tail

Above `static func _nose_to_tail(made: Array, st: Dictionary, span: float) -> Array:`:

```text
A LINE OF THEM, NOSE TO TAIL (Jon on the queues, convoys and strings of cargo:
"why are they so weirdly stacked"). Each next one goes on along the line only
once it is clear of the one before it SIDEWAYS -- `gap` px of air between the
one's tail and the next one's nose -- never set above or below it, so the line
reads as things one behind another and never piles into a column or a
staircase. The line runs nearly level, at most `MAX_SLOPE` up or down (`dir`
gives which way it goes and its lean): the far end a little higher, as far
things sit nearer the horizon. Its gaps close up as its pieces get smaller
(further off, closer together). Only as many as `span` holds either side of
the middle; the rest are past the edge of what you see. `jitter` lifts or drops
each one a few px off the line and `turns` turns each a few degrees (a drifting
string, not a parade), from `seed`. Centred, and any that would cross what the
scene already holds left out.
```

## Fields

Inside `_stage_field()`, above `var turns := float(st.get("turns", 0.0))`:

```text
NOT COPIES PASTED IN (Jon on the mine drift and the scatter: "super busy?
idk they look just copy and pasted in"), when a field asks: `turns`, each
piece turned its own way up to that many degrees (once, pixel for pixel);
`deep`, the last that many a quarter size, further off still, so the field
has three distances and not two; `band`, the field a stream leaning that
many degrees, things drifting through along a line, not a round cloud.
```

## Loose herd

Above `static func _loose_round(st: Dictionary, body: Dictionary) -> Array:`:

```text
A LOOSE HERD ROUND A BODY (Jon on the ring of feeders: "????????"; then
"why are they touching the moon"): each somewhere near it at its own distance
from it -- more in front of it than behind -- at its own size (`size` at
most, down to a quarter of it behind), turned up to `tilt` degrees and facing
either way, from `seed`. Each keeps clear of the others, and `apart` px of
sky clear of the body itself; one that cannot is left out.
```

## Clamped pieces

Above `static func _loose_on(st: Dictionary, clamp_id: StringName, face: Vector2, rock: Dictionary) -> Array:`:

```text
CLAMPED WHERE THEY WERE DROPPED, NOT IN ROWS (Jon on the welded rows: "why
are they so weirdly stacked"): `count` pieces in one patch of the rock's face
(`spread`, round `face`), each turned up to `turns` degrees, each held by its
own clamp at its foot, each clear of the others and every corner of it on the
rock (none hanging past its edge), from `seed`. Side by side, never one above
another (Jon: "literally a stack"): no two share any width. `size` draws them
smaller against the rock (half: their own picture's every other pixel, not
dimmed -- they are on the rock, as near as it is).
```

## Role casting

Above `static func resolve(s: Variant, oid: StringName, danger: int = 1, sys: int = -1) -> Variant:`:

```text
THE SAME SHIPS FOR THE SAME ENCOUNTER. Every `role:<name>` in a subject
becomes a kept pool ship of that role: the encounter's id picks where in the
role's list it starts, and each further ship of that role in it takes the
next one along. So one encounter shows the same ships every time, the ships
inside it differ, and two encounters land on different ones. A stage with a
`count` and roles in its pieces gets one pick per ship, not one per entry.
A stage of kept takes (`pick`) keeps the one take this system draws.
```

## Ring arc

Above `static func _stage_ring_arc(st: Dictionary) -> Array:`:

```text
IN THE RINGS OF THE WORLD YOU ORBIT (`ring_arc`): each piece on the ring's
far arc, where it shows past the world's limb above the event's band, at
`u` across it (-1 its left end, 1 its right; past the limb is |u| over about
a half) and `lift` px off the ring's middle line, at `size` (a quarter: far
off, as big as hulls in a ring a hundred thousand kilometres across look).
Planned with the giant at its usual size; drawn where the giant is
(`_ring_point`).
```

## Fitting

Above `static func fit(box: Rect2, bounds: Rect2, avoid: Array[Rect2]) -> Dictionary:`:

```text
WHERE THE STAGING GOES AND HOW BIG: its middle in the middle of `box`, at 1x,
unless something it must not cover is in the box (`avoid`: the wrecks a
fight left here, which keep their places because each is a door -- click it
and its hold opens). Then it takes the biggest stretch of the box left clear
above, left or right of them (below them are their names, then the band), at
1x if it fits there and at half size, dimmed as far off, if only that does
(a quarter if not even half does).
{centre (where the staging's own origin goes), scale, clear (the stretch)}.
```

## Fought out

Above `static func fought_out(n: MapGen.MapNode, i: int) -> bool:`:

```text
WHETHER OPTION `i` AT `n` WAS A FIGHT THAT HAS BEEN FOUGHT HERE (Jon, Oct 22:
"When you destroy a ship in combat, sometimes another ship randomly pops
up?"). A fight's subject is the ship it is about (`hostile_contact`'s
gunboat), but the fight flies in its own ship (`EnemyArt`) and leaves that
one's wreck. So after the kill the bar's event (still the fight, RESOLVED)
drew its subject again, whole and beside the wreck of what you shot: a
second enemy out of nowhere. True when the option leads to a fight (tagged
`fight`, or a choice declares one), someone has taken it, and a wreck lies at
this place. A fight walked away from (BURN PAST) leaves no wreck, and its
ship is still there to draw; a fight fled leaves none either. Then only what
the subject marks `fights` goes (`without_foes`).
```

## Moving parts

Above `func _structure_parts(rec: Dictionary, p: Dictionary) -> void:`:

```text
A STRUCTURE'S MOVING PARTS GLIDE (Jon, round two: "can the motion be more
smooth?"; stepped poses and whole-pixel sways were the first round). Each
part is a picture with its pivot at its middle (a boom's joint, an arm's
shoulder), turned live about it by the soft turner (`PixelTurn.Turner`: 16
points a pixel averaged, its edge partly clear -- the turn Jon picked for
sprites), eased on its clock (`_structure_clock`), never rotated on screen
and never stepped. Its own material, lit as the structure is. Then `caps`, a
layer the structure's own size over them (the arms' shoulder discs).
```

Above `func _structure_clock(rec: Dictionary, t: float) -> void:`:

```text
THE STRUCTURE'S MOVING PARTS ON THEIR CLOCKS, turned or moved live and eased,
never stepped: a boom swaying about its joint (`sway`: `deg` either way over
`period` s, a sine); a boom sliding to and fro along its girder (`slide`:
between `dx[0]` and `dx[1]` px, eased, by any fraction of a pixel -- the soft
turner's shift, in its `pad`); a cradle's arms gliding shut and open again
(`cycle`: `deg` at shut, eased by `cycle_close`).
```

## Pixel turn

Above `func _turn(rec: Dictionary, rot: float, shift: Vector2) -> void:`:

```text
A PIECE TURNED IN A PICTURE OF ITS OWN (`PixelTurn`, STEPPED or BLENDED; off
unless asked): its own turn and this frame's tumble or roll (`rot`), turned
in one go from the unturned picture its size draws, by `pixel_turn.gdshader`,
and shown unrotated at 1:1. A mirrored piece turns the other way about its
own turn (`Sprite2D` mirrors the turned picture). Its light is worked out in
the screen's frame, as before (`to_star`, the caller).
```

## Rock form

Above `func _rock(rec: Dictionary, p: Dictionary, k: float, w: int, h: int) -> void:`:

```text
A LUMPY ROCK WITH FORM (Jon: "kinda flat rock", "rock sucks kinda boring").
The planet painter lit a round world and cut a lumpy outline out of it, so its
light never followed the rock's own shape. Here the rock's own outline makes
its shape (`rock_form`: a dome that follows the outline, waist and all), and
the shader lights that from the star every frame (`local_subject.gdshader`,
`rock`): a lit face in the world's own rock colours stepping down through a
dithered terminator to a dark side, ridges and lumps from noise, craters with
a bright lip toward the star and a shadowed bowl, and a rim caught in the
star's colour -- then the scene's palette over it like every other piece.
```

Above `static func rock_form(p: Dictionary, k: float, w: int, h: int) -> Dictionary:`:

```text
The rock's shape as a normal map, built once per recipe and size: its lumpy
outline (`lumpy_mask`), the distance in from that outline at every pixel
eased into a rounded profile (so a two-lobed rock is two domes and a saddle,
not one ball), smoothed, and its slope packed as RG (x, y; 0.5 is flat), B the
depth in from the edge, A inside. And a few craters on it, where there is room:
[x, y, radius, depth] in its own pixels. {tex, craters}
```

## First frame placement

Inside `_layout()`, above `if is_inside_tree() and (not _placed.is_empty() or fx != null):`:

```text
AND THE PIECES PUT WHERE THEY STAND, NOW. They are placed each frame in
`_process`, and a subject built after this frame's process pass -- the
fight's screen, built as LOCAL in the swap that `Router.start_combat` makes
from a tween's callback -- was drawn once with every piece at its holder's
origin, the top left corner: the event's ship blinked out for a frame as the
fight opened (nav audit, Oct 17). `_build` ends here, and so does a resize.
```

## Cutting head

Above `func _sparks(sp: Dictionary, t: float, dim: float) -> void:`:

```text
A CUTTING HEAD AT WORK (`sparks`; Jon: "Can we have the arm that makes the
sparks actually interacting with the ship?"): every `period` s it runs for
`run` s from `start`, eased in and out, where its rim meets the plating (`at`,
riding the part that carries it, `part`) -- its nozzles burning blue-white, a
hot spot on the plating, and sparks thrown off along the surface in cones
(`degs`, each +- `spread`), each flying straight, fading over its own short
life.
```

## Engine flame

Inside `_draw_over()`, above `var burn := -1`:

```text
THE ENGINE FLAME (look A, Oct 13): a ship under way (`drive`) burns at
CRUISE, a lit one sitting here idles (Jon: "a gentle idle burn ...
anywhere a ship sits"), a dark one is dead. Its engines are the
picture's own or art/engines.json's, drawn in the piece's own frame
(its turn, its mirror, its size) so it leaves the stern wherever the
piece is pointing.
```

## Piece light

Above `func _draw_piece_light(t: float) -> void:`:

```text
LIGHT ON A PIECE THAT IS NOT ITS OWN LAMPS, as light (eased, never snapped):
  glint &"beam"   its high edge catching a pulsar's beam as it crosses
                  (`LocalFx.beam_hit`): an instrument rack, a field's metal
  glint &"glaze"  a thick glaze catching the light here and there, each
                  point brightening and fading on its own slow clock
  lights &"shaded" a cooked machine's last lights, on its shaded side only,
                  each blinking once just after a flare of the star
  window [x, y]   one lit window (someone listening), warm, breathing a
                  little
```
