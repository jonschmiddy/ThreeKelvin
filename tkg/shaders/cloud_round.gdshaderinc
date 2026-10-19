// A CLOUD GOING SMALL THINS OUT AS A CLOUD (Jon, of the map's cloud shrinking
// into the chart: "Zooming out still has a huge square"): how much of it stands
// at `p`, `k` of the way in -- an ellipse well inside the picture's half-width
// and half-height (`h` from its middle `c`, its corners gone), feathered wide,
// its edge broken by low-frequency noise and by the gas's own light (`lum`:
// bright gas holds on further). The same at the same point on the live map
// (screen px, `nav_key`, `nav_ext`) and in the picture held (its texels, which
// are those screen px at the handoff), so the two meet without a step.

float cl_hash(vec2 c) {
	return fract(sin(dot(c, vec2(127.1, 311.7))) * 43758.5453);
}

float cl_noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(cl_hash(i), cl_hash(i + vec2(1.0, 0.0)), f.x), mix(cl_hash(i + vec2(0.0, 1.0)), cl_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float cloud_round(vec2 p, float lum, float k, vec2 c, vec2 h) {
	if (k <= 0.0) {
		return 1.0;
	}
	vec2 d = (p - c) / (h * 0.62);
	float r = length(d);
	float n = cl_noise(p / 70.0) * 0.6 + cl_noise(p / 29.0 + 7.3) * 0.4;
	float reach = 0.92 + (n - 0.5) * 0.36 + lum * 0.18;
	float m = 1.0 - smoothstep(reach - 0.55, reach, r);
	return mix(1.0, m, clamp(k, 0.0, 1.0));
}

// THE MAP'S SKY KEYED TO ITS VOID, as the map keys it (`nav_key`): how much of
// it is cloud (bright gas, or the near-black of dark dust) and not the space
// between, which is the field's
float sky_key(vec3 c) {
	float L = dot(c, vec3(0.299, 0.587, 0.114));
	return max(smoothstep(0.046, 0.085, L), 1.0 - smoothstep(0.008, 0.018, L));
}

// PAST THE MAP'S SKY'S END (it ends under the side panel; Jon: "the mirror is
// visible"). With the strip of it drawn on (`SystemView` `_past`, from sky px
// `PAST_X0`, `PAST_W` wide): the same cloud, handed over to across the
// picture's last 32 px (the gas the same pixels there, so only what lies in
// front of it in the picture thins out). With none (PAINTED): the sky's own
// strip off the screens' left, cross-faded in over its last 0.1 along a line
// the noise wanders. `u` in the sky's own [0, 1] (and on past 1).
//
// The caller samples (no sampler passed in: Godot's compiler refuses the
// item's own TEXTURE as an argument) -- the sky at `sky_uv_a` and `sky_uv_b`,
// the strip at `sky_uv_past` -- and `sky_wide` puts them together, keyed and
// premultiplied (rgb k, k).
const float SKY_SEAM = 0.1;
const float PAST_X0 = 928.0;
const float PAST_W = 192.0;

vec2 sky_uv_a(vec2 u) {
	return vec2(min(u.x, 1.0), clamp(u.y, 0.0, 1.0));
}

vec2 sky_uv_b(vec2 u) {
	return vec2(clamp(u.x - (1.0 - SKY_SEAM), 0.0, 1.0), clamp(u.y, 0.0, 1.0));
}

vec2 sky_uv_past(vec2 u) {
	return vec2(clamp((u.x * 960.0 - PAST_X0) / PAST_W, 0.0, 1.0), clamp(u.y, 0.0, 1.0));
}

vec4 sky_keyed(vec4 c) {
	float k = sky_key(c.rgb) * c.a;
	return vec4(c.rgb * k, k);
}

vec4 sky_wide(vec4 a, vec4 b, vec4 s, bool past_on, vec2 u) {
	float wx = u.x * 960.0;
	if (!past_on) {
		if (u.x <= 1.0 - SKY_SEAM) {
			return sky_keyed(a);
		}
		// (the hand-over wandering with the gas, not down one straight line)
		float w = (cl_noise(u * vec2(9.0, 5.0)) - 0.5) * SKY_SEAM * 0.9;
		return sky_keyed(mix(a, b, smoothstep(1.0 - SKY_SEAM, 1.0, u.x + w)));
	}
	if (wx <= PAST_X0) {
		return sky_keyed(a);
	}
	vec4 S = sky_keyed(vec4(s.rgb, 1.0));
	if (wx >= 960.0) {
		return S;
	}
	return mix(sky_keyed(a), S, smoothstep(PAST_X0, 960.0, wx));
}
