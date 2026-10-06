shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE PAINTED CHART'S PAINT PASS (`ChartSky`, style PAINTED), one fragment a
// block: the G-buffer becomes palette colours, the way a pixel artist paints
// (the showcase's direction B, `B/chart/paint.glsl`).
//  - bands: each block's band (held by the band memory, `chart_b_state`) picks
//    one step of its material's curated ramp
//  - transitions: a block on the dark side of a band edge becomes a 1-block
//    50% checker of the two steps (never between two dark steps)
//  - where two lights meet, a 1-block checker seam of the neighbour's colour
//  - outlines on the shadow side of a big shape's silhouette, a rim of light
//    on its lit side
//  - cleanup: a lone block that differs from four agreeing neighbours takes
//    their value, and in a soft mass of gas one that three outvote takes theirs
// The palette is the curated one, the same table as the painted sector map.

uniform sampler2D gbuf : filter_nearest;
uniform sampler2D state : filter_nearest;
uniform sampler2D pal : filter_nearest;
uniform int u_idx[96];
uniform int u_mstart[24];
uniform int u_mlen[24];
uniform int u_rim[24];
uniform int u_out[24];
uniform int u_trans[24];
uniform vec2 vp_size = vec2(330.0, 220.0);
uniform vec2 block0 = vec2(0.0);

struct GB { int m; int band; int sid; int ang; bool edge; };

// a modulo that wraps negative numbers (GLSL leaves % of a negative undefined)
ivec2 pmod(ivec2 a, ivec2 s) {
	return a - s * ivec2(floor(vec2(a) / vec2(s)));
}

GB fetchG(ivec2 b) {
	ivec2 size = ivec2(vp_size);
	b = clamp(b, ivec2(0), size - 1);
	vec4 g = texelFetch(gbuf, b, 0);
	GB r;
	r.m = clamp(int(g.r * 255.0 + 0.5), 0, 23);
	int n = max(u_mlen[r.m], 1);
	r.band = clamp(int(floor(g.g * float(n))), 0, n - 1);
	// the band the memory holds, where it remembers this material here
	ivec2 slot = pmod(b + ivec2(block0), size);
	vec4 s = texelFetch(state, slot, 0);
	if (int(s.r * 255.0 + 0.5) == r.m) {
		r.band = clamp(int(s.g * 15.0 + 0.5), 0, n - 1);
	}
	r.sid = int(g.b * 255.0 + 0.5);
	int a = int(g.a * 255.0 + 0.5);
	r.ang = a >> 1;
	r.edge = (a & 1) == 1;
	return r;
}
bool isStar(int m) { return m >= 13 && m <= 16; }
// the lightning bolt: a stepped line of single blocks, its diagonal steps
// touching only at their corners -- the cleanup must never take one
bool isBolt(int m) { return m == 18; }
bool seamMat(int m) { return m == 1 || m == 2 || m == 3 || m == 5 || m == 6 || m == 7 || m == 8 || m == 17; }
bool same(GB a, GB b) { return a.m == b.m && a.band == b.band; }
// the soft masses: the sky, the arms' gas, the bulge, the billows, a
// reflection cloud's haze, the halo and an elliptical's ball (not the thin
// lines -- a remnant's strands, a ring's rim -- nor the sparkles)
bool massMat(int m) { return m == 0 || m == 1 || m == 3 || m == 5 || m == 8 || m == 10 || m == 17; }
// the billows (cool heaps are the arm's material, warm ones their own)
bool heapMat(int m) { return m == 1 || m == 5; }

