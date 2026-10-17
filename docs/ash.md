# A.S.H. — Autonomous Systems Handler

The ship's AI, and the one person aboard. Named for Ashlee, by Jon, Oct 17.
Her voice was chosen by Ashlee: **dry, humorous and teasing.** Her face is a
**hologram.**

Status: brief and 26 approved lines (`docs/ash_lines.json`). Nothing in the game yet.

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

## Where she shows up (planned)

1. A portrait slot on LOCAL and in fights, driven by `Run.heat`, `Run.heat_cap()`
   and `Run.hp` / `Run.max_hp()`.
2. Her lines in the log at the moments above, from a data table (like the cards),
   so more lines never need code.

Later, maybe: a voice (ElevenLabs — ask Jon before spending), and lines that
shift with the hull's manufacturer.
