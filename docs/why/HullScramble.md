The reasoning behind `tkg/scripts/ui/HullScramble.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hull scramble

Above `const NOISE := SignalText.NOISE`:

```text
THE WORDS DECODE BADLY WHILE THE HULL FAILS (`LowHull`). Jon, Oct 20: "I
think the text should glitch more like the decoding. It should be ALL of the
text on the screen. With it getting worse as the health lowers." And then:
"This goes outside of combat too." "Tool tips etc. Only the ESC menu doesn't
glitch."

WHAT: now and then a letter somewhere on screen -- or a short run of them,
inside one word -- turns into the same noise `SignalText` decodes from (its
NOISE glyphs, at its NOISE_A ink, changing every NOISE_S), and then resolves
back, left to right. Every text the player can see: the HUD (its hull figure
too), the top bar, the goal line, buttons, panels, A.S.H.'s box, cards, the
chart's and the map's names, popups and tooltips. Never the escape menu or
Settings (Main's overlay layer), and nothing at all while the menu is open.

HOW MUCH follows the hull, continuously: `LowHull.depth` is 0 at TIER1_AT and
1 at no hull, eased, and from it come how many letters start a second
(`scr.rate`, rising as depth^1.5, for a screen of REF_LETTERS letters), how
long a run is (1 letter at the line,
up to `scr.run` near 0) and how long each holds (`scr.hold`). Two ceilings
keep it readable at 5%: at most `scr.most` letters scrambled on the whole
screen at once, and at most `scr.share` of any one text's letters. Every
number is the preset's (`LowHull.LOOKS`).

NOTHING MOVES, NOTHING IS REWRITTEN. No string is ever changed and no
control's layout is touched:
  * a Label, a Button or a RichTextLabel keeps drawing itself as it always
    does; a shader on its canvas item (set through the RenderingServer, not
    its `material`, and taken off after) leaves its glyph pixels out inside
    the scrambled letters' cells (`low_hull_mask.gdshader`), and a canvas
    item of this node's own, a child of the control's, draws the noise glyph
    in each cell. So it clips, fades, scales and stacks with the control (a
    tooltip over it hides it; a popup over it hides it), and a click, a hover
    and a rect are exactly what they were;
  * `SignalText` draws its own letters, so it is told which settled letters
    are noise (`SignalText.scramble`) and draws those;
  * text a screen draws by hand (the chart's names, the outcome rows, the
    cards' numbers...) asks `LowHull.scr` for the string to DRAW: the same
    string, with a scrambled letter swapped for a noise glyph of exactly the
    same advance, and the whole string's width checked equal, so not a pixel
    after it moves. Its own data never sees that string.
Whatever reads a Label's text, a save, a test, a tooltip's builder, reads the
real words, because they are never anything else.

THE COST: the texts on screen are found as they enter the tree
(`SceneTree.node_added`), never by walking it, and which of them are showing
is re-checked SCAN_PER_FRAME at a time while the effect is on. Nothing here
runs at all with the hull sound (and nothing is ever handed to a worker: it is
all RenderingServer and Control calls, which are the main thread's).
```