void fragment() {
	ivec2 b = ivec2(floor(UV * vp_size));
	GB c = fetchG(b);
	GB n0 = fetchG(b + ivec2(1, 0)), n1 = fetchG(b + ivec2(-1, 0)), n2 = fetchG(b + ivec2(0, 1)), n3 = fetchG(b + ivec2(0, -1));
	if (!isStar(c.m) && !isBolt(c.m) && same(n0, n1) && same(n1, n2) && same(n2, n3) && !same(c, n0) && !isStar(n0.m)) {
		c.m = n0.m;
		c.band = n0.band;
		c.sid = n0.sid;
		c.edge = false;
	} else if (massMat(c.m) && c.sid == 0) {
		// SOFT CONNECTED MASSES (Jon, of the painted clouds: "harsh and
		// disconnected" against B's "fluffy and full and connected"): in a mass
		// of gas a block that three of its four neighbours outvote takes their
		// band -- a one-block spur goes, a one-block notch fills, a lone island
		// joins its mass -- so band edges run as rounded lobes and the steps of a
		// diagonal stay whole stairs
		for (int k = 0; k < 4; k++) {
			GB a = k == 0 ? n0 : (k == 1 ? n1 : (k == 2 ? n2 : n3));
			int votes = int(same(a, n0)) + int(same(a, n1)) + int(same(a, n2)) + int(same(a, n3));
			if (votes >= 3 && !same(c, a) && massMat(a.m) && a.sid == 0) {
				c.m = a.m;
				c.band = a.band;
				c.edge = false;
				break;
			}
		}
	}
	int base = u_mstart[c.m];
	int n = u_mlen[c.m];
	int idx = u_idx[base + c.band];
	ivec2 di = b + ivec2(block0);
	bool par = ((di.x + di.y) & 1) == 0;
	if (u_trans[c.m] == 1 && c.band < n - 1) {
		int up = c.band;
		if (n0.m == c.m) {
			up = max(up, n0.band);
		}
		if (n1.m == c.m) {
			up = max(up, n1.band);
		}
		if (n2.m == c.m) {
			up = max(up, n2.band);
		}
		if (n3.m == c.m) {
			up = max(up, n3.band);
		}
		bool darkPair = (c.m == 0) || (c.band == 0 && (c.m == 1 || c.m == 4 || c.m == 9 || c.m == 11 || c.m == 5 || c.m == 10 || c.m == 17));
		if (up > c.band && !darkPair && par) {
			idx = u_idx[base + c.band + 1];
		}
	}
	if (seamMat(c.m) && par && c.sid == 0) {
		for (int k = 0; k < 4; k++) {
			GB nb = k == 0 ? n0 : (k == 1 ? n1 : (k == 2 ? n2 : n3));
			if (nb.m != c.m && seamMat(nb.m) && c.m < nb.m && nb.sid == 0) {
				idx = u_idx[u_mstart[nb.m] + nb.band];
				break;
			}
		}
	}
	if (c.sid != 0 && c.edge) {
		// (only against what is not a shape at all: between two heaps of one arm
		// the outline and its rim ran round every heap, a web of black and white
		// lines the showcase's pictures never show)
		float a = float(c.ang) / 32.0 * 6.2831853;
		vec2 L = vec2(cos(a), sin(a));
		float dLit = -1e9, dShade = 1e9;
		if (n0.sid == 0 || (n0.sid != c.sid && n0.m != c.m)) {
			float d = dot(vec2(1.0, 0.0), L);
			dLit = max(dLit, d);
			dShade = min(dShade, d);
		}
		if (n1.sid == 0 || (n1.sid != c.sid && n1.m != c.m)) {
			float d = dot(vec2(-1.0, 0.0), L);
			dLit = max(dLit, d);
			dShade = min(dShade, d);
		}
		if (n2.sid == 0 || (n2.sid != c.sid && n2.m != c.m)) {
			float d = dot(vec2(0.0, 1.0), L);
			dLit = max(dLit, d);
			dShade = min(dShade, d);
		}
		if (n3.sid == 0 || (n3.sid != c.sid && n3.m != c.m)) {
			float d = dot(vec2(0.0, -1.0), L);
			dLit = max(dLit, d);
			dShade = min(dShade, d);
		}
		// A HEAP OF BILLOWS is gas: no ink line round it and no rim of light
		// along it (drawn round every heap they cut the clouds into stickers, the
		// rim a dotted white seam); its tops are lit by its own bands. The
		// pillars, lanes and dark clouds keep both
		if (!heapMat(c.m)) {
			if (dShade < -0.38 && u_out[c.m] >= 0) {
				idx = u_out[c.m];
			} else if (dLit > 0.38 && u_rim[c.m] >= 0) {
				idx = u_rim[c.m];
			}
		}
	}
	COLOR = vec4(texelFetch(pal, ivec2(idx, 0), 0).rgb, 1.0);
}
