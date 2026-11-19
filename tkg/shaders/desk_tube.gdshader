shader_type canvas_item;
render_mode unshaded;

// THE TUBE (the page's `DESK.tube`, Jon's pick D, "slightly less curve"), at the page's canvas size:
// the glass is barrel-curved to a rounded rim, darker toward it in four steps, and the screen's
// light falls on the bezel round it in six stepped rings, coloured by the picture's mean.
// Drawn over the whole desk; a pixel outside the tube's region is the canvas as it is.
// Why: docs/why/DeskScene.md#the-plan

#include "res://shaders/desk_canvas.gdshaderinc"

uniform sampler2D mean_tex : filter_nearest, repeat_disable;
// the fit (`buildMap`'s scale, from the bake: the widest glass pixel lands on the glass's edge)
uniform float tube_scale = 1.0;
uniform bool tube_on = true;
uniform vec2 canvas = vec2(1920.0, 1080.0);

const float K = 0.028;
const float RIM = 0.985;
const int P = 22;
const float GLOW = 0.16;
const float VIG = 0.12;

vec3 tube_px(ivec2 c) {
	ivec2 g = c - GLASS_C.xy;
	if (!tube_on || g.x < -P || g.y < -P || g.x >= GLASS_C.z + P || g.y >= GLASS_C.w + P) return canvas_px(c);
	float hw = (float(GLASS_C.z) - 1.0) / 2.0;
	float hh = (float(GLASS_C.w) - 1.0) / 2.0;
	if (g.x >= 0 && g.y >= 0 && g.x < GLASS_C.z && g.y < GLASS_C.w) {
		float u = (float(g.x) - hw) / hw;
		float v = (float(g.y) - hh) / hh;
		float r2 = u * u + v * v;
		float u4 = u * u * u * u;
		float v4 = v * v * v * v;
		float se = pow(u4 * u4 * u4 + v4 * v4 * v4, 1.0 / 12.0);
		if (se >= RIM) return vec3(4.0, 6.0, 9.0);
		float f = (1.0 + K * r2) / tube_scale;
		int sx = int(floor(u * f * hw + hw + 0.5));
		int sy = int(floor(v * f * hh + hh + 0.5));
		if (sx < 0 || sx >= GLASS_C.z || sy < 0 || sy >= GLASS_C.w) return vec3(4.0, 6.0, 9.0);
		float edge = floor(clamp((RIM - se) / 0.06, 0.0, 1.0) * 4.0) / 4.0;
		float vig = 1.0 - VIG * clamp(r2 - 0.6, 0.0, 1.0);
		float mul = (0.55 + 0.45 * edge) * vig;
		vec3 s = canvas_px(GLASS_C.xy + ivec2(sx, sy));
		if (mul >= 0.999) return s;
		return floor(s * floor(mul * 256.0 + 0.5) / 256.0);
	}
	int dx = g.x < 0 ? -g.x : (g.x >= GLASS_C.z ? g.x - GLASS_C.z + 1 : 0);
	int dy = g.y < 0 ? -g.y : (g.y >= GLASS_C.w ? g.y - GLASS_C.w + 1 : 0);
	int dd = max(dx, dy);
	vec3 s = canvas_px(c);
	float a = GLOW * (1.0 - (float(dd) - 1.0) / float(P));
	a = floor(max(0.0, a) * 6.0) / 6.0;
	if (dd > P || a <= 0.0) return s;
	a = floor(a * 256.0 + 0.5) / 256.0;
	vec3 mn = floor(texelFetch(mean_tex, ivec2(0), 0).rgb * 255.0 + 0.5) + texelFetch(mean_tex, ivec2(1, 0), 0).rgb;
	return floor(min(vec3(255.0), s * (1.0 + a) + mn * a * 0.6));
}

void fragment() {
	ivec2 c = ivec2(floor(UV * canvas));
	COLOR = vec4(tube_px(c) / 255.0, 1.0);
}
