shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE PAINTED CLOUD'S FORM, baked once a system (`SectorPainted.bake_puffs`): the
// way B's sky bake blocks in clouds (showcase `B/sector/bake.glsl`), three gas
// sheets (far, mid, near), each a set of big MASSES shaded as one dome, with round
// lumpy LOBES along their edges so the outline billows while the body reads as one
// lit shape. Jon on the posterised cloud: "The clouds are fluffy and full and
// connected in the concept, and in game they are harsh and disconnected".
//
// WHERE the masses are is SIMPLIFIED's own cloud (the field bake's density, `src`),
// smoothed heavily, so the gas stands where the weather and the cloud's light
// expect it; only its stringy, sharp edges are gone. A little low noise bends the
// masses so they are not just the blur's blobs.
//
// One texel a block, the field bake's frame (its margin too); the three sheets
// stacked, `tex.y` rows each. Out: r = height / (2 * cell), g/b = the normal's xy
// * 0.5 + 0.5, a = fine detail. Height 0: no gas in that sheet.

uniform sampler2D src : filter_linear, repeat_disable;
uniform vec2 tex = vec2(576.0, 366.0);
uniform float mb = 48.0;
uniform float sd = 0.0;
// the sheets' mass thresholds (on the smoothed density)
uniform vec3 thr = vec3(0.16, 0.45, 0.68);
// the blur's step (sky px; 7 x 7 steps, Gaussian)
uniform float blur = 12.0;
// the cloud's kind (0 emission: its dust is the pillars and their bank, not its lanes)
uniform int kind = 0;

float h1(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p)) + 65536);
	uint h = (q.x * 374761393u) ^ (q.y * 668265263u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(h1(i), h1(i + vec2(1.0, 0.0)), f.x), mix(h1(i + vec2(0.0, 1.0)), h1(i + vec2(1.0)), f.x), f.y);
}
float sheetS(int k) { return k == 0 ? 96.0 : (k == 1 ? 64.0 : 48.0); }
float sheetD(int k) { return k == 0 ? 70.0 : (k == 1 ? 56.0 : 40.0); }
float thrOf(int k) { return k == 0 ? thr.x : (k == 1 ? thr.y : thr.z); }

// SIMPLIFIED's cloud, smoothed heavily (sky px)
float maskAt(vec2 sp) {
	float s = 0.0, w = 0.0;
	float sg = 2.0 * blur * 2.0 * blur * 2.0;
	for (int j = -3; j <= 3; j++) {
		for (int i = -3; i <= 3; i++) {
			vec2 o = vec2(float(i), float(j)) * blur;
			float g = exp(-dot(o, o) / sg);
			// (a dark cloud is its dust: its masses are the dust's)
			vec4 a = texture(src, (sp + o + mb * 2.0) / (2.0 * tex));
			s += g * (kind == 4 ? a.g : a.r);
			w += g;
		}
	}
	return s / w;
}
// the mass a sheet's clouds are made of: the smoothed cloud, bent by a low noise
// (half the cloud's own gas, half B's own masses -- two octaves of value noise,
// warped -- so the gas breaks into several clouds with their own domes; and none
// where the cloud has no gas)
float mass(vec2 p, int k) {
	float fk = float(k) * 7.31 + sd;
	float L = k == 2 ? 192.0 : 384.0;
	vec2 wv = (vec2(vn(p / (L * 0.5) + fk), vn(p / (L * 0.5) + fk + 11.7)) - 0.5) * L * 0.5;
	vec2 q = p + wv;
	float n = 0.68 * vn(q / L + fk * 1.3) + 0.32 * vn(q / (L * 0.5) + fk * 2.1);
	float mk = maskAt(p + wv * 0.25);
	// (the far sheet all through the cloud: where it left gaps, the sky behind showed in
	// dark stringy plates)
	return (0.55 * mk + 0.45 * n) * smoothstep(k == 0 ? 0.01 : 0.04, k == 0 ? 0.08 : 0.22, mk) + (k == 0 ? 0.25 * smoothstep(0.02, 0.15, mk) : 0.0);
}
// a mass as a dome: steep at its edge, rising slowly to its middle
// (the far sheet's domes broad: at 0.25 its masses topped out flat and it read as one plate)
float dome(float m, int k) { return sheetD(k) * sqrt(clamp((m - thrOf(k)) / (k == 0 ? 0.5 : 0.25), 0.0, 1.0)); }

// periodic value noise round a circle: n lattice points over a turn (an outline's lumps)
float angN(float a, int n, int s) {
	float x = (a / 6.2831853 + 0.5) * float(n);
	float i = floor(x), f = x - i;
	int i0 = int(i) % n, i1 = (int(i) + 1) % n;
	float u = f * f * (3.0 - 2.0 * f);
	return mix(h1(vec2(float(i0), float(s))), h1(vec2(float(i1), float(s))), u);
}

