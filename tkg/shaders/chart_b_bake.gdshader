shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE PAINTED CHART'S BAKE: the billow puff table, one texel per cell of a
// 0.016 gu grid in the galaxy's own frame, baked once a galaxy and read back
// (`ChartSky`). The place pass reads it with texelFetch, so a puff costs one
// quadratic a frame. From the showcase's direction B (`B/chart/bake.glsl`).
//   part 0: (offset x, offset y within the cell 0..1, R gu (0 = no puff), centre height gu)
//   part 1: (vertical radius gu, heap mass 0..1, warm share 0..1, heap id / 255)

#include "res://shaders/chart_b_common.gdshaderinc"

uniform int u_part = 0;
uniform vec4 u_puffP;        // cells across, cell size (gu), origin x, origin y (gu)

void fragment() {
	ivec2 c = ivec2(floor(UV * u_puffP.x));
	float cs = u_puffP.y;
	vec3 h = kitHash3(c + ivec2(9127, 3411));
	vec2 off = 0.1 + 0.8 * h.xy;
	vec2 ctr = u_puffP.zw + (vec2(c) + off) * cs;
	float r = length(ctr);
	float A = armAt(ctr);
	float M = massAt(ctr, A, r) * min(u_g1.w, 1.6) * cloudFree(ctr);
	bool on = u_g3.x < 0.5 && u_g1.w >= 0.2 && r > 0.075 && r < 0.88 && M > 0.1 && h.z < M * 2.0;
	float h2 = kitHash1(c + ivec2(77, 13));
	float R = cs * (0.6 + 0.5 * h2) * (0.62 + 0.5 * M);
	float cR = 0.8 * R;
	float deck = 0.003 + 0.036 * M;
	float ch = deck * (0.6 + 0.4 * h2) - 0.25 * R;
	// lit by the core (warm) near it, by the arm's own young stars (cool) further out
	float warm = smoothstep(0.52, 0.24, r + 0.1 * (h2 - 0.5));
	// one id per heap (a coarse cell), so outlines run round a heap and never between its puffs
	ivec2 hc = ivec2(floor(ctr / 0.055));
	float id = float(1 + int(kitHashU2(hc + ivec2(31, 7)) % 250u)) / 255.0;
	COLOR = u_part == 0 ? vec4(off, on ? R : 0.0, ch) : vec4(cR, M, warm, id);
}
