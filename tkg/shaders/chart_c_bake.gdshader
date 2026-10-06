shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE SIMPLIFIED CHART'S TWO BAKES (`ChartSky`), face-on fields in the galaxy's own
// plane over -ext..ext gu, rendered ONCE a galaxy, read back and mip-mapped:
//   mode 0, NOISE (1024^2): R star-cloud clumps, G dust filaments that follow
//            the spiral, B billow tops, A star-forming mottling. Every channel
//            about 0..1 with its middle near 0.5, so the place pass can stream
//            it along the arms with a two-phase flow map.
//   mode 1, STRUCTURE (2048^2): R the arm ridge, G the dust lane on the arm's
//            inner edge (and the nuclear spirals), B the lane's core-facing lip,
//            A the star-forming front between them.
// The arm model is the game's own (`MapGen.shape_angle`): arm k of n at plane
// radius r sits at k 2pi/n + spin + (r - bar)/(1 - bar) twist, so the systems
// MapGen lays on the arms sit on the arms drawn here. Ported from the showcase's
// direction C (`C/chart/bake.glsl`), extended to every galaxy kind: up to ten
// arms, chaos breaking the arms into patches, a bar on an armless disc.

#include "res://shaders/chart_kit.gdshaderinc"

uniform int mode = 0;
uniform float ext = 1.2;
uniform float arms = 2.0;
uniform float twist = 8.0;
uniform float bar = 0.0;
uniform float spin = 0.0;
uniform float spread = 1.0;
uniform float chaos = 0.0;

float wrapA(float a) { return mod(a + KIT_PI, KIT_TAU) - KIT_PI; }

vec4 noiseFields(vec2 p) {
	float r = length(p), th = atan(p.y, p.x);
	// R: lumpy star clouds, warped so they read as clouds and not as a texture
	vec2 w = kitWarp2(p * 6.5 + vec2(3.1, 7.7), 0.55, 3);
	float c = kitFbm2(w * 1.35, 6);
	// G: dust filaments along the spiral (psi = th - r twist is constant along
	// an arm): fine across it, slow along it; and spurs at a steeper pitch
	float tw = max(twist, 4.0);
	float psi = th - r * tw;
	float f1 = kitRidge3(vec3(cos(psi) * 6.5, sin(psi) * 6.5, r * 7.0), 4);
	float psi2 = th - r * tw * 0.33;
	float f2 = kitRidge3(vec3(cos(psi2) * 10.0 + 4.0, sin(psi2) * 10.0, r * 9.0 + 3.0), 3);
	float brk = smoothstep(-0.25, 0.35, kitFbm2(p * 9.0 + 2.2, 3));
	float g = max(f1 * (0.35 + 0.65 * brk), f2 * 0.8 * (1.0 - brk * 0.5));
	// B: billow tops, rounded puffs
	vec2 wb = kitWarp2(p * 19.0 + vec2(7.7, 1.9), 0.5, 2);
	float b = kitFbm2(wb, 5);
	// A: where stars are forming, mottled and clumpy
	float a = kitFbm2(kitWarp2(p * 14.0 + vec2(11.3, 4.4), 0.4, 2), 4);
	return clamp(vec4(0.5 + 0.85 * c, g, 0.5 + 0.9 * b, 0.5 + 0.95 * a), 0.0, 1.0);
}

vec4 structure(vec2 p) {
	float r = length(p), th = atan(p.y, p.x);
	if (arms < 0.5) {
		// an armless disc keeps its bar, as a ridge of old light and no lanes
		if (bar < 0.01) {
			return vec4(0.0);
		}
		float d0 = wrapA(th - spin);
		float xb = r * sin(d0) / 0.032;
		float along = r * cos(d0);
		float ridge0 = exp(-1.7 * xb * xb) * (1.0 - smoothstep(bar * 0.8, bar * 1.05, abs(along)));
		return vec4(ridge0, 0.0, 0.0, 0.0);
	}
	// chaos: the arm angle wanders and the arms break into patches, as an
	// irregular's stars do (`_build_stars` scatters each star by chaos)
	float wob = chaos > 0.0 ? chaos * 1.6 * kitFbm2(p * 2.2 + 7.3, 3) : 0.0;
	float barW = bar > 0.001 ? smoothstep(bar * 0.8, bar * 1.2, r) : 1.0;   // 0 inside the bar
	float base = spin + max(r - bar, 0.0) / (1.0 - bar) * twist + wob;
	float w = 0.5 * (0.55 + 0.9 * r) * spread * (1.0 + 1.2 * chaos);
	float ridge = 0.0, lane = 0.0, lip = 0.0, front = 0.0;
	for (int k = 0; k < 10; k++) {
		if (float(k) >= arms) {
			break;
		}
		float a = float(k) * KIT_TAU / arms + base;
		float d = wrapA(th - a);
		float xa = d / w;                                     // across a spiral arm, in half-widths (+ = inner side)
		float xb = r * sin(d) / 0.032 * (abs(d) < 1.5708 ? 1.0 : 12.0);   // across the bar
		float x = mix(xb, xa, barW);
		ridge = max(ridge, exp(-1.7 * (x + 0.10) * (x + 0.10)));
		lane = max(lane, exp(-pow((x - 0.46) / 0.17, 2.0)));
		lip = max(lip, exp(-pow((x - 0.66) / 0.09, 2.0)));
		front = max(front, exp(-pow((x - 0.20) / 0.15, 2.0)));
	}
	if (chaos > 0.0) {
		// patches: whole stretches of arm missing, others bright
		float patch = smoothstep(-0.35, 0.45, kitFbm2(p * 3.4 + 1.9, 3));
		float keep = mix(1.0, 0.25 + 0.95 * patch, clamp(chaos * 2.2, 0.0, 1.0));
		ridge *= keep;
		front *= keep;
		lane *= mix(1.0, keep, 0.7) * (1.0 - 0.6 * clamp(chaos * 2.0, 0.0, 1.0));
	}
	// the lanes fade out where the disc does, and inside the bulge they wind
	// into nuclear spirals
	lane *= smoothstep(0.012, 0.05, r) * (1.0 - smoothstep(0.9, 1.15, r));
	if (r < 0.14) {
		// nuclear dust: flocculent filaments wound tight round the hole, thin
		// enough to vanish at the opening view
		vec2 pr = kitRot(r * 16.0) * p;
		float nf = 0.5 + 0.8 * kitFbm2(kitWarp2(pr * 42.0 + 3.7, 0.8, 2), 4);
		float nuc = smoothstep(0.42, 0.72, nf) * smoothstep(0.005, 0.015, r) * (1.0 - smoothstep(0.07, 0.13, r));
		lane = max(lane, nuc);
	}
	lip *= smoothstep(0.02, 0.06, r);
	// nothing at the bake's edge: a sample past it reads the edge texel, and an
	// arm still lit there smeared into spikes above and below the disc
	float rim = 1.0 - smoothstep(ext * 0.86, ext * 0.97, max(abs(p.x), abs(p.y)));
	return clamp(vec4(ridge, lane, lip, front) * rim, 0.0, 1.0);
}

void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * ext;
	COLOR = mode == 0 ? noiseFields(p) : structure(p);
}
