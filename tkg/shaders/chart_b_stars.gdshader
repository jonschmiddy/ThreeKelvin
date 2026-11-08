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
uniform int diag = 0;   // (tuning: 2 draws no stars, `ChartSky.diag`)
uniform float k = 622.25;
uniform float phi = 0.0;
uniform float t = 0.0;
uniform float calm = 0.0;
uniform float bulge_r = 0.128;
// TORN AWAY (`ChartTorn`, redraw A): the dwarf's stars where they always are, those
// past its rings' torn edge gone with their rings, and those thick about its body past
// its drawn edge thinned out to the sky's own few. torn: on, the rings' edge (gu), the
// plane's squash, the cut's strength; torn2: the way the stream leaves the dwarf (the
// plane, squashed as the rings are), how far the edges are drawn out that way (a share
// of them), the drawn edge (gu, the ball's own frame); torn3: the way the stream leaves
// it in the ball's own frame, the ball's squash on the screen. Off (torn.x 0): every
// star as it always is
uniform vec4 torn = vec4(0.0);
uniform vec4 torn2 = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 torn3 = vec4(1.0, 0.0, 1.0, 0.0);
// (the share of the thick stars kept past the drawn edge: the sky's own density there)
const float TORN_FIELD = 0.18;
// THE SOLID GALAXY (`ChartSky.solid`): the sparkles where the camera shows the disc
// (`chart_solid`'s solidFwdN, as `chart_c_stars` puts its stars): on, and the camera's
// distance, elevation's sine and cosine, 0; and where it looks on the disc's plane
uniform bool solid = false;
uniform vec4 solidW = vec4(1.9, 0.38, 0.92499, 0.0);
uniform vec2 solidT = vec2(0.0);

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
		bool tgone = false;
		if (torn.x > 0.5 && torn.w > 0.0) {
			// (past the edge, as the place pass cuts the body, `tornShape`: torn on the
			// star's own hash, drawn out toward the stream, its last band thinning out)
			vec2 gal = vec2(a.x, a.y * torn.z);
			float re = length(vec3(gal, b.w));
			float pull = re > 1e-5 ? pow(max(dot(gal / max(length(gal), 1e-5), torn2.xy), 0.0), 3.0) : 0.0;
			float Ee = torn.y * (1.0 + torn2.z * pull + 0.09 * (fract(b.z * 91.7 + c.x * 13.1) - 0.5));
			float band = torn.y * (0.08 + 0.9 * torn2.z * pull);
			float x = (re - Ee) / max(band, 1e-4);
			float keepP = (1.0 - x) * (0.4 + 0.5 * pull);
			if (torn.w > 0.5 && (x >= 1.0 || (x > 0.0 && fract(b.z * 37.3 + c.y * 5.9) >= keepP))) {
				tgone = true;
			}
			// the drawn edge: in the ball's own frame on the screen, as the body is cut
			vec2 vs = vec2((a.x * cs + a.y * sn), ((a.y * cs - a.x * sn) * 0.38 - b.w * 0.92499) / torn3.z);
			float rs = length(vs);
			float pullS = rs > 1e-5 ? pow(max(dot(vs / rs, torn3.xy), 0.0), 3.0) : 0.0;
			float Ed = torn2.w * (1.0 + torn2.z * pullS) + (0.015 + 0.25 * torn2.w) * (fract(b.z * 17.9 + c.y * 3.3) - 0.5);
			float bandS = torn2.w * (0.3 + 1.4 * torn2.z * pullS);
			float xs = (rs - Ed) / max(bandS, 1e-4);
			float keepS = xs <= 0.0 ? 1.0 : max(TORN_FIELD, (1.0 - xs) * (0.4 + 0.5 * pullS));
			// (only where they were thick: past the body, the sky's own few stay with their rings)
			keepS = mix(keepS, 1.0, sm(0.95 * torn3.w, 1.25 * torn3.w, rs));
			if (torn.w > 0.5 && fract(b.z * 61.3 + c.x * 7.7) >= keepS) {
				tgone = true;
			}
		}
		vec2 v = vec2((a.x * cs + a.y * sn), (a.y * cs - a.x * sn) * 0.38 - b.w * 0.92499) * k;
		if (solid) {
			vec2 d = vec2(v.x, v.y / 0.38) / k - solidT;
			float sc = solidW.x / (solidW.x - d.y * solidW.z);
			v = (vec2(solidT.x, solidT.y * 0.38) + vec2(d.x * sc, d.y * solidW.y * sc)) * k;
		}
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
		if (lv > 0.05 && (diag & 18) == 0 && !tgone) {
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
