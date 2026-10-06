shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE RADIANT CHART'S HORIZON MAP (`ChartRadiant`), baked once a galaxy: for
// each azimuth (x) and radius (y), the steepest slope h/r of the billow tops
// between the bulge and that radius. A point (r, th, h) sees the core when |h|/r
// is above it: this cuts god rays into the haze and shades the billows. From
// the showcase's direction A (`A/chart/bake_hor.glsl`).

#include "res://shaders/chart_r_common.gdshaderinc"

uniform float u_rmax = 1.3;
uniform float u_ext = 1.3;
uniform sampler2D u_discB : filter_linear_mipmap, repeat_disable;

void fragment() {
	float th = (UV.x - 0.5) * R_TAU;
	float r = UV.y * u_rmax;
	const float R0 = 0.05;
	float acc = 0.0;
	for (int k = -3; k <= 3; k++) {
		float a = th + float(k) * 0.02;
		vec2 d2 = vec2(cos(a), sin(a));
		float best = 0.0;
		for (int i = 1; i <= 48; i++) {
			float rr = R0 + (r - R0) * float(i) / 48.0;
			if (rr <= R0) {
				break;
			}
			float b = textureLod(u_discB, kitMapUV(d2 * rr, u_ext), 1.0).b;
			best = max(best, b / rr);
		}
		acc += best * (4.0 - abs(float(k)));
	}
	COLOR = vec4(acc / 16.0, 0.0, 0.0, 1.0);
}
