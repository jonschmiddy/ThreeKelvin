shader_type canvas_item;
render_mode unshaded;

// Solari's furnace light (Jon, Nov 20: idea C, embers and flare-ups). TEXTURE is the hull's
// light map from SolariFurnace: r the part (x40), g the disc radius (x200) or the distance
// along a line, b the art's own lightness. Every lit pixel is set to a colour off its part's
// ramp (the art's own colours), stepped with a 4x4 Bayer dither; at rest it is left alone.
// Why: docs/why/SolariFurnace.md#furnace-light

uniform sampler2D ramps : filter_nearest;
uniform ivec3 ramp_n = ivec3(1, 1, 1);
uniform vec2 size = vec2(1.0);
uniform float t = 0.0;
uniform vec4 flares[12];
uniform int flare_n = 0;
uniform vec2 sparks[24];
uniform int spark_n = 0;
uniform float fl = 0.0;
uniform float lens = 0.0;
uniform float glass = 1.0;
uniform float fwd_len = 1.0;
uniform float aft_len = 1.0;
uniform float speed = 200.0;
uniform float line_hold = 0.0;
uniform float line_decay = 0.3;
uniform float base_lvl = 0.5;
uniform float bed_k = 1.0;
uniform float line_rest = 0.52;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float line_level(float s, bool fwd) {
	float lv = line_rest;
	float len = fwd ? fwd_len : aft_len;
	for (int i = 0; i < 12; i++) {
		if (i >= flare_n) {
			break;
		}
		vec4 f = flares[i];
		float u = t - f.x;
		if (u < 0.0) {
			continue;
		}
		float front = u * speed;
		float reach = fwd ? f.z : f.w;
		if (s > min(front, reach)) {
			continue;
		}
		float tail = exp(-max(0.0, u - len / speed - line_hold) / line_decay);
		float head = clamp(1.0 - (front - s) / 8.0, 0.0, 1.0) * 0.5;
		lv = max(lv, line_rest + f.y * (0.6 * tail + head));
	}
	return lv;
}

void fragment() {
	vec2 px = floor(UV * size);
	vec4 d = texture(TEXTURE, (px + 0.5) / size);
	int part = int(round(d.r * 255.0 / 40.0));
	if (part == 0 || d.a < 0.5) {
		discard;
	}
	float lum = d.b;
	float lvl = 1.0;
	int row = 1;
	int n = ramp_n.y;
	if (part == 1) {
		float rad = d.g * 255.0 / 200.0;
		float bed = hash3(vec3(floor(px / 2.0), floor(t * 9.0) + 11.0));
		lvl = base_lvl + 0.35 * bed * bed_k + 0.85 * fl * (1.15 - rad * 0.5);
		for (int i = 0; i < 24; i++) {
			if (i >= spark_n) {
				break;
			}
			if (all(equal(px, sparks[i]))) {
				lvl = 2.2;
			}
		}
		row = 0;
		n = ramp_n.x;
	} else if (part == 2 || part == 3) {
		lvl = line_level(d.g * 255.0, part == 2);
	} else if (part == 4) {
		lvl = 0.65 + 0.9 * lens;
	} else {
		lvl = glass;
		row = 2;
		n = ramp_n.z;
	}
	if (abs(lvl - 1.0) < 0.04) {
		discard;
	}
	float want = clamp(lum * lvl, 0.0, 1.0);
	// the fractional index along the ramp, by lightness
	float idx = 0.0;
	float prev = texelFetch(ramps, ivec2(0, row * 2 + 1), 0).r;
	if (want > prev) {
		idx = float(n - 1);
		for (int i = 1; i < 32; i++) {
			if (i >= n) {
				break;
			}
			float li = texelFetch(ramps, ivec2(i, row * 2 + 1), 0).r;
			if (want <= li) {
				idx = float(i - 1) + (want - prev) / max(li - prev, 0.0001);
				break;
			}
			prev = li;
		}
	}
	int lo = int(floor(idx));
	ivec2 q = ivec2(int(mod(px.x, 4.0)), int(mod(px.y, 4.0)));
	float th = (BAYER[q.y * 4 + q.x] + 0.5) / 16.0;
	int pick = clamp(lo + ((idx - float(lo)) > th ? 1 : 0), 0, n - 1);
	COLOR = vec4(texelFetch(ramps, ivec2(pick, row * 2), 0).rgb, 1.0);
}
