shader_type canvas_item;
render_mode unshaded, blend_add;

// R2's hypercube and motes as light, one quad a sample, placed by VERTEX_ID (`SeqFourth`):
// its 32 edges stepped a pixel at a time with their energy beads, its 16 corner glints, and
// after the bang the 120 motes (4D spheres crossing our space), summed into a light buffer as
// r2.py's `draw_tesseract` deposited them. `target` 0 is the hot lines (`core`), 1 the light
// that glows (`src`, at any cell size), 2 the cells' faint panes (`faces`, their own mesh).
// Why: docs/why/SeqFourth.md#hypercube

#include "res://shaders/jump/jump_r2.gdshaderinc"

uniform int target = 0;
uniform float gain_k = 1.0;
uniform float cell = 1.0;
uniform vec2 origin = vec2(0.0);
uniform int maxe = 800;
// the 16 corners on screen (x, y), along W, and in depth (< 0: behind the hull)
uniform vec4 vx[16];
uniform vec4 ext = vec4(0.0);
uniform float gain = 0.0;
uniform float beads = 0.0;
uniform float bead_ph = 0.0;
uniform float cube_on = 0.0;
uniform float faces_on = 0.0;
// the motes: on, time since the bang, the axis they fly from, and their scale
uniform vec4 mote = vec4(0.0);
uniform vec4 mo_a[120];
uniform vec4 mo_b[120];
uniform float mo_k = 1.0;

const int EI[32] = int[32](0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4, 5, 5, 6, 6, 7, 8, 8, 8, 9, 9, 10, 10, 11, 12, 12, 13, 14);
const int EJ[32] = int[32](1, 2, 4, 8, 3, 5, 9, 3, 6, 10, 7, 11, 5, 6, 12, 7, 13, 7, 14, 15, 9, 10, 12, 11, 13, 11, 14, 15, 13, 14, 15, 15);
const int EAX[32] = int[32](0, 1, 2, 3, 1, 2, 3, 0, 2, 3, 2, 3, 0, 1, 3, 1, 3, 0, 3, 3, 0, 1, 2, 1, 2, 0, 2, 2, 0, 1, 1, 0);
const vec2 CORNER[6] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(1.0, 1.0),
	vec2(0.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 1.0));

// what one quad draws: its colours (first pixel, second), and its kind and size
varying flat vec3 v_c0;
varying flat vec3 v_c1;
varying flat vec4 v_k;
varying vec2 v_loc;

float ext_w(float w) {
	return w / max(ext.w, 1e-3) * min(1.0, ext.w * 1.4);
}

void edge(int e, int i, out vec2 at, out vec2 size, out vec3 c0, out vec3 c1) {
	at = vec2(-1e5);
	size = vec2(1.0);
	c0 = vec3(0.0);
	c1 = vec3(0.0);
	vec4 a = vx[EI[e]];
	vec4 b = vx[EJ[e]];
	int n = int(max(abs(b.x - a.x), abs(b.y - a.y))) + 1;
	if (i >= n) {
		return;
	}
	float wgt = 1.0;
	for (int o = 0; o < 4; o++) {
		if (o != EAX[e]) {
			wgt *= 0.5 + 0.5 * min(1.0, ext[o] * 3.0);
		}
	}
	float u = n > 1 ? float(i) / float(n - 1) : 0.0;
	vec2 p = a.xy + (b.xy - a.xy) * u;
	float pw = a.z + (b.z - a.z) * u;
	float pz = a.w + (b.w - a.w) * u;
	vec3 cols = r2_wcol(ext_w(pw)) * (wgt * gain);
	vec2 pix = floor(p + 0.5);
	bool behind = pz < -0.05 && ext.w > 0.5 && r2_hull_at(pix);
	// energy runs along every edge: two hot beads with short tails
	vec3 bc_core = vec3(0.0), bc_src = vec3(0.0);
	if (beads > 0.0 && n > 3 && !behind) {
		float ph = fract(bead_ph + float((EI[e] * 7 + EJ[e] * 13) % 17) / 17.0);
		for (int kb = 0; kb < 2; kb++) {
			float ub = fract(ph + 0.5 * float(kb));
			float tail = u <= ub ? clamp(1.0 - (ub - u) / 0.22, 0.0, 1.0) : 0.0;
			tail = tail * tail * tail * beads;
			if (tail > 0.02) {
				vec3 bc = cols / max(wgt * gain, 1e-3) * 0.4 + R2_HOT * 0.6;
				bc_core += bc * tail * 5.0;
				bc_src += bc * tail * 1.5;
			}
		}
	}
	at = pix;
	if (target == 0) {
		c0 = (behind ? vec3(0.0) : cols * 1.25) + bc_core;
		// near along W (the swollen outer cell) draws two pixels wide
		if (pw > 0.35 * ext.w && !behind) {
			c1 = cols * 0.9;
			size = abs(b.x - a.x) >= abs(b.y - a.y) ? vec2(1.0, 2.0) : vec2(2.0, 1.0);
		}
	} else {
		c0 = cols * (behind ? 0.35 : 1.0) + bc_src;
	}
}

