shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE RADIANT CHART'S FACE-ON DISC (`ChartRadiant`), baked once a galaxy in its
// own frame (it turns with phi, so the bake never needs redoing). Two passes
// into two half-float maps over -u_ext..u_ext galaxy units:
//   pass 0 (discA): R old-star light, G young-star light (blue arms, clusters),
//                   B the H-alpha glow of the arms' fronts, A dust depth
//   pass 1 (discB): R arm gas (billow base), G billow top height (gu),
//                   B blocker height (the horizon map), A core swirl gas
// The knots are not baked: they breathe, so the place pass draws them live.
// From the showcase's direction A (`A/chart/bake_disc.glsl`), every galaxy kind:
// `u_isEll` for the balls, no arms for the armless discs.

#include "res://shaders/chart_r_common.gdshaderinc"

uniform float u_ext = 1.3;
uniform int u_pass = 0;
uniform float u_isEll = 0.0;
// pass 2 (the knot map): each texel the nearest knot in reach, (index + 1) / 255
uniform int u_nkn = 0;
uniform vec4 u_kn[64];

// young star clusters: compact blobs scattered along the young ridge
float clusters(vec2 p) {
	const float CELL = 0.016;
	vec2 q = p / CELL;
	ivec2 c0 = ivec2(floor(q));
	float s = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			ivec2 c = c0 + ivec2(i, j);
			vec3 h = kitHash3(c + ivec2(4242, 977));
			vec2 pos = (vec2(c) + 0.15 + 0.7 * h.xy) * CELL;
			float hw, w;
			float d = armD(pos, hw, w);
			float rr = length(pos);
			float ridge = exp(-pow((d + 0.1) / 0.42, 2.0)) * smoothstep(0.08, 0.22, rr) * (1.0 - smoothstep(0.85, 1.1, rr));
			if (h.z > ridge * 0.55) {
				continue;
			}
			vec3 g = kitHash3(c + ivec2(77, 4242));
			float rad = 0.0022 + 0.0042 * g.x * g.x;
			vec2 dd = p - pos;
			s += (0.45 + 1.1 * g.y * g.y) * exp(-dot(dd, dd) / (rad * rad));
		}
	}
	return s;
}

vec4 knotMap(vec2 p) {
	// THE KNOT MAP: the place pass reads one texel and draws that knot,
	// instead of looping over every knot for every block
	float best = 1e9;
	int bi = -1;
	for (int i = 0; i < 64; i++) {
		if (i >= u_nkn) {
			break;
		}
		vec4 kn = u_kn[i];
		float d = length(p - kn.xy) / max(kn.z, 0.004);
		if (d < best && length(p - kn.xy) < max(kn.z * 6.0, 0.01) + 0.008) {
			best = d;
			bi = i;
		}
	}
	return vec4(float(bi + 1) / 255.0, 0.0, 0.0, 1.0);
}

