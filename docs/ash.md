# A.S.H. — Autonomous Systems Handler

The ship's AI, and the one person aboard. Named for Ashlee, by Jon, Oct 17.
Her voice was chosen by Ashlee: **dry, humorous and teasing.** Her face is a
**hologram.**

Status: in the game (Oct 17), text only: her face on LOCAL and in fights, the 30 approved
lines (`docs/ash_lines.json`) at their moments. Moods and a voice are still to come.

## Why she exists

Ashlee's note: "you're a ship right now disembodied from anything, separate from
something with consciousness. People get more engaged with something that feels
alive that they can connect to."

"The ship IS the character" is a ruling, and A.S.H. is how it becomes literal:
she is the ship's mind, not a crew member. **Nobody manages her.** She has no
stats, no levels, no slot, no upgrade tree. She cannot be hired, fired or lost.

## Who she is

- **The constant.** Hulls change; she moves with you. A new frame is a new body
  she complains about. You get attached to her, not to a hull.
- **Dry.** She under-reacts. Disaster is reported like a mild inconvenience in a
  maintenance log.
- **Humorous.** The joke is usually in what she declines to say.
- **Teasing.** She needles the pilot about their choices — the greed, the heat,
  the detour for one more wreck — and is quietly on their side anyway.
- **Bureaucratic by birth.** Her designation is a job title on a work order. She
  knows it, and uses the register of filings, riders and invoices the game
  already speaks.

## What she carries

The design doc's doubt: this might be a rescue, or "a very long, very cold
delusion." A.S.H. never settles it. She can joke past it, and once in a long
while she lets a line land that suggests she has done the arithmetic too.

## How she talks

- **Short.** One line, usually under twelve words. Never a paragraph.
- **At moments that matter**, not as commentary on every action: first launch, a
  big haul, overheating, hull failing, a new hull, one more wreck, and once in a
  long while a line of doubt.
- **Nothing after the ship is lost** (Jon, Oct 17: "No lines after the ship is
  lost. The ship has blown up."). She is the ship; when it goes, she goes. Her
  last words are whatever she said while the hull was failing.
- **Never explains the world.** No lore dumps, no cosmology, no faction history
  ("No prophecy, no chosen crew, no faction explaining the cosmology in a text
  box"). If she knows more than the player, she does not say so.
- **Never cruel.** The teasing has affection under it. She roasts the decision,
  never the person.
- **Never cute.** No emoji energy, no "Yay!", no exclamation marks except in
  irony.
- Plain words. No technobabble she would have to explain.

## Her face

A holographic portrait: a face made of scanlines and projector light, in a small
frame on the main screen. It reacts to the ship, not to the script:

| The ship | Her face |
| --- | --- |
| Cold, calm | steady, half-lidded, mildly unimpressed |
| Heat climbing | flickers warmer; one eyebrow up |
| Over the heat cap | interference, colour bleeding, eyes narrowed |
| Hull low | the image breaks up, lines drop out, she keeps her composure |
| A big haul | the smallest smile she can get away with |
| Ship lost | the projection cuts with the ship, no line |

### Making the portrait (planned, Oct 17)

1. **Her face, calm.** 64x64 pixel art, shown at 2x and 3x. Three looks, one
   PixelLab pro call each (16 takes a call, about 10 generations):
   A, cyan projector light and scanlines; B, a pale white-blue wireframe face;
   C, warm amber light matching the UI. Jon and Ashlee pick one. Cap 50.
2. **Her moods**, edited from the picked face so she stays one person: hot,
   over the heat cap, hurt, pleased (the table above). Spend asked separately.
3. Never a real person's likeness: she is named for Ashlee, not drawn from her.

## Where she shows up (built Oct 17)

`scripts/ui/Ash.gd` decides, `AshPortrait` draws, `AshLines` holds the lines (held to
`docs/ash_lines.json` by `-- sheet=AshTest`, in the merge gate).

- **Her face** is one file, `tkg/art/ash/face.png`: eight 64x64 frames (four mouths, each
  with a blink), cut from the hand-drawn talk frames on B15 by `tkg/art/tools/ash_face.py`.
  When Jon picks a variation, `ash_face.py --face <png>` lays the same mouths and blink onto
  it and says how far the new face's features have moved; look at it at 2x before keeping it.
- **Where:** the top left of the picture, under the goal line's band, the face with her line
  typing beside it in the event text's signal type. It was the one spot clear on every screen
  she uses (65 built by AshTest: LOCAL with and without wrecks or a subject, fights of one to
  three ships in every weight); every other corner and the middles cover a plate, an enemy's
  words or its numbers in some fight. If something ever stands there, she tries the other
  corners and otherwise waits. Not pressable and not clickable: clicks go through her.
- **When:** each line at its own moment: a new run's launch; the first time she is up in a new
  hull; the hull at a quarter or under; over the heat cap in a fight; a chit of 60 credits or
  an epic part taken aboard; the third wreck opened since the last dock; and, from jump 6, a
  three-in-ten chance on arrival at least ten jumps after the last doubt.
- **Limits:** one line at a time; 40 s of quiet after a line (6 s before the hull failing or a
  new hull); one line a fight unless the hull starts failing in it; never during a card drag
  or the enemy's turn (END TURN takes her off that frame); nothing over a jump, an arrival, the
  camera moving, the cutaway, a wreck's window, the event band or the escape menu; a moment
  that cannot be said in time is dropped. **Nothing after the ship is lost**: up when it goes,
  she cuts with it. **Hints win**: she waits while a hint is up, settling or due on the screen.
- **Talking:** the mouth follows the typed letters, a held frame every 0.1 s, with blinks and
  one-pixel hologram slips (more often with the hull failing); about 9 changes a second while
  she talks, all on the game's clock. A two-note `text_blip` chirp as she appears.
- **Settings:** SHIP'S AI, A.S.H. ON / OFF, under HINTS. Off under harnesses unless `-- ash`.
- **Co-op:** each player's A.S.H. is their own ship's, on their own machine: she reads that
  machine's run, sends nothing, and nothing waits on her.

Later, maybe: a voice (ElevenLabs — ask Jon before spending; the voice
description and options are in the handoff, "A.S.H.'s voice"), and lines that
shift with the hull's manufacturer.
