shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE BANNERS' CLOTH, ONE PASS OF ONE STEP (`YardCloth`, docs/why/YardBanner.md#gpu). The state is this
// viewport, never cleared, copied to the screen texture before every pass. mode 0 integrates (the page's
// forces, Verlet with its damping) and swings the rod by the cloth's moment; mode 1 relaxes every constraint
// at once (Jacobi, OMEGA x the sum of its constraints' corrections); mode 2 relaxes, then holds each node
// within its tether of the rod and in front of the wall; mode 3, first each frame, puts the bake in where the
// state is not yet written (alpha not 165), so the first step integrates from it.

#include "res://shaders/yard_cloth.gdshaderinc"

uniform sampler2D prev : hint_screen_texture, filter_nearest;
uniform sampler2D hung : filter_nearest;
uniform int mode = 0;
uniform float omega = 0.55;
// per banner: (lean, twist, breeze in z, fold), (fold phase, push, push x, push y), (pointer x, y, bx, -)
uniform vec4 fa[7];
uniform vec4 fb[7];
uniform vec4 fc[7];
// the two fold waves' phases this step
uniform vec2 waves;

const float G = 560.0;
const float DAMP = 0.996;
const ivec2 OFF[12] = ivec2[12](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1), ivec2(1, 1), ivec2(-1, -1),
	ivec2(1, -1), ivec2(-1, 1), ivec2(2, 0), ivec2(-2, 0), ivec2(0, 2), ivec2(0, -2));
const float KB[12] = float[12](1.0, 1.0, 1.0, 1.0, -0.06, -0.06, -0.06, -0.06, 0.22, 0.22, 0.22, 0.22);

// the state's node and rod, read straight from the screen texture (a screen sampler cannot be passed on)
float rodv(int b) {
	return tk_dec(texelFetch(prev, ivec2(0, NY * b), 0));
}

vec3 node(int i, int j, int b, float rod) {
	if (j == 0) {
		return vec3(tk_u(i) + rod, 0.0, 0.0);
	}
	int y = j + NY * b;
	return vec3(tk_dec(texelFetch(prev, ivec2(i, y), 0)), tk_dec(texelFetch(prev, ivec2(i + NX, y), 0)),
		tk_dec(texelFetch(prev, ivec2(i + 2 * NX, y), 0)));
}

bool strand(int i, int j) {
	return i == 6 && j >= 23;
}

float slack(float v) {
	return 1.0 + 0.035 * tk_sstep(38.0, 75.0, v);
}

// a shear constraint stiffens up the head, so the name and the mark stay square
float stiff(float k, float vm) {
	if (k < 0.0) {
		k = -k * (1.0 + 9.0 * (1.0 - tk_sstep(24.0, 62.0, vm)));
	}
	return min(1.0, k);
}

// the pointer's shove on a node: x, y and z
vec3 push(int b, vec3 p) {
	vec4 B = fb[b];
	vec4 C = fc[b];
	vec3 a = vec3(0.0);
	if (B.y > 0.0) {
		float dx = C.z + p.x - C.x;
		float dy = CT + p.y - C.y;
		float d2 = dx * dx + dy * dy;
		if (d2 < 324.0) {
			float q = 1.0 - d2 / 324.0;
			float w = q * q;
			float d = sqrt(d2) + 0.5;
			a = vec3(w * (420.0 * B.z + 40.0 * B.y * dx / d), w * (90.0 * B.w + 15.0 * B.y * dy / d), -300.0 * w * B.y);
		}
	}
	return a;
}

vec3 accel(int b, vec3 p, float u, float v) {
	vec4 A = fa[b];
	float ph = fb[b].x;
	float wf = 0.25 + 0.75 * tk_sstep(30.0, 95.0, v);
	float wt = tk_sstep(35.0, 95.0, v);
	float az = A.w * wf * (sin(TAU / 26.0 * u - waves.x + ph + v * 0.012) + 0.65 * sin(TAU / 17.0 * u + waves.y + ph * 1.7 - v * 0.016))
		+ A.z * wf + A.y * wt * (u - CW / 2.0) / (CW / 2.0);
	return vec3(A.x, G, az) + push(b, p);
}

