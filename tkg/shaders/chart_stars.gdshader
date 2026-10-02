shader_type canvas_item;
render_mode blend_mix;

// THE GALAXY: every static star, gas block and dust pixel `_build_stars` laid
// down, one quad each (`StarchartScreen.MapChart`, the Backdrop layer).
//
// It used to be 48,000 `draw_rect` calls rebuilt in GDScript whenever the zoom
// changed -- 18ms a frame of wheel -- and resubmitted every frame even when it
// was not. The stars now sit in three textures made straight from the packed
// arrays (no loop over them), and this places each one from the uniforms.
//
// The rules are the old repaint's, unchanged:
// - placed at `origin + p * zoom`, where origin is `size * 0.5 + _sky_pan`, the
//   view the layer was last REBASED at, and then moved by `slide`, the whole
//   pixels the pan has gone since. A pan is a rigid move of this layer; only a
//   zoom, or a drag past the slide margin, rebases it. Kept exactly, because
//   rounding every star against the live fractional pan instead would shift a
//   few of them a pixel relative to their neighbours mid-drag;
// - turned in DATA, not by transform, and rounded after turning: rotating a
//   canvas full of 1x1 rects resamples a grid onto a grid, which is moire (see
//   `set_sky_rotation`). `rot` is (1, 0) when the galaxy is not turned;
// - culled on the unrounded position against the chart grown by the margin,
//   exactly as before, so a star the old cull dropped stays dropped;
// - size class 0 is a pixel, 1 a 2x2 star, 2 a gas block whose side grows with
//   the zoom (`gas_px`), so a nebula holds together as a mass when magnified
//   instead of thinning into confetti.

#include "res://shaders/chart_sky.gdshaderinc"

uniform sampler2D star_pos : filter_nearest;
uniform sampler2D star_col : filter_nearest;
uniform sampler2D star_big : filter_nearest;
uniform int tex_w = 2048;
uniform int count = 0;

uniform vec2 origin = vec2(0.0);
uniform vec2 slide = vec2(0.0);
uniform float zoom = 1.0;
uniform vec2 rot = vec2(1.0, 0.0);
uniform float gas_px = 1.0;
// x0, y0, x1, y1: the chart grown by the slide margin
uniform vec4 cull = vec4(-224.0, -224.0, 1184.0, 764.0);

void vertex() {
	int id = VERTEX_ID / 6;
	ivec2 at = ivec2(id % tex_w, id / tex_w);
	vec2 p = texelFetch(star_pos, at, 0).xy;
	vec2 turned = vec2(p.x * rot.x - p.y * rot.y, p.x * rot.y + p.y * rot.x);
	vec2 q = origin + mul2(turned, zoom);
	vec2 o = HIDE;
	if (id < count && !(q.x < cull.x || q.y < cull.y || q.x > cull.z || q.y > cull.w)) {
		float big = floor(texelFetch(star_big, at, 0).r * 255.0 + 0.5);
		float side = big > 1.5 ? gas_px : (big > 0.5 ? 2.0 : 1.0);
		o = quad_corner(VERTEX_ID, snap(q) + slide, vec2(side));
	}
	VERTEX = o;
	COLOR = texelFetch(star_col, at, 0);
}
