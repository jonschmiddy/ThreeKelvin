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
