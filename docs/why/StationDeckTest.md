The reasoning behind `tkg/scripts/sim/StationDeckTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Test purpose

Above `var _fails := 0`:

```text
ALL FIVE DECKS AT EVERY STATION, headless:
  godot --headless --path . -- sheet=StationDeckTest
Jon, Nov 3: every station has the PROMENADE, SHIPYARD, EXCHANGE, HIRING BOARD
and LABORATORY, at every development level. The LABORATORY used to hide below
a city (RELIC ANALYSIS was dev 3) and the HIRING BOARD where no manufacturer
berths (an empty `Contracts.board`).

Through the real station screen, at each level from UNCLAIMED to CAPITAL,
once with no berth and once with one: all five tabs are on and shown and the
elevator lights five floors; the lab's screen shows the owner's logo, and
the sign-in while the pointer is on the glass (Jon, Nov 5), each inside the
screen's window, nothing overlapping (the settlement's 206 x 110 is the
smallest); the glass is the only key (a click just off it opens nothing,
Enter and the pad's A press it); pressed, the camera goes onto the glass
(`LabZoom`, science S9, Jon's 1C), one uniform zoom landing at the lab's
whole number with the board's glass inside the lab's, and RECIPES (AUGMENT's
layout, Jon, Nov 5) greys every recipe with nothing held, prices RELIC
ANALYSIS at that level and the other two at no credits, picks by a click on
a row and a ring, and its MAKE survives thirty refreshes and makes, and
the RESEARCH board passes the mockup's box test (every box inside the glass,
none overlapping, no word across an arm) with no step, some and all of them
bought and the strip on every step; AUGMENT passes it on every part and
every affix (one part augmented, one with a rolled affix, DATA short, a
hold that runs onto a second page, STRIP on each affix), costs 5 DATA and
22/20/18/16/15 credits, its key survives thirty refreshes, a click on a row
moves no part, AUGMENT and STRIP pressed through the viewport do what they
say; BUY stays one object through thirty
refreshes, never shows on a step behind the next, buys, and the board is the
same at a second station of the run; with no berth the board
posts its dock desk's work (`Contracts.dock_desk`), hangs the desk's notice,
and a job signed there is handed in at that desk; with a berth there is no
desk.
A board with nothing to post says NO WORK POSTED. and keeps its tab. The
chart names the dock desk under OPERATORS, and every such line fits the
destination panel.
```

## Address order

Inside `_dock_desk_rule()`, above `var made: Array = []`:

```text
One process keeps one address order, so the real table cannot show the
fault. A table of fresh StringNames made in reverse text order can: their
addresses fall in no text order, and a different one each process (3, 4,
2, 5, 1, 6, 7 one run and 1, 5, 2, 4, 3, 7, 6 the next on Nov 3), and a
`keys().sort()` pick follows the addresses. Checked failing on that sort.
```

## Recipes in augments layout

Above `func _recipes_page(zoom: LabZoom, here: MapGen.MapNode, tag: String, dev: int) -> void:`:

```text
RECIPES IN AUGMENT'S LAYOUT (Jon, Nov 5: "Can't we make the recipes page
like the augment page in its layout?"; `LabRecipes`). With nothing held: no
key, every recipe greyed with what it needs, RELIC ANALYSIS at this level's
price. With film and a relic: the film on the bench and DEVELOP FILM picked;
a click on a row and on a ring through the viewport picks; MAKE is the same
object after thirty `resources_changed` and, clicked through the viewport,
develops a roll (the counts, DATA and the header move) and reads a relic out
as a part. The box test passes in every state.
```

## The labs screen at rest

Above `func _sign_on(st: StationScreen, tag: String, dev: int, deep: bool) -> void:`:

```text
THE LAB'S SCREEN AT REST (Jon, Nov 5; the savers, Nov 7): the station
owner's savers, its own three and the seven every lab runs, one up at a time;
the saver's own sign-in while the pointer is on the glass, and the same saver
at rest again off it (pointing never turns it). Each look passes the box test
inside the screen's window (`LabLogin.check`), the window inside the glass,
and the glass whole in the room. `LabSaverTest` draws every saver.
```

## The move itself

Above `func _camera_move(st: StationScreen, zoom: LabZoom, tag: String) -> void:`:

```text
THE MOVE ITSELF, animated (`Router.animate_in_harness`; headless it jumps
to its end): the camera carries the deck's frame with the room, one
picture (Jon, Nov 5: "the fact that the frame pops in is kinda awkward"),
the deck's own plate hidden only while it does and whole again on the
frame the camera rests; the camera off within two frames of the press, and
at rest out, a click on the elevator two frames after is taken (the review
of aebd46f6: a still beat of 13 frames each way, the input eaten in the
second); and the
elevator and the HUD out with the frame's edges (Jon, Nov 5: "a smoother
transition with the elevator"), the gap between each and the frame what it
was at rest, never over it, gone once landed, and back in their places on
the frame it is out; Esc on the way
in turns it round and opens no pause menu; a click during the move lands
it and is eaten (it reaches no page key, and on the way out it does not
open the Lab again); Tab with the camera in takes it out at once, the
chrome back. Mid-move the room is one picture at one scale, the sign-on
riding in on its glass. The HUD's alpha and the rail's are read off the
nodes the player sees.
```

## The elevators ride between decks

Above `func _deck_ride(st: StationScreen, tag: String) -> void:`:

```text
THE ELEVATOR'S RIDE BETWEEN DECKS, animated (Jon, Nov 5: "a smoother
transition with the elevator"; the review: a dip to black is still a cut).
Pressing a floor no longer swaps the decks on the press. The deck you leave
and the deck you go to ride past the panel as one shaft, a floor slab
between them, in the car's direction, neither taking clicks, nothing
scaled; at the end only the new deck shows, in its place, taking clicks.
One floor takes at least `DECK_MIN_S`. A press mid-ride starts from where
the shaft stands (the deck on screen does not jump). The glass cannot be
pressed while the Lab rides in. Unanimated (a harness) the decks change on
the press, as before.
```

## Every elevator choice is the slide

Above `func _every_ride(dev: int) -> void:`:

```text
EVERY ELEVATOR CHOICE IS THE SLIDE (Jon, Nov 5, round three: "The slide can
be the main transition for every elevator choice"). On a fresh docking at
each level, animated, from each of the five decks to each of the other four
(twenty rides, up and down): the press starts a slide, never a cut or the
dip: both decks shown, the slab between them, the deck you go to below the
one you leave going down and above it going up; on every frame of the ride
the two decks one rigid shaft moving one way, each clipped to itself and
the lower drawn over the upper (a deck runs on past the panel); at the
car's stop only the new deck, in its place, taking clicks, its clip and z
as they were, the slab gone; and no frame moves the
shaft further than one `RIDE_STEP_S` at the shortest ride's top speed (a
deck's first frame, built as it shows, used to jump the whole ride). The
first ride onto the HIRING BOARD keeps its tubes dark till the car is
nearly in. Then `deck_move` &"dip" (the fallback) dips through the dark.
```