// the rod swings a little on its chains with the cloth's weight (its moment after this step's integration)
float rod_step(int b) {
	float rod = rodv(b);
	float mx = 0.0;
	for (int j = 1; j < NY; j++) {
		for (int i = 0; i < NX; i++) {
			int y = j + NY * b;
			float x = tk_dec(texelFetch(prev, ivec2(i, y), 0));
			float py = tk_dec(texelFetch(prev, ivec2(i + NX, y), 0));
			float ox = tk_dec(texelFetch(prev, ivec2(i + 3 * NX, y), 0));
			float ax = fa[b].x + push(b, vec3(x, py, 0.0)).x;
			mx += (x + (x - ox) * DAMP + ax * HS * HS - tk_u(i) - rod) * tk_v(j);
		}
	}
	float target = clamp(mx / (float(NX * NY) * CH * 0.5), -1.6, 1.6);
	return rod + (target - rod) * 0.02;
}

vec3 relax(int i, int j, int b, float rod) {
	vec3 P = node(i, j, b, rod);
	vec3 D = vec3(0.0);
	float ua = tk_u(i);
	float va = tk_v(j);
	for (int c = 0; c < 13; c++) {
		int i2 = i;
		int j2 = j;
		float k = -0.06;
		if (c < 12) {
			i2 = i + OFF[c].x;
			j2 = j + OFF[c].y;
			k = KB[c];
			if (i2 < 0 || i2 >= NX || j2 < 0 || j2 >= NY) {
				continue;
			}
			// the forked foot's two flaps hang free of each other, and the centre strand hangs alone
			if (min(j, j2) >= 23 && ((i < 6 && i2 > 6) || (i > 6 && i2 < 6))) {
				continue;
			}
			if (strand(i, j) != strand(i2, j2) && i != i2) {
				continue;
			}
		} else {
			// the page's grid wraps its shear at the right edge: each row's two edges are tied across
			if (i != 0 && i != NX - 1) {
				continue;
			}
			i2 = NX - 1 - i;
		}
		vec3 Q = node(i2, j2, b, rod);
		float vb = tk_v(j2);
		float vm = (va + vb) * 0.5;
		float r = length(vec2((tk_u(i2) - ua) * slack(vm), vb - va));
		vec3 d = Q - P;
		float len = length(d);
		if (len == 0.0) {
			len = 1e-6;
		}
		D += d * ((len - r) / len * stiff(k, vm) / (j2 == 0 ? 1.0 : 2.0));
	}
	return P + omega * D;
}

// one texel of the integration step
vec4 integrate(ivec2 p) {
	int i = p.x % NX;
	int k = p.x / NX;
	int j = p.y % NY;
	int b = p.y / NY;
	if (j == 0) {
		return (i == 0 && k == 0) ? tk_enc(rod_step(b)) : texelFetch(prev, p, 0);
	}
	int y = j + NY * b;
	vec3 P = node(i, j, b, 0.0);
	vec3 O = vec3(tk_dec(texelFetch(prev, ivec2(i + 3 * NX, y), 0)), tk_dec(texelFetch(prev, ivec2(i + 4 * NX, y), 0)),
		tk_dec(texelFetch(prev, ivec2(i + 5 * NX, y), 0)));
	vec3 N = P + (P - O) * DAMP + accel(b, P, tk_u(i), tk_v(j)) * (HS * HS);
	return tk_enc(k < 3 ? N[k] : P[k - 3]);
}

void fragment() {
	ivec2 p = ivec2(FRAGCOORD.xy);
	vec4 me = texelFetch(prev, p, 0);
	bool fresh = floor(me.a * 255.0 + 0.5) != 165.0;
	if (mode == 3 || fresh) {
		COLOR = fresh ? texelFetch(hung, p, 0) : me;
	} else if (mode == 0) {
		COLOR = integrate(p);
	} else {
		int i = p.x % NX;
		int k = p.x / NX;
		int j = p.y % NY;
		int b = p.y / NY;
		COLOR = me;
		if (j > 0 && k < 3) {
			float rod = rodv(b);
			vec3 P = relax(i, j, b, rod);
			if (mode == 2) {
				// no stretch from the rod down (the long-range tether), and the wall behind
				vec3 top = vec3(tk_u(i) + rod, 0.0, 0.0);
				vec3 d = P - top;
				float len = length(d);
				float lim = tk_v(j) * 1.004;
				if (len > lim) {
					P = top + d * (lim / len);
				}
				P.z = max(P.z, -8.0 + 0.6);
			}
			COLOR = tk_enc(P[k]);
		}
	}
}
