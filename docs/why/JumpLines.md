The reasoning behind `tkg/scripts/ui/jump/JumpLines.gd`, `tkg/scripts/ui/jump/JumpDots.gd` and `tkg/shaders/jump/jump_lines.gdshader`; each heading is referenced from the code by a `Why:` line.

## Streaks

The films drew their streaks with a Python loop: one sample a pixel from head to tail,
brightest at the head with its first pixel boosted, the longer the dimmer, summed into a
float light array. R1 has about 4000 of them a frame. In the game each streak is one
instance of a unit quad in a `MultiMesh`; the vertex shader builds the quad from the
instance's own numbers (its transform's origin and two axes, which carry data, not a place)
and this instant's uniforms, so moving a thousand streaks costs the CPU nothing a frame.

- Mode 0 is a given line: head, tail and their brightness, set from GDScript (R5's snap lines).
- Mode 1 is R1's stars: the home, the brightness and the lag; head and tail come from
  `r1_star` (`jump_r1.gdshaderinc`), the same law the world pass uses to paint the homes bare.
- Mode 2 is R1's flow: angle, phase, speed and depth; the head runs out from the pinhole on
  `fract(u0 - phi * v)`, phi being the speed curve's integral, as the film's.

The quad covers just the pixels the film's line touched (half a pixel across, scaled by the
line's major axis) and the fragment shader steps along it in whole samples, so a streak is
the film's run of pixels, not an antialiased line. The light is pre-scaled into the stage's
light buffer (`docs/why/JumpStage.md#light-buffers`).

The class is named as the plan named it (JumpLines, "vertex-shader strips; R1, R8, R9, R14").
Modes 1 and 2 are R1's; a film that needs another law adds a mode.

## Dots

Single pixels of light (R1's sparks, R5's foam): a `Node2D` drawing one-pixel rects with an
additive material into a light buffer. They are few (under 300), placed in GDScript from the
films' closed forms in t, so a `MultiMesh` would buy nothing.
