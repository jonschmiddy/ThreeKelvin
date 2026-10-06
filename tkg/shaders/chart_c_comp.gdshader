shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE SIMPLIFIED CHART'S COMPOSITE (`ChartSky`), one fragment a block: the place
// pass's light toned (hue-keeping, burn 2.5) to sRGB, then the galaxy's own
// palette, cut once for the galaxy and never swapped while you move. Each block
// takes its nearest colour; a block is dithered toward its partner only on a
// slow, steady GRADIENT, never on a busy texture (there the texture already
// carries the detail, and dither on top only shimmers as the view moves) and
// never in the dark. The dither is a 4x4 Bayer anchored to the galaxy's centre.
// The showcase's direction C composite (`C/chart/composite.glsl`).

#include "res://shaders/chart_kit.gdshaderinc"

uniform sampler2D place : filter_nearest, repeat_disable;
uniform sampler2D lut : filter_nearest;
uniform sampler2D pal : filter_nearest;
uniform bool quant = true;
uniform vec2 vp_size = vec2(330.0, 220.0);
// this viewport's first block, counted from the galaxy's centre
uniform vec2 block0 = vec2(0.0);
uniform float exposure = 1.2;
uniform float burn = 2.5;
uniform float dith = 1.0;
// how steady a gradient must be to be dithered: its change over six blocks
// (gs_lo) and how much of that is a steady slope rather than texture (coh_lo)
uniform float gs_lo = 0.006;
uniform float coh_lo = 0.5;
// vibrance (the radiant chart's, 0 for the others): dull mid tones lifted in
// OKLab, never the darkest or the hottest, never colours already vivid, so
// light that has passed through gas keeps its colour before the palette
uniform float vib = 0.0;
// THE COLOUR HELD (the zoom's flicker, by stable sampling rather than by fewer
// colours or less detail): this viewport is never cleared, so `prev` is the
// picture drawn last frame. A block keeps the colour it had while its light is
// still nearly as close to that colour as to the one it would now take
// (`hyst`, sRGB), so a gradient or a grain sliding under the blocks as the zoom
// moves no longer flips a block between two neighbouring colours and back.
// `prev_shift`: where this block was last frame (the blocks are anchored to the
// galaxy, so a pan moves them through the viewport). `hyst` 0: nothing held
// (the first frame, after a resize or a new palette).
uniform sampler2D prev : hint_screen_texture, filter_nearest;
uniform vec2 prev_shift = vec2(0.0);
uniform float hyst = 0.0;

vec3 toneAt(ivec2 b) {
	b = clamp(b, ivec2(0), ivec2(vp_size) - 1);
	return kitToSrgb(kitTone(texelFetch(place, b, 0).rgb * exposure, burn));
}

vec3 quantGated(vec3 s, ivec2 d, float allow) {
	if (!quant) {
		return s;
	}
	s = clamp(s, 0.0, 1.0);
	ivec3 q = ivec3(floor(s * 31.0 + 0.5));
	vec4 e = texelFetch(lut, ivec2(q.b * 32 + q.r, q.g), 0);
	vec3 A = texelFetch(pal, ivec2(int(e.r * 255.0 + 0.5), 0), 0).rgb;
	if (e.b < 0.5) {
		return A;
	}
	vec3 B = texelFetch(pal, ivec2(int(e.g * 255.0 + 0.5), 0), 0).rgb;
	vec3 ab = B - A;
	float t = clamp(dot(s - A, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	// a narrower dithered band: within a fifth of either colour the nearest wins
	t = mix(step(0.5, t), clamp((t - 0.5) * 1.6 + 0.5, 0.0, 1.0), allow);
	return (t > kitBayer4(d)) ? B : A;
}

void fragment() {
	ivec2 b = ivec2(floor(UV * vp_size));
	vec3 s = toneAt(b);
	float g = length(toneAt(b + ivec2(1, 0)) - s);
	g = max(g, length(toneAt(b - ivec2(1, 0)) - s));
	g = max(g, length(toneAt(b + ivec2(0, 1)) - s));
	g = max(g, length(toneAt(b - ivec2(0, 1)) - s));
	// a slow gradient changes little a block but steadily: three blocks out too
	float gs = max(length(toneAt(b + ivec2(3, 0)) - toneAt(b - ivec2(3, 0))), length(toneAt(b + ivec2(0, 3)) - toneAt(b - ivec2(0, 3))));
	float coh = smoothstep(coh_lo, coh_lo + 0.3, gs / (6.0 * g + 1e-4));
	float allow = smoothstep(gs_lo, gs_lo * 3.0, gs) * coh;
	if (vib > 0.0) {
		vec3 L = kitOklab(max(kitTone(texelFetch(place, b, 0).rgb * exposure, burn), 0.0));
		float k = 1.0 + vib * smoothstep(0.1, 0.32, L.x) * (1.0 - smoothstep(0.86, 0.97, L.x)) * (1.0 - smoothstep(0.06, 0.16, length(L.yz)));
		L.yz *= k;
		s = kitToSrgb(max(kitOklabToLinear(L), 0.0));
	}
	vec3 raw = s;
	s = quantGated(s, b + ivec2(block0), allow * dith);
	if (hyst > 0.0 && quant) {
		ivec2 pb = b + ivec2(prev_shift);
		if (pb.x >= 0 && pb.y >= 0 && pb.x < int(vp_size.x) && pb.y < int(vp_size.y)) {
			vec3 was = texelFetch(prev, pb, 0).rgb;
			// held only if it is a palette colour this light could take (its nearest
			// or its partner): never the picture drawn before the palette came in
			vec3 rc = clamp(raw, 0.0, 1.0);
			ivec3 q = ivec3(floor(rc * 31.0 + 0.5));
			vec4 e = texelFetch(lut, ivec2(q.b * 32 + q.r, q.g), 0);
			vec3 A = texelFetch(pal, ivec2(int(e.r * 255.0 + 0.5), 0), 0).rgb;
			vec3 B = texelFetch(pal, ivec2(int(e.g * 255.0 + 0.5), 0), 0).rgb;
			bool ok = length(was - A) < 0.004 || length(was - B) < 0.004;
			if (ok && length(was - s) > 1e-3 && length(raw - was) < length(raw - s) + hyst) {
				s = was;
			}
		}
	}
	COLOR = vec4(s, 1.0);
}
