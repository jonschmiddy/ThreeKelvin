The reasoning behind `tkg/scripts/ui/jump/JumpMirror.gd`; each heading is referenced from the code by a `Why:` line.

## Mirror

R15 DATAMOSH needs last frame's world: each moshed frame is the last one moved block by block.
The stage cannot keep that itself. It draws into the game view, and a frame of the game view
also holds the HUD, which must never be smeared, and the film's own output, which must not
feed back. The world has to be drawn a second time into a texture of its own.

A SubViewport given the game view's `World2D` draws the same canvas items, in the same
places, in the same frame. On its own it would draw everything: the HUD, the drawer, the
stage. Godot culls per viewport by layer: a viewport draws a canvas item only if the item
and every parent share a bit with its `canvas_cull_mask`. So the mirror draws layer 1 only,
and every canvas item off EncounterView's path to the viewport, plus the stage, goes on
layer 20 (`HIDDEN`) alone. The game view's mask is every layer, so it draws them as before.
Items in a CanvasLayer (tags, overlays) belong to that layer's canvas, not the world's, so
the mirror never sees them either. Freed, the mirror puts every layer back.

The spike (`-- sheet=JumpMoshSpike`, GL Compatibility, a real window, Nov 10) measured it:
inside the world window, away from the HUD's own lines that sit over it (the goal line and the
status bar's foot, which it rightly leaves out), the mirror matched the game view on 99.6% of
samples; it held none of the HUD bar (0 of 7080 samples equal); and a test rect put on
`HIDDEN` inside the window was not in it. The fallback, a state SubViewport fed from
LocalSky's textures and the stand-in, was not needed: the mirror carries everything the
world draws (sky, dust, effects, other ships), so they are moshed for free.

It is not updated on its own (`UPDATE_DISABLED`): the film asks for one draw on each tick of
its clock, together with the state and the output it feeds.
