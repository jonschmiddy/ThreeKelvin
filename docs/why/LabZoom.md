The reasoning behind `tkg/scripts/ui/LabZoom.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## The camera onto the labs screen

Above `signal opened`:

```text
THE CAMERA ONTO THE LAB'S SCREEN (science S9; Jon's 1C, Nov 4, and his
question the same day: "is the screen really big enough for a player to see
all of it?"). It is not, at the glass's own size: the capital's glass is
440x228 and the settlement's 230x124, and the board was drawn for 908x488.
So pressing the screen in the room moves the camera onto the glass until the
glass fills the window, and the Lab's pages come up on it at the board's own
size: RESEARCH (the star chart, `LabBoard`), AUGMENT and RECIPES. LEAVE, or
Esc, takes the camera back out to the room, the screen on its logo.

ONE CAMERA MOVE, NOT A CUT, from the frame after the press: the camera
moves (`LAB_ZOOM_S`, smootherstep), the screen's own effects going off the
sign-in as it sets off (`FX_S`), and carries the deck's frame, the
elevator and the HUD out of the window with the room, and the Lab's pages
come up on the landed glass over the sign-in it carried in (`UI_IN_S`).
Back out it all runs backwards: the frame, the elevator and the HUD ride
back in with the room and stand in their places on the frame the camera
lands (Jon, Nov 5: "a smoother transition with the elevator", and of the
frame fading back after: "the fact that the frame pops in is kinda
awkward, yeah?"). No still beat before the move, nor after it on the way
out (the review of aebd46f6: ZoomLadder's `UI_OUT_S` held the camera still
13 frames after the click, and 13 more on the way out with the input
eaten after the camera had stopped); the other moves keep theirs. A
click or a key during a move is eaten and the camera goes on (camera
moves, never cuts): Esc, or the pad's B, on the way in turns it round; Tab
takes the camera out at three times the pace and then goes on to the
ladder.

A PURE CAMERA (Jon, Nov 5: "I don't really like the warping of the screen
getting bigger than the room, it should stay fixed"). The room is one
picture at one scale: the lab's painted room, lit by the lab's own light
(`LabScene`'s material, so a lamp that flickers in the room flickers here),
its life (the tanks' bubbles, the monitors) and the screen's sign-on
(`LabLogin`, the very texture the room shows), all through the one camera,
sampled nearest, its origin on whole pixels. Nothing is sliced, repeated or
stretched: the frame round the glass is never bigger than the wall it is in.
The scale goes from the room's own to the lab's `ZOOM` geometrically (each
frame the same ratio bigger, as a camera closing in at a steady speed),
about the one point of the room that holds still on screen, so the glass
comes from where it stands in the room to the window's middle.

THE LANDED GLASS. Each lab's `ZOOM` is the smallest whole number that puts
the board's own glass (908x488 at 26,26) inside the lab's glass on screen:
the settlement's glass is 920x496 at 4 (its bezel, 20 and 22 px, round the
window), the den's is the window's whole width at 3 (its bezel 9 px top and
bottom, which the board's ground covers: `board_rect`), and the outpost's, the city's and the capital's go past the window
on every side, so their glass is the whole window. The board is laid out as
it always was: the chart's ground runs on to the lab's glass edge, wherever
that is (`lab_chart.gdshader`'s `rpos`).

THE DECK'S FRAME IS PART OF THE PICTURE (`_frame`): the deck page's plate
round the room (its backing and its border) drawn through the same camera,
at the room's pixel size, so the room is never a bare rectangle on the dark
and nothing round it fades. It replaces the plate the frame the camera
leaves the room, and hands it back the frame it lands, the two the same
pixels there. (Round three let the room's edge fall away into the dark, a
veil faded on before the move and off after it; with the plate fading the
same way, the frame popped back after the camera landed.)
```

## The cameras zoom at each lab

Above `const ZOOM := {"unclaimed": 3, "outpost": 4, "settlement": 4, "city": 4, "capital": 3}`:

```text
THE CAMERA'S ZOOM AT EACH LAB, a whole number: the smallest that puts the
board's glass (`GLASS`) inside the lab's glass on screen. The glass on
screen at that zoom (labs.json `screen.glass`):
  unclaimed  438x174 x3 = 1314x522, the window's width, 9 px of bezel top and bottom
  outpost    276x176 x4 = 1104x704, past the window all round
  settlement 230x124 x4 =  920x496, a bezel of 20 px each side and 22 top and bottom
  city       268x142 x4 = 1072x568, past the window all round
  capital    440x228 x3 = 1320x684, past the window all round
At one less, each is too small for the board: 876x348, 828x528, 690x372,
804x426 and 880x456.
```

## Next screen

Inside `_input()`, above `if key != null and key.pressed and not key.echo and key.is_action_pressed(&"next_screen"):`:

```text
NEXT SCREEN (Tab) WITH THE CAMERA IN THE GLASS: out to the room, the
station's chrome back, and then the key for Main, so the ladder's move off
the station starts from the room it knows (it played under the Lab's
picture, and the map arrived as a cut). The camera goes out at three times
its pace rather than jumping: it moves, never cuts. Unanimated (a harness)
it is out at once and the key goes straight on.
```

## A press during a move is

Inside `_input()`, above `get_viewport().set_input_as_handled()`:

```text
A PRESS DURING A MOVE IS EATEN, AND THE CAMERA GOES ON (camera moves,
never cuts: it used to finish the move at once, a jump). Eaten, a click
on the way out cannot open the Lab again from the glass, nor the second
click of a double-click on the glass land on a page key. Esc or B on the
way in turns the camera round (not on to the pause menu over a Lab that
just landed).
```

## The elevator and the hud ride

Above `func _carry(on: bool) -> void:`:

```text
THE ELEVATOR AND THE HUD RIDE THE FRAME'S EDGES (`StationScreen.lab_carry`):
moved as far as the camera has moved the deck's frame from where it
stands (the elevator by its left edge, the HUD by its top), out of the
window going in and back into their places on the frame the camera lands
coming out; `on` false puts them back as they were. By the frame, not the
room: the frame's margin grows with the camera, and carried by the room's
edge the elevator ran onto it.
```
