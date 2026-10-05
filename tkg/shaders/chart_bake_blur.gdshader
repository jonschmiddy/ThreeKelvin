shader_type canvas_item;
render_mode unshaded, blend_disabled;

// ONE HALF OF A GAUSSIAN BLUR, across or down, for the star chart's bake
// (`ChartSky`). The mockup spread the galaxy's added-up points with three box
// blurs in a row; a Gaussian of the same spread (sqrt(r (r + 1)) for a box of
// radius r) is the same picture without the boxes' corners. RGB and A take
// their own widths, so two fields that share a picture are spread apart.
//   pre 0: the source as it is;
//   pre 1: the light's brightness (from `src`) and the bulge's part of it
//          (`src2`.r), for how much of the light is the bulge's;
//   pre 2: the clouds' lit gas (`src`) and their dust (`src2`.g).
// Off the edge the nearest texel stands in, as the boxes did.

uniform sampler2D src : filter_nearest;
uniform sampler2D src2 : filter_nearest;
uniform int pre = 0;
uniform vec2 dir = vec2(1.0, 0.0);
uniform float sig_rgb = 1.0;
uniform float sig_a = 1.0;
uniform vec2 size = vec2(896.0, 616.0);

vec4 fetch(ivec2 at) {
	ivec2 lim = ivec2(size) - 1;
	at = clamp(at, ivec2(0), lim);
	vec4 a = texelFetch(src, at, 0);
	if (pre == 1) {
		vec4 b = texelFetch(src2, at, 0);
		return vec4(0.3 * a.r + 0.59 * a.g + 0.11 * a.b, b.r, 0.0, 0.0);
	}
	if (pre == 2) {
		vec4 b = texelFetch(src2, at, 0);
		return vec4(a.rgb, b.g);
	}
	return a;
}

void fragment() {
	ivec2 me = ivec2(floor(UV * size));
	ivec2 step_v = ivec2(dir);
	float sr = max(sig_rgb, 0.01), sa = max(sig_a, 0.01);
	int rad = min(int(ceil(3.0 * max(sr, sa))), 160);
	vec3 acc = vec3(0.0);
	float acc_a = 0.0, wr = 0.0, wa = 0.0;
	for (int i = -rad; i <= rad; i++) {
		float x = float(i);
		float w1 = exp(-x * x / (2.0 * sr * sr));
		float w2 = exp(-x * x / (2.0 * sa * sa));
		vec4 v = fetch(me + step_v * i);
		acc += v.rgb * w1;
		acc_a += v.a * w2;
		wr += w1;
		wa += w2;
	}
	COLOR = vec4(acc / wr, acc_a / wa);
}
