shader_type canvas_item;

// THE BANNERS AS SHOWN (`YardCloth`, docs/why/YardBanner.md#pixels): the lit cloth (the top half of the 3D
// render, 1x), the room's rim lights on its edge pixels (the outermost whole, the one inside it half and
// dithered, stepped in quarters, in the row's field colour from the render's lower half), the rig (chains
// leaning with the rod, the rod with its bent ends) in its light, and the hover ring round the cloth.


uniform sampler2D lit : filter_nearest;
uniform sampler2D state : filter_nearest;
#define STATE state
#include "res://shaders/yard_cloth.gdshaderinc"
uniform float bx[7];
uniform vec3 rig[7];
uniform int hover = -1;
uniform vec4 mark = vec4(0.72, 0.96, 0.85, 1.0);
uniform float expo = 1.0;
// each rim light: (x, y, z or a direction, 1 a point), (colour, its rim x this frame's flicker), (1 / reach^2, 1 behind)
uniform int nr = 0;
uniform vec4 rp[8];
uniform vec4 rc[8];
uniform vec2 rk[8];

const ivec2 D4[4] = ivec2[4](ivec2(-1, 0), ivec2(1, 0), ivec2(0, -1), ivec2(0, 1));

vec4 at(ivec2 p) {
	return texture(lit, (vec2(p) + 0.5) / vec2(960.0, 320.0));
}

bool cov(ivec2 p) {
	return p.x >= 0 && p.y >= 0 && p.x < 960 && p.y < 160 && at(p).a > 0.5;
}

vec3 rims(ivec2 p, vec3 col) {
	bool n[4];
	bool f[4];
	for (int s = 0; s < 4; s++) {
		n[s] = cov(p + D4[s]);
		f[s] = cov(p + 2 * D4[s]);
	}
	vec3 fld = at(p + ivec2(0, 160)).rgb;
	for (int k = 0; k < nr; k++) {
		vec2 e = rp[k].xy;
		float att = 1.0;
		if (rp[k].w > 0.5) {
			vec3 l = vec3(rp[k].xy - vec2(p), rp[k].z);
			float d2 = dot(l, l);
			e = l.xy * inversesqrt(d2);
			att = 1.0 / (1.0 + d2 * rk[k].x);
		}
		float face = -1.0;
		int depth = 0;
		for (int s = 0; s < 4; s++) {
			float ee = dot(vec2(D4[s]), e);
			if (!n[s]) {
				face = depth == 1 ? max(face, ee) : ee;
				depth = 1;
			} else if (depth != 1 && !f[s]) {
				face = max(face, ee);
				depth = 2;
			}
		}
		if (depth == 0 || (depth == 2 && tk_bay(p + ivec2(1, 0)) < 0.5)) {
			continue;
		}
		float kk = (rk[k].y > 0.5 ? 0.35 + 0.65 * max(0.0, face) : max(0.0, face)) * att * rc[k].w * (depth == 2 ? 0.5 : 1.0);
		kk = floor(kk / 0.25 + tk_bay(p) * 0.5) * 0.25;
		if (kk > 0.0) {
			col += fld * rc[k].rgb * kk * expo;
		}
	}
	return col;
}

// the rig at a pixel: its colour, alpha 0 where there is none
vec4 rig_at(ivec2 p, int b) {
	float rod = tk_rod(b);
	float rs = sign(rod) * floor(abs(rod) + 0.5);
	float x = float(p.x);
	vec3 c = vec3(-1.0);
	if (p.y >= 18 && p.y < 34) {
		float o = floor(rs * float(p.y - 18) / 15.0 + 0.5);
		if (x == bx[b] + 6.0 + o || x == bx[b] + 42.0 + o) {
			c = (p.y % 2 == 1) ? vec3(92.0, 86.0, 72.0) : vec3(150.0, 140.0, 116.0);
		}
	}
	float x0 = bx[b] - 4.0 + rs;
	float x1 = bx[b] + 51.0 + rs;
	if (x >= x0 && x <= x1) {
		int dy = (x <= x0 + 2.0 || x >= x1 - 2.0) ? 1 : 0;
		int r = p.y - 34 - dy;
		if (r >= 0 && r <= 3 && !(dy == 1 && r == 3)) {
			c = r == 0 ? vec3(104.0, 115.0, 134.0) : (r == 3 ? vec3(40.0, 44.0, 52.0) : vec3(67.0, 74.0, 86.0));
		}
	}
	return c.r < 0.0 ? vec4(0.0) : vec4(c * rig[b] / 255.0, 1.0);
}

void fragment() {
	ivec2 p = ivec2(floor(UV * vec2(960.0, 160.0)));
	int b = clamp(int(floor((float(p.x) - 94.0) / 112.0)), 0, 6);
	vec4 c = at(p);
	if (c.a > 0.5) {
		vec3 col = c.rgb;
		if (nr > 0 && p.x > 0 && p.y > 0 && p.x < 959 && p.y < 159) {
			col = rims(p, col);
		}
		COLOR = vec4(min(col, vec3(1.0)), 1.0);
	} else {
		bool ring = false;
		if (hover == b) {
			for (int dy = -2; dy <= 2; dy++) {
				for (int dx = -2; dx <= 2; dx++) {
					ring = ring || cov(p + ivec2(dx, dy));
				}
			}
		}
		COLOR = ring ? vec4(mark.rgb, 1.0) : rig_at(p, b);
	}
}