vec4 discAt(vec2 UVp) {
	// (row 0 is -u_ext: the place pass reads it with kitMapUV as it is)
	vec2 p = (UVp * 2.0 - 1.0) * u_ext;
	float r = length(p), th = atan(p.y, p.x);
	float hw, w;
	float d = armD(p, hw, w);
	bool spiral = u_arms > 0.5;

	// ---- arm profiles (d in half-widths; positive = concave inner side)
	float armB = spiral ? exp(-d * d * 0.55) : 0.0;
	float young = spiral ? exp(-pow((d + 0.12) / 0.40, 2.0)) : 0.0;
	float lane = spiral ? exp(-pow((d - 0.42) / 0.13, 2.0)) : 0.0;
	float feat = 0.0;
	if (spiral) {
		float fe = kitRidge3(armCoord(r, w + r * 9.0, 22.0, 9.0) + vec3(4.0 + u_seed, 1.0, 2.0), 3);
		feat = smoothstep(0.55, 0.9, fe) * smoothstep(1.4, 0.4, abs(d + 0.4)) * 0.5;
	}
	// an irregular's arms break into stretches
	float brk = 1.0 - u_chaos * 0.8 * smoothstep(-0.2, 0.4, kitSnoise2(p * 3.4 + 1.9));

	// ---- radial profiles: the disc thins very gradually into the halo (no edge)
	float trunc = 1.0 - smoothstep(0.8, 1.25, r);
	float oldR = exp(-r / u_rd) * trunc + 0.05 * exp(-r / 0.6) * (1.0 - smoothstep(0.85, 1.15, r));
	float youngR = smoothstep(0.04, 0.2, r) * exp(-r / 0.6) * (1.0 - smoothstep(0.92, 1.35, r));

	float cl = kitFbm3(armCoord(r, w, 26.0, 3.2) + vec3(u_seed, 0.0, 0.0), 5);
	float clumps = 0.18 + 1.7 * pow(clamp(0.5 + 0.95 * cl, 0.0, 1.0), 2.4);
	float iso = kitFbm3(vec3(p * 38.0, 3.1 + u_seed), 4);

	if (u_pass == 0) {
		float sInner = spiral ? exp(-d * d * 1.4) * (1.0 - smoothstep(0.1, 0.3, r)) * smoothstep(0.015, 0.05, r) : 0.0;
		float S_old = oldR * (0.32 + 0.85 * armB * u_armStr) * (0.88 + 0.24 * iso) + sInner * 0.9;
		if (spiral && u_bar > 0.01) {
			S_old += 1.3 * exp(-d * d * 0.3) * (1.0 - smoothstep(u_bar * 0.75, u_bar * 1.2, r)) * smoothstep(0.012, 0.04, r);
		}
		if (u_isEll > 0.5 || !spiral) {
			S_old = oldR * (0.94 + 0.12 * iso);
		}
		float S_young = youngR * young * clumps * u_armStr * 0.75 * brk;
		S_young += youngR * clusters(p) * u_armStr * 0.9 * brk;
		// the arms' fronts: a faint H-alpha glow along the young ridge (the knots are live)
		float ha = youngR * young * smoothstep(0.62, 0.9, cl * 0.5 + 0.5) * u_armStr * 0.35 * brk;
		float fil = kitRidge3(armCoord(r, w, 60.0, 11.0) + vec3(11.0 + u_seed, 3.0, 5.0), 4);
		float laneD = lane * (0.3 + 1.0 * fil) + feat * (0.4 + 0.8 * fil);
		laneD *= smoothstep(0.04, 0.12, r) * (1.0 - smoothstep(0.8, 1.15, r)) * brk;
		float diffuse = 0.05 * armB * youngR / 0.6;
		float ls = log(max(r, 1e-3));
		float nuc = 0.0;
		if (spiral) {
			float sp = sin(2.0 * (th - u_spin) - ls * 4.2 + 1.2 * kitFbm2(p * 30.0, 3));
			nuc = smoothstep(0.5, 0.95, sp) * smoothstep(0.02, 0.045, r) * (1.0 - smoothstep(0.08, 0.17, r)) * 0.7;
		}
		float tau = u_laneStr * (0.95 * laneD + diffuse) + nuc * min(u_laneStr, 1.0);
		tau = min(tau, 0.95);
		return vec4(S_old, S_young, ha, tau);
	} else {
		float G = u_gas * youngR * (0.25 * armB + 0.75 * young * (0.4 + 0.6 * clumps)) * 1.6 * brk;
		float rg = smoothstep(0.15, 0.85, 0.5 + 0.55 * kitFbm2(p * 6.0 + vec2(3.7 + u_seed, 1.3), 4));
		float Hc = (0.008 + 0.075 * pow(rg, 1.7)) * smoothstep(0.06, 0.45, G);
		float blocker = Hc * smoothstep(0.25, 0.7, G);
		float ls = log(max(r, 1e-3));
		float sw = 0.5 + 0.5 * sin(3.0 * th - ls * 5.0 + 1.5 * kitFbm2(p * 24.0, 3));
		float core = sw * sw * sw * smoothstep(0.006, 0.02, r) * (1.0 - smoothstep(0.045, 0.12, r)) * (spiral ? 1.0 : 0.35);
		return vec4(G, Hc, blocker, core);
	}
	return vec4(0.0);
}

void fragment() {
	COLOR = u_pass == 2 ? knotMap((UV * 2.0 - 1.0) * u_ext) : discAt(UV);
}
