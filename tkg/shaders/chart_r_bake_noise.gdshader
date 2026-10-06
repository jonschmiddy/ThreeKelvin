shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE RADIANT CHART'S NOISE VOLUME (`ChartRadiant`), baked once a session: a
// periodic 3D gradient noise on an integer lattice taken modulo the period, so
// the volume tiles in x, y and z; 64 slices of 66x66 texels (64 voxels and a
// one-voxel wrap border) in an 8x8 grid, 528x528 (`chart_r_common`'s nz()).
// From the showcase's direction A (`A/chart/bake_noise.glsl`).

#include "res://shaders/chart_r_common.gdshaderinc"

vec3 pgrad(ivec3 c, int P, int s) {
	c = ((c % P) + P) % P;
	return normalize(kitHash3v3(c + ivec3(s * 131 + 7, s * 71 + 3, s * 29 + 11)) * 2.0 - 1.0 + 1e-4);
}
float pgn(vec3 p, int P, int s) {
	vec3 i = floor(p), f = p - i, u = kitQuintic3(f);
	ivec3 c = ivec3(i);
	float n000 = dot(pgrad(c, P, s), f);
	float n100 = dot(pgrad(c + ivec3(1, 0, 0), P, s), f - vec3(1, 0, 0));
	float n010 = dot(pgrad(c + ivec3(0, 1, 0), P, s), f - vec3(0, 1, 0));
	float n110 = dot(pgrad(c + ivec3(1, 1, 0), P, s), f - vec3(1, 1, 0));
	float n001 = dot(pgrad(c + ivec3(0, 0, 1), P, s), f - vec3(0, 0, 1));
	float n101 = dot(pgrad(c + ivec3(1, 0, 1), P, s), f - vec3(1, 0, 1));
	float n011 = dot(pgrad(c + ivec3(0, 1, 1), P, s), f - vec3(0, 1, 1));
	float n111 = dot(pgrad(c + ivec3(1, 1, 1), P, s), f - vec3(1, 1, 1));
	return 1.1547 * mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y), mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
}
// octaves o0..o1-1 of a base-cell fbm (cells a period = base << octave)
float pfbm(vec3 p, int base, int o0, int o1, int s) {
	float sum = 0.0, amp = 1.0, nrm = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= o1) {
			break;
		}
		if (i >= o0) {
			int f = base << i;
			sum += amp * pgn(p * float(f), f, s + i * 17);
			nrm += amp;
		}
		amp *= 0.5;
	}
	return sum / max(nrm, 1e-4);
}
float pridge(vec3 p, int base, int oct, int s) {
	float sum = 0.0, amp = 0.5, nrm = 0.0, w = 1.0;
	for (int i = 0; i < 6; i++) {
		if (i >= oct) {
			break;
		}
		int f = base << i;
		float r = 1.0 - abs(pgn(p * float(f), f, s + i * 17));
		r *= r;
		sum += amp * r * w;
		w = clamp(r * 1.6, 0.0, 1.0);
		nrm += amp;
		amp *= 0.5;
	}
	return sum / max(nrm, 1e-4);
}

void fragment() {
	vec2 fc = floor(UV * 528.0);
	vec2 tile = floor(fc / 66.0);
	vec2 local = fc - tile * 66.0;
	float z = tile.y * 8.0 + tile.x;
	vec3 vox = vec3(mod(local - 1.0 + 64.0, 64.0), z);
	vec3 p = (vox + 0.5) / 64.0;
	COLOR = vec4(pfbm(p, 3, 0, 2, 1) * 1.7, pfbm(p, 3, 2, 4, 2) * 1.9, pridge(p, 3, 3, 3), pfbm(p, 3, 0, 2, 4) * 1.7);
}