void vertex() {
	vec2 corner = CORNER[VERTEX_ID % 6];
	int slot = VERTEX_ID / 6;
	vec2 at = vec2(-1e5);
	vec2 size = vec2(1.0);
	vec3 c0 = vec3(0.0), c1 = vec3(0.0);
	vec4 kind = vec4(0.0);
	int ne = 32 * maxe;
	vec2 face_at = vec2(-1e5);
	bool face = target == 2;
	if (face) {
		v_k = vec4(-1.0);
		v_c0 = vec3(0.0);
		v_c1 = vec3(0.0);
		v_loc = vec2(0.0);
		// a cell's pane: face f is the square spanned by axes a1, a2 at the other two's corner
		int f = slot;
		int pair = f / 4;
		int a1 = pair < 3 ? 0 : (pair < 5 ? 1 : 2);
		int a2 = pair == 0 ? 1 : (pair == 1 ? 2 : (pair == 2 ? 3 : (pair == 3 ? 2 : 3)));
		float fw = ext[a1] * ext[a2];
		if (faces_on > 0.5 && f < 24 && fw >= 0.05) {
			int o0 = -1, o1 = -1;
			for (int o = 0; o < 4; o++) {
				if (o != a1 && o != a2) {
					if (o0 < 0) { o0 = o; } else { o1 = o; }
				}
			}
			int base = (((f % 4) & 1) << o0) | (((f % 4) >> 1) << o1);
			int ids[4] = int[4](base, base | (1 << a1), base | (1 << a1) | (1 << a2), base | (1 << a2));
			int vi = VERTEX_ID % 6;
			int k = vi < 3 ? vi : (vi == 3 ? 0 : (vi == 4 ? 2 : 3));
			float wm = (vx[ids[0]].z + vx[ids[1]].z + vx[ids[2]].z + vx[ids[3]].z) * 0.25;
			float zm = (vx[ids[0]].w + vx[ids[1]].w + vx[ids[2]].w + vx[ids[3]].w) * 0.25;
			v_c0 = r2_wcol(ext_w(wm)) * (0.012 * fw * gain) * gain_k;
			v_c1 = vec3(0.0);
			v_k = vec4(3.0, zm < -0.05 ? 1.0 : 0.0, 0.0, 0.0);
			v_loc = vec2(0.0);
			face_at = vx[ids[k]].xy;
		}
	} else if (slot < ne) {
		if (cube_on > 0.5) {
			edge(slot / maxe, slot % maxe, at, size, c0, c1);
		}
	} else if (slot < ne + 16) {
		// a corner: a little star, brightest on the nearest along W
		int i = slot - ne;
		vec4 c = vx[i];
		vec2 pix = floor(c.xy + 0.5);
		if (cube_on > 0.5 && !(c.w < -0.05 && r2_hull_at(pix))) {
			float nearw = 0.5 + 0.5 * clamp(c.z / max(ext.w, 1e-3), -1.0, 1.0) * min(1.0, ext.w * 1.4);
			float arm = floor(2.0 + 5.0 * nearw);
			c0 = r2_wcol(ext_w(c.z));
			kind = vec4(1.0, arm, gain, 0.0);
			at = pix - 7.0;
			size = vec2(15.0);
		}
	} else if (slot < ne + 136 && mote.x > 0.5) {
		// a mote: a point that swells to a disc and shrinks back, as we see a 4D sphere's slice
		int i = slot - ne - 16;
		vec4 ma = mo_a[i];
		vec4 mb = mo_b[i];
		float kk = mote.y - mb.x + mb.y;
		if (kk >= 0.0 && kk <= 2.0 * mb.y) {
			float ph = (kk - mb.y) / mb.y;
			float r = mb.z * sqrt(max(0.0, 1.0 - ph * ph));
			float dist = ma.w * (1.0 - exp(-mote.y * 1.2)) / 1.2;
			vec2 X = mote.zw + (ma.xy + vec2(cos(ma.z), sin(ma.z) * 0.7) * dist) * mo_k;
			vec2 pix = floor(X + 0.5);
			float ri = floor(r * 0.8 + 0.5);
			c0 = mb.w > 0.0 ? R2_MAG : R2_MINT;
			kind = vec4(2.0, ri, 0.0, 0.0);
			at = pix - ri;
			size = vec2(2.0 * ri + 1.0);
		}
	}
	if (cell > 1.0 && at.x > -1e4) {
		// a coarse buffer: the whole cell the light falls in (a mote or a star by its middle)
		vec2 mid = kind.x > 0.5 ? at + floor(size * 0.5) : at;
		at = origin + floor((mid - origin) / cell) * cell;
		size = vec2(cell);
		if (kind.x > 0.5) {
			kind.w = 1.0;
		}
	}
	if (face) {
		VERTEX = face_at;
	} else {
		v_c0 = c0 * gain_k;
		v_c1 = c1 * gain_k;
		v_k = kind;
		v_loc = corner * size;
		VERTEX = at + corner * size;
	}
}

