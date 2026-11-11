The reasoning behind `tkg/scripts/sim/JumpShaderTest.gd`; each heading is referenced from the code by a `Why:` line.

## Jump shader test

Headless Godot has no renderer that compiles shaders: `shader_set_code` on it parses
nothing, so a jump shader with an error loads, its film plays on the clock, and JumpSeqTest
passes. That happened in slice 2 (a `return` in `vertex()`) and the film it broke drew
nothing. This sheet runs windowed: it draws every `shaders/jump/*.gdshader` on a 64 px rect
for three frames, then plays every landed film through `Router.begin_jump` to its commit,
and an engine logger fails it on any error (a shader that does not compile prints
`SHADER ERROR` and `Shader compilation failed`, which reach the logger). Two broken probe
shaders, the `return` and a `vec3` assigned to a `float`, each failed it.

The films play at the real clock (`--fixed-fps 60` with vsync off), every frame drawn: the
clock is `GameClock`, which `Engine.time_scale` did not speed up here. In the gate it is
`unit_jumpshadertest` (`docs/why/validate.md#unit_jumpshadertest`).
