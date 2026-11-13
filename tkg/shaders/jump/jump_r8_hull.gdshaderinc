// R8 MAELSTROM's hull, read by the warp pass at each tap's point in the disc (maelstrom.py's ship
// in `frame`): the baked stand-in through the ship's pose, lit as the film lit it. Include after
// jump_common, jump_warp and jump_r8.
// Why: docs/why/SeqMaelstrom.md#ship-in-the-twist

uniform sampler2D hull : filter_nearest, repeat_disable;
uniform sampler2D aux : filter_nearest, repeat_disable;
// the films' own seams (red) and their halo (green): JumpWarpField.film_seams
uniform sampler2D seams : filter_nearest, repeat_disable;
uniform sampler2D sdf : filter_nearest, repeat_disable;
uniform vec4 ship = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 ink_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float sdf_pad = 48.0;
uniform float k_ship = -1.0;
uniform float hull_k = 0.0;
// the eye's direction in the sprite's frame
uniform vec2 lxy = vec2(1.0, 0.0);
uniform float seam_on = 0.0;
uniform float seam_u = 0.0;
uniform float seam_ph = 0.0;
uniform float seam_mul = 1.0;
uniform float deep = 0.0;
uniform float glow = 0.0;

const vec3 HOT = vec3(1.0, 0.94, 1.0);
const vec3 VIO = vec3(0.55, 0.36, 1.0);
const vec3 MAG = vec3(0.95, 0.32, 0.80);
const vec3 SEA = vec3(0.30, 0.95, 0.72);

float A(vec2 h) {
	return j_hull_px(hull, h, ship.zw).a > 0.0 ? 1.0 : 0.0;
}

float sd(vec2 h) {
	return j_hull_sdf(sdf, h, ship.zw, sdf_pad, ink_rect);
}

vec3 lit(vec2 h) {
	vec3 c = jw_lin(j_hull_px(hull, h, ship.zw).rgb);
	vec3 c0 = c;
	// the outline facing the eye takes a stepped rim (outward normal: the distance field's slope)
	vec2 n = vec2(sd(h + vec2(1.0, 0.0)) - sd(h - vec2(1.0, 0.0)), sd(h + vec2(0.0, 1.0)) - sd(h - vec2(0.0, 1.0)));
	n /= length(n) + 1e-6;
	float din = texture(aux, (h + 0.5) / ship.zw).g * 32.0;
	float edge = din < 1.2 ? 1.0 : (din < 2.1 ? 0.45 : 0.0);
	float rim = pow(clamp(dot(n, lxy), 0.0, 1.0), 1.5) * edge;
	// the side facing the eye brightens
	float ld = clamp(dot(h - sc, lxy), -150.0, 150.0) / 150.0;
	float Lh = hull_k * (0.55 + 0.45 * ld);
	float Lr = hull_k * rim * 1.6;
	c = c * (1.0 + 1.2 * Lh) + Lh * 0.03 * MAG;
	c += floor(clamp(Lr, 0.0, 2.0) * 3.0) / 3.0 * (0.40 * VIO + 0.25 * HOT + 0.15 * SEA);
	if (seam_on > 0.5) {
		float xs = (50.0 + (h.x - ink_rect.x) * 236.0 / max(ink_rect.z, 1.0)) / 300.0;
		float wave = cos(TAU * (xs * 1.5 - seam_ph));
		float am = (0.15 + 0.85 * seam_u) * (0.3 + 0.7 * pow(clamp(wave, 0.0, 1.0), 3.0)) * seam_mul;
		vec2 sh = texture(seams, (h + 0.5) / ship.zw).rg;
		float seam = sh.r;
		float e = floor(clamp(seam * am, 0.0, 1.5) * 4.0) / 4.0;
		float halo = sh.g;
		float hal = floor(clamp(halo * am, 0.0, 1.2) * 3.0) / 3.0;
		c = c * (1.0 + 1.2 * hal) + hal * 0.05 * VIO;
		c += e * (0.6 * VIO + 0.45 * HOT);
	}
	if (k_ship >= 0.0) {
		// deep in the storm the hull takes its colours, then burns white as it reaches the eye
		float lum = (c0.r + c0.g + c0.b) / 3.0;
		vec3 tint = (lum * 1.1 + 0.004) * MAG * (1.0 + Lh * 0.4);
		c = c * (1.0 - deep) + tint * deep;
		c = c * (1.0 - glow) + (lum * 0.6 + 0.35) * HOT * glow * 2.0;
	}
	return c;
}

