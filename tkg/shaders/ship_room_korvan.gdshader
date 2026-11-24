shader_type canvas_item;
render_mode unshaded;

// KORVAN'S PARTS DEPOT, LIT AS ITS FILM WAS (life2/korvan/r18/mix18.py, core.py). Every field is the
// film's own, stepped offline (tk-scratch/shipselect/port/korvan/export.py); what moves is worked out here
// on the frame's 4x4 Bayer grid. Why: docs/why/ShipRoomKorvan.md#light
//   mode 0  the room: its albedo under L (static + dyn + floor-only), the emissive over it
//   1  a post: the stands' own light x WORK x the lamps, plus dyn and dobj, side-lit by work lights
//   2  a hull: the berth lamps' ship light x its row light (hull_light), plus dsh, capped at 0.98
//   3  life: its own colour under the object light (lmode: 0 at its pixels, 1 at a point, 2 k-scaled,
//      3 the room light at its pixels (albedo edits), 4 as drawn, 5 a flat light; then x mul + add)

uniform int mode = 0;
uniform sampler2D albedo : filter_nearest, repeat_disable;
uniform sampler2D emissive : filter_nearest, repeat_disable;
uniform sampler2D lt0 : filter_nearest, repeat_disable;
uniform sampler2D lt1 : filter_nearest, repeat_disable;
uniform sampler2D lt2 : filter_nearest, repeat_disable;
uniform sampler2D lt3 : filter_nearest, repeat_disable;
uniform sampler2D lt4 : filter_nearest, repeat_disable;
uniform sampler2D lt5 : filter_nearest, repeat_disable;
uniform sampler2D lt6 : filter_nearest, repeat_disable;
uniform sampler2D lt7 : filter_nearest, repeat_disable;
uniform sampler2D dy0 : filter_nearest, repeat_disable;
uniform sampler2D dy1 : filter_nearest, repeat_disable;
uniform sampler2D dy2 : filter_nearest, repeat_disable;
uniform sampler2D dy3 : filter_nearest, repeat_disable;

// this frame: each tube's weight (top 0-14, mid 15-17, low 18-23), their mean, the door lamps'
uniform float tw[24];
uniform float lk = 1.0;
uniform float door_lamp = 1.0;
// the crane's load keeps the lamps off what is under it: its columns (a, b), its foot row, and the
// cargo drones' load (centre, half width; half strength); x < -9000 is none
uniform vec4 crane = vec4(-9999.0, -9999.0, 999.0, 0.0);
uniform vec2 drone_load = vec2(-9999.0, 0.0);
// point lights: (cx, cy, r, fall), (sy, weight, buffers, side x), colour; buffers 1 dyn, 2 dobj, 4 dsh, 8 floor
uniform int n_pts = 0;
uniform vec4 pa[32];
uniform vec4 pb[32];
uniform vec3 pc[32];
// the static fields' weights x colours this frame
uniform vec3 k_arc_floor = vec3(0.0);
uniform vec3 k_burn_wf = vec3(0.0);
uniform vec3 k_burn_obj = vec3(0.0);
uniform vec3 k_burn_ship = vec3(0.0);
uniform vec3 k_slab = vec3(0.0);
uniform int slab_lv = 0;
uniform vec3 k_door_obj = vec3(0.0);
uniform vec3 k_wfloor0 = vec3(0.0);
uniform vec3 k_wfloor1 = vec3(0.0);
// side-lit work lights on the posts: the arc, the burner, the ladder lights (x each)
uniform vec4 side_x = vec4(-9999.0);
// the engine's two turning beacons: (spot x, spot y, strength); strength 0 is off
uniform vec3 beacon0 = vec3(0.0);
uniform vec3 beacon1 = vec3(0.0);
// the crane's three beacons on the wall: (x, row, strength), radius 14, 14, 20
uniform vec3 cb0 = vec3(0.0);
uniform vec3 cb1 = vec3(0.0);
uniform vec3 cb2 = vec3(0.0);
// the survey drone's downlight cone: (x, strength); strength 0 is none
uniform vec2 survey = vec2(0.0);
// the posts: up to six (x, top, w, h), for the side-lit rule
uniform vec4 posts[6];
uniform float hull_amb = 0.6;

instance uniform vec2 rows = vec2(0.0, 1.0);
instance uniform int lmode = 0;
instance uniform vec2 lp = vec2(0.0);
instance uniform vec4 lk4 = vec4(0.0, 0.0, 9.0, 1.0);
instance uniform vec3 ladd = vec3(0.0);

