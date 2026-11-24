// SOLARI'S CASTING BED: show18's light (life2/solari/engine.py Lights), shared by the room, the things
// standing in it, the hulls and the air. Every light is a field on the film's 2x2 cell grid; a cell sums
// field x weight x colour (l3), its weight (s0) and its weight x breath (s1); the sum is stepped into
// sixths and the breath multiplies after the stepping. Static fields are baked (fields.png, 4 to a layer,
// 270 rows a layer, port/solari/export.py); the moving pools are drawn here from `pools_*`.
// Why: docs/why/ShipRoomSolari.md#light

uniform sampler2D fields : filter_nearest, repeat_disable;
uniform sampler2D air : filter_linear, repeat_disable;
uniform float fscale[32];
uniform float ascale[28];
// per furnace: fire_k (its breath), its pour's flare (the lip's catch), a pour's weight and gutter
uniform float fk[6];
uniform float flare[6];
uniform float pour_w[6];
uniform float pour_b[6];
// the roar's light out of furnace 2 (door field 1..5, its weight, its flicker)
uniform int door_k = 0;
uniform float door_w = 0.0;
uniform float door_b = 1.0;
uniform int arc_i = -1;
uniform float arc_w = 0.0;
uniform float grind_w = 0.0;
uniform int tech_i = -1;
uniform float tired_b = 1.0;
// moving pools: (cx, cy, rx, ry), (edge, front, clip y0, clip y1), (colour x steady, steady), (breath, no ring, 0, 0)
uniform int n_pools = 0;
uniform vec4 pool_a[32];
uniform vec4 pool_b[32];
uniform vec4 pool_c[32];
uniform vec4 pool_d[32];
// the people walking through the arc's light: (x0, x1, z, height); the torch's tip
uniform vec4 people[3];
uniform vec2 arc_tip = vec2(0.0);

const vec3 AMBC = vec3(1.0, 0.84, 0.72);
const vec3 FIRE = vec3(1.0, 0.62, 0.30);
const vec3 LAMP = vec3(1.0, 0.78, 0.50);
const vec3 WHITE_HEAT = vec3(1.0, 0.93, 0.78);
const vec3 ARC = vec3(0.72, 0.85, 1.0);
const float TAPS[6] = float[](33.0, 206.0, 380.0, 560.0, 743.0, 920.0);
const float FOOT = 207.0;

float fch(ivec2 c, int k) {
	ivec2 p = ivec2(clamp(c.x, 0, 479), clamp(c.y, 0, 269) + (k / 4) * 270);
	vec4 v = texelFetch(fields, p, 0);
	int ch = k - (k / 4) * 4;
	float x = ch == 0 ? v.r : (ch == 1 ? v.g : (ch == 2 ? v.b : v.a));
	return x * fscale[k];
}

float ach(vec2 cell, int k) {
	vec2 q = (cell + 0.5) / 4.0;
	vec2 uv = vec2(q.x / 120.0, (clamp(q.y, 0.5, 67.5) + float(k / 4) * 68.0) / (68.0 * 7.0));
	vec4 v = texture(air, uv);
	int ch = k - (k / 4) * 4;
	float x = ch == 0 ? v.r : (ch == 1 ? v.g : (ch == 2 ? v.b : v.a));
	return x * ascale[k];
}

float pool_at(vec2 p, int i, float ring) {
	vec4 a = pool_a[i];
	vec4 b = pool_b[i];
	float f;
	if (a.y >= FOOT) {
		float r = length((p - a.xy) / a.zw);
		f = clamp((1.0 - r) / b.x, 0.0, 1.0);
	} else {
		// round 14's soft wall pool: a smooth bump across times a smooth bump down
		vec2 u = clamp(abs(p - a.xy) / a.zw, 0.0, 1.0);
		f = (1.0 - u.x * u.x) * (1.0 - u.x * u.x) * (1.0 - u.y * u.y) * (1.0 - u.y * u.y);
	}
	if (b.y > 0.0) {
		f *= 1.0 - b.y * clamp((p.y - (a.y - a.w)) / (2.0 * a.w), 0.0, 1.0);
	}
	if (b.w > b.z) {
		f *= (p.y >= b.z && p.y < b.w) ? 1.0 : 0.0;
	}
	if (pool_d[i].y > 0.5) {
		f *= 1.0 - ring;
	}
	return f;
}

// shadows13.hit: does the line from a floor cell to the light pass through anyone walking?
bool people_hit(vec2 f, vec3 l) {
	if (f.y < FOOT) {
		return false;
	}
	for (int i = 0; i < 3; i++) {
		vec4 s = people[i];
		if (s.w <= 0.0) {
			continue;
		}
		float dz = f.y - l.y;
		if (abs(dz) <= 0.5) {
			continue;
		}
		float u = (s.z - l.y) / dz;
		if (u <= 0.0 || u > 1.0) {
			continue;
		}
		float xr = round(l.x + (f.x - l.x) * u);
		float hr = l.z * (1.0 - u);
		if (xr >= s.x && xr <= s.y && hr >= 0.0 && hr <= s.w) {
			return true;
		}
	}
	return false;
}

// shadows13.point: 0.15 in a walker's shadow, 0.55 on its one-cell edge
float people_k(ivec2 c, vec3 l) {
	vec2 f = vec2(c) * 2.0 + 1.0;
	if (people_hit(f, l)) {
		return 0.15;
	}
	if (people_hit(f + vec2(2.0, 0.0), l) || people_hit(f - vec2(2.0, 0.0), l)
			|| people_hit(f + vec2(0.0, 2.0), l) || people_hit(f - vec2(0.0, 2.0), l)) {
		return 0.55;
	}
	return 1.0;
}

