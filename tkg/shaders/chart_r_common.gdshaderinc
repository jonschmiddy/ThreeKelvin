// THE RADIANT STAR CHART, shared by its bakes and its place pass (`ChartRadiant`,
// style RADIANT): direction A of the Oct 5 showcase, "Light through gas"
// (`showcase/A/chart/common.glsl`). The galaxy's arm model, noise helpers and
// the baked periodic noise volume. Galaxy frame: plane x, y in galaxy units
// (face-on), h = height above the plane in galaxy units.

#include "res://shaders/chart_kit.gdshaderinc"

uniform float u_arms = 2.0;
uniform float u_twist = 8.0;
uniform float u_bar = 0.0;
uniform float u_spread = 1.0;
uniform float u_spin = 0.0;
uniform float u_gas = 1.0;
uniform float u_armStr = 1.0;
uniform float u_laneStr = 1.0;
uniform float u_rd = 0.25;
uniform float u_seed = 1.3;
uniform float u_chaos = 0.0;

const float KIT_RAY_DY = 2.43418;    // along a view ray, plane y grows this much per unit of h
const float R_TAU = 6.2831853;
const float R_PI = 3.14159265;

vec3 kitHash3v3(ivec3 p) {
	uint h = kitHashU3(p);
	uint h2 = kitHashU(h);
	return vec3(kitU2F(h), kitU2F(h2), kitU2F(kitHashU(h2)));
}
vec3 kitQuintic3(vec3 f) { return f * f * f * (f * (f * 6.0 - 15.0) + 10.0); }
float kitRidge2(vec2 p, int oct) {
	float s = 0.0, a = 0.5, n = 0.0, w = 1.0;
	for (int i = 0; i < 10; i++) {
		if (i >= oct) {
			break;
		}
		float r = 1.0 - abs(kitSnoise2(p));
		r *= r;
		s += a * r * w;
		w = clamp(r * 1.6, 0.0, 1.0);
		n += a;
		p = KIT_R2 * p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return s / n;
}
vec2 kitMapUV(vec2 p, float extent) { return (p + extent) / (2.0 * extent); }
float wrapPi(float a) { return a - R_TAU * floor((a + R_PI) / R_TAU); }

// The game's arm model (`MapGen.shape_angle`): ridge angle k 2pi/n + spin +
// (r < bar ? 0 : (r - bar)/(1 - bar) twist); half-width 0.5 (0.55 + 0.9 r)
// spread (x0.22 inside the bar). Returns the signed offset from the nearest
// ridge in half-widths (positive = the arm's concave, inner side), the
// half-width and w, the co-spiral angle (constant along an arm). An irregular's
// ridge wanders (chaos), as the game scatters its systems.
float armD(vec2 p, out float hw, out float w) {
	float r = length(p), th = atan(p.y, p.x);
	th += u_chaos * 1.6 * kitSnoise2(p * 2.2 + 7.3);
	float inBar = r < u_bar ? 1.0 : 0.0;
	hw = 0.5 * (0.55 + 0.9 * r) * u_spread * mix(1.0, 0.22, inBar) * (1.0 + 1.2 * u_chaos);
	float wind = inBar > 0.5 ? 0.0 : (r - u_bar) / max(1.0 - u_bar, 1e-3) * u_twist;
	w = th - wind;
	if (u_arms < 0.5) {
		return 99.0;
	}
	float best = 1e9;
	for (int k = 0; k < 6; k++) {
		if (float(k) >= u_arms) {
			break;
		}
		float d = wrapPi(th - (float(k) * R_TAU / u_arms + u_spin + wind));
		if (abs(d) < abs(best)) {
			best = d;
		}
	}
	return best / max(hw, 1e-3);
}

// smooth noise in arm coordinates: r along the arm, w (on a circle, so it wraps) across it
vec3 armCoord(float r, float w, float fr, float fw) { return vec3(r * fr, cos(w) * fw, sin(w) * fw); }

// ---- the baked noise volume (`chart_r_bake_noise`): periodic 3D noise, 64^3
// voxels a period, stored as 64 slices of 66x66 (a one-voxel wrap border, so
// bilinear filtering tiles seamlessly) in an 8x8 grid, 528x528. R low fbm, G
// high fbm, B ridged (thin filaments), A a second low fbm (for warps). Every
// lookup is two bilinear fetches, so the march never evaluates noise maths.
uniform sampler2D u_noise : filter_linear, repeat_disable;
vec4 nzSlice(float z, vec2 xy) {
	vec2 t = vec2(mod(z, 8.0), floor(z * 0.125 + 1e-3));
	return texture(u_noise, (t * 66.0 + 1.0 + xy * 64.0) / 528.0);
}
vec4 nz(vec3 p) {
	vec3 f = fract(p);
	float z = f.z * 64.0 - 0.5;
	float z0 = floor(z), fz = z - z0;
	float za = z0 < 0.0 ? 63.0 : z0;
	float zb = z0 + 1.0 > 63.5 ? 0.0 : z0 + 1.0;
	return mix(nzSlice(za, f.xy), nzSlice(zb, f.xy), fz);
}
