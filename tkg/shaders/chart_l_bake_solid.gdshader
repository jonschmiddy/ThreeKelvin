shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE SOLID LOOK'S TWO FIELDS FOR THE LEGACY CHART (`ChartLegacy._stage_textures`):
// what `chart_solid.gdshaderinc` reads as `u_struct` and `u_noise`, made from
// LEGACY's own bake, so the puffs and the middle's relief follow LEGACY's own arms,
// lanes and gas rather than SIMPLIFIED's. Face-on in the galaxy's own plane over
// -ext..ext gu (a gu is the disc's radius, `big_r` bake pixels), 1024 square,
// rendered once a galaxy, read back and mip-mapped, as SIMPLIFIED's are:
//   mode 0, NOISE: R the gas's clumps (LEGACY's own warped gas noise, `gal_fields`'
//            `w`), B billow tops (its fine billowing, `bill`'s scale); G and A at
//            their middle. Each about 0..1 with its middle near 0.5, with the
//            contrast of SIMPLIFIED's, so the shared thresholds cut the same share.
//   mode 1, STRUCTURE: R the arm ridge (LEGACY's arms' light where the ridge
//            measure says crest), G the dust lane (its baked lanes, cut as the field
//            cuts them), B and A none.

#include "res://shaders/chart_l_galaxy.gdshaderinc"

uniform int mode = 0;
uniform float ext = 1.2;
uniform sampler2D aux_tex : filter_linear, repeat_disable;
uniform sampler2D dust_tex : filter_linear, repeat_disable;
uniform vec2 bake_size = vec2(896.0, 616.0);
uniform vec2 bake_origin = vec2(448.0, 308.0);
uniform float big_r = 261.0;
uniform float eff = 0.38;
uniform float arm_k = 1.0;
uniform float lane_amt = 0.0;
uniform float sd = 0.0;

vec4 sb4(sampler2D tx, vec2 p) {
	vec2 x = p + bake_origin;
	if (x.x < 0.0 || x.y < 0.0 || x.x > bake_size.x - 1.001 || x.y > bake_size.y - 1.001) {
		return vec4(0.0);
	}
	return texture(tx, (x + 0.5) / bake_size);
}

void fragment() {
	// the plane point, gu, and in LEGACY's bake (its pixels, the plane squashed by eff)
	vec2 P = (UV * 2.0 - 1.0) * ext;
	float lx = P.x * big_r, ly = P.y * big_r;
	vec2 pb = vec2(lx, ly * eff);
	if (mode == 0) {
		// the gas's clumps, as the field shapes its arm gas (a warped fbm at 0.016 a
		// bake pixel), and its billows at the dust's billowing scale (0.07)
		float q = g_fbm(vec2(lx * 0.016 + sd, ly * 0.016 - sd), 4.0);
		float w = g_fbm(vec2(lx * 0.016 + 5.2 + q * 1.9, ly * 0.016 + 1.3 + q * 1.9), 5.0);
		float b = g_fbm(vec2(lx * 0.07 + 31.0 + q, ly * 0.07 - sd), 5.0);
		// (a value fbm spreads 0.13 either way of its middle, the kit's simplex fbm in SIMPLIFIED's bake about 0.15: stretched to it)
		COLOR = vec4(clamp(0.5 + (w - 0.5) * 1.1, 0.0, 1.0), 0.5, clamp(0.5 + (b - 0.5) * 1.18, 0.0, 1.0), 0.5);
	} else {
		vec4 aux = sb4(aux_tex, pb);
		float on_arm = (1.0 - arm_k) + arm_k * g_sm(0.95, 1.6, aux.g);
		float ridge = g_sm(0.08, 0.75, aux.r) * on_arm;
		float lane = g_sm(0.02, 0.2, sb4(dust_tex, pb).r * lane_amt);
		COLOR = vec4(ridge, lane, 0.0, 1.0);
	}
}