// The cell's light before stepping: l3 (rgb), s0, s1.
void light_sum(ivec2 c, out vec3 l3, out float s0, out float s1) {
	l3 = vec3(fch(c, 0), fch(c, 1), fch(c, 2));
	s0 = fch(c, 3);
	s1 = s0;
	float v = fch(c, 29);
	l3 += v * LAMP;
	s0 += v;
	s1 += v * tired_b;
	bool fl = c.y * 2 >= int(FOOT);
	float bl = fch(c, 16);
	float ring = fch(c, 30);
	int lip = int(round(fch(c, 31) * 6.0));
	for (int i = 0; i < 6; i++) {
		float w = fch(c, 4 + i);
		float pf = fch(c, 10 + i);
		v = w + 0.24 * pf;
		if (lip == i + 1) {
			v += 0.16 + 0.30 * flare[i];
		}
		l3 += v * FIRE;
		s0 += v;
		s1 += v * fk[i];
		if (pour_w[i] > 0.0) {
			v = pf * bl * pour_w[i];
			l3 += v * FIRE;
			s0 += v;
			s1 += v * pour_b[i];
		}
	}
	if (door_k > 0) {
		v = fch(c, 16 + door_k) * door_w;
		l3 += v * WHITE_HEAT;
		s0 += v;
		s1 += v * door_b;
	}
	if (arc_i >= 0) {
		v = fch(c, 22 + arc_i) * arc_w;
		// a walker near the arc throws its own point shadow (show20: no wedges from the pours or the roar)
		if (v > 0.0 && fl) {
			v *= people_k(c, vec3(arc_tip.x, 386.0, 386.0 - arc_tip.y));
		}
		l3 += v * ARC;
		s0 += v;
		s1 += v;
	}
	if (grind_w > 0.0) {
		v = fch(c, 25) * 0.6;
		l3 += v * FIRE;
		s0 += v;
		s1 += v * grind_w;
	}
	if (tech_i >= 0) {
		v = fch(c, 26 + tech_i) * 0.5;
		l3 += v * vec3(1.0, 0.92, 0.75);
		s0 += v;
		s1 += v;
	}
	vec2 p = vec2(c) * 2.0 + 0.5;
	for (int i = 0; i < n_pools; i++) {
		v = pool_at(p, i, ring);
		if (v <= 0.0) {
			continue;
		}
		l3 += v * pool_c[i].rgb;
		s0 += v * pool_c[i].a;
		s1 += v * pool_c[i].a * pool_d[i].x;
	}
}

// Lights.stepped: sixths (below 1.5 of a step it runs smooth), the overflow a little brighter,
// the breath after the stepping, the tint kept.
vec3 stepped(vec3 l3, float s0, float s1) {
	float l = max(l3.r, max(l3.g, l3.b));
	float q = floor(l * 6.0 + 0.5) / 6.0;
	bool hi = l >= 0.25;
	float tq = hi ? min(q, 1.0) : l;
	float ov = (hi && q > 1.0) ? min(q - 1.0, 0.35) : 0.0;
	float bm = s0 > 1e-6 ? s1 / s0 : 1.0;
	tq = min(1.0, tq * bm);
	ov *= bm;
	vec3 tr = l3 / max(l, 1e-6);
	vec3 m = 0.10 * AMBC * (1.0 - tq) + (1.0 - 0.45 * (1.0 - tr)) * tq;
	return m + ov * 0.3 * m;
}

// The light multiplier m at a frame pixel (lit = albedo x m x 1.7).
vec3 light_m(vec2 fp) {
	ivec2 c = ivec2(floor(fp * 0.5));
	vec3 l3;
	float s0;
	float s1;
	light_sum(c, l3, s0, s1);
	return stepped(l3, s0, s1);
}

// air_light: the l3 field blurred wide, for the haze's colour.
vec3 air_l3(vec2 fp) {
	vec2 cell = floor(fp * 0.5);
	vec3 l3 = vec3(ach(cell, 0), ach(cell, 1), ach(cell, 2)) + ach(cell, 3) * LAMP;
	for (int i = 0; i < 6; i++) {
		l3 += (ach(cell, 4 + i) + (0.24 + pour_w[i]) * ach(cell, 10 + i)) * FIRE;
	}
	if (door_k > 0) {
		l3 += ach(cell, 15 + door_k) * door_w * WHITE_HEAT;
	}
	if (arc_i >= 0) {
		l3 += ach(cell, 21 + arc_i) * arc_w * ARC;
	}
	if (grind_w > 0.0) {
		l3 += ach(cell, 24) * 0.6 * FIRE;
	}
	if (tech_i >= 0) {
		l3 += ach(cell, 25 + tech_i) * 0.5 * vec3(1.0, 0.92, 0.75);
	}
	vec2 p = cell * 2.0 + 0.5;
	for (int i = 0; i < n_pools; i++) {
		l3 += pool_at(p, i, 0.0) * pool_c[i].rgb;
	}
	return l3;
}

// The hall's air in front of a pixel at haze level a (twelfths): toward the glow of the light round it.
vec3 hazed(vec3 rgb, vec2 fp, float a) {
	vec3 al = clamp(air_l3(fp), 0.0, 1.6);
	vec3 hcol = (vec3(22.0, 15.0, 12.0) + al * vec3(150.0, 92.0, 52.0)) / 255.0;
	return rgb * (1.0 - a) + hcol * a;
}
