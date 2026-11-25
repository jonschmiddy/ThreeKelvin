The reasoning behind `tkg/scripts/sim/TagTest.gd`.

## Test purpose

Above `var _tree: SceneTree`:

```text
STRIPPED-DOWN UI T1, T2 and C3 (Jon, Nov 9). Three rules, held through the
real screens headless: a tooltip is one hologram tag right above the thing it
names, clear of it, inside the screen, one sentence and no title (the HUD's
hull gauge; a rich tooltip, the hull's perks, keeps its body on the same
plate); each keyword on a card in the hand is its own hover target whose
sentence shows at once on the card's picture, the word lit, and no
whole-card readout opens any more; the chart's JUMP is a 56 px ember plate
with the star's name on it, the refusal word on a dark plate of the same
size, the panel down to danger, fuel and warnings, the survey on the star's
tag. The pure rules first (`TagLayer.plain`, `HoloTag.place`, `sentence`,
`measure`), so a failure names the rule before the screen. Without the
layer (08534bae) the first section fails to compile.
```

## Markup

Above `func _markup() -> void:`:

```text
EVERY CARD, NOT ONE (Nov 24). Bank the Fire printed "BRACE 6. BRACE FROM
HEAT]BRACE FROM HEAT[/URL]." because the long term's markup still held the
short term, and the next replace rewrote inside it
(docs/why/CardData.md#rich-description). The old check looked at one card
in one hand. This one takes every module's cards and every malfunction, in
four forms: plain, every clause paying, a live damage number, and each word
lit with its clause paying. For each form it checks four things. No token
mark is left. Every "[url=" has its "[/url]". Every [url] is exactly
`keyword_markup`'s shape round its own word. With every tag stripped, the
text is `describe()` letter for letter. The tokens are \u0001N\u0002, so
the check also holds that no keyword has a digit or either mark in it.
Bank the Fire, Shroud and Corona are named, as the three that carry "Brace
from heat". A paying Brace must still find its tag after the tokens and
turn its 6 green.
```

## GUI by hand

Above `func _gui_point(root: Control, p: Vector2) -> void:`:

```text
Headless keeps no GUI hover: the root window never hears the pointer enter
it, so Godot never works out what is under a pushed motion and sends no
mouse_entered or mouse_exited. A loop BETWEEN two hover targets cannot show
without them. So the harness does that part of the GUI's job by hand, as
Godot 4.7 does it. The control hit is the topmost visible one under the
point that takes the mouse, later children first. A clip hides what it
clips, IGNORE passes through to the children, and a DISABLED
mouse_behavior_recursive up the tree makes a control IGNORE. Its chain runs
up through PASS parents and ends at the first STOP. Controls that left the
chain get MOUSE_EXIT and mouse_exited, then new ones get MOUSE_ENTER and
mouse_entered, root first. The notification alone sends no signal: the
first run of this harness raised no gallery copy because of that. Then the
motion goes to each control in the chain, at its own coordinates.
```

## Held word

Above `func _gallery_words() -> void:`:

```text
Jon, Nov 24: "In the dev card viewer, hovering over the underlined words
makes the card vibrate lol". The pointer is held on a keyword of the
gallery's risen copy for 60 frames, with a motion every frame, the most a
still hand sends. The copy must stay the same instance, its rect and its
text box's rect must not change, its word must stay lit every frame, and
the grid card under it must hear no exit and no enter. Before the fix the
copy's text box took the hover, so the grid card left, the copy was cleared
and raised again: a new copy every frame or two, rising from the grid
card's spot. `_held_hand_word` runs the same hold on a lifted card in the
hand, where the word's tag must also stay up as the same tag.
```
