shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE PAINTED SECTOR MAP'S PAINT PASS (`SectorPainted`, style PAINTED), one
// fragment a block, in the place picture where the cut palette's pass stands
// in the other styles. The band memory (`sector_b_state`) has given every block
// of the far picture one entry of the scene's curated palette; this paints it
// the way a pixel artist finishes a blocked-in picture (bible 4.1, the
// showcase's `B/sector/paint.glsl`):
//  - cleanup: a lone block that differs from four agreeing neighbours takes
//    their colour (never a star);
//  - transitions: a block beside the next darker step of its own ramp takes
//    that step on every other block, a 1-block 50% checker (never a Bayer
//    ramp, never between two dark steps), only along runs, so a thin feature
//    stays crisp;
//  - silhouettes: where a big shape of the mid gas or the dust meets something
//    else, the side facing away from the star takes an outline two steps down,
//    the side facing it a rim one step up;
//  - sparkles: a tier 2 star wears a plus, a tier 3 a four-point star with
//    diagonal glints whose arms step slowly longer and shorter (never a strobe).

uniform sampler2D state : filter_nearest;
uniform sampler2D pal : filter_nearest;
uniform int u_grp[96];
uniform int u_step[96];
uniform int u_glen[32];
// per ramp: 1 soft (its bands checker), 2 shape (outline and rim), 4 sparkle,
// 8 dark (no checker on its lowest steps)
uniform int u_gfl[32];
uniform int u_star0 = 0;
uniform int u_star_n = 0;
// where the star is, in the place picture's 960 x 540 pixels
uniform vec2 star_at = vec2(480.0, 270.0);
uniform float time = 0.0;
// the far picture's slide in blocks: checker parity and twinkle ride the sky
uniform vec2 sky_blk = vec2(0.0);
uniform bool low = false;

struct Ent { int e; int g; int s; int t; };
Ent fetchE(ivec2 b) {
	b = clamp(b, ivec2(0), ivec2(479, 269));
	vec4 v = texelFetch(state, b, 0);
	Ent r;
	r.e = int(v.r * 255.0 + 0.5);
	r.g = u_grp[r.e];
	r.s = u_step[r.e];
	r.t = int(v.b * 3.0 + 0.5);
	return r;
}
float hsh(vec2 p) {
	uvec2 q = uvec2(ivec2(p) + 65536);
	uint h = (q.x * 374761393u) ^ (q.y * 668265263u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}
Ent pickN(int k, Ent a, Ent b, Ent c, Ent d) {
	if (k == 0) return a;
	if (k == 1) return b;
	if (k == 2) return c;
	return d;
}
vec3 colOf(int e) { return texelFetch(pal, ivec2(e, 0), 0).rgb; }
// the sparkle ramp's entry a step dimmer than e (its arms), or e itself
int dimmer(int e) { return u_step[e] > 0 ? e - 1 : e; }

void fragment() {
	ivec2 b = ivec2(floor(UV * vec2(480.0, 270.0)));
	Ent c = fetchE(b);
	Ent n0 = fetchE(b + ivec2(1, 0));
	Ent n1 = fetchE(b + ivec2(-1, 0));
	Ent n2 = fetchE(b + ivec2(0, 1));
	Ent n3 = fetchE(b + ivec2(0, -1));
	int fl = u_gfl[c.g];
	bool spark = (fl & 4) != 0;
	int e = c.e;
	ivec2 di = b + ivec2(sky_blk);
	bool odd = ((di.x + di.y) & 1) == 1;
	// cleanup
	if (!spark && n0.e == n1.e && n1.e == n2.e && n2.e == n3.e && n0.e != c.e && (u_gfl[n0.g] & 4) == 0) {
		e = n0.e;
		c = n0;
		fl = u_gfl[c.g];
	} else if (!spark) {
		int same = (n0.e == c.e ? 1 : 0) + (n1.e == c.e ? 1 : 0) + (n2.e == c.e ? 1 : 0) + (n3.e == c.e ? 1 : 0);
		// transitions: the 1-block checker on the bright side of a band edge
		if ((fl & 1) != 0 && odd && same >= 2 && c.s > 0 && !((fl & 8) != 0 && c.s <= 1)) {
			bool dk = (n0.g == c.g && n0.s == c.s - 1) || (n1.g == c.g && n1.s == c.s - 1)
				|| (n2.g == c.g && n2.s == c.s - 1) || (n3.g == c.g && n3.s == c.s - 1);
			if (dk) e = c.e - 1;
		}
		// silhouettes of the big shapes, against the star's direction
		if ((fl & 2) != 0 && same >= 2 && !low) {
			vec2 toS = star_at - (vec2(b) * 2.0 + 1.0);
			toS /= max(length(toS), 1.0);
			float dOut = 1e9, dRim = -1e9;
			for (int k = 0; k < 4; k++) {
				Ent nb = pickN(k, n0, n1, n2, n3);
				vec2 dd = k == 0 ? vec2(1.0, 0.0) : (k == 1 ? vec2(-1.0, 0.0) : (k == 2 ? vec2(0.0, 1.0) : vec2(0.0, -1.0)));
				bool edge = (nb.g != c.g && (u_gfl[nb.g] & 4) == 0) || (nb.g == c.g && nb.s <= c.s - 2);
				if (edge) {
					float d = dot(dd, toS);
					dOut = min(dOut, d);
					dRim = max(dRim, d);
				}
			}
			if (dOut < -0.38) {
				e = c.e - min(c.s, 2);
			} else if (dRim > 0.38 && c.s >= 1 && c.s < u_glen[c.g] - 1) {
				e = c.e + 1;
			}
		}
	}
	// SPARKLES: a star's arms on the blocks round it
	if (u_star_n > 0 && !low && !spark) {
		for (int k = 0; k < 4; k++) {
			Ent nb = pickN(k, n0, n1, n2, n3);
			// (a dim heart's arms went darker than the sky: dark crosses in the band)
			if (nb.t >= 2 && u_step[nb.e] >= 2) {
				e = dimmer(nb.e);
			}
		}
		if (e == c.e || (u_gfl[u_grp[e]] & 4) == 0) {
			for (int k = 0; k < 8; k++) {
				ivec2 o = k == 0 ? ivec2(2, 0) : (k == 1 ? ivec2(-2, 0) : (k == 2 ? ivec2(0, 2) : (k == 3 ? ivec2(0, -2)
					: (k == 4 ? ivec2(1, 1) : (k == 5 ? ivec2(-1, 1) : (k == 6 ? ivec2(1, -1) : ivec2(-1, -1)))))));
				Ent nb = fetchE(b + o);
				if (nb.t == 3 && u_step[nb.e] >= 2) {
					// the arms' tips come and go on the star's own slow beat
					float h = hsh(vec2(b + o) + sky_blk);
					bool longArm = fract(time / (3.0 + 3.0 * h) + h) < 0.5;
					if (k >= 4 || longArm) {
						e = dimmer(dimmer(nb.e));
					}
				}
			}
		}
	}
	COLOR = vec4(colOf(e), 1.0);
}