varying vec2 fp;

const vec3 TUBE = vec3(0.84, 0.92, 1.0);
const vec3 WORK = vec3(1.0, 0.86, 0.66);
const vec3 LOW2 = vec3(0.75, 1.0, 1.0);
const vec3 AMBC = vec3(0.62, 0.78, 1.0);

void vertex() {
	fp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float bay(ivec2 q) {
	int i = (q.y & 3) * 4 + (q.x & 3);
	float B[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);
	return B[i] / 16.0;
}

// core.step: six levels, only the outer quarter of each step dithered
float step6(float f, ivec2 q) {
	float v = clamp(f, 0.0, 2.5) * 6.0;
	float lo = floor(v);
	float fr = v - lo;
	float up = (fr > 0.75 && bay(q) < (fr - 0.75) * 4.0) ? 1.0 : 0.0;
	return (lo + up) / 6.0;
}

// round 18's pools: twelve levels, each ordered-dithered into the next by its exact fraction
float step12(float f, ivec2 q) {
	float v = clamp(f, 0.0, 2.5) * 12.0;
	float lo = floor(v);
	return (lo + (bay(q) < v - lo ? 1.0 : 0.0)) / 12.0;
}

float f240(sampler2D t, ivec2 q, int c) {
	return texelFetch(t, q, 0)[c] * 255.0 / 240.0;
}

float f96(sampler2D t, ivec2 q, int c) {
	return texelFetch(t, q, 0)[c] * 255.0 / 96.0;
}

// core.point (and mix18's _point18 when sy < 1) at frame pixel q
float point_at(ivec2 q, vec4 a, float sy) {
	vec2 d = vec2(q) - a.xy;
	if (abs(d.x) > a.z || abs(d.y) > a.z) {
		return 0.0;
	}
	float dd = length(vec2(d.x, d.y / sy)) / a.z;
	float f = pow(max(1.0 - dd, 0.0), a.w);
	return sy < 1.0 ? step12(f, q) : step6(f, q);
}

// glow_local(r, fall, sy) as a patch centred on c
float glow_at(ivec2 q, vec2 c, float r, float fall, float sy) {
	vec2 d = vec2(q) - c;
	if (abs(d.x) > r || abs(d.y) > r) {
		return 0.0;
	}
	return pow(max(1.0 - length(vec2(d.x, d.y / sy)) / r, 0.0), fall);
}

float crane_cm(float x) {
	float c = clamp(min(x - crane.x, crane.y - x) / 6.0, 0.0, 1.0);
	float h = drone_load.y;
	float d = clamp(min(x - (drone_load.x - h), (drone_load.x + h) - x) / 6.0, 0.0, 1.0) * 0.5;
	return max(c, d);
}

// the hall's static light: every tube's stepped cone x its weight, the floor's even light, the crane's shadow
vec3 l_static(ivec2 q) {
	vec4 a = texelFetch(lt0, q, 0) * 255.0 / 240.0;
	vec4 b = texelFetch(lt1, q, 0) * 255.0 / 240.0;
	vec4 c = texelFetch(lt2, q, 0) * 255.0 / 240.0;
	vec4 d = texelFetch(lt3, q, 0) * 255.0 / 240.0;
	vec4 e = texelFetch(lt4, q, 0);
	vec4 f = texelFetch(lt5, q, 0) * 255.0 / 96.0;
	vec4 g = texelFetch(lt6, q, 0);
	float s = g.y > 0.5 ? 0.45 : 1.0;
	float top = a.x * tw[0] + a.y * tw[1] + a.z * tw[2] + a.w * tw[3] + b.x * tw[4] + b.y * tw[5]
		+ b.z * tw[6] + b.w * tw[7] + c.x * tw[8] + c.y * tw[9] + c.z * tw[10] + c.w * tw[11]
		+ d.x * tw[12] + d.y * tw[13] + d.z * tw[14] + d.w * tw[15]
		+ e.x * 255.0 / 240.0 * tw[16] + e.y * 255.0 / 240.0 * tw[17];
	vec3 L = top * s * TUBE;
	L += (e.z * 255.0 / 96.0 * tw[18] + e.w * 255.0 / 96.0 * tw[19] + f.y * tw[21] + f.z * tw[22] + f.w * tw[23]) * WORK;
	L += f.x * tw[20] * LOW2;
	L += g.x * 255.0 / 240.0 * lk * TUBE;
	if (float(q.y) >= crane.z + 8.0 && q.y < 207) {
		L *= 1.0 - 0.55 * crane_cm(float(q.x));
	}
	return L;
}

// the side a post shows a work light at x: lit, the terminator, the far side (shadows6.side_lit)
float side_k(ivec2 q, float sx) {
	if (sx < -9000.0) {
		return 1.0;
	}
	for (int i = 0; i < 6; i++) {
		vec4 p = posts[i];
		if (float(q.x) >= p.x && float(q.x) < p.x + p.z && float(q.y) >= p.y && float(q.y) < p.y + p.w) {
			float cx = p.x + p.z / 2.0;
			float s = sx >= cx ? 1.0 : -1.0;
			float u = (float(q.x) - cx) / (p.z / 2.0) * s;
			return u > 0.25 ? 1.0 : (u > -0.15 ? 0.5 : 0.12);
		}
	}
	return 1.0;
}

// what moves this frame, into the film's four buffers: dyn, dobj, dsh, floor-only. post: the side-lit rule.
void l_moving(ivec2 q, bool post, float back, out vec3 dyn, out vec3 dobj, out vec3 dsh, out vec3 flo) {
	dyn = vec3(0.0);
	dobj = vec3(0.0);
	dsh = vec3(0.0);
	flo = vec3(0.0);
	for (int i = 0; i < n_pts; i++) {
		float v = point_at(q, pa[i], pb[i].x);
		if (v <= 0.0) {
			continue;
		}
		vec3 c = pc[i] * v * pb[i].y;
		int m = int(pb[i].z);
		if ((m & 1) != 0) dyn += c;
		if ((m & 2) != 0) dobj += c * (post ? side_k(q, pb[i].w) : 1.0);
		if ((m & 4) != 0) dsh += c;
		if ((m & 8) != 0) flo += c;
	}
	vec4 a = texelFetch(dy0, q, 0) * 255.0 / 240.0;
	vec4 b = texelFetch(dy1, q, 0) * 255.0 / 240.0;
	vec4 c = texelFetch(dy2, q, 0) * 255.0 / 240.0;
	vec4 d = texelFetch(dy3, q, 0) * 255.0 / 240.0;
	flo += a.x * k_arc_floor + c.w * k_wfloor0 + d.x * k_wfloor1;
	dyn += a.y * k_burn_wf;
	dobj += a.z * k_burn_obj * (post ? side_k(q, side_x.y) : 1.0);
	dsh += a.w * k_burn_ship;
	float slab = slab_lv == 0 ? b.x : (slab_lv == 1 ? b.y : (slab_lv == 2 ? b.z : (slab_lv == 3 ? b.w : (slab_lv == 4 ? c.x : c.y))));
	dyn += slab * k_slab;
	dobj += c.z * k_door_obj * back;
	// the engine's beacons, each stepped on its own; the crane's three summed and stepped once
	vec3 amber = vec3(1.0, 0.62, 0.18);
	if (beacon0.z > 0.0) {
		float v = step6(glow_at(q, beacon0.xy, 16.0, 1.0, 2.2) * beacon0.z, q) * 1.4;
		dyn += v * amber;
		dobj += v * amber;
	}
	if (beacon1.z > 0.0) {
		float v = step6(glow_at(q, beacon1.xy, 16.0, 1.0, 2.2) * beacon1.z, q) * 1.4;
		dyn += v * amber;
		dobj += v * amber;
	}
	float cw = glow_at(q, cb0.xy, 14.0, 1.0, 1.8) * cb0.z + glow_at(q, cb1.xy, 14.0, 1.0, 1.8) * cb1.z
		+ glow_at(q, cb2.xy, 20.0, 1.0, 1.8) * cb2.z;
	if (cw > 0.0) {
		dyn += step6(cw, q) * amber * 1.3;
	}
	if (survey.y > 0.0 && q.y >= 104 && q.y < 123) {
		float u = float(q.y - 104) / 18.0;
		float half_w = 3.0 + 9.0 * u;
		float a0 = max(0.0, trunc(survey.x - half_w));
		float b0 = trunc(survey.x + half_w) + 1.0;
		if (float(q.x) >= a0 && float(q.x) < b0) {
			dyn += step6(1.0 - 0.4 * u, q) * survey.y * vec3(0.85, 0.95, 1.0);
		}
	}
}

// core.shade: the brightest channel is how much light, the ratios its colour; strong light washes dark paint
vec3 shade(vec3 base, vec3 L) {
	float l = max(L.r, max(L.g, L.b));
	vec3 n = L / max(l, 1e-6);
	vec3 tint = 1.0 - 0.7 * (1.0 - n);
	float tq = min(l, 1.0);
	float over = clamp(l - 1.0, 0.0, 0.5);
	vec3 m = 0.1 * AMBC * (1.0 - tq) + tint * tq;
	vec3 wash = clamp(l - 0.75, 0.0, 0.8) * n * 48.0 / 255.0;
	return base * m * (1.0 + over * 0.9) * 1.45 + wash;
}

vec3 l_room(ivec2 q) {
	vec3 dyn, dobj, dsh, flo;
	l_moving(q, false, 0.3, dyn, dobj, dsh, flo);
	return l_static(q) + dyn + flo;
}

vec3 l_obj(ivec2 q) {
	vec3 dyn, dobj, dsh, flo;
	l_moving(q, false, 0.3, dyn, dobj, dsh, flo);
	return l_static(q) + dyn + dobj;
}

float emis_k(ivec2 q) {
	int i = int(round(texelFetch(lt6, q, 0).z * 255.0));
	if (i == 0) {
		return 1.0;
	}
	return i <= 24 ? tw[i - 1] : door_lamp;
}

// a post's backlit rim from the door (door7.stand_backlight): its first two and last two columns, its top
float backlit(sampler2D tx, vec2 uv, vec2 px) {
	if (texture(tx, uv + vec2(-px.x, 0.0)).a < 0.5 || texture(tx, uv + vec2(-2.0 * px.x, 0.0)).a < 0.5
			|| texture(tx, uv + vec2(px.x, 0.0)).a < 0.5 || texture(tx, uv + vec2(2.0 * px.x, 0.0)).a < 0.5
			|| texture(tx, uv + vec2(0.0, -px.y)).a < 0.5) {
		return 1.0;
	}
	return 0.08;
}

void fragment() {
	ivec2 q = ivec2(floor(fp));
	vec4 c = COLOR;
	if (mode == 0) {
		vec3 a = texelFetch(albedo, q, 0).rgb;
		vec3 lit = shade(a, l_room(q));
		vec4 e = texelFetch(emissive, q, 0);
		float k = emis_k(q);
		vec3 er = e.rgb * (0.1 + 0.9 * clamp(k, 0.0, 1.0)) * max(1.0, k);
		COLOR = vec4(mix(lit, er, e.a), 1.0);
	} else if (mode == 1) {
		vec3 dyn, dobj, dsh, flo;
		float back = backlit(TEXTURE, UV, TEXTURE_PIXEL_SIZE);
		l_moving(q, true, back, dyn, dobj, dsh, flo);
		float st = texelFetch(lt6, q, 0).w * 255.0 / 96.0 * 0.9;
		vec3 L = st * WORK * lk + dyn + dobj;
		COLOR = vec4(shade(c.rgb, L), c.a);
	} else if (mode == 2) {
		vec3 dyn, dobj, dsh, flo;
		l_moving(q, false, 0.3, dyn, dobj, dsh, flo);
		vec4 s = texelFetch(lt7, q, 0) * 255.0 / 96.0;
		vec3 ls = s.x * 0.72 * lk * WORK + (s.y + s.z) * 0.92 * lk * TUBE;
		ls *= 1.0 - 0.78 * crane_cm(float(q.x));
		float u = clamp((float(q.y) - rows.x) / max(1.0, rows.y - rows.x), 0.0, 1.0);
		float g = u < 0.42 ? 1.0 : (u < 0.5 ? 0.5 : 0.3 + 0.2 * clamp((u - 0.5) / 0.5, 0.0, 1.0));
		g = step6(g, q);
		vec3 L = ls * g + dsh;
		float lm = max(L.r, max(L.g, L.b));
		L *= min(1.0, 0.98 / max(lm, 1e-6));
		COLOR = vec4(shade(c.rgb, L), c.a);
	} else {
		vec3 rgb = c.rgb;
		if (lmode == 0) {
			rgb = shade(rgb, l_obj(q) + lk4.x);
		} else if (lmode == 1) {
			rgb = shade(rgb, l_obj(ivec2(lp)) + lk4.x);
		} else if (lmode == 2) {
			vec3 L = l_obj(ivec2(lp));
			rgb *= clamp(max(L.r, max(L.g, L.b)) + lk4.x, lk4.y, lk4.z) * lk4.w;
		} else if (lmode == 3) {
			rgb = shade(rgb, l_room(q));
		} else if (lmode == 5) {
			rgb = shade(rgb, vec3(lk4.x));
		}
		COLOR = vec4(rgb * (lmode == 2 ? 1.0 : lk4.w) + ladd, c.a);
	}
}