void fragment() {
	if (v_k.x < -0.5) {
		discard;
	}
	vec3 o = vec3(0.0);
	if (v_k.x > 2.5) {
		// a pane behind the hull is hidden by it
		if (v_k.y > 0.5 && r2_hull_at(floor(SCREEN_UV / SCREEN_PIXEL_SIZE) + origin)) {
			discard;
		}
		o = v_c0;
	} else if (v_k.x > 1.5) {
		// a mote: its disc faint, its rim bright; in the glow its disc only (a whole cell: its sum)
		vec2 d = floor(v_loc) - v_k.y;
		float ri = v_k.y;
		if (v_k.w > 0.5) {
			o = target == 1 && ri > 0.0 ? v_c0 * 0.4 * (3.14159 * (ri + 0.3) * (ri + 0.3) / (cell * cell)) : vec3(0.0);
		} else if (ri <= 0.0) {
			o = target == 0 ? v_c0 * 1.2 : vec3(0.0);
		} else {
			float dd = length(d);
			float disc = dd <= ri + 0.3 ? 1.0 : 0.0;
			float rim = dd > ri - 0.8 && dd <= ri + 0.3 ? 1.0 : 0.0;
			o = target == 0 ? (disc * 0.35 + rim * 1.1) * v_c0 : disc * 0.4 * v_c0;
		}
	} else if (v_k.x > 0.5) {
		// a corner: a hot point, its arms in the line light; in the glow its point only
		vec2 d = floor(v_loc) - 7.0;
		float arm = v_k.y;
		float g = v_k.z;
		if (v_k.w > 0.5) {
			o = target == 1 ? v_c0 * 3.5 * g / (cell * cell) : vec3(0.0);
		} else if (d.x == 0.0 && d.y == 0.0) {
			o = target == 0 ? R2_HOT * 4.0 * g : v_c0 * 3.5 * g;
		} else if (target == 0 && (d.x == 0.0 || d.y == 0.0)) {
			float dd = abs(d.x) + abs(d.y);
			if (dd < arm) {
				o = v_c0 * pow(1.0 - dd / arm, 1.6) * 2.2 * g;
			}
		}
	} else {
		// an edge's sample: its pixel, and its second where the edge is near along W
		vec2 d = floor(v_loc);
		o = (d.x + d.y) < 0.5 ? v_c0 : v_c1;
		if (cell > 1.0) {
			o = v_c0 / (cell * cell);
		}
	}
	COLOR = vec4(o, 1.0);
}