// THE DUST (a fourth sheet): SIMPLIFIED's own, lightly smoothed so a pillar's edge
// is a clean line and not the noise's stair-steps (an emission cloud's lanes left
// out: B's dust is the pillars and their bank)
float dustAt(vec2 sp) {
	vec4 a = texture(src, (sp + mb * 2.0) / (2.0 * tex));
	return kind == 0 ? max(a.g - 0.45 * a.a * a.b, 0.0) : a.g;
}
float dustSm(vec2 sp) {
	float s = 0.0, w = 0.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 o = vec2(float(i), float(j)) * 3.0;
			float g = exp(-dot(o, o) / 50.0);
			s += g * dustAt(sp + o);
			w += g;
		}
	}
	return s / w;
}

void fragment() {
	ivec2 t = ivec2(floor(UV * vec2(tex.x, tex.y * 4.0)));
	int k = clamp(t.y / int(tex.y), 0, 3);
	vec2 p = (vec2(float(t.x), float(t.y - k * int(tex.y))) + 0.5) * 2.0 - mb * 2.0;
	if (k == 3) {
		float dv = dustSm(p);
		vec2 gr = vec2(dustSm(p + vec2(4.0, 0.0)) - dustSm(p - vec2(4.0, 0.0)), dustSm(p + vec2(0.0, 4.0)) - dustSm(p - vec2(0.0, 4.0)));
		vec2 no = -gr / max(length(gr), 1e-5);
		COLOR = vec4(dv, no.x * 0.5 + 0.5, no.y * 0.5 + 0.5, vn(p / 30.0 + 3.0));
	} else {
	float S = sheetS(k);
	float m = mass(p, k);
	float H = 0.0;
	vec3 N = vec3(0.0, 0.0, 1.0);
	if (m > thrOf(k)) {
		float e = 4.0;
		H = dome(m, k);
		float dx = dome(mass(p + vec2(e, 0.0), k), k) - dome(mass(p - vec2(e, 0.0), k), k);
		float dy = dome(mass(p + vec2(0.0, e), k), k) - dome(mass(p - vec2(0.0, e), k), k);
		N = normalize(vec3(-dx, -dy, 2.0 * e * 1.4));
	}
	// LOBES on the masses' edges (B: centred in the band just inside the edge), each a
	// low lumpy bump -- never a clean circle, a ring of those reads as soap bubbles --
	// lit mostly as its mass is, with a little roundness of its own
	ivec2 c0 = ivec2(floor(p / S));
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 c = vec2(c0 + ivec2(dx, dy));
			vec2 hc = c + vec2(float(k) * 131.0 + sd * 3.0, float(k) * 71.0);
			vec3 hh = vec3(h1(hc), h1(hc + 17.3), h1(hc + 41.9));
			float hw = h1(hc + 77.7);
			vec2 ctr = (c + 0.5 + (hh.xy - 0.5) * 0.7) * S;
			float mc = mass(ctr, k);
			float x = mc - thrOf(k);
			// edge lobes in the band just inside the edge (the billowing outline), and
			// now and then a big one inside, so a mass's body is not one flat dome
			bool inner = x > 0.09 && x < 0.45 && hw < 0.18;
			if (!inner && (x < -0.015 || x > 0.07 || hh.z < 0.18)) continue;
			float r = S * (inner ? 0.6 + 0.4 * hh.z : 0.42 + 0.34 * hh.z);
			float base = dome(max(mc, thrOf(k)), k) * (inner ? 0.7 : 0.55);
			vec2 d = p - ctr;
			float dd = dot(d, d);
			if (dd >= r * r * 1.5) continue;
			float a = atan(d.y, d.x);
			int ls = int(hw * 997.0) + k * 13;
			float rr = r * (0.86 + 0.28 * angN(a, 5, ls) + 0.08 * angN(a, 11, ls + 3));
			if (dd >= rr * rr) continue;
			float z = sqrt(rr * rr - dd), h = base + z * 0.85;
			if (h > H) {
				vec3 Nm = N;
				H = h;
				N = normalize(mix(Nm, normalize(vec3(d, z)), 0.45));
			}
		}
	}
	// (broad: a fine detail lifted single blocks a band up and the gas came out speckled)
	float det = 0.6 * vn(p / 46.0 + float(k) * 5.0) + 0.4 * vn(p / 23.0 + float(k) * 9.0);
	COLOR = vec4(clamp(H / (2.0 * S), 0.0, 1.0), N.x * 0.5 + 0.5, N.y * 0.5 + 0.5, det);
	}
}
