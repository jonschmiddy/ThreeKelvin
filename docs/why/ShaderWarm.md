The reasoning behind `tkg/scripts/ui/ShaderWarm.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Shader warm

Above `const QUIET_MS := 250`:

```text
THE SECTOR MAP'S SHADERS COMPILED BEHIND THE TITLE MENU (Oct 27, on Jon's
Mac: Intel Iris Plus 645, Apple's own OpenGL).

Godot's OpenGL renderer compiles a canvas shader the first time something is
drawn with it, on the main thread, and the frame waits. The chart's are
compiled behind the boot splash (`ChartSky._warm`); nothing else was, so the
first sector map stood still while its own compiled: about 0.8 s of its
first frame's 1.6 to 2.5 s on this Mac (`LadderShot first timing`). And
Apple's OpenGL hands Godot no program binaries to keep (its shader cache
folder comes out empty), so that is every launch, not only the first.

So they are compiled here instead, one each frame while the title is up:
drawn once into a 4x4 picture of their own, never shown, the way the game
draws them -- a rect, and the fabric as a mesh, which is a program of its own
(`draw_mesh` binds the attribute variant). Nothing drawn on screen changes.
A compile is a frame the title does not answer in, so none is started within
QUIET_MS of the player moving the mouse or pressing anything (`note_input`,
fed by the title's own `_input` from the moment it is up, so a hand already
moving when the warm begins holds back the first compile too; and never in
the first QUIET_MS after this node arrives), and only the
cheap ones are here: each costs this Mac at most a frame as long as the
title's own longest (0.4 s, `-- sheet=WarmCost`). Not on the hull pick,
whose hull bobs and burns, so a held frame there would be seen; what is left
when the title goes is paid where it is used, as before.

LOCAL'S ARE NOT HERE, ON PURPOSE: `planet` takes 13 to 16 s to compile on
this Mac, `sun` and `sky_nebula` 1.9 s each. Behind the title that froze the
menu for as long (measured), so they are still compiled by the first LOCAL.

`-- warm=0` turns it off (to measure a launch without it); so does `off`
(`-- sheet=WarmCost`, which times the compiles itself).
```
