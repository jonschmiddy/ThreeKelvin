shader_type canvas_item;
render_mode unshaded, blend_mix;

// THE PAINTED CHART'S SPARKLES (`ChartSky`, style PAINTED): the showcase's
// direction B star rule on the GPU, one quad a star, each painting a sprite into
// a block buffer the place pass reads -- (level, colour class / 4, tier / 3, 1).
// The chart's own stars by the shared rule (the same thresholds and per-star
// hash as the simplified chart: sparse at the opening, more fading in as you zoom),
// drawn as sprites by tier: most a single block, some a plus, a rare few a
// four-point star with two-block arms and one-block glints whose arms grow a
// step and back on a slow 3-6 s cycle (a held pose, never a strobe). Globulars
// below zoom 2 are warm knots; a pulsar beats in two held poses. Stars are
// sorted dimmest first, so where two sprites meet the brighter is drawn last.
//
//   st_a  (plane x, plane y, luminance 0-255, kind: 0 disc 1 core 2 globular member 4 globular knot 5 pulsar)
//   st_b  (colour class 0-3, tier 1-3, the star's hash, height above the plane gu)
//   st_c  (two more hashes, the globular's size or 0)

uniform sampler2D st_a : filter_nearest;
uniform sampler2D st_b : filter_nearest;
uniform sampler2D st_c : filter_nearest;
uniform int tex_w = 2048;
uniform int n_star = 0;
uniform vec2 vp_origin = vec2(-2.0);
uniform vec2 cpix = vec2(327.0, 214.0);
uniform float zoom = 0.42;
uniform float k = 622.25;
uniform float phi = 0.0;
uniform float t = 0.0;
uniform float calm = 0.0;
uniform float bulge_r = 0.128;

varying vec4 v_s;      // level, colour class / 4, tier / 3, sprite (0 dot 1 plus 2 four-point 3 four-point long)
varying vec2 v_loc;

const vec2 CORNER[6] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(1.0, 1.0),
	vec2(0.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 1.0));

float sm(float a, float b, float x) {
	float u = clamp((x - a) / (b - a), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

void vertex() {
	int id = VERTEX_ID / 6;
	vec2 corner = CORNER[VERTEX_ID % 6];
	vec2 blk = vec2(-100.0);
	vec4 s = vec4(0.0);
	if (id < n_star) {
		ivec2 at = ivec2(id % tex_w, id / tex_w);
		vec4 a = texelFetch(st_a, at, 0);
		vec4 b = texelFetch(st_b, at, 0);
		vec4 c = texelFetch(st_c, at, 0);
		int kind = int(a.w + 0.5);
		float lz = log(zoom);
		float cs = cos(phi), sn = sin(phi);
		vec2 v = vec2((a.x * cs + a.y * sn), (a.y * cs - a.x * sn) * 0.38 - b.w * 0.92499) * k;
		vec2 scr = cpix + v * zoom;
		float lum = a.z;
		float lv = 0.0;
		float sprite = 0.0;
		float tier = b.y;
		float cls = b.x;
		if (kind <= 2) {
			float L = zoom <= 0.6 ? 150.0 : (zoom >= 3.0 ? 60.0 : 150.0 + (60.0 - 150.0) * (lz - log(0.6)) / (log(3.0) - log(0.6)));
			float keep = zoom <= 0.6 ? 0.4 : (zoom >= 2.0 ? 1.0 : 0.4 + 0.6 * (lz - log(0.6)) / (log(2.0) - log(0.6)));
			float f = 1.0;
			if (kind == 1 && length(a.xy) < bulge_r) {
				f *= sm(1.55, 2.3, zoom);
			}
			if (kind == 2) {
				f *= sm(1.6, 2.4, zoom);
			}
			float kk = kind == 1 ? keep * 0.25 : keep;
			float hs = b.z;
			if (lum >= L && hs < kk && f > 0.02) {
				float fade = min(1.0, (lum - L) / 30.0 + 0.15) * min(1.0, (kk - hs) / 0.08 + 0.15) * f;
				lv = min(0.999, fade * pow(max(0.0, lum - 40.0) / 215.0, 0.7));
				if (tier >= 2.5 && lv > 0.45) {
					float per = 3.0 + c.y * 3.0, ph = c.x * 40.0;
					float cyc = (sin(t * (calm > 0.5 ? 0.5 : 1.0) * 6.2831853 / per + ph) + 1.0) * 0.5;
					sprite = cyc > 0.62 ? 3.0 : 2.0;
				} else if (tier >= 1.5 && lv > 0.3 && (tier >= 2.5 || zoom >= 0.75 || c.x < 0.035)) {
					sprite = 1.0;
				}
			}
		} else if (kind == 4) {
			float gk = 1.0 - sm(1.6, 2.4, zoom);
			if (gk > 0.02) {
				lv = min(0.999, gk * (0.34 + min(0.2, c.z / 500.0)));
				cls = 1.0;
				tier = 2.0;
				sprite = 1.0;
			}
		} else {
			// a pulsar: two held poses on its beat, the bright one a second long
			float beat = fract(t / 5.0);
			bool on = beat < 0.2 && calm < 0.5;
			lv = on ? 0.95 : 0.6;
			cls = 0.0;
			tier = 3.0;
			sprite = on ? 3.0 : 1.0;
		}
		if (lv > 0.05) {
			blk = floor((scr - vp_origin) * 0.5);
			s = vec4(lv, cls / 4.0, tier / 3.0, sprite);
		}
	}
	v_s = s;
	// a sprite's quad: 7 x 7 blocks round its centre (the longest arm is 3)
	vec2 lo = blk - 3.0;
	v_loc = corner * 7.0 - 3.0;
	VERTEX = lo + corner * 7.0;
}

void fragment() {
	ivec2 d = ivec2(floor(v_loc));
	int ax = abs(d.x), ay = abs(d.y);
	int sprite = int(v_s.w + 0.5);
	float lv = v_s.x;
	float part = -1.0;
	if (ax == 0 && ay == 0) {
		part = 1.0;
	} else if (sprite >= 1 && ax + ay == 1) {
		part = 0.62;
	} else if (sprite >= 2 && ((ax == 2 && ay == 0) || (ax == 0 && ay == 2))) {
		part = 0.4;
	} else if (sprite >= 2 && ax == 1 && ay == 1) {
		part = 0.3;
	} else if (sprite >= 3 && ax == 3 && ay == 0) {
		part = 0.26;
	}
	if (part < 0.0 || lv <= 0.05) {
		discard;
	}
	// the arms are sprite parts: tier "0" so the paint pass never outlines them
	COLOR = vec4(lv * part, v_s.y, part >= 1.0 ? v_s.z : 0.0, 1.0);
}
